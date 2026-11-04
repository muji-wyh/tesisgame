# Chest asset provenance

The source files in this collection are acquired production models by Kenney
and Kay Lousberg, copied without alteration from the existing verified
`tesisgame/assets/chests/catalog-cc0` collection on November 3, 2026. All included
sources use [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).
The original license notices remain beside each source and in `../licenses/`.
No private Unity Asset Store model, texture, package, controller, or shader is
included.

| Source folder | Creator and original source | Included material | Available source animation |
| --- | --- | --- | --- |
| `sources/kenney-survival` | Kenney, [Survival Kit](https://kenney.nl/assets/survival-kit), acquired version 2.0 | Chest, original palette PNG, license | Separate `lid`; `open` (~0.3 s), `close` (1 s), `open-close` (2 s) |
| `sources/kenney-platformer` | Kenney, [Platformer Kit](https://kenney.nl/assets/platformer-kit), acquired version 4.1 | Chest, jewel, lock, gold coin, original palette PNG, license | Chest has separate `lid` and the same three clips; ornaments are static |
| `sources/kenney-mini-dungeon` | Kenney, [Mini Dungeon](https://kenney.nl/assets/mini-dungeon), acquired version 2.0 | Chest, round and rectangular shields, original palette PNG, license | Chest has separate `lid` and the same three clips; ornaments are static |
| `sources/kaykit-dungeon` | Kay Lousberg, [KayKit Dungeon Remastered](https://kaylousberg.itch.io/kaykit-dungeon-pack), free version 1.0 | Chest, coin, small and medium coin stacks with embedded texture atlases, license | Separate `chest_lid`; no source animation clips; loot meshes are static |
| `sources/kenney-tower-defense` | Kenney, [Tower Defense Kit](https://kenney.nl/assets/tower-defense-kit), acquired version 2.0 | Crystal, original palette PNG, license | Static ornament |
| `sources/kenney-particles` | Kenney, [Particle Pack](https://kenney.nl/assets/particle-pack), acquired version 1.1 | Four original transparent light/star sprites, license | Static effect textures for authored compositing |

The KayKit source is pinned to official creator repository commit
[`b0ca9bd96a8072ab36a3a5464f00ed1e06a16d07`](https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0/tree/b0ca9bd96a8072ab36a3a5464f00ed1e06a16d07).
Kenney inputs originate from the user's acquired Kenney Game Assets All-in-1
3.7.0 collection. Pack versions above come from their original license notices.
Current public pages may describe newer versions.

## Verification and acquisition status

The 19 previously acquired source files contain ten GLBs, four palette PNGs, and
five original license notices, totaling 284,222 bytes. All 19 were verified after
copying against the existing acquisition manifest's SHA-256 values. Three
additional original KayKit GLBs were downloaded from the pinned official creator
repository for this collection: `coin.gltf.glb`, `coin_stack_small.gltf.glb`, and
`coin_stack_medium.gltf.glb`. Their Git blob SHA-1 values were checked against
the pinned repository tree; SHA-256 values were computed after download. The
combined 22 model-source files total 408,398 bytes. Four 512 by 512 transparent
sprites (`light_01.png`, `light_02.png`, `star_04.png`, `star_09.png`) and their
original notice are additionally copied from the user's acquired Kenney Particle
Pack 1.1. All 27 source files total 676,720 bytes. These are actual downloaded
models and production textures, separate from listing previews.

[`../sources/staging-record.json`](../sources/staging-record.json) records the
current collection-relative paths, file sizes, source IDs, and checked hashes.
[`../sources/acquisition-record.json`](../sources/acquisition-record.json) is an
unchanged copy of the earlier acquisition manifest (SHA-256
`678511aa8f49f8a60d793e539c09d28e3862a07fe3c5a7956c9cef0ff0727f07`).
Its project-relative paths and integration notes describe the earlier tesisgame
catalog. They do not claim that this new collection has been integrated or
approved in the game.

[`../sources/kaykit-dungeon/coin-acquisition.json`](../sources/kaykit-dungeon/coin-acquisition.json)
records the additional loot models' original URLs, verified Git blob hashes,
SHA-256 values, sizes, real mesh bounds, and triangle counts. The actual GLB JSON
and binary geometry were inspected: the coin has 80 triangles, the small stack
416, and the medium stack 968. Each has one embedded texture atlas, no external
dependencies, and no animation clips. The existing original KayKit license was
also checked against the pinned official repository's original license bytes.

[`../sources/kenney-particles/acquisition.json`](../sources/kenney-particles/acquisition.json)
records the four original effect sprites' pack paths, dimensions, sizes and
SHA-256 values, plus the original license hash. They are unchanged transparent
source images used for the magic render's compositing. Their notice credits
Kenney and filter-template contributors Indigo Ray, Craig Nisbet, Zoltan
Erdokovy, Heliagon, ThreeDee, Killst4r, and Tim2501. The original notice is also
preserved in `licenses/kenney-particles-LICENSE.txt`.

Preserve the case-sensitive `Textures/colormap.png` path beside each Kenney
model. KayKit embeds its atlas in the GLB and needs no external PNG.

## Derived collection and reference

The detail pass also extracts genuine KayKit keyhole/clasp and rivet components,
and the Kenney padlock shackle, into `components/`. Their original polygons,
source UVs, atlas materials, source/output hashes, and exact component selection
are recorded in [the component provenance](../components/provenance.json).
See [the component notes](../components/README.md) for node names, orientation,
licenses, and the difference between the real KayKit keyhole and Kenney's
diamond inset. Source models are never overwritten by the extraction tool.

Revision 2 additionally uses original collection-authored hardware fitted to the
acquired shells: layered edge rails, corner shoes, domed fasteners, rear hinge
plates and barrels, rolled side handles with backplates and mounting pins, and
theme-specific trim. These additions are authored by `tools/chest_details.py`.
They are separate from the external CC0 production models and the extracted
creator fittings; they are not claimed as Kenney or Kay Lousberg source meshes.
Body hardware belongs to the fixed `Body` hierarchy and lid hardware follows the
real `Lid` hinge. Generated metadata records the authored piece count separately
from the number of exported hardware objects after batching.

`tools/surface_details.py` authors supplementary panel normal/roughness maps and
fine metal normal finishing. The acquired source atlas remains the main color
artwork on UV0; a separate secondary UV set drives the new surface finishing.
Those generated maps are collection-authored supplements, not downloaded source
textures. The GLBs embed the generated maps. Their presence does not claim that
the original sources included detailed wood grain, enamel scoring, or brushed
metal maps.

The new derivative families use these original production geometries:

| Derivative ID | Original chest base |
| --- | --- |
| `royal-rose` | Kenney Platformer Kit |
| `moonbound` | Kenney Mini Dungeon |
| `sunward` | Kenney Survival Kit |
| `tideguard` | KayKit Dungeon Remastered |

Derivative palettes, softened edges, ornament arrangements, loot composition,
render lighting, and any newly authored motion are adaptations made for this
collection. They are not publisher-authored variants or additional original
source models. The collection manifest records the generated outputs and their
available states. A local review page is separate from integration into the
tesisgame reward system.

The user-supplied image is a visual reference for three-quarter views, broad
metal framing, distinct material palettes, and closed/open/loot/glow states.
The image's original creator and license are unknown; it is not an acquired
source of production pixels or geometry for this collection. The sources listed
above provide the reusable production material.
