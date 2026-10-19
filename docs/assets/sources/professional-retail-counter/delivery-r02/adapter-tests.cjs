'use strict';
// Scratch-only failure-injection coverage. All fixture mutations stay under the supplied fresh output directory.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const plan = require('./transaction-plan.cjs');
const helper = require('./guarded-transaction.cjs');
const directory = path.resolve(process.argv[2] || path.join(__dirname, 'adapter-tests-r01'));
const rel = path.relative(__dirname, directory);
assert.ok(rel && rel !== '..' && !rel.startsWith('..' + path.sep) && !path.isAbsolute(rel), 'Fixtures must stay inside delivery-r02');
assert.equal(fs.existsSync(directory), false, 'Keep existing fixture evidence; choose a new test revision');
fs.mkdirSync(directory, {recursive: true});
let assertions = 0;
function same(actual, expected, label) { assert.deepEqual(actual, expected, label); assertions++; }
function rejects(fn, pattern, label) { assert.throws(fn, pattern, label); assertions++; }
const cases = [];
function fixture(name) {
  const root = path.join(directory, name, 'repository'), transaction = path.join(root, 'transactions', 'attempt-r01');
  fs.mkdirSync(path.join(root, 'data'), {recursive: true});
  fs.mkdirSync(path.join(root, 'docs'), {recursive: true});
  fs.writeFileSync(path.join(root, 'data', 'retail.json'), Buffer.from('original registry bytes\r\n'));
  fs.writeFileSync(path.join(root, 'docs', 'source-license.txt'), Buffer.from('original identical CC0 source\r\n'));
  const artifacts = [
    {path: 'docs/source-license.txt', policy: 'immutable', after: Buffer.from('original identical CC0 source\r\n')},
    {path: 'docs/source-model.glb', policy: 'immutable', after: Buffer.from([0, 1, 2, 3, 128, 255])},
    {path: 'media/counter.png', policy: 'immutable', after: Buffer.from([137, 80, 78, 71, 13, 10, 26, 10, 255])},
    {path: 'data/retail.json', policy: 'replace', after: Buffer.from('integrated registry bytes\n')},
    {path: 'data/image-provenance.json', policy: 'create', after: Buffer.from('{"image":"accepted"}\n')},
    {path: 'receipts/integration.json', policy: 'create', after: Buffer.from('{"integrated":true}\n')}
  ];
  const expectedPreimages = Object.fromEntries(artifacts.map(item => {
    const before = plan.observedBytes(root, item.path);
    return [item.path, before === null ? null : plan.sha256(before)];
  }));
  const changes = plan.makeChanges({repositoryRoot: root, artifacts, expectedPreimages});
  return {root, transaction, artifacts, expectedPreimages, changes,
    helperChanges: changes.map(change => ({...change, path: path.join(root, change.path)})),
    allowedPaths: artifacts.map(item => path.join(root, item.path))};
}
function runCase(name, fn) {
  const before = assertions;
  fn(fixture(name));
  cases.push({name, assertions: assertions - before, failures: 0});
}
runCase('successful-mixed-file-commit', f => {
  let verified = false;
  const description = helper.describePlan({repositoryRoot: f.root, transactionDir: f.transaction, allowedPaths: f.allowedPaths, changes: f.helperChanges});
  const result = helper.commitTransaction({repositoryRoot: f.root, transactionDir: f.transaction, allowedPaths: f.allowedPaths,
    changes: f.helperChanges, verify() { plan.verifyChanges(f.root, f.changes, 'after'); verified = true; }});
  same(verified, true);
  plan.verifyChanges(f.root, f.changes, 'after'); assertions++;
  const reconstructed = plan.trustedChanges({repositoryRoot: f.root, artifacts: f.artifacts, expectedPreimages: f.expectedPreimages,
    replacementPreimages: {'data/retail.json': f.changes.find(change => change.path === 'data/retail.json').before}});
  same(reconstructed, f.changes, 'Recovery reconstructs exact planned bytes without reading the changed live registry');
  const reconstructedDescription = helper.describePlan({repositoryRoot: f.root, transactionDir: f.transaction, allowedPaths: f.allowedPaths,
    changes: reconstructed.map(change => ({...change, path: path.join(f.root, change.path)}))});
  same(reconstructedDescription.planSha256, description.planSha256);
  same(fs.readFileSync(path.join(f.root, 'docs/source-license.txt')), Buffer.from('original identical CC0 source\r\n'));
  const recovery = helper.recoverTransaction({repositoryRoot: f.root, transactionDir: f.transaction, allowedPaths: f.allowedPaths});
  same(recovery.status, 'committed'); same(recovery.targetFilesMutated, false);
  plan.verifyChanges(f.root, f.changes, 'after'); assertions++;
  cases.push({name: 'successful-helper-result', result});
});
runCase('verification-failure-rolls-back-all-owned-files', f => {
  rejects(() => helper.commitTransaction({repositoryRoot: f.root, transactionDir: f.transaction, allowedPaths: f.allowedPaths,
    changes: f.helperChanges, verify() { plan.verifyChanges(f.root, f.changes, 'after'); throw new Error('Injected counter post-write verification failure'); }}), /Injected counter post-write verification failure/);
  plan.verifyChanges(f.root, f.changes, 'before'); assertions++;
  same(fs.readFileSync(path.join(f.root, 'data/retail.json')), Buffer.from('original registry bytes\r\n'));
  same(fs.readFileSync(path.join(f.root, 'docs/source-license.txt')), Buffer.from('original identical CC0 source\r\n'));
  for (const file of ['docs/source-model.glb', 'media/counter.png', 'data/image-provenance.json', 'receipts/integration.json']) same(fs.existsSync(path.join(f.root, file)), false);
});
runCase('different-existing-immutable-file-rejected', f => {
  fs.writeFileSync(path.join(f.root, 'docs/source-license.txt'), 'different existing source');
  const expected = {...f.expectedPreimages, 'docs/source-license.txt': plan.sha256(Buffer.from('different existing source'))};
  rejects(() => plan.makeChanges({repositoryRoot: f.root, artifacts: f.artifacts, expectedPreimages: expected}), /Existing immutable file differs/);
  same(fs.existsSync(f.transaction), false);
  same(fs.readFileSync(path.join(f.root, 'data/retail.json')), Buffer.from('original registry bytes\r\n'));
});
runCase('post-binding-preimage-drift-rejected', f => {
  fs.writeFileSync(path.join(f.root, 'data/retail.json'), 'concurrent unrelated registry change');
  rejects(() => plan.makeChanges({repositoryRoot: f.root, artifacts: f.artifacts, expectedPreimages: f.expectedPreimages}), /Target changed since baseline binding/);
  same(fs.existsSync(f.transaction), false);
  same(fs.readFileSync(path.join(f.root, 'data/retail.json'), 'utf8'), 'concurrent unrelated registry change');
});
runCase('interrupted-commit-requires-explicit-recovery', f => {
  const inputFile = path.join(directory, 'interruption-input.json');
  fs.writeFileSync(inputFile, JSON.stringify({repositoryRoot: f.root, transactionDir: f.transaction, allowedPaths: f.allowedPaths,
    changes: f.helperChanges.map(change => ({path: change.path, before: change.before === null ? null : change.before.toString('base64'), after: change.after.toString('base64')}))}), {flag: 'wx'});
  const childScript = [
    "const fs=require('node:fs');",
    "const helper=require(process.argv[1]);",
    "const input=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));",
    "input.changes=input.changes.map(c=>({...c,before:c.before===null?null:Buffer.from(c.before,'base64'),after:Buffer.from(c.after,'base64')}));",
    "input.verify=()=>process.exit(71);",
    'helper.commitTransaction(input);'
  ].join('\n');
  const child = spawnSync(process.execPath, ['--eval', childScript, path.join(__dirname, 'guarded-transaction.cjs'), inputFile],
    {cwd: __dirname, encoding: 'utf8', timeout: 15000, windowsHide: true});
  same(child.status, 71); same(child.error, undefined); same(child.signal, null);
  plan.verifyChanges(f.root, f.changes, 'after'); assertions++;
  rejects(() => helper.recoverTransaction({repositoryRoot: f.root, transactionDir: f.transaction, allowedPaths: f.allowedPaths.slice(1)}), /allow|path/i);
  plan.verifyChanges(f.root, f.changes, 'after'); assertions++;
  const described = helper.describePlan({repositoryRoot: f.root, transactionDir: f.transaction, allowedPaths: f.allowedPaths, changes: f.helperChanges});
  rejects(() => helper.recoverTransaction({repositoryRoot: f.root, transactionDir: f.transaction, allowedPaths: f.allowedPaths,
    expectedPlanSha256: '0'.repeat(64)}), /plan/i);
  plan.verifyChanges(f.root, f.changes, 'after'); assertions++;
  const result = helper.recoverTransaction({repositoryRoot: f.root, transactionDir: f.transaction, allowedPaths: f.allowedPaths,
    expectedPlanSha256: described.planSha256});
  plan.verifyChanges(f.root, f.changes, 'before'); assertions++;
  same(fs.readFileSync(path.join(f.root, 'docs/source-license.txt')), Buffer.from('original identical CC0 source\r\n'));
  cases.push({name: 'recovery-helper-result', result});
});
const result = {schema: 1, status: 'scratch_counter_transaction_adapter_checks_passed', assertions, failures: 0, cases,
  helper_raw_sha256: plan.sha256(fs.readFileSync(path.join(__dirname, 'guarded-transaction.cjs'))),
  adapter_raw_sha256: plan.sha256(fs.readFileSync(path.join(__dirname, 'transaction-plan.cjs'))),
  test_script_raw_sha256: plan.sha256(fs.readFileSync(__filename)),
  production_content_written: false, fixture_directory: directory};
fs.writeFileSync(path.join(directory, 'result.json'), JSON.stringify(result, null, 2) + '\n', {flag: 'wx'});
console.log(JSON.stringify(result));
