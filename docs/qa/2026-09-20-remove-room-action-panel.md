# Remove the room action panel

Removed the separate step caption and toy action button beneath Pip's room.
The toy catalog follows the room directly. The toy itself still supports tap,
keyboard and controller activation for its three stages and replay. Selecting
an owned toy card leaves a locked preview.

Interaction feedback remains in the accessibility status announcements without
creating a hidden UI control. Newly unlocked gifts focus the toy itself. Room
load failures appear on the affected toy card, preserving the retry action.

## Verification

- All 1,544 assertions passed across the 10 affected native suites and the
  existing legacy-save and UI-recovery suites. Coverage includes direct toy
  clicks, controller activation, replay, preview exit, focus, audio and saves.
- The Web release build passed pack verification with no missing resources
  (14.95 MB startup; 200 pronunciations and eight slice sounds bundled).
- All 15 targeted browser cases passed across desktop Chromium and emulated
  iPhone/iPad WebKit after the affected cases were rerun. Coverage includes
  direct toy activation, replay, locked preview exit, narrow keyboard controls,
  saved gift goals and recovery from an initial storage read failure.
- The storage-recovery fixture now expects the actual startup recovery message,
  and its focus helper handles the deliberately blocked storage read. Normal
  startup assertions remain unchanged. The visible load error stays on the toy
  card, and choosing an owned card retries successfully when storage recovers.
- One initial iPhone-profile tablet run reached the 90-second test limit while
  traversing focus at DPR 3. Trace review found slow cumulative frame waits,
  not a stuck game action; the unchanged case passed on rerun in 30.5 seconds
  without increasing the timeout. WebKit checks ran on Windows emulation,
  not physical Apple devices.
- Real exported-game screenshots were inspected at 390×844, 768×1024 and
  1366×768. The caption and long button are gone, and the catalog follows the
  room without a blank placeholder. Each viewport completed all three apple
  stages using mouse, Enter and Space, replayed, previewed a locked toy, then
  returned through the owned apple card and played again. There were zero page
  or console errors, and medal ownership remained unchanged.

Browser evidence: `build/voice-pop-qa/remove-room-action-panel-browser`,
`build/voice-pop-qa/remove-room-action-panel-recheck` and
`build/voice-pop-qa/remove-room-action-panel-recovery`.
Screenshot evidence: `build/voice-pop-qa/remove-room-action-panel-local`.
