# Jelly Web publication and moving paint optimization

## Scope

This change addresses complete diagnostic snapshots and redundant moving-body
presentation updates on the game page. The baseline is committed revision
`39847046b732c6baf237dd5d5ca55e7f9d800608`, which already contains static item
prices. Map presentation is outside this change.

Normal Web Word Jelly play selects a small status envelope before constructing
the full model/view snapshot. It retains visibility, mode, round, phase, pause,
map visibility and error state. Native gameplay, learning, wallet persistence,
collision, audio and live announcements remain independent of diagnostic DOM
payloads. `?jellyDiagnostics=1` restores complete diagnostic snapshots. Native
views and native `changed` observers retain the complete publication path;
switching policies forces the appropriate host payload before ordinary
deduplication resumes.

Moving-body presentation computes the final size, position, layer, pressure and
support before applying them. It no longer resets each airborne body to its
destination and neutral shadow before applying its actual pose. Neutral movement
can reuse cached body paint and compatible merged cores. Interaction suspends a
merged core while retaining its texture and bounded atlas reservation.

## Visual constraints

An initial affine-raster shortcut was rejected by the existing tight pixel
comparison. Its maximum silhouette-edge error was 74/255, despite a small average
error. Resampling the small cached raster during stretch cannot reproduce direct
sampling of the acquired source artwork. Affine stretch, nonlinear pressure and
contact therefore use the original shader; the picture and learning face keep
their native geometry.

A rotated tile also exposed fractional raster-phase differences during
translation. Merged-core reuse now requires the same render basis and an integer
backing-pixel displacement. Incompatible rotation or pixel phase restores native
source paint. Returning to a compatible neutral pose reuses the retained core.
The 2048-square atlas, 64-slot limit and two-bakes-per-frame limit are unchanged.
An interrupted, unbaked reservation resumes the same key and revision when it
becomes eligible again. The rendered warmup regression interrupts one of 56
pending owners, drains the other 55, then verifies one final bake and unchanged
owner/slot counts after recovery.

Final rendered revision-3 checks on Microsoft Basic Render Driver passed:

| Suite | Checks | Result |
| --- | ---: | --- |
| Body cache | 64 | Native affine fallback has zero pixel error |
| Merged core cache | 243 | Translated full board remains within the original RGBA8 limits |
| Settled body layer | 25 | Zero pixel error |

The translated merged-board comparison used 732 source draws versus 457 cached
draws, including the rotated tile's native fallback. This is a controlled native
rendering comparison, not a browser GPU or physical-FPS result. The failed
revision-1 logs remain alongside the successful revision-2/3 logs under ignored
`build/performance/chrome-60fps/lean-motion-v1/`; no thresholds were relaxed.

## Regression evidence

Twelve initial native suites passed, covering publication, falling contact, Fill,
full-board drag, view updates, Auto Collect hover and controls. After the
conservative rendering fallback and publication-policy hardening, the focused
publication suite passed 129 assertions, motion poses passed 153 checks, and tile
performance passed 506 checks. The host Node suite passed 11 tests. The native
publication fixture advances 24 changing body poses without constructing a full
snapshot or calling either complete JSON encoder, and verifies native-observer
compatibility and encoded-before-native signal order.

The final standard `npm run build:web` succeeds, including startup vocabulary,
production artwork, motion and audio pack verification. Both new desktop browser
publication checks pass against that export: normal lean Stage 1 entry/pause/
touch behavior and explicit complete diagnostics. Final build-receipt verification
confirms 14,127 source inputs and 117 output files remain unchanged.

The existing browser case `manual and automatic preview packets naturally fall
into the well` passes manual release but fails its automatic first-observed-frame
assertion in this lab. The candidate fails with tracing enabled and disabled;
the frozen baseline also fails the same unchanged assertion with tracing
disabled. The baseline replay uses the diagnostic baseline export, whose idle
benchmark hooks remain installed, and is not an uninstrumented FPS comparison.
Candidate/baseline first centers are 131.97/130.78 logical pixels versus the
124.57-pixel upper bound. The traced candidate timeline first observes all seven
automatic bodies at age 0.233333; manual bodies first appear at age zero.

Source inspection explains the distinction: automatic Fill generates bodies at
the beginning of a model step, advances them by that frame's consumed delta, and
publishes after the step. Manual release can publish before stepping. Model
timing is unchanged by this optimization. This is a retained large-frame
automatic-start limitation, not a passing regression check; the test and its
threshold remain unchanged. Failed traces/timelines, the untraced retry and the
frozen-baseline replay remain in the ignored harness directory.

## Paired browser diagnosis

