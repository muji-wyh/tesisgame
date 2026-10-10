const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {
  TEXTURES, DEFAULT_SOURCE_DIRECTORY, checkChestMilestoneArt, prepareChestMilestoneArt
} = require('../tools/prepare-chest-milestone-art.cjs');

const repoRoot = path.resolve(__dirname, '..');
const sources = TEXTURES.map(texture => [path.join(repoRoot, texture.destination),
  path.join(DEFAULT_SOURCE_DIRECTORY, texture.source)].find(filename => fs.existsSync(filename)));

function fixture(t) {
  const parent = fs.realpathSync(os.tmpdir());
  const root = fs.mkdtempSync(path.join(parent, 'chest-milestone-art-'));
  t.after(() => {
    const target = fs.realpathSync(root);
    assert.equal(path.dirname(target), parent, 'Cleanup remains inside the temporary directory');
    assert.match(path.basename(target), /^chest-milestone-art-/);
    fs.rmSync(target, { recursive: true, force: true });
  });
  return { root, sourceDirectory: path.join(root, 'source') };
}

function needSources(t, context) {
  if (sources.some(filename => !filename)) {
    t.skip('Restore the two reviewed private Toon FX textures to test exact copying and import settings.');
    return false;
  }
  fs.mkdirSync(context.sourceDirectory);
  TEXTURES.forEach((texture, index) => fs.copyFileSync(sources[index], path.join(context.sourceDirectory, texture.source)));
  return true;
}

test('build verification rejects missing private chest textures without writing files', t => {
  const { root } = fixture(t);
  assert.throws(() => checkChestMilestoneArt(root), /private chest milestone texture is missing/);
  assert.deepEqual(fs.readdirSync(root), []);
});

test('both source files must validate before preparation changes any output', t => {
  const context = fixture(t);
  if (!needSources(t, context)) return;
  const secondSource = path.join(context.sourceDirectory, TEXTURES[1].source);
  const secondBytes = fs.readFileSync(secondSource);
  secondBytes[100] ^= 1;
  fs.writeFileSync(secondSource, secondBytes);
  assert.throws(() => prepareChestMilestoneArt(context), /sparkle.png does not match the reviewed/);
  assert.deepEqual(fs.readdirSync(context.root), ['source']);
});

test('preparation copies both sources exactly and retains existing resource UIDs without rewriting files', t => {
  const context = fixture(t);
  if (!needSources(t, context)) return;
  const report = prepareChestMilestoneArt(context);
  for (const [index, texture] of TEXTURES.entries()) {
    const filename = path.join(context.root, texture.destination);
    assert.deepEqual(report[index], { path: texture.destination, bytes: texture.bytes, sha256: texture.sha256,
      size: [512, 512], import: 'Lossless RGBA; no mipmaps or texture resizing' });
    assert.deepEqual(fs.readFileSync(filename), fs.readFileSync(path.join(context.sourceDirectory, texture.source)));
    const metadata = fs.readFileSync(filename + '.import', 'utf8');
    fs.writeFileSync(filename + '.import', metadata.replace('type="CompressedTexture2D"',
      `type="CompressedTexture2D"\nuid="uid://testchest${index}"`));
  }
  const before = TEXTURES.map(texture => {
    const filename = path.join(context.root, texture.destination);
    return { mtime: fs.statSync(filename).mtimeMs, metadata: fs.readFileSync(filename + '.import', 'utf8'),
      importMtime: fs.statSync(filename + '.import').mtimeMs };
  });
  assert.deepEqual(prepareChestMilestoneArt(context), report);
  assert.deepEqual(checkChestMilestoneArt(context.root), report);
  TEXTURES.forEach((texture, index) => {
    const filename = path.join(context.root, texture.destination);
    assert.equal(fs.statSync(filename).mtimeMs, before[index].mtime);
    assert.equal(fs.statSync(filename + '.import').mtimeMs, before[index].importMtime);
    assert.equal(fs.readFileSync(filename + '.import', 'utf8'), before[index].metadata);
  });
});

for (const texture of TEXTURES) {
  test(`${texture.source}: rejects missing, truncated and same-size modified art without replacing it`, t => {
    const context = fixture(t);
    if (!needSources(t, context)) return;
    prepareChestMilestoneArt(context);
    const filename = path.join(context.root, texture.destination);
    const metadata = fs.readFileSync(filename + '.import');
    fs.unlinkSync(filename);
    assert.throws(() => checkChestMilestoneArt(context.root), /private chest milestone texture is missing/);
    for (const invalid of [Buffer.from('unreviewed'), Buffer.alloc(texture.bytes)]) {
      fs.writeFileSync(filename, invalid);
      assert.throws(() => checkChestMilestoneArt(context.root), /does not match the reviewed/);
      assert.deepEqual(fs.readFileSync(filename), invalid);
      assert.deepEqual(fs.readFileSync(filename + '.import'), metadata);
    }
  });

  test(`${texture.source}: rejects absent and altered import settings without restoring them`, t => {
    const context = fixture(t);
    if (!needSources(t, context)) return;
    prepareChestMilestoneArt(context);
    const filename = path.join(context.root, texture.destination);
    const metadataPath = filename + '.import';
    const original = fs.readFileSync(metadataPath, 'utf8');
    const art = fs.readFileSync(filename);
    fs.unlinkSync(metadataPath);
    assert.throws(() => checkChestMilestoneArt(context.root), /lossless import settings are missing/);
    assert.equal(fs.existsSync(metadataPath), false);
    const invalidSettings = [
      original.replace('compress/mode=0', 'compress/mode=1'),
      original.replace('compress/normal_map=0', 'compress/normal_map=1'),
      original.replace('compress/channel_pack=0', 'compress/channel_pack=1'),
      original.replace('mipmaps/generate=false', 'mipmaps/generate=true'),
      original.replace('process/size_limit=0', 'process/size_limit=128'),
      original.replace('process/channel_remap/alpha=3', 'process/channel_remap/alpha=0'),
      original.replace('process/premult_alpha=false', 'process/premult_alpha=true'),
      original.replace('source_file="res://assets/', 'source_file="res://unexpected/'),
      original.replace(/dest_files=\[.*\]/, 'dest_files=["res://unexpected.ctex"]'),
      original + '\ncompress/mode=1\n'
    ];
    for (const changed of invalidSettings) {
      fs.writeFileSync(metadataPath, changed);
      assert.throws(() => checkChestMilestoneArt(context.root), /lossless import settings|repeats a setting/);
      assert.equal(fs.readFileSync(metadataPath, 'utf8'), changed);
      assert.deepEqual(fs.readFileSync(filename), art);
    }
  });
}

test('an invalid second replacement source leaves both existing textures and imports unchanged', t => {
  const context = fixture(t);
  if (!needSources(t, context)) return;
  prepareChestMilestoneArt(context);
  const filenames = TEXTURES.flatMap(texture => [texture.destination, texture.destination + '.import'])
    .map(filename => path.join(context.root, filename));
  const before = filenames.map(filename => fs.readFileSync(filename));
  fs.writeFileSync(path.join(context.sourceDirectory, TEXTURES[1].source), Buffer.alloc(TEXTURES[1].bytes));
  assert.throws(() => prepareChestMilestoneArt(context), /does not match the reviewed/);
  filenames.forEach((filename, index) => assert.deepEqual(fs.readFileSync(filename), before[index]));
});

test('the jelly test group includes private chest milestone art verification', () => {
  assert.ok(require('../tools/run-tests.cjs').createPlan(['jelly']).node.includes('tests/chest-milestone-art.test.cjs'));
});
