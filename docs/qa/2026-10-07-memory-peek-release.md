# Memory eye release review

Date: 2026-10-07

The eye remains a hold control: pressing reveals unmatched cards and releasing
hides them. A trusted page-level release now reaches Memory before canvas
handlers, with the original touch identifier, so an interrupted canvas release
cannot leave the eye open. Native GUI touch input records the same ownership.
The fallback clears the native button's pressed state and restores its focus.
It ignores other pointers and leaves keyboard/controller holds unchanged.

Before the fix, ordinary automated mouse and touch release passed. Deliberately
interrupting delivery of a trusted `touchend` to the canvas reproduced the
reported stuck-open symptom: the game stayed at `Release to hide.` after the
finger lifted. This verifies the missed-release failure path without claiming
the user's specific device or event sequence was reproduced.

Validation:

- Memory peek: 291 checks passed, covering normal releases, both orders of
  touch/mouse emulation, rapid taps, multiple fingers, fallback releases,
  native GUI handling, focus cleanup, and keyboard/controller isolation.
- Memory scene: 178 assertions passed. UI recovery: 74 assertions passed.
- All 37 selected host/export Node tests passed.
- The Web export passed its resource checks with all 112 required audio
  resources and 350 word pronunciations retained.
- Four focused desktop Chromium cases passed. They cover stationary mouse-up,
  trusted touch-end, interrupted canvas delivery, rapid taps, multi-touch,
  cancellation, navigation and page suspension. The multi-touch fixture was
  corrected to update CDP's active contact set; CDP `touchEnd` lifts all contacts.
  The released-eye screenshot was inspected: the eye is closed and all ten
  unmatched cards show their backs without a further pointer movement.
- The same trusted hold/release and interrupted-delivery case passed in Android
  Chromium. At fractional mobile pixel scales, back comparisons allow less than
  0.5% changed card pixels for text-edge rasterization; reveal comparisons still
  require a visible face change. Both mobile back captures were inspected.
- Both iPhone WebKit cases passed: stationary mouse release (including
  interrupted canvas delivery) and repeated touch taps with full motion.
- The final build receipt verified 2,232 unchanged source inputs and 17 outputs.
