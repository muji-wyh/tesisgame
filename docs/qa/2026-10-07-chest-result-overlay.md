# Chest result overlay

Match and Memory now dedicate the result area to the existing chest artwork and
animation. The result word strip, its replay/scroll handlers, and the secondary
toy action were removed. Unlocked toys remain available in Pip's room.

New adventure is hidden until opening finishes and the reward has saved. It then
appears at the bottom-right as a 240 by 56 CSS-pixel overlay, inset by 16 pixels
inside the existing safe content area. The chest keeps the same full-size stage
through closed, opening, opened, and recovery states. Save failures retain a
visible message and a separate Retry saving overlay; neither can skip or duplicate
the pending reward. Controller focus waits for the completed result action.

No artwork, audio, reward rules, or asset licenses changed.

## Verification

- Captured the previous desktop result at the same viewport for comparison.
- Native result checks cover Match and Memory, unopened and opening action
  guards, saved and pending rewards, full-stage bounds, no layout shift, focus,
  modal isolation, and touch targets from 320-pixel layouts to desktop.
- Updated the existing navigation, gift, recovery, audio-click, and vocabulary
  suites to remove assumptions about the retired result controls.
- All 14 focused native suites passed, including 175 adventure-scene assertions.
  The broader 900-lesson vocabulary layout sweep exceeded its 180-second runner
  limit without reporting an assertion failure; it is not counted as a pass.
- Seven desktop Chromium browser scenarios passed: Match and Memory opening and
  continuing, controller handoff, phone-sized rendered button visibility, gift
  play and reload, two saved rounds across reload, and failed-save recovery.
  The first pass exposed an obsolete Picnic test word list and an insufficient
  two-round timeout; both fixtures were corrected and the two scenarios passed
  on rerun. No game behavior was changed to accommodate those fixture issues.
- Inspected desktop and phone-sized screenshots of closed/opened chests, plus
  the saved Memory reward and the visible save-error/retry state.
- Android Chromium passed the closed/opened/next-adventure flow. iPhone WebKit
  passed failed-save recovery. The iPhone screenshot exposed a collision between
  the save notice and the world badge; save notices now temporarily replace that
  badge. All 69 collection-polish assertions and the iPhone recovery scenario
  passed after the adjustment; the final screenshot confirms separated text.

Local evidence is under `build/chest-overlay/` (ignored). These checks use browser
device profiles, not physical phones. The packaged export verifies all required
audio, chest models, and word assets. Its receipt covers 2,232 source inputs and
17 output files. Deployment verification compares all 11 public file hashes
against that receipt and records `build/presentation-production-verified.json`.
