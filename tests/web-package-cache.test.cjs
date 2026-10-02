const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { brotliCompressSync, brotliDecompressSync, constants } = require('node:zlib');
const { compressWebAsset } = require('../tools/package-web.cjs');

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'web-compression-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  return root;
}

test('unchanged engine bytes reuse a complete byte-verified Brotli sidecar', t => {
  const root = fixture(t), bytes = Buffer.from('unchanged engine instructions '.repeat(4096));
  const compressed = brotliCompressSync(bytes, { params: { [constants.BROTLI_PARAM_QUALITY]: 4 } });
  const filename = path.join(root, 'previous-engine.wasm.br');
  fs.writeFileSync(filename, compressed);
  assert.deepEqual(compressWebAsset(bytes, [filename]), compressed,
    'Reuse the actual verified cache entry instead of recompressing it at quality 11');
  assert.deepEqual(brotliDecompressSync(compressWebAsset(bytes, [filename])), bytes);
});

test('changed content with the same length cannot reuse old compression', t => {
  const root = fixture(t), bytes = Buffer.from('current engine'), old = Buffer.from('retired engine');
  assert.equal(bytes.length, old.length);
  const filename = path.join(root, 'old.wasm.br');
  fs.writeFileSync(filename, brotliCompressSync(old));
  assert.deepEqual(brotliDecompressSync(compressWebAsset(bytes, [filename])), bytes);
});

test('missing, truncated and oversized cache entries are rebuilt or skipped', t => {
  const root = fixture(t), bytes = Buffer.from('current game pack');
  const truncated = path.join(root, 'truncated.br'), oversized = path.join(root, 'oversized.br');
  fs.writeFileSync(truncated, Buffer.from([0xff, 0x22]));
  fs.writeFileSync(oversized, brotliCompressSync(Buffer.alloc(65536)));
  assert.deepEqual(brotliDecompressSync(compressWebAsset(bytes,
    [path.join(root, 'missing.br'), truncated, oversized])), bytes);
});

test('a valid Brotli prefix cannot conceal trailing garbage or a second stream in the cache', t => {
  const root = fixture(t), bytes = Buffer.from('complete game bytes '.repeat(1024));
  const compressed = brotliCompressSync(bytes);
  const tails = [Buffer.from('ignored trailing garbage'), brotliCompressSync(Buffer.from('second stream'))];
  for (const [index, tail] of tails.entries()) {
    const filename = path.join(root, `tailed-${index}.br`), tainted = Buffer.concat([compressed, tail]);
    fs.writeFileSync(filename, tainted);
    const result = compressWebAsset(bytes, [filename]);
    assert.notDeepEqual(result, tainted, 'Never publish a cache that contains unconsumed compressed bytes');
    const decoded = brotliDecompressSync(result, { info: true });
    assert.deepEqual(decoded.buffer, bytes);
    assert.equal(decoded.engine.bytesWritten, result.length);
  }
});
