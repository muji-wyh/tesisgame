# Vocabulary, generation, and imported media

Maintained asset workflows and source requirements. Paths in commands are
relative to the repository root. See the [asset index](README.md) for individual
source manifests, licenses, and retired provenance.

The visible game name is **Pip and Words**. The internal Godot project identity,
`wordBuddiesHost` API and `wordBuddies.*` storage keys remain unchanged so the
rename preserves existing native and browser saves.

`words.json` is the only vocabulary list. Keep at least five entries:

| Field | Purpose |
|---|---|
| `id` | Unique stable lowercase identifier. |
| `text` | Unique lowercase English word, 2-10 letters. |
| `image` | Unique local picture under `assets/images/words/`. |
| `audio` | Local pronunciation under `assets/audio/voice/`. |
| `level` | `basic`, `growing`, or `advanced`; explicitly authored for every catalogue entry. Older four-field callers default to `basic`; invalid supplied levels are rejected. |

The 350 word pictures live together in `assets\images\words`. Word/reward/bear SVGs, English prompt scripts and synthesized SFX were generated for this project. Prerecorded speech uses **Microsoft Jenny Neural (en-US)** with a warm, friendly delivery and a slightly slower pace. Azure Speech is used only to generate these source recordings; playback and ordinary builds need no speech credentials. Optional microphone recognition is a separate browser-provided service. All 350 word recordings, background music, active prompts and sound effects are included in the startup PCK.

Pip's original pose, idle-action and dance-part sheets are maintained under
`assets\images\mascots`. The regular sheet's four frames are idle, speaking,
blinking and waving. Editable hat and clothing layers for all eight worlds live
in `assets\images\mascots\outfits\wardrobe.svg`. Regenerate the 24 complete
costume sheets with `node tools\generate-pip-outfits.cjs`, or use `--check` to
check that committed sheets match their sources. Native `duck_mascot.gd` loads
the selected costume's pose, idle and dance sheets; the Web build embeds the
themed regular poses and dance parts for the loading and voice companions.

The collection keeps words to 2-10 lowercase letters across twelve picture-word topics:

| Topic | Words |
|---|---:|
| Animals | 57 |
| Food and drinks | 55 |
| Body parts | 17 |
| Clothes and accessories | 31 |
| Nature | 35 |
| Vehicles | 20 |
| Toys and books | 21 |
| Home and everyday objects | 42 |
| Ocean | 18 |
| Space | 19 |
| Garden | 16 |
| Music | 19 |

Original word-art definitions are maintained in `tools\generate-images.cjs` and the small
topic modules under `tools\word-art`. The generated SVGs use simple shapes without fonts,
external images or text labels.

```powershell
node tools\generate-images.cjs
node tools\generate-world-bgm.cjs --missing
node tools\generate-sfx.cjs
```

Edit `voice-prompts.json` to change the spoken prompts. Active prompt IDs must have valid Godot imports and remain included in the Web preset; the build rejects required audio missing from the PCK. When adding a word, add its image-generation definition, level-tagged JSON entry, topic membership in `game_data.gd`, and pronunciation recording. Keep at least five non-confusable eligible words per topic at every level. Run `npm run test:ages` and `npm run build:web` afterward: the vocabulary and all active audio are packaged into Godot's PCK. There is no second runtime word-record list.

The compatible version-one playroom save has an optional `[learning] age_band`
key (`all`, `4-6`, `7-9`, or `10-plus`). Missing keys retain all words; invalid
IDs fail visibly rather than overwriting choices. Existing rewards, journey
history, and legacy sticker collections are preserved, including all 350 words.

### Regenerate natural speech

Voice regeneration and its conversion tests additionally require **FFmpeg** on PATH.
`tools\generate-voices.cjs` uses Jenny's `friendly` style at degree `1.15`, with an 8% slower
speaking rate. A short leading pause keeps card pronunciation responsive. FFmpeg removes
excess final silence while retaining a gentle 160 ms tail, quiet word endings, and pauses
within sentences. It converts the service's 24 kHz output to the existing **22.05 kHz,
PCM16 mono** asset format, preserving the mobile audio import settings.

The personal Azure Speech resource is `tesisgame-speech`, **F0**, in `rg-footises`, East Asia.
The generator spaces requests for that tier, checks that the selected neural style is
available, and keeps existing recordings until the complete batch has been generated and
validated. It fails explicitly rather than silently reverting to a desktop voice.

```powershell
$env:SPEECH_REGION = "eastasia"
$env:SPEECH_KEY = az cognitiveservices account keys list `
    --subscription "Visual Studio Enterprise Subscription" `
    --name tesisgame-speech --resource-group rg-footises `
    --query key1 --output tsv
