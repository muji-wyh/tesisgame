# Native rendered-frame performance evidence — 2026-10-03

The completed five-pair, seven-scenario comparison met the predefined native
performance target: **12.63% less active rendered-frame wall time**, using the
equal-weight geometric mean of scenario ratios of pooled means. The ratio was
**0.873669**. Every paired repeat improved, and no scenario mean regressed by
more than 5%. These results describe this Windows **software renderer** and this
workload; they do not establish phone/Web FPS, hardware-GPU speed, or audio
latency. Functional and release validation are recorded below.

The [protocol](../performance.md) defines the measurement, acceptance rules,
source freezing, and reproduction commands. The committed
[compact evidence](2026-10-03-performance-evidence.json) retains exact results,
identities, collection order, workload diagnostics, and log warnings. Full raw
summaries, including all frame samples, are preserved as
[baseline JSON.gz](2026-10-03-performance-baseline.json.gz) and
[candidate JSON.gz](2026-10-03-performance-candidate.json.gz).

## Changes measured

- Voice Pop coalesces presentation updates and reuses style and text-layout data.
- Pip redraws discrete animation frames when their presentation changes while
  retaining continuous action motion.
- Talk Quest reuses word geometry and creature material data.
- The room caches its existing architecture artwork as a raster layer while
  Pip, toys, and their interactions remain live.

Normal sourced assets, motion, gameplay, and audio handlers remain active.

## Measurement and host

The actual main scene ran at 390 × 844 with production `canvas_items` / `expand`
stretch, normal sourced artwork, normal motion, a 60 Hz cap, and vsync disabled.
Each scenario used seed 73021, 90 warmup frames, and 240 measured frames per
repeat. Five fresh-process repeats per version yield 1,200 samples per scenario
and version, or 16,800 measured frames overall. Audio handlers remained enabled
with the Dummy audio device. Native transcript helpers supplied scheduled input;
microphone and network speech services were absent.

The primary span begins before scheduled input and main-scene processing and
ends at `RenderingServer.frame_post_draw`. It includes draw preparation and
rendering work before that signal; later frame-cap sleep is excluded. It is not
complete-frame CPU time or isolated GPU time. The process-only span is retained
as a secondary diagnostic and does not determine acceptance.

| Setting | Recorded value |
| --- | --- |
| OS | Windows, `win32`, release `10.0.26300` |
| CPU | AMD EPYC 7763 64-Core Processor; 16 logical CPUs exposed |
| Engine | Godot 4.7 stable official, `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88` |
| Rendering | GL Compatibility, `opengl3_angle`, Windows display server |
| Adapter | `ANGLE (Microsoft, Microsoft Basic Render Driver (0x0000008C) Direct3D11 vs_5_0 ps_5_0, D3D11-10.0.26100.9278)` |
| Collection | October 3, 2026, 00:03:47–00:12:59 Asia/Shanghai; October 2, 16:03:47–16:12:59 UTC |

## Results

Means and nearest-rank p95 values below pool all five repeats; times are in
milliseconds. Every scenario has equal weight in the headline, regardless of
its absolute cost.

| Scenario | Baseline mean | Candidate mean | Reduction | Baseline p95 | Candidate p95 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Match | 6.168 | 5.964 | 3.30% | 12.372 | 12.220 |
| Memory | 6.874 | 6.667 | 3.01% | 9.938 | 8.960 |
| Voice Pop | 16.219 | 11.263 | 30.56% | 25.563 | 18.976 |
| Talk Quest | 13.075 | 12.350 | 5.54% | 17.771 | 16.499 |
| Room | 9.242 | 6.067 | 34.35% | 13.029 | 9.459 |
| All words | 4.227 | 4.072 | 3.66% | 5.124 | 4.771 |
| Chest | 16.344 | 16.320 | 0.15% | 31.373 | 30.749 |

The headline time reduction is 12.6331%; its mathematical
throughput-equivalent speedup is 14.4598%, which must not be described as measured
FPS improvement. Small individual differences, especially the chest result,
should not be treated as separately established speedups from these five pairs.

