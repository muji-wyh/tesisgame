# Talk Quest giant creature sources

> Archived on 2026-10-06. Talk Quest has been removed from the game. This
> document preserves the former implementation, source provenance, and review
> evidence. Its asset paths, interfaces, and commands describe that revision;
> they are not current build prerequisites or instructions to restore the mode.
> Retained manifests and license records do not mean the runtime assets ship.

The selected refresh replaces three level creatures with distinct, imposing
source models. These are new character designs rather than scaled versions of
the existing cute roster. The other eleven original level creatures remain
active; there are still fourteen level assignments.

| Level | New identity | Selected source | Replaced identity |
| ---: | --- | --- | --- |
| 1 | `giant-rock-guardian` | Mini Legion Rock Golem, handpainted appearance | `lpm-goleing` |
| 12 | `giant-storm-dragon` | Animated Witch and Dragon Monster, dragon only | `lpm-alpaking` |
| 14 | `giant-ember-golem` | Golem / GolemMonster | `lpm-alien` |

[The source manifest](talk-quest-giants-sources.json) records product URLs,
publisher archive metadata, exact package and selected-input SHA-256 values,
texture dimensions, prior preview evidence and animation limitations. Its local
paths are relative to the maintained source root, `C:/uworks/TalkQuest`. The
manifest is a source handoff; it does not claim converted models or target-game
animation have passed validation.

## Acquisition and license

