const { test, expect } = require('@playwright/test');
const fs = require('node:fs');
const path = require('node:path');
const { VoicePopResampler } = require('../../web/multiplayer-audio.js');

// Opt in after preparing and exporting the real models. UI fixtures deliberately
// do not download 100+ MB or claim to validate the acoustic inference path.
test.skip(process.env.VOICE_POP_REAL_RUNTIME !== '1', 'Set VOICE_POP_REAL_RUNTIME=1 to exercise the packaged WASM and models.');

function recording(word) {
  const wav = fs.readFileSync(path.resolve(__dirname, `../../assets/audio/voice/word-${word}.wav`));
  let format, data;
  for (let offset = 12; offset + 8 < wav.length;) {
    const id = wav.toString('ascii', offset, offset + 4);
    const size = wav.readUInt32LE(offset + 4);
    if (id === 'fmt ') format = { type: wav.readUInt16LE(offset + 8), channels: wav.readUInt16LE(offset + 10), rate: wav.readUInt32LE(offset + 12), bits: wav.readUInt16LE(offset + 22) };
    if (id === 'data') data = wav.subarray(offset + 8, offset + 8 + size);
    offset += 8 + size + size % 2;
  }
  expect(format.type).toBe(1);
  expect(format.bits).toBe(16);
  const samples = new Float32Array(data.length / (2 * format.channels));
  for (let i = 0; i < samples.length; i++) for (let c = 0; c < format.channels; c++) {
    samples[i] += data.readInt16LE((i * format.channels + c) * 2) / 32768 / format.channels;
  }
  const chunks = [];
  const resampler = new VoicePopResampler(format.rate, chunk => chunks.push(chunk));
  resampler.push(samples);
  resampler.flush();
  const audio = new Float32Array(3200 + chunks.reduce((n, chunk) => n + chunk.length, 0) + 16000);
  let offset = 3200;
  for (const chunk of chunks) { audio.set(chunk, offset); offset += chunk.length; }
  return Array.from(audio);
}

test('packaged models warm up, reuse verified cache, and recognize local recordings offline', async ({ page, context }, info) => {
  test.setTimeout(240000);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.route('**/__voice_pop_runtime__', route => route.fulfill({ contentType: 'text/html', body:
    '<!doctype html><script src="/multiplayer-capture.js"></script><script src="/multiplayer-host.js"></script>' }));
  await page.goto('/__voice_pop_runtime__');
  const cold = await page.evaluate(async () => {
    window.newRuntime = () => {
      const host = new VoicePopMultiplayer();
      // Windows Playwright WebKit omits all capture/audio APIs. The application
      // must report unsupported there; this recording-only harness can still
      // validate its actual Worker/WASM engine without fabricating a microphone.
      if (!window.captureSupported) host.supported = () => true;
      return host;
    };
    window.captureSupported = new VoicePopMultiplayer().supported();
    if (!captureSupported) {
      const unsupported = new VoicePopMultiplayer();
      if (await unsupported.prepare() || unsupported.state.status !== 'unsupported' || unsupported.state.loaded !== 0) {
        throw new Error('Missing capture APIs must prevent application readiness and model downloads');
      }
      if (!window.Worker || !window.WebAssembly || !crypto.subtle) throw new Error('This browser cannot run the inference-only harness');
    }
    window.runtimeStates = [];
    window.localRuntime = newRuntime();
    localRuntime.observe(state => runtimeStates.push(state));
    const start = performance.now();
    const ready = await localRuntime.prepare();
    return { ready, milliseconds: performance.now() - start, states: runtimeStates, captureSupported };
  });
  expect(cold.ready, JSON.stringify(cold.states.at(-1))).toBe(true);
  expect(cold.states.some(state => state.status === 'downloading' && state.loaded > 0)).toBe(true);
  expect(cold.states.findIndex(state => state.status === 'initializing')).toBeLessThan(cold.states.findIndex(state => state.status === 'ready'));
  const finalState = cold.states.at(-1);
  expect(finalState.loaded).toBe(finalState.total);
  expect(finalState.total).toBeGreaterThan(100000000);

  const warm = await page.evaluate(async () => {
    localRuntime.stop();
    localRuntime.worker.terminate();
    const fetched = [];
    const originalFetch = window.fetch;
    window.fetch = (...args) => { fetched.push(String(args[0])); return originalFetch(...args); };
    window.localRuntime = newRuntime();
    const start = performance.now();
    const ready = await localRuntime.prepare();
    window.fetch = originalFetch;
    return { ready, milliseconds: performance.now() - start, fetched, state: localRuntime.state };
  });
  expect(warm.ready, JSON.stringify(warm.state)).toBe(true);
  expect(warm.fetched.every(url => url.endsWith('/multiplayer/manifest.json'))).toBe(true);
  await context.setOffline(true);
  expect(await page.evaluate(() => localRuntime.verifyReady())).toBe(true);
  const results = [];
  for (const word of ['cat', 'apple', 'dog']) {
    const audio = recording(word);
    const result = await page.evaluate(({ word, audio }) => new Promise((resolve, reject) => {
      const events = [];
      const start = performance.now();
      const timer = setTimeout(() => reject(new Error('Local recording recognition timed out')), 30000);
      const sessionId = `recording-${word}`;
      localRuntime.session = { sessionId,
        onEvent: event => events.push(event),
        onError: reject,
        onFlushed: () => { clearTimeout(timer); resolve({ word, milliseconds: performance.now() - start, events }); }
      };
      localRuntime.worker.postMessage({ type: 'start', sessionId, timeOffsetMs: 0 });
      const samples = new Float32Array(audio);
      for (let sampleOffset = 0; sampleOffset < samples.length; sampleOffset += 512) {
        const chunk = samples.slice(sampleOffset, sampleOffset + 512);
        localRuntime.worker.postMessage({ type: 'audio', sessionId, sampleOffset, samples: chunk }, [chunk.buffer]);
      }
      localRuntime.worker.postMessage({ type: 'flush', sessionId });
    }), { word, audio });
    expect(result.events.map(event => event.text)).toContain(word);
    for (const event of result.events) {
      expect(event.embedding.length).toBe(256);
      expect(event.embedding.every(Number.isFinite)).toBe(true);
      expect(Math.abs(Math.hypot(...event.embedding) - 1)).toBeLessThan(0.00001);
      expect(event.startMs).toBeGreaterThanOrEqual(0);
      expect(event.endMs).toBeGreaterThan(event.startMs);
      expect(event.endMs).toBeLessThanOrEqual(audio.length / 16);
    }
    results.push({ ...result, events: result.events.map(({ embedding, ...event }) => ({ ...event, dimensions: embedding.length })) });
  }
  await info.attach('real-runtime-results.json', { contentType: 'application/json', body: JSON.stringify({ coldMilliseconds: cold.milliseconds,
    cachedMilliseconds: warm.milliseconds, bytes: finalState.total, captureSupported: cold.captureSupported,
    inferenceOnly: !cold.captureSupported, results }, null, 2) });
  expect(errors).toEqual([]);
  await page.evaluate(() => { localRuntime.stop(); localRuntime.worker.terminate(); });
});
