# Game asset art direction

## Asset quality

All game elements need appropriate sourced production assets. This includes
characters, scenes, environmental props, chests, rewards, interface artwork,
visual effects, music, and sound effects. Simple shapes, solid-color silhouettes,
and generic procedural drawings must not stand in for the requested artwork.

Search for the actual asset before building its presentation. Inspect it at the
intended phone size, check source and license terms, and preserve attribution.
Record preview, acquisition, conversion, and integration as separate states.
An asset that has only been previewed is not a downloaded or shipped asset.
If a suitable asset is still missing, keep that selection explicitly pending
instead of filling it with placeholder art or claiming the element is finished.

This requirement guides new work and replacements. It does not imply that
all existing procedural artwork has already been replaced.

## Storybook 2.5D Upgrade (2026-11-25)

To unify the visual language around the 3D Atelier treasure chests, 3D Pirate Boss,
3D miniature career previews, and 3D Fluent vocabulary stills:
- **3D Miniature Diorama Scenery (`tools/render-storybook-scenery.py`)**: All nine Jelly Journey
  chapter landmarks (`assets/images/jelly-campaign/*.png`) and four board garden layers
  (`assets/images/jelly-match/garden/{hills,tree,tree-long,foliage}.png`) are rendered in Blender 5.3
  Cycles from user-supplied CC0 Kenney 3D kits (`Nature Kit`, `Castle Kit`, `Holiday Kit`, `Pirate Kit`)
  under unified warm top-left storybook lighting.
- **Multi-Biome Skies (`docs/assets/jelly-sky.json`)**: Adds golden-hour (`morning.png`) and twilight
  (`night.png`) panoramas from CC0 Kenney Skyboxes 1.0 alongside `day.png`.
- **3D Translucent Gel Skins & Sculpted Medallions (`tools/render-storybook-ui-and-gels.py`)**:
  Replaces flat gel sprites and medallions with Blender 5.3 Cycles renders while strictly preserving
  the 320x320 rounded-rectangle SDF contract (`tools/prepare-jelly-material.py`).
- **Tactile 9-Slice UI Chrome & Memory Card Backs**: Symmetrical sculpted parchment panels,
  chapter banners, toybox well frame, primary/secondary/gold buttons (`assets/images/ui/chrome/`),
  and quilted storybook Memory card backs (`assets/images/ui/memory/`).
- **Fluent 3D RPG, Boon, Powerup & Starter Vocabulary Art**: 31 new 3D icons (`assets/images/ui/jelly-rpg/`,
  `auto-merge-wand.webp`, `finish-flag.webp`, `modes/rocket.webp`, `modes/rainbow.webp`) and 47
  starter Age 4–5 Mulberry vocabulary words upgraded to pinned Microsoft Fluent Emoji 3D (MIT) with
  regenerated 32-frame motion atlases (`tools/upgrade-starter-mulberry-words.py`).
- **Toon FX Boss & Impact Particles**: Additional frost, ink-splat, impact-star, and soft-poof textures
  extracted from the user's licensed local Archanor VFX Toon FX 1.52 package.

## Archived Talk Quest guardian direction

Talk Quest was retired on 2026-10-06. The following direction and source review
are historical; they do not require new creatures or restore a game mode.

Each of the fourteen levels needs its own distinct creature design. Favor
beautiful fantasy guardians with large bodies, broad wings, flowing fins,
ornamental antlers, or rich natural detail. They should feel majestic and
friendly to children. A large scale must not come from a frightening expression.

Exclude horror imagery, skull-like faces, grotesque anatomy, snarling mouths,
aggressive exposed teeth, and threatening lunges toward the camera. Inspect
the front face, full silhouette, idle, reactions, and the most extreme animation
pose. A friendly thumbnail alone does not verify all source animation.

Prefer breathing, blinking, gliding, curious head turns, and playful reactions.
Use a friendly retreat or magical departure for defeat. Record missing rigging
or animation work honestly; a static source is not an animated game character.

The current replacement selection is an art review, separate from the active
game assets. Source previews are stored under the local TalkQuest asset review
workspace; downloaded models and their licenses must be verified before game
integration.
