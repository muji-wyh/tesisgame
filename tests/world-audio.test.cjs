const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const themes = ['spring', 'summer', 'autumn', 'winter', 'ocean', 'space', 'jungle', 'candy'];
const added = ['jungle', 'candy'];

function fixture(t) {
  fs.mkdirSync(path.join(root, 'build'), { recursive: true });
  const directory = fs.mkdtempSync(path.join(root, 'build', 'world-audio-test-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  return directory;
}

test('the new-world provenance preserves superseded music history and pins four active original recordings', () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'docs/assets/jungle-candy-audio.json'), 'utf8'));
  const expected = added.flatMap(id => [
    `assets/audio/bgm/${id}.wav`,
    ...['arrive', 'open'].map(suffix => `assets/audio/sfx/${id}-${suffix}.wav`),
    ...['theme', 'arrive', 'open'].map(suffix => `assets/audio/voice/${id}-${suffix}.wav`)
  ]);
  assert.deepEqual(manifest.files.map(file => file.path), expected);
  const superseded = added.map(id => `assets/audio/bgm/${id}.wav`);
  const active = added.flatMap(id => [
    `assets/audio/sfx/${id}-arrive.wav`,
    `assets/audio/voice/${id}-theme.wav`
  ]);
  const retired = added.flatMap(id => [
    `assets/audio/sfx/${id}-open.wav`,
    `assets/audio/voice/${id}-arrive.wav`,
    `assets/audio/voice/${id}-open.wav`
  ]);
  for (const file of manifest.files) {
    if (superseded.includes(file.path)) {
      // The active casual-music manifest owns the replacement recording's hash.
      // The dated manifest continues to describe the original synthesized score.
      assert.equal(file.kind, 'bgm');
      assert.equal(fs.existsSync(path.join(root, file.path)), true, file.path);
      continue;
    }
    if (!active.includes(file.path)) {
      assert.ok(retired.includes(file.path), `Unclassified historical audio: ${file.path}`);
      assert.equal(fs.existsSync(path.join(root, file.path)), false,
        `Retired audio is documented but must not return to the source inventory: ${file.path}`);
      continue;
    }
    const bytes = fs.readFileSync(path.join(root, file.path));
    assert.equal(bytes.length, file.bytes, file.path);
    assert.equal(createHash('sha256').update(bytes).digest('hex'), file.sha256, file.path);
  }
});

test('missing-only SFX generation adds two arrival cues without rewriting effects or restoring retired openings', (t) => {
  const { sounds, makeWave, generateSfx } = require('../tools/generate-sfx.cjs');
  const directory = fixture(t);
  const output = path.join(directory, 'assets/audio/sfx');
  fs.mkdirSync(output, { recursive: true });
  const ids = added.map(id => `${id}-arrive`);
  const active = ['select', 'correct', 'wrong', 'loss', ...themes.map(id => `${id}-arrive`)];
  assert.deepEqual(Object.keys(sounds).sort(), [...active].sort());
  const original = Buffer.from('An existing effect must remain byte-for-byte unchanged.');
  const retained = active.filter(id => !ids.includes(id));
  for (const id of retained) fs.writeFileSync(path.join(output, `${id}.wav`), original);
  assert.equal(generateSfx({ root: directory, onlyMissing: true }), 2);
  const generated = ids.map(id => {
    const bytes = fs.readFileSync(path.join(output, `${id}.wav`));
    assert.deepEqual(bytes, makeWave(sounds[id]));
    return bytes.toString('base64');
  });
  assert.equal(new Set(generated).size, 2);
  for (const id of retained) assert.deepEqual(fs.readFileSync(path.join(output, `${id}.wav`)), original);
  assert.equal(generateSfx({ root: directory, onlyMissing: true }), 0);
  assert.deepEqual(fs.readdirSync(output).sort(), active.map(id => `${id}.wav`).sort());
});

test('BGM generation defaults to preserving existing tracks and reproduces the historical jungle and candy scores', (t) => {
  const { soundtrack, generateWorldBgm } = require('../tools/generate-world-bgm.cjs');
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'docs/assets/jungle-candy-audio.json'), 'utf8'));
  const directory = fixture(t);
  const output = path.join(directory, 'assets/audio/bgm');
  fs.mkdirSync(output, { recursive: true });
  const original = Buffer.from('Do not replace a retained soundtrack.');
  for (const id of themes.filter(id => !added.includes(id))) {
    fs.writeFileSync(path.join(output, `${id}.wav`), original);
  }
  assert.equal(generateWorldBgm({ root: directory }), 2);
  for (const id of added) {
    const bytes = fs.readFileSync(path.join(output, `${id}.wav`));
    assert.equal(bytes.toString('ascii', 0, 4), 'RIFF');
    assert.equal(bytes.toString('ascii', 8, 12), 'WAVE');
    assert.equal(bytes.readUInt16LE(22), 2, `${id} is stereo`);
    assert.equal(bytes.readUInt32LE(24), 44100, `${id} uses the established BGM source rate`);
    assert.equal(bytes.readUInt16LE(34), 16, `${id} is PCM16`);
    assert.ok(soundtrack(id).duration >= 16 && soundtrack(id).duration <= 20);
    const historical = manifest.files.find(file => file.path === `assets/audio/bgm/${id}.wav`);
    assert.equal(bytes.length, historical.bytes, id);
    assert.equal(createHash('sha256').update(bytes).digest('hex'), historical.sha256,
      `${id} is exactly reproducible from its historical original score`);
  }
  assert.notDeepEqual(soundtrack('jungle').notes, soundtrack('candy').notes);
  for (const id of themes.filter(id => !added.includes(id))) {
    assert.deepEqual(fs.readFileSync(path.join(output, `${id}.wav`)), original);
  }
  assert.equal(generateWorldBgm({ root: directory, onlyMissing: true }), 0);
});