These packages were acquired through the official Unity Asset Store browser and
Unity Package Manager workflow. They use the
[Standard Unity Asset Store EULA](https://unity.com/legal/as-terms). Keep the
archives, reusable source models, textures and converted character build inputs
private. The game may embed the licensed content in its compiled game pack;
this documentation and the hashes do not redistribute the source assets.

| Source | Official product | Retained version | Publisher |
| --- | --- | --- | --- |
| Mini Legion Rock Golem PBR HP Polyart | [94707](https://assetstore.unity.com/packages/3d/characters/humanoids/fantasy/mini-legion-rock-golem-pbr-hp-polyart-94707) | 1.2, January 14, 2020 | Dungeon Mason |
| Animated Witch and Dragon Monster | [49955](https://assetstore.unity.com/packages/3d/characters/animated-witch-and-dragon-monster-49955) | 1.1, November 24, 2015 | masatomo |
| Golem | [33260](https://assetstore.unity.com/packages/3d/characters/creatures/golemmonster-33260) | 2.0, December 12, 2021 | Siuniaev |

The dragon's downloaded archive identifies version 1.1, while the previously
observed listing and Unity UI reported 2.0. Product identity and archive integrity
passed the acquisition audit. The original version and bytes are retained,
without relabeling them as the newer listing version.

The original acquisition workflow checked product IDs, full gzip CRC/length,
safe TAR paths, package copies and extracted payload hashes. Its evidence is
retained under `processing/LARGE_MONSTERS.md`,
`processing/large-monsters-validation.json` and
`asset-review/sources.large-monsters.json` in the source root. This source
handoff rechecks retained packages and selected input hashes; it does not claim
to have repeated extraction or runtime testing.

## Selected models and materials

The Rock Guardian uses the complete mesh and handpainted texture referenced by
`HP_Golem.prefab`, rather than the plain Polyart appearance. Its source tree is
`sources/mini-legion-rock-golem/2bcdcd9755adeb1d/tree/Assets/Mini Legion Rock Golem PBR HP Polyart/`.
The selected files are `Meshes/Golem.fbx`, `Textures/HP_Golem.png` and
`Materials/HP_Golem.mat`. The texture is 2048 by 2048 pixels. The complete
handpainted prefab was previously rendered through isolated Unity export, so
its preview resolves the original mesh, transforms and material assignment.

The Storm Dragon uses `Models/ChaDragon/ChaDragon.fbx`,
`Models/ChaDragon/Textures/Cha_Dragon.png` and
`Models/ChaDragon/Materials/Mat_Cha_Dragon.mat` under
`sources/witch-dragon/56f8af6fd6b89f4c/tree/Assets/Character_Witch_Dragon/`.
The texture is 1024 by 1024 pixels. Only the dragon is selected; the separate
witch does not contribute another creature to this refresh.

The Ember Golem uses `Models/FBX/Golem.FBX`, `Textures/Golem.png` and
`Materials/Golem.mat` under
`sources/golem-monster/789bd21f6ab61a3b/tree/Assets/SiuniaevCharacters/02_Golem/`.
Its source texture is 2048 by 2048 pixels and supplies the armored rock and lava
details. The prior Blender render resolved the supplied Unity material.

## Animation provenance and conversion constraints

The Rock Guardian's seven supplied clips are Unity Humanoid muscle animations:
`Idle`, `Walk`, `Attack01`, `Attack02`, `GetHit`, `Die` and `Victory`.
The earlier review sampled only the Polyart variant's Idle through Unity; the
selected handpainted preview is a rest pose. Direct Blender FBX import does not
transfer these standalone `.anim` clips. If they cannot be transferred safely,
use authored skeletal clips and explicitly identify them as game-authored
motion, not publisher animation. Validate the actual converted character's
deformation and framing before claiming the animation works in the game.

The Storm Dragon has a Generic rig and five separate animation-only FBXs in
`Models/ChaDragon/Motions`: `MotDragon_Wait`, `MotDragon_Attack`,
`MotDragon_Damage`, `MotDragon_Dead` and `MotDragon_Move`. All imported actions
share `Skeleton_Pelvis|Take 001|Layer 001`, so semantic names must come from the
filenames. Bind them to the matching model rig and validate mesh deformation;
an animation stack name alone is insufficient evidence.

The Ember Golem's Generic rig and fourteen source actions reside in the model
FBX. Candidate gameplay mappings are `idle` to Idle, `hit` or `hit2` to Attack,
`damage` to Hit, and `die` to Defeat. In this source, `hit` is an attack action,
not the receive-hit reaction. The manifest retains all supplied clip names;
the exported runtime subset and its verification belong to the conversion
handoff.

The existing Unity `rest.json` files and Mini Legion Idle sample JSON files
contain baked mesh snapshots without skin weights or bind poses. They provide
preview evidence, not reusable animated-rig exports. Existing posters also do
not establish intended in-game scale because each was independently framed.

The separate Giant Monster Model - Golem, product 278960, is not selected here.
Its source has no supplied animation clips, and the retained Blender 5.2 import
attempt failed with `KeyError: B-hips`. It should not silently replace one of
the three selected sources or be counted as an animated game character.

## Integrated runtime assets

The three conversions are integrated into levels 1, 12 and 14 as Stonewarden,
Stormwing and Embermaw. The original fourteen-character catalog remains available;
eleven of those characters still appear in the active campaign. Level numbers,
combat rules and saved progress are unchanged.

`assets/talk_quest/monsters/giants-manifest.json` records the converted GLB hashes,
runtime dimensions, measured animated bounds, embedded textures and exported
clips. The three private GLBs total 4,656,416 bytes. Source albedo and UVs are
retained, with textures capped at 1024 by 1024 pixels. Runtime materials preserve
the painted detail and do not apply the older low-poly material treatment.

- Stonewarden has game-authored skeletal Idle, Attack and Hit clips. The
  exporter corrects the source FBX's inconsistent child-bone bind units, bakes
  a coherent neutral stance and retains the original mesh, UVs and skeleton.
  It does not claim to transfer the publisher's Unity Humanoid muscle clips.
  Defeat uses a short, heavy settling retreat.
- Stormwing uses the publisher's Wait, Attack, Damage and Dead FBX takes,
  bound to the matching dragon skeleton and exported as Idle, Attack, Hit
  and Defeat.
- Embermaw uses the publisher's idle, hit, damage and die takes under the same
  four runtime names. The original hit take is correctly used for attacking.

The reproducible converters are `tools/talk-quest-monsters/export_giants.py`
and `tools/talk-quest-monsters/export_rock_guardian.py`. They verify skinned
vertex movement, not just clip names. `publish_giants.py` verifies hashes,
skins, joint weights, texture coordinates, embedded albedo and required clips
before publishing the private runtime files and supplemental manifest.

The game uses a low camera and larger standing bodies. During attacks it eases
back to keep lifted heads, wings and horns in view, then restores the close
idle composition. A periodic threat gesture supplies visible skeletal action
without dealing damage or changing the word budget. Reduced motion disables
these periodic gestures and camera movement. See the
[runtime QA record](../qa/2026-10-02-talk-quest-giants.md) for verification.
