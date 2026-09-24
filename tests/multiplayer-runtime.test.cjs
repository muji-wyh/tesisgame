'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { VoicePopResampler } = require('../web/multiplayer-audio.js');
const { VoicePopInference, wordsFromResult } = require('../web/multiplayer-worker.js');
const { identificationProfiles, matchVoiceProfile } = require('../web/multiplayer-host.js');
const { SPEAKER_MODEL_VERSION } = require('../web/voice-profiles.js');
const { MODELS } = require('../tools/prepare-multiplayer-runtime.cjs');
const root = path.resolve(__dirname, '..');

function resample(samples, rate, chunk = 128) {
  const packets = [];
  const resampler = new VoicePopResampler(rate, (samples, sampleOffset) => packets.push({ samples, sampleOffset }));
  for (let offset = 0; offset < samples.length; offset += chunk) resampler.push(samples.subarray(offset, offset + chunk));
  resampler.flush();
  const joined = new Float32Array(packets.reduce((sum, packet) => sum + packet.samples.length, 0));
  let offset = 0;
  for (const packet of packets) {
    assert.equal(packet.sampleOffset, offset, 'sample offsets must remain contiguous across packets and final flush');
    joined.set(packet.samples, offset);
    offset += packet.samples.length;
  }
  return joined;
}

test('capture resampling preserves duration and does not depend on render quantum size', () => {
  for (const rate of [16000, 44100, 48000]) {
    const input = Float32Array.from({ length: rate }, (_, i) => 0.5 * Math.sin(i * 2 * Math.PI * 1000 / rate));
    const a = resample(input, rate);
    const b = resample(input, rate, 511);
    assert.ok(Math.abs(a.length - 16000) <= 1);
    assert.deepEqual(a, b);
    assert.ok(a.every(Number.isFinite));
  }
});

test('anti-alias filtering suppresses microphone frequencies above 8 kHz', () => {
  const signal = (frequency) => resample(Float32Array.from({ length: 48000 }, (_, i) => Math.sin(i * 2 * Math.PI * frequency / 48000)), 48000);
  const rms = (samples) => Math.sqrt(samples.slice(100, -100).reduce((sum, x) => sum + x * x, 0) / (samples.length - 200));
  assert.ok(rms(signal(1000)) > 0.65);
  assert.ok(rms(signal(11000)) < 0.03);
});

test('word events use Zipformer token timestamps and discard ambiguous untimed multiword results', () => {
  assert.deepEqual(wordsFromResult({ text: 'apple cat', tokens: ['▁APP', 'LE', '▁CAT'], timestamps: [0.12, 0.2, 0.6] }, 1000, 2100), [
    { text: 'apple', startMs: 1120, endMs: 1600 },
    { text: 'cat', startMs: 1600, endMs: 2100 }
  ]);
  assert.deepEqual(wordsFromResult({ text: 'apple cat' }, 1000, 2100), []);
  assert.deepEqual(wordsFromResult({ text: 'cat' }, 1000, 2100), [{ text: 'cat', startMs: 1000, endMs: 2100 }]);
  assert.deepEqual(wordsFromResult({ text: 'cat', tokens: ['▁CAT'], timestamps: [0.8] }, 1000, 1500), [], 'timestamps from appended ASR silence must not be clamped into the last millisecond of real speech');
  assert.deepEqual(wordsFromResult({ text: 'cat dog', tokens: [' CA', 'T', ' ', 'DO', 'G'], timestamps: [0.1, 0.2, 0.3, 0.4, 0.5] }, 0, 900).map((word) => word.text), ['cat', 'dog']);
});

test('adjacent words receive disjoint voice clips and feedback never reuses a scoring event ID', () => {
  const messages = [];
  const clips = [];
  const heap = new Float32Array(65536);
  let available = true;
  let secondTimestamp = 0.6;
  const engine = new VoicePopInference((event) => messages.push(event));
  engine.sessionId = 'two-speakers';
  engine.sampleCount = 16000;
  engine.maxTimeMs = 30000;
  engine.audioBuffer = new Float32Array(16000);
  engine.copy = () => {};
  engine.module = {
    HEAPF32: heap,
    _vp_front: () => available ? 16000 : 0,
    _vp_segment_start: () => 0,
    _vp_segment_samples: () => 400,
    _vp_transcribe: () => 0,
    UTF8ToString: () => JSON.stringify({ text: 'cat dog', tokens: ['▁CAT', '▁DOG'], timestamps: [0.1, secondTimestamp] }),
    _vp_embed(pointer, count) {
      heap.fill(0, 20000, 20256);
      heap[20000 + clips.length] = 1;
      clips.push({ pointer, count });
      return 256;
    },
    _vp_embedding: () => 80000,
    _vp_pop() { available = false; }
  };
  engine.drain();
  assert.equal(messages.length, 2);
  assert.equal(clips[0].pointer + clips[0].count * 4, clips[1].pointer);
  assert.equal(clips[0].count + clips[1].count, 16000);
  assert.notDeepEqual(messages[0].embedding, messages[1].embedding);
  available = true;
  secondTimestamp = 0.2;
  engine.drain();
  assert.equal(messages[2].type, 'feedback');
  assert.equal(messages[2].reason, 'identity_unconfirmed');
  assert.equal(messages[3].type, 'utterance');
  assert.equal(new Set(messages.map(event => event.eventId)).size, 4);
});

test('an isolated word emitted at the VAD end uses actual PCM bounds; synthetic-tail emissions are rejected', () => {
  const run = (timestamp) => {
    const events = [];
    let available = true;
    const heap = new Float32Array(65536);
    heap.fill(0.1, 100 + 3200, 100 + 9600);
    heap[20000] = 1;
    const engine = new VoicePopInference((event) => events.push(event));
    Object.assign(engine, { sessionId: 'cat', sampleCount: 16000, maxTimeMs: 30000,
      audioBuffer: new Float32Array(16000), copy() {} });
    engine.module = {
      HEAPF32: heap, _vp_front: () => available ? 12800 : 0,
      _vp_segment_start: () => 0, _vp_segment_samples: () => 400,
      _vp_transcribe: () => 0,
      UTF8ToString: () => JSON.stringify({ text: 'cat', tokens: [' CA', 'T'], timestamps: [timestamp, timestamp + 0.1] }),
      _vp_embed: () => 256, _vp_embedding: () => 80000,
      _vp_pop() { available = false; }
    };
    engine.drain();
    return events;
  };
  const real = run(0.8);
  assert.equal(real.length, 1);
  assert.equal(real[0].startMs, 200);
  assert.equal(real[0].endMs, 600);
  const tail = run(1.1);
  assert.equal(tail.length, 1);
  assert.equal(tail[0].type, 'feedback');
  assert.equal(tail[0].reason, 'timing_unavailable');
  assert.equal(tail[0].text, 'cat');
  assert.equal(tail[0].startMs, 0);
  assert.equal(tail[0].endMs, 800, 'Feedback keeps the real VAD interval, not the synthetic token timestamp');
});

