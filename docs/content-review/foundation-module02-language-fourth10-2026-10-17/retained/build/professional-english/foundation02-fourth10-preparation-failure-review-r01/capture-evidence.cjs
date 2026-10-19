'use strict';
// Independent JSON and raw-byte inspection. No project implementation is imported.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');

const root = 'Q:/.codex/worktrees/current-age-vocabulary/tesisgame';
const output = 'build/professional-english/foundation02-fourth10-preparation-failure-review-r01';
assert.equal(path.resolve(process.cwd()).replaceAll('\\', '/').toLowerCase(), root.toLowerCase());
assert.equal(path.resolve(__dirname).replaceAll('\\', '/').toLowerCase(), `${root}/${output}`.toLowerCase());
const sourceReview = 'build/professional-english/foundation02-fourth10-preparation-source-review-r01';
const proposal = 'build/professional-english/foundation02-fourth10-delivery-preparation-r01';
const witness = 'build/professional-english/foundation02-fourth10-root-preparation-r01';
const fifthReview = 'build/professional-english/foundation-module01-language-review/fifth10';
const ledgerPath = 'docs/content-review/foundation-module02-language-fourth10-research-2026-10-17/candidate-ledger.json';
const expectedResource = 'res://data/professional/lexemes/foundation-module02.json';
const ids = [
  'submit.send-for-consideration.v', 'approve.authorize.v', 'reject.decline-acceptance.v',
  'sign.write-name.v', 'delay.late-occurrence.n', 'error.mistake.n', 'fault.equipment-defect.n',
  'damage.physical-harm.n', 'shortage.insufficient-supply.n', 'missing.not-present.adj'
];
const historyKeys = ['first10', 'second10', 'third10', 'fourth10', 'fifth10'];
const historyHashes = [
  'c6c6083fe03324ac5ea5d1e7c5ec7cf2bad92559616d8437ce32d572fe1b3d92',
  '528267cabf4ef12daa9977da23267131c3b69d223f76d1a4a83fcac9ba9973e7',
  'd821f85146ef5e5e14ee5b4cee9ce129d0c6652f683090bc44fb7af14d6d14f1',
  '8ab99dbd7a7ea692401c594259986328d43e04e676557c51d15aa675fc7bf83b',
  'ccd4ab160b89efbc21289c51fd576933d7da19734567ee986656b4462ad06083'
];
const expectedCounts = Object.fromEntries(ids.map(id => [id,
  id === 'sign.write-name.v' ? [1, 1, 1, 1, 2] : [1, 1, 1, 1, 1]]));
