const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { readModelContainer, readFloatAccessor } = require('./helpers/chest-model-assets.cjs');

const root = path.resolve(__dirname, '..');
const model = readModelContainer(path.join(root, 'assets/pirate/pirate-game.glb'));
const { gltf } = model;
const report = JSON.parse(fs.readFileSync(path.join(root, 'assets/pirate/optimization-report.json'), 'utf8'));
const durations = {
  Idle: 3, Attack_L: .65, Attack_M: 1.05, Attack_P: 1.55,
  Hit_L: .5, Hit_M: .9, Hit_P: 1.45,
  Ultimate_TidalRush: 2.25, Ultimate_CrescentSpin: 2.25,
  Ultimate_CaptainsDrop: 2.5, Special_GiantRam: 2.3, Special_BigBite: 1.6,
  Taunt_HatTip: 1.5, Taunt_BellyLaugh: 2.1, Taunt_SideEye: 1.7,
  Taunt_NopeWag: 1.5, Taunt_Peekaboo: 2, Taunt_MockBow: 2,
  Taunt_Swagger: 2.1, Taunt_TongueTease: 1.8,
  Taunt_VictoryLap: 2.5, Taunt_FakeSleep: 2.6
};
const morphs = ['Bite_Open', 'Eye_Squint', 'Smile_Smirk', 'Tongue_Out'];
const taunts = Object.keys(durations).filter(name => name.startsWith('Taunt_'));

function channelFrames(animation, channel) {
  const sampler = animation.samplers[channel.sampler];
  const times = readFloatAccessor(model, sampler.input).map(row => row[0]);
  const rows = readFloatAccessor(model, sampler.output);
  assert.ok(['LINEAR', 'STEP'].includes(sampler.interpolation || 'LINEAR'));
  assert.equal(rows.length % times.length, 0);
  const width = rows.length / times.length;
  const values = times.map((_, index) => rows.slice(index * width, (index + 1) * width).flat());
  return { times, values };
}

function weightValues(animation) {
  const channel = animation.channels.find(item => item.target.path === 'weights');
  assert.ok(channel, `${animation.name} keeps every facial reset track`);
  const { times, values } = channelFrames(animation, channel);
  const names = gltf.meshes[gltf.nodes[channel.target.node].mesh].extras.targetNames;
  assert.deepEqual([...names].sort(), [...morphs].sort());
  assert.ok(values.every(sample => sample.length === names.length));
  return Object.fromEntries(names.map((name, index) => [name, { times, values: values.map(sample => sample[index]) }]));
}

function readMorph(index) {
  const accessor = gltf.accessors[index];
  const width = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4 }[accessor.type];
  assert.equal(accessor.componentType, 5126);
  const result = accessor.bufferView === undefined
    ? Array.from({ length: accessor.count }, () => Array(width).fill(0))
    : readFloatAccessor({ ...model, gltf: { ...gltf, accessors: gltf.accessors.map((item, at) =>
      at === index ? { ...item, sparse: undefined } : item) } }, index);
  if (accessor.sparse) {
    const sparse = accessor.sparse;
    const indicesView = gltf.bufferViews[sparse.indices.bufferView];
    const valuesView = gltf.bufferViews[sparse.values.bufferView];
    const indicesAt = (indicesView.byteOffset || 0) + (sparse.indices.byteOffset || 0);
    const valuesAt = (valuesView.byteOffset || 0) + (sparse.values.byteOffset || 0);
    const indexWidth = { 5121: 1, 5123: 2, 5125: 4 }[sparse.indices.componentType];
    const readIndex = { 1: 'readUInt8', 2: 'readUInt16LE', 4: 'readUInt32LE' }[indexWidth];
    for (let row = 0; row < sparse.count; row++) {
      const at = model.binary[readIndex](indicesAt + row * indexWidth);
      result[at] = Array.from({ length: width }, (_, component) =>
        model.binary.readFloatLE(valuesAt + (row * width + component) * 4));
    }
  }
  return result;
}

function closePose(first, second, property) {
  const near = (sign) => first.length === second.length &&
    first.every((value, index) => Math.abs(value - sign * second[index]) < 2e-5);
  return near(1) || (property === 'rotation' && near(-1));
}

test('Pirate is a bounded two-mesh game asset with a matching audit', () => {
  assert.equal(gltf.meshes.length, 2);
  const surfaces = gltf.meshes.flatMap(mesh => mesh.primitives);
  const triangles = surfaces.reduce((total, primitive) =>
    total + gltf.accessors[primitive.indices].count / 3, 0);
  assert.ok(triangles <= 12000);
  assert.ok(surfaces.length <= 6);
  assert.ok(gltf.materials.length <= 6);
  assert.ok(model.bytes.length < 2000000);
  assert.equal(report.status, 'passed');
  assert.equal(report.triangles, triangles);
  assert.equal(report.bytes, model.bytes.length);
  assert.equal(report.sha256, crypto.createHash('sha256').update(model.bytes).digest('hex'));
});

