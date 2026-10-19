'use strict';
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const base = __dirname, root = path.resolve(base, '../../../..');
const prior = path.resolve(base, '../attempts/attempt-001'), priorProject = path.join(prior, 'project');
const attempt = path.join(base, 'attempts/attempt-001'), project = path.join(attempt, 'project');
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const json = value => Buffer.from(JSON.stringify(value, null, 2) + '\n');
assert.ok(!fs.existsSync(attempt), 'Fresh affected supplement only; do not replay.');
const inventory = JSON.parse(fs.readFileSync(path.join(prior, 'execution-input-inventory.json')));
const failedBytes = fs.readFileSync(path.join(prior, 'validation-receipt.json')), failed = JSON.parse(failedBytes);
assert.equal(failed.ok, false); assert.equal(failed.checks, 214); assert.equal(failed.failures, 1);
const files = [], guards = [];
function put(relative, bytes) {
  const destination = path.join(project, relative);
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.writeFileSync(destination, bytes, { flag: 'wx' });
  files.push({ path: relative, bytes: bytes.length, sha256: hash(bytes) });
}
function copyPrior(row) {
  const source = path.join(priorProject, row.path), bytes = fs.readFileSync(source);
  assert.equal(bytes.length, row.bytes); assert.equal(hash(bytes), row.sha256);
  put(row.path, bytes);
  guards.push({ path: path.relative(root, source).replaceAll('\\', '/'), bytes: bytes.length, sha256: hash(bytes) });
  if (row.path.startsWith('scripts/')) {
    assert.equal(hash(fs.readFileSync(path.join(root, row.path))), row.sha256);
    guards.push({ path: row.path, bytes: bytes.length, sha256: row.sha256 });
  }
}
for (const row of inventory.files.filter(row => row.namespace === 'project')) {
  if (row.path.startsWith('scripts/') || row.path.startsWith('cases/valid/') ||
      row.path.startsWith('data/professional/') && !row.path.startsWith('data/professional/negative-fixture/') ||
      ['project.godot', 'fixture_catalog.gd', 'candidate_owner_reference.gd', 'case-manifest.json'].includes(row.path)) copyPrior(row);
}
const originalTest = fs.readFileSync(path.join(priorProject, 'negative_tests.gd'));
const testRow = inventory.files.find(row => row.namespace === 'project' && row.path === 'negative_tests.gd');
assert.equal(hash(originalTest), testRow.sha256);
let test = originalTest.toString('utf8');
const oldCalls = '\tawait _package_rejections()\n\tawait _owner_replacement()\n\tawait _invalid_replacement_requests()';
assert.ok(test.includes(oldCalls));
test = test.replace(oldCalls, '\t_check(not "mode unavailable".contains(""), "Godot empty-substring predicate explains the retained harness failure")\n\tawait _invalid_replacement_requests()');
const oldExpectation = 'not rejected.get("ok", false) and str(rejected.get("error", "")).contains(spec.error)';
assert.equal(test.split(oldExpectation).length, 2);
test = test.replace(oldExpectation, 'not rejected.get("ok", false) and (str(spec.error).is_empty() or str(rejected.get("error", "")).contains(spec.error))');
const stateLine = '\t\tvar state: Dictionary = owner.diagnostics()\n\t\t_check(state.cached_modules == 1';
assert.ok(test.includes(stateLine));
test = test.replace(stateLine, '\t\tvar state: Dictionary = owner.diagnostics()\n\t\t_observations.append({"id": spec.id, "selection": selection, "result": rejected.duplicate(true), "state": state})\n\t\t_check(state.cached_modules == 1');
test = test.replace('Fixed synthetic package rejection and replacement only. Exact previous owner logic and current production catalog/resolver. No PCK/app trust, media fetch, browser, memory or latency acceptance.',
  'Affected invalid-replacement-request supplement only. No package-negative rerun; original 214-check run remains failed. Exact unchanged owner and production scripts. No app trust, media fetch, browser, memory or latency acceptance.');
put('negative_tests.gd', Buffer.from(test));
guards.push({ path: path.relative(root, path.join(priorProject, 'negative_tests.gd')).replaceAll('\\', '/'), bytes: originalTest.length, sha256: hash(originalTest) });
guards.push({ path: path.relative(root, path.join(prior, 'validation-receipt.json')).replaceAll('\\', '/'), bytes: failedBytes.length, sha256: hash(failedBytes) });
fs.writeFileSync(path.join(base, 'negative_tests.gd'), test, { flag: 'wx' });
let runner = fs.readFileSync(path.join(base, '../run-native.cjs'), 'utf8');
runner = runner.replace("root = path.resolve(base, '../../..')", "root = path.resolve(base, '../../../..')");
runner = runner.replace('package_negative_cases: prep.negative_cases,', 'package_negative_cases: prep.negative_cases, affected_request_replacements: 5, original_failed_receipt_sha256: prep.original_failed_receipt.sha256,');
runner = runner.replace('Fixed synthetic package rejection, exact previous async owner logic, current production catalog/resolver, and invalid replacement requests. No production policy installed.',
  'Affected invalid-replacement-request supplement only; no package-negative rerun. Original 214-check run remains failed. Exact unchanged owner and production copies; no production policy installed.');
fs.writeFileSync(path.join(base, 'run-native.cjs'), runner, { flag: 'wx' });
const harness = ['prepare.cjs', 'negative_tests.gd', 'run-native.cjs'].map(relative => {
  const bytes = fs.readFileSync(path.join(base, relative)); return { path: relative, bytes: bytes.length, sha256: hash(bytes) };
});
const dependency = 'tools/run-godot.cjs', dependencyBytes = fs.readFileSync(path.join(root, dependency));
for (const row of guards) assert.equal(hash(fs.readFileSync(path.join(root, row.path))), row.sha256);
fs.writeFileSync(path.join(attempt, 'preparation-receipt.json'), json({ schema: 1, created_at: new Date().toISOString(), authority: 'none',
  files, expected_missing: [], source_guards: guards, harness_files: harness,
  runner_dependency: { path: dependency, bytes: dependencyBytes.length, sha256: hash(dependencyBytes) },
  original_failed_receipt: { path: path.relative(root, path.join(prior, 'validation-receipt.json')).replaceAll('\\', '/'), sha256: hash(failedBytes) },
  negative_cases: 0, affected_request_replacements: 5, production_scripts_copied_unchanged: 8,
  candidate_logic_unchanged: true, media_files_copied: 0,
  scope: 'Correct only optional-message expectation; execute the five affected replacement selections and record their actual results. Prior 22 package negatives are not rerun.' }), { flag: 'wx' });
console.log(JSON.stringify({ project, files: files.length, source_guards: guards.length, authority: 'none' }));
