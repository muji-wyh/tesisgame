const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { readModelContainer, embeddedModelImages, imageDimensions } = require('./helpers/chest-model-assets.cjs');
const root = path.resolve(__dirname, '..');
const words = JSON.parse(fs.readFileSync(path.join(root, 'words.json'), 'utf8'));
const phrases = JSON.parse(fs.readFileSync(path.join(root, 'phrases.json'), 'utf8'));
const seasons = ['spring', 'summer', 'autumn', 'winter', 'ocean', 'space', 'jungle', 'candy'].map((id) => ({
  id, symbol: `assets/images/rewards/${id}.svg`, bgm: `assets/audio/bgm/${id}.wav`
}));
const rewardSymbols = seasons.flatMap(({ id }) =>
  Array.from({ length: ['spring', 'summer', 'autumn', 'winter'].includes(id) ? 10 : 6 }, (_, index) => `assets/images/rewards/${id}-${index + 1}.svg`)
);
const sha256 = (bytes) => crypto.createHash('sha256').update(bytes).digest('hex');
const expectedPrompts = {
  'spring-theme': 'Welcome to spring!',
  'summer-theme': 'Welcome to summer!',
  'autumn-theme': 'Welcome to autumn!',
  'winter-theme': 'Welcome to winter!',
  'ocean-theme': 'Welcome to the ocean!',
  'space-theme': 'Welcome to space!',
  'jungle-theme': 'Welcome to the jungle!',
  'candy-theme': 'Welcome to candy land!',
  'phrase-intro': 'Listen to Pip. Put the words in order.',
  'phrase-try-again': 'Try a different order. You can do it!',
  'phrase-complete': 'Three phrases complete! Your treasure is ready.'
};
const expectedRewardColors = {
  spring: ['#edf8ec', '#438363', '#8ecf6b'],
  summer: ['#ffe6e6', '#b53640', '#ff8f9d'],
  autumn: ['#fff8cf', '#8f7400', '#ffd24d'],
  winter: ['#ffffff', '#606a73', '#d8dee3'],
  ocean: ['#e4f6fb', '#216d89', '#69cbd6'],
  space: ['#eeeafa', '#69569b', '#d7ccef'],
  jungle: ['#edf7df', '#765445', '#e7c180'],
  candy: ['#fff0f7', '#765445', '#f5c8da']
};
const sfxIds = [
  'select', 'correct',
  ...seasons.map(({ id }) => `${id}-arrive`)
];

test('Pip greetings preserve the three selected WAVs in the repository', () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'docs/assets/pip-sounds.json')));
  assert.equal(manifest.assets.length, 3);
  assert.equal(new Set(manifest.assets.map(asset => asset.sha256)).size, 3);
  for (const asset of manifest.assets) {
    const bytes = fs.readFileSync(path.join(root, asset.file));
    assert.equal(sha256(bytes), asset.sha256, asset.file);
    assert.equal(bytes.toString('ascii', 0, 4), 'RIFF');
    assert.equal(bytes.toString('ascii', 8, 12), 'WAVE');
    const metadata = fs.readFileSync(path.join(root, asset.file + '.import'), 'utf8');
    assert.match(metadata, /edit\/loop_mode=0/);
    assert.match(metadata, /edit\/normalize=false/);
  }
});

test('the duck mascot has four original reusable poses and is embedded for the web loader', () => {
  const filename = path.join(root, 'assets', 'images', 'mascots', 'pip.svg');
  assert.ok(fs.existsSync(filename), 'The original Pip sprite sheet is missing');
  const svg = fs.readFileSync(filename, 'utf8');
  assert.match(svg, /viewBox="0 0 480 120"/);
  for (const pose of ['idle', 'speaking', 'blink', 'wave']) {
    assert.match(svg, new RegExp(`id="pip-${pose}"`));
  }
  assert.doesNotMatch(svg, /<(?:script|image|foreignObject|use|text)\b|\b(?:href|src|on[a-z]+)\s*=/i);
  const { inlineMascot } = require('../tools/prepare-godot.cjs');
  assert.equal(typeof inlineMascot, 'function');
  const embedded = inlineMascot('url("$PIP_MASCOT_URI")');
  assert.equal(embedded, `url("data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}")`);
  const idle = fs.readFileSync(path.join(root, 'assets/images/mascots/pip-idle-actions.svg'), 'utf8');
  assert.match(idle, /viewBox="0 0 480 120"/);
  for (const pose of ['look-left', 'look-right', 'stretch', 'preen']) {
    assert.match(idle, new RegExp(`id="pip-${pose}"`));
  }
  assert.doesNotMatch(idle, /<(?:script|image|foreignObject|use|text)\b|\b(?:href|src|on[a-z]+)\s*=/i);
});

