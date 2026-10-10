const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { selectSource, readCachedPicture } = require('../tools/vocabulary-art/prepare-library.cjs');

const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const directories = { root: path.resolve('fixture-library'), mulberryRoot: path.resolve('fixture-mulberry') };
const word = { id: 'grain', text: 'grain', meaning: 'A small hard seed grown for food' };
const emoji = { local: 'fluent/grain.png', path: 'assets/Ear of rice/3D/ear_of_rice_3d.png', sha256: 'a'.repeat(64) };
const symbol = { source: 'grains.svg', sourceSha256: 'b'.repeat(64) };
const extra = { local: 'curated/grain.png', source: { provider: 'mulberry', sha256: 'c'.repeat(64) },
  crop: { left: 4, top: 5, width: 120, height: 130 } };

test('a missing reviewed composition fails instead of reverting to available lower-priority artwork', t => {
  const requested = [];
  t.mock.method(fs, 'existsSync', filename => {
    requested.push(filename);
    return filename !== path.join(directories.root, extra.local);
  });
  assert.throws(() => selectSource(word, { extra, emoji, symbol }, directories),
    /Missing reviewed mulberry source for grain:.*curated[\\/]grain\.png.*Acquire or regenerate/);
  assert.deepEqual(requested, [path.join(directories.root, extra.local)]);
});

test('a missing Fluent illustration fails even when the original Mulberry source remains available', t => {
  t.mock.method(fs, 'existsSync', filename => filename === path.join(directories.mulberryRoot, symbol.source));
  assert.throws(() => selectSource(word, { emoji, symbol }, directories),
    /Missing reviewed fluent-emoji source for grain:.*fluent[\\/]grain\.png.*Acquire or regenerate/);
  assert.throws(() => selectSource(word, { emoji: { ...emoji, sha256: undefined }, symbol }, directories),
    /Missing reviewed Fluent source hash: grain/);
});

test('available reviewed sources retain their selected composition and truly unmapped words remain missing', t => {
  t.mock.method(fs, 'existsSync', () => true);
  const selected = selectSource(word, { extra, emoji, symbol }, directories);
  assert.equal(selected.input, path.join(directories.root, extra.local));
  assert.equal(selected.source, extra.source);
  assert.deepEqual(selected.crop, extra.crop);
  assert.equal(selected.vector, false);
  assert.equal(selectSource(word, {}, directories), null);
});

function cachedFixture(t) {
  const original = Buffer.from('reviewed picture bytes');
  let current = original;
  const output = path.join(directories.root, 'pictures/grain.webp');
  const receipt = { inputSha256: 'd'.repeat(64), compositionKey: '{}', bytes: original.length, sha256: digest(original) };
  const context = { inputSha256: receipt.inputSha256, compositionKey: '{}', rendererHash: 'e'.repeat(64), previousRendererHash: 'e'.repeat(64) };
  t.mock.method(fs, 'existsSync', filename => filename === output);
  t.mock.method(fs, 'readFileSync', filename => {
    assert.equal(filename, output);
    return current;
  });
  return { original, output, receipt, context, replace: bytes => { current = bytes; } };
}

test('unchanged reviewed output can be reused but changed input, composition or renderer requires rendering', t => {
  const fixture = cachedFixture(t);
  assert.equal(readCachedPicture(fixture.output, fixture.receipt, fixture.context), fixture.original);
  for (const change of [{ inputSha256: 'f'.repeat(64) }, { compositionKey: '{"crop":null}' }, { rendererHash: 'f'.repeat(64) }]) {
    assert.equal(readCachedPicture(fixture.output, fixture.receipt, { ...fixture.context, ...change }), null);
  }
});

test('modified and truncated staged pictures require rendering instead of acquiring a new approved hash', t => {
  const fixture = cachedFixture(t);
  const modified = Buffer.from(fixture.original);
  modified[4] ^= 1;
  fixture.replace(modified);
  assert.equal(readCachedPicture(fixture.output, fixture.receipt, fixture.context), null,
    'A same-length modification must not be reapproved');
  fixture.replace(fixture.original.subarray(0, fixture.original.length - 1));
  assert.equal(readCachedPicture(fixture.output, fixture.receipt, fixture.context), null,
    'An interrupted write must not be reapproved');
});

test('missing staging files and missing output receipts require rendering', t => {
  const fixture = cachedFixture(t);
  assert.equal(readCachedPicture(fixture.output, undefined, fixture.context), null);
  assert.equal(readCachedPicture(fixture.output, { ...fixture.receipt, sha256: undefined }, fixture.context), null);
  assert.equal(readCachedPicture(fixture.output, { ...fixture.receipt, bytes: undefined }, fixture.context), null);
  assert.equal(readCachedPicture(path.join(directories.root, 'pictures/absent.webp'), fixture.receipt, fixture.context), null);
});
