# Fixed synthetic package rejection supplement

This scratch continuation adds negative-path execution for the asynchronous owner from `runtime-continuation-2026-10-17-r01/attempts/attempt-002`. No owner logic, production code, curriculum review, real media or deployment was changed.

## Results and retained failure

The original [attempt-001 receipt](attempts/attempt-001/validation-receipt.json) remains **failed: 214 checks, one failure**, in 5,096 ms. All 147 frozen inputs and five intentional file absences stayed unchanged. The 22 package-negative cases passed all 176 assertions, and the valid-owner/invalid-replacement lifecycle assertions passed. The sole failure was an optional-message assertion for an unavailable-mode request: the harness called `String.contains("")` when that case intentionally had no expected error-text fragment. Its adjacent actual `mode_unavailable`, no-token, no-new-publication and unchanged-owner-I/O checks passed.

The fresh [affected supplement receipt](supplement-r01/attempts/attempt-001/validation-receipt.json) passed **28/28 checks** in 1,580 ms, with all 52 frozen inputs unchanged. It directly observed that Godot's empty-substring predicate returns false, corrected the optional-message expectation, and reran only the five invalid replacement selections plus recovery. It records actual returned error codes/text and owner diagnostics. No package-negative suite was rerun. The original 214-check run must not be relabelled as passing or combined into a fictional single passing run.

Both executions used Godot 4.7 stable, one native process each, in separately granted serialized execution windows. All logs, reports, preparations and input inventories remain unchanged. No further native execution is needed for this stated supplement scope.

## Exact implementation and fixtures

The canonical owner is the exact previously executed `candidate_owner.gd`, SHA-256 `5ca565b95bad3702c4592acb0b6c34a3c786abd1bba20b66bd1951e5f0a93a50`. Each test owner differs only in three fixed resource-path literals naming its immutable synthetic fixture. Preparation reverses those literal substitutions and asserts byte identity with the canonical owner. The runtime API accepts no caller-selected path or trusted pin.

The full attempt contains 126 project files, including eight exact current production scripts, the unchanged fixture catalog adapter, one valid fixture and 22 negative fixtures. It copies the retained independently audited r03 synthetic data; deliberate test mutations and synthetic hash rebinding occur only in this new scratch directory. The supplement contains only 19 project files needed for the valid fixture and affected request cases. Both runs guard the exact current production-script commitments. No image or audio media file was copied.

The package cases cover:

- Missing descriptor, index, theme snapshot, payload and media manifest.
- Nonobject or unsupported descriptor and an unexpected caller-like index path.
- Same-length raw corruption of index, themes and payload, rejected before their native decode phases; exact index/payload length mismatch.
- Unsupported policy, duplicate index identity, unsafe payload path and duplicate theme identity after explicit synthetic rebinding.
- Wrong selected identity, missing membership, an attempted non-null exception and coarse-required domain-review relaxation after explicit synthetic rebinding.
- Missing/corrupt media manifest rejection through the unchanged actual catalog/manifest parser, without media fetch or decoding.

Each package case checks its expected error family, no exposed token, no new module-cache entry or publication, no active job/open file, refusal before its specified later phase and exactly one terminal error transition.

Same-process lifecycle checks first prepare valid A, retire it before constructing invalid B, and verify that B cannot consume A's token, copied content, caller descriptor or accepted IDs. Retry and reconfiguration of B still fail on its fixed bad package; a separate valid C recovers without reviving A. Previously returned A content remains independent copied data; no claimed media lease or full game behavior is established by that check.

The affected request supplement starts from a valid cached selection, then replaces it with malformed, draft, foreign-course, wrong-revision and unavailable-mode requests. Every replacement immediately revokes the old token, rejects with its recorded code, retains only immutable data without new authority, and adds no owner file I/O. A following valid request succeeds. The observed codes are `invalid_fixture`, `content_pending`, `content_pending`, `invalid_fixture` and `mode_unavailable`, respectively.

## Evidence hashes

| Artifact | SHA-256 |
| --- | --- |
| Original failed receipt | `311bbf2bec145a18f0819bfa6c1aeac949e0828793e42d10a90f0c3315943f02` |
| Original report | `73ea73e87278b6a90ca991cb8cdc0b32160790c32a094b74a354805fa02ec93a` |
| Original log | `619e1ccd85c3094461dfb5cb7efe61a65fd3c60e558a60aea34d15ded86cc484` |
| Affected passing receipt | `f37d37f8537b428f80f2f3a6520434590e352222d8cf3f9881eb819c84b2835b` |
| Affected report | `6973508a54af4f04ae9c1c3ee08f59adc4442581382dff07d30be5c944f8f082` |
| Affected log | `498d6e1ec3fd27d775721f3538139e7f809cb2d285b5fa008647667b4a6df8ab` |

## Remaining scope

These are fixed **synthetic** descriptor tests, not proof of an application trust anchor. Fresh complete-source compiler/auditor binding, the app-owned descriptor, exact exported PCK inventory, actual round-loader/ProfessionalPlay/store/view/media lifecycle, complete decoder parity, real single-thread Web behavior, measured memory and cold/warm latency still require their own implementation/evidence. Test durations are not performance acceptance. The owner still uses indivisible native decode/validation/resolution/copy operations inside a between-step scheduling budget.

All real modules remain governed by their unchanged separate review and readiness gates. No production domain policy was installed. Root owns any durable QA note and checkpoint update.
