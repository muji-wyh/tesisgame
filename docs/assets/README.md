# Asset documentation

Source manifests record provenance and may include assets that a later revision
retired. A recorded hash or source path is not, by itself, an active export
requirement. The current exporters, resource loaders, and asset tests define
what ships. Private source packs remain subject to their own licenses.

## Current workflows

| Reference | Purpose |
| --- | --- |
| [Interface typography and library artwork](../../assets/fonts/SOURCE.md) | Acquired Nunito, font weights, and reused Twemoji illustrations |
| [Asset art direction](art-direction.md) | Required sourced artwork, inspection, license records, and honest integration status |
| [Vocabulary and generated media](generated-media.md) | Vocabulary schema, recorded pronunciation, wardrobe generation, chest imports, and music sources |
| [Ava speech](ava-voice.md) | Approved voice profile, all 358 spoken recordings, generation, and source hashes |
| [Casual background music](casual-bgm.md) | Eight active CC0 tracks, theme assignments, source licenses, level processing, and restoration |
| [Chest feel](chest-feel.md) | Current chest art, procedural sound bank, motion, and previews |
| [Reference pair feedback](pair-feedback-audio.md) | Match and Memory right/wrong excerpts, source provenance, extraction and required build assets |
| [Reference Voice Pop audio](voice-pop-reference-audio.md) | Preferred hit bank, separate launch cue, import checks, and recording limitations |
| [Fruit-slice audio](voice-pop-random-slices.md) | Second-choice hit bank and unchanged source hashes |
| [Single-slice audio](voice-pop-sfx.md) | Earlier hit fallback and source-pack licensing |
| [Pip sounds](pip-sounds.md) | Current calls and source CC0 attribution |
| [Pip dance](pip-dance.md) | Atlas geometry and original-art derivation |
| [Jungle and Candy audio](jungle-candy-audio.md) | Retained arrival effects, superseded music and greetings, and retired opening-clip provenance |
| [Unity artwork](unity-art.md) | Optional local image import, licenses, and tracked fallbacks |

Voice Pop uses the reference hit bank when complete and playable, then the
eight fruit slices, then the single imported slice, then `select.wav`. Launch
audio has a separate tracked fallback. All selected audio is bundled at startup.

## Retired assets

[Voice Pop report recordings](pop-voice.md) preserves the original provider,
scripts, formats, and hashes for the removed narration subsystem. It is a
historical record, not an active generation or packaging guide.

### Talk Quest archive

Talk Quest was retired on 2026-10-06. Its runtime artwork, code, and preparation
tools no longer ship. The following documents and retained manifests preserve
source URLs, authors, licenses, acquisition status, hashes, and animation notes.
They are historical records, not import, export, or restoration prerequisites.
Private acquired source files keep their original license restrictions.

| Archived reference | Historical scope |
| --- | --- |
| [Guardian replacement review](talk-quest-monster-refresh.md) | Fourteen proposed friendly sources, acquisition status, and animation gaps; not shipped assets |
| [Talk Quest chapter atlas](../../assets/talk_quest/map/SOURCE.md) | Acquired parchment maps, fourteen landmark illustrations, navigation artwork, and source credits |
| [Talk Quest monsters](talk-quest-monsters.md) | Fourteen licensed rigged characters, source colors and clips, conversion workflow, and provenance |
| [Talk Quest scenes](../../assets/talk_quest/scenes/README.md) | Fourteen original procedural environments and their [art manifest](../../assets/talk_quest/scenes/manifest.json) |
| [Talk Quest treasures](../../assets/talk_quest/chests/README.md) | Twenty original container designs, opening mechanisms, and their [art manifest](../../assets/talk_quest/chests/manifest.json) |
| [Talk Quest treasure room](../../assets/talk_quest/treasure/SOURCE.md) | Acquired interior artwork, textured celebration lighting, and interface framing |
| [Talk Quest dimensional islands](../../assets/talk_quest/map-dimensional/SOURCE.md) | Kenney model renders, acquired sky/cloud artwork, and prepared chapter palettes |
| [Talk Quest giants](talk-quest-giants.md) | Three acquired character designs and animation limitations |
| [Talk Quest combat audio](talk-quest-audio.md) | Original effects and former generation/packaging records |

The [monster conversion manifest](talk-quest-monsters.json) and
[giant source manifest](talk-quest-giants-sources.json) retain their source hashes.
Former runtime manifests under `assets/talk_quest/` are excluded from Godot
import and Web export. Source previews, downloaded models, and integrated
characters remain distinct statuses in these records.
