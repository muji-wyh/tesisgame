# Talk Quest treasure stage artwork

The Talk Quest reward presentation uses acquired room artwork and effects
textures. These are integrated source images, not source previews. The runtime
manifest records source URLs, creator and license details, original file hashes,
and hashes and byte counts for the seven shipped textures.

## Scenery

- **Interior01**, by **Midnight68**:
  <https://opengameart.org/content/interior01>.
- License: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).
- The author describes the images as CG illustrations and explicitly releases
  them into the public domain for reuse for any purpose.
- Acquired originals: `interior001.bmp` (995 x 558) and `parlour001_1.bmp`
  (755 x 675). The original BMP files are retained in
  `C:/uworks/TalkQuest/downloads/treasure-stage/`.
- Integrated derivatives: `alcove.jpg` and `parlour.jpg`. Both preserve the
  original dimensions; saturation is reduced to 72 percent and the image is
  encoded as an optimized JPEG at quality 92. No objects, replacement shapes,
  or generated environment artwork were added.
- Both complete images were inspected before integration. They depict empty
  golden wood-paneled rooms without creatures, threatening imagery, or people.

The uncluttered alcove is used on phones and compact landscapes. The furnished
parlour is used when the stage is wider than 700 physical pixels and at least
350 physical pixels tall. Runtime aspect-fill crops preserve image proportions.

## Lighting and interface textures

**Modern 2D Animated Chests - FREE Demo 1.0.2**, by **Bobardo**, product 360538:
<https://assetstore.unity.com/packages/2d/modern-2d-animated-chests-free-demo-360538>.
The acquired local package is governed by the
[Unity Asset Store Standard EULA](https://unity.com/legal/as-terms).

| Runtime texture | Acquired particle texture | Preparation |
| --- | --- | --- |
| `halo.png` | `Particles/Textures/glow1.png` | Downsampled to 256 x 256 |
| `ray.png` | `Particles/Textures/lightray1.png` | Downsampled to 512 x 128 |
| `sparkle.png` | `Particles/Textures/sparkle3.png` | Downsampled to 128 x 128 |

These static RGBA textures were inspected in a contact sheet. Their original
transparency is preserved. Unity prefabs, code, materials, and paid-chest demo
thumbnails are not part of this integration.

**UI Pack: RPG Expansion**, by **Kenney Vleugels**:
<https://kenney.nl/assets/ui-pack-rpg-expansion>, licensed CC0 1.0.
`title-panel.png` is the original `PNG/panelInset_brown.png`; `frame.png` is the
original `PNG/panel_beige.png`. These two files are copied without pixel edits.
The frame renders only its border, leaving the sourced scenery unobstructed.

## Runtime behavior

The component is `scripts/talk_quest_treasure_stage.gd`. It exposes:

- `configure(theme: Dictionary)` for an existing game theme dictionary.
- `set_presentation_rects(title: Rect2, chest: Rect2)` in local coordinates.
  Empty rectangles disable the title plate and select a default chest focus.
- `set_reveal(value: float)` for decorative intensity from zero to one.
- `set_reduced_motion(enabled: bool)` and `set_active(enabled: bool)`.
- `snapshot()` for presentation and source diagnostics.

Source artwork is static. Gentle light-ray movement, halo breathing and drifting
sparkles are authored presentation effects; they are not source animation clips.
Ambient redraws are capped at 24 per second and stop while hidden, inactive or
in reduced-motion mode. Reveal changes remain visible in reduced-motion mode.
The component ignores input and never advances chest or reward state.

The seven textures total 261,862 bytes before Godot import. `manifest.json` must
be included in the Web export alongside their imported resources.
