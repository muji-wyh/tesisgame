const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { readModelContainer, embeddedModelImages, imageDimensions } = require('./helpers/chest-model-assets.cjs');

const root = path.join(__dirname, '..');
const chestRoot = path.join(root, 'assets', 'chests');
const partNames = ['chest', ...Array.from({ length: 8 }, (_, index) => String(index + 1).padStart(2, '0'))];
const pngSignature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
const expectedParticles = {
  glow: 'assets/chests/shared/effects/portal_glow.png'
};
const sha256 = (bytes) => crypto.createHash('sha256').update(bytes).digest('hex');
const absolute = (relativePath) => path.join(root, ...relativePath.split('/'));

function soundEnergy(samples, rate) {
  const alpha = 1 - Math.exp(-2 * Math.PI * 400 / rate);
  const phoneLow = 1 - Math.exp(-2 * Math.PI * 180 / rate);
  const phoneHigh = 1 - Math.exp(-2 * Math.PI * 1200 / rate);
  let low = 0, body = 0, total = 0, low180 = 0, low1200 = 0, phone = 0;
  for (const sample of samples) {
    low += alpha * (sample - low);
    low180 += phoneLow * (sample - low180);
    low1200 += phoneHigh * (sample - low1200);
    body += low * low;
    phone += (low1200 - low180) ** 2;
    total += sample * sample;
  }
  return { rms: Math.sqrt(total / samples.length), bodyRatio: body / total, phoneRatio: phone / total };
}

test('all 48 retained original chest cues reproduce exactly without the replaced theme copies', () => {
  const audio = require('../tools/generate-chest-audio.cjs');
  const files = fs.readdirSync(absolute('assets/audio/chests')).filter(name => name.endsWith('.wav'));
  const expected = audio.THEMES.flatMap(theme => Object.keys(audio.CUES).map(cue => `${theme}-${cue}.wav`));
  assert.equal(expected.length, 48);
  assert.deepEqual(files.sort(), expected.sort());
  let bytes = 0;
  for (const theme of audio.THEMES) for (const cue of Object.keys(audio.CUES)) {
    const authored = fs.readFileSync(absolute(`assets/audio/chests/${theme}-${cue}.wav`));
    assert.deepEqual(authored, audio.wav(audio.render(theme, cue)), `${theme}/${cue} is reproducible`);
    bytes += authored.length;
  }
  assert.ok(bytes < 800000, 'The retained original bank stays below 0.8 MB');
});

test('the final chest breath brakes into a quiet hold before the shared recorded release', () => {
  const audio = require('../tools/generate-chest-audio.cjs');
  for (const theme of audio.THEMES) {
    const breath = audio.render(theme, 'opening');
    const window = (start, end) => soundEnergy(breath.slice(Math.round(start * audio.RATE), Math.round(end * audio.RATE)), audio.RATE).rms;
    const early = window(0.006, 0.035);
    const held = window(0.060, 0.210);
    assert.equal(breath.length, Math.round(0.24 * audio.RATE), `${theme} preserves the shared cue duration`);
    assert.ok(early > 0.08 && early < 0.25, `${theme} gathers a short audible breath during the brake`);
    assert.ok(held > 0.0002 && held < early * 0.12, `${theme} holds live tension at least 18 dB below the brake`);
    for (let step = 0; step < 8; step++) {
      assert.ok(window(0.060 + step * 0.020, 0.080 + step * 0.020) < early * 0.12,
        `${theme} cannot rise again or add a second attack during its held pose`);
    }
    assert.ok(breath[0] === 0 && breath.at(-1) === 0, `${theme} breath has clean sample boundaries`);
    assert.ok(breath.every(sample => Math.abs(sample) < 0.79), `${theme} breath retains mixing headroom`);
  }
});

test('retained chest settle cues preserve a compact material stop', () => {
  const audio = require('../tools/generate-chest-audio.cjs');
  const window = (samples, start, end) => samples.slice(Math.round(start * audio.RATE), Math.round(end * audio.RATE));
  for (const theme of audio.THEMES) {
    const settle = audio.render(theme, 'settle');
    const landing = soundEnergy(settle, audio.RATE);
    assert.ok(landing.rms > 0.07 && landing.rms < 0.10 && landing.bodyRatio > 0.65 && landing.phoneRatio > 0.20,
      `${theme} preserves its tangible material stop`);
    assert.ok(soundEnergy(window(settle, 0.18, 0.4), audio.RATE).rms <
      soundEnergy(window(settle, 0, 0.04), audio.RATE).rms * 0.02,
    `${theme} stops ringing after its compact rebound`);
    assert.ok(settle.every(sample => Math.abs(sample) < 0.79), `${theme} landing stays unclipped`);
  }
});

