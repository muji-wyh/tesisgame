const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');

test('Grow with Pip branding keeps the existing internal save identity', () => {
  const shell = fs.readFileSync(path.join(root, 'web', 'shell.html'), 'utf8');
  assert.match(shell, /<title>Grow with Pip<\/title>/);
  assert.match(shell, /id="loading-title">Grow with Pip<\/h1>/);
  assert.match(shell, /aria-label="Grow with Pip word game"/);
  const project = fs.readFileSync(path.join(root, 'project.godot'), 'utf8');
  assert.match(project, /^config\/name="Word Buddies"$/m);
  assert.match(shell, /wordBuddies\.medalProgress/);
  assert.match(shell, /wordBuddies\.playroom/);
});

test('the web bootstrap references only existing script dependencies', () => {
  const source = fs.readFileSync(path.join(root, 'scripts', 'web_bootstrap.gd'), 'utf8');
  const dependencies = source.match(/const SCRIPTS := \[([\s\S]*?)\]/)?.[1];
  assert.ok(dependencies, 'The startup dependency list must be present');
  for (const [, name] of dependencies.matchAll(/"([a-z_]+)"/g)) {
    assert.ok(fs.existsSync(path.join(root, 'scripts', `${name}.gd`)), `Missing startup dependency: ${name}`);
  }
});

test('the delivery preset exports a single-threaded Godot Web game with JSON data', () => {
  const filename = path.join(root, 'export_presets.cfg');
  assert.ok(fs.existsSync(filename), 'The Web export preset is missing');
  const preset = fs.readFileSync(filename, 'utf8');
  assert.match(preset, /platform="Web"/);
  assert.match(preset, /variant\/thread_support=false/);
  assert.match(preset, /variant\/extensions_support=false/);
  assert.match(preset, /include_filter="[^"]*words\.json[^"]*assets\/chests\/manifest\.json/);
  assert.ok(preset.match(/^include_filter="([^"]*)"$/m)[1].split(',').includes('phrases.json'),
    'The raw phrase catalog must be available to the exported native game');
  assert.match(preset, /html\/custom_html_shell="res:\/\/web\/shell\.html"/);
  assert.match(preset, /html\/canvas_resize_policy=0/);
  assert.match(preset, /html\/focus_canvas_on_start=false/);
  assert.match(preset, /html\/experimental_virtual_keyboard=false/,
    'The removed profile editor no longer requires the native keyboard bridge');
  const excluded = preset.match(/^exclude_filter="([^"]*)"$/m)[1].split(',');
  for (const word of JSON.parse(fs.readFileSync(path.join(root, 'words.json'), 'utf8'))) {
    for (const source of [word.image, word.audio]) {
      assert.equal(excluded.some(pattern => path.matchesGlob(source, pattern)), false,
        `Every vocabulary picture and recording must survive export: ${source}`);
    }
  }
  for (const source of [
    'assets/audio/bgm/spring.wav',
    'assets/audio/chests/spring-settle.wav', 'assets/audio/voice/spring-theme.wav',
    ...['step', 'step-detail', 'step-roll', 'release', 'reward'].map(cue => `assets/imported-audio/chest-reference/${cue}.wav`),
    'assets/imported-audio/pair-feedback/right.wav', 'assets/imported-audio/pair-feedback/wrong.wav',
    'assets/imported-audio/ui-click/select.wav',
    ...JSON.parse(fs.readFileSync(path.join(root, 'phrases.json'), 'utf8')).map(phrase => phrase.audio)
  ]) {
    assert.equal(excluded.some(pattern => path.matchesGlob(source, pattern)), false,
      `Active audio must be included in the game pack: ${source}`);
  }
  for (const source of ['assets/audio/voice/ocean-arrive.wav', 'assets/audio/voice/ocean-open.wav']) {
    assert.ok(excluded.some(pattern => path.matchesGlob(source, pattern)), `Retired audio stays excluded: ${source}`);
  }
  for (const name of ['ready.wav', 'high-five.wav', 'round-20.wav']) {
    const source = `assets/audio/pop/${name}`;
    assert.ok(excluded.some(pattern => path.matchesGlob(source, pattern)), `Unused spoken reports stay out of the game pack: ${source}`);
  }
  assert.doesNotMatch(preset.match(/^include_filter="([^"]*)"$/m)[1], /pop-voice-prompts\.json/);
  const project = fs.readFileSync(path.join(root, 'project.godot'), 'utf8');
  assert.match(project, /textures\/vram_compression\/import_s3tc_bptc=true/);
  assert.match(project, /textures\/vram_compression\/import_etc2_astc=true/);
});

test('the export shell hosts the engine and fits a safe-area container without disabling zoom', () => {
  const filename = path.join(root, 'web', 'shell.html');
  assert.ok(fs.existsSync(filename), 'The Godot Web shell is missing');
  const shell = fs.readFileSync(filename, 'utf8');
  assert.match(shell, /\$GODOT_URL/);
  assert.match(shell, /\$GODOT_CONFIG/);
  assert.match(shell, /<canvas\b/);
  assert.match(shell, /safe-area-inset/);
  assert.match(shell, /ResizeObserver/);
  assert.match(shell, /prefers-reduced-motion/);
  assert.match(shell, /visibilitychange/);
  assert.match(shell, /engineReady/);
  assert.match(shell, /id="game-status"/);
  assert.match(shell, /id="audio-status"/);
  assert.match(shell, /--audio-driver/);
  assert.match(shell, /Dummy/);
  assert.doesNotMatch(shell, /user-scalable\s*=\s*no|maximum-scale\s*=\s*1/);
  assert.doesNotMatch(shell, /GameCore|selectCard|createRound/);
  // All game speech uses bundled recordings from the approved voice profile.
  assert.doesNotMatch(shell, /speechSynthesis|SpeechSynthesisUtterance|speakPopSummary/);
});

test('build-only typography and wardrobe sources stay reproducible without duplicate pack resources', () => {
  const preset = fs.readFileSync(path.join(root, 'export_presets.cfg'), 'utf8');
  const excluded = preset.match(/^exclude_filter="([^"]*)"$/m)[1].split(',');
  for (const source of ['assets/fonts/Nunito-600.ttf', 'assets/fonts/Nunito-800.ttf',
    'assets/images/mascots/outfits/wardrobe.svg']) {
    assert.ok(fs.statSync(path.join(root, source)).size > 0, `Keep the reproducible build input: ${source}`);
    assert.ok(excluded.includes(source), `Exclude only the unused pack copy: ${source}`);
  }
  const shell = require('../tools/prepare-godot.cjs').inlineMascot(
    '$PIP_MASCOT_URI $INTERFACE_BODY_FONT_URI $INTERFACE_HEADING_FONT_URI');
  const fonts = [...shell.matchAll(/data:font\/ttf;base64,([A-Za-z0-9+/=]+)/g)];
  assert.equal(fonts.length, 2, 'The browser shell must still embed both static fonts');
  for (const [index, name] of ['Nunito-600.ttf', 'Nunito-800.ttf'].entries()) {
    assert.deepEqual(Buffer.from(fonts[index][1], 'base64'), fs.readFileSync(path.join(root, 'assets/fonts', name)));
  }
  for (const name of ['body', 'heading']) {
    assert.match(fs.readFileSync(path.join(root, `assets/fonts/${name}.tres`), 'utf8'),
      /path="res:\/\/assets\/fonts\/Nunito\.ttf"/);
  }
  for (const source of ['assets/fonts/Nunito.ttf', 'assets/fonts/body.tres', 'assets/fonts/heading.tres',
    ...['spring', 'summer', 'autumn', 'winter', 'ocean', 'space', 'jungle', 'candy'].flatMap(theme =>
      ['', '-idle', '-parts'].map(suffix => `assets/images/mascots/outfits/pip-${theme}${suffix}.svg`))]) {
    assert.equal(excluded.some(pattern => path.matchesGlob(source, pattern)), false,
      `Keep the runtime font and outfit resources: ${source}`);
  }
});

test('the Godot command runner waits for the engine and propagates its real failure status', () => {
  const filename = path.join(root, 'tools', 'run-godot.cjs');
  assert.ok(fs.existsSync(filename), 'The Godot process runner is missing');
  const { runGodot } = require(filename);
  assert.match(runGodot(['--version']).stdout, /^4\.7\./);
  assert.throws(
    () => runGodot(['--headless', '--path', root, '--script', 'res://tests/godot/exit_code.gd']),
    /exit 7/
  );
});

