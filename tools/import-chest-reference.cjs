const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { spawnSync } = require('node:child_process');
const { RATE, fade, statistics, wave, importMetadata } = require('./import-pop-reference.cjs');

const SOURCE_SHA256 = 'e7bfa745776943120f9e7ead27883258eaf511c88f266ca1d62cfce9fa743f0d';
const WINDOWS = [
  { id: 'step', start: 34.215, seconds: 0.24, gain: 1.2, attackSeconds: 0.002, releaseSeconds: 0.020 },
  { id: 'step-detail', start: 36.280, seconds: 0.24, gain: 1.2, attackSeconds: 0.002, releaseSeconds: 0.020 },
  { id: 'step-roll', start: 38.030, seconds: 0.24, gain: 1.2, attackSeconds: 0.002, releaseSeconds: 0.020 },
  { id: 'release', start: 43.950, seconds: 1.50, gain: 2.2, attackSeconds: 0.002, releaseSeconds: 0.050 },
  { id: 'reward', start: 45.580, seconds: 1.20, gain: 2.2, attackSeconds: 0.005, releaseSeconds: 0.080 },
];
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');

function importChestReference({ source, root = path.resolve(__dirname, '..'), ffmpeg = 'ffmpeg' }) {
  source = path.resolve(source);
  if (sha256(fs.readFileSync(source)) !== SOURCE_SHA256) {
    throw new Error('The video does not match the reviewed chest-opening reference. No assets were changed.');
  }
  // Decode the full track before sample-accurate cuts to preserve AAC timing.
  // Only gain and boundary fades are applied; no synthesis or normalization.
  const decoded = spawnSync(ffmpeg, ['-hide_banner', '-loglevel', 'error', '-i', source,
    '-map', '0:a:0', '-vn', '-ac', '1', '-ar', String(RATE), '-f', 'f32le',
    '-acodec', 'pcm_f32le', 'pipe:1'], { windowsHide: true, maxBuffer: 16 * 1024 * 1024 });
  if (decoded.error) throw decoded.error;
  if (decoded.status !== 0) throw new Error(`FFmpeg extraction failed: ${decoded.stderr.toString()}`);
  const rendered = WINDOWS.map(window => {
    const start = Math.round(window.start * RATE), count = Math.round(window.seconds * RATE);
    if (decoded.stdout.length < (start + count) * 4) throw new Error('The source track is incomplete.');
    const samples = Float64Array.from({ length: count }, (_, index) =>
      decoded.stdout.readFloatLE((start + index) * 4) * window.gain);
    fade(samples, window.attackSeconds, window.releaseSeconds);
    const stats = statistics(samples);
    if (stats.peak >= 0.85 || stats.rms < 0.005) throw new Error(`Unexpected signal level: ${window.id}`);
    const bytes = wave(samples);
    return { bytes, id: window.id, destination: `assets/imported-audio/chest-reference/${window.id}.wav`,
      sha256: sha256(bytes), seconds: count / RATE, sampleRate: RATE, channels: 1, bitDepth: 16,
      peakDbfs: Number((20 * Math.log10(stats.peak)).toFixed(4)),
      rmsDbfs: Number((20 * Math.log10(stats.rms)).toFixed(4)),
      window: { start: window.start, seconds: window.seconds },
      processing: { gain: window.gain, attackSeconds: window.attackSeconds, releaseSeconds: window.releaseSeconds } };
  });
  for (const asset of rendered) {
    const destination = path.join(root, asset.destination);
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    if (!fs.existsSync(destination) || sha256(fs.readFileSync(destination)) !== asset.sha256) {
      fs.writeFileSync(destination, asset.bytes);
    }
    importMetadata(destination, asset.destination);
  }
  const manifest = {
    source: { file: 'sound_effect-chest_openning.mp4', suppliedPath: 'C:/uworks/sound_effect-chest_openning.mp4',
      sha256: SOURCE_SHA256, seconds: 53.066667, audioSeconds: 53.038345,
      sampleRate: RATE, channels: 1, codec: 'AAC LC', reviewedWindow: { start: 33, end: 47 },
      creator: 'Duolingo as identified in the supplied screen recording; original sound designer unknown',
      license: 'Not supplied. User supplied the reference for a requested chest-audio adaptation; no independent redistribution license is asserted.',
      status: 'Acquired from the user and extracted locally; shipped inside the compiled game pack only' },
    processing: { decoder: 'FFmpeg floating-point AAC decode', pitchShift: 0, timeStretch: 1,
      normalization: false, compression: false, looping: false },
    assets: rendered.map(({ bytes, ...asset }) => asset),
  };
  fs.mkdirSync(path.join(root, 'docs/assets'), { recursive: true });
  fs.writeFileSync(path.join(root, 'docs/assets/chest-reference-audio.json'), JSON.stringify(manifest, null, 2) + '\n');
  return manifest;
}

if (require.main === module) {
  if (!process.argv[2]) throw new Error('Usage: node tools/import-chest-reference.cjs "C:/path/sound_effect-chest_openning.mp4"');
  console.log(JSON.stringify(importChestReference({ source: process.argv[2] }), null, 2));
}
module.exports = { SOURCE_SHA256, WINDOWS, importChestReference };
