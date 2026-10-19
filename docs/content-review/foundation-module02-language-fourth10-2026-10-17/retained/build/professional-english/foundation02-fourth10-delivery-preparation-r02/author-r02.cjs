'use strict';
// Static source derivation only. Does not import project or candidate modules or run checks.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = 'Q:/.codex/worktrees/current-age-vocabulary/tesisgame';
const relativeOut = 'build/professional-english/foundation02-fourth10-delivery-preparation-r02';
const previous = 'build/professional-english/foundation02-fourth10-delivery-preparation-r01';
const out = path.resolve(root, relativeOut);
assert.equal(path.resolve(__dirname).toLowerCase(), out.toLowerCase());
assert.equal(path.resolve(process.cwd()).toLowerCase(), path.resolve(root).toLowerCase());
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
const sourceBefore = sha(fs.readFileSync(__filename));
const pins = [
  ['projection.cjs', 'c07b67580921610e94425d3f2c01b620203163d7a6ef40be2a4ebe07edf12da9'],
  ['test-transforms.cjs', 'f28949a1cdb0dfceb1875ec7abfd6478aa2502dfecb3b6e8e37d1bd113c58d5e'],
  ['prepare.cjs', '6fa9ddd5547673b797c302a4b1c78d8b3be64a9b90f07cfe2771a3f2236b9c11']
];
const originals = new Map(pins.map(([name, expected]) => {
  const raw = fs.readFileSync(path.join(root, previous, name));
  assert.equal(sha(raw), expected, name);
  return [name, raw];
}));
const oldCallback = '    for(const history of [foundationLanguageRecord,foundationSecondLanguageRecord,foundationThirdLanguageRecord,foundationFourthLanguageRecord,foundationFifthLanguageRecord]){const snapshots=history.protected_context.lexemes.filter(row=>row.entry.id===p.id);assert.equal(snapshots.length,1);assert.deepEqual(beforeFoundationLanguage(entry),snapshots[0].entry);}';
const newCallback = `    const histories=[foundationLanguageRecord,foundationSecondLanguageRecord,foundationThirdLanguageRecord,foundationFourthLanguageRecord,foundationFifthLanguageRecord];
    const expectedCounts=p.id==='sign.write-name.v'?[1,1,1,1,2]:[1,1,1,1,1];
    const expectedRow={resource:'res://data/professional/lexemes/foundation-module02.json',json_sha256:p.before_sha256,entry:p.before};
    assert.equal(data.lexemeOrigins[p.id],expectedRow.resource);
    for(const [historyIndex,history] of histories.entries()){
      const snapshots=history.protected_context.lexemes.filter(row=>row.entry.id===p.id);
      assert.equal(snapshots.length,expectedCounts[historyIndex],p.id+': exact historical snapshot multiplicity '+historyIndex);
      for(const snapshot of snapshots){
        assert.deepEqual(snapshot,expectedRow,p.id+': exact whole historical donor row '+historyIndex);
        assert.deepEqual(snapshot.entry,beforeFoundationLanguage(entry),p.id+': exact historical reversal '+historyIndex);
      }
    }`;
let transformed = originals.get('test-transforms.cjs').toString('utf8');
assert.equal(transformed.split(oldCallback).length - 1, 1, 'Exactly one newly proposed fourth-ten callback is corrected');
transformed = transformed.replace(oldCallback, newCallback);
let prepare = originals.get('prepare.cjs').toString('utf8');
const oldSources = "const sourceNames = ['input-pins.json', 'input-freeze-receipt.json', 'projection.cjs', 'test-transforms.cjs', 'prepare.cjs', 'HANDOFF.md', 'TRANSACTION.md', 'author-inventory.json'];";
const newSources = "const sourceNames = ['input-pins.json', 'input-freeze-receipt.json', 'projection.cjs', 'test-transforms.cjs', 'prepare.cjs', 'HANDOFF.md', 'TRANSACTION.md', 'author-r02.cjs', 'revision-derivation.json', 'freeze-inputs.cjs', 'author-inventory.json'];";
assert.equal(prepare.split(oldSources).length - 1, 1);
prepare = prepare.replace(oldSources, newSources);
const outputs = [
  ['projection.cjs', originals.get('projection.cjs')],
  ['test-transforms.cjs', Buffer.from(transformed)],
  ['prepare.cjs', Buffer.from(prepare)]
];
for (const [name] of outputs) assert(!fs.existsSync(path.join(out, name)), 'Never overwrite a source revision');
assert(!fs.existsSync(path.join(out, 'revision-derivation.json')), 'Derivation already consumed');
for (const [name, expected] of pins) assert.equal(sha(fs.readFileSync(path.join(root, previous, name))), expected);
assert.equal(sha(fs.readFileSync(__filename)), sourceBefore);
for (const [name, raw] of outputs) fs.writeFileSync(path.join(out, name), raw, {flag: 'wx'});
const record = {
  schema: 1, status: 'unexecuted_preparation_r02_static_sources_derived', recorded_at: new Date().toISOString(),
  author: 'Codex runtime_recovery delivery proposal author', repository_root: root,
  author_source_before_sha256: sourceBefore, author_source_after_sha256: sha(fs.readFileSync(__filename)),
  predecessor: previous,
  source_preimages: pins.map(([name, raw_sha256]) => ({path: previous + '/' + name, raw_sha256})),
  output_sources: outputs.map(([name, raw]) => ({path: name, bytes: raw.length, raw_sha256: sha(raw)})),
  changes: [
    {file: 'projection.cjs', action: 'Exact byte copy; language, provenance, protected context and proposed output semantics unchanged'},
    {file: 'test-transforms.cjs', action: 'One exact callback anchor replacement', before: oldCallback, after: newCallback, count: 1},
    {file: 'prepare.cjs', action: 'Extend source witnesses to bind r02 derivation and input-freeze source', before: oldSources, after: newSources, count: 1}
  ],
  exact_multiplicity: {history_order: ['Foundation01 first10', 'Foundation01 second10', 'Foundation01 third10', 'Foundation01 fourth10', 'Foundation01 fifth10'], sign: [1,1,1,1,2], other_nine_fourth10_ids: [1,1,1,1,1], expected_total_rows: 51, expected_groups: 50},
  duplicate_origin: 'Fifth10 protected_context.lexemes[73] and [90] originate from identical preimages.unselected_foundation_entries[73] and preimages.related_entries[0], concatenated by delivery-lib.cjs. Both complete rows must match resource, json_sha256 and entry.',
  original_failure_preserved: true, history_rewritten_or_deduplicated: false, broad_guard_exception: false,
  production_mutated: false, shared_tests_mutated: false, candidate_modules_imported: false,
  preparation_or_projection_dispatched: false, syntax_checked: false, tests_dispatched: false, native_dispatched: false,
  input_freeze_pending: true, independent_source_review_pending: true, root_dispatch_required: true
};
const raw = Buffer.from(JSON.stringify(record, null, 2) + '\n');
fs.writeFileSync(path.join(out, 'revision-derivation.json'), raw, {flag: 'wx'});
console.log(JSON.stringify({status: record.status, revision_derivation_sha256: sha(raw), outputs: record.output_sources}, null, 2));
