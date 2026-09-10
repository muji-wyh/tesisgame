const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const words = JSON.parse(fs.readFileSync(path.join(root, 'words.json'), 'utf8'));
const seasons = ['spring', 'summer', 'autumn', 'winter', 'ocean', 'space'].map((id) => ({
  id, symbol: `assets/images/rewards/${id}.svg`, bgm: `assets/audio/bgm/${id}.wav`
}));
const rewardSymbols = seasons.flatMap(({ id }) =>
  Array.from({ length: ['ocean', 'space'].includes(id) ? 6 : 10 }, (_, index) => `assets/images/rewards/${id}-${index + 1}.svg`)
);
const sha256 = (bytes) => crypto.createHash('sha256').update(bytes).digest('hex');
const expectedPrompts = {
  welcome: "Find three pairs. Some cards have no match. Tap a picture or a word!",
  correct: 'Great match! Well done!',
  wrong: "Not quite. Let's try another one!",
  loss: "Good try! Let's play again!",
  'spring-theme': 'Welcome to spring!',
  'summer-theme': 'Welcome to summer!',
  'autumn-theme': 'Welcome to autumn!',
  'winter-theme': 'Welcome to winter!',
  'spring-arrive': 'You did it! Tap the spring chest for a surprise!',
  'summer-arrive': 'You did it! Tap the summer chest for a surprise!',
  'autumn-arrive': 'You did it! Tap the autumn chest for a surprise!',
  'winter-arrive': 'You did it! Tap the winter chest for a surprise!',
  'spring-open': 'A spring flower for you! Great job!',
  'summer-open': 'A summer sun for you! Great job!',
  'autumn-open': 'An autumn leaf for you! Great job!',
  'winter-open': 'A winter snowflake for you! Great job!',
  'ocean-theme': 'Welcome to the ocean!',
  'ocean-arrive': 'You did it! Tap the ocean chest for a surprise!',
  'ocean-open': 'An ocean treasure for you! Great job!',
  'space-theme': 'Welcome to space!',
  'space-arrive': 'You did it! Tap the space chest for a surprise!',
  'space-open': 'A space treasure for you! Great job!'
};
const expectedRewardColors = {
  spring: ['#edf8ec', '#438363', '#8ecf6b'],
  summer: ['#ffe6e6', '#b53640', '#ff8f9d'],
  autumn: ['#fff8cf', '#8f7400', '#ffd24d'],
  winter: ['#ffffff', '#606a73', '#d8dee3'],
  ocean: ['#e4f6fb', '#216d89', '#69cbd6'],
  space: ['#eeeafa', '#69569b', '#d7ccef']
};
const sfxIds = [
  'select', 'correct', 'wrong', 'loss',
  ...seasons.flatMap(({ id }) => [`${id}-arrive`, `${id}-open`])
];

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
  assert.equal(imports.length, 220);
  for (const filename of imports) {
    const metadata = fs.readFileSync(filename, 'utf8');
    assert.match(metadata, /^compress\/mode=1$/m, filename);
    assert.match(metadata, /^compress\/lossy_quality=0\.85$/m, filename);
    assert.match(metadata, /^process\/size_limit=0$/m, filename);
    assert.match(metadata, /^mipmaps\/generate=false$/m, filename);
  }
});

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

test('all 140 short vocabulary words have distinct illustrations in one directory', () => {
  assert.equal(words.length, 140);
  assert.equal(new Set(words.map(word => word.id)).size, 140);
  assert.equal(new Set(words.map(word => word.text)).size, 140);
  for (const original of ['cat', 'dog', 'sun', 'ball', 'car', 'apple', 'fish', 'duck']) {
    assert.ok(words.some(word => word.id === original && word.text === original));
  }
  const digests = new Set();
  for (const word of words) {
    assert.match(word.text, /^[a-z]{2,6}$/);
    assert.equal(word.id, word.text);
    assert.equal(path.dirname(path.normalize(word.image)), path.join('assets', 'images', 'words'));
    assert.equal(path.basename(word.image), `${word.id}.svg`);
    digests.add(sha256(readSvg(word.image).replace(/<title\b[^>]*>[\s\S]*?<\/title>/g, '')));
  }
  assert.equal(digests.size, words.length);
});

test('each season has its own original reward SVG', () => {
  assert.deepEqual(seasons.map(({ id }) => id), ['spring', 'summer', 'autumn', 'winter', 'ocean', 'space']);
  const digests = new Set();
  for (const season of seasons) {
    assert.equal(season.symbol, `assets/images/rewards/${season.id}.svg`);
    digests.add(sha256(readSvg(season.symbol)));
  }
  assert.equal(digests.size, 6);
});

