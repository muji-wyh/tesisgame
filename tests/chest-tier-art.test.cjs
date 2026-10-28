const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { readModelContainer, imageDimensions, readFloatAccessor } = require('./helpers/chest-model-assets.cjs');

const root = path.resolve(__dirname, '..');
const catalogPath = 'assets/chests/catalog-cc0/sources.json';
const presetsPath = 'assets/chests/tier-presets.json';
const catalogPrefix = 'assets/chests/catalog-cc0/';
const slots = ['front', 'left', 'right', 'front-left', 'front-right'];
const sha256 = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const absolute = relative => path.join(root, ...relative.split('/'));

function readJson(relative) {
  assert.ok(fs.existsSync(absolute(relative)), `Missing chest-tier metadata: ${relative}`);
  return JSON.parse(fs.readFileSync(absolute(relative), 'utf8'));
}

function safePath(relative) {
  assert.equal(typeof relative, 'string');
  assert.ok(relative.startsWith('assets/chests/'), relative);
  assert.ok(!relative.includes('\\') && !relative.split('/').includes('..'), relative);
  assert.ok(!path.isAbsolute(relative) && !relative.includes(':'), relative);
  return relative;
}

function spatialRank(points) {
  const origin = points[0];
  const basis = [];
  for (const point of points) {
    let residual = point.map((value, axis) => value - origin[axis]);
    for (const unit of basis) {
      const projection = residual.reduce((sum, value, axis) => sum + value * unit[axis], 0);
      residual = residual.map((value, axis) => value - projection * unit[axis]);
    }
    const length = Math.hypot(...residual);
    if (length > 1e-6) basis.push(residual.map(value => value / length));
    if (basis.length === 3) break;
  }
  return basis.length;
}

function indexValues(model, accessorIndex) {
  const accessor = model.gltf.accessors[accessorIndex];
  assert.equal(accessor.type, 'SCALAR');
  assert.ok(!accessor.sparse);
  const readers = { 5121: ['readUInt8', 1], 5123: ['readUInt16LE', 2], 5125: ['readUInt32LE', 4] };
  const [reader, size] = readers[accessor.componentType] || [];
  assert.ok(reader, 'Triangle indices use unsigned integer components');
  const view = model.gltf.bufferViews[accessor.bufferView];
  const offset = (view.byteOffset || 0) + (accessor.byteOffset || 0);
  const stride = view.byteStride || size;
  return Array.from({ length: accessor.count }, (_, index) => model.binary[reader](offset + index * stride));
}

function animationFacts(model) {
  return (model.gltf.animations || []).map(animation => {
    const times = animation.samplers.flatMap(sampler => readFloatAccessor(model, sampler.input).flat());
    const timeMin = Math.min(...times);
    const timeMax = Math.max(...times);
    return {
      name: animation.name,
      time_min: timeMin,
      time_max: timeMax,
      duration_seconds: timeMax - timeMin,
      channel_count: animation.channels.length,
      target_nodes: [...new Set(animation.channels.map(channel =>
        model.gltf.nodes[channel.target.node].name))].sort(),
      properties: [...new Set(animation.channels.map(channel => channel.target.path))].sort()
    };
  });
}

function registry(catalog) {
  return new Map([...catalog.files.filter(file => file.kind === 'model'), ...catalog.referenced_private_models]
    .map(file => [file.path, file]));
}

