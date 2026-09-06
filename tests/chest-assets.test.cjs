const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const root = path.join(__dirname, '..');
const chestRoot = path.join(root, 'assets', 'chests');
const partNames = ['chest', ...Array.from({ length: 8 }, (_, index) => String(index + 1).padStart(2, '0'))];
const pngSignature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
const expectedParticles = {
  glow: 'assets/chests/particles/portal_glow.png',
  ring: 'assets/chests/particles/ring.png',
  spark: 'assets/chests/particles/sparkle3.png',
  ray: 'assets/chests/particles/lightray1.png',
  burst: 'assets/chests/particles/explosion_spike01.png',
  orb: 'assets/chests/particles/magic_orb2.png'
};
const expectedFiles = [
  ...['Royal', 'Energy'].flatMap((style) => [
    { path: `assets/chests/${style.toLowerCase()}/closed.png`, source: `Chests/${style}/Sprites/SPR_${style}_Close.png` },
    { path: `assets/chests/${style.toLowerCase()}/open.png`, source: `Chests/${style}/Sprites/SPR_${style}_Open.png` }
  ]),
  ...partNames.map((name) => ({
    path: `assets/chests/crystal/${name === 'chest' ? 'base' : `part_${name}`}.png`,
    source: `Chests/Crystal/Sprites/SPR_${name}.png`
  })),
  ...Object.values(expectedParticles).map((filename) => ({
    path: filename, source: `Particles/Textures/${path.posix.basename(filename)}`
  }))
];
const sha256 = (bytes) => crypto.createHash('sha256').update(bytes).digest('hex');
const absolute = (relativePath) => path.join(root, ...relativePath.split('/'));

function readManifest() {
  const filename = path.join(chestRoot, 'manifest.json');
  assert.ok(fs.existsSync(filename), 'Missing imported chest manifest');
  return JSON.parse(fs.readFileSync(filename, 'utf8'));
}

function readPng(relativePath) {
  const filename = absolute(relativePath);
  assert.ok(fs.existsSync(filename), `Missing imported PNG: ${relativePath}`);
  const bytes = fs.readFileSync(filename);
  assert.ok(bytes.length > 32, relativePath);
  assert.deepEqual(bytes.subarray(0, 8), pngSignature, relativePath);
  assert.equal(bytes.readUInt32BE(8), 13, `Invalid IHDR length: ${relativePath}`);
  assert.equal(bytes.toString('ascii', 12, 16), 'IHDR', relativePath);
  const width = bytes.readUInt32BE(16);
  const height = bytes.readUInt32BE(20);
  assert.ok(width > 0 && height > 0, relativePath);
  return { bytes, width, height };
}

function listFiles(directory) {
  assert.ok(fs.existsSync(directory), `Missing chest directory: ${directory}`);
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const filename = path.join(directory, entry.name);
    return entry.isDirectory() ? listFiles(filename) : [path.relative(root, filename).split(path.sep).join('/')];
  });
}

function assertMatrixClose(actual, expected, label) {
  assert.equal(actual.length, 6, label);
  actual.forEach((value, index) => {
    assert.ok(Math.abs(value - expected[index]) < 1e-8, `${label}[${index}]: ${value} != ${expected[index]}`);
  });
}

