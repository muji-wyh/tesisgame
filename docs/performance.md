# Rendered main-scene performance protocol

The current protocol is `main-scene-rendered-v2`. It covers the Grow with Pip
curriculum and growth notebook; no v2 timing or performance improvement is claimed
by the workload migration itself.

The benchmark runs the actual main scene in a native Godot window using the GL
Compatibility renderer. The primary profile is a 390 by 844 phone-shaped window,
with the production `canvas_items` / `expand` stretch configuration, normal motion,
normal sourced artwork, and normal audio-event handlers. The audio device is Dummy;
the application is not muted. Browser microphone recognition and network speech
services are absent from this native measurement. Scheduled transcripts enter the
existing native gameplay helpers.

## Metrics and limits

The primary sample is the wall time from a process sentinel with priority
`-1000000` through `RenderingServer.frame_post_draw` in that same rendered frame.
It includes the scheduled input, the live scene's process callbacks, draw
preparation, and the renderer's work before that signal. Vsync is disabled and
the engine caps the actual run at 60 Hz. The frame-cap sleep after drawing is
outside the sample. This is **active rendered-frame wall time**, not isolated GPU
time, complete engine-frame CPU time, a phone benchmark, Web FPS, or audio latency.
Driver blocking and operating-system scheduling can affect it.

A second sentinel at priority `1000000` captures the **main-scene process span**
as a diagnostic. This excludes later redraw preparation and rendering and must
not replace the primary result. Raw process spans, rendered spans, and frame-start
intervals are retained per frame. The frame-start intervals include pacing and
help verify that the run was advancing in real time.

