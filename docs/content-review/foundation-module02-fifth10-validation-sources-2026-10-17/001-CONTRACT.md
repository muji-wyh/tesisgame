# Native candidate dispatch and review contract

## Existing fixed baseline

- Actual binding: `build/professional-english/foundation02-fifth10-root-binding-proposal-r02/execution-r01/actual-baseline-binding.json`, 3,187,477 bytes, SHA256 `7323bcb1baac6ea85817169bcc90325f9b54d587b19d4895ca3106ee7af0e015`.
- Preparation source directory: `build/professional-english/foundation02-fifth10-delivery-preparation-r03`.
- Frozen preparation source inventory SHA256: `2f4033d3edfeb6eacc78657e9c215ef8718bd3ceb275c94f4c6168e68d2c6ee3`.
- Reference only: `build/professional-english/foundation02-fourth10-native-candidate-r02/run.cjs`. Its output, dispatch or status is not reused as fifth-ten acceptance.

Repository-relative pins have exactly `{path, bytes, raw_sha256}`. Paths use forward slashes, stay within this Q worktree and resolve to regular files. An executable pin has the same keys but an absolute `.exe` path chosen by root. The native runner author is `/root/morph_review`; the preparation authors are `/root/recover_delivery` and inherited `/root/runtime_recovery`.

## Source acceptance

Root or another reviewer independent of the native runner author must inspect this exact frozen source inventory. The separate source acceptance requires:

- `status: "accepted_for_one_root_owned_fifth10_native_candidate"`.
- `source_execution_accepted: true`.
- `reviewer`: `/root` or a canonical `/root/<agent_name>`, different from `/root/morph_review`.
- `source_inventory`: the complete exact pin selected in the eventual root input.

This gate reviews the native runner. It does not provide approval for preparation afterimages.

## Actual preparation and independent output acceptance

The eventual root input's `preparation` object has exactly five complete pins:

| Key | Real required artifact |
|---|---|
| `receipt` | `.../foundation02-fifth10-delivery-preparation-r03/execution-r01/preparation-receipt.json` |
| `execution_end` | `.../foundation02-fifth10-delivery-preparation-r03/execution-r01/execution-end.json` |
| `target_plan` | `.../foundation02-fifth10-delivery-preparation-r03/execution-r01/target-plan.json` |
| `projection_observation` | `.../foundation02-fifth10-delivery-preparation-r03/execution-r01/projection-observation.json` |
| `root_input` | The real root preparation input named by the preparation start artifact |

The real preparation must have the r03 successful statuses, complete receipt artifact closure and exact 823-target plan. Its start, root input, binding acceptance and frozen preparation inventory must agree. A `failed-attempt.json` blocks use of that preparation. Construction-stage provenance must retain null fifth-ten commit/persisted lineage.

A separate reviewer independent of both preparation authors and the root dispatcher must inspect the actual afterimages. That acceptance requires:

- `status: "accepted_for_root_owned_fifth10_native_candidate_validation"`.
- `projected_afterimages_accepted: true` and `native_candidate_execution_accepted: true`.
- `reviewer`: a canonical `/root/<agent_name>` other than `/root/recover_delivery` or `/root/runtime_recovery`. The root dispatcher is not an output reviewer. The native runner author may review another author's preparation afterimages; the runner source still needs the separate independent source acceptance above.
- `actual_binding`: exactly equal to the root input's complete binding pin.
- `preparation`: exactly equal to its complete five-pin object, including every path and byte length.
- `preparation_source_inventory`: exactly equal to the successful preparation receipt's frozen r03 pin.

Do not assert these statuses or invent future hashes before the real outputs exist and have been independently inspected. A fresh native-specific acceptance may reference an earlier full output review while explicitly covering these exact real pins. No future output or output acceptance is selected by this source packet.

## Root dispatch input

Root writes a separate input using `root-input.template.json` as a schema reference. Required identity fields are `dispatcher: "/root"`, `proposal_author: "/root/morph_review"`, exact `entrypoint` and `output`, `execute_native: true`, `execute_project_node_tests: false`, and status `root_authorized_one_shot_fifth10_native_candidate`.

All three guards must be true: `production_writers_yielded`, `source_and_output_acceptances_complete` and `isolated_destination_reviewed`. Root selects the actual Godot executable and its raw byte pin. The source deliberately does not use PATH lookup or inherit `GODOT_BIN` as executable authority.

Root then supplies the separate exact raw hash of that input:

`node build/professional-english/foundation02-fifth10-native-candidate-proposal-r01/run.cjs --root-input <real-relative-input> --root-input-sha256 <exact-input-hash>`

Root owns any syntax checks and guard checks before that dispatch. This author has performed neither. Preflight gate rejection creates no candidate output; root retains its rejection log. Once `execution-r01` exists, it is consumed even on failure. Preserve it and make a new reviewed source revision for a retry.

## Evidence and remaining delivery

The candidate has one isolated project, a fixed configuration, all exact baseline copies and four actual accepted overlays. Both Godot runs use the same copied project. Separate stdout/stderr hashes, process status and the actual native summary are retained. `source-inputs.json` records all protected pins, and each postcheck attempts every source and completed copy even after earlier failures, collecting errors rather than stopping at the first mismatch.

The final receipt only claims isolated candidate success if both child commands and all required checks succeeded. Preparation, binding and source identities are repeated literally. Production installation, complete persisted verification and all wider acceptance remain root-owned subsequent work.
