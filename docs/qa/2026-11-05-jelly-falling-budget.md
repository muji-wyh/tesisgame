# Jelly World bulk-fall animation budget

This follow-up targets game-page frame drops during Fill arrivals and the
simultaneous downward collapse of many Jelly bodies. The acceptance target
remains desktop Chrome at 1366 x 768, including full-board movement and mixed-level
Auto Collect. Physical 60 FPS acceptance still requires the user's actual PC.

## Cause and policy

The view previously treated every moving body as an ambient-animation priority.
That included unsettled arrivals and gravity reflow, so a large falling cohort
bypassed the three-owner idle limit. Registration, hover release and completion
hint refreshes could also restore that movement-based exemption. Physical motion
therefore activated decorative vocabulary sheets and merged-level effects for
the entire moving group.

The view now keeps a separate private interaction-owner set. Physical motion
continues to use the existing active and dynamic pose sets; decorative priority
uses the interaction set, the bounded teaching-hint cohort, and hover/focus.
Registration, old-hover restoration and every completion-hint priority callsite
follow the same distinction. Starting a reflow no longer grants decorative
priority by itself.

Real interaction owners retain immediate feedback: the dragged source, contact
target, keyboard source, queued collection, powerup presentation, rejection and
snapback. Native hover and keyboard-focus ownership remain in the existing
scheduler. Semantic matching hints still mark every legal target, while their
decorative motion uses the existing limited teaching cohort. Idle rotation,
pause/background gating and reduced-motion behavior are unchanged.

The fix does not change model gravity, arrival clocks, falling speed, trajectories,
landing deformation, shadows, support lift, collision outlines or reserved
destinations. It does not change game-map presentation, authored artwork/audio,
rewards, learning or wallet behavior. Complete snapshot transport, detached
ownership, publication cadence and serialized-before-native signal order are
retained. Noncohort vocabulary art retains its
existing sourced poster and tier accents while the Jelly body keeps moving.

## Regression coverage

The ambient-budget suite replaces its former assertion that every airborne owner
must receive unbudgeted decorative animation. It now checks physical movement
independently from decoration: actual supply bodies continue downward, real Fill
waves reach and settle a full board, and removing seven supports moves all 42
surviving bodies. The tests also check a falling poster outside the cohort,
moving-owner hover release, native focus, bounded teaching hints, exact final
board rectangles, pause and reduced-motion restoration.

The root-run focused checks passed on Godot 4.7.2:

| Suite | Passing assertions/checks |
| --- | ---: |
| Word Jelly ambient budget | 62 |
| Word Jelly interaction budgets | 80 |
| Word Jelly falling contact | 377 |
| Word Jelly preview caches and hint budget | 595 |
| Merged Jelly level effects | 636 |
| Word Jelly interaction | 4,110 |
| Word Jelly authored drag | 2,544,756 |
| Auto Collect hover targets | 397 |
| Word Jelly publication cache | 284 |
| Jelly publication JSON | 114 |

These are ten passing focused suites. The JSON suite deliberately exercises NaN
serialization and records Godot's expected NaN-to-null warning. Evidence is
`build/performance/chrome-60fps/falling-budget-regressions-v2.log` and
`falling-budget-regressions-rest-v1.log`. The earlier V1 ambient run is retained
as a failed test-authoring attempt; it is not counted as a pass.

### Existing presentation teardown failure

The broad `word_jelly_presentation_tests.gd` command is **not a passing check**.
Both the candidate and a separately copied baseline at `5b8ad782` report 354
passing assertions, then emit the same five teardown errors:
`Node not inside tree. Use look_at_from_position() instead.` The stack reaches
`word_jelly_boss_actor.gd:124` through `word_jelly_result_taunt.gd:77` and
`pop_reward_room.gd:1666` while freeing the challenge-results room. The process
exits zero, but the normal runner rejects engine `ERROR` output.

The baseline project contains 788 frozen runtime/config/data files and 536 exact
current Godot/performance test files, with shared asset/import junctions. Its
Word Jelly source matches the frozen release bytes and Git `5b8ad782` after
newline normalization. The project is
`build/performance/falling-presentation-baseline-v1`; its manifest SHA256 is
`e1d303bfee8267f08bb3fd430d3d419a1aac0bb10774d276c0e599647ac5aa8f`.
The baseline reproduction is in
`build/performance/chrome-60fps/falling-presentation-baseline-v1.log`; the
candidate failure is in `falling-budget-regressions-v2.log`. This establishes
the teardown failure on the unchanged baseline. No Boss/result-room fix or
suppressed engine error is included in this bulk-fall change.

## Browser diagnostic protocol

The ignored harness is under
`build/performance/chrome-60fps/massfall-v1`, with protocol
`jelly-massfall-rendered-v1`. The baseline is the frozen `5b8ad782` runtime; the
candidate changes only `scripts/word_jelly.gd`. Source/configuration manifests
pin the copied files. Existing artwork, engine imports and vocabulary remain
shared resources, so they must remain unchanged across the pair.

Both scenarios first warm a nine-word, nine-level merged full board for eight
excluded seconds. Fill then retains 14 merged bodies in the bottom two rows and
switches the real connected Fill toggle at 0.5 seconds; ordinary production
supply must fill and settle the board. Gravity stress retains 49 bodies above
an unsupported empty bottom row and sets gravity pending at 0.5 seconds. That
second geometry setup is deliberately synthetic; ordinary production gravity
performs the movement. Neither scenario starts collection or a merge.

