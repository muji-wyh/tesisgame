const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const http = require('node:http');
const { once } = require('node:events');
const { createHash } = require('node:crypto');
const { brotliCompressSync, brotliDecompressSync } = require('node:zlib');
const { createWebServer } = require('../tools/serve-web.cjs');

async function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'web-server-'));
  const bytes = Buffer.from('GDPC complete native game bytes '.repeat(1024));
  const mainPack = `game-${createHash('sha256').update(bytes).digest('hex').slice(0, 16)}.pck.br`;
  const compressed = brotliCompressSync(bytes);
  fs.writeFileSync(path.join(root, mainPack), compressed);
  fs.writeFileSync(path.join(root, 'index.html'), '<title>Grow with Pip</title>');
  fs.writeFileSync(path.join(root, 'engine-0123456789abcdef.js'), 'window.engineLoaded = true;');
  fs.writeFileSync(path.join(root, 'engine-0123456789abcdef.js.br'), brotliCompressSync(Buffer.from('window.engineLoaded = true;')));
  const server = createWebServer(root);
  t.after(async () => {
    await new Promise(resolve => { server.close(resolve); server.closeAllConnections(); });
    fs.rmSync(root, { recursive: true, force: true });
  });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  return { root, bytes, mainPack, compressed, url: `http://127.0.0.1:${server.address().port}` };
}

function rawRequest(url, options = {}) {
  return new Promise((resolve, reject) => {
    http.get(url, options, response => {
      const chunks = [];
      response.on('data', chunk => chunks.push(chunk));
      response.on('error', reject);
      response.on('end', () => resolve({ status: response.statusCode, headers: response.headers, bytes: Buffer.concat(chunks) }));
    }).on('error', reject);
  });
}

test('the explicit compressed pack URL delivers one stream that Fetch decodes to native game bytes', async t => {
  const { root, bytes, mainPack, compressed, url } = await fixture(t);
  assert.equal(fs.existsSync(path.join(root, mainPack.slice(0, -3))), false);
  const raw = await rawRequest(`${url}/${mainPack}`, { headers: { 'Accept-Encoding': 'br' } });
  assert.equal(raw.status, 200);
  assert.equal(raw.headers['content-encoding'], 'br');
  assert.equal(raw.headers['content-type'], 'application/octet-stream');
  assert.equal(Number(raw.headers['content-length']), compressed.length);
  assert.equal(raw.headers.vary, 'Accept-Encoding');
  assert.deepEqual(raw.bytes, compressed, 'The server must not compress a Brotli file a second time');
  assert.deepEqual(brotliDecompressSync(raw.bytes), bytes);
  const response = await fetch(`${url}/${mainPack}?review=1`);
  assert.equal(response.status, 200);
  assert.deepEqual(Buffer.from(await response.arrayBuffer()), bytes, 'Godot receives decoded PCK data');
  const head = await rawRequest(`${url}/${mainPack}`, { method: 'HEAD' });
  assert.equal(head.status, 200);
  assert.equal(head.headers['content-encoding'], 'br');
  assert.equal(Number(head.headers['content-length']), compressed.length);
  assert.equal(head.bytes.length, 0);
});

test('missing packs return an ordinary error without a misleading encoding header', async t => {
  const { url } = await fixture(t);
  const response = await fetch(`${url}/game-0000000000000000.pck.br`);
  assert.equal(response.status, 404);
  assert.equal(response.headers.get('content-encoding'), null);
  assert.equal(await response.text(), 'Game pack not found.');
});

test('the pack handler preserves HTML and negotiated engine asset delivery', async t => {
  const { url } = await fixture(t);
  const html = await fetch(`${url}/`);
  assert.equal(html.status, 200);
  assert.equal(html.headers.get('content-encoding'), null);
  assert.equal(await html.text(), '<title>Grow with Pip</title>');
  const engine = await rawRequest(`${url}/engine-0123456789abcdef.js`, { headers: { 'Accept-Encoding': 'br' } });
  assert.equal(engine.status, 200);
  assert.equal(engine.headers['content-encoding'], 'br');
  assert.equal(brotliDecompressSync(engine.bytes).toString(), 'window.engineLoaded = true;');
  const identity = await rawRequest(`${url}/engine-0123456789abcdef.js`);
  assert.equal(identity.status, 200);
  assert.equal(identity.headers['content-encoding'], undefined);
  assert.equal(identity.bytes.toString(), 'window.engineLoaded = true;');
});