test('unusable detected speech reports non-scoring feedback without stopping or changing identity rules', () => {
  const cases = [
    { result: { text: '' }, reason: 'unclear_speech', text: '' },
    { result: { text: ' RAW WORDS ' }, reason: 'timing_unavailable', text: 'RAW WORDS' },
    { dimension: 0, reason: 'identity_unconfirmed', text: 'cat' },
    { value: NaN, reason: 'identity_unconfirmed', text: 'cat' },
    { value: 0, reason: 'identity_unconfirmed', text: 'cat' },
    { count: 1600, reason: 'identity_unconfirmed', text: 'cat' }
  ];
  for (const item of cases) {
    const events = [], heap = new Float32Array(65536), count = item.count || 16000;
    heap.fill(0.1, 100, 100 + count);
    heap[20000] = item.value ?? 1;
    let available = true;
    const engine = new VoicePopInference(event => events.push(event));
    Object.assign(engine, { sessionId: 'feedback-round', timeOffsetMs: 3000, sampleCount: count,
      maxTimeMs: 30000, audioBuffer: new Float32Array(count), copy() {} });
    engine.module = {
      HEAPF32: heap, _vp_front: () => available ? count : 0,
      _vp_segment_start: () => 0, _vp_segment_samples: () => 400,
      _vp_transcribe: () => 0,
      UTF8ToString: () => JSON.stringify(item.result || { text: 'cat', tokens: [' CA', 'T'], timestamps: [0.02, 0.04] }),
      _vp_embed: () => item.dimension ?? 256, _vp_embedding: () => 80000,
      _vp_pop() { available = false; }
    };
    engine.drain();
    assert.deepEqual(events, [{ type: 'feedback', sessionId: 'feedback-round', eventId: 'feedback-round:1',
      text: item.text, startMs: 3000, endMs: 3000 + count / 16, reason: item.reason }]);
    assert.equal(engine.sessionId, 'feedback-round');
    assert.equal(events[0].embedding, undefined);
    engine.drain();
    assert.equal(events.length, 1, 'A drained segment cannot produce duplicate feedback');
  }
});

test('game vocabulary uses safe canonical BPE phrases, is copied then erased, and resets across sessions', () => {
  const heap = new Float32Array(4096), messages = [], vocabularies = [];
  let active = '', frees = 0;
  const engine = new VoicePopInference(event => messages.push(event));
  engine.ready = true;
  engine.module = {
    HEAPF32: heap, _malloc: () => 4,
    _vp_reset() { active = ''; },
    _vp_set_vocabulary(pointer) {
      const bytes = new Uint8Array(heap.buffer, pointer);
      active = String.fromCharCode(...bytes.subarray(0, bytes.indexOf(0)));
      vocabularies.push(active);
    },
    _free() { assert.ok(heap.every(value => value === 0)); frees++; }
  };
  engine.start({ sessionId: 'biased', vocabulary: ['cat', ' CAT ', 'ice cream', 'dog:99', 'cat/dog', 'cat\ndog', 3, 'x'.repeat(65)] });
  assert.equal(active, 'CAT\nICE CREAM');
  assert.equal(frees, 1);
  engine.start({ sessionId: 'plain' });
  assert.equal(active, '');
  engine.start({ sessionId: 'profile', mode: 'enrollment', vocabulary: ['cat'] });
  assert.equal(active, '', 'Profile capture must never inherit or set a game vocabulary');
  assert.deepEqual(vocabularies, ['CAT\nICE CREAM']);
  assert.equal(messages.filter(event => event.type === 'started').length, 3);
});

test('worker fences old sessions, rejects audio gaps and clips samples at the round deadline', () => {
  const messages = [];
  let accepted = 0;
  const engine = new VoicePopInference((event) => messages.push(event));
  engine.module = { _vp_reset() {}, _vp_accept(_pointer, count) { accepted += count; }, _vp_front() { return 0; }, _vp_flush() {} };
  engine.copy = () => {};
  engine.ready = true;
  engine.start({ sessionId: 'round1', timeOffsetMs: 29900 });
  engine.audio({ sessionId: 'old', samples: new Float32Array(512), sampleOffset: 0 });
  assert.equal(accepted, 0);
  engine.audio({ sessionId: 'round1', samples: new Float32Array(512), sampleOffset: 0 });
  engine.audio({ sessionId: 'round1', samples: new Float32Array(512), sampleOffset: 0 });
  assert.equal(accepted, 512, 'duplicate audio is ignored');
  assert.throws(() => engine.audio({ sessionId: 'round1', samples: new Float32Array(512), sampleOffset: 1024 }), /interrupted/);
  engine.audio({ sessionId: 'round1', samples: new Float32Array(2048), sampleOffset: 512 });
  assert.equal(accepted, 1600);
  engine.flush({ sessionId: 'round1' });
  assert.equal(messages.at(-1).type, 'flushed');
  assert.equal(engine.sessionId, null);
});

test('a failed model warm-up never emits ready', async () => {
  const messages = [];
  const engine = new VoicePopInference((event) => messages.push(event), async () => ({ FS: { writeFile() {} }, _vp_create() { return 0; } }));
  const assets = Object.fromEntries(MODELS.map((model) => [model.id, new ArrayBuffer(1)]));
  const modelFiles = Object.fromEntries(MODELS.map((model) => [model.id, `/${model.file}`]));
  await assert.rejects(engine.init({ assets, runtime: { modelFiles } }), /could not be opened/);
  assert.equal(engine.ready, false);
  assert.equal(messages.length, 0);
});