test('accessible help describes the current controls rather than the removed motion menu', () => {
  const shell = fs.readFileSync(path.join(root, 'web', 'shell.html'), 'utf8');
  const help = shell.match(/<p\b[^>]*id="help"[^>]*>([\s\S]*?)<\/p>/)?.[1];
  assert.ok(help, 'The canvas needs accessible gameplay instructions.');
  assert.doesNotMatch(help, /\bFX\b|season menu|Reduce motion button/i);
  assert.match(help, /device.*reduced-motion/i);
  assert.match(help, /Keep trying until every pair is matched/);
  assert.doesNotMatch(shell, /speech-successes|speech-mistakes|speech-score|roundProgress|Three mistakes/);
});

test('the web shell retires Talk Quest without accessing or clearing its saved progress', () => {
  const shell = fs.readFileSync(path.join(root, 'web', 'shell.html'), 'utf8');
  const help = shell.match(/<p\b[^>]*id="help"[^>]*>([\s\S]*?)<\/p>/)?.[1];
  assert.match(help, /Choose Match, Memory, Voice Pop, Phrase Builder, or Jelly Match\./);
  assert.doesNotMatch(shell, /Talk Quest|quest-status|createQuestHost|questHost|questProgress|saveQuestProgress|questStatus|observeQuestSpeech|questTargets?/);
  assert.doesNotMatch(shell, /wordBuddies\.talkQuest|localStorage\.clear\s*\(/,
    'Retired adventure progress stays on the device and is neither read nor erased');
});

function referenceBankFixture(t, populated = true) {
  const directory = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'voice-pop-reference-export-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const bank = path.join(directory, 'assets/imported-audio/pop-reference');
  const manifestPath = path.join(directory, 'docs/assets/voice-pop-reference-audio.json');
  const writeImport = source => {
    const sourcePath = path.join(directory, source);
    const imported = `.godot/imported/${path.basename(source)}-fixture.sample`;
    fs.mkdirSync(path.dirname(sourcePath), { recursive: true });
    fs.mkdirSync(path.join(directory, '.godot/imported'), { recursive: true });
    fs.writeFileSync(`${sourcePath}.import`, `[remap]\npath="res://${imported}"\n`);
    fs.writeFileSync(path.join(directory, imported), 'RSRC fixture audio');
    return imported;
  };
  const entries = ['quick', 'juicy', 'crisp', 'launch'].map((id, index) => {
    const samples = id === 'launch' ? 10584 : 13230;
    const wav = Buffer.alloc(44 + samples * 2);
    wav.write('RIFF'); wav.writeUInt32LE(wav.length - 8, 4); wav.write('WAVEfmt ', 8);
    wav.writeUInt32LE(16, 16); wav.writeUInt16LE(1, 20); wav.writeUInt16LE(1, 22);
    wav.writeUInt32LE(44100, 24); wav.writeUInt32LE(88200, 28); wav.writeUInt16LE(2, 32); wav.writeUInt16LE(16, 34);
    wav.write('data', 36); wav.writeUInt32LE(samples * 2, 40);
    for (let frame = 0; frame < samples; frame++) wav.writeInt16LE(Math.round(Math.sin(frame * (0.04 + index * 0.01)) * 8000), 44 + frame * 2);
    return { id, destination: `assets/imported-audio/pop-reference/${id}.wav`,
      sha256: require('node:crypto').createHash('sha256').update(wav).digest('hex'),
      seconds: samples / 44100, sampleRate: 44100, channels: 1, bitDepth: 16, wav };
  });
  const assets = entries.slice(0, 3);
  const launch = entries[3];
  const writeManifest = () => {
    fs.mkdirSync(path.dirname(manifestPath), { recursive: true });
    fs.writeFileSync(manifestPath, JSON.stringify({ assets: assets.map(({ wav, ...asset }) => asset),
      launch: (({ wav, ...asset }) => asset)(launch) }));
  };
  if (populated) {
    fs.mkdirSync(bank, { recursive: true });
    for (const asset of entries) {
      fs.writeFileSync(path.join(directory, asset.destination), asset.wav);
      writeImport(asset.destination);
    }
    writeManifest();
  }
  return { directory, bank, assets, launch, manifestPath, writeManifest, writeImport };
}

test('an absent optional Voice Pop reference bank preserves clean-checkout packaging', t => {
  const fixture = referenceBankFixture(t, false);
  assert.deepEqual(require('../tools/package-web.cjs').collectPopReferenceAudio(fixture.directory), []);
});

test('the complete Voice Pop reference bank joins the required in-pack audio inventory', t => {
  const fixture = referenceBankFixture(t);
  const { collectPopReferenceAudio, collectRequiredAudio } = require('../tools/package-web.cjs');
  const reference = collectPopReferenceAudio(fixture.directory);
  assert.deepEqual(reference.map(asset => asset.source), [...fixture.assets, fixture.launch].map(asset => `res://${asset.destination}`));
  assert.ok(reference.every(asset => asset.imported.startsWith('res://.godot/imported/') && asset.bytes.length > 4));
  fs.writeFileSync(path.join(fixture.directory, 'voice-prompts.json'), '{}');
  const phrases = JSON.parse(fs.readFileSync(path.join(root, 'phrases.json'), 'utf8'));
  fs.writeFileSync(path.join(fixture.directory, 'phrases.json'), JSON.stringify(phrases));
  for (const phrase of phrases) fixture.writeImport(phrase.audio);
  fixture.writeImport('assets/audio/sfx/pop-launch.wav');
  for (const cue of ['merge', 'clear', 'land', 'danger']) fixture.writeImport(`assets/audio/jelly-match/${cue}.wav`);
  require('./helpers/pair-feedback-assets.cjs').pairFeedbackFixture(fixture.directory, fixture.writeImport);
  require('./helpers/ui-click-assets.cjs').uiClickFixture(fixture.directory, fixture.writeImport);
  const chest = require('./helpers/chest-reference-assets.cjs').chestReferenceFixture(fixture.directory, fixture.writeImport);
  for (const theme of ['spring', 'summer', 'autumn', 'winter', 'ocean', 'space', 'jungle', 'candy']) {
    fixture.writeImport(`assets/audio/bgm/${theme}.wav`);
    for (const cue of ['press', 'charge', 'cancel', 'opening', 'unlock', 'settle']) {
      fixture.writeImport(`assets/audio/chests/${theme}-${cue}.wav`);
    }
  }
  const required = collectRequiredAudio(fixture.directory);
  assert.equal(required.length, 403);
  assert.equal(required.filter(asset => asset.source.includes('/jelly-match/')).length, 4,
    'Every Jelly cue is required in the startup pack');
  assert.deepEqual(required.slice(-4), reference);
  assert.ok(required.some(asset => asset.source === 'res://assets/audio/sfx/pop-launch.wav'),
    'The source-checkout launch fallback also ships in the startup pack');
  for (const id of ['right', 'wrong']) {
    assert.ok(required.some(asset => asset.source === `res://assets/imported-audio/pair-feedback/${id}.wav`),
      'Pair feedback ships in the startup pack without a later fetch');
  }
  assert.ok(required.some(asset => asset.source === 'res://assets/imported-audio/ui-click/select.wav'),
    'Native menu feedback ships in the startup pack without a later fetch');
  assert.deepEqual(required.filter(asset => asset.source.includes('/chest-reference/')).map(asset => asset.source),
    chest.assets.map(asset => `res://${asset.destination}`), 'Five shared chest recordings each ship once in the pack');
  assert.deepEqual(required.filter(asset => asset.source.includes('/voice/phrase-')).map(asset => asset.source),
    phrases.map(phrase => `res://${phrase.audio}`), 'Every whole-phrase recording is verified as a required resource');
  assert.ok(required.every(asset => !asset.source.startsWith('res://assets/audio/quest/')),
    'Retired adventure audio is no longer a required packaging input');
  assert.ok(required.every(asset => asset.source.startsWith('res://') && asset.imported.startsWith('res://')),
    'Reference slices remain required pack resources without an HTTP audio map');
  assert.ok(required.every(asset => !asset.source.startsWith('res://assets/audio/pop/')),
    'Retired report narration is not a required packaging input');
});

test('pair feedback is required and rejects missing, extra, tampered, and malformed recordings', t => {
  const fixture = referenceBankFixture(t, false);
  const { collectPairFeedbackAudio } = require('../tools/package-web.cjs');
  assert.throws(() => collectPairFeedbackAudio(fixture.directory), /ENOENT/);
  const pair = require('./helpers/pair-feedback-assets.cjs').pairFeedbackFixture(fixture.directory, fixture.writeImport);
  assert.deepEqual(collectPairFeedbackAudio(fixture.directory).map(asset => asset.source),
    pair.assets.map(asset => `res://${asset.destination}`));
  const filename = path.join(fixture.directory, pair.assets[0].destination);
  const original = fs.readFileSync(filename);
  fs.unlinkSync(filename);
  assert.throws(() => collectPairFeedbackAudio(fixture.directory), /requires exactly/);
  fs.writeFileSync(filename, original);
  const extra = path.join(path.dirname(filename), 'extra.wav');
  fs.writeFileSync(extra, original);
  assert.throws(() => collectPairFeedbackAudio(fixture.directory), /requires exactly/);
  fs.unlinkSync(extra);
  const invalid = Buffer.from(original);
  invalid.writeUInt16LE(2, 22);
  fs.writeFileSync(filename, invalid);
  assert.throws(() => collectPairFeedbackAudio(fixture.directory), /hash mismatch/);
  pair.assets[0].sha256 = require('node:crypto').createHash('sha256').update(invalid).digest('hex');
  pair.writeManifest();
  assert.throws(() => collectPairFeedbackAudio(fixture.directory), /Invalid mono PCM16/);
});

test('shared chest recordings are required and reject incomplete, extra, tampered or malformed banks', t => {
  const fixture = referenceBankFixture(t, false);
  const { collectChestReferenceAudio } = require('../tools/package-web.cjs');
  assert.throws(() => collectChestReferenceAudio(fixture.directory), /ENOENT/);
  const chest = require('./helpers/chest-reference-assets.cjs').chestReferenceFixture(fixture.directory, fixture.writeImport);
  assert.deepEqual(collectChestReferenceAudio(fixture.directory).map(asset => asset.source),
    chest.assets.map(asset => `res://${asset.destination}`));
  const filename = path.join(fixture.directory, chest.assets[0].destination);
  const original = fs.readFileSync(filename);
  fs.unlinkSync(filename);
  assert.throws(() => collectChestReferenceAudio(fixture.directory), /requires exactly/);
  fs.writeFileSync(filename, original);
  const extra = path.join(path.dirname(filename), 'extra.wav');
  fs.writeFileSync(extra, original);
  assert.throws(() => collectChestReferenceAudio(fixture.directory), /requires exactly/);
  fs.unlinkSync(extra);
  const invalid = Buffer.from(original);
  invalid.writeUInt16LE(2, 22);
  fs.writeFileSync(filename, invalid);
  assert.throws(() => collectChestReferenceAudio(fixture.directory), /hash mismatch/);
  chest.assets[0].sha256 = require('node:crypto').createHash('sha256').update(invalid).digest('hex');
  chest.writeManifest();
  assert.throws(() => collectChestReferenceAudio(fixture.directory), /Invalid mono PCM16/);
});

test('shared chest metadata cannot redirect, truncate or ambiguously declare the required recordings', t => {
  const fixture = referenceBankFixture(t, false);
  const chest = require('./helpers/chest-reference-assets.cjs').chestReferenceFixture(fixture.directory, fixture.writeImport);
  const { collectChestReferenceAudio } = require('../tools/package-web.cjs');
  for (const change of [
    { id: 'other' }, { destination: '../outside.wav' }, { seconds: 0.20 }, { seconds: null },
    { channels: 2 }, { sampleRate: 48000 }, { bitDepth: 8 }, { sha256: 'invalid' }
  ]) {
    fs.writeFileSync(chest.manifestPath, JSON.stringify({ assets: [{ ...chest.assets[0], ...change }, ...chest.assets.slice(1)] }));
    assert.throws(() => collectChestReferenceAudio(fixture.directory), /Invalid chest reference manifest entry/);
  }
  for (const assets of [[], [...chest.assets, chest.assets[0]], [...chest.assets].reverse()]) {
    fs.writeFileSync(chest.manifestPath, JSON.stringify({ assets }));
    assert.throws(() => collectChestReferenceAudio(fixture.directory));
  }
  chest.writeManifest();
  const filename = path.join(fixture.directory, chest.assets[3].destination);
  const truncated = fs.readFileSync(filename).subarray(0, 44 + 44100);
  truncated.writeUInt32LE(truncated.length - 8, 4);
  truncated.writeUInt32LE(truncated.length - 44, 40);
  fs.writeFileSync(filename, truncated);
  chest.assets[3].sha256 = require('node:crypto').createHash('sha256').update(truncated).digest('hex');
  chest.writeManifest();
  assert.throws(() => collectChestReferenceAudio(fixture.directory), /Invalid mono PCM16/,
    'A valid WAV header and matching hash cannot hide a truncated release');
});

test('a partial or ambiguous Voice Pop reference bank fails instead of shipping mixed fallback audio', t => {
  const { collectPopReferenceAudio } = require('../tools/package-web.cjs');
  const fixture = referenceBankFixture(t);
  fs.unlinkSync(path.join(fixture.bank, 'crisp.wav'));
  assert.throws(() => collectPopReferenceAudio(fixture.directory), /incomplete/);
  fs.writeFileSync(path.join(fixture.bank, 'crisp.wav'), fixture.assets[2].wav);
  fs.writeFileSync(path.join(fixture.bank, 'extra.wav'), fixture.assets[2].wav);
  assert.throws(() => collectPopReferenceAudio(fixture.directory), /unexpected WAVs/);
  fs.unlinkSync(path.join(fixture.bank, 'extra.wav'));
  fixture.assets[0].destination = '../outside.wav';
  fixture.writeManifest();
  assert.throws(() => collectPopReferenceAudio(fixture.directory), /Invalid.*manifest/);
});

test('Voice Pop reference source validation rejects changed bytes and malformed WAV metadata', t => {
  const { collectPopReferenceAudio } = require('../tools/package-web.cjs');
  const fixture = referenceBankFixture(t);
  const filename = path.join(fixture.directory, fixture.assets[0].destination);
  const invalid = Buffer.from(fixture.assets[0].wav);
  invalid.writeUInt16LE(2, 22);
  fs.writeFileSync(filename, invalid);
  assert.throws(() => collectPopReferenceAudio(fixture.directory), /hash mismatch/);
  fixture.assets[0].sha256 = require('node:crypto').createHash('sha256').update(invalid).digest('hex');
  fixture.writeManifest();
  assert.throws(() => collectPopReferenceAudio(fixture.directory), /Invalid mono PCM16/);
  fs.writeFileSync(filename, fixture.assets[0].wav);
  fixture.assets[0].sha256 = require('node:crypto').createHash('sha256').update(fixture.assets[0].wav).digest('hex');
  fixture.assets[0].seconds += 0.01;
  fixture.writeManifest();
  assert.throws(() => collectPopReferenceAudio(fixture.directory), /Invalid mono PCM16/);
});

test('the reference launch is separately validated and never treated as a hit variant', t => {
  const { collectPopReferenceAudio } = require('../tools/package-web.cjs');
  const fixture = referenceBankFixture(t);
  assert.equal(fixture.assets.length, 3);
  fs.unlinkSync(path.join(fixture.directory, fixture.launch.destination));
  assert.throws(() => collectPopReferenceAudio(fixture.directory), /incomplete/);
  fs.writeFileSync(path.join(fixture.directory, fixture.launch.destination), fixture.launch.wav);
  const malformed = JSON.parse(fs.readFileSync(fixture.manifestPath));
  delete malformed.launch;
  fs.writeFileSync(fixture.manifestPath, JSON.stringify(malformed));
  assert.throws(() => collectPopReferenceAudio(fixture.directory), /Invalid.*launch/);
  fixture.launch.seconds = 0.4;
  fixture.writeManifest();
  assert.throws(() => collectPopReferenceAudio(fixture.directory), /Invalid.*launch/);
});

test('Voice Pop reference packaging rejects missing, unsafe or invalid Godot imports', t => {
  const { collectPopReferenceAudio } = require('../tools/package-web.cjs');
  const fixture = referenceBankFixture(t);
  const asset = fixture.assets[0];
  const metadata = path.join(fixture.directory, `${asset.destination}.import`);
  fs.unlinkSync(metadata);
  assert.throws(() => collectPopReferenceAudio(fixture.directory), /ENOENT/);
  fs.writeFileSync(metadata, '[remap]\npath="res://.godot/imported/../outside.sample"\n');
  assert.throws(() => collectPopReferenceAudio(fixture.directory), /Import.*before packaging/);
  const imported = fixture.writeImport(asset.destination);
  fs.writeFileSync(path.join(fixture.directory, imported), 'not an imported sample');
  assert.throws(() => collectPopReferenceAudio(fixture.directory), /Expected an imported Godot audio resource/);
});

test('Web delivery compresses and fingerprints assets without mixing cached game versions', (t) => {
  const filename = path.join(root, 'tools', 'package-web.cjs');
  assert.ok(fs.existsSync(filename), 'The mobile Web export packager is missing');
  const { packageWebExport } = require(filename);
  const { brotliDecompressSync } = require('node:zlib');
  const directory = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'word-buddies-web-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const files = {
    'index.js': Buffer.from(startupFixture),
    'index.wasm': Buffer.from('engine bytecode '.repeat(8192)),
    'index.audio.worklet.js': Buffer.from('audio worklet'),
    'index.audio.position.worklet.js': Buffer.from('position worklet'),
    'index.pck': Buffer.from('game data and bundled audio '.repeat(1024))
  };
  const writeExport = () => {
    for (const [name, bytes] of Object.entries(files)) fs.writeFileSync(path.join(directory, name), bytes);
    fs.writeFileSync(path.join(directory, 'index.html'),
      `<script src="index.js"></script><script>const config = ${JSON.stringify({
        executable: 'index', args: [], audioAssets: { 'res://assets/audio/voice/spring-theme.wav': 'retired.sample' }, fileSizes: {
          'index.wasm': files['index.wasm'].length,
          'index.pck': files['index.pck'].length
        }
      })};</script>`);
  };
  const readConfig = () => JSON.parse(fs.readFileSync(path.join(directory, 'index.html'), 'utf8')
    .match(/const config = (\{[^\r\n]*\});/)[1]);
  writeExport();
  fs.writeFileSync(path.join(directory, 'keep.txt'), 'unrelated file');
  const initialBytes = packageWebExport(directory);
  const first = readConfig();
  assert.match(first.executable, /^engine-[a-f0-9]{16}$/);
  assert.match(first.mainPack, /^game-[a-f0-9]{16}\.pck$/);
  const digest = require('node:crypto').createHash('sha256');
  for (const [name, bytes] of Object.entries(files).filter(([name]) => !name.endsWith('.pck'))) {
    digest.update(name.slice('index.'.length)).update(name === 'index.js'
      ? require('../tools/patch-web-engine.cjs').patchWebEngine(bytes.toString()) : bytes);
  }
  assert.equal(first.executable, `engine-${digest.digest('hex').slice(0, 16)}`, 'Cache keys must hash the patched engine');
  for (const [name, bytes] of Object.entries(files)) {
    const target = name.endsWith('.pck') ? first.mainPack : name.replace('index', first.executable);
    const expected = name === 'index.js'
      ? Buffer.from(require('../tools/patch-web-engine.cjs').patchWebEngine(bytes.toString())) : bytes;
    assert.deepEqual(fs.readFileSync(path.join(directory, target)), expected);
    assert.deepEqual(brotliDecompressSync(fs.readFileSync(path.join(directory, `${target}.br`))), expected);
    assert.equal(fs.existsSync(path.join(directory, name)), false, 'Unversioned engine/data files must not be shipped');
  }
  assert.equal(first.fileSizes[`${first.executable}.wasm`], files['index.wasm'].length);
  assert.equal(first.fileSizes[first.mainPack], files['index.pck'].length);
  assert.ok(fs.readFileSync(path.join(directory, 'index.html'), 'utf8').includes(`src="${first.executable}.js"`));
  assert.ok(fs.statSync(path.join(directory, `${first.executable}.wasm.br`)).size < files['index.wasm'].length / 4);
  assert.equal(first.audioAssets, undefined, 'Bundled audio must not publish an on-demand URL map');
  assert.equal(fs.readdirSync(directory).some(name => name.endsWith('.sample') || name.endsWith('.sample.br')), false,
    'Audio is delivered only inside the game pack');
  assert.equal(initialBytes, fs.readdirSync(directory).filter(name => name.endsWith('.br'))
    .reduce((total, name) => total + fs.statSync(path.join(directory, name)).size, 0),
  'Startup size must count every compressed engine and game-pack byte');
  writeExport();
  assert.equal(packageWebExport(directory), initialBytes, 'Identical exports retain the same startup size');
  assert.equal(readConfig().mainPack, first.mainPack, 'Identical game packs retain their cache key');

  files['index.pck'] = Buffer.from('game data and updated bundled audio');
  writeExport();
  packageWebExport(directory);
  const second = readConfig();
  assert.equal(second.executable, first.executable, 'Game changes must reuse the cached engine');
  assert.notEqual(second.mainPack, first.mainPack, 'An audio update inside the game pack must use a new cache key');
  assert.equal(fs.existsSync(path.join(directory, first.mainPack)), false, 'Obsolete generated packs must not accumulate');
  assert.equal(fs.readFileSync(path.join(directory, 'keep.txt'), 'utf8'), 'unrelated file');
  files['index.js'] = Buffer.from('changed Godot template');
  writeExport();
  const beforeFailure = new Map(fs.readdirSync(directory, { recursive: true }).filter(name => fs.statSync(path.join(directory, name)).isFile()).map(name => [name, fs.readFileSync(path.join(directory, name))]));
  assert.throws(() => packageWebExport(directory), /Godot Web startup patch/);
  assert.deepEqual(new Map(fs.readdirSync(directory, { recursive: true }).filter(name => fs.statSync(path.join(directory, name)).isFile()).map(name => [name, fs.readFileSync(path.join(directory, name))])), beforeFailure,
    'An unknown engine must fail before overwriting or deleting any export file');
  const config = JSON.parse(fs.readFileSync(path.join(root, 'web', 'staticwebapp.config.json'), 'utf8'));
  assert.equal(config.globalHeaders['Cache-Control'], 'no-cache', 'HTML must discover updated asset names');
  assert.equal(config.globalHeaders.Vary, 'Accept-Encoding', 'Caches must distinguish compressed and identity responses');
  for (const route of ['/engine-*', '/game-*']) {
    assert.equal(config.routes.find(entry => entry.route === route).headers['Cache-Control'],
      'public, max-age=31536000, immutable');
  }
});