function assetFiles(directory) {
  const names = fs.readdirSync(directory);
  for (const name of names.filter((entry) => entry.endsWith('.import'))) {
    assert.ok(names.includes(name.slice(0, -7)), `Orphan Godot import metadata: ${name}`);
  }
  return names.filter((name) => !name.endsWith('.import')).sort();
}

test('mobile textures use high-quality WebP without reducing their source resolution', () => {
  const imports = ['chests', 'images'].flatMap(group => fs.readdirSync(path.join(root, 'assets', group), {
    recursive: true
  }).filter(name => name.endsWith('.import')).map(name => path.join(root, 'assets', group, name)));
  const chestManifest = JSON.parse(fs.readFileSync(path.join(root, 'assets/chests/downloaded/manifest.json'), 'utf8'));
  const chestModels = Object.values(chestManifest.styles).map(style => style.model);
  assert.equal(new Set(chestModels).size, 5, 'The five added chest designs use separate live models');
  assert.ok(imports.every(filename => !filename.startsWith(path.join(root, 'assets/chests/downloaded') + path.sep)),
    'Retired 320-pixel opening frames are not imported into the game');
  const modelImports = imports.filter(filename => filename.endsWith('.glb.import'));
  assert.deepEqual(modelImports.sort(), chestModels.map(filename => path.join(root, filename + '.import')).sort());
  for (const filename of modelImports) {
    const metadata = fs.readFileSync(filename, 'utf8');
    assert.match(metadata, /^type="PackedScene"$/m, filename);
    assert.match(metadata, /^importer="scene"$/m, filename);
  }
  const modelImages = chestModels.flatMap(filename => embeddedModelImages(filename, readModelContainer(path.join(root, filename))));
  const modelTextureImports = imports.filter(filename => !filename.endsWith('.glb.import')
    && filename.startsWith(path.join(root, 'assets/chests/models') + path.sep));
  assert.deepEqual(modelTextureImports.sort(), modelImages.map(image => path.join(root, image.path + '.import')).sort(),
    'Every imported model texture comes from an embedded source image');
  for (const image of modelImages) {
    const filename = path.join(root, image.path);
    const bytes = fs.readFileSync(filename);
    assert.equal(sha256(bytes), sha256(image.bytes), `${image.path} preserves all source texture bytes`);
    const dimensions = imageDimensions(bytes);
    assert.deepEqual(dimensions, imageDimensions(image.bytes), `${image.path} preserves source resolution`);
    assert.ok(dimensions.width >= 512 && dimensions.height >= 512, `${image.path} retains detailed source material maps`);
    const metadata = fs.readFileSync(filename + '.import', 'utf8');
    assert.match(metadata, /^compress\/mode=1$/m, filename);
    assert.match(metadata, /^compress\/lossy_quality=0\.85$/m, filename);
    assert.match(metadata, /^process\/size_limit=0$/m, filename);
    assert.match(metadata, /^mipmaps\/generate=true$/m, `${image.path} retains mipmaps for stable 3D sampling`);
  }
  const textureImports = imports.filter(filename => !filename.startsWith(path.join(root, 'assets/chests/models') + path.sep));
  assert.equal(textureImports.length, 1380); // Original art, Pip wardrobes, derived chest layers and surprises.
  for (const filename of textureImports) {
    const metadata = fs.readFileSync(filename, 'utf8');
    assert.match(metadata, /^compress\/mode=1$/m, filename);
    assert.match(metadata, /^compress\/lossy_quality=0\.85$/m, filename);
    assert.match(metadata, /^process\/size_limit=0$/m, filename);
    assert.match(metadata, /^mipmaps\/generate=false$/m, filename);
  }
});

