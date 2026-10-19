# Fifth10 memory-guard source review r01

Status: **changes requested for precise first-assertion coverage**. Guard execution acceptance is withheld.

This review covers the separate guard proposal authored by `/root/runtime_recovery`, pinned by source inventory `ae29e404eceb8523bd7d4bb4fe26f3dbd8ff3b66d5d0ce585eebd40b84bf8b90` and guard source `bf2d06df37109966ed2d08226c047fac3f6ff385334531a41c5526cb1838a8bd`.

Reviewer `/root/recover_delivery` authored the helper and frozen preparation. Independence is limited to the separately authored guard source. Root and `/root/morph_review` retain actual-binding and preparation acceptance. `/root/recover_delivery/guard_assertion_review` corroborated assertion attribution and relinking by raw source inspection without execution or writes.

## Findings

- **F01 / P2:** The guard checks the line of the first binding stack frame and discards its column. The binding-path and binding-bytes variants name the source-inventory assertion, but alter the next actual-binding assertion on the same line. The persisted-state variant names a path assertion while changing the hash checked by the next assertion on that line. These invalid semantic conditions still appear to reject; the defect is that the guard records the wrong named first assertion and overstates its precision.
- **F02 / P3:** The reviewer mismatch case uses a fixed valid alternate identity. If that identity is already the real reviewer, the case creates no mismatch and stops the guard as unexpectedly accepted. This conditional issue is not a false pass and is not asserted to affect the intended `/root/morph_review` input.

Use a fresh guard revision to select the correct assertion markers, verify statement-level first-frame attribution, and choose a guaranteed-distinct reviewer identity. Preserve frozen guard r01 and preparation r03.

## Scope and evidence

The review inspected raw source, JSON, byte lengths, and SHA-256 hashes. All 35 unique frozen inputs matched their pins and were rechecked unchanged. The source exposes cached reads to the exact frozen binding in a VM; actual-only prerequisites, source acceptance separation, in-memory fixture rebinding, original rechecks, and one-shot output controls are present. Static tracing did not identify a deterministic earlier-assertion blocker in the commit/state/prepared relinking or journal-copy cases.

No source module was imported, parsed as executable code, syntax checked, or executed. No VM, guard case, preparation, project code, test, native command, transaction, or production write was run. The planned 53-case coverage is a source observation, not a test result. This review does not select an actual binding or grant preparation acceptance.

`review.json` contains the decision and exact finding locations. `inspection.json` records assertion fragments and their columns. `inputs.json` pins the reviewed inputs; `original-recheck.json` records their final equality. `inventory.json` pins these review artifacts and excludes itself.
