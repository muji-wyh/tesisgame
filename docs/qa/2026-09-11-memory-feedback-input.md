# Memory feedback accepts the next player action

The user's screenshot showed Memory comparing a `harp` picture with `piano`.
All cards and Study were disabled until Continue, despite remaining visible
in their ordinary positions. The view restricted input and navigation to the
waiting/matching states.

The first tap on an unmatched card now acknowledges nonfinal feedback and
reveals that exact card as the next selection. Study similarly opens the
full-board study view directly from nonfinal
feedback. These actions preserve card order, geometry, attempts, planted
pairs and reward state. Feedback remains self-paced and Continue stays
available. Planted cards and final feedback cannot submit duplicate pairs;
the final Continue still completes the garden.

The view validates paused, hidden, studying, invalid and planted-card input
before clearing feedback. It continues feedback, restores actual keyboard
focus to the tapped card, then selects once. The host stops old correction
speech before playing the newly revealed word. Enter and Space therefore act
on the visible selected card instead of the hidden Continue control. The
model and host code are unchanged. Disabled Study also uses `FOCUS_NONE`,
so tapping it cannot steal Continue's focus at the end of the round.

## Regression evidence

Before the product change, the three updated native suites failed with the
expected interaction assertions, without parser errors: Memory Garden had
27 failures, Memory scene 12, and UI audio flow 4. Against the previous Web
export, the new browser case failed on desktop Chromium and iPhone WebKit:
the original card tap left the previous comparison selection unchanged.
Logs and screenshots are in `build/memory-feedback-native-red.log` and
`build/memory-feedback/red-results/`, with the browser report at
`build/memory-feedback/red-report.json`.

After the product change, the targeted native suites passed: Memory Garden
6,150 checks, Memory scene 127 assertions, and UI audio flow 68 assertions,
all with zero failures (`build/memory-feedback-native-green.log`). Coverage
includes either original mismatch card, a third card, correct feedback,
Study and Return, actual pointer focus, replacement audio, blocked input,
fixed card coordinates, unchanged scoring, and final Continue/reward guards.

An independent review of the applied product and test diffs found no
blocking issue with selection, focus, audio, or final-pair completion.

The first full `npm test` passed 27 native suites (18,687 checks/assertions)
and 100 Node tests, with one existing external chest-source skip.
Log: `build/memory-feedback-tests.log`.

The first browser run passed direct original/third/next-card selection,
keyboard selection focus, both Study/Return paths, unchanged board positions,
and all five pairs with eight attempts on desktop Chromium and iPhone WebKit.
Both then failed final Enter after a tap on disabled Study. The first run is
preserved in `build/memory-feedback/green-first-report.json` and
`green-first-results/`; no browser assertion was relaxed.

Native mouse and touch diagnostics reproduced the focus loss on both the
initial fix and the base commit: disabled Study still had `FOCUS_ALL` and
took Continue's focus. A real-pointer regression then failed two of 130
Memory scene assertions. After making disabled Study use `FOCUS_NONE`, all
130 passed. Logs: `build/memory-final-focus-diagnostic.log`,
`build/memory-final-focus-native-red.log`, and
`build/memory-final-focus-native-green.log`.

The first staged Web export was not activated or deployed.

## Final verification

The final `npm test` passed all 27 native suites (18,690 checks/assertions,
zero failures) and 100 Node tests, with the same one external chest-source
skip. Log: `build/memory-feedback-tests-final.log`. Independent review also
confirmed the disabled-focus fix and that the real-pointer/Enter regression
cannot be masked by the older synthetic Continue in the test.

The final `npm run build:web` passed, including 140 word pronunciations and
56 optional path checks. Startup transfer remains 12.11 MB with 28 on-demand
audio assets. Log: `build/memory-feedback-build-final.log`.

The final frozen export was verified through HTTP on port 4181:

- Pack: `game-8106acc9244b864e.pck`.
- Pack SHA256: `8106acc9244b864e6a7b11222476ee8d9541f60033fd23a84611b95b4f937622`.
- HTML SHA256: `5ef3a77cfc2f97016dda75a964c486eba4836ffca2694b70e5a627aabdf71782`.

All 71 exported files were copied to a fresh staging directory under the main
preview's build directory and individually matched by SHA256. Manifest:
`build/memory-feedback/preview-stage-final-manifest.json`.

Both unchanged browser cases passed against the final local export in 69.5
seconds: desktop Chromium and iPhone WebKit, with zero failures, skips or
flaky cases. They cover the full feedback-to-selection and Study flows,
unchanged coordinates and scoring, blocked final input, and Enter completing
the round after tapping disabled Study. The cases use the silent-audio path;
pronunciation replacement is verified by the native audio-flow suite.
Reports and screenshots: `build/memory-feedback/green-report.json` and
`green-results/`. Independent screenshot review confirmed the selected
card's focus, enabled Study, final Continue's retained focus, and the phone
victory screen without clipping.
