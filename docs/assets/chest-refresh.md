# Themed chest replacement

The Autumn, Ocean, Space, Jungle, and Candy reward scenes use five distinct
acquired chest designs with softer colors and edges. Their closed forms are
also reused by the shared round celebration. Spring Royal, Summer Energy, and
Winter Crystal retain their existing artwork. Opening rules, rewards, timing,
effects, and audio remain the responsibility of the existing chest presentation.

| World | Runtime design | Acquired source design | Material direction |
| --- | --- | --- | --- |
| Autumn | Harvest Keepsake | Batata `Treasure_Chest_4a` | Amber wood and champagne trim |
| Ocean | Lagoon Pearl | Batata `Treasure_Chest_1a` | Teal, pale aqua and pearl |
| Space | Moonstone Vault | Bobardo `Epic Chest` | Lilac enamel, pearl framing and a gemstone |
| Jungle | Meadow Explorer | Ekrem `Chest_Animated` | Warm wood and leafy green framing |
| Candy | Strawberry Bonbon | Batata `Treasure_Chest_2a` | Strawberry rose and vanilla bands |

## Sources and acquisition

All three packages are downloaded production sources, not listing images. They
use the [Unity Asset Store Standard EULA](https://unity.com/legal/as-terms).
Original packages, extracted payloads, and acquisition evidence are retained
outside the repository in `C:/uworks/TalkQuest`.

| Source | Creator | Version | Package SHA-256 |
| --- | --- | --- | --- |
| [POLY STYLE - Fantasy Treasure Chest](https://assetstore.unity.com/packages/3d/props/poly-style-fantasy-treasure-chest-280107) | Batata Studio | 1.15 | `ca35e6d033bf29cf3b247d866d8b3db0b4a8800e691a97bbc31002712ac0b75e` |
| [Stylized 3D Animated Chests - FREE Demo](https://assetstore.unity.com/packages/slug/360542) | Bobardo | 1.0 | `2356a6173afd53692fec5fb0360fbfcb9eb3f73549d13600e5446d66c8f18375` |
| [Low Poly Chest Animated](https://assetstore.unity.com/packages/3d/props/low-poly-chest-animated-247127) | Ekrem C. | 1.0 | `a0022b1fbe2f1762114774f10a2ecdacf2db169f9c01d51dbe42497213fd8397` |

`asset-review/sources.additional-chests.json` records the Batata and Ekrem
product pages, free price and Standard EULA check on 2026-10-01, official
package IDs, full gzip CRC/length verification, safe extraction, and source
hashes. `asset-review/sources.downloaded.json` records the acquired Bobardo
package; `processing/acquisition-audit.json` and
`processing/source-validation.json` retain its product-ID/archive checks and
source/preview validation. These hashes identify local acquired bytes; they
are not publisher-supplied checksums.

Source contact sheets and model previews were inspected before conversion.
The [runtime manifest](../../assets/chests/downloaded/manifest.json) identifies
the converted and integrated files separately, including their source design,
model, texture, and output hashes. Private GLBs and import sidecars remain
ignored build inputs and ship inside the compiled game pack only. No reusable
source library or publisher scripts/controllers are distributed.

## Geometry and material preparation

Source roots below are relative to `C:/uworks/TalkQuest/sources`:

- Batata: `poly-style-fantasy-chest/ca35e6d033bf29cf/tree/Assets/POLY STYLE - Fantasy Treasure Chest/Fantasy Treasure Chest_URP/`.
  Geometry comes from `Art/Meshes/Chest/Meshes.fbx`; design references are
  `Prefabs/Chest/Treasure_Chest_4a.prefab`, `Treasure_Chest_1a.prefab`, and
  `Treasure_Chest_2a.prefab` in the same folder.
- Bobardo: `stylized-chests/2356a6173afd5369/tree/Assets/Stylized 3D Animated Chests – FREE Demo/`.
  Geometry and textures come from `Resources/Chsets/Epic Chest/`; the design
  reference is `BIRP/Chsets/Epic Chest/EpicChest_PF_BIRP.prefab`.
- Ekrem: `low-poly-chest-animated/a0022b1fbe2f1762/tree/Assets/Low Poly Chest Animated/`.
  The model is `Model/Chest_Animated.fbx`; `Prefabs/Chest_Green.prefab` supplies
  the selected design reference. Blue and green prefabs use the same mesh IDs.

The converter consumes the existing verified Unity geometry exports under
`C:/uworks/TalkQuest/asset-review/media/`:

| Runtime design | Export path | Body / separate lid |
| --- | --- | --- |
| Harvest Keepsake | `additional-chest-previews/poly-style-4a/rest.json` | `Treasure_Chest_4a` / `Opened_6` |
| Lagoon Pearl | `additional-chest-previews/poly-style-1a/rest.json` | `Treasure_Chest_1a` / `Opened_15` |
| Moonstone Vault | `chest-prefab-previews/epic-chest/rest.json` | `Chest Eoic.003` / `Cube.023` |
| Meadow Explorer | `additional-chest-previews/low-poly-blue/rest.json` | `Chest_Bottom` / `Chest_Up` |
| Strawberry Bonbon | `additional-chest-previews/poly-style-2a/rest.json` | `Treasure_Chest_2a` / `Opened_12` |

The original body designs and UVs are preserved. Harvest Keepsake retains the
largest connected lid shell, removing the source skull/bone clasp and six
pointed ornaments. Strawberry Bonbon's studs are integral to its bands; their
pointed tops are lowered into shallow fittings while retaining the barrel form.
Per-design rim anchors exclude decorative handles, wings, and chains, placing
the opening light along the actual cavity rather than the full ornament bounds.

A three-segment bevel at 0.28% of source width softens edges. Pastel colors,
metallic response and roughness are game adaptations on the source material
slots; no procedural wood grain is added.
POLY loot meshes are omitted. Missing review material slots in families 1 and 2
receive a deliberate theme inset material rather than a claim of source fidelity.

Moonstone remaps color regions in the original 1024px
`EpicChest_BaseMap_01_TEX.png` and retains `EpicChest_AOmap_01_TEX.png` shading.
Meadow uses the verified **blue** prefab export with an authored green palette;
there is no previously verified green render/export. The source green material
and matching green prefab establish the selected color/design reference, not
pixel-identical reproduction of a green preview.

## Available animation versus runtime motion

| Source | Available source animation | Integrated motion |
| --- | --- | --- |
| POLY STYLE | No chest clips; separate static open/closed parts. The five demo timeline clips animate cameras. | Game-authored 92-degree lid hinge |
| Epic Chest | `EpicChest_Intro_ANIM`, `EpicChest_Idle_ANIM`, `EpicChest_Open_ANIM`, `EpicChest_Pickup_ANIM` | Game-authored magnetic cover lift of 1.16 source units before normalization |
| Low Poly Chest Animated | `Chest_Open_Close` (2.15 s), `Chest_Rotation`, `Chest_Shake` | Game-authored 92-degree lid hinge |

Each runtime `Open` take is a continuous one-second curve sampled at 60 Hz.
The caller maps it onto the existing chest sequence. No original clip is claimed
as preserved by this conversion. The original Ekrem opening/closing clip has
verified local samples; the Epic opening clip was inventoried but had no sampled
opening preview in the retained review collection.

## Rebuild

From the repository root, with Blender 5.2 and the acquired archive available:

```powershell
blender --background --factory-startup --disable-autoexec --python tools/prepare-chest-models.py --
python tools/prepare-chest-models.py --optimize
node tools/package-chest-models.cjs
npm run import
```

The converter defaults `--source-root` to `C:/uworks/TalkQuest/sources` and
expects the verified exports in sibling `asset-review/media`. `--output` and
`--work` relocate the generated GLBs and reports. The packager accepts the
TalkQuest root as its first argument. Convert all five models before packaging;
the packager checks their metadata and hashes before replacing the manifest.

Review renders and conversion reports are written to ignored
`build/chest-quality/`. The native `tests/godot/chest_models_visual_review.gd`
captures the actual presentation with a graphics renderer; use
`--audio-driver Dummy` for silent captures. Source-preview inspection does not
replace runtime opening, layout, or deployment verification.
