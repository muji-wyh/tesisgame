# Stronger matching glow

Following the clean matching-highlight release, the user requested a modestly
larger glow. Matching targets now have a soft amber bloom that follows the
acquired skin's distance field and fades within about five pixels at the common
phone tile size. Inverse UV mapping keeps the painted body's size fixed while
padding the rendered light. Surface sweep strength rises from 0.65 to 0.95, the
contour is brighter, and the ivory reflection's size cap rises from 14 to 18
screen pixels. Its existing breathing and sweep timing are retained.

Idle merged readiness stays at strength 0.35, below the new bloom threshold.
Contact keeps the established rim color. Matching rules, collision distances,
input geometry and rewards are unchanged. Reduced motion uses steady light.
All source and license records remain in [Jelly Words](../assets/jelly-words.md);
no artwork or audio was acquired.

## Verification

- Interaction: 1,701 checks passed.
- Hybrid tile presentation: 584 checks passed.
- Tile presentation performance: 36 checks passed.
- Drag performance: 40 assertions passed.
- Native renders inspected at phone and desktop viewport sizes, including green
  contact feedback, reduced motion and matching merged words across levels.
- Sampled frames from a 78-frame, 2.6-second sequence were inspected through the
  sweep and breathing cycle. These are desktop renders, not physical-device
  recordings; no acoustic change or playback claim is made.

Evidence is retained in the ignored `build/qa/match-glow/` directory: the previous
release's matching fixture captures, source snapshots, updated captures,
`comparison.png`, `matching-glow.mp4`, capture scripts and check logs.

The fresh Web build passed packaged-resource validation. Desktop Chromium and
Pixel 7 Chromium emulation both passed the manual matching flow, including
contact before release, exactly one accepted fusion, immediate pronunciation,
and no collection or browser errors. The packaged core is
`game-b2856a2a2fefd874.pck.br`; build and browser logs accompany the captures.
