# Keep matching feedback at slight touch

The hear/ear report showed a conspicuous diagonal gap while both bodies displayed
merge contact. Two effects compounded it: the preceding 28-percent / 24-pixel
approach margin activated too early, and matching pressure moved both painted
bodies away from each other as the cue strengthened.

The matching margin is now 6 percent of the shorter tile side, capped at 4 screen
pixels. Matching pressure applies a small attraction instead of repulsion, with
the same tuning in ordinary skins and active fusion lobes. Neutral and rejected
contact retain their existing displacement. Detection still uses the unpressured
painted contour so the feedback cannot repeatedly disconnect its own target.
The crowded-board matching priority from the preceding fix remains in place.
All visuals reuse the acquired artwork recorded in [Jelly Words](../assets/jelly-words.md).

## Verification

- Interaction suite: 1,833 checks, zero failures at 1000 x 720 and 390 x 844,
  with normal and reduced motion. Fixtures independently measure the closest
  unpressured painted-edge distance instead of assuming a center-distance ratio.
- Eight approach directions reject an 8-pixel gap, accept a 1-pixel gap, preserve
  the target during sustained contact, keep matching displacement toward the
  partner, and release into exactly one merge.
- Crowded carrot tests retain unrelated overlaps while selecting and consuming
  the matching target. Active-fusion tests cover distant separation, slight
  touch, early release, natural completion, and the single contact cue.
- Word Jelly view: 19,482 assertions, zero failures.
- Shared Jelly Match view: 3,084 assertions, zero failures.
- Drag performance contract: 40 assertions, zero failures.

Native before/after captures use the same input and acquired artwork. At an
8-pixel unpressured gap, the previous version advertised a merge; the corrected
version retains only the word-family hint and any actual unrelated contact.
At a 1-pixel gap, both versions accept the merge, but the corrected feedback
keeps the bodies together instead of opening a visible gap. Phone, desktop,
reduced-motion, crowded carrot, and active-fusion frames were visually inspected.
An additional fusion capture starts the close approach at 0.08 seconds so the
joining lobes are exercised before the completed result takes over.

Evidence is retained in the ignored `build/qa/close-match/` directory, including
capture scripts, PNG sequences, contact crops, `comparison.png`, and test logs.
These are native desktop renders at the stated sizes, not physical-device
recordings. There are no audio changes or listening claims in this correction.

The fresh Web build passed its packaged resource checks. Desktop Chromium and
Pixel 7 Chromium emulation both passed the manual word-picture merge flow,
including contact before release, the actual fusion, one immediate pronunciation,
and no collection. Browser and build logs are retained with the native evidence.
