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
| `text` | Unique lowercase English word, 2-14 letters. |
| `image` | Unique local picture under `assets/images/words/`. |
| `audio` | Local pronunciation under `assets/audio/voice/`. |
| `level` | `basic`, `growing`, or `advanced`; explicitly authored for every catalogue entry. Older four-field callers default to `basic`; invalid supplied levels are rejected. |

The 1,250 word pictures live together in `assets\images\words`: 350 legacy SVGs and
900 sourced Mulberry PNGs. The [source manifest and import guide](mulberry-vocabulary.md)
describe their distinct origins and licenses. Prerecorded speech uses the approved
**Microsoft Ava Neural (en-US)** voice with rate `-15%`, pitch `+8Hz`, and unchanged
volume. Microsoft Edge online TTS generates these source recordings; playback and
ordinary builds need no speech service or credentials. Optional microphone recognition
is a separate browser-provided service. All 1,250 word recordings, background music,
active prompts and sound effects are included in the startup PCK.

The 900 new entries also include `part_of_speech`, `meaning`, `topic`, `art_key`,
and optional `confusable` IDs. These preserve the intended sense, prevent invalid
noun endings for other parts of speech, and keep confusing answers apart.

Pip's original pose, idle-action and dance-part sheets are maintained under
`assets\images\mascots`. The regular sheet's four frames are idle, speaking,
blinking and waving. Editable hat and clothing layers for all eight worlds live
in `assets\images\mascots\outfits\wardrobe.svg`. Regenerate the 24 complete
costume sheets with `node tools\generate-pip-outfits.cjs`, or use `--check` to
check that committed sheets match their sources. Native `duck_mascot.gd` loads
the selected costume's pose, idle and dance sheets; the Web build embeds the
themed regular poses and dance parts for the loading and voice companions.

The 350 legacy entries retain their twelve picture-word topics:

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
python tools\import-casual-bgm.py --check
node tools\generate-sfx.cjs
```

The 900 additions belong to seven new topics: actions and routines, feelings and
people, describe and compare, places and time, nature and science, food and home,
and school and play. Runtime topic membership is derived from each entry's `topic`.

Edit `voice-prompts.json` to change the spoken prompts. Active prompt IDs must have
valid Godot imports and remain included in the Web preset; the build rejects required
audio missing from the PCK. When adding a word, provide its sourced illustration and
provenance, level, topic, intended meaning, part of speech, and pronunciation. Keep at
least five non-confusable eligible words per topic at every level. Run
`npm run test:ages` and `npm run build:web` afterward. There is no second runtime
word-record list. The legacy image generator preserves and validates sourced additions.

The compatible version-one playroom save has an optional `[learning] age_band`
key (`all`, `4-6`, `7-9`, or `10-plus`). Missing keys retain all words; invalid
IDs fail visibly rather than overwriting choices. Existing rewards, journey
history, and legacy sticker collections are preserved, including all 350 earlier words.

### Regenerate natural speech

Voice regeneration requires **Python**, **edge-tts 7.2.8**, and **FFmpeg** on PATH.
`tools\generate-voices.cjs` uses the same Ava profile as the user-approved preview.
FFmpeg decodes the service MP3 into the existing **22.05 kHz, PCM16 mono** asset
format. It does not alter pitch, add effects, or trim the spoken delivery.
The generator validates the complete batch before replacing any existing recording,
and retains a profile/text-keyed cache under `build/voice-cache` for retries.
It fails explicitly rather than substituting a different voice.

```powershell
python -m pip install -r tools/voice-requirements.txt
node tools/generate-voices.cjs
npm run build:web
```

The existing `tools\generate-voices.ps1` command forwards to the same generator.
Set `PYTHON` if a particular Python executable is required. Only generation uses
the online service; the shipped game plays the committed recordings.
Use `node tools\generate-voices.cjs --missing` to add only absent recordings.
The game prompt catalog contains eleven messages: one greeting for each world
and three Phrase Builder cues. Together with the 1,250 word pronunciations and
36 whole-phrase recordings from `phrases.json`, the generator maintains 1,297
active files under `assets\audio\voice`. Retired
arrival/opening recordings and Match wrong-answer/loss prompts have been removed; historical provenance remains in
the asset documentation. The retired Voice Pop report recordings and their
generator are no longer shipped; [their provenance](pop-voice.md) remains historical.
Current source details and hashes are in [Ava speech](ava-voice.md).
[Jungle and Candy audio](jungle-candy-audio.md) preserves the superseded Jenny provenance.

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

All eight active theme tracks now use Juhani Junkala's **JRPG Pack 2 Towns** and
**JRPG Pack 4 Calm**, released under **CC0 1.0**. The town and calm cues provide
distinct full musical loops for each theme, lasting 46 to 112 seconds. The
[casual BGM guide](casual-bgm.md) lists their theme assignments, original license
notices, source downloads, processing, and restoration commands. The active
[source manifest](casual-bgm.json) pins source and output hashes.

The October 2, 2026 refresh replaces the earlier four seasonal recordings from
the user-provided Casual Game Music Pack 1.4 and the four synthesized ocean,
space, jungle, and candy scores. The dated [Jungle and Candy audio](jungle-candy-audio.md)
provenance preserves the original music, retained arrival effects, and superseded
Jenny Neural greetings. `tools\generate-world-bgm.cjs` now preserves existing
tracks by default; `--replace` explicitly regenerates the four historical scores.
Restore current music with `tools\import-casual-bgm.py`.

The stereo 44.1 kHz PCM16 WAVs use consistent gain for approximately -20 LUFS
and three-millisecond edge fades. Godot packages compressed BGM resources;
each track's `.wav.import` retains its mono 22.05 kHz mobile settings. The existing
music gain, spoken-prompt ducking, chest mix, and silence during microphone
recognition remain unchanged. Rebuild after changing recordings or import settings.

Current music retains its CC0 source notices. Chest artwork and superseded
licensed music retain their providers' terms; this repository's code license
does not grant additional rights to those assets. The original source packs
are not modified.
