const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');

const SOURCE_SHA256 = '14606c1eacc47550afdaddb920b8102363108d72a0ad02997366cd894bae4108';
const SOURCE_BYTES = 17134;
const DESTINATION = 'assets/images/jelly-match/confetti.png';
const DEFAULT_SOURCE = 'C:/uworks/AssetsSource/Toon FX [1.52]/Textures/confetti2x2_smoothed.png';
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const RESOURCE = 'res://' + DESTINATION;
const IMPORTED = `res://.godot/imported/confetti.png-${createHash('md5').update(RESOURCE).digest('hex')}.ctex`;

function validateSource(bytes) {
  if (bytes.length !== SOURCE_BYTES || sha256(bytes) !== SOURCE_SHA256) {
    throw new Error('The confetti atlas does not match the reviewed Toon FX 1.52 source. No assets were changed.');
  }
  if (bytes.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a' ||
      bytes.readUInt32BE(16) !== 512 || bytes.readUInt32BE(20) !== 512 || bytes[25] !== 6) {
    throw new Error('Expected the reviewed 512 x 512 RGBA confetti PNG. No assets were changed.');
  }
}

function checkJellyRewardArt(root = path.resolve(__dirname, '..')) {
  const filename = path.join(root, DESTINATION);
  if (!fs.existsSync(filename)) {
    throw new Error('The private Jelly confetti atlas is missing. Restore it with node tools/prepare-jelly-reward-art.cjs before building.');
  }
  const bytes = fs.readFileSync(filename);
  validateSource(bytes);
  if (!fs.existsSync(filename + '.import')) {
    throw new Error('The Jelly confetti lossless import settings are missing. Run node tools/prepare-jelly-reward-art.cjs before building.');
  }
  const sections = new Map();
  let section = '';
  for (const line of fs.readFileSync(filename + '.import', 'utf8').replace(/^\uFEFF/, '').split(/\r?\n/)) {
    const heading = line.match(/^\s*\[([^\]]+)\]\s*$/);
    if (heading) {
      section = heading[1];
      continue;
    }
    const setting = line.match(/^\s*([^=\s]+)\s*=\s*(.*?)\s*$/);
    if (!setting) continue;
    const key = `${section}.${setting[1]}`;
    if (sections.has(key)) throw new Error('The Jelly confetti import repeats a setting: ' + key);
    sections.set(key, setting[2]);
  }
  const expected = {
    'remap.importer': '"texture"',
    'remap.type': '"CompressedTexture2D"',
    'remap.path': JSON.stringify(IMPORTED),
    'deps.source_file': JSON.stringify(RESOURCE),
    'deps.dest_files': JSON.stringify([IMPORTED]),
    'params.compress/mode': '0',
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
      throw new Error('The Jelly confetti atlas requires its reviewed lossless import settings: ' + key);
    }
  }
  return { path: DESTINATION, bytes: bytes.length, sha256: SOURCE_SHA256,
    size: [512, 512], import: 'Lossless RGBA; no mipmaps or texture resizing' };
}

function prepareJellyRewardArt({ source = DEFAULT_SOURCE, root = path.resolve(__dirname, '..') } = {}) {
  const bytes = fs.readFileSync(path.resolve(source));
  validateSource(bytes);
  const filename = path.join(root, DESTINATION);
  fs.mkdirSync(path.dirname(filename), { recursive: true });
  if (!fs.existsSync(filename) || sha256(fs.readFileSync(filename)) !== SOURCE_SHA256) {
    fs.writeFileSync(filename, bytes);
  }
  const metadataPath = filename + '.import';
  const previous = fs.existsSync(metadataPath) ? fs.readFileSync(metadataPath, 'utf8') : '';
  const uid = previous.match(/^uid="uid:\/\/[a-z0-9]+"$/m)?.[0];
  const metadata = `[remap]

importer="texture"
type="CompressedTexture2D"
${uid ? uid + '\n' : ''}path="${IMPORTED}"
metadata={
"vram_texture": false
}

[deps]

source_file="${RESOURCE}"
dest_files=["${IMPORTED}"]

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
  if (previous !== metadata) fs.writeFileSync(metadataPath, metadata);
  return checkJellyRewardArt(root);
}

if (require.main === module) {
  if (process.argv.length > 3) throw new Error('Usage: node tools/prepare-jelly-reward-art.cjs [path/to/confetti2x2_smoothed.png]');
  console.log(JSON.stringify(prepareJellyRewardArt({ source: process.argv[2] || DEFAULT_SOURCE }), null, 2));
}

module.exports = { SOURCE_SHA256, SOURCE_BYTES, DESTINATION, DEFAULT_SOURCE, checkJellyRewardArt, prepareJellyRewardArt };