test('the BGM command preserves replacements by default and requires an explicit replace flag', (t) => {
  const directory = fixture(t);
  const output = path.join(directory, 'assets/audio/bgm');
  const toolDirectory = path.join(directory, 'tools');
  fs.mkdirSync(output, { recursive: true });
  fs.mkdirSync(toolDirectory, { recursive: true });
  for (const tool of ['generate-world-bgm.cjs', 'generate-sfx.cjs']) {
    fs.copyFileSync(path.join(root, 'tools', tool), path.join(toolDirectory, tool));
  }
  const original = Buffer.from('A downloaded soundtrack must survive the legacy generator.');
  for (const id of themes) fs.writeFileSync(path.join(output, `${id}.wav`), original);
  const run = args => spawnSync(process.execPath, [path.join(toolDirectory, 'generate-world-bgm.cjs'), ...args], {
    cwd: directory, encoding: 'utf8', windowsHide: true, timeout: 120000
  });
  for (const args of [[], ['--missing']]) {
    const result = run(args);
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /Generated 0 original world soundtracks/);
    for (const id of themes) assert.deepEqual(fs.readFileSync(path.join(output, `${id}.wav`)), original, id);
  }
  const conflicting = run(['--missing', '--replace']);
  assert.ifError(conflicting.error);
  assert.notEqual(conflicting.status, 0);
  for (const id of themes) assert.deepEqual(fs.readFileSync(path.join(output, `${id}.wav`)), original, id);

  const result = run(['--replace']);
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Generated 4 original world soundtracks/);
  for (const id of ['ocean', 'space', 'jungle', 'candy']) {
    const bytes = fs.readFileSync(path.join(output, `${id}.wav`));
    assert.equal(bytes.toString('ascii', 0, 4), 'RIFF', id);
    assert.notDeepEqual(bytes, original, id);
  }
  for (const id of ['spring', 'summer', 'autumn', 'winter']) {
    assert.deepEqual(fs.readFileSync(path.join(output, `${id}.wav`)), original, id);
  }
});

test('required bundled audio includes both new worlds and rejects missing or invalid imports', (t) => {
  const { collectRequiredAudio } = require('../tools/package-web.cjs');
  const directory = fixture(t);
  const prompts = JSON.parse(fs.readFileSync(path.join(root, 'voice-prompts.json'), 'utf8'));
  fs.writeFileSync(path.join(directory, 'voice-prompts.json'), JSON.stringify(prompts));
  const expected = [
    'assets/audio/sfx/pop-launch.wav',
    'assets/audio/sfx/match-voice-hit.wav',
    ...['launch', 'impact', 'defeat'].map(id => `assets/audio/quest/${id}.wav`),
    ...themes.map(id => `assets/audio/bgm/${id}.wav`),
    ...Object.keys(prompts).map(id => `assets/audio/voice/${id}.wav`),
    ...themes.flatMap(id => ['press', 'charge', 'step', 'step-detail', 'step-roll', 'cancel', 'opening', 'unlock', 'release', 'settle', 'reward']
      .map(cue => `assets/audio/chests/${id}-${cue}.wav`)).sort()
  ];
  fs.mkdirSync(path.join(directory, '.godot/imported'), { recursive: true });
  for (const [index, source] of expected.entries()) {
    const metadata = path.join(directory, `${source}.import`);
    fs.mkdirSync(path.dirname(metadata), { recursive: true });
    fs.writeFileSync(path.join(directory, source), 'source fixture');
    fs.writeFileSync(metadata, `path="res://.godot/imported/${index}.sample"\n`);
    fs.writeFileSync(path.join(directory, '.godot/imported', `${index}.sample`), `RSRCfixture-${index}`);
  }
  const audio = collectRequiredAudio(directory);
  assert.deepEqual(audio.map(file => file.source), expected.map(source => `res://${source}`));
  assert.ok(audio.every(file => !file.source.includes('/audio/pop/')));
  assert.equal(new Set(audio.map(file => file.source)).size, expected.length);
  assert.equal(audio.filter(file => file.source.includes('/chests/')).length, 88);
  assert.ok(audio.some(file => file.source.endsWith('/summer-step-detail.wav')));
  assert.ok(audio.some(file => file.source.endsWith('/winter-step-roll.wav')));
  for (const id of added) {
    const sources = audio.map(file => file.source);
    assert.ok(sources.includes(`res://assets/audio/bgm/${id}.wav`));
    assert.ok(sources.includes(`res://assets/audio/voice/${id}-theme.wav`));
  }
  const lastImport = path.join(directory, `${expected.at(-1)}.import`);
  const original = fs.readFileSync(lastImport);
  fs.writeFileSync(lastImport, 'path="res://missing-resource"\n');
  assert.throws(() => collectRequiredAudio(directory), /before packaging required audio/);
  fs.writeFileSync(lastImport, original);
  const lastResource = path.join(directory, '.godot/imported', `${expected.length - 1}.sample`);
  fs.writeFileSync(lastResource, 'invalid resource');
  assert.throws(() => collectRequiredAudio(directory), /Expected an imported Godot audio resource/);
  fs.writeFileSync(lastResource, 'RSRC restored fixture');
  fs.unlinkSync(lastImport);
  assert.throws(() => collectRequiredAudio(directory), /winter-unlock\.wav\.import/,
    'A missing chest cue cannot silently disappear from the required bundle');
  fs.writeFileSync(lastImport, original);
  fs.unlinkSync(path.join(directory, 'assets/audio/bgm/candy.wav.import'));
  assert.throws(() => collectRequiredAudio(directory), /candy\.wav\.import/);
});
