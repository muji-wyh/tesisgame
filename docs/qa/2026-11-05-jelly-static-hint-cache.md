# Jelly World drag cache retention

This follow-up targets full-board drag rendering after release `7c539271`. The acceptance target remains desktop Chrome at 1366 x 768, including mixed-level Auto Collect. The user will test the deployed release on a physical PC; the available Hyper-V software renderer cannot establish physical 60 FPS acceptance.

## Diagnosis and change

A diagnostic full merged-board drag began with 53 cached merged cores and ended with only six, while 48 body skins remained cached. Static completion hints use tile layer four, but full-core eligibility previously accepted only layer one. Component dimming also invalidated its full core without requesting a replacement; an unrelated static tile might never receive another pose update.

The tile now requests a replacement after all dimming component tints have changed. The eligibility gate also accepts layer four specifically for static or reduced completion hints. Animated, hovered, focused, marked, contacted, projected and moving artwork retains its existing live rendering. The shared atlas remains limited to 64 cells and two bakes per frame.

The full-core proxy remains a tile-relative child at local layer zero. Native learning labels, elevated level badges, fragments and contact shadows retain their original ordering. Acquired production artwork and all nine level effects remain intact. Game map presentation is unchanged.

The diagnostic tooling adds precise snapshot, preview and publication-bridge timers. The fine V2 capture at `build/performance/jelly-fps-7c539-drag-profile-v2-capture/drag-merged-1.json` attributes approximately 10.34 ms per sampled frame to the synchronous host publication call, 12.16 ms to the complete view snapshot, and 11.64 ms to base encoding. Preview availability is approximately 0.01 ms per frame in this fixture, so this release does not change its semantics. These inclusive diagnostic times overlap and contain instrumentation overhead; they are not FPS acceptance evidence.

A separate diagnostic copy instruments only the JavaScript phases inside the same synchronous host method. Its 54 valid publications average 1.517 ms for parsing/validation, 0.015 ms for dataset lookup/assignment, and 0.013 ms for phrase parsing plus touch-action assignment. This does not isolate native argument conversion or bridge overhead. The helper and all modified exports remain under `build/performance`; production host behavior is unchanged. Raw evidence and pinned index/runner hashes are in `jelly-fps-7c539-host-profile-v1-capture` and `chrome-60fps/profile-jelly-host-js-v1.manifest.json`.

## Correctness

The graphical merged-core suite passed 218 checks. New captures compare automatic dimming, undimming and raised static hints against the same source artwork, including mixed ordinary and merged neighbors, inherited alpha, labels, badges, fragments and shadows. They retain the existing RGBA8 rounding budget. The raised-hint capture reduced real draw calls from 557 to 417; automatic dimming and undimming each reduced 542 to 452. Animated hints, non-hint layer four and arbitrary layer five remain excluded.

The drag performance suite passed 49 assertions, merged-level effects passed 636, and ambient animation budgeting passed 49.

## Bare browser comparison

The baseline reuses `build/performance/jelly-fps-preparation-candidate-bare-v1`; all 786 copied runtime source and data files match `7c539271` after line-ending normalization. The benchmark-specific project configuration is excluded from that check. Evidence is recorded in `build/performance/chrome-60fps/static-hint-baseline-source-parity.json`.

The new export is `build/performance/jelly-fps-static-hint-candidate-bare-v1`. Both capture directories use the corresponding `jelly-fps-static-hint-*-bare-v1-capture` names. Both runs use headed Chrome 159.0.8140.0, 1366 x 768, DPR 1, SwiftShader, eight seconds of excluded warmup, normal motion/audio, native CDP mouse input, and no fine timers, GL wrappers, tracing or input snapshot diagnostics. The unchanged scene runner and fixture hashes are `47f4a2c28a83ea45cb1db0aa29e378af53e5a97c6270f89488b22b9ccd24602a` and `d5b817fe53ccc5ba4a61821a5cc7168a3c0f44286959fa2bc706411d8dce009e`.

| Bare metric | Previous | Candidate |
| --- | ---: | ---: |
| Merged cores retained after full-board drag | 6 | 48 |
| Merged drag process mean | 47.96 ms | 39.61 ms |
| Merged drag process P95 | 59.3 ms | 52.8 ms |
| Merged drag submission mean | 68.31 ms | 53.73 ms |
| Merged drag engine FPS | 6.14 | 7.04 |
| Auto Collect process mean | 49.44 ms | 49.29 ms |
| Auto Collect process P95 | 73.2 ms | 73.6 ms |
| Dense 40-56-body collection process mean | 69.89 ms | 69.62 ms |

All six candidate scenarios passed: ordinary and merged idle, ordinary and merged drag, merge, and mixed-level Auto Collect. The real merge left 55 bodies. Both collection captures committed all 56 pickups across nine reviewed production words and all nine merge levels, with zero skips and no remaining bodies. Atlas allocation remained 16 MiB, at most 64 entries and two bakes per frame, with no fallbacks or pending warmup at the drag boundary.

The summary is `build/performance/chrome-60fps/static-hint-bare-comparison.json`. CPU time also decreased in unchanged ordinary scenarios, indicating host-load variation; the raw timing change cannot be attributed entirely to this patch. Direct cache retention and the controlled graphical draw-call comparisons establish the intended rendering improvement. Collection timings are essentially unchanged. Empty-page cadence varied between approximately 21 and 31 FPS, so these captures do not establish physical 60 FPS acceptance.

## Production export

The standard Web build passed startup-pack validation and receipt verification for 14,127 source inputs and 117 outputs. The packaged core is 66.12 MB plus the selected age pack. Production uses `build/web`; diagnostic and benchmark exports remain separate.

A headed Chrome smoke test of that actual production export entered a real 56-body challenge, dragged a settled top-row Jelly, and released above the board to isolate drag return from matching. It verified all 56 bodies remained after a further 500 ms, input was released, the phase remained playing, and no browser errors occurred. Evidence is `build/performance/chrome-60fps/release-static-hint-smoke.json` and `.png`. This validates release boot and interaction, not physical FPS acceptance.
