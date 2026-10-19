'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const http = require('node:http');
const { createHash } = require('node:crypto');
const { chromium } = require('@playwright/test');
const api = require('../web/professional-media.js');
const png = fs.readFileSync('assets/images/words/absent.png');
function resource(data = png) {
  const hash = createHash('sha256').update(data).digest('hex');
  return { id: `sha256:${hash}`, sha256: hash, path: `professional-media/${hash}.png`, kind: 'image', format: 'png',
    compressed_bytes: data.length, decoded_bytes: data.readUInt32BE(16) * data.readUInt32BE(20) * 8,
    width: data.readUInt32BE(16), height: data.readUInt32BE(20) };
}
function manifest(rows = [resource()]) {
  return { schema_version: 1, course_id: 'retail', module_id: 'module01', curriculum_revision: 'test-1', resources: rows };
}

test('immutable module metadata rejects duplicate, missing, changed-context, unsupported, and over-budget media', () => {
  assert.equal(api.validateManifest(manifest()).resources.length, 1);
  assert.equal(api.validateDependencies(manifest(), [resource().id]).resources.length, 1);
  assert.throws(() => api.validateDependencies(manifest(), [`sha256:${'0'.repeat(64)}`]), /absent/);
  assert.throws(() => api.validateManifest(manifest([])), /nonempty/);
  assert.throws(() => api.validateManifest(manifest([resource(), resource()])), /only once/);
  assert.throws(() => api.validateManifest(manifest(), { course_id: 'nursing' }), /another module/);
  assert.throws(() => api.validateResource({ ...resource(), path: '../escape.png' }), /immutable/);
  assert.throws(() => api.validateResource({ ...resource(), id: 'picture-a' }), /SHA-256/);
  assert.throws(() => api.validateResource({ ...resource(), format: 'mp3' }), /immutable/);
  assert.throws(() => api.validateResource({ ...resource(), decoded_bytes: 1 }), /RGBA8/);
  assert.throws(() => api.validateResource({ ...resource(), compressed_bytes: api.LIMITS.compressed + 1 }), /budget/);
  const large = { ...resource(), width: 2048, height: 2048, decoded_bytes: 32 * 1024 * 1024 };
  const second = { ...large, sha256: 'b'.repeat(64), id: `sha256:${'b'.repeat(64)}`, path: `professional-media/${'b'.repeat(64)}.png` };
  assert.throws(() => api.validateManifest(manifest([large, second])), /32 MiB/);
  assert.throws(() => api.validateManifest({ ...manifest(), ignored: 'x'.repeat(api.LIMITS.manifest) }), /too large/);
});

test('real browser streaming bridge verifies hashes, bounds payloads, cancels stale requests, and retries failures', async () => {
  let behavior = 'normal';
  const server = http.createServer((request, response) => {
    response.setHeader('cache-control', 'no-store');
    if (request.url === '/') { response.writeHead(200, { 'content-type': 'text/html' }); response.end('<title>Raw professional media fixture</title>'); return; }
    if (behavior === 'missing') { response.writeHead(404); response.end(); return; }
    if (behavior === 'redirect') { response.writeHead(302, { location: '/' }); response.end(); return; }
    if (behavior === 'slow') { setTimeout(() => { if (!response.destroyed) { response.writeHead(200); response.end(png); } }, 300); return; }
    if (behavior === 'extra') { response.writeHead(200); response.write(png); response.end(Buffer.from([1])); return; }
    const data = Buffer.from(png);
    if (behavior === 'wrong' || behavior === 'cachedwrong') data[data.length - 1] ^= 1;
    if (behavior === 'cachedwrong') response.setHeader('cache-control', 'public, max-age=3600, immutable');
    if (behavior === 'short') { response.writeHead(200); response.end(data.subarray(0, -1)); return; }
    response.writeHead(200, { 'content-type': 'image/png', 'content-length': data.length }); response.end(data);
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage();
    await page.goto(`http://127.0.0.1:${server.address().port}/`);
    await page.addScriptTag({ content: fs.readFileSync(require.resolve('../web/professional-media.js'), 'utf8') });
    await page.evaluate(row => { window.row = row; window.bridge = ProfessionalMedia.createProfessionalMediaBridge({ timeoutMs: 120 }); }, resource());
    const first = await page.evaluate(async () => {
      const result = await bridge.fetchResource(row, 1);
      const bitmap = await createImageBitmap(new Blob([result.bytes], { type: 'image/png' }));
      return { ok: result.ok, bytes: result.bytes.length, width: bitmap.width, height: bitmap.height };
    });
    assert.deepEqual(first, { ok: true, bytes: png.length, width: resource().width, height: resource().height });
    for (const [mode, code] of [['missing', 'missing_asset'], ['wrong', 'hash_mismatch'], ['extra', 'size_mismatch'], ['short', 'size_mismatch'], ['slow', 'timeout'], ['cachedwrong', 'hash_mismatch']]) {
      behavior = mode;
      const failed = await page.evaluate(() => bridge.fetchResource(row, 2));
      assert.equal(failed.ok, false, mode); assert.equal(failed.code, code, mode); assert.equal(failed.retryable, true);
      behavior = 'normal';
      assert.equal((await page.evaluate(() => bridge.fetchResource(row, 2))).ok, true, `${mode} retry`);
    }
    behavior = 'redirect';
    assert.equal((await page.evaluate(() => bridge.fetchResource(row, 2))).ok, false);
    behavior = 'slow';
    await page.evaluate(() => { window.old = bridge.fetchResource(row, 3); });
    behavior = 'normal';
    const latest = await page.evaluate(async () => {
      const result = await bridge.fetchResource(row, 4);
      return { result: { ok: result.ok, generation: result.generation }, old: await window.old };
    });
    assert.deepEqual(latest.result, { ok: true, generation: 4 });
    assert.equal(latest.old.code, 'cancelled');
    const bridged = await page.evaluate(() => new Promise(resolve => {
      let synchronous = true;
      bridge.professionalMediaRequest(JSON.stringify({ request_id: 9, generation: 5, resource: row }), source => {
        const result = JSON.parse(source); result.synchronous = synchronous; resolve(result);
      });
      synchronous = false;
    }));
    assert.equal(bridged.ok, true); assert.equal(bridged.request_id, 9); assert.equal(bridged.synchronous, false);
    assert.deepEqual(Buffer.from(bridged.data_base64, 'base64'), png);
    await page.evaluate(() => { window.cancellation = bridge.fetchResource(row, 6); bridge.professionalMediaCancel(6); });
    assert.equal((await page.evaluate(() => cancellation)).code, 'cancelled');
  } finally { await browser.close(); await new Promise(resolve => server.close(resolve)); }
});