function crystalFixture() {
  const flow = (values) => `{${Object.entries(values).map(([key, value]) => `${key}: ${value}`).join(', ')}}`;
  const gameObject = (id, name) => `--- !u!1 &${id}\nGameObject:\n  m_Name: ${name}\n`;
  const transform = (id, gameId, parent, position, rotation, scale) => `--- !u!4 &${id}
Transform:
  m_GameObject: {fileID: ${gameId}}
  m_LocalPosition: ${flow(position)}
  m_LocalRotation: ${flow(rotation)}
  m_LocalScale: ${flow(scale)}
  m_Father: {fileID: ${parent}}
`;
  const rootTransformId = '9007199254740993';
  const middleTransformId = '9007199254740995';
  const origin = { x: 0, y: 0, z: 0 };
  const identity = { x: 0, y: 0, z: 0, w: 1 };
  const unit = { x: 1, y: 1, z: 1 };
  const rootTransform = transform(rootTransformId, '9007199254740992', '0',
    { x: 2, y: 3, z: 0 }, { x: 0, y: 0, z: Math.SQRT1_2, w: Math.SQRT1_2 }, { x: 2, y: 3, z: 1 });
  const middleTransform = transform(middleTransformId, '9007199254740994', rootTransformId,
    { x: 1, y: -2, z: 0 }, identity, { x: -1, y: 0.5, z: 1 });
  const documents = [
    gameObject('9007199254740992', 'Root'), rootTransform,
    gameObject('9007199254740994', 'Middle'), middleTransform
  ];
  const transforms = [];
  const renderers = [];
  const sprites = partNames.map((name, index) => {
    const gameId = String(9007199254741000n + BigInt(index) * 10n);
    const transformId = String(BigInt(gameId) + 1n);
    const rendererId = String(BigInt(gameId) + 2n);
    const guid = String(index + 1).padStart(32, '0');
    let position = origin;
    let rotation = identity;
    let scale = unit;
    if (name === '01') {
      position = { x: 4, y: 2, z: 0 };
      rotation = { x: 0, y: 0, z: Math.SQRT1_2, w: Math.SQRT1_2 };
      scale = { x: 0.25, y: 0.75, z: 1 };
    } else if (name === '03') {
      rotation = { x: 0, y: 0, z: Math.sin(Math.PI / 8), w: Math.cos(Math.PI / 8) };
    }
    const transformDocument = transform(transformId, gameId, middleTransformId, position, rotation, scale);
    const rendererDocument = `--- !u!212 &${rendererId}
SpriteRenderer:
  m_GameObject: {fileID: ${gameId}}
  m_Sprite: {fileID: 21300000, guid: ${guid}, type: 3}
  m_SortingOrder: ${index - 4}
  m_FlipX: ${name === '01' ? 1 : 0}
  m_FlipY: ${name === '03' ? 1 : 0}
  m_DrawMode: 0
`;
    documents.push(gameObject(gameId, name), transformDocument, rendererDocument);
    transforms.push(transformDocument);
    renderers.push(rendererDocument);
    return {
      name, texture: `assets/chests/crystal/${name === 'chest' ? 'base' : `part_${name}`}.png`,
      guid, ppu: name === '01' ? 50 : 100, pivot: name === '01' ? [0.25, 0.75] : [0.5, 0.5]
    };
  });
  return { text: documents.join(''), sprites, rootTransform, middleTransform, middleTransformId, transforms, renderers };
}

test('all nineteen selected chest and particle PNGs exist with valid IHDR dimensions', () => {
  for (const file of expectedFiles) {
    const image = readPng(file.path);
    if (/\/(?:royal|energy)\//.test(file.path)) {
      assert.equal(image.width, 1024, file.path);
      assert.equal(image.height, 1024, file.path);
    }
  }
});

test('the chest manifest has exactly the required three styles and particle mappings', () => {
  const manifest = readManifest();
  assert.deepEqual(Object.keys(manifest).sort(), ['version', 'source', 'styles', 'particles', 'files'].sort());
  assert.equal(manifest.version, 1);
  assert.equal(manifest.source, 'Modern 2D Animated Chests Pack_FREE Demo 1.0.2');
  assert.deepEqual(Object.keys(manifest.styles).sort(), ['crystal', 'energy', 'royal']);
  for (const style of ['royal', 'energy']) {
    assert.deepEqual(manifest.styles[style], {
      closed: `assets/chests/${style}/closed.png`,
      open: `assets/chests/${style}/open.png`
    });
  }
  assert.deepEqual(Object.keys(manifest.styles.crystal), ['parts']);
  assert.deepEqual(manifest.particles, expectedParticles);
});

test('Crystal has nine unique parts with finite nonsingular Godot transforms and explicit drawing metadata', () => {
  const parts = readManifest().styles.crystal.parts;
  assert.equal(parts.length, 9);
  assert.deepEqual(parts.map(({ name }) => name).sort(), [...partNames].sort());
  assert.equal(new Set(parts.map(({ texture }) => texture)).size, 9);
  for (const part of parts) {
    assert.deepEqual(Object.keys(part).sort(), ['name', 'texture', 'transform', 'pivot', 'order', 'flip_h', 'flip_v'].sort());
    assert.equal(part.texture, `assets/chests/crystal/${part.name === 'chest' ? 'base' : `part_${part.name}`}.png`);
    assert.equal(part.transform.length, 6);
    assert.ok(part.transform.every(Number.isFinite), part.name);
    const [a, b, c, d] = part.transform;
    assert.ok(Math.abs(a * d - b * c) > 1e-12, `Singular transform: ${part.name}`);
    assert.deepEqual(part.pivot, [0.5, 0.5], part.name);
    assert.ok(Number.isSafeInteger(part.order), part.name);
    assert.equal(typeof part.flip_h, 'boolean', part.name);
    assert.equal(typeof part.flip_v, 'boolean', part.name);
  }
});

