# Jelly Match artwork and sound

Jelly Match uses acquired, face-free jelly artwork beneath the existing word
pictures and labels. A shared silhouette, consistent upper-left highlights and
muted color variants give the board a soft material without competing with the
learning content. The appearance comes from a production illustration; animation
deforms that illustration rather than replacing it with flat geometry.
The playfield now sits in a sourced [woodland environment](jelly-environment.md).

## Sources and acquired material

| Material | Creator and original source | License and status | Available animation |
| --- | --- | --- | --- |
| Gel tile surface | Zuhria Alfitra, also known as pzUH, [Jelly Squash Free Sprites](https://www.gameart2d.com/jelly-squash-free-sprites.html), GameArt2D | CC0 1.0 under the creator's [Free Assets License](https://www.gameart2d.com/license.html). Downloaded from the original site on October 9, 2026; all six blank bodies inspected, then the smooth third body adapted and integrated. | The source supplies static bodies, separate faces and vector originals. It does not include baked animation clips. Squash, merge, settling and clear motion are authored by the game. |
| Contact shadow | Same acquired Jelly Squash pack, `png/separate/Shadow.png` | Same CC0 1.0 license. Inspected and copied byte-for-byte to `assets/images/jelly-match/contact-shadow.png`; source and output hashes are identical. | Static 334 × 150 RGBA texture, maximum alpha 26/255. Runtime placement, tint and opacity establish contact independently of the moving gel. The pack's `WithShadow` bodies include faces and are not used. |
| Merge, clear and countdown warning cues | Kenney, [Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | CC0 1.0. Original archive downloaded; three selected OGG recordings decoded, adapted and integrated as WAVs. The original pack license is retained. | One-shot recordings; no loops. |
| Word artwork and pronunciation | Existing Grow with Pip vocabulary | Reused unchanged, with existing [vocabulary](growth-vocabulary.md), [Mulberry](mulberry-vocabulary.md) and [Ava](ava-voice.md) provenance. | Existing pronunciation playback; artwork is static. |
| Earned chest cue | Existing [chest reference audio](chest-reference-audio.md) | Reuse `assets/imported-audio/chest-reference/reward.wav` without a duplicate. Its existing user-supplied source and embedded-game restrictions remain in force; it is not relabeled CC0. | Existing one-shot reward cue. |
| Landing contact cue | Existing [chest reference audio](chest-reference-audio.md) | Reuse `assets/imported-audio/chest-reference/step-detail.wav` without a duplicate; the same user-supplied source and embedded-game restrictions apply. | Existing short one-shot, triggered once per landing group at low gain with speech ducking and the established interruption lifecycle. No new recording is acquired. |
| Select and empty-drop cues | Existing [interface click](ui-click-audio.md) and [chest reference audio](chest-reference-audio.md) | Reuse `assets/imported-audio/ui-click/select.wav` and `assets/imported-audio/chest-reference/step.wav` without duplicate files, under their existing embedded-game source restrictions. | One-shot selection and intentional empty-drop feedback. Movement, hover, menu interruption and pointer cancellation do not replay them. |
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
The adaptation changes hue while retaining 88% of the source HSV saturation
(78% for mint to restrain its bright green contour). It mixes 40% white into the
central reading area and 24% into the outer contour and lower foot. This retains
the source's material contrast without making the word area dark. It does not
redraw the source silhouette or add a face. The source's other bodies have
protruding ears or bubble clusters; those are intentionally not included in the
gameplay set.

Processing uses normalized coordinates within the unpadded source. The horizontal
center weight is `smoothstep(0.08, 0.28, x) * smoothstep(0.08, 0.28, 1 - x)`;
the foot weight is `1 - smoothstep(0.80, 0.99, y)`. The product interpolates the
white mix from 0.24 to 0.40. Each smoothstep uses the cubic `t * t * (3 - 2 * t)`
after clamping `t` to 0–1. Hue offsets are unchanged and every source alpha value
is retained. The manifest records these constants for each color.

Content should stay near the center, approximately `x=80..240, y=110..235` in
texture coordinates. Keep label layout and hit bounds stable while deforming the
gel. Reserve transparent margins for motion; a shader or mesh may use the texture's
own alpha silhouette for a smooth merge. Reduced motion can retain the same
acquired surface while omitting elastic deformation.

The settled foot lies at `y=285/320` of the padded texture. Squash and recovery
should pivot there so the underside keeps contact. The separately acquired shadow
is not baked into the gel; its support position can remain fixed while the body
falls, compresses or lifts. This avoids moving a ground shadow through the air.
New arrivals use a visible descent lasting `0.72 * sqrt(travel_rows)` seconds,
beginning one cell above the clipped well. Local gravity after a clear remains
brisk at `0.16 * sqrt(max(1, travel_rows))` seconds. Both clocks then allow 65 ms
for compression, 120 ms for rebound and 95 ms to settle.
Only the painted body deforms; the learning picture, label and hit bounds retain
their layout. Input becomes available after the same clock completes.

Supply dispatches one tile at a time. Six settled tiles provide the initial
matching layout, followed by one incoming tile. Three committed upcoming tiles
are shown outside the well: vertically at the right on wide screens and in a
horizontal strip above it on phones. Their picture/word kind, artwork and chest
markers come from the actual queue. Bounded bags interleave complementary halves
so they do not arrive together; every full board retains a possible match.

The landing projection reuses the same acquired gel silhouette at the actual
destination, without word, picture or chest content. It remains stationary while
the incoming tile descends, then disappears at contact. The original painted
contact shadow still accompanies the landing. No additional placeholder artwork
is introduced. Fusion freezes descent and the supply clock; a shifted support
retargets the destination while preserving the incoming tile's visible height.
Reduced motion places the incoming tile at its destination without a projection
or descent, keeping the same readiness gate. The full-board warning starts only
after the last tile settles, leaving the complete eight seconds to make space.

The adapted surfaces were inspected at full size and in an 86 px tile sample
with 14 px dark labels and existing word pictures. Source and adapted contact
sheets are `jelly-source-contact.png` and `integrated-gel-contact.png` under the
ignored source directory. These are asset composition checks, not screenshots of
the finished game's responsive layout.

The refined colors were compared against the prior production PNGs at 320 px and
86 px with dark learning words. The ignored `gel-refinement-320.png` and
`gel-refinement-86.png` sheets document that asset comparison. Native captures at
1366 x 768, 390 x 844 and 844 x 390 were inspected for label fit, contact shadows,
dragging and reduced motion. Before/after descent frames use the same seeded
board and 60 Hz timeline; these rendered checks do not establish subjective
sound quality or performance on a physical phone.

## Cue contract and mix

Each fully cleared pair earns one point. The round summary displays the score
and exact chest count from entry, including zero-loot rounds. Rounds with treasure
keep Pip's existing reward presentation before revealing the opening action;
the summary uses `Round results` rather than a level-completion message.

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
duck Jelly Match effects by 6 dB and use a small bounded voice pool. The original
12 dB duck made the short merge/clear transients too attenuated under frequent
pronunciation. Current gains are 0.64 for pick, 0.38 for release and land, 1.0 for
merge, 0.90 for clear, 0.52 for danger and 0.36 for reward. Pick, release and land
only use idle channels; they cannot cut off a warning, answer or reward.
The quiet landing cue uses the existing `step-detail.wav` source once per contact
group, following the same pronunciation priority; overlapping tiles must not
multiply the transient. Its audible weight and comfort require runtime listening,
and are not established by the reuse record or waveform measurements.
Mute, pause, backgrounding and leaving the mode must stop pending and playing
Jelly cues. Reuse the existing chest reward gain and lifecycle for earned chests.

## Reproduction and validation

The two verified archives are downloaded from the exact URLs in the manifest
to `build/jelly-match-sources/jelly.zip` and
`build/jelly-match-sources/kenney-interface-sounds.zip`. With Python, Pillow 12.2.0
and FFmpeg available:

```powershell
python tools/import-jelly-match-assets.py
python tools/import-jelly-match-assets.py --images-only
python tools/import-jelly-match-assets.py --check
```

The importer rejects different source archive hashes, extracts only into its
source directory, and reproduces four adapted gel PNGs, the unchanged source
shadow PNG, three WAVs and the manifest. `--images-only` retains existing audio
files and their provenance records while regenerating artwork. The check mode
only reads files and verifies hashes, texture format, PCM format, zero edges and
headroom; it also verifies the shadow matches its original source hash. Normal
game builds use the acquired files and need no asset service or network synthesis.

FFprobe/FFmpeg decoding and sample checks passed. This task's tool channel could
not present audio to the reviewing model, so no subjective listening approval is
claimed. A labeled candidate timeline and `kenney-audition.wav` are retained in
the ignored source directory for human review. Native gesture/lifecycle checks
and Chromium WebAudio checks on desktop and simulated Android pass: observed
PCM distinguishes pick, release, land, merge and clear, preserves pronunciation,
and confirms mute and interruption behavior. The Windows iPhone WebKit test
runtime has no available WebAudio, so its audio check is skipped; its gameplay
and layout checks pass. These checks do not establish subjective mix quality,
repeated-play fatigue or sound on physical device speakers.

Single-tile supply is verified through three consecutive real browser arrivals:
each matches the previous preview head, descends over multiple frames and lands
on its stationary projection. Native model, view and flow checks cover frozen
descent during fusion, support changes and the complete full-board rescue window.
Desktop and phone captures cover the external queue and fixed-ratio well. After
live resize, Windows WebKit retains its previously documented
[page-compositor limitation](../qa/2026-09-11-steady-gameplay.md): composed page
captures can be blank while the raw canvas renders correctly. Both captures are
retained; the raw canvas and touch/keyboard interactions pass at 390 x 844 and
844 x 390. This does not establish physical iPhone rotation behavior.
