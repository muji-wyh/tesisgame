# Actual baseline and dispatch contract r03

Both templates intentionally refuse execution. Final binding remains UNBOUND until actual bag commit and persisted success exist. Root must capture a separate complete binding, obtain independent acceptance of that exact binding and frozen source inventory, then prepare a separate root input. Do not alter genuine historical receipts or manufacture compatibility wrappers. Selected paths are repository-relative with forward slashes inside the Q worktree. Pins are exactly `{path, bytes, raw_sha256}`.

## Roles and independent acceptance

The preparation author is `/root/recover_delivery`; `/root/runtime_recovery` is the inherited r02 source author; the dispatcher is `/root`. The final binding has `roles: {preparation_author, inherited_preparation_author, dispatcher, independent_reviewer}` with those three exact identities and a separate canonical reviewer identity such as `/root/morph_review`.

The independent acceptance has status `accepted_for_one_root_owned_fifth10_scratch_preparation`, `preparation_execution_accepted: true`, a nonempty canonical `reviewer`, and `roles` exactly equal to the final binding's roles. The reviewer must match `roles.independent_reviewer`, use `/root/<agent_name>`, and differ from both preparation authors and the dispatcher. Missing, empty, padded, author-self, inherited-author, dispatcher and mismatched-role values are rejected. The acceptance's complete `source_inventory` and `actual_binding` pins must equal the root input's pins, including paths and byte lengths as well as hashes. An author-supplied status or hash alone cannot open the gate.

The root input has status `root_authorized_one_shot_scratch_preparation`, `dispatcher: "/root"`, `preparation_author: "/root/recover_delivery"`, the exact r03 entrypoint/output paths, `root_selected_actual_baseline: true`, `execute_project_tests: false`, and pins for `binding`, `source_inventory` and `independent_source_review`. Its exact raw hash is provided separately on the command line. The source inventory remains the frozen unbound author artifact.

## Common predecessor journal contract

`predecessors` has exactly `fourth10` and `shopping_bag`. Each has true `root_confirmed_committed` and `root_confirmed_persisted`, pinned `committed_receipt`, `committed_journal`, `prepared_journal` and `persisted_receipt`, its explicit `receipt_schema`, and `journal_copies` (normally `[]`). Mandatory journal checks cannot be replaced by caller `success_assertions`.

The selected commit names its authoritative committed-state hash, prepared-journal hash and plan hash. The source requires the selected state pin to equal that state hash, the selected prepared pin to equal the prepared hash, the state's `prepared_sha256` to match, and the freshly serialized prepared plan hash to match both the prepared journal and commit. The prepared repository root must be this Q worktree. Its complete plan entries, prepared entries, allowed paths and committed state's targets must agree exactly, including every path, before/after descriptor, byte length, hash and noop value. Case-insensitive duplicate targets are rejected. The selected state must be the latest numbered state under the actual transaction's `states` directory; this is checked again before preparation completes.

Normally the two selected journal pins use the original receipt-derived paths. A durable journal copy is allowed only with identical bytes and an explicit `journal_copies` row `{kind, source_path, target_path, bytes, raw_sha256}`. `kind` is `committed_journal` or `prepared_journal`; the source path is the original receipt-derived path, and the target is the selected pin path. The actual original must also be in the complete input pins and match byte-for-byte. The array contains exactly the copies used, in committed-then-prepared order; unused aliases are rejected.

Every actual persisted command must have exit code zero, null error and null signal. Its simple log basename is resolved beside the selected persisted receipt and rehashed. An explicit nonempty `success_assertions` array remains available for additional exact checks: `{document: "commit" | "journal" | "persisted", keys: [...], expected: ...}`. These supplement the mandatory relationships.

## Genuine fourth-ten schema

`receipt_schema` is `foundation02_fourth10_nested_result_v1`. The accepted commit and persisted hashes remain `96fff4c1ac94147e99efcb8f18ff07711a5c2e53729fa07695d7d2296ae037f8` and `f25fbeb4fa8fafe08b0431653a5a9171d8369581aed104faad3e0161bbaf40f7`.

The actual commit has `result.status`, `result.committed`, `result.transactionDir`, `result.state`, `result.preparedSha256` and `result.planSha256`. Its actual absolute paths are normalized within the Q worktree; unrelated paths are rejected. The persisted receipt uses identical `source_before` and `source_after`, links the exact selected commit receipt path/hash, and records four successful commands. Its authoritative complete manifest comes from the hash-bound prepared plan and must equal its committed journal targets. Historical fourth-ten installed files are not required to retain pre-bag test bytes: the later bag transaction legitimately replaced three test files. The immutable fourth-ten receipt/journal relationship remains exact.

## Genuine shopping-bag schema

`receipt_schema` is `shopping_bag_top_level_commit_and_persisted_input_v1`. The actual bag commit has top-level `status`, `committed`, `transaction_dir`, `state`, `prepared_sha256`, `plan_sha256` and `target_manifest`; a fabricated nested `result` is rejected. Its embedded journal summary must agree with the same plan, prepared journal, state and complete target count.

