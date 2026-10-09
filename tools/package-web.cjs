const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { brotliCompressSync, brotliDecompressSync, constants } = require('node:zlib');
const { patchWebEngine } = require('./patch-web-engine.cjs');
const { readUiClickAudio } = require('./ui-click-audio.cjs');
const { readChestReferenceAudio } = require('./chest-reference-audio.cjs');

const THEMES = ['spring', 'summer', 'autumn', 'winter', 'ocean', 'space', 'jungle', 'candy'];
const CHEST_CUES = ['press', 'charge', 'cancel', 'opening', 'unlock', 'settle'];
const POP_REFERENCE_IDS = ['quick', 'juicy', 'crisp'];

function compressWebAsset(bytes, candidates = []) {
  for (const filename of candidates) {
    try {
      const compressed = fs.readFileSync(filename);
      // Filename hashes are only a lookup hint. Verify the complete decoded
      // content before reusing a sidecar, including caches from interrupted builds.
      const decoded = brotliDecompressSync(compressed, { maxOutputLength: bytes.length + 1, info: true });
      if (decoded.buffer.equals(bytes) && decoded.engine.bytesWritten === compressed.length) return compressed;
    } catch (error) {
      if (error.code === 'EACCES' || error.code === 'EPERM') throw error;
      // Missing, truncated or stale caches are disposable; rebuild them below.
    }
  }
  return brotliCompressSync(bytes, { params: { [constants.BROTLI_PARAM_QUALITY]: 11 } });
}

function importedAudio(root, source) {
  const metadata = fs.readFileSync(path.join(root, ...`${source}.import`.split('/')), 'utf8');
  const imported = metadata.match(/^path="(res:\/\/\.godot\/imported\/[^"/\\]+\.sample)"$/m)?.[1];
  if (!imported) throw new Error(`Import ${source} before packaging required audio.`);
  const bytes = fs.readFileSync(path.join(root, ...imported.slice(6).split('/')));
  if (!['RSRC', 'RSCC'].includes(bytes.subarray(0, 4).toString('ascii'))) {
    throw new Error(`Expected an imported Godot audio resource: ${imported}`);
  }
  return { source: `res://${source}`, imported, bytes };
}

function collectPopReferenceAudio(root) {
  const directory = path.join(root, 'assets/imported-audio/pop-reference');
  if (!fs.existsSync(directory)) return [];
  if (!fs.statSync(directory).isDirectory()) throw new Error('The optional Voice Pop reference bank must be a directory.');
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'docs/assets/voice-pop-reference-audio.json'), 'utf8'));
  if (!Array.isArray(manifest.assets) || manifest.assets.length !== POP_REFERENCE_IDS.length) {
    throw new Error('The Voice Pop reference bank must declare all three variants.');
  }
  const ids = [...POP_REFERENCE_IDS, 'launch'];
  const expected = ids.map(id => `${id}.wav`).sort();
  const present = fs.readdirSync(directory).filter(name => name.toLowerCase().endsWith('.wav')).sort();
  if (JSON.stringify(present) !== JSON.stringify(expected)) {
    throw new Error('The optional Voice Pop reference bank is incomplete or has unexpected WAVs; provide all three hit variants and the separate launch, or remove the bank.');
  }
  return [...manifest.assets, manifest.launch].map((asset, index) => {
    const id = ids[index];
    const source = `assets/imported-audio/pop-reference/${id}.wav`;
    if (!asset || asset.id !== id || asset.destination !== source ||
        !/^[a-f0-9]{64}$/.test(asset.sha256) || asset.sampleRate !== 44100 ||
        asset.channels !== 1 || asset.bitDepth !== 16 ||
        !Number.isFinite(asset.seconds) || asset.seconds < (id === 'launch' ? 0.10 : 0.20) || asset.seconds > (id === 'launch' ? 0.30 : 0.50)) {
      throw new Error(`Invalid Voice Pop reference manifest entry: ${id}`);
    }
    const bytes = fs.readFileSync(path.join(root, source));
    if (createHash('sha256').update(bytes).digest('hex') !== asset.sha256) {
      throw new Error(`Voice Pop reference audio hash mismatch: ${source}`);
    }
    const invalid = () => { throw new Error(`Invalid mono PCM16 Voice Pop reference WAV: ${source}`); };
    if (bytes.length < 44 || bytes.toString('ascii', 0, 4) !== 'RIFF' ||
        bytes.toString('ascii', 8, 12) !== 'WAVE' || bytes.readUInt32LE(4) !== bytes.length - 8) invalid();
    let format, samples;
    for (let offset = 12; offset < bytes.length;) {
      if (offset + 8 > bytes.length) invalid();
      const name = bytes.toString('ascii', offset, offset + 4);
      const length = bytes.readUInt32LE(offset + 4);
      const end = offset + 8 + length;
      if (end + length % 2 > bytes.length) invalid();
      if (name === 'fmt ') {
        if (format || length < 16) invalid();
        format = bytes.subarray(offset + 8, end);
      }
      if (name === 'data') {
        if (samples || length === 0 || length % 2) invalid();
        samples = bytes.subarray(offset + 8, end);
      }
      offset = end + length % 2;
    }
    if (!format || !samples || format.readUInt16LE(0) !== 1 || format.readUInt16LE(2) !== 1 ||
        format.readUInt32LE(4) !== 44100 || format.readUInt32LE(8) !== 88200 ||
        format.readUInt16LE(12) !== 2 || format.readUInt16LE(14) !== 16 ||
        Math.abs(samples.length / 88200 - asset.seconds) > 1 / 44100) invalid();
    return importedAudio(root, source);
  });
}

