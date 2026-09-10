# Pip's autonomous gestures

The Learn-page marker points to Pip. He now looks left and right, stretches his
wings, waves, preens, and makes two small hops without needing a click. Each
gesture lasts 1.8 seconds; a separate random generator chooses 6–10 quiet seconds
between gestures. The five actions rotate without immediate repetition.

Only drawing changes. Pip's button bounds, word associations, lesson position,
audio and earned rewards are unaffected. Speech, pointer/focus reactions and
explicit tricks cancel idle gestures. Reduced motion, mascot visibility and
page suspension stop the idle animation loop. Returning to a page starts a new
quiet interval and does not resume audio or catch up missed gestures.

Four additional original SVG poses share the existing Pip palette and outlines.
They are imported as a small Godot texture; the original four-frame sheet used
by the HTML loading companion remains unchanged. Godot remains at 4.7.1.

## Verification

- All 23 native suites completed: 11,936 assertions/checks, zero failures.
  The new mascot checks cover all five actions, interruption, long frames,
  hidden/resumed processing, reduced motion and unchanged hit targets.
- Node suites: 97 passed, one existing external-source-pack check skipped.
  The asset inventory expectation was updated for the one additional texture;
  its compression settings and four pose identifiers are checked.
- Existing browser Pip/page/audio and Learn-mode regressions: seven passed,
  two WebKit audio tests skipped because that Windows runtime lacks AudioContext.
- New autonomous-gesture/lifecycle browser suite: all six tests passed across
  desktop Chromium and the iPhone/iPad WebKit profiles at a 390×844 viewport,
  with no page or console errors. It checks body movement, click response,
  unchanged lesson/saves, reduced motion and both visibility/page lifecycle paths.
- Original and new poses were inspected in an actual Godot-rendered contact
  sheet. Browser screenshots check the compact mascot in the portrait Learn UI.
- The new browser gesture check requires over 5% of body/wing pixels to change
  by an RGB distance greater than 60. The existing blink is a negative control:
  its lossy atlas changes PNG bytes but produces 0% meaningful changed pixels.
  The check excludes eye pixels so a blink alone cannot demonstrate new motion.
- Web export passed, including all 140 word pronunciations and 56 optional paths.
  Startup transfer is 10.96 MB rounded to two decimal places.
- Independent source review found no actionable issues.

The full native run initially stopped on the old texture-count expectation
(219 rather than 220). After updating it, the complete asset suite and the three
native suites after that checkpoint passed. No gameplay code changed afterward.

## Tested export

- Engine: `engine-b450c3c96fc33a1d`.
- Pack: `game-3303b8b7e4d83bac.pck`.
- HTML SHA256: `4a6bbb908649edf90b936ae8876e9ee0bbc9c25717f0ee8a1ede8a1c42f9049b`.
- Pack SHA256: `3303b8b7e4d83bacc24527138ab546f54329574c8f54f4a383b3a6897e5ff9bf`.

Reproduce with `npm test`, `npm run build:web`, and the `pip-idle.spec.cjs`
browser suite. The selected earlier regressions are in `godot.spec.cjs` (the two
Pip tests) and `learning.spec.cjs` (the five-association/mode-switch test).
Browser checks use isolated test profiles and leave real player profiles alone.