test('the manifest records exactly nineteen original paths, hashes and image dimensions', () => {
  const files = readManifest().files;
  assert.equal(files.length, 19);
  assert.deepEqual(
    files.map(({ path: output, source }) => ({ path: output, source })).sort((a, b) => a.path.localeCompare(b.path)),
    [...expectedFiles].sort((a, b) => a.path.localeCompare(b.path))
  );
  for (const file of files) {
    assert.deepEqual(Object.keys(file).sort(), ['path', 'source', 'sha256', 'width', 'height'].sort());
    assert.match(file.sha256, /^[a-f0-9]{64}$/);
    const image = readPng(file.path);
    assert.equal(file.width, image.width, file.path);
    assert.equal(file.height, image.height, file.path);
    assert.equal(file.sha256, sha256(image.bytes), file.path);
  }
});

test('only the nineteen selected PNGs are imported and Godot image sidecars are allowed', () => {
  const files = listFiles(chestRoot);
  assert.deepEqual(files.filter((file) => /\.png$/i.test(file)).sort(), expectedFiles.map(({ path: filename }) => filename).sort());
  assert.deepEqual(files.filter((file) => /\.(?:meta|prefab|anim|mat|cs)$/i.test(file)), []);
});

test('SOURCE documents the free demo version, selected paths and non-imported Unity behavior', () => {
  const filename = path.join(chestRoot, 'SOURCE.txt');
  assert.ok(fs.existsSync(filename), 'Missing chest source documentation');
  const source = fs.readFileSync(filename, 'utf8');
  assert.match(source, /Modern 2D Animated Chests Pack_FREE Demo 1\.0\.2/);
  assert.match(source, /Unity behaviors were not imported/);
  for (const file of expectedFiles) assert.ok(source.includes(file.source), file.source);
  assert.match(source, /100.*pixels.*Unity.*unit/i);
  assert.match(source, /y.down/i);
  assert.match(source, /11 original PNGs contain trailing data after IEND/);
  assert.match(source, /trailing bytes are preserved byte-for-byte/);
});

test('the actual Crystal rest pose retains both the 0.67 ancestor scale and 0.85 base X scale', () => {
  const parts = new Map(readManifest().styles.crystal.parts.map((part) => [part.name, part]));
  const poses = {
    chest: [0, 0, 0],
    '01': [-79.1605, 12.06, 5],
    '02': [-215.8405, 97.82, 1],
    '03': [-189.074, -116.58, 3],
    '04': [-69.87765, -198.722, 2],
    '05': [98.5235, -70.35, 2],
    '06': [100.8015, 158.79, 2],
    '07': [229.5085, 64.99, 2],
    '08': [189.074, -127.3, 2]
  };
  for (const [name, [x, y, order]] of Object.entries(poses)) {
    const part = parts.get(name);
    const scale = name === '01' ? 0.83206 : 1;
    assertMatrixClose(part.transform, [0.5695 * scale, 0, 0, 0.67 * scale, x, y], name);
    assert.equal(part.order, order, name);
    assert.equal(part.flip_h, false, name);
    assert.equal(part.flip_v, false, name);
  }
});

test('the importer composes full parent matrices, preserves large fileIDs and converts PPU/y direction', () => {
  const { buildCrystalParts } = require('../tools/import-chests.cjs');
  const fixture = crystalFixture();
  const parts = buildCrystalParts(fixture.text, fixture.sprites);
  assert.equal(parts.length, 9);
  const one = parts.find(({ name }) => name === '01');
  assertMatrixClose(one.transform, [-0.75, 0, 0, 3, 500, 300], 'rotated and reflected 01');
  assert.deepEqual(one.pivot, [0.25, 0.75]);
  assert.equal(one.order, -3);
  assert.equal(one.flip_h, true);
  assert.equal(one.flip_v, false);
  const three = parts.find(({ name }) => name === '03');
  assertMatrixClose(three.transform, [
    -1.5 * Math.SQRT1_2, 2 * Math.SQRT1_2, 1.5 * Math.SQRT1_2, 2 * Math.SQRT1_2, 800, -500
  ], 'sheared 03');
  assert.equal(three.flip_v, true);
});

