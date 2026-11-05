# Jelly World full-board performance

Target: the game page in PC Chrome at 1366 x 768, DPR 1, with 56 Jellies, normal motion and audio. The game map is excluded from this change.

| Evidence | Status |
| --- | --- |
| Native publication encoding and gravity CPU comparisons | Verified, with semantic parity |
| Corrected V4 rendered baseline/candidate comparison | Verified single-repeat software-renderer captures, six scenarios |
| Bare candidate capture without GL wrappers | Verified for ordinary drag and Auto Collect |
| Final dense production encoding comparison | Verified complete native base/host byte parity, three scenarios |
| Physical GPU 60 FPS acceptance | **PENDING: user testing on actual PC Chrome** |

## Implementation and render parity

Ordinary settled Jelly skins share one body layer, while moving and interactive bodies return to their original nodes. The 25-check body-layer suite passed with pixel-identical tested renders, including restoration and neighboring artwork.

Settled merged cores share a bounded 2048 x 2048 RGBA8 atlas with 64 cells, warmed at two captures per frame. The cache preserves production artwork and Godot's native glyph rendering for labels, fragment text and Lv badges, together with shadows and boss overlays; it does not substitute custom glyphs or simplified art. The 193-check merged-core suite covers full boards, ancestor alpha, mixed neighbors and the stretched desktop viewport. RGBA8 rounding is limited to maximum RGB error 4/255, mean error 0.35/255, and at most 0.05% of pixels exceeding 2/255. Its rendered draw-call comparison fell from 732 to 452. Draw-call counts and pixel parity are rendering evidence, not a displayed-FPS claim.

Additional suites passed 896 gravity checks, 194 collection-effect checks and 636 merged-level-effect checks. These support preserved gameplay and effects; native CPU timings and software-rendered cadence are reported separately below.

## Verified CPU diagnostics

Frozen production source: `76d49ec79db722cebb00a16db0dabb2ca86102e6`, copied to `build/performance/baseline-60fps-76d49ec`.

`build/performance/chrome-60fps/publication-cpu.json` measures encoding a 56-tile, 176,112-character snapshot over 210 samples. Semantic parity is true.

| Encoder | Mean | P95 |
| --- | ---: | ---: |
| Fragmented reference | 13.985 ms | 15.949 ms |
| Whole dictionary | 24.870 ms | 28.309 ms |
| Cached fragments | 7.372 ms | 8.773 ms |

This is encoding CPU only. Snapshot construction, the browser bridge, rendering, audio and physical FPS are excluded. The earlier ordinary fixture has substantially less vocabulary metadata than the corrected mixed-merged board; its 176,112-character payload does not represent the later approximately 373,000-character dense snapshot.

`build/performance/chrome-60fps/gravity-cpu.json` uses Godot 4.7.2, seed 73021, 30 warmup iterations and 1,000 samples per case. Fixture resets, parity checks and alternating call order are outside timing. Semantic parity is true for every case.

| Gravity case | Reference mean | Candidate mean | Reduction |
| --- | ---: | ---: | ---: |
| Lifted support, 56 bodies | 7.005 ms | 1.003 ms | 85.68% |
| Falling, 56 bodies | 7.735 ms | 1.276 ms | 83.51% |
| Removed support, 55 remaining bodies | 7.765 ms | 1.122 ms | 85.55% |

Per-body occupancy queries fall from 55,000 / 48,000 / 55,000 to zero. These figures cover gravity CPU only, excluding other model clocks, view work, browser rendering and audio.

## Corrected V4 software-renderer comparison

The valid paired artifacts are `build/performance/jelly-fps-baseline-v4-capture/summary.json` and `build/performance/jelly-fps-candidate-v4-capture/summary.json`. Each side contains one repeat of six scenarios, using Chrome 159.0.8140.0, a visible headed window, 1366 x 768, DPR approximately 1, eight seconds of warmup, normal motion and unmuted audio. GL auditing is enabled; Chrome tracing, CPU instrumentation and input snapshot diagnostics are disabled.

