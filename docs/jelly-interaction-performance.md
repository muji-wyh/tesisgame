# Jelly World crowded-board interaction performance

The 2026-11-04 interaction changes address dragging, merging and collecting on
crowded PC Chrome boards after the settled-board optimization in
[the idle performance report](jelly-idle-performance.md). Dragging previously
promoted every compatible target to animated presentation and live gel rendering.
Repeated return-space and placement checks added CPU work while the board was
unchanged.

## Runtime behavior

Every compatible target retains its semantic completion hint and authored
lighting. Three nearest targets are selected once per gesture for animated
feedback. Other matching targets hold a 1.12 skin scale, 0.95 completion strength
and no moving glint. Contact, hover, focus, dragging and falling still receive
immediate priority. Static-to-animated promotion preserves the held enlarged
posture; reduced-motion changes update the same active hint without restarting
the gesture.

Static expanded hints use the shared acquired-paint atlas, including the full
1.32 padded glow envelope. Ordinary entries share their display material; padded
entries use a bounded vertex-padding material. Each viewport retains at most 64
atlas cells and warms at most two new states per frame. Contact, bending,
pressure, changing scale and moving sweeps retain live rendering. There is no
recurring GPU readback. No game artwork or audio was replaced.

Supply drop availability is cached only across verified stable geometry. Falling,
moving, fusion and gravity-delay boundaries invalidate it. Placement previews are
cached by source, rounded grid position and model/geometry boundaries. Pointer-up
validates against fresh model state before resolving a drop. Availability checks
outside a presentation pass also remain fresh. Same-elapsed hint work is skipped,
and board priority changes are batched before membership updates. Newly
registered arrivals receive their already-classified priority in the same pass;
hover and focus updates outside a batch remain immediate.

Fusion release beads are created only when the effect actually uses them. Word
Jelly requests no release beads. A union with zero opacity stops drawing after
full handover. Concurrent reading cards retain every word, reward and reading
duration. The newest card keeps its full authored celebration. Secondary cards
share a limit of 192 texture stamps per draw, at most 64 per card; each generates
at most 12 secondary particles and one trail. Particle-work diagnostics are
separate from gameplay snapshots so drawing does not mutate paused game state.

Regular host publication reuses canonical top-level JSON member fragments. Each
String/StringName-keyed base field is encoded once with native JSON semantics;
fragment keys normalize to String without changing raw input key types. Joining the
sorted fragments produces the same canonical base JSON used for deduplication.
The host then encodes only its ten fresh override fields and rejoins the member
fragments. `GameUI` enables this path for its two Jelly views. The base JSON
equality guard, native `changed` snapshot signal, publication cadence and
host-first delivery remain intact. Direct pause, finish and cancel publication
routes retain the original fresh snapshot/shallow-copy serialization path. Any
top-level key other than String or StringName in the base or overrides uses the
native fallback.

## Reproducible CPU comparison

The source baseline is commit `74924a870ca1c7f9b01185351b31e2f44435b16c`, frozen
in `build/performance/jelly-interaction-baseline-74924a87-20261104/`. This is a
plain source snapshot, not a Git worktree. Assets, engine imports and the harness
are shared inputs and must remain unchanged during each pair. The runner
fingerprints source and harness files, alternates process order, retains raw
samples and verifies exact interaction traces. Only one engine, browser or build
workload runs at a time.

```powershell
node tools/benchmark-word-jelly-drag.cjs --authored --baseline build/performance/jelly-interaction-baseline-74924a87-20261104 --label jelly-authored-interaction-paired-20261104 --repeats 3 --samples 120
```

