const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { execFileSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const source = process.argv[2];
if (!source) throw new Error('Usage: node tools/import-coin-audio.cjs <Kenney RPG Audio/Audio/handleCoins2.ogg>');
const sourceBytes = fs.readFileSync(source);
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
if (hash(sourceBytes) !== '32d79ea56ff22e6d74c4dd541674c95f5adbcff01300b9f99694627e3e9fdbfe') {
  throw new Error('Expected the inspected Kenney RPG Audio handleCoins2.ogg recording.');
}
const decoded = execFileSync('ffmpeg', ['-v', 'error', '-i', source, '-ac', '1', '-ar', '44100', '-f', 'f32le', 'pipe:1']);
const frames = decoded.length / 4;
const samples = new Float32Array(frames);
let peak = 0;
for (let i = 0; i < frames; i++) {
  const envelope = Math.min(1, i / 88, (frames - 1 - i) / 529);
  samples[i] = decoded.readFloatLE(i * 4) * envelope;
  peak = Math.max(peak, Math.abs(samples[i]));
}
if (!Number.isFinite(peak) || peak <= 0 || frames < 4410 || frames > 22050) {
  throw new Error('Expected a short, non-silent Kenney coin recording.');
}
const gain = 0.8 / peak;
const wav = Buffer.alloc(44 + frames * 2);
wav.write('RIFF'); wav.writeUInt32LE(wav.length - 8, 4); wav.write('WAVEfmt ', 8);
wav.writeUInt32LE(16, 16); wav.writeUInt16LE(1, 20); wav.writeUInt16LE(1, 22);
wav.writeUInt32LE(44100, 24); wav.writeUInt32LE(88200, 28);
wav.writeUInt16LE(2, 32); wav.writeUInt16LE(16, 34);
wav.write('data', 36); wav.writeUInt32LE(frames * 2, 40);
for (let i = 0; i < frames; i++) wav.writeInt16LE(Math.round(samples[i] * gain * 32767), 44 + i * 2);
const directory = path.join(root, 'assets/audio/coins');
fs.mkdirSync(directory, { recursive: true });
fs.writeFileSync(path.join(directory, 'collect.wav'), wav);
fs.copyFileSync(path.resolve(path.dirname(source), '../License.txt'), path.join(directory, 'LICENSE.txt'));
const manifest = {
  creator: 'Kenney', pack: 'RPG Audio 1.0', sourceUrl: 'https://kenney.nl/assets/rpg-audio',
  license: 'CC0-1.0', licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
  acquisition: 'Acquired from the user-provided local Kenney Game Assets All-in-1 3.7.0 collection; integrated.',
  source: 'Audio/RPG Audio/Audio/handleCoins2.ogg', sourceSha256: hash(sourceBytes),
  destination: 'assets/audio/coins/collect.wav', sha256: hash(wav),
  sampleRate: 44100, channels: 1, bitDepth: 16, seconds: frames / 44100,
  processing: { downmix: 'mono', resample: 44100, fadeInFrames: 88, fadeOutFrames: 529,
    peak: 0.8, gain, trimming: 'none', pitch: 'unchanged' },
  animations: 'Not applicable; audio only.'
};
fs.writeFileSync(path.join(directory, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(JSON.stringify(manifest, null, 2));
