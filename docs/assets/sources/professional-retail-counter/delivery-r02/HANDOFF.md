# Transactional counter image delivery

This revision replaces the delivery approach in frozen `delivery-r01`; v1 is preserved unchanged. Its partial-write risks are recorded in `v1-risk-review.json`. The image, source records, native crops and independent root acceptance are unchanged. No baseline has been bound and no production integration or native rendering has been performed by this preparation.

Root acceptance remains `../root-image-review.json`, SHA256 `ea82b3f6d34b192268bda35332f749870d18608201e22a87e41a5288739bec88`. The author receipt remains SHA256 `c06028630c91070f11d42a3eb57349b294b9d9331f0881faf31fc6c00bce7fd0`. The selected PNG remains SHA256 `c73f0a77c42d84a6dbf3d4d2036398a792511d1a1e4e139aad65f7a492aebe7a`.

The locally retained `guarded-transaction.cjs` is an exact copy of the reviewed shared helper identified in `helper-origin.json`. The production transaction directory is `build/professional-english/transactions/counter-image-delivery-r02`. Its central parent supplies the cooperative lock used by the fifth10 adapter too. This is a journaled multi-file transaction; the committed journal determines completion. The helper covers process interruption and guarded rollback; it does not claim multi-file atomic visibility or power-loss durability.

The transaction stages exact new bytes and raw preimages, persists its prepared journal, and then installs the exact allowed paths. All copied evidence, the PNG, the single registry replacement, provenance and integration receipt participate in the same guarded operation. A thrown write or verification error rolls back owned changes. Existing identical immutable evidence and media are included as no-ops, so rollback preserves them. Existing differing bytes, unexpected path membership or changed preimages cause rejection. Existing directories are not deleted during rollback.

Before binding, root must integrate fifth10 and confirm an exact successful combined validation on that resulting registry. No validation revision is preselected. The binder checks successful Node, native and native-audio runs, their retained log hashes, complete unchanged measured inputs and registry equality to completed fifth10. It also freezes every Professional JSON hash, the exact counter entry, all delivery files, the frozen v1 preparation, helper origin, exact output paths and each output's preexisting hash or absence. No later test or data drift is exempted.

```powershell
node build/professional-english/retail-term-art-review/counter-r01/delivery-r02/bind-current-baseline.cjs --root-approval-sha256 ea82b3f6d34b192268bda35332f749870d18608201e22a87e41a5288739bec88 --validation-path build/professional-english/continuation-validation-rNN.json --validation-sha256 REPLACE_WITH_EXACT_VALIDATION_SHA256
```

Replace the validation placeholders with root-confirmed values. Binding writes only new scratch `preimages.json` and `binding-receipt.json`. Review them, then use their exact reported preimages hash for a read-only dry run:

```powershell
node build/professional-english/retail-term-art-review/counter-r01/delivery-r02/integrate-reviewed.cjs --preimages-sha256 REPLACE_WITH_EXACT_PREIMAGES_SHA256
```

Only root should add `--integrate` after reviewing the plan. The final verification callback checks every installed byte, the whole proposed registry, the full content audit, exact Professional JSON membership and every unrelated validated input before the helper marks the journal committed. Any callback failure rolls back the raw preimages and removes transaction-owned new files. The integration receipt is one of those guarded outputs; its `integrated` field is valid only with the committed transaction journal.

An interrupted process may leave the prepared/applying journal and partially installed bytes. Do not rerun integration or infer completion from a copied image or receipt. After inspecting the journal, root may explicitly request rollback:

```powershell
node build/professional-english/retail-term-art-review/counter-r01/delivery-r02/integrate-reviewed.cjs --preimages-sha256 REPLACE_WITH_EXACT_PREIMAGES_SHA256 --recover
```

Recovery verifies the pinned immutable inputs and exact allowed paths, then reconstructs the expected plan hash from the bound raw target preimage, exact outputs and audit summary before it touches a possibly incomplete registry. It invokes guarded raw rollback first, then checks the complete restored baseline. An interruption before preparation is confirmed as having made no target mutation. A committed transaction is reported as a no-op and cannot be rolled back through this option. Transaction history is retained; a later integration attempt needs a fresh reviewed attempt/revision rather than overwriting the journal.

The only semantic registry edits remain the exact counter image descriptor and one obsolete picture clause. The descriptor credits Kenney Furniture Kit 2.1 and Car Kit 3.1, both CC0 1.0, with static original models and documented whole-model composition. Current audio, morphology, language/domain state and all other registry fields remain exact. No service-function counter variant is accepted by this delivery.

Shared tests, runtime code and top-level documentation remain root-owned. `update-persisted-tests.cjs` is a proposed updater: it captures no current test hashes, and instead requires the later image binding's exact post-fifth validation hashes plus an exact completed image integration receipt. Its default run reports changes without writing. Adding `--apply` uses a separate transaction under the same central lock to update three Node test files; native morphology tests stay unchanged. The two required hash options are `--preimages-sha256` and `--integration-receipt-sha256`. Its dry run reports `transaction_plan_sha256`; explicit interrupted recovery additionally requires that exact hash via `--recover --transaction-plan-sha256`. The updater cannot run before successful image integration, and does not run the updated tests itself.

The proposed tests append the exact counter provenance to existing media reversal chains for first-ten and older editorial snapshots. The fifth10 protected related-entry and first-forty snapshots receive a counter-only exact reversal, preserving their later audio/image state for all other senses. Current image counts change from four to five, and a dual-source counter provenance/pixel test is added. The source document remains a scratch draft. After successful integration, root still needs actual production-loader/card verification against the four frozen crop pixel hashes, loader teardown checks, test/documentation updates and combined post-integration validation. Domain review and module-readiness gates remain unchanged.
