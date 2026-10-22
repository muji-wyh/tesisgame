# Match guidance on the painted jelly surface

The reported peach highlight covered nearby space with violet portal wisps, a
thick purple contour, and two large gold stars. Matching guidance now uses a thin
amber contour with a cream keyline, one small ivory reflection, and a slower
surface sweep. Skin breathing is reduced from 3.5-5.5 percent to 1.5-2.3 percent.
The enlarged matching halo is removed entirely.

The reflection reuses the acquired Toon FX sparkle and the contour follows the
existing Jelly Squash paint; source, creator, license and integration details
remain in [Jelly Words](../assets/jelly-words.md). No new asset was acquired.
Merged-word readiness keeps its established art. Candidate eligibility,
cross-level word-family hints, green contact feedback, and the slight-touch
threshold are unchanged. Reduced motion keeps the contour and reflection still.

## Verification

- Word Jelly view: 18,732 assertions, zero failures. The first full run reached
  its local runtime limit with no assertion failure; a rerun with a longer process
  allowance completed successfully. Both logs are retained.
- Interaction: 1,701 checks, zero failures, covering cross-level hints, crowded
  contact, active fusion dragging, cancellation, and advertised drops.
- Hybrid tile presentation: 584 checks, zero failures, including all merge levels,
  picture/word layout, projection cleanup and reduced motion.
- Tile presentation performance: 36 checks, zero failures.
- Drag performance: 40 assertions, zero failures.

Native phone and desktop frames, reduced-motion frames, and same-word merged
levels were visually inspected. The before/after comparison uses the same peach
fixture and input with the preceding tile script retained separately. A 78-frame
phone sequence covers 2.6 seconds of the new cue; sampled frames were inspected
through the breathing and sweep cycle. These are desktop renders at the stated
viewport sizes, not physical-device recordings. No audio was changed.

Evidence is retained in the ignored `build/qa/match-polish/` directory: baseline
scripts, capture scripts and PNGs, `comparison.png`, `matching-highlight.mp4`, and
test logs. Earlier capture setup failures were corrected before collecting the
reported frames.

The fresh Web build passed its packaged resource validation. Desktop Chromium
and Pixel 7 Chromium emulation both passed the manual matching flow: contact
before release, one accepted fusion, immediate pronunciation, and no collection.
Build and browser logs are retained alongside the visual evidence.
