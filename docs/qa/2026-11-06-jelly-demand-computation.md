# Jelly World demand-driven computation during bulk falls

## Scope and status

This change targets the game page during automatic Fill arrivals and downward
collapse after clearing supports. Game-map presentation is outside this change.
The reported target PC uses a Ryzen 9950X3D and RTX 5070 Ti at 4K fullscreen with
browser zoom 1. The controlled diagnostic viewport remains 1366 x 768 at DPR 1.

The user's Chrome recording establishes repeated CPU stalls on the actual PC.
Separate instrumented reproduction identifies unrequested family-merge forecasts
as the dominant cost during ordinary Fill. The candidate removes that background
planning and reduces redundant layout, retained-paint invalidation and supply
occupancy scans. The paired 1366 x 768 capture, candidate 4K-backing diagnostic
capture and focused rendered regressions are complete. Final production-build
receipts and actual-PC acceptance remain separate from these diagnostics. Local
software-renderer measurements do not establish physical 60 FPS acceptance.

## Actual-PC trace evidence

Read-only analysis of the supplied Chrome trace produced ignored local evidence
under `build/performance/chrome-60fps/fall-hotspots-v1/user-trace/`. The private
trace and its screenshots are not included in repository content. CPU and frame
pipeline analysis use different declared windows: the CPU review covers a
3,046.283 ms event envelope; the pipeline review uses the selected 2,787.298 ms
DevTools window.

The renderer main thread contains eight tasks lasting 105.918 to 162.414 ms.
Together they consume 1,116.651 ms wall time and 1,075.607 ms thread CPU time,
approximately 96.3% of their wall duration. The 98 animation callbacks have a
5.495 ms median, 155.235 ms P95 and 162.222 ms maximum. Samples in the long tasks
are predominantly anonymous WebAssembly execution. These are substantial CPU
stalls before frame submission, which a faster graphics card alone cannot remove.

The union of recorded renderer V8 garbage-collection intervals is 1.035 ms; the
largest MinorGC event is 0.576 ms. Recorded browser GC cannot explain the repeated
100+ ms stalls. This measure does not account for every allocation or collection
inside the WebAssembly engine.

The pipeline evidence aligns each of the eight DrawFrame intervals above 40 ms
with a preceding animation callback lasting 105.685 to 162.222 ms. The callback
finishes only 0.26 to 0.38 ms before its associated DrawFrame.

| Recorded pipeline measure | Median | P95 | Maximum |
| --- | ---: | ---: | ---: |
| BeginFrame interval | 16.67 ms | 16.72 ms | 16.81 ms |
| DrawFrame interval | 16.67 ms | 157.05 ms | 167.03 ms |
| SendBeginMainFrameToCommit | 5.664 ms | 157.053 ms | 166.991 ms |
| Commit | 0.016 ms | 0.025 ms | 0.102 ms |
| StartDrawToSwapStart | 0.934 ms | 1.354 ms | 1.635 ms |
| Swap | 0.285 ms | 0.489 ms | 0.583 ms |
| SubmitCompositorFrameToPresentationCompositorFrame | 16.512 ms | 16.593 ms | 16.664 ms |

These are Chrome event stages, not hardware GPU timer queries. GPU-process
`GPUTask` durations describe CPU work in that process. The trace has no Godot
motion counters, WebGL draw timing, hardware elapsed timer or detailed raster
timing. It therefore does not prove that GPU work is free or identify the exact
game operation in each stalled task.

The exported engine has no usable WebAssembly name section or matching source
map. Anonymous indices such as `wasm-function[2238]` cannot honestly be mapped to
a particular GDScript method. CPU sample weights and nested inclusive stacks also
overlap; recursively repeated inclusive entries must not be added as exclusive
cost. The controlled method probes below provide separate source attribution.

Local analysis receipts are `cpu-review.json`, `gpu-pipeline-summary-v1.json`,
`gpu-frame-series-v1.json` and `gpu-draw-frame-correlation-v1.csv` in the ignored
trace-analysis directory. Their companion scripts retain the read-only analysis.

## Controlled baseline diagnosis