function collectPairFeedbackAudio(root) {
  const directory = path.join(root, 'assets/imported-audio/pair-feedback');
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'docs/assets/pair-feedback-audio.json'), 'utf8'));
  const ids = ['right', 'wrong'];
  if (!Array.isArray(manifest.assets) || manifest.assets.length !== ids.length) {
    throw new Error('Pair feedback must declare the required right and wrong recordings.');
  }
  const present = fs.readdirSync(directory).filter(name => name.toLowerCase().endsWith('.wav')).sort();
  if (JSON.stringify(present) !== JSON.stringify(ids.map(id => `${id}.wav`))) {
    throw new Error('Pair feedback requires exactly the right and wrong recordings.');
  }
  return manifest.assets.map((asset, index) => {
    const id = ids[index], source = `assets/imported-audio/pair-feedback/${id}.wav`;
    if (!asset || asset.id !== id || asset.destination !== source || !/^[a-f0-9]{64}$/.test(asset.sha256) ||
        asset.sampleRate !== 44100 || asset.channels !== 1 || asset.bitDepth !== 16 ||
        !Number.isFinite(asset.seconds) || asset.seconds < 0.2 || asset.seconds > 2) {
      throw new Error(`Invalid pair feedback manifest entry: ${id}`);
    }
    const bytes = fs.readFileSync(path.join(root, source));
    if (createHash('sha256').update(bytes).digest('hex') !== asset.sha256) {
      throw new Error(`Pair feedback audio hash mismatch: ${source}`);
    }
    if (bytes.length < 44 || bytes.toString('ascii', 0, 4) !== 'RIFF' ||
        bytes.readUInt32LE(4) !== bytes.length - 8 || bytes.toString('ascii', 8, 16) !== 'WAVEfmt ' ||
        bytes.readUInt32LE(16) !== 16 || bytes.readUInt16LE(20) !== 1 || bytes.readUInt16LE(22) !== 1 ||
        bytes.readUInt32LE(24) !== 44100 || bytes.readUInt32LE(28) !== 88200 ||
        bytes.readUInt16LE(32) !== 2 || bytes.readUInt16LE(34) !== 16 ||
        bytes.toString('ascii', 36, 40) !== 'data' || bytes.readUInt32LE(40) !== bytes.length - 44 ||
        (bytes.length - 44) % 2 || Math.abs((bytes.length - 44) / 88200 - asset.seconds) > 1 / 44100) {
      throw new Error(`Invalid mono PCM16 pair feedback WAV: ${source}`);
    }
    return importedAudio(root, source);
  });
}

