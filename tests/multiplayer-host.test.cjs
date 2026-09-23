const test = require('node:test');
const assert = require('node:assert/strict');
const { createHash, webcrypto } = require('node:crypto');
const { VoicePopMultiplayer, SPEAKER_MODEL_VERSION, identificationProfiles, matchVoiceProfile } = require('../web/multiplayer-host.js');

const voice = index => Array.from({ length: 256 }, (_, item) => item === index ? 1 : 0);
const voiceUsers = () => [
  { id: 'ada', name: 'Ada', emoji: '🐱', embedding: voice(0), modelVersion: SPEAKER_MODEL_VERSION },
  { id: 'ben', name: 'Ben', emoji: '🐶', embedding: voice(1), modelVersion: SPEAKER_MODEL_VERSION }
];
const identificationResult = (sessionId, embedding = voice(0), extra = {}) => ({
  type: 'identification-complete', sessionId, embedding, modelVersion: SPEAKER_MODEL_VERSION,
  templates: [embedding.slice(), embedding.slice()],
  segments: [{ embedding: embedding.slice(), voicedMs: 2200 }, { embedding: embedding.slice(), voicedMs: 2200 }],
  quality: { segments: 2, voicedMs: 4400, minimumSimilarity: 1, rejectedSegments: 0 }, ...extra
});

function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}

async function until(predicate, description) {
  const deadline = performance.now() + 3000;
  while (performance.now() < deadline) {
    if (predicate()) return;
    // Cache validation uses real WebCrypto threads. A fixed number of empty
    // event-loop turns can finish before a digest when inference runs alongside.
    await new Promise(resolve => setTimeout(resolve, 5));
  }
  assert.fail(description || 'Expected asynchronous state did not arrive');
}

function fixture(options = {}) {
  const origin = 'https://game.example/';
  const bytes = [Uint8Array.from([1, 2, 3, 4]), Uint8Array.from([9, 8, 7, 6, 5, 4])];
  const manifest = {
    version: 'fixture-v1', runtime: { format: 'fixture' },
    assets: bytes.map((data, index) => ({ id: `model-${index}`, url: `model-${index}.bin`,
      bytes: data.byteLength, sha256: createHash('sha256').update(data).digest('hex') }))
  };
  options.manifest?.(manifest);
  const workers = [], fetches = [], captures = [], captureRequests = [], operations = [];
  const stored = new Map(), cacheDeletes = [], cacheWrites = [];
  const timers = new Map();
  let now = 0, nextTimer = 0;
  const cache = {
    async match(url) {
      if (options.matchFails) throw new Error('Private browsing cache failure');
      return stored.get(url)?.clone();
    },
    async put(url, response) {
      cacheWrites.push(url);
      if (options.putFails) throw new Error('Quota exceeded');
      stored.set(url, response.clone());
    },
    async delete(url) { cacheDeletes.push(url); stored.delete(url); }
  };
  class Worker {
    constructor(url) { this.url = url; this.messages = []; this.terminated = false; workers.push(this); }
    postMessage(message, transfer) {
      this.messages.push({ message, transfer });
      operations.push(`worker:${message.type}`);
      if (message.type === 'init' && options.autoReady !== false)
        queueMicrotask(() => this.emit({ type: 'ready' }));
      if (message.type === 'ping' && options.autoPong !== false)
        queueMicrotask(() => this.emit({ type: 'pong', requestId: message.requestId }));
    }
    emit(data) { this.onmessage?.({ data }); }
    error(message) { this.onerror?.({ message }); }
    terminate() { this.terminated = true; operations.push('worker:terminate'); }
  }
  const env = {
    isSecureContext: true, Worker, WebAssembly, crypto: webcrypto, AbortController, Response,
    navigator: { mediaDevices: { getUserMedia() {} } }, AudioContext() {}, AudioWorkletNode() {},
    document: { baseURI: origin },
    setTimeout(callback, delay) {
      const id = ++nextTimer;
      timers.set(id, { callback, at: now + delay });
      return id;
    },
    clearTimeout(id) { timers.delete(id); },
    caches: { async open() { if (options.openFails) throw new Error('Storage unavailable'); return cache; } },
    async fetch(url, request) {
      fetches.push({ url, request });
      if (url.endsWith('manifest.json')) return new Response(JSON.stringify(manifest), { status: 200 });
      const index = manifest.assets.findIndex(asset => new URL(asset.url, origin + 'multiplayer/manifest.json').href === url);
      assert.ok(index >= 0, `Unexpected model fetch: ${url}`);
      if (options.fetchFails) return new Response('', { status: 503 });
      let payload = bytes[index];
      if (options.corrupt === index) payload = Uint8Array.from(payload, value => value + 1);
      if (options.truncate === index) payload = payload.slice(0, -1);
      if (options.oversize === index) payload = Uint8Array.from([...payload, 0]);
      if (options.noStream) return { ok: true, arrayBuffer: async () => payload.buffer.slice(0) };
      return new Response(new ReadableStream({
        start(controller) {
          const midpoint = Math.floor(payload.length / 2);
          controller.enqueue(payload.slice(0, midpoint));
          controller.enqueue(payload.slice(midpoint));
          controller.close();
        }
      }), { status: 200 });
    },
    VoicePopCapture: {
      create(config) {
        operations.push('capture:create');
        captureRequests.push(config);
        if (options.captureThrows) throw options.captureThrows;
        const capture = {
          stopped: false,
          async flush() {
            operations.push('capture:flush');
            if (options.flushFrame) config.onAudio({ samples: new Float32Array([0.1]), sampleOffset: 160 });
            if (options.flushGate) return options.flushGate.promise;
          },
          stop() {
            operations.push('capture:stop');
            if (options.stopFails) throw new Error('Native microphone did not stop');
            this.stopped = true;
          }
        };
        captures.push(capture);
        if (options.captureGate) return options.captureGate.promise;
        if (options.captureRejects) return Promise.reject(options.captureRejects);
        return Promise.resolve(capture);
      }
    }
  };
  const host = new VoicePopMultiplayer({ env });
  const states = [];
  host.observe(state => states.push(state));
  return {
    host, env, options, manifest, bytes, states, workers, fetches, captures, captureRequests,
    operations, stored, cacheDeletes, cacheWrites, timers,
    advance(ms) {
      now += ms;
      for (const [id, timer] of [...timers]) {
        if (timer.at <= now) { timers.delete(id); timer.callback(); }
      }
    },
    get worker() { return workers.at(-1); },
    frame(request = captureRequests.length - 1) {
      captureRequests[request].onAudio({ samples: new Float32Array([0.1, -0.1]), sampleOffset: 0 });
    }
  };
}