The baseline evidence is
`build/performance/jelly-demand-baseline-1366-v3/summary.json`, produced from
`build/performance/jelly-demand-baseline-view-v2/web`. The build receipt records
the copied-source fingerprint
`be74126c1a3163349234557b3efc329d7a4e0166ad8913743ef9c353716e9ce1`.

Two ordinary Fill episodes use seeds 73021 and 73022, production Age 3 vocabulary
(`apple`, `duck`, `milk`), three visible goal cards and fourteen merged bodies
supported by the bottom two rows. A real connected Fill toggle starts production
supply. Both episodes reach 56 settled bodies without a merge or collection.
There are 23 sampled frames per episode and 21 moving frames each: 42 moving
frames in total. Clocks, audio and artwork remain normal, with eight excluded
warmup seconds. No sampled deletion, injected gravity flag or reset motion age
is used.

Before this change, `_refresh_goal_buttons()` requested quotes for every family.
For a family containing an unsettled incoming body, the simple exact-count path
cannot apply. The model then clones a forecast, runs the merge timeline to
completion and counts its reduction. Its timing key includes unsettled body
ages, so later refreshes can repeat this complete simulation. Static prices
do not require these forecasts.

| Baseline moving-frame evidence | Episode 1 | Episode 2 |
| --- | ---: | ---: |
| Moving frames | 21 | 21 |
| View `_process` inclusive time | 7,815.0 ms | 8,340.3 ms |
| `family_merge_quotes.live` calls | 22 | 22 |
| Family quotes inclusive time | 7,006.6 ms | 7,434.4 ms |
| Family quotes / view inclusive time | 89.7% | 89.1% |
| Forecast instances | 61 | 58 |
| Forecast completion inclusive time | 6,796.6 ms | 7,211.2 ms |

These ratios describe nested inclusive diagnostic time, not separate additive
costs. Whole-episode counters record 4,225 and 3,916 forecast simulation slices,
versus 59 live slices in each episode. Full model/view snapshots, full JSON
encoders and host publication overrides have zero sampling-wide calls in both
captures. Lean publication is active; repeated full diagnostic serialization
does not explain this baseline.

The controlled host uses Hyper-V and ANGLE SwiftShader. Even its empty-page RAF
median is approximately 31.2 to 31.3 ms. Inclusive method wrappers, scalar
observers and software rendering add overhead. These large diagnostic times
establish which computation dominates this reproduction; they are not actual-PC
frame times or a forecast of the RTX 5070 Ti's performance.

## Candidate behavior

- Ordinary toolbar refreshes use cheap input-state readiness and current static
  use prices. They do not search for a complete legal merge for every button.
- Family quotes are requested only for the indicated family on deliberate hover
  or active keyboard/controller focus. Auto Merge planning likewise requires
  explicit preview demand. Pointer movement and rail presses clear stale focus
  demand; leaving, pausing and interaction gates clear previews appropriately.
- While any body is still settling, both exact family quotes and exact Auto
  Merge previews are deferred until the whole board settles. The family identity
  highlight and current static price remain available. Settlement restores the
  exact requested preview; purchase-time legality remains independent of this
  read-only presentation policy.
- A tool with unknown legal availability remains actionable. Actual activation
  independently checks the current board and exact current price before payment.
  A stale or absent preview cannot authorize a charge.
- The specialized Word Jelly face layout skips the inherited caption fitting
  pass that it immediately replaces. Picture geometry retains its prior order
  and Control rounding so visible geometry can be compared exactly.
- The settled-body layer retains unchanged paint when its allowed state and
  exact tint inputs are unchanged. Existing rectangle, visibility and cache
  watchers still invalidate real changes, including merged-effect occlusion.
- Fill checks cheap blockers before querying board availability. An authored
  supply packet without an active drag shares one operation-local occupancy map
  and updates it after each accepted body. External supply callbacks invalidate
  that map; drag-return and legacy paths retain fresh queries. A replaced or
  paused round ends the old packet before closing work touches the new board.

The occupancy optimization does not introduce a persistent geometry cache or
change gravity. Its regression oracle retains the former lane-by-lane packet
implementation and compares identities, geometry, supply, delays, counters, RNG
and later normal-clock simulation. Full blocked packets reduce occupancy scans
from seven to one; open seven-body Fill packets require at most one initial scan
and a rebuild after a supply-generation boundary. These are scan-count results,
not an end-to-end speedup claim.

