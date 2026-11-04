# Sci-fi and arcane chest expansion

Eight new designs extend the four revision 2 fantasy chests. The user-supplied
images guide the broad chamfered silhouettes, protected corner fittings, nested
core settings, material contrast and friendly companion face. Their creator and
reuse license are unknown; their pixels are reference material only and are not
included in any production texture or model.

| Design | Direction | Acquired case |
| --- | --- | --- |
| Aether Vault | Ivory ceramic, gold corner cages and amethyst seal | Blaster crate-small |
| Cobalt Vault | Obsidian panels, silver cages and cyan energy | Blaster crate-small |
| Solar Relay | Amber armor, dark inset panels and octagonal reactor | Blaster crate-medium |
| Frost Relay | White armor, blue ceramic and cyan reactor | Blaster crate-medium |
| Prism Signal | Wide porcelain case, magenta bridges and triangle lens | Blaster crate-wide |
| Jade Reliquary | Jade enamel, gilded bridges and real faceted emerald | Blaster crate-wide |
| Crimson Citadel | Crimson enamel and a layered ruby escutcheon | Blaster crate-wide |
| Nova Buddy | Friendly eyes, a signal canopy and a heart inside the lid | Blaster crate-medium |

The genuine acquired Kenney Blaster Kit case bodies, cavity geometry, lid
meshes and source color UVs remain the production base. Adaptations change
proportions and orientation, remap the original shaded palette, add supplementary
ceramic surface finishing, and fit new segmented armor, fasteners, recessed
vents, rear hinges, core bezels and inner-lid badges. Gold piles and selected
faceted jewels use the existing acquired KayKit and Kenney source meshes.
See [source acquisition and inspection](EXPANSION-SOURCES.md) for exact files,
creator notices, source animation and hash records.

Each new authoring entry has four aligned 1024-pixel transparent states and an
editable Blender scene. `Open` and `Close` are newly authored one-second
100-degree rigid hinge clips. The runtime copy batches fixed and moving parts,
reduces hardware and loot geometry, and bakes standard single-UV color, normal,
roughness/metallic and localized emissive maps. The original source clips are
preserved in the acquired originals rather than presented as the new clips.

## Rebuild

```powershell
blender --background --factory-startup --disable-autoexec --python tools/build_expansion.py
python tools/package_images.py --only aether-vault cobalt-vault solar-relay frost-relay prism-signal jade-reliquary crimson-citadel nova-buddy
blender --background --factory-startup --disable-autoexec --python tools/export_runtime.py -- --only aether-vault
python tools/pack_runtime.py --only aether-vault
```

Repeat the last two commands for another selected ID. `build_expansion.py`
supports `-- --only <id>`, `--no-index` for an unfinished pilot and
`--index-only` to index completed outputs. Keep draft outputs outside the review
index until their states and metadata are ready. The original four-model
authoring builder preserves already indexed expansion entries.

Use the collection validator for source/provenance, real mesh/material bindings,
hinge clocks, transparent frames and exact spritesheet cells. Use matched browser
comparisons and actual Godot GL Compatibility captures to review final runtime
bytes. The native harness accepts the expansion recipe manifest or the complete
runtime manifest. Publish through `tools/publish_runtime.py` with the matching
native report; publication alone does not select a gameplay reward tier.

The review page includes search, collection filters, state comparison, orbit,
Details, replay and downloads for every indexed design. Its previews and the
native game's renderer use different lighting.

## Final deliverables and verification

All eight designs are indexed alongside the original four in the review page.
`expansion.png` shows the eight new Blender authoring renders; `collection.png`
compares all twelve designs and their four states. The eight optimized runtime
GLBs total 13,609,944 bytes and 160,480 triangles, with three mesh instances per
asset and no required external glTF codec. They are published with source
records and CC0 notices to `Q:/uwok/tesisgame/assets/chests/atelier/`.

The complete twelve-model authoring collection passed 2,067,748 checks with no
failures, covering source hashes, licenses, bound mesh/material data, one-second
hinge clips, transparent state images and exact spritesheet cells. All 48 matched
240-pixel browser source/runtime pose pairs were captured and visually reviewed.
All twelve destination models passed 1,041 headless native checks and 1,296
native GL Compatibility capture checks with zero failures. Reports bind those
results to the exact final GLB hashes. See [runtime export notes](RUNTIME-EXPORT.md)
for measurements, evidence paths and renderer scope.

The current Web resource pack was exported and loaded successfully with all
twelve scenes, the JSON manifest, PBR/emission textures and one-second clips.
This verifies packaged resources; physical-phone performance was not measured.
