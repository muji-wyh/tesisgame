'use strict';
// Root must grant the shared native slot before this runner is invoked.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const base = __dirname;
const root = path.resolve(base, '../../../..');
const {runGodot} = require(path.join(root, 'tools/run-godot.cjs'));
const args = process.argv.slice(2);
assert.deepEqual(args.slice(0, 2), ['--root-granted-native-slot', 'checkout-r01']);
assert.equal(args.length, 3);
const stage = args[2];
assert(['sources', 'composition'].includes(stage));
const raw = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const read = p => JSON.parse(fs.readFileSync(p, 'utf8'));
const record = read(path.join(base, 'source-record.json'));
const script = stage === 'sources' ? 'inspect-sources.gd' : 'probe-composition.gd';
const outputDir = stage === 'sources' ? 'source-inspection' : 'composition-probe';
if (stage === 'composition') {
  const review = read(path.join(base, 'source-pose-review.json'));
  assert.equal(review.status, 'accepted_for_composition_probe');
  assert.equal(review.source_inspection_report_sha256, raw(path.join(base, 'source-inspection/report.json')));
}
for (const relative of [outputDir, `${stage}-native.log`, `${stage}-native-receipt.json`]) assert.equal(fs.existsSync(path.join(base, relative)), false, `Preserve ${relative}; create a new revision`);
function scan(relative, result = {}) {
  const directory = path.join(root, relative);
  for (const name of fs.readdirSync(directory)) {
    const file = path.join(directory, name);
    const rel = path.join(relative, name).replaceAll('\\', '/');
    if (fs.statSync(file).isDirectory()) scan(rel, result);
    else result[rel] = raw(file);
  }
  return result;
}
function snapshot() { return {...scan('data/professional'), ...scan('scripts'), ...scan('professional-media')}; }
function checkSources() {
  for (const file of record.files) {
    assert.equal(raw(file.original_path), file.sha256, file.original_path);
    assert.equal(raw(path.join(base, file.retained_path)), file.sha256, file.retained_path);
  }
}
checkSources();
const before = snapshot();
const sourceRecordHash = raw(path.join(base, 'source-record.json'));
const scriptHash = raw(path.join(base, script));
const nativeArgs = ['--path', '.', '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy', '--script', `res://build/professional-english/retail-term-art-review/checkout-r01/${script}`];
const started = Date.now();
let output = '', nativeError = null;
try {
  const result = runGodot(nativeArgs, {timeout: 60000});
  output = (result.stdout || '') + (result.stderr || '');
} catch (error) { nativeError = String(error.stack || error); output = nativeError; }
fs.writeFileSync(path.join(base, `${stage}-native.log`), output, {flag: 'wx'});
let guardError = null;
try {
  checkSources();
  assert.deepEqual(snapshot(), before);
  assert.equal(raw(path.join(base, 'source-record.json')), sourceRecordHash);
  assert.equal(raw(path.join(base, script)), scriptHash);
} catch (error) { guardError = String(error.stack || error); }
const reportFile = path.join(base, outputDir, 'report.json');
const report = fs.existsSync(reportFile) ? read(reportFile) : null;
const receipt = {schema: 1, stage, ok: !nativeError && !guardError && !!report && (!('failed' in report) || report.failed === 0), scope: 'Scratch source/composition probe only. No production, test, curriculum or review-gate writes.', native_runner: 'tools/run-godot.cjs::runGodot', native_timeout_ms: 60000, native_args: nativeArgs, duration_ms: Date.now() - started, script_sha256: scriptHash, source_record_sha256: sourceRecordHash, report_sha256: report ? raw(reportFile) : null, log_sha256: raw(path.join(base, `${stage}-native.log`)), guarded_production_files: Object.keys(before).length, source_original_and_retained_files: record.files.length * 2, native_error: nativeError, guard_error: guardError};
fs.writeFileSync(path.join(base, `${stage}-native-receipt.json`), JSON.stringify(receipt, null, 2) + '\n', {flag: 'wx'});
console.log(JSON.stringify(receipt));
process.exitCode = receipt.ok ? 0 : 1;
