const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');

const root = path.resolve(__dirname, '..');
const fruits = ['apple', 'orange', 'watermelon', 'pineapple', 'banana', 'strawberry', 'peach', 'coconut'];
const source = path.resolve(process.argv[2] || 'D:/uwork/AssetsSource/AIGenSFX/FruitSlice_Arcade_05/wav');
const manifest = JSON.parse(fs.readFileSync(path.join(source, '..', 'manifest.json'), 'utf8'));
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');

// Validate the complete selected set before copying any files. Previews and stems
// intentionally never enter the hit-sound pool.
const assets = fruits.map(fruit => {
  const relative = `${fruit}/${fruit}_slice_02.wav`;
  const bytes = fs.readFileSync(path.join(source, relative));
  const entry = manifest.assets.find(asset => asset.file === `wav/${relative}`);
  if (!entry || entry.sha256 !== sha256(bytes)) throw new Error(`Source hash mismatch: ${relative}`);
  if (bytes.toString('ascii', 0, 4) !== 'RIFF' || bytes.toString('ascii', 8, 12) !== 'WAVE') {
    throw new Error(`Not a WAV: ${relative}`);
  }
  let format, data;
  for (let offset = 12; offset + 8 <= bytes.length;) {
    const id = bytes.toString('ascii', offset, offset + 4), size = bytes.readUInt32LE(offset + 4);
    if (offset + 8 + size > bytes.length) throw new Error(`Truncated WAV: ${relative}`);
    if (id === 'fmt ') format = bytes.subarray(offset + 8, offset + 8 + size);
    if (id === 'data') data = bytes.subarray(offset + 8, offset + 8 + size);
    offset += 8 + size + (size % 2);
  }
  if (!format || format.length < 16 || !data || format.readUInt16LE(0) !== 1 ||
      format.readUInt16LE(2) !== 2 || format.readUInt32LE(4) !== 48000 || format.readUInt16LE(14) !== 24 ||
      data.length % 6 !== 0) throw new Error(`Expected stereo 48 kHz PCM24: ${relative}`);
  const seconds = data.length / 6 / 48000;
  if (seconds < 0.25 || seconds > 0.4) throw new Error(`Unexpected hit duration: ${relative}`);
  let peak = 0;
  for (let offset = 0; offset < data.length; offset += 3) peak = Math.max(peak, Math.abs(data.readIntLE(offset, 3) / 8388608));
  if (peak === 0 || peak >= 0.9) throw new Error(`Silent or overly loud hit: ${relative}`);
  return { bytes, id: fruit, source: relative, destination: `assets/imported-audio/pop-slices/${fruit}.wav`,
    sha256: sha256(bytes), seconds, sampleRate: 48000, channels: 2, bitDepth: 24,
    peakDbfs: Number((20 * Math.log10(peak)).toFixed(3)) };
});
if (new Set(assets.map(asset => asset.sha256)).size !== fruits.length) throw new Error('Duplicate slice sounds');
for (const asset of assets) {
  const destination = path.join(root, asset.destination);
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  if (!fs.existsSync(destination) || sha256(fs.readFileSync(destination)) !== asset.sha256) {
    fs.writeFileSync(destination, asset.bytes);
  }
  // These tiny transients use uncompressed Godot PCM, with no trimming,
  // normalization, rate conversion or looping. Preserve an existing UID.
  const imported = destination + '.import';
  const previous = fs.existsSync(imported) ? fs.readFileSync(imported, 'utf8') : '';
  const uid = previous.match(/^uid="[^"]+"$/m)?.[0];
  const resourcePath = 'res://' + asset.destination;
  const sample = `res://.godot/imported/${asset.id}.wav-${createHash('md5').update(resourcePath).digest('hex')}.sample`;
  const metadata = `[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\n${uid ? uid + '\n' : ''}path="${sample}"\n\n` +
    `[deps]\n\nsource_file="${resourcePath}"\ndest_files=["${sample}"]\n\n[params]\n\n` +
    'force/8_bit=false\nforce/mono=false\nforce/max_rate=false\nforce/max_rate_hz=44100\n' +
    'edit/trim=false\nedit/normalize=false\nedit/loop_mode=0\nedit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=0\n';
  if (previous.replace(/\r\n/g, '\n') !== metadata) fs.writeFileSync(imported, metadata);
}
const record = { pack: 'FruitSlice_Arcade_05', sourceDirectory: source.replace(/\\/g, '/'),
  note: 'User-provided finished mixes copied unchanged. Raw WAVs and Godot imports stay Git-ignored; the Web game bundles all eight.',
  assets: assets.map(({ bytes, ...asset }) => asset) };
fs.writeFileSync(path.join(root, 'docs/assets/voice-pop-random-slices.json'), JSON.stringify(record, null, 2) + '\n');
console.log(`Imported ${assets.length} distinct slice sounds unchanged (${assets.reduce((total, asset) => total + asset.bytes.length, 0)} bytes).`);
