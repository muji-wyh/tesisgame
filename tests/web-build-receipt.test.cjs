const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createHash } = require('node:crypto');
const { brotliCompressSync } = require('node:zlib');
const { snapshotInputs, invalidateBuildReceipt, writeBuildReceipt, verifyBuildReceipt } = require('../tools/web-build-receipt.cjs');

function fixture(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'web-build-receipt-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const write = (name, contents) => {
    const filename = path.join(root, name);
    fs.mkdirSync(path.dirname(filename), { recursive: true });
    fs.writeFileSync(filename, contents);
    return filename;
  };
  write('project.godot', 'config_version=5');
  write('scripts/game.gd', 'extends Node');
  write('assets/chests/models/private.glb', 'private model bytes');
  write('web/shell.html', 'source shell');
  const pack = Buffer.from('A complete native game pack with bundled art and audio');
  const mainPack = `game-${createHash('sha256').update(pack).digest('hex').slice(0, 16)}.pck.br`;
  const config = { executable: 'engine-0123456789abcdef', mainPack, fileSizes: { [mainPack]: pack.length } };
  config.vocabularyPacks = {};
  for (let age = 3; age <= 12; age++) {
    const bytes = Buffer.from(`GDPC vocabulary age ${age}`);
    const sha256 = createHash('sha256').update(bytes).digest('hex');
    const file = `vocabulary-${age}-${sha256.slice(0, 16)}.pck.br`;
    config.vocabularyPacks[age] = { file, bytes: bytes.length, sha256, dependencies: [] };
    write(`build/web/${file}`, brotliCompressSync(bytes));
  }
  write('build/web/index.html', `<script>const config = ${JSON.stringify(config)};</script>`);
  write('build/web/staticwebapp.config.json', '{}');
  for (const file of ['js', 'wasm', 'audio.worklet.js', 'audio.position.worklet.js']
    .map(suffix => `${config.executable}.${suffix}`)) {
    write(`build/web/${file}`, `compiled ${file}`);
    write(`build/web/${file}.br`, `compressed ${file}`);
  }
  write(`build/web/${mainPack}`, brotliCompressSync(pack));
  return { root, write, config, pack, receipt: path.join(root, 'build/web-build.json'),
    record: () => writeBuildReceipt(root, snapshotInputs(root)) };
}

test('a successful receipt verifies exact source and output bytes without relying on timestamps or Git', t => {
  const { root, write, record, receipt } = fixture(t);
  const recorded = record();
  assert.deepEqual(verifyBuildReceipt(root), recorded);
  assert.ok(recorded.sources.some(file => file.path === 'assets/chests/models/private.glb'),
    'Ignored licensed build inputs are part of source verification');
  assert.equal(recorded.output.some(file => file.path.includes('web-build.json')), false,
    'The local source inventory is never put in the published output');
  write('build/review/notes.txt', 'An unrelated local artifact does not invalidate the game.');
  write('docs/review.md', 'An unrelated design note does not invalidate the game.');
  fs.utimesSync(path.join(root, 'scripts/game.gd'), new Date(0), new Date(0));
  assert.deepEqual(verifyBuildReceipt(root), JSON.parse(fs.readFileSync(receipt, 'utf8')));
});

test('localhost preview edits do not stale production builds while runtime and deployed files remain protected', t => {
  const { root, write, record } = fixture(t);
  write('web/preview/pip-growth/index.html', 'local preview');
  write('web/preview/pip-growth/art/pip.svg', 'review artwork');
  write('web/preview.js', 'production script with a similar name');
  const receipt = record();
  assert.equal(receipt.sources.some(file => file.path.startsWith('web/preview/')), false);
  assert.ok(receipt.sources.some(file => file.path === 'web/preview.js'));
  write('web/preview/pip-growth/index.html', 'revised local preview');
  write('web/preview/pip-growth/review-output/desktop.png', 'new local review capture');
  fs.unlinkSync(path.join(root, 'web/preview/pip-growth/art/pip.svg'));
  assert.deepEqual(verifyBuildReceipt(root), receipt);
  write('web/preview.js', 'changed production script');
  assert.throws(() => verifyBuildReceipt(root), /Stale Web build.*web\/preview\.js/);
  record();
  write('build/web/preview/pip-growth/index.html', 'accidentally copied preview');
  assert.throws(() => verifyBuildReceipt(root), /export changed.*preview\/pip-growth\/index\.html/);
});

