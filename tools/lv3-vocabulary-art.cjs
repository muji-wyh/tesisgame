const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');

function checkLv3Art(root = path.resolve(__dirname, '..'), manifest) {
  manifest ||= JSON.parse(fs.readFileSync(path.join(root, 'docs/assets/lv3-vocabulary.json')));
  const words = JSON.parse(fs.readFileSync(path.join(root, 'words.json')));
  const expected = words.filter(word => word.min_age === 3 && word.image).map(word => word.id).sort();
  if (manifest.schema !== 1 || manifest.age !== 3 || manifest.count !== 69 ||
      JSON.stringify(manifest.files.map(file => file.id).sort()) !== JSON.stringify(expected)) {
    throw new Error('Lv3 artwork must cover exactly the 69 pictured curriculum words.');
  }
  const hashes = new Set();
  for (const file of manifest.files) {
    if (file.path !== `assets/images/words/lv3-${file.id}.png` || !/^[a-z]+$/.test(file.id)) {
      throw new Error(`Invalid reviewed picture path: ${file.id}`);
    }
    const bytes = fs.readFileSync(path.join(root, file.path));
    const hash = createHash('sha256').update(bytes).digest('hex');
    if (!bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])) ||
        bytes.readUInt32BE(16) !== 256 || bytes.readUInt32BE(20) !== 256 || bytes[25] !== 6 ||
        file.width !== 256 || file.height !== 256 || hash !== file.sha256 || hashes.has(hash)) {
      throw new Error(`Unreviewed, duplicate, or invalid Lv3 picture: ${file.id}`);
    }
    hashes.add(hash);
    const provider = manifest.providers[file.source.provider];
    if (!provider || !provider.creator || !['MIT', 'CC0-1.0'].includes(provider.license)) {
      throw new Error(`Missing source rights: ${file.id}`);
    }
    if (file.source.provider === 'fluent-emoji') {
      const source = file.source.path.split('/').map(encodeURIComponent).join('/');
      if (file.source.url !== `https://raw.githubusercontent.com/microsoft/fluentui-emoji/${provider.revision}/${source}` ||
          !/^[a-f0-9]{64}$/.test(file.source.sha256)) throw new Error(`Invalid Fluent source: ${file.id}`);
    } else if (file.source.scene !== file.id || !/^[a-f0-9]{64}$/.test(file.source.renderSha256)) {
      throw new Error(`Missing Blender render receipt: ${file.id}`);
    }
  }
  return { pictures: hashes.size, blender: manifest.files.filter(file => file.source.provider === 'kenney-blender').length };
}

function checkWordMotion(root = path.resolve(__dirname, '..')) {
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'docs/assets/lv3-word-motion.json')));
  const expected = ['close', 'drink', 'eat', 'hello', 'jump', 'open', 'run', 'walk'];
  if (manifest.license !== 'CC0-1.0' || JSON.stringify(manifest.files.map(file => file.id).sort()) !== JSON.stringify(expected)) {
    throw new Error('Word motion must contain exactly the eight reviewed, licensed actions.');
  }
  for (const file of manifest.files) {
    if (file.path !== `assets/images/word-motion/${file.id}.webp` || file.frameSide !== 128 || file.columns !== 8 ||
        file.fps !== 24 || file.posterFrame >= file.frames || file.posterFrame < 0) throw new Error(`Invalid word motion: ${file.id}`);
    const bytes = fs.readFileSync(path.join(root, file.path));
    if (bytes.toString('ascii', 0, 4) !== 'RIFF' || bytes.toString('ascii', 8, 12) !== 'WEBP' ||
        bytes.length !== file.bytes || createHash('sha256').update(bytes).digest('hex') !== file.sha256) {
      throw new Error(`Unreviewed or incomplete word motion: ${file.id}`);
    }
  }
  return { clips: manifest.files.length, frames: manifest.files.reduce((sum, file) => sum + file.frames, 0) };
}

module.exports = { checkLv3Art, checkWordMotion };
if (require.main === module) {
  try {
    const result = checkLv3Art();
    console.log(`Verified ${result.pictures} Lv3 pictures, including ${result.blender} Blender scene renders.`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
