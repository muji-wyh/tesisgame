# Treasure Atelier runtime library

28 optimized designs: twelve original editions, nine Heritage editions and
seven Relic editions. The game selects all 28 retained model families.
The gameplay catalog has 99 levels; levels 29–99 reuse Aether Vault.

| Design | Model | GLB bytes | Triangles | License |
| --- | --- | ---: | ---: | --- |
| Wayfarer Oak | [wayfarer-oak](wayfarer-oak/wayfarer-oak.glb) | 914,248 | 9,077 | CC0 |
| Ironbound Trail | [ironbound-trail](ironbound-trail/ironbound-trail.glb) | 919,192 | 9,016 | CC0 |
| Duskwatch Coffer | [duskwatch-coffer](duskwatch-coffer/duskwatch-coffer.glb) | 914,784 | 9,018 | CC0 |
| Dungeon Keeper | [dungeon-keeper](dungeon-keeper/dungeon-keeper.glb) | 1,080,920 | 12,147 | CC0 |
| Cooper Star | [cooper-star](cooper-star/cooper-star.glb) | 1,500,092 | 17,644 | CC0 |
| Tideguard | [tideguard](tideguard/tideguard.glb) | 1,549,360 | 16,873 | CC0 |
| Meadow Cabinet | [meadow-cabinet](meadow-cabinet/meadow-cabinet.glb) | 982,836 | 15,090 | Private EULA |
| Sunward | [sunward](sunward/sunward.glb) | 1,294,424 | 12,986 | CC0 |
| Harvest Strongbox | [harvest-strongbox](harvest-strongbox/harvest-strongbox.glb) | 1,821,764 | 49,938 | Private EULA |
| Gilded Waywatch | [gilded-waywatch](gilded-waywatch/gilded-waywatch.glb) | 1,436,848 | 14,960 | CC0 |
| Verdant Oath | [verdant-oath](verdant-oath/verdant-oath.glb) | 1,479,852 | 15,115 | CC0 |
| Bonbon Keepsake | [bonbon-keepsake](bonbon-keepsake/bonbon-keepsake.glb) | 1,135,260 | 20,031 | Private EULA |
| Velvet Parcel | [velvet-parcel](velvet-parcel/velvet-parcel.glb) | 1,109,804 | 15,977 | CC0 |
| Moonbound | [moonbound](moonbound/moonbound.glb) | 1,295,512 | 13,077 | CC0 |
| Royal Rose | [royal-rose](royal-rose/royal-rose.glb) | 1,237,636 | 13,123 | CC0 |
| Lagoon Reliquary | [lagoon-reliquary](lagoon-reliquary/lagoon-reliquary.glb) | 1,145,704 | 20,678 | Private EULA |
| Moonstone Crown | [moonstone-crown](moonstone-crown/moonstone-crown.glb) | 998,008 | 14,100 | Private EULA |
| Prism Signal | [prism-signal](prism-signal/prism-signal.glb) | 1,605,224 | 19,079 | CC0 |
| Aegis Transit | [aegis-transit](aegis-transit/aegis-transit.glb) | 925,756 | 11,896 | CC0 |
| Frost Relay | [frost-relay](frost-relay/frost-relay.glb) | 1,857,808 | 21,759 | CC0 |
| Solar Relay | [solar-relay](solar-relay/solar-relay.glb) | 1,845,100 | 21,759 | CC0 |
| Nova Buddy | [nova-buddy](nova-buddy/nova-buddy.glb) | 1,639,428 | 19,573 | CC0 |
| Jade Reliquary | [jade-reliquary](jade-reliquary/jade-reliquary.glb) | 1,632,244 | 19,193 | CC0 |
| Crimson Citadel | [crimson-citadel](crimson-citadel/crimson-citadel.glb) | 1,745,060 | 20,891 | CC0 |
| Regent Wings | [regent-wings](regent-wings/regent-wings.glb) | 933,528 | 9,020 | CC0 |
| Cobalt Vault | [cobalt-vault](cobalt-vault/cobalt-vault.glb) | 1,634,188 | 19,113 | CC0 |
| Rune Sentinel | [rune-sentinel](rune-sentinel/rune-sentinel.glb) | 1,492,824 | 14,982 | CC0 |
| Aether Vault | [aether-vault](aether-vault/aether-vault.glb) | 1,650,892 | 19,113 | CC0 |

