const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {
  SOURCE_SHA256, SOURCE_BYTES, DESTINATION, DEFAULT_SOURCE,
  checkJellyRewardArt, prepareJellyRewardArt
} = require('../tools/prepare-jelly-reward-art.cjs');

const repoRoot = path.resolve(__dirname, '..');
const localSource = [path.join(repoRoot, DESTINATION), DEFAULT_SOURCE].find(file => fs.existsSync(file));

function fixture(t, withSource = false) {
  const parent = fs.realpathSync(os.tmpdir());
  const root = fs.mkdtempSync(path.join(parent, 'jelly-reward-art-'));
  t.after(() => {
    const target = fs.realpathSync(root);
    assert.equal(path.dirname(target), parent, 'Cleanup remains inside the temporary directory');
    assert.match(path.basename(target), /^jelly-reward-art-/);
    fs.rmSync(target, { recursive: true, force: true });
  });
  if (withSource) prepareJellyRewardArt({ root, source: localSource });
  return { root, output: path.join(root, DESTINATION), metadata: path.join(root, DESTINATION + '.import') };
}

function needSource(t) {
  if (localSource) return true;
  t.skip('Restore the private reviewed Toon FX atlas to check exact copying and import metadata.');
  return false;
}

test('build verification rejects a missing private atlas without creating files', t => {
  const { root } = fixture(t);
  assert.throws(() => checkJellyRewardArt(root), /private Jelly confetti atlas is missing/);
  assert.deepEqual(fs.readdirSync(root), []);
});

test('build verification rejects an unexpected size and same-size changed content without replacing it', t => {
  const { root, output } = fixture(t);
  fs.mkdirSync(path.dirname(output), { recursive: true });
  for (const wrong of [Buffer.from('unreviewed source'), Buffer.alloc(SOURCE_BYTES, 0xff)]) {
    fs.writeFileSync(output, wrong);
    assert.throws(() => checkJellyRewardArt(root), /does not match the reviewed/);
    assert.deepEqual(fs.readFileSync(output), wrong);
    assert.equal(fs.existsSync(output + '.import'), false);
  }
});

test('exact source restoration is reproducible and preserves an engine-assigned resource UID', t => {
  if (!needSource(t)) return;
  const { root, output, metadata } = fixture(t);
  const source = path.join(root, 'source.png');
  fs.copyFileSync(localSource, source);
  const report = prepareJellyRewardArt({ root, source });
  assert.equal(report.sha256, SOURCE_SHA256);
  assert.equal(report.bytes, SOURCE_BYTES);
  assert.deepEqual(report.size, [512, 512]);
  assert.deepEqual(fs.readFileSync(output), fs.readFileSync(source));
  const uid = 'uid="uid://testconfetti123"';
  fs.writeFileSync(metadata, fs.readFileSync(metadata, 'utf8').replace('type="CompressedTexture2D"', 'type="CompressedTexture2D"\n' + uid));
  const initialMetadata = fs.readFileSync(metadata, 'utf8');
  const initialMtime = fs.statSync(output).mtimeMs;
  assert.deepEqual(prepareJellyRewardArt({ root, source }), report);
  assert.equal(fs.statSync(output).mtimeMs, initialMtime);
  assert.equal(fs.readFileSync(metadata, 'utf8'), initialMetadata);
  assert.deepEqual(checkJellyRewardArt(root), report);
  assert.equal(fs.statSync(output).mtimeMs, initialMtime);
});

test('an unreviewed restoration source cannot damage an existing verified atlas or metadata', t => {
  if (!needSource(t)) return;
  const { root, output, metadata } = fixture(t, true);
  const before = fs.readFileSync(output);
  const importBefore = fs.readFileSync(metadata);
  const wrong = path.join(root, 'unexpected.png');
  fs.writeFileSync(wrong, Buffer.alloc(SOURCE_BYTES));
  assert.throws(() => prepareJellyRewardArt({ root, source: wrong }), /does not match the reviewed/);
  assert.deepEqual(fs.readFileSync(output), before);
  assert.deepEqual(fs.readFileSync(metadata), importBefore);
});

test('a valid atlas without import metadata fails verification and remains unchanged', t => {
  if (!needSource(t)) return;
  const { root, output, metadata } = fixture(t, true);
  fs.unlinkSync(metadata);
  const before = fs.readFileSync(output);
  assert.throws(() => checkJellyRewardArt(root), /lossless import settings are missing/);
  assert.deepEqual(fs.readFileSync(output), before);
  assert.equal(fs.existsSync(metadata), false);
});

test('verification rejects lossy, resized, remapped or redirected imports without mutating them', t => {
  if (!needSource(t)) return;
  const { root, metadata } = fixture(t, true);
  const original = fs.readFileSync(metadata, 'utf8');
  const invalid = [
    original.replace('compress/mode=0', 'compress/mode=1'),
    original.replace('mipmaps/generate=false', 'mipmaps/generate=true'),
    original.replace('process/size_limit=0', 'process/size_limit=128'),
    original.replace('process/channel_remap/alpha=3', 'process/channel_remap/alpha=0'),
    original.replace('process/premult_alpha=false', 'process/premult_alpha=true'),
    original.replace('source_file="res://assets/', 'source_file="res://unexpected/'),
    original.replace(/dest_files=\[.*\]/, 'dest_files=["res://unexpected.ctex"]'),
    original + '\ncompress/mode=1\n'
  ];
  for (const changed of invalid) {
    fs.writeFileSync(metadata, changed);
    assert.throws(() => checkJellyRewardArt(root), /lossless import settings|repeats a setting/);
    assert.equal(fs.readFileSync(metadata, 'utf8'), changed);
  }
});

test('the jelly test group retains the milestone scene suite and includes private art validation', () => {
  const plan = require('../tools/run-tests.cjs').createPlan(['jelly']);
  assert.ok(plan.godot.some(suite => suite.file === 'tests/godot/jelly_chest_celebration_tests.gd'));
  assert.ok(plan.node.includes('tests/jelly-reward-art.test.cjs'));
});
