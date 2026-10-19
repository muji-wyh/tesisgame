# Root-executed R22 binding and guarded integration

Work only in Q:/.codex/worktrees/current-age-vocabulary/tesisgame. This frozen package supplies executable binder, content integrator and test updater scripts. It contains no bound preimages, binding receipt or transaction. Root reviews and executes these scripts; the author has performed only scratch preparation and read-only checks. Prior delivery builders must never be replayed.

## 1. Verify the frozen unbound proposal

Pin the preparation receipt, delivery proposal and artifact inventory raw SHA-256 values from the handoff. Verify every inventory entry and the root decision. Run the new read-only commands with the exact reviewed receipt/proposal hashes:

```powershell
node build/professional-english/foundation-module01-language-review/third10/delivery-r01/dry-run.cjs --preparation-sha256 EXACT_PREPARATION_RAW_SHA256 --proposal-sha256 EXACT_PROPOSAL_RAW_SHA256
node build/professional-english/foundation-module01-language-review/third10/delivery-r01/persisted-test-transforms.cjs --dry-run
```

These commands read and compare; they neither bind nor integrate. The transform command checks full post-barcode test preimages and exact frozen preview outputs. If a test input has changed, prepare a separate reviewed transform revision. Do not overwrite these previews.

## 2. Bind exact current R22 inputs

The supplied binder explicitly requires successful R22 at build/professional-english/continuation-validation-r22.json, raw SHA-256 ccc5f7777a8ec7be8838d7cb54c1386e13afcaea8d472e6dc0a9fb0759416465. It verifies no changed measured inputs or skips, successful Node/native/native-audio runs, exact log hashes, matching before/after/live registry hashes and every current measured input. Preparation checks R22 read-only; only this binder captures the integration baseline. A different validation requires a separately reviewed delivery revision.

```powershell
node build/professional-english/foundation-module01-language-review/third10/delivery-r01/bind-current-baseline.cjs --preparation-sha256 EXACT_PREPARATION_RAW_SHA256 --proposal-sha256 EXACT_PROPOSAL_RAW_SHA256 --validation-path build/professional-english/continuation-validation-r22.json --validation-sha256 ccc5f7777a8ec7be8838d7cb54c1386e13afcaea8d472e6dc0a9fb0759416465
```

The binder requires every Professional JSON path to be measured. It captures exact raw bytes and SHA-256 for the two replacement envelopes, all other measured input hashes, all planned output preimages, the frozen proposal, all delivery scripts and all retained evidence. Full parsed preservation and measured raw preimages protect the current source registry and barcode/media records. It writes only fresh preimages.json and binding-receipt.json in this delivery directory, and refuses existing bound state or transactions. Inspect the binding receipt; its preimages_raw_sha256 is the exact hash used in the following commands.

The supplied scripts use delivery-lib.cjs as a read-only proposal library: verifyEvidence, verifyPrepared and verifyScope must pass, and proposalData must equal delivery-proposal.json exactly. Calling propose with the current loaded registry returns next, envelopes and replacement_bytes; it writes nothing. The informational prospective hashes from preparation are not a substitute for fresh current binding.

## 3. Inspect the exact content plan and commit it

Run the first command as a read-only plan and inspect it before running the second:

```powershell
node build/professional-english/foundation-module01-language-review/third10/delivery-r01/integrate-reviewed.cjs --preimages-sha256 EXACT_PREIMAGES_RAW_SHA256
node build/professional-english/foundation-module01-language-review/third10/delivery-r01/integrate-reviewed.cjs --preimages-sha256 EXACT_PREIMAGES_RAW_SHA256 --integrate
```

Only these live JSON envelopes may be replaced:

1. data/professional/lexemes/foundation-module01.json: replace the nine exact full before entries with their exact after entries. Preserve order, envelope metadata and every other entry. Attendance must retain full-entry JSON SHA-256 a7699c3e58649791eaee79817f87879c2ce6b2418e729768c6f1a43c19b3594e, pending review, original references and original notes.
2. data/professional/sources.json: append only proposal.sources, exactly sixteen records in their frozen order. Require those IDs to be absent. Preserve all older sources. Require both proposal.excluded_source_ids to remain absent.

Use JSON.stringify(value, null, 2) plus a final newline for replacement bytes, matching the library. Compare every nonpatched lexeme, all old sources and every other registry section with the bound current registry. All forms, regions, morphology, media, expressions and release gates must remain exact. Re-run the candidate schema/content audit in memory and require zero errors.

