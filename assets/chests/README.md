# Chest asset library

Start with [the level mapping](catalog/chest-levels.json) to find any of the 24
reviewed chest families by level, name, stable asset ID and current resource path.
The level mapping describes visual asset progression; [gameplay tier presets](catalog/tier-presets.json)
retain the existing 30 reward tiers.

```text
chests/
  catalog/                  Runtime manifests and level/tier mappings
  models/
    atelier/<asset-id>/      Twelve optimized, source-derived CC0 chest designs
    cc0/<source-id>/         Four polished Kenney/KayKit chest bases
    licensed/<asset-id>/     Five private licensed models and their import textures
  sprites/
    royal/                  Original PNGs, derived rig/ and states/ layers
    energy/                 Original PNGs, derived rig/ and states/ layers
    crystal/                Original layered PNGs and derived states/
  shared/
    effects/                Shared glow, ray and sparkle textures
    rewards/                Sourced coin models and legacy surprise artwork
  sources/
    cc0/                    Original acquired models, palettes and creator licenses
    atelier/                Licenses, acquisition provenance and validation evidence
    licensed/               Private-model source notes
    sprites/                Original 2D source mapping and import notes
    sprite-rigs/            Derived layer construction notes
    states/                 Acquired state sources and derivation evidence
```

Each runtime 3D chest has its own folder. Keep its `.glb`, Godot `.import`
sidecars and extracted texture files together. Resource paths in catalog JSON
are relative to the project root; Godot resource paths begin with `res://`.
The original CC0 `Textures/` directories remain beside their source GLBs.

| Catalog | Purpose |
| --- | --- |
| [chest-levels.json](catalog/chest-levels.json) | Stable low-to-high asset levels, rarity, asset IDs and paths |
| [tier-presets.json](catalog/tier-presets.json) | Existing 30 gameplay assembly recipes |
| [atelier.json](catalog/atelier.json) | Optimized Atelier model contracts, provenance and hashes |
| [licensed-models.json](catalog/licensed-models.json) | Private licensed model sources and animation metadata |
| [cc0-models.json](catalog/cc0-models.json) | Polished CC0 models and original source hashes |
| [cc0-sources.json](catalog/cc0-sources.json) | Original acquired CC0 bases, ornaments and licenses |
| [sprites.json](catalog/sprites.json) | Original Royal, Energy and Crystal artwork |
| [sprite-rigs.json](catalog/sprite-rigs.json) | Derived Royal/Energy moving layers and source hashes |
| [chest-states.json](catalog/chest-states.json) | Closed, Open, Treasure and Magic compositions and loadable scenes |
| [chest-state-assets.json](catalog/chest-state-assets.json) | Shared KayKit coins and Kenney particle sources, hashes and licenses |
| [chest-sprite-states.json](catalog/chest-sprite-states.json) | Derived sprite-state output hashes and source evidence |

The local review studio remains in `Q:/uwok/chest`. It reads this layout directly;
its Delete action also updates the corresponding catalogs and level mappings.
Stable asset IDs and levels are independent of directory names.

## State scenes

Every family has four exclusive states: `closed`, `open` (empty cavity),
`treasure` (open with coins), and `magic` (open with light and sparks, without
coins). Load the `scene` path recorded in `chest-states.json`. Models use a sibling
`<id>-states.tscn`; sprite families use `sprites/<style>/<style>-states.tscn`.

```gdscript
var chest = load("res://assets/chests/models/atelier/tideguard/tideguard-states.tscn").instantiate()
add_child(chest)
chest.set_state("treasure")
```

The original model and acquired image bytes are retained. The wrapper scenes
compose existing lid clips or hinges with sourced KayKit coin geometry and
Kenney particle textures. These added states are game-authored compositions;
they do not imply that the original creator supplied those animations. Derived
Royal, Energy and Crystal state PNGs also retain their source and construction
records. The original 30 gameplay tier recipes remain a separate catalog.

This organization changes paths, while preserving original model, image and
license bytes. Historical acquisition/native reports retain their original path
labels and hashes. The relocation record is documented in
[the layout notes](../../../docs/assets/chest-layout.md).