test('Pip growth preview stays local and is removed from an older Web export without touching neighboring files', t => {
  const fixture = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'pip-growth-export-'));
  t.after(() => fs.rmSync(fixture, { recursive: true, force: true }));
  const source = path.join(fixture, 'web/preview/pip-growth');
  const directory = path.join(fixture, 'build/web');
  const output = path.join(directory, 'preview/pip-growth');
  const original = path.join(root, 'web/preview/pip-growth');
  const write = (base, name, bytes) => {
    const filename = path.join(base, name);
    fs.mkdirSync(path.dirname(filename), { recursive: true });
    fs.writeFileSync(filename, bytes);
  };
  // Keep all cache and stale-output fixtures outside the real source and export.
  for (const name of ['package-web.cjs', 'patch-web-engine.cjs', 'ui-click-audio.cjs', 'chest-reference-audio.cjs']) {
    write(fixture, `tools/${name}`, fs.readFileSync(path.join(root, 'tools', name)));
  }
  const catalog = JSON.parse(fs.readFileSync(path.join(original, 'stages.json'), 'utf8'));
  assert.equal(catalog.stages.length, 10);
  const previewFiles = ['index.html', 'preview.js', 'preview.css', 'stages.json',
    'Nunito-600.ttf', 'Nunito-800.ttf', 'FONT-LICENSE.txt', 'audio/manifest.json',
    ...catalog.stages.flatMap(stage => [...Object.values(stage.previewArt), stage.newVoice.previewPath])].sort();
  for (const name of previewFiles) {
    const bytes = fs.readFileSync(path.join(original, name));
    write(source, name, bytes);
    write(output, name, bytes);
  }
  const helpers = ['.gitignore', 'generate.cjs', 'verify.cjs', 'review.cjs'];
  for (const name of helpers) {
    write(source, name, fs.readFileSync(path.join(original, name)));
    write(output, name, 'stale helper from a previous export');
  }
  write(source, '.voice-cache/recording.mp3', 'private voice generation cache');
  write(source, 'review-output/desktop.png', 'local review capture');
  write(output, '.voice-cache/recording.mp3', 'old private cache');
  write(output, 'review-output/desktop.png', 'old local capture');
  write(directory, 'preview/keep/index.html', 'unrelated preview');
  write(directory, 'notes.txt', 'unrelated output');
  const writeExport = () => {
    write(directory, 'index.html', '<script src="index.js"></script><script>const config = {};</script>');
    for (const suffix of ['js', 'wasm', 'pck', 'audio.worklet.js', 'audio.position.worklet.js']) {
      write(directory, `index.${suffix}`, suffix === 'js' ? startupFixture : suffix);
    }
  };

  const { packageWebExport } = require(path.join(fixture, 'tools/package-web.cjs'));
  for (let pass = 0; pass < 2; pass++) {
    writeExport();
    packageWebExport(directory);
    assert.equal(fs.existsSync(output), false, 'Neither stale nor freshly copied Pip preview files may ship');
    assert.equal(fs.readFileSync(path.join(directory, 'preview/keep/index.html'), 'utf8'), 'unrelated preview');
    assert.equal(fs.readFileSync(path.join(directory, 'notes.txt'), 'utf8'), 'unrelated output');
  }

  for (const name of [...previewFiles, ...helpers]) {
    assert.deepEqual(fs.readFileSync(path.join(source, name)), fs.readFileSync(path.join(original, name)),
      `Keep the localhost preview source intact: ${name}`);
  }
  assert.equal(fs.readFileSync(path.join(source, '.voice-cache/recording.mp3'), 'utf8'), 'private voice generation cache');
  assert.equal(fs.readFileSync(path.join(source, 'review-output/desktop.png'), 'utf8'), 'local review capture');
});