test('edits to private assets, new scripts and deleted runtime inputs reject an older export', t => {
  const { root, write, record } = fixture(t);
  record();
  write('assets/chests/models/private.glb', 'revised model bytes');
  assert.throws(() => verifyBuildReceipt(root), /Stale Web build.*private\.glb/);
  record();
  write('scripts/new_mode.gd', 'extends Control');
  assert.throws(() => verifyBuildReceipt(root), /Stale Web build.*new_mode\.gd/);
  record();
  fs.unlinkSync(path.join(root, 'scripts/game.gd'));
  assert.throws(() => verifyBuildReceipt(root), /Stale Web build.*game\.gd/);
});

test('changing the sourced menu cue contract rejects an older export', t => {
  const { root, write, record } = fixture(t);
  write('docs/assets/ui-click-audio.json', '{"assets":[{"seconds":0.08}]}');
  record();
  write('docs/assets/ui-click-audio.json', '{"assets":[{"seconds":0.09}]}');
  assert.throws(() => verifyBuildReceipt(root), /Stale Web build.*ui-click-audio\.json/);
  record();
  write('tools/ui-click-audio.cjs', 'module.exports = {};');
  assert.throws(() => verifyBuildReceipt(root), /Stale Web build.*ui-click-audio\.cjs/);
});

test('changing the shared chest audio contract or validator rejects an older export', t => {
  const { root, write, record } = fixture(t);
  write('docs/assets/chest-reference-audio.json', '{"assets":[{"id":"release","seconds":1.5}]}');
  record();
  write('docs/assets/chest-reference-audio.json', '{"assets":[{"id":"release","seconds":1.4}]}');
  assert.throws(() => verifyBuildReceipt(root), /Stale Web build.*chest-reference-audio\.json/);
  record();
  write('tools/chest-reference-audio.cjs', 'module.exports = {};');
  assert.throws(() => verifyBuildReceipt(root), /Stale Web build.*chest-reference-audio\.cjs/);
});

test('changing the Kenney chest manifest, validator or import recipe rejects an older export', t => {
  const { root, write, record } = fixture(t);
  const sources = ['docs/assets/chest-kenney-audio.json', 'tools/chest-kenney-audio.cjs', 'tools/import-chest-kenney.py'];
  for (const source of sources) write(source, 'original Kenney chest contract');
  for (const source of sources) {
    record();
    write(source, 'revised Kenney chest contract');
    assert.throws(() => verifyBuildReceipt(root), error => error.message.includes('Stale Web build') && error.message.includes(source));
  }
});

test('changing the vocabulary motion manifest, source map or validator invalidates an older export', t => {
  const { root, write, record } = fixture(t);
  const sources = ['data/word-motion.json', 'docs/assets/word-library-motion.json',
    'tools/vocabulary-art/library-motion-map.json', 'tools/word-library-motion.cjs'];
  for (const source of sources) write(source, 'original motion contract');
  for (const source of sources) {
    record();
    write(source, 'revised motion contract');
    assert.throws(() => verifyBuildReceipt(root), error => error.message.includes('Stale Web build') && error.message.includes(source));
  }
});

test('changes to the chest milestone artwork validator reject an older export', t => {
  const { root, write, record } = fixture(t);
  const source = 'tools/prepare-chest-milestone-art.cjs';
  write(source, 'original milestone artwork validation');
  record();
  write(source, 'revised milestone artwork validation');
  assert.throws(() => verifyBuildReceipt(root), /Stale Web build.*prepare-chest-milestone-art\.cjs/);
  record();
  fs.unlinkSync(path.join(root, source));
  assert.throws(() => verifyBuildReceipt(root), /Stale Web build.*prepare-chest-milestone-art\.cjs/);
});

test('editing or deleting the phrase catalog rejects an older export', t => {
  const { root, write, record } = fixture(t);
  write('phrases.json', '[{"id":"red-apple","text":"red apple"}]');
  const receipt = record();
  assert.ok(receipt.sources.some(file => file.path === 'phrases.json'),
    'The raw phrase catalog participates in the exact source inventory');
  write('phrases.json', '[{"id":"green-apple","text":"green apple"}]');
  assert.throws(() => verifyBuildReceipt(root), /Stale Web build.*phrases\.json/);
  record();
  fs.unlinkSync(path.join(root, 'phrases.json'));
  assert.throws(() => verifyBuildReceipt(root), /Stale Web build.*phrases\.json/);
});

test('changed or missing deployed files fail verification even when source inputs are unchanged', t => {
  const { root, write, config, record } = fixture(t);
  record();
  write('build/web/index.html', fs.readFileSync(path.join(root, 'build/web/index.html'), 'utf8') + '<!-- changed -->');
  assert.throws(() => verifyBuildReceipt(root), /export changed.*index\.html/);
  record();
  write('build/web/unexpected.js', 'unexpected upload');
  assert.throws(() => verifyBuildReceipt(root), /export changed.*unexpected\.js/);
  record();
  fs.unlinkSync(path.join(root, `build/web/${config.mainPack}`));
  assert.throws(() => verifyBuildReceipt(root), /Missing Web export file/);
});

