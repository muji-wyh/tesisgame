# Shopping-bag commit independent source review

Accepted for source-level use: commit.cjs at b522c987354d2e526cc9194b0dd5239b2592b07aa30f4ddd7bd16261e2c3c087 and the optional guard-probe.cjs at 606b14e55469c212d39e24e16a0bcbdf51e3c46330bc8ecf5bb23b732a11bdf7. Reviewer: Codex runtime_recovery. No concrete blocking source defect was found.

This packet approves source only. It does not approve an exact commit contract, final metadata, candidate success, dispatch, integration or persisted validation. source-review.json deliberately has a status that cannot satisfy the transaction's exact-contract review gate.

The inspection covers the full commit source, transaction helper, probe source, candidate runner, README and input template. Raw hashes and byte lengths match both proposal inventories and all 42 prepared artifacts. The preparation fixes 34 targets and exactly four replacements. The observed r03 input has 11,569 pins; no successful candidate receipt is accepted here.

The reviewed guards require exact source and target commitments, Windows-safe repository-relative paths, evidence/target separation, a complete pinned dependency union, actual successful candidate evidence, independent contract approval, a fresh one-shot attempt and an absent transaction lock/journal. Journal verification requires the trusted final-state hash, so an internally consistent rewritten chain alone cannot pass. Existing attempts or transaction state require a separate reviewed action.

The optional probe has read-only disk access and uses synthetic memory overlays for its negative cases and journal. Its 62 statically identified cases are planned coverage only. This reviewer performed no imports, syntax checks, probes, project tests, native/browser runs or transactions. Root owns those dispatches and must retain their actual outcomes.

Root still needs actual successful candidate evidence, finalized provenance/document/evidence, and a separate review binding the exact contract before commit. The committed receipt must retain false/null persisted fields; later validation belongs in a new immutable receipt. If a postcommit check or receipt write fails, the committed journal may already exist: preserve it, inspect the failure and obtain separate recovery/completion review instead of replaying the attempt.