test('Pip growth preview cleanup does not follow linked folders outside the export', t => {
  const { packageWebExport } = require('../tools/package-web.cjs');
  const fixture = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'pip-growth-export-links-'));
  t.after(() => fs.rmSync(fixture, { recursive: true, force: true }));
  const directory = path.join(fixture, 'export');
  const external = path.join(fixture, 'local-only');
  fs.mkdirSync(directory);
  fs.mkdirSync(path.join(external, 'pip-growth'), { recursive: true });
  const sentinel = path.join(external, 'pip-growth/index.html');
  fs.writeFileSync(sentinel, 'preserve local preview');
  const writeExport = () => {
    fs.writeFileSync(path.join(directory, 'index.html'), '<script src="index.js"></script><script>const config = {};</script>');
    for (const suffix of ['js', 'wasm', 'pck', 'audio.worklet.js', 'audio.position.worklet.js']) {
      fs.writeFileSync(path.join(directory, `index.${suffix}`), suffix === 'js' ? startupFixture : suffix);
    }
  };
  const preview = path.join(directory, 'preview');
  fs.symlinkSync(external, preview, process.platform === 'win32' ? 'junction' : 'dir');
  writeExport();
  assert.throws(() => packageWebExport(directory), /Refusing to clean a linked preview directory/);
  assert.equal(fs.readFileSync(sentinel, 'utf8'), 'preserve local preview');
  fs.unlinkSync(preview);
  fs.mkdirSync(preview);
  fs.symlinkSync(path.join(external, 'pip-growth'), path.join(preview, 'pip-growth'), process.platform === 'win32' ? 'junction' : 'dir');
  writeExport();
  packageWebExport(directory);
  assert.equal(fs.existsSync(preview), false, 'Remove only the stale output link and its empty parent');
  assert.equal(fs.readFileSync(sentinel, 'utf8'), 'preserve local preview');
});

