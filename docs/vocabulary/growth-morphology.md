# Growth morphology overlay

The morphology overlay preserves the original 1,550 Growth vocabulary records.
It stores individual review decisions separately from `words.json`, curriculum
membership, media, progress and saves. All 265 context-only entries retain their
original missing-image state. A review never supplies an invented illustration
or changes eligibility in another game.

## Authored decisions

`tools/author-growth-morphology.cjs` and the explicit cohort modules in
`tools/growth-morphology/` contain the editorial decisions. The tool serializes
these decisions; it does not discover roots, strip suffixes, split at midpoints,
or classify unlisted words as atomic. Each reviewed identity has its own
contemporary-sense rationale and references. Words without an explicit decision
remain pending and have no analysis.

An explicit cohort `pending` map can reopen a previous decision with an individual
reason. Authoring rejects unknown IDs, duplicate reopenings, empty reasons, and
IDs that are simultaneously reviewed and pending before it writes any overlay.
Reopening removes the playable analysis; the previous decision is retained in
review history rather than remaining available behind a pending label.

The 2026-10-16 bound-family correction newly reviewed attract, connect, include,
receive, reflect, and adapt using term-specific source evidence. It temporarily
withdrew nine uncertain analyses; the complete old and new decisions, source
consultation scopes, and acceptance hashes remain preserved in
[the correction history](review-history/2026-10-16-bound-family-corrections.json).

A subsequent individual review resolved all nine withdrawals using 22 newly
consulted sources and an independent AI cross-check. Compare, investigate,
suggest, separate, multiply, divide, estimate, and retire now have explicit
inherited-family graphs. Explore retains its complete current stem after review
of competing historical accounts; it grants exposure, not composition mastery.
The complete transition and exact acceptance hashes are preserved in
[the resolution history](review-history/2026-10-16-nine-bound-family-resolutions.json).
All 1,550 Growth entries are reviewed, with zero pending entries, and the strict
complete-migration audit passes. This coverage result does not imply human
linguistic approval or change Professional content readiness.

Canonical identities preserve the important distinctions: compare uses par
equal while separate uses par prepare; divide uses the separate-root vide rather
than the sight root; retire uses the French drawing family rather than tire
weary. Investigate and separate have explicit bound intermediate stems,
investig and separ. These intermediates are not independent English words and
never grant mastery. Historical component glosses do not replace the current
whole-word meanings.

The named reviewer is `Codex (AI editorial review; not human approval)`.
This accurately records the provenance of this pass; it does not imply a human
linguist approved the catalog. The framework is Catherine Anderson's
*Essentials of Linguistics*, sections 6.1–6.4 and 7.1–7.3. Lexical references
record their URL, author, consultation date and the evidence used. The source
registry distinguishes the general framework from individual dictionary
evidence. Original rationales are written for these vocabulary senses.

An atomic analysis means that the round exposes the approved whole form. It
does not claim that the word has no grammatical properties or historical
structure. For example, suppletive pronouns and verb forms, lexical plurals,
borrowings and opaque lexicalized formations can be kept whole when a
decomposition would teach a misleading modern relation. Each such choice is
recorded individually. These tiles provide exposure, not composition mastery.

Compound and derived analyses preserve the selected sense. The fast in
breakfast is the abstention noun, not the speed adjective; bow in rainbow is
the arc sense, not ribbon. Friendly uses adjectival -ly. Authored outputs handle
changes such as anger + -y → angry, have + -s → has, and dry + -er → dryer.
The renderer never infers these spelling operations from rule labels.
Three-part graphs explicitly record intermediate nodes and their exact outputs.

## Data and runtime boundary

`data/vocabulary/morphology/index.json` records the revision, normalized
inventory fingerprint, source registry and per-age counts. The ten
`age-XX.json` files enumerate every original identity exactly once. Identity is
the exact tuple of ID, text, minimum age, part of speech and meaning. Missing
meaning is equivalent to the original empty string. Original spelling and case
are preserved, including the stored lowercase i and calendar names.

`GrowthMorphology.decorate(word)` returns an isolated deep copy:

- `morphology_status` is reviewed, pending or invalid.
- `morphology_notice` explains pending or invalid states in English.
- `morphology` exists only after the separate review and graph validate.

The loader discards any candidate-supplied analysis first. A missing entry is
pending; identity mismatch, missing source evidence or a malformed graph is
invalid. The index loads once and cohort files load on demand through bounded,
fixed paths. Returned data cannot modify the cached review records.

The shared learning resolver decorates Growth Word Jelly candidates before
filtering. Pending or invalid candidates cannot fall back to spelling chunks.
Other games and the Word Library retain the original record and behavior.
The Web export filter includes the complete morphology JSON directory.

## Audit and release checks

The generated index is the authority for the current reviewed/pending counts.
Use the following commands after any editorial change:

```text
node tools/author-growth-morphology.cjs
node tools/validate-growth-morphology.cjs
node --test tests/growth-morphology.test.cjs
node tools/run-godot.cjs --headless --path . --script res://tests/godot/growth_morphology_tests.gd
node tools/validate-growth-morphology.cjs --release
```

The normal audit permits honestly pending entries while checking full inventory
coverage, age counts, unchanged senses, source records, canonical identities,
bounded graphs, exact outputs, ordered adjacency, acyclicity and reachability.
The release audit additionally requires all 1,550 individual reviews to be
complete. Passing the normal audit alone never means the migration is finished.

Native tests decorate all 1,550 real records and check every original field for
preservation. They compile every reviewed graph and ensure pending records have
no invented graph. Mutation tests exercise changed senses, missing review
evidence, candidate-injected morphology, cyclic or reordered joins and cache
isolation. Composition examples also check exact irregular output and the
non-mastery behavior of atomic exposure.

The nine resolved entries are checked through the real content resolver, with
the original image requirements and contextual content preserved. Synthetic
withdrawals still remove playable graphs, and the strict release check rejects
even one newly pending review. Full review coverage does not disable quarantine.