test('preparation reports actual byte progress and cannot become ready before runtime warmup', async () => {
  const f = fixture({ autoReady: false });
  const first = f.host.prepare(), second = f.host.prepare();
  assert.equal(first, second, 'Concurrent requests share one download and initialization');
  await until(() => f.worker?.messages.length, 'A downloaded model should initialize a worker');
  assert.equal(f.workers.length, 1);
  assert.equal(f.fetches.length, 3, 'One manifest and each model are fetched once');
  assert.ok(f.states.some(state => state.loaded === 2 && state.total === 10 && state.progress === 0.2));
  assert.ok(f.states.some(state => state.loaded === 7 && state.total === 10 && state.progress === 0.7));
  assert.equal(f.host.state.progress, 1);
  assert.equal(f.host.state.status, 'initializing');
  assert.equal(f.host.isReady(), false, '100 percent downloaded is not initialized');
  assert.ok(f.states.every(state => state.status !== 'ready'));
  assert.equal(f.captures.length, 0, 'Preparation never requests a microphone');
  f.worker.emit({ type: 'ready' });
  assert.equal(await first, true);
  assert.equal(await f.host.prepare(), true);
  assert.equal(f.workers.length, 1, 'Ready preparation is idempotent');
  assert.equal(f.host.isReady(), true);
  assert.equal(f.timers.size, 0, 'Completed requests and warmup clear timeout handles');
});

test('hash failures and incomplete or oversized downloads never advertise readiness', async () => {
  for (const option of [{ corrupt: 0 }, { truncate: 0 }, { oversize: 0 }, { fetchFails: true }]) {
    const f = fixture(option);
    assert.equal(await f.host.prepare(), false);
    assert.equal(f.host.state.status, 'error');
    assert.equal(f.host.isReady(), false);
    assert.equal(f.workers.length, 0);
    assert.equal(f.cacheWrites.length, 0, 'Only fully verified assets enter cache');
    assert.match(f.host.state.message, /verification|interrupted|size changed|503/i);
    assert.equal(f.timers.size, 0);
  }
});

test('initialization failure at 100 percent is an error and retry creates a fresh worker', async () => {
  const f = fixture({ autoReady: false });
  const loading = f.host.prepare();
  await until(() => f.worker?.messages.length);
  f.worker.emit({ type: 'error', message: 'WASM model is incompatible' });
  assert.equal(await loading, false);
  assert.equal(f.host.state.progress, 1);
  assert.equal(f.host.state.status, 'error');
  assert.equal(f.workers[0].terminated, true);
  const retry = f.host.prepare();
  await until(() => f.workers.length === 2 && f.worker.messages.length);
  f.worker.emit({ type: 'ready' });
  assert.equal(await retry, true);
  assert.equal(f.fetches.filter(request => !request.url.endsWith('manifest.json')).length, 2,
    'Verified cached models are reused on initialization retry');
});

test('optional cache failures never prevent in-memory preparation', async () => {
  for (const option of [{ openFails: true }, { matchFails: true }, { putFails: true }]) {
    const f = fixture(option);
    assert.equal(await f.host.prepare(), true);
    assert.equal(f.host.isReady(), true);
    assert.equal(f.fetches.length, 3);
  }
  const noStream = fixture({ noStream: true });
  assert.equal(await noStream.host.prepare(), true, 'The non-streaming fetch fallback verifies models too');
  assert.equal(noStream.host.state.loaded, 10);
});

test('cached bytes are hash-verified; corrupt entries are replaced and valid entries skip network download', async () => {
  const f = fixture();
  const urls = f.manifest.assets.map(asset => new URL(asset.url, 'https://game.example/multiplayer/manifest.json').href);
  f.stored.set(urls[0], new Response(Uint8Array.from([4, 3, 2, 1])));
  f.stored.set(urls[1], new Response(f.bytes[1]));
  assert.equal(await f.host.prepare(), true);
  assert.deepEqual(f.cacheDeletes, [urls[0]]);
  assert.deepEqual(f.cacheWrites, [urls[0]]);
  assert.deepEqual(f.fetches.map(request => request.url), ['https://game.example/multiplayer/manifest.json', urls[0]]);
  assert.equal(f.host.state.loaded, f.host.state.total);
});

test('unsupported devices and invalid manifests fail without touching microphone or starting workers', async () => {
  for (const missing of ['Worker', 'AudioWorkletNode', 'crypto']) {
    const f = fixture();
    delete f.env[missing];
    assert.equal(await f.host.prepare(), false);
    assert.equal(f.host.state.status, 'unsupported');
    assert.equal(f.fetches.length, 0);
  }
  const nonSimd = fixture();
  nonSimd.env.WebAssembly = { validate: () => false };
  assert.equal(await nonSimd.host.prepare(), false);
  assert.equal(nonSimd.host.state.status, 'unsupported');
  assert.equal(nonSimd.fetches.length, 0, 'An incompatible engine does not download the models');
  for (const mutate of [
    manifest => { manifest.version = '../unsafe'; },
    manifest => { manifest.assets[0].sha256 = 'not-a-hash'; },
    manifest => { manifest.assets[1].id = manifest.assets[0].id; },
    manifest => { manifest.assets[0].url = 'https://other.example/model'; }
  ]) {
    const f = fixture({ manifest: mutate });
    assert.equal(await f.host.prepare(), false);
    assert.equal(f.host.state.status, 'error');
    assert.equal(f.workers.length, 0);
    assert.equal(f.captures.length, 0);
  }
});

test('permission waits do not start a round; canceling pending permission closes late capture and fences audio', async () => {
  const gate = deferred();
  const f = fixture({ captureGate: gate });
  await f.host.prepare();
  let starts = 0;
  const pending = f.host.start({ sessionId: 'round-a', onStarted() { starts++; } });
  assert.equal(f.captureRequests.length, 1, 'Capture begins synchronously in the click gesture');
  f.frame();
  assert.equal(starts, 0);
  assert.equal(f.worker.messages.some(({ message }) => message.type === 'audio'), false);
  assert.equal(f.host.stop(), true);
  await assert.rejects(f.host.start({ sessionId: 'round-b' }), /previous microphone request/i);
  gate.resolve(f.captures[0]);
  assert.equal(await pending, false);
  assert.equal(f.captures[0].stopped, true);
  f.frame();
  assert.equal(starts, 0, 'The canceled permission callback cannot start a new round');
  assert.equal(f.worker.messages.some(({ message }) => message.type === 'audio'), false);
});

