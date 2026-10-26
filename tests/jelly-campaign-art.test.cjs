const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const repoRoot = path.resolve(__dirname, '..');
const artRoot = path.join(repoRoot, 'assets', 'images', 'jelly-campaign');
const sourceRoot = String.raw`Q:\uwok\Kenney Game Assets All-in-1 3.7.0\2D assets\Background Elements Remastered`;
const licenseHash = '618ad6b7a71d4fe2861829f0dce793eec43616a064e951ed34a517cf363f8fd7';
const images = [
  ['mountains.png', String.raw`Backgrounds\Elements\mountains.png`, 1024, 400, 5254,
    '33e787985553a8f9ade137d6bb7af563b63a272ce0c2a7d18f4f8481804fbe23'],
  ['tree-pine.png', String.raw`PNG\Retina\treePine.png`, 212, 508, 4714,
    'a7314cedbba00c3d0e5259391d7339d12a21baadc9c72fbdf3ef3b773107e294'],
  ['tree-orange.png', String.raw`PNG\Retina\treeOrange.png`, 202, 518, 5423,
    'd0c1bf4535472d8fa2694c94f5d7ff38ea2bd5e795437b1e18379840b7e6d5c5'],
  ['tree-snow.png', String.raw`PNG\Retina\treeSnow.png`, 202, 462, 6161,
    '9ffdc49074fb69c1638ef853a9a631989ca7e61209ca7cbc08ac9b6099bb5fb3'],
  ['tree-pine-snow.png', String.raw`PNG\Retina\treePineSnow.png`, 212, 494, 5954,
    'ca544d1abe51f69108c6399cb9afeae0e81e27b6119041fe15c00753669576c3'],
  ['tree-palm.png', String.raw`PNG\Retina\treePalm.png`, 400, 476, 7972,
    'dbd582eec5a5323446ac54a44800e9a9c8482941ce7356d53aa79cce3fcc34ec'],
  ['cactus.png', String.raw`PNG\Retina\cactus1.png`, 192, 278, 2954,
    '43a58b9f2f2cd483056aef6fea3b26d3be1d2f70f77670d20852b95e632544c5'],
  ['cottage.png', String.raw`PNG\Retina\houseSmall1.png`, 150, 100, 1743,
    '424a30b6d3d85bc6ad1aca52ec910099a89f32c80a338ca40478981234455ae6'],
  ['castle.png', String.raw`PNG\Retina\castleSmall.png`, 216, 170, 2224,
    '821c3fffd43f9f33d529ba7de9890e41f37415423ccf01fc01f566cb74dca7ca']
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

test('campaign manifest pins the reviewed local source, rights and static-only acquisition', () => {
  const data = manifest();
  assert.equal(data.version, 1);
  assert.equal(data.status, 'acquired; integrated and native-render reviewed');
  assert.match(data.acquired_on, /^\d{4}-\d{2}-\d{2}$/);
  assert.deepEqual(data.source, {
    title: 'Background Elements Remastered',
    url: 'https://kenney.nl/assets/background-elements-remastered',
    creator: 'Kenney',
    version: '1.0',
    local_directory: sourceRoot,
    acquisition: 'Unmodified copies from the user-supplied, already-acquired local library; no download or purchase.',
    selection: 'Parent-delegated autonomous acquisition after source inspection; not a user visual-concept sign-off.',
    type: '2D PNG artwork',
    animations: 'Static artwork; no source animation clips.'
  });
  assert.deepEqual(data.license, {
    id: 'CC0-1.0',
    url: 'https://creativecommons.org/publicdomain/zero/1.0/',
    path: 'LICENSE-CC0.txt',
    source_relative_path: 'License.txt',
    source_sha256: licenseHash,
    output_sha256: licenseHash
  });
  assert.deepEqual(data.images, images.map(([file, source, width, height, bytes, hash]) => ({
    path: file,
    source_relative_path: source,
    width,
    height,
    bytes,
    source_sha256: hash,
    output_sha256: hash,
    processing: 'Unmodified original PNG bytes.',
    animation: 'static; no source animation'
  })));
  assert.match(data.review.kind, /Source artwork inspected before integration/);
  assert.match(data.review.kind, /all eleven scenic chapters rendered and reviewed/);
  assert.match(data.review.kind, /Browser verification is recorded separately/);
  assert.match(data.review.preview_directory, /\\files\\campaign-art-review$/);
  assert.notEqual(path.resolve(data.review.preview_directory), artRoot);
});

test('all nine runtime PNGs retain the independently pinned original bytes and dimensions', () => {
  manifest();
  for (const [file, source, width, height, bytes, hash] of images) {
    const output = fs.readFileSync(path.join(artRoot, file));
    assert.equal(output.length, bytes, `${file}: byte length`);
    assert.equal(sha256(output), hash, `${file}: unchanged original SHA-256`);
    assert.deepEqual(dimensions(output, file), [width, height], `${file}: source dimensions`);
    if (fs.existsSync(sourceRoot)) {
      const original = fs.readFileSync(path.join(sourceRoot, ...source.split('\\')));
      assert.deepEqual(output, original, `${file}: byte-for-byte local source identity`);
    }
  }
});

test('the original CC0 license is retained byte-for-byte and identifies the correct pack', () => {
  const data = manifest();
  const license = fs.readFileSync(path.join(artRoot, data.license.path));
  assert.equal(sha256(license), licenseHash);
  assert.match(license.toString('utf8'), /Background Elements Remastered \(1\.0\)/);
  assert.match(license.toString('utf8'), /Created\/distributed by Kenney/);
  assert.match(license.toString('utf8'), /Creative Commons Zero, CC0/);
  if (fs.existsSync(sourceRoot)) {
    assert.deepEqual(license, fs.readFileSync(path.join(sourceRoot, 'License.txt')));
  }
});

test('the campaign directory excludes extra artwork and references existing sky, garden and gels', () => {
  const data = manifest();
  const allowed = new Set(['sources.json', 'LICENSE-CC0.txt', ...images.map(([file]) => file)]);
  const entries = fs.readdirSync(artRoot, { withFileTypes: true });
  for (const entry of entries) {
    assert.ok(entry.isFile(), `${entry.name}: no nested preview or source directories`);
    const name = entry.name.endsWith('.png.import') ? entry.name.slice(0, -7) : entry.name;
    assert.ok(allowed.has(name), `${entry.name}: unexpected campaign asset`);
  }
  assert.deepEqual(entries.filter(entry => /\.png$/i.test(entry.name)).map(entry => entry.name).sort(),
    images.map(([file]) => file).sort());
  assert.deepEqual(data.reuse, reused.map(([file, sourceRecord]) => ({ path: file, source_record: sourceRecord })));
  for (const [file, sourceRecord] of reused) {
    assert.ok(fs.existsSync(path.join(repoRoot, ...file.split('\\'))), `${file}: reused art exists`);
    assert.ok(fs.existsSync(path.join(repoRoot, ...sourceRecord.split('\\'))), `${sourceRecord}: provenance exists`);
  }
});

test('map medallions and challenge panels preserve the inspected original CC0 UI artwork', () => {
  const directory = path.join(repoRoot, 'assets', 'images', 'ui', 'jelly-map');
  const data = JSON.parse(fs.readFileSync(path.join(directory, 'sources.json'), 'utf8'));
  assert.equal(data.source.creator, 'Kenney');
  assert.equal(data.source.license, 'CC0-1.0');
  assert.equal(data.source.version, '1.1');
  assert.match(data.source.animations, /Static/);
  assert.deepEqual(data.images.map(image => image.file).sort(),
    ['stage-open.png', 'stage-locked.png', 'adventure-panel.png'].sort());
  for (const image of data.images) {
    const bytes = fs.readFileSync(path.join(directory, image.file));
    assert.equal(sha256(bytes), image.sha256, image.file);
    assert.equal(bytes.length, image.bytes, image.file);
    assert.deepEqual(dimensions(bytes, image.file), image.size);
  }
  const license = fs.readFileSync(path.join(directory, data.license.file));
  assert.equal(sha256(license), data.license.sha256);
  assert.match(license.toString('utf8'), /UI Pack - Adventure \(1\.1\)/);
});