test('parsed matrices use JSON-stable zero components in the returned manifest', () => {
  const { buildCrystalParts } = require('../tools/import-chests.cjs');
  const fixture = crystalFixture();
  const unrotatedRoot = fixture.rootTransform.replace(/m_LocalRotation: \{.*\}/, 'm_LocalRotation: {x: 0, y: 0, z: 0, w: 1}');
  const parts = buildCrystalParts(fixture.text.replace(fixture.rootTransform, unrotatedRoot), fixture.sprites);
  for (const part of parts) {
    for (const value of part.transform) assert.equal(Object.is(value, -0), false, `JSON-unstable signed zero: ${part.name}`);
  }
});

test('single-sprite metadata parsing preserves actual pivots and rejects unsupported metadata', () => {
  const { parseSpriteMetadata } = require('../tools/import-chests.cjs');
  const metadata = `fileFormatVersion: 2
guid: 618e3041b039886449f692bff802e65d
TextureImporter:
  spriteMode: 1
  spritePixelsToUnits: 50
  spritePivot: {x: 0.25, y: 0.75}
  textureType: 8
`;
  assert.deepEqual(parseSpriteMetadata(metadata, 'fixture.meta'), {
    guid: '618e3041b039886449f692bff802e65d', ppu: 50, pivot: [0.25, 0.75]
  });
  assert.throws(() => parseSpriteMetadata(metadata.replace('spriteMode: 1', 'spriteMode: 2')), /single.sprite/i);
  assert.throws(() => parseSpriteMetadata(metadata.replace('spritePixelsToUnits: 50', 'spritePixelsToUnits: 0')), /PPU|pixels.*units/i);
  assert.throws(() => parseSpriteMetadata(metadata.replace('spritePixelsToUnits: 50', 'spritePixelsToUnits: Infinity')), /number|finite/i);
  assert.throws(() => parseSpriteMetadata(metadata.replace('x: 0.25', 'x: 1.25')), /pivot/i);
  assert.throws(() => parseSpriteMetadata(metadata.replace('618e3041b039886449f692bff802e65d', 'not-a-guid')), /guid/i);
});

test('Crystal parsing rejects missing and duplicate selected sprites', () => {
  const { buildCrystalParts } = require('../tools/import-chests.cjs');
  const fixture = crystalFixture();
  assert.throws(() => buildCrystalParts(fixture.text.replace(fixture.renderers[8], ''), fixture.sprites), /missing.*08/i);
  const duplicate = fixture.renderers[1].replace(/^--- !u!212 &\d+/, '--- !u!212 &999999999999999999');
  assert.throws(() => buildCrystalParts(fixture.text + duplicate, fixture.sprites), /duplicate.*01/i);
  const duplicateGuid = fixture.sprites.map((sprite, index) => index === 8 ? { ...sprite, guid: fixture.sprites[1].guid } : sprite);
  assert.throws(() => buildCrystalParts(fixture.text, duplicateGuid), /duplicate.*guid/i);
});

test('Crystal parsing rejects unresolved parents, transform cycles and duplicate fileIDs', () => {
  const { buildCrystalParts } = require('../tools/import-chests.cjs');
  const fixture = crystalFixture();
  const unresolved = fixture.text.replace(
    `m_Father: {fileID: ${fixture.middleTransformId}}`, 'm_Father: {fileID: 999999999999999999}'
  );
  assert.throws(() => buildCrystalParts(unresolved, fixture.sprites), /unresolved.*parent/i);
  const cycle = fixture.text.replace('m_Father: {fileID: 0}', `m_Father: {fileID: ${fixture.middleTransformId}}`);
  assert.throws(() => buildCrystalParts(cycle, fixture.sprites), /cyclic|cycle/i);
  assert.throws(() => buildCrystalParts(fixture.text + fixture.rootTransform, fixture.sprites), /duplicate.*fileID/i);
});

