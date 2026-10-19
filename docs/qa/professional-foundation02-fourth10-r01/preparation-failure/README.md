# Fourth-ten preparation r01 failure

All three source syntax checks passed. The one-shot scratch preparation failed in the new morphology callback because it expected one historical donor snapshot and found two. Root's read-only inspection located the pair at `sign.write-name.v` in the immutable Foundation01 fifth-ten record; both entry payloads match. The other 49 entry/history groups contain one matching snapshot each.

No production file changed and no native validation ran. Root rehashed all 803 distinct pinned/context inputs after failure and compared the executed source start, end and current bytes. All remain exact. Only the content-test before/after was saved before failure; there is no complete preparation receipt or full projected-suite pass.

- [Actual failure](actual/failed-attempt.json)
- [Root command receipt](root/execution/receipt.json): `9305ef12ea2570f4f0502751b551670e1cf992601c9978251b9150100025ab07`
- [Root post-failure observation](root-observation.json)
- [Exact 22-file copy receipt](copy-receipt.json): `aa82f960a92a42f0a9f3a86437312b541931199381c54bf44ac29c2ec015052b`

Preserve this attempt. A fresh revision must check the exact expected multiplicity and all donor snapshots without changing immutable histories. Independent diagnosis and new source review remain separate from execution.
