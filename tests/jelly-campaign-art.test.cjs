const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const repoRoot = path.resolve(__dirname, '..');
const artRoot = path.join(repoRoot, 'assets', 'images', 'jelly-campaign');
const licenseHash = '618ad6b7a71d4fe2861829f0dce793eec43616a064e951ed34a517cf363f8fd7';
const expectedFiles = [
  'mountains.png', 'tree-pine.png', 'tree-orange.png', 'tree-snow.png',
  'tree-pine-snow.png', 'tree-palm.png', 'cactus.png', 'cottage.png', 'castle.png'
];
const reused = [
  [String.raw`assets\images\jelly-match\sky\day.png`, String.raw`docs\assets\jelly-sky.json`],
  ...['hills.png', 'tree.png', 'tree-long.png', 'foliage.png'].map(name =>
    [String.raw`assets\images\jelly-match\garden` + '\\' + name, String.raw`docs\assets\jelly-garden.json`]),
  ...['coral', 'mint', 'sky', 'lilac'].map(color =>
    [String.raw`assets\images\jelly-match\gel-${color}.png`, String.raw`docs\assets\jelly-match.json`])
];

function manifest() {
  const filename = path.join(artRoot, 'sources.json');
  assert.ok(fs.existsSync(filename), 'Campaign source acquisition manifest must exist');
  return JSON.parse(fs.readFileSync(filename, 'utf8'));
}

function sha256(bytes) {
  return crypto.createHash('sha256').update(bytes).digest('hex');
}

function dimensions(bytes, filename) {
  assert.ok(bytes.length >= 33, `${filename}: complete PNG header`);
  assert.deepEqual(bytes.subarray(0, 8), Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    `${filename}: PNG signature`);
  assert.equal(bytes.readUInt32BE(8), 13, `${filename}: IHDR length`);
  assert.equal(bytes.toString('ascii', 12, 16), 'IHDR', `${filename}: first chunk`);
  return [bytes.readUInt32BE(16), bytes.readUInt32BE(20)];
}

test('campaign manifest pins the reviewed 3D diorama source, rights and static-only acquisition', () => {
  const data = manifest();
  assert.equal(data.version, 2);
  assert.match(data.status, /integrated/);
  assert.match(data.acquired_on, /^\d{4}-\d{2}-\d{2}$/);
  assert.equal(data.license.id, 'CC0-1.0');
  assert.equal(data.license.output_sha256, licenseHash);
  assert.deepEqual(data.images.map(img => img.path).sort(), expectedFiles.slice().sort());
  for (const img of data.images) {
    assert.ok(img.width >= 200 && img.height >= 200, `${img.path}: production resolution`);
    assert.match(img.output_sha256, /^[a-f0-9]{64}$/, `${img.path}: recorded sha256`);
  }
});

test('all nine runtime PNGs match their recorded manifest bytes, hashes and dimensions', () => {
  const data = manifest();
  for (const img of data.images) {
    const output = fs.readFileSync(path.join(artRoot, img.path));
    assert.equal(output.length, img.bytes, `${img.path}: byte length`);
    assert.equal(sha256(output), img.output_sha256, `${img.path}: manifest SHA-256`);
    assert.deepEqual(dimensions(output, img.path), [img.width, img.height], `${img.path}: dimensions`);
  }
});

test('the original CC0 license is retained byte-for-byte', () => {
  const data = manifest();
  const license = fs.readFileSync(path.join(artRoot, data.license.path));
  assert.equal(sha256(license), licenseHash);
  assert.match(license.toString('utf8'), /Creative Commons Zero, CC0/);
});

test('the campaign directory excludes extra artwork and references existing sky, garden and gels', () => {
  const data = manifest();
  const allowed = new Set(['sources.json', 'LICENSE-CC0.txt', ...expectedFiles]);
  const entries = fs.readdirSync(artRoot, { withFileTypes: true });
  for (const entry of entries) {
    assert.ok(entry.isFile(), `${entry.name}: no nested preview or source directories`);
    const name = entry.name.endsWith('.png.import') ? entry.name.slice(0, -7) : entry.name;
    assert.ok(allowed.has(name), `${entry.name}: unexpected campaign asset`);
  }
  assert.deepEqual(entries.filter(entry => /\.png$/i.test(entry.name)).map(entry => entry.name).sort(),
    expectedFiles.slice().sort());
  assert.deepEqual(data.reuse, reused.map(([file, sourceRecord]) => ({ path: file, source_record: sourceRecord })));
  for (const [file, sourceRecord] of reused) {
    assert.ok(fs.existsSync(path.join(repoRoot, ...file.split('\\'))), `${file}: reused art exists`);
    assert.ok(fs.existsSync(path.join(repoRoot, ...sourceRecord.split('\\'))), `${sourceRecord}: provenance exists`);
  }
});

test('map medallions and challenge panels match their inspected CC0 UI manifest', () => {
  const directory = path.join(repoRoot, 'assets', 'images', 'ui', 'jelly-map');
  const data = JSON.parse(fs.readFileSync(path.join(directory, 'sources.json'), 'utf8'));
  assert.equal(data.source.license, 'CC0-1.0');
  assert.match(data.source.animations, /Static/);
  assert.deepEqual(data.images.map(image => image.file).sort(),
    ['stage-open.png', 'stage-locked.png', 'stage-boss.png', 'adventure-panel.png'].sort());
  for (const image of data.images) {
    const bytes = fs.readFileSync(path.join(directory, image.file));
    assert.equal(sha256(bytes), image.sha256, image.file);
    assert.equal(bytes.length, image.bytes, image.file);
    assert.deepEqual(dimensions(bytes, image.file), image.size);
  }
  const license = fs.readFileSync(path.join(directory, data.license.file));
  assert.equal(sha256(license), data.license.sha256);
});