The authored fixture uses 49 bodies at 1366 by 768: reviewed Growth cat roots and
pictures with 24 matching hints, or a friendly authored two-part merged word
retaining composition with 48 matching hints. Each process advances 30 warmup
updates and 120 measured updates per case at a 60 Hz simulation cadence. Cases
cover free/contact dragging and one/four input motion events per update. Timing
includes the shared WordArt clock and a conservative deep-copy/JSON stand-in for
host publication. Production `GameUI` shallow-copies the snapshot before adding
host overlays and serializing it; the benchmark wrapper deep-copies it. Paired
savings apply to this documented protocol, not an exact reproduction of the
production host copy. Headless rendering uses the live fallback: these timings
measure CPU/view work and exclude rendering, browser bridge execution, audio and
physical PC FPS.

Godot 4.7.2 on Windows completed three alternating process pairs. All 24 paired
interaction traces matched, including hint identities, placement and contact.
Pooled mean milliseconds per manually advanced update were:

| Source | Contact | Motion events | Before | After | Reduction |
| --- | --- | ---: | ---: | ---: | ---: |
| Root | No | 1 | 13.903 | 11.579 | 16.7% |
| Root | No | 4 | 13.705 | 10.571 | 22.9% |
| Root | Yes | 1 | 13.852 | 10.298 | 25.7% |
| Root | Yes | 4 | 13.483 | 11.064 | 17.9% |
| Merged | No | 1 | 15.462 | 11.818 | 23.6% |
| Merged | No | 4 | 15.696 | 12.411 | 20.9% |
| Merged | Yes | 1 | 15.651 | 13.823 | 11.7% |
| Merged | Yes | 4 | 15.826 | 13.619 | 13.9% |

All pooled means improved, but shared host load varied and snapshot frames still
stall. The full raw and percentile results remain in
`build/performance/jelly-authored-interaction-paired-20261104/summary.json`.
Inclusive profiling reduced drop-availability work from approximately 3.0 to
0.60-0.85 ms per update and placement-preview work from approximately 2.6 to
0.19-0.29 ms. These authored frame timings cover the earlier nine-source stage;
the final publication improvement has its own serialization comparison below.

The three-pair timings precede narrow follow-ups for early hint promotion,
reduced-motion toggles and newly registered airborne priority. An optional final
one-pair rerun encountered missing shared licensed chest inputs after completing
eight cases. The incomplete run is not accepted as a paired measurement. The
table therefore remains specific to the earlier three-pair source fingerprints.
Final focused native checks cover the follow-ups: 3,396 hybrid-tile checks, 595
preview/hint assertions and 49 ambient-lifecycle assertions passed.

## Publication serialization comparison

The initial String-only helper did not engage on live Word Jelly snapshots:
`WordJellyModel.snapshot()` inserts `authored_morphology` through property syntax,
which creates a StringName root key. Re-parsing browser JSON converted all keys
to String and hid that fallback. The earlier serialization experiment is
therefore superseded as evidence for the actual runtime path.

The final helper accepts mixed String/StringName roots. The v2 CPU fixture
re-parses the preserved earlier candidate drag sample's `before` host JSON, then
captures and erases the String `authored_morphology` key and reinserts it through
the actual property syntax. It asserts the restored StringName key type and
requires the fragmented path. Root-key-type fingerprints, canonical base/host
JSON and raw input immutability are verified outside timed blocks. The base still
includes existing host keys, and both variants apply the same ten host overrides.
Numeric values remain JSON re-parsed and can differ from the live source Variant
representation. Native tests also exercise direct real-model snapshots and a
property-inserting stub.

```powershell
node build/performance/jelly-interaction-20261104/publication-benchmark.cjs --label publication-json-named-final-20261104 --repeats 3
```

Three independent Godot 4.7.2 processes each completed 20 warmup iterations and
120 measured iterations. Legacy/candidate order alternates within each process,
and the first variant alternates across processes. All 5,049 canonical JSON,
key-type and immutability checks passed: 1,683 per process. The actual restored
StringName root remained intact and the fragmented path engaged in every
candidate iteration. Pooled serialization timings are:

