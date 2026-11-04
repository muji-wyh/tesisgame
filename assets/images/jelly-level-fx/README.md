# Merged Jelly level accents

This private atlas composes previously acquired production particle artwork into
nine different rim effects. Each level keeps a recognizable static frame as well
as a 3.2-second loop. It adds no gameplay rules, text labels, audio or hit targets.
Runtime integration and device rendering are verified separately from this source
composition preview.

| Level | Profile | Effect | Composition |
| --- | --- | --- | --- |
| 1 | `pearl` | Pearl bubbles | Three pearly bubbles gently rise around the outside of the gel. |
| 2 | `ripple` | Twin crystal ripples | Two nested aqua rings breathe out of phase around the perimeter. |
| 3 | `spiral` | Sapphire spiral | Opposing blue and lavender arcs turn with a small orbiting glint. |
| 4 | `firework` | Golden firework bloom | Five outward golden flamelets breathe around a restrained radial bloom. |
| 5 | `cascade` | Rose cascade | Three pink flowers flutter down the two sides with staggered translucent tails. |
| 6 | `bouquet` | Prismatic bouquet | Four diamond points shimmer in different colors with two iridescent bubbles. |
| 7 | `aurora` | Aurora ribbons | Mint and violet wavy light strands sway at the sides with a soft upper ribbon. |
| 8 | `constellation` | Constellation shimmer | A fine five-node constellation surrounds five independently twinkling rim stars. |
| 9 | `grand_bouquet` | Grand golden crown | A three-star gold crest glows above the Jelly with small lower-rim accents. |

`sources.json` records original source locations, creators, licenses, byte counts,
SHA-256 hashes, source animation availability and each composition recipe.
The source images were inspected on dark backgrounds and at small particle size.
Toon FX by Kenneth Foldal Moe / Archanor VFX retains its existing Standard Unity
Asset Store EULA and embedded-game restrictions, documented in
[Jelly fragments](../../../docs/assets/jelly-fragments.md). Kenney's Particle
Pack 1.1 comes from the user's local All-in-1 3.7.0 collection under CC0-1.0; the
existing [license](../../chests/sources/states/kenney-particles/LICENSE.txt) is
retained. No new asset purchase or listing-preview extraction is performed.

The originals are static images. The Toon flower and flame `2x2` sheets contain
four supplied particle views; this composition uses them as static variants and
does not import Unity particle playback. The loop uses game-authored placement,
rotation, tint and alpha. Its transparent
center reserves the learning picture and spelling. No source pixel art is
replaced with procedural shapes, and Unity prefabs and scripts are not executed.

The atlas is 1536 by 1728 RGBA: sixteen columns of 96-pixel cells and eighteen
rows. Each level uses two consecutive rows and thirty-two frames. Frame zero is
the reduced-motion cue. Runtime may interpolate frames for smooth playback and
freeze its local clock outside the existing animation budget. Source composition
is rendered at four times the final size and downsampled for clean small rims.
The original sources remain outside the repository; the derived atlas and Godot
imports remain ignored and ship only inside the compiled game pack.
The generated `atlas.png.import` sidecar uses lossless compression, no mipmaps,
no resizing and straight alpha to preserve the small rim artwork and cell edges.
It preserves an existing texture UID and import path. This sidecar accompanies
the private source-derived atlas and remains ignored with it under the same
embedded-game asset distribution restrictions.

Regenerate from the acquired source roots:

```powershell
python tools/prepare-merged-jelly-fx.py
```

Use `--toon-root`, `--kenney-root` and `--repo-root` to override source or repository
roots. Input hashes are verified before output is written. Use `--check` to
validate the prepared atlas against its recorded hash and layout without needing
the source collection, and validate the required import settings when its sidecar
is present. The contact sheet at
`build/qa/merged-jelly-level-fx/source-atlas-contact.png` previews the actual derived
atlas on a dark background; it is not a game screenshot or physical-device test.