test('authored colors, smooth normals and the recessed biting mouth survive packing', () => {
  let movingMouthVertices = 0;
  for (const mesh of gltf.meshes) for (const primitive of mesh.primitives) {
    assert.notEqual(primitive.attributes.COLOR_0, undefined, 'The authored finish uses retained vertex colors');
    const normals = readFloatAccessor(model, primitive.attributes.NORMAL);
    assert.equal(normals.length, gltf.accessors[primitive.attributes.POSITION].count);
    assert.ok(normals.every(normal => Math.abs(Math.hypot(...normal) - 1) < .01));
    for (const [index, target] of (primitive.targets || []).entries()) {
      const deltas = readMorph(target.POSITION);
      assert.equal(deltas.length, normals.length);
      assert.ok(deltas.every(delta => delta.every(Number.isFinite)));
      if (mesh.extras.targetNames[index] === 'Bite_Open')
        movingMouthVertices += deltas.filter(delta => Math.hypot(...delta) > .1).length;
    }
  }
  const body = gltf.meshes.find(mesh => mesh.extras?.targetNames?.includes('Bite_Open'));
  assert.ok(body, 'The elastic body retains the actual mouth shape key');
  assert.deepEqual([...body.extras.targetNames].sort(), [...morphs].sort());
  assert.deepEqual(body.weights, [0, 0, 0, 0]);
  assert.ok(movingMouthVertices > 0, 'The opening changes actual three-dimensional vertices');
});

test('all twenty-two clips retain duration, zero time origin and neutral reset channels', () => {
  assert.deepEqual(gltf.animations.map(animation => animation.name).sort(), Object.keys(durations).sort());
  const idle = gltf.animations.find(animation => animation.name === 'Idle');
  const rest = new Map(idle.channels.map(channel => {
    const { values } = channelFrames(idle, channel);
    return [`${channel.target.node}:${channel.target.path}`, values[0]];
  }));
  for (const animation of gltf.animations) {
    const channels = new Set(animation.channels.map(channel => `${channel.target.node}:${channel.target.path}`));
    assert.ok([...rest.keys()].every(key => channels.has(key)), `${animation.name} retains its reset channels`);
    let end = 0;
    for (const channel of animation.channels) {
      const { times, values } = channelFrames(animation, channel);
      assert.equal(times[0], 0, animation.name);
      assert.ok(times.slice(1).every((time, index) => time > times[index]));
      end = Math.max(end, times.at(-1));
      const pose = rest.get(`${channel.target.node}:${channel.target.path}`);
      assert.ok(closePose(values[0], pose, channel.target.path), `${animation.name} begins at rest`);
      assert.ok(closePose(values.at(-1), pose, channel.target.path), `${animation.name} ends at rest`);
    }
    assert.ok(Math.abs(end - durations[animation.name]) < 1e-5, animation.name);
  }
});

test('the spin keeps both revolutions and the bite fully opens then closes', () => {
  const spin = gltf.animations.find(animation => animation.name === 'Ultimate_CrescentSpin');
  const travel = spin.channels.filter(channel => channel.target.path === 'rotation').map(channel => {
    const { values } = channelFrames(spin, channel);
    return values.slice(1).reduce((angle, second, index) => {
      const first = values[index];
      const dot = Math.abs(first.reduce((total, value, axis) => total + value * second[axis], 0)) /
        (Math.hypot(...first) * Math.hypot(...second));
      return angle + 2 * Math.acos(Math.min(1, dot));
    }, 0);
  });
  assert.ok(Math.max(...travel) > 700 * Math.PI / 180);
  for (const animation of gltf.animations) {
    const weights = weightValues(animation);
    for (const { values } of Object.values(weights)) {
      assert.equal(values[0], 0);
      assert.equal(values.at(-1), 0);
      assert.ok(values.every(value => value >= -1e-6 && value <= 1.00001));
    }
    if (animation.name === 'Special_BigBite') assert.ok(Math.max(...weights.Bite_Open.values) >= .99);
    else assert.ok(Math.max(...weights.Bite_Open.values) < .99, `${animation.name} keeps the full bite exclusive`);
  }
});

test('ten taunts have distinct gesture trajectories and active authored facial expressions', () => {
  const signatures = [];
  for (const name of taunts) {
    const animation = gltf.animations.find(item => item.name === name);
    const features = animation.channels.map(channel => {
      const { times, values } = channelFrames(animation, channel);
      const duration = Math.max(...animation.samplers.map(sampler =>
        readFloatAccessor(model, sampler.input).at(-1)[0]));
      // Ranges and peak phases provide a second check independent of the
      // packer's resampled full trajectories and their saved hashes.
      const coordinates = values[0].map((_, coordinate) => {
        const samples = values.map(value => value[coordinate]);
        const minimum = Math.min(...samples), maximum = Math.max(...samples);
        const peak = samples.findIndex(value => value === maximum);
        return [minimum, maximum, times[peak] / duration].map(value =>
          Math.abs(value) < .00005 ? 0 : Math.round(value * 10000) / 10000);
      });
      return [channel.target.node, channel.target.path, coordinates];
    });
    features.sort((first, second) => first[0] - second[0] || first[1].localeCompare(second[1]));
    signatures.push(JSON.stringify(features));
    const audit = report.clips.find(clip => clip.name === name);
    assert.ok(audit.has_motion && audit.starts_at_rest && audit.ends_at_rest, name);
  }
  assert.equal(new Set(signatures).size, 10, 'Ranges and peak timing distinguish the gestures');
  assert.equal(new Set(report.clips.filter(clip => taunts.includes(clip.name))
    .map(clip => clip.taunt_trajectory_sha256)).size, 10);
  assert.equal(report.taunt_count, 10);
  assert.equal(report.taunts_distinct, true);
  for (const morph of ['Eye_Squint', 'Smile_Smirk', 'Tongue_Out'])
    assert.ok(taunts.some(name => Math.max(...weightValues(gltf.animations.find(item => item.name === name))[morph].values) >= .5),
      `${morph} has a visible taunt rather than an unused target`);
  assert.ok(Math.max(...weightValues(gltf.animations.find(item => item.name === 'Taunt_FakeSleep')).Eye_Squint.values) >= .9);
  assert.ok(Math.max(...weightValues(gltf.animations.find(item => item.name === 'Taunt_TongueTease')).Tongue_Out.values) >= .9);
});