Both exports use runner SHA-256 `47f4a2c28a83ea45cb1db0aa29e378af53e5a97c6270f89488b22b9ccd24602a` and fixture SHA-256 `d5b817fe53ccc5ba4a61821a5cc7168a3c0f44286959fa2bc706411d8dce009e`. Their recorded copied-source fingerprints are `032bc84b84db9fd9ec0c22ae9066e865c6bab1c5d93520afc1e08acf32f5f23d` for baseline and `91c7fdf6326c114af08178a49c7ebfc24ea1edac3a1944fc82201170c32cc38f` for candidate. Shared licensed assets and imports are excluded from those fingerprints.

| Scenario | Baseline engine FPS | Candidate engine FPS | Baseline CPU mean | Candidate CPU mean | Engine interval P95, baseline / candidate |
| --- | ---: | ---: | ---: | ---: | ---: |
| Ordinary idle | 8.69 | 10.93 | 38.02 ms | 17.23 ms | 130.3 / 106.5 ms |
| Merged idle | 7.13 | 8.89 | 40.17 ms | 28.13 ms | 159.5 / 121.1 ms |
| Ordinary drag | 8.76 | 8.56 | 33.51 ms | 33.66 ms | 123.2 / 126.2 ms |
| Merged drag | 6.92 | 7.43 | 40.13 ms | 33.12 ms | 178.3 / 160.6 ms |
| One real merge, whole window | 10.31 | 10.95 | 26.02 ms | 19.86 ms | 137.5 / 133.5 ms |
| Mixed Auto Collect, whole window | 5.08 | 5.63 | 59.70 ms | 49.62 ms | 513.1 / 486.6 ms |

Ordinary drag shows no improvement in this pair. The other scenarios improve, but one repeat on a software GPU does not establish a stable hardware FPS result.

Both merge runs rendered a real fusion and ended with 55 tiles. Fusion-only engine FPS was 7.36 / 9.29 over six / seven active frames. Including the entry and exit transitions, mean interval was 146.47 / 119.90 ms. The entry spike remained 246 / 245 ms; whole-window means do not imply that this spike was eliminated.

Both Auto Collect runs started and committed all 56 pickups, skipped zero, ended with zero tiles, and retained the real learning/wallet callbacks. In the 40-56-tile dense phase, CPU mean improved from 76.83 to 63.14 ms, engine FPS from 4.67 to 5.39, and engine interval P95 from 433.8 to 388.3 ms. The candidate began with 52 cached merged cores, finished with 57 total atlas bakes, and had zero atlas fallbacks. Peak visible and resident collection effects were eight. Dense-phase statistics are separate from the effects and empty tails.

These V4 browser captures precede the final native-array publication fallback below. They measure their recorded exports and are not fresh FPS validation of the final release artifact.

## Bare candidate captures

`build/performance/jelly-fps-candidate-v4-bare/summary.json` contains one ordinary-drag and one Auto Collect capture of the same V4 candidate, with GL auditing disabled. No GL wrappers, counters or frame-boundary hooks are installed. Chrome tracing, CPU instrumentation and input snapshot diagnostics are also disabled; normal audio and motion remain enabled.

| Scenario | Engine FPS | Engine interval P95 | CPU mean |
| --- | ---: | ---: | ---: |
| Ordinary drag, 56 tiles | 8.63 | 134.2 ms | 32.87 ms |
| Auto Collect, whole window | 4.79 | 532.0 ms | 68.93 ms |
| Auto Collect, 40-56-tile dense phase | 4.39 | 478.2 ms | 90.72 ms |

All 56 bare Auto Collect pickups committed, with zero skips and zero remaining tiles. This selected-scenario capture is not a full six-scenario bare comparison. Its slower collection timing also demonstrates run variability; comparing it with one audited run does not isolate GL-wrapper overhead.

All corrected V4 runs used `ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero) (0x0000C0DE)), SwiftShader driver)`. Empty-page median intervals were approximately 31.3 ms. The separate MCP production diagnostic in `build/performance/chrome-60fps/production-baseline.json` used Microsoft Basic Render Driver and a 31.25 ms empty-page cadence. These are different software adapters and cannot form a matched pair. Neither environment establishes physical 60 FPS.

## Remaining Auto Collect CPU hotspots

`build/performance/jelly-fps-candidate-v4-collect-profile/collect-1.json` is a corrected, instrumented diagnostic with 82 sampled frames, 56 completed pickups and a complete initial base snapshot of 374,498 characters. Instrumentation adds overhead; its inclusive times overlap and must not be summed or compared directly with uninstrumented FPS captures.