The bag persisted receipt uses `source_sha256` and `input_sha256`, `ok: true`, null `error` and `postcheck_error`, actual audit and test summaries, and two successful commands. The stage additionally pins `persisted_source` and `persisted_input`; their actual bytes must match those hashes. The persisted input has status `root_confirmed_actual_bag_commit_for_persisted_validation` and must identify the exact selected commit receipt and original committed state path/hash, complete target count, expected callback count, expected audit summary and every committed target afterimage in `expected_inputs`. The receipt must show those exact counts, zero failed/cancelled/skipped tests, zero audit errors, nine images, twelve recordings and zero ready modules. Only the actual content audit and the three affected Node-suite command arguments are accepted by this schema. A changed actual persisted schema requires a fresh reviewed source revision, not invented compatibility fields.

`installed_targets` is the exact complete set of `{path, bytes, raw_sha256}` afterimage pins derived from the authoritative `target_manifest`. It may be ordered differently, but no missing, duplicate, extra or changed row is accepted. Every installed byte is independently rehashed through the complete input map. The retail lexical file, bag provenance and all three Node suites remain explicit required targets; projection separately checks the exact accepted bag entry and PNG. The actual bag commit's registry-after hash must equal the fifth-ten binding's registry-before hash.

## Complete actual baseline and preserved content

The final binding has status `root_bound_actual_post_bag_persisted_baseline`, `bound: true`, and true `guards.production_writers_yielded`, `guards.complete_inputs_frozen` and `guards.final_destinations_reviewed`.

`registry_before_sha256`, `registry_after_sha256` and `counts: {before, after}` come from fresh complete JSON measurements. Each count includes `reviewed_status`, `reviewed_language`, `foundation02_language`, `sources`, `lexemes`, `expressions`, `images`, `audio` and `ready_modules`. This source packet selects none. The historical content anchor of 148 is still checked by the unchanged transform; an unexpected actual predecessor count requires reinspection.

`input_files` is the complete unique list of raw inputs: catalog resources, actual four test sources, old provenance and donor histories, original fifth-ten proposal/review closures and all thirty-nine evidence/history pins, all installed bag targets, predecessor receipts/logs/prepared and committed journals, bag persisted input/source, every frozen r03 inventory member, and all concrete validator/test dependencies. No directory wildcard is a substitute. Projection rejects an unpinned read. The separate final binding, independent acceptance and root input are external pins, avoiding circular hashes.

The byte-identical projection and transforms preserve eight complete accepted projections, sixteen exact appended source rows, six complete holds, fifty full donor rows and their original indices/multiplicity, and every existing Foundation/source/bag chronology boundary. The actual source prefix, complete protected fields, expressions, memberships, pending morphology and media remain exact. `CALL-GRAPH.md` preserves the accepted restoration routes. No lexical approval is created by this repair.

## Durable evidence and target closure

`retained_files` lists stable `{source, target, bytes, raw_sha256}` copies individually under `docs/content-review/foundation-module02-language-fifth10-2026-10-17/`. Required copies include complete proposal/review inventory closures, three accepted JSON copies, r03 source inventory and sources, frozen r02 rejection/lineage, and the explicitly enumerated `required_retained_sources` closure. The gate requires all predecessor commit, state, prepared and persisted pins in that closure, plus bag persisted source/input. Historical metadata is copied without rewriting nested paths.

`deferred_retained_targets` still has exactly three `{kind, target}` rows: `actual_binding`, `independent_source_review` and `root_input`. Their paths are fixed in the binding; exact bytes/hashes come from separately verified root-input pins. The command-line pin supplies the root input's own hash.

`must_remain_absent` is exactly every addition: new provenance, `DELIVERY.md`, and every stable/deferred retained destination. `target_paths` is the complete set plus six replacements: Foundation02 lexical JSON, sources JSON, three Node suites and native morphology test. No duplicate, existing addition or unused absence entry is accepted. Final counts remain unbound.

## Execution boundaries

The new entrypoint accepts `--root-input <relative-path> --root-input-sha256 <exact-hash>`. Root must retain preflight rejection evidence, including the cases in `guard-cases.json`, before actual preparation. The author has not executed those cases or any code in this packet. Rejected gates create no preparation output. After acceptance, `execution-r01` is single-use, retains failures and never overwrites artifacts. Any consumed failure requires a fresh revision.

Preparation performs only built-in byte/JSON construction after the gate. No syntax check, test callback, validator, native/build/browser run or production commit is embedded. Root separately owns source/binding review, syntax and guard checks, one preparation, projected validation with complete filesystem visibility, output review, native checks, guarded installation and fresh persisted validation. Construction-stage provenance keeps actual fifth-ten commit/persisted fields null. No human, specialist, expression, morphology, media, ready-module or release approval is provided.
