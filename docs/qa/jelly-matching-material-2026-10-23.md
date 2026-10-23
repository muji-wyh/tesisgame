# Matching light within the jelly material

The amber outline and uniform outer bloom read as a separate frame around the
jelly. Matching guidance now uses a bright wet crown, transmitted lower-shoulder
light and directional spill drawn from the acquired skin's own palette. The
matching border and added star sprite are removed. A sheen crosses the skin in
the first second of each three-second cycle; the existing 1.5-2.3 percent skin
breathing is retained. Lettering, pictures and input geometry stay fixed.

Expanded-light inspection exposed clamped distance samples outside the source
texture, which could leave straight edges on the glow. The distance field now
continues beyond that transparent margin, letting the light fade before the
expanded mesh ends. Green merge contact keeps its separate contour. Idle merged
readiness remains below the new material-light threshold and retains its previous
color response and sourced decorations. Reduced motion keeps the light steady.

The acquired Jelly Squash paint and its derived distance field provide the
shape and color; no new artwork or audio was acquired. Source, creator, license
and integration records remain in [Jelly Words](../assets/jelly-words.md).

## Verification

- Word Jelly view: 17,983 assertions passed.
- Interaction: 1,569 checks passed.
- Hybrid tile presentation: 584 checks passed.
- Tile presentation performance: 36 checks passed.
- Drag performance: 40 assertions passed.

Existing presentation checks now inspect the active material light, clearing
and reduced-motion stability instead of counting the removed star sprite.
Phone and desktop viewport captures were inspected, including plain word
targets, merged targets across levels, green contact, reduced motion and five
palette colors. Sampled frames from a 78-frame, 2.6-second sequence were inspected
through the sheen and breathing cycle. These are desktop renders at the stated
viewport sizes, not physical-device recordings or an acoustic evaluation.

Evidence is retained in the ignored `build/qa/match-material/` directory: source
snapshots, the preceding release's fixture captures, updated PNGs,
`comparison.png`, `matching-material.mp4`, capture scripts and test logs.

The fresh Web build passed packaged-resource validation. Desktop Chromium and
Pixel 7 Chromium emulation both passed the manual matching flow, including
contact before release, exactly one accepted fusion, immediate pronunciation,
and no collection or browser errors. The packaged core is
`game-90051dae3a15e6ca.pck.br`; build and browser logs accompany the captures.
