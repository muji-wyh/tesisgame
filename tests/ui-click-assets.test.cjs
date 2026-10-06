const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { readUiClickAudio } = require('../tools/ui-click-audio.cjs');
const { uiClickFixture } = require('./helpers/ui-click-assets.cjs');

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ui-click-audio-'));
  t.after(() => {
    assert.equal(path.dirname(root), os.tmpdir());
    fs.rmSync(root, { recursive: true, force: true });
  });
  return { root, ...uiClickFixture(root) };
}

function replaceBytes(fixture, bytes) {
  fs.writeFileSync(fixture.filename, bytes);
  fixture.asset.sha256 = createHash('sha256').update(bytes).digest('hex');
  fixture.writeManifest();
}

test('the menu cue is a complete validated 80 ms PCM16 recording', t => {
  const sample = fixture(t);
  const result = readUiClickAudio(sample.root);
  assert.deepEqual(result.asset, sample.asset);
  assert.deepEqual(result.bytes, sample.bytes);
  assert.equal(result.asset.seconds, 0.08);
});

test('a missing or replaced menu recording cannot silently fall back during packaging', t => {
  const sample = fixture(t);
  fs.unlinkSync(sample.filename);
  assert.throws(() => readUiClickAudio(sample.root));
  const changed = Buffer.from(sample.bytes);
  changed.writeInt16LE(changed.readInt16LE(200) + 1, 200);
  fs.writeFileSync(sample.filename, changed);
  assert.throws(() => readUiClickAudio(sample.root), /hash mismatch/i);
  fs.writeFileSync(sample.filename, sample.bytes);
  const extra = path.join(path.dirname(sample.filename), 'extra.wav');
  fs.writeFileSync(extra, sample.bytes);
  assert.throws(() => readUiClickAudio(sample.root), /exactly select\.wav/);
  fs.unlinkSync(extra);
  fs.unlinkSync(sample.manifestPath);
  assert.throws(() => readUiClickAudio(sample.root), /ENOENT/);
});

test('the importer requires the reviewed source and preserves installed audio on a mismatched input', t => {
  const sample = fixture(t);
  const source = path.join(sample.root, 'unreviewed.mp4');
  fs.writeFileSync(source, 'This is not the supplied source recording.');
  const { importUiClick, SOURCE_SHA256, START, SECONDS } = require('../tools/import-ui-click.cjs');
  const manifest = require('../docs/assets/ui-click-audio.json');
  assert.equal(manifest.source.sha256, SOURCE_SHA256);
  assert.deepEqual(manifest.assets[0].window, { start: START, seconds: SECONDS });
  assert.ok(START >= 0 && START + SECONDS <= 5, 'The excerpt comes from the requested first five seconds');
  assert.throws(() => importUiClick({ source, root: sample.root, ffmpeg: 'must-not-run' }),
    /does not match the reviewed button-click reference/);
  assert.deepEqual(fs.readFileSync(sample.filename), sample.bytes);
  assert.deepEqual(JSON.parse(fs.readFileSync(sample.manifestPath)), { assets: sample.assets });
});

test('the menu manifest cannot redirect the source or declare an ambiguous bank', t => {
  const sample = fixture(t);
  for (const change of [
    { id: 'wrong' }, { destination: '../outside.wav' }, { seconds: 0.02 }, { seconds: 0.16 },
    { seconds: null }, { channels: 2 }, { sampleRate: 48000 }, { bitDepth: 8 }, { sha256: 'invalid' }
  ]) {
    fs.writeFileSync(sample.manifestPath, JSON.stringify({ assets: [{ ...sample.asset, ...change }] }));
    assert.throws(() => readUiClickAudio(sample.root), undefined, JSON.stringify(change));
  }
  for (const assets of [[], [sample.asset, sample.asset]]) {
    fs.writeFileSync(sample.manifestPath, JSON.stringify({ assets }));
    assert.throws(() => readUiClickAudio(sample.root));
  }
});

test('matching hashes do not permit malformed audio or a mismatched duration', t => {
  const sample = fixture(t);
  const changes = [
    bytes => bytes.writeUInt32LE(bytes.length - 9, 4),
    bytes => bytes.writeUInt16LE(3, 20),
    bytes => bytes.writeUInt16LE(2, 22),
    bytes => bytes.writeUInt32LE(48000, 24),
    bytes => bytes.writeUInt32LE(44100, 28),
    bytes => bytes.writeUInt16LE(4, 32),
    bytes => bytes.writeUInt16LE(8, 34),
    bytes => bytes.writeUInt32LE(bytes.length - 46, 40)
  ];
  for (const change of changes) {
    const changed = Buffer.from(sample.bytes);
    change(changed);
    replaceBytes(sample, changed);
    assert.throws(() => readUiClickAudio(sample.root));
  }
  replaceBytes(sample, sample.bytes);
  sample.asset.seconds = 0.09;
  sample.writeManifest();
  assert.throws(() => readUiClickAudio(sample.root));
});

test('the loading shell embeds the same validated cue used by native menus', t => {
  const root = path.resolve(__dirname, '..');
  if (!fs.existsSync(path.join(root, 'assets/imported-audio/ui-click/select.wav'))) {
    return t.skip('The supplied reference excerpt must be imported before building the game.');
  }
  const { bytes } = readUiClickAudio(root);
  const { inlineMascot } = require('../tools/prepare-godot.cjs');
  const shell = inlineMascot('<img src="$PIP_MASCOT_URI"><audio src="$UI_CLICK_URI"></audio>');
  const embedded = shell.match(/<audio src="data:audio\/wav;base64,([A-Za-z0-9+/=]+)"><\/audio>/);
  assert.ok(embedded, 'The menu sound must be ready before the engine has finished downloading');
  assert.deepEqual(Buffer.from(embedded[1], 'base64'), bytes);
  assert.doesNotMatch(shell, /\$UI_CLICK_URI/);
});