The settlement gate coalesces changing incoming ages rather than throttling a
complete forecast to a recurring timer. An exact settled-board forecast remains
synchronous and should still be profiled for complex authored shapes; this
change does not introduce an asynchronous planner or a general per-frame CPU
budget.

## Paired 1366 x 768 diagnostic results

The pair is recorded in
`build/performance/chrome-60fps/fall-demand-v2/paired-1366-results.json` and the
raw summaries under `jelly-demand-baseline-1366-v3` and
`jelly-demand-candidate-1366-v3`. Both use Chrome 159.0.8140.0, DPR 1, the same
two seeds, the same three harness file hashes and 48 inclusive method wrappers.
The candidate source fingerprint is
`28e19827dc75438564d6a3f93f4c9e65b7414f8de17cb4886b2e2df7c288e995`.
Its frozen source includes the whole-board-settlement preview guards.

| Moving-frame process measure | Baseline episode 1 | Candidate episode 1 | Baseline episode 2 | Candidate episode 2 |
| --- | ---: | ---: | ---: | ---: |
| Moving frames | 21 | 30 | 21 | 28 |
| Mean | 375.59 ms | 28.31 ms | 400.90 ms | 33.20 ms |
| P95 | 586.50 ms | 57.80 ms | 683.50 ms | 58.20 ms |
| Maximum | 633.50 ms | 60.80 ms | 713.00 ms | 59.10 ms |
| Mean including adjacent entry/exit frames | 359.38 ms | 28.00 ms | 383.84 ms | 32.58 ms |

Every sampled moving body remains physically posed. Both variants reach the
same 56-body settled board, with zero cleared pairs, wallet delta, game error or
learning error. Moving-frame counts differ because these episodes use normal
real-time clocks rather than a fixed simulation step. Timing therefore describes
the measured episodes, not an identical-frame benchmark.

Sampling-wide source counters confirm that background forecasts disappear:

| Whole-episode call or slice count | Baseline episode 1 / 2 | Candidate episode 1 / 2 |
| --- | ---: | ---: |
| Live family quote calls | 23 / 23 | 0 / 0 |
| Live forecast construction calls | 61 / 58 | 0 / 0 |
| Forecast completion calls | 61 / 58 | 0 / 0 |
| Forecast model-step calls | 61 / 58 | 0 / 0 |
| Forecast simulation slices | 4,225 / 3,916 | 0 / 0 |
| Superseded base tile-layout calls | 294 / 294 | 0 / 0 |
| Specialized Word Jelly layout calls | 294 / 294 | 294 / 294 |

Call counts sum framed and separately retained unframed totals. All full
model/view snapshot and full-publication counters remain zero in the candidate,
including the `.live` and `.forecast` model variants. Live simulation slices are
68 and 66 in the candidate; increased presentation cadence does not create
forecast work.

The candidate's remaining inclusive costs are distributed across ordinary board
presentation and simulation. Per moving process frame, `_sync_tiles` records
13.70 / 16.74 ms, live model `step` 6.19 / 6.83 ms, `_sync_positions`
5.18 / 6.14 ms, specialized tile `_layout` 4.25 / 5.04 ms and `_sync_preview`
2.89 / 3.37 ms. These nested costs overlap and must not be added. The largest
candidate frames contain 21 to 28 specialized layouts and no forecast calls.
Configuration and supply-presentation batching are possible later profiling
targets; these observations do not establish a new correctness defect.

The pair demonstrates removal of the identified repeated computation and a
large reduction in diagnostic process time. It combines all candidate changes,
so it cannot isolate each change's timing contribution. Two episodes, shared
assets/imports, warm caches, method wrappers, scalar observers, Hyper-V and
SwiftShader limit the result. Candidate means remain above a 16.67 ms frame
budget in this lab, and submission/RAF timing also includes software-renderer
and host scheduling costs. This is neither a physical 60 FPS result nor an
estimate of the actual PC's remaining frame time.

## Candidate 4K-backing diagnostic results

