# Matching target enlargement and breathing

Eligible Jelly Words targets grow to 112 percent over 200 ms, then remain between
112 and 114.5 percent through each 2.2-second breath. Each newly eligible target
gets its own entrance, including targets that arrive during a long hold. Changing
the source restarts the entrance; cancellation and projection clear the scale.
Reduced motion retains steady material lighting without enlargement.

The existing acquired gel skin supplies the effect. Pictures, lettering, badges,
logical size and contact geometry stay fixed. No new artwork or audio was acquired;
source and license records remain in [Jelly Words](../assets/jelly-words.md).

Verification completed with zero failures in the focused native suites:

- Word Jelly view: 17,814 assertions.
- Interaction: 1,569 checks.
- Hybrid tile presentation: 1,334 checks, including more than two held cycles,
  late eligibility, source changes, contact, cancellation and reduced motion.
- Tile presentation performance: 36 checks.

The fresh Web export passed packaged-resource verification. Desktop Chromium and
Pixel 7 Chromium emulation passed the current-stage enlargement/breathing/cancel
test and the existing manual merge/pronunciation test. The sampling test now
collects consecutive frames inside the browser and allows the measured software
rendering runtime; an earlier phone run exceeded its original 90-second budget.

The older ordered-root browser scenario failed during fixture setup: it searches
for a two-root word while the current opening stage supplies atomic word/picture
pairs, eventually filling the well. It never reached the highlight assertions.
The new current-stage test exercises the requested effect with ordinary inputs.

Phone and desktop native renders, merged levels, reduced motion and sampled
frames from a 4.8-second sequence were inspected. These are desktop renders and
browser device emulation, not physical-device recordings. Evidence, comparison
images, the sequence video, test logs and initial failure traces are retained in
the ignored `build/qa/match-scale/` directory.
