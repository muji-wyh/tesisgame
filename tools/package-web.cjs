const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { brotliCompressSync, constants } = require('node:zlib');
const { patchWebEngine } = require('./patch-web-engine.cjs');

function collectOptionalAudio(root) {
  const prompts = JSON.parse(fs.readFileSync(path.join(root, 'voice-prompts.json'), 'utf8'));
  const sources = [
    ...['spring', 'summer', 'autumn', 'winter', 'ocean', 'space'].map(id => `assets/audio/bgm/${id}.wav`),
    ...Object.keys(prompts).map(id => `assets/audio/voice/${id}.wav`)
  ];
  return sources.map(source => {
    const metadata = fs.readFileSync(path.join(root, ...`${source}.import`.split('/')), 'utf8');
    const imported = metadata.match(/^path="(res:\/\/\.godot\/imported\/[^"]+\.sample)"$/m)?.[1];
    if (!imported) throw new Error(`Import ${source} before packaging optional audio.`);
    const bytes = fs.readFileSync(path.join(root, ...imported.slice(6).split('/')));
    if (!['RSRC', 'RSCC'].includes(bytes.subarray(0, 4).toString('ascii'))) {
      throw new Error(`Expected an imported Godot audio resource: ${imported}`);
    }
    return { source: `res://${source}`, imported, bytes };
  });
}

function packageWebExport(directory, optionalAudio = []) {
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
  const audio = optionalAudio.map(file => ({
    ...file, optional: true,
    name: `audio-${createHash('sha256').update(file.bytes).digest('hex').slice(0, 16)}.sample`
  }));
  const files = [
    ...engine.map(file => ({ name: `${executable}.${file.suffix}`, bytes: file.bytes })),
    { name: mainPack, bytes: pack },
    ...audio
  ];
  const retained = new Set();
  let downloadBytes = 0;
  // ponytail: Azure negotiates .br sidecars; the browser handles decompression and caching.
  for (const file of files) {
    const compressed = brotliCompressSync(file.bytes, {
      params: { [constants.BROTLI_PARAM_QUALITY]: 11 }
    });
    fs.writeFileSync(path.join(directory, file.name), file.bytes);
    fs.writeFileSync(path.join(directory, `${file.name}.br`), compressed);
    retained.add(file.name).add(`${file.name}.br`);
    if (!file.optional) downloadBytes += compressed.length;
  }
  config.executable = executable;
  config.mainPack = mainPack;
  config.audioAssets = Object.fromEntries(audio.map(file => [file.source, file.name]));
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
  return downloadBytes;
}

module.exports = { packageWebExport, collectOptionalAudio };
