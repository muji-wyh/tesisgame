'use strict';
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const base = __dirname, root = path.resolve(base, '../../../..');
assert.equal(process.argv[2], '--root-granted-native-slot');
const name = process.argv[3]; assert.match(name || '', /^attempt-[0-9]{3}$/);
const attempt = path.join(base, 'attempts', name), project = path.join(attempt, 'project');
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
assert.ok(!fs.existsSync(path.join(attempt, 'native-attempt.json')), 'Never replay or overwrite a native attempt.');
const preparationBytes = fs.readFileSync(path.join(attempt, 'preparation-receipt.json'));
const prep = JSON.parse(preparationBytes);
const inputs = [
  ...prep.files.map(row => ({ ...row, namespace: 'project', absolute: path.join(project, row.path) })),
  ...prep.harness_files.map(row => ({ ...row, namespace: 'harness', absolute: path.join(base, row.path) })),
  ...prep.source_guards.map(row => ({ ...row, namespace: 'source', absolute: path.join(root, row.path) })),
  { ...prep.runner_dependency, namespace: 'runner', absolute: path.join(root, prep.runner_dependency.path) },
  { path: 'preparation-receipt.json', namespace: 'attempt', absolute: path.join(attempt, 'preparation-receipt.json'), bytes: preparationBytes.length, sha256: hash(preparationBytes) }
];
const drift = () => {
  const changed = inputs.filter(row => {
    try { const bytes = fs.readFileSync(row.absolute); return bytes.length !== row.bytes || hash(bytes) !== row.sha256; }
    catch { return true; }
  }).map(row => row.namespace + ':' + row.path);
  for (const relative of prep.expected_missing) if (fs.existsSync(path.join(project, relative))) changed.push('unexpected-file:' + relative);
  return changed;
};
assert.deepEqual(drift(), [], 'All frozen execution inputs and intentional absences must match preparation.');
const inventory = Buffer.from(JSON.stringify({ schema: 1, expected_missing: prep.expected_missing, files: inputs.map(({ absolute, ...row }) => row) }, null, 2) + '\n');
fs.writeFileSync(path.join(attempt, 'execution-input-inventory.json'), inventory, { flag: 'wx' });
fs.writeFileSync(path.join(attempt, 'native-attempt.json'), JSON.stringify({ schema: 1, started_at: new Date().toISOString(), timeout_ms: 60000,
  input_count: inputs.length, absent_input_count: prep.expected_missing.length, input_inventory_sha256: hash(inventory) }, null, 2) + '\n', { flag: 'wx' });
const start = Date.now(); let output = '', error = null;
try {
  const result = require(path.join(root, prep.runner_dependency.path)).runGodot(['--headless', '--path', project, '--script', 'res://negative_tests.gd'], { timeout: 60000 });
  output = (result.stdout || '') + (result.stderr || '');
} catch (failure) { error = failure.message; output = failure.message; }
fs.writeFileSync(path.join(attempt, 'native.log'), output, { flag: 'wx' });
const reportPath = path.join(project, 'native-report.json');
const report = fs.existsSync(reportPath) ? JSON.parse(fs.readFileSync(reportPath)) : null;
const changed = drift();
const receipt = { schema: 1, ok: !error && changed.length === 0 && report?.count > 0 && report.failures === 0,
  duration_ms: Date.now() - start, checks: report?.count || 0, failures: report?.failures ?? null, error,
  input_count: inputs.length, absent_input_count: prep.expected_missing.length, inputs_unchanged: changed.length === 0, changed_paths: changed,
  package_negative_cases: prep.negative_cases, affected_request_replacements: 5, original_failed_receipt_sha256: prep.original_failed_receipt.sha256, report_sha256: report ? hash(fs.readFileSync(reportPath)) : null,
  log_sha256: hash(Buffer.from(output)), authority: 'none', production_changes: false, candidate_logic_unchanged: true,
  app_trust_verified: false, pck_browser_memory_latency_acceptance: false, real_media_fetch_decode: false,
  scope: 'Affected invalid-replacement-request supplement only; no package-negative rerun. Original 214-check run remains failed. Exact unchanged owner and production copies; no production policy installed.' };
fs.writeFileSync(path.join(attempt, 'validation-receipt.json'), JSON.stringify(receipt, null, 2) + '\n', { flag: 'wx' });
console.log(JSON.stringify(receipt)); process.exitCode = receipt.ok ? 0 : 1;
