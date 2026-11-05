const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { readModelContainer, imageDimensions, readFloatAccessor } = require('./helpers/chest-model-assets.cjs');

const root = path.resolve(__dirname, '..');
const manifestPath = 'assets/chests/catalog/gameplay-chests.json';
const sourcePath = 'assets/chests/catalog/atelier.json';
const materialIds = [
  'wayfarer-oak', 'ironbound-trail', 'duskwatch-coffer', 'dungeon-keeper',
  'cooper-star', 'tideguard', 'meadow-cabinet', 'sunward', 'harvest-strongbox',
  'gilded-waywatch', 'verdant-oath', 'bonbon-keepsake', 'velvet-parcel',
  'moonbound', 'royal-rose', 'lagoon-reliquary', 'moonstone-crown', 'prism-signal',
  'aegis-transit', 'frost-relay', 'solar-relay', 'nova-buddy', 'jade-reliquary',
  'crimson-citadel', 'regent-wings', 'cobalt-vault', 'rune-sentinel', 'aether-vault'
];
const privateIds = ['meadow-cabinet', 'harvest-strongbox', 'bonbon-keepsake', 'lagoon-reliquary', 'moonstone-crown'];
const sha256 = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const absolute = relative => path.join(root, ...relative.split('/'));
const readJson = relative => JSON.parse(fs.readFileSync(absolute(relative), 'utf8'));

