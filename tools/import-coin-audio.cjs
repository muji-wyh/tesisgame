const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { execFileSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const release = process.argv[2] === '--release';
const source = process.argv[release ? 3 : 2];
if (!source) throw new Error('Usage: node tools/import-coin-audio.cjs <Kenney RPG Audio/Audio/handleCoins2.ogg> | --release <Kenney Retro Sounds 2/Audio/coin5.ogg>');
const sourceBytes = fs.readFileSync(source);
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const expectedHash = release ? '73ce21b89de7eca2b7a7cac2e8faed4b20c9699e12c13d96c9851bb7b85edf59' :
  '32d79ea56ff22e6d74c4dd541674c95f5adbcff01300b9f99694627e3e9fdbfe';
if (hash(sourceBytes) !== expectedHash) {
  throw new Error(`Expected the inspected Kenney ${release ? 'Retro Sounds 2 coin5.ogg' : 'RPG Audio handleCoins2.ogg'} recording.`);
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
// The release is tonal and denser than the physical deposit; match its RMS
// conservatively instead of making both recordings equally high at the peak.
const targetPeak = release ? 0.18 : 0.8;
const gain = targetPeak / peak;
const wav = Buffer.alloc(44 + frames * 2);
wav.write('RIFF'); wav.writeUInt32LE(wav.length - 8, 4); wav.write('WAVEfmt ', 8);
wav.writeUInt32LE(16, 16); wav.writeUInt16LE(1, 20); wav.writeUInt16LE(1, 22);
wav.writeUInt32LE(44100, 24); wav.writeUInt32LE(88200, 28);
wav.writeUInt16LE(2, 32); wav.writeUInt16LE(16, 34);
wav.write('data', 36); wav.writeUInt32LE(frames * 2, 40);
for (let i = 0; i < frames; i++) wav.writeInt16LE(Math.round(samples[i] * gain * 32767), 44 + i * 2);
const directory = path.join(root, 'assets/audio/coins');
fs.mkdirSync(directory, { recursive: true });
fs.writeFileSync(path.join(directory, release ? 'release.wav' : 'collect.wav'), wav);
fs.copyFileSync(path.resolve(path.dirname(source), '../License.txt'), path.join(directory, release ? 'LICENSE-Retro-Sounds-2.txt' : 'LICENSE.txt'));
const manifest = {
  creator: 'Kenney', pack: release ? 'Retro Sounds 2 1.0' : 'RPG Audio 1.0',
  sourceUrl: release ? 'https://kenney.nl' : 'https://kenney.nl/assets/rpg-audio',
  license: 'CC0-1.0', licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
  acquisition: 'Acquired from the user-provided local Kenney Game Assets All-in-1 3.7.0 collection; integrated.',
  source: release ? 'Audio/Retro Sounds 2/Audio/coin5.ogg' : 'Audio/RPG Audio/Audio/handleCoins2.ogg', sourceSha256: hash(sourceBytes),
  destination: `assets/audio/coins/${release ? 'release' : 'collect'}.wav`, sha256: hash(wav),
  sampleRate: 44100, channels: 1, bitDepth: 16, seconds: frames / 44100,
  processing: { downmix: 'mono', resample: 44100, fadeInFrames: 88, fadeOutFrames: 529,
    peak: targetPeak, gain, trimming: 'none', pitch: 'unchanged' },
  animations: 'Not applicable; audio only.'
};
if (release) {
  let squared = 0;
  let clipped = 0;
  let onset = frames;
  let tail = 0;
  for (let i = 0; i < frames; i++) {
    const value = wav.readInt16LE(44 + i * 2) / 32768;
    squared += value * value;
    if (Math.abs(value) >= 32767 / 32768) clipped++;
    if (Math.abs(value) >= targetPeak * 0.04) {
      onset = Math.min(onset, i);
      tail = i;
    }
  }
  manifest.licenseFile = 'assets/audio/coins/LICENSE-Retro-Sounds-2.txt';
  manifest.review = { rms: Math.sqrt(squared / frames), clippedSamples: clipped,
    onsetAboveFourPercentPeakSeconds: onset / 44100, lastAboveFourPercentPeakSeconds: tail / 44100,
    method: 'Source identity, decoded waveform, timing and spectrum inspected; no acoustic audition.' };
}
fs.writeFileSync(path.join(directory, release ? 'release-manifest.json' : 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(JSON.stringify(manifest, null, 2));