The harness records actual unsettled arrivals, delayed arrivals and collapsing
bodies, together with physical pose membership, decorative priority, native
hover/focus ownership and loaded vocabulary-sheet state. Persistent `falling`
flags are gated by actual settlement age. Those observations occur after the
process/submission timers and add cadence overhead. Decoded sheet bytes are an
existing width-times-height-times-four estimate, not measured GPU memory.

Nine common inclusive method wrappers diagnose view processing/classification,
pose synchronization, model stepping, Fill pumping, gravity settlement and
WordArt advance/owner-animation/sheet loading. Their nested times overlap and
must not be added. `_load_sheet` calls are a load proxy when successful, not a
graphics upload counter. `frame_post_draw` marks CPU submission completion,
not a GPU or presentation fence. Instrumented timing and software-renderer FPS
cannot establish physical 60 FPS acceptance.

## Browser results

The root's bounded pair completed in headed Chrome 159 at 1366 x 768, with
normal audio, eight excluded warmup seconds and six sampled seconds. Both
exports have the same three harness files and nine CPU wrappers; verified
source fingerprints differ only in `scripts/word_jelly.gd`. All copied source
bytes match their build receipts. No browser error/failure records, game or
journal errors, merges, collection batches, collection effects, coin changes or
learning-save failures occurred. Both Fill runs reached 56 settled bodies; both
gravity runs retained and settled all 49.

| Observed motion | Baseline | Candidate |
| --- | ---: | ---: |
| Fill: total frames / moving frames | 44 / 22 | 50 / 22 |
| Fill: peak moving / priority / animated owners | 22 / 22 / 25 | 22 / 0 / 3 |
| Gravity: total frames / moving frames | 56 / 2 | 57 / 3 |
| Gravity: peak moving / priority / animated owners | 49 / 49 / 49 | 49 / 0 / 3 |

Native hover/focus counts were zero throughout. At every observed moving
sample, physical active/dynamic pose counts covered the moving count; at the
peak they were exactly 22/22 for Fill and 49/49 for gravity in both variants.
The unchanged classification path keeps each moving body in those physical
sets. Exact active/dynamic ID sets were not recorded per frame, so the browser
evidence establishes their counts together with that source review.

The following values use only frames with actual active arrivals or collapse.
Method means are total inclusive microseconds divided by actual call counts;
they overlap and must not be added.

| Motion-phase measurement | Baseline | Candidate |
| --- | ---: | ---: |
| Fill: mean process / submission, ms (22 / 22 samples) | 100.455 / 109.718 | 88.009 / 96.045 |
| Fill: WordArt advance, ms/call (22 / 22 calls) | 2.773 | 2.423 |
| Fill: pose synchronization, ms/call (23 / 23 calls) | 4.704 | 3.343 |
| Fill: sheet-load calls, motion / full capture | 3 / 3 | 3 / 3 |
| Gravity: mean process / submission, ms (2 / 3 samples) | 80.900 / 96.000 | 34.867 / 51.267 |
| Gravity: WordArt advance, ms/call (2 / 3 calls) | 23.750 | 0.300 |
| Gravity: pose synchronization, ms/call (2 / 3 calls) | 22.650 | 5.833 |
| Gravity: sheet-load calls, motion / full capture | 3 / 4 | 0 / 2 |

This verifies the intended decoration-budget change while preserving observed
physical movement. It does not establish a stable speedup: there is one capture
per variant/scenario, Fill samples have differing moving-count distributions,
and the entire gravity motion phase contains only two versus three samples.
The renderer is ANGLE SwiftShader; even empty-page RAF averaged approximately
29 FPS. CPU wrappers and post-submission observers add overhead. These timings
cannot establish physical 60 FPS or GPU upload cost.

Raw evidence is in
`build/performance/jelly-massfall-baseline-fine-capture-v1` and
`build/performance/jelly-massfall-candidate-fine-capture-v1`; their corresponding
`jelly-massfall-{baseline,candidate}-fine-v1/benchmark-build.json` receipts pin
the exported sources. The read-only arithmetic/source audit and exact input
hashes are saved in
`build/performance/chrome-60fps/massfall-v1/results-audit-v1.json`, generated by
`audit-results-v1.cjs`. Shared artwork/imports/vocabulary were referenced and
were not independently frozen by these source manifests.

## Production validation

The standard `npm run build:web` succeeded, including startup-pack resource,
vocabulary, artwork, animation and audio verification. Running
`node tools/web-build-receipt.cjs --verify` then confirmed 14,127 source inputs
and 117 output files were unchanged. This receipt covers the actual production
export; diagnostic exports are not release artifacts.

The actual-export smoke used headed Chrome at 1366 x 768, normal motion/audio,
the ordinary Stage 1 game and a native mouse click on its public Fill control.
The board grew from 21 to 56 settled bodies and remained in the playing phase.
Across 32 hosted-publication observations, moving bodies peaked at 21 while
decorative owners never exceeded three. Every observed moving ID remained in
the physical active set, and no browser or game errors were recorded. This is
functional validation rather than FPS acceptance. The report and screenshot
are `build/performance/chrome-60fps/release-falling-budget-smoke-v1.json` and
`release-falling-budget-smoke-v1.png`.

Delivery verification runs after deployment against the production URL. It
compares the online index and engine bytes with this verified export and checks
HTTP availability of the versioned engine, WebAssembly and game pack. Its
release-specific result is retained in
`build/performance/chrome-60fps/release-falling-budget-production-verification-v1.json`.
Physical 60 FPS acceptance remains for the user's actual PC.
