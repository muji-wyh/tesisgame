# Jelly collection callback performance

The subsequent [reward preparation and publication follow-up](2026-11-05-jelly-reward-preparation.md) records the next optimization and its separate paired measurements.

This follow-up targets game-page full-board Auto Collect after release `aa6c1223`. The physical acceptance target remains PC Chrome at 1366 x 768, 60 FPS during idle, drag, merge and collection. The available Hyper-V software adapters cannot establish that acceptance result; the user will test the deployed game on a physical PC.

## Measured cause and implementation

The fine V2 baseline captured 56 mixed-Lv pickups, all nine merged levels and nine production word identities, with normal motion and audio. It committed every pickup, skipped none and left no tiles. `JellyMatch._chest_for_theme` consumed 983.2 ms across 280 calls, principally synchronously constructing the next static chest icon at eleven tier milestones. Milestone handling consumed 1,142.7 ms inclusive. Growth snapshot queries consumed 295.9 ms across 115 calls; hidden Home hero layout consumed 64.5 ms across 112 calls.

These are inclusive diagnostic durations from instrumented methods. Nested timings overlap and must not be added as exclusive costs. The profiler adds wrapper, dispatch, lookup and recording overhead; its FPS cannot establish acceptance.

- Growth total mastery now iterates recorded streaks while retaining the same vocabulary-membership and mastery-threshold predicate. Sparse history avoids scanning all 1,550 words; dense history and lifetime mastery remain correct.
- Hidden Home keeps growth, portraits, progress, accessibility, counts and external learning controls current. Only its expensive hero styling and geometry wait until effective visibility returns. Returning Home flushes pending layout synchronously; detached initialization still lays out at a valid width. Game map presentation is unchanged.
- Jelly HUD and fragment chest icons use 28 lossless, alpha-cropped images baked from the same production Chest Control, 768-pixel render surface, acquired models, theme, lighting and shadow. Icons create no runtime 3D surfaces or image readbacks. Stable source-keyed texture references, all 99 level identities, final-material reuse and the live 3D upgrade presentation remain intact.

The images total 2,303,592 PNG bytes. Private source derivatives retain their existing ignore rules. `assets/chests/catalog/jelly-icons.json` records actual integrated sources, creators, licenses, acquisition status, source animations, crops and hashes; these are derived production portraits, not source previews. Drawing inputs and lossless import settings are checked before a production build. Checkout line ending changes are allowed for identical text; content changes invalidate the bake. The final raw startup pack must contain all 28 textures.

## Validation

Native checks passed: Growth state 969, cross-age growth 77, Growth flow 1,005, Home 714, deferred Home hero 203, library publication 10, static chest icons 557, Jelly Match view 3,151, chest celebration 7,675, tap 199, header layout 1,601, tier consumers 14 and collection learning 30. The icon suite verifies imported pixels exactly against the baked PNG, all 99 levels, source cropping, stable references and absence of icon renderers. The celebration suite retains real 3D turn and queue checks.

Two stale celebration test accesses were updated: use the current catalog API instead of the removed manifest constant, and inspect a detached renderer's active flag without asking its removed scene tree for global geometry. Assertions remain enabled and engine errors remain fatal.

Node asset validation passed five tests covering all assets, missing/changed inputs, bad crops, source identities and line ending parity. Eleven profiler safety tests cover exact signatures, multiline/default forwarding, inheritance, typed returns and copied-project isolation. Deployment, build receipt and test runner checks also passed. All repository changes were independently reviewed.

## Reproducible captures

The committed baseline source is frozen as ordinary files under ignored `build/performance/baseline-aa6c-callback`, without a Git branch or worktree. Original source models and textures remain unchanged. Candidate exports add the new static images; the baseline does not reference them. Shared engine imports and assets are not independently archived.

Fine baseline: `build/performance/jelly-fps-aa6c-callback-profile-v2-capture/collect-1.json`.

Fine candidate: `build/performance/jelly-fps-callback-candidate-profile-v2-capture/collect-1.json`.

Bare baseline: `build/performance/jelly-fps-aa6c-callback-bare-v1-capture/collect-1.json`.

All captures use headed Chrome Canary, 1366 x 768, DPR 1, eight seconds of warmup, real native mouse/button inputs, unmuted audio, normal motion, no Chrome trace, no GL wrappers and no input snapshot diagnostics. Fine captures additionally wrap the same GDScript methods for CPU diagnosis. Compare each run only with its matching instrumentation class and fixture hashes.

