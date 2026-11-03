# Jelly Words drag performance

The 2026-10-22 five-pair CPU diagnostic reduced mean drag-update time by 69.7%-90.2%
across eight scenarios, with matching per-frame interaction traces. These are
headless CPU measurements, not mobile FPS or touch-to-screen latency results.

## Changes

Pointer motion retains the first drag-threshold crossing and then consumes the
latest position once per presentation frame. Pointer-up resolves its own final
coordinates immediately. Touch cancellation, pause, loss of focus, and responsive
layout changes discard pending input. Direct scripted moves remain synchronous.

The presentation pass shares cell lookup, merge eligibility, preview return-space,
palette, and completion-hint work. These decisions are discarded before publishing
state and never survive a model step. Contact first checks outline bounds, then
keeps the existing exact polygon intersection and nearest-target rules.

Repeated tile projection, geometry, shadow, and unchanged shader-property writes
are skipped. Production artwork, animation, contact feedback, and reduced-motion
behavior are retained. Full diagnostic snapshots are no longer created for every
motion event; the existing periodic and transition publications remain available.

## CPU diagnostic protocol

`word-jelly-drag-cpu-v1` measures headless execution of the real Word Jelly view,
including touch input dispatch, one manually advanced 1/60-second model/view
update, and the host's dictionary-copy/JSON serialization work. The renderer,
browser JavaScript execution, audio playback, physical touch latency, and device
frame pacing are excluded. This is neither a rendered-frame nor a phone FPS test.

The seeded 390 by 844 fixture uses ordinary production cat roots, pictures, and
artwork with normal motion. The eight cases combine 18 or 42 settled bodies,
empty-space or contact paths, and one or four motion events per simulated frame.
Each case warms up for 30 frames; the runner defaults to 120 measured frames and
five independent process pairs. A shorter diagnostic must disclose its sample
count. No collection or spawning occurs in the timed interval.

Each pair alternates baseline/candidate order. Source and shared harness hashes
must stay fixed. Per-frame source positions, contact targets/kinds, and placement
validity are recorded outside timing and must match exactly between versions.
Contact cases must actually touch another body; empty cases must remain clear.
Raw microsecond samples, contact-frame counts, presentation passes, snapshots,
and serialized character counts are retained. Character counts are not byte counts.

Freeze the desired source revision, then compare with the working copy:

```powershell
node tools/freeze-performance-baseline.cjs --ref HEAD --output build/performance/jelly-baseline
node tools/benchmark-word-jelly-drag.cjs --baseline build/performance/jelly-baseline --label jelly-drag-paired --repeats 5
```

Only one engine or browser performance workload should run during collection.
The freeze tool shares assets/imports/tests with the working copy; keep those
inputs unchanged. Output labels must be new: the runner never replaces previous
reports. Results live under ignored `build/performance/<label>/`.

## Paired CPU results on 2026-10-22

The baseline is commit `d9c5e72e6c5892acf9f86b5b0314a714f7be10d1`, frozen in
`build/performance/jelly-mobile-baseline-20261022`. The candidate is this working
copy. Both used Godot 4.7.2 on Windows, on a host reporting an AMD EPYC 7763 CPU,
eight cores and sixteen logical processors. No browser tests, Web builds, or
other Godot workloads ran during measurement.

This shorter CPU diagnostic used five independent pairs, 30 warmup frames per
case, and 60 measured frames per case per process. Each version contributes 300
samples per row. Baseline/candidate order alternated between pairs. All source
and harness hash checks passed, as did exact source-position, contact-target,
contact-kind, and placement trace comparisons in all 40 paired scenarios.

Times below are milliseconds per manually advanced update. P95 is calculated
from the pooled 300 raw samples for that row and version.

