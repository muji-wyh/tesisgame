'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../..');
assert.equal(root.replaceAll('\\', '/').toLowerCase(), 'q:/.codex/worktrees/current-age-vocabulary/tesisgame');
const api = require(path.join(root, 'tools/validate-professional-content.cjs'));
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const objectHash = value => hash(JSON.stringify(value));
const at = file => {
  assert(!path.isAbsolute(file) && !file.includes('\\'));
  const result = path.resolve(root, file);
  assert.equal(path.relative(root, result).replaceAll('\\', '/'), file);
  assert(!file.startsWith('../'));
  return result;
};
const raw = file => hash(fs.readFileSync(at(file)));
const read = file => JSON.parse(fs.readFileSync(at(file)));
const baselineFile = 'build/professional-english/continuation-baseline-r32-composite-r02/baseline.json';
const correction = 'build/professional-english/r32-native-attendance-correction-r01';
const originalPath = 'build/professional-english/continuation-validation-r32.json';
const correctedPath = correction + '/receipt.json';
const reviewPath = 'build/professional-english/r32-native-attendance-correction-r01-independent-review-r01/review.json';
const nativeTest = 'tests/godot/professional_retail_morphology_tests.gd';
const pinned = Object.freeze({
  [originalPath]: '951167226fbfa4e362dbb415146385785fdc682115e0591b28e3cb30f81253d9',
  [correctedPath]: '87eb0fbefbf573c68fbd06f7c539a11c1c3c2b7fe1913b31a62bf994476013db',
  [reviewPath]: '6e585823e4aa9a3ae936887579e587c20c5e4e7ba34e9272b3cd2e41645a0e56',
  [correction + '/execution-inputs.json']: 'dfd859293e087f3bd66e63af901406ae90bc052d57bfe3ae940cc33c7da6b266',
  [correction + '/validate.cjs']: 'eb015cbdc1d4378833e1dbda093396b894b52688c68364c5011ca647dc0f3748',
  [correction + '/professional_retail_morphology_tests.before.gd']: '3e000bea8af8529f4b215576f70b5a46ba7b734455cb518b8c2d56261e403dc9'
});
function stableInputs(receipt, beforeKey, afterKey) {
  assert.deepEqual(receipt.changed_measured_inputs, []);
  assert.equal(receipt.measured_input_count, 679);
  assert.equal(Object.keys(receipt[beforeKey]).length, 679);
  assert.deepEqual(receipt[beforeKey], receipt[afterKey]);
  assert.equal(receipt.registry_before_sha256, receipt.registry_after_sha256);
}
function checkRun(run, expected) {
  assert.equal(run.status, 0);
  assert.equal(run.signal, null);
  assert.equal(run.error, null);
  assert.equal(raw(run.log), run.log_sha256);
  for (const [key, value] of Object.entries(expected)) assert.equal(run[key], value, key);
}
function verifyCurrent() {
  for (const [file, sha] of Object.entries(pinned)) assert.equal(raw(file), sha, file);
  const original = read(originalPath), corrected = read(correctedPath), review = read(reviewPath);
  assert.equal(original.ok, false);
  stableInputs(original, 'before_input_sha256', 'after_input_sha256');
  assert.deepEqual(original.runs.map(run => run.name), ['node', 'native', 'native-audio']);
  const [node, failedNative, audio] = original.runs;
  checkRun(node, {tests: 249, pass: 249, fail: 0, cancelled: 0, skipped: 0});
  checkRun(audio, {checks: 141, failures: 0});
  assert.equal(failedNative.status, 1);
  assert.equal(failedNative.checks, 2837);
  assert.equal(failedNative.failures, 1);
  assert.equal(failedNative.signal, null);
  assert.equal(failedNative.error, null);
  assert.equal(raw(failedNative.log), failedNative.log_sha256);
  const failedLines = fs.readFileSync(at(failedNative.log), 'utf8').split(/\r*\n/).filter(line => line.startsWith('FAIL:'));
  assert.deepEqual(failedLines, ['FAIL: Persisted legacy entry equals its protected preimage: attendance.presence-record.n']);
  assert.equal(corrected.ok, true);
  stableInputs(corrected, 'before_input_sha256', 'after_input_sha256');
  assert.equal(corrected.baseline_path, originalPath);
  assert.equal(corrected.baseline_sha256, pinned[originalPath]);
  assert.equal(corrected.permitted_delta, nativeTest);
  assert.equal(corrected.registry_before_sha256, original.registry_after_sha256);
  checkRun(corrected.run, {checks: 2839, failures: 0});
  assert.deepEqual(corrected.run.args, failedNative.args);
  assert.deepEqual(Object.keys(corrected.after_input_sha256), Object.keys(original.after_input_sha256));
  assert.deepEqual(Object.keys(corrected.after_input_sha256).filter(file => corrected.after_input_sha256[file] !== original.after_input_sha256[file]), [nativeTest]);
  assert.equal(corrected.test_before_sha256, original.after_input_sha256[nativeTest]);
  assert.equal(corrected.test_after_sha256, corrected.after_input_sha256[nativeTest]);
  const execution = read(correction + '/execution-inputs.json');
  assert.deepEqual(execution.inputs, corrected.before_input_sha256);
  assert.deepEqual(execution.args, corrected.run.args);
  assert.equal(execution.baseline_path, originalPath);
  assert.equal(execution.baseline_sha256, pinned[originalPath]);
  assert.equal(execution.harness_sha256, pinned[correction + '/validate.cjs']);
  assert.equal(review.status, 'accepted_independent_technical_review');
  assert.equal(review.finding_count, 0);
  assert.deepEqual(review.findings, []);
  assert.equal(review.reviewed_code.before_raw_sha256, corrected.test_before_sha256);
  assert.equal(review.reviewed_code.after_raw_sha256, corrected.test_after_sha256);
  assert.equal(review.evidence.receipt.sha256, pinned[correctedPath]);
  assert.equal(review.evidence.failed_historical_R32.sha256, pinned[originalPath]);
  assert.equal(review.registry_sha256, corrected.registry_after_sha256);
  assert.equal(review.attendance_patch.morphology_unchanged, true);
  const now = Object.fromEntries(Object.keys(corrected.after_input_sha256).sort().map(file => [file, raw(file)]));
  assert.deepEqual(now, corrected.after_input_sha256);
  const treeRoots = ['data/professional', 'data/vocabulary/morphology', 'scripts', 'tools'];
  const discovered = [];
  function collect(directory) {
    for (const entry of fs.readdirSync(at(directory), {withFileTypes: true})) {
      const file = directory + '/' + entry.name;
      if (entry.isDirectory()) collect(file);
      else if (/\.(json|gd|cjs)$/.test(file)) discovered.push(file);
    }
  }
  for (const directory of treeRoots) collect(directory);
  assert.deepEqual(discovered.sort(), Object.keys(now).filter(file => treeRoots.some(directory => file.startsWith(directory + '/'))).sort());
  const data = api.loadProfessionalContent(root);
  assert.equal(objectHash(data), corrected.registry_after_sha256);
  const constituents = [
    {name: 'node', source_receipt: originalPath, source_receipt_sha256: pinned[originalPath], original_run_index: 0, run: node},
    {name: 'native', source_receipt: correctedPath, source_receipt_sha256: pinned[correctedPath], original_run_key: 'run', run: corrected.run},
    {name: 'native-audio', source_receipt: originalPath, source_receipt_sha256: pinned[originalPath], original_run_index: 2, run: audio}
  ];
  const baseline = {
    schema: 1,
    kind: 'composite_validation_baseline',
    status: 'current_inputs_verified_against_passing_r32_constituents_and_reviewed_native_correction',
    ok: true,
    full_combined_validation_of_current_state: false,
    new_test_execution: false,
    historical_full_run_remains_failed: {path: originalPath, raw_sha256: pinned[originalPath], ok: false},
    constituent_runs: constituents,
    sole_historical_delta: {path: nativeTest, before_sha256: corrected.test_before_sha256, after_sha256: corrected.test_after_sha256, reason: 'Exact independently reviewed attendance historical comparison; two added guard assertions. No product change.'},
    evidence: Object.entries(pinned).map(([path, raw_sha256]) => ({path, raw_sha256})),
    current_registry_sha256: objectHash(data),
    current_input_count: Object.keys(now).length,
    current_input_sha256: now,
    input_additions_or_removals: [],
    scope: 'Composed evidence only. R32 remains failed. Its passing Node/audio results are inherited with unchanged production and suite bytes; the sole changed native morphology test has its own passing focused run and independent technical review. This is not a fresh combined run, browser/performance result or curriculum release acceptance.'
  };
  return {baseline, data, inputs: now};
}
function verifyBaseline(file, sha) {
  assert.equal(file, baselineFile);
  assert.equal(raw(file), sha);
  const saved = read(file), verified = verifyCurrent();
  assert.equal(saved.verifier.path, 'build/professional-english/continuation-baseline-r32-composite-r02/verify.cjs');
  assert.equal(saved.verifier.raw_sha256, hash(fs.readFileSync(__filename)));
  assert.equal(saved.builder.raw_sha256, raw(saved.builder.path));
  const {recorded_at, verifier, builder, ...substance} = saved;
  assert.equal(typeof recorded_at, 'string');
  assert.deepEqual(substance, verified.baseline);
  return {baseline: saved, data: verified.data, inputs: verified.inputs};
}
module.exports = {verifyCurrent, verifyBaseline, baselineFile, raw, root};
