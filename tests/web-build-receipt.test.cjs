const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
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
  const config = { executable: 'engine-0123456789abcdef', mainPack: 'game-0123456789abcdef.pck' };
  write('build/web/index.html', `<script>const config = ${JSON.stringify(config)};</script>`);
  write('build/web/staticwebapp.config.json', '{}');
  for (const file of [...['js', 'wasm', 'audio.worklet.js', 'audio.position.worklet.js']
    .map(suffix => `${config.executable}.${suffix}`), config.mainPack]) {
    write(`build/web/${file}`, `compiled ${file}`);
    write(`build/web/${file}.br`, `compressed ${file}`);
  }
  return { root, write, receipt: path.join(root, 'build/web-build.json'),
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
  const { root, write, record } = fixture(t);
  record();
  write('build/web/index.html', fs.readFileSync(path.join(root, 'build/web/index.html'), 'utf8') + '<!-- changed -->');
  assert.throws(() => verifyBuildReceipt(root), /export changed.*index\.html/);
  record();
  write('build/web/unexpected.js', 'unexpected upload');
  assert.throws(() => verifyBuildReceipt(root), /export changed.*unexpected\.js/);
  record();
  fs.unlinkSync(path.join(root, 'build/web/game-0123456789abcdef.pck.br'));
  assert.throws(() => verifyBuildReceipt(root), /Missing Web export file/);
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

test('unpackaged exports and malformed receipts fail closed', t => {
  const { root, write, receipt } = fixture(t);
  write('build/web/index.html', '<script>const config = {"executable":"index"};</script>');
  assert.throws(() => writeBuildReceipt(root, snapshotInputs(root)), /not been packaged/);
  fs.writeFileSync(receipt, '{');
  assert.throws(() => verifyBuildReceipt(root), /Invalid Web build receipt/);
  fs.writeFileSync(receipt, JSON.stringify({ version: 1, sources: [], output: [] }));
  assert.throws(() => verifyBuildReceipt(root), /Invalid Web build receipt/);
});