test('rebuilding a legacy export removes standalone audio and retired speech assets while preserving unrelated output', t => {
  const { packageWebExport } = require('../tools/package-web.cjs');
  const directory = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'voice-pop-solo-export-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const writeExport = () => {
    fs.writeFileSync(path.join(directory, 'index.html'),
      '<script src="index.js"></script><script>const config = {};</script>');
    for (const suffix of ['js', 'wasm', 'pck', 'audio.worklet.js', 'audio.position.worklet.js']) {
      fs.writeFileSync(path.join(directory, `index.${suffix}`), suffix === 'js' ? startupFixture : suffix);
    }
  };
  const legacyScripts = ['multiplayer-host.js', 'multiplayer-capture.js', 'multiplayer-audio.js', 'multiplayer-worker.js',
    'voice-profiles.js', 'voice-profiles-ui.js', 'voice-profiles.css'];
  const legacyAssets = ['encoder-0123456789abcdef.onnx', 'decoder-0123456789abcdef.onnx', 'joiner-0123456789abcdef.onnx',
    'speaker-0123456789abcdef.onnx', 'vad-0123456789abcdef.onnx', 'tokens-0123456789abcdef.txt',
    'bpe-0123456789abcdef.vocab', 'runtime-js-0123456789abcdef.js', 'runtime-wasm-0123456789abcdef.wasm',
    'manifest.json', 'THIRD_PARTY_NOTICES.txt'];
  fs.mkdirSync(path.join(directory, 'multiplayer'));
  const removed = [...legacyScripts, 'audio-0123456789abcdef.sample', ...legacyAssets.map(name => `multiplayer/${name}`)]
    .flatMap(name => [name, `${name}.br`, `${name}.gz`]);
  for (const name of removed) fs.writeFileSync(path.join(directory, name), 'retired generated asset');
  const preserved = ['notes.txt', 'multiplayer-notes.js', 'multiplayer/notes.txt', 'multiplayer/notes.vocab',
    'multiplayer/custom-0123456789abcdef.onnx'];
  for (const name of preserved) fs.writeFileSync(path.join(directory, name), 'keep unrelated output');
  writeExport();
  packageWebExport(directory);
  for (const name of removed) assert.equal(fs.existsSync(path.join(directory, name)), false, name);
  for (const name of preserved) assert.equal(fs.readFileSync(path.join(directory, name), 'utf8'), 'keep unrelated output', name);
  for (const name of preserved.filter(name => name.startsWith('multiplayer/'))) fs.unlinkSync(path.join(directory, name));
  writeExport();
  packageWebExport(directory);
  assert.equal(fs.existsSync(path.join(directory, 'multiplayer')), false, 'Empty retired asset directories should not ship');
});

function startupHarness(overrides = {}) {
  const { patchWebEngine } = require('../tools/patch-web-engine.cjs');
  const runtime = { initFS: async () => undefined };
  const sandbox = {
    Promise, Error, Response, ReadableStream,
    loadPath: 'index', Engine: { unload() {} },
    receiveInstance: instance => instance,
    Godot: async () => runtime,
    me: { config: { persistentPaths: ['/userfs'], getModuleConfig: () => ({}) }, rtenv: null },
    ...overrides
  };
  require('node:vm').runInNewContext(patchWebEngine(startupFixture), sandbox);
  return { sandbox, runtime, response: Promise.resolve(new Response(new Uint8Array(0))) };
}

async function trackedDownloadFinished(status) {
  const deadline = Date.now() + 1000;
  while (!status.done && Date.now() < deadline) await new Promise(setImmediate);
  assert.equal(status.done, true, 'Download monitoring must finish instead of leaving progress pending');
}

