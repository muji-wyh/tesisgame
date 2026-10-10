const test = require('node:test');
const assert = require('node:assert/strict');
const { createHash, webcrypto } = require('node:crypto');
const { createVocabularyLoader, MAX_PACK_BYTES } = require('../web/vocabulary-loader.js');
const fs = require('node:fs');
const vm = require('node:vm');

function fixture(overrides = {}) {
  const bytes = new Uint8Array(Buffer.from('A complete vocabulary pack.'));
  const sha256 = createHash('sha256').update(bytes).digest('hex');
  const packs = Object.fromEntries([3, 4, 12].map(age => [age, {
    file: `vocabulary-${age}-${sha256.slice(0, 16)}.pck.br`, bytes: bytes.length, sha256
  }]));
  const requests = [], copies = [], states = [];
  const loader = createVocabularyLoader({
    packs, crypto: webcrypto,
    fetch: async (file, options) => { requests.push({ file, options }); return new Response(bytes); },
    engine: { copyToFS(path, data) { copies.push({ path, data }); } },
    ...overrides
  });
  return { loader, bytes, packs, requests, copies, states, report: text => states.push(JSON.parse(text)) };
}

test('construction fetches nothing; a selected age is verified and copied once', async () => {
  const f = fixture();
  assert.deepEqual(f.requests, []);
  assert.equal(f.loader.status(3).state, 'idle');
  const result = await f.loader.request(3, f.report);
  assert.equal(result.state, 'ready');
  assert.equal(f.requests.length, 1);
  assert.equal(f.requests[0].file, f.packs[3].file);
  assert.equal(f.requests[0].options.cache, 'force-cache');
  assert.equal(f.requests[0].options.redirect, 'error');
  assert.equal(f.copies.length, 1);
  assert.equal(f.copies[0].path, '/' + f.packs[3].file.slice(0, -3));
  assert.deepEqual(f.copies[0].data, f.bytes);
  assert.equal(f.states[0].state, 'loading');
  assert.equal(f.states.at(-1).state, 'ready');
  assert.ok(f.states.some(state => state.progress > 0 && state.progress < 1));
  assert.equal(f.loader.status(4).state, 'idle');
  assert.equal(f.loader.status(12).state, 'idle');
});

test('concurrent consumers share a request; ready ages do not redownload', async () => {
  let release;
  const gate = new Promise(resolve => { release = resolve; });
  let calls = 0;
  const f = fixture({ fetch: async () => { calls++; await gate; return new Response(f.bytes); } });
  const second = [];
  const a = f.loader.request(3, f.report);
  const b = f.loader.request(3, text => second.push(JSON.parse(text)));
  assert.equal(a, b);
  assert.equal(calls, 1);
  release();
  await a;
  await f.loader.request(3, f.report);
  assert.equal(calls, 1);
  assert.equal(f.copies.length, 1);
  assert.equal(second.at(-1).state, 'ready');
  assert.equal(f.states.at(-1).state, 'ready');
});

test('callbacks run after the requesting call and listener errors do not poison downloads', async () => {
  let inside = true, reentered = false;
  const f = fixture();
  const request = f.loader.request(3, () => { reentered ||= inside; throw new Error('Discarded view'); });
  inside = false;
  assert.equal((await request).state, 'ready');
  assert.equal(reentered, false);
  assert.equal(f.copies.length, 1);
});

test('an HTTP failure leaves other ages available and can be retried', async () => {
  let failed = true;
  const f = fixture({ fetch: async () => failed ? new Response('unavailable', { status: 503 }) : new Response(f.bytes) });
  assert.equal((await f.loader.request(3, f.report)).state, 'failed');
  assert.equal(f.copies.length, 0);
  failed = false;
  assert.equal((await f.loader.request(4, f.report)).state, 'ready');
  assert.equal((await f.loader.request(3, f.report)).state, 'ready');
  assert.equal(f.copies.length, 2);
});