test('capture stop retries failed physical release and never returns false success', async () => {
  let stopCalls = 0;
  let rejectStop = true;
  const track = { addEventListener() {}, stop() { stopCalls++; if (rejectStop) throw new Error('track failure'); } };
  class Context {
    constructor() { this.state = 'running'; this.audioWorklet = { async addModule() {} }; }
    async resume() {}
    async close() {}
    createMediaStreamSource() { return { connect() {}, disconnect() { throw new Error('disconnected'); } }; }
    createGain() { return { gain: {}, connect() {}, disconnect() {} }; }
  }
  class Node {
    constructor() { this.port = { postMessage() {} }; }
    connect() {}
    disconnect() { throw new Error('disconnected'); }
  }
  const context = { AudioContext: Context, AudioWorkletNode: Node, navigator: { mediaDevices: { async getUserMedia() { return { getTracks: () => [track] }; } } }, setTimeout, clearTimeout };
  context.window = context;
  vm.runInNewContext(fs.readFileSync(path.join(root, 'web/multiplayer-capture.js'), 'utf8'), context);
  const capture = await context.VoicePopCapture.create({ onAudio() {} });
  assert.throws(() => capture.stop(), /release the microphone/);
  assert.throws(() => capture.stop(), /release the microphone/);
  assert.equal(stopCalls, 2);
  rejectStop = false;
  capture.stop();
  capture.stop();
  assert.equal(stopCalls, 3);
});

function enrollmentFixture(mode = 'enrollment') {
  const messages = [], heap = new Float32Array(800000), segments = [], embeddedClips = [];
  const pcmOffset = 100000, embeddingOffset = 700000;
  let resetCount = 0, transcriptions = 0, embeddingCalls = 0;
  const engine = new VoicePopInference(event => messages.push(event));
  engine.module = {
    HEAPF32: heap, _malloc: () => 4096, _free() {},
    _vp_reset() { resetCount++; heap.fill(0, pcmOffset, embeddingOffset + 256); segments.length = 0; },
    _vp_accept() {}, _vp_flush() {}, _vp_front: () => segments[0]?.count || 0,
    _vp_segment_start: () => segments[0].start,
    _vp_segment_samples() { heap.set(segments[0].pcm, pcmOffset); return pcmOffset * 4; },
    _vp_pop() { heap.fill(0, pcmOffset, pcmOffset + segments[0].count); segments.shift(); },
    _vp_transcribe() { transcriptions++; throw new Error('Voice sampling must not transcribe speech'); },
    _vp_embed(pointer, count) {
      embeddingCalls++;
      assert.ok(count >= 700 * 16);
      embeddedClips.push(heap.slice(pointer / 4, pointer / 4 + count));
      const vector = segments[0].vectors.shift() || segments[0].vector;
      heap.set(vector, embeddingOffset);
      return 256;
    },
    _vp_embedding: () => embeddingOffset * 4
  };
  engine.ready = true;
  engine.start({ sessionId: mode, mode, maxTimeMs: mode === 'enrollment' ? 60000 : 30000 });
  return { engine, messages, heap, embeddedClips, get resetCount() { return resetCount; }, get transcriptions() { return transcriptions; },
    get embeddingCalls() { return embeddingCalls; },
    segment(seconds = 4.1, vector = [1, ...new Array(255).fill(0)], amplitude = 0.1, vectors = [], drain = true, options = {}) {
      const pcm = options.pcm || new Float32Array(Math.round(seconds * 16000)).fill(amplitude);
      const count = pcm.length, start = engine.sampleCount + (engine.sampleCount ? (options.gapMs ?? 400) * 16 : 0);
      engine.audioBuffer.set(pcm, start);
      engine.sampleCount = start + count;
      segments.push({ count, start, pcm, vector, vectors: [...vectors] });
      if (drain) engine.drain();
    }
  };
}

test('enrollment requires three clear turns and twelve effective seconds, returns independent features and erases retained samples', () => {
  const f = enrollmentFixture();
  const buffer = f.engine.audioBuffer;
  f.segment(); f.segment();
  assert.equal(f.messages.at(-1).canFinish, false);
  f.segment();
  const vectors = f.engine.enrollment.vectors.map(value => value.embedding);
  assert.equal(f.messages.at(-1).canFinish, true);
  assert.equal(f.messages.at(-1).segments, 3);
  assert.equal(f.messages.at(-1).voicedMs, 12300);
  assert.equal(f.messages.at(-1).progress, 1);
  assert.equal(f.messages.some(value => value.type === 'enrollment-complete'), false, 'Readiness cannot save or finish a profile automatically');
  f.engine.flush({ sessionId: 'enrollment' });
  const result = f.messages.at(-1);
  assert.equal(result.type, 'enrollment-complete');
  assert.equal(result.modelVersion, SPEAKER_MODEL_VERSION);
  assert.equal(result.embedding.length, 256);
  assert.equal(Math.hypot(...result.embedding), 1);
  assert.equal(result.quality.segments, 3);
  assert.equal(result.segments.length, 3);
  assert.ok(result.segments.every(segment => segment.voicedMs === 4100 && Math.hypot(...segment.embedding) === 1));
  assert.ok(result.templates.length >= 1 && result.templates.length <= 8);
  assert.ok(result.templates.every(template => Math.hypot(...template) === 1));
  assert.equal(f.transcriptions, 0);
  assert.equal(f.engine.sessionId, null);
  assert.equal(f.engine.audioBuffer, null);
  assert.equal(f.engine.enrollment, null);
  assert.ok(buffer.every(value => value === 0));
  assert.ok(vectors.every(vector => vector.every(value => value === 0)));
  assert.ok(f.heap.every(value => value === 0), 'Native reset and scratch cleanup also erase audio and temporary features');
});

test('silent, short, quiet and clipped enrollment segments do not count as a completed voice sample', () => {
  const f = enrollmentFixture();
  f.segment(2, undefined, 0);
  f.segment(0.4);
  f.segment(2, undefined, 0.0035);
  f.segment(2, undefined, 0.99);
  assert.equal(f.engine.enrollment.segments, 0);
  assert.equal(f.engine.enrollment.rejectedSegments, 4);
  assert.equal(f.embeddingCalls, 0);
  f.engine.flush({ sessionId: 'enrollment' });
  assert.equal(f.messages.at(-1).type, 'enrollment-error');
  assert.equal(f.messages.at(-1).code, 'insufficient_speech');
  assert.equal(f.engine.audioBuffer, null);
});

test('twelve seconds in fewer than three turns and three short turns both fail enrollment quality gates', () => {
  for (const turns of [[6.5, 6.5], [1, 1, 1]]) {
    const f = enrollmentFixture();
    for (const duration of turns) f.segment(duration);
    assert.equal(f.messages.at(-1).canFinish, false);
    f.engine.flush({ sessionId: 'enrollment' });
    assert.equal(f.messages.at(-1).code, 'insufficient_speech');
    assert.equal(f.messages.some(value => value.type === 'enrollment-complete'), false);
  }
});

