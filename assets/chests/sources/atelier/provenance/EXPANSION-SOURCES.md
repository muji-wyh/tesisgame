# Sci-fi chest expansion sources

The selected production bases are the acquired Kenney Blaster Kit cases. Their
real meshes already include chamfered shells, recessed cavities, handles,
clasps, a separate lid, and original opening animation. They provide a better
starting point for the new sci-fi designs than the existing fantasy chests.
The requested eight designs are new adaptations of these source cases, not
eight separately acquired native chest families.

## Acquisition and license

Original inputs were copied byte-for-byte from the user's acquired
`Q:/uwok/Kenney Game Assets All-in-1 3.7.0/3D assets/` collection. Every staged
pack has its original Kenney CC0 notice. No marketplace-only preview, private
Unity package, or unlicensed model was staged. The existing game's private
Standard-EULA chests are excluded from this reusable collection.

`sources/expansion/staging-record.json` records the original absolute path,
creator, public source URL, pack version, original notice, bytes, SHA-256, node
names, materials, texture dependencies, triangle counts, and acquired animation
clips. It covers 34 unchanged original files totaling 603,874 bytes: 27 models,
four notices, and three required palette PNGs. The separate `review/` folder
contains newly rendered source previews and review scripts; those are not
unchanged creator files.

| Staged source folder | Creator / version | Public source |
| --- | --- | --- |
| `sources/expansion/kenney-blaster/` | Kenney / Blaster Kit 2.1 | <https://kenney.nl/assets/blaster-kit> |
| `sources/expansion/kenney-space-station/` | Kenney / Space Station Kit 1.0 | <https://kenney.nl/assets/space-station-kit> |
| `sources/expansion/kenney-factory/` | Kenney / Factory Kit 3.0 | <https://kenney.nl/assets/factory-kit> |
| `sources/expansion/kenney-space/` | Kenney / Space Kit 2.0 | <https://kenney.nl/assets/space-kit> |

Each folder's `LICENSE.txt` is an unchanged copy of the pack's original
`License.txt`. The license is CC0-1.0. Preserve the records and notices with any
derived library even though CC0 does not require attribution.

## Selected animated production cases

All three paths below are relative to
`Q:/uwok/chest/sources/expansion/kenney-blaster/`:

| Model | Bytes | Body / lid triangles | Acquired clips |
| --- | ---: | ---: | --- |
| `crate-small.glb` | 59,020 | 372 / 256 | `open`, `close`, `open-close` |
| `crate-medium.glb` | 59,344 | 372 / 256 | `open`, `close`, `open-close` |
| `crate-wide.glb` | 59,404 | 372 / 256 | `open`, `close`, `open-close` |

These are related case proportions with the same topology, not three unrelated
topological designs. The original source palettes distinguish mint, violet, and
yellow bodies. Each source uses a single `colormap` material, UV0, real vertex
normals/tangents, and the required case-sensitive sibling
`Textures/colormap.png`. The original palette material has `metallicFactor=0`;
new metallic response, normal detail, roughness, emission, and theme colors must
be recorded as authored adaptations rather than source features.

The source root mesh has the case filename as its node name and a child mesh
named `lid`. Source glTF coordinates are +Y up, with width along Z, front toward
-X, and the hinge at X=+0.25, Y=0.19. The source `open` clip rotates that lid
-135 degrees around Z over 0.6 seconds; `close` lasts 1 second and
`open-close` lasts 2 seconds. They are genuine acquired clips, distinct from any
new one-second `Open` and `Close` takes authored for the collection.

Rotate the source +90 degrees around glTF Y to reach the collection's +Y-up,
+Z-front orientation. After standard Blender glTF import, the equivalent is
+90 degrees around Blender Z. This maps the width to X and the hinge to the
rear -Z side. Normalize the resulting closed case to width 2 and preserve the
real lid pivot when authoring the collection's 100-degree negative-X opening.

Blender import activates an acquired action at its current frame. Merely
calling `animation_data_clear()` leaves the evaluated lid transform behind.
Explicitly reset the imported `lid` local quaternion to `(1, 0, 0, 0)` before
measuring the closed shell or authoring new keys. The raw glTF bind-pose lid has
translation only and no rotation. Otherwise a partially open source can be
mistaken for the closed pose.

## Other acquired geometry available for real components

