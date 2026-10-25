# Jelly Words combo presentation

The combo HUD combines the model's rank and exact count with a brief local
flourish on each increase. The rank letters use the existing Nunito heading
font. Count and reward text stay above the artwork. A positive merge reward
adds a larger gold acknowledgement explicitly labelled **COMBO BONUS**, alongside
the acquired gold coin and exact increment. A collection-only increment cannot
erase a still-visible acknowledgement of a preceding paid merge.

The component does not decide rank thresholds, award coins, reset the chain,
play sound, or run a separate gameplay timer. Its owner supplies state and
advances the presentation clock. Repeated state publication does not replay
the flourish. The model supplies an eight-second remaining-time value, rendered
as a full-width countdown bar; expiry or a wrong merge clears the current chain.
The bar turns warm red during the last quarter. Pause, saving waits and automatic
matching freeze the authoritative clock. Zero count hides the HUD. Reduced motion
retains the real countdown, rank, count and reward readout with static artwork
and no scaling or travel.

## Acquired artwork

| Runtime material | Original source, creator and license | Acquisition and animation status |
| --- | --- | --- |
| `assets/chests/particles/portal_glow.png` | `Particles/Textures/portal_glow.png`, Modern 2D Animated Chests Pack_FREE Demo 1.0.2 by Bobardo; Standard Unity Asset Store EULA | Previously acquired and integrated static texture. Original mapping is retained in `assets/chests/SOURCE.txt` and `assets/chests/manifest.json`. Used for local colored light. |
| `assets/chests/milestone/rays.png` and `sparkle.png` | `Textures/glowlines.png` and `Textures/sparkle.png`, [Toon FX 1.52](https://assetstore.unity.com/packages/vfx/particles/toon-fx-25601), Kenneth Foldal Moe / Archanor VFX; [Standard Unity Asset Store EULA](https://unity.com/legal/as-terms) | Previously acquired private package inputs, integrated byte-for-byte. Static radial rays and a four-point glint; source hashes, restoration and license evidence remain in [Jelly fragments](jelly-fragments.md#extra-motion-textures). |
| `assets/coins/gold-coin.png` | `Textures/coins.png` from the same acquired Toon FX 1.52 package, creator and license | Existing 128px front-face adaptation with original bevel, shading and alpha. The warm gold conversion, original source hash, output hash and acquisition record remain in [Gold coin artwork](coins.md) and `assets/coins/manifest.json`. It is a static authored view, not a spin flipbook. |
| `assets/fonts/heading.tres` | Existing Nunito heading font under the SIL Open Font License | Already integrated typography; original source and license remain in `assets/fonts/SOURCE.md` and `assets/fonts/OFL.txt`. |

The actual integrated particle textures were inspected over a dark background,
and the acquired gold face was inspected before presentation work. These are
production inputs, not source previews. No new image acquisition, reference
video extraction, branded rank artwork, or third-party game sound is included.
The energetic rank/count hierarchy is original interface presentation.

## Motion and bounds

The supplied HUD rectangle reserves the complete text pop, local rays and
sparkles. The count changes immediately, grows briefly, and settles in 420ms;
the artwork recovers within 560ms. Successive increments share a bounded
flourish instead of accumulating emitters. The coin acknowledgement lasts at most
1.8 seconds and has its own warm outlined reward band. Ordinary rail slots
reserve 196 x 72 display pixels, with compact header/footer alternatives and
font fitting for narrow layouts. The sourced coin face can reach 24 display
pixels; the amount is independently fitted rather than relegated to the old
twelve-pixel detail row. Idle artwork stays still while the time bar drains.

The source textures receive runtime placement, tint, rotation, scale and
opacity. No Unity prefab, script or source animation is executed. The whole
component ignores input and clips cosmetic artwork to its assigned slot; the
view owns placement relative to Finish, stage progress and collected-word
cards. Sound and rewarded-state verification belong to the integrated view
and model checks rather than this visual asset record.

Isolated native stills review the seven ranks at 180 x 48 pixels, 128 x 42 and
144 x 56 compact slots, long exact counts, reward recovery and reduced motion.
The focused fixture also checks repeated state, rapid 140ms increments,
continued idle visibility and reset cleanup. These are component captures,
not integrated gameplay, normal-speed audio, or physical-device evidence.

Integrated native fixtures additionally exercise local and hosted headers,
phone/tablet/desktop sizes and short landscape with real merge and collection
operations from seeded states. The owner uses an existing footer slot beside
Collect, an open side-rail slot, or the lower left gutter on very short screens.
The latter placement keeps collection cards above the badge. The original badge
study is retained in the [combo QA report](../qa/2026-10-25-jelly-combo.md).
Current countdown, reward attribution and expiry regressions live in
`tests/godot/word_jelly_combo_hud_tests.gd`, `word_jelly_combo_tests.gd` and the
real browser combo journeys.
