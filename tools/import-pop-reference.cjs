const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { spawnSync } = require('node:child_process');

const SOURCE_SHA256 = '24aede3aa3cc104dcc1c1e28fbfbed82223647fbf90a803ea79ebb4291a5c79e';
const RATE = 44100;
const CUT_OFFSET_SECONDS = 0.032;
const VARIANTS = [
  { id: 'quick', blade: { start: 1.215, seconds: 0.155 }, cut: { start: 2.386, seconds: 0.245 }, bladeGain: 0.78, cutGain: 1.0 },
  { id: 'juicy', blade: { start: 1.215, seconds: 0.145 }, cut: { start: 1.372, seconds: 0.265 }, bladeGain: 0.66, cutGain: 1.0 },
  { id: 'crisp', blade: { start: 1.215, seconds: 0.165 }, cut: { start: 1.466, seconds: 0.285 }, bladeGain: 0.88, cutGain: 0.92 },
];
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');

function statistics(samples) {
  let peak = 0, energy = 0;
  for (const sample of samples) {
    if (!Number.isFinite(sample)) throw new Error('Non-finite decoded sample.');
    peak = Math.max(peak, Math.abs(sample));
    energy += sample * sample;
  }
  return { peak, rms: Math.sqrt(energy / samples.length) };
}

function fade(samples, attackSeconds, releaseSeconds) {
  const attack = Math.round(attackSeconds * RATE);
  const release = Math.round(releaseSeconds * RATE);
  for (let index = 0; index < samples.length; index++) {
    const gain = Math.min(1, index / attack, (samples.length - 1 - index) / release);
    samples[index] *= Math.max(0, gain);
  }
  return samples;
}

function normalize(samples, targetRms, peakLimit) {
  const { peak, rms } = statistics(samples);
  if (rms < 0.0001) throw new Error('The selected source window is silent.');
  const gain = Math.min(targetRms / rms, peakLimit / peak);
  return Float64Array.from(samples, sample => sample * gain);
}

function decode(source, window, highpass, ffmpeg) {
  // Decode directly to floating point so AAC overshoot is not clipped before
  // filtering and gain staging. The mono source has no separable stereo stems.
  const result = spawnSync(ffmpeg, [
    '-hide_banner', '-loglevel', 'error', '-ss', String(window.start), '-i', source,
    '-t', String(window.seconds), '-vn', '-af', `highpass=f=${highpass},lowpass=f=8000`,
    '-ac', '1', '-ar', String(RATE), '-f', 'f32le', '-acodec', 'pcm_f32le', 'pipe:1',
  ], { windowsHide: true, maxBuffer: 1024 * 1024 });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`FFmpeg extraction failed: ${result.stderr.toString()}`);
  const frames = result.stdout.length / 4;
  if (!Number.isInteger(frames) || Math.abs(frames - Math.round(window.seconds * RATE)) > 1) {
    throw new Error('The extracted window has an unexpected length.');
  }
  return Float64Array.from({ length: frames }, (_, index) => result.stdout.readFloatLE(index * 4));
}

function wave(samples) {
  const bytes = Buffer.alloc(44 + samples.length * 2);
  bytes.write('RIFF', 0); bytes.writeUInt32LE(bytes.length - 8, 4); bytes.write('WAVEfmt ', 8);
  bytes.writeUInt32LE(16, 16); bytes.writeUInt16LE(1, 20); bytes.writeUInt16LE(1, 22);
  bytes.writeUInt32LE(RATE, 24); bytes.writeUInt32LE(RATE * 2, 28);
  bytes.writeUInt16LE(2, 32); bytes.writeUInt16LE(16, 34);
  bytes.write('data', 36); bytes.writeUInt32LE(samples.length * 2, 40);
  for (let index = 0; index < samples.length; index++) {
    bytes.writeInt16LE(Math.round(Math.max(-1, Math.min(1, samples[index])) * 32767), 44 + index * 2);
  }
  return bytes;
}

function importMetadata(destination, relative) {
  const imported = destination + '.import';
  const previous = fs.existsSync(imported) ? fs.readFileSync(imported, 'utf8') : '';
  const uid = previous.match(/^uid="[^"]+"$/m)?.[0];
  const resourcePath = `res://${relative}`;
  const sample = `res://.godot/imported/${path.basename(destination)}-${createHash('md5').update(resourcePath).digest('hex')}.sample`;
  const metadata = `[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\n${uid ? uid + '\n' : ''}path="${sample}"\n\n` +
    `[deps]\n\nsource_file="${resourcePath}"\ndest_files=["${sample}"]\n\n[params]\n\n` +
    'force/8_bit=false\nforce/mono=false\nforce/max_rate=false\nforce/max_rate_hz=44100\n' +
    'edit/trim=false\nedit/normalize=false\nedit/loop_mode=0\nedit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=0\n';
  if (previous.replace(/\r\n/g, '\n') !== metadata) fs.writeFileSync(imported, metadata);
}

