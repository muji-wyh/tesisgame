# Chest library organization

The chest library is organized by role under `assets/chests/`. Read
[the library guide](../../assets/chests/README.md) for the current tree and catalog
entry points. Each runtime model family has its own directory, including its
extracted textures and Godot import sidecars.

## Catalog entry points

| Previous location under `assets/chests/` | Current location |
| --- | --- |
| `chest-levels.json` | `catalog/chest-levels.json` |
| `tier-presets.json` | `catalog/tier-presets.json` |
| `manifest.json` | `catalog/sprites.json` |
| `rigs.json` | `catalog/sprite-rigs.json` |
| `downloaded/manifest.json` | `catalog/licensed-models.json` |
| `polished-cc0/manifest.json` | `catalog/cc0-models.json` |
| `catalog-cc0/sources.json` | `catalog/cc0-sources.json` |
| `atelier/manifest.json` | `catalog/atelier.json` |

## Resource and source locations

| Previous location | Current location |
| --- | --- |
| `atelier/<id>.glb` and `<id>_*.png` | `models/atelier/<id>/` |
| `models/<id>.glb` and `<id>_*.jpg` | `models/licensed/<id>/` |
| `polished-cc0/<id>.glb` and `<id>_*.png` | `models/cc0/<id>/` |
| `royal/`, `energy/`, `crystal/` | `sprites/royal/`, `sprites/energy/`, `sprites/crystal/` |
| `rigs/<style>/` | `sprites/<style>/rig/` |
| `particles/`, `milestone/` | `shared/effects/` |
| `surprises/` | `shared/rewards/` |
| `catalog-cc0/<pack>/` | `sources/cc0/<pack>/` |
| `atelier/licenses/`, `atelier/provenance/`, `atelier/validation/` | `sources/atelier/` with the same child names |
| `SOURCE.txt`, `downloaded/SOURCE.txt`, `rigs/SOURCE.md` | `sources/sprites/`, `sources/licensed/`, `sources/sprite-rigs/` |

Filenames, case-sensitive source `Textures/` directories, model/image/license
bytes, import UIDs, stable asset IDs and assigned levels are retained. The active
game scripts, tests, preparation tools, export rules and local review studio use
the new locations. The Web export explicitly includes the catalog JSON files.
Private licensed models and milestone effects retain their Git ignore rules.

Historical acquisition records and native validation reports preserve their
original bytes, hashes and path labels. Their current locations are recorded in
the catalog; those original labels describe the earlier validation context.
Old QA snapshots under `docs/qa/` are historical evidence and are not rewritten.

The local migration inventory and original byte hashes are retained in
`build/chest-layout-migration.json`. It records every relocated file, including
Godot sidecars. Regenerating or republishing artwork should use the maintained
preparation and publishing tools, which target this layout.
