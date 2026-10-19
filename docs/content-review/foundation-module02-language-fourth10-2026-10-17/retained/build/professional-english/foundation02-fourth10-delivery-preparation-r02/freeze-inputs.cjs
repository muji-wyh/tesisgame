'use strict';
// One-time raw input inventory and donor observation only. No project or candidate imports.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = 'Q:/.codex/worktrees/current-age-vocabulary/tesisgame';
const relativeOut = 'build/professional-english/foundation02-fourth10-delivery-preparation-r02';
const previous = 'build/professional-english/foundation02-fourth10-delivery-preparation-r01';
const finding = 'build/professional-english/foundation02-fourth10-preparation-failure-review-r01';
const out = path.resolve(root, relativeOut);
assert.equal(path.resolve(__dirname).toLowerCase(), out.toLowerCase());
assert.equal(path.resolve(process.cwd()).toLowerCase(), path.resolve(root).toLowerCase());
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
const hash = value => sha(JSON.stringify(value));
const sourceBefore = sha(fs.readFileSync(__filename));
const startedAt = new Date().toISOString();
const outputs = ['input-pins.json', 'input-freeze-receipt.json', 'author-inventory.json'];
for (const name of outputs) assert(!fs.existsSync(path.join(out, name)), 'Freeze already consumed');
assert(!fs.existsSync(path.join(out, 'execution-r01')), 'Candidate must remain unexecuted');
const raw = file => fs.readFileSync(path.join(root, file));
const parse = file => JSON.parse(raw(file));
const inputs = new Map();
function observe(file, expected) {
  assert(!path.isAbsolute(file) && !file.includes('\\') && !file.startsWith('../'));
  assert.equal(path.relative(root, path.resolve(root, file)).replaceAll('\\', '/'), file);
  const value = raw(file), measured = {path: file, raw_sha256: sha(value), bytes: value.length};
  if (expected) assert.equal(measured.raw_sha256, expected, file);
  if (inputs.has(file)) assert.deepEqual(inputs.get(file), measured, file);
  inputs.set(file, measured);
  return measured;
}
function observeTree(directory) {
  for (const item of fs.readdirSync(path.join(root, directory), {withFileTypes: true}).sort((a,b) => a.name.localeCompare(b.name))) {
    const file = directory + '/' + item.name;
    assert(!item.isSymbolicLink(), 'No linked evidence path');
    if (item.isDirectory()) observeTree(file);
    else { assert(item.isFile()); observe(file); }
  }
}
const previousPinBytes = raw(previous + '/input-pins.json');
assert.equal(sha(previousPinBytes), 'd58ea126241c8585d7b8887fa7698520fde2d0134de5f60d9599a19bb92adaa5');
const pins = JSON.parse(previousPinBytes);
assert.equal(pins.files.length, 800);
for (const row of pins.files) observe(row.path, row.raw_sha256);
const context = parse(pins.original_context_manifest.path);
assert.equal(sha(raw(pins.original_context_manifest.path)), pins.original_context_manifest.raw_sha256);
assert.equal(context.source_file_hashes.length, 355);
const historicalDifferences = [];
for (const row of context.source_file_hashes) {
  const current = sha(raw(row.path));
  const delta = pins.approved_rebase_file_deltas.find(item => item.path === row.path);
  if (current !== row.raw_sha256) {
    assert(delta && delta.historical_raw_sha256 === row.raw_sha256 && delta.current_raw_sha256 === current);
    historicalDifferences.push(delta);
  }
  observe(row.path, delta ? delta.current_raw_sha256 : row.raw_sha256);
}
assert.equal(inputs.size, 803, 'Complete original input/context union');
assert.deepEqual(historicalDifferences.slice().sort((a,b) => a.path.localeCompare(b.path)), pins.approved_rebase_file_deltas.slice().sort((a,b) => a.path.localeCompare(b.path)));
const baselinePathCount = inputs.size;
observe(previous + '/author-inventory.json', 'b4e418aaaec0c4748b32264438c66e0ba6f65944e97f3f31988a430f570e0f04');
for (const row of parse(previous + '/author-inventory.json').artifacts) observe(previous + '/' + row.path, row.raw_sha256);
observe(finding + '/inventory.json', '01936ecbb484020da8d50155d4955d42a4312834ec4ca8bae475c5a85fb9e92f');
const diagnosisInventory = parse(finding + '/inventory.json');
for (const row of diagnosisInventory.artifacts) observe(finding + '/' + row.path, row.raw_sha256);
observe(finding + '/review.json', '128db76183e79166b9bb766d1b7fb1390b0fb1f1b378a41b215cb3a238a3e328');
observe(finding + '/donor-review.json', '9a667e75ecc75b10664b976159f8ff6a4cef945d40a9ed246d64337285b3dd40');
const diagnosis = parse(finding + '/review.json');
assert.equal(diagnosis.status, 'diagnosis_complete_strict_replacement_constraints_only');
assert.deepEqual([diagnosis.exact_history_id_groups, diagnosis.exact_whole_donor_rows, diagnosis.unchanged_input_count], [50,51,803]);
assert.equal(diagnosis.preparation_accepted, false);
const failureReceipt = 'build/professional-english/foundation02-fourth10-root-preparation-r01/execution/receipt.json';
observe(failureReceipt, '9305ef12ea2570f4f0502751b551670e1cf992601c9978251b9150100025ab07');
assert.equal(parse(failureReceipt).ok, false);
for (const directory of [previous, 'build/professional-english/foundation02-fourth10-root-preparation-r01', 'build/professional-english/foundation02-fourth10-preparation-source-review-r01', finding, 'docs/qa/professional-foundation02-fourth10-r01/preparation-failure']) observeTree(directory);
const validation = parse(pins.third10_persisted_validation.path);
const measurement = parse(pins.third10_measurement_manifest.path);
observe(pins.third10_commit_receipt.path, pins.third10_commit_receipt.raw_sha256);
observe(pins.third10_persisted_validation.path, pins.third10_persisted_validation.raw_sha256);
observe(pins.third10_measurement_manifest.path, pins.third10_measurement_manifest.raw_sha256);
assert.equal(validation.ok, true);
assert.equal(validation.checked_inputs, 686);
assert.equal(Object.keys(measurement.expected_inputs).length, 686);
for (const [file, expected] of Object.entries(measurement.expected_inputs)) observe(file, expected);
for (const absent of pins.must_remain_absent) assert(!fs.existsSync(path.join(root, absent)), absent);
const ids = ['submit.send-for-consideration.v','approve.authorize.v','reject.decline-acceptance.v','sign.write-name.v','delay.late-occurrence.n','error.mistake.n','fault.equipment-defect.n','damage.physical-harm.n','shortage.insufficient-supply.n','missing.not-present.adj'];
const histories = ['first10','second10','third10','fourth10','fifth10'].map(label => {
  const file = 'data/professional/provenance/foundation-module01-language-' + label + '-2026-10-16.json';
  observe(file);
  return {label, file, data: parse(file)};
});
const module02 = parse('data/professional/lexemes/foundation-module02.json');
const donorGroups = [];
for (const id of ids) {
  const liveMatches = module02.lexemes.filter(entry => entry.id === id);
  assert.equal(liveMatches.length, 1);
  const entry = liveMatches[0], counts = id === 'sign.write-name.v' ? [1,1,1,1,2] : [1,1,1,1,1];
  const expected = {resource: 'res://data/professional/lexemes/foundation-module02.json', json_sha256: hash(entry), entry};
  for (const [index, history] of histories.entries()) {
    const matches = history.data.protected_context.lexemes.map((row, rowIndex) => ({row, rowIndex})).filter(item => item.row.entry.id === id);
    assert.equal(matches.length, counts[index]);
    for (const item of matches) assert.deepEqual(item.row, expected);
    donorGroups.push({id, history: history.label, history_path: history.file, count: matches.length, indices: matches.map(item => item.rowIndex), whole_row_json_sha256: matches.map(item => hash(item.row)), entry_json_sha256: hash(entry), resource: expected.resource});
  }
}
assert.equal(donorGroups.length, 50);
assert.equal(donorGroups.reduce((sum, group) => sum + group.count, 0), 51);
const originalPreimages = 'build/professional-english/foundation-module01-language-review/fifth10/preimages.json';
observe(originalPreimages);
const preimages = parse(originalPreimages);
assert.deepEqual(histories[4].data.protected_context.lexemes, [...preimages.unselected_foundation_entries, ...preimages.related_entries]);
assert.equal(preimages.unselected_foundation_entries.length, 90);
assert.deepEqual(preimages.unselected_foundation_entries[73], preimages.related_entries[0]);
assert.equal(preimages.related_entries[0].entry.id, 'sign.write-name.v');
assert.deepEqual(donorGroups.find(group => group.id === 'sign.write-name.v' && group.history === 'fifth10').indices, [73,90]);
const localNames = ['HANDOFF.md','TRANSACTION.md','author-r02.cjs','revision-derivation.json','author-coverage-r02.cjs','coverage-supplement.json','freeze-inputs.cjs','projection.cjs','test-transforms.cjs','prepare.cjs'];
assert.deepEqual(fs.readdirSync(out).sort(), localNames.slice().sort());
const localPins = localNames.map(name => ({path: name, bytes: fs.statSync(path.join(out, name)).size, raw_sha256: sha(fs.readFileSync(path.join(out, name)))}));
const expectedCode = { 'projection.cjs': 'c07b67580921610e94425d3f2c01b620203163d7a6ef40be2a4ebe07edf12da9', 'test-transforms.cjs': '7886b3c0d03766f2f0a3f460e6e2cbf391384338fe747f8defa2ce308d1d4dc9', 'prepare.cjs': '612d9b98fd62b62492f7140a034ccb29a8c75fb07fc2937fa6b7787e35c98621' };
for (const [name, expected] of Object.entries(expectedCode)) assert.equal(localPins.find(row => row.path === name).raw_sha256, expected);
for (const row of inputs.values()) assert.equal(sha(raw(row.path)), row.raw_sha256, 'Input changed during freeze: ' + row.path);
for (const row of localPins) assert.equal(sha(fs.readFileSync(path.join(out, row.path))), row.raw_sha256, 'Source changed during freeze');
assert.equal(sha(fs.readFileSync(__filename)), sourceBefore);
const allInputs = [...inputs.values()].sort((a,b) => a.path.localeCompare(b.path));
const nextPins = {...pins, recorded_at: startedAt, revision: 'r02', predecessor_input_pins: {path: previous + '/input-pins.json', raw_sha256: sha(previousPinBytes)}, failed_predecessor_receipt: {path: failureReceipt, raw_sha256: '9305ef12ea2570f4f0502751b551670e1cf992601c9978251b9150100025ab07'}, independent_failure_diagnosis: {path: finding + '/inventory.json', raw_sha256: '01936ecbb484020da8d50155d4955d42a4312834ec4ca8bae475c5a85fb9e92f'}, files: allInputs, measurement_paths: allInputs.map(row => row.path), measurement_path_count: allInputs.length, validation_boundary: 'Fresh r02 source/input inventory after preserved r01 failure. No r02 candidate implementation, syntax, callbacks, native, commit or persisted checks executed. Third10 validation applies only to its actual unchanged baseline.'};
const write = (name, object) => { assert(outputs.includes(name)); const bytes = Buffer.from(JSON.stringify(object, null, 2) + '\n'); fs.writeFileSync(path.join(out, name), bytes, {flag: 'wx'}); return {path: name, bytes: bytes.length, raw_sha256: sha(bytes)}; };
const pinRecord = write('input-pins.json', nextPins);
const receiptRecord = write('input-freeze-receipt.json', {
  schema: 1, status: 'static_r02_input_inventory_frozen_no_candidate_execution', recorded_at: new Date().toISOString(),
  input_pins_sha256: pinRecord.raw_sha256, files_measured: allInputs.length, original_input_context_union: baselinePathCount,
  preserved_r01_input_pin_count: pins.files.length, persisted_third10_inputs_exact: 686, historical_context_files: 355,
  exact_historical_file_differences: historicalDifferences,
  independent_failure_diagnosis_inventory_sha256: '01936ecbb484020da8d50155d4955d42a4312834ec4ca8bae475c5a85fb9e92f',
  failed_r01_receipt_sha256: '9305ef12ea2570f4f0502751b551670e1cf992601c9978251b9150100025ab07',
  freeze_source_before_sha256: sourceBefore, freeze_source_after_sha256: sha(fs.readFileSync(__filename)),
  all_observed_inputs_stable: true, all_local_sources_stable: true,
  exact_donor_groups: donorGroups, exact_donor_group_count: 50, exact_whole_donor_row_count: 51,
  original_fifth10_array_matches_exact_preimage_concatenation: true,
  candidate_implementation_imported_or_executed: false, projected_afterimages_generated: false, syntax_or_shared_tests_dispatched: false,
  native_dispatched: false, production_mutated: false, historical_scripts_replayed: false,
  method: 'Node built-in raw-byte SHA256 observations and JSON donor comparisons, then only exclusive reviewer-owned metadata writes. No project or candidate code imports.'
});
const artifacts = [...localPins, pinRecord, receiptRecord].sort((a,b) => a.path.localeCompare(b.path));
const inventoryRecord = write('author-inventory.json', {
  schema: 1, status: 'unexecuted_r02_author_delivery_proposal_ready_for_independent_source_review', recorded_at: new Date().toISOString(),
  author: 'Codex runtime_recovery delivery proposal author', directory: relativeOut, repository_root: root,
  input_files_pinned: allInputs.length, original_input_context_union: baselinePathCount, third10_validated_inputs_exact: 686,
  registry_before_sha256: pins.registry_json_sha256, historical_research_registry_sha256: pins.historical_registry_json_sha256,
  independent_language_review_sha256: '58993d8767ec701e37613fdee70d75e94f22a68d467b94157ea41a211bc9f8bd',
  independent_failure_diagnosis_inventory_sha256: '01936ecbb484020da8d50155d4955d42a4312834ec4ca8bae475c5a85fb9e92f',
  accepted_language_projections: 10, actual_content_changed_entries: 6, content_field_edits: {difficulty: 6, definition: 1, example: 1}, proposed_source_additions: 20,
  exact_historical_donor_groups: 50, exact_whole_donor_rows: 51,
  production_mutated: false, shared_tests_mutated: false, candidate_implementation_imported_or_executed: false,
  static_source_derivation_and_metadata_writers_executed: true, syntax_checked: false, projected_afterimages_generated: false,
  tests_or_native_dispatched: false, historical_scripts_replayed: false, new_language_approval: false, independent_source_review_pending: true,
  artifacts, self_excluded: true
});
console.log(JSON.stringify({status: 'r02_source_and_input_inventory_frozen', input_count: allInputs.length, original_union: baselinePathCount, whole_donor_rows: 51, inventory: inventoryRecord, input_pins: pinRecord, freeze_receipt: receiptRecord}, null, 2));
