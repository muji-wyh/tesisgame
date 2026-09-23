'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { VoicePopResampler } = require('../web/multiplayer-audio.js');
const { VoicePopInference, wordsFromResult } = require('../web/multiplayer-worker.js');
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

test('adjacent words receive their own disjoint audio embeddings instead of one mixed speaker vector', () => {
  const messages = [];
  const clips = [];
  const heap = new Float32Array(65536);
  let available = true;
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
    UTF8ToString: () => JSON.stringify({ text: 'cat dog', tokens: ['▁CAT', '▁DOG'], timestamps: [0.2, 0.6] }),
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
  assert.equal(run(1.1).length, 0);
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

test('real WASM recognizes a repository word recording and produces a unit-length 256-dimensional voice embedding', { skip: process.env.VOICE_POP_REAL_RUNTIME !== '1', timeout: 120000 }, async () => {
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
  engine.start({ sessionId: 'real-audio' });
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
  engine.module._vp_destroy();
  engine.module._free(engine.pointer);
});