| Bodies | Path | Motions per update | Before mean | After mean | Before P95 | After P95 | Mean reduction |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 18 | Empty space | 1 | 17.563 | 4.909 | 19.687 | 10.943 | 72.1% |
| 18 | Empty space | 4 | 52.213 | 5.104 | 61.407 | 11.215 | 90.2% |
| 18 | Contact | 1 | 17.210 | 5.222 | 19.349 | 11.497 | 69.7% |
| 18 | Contact | 4 | 50.403 | 5.113 | 56.353 | 11.663 | 89.9% |
| 42 | Empty space | 1 | 38.548 | 11.024 | 42.275 | 23.663 | 71.4% |
| 42 | Empty space | 4 | 110.704 | 11.277 | 124.383 | 24.366 | 89.8% |
| 42 | Contact | 1 | 38.726 | 11.284 | 43.167 | 24.096 | 70.9% |
| 42 | Contact | 4 | 113.538 | 11.273 | 134.259 | 24.327 | 90.1% |

Position passes fell from two to one per update for single motions, and from
five to one for four-motion bursts. Full snapshots fell from one or four per
update to eight per 60 measured updates. Serialized character volume fell by
approximately 86.7% and 96.7%, respectively. The remaining periodic publication
cost is included in the timings. Crowded-board P95 still exceeds 16.7 ms even
without rendering; these results do not establish a sustained 60 FPS budget.

The raw samples, repeat means, source/harness hashes, interaction traces, and
individual engine logs are retained in `build/performance/jelly-drag-paired/`;
`summary.json` contains the aggregate comparisons. The earlier single-pair,
30-sample diagnostic is retained separately and is not pooled into these results.

Exact invocation:

```powershell
node tools/benchmark-word-jelly-drag.cjs --baseline build/performance/jelly-mobile-baseline-20261022 --label jelly-drag-paired --repeats 5 --samples 60
```

Use a fresh output label when repeating the measurement.

## Functional checks

The focused drag regression checks touch bursts, latest-position presentation,
release before another frame, threshold excursions that return before a frame,
cancellation, pause/resume, resize, and presentation-cache invalidation. The tile
regression covers repeated projection/layout, theme refresh, responsive sizes,
shader feedback, level rewards, and reduced motion. Existing Word Jelly and shared
Jelly Match suites cover collection, wallet receipts, contact, placement, and flow.

Real Android Chrome and iOS Safari hardware still require drag frame-time and
touch-to-screen checks on sparse and crowded boards. Browser emulation can verify
interaction and layout, but cannot establish those device performance results.

## Validation on 2026-10-22

Native engine: Godot 4.7.2 on Windows. The focused drag suite passed 40 assertions
and the tile suite passed 36 checks. Existing suites passed with zero failures:

| Suite | Assertions/checks |
| --- | ---: |
| Word Jelly model | 115,994 |
| Word Jelly view | 20,824 |
| Word Jelly flow | 797 |
| Word Jelly morphology model / view | 1,204 / 1,717 |
| Word Jelly hybrid tile / view | 584 / 57 |
| Word Jelly collection effects | 87 |
| Coin economy | 876 |
| Coin audio with eligible Lv2 collection | 152 |
| Word Jelly stage loading | 52 |
| Shared Jelly Match view / flow | 3,104 / 423 |
| Shared tile labels | 75 |

The Node host/test-runner checks passed 13 tests; the Web export/help suite passed
42 tests. `npm run build:web` completed successfully. The resource-pack validation
passed with all required audio and vocabulary resources present. Existing visual
assertions that intentionally observe intermediate pointer motion now advance a
zero-delta presentation frame;
release-before-frame coverage remains separate and unchanged.

The additional finish-confirmation suite ran 187 checks with two failures in
the raw controller Back cases, one in each Jelly mode. Its new Lv2 reward and
batch-collection checks passed. On this Godot runtime, `ui_cancel` maps Escape
but not controller B; the unchanged `game_ui.gd` input guard consumes B before
the controller-back handler. This controller issue remains outside the mobile
drag and coin changes. Evidence is in
`build/performance/jelly-finish-level-fixtures.log` and
`build/performance/controller-input-probe.log`. The successful supplemental logs
are `build/performance/coin-audio-level-fixtures.log` and
`build/performance/jelly-stage-loading-level-fixtures.log`.

### Browser behavior and visual checks

Seven focused Playwright cases passed against the rebuilt Web export, using one
worker and running separately from native tests and CPU measurements:

