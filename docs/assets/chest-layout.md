# Chest library organization

The game selects all28 retained chest01 Atelier models. [The library guide](../../assets/chests/README.md) describes the current contract, source terms and99-level mapping.

Live resources are under `assets/chests/models/atelier/<asset-id>/`. Each folder keeps its GLB, textures, import sidecars, state scene and license. `catalog/gameplay-chests.json` defines99 gameplay levels and8 palette aliases. `catalog/chest-levels.json` records the ordered material mapping. The final material is reused from Lv29 through Lv99.

`catalog/chest-states.json` describes the28 actual state compositions, and `catalog/chest-state-assets.json` records shared sourced treasure and effect assets. The game samples each native Open clip continuously and renders sourced Treasure/Magic contents with the same caller-owned clock. Shared UI portraits use one camera and a union alpha crop so the closed/open body stays aligned.

The former sprite artwork, source chest base resources and modular tier catalogs have been removed. Shared game effects, audio, reward geometry and provenance notices remain. Original acquisition and validation records preserve their historical paths and capture counts; their labels describe the earlier validation context rather than active game resources.

Private source-derived Atelier editions retain their Git ignore rules and original source terms. Runtime copies ship inside the verified game package. Historical QA snapshots under `docs/qa/` are retained as evidence.
