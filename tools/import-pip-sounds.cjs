const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');

const root = path.resolve(__dirname, '..');
const source = path.resolve(process.argv[2] || 'D:/uwork/AssetsSource/AIGenSFX/duck_gaga');
const names = ['duck_double_01_bouncy.wav', 'duck_double_03_derpy.wav', 'duck_quack_innocent_deep_short_04.wav'];
const assets = names.map(name => {
  const bytes = fs.readFileSync(path.join(source, name));
  if (bytes.toString('ascii', 0, 4) !== 'RIFF' || bytes.toString('ascii', 8, 12) !== 'WAVE') throw new Error(`Invalid WAV: ${name}`);
  let format, pcm;
  for (let offset = 12; offset + 8 <= bytes.length;) {
    const id = bytes.toString('ascii', offset, offset + 4), size = bytes.readUInt32LE(offset + 4);
    if (offset + 8 + size > bytes.length) throw new Error(`Truncated WAV: ${name}`);
    if (id === 'fmt ') format = bytes.subarray(offset + 8, offset + 8 + size);
    if (id === 'data') pcm = bytes.subarray(offset + 8, offset + 8 + size);
    offset += 8 + size + size % 2;
  }
  if (!format || format.length < 16 || !pcm || format.readUInt16LE(0) !== 1 ||
      format.readUInt16LE(2) !== 1 || format.readUInt32LE(4) !== 48000 || format.readUInt16LE(14) !== 24 || pcm.length % 3) {
    throw new Error(`Expected mono 48 kHz PCM24: ${name}`);
  }
  const seconds = pcm.length / 3 / 48000;
  let peak = 0;
  for (let i = 0; i < pcm.length; i += 3) peak = Math.max(peak, Math.abs(pcm.readIntLE(i, 3) / 8388608));
  if (seconds < 0.1 || seconds > 0.6 || peak < 0.01 || peak >= 0.9) throw new Error(`Invalid greeting duration/level: ${name}`);
  return { bytes, file: `assets/audio/pip/${name}`, seconds, sampleRate: 48000, channels: 1, bitDepth: 24,
    sha256: createHash('sha256').update(bytes).digest('hex'), peakDbfs: Number((20 * Math.log10(peak)).toFixed(3)) };
});
if (new Set(assets.map(asset => asset.sha256)).size !== names.length) throw new Error('Duplicate Pip sounds');
for (const asset of assets) {
  const destination = path.join(root, asset.file);
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.writeFileSync(destination, asset.bytes);
}
fs.writeFileSync(path.join(root, 'docs/assets/pip-sounds.json'), JSON.stringify({
  sourceDirectory: source.replaceAll('\\', '/'),
  note: 'User-selected finished WAVs copied unchanged and tracked in Git. No normalization, trimming or pitch changes.',
  assets: assets.map(({ bytes, ...asset }) => asset)
}, null, 2) + '\n');
console.log(`Imported ${assets.length} Pip sounds unchanged (${assets.reduce((sum, asset) => sum + asset.bytes.length, 0)} bytes).`);