function collectChestReferenceAudio(root) {
  return readChestReferenceAudio(root).map(({ asset }) => importedAudio(root, asset.destination));
}

// These formerly separate downloads are required resources in the game pack.
// Keep an explicit chest inventory so a missing cue cannot silently pass export.
function collectRequiredAudio(root) {
  const prompts = JSON.parse(fs.readFileSync(path.join(root, 'voice-prompts.json'), 'utf8'));
  const phrases = JSON.parse(fs.readFileSync(path.join(root, 'phrases.json'), 'utf8'));
  if (!Array.isArray(phrases) || !phrases.length) {
    throw new Error('The required phrase audio catalog must be a nonempty array.');
  }
  const phrasePaths = new Set();
  for (const phrase of phrases) {
    if (!phrase || typeof phrase.id !== 'string' || !/^[a-z]+(?:-[a-z]+)*$/.test(phrase.id) ||
        phrase.audio !== `assets/audio/voice/phrase-${phrase.id}.wav` || phrasePaths.has(phrase.audio) ||
        Object.hasOwn(prompts, `phrase-${phrase.id}`)) {
      throw new Error('Each phrase needs a unique catalog ID and its own in-pack voice path.');
    }
    phrasePaths.add(phrase.audio);
  }
  const sources = [
    'assets/audio/sfx/pop-launch.wav',
    ...['merge', 'clear', 'land', 'danger'].map(id => `assets/audio/jelly-match/${id}.wav`),
    ...THEMES.map(id => `assets/audio/bgm/${id}.wav`),
    ...Object.keys(prompts).map(id => `assets/audio/voice/${id}.wav`),
    ...phrasePaths,
    ...THEMES.flatMap(theme => CHEST_CUES.map(cue => `assets/audio/chests/${theme}-${cue}.wav`)).sort()
  ];
  const uiClick = readUiClickAudio(root);
  return [...sources.map(source => importedAudio(root, source)), importedAudio(root, uiClick.asset.destination),
    ...collectPairFeedbackAudio(root), ...collectChestReferenceAudio(root), ...collectPopReferenceAudio(root)];
}

function removeRetiredVoiceAssets(directory) {
  const scripts = new Set([
    'multiplayer-host.js', 'multiplayer-capture.js', 'multiplayer-audio.js', 'multiplayer-worker.js',
    'voice-profiles.js', 'voice-profiles-ui.js', 'voice-profiles.css'
  ].flatMap(name => [name, `${name}.br`, `${name}.gz`]));
  for (const file of fs.readdirSync(directory, { withFileTypes: true })) {
    if (file.isFile() && scripts.has(file.name)) fs.unlinkSync(path.join(directory, file.name));
  }
  const assets = path.join(directory, 'multiplayer');
  if (!fs.existsSync(assets) || !fs.lstatSync(assets).isDirectory()) return;
  // Retire only files generated by the former local speech packager. Preserve
  // unrelated output files and the build-only model cache outside this export.
  const generated = /^(?:(?:encoder|decoder|joiner|speaker|vad)-[a-f0-9]{16}\.onnx|tokens-[a-f0-9]{16}\.txt|bpe-[a-f0-9]{16}\.vocab|runtime-js-[a-f0-9]{16}\.js|runtime-wasm-[a-f0-9]{16}\.wasm|manifest\.json|THIRD_PARTY_NOTICES\.txt)(?:\.(?:br|gz))?$/;
  for (const file of fs.readdirSync(assets, { withFileTypes: true })) {
    if (file.isFile() && generated.test(file.name)) fs.unlinkSync(path.join(assets, file.name));
  }
  if (fs.readdirSync(assets).length === 0) fs.rmdirSync(assets);
}