function assertSvgGeometry(svg, label) {
  for (const [, data] of svg.matchAll(/<path\b[^>]*\bd="([^"]*)"/g)) {
    assert.match(data, /^[MmZzLlHhVvCcSsQqTtAaEe0-9.,+\s-]+$/, `Invalid path coordinates: ${label}`);
  }
  for (const [, value] of svg.matchAll(/\b(?:cx|cy|r|rx|ry|x|y|x1|x2|y1|y2|width|height)="([^"]*)"/g)) {
    assert.match(value, /^-?(?:\d+(?:\.\d*)?|\.\d+)$/, `Invalid shape coordinates: ${label}`);
  }
  for (const [, transform] of svg.matchAll(/\btransform="([^"]*)"/g)) {
    assert.match(transform.replace(/\b(?:matrix|translate|scale|rotate|skewX|skewY)\b/g, ''),
      /^[0-9.,+\s()-]+$/, `Invalid transform coordinates: ${label}`);
  }
}

function readSvg(relativePath) {
  const filename = path.join(root, relativePath);
  assert.ok(fs.existsSync(filename), `Missing SVG: ${relativePath}`);
  const svg = fs.readFileSync(filename, 'utf8');
  assert.match(svg, /<svg\b[^>]*\bviewBox="0 0 120 120"/);
  assert.match(svg, /\bxmlns="http:\/\/www\.w3\.org\/2000\/svg"/);
  assert.match(svg, /<(?:path|circle|ellipse|rect|line|polygon|polyline)\b/);
  assert.match(svg, /<\/svg>\s*$/);
  assert.doesNotMatch(svg, /<\s*\/?\s*(?:[\w-]+:)?(?:text|script|image|foreignObject|iframe|use|a|style|animate\w*|set)\b/i);
  assert.doesNotMatch(svg, /\b(?:href|src|on[a-z]+)\s*=|\burl\s*\(|@import|<!\s*(?:DOCTYPE|ENTITY)/i);
  assert.doesNotMatch(svg.replace('http://www.w3.org/2000/svg', ''), /https?:|data:/i);
  assertSvgGeometry(svg, relativePath);
  return svg;
}

function readWave(relativePath) {
  const filename = path.join(root, relativePath);
  assert.ok(fs.existsSync(filename), `Missing WAV: ${relativePath}`);
  const bytes = fs.readFileSync(filename);
  assert.ok(bytes.length > 1000, `WAV is too short: ${relativePath}`);
  assert.equal(bytes.toString('ascii', 0, 4), 'RIFF', relativePath);
  assert.equal(bytes.toString('ascii', 8, 12), 'WAVE', relativePath);
  assert.equal(bytes.readUInt32LE(4), bytes.length - 8, `Invalid RIFF size: ${relativePath}`);
  let format;
  let data;
  let dataOffset;
  for (let offset = 12; offset + 8 <= bytes.length;) {
    const id = bytes.toString('ascii', offset, offset + 4);
    const size = bytes.readUInt32LE(offset + 4);
    const start = offset + 8;
    assert.ok(start + size <= bytes.length, `Truncated WAV chunk: ${relativePath}`);
    if (id === 'fmt ') {
      assert.ok(size >= 16, `Invalid WAV format chunk: ${relativePath}`);
      format = {
        encoding: bytes.readUInt16LE(start),
        channels: bytes.readUInt16LE(start + 2),
        sampleRate: bytes.readUInt32LE(start + 4),
        byteRate: bytes.readUInt32LE(start + 8),
        blockAlign: bytes.readUInt16LE(start + 12),
        bits: bytes.readUInt16LE(start + 14)
      };
    } else if (id === 'data') {
      data = bytes.subarray(start, start + size);
      dataOffset = start;
    }
    offset = start + size + (size % 2);
  }
  assert.ok(format, `Missing WAV format chunk: ${relativePath}`);
  assert.ok(data && data.length > 0, `Missing WAV samples: ${relativePath}`);
  assert.equal(format.encoding, 1, `Expected PCM WAV: ${relativePath}`);
  assert.equal(format.bits, 16, `Expected PCM16 WAV: ${relativePath}`);
  assert.equal(format.blockAlign, format.channels * 2, relativePath);
  assert.equal(format.byteRate, format.sampleRate * format.blockAlign, relativePath);
  assert.equal(data.length % format.blockAlign, 0, relativePath);
  return { bytes, data, dataOffset, ...format };
}

function pcmStats(data) {
  let peak = 0;
  let energy = 0;
  for (let offset = 0; offset < data.length; offset += 2) {
    const sample = data.readInt16LE(offset);
    peak = Math.max(peak, Math.abs(sample));
    energy += sample * sample;
  }
  return { peak, energy };
}

function assertVoice(relativePath) {
  const wave = readWave(relativePath);
  assert.equal(wave.sampleRate, 22050, relativePath);
  assert.equal(wave.channels, 1, relativePath);
  assert.ok(pcmStats(wave.data).energy > 0, `Silent pronunciation: ${relativePath}`);
  return wave;
}

test('all 1250 leveled vocabulary words have distinct illustrations in one directory', () => {
  assert.equal(words.length, 1250);
  assert.equal(new Set(words.map(word => word.id)).size, 1250);
  assert.equal(new Set(words.map(word => word.text)).size, 1250);
  for (const original of ['cat', 'dog', 'sun', 'ball', 'car', 'apple', 'fish', 'duck']) {
    assert.ok(words.some(word => word.id === original && word.text === original));
  }
  const digests = new Set();
  for (const word of words) {
    assert.match(word.text, /^[a-z]{2,14}$/);
    assert.ok(['basic', 'growing', 'advanced'].includes(word.level), `${word.id} needs an explicit level`);
    assert.equal(word.id, word.text);
    assert.equal(path.dirname(path.normalize(word.image)), path.join('assets', 'images', 'words'));
    if (word.art_key?.startsWith('mulberry/')) {
      assert.equal(path.basename(word.image), `${word.id}.png`);
      const png = fs.readFileSync(path.join(root, word.image));
      assert.deepEqual(require('../tools/import-vocabulary.cjs').pngDimensions(png), {width: 192, height: 192}, word.id);
      digests.add(sha256(png));
    } else {
      assert.equal(path.basename(word.image), `${word.id}.svg`);
      digests.add(sha256(readSvg(word.image).replace(/<title\b[^>]*>[\s\S]*?<\/title>/g, '')));
    }
  }
  assert.equal(digests.size, words.length);
});

test('each age tier gains 300 sourced words spanning actions, qualities, people and everyday topics', () => {
  const importer = require('../tools/import-vocabulary.cjs');
  const additions = importer.additions();
  assert.equal(additions.length, 900);
  assert.deepEqual(words.slice(350).map(word => word.id), additions.map(word => word.id),
    'The sourced additions follow the preserved original 350 entries');
  assert.deepEqual(words.reduce((counts, word) => {
    counts[word.level] = (counts[word.level] || 0) + 1;
    return counts;
  }, {}), {basic: 448, growing: 412, advanced: 390});
  for (const level of ['basic', 'growing', 'advanced']) {
    const tier = additions.filter(word => word.level === level);
    assert.equal(tier.length, 300, level);
    assert.ok(tier.filter(word => word.part_of_speech === 'verb').length >= 30, `${level} includes everyday actions`);
    assert.ok(tier.filter(word => word.part_of_speech === 'adjective').length >= 25, `${level} includes qualities and feelings`);
    for (const topic of ['actions-and-routines', 'feelings-and-people', 'describe-and-compare',
      'places-and-time', 'nature-and-science', 'food-and-home', 'school-and-play']) {
      assert.ok(tier.filter(word => word.topic === topic).length >= 5, `${level}: ${topic}`);
    }
  }
});

test('sourced vocabulary PNGs preserve pinned provenance and a consistent production renderer', () => {
  const importer = require('../tools/import-vocabulary.cjs');
  assert.doesNotThrow(() => importer.check());
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'docs/assets/mulberry-vocabulary.json')));
  assert.equal(manifest.provider, 'Mulberry Symbols');
  assert.ok(manifest.creator.length > 0);
  assert.equal(manifest.source, 'https://github.com/mulberrysymbols/mulberry-symbols');
  assert.equal(manifest.licenseUrl, 'https://creativecommons.org/licenses/by-sa/4.0/');
  assert.equal(manifest.status, 'Downloaded and integrated');
  assert.equal(manifest.animations, 'None; static illustrations');
  assert.match(manifest.modifications, /rasterized.*192 by 192 PNGs/);
  assert.equal(manifest.renderer.name, 'sharp');
  assert.match(manifest.renderer.version, /^\d+\.\d+\.\d+/);
  assert.equal(manifest.renderer.fit, 'contain');
  assert.equal(manifest.renderer.background, 'transparent');
  assert.equal(new Set(manifest.files.map(file => file.sourceSha256)).size, 900,
    'Every word has a separate original source illustration');
});

