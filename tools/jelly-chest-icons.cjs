const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { isDeepStrictEqual } = require('node:util');

const manifestPath = 'assets/chests/catalog/jelly-icons.json';
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const requiredDependencies = [
  'tools/render-jelly-chest-icons.gd', 'project.godot', 'assets/chests/catalog/atelier.json',
  'assets/chests/catalog/chest-states.json', 'assets/chests/catalog/chest-state-assets.json',
  'assets/chests/catalog/chest-levels.json', 'assets/chests/catalog/gameplay-chests.json',
  ...['chest_view', 'chest_model_view', 'chest_asset_states', 'chest_tier_catalog', 'chest_feel',
    'chest_opening_effect', 'game_data', 'jelly_reward_progress'].map(name => `scripts/${name}.gd`),
  'scripts/chest_rainbow_light.gdshader', 'scripts/chest_surface.gdshader'
];

function checkJellyChestIcons(root = path.resolve(__dirname, '..'), { readFile = fs.readFileSync } = {}) {
  const cache = new Map();
  const read = relative => {
    if (typeof relative !== 'string' || path.isAbsolute(relative) || relative.includes('\\') ||
        relative.split('/').some(part => !part || part === '.' || part === '..')) {
      throw new Error('Invalid Jelly chest icon input path.');
    }
    if (!cache.has(relative)) cache.set(relative, readFile(path.join(root, relative)));
    return cache.get(relative);
  };
  const verify = record => {
    const bytes = record && read(record.path);
    const normalized = bytes && /\.(?:gd|gdshader|tscn|tres|import|json|godot)$/.test(record.path) &&
      /^[a-f0-9]{64}$/.test(record.text_sha256 || '') &&
      digest(Buffer.from(bytes.toString('utf8').replace(/\r\n?/g, '\n'))) === record.text_sha256;
    if (!record || !/^[a-f0-9]{64}$/.test(record.sha256) ||
        (digest(bytes) !== record.sha256 && !normalized)) {
      throw new Error(`Stale Jelly chest icon input: ${record?.path || 'missing record'}`);
    }
  };
  const manifest = JSON.parse(read(manifestPath));
  const catalog = JSON.parse(read('assets/chests/catalog/gameplay-chests.json'));
  const sources = JSON.parse(read('assets/chests/catalog/atelier.json'));
  if (manifest.version !== 1 || JSON.stringify(manifest.render_size) !== '[768,768]' ||
      !Number.isInteger(manifest.settle_frames) || manifest.settle_frames < 6 ||
      !Array.isArray(manifest.dependencies) || !manifest.dependencies.length ||
      !Array.isArray(manifest.icons) || manifest.icons.length !== 28) {
    throw new Error('Jelly chest icons require all 28 source portraits and their native bake provenance.');
  }
  const dependencies = new Set(manifest.dependencies.map(record => record.path));
  if (requiredDependencies.some(relative => !dependencies.has(relative))) {
    throw new Error('Missing Jelly chest icon generator dependencies.');
  }
  for (const dependency of manifest.dependencies) verify(dependency);
  const ids = new Set();
  let bytes = 0;
  for (const [index, icon] of manifest.icons.entries()) {
    const recipe = catalog.tiers[index];
    const style = catalog.styles[recipe.base_source_id];
    const source = sources.models.find(model => model.id === recipe.asset_id);
    const expected = `assets/chests/models/atelier/${recipe.asset_id}/closed-jelly.png`;
    if (icon.asset_id !== recipe.asset_id || icon.tier !== index + 1 || ids.has(icon.asset_id) ||
        icon.path !== expected || icon.source_model?.path !== recipe.base_model ||
        icon.state_scene?.path !== style.state_scene || !icon.creator || !icon.license ||
        !icon.acquisition_status || !Array.isArray(icon.available_animations) || !source ||
        icon.creator !== source.source.creator || icon.license !== source.license ||
        !isDeepStrictEqual(icon.source, source.source) ||
        !isDeepStrictEqual(icon.source_inputs, source.source_inputs) ||
        !isDeepStrictEqual(icon.available_animations, source.animations)) {
      throw new Error(`Invalid Jelly chest icon source identity at tier ${index + 1}.`);
    }
    ids.add(icon.asset_id);
    if (!dependencies.has(`${icon.path}.import`)) {
      throw new Error(`Missing Jelly chest icon import settings: ${icon.asset_id}`);
    }
    verify(icon.source_model);
    verify(icon.state_scene);
    if (!Array.isArray(icon.source_inputs)) {
      throw new Error(`Missing Jelly chest icon source dependencies: ${icon.asset_id}`);
    }
    verify(icon);
    const png = read(icon.path);
    const crop = icon.crop;
    if (png.length < 24 || png.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a' ||
        png.readUInt32BE(16) !== icon.width || png.readUInt32BE(20) !== icon.height ||
        !Array.isArray(crop) || crop.length !== 4 || !crop.every(Number.isInteger) ||
        crop[0] < 0 || crop[1] < 0 || crop[2] <= 0 || crop[3] <= 0 ||
        crop[0] + crop[2] > 768 || crop[1] + crop[3] > 768 ||
        crop[2] !== icon.width || crop[3] !== icon.height) {
      throw new Error(`Invalid Jelly chest icon pixels or crop: ${icon.asset_id}`);
    }
    bytes += png.length;
  }
  return { icons: ids.size, bytes, dependencies: cache.size, manifest: manifestPath };
}

if (require.main === module) console.log(JSON.stringify(checkJellyChestIcons()));
module.exports = { checkJellyChestIcons, manifestPath };