function removeLocalPipPreview(directory) {
  const exportRoot = fs.realpathSync(directory);
  const previewRoot = path.join(exportRoot, 'preview');
  const parent = fs.lstatSync(previewRoot, { throwIfNoEntry: false });
  if (!parent || !parent.isDirectory() && !parent.isSymbolicLink()) return;
  if (parent.isSymbolicLink()) throw new Error('Refusing to clean a linked preview directory outside the Web export.');
  const target = path.resolve(previewRoot, 'pip-growth');
  const relative = path.relative(exportRoot, target);
  if (!relative || relative === '..' || relative.startsWith(`..${path.sep}`) || path.isAbsolute(relative)) {
    throw new Error('The retired Pip preview must remain inside the Web export.');
  }
  const stale = fs.lstatSync(target, { throwIfNoEntry: false });
  if (stale?.isSymbolicLink()) fs.unlinkSync(target);
  else if (stale) fs.rmSync(target, { recursive: true, force: true });
  if (fs.readdirSync(previewRoot).length === 0) fs.rmdirSync(previewRoot);
}

function packageWebExport(directory) {
  const page = path.join(directory, 'index.html');
  const html = fs.readFileSync(page, 'utf8');
  const match = html.match(/const config = (\{[^\r\n]*\});/);
  if (!match || !html.includes('src="index.js"')) {
    throw new Error('Expected a freshly exported index.html with its Godot engine configuration.');
  }
  const config = JSON.parse(match[1]);
  const suffixes = ['js', 'wasm', 'audio.worklet.js', 'audio.position.worklet.js'];
  const engine = suffixes.map(suffix => ({
    suffix, bytes: fs.readFileSync(path.join(directory, `index.${suffix}`))
  }));
  const script = engine.find(file => file.suffix === 'js');
  script.bytes = Buffer.from(patchWebEngine(script.bytes.toString('utf8')));
  const digest = createHash('sha256');
  for (const file of engine) digest.update(file.suffix).update(file.bytes);
  const executable = `engine-${digest.digest('hex').slice(0, 16)}`;
  const pack = fs.readFileSync(path.join(directory, 'index.pck'));
  const mainPack = `game-${createHash('sha256').update(pack).digest('hex').slice(0, 16)}.pck`;
  const files = [
    ...engine.map(file => ({ name: `${executable}.${file.suffix}`, bytes: file.bytes })),
    { name: mainPack, bytes: pack }
  ];
  const retained = new Set();
  const cachedSidecars = fs.readdirSync(directory)
    .filter(name => /^(?:engine|game)-[a-f0-9]{16}\..+\.br$/.test(name));
  let downloadBytes = 0;
  // Azure negotiates .br sidecars; the browser handles decompression and caching.
  for (const file of files) {
    const suffix = file.name.slice(file.name.indexOf('.'));
    const candidates = cachedSidecars.filter(name => name.endsWith(`${suffix}.br`))
      .sort((first, second) => Number(second === `${file.name}.br`) - Number(first === `${file.name}.br`))
      .map(name => path.join(directory, name));
    const compressed = compressWebAsset(file.bytes, candidates);
    fs.writeFileSync(path.join(directory, file.name), file.bytes);
    fs.writeFileSync(path.join(directory, `${file.name}.br`), compressed);
    retained.add(file.name).add(`${file.name}.br`);
    downloadBytes += compressed.length;
  }
  config.executable = executable;
  config.mainPack = mainPack;
  delete config.audioAssets;
  config.fileSizes = {
    [`${executable}.wasm`]: engine.find(file => file.suffix === 'wasm').bytes.length,
    [mainPack]: pack.length
  };
  fs.writeFileSync(page, html
    .replace(match[0], `const config = ${JSON.stringify(config)};`)
    .replace('src="index.js"', `src="${executable}.js"`));

  const originals = new Set([...suffixes, 'pck'].flatMap(suffix => [`index.${suffix}`, `index.${suffix}.br`]));
  for (const file of fs.readdirSync(directory, { withFileTypes: true })) {
    if (file.isFile() && (originals.has(file.name) ||
        (/^(engine|game|audio)-[a-f0-9]{16}\./.test(file.name) && !retained.has(file.name)))) {
      fs.unlinkSync(path.join(directory, file.name));
    }
  }
  removeRetiredVoiceAssets(directory);
  removeLocalPipPreview(directory);
  return downloadBytes;
}

module.exports = { packageWebExport, collectRequiredAudio, collectPopReferenceAudio, collectPairFeedbackAudio, collectChestReferenceAudio, compressWebAsset };