test('queued audio is sent only after actual start and completed sessions reject all stale events and frames', async () => {
  const gate = deferred();
  const f = fixture({ captureGate: gate });
  await f.host.prepare();
  const received = [];
  const pending = f.host.start({ sessionId: 'round-a', elapsedMs: 4321, onStarted() { f.operations.push('game:started'); },
    onEvent(event) { received.push(event); } });
  f.frame();
  gate.resolve(f.captures[0]);
  assert.equal(await pending, true);
  assert.ok(f.operations.indexOf('game:started') < f.operations.indexOf('worker:audio'));
  assert.equal(f.worker.messages.find(({ message }) => message.type === 'start').message.timeOffsetMs, 4321);
  f.worker.emit({ type: 'utterance', sessionId: 'stale', text: 'dog' });
  f.worker.emit({ type: 'utterance', sessionId: 'round-a', text: 'cat' });
  assert.equal(received.length, 1);
  f.host.stop();
  const count = f.worker.messages.length;
  f.frame();
  f.worker.emit({ type: 'utterance', sessionId: 'round-a', text: 'cat' });
  assert.equal(received.length, 1);
  assert.equal(f.worker.messages.length, count, 'Stopped capture callbacks never post audio');
});

test('flush forwards the final audio before stopping capture and signaling completion', async () => {
  const f = fixture({ flushFrame: true });
  await f.host.prepare();
  const flushed = [], utterances = [];
  await f.host.start({ sessionId: 'settling', onFlushed: event => flushed.push(event), onEvent: event => utterances.push(event) });
  f.operations.length = 0;
  await f.host.flush();
  assert.deepEqual(f.operations, ['capture:flush', 'worker:audio', 'capture:stop', 'worker:flush']);
  f.frame();
  assert.equal(f.operations.at(-1), 'worker:flush', 'No live audio is accepted after the deadline flush');
  f.worker.emit({ type: 'utterance', sessionId: 'settling', text: 'cat' });
  f.worker.emit({ type: 'flushed', sessionId: 'old' });
  f.worker.emit({ type: 'flushed', sessionId: 'settling' });
  assert.equal(utterances.length, 1, 'Recognition of captured audio can settle after microphone stop');
  assert.equal(flushed.length, 1, 'Only the current session can complete settlement');
  await f.host.flush();
  assert.equal(f.operations.filter(value => value === 'worker:flush').length, 1);
});

test('a pending flush is invalidated by stop and cannot flush a replacement round', async () => {
  const gate = deferred();
  const f = fixture({ flushGate: gate });
  await f.host.prepare();
  await f.host.start({ sessionId: 'a' });
  const flushing = f.host.flush();
  f.host.stop();
  await f.host.start({ sessionId: 'b' });
  gate.resolve();
  await flushing;
  assert.equal(f.host.session.sessionId, 'b');
  assert.equal(f.worker.messages.some(({ message }) => message.type === 'flush'), false);
  assert.equal(f.captures[1].stopped, false);
});

test('ready probes are correlated and timeouts clear a dead worker and notify the active round', async () => {
  const f = fixture({ autoPong: false });
  assert.equal(await f.host.verifyReady(), false);
  await f.host.prepare();
  const probe = f.host.verifyReady();
  const ping = f.worker.messages.at(-1).message;
  let complete = false;
  probe.then(() => { complete = true; });
  f.worker.emit({ type: 'pong', requestId: ping.requestId + 1 });
  await Promise.resolve();
  assert.equal(complete, false, 'Unrelated pong cannot satisfy the readiness probe');
  f.worker.emit({ type: 'pong', requestId: ping.requestId });
  assert.equal(await probe, true);
  const errors = [];
  await f.host.start({ sessionId: 'active', onError: error => errors.push(error.message) });
  const timeout = f.host.verifyReady();
  f.advance(5000);
  assert.equal(await timeout, false);
  assert.equal(f.host.state.status, 'error');
  assert.equal(f.host.worker, null);
  assert.equal(f.captures[0].stopped, true);
  assert.equal(errors.length, 1);
  assert.match(errors[0], /did not respond/i);
});

test('microphone errors retain ready models and reject capture without starting a round', async () => {
  const denied = Object.assign(new Error('Permission denied'), { name: 'NotAllowedError' });
  for (const option of [{ captureRejects: denied }, { captureThrows: denied }]) {
    const f = fixture(option);
    await f.host.prepare();
    let started = false;
    await assert.rejects(f.host.start({ sessionId: 'denied', onStarted() { started = true; } }), { name: 'NotAllowedError' });
    assert.equal(started, false);
    assert.equal(f.host.session, null);
    assert.equal(f.host.isReady(), true, 'Permission errors do not redownload or mislabel healthy models');
  }
  const f = fixture();
  await f.host.prepare();
  const errors = [];
  await f.host.start({ sessionId: 'active', onError: error => errors.push(error) });
  f.captureRequests[0].onError(new Error('Audio device disconnected'));
  assert.equal(errors.length, 1);
  f.host.stop();
  f.captureRequests[0].onError(new Error('Old audio callback'));
  assert.equal(errors.length, 1);
});

test('failed microphone shutdown prevents opening a replacement capture', async () => {
  const f = fixture({ stopFails: true });
  await f.host.prepare();
  await f.host.start({ sessionId: 'old' });
  await assert.rejects(f.host.start({ sessionId: 'new' }), /stop|microphone|close/i);
  assert.equal(f.captures.length, 1, 'A still-open microphone cannot be replaced with another capture');
});

test('canceling permission retains a late capture whose physical microphone cannot be released', async () => {
  const gate = deferred();
  const f = fixture({ captureGate: gate, stopFails: true });
  await f.host.prepare();
  const pending = f.host.start({ sessionId: 'canceled-permission' });
  f.host.stop();
  const rejected = assert.rejects(pending, /microphone|stop|release/i);
  gate.resolve(f.captures[0]);
  await rejected;
  assert.equal(f.host.capture, f.captures[0], 'The failed cleanup remains reachable for another stop attempt');
  assert.equal(f.host.state.microphoneBlocked, true, 'A late grant publishes a visible release failure even after its editor closed');
  assert.match(f.host.state.microphoneMessage, /microphone.*stop/i);
  assert.equal(f.host.state.status, 'ready', 'A failed physical release does not mislabel healthy models');
  assert.equal(f.host.stop(), false, 'Cancellation must not manufacture successful physical release');
  await assert.rejects(f.host.start({ sessionId: 'unsafe-replacement' }), /stop|microphone|close/i);
  assert.equal(f.captures.length, 1);
  f.options.stopFails = false;
  assert.equal(f.host.stop(), true);
  assert.equal(f.host.state.microphoneBlocked, false);
  assert.equal(f.host.state.microphoneMessage, '');
});