test('five shared chest reference excerpts have verified PCM, unique content and clean signal boundaries', t => {
  const manifest = require('../docs/assets/chest-reference-audio.json');
  const { SOURCE_SHA256, WINDOWS } = require('../tools/import-chest-reference.cjs');
  assert.equal(manifest.source.sha256, SOURCE_SHA256);
  assert.deepEqual(manifest.assets.map(asset => ({ id: asset.id, ...asset.window, ...asset.processing })), WINDOWS);
  assert.ok(WINDOWS.every(window => window.start >= 33 && window.start + window.seconds <= 47));
  if (!fs.existsSync(absolute('assets/imported-audio/chest-reference'))) {
    return t.skip('Import the private chest reference before building the game.');
  }
  const entries = require('../tools/chest-reference-audio.cjs').readChestReferenceAudio(root);
  assert.equal(new Set(entries.map(({ asset }) => asset.sha256)).size, 5);
  assert.equal(entries.reduce((total, { bytes }) => total + bytes.length, 0), 301864);
  for (const { asset, bytes } of entries) {
    const samples = Array.from({ length: (bytes.length - 44) / 2 }, (_, index) => bytes.readInt16LE(44 + index * 2) / 32767);
    const peak = samples.reduce((maximum, sample) => Math.max(maximum, Math.abs(sample)), 0);
    const rms = Math.sqrt(samples.reduce((total, sample) => total + sample * sample, 0) / samples.length);
    assert.ok(peak < 0.85 && rms > 0.005, `${asset.id} has unclipped, non-silent audio`);
    assert.ok(Math.abs(20 * Math.log10(peak) - asset.peakDbfs) < 0.01, `${asset.id} peak matches its provenance`);
    assert.ok(Math.abs(20 * Math.log10(rms) - asset.rmsDbfs) < 0.01, `${asset.id} energy matches its provenance`);
    assert.equal(samples[0], 0, `${asset.id} starts at zero`);
    assert.equal(samples.at(-1), 0, `${asset.id} ends at zero`);
  }
});

test('the chest reference importer preserves installed files when the supplied video hash does not match', t => {
  const temporary = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'chest-source-check-'));
  t.after(() => fs.rmSync(temporary, { recursive: true, force: true }));
  const fixture = require('./helpers/chest-reference-assets.cjs').chestReferenceFixture(temporary);
  const before = fixture.assets.map(asset => fs.readFileSync(path.join(temporary, asset.destination)));
  const manifest = fs.readFileSync(fixture.manifestPath);
  const source = path.join(temporary, 'unreviewed.mp4');
  fs.writeFileSync(source, 'Not the supplied recording');
  assert.throws(() => require('../tools/import-chest-reference.cjs').importChestReference({
    source, root: temporary, ffmpeg: 'must-not-run'
  }), /does not match the reviewed chest-opening reference/);
  assert.deepEqual(fs.readFileSync(fixture.manifestPath), manifest);
  fixture.assets.forEach((asset, index) => assert.deepEqual(fs.readFileSync(path.join(temporary, asset.destination)), before[index]));
});

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

function readGlb(relativePath) {
  const model = readModelContainer(absolute(relativePath));
  const { gltf } = model;
  assert.equal(gltf.asset.version, '2.0', relativePath);
  assert.ok(gltf.nodes?.length > 0 && gltf.meshes?.length > 0, `${relativePath} contains real geometry`);
  assert.ok(gltf.buffers?.every(buffer => !buffer.uri), `${relativePath} embeds its geometry`);
  assert.ok((gltf.images || []).every(image => Number.isInteger(image.bufferView)), `${relativePath} embeds its materials`);
  const primitives = gltf.meshes.flatMap(mesh => mesh.primitives);
  assert.ok(primitives.every(primitive => Number.isInteger(primitive.attributes.POSITION)), `${relativePath} has vertex positions`);
  assert.ok(primitives.some(primitive => gltf.accessors[primitive.attributes.POSITION].count >= 100),
    `${relativePath} contains modeled detail instead of a flat image plane`);
  return model;
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
      name, texture: `assets/chests/sprites/crystal/${name === 'chest' ? 'base' : `part_${name}`}.png`,
      guid, ppu: name === '01' ? 50 : 100, pivot: name === '01' ? [0.25, 0.75] : [0.5, 0.5]
    };
  });
  return { text: documents.join(''), sprites, rootTransform, middleTransform, middleTransformId, transforms, renderers };
}