test('a same-size hash mismatch never reaches the engine and retry verifies new bytes', async () => {
  let damaged = true;
  const cacheModes = [];
  const f = fixture({ fetch: async (_file, options) => {
    cacheModes.push(options.cache);
    const data = f.bytes.slice();
    if (damaged) data[0] ^= 1;
    return new Response(data);
  } });
  const first = await f.loader.request(3, f.report);
  assert.equal(first.state, 'failed');
  assert.match(first.error, /damaged/);
  assert.equal(f.copies.length, 0);
  damaged = false;
  assert.equal((await f.loader.request(3, f.report)).state, 'ready');
  assert.equal(f.copies.length, 1);
  assert.deepEqual(cacheModes, ['force-cache', 'reload'], 'A retry bypasses a damaged immutable HTTP cache entry');
});

test('truncated and oversized decoded streams are rejected before mounting', async () => {
  for (const adjustment of [-1, 1]) {
    let canceled = false;
    const f = fixture({ fetch: async () => ({ ok: true, body: new ReadableStream({
      start(controller) {
        controller.enqueue(new Uint8Array(f.bytes.length + adjustment));
        if (adjustment < 0) controller.close();
      },
      cancel() { canceled = true; }
    }) }) });
    assert.equal((await f.loader.request(3, f.report)).state, 'failed');
    assert.equal(f.copies.length, 0);
    if (adjustment > 0) assert.equal(canceled, true);
  }
});

test('the timeout covers stalled fetches and streams and permits a later request', async () => {
  for (const stage of ['headers', 'body']) {
    let signal, fail = true;
    const f = fixture({ timeoutMs: 20, fetch: async (_file, options) => {
      signal = options.signal;
      if (!fail) return new Response(f.bytes);
      return stage === 'headers' ? new Promise(() => {}) : { ok: true, body: new ReadableStream() };
    } });
    const result = await f.loader.request(3, f.report);
    assert.equal(result.state, 'failed');
    assert.match(result.error, /too long/);
    assert.equal(signal.aborted, true);
    assert.equal(f.copies.length, 0);
    fail = false;
    assert.equal((await f.loader.request(3, f.report)).state, 'ready');
  }
});

test('manifest filenames, digests, size limits and ages are validated before network access', async () => {
  for (const invalid of [
    { file: '../vocabulary-3-deadbeefdeadbeef.pck.br' },
    { file: 'https://example.test/vocabulary-3-deadbeefdeadbeef.pck.br' },
    { file: 'vocabulary-4-deadbeefdeadbeef.pck.br' },
    { file: 'vocabulary-3-deadbeefdeadbeef.pck.br' },
    { bytes: MAX_PACK_BYTES + 1 }, { bytes: -1 }, { bytes: 1.5 }, { sha256: 'bad-hash' }
  ]) {
    const f = fixture();
    Object.assign(f.packs[3], invalid);
    assert.equal((await f.loader.request(3, f.report)).state, 'failed');
    assert.deepEqual(f.requests, []);
    assert.deepEqual(f.copies, []);
  }
  for (const age of [2, 13, 3.5, '3', NaN]) {
    const f = fixture();
    assert.equal((await f.loader.request(age, f.report)).state, 'failed');
    assert.deepEqual(f.requests, []);
  }
});

test('copy failures do not report ready and can be retried from the verified resource', async () => {
  let fail = true;
  const f = fixture({ engine: { copyToFS() { if (fail) throw new Error('Not enough memory to load these words.'); } } });
  assert.equal((await f.loader.request(3, f.report)).state, 'failed');
  assert.equal(f.states.some(state => state.state === 'ready'), false);
  fail = false;
  assert.equal((await f.loader.request(3, f.report)).state, 'ready');
});

test('a browser without streaming or integrity verification fails explicitly', async () => {
  const noStream = fixture({ fetch: async () => ({ ok: true, arrayBuffer: async () => new ArrayBuffer(0) }) });
  assert.equal((await noStream.loader.request(3, noStream.report)).state, 'failed');
  assert.equal(noStream.copies.length, 0);
  const noDigest = fixture({ crypto: {} });
  assert.equal((await noDigest.loader.request(3, noDigest.report)).state, 'failed');
  assert.equal(noDigest.copies.length, 0);
});

