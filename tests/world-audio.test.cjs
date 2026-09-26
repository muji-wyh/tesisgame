const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const root = path.resolve(__dirname, '..');
const themes = ['spring', 'summer', 'autumn', 'winter', 'ocean', 'space', 'jungle', 'candy'];
const added = ['jungle', 'candy'];

function fixture(t) {
  fs.mkdirSync(path.join(root, 'build'), { recursive: true });
  const directory = fs.mkdtempSync(path.join(root, 'build', 'world-audio-test-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  return directory;
}

test('the new-world provenance pins every retained audio file', () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'docs/assets/jungle-candy-audio.json'), 'utf8'));
  const expected = added.flatMap(id => [
    `assets/audio/bgm/${id}.wav`,
    ...['arrive', 'open'].map(suffix => `assets/audio/sfx/${id}-${suffix}.wav`),
    ...['theme', 'arrive', 'open'].map(suffix => `assets/audio/voice/${id}-${suffix}.wav`)
  ]);
  assert.deepEqual(manifest.files.map(file => file.path), expected);
  for (const file of manifest.files) {
    const bytes = fs.readFileSync(path.join(root, file.path));
    assert.equal(bytes.length, file.bytes, file.path);
    assert.equal(createHash('sha256').update(bytes).digest('hex'), file.sha256, file.path);
  }
});

test('missing-only SFX generation adds four distinct new cues without rewriting old effects', (t) => {
  const { sounds, makeWave, generateSfx } = require('../tools/generate-sfx.cjs');
  const directory = fixture(t);
  const output = path.join(directory, 'assets/audio/sfx');
  fs.mkdirSync(output, { recursive: true });
  const ids = added.flatMap(id => [`${id}-arrive`, `${id}-open`]);
  const original = Buffer.from('An existing effect must remain byte-for-byte unchanged.');
  const retained = Object.keys(sounds).filter(id => !ids.includes(id));
  for (const id of retained) fs.writeFileSync(path.join(output, `${id}.wav`), original);
  assert.equal(generateSfx({ root: directory, onlyMissing: true }), 4);
  const generated = ids.map(id => {
    const bytes = fs.readFileSync(path.join(output, `${id}.wav`));
    assert.deepEqual(bytes, makeWave(sounds[id]));
    return bytes.toString('base64');
  });
  assert.equal(new Set(generated).size, 4);
  for (const id of retained) assert.deepEqual(fs.readFileSync(path.join(output, `${id}.wav`)), original);
  assert.equal(generateSfx({ root: directory, onlyMissing: true }), 0);
});

test('missing-only BGM generation preserves all existing tracks and adds playable jungle and candy tunes', (t) => {
  const { soundtrack, generateWorldBgm } = require('../tools/generate-world-bgm.cjs');
  const directory = fixture(t);
  const output = path.join(directory, 'assets/audio/bgm');
  fs.mkdirSync(output, { recursive: true });
  const original = Buffer.from('Do not replace a retained soundtrack.');
  for (const id of themes.filter(id => !added.includes(id))) {
    fs.writeFileSync(path.join(output, `${id}.wav`), original);
  }
  assert.equal(generateWorldBgm({ root: directory, onlyMissing: true }), 2);
  for (const id of added) {
    const bytes = fs.readFileSync(path.join(output, `${id}.wav`));
    assert.equal(bytes.toString('ascii', 0, 4), 'RIFF');
    assert.equal(bytes.toString('ascii', 8, 12), 'WAVE');
    assert.equal(bytes.readUInt16LE(22), 2, `${id} is stereo`);
    assert.equal(bytes.readUInt32LE(24), 44100, `${id} uses the established BGM source rate`);
    assert.equal(bytes.readUInt16LE(34), 16, `${id} is PCM16`);
    assert.ok(soundtrack(id).duration >= 16 && soundtrack(id).duration <= 20);
    assert.deepEqual(bytes, fs.readFileSync(path.join(root, 'assets/audio/bgm', `${id}.wav`)),
      `${id} is exactly reproducible from its original score`);
  }
  assert.notDeepEqual(soundtrack('jungle').notes, soundtrack('candy').notes);
  for (const id of themes.filter(id => !added.includes(id))) {
    assert.deepEqual(fs.readFileSync(path.join(output, `${id}.wav`)), original);
  }
  assert.equal(generateWorldBgm({ root: directory, onlyMissing: true }), 0);
});

test('optional Web audio includes both new worlds and fails clearly if their imports are missing', (t) => {
  const { collectOptionalAudio } = require('../tools/package-web.cjs');
  const directory = fixture(t);
  const prompts = JSON.parse(fs.readFileSync(path.join(root, 'voice-prompts.json'), 'utf8'));
  const popPrompts = JSON.parse(fs.readFileSync(path.join(root, 'pop-voice-prompts.json'), 'utf8'));
  fs.writeFileSync(path.join(directory, 'voice-prompts.json'), JSON.stringify(prompts));
  fs.writeFileSync(path.join(directory, 'pop-voice-prompts.json'), JSON.stringify(popPrompts));
  const expected = [
    ...themes.map(id => `assets/audio/bgm/${id}.wav`),
    ...Object.keys(prompts).map(id => `assets/audio/voice/${id}.wav`),
    ...Object.keys(popPrompts).map(id => `assets/audio/pop/${id}.wav`)
  ];
  fs.mkdirSync(path.join(directory, '.godot/imported'), { recursive: true });
  for (const [index, source] of expected.entries()) {
    const metadata = path.join(directory, `${source}.import`);
    fs.mkdirSync(path.dirname(metadata), { recursive: true });
    fs.writeFileSync(metadata, `path="res://.godot/imported/${index}.sample"\n`);
    fs.writeFileSync(path.join(directory, '.godot/imported', `${index}.sample`), `RSRCfixture-${index}`);
  }
  const audio = collectOptionalAudio(directory);
  assert.deepEqual(audio.map(file => file.source), expected.map(source => `res://${source}`));
  assert.equal(new Set(audio.map(file => file.source)).size, expected.length);
  for (const id of added) {
    const sources = audio.map(file => file.source);
    assert.ok(sources.includes(`res://assets/audio/bgm/${id}.wav`));
    assert.ok(sources.includes(`res://assets/audio/voice/${id}-theme.wav`));
  }
  fs.unlinkSync(path.join(directory, 'assets/audio/bgm/candy.wav.import'));
  assert.throws(() => collectOptionalAudio(directory), /candy\.wav\.import/);
});