| Pair | Serial collection order | Candidate/baseline aggregate ratio | Time reduction |
| --- | --- | ---: | ---: |
| 1 | Baseline → Candidate | 0.842505 | 15.75% |
| 2 | Candidate → Baseline | 0.878754 | 12.12% |
| 3 | Baseline → Candidate | 0.861054 | 13.89% |
| 4 | Candidate → Baseline | 0.908512 | 9.15% |
| 5 | Baseline → Candidate | 0.886668 | 11.33% |

"Every pair improves" refers to this seven-scenario aggregate. Individual
scenario pairs can regress: Memory pair 2 is 7.29% slower, for example. Quest's
pooled result is sensitive to pair 1, which improves 18.48%; pairs 2–5 improve
0.12–2.62%. As a descriptive sensitivity check, omitting any one pair leaves
the aggregate reduction between 11.74% and 13.46%. All five pairs remain in the
actual acceptance result; these checks do not justify selecting favorable runs.

The **separate paired estimator**, the geometric mean of these five pair ratios,
is 0.875210, or a 12.48% reduction. A deterministic 10,000-resample percentile
bootstrap of whole repeat pairs gives a **95% interval of 10.55–14.47% reduction**
for that paired estimator. It is not a confidence interval for the exact
12.63% headline estimator, which uses ratios of pooled scenario means. Frames
were not treated as independent bootstrap observations. Five pairs provide
limited precision, and requiring every pair to improve already makes a positive
percentile-bootstrap improvement expected.

## Workload audit and exposure limits

All ten runs have matching protocol, engine, host, rendering/audio configuration,
and harness/fixture hashes. All 70 scenario records retain 240 rendered and
process samples plus 239 frame intervals. Every scheduled action matches between
versions in all seven scenarios for each pair. All ten chest records begin in
`opening` without a `release` cue and finish `opened` with release recorded.
The audit found no configuration, action, sample-count, or source-identity
mismatch. It did find the physical-time limitation and teardown warning below.
Chest baseline repeats 1–3 have one additional `tension_pulse` before the sampled
interval; their complete ending cue sequences still match the candidate. This
is another small wall-clock phase difference, consistent with the protocol's
live animation behavior.

Voice Pop hits `swordfish`, `bird`, and `coat` at measured-frame indices 19, 120,
and 201, finishing with exactly three hits in every run. Talk Quest hits
`flower` and `chair` at indices 19 and 120, finishing with exactly two hits and
HP reduced from 5 to 3. Both retain real visible target artwork. Live-target and
drawn-target counts agree on every recorded frame, and the peak is one target.

Elapsed time below is the gameplay `after.elapsed - before.elapsed` value,
excluding warmup. Exposure counts are the number of the 240 measured frames
containing a live/drawn target. `B / C` means baseline / candidate.

| Pair | Voice Pop elapsed, s (B / C) | Voice Pop target frames (B / C) | Quest elapsed, s (B / C) | Quest target frames (B / C) |
| --- | ---: | ---: | ---: | ---: |
| 1 | 4.470 / 4.014 | 167 / 144 | 4.094 / 4.021 | 202 / 202 |
| 2 | 4.463 / 3.989 | 167 / 146 | 4.031 / 4.017 | 201 / 202 |
| 3 | 4.490 / 4.000 | 169 / 146 | 4.024 / 4.013 | 202 / 202 |
| 4 | 4.412 / 4.008 | 166 / 144 | 4.037 / 4.024 | 202 / 203 |
| 5 | 4.399 / 4.005 | 164 / 144 | 4.029 / 4.014 | 204 / 202 |

Voice Pop's baseline misses the 60 Hz cap more often: its mean frame-start
intervals are 18.360–18.730 ms, compared with 16.621–16.724 ms for the candidate.
It consequently advances further in physical time and exposes more target
frames. Baseline runs finish with one target; candidate runs finish in an empty
interval after the same third successful hit. The workload is therefore not
an identical sequence of physical-time animation samples.

