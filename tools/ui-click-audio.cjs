const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');

function readUiClickAudio(root) {
  const source = 'assets/imported-audio/ui-click/select.wav';
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'docs/assets/ui-click-audio.json'), 'utf8'));
  const asset = manifest.assets?.[0];
  if (!Array.isArray(manifest.assets) || manifest.assets.length !== 1 || !asset ||
      asset.id !== 'select' || asset.destination !== source || !/^[a-f0-9]{64}$/.test(asset.sha256) ||
      asset.sampleRate !== 44100 || asset.channels !== 1 || asset.bitDepth !== 16 ||
      !Number.isFinite(asset.seconds) || asset.seconds < 0.03 || asset.seconds > 0.15) {
    throw new Error('Invalid UI click audio manifest: one short mono PCM16 select recording is required.');
  }
  const present = fs.readdirSync(path.dirname(path.join(root, source)))
    .filter(name => name.toLowerCase().endsWith('.wav')).sort();
  if (JSON.stringify(present) !== JSON.stringify(['select.wav'])) throw new Error('UI click audio requires exactly select.wav.');
  const bytes = fs.readFileSync(path.join(root, source));
  if (createHash('sha256').update(bytes).digest('hex') !== asset.sha256) throw new Error('UI click audio hash mismatch.');
  if (bytes.length < 44 || bytes.toString('ascii', 0, 4) !== 'RIFF' ||
      bytes.readUInt32LE(4) !== bytes.length - 8 || bytes.toString('ascii', 8, 16) !== 'WAVEfmt ' ||
      bytes.readUInt32LE(16) !== 16 || bytes.readUInt16LE(20) !== 1 || bytes.readUInt16LE(22) !== 1 ||
      bytes.readUInt32LE(24) !== 44100 || bytes.readUInt32LE(28) !== 88200 ||
      bytes.readUInt16LE(32) !== 2 || bytes.readUInt16LE(34) !== 16 ||
      bytes.toString('ascii', 36, 40) !== 'data' || bytes.readUInt32LE(40) !== bytes.length - 44 ||
      (bytes.length - 44) % 2 || Math.abs((bytes.length - 44) / 88200 - asset.seconds) > 1 / 44100) {
    throw new Error('Invalid mono PCM16 UI click WAV.');
  }
  return { asset, bytes };
}

module.exports = { readUiClickAudio };