test('the selected gameplay manifest shares sourced glow and magic sprites across all Atelier levels', () => {
  const manifest = JSON.parse(fs.readFileSync(absolute('assets/chests/catalog/gameplay-chests.json'), 'utf8'));
  const stateAssets = JSON.parse(fs.readFileSync(absolute('assets/chests/catalog/chest-state-assets.json'), 'utf8'));
  assert.deepEqual(manifest.particles, expectedParticles);
  assert.deepEqual(manifest.files.map(file => file.path).sort(), [
    expectedParticles.glow,
    'assets/chests/shared/effects/kenney-light-01.png',
    'assets/chests/shared/effects/kenney-light-02.png',
    'assets/chests/shared/effects/kenney-star-04.png'
  ].sort());
  for (const file of manifest.files) {
    const image = readPng(file.path);
    assert.ok(image.width <= 1024 && image.height <= 1024, file.path);
    const record = stateAssets.assets.find(asset => asset.path === file.path);
    if (record) assert.equal(sha256(image.bytes), record.sha256, file.path);
  }
  for (const style of Object.values(manifest.styles)) {
    assert.ok(style.model.startsWith('assets/chests/models/atelier/'));
    assert.ok(!Object.hasOwn(style, 'closed') && !Object.hasOwn(style, 'parts') && !Object.hasOwn(style, 'frames'));
    assert.deepEqual(Object.values(style.magic.textures).sort(), manifest.files.map(file => file.path)
      .filter(filename => filename !== expectedParticles.glow).sort());
  }
});

test('active Atelier and reward image imports reproduce their exact embedded production textures', () => {
  const atelier = JSON.parse(fs.readFileSync(absolute('assets/chests/catalog/atelier.json'), 'utf8'));
  const stateAssets = JSON.parse(fs.readFileSync(absolute('assets/chests/catalog/chest-state-assets.json'), 'utf8'));
  const modelPaths = [...atelier.models.map(model => model.model),
    ...stateAssets.assets.filter(asset => asset.kind === 'glb').map(asset => asset.path)];
  const embedded = [...new Set(modelPaths)].flatMap(filename => embeddedModelImages(filename, readGlb(filename)));
  assert.ok(embedded.length > 28, 'Source chests retain their differentiated baked maps and palette artwork');
  for (const image of embedded) {
    const actual = fs.readFileSync(absolute(image.path));
    assert.equal(sha256(actual), sha256(image.bytes), `${image.path} preserves the embedded source pixels`);
    assert.deepEqual(imageDimensions(actual), imageDimensions(image.bytes), image.path);
  }
  const expectedModelImages = embedded.map(image => image.path).sort();
  const activeModelImages = [listFiles(path.join(chestRoot, 'models', 'atelier')),
    listFiles(path.join(chestRoot, 'shared', 'rewards'))].flat()
    .filter(filename => /\.(?:png|jpe?g)$/i.test(filename)).sort();
  assert.deepEqual(activeModelImages, expectedModelImages);
  for (const asset of stateAssets.assets.filter(asset => asset.kind === 'png')) {
    const image = readPng(asset.path);
    assert.equal(sha256(image.bytes), asset.sha256, asset.path);
    assert.equal(image.bytes.length, asset.bytes, asset.path);
  }
  const milestoneTextures = require('../tools/prepare-chest-milestone-art.cjs').checkChestMilestoneArt(root);
  assert.deepEqual(milestoneTextures.map(texture => texture.path), [
    'assets/chests/shared/effects/rays.png', 'assets/chests/shared/effects/sparkle.png'
  ]);
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