test('a terminated worker cannot mark a retry ready or fail the replacement worker', async () => {
  const f = fixture({ autoReady: false });
  const first = f.host.prepare();
  await until(() => f.worker?.messages.length);
  const stale = f.worker;
  stale.error('First runtime failed');
  assert.equal(await first, false);
  const retry = f.host.prepare();
  await until(() => f.workers.length === 2 && f.worker.messages.length);
  const current = f.worker;
  stale.emit({ type: 'ready' });
  await Promise.resolve();
  await Promise.resolve();
  assert.equal(f.host.isReady(), false, 'A stale ready message cannot bypass replacement warmup');
  stale.error('Delayed old error');
  assert.equal(f.host.worker, current, 'A stale worker failure cannot tear down its replacement');
  current.emit({ type: 'ready' });
  assert.equal(await retry, true);
});

test('synchronous worker transport failures invalidate readiness without leaking waiters or opening capture', async () => {
  const probe = fixture();
  await probe.host.prepare();
  probe.worker.postMessage = () => { throw new Error('Worker transport closed'); };
  assert.equal(await probe.host.verifyReady(), false);
  assert.equal(probe.host.state.status, 'error');
  assert.equal(probe.timers.size, 0);

  const starting = fixture();
  await starting.host.prepare();
  starting.worker.postMessage = () => { throw new Error('Worker transport closed'); };
  await assert.rejects(starting.host.start({ sessionId: 'transport-failure' }), /transport closed/);
  assert.equal(starting.host.state.status, 'error');
  assert.equal(starting.host.session, null);
  assert.equal(starting.captures.length, 0);
});

test('enrollment shares capture ownership, begins only after permission and ignores stale recording messages', async () => {
  const gate = deferred(), f = fixture({ captureGate: gate });
  await f.host.prepare();
  let started = 0;
  const progress = [], complete = [];
  const pending = f.host.startEnrollment({ sessionId: 'voice-a', onStarted() { started++; },
    onProgress: value => progress.push(value), onComplete: value => complete.push(value) });
  assert.equal(f.captureRequests.length, 1, 'Recording requests capture inside the initiating gesture');
  assert.equal(started, 0);
  assert.equal(f.timers.size, 0, 'The recording deadline does not run while permission is pending');
  gate.resolve(f.captures[0]);
  assert.equal(await pending, true);
  assert.equal(started, 1);
  assert.equal(f.worker.messages.find(value => value.message.type === 'start').message.mode, 'enrollment');
  f.worker.emit({ type: 'enrollment-progress', sessionId: 'old', segments: 3 });
  f.worker.emit({ type: 'enrollment-progress', sessionId: 'voice-a', segments: 1 });
  assert.equal(progress.length, 1);
  assert.equal(f.host.cancelEnrollment(), true);
  assert.equal(f.captures[0].stopped, true);
  assert.equal(f.timers.size, 0);
  f.worker.emit({ type: 'enrollment-complete', sessionId: 'voice-a', embedding: [1] });
  assert.equal(complete.length, 0);
  await f.host.start({ sessionId: 'game' });
  assert.equal(f.host.session.mode, 'game');
  f.host.cancelEnrollment();
  assert.equal(f.host.session.sessionId, 'game', 'A stale close from the profile UI cannot stop a new game');
  f.host.stop();
});

test('finish enrollment flushes final audio, releases capture and only returns explicit quality-approved features', async () => {
  const f = fixture({ flushFrame: true });
  await f.host.prepare();
  const complete = [];
  await f.host.startEnrollment({ sessionId: 'voice', onComplete: value => complete.push(value) });
  const finishing = f.host.finishEnrollment();
  assert.equal(f.host.finishEnrollment(), finishing, 'Repeated finish presses share one completion');
  await until(() => f.worker.messages.some(value => value.message.type === 'flush'));
  assert.equal(f.captures[0].stopped, true);
  assert.equal(complete.length, 0, 'Microphone release alone cannot pass quality checks');
  f.worker.emit({ type: 'enrollment-complete', sessionId: 'voice', embedding: [1, ...new Array(255).fill(0)],
    modelVersion: SPEAKER_MODEL_VERSION, quality: { segments: 3, voicedMs: 12500 } });
  const result = await finishing;
  assert.equal(result.embedding.length, 256);
  assert.equal(result.quality.voicedMs, 12500);
  assert.equal(complete.length, 1);
  assert.equal(f.host.session, null);
  assert.equal(f.timers.size, 0);
  assert.equal(f.host.isReady(), true);
});

test('recording deadline runs for sixty seconds and insufficient speech is retryable without model reload', async () => {
  const f = fixture();
  await f.host.prepare();
  const errors = [];
  await f.host.startEnrollment({ sessionId: 'silence', onError: error => errors.push(error) });
  f.advance(59999);
  assert.equal(f.captures[0].stopped, false);
  f.advance(1);
  await until(() => f.worker.messages.some(value => value.message.type === 'flush'));
  f.worker.emit({ type: 'enrollment-error', sessionId: 'silence', code: 'insufficient_speech', message: 'Speak for longer.' });
  assert.equal(errors.length, 1);
  assert.equal(errors[0].code, 'insufficient_speech');
  assert.equal(f.host.session, null);
  assert.equal(f.host.isReady(), true);
  assert.equal(f.timers.size, 0);
  await f.host.startEnrollment({ sessionId: 'retry' });
  assert.equal(f.workers.length, 1);
  f.host.cancelEnrollment();
});

test('enrollment cancellation while permission is pending wipes queued frames and closes late capture', async () => {
  const gate = deferred(), f = fixture({ captureGate: gate });
  await f.host.prepare();
  const pending = f.host.startEnrollment({ sessionId: 'cancel-me' });
  const samples = new Float32Array([0.4, -0.2]);
  f.captureRequests[0].onAudio({ samples, sampleOffset: 0 });
  f.host.cancelEnrollment();
  assert.deepEqual(Array.from(samples), [0, 0]);
  gate.resolve(f.captures[0]);
  assert.equal(await pending, false);
  assert.equal(f.captures[0].stopped, true);
  assert.equal(f.timers.size, 0);
});

