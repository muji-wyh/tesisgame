const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { checkWordLibraryMotion } = require('../tools/word-library-motion.cjs');

const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const fixtureRoot = path.resolve('fixture-motion-library');
const runtimeKeys = ['id', 'path', 'frames', 'fps', 'frameSide', 'columns', 'posterFrame'];

// Minimal container metadata fixtures exercise the release checker without
// decoding artwork or depending on the production render job.
function atlas(width, height) {
  const bytes = Buffer.alloc(42);
  bytes.write('RIFF'); bytes.writeUInt32LE(34, 4); bytes.write('WEBP', 8);
  bytes.write('VP8X', 12); bytes.writeUInt32LE(10, 16); bytes[20] = 0x10;
  bytes.writeUIntLE(width - 1, 24, 3); bytes.writeUIntLE(height - 1, 27, 3);
  bytes.write('VP8 ', 30); bytes.writeUInt32LE(4, 34); bytes.writeUInt32LE(1, 38);
  return bytes;
}

function fixture(t) {
  const files = ['grain', 'walk'].map(id => {
    const bytes = atlas(1024, id === 'walk' ? 640 : 512);
    return { id, path: `assets/images/word-motion/${id}.webp`, frames: id === 'walk' ? 40 : 32,
      fps: id === 'walk' ? 24 : 12, frameSide: 128, columns: 8, posterFrame: id === 'walk' ? 19 : 0,
      bytes: bytes.length, sha256: digest(bytes), sourceSha256: (id === 'walk' ? 'a' : 'b').repeat(64),
      sourceRecord: 'docs/assets/word-library.json', creator: 'Reviewed source creator', license: 'CC0-1.0',
      profile: id === 'walk' ? 'authored_clip' : 'rigid_glint', adaptation: 'Reviewed motion adaptation',
      ...(id === 'grain' ? { uniqueFrames: 32, minimumOpaqueMargin: 4 } : {}) };
  });
  const manifest = { schema: 1, count: 2, status: 'Integrated', files };
  const runtime = { schema: 1, files: files.map(file => Object.fromEntries(runtimeKeys.map(key => [key, file[key]]))) };
  const library = { files: files.map(file => ({ id: file.id, sha256: file.sourceSha256,
    source: { creator: file.creator, license: file.license } })) };
  const authored = { files: [structuredClone(files[1])] };
  const mapping = { profiles: { authored_clip: {}, rigid_glint: {} }, files: files.map(({ id, profile }) => ({ id, profile })) };
  const images = new Map(files.map(file => [file.path, atlas(1024, file.id === 'walk' ? 640 : 512)]));
  const json = new Map([
    ['words.json', [{ id: 'grain', image: 'grain.png' }, { id: 'walk', image: 'walk.png' }, { id: 'the', image: '' }]],
    ['docs/assets/word-library-motion.json', manifest], ['data/word-motion.json', runtime],
    ['docs/assets/word-library.json', library], ['docs/assets/lv3-word-motion.json', authored],
    ['tools/vocabulary-art/library-motion-map.json', mapping]
  ]);
  t.mock.method(fs, 'readFileSync', filename => {
    const relative = path.relative(fixtureRoot, filename).replaceAll('\\', '/');
    if (json.has(relative)) return Buffer.from(JSON.stringify(json.get(relative)));
    assert.ok(images.has(relative), `Unexpected fixture read: ${relative}`);
    return images.get(relative);
  });
  const directory = files.map(file => `${file.id}.webp`);
  t.mock.method(fs, 'readdirSync', filename => {
    assert.equal(filename, path.join(fixtureRoot, 'assets/images/word-motion'));
    return directory;
  });
  return { manifest, runtime, library, authored, mapping, images, directory, check: () => checkWordLibraryMotion(fixtureRoot) };
}

test('the all-word motion check accepts matched source, runtime, atlas and authored timing receipts', t => {
  const f = fixture(t);
  assert.deepEqual(f.check(), { clips: 2, authored: 1, frames: 72, bytes: 84 });
});

test('motion coverage rejects missing, duplicate and context-only animation records', t => {
  const f = fixture(t);
  const original = structuredClone(f.runtime.files);
  for (const records of [original.slice(0, 1), [original[0], original[0]], [...original, { ...original[0], id: 'the' }]]) {
    f.runtime.files = records;
    assert.throws(f.check, /cover every pictured curriculum word exactly once/);
  }
  f.runtime.files = original;
  f.manifest.status = 'Local motion review';
  assert.throws(f.check, /cover every pictured curriculum word exactly once/);
});

test('runtime descriptors cannot drift from the reviewed frame layout or authored timing', t => {
  const f = fixture(t);
  f.runtime.files[0].fps = 24;
  assert.throws(f.check, /inconsistent runtime motion metadata: grain/);
  f.runtime.files[0].fps = 12;
  f.runtime.files[1].posterFrame = f.manifest.files[1].posterFrame = 20;
  assert.throws(f.check, /reviewed authored motion changed: walk/);
});

test('motion source and adaptation records must match the current reviewed artwork and mapped profile', t => {
  const f = fixture(t), file = f.manifest.files[0];
  for (const change of [{ sourceSha256: '0'.repeat(64) }, { license: 'Unknown' }, { creator: '' },
    { profile: 'unmapped' }, { adaptation: '' }]) {
    const original = { ...file };
    Object.assign(file, change);
    assert.throws(f.check, /stale word motion source attribution: grain/);
    Object.assign(file, original);
  }
});

test('static, clipped or altered atlas bytes fail the motion release check', t => {
  const f = fixture(t), file = f.manifest.files[0];
  file.uniqueFrames = 1;
  assert.throws(f.check, /Static, clipped or unsupported library motion: grain/);
  file.uniqueFrames = 32; file.minimumOpaqueMargin = 0;
  assert.throws(f.check, /Static, clipped or unsupported library motion: grain/);
  file.minimumOpaqueMargin = 4;
  const changed = Buffer.from(f.images.get(file.path)); changed[41] ^= 1;
  f.images.set(file.path, changed);
  assert.throws(f.check, /unreviewed word motion bytes: grain/);
});

test('even rehashed containers must contain complete alpha atlas metadata and the required frame dimensions', t => {
  const f = fixture(t), file = f.manifest.files[0];
  const replace = bytes => { f.images.set(file.path, bytes); file.bytes = bytes.length; file.sha256 = digest(bytes); };
  replace(atlas(1024, 128));
  assert.throws(f.check, /atlas dimensions disagree with its frames: grain/);
  replace(atlas(1024, 512).subarray(0, 41));
  assert.throws(f.check, /Invalid or truncated word motion atlas: grain/);
  const opaque = atlas(1024, 512); opaque[20] = 0;
  replace(opaque);
  assert.throws(f.check, /Invalid or truncated word motion atlas: grain/);
  const animated = atlas(1024, 512); animated[20] |= 0x02;
  replace(animated);
  assert.throws(f.check, /Invalid or truncated word motion atlas: grain/);
});

test('orphan atlases cannot ship outside the pictured curriculum', t => {
  const f = fixture(t);
  f.directory.push('the.webp');
  assert.throws(f.check, /Orphan word motion atlases/);
});