function local(relative) {
  assert.equal(path.isAbsolute(relative), false);
  assert.equal(relative.includes('\\'), false);
  const resolved = path.resolve(root, relative);
  assert.equal(path.relative(root, resolved).replaceAll('\\', '/'), relative);
  assert.ok(!relative.startsWith('../'));
  return resolved;
}
const bytes = file => fs.readFileSync(local(file));
const read = file => JSON.parse(bytes(file).toString('utf8'));
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const jsonHash = value => hash(JSON.stringify(value));
function measure(file) { const value = bytes(file); return {path: file, bytes: value.length, sha256: hash(value)}; }
function writeNew(name, value) {
  assert.match(name, /^[a-z0-9-]+\.json$/);
  fs.writeFileSync(local(`${output}/${name}`), JSON.stringify(value, null, 2) + '\n', {flag: 'wx'});
}
function filesBelow(directory) {
  const result = [];
  for (const item of fs.readdirSync(local(directory), {withFileTypes: true})) {
    const file = `${directory}/${item.name}`;
    if (item.isDirectory()) result.push(...filesBelow(file));
    else { assert.ok(item.isFile()); result.push(file); }
  }
  return result.sort();
}
const startedAt = new Date().toISOString();
const sourcePins = {
  [`${sourceReview}/inventory.json`]: 'c97cd34b74ccb28d642832dfce3990406140db1b2b9767f946c3da36a8ded0f8',
  [`${sourceReview}/static-measurements.json`]: 'd1df61937309599f0538a13933ae13afb697d5b4afdaf3d9c93d311666e590a0',
  [`${sourceReview}/evidence-summary.json`]: '502015bac4c0be20a077bea6b8e893111e49ab09898c0dc562869fd61bf0b51e',
  [`${sourceReview}/review.json`]: 'c5c0d17720fc7e02a52c9623ad08c0546f8e6c00c6787cdd25ed08403dfa034d',
  [`${witness}/execution/receipt.json`]: '9305ef12ea2570f4f0502751b551670e1cf992601c9978251b9150100025ab07',
  [`${witness}/execution/command-4.log`]: '241d2609dd7cc6def544b42130468140c6689a6b2d8bfddfa8397cde9dbe78b7',
  [`${fifthReview}/preimages.json`]: 'a7400da1bd33130b62f0e49d6bff48d4f8ecb498712fef9d5464f0014749193d'
};
for (const [file, expected] of Object.entries(sourcePins)) assert.equal(measure(file).sha256, expected, file);
const oldInventory = read(`${sourceReview}/inventory.json`);
for (const row of oldInventory.artifacts) {
  const actual = measure(`${sourceReview}/${row.path}`);
  assert.equal(actual.sha256, row.raw_sha256);
  assert.equal(actual.bytes, row.bytes);
}
const oldMeasurement = read(`${sourceReview}/static-measurements.json`);
const oldSummary = read(`${sourceReview}/evidence-summary.json`);
assert.equal(oldMeasurement.input_measurements.length, 800);
assert.equal(oldSummary.context_paths_beyond_800_pin_union.length, 3);
const pins = oldMeasurement.input_measurements.map(row => ({
  path: row.path, expected_sha256: row.expected_sha256, expected_bytes: row.expected_bytes,
  evidence: `${sourceReview}/static-measurements.json`
}));
for (const row of oldSummary.context_paths_beyond_800_pin_union) pins.push({
  path: row.path, expected_sha256: row.expected_historical_sha256,
  evidence: `${sourceReview}/evidence-summary.json`
});
assert.equal(new Set(pins.map(row => row.path)).size, 803);
const inputBefore = pins.map(pin => {
  const actual = measure(pin.path);
  assert.equal(actual.sha256, pin.expected_sha256, pin.path);
  if (Object.hasOwn(pin, 'expected_bytes')) assert.equal(actual.bytes, pin.expected_bytes, pin.path);
  return {...pin, actual_sha256: actual.sha256, actual_bytes: actual.bytes, matches_frozen_input: true};
});
const preservedPaths = [...new Set([
  ...filesBelow(proposal), ...filesBelow(sourceReview), ...filesBelow(witness),
  `${fifthReview}/preimages.json`, `${fifthReview}/delivery-r01/delivery-lib.cjs`,
  'docs/content-review/foundation-module01-language-fifth10-2026-10-16/preimages.json'
])].sort();
const preservedBefore = preservedPaths.map(measure);
const receipt = read(`${witness}/execution/receipt.json`);
assert.equal(receipt.ok, false);
assert.equal(receipt.sources_unchanged, true);
assert.deepEqual(receipt.commands.map(row => row.exit_code), [0, 0, 0, 1]);
for (const row of receipt.sources) assert.deepEqual(measure(row.path), row);
const ledger = read(ledgerPath);
assert.deepEqual(ledger.entries.map(row => row.id), ids);
const current = read('data/professional/lexemes/foundation-module02.json');
const beforeById = new Map(ledger.entries.map(row => [row.id, row]));
for (const row of ledger.entries) {
  assert.equal(jsonHash(row.before_entry), row.before_entry_sha256);
  const matches = current.lexemes.filter(entry => entry.id === row.id);
  assert.equal(matches.length, 1);
  assert.deepEqual(matches[0], row.before_entry);
}
let wholeRowsChecked = 0;
const histories = historyKeys.map((key, historyIndex) => {
  const file = `data/professional/provenance/foundation-module01-language-${key}-2026-10-16.json`;
  const fingerprint = measure(file);
  assert.equal(fingerprint.sha256, historyHashes[historyIndex]);
  const history = read(file);
  const groups = ids.map(id => {
    const before = beforeById.get(id);
    const expectedRow = {resource: expectedResource, json_sha256: before.before_entry_sha256, entry: before.before_entry};
    const rows = history.protected_context.lexemes.map((row, index) => ({row, index})).filter(item => item.row.entry.id === id);
    assert.equal(rows.length, expectedCounts[id][historyIndex], `${key}/${id}`);
    const checks = rows.map(({row, index}) => {
      assert.deepEqual(row, expectedRow, `Exact whole donor row ${key}/${id}/${index}`);
      assert.equal(jsonHash(row.entry), row.json_sha256);
      wholeRowsChecked++;
      return {index_zero_based: index, resource: row.resource, recorded_entry_json_sha256: row.json_sha256,
        computed_entry_json_sha256: jsonHash(row.entry), whole_row_json_sha256: jsonHash(row),
        exact_whole_row_matches_expected: true, full_entry_matches_ledger_before: true};
    });
    return {id, expected_count: expectedCounts[id][historyIndex], actual_count: rows.length, rows: checks};
  });
  return {key, ...fingerprint, groups};
});
assert.equal(wholeRowsChecked, 51);
const pre = read(`${fifthReview}/preimages.json`);
const durablePrePath = 'docs/content-review/foundation-module01-language-fifth10-2026-10-16/preimages.json';
assert.deepEqual(bytes(`${fifthReview}/preimages.json`), bytes(durablePrePath));
assert.equal(pre.unselected_foundation_entries.length, 90);
assert.equal(pre.related_entries.length, 65);
const fifthPath = histories[4].path;
const fifth = read(fifthPath);
assert.deepEqual(fifth.protected_context.lexemes, [...pre.unselected_foundation_entries, ...pre.related_entries]);
const signRow = {resource: expectedResource, json_sha256: beforeById.get(ids[3]).before_entry_sha256, entry: beforeById.get(ids[3]).before_entry};
assert.deepEqual(pre.unselected_foundation_entries[73], signRow);
assert.deepEqual(pre.related_entries[0], signRow);
assert.deepEqual(fifth.protected_context.lexemes[73], signRow);
assert.deepEqual(fifth.protected_context.lexemes[90], signRow);
const donorReview = {
  schema: 1, status: 'independent_json_inspection_complete', root,
  hash_basis: 'Raw-byte SHA256 for files; UTF-8 JSON.stringify for parsed entry and row JSON hashes.',
  histories, expected_counts_by_id_in_history_order: expectedCounts, history_order: historyKeys,
  history_id_groups_checked: 50, whole_rows_checked: 51,
  ledger: measure(ledgerPath), current_foundation02: measure('data/professional/lexemes/foundation-module02.json'),
  duplicate_origin: {
    history: fifthPath, id: ids[3], indices_zero_based: [73, 90],
    original_preimages: measure(`${fifthReview}/preimages.json`), durable_preimages: measure(durablePrePath),
    original_and_durable_preimages_raw_bytes_equal: true,
    categories: [{name: 'unselected_foundation_entries', index_zero_based: 73, category_count: 90},
      {name: 'related_entries', index_zero_based: 0, category_count: 65}],
    constructor: {...measure(`${fifthReview}/delivery-r01/delivery-lib.cjs`), line: 92,
      expression: 'lexemes:[...evidence.pre.unselected_foundation_entries,...evidence.pre.related_entries]'},
    entire_history_lexemes_array_matches_original_category_concatenation: true,
    whole_row: signRow, whole_row_json_sha256: jsonHash(signRow), both_whole_rows_equal: true
  }
};
const inputAfter = pins.map(pin => measure(pin.path));
for (let i = 0; i < inputBefore.length; i++) {
  assert.equal(inputAfter[i].sha256, inputBefore[i].actual_sha256, pins[i].path);
  assert.equal(inputAfter[i].bytes, inputBefore[i].actual_bytes, pins[i].path);
}
const preservedAfter = preservedPaths.map(measure);
assert.deepEqual(preservedAfter, preservedBefore);
writeNew('donor-review.json', donorReview);
writeNew('input-measurements.json', {schema: 1, started_at: startedAt, finished_at: new Date().toISOString(),
  total_inputs: 803, frozen_inputs: 800, additional_context_inputs: 3, mismatches: [],
  all_inputs_match_previous_frozen_measurement: true, before: inputBefore, after: inputAfter});
