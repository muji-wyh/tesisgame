'use strict';
// UNEXECUTED outline. Pure construction sketches only. No file IO or dispatch.
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const hash = value => crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
const clone = value => structuredClone(value);

function unique(rows, id, label) {
  const matches = rows.filter(row => row.id === id);
  assert.equal(matches.length, 1, label + ': exact identity multiplicity');
  return matches[0];
}

function protectedFields(entry) {
  const value = clone(entry);
  for (const key of ['definition', 'example', 'difficulty', 'references', 'editorial_notes']) delete value[key];
  for (const key of ['status', 'language', 'reviewer', 'reviewed_at']) delete value.review[key];
  return value;
}

function validateAcceptedPairs(contract) {
  assert.equal(contract.patches.length, 8);
  assert.equal(contract.sources.length, 16);
  assert.equal(contract.whole_entry_holds.length, 6);
  assert.equal(new Set(contract.patches.map(row => row.id)).size, 8);
  assert.equal(new Set(contract.sources.map(row => row.id)).size, 16);
  assert.equal(contract.acceptance.delivery_metadata_technical_acceptance, true);
  assert.equal(contract.acceptance.new_language_acceptance, false);
  const contentCounts = {definition: 0, example: 0, difficulty: 0};
  for (const patch of contract.patches) {
    const accepted = unique(contract.acceptance.accepted_delivery_entries, patch.id, 'Accepted decision');
    assert.equal(hash(patch.before), patch.before_entry_json_sha256);
    assert.equal(hash(patch.after), patch.after_entry_json_sha256);
    assert.equal(hash(patch.after), accepted.accepted_delivery_entry_json_sha256);
    assert.deepEqual(protectedFields(patch.before), protectedFields(patch.after));
    assert.deepEqual(patch.after.references.slice(0, patch.before.references.length), patch.before.references);
    const additions = patch.after.references.slice(patch.before.references.length);
    assert.equal(additions.length, 2);
    assert.deepEqual(additions.map(row => row.source_id), patch.source_ids);
    for (const field of Object.keys(contentCounts)) {
      assert.deepEqual(patch.after[field], patch.accepted_fields[field]);
      if (patch.before[field] !== patch.after[field]) contentCounts[field]++;
    }
    for (const sourceId of patch.source_ids) unique(contract.sources, sourceId, 'Accepted source');
  }
  assert.deepEqual(contentCounts, {definition: 4, example: 1, difficulty: 5});
  for (const hold of contract.whole_entry_holds) {
    assert.equal(hash(hold.before_entry), hold.entry_json_sha256);
    assert.equal(contract.patches.some(patch => patch.id === hold.id), false);
  }
  for (const source of contract.sources) {
    assert.equal(source.status, 'consulted');
    assert.equal(source.assets_acquired, false);
    assert.equal(source.asset_license, null);
  }
}

function lexicalCandidate(beforeEnvelope, contract) {
  validateAcceptedPairs(contract);
  for (const patch of contract.patches) assert.deepEqual(unique(beforeEnvelope.lexemes, patch.id, 'Live preimage'), patch.before);
  for (const hold of contract.whole_entry_holds) assert.deepEqual(unique(beforeEnvelope.lexemes, hold.id, 'Whole hold'), hold.before_entry);
  const patches = new Map(contract.patches.map(patch => [patch.id, patch]));
  const afterEnvelope = clone(beforeEnvelope);
  afterEnvelope.lexemes = beforeEnvelope.lexemes.map(entry => clone(patches.get(entry.id)?.after || entry));
  assert.equal(afterEnvelope.lexemes.length, beforeEnvelope.lexemes.length);
  assert.deepEqual(afterEnvelope.lexemes.filter(entry => !patches.has(entry.id)), beforeEnvelope.lexemes.filter(entry => !patches.has(entry.id)));
  return afterEnvelope;
}

function sourceCandidate(beforeEnvelope, contract) {
  validateAcceptedPairs(contract);
  const existing = beforeEnvelope.sources;
  assert.equal(new Set(existing.map(source => source.id)).size, existing.length);
  for (const source of contract.sources) assert.equal(existing.some(row => row.id === source.id), false);
  for (const id of contract.excluded_source_ids) {
    assert.equal(existing.some(source => source.id === id), false);
    assert.equal(contract.sources.some(source => source.id === id), false);
  }
  const after = clone(beforeEnvelope);
  after.sources.push(...clone(contract.sources));
  assert.deepEqual(after.sources.slice(0, existing.length), existing);
  assert.deepEqual(after.sources.slice(existing.length), contract.sources);
  return after;
}

function checkCompleteDonors(actualHistoryObjectsByPath, donorContract) {
  assert.equal(donorContract.rows.length, 50);
  assert.equal(new Set(donorContract.rows.map(row => row.history_path + '/' + row.id)).size, 50);
  for (const expected of donorContract.rows) {
    const rows = actualHistoryObjectsByPath[expected.history_path].protected_context.lexemes;
    assert.equal(rows.filter(row => row.entry.id === expected.id).length, 1);
    assert.equal(expected.exact_count, 1);
    const actual = rows[expected.index];
    assert.deepEqual(actual, expected.whole_row);
    assert.deepEqual(Object.keys(actual), ['resource', 'json_sha256', 'entry']);
    assert.equal(hash(actual), expected.whole_row_json_sha256);
    assert.equal(hash(actual.entry), actual.json_sha256);
  }
}

function prepare() {
  throw new Error('UNBOUND outline: no preparation dispatch exists. Root must bind actual post-bag persisted success and review a concrete new runner first.');
}

module.exports = {status: 'UNBOUND_OUTLINE_ONLY', validateAcceptedPairs, lexicalCandidate, sourceCandidate, checkCompleteDonors, prepare};
if (require.main === module) prepare();
