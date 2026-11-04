# Jelly Words drag performance

The later [settled-board implementation and validation](jelly-idle-performance.md)
covers shared gel rendering, dirty updates and the ambient animation budget.

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
the improvement. This measurement did not include deployment verification.

## Crowded-board follow-up after the upgrade release

This follow-up compares the published upgrade release `4fb89958` with the local
performance changes on 2026-11-03/04. It targets the user's report that PC Chrome
slows as the board fills. The exact source baseline is retained in
`build/performance/jelly-pc-baseline-4fb89958-20261103`, and its Web export in
`build/performance/pc-chrome-20261103/web-baseline`. These are snapshots, not Git
worktrees. The production baseline uses `game-61ebbcc49e5e9ceb.pck.br`.

### Runtime changes

Toolbar availability shares one read-only result across the powerup and word-goal
controls. Its key tracks legal geometry, composition, settled state, vocabulary
revision, levels, rules and Boss restrictions, without copying repeated artwork,
audio or editorial records. Activation and payment still perform a fresh plan.

Merge feedback shares a conservative occupied-area bound within one presentation
pass. When this proves that a one-cell destination exists, feedback skips repeated
full occupancy and nearest-slot searches. Full or uncertain boards retain the
original exact solver, and semantic compatibility and freeze checks always apply.
Unchanged empty Boss overlays and hidden Home diagnostics skip redundant work.

The gel shader skips zero-strength effects while retaining the original math for
active effects. A prototype cached sky projection was investigated and removed:
the isolated same-page comparison did not establish a useful frame-time benefit.
The final runtime retains the original sourced panorama projection and motion.

### Paired native CPU result

Three independent process pairs alternate baseline/candidate order, with 30 warmup
and 120 measured updates per case. All eight per-frame interaction traces match.
The table gives pooled means for the four 49-body cases, in milliseconds per
manually advanced update. The isolated fixture has no sky backdrop, so this
measurement covers retained CPU/view changes and excludes rendering.

| Path | Motions per update | Before mean | After mean | Reduction |
| --- | ---: | ---: | ---: | ---: |
| Empty space | 1 | 16.716 | 13.328 | 20.3% |
| Empty space | 4 | 15.720 | 13.751 | 12.5% |
| Contact | 1 | 16.002 | 13.421 | 16.1% |
| Contact | 4 | 16.232 | 13.196 | 18.7% |

Raw samples, source/harness hashes, interaction traces and engine logs are in
`build/performance/jelly-pc-paired-20261103/`; `summary.json` contains the aggregate.
An additional single-process authored 49-body availability diagnostic reduced
query means from 664 to 370 microseconds at stage 1 and 749 to 379 microseconds
at stage 99. That diagnostic is not a rendered frame-time measurement.

### Regression scope

The powerup-cache suite passed 140 checks, the feedback-space oracle 1,089, the
tile performance suite 506, and the hidden-library publication suite 10.
Existing focused drag, falling-contact, Auto Merge upgrade, controls and
morphology checks also passed.

The Boss view suite has five ending/victory dialogue failures among 44 checks.
The identical failures were reproduced against frozen `4fb89958`; they were not
relaxed or counted as passing. This is not a complete repository-suite pass.
Focused logs and browser evidence are retained in
`build/performance/pc-chrome-20261103/`.

A later broad coin-flow run passed 462 of 473 checks and failed eleven
`Combo 2..12 persists its exact reward once before presentation` assertions.
The unchanged combo-only fixture reproduced all eleven failures against frozen
`4fb89958` (97 checks). It expects the displayed combo level to equal action
number, whereas both versions use progressively increasing action requirements.
The production combo behavior and original test were not changed. Evidence is
in `coin-combo-baseline.log` and `coin-combo-audit.md` in the same directory.

### Rejected sky-cache prototype

The experimental export uses `game-937f8777b6589d82.pck.br`, retained separately
in `build/performance/pc-chrome-20261103/web-final-r2-measured`. Both versions used
the same Chromium 153 mouse-only profile at 1366x768, DPR 1 and normal motion,
with no deliberate CPU or network throttle. The Windows Hyper-V host reports
an AMD EPYC 7763 and the ANGLE Vulkan SwiftShader software renderer. Unrelated
host CPU load remains present. Only one engine/browser performance workload ran
at a time; no build ran during these browser samples.