test('WASM progress preserves the fetched response and its native clone through engine initialization', async () => {
  const { sandbox } = startupHarness();
  let controller;
  const response = new Response(new ReadableStream({ start(value) { controller = value; } }), {
    headers: { 'content-type': 'application/wasm' }
  });
  const status = { loaded: 0, done: false };
  const tracked = sandbox.getTrackedResponse(response, status);
  assert.equal(tracked, response, 'Replacing a fetched Response discards browser WASM cache metadata');
  assert.equal(response.bodyUsed, false, 'Progress must read a clone, leaving the original body available');
  const clone = response.clone();
  response.clone = () => clone;
  let moduleSource;
  sandbox.me.config.getModuleConfig = (_, source) => { moduleSource = source; return {}; };
  await sandbox.doInit(Promise.resolve(tracked));
  assert.equal(moduleSource, clone, 'Correct WASM MIME must retain the native clone instead of synthesizing a Response');
  const bytes = moduleSource.arrayBuffer();
  controller.enqueue(new Uint8Array([0, 97, 115, 109]));
  controller.enqueue(new Uint8Array([1, 0, 0, 0]));
  controller.close();
  assert.deepEqual(new Uint8Array(await bytes), new Uint8Array([0, 97, 115, 109, 1, 0, 0, 0]));
  await trackedDownloadFinished(status);
  assert.equal(status.loaded, 8);
});

test('missing or incorrect WASM MIME retains the compatibility response and exact bytes', async () => {
  for (const contentType of [undefined, 'application/octet-stream']) {
    const { sandbox } = startupHarness();
    const response = new Response(new Uint8Array([0, 97, 115, 109]), {
      headers: contentType ? { 'content-type': contentType } : {}
    });
    const clone = response.clone();
    response.clone = () => clone;
    let moduleSource;
    sandbox.me.config.getModuleConfig = (_, source) => { moduleSource = source; return {}; };
    await sandbox.doInit(Promise.resolve(response));
    assert.notEqual(moduleSource, clone);
    assert.equal(moduleSource.headers.get('content-type'), 'application/wasm');
    assert.deepEqual(new Uint8Array(await moduleSource.arrayBuffer()), new Uint8Array([0, 97, 115, 109]));
  }
});

test('a progress-reader failure leaves the original download rejection observable and stops monitoring', async () => {
  const { sandbox, runtime } = startupHarness();
  const failure = new TypeError('Network body failed');
  let controller;
  const response = new Response(new ReadableStream({ start(value) { controller = value; } }), {
    headers: { 'content-type': 'application/wasm' }
  });
  const status = { loaded: 0, done: false };
  const tracked = sandbox.getTrackedResponse(response, status);
  sandbox.me.config.getModuleConfig = (_, source) => source;
  sandbox.Godot = async source => { await source.arrayBuffer(); return runtime; };
  const starting = sandbox.doInit(Promise.resolve(tracked));
  controller.error(failure);
  await rejectsWith(starting, failure);
  assert.equal(sandbox.me.rtenv, null);
  await trackedDownloadFinished(status);
  assert.equal(status.loaded, 0);
});

async function rejectsWith(promise, expected) {
  let timer;
  try {
    await assert.rejects(Promise.race([
      promise,
      new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('Startup stayed pending')), 1000); })
    ]), error => error === expected);
  } finally {
    clearTimeout(timer);
  }
}

test('the generated startup patch rejects missing, duplicate, and changed template anchors', () => {
  const { patchWebEngine } = require('../tools/patch-web-engine.cjs');
  assert.throws(() => patchWebEngine('unrecognized engine'), /Godot Web startup patch/);
  assert.throws(() => patchWebEngine(startupFixture.repeat(2)), /Godot Web startup patch/);
  for (const marker of ['Module["instantiateWasm"](info', "'instantiateWasm': function", 'function doInit(promise)', 'getDB:(name,callback)', 'function getTrackedResponse(response, load_status)', '_restart(){if(this._source!=null)', 'GodotAudio.ctx=ctx;ctx.onstatechange', 'GodotAudio.ctx=null;if(!ctx)', 'function _godot_audio_resume()', 'GodotAudio.audioPositionWorkletPromise=ctx.audioWorklet.addModule(path)', 'async connectPositionWorklet(start){await']) {
    assert.ok(startupFixture.includes(marker));
    assert.throws(() => patchWebEngine(startupFixture.replace(marker, `${marker} changed`)), /Godot Web startup patch/);
  }
  assert.throws(() => patchWebEngine(patchWebEngine(startupFixture)), /Godot Web startup patch/);
});

test('the patched engine shares and releases its existing context and tolerates blocked audio resumes', async () => {
  const { patchWebEngine } = require('../tools/patch-web-engine.cjs');
  const registered = [];
  let attempts = 0;
  const context = {
    state: 'suspended',
    resume() { attempts++; return Promise.reject(new Error('User gesture required')); },
    close() { this.state = 'closed'; return Promise.resolve(); }
  };
  const sandbox = {
    GodotAudio: {},
    window: { AudioContext: function () { return context; }, wordBuddiesHost: { attachAudioContext: value => registered.push(value) } }
  };
  require('node:vm').runInNewContext(patchWebEngine(startupFixture), sandbox);
  assert.equal(sandbox.audioInitFixture({}), context);
  assert.deepEqual(registered, [context], 'The host receives the actual engine context, not a new audio stack');
  sandbox._godot_audio_resume();
  await new Promise(resolve => setImmediate(resolve));
  context.resume = () => { attempts++; context.state = 'running'; return Promise.resolve(); };
  sandbox._godot_audio_resume();
  assert.equal(attempts, 2, 'A rejected attempt does not latch out the next user gesture');
  sandbox._godot_audio_resume();
  assert.equal(attempts, 2, 'A running context is not interrupted by extra resume calls');
  await new Promise(resolve => sandbox.audioCloseFixture.close_async(resolve));
  assert.deepEqual(registered, [context, null]);
  sandbox._godot_audio_resume();
  assert.equal(attempts, 2, 'Closing the engine removes the context from both recovery paths');
  sandbox.GodotAudio.ctx = { state: 'interrupted', resume() { throw new Error('Temporarily unavailable'); } };
  assert.doesNotThrow(() => sandbox._godot_audio_resume());
  sandbox.GodotAudio.ctx.state = 'closed';
  assert.doesNotThrow(() => sandbox._godot_audio_resume());
});

function positionWorkletHarness(source = require('../tools/patch-web-engine.cjs').patchWebEngine(startupFixture)) {
  const events = [];
  const sandbox = { GodotAudio: {}, window: {} };
  require('node:vm').runInNewContext(source, sandbox);
  function prepare(promise, context = { currentTime: 17, close: () => Promise.resolve() }) {
    sandbox.GodotAudio.ctx = context;
    context.audioWorklet = { addModule: () => promise };
    sandbox.positionWorkletInitFixture(context, 'position-worklet.js');
    return context;
  }
  function sample(id) {
    return Object.assign(Object.create(sandbox.SampleNode.prototype), {
      isCanceled: false, isStarted: false, startTime: 0, offset: 0,
      _source: {
        connect() { events.push(`connect:${id}`); },
        start() { events.push(`start:${id}`); }
      },
      getPositionWorklet() { return {}; }
    });
  }
  return { sandbox, events, prepare, sample };
}

test('prepared WebAudio hits start within the hit callback before subsequent frame work', async () => {
  for (const patched of [false, true]) {
    const { events, prepare, sample } = positionWorkletHarness(patched
      ? require('../tools/patch-web-engine.cjs').patchWebEngine(startupFixture) : startupFixture);
    prepare(Promise.resolve());
    await Promise.resolve();
    const starts = [sample('one'), sample('two'), sample('three')]
      .map(node => node.connectPositionWorklet(true));
    // Any expensive work after this marker blocks the old promise continuation,
    // even though the position worklet finished loading before the hit callback.
    events.push('remaining-game-frame-work');
    const expected = ['connect:one', 'start:one', 'connect:two', 'start:two', 'connect:three', 'start:three'];
    assert.deepEqual(events, patched ? [...expected, 'remaining-game-frame-work'] : ['remaining-game-frame-work']);
    await Promise.all(starts);
    assert.deepEqual(events, patched ? [...expected, 'remaining-game-frame-work'] : ['remaining-game-frame-work', ...expected]);
  }
});