test('the sixty-word age expansion has its own reproducible original art module', () => {
  const filename = path.join(root, 'tools', 'word-art', 'age-expansion.cjs');
  assert.ok(fs.existsSync(filename), 'The original age-expansion art module is missing');
  const art = require(filename);
  const expansion = words.slice(140, 200);
  assert.equal(expansion.length, 60);
  assert.deepEqual(Object.keys(art).sort(), expansion.map(word => word.id).sort());
  for (const word of expansion) assertSvgGeometry(art[word.id], word.id);
  for (const word of expansion) {
    assert.ok(readSvg(word.image).replace(/\r\n/g, '\n').includes(art[word.id].replace(/\r\n/g, '\n')),
      `${word.id} must match its original art definition`);
  }
});

test('each age tier gains fifty unique illustrated nouns without replacing earlier words', () => {
  const previous = words.slice(0, 200);
  assert.deepEqual(previous.reduce((counts, word) => {
    counts[word.level] = (counts[word.level] || 0) + 1;
    return counts;
  }, {}), { basic: 98, growing: 62, advanced: 40 });
  const added = words.slice(200, 350);
  assert.equal(added.length, 150);
  for (const level of ['basic', 'growing', 'advanced']) {
    const additions = added.filter(word => word.level === level);
    assert.equal(additions.length, 50, `${level} must gain fifty words`);
    const art = require(`../tools/word-art/${level}-expansion.cjs`);
    assert.deepEqual(Object.keys(art).sort(), additions.map(word => word.id).sort());
    for (const word of additions) {
      assertSvgGeometry(art[word.id], word.id);
      assert.ok(readSvg(word.image).replace(/\r\n/g, '\n').includes(art[word.id].replace(/\r\n/g, '\n')),
        `${word.id} must match its original illustration`);
    }
  }
});