test('refined CC0 chests retain source identities, separate real lids, original clips and bounded geometry', () => {
  const refinement = readJson('assets/chests/polished-cc0/manifest.json');
  const catalog = readJson(catalogPath);
  assert.equal(refinement.models.length, 4);
  for (const entry of refinement.models) {
    const source = catalog.files.find(file => file.path === entry.original);
    assert.ok(source && source.role === 'chest-base');
    assert.equal(entry.source_sha256, source.output_sha256);
    assert.equal(entry.license, 'CC0-1.0');
    assert.ok(entry.creator && entry.source && entry.license_file);
    const bytes = fs.readFileSync(absolute(safePath(entry.file)));
    assert.equal(bytes.length, entry.bytes);
    assert.equal(sha256(bytes), entry.sha256);
    const before = readModelContainer(absolute(entry.original));
    const after = readModelContainer(absolute(entry.file));
    assert.deepEqual((after.gltf.animations || []).map(animation => animation.name).sort(),
      (before.gltf.animations || []).map(animation => animation.name).sort());
    assert.ok(after.gltf.nodes.some(node => /lid/i.test(node.name)), 'The sourced lid is still separately articulated');
    for (const mesh of after.gltf.meshes) for (const primitive of mesh.primitives) {
      assert.equal(spatialRank(readFloatAccessor(after, primitive.attributes.POSITION)), 3);
      assert.ok(primitive.attributes.NORMAL !== undefined && primitive.attributes.TEXCOORD_0 !== undefined);
    }
    assert.ok(entry.refined_vertices > 0 && entry.refined_vertices < 5000 && entry.bytes < 250000);
    assert.match(entry.processing, /bevel/);
  }
});