As a diagnostic, condition on every sampled frame with `target_counts > 0`,
then pool those durations across repeats:

| Scenario | Included frames (B / C) | Baseline mean, ms | Candidate mean, ms | Reduction |
| --- | ---: | ---: | ---: | ---: |
| Voice Pop | 833 / 724 | 14.067 | 8.487 | 39.67% |
| Talk Quest | 1,011 / 1,011 | 13.278 | 12.546 | 5.51% |

This shows that the measured improvement remains when empty-target frames are
excluded. It does not isolate identical artwork positions or animation phases,
and it does not replace or adjust the predefined full-frame headline. The
fixed-frame result must retain this exposure caveat when cited.
Even Quest's equal pooled exposure counts do not mean exact frame alignment:
four of the 1,200 paired target-present indicators differ.

## Source identity and shared correctness repair

The original frozen baseline is commit
`f7c3caf1806af8f6ca1b533f950347fb6e06b24c`. The final baseline is a **new snapshot
of that commit plus the shared numerical sparkle fix**, applied using the
[recorded patch](2026-10-03-performance-baseline-sparkle.patch). The original
`build/performance/baseline-project` remains untouched. Comparing frozen file
hashes with final baseline hashes confirms that only `scripts/duck_mascot.gd`
changed. No candidate performance optimizations were backported.

The fix triangulates a unit-size star and applies its size and position through
the draw transform. It preserves the existing artwork and `radius > 0.01`
guard. The focused regression reproduced eight triangulation errors before
the repair and passed 79 checks in both headless and native runs afterward.

| Identity | SHA-256 |
| --- | --- |
| Final baseline runtime | `033cbf4605f267a48ef450225c1fddd03eede9141bf496e293c4d8f8b63801f1` |
| Candidate runtime | `5f995475ccc05ec474dbb05279a8b254a6b05e3908953b2c87498742ab756f19` |
| Combined harness and fixture | `5e486a3cd4055c2ccb59dd1cd89b644ff6855af9856853741bbf0398a1970cb1` |
| Baseline repair patch | `b06487b57ddbe66d65b72ccd6baa535379aee21c34ee20ae6546fc0118c38ac9` |

The candidate was an uncommitted working tree when measured; its recorded Git
HEAD is the same base commit and does not identify its contents. The runtime
fingerprint and per-file hashes in the raw summary are authoritative. The
runner verified source and actual-project harness/fixture identity before and
after every engine process and before writing summaries.

Assets, imports, and tests were shared junctions to the current workspace, not
frozen copies from the commit. The reports do not independently content-hash
all shared assets or imports. Preserve those inputs when reproducing; the
committed evidence archives contain measurements, not licensed assets or engine
imports. The original snapshot manifest and the patched runtime fingerprint use
different scopes/serialization and are not interchangeable hashes.

## Interrupted collections and warnings

`native-paired` stopped during candidate repeat 4 on the inherited tiny-star
triangulation error. After the candidate repair, `native-verified-paired` stopped
during baseline repeat 1 on the same original error. Neither incomplete matrix
contributes samples to this result. Their local raw reports remain available:

- [First interrupted candidate repeat](../../build/performance/native-paired-candidate/repeat-04.json)
- [Interrupted original baseline repeat](../../build/performance/native-verified-paired-baseline/repeat-01.json)

The runner rejected those engine processes before writing their `.log` files;
their stopping reasons were captured in the collection console. The new final
collection uses `native-stabilized-paired` and all ten completed reports.

No final log contains an engine `ERROR` or `SCRIPT ERROR`. All ten logs warn
that the driver falls back to ANGLE, consistent with their recorded adapter.
Candidate repeat 2 additionally reports **two ObjectDB instances leaked at
exit**, after all seven benchmark completion lines. Its samples remain in the
comparison; this is not a warning-free run. The same warning also appears in
the earlier original-baseline [diagnostic](../../build/performance/baseline-diagnostic/repeat-01.log),
[pilot](../../build/performance/pilot-paired-baseline/repeat-01.log), and
[interrupted collection](../../build/performance/native-paired-baseline/repeat-03.log),
so it is not unique to this candidate. Exact leaked types and the root cause
are not established by these measurements. Fresh engine processes prevent leaked objects
from persisting into later repeats, but this does not establish application
cleanup correctness.

