# Professional delivery bundle validation

The approved resource contract limits each decoded delivery bundle to 32 MiB,
while permitting 128 MiB of resident Professional media. The original manifest
version applied 32 MiB to the entire selected module. Retail's reviewed theme
alone occupies 16,105,984 decoded bytes, leaving too little room for its complete
vocabulary pictures and recordings under that interpretation.

Manifest version 2 now supports stable, versioned resource groups. Each group
stays within 32 MiB. The flat resource inventory remains unique, fully covered,
at most 10 MiB encoded and at most 128 MiB decoded. Shared resources transfer
and allocate once, including when two groups reference them. Version 1 retains
its original whole-inventory limit. No decoder, archive or PCK mounting was added.

The content auditor, sidecar packager and runtime cache reject a reused group
identity/revision with different members. The cache registers identities only
after validation and feasible reservation, so a failed request cannot poison a
later retry. Existing active rounds and leases survive ordinary replacement
failure or cancellation. After the application clears views and audio,
`ProfessionalPlay.leave()` cancels preparation, releases pending and active
scopes, deactivates the module and trims unused resources.

## Evidence

Evidence is retained under `build/professional-english/media-bundle-review/`.

| Check | Result |
|---|---:|
| New native grouped delivery | 51 checks, 0 failures |
| Legacy native media | 54 checks, 0 failures |
| Professional Play | 10 checks, 0 failures |
| Round loader | 18 checks, 0 failures |
| Application flow | 79 checks, 0 failures |
| View teardown | 10 checks, 0 failures |
| Node/browser media, grouped delivery and packaging | 10 tests passed |
| Runner inventory and theme motion follow-up | 7 tests passed |

The native grouped test parses a real hash-verified JSON manifest, then decodes
an expanded existing-art fixture totaling 32 MiB plus 8 bytes. It checks stable
cross-course group reuse, reordered members, conflicting definitions, metadata
drift, failed pressure registration, old leased rounds, missing replacements,
stale callbacks and leaving with both active and unclaimed pending scopes.
Fixtures are test data, not curriculum artwork.

The first attempt exposed a real Godot JSON-number compatibility defect. The
schema-version check now accepts integral JSON numeric values for versions 1 and
2; the actual parsed-manifest regression covers it. Original failure evidence
remains in `attempt1/`.

The next batch passed all 222 native checks and all 10 media/browser/package
tests. The runner inventory assertion then found the pre-existing theme-motion
suite missing from the runner. It is now registered in the themes group, and
the focused runner plus motion follow-up passed 7/7. The original batch remains
in `attempt2/`; `runtime-validation.json` records unchanged input hashes for
that batch, and `runner-followup.json` records unchanged follow-up inputs.
Unrelated native suites were not repeated after this registration-only change.

An independent read-only review checked the GDScript manifest/cache/Play logic,
JavaScript validation, relevant tests and actual application teardown ordering.
It found no additional blocking defect. The settled validator also passed the
current full content suite, 126/126; its immutable registry and source hashes
are in `data/professional/provenance/hold9-basket-grouped-content-validation-2026-10-16.json`.

This delivery corrects resource accounting and lifecycle behavior. It does not
approve any additional curriculum content, artwork, recordings or theme, and
does not mark a Professional module ready. Whole-process memory and physical
device performance remain separate release checks.