test('regenerating unchanged SVGs leaves existing media bytes untouched', (t) => {
  t.mock.method(fs, 'writeFileSync', filename => {
    assert.fail(`Unchanged SVG must not be rewritten: ${path.relative(root, filename)}`);
  });
  require('../tools/generate-images.cjs').generateImages();
});

test('each season has its own original reward SVG', () => {
  assert.deepEqual(seasons.map(({ id }) => id), ['spring', 'summer', 'autumn', 'winter', 'ocean', 'space', 'jungle', 'candy']);
  const digests = new Set();
  for (const season of seasons) {
    assert.equal(season.symbol, `assets/images/rewards/${season.id}.svg`);
    digests.add(sha256(readSvg(season.symbol)));
  }
  assert.equal(digests.size, 8);
});

test('all sixty-four collectible rewards have distinct SVG artwork', () => {
  const digests = new Set(rewardSymbols.map((symbol) =>
    sha256(readSvg(symbol).replace(/<title\b[^>]*>.*?<\/title>/gs, ''))
  ));
  assert.equal(rewardSymbols.length, 64);
  assert.equal(digests.size, 64);
});

test('seasonal reward SVGs use the requested seasonal palette', () => {
  for (const [season, colors] of Object.entries(expectedRewardColors)) {
    const svg = readSvg(`assets/images/rewards/${season}.svg`).toLowerCase();
    for (const color of colors) {
      assert.match(svg, new RegExp(color), `${season} reward should include ${color}`);
    }
  }
});

