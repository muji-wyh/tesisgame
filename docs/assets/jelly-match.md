# Jelly Match artwork and sound

Jelly Match uses acquired, face-free jelly artwork beneath the existing word
pictures and labels. A shared silhouette, consistent upper-left highlights and
muted color variants give the board a soft material without competing with the
learning content. The appearance comes from a production illustration; animation
deforms that illustration rather than replacing it with flat geometry.

## Sources and acquired material

| Material | Creator and original source | License and status | Available animation |
| --- | --- | --- | --- |
| Gel tile surface | Zuhria Alfitra, also known as pzUH, [Jelly Squash Free Sprites](https://www.gameart2d.com/jelly-squash-free-sprites.html), GameArt2D | CC0 1.0 under the creator's [Free Assets License](https://www.gameart2d.com/license.html). Downloaded from the original site on October 9, 2026; all six blank bodies inspected, then the smooth third body adapted and integrated. | The source supplies static bodies, separate faces and vector originals. It does not include baked animation clips. Squash, merge, settling and clear motion are authored by the game. |
| Merge, clear and countdown warning cues | Kenney, [Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | CC0 1.0. Original archive downloaded; three selected OGG recordings decoded, adapted and integrated as WAVs. The original pack license is retained. | One-shot recordings; no loops. |
| Word artwork and pronunciation | Existing Grow with Pip vocabulary | Reused unchanged, with existing [vocabulary](growth-vocabulary.md), [Mulberry](mulberry-vocabulary.md) and [Ava](ava-voice.md) provenance. | Existing pronunciation playback; artwork is static. |
| Earned chest cue | Existing [chest reference audio](chest-reference-audio.md) | Reuse `assets/imported-audio/chest-reference/reward.wav` without a duplicate. Its existing user-supplied source and embedded-game restrictions remain in force; it is not relabeled CC0. | Existing one-shot reward cue. |
| Chest artwork | Existing current theme chest manifest and renderer | Reused under the recorded [chest asset rights](chest-feel.md). Royal and Energy have closed PNG artwork; the five newer modeled skins require the actual current renderer or a cached still of that renderer. | Use a closed pose for gameplay badges. Archived renders of replaced chest designs must not substitute for the current theme. |

The creator identifies himself on [GameArt2D's about page](https://www.gameart2d.com/about.html).
The machine-readable [manifest](jelly-match.json) records original archive and
selected-file hashes, output hashes, exact adaptations and audio measurements.
Source downloads, unselected alternatives and inspection contact sheets stay in
ignored `build/jelly-match-sources/`. They are acquired source material, not shipped
game assets or evidence of a completed runtime animation review.

## Tile contract

The four production textures are:

- `assets/images/jelly-match/gel-coral.png`
- `assets/images/jelly-match/gel-mint.png`
- `assets/images/jelly-match/gel-sky.png`
- `assets/images/jelly-match/gel-lilac.png`

Each is a 320 × 320 RGBA image. The original 297 × 251 illustration occupies
`x=11, y=34, width=297, height=251`; surrounding pixels are transparent. The source
aspect ratio and every alpha edge, highlight and shaded contour are retained.
The adaptation changes hue and mixes 46% white into RGB to support dark word
labels and colorful vocabulary pictures. It does not redraw the source silhouette
or add a face. The source's other bodies have protruding ears or bubble clusters;
those are intentionally not included in the gameplay set.

Content should stay near the center, approximately `x=80..240, y=110..235` in
texture coordinates. Keep label layout and hit bounds stable while deforming the
gel. Reserve transparent margins for motion; a shader or mesh may use the texture's
own alpha silhouette for a smooth merge. Reduced motion can retain the same
acquired surface while omitting elastic deformation.

The adapted surfaces were inspected at full size and in an 86 px tile sample
with 14 px dark labels and existing word pictures. Source and adapted contact
sheets are `jelly-source-contact.png` and `integrated-gel-contact.png` under the
ignored source directory. These are asset composition checks, not screenshots of
the finished game's responsive layout.

## Cue contract and mix

| Event | Runtime path | Original source | Duration | Measured peak |
| --- | --- | --- | ---: | ---: |
| Two gel bodies commit to a merge | `assets/audio/jelly-match/merge.wav` | `Audio/drop_002.ogg` | 188 ms | −10.05 dBFS |
| Completed item clears with elastic release | `assets/audio/jelly-match/clear.wav` | `Audio/pluck_002.ogg` | 162 ms | −6.00 dBFS |
| Each full-board countdown beat | `assets/audio/jelly-match/danger.wav` | `Audio/question_001.ogg` | 491 ms | −12.00 dBFS |

The names describe intended event use. The drop and pluck sources were selected
for contrasting contact and release envelopes; the attention source is a question
cue rather than an error buzzer. Actual wetness, elasticity and comfort need
listening approval in the game mix; file names and waveform checks alone do not
establish these qualities.

Conversion uses FFmpeg floating-point decode, stereo-to-mono mix and 44.1 kHz
PCM16 output. Original duration and pitch are retained. Peak headroom is applied
before a 44-frame attack fade and 441-frame tail fade. This also avoids clipping
from the original Vorbis decode's intersample overshoot. Every delivered file
starts and ends at zero and has no full-scale samples; audible onset is within
7 ms of the cue start. The manifest distinguishes pre-fade gain from final
measured peaks.

Drive each cue from the same committed event as its visible contact or release.
Do not play merge or clear for every animation frame or every affected card.
The full-board clock triggers one danger recording at each remaining second,
including entry. The border uses that same clock: bright for 180 ms, fading to
its normal outline by 550 ms, then resting until the next second. Reduced motion
uses a steady warning outline. A matching contact immediately stops warning
audio and removes the border flash; pause, exit and expiry stop the warning too.
Tap pronunciation remains the primary learning sound. While a word plays,
duck Jelly Match effects by about 12 dB and use a small bounded voice pool.
Mute, pause, backgrounding and leaving the mode must stop pending and playing
Jelly cues. Reuse the existing chest reward gain and lifecycle for earned chests.

## Reproduction and validation

The two verified archives are downloaded from the exact URLs in the manifest
to `build/jelly-match-sources/jelly.zip` and
`build/jelly-match-sources/kenney-interface-sounds.zip`. With Python, Pillow 12.2.0
and FFmpeg available:

```powershell
python tools/import-jelly-match-assets.py
python tools/import-jelly-match-assets.py --check
```

The importer rejects different source archive hashes, extracts only into its
source directory, and reproduces the four PNGs, three WAVs and manifest. The check
mode only reads files and verifies hashes, texture format, PCM format, zero edges
and headroom. Normal game builds use the acquired files and need no asset service
or network synthesis.

FFprobe/FFmpeg decoding and sample checks passed. This task's tool channel could
not present audio to the reviewing model, so no subjective listening approval is
claimed. A labeled candidate timeline and `kenney-audition.wav` are retained in
the ignored source directory for human review. Native/browser timing, overlapping
pronunciation, repeated-play fatigue and device speakers need runtime review.
