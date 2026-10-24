# Memory mismatch dismissal - 2026-10-24

Mismatched cards remain face up until the player completes another card click.
Clicking either exposed card or an already matched card only hides the mismatch.
Clicking a different concealed card also starts the next selection, with its
answer still hidden. Correct pairs keep their existing automatic continuation.

Dismissal does not add attempts, mistakes, learning evidence, rewards, or outcome
audio. Peek, invalid indices, paused/hidden input, and stale timer callbacks cannot
dismiss the mismatch. Restart and stop clear it normally. Existing artwork is
unchanged.

## Verification

Eight native Godot suites passed with 78,397 checks/assertions and zero failures:

- Memory model: 812
- Memory garden: 76,009
- Memory Peek: 290
- Memory Peek payment: 98
- Memory reward UI: 559
- Memory scene: 232
- UI audio flow: 310
- UI recovery: 87

The mouse cancellation fixture now sends the movement between press and release.
The responsive header fixture waits for the newly visible eye button's container
layout and advances the countdown relative to its remaining time. The initial
header overlap was also reproduced with the original Memory runtime. Header-only
checks passed against both runtimes after those fixture corrections. Diagnostics are in
`build/qa/memory-mismatch-click/`.

The Android observation fixtures now accept the real observation expiring before
the skip gesture. Each card tap reuses one bounds snapshot rather than reading
the canvas twice. The new multi-attempt browser case uses the existing long-test
budget of 180 seconds: its first Android trace showed the third mismatch correctly
revealed at 118.51 seconds, just before the former 120-second test limit.
Interaction screenshots use one device pixel per CSS pixel, matching the existing
audio fixture, while retaining each phone viewport and touch input. High-DPI
emulation produced GPU readback stalls and exceeded the full-round test budget;
those partial runs are retained separately from the final CSS-resolution run.

The final web build passed, including packaged resource verification. Eight
focused browser cases passed across desktop Chromium and Android emulation:
normal/reduced-motion full rounds, persistent mismatches and all three follow-up
clicks, and synchronized outcome audio with silent dismissal.

Evidence is retained under `build/qa/memory-mismatch-click/`:

- `browser/`: the first three passing desktop cases, completed before the initial
  runner was interrupted.
- `browser-resume/`: passing desktop dismissal and Android audio cases, plus the
  earlier Android timing failures.
- `browser-final-css/`: all three final Android interaction cases passed; their
  log and status record distinguish them from the partial high-DPI attempts.
- `final-build.log` and `final-build-status.json`: the final successful export.

Desktop and phone captures were visually checked for readable wrong-pair faces,
stable board/header positions, and a concealed next selection. The exported
screen-reader help was also checked against the new behavior.

## Existing unrelated check

The broad accessible-help Node contract in `tests/web-export.test.cjs` still fails
on its unchanged Jelly Words expectation for same-level merging through Lv9.
Current Jelly help describes adding levels through Lv6. The Memory help now
describes click-driven mismatch dismissal; this change does not alter Jelly rules.
