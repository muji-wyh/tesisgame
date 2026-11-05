# Jelly UTF-8 bridge scan

This change targets the remaining full-board Jelly World game-page CPU cost at 1366 x 768. The acceptance goal is physical desktop Chrome at 60 FPS with 56 Jelly bodies during idle, dragging, merging and collection. The diagnostic results below isolate one engine string-conversion bottleneck; they do not establish that FPS target. Game map presentation is unchanged.

## Bottleneck and solution

The fine drag profile transfers a complete hosted JSON snapshot of approximately 377,624 characters. Timing only `wordBuddiesHost.jellyStatus` initially missed most bridge cost: native argument conversion and JavaScript UTF-8 decoding occur before that method runs. A second diagnostic patched the generated engine wrapper to time native conversion, `variant2js`, lock release, the original JavaScript method call and result conversion separately.

The original Emscripten `findStringEnd` advances through every byte in a JavaScript loop before `TextDecoder.decode`. For the ordinary unbounded `HEAPU8` string path, this scan dominated `variant2js`. The production export patch replaces that case with captured intrinsic `Uint8Array.prototype.indexOf(0, idx)`.

The fast path requires an undefined byte bound, falsy `ignoreNul`, an integer index at or above zero and below the intrinsic view length, a genuine `Uint8Array`, and attached ordinary `ArrayBuffer` storage. Captured typed-array tag, length and buffer getters enforce actual brands and ignore shadowed properties. A captured `ArrayBuffer` byte-length getter rejects shared storage even after prototype changes. A missing NUL returns the actual view length; an immediate NUL returns the original index, preserving negative zero. Original bound arithmetic, the `ignoreNul` return and the fallback loop retain their order and behavior for all other cases.

`tools/patch-web-engine.cjs` requires the exact original initializer exactly once, so template drift fails packaging. The unchanged packager fingerprints the patched engine and emits its matching Brotli sidecar. Full native and hosted JSON, synchronous complete `data-jelly` assignments, publication cadence, base deduplication, detached snapshots and `serialized_changed` before `changed` are retained. No fragment transport or encoder change is included.

## Instrumented bridge evidence

V2 uses the original scanner, V3 is the initial `instanceof`-guard experiment, and V4 uses the strict intrinsic brands above. Each copies `build/performance/jelly-fps-7c539-drag-profile-v2/web` without rebuilding and retains the same host and bridge phase profilers. The runner is unchanged. Captures use headed Chrome 159.0.8140.0, 1366 x 768, DPR 1, eight seconds of excluded warmup, normal motion/audio and no GL auditing.

Mean milliseconds per bridge call:

| Phase | V2 | V3 | V4 |
| --- | ---: | ---: | ---: |
| Native argument conversion | 1.381 | 1.400 | 1.054 |
| Lock read and `variant2js` UTF-8 conversion | 6.034 | 0.459 | 0.420 |
| Conditional lock release | 0.006 | 0.002 | 0.000 |
| Original JavaScript host call | 1.685 | 1.618 | 1.441 |
| Result conversion | 0.000 | 0.002 | 0.002 |
| Timed wrapper total | 9.113 | 3.493 | 2.931 |
| Calls / process frames | 53 / 51 | 56 / 54 | 59 / 57 |

V4 retains approximately 93% lower decode-phase time than V2, saving 5.614 ms per call in that phase. Its corresponding per-process-frame phase mean is 0.435 ms, compared with 6.271 ms in V2. Native conversion and the original JavaScript call also drift lower in V4; their changes and the entire wrapper/FPS difference must not be attributed to the scanner.

These are instrumented diagnostic captures, not bare acceptance runs. Wrapper timing starts after object/method lookup and ends before the sample-array push; engine timing includes additional work. V4's approximately 28 FPS empty-page cadence and 7.02 engine FPS do not establish physical game performance or a scanner-attributed FPS improvement.

Raw captures are `build/performance/jelly-fps-7c539-host-bridge-profile-v{2,3,4}-capture/drag-merged-1.json`. Adjacent helper manifests under `build/performance/chrome-60fps` pin source, copied and patched index/engine bytes, compressed and decoded engine bytes, and unchanged runner hashes. The read-only aggregate is `build/performance/chrome-60fps/host-bridge-v2-v3-v4-phase-summary-v1.json`; it also pins its source captures and manifests. Prepared V3 evidence retains its original weaker guard; V4 supersedes that guard for production.

## Rejected and deferred runtime experiments

`build/performance/chrome-60fps/dynamic-record-cache-transition-paired-v1.json` alternates production and the ignored dynamic-record prototype in one headless native process. Timed sections include complete base and host encoding, with native byte parity checked outside timing. The 56-body fixture uses real vocabulary metadata; controlled row/column handoffs follow model assignment semantics rather than a recorded physical game session.

| Encoding phase | Production mean | Prototype mean |
| --- | ---: | ---: |
| Stable-prewarmed cold motion onset | 20.977 ms | 39.852 ms |
| First row handoff | 21.095 ms | 39.890 ms |
| First column handoff | 23.120 ms | 41.247 ms |
| Repeated-cycle warm motion | 17.965 ms | 11.645 ms |

Each cold/handoff mean has 30 samples; the warm-motion mean has 60. The cold-onset P95 rises from 28.680 to 58.526 ms. Warm savings do not justify these interaction spikes, so the prototype remains unintegrated.

