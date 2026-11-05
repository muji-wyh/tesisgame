# Jelly reward preparation and publication

This follow-up targets remaining game-page CPU spikes after release `5ad05872`. The acceptance target remains desktop Chrome at 1366 x 768, with 60 FPS during full-board idle, dragging, merging and mixed-level Auto Collect. The user will test the deployed release on a physical PC; the available Hyper-V software renderer cannot establish that acceptance result.

## Changes

- Settled record encoding checks string-like keys only when the already validated record body changes. Unsupported keys remain uncached and use native JSON on every call. Full payloads, synchronous signal order, detached snapshots and host overrides remain intact.
- Reward-only chest surfaces prepare the real closed model and its measured turn envelope directly. They skip the opening-pose and treasure/magic envelope measurements that the previous closed-turn framing immediately discarded. Ordinary opening surfaces retain their complete envelopes.
- Chest state composition still checks and reads its catalog on every configuration. One private cache reuses parsing only for exactly matching source text. Changed or invalid text replaces that entry, and selected recipes are deep copies owned by each instance. A direct source-path getter avoids building a debug snapshot merely to validate model identity.

The changes retain all 99 tier identities, final-material reuse, acquired geometry, materials, actual articulation, reward ordering, audio and effects. Game map presentation is unchanged.

## Paired native CPU evidence

The committed reference is frozen as ordinary files at `build/performance/baseline-5ad058-preparation`, without a Git branch or worktree. Its source-tree SHA-256 is `54ae111f8fc800de2887b340cd488a366712e043c14636284226390eb0ed9ad4`. Assets, imported resources and tests remain shared references.

`build/performance/chrome-60fps/publication-dense-validation-paired-v1.json` alternates the previous and candidate cache in the same process, with 40 samples after 10 warmup iterations per scenario. The real model/view fixture contains 56 merged bodies, nine reviewed production vocabulary identities and all nine merge levels. Every complete base and host JSON result equals native serialization byte for byte.

| Complete base and host encoding | Previous mean | Candidate mean |
| --- | ---: | ---: |
| Age-only changes | 8.325 ms | 7.546 ms |
| Falling pose changes | 17.639 ms | 17.604 ms |
| Persistent nested metadata changes | 9.545 ms | 8.525 ms |

This isolates approximately 9.4% and 10.7% savings for stable-body encoding, with the dense moving-body native fallback essentially unchanged. Earlier separate-process captures have substantial machine-load drift and are not used to claim improvement.

`build/performance/chrome-60fps/chest-preparation-cpu-paired-v3.json` alternates previous full preparation plus closed-turn framing against the final production closed helper. It uses tiers 1 through 11 and 99, six samples per tier after one warmup pair, fresh inactive views and strongly retained production resources. Across 72 timed pairs, mean preparation decreased from 5.417 ms to 2.542 ms, approximately 53.1%. View construction, attachment, source warming, validation, cleanup and reporting are outside timing.

The previous renderer and state composer are ordinary source copies under `build/performance/chest-preparation-reference-5ad058`. The only renderer transformation retargets its composer preload to that copied previous source. The final benchmark records both hashes and named Script constant dependency edges, and verifies exact identity, articulation, camera framing, projected bounds and yaw/pitch parity. The initial `chest-preparation-cpu-v1.json` measured only the closed-envelope optimization before the catalog/getter changes. V2 measured the combined change but omitted its private composer's hash inside the report; adjacent `source.json` pins that file. V3 supersedes both as final evidence.

These are native CPU measurements, excluding rendering, browser bridge, audio and physical FPS. They must not be interpreted as a 60 FPS result.

## Browser comparison

The bare baseline uses the existing export `jelly-fps-callback-candidate-bare-v1`; its 151 GDScript sources and 444 scene/data files match the frozen release after line-ending normalization. New baseline captures are in `build/performance/jelly-fps-preparation-baseline-bare-v1-capture`. The final candidate export and captures are `jelly-fps-preparation-candidate-bare-v1` and `jelly-fps-preparation-candidate-bare-v1-capture` under the same performance directory.

Both use headed Chrome 159.0.8140.0, 1366 x 768, DPR 1, SwiftShader, eight seconds of excluded warmup, normal motion and audio, and identical fixture/runner hashes. Neither uses method wrappers, GL wrappers, tracing or input snapshot diagnostics. Copied-source fingerprints are `7a2d3a39073056311bc9aedbb09f44186e3c66383234ee7dd3555d9bd17be1d3` and `e3c9bc94557c4f81a906566a419114bc8dcd9e6d3e3ccbbe9e402a577b878341` respectively.

| Bare metric | Previous | Candidate |
| --- | ---: | ---: |
| Auto Collect process mean | 42.06 ms | 34.59 ms |
| Auto Collect process P95 | 61.9 ms | 51.4 ms |
| Dense 40-56-body collection process mean | 55.07 ms | 50.80 ms |
| Dense collection process P95 | 145.2 ms | 122.8 ms |
| Auto Collect engine interval P95 | 168.8 ms | 151.8 ms |
| Full merged-board drag process mean | 36.88 ms | 36.91 ms |
| Full merged-board drag process P95 | 45.9 ms | 51.6 ms |

Auto Collect mean CPU decreased approximately 17.7% in this single pair. Both runs committed all 56 mixed-level pickups with zero skips and no remaining bodies. Full merged-board drag mean was essentially unchanged and its P95 was higher in this pair; this iteration does not establish a drag improvement. Empty-page cadence was approximately 29-31 FPS, and collection engine FPS was 7.18/8.04, so physical 60 FPS remains unverified.

The candidate also passed ordinary and merged full-board idle, ordinary and merged native-mouse drag, a real merge that left 55 bodies, and mixed-level Auto Collect. The comparison summary is `build/performance/chrome-60fps/preparation-bare-comparison.json`. No browser error was reported.

## Correctness

Publication cache checks passed 284 assertions, including warmed valid-to-unsupported key transitions, repeated fallback, StringName aliases, nested mutation and escaped keys. The general publication JSON suite passed 114 assertions. Collection learning passed 30 checks.

Chest state checks passed 1,592 assertions covering all production models plus catalog changes, invalid/restored text, duplicate first-match behavior and nested entry isolation. The final graphical celebration suite passed 7,750 assertions, including exact pixel equality for reference and candidate closed models at four yaw/pitch poses across tiers 1, 4, 10, 28 and 99. Source models and runtime reward surfaces remain three dimensional.

Live model checks passed 125 assertions, all 99 tier recipes passed 2,967, tier consumers passed 14, static Jelly icons passed 557, and the Node icon validator passed five tests. All 28 icons were rebaked after the pinned renderer sources changed. Every icon record, crop, PNG hash and decoded pixel hash exactly matches the previous bake; only the two renderer source dependency pins changed in the manifest.

## Production export

The final standard Web build passed startup-pack validation and receipt verification for 14,127 unchanged source inputs and 117 outputs. The packaged core is 66.12 MB plus the selected age pack. A headed Chrome smoke test of that actual production export entered a real 56-body challenge, performed a native mouse drag and release, retained all 56 bodies and remained in the playing phase with no browser errors. Evidence: `build/performance/chrome-60fps/release-preparation-smoke.json` and `.png`. This validates release boot and interaction, not physical FPS.