test('enrollment quality errors stop the microphone immediately and physical release failures block replacement', async () => {
  const f = fixture({ stopFails: true });
  await f.host.prepare();
  const errors = [];
  await f.host.startEnrollment({ sessionId: 'mixed', onError: error => errors.push(error) });
  f.worker.emit({ type: 'enrollment-error', sessionId: 'mixed', code: 'multiple_speakers', message: 'One person only.' });
  assert.equal(errors.length, 1);
  assert.match(errors[0].message, /microphone.*stop/i);
  assert.equal(f.host.capture, f.captures[0]);
  assert.equal(f.host.state.microphoneBlocked, true);
  assert.equal(f.host.cancelEnrollment(), false);
  await assert.rejects(f.host.startEnrollment({ sessionId: 'unsafe' }), /microphone.*stop/i);
  assert.equal(f.captures.length, 1);
  f.options.stopFails = false;
  assert.equal(f.host.cancelEnrollment(), true);
  assert.equal(f.host.state.microphoneBlocked, false);
});

test('a canceled enrollment flush cannot stop or finish a replacement game', async () => {
  const gate = deferred(), f = fixture({ flushGate: gate });
  await f.host.prepare();
  await f.host.startEnrollment({ sessionId: 'old' });
  const finishing = f.host.finishEnrollment();
  const canceled = assert.rejects(finishing, { code: 'canceled' });
  f.host.cancelEnrollment();
  await f.host.start({ sessionId: 'new-game' });
  gate.resolve();
  await canceled;
  await Promise.resolve();
  assert.equal(f.host.session.sessionId, 'new-game');
  assert.equal(f.captures[1].stopped, false);
  assert.equal(f.worker.messages.filter(value => value.message.type === 'flush').length, 0);
  f.host.stop();
});

test('identification matches the saved voice thresholds and rejects unknown, ambiguous or incompatible profiles', () => {
  const profiles = voiceUsers();
  assert.equal(SPEAKER_MODEL_VERSION, require('../web/voice-profiles.js').SPEAKER_MODEL_VERSION);
  const normalized = identificationProfiles(profiles);
  assert.deepEqual(matchVoiceProfile(voice(0), normalized).profile, { id: 'ada', name: 'Ada', emoji: '🐱' });
  assert.equal(matchVoiceProfile(voice(10), normalized).profile, null);
  const ambiguous = voice(0); ambiguous[0] = Math.SQRT1_2; ambiguous[1] = Math.SQRT1_2;
  assert.equal(matchVoiceProfile(ambiguous, normalized).profile, null);
  const close = voice(0); close[0] = 0.73; close[1] = 0.68;
  assert.equal(matchVoiceProfile(close, normalized).profile, null, 'A best match above threshold still needs the 0.08 runner-up margin');
  const belowThreshold = voice(0); belowThreshold[0] = 0.59; belowThreshold[10] = Math.sqrt(1 - 0.59 ** 2);
  assert.equal(matchVoiceProfile(belowThreshold, normalized).profile, null);
  const enough = voice(0); enough[0] = 0.61; enough[10] = Math.sqrt(1 - 0.61 ** 2);
  assert.equal(matchVoiceProfile(enough, normalized).profile.id, 'ada');
  const invalid = [
    { ...profiles[0], modelVersion: 'old-speaker-model' },
    { ...profiles[0], id: 'zero', embedding: new Array(256).fill(0) },
    { ...profiles[0], id: 'short', embedding: [1] },
    { ...profiles[0], id: 'nan', embedding: voice(0).fill(NaN) },
    { ...profiles[0], id: 'metadata', name: '' }
  ];
  assert.deepEqual(identificationProfiles(invalid), []);
  assert.deepEqual(identificationProfiles([profiles[0], profiles[0]]), [], 'Duplicated IDs cannot create a false match');
  assert.deepEqual(profiles, voiceUsers(), 'Matching never adapts or mutates the saved voices');
  assert.throws(() => matchVoiceProfile([1], normalized), { code: 'invalid_voice_sample' });
});

test('identification starts capture in the gesture, waits for permission and snapshots the saved identities', async () => {
  const gate = deferred(), f = fixture({ captureGate: gate });
  await f.host.prepare();
  const profiles = voiceUsers(), progress = [], completed = [];
  let started = 0;
  const pending = f.host.startIdentification({ sessionId: 'identify', profiles,
    onStarted() { started++; }, onProgress: value => progress.push(value), onComplete: value => completed.push(value) });
  assert.equal(f.captureRequests.length, 1);
  assert.equal(f.timers.size, 0, 'Permission time does not consume the identification deadline');
  f.worker.emit(identificationResult('identify'));
  assert.equal(completed.length, 0, 'A result cannot complete before a physical capture has started');
  profiles[0].name = 'Changed after start'; profiles[0].embedding.fill(0);
  gate.resolve(f.captures[0]);
  assert.equal(await pending, true);
  assert.equal(started, 1);
  assert.equal(f.worker.messages.find(value => value.message.type === 'start').message.mode, 'identification');
  f.worker.emit({ type: 'identification-progress', sessionId: 'old', progress: 0.5 });
  f.worker.emit({ type: 'identification-progress', sessionId: 'identify', progress: 0.5,
    voicedMs: 1000, requiredVoicedMs: 4000, message: 'Keep speaking.' });
  assert.equal(progress.length, 1);
  const vector = voice(0), snapshot = f.host.session.profiles;
  f.worker.emit(identificationResult('identify', vector));
  assert.deepEqual(completed[0].profile, { id: 'ada', name: 'Ada', emoji: '🐱' });
  assert.equal(completed[0].quality.voicedMs, 4400);
  assert.equal(completed[0].quality.similarity, 1);
  assert.ok(vector.every(value => value === 0), 'The temporary inference vector is wiped after matching');
  assert.deepEqual(snapshot, [], 'The per-attempt library copy is discarded after identification');
  assert.equal(f.host.session, null);
  assert.equal(f.timers.size, 0);
});

test('known, unknown and ambiguous identification results all release the microphone before completing exactly once', async () => {
  const ambiguous = voice(0); ambiguous[0] = Math.SQRT1_2; ambiguous[1] = Math.SQRT1_2;
  for (const [embedding, expected] of [[voice(0), 'ada'], [voice(9), null], [ambiguous, null]]) {
    const f = fixture(), complete = [];
    await f.host.prepare();
    const networkCount = f.fetches.length;
    await f.host.startIdentification({ sessionId: 'attempt', profiles: voiceUsers(), onComplete(value) {
      assert.equal(f.captures[0].stopped, true, 'Physical capture is released before displaying a user');
      assert.equal(f.host.capture, null);
      assert.equal(f.host.session, null);
      complete.push(value);
    } });
    f.worker.emit(identificationResult('attempt', embedding));
    f.worker.emit(identificationResult('attempt'));
    assert.equal(complete.length, 1);
    assert.equal(complete[0].profile?.id || null, expected);
    assert.ok(!JSON.stringify(complete[0]).includes('embedding'));
    assert.equal(f.fetches.length, networkCount, 'Identify never downloads models again');
    assert.equal(f.host.isReady(), true);
  }
});