The integrator creates data/professional/provenance/foundation-module01-language-third10-2026-10-16.json with the draft's reviewer, root_acceptance, author_ledger, proposal, patches, sources, held, scope, protected_context, historical_source_consultations and attendance_history_boundary preserved exactly. It adds validation identity, bound before/after registry hashes, preparation/proposal hashes, serializer/helper hashes, transaction path and retained_files. Each retained_files item has path and raw_sha256 for its installed immutable bytes. Exact replacement and output hashes are recorded in the integration receipt and guarded plan. Installation requires a committed journal; a receipt alone is not completion.

The integrator copies every durable-provenance-draft.json retained_manifest item to its exact path under docs/content-review/foundation-module01-language-third10-2026-10-16. Existing immutable destinations must be byte-identical or absent. It also retains fresh preimages.json and binding-receipt.json under the delivery-r01 history directory, alongside reviewed scripts and plan adapter. Retained attendance evidence is history only; it is never merged into the live attendance entry or source registry.

The scripts use the byte-identical prior fault-tested guarded helper and validated plan adapter identified with exact hashes in delivery-origin.json. The new content transaction is build/professional-english/transactions/foundation01-language-third10-r01. Review the exact plan before committing. No prior transaction directory, binding or integration receipt is imported. Completion verification requires exact output bytes, registry equality to the planned result, unchanged measured inputs except approved replacements, the expected Professional JSON inventory, and zero audit errors. Only a committed journal confirms completion.

For interruption recovery, the integrator reconstructs trusted before/after bytes from bound data before parsing potentially partial live JSON and supplies the exact reconstructed plan hash to recovery. Inspect the journal, then use:

```powershell
node build/professional-english/foundation-module01-language-review/third10/delivery-r01/integrate-reviewed.cjs --preimages-sha256 EXACT_PREIMAGES_RAW_SHA256 --recover
```

Recovery restores only exact originals and removes only proved-owned outputs; unexpected bytes refuse recovery. A committed journal is a no-op. A previously prepared or rolled-back attempt remains immutable; a new attempt requires a separately reviewed fresh revision. This provides interruption recovery, not multi-file atomic visibility or power-loss durability.

## 4. Inspect and apply the separate test transaction

After the content journal is committed, inspect integration-receipt.json and verify its raw SHA-256 against the committed prepared-plan entry. The updater requires that committed journal, exact installed content/provenance/history and all non-test measured inputs. It requires the two live CJS files still to equal the frozen input hashes in persisted-test-transforms.cjs, generates outputs in memory and demands exact equality to the frozen preview bytes and receipt after hashes. Run the first command as a read-only plan, inspect it, then run the second:

```powershell
node build/professional-english/foundation-module01-language-review/third10/delivery-r01/update-persisted-tests.cjs --preimages-sha256 EXACT_PREIMAGES_RAW_SHA256 --integration-receipt-sha256 EXACT_COMMITTED_INTEGRATION_RECEIPT_RAW_SHA256
node build/professional-english/foundation-module01-language-review/third10/delivery-r01/update-persisted-tests.cjs --preimages-sha256 EXACT_PREIMAGES_RAW_SHA256 --integration-receipt-sha256 EXACT_COMMITTED_INTEGRATION_RECEIPT_RAW_SHA256 --apply
```

The separate guarded transaction is build/professional-english/transactions/foundation01-language-third10-tests-r01. It replaces only tests/professional-content.test.cjs and tests/professional-retail-morphology.test.cjs and creates persisted-tests-update-receipt.json. Original test bytes and output ownership are captured for recovery using the same strict helper. Completion verifies every committed content output and every measured input, allowing only the two exact test replacements. Full-entry historical equality is preserved; no ignored-field comparison or native test source change is included.

For test recovery, inspect the journal and supply the exact transaction_plan_sha256 from the reviewed dry run or matching prepared journal:

```powershell
node build/professional-english/foundation-module01-language-review/third10/delivery-r01/update-persisted-tests.cjs --preimages-sha256 EXACT_PREIMAGES_RAW_SHA256 --integration-receipt-sha256 EXACT_COMMITTED_INTEGRATION_RECEIPT_RAW_SHA256 --transaction-plan-sha256 EXACT_REVIEWED_TEST_PLAN_SHA256 --recover
```

Run root's required Node, native morphology and native audio suites and a fresh combined validation after content and tests are committed. The current previews add five Node cases; required semantic changes are nine reviewed senses and 180 accepted memberships, with attendance still held. Confirm media counts and barcode outputs remain exact. Hand the resulting test hashes to the Retail04 third10 delivery so its previews can be composed from this state.
