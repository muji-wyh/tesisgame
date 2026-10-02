# Mobile player-name keyboard reopening

The phone viewport can shrink when its virtual keyboard opens. Crossing the UI scale boundary rebuilt the player form and replaced its active `LineEdit`. That replacement dismissed the native browser editor during the resize and left subsequent editing inconsistent.

The fix defers a scale-driven form rebuild while the name field is focused and editing. The existing input keeps its text, caret, and selection; the pending scale update applies when editing ends. The existing 16 CSS-pixel native editor font remains unchanged to prevent iOS focus zoom.

Ending editing by pressing Create or Save also defers the rebuild until the pointer release has reached the button. A native regression reproduced the first release being swallowed for both mouse and emulated touch when a shortened viewport still had a pending scale change. The baseline produced eight failures across the four creation/editing gestures: `build/keyboard-submit-gesture-baseline.log`.

## Reproduction and validation

- The ordinary native-blur/reopen baseline passed on iPhone WebKit. Android Chromium completed the reopening cycles but exceeded its earlier time budget at the final Save action.
- The viewport baseline reproduced the failure on iPhone WebKit: after changing `390 × 844` to `390 × 350`, the focused native-input count became zero. Log: `build/keyboard-viewport-baseline.log`.
- Native regression suite: 402 checks passed, including pointer-held Create/Save and drag-out cancellation. Log: `build/keyboard-submit-gesture-fixed.log`.
- Node host tests: 35 passed. Log: `build/keyboard-reopen-host.log`.
- Browser coverage includes repeated blur/reopen cycles, retapping with native focus retained, IME text, draft preservation, profile creation and editing, and viewport shrink/restore. The original Tab/Escape navigation test remains in place. Failed tests attach native-editor, focus, viewport, canvas, and player-state diagnostics.
- Final Web export passed: 20.46 MB startup pack, including the pointer-release fix. Log: `build/keyboard-reopen-release-web-build.log`.
- All six mobile browser cases passed across iPhone WebKit and Android Chromium. Five cases passed in `build/keyboard-reopen-final-browser.log`; the focused iPhone viewport case passed in `build/keyboard-viewport-render-verified.log`.
- After adding the pointer-release fix, both affected viewport cases passed again against the final Web export (iPhone WebKit: 48.6 seconds; Android Chromium: 3.8 minutes). Log: `build/keyboard-reopen-release-browser.log`. The other browser cases and Node host tests were not repeated because the additional change is limited to applying a pending viewport scale.
- Raw canvas captures from the iPhone viewport case and Android page captures were visually inspected. Both creation and editing forms retain the entered name and complete layout after viewport recovery.

Windows WebKit has an existing page presentation/capture limitation after live viewport resizing, documented in `docs/qa/2026-09-11-steady-gameplay.md`. In this run the native editor remained visible over an otherwise blank page capture, while the raw game canvas rendered the complete form. The test retains the page, a uniform top-quarter crop, the raw canvas, and color-count diagnostics. The exception is limited to Windows WebKit with that exact signature; it does not establish that the affected WebKit window displays correctly.

Browser tests use device emulation. They verify native DOM editor focus and input behavior; they do not directly verify a physical phone's operating-system keyboard visibility.

Deployed with the Talk Quest word-battle release on October 2, 2026. The
production export matches the tested local release by SHA-256; see
`build/quest-words-production-verification.log`.

Release: https://gentle-forest-02ff42900.3.azurestaticapps.net/?v=e35979cd80496b74
