const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { readModelContainer, readFloatAccessor, imageDimensions } = require('./helpers/chest-model-assets.cjs');

const root = path.resolve(__dirname, '..');
const manifest = JSON.parse(fs.readFileSync(path.join(root, 'assets', 'jelly-boss', 'manifest.json'), 'utf8'));
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');

test('Bramble retains the real acquired source, source rights and private reusable input', () => {
  assert.equal(manifest.source.creator, 'Wabu');
  assert.match(manifest.source.url, /380750$/);
  assert.equal(manifest.source.license, 'Standard Unity Asset Store EULA');
  assert.equal(manifest.source.fbx_sha256, 'b716387a7be20268652e64b36aff88a8a46169ed8401051b422bebdacf00af76');
  assert.equal(manifest.source.title, 'Frog, 50+ Monsters Bundle');
  assert.equal(manifest.model.private_build_input, true);
  assert.match(fs.readFileSync(path.join(root, '.gitignore'), 'utf8'), /^assets\/jelly-boss\/private\/$/m);
  const bytes = fs.readFileSync(path.join(root, manifest.model.path));
  assert.equal(bytes.length, manifest.model.bytes);
  assert.equal(sha(bytes), manifest.model.sha256);
});

test('the acquired Boss uses skinned production meshes and eight actually moving skeletal clips', () => {
  const model = readModelContainer(path.join(root, manifest.model.path));
  const { gltf } = model;
  assert.ok(gltf.skins?.length, 'The Boss is not a rigid placeholder silhouette');
  assert.equal(gltf.meshes.length, 1, 'The newly acquired Frog body replaces the Bunny and its carrot');
  assert.deepEqual([...manifest.model.facial_shapes].sort(), ['Blink.L', 'Blink.R', 'WideEyes'].sort());
  for (const primitive of gltf.meshes[0].primitives)
    assert.equal(primitive.targets.length, 3, 'Expressions deform the original eye surfaces, not a painted-on placeholder face');
  for (const mesh of gltf.meshes) for (const primitive of mesh.primitives)
    assert.ok(primitive.attributes.JOINTS_0 !== undefined && primitive.attributes.WEIGHTS_0 !== undefined);
  assert.deepEqual(gltf.animations.map(animation => animation.name).sort(), [...manifest.model.animations].sort());
  const joints = new Set(gltf.skins.flatMap(skin => skin.joints));
  for (const animation of gltf.animations) {
    const moving = animation.channels.some(channel => {
      if (!joints.has(channel.target.node)) return false;
      const samples = readFloatAccessor(model, animation.samplers[channel.sampler].output);
      return samples.some(sample => sample.some((value, index) => Math.abs(value - samples[0][index]) > 0.0001));
    });
    assert.ok(moving, `${animation.name} deforms a real skinned joint, not only its scene root`);
  }
  assert.ok(model.bytes.length < 2_000_000, 'The complete Boss remains a bounded mobile build input');
  for (const name of ['Idle', 'Taunt', 'Hit']) {
    const animation = gltf.animations.find(item => item.name === name);
    const track = animation.channels.find(channel => channel.target.path === 'weights');
    assert.ok(track, `${name} actually exports its eye-expression track`);
    const samples = readFloatAccessor(model, animation.samplers[track.sampler].output);
    assert.ok(samples.some(sample => sample.some(value => value > 0.1)), `${name} contains a visible facial-expression change`);
  }
});

test('Boss taunts use the acquired CC0 human recording and exact original bytes', () => {
  const bytes = fs.readFileSync(path.join(root, manifest.vocal.path));
  assert.equal(manifest.vocal.creator, 'AntumDeluge');
  assert.equal(manifest.vocal.license, 'CC0-1.0');
  assert.equal(bytes.length, manifest.vocal.bytes);
  assert.equal(sha(bytes), manifest.vocal.sha256);
  assert.equal(bytes.toString('ascii', 0, 4), 'OggS');
  assert.ok(manifest.vocal.runtime_gain <= 0.3);
  assert.match(fs.readFileSync(path.join(root, 'tools', 'package-web.cjs'), 'utf8'),
    /assets\/audio\/jelly-boss\/bramble-laugh\.ogg/);
});

test('the story compass is an exact startup UI copy, independent of deferred age-twelve vocabulary', () => {
  const compass = fs.readFileSync(path.join(root, 'assets', 'jelly-boss', 'compass.webp'));
  assert.equal(sha(compass), '8223082a5d514861eebb194d815f634b821e0d6f64b19351e99467ec068762a8');
  assert.match(fs.readFileSync(path.join(root, 'scripts', 'word_jelly_boss_view.gd'), 'utf8'),
    /preload\("res:\/\/assets\/jelly-boss\/compass\.webp"\)/);
});

test('the map uses an actual transparent portrait rendered from the same acquired Boss', () => {
  const portrait = manifest.portrait;
  assert.ok(portrait, 'The map portrait has a source and acquisition record');
  assert.equal(portrait.creator, manifest.source.creator);
  assert.equal(portrait.license, manifest.source.license);
  assert.equal(portrait.source_model_sha256, manifest.model.sha256);
  assert.match(portrait.path, /^assets\/jelly-boss\/private\//);
  const bytes = fs.readFileSync(path.join(root, portrait.path));
  assert.equal(bytes.length, portrait.bytes);
  assert.equal(sha(bytes), portrait.sha256);
  assert.deepEqual(imageDimensions(bytes), { width: 256, height: 256 });
  assert.equal(bytes[25], 6, 'The rendered PNG retains transparency, not a flat-color badge background');
  const map = fs.readFileSync(path.join(root, 'scripts', 'word_jelly_map.gd'), 'utf8');
  assert.match(map, /BOSS_PORTRAIT = preload\("res:\/\/assets\/jelly-boss\/private\/bramble-portrait\.png"\)/);
  assert.doesNotMatch(map, /_label\(button, "BOSS"/);
});