test('internal silence and background noise add no speech credit and are not cut out of model clips', () => {
  for (const background of [0, 0.0025]) {
    const f = enrollmentFixture();
    const pcm = new Float32Array(4 * 16000).fill(background);
    pcm.fill(0.1, 0, 16000);
    pcm.fill(0.1, 3 * 16000);
    f.segment(4, undefined, 0.1, [], true, { pcm });
    assert.equal(f.messages.at(-1).voicedMs, 2000);
    assert.equal(f.embeddedClips[0].length, pcm.length);
    assert.deepEqual(f.embeddedClips[0], pcm, 'The embedding keeps the natural timing of both speech regions');
    f.segment(4, undefined, 0.1, [], true, { pcm });
    f.segment(4, undefined, 0.1, [], true, { pcm });
    assert.equal(f.messages.at(-1).segments, 3);
    assert.equal(f.messages.at(-1).voicedMs, 6000);
    assert.equal(f.messages.at(-1).canFinish, false, 'Twelve seconds of VAD span is not twelve seconds of useful speech');
    f.engine.flush({ sessionId: 'enrollment' });
    assert.equal(f.messages.at(-1).code, 'insufficient_speech');
  }
  const f = enrollmentFixture();
  const sparse = new Float32Array(5 * 16000);
  sparse.fill(0.1, 0, 0.2 * 16000);
  sparse.fill(0.1, 4.8 * 16000);
  f.segment(5, undefined, 0.1, [], true, { pcm: sparse });
  assert.equal(f.messages.at(-1).reason, 'insufficient_speech');
  assert.equal(f.messages.at(-1).voicedMs, 0);
  assert.equal(f.embeddingCalls, 0, 'Two short sounds around a long pause never qualify as a usable turn');
});

test('quality progress and final error distinguish quiet, clipped and insufficient speech', () => {
  for (const [seconds, amplitude, reason] of [[2, 0.0035, 'too_quiet'], [2, 0.99, 'clipping'], [0.3, 0.1, 'insufficient_speech']]) {
    const f = enrollmentFixture();
    f.segment(seconds, undefined, amplitude);
    assert.equal(f.messages.at(-1).reason, reason);
    assert.ok(f.messages.at(-1).message);
    f.engine.flush({ sessionId: 'enrollment' });
    assert.equal(f.messages.at(-1).reason, reason);
    assert.deepEqual(f.messages.at(-1).quality.rejectionReasons, { [reason]: 1 });
  }
});

test('continuous VAD chunks cannot count as independent recording turns', () => {
  const f = enrollmentFixture();
  f.segment(4);
  f.segment(4, undefined, 0.1, [], true, { gapMs: 0 });
  f.segment(4, undefined, 0.1, [], true, { gapMs: 0 });
  assert.equal(f.messages.at(-1).voicedMs, 12000);
  assert.equal(f.messages.at(-1).segments, 1);
  assert.equal(f.messages.at(-1).canFinish, false);
  f.engine.flush({ sessionId: 'enrollment' });
  assert.equal(f.messages.at(-1).code, 'insufficient_speech');
  const identify = enrollmentFixture('identification');
  identify.segment(2);
  identify.segment(2, undefined, 0.1, [], true, { gapMs: 0 });
  assert.equal(identify.messages.at(-1).segments, 1);
  assert.equal(identify.messages.at(-1).voicedMs, 4000);
  assert.equal(identify.messages.some(event => event.type === 'identification-complete'), false);
  identify.segment(1);
  assert.equal(identify.messages.at(-1).type, 'identification-complete');
  assert.deepEqual(identify.messages.at(-1).segments.map(segment => segment.voicedMs), [4000, 1000]);
  const dipped = enrollmentFixture('identification');
  const first = new Float32Array(2.5 * 16000).fill(0.1), second = first.slice();
  first.fill(0, 2.2 * 16000); second.fill(0, 0, 0.3 * 16000);
  dipped.segment(2.5, undefined, 0.1, [], true, { pcm: first });
  dipped.segment(2.5, undefined, 0.1, [], true, { pcm: second, gapMs: 0 });
  assert.equal(dipped.messages.at(-1).voicedMs, 4400);
  assert.equal(dipped.messages.at(-1).segments, 1, 'Amplitude dips cannot turn adjacent forced VAD chunks into independent turns');
  dipped.engine.stop({});
});

test('recording duration allows sixty seconds only for enrollment', () => {
  const f = enrollmentFixture();
  for (const [mode, limit] of [['enrollment', 60000], ['identification', 30000], ['game', 30000]]) {
    f.engine.start({ sessionId: mode, mode, maxTimeMs: 90000 });
    assert.equal(f.engine.maxTimeMs, limit);
    assert.equal(f.engine.audioBuffer.length, limit * 16);
  }
  assert.throws(() => f.engine.start({ sessionId: 'invalid', mode: 'game', maxTimeMs: Infinity }), /duration/);
  assert.throws(() => f.engine.start({ sessionId: 'invalid', mode: 'game', maxTimeMs: 60000, timeOffsetMs: 40000 }), /clock/);
  f.engine.stop({});
});

test('a consistent pair can replace the first outlier without retaining its voice in enrollment', () => {
  const a = [1, ...new Array(255).fill(0)], b = [0, 1, ...new Array(254).fill(0)];
  const f = enrollmentFixture();
  f.segment(4.1, b);
  const outlier = f.engine.enrollment.vectors[0].embedding;
  f.segment(4.1, a); f.segment(4.1, a);
  assert.ok(outlier.every(value => value === 0));
  assert.equal(f.messages.at(-1).segments, 2);
  assert.equal(f.messages.at(-1).voicedMs, 8200);
  f.segment(4.1, a);
  f.engine.flush({ sessionId: 'enrollment' });
  assert.equal(f.messages.at(-1).type, 'enrollment-complete');
  assert.deepEqual(f.messages.at(-1).embedding, a);
  assert.ok(f.messages.at(-1).templates.every(vector => vector[1] === 0));
});

test('robust consensus does not reject a coherent sample solely for one weak pair', () => {
  const a = [1, ...new Array(255).fill(0)];
  const b = [0.84, Math.sqrt(1 - 0.84 ** 2), ...new Array(254).fill(0)];
  const c = [0.84, -Math.sqrt(1 - 0.84 ** 2), ...new Array(254).fill(0)];
  assert.ok(b.reduce((sum, value, i) => sum + value * c[i], 0) < 0.45);
  const f = enrollmentFixture();
  f.segment(4.1, a); f.segment(4.1, b); f.segment(4.1, c);
  f.engine.flush({ sessionId: 'enrollment' });
  assert.equal(f.messages.at(-1).type, 'enrollment-complete');
  assert.equal(f.messages.at(-1).quality.rejectedSegments, 0);
  assert.equal(f.messages.at(-1).templates.length, 3);
});

