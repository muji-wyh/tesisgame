# Checkout source and composition preparation

This scratch revision targets `checkout.payment-area.n`: the place in a store
where purchases are paid for. It does not change production files or any review
gate.

The complete Mini Market belt-and-terminal model is suitable to investigate as
a checkout station. Its prior rejection for the separate physical-key cash
register sense is preserved in the earlier cash-register review. The intended
picture includes a green-uniformed employee, a visually distinct shopper in a
yellow top, and a carton and apple on the goods belt. The whole transaction
space is the subject. An optional four-tile floor will be compared against a
compact transparent group at actual phone card sizes.

`source-record.json` records the original acquired GLBs, textures, licenses,
pack previews, source URLs, creators and exact hashes. All six complete models
and their material dependencies are retained under `source/`. Nothing was
downloaded or integrated for this revision. The two source characters contain
32 named clips each; only the neutral static, idle-start and selected
interact-right poses are planned for native inspection. Other clips are not
approved for this picture.

`composition-decision.json` keeps the exact live meaning and image brief,
diagnosis, proposed layout and rejection criteria. Source geometry inspection
established the dark belt top at original local height 0.25. The groceries are
placed at that height rather than at the higher register counter surface.

Native execution is intentionally separated:

1. Root grants the shared native slot, then invokes the source stage:
   `node build/professional-english/retail-term-art-review/checkout-r01/run-native-probe.cjs --root-granted-native-slot checkout-r01 sources`
2. Inspect all source renders, including both characters' sampled arm poses.
   Only if they fit, create `source-pose-review.json` with
   `status: "accepted_for_composition_probe"`, the exact
   `source_inspection_report_sha256`, and `employee_pose` / `shopper_pose`
   objects containing the selected original `clip` and `seconds`.
3. After a native slot is granted for composition, invoke the same runner with
   the final argument `composition`. It produces four layout/camera probes and
   four real WordCard states per probe. It does not choose or approve an image.

The runner uses the existing `tools/run-godot.cjs::runGodot`, applying a 60-second
timeout to the actual Godot child and waiting for its exit. It hashes source
originals and retained copies and compares production content, script and media
files before/after. Output paths are exclusive; preserve failures in place and
use a new revision for another run. GDScript has not been parsed or rendered
until the corresponding native receipt says so. Node syntax checks are only
preparation checks.

Remaining uncertainty is visual: source pose usefulness, body/station clearance,
face direction, goods contact with the belt, and recognition at 102 by 52 pixels.
Native visual review is required before any candidate recommendation. Existing
Godot and the acquired local library are sufficient; no additional renderer,
asset acquisition or paid service is needed.