The candidate capture is
`build/performance/jelly-demand-candidate-4k-v3/summary.json`. The browser records
2560 x 1440 CSS pixels at DPR 1.5 and visual-viewport scale 1, producing a
3840 x 2160 canvas backing. This exercises the 4K raster extent; it is not a
3840 x 2160 CSS layout. The adapter remains Hyper-V/SwiftShader.

Two Fill episodes contain 21 moving frames each, 42 in total, and both reach 56
settled bodies. Moving-frame process mean/P95/maximum is
39.03 / 58.90 / 61.40 ms for episode 1 and
36.89 / 66.70 / 87.60 ms for episode 2. These are candidate diagnostics only;
there is no paired 4K baseline in this capture.

The two supported row-clear episodes retain and settle all 49 survivors. They
contain only two observed moving frames each, four total, which is insufficient
for a useful moving-frame percentile or steady-state FPS conclusion. Whole
episodes preserve trigger and completion transitions, including the following
large process samples:

| Row-clear transition | Episode 1 process | Episode 2 process | Included Word Jelly view `_process`, episode 1 / 2 |
| --- | ---: | ---: | ---: |
| Seven legal collection handlers, before falling | 251.3 ms | 306.2 ms | 14.5 / 14.9 ms |
| Collection completion and release of 49 bodies | 262.0 ms | 209.1 ms | 252.5 / 199.5 ms |

The runner starts its process timer before invoking the declared seven-handler
trigger. The first large sample therefore includes collection-start callbacks
and presentation outside the view's own `_process`. Its measured specialized
layout work is 35 calls and 18.2 / 20.2 ms, but the current probes do not resolve
the much larger remainder into audio, art loading, collection presenters or
other application callbacks. WordArt has five/four resident sheets before the
episodes and nine afterward, so the warmed game page does not imply every
collection asset was already resident.

The second transition includes 214.6 / 171.0 ms in the live model `step`, versus
only 2.5 / 2.0 ms across three `_settle_collected_stack` calls. `step` includes
synchronous completion callbacks, so its inclusive duration is not pure gravity
cost. The seven mastery-eligible pickups can record learning and refresh active
progress through those callbacks; the probes do not separately time persistence
and each presenter. Coin balance and receipt count remain unchanged, with zero
collected coins in these row-clear fixtures. Unframed probes record only a few
milliseconds of cache-bake completion/request work and do not account for the
200+ ms transitions. No exact source-level attribution for the unresolved
transition cost is claimed.

Source review confirms that hidden Home hero geometry is already deferred:
`GameLibrary._layout_hero()` updates snapshot text and exits before geometry or
style allocation while hidden. Pip age/profile setters also guard unchanged
appearance. Repeated calls to those guarded methods are not evidence of a heavy
hidden rebuild, and no further production change is based on that hypothesis.

All four 4K episodes record zero forecast slices and zero full-publication
calls. Sampled body backing extents and body/core capture requests have zero
size-limit overflow. Body and core atlas-fallback counters add zero new fallbacks
during every episode. Fill capture requests reach 122 x 122 backing pixels;
row-clear body requests reach 141 x 141 and core captures at most 187 x 186.
These observations exclude a newly triggered sampled atlas-size failure; they
do not measure hardware GPU time or establish 60 FPS.

## Collection callback follow-up

A separate candidate-only capture uses 58 callback-oriented inclusive probes:
`build/performance/jelly-fall-callbacks-4k-v1/summary.json`. Its analysis is
`build/performance/chrome-60fps/fall-demand-callbacks-v1/candidate-callback-results.json`.
It retains the same 4K backing extent, declared seven-handler row-clear burst,
normal clocks, audio and artwork. Its probe set differs from the earlier view
capture, so timings are not a paired comparison. Each episode again observes
only two moving frames; these samples cannot establish steady-state FPS.

