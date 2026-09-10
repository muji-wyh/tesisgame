# Memory Garden release verification

## Scope

Memory is the fifth practice mode. Ten fixed cards conceal the lesson's five words and
five pictures. Matched pairs remain visible and grow flowers. Study reveals the same
board without scoring; Return to play preserves positions and completed pairs.
Feedback teaches the actual associations until Continue. Exploration has no timer or
three-mistake loss and does not enter the missed-vocabulary list. Five pairs use the
existing one-piece chest claim and persistence; Repeat keeps the lesson and world.

The game retains its Godot runtime, original word illustrations, pronunciation audio
and existing saves. No external assets or new dependencies were needed for this mode.

## Native and Node checks

- `npm test` passed, followed by `npm --ignore-scripts test` after the final focus fix:
  20 native suites, 11,737 checks, no failures or engine warnings.
- The Node suite passed 89 cases; one pre-existing external source-pack checksum test
  was skipped because that optional source pack is unavailable.
- The initial clean worktree's deployment fixtures required a Web export. After the
  first build all deployment cases passed, including wrong target and token-environment restoration.
- Independent final code review found no remaining blockers.

Regressions found and fixed during implementation:

- Return from My rewards now restores Memory focus after modal focus restrictions lift.
- Replaced cards disconnect their callbacks before deferred deletion, so stale input
  cannot reveal a card in the new round.
- Short square layouts use the wide board; feedback recomputes its minimum after
  leaving a tall layout.
- Five mode tabs share the available width and fit their labels on narrow native windows.
- Disabled Memory cards no longer steal focus from Return to play in Study. The native
  regression sends actual viewport mouse press/release followed by Enter; the browser
  regression uses the same interaction. Paused and planted cards also relinquish focus.

## Browser and visual checks

Tests use normal canvas input and announced card discoveries, not private hidden-card
state. Existing-mode regressions use a frozen export on port 4174; final Memory checks
use port 4175. The existing 4173 preview is preserved.

The first Memory browser pass reproduced the Study focus defect on desktop Chromium,
iPhone WebKit and iPad WebKit. Victory, one-piece persistence, replay, keyboard, Xbox
and small-layout cases passed on all three. The final pass retains the failing
disabled-card tap followed by Enter as a regression assertion.

- Final Memory coverage passed all nine cases across desktop Chromium, iPhone WebKit
  and iPad WebKit. The first final run passed eight and exhausted the 90-second total
  budget in the iPad discovery case while another WebKit suite ran concurrently.
  Its Study-return assertion had already passed. The unchanged case passed alone in
  17.4 seconds; neither assertions nor timeout were relaxed.
- Existing-mode regression coverage includes 129 cases: learning, adventure book,
  expansion, voice, Xbox, chest, rewards, fragments, hints, orientation and motion.
  The frozen pre-focus export differs only in disabled Memory card focus behavior.
  The broad run passed 127 cases; both WebKit Sky cases lost their WebGL context and
  produced blank captures. Both unchanged cases passed with no console errors in
  fresh isolated runs (6.8 and 7.3 seconds), completing the 129-case coverage.
- The final isolated run passed all five selected cases: those two Sky cases, iPad
  discovery/Study/modal preservation, and both WebKit small-layout/input cases.
- Desktop, phone and tablet Study, planted pairs, teaching feedback, victory and
  replay images were inspected. Native and Chromium checks cover 320-pixel portrait,
  square and 640-pixel landscape layouts without clipped controls.

Windows WebKit capture limitation: page screenshots after emulated square/landscape
resize can be blank even while the canvas renders correctly. A separate isolated
diagnostic recorded six stages with matching, varied internal and visible framebuffer
pixels, correct canvas/renderbuffer/viewport sizes, no context loss, and no GL errors.
Canvas PNGs show all ten cards; both page screenshot scales can still be blank after
resize. A fresh landscape load captures correctly. This identifies a downstream
compositing/capture issue in this runtime; it does not prove how a headed or physical
Safari browser behaves. No engine workaround or test assertion was changed for it.

Evidence is retained locally in `test-results/memory-final`, `memory-isolated`,
`memory-regressions` and `memory-resize-diagnostic`. These are Windows browser device
profiles, not physical iPhone/iPad tests; the real-device caveats in README still apply.

## Artifact and production

- Export command: `npm run build:web`.
- Startup download: 10.90 MB, including all 140 word pronunciations; 28 optional audio assets.
- Pack: `game-3c36a28c7c403f12.pck`.
- SHA256: `3c36a28c7c403f12432cb08f88bc2a868ecddff6668a38a2631a6107a75f4fe1`.
- One earlier Godot import process exited with access violation `0xC0000005` after its
  reimport pass. A separate import retry and the complete final build then exited zero.
  No failing export was deployed.

Production verification pending.