The revision-2 benchmark exports use identical runner/fixture hashes, Chrome
Canary 159.0.8140.0, a 1366 x 768 viewport, DPR 1, normal motion/audio, an
eight-second warmup and a six-second sample. Both exports contain the same 14
inclusive CPU probes and post-submission scalar observations. GL wrappers,
Chrome tracing and full observer snapshots are disabled. The baseline uses its
original complete publication policy; the candidate uses ordinary lean Web play.
Source fingerprints and shared-asset limitations are recorded in each
`benchmark-build.json`.

| Workload | Process mean, baseline / candidate | Process P95, baseline / candidate | Publish inclusive ms per frame, baseline / candidate |
| --- | ---: | ---: | ---: |
| Fill, 14 to 56 bodies | 46.11 / 22.96 ms | 93.10 / 64.20 ms | 21.96 / 0.084 |
| Gravity stress, all 49 bodies | 48.19 / 11.51 ms | 63.30 / 30.00 ms | 35.60 / 0.075 |

These are whole-window process measurements, including the settled tail. The
moving portions contain 23/26 frames for Fill and only 2/3 for gravity stress;
their respective process means are 64.26/39.51 ms and 61.20/26.43 ms. The short
gravity phase cannot support a reliable moving-only percentile or speedup claim.
Frame counts and phase summaries are retained in `results-v2.json`; raw motion
samples remain in the capture summaries.

The baseline makes 47 complete publications during Fill and 45 during gravity.
The candidate makes zero calls to the complete model/view snapshots, base/host
encoders or full campaign overlays during either sample, including input and
deferred work between drawn frames. Every observed moving model ID retains an
active view tile. Fill reaches 56 settled bodies; gravity moves and settles all
49. Both finish playing, visible, unpaused and without game or storage errors.
Gravity observes up to 42 moving cached skins and four moving cached cores;
these counts overlap and occur in only one of its three moving samples. Fill
retains native affine rendering and observes no cached moving skins.

Both captures use SwiftShader. Empty-page cadence varies from 21.56 to 29.33 FPS
across the pair; this and the single-repeat diagnostic instrumentation preclude
physical-FPS acceptance or attributing a displayed-FPS percentage improvement.
Artifacts are `jelly-lean-motion-baseline-capture-v2/summary.json`,
`jelly-lean-motion-candidate-capture-v2/summary.json`, and
`chrome-60fps/lean-motion-v1/results-v2.json` beneath `build/performance/`.

## Full-board interaction diagnosis

The candidate's separate 12-second interaction captures use the same export,
normal motion/audio and strict sampling-wide lean assertions. Native Chrome CDP
mouse input holds the ordinary source for 120 of 124 frames and the merged
source for 99 of 103 frames. Both keep all 56 bodies and commit no unintended
merge or collection. Process mean/P95 is 10.86/14.30 ms for ordinary drag and
16.12/26.00 ms for merged drag. These candidate-only captures have no matched
interaction baseline, so they establish regression coverage, not a measured
interaction speedup.
Merged drag still observes 69 new core bakes during the sample; retained neutral
paint does not eliminate all atlas work.

Auto Collect starts and commits all 56 bodies across nine words and Lv1-9, skips
zero, and leaves the board empty. The wallet receives 5,000 coins, learning has
zero pending records or save failures, and game/journal errors remain empty.
All three interaction captures make zero complete snapshot/encoder/overlay calls,
including unframed input/deferred work.

The dense collecting phase contains 23 frames with 40-56 bodies. Its process
mean/P95/maximum is 37.53/59.80/175.80 ms; the whole collecting queue has an
inclusive live-model-step cost that also includes synchronous completion
callbacks. Auto Collect still has CPU spikes in this diagnostic environment.
The largest spike contains 161.70 ms in the inclusive live-model step and only
0.10 ms in publication; narrower probes are required to identify its cause.
Removing publication work does not establish a 16.67 ms frame budget for that
path. Raw phases, storage boundaries and inclusive counters remain in
`jelly-lean-motion-interaction-capture-v2/summary.json` and
`chrome-60fps/lean-motion-v1/interaction-results-v2.json`.

Detailed logs and source-fingerprinted benchmark exports are retained under
ignored `build/performance/`. Instrumented method durations are inclusive and
overlap; they must not be added together. Post-submission scalar observers add
cadence overhead. Body and merged-core cache counts overlap and are not additive
counts of optimized bodies. `frame_post_draw` measures submission completion,
not GPU completion or displayed frames. The available Hyper-V software-rendered
Chrome environment cannot establish physical 60 FPS acceptance.