| Trigger-frame inclusive measure | Episode 1 | Episode 2 |
| --- | ---: | ---: |
| Whole process sample before falling | 312.6 ms | 330.6 ms |
| Seven view `_collection_started` callbacks | 214.7 ms | 218.6 ms |
| Fifteen `_refresh_fusion` calls | 103.7 ms | 107.6 ms |
| Sixty-three `_ensure_fusion_visual` calls | 93.7 ms | 98.5 ms |
| Seven `_jelly_hear` speech callbacks | 91.9 ms | 93.2 ms |
| Cold WordArt sheet loads | 62.3 ms, 3 calls | 80.0 ms, 4 calls |

The fusion refresh scans include creation/configuration of simultaneous
collection shells; normal serial collection can reuse one idle shell, while
this declared burst needs additional shells. Speech goes through synchronous
audio stream acquisition on a cache miss. Global WordArt advancement loads the
cold sheets outside the view's own process method. The reveal presenter itself
records 17.4 / 16.0 ms, and the collection-effect presenter 0.1 / 0.2 ms. These
are burst allocation, speech and cold-sheet costs, rather than a return of the
repeated background forecasts. Nested inclusive times overlap and must not be
summed.

The completion/release process samples remain 286.7 / 285.8 ms. Seven model
`_complete_collection` calls account for 225.3 / 223.0 ms inclusive. Known
learning and presentation callbacks explain only part of that envelope:
`_jelly_growth_answer` records 23.6 / 24.9 ms, `_combo_changed`
23.3 / 17.5 ms and `_collected` 19.7 / 15.5 ms. Fourteen growth snapshots total
5.3 / 11.1 ms; seven persistence calls total 3.2 / 1.8 ms. Hidden Home hero
layout records 0.1 / 0.0 ms in the completion frames. Neither growth persistence nor
hidden Home rebuilding is established as the dominant remainder.

Source review identifies an unprobed reward boundary worth isolating next.
These seven one-fragment pickups cross chest tier 0 to 1 on the fourth
completion. `fragments_awarded` has no production listeners, and reward-progress
calculation is constant-time arithmetic. The tier milestone invokes inherited
`_chest_milestone`, then celebration `enqueue` and `_prepare_models`.
`ChestRewardModel.prepare` can synchronously create a `ChestModelView` and run
`configure_closed_turn`, including source composition, model scans and measured
turn bounds. The two-entry reward-model pool is distinct from the already
warmed 2D icon cache. This is a concrete unmeasured path, not proof of its time
or attribution of the remaining completion cost. No production edit is based
on that attribution alone.

The next moving process samples are 49.1 / 52.3 ms; each still includes one
WordArt sheet load of 19.1 / 19.3 ms. Both episodes retain zero forecast slices,
zero full-publication calls, unchanged wallet balance/receipt count, zero new
body/core atlas fallbacks and no sampled capture-size overflow. Callback
bookkeeping and the local software adapter remain diagnostic overhead; these
results make no actual-PC or general 60 FPS claim.

## Validation

The root-run focused checks pass:

| Suite | Passing assertions/checks |
| --- | ---: |
| Word Jelly Fill demand | 101 |
| Word Jelly layout parity | 769 |
| Word Jelly hover demand | 139 |
| Word Jelly selected merge flow | 186 |
| Rendered settled-body layer | 57 |
| Rendered body cache | 64 |
| Rendered merged-core cache | 243 |
| Feedback space | 1,089 |
| Controls | 1,251 |
| Auto Collect hover | 397 |
| Powerup button | 1,389 |
| Preview caches | 595 |
| Drag performance | 49 |
| Motion poses | 153 |
| Tile performance | 506 |
| Base tile label | 75 |
| Hybrid tile | 3,396 |
| Fill stream | 5,493 |
| Fill stream view | 122 |
| Fill items | 1,581 |
| Gravity occupancy | 896 |

Fill coverage includes blocked/open/broken-sky packets, authored shapes, dragged
return and legacy fallbacks, external geometry mutation and round replacement.
Layout coverage compares native visible geometry while verifying that the
superseded base face pass is skipped. Hover coverage checks absent-demand work,
single-family selection, input-mode changes, pause/held/collection/finish gates
and fresh purchase validation. Its arrival regression advances 40 changing-age
refresh cycles for each explicitly hovered tool without a planner, forecast or
exact-preview query, then verifies the exact preview after landing. These checks
do not substitute for rendered pixel comparison or
target-PC performance acceptance.

