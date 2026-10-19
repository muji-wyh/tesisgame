'use strict';
// Root must own the shared native slot. This one-shot runner preserves every attempt.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const here = __dirname, root = path.resolve(here, '../../../..');
const raw = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
assert.deepEqual(process.argv.slice(2), ['--root-granted-native-slot', 'cash-register-r04']);
assert.equal(process.cwd().toLowerCase(), root.toLowerCase());
for (const name of ['native-inspection-r01', 'inspection.log', 'inspection-receipt.json']) assert.equal(fs.existsSync(path.join(here, name)), false, 'Preserve prior attempts');
const record = read(path.join(here, 'source-record.json'));
assert.equal(raw(path.join(here, 'source-record.json')), '3e6184da75cd0fa51efaad7a47369c291b8ed920f1659a3c0d5b891e691149f0');
function snapshot(relative, result = {}) {
  const base = path.join(root, relative);
  for (const name of fs.readdirSync(base)) {
    const file = path.join(relative, name);
    if (fs.statSync(path.join(root, file)).isDirectory()) snapshot(file, result);
    else result[file.replaceAll('\\', '/')] = raw(path.join(root, file));
  }
  return result;
}
function production() { return {...snapshot('data/professional'), ...snapshot('scripts'), ...snapshot('professional-media'), ...snapshot('tests'), 'project.godot': raw(path.join(root, 'project.godot')), 'export_presets.cfg': raw(path.join(root, 'export_presets.cfg'))}; }
function checkSources() {
  assert.equal(raw(path.join(here, record.acquisition.archive_path)), record.acquisition.archive_sha256);
  for (const file of record.files) assert.equal(raw(path.join(here, file.path)), file.sha256, file.path);
}
checkSources();
const before = production();
const inputNames = ['source-record.json', 'archive-inventory.json', 'primary-capture-receipt.json', 'inspect-source.gd', 'run-inspection.cjs'];
const inputs = Object.fromEntries(inputNames.map(name => [name, raw(path.join(here, name))]));
const start = Date.now();
let output = '', nativeError = null, guardError = null, report = null;
try {
  const result = require(path.join(root, 'tools/run-godot.cjs')).runGodot(['--path', '.', '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--script', 'res://build/professional-english/retail-term-art-review/cash-register-r04/inspect-source.gd'], {timeout: 60000});
  output = (result.stdout || '') + (result.stderr || '');
} catch (error) { nativeError = String(error.stack || error); output = nativeError; }
fs.writeFileSync(path.join(here, 'inspection.log'), output, {flag: 'wx'});
try {
  assert.deepEqual(production(), before);
  checkSources();
  for (const [name, hash] of Object.entries(inputs)) assert.equal(raw(path.join(here, name)), hash);
  assert.equal(/(?:^|\n)\s*(?:SCRIPT )?ERROR:/m.test(output), false);
  report = read(path.join(here, 'native-inspection-r01/report.json'));
  assert.equal(report.captures.length, 6);
  assert.equal(report.meshes.length, 2);
  assert.equal(report.animation_players, 0);
  assert.equal(report.model_sha256, '43aed74637cf10432d996a18f03ed580f6cbc346b5f91d9592473370ed8ea1cc');
  for (const item of report.captures) {
    assert.deepEqual(item.pixels, [768, 768]);
    assert.equal(raw(path.join(here, 'native-inspection-r01', item.file)), item.sha256);
  }
} catch (error) { guardError = String(error.stack || error); }
const receipt = {schema: 1, status: !nativeError && !guardError ? 'original_source_inspection_passed_pending_visual_review' : 'failed_attempt_preserved', native_error: nativeError, guard_error: guardError, elapsed_ms: Date.now() - start, guarded_production_files: Object.keys(before).length, inputs, source_files: record.files.length, captures: report?.captures.length || 0, report_sha256: report ? raw(path.join(here, 'native-inspection-r01/report.json')) : null, log_sha256: raw(path.join(here, 'inspection.log')), production_changes: false};
fs.writeFileSync(path.join(here, 'inspection-receipt.json'), JSON.stringify(receipt, null, 2) + '\n', {flag: 'wx'});
console.log(JSON.stringify(receipt, null, 2));
if (nativeError || guardError) process.exitCode = 1;
