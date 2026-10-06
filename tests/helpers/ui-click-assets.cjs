const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');

function uiClickFixture(root, writeImport = () => {}) {
  const frames = 3528, bytes = Buffer.alloc(44 + frames * 2);
  bytes.write('RIFF'); bytes.writeUInt32LE(bytes.length - 8, 4); bytes.write('WAVEfmt ', 8);
  bytes.writeUInt32LE(16, 16); bytes.writeUInt16LE(1, 20); bytes.writeUInt16LE(1, 22);
  bytes.writeUInt32LE(44100, 24); bytes.writeUInt32LE(88200, 28);
  bytes.writeUInt16LE(2, 32); bytes.writeUInt16LE(16, 34);
  bytes.write('data', 36); bytes.writeUInt32LE(bytes.length - 44, 40);
  for (let frame = 0; frame < frames; frame++) {
    bytes.writeInt16LE(Math.round(Math.sin(frame * 0.17) * Math.sin(Math.PI * frame / (frames - 1)) * 8000), 44 + frame * 2);
  }
  const destination = 'assets/imported-audio/ui-click/select.wav';
  const filename = path.join(root, destination);
  fs.mkdirSync(path.dirname(filename), { recursive: true });
  fs.writeFileSync(filename, bytes);
  writeImport(destination);
  const asset = { id: 'select', destination, sha256: createHash('sha256').update(bytes).digest('hex'),
    seconds: frames / 44100, sampleRate: 44100, channels: 1, bitDepth: 16 };
  const manifestPath = path.join(root, 'docs/assets/ui-click-audio.json');
  fs.mkdirSync(path.dirname(manifestPath), { recursive: true });
  const assets = [asset];
  const writeManifest = () => fs.writeFileSync(manifestPath, JSON.stringify({ assets }));
  writeManifest();
  return { asset, assets, bytes, filename, manifestPath, writeManifest };
}

module.exports = { uiClickFixture };
