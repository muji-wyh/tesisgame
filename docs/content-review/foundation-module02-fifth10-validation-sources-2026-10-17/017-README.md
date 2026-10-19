# Fifth10 projected-validator source review r02

Status: **accepted at source-review level, pending actual afterimage and concrete-input acceptance**.

The revision resolves r01/F01. Its `cpSync` override accepts the retained fixture's exact schema source and `{recursive:true}` option. It checks each temporary destination, rejects visited source links, and reads every copied file through the pinned overlay. The current schema tree has eight regular JSON files. The source differs from r01 only by the 15-line helper and its override.

The shared local-module overlay, artifact and target checks, expected 197/40/26 callbacks, temporary-root restrictions, and postchecks remain unchanged. This is trusted-code instrumentation: destination containment remains lexical and the host context remains available. The reviewed fixture creates a fresh temporary root and no links; this review does not claim hostile-code or injected-link isolation.

Reviewer `/root/recover_delivery` authored the helper and preparation but did not author this separately root-authored validator. Independence is limited to the validator source. Root and `/root/morph_review` retain actual-binding and preparation acceptance. `/root/recover_delivery/guard_assertion_review` corroborated the correction by source inspection.

All 31 input pins and the eight-entry schema directory listing were rechecked unchanged. No source import, executable parsing, syntax check, VM execution, callback, test, native command or production write occurred. No actual preparation input or afterimage was inspected or accepted. Root must separately obtain the actual afterimage review and freeze a complete, conflict-checked concrete input before considering one dispatch.

`review.json` records the scoped decision. `inspection.json` records the exact source delta and copy behavior. `inputs.json` pins the reviewed inputs and schema listing. `inventory.json` pins this review and excludes itself.