test('the image directories contain exactly the 1322 named vocabulary and reward assets', () => {
  const expected = [
    ['words', words.map(({ image }) => path.basename(image))],
    ['rewards', [...seasons.map(({ id }) => `${id}.svg`), ...rewardSymbols.map((symbol) => path.basename(symbol))]]
  ];
  assert.equal(expected.reduce((count, [, names]) => count + names.length, 0), 1322);
  for (const [directory, names] of expected) {
    const fullPath = path.join(root, 'assets', 'images', directory);
    assert.ok(fs.existsSync(fullPath), `Missing image directory: ${directory}`);
    assert.deepEqual(assetFiles(fullPath), names.sort());
  }
});

test('voice prompts contain eight world greetings and three Phrase Builder cues', () => {
  const filename = path.join(root, 'voice-prompts.json');
  assert.ok(fs.existsSync(filename), 'Missing voice-prompts.json');
  const prompts = JSON.parse(fs.readFileSync(filename, 'utf8'));
  assert.deepEqual(prompts, expectedPrompts);
  for (const [id, text] of Object.entries(prompts)) {
    assert.match(id, /^[a-z]+(?:-[a-z]+)*$/);
    assert.match(text, /^[\x20-\x7e]+$/);
  }
});

test('all eleven English prompts have nonempty prerecorded mono voice WAVs', () => {
  for (const id of Object.keys(expectedPrompts)) {
    assertVoice(path.join('assets', 'audio', 'voice', `${id}.wav`));
  }
});

test('every vocabulary entry has its own prerecorded English pronunciation', () => {
  const recordings = new Set();
  for (const word of words) {
    assert.equal(word.audio, `assets/audio/voice/word-${word.id}.wav`);
    recordings.add(sha256(assertVoice(word.audio).data));
    if (word.art_key?.startsWith('mulberry/')) {
      const imported = fs.readFileSync(path.join(root, word.audio + '.import'), 'utf8');
      assert.match(imported, /^compress\/mode=2$/m, `${word.id} uses the compact QOA playback format`);
    }
  }
  assert.equal(recordings.size, words.length, 'Different words must not reuse a recording.');
});

test('every phrase has a distinct prerecorded whole-phrase pronunciation', () => {
  const recordings = new Set();
  for (const phrase of phrases) {
    assert.equal(phrase.audio, `assets/audio/voice/phrase-${phrase.id}.wav`);
    recordings.add(sha256(assertVoice(phrase.audio).data));
  }
  assert.equal(recordings.size, phrases.length, 'Different phrases must not reuse a recording.');
});

test('voice sources contain exactly 1250 words, 36 phrases, and eleven active prompts', () => {
  const directory = path.join(root, 'assets', 'audio', 'voice');
  assert.ok(fs.existsSync(directory), 'Missing voice directory');
  const expected = [
    ...Object.keys(expectedPrompts).map((id) => `${id}.wav`),
    ...words.map(({ id }) => `word-${id}.wav`),
    ...phrases.map(({ id }) => `phrase-${id}.wav`)
  ];
  assert.equal(expected.length, 1297);
  assert.deepEqual(assetFiles(directory), expected.sort());
});

test('every shipped spoken recording matches the approved Ava profile and source manifest', () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'docs/assets/ava-voice.json'), 'utf8'));
  for (const [key, value] of Object.entries({ voice: 'en-US-AvaNeural', rate: '-15%', pitch: '+8Hz', volume: '+0%' })) {
    assert.equal(manifest.profile[key], value, `Approved voice setting: ${key}`);
  }
  const expected = new Map([
    ...Object.entries(expectedPrompts),
    ...words.map(word => [`word-${word.id}`, word.text]),
    ...phrases.map(phrase => [`phrase-${phrase.id}`, phrase.text])
  ]);
  assert.equal(manifest.files.length, expected.size);
  assert.equal(new Set(manifest.files.map(file => file.id)).size, expected.size);
  for (const file of manifest.files) {
    assert.ok(expected.has(file.id), `Unexpected spoken recording: ${file.id}`);
    assert.equal(file.text, expected.get(file.id), file.id);
    assert.equal(file.path, `assets/audio/voice/${file.id}.wav`, file.id);
    const bytes = fs.readFileSync(path.join(root, file.path));
    assert.equal(bytes.length, file.bytes, file.id);
    assert.equal(sha256(bytes), file.sha256, `${file.id} uses its recorded Ava source`);
  }
});

