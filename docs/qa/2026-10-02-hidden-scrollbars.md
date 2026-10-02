# Hidden scrollbars across the application

The Voice Pop microphone gate and Talk Quest treasure shelf now use the existing
gesture-aware scroll container with hidden rails. Focus reveals offscreen gate
actions and treasure cards. The shelf retains a small bottom inset for fractional
viewport scaling. Page changes, overlays, and browser input cancellation clear
pending gestures.

The Web shell and map-art credits hide standard and WebKit scrollbar chrome
globally, including dynamically created speech diagnostics. Their overflow modes
remain unchanged, preserving document, wheel, touch, and keyboard navigation.

## Verification

- Scrollbar visibility: 522 checks passed at 320 x 568 and 844 x 390, using the
  real main scene and isolated saves. The audit includes internal scrollbar nodes
  across Match, Memory, Voice Pop, Talk Quest, the room, players, and leaderboards.
- The overflowing shelf supports wheel and touch drags over art and labels, and
  keyboard focus reaches the last treasure. Compact microphone actions remain
  reachable; dragging an action does not activate it.
- Talk Quest scene: 693 checks passed.
- Voice Pop scene: 1,690 checks passed.
- Result scrolling: 66 checks passed; room scrolling: 65 checks passed.
- Web scrollbar, export, and test-runner checks: 36 passed.
- Web export succeeded with 31.63 MB compressed startup data. The verified build
  receipt was created at `2026-10-02T14:00:20.428Z` (2,313 inputs, 16 outputs).
- Live local browser checks confirmed hidden CSS rails on loading and speech
  surfaces, wheel access to the last shelf row, and keyboard document scrolling
  on the credits page. No browser console errors were recorded. The temporary
  viewport override was reset. Capture: `build/scrollbar-review.png`.

Initial tests caught native touch dragging failing after the rails were hidden,
and a fractional-scale card-edge clip. Both were fixed before the final checks.

These checks use simulated engine input and local desktop browser verification;
they do not establish behavior on a physical iPhone or Android device.
