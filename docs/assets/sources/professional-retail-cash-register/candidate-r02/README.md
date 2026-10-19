# Cash register candidate preparation

Status: **fresh r02 source repair; production input freeze is deferred until root provides successful R26**.

r01 failed during GDScript parsing, before any rendering, because the dictionary-derived sidecar path used inferred typing. Its original source, frozen files, attempt marker, log and failure receipt are retained untouched. r02 explicitly types that path as String and converts the dictionary path with str(). Dictionary-returning and coroutine-returning locals also have explicit Dictionary types; generated model is explicitly Node3D. No source composition or UI behavior changes are intended.

Only after root sends the successful R26 receipt hash may preparation run:

```powershell
node build/professional-english/retail-term-art-review/cash-register-r04/candidate-r02/prepare-candidate.cjs --r26-validation-sha256 R26_RECEIPT_SHA256
```

The preparation checks the exact successful receipt, all three run results and their logs, unchanged measured inputs and current full registry before freezing any production hashes.

Root inspected all six successful original-source captures and authorized this candidate probe. Its source-only finding was that the keypad, large display face and lower drawer/handle remain clear. Root preferred `positive-z-right-low.png`, with the high-right view only a secondary alternative. This authorization is recorded in `root-source-review.json`; it is neither picture acceptance nor production approval.

The chosen sense is the machine used to record sales and handle payments. The exact current entry, definition, example, brief, media states and separate gates are frozen in `entry-preimage.json`. The original brief requires one complete register in a dedicated three-quarter view, with display, physical keys and drawer base visible, filling the frame. A detached cash drawer, handheld scanner and isolated card reader are excluded. The already integrated Ava recording remains unchanged and is not played.

The harness retains the complete acquired Tiny Treats model, original handle transform and original atlas material. It uses the precise low-right camera, model centering and light settings from the successful source inspection, with a transparent background. It crops to alpha bounds plus 16 pixels of margin, then resizes to 512 pixels wide while retaining the aspect ratio. No display digits, geometry, keys, drawer movement or other component is authored. Both source display faces remain blank/dark. The acquired source has no animation or skin data.

The resulting PNG is copied byte-for-byte into a content-addressed **scratch fixture**. The unmodified production Loader reads this raw fixture with no fetch callback; the real Manifest decoder, cache lease, Access, WordArt and WordCard handle it. There is no direct assignment to `card.picture.texture`. The native probe checks decoded RGBA equality with the source render, exact Match 126 x 72 / Memory 144 x 74 cards and their 102 x 52 / 120 x 54 picture insets, genuine matched badges and 0.68 alpha, and complete cache/resource/scope teardown. It also checks that all Retail modules remain draft and all six actual module03 routes still reject incomplete content.

Four native card crops, a native contact sheet and a nearest-neighbor 3x review aid are emitted. `make-review-aids.py` assembles unchanged historical accepted cart/basket crops alongside the new crops and crops selected source-image cue regions for review. It does not render or alter the candidate. Cue bounds are observation guides from the inspected 768 x 768 low-right source capture, not semantic acceptance tests.

Root must visually inspect the entire silhouette, front display, raised key bank and drawer front/handle in every unmatched/matched minimum crop. Receipt detail is secondary. Source-view clarity and passing mechanical checks do not establish minimum-card recognition. Explicit cue-visibility fields remain `pending_root_visual_review`; no acceptance gate is set.

The prepared native command is:

```powershell
node build/professional-english/retail-term-art-review/cash-register-r04/candidate-r02/run-candidate.cjs --root-granted-native-slot cash-register-r04-candidate-r02 --frozen-inputs-sha256 FROZEN_INPUTS_SHA256
```

Use the exact frozen-input hash from the handoff. Root owns native execution. The runner refuses an existing attempt marker or output directory, freezes and rechecks production/shared-test/source dependencies, and retains logs and receipts even on failure. Every failed attempt must be kept; create a fresh revision instead of replaying this runner. `prepare-candidate.cjs` is likewise one-shot. No production, shared-test or curriculum edits are authorized by this package.
