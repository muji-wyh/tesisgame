# Asset documentation

Source manifests record provenance and may include assets that a later revision
retired. A recorded hash or source path is not, by itself, an active export
requirement. The current exporters, resource loaders, and asset tests define
what ships. Private source packs remain subject to their own licenses.

## Current workflows and retained provenance

| Reference | Purpose |
| --- | --- |
| [Vocabulary and generated media](generated-media.md) | Vocabulary schema, recorded pronunciation, wardrobe generation, chest imports, and music sources |
| [Chest feel](chest-feel.md) | Current chest art, procedural sound bank, motion, and previews |
| [Reference Voice Pop audio](voice-pop-reference-audio.md) | Preferred hit bank, separate launch cue, import checks, and recording limitations |
| [Fruit-slice audio](voice-pop-random-slices.md) | Second-choice hit bank and unchanged source hashes |
| [Single-slice audio](voice-pop-sfx.md) | Earlier hit fallback and source-pack licensing |
| [Pip sounds](pip-sounds.md) | Current calls and source CC0 attribution |
| [Pip dance](pip-dance.md) | Atlas geometry and original-art derivation |
| [Jungle and Candy audio](jungle-candy-audio.md) | Active music/greetings plus provenance for retired opening clips |
| [Unity artwork](unity-art.md) | Optional local image import, licenses, and tracked fallbacks |
| [Talk Quest monsters](talk-quest-monsters.md) | Fourteen licensed rigged characters, source colors and clips, conversion workflow, and provenance |
| [Talk Quest scenes](../../assets/talk_quest/scenes/README.md) | Fourteen original procedural environments and their [art manifest](../../assets/talk_quest/scenes/manifest.json) |
| [Talk Quest treasures](../../assets/talk_quest/chests/README.md) | Twenty original container designs, opening mechanisms, and their [art manifest](../../assets/talk_quest/chests/manifest.json) |

Voice Pop uses the reference hit bank when complete and playable, then the
eight fruit slices, then the single imported slice, then `select.wav`. Launch
audio has a separate tracked fallback. All selected audio is bundled at startup.

Talk Quest's acquired monster models retain the Standard Unity Asset Store EULA.
Their GLBs and source-preview PNGs are ignored local build inputs and ship only
inside the compiled game pack. A fresh checkout needs the licensed assets
restored using the monster guide before Godot import or export.
Their [runtime manifest](../../assets/talk_quest/monsters/manifest.json) records
source and output hashes; the [conversion provenance](talk-quest-monsters.json)
records evaluated source clips, materials, and thumbnail crops. The scene and
treasure manifests identify original artwork authored for this repository.
Friendly hit, retreat, and repair reactions are authored gameplay animation;
the monster guide distinguishes these from the exported source clips.

## Retired assets

[Voice Pop report recordings](pop-voice.md) preserves the original provider,
scripts, formats, and hashes for the removed narration subsystem. It is a
historical record, not an active generation or packaging guide.