The 28 GLBs total **37,778,296 bytes** and
**475,228 triangles**. Extracted image files and
Godot import sidecars are separate from this total. The nine Heritage GLBs total
9,912,716 bytes, 37.53% below their authoring GLBs;
geometry decreases from 308,109 to 159,095 triangles
(48.36%). Exact per-model measurements and
source hashes are in [Heritage evidence](../../sources/atelier/provenance/heritage-editions.json).

## Integration contract

Read each model's `style` dictionary in [atelier.json](../../catalog/atelier.json).
Keep its GLB, extracted images and import sidecars together in its asset folder.
Use `normalize_model: false` and `material_profile: {}` to preserve the exported
coordinates and imported PBR finish. Files use +Y up, +Z front and +X right,
with authored dimensions and feet at Y=0. Measured closed/open bounds retain
the full fitted silhouette; source-shell and added-hardware widths may differ.

Keep the semantic `Body` and moving `Lid` nodes and the actual `Open`/`Close`
one-second clips. The original twelve designs have embedded `Treasure` geometry;
Heritage and Relic editions receive acquired KayKit coins through their state scenes.
Moonstone Crown opens by lifting its cover vertically. Its clip and declared
lift mechanism must be retained.

Load the sibling `<id>-states.tscn` and call `set_state("closed")`,
`set_state("open")`, `set_state("treasure")` or `set_state("magic")`.
Open has an empty cavity, Treasure has sourced coins, and Magic has sourced
light/spark textures. The shared state catalog keeps these views exclusive.
Reward eligibility and amounts remain game-owned.

`cavity_3d` supplies the measured cavity anchor; optional `cavity_bounds_3d`
retains inner walls and floor for fitting loot. `closed_bounds_3d` and
`opened_bounds_3d` describe measured endpoints. The renderer samples actual
cover motion when framing a model; endpoint unions are not swept bounds.

Most runtime designs use embedded baked PBR maps up to 1024 pixels. Harvest
Strongbox preserves its acquired overlapping shell, imported normals and source
PBR materials while reducing added hardware; its fitted inner backing closes
a source underside gap. Its documented 50,000-triangle budget protects source
shading. Moonstone Crown keeps its original SourceUV palette as an embedded PNG,
preserving purple panels, silver rims and aqua jewelry. Both use several material
slots on two rigid mesh batches. Other Heritage designs use one baked material.

## Sources and validation

The twelve original designs, four CC0 Heritage editions and seven Relic editions
retain Kenney/Kay Lousberg CC0 terms. Meadow Cabinet, Harvest Strongbox, Bonbon Keepsake, Lagoon Reliquary
and Moonstone Crown retain their source Unity Asset Store EULA for embedded game
artwork. Atelier identifies the collection, not a common license. Source creators,
URLs, acquired hashes and authored changes remain in each catalog entry and
[provenance](../../sources/atelier/provenance/). Original creator notices remain
in [licenses](../../sources/atelier/licenses/).

The original twelve-model native report is retained as historical evidence.
The current [native state report](../../sources/atelier/validation/relic-state-report.json)
binds imported models and four-state graphics readback to exact GLB hashes;
`atelier.json.native_validation` records its current result. Actual new-edition
capture strips are retained in the review collection under
`Q:/uwok/chest/sources/relic/validation/`. Phone performance is a separate
measurement. Authoring scenes, matched previews and the local review studio
remain in `Q:/uwok/chest`.

## Relic edition

Seven additional CC0 source-derived designs add an ornate gilded lock, emerald
setting, glowing rune armor, protected carry handle, wooden barrel, sculpted
satin bow and layered royal wings. Their optimized GLBs total
8,878,704 bytes, 38.79% below authoring GLBs.
Exact provenance and measurements are in
[Relic evidence](../../sources/atelier/provenance/relic-editions.json).
All four states were checked using the exported model bytes.
