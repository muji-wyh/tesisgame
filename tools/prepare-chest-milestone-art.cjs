const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');

const DEFAULT_SOURCE_DIRECTORY = 'C:/uworks/AssetsSource/Toon FX [1.52]/Textures';
const TEXTURES = Object.freeze([
  Object.freeze({ source: 'glowlines.png', destination: 'assets/chests/milestone/rays.png', bytes: 19013,
    sha256: '75ecb9a8d2c20b4892dc45160decb6d18387ce3892f7fc8ee2401d5f8773d8c1' }),
  Object.freeze({ source: 'sparkle.png', destination: 'assets/chests/milestone/sparkle.png', bytes: 50052,
    sha256: 'e8387f9328d38d0b10706814f0c3500debaf1ba2133a8c80a65ef636a8238856' })
]);
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');

function resources(texture) {
  const source = 'res://' + texture.destination;
  return { source, imported: `res://.godot/imported/${path.basename(texture.destination)}-${createHash('md5').update(source).digest('hex')}.ctex` };
}

function validateSource(bytes, texture) {
  if (bytes.length !== texture.bytes || sha256(bytes) !== texture.sha256) {
    throw new Error(`${texture.source} does not match the reviewed Toon FX 1.52 source. No assets were changed.`);
  }
  if (bytes.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a' ||
      bytes.readUInt32BE(16) !== 512 || bytes.readUInt32BE(20) !== 512 || bytes[24] !== 8 || bytes[25] !== 6) {
    throw new Error(`Expected the reviewed 512 x 512, 8-bit RGBA ${texture.source} PNG. No assets were changed.`);
  }
}

function checkImport(filename, texture) {
  if (!fs.existsSync(filename)) {
    throw new Error(`The chest milestone lossless import settings are missing for ${texture.destination}. Run node tools/prepare-chest-milestone-art.cjs before building.`);
  }
  const sections = new Map();
  let section = '';
  for (const line of fs.readFileSync(filename, 'utf8').replace(/^\uFEFF/, '').split(/\r?\n/)) {
    const heading = line.match(/^\s*\[([^\]]+)\]\s*$/);
    if (heading) {
      section = heading[1];
      continue;
    }
    const setting = line.match(/^\s*([^=\s]+)\s*=\s*(.*?)\s*$/);
    if (!setting) continue;
    const key = `${section}.${setting[1]}`;
    if (sections.has(key)) throw new Error(`The chest milestone import repeats a setting: ${key}`);
    sections.set(key, setting[2]);
  }
  const { source, imported } = resources(texture);
  const expected = {
    'remap.importer': '"texture"',
    'remap.type': '"CompressedTexture2D"',
    'remap.path': JSON.stringify(imported),
    'deps.source_file': JSON.stringify(source),
    'deps.dest_files': JSON.stringify([imported]),
    'params.compress/mode': '0',
    'params.compress/normal_map': '0',
    'params.compress/channel_pack': '0',
    'params.mipmaps/generate': 'false',
    'params.process/size_limit': '0',
    'params.process/channel_remap/red': '0',
    'params.process/channel_remap/green': '1',
    'params.process/channel_remap/blue': '2',
    'params.process/channel_remap/alpha': '3',
    'params.process/premult_alpha': 'false'
  };
  for (const [key, value] of Object.entries(expected)) {
    if (sections.get(key) !== value) {
      throw new Error(`The chest milestone texture requires its reviewed lossless import settings: ${texture.destination}: ${key}`);
    }
  }
}

function checkChestMilestoneArt(root = path.resolve(__dirname, '..')) {
  return TEXTURES.map(texture => {
    const filename = path.join(root, texture.destination);
    if (!fs.existsSync(filename)) {
      throw new Error(`The private chest milestone texture is missing: ${texture.destination}. Restore it with node tools/prepare-chest-milestone-art.cjs before building.`);
    }
    validateSource(fs.readFileSync(filename), texture);
    checkImport(filename + '.import', texture);
    return { path: texture.destination, bytes: texture.bytes, sha256: texture.sha256,
      size: [512, 512], import: 'Lossless RGBA; no mipmaps or texture resizing' };
  });
}

function importMetadata(texture, previous) {
  const { source, imported } = resources(texture);
  const uid = previous.match(/^uid="uid:\/\/[a-z0-9]+"$/m)?.[0];
  return `[remap]

importer="texture"
type="CompressedTexture2D"
${uid ? uid + '\n' : ''}path="${imported}"
metadata={
"vram_texture": false
}

[deps]

source_file="${source}"
dest_files=["${imported}"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.85
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
`;
}

function prepareChestMilestoneArt({ sourceDirectory = DEFAULT_SOURCE_DIRECTORY, root = path.resolve(__dirname, '..') } = {}) {
  // Validate both sources before writing either output or its import settings.
  const inputs = TEXTURES.map(texture => {
    const bytes = fs.readFileSync(path.join(path.resolve(sourceDirectory), texture.source));
    validateSource(bytes, texture);
    return { texture, bytes };
  });
  for (const { texture, bytes } of inputs) {
    const filename = path.join(root, texture.destination);
    fs.mkdirSync(path.dirname(filename), { recursive: true });
    if (!fs.existsSync(filename) || sha256(fs.readFileSync(filename)) !== texture.sha256) fs.writeFileSync(filename, bytes);
    const metadataPath = filename + '.import';
    const previous = fs.existsSync(metadataPath) ? fs.readFileSync(metadataPath, 'utf8') : '';
    const metadata = importMetadata(texture, previous);
    if (previous !== metadata) fs.writeFileSync(metadataPath, metadata);
  }
  return checkChestMilestoneArt(root);
}

if (require.main === module) {
  if (process.argv.length > 3) throw new Error('Usage: node tools/prepare-chest-milestone-art.cjs [path/to/Toon-FX/Textures]');
  console.log(JSON.stringify(prepareChestMilestoneArt({ sourceDirectory: process.argv[2] || DEFAULT_SOURCE_DIRECTORY }), null, 2));
}

module.exports = { TEXTURES, DEFAULT_SOURCE_DIRECTORY, checkChestMilestoneArt, prepareChestMilestoneArt };
