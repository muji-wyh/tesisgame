const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { CHEST_KENNEY_CUES } = require('../../tools/chest-kenney-audio.cjs');

function chestKenneyFixture(root, writeImport = () => {}) {
  const assets = CHEST_KENNEY_CUES.map((id, index) => {
    const seconds = id === 'charge' ? 0.8 : (id === 'release' ? 1.5 : (id === 'reward' ? 0.56 : 0.24));
    const frames = Math.round(44100 * seconds), wav = Buffer.alloc(44 + frames * 2);
    wav.write('RIFF'); wav.writeUInt32LE(wav.length - 8, 4); wav.write('WAVEfmt ', 8);
    wav.writeUInt32LE(16, 16); wav.writeUInt16LE(1, 20); wav.writeUInt16LE(1, 22);
    wav.writeUInt32LE(44100, 24); wav.writeUInt32LE(88200, 28);
    wav.writeUInt16LE(2, 32); wav.writeUInt16LE(16, 34);
    wav.write('data', 36); wav.writeUInt32LE(frames * 2, 40);
    for (let frame = 0; frame < frames; frame++) {
      wav.writeInt16LE(Math.round(Math.sin(frame * (0.05 + index * 0.02)) * 8000), 44 + frame * 2);
    }
    const destination = `assets/audio/chest-kenney/${id}.wav`;
    fs.mkdirSync(path.dirname(path.join(root, destination)), { recursive: true });
    fs.writeFileSync(path.join(root, destination), wav);
    writeImport(destination);
    return { id, destination, sha256: createHash('sha256').update(wav).digest('hex'),
      bytes: wav.length, seconds, sampleRate: 44100, channels: 1, bitDepth: 16 };
  });
  const manifestPath = path.join(root, 'docs/assets/chest-kenney-audio.json');
  fs.mkdirSync(path.dirname(manifestPath), { recursive: true });
  const writeManifest = () => fs.writeFileSync(manifestPath, JSON.stringify({ assets }));
  writeManifest();
  return { assets, manifestPath, writeManifest };
}

module.exports = { chestKenneyFixture };
