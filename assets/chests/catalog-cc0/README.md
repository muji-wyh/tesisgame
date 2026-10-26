# Modular chest tier source inputs

**Status: thirty modular tiers integrated and native-render reviewed.** This is
nine genuine 3D base exterior families plus thirty game-authored style/assembly
recipes, **not thirty native chest models**. Actual front, side, back and opened
captures for every tier are under `build/qa/chest-thirty-tiers/`; geometry,
real fitting attachments and sampled moving-lid clearance are checked by
`tests/godot/chest_tier_models_tests.gd`.

Original GLB/PNG/license bytes remain unchanged. The runtime preserves source UVs
and textures, styles source atlas regions per instance, uses actual source clips
or the KayKit lid hinge, and mounts genuine 3D ornaments on measured body surfaces.
The acquisition-only descriptions below retain their historical source facts;
their proposed transform/material contracts are now implemented by
`scripts/chest_tier_catalog.gd` and `scripts/chest_model_view.gd`.

[`sources.json`](sources.json) records original source and output SHA-256,
byte sizes, creators, original licenses, acquisition status, actual geometry,
materials, dependencies, node names and available animation clips. Source and
output hashes are equal because the new inputs are byte-for-byte copies.
Original license files are copied without changing their contents.
The local `.gitattributes` preserves original GLB/PNG/license bytes regardless of
checkout line-ending settings, so the same hashes also work on another machine.

## Included CC0 inputs

Paths below are relative to this directory. Retain the case-sensitive
`Textures/colormap.png` dependency beside each corresponding Kenney model.

