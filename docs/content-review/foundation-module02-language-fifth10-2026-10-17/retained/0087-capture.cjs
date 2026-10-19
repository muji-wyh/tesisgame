'use strict';
// Independent raw-byte/JSON/literal inspection only. No reviewed module is imported.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = 'Q:/.codex/worktrees/current-age-vocabulary/tesisgame';
const own = 'build/professional-english/foundation02-fifth10-preparation-independent-review-r03';
const source = 'build/professional-english/foundation02-fifth10-delivery-preparation-r03';
const prior = 'build/professional-english/foundation02-fifth10-delivery-preparation-r02';
const priorReview = 'build/professional-english/foundation02-fifth10-preparation-independent-review-r02';
const output = path.join(root, own, 'capture-attempt-r01');
assert(!fs.existsSync(output), 'Never replay a consumed static capture.');
fs.mkdirSync(output);
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const encode = value => Buffer.from(JSON.stringify(value, null, 2) + '\n');
const inputs = new Map(), checks = [], observations = {};
function save(name, value) { fs.writeFileSync(path.join(output, name), encode(value), {flag: 'wx'}); }
function abs(relative) {
  assert.equal(typeof relative, 'string');
  assert(!path.isAbsolute(relative) && !relative.includes('\\'));
  const result = path.resolve(root, relative);
  assert.equal(path.relative(root, result).replaceAll('\\', '/'), relative);
  assert(!relative.startsWith('../'));
  return result;
}
function raw(relative) {
  const bytes = fs.readFileSync(abs(relative));
  const pin = {path: relative, bytes: bytes.length, raw_sha256: sha(bytes)};
  if (inputs.has(relative)) assert.deepEqual(pin, inputs.get(relative), 'Input changed: ' + relative);
  else inputs.set(relative, pin);
  return bytes;
}
function json(relative) { return JSON.parse(raw(relative)); }
function text(relative) { return raw(relative).toString('utf8'); }
function check(label, value) { checks.push({label, passed: Boolean(value)}); }
function equal(label, left, right) {
  let same = true;
  try { assert.deepEqual(left, right); } catch { same = false; }
  check(label, same);
}
function pin(row, prefix = '') {
  const bytes = raw(prefix + row.path);
  check('Raw pin: ' + prefix + row.path, bytes.length === row.bytes && sha(bytes) === (row.raw_sha256 || row.sha256));
}
function relative(value) {
  return path.isAbsolute(value) ? path.relative(root, value).replaceAll('\\', '/') : value;
}
function inspectJournal(label, commit, selected, currentTargets) {
  const transaction = relative(selected.transaction);
  const statePath = relative(selected.state.path);
  const preparedBytes = raw(transaction + '/prepared.json');
  const prepared = JSON.parse(preparedBytes);
  const stateBytes = raw(statePath), state = JSON.parse(stateBytes);
  equal(label + ' prepared hash links selected receipt', sha(preparedBytes), selected.prepared);
  equal(label + ' terminal hash links selected receipt', sha(stateBytes), selected.state.sha256);
  equal(label + ' plan serialization matches original transaction identity', sha(encode(prepared.plan)), selected.plan);
  equal(label + ' prepared plan identity', prepared.plan_sha256, selected.plan);
  equal(label + ' committed state prepared identity', state.prepared_sha256, selected.prepared);
  equal(label + ' repository root', path.resolve(prepared.plan.repository_root), path.resolve(root));
  const manifest = prepared.plan.entries;
  if (selected.manifest) equal(label + ' full receipt/plan manifest equality', manifest, selected.manifest);
  equal(label + ' allowed path set', prepared.plan.allowed_paths, manifest.map(row => row.path).sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase())));
  equal(label + ' prepared entry count', prepared.entries.length, manifest.length);
  equal(label + ' complete committed target manifest', state.targets, manifest.map(row => ({path: row.path, ...row.after, noop: row.noop})));
  equal(label + ' unique paths', new Set(manifest.map(row => row.path.toLowerCase())).size, manifest.length);
  for (const [index, row] of manifest.entries()) {
    equal(label + ' manifest keys: ' + index, Object.keys(row).sort(), ['after', 'before', 'noop', 'path']);
    const preparedRow = prepared.entries[index];
    equal(label + ' prepared descriptor: ' + index, {path: preparedRow.path, before: preparedRow.before, after: preparedRow.after, noop: preparedRow.noop}, row);
    if (currentTargets) pin({path: row.path, bytes: row.after.bytes, raw_sha256: row.after.sha256});
  }
  const names = fs.readdirSync(abs(transaction + '/states')).sort();
  equal(label + ' actual latest state path', transaction + '/states/' + names.at(-1), statePath);
  const expected = [{status: 'prepared'}];
  for (const [index, row] of manifest.entries()) {
    if (!row.noop) expected.push({status: 'applying', path: row.path});
    expected.push({status: row.noop ? 'noop' : 'applied', path: row.path, index});
  }
  expected.push({status: 'committed'});
  equal(label + ' complete actual state count', names.length, expected.length);
  let previous = null;
  for (const [index, name] of names.entries()) {
    const bytes = raw(transaction + '/states/' + name), row = JSON.parse(bytes);
    check(label + ' numbered state filename: ' + name, name === String(index + 1).padStart(6, '0') + '-' + row.status + '.json');
    check(label + ' hash chain and prepared identity: ' + name, row.schema === 1 && row.sequence === index + 1 && row.previous_state_sha256 === previous && row.prepared_sha256 === selected.prepared);
    check(label + ' ordered transition: ' + name, expected[index] && Object.entries(expected[index]).every(([key, value]) => row[key] === value));
    previous = sha(bytes);
  }
  equal(label + ' complete chain terminates at selected receipt hash', previous, selected.state.sha256);
  observations[label] = {commit_receipt_status: commit.status, target_count: manifest.length, state_count: names.length, plan_sha256: selected.plan, prepared_sha256: selected.prepared, terminal_state: {path: statePath, raw_sha256: selected.state.sha256}, current_targets_checked: currentTargets};
}
save('start.json', {schema: 1, started_at: new Date().toISOString(), method: 'Independent built-in raw-file hashes, JSON structure comparison and literal source inspection', reviewed_modules_imported: false, guard_or_preparation_or_project_execution: false});
try {
  equal('Exact frozen r03 source inventory', sha(raw(source + '/source-inventory.json')), '2f4033d3edfeb6eacc78657e9c215ef8718bd3ceb275c94f4c6168e68d2c6ee3');
  const inventory = json(source + '/source-inventory.json');
  equal('Seventeen frozen r03 members', inventory.files.length, 17);
  for (const row of inventory.files) pin(row, source + '/');
  const priorInventory = json(prior + '/source-inventory.json');
  equal('Exact frozen r02 inventory', sha(raw(prior + '/source-inventory.json')), '21df8c149742cb4fc63acecb033bfb7d499e10310b5467c8ff81bd715db73598');
  for (const row of priorInventory.files) pin(row, prior + '/');
  const lineage = json(source + '/revision-lineage.json');
  equal('Eight declared preserved members', lineage.unchanged_r02_members.length, 8);
  for (const row of lineage.unchanged_r02_members) {
    pin(row, source + '/'); pin(row, prior + '/');
    equal('Exact old/new preserved member: ' + row.path, raw(source + '/' + row.path), raw(prior + '/' + row.path));
  }
  equal('Exact prior inventory copy', raw(source + '/prior-source-inventory.json'), raw(prior + '/source-inventory.json'));
  equal('Exact prior independent rejection copy', raw(source + '/prior-independent-review.json'), raw(priorReview + '/review.json'));
  const reviewInventory = json(priorReview + '/inventory.json');
  for (const row of reviewInventory.files) pin(row, priorReview + '/');
  const oldInputs = json(priorReview + '/capture-attempt-r01/inputs.json');
  equal('Previous static review measured 74 raw inputs', oldInputs.files.length, 74);
  for (const row of oldInputs.files) pin(row);
  const contract = json(source + '/accepted-contract.json');
  equal('Eight accepted entries remain', contract.patches.length, 8);
  equal('Sixteen consulted sources remain', contract.sources.length, 16);
  equal('Six full holds remain', contract.whole_entry_holds.length, 6);
  equal('Fifty complete donor rows remain', json(source + '/donor-row-contract.json').rows.length, 50);
  const binding = text(source + '/binding.cjs');
  const anchors = [
    ["const own = '" + source + "';", 'r03 binding owns correct directory'],
    ["const AUTHOR = '/root/recover_delivery';", 'Current author role'],
    ["const INHERITED_AUTHOR = '/root/runtime_recovery';", 'Inherited author role'],
    ["const DISPATCHER = '/root';", 'Root dispatcher role'],
    ["assert(value.length > 0 && value === value.trim()", 'Reject missing/empty/padded reviewer'],
    ["assert.match(value, /^\\/root\\/[a-z0-9_]+$/", 'Canonical reviewer identity'],
    ["assert(![AUTHOR, INHERITED_AUTHOR, DISPATCHER].includes(value)", 'Reviewer distinct from both authors and dispatcher'],
    ["assert.equal(review.reviewer, binding.roles.independent_reviewer);assert.deepEqual(review.roles, binding.roles);", 'Review/binding role agreement'],
    ["assert.deepEqual(review.source_inventory, input.source_inventory);assert.deepEqual(review.actual_binding, input.binding);", 'Complete acceptance pin agreement'],
    ["if (kind === 'fourth10')", 'Explicit fourth-ten receipt branch'],
    ["assert.equal(stage.receipt_schema, 'shopping_bag_top_level_commit_and_persisted_input_v1');", 'Explicit genuine bag receipt schema'],
    ["assert.equal(Object.hasOwn(commit, 'result'), false", 'Reject fabricated bag wrapper'],
    ["assert.deepEqual(commit.journal.state, commit.state);", 'Embedded bag journal agrees with selected state'],
    ["assert.equal(pin.raw_sha256, expectedHash, key);", 'Journal pin must equal commit named identity'],
    ["assert.deepEqual(bytes, original, 'Durable journal copy differs from actual original');", 'Durable copy exact bytes'],
    ["assert.deepEqual(stage.journal_copies, copies", 'No omitted or unused journal aliases'],
    ["assert.equal(sha(serialize(prepared.plan)), prepared.plan_sha256", 'Prepared plan serialization identity'],
    ["assert.equal(prepared.plan_sha256, selected.plan_sha256", 'Plan linked to selected commit'],
    ["assert.equal(journal.prepared_sha256, selected.prepared_sha256);", 'State linked to prepared journal'],
    ["assert.deepEqual(manifest, selected.target_manifest", 'Full bag receipt manifest matches plan'],
    ["assert.deepEqual(journal.targets, manifest.map(row => ({path: row.path, ...row.after, noop: row.noop}))", 'Full state target manifest'],
    ["assert.deepEqual(sorted(stage.installed_targets), sorted(complete)", 'Complete installed bag target equality'],
    ["for (const pin of stage.installed_targets) readPin(pin, read);", 'Every installed target rehashed'],
    ["assert.equal(stage.persisted_source.raw_sha256, persisted.source_sha256);readPin(stage.persisted_source, read);", 'Persisted source bytes and receipt linked'],
    ["assert.equal(stage.persisted_input.raw_sha256, persisted.input_sha256);", 'Persisted input linked to receipt'],
    ["assert.equal(persistedInput.commit_receipt.path, stage.committed_receipt.path);assert.equal(persistedInput.commit_receipt.sha256, stage.committed_receipt.raw_sha256);", 'Persisted input links exact commit'],
    ["assert.equal(persistedInput.committed_journal.path, receiptRelative(commit.state.path));assert.equal(persistedInput.committed_journal.sha256, commit.state.sha256);", 'Persisted input links exact original state'],
    ["for (const row of commit.target_manifest) assert.equal(persistedInput.expected_inputs[row.path], row.after.sha256", 'Persisted input covers every committed target'],
    ["assert.equal(sha(read(log)), command.log_sha256, log);", 'Persisted logs independently pinned'],
    ["assert.equal(bag.commit.registry_after_sha256, binding.registry_before_sha256", 'Baseline starts from delivered bag registry'],
    ["assert.equal(names.at(-1), path.posix.basename(state));", 'Recheck latest actual committed state']
  ];
  for (const [literal, label] of anchors) check('Literal source contract: ' + label, binding.includes(literal));
  observations.literal_source_contracts = anchors.length;
  const prepare = text(source + '/prepare.cjs'), projection = text(source + '/projection.cjs');
  check('Unchanged preparation resolves output through r03 binding', prepare.includes("B.at(B.own+'/execution-r01')"));
  check('Unchanged projection resolves accepted contracts through r03 binding', projection.includes("B.own+'/accepted-contract.json'") && projection.includes("B.own+'/context-contract.json'") && projection.includes("B.own+'/donor-row-contract.json'"));
  check('Predecessor gate runs before output and reviewed proposal imports', prepare.indexOf('const ctx=B.openSession(') < prepare.indexOf('fs.mkdirSync(output)') && prepare.indexOf('const ctx=B.openSession(') < prepare.indexOf("require('./projection.cjs')"));
  const guards = json(source + '/guard-cases.json');
  equal('Twenty-nine unexecuted guard cases', guards.negative_cases.length, 29);
  check('No guard execution claim', guards.executed === false && guards.actual_fixture === null && guards.negative_cases.every(row => row.executed === false));
  const template = json(source + '/actual-baseline-binding.template.json');
  check('Actual baseline remains unbound', template.bound === false && template.status === 'UNBOUND_TEMPLATE_DO_NOT_DISPATCH');
  const rootTemplate = json(source + '/root-input.template.json');
  equal('Root template selects correct r03 entrypoint', rootTemplate.entrypoint, source + '/prepare.cjs');
  const fourthPath = 'docs/content-review/foundation-module02-language-fourth10-2026-10-17/commit-receipt.json';
  equal('Accepted fourth-ten commit receipt raw hash', sha(raw(fourthPath)), '96fff4c1ac94147e99efcb8f18ff07711a5c2e53729fa07695d7d2296ae037f8');
  const fourth = json(fourthPath);
  check('Genuine fourth-ten nested-result success shape', fourth.status === 'committed' && fourth.result.status === 'committed' && fourth.result.committed === true && fourth.result.state.status === 'committed');
  inspectJournal('fourth10', fourth, {transaction: fourth.result.transactionDir, state: fourth.result.state, prepared: fourth.result.preparedSha256, plan: fourth.result.planSha256}, false);
  const fourthPersistedPath = 'build/professional-english/foundation02-fourth10-persisted-validation-r01/attempt-001/receipt.json';
  equal('Accepted fourth-ten persisted receipt raw hash', sha(raw(fourthPersistedPath)), 'f25fbeb4fa8fafe08b0431653a5a9171d8369581aed104faad3e0161bbaf40f7');
  const fourthPersisted = json(fourthPersistedPath);
  check('Genuine fourth-ten persisted success shape', fourthPersisted.schema === 1 && fourthPersisted.ok === true && fourthPersisted.error === null && fourthPersisted.source_before === fourthPersisted.source_after && fourthPersisted.commands.length === 4);
  equal('Fourth-ten persisted receipt selects durable committed-receipt path', fourthPersisted.committed_receipt, {path: fourthPath, sha256: sha(raw(fourthPath))});
  for (const command of fourthPersisted.commands) {
    check('Fourth-ten actual successful command: ' + command.log, command.exit_code === 0 && command.error === null && command.signal === null);
    equal('Fourth-ten actual command log: ' + command.log, sha(raw(path.posix.dirname(fourthPersistedPath) + '/' + command.log)), command.log_sha256);
  }
  const bagPath = 'build/professional-english/shopping-bag-root-commit-r01/execution-r01/receipt.json';
  equal('Observed actual bag commit receipt raw hash', sha(raw(bagPath)), 'b5b263fda99813d9c45564d5fdc35a8b437f5a3a91ec60b06eb1b00e45ddb681');
  const bag = json(bagPath);
  check('Genuine bag top-level success shape', bag.schema === 1 && bag.status === 'committed' && bag.committed === true && !Object.hasOwn(bag, 'result'));
  inspectJournal('shopping_bag', bag, {transaction: bag.transaction_dir, state: bag.state, prepared: bag.prepared_sha256, plan: bag.plan_sha256, manifest: bag.target_manifest}, true);
  equal('Bag embedded exact state', bag.journal.state, bag.state);
  check('Bag embedded exact prepared/plan/count summary', bag.journal.status === 'committed' && bag.journal.prepared_sha256 === bag.prepared_sha256 && bag.journal.plan_sha256 === bag.plan_sha256 && bag.journal.verified_targets === bag.target_manifest.length && bag.journal.state_count === observations.shopping_bag.state_count);
  equal('Bag commit source identity', sha(raw('build/professional-english/shopping-bag-commit-proposal-r01/commit.cjs')), bag.source_sha256);
  const persistedSourcePath = 'build/professional-english/shopping-bag-persisted-validation-r01/invoke.cjs';
  equal('Exact bag persisted wrapper inspected', sha(raw(persistedSourcePath)), 'c25cafb5332e391eeb76d59a51e5f317199504a2c112b7fdfca2e7a52435221f');
  const persistedSource = text(persistedSourcePath);
  check('Bag persisted wrapper actual emitted source/input/error fields', persistedSource.includes('source_sha256: sourceHash, input_sha256: process.argv[3], commands, audit, tests, error: failure, postcheck_error: postcheckError'));
  check('Bag persisted wrapper actual args fields', persistedSource.includes('commands.push({args,') && persistedSource.includes("['tools/validate-professional-content.cjs', '--json']"));
  check('Bag persisted wrapper actual input commit/state/targets', persistedSource.includes('input.commit_receipt.path') && persistedSource.includes('input.committed_journal.path') && persistedSource.includes('input.target_count') && persistedSource.includes('input.expected_inputs'));
  check('Bag persisted wrapper command schema matches proposed binding', binding.includes("persisted.commands.map(command => command.args), [['tools/validate-professional-content.cjs', '--json'], ['--test', 'tests/professional-content.test.cjs', 'tests/professional-retail-morphology.test.cjs', 'tests/professional-retail-media.test.cjs']]"));
  observations.bag_persisted = {source_path: persistedSourcePath, source_raw_sha256: sha(raw(persistedSourcePath)), inspection: 'Raw source schema only; no persisted input or success receipt selected by this source-only review', actual_persisted_binding: null};
  for (const row of inputs.values()) {
    const bytes = fs.readFileSync(abs(row.path));
    assert.equal(bytes.length, row.bytes, 'Input length changed: ' + row.path);
    assert.equal(sha(bytes), row.raw_sha256, 'Input changed: ' + row.path);
  }
  const failed = checks.filter(row => !row.passed);
  save('inspection.json', {schema: 1, status: failed.length ? 'static_comparison_findings' : 'static_comparisons_passed_source_only', checks_passed: checks.length - failed.length, checks_failed: failed.length, checks, observations, actual_binding: null, preparation_execution_accepted: false, reviewed_modules_imported: false, guard_or_preparation_or_project_execution: false, production_mutated: false});
  save('inputs.json', {schema: 1, files: [...inputs.values()], all_rehashed_unchanged: true});
  console.log(JSON.stringify({checks_passed: checks.length - failed.length, checks_failed: failed.length, measured_inputs: inputs.size, failed, observations}));
} catch (error) {
  save('failure.json', {schema: 1, error: error.stack || String(error), partial_checks: checks, inputs: [...inputs.values()], replay_allowed: false});
  throw error;
}
