const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');

const CHEST_REFERENCE_CUES = { step: 0.24, 'step-detail': 0.24, 'step-roll': 0.24, release: 1.50, reward: 1.20 };

function readChestReferenceAudio(root) {
  const directory = path.join(root, 'assets/imported-audio/chest-reference');
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'docs/assets/chest-reference-audio.json'), 'utf8'));
  const ids = Object.keys(CHEST_REFERENCE_CUES);
  if (!Array.isArray(manifest.assets) || manifest.assets.length !== ids.length) {
    throw new Error('Chest reference audio must declare all five shared recordings.');
  }
  const present = fs.readdirSync(directory).filter(name => name.toLowerCase().endsWith('.wav')).sort();
  if (JSON.stringify(present) !== JSON.stringify(ids.map(id => `${id}.wav`).sort())) {
    throw new Error('Chest reference audio requires exactly the five shared recordings.');
  }
  return manifest.assets.map((asset, index) => {
    const id = ids[index], source = `assets/imported-audio/chest-reference/${id}.wav`;
    if (!asset || asset.id !== id || asset.destination !== source || !/^[a-f0-9]{64}$/.test(asset.sha256) ||
        asset.sampleRate !== 44100 || asset.channels !== 1 || asset.bitDepth !== 16 ||
        asset.seconds !== CHEST_REFERENCE_CUES[id]) {
      throw new Error(`Invalid chest reference manifest entry: ${id}`);
    }
    const bytes = fs.readFileSync(path.join(root, source));
    if (createHash('sha256').update(bytes).digest('hex') !== asset.sha256) {
      throw new Error(`Chest reference audio hash mismatch: ${source}`);
    }
    if (bytes.length < 44 || bytes.toString('ascii', 0, 4) !== 'RIFF' ||
        bytes.readUInt32LE(4) !== bytes.length - 8 || bytes.toString('ascii', 8, 16) !== 'WAVEfmt ' ||
        bytes.readUInt32LE(16) !== 16 || bytes.readUInt16LE(20) !== 1 || bytes.readUInt16LE(22) !== 1 ||
        bytes.readUInt32LE(24) !== 44100 || bytes.readUInt32LE(28) !== 88200 ||
        bytes.readUInt16LE(32) !== 2 || bytes.readUInt16LE(34) !== 16 ||
        bytes.toString('ascii', 36, 40) !== 'data' || bytes.readUInt32LE(40) !== bytes.length - 44 ||
        bytes.length !== 44 + Math.round(asset.seconds * 44100) * 2) {
      throw new Error(`Invalid mono PCM16 chest reference WAV: ${source}`);
    }
    return { asset, bytes };
  });
}

module.exports = { CHEST_REFERENCE_CUES, readChestReferenceAudio };