test('Crystal parsing rejects nonfinite, singular, non-2D and sliced/tiled transforms', () => {
  const { buildCrystalParts } = require('../tools/import-chests.cjs');
  const fixture = crystalFixture();
  assert.throws(() => buildCrystalParts(
    fixture.text.replace('m_LocalPosition: {x: 4, y: 2, z: 0}', 'm_LocalPosition: {x: NaN, y: 2, z: 0}'),
    fixture.sprites
  ), /number|finite/i);
  assert.throws(() => buildCrystalParts(
    fixture.text.replace('m_LocalScale: {x: 2, y: 3, z: 1}', 'm_LocalScale: {x: 0, y: 3, z: 1}'),
    fixture.sprites
  ), /singular|zero.*scale/i);
  assert.throws(() => buildCrystalParts(
    fixture.text.replace('m_LocalPosition: {x: 4, y: 2, z: 0}', 'm_LocalPosition: {x: 4, y: 2, z: 1}'),
    fixture.sprites
  ), /2D/i);
  assert.throws(() => buildCrystalParts(
    fixture.text.replace('m_LocalRotation: {x: 0, y: 0, z: 0, w: 1}', 'm_LocalRotation: {x: 0.5, y: 0, z: 0, w: 1}'),
    fixture.sprites
  ), /2D/i);
  assert.throws(() => buildCrystalParts(
    fixture.text.replace('m_LocalRotation: {x: 0, y: 0, z: 0, w: 1}', 'm_LocalRotation: {x: 0, y: 0, z: 0, w: 0}'),
    fixture.sprites
  ), /quaternion/i);
  assert.throws(() => buildCrystalParts(fixture.text.replace('m_DrawMode: 0', 'm_DrawMode: 1'), fixture.sprites), /draw.*mode|sliced|single.sprite/i);
  assert.throws(() => buildCrystalParts(fixture.text.replace('m_FlipX: 1', 'm_FlipX: 2'), fixture.sprites), /flip/i);
});

test('particle renderers and SpriteRenderers with unrelated GUIDs do not enter the Crystal composite', () => {
  const { buildCrystalParts } = require('../tools/import-chests.cjs');
  const fixture = crystalFixture();
  const unrelated = `--- !u!199 &999999999999999998
ParticleSystemRenderer:
  m_GameObject: {fileID: 123}
--- !u!212 &999999999999999999
SpriteRenderer:
  m_Sprite: {fileID: 21300000, guid: ffffffffffffffffffffffffffffffff, type: 3}
`;
  assert.deepEqual(buildCrystalParts(fixture.text + unrelated, fixture.sprites), buildCrystalParts(fixture.text, fixture.sprites));
});

test('differing existing destination bytes cause an explicit refusal without any overwrite', () => {
  const { writeImportFiles } = require('../tools/import-chests.cjs');
  const filename = expectedFiles[0].path;
  const before = readPng(filename).bytes;
  const modifiedTime = fs.statSync(absolute(filename), { bigint: true }).mtimeNs;
  assert.throws(() => writeImportFiles([{ path: filename, bytes: Buffer.from('different proposed content') }]), /refusing.*overwrite.*differ/i);
  assert.deepEqual(fs.readFileSync(absolute(filename)), before);
  assert.equal(fs.statSync(absolute(filename), { bigint: true }).mtimeNs, modifiedTime);
});

test('source checksums agree and a real importer rerun leaves every imported byte and timestamp unchanged', (context) => {
  const { DEFAULT_SOURCE, importChests } = require('../tools/import-chests.cjs');
  if (!fs.existsSync(DEFAULT_SOURCE)) {
    context.skip('The external source pack is unavailable; imported-file and parser tests remain standalone.');
    return;
  }
  const manifest = readManifest();
  const snapshotPaths = [...manifest.files.map((file) => file.path), 'assets/chests/manifest.json', 'assets/chests/SOURCE.txt'];
  const snapshot = new Map(snapshotPaths.map((filename) => [filename, {
    hash: sha256(fs.readFileSync(absolute(filename))),
    mtime: fs.statSync(absolute(filename), { bigint: true }).mtimeNs
  }]));
  for (const file of manifest.files) {
    assert.equal(sha256(fs.readFileSync(path.join(DEFAULT_SOURCE, ...file.source.split('/')))), file.sha256, file.source);
  }
  const result = importChests(DEFAULT_SOURCE);
  assert.deepEqual(result.manifest, manifest);
  assert.equal(result.written, 0);
  assert.equal(result.unchanged, 21);
  for (const [filename, before] of snapshot) {
    assert.equal(sha256(fs.readFileSync(absolute(filename))), before.hash, filename);
    assert.equal(fs.statSync(absolute(filename), { bigint: true }).mtimeNs, before.mtime, filename);
  }
});
