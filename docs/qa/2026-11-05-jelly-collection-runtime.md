# Jelly World full-board collection CPU

The target remains desktop Chrome at 1366 x 768 with 56 Jelly bodies, including
idle, dragging, merging and mixed-level Auto Collect. These changes reduce game
page CPU work. Physical 60 FPS acceptance requires the user's PC test; this
Hyper-V/SwiftShader environment has approximately 30 FPS empty-page cadence.

## Runtime changes

The collection model skips gravity sorting and footprint construction only
when an active batch reserves every live body. A fresh ID set observes edited
reservations, cancellation and new rounds. Any new unreserved body uses the
original gravity pass. Initial settlement checks borrow live scalar fields
synchronously; public cell accessors, snapshots and signal payloads retain
detached ownership.

Reveal fireworks calculate shared head and tail clocks once per burst group.
Float64 values preserve the original arithmetic order. Production textures,
trajectories, colors, clipping, particle budgets, stamp order and the public
trajectory helper remain unchanged. Audio and reward timing are unchanged.

## Native CPU evidence

Paired model experiments use the real nine-word, nine-level 56-body fixture,
alternate execution order and compare complete snapshots, native JSON bytes,
private continuation state and signal payload/order outside timing. Both the
linkage-only control and combined experiment passed 41,624 checks with no
normalization exclusions. All six timed collection trials completed 56 pickups
with zero skips.

Dense active model samples from two trials are pooled with equal sample weight:

| Scenario | Production mean | Candidate mean | Production P95 | Candidate P95 |
| --- | ---: | ---: | ---: | ---: |
| Normal collection | 1.127 ms | 0.542 ms | 2.418 ms | 1.359 ms |
| Initial falling | 2.755 ms | 0.921 ms | 8.374 ms | 2.135 ms |
| Later unreserved supply | 1.937 ms | 2.030 ms | 4.618 ms | 4.408 ms |

Normal and initially falling dense means fall by 51.90% and 66.58%. New-supply
mean rises 4.79%, with per-trial increases of 5.98% and 1.86%; behavior remains
identical. These samples do not isolate the cause of the slower fallback.

The paired reveal experiment checks exact attempted and fitted stamp commands,
texture identities and complete snapshot JSON over levels, budgets, layout,
clipping and effect boundaries. Each timed sample contains three draws through
the same scalar sink. Dividing each sample by three gives:

| Hero effect | Production mean per draw | Candidate mean per draw |
| --- | ---: | ---: |
| Lv4 manual | 1.723 ms | 1.215 ms |
| Lv6 manual | 4.793 ms | 3.301 ms |
| Lv9 manual | 7.225 ms | 4.856 ms |
| Lv9 batch | 4.486 ms | 3.030 ms |

The small 12-stamp secondary cases have little mean change and some higher P95
values. These CPU experiments exclude native draw submission and GPU work;
model, effect and preparation times must not be added as a predicted frame gain.

Raw evidence is under `build/performance/chrome-60fps`: the model linkage and
combined paired reports, `reveal-fx-group-clock-paired-v1.json`, and the pinned
arithmetic audit `collect-runtime-native-summary-v1.json` (SHA256
`f9bdad5c0b6bd52c18e133af0304a631ecadbd73741051a0ef96f0658a8749a3`).
The audit pins all four native input reports and reproduces their statistics.

## Unintegrated chest experiment

A Jelly-only closed reward shell tested skipping unseen treasure/magic
instances while retaining the full default content APIs. Its 44 warm native
preparations averaged 4.176 to 3.640 ms, but the graphical gate did not pass.
The original all-source exact test stopped at tier 8. A 240-pair tier-8 control
completed with 238 exact pairs and two stable single-pixel shading differences
in the same-class full/shell comparison; unchanged full/full controls were exact.

A separately recorded bounded all-source test required exact alpha and used
bounds, at most one changed RGB pixel, and maximum channel error 20. It stopped
at tier 9 after 125 pairs: 123 exact, one bounded, one rejected. The rejected
pixel had channel error 26. The original exact failures remain failures; the
bounded experiment is also rejected. No chest source, API or reward pool change
from this experiment is integrated. Its warm timing result does not establish
a browser or cold-allocation improvement.