| Variant | Mean | P95 |
| --- | ---: | ---: |
| Legacy base and full host serialization | 56.274 ms | 93.522 ms |
| Reused member fragments and host overrides | 34.056 ms | 54.612 ms |

The mixed-key fixture's pooled mean decreases by 39.5%. Its canonical host
payload is 288,524-288,536 characters. Raw samples, individual process means,
engine identity and current fixture/helper/harness/GameUI/JellyMatch hashes are
retained under
`build/performance/jelly-interaction-20261104/publication-json-named-final-20261104/`.
This is pure serialization CPU work. It excludes snapshot creation, publication
cadence, simulation, drawing, the WebAssembly/browser bridge, browser parsing,
audio and physical PC FPS. It does not establish a final paired native frame
improvement or combine with the earlier authored-frame percentages. The final
native publication suite passes 114 assertions, including direct real-model and
property-inserting stub coverage.

The superseded String-only experiment recorded a 42.0% mean reduction and 3,363
canonical/immutability checks. Its raw evidence remains in
`publication-json-final-20261104/`; those results describe the re-parsed
String-only fixture and do not prove the live mixed-key path.

Snapshot construction remains synchronous frame work. During play, the view
publishes on an accumulated 0.1-second cadence and input/state-change events.
Model `cells` and presentation `tiles` independently carry copies of the same
board metadata. An earlier live baseline drag snapshot contains approximately
282,000 JSON characters, including 151,744 for `tiles` and 92,949 for `cells`.
The browser still parses the full payload and writes the diagnostic dataset
synchronously. The final regular path avoids the second traversal of the full
JSON object, but the payload shape, snapshot construction and cadence remain.
A future change can profile event coalescing or separate lightweight host status
from opt-in detailed diagnostics, while preserving fresh input-release and
settlement boundaries, mutable native snapshots and browser `tiles`/`cells`
consumers.

## Rendered browser comparison

The maintained opt-in fixture is
`tests/browser/word-jelly-performance.spec.cjs`. It fills a normal-motion desktop
board with 49 ordinary bodies, then measures dragging, Auto Merge or Auto Collect.
Auto Collect starts with 48 bodies after one manual merge. Each browser process
uses one window per scenario: four seconds for dragging and nine seconds for
automatic actions. The test records raw `requestAnimationFrame` intervals,
renderer, DPR, exact body counts, presentation diagnostics and gameplay outcomes.

The recipe fixes words, body count and type composition, but its seed does not
seed `GameUI.new_round`; placement and word allocation remain randomized. This
is an equivalent-workload browser comparison with a layout limitation. It is not
the exact-board pairing used by the authored CPU fixture. The baseline Chrome
Canary 159 run on the shared Windows host used software rendering; neither this
nor the headless timings establish sustained 60 FPS on the user's physical PC
GPU.

The final mixed-key candidate uses the preserved baseline Web PCK with twelve
performance source/shader replacements or additions: the initial nine plus `jelly_match.gd`,
`game_ui.gd` and `jelly_publication_json.gd`. Its audit retains 1,792 other packed
resources with their original SHA-256 values and reports zero mismatches. Its
replacement hashes match the current twelve performance sources, including the
final mixed-key helper.
Obsolete compiled-script/remap entries for the additional replaced scripts are
removed. Parallel chest changes remain untouched and are excluded from the
comparison.

