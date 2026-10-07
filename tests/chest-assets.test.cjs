const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { readModelContainer, embeddedModelImages, imageDimensions, readFloatAccessor } = require('./helpers/chest-model-assets.cjs');

const root = path.join(__dirname, '..');
const chestRoot = path.join(root, 'assets', 'chests');
const partNames = ['chest', ...Array.from({ length: 8 }, (_, index) => String(index + 1).padStart(2, '0'))];
const pngSignature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
const expectedParticles = {
  glow: 'assets/chests/particles/portal_glow.png'
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
      name, texture: `assets/chests/crystal/${name === 'chest' ? 'base' : `part_${name}`}.png`,
      guid, ppu: name === '01' ? 50 : 100, pivot: name === '01' ? [0.25, 0.75] : [0.5, 0.5]
    };
  });
  return { text: documents.join(''), sprites, rootTransform, middleTransform, middleTransformId, transforms, renderers };
}

test('all fourteen selected chest and glow PNGs exist with valid IHDR dimensions', () => {
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

test('the manifest records exactly fourteen original paths, hashes and image dimensions', () => {
  const files = readManifest().files;
  assert.equal(files.length, 14);
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

test('every chest image belongs to original art, derived rigs or an embedded model material', () => {
  const files = listFiles(chestRoot);
  const rigs = JSON.parse(fs.readFileSync(path.join(chestRoot, 'rigs.json'), 'utf8'));
  assert.equal(rigs.version, 1);
  assert.deepEqual(Object.keys(rigs.styles).sort(), ['energy', 'royal']);
  const parts = Object.values(rigs.styles).flatMap((style) => style.parts);
  assert.equal(parts.length, 10);
  assert.equal(new Set(parts.map((part) => part.texture)).size, 10);
  for (const part of parts) {
    assert.match(part.texture, /^assets\/chests\/rigs\/(?:royal|energy)\/[a-z_]+\.png$/);
    const image = readPng(part.texture);
    assert.equal(sha256(image.bytes), part.sha256, part.texture);
    assert.equal(image.bytes.length, part.bytes, part.texture);
    assert.equal(image.width, part.width, part.texture);
    assert.equal(image.height, part.height, part.texture);
  }
  const downloaded = JSON.parse(fs.readFileSync(path.join(chestRoot, 'downloaded', 'manifest.json'), 'utf8'));
  const modelImages = downloaded.assets.flatMap(asset => embeddedModelImages(asset.path, readGlb(asset.path)));
  for (const image of modelImages) {
    const actual = fs.readFileSync(absolute(image.path));
    assert.equal(sha256(actual), sha256(image.bytes), `${image.path} is the exact embedded source texture`);
    assert.deepEqual(imageDimensions(actual), imageDimensions(image.bytes), `${image.path} retains source dimensions`);
  }
  assert.deepEqual(files.filter((file) => /\.(?:png|jpe?g)$/i.test(file)).sort(), [
    ...expectedFiles.map(({ path: filename }) => filename), ...parts.map((part) => part.texture),
    ...modelImages.map(image => image.path)
  ].sort());
  assert.deepEqual(files.filter((file) => /\.(?:meta|prefab|anim|mat|cs)$/i.test(file)), []);
});

test('five detailed chest models have distinct geometry, continuous articulation and verified provenance', () => {
  const downloaded = JSON.parse(fs.readFileSync(path.join(chestRoot, 'downloaded', 'manifest.json'), 'utf8'));
  assert.equal(downloaded.version, 2);
  assert.deepEqual(Object.keys(downloaded.styles).sort(), ['bonbon', 'bramble', 'harvest', 'nebula', 'tide']);
  assert.equal(new Set(Object.values(downloaded.styles).map(style => style.source)).size, 5,
    'Each replacement comes from a different source design');
  const checksums = new Map(downloaded.assets.map((file) => [file.path, file]));
  assert.equal(checksums.size, 5, 'Every model has one checksum');
  assert.equal(downloaded.assets.length, 5);
  let totalBytes = 0;
  const modelHashes = new Set();
  const vec3 = (value, label) => {
    assert.equal(value?.length, 3, label);
    assert.ok(value.every(Number.isFinite), label);
  };
  for (const [style, catalog] of Object.entries(downloaded.styles)) {
    assert.ok(!Object.hasOwn(catalog, 'frames'), `${style} uses continuous geometry instead of sparse images`);
    assert.match(catalog.model, /^assets\/chests\/models\/[a-z-]+\.glb$/);
    const record = checksums.get(catalog.model);
    assert.ok(record, catalog.model);
    const model = readGlb(catalog.model);
    const { bytes, gltf } = model;
    assert.equal(record.sha256, sha256(bytes), catalog.model);
    assert.equal(record.bytes, bytes.length, catalog.model);
    totalBytes += record.bytes;
    modelHashes.add(record.sha256);
    const parts = catalog.model_parts;
    assert.ok(Array.isArray(parts) && parts.some(part => part.role === 'lid'), `${style} articulates its lid during pressure`);
    const nodeNames = new Set(gltf.nodes.map(node => node.name));
    for (const part of parts) {
      assert.ok(['lid', 'lock', 'handle'].includes(part.role), `${style}/${part.node} has a known mechanism role`);
      assert.ok(part.node && (nodeNames.has(part.node) || nodeNames.has(part.node.split('/').at(-1)) || part.bone),
        `${style}/${part.node} resolves to a source node or explicit bone`);
      if (part.bone) assert.ok(nodeNames.has(part.bone), `${style}/${part.bone} exists in the source skeleton`);
      vec3(part.axis, `${style}/${part.node} hinge axis`);
      assert.ok(Math.hypot(...part.axis) > 0.99, `${style}/${part.node} has a usable hinge axis`);
      assert.ok(Number.isFinite(part.angle), `${style}/${part.node} has a finite pressure rotation`);
      if (part.lift) vec3(part.lift, `${style}/${part.node} pressure lift`);
    }
    if (catalog.open_animation) {
      const animation = (gltf.animations || []).find(animation => animation.name === catalog.open_animation);
      assert.ok(animation, `${style} retains its named opening clip`);
      const times = animation.samplers.flatMap(sampler => readFloatAccessor(model, sampler.input).map(sample => sample[0]));
      const start = catalog.open_start ?? Math.min(...times);
      const end = catalog.open_end ?? Math.max(...times);
      assert.ok(start >= Math.min(...times) - 1e-5 && end <= Math.max(...times) + 1e-5 && end > start,
        `${style} selects a valid opening interval from the source clip`);
      const varyingChannels = animation.channels.filter(channel => {
        if (!['rotation', 'translation'].includes(channel.target.path)) return false;
        const sampler = animation.samplers[channel.sampler];
        let values = readFloatAccessor(model, sampler.output);
        if (sampler.interpolation === 'CUBICSPLINE') values = values.filter((_, index) => index % 3 === 1);
        const first = values[0];
        return values.some(value => {
          const distance = Math.hypot(...value.map((component, index) => component - first[index]));
          const equivalentRotation = channel.target.path === 'rotation'
            && Math.hypot(...value.map((component, index) => component + first[index])) <= 1e-6;
          return distance > 1e-6 && !equivalentRotation;
        });
      });
      assert.ok(varyingChannels.length > 0, `${style} opens by moving geometry`);
      for (const channel of varyingChannels) {
        assert.notEqual(animation.samplers[channel.sampler].interpolation, 'STEP',
          `${style}/${gltf.nodes[channel.target.node].name} interpolates genuinely moving geometry`);
      }
    } else {
      assert.ok(parts.some(part => Math.abs(part.angle) > 0.5), `${style} supplies a full authored lid hinge`);
    }
    for (const property of ['closed_bounds_3d', 'motion_bounds_3d']) {
      vec3(catalog[property]?.min, `${style}/${property} minimum`);
      vec3(catalog[property]?.max, `${style}/${property} maximum`);
      assert.ok(catalog[property].max.every((value, index) => value > catalog[property].min[index]),
        `${style}/${property} has positive volume`);
    }
    vec3(catalog.camera_direction, `${style} camera direction`);
    assert.ok(Math.hypot(...catalog.camera_direction) > 0.5, `${style} has a nonzero camera direction`);
    vec3(catalog.cavity_3d, `${style} cavity anchor`);
    assert.ok(catalog.seam_3d.length >= 2, `${style} has a lit lid seam`);
    for (const point of catalog.seam_3d) vec3(point, `${style} seam point`);
    const source = downloaded.sources[catalog.source];
    assert.ok(source.title && source.publisher && source.version);
    assert.match(source.package_sha256, /^[a-f0-9]{64}$/);
    assert.match(source.url, /^https:\/\/(?:assetstore\.unity\.com|sketchfab\.com)\//);
    assert.match(source.license, /embedded game artwork/);
  }
  assert.equal(modelHashes.size, 5, 'Each theme owns a different model');
  assert.deepEqual(listFiles(path.join(chestRoot, 'models')).filter(file => file.endsWith('.glb')).sort(), [...checksums.keys()].sort());
  assert.ok(totalBytes < 20000000, 'The five embedded models stay below the 20 MB download budget');
  const data = fs.readFileSync(absolute('scripts/game_data.gd'), 'utf8');
  const themeSection = data.slice(data.indexOf('const THEMES:'), data.indexOf('const REWARD_NAMES:'));
  const styles = [...themeSection.matchAll(/"chest": "([a-z]+)"/g)].map((match) => match[1]);
  assert.equal(styles.length, 8);
  assert.equal(new Set(styles).size, 8, 'All eight themes own a different chest type');
  assert.ok(styles.every((style) => readManifest().styles[style] || downloaded.styles[style]));
});

test('derived rigs preserve original source hashes and share exact lid hinges', () => {
  const rigs = JSON.parse(fs.readFileSync(path.join(chestRoot, 'rigs.json'), 'utf8'));
  const originals = readManifest().files;
  assert.equal(rigs.sources.length, 4);
  for (const source of rigs.sources) {
    const original = originals.find((file) => file.path === source.path);
    assert.ok(original, source.path);
    assert.equal(source.sha256, original.sha256, source.path);
    assert.equal(sha256(fs.readFileSync(absolute(source.path))), source.sha256, source.path);
  }
  for (const [name, style] of Object.entries(rigs.styles)) {
    assert.deepEqual(style.canvas, [1024, 1024]);
    assert.deepEqual(style.parts.map((part) => part.role).sort(),
      ['body', 'interior', 'lid_inner', 'lid_outer', name === 'royal' ? 'latch' : 'core'].sort());
    for (const part of style.parts) {
      assert.equal(part.name, part.role);
      assert.equal(part.pivot.length, 2);
      assert.equal(part.position.length, 2);
      assert.ok([...part.pivot, ...part.position].every(Number.isFinite), part.role);
      assert.equal(part.crop.length, 4);
      assert.ok(part.crop.every(Number.isSafeInteger), part.role);
      assert.ok(part.crop.every((value) => value >= 0 && value <= 1024), part.role);
      assert.equal(part.crop[2] - part.crop[0], part.width, part.role);
      assert.equal(part.crop[3] - part.crop[1], part.height, part.role);
      assert.ok(Math.abs(part.position[0] - part.pivot[0] * part.width - part.crop[0]) < 1e-8, part.role);
      assert.ok(Math.abs(part.position[1] - part.pivot[1] * part.height - part.crop[1]) < 1e-8, part.role);
      if (part.role.startsWith('lid_')) assert.deepEqual(part.position, style.hinge);
    }
  }
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
  assert.equal(result.unchanged, 16);
  for (const [filename, before] of snapshot) {
    assert.equal(sha256(fs.readFileSync(absolute(filename))), before.hash, filename);
    assert.equal(fs.statSync(absolute(filename), { bigint: true }).mtimeNs, before.mtime, filename);
  }
});