test('the explicit compressed pack is validated against its decoded byte length and hash', t => {
  const { root, write, config, pack, record } = fixture(t);
  const packPath = `build/web/${config.mainPack}`;
  write(packPath, brotliCompressSync(Buffer.alloc(pack.length, 1)));
  assert.throws(record, /decoded size and content hash/);
  write(packPath, Buffer.from([0xff, 0x22]));
  assert.throws(record, /complete Brotli stream/);
  write(packPath, brotliCompressSync(pack));
  config.fileSizes[config.mainPack] = pack.length - 1;
  write('build/web/index.html', `<script>const config = ${JSON.stringify(config)};</script>`);
  assert.throws(record, /decoded size and content hash/);
  config.fileSizes[config.mainPack] = pack.length + 1;
  write('build/web/index.html', `<script>const config = ${JSON.stringify(config)};</script>`);
  assert.throws(record, /decoded size and content hash/);
  delete config.fileSizes;
  write('build/web/index.html', `<script>const config = ${JSON.stringify(config)};</script>`);
  assert.throws(() => writeBuildReceipt(root, snapshotInputs(root)), /decoded byte length/);
});

test('a compressed pack cannot conceal trailing data or redundant native pack copies', t => {
  const { root, write, config, pack, record } = fixture(t);
  const compressed = brotliCompressSync(pack);
  for (const tail of [Buffer.from('extra bytes'), brotliCompressSync(Buffer.from('another stream'))]) {
    write(`build/web/${config.mainPack}`, Buffer.concat([compressed, tail]));
    assert.throws(record, /decoded size and content hash/);
  }
  write(`build/web/${config.mainPack}`, compressed);
  for (const name of [config.mainPack.slice(0, -3), 'index.pck', 'index.pck.br', 'game-0123456789abcdef.pck.br']) {
    const filename = write(`build/web/${name}`, pack);
    assert.throws(record, /duplicate Web game packs/);
    fs.unlinkSync(filename);
  }
  const receipt = record();
  assert.deepEqual(verifyBuildReceipt(root), receipt);
});

test('changes to the local delivery server invalidate the build verified with it', t => {
  const { root, write, record } = fixture(t);
  write('tools/serve-web.cjs', 'original compressed pack server');
  record();
  write('tools/serve-web.cjs', 'updated compressed pack server');
  assert.throws(() => verifyBuildReceipt(root), /Stale Web build.*serve-web\.cjs/);
});

test('every deferred vocabulary pack must match its declared decoded size, full hash and complete Brotli stream', t => {
  const { root, write, config, record } = fixture(t);
  record();
  const file = config.vocabularyPacks['4'];
  const filename = path.join(root, 'build/web', file.file);
  const original = fs.readFileSync(filename);
  fs.unlinkSync(filename);
  assert.throws(record, /Missing Web vocabulary pack/);
  write(`build/web/${file.file}`, Buffer.concat([original, Buffer.from('trailing garbage')]));
  assert.throws(record, /Vocabulary pack.*decoded size and content hash/);
  write(`build/web/${file.file}`, brotliCompressSync(Buffer.from('changed age vocabulary')));
  assert.throws(record, /Vocabulary pack.*decoded size and content hash|Incomplete Brotli vocabulary pack/);
  write(`build/web/${file.file}`, original);
  const bytes = file.bytes;
  file.bytes++;
  write('build/web/index.html', `<script>const config = ${JSON.stringify(config)};</script>`);
  assert.throws(record, /Vocabulary pack.*decoded size and content hash/);
  file.bytes = bytes;
  delete config.vocabularyPacks['12'];
  write('build/web/index.html', `<script>const config = ${JSON.stringify(config)};</script>`);
  assert.throws(record, /all ten on-demand vocabulary packs/);
});

test('obsolete vocabulary hashes and raw duplicate packs cannot be deployed', t => {
  const { root, write, config, record } = fixture(t);
  for (const name of ['vocabulary-4-0123456789abcdef.pck.br', 'vocabulary-shared-3-5-12-0123456789abcdef.pck.br',
    'vocabulary-shared-3-5-12-0123456789abcdef.pck', config.vocabularyPacks['4'].file.slice(0, -3)]) {
    const filename = write(`build/web/${name}`, 'obsolete vocabulary');
    assert.throws(record, /duplicate Web vocabulary packs/);
    fs.unlinkSync(filename);
  }
  const receipt = record();
  assert.deepEqual(verifyBuildReceipt(root), receipt);
});