test('all eight themed background tracks are distinct, audible PCM16 stereo WAVs', () => {
  const hashes = new Set();
  const music = JSON.parse(fs.readFileSync(path.join(root, 'docs/assets/casual-bgm.json'), 'utf8'));
  assert.deepEqual(music.files.map(track => track.theme), seasons.map(season => season.id));
  for (const season of seasons) {
    assert.equal(season.bgm, `assets/audio/bgm/${season.id}.wav`);
    const track = music.files.find(item => item.theme === season.id);
    assert.equal(sha256(fs.readFileSync(path.join(root, season.bgm))), track.sha256,
      `${season.id} retains its reviewed music recording`);
    const wave = readWave(season.bgm);
    assert.equal(wave.channels, 2, season.id);
    assert.equal(wave.sampleRate, 44100, season.id);
    const stats = pcmStats(wave.data);
    assert.ok(stats.energy > 0, `Silent soundtrack: ${season.id}`);
    assert.ok(stats.peak < 32768 * 10 ** (-3 / 20), `${season.id} retains playback headroom`);
    for (let channel = 0; channel < 2; channel++) {
      const first = wave.data.readInt16LE(channel * 2);
      const last = wave.data.readInt16LE(wave.data.length - 4 + channel * 2);
      assert.ok(Math.abs(last - first) < 32768 * 0.002, `${season.id} has no abrupt loop boundary`);
    }
    hashes.add(sha256(wave.data));
  }
  assert.equal(hashes.size, 8);
  assert.deepEqual(
    assetFiles(path.join(root, 'assets', 'audio', 'bgm')),
    seasons.map(({ id }) => `${id}.wav`).sort()
  );
});

test('the ten melody effects have gentle, non-silent PCM samples and smooth endpoints', () => {
  for (const id of sfxIds) {
    const wave = readWave(path.join('assets', 'audio', 'sfx', `${id}.wav`));
    assert.equal(wave.sampleRate, 22050, id);
    assert.equal(wave.channels, 1, id);
    assert.equal(wave.dataOffset, 44, `Expected canonical 44-byte SFX header: ${id}`);
    const { peak, energy } = pcmStats(wave.bytes.subarray(44));
    assert.ok(energy > 0, `Silent SFX: ${id}`);
    assert.ok(peak < 30000, `SFX lacks headroom: ${id}, peak ${peak}`);
    assert.equal(wave.data.readInt16LE(0), 0, `SFX must start at zero: ${id}`);
    assert.equal(wave.data.readInt16LE(wave.data.length - 2), 0, `SFX must end at zero: ${id}`);
  }
  assert.deepEqual(
    assetFiles(path.join(root, 'assets', 'audio', 'sfx')),
    [...sfxIds, 'pop-launch'].map((id) => `${id}.wav`).sort()
  );
});

test('the SFX generator exactly reproduces its named files and rejects excessive float peaks', () => {
  const { sounds, makeWave } = require('../tools/generate-sfx.cjs');
  assert.deepEqual(Object.keys(sounds).sort(), [...sfxIds].sort());
  for (const id of sfxIds) {
    assert.deepEqual(
      makeWave(sounds[id]),
      fs.readFileSync(path.join(root, 'assets', 'audio', 'sfx', `${id}.wav`)),
      `SFX is not reproducible: ${id}`
    );
  }
  assert.throws(() => makeWave({
    ...sounds.select,
    notes: sounds.select.notes.map((note) => ({ ...note, gain: 4 }))
  }), /peak.*0\.9/i);
});