test('a contaminated continuous turn is removed instead of averaging its incompatible chunks', () => {
  const a = [1, ...new Array(255).fill(0)], b = [0, 1, ...new Array(254).fill(0)];
  const f = enrollmentFixture();
  f.segment(1, a); f.segment(1, a);
  const retained = f.engine.enrollment.turns.at(-1).embedding;
  f.segment(1, b, 0.1, [], true, { gapMs: 0 });
  assert.equal(f.messages.at(-1).segments, 1);
  assert.equal(f.messages.at(-1).voicedMs, 1000);
  assert.equal(f.messages.at(-1).reason, 'inconsistent_sample');
  assert.ok(retained.every(value => value === 0));
  f.segment(1, a, 0.1, [], true, { gapMs: 0 });
  assert.equal(f.messages.at(-1).segments, 1);
  f.segment(4, a); f.segment(4, a); f.segment(4, a);
  f.engine.flush({ sessionId: 'enrollment' });
  assert.equal(f.messages.at(-1).type, 'enrollment-complete');
  assert.deepEqual(f.messages.at(-1).embedding, a);
});

test('templates retain bounded diverse normalized samples while all independent turns remain available', () => {
  const f = enrollmentFixture();
  for (let i = 0; i < 12; i++) {
    const vector = new Array(256).fill(0);
    vector[0] = 0.9; vector[i + 1] = Math.sqrt(1 - 0.9 ** 2);
    f.segment(1, vector);
  }
  f.engine.flush({ sessionId: 'enrollment' });
  const result = f.messages.at(-1);
  assert.equal(result.type, 'enrollment-complete');
  assert.equal(result.templates.length, 8);
  assert.equal(result.segments.length, 12);
  assert.equal(result.quality.segments, 12);
  assert.ok(result.templates.every(vector => Math.abs(Math.hypot(...vector) - 1) < 1e-6));
  assert.equal(new Set(result.templates.map(vector => vector.findIndex((value, i) => i && value > 0))).size, 8);
});

test('inconsistent segments can be retried within enrollment without averaging incompatible voices', () => {
  const a = [1, ...new Array(255).fill(0)], b = [0, 1, ...new Array(254).fill(0)];
  for (const sameTurn of [false, true]) {
    const f = enrollmentFixture();
    f.segment(4.1, a); f.segment(4.1, a);
    const before = f.engine.enrollment.voicedMs;
    if (sameTurn) f.segment(4.2, a, 0.1, [a, a, b]);
    else f.segment(4.1, b);
    assert.equal(f.messages.at(-1).type, 'enrollment-progress');
    assert.equal(f.messages.at(-1).reason, 'inconsistent_sample');
    assert.equal(f.messages.at(-1).voicedMs, before);
    assert.equal(f.engine.sessionId, 'enrollment');
    assert.doesNotMatch(f.messages.at(-1).message, /detected|multiple speakers/i);
    f.segment(4.1, a);
    f.engine.flush({ sessionId: 'enrollment' });
    const result = f.messages.at(-1);
    assert.equal(result.type, 'enrollment-complete');
    assert.deepEqual(result.embedding, a);
    assert.equal(result.quality.rejectedSegments, 1);
    assert.equal(result.segments.length, 3);
  }
});

test('canceling or replacing enrollment clears its accumulated evidence and ignores stale finish requests', () => {
  const f = enrollmentFixture();
  f.segment();
  const buffer = f.engine.audioBuffer, vector = f.engine.enrollment.vectors[0].embedding;
  f.engine.stop({ sessionId: 'stale' });
  assert.equal(f.engine.sessionId, 'enrollment');
  f.engine.start({ sessionId: 'game' });
  assert.equal(f.engine.enrollment, null);
  assert.ok(buffer.every(value => value === 0));
  assert.ok(vector.every(value => value === 0));
  f.engine.flush({ sessionId: 'enrollment' });
  assert.equal(f.engine.sessionId, 'game');
  assert.equal(f.messages.some(value => value.type === 'enrollment-complete'), false);
});

test('identification requires two distinct turns and four effective seconds without ASR or retained audio', () => {
  const f = enrollmentFixture('identification');
  const buffer = f.engine.audioBuffer;
  f.segment(2);
  assert.equal(f.messages.at(-1).canFinish, false);
  f.segment(2);
  const progress = f.messages.at(-2), result = f.messages.at(-1);
  assert.equal(progress.type, 'identification-progress');
  assert.equal(progress.sessionId, 'identification');
  assert.equal(progress.voicedMs, 4000);
  assert.equal(progress.requiredVoicedMs, 4000);
  assert.equal(progress.requiredSegments, 2);
  assert.equal(progress.progress, 1);
  assert.equal(progress.canFinish, true);
  assert.equal(result.type, 'identification-complete');
  assert.equal(result.sessionId, 'identification');
  assert.equal(result.modelVersion, SPEAKER_MODEL_VERSION);
  assert.equal(result.embedding.length, 256);
  assert.equal(Math.hypot(...result.embedding), 1);
  assert.deepEqual(result.quality, { segments: 2, voicedMs: 4000, minimumSimilarity: 1, rejectedSegments: 0,
    reason: '', rejectionReasons: {} });
  assert.equal(result.segments.length, 2);
  assert.ok(result.templates.length >= 1 && result.templates.length <= 8);
  assert.equal(f.transcriptions, 0);
  assert.equal(f.embeddingCalls, 2);
  assert.equal(f.engine.sessionId, null);
  assert.equal(f.engine.audioBuffer, null);
  assert.equal(f.engine.enrollment, null);
  assert.ok(buffer.every(value => value === 0));
  assert.ok(f.heap.every(value => value === 0));
  const messageCount = f.messages.length;
  f.engine.flush({ sessionId: 'identification' });
  f.engine.audio({ sessionId: 'identification', samples: new Float32Array(512), sampleOffset: 32000 });
  f.engine.stop({ sessionId: 'identification' });
  assert.equal(f.messages.length, messageCount, 'Late audio or finish cannot produce a duplicate identification');
});