if ($LASTEXITCODE -ne 0 -or !$env:SPEECH_KEY) { throw "Speech credentials unavailable." }
try {
    node tools\generate-voices.cjs
    if ($LASTEXITCODE -ne 0) { throw "Voice generation failed." }
} finally {
    Remove-Item Env:\SPEECH_KEY
    Remove-Item Env:\SPEECH_REGION
}
```

The existing `tools\generate-voices.ps1` command forwards to the same generator.
Keep keys in the process environment, never in source files or the Web export.
Use `node tools\generate-voices.cjs --missing` to add only absent recordings.
The game prompt catalog contains ten messages: wrong-answer and loss feedback,
plus one greeting for each world. Together with the 350 word recordings, the
generator maintains 360 active files under `assets\audio\voice`. Retired
arrival/opening recordings have been removed; historical provenance remains in
the asset documentation. The retired Voice Pop report recordings and their
generator are no longer shipped; [their provenance](pop-voice.md) remains historical.
Source details, hashes and generation checks are in
[Jungle and Candy audio](jungle-candy-audio.md).

## Chest artwork

Selected artwork is imported from the user-provided **Modern 2D Animated Chests Pack_FREE Demo 1.0.2**. Its three source designs support eight distinct motion and sound treatments:

| Season | Source chest | Treatment |
|---|---|---|
| Spring | Royal | Light wood, unfolding lid, petals and flower bells. |
| Summer | Energy | Heating core, pressure release and a fast lid spring. |
| Autumn | Royal | Heavy wood, metal latch, slower hinge and a small landing recoil. |
| Winter | Crystal | Staggered facets, a central unlock and short ice resonance. |
| Ocean | Crystal | Inward pressure, buoyant release, bubbles and soft water. |
| Space | Energy | Magnetic steps, a floating cover and servo/airlock sounds. |
| Jungle | Royal | Vine tension, a pulled lid, delayed leaves and woody recoil. |
| Candy | Crystal | Elastic compression, a two-beat opening, pops and sugar rattles. |

`scripts/chest_feel.gd` defines shared cue times and per-world motion profiles.
`assets/chests/rigs.json` describes derived Royal/Energy layers; the original
source manifest retains the 14 images used by the current chest. The derived art reuses the original
pixels and textures rather than replacing the silhouette with a new illustration.

The importer copies 14 PNGs byte-for-byte, records SHA256 and source paths, and converts the Crystal prefab's rest transforms, pivots, flips and ordering into `assets\chests\manifest.json`. The retired collectible celebration and its five unused particle textures are no longer included. Unity scripts, materials, prefabs and animation clips are **not** executed or shipped; motion is recreated natively in Godot.

```powershell
node tools\import-chests.cjs "D:\uwork\AssetsSource\Modern 2D Animated Chests Pack_FREE Demo"
```

The supplied source directory is read-only to this workflow. `assets\chests\SOURCE.txt` records provenance. The free demo has three designs, not four independently authored seasonal chest models. Its other `Demo\Sprites` images are locked, watermarked full-version previews, not additional animated chest assets. They are not imported or stripped of their overlays.

## Background music and third-party assets

Voice Pop prefers the three imported reference hit clips and a separate launch
cue. When that private bank is absent, it falls back to the eight fruit-slice
clips, then the earlier `Cut2.wav` override, then the tracked selection sound.
The launch cue has its own tracked fallback. All selected sounds ship inside
the startup pack. See [reference audio](voice-pop-reference-audio.md),
[fruit-slice provenance](voice-pop-random-slices.md), and
[single-slice provenance](voice-pop-sfx.md) for source requirements.

Four tracks were copied from the user-provided **Casual Game Music Pack 1.4**:

| Season | Source track | Local file |
|---|---|---|
| Spring | Flower-Menu-Loop | `assets\audio\bgm\spring.wav` |
| Summer | Ukulele-Menu-v1-Loop | `assets\audio\bgm\summer.wav` |
| Autumn | Banjo-Menu-Loop | `assets\audio\bgm\autumn.wav` |
| Winter | Space-Menu-Loop | `assets\audio\bgm\winter.wav` |

Ocean, Space, Jungle and Candy use original scores from
`tools\generate-world-bgm.cjs`, bringing the total to eight tracks. Jungle uses
rounded wooden-key tones and a quiet low pulse; Candy uses soft toy-piano
overtones. Their source music is distinct from the licensed four-season pack.
See [Jungle and Candy audio](jungle-candy-audio.md) for the new music,
chest effects and Jenny Neural prompts.

The stereo 44.1 kHz source WAVs are retained. Godot packages compressed BGM
resources; each track's `.wav.import` records its `force/mono` and `force/max_rate`
settings. Mono 22.05 kHz imports reduce the mobile download size without changing
the source recording. Rebuild after changing these settings.

The chest artwork and music retain their providers' terms; this repository's code license does not grant additional rights to those assets. Confirm distribution permissions before publishing them. The original source packs are not modified.
