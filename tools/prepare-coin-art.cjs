const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');

const OUTPUTS = Object.freeze({ 'gold-coin.png': [128, 128], 'gold-coins.png': [256, 256] });
const REBUILD = 'Restore the acquired artwork with python assets/coins/prepare.py, then run node tools/prepare-coin-art.cjs before building.';
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');

function resources(filename) {
  const source = `res://assets/coins/${filename}`;
  return { source, imported: `res://.godot/imported/${filename}-${createHash('md5').update(source).digest('hex')}.ctex` };
}

function checkedTextures(root) {
  const manifestPath = path.join(root, 'assets/coins/manifest.json');
  if (!fs.existsSync(manifestPath)) throw new Error(`The coin artwork manifest is missing. ${REBUILD}`);
  let manifest;
  try { manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8').replace(/^\uFEFF/, '')); }
  catch { throw new Error(`The coin artwork manifest is unreadable. ${REBUILD}`); }
  if (!manifest?.outputs || Object.keys(manifest.outputs).sort().join(',') !== Object.keys(OUTPUTS).sort().join(',')) {
    throw new Error(`The coin artwork manifest must include both reviewed textures. ${REBUILD}`);
  }
  return Object.entries(OUTPUTS).map(([filename, size]) => {
    const record = manifest.outputs[filename];
    if (!record || JSON.stringify(record.size) !== JSON.stringify(size) ||
        !Number.isSafeInteger(record.bytes) || record.bytes < 33 || !/^[a-f0-9]{64}$/.test(record.sha256)) {
      throw new Error(`The reviewed coin metadata is invalid: ${filename}. ${REBUILD}`);
    }
    const absolute = path.join(root, 'assets/coins', filename);
    if (!fs.existsSync(absolute)) throw new Error(`The required private coin texture is missing: assets/coins/${filename}. ${REBUILD}`);
    const bytes = fs.readFileSync(absolute);
    if (bytes.length < 33 || bytes.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a' ||
        bytes.readUInt32BE(8) !== 13 || bytes.toString('ascii', 12, 16) !== 'IHDR' ||
        bytes.readUInt32BE(16) !== size[0] || bytes.readUInt32BE(20) !== size[1] || bytes[24] !== 8 || bytes[25] !== 6) {
      throw new Error(`Expected the reviewed ${size.join(' x ')}, 8-bit RGBA coin PNG: ${filename}. ${REBUILD}`);
    }
    if (bytes.length !== record.bytes || sha256(bytes) !== record.sha256) {
      throw new Error(`The private coin texture differs from its reviewed manifest: ${filename}. ${REBUILD}`);
    }
    return { filename, absolute, path: `assets/coins/${filename}`, size, bytes: record.bytes, sha256: record.sha256 };
  });
}

function expectedImport(filename) {
  const { source, imported } = resources(filename);
  return {
    remap: { importer: '"texture"', type: '"CompressedTexture2D"', path: JSON.stringify(imported) },
    deps: { source_file: JSON.stringify(source), dest_files: JSON.stringify([imported]) },
    params: {
      'compress/mode': '0', 'compress/normal_map': '0', 'compress/channel_pack': '0',
      'mipmaps/generate': 'false', 'process/size_limit': '0',
      'process/channel_remap/red': '0', 'process/channel_remap/green': '1',
      'process/channel_remap/blue': '2', 'process/channel_remap/alpha': '3',
      'process/fix_alpha_border': 'true', 'process/premult_alpha': 'false'
    }
  };
}

function checkImport(texture) {
  const filename = texture.absolute + '.import';
  if (!fs.existsSync(filename)) throw new Error(`Coin lossless import settings are missing: ${texture.path}. Run node tools/prepare-coin-art.cjs before building.`);
  const settings = new Map();
  let section = '';
  for (const line of fs.readFileSync(filename, 'utf8').replace(/^\uFEFF/, '').split(/\r?\n/)) {
    const heading = line.match(/^\s*\[([^\]]+)\]\s*$/);
    if (heading) { section = heading[1]; continue; }
    const setting = line.match(/^\s*([^=\s]+)\s*=\s*(.*?)\s*$/);
    if (!setting) continue;
    const key = `${section}.${setting[1]}`;
    if (settings.has(key)) throw new Error(`Coin import repeats a setting: ${key}`);
    settings.set(key, setting[2]);
  }
  for (const [section, values] of Object.entries(expectedImport(texture.filename))) {
    for (const [key, value] of Object.entries(values)) {
      if (settings.get(`${section}.${key}`) !== value) {
        throw new Error(`Coin import must preserve its reviewed lossless RGBA pixels: ${texture.path}: ${key}. Run node tools/prepare-coin-art.cjs before building.`);
      }
    }
  }
}

function checkCoinArt(root = path.resolve(__dirname, '..')) {
  return checkedTextures(root).map(texture => {
    checkImport(texture);
    const { filename, absolute, ...record } = texture;
    return { ...record, import: 'Lossless RGBA; no mipmaps or texture resizing' };
  });
}

function prepareCoinArt(root = path.resolve(__dirname, '..')) {
  // Verify every actual PNG before changing any import settings.
  for (const texture of checkedTextures(root)) {
    const filename = texture.absolute + '.import';
    const previous = fs.existsSync(filename) ? fs.readFileSync(filename, 'utf8') : '';
    const uid = previous.match(/^uid="uid:\/\/[a-z0-9]+"$/m)?.[0];
    const metadata = Object.entries(expectedImport(texture.filename)).map(([section, values]) =>
      `[${section}]\n\n${section === 'remap' && uid ? uid + '\n' : ''}` +
      Object.entries(values).map(([key, value]) => `${key}=${value}`).join('\n')).join('\n\n') + '\n';
    if (previous !== metadata) fs.writeFileSync(filename, metadata);
  }
  return checkCoinArt(root);
}

if (require.main === module) {
  if (process.argv.length > 3 || (process.argv[2] && process.argv[2] !== '--check')) {
    throw new Error('Usage: node tools/prepare-coin-art.cjs [--check]');
  }
  console.log(JSON.stringify(process.argv[2] === '--check' ? checkCoinArt() : prepareCoinArt(), null, 2));
}

module.exports = { OUTPUTS, checkCoinArt, prepareCoinArt };
