const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { spawnSync } = require('node:child_process');
const { RATE, fade, statistics, wave, importMetadata } = require('./import-pop-reference.cjs');

const SOURCE_SHA256 = '51807fedc4d376ef328570e067ce4f14571ef0e1316dc29278f3592cddb5a48f';
const WINDOWS = [
  { id: 'right', start: 4.320, seconds: 0.820 },
  { id: 'wrong', start: 2.122, seconds: 0.860 },
];
const GAIN = 1.5;
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');

function importPairFeedback({ source, root = path.resolve(__dirname, '..'), ffmpeg = 'ffmpeg' }) {
  source = path.resolve(source);
  if (sha256(fs.readFileSync(source)) !== SOURCE_SHA256) {
    throw new Error('The video does not match the reviewed right/wrong reference. No assets were changed.');
  }
  // Decode the complete, short track before sample-accurate cutting. No pitch,
  // time stretch, synthesis, denoising or independent loudness normalization.
  const decoded = spawnSync(ffmpeg, ['-hide_banner', '-loglevel', 'error', '-i', source,
    '-map', '0:a:0', '-vn', '-ac', '1', '-ar', String(RATE), '-f', 'f32le',
    '-acodec', 'pcm_f32le', 'pipe:1'], { windowsHide: true, maxBuffer: 4 * 1024 * 1024 });
  if (decoded.error) throw decoded.error;
  if (decoded.status !== 0) throw new Error(`FFmpeg extraction failed: ${decoded.stderr.toString()}`);
  const rendered = WINDOWS.map(window => {
    const start = Math.round(window.start * RATE), count = Math.round(window.seconds * RATE);
    if (decoded.stdout.length < (start + count) * 4) throw new Error('The source track is incomplete.');
    const samples = Float64Array.from({ length: count }, (_, index) =>
      decoded.stdout.readFloatLE((start + index) * 4) * GAIN);
    fade(samples, 0.002, 0.020);
    const stats = statistics(samples);
    if (stats.peak >= 0.85 || stats.rms < 0.005) throw new Error(`Unexpected signal level: ${window.id}`);
    const bytes = wave(samples);
    return { bytes, id: window.id, destination: `assets/imported-audio/pair-feedback/${window.id}.wav`,
      sha256: sha256(bytes), seconds: count / RATE, sampleRate: RATE, channels: 1, bitDepth: 16,
      peakDbfs: Number((20 * Math.log10(stats.peak)).toFixed(4)),
      rmsDbfs: Number((20 * Math.log10(stats.rms)).toFixed(4)), window };
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
    source: { file: 'right_and_wrong.mp4', suppliedPath: 'C:/uworks/right_and_wrong.mp4',
      sha256: SOURCE_SHA256, seconds: 7.166667, sampleRate: RATE, channels: 1, codec: 'AAC LC',
      creator: 'Duolingo as identified in the supplied screen recording; original sound designer unknown',
      license: 'Not supplied. User explicitly requested extraction and use in this game; no independent redistribution license is asserted.',
      status: 'Acquired from the user and extracted locally; shipped inside the compiled game pack only' },
    processing: { decoder: 'FFmpeg floating-point AAC decode', gain: GAIN, attackSeconds: 0.002,
      releaseSeconds: 0.020, runtimeGain: 0.48, runtimePlaybackRate: 1, maxSimultaneousAnswers: 1 },
    assets: rendered.map(({ bytes, ...asset }) => asset),
  };
  fs.writeFileSync(path.join(root, 'docs/assets/pair-feedback-audio.json'), JSON.stringify(manifest, null, 2) + '\n');
  return manifest;
}

if (require.main === module) {
  if (!process.argv[2]) throw new Error('Usage: node tools/import-pair-feedback.cjs "C:/path/right_and_wrong.mp4"');
  console.log(JSON.stringify(importPairFeedback({ source: process.argv[2] }), null, 2));
}
module.exports = { SOURCE_SHA256, WINDOWS, importPairFeedback };
