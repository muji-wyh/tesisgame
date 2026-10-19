# Strict replacement constraints

Retain exact counts by immutable history and selected ID. In history order first10, second10, third10, fourth10, fifth10, `sign.write-name.v` requires `[1, 1, 1, 1, 2]`. Each other selected ID requires `[1, 1, 1, 1, 1]`. Require exact coverage of the ten selected IDs and five history records so an unexpected ID cannot silently fall into a default count rule.

For each matching row, require complete structural equality with `{resource, json_sha256, entry}`. The resource is `res://data/professional/lexemes/foundation-module02.json`, the hash is the patch's verified `before_sha256`, and the entry is the complete patch `before`. Require the reversed live entry to equal every row's entry. Preserve all existing morphology, media, review-domain and deliberate-drift assertions.

The illustrative loop below is an unexecuted recommendation. The author must integrate it in a new r02 revision with explicit constants and retain the five source-history raw hashes in the frozen input set.

```js
const expectedIds = [
  'submit.send-for-consideration.v', 'approve.authorize.v',
  'reject.decline-acceptance.v', 'sign.write-name.v',
  'delay.late-occurrence.n', 'error.mistake.n',
  'fault.equipment-defect.n', 'damage.physical-harm.n',
  'shortage.insufficient-supply.n', 'missing.not-present.adj'
];
const countsById = {
  'submit.send-for-consideration.v': [1, 1, 1, 1, 1],
  'approve.authorize.v': [1, 1, 1, 1, 1],
  'reject.decline-acceptance.v': [1, 1, 1, 1, 1],
  'sign.write-name.v': [1, 1, 1, 1, 2],
  'delay.late-occurrence.n': [1, 1, 1, 1, 1],
  'error.mistake.n': [1, 1, 1, 1, 1],
  'fault.equipment-defect.n': [1, 1, 1, 1, 1],
  'damage.physical-harm.n': [1, 1, 1, 1, 1],
  'shortage.insufficient-supply.n': [1, 1, 1, 1, 1],
  'missing.not-present.adj': [1, 1, 1, 1, 1]
};
const histories = [
  ['first10', foundationLanguageRecord],
  ['second10', foundationSecondLanguageRecord],
  ['third10', foundationThirdLanguageRecord],
  ['fourth10', foundationFourthLanguageRecord],
  ['fifth10', foundationFifthLanguageRecord]
];
assert.deepEqual(histories.map(([key]) => key),
  ['first10', 'second10', 'third10', 'fourth10', 'fifth10']);
assert.deepEqual(Object.keys(countsById), expectedIds);
assert.deepEqual(foundation02FourthLanguageRecord.patches.map(p => p.id), expectedIds);
for (const p of foundation02FourthLanguageRecord.patches) {
  // Keep the existing exact live-entry, morphology, media, domain, and drift checks.
  const liveMatches = data.lexemes.filter(row => row.id === p.id);
  assert.equal(liveMatches.length, 1);
  const reversedLive = beforeFoundationLanguage(liveMatches[0]);
  assert.deepEqual(reversedLive, p.before);
  for (const [historyIndex, [key, history]] of histories.entries()) {
    const snapshots = history.protected_context.lexemes.filter(row => row.entry.id === p.id);
    assert.equal(snapshots.length, countsById[p.id][historyIndex], `${key}/${p.id}`);
    for (const snapshot of snapshots) {
      assert.deepEqual(snapshot, {
        resource: 'res://data/professional/lexemes/foundation-module02.json',
        json_sha256: p.before_sha256,
        entry: p.before
      });
      assert.deepEqual(reversedLive, snapshot.entry);
    }
  }
}
```

The fifth10 sign rows must remain at their historical multiplicity. Do not change or deduplicate history, use a minimum-count assertion, use `.find()` to select one donor, compare only the first match, or omit whole-row resource/hash checks. Do not overwrite, rerun, or clean the failed r01 attempt.
