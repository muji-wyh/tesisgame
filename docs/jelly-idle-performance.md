# Jelly World settled-board performance

The 2026-11-04 changes address crowded PC Chrome boards through shared settled
body rendering, dirty presentation updates and a bounded ambient animation cohort.
Physics, input dispatch, release resolution and gameplay clocks keep their
existing cadence.

## Runtime behavior

Settled bodies use the original acquired gel shader to paint a shared GPU atlas.
The cache retains the original contour, palette and static lighting. Pictures,
labels, support shadows and input rectangles remain separate. Contact, selection,
deformation, moving sheen, expanded completion light and geometry changes restore
the live material synchronously. Other Jelly Match consumers remain opt-in.

Each viewport has at most one 2048 by 2048 RGBA atlas: 64 cells, approximately
16 MiB before renderer overhead. At most two new states warm in a frame. Bodies
above 252 backing pixels in either dimension and capacity overflow keep the live
shader. Unleased entries can be reused; the atlas leaves the tree two seconds
after its final owner releases it. No frame-by-frame GPU readback occurs.

Word Jelly classifies the board after simulation, then updates changed or active
poses. Stable topology, palette, marks, hint eligibility, controls and ordinary
Boss overlays skip repeated work. Moving bodies receive their final resting pose
once before leaving the active set. Layout, theme, scale, reduced motion and
gameplay transitions invalidate the relevant presentation state. HUD clocks,
supply motion, collection effects and active Boss feedback retain their cadence.

Three eligible idle board owners animate. The cohort advances every 2.8 seconds,
introducing at most one new idle owner per rotation. Pointer hover, focus, held
bodies, contact, falling, hints and collecting
owners receive priority immediately. Frozen duplicates share a separate poster
wrapper, so another copy's animated atlas cannot animate them accidentally.
Posters and motion sheets retain the existing vocabulary artwork. Merged bodies
outside the cohort keep steady readiness accents while their sheen and glints
stop advancing. The seven supply slots and live fusion effects keep their motion.

The acquired gel source and license remain recorded in
[the Jelly asset inventory](assets/jelly-match.md). No artwork or audio was
replaced for this optimization.

## Reproducible CPU comparison

The baseline is committed source `1d2b4c24f0050f533361ff796c39c032605d45ac`,
frozen in `build/performance/jelly-idle-baseline-1d2b4c24-20261104`.
Assets, engine imports and the test harness are shared inputs; they must remain
unchanged during a pair. The runner fingerprints source and harness files,
alternates process order, retains raw samples and requires exact interaction
traces. Only one engine or browser workload runs at a time.

```powershell
node tools/benchmark-word-jelly-drag.cjs --idle --baseline build/performance/jelly-idle-baseline-1d2b4c24-20261104 --label jelly-idle-paired-20261104 --repeats 3 --samples 120
```

The idle fixture uses 21 and 49 production ordinary or merged bodies, a 1366 by
768 viewport, 60 warmup updates and a 60 Hz simulation. Merged fixtures explicitly
reconfigure the visible tiles after changing model composition. Timing includes
the shared WordArt clock and host snapshot copy/JSON serialization. The headless
cache takes the live fallback, so these results measure CPU/view savings only.
They exclude rendering, browser bridge execution, audio and physical PC FPS.

Godot 4.7.2 on Windows completed three independent process pairs, alternating
order, with 120 measured updates per case per process (360 samples per version
and row). All 12 paired idle traces matched exactly. Pooled timings are
milliseconds per manually advanced update:

| Bodies | Presentation | Before mean | After mean | Before P95 | After P95 | Mean reduction |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 21 | Ordinary | 4.063 | 2.466 | 15.147 | 10.982 | 39.3% |
| 21 | Merged | 4.460 | 2.719 | 14.008 | 11.529 | 39.0% |
| 49 | Ordinary | 8.844 | 4.279 | 37.643 | 18.198 | 51.6% |
| 49 | Merged | 10.597 | 4.974 | 41.835 | 24.647 | 53.1% |

Every paired case improved, but shared host load varied. For 49 ordinary bodies,
baseline process means ranged from 5.309 to 10.979 ms and candidate means from
3.323 to 6.136 ms. Merged ranges were 6.747–13.555 and 3.860–6.998 ms. This
diagnostic does not establish a sustained 16.7 ms frame budget: snapshot frames
still have higher CPU cost. Raw repeat timings are retained in the summary.

The unchanged drag protocol also completed three process pairs, 30 warmup and
120 measured updates per case. All 24 paired interaction traces matched. At
49 bodies the four empty/contact and one/four-motion cases reduced pooled
means by 28.0%–39.3% (9.482–10.794 ms before, 6.556–7.039 ms after). The raw
reports are in `build/performance/jelly-idle-drag-paired-20261104/`.

