'use strict';
// Independent raw-byte, JSON and literal source inspection only.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto'), assert = require('node:assert/strict');
const root = 'Q:/.codex/worktrees/current-age-vocabulary/tesisgame';
const own = 'build/professional-english/foundation02-fifth10-root-binding-independent-review-r02';
const source = 'build/professional-english/foundation02-fifth10-root-binding-proposal-r02';
const prior = 'build/professional-english/foundation02-fifth10-root-binding-proposal-r01';
const priorReview = 'build/professional-english/foundation02-fifth10-root-binding-independent-review-r01';
const prep = 'build/professional-english/foundation02-fifth10-delivery-preparation-r03';
const output = path.join(root, own, 'inspection-r01');
assert(!fs.existsSync(output), 'Never replay a consumed independent inspection.');
fs.mkdirSync(output);
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
const inputs = new Map(), checks = [], notes = {};
function save(name, value) { fs.writeFileSync(path.join(output, name), JSON.stringify(value, null, 2) + '\n', {flag: 'wx'}); }
function at(relative) {
  assert(!path.isAbsolute(relative) && !relative.includes('\\'));
  const absolute = path.resolve(root, relative);
  assert.equal(path.relative(root, absolute).replaceAll('\\', '/'), relative);
  assert(!relative.startsWith('../'));
  return absolute;
}
function raw(relative) {
  const bytes = fs.readFileSync(at(relative));
  const value = {path: relative, bytes: bytes.length, raw_sha256: sha(bytes)};
  if (inputs.has(relative)) assert.deepEqual(inputs.get(relative), value, 'Input changed: ' + relative);
  else inputs.set(relative, value);
  return bytes;
}
function json(relative) { return JSON.parse(raw(relative)); }
function check(label, passed) { checks.push({label, passed: Boolean(passed)}); }
function equal(label, left, right) { let same = true; try { assert.deepEqual(left, right); } catch { same = false; } check(label, same); }
function pin(value, prefix = '') { const bytes = raw(prefix + value.path); check('Raw pin: ' + prefix + value.path, bytes.length === value.bytes && sha(bytes) === (value.raw_sha256 || value.sha256)); }
function inventory(value) {
  pin(value); const packet = json(value.path);
  const rows = packet.files || packet.artifacts;
  check('Nonempty inventory: ' + value.path, Array.isArray(rows) && rows.length > 0);
  for (const row of rows) pin(row, path.posix.dirname(value.path) + '/');
  return rows;
}
function exactSection(buffer) {
  const start = buffer.indexOf(Buffer.from('function at(relative)'));
  const end = buffer.indexOf(Buffer.from('function main()'), start);
  assert(start >= 0 && end > start);
  return buffer.subarray(start, end);
}
save('start.json', {schema: 1, started_at: new Date().toISOString(), scope: 'Independent source-only inspection of helper r02; no reviewed module execution and no actual binding'});
try {
  inventory({path: source + '/source-inventory.json', bytes: 1826, raw_sha256: 'b52fea9c2181064d024d35a05f599ad3b24897e2402927031f13e449e5a10993'});
  equal('Eight helper r02 inventory members', json(source + '/source-inventory.json').files.length, 8);
  pin({path: source + '/capture.cjs', bytes: 42867, raw_sha256: '8fdc5aeaa82eba2d6e4b4eea8a6a53b7b3b18e674d842ce7916263fa82cbe620'});
  inventory({path: prior + '/source-inventory.json', bytes: 1666, raw_sha256: '706a57585e1d96755755ac6c081b1623ac19bd55a0d83cb7f4742ae963797c9a'});
  inventory({path: priorReview + '/inventory.json', bytes: 1550, raw_sha256: '9ee41dab3cf3443627efa661180a7850ef119d88f3ced5790dc4fca1aa10ab39'});
  inventory({path: prep + '/source-inventory.json', bytes: 3279, raw_sha256: '2f4033d3edfeb6eacc78657e9c215ef8718bd3ceb275c94f4c6168e68d2c6ee3'});
  const priorInputs = json(priorReview + '/inspection-r01/inputs.json');
  for (const value of priorInputs.files) pin(value);
  equal('149 prior raw review inputs preserved', priorInputs.files.length, 149);
  const oldBytes = raw(prior + '/capture.cjs'), newBytes = raw(source + '/capture.cjs');
  equal('Entire predecessor/registry/projection section is byte-identical', exactSection(newBytes), exactSection(oldBytes));
  equal('Copied section exact raw hash', sha(exactSection(newBytes)), '20bc694f1718af6ded64d775080d2fa0d0d63034325deab10323187132cce745');
  const helper = newBytes.toString('utf8');
  equal('Only four built-in imports', [...helper.matchAll(/require\(([^)]*)\)/g)].map(row => row[1]), ["'node:fs'", "'node:path'", "'node:crypto'", "'node:assert/strict'"]);
  check('No source evaluation or subprocess dispatch', !/\b(?:eval|Function|spawn|spawnSync|exec|execSync|import)\s*\(/.test(helper));
  const anchors = [
    ["const own = '" + source + "';", 'Fresh r02 own directory'],
    ["if (Object.hasOwn(bagInput.expected_inputs, pin.path))", 'Compare only actual input/evidence overlaps'],
    ["assert.equal(bagInput.expected_inputs[pin.path], pin.sha256, 'Conflicting overlapping bag input/evidence pin');", 'Reject overlap conflict'],
    ["addPath(pin.path, pin.sha256, true); inheritedUnion.add(pin.path);", 'Add and retain every evidence row'],
    ["assert.equal(evidenceOverlap, 89); assert.equal(evidenceOnly, 490); assert.equal(inheritedUnion.size, 12230);", 'Measure exact sealed collection union'],
    ["if (pins.has(pin.path)) assert.deepEqual(pins.get(pin.path), pin, 'Conflicting input pin');", 'Reject conflicts with supplementary pins too'],
    ["assert.equal(bagInputPin.path, 'build/professional-english/shopping-bag-persisted-validation-r02/input.json');", 'Genuine r02 input path'],
    ["assert.equal(bagSourcePin.path, 'build/professional-english/shopping-bag-persisted-validation-r02/invoke.cjs');", 'Genuine r02 wrapper path'],
    ["assert.equal(bagSourcePin.raw_sha256, '6e138489e51f4789c1f2fd6a4039aa7e2f1af44ec435ff4309c33e568053bac5');", 'Exact reviewed replacement source'],
    ["const originalBagPersisted = 'build/professional-english/shopping-bag-persisted-validation-r02/attempt-001/receipt.json';", 'Genuine future r02 receipt path'],
    ["addPath(originalBagPersisted, config.bag_persisted_receipt.raw_sha256, true);", 'Original/copy persisted equality remains'],
    ["assert.equal(failedReceipt.ok, false);", 'Retain prior failure as failure'],
    ["assert.equal(failureCopies.status, 'exact_failed_attempt_and_review_copies'); assert.equal(failureCopies.files.length, 11);", 'Exact eleven failed-attempt copies'],
    ["add({path: row.source, bytes: row.bytes, raw_sha256: row.sha256}, true);", 'Retain each original failure input'],
    ["add({path: row.target, bytes: row.bytes, raw_sha256: row.sha256}, true);", 'Retain each durable failure copy'],
    ["assert.deepEqual(read(row.source), read(row.target), 'Changed prior failure copy');", 'Byte-equal failed evidence pairs'],
    ["inventory(supplement.prior_helper_source_inventory);", 'Prior helper entire inventory retained'],
    ["assert.equal(priorReview.helper_execution_accepted, false);", 'Prior rejection not relabeled'],
    ["assert.equal(helperReview.actual_binding_accepted, false);", 'Capture review does not accept binding'],
    ["assert.equal(helperReview.preparation_execution_accepted, false);", 'Capture review does not accept preparation'],
    ["for (const pin of binding.input_files) verifyPin(pin);", 'Complete final input recheck'],
    ["for (const [kind, value] of Object.entries(predecessors)) successfulPredecessor(kind, value, read);", 'Genuine predecessor final recheck'],
    ["fs.mkdirSync(at(config.output));", 'Scratch output only'],
    ["fs.writeFileSync(at(relative), bytes, {flag: 'wx'});", 'Exclusive fresh output files'],
    ["save('failed-attempt.json'", 'Preserve any consumed capture failure']
  ];
  for (const [literal, label] of anchors) check('Literal gate: ' + label, helper.includes(literal));
  check('Old subset-only assertion removed', !helper.includes('Evidence must remain in the complete bag closure'));
  const supplement = json(source + '/closure-supplement.json'), oldSupplement = json(prior + '/closure-supplement.json');
  equal('182 individually pinned supplemental paths', supplement.input_files.length, 182);
  equal('Thirteen inventory roots', supplement.inventory_roots.length, 13);
  equal('961 unchanged explicit dependency paths', supplement.explicit_runtime_dependencies, oldSupplement.explicit_runtime_dependencies);
  const retained = new Set(supplement.required_retained_sources), current = new Map(supplement.input_files.map(value => [value.path, value]));
  equal('All supplemental sources retained', [...retained].sort(), [...current.keys()].sort());
  for (const value of supplement.input_files) pin(value);
  for (const value of oldSupplement.input_files) equal('Old supplemental pin preserved: ' + value.path, current.get(value.path), value);
  let members = 0;
  for (const value of supplement.inventory_roots) {
    const rows = inventory(value); members += rows.length;
    check('Inventory root retained: ' + value.path, retained.has(value.path));
    for (const row of rows) check('Inventory member retained: ' + row.path, retained.has(path.posix.dirname(value.path) + '/' + row.path));
  }
  const failure = supplement.prior_bag_persisted_failure;
  pin(failure.receipt); pin(failure.copy_receipt);
  equal('Original failed receipt identity', failure.receipt.raw_sha256, '8680e417f593aa1e04225e258b9390e1cb944c7d91cf378288ff19011de2204d');
  equal('Original receipt remains failed', json(failure.receipt.path).ok, false);
  const copies = json(failure.copy_receipt.path).files;
  equal('Eleven original/durable failure pairs', copies.length, 11);
  for (const row of copies) {
    pin({path: row.source, bytes: row.bytes, raw_sha256: row.sha256});
    pin({path: row.target, bytes: row.bytes, raw_sha256: row.sha256});
    equal('Exact failed-evidence copy: ' + row.source, raw(row.source), raw(row.target));
    check('Both failed-evidence pair paths retained', retained.has(row.source) && retained.has(row.target));
  }
  pin(supplement.bag_persisted_source); pin(supplement.bag_persisted_input);
  equal('New input remains byte-identical to sealed r01 input', raw(supplement.bag_persisted_input.path), raw(oldSupplement.bag_persisted_input.path));
  const bagInput = json(supplement.bag_persisted_input.path), union = new Map(Object.entries(bagInput.expected_inputs));
  let overlap = 0, evidenceOnly = 0;
  for (const value of bagInput.evidence_files) {
    if (union.has(value.path)) { overlap++; equal('Matching actual overlap: ' + value.path, union.get(value.path), value.sha256); }
    else evidenceOnly++;
    union.set(value.path, value.sha256);
  }
  equal('Sealed collection counts', [Object.keys(bagInput.expected_inputs).length, bagInput.evidence_files.length, overlap, evidenceOnly, union.size], [11740, 579, 89, 490, 12230]);
  equal('Case-unique complete union', new Set([...union.keys()].map(value => value.toLowerCase())).size, 12230);
  for (const value of supplement.input_files) if (union.has(value.path)) equal('Supplement/complete-union overlap: ' + value.path, value.raw_sha256, union.get(value.path));
  for (const relative of supplement.explicit_runtime_dependencies) check('Explicit dependency in complete pin union: ' + relative, union.has(relative) || current.has(relative));
  const acceptancePath = 'build/professional-english/shopping-bag-persisted-independent-review-r02/review.json';
  equal('Root-selected r02 persisted source acceptance identity', sha(raw(acceptancePath)), '4267b52b1feaeb32f03edd54325a6f248fdab37d4fad41a0a4eb3692e6fd6d71');
  const acceptance = json(acceptancePath);
  equal('Helper selected source matches accepted r02 wrapper', {path: supplement.bag_persisted_source.path, bytes: supplement.bag_persisted_source.bytes, sha256: supplement.bag_persisted_source.raw_sha256}, acceptance.source);
  equal('Helper selected input matches accepted r02 input', {path: supplement.bag_persisted_input.path, bytes: supplement.bag_persisted_input.bytes, sha256: supplement.bag_persisted_input.raw_sha256}, acceptance.input);
  const oldWrapper = raw(oldSupplement.bag_persisted_source.path).toString('utf8').split('\n'), newWrapper = raw(supplement.bag_persisted_source.path).toString('utf8').split('\n');
  equal('Persisted wrapper line count unchanged', oldWrapper.length, newWrapper.length);
  equal('Only persisted reporter parser line changed', oldWrapper.flatMap((line, index) => line === newWrapper[index] ? [] : [index + 1]), [72]);
  const guards = json(source + '/guard-cases.json'), template = json(source + '/root-capture-input.template.json');
  equal('Twenty-seven unexecuted guard cases', guards.cases.length, 27);
  check('All guard specifications unexecuted', guards.cases.every(value => value.executed === false) && guards.helper_or_guard_execution_performed === false);
  check('Template still rejects execution', template.status === 'UNBOUND_DO_NOT_EXECUTE' && template.root_confirms_actual_bag_persisted_success === false && template.bag_persisted_receipt === null);
  check('Supplement selects no actual success or binding', supplement.actual_bag_persisted_receipt === null && supplement.actual_registry_binding === null);
  for (const value of inputs.values()) {
    const bytes = fs.readFileSync(at(value.path));
    assert.equal(bytes.length, value.bytes, 'Input changed: ' + value.path);
    assert.equal(sha(bytes), value.raw_sha256, 'Input changed: ' + value.path);
  }
  notes.copied_section_sha256 = sha(exactSection(newBytes));
  notes.inventory_member_rows_verified = members;
  notes.literal_gates = anchors.length;
  notes.inherited_union = {expected_inputs: 11740, evidence_files: 579, overlap, evidence_only: evidenceOnly, paths: union.size, actual_inherited_runtime_files_rehashed_by_this_review: false};
  notes.actual_bag_persisted_result_selected = false;
  const failed = checks.filter(value => !value.passed);
  save('inspection.json', {schema: 1, status: failed.length ? 'static_findings' : 'static_source_checks_passed', checks_passed: checks.length - failed.length, checks_failed: failed.length, checks, notes, measured_inputs: inputs.size, all_measured_inputs_rehashed_unchanged: true, helper_or_project_execution: false, guard_or_syntax_or_test_execution: false, actual_binding_created: false, production_mutated: false});
  save('inputs.json', {schema: 1, files: [...inputs.values()], all_rehashed_unchanged: true});
  console.log(JSON.stringify({checks_passed: checks.length - failed.length, checks_failed: failed.length, measured_inputs: inputs.size, failed: failed.slice(0, 10), notes}));
} catch (error) {
  save('failure.json', {schema: 1, error: error.stack || String(error), partial_checks: checks, inputs: [...inputs.values()], replay_allowed: false});
  throw error;
}