function safePath(relative) {
  assert.equal(typeof relative, 'string');
  assert.ok(relative.startsWith('assets/chests/'), relative);
  assert.ok(!relative.includes('\\') && !relative.split('/').includes('..'), relative);
  assert.ok(!path.isAbsolute(relative) && !relative.includes(':'), relative);
  assert.ok(fs.existsSync(absolute(relative)), `Missing selected chest asset: ${relative}`);
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

function vector3(value, label) {
  assert.equal(value?.length, 3, label);
  assert.ok(value.every(Number.isFinite), label);
}

test('ninety-nine gameplay tiers use all twenty-eight ranked Atelier materials and repeat only the final material', () => {
  const manifest = readJson(manifestPath);
  const sources = readJson(sourcePath);
  const ranking = readJson('assets/chests/catalog/chest-levels.json');
  assert.equal(manifest.version, 1);
  assert.equal(manifest.max_tier, 99);
  assert.equal(manifest.tier_count, 99);
  assert.equal(manifest.material_count, 28);
  assert.deepEqual(manifest.material_ids, materialIds);
  assert.equal(manifest.source_catalog, sourcePath);
  assert.equal(manifest.repeat_from_level, 29);
  assert.equal(manifest.repeat_asset_id, 'aether-vault');
  const modelRows = ranking.levels.filter(row => row.asset_type === 'model');
  assert.equal(modelRows.length, 99);
  assert.deepEqual([...new Set(modelRows.map(row => row.asset_id))], materialIds);
  assert.deepEqual(manifest.tiers.map(tier => tier.level), Array.from({ length: 99 }, (_, index) => index + 1));
  assert.equal(new Set(manifest.tiers.map(tier => tier.id)).size, 99);
  assert.equal(sources.models.length, materialIds.length);
  const known = new Map(sources.models.map(entry => [entry.id, entry]));
  for (const [index, tier] of manifest.tiers.entries()) {
    const selected = materialIds[Math.min(index, materialIds.length - 1)];
    assert.equal(tier.asset_id, selected, `Lv${index + 1}`);
    assert.equal(tier.base_source_id, selected, tier.id);
    assert.equal(tier.material_style, selected, tier.id);
    assert.equal(tier.base_model, known.get(selected)?.model, tier.id);
    assert.equal(tier.repeated_material, index >= 28, tier.id);
    assert.equal(modelRows[index].asset_id, selected, tier.id);
    assert.equal(tier.id, `tier-${String(index + 1).padStart(2, '0')}-${selected}`);
    assert.ok(tier.name.length > 0 && !/skull|horror|mimic|fang|demon/i.test(tier.name));
    assert.deepEqual(tier.decorations, []);
    safePath(tier.base_model);
  }
  assert.equal(new Set(manifest.tiers.map(tier => tier.base_model)).size, 28);
  assert.ok(!/models\/(?:cc0|licensed)\/|sprites\//.test(JSON.stringify(manifest)));
});

test('every selected GLB has exact hashed bytes, volumetric modeled detail and bounded authored textures', () => {
  const sources = readJson(sourcePath);
  let modelBytes = 0;
  for (const entry of sources.models) {
    const model = readModelContainer(absolute(safePath(entry.model)));
    const { bytes, gltf } = model;
    assert.equal(gltf.asset.version, '2.0', entry.id);
    assert.equal(bytes.length, entry.bytes, entry.id);
    assert.equal(sha256(bytes), entry.sha256, entry.id);
    modelBytes += bytes.length;
    assert.ok(gltf.buffers.every(buffer => !buffer.uri), entry.id);
    assert.equal(gltf.meshes.length, entry.mesh_resources, entry.id);
    assert.equal(gltf.nodes.filter(node => Number.isInteger(node.mesh)).length, entry.mesh_instances, entry.id);
    assert.equal((gltf.materials || []).length, entry.materials, entry.id);
    const primitives = gltf.meshes.flatMap(mesh => mesh.primitives);
    assert.equal(primitives.length, entry.primitives, entry.id);
    let vertices = 0;
    let triangles = 0;
    const allPoints = [];
    for (const primitive of primitives) {
      assert.equal(primitive.mode ?? 4, 4, entry.id);
      const points = readFloatAccessor(model, primitive.attributes.POSITION);
      const indices = indexValues(model, primitive.indices);
      assert.ok(points.length > 0 && indices.length > 0, entry.id);
      assert.equal(indices.length % 3, 0, entry.id);
      assert.ok(indices.every(index => index < points.length), entry.id);
      assert.ok(Number.isInteger(primitive.attributes.NORMAL), entry.id);
      assert.ok(Number.isInteger(primitive.material) && primitive.material < entry.materials, entry.id);
      vertices += points.length;
      triangles += indices.length / 3;
      for (const point of points) allPoints.push(point);
    }
    assert.equal(vertices, entry.vertices, entry.id);
    assert.equal(triangles, entry.triangles, entry.id);
    assert.equal(spatialRank(allPoints), 3, `${entry.id} is actual chest geometry`);
    assert.ok(triangles > 1000 && triangles < 55000, `${entry.id} has bounded production detail`);
    assert.equal((gltf.images || []).length, entry.images.length, entry.id);
    for (const [index, image] of (gltf.images || []).entries()) {
      assert.ok(Number.isInteger(image.bufferView) && !image.uri, entry.id);
      const view = gltf.bufferViews[image.bufferView];
      const imageBytes = model.binary.subarray(view.byteOffset || 0, (view.byteOffset || 0) + view.byteLength);
      const recorded = entry.images[index];
      const dimensions = imageDimensions(imageBytes);
      assert.equal(recorded.name, image.name, entry.id);
      assert.equal(recorded.mime_type, image.mimeType, entry.id);
      assert.equal(recorded.bytes, imageBytes.length, entry.id);
      assert.equal(recorded.sha256, sha256(imageBytes), entry.id);
      assert.deepEqual(recorded.size, [dimensions.width, dimensions.height], entry.id);
      assert.ok(dimensions.width <= 1024 && dimensions.height <= 1024, entry.id);
    }
  }
  assert.equal(modelBytes, sources.model_bytes);
  assert.ok(modelBytes < 40000000, 'All twenty-eight runtime chest materials remain below 40 MB');
});

test('all selected sources retain real continuous one-second Open and Close lid clips', () => {
  for (const entry of readJson(sourcePath).models) {
    const model = readModelContainer(absolute(entry.model));
    assert.deepEqual(model.gltf.animations.map(clip => clip.name).sort(), ['Close', 'Open']);
    const lid = entry.style.model_parts.find(part => part.role === 'lid');
    assert.ok(lid && model.gltf.nodes.some(node => node.name === lid.node), entry.id);
    for (const animation of model.gltf.animations) {
      const recorded = entry.animations.find(clip => clip.name === animation.name);
      const times = animation.samplers.flatMap(sampler => readFloatAccessor(model, sampler.input).flat());
      assert.ok(Math.abs(Math.min(...times)) < 1e-6, entry.id);
      assert.ok(Math.abs(Math.max(...times) - 1) < 1e-6, entry.id);
      assert.equal(recorded.duration_seconds, 1, entry.id);
      assert.equal(recorded.samples, 61, entry.id);
      const targets = [...new Set(animation.channels.map(channel => model.gltf.nodes[channel.target.node].name))];
      assert.deepEqual(targets, recorded.targets, entry.id);
      assert.ok(targets.includes('Lid'), entry.id);
      const moving = animation.channels.some(channel => {
        if (!['rotation', 'translation'].includes(channel.target.path)) return false;
        const sampler = animation.samplers[channel.sampler];
        assert.notEqual(sampler.interpolation, 'STEP', entry.id);
        let values = readFloatAccessor(model, sampler.output);
        if (sampler.interpolation === 'CUBICSPLINE') values = values.filter((_, index) => index % 3 === 1);
        return values.some(value => {
          const first = values[0];
          const distance = Math.hypot(...value.map((component, index) => component - first[index]));
          const sameRotation = channel.target.path === 'rotation'
            && Math.hypot(...value.map((component, index) => component + first[index])) < 1e-6;
          return distance > 0.1 && !sameRotation;
        });
      });
      assert.ok(moving, `${entry.id}/${animation.name} genuinely moves its lid`);
    }
  }
});

test('tier and theme styles preserve selected source materials, mechanisms and complete state scenes', () => {
  const manifest = readJson(manifestPath);
  const states = readJson('assets/chests/catalog/chest-states.json');
  for (const entry of readJson(sourcePath).models) {
    const style = manifest.styles[entry.id];
    const state = states.variants.find(variant => variant.id === entry.id);
    assert.equal(style.model, entry.model, entry.id);
    assert.equal(style.source_model, entry.model, entry.id);
    assert.equal(style.state_asset_id, entry.id, entry.id);
    assert.equal(style.state_scene, state?.scene, entry.id);
    safePath(style.state_scene);
    assert.equal(state.model, entry.model, entry.id);
    assert.equal(state.model_sha256, entry.sha256, entry.id);
    assert.deepEqual(state.states, ['closed', 'open', 'treasure', 'magic'], entry.id);
    assert.deepEqual(style.model_parts, entry.style.model_parts, entry.id);
    assert.equal(style.open_animation, 'Open', entry.id);
    assert.equal(style.open_start, 0, entry.id);
    assert.equal(style.open_end, 1, entry.id);
    assert.equal(style.normalize_model, false, entry.id);
    assert.equal(style.material_authorship, 'atelier-authored-source-materials', entry.id);
    assert.deepEqual(style.material_profile, {}, entry.id);
    assert.deepEqual(style.decorations, [], entry.id);
    assert.deepEqual(style.treasure, state.treasure, entry.id);
    assert.deepEqual(style.magic, state.magic, entry.id);
    for (const box of [style.closed_bounds_3d, style.motion_bounds_3d]) {
      vector3(box.min, entry.id);
      vector3(box.max, entry.id);
      assert.ok(box.max.every((value, axis) => value > box.min[axis]), entry.id);
    }
  }
  for (const alias of ['royal', 'energy', 'harvest', 'crystal', 'tide', 'nebula', 'bramble', 'bonbon']) {
    const selected = manifest.tiers[manifest.theme_tiers[alias] - 1];
    assert.equal(manifest.styles[alias].model, selected.base_model, alias);
    assert.equal(manifest.styles[alias].state_asset_id, selected.asset_id, alias);
  }
  const tierCode = fs.readFileSync(absolute('scripts/chest_tier_catalog.gd'), 'utf8');
  assert.match(tierCode, /const MAX_TIER: int = 99/);
  assert.match(tierCode, /const MATERIAL_COUNT: int = 28/);
  assert.ok(tierCode.includes(`res://${manifestPath}`));
  assert.match(tierCode, /\.duplicate\(true\)/);
});

test('authored source and optimization provenance remain truthful and private derivatives stay protected', () => {
  const sources = readJson(sourcePath);
  const ignored = fs.readFileSync(absolute('.gitignore'), 'utf8').split(/\r?\n/);
  assert.equal(sources.collection, 'Treasure Atelier');
  assert.match(sources.license, /Mixed.*CC0.*private Unity Asset Store/);
  assert.deepEqual(sources.models.filter(entry => entry.license !== 'CC0-1.0').map(entry => entry.id).sort(), [...privateIds].sort());
  for (const entry of sources.models) {
    assert.ok(entry.source.creator && entry.source.title, entry.id);
    assert.match(entry.source.url, /^https:\/\//, entry.id);
    assert.match(entry.authoring_glb_sha256, /^[a-f0-9]{64}$/, entry.id);
    assert.ok(Array.isArray(entry.authored_changes) && entry.authored_changes.length > 0, entry.id);
    const runtime = entry.runtime_source_record;
    assert.equal(runtime.sha256, entry.sha256, entry.id);
    assert.equal(runtime.triangles, entry.triangles, entry.id);
    assert.ok(runtime.source_triangles > entry.triangles, entry.id);
    assert.match(runtime.source_glb_sha256, /^[a-f0-9]{64}$/, entry.id);
    for (const input of entry.source_inputs || []) {
      if (input.original_source_sha256) assert.match(input.original_source_sha256, /^[a-f0-9]{64}$/, entry.id);
      if (!input.license_file) continue;
      const notice = path.resolve(absolute('assets/chests/catalog'), input.license_file);
      assert.ok(notice.startsWith(absolute('assets/chests') + path.sep), entry.id);
      assert.ok(fs.existsSync(notice), `${entry.id} preserves its acquired license notice`);
    }
    if (privateIds.includes(entry.id)) {
      assert.match(entry.license, /Unity Asset Store Standard EULA/, entry.id);
      assert.ok(ignored.includes(`assets/chests/models/atelier/${entry.id}/`), entry.id);
    } else {
      const editionNotice = absolute(`assets/chests/sources/atelier/licenses/${entry.id}-LICENSE.txt`);
      const sourceNotice = entry.source.license_file
        ? absolute(`assets/chests/sources/atelier/licenses/${path.posix.basename(path.posix.dirname(entry.source.license_file))}-LICENSE.txt`)
        : null;
      assert.ok((entry.source_inputs || []).some(input => input.license_file) || fs.existsSync(editionNotice)
        || (sourceNotice && fs.existsSync(sourceNotice)),
        `${entry.id} retains a source or edition-specific CC0 notice`);
      if (sourceNotice && fs.existsSync(sourceNotice) && entry.source.license_sha256) {
        assert.equal(sha256(fs.readFileSync(sourceNotice)), entry.source.license_sha256, entry.id);
      }
    }
  }
  assert.ok(!/"[A-Za-z]:[\\/]/.test(JSON.stringify([sources, readJson(manifestPath)])),
    'Runtime metadata does not require machine-specific acquisition paths');
});
