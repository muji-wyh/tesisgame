# Growth morphology completion

The separate morphology overlay covers every original Growth vocabulary record. No original vocabulary identity, spelling, age, part of speech, meaning, media reference, practice mode, or saved-learning identity was replaced.

| Age | Reviewed | Atomic | Compound | Morphological |
| --- | ---: | ---: | ---: | ---: |
| 3 | 80 | 80 | 0 | 0 |
| 4 | 99 | 97 | 0 | 2 |
| 5 | 188 | 171 | 8 | 9 |
| 6 | 272 | 237 | 6 | 29 |
| 7 | 284 | 212 | 25 | 47 |
| 8 | 184 | 120 | 26 | 38 |
| 9 | 177 | 129 | 21 | 27 |
| 10 | 101 | 77 | 12 | 12 |
| 11 | 76 | 43 | 10 | 23 |
| 12 | 89 | 54 | 6 | 29 |
| Total | 1,550 | 1,220 | 114 | 216 |

There are zero pending entries. All 265 original context-only image gaps remain explicit and unchanged. The source registry contains 159 named sources.

The recorded reviewer is **Codex (AI editorial review; not human approval)**, dated 2026-10-16. Each decision has its own rationale and references. These records do not claim human editorial sign-off. Missing authored decisions remain pending and fail the release audit; there is no suffix classifier, automatic midpoint split, or blanket atomic fallback.

## Verification

- Normal validator: zero errors.
- Release validator: zero errors and `release_ready: true`.
- Node morphology suite: seven tests, zero failures.
- Native morphology suite: 20,503 assertions, zero failures.
- The native shared-catalog resolver executes every authored join across all 1,550 records.
- Fourteen three-part cases check explicit intermediates, invalid nonadjacent joins, two-step automatic plans, and assisted ancestry that cannot earn manual-composition mastery.

The inventory fingerprint is:

`5a255c8afb15e7592c656236d537a6c33dc048699a6f6b8451bc81b8d876b24b`

The generated evidence is stored at:

- `build/professional-english/growth-morphology-audit.json`
- `build/professional-english/growth-morphology-release-audit.json`
- `build/professional-english/growth-morphology-node.log`
- `build/professional-english/growth-morphology-native.log`

## Authored drag regression

Browser-test migration exposed a physics regression: an authored body's original footprint remained invisible support after the body was lifted. A native test using the real reviewed Growth `cat` reproduced the failure. Lifted authored bodies now use a moving return reservation with their full fixed dimensions for incoming supply and growth. Gravity ignores that reservation, allowing unsupported neighbors to fall while the pointer remains held.

An additional crowded-board regression exposed a fragmented return: lifting a three-cell body below an offset bridge could leave only disconnected one-cell and two-cell gaps. A geometry-only preflight now declines that lift before changing any live body. Immediate settled falls remain allowed and their vacated cells become available immediately. The full-size return reservation also stays clear of delayed fall paths, including pending merge and collection outcomes. Incoming supply and its enabled state use the same check, so a new body cannot fall through the only remaining return rectangle. A neutral, temporary "Make room before moving this jelly." notice explains the blocked move without a wrong-answer sound.

Verification:

- Authored-drag native suite: 77,095 assertions, zero failures across twelve naturally supplied crowded boards and two deterministic crowded fixtures. It checks real falling while held, lift and cancellation, arrivals while held, exact dimensions and contents, fragment conservation, released drag identities, actual support, and nonoverlap. Unsafe lifts preserve the complete board unchanged.
- Existing Word Jelly model suite: 112,155 assertions, zero failures.
- Existing morphology model suite: 476 assertions, zero failures.
- Morphology view suite: 117 checks, zero failures, including readable room feedback, no negative audio, and expiry without moving the board.
- An isolated negative-control subclass that uses only the current free rectangle reproduces nine failures in the two deterministic fixtures, including a stuck lifted body, overlap, and unsafe incoming supply. Production files were not reverted for this control.

Logs are in `build/tests/jelly-final/{authored-drag-native,authored-drag-baseline,model-native,morphology-native,morphology-view-native}.log`. Browser acceptance for the final export is tracked separately; a run interrupted by host resource contention is not a pass.

## Browser acceptance on the immutable r2 export

The focused desktop Chromium batch passed **5/5 tests**, with zero failures, skips, or flaky outcomes, in 692.4 seconds. Its immutable export receipt is `2026-10-15T18:03:07.157Z`, with startup pack `game-1a90f99d3b178ad7.pck.br`. The run started at `2026-10-15T18:25:42.962Z` and used one worker with no retries.

- Collecting a real lower word removed its sole support and produced distinct start, intermediate rendered fall, and supported landing positions for the upper stack.
- Lifting a real lower word allowed its upper stack to fall while the pointer remained held. Cancellation preserved each original body's text, mass, fixed dimensions, word, fragments, and composition, without overlap.
- The age-three atomic case used `dance`; the age-twelve two-part case used `quadrilateral`; the age-twelve three-part case used `binoculars` with its explicit `binocular` intermediate and authored spelling change. The tests reached these words through ordinary supply, completion, and collection controls.
- All three cases retained their measured logical footprints across 1366-by-768, 390-by-844, and 393-by-852 viewports. Every spelling character remained represented, displayed labels stayed at or above the sixteen-pixel reading floor, and completed-word collection used the same fifty-coin reward at a one-percent chance.

The actual falling-frame and complete-word screenshots were inspected for readable labels and unobstructed presentation. Test sources, helpers, configuration, vocabulary, and ten morphology overlays were captured as seventeen inputs; SHA-256 comparisons before and after the batch found no changes.

Evidence is in `build/tests/jelly-r2/core-desktop-report.json`, `core-desktop.log`, `core-desktop-results/`, and `core-desktop-source/`. This result covers the five selected Chromium cases on r2. It is not a claim that the remaining Word Jelly cases, iPhone WebKit, or a later export have passed.
