# Jelly Words drag performance

Five paired CPU diagnostic runs reduced mean drag-update time by 69.7%-90.2%
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

Logs, screenshots, traces, and audio evidence are retained locally under:

- `build/performance/browser-hybrid-20261022/` and its sibling `.log`
- `build/performance/browser-hybrid-rerun-20261022/` and its sibling `.log`
- `build/performance/browser-support-lift-20261022/` and its sibling `.log`
- `build/performance/browser-lv1-audio-20261022/` and its sibling `.log`