| Case | Browser profiles | Result |
| --- | --- | --- |
| Word/picture merge, responsive layout, hold, and Lv1 collection | Desktop Chromium, Android Chromium, iPhone WebKit, iPad WebKit | 4 passed |
| Lifting a supporting Jelly while retaining the held pointer | Android Chromium | 1 passed |
| Lv1 manual/batch collection, wallet, audio, offline playback, and mute | Desktop Chromium, normal and reduced motion | 2 passed |

The Android hybrid case dispatches real browser touch events through CDP and
checks touch pointer ownership. Other hybrid profiles use mouse-driven drag
input. These browser profiles run on the Windows host, not physical phones.

The first desktop and iPhone hybrid attempts reached successful merges and then
failed because the test left the intended Read dialog open after holding a
clipped word. The helper now checks and dismisses that dialog before collection;
both reruns passed without changing runtime behavior.

Desktop, Android, and the initial iPhone/iPad screenshots show the production
artwork and merged word presentation correctly. WebKit screenshots taken after
viewport resizing were blank beige. Post-resize interaction and layout-state
assertions passed, but those captures do not establish visual correctness.
Physical iOS Safari resize rendering and mobile frame pacing remain unverified.

## Runtime follow-up on 2026-10-27

The new full-board investigation starts at published commit
`93874d3f203f72901860a3188b836709a49cfc13`. Its source is frozen in
`build/performance/jelly-auto-baseline-93874d3f-20261027`; an exact 117-file Web
snapshot is retained in `build/performance/web-before-93874d3f`. The latter keeps
immutable, content-addressed binaries separately from the subsequently rebuilt
entry page. Neither snapshot creates a Git branch or changes the user's HEAD.

The implementation removes speculative complete-word construction from
read-only match checks, avoids allocating a combo snapshot for each availability
check, and coalesces callback-driven board refreshes/publications into the
current presentation frame. Wallet and learning signals retain their original
transaction boundaries. Hidden map diagnostics no longer rebuild all 99 node
rectangles during gameplay; the host only shallow-copies a fresh presentation
snapshot before assigning its top-level diagnostics.

Web UI scale queries share the browser pixel-ratio read within an engine frame,
refreshing it when the frame or window size changes. Ongoing matching hints
still animate their material uniforms, without reapplying constant rim feedback.
Neutral contacts do not repeatedly rebuild an unchanged picture shadow.
Automatic actions keep bodies disabled instead of enabling/disabling the entire
board on each pass. Serial pickups reuse one hidden, sourced visual shell;
expired visuals retire before the next pickup acquires it. Stop/round cleanup
releases that shell and its texture references.

### Measurements and limits

`word-jelly-auto-cpu-v1` adds two native headless scenarios: 35 real-art source
bodies for actual Auto Merge, and 35 ready Lv1-Lv9 bodies for actual Auto Collect.
It advances the normal model/view clocks, including intentional impact holds,
and includes host-copy/JSON work. Carried fragments are zero to isolate board
work from chest presentation. Raw per-frame action traces must match across
the frozen baseline and candidate. This is not GPU, browser or device FPS.

```powershell
node tools/benchmark-word-jelly-drag.cjs --automatic --baseline build/performance/jelly-auto-baseline-93874d3f-20261027 --label jelly-auto-paired --repeats 3 --samples 600
```

The opt-in `word-jelly-browser-intervals-v1` journey fills the real board through
normal preview controls. It measures desktop mouse dragging with 35 bodies,
Auto Merge with 35, and Auto Collect with 34 live bodies plus one manually formed
word. The native scenario separately covers the 35-target high-level batch.
Set `JELLY_PERF_LABEL` to enable it; ordinary browser runs skip this timing suite.
`JELLY_PERF_TRACE=1` captures a Chromium CPU profile and main-thread/GPU trace.
`JELLY_PERF_REPEATS` defaults to three; a one-repeat trace is diagnostic only.

The initial Windows-hosted Chromium 153 / SwiftShader mouse-drag observations,
with 1366x768 viewport, normal motion and no deliberate CPU/network throttling,
were:

| Version | P95 interval, three separate repeats | Median |
| --- | --- | --- |
| Frozen published Web build | 366.6 / 416.6 / 333.3 ms | 366.6 ms |
| Initial optimized Web build | 416.7 / 400.1 / 383.2 ms | 400.1 ms |