The root-run `snapshot-all-paired-v1.json` also reports only small production-to-candidate mean changes: settled 7.068 to 6.861 ms, drag 6.712 to 6.515 ms, falling 6.716 to 6.652 ms, and nested metadata 9.238 to 8.980 ms. Those differences are insufficient to separate the candidate from measurement/linkage noise. Snapshot changes are deferred.

## Regression coverage

`tests/web-export.test.cjs` retains an independent original scanner and unchanged decoder snapshot. Added behavioral coverage compares original and patched results across same/cross-realm views, valid and unusual indices/bounds, NUL placement, subarrays, signed zero, malformed UTF-8, and both manual and `TextDecoder` routes. Counted search calls verify genuine byte views use the intrinsic path while bounded, ignored-NUL, detached, shared, proxy and non-byte inputs retain fallback. Re-prototyped float/BigInt arrays, spoofed tags and shared-buffer prototypes, and shadowed length/buffer/index methods are included.

Isolated missing, duplicate and changed scanner anchors must fail, alongside the existing already-patched rejection. Existing packaging tests continue to verify that fingerprints use patched engine bytes, Brotli decodes to those exact bytes, and an unknown template fails before modifying export output. The root-run focused Node Web export suite passed all 48 tests.

## Bare comparison

The completed baseline and candidate captures are `build/performance/jelly-fps-utf8-baseline-bare-v1-capture` and `build/performance/jelly-fps-utf8-candidate-bare-v1-capture`. Both use headed Chrome 159.0.8140.0, SwiftShader, 1366 x 768, DPR 1, eight seconds of excluded warmup, normal audio/motion, and no CPU/host/GL profiling, tracing or input-snapshot diagnostics. These are sequential single-pair captures, so machine-load drift remains possible.

The read-only comparison at `build/performance/chrome-60fps/jelly-utf8-bare-v1-comparison.json` verifies all 622 copied source/configuration/data/fixture files against both build receipts and each other. It independently compares 619 runtime files with the Git blobs at full revision `d21f422a68b0e3063586289d8f03e88d631c433c`, normalizing only CRLF to LF and recording each blob ID and normalized SHA-256. The three benchmark-mutated configuration files (`project.godot`, `export_presets.cfg` and `benchmark-shell.html`) retain exact paired receipt parity instead. Generated `.uid` files are excluded. Both fixture files and the frozen browser runner are pinned separately; the existing runner does not embed its own source hash in each capture.

Delivered candidate engine JavaScript equals the baseline with exactly one strict scanner replacement and no other byte changes. Packaged host HTML is equal after replacing only the engine hash prefix. Decoded WASM, audio worklets and all 102 game/vocabulary packs match; every engine Brotli sidecar decodes to its delivered plain file. All six complete scenarios pass their workload checks. Both nine-word, nine-level mixed collection boards commit all 56 pickups with zero skips and no remaining bodies.

Process CPU milliseconds:

| Scenario | Baseline mean | Candidate mean | Baseline P95 | Candidate P95 |
| --- | ---: | ---: | ---: | ---: |
| Ordinary idle | 26.20 | 18.29 | 38.8 | 30.9 |
| Merged idle | 33.67 | 31.33 | 41.8 | 38.5 |
| Ordinary drag | 33.61 | 27.37 | 43.6 | 37.2 |
| Merged drag | 39.81 | 37.20 | 53.0 | 48.4 |
| Merge | 21.19 | 18.51 | 37.1 | 32.4 |
| Auto Collect | 41.58 | 41.45 | 62.6 | 66.8 |

Merged-drag submission CPU mean/P95 changes from 54.31/75.0 to 52.29/68.5 ms. Submission is CPU-side `frame_post_draw` completion, not a GPU fence. The pair supports lower drag CPU, while the phase diagnostic above provides the direct scanner attribution.

Dense Auto Collect uses only frames with 40-56 resident bodies and an active collection queue. Cadence includes only intervals whose two adjacent frames both meet that definition. Baseline/candidate contain 22/23 such frames:

| Dense collection metric | Baseline | Candidate |
| --- | ---: | ---: |
| Process mean / P95 | 59.07 / 152.4 ms | 62.89 / 134.1 ms |
| Submission mean / P95 | 77.64 / 168.9 ms | 85.04 / 148.2 ms |
| Adjacent engine-interval mean / P95 | 153.81 / 244.2 ms | 163.21 / 226.0 ms |
| Engine interval FPS | 6.50 | 6.13 |

Collection mean cost does not improve despite some lower tail values. Full collection engine FPS is 7.32/7.19, merged-drag engine FPS is 7.05/7.16, and merge engine FPS is 10.80/11.18 for baseline/candidate. Empty-page cadence varies from approximately 26.49 to 31.33 FPS. These software-renderer runs establish no collection gain, general FPS gain or physical full-board 60 FPS acceptance.

## Production validation

The focused Node Web export suite passed 48 of 48 tests. The standard Web build passed startup-pack validation, including deferred vocabulary, acquired chest/boss assets and all required audio. Its release receipt verified 14,127 source inputs and 117 output files. Production delivery uses `build/web`; diagnostic exports remain separate.

A headed Chrome smoke test of that actual production export entered a real 56-body challenge at 1366 x 768, dragged a settled top-row Jelly and released above the board. It verified all 56 bodies remained after a further 500 ms, input was released, the phase remained playing and no browser errors occurred. The screenshot also retained the complete board and production artwork. Evidence is `build/performance/chrome-60fps/release-utf8-bridge-smoke.json` and `.png`.

These release checks establish startup and interaction correctness. Physical desktop full-board 60 FPS, including mixed-level Auto Collect, remains unverified and requires the user's manual PC test.
