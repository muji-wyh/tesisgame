# Professional domain package verification r01

The stage-one release tooling is implemented and frozen for the application Web build. This evidence covers Node-only source capture, compilation, independent package reconstruction, application pin installation, rollback, and stale-authority rejection. The actual application build is owned by the parent task and has separate evidence.

## Production scope

- Nine production modules in `tools/professional-domain/` implement a bounded strict JSON codec, fixed release contracts, source reconstruction, unchanged content/media gates, exact-byte snapshots, compilation, independent auditing, and guarded installation.
- `data/professional/domain-policy/decisions.json` explicitly contains no decisions. This release does not authorize any lexical or expression exception, reviewer acceptance, or real module promotion.
- Source snapshots capture the complete governed Professional graph plus referenced supporting schemas, themes, media and audio resources. Generated output is excluded. The existing `auditProfessionalContent` gates remain in force.
- The compiler emits every index row and emits payloads only for ready modules. Raw themes and selected media manifests retain their exact source bytes. The independent auditor rebuilds the expected source graph and output without importing the compiler or its input model.
- The initial real source state contains 200 unavailable modules and zero ready modules. Its generated members are only `index.json`, `release.json`, and `themes.json`; there are no production module payloads or accepted IDs.
- Installation binds the audited release descriptor to the fixed application pin `scripts/professional_domain_release.gd`. Previous generated output and pin are preserved in the fresh work directory. An injected installation failure restores their exact bytes and retains the failed generation.

## Integration API

`require('./tools/professional-domain/package.cjs')` exports synchronous `prepareRelease({rootDir, workDir})` and `verifyPreparedRelease({rootDir, report})`.

The work directory must be a fresh, nonexistent child of the project's `build` directory, with its parent already present. Preparation retains the source snapshot, compile/audit reports, prepared and installed reports, previous generation, and failure artifacts. Verification requires the retained source snapshot, compares current source and contract inventories, independently reconstructs the installed package, regenerates the report and pin, and repeats the source/contract checks. Missing evidence fails closed.

The fixed pin exports `SCHEMA_VERSION`, `POLICY_VERSION`, `CONTEXT_BOUNDARY`, `DESCRIPTOR_PATH`, `DESCRIPTOR_BYTES`, `DESCRIPTOR_SHA256`, and `GENERATED_ROOT`. The descriptor and report use policy `ordinary-lexical-v3`, context boundary `containing-modules-v1`, and trust status `application_build_audited`. This trust status does not mean reviewer acceptance.

## Separate observed runs

| Run | Command | Observed result |
| --- | --- | --- |
| Initial focused run | `node --test tests/professional-domain-release.test.cjs` | Exit 1; 22 reported tests, 20 passed, 2 failed; 280351.6004 ms. |
| Affected package supplement | `node --test --test-name-pattern '^Professional domain package installation' tests/professional-domain-release.test.cjs` | Exit 0; 1 test passed, 0 failed; 379034.8873 ms. |

The initial run has one failed leaf case and its enclosing parent-test failure. Its package-case setup attempted to create an already copied `scripts` directory and raised `EEXIST` before `prepareRelease` ran. The original test, failed log, and receipt are preserved byte-for-byte. The correction only made the test setup directory creation recursive, separated that package case into a top-level test, and added independent final source/contract guards. No production implementation changed. The focused supplement exercised that corrected package case only; this record does not present a fictional clean full-suite rerun.

The initial run's 20 passing cases include complete current-source compilation/audit; output freshness; nonempty decisions, orphan/missing sources, and duplicate membership rejection; unchanged readiness/media gates; mutated, missing, or extra generated output; hash-rebound unavailable status and invented selected policy rejection; compiler/auditor drift detection; a copied synthetic ready fixture; missing ready media rejection; and strict codec boundaries.

The package supplement confirms initial installation and independent verification, exact fixed pin bytes, work-directory reuse rejection, second-generation preservation, injected pin-install rollback, source drift before installation, caller-added acceptance rejection, changed-pin rejection, and nonempty-decisions rejection with the prior package retained.

The ready fixture is explicitly synthetic and isolated in scratch. It reuses genuine media bytes only to exercise structural gates; it is not production content, a human review, a specialist approval, or a claim of appropriate artwork or speech. It exercised one ready module, 50 lexical domain rows, 10 expression domain rows, and a five-file cold closure under the two-MiB limit. All real modules remain unavailable.

## Stability and handoff

Both completed runs verified that all 407 captured real source/support files and the production contract inventory were unchanged:

- Full source/support inventory SHA-256: `99c90edda341f88b6b6ce63b80b8f2dc170f7eb6cdf918d8d844c4296c46f2a4`.
- Production contract inventory SHA-256: `1349a42c807b10260e5456af0df8419f7ff363435ed295d3c19c5e5acfee3b45`.

At the pass/freeze handoff, the real generated directory and fixed pin were absent, the supplement process had exited, and no matching test Node processes remained. This task did not run native Godot, prepare a real application package, export Web, deploy, or claim runtime/performance acceptance. The parent task owns the first real package generation inside its actual Web build. Production tools and the shared test are frozen; subsequent work in this handoff is documentation only.

A separate read-only inspection by the independent-auditor author found no concrete unaddressed blocker in compiler artifacts/closures, package preservation/rollback, independent verification binding, or build handoff. That inspection is not an additional execution result.

## Retained evidence

`handoff-manifest.json` lists exact hashes for production files and every copied evidence file. The complete attempt trees remain under:

- `build/professional-english/domain-application-release-r01/node-attempt-c5qvIC/`
- `build/professional-english/domain-application-release-r01/package-attempt-hvBH6O/`

The durable directory contains the original failed log/receipt and test preimage, the separate passing supplement log/receipt, both source captures and final stability proofs, and a frozen copy of the corrected shared test. Original raw artifacts have not been removed or relabeled.