## Rendered verification

The native cache regression compares original and cached paint, recoloring,
merged rims, dimming and alpha. The first completed run on Godot 4.7.2 with ANGLE
Microsoft Basic Render Driver found a maximum channel difference of 1/255.
Additional checks cover live promotion, cache sharing, resizing, capacity,
bounded warmup, weak owner release and teardown.

The opt-in browser fixture is `tests/browser/word-jelly-idle-budget.spec.cjs`.
It uses the same authored campaign recipe and matches ordinary body counts and
type composition at 21 or 49 bodies, with normal motion. The recipe seed does
not seed `GameUI.new_round`: placement and word allocation remain randomized.
This browser comparison therefore measures equivalent workloads, with a layout
limitation, rather than the exact same boards used by the paired CPU protocol.
It records renderer, DPR, raw intervals, draw calls, exact board counts and
presentation diagnostics.

Chrome Canary 159.0.8140.0 on Windows completed two browser processes per version
at 1366 by 768, DPR 1, using ANGLE Vulkan SwiftShader. Each body-count case has
three consecutive 2.5-second `requestAnimationFrame` windows per process: six
windows per version and row. Process order was baseline, candidate, candidate,
baseline. The windows are not independent statistical samples. Pooled rendered
intervals were:

| Ordinary bodies | Before mean | After mean | Before P95 | After P95 | Mean reduction |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 21 | 71.004 ms | 69.013 ms | 83.4 ms | 83.4 ms | 2.8% |
| 49 | 100.541 ms | 78.229 ms | 116.7 ms | 100.1 ms | 22.2% |

Draw counts remained effectively unchanged at about 203 per frame for 21 bodies
and 294 per frame for 49 bodies. Candidate windows reported all 21 or 49 bodies
cached and three ambient animation owners. These results cover ordinary boards
at the fixed browser viewport; they do not establish rendered performance for
merged boards, other layouts or the user's physical PC GPU. Shared host load,
randomized layouts and software rendering limit generalization. The measured
intervals also remain well above a 16.7 ms frame budget.

The browser results describe these measured exports:

| Version | Measured Web pack |
| --- | --- |
| Baseline | `game-1d2aca9272516db8.pck.br` |
| Candidate | `game-4724ab7c284abc18.pck.br` |

`browser-provenance.json` records their exact compressed SHA-256 values and
export directories; `browser-summary.json` retains pooled and individual window
statistics. Both are under `build/performance/jelly-idle-implemented-20261104/`.
A subsequent candidate rebuild needs fresh validation before inheriting these
rendered measurements.

The final export is `game-517f0e427825c150.pck.br`. A resize follow-up marks all
existing bodies dirty before the final layout pose, including when layout runs
inside an already active presentation pass. This prevents stale visible positions
from disagreeing with model hit targets. Native checks cover all 49 bodies and
paused resizing. Final browser QA passed mouse input after a desktop-to-phone
resize and real CDP touch gestures on Android, including merge, exact grid
alignment, hold-to-read and collection. The final build differs from the measured
candidate in `scripts/word_jelly.gd` only; the rendered timing table above remains
specific to the earlier measured candidate, rather than a new final-build timing.

The baseline Web export, measured and final build receipts, measurements and
regression logs are retained under
`build/performance/jelly-idle-implemented-20261104/`. The preserved
`measured-word-jelly.gd` matches the measured receipt's source hash; the final
follow-up is recorded in `final-build-follow-up.json`. The frozen baseline source
and paired raw CPU results use the paths in the commands above.

## Focused regression scope

The checks below passed during this implementation. This is a focused regression
run, not a claim that the complete repository suite is green.

| Suite | Assertions/checks |
| --- | ---: |
| Ambient cohort and real-board lifecycle, including same-pass and paused resizing | 49 |
| Falling contact | 377 |
| Controls | 1,251 |
| Morphology view | 1,990 |
| Interaction, including neutral merged-partner drops | 4,110 |
| Auto merge permanent upgrades | 818 |
| Fill stream view | 145 |
| Collection effects | 170 |
| Boss application | 64 |
| Shared Jelly Match view / flow | 3,143 / 427 |
| Animated vocabulary | 4,949 |
| Tile performance and feedback | 506 |
| Rendered idle body cache | 28 |

Node benchmark/runner tests passed 19 cases; motion-inventory/runner checks
passed 11. The asset parity audit checked 6,660 existing non-import asset files
against the preserved release receipt and found no changed files.
