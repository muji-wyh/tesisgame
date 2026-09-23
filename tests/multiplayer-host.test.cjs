const test = require('node:test');
const assert = require('node:assert/strict');
const { createHash, webcrypto } = require('node:crypto');
const { VoicePopMultiplayer } = require('../web/multiplayer-host.js');

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
  assert.equal(f.host.stop(), false, 'Cancellation must not manufacture successful physical release');
  await assert.rejects(f.host.start({ sessionId: 'unsafe-replacement' }), /stop|microphone|close/i);
  assert.equal(f.captures.length, 1);
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