The preserved reports are under `reward-shell-v1`: `paired-prepare-native-v1.json`,
`tier8-pixel-capture-v3-root-v1/report.json` and
`all-source-graphical-bounded-v4-root-v1.json`.

## Regression coverage

The new collection test passed 33,841 assertions, including callback coverage
guards, cancellation/new-round generation boundaries, original retained signal
payloads, exact reward/learning receipts and public ownership. The new reveal
test passed 391,949 checks over 624 draw cases and 204,940 attempted / 183,487
accepted stamps using independent archived arithmetic and draw-loop oracles.

Fifteen existing Godot suites passed: model, gravity, publication, collection
learning/effects, word reveal, interaction, authored drag, Auto Collect hover,
chest celebration/states/models/consumers, Pair rewards and queued upgrades.
The focused host, benchmark tooling and explicit test-runner Node suites passed
39 tests. Logs are `collect-runtime-new-tests-v1.log` and
`collect-runtime-regressions-v1.log` in the same ignored evidence directory.

## Browser and release validation

The unchanged 69ddd037 export is pinned by
`collect-runtime-baseline-reuse-audit-v1.json`; its 619 runtime/data/fixture
entries match that revision after CRLF-to-LF normalization. The frozen browser
runner, fixtures and delivered engine bytes are also pinned. A fresh baseline
capture uses normal motion/audio, DPR 1, eight excluded warmup seconds and no
GL auditing, tracing or CPU wrappers. All six baseline workloads passed;
mixed-level Auto Collect committed all 56 pickups with zero skips.

The first bare candidate comparison also passed all six workload checks. Both
mixed-level boards committed all 56 pickups with zero skips. Engine JavaScript,
WASM, worklets and decoded vocabulary packs match. The source audit permits
only the two reviewed runtime file changes; it pins both exports, captures and
the frozen runner in `jelly-collect-runtime-bare-v1-comparison.json`.

| First bare pair | Production process mean | Candidate process mean | Production engine FPS | Candidate engine FPS |
| --- | ---: | ---: | ---: | ---: |
| Ordinary idle | 16.13 ms | 30.26 ms | 10.93 | 9.24 |
| Merged idle | 26.41 ms | 32.06 ms | 8.75 | 8.13 |
| Ordinary drag | 28.73 ms | 31.91 ms | 8.92 | 8.58 |
| Merged drag | 34.04 ms | 42.09 ms | 7.33 | 6.75 |
| Merge | 16.91 ms | 17.40 ms | 11.40 | 11.32 |
| Auto Collect | 37.04 ms | 43.40 ms | 7.70 | 7.10 |

Dense Auto Collect (40..56 bodies with an active queue) process mean/P95 changes
from 52.43/123.1 to 63.08/150.0 ms in that pair. A fresh adjacent idle/collect
follow-up was run because the first pair showed slower candidate results even
in idle. Follow-up ordinary idle changes from 30.13 to 25.69 ms process CPU,
and 9.29 to 9.73 engine FPS. Whole Auto Collect changes from 44.53 to 50.65 ms
and 7.28 to 6.79 FPS. Dense collection changes from 72.90/165.9 to 68.37/155.5 ms
mean/P95, with adjacent dense interval FPS 5.69 to 5.84.

The follow-up captures are
`jelly-fps-collect-runtime-{baseline,candidate}-bare-v2-capture`. These sequential
software-renderer samples establish neither an overall collection FPS gain nor
physical 60 FPS acceptance. The cause of the slower whole-window candidate
results has not been isolated. Native local CPU savings must not be presented
as a demonstrated browser frame-rate improvement. Physical target-PC testing
remains required.

The standard production Web export passed startup resource validation, including
all required audio and acquired artwork. Its build receipt verified 14,127
source inputs and 117 output files. A headed Chrome smoke test of that actual
production export entered a real 56-body challenge at 1366 x 768, dragged a
settled top-row body and released above the board. All 56 bodies remained after
another 500 ms, input was released, the phase remained playing and browser errors
were empty. Evidence is `release-collect-runtime-smoke.json` and `.png` under
the same ignored QA directory.

Production delivery verification uses `release-collect-runtime-verify.cjs` to
compare exact online/local index and engine JavaScript bytes and require live
engine/WASM/game-pack resources. Its separate release report records the
deployed revision; physical full-board 60 FPS acceptance remains open.