| Creator / acquired pack | Original model inputs copied here | Geometry / motion |
| --- | --- | --- |
| Kenney / [Survival Kit](https://kenney.nl/assets/survival-kit) 2.0 | `kenney-survival/chest.glb` | 322 triangles; separate `lid`; source `open`, `close`, `open-close` |
| Kenney / [Platformer Kit](https://kenney.nl/assets/platformer-kit) 4.1 | `kenney-platformer/chest.glb` | 232 triangles; separate `lid`; the same three source clip names |
| Kenney / [Mini Dungeon](https://kenney.nl/assets/mini-dungeon) 2.0 | `kenney-mini-dungeon/chest.glb` | 288 triangles; separate `lid`; the same three source clip names |
| Kay Lousberg / [Dungeon Remastered](https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0) 1.0 | `kaykit-dungeon/chest.glb` | 728 triangles; separate `chest_lid`; **no animation clips**; embedded 1024px atlas |
| Kenney / Platformer Kit | `kenney-platformer/jewel.glb`, `lock.glb`, `coin-gold.glb` | 12 / 100 / 124 triangles; static 3D jewel, padlock and medallion |
| Kenney / Mini Dungeon | `kenney-mini-dungeon/shield-rectangle.glb`, `shield-round.glb` | 134 / 160 triangles; static framed shields reused as escutcheons |
| Kenney / [Tower Defense Kit](https://kenney.nl/assets/tower-defense-kit) 2.0 | `kenney-tower-defense/detail-crystal.glb` | 68 triangles; static 3D crystal |

Each of the four Kenney folders includes its original 512px palette PNG and
original `LICENSE.txt`. The KayKit folder contains its original `LICENSE.txt`;
its GLB already embeds the required atlas. There are ten original GLBs, four
required PNGs and five original license notices: **284,222 bytes** in total,
excluding JSON and this documentation.

KayKit inputs are pinned to creator-repository commit
`b0ca9bd96a8072ab36a3a5464f00ed1e06a16d07`, including the original license.
The acquired Kenney versions are taken from their original license notices;
their current public product pages may describe newer versions.

All new raw inputs use [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)
and may be stored in the repository. Credit is optional, but the original notices
and source records are retained. Paid KayKit EXTRA/SOURCE content is not included.

Pirate Kit's chest is a scaled counterpart of Platformer Kit's exterior and is
not counted or copied. KayKit's `chest_gold` adds interior loot to the same
exterior and is not copied. Bronze/silver/gold coins are one geometry; the snow
crystal palettes are duplicates. Neither a rock/crystal cluster nor a fabricated
crown mesh is needed by the recipes.

## Existing private bases

The other five base models remain at their existing ignored build-input paths:

- `assets/chests/models/meadow-explorer.glb` — Ekrem C., Low Poly Chest Animated.
- `assets/chests/models/harvest-keepsake.glb` — Batata Studio, Treasure Chest 4a.
- `assets/chests/models/lagoon-pearl.glb` — Batata Studio, Treasure Chest 1a.
- `assets/chests/models/strawberry-bonbon.glb` — Batata Studio, Treasure Chest 2a.
- `assets/chests/models/moonstone-vault.glb` — Bobardo, Epic Chest.

They retain the **Unity Asset Store Standard EULA**, not CC0. This directory
contains metadata references only: no restricted GLB, original Unity package,
source texture, controller or shader is copied here or relicensed. Their exact
existing file hashes are checked against the tracked downloaded-chest manifest.
See [the existing acquisition/adaptation record](../../../docs/assets/chest-refresh.md).
The Harvest reference is the already cleaned private model with its original
skull/bone clasp removed, not the unmodified source prefab.

## Recipe schema and attachment API

[`../tier-presets.json`](../tier-presets.json) has:

```text
version
source_notes
tiers[]:
  level, id, name, base_model, base_source_id, material_style
  decorations[]: model, slot, scale, rotation_degrees
  open_animation?  (actual case-sensitive clip name, when one exists)
```

Paths are portable project-relative resource paths; a Godot caller may add
`res://`. `material_style` selects a declared style in
`source_notes.material_styles`, progressing through wood/iron, bronze, silver,
sterling, gilded green, champagne gold, pearl gold, rose gold and royal white gold.
The tier families are consecutive: levels 1–3 / 4–6 / 7–9 / 10–12 / 13–15 /
16–18 / 19–22 / 23–26 / 27–30 use the nine bases in that order.

Every recipe has a different base/ornament/anchor structure even when color,
scale and rotation are ignored. Low tiers have at most two or three attachments;
later tiers use larger real gems, escutcheons and balanced side fittings. This
structural uniqueness does **not** establish visual distinctness or perceived
preciousness without the pending render review.

The five semantic slots are `front`, `left`, `right`, `front-left` and
`front-right`. Attach to the actual **body**, below the lid seam, in the
normalized base-local frame (+Y up, +Z front, +X right). There is at most one
model at each slot. Source shields/coins become new game-authored escutcheon and
medallion arrangements; they are not publisher-authored chest variants.

`scale` is the desired largest ornament dimension as a fraction of the
normalized chest width. Center the entire source ornament on its own 3D bounds,
then uniformly scale it by:

```text
chest_width * scale / ornament_largest_dimension
```

It is **not** a raw GLB-unit scale multiplier. `rotation_degrees` is XYZ Euler
rotation in that base-local frame. Side attachments turn around Y. The caller
must identify real surface depth and safe seam/handle clearance; a bounding box
alone does not establish a valid attachment surface.

## Material and animation facts

The original Kenney/KayKit materials use a single palette/gradient atlas and
`metallicFactor: 0`. Their silver/gold colors are painted source regions, not
already physically metallic materials. New `shell`, `trim`, `ornament_metal`
and `gemstone` role colors/roughness/metallic values are **proposed in-game
adaptations**, not source-authored materials or changes applied to these files.
The original atlas shading and UVs must survive later role-specific masks/remaps;
a global metallic/color override would also affect wood and is not equivalent.

The three Kenney bases have `open` (approximately 0.3s), `close` (1s) and
`open-close` (2s). KayKit only has a separate static lid; levels 10–12 omit
`open_animation` instead of inventing a source clip. Existing private bases have
their current game-authored `Open` (1s): four hinge rotations and Moonstone's
floating cover translation. These are not preserved original Unity takes.
All six ornaments are static and should follow the body without obstructing
opening. No new animation is authored by this catalog.

## Required next validation

Before calling these integrated or visually approved, render all thirty recipes
closed, opening and rotating at phone size. Check real surface mounting,
interpenetration, original clasps/handles, lid clearance, source UV/material-region
assignment, silhouette distinction, monotonic perceived luxury and friendly
appearance. The higher-tier source bases are much denser than the new CC0 inputs;
actual view-count and mobile performance also need measurement. No engine
imports, GPU rendering, server, export or presentation integration were run here.

Run only the portable metadata suite with:

```powershell
node --test tests\chest-tier-art.test.cjs
```

It checks hashes, checkout-byte preservation, raw licenses, actual volumetric
geometry, texture dependencies, clip facts, all thirty recipes, balanced anchors
and portable private references.
It needs no local original source collection, Godot or restored private GLB to
pass; a private file's actual hash is additionally compared when that file exists.