| Export | Copied-source SHA-256 |
| --- | --- |
| Fine baseline | `427da64b7cc8a286fa1fcd2e77cd775ec9006941ee71150069097f6da361db12` |
| Fine candidate | `d8f7b8ee61be384fe024568799022ec294f665183556edfee3a8a910d4fb7cd7` |
| Bare baseline | `e0a6cefbd1bb1d3841d7ee8523fb91594af671de32e2168ac059e8e741aae1c8` |
| Bare candidate | `7a2d3a39073056311bc9aedbb09f44186e3c66383234ee7dd3555d9bd17be1d3` |

Both fine exports use runner SHA-256 `066337ebf1e57a8d34d3e22f37a6f1cf437a6fcc5bf780deb8aba2bba061ec32`; both bare exports use `47f4a2c28a83ea45cb1db0aa29e378af53e5a97c6270f89488b22b9ccd24602a`. All four use fixture `d5b817fe53ccc5ba4a61821a5cc7168a3c0f44286959fa2bc706411d8dce009e`.

## Fine callback comparison

Chrome 159.0.8140.0 used the same SwiftShader adapter for both fine captures. Baseline sampled 83 frames and candidate sampled 89. Both started and committed all 56 pickups with zero skips and zero remaining bodies. Frame counts differ because actual frame pacing differs; method totals and per-call durations are retained separately in the artifacts.

| Inclusive method | Baseline calls / total | Candidate calls / total | Baseline / candidate per call |
| --- | ---: | ---: | ---: |
| `WordModel._complete_collection` | 56 / 1,870.2 ms | 56 / 432.8 ms | 33.396 / 7.729 ms |
| `GameUI._refresh_growth` | 56 / 419.6 ms | 56 / 62.5 ms | 7.493 / 1.116 ms |
| `GrowthState.snapshot` | 115 / 295.9 ms | 115 / 20.3 ms | 2.573 / 0.177 ms |
| `GameLibrary._layout_hero` | 112 / 64.5 ms | 112 / 0.9 ms | 0.576 / 0.008 ms |
| `JellyMatch._chest_for_theme` | 280 / 983.2 ms | 282 / 50.7 ms | 3.511 / 0.180 ms |
| `JellyMatch._chest_milestone` | 11 / 1,142.7 ms | 11 / 162.8 ms | 103.882 / 14.800 ms |
| `ChestCelebration.enqueue` | 11 / 142.4 ms | 11 / 100.3 ms | 12.945 / 9.118 ms |

The collection-completion callback decreased about 76.9% in this diagnostic pair. Hidden layout now performs only the cheap eager text projection. Live 3D reward enqueue still incurs model preparation; it remains included and was not replaced by a flat upgrade. Instrumented whole-window process mean was 77.36 / 41.91 ms, and process P95 was 187.2 / 71.5 ms. These measurements include profiler overhead and do not establish physical FPS.

## Bare browser comparison

The bare candidate is `build/performance/jelly-fps-callback-candidate-bare-v1-capture/collect-1.json`. It has no fine method wrappers, GL wrappers, trace or input diagnostics. The same browser version and SwiftShader adapter were used. Baseline sampled 83 frames; candidate sampled 91. Both committed all 56 mixed-Lv pickups, skipped zero, finished with zero tiles and retained learning/wallet callbacks.

| Bare Auto Collect metric | Baseline | Candidate |
| --- | ---: | ---: |
| Whole-window process mean | 64.94 ms | 39.92 ms |
| Whole-window process P95 | 149.0 ms | 56.5 ms |
| Whole-window engine interval P95 | 489.0 ms | 154.5 ms |
| Dense 40-56-tile process mean | 81.57 ms | 58.06 ms |
| Dense 40-56-tile engine interval P95 | 423.4 ms | 227.0 ms |
| Whole-window engine FPS | 5.01 | 7.54 |

Whole-window process mean decreased about 38.5% and dense-phase process mean about 28.8% in this single paired capture. Empty-page cadence remained near 30 FPS; these software-renderer results do not meet or prove physical 60 FPS. Live upgrade preparation and publication/rendering still contribute remaining frame spikes.

The candidate bare run also exercised ordinary full-board drag, merged full-board drag and a real merge. Drag remained active for the required sampled frames; the real merge rendered a fusion and left 55 bodies. All workload validity assertions passed and no browser errors occurred. Those candidate-only drag/merge captures are interaction checks, not matched performance claims.
