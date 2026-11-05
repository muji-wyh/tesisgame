# Chest asset library

The game uses the 28 selected models from the chest01 Atelier collection. Levels 1–28 follow the approved ranking. Levels 29–99 reuse the final Aether Vault material, with distinct gameplay level IDs and the full upgrade presentation.

- [gameplay-chests.json](catalog/gameplay-chests.json) contains the active 99-level runtime contract and eight palette aliases.
- [chest-levels.json](catalog/chest-levels.json) maps gameplay levels to stable asset IDs, model paths and provenance.
- [atelier.json](catalog/atelier.json) records optimized source models, hashes, licenses and historical native validation.
- [chest-states.json](catalog/chest-states.json) defines Closed, Open, Treasure and Magic compositions for the 28 selected models.
- [chest-state-assets.json](catalog/chest-state-assets.json) records shared KayKit treasure geometry and Kenney effect textures.
- [shared/ui/manifest.json](shared/ui/manifest.json) records the matched transparent portraits rendered from Wayfarer Oak.

Each model lives in `models/atelier/<asset-id>/` with its GLB, Godot import sidecars, textures, state scene and source license. The former sprite artwork and original base models have been removed from the active asset library.

The GLBs supply their authored Open and Close clips. Treasure and Magic are compositions using sourced geometry and textures, not additional native animation clips. The runtime uses one source instance and its own continuous opening clock; presentation never grants rewards.

```gdscript
var chest = load("res://assets/chests/models/atelier/tideguard/tideguard-states.tscn").instantiate()
add_child(chest)
chest.set_state("treasure")
```

Atelier names the collection rather than a single license. CC0 source derivatives retain CC0 terms. Private Unity Asset Store derivatives remain private build inputs under their original terms. User-supplied reference artwork does not imply any new usage rights. Exact provenance and creator notices remain under `sources/atelier/`, while shared state sources retain their own notices under `sources/states/`.

Historical acquisition and validation reports retain their original path labels and capture counts. The local authoring studio remains in `Q:/uwok/chest`; gameplay selection is now the 99-level runtime catalog.