Each row is one four-second window per version, not a repeated statistical
acceptance result. Every window starts and ends with 49 live bodies, 49 generated
tiles and zero merges. The frame counts are retained rather than hidden by a
minimum-FPS assertion.

| Scenario | Before P95 | After P95 | P95 change | Before/after samples |
| --- | ---: | ---: | ---: | ---: |
| Crowded idle | 150.1 ms | 116.7 ms | -22.3% | 31 / 37 |
| Auto Merge hover | 150.1 ms | 166.6 ms | +11.0% | 30 / 30 |
| Crowded mouse drag | 216.7 ms | 183.4 ms | -15.4% | 20 / 26 |

All three browser behavior cases passed. Hover did not improve in this window:
its median interval remained approximately 133.3 ms while its P95 increased.
The earlier `pc-final-r1` prototype kept using the direct sky fallback. The later
prototype's completion callback explicitly disabled the one-shot viewport and
selected its texture, without waiting for the node's stored update-mode getter
to reset. Its regression began from the retained one-shot state. Both prototypes
were rejected; these callback and viewport changes are absent from production.

Raw intervals, final native states,
screenshots and Chromium profiles/traces are retained in `pc-baseline-4fb89958/`
and `pc-final-r2/` under the evidence directory above. `candidate-r2-provenance.json`
records the measured pack and build-receipt source hashes. A separate draw-suppression
diagnostic found that rendering/submission/driver work dominates the remaining
idle lag in this lab; its raw data and limitations are in `render-diagnostic.json`
and `render-diagnostic-notes.md`.

The experimental Web build completed with its input/output receipt and pack checks.
A separate rendered visual journey compared reduced-motion desktop, portrait
and restored-desktop screenshots with the original projection. Exposed-sky RGB
RMSE was 0.454 on desktop and 0.480 in portrait, with maximum channel differences
of two and one levels respectively. The normal-motion journey retained 49 bodies
and no runtime/shader errors. Captured WebGL programs confirm 415 cached sky draws,
three one-time bakes at 1602x886, 490x892 and 1602x886, and only three direct
fallback frames. Motion resumes without further baking. Images, pixel comparisons
and the visual findings are in `render-visual-qa/`; the passing final log is
`render-visual-qa-r2.log`.

### Experimental consecutive-window cross-check

A trace-free follow-up sampled three two-second windows each for idle, hover and
drag on one fixed authored board per export, rotating the scenario order. Baseline
and candidate ran sequentially, with one active browser and no build or native
workload. All 18 windows retained 49 bodies, 49 generated tiles, zero merges and
the 60-second replay cadence. Each window contains only 11-17 intervals; these
are consecutive windows, not independent process replicates or significance tests.

| Scenario | Before pooled mean | After pooled mean | Mean change | Before/after pooled P95 |
| --- | ---: | ---: | ---: | ---: |
| Idle | 123.33 ms | 128.46 ms | +4.2% | 133.4 / 150.0 ms |
| Hover | 130.84 ms | 137.03 ms | +4.7% | 150.0 / 150.1 ms |
| Drag | 162.28 ms | 177.14 ms | +9.2% | 183.3 / 183.4 ms |

This cross-check does not confirm a consistent rendered improvement. The baseline
itself sped up across its consecutive idle and drag windows, so warmup, sequential
order and shared host load remain confounders. All positive and negative windows
are retained in `repeated-window/{baseline,candidate,summary}.json`. The first
partial attempt exceeded the replay's spawn cadence and changed board size; it
is retained as `invalid-first-baseline.json` and excluded for that fixture failure.

Native CPU work is reduced, but the current Chrome lab does not establish a
consistent FPS improvement or a result on the user's actual PC GPU. Physical PC
Chrome frame pacing remains unverified. Release status is tracked separately
from these measurements.