## Validation and reproduction artifacts

| Validation | Status |
| --- | --- |
| Completed native performance matrix and evidence audit | Passed, with scope/exposure/warning caveats above |
| Focused tiny-star regression | 79 checks passed headless and native after reproducing eight errors before repair |
| Room cache pixel regression | 13 headless and 77 native checks passed; seven live/cache comparisons differ by at most 2/255 per channel |
| Gift adventure lifecycle regression | 130 checks passed after a test-only lifecycle correction; the original six failures reproduced on the stabilized baseline |
| Room navigation regression | 76 checks passed after updating the fixture for the existing age catalogue; the original two failures reproduced on the stabilized baseline |
| Broad Godot and Node regressions | 54 Godot suites and 270 Node tests across 17 suites passed; serial execution resumed after the two fixture corrections below |
| Talk Quest regressions | 14 Godot suites and 39 Node tests passed |
| Production Web export | Passed; 2,317 source inputs and 16 output files verified; game pack `47710e658eb5a104`, engine `9ce25b5d2f802dd7` |
| Browser functional and visual validation | Passed local smoke checks at 942 × 949 and 390 × 844; no captured console warnings or errors |

The final Web startup pack verified 350 pronunciations, 12 effects, and 230
required audio paths with no failures. Its compressed startup download is
31.65 MB. All 68 measured runtime source files remained byte-identical after
functional testing and export.

Browser checks exercised Match pairing, Memory card reveal, room entry and
return, live toy/Pip reaction, world-dependent room cache replacement, the
350-word age catalogue and scrollbar-free scrolling, Voice Pop entry/player
selection navigation, and the Talk Quest chapter map. Phone and desktop room
layouts rendered without missing architecture or artwork. The viewport override
was reset after testing. Local captures:
[room](../../build/performance/room-browser.png),
[catalogue](../../build/performance/catalog-browser.png), and
[quest map](../../build/performance/quest-map-browser.png).
Live microphone recognition and real speaker latency were not tested. Word
attacks, animated creatures, and chest release are covered by the native suites
and measured workloads rather than a new browser speech session.

The gift regression called `on_page_hidden()` without restoring
`on_page_visible()` before subsequent player actions. Restoring the missing
visibility transition in the test resolves the baseline and candidate failures;
it does not change runtime code, the benchmark harness, or the measured source
identity.

The room navigation fixture still expected an age choice to leave the room
uncovered. Age choices now open their vocabulary catalogue, so the first Back
correctly returns to the room. The fixture now checks that transition before
testing Back from the room to the game. This is also a test-only correction;
no navigation runtime changed.

Local source reports are the [comparison](../../build/performance/native-stabilized-paired/comparison.json),
[baseline summary](../../build/performance/native-stabilized-paired-baseline/summary.json),
[candidate summary](../../build/performance/native-stabilized-paired-candidate/summary.json),
[collection order](../../build/performance/native-stabilized-paired/collection-order.json),
[original snapshot manifest](../../build/performance/baseline-stabilized-project/baseline-source.json),
and [stabilization record](../../build/performance/baseline-stabilized-project/baseline-stabilization.json).
The `build/` files are ignored and may be absent in a clean checkout. The two
committed gzip files decompress to byte-identical original summaries; compressed
and uncompressed SHA-256 hashes are in the compact evidence JSON. Together the
compressed summaries occupy 167,369 bytes.

To reproduce the capture, follow the stabilized-baseline commands in the
[protocol](../performance.md#baseline-stabilization-on-2026-10-03). To inspect
archived measurements without rerunning an engine, decompress each JSON.gz to a
new local JSON file and compare them with `tools/benchmark-performance.cjs
--compare BASELINE_JSON CANDIDATE_JSON`. The comparator writes its result under
ignored `build/performance`; it does not launch an engine in comparison mode.