| Method | Calls | Inclusive total | Inclusive time per sampled frame |
| --- | ---: | ---: | ---: |
| `WordModel.step` | 82 | 2,732.3 ms | 33.32 ms |
| `WordJelly._publish` | 292 | 2,361.7 ms | 28.80 ms |
| `PublicationCache.encode_base` | 85 | 925.6 ms | 11.29 ms |
| `WordJelly.snapshot` | 85 | 644.0 ms | 7.85 ms |
| `WordModel.snapshot` | 85 | 216.6 ms | 2.64 ms |
| `PublicationCache.encode_host` | 84 | 46.9 ms | 0.57 ms |

The base encoder averaged 10.89 ms per call and the full view snapshot 7.58 ms per call. Model snapshot time is included in view snapshot time. Many publication calls defer; 292 calls do not mean 292 complete serializations.

`WordModel.step` includes synchronous completion callbacks, not only gravity. Source inspection follows `_complete_operation` and `_complete_collection` into learning-attempt recording, wallet credit, combo and collected signals, HUD refresh and host publications. Growth attempt recording also refreshes stage targets and shared Growth presentation. The profile does not isolate each callback's cost, so the 33.32 ms cannot be attributed solely to physics or to one persistence operation. Callback work remains a performance hotspot; learning evidence, receipts, signals and Auto Collect ordering are retained.

## Dense encoding decision and final fallback

The isolated field-cache experiment passed 726 parity checks but was discarded after `build/performance/chrome-60fps/record-field-cpu-v1.json`. It used a real 56-body mixed-merged view/model snapshot, nine reviewed production Age 3 words, Lv1-9, 20 warmup iterations and 80 samples per case.

| Field-cache experiment | Reference mean | Original record-cache mean | Isolated field-cache mean |
| --- | ---: | ---: | ---: |
| Age only | 20.445 ms | 10.676 ms | 45.656 ms |
| Falling and pose changes | 20.803 ms | 33.212 ms | 54.026 ms |
| Persistent nested metadata | 19.540 ms | 10.145 ms | 45.642 ms |

A smaller detached-container reuse variant passed 109 checks but also had no meaningful win. Its separate 10-warmup / 40-sample report is `build/performance/chrome-60fps/detached-record-cpu-v1.json`.

| Detached-copy experiment | Reference mean | Original record-cache mean | Isolated detached-copy mean |
| --- | ---: | ---: | ---: |
| Age only | 32.242 ms | 14.159 ms | 13.686 ms |
| Falling and pose changes | 30.487 ms | 49.820 ms | 50.023 ms |
| Persistent nested metadata | 27.740 ms | 13.013 ms | 13.548 ms |

Compare encoders within each paired report; absolute timings vary between runs. Both experiments were archived under ignored `build/performance/encoder-experiments` and excluded from production.

The final production encoder retains cached age-only records and uses native whole-array JSON for a dense moving stack. For arrays of at least eight records, it samples eight evenly spaced records and selects native encoding when more than four are falling or unsettled. It clears that array's stale record cache, then rebuilds cache entries after the stack settles. Complete snapshots, host overrides and publication semantics remain intact.

`build/performance/chrome-60fps/publication-dense-cpu-v1.json` verifies the actual final production encoder against the fragmented native reference. The full production view/model fixture has 56 merged bodies, nine authored Age 3 word identities, all nine merge levels and a 372,703-character initial snapshot. Each case uses 10 warmup iterations and 40 samples, alternates the two encoder orders, and verifies complete native base and host bytes outside timing. Encoder source hashes are recorded in the artifact.

| Final encoding case | Reference mean | Production mean | Reference P95 | Production P95 |
| --- | ---: | ---: | ---: | ---: |
| Age only | 18.553 ms | 8.917 ms | 23.452 ms | 11.753 ms |
| Falling and pose changes | 18.902 ms | 17.607 ms | 26.240 ms | 23.486 ms |
| Persistent nested metadata | 19.562 ms | 10.352 ms | 25.254 ms | 15.415 ms |

These are native encoding CPU measurements, excluding snapshot creation, rendering, browser bridge, signals, Auto Collect callbacks, audio and physical FPS. They address the record-cache falling regression without claiming that CPU encoding alone meets the frame budget.