test('shared vocabulary bundles validate once and must have exactly their declared consumer ages', t => {
  const { root, write, config, record } = fixture(t);
  const bytes = Buffer.from('GDPC shared media for three, five and twelve');
  const sha256 = createHash('sha256').update(bytes).digest('hex');
  const file = `vocabulary-shared-3-5-12-${sha256.slice(0, 16)}.pck.br`;
  const shared = { file, bytes: bytes.length, sha256 };
  const publish = () => write('build/web/index.html', `<script>const config = ${JSON.stringify(config)};</script>`);
  write(`build/web/${file}`, brotliCompressSync(bytes));
  for (const age of ['3', '5', '12']) config.vocabularyPacks[age].dependencies = [{ ...shared }];
  publish();
  const receipt = record();
  assert.deepEqual(verifyBuildReceipt(root), receipt);
  config.vocabularyPacks['5'].dependencies = [];
  publish();
  assert.throws(record, /exactly its consumer ages/);
  config.vocabularyPacks['5'].dependencies = [{ ...shared }];
  config.vocabularyPacks['4'].dependencies = [{ ...shared }];
  publish();
  assert.throws(record, /Invalid shared vocabulary consumers/);
  config.vocabularyPacks['4'].dependencies = [];
  config.vocabularyPacks['12'].dependencies[0].bytes += 1;
  publish();
  assert.throws(record, /Conflicting shared vocabulary declarations/);
  config.vocabularyPacks['12'].dependencies[0].bytes -= 1;
  config.vocabularyPacks['3'].dependencies.push({ ...shared });
  publish();
  assert.throws(record, /Invalid vocabulary dependencies/);
  config.vocabularyPacks['3'].dependencies.pop();
  publish();
  write(`build/web/${file}`, brotliCompressSync(Buffer.from('damaged shared pack')));
  assert.throws(record, /Vocabulary pack.*decoded size and content hash|Incomplete Brotli vocabulary pack/);
  fs.unlinkSync(path.join(root, 'build/web', file));
  assert.throws(record, /Missing Web vocabulary pack/);
});

test('failed and interrupted builds cannot leave a prior successful receipt deployable', t => {
  const { root, receipt, record } = fixture(t);
  record();
  invalidateBuildReceipt(root);
  assert.equal(fs.existsSync(receipt), false);
  assert.throws(() => verifyBuildReceipt(root), /Missing successful Web build receipt/);
  invalidateBuildReceipt(root);
});

test('sources changed during export cannot receive a successful receipt', t => {
  const { root, write, receipt } = fixture(t), before = snapshotInputs(root);
  write('scripts/game.gd', 'extends Control');
  assert.throws(() => writeBuildReceipt(root, before), /inputs changed during export.*game\.gd/);
  assert.equal(fs.existsSync(receipt), false);
});

test('inputs edited while output verification runs cannot receive a successful receipt', t => {
  const { root, write, config, receipt } = fixture(t);
  const read = fs.readFileSync;
  let changed = false;
  const packed = path.join(root, 'build/web', config.mainPack);
  t.mock.method(fs, 'readFileSync', function (filename, ...args) {
    const result = read.call(fs, filename, ...args);
    if (filename === packed && !changed) {
      changed = true;
      write('scripts/game.gd', 'extends Node # edited during output verification');
    }
    return result;
  });
  assert.throws(() => writeBuildReceipt(root, snapshotInputs(root)), /inputs changed during output audit.*game\.gd/);
  assert.equal(changed, true);
  assert.equal(fs.existsSync(receipt), false);
});

test('receipt verification rejects source edits during its output audit', t => {
  const { root, write, config, record } = fixture(t);
  record();
  const read = fs.readFileSync;
  let changed = false;
  t.mock.method(fs, 'readFileSync', function (filename, ...args) {
    const result = read.call(fs, filename, ...args);
    if (filename === path.join(root, 'build/web', config.mainPack) && !changed) {
      changed = true;
      write('scripts/game.gd', 'extends Node # edited while verifying receipt');
    }
    return result;
  });
  assert.throws(() => verifyBuildReceipt(root), /Stale Web build.*during output audit.*game\.gd/);
  assert.equal(changed, true);
});

test('unpackaged exports and malformed receipts fail closed', t => {
  const { root, write, receipt } = fixture(t);
  write('build/web/index.html', '<script>const config = {"executable":"index"};</script>');
  assert.throws(() => writeBuildReceipt(root, snapshotInputs(root)), /not been packaged/);
  fs.writeFileSync(receipt, '{');
  assert.throws(() => verifyBuildReceipt(root), /Invalid Web build receipt/);
  fs.writeFileSync(receipt, JSON.stringify({ version: 1, sources: [], output: [] }));
  assert.throws(() => verifyBuildReceipt(root), /Invalid Web build receipt/);
});