test('initial WebAudio hits await worklet loading and preserve cancellation and connect-only requests', async () => {
  const { sandbox, events, prepare, sample } = positionWorkletHarness();
  let resolveModule;
  const loading = new Promise(resolve => { resolveModule = resolve; });
  const context = prepare(loading);
  const active = sample('active'), concurrent = sample('concurrent');
  const cancelled = sample('cancelled'), connected = sample('connected');
  const pending = [active.connectPositionWorklet(true), concurrent.connectPositionWorklet(true),
    cancelled.connectPositionWorklet(true), connected.connectPositionWorklet(false)];
  cancelled.isCanceled = true;
  assert.deepEqual(events, [], 'No source connects or starts before its worklet is available');
  resolveModule();
  await Promise.all(pending);
  assert.equal(sandbox.GodotAudio.audioPositionWorkletReadyContext, context);
  assert.deepEqual(events, ['connect:active', 'start:active', 'connect:concurrent', 'start:concurrent', 'connect:connected']);
  assert.equal(connected.isStarted, false);
  const stopped = sample('already-cancelled');
  stopped.isCanceled = true;
  await stopped.connectPositionWorklet(true);
  await sample('prepared-connect-only').connectPositionWorklet(false);
  assert.deepEqual(events.slice(5), ['connect:prepared-connect-only']);
});

test('rejected worklet preparation stays observable without marking audio ready or creating a detached rejection', async () => {
  const { sandbox, events, prepare, sample } = positionWorkletHarness();
  const failure = new Error('Position worklet could not load');
  let rejectModule;
  prepare(new Promise((_, reject) => { rejectModule = reject; }));
  const rejected = assert.rejects(sample('failed').connectPositionWorklet(true), error => error === failure);
  rejectModule(failure);
  await rejected;
  assert.equal(sandbox.GodotAudio.audioPositionWorkletReadyContext, null);
  assert.deepEqual(events, []);
  await assert.rejects(sample('still-failed').connectPositionWorklet(true), error => error === failure);
  // No sample may be requested at all when a page closes during initialization.
  // The readiness observer must handle this promise without a detached rejection.
  prepare(Promise.reject(failure));
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(sandbox.GodotAudio.audioPositionWorkletReadyContext, null);
});

test('late worklet completion cannot revive closed audio or mark a replacement context ready', async () => {
  const { sandbox, events, prepare, sample } = positionWorkletHarness();
  let resolveOld, resolveNew;
  const oldContext = prepare(new Promise(resolve => { resolveOld = resolve; }));
  const stale = sample('old').connectPositionWorklet(true);
  await new Promise(resolve => sandbox.audioCloseFixture.close_async(resolve));
  const newContext = prepare(new Promise(resolve => { resolveNew = resolve; }));
  const current = sample('new').connectPositionWorklet(true);
  resolveOld();
  await stale;
  assert.notEqual(newContext, oldContext);
  assert.equal(sandbox.GodotAudio.audioPositionWorkletReadyContext, null);
  assert.deepEqual(events, [], 'An obsolete completion neither starts its source nor bypasses the new load');
  resolveNew();
  await current;
  assert.equal(sandbox.GodotAudio.audioPositionWorkletReadyContext, newContext);
  assert.deepEqual(events, ['connect:new', 'start:new']);
  await new Promise(resolve => sandbox.audioCloseFixture.close_async(resolve));
  assert.equal(sandbox.GodotAudio.audioPositionWorkletReadyContext, null);
  await sample('after-close').connectPositionWorklet(true);
  assert.deepEqual(events, ['connect:new', 'start:new']);
});

test('looped WebAudio samples restore their pitch before a replacement source can render', () => {
  const { patchWebEngine } = require('../tools/patch-web-engine.cjs');
  function restartFixture(source, pitch, rate, paused = false) {
    const sources = [], starts = [], positionMessages = [];
    const buffer = { duration: 0.8 };
    const destination = {};
    const context = {
      currentTime: 17,
      createBufferSource() {
        const listeners = new Map();
        const source = {
          playbackRate: { value: 1 }, connections: [], disconnected: false,
          addEventListener(name, callback) { listeners.set(name, callback); },
          removeEventListener(name) { listeners.delete(name); },
          disconnect() { this.disconnected = true; },
          connect(node) { this.connections.push(node); },
          start(time, offset) { starts.push({ rate: this.playbackRate.value, time, offset }); },
          ended() { listeners.get('ended')?.(); }
        };
        sources.push(source);
        return source;
      }
    };
    const sandbox = { GodotAudio: { ctx: context } };
    require('node:vm').runInNewContext(source, sandbox);
    const node = Object.assign(Object.create(sandbox.SampleNode.prototype), {
      _source: context.createBufferSource(), _onended: null,
      _sampleNodeBuses: new Map([[0, { getInputNode: () => destination }]]),
      _positionWorklet: { port: { postMessage: message => positionMessages.push(message.type) } },
      _playbackRate: rate, _pitchScale: pitch, startTime: 0, offset: 0.125,
      pauseTime: paused ? 0.3 : 0, isPaused: paused, isStarted: true,
      getSample: () => ({ getAudioBuffer: () => buffer, loopMode: 'forward' })
    });
    node._addEndedListener();
    if (paused) node._unpause();
    else sources[0].ended();
    assert.equal(sources.length, 2, 'A single loop or resume replaces exactly one source');
    assert.equal(sources[0].disconnected, true);
    assert.equal(sources[1].buffer, buffer);
    assert.deepEqual(sources[1].connections, [destination, node._positionWorklet]);
    assert.deepEqual(positionMessages, ['clear']);
    assert.equal(starts[0].offset, paused ? 0.425 : 0.125);
    assert.equal(node.isStarted, true);
    assert.equal(node.isPaused, false);
    return starts[0].rate;
  }
  // Establish the engine regression using its independent source snapshot:
  // the new source starts at 1 even while the stored pitch is already 1.85.
  assert.equal(restartFixture(startupFixture, 1.85, 1), 1);
  const patched = patchWebEngine(startupFixture);
  for (const [pitch, rate] of [[0.8, 1], [1.85, 1], [1.55, 0.5]]) {
    for (const paused of [false, true]) {
      assert.equal(restartFixture(patched, pitch, rate, paused), pitch * rate,
        'Playback rate must be correct in start(), before any later game frame');
    }
  }
});

test('streaming and fallback compilation failures reach initialization with the original cause', async () => {
  for (const streaming of [true, false]) {
    for (const ErrorType of [Error, RangeError]) {
      for (const synchronous of [false, true]) {
        const failure = new ErrorType('Allocation failed');
        const instantiate = synchronous ? () => { throw failure; } : async () => { throw failure; };
        const { sandbox, runtime, response } = startupHarness({
          WebAssembly: streaming ? { instantiateStreaming: instantiate } : { instantiate }
        });
        sandbox.Godot = config => {
          sandbox.Module = config;
          return sandbox.createWasm().then(() => runtime);
        };
        sandbox.me.config.getModuleConfig = () => sandbox.makeModuleConfig({ arrayBuffer: async () => new ArrayBuffer(0) });
        await rejectsWith(sandbox.doInit(response), failure);
        assert.equal(sandbox.me.rtenv, null);
      }
    }
  }
  const failure = new Error('Response body failed');
  const { sandbox } = startupHarness({ WebAssembly: {} });
  sandbox.Module = sandbox.makeModuleConfig({ arrayBuffer: async () => { throw failure; } });
  await rejectsWith(sandbox.createWasm(), failure);
  const callbackFailure = new Error('Instance initialization failed');
  const callbackHarness = startupHarness({
    WebAssembly: { instantiateStreaming: async () => ({ instance: {}, module: {} }) },
    receiveInstance() { throw callbackFailure; }
  }).sandbox;
  callbackHarness.Module = callbackHarness.makeModuleConfig({});
  await rejectsWith(callbackHarness.createWasm(), callbackFailure);
});

test('load, module, filesystem, and synchronous startup errors propagate while ordinary IDB denial stays compatible', async () => {
  for (const stage of ['load', 'clone', 'module', 'module-sync', 'filesystem', 'filesystem-sync', 'storage-blocked']) {
    const failure = new Error(stage);
    const { sandbox, runtime, response } = startupHarness();
    let load = response;
    if (stage === 'load') load = Promise.reject(failure);
    if (stage === 'clone') load = Promise.resolve({ clone() { throw failure; } });
    if (stage === 'module') sandbox.Godot = async () => { throw failure; };
    if (stage === 'module-sync') sandbox.Godot = () => { throw failure; };
    if (stage === 'filesystem') runtime.initFS = async () => { throw failure; };
    if (stage === 'filesystem-sync') runtime.initFS = () => { throw failure; };
    if (stage === 'storage-blocked') {
      failure.name = 'StorageBlockedError';
      runtime.initFS = async () => failure;
    }
    await rejectsWith(sandbox.doInit(load), failure);
    assert.equal(sandbox.me.rtenv, null);
  }
  const { sandbox, runtime, response } = startupHarness();
  runtime.initFS = async () => new DOMException('Private browser', 'SecurityError');
  await sandbox.doInit(response);
  assert.equal(sandbox.me.rtenv, runtime);
});

