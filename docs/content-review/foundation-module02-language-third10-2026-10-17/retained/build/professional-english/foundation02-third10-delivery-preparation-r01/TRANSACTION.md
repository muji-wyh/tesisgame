# Root-owned execution and transaction contract

This proposal stops before execution. The commands below are future commands, not reported results. Root must serialize dispatch against native/build/test work and verify the active writer map first.

## Prepare a reviewable candidate

Use the Q: worktree with PowerShell `login: false`. Record the exact command, timestamps, exit code or exception, stdout/stderr log hashes and author-source hashes in a new root witness outside `execution-r01/`. Do not rerun an existing attempt.

```text
node --check build/professional-english/foundation02-third10-delivery-preparation-r01/projection.cjs
node --check build/professional-english/foundation02-third10-delivery-preparation-r01/test-transforms.cjs
node --check build/professional-english/foundation02-third10-delivery-preparation-r01/prepare.cjs
node build/professional-english/foundation02-third10-delivery-preparation-r01/prepare.cjs --root-dispatch confirmed-by-root
```

The fourth command has a single-use `execution-r01/` directory guard. Its output must contain exact production/test before/after bytes, the proposed provenance content, projection checks, fresh input measurement, preparation receipt and execution end record. The preparation receipt is not a native or full combined validation receipt. The native afterimage still requires parse/execution evidence in a scratch project or after a reviewed transaction; do not replace the production native suite just to parse it.

Independent technical review must cover the frozen executed sources, input pins, every prepared output, source/start/end witness equality, root command outcome, all callback results, source-level limitations, strict reversal drift rejection, every held entry and unchanged nonlanguage field. Review must distinguish the already accepted language fields from the newly proposed metadata. A new technical acceptance must reference exact hashes, not a mutable directory name.

The independent review should exercise exact `before` and `after` states, corrupted changes to each permitted and protected field, source suffix drift, missing/duplicated identities, input drift, overlapping or pre-existing destinations, forged/missing receipts and the one-shot transaction guard. The current proposal contains positive/adversarial language tests but has not exercised delivery guards because no commit entrypoint is authored yet.

R33's complete input list no longer matches current runtime inputs. Its successful result stays historical. Before committing, root must either execute a fresh scoped current baseline or obtain an independently reviewed exact dependency-transfer record establishing which unchanged passing evidence applies. Do not label a source snapshot or an in-memory projected callback run as a new whole-repository baseline.

## Fresh guarded commit

Use the existing validated helper by import, never by rerunning an old serializer:

```text
build/professional-english/foundation-module01-language-review/fifth10/delivery-r01/guarded-transaction.cjs
```

Its raw SHA256 is `1a86c7a664a8477a5eab08d3af13dc91169799bbb433498ebb279d541962eaa6`. The separately retained helper validation receipt is pinned in `input-pins.json`. Author a new commit entrypoint in a new reviewed revision; do not copy and execute the committed second-ten entrypoint.

The commit entrypoint must require root's exclusive mutation-window token, exact preparation binding hash, independent technical review path/hash and current validation/transfer path/hash. Validate their content, successful execution status and every referenced hash. Recompute the proposal and compare every exact prepared afterimage before describing the transaction. Verify all pinned inputs again immediately before commit.

Transaction destination, required absent:

```text
build/professional-english/transactions/foundation02-third10-language-r01
```

The only production replacements are:

```text
data/professional/lexemes/foundation-module02.json
data/professional/sources.json
tests/professional-content.test.cjs
tests/professional-retail-morphology.test.cjs
tests/godot/professional_retail_morphology_tests.gd
```

The only new durable output families are:

```text
data/professional/provenance/foundation-module02-language-third10-2026-10-17.json
docs/content-review/foundation-module02-language-third10-2026-10-17/
```

Construct the exact helper allowlist from individual artifact paths. Never authorize a recursive directory replacement. Each replacement needs its exact before bytes; every new file needs `before: null` and an absence guard. Reject duplicate normalized paths and enforce the resolved Q: root for every destination.

The provenance record must preserve all prepared patches, held entries, source observations, independent-review limitations and protected contexts. Add the actual accepted baseline/transfer, binding and review lineage. Set `status: integrated_language_outputs_require_committed_journal` only as the transaction's proposed afterimage; do not claim completion until the journal is committed. Retain all code, source-start/end witnesses, actual command outcome, exact test preimages/afterimages and independent technical evidence under the new durable review directory, with a hash inventory. Never overwrite author research or prior independent reviews to change their statuses.

Before commit, write a separate transaction intent containing the helper's `describePlan()` result and hash. Commit once with `commitTransaction()`. Its verification callback must compare the complete loaded registry to the prepared `next` value, every changed artifact to its afterimage and every unrelated bound input to its preimage hash. Write the commit receipt only after `committed: true` and a committed journal state. Preserve and inspect any failure state; do not retry the same transaction directory.

A new persisted test must bind the actual source-start/end witnesses, preparation output, validation/transfer evidence, independent technical review, retained copies, transaction intent and committed journal. That test cannot truthfully pass in the pre-commit projection; retain its explicit future-execution distinction. This final transaction-evidence test and the commit entrypoint are intentionally still outstanding.

## Persisted verification after commit

Use a new root witness, with command/log hashes and all before/after input hashes, for the following affected checks. Do not replay R33 or any old witness:

```text
node tools/validate-professional-content.cjs --json
node --test tests/professional-content.test.cjs tests/professional-retail-morphology.test.cjs
node tools/run-godot.cjs --headless --path . --script res://tests/godot/professional_retail_morphology_tests.gd
```

The audit must remain at zero errors and zero ready modules. Preserve any failing execution exactly; a later affected supplement is separate evidence. The twelve approved recordings and other media should remain byte-identical because this transaction cannot touch their lexemes/assets or historical acceptance. Run further audio/native/runtime checks only if the final dependency analysis identifies an affected input or a required acceptance gap.

After persisted checks, copy evidence durably and update the central checkpoint with actual delivered counts and evidence. Do not mark any complete curriculum, theme, professional media, specialist or human acceptance from this language-only transaction.