`Performance.TIME_PROCESS` is deliberately unused as a frame timer. In Godot 4.7
it publishes a maximum accumulated over approximately one second, rather than
the duration of the current frame. Repeatedly sampling that monitor would make
per-frame means and percentiles misleading. See
[Godot 4.7 main loop](https://github.com/godotengine/godot/blob/4.7-stable/main/main.cpp).

## Fixed workloads

Each scenario creates a fresh full main scene and isolated save files, uses seed
73021, then allows 90 warmup frames before recording 240 rendered frames. The
private Pip idle generator is also seeded after the scene is ready. The
scene is never manually advanced, frozen, stripped of artwork, or given reduced
motion during warmup or measurement. The chest fixture crosses the shared
celebration gate before warmup; chest charge and release then use their real
clocks. Startup/loading and result-file serialization are outside measurement.
The six default scenarios receive equal weight:

| Scenario | Presentation and scheduled input |
| --- | --- |
| Match (`match`) | Ten cards from the seeded Lv3 curriculum, Spring theme; two successful word-picture pairs at 8% and 50% of the measured interval. |
| Memory (`memory`) | Ten cards from the same seeded lesson; two successful pairs with a 15-frame gap between reveals; a brief held study peek. |
| Voice Pop (`voice-pop`) | Actual listening/running state, wall-clock target movement, transcript feedback, and three scheduled hits on the first live target. |
| Growth notebook (`growth`) | The 80-word Lv3 cohort; browse age 4, return to age 3, then hear its first card. Browsing and listening must leave learning progress unchanged. |
| Age catalogue (`catalog`) | The 284-word age-7 preview cohort in five pages of at most 60 cards; focus, scroll, pagination, and pronunciation at the first, middle, and last card. Only pictured words retain image textures. |
| Chest (`chest`) | A real Match win and continuous chest hold after the celebration gate; the hold begins during the final 60 warmup frames so measurement includes charge, release, and reward presentation. |

Talk Quest and its map diagnostic were retired on 2026-10-06. Protocol v2 replaces
the retired room scenario with the growth notebook and the full-library catalogue
with an explicit age cohort. The current six-scenario matrix must be used for
both baseline and candidate. Archived v1 and seven-scenario results remain evidence
for their original revisions and cannot be compared directly with this aggregate.

State assertions reject an open game menu, a paused page, inactive gameplay,
missing word hits, incomplete card boards, an incomplete catalogue, and a chest
that has already opened or reached its release cue before measurement, or never
reaches release during measurement. Voice Pop requires exactly three hits after
measurement, including diagnostic runs. Visible controls must retain nonzero layout;
Voice Pop must retain its visible HUD and start with live drawn targets. Its
raw live-target and drawn-target counts are recorded alongside every timed sample, with total active-frame counts
and peak counts. At least one quarter of measured frames must contain live and
drawn targets; successful hits must also be recorded. This allows a legitimate
empty interval between volleys at the end of measurement. The growth notebook
must retain its catalogue, Lv3 summary, expected cohort, and unchanged progress.
Age-catalogue assertions verify all 284 words, pagination, actual pictured-resource
counts, and unchanged progress. Evidence collection occurs after the timing
endpoint; workload assertions run outside measurement. The JSON records state before and after,
scheduled actions, node/object counts, engine version, graphics adapter, render
backend, display size, and pacing settings. All save paths are assigned before
the corresponding scene's `_ready`; run-owned files are removed afterward.

The fixed frame count does not guarantee identical wall-clock exposure. Voice Pop
uses the wall clock for target motion, and inputs are scheduled by frame index. A baseline that misses the 60 Hz cap can
take longer than the candidate to render the same 240 measured frames. Targets
can then occupy different positions or remain visible for different numbers of
frames, and animation phases can differ even when the hit words and scheduled
actions match. Inspect and report elapsed durations, frame intervals, actions,
and live/drawn-target exposure for each version before interpreting the result
as equal-work improvement. A conditional mean over frames with at least one
target is a useful additional diagnostic when exposure differs; it does not
replace the primary full-frame mean. The runner records exposure but does not
automatically prove workload equivalence. This protocol cannot claim identical
physical-time animation samples between runs.

## Running and comparing

Only one engine instance should benchmark at a time. Keep the machine's power
mode, other workloads, window visibility, and graphics configuration consistent.
Do not interact with the benchmark window during collection. Run five repeats
for each version; a one-repeat diagnostic is useful for validating the harness
but is not an acceptance result.

Run a single diagnostic with all six workloads and the full timing window:

```powershell
node tools/benchmark-performance.cjs --label growth-v2-diagnostic --repeats 1
```

Use a fresh label for later runs to preserve earlier diagnostic files. Keep the
default 90 warmup and 240 sample frames for this smoke check; a shorter chest
sample can end before the real release cue and correctly fail its assertion.

First freeze the chosen source commit into a new directory:

```powershell
node tools/freeze-performance-baseline.cjs --ref HEAD --output build/performance/baseline-project
```

The tool defaults to `HEAD` and an output name containing its resolved commit.
It copies tracked `scripts`, `scenes`, `data`, `project.godot`, `words.json`,
`phrases.json`, `curriculum.json`, and `voice-prompts.json` directly from Git
blobs as buffers, preserving committed
bytes and excluding uncommitted runtime changes. `baseline-source.json` records
the exact commit, original Git blob IDs, per-file SHA-256 hashes, and a source
tree fingerprint. It always refuses an existing destination, an output outside
`build/performance`, or a linked parent directory. It never deletes or replaces
files; a partial snapshot after an error remains available for inspection.

The snapshot links the current `assets`, `.godot`, and `tests` directories using
Windows directory junctions or directory symlinks on other platforms. Their
absolute targets, mutable status, and current harness hashes are recorded.
These references are shared inputs, not frozen asset/import copies: keep them
unchanged during comparison. The tool does not archive licensed source assets
or run the engine. Choose a different new output directory if the example
destination already exists.

Then collect the paired matrix:

```powershell
node tools/benchmark-performance.cjs --paired --baseline-project build/performance/baseline-project --label native-paired --repeats 5
```

The paired command runs baseline then candidate for odd-numbered pairs and
candidate then baseline for even-numbered pairs. Engine processes are strictly
serial. Each version gets five fresh-process repeats. Raw reports and summaries
are saved in `native-paired-baseline` and `native-paired-candidate`; the
chronological collection manifest and comparison are in `native-paired`.

Separate collection and later comparison are also available:

```powershell
node tools/benchmark-performance.cjs --label baseline --project build/performance/baseline-project --repeats 5
node tools/benchmark-performance.cjs --label candidate --repeats 5
node tools/benchmark-performance.cjs --compare build/performance/baseline/summary.json build/performance/candidate/summary.json
```

`--project` allows a frozen baseline checkout to share the same imported assets
and harness. Use byte-identical asset inputs and the same Godot executable for
both projects. Use the paired command to reduce order bias from thermal or
background-load drift. Separate collection must disclose its collection order;
ratios paired by repeat index alone do not establish interleaved execution.
Do not edit either measured runtime or the harness during a run. The runner
verifies the actual selected project's `tests/performance/main_scene_benchmark.gd`
and `tests/godot/player_flow_fixture.gd` against the root project's copies, then
freezes a combined fingerprint of both files. This also detects changes to
shared junction targets after collection starts. Runtime hashes include the
curriculum, phrase library, and Pip growth-stage data. Runtime and protocol hashes
are checked before and after every engine process, as well as before summaries
are written. Summaries retain both the combined harness hash and per-file hashes.

Optional flags are `--scenarios`, `--width`, `--height`, `--warmup`, `--samples`,
and `--seed`. The default protocol uses the values specified above. Shorter or
smaller diagnostic configurations must not be presented as the primary result;
the comparator marks them ineligible for the primary acceptance target.
`GODOT_BIN` selects the engine binary through the existing Godot runner.

Reports and logs go to ignored `build/performance/<label>/`, never `build/web`.
Each repeat keeps every raw microsecond sample. `summary.json` contains pooled
per-scenario means, nearest-rank p50/p95, per-repeat means, and source SHA-256
fingerprints. Runtime source and harness fingerprints are checked again after
collection. A copied baseline can reside inside another Git checkout, so the
content fingerprint is authoritative and the nearby Git HEAD is informational.

### Historical baseline stabilization on 2026-10-03

This subsection records the former seven-scenario comparison. Reproducing it
requires its original runtime, assets, and harness from that revision; these
commands are not the current six-scenario setup.

The first `native-paired` collection stopped during candidate repeat 4 because
Pip's tiny reaction stars triggered an inherited polygon-triangulation error.
After the candidate fix, `native-verified-paired` stopped during baseline repeat
1 with the same original error. These interrupted collections are retained for
diagnosis and are not acceptance results. The original `baseline-project`
remains untouched.

The shared correctness fix triangulates a unit-size star and applies its size
and position through the draw transform. It preserves the artwork and existing
`radius > 0.01` guard. The regression reproduced eight errors before the fix;
the fixed implementation passed headless and native validation. A separate
baseline receives only this identical numerical fix; no candidate performance
optimizations are backported. Reproduce it from the repository root:

```powershell
node tools/freeze-performance-baseline.cjs --ref f7c3caf --output build/performance/baseline-stabilized-project
git apply --directory=build/performance/baseline-stabilized-project docs/qa/2026-10-03-performance-baseline-sparkle.patch
node tools/benchmark-performance.cjs --paired --baseline-project build/performance/baseline-stabilized-project --label native-stabilized-paired --repeats 5
```

Use a fresh output directory if that baseline already exists. The recorded
[patch](qa/2026-10-03-performance-baseline-sparkle.patch) touches only Pip's star
drawing. `baseline-source.json` identifies the original frozen commit; the
benchmark summaries identify the actual patched runtime and common harness by
their hashes. Report final results against **`f7c3caf` plus this shared numerical
fix**, not against the untouched commit or the interrupted collections.

## Acceptance and reporting

For each scenario, pool all measured frames across repeats, then calculate the
candidate mean divided by the baseline mean. The headline aggregate is the
equal-weight geometric mean of those six ratios of pooled means. Report
`100 * (1 - aggregate)` as the reduction in active rendered-frame wall time.
The throughput-equivalent speedup is a different number and is reported
separately. A successful target requires at least five repeats, the complete
six-scenario matrix, a reduction of at least 10%, and no individual scenario's
mean regressing by more than 5%. Every paired repeat must improve.

The interval describes a separate estimator: first calculate the equal-weight
geometric mean of the six scenario ratios within each repeat pair, then take
the geometric mean across pairs. This paired estimator generally differs from
the headline aggregate of ratios of pooled means. A deterministic 10,000-resample
percentile bootstrap computes its 95% interval by resampling whole independent
baseline/candidate repeat pairs, never individual frames. Do not present that
interval as a confidence interval for the exact headline estimator. It is a
separate check of repeat-level consistency and must support an improvement for
acceptance. The headline 10% requirement is a point-estimate requirement. Only
claim at least 10% for the paired estimator's entire interval if its reported
lower bound reaches 10%. Five pairs provide limited precision; the requirement
that every pair improves also makes a positive percentile-bootstrap improvement
expected. Retain and show the interval and all paired ratios.

Show every scenario's mean and p95, the collection order, and each repeat's
aggregate ratio. Never omit an unfavorable scenario, substitute a process-only
hotspot result for the full matrix, or describe this metric as an equivalent
increase in phone/Web FPS. Compare rejects differing harnesses, protocol
configurations, hosts, engines, and renderer settings. Functional and visual
regression checks remain necessary alongside a performance result.

The current Windows environment identifies its graphics adapter as
`ANGLE (Microsoft, Microsoft Basic Render Driver ... Direct3D11 ...)`, which is a
software renderer. Results collected here must explicitly state that fact. They
can establish a repeatable improvement on this native software-rendered workload,
but cannot establish a hardware-GPU or mobile-browser performance improvement.
The comparator records the full adapter string and labels recognized software
adapters in its result and scope description.
