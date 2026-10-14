const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { execFileSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const source = process.argv[2];
if (!source) throw new Error('Usage: node tools/import-fragment-audio.cjs <Kenney All-in-1/Audio>');
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const sampleRate = 44100;
const fadeInFrames = 44;
const fadeOutFrames = 529;
const targetPeak = 0.70;
const directory = path.join(root, 'assets/audio/fragments');
const sources = [
  {
    id: 'appear', file: 'drop_002.ogg',
    sha256: '978c28bfc517f54fc956f7491e33f37802809d938933bf5071f39423089554d3',
    trigger: 'A chest fragment first becomes visible at the start of its flight.',
  },
  {
    id: 'arrive', file: 'glass_001.ogg',
    sha256: '12a8b47dc2d6351ddf8b8524c29ea487131e4d0152021c9603f3b5fcac9c0491',
    trigger: 'A chest fragment reaches the receiving chest or its Treasure target jelly.',
  },
];

function wavFromPcm(pcm) {
  const wav = Buffer.alloc(44 + pcm.length);
  wav.write('RIFF'); wav.writeUInt32LE(wav.length - 8, 4); wav.write('WAVEfmt ', 8);
  wav.writeUInt32LE(16, 16); wav.writeUInt16LE(1, 20); wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(sampleRate, 24); wav.writeUInt32LE(sampleRate * 2, 28);
  wav.writeUInt16LE(2, 32); wav.writeUInt16LE(16, 34);
  wav.write('data', 36); wav.writeUInt32LE(pcm.length, 40); pcm.copy(wav, 44);
  return wav;
}

function importSettings(destination) {
  const imported = path.join(root, destination + '.import');
  const previous = fs.existsSync(imported) ? fs.readFileSync(imported, 'utf8') : '';
  const uid = previous.match(/^uid="[^"]+"$/m)?.[0];
  const resourcePath = 'res://' + destination;
  const sample = `res://.godot/imported/${path.basename(destination)}-${createHash('md5').update(resourcePath).digest('hex')}.sample`;
  const metadata = `[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\n${uid ? uid + '\n' : ''}path="${sample}"\n\n` +
    `[deps]\n\nsource_file="${resourcePath}"\ndest_files=["${sample}"]\n\n[params]\n\n` +
    'force/8_bit=false\nforce/mono=false\nforce/max_rate=false\nforce/max_rate_hz=44100\n' +
    'edit/trim=false\nedit/normalize=false\nedit/loop_mode=0\nedit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=0\n';
  if (previous.replace(/\r\n/g, '\n') !== metadata) fs.writeFileSync(imported, metadata);
}

// Validate all acquired inputs before replacing any integrated asset.
const licensePath = path.join(source, 'Interface Sounds/License.txt');
const license = fs.readFileSync(licensePath);
if (!license.toString('utf8').includes('Creative Commons Zero, CC0')) {
  throw new Error('Expected the original Kenney Interface Sounds CC0 license.');
}
for (const entry of sources) {
  entry.relative = `Interface Sounds/Audio/${entry.file}`;
  entry.path = path.join(source, entry.relative);
  if (hash(fs.readFileSync(entry.path)) !== entry.sha256) {
    throw new Error(`Expected the inspected Kenney Interface Sounds recording: ${entry.file}`);
  }
}

const rendered = sources.map(entry => {
  // OGG decoding can exceed full scale; retain float headroom until final gain.
  const decoded = execFileSync('ffmpeg', ['-v', 'error', '-i', entry.path,
    '-ac', '1', '-ar', String(sampleRate), '-f', 'f32le', 'pipe:1']);
  const frames = decoded.length / 4;
  if (!Number.isInteger(frames) || frames < 4410 || frames > 22050) {
    throw new Error(`Expected a short fragment recording: ${entry.file}`);
  }
  const samples = new Float64Array(frames);
  let peak = 0;
  let sourcePeak = 0;
  for (let i = 0; i < frames; i++) {
    const value = decoded.readFloatLE(i * 4);
    if (!Number.isFinite(value)) throw new Error(`Invalid decoded sample: ${entry.file}`);
    sourcePeak = Math.max(sourcePeak, Math.abs(value));
    samples[i] = value * Math.min(1, i / fadeInFrames, (frames - 1 - i) / fadeOutFrames);
    peak = Math.max(peak, Math.abs(samples[i]));
  }
  if (peak <= 0) throw new Error(`Silent fragment recording: ${entry.file}`);
  const gain = targetPeak / peak;
  const pcm = Buffer.alloc(frames * 2);
  let outputPeak = 0;
  let squared = 0;
  let clipped = 0;
  let onset = frames;
  let tail = 0;
  for (let i = 0; i < frames; i++) {
    const integer = Math.round(samples[i] * gain * 32767);
    pcm.writeInt16LE(integer, i * 2);
    const value = integer / 32768;
    outputPeak = Math.max(outputPeak, Math.abs(value));
    squared += value * value;
    if (Math.abs(integer) >= 32767) clipped++;
    if (Math.abs(value) >= targetPeak * 0.04) {
      onset = Math.min(onset, i);
      tail = i;
    }
  }
  const wav = wavFromPcm(pcm);
  return { pcm, wav, record: {
    id: entry.id, source: entry.relative, sourceSha256: entry.sha256,
    destination: `assets/audio/fragments/${entry.id}.wav`, sha256: hash(wav),
    trigger: entry.trigger, bytes: wav.length, frames, seconds: frames / sampleRate,
    sampleRate, channels: 1, bitDepth: 16,
    processing: { decoder: 'FFmpeg float decode', downmix: 'mono', resample: sampleRate,
      sourcePeak, fadeInFrames, fadeOutFrames, targetPeak, gain,
      trimming: 'none', pitch: 'unchanged', filtering: 'none', generatedLayers: 'none' },
    review: { peak: outputPeak, peakDbfs: 20 * Math.log10(outputPeak),
      rms: Math.sqrt(squared / frames), clippedSamples: clipped,
      onsetAboveFourPercentPeakSeconds: onset / sampleRate,
      lastAboveFourPercentPeakSeconds: tail / sampleRate },
  } };
});

fs.mkdirSync(directory, { recursive: true });
for (const item of rendered) {
  fs.writeFileSync(path.join(root, item.record.destination), item.wav);
  importSettings(item.record.destination);
}
fs.writeFileSync(path.join(directory, 'LICENSE.txt'), license);
const manifest = {
  creator: 'Kenney', pack: 'Interface Sounds 1.0',
  sourceUrl: 'https://kenney.nl/assets/interface-sounds',
  license: 'CC0-1.0', licenseUrl: 'https://creativecommons.org/publicdomain/zero/1.0/',
  licenseFile: 'assets/audio/fragments/LICENSE.txt', licenseSha256: hash(license),
  acquisition: 'Acquired from the user-provided local Kenney Game Assets All-in-1 3.7.0 collection; processed and integrated. Not source previews.',
  animations: 'Not applicable; audio only.',
  review: 'Source identity, license, decoded waveform, duration, spectrum and output headroom inspected. No acoustic audition.',
  importer: 'tools/import-fragment-audio.cjs',
  assets: rendered.map(item => item.record),
};
fs.writeFileSync(path.join(directory, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');

const audition = path.join(root, 'build/fragment-audio-audition.wav');
fs.mkdirSync(path.dirname(audition), { recursive: true });
const gap = Buffer.alloc(Math.round(0.65 * sampleRate) * 2);
fs.writeFileSync(audition, wavFromPcm(Buffer.concat([rendered[0].pcm, gap, rendered[1].pcm])));
console.log(JSON.stringify({ ...manifest, audition: 'build/fragment-audio-audition.wav' }, null, 2));
