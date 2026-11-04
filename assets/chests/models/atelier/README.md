# Treasure Atelier runtime library

12 optimized chest assets prepared for tesisgame, including the revision 3 expansion. This adds an asset library; the active reward catalog is not selected by this publication.

| Design | Model | GLB bytes | Triangles |
| --- | --- | ---: | ---: |
| Royal Rose | `royal-rose/royal-rose.glb` | 1,237,636 | 13,123 |
| Moonbound | `moonbound/moonbound.glb` | 1,295,512 | 13,077 |
| Sunward | `sunward/sunward.glb` | 1,294,424 | 12,986 |
| Tideguard | `tideguard/tideguard.glb` | 1,549,360 | 16,873 |
| Aether Vault | `aether-vault/aether-vault.glb` | 1,650,892 | 19,113 |
| Cobalt Vault | `cobalt-vault/cobalt-vault.glb` | 1,634,188 | 19,113 |
| Solar Relay | `solar-relay/solar-relay.glb` | 1,845,100 | 21,759 |
| Frost Relay | `frost-relay/frost-relay.glb` | 1,857,808 | 21,759 |
| Prism Signal | `prism-signal/prism-signal.glb` | 1,605,224 | 19,079 |
| Jade Reliquary | `jade-reliquary/jade-reliquary.glb` | 1,632,244 | 19,193 |
| Crimson Citadel | `crimson-citadel/crimson-citadel.glb` | 1,745,060 | 20,891 |
| Nova Buddy | `nova-buddy/nova-buddy.glb` | 1,639,428 | 19,573 |

The GLBs total **18,986,876 bytes**. Godot-generated extracted PNGs and `.import` sidecars are separate from this total and are preserved. Each GLB embeds its geometry, color, normal and packed roughness/metallic maps. The single-UV materials use ordinary glTF 2.0 with no required external codec.

## Integration contract

Read each model's `style` dictionary in [atelier.json](../../catalog/atelier.json). Each model and its extracted textures live in an `<asset-id>/` folder here. Model paths are project relative; `resource` supplies the corresponding `res://` path. Use `normalize_model: false` to preserve the exported coordinates and `material_profile: {}` to keep the imported PBR finish. The files are +Y up, +Z front, +X right, with a two-unit source-shell width and feet at Y=0; hardware can extend beyond that shell width.

Keep `ChestRoot`, `Body`, empty hinge `Lid`, child `LidShell`, and `Treasure`. The game seeks `Open` or `Close` over one second; animation completion does not grant rewards. `Lid` supplies the rigid negative-X 100-degree opening. Hide `Treasure` for closed/empty/magic views and show it for the treasure view. Magic rays and glow are separate game effects.

`closed_bounds_3d` and `opened_bounds_3d` are measured runtime-export endpoints transformed from Blender `(x,y,z)` to `(x,z,-y)`. The original measured bounds remain in `runtime_source_record`. An endpoint union is not advertised as a full motion bound. Supply measured cavity/seam metadata and let the existing renderer sample the complete lid motion when later selecting a gameplay tier. The current renderer also measures hidden mesh instances, so review framing through its actual caller.

## Sources and validation

Chest geometry, original UV material and ornaments derive from Kenney's Blaster, Platformer, Mini Dungeon, Survival and Tower Defense kits and Kay Lousberg's KayKit Dungeon Remastered. Real KayKit coin-pile meshes supply the treasure. New work adds fitted hardware, fine surface finishing, localized luminous cores and one-second lid clips; runtime processing reduces hardware/loot geometry and bakes the finish to compatible PBR maps. Original creator notices are unchanged in [licenses/](../../sources/atelier/licenses/). Original acquisition/provenance records are retained under [provenance/](../../sources/atelier/provenance/); their source paths refer to the chest authoring collection. Each manifest entry preserves its full authoring and optimization source records, including original and derived hashes.

All 12 final GLBs passed 1296 native Godot checks with graphics readback. The report binds its results to each published SHA-256 and byte count. This validates native import, material presence, hinge motion and graphics capture; physical phone performance is a separate measurement. The publication does not change reward rules or gameplay catalog selection. The authoring `.blend`, full-resolution PNG states and review studio remain in the chest collection.