| Folder and models | Verified properties | Appropriate use |
| --- | --- | --- |
| `kenney-space-station/container*.glb` | Five static container variants, 88–132 triangles; no opening clips. `container-tall` includes an additional `Group` mesh. | Alternative cargo shells if an actual lid cut and lined cavity are authored and reviewed. |
| `kenney-space-station/container-flat-open.glb` | Static alternate open container, one mesh; no hinge or animation. | Interior construction reference, not a ready animated chest. |
| `kenney-space-station/computer-{screen,system,wide}.glb` | Genuine static console meshes, 174–198 triangles. | A physical display housing or instrumentation component. |
| `kenney-factory/box-{small,large,long,wide}.glb` | Four static 70-triangle industrial boxes. | Alternative cargo panels and shell details; no native lids or clips. |
| `kenney-factory/machine-window.glb` | 428 triangles, original atlas plus an alpha-blended glass material. | Real machinery window/frame geometry; adapt transparency deliberately for GL Compatibility. |
| `kenney-factory/machine-connection-hole.glb` | 294 triangles, static mechanical connector. | Core socket or physical port surround. |
| `kenney-factory/robot-arm-a.glb` | 472 triangles across nine named meshes, no clips. | Acquired joints, brackets, and mechanical fittings. |
| `kenney-factory/screen-panel-{flat,small,wide}.glb` | Static panel assemblies, 138–162 triangles. | Physical face/display backing for the friendly robot chest. |
| `kenney-space/machine_generator*.glb` | Two production generators, 126 and 406 triangles. | Sourced reactor/core machinery and cable geometry. |
| `kenney-space/machine_barrel*.glb` | Two production barrel machines, 192 and 338 triangles. | Sourced circular or cylindrical energy details. |
| `kenney-space/{barrel,desk_computerScreen}.glb` | Static production barrel and screen, 56 and 108 triangles. | Additional core casing or display geometry. |

Space Station and Factory use their own staged sibling
`Textures/colormap.png`; do not substitute the Blaster atlas. Space Kit models
use original named material colors with no image dependencies. Their source
geometry remains production artwork; new finishes and assemblies are separate
authored work. All secondary models listed above are static and have no acquired
animation clips. Binary mesh/node/material inspection is recorded in the staging
record; only the selected Blaster bases have dedicated source render previews.

## Eight proposed source-based adaptations

| Design | Suggested production base | Distinct authored direction |
| --- | --- | --- |
| Aether Vault | Blaster small | Ivory and gold layered case, purple gem and detailed inset crest. |
| Cobalt Vault | Blaster small | Dark structural shell, silver armor, cyan energy instrumentation. |
| Solar Relay | Blaster medium | Yellow and charcoal case, round or octagonal core with sourced machinery fittings. |
| Frost Relay | Blaster small | Ice-blue and white segmented frame with cold energy details. |
| Prism Signal | Blaster wide | White and magenta shell with a triangular signal assembly. |
| Jade Reliquary | Blaster wide | Green and gold case with a diamond-shaped focal assembly. |
| Crimson Citadel | Blaster wide | Red and gold reinforced shell with a hexagonal focal assembly. |
| Nova Buddy | Blaster medium | White and red rounded robot case, physical display housing, friendly face. |

The source case, cavity, handle, and lid remain acquired production geometry.
New armor, fitted trim, core assemblies, friendly display artwork, and surface
finishing need their own authorship records and visual review. Supplied reference
images guide the design; they are not evidence of acquisition or licensing for
the underlying depicted game models.

## Review and integration status

The original Blaster source geometry and materials are rendered at 512 pixels
under `sources/expansion/review/`. The source contact sheet is
`blaster-source-contact.png`. Previews are rotated and normalized for inspection;
the open view matches the source's 135-degree hinge endpoint. They show source
meshes rather than completed expansion designs or game integration.

Source staging does not publish runtime assets or change the game's catalog.
Derived exports must retain provenance, stable `Body`/`Lid`/`Treasure` semantics,
single-UV native PBR materials, exact-byte native validation, and separate browser
and packaged-resource checks appropriate to the final change.

The focused native harness accepts the expansion recipe list directly, while
its default selection remains the original four families:

```powershell
node tools/run-godot.cjs --headless --path . --script Q:/uwok/chest/tools/verify_runtime_godot.gd -- --manifest Q:/uwok/chest/tools/expansion-recipes.json --output Q:/uwok/chest/build/expansion/native-structural
node tools/run-godot.cjs --rendering-method gl_compatibility --resolution 256x256 --position -32000,-32000 --path . --script Q:/uwok/chest/tools/verify_runtime_godot.gd -- --manifest Q:/uwok/chest/tools/expansion-recipes.json --capture --output Q:/uwok/chest/build/expansion/native
```

Run these commands from `Q:/uwok/tesisgame` after the selected runtime copies
have been imported. `--assets aether-vault,cobalt-vault` selects a comma-separated
subset; `--asset` remains a compatible alias. `--manifest` accepts a recipe
array, a runtime object with `models`, or a collection object with `variants`.
It supplies IDs and display titles rather than changing the default model
directory. `--models-root` can override `res://assets/chests/atelier`.

The eight expansion IDs require an actual localized emissive map in the source
GLB and enabled native emission after import. A bright albedo color alone does
not satisfy this check. Single-UV color/normal/roughness contracts, real lid
motion, fixed body, loot visibility, and exact-byte import-cache verification
remain required. The original four families retain their three-mesh contract;
the new families allow three to eight meshes for additional physical details.
A manifest entry's optional `native_validation` object can specify `mesh_count`
or `mesh_count_min`/`mesh_count_max`, and `expected_emission` for future models.
The generalized harness passed all original four models and separately passed
manifest parsing plus comma-separated selection against existing imported
assets. This regression does not claim that the eight new exports are already
published or native-validated.
