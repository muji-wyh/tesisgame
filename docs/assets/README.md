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

Voice Pop uses the reference hit bank when complete and playable, then the
eight fruit slices, then the single imported slice, then `select.wav`. Launch
audio has a separate tracked fallback. All selected audio is bundled at startup.

## Retired assets

[Voice Pop report recordings](pop-voice.md) preserves the original provider,
scripts, formats, and hashes for the removed narration subsystem. It is a
historical record, not an active generation or packaging guide.
