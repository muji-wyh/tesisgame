const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

// Model conversion is a separate, serialized Blender job. This step validates
// its completed outputs before replacing the runtime manifest atomically.
const root = path.resolve(__dirname, '..');
const sourceRoot = path.resolve(process.argv[2] || 'C:/uworks/TalkQuest');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const definitions = {
  harvest: ['iron-wood', 'casual-chests', 'Harvest Ironwood'],
  tide: ['sea', 'stylized-sea-chest', 'Tide Captain'],
  nebula: ['crowned', 'stylized-chests', 'Nebula Crown'],
  bramble: ['skull', 'poly-style-fantasy-chest', 'Bramble Relic'],
  bonbon: ['painted-gold', 'cartoon-treasure-chest', 'Bonbon Gold']
};
const catalog = new Map();
for (const filename of ['sources.downloaded.json', 'sources.chests.json', 'sources.additional-chests.json']) {
  const document = read(path.join(sourceRoot, 'asset-review', filename));
  for (const entry of document.sources || []) catalog.set(entry.id, entry);
}
const models = new Map(read(path.join(root, 'build/chest-quality/model-metadata.json')).models.map(model => [model.id, model]));
const manifest = { version: 2, renderer: 'live-model', design_size: 1024, sources: {}, styles: {}, assets: [] };
for (const [style, [id, source, name]] of Object.entries(definitions)) {
  const model = models.get(id);
  if (!model || !model.model_parts?.some(part => part.role === 'lid')) throw new Error(`Missing articulated model: ${id}`);
  const modelPath = model.model.replace(/^res:\/\//, '');
  if (!/^assets\/chests\/models\/[a-z-]+\.glb$/.test(modelPath)) throw new Error(`Invalid model path: ${modelPath}`);
  const bytes = fs.readFileSync(path.join(root, modelPath));
  const sha256 = crypto.createHash('sha256').update(bytes).digest('hex');
  if (bytes.length !== model.bytes || sha256 !== model.sha256) throw new Error(`Model changed after conversion: ${id}`);
  const entry = catalog.get(source), metadata = entry?.provenance?.package_metadata;
  if (!metadata?.title || !entry.provenance.package_sha256) throw new Error(`Missing source package provenance: ${source}`);
  manifest.sources[source] = {
    title: metadata.title, publisher: metadata.publisher.label, version: metadata.version,
    product_id: metadata.id, url: entry.url || `https://assetstore.unity.com/packages/slug/${metadata.id}`,
    package_sha256: entry.provenance.package_sha256,
    license: 'Unity Asset Store Standard EULA; embedded game artwork only'
  };
  const skin = { name, source, model: modelPath };
  for (const key of ['open_animation', 'open_start', 'open_end', 'model_parts', 'camera_direction',
    'closed_bounds_3d', 'motion_bounds_3d', 'cavity_3d', 'seam_3d', 'vertex_count', 'triangle_count']) skin[key] = model[key];
  skin.motion = model.motion.method;
  skin.materials = model.materials.mapping;
  skin.source_model_sha256 = model.source_sha256;
  skin.texture_sizes = model.materials.textures.map(texture => ({
    source: texture.source_dimensions, runtime: texture.runtime_dimensions, sha256: texture.source_sha256
  }));
  manifest.styles[style] = skin;
  manifest.assets.push({ path: modelPath, bytes: bytes.length, sha256 });
}
const destination = path.join(root, 'assets/chests/downloaded/manifest.json');
fs.writeFileSync(destination + '.tmp', JSON.stringify(manifest, null, 2) + '\n');
fs.renameSync(destination + '.tmp', destination);
console.log(`Validated and catalogued ${manifest.assets.length} animated chest models (${(manifest.assets.reduce((sum, asset) => sum + asset.bytes, 0) / 1e6).toFixed(2)} MB).`);