Final focused checks passed: 200 publication-cache checks, 10 library-publication checks, 30 collection-learning checks, and 35 Node packaging/deployment/performance/test-runner checks. Physical full-board idle, drag, merge and Auto Collect acceptance at 60 FPS remains pending on the user's actual PC Chrome after deployment.

The final production Web build passed startup-pack, deferred vocabulary, production artwork and audio verification. Its build receipt verified 14,068 unchanged source inputs and 117 output files. A clean Chrome Canary context at 1366 x 768 loaded the real full-board challenge, exercised native mouse dragging and released the source with all 56 bodies retained. It reported no browser errors, 56 cached body skins, 52 batched ordinary bodies and no merged-atlas fallbacks. The smoke artifacts are `build/performance/chrome-60fps/release-smoke.json` and `release-smoke.png`; this checks the final export's boot and interaction, not physical FPS.

## Superseded browser diagnostics

The earlier fixture placed its required `view.configure(...)` call inside `assert(...)`. Release exports remove assertion expressions, so the rendered cat board retained the preceding stage's internal vocabulary. The baseline merge reached the intended target but could not legally merge. All V2/V3 browser runs are diagnostic evidence only, including the five completed V3 scenarios; they cannot be paired with the corrected fixture for acceptance.

The corrected fixture executes initialization and validation explicitly, decorates words with the production Growth morphology, constructs ordinary roots through the production composition constructor, checks a legal pair, and records the actual cohort, authored flag and learning age. Both sides must use this same corrected harness.

`build/performance/jelly-fps-collect-profile-v2-valid/collect-1.json` remains an earlier instrumented diagnostic. Its pickups completed, but it predates the corrected V4 fixture and cannot replace the V4 evidence or serve as a matched acceptance comparison.

## Corrected capture procedure

Run exports sequentially and keep licensed assets and imports unchanged between them. The builder records copied-source and harness hashes; shared assets and `.godot` resources are not frozen by that fingerprint. Use new labels because existing results are never overwritten.

```powershell
node tools/build-jelly-fps-web.cjs --source build/performance/baseline-60fps-76d49ec --label jelly-fps-baseline-v4
node tools/build-jelly-fps-web.cjs --label jelly-fps-candidate-v4
node tools/benchmark-jelly-fps-browser.cjs --directory build/performance/jelly-fps-baseline-v4/web --label jelly-fps-baseline-v4-capture --channel chrome-canary --headed true --warmup 8 --repeats 1 --gl-audit true
node tools/benchmark-jelly-fps-browser.cjs --directory build/performance/jelly-fps-candidate-v4/web --label jelly-fps-candidate-v4-capture --channel chrome-canary --headed true --warmup 8 --repeats 1 --gl-audit true
node tools/benchmark-jelly-fps-browser.cjs --directory build/performance/jelly-fps-candidate-v4/web --label jelly-fps-candidate-v4-bare --channel chrome-canary --headed true --warmup 8 --repeats 1 --gl-audit false --scenarios drag-ordinary,collect
```

Defaults cover ordinary idle, merged idle, ordinary drag, merged drag, one real merge and mixed Auto Collect. Match Chrome version, headed mode, adapter, viewport, DPR, harness hashes, assets, audio and motion. CPU profiling, Chrome tracing and `--input-diagnostics true` are diagnostic runs with additional overhead; keep them off in comparisons and acceptance captures. GL auditing defaults to true for comparison with audited captures. Bare captures install no GL API wrappers, counters or boundary hooks.

Warmup is excluded from timing, and its duration and final cache state remain recorded. Use separate short-warmup diagnostics to inspect cold behavior. Merge reports retain internal fusion intervals, entry/exit crossing intervals and their union. Collect reports separate dense active tiles, the active queue, peak effects, the effects tail and the empty tail. A fast empty tail cannot stand in for full-board performance.

Input uses Chrome mouse dispatch for dragging and merging, and the real scene button for Auto Collect. Collection must start and commit all 56 pickups with no skips; merge must render fusion and leave 55 tiles. `RenderingServer.frame_post_draw` marks submission completion, not a GPU fence or displayed frame. Record empty-page cadence and adapter before interpreting the target; physical 60 FPS acceptance remains pending on a suitable hardware-rendered PC Chrome environment.