The incremental preview replaces exported `.gdc` resources with `.gd` source.
Godot 4.7.2 export mode 2 stores ZSTD-compressed token buffers rather than VM
opcodes; text and binary-token loading converge on the same analyzer/compiler.
Assertions are governed by the preserved template's `DEBUG_ENABLED` setting.
The same Web engine and a loaded, settled game support steady gameplay
comparison, while startup time and retained source memory can differ. The
official implementation is recorded in
[GDScript export registration](https://github.com/godotengine/godot/blob/4.7.2-stable/modules/gdscript/register_types.cpp#L99-L116),
[runtime parsing](https://github.com/godotengine/godot/blob/4.7.2-stable/modules/gdscript/gdscript.cpp#L814-L849)
and [export modes](https://github.com/godotengine/godot/blob/4.7.2-stable/editor/export/editor_export_preset.h#L57-L61).

The normal source build was stopped after confirming missing licensed chest
inputs: seven tracked Kenney deletions and eleven missing ignored artifacts,
including inputs used by `meadow-explorer`, `strawberry-bonbon` and
`moonstone-vault`. The incremental export is a local validation preview, not a
successful `npm run build:web` or a standard build receipt. It has not been
deployed.

Final mixed-key browser validation completed four separate Chrome Canary
159.0.8140.0 processes on Windows at 1366 by 768, DPR 1, normal motion, using
ANGLE Vulkan SwiftShader software rendering. Process order was final candidate
drag, adjacent baseline drag, final candidate Auto Merge, then final candidate
Auto Collect. Each run passed its gameplay outcomes and remained in the playing
phase. The final windows recorded:

| Export | Scenario | Bodies before/after | Mean interval | P95 interval | Intervals |
| --- | --- | --- | ---: | ---: | ---: |
| Adjacent baseline | Drag | 49 / 49 | 190.15 ms | 200.1 ms | 22 |
| Final mixed-key candidate | Drag | 49 / 49 | 156.41 ms | 166.7 ms | 26 |
| Final mixed-key candidate | Auto Merge | 49 / 46 | 139.23 ms | 199.9 ms | 65 |
| Final mixed-key candidate | Auto Collect | 48 / 54 | 132.84 ms | 150.0 ms | 68 |

Within the one adjacent four-second drag pair, the candidate mean interval is
17.7% lower and P95 is 16.7% lower. Candidate cached bodies change from 49 to 45,
compared with 49 to 40 in the baseline; animated owners change from three to
seven, compared with three to twelve. Both retain all eight matching hints.
These windows cover randomized layouts and a shared software-rendering host,
with 26 and 22 measured intervals; they do not establish physical PC performance
or a sustained 60 FPS budget.

The earlier baseline-control automatic windows recorded:

| Earlier baseline-control scenario | Bodies before/after | Mean interval | P95 interval | Intervals |
| --- | --- | ---: | ---: | ---: |
| Auto Merge | 49 / 46 | 92.00 ms | 133.3 ms | 98 |
| Auto Collect | 48 / 54 | 96.81 ms | 116.7 ms | 94 |

The final automatic windows are slower than those earlier controls. Their
separated measurement times, randomized placement and differences in action
progress limit causal comparison. Initial, String-only prototype and final
mixed-key windows vary widely across the session. The rendered evidence does
not show a universal improvement across dragging, merging and collecting.
`browser-summary.json` retains all raw-window summaries with their corresponding
pack identities; `browser-named-final-order.json` records final process order.
Earlier process orders and raw reports remain preserved in the evidence
directory.

The measured export identities are:

| Version | Web pack |
| --- | --- |
| Preserved baseline | `game-517f0e427825c150.pck.br` |
| Final mixed-key incremental candidate | `game-f5577f51e76ed1a3.pck.br` |

The final candidate's raw PCK is 90,822,336 bytes. Its raw SHA-256 is
`f5577f51e76ed1a3b1b3eebd5aeee1364df5e0746229222b4770237ef5d078bf`; the
Brotli-compressed SHA-256 is
`fce1f9239773890b0385c79885cec537040e68f714abcb801f422d9f6f8d5060`.
`incremental-build-receipt.json` records the source/replacement paths, export
directory and exact hashes. `incremental-pack-audit.json` records retained and
replaced resource hashes and the empty mismatch list. Both are in the evidence
directory below. Earlier receipts and audits for the nine-script candidate
`game-768729cff98cf9a6.pck.br` and String-only publication candidate
`game-a3ea5649f557c96f.pck.br` are retained separately under
`initial-nine-script-candidate/` and `string-only-publication-candidate/`.
Their measurements do not describe the final pack.

Completed final verification is recorded in
`incremental-final-verification.json` and `incremental-final-verification.log`.
It confirms all twelve current source hashes, 1,792 retained resource hashes,
the raw/compressed pack and loader hashes, and unchanged release output files.

The preserved baseline export, receipts, browser reports and focused native logs
are under `build/performance/jelly-interaction-20261104/`. Its baseline Web pack
is `game-517f0e427825c150.pck.br`. Rendered measurements must remain attached to
their exact exports; a later rebuild needs fresh validation before inheriting
them.

## Focused verification

Rendered cache validation passed 36 checks on Godot 4.7.2 with ANGLE Microsoft
Basic Render Driver. Original and cached paint, palette, rim, opacity and the
full completion-light envelope differ by at most 1/255 per channel. The full
padded envelope has mean error 0.00082964723826 and maximum error
0.00392158329487. Raw validation is retained under
`build/qa/jelly-static-hint-cache-validation/`.

The following focused suites passed; this is not a claim that the complete
repository suite is green:

| Suite | Checks/assertions |
| --- | ---: |
| Hybrid tile, including continuous early hint promotion | 3,396 |
| Preview caches and hint budget, including reduced-motion toggles | 595 |
| Ambient lifecycle, including same-pass airborne priority | 49 |
| Interaction allocation and draw budgets | 80 |
| Word reading reveal | 16,324 |
| Hybrid view | 233 |
| Falling contact | 377 |
| Interaction, including neutral merged-partner drops | 4,110 |
| Controls | 1,251 |
| Morphology view | 1,990 |
| Fill stream view | 145 |
| Collection effects | 170 |
| Auto merge permanent upgrades | 818 |
| Boss application | 64 |
| Shared Jelly Match view / flow | 3,143 / 427 |
| Existing drag performance | 49 |
| Canonical publication, real mixed-key model, deduplication, delivery order and fallback | 114 |
| Node benchmark/runner | 19 |

The initial hybrid-view run exposed 20 stale assertions requiring completed
charge glow/sparkle nodes to be queued for deletion immediately. The frozen
baseline reproduced the same 20 failures. Existing runtime behavior retains one
hidden `_idle_collection_visual` pool; this iteration does not change that pool.
The corrected test verifies that finished artwork stops drawing and that
`view.stop()` queues the retained nodes for deletion. Configure/stop interruption
coverage remains. The final hybrid-view run passes 233 checks.

The initial ambient run found a genuine one-frame priority delay for new arrivals.
The same-pass registration fix passes the original lifecycle assertion. Final
logs are `hybrid-final.log`, `final-checks.log` and the corresponding `*-final.log`
files in the evidence directory. The mixed-key publication result is recorded in
`publication-regression-named-final.log`.

The maintained `tests/browser/word-jelly-hybrid.spec.cjs` passed against the final
mixed-key `game-f5577f51e76ed1a3.pck.br` preview in desktop Chromium and Android
Chromium. Desktop uses mouse input at 1366 by 768 with `hasTouch: false`. Android
uses the Pixel 7 profile and real CDP touch dragging/holding. Both cover merging,
a resize to 390 by 844, settled-grid alignment, clipped-label Read dialogs,
resume and collection. Final page-error assertions are empty. The completed
test assertions are recorded in `browser-hybrid-named-final.log`.

Visual inspection of the desktop `hybrid-word-and-picture.png` and Android
`hybrid-phone.png` screenshots confirms the acquired Jelly/vocabulary artwork
remains intact and the resized grid aligns. Clipped merged labels retain their
Read-dialog interaction; the corresponding dialog screenshot is preserved.
These are focused interaction and visual checks of the incremental preview.
The missing licensed source inputs still prevent a standard source build; this
preview has not been deployed.