These observations **do not establish a rendered-frame improvement or a
60-FPS pass**. The shared host subsequently reported 100% CPU load. A diagnostic
trace was main-thread/WebAssembly dominated; the release engine has no function
name section, so its sampled Wasm indices cannot honestly be named as specific
GDScript methods. Native inclusive method timers support source-level
investigation, not a physical-device claim. A trial cross-frame static-body pose
cache was removed because its benefit was not established.

Raw CPU diagnostics are retained in
`build/performance/jelly-drag-runtime-before-20261027/`; the interrupted first
paired run is diagnostic and must not be presented as a completed paired
acceptance result. Chromium and Windows WebKit device profiles verify only the
available lab environment. Physical PC Chrome and iPad Chrome smoothness still
require an idle, representative device measurement. In particular, an iPad
viewport and WebKit user agent are not physical iPad performance evidence.

Logs, screenshots, traces, and audio evidence are retained locally under:

- `build/performance/browser-hybrid-20261022/` and its sibling `.log`
- `build/performance/browser-hybrid-rerun-20261022/` and its sibling `.log`
- `build/performance/browser-support-lift-20261022/` and its sibling `.log`
- `build/performance/browser-lv1-audio-20261022/` and its sibling `.log`

## PC runtime follow-up on 2026-11-03

The current board has seven columns and eight rows. The unchanged native
diagnostic now uses 21-body opening boards and 49-body crowded boards; the
18/42-body results above describe their historical versions, not today's geometry.

The runtime avoids constructing distant target contours during empty-space
dragging. A cheap face rectangle conservatively encloses the acquired skin and
its visual lift; only overlapping candidates proceed to the original exact
polygon intersection and distance/tie rules. Contact-point generation reads
the body's fixed pose once rather than calling native properties for every vertex.
Support-shadow geometry and purchase accessibility also skip unchanged inputs.

Return-space projection maintains counted occupancy as each copied body moves,
retaining overlapping fusion reservations and every original swept fall path.
An unobstructed, equally sized anchor is already the exact zero-distance return
destination and does not need a full-well nearest-slot search.

Stage-clock updates still refresh the actual timer and practice state. They no
longer publish another complete board snapshot outside the normal presentation
publisher. Goal, star, outcome, pause and explicit celebration changes remain
immediate. The browser bridge validates the native JSON and stores that original
text instead of serializing it a second time. Tool feedback follows the combined
pause reason, including the end of Ready; hover is not left internally paused
until the player manually pauses and resumes.

### Browser protocol

The opt-in protocol is now `word-jelly-browser-intervals-v2`:

- `JELLY_PERF_TILES` accepts 21, 28, 35, 42 or 49 bodies; its default remains 35.
- `JELLY_PERF_SCENARIOS` accepts comma-separated `idle`, `hover`, `drag`,
  `auto-merge` and `auto-collect`. The default remains the three action scenarios.
- `JELLY_PERF_REPEATS` defaults to three. `JELLY_PERF_TRACE=1` captures the first
  repeat's Chromium CPU profile and main-thread/GPU trace.
- Idle, hover and drag use four-second rAF windows. Hover first explicitly
  pauses/resumes and establishes a real active forecast; its window measures
  steady preview work, while the trace also retains the initial forecast.
- Each sample captures its final native state in the final rAF callback, not
  after transferring a potentially large trace. It records publication count,
  snapshot character count, renderer, DPR, long tasks and raw frame intervals.
  Raw samples are preserved before behavior assertions, including failed cases.

For the repository's desktop profile:

```powershell
$env:JELLY_PERF_LABEL = 'pc-crowded-runtime'
$env:JELLY_PERF_TILES = '49'
$env:JELLY_PERF_SCENARIOS = 'idle,hover,drag'
$env:JELLY_PERF_REPEATS = '3'
$env:JELLY_PERF_TRACE = '1'
npx --no-install playwright test tests\browser\word-jelly-performance.spec.cjs --project desktop-chromium
```