test('all fifty-two collectible rewards have distinct SVG artwork', () => {
  const digests = new Set(rewardSymbols.map((symbol) =>
    sha256(readSvg(symbol).replace(/<title\b[^>]*>.*?<\/title>/gs, ''))
  ));
  assert.equal(rewardSymbols.length, 52);
  assert.equal(digests.size, 52);
});

test('seasonal reward SVGs use the requested seasonal palette', () => {
  for (const [season, colors] of Object.entries(expectedRewardColors)) {
    const svg = readSvg(`assets/images/rewards/${season}.svg`).toLowerCase();
    for (const color of colors) {
      assert.match(svg, new RegExp(color), `${season} reward should include ${color}`);
    }
  }
});

test('the encouraging try-again scene is a standalone SVG', () => {
  readSvg(path.join('assets', 'images', 'scenes', 'try-again.svg'));
});

test('the generated image directories contain exactly the 199 named SVGs', () => {
  const expected = [
    ['words', words.map(({ id }) => `${id}.svg`)],
    ['rewards', [...seasons.map(({ id }) => `${id}.svg`), ...rewardSymbols.map((symbol) => path.basename(symbol))]],
    ['scenes', ['try-again.svg']]
  ];
  for (const [directory, names] of expected) {
    const fullPath = path.join(root, 'assets', 'images', directory);
    assert.ok(fs.existsSync(fullPath), `Missing image directory: ${directory}`);
    assert.deepEqual(assetFiles(fullPath), names.sort());
  }
});

test('voice prompts contain exactly the twenty-two specified English messages', () => {
  const filename = path.join(root, 'voice-prompts.json');
  assert.ok(fs.existsSync(filename), 'Missing voice-prompts.json');
  const prompts = JSON.parse(fs.readFileSync(filename, 'utf8'));
  assert.deepEqual(prompts, expectedPrompts);
  for (const [id, text] of Object.entries(prompts)) {
    assert.match(id, /^[a-z]+(?:-[a-z]+)*$/);
    assert.match(text, /^[\x20-\x7e]+$/);
  }
});

test('all twenty-two English prompts have nonempty prerecorded mono voice WAVs', () => {
  for (const id of Object.keys(expectedPrompts)) {
    assertVoice(path.join('assets', 'audio', 'voice', `${id}.wav`));
  }
});

test('every vocabulary entry has its own prerecorded English pronunciation', () => {
  const recordings = new Set();
  for (const word of words) {
    assert.equal(word.audio, `assets/audio/voice/word-${word.id}.wav`);
    recordings.add(sha256(assertVoice(word.audio).data));
  }
  assert.equal(recordings.size, words.length, 'Different words must not reuse a recording.');
});

test('voice output contains exactly 140 word recordings and twenty-two prompts', () => {
  const directory = path.join(root, 'assets', 'audio', 'voice');
  assert.ok(fs.existsSync(directory), 'Missing voice directory');
  const expected = [
    ...Object.keys(expectedPrompts).map((id) => `${id}.wav`),
    ...words.map(({ id }) => `word-${id}.wav`)
  ];
  assert.deepEqual(assetFiles(directory), expected.sort());
});

test('all six themed background tracks are distinct, audible PCM16 stereo WAVs', () => {
  const hashes = new Set();
  for (const season of seasons) {
    assert.equal(season.bgm, `assets/audio/bgm/${season.id}.wav`);
    const wave = readWave(season.bgm);
    assert.equal(wave.channels, 2, season.id);
    assert.equal(wave.sampleRate, 44100, season.id);
    assert.ok(pcmStats(wave.data).energy > 0, `Silent soundtrack: ${season.id}`);
    hashes.add(sha256(wave.data));
  }
  assert.equal(hashes.size, 6);
  assert.deepEqual(
    assetFiles(path.join(root, 'assets', 'audio', 'bgm')),
    seasons.map(({ id }) => `${id}.wav`).sort()
  );
});

test('all sixteen original effects have gentle, non-silent PCM samples and smooth endpoints', () => {
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
    sfxIds.map((id) => `${id}.wav`).sort()
  );
});

test('the six themed chest openings have different SHA256 values and last one to two seconds', () => {
  const hashes = new Set();
  for (const { id } of seasons) {
    const wave = readWave(path.join('assets', 'audio', 'sfx', `${id}-open.wav`));
    hashes.add(sha256(wave.bytes));
    const seconds = wave.data.length / wave.blockAlign / wave.sampleRate;
    assert.ok(seconds >= 1 && seconds <= 2, `${id} opening duration: ${seconds}`);
  }
  assert.equal(hashes.size, 6);
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