The rendered settled-body-layer comparison reports pixel mean and maximum error
of zero. Body/core comparisons retain their existing tolerances; no threshold
was relaxed. These are controlled rendered regression results on the local
adapter, not browser GPU timings or actual-PC FPS acceptance.

The normal `npm run build:web` succeeds, including startup-pack inventory,
vocabulary, artwork and required-audio verification. Its local receipt is
`build/web-build.json`, created at `2026-11-06T02:54:41.033Z`, with SHA256
`016b0da03f88f47aeac70a026b5961abf57f094bb91a454d962dd512485d428d`.
It records 14,127 source inputs and 117 output files. The packaged game is
`game-3afdf02477e5077d.pck.br`, SHA256
`d2b4047720a9256a13a4f0d19a6d266cdb4c70854484a76b8eebbff568490028`.
The build and diagnostics above were completed before the release step.

The four Node test-runner checks pass, including complete default-suite
registration. Both desktop Chromium publication tests pass against that normal
build: lean production play retains map, pause and touch behavior, and explicitly
enabled diagnostics retain complete model and presentation snapshots. Browser
artifacts are under `build/performance/jelly-demand-browser-smoke/`.

## Reproducible diagnostic pair

The frozen local harness is under
`build/performance/chrome-60fps/fall-demand-v2/`. Its report protocol remains
`jelly-fall-hotspots-v1`. The builder copies source/configuration and records
fingerprints; licensed assets and existing engine imports remain shared
references, so they must remain unchanged across the pair. Standard Web build
imports and vocabulary packs must already exist. Use fresh output labels because
the harness refuses to overwrite evidence.

For the same local workspace, the following commands build and capture a fresh
pair without switching branches or modifying the production export:

```powershell
$jellyDemandHarness = "build/performance/chrome-60fps/fall-demand-v2"
node "$jellyDemandHarness/build.cjs" --source build/performance/chrome-60fps/fall-hotspots-v1/baseline-source --label jelly-demand-baseline-repro-01 --profile view
node "$jellyDemandHarness/build.cjs" --source . --label jelly-demand-candidate-repro-01 --profile view
node "$jellyDemandHarness/capture.cjs" --directory build/performance/jelly-demand-baseline-repro-01/web --label jelly-demand-baseline-capture-01 --headed true --repeats 10 --seconds 20 --warmup 8 --scenarios fill,row-clear --width 1366 --height 768 --dpr 1 --min-moving 20 --expect-lean true
node "$jellyDemandHarness/capture.cjs" --directory build/performance/jelly-demand-candidate-repro-01/web --label jelly-demand-candidate-capture-01 --headed true --repeats 10 --seconds 20 --warmup 8 --scenarios fill,row-clear --width 1366 --height 768 --dpr 1 --min-moving 20 --expect-lean true
node "$jellyDemandHarness/analyze.cjs" build/performance/jelly-demand-pair-repro-01.json build/performance/jelly-demand-baseline-capture-01/summary.json build/performance/jelly-demand-candidate-capture-01/summary.json
```

The row-clear fixture starts from a supported full mixed-level board and invokes
seven legal view collection handlers on its bottom supports; ordinary gravity
drops the 49 survivors. It is a declared burst of seven handlers, not Auto Collect
and not one player gesture. Timing retains the entire episode and separately
reports moving frames plus adjacent entry/exit frames, because a post-draw
settled flag can otherwise hide an expensive final-landing frame. Method counts
include separate unframed work; full snapshot labels must include `.live` and
`.forecast` variants when checking for zero publication calls. CPU submission
completion is not a GPU-presentation fence.
If the minimum moving sample count is not reached for either scenario, use a
fresh label and more episodes rather than slowing gameplay clocks.

## Completion status and acceptance

The production build, focused checks and both desktop browser smoke checks are
complete, with receipts recorded above. The completed 1366 x 768 pair establishes
local CPU-work reduction within its declared limits; the candidate 4K
diagnostics retain the unresolved collection transition spikes described above.
Final acceptance must include actual-PC full-board Fill,
downward collapse, dragging and mixed-level Auto Collect; the local software GPU
cannot establish physical 60 FPS.