Use the same compiled source, harness, profile and conditions for a comparison.
The ordinary desktop profile advertises touch; the mouse-only PC lab used an
isolated `hasTouch: false` profile at 1366x768, DPR 1, normal motion, and no
deliberate CPU/network throttle. Its Chromium 153 renderer is Windows SwiftShader,
not the user's hardware GPU. Neither these rAF intervals nor the headless CPU
diagnostic establish real-user FPS, field INP, audio quality or physical-device
smoothness. Poor frame counts are retained as measurements, not rejected by
an arbitrary minimum-FPS behavior assertion.

### Native comparison and regression scope

Three independent native processes per version used the unchanged
`word-jelly-drag-cpu-v1` and `word-jelly-auto-cpu-v1` harnesses. Drag retained
30 warmup and 120 measured frames per case; automatic actions retained 1,200
measured frames so the 49-target Lv1-9 collection can actually finish.
Every per-frame interaction trace matched the published `80ba0f56` baseline.

Numbers below are medians of the three process means, in milliseconds per
manually advanced update. Parentheses show the range of those process means.
The drag row pools the four 49-body contact/motion variants within each process,
not unrelated inclusive method timers.

| CPU diagnostic | Before | After | Median mean reduction |
| --- | ---: | ---: | ---: |
| 49-body drag | 23.720 (22.724-25.279) | 11.314 (10.243-12.251) | 52.3% |
| 49-body Auto merge | 12.011 (11.754-23.302) | 6.713 (6.572-7.805) | 44.1% |
| 49-body Auto Collect | 6.674 (4.913-6.750) | 3.525 (3.306-4.374) | 47.2% |

These headless fixtures use the existing legacy cat setup and do not replace
the rendered, reviewed-morphology campaign journey. The exact projection oracle
also compared 1,200 mixed geometry/fusion/arrival cases against the original
algorithm, including checks that live cells never change.

The focused drag and tile checks passed, including bounded distant-contour
work, exact contact points, responsive shadows, clock-only publication, actual
star/goal changes and Ready-to-play hover restoration. The current native model,
campaign, Fill, falling contact, morphology, Auto merge capacity/forecast,
payment and shared Jelly Match checks passed.

Three additional legacy suites exposed existing failures: five Word Jelly view
assertions using obsolete impact/recovery expectations, one authored-drag
arrival assertion during full-board recovery, and twenty hybrid-view assertions
expecting the deliberately reusable charge shell to be freed. Each identical
failure set was reproduced against a frozen `80ba0f56` source snapshot; the
baseline authored-drag reproduction used its bounded `--quick` path. These
unrelated assertions were not relaxed or counted as passing, and this is not
a claim that the complete repository suite is green.

### Rendered Chromium comparison

The published baseline used `game-f5df45b25fc6738f.pck.br`; the fresh local
candidate used `game-e2d7f93460e4a939.pck.br`. Each scenario retained 49 live
bodies throughout all three four-second windows, the same browser/profile,
normal motion and unthrottled conditions described above. The first repeat
recorded a CPU/DevTools trace in both versions.

The table gives the median of each version's three window P95 rAF intervals.
Parentheses show the range of those three P95 values, not field percentiles.

| Rendered lab scenario | Before | After | Median P95 reduction |
| --- | ---: | ---: | ---: |
| Crowded idle | 266.6 (250.0-333.3) ms | 133.4 (133.3-166.7) ms | 50.0% |
| Auto merge hover | 216.7 (216.6-250.0) ms | 150.1 (133.4-183.3) ms | 30.7% |
| Crowded mouse drag | 483.4 (483.3-516.8) ms | 166.7 (166.7-200.0) ms | 65.5% |

Complete board publications fell from exactly two to one per sampled rAF
callback in every repeat; the diagnostic payload was retained rather than
discarding vocabulary or changing its output shape. The fresh browser journey
also preserved the exact hover-input/consumed-input match, paid six-output
capacity and overlapping 100 ms Auto merge launches. The bridge/export/runner
contracts passed 60 Node tests, and the source-pinned Pip review retained its
58 states and 334 performances.

The software-rendered lab still exceeds a 16.7 ms frame budget. These results
establish a substantial reduction under the stated local conditions, not
60 FPS on the user's actual PC, a hardware-GPU result or field INP. Artwork,
audio, effects, difficulty, saves and purchase rules were not reduced to obtain
the improvement. The candidate is local; this investigation does not deploy it.
