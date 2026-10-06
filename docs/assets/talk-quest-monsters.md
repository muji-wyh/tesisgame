# Talk Quest monster models

> Archived on 2026-10-06. Talk Quest has been removed from the game. This
> document preserves the former implementation, source provenance, and review
> evidence. Its asset paths, interfaces, and commands describe that revision;
> they are not current build prerequisites or instructions to restore the mode.
> Retained manifests and license records do not mean the runtime assets ship.

The original fourteen models in `assets/talk_quest/monsters` are complete rigged 3D
characters from [Low Poly Monsters Pack, product 380750](https://assetstore.unity.com/packages/3d/characters/low-poly-monsters-pack-380750).
They are licensed under the **Standard Unity Asset Store EULA** for use in the
game. The GLBs, source-preview PNGs, and their Godot import sidecars are private
local build inputs excluded from Git. They ship inside the compiled game pack.
The public repository includes the manifests and conversion tools, without
redistributing the reusable source characters.

The active campaign uses eleven of these original characters and three
[acquired giants](talk-quest-giants.md) at levels 1, 12 and 14. The original
catalog remains available for compatibility. That source record also documents
the supplemental giant manifest and animation provenance.

Each GLB contains the original selected mesh, its source armature, exact embedded
FBX diffuse colors, and a measured moving source `Idle` clip. Eight characters
also include `Celebrate`. The PNGs are previously reviewed source previews for
level cards; the main game character uses the GLB. Their transparent padding is
cropped to the complete nonzero-alpha silhouette, fitted within 288 by 288
pixels, and replaced with a 16-pixel transparent margin on every edge. No source
colors, opaque backgrounds, or model parts are removed.

| Models | Exported source animations |
| --- | --- |
| Alien, Bird, Bunny, Cactoro, Dino, Frog, Mushroom, Yeti | `Idle`, `Celebrate` |
| Alpaking, Armabee, Glub, Goleing, Hywirl, Squidle | `Idle` |

No usable source `Hit` or `Defeat` clips were present in these selected base
characters. The runtime script explicitly authors a brief squash/recoil, a
friendly shrinking retreat, and celebration hops. Cooperative mode disables
hit/defeat, starts a resting pose with breathing, gradually lights the character
as repairs progress, and wakes it with a stretch and available source
celebration. Those game reactions are not represented as verified source clips.

## Runtime interface

`scripts/talk_quest_monster.gd` extends `Node3D`. The caller owns its SubViewport,
camera, lights, game state, and UI. Load one character at a time with
`set_creature("lpm-alien")`; no model is preloaded by the script.

- `set_creature(id) -> bool`, `reset_pose()`, `play_idle()`
- `react_hit() -> bool`, `defeat() -> bool`, `celebrate()`
- `set_cooperative_mode(enabled)`, `set_sleeping(sleeping)`
- `repair_progress(completed, total = 5)`, `wake_up()`
- `set_reduced_motion(enabled)`
- `get_normalized_height()`, `get_model_bounds()`, `source_animation_names()`
- `reaction_finished(kind)` signal (`hit`, `defeat`, `celebrate`, `repair`, `wake`)

Coordinates use Godot Y-up, front +Z, source rest floor y=0, and a maximum source
rest extent of 2.0. `manifest.json` records each character's actual height and
animations. Flight poses may hover above the source rest floor. The caller
should frame the full 2.0 extent and aim near half the recorded height.

The total GLB payload is about 3.38 MiB. Each model has 17–65 bones, 2,280–8,284
source triangles, and at most two exported animations. The standard glTF
exporter keeps the four strongest normalized skin weights per vertex for Web
Compatibility performance. Source topology is retained; glTF splits vertices at
normal/material boundaries. The exported GLB baseline uses texture-free
materials with source linear diffuse values, roughness 0.72, and metallic 0.0.
At runtime, creature-specific surface profiles adjust roughness and specular
response and add shared 64 by 64 procedural color and normal grain. Eye whites
and pupils retain restrained highlights. Anatomy-specific skeletal gestures
and weight-dependent reactions are runtime additions, not newly exported source
animations. The game's cooperative repair emission is a separate temporary
visual effect.

## Provenance and reproducibility

The retained archive SHA-256 is
`55dce3d4f4fe9e89fbe3cb98ebde6f2c080a1b07930224aabe24c61b3e9c4b32`.
The current listing identified **Low Poly Monsters Pack / Visible Ghost / 1.1**,
dated June 29, 2026. The downloaded archive identifies **50+ Monsters Bundle /
Wabu / 1.0**, dated May 17, 2026. Both carry product ID **380750**. Original
metadata is retained in `talk-quest-monsters.json`; the discrepancy does not
create a second source or a claim that version 1.1 was downloaded.

The approved local source selection contains fourteen unique design families,
paths, and file hashes. Evolution, recolor, blob counterparts, and alternate
poses do not increase the count. `assets/talk_quest/monsters/manifest.json`
records source and output hashes. `docs/assets/talk-quest-monsters.json` records
every evaluated candidate clip, the exact exported source action, source
materials, and conversion settings. Thumbnail evidence records the reviewed
source hash, exact alpha crop, output dimensions, margin, and output hash.

Before importing or building a fresh checkout, acquire the licensed source pack
and restore the fourteen selected models and portraits to
`assets/talk_quest/monsters`. These are required build inputs; the manifest alone
does not contain model or portrait data. On the maintained workstation the
licensed sources and review selection are retained under `C:\uworks\TalkQuest`.

With Python/Pillow and Blender available, reproduce from that retained local
TalkQuest review directory (no downloads or Unity project import):

```powershell
python tools/talk-quest-monsters/prepare.py --source-root C:\uworks\TalkQuest --blender "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
python tools/talk-quest-monsters/publish.py --source-root C:\uworks\TalkQuest
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup --python tools/talk-quest-monsters/validate_runtime.py -- C:\uworks\tesisgame
```

The converter evaluates seven skinned-mesh samples per source candidate and
rejects static or unbounded takes. Publication checks every mesh has skin
weights, every animation has actual samples, the GLB colors equal source
diffuse values, and every reviewed thumbnail/source hash matches. Roundtrip
validation reloads all exported GLBs and measures actual animated mesh motion.
Godot import and browser gameplay checks are performed by the game's integration
workflow; Blender-only evidence does not claim those checks passed.