A final isolated same-page sky test alternated four direct and four cached
four-second windows at fixed lighting and full physical resolution. Both paths
had approximately 33.3 ms median and 33.4 ms P95 intervals. Pooled means differed
by only about 1%. The shader-use hooks verified one sky and seven garden draws
per frame, no rebakes, and exclusive use of the requested shader. This did not
justify retaining the extra cache implementation; the source and test changes
were removed. Raw evidence is in `sky-render-fixture/measurement.json`.

### Rejected MSDF caption prototype

A valid isolated fixture compared the original hinted Nunito captions with a
copied MSDF font on 49 production JellyTiles at 12–28 pixels. MSDF reduced draws
from 156 to 147 per frame, but P95 stayed at 66.7 ms and mean intervals did not
improve. Small caption outlines developed light cuts and distorted edges, even
with an increased distance range. The first font switch also took approximately
617 ms. An earlier apparent 49-draw reduction used a fixture with a missing gel
shader include and is invalid. No font changes were retained. Evidence and the
caption comparison are in `sky-render-fixture/findings.md` and
`sky-render-fixture/font-small-caption-comparison.png`.

### Continuous upgrade feedback

The hold control no longer allocates flying-coin records or redraws their paths.
Ordinary paid receipts avoid rebuilding the page layout and rail styles, and
successful contributions no longer refresh the hidden game and Home controls.
The wallet retargets one continuous count envelope; the rail preserves velocity
while moving to saved progress, with a bounded 120 ms finish before a committed
level's effect and sound. Button and wallet feedback reuse the acquired local
glow/glint textures. One continuous audio voice acknowledges the hold, with a
short release envelope; quieter debit sounds reuse the bounded coin voice pool.
These are interaction-specific changes, not evidence of improved crowded-board
Chrome frame pacing.

Focused upgrade validation passed: view 217 checks, audio/input lifecycle 66,
contribution coordinator 46, and first-clear journey 36. Existing coin audio
passed 152 checks. Chest presentation passed 249 headless level checks, 264
rendered checks, 7,655 choreography assertions and 859 queued-settlement checks.
A 5.6-second native Movie Maker capture exercised two holds with real isolated
wallet/campaign receipts: the display never increased, changed on 159 recorded
frames, and the 14 ordinary debits caused only two layout changes at a level or
preview transition. The engine-mixed peak was -11.6 dBFS. Capture, event/frame
samples and screenshots are in `build/qa/jelly-upgrades/`; this fixed-time render
does not establish real-time frame pacing or physical speaker quality.

The initial local Web pack `game-a7c9742331c0da76.pck.br` passed desktop 1366x768 and
portrait 393x852 browser charging checks. Both verified no flying coins,
continuous local feedback, an intermediate displayed wallet balance, stable
layout during ordinary contributions and no spending after release. The final
build receipt verified 13,920 source inputs and 117 output files. Additional
view checks cover release/repress during a milestone and retain the earned
preview until its effect finishes.

### Production release verification

Runtime commit `a8272740` was published on 2026-11-04 from an isolated copy of
tracked source with the existing reviewed private build inputs restored by hash.
The release omits the unrelated local Atelier chest library. Its source receipt
and parsed startup pack contain no Atelier source files, direct resources or
matching imported resources.

Release pack: `game-c40f8539e941fccd.pck.br`, 39,944,961 compressed bytes. Core
startup is 47.10 MB, about 9.07 MB smaller than the initial local export. The
deployment verified 13,768 source inputs and 117 output files before publishing.

Both local release checks and both production checks passed at desktop 1366x768
and portrait 393x852. Production HTML and actual browser pack requests matched
the release hash. The checks verified charging feedback, smooth displayed
debits, zero coin flights, stable contribution layout and no spending after
release. Both sizes use mouse-held charging; portrait navigation uses touch.
The browser helper falls back to mouse when the OS exposes touch points but
the test context disables touch, preserving other input failures.

Production: <https://gentle-forest-02ff42900.3.azurestaticapps.net/>. Release
receipts, exclusion proof, deployment log and browser captures are retained in
`build/qa/jelly-upgrades/`. This release does not establish physical-PC Chrome
frame rates or subjective audio quality.