test('identification requires compatible saved profiles before requesting a microphone', async () => {
  const f = fixture();
  await f.host.prepare();
  for (const profiles of [[], null, [{ ...voiceUsers()[0], modelVersion: 'old' }], [{ ...voiceUsers()[0], embedding: [1] }]])
    await assert.rejects(f.host.startIdentification({ sessionId: 'invalid', profiles }), { code: 'no_profiles' });
  await assert.rejects(f.host.startIdentification({ profiles: voiceUsers() }), { code: 'invalid_session' });
  assert.equal(f.captures.length, 0);
  assert.equal(f.host.session, null);
});

test('identification permission failures report once while cancellation fences late permission and queued audio', async () => {
  const denied = Object.assign(new Error('Permission denied'), { name: 'NotAllowedError' });
  for (const option of [{ captureRejects: denied }, { captureThrows: denied }]) {
    const f = fixture(option), errors = [];
    await f.host.prepare();
    await assert.rejects(f.host.startIdentification({ sessionId: 'denied', profiles: voiceUsers(), onError: error => errors.push(error) }),
      { name: 'NotAllowedError' });
    assert.equal(errors.length, 1);
    assert.equal(f.host.session, null);
    assert.equal(f.host.isReady(), true);
    assert.equal(f.timers.size, 0);
  }
  const gate = deferred(), f = fixture({ captureGate: gate }), callbacks = [];
  await f.host.prepare();
  const pending = f.host.startIdentification({ sessionId: 'canceled', profiles: voiceUsers(),
    onStarted: () => callbacks.push('started'), onComplete: () => callbacks.push('complete'), onError: () => callbacks.push('error') });
  const samples = new Float32Array([0.2, -0.4]);
  f.captureRequests[0].onAudio({ samples, sampleOffset: 0 });
  assert.equal(f.host.cancelIdentification(), true);
  assert.deepEqual(Array.from(samples), [0, 0]);
  gate.resolve(f.captures[0]);
  assert.equal(await pending, false);
  assert.equal(f.captures[0].stopped, true);
  f.worker.emit(identificationResult('canceled'));
  assert.deepEqual(callbacks, []);
});

test('identification deadline flushes at twenty-five seconds and bounded finishing clears failed speech or a stuck worker', async () => {
  const f = fixture(), errors = [];
  await f.host.prepare();
  await f.host.startIdentification({ sessionId: 'silence', profiles: voiceUsers(), onError: error => errors.push(error) });
  f.advance(24999);
  assert.equal(f.captures[0].stopped, false);
  f.advance(1);
  await until(() => f.worker.messages.some(value => value.message.type === 'flush'));
  assert.equal(f.captures[0].stopped, true);
  f.worker.emit({ type: 'identification-error', sessionId: 'silence', code: 'insufficient_speech', message: 'Speak for longer.' });
  assert.equal(errors.length, 1);
  assert.equal(errors[0].code, 'insufficient_speech');
  assert.equal(f.timers.size, 0);
  assert.equal(f.host.isReady(), true);
  const stuck = fixture({ flushGate: deferred() }), failures = [];
  await stuck.host.prepare();
  await stuck.host.startIdentification({ sessionId: 'stuck', profiles: voiceUsers(), onError: error => failures.push(error) });
  stuck.advance(25000);
  stuck.advance(2000);
  assert.equal(stuck.captures[0].stopped, true, 'A stuck flush cannot leave the microphone open indefinitely');
  assert.equal(failures.length, 1);
  assert.equal(failures[0].code, 'identification_timeout');
  assert.equal(stuck.host.session, null);
  assert.equal(stuck.timers.size, 0);
});

test('identification rejects invalid completed quality and disconnected audio without returning an identity', async () => {
  for (const extra of [{ quality: { segments: 1, voicedMs: 1000 } }, { modelVersion: 'older-model' }, { embedding: [1] }]) {
    const f = fixture(), errors = [], complete = [];
    await f.host.prepare();
    await f.host.startIdentification({ sessionId: 'quality', profiles: voiceUsers(),
      onError: error => errors.push(error), onComplete: result => complete.push(result) });
    f.worker.emit(identificationResult('quality', voice(0), extra));
    assert.equal(complete.length, 0);
    assert.equal(errors.length, 1);
    assert.equal(f.captures[0].stopped, true);
    assert.equal(f.host.isReady(), true);
  }
  const f = fixture(), errors = [];
  await f.host.prepare();
  await f.host.startIdentification({ sessionId: 'disconnected', profiles: voiceUsers(), onError: error => errors.push(error) });
  f.captureRequests[0].onError(new Error('Microphone disconnected'));
  f.captureRequests[0].onError(new Error('Old disconnected callback'));
  assert.equal(errors.length, 1);
  assert.equal(f.captures[0].stopped, true);
});

test('failed identification microphone release stays blocked and can never report a successful identity', async () => {
  const f = fixture({ stopFails: true }), errors = [], complete = [];
  await f.host.prepare();
  await f.host.startIdentification({ sessionId: 'blocked', profiles: voiceUsers(),
    onError: error => errors.push(error), onComplete: result => complete.push(result) });
  f.worker.emit(identificationResult('blocked'));
  assert.equal(complete.length, 0);
  assert.equal(errors.length, 1);
  assert.equal(errors[0].code, 'microphone_release_failed');
  assert.equal(f.host.capture, f.captures[0]);
  assert.equal(f.host.state.microphoneBlocked, true);
  assert.equal(f.host.cancelIdentification(), false);
  await assert.rejects(f.host.startIdentification({ sessionId: 'unsafe', profiles: voiceUsers() }), /microphone.*stop/i);
  assert.equal(f.captures.length, 1);
  f.options.stopFails = false;
  assert.equal(f.host.cancelIdentification(), true);
  assert.equal(f.host.state.microphoneBlocked, false);
});