writeNew('preservation-measurements.json', {schema: 1, preserved_file_count: preservedBefore.length,
  before: preservedBefore, after: preservedAfter, unchanged: true});
writeNew('review.json', {
  schema: 1, status: 'diagnosis_complete_strict_replacement_constraints_only', reviewer: 'Codex recover_delivery',
  recorded_at: new Date().toISOString(), failed_root_receipt: measure(`${witness}/execution/receipt.json`),
  failed_log: measure(`${witness}/execution/command-4.log`),
  finding: 'r01 wrongly assumes one historical donor per history and selected ID. Fifth10 sign has two legitimate identical whole donor rows from overlapping protected categories.',
  prior_review_limit: 'The previous static source review missed this exact multiplicity assumption. Its scratch-dispatch acceptance did not establish successful preparation or output acceptance.',
  evidence: ['donor-review.json', 'input-measurements.json', 'preservation-measurements.json', 'strict-assertion-recommendation.md'],
  exact_history_id_groups: 50, exact_whole_donor_rows: 51, unchanged_input_count: 803,
  all_pinned_inputs_unchanged: true, r01_and_original_source_review_preserved: true,
  replacement_constraints: [
    'Explicit five-history and ten-ID coverage with exact counts: sign [1,1,1,1,2]; each other selected ID [1,1,1,1,1].',
    'Every donor row must deep-equal the expected whole resource/json_sha256/entry object and every entry must equal the exact before entry.',
    'The reversed live entry must equal every historical row entry; existing morphology/media/domain checks remain.',
    'Preserve all historical donor rows and bytes. No deduplication, relaxed minimum counts, first-row-only comparisons, old-callback execution, or r01 revision.'
  ],
  project_code_imported: false, old_prepare_or_transform_callbacks_invoked: false,
  syntax_or_project_tests_dispatched: false, preparation_dispatched: false,
  native_dispatched: false, production_modified: false, preparation_accepted: false,
  next_step: 'A separate author may create isolated r02 source for root review and root-owned dispatch.'
});
console.log(JSON.stringify({status: 'complete', inputs_unchanged: 803, groups_checked: 50, whole_rows_checked: 51,
  preserved_files: preservedBefore.length, output}, null, 2));
