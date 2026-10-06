const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { spawnSync } = require('node:child_process');
const { RATE, fade, statistics, wave, importMetadata } = require('./import-pop-reference.cjs');

const SOURCE_SHA256 = '31cf2565a5670c1e91e598c98ecd6d8da701184211478fe37d12951f5ec1c62d';
const START = 2.190;
const SECONDS = 0.080;
const GAIN = 8;
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');

function importUiClick({ source, root = path.resolve(__dirname, '..'), ffmpeg = 'ffmpeg' }) {
  source = path.resolve(source);
  if (sha256(fs.readFileSync(source)) !== SOURCE_SHA256) {
    throw new Error('The video does not match the reviewed button-click reference. No assets were changed.');
  }
  const decoded = spawnSync(ffmpeg, ['-hide_banner', '-loglevel', 'error', '-i', source,
    '-map', '0:a:0', '-vn', '-ac', '1', '-ar', String(RATE), '-f', 'f32le',
    '-acodec', 'pcm_f32le', 'pipe:1'], { windowsHide: true, maxBuffer: 4 * 1024 * 1024 });
  if (decoded.error) throw decoded.error;
  if (decoded.status !== 0) throw new Error(`FFmpeg extraction failed: ${decoded.stderr.toString()}`);
  const start = Math.round(START * RATE), frames = Math.round(SECONDS * RATE);
  if (decoded.stdout.length < (start + frames) * 4) throw new Error('The source track is incomplete.');
  const samples = Float64Array.from({ length: frames }, (_, index) => decoded.stdout.readFloatLE((start + index) * 4) * GAIN);
  // Preserve the sampled click's attack and decay; taper only the quiet boundaries.
  fade(samples, 0.0005, 0.005);
  const stats = statistics(samples);
  if (stats.peak >= 0.85 || stats.rms < 0.005) throw new Error('Unexpected button-click signal level.');
  const bytes = wave(samples), destination = 'assets/imported-audio/ui-click/select.wav';
  const filename = path.join(root, destination);
  fs.mkdirSync(path.dirname(filename), { recursive: true });
  if (!fs.existsSync(filename) || sha256(fs.readFileSync(filename)) !== sha256(bytes)) fs.writeFileSync(filename, bytes);
  importMetadata(filename, destination);
  const manifest = {
    source: { file: 'sound_effect-select.mp4', suppliedPath: 'C:/uworks/sound_effect-select.mp4',
      sha256: SOURCE_SHA256, seconds: 7.966667, sampleRate: RATE, channels: 1, codec: 'AAC LC',
      creator: 'Duolingo as identified in the supplied screen recording; original sound designer unknown',
      license: 'Not supplied. User requested this recording as the game button-click reference; no independent redistribution license is asserted.',
      status: 'Acquired from the user and extracted locally; compiled into the game pack and embedded in the loading page',
      animations: 'Not applicable to this audio asset' },
    processing: { decoder: 'FFmpeg floating-point AAC decode', gain: GAIN,
      attackSeconds: 0.0005, releaseSeconds: 0.005, runtimeGain: 0.48, runtimePlaybackRate: 1,
      maxSimultaneousUiClicksPerRuntime: 1 },
    assets: [{ id: 'select', destination, sha256: sha256(bytes), seconds: frames / RATE,
      sampleRate: RATE, channels: 1, bitDepth: 16,
      peakDbfs: Number((20 * Math.log10(stats.peak)).toFixed(4)),
      rmsDbfs: Number((20 * Math.log10(stats.rms)).toFixed(4)),
      window: { start: START, seconds: SECONDS } }]
  };
  fs.writeFileSync(path.join(root, 'docs/assets/ui-click-audio.json'), JSON.stringify(manifest, null, 2) + '\n');
  return manifest;
}

if (require.main === module) {
  if (!process.argv[2]) throw new Error('Usage: node tools/import-ui-click.cjs "C:/path/sound_effect-select.mp4"');
  console.log(JSON.stringify(importUiClick({ source: process.argv[2] }), null, 2));
}
module.exports = { SOURCE_SHA256, START, SECONDS, importUiClick };