test('stale identification cancellation, results and deadline flushes cannot interrupt a replacement game or enrollment', async () => {
  const gate = deferred(), f = fixture({ flushGate: gate }), completed = [];
  await f.host.prepare();
  await f.host.startIdentification({ sessionId: 'old', profiles: voiceUsers(), onComplete: result => completed.push(result) });
  f.advance(25000);
  f.host.cancelIdentification();
  await f.host.start({ sessionId: 'game' });
  assert.equal(f.host.cancelIdentification(), true);
  gate.resolve();
  await Promise.resolve(); await Promise.resolve();
  f.worker.emit(identificationResult('old'));
  assert.equal(f.host.session.sessionId, 'game');
  assert.equal(f.captures[1].stopped, false);
  assert.equal(completed.length, 0);
  assert.equal(f.worker.messages.filter(value => value.message.type === 'flush').length, 0);
  await f.host.startEnrollment({ sessionId: 'enroll' });
  assert.equal(f.host.cancelIdentification(), true);
  assert.equal(f.host.session.sessionId, 'enroll');
  assert.equal(f.captures[2].stopped, false);
  f.host.cancelEnrollment();
});

test('identification worker startup failure cancels pending permission and closes a later microphone grant', async () => {
  const gate = deferred(), f = fixture({ captureGate: gate }), callbacks = [];
  await f.host.prepare();
  const pending = f.host.startIdentification({ sessionId: 'startup', profiles: voiceUsers(),
    onStarted: () => callbacks.push('started'), onComplete: () => callbacks.push('complete'),
    onError: error => callbacks.push(error.code) });
  f.worker.emit({ type: 'identification-error', sessionId: 'startup', code: 'recognition_failed', message: 'Inference could not start.' });
  assert.deepEqual(callbacks, ['recognition_failed']);
  assert.equal(f.host.session, null);
  gate.resolve(f.captures[0]);
  assert.equal(await pending, false);
  assert.equal(f.captures[0].stopped, true);
  assert.deepEqual(callbacks, ['recognition_failed'], 'Late permission cannot restart or report another result after startup failure');
  assert.equal(f.timers.size, 0);
});

test('a canceled identification with late failed release preserves the physical microphone without reviving its callbacks', async () => {
  const gate = deferred(), f = fixture({ captureGate: gate, stopFails: true }), callbacks = [];
  await f.host.prepare();
  const pending = f.host.startIdentification({ sessionId: 'late', profiles: voiceUsers(),
    onStarted: () => callbacks.push('started'), onComplete: () => callbacks.push('complete'), onError: () => callbacks.push('error') });
  f.host.cancelIdentification();
  const rejected = assert.rejects(pending, /microphone.*stop/i);
  gate.resolve(f.captures[0]);
  await rejected;
  assert.deepEqual(callbacks, []);
  assert.equal(f.host.capture, f.captures[0]);
  assert.equal(f.host.state.microphoneBlocked, true);
  assert.equal(f.host.cancelIdentification(), false);
  f.options.stopFails = false;
  assert.equal(f.host.cancelIdentification(), true);
  assert.equal(f.host.capture, null);
});

test('a broken inference worker reports one identification error and physically releases the microphone', async () => {
  const f = fixture(), errors = [], results = [];
  await f.host.prepare();
  await f.host.startIdentification({ sessionId: 'worker-failed', profiles: voiceUsers(),
    onError: error => errors.push(error), onComplete: result => results.push(result) });
  f.worker.error('Inference worker stopped unexpectedly');
  assert.equal(errors.length, 1);
  assert.equal(results.length, 0);
  assert.equal(f.captures[0].stopped, true);
  assert.equal(f.host.session, null);
  assert.equal(f.host.state.status, 'error');
  assert.equal(f.timers.size, 0);
});

test('multiple saved templates recover supported variation without accepting one isolated high score', () => {
  const turn = (angle, dimension) => {
    const value = voice(0); value[0] = Math.cos(angle); value[dimension] = Math.sin(angle); return value;
  };
  const templates = [voice(0), turn(Math.PI / 9, 1), turn(Math.PI / 3, 2)];
  const centroid = templates.reduce((sum, value) => sum.map((number, i) => number + value[i]), new Array(256).fill(0));
  const norm = Math.hypot(...centroid);
  const saved = { ...voiceUsers()[0], embedding: centroid.map(value => value / norm) };
  const competitor = { ...voiceUsers()[1], embedding: turn(Math.acos(0.86), 3) };
  const single = matchVoiceProfile(voice(0), identificationProfiles([saved, competitor]));
  assert.equal(single.profile, null, 'The legacy mean loses enough variation to leave a narrow runner-up margin');
  const matching = matchVoiceProfile(voice(0), identificationProfiles([{ ...saved, templates }, competitor]));
  assert.equal(matching.profile.id, 'ada');
  assert.ok(matching.similarity > single.similarity);
  assert.ok(Math.abs(matching.similarity - (1 + Math.cos(Math.PI / 9)) / 2) < 1e-12);
  const isolated = identificationProfiles([{ ...saved, templates: [voice(0), voice(5), voice(6)] }]);
  assert.equal(matchVoiceProfile(voice(0), isolated).profile, null, 'A single coincidental template does not win via max-only scoring');
  const legacy = identificationProfiles([voiceUsers()[0]]);
  assert.equal(matchVoiceProfile(turn(Math.acos(0.7), 3), legacy).similarity, 0.7, 'Single-template matching keeps the exact legacy cosine');
});

test('identification snapshots validate all optional templates rather than falling back on malformed saved evidence', () => {
  for (const templates of [[], null, [voice(0), [1]], Array.from({ length: 9 }, () => voice(0)), [voice(0).fill(NaN)]])
    assert.deepEqual(identificationProfiles([{ ...voiceUsers()[0], templates }]), []);
  const original = [{ ...voiceUsers()[0], templates: [voice(0).map(value => value * 2), voice(0)] }];
  const copy = identificationProfiles(original);
  assert.equal(copy[0].templates[0][0], 1);
  original[0].templates[0].fill(0);
  assert.equal(copy[0].templates[0][0], 1);
});