function importReference({ source, root = path.resolve(__dirname, '..'), ffmpeg = 'ffmpeg' }) {
  source = path.resolve(source);
  if (sha256(fs.readFileSync(source)) !== SOURCE_SHA256) {
    throw new Error('The video does not match the reviewed reference. No assets were changed.');
  }
  // Build every variant before touching any destination. All layers are baked
  // together so browser scheduling cannot separate the blade from the impact.
  const rendered = VARIANTS.map(variant => {
    const blade = normalize(fade(decode(source, variant.blade, 230, ffmpeg), 0.002, 0.032), 0.10, 0.70);
    const cut = normalize(fade(decode(source, variant.cut, 170, ffmpeg), 0.002, 0.060), 0.16, 0.82);
    const offset = Math.round(CUT_OFFSET_SECONDS * RATE);
    let mixed = new Float64Array(Math.max(blade.length, offset + cut.length));
    for (let index = 0; index < blade.length; index++) mixed[index] += blade[index] * variant.bladeGain;
    for (let index = 0; index < cut.length; index++) mixed[index + offset] += cut[index] * variant.cutGain;
    mixed = normalize(mixed, 0.125, 0.62);
    const bytes = wave(mixed);
    const stats = statistics(Array.from({ length: mixed.length }, (_, index) => bytes.readInt16LE(44 + index * 2) / 32768));
    return { bytes, id: variant.id, destination: `assets/imported-audio/pop-reference/${variant.id}.wav`,
      sha256: sha256(bytes), seconds: mixed.length / RATE, sampleRate: RATE, channels: 1, bitDepth: 16,
      peakDbfs: Number((20 * Math.log10(stats.peak)).toFixed(4)), rmsDbfs: Number((20 * Math.log10(stats.rms)).toFixed(4)),
      blade: variant.blade, cut: variant.cut, bladeGain: variant.bladeGain, cutGain: variant.cutGain,
      cutOffsetSeconds: CUT_OFFSET_SECONDS };
  });
  for (const asset of rendered) {
    const destination = path.join(root, asset.destination);
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    if (!fs.existsSync(destination) || sha256(fs.readFileSync(destination)) !== asset.sha256) fs.writeFileSync(destination, asset.bytes);
    importMetadata(destination, asset.destination);
  }
  const manifest = {
    source: { file: 'fruit_ninja.mp4', sha256: SOURCE_SHA256, seconds: 56.8, sampleRate: RATE, channels: 1, codec: 'AAC LC' },
    note: 'User-provided gameplay recording. These are filtered excerpts of one mixed mono track, not isolated original stems. Raw video, extracted audio and imports remain Git-ignored; the local Web export bundles the three finished hits.',
    processing: { decoder: 'FFmpeg floating-point AAC decode', bladeHighpassHz: 230, cutHighpassHz: 170, lowpassHz: 8000,
      attackSeconds: 0.002, bladeReleaseSeconds: 0.032, cutReleaseSeconds: 0.060,
      targetRms: 0.125, peakLimit: 0.62, runtimeGain: 0.24, maxSimultaneousHits: 3, runtimePlaybackRate: 1 },
    assets: rendered.map(({ bytes, ...asset }) => asset),
  };
  const manifestPath = path.join(root, 'docs/assets/voice-pop-reference-audio.json');
  fs.mkdirSync(path.dirname(manifestPath), { recursive: true });
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n');
  return manifest;
}

if (require.main === module) {
  if (!process.argv[2]) throw new Error('Usage: node tools/import-pop-reference.cjs "C:/path/fruit_ninja.mp4"');
  const manifest = importReference({ source: process.argv[2] });
  console.log(`Imported ${manifest.assets.length} premixed reference hits (${manifest.assets.map(asset => Math.round(asset.seconds * 1000)).join(', ')} ms).`);
}

module.exports = { SOURCE_SHA256, RATE, VARIANTS, CUT_OFFSET_SECONDS, statistics, fade, normalize, wave, importReference };
