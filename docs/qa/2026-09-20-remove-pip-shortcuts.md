# Remove Pip room shortcuts

Removed the Pet, Poke, Toss and Call button row, including its layout space and
keyboard focus entries. The room now leads directly into the shared interaction
caption, primary toy action and toy catalog.

Direct Pip taps and strokes, floor movement and toy dragging remain available.
The caption still reports toy stages, direct interactions and locked previews.
Saved toys, goals and medals are unchanged.

## Verification

- Native playroom view, playground, room scrolling and collection navigation
  checks passed: 384 assertions, zero failures.
- The Web release build passed pack verification with zero missing resources
  (14.94 MB startup; 200 word pronunciations and eight slice sounds bundled).
- All 12 playground browser cases passed across desktop Chromium and emulated
  iPhone/iPad WebKit, including direct gestures, interrupted drags, remaining
  keyboard controls and reduced motion at 320 px. WebKit ran on Windows, not
  physical Apple devices.
- Real exported-game screenshots were inspected at 390×844, 768×1024 and
  1366×768. The shortcut row is gone without a blank placeholder. Each viewport
  passed all three apple stages using mouse, Enter and Space with zero page
  errors; toy ownership and medal saves remained unchanged.
- The 320 px saved-gift keyboard/replay browser case passed. Four scroll cases
  also passed, covering the room, locked preview and medal list. The screenshot
  comparison now starts below the measured fixed header instead of a stale
  170 px coordinate; the original ±2 px tracking assertions remain unchanged.
  The final targeted browser total is 17 passing cases.

Local evidence: `build/voice-pop-qa/remove-pip-shortcuts-browser` and
`build/voice-pop-qa/remove-pip-shortcuts-local`. Scroll evidence is in
`build/voice-pop-qa/remove-pip-shortcuts-scroll`; the saved-gift pass is in
`build/voice-pop-qa/remove-pip-shortcuts-navigation` alongside the initial
fixed-header sampling failures.

## Production

Runtime commit `7769442` was merged into `main`, pushed and deployed. All four
startup files match the tested export by SHA-256; see
`2026-09-20-remove-pip-shortcuts-production-manifest.json`.

The actual production game passed the apple's three steps at all three tested
viewports, with zero page errors and unchanged medal ownership. Phone and tablet
screenshots were inspected again: the removed row leaves no empty space and
the primary toy action remains reachable. Evidence:
`build/voice-pop-qa/remove-pip-shortcuts-production`.
