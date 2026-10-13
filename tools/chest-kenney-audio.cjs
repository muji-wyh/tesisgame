const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');

const CHEST_KENNEY_CUES = [
  'press', 'charge', 'step', 'step-detail', 'step-roll', 'cancel',
  'opening', 'unlock', 'release', 'settle', 'reward'
];

function readChestKenneyAudio(root) {
  const directory = path.join(root, 'assets/audio/chest-kenney');
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'docs/assets/chest-kenney-audio.json'), 'utf8'));
  if (!Array.isArray(manifest.assets) || manifest.assets.length !== CHEST_KENNEY_CUES.length ||
      new Set(manifest.assets.map(asset => asset?.id)).size !== CHEST_KENNEY_CUES.length ||
      manifest.assets.some(asset => !CHEST_KENNEY_CUES.includes(asset?.id))) {
    throw new Error('Kenney chest audio must declare exactly all eleven shared cues.');
  }
  const present = fs.readdirSync(directory).filter(name => name.toLowerCase().endsWith('.wav')).sort();
  const expected = CHEST_KENNEY_CUES.map(id => `${id}.wav`).sort();
  if (JSON.stringify(present) !== JSON.stringify(expected)) {
    throw new Error('Kenney chest audio requires exactly the eleven shared WAV recordings.');
  }
  return CHEST_KENNEY_CUES.map(id => {
    const asset = manifest.assets.find(entry => entry.id === id);
    const source = `assets/audio/chest-kenney/${id}.wav`;
    if (asset.destination !== source || !/^[a-f0-9]{64}$/.test(asset.sha256) ||
        asset.sampleRate !== 44100 || asset.channels !== 1 || asset.bitDepth !== 16 ||
        !Number.isFinite(asset.seconds) || asset.seconds <= 0 || asset.seconds > 5 ||
        (asset.bytes !== undefined && (!Number.isSafeInteger(asset.bytes) || asset.bytes < 44))) {
      throw new Error(`Invalid Kenney chest audio manifest entry: ${id}`);
    }
    const bytes = fs.readFileSync(path.join(root, source));
    if (createHash('sha256').update(bytes).digest('hex') !== asset.sha256) {
      throw new Error(`Kenney chest audio hash mismatch: ${source}`);
    }
    const invalid = () => { throw new Error(`Invalid mono PCM16 Kenney chest WAV: ${source}`); };
    if (bytes.length < 44 || bytes.toString('ascii', 0, 4) !== 'RIFF' ||
        bytes.toString('ascii', 8, 12) !== 'WAVE' || bytes.readUInt32LE(4) !== bytes.length - 8 ||
        (asset.bytes !== undefined && asset.bytes !== bytes.length)) invalid();
    let format, samples;
    for (let offset = 12; offset < bytes.length;) {
      if (offset + 8 > bytes.length) invalid();
      const name = bytes.toString('ascii', offset, offset + 4);
      const length = bytes.readUInt32LE(offset + 4);
      const end = offset + 8 + length;
      if (end + length % 2 > bytes.length) invalid();
      if (name === 'fmt ') {
        if (format || length < 16) invalid();
        format = bytes.subarray(offset + 8, end);
      }
      if (name === 'data') {
        if (samples || length === 0 || length % 2) invalid();
        samples = bytes.subarray(offset + 8, end);
      }
      offset = end + length % 2;
    }
    if (!format || !samples || format.readUInt16LE(0) !== 1 || format.readUInt16LE(2) !== 1 ||
        format.readUInt32LE(4) !== 44100 || format.readUInt32LE(8) !== 88200 ||
        format.readUInt16LE(12) !== 2 || format.readUInt16LE(14) !== 16 ||
        samples.length !== Math.round(asset.seconds * 44100) * 2) invalid();
    return { asset, bytes };
  });
}

module.exports = { CHEST_KENNEY_CUES, readChestKenneyAudio };