test('the source catalog distinguishes original CC0 bytes, nine bases and reviewed modular runtime tiers', () => {
  const catalog = readJson(catalogPath);
  assert.equal(catalog.version, 1);
  assert.equal(catalog.status.raw_assets, 'original-cc0-byte-copies');
  assert.equal(catalog.status.tier_presets, 'integrated-native-four-view-reviewed');
  assert.equal(catalog.status.material_adaptations, 'per-instance-source-atlas-role-styling');
  assert.equal(catalog.counts.native_chest_base_families, 9);
  assert.equal(catalog.counts.modular_tier_recipes, 30);
  assert.equal(catalog.counts.cc0_chest_bases, 4);
  assert.equal(catalog.counts.private_chest_base_references, 5);
  assert.equal(catalog.counts.ornament_geometry_types, 6);
  assert.equal(catalog.sources.length, 5);
  assert.equal(new Set(catalog.sources.map(source => source.id)).size, 5);
  for (const source of catalog.sources) {
    assert.equal(source.license_id, 'CC0-1.0');
    assert.ok(source.creator && source.title && source.version);
    assert.match(source.url, /^https:\/\//);
    assert.match(source.license_url, /^https:\/\/creativecommons\.org\/publicdomain\/zero\/1\.0\/$/);
    assert.ok(catalog.files.some(file => file.path === source.license_file && file.kind === 'license'));
  }
  assert.equal(catalog.files.filter(file => file.role === 'chest-base').length, 4);
  assert.equal(catalog.files.filter(file => file.role === 'ornament').length, 6);
  assert.equal(catalog.referenced_private_models.length, 5);
  const models = [...registry(catalog).values()];
  assert.equal(new Set(models.filter(file => file.role === 'chest-base')
    .map(file => file.geometry_family_id)).size, 9);
  assert.ok(catalog.source_notes.excluded_duplicates.some(note => /Pirate/.test(note)));
  assert.ok(catalog.source_notes.excluded_duplicates.some(note => /chest_gold/.test(note)));
});

test('all committed CC0 models, dependencies and original licenses match their source/output hashes', () => {
  const catalog = readJson(catalogPath);
  const declared = new Map(catalog.files.map(file => [file.path, file]));
  assert.equal(declared.size, catalog.files.length);
  assert.equal(catalog.files.filter(file => file.kind === 'model').length, 10);
  assert.equal(catalog.files.filter(file => file.kind === 'texture').length, 4);
  assert.equal(catalog.files.filter(file => file.kind === 'license').length, 5);
  let total = 0;
  for (const file of catalog.files) {
    safePath(file.path);
    assert.ok(file.path.startsWith(catalogPrefix), file.path);
    assert.equal(file.status, 'raw-original-not-integrated');
    assert.ok(catalog.sources.some(source => source.id === file.source_id), file.path);
    assert.ok(file.original_relative_path && !file.original_relative_path.includes(':'));
    assert.ok(!path.posix.isAbsolute(file.original_relative_path) && !path.win32.isAbsolute(file.original_relative_path));
    assert.match(file.source_sha256, /^[a-f0-9]{64}$/);
    assert.equal(file.source_sha256, file.output_sha256, `${file.path} is a byte copy, not a conversion`);
    const bytes = fs.readFileSync(absolute(file.path));
    assert.equal(bytes.length, file.output_bytes, file.path);
    assert.equal(sha256(bytes), file.output_sha256, file.path);
    total += bytes.length;
    if (file.kind === 'texture') assert.deepEqual(imageDimensions(bytes), { width: 512, height: 512 });
    if (file.kind === 'license') {
      const source = catalog.sources.find(source => source.id === file.source_id);
      assert.match(bytes.toString('utf8'), /CC0/);
      assert.ok(bytes.toString('utf8').includes(source.creator), file.path);
    }
    for (const dependency of file.dependencies || []) {
      assert.ok(declared.has(safePath(dependency)), `${file.path} declares ${dependency}`);
    }
  }
  assert.ok(total < 400000, `The isolated raw CC0 input set remains small (${total} bytes)`);
  assert.ok(!catalog.files.some(file => /pirate|chest_gold|\.fbx$|\.unitypackage$/i.test(file.path)));
});

test('raw hashed inputs retain identical bytes across checkout line-ending settings', () => {
  const filename = absolute(`${catalogPrefix}.gitattributes`);
  assert.ok(fs.existsSync(filename), 'Raw original license/model/texture bytes need local checkout protection');
  const patterns = fs.readFileSync(filename, 'utf8').split(/\r?\n/)
    .map(line => line.trim()).filter(line => line && !line.startsWith('#'));
  assert.deepEqual(patterns, ['**/*.glb -text', '**/*.png -text', '**/LICENSE.txt -text']);
});

test('every copied GLB contains real nonplanar geometry with exact metadata and valid atlas dependencies', () => {
  const catalog = readJson(catalogPath);
  const files = new Map(catalog.files.map(file => [file.path, file]));
  for (const file of catalog.files.filter(file => file.kind === 'model')) {
    const model = readModelContainer(absolute(file.path));
    assert.ok(model.gltf.buffers.every(buffer => !buffer.uri), file.path);
    const primitives = model.gltf.meshes.flatMap(mesh => mesh.primitives);
    let vertices = 0;
    let triangles = 0;
    const ranks = [];
    for (const primitive of primitives) {
      assert.equal(primitive.mode ?? 4, 4, file.path);
      const points = readFloatAccessor(model, primitive.attributes.POSITION);
      const indices = indexValues(model, primitive.indices);
      assert.equal(indices.length % 3, 0, file.path);
      assert.ok(indices.every(index => index < points.length), file.path);
      vertices += points.length;
      triangles += indices.length / 3;
      ranks.push(spatialRank(points));
    }
    assert.ok(ranks.every(rank => rank === 3), `${file.path} is not a flat image plane`);
    assert.deepEqual(file.geometry, {
      mesh_count: model.gltf.meshes.length,
      primitive_count: primitives.length,
      vertex_count: vertices,
      triangle_count: triangles,
      primitive_spatial_ranks: ranks
    });
    assert.deepEqual(file.materials, model.gltf.materials || []);
    assert.deepEqual(file.nodes, model.gltf.nodes);
    assert.deepEqual(file.animation.clips, animationFacts(model));
    assert.equal(file.images.length, (model.gltf.images || []).length, file.path);
    for (const [index, image] of (model.gltf.images || []).entries()) {
      const recorded = file.images[index];
      if (image.uri) {
        assert.ok(!image.uri.includes('\\') && !image.uri.includes('..') && !image.uri.includes(':'));
        const resolved = path.posix.join(path.posix.dirname(file.path), image.uri);
        assert.equal(recorded.path, resolved);
        assert.ok(file.dependencies.includes(resolved), file.path);
        assert.ok(files.has(resolved), file.path);
        assert.equal(recorded.sha256, files.get(resolved).output_sha256);
      } else {
        const view = model.gltf.bufferViews[image.bufferView];
        const bytes = model.binary.subarray(view.byteOffset || 0, (view.byteOffset || 0) + view.byteLength);
        assert.equal(recorded.location, 'embedded');
        assert.equal(recorded.sha256, sha256(bytes));
        assert.deepEqual(recorded.dimensions, imageDimensions(bytes));
      }
    }
  }
});

test('source opening clips and static lids are not confused with newly authored animation', () => {
  const catalog = readJson(catalogPath);
  const bases = catalog.files.filter(file => file.role === 'chest-base');
  for (const base of bases) {
    assert.equal(base.animation.authorship, 'source-original');
    assert.ok(base.nodes.some(node => node.name === base.animation.lid_node && Number.isInteger(node.mesh)));
    if (base.source_id === 'kaykit-dungeon-1.0') {
      assert.deepEqual(base.animation.clips, []);
      assert.equal(base.animation.opening_support, 'separate-static-lid-no-clip');
    } else {
      assert.deepEqual(base.animation.clips.map(clip => clip.name), ['open', 'close', 'open-close']);
      assert.ok(Math.abs(base.animation.clips[0].duration_seconds - 0.3) < 1e-6);
      assert.equal(base.animation.opening_support, 'separate-lid-with-source-clips');
    }
  }
  for (const file of catalog.files.filter(file => file.role === 'ornament')) {
    assert.deepEqual(file.animation.clips, [], file.path);
    assert.equal(file.animation.opening_support, 'static-attachment');
    assert.ok(file.materials.every(material => material.pbrMetallicRoughness.metallicFactor === 0));
  }
});

test('thirty contiguous recipes use nine registered bases and thirty different geometry/slot assemblies', () => {
  const catalog = readJson(catalogPath);
  const presets = readJson(presetsPath);
  const models = registry(catalog);
  assert.equal(presets.version, 1);
  assert.equal(presets.source_notes.status, 'integrated-native-four-view-reviewed');
  assert.equal(presets.source_notes.native_base_mesh_families, 9);
  assert.equal(presets.source_notes.material_styling, 'declared-in-game-adaptation-not-source-authored');
  assert.equal(presets.tiers.length, 30);
  assert.deepEqual(presets.tiers.map(tier => tier.level), Array.from({ length: 30 }, (_, index) => index + 1));
  assert.equal(new Set(presets.tiers.map(tier => tier.id)).size, 30);
  assert.equal(new Set(presets.tiers.map(tier => tier.name)).size, 30);
  assert.equal(new Set(presets.tiers.map(tier => tier.base_model)).size, 9);
  const structures = new Set();
  for (const tier of presets.tiers) {
    assert.match(tier.id, /^tier-\d{2}-[a-z0-9-]+$/);
    assert.ok(tier.name.length > 0 && !/skull|horror|mimic|fang|demon/i.test(tier.name));
    const base = models.get(safePath(tier.base_model));
    assert.ok(base && base.role === 'chest-base', tier.id);
    assert.equal(tier.base_source_id, base.source_id, tier.id);
    assert.ok(presets.source_notes.material_styles[tier.material_style], tier.id);
    assert.ok(Array.isArray(tier.decorations));
    assert.equal(new Set(tier.decorations.map(decoration => decoration.slot)).size, tier.decorations.length,
      `${tier.id} has at most one mesh per semantic anchor, not overlapping frame/gem centers`);
    for (const decoration of tier.decorations) {
      assert.deepEqual(Object.keys(decoration).sort(), ['model', 'rotation_degrees', 'scale', 'slot']);
      assert.equal(models.get(safePath(decoration.model))?.role, 'ornament', tier.id);
      assert.ok(slots.includes(decoration.slot), tier.id);
      assert.ok(Number.isFinite(decoration.scale) && decoration.scale >= 0.04 && decoration.scale <= 0.4, tier.id);
      assert.equal(decoration.rotation_degrees.length, 3, tier.id);
      assert.ok(decoration.rotation_degrees.every(value =>
        Number.isFinite(value) && value >= -180 && value <= 180), tier.id);
    }
    if (tier.open_animation) {
      assert.ok(base.animation.clips.some(clip => clip.name === tier.open_animation), tier.id);
    } else {
      assert.equal(base.animation.opening_support, 'separate-static-lid-no-clip', tier.id);
    }
    structures.add(JSON.stringify([tier.base_model, tier.decorations
      .map(decoration => [decoration.slot, decoration.model]).sort()]));
  }
  assert.equal(structures.size, 30, 'Styles differ in actual base/ornament/anchor structure, not just tint or scale');
});

test('preciousness increases through coherent families while early tiers stay modest and ornaments stay symmetric', () => {
  const presets = readJson(presetsPath);
  const styles = presets.source_notes.material_styles;
  assert.equal(Object.keys(styles).length, 9);
  let previousGrade = 0;
  let previousBase = null;
  const completedFamilies = new Set();
  for (const tier of presets.tiers) {
    const style = styles[tier.material_style];
    assert.ok(style.preciousness_rank >= previousGrade, tier.id);
    previousGrade = style.preciousness_rank;
    if (previousBase !== tier.base_model) {
      assert.ok(!completedFamilies.has(tier.base_model), 'Each base forms one coherent consecutive family');
      if (previousBase) completedFamilies.add(previousBase);
      previousBase = tier.base_model;
    }
    assert.ok(tier.decorations.length <= (tier.level <= 3 ? 2 : tier.level <= 9 ? 3 : 5), tier.id);
    for (const [left, right] of [['left', 'right'], ['front-left', 'front-right']]) {
      const a = tier.decorations.find(decoration => decoration.slot === left);
      const b = tier.decorations.find(decoration => decoration.slot === right);
      if (!a && !b) continue;
      assert.ok(a && b, tier.id);
      assert.equal(a.model, b.model, tier.id);
      assert.equal(a.scale, b.scale, tier.id);
      assert.equal(a.rotation_degrees[0], b.rotation_degrees[0], tier.id);
      assert.equal(a.rotation_degrees[1] + b.rotation_degrees[1], 0, tier.id);
      assert.equal(a.rotation_degrees[2], b.rotation_degrees[2], tier.id);
    }
  }
  for (const style of Object.values(styles)) {
    assert.ok(style.description && style.authorship === 'proposed-game-adaptation');
    for (const role of ['shell', 'trim', 'ornament_metal', 'gemstone']) {
      const material = style.roles[role];
      assert.match(material.base_color, /^#[a-f0-9]{6}$/i);
      assert.ok(material.metallic >= 0 && material.metallic <= 1);
      assert.ok(material.roughness > 0 && material.roughness <= 1);
    }
  }
  assert.equal(styles[presets.tiers[0].material_style].preciousness_rank, 1);
  assert.equal(styles[presets.tiers.at(-1).material_style].preciousness_rank, 9);
  assert.equal(presets.tiers.at(-1).decorations.length, 5);
  assert.deepEqual(Object.keys(presets.source_notes.decoration_transform_contract.slots).sort(), [...slots].sort());
  assert.equal(presets.source_notes.decoration_transform_contract.attachment_target, 'body');
});

test('private bases remain portable metadata references rather than redistributed restricted model files', () => {
  const catalog = readJson(catalogPath);
  const retained = readJson('assets/chests/downloaded/manifest.json');
  const originals = new Map(retained.assets.map(file => [file.path, file]));
  assert.equal(catalog.referenced_private_sources.length, 3);
  for (const source of catalog.referenced_private_sources) {
    assert.equal(source.url, retained.sources[source.id]?.url);
    assert.equal(source.package_sha256, retained.sources[source.id]?.package_sha256);
    assert.match(source.license, /Unity Asset Store Standard EULA/);
  }
  for (const file of catalog.referenced_private_models) {
    assert.ok(!file.path.startsWith(catalogPrefix), file.path);
    assert.equal(file.status, 'existing-private-build-input-reference-only');
    assert.equal(file.animation.authorship, 'game-authored-existing-conversion');
    assert.deepEqual(file.animation.clips.map(clip => clip.name), ['Open']);
    assert.equal(file.output_sha256, originals.get(file.path)?.sha256, file.path);
    assert.equal(file.output_bytes, originals.get(file.path)?.bytes, file.path);
    if (fs.existsSync(absolute(file.path))) {
      assert.equal(sha256(fs.readFileSync(absolute(file.path))), file.output_sha256, file.path);
    }
  }
  const serialized = JSON.stringify([catalog, readJson(presetsPath)]);
  assert.ok(!/"[A-Za-z]:[\\/]/.test(serialized), 'Committed metadata has no mandatory machine-specific source paths');
});