test('identification progress uses accumulated accepted speech and clears retained vectors when it auto-completes', () => {
  const f = enrollmentFixture('identification');
  f.segment(1.2);
  const vector = f.engine.enrollment.vectors[0].embedding;
  assert.equal(f.messages.at(-1).type, 'identification-progress');
  assert.equal(f.messages.at(-1).voicedMs, 1200);
  assert.equal(f.messages.at(-1).progress, 0.3);
  assert.equal(f.messages.at(-1).canFinish, false);
  assert.equal(f.messages.some(value => value.type === 'identification-complete'), false);
  f.segment(2.8);
  assert.equal(f.messages.at(-1).type, 'identification-complete');
  assert.equal(f.messages.at(-1).quality.segments, 2);
  assert.equal(f.messages.at(-1).quality.voicedMs, 4000);
  assert.ok(vector.every(value => value === 0));
  assert.equal(f.transcriptions, 0);
});

test('identification rejects silent, short, quiet and clipped segments and reports insufficient speech on flush', () => {
  for (const [seconds, amplitude] of [[2, 0], [0.4, 0.1], [2, 0.0035], [2, 0.99]]) {
    const f = enrollmentFixture('identification');
    const buffer = f.engine.audioBuffer;
    f.segment(seconds, undefined, amplitude);
    assert.equal(f.messages.at(-1).type, 'identification-progress');
    assert.equal(f.messages.at(-1).progress, 0);
    assert.equal(f.messages.at(-1).voicedMs, 0);
    assert.ok(f.messages.at(-1).message.length > 0);
    assert.equal(f.engine.enrollment.rejectedSegments, 1);
    assert.equal(f.embeddingCalls, 0);
    f.engine.flush({ sessionId: 'identification' });
    assert.equal(f.messages.at(-1).type, 'identification-error');
    assert.equal(f.messages.at(-1).code, 'insufficient_speech');
    assert.equal(f.engine.sessionId, null);
    assert.equal(f.engine.enrollment, null);
    assert.ok(buffer.every(value => value === 0));
    assert.equal(f.transcriptions, 0);
  }
  const f = enrollmentFixture('identification');
  f.segment(1.99);
  f.engine.flush({ sessionId: 'identification' });
  assert.equal(f.messages.at(-1).code, 'insufficient_speech', 'Identification still needs two turns and four effective seconds');
});

test('identification can recover from an outlier first turn or an inconsistent long turn', () => {
  const a = [1, ...new Array(255).fill(0)], b = [0, 1, ...new Array(254).fill(0)];
  for (const sameTurn of [false, true]) {
    const f = enrollmentFixture('identification');
    let retained;
    if (sameTurn) f.segment(4.2, a, 0.1, [a, a, b]);
    else { f.segment(1, a); retained = f.engine.enrollment.vectors[0].embedding; f.segment(1, b); }
    assert.equal(f.messages.at(-1).type, 'identification-progress');
    assert.equal(f.messages.at(-1).reason, 'inconsistent_sample');
    assert.equal(f.engine.sessionId, 'identification');
    f.segment(3, b);
    if (sameTurn) f.segment(1, b);
    assert.equal(f.messages.at(-1).type, 'identification-complete');
    assert.deepEqual(f.messages.at(-1).embedding, b);
    if (retained) assert.ok(retained.every(value => value === 0));
    assert.equal(f.transcriptions, 0);
  }
});

test('invalid identification features produce a quality error and clear the partial recording', () => {
  for (const invalid of ['dimension', 'zero', 'nan']) {
    const f = enrollmentFixture('identification');
    f.segment(0.8);
    const buffer = f.engine.audioBuffer, retained = f.engine.enrollment.vectors[0].embedding;
    if (invalid === 'dimension') f.engine.module._vp_embed = () => 128;
    const vector = new Array(256).fill(0);
    if (invalid === 'nan') vector[0] = NaN;
    f.segment(1.2, vector);
    assert.equal(f.messages.at(-1).type, 'identification-error');
    assert.equal(f.messages.at(-1).code, 'invalid_voice_sample');
    assert.equal(f.engine.sessionId, null);
    assert.equal(f.engine.enrollment, null);
    assert.ok(buffer.every(value => value === 0));
    assert.ok(retained.every(value => value === 0));
    assert.ok(f.heap.every(value => value === 0));
    assert.equal(f.transcriptions, 0);
  }
});

test('identification flush drains the last captured segment and never emits game results', () => {
  const f = enrollmentFixture('identification');
  f.segment(2);
  f.segment(2.01, undefined, 0.1, [], false);
  assert.equal(f.messages.length, 2);
  f.engine.flush({ sessionId: 'identification' });
  assert.equal(f.messages.at(-1).type, 'identification-complete');
  assert.equal(f.messages.at(-1).quality.voicedMs, 4010);
  assert.equal(f.messages.filter(value => value.type === 'identification-complete').length, 1);
  assert.equal(f.messages.some(value => ['flushed', 'utterance', 'enrollment-complete'].includes(value.type)), false);
  assert.equal(f.transcriptions, 0);
});

test('canceling or replacing identification zeroes evidence and fences delayed commands from other sessions', () => {
  for (const replace of [false, true]) {
    const f = enrollmentFixture('identification');
    f.segment(1);
    const buffer = f.engine.audioBuffer, vector = f.engine.enrollment.vectors[0].embedding;
    f.engine.stop({ sessionId: 'stale' });
    f.engine.flush({ sessionId: 'stale' });
    f.engine.audio({ sessionId: 'stale', samples: new Float32Array(512), sampleOffset: 16000 });
    assert.equal(f.engine.sessionId, 'identification');
    assert.equal(f.engine.enrollment.voicedMs, 1000);
    if (replace) f.engine.start({ sessionId: 'next-enrollment', mode: 'enrollment' });
    else f.engine.stop({ sessionId: 'identification' });
    assert.ok(buffer.every(value => value === 0));
    assert.ok(vector.every(value => value === 0));
    const messageCount = f.messages.length;
    f.engine.flush({ sessionId: 'identification' });
    f.engine.stop({ sessionId: 'identification' });
    f.engine.audio({ sessionId: 'identification', samples: new Float32Array(512), sampleOffset: 16000 });
    assert.equal(f.messages.length, messageCount);
    assert.equal(f.engine.sessionId, replace ? 'next-enrollment' : null);
    assert.equal(f.engine.enrollment?.mode ?? null, replace ? 'enrollment' : null);
    assert.equal(f.messages.some(value => value.type === 'identification-complete'), false);
    f.engine.stop({});
    assert.ok(f.heap.every(value => value === 0));
  }
});

test('the worker reports identification startup failures with their capture session and error type', async () => {
  const messages = [];
  const context = { importScripts() {}, postMessage: message => messages.push(message) };
  context.self = context;
  vm.runInNewContext(fs.readFileSync(path.join(root, 'web/multiplayer-worker.js'), 'utf8'), context);
  context.onmessage({ data: { type: 'start', sessionId: 'not-ready', mode: 'identification' } });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(messages.length, 1);
  assert.equal(messages[0].type, 'identification-error');
  assert.equal(messages[0].code, 'recognition_failed');
  assert.equal(messages[0].sessionId, 'not-ready');
  assert.match(messages[0].message, /not ready/);
});

