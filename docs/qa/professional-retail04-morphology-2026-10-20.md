# Retail module 04 morphology and layout evidence

The remaining 20 Retail module 04 analyses were independently reviewed and
integrated on 2026-10-20. All 50 module analyses now have reviewed graphs; the
catalog has 209 reviewed graphs among 4,050 authored lexemes. The first 30
analyses, non-morphology fields, media, domain and course gates were preserved.
The exact before/after graphs and review decisions are in the
[integration provenance](../../data/professional/provenance/retail-module04-morphology-remaining20-2026-10-20.json).

Ten additions are whole-term analyses: seam, sole, heel, sleeve, collar,
ingredient, allergen, portion, sample and accessory. Ten are composed analyses:
waistband, lining, care label, net weight, unit price, pack size, multipack,
refill, demonstration model and spare part. Whole-term recognition remains
exposure, rather than an invented decomposition exercise.

## Recorded checks

These results describe the retained runs below, before the combined final
regression refresh. A later run must receive its own output path and result.

| Check | Recorded result | Local evidence |
| --- | --- | --- |
| Installed-graph native tests | 272 checks, 0 failures | [Native log](../../build/professional-english/continuation-20261020/retail04-native-r01.log) |
| Real-renderer layout harness | 318 checks, 0 failures, 21 captures | [Report](../../build/professional-english/retail04-morphology-20261020/render/report.json), [log](../../build/professional-english/continuation-20261020/retail04-render-r01.log) |
| Individual original PNG review | All 21 opened at original detail; accepted for the stated static layout scope | [Visual review with hashes](../../build/professional-english/retail04-morphology-20261020/visual-review.json) |
| Content assertions in the combined Node command | 159 passed, 0 failed | [Combined command log](../../build/professional-english/continuation-20261020/retail04-node-r02.log) |
| Whole combined Node command | 163 tests: 162 passed, 1 failed; **not an all-pass command** | Same log; failure concerned the omitted Foundation02 runner registration |

The runner registration was subsequently corrected. The final refresh passed
all 235 tests across the content, card-reader, Retail media, Retail morphology
and Foundation02 suites; its [retained receipt](professional-card-reader-r04/postintegration-node/receipt.json)
binds the original [successful log](professional-card-reader-r04/postintegration-node/history-r02.log).
A separate [focused run](../../build/professional-english/continuation-20261020/focused-node-r03.log)
passed all 12 tests for Retail04, approved audio preservation and the test runner.
The earlier failed command remains recorded above. The native tests
are [professional_retail04_morphology_tests.gd](../../tests/godot/professional_retail04_morphology_tests.gd);
the focused data checks are
[professional-retail04-morphology.test.cjs](../../tests/professional-retail04-morphology.test.cjs).

The renderer shows ingredient, lining, multipack, net weight and demonstration
model at 320 x 568, 390 x 844, 844 x 390 and 1280 x 800, plus a 180 x 220 safe
pause. Every displayed source and result label was legible without clipping or
control overlap. The minimum reported board font sizes at the four ordinary
sizes were 20, 31, 17 and 40 pixels. The authored demonstration-model boundary
wraps the result as `demonstrat` / `ion model`; the full `demonstrate` source keeps
its final e, and the intermediate `demonstration` is shown separately.

These are standalone morphology layout fixtures. The cat image and audio are
explicit fixtures, not approved media for these words. The small-window review
confirms the safe-pause text, not hosted Finish-button accessibility: the
standalone Finish control is under the cover. The record establishes no human,
specialist, physical-device, listening, complete-game or release acceptance.

## Repeating the layout capture

Use the tracked [reusable capture tool](../../tools/capture-professional-retail04.gd).
It was promoted from the consumed original harness after the recorded capture;
its execution status at that review was `not_run`. The promoted tool subsequently
passed [Godot check-only validation](../../build/professional-english/continuation-20261020/retail04-capture-check-r01.log).
The original capture was not repeated for the promotion. The original
[capture-retail04.gd](../../build/professional-english/retail04-morphology-20261020/capture-retail04.gd)
and its output remain immutable historical evidence.

Run from the repository root with a real renderer, without `--headless`:

```powershell
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --audio-driver Dummy --script res://tools/capture-professional-retail04.gd -- --output res://build/professional-english/retail04-layout-r02
```

Resolve `godot` to the configured Godot executable when it is not on `PATH`.
The output parent must already exist, and the target directory must not exist,
even if it would be empty. The tool requires exactly `--output <path>` after
`--`; accepted paths are absolute filesystem paths or `res://` paths. Choose a
fresh suffix for every attempt and retain failed runs. Never replay the
one-shot installation scripts or change consumed candidates to repeat QA.

Inspect every original PNG and retain the new `report.json`, command log, source
identities and a separately dated review. Passing geometry assertions alone
does not establish visual acceptance. The original batch's
[candidate record](../../build/professional-english/retail04-morphology-20261020/candidate-record.json),
[candidate module](../../build/professional-english/retail04-morphology-20261020/candidate-module.json)
and [root review](../../build/professional-english/retail04-morphology-20261020/root-review.json)
remain local evidence; ignored `build/` files may be absent in a clean checkout.

## Memory regression expectation correction

An isolated probe using the exact `scripts/game_ui.gd` from baseline commit
`0dc584b0` reproduced three stale expectations in the Memory scene suite before
the new palette invalidation: a same-lesson reset changed Ocean to Growth's
Spring theme, and Voice Pop and Phrase Builder cleared the shared Match lesson.
See the retained [observations](../../build/professional-english/continuation-20261020/memory-baseline/observations.json)
and [probe log](../../build/professional-english/continuation-20261020/memory-baseline/probe.log).

The narrow [test correction](../../tests/godot/memory_scene_tests.gd) retains the
same-lesson Memory checks and all earlier earned Ocean reward checks. It derives
the new round's reward theme from the Growth catalog profile and explicitly
checks that the previous Ocean piece, exact coin receipts and balance survive.
Match and Memory continue to require their paired-card lesson; Voice Pop and
Phrase Builder require cleared Match data and populated mode-owned content.
Four assertions were added. The correction does not change runtime behavior.
The [corrected native rerun](../../build/professional-english/continuation-20261020/memory_scene_tests-r02.log)
passed 231 assertions with zero failures. The separate
[theme-art regression](../../build/professional-english/continuation-20261020/learning_theme_art_tests-r01.log)
passed 26 checks with zero failures.