test('blocked IDB upgrades fail once, abort late migration, and close late connections without caching them', () => {
  const { sandbox } = startupHarness();
  const request = {};
  sandbox.IDBFS.indexedDB = () => ({ open: () => request });
  const results = [];
  sandbox.IDBFS.getDB('/userfs', (...args) => results.push(args));
  request.onblocked();
  request.onblocked();
  assert.equal(results.length, 1);
  assert.equal(results[0][0].name, 'StorageBlockedError');
  assert.match(results[0][0].message, /close.*other.*game.*tab/i);
  let aborted = 0;
  request.onupgradeneeded({ target: { transaction: { abort() { aborted++; } } } });
  assert.equal(aborted, 1);
  let prevented = 0;
  request.onerror({ target: { error: new Error('AbortError') }, preventDefault() { prevented++; } });
  let closed = 0;
  request.result = { close() { closed++; } };
  request.onsuccess();
  assert.equal(prevented, 1);
  assert.equal(closed, 1);
  assert.equal(results.length, 1);
  assert.equal(sandbox.IDBFS.dbs['/userfs'], undefined);
});

test('normal IDB connections remain cached and access denial keeps its original error', () => {
  const { sandbox } = startupHarness();
  const request = { result: {} };
  sandbox.IDBFS.indexedDB = () => ({ open: () => request });
  const results = [];
  sandbox.IDBFS.getDB('/userfs', (...args) => results.push(args));
  request.onsuccess();
  assert.equal(results.length, 1);
  assert.equal(results[0][0], null);
  assert.equal(results[0][1], request.result);
  assert.equal(sandbox.IDBFS.dbs['/userfs'], request.result);
  sandbox.IDBFS.getDB('/userfs', (...args) => results.push(args));
  assert.equal(results.length, 2);
  const failure = new DOMException('Access denied', 'SecurityError');
  sandbox.IDBFS.indexedDB = () => ({ open() { throw failure; } });
  sandbox.IDBFS.getDB('/other', error => assert.equal(error, failure));
});

// Kept independently from the patch strings so template drift cannot silently pass.
const startupFixture = String.raw`// Snapshot of the relevant unmodified Godot 4.7.1 release-template code.
	function getTrackedResponse(response, load_status) {
		function onloadprogress(reader, controller) {
			return reader.read().then(function (result) {
				if (load_status.done) {
					return Promise.resolve();
				}
				if (result.value) {
					controller.enqueue(result.value);
					load_status.loaded += result.value.length;
				}
				if (!result.done) {
					return onloadprogress(reader, controller);
				}
				load_status.done = true;
				return Promise.resolve();
			});
		}
		const reader = response.body.getReader();
		return new Response(new ReadableStream({
			start: function (controller) {
				onloadprogress(reader, controller).then(function () {
					controller.close();
				});
			},
		}), { headers: response.headers });
	}

function createWasm() {
  const info = {};
  if(Module["instantiateWasm"]){return new Promise((resolve,reject)=>{Module["instantiateWasm"](info,(inst,mod)=>{resolve(receiveInstance(inst,mod))})})}
}
function makeModuleConfig(response) {
  let r = response;
  return {
			'instantiateWasm': function (imports, onSuccess) {
				function done(result) {
					onSuccess(result['instance'], result['module']);
				}
				if (typeof (WebAssembly.instantiateStreaming) !== 'undefined') {
					WebAssembly.instantiateStreaming(Promise.resolve(r), imports).then(done);
				} else {
					r.arrayBuffer().then(function (buffer) {
						WebAssembly.instantiate(buffer, imports).then(done);
					});
				}
				r = null;
				return {};
			},
  };
}
				function doInit(promise) {
					// Care! Promise chaining is bogus with old emscripten versions.
					// This caused a regression with the Mono build (which uses an older emscripten version).
					// Make sure to test that when refactoring.
					return new Promise(function (resolve, reject) {
						promise.then(function (response) {
							const cloned = new Response(response.clone().body, { 'headers': [['content-type', 'application/wasm']] });
							Godot(me.config.getModuleConfig(loadPath, cloned)).then(function (module) {
								const paths = me.config.persistentPaths;
								module['initFS'](paths).then(function (err) {
									me.rtenv = module;
									if (me.config.unloadAfterInit) {
										Engine.unload();
									}
									resolve();
								});
							});
						});
					});
				}

var IDBFS = { dbs: {}, DB_VERSION: 21, DB_STORE_NAME: 'FILE_DATA', getDB:(name,callback)=>{var db=IDBFS.dbs[name];if(db){return callback(null,db)}var req;try{req=IDBFS.indexedDB().open(name,IDBFS.DB_VERSION)}catch(e){return callback(e)}if(!req){return callback("Unable to connect to IndexedDB")}req.onupgradeneeded=e=>{var db=e.target.result;var transaction=e.target.transaction;var fileStore;if(db.objectStoreNames.contains(IDBFS.DB_STORE_NAME)){fileStore=transaction.objectStore(IDBFS.DB_STORE_NAME)}else{fileStore=db.createObjectStore(IDBFS.DB_STORE_NAME)}if(!fileStore.indexNames.contains("timestamp")){fileStore.createIndex("timestamp","timestamp",{unique:false})}};req.onsuccess=()=>{db=req.result;IDBFS.dbs[name]=db;callback(null,db)};req.onerror=e=>{callback(e.target.error);e.preventDefault()}} };

function audioInitFixture(opts){const ctx=new(window.AudioContext||window.webkitAudioContext)(opts);GodotAudio.ctx=ctx;ctx.onstatechange=function(){};return ctx}
function positionWorkletInitFixture(ctx,path){GodotAudio.audioPositionWorkletPromise=ctx.audioWorklet.addModule(path);}
var audioCloseFixture={close_async:function(resolve,reject){const ctx=GodotAudio.ctx;GodotAudio.ctx=null;if(!ctx){resolve();return}ctx.close().then(resolve)}};
function _godot_audio_resume(){if(GodotAudio.ctx&&GodotAudio.ctx.state!=="running"){GodotAudio.ctx.resume()}}

var SampleNode = class SampleNode {
getPlaybackRate(){return this._playbackRate}getPitchScale(){return this._pitchScale}getOutputNode(){return this._source}
start(){if(this.isStarted){return}this._resetSourceStartTime();this._source.start(this.startTime,this.offset);this.isStarted=true}
async connectPositionWorklet(start){await GodotAudio.audioPositionWorkletPromise;if(this.isCanceled){return}this._source.connect(this.getPositionWorklet());if(start){this.start()}}
restart(){this.isPaused=false;this.pauseTime=0;this._resetSourceStartTime();this._restart()}
connect(node){return this.getOutputNode().connect(node)}
_resetSourceStartTime(){this._sourceStartTime=GodotAudio.ctx.currentTime}
_syncPlaybackRate(){this._source.playbackRate.value=this.getPlaybackRate()*this.getPitchScale()}
_restart(){if(this._source!=null){this._source.disconnect()}this._source=GodotAudio.ctx.createBufferSource();this._source.buffer=this.getSample().getAudioBuffer();for(const sampleNodeBus of this._sampleNodeBuses.values()){this.connect(sampleNodeBus.getInputNode())}this._addEndedListener();const pauseTime=this.isPaused?this.pauseTime:0;if(this._positionWorklet!=null){this._positionWorklet.port.postMessage({type:"clear"});this._source.connect(this._positionWorklet)}this._source.start(this.startTime,this.offset+pauseTime);this.isStarted=true}
_unpause(){this._restart();this.isPaused=false;this.pauseTime=0}
_addEndedListener(){if(this._onended!=null){this._source.removeEventListener("ended",this._onended)}const self=this;this._onended=_=>{if(self.isPaused){return}switch(self.getSample().loopMode){case"disabled":self.stop();break;case"forward":case"backward":self.restart();break;default:}};this._source.addEventListener("ended",this._onended)}
};
`;