function wavSamples(file) {
  const wav = fs.readFileSync(file);
  let format;
  let data;
  for (let offset = 12; offset + 8 < wav.length;) {
    const id = wav.toString('ascii', offset, offset + 4);
    const size = wav.readUInt32LE(offset + 4);
    if (id === 'fmt ') format = { type: wav.readUInt16LE(offset + 8), channels: wav.readUInt16LE(offset + 10), rate: wav.readUInt32LE(offset + 12), bits: wav.readUInt16LE(offset + 22) };
    if (id === 'data') data = wav.subarray(offset + 8, offset + 8 + size);
    offset += 8 + size + size % 2;
  }
  assert.equal(format.type, 1);
  assert.equal(format.bits, 16);
  const samples = new Float32Array(data.length / (2 * format.channels));
  for (let i = 0; i < samples.length; i++) for (let c = 0; c < format.channels; c++) samples[i] += data.readInt16LE((i * format.channels + c) * 2) / 32768 / format.channels;
  return resample(samples, format.rate);
}

test('real WASM recognizes words and keeps held-out same-recording voice segments consistent', { skip: process.env.VOICE_POP_REAL_RUNTIME !== '1', timeout: 120000 }, async (t) => {
  const directory = path.join(root, 'build/multiplayer');
  const manifest = JSON.parse(fs.readFileSync(path.join(directory, 'manifest.json'), 'utf8'));
  const assets = Object.fromEntries(manifest.assets.map((asset) => {
    const buffer = fs.readFileSync(path.join(directory, asset.url));
    return [asset.id, buffer.buffer.slice(buffer.byteOffset, buffer.byteOffset + buffer.byteLength)];
  }));
  const factory = require(path.join(directory, 'voice-pop-runtime.js'));
  const messages = [];
  const engine = new VoicePopInference((event) => messages.push(event), async () => factory({ wasmBinary: new Uint8Array(assets['runtime-wasm']), print() {}, printErr() {} }));
  await engine.init({ assets, runtime: manifest.runtime });
  assert.equal(messages[0].type, 'ready');
  engine.start({ sessionId: 'real-audio', vocabulary: ['cat', 'dog', 'fish', 'duck', 'cow'] });
  const word = wavSamples(path.join(root, 'assets/audio/voice/word-cat.wav'));
  const audio = new Float32Array(3200 + word.length + 16000);
  audio.set(word, 3200);
  for (let sampleOffset = 0; sampleOffset < audio.length; sampleOffset += 512) engine.audio({ sessionId: 'real-audio', samples: audio.slice(sampleOffset, sampleOffset + 512), sampleOffset });
  engine.flush({ sessionId: 'real-audio' });
  const words = messages.filter((message) => message.type === 'utterance');
  assert.ok(words.some((word) => word.text === 'cat'), `Expected cat, got ${words.map((word) => word.text).join(' ')}`);
  for (const word of words) {
    assert.equal(word.embedding.length, 256);
    assert.ok(word.embedding.every(Number.isFinite));
    assert.ok(Math.abs(Math.hypot(...word.embedding) - 1) < 1e-5);
    assert.ok(word.startMs >= 0 && word.endMs > word.startMs && word.endMs <= audio.length / 16);
  }
  const feed = (sessionId, chunks, flush = true) => {
    const joined = new Float32Array(chunks.reduce((sum, chunk) => sum + chunk.length, 0));
    let offset = 0;
    for (const chunk of chunks) { joined.set(chunk, offset); offset += chunk.length; }
    for (let sampleOffset = 0; sampleOffset < joined.length; sampleOffset += 512)
      engine.audio({ sessionId, samples: joined.slice(sampleOffset, sampleOffset + 512), sampleOffset });
    if (flush) engine.flush({ sessionId });
  };
  const rawResults = [], originalTranscribe = engine.module._vp_transcribe;
  engine.module._vp_transcribe = (...args) => {
    const pointer = originalTranscribe(...args);
    rawResults.push(JSON.parse(engine.module.UTF8ToString(pointer)).text.trim().toLowerCase());
    return pointer;
  };
  engine.start({ sessionId: 'real-biased-silence', vocabulary: ['cat', 'dog', 'fish', 'duck', 'cow'] });
  feed('real-biased-silence', [new Float32Array(32000)]);
  assert.equal(messages.some(event => event.sessionId === 'real-biased-silence' && ['utterance', 'feedback'].includes(event.type)), false,
    'Vocabulary bias does not turn silence into speech or diagnostic noise');
  assert.equal(rawResults.length, 0);
  engine.start({ sessionId: 'real-off-vocabulary', vocabulary: ['moon', 'sun', 'star', 'cloud', 'rain'] });
  feed('real-off-vocabulary', [new Float32Array(3200), word, new Float32Array(16000)]);
  assert.ok(rawResults.includes('cat'), 'A word outside the hinted vocabulary remains available to the decoder');
  const recording = wavSamples(path.join(root, 'assets/audio/voice/welcome.wav'));
  const catalog = [...new Set([...fs.readFileSync(path.join(root, 'scripts/game_data.gd'), 'utf8')
    .matchAll(/"words": \[([^\]]+)\]/g)]
    .flatMap(match => [...match[1].matchAll(/"([a-z]+)"/g)].map(value => value[1])))];
  assert.ok(catalog.length >= 200, 'Exercise the complete round vocabulary, not only a few favorable hints');
  for (const [sessionId, vocabulary] of [
    ['real-biased-narration', ['cat', 'dog', 'fish', 'duck', 'cow']],
    ['real-catalog-narration', catalog]
  ]) {
    rawResults.length = 0;
    engine.start({ sessionId, vocabulary });
    feed(sessionId, [new Float32Array(3200), recording, new Float32Array(16000)]);
    assert.equal(rawResults.join(' '), 'find three pairs some cards have no match a picture or a word',
      'Unrelated narration remains ordinary speech with a small or full round vocabulary');
  }
  rawResults.length = 0;
  engine.start({ sessionId: 'real-catalog-octopus', vocabulary: catalog });
  feed('real-catalog-octopus', [new Float32Array(3200), wavSamples(path.join(root, 'assets/audio/voice/word-octopus.wav')), new Float32Array(16000)]);
  assert.deepEqual(rawResults, ['octopus'], 'Actual BPE context bias resolves this fixture beyond the unassisted octapus transcription');
  const originalEmbed = engine.module._vp_embed;
  engine.module._vp_embed = () => 0;
  engine.start({ sessionId: 'real-unconfirmed-word', vocabulary: ['cat'] });
  feed('real-unconfirmed-word', [new Float32Array(3200), word, new Float32Array(16000)]);
  const unconfirmed = messages.filter(event => event.sessionId === 'real-unconfirmed-word' && event.type === 'feedback');
  assert.ok(unconfirmed.some(event => event.text === 'cat' && event.reason === 'identity_unconfirmed'));
  assert.equal(messages.some(event => event.sessionId === 'real-unconfirmed-word' && event.type === 'utterance'), false);
  engine.module._vp_embed = originalEmbed;
  engine.module._vp_transcribe = originalTranscribe;
  let enrollmentTranscriptions = 0;
  const transcribe = engine.module._vp_transcribe;
  engine.module._vp_transcribe = (...args) => { enrollmentTranscriptions++; return transcribe(...args); };
  engine.start({ sessionId: 'real-short-enrollment', mode: 'enrollment' });
  feed('real-short-enrollment', [word, new Float32Array(16000)]);
  assert.equal(messages.at(-1).type, 'enrollment-error');
  assert.equal(messages.at(-1).code, 'insufficient_speech');
  engine.start({ sessionId: 'real-phrase-enrollment', mode: 'enrollment', maxTimeMs: 60000 });
  const captured = engine.audioBuffer;
  // Repeated source audio is only a deterministic pipeline smoke fixture. The
  // held-out half never enters enrollment; this does not measure human accuracy.
  let split = 0, quietest = Infinity;
  for (let offset = Math.floor(recording.length * 0.4); offset < recording.length * 0.6; offset += 160) {
    const energy = recording.subarray(offset, offset + 160).reduce((sum, value) => sum + value * value, 0);
    if (energy < quietest) { quietest = energy; split = offset; }
  }
  const enrollmentPhrase = recording.slice(0, split), heldOutPhrase = recording.slice(split);
  const phrases = Array.from({ length: 8 }, () => [enrollmentPhrase, new Float32Array(8000)]).flat();
  feed('real-phrase-enrollment', phrases);
  const enrollment = messages.at(-1);
  assert.equal(enrollment.type, 'enrollment-complete', JSON.stringify(enrollment));
  assert.ok(enrollment.quality.segments >= 3);
  assert.ok(enrollment.quality.voicedMs >= 12000);
  assert.equal(enrollment.embedding.length, 256);
  assert.ok(Math.abs(Math.hypot(...enrollment.embedding) - 1) < 1e-5);
  assert.equal(enrollment.modelVersion, SPEAKER_MODEL_VERSION);
  assert.equal(enrollmentTranscriptions, 0, 'Enrollment exercises the actual VAD and speaker model without running ASR');
  assert.ok(captured.every(value => value === 0), 'Completed enrollment clears its accumulated recording');
  assert.equal(engine.audioBuffer, null);
  assert.equal(engine.enrollment, null);
  engine.start({ sessionId: 'real-short-identification', mode: 'identification' });
  feed('real-short-identification', [word, new Float32Array(16000)]);
  assert.equal(messages.at(-1).type, 'identification-error');
  assert.equal(messages.at(-1).code, 'insufficient_speech');
  engine.start({ sessionId: 'real-phrase-identification', mode: 'identification' });
  const identificationAudio = engine.audioBuffer;
  feed('real-phrase-identification', Array.from({ length: 4 }, () => [heldOutPhrase, new Float32Array(8000)]).flat(), false);
  const identification = messages.at(-1);
  assert.equal(identification.type, 'identification-complete', JSON.stringify(identification));
  assert.ok(identification.quality.segments >= 2);
  assert.ok(identification.quality.voicedMs >= 4000);
  assert.equal(identification.embedding.length, 256);
  assert.ok(Math.abs(Math.hypot(...identification.embedding) - 1) < 1e-5);
  assert.equal(identification.modelVersion, SPEAKER_MODEL_VERSION);
  assert.equal(enrollment.segments.length, enrollment.quality.segments);
  assert.equal(identification.segments.length, identification.quality.segments);
  const similarity = (a, b) => a.reduce((sum, value, i) => sum + value * b[i], 0);
  const similarities = identification.segments.map(segment => similarity(enrollment.embedding, segment.embedding));
  t.diagnostic(`Same-recording held-out cosine: aggregate=${similarity(enrollment.embedding, identification.embedding).toFixed(4)}, segments=${similarities.map(value => value.toFixed(4)).join(', ')}; enrollment=${enrollment.quality.voicedMs}ms/${enrollment.quality.segments} turns, identification=${identification.quality.voicedMs}ms/${identification.quality.segments} turns.`);
  assert.ok(similarities.every(value => value >= 0.6), 'Held-out natural speech from the same source recording keeps a comparable speaker vector');
  assert.ok(similarity(enrollment.embedding, identification.embedding) >= 0.6);
  const savedIdentity = { id: 'wasm-narrator', name: 'Narrator', emoji: '🐥' };
  const profiles = identificationProfiles([{ ...savedIdentity, embedding: enrollment.embedding,
    templates: enrollment.templates, modelVersion: enrollment.modelVersion }]);
  assert.equal(profiles.length, 1);
  assert.equal(profiles[0].templates.length, enrollment.templates.length);
  const aggregateMatch = matchVoiceProfile(identification.embedding, profiles);
  const turnMatches = identification.segments.map(segment => matchVoiceProfile(segment.embedding, profiles));
  assert.deepEqual(aggregateMatch.profile, savedIdentity, 'The production template matcher recognizes the held-out aggregate');
  assert.ok(turnMatches.filter(match => match.profile?.id === savedIdentity.id).length >= 2,
    'At least two independent held-out turns also match the actual enrollment templates');
  t.diagnostic(`Production template scores: aggregate=${aggregateMatch.similarity.toFixed(4)}, segments=${turnMatches.map(match => match.similarity.toFixed(4)).join(', ')}; templates=${profiles[0].templates.length}.`);
  assert.equal(enrollmentTranscriptions, 0, 'Enrollment and identification use the actual VAD and speaker model without ASR');
  assert.ok(identificationAudio.every(value => value === 0));
  assert.equal(engine.audioBuffer, null);
  assert.equal(engine.enrollment, null);
  assert.equal(engine.sessionId, null);
  engine.module._vp_destroy();
  engine.module._free(engine.pointer);
});