test('identification requires independent segment agreement and aggregate support before returning an identity', async () => {
  const ambiguous = voice(0); ambiguous[0] = Math.SQRT1_2; ambiguous[1] = Math.SQRT1_2;
  const examples = [
    { aggregate: voice(0), turns: [voice(0), voice(0)], expected: 'ada', reason: 'matched' },
    { aggregate: voice(0), turns: [voice(0), voice(1)], reason: 'segment_disagreement' },
    { aggregate: voice(0), turns: [voice(1), voice(1)], reason: 'segment_disagreement' },
    { aggregate: voice(0), turns: [voice(0), voice(8)], reason: 'insufficient_consensus' },
    { aggregate: voice(0), turns: [ambiguous, ambiguous], reason: 'ambiguous_voice' },
    { aggregate: voice(8), turns: [voice(8), voice(8)], reason: 'unknown_voice' },
    { aggregate: ambiguous, turns: [voice(0), voice(0)], reason: 'ambiguous_voice' },
    { aggregate: voice(0), turns: [voice(0), voice(0), voice(8)], expected: 'ada', reason: 'matched' },
    { aggregate: voice(0), turns: [], reason: 'insufficient_consensus' }
  ];
  for (const example of examples) {
    const f = fixture(), completed = [], errors = [];
    await f.host.prepare();
    await f.host.startIdentification({ sessionId: 'consensus', profiles: voiceUsers(),
      onComplete: result => completed.push(result), onError: error => errors.push(error) });
    const result = identificationResult('consensus', example.aggregate, {
      segments: example.turns.map(embedding => ({ embedding: embedding.slice(), voicedMs: 2200 })),
      quality: { voicedMs: Math.max(2, example.turns.length) * 2200, segments: Math.max(2, example.turns.length) }
    });
    f.worker.emit(result);
    assert.deepEqual(errors, [], example.reason);
    assert.equal(completed.length, 1);
    assert.equal(completed[0].profile?.id || null, example.expected || null, example.reason);
    assert.equal(completed[0].quality.reason, example.reason);
    assert.equal(f.captures[0].stopped, true);
    assert.ok(result.templates.every(vector => vector.every(value => value === 0)));
    assert.ok(result.segments.every(segment => segment.embedding.every(value => value === 0)));
  }
});

test('a claimed aggregate duration cannot substitute for two usable independent speech segments', async () => {
  for (const segments of [undefined, [{ embedding: voice(0), voicedMs: 4500 }],
    [{ embedding: voice(0), voicedMs: 100 }, { embedding: voice(0), voicedMs: 100 }],
    [{ embedding: voice(0), voicedMs: 2200 }, { embedding: [], voicedMs: 2200 }]]) {
    const f = fixture(), completed = [];
    await f.host.prepare();
    await f.host.startIdentification({ sessionId: 'evidence', profiles: voiceUsers(), onComplete: result => completed.push(result) });
    f.worker.emit(identificationResult('evidence', voice(0), { segments }));
    assert.equal(completed[0].profile, null);
    assert.equal(completed[0].quality.reason, 'insufficient_consensus');
    assert.equal(f.captures[0].stopped, true);
  }
});

test('enrollment returns independent copies of all voice evidence only after physical microphone release', async () => {
  const f = fixture(), completed = [];
  await f.host.prepare();
  await f.host.startEnrollment({ sessionId: 'templates', onComplete(result) {
    assert.equal(f.captures[0].stopped, true);
    completed.push(result);
  } });
  assert.equal(f.worker.messages.find(value => value.message.type === 'start').message.maxTimeMs, 60000);
  const result = { type: 'enrollment-complete', sessionId: 'templates', embedding: voice(0),
    templates: [voice(0), voice(0), voice(0)],
    segments: Array.from({ length: 3 }, () => ({ embedding: voice(0), voicedMs: 4200 })),
    modelVersion: SPEAKER_MODEL_VERSION, quality: { segments: 3, voicedMs: 12600 } };
  f.worker.emit(result);
  assert.equal(completed.length, 1);
  assert.ok(result.embedding.every(value => value === 0));
  assert.ok(result.templates.every(vector => vector.every(value => value === 0)));
  assert.ok(result.segments.every(segment => segment.embedding.every(value => value === 0)));
  assert.equal(completed[0].embedding[0], 1);
  assert.ok(completed[0].templates.every(vector => vector[0] === 1));
  assert.ok(completed[0].segments.every(segment => segment.embedding[0] === 1));
  f.worker.emit(result);
  assert.equal(completed.length, 1);
});

test('cancel and late results wipe transient template copies while keeping saved profiles intact', async () => {
  const f = fixture(), profiles = [{ ...voiceUsers()[0], templates: [voice(0), voice(0)] }];
  await f.host.prepare();
  await f.host.startIdentification({ sessionId: 'private', profiles });
  assert.equal(f.worker.messages.find(value => value.message.type === 'start').message.maxTimeMs, 30000);
  const savedCopies = [f.host.session.profiles[0].embedding, ...f.host.session.profiles[0].templates];
  f.host.cancelIdentification();
  assert.ok(savedCopies.every(vector => vector.every(value => value === 0)));
  assert.ok(profiles[0].templates.every(vector => vector[0] === 1), 'The persistent library was not zeroed');
  const late = identificationResult('private');
  f.worker.emit(late);
  assert.ok(late.embedding.every(value => value === 0));
  assert.ok(late.templates.every(vector => vector.every(value => value === 0)));
  assert.ok(late.segments.every(segment => segment.embedding.every(value => value === 0)));
  const oldEnrollment = { type: 'enrollment-complete', sessionId: 'old', embedding: voice(0),
    templates: [voice(0)], segments: [{ embedding: voice(0), voicedMs: 12000 }] };
  f.worker.emit(oldEnrollment);
  assert.ok(oldEnrollment.templates[0].every(value => value === 0));
  assert.ok(oldEnrollment.segments[0].embedding.every(value => value === 0));
});

test('enrollment cannot complete with insufficient or malformed evidence even when the worker reports completion', async () => {
  for (const extra of [
    { quality: { segments: 3, voicedMs: 11999 } },
    { quality: { segments: 2, voicedMs: 13000 } },
    { templates: [voice(0), []] },
    { segments: [{ embedding: voice(0), voicedMs: 13000 }] },
    { segments: [{ embedding: voice(0), voicedMs: 4300 }, { embedding: [], voicedMs: 4300 }, { embedding: voice(0), voicedMs: 4300 }] }
  ]) {
    const f = fixture(), completed = [], errors = [];
    await f.host.prepare();
    await f.host.startEnrollment({ sessionId: 'evidence', onComplete: result => completed.push(result), onError: error => errors.push(error) });
    const message = { type: 'enrollment-complete', sessionId: 'evidence', embedding: voice(0), templates: [voice(0)],
      modelVersion: SPEAKER_MODEL_VERSION, quality: { segments: 3, voicedMs: 12900 }, ...extra };
    f.worker.emit(message);
    assert.deepEqual(completed, []);
    assert.equal(errors.length, 1);
    assert.equal(f.captures[0].stopped, true);
    assert.ok(message.embedding.every(value => value === 0));
    assert.ok(message.templates.every(vector => vector.every(value => value === 0)));
    assert.ok(!message.segments || message.segments.every(segment => segment.embedding.every(value => value === 0)));
  }
});