test('startup vocabulary failures expose a working reload without stopping the engine or loading play', async () => {
  const shell = fs.readFileSync('web/shell.html', 'utf8').replace(/\r\n/g, '\n');
  const hint = shell.match(/      function vocabularyLoadingHint\([\s\S]*?\n      function createGameAudioRecovery/)[0]
    .replace(/\n      function createGameAudioRecovery$/, '');
  const retry = shell.match(/      retry.addEventListener\('click', event => \{[\s\S]*?\n      \}\);/)[0];
  let handler, reloads = 0;
  const context = {
    readyReceived: false, failed: false,
    message: { textContent: '' }, downloadStatus: { textContent: '' }, loadingNote: { hidden: true },
    retry: { hidden: true, disabled: false, addEventListener: (_name, callback) => { handler = callback; } },
    interfaceClickSound: { play: async () => {} }, window: { location: { reload: () => { reloads++; } } }
  };
  vm.runInNewContext(hint + '\n' + retry, context);
  context.vocabularyLoadingHint(3, 'loading', 0.5, '');
  assert.match(context.message.textContent, /Loading Age 3 words/);
  assert.match(context.downloadStatus.textContent, /50%/);
  context.vocabularyLoadingHint(3, 'failed', 0.5, 'Connection interrupted. Please try again.');
  assert.equal(context.loadingNote.hidden, false);
  assert.equal(context.retry.hidden, false);
  assert.equal(context.failed, false);
  assert.match(context.loadingNote.textContent, /Connection interrupted/);
  handler({ isTrusted: true });
  await Promise.resolve();
  assert.equal(reloads, 1);
  const previous = context.message.textContent;
  context.readyReceived = true;
  context.vocabularyLoadingHint(4, 'loading', 0.1, '');
  assert.equal(context.message.textContent, previous, 'In-game prefetch cannot reopen or alter the startup overlay');
});

function bundle(label, text) {
  const data = new Uint8Array(Buffer.from(text));
  const sha256 = createHash('sha256').update(data).digest('hex');
  return { data, descriptor: { file: `vocabulary-${label}-${sha256.slice(0, 16)}.pck.br`, bytes: data.length, sha256 } };
}

function sharedFixture(overrides = {}) {
  const shared = bundle('shared-3-4', 'Shared media');
  const three = bundle('3', 'Age three unique media');
  const four = bundle('4', 'Age four unique media');
  const packs = { 3: { ...three.descriptor, dependencies: [shared.descriptor] },
    4: { ...four.descriptor, dependencies: [shared.descriptor] } };
  const sources = new Map([shared, three, four].map(pack => [pack.descriptor.file, pack.data]));
  const f = fixture({ packs, fetch: async file => { f.requests.push({ file }); return new Response(sources.get(file)); }, ...overrides });
  return Object.assign(f, { packs, sources, shared, three, four });
}

test('concurrent ages fetch and copy shared dependencies once and return dependency-first paths', async () => {
  const f = sharedFixture();
  const [three, four] = await Promise.all([f.loader.request(3, f.report), f.loader.request(4, f.report)]);
  assert.equal(three.state, 'ready');
  assert.equal(four.state, 'ready');
  assert.equal(f.requests.length, 3);
  assert.equal(f.copies.length, 3);
  const sharedPath = '/' + f.shared.descriptor.file.slice(0, -3);
  assert.deepEqual(three.paths, [sharedPath, three.path]);
  assert.deepEqual(four.paths, [sharedPath, four.path]);
  assert.equal(f.copies.filter(copy => copy.path === sharedPath).length, 1);
  assert.equal(f.loader.status(12).state, 'idle');
  three.paths.length = 0;
  assert.equal(f.loader.status(3).paths.length, 2, 'A consumer cannot mutate cached resource paths');
});

test('age progress weights shared and base bundles by decoded bytes', async () => {
  let releaseBase, sharedCopied;
  const gate = new Promise(resolve => { releaseBase = resolve; });
  const copied = new Promise(resolve => { sharedCopied = resolve; });
  const f = sharedFixture({
    fetch: async file => { if (file === f.three.descriptor.file) await gate; return new Response(f.sources.get(file)); },
    engine: { copyToFS(path) { if (path.includes('shared-')) sharedCopied(); } }
  });
  const request = f.loader.request(3, f.report);
  await copied;
  await new Promise(resolve => setImmediate(resolve));
  const expected = f.shared.data.length / (f.shared.data.length + f.three.data.length);
  assert.equal(f.loader.status(3).state, 'loading');
  assert.ok(Math.abs(f.loader.status(3).progress - expected) < 1e-12);
  releaseBase();
  assert.equal((await request).state, 'ready');
});

test('a shared-bundle failure retries only failed resources and retains successful downloads', async () => {
  let failShared = true;
  const requests = [];
  const f = sharedFixture({ fetch: async (file, options) => {
    requests.push({ file, cache: options.cache });
    return failShared && file === f.shared.descriptor.file ? new Response('', { status: 503 }) : new Response(f.sources.get(file));
  } });
  assert.equal((await f.loader.request(3, f.report)).state, 'failed');
  failShared = false;
  assert.equal((await f.loader.request(3, f.report)).state, 'ready');
  assert.equal(requests.filter(item => item.file === f.three.descriptor.file).length, 1);
  assert.deepEqual(requests.filter(item => item.file === f.shared.descriptor.file).map(item => item.cache), ['force-cache', 'reload']);
  assert.equal(f.copies.length, 2);
});

test('shared manifests reject unrelated consumers, duplicate resources and conflicting bundle metadata before fetch', async () => {
  for (const consumer of ['4-5', '3', '3-3-4', '4-3', '03-4', '3-13']) {
    const f = sharedFixture();
    f.packs[3].dependencies = [{ ...f.shared.descriptor,
      file: f.shared.descriptor.file.replace('shared-3-4-', `shared-${consumer}-`) }];
    assert.equal((await f.loader.request(3, f.report)).state, 'failed');
    assert.equal(f.requests.length, 0);
  }
  for (const dependency of [null, 'invalid', []]) {
    const f = sharedFixture();
    f.packs[3].dependencies = dependency === null ? null : dependency === 'invalid' ? {} : [f.shared.descriptor, f.shared.descriptor];
    assert.equal((await f.loader.request(3, f.report)).state, 'failed');
    assert.equal(f.requests.length, 0);
  }
  const f = sharedFixture();
  assert.equal((await f.loader.request(3, f.report)).state, 'ready');
  const before = f.requests.length;
  f.packs[4].dependencies = [{ ...f.shared.descriptor, bytes: f.shared.descriptor.bytes + 1 }];
  assert.equal((await f.loader.request(4, f.report)).state, 'failed');
  assert.equal(f.requests.length, before);
});

test('large dependency sets cap simultaneous downloads and queued resources remain available', async () => {
  const resources = [4, 5, 6, 7].map(age => bundle(`shared-3-${age}`, `Shared ${age}`));
  const base = bundle('3', 'Unique age three');
  const sources = new Map([...resources, base].map(pack => [pack.descriptor.file, pack.data]));
  let release;
  const gate = new Promise(resolve => { release = resolve; });
  let calls = 0, active = 0, peak = 0;
  const f = fixture({ packs: { 3: { ...base.descriptor, dependencies: resources.map(pack => pack.descriptor) } },
    fetch: async file => { calls++; active++; peak = Math.max(peak, active); await gate; active--; return new Response(sources.get(file)); } });
  const request = f.loader.request(3, f.report);
  assert.equal(calls, 3);
  release();
  const result = await request;
  assert.equal(result.state, 'ready');
  assert.equal(result.paths.length, 5);
  assert.equal(calls, 5);
  assert.equal(peak, 3);
});
