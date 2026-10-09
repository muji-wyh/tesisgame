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
New arrivals accelerate from rest at 12.5 board rows per second squared,
beginning one cell above the clipped well. Contact takes
`0.40 * sqrt(travel_rows)` seconds: 0.40 seconds for one row and 0.98 seconds
for the full six-row distance, about 44% shorter than the previous descent.
The quadratic path keeps acceleration constant, including when a cleared
support extends the fall. Local gravity after a clear remains brisk at
`0.16 * sqrt(max(1, travel_rows))` seconds. Both clocks then allow 55 ms
for planted compression, 105 ms for a restrained rebound and 110 ms to settle.
Longer falls stretch the gel slightly more in the air and compress it more
firmly on contact (up to 24% of its height). The foot stays planted throughout
the single rebound, with no repeated bouncing. The landing cue and projection
retirement share the actual contact boundary. The four-tile supply interval
and eight-second rescue countdown are unchanged.
Only the painted body deforms; the learning picture, label and hit bounds retain
their layout. Input becomes available after the same clock completes.

Supply dispatches four tiles together. Six settled tiles provide the initial
matching layout, followed by the first four arrivals. Four committed upcoming
tiles appear outside the well: a compact two-by-two group on wide screens and
a horizontal strip above it on phones. There is no visible heading or countdown
bar. Their picture/word kind, artwork and chest markers come from the actual
queue. A batch first uses each available column once, then stacks additional
arrivals above one another if fewer columns have space. A nearly full board
accepts only the remaining capacity and preserves the unused preview entries.
The bounded supply bags preserve a possible match on every full board.

Upcoming bodies wobble on the actual supply clock, with frequency rising from
1 to 4.5 Hz and lateral travel from 0.6% to 5.2% of tile width. A curved buildup
reserves the strongest motion for the end of the interval; slot phase offsets
keep the four acquired gel illustrations from moving as one rigid object.
Only their surfaces squash, preserving the learning labels and pictures. Pause
and fusion freeze this same pose. New supply resets the buildup; a full board
and reduced motion display neutral previews. No new visual or audio asset is
introduced for anticipation.

Each landing projection reuses the same acquired gel silhouette at its actual
destination, without word, picture or chest content. It remains stationary while
its incoming tile descends, then disappears at contact. The original painted
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

### Contact, union and elastic release

Contact now gives reciprocal skin pressure and separates the two learning faces
slightly so an overlapping dragged body does not hide its partner. A mint contour
and `Match!` label identify an opposite-kind pair with the same word ID; a coral
contour, `Try another` label and opposed recoil identify an incompatible pair.
These previews do not submit learning attempts. Only a committed wrong drop
resets learning, and only a completed fusion grants success and treasure.

The continuous fusion skin samples four derivative material maps documented in
[the material manifest](jelly-material.json). RGB preserves the acquired painted
surface, including its existing highlights; alpha stores signed distance to that
exact source silhouette. Smooth distance-field union gives the contact neck a
continuous contour. Moving meniscus light, lower-edge attenuation and a restrained
highlight add thickness without warping the separate picture or word. These are
runtime material effects, not additional sourced animation clips.

The 1.05-second committed timeline remains unchanged: two contact lobes unite by
0.40 seconds, briefly hold the combined picture and word, compress from 0.57 to
0.70 seconds, then spring upward and retract. The existing pop cue at 0.70 seconds
starts that release. Five small pieces reuse the acquired gel illustration; a
brief supporting bloom reuses `assets/chests/particles/portal_glow.png`, from
Bobardo's already acquired Modern 2D Animated Chests Pack_FREE Demo 1.0.2 under
the recorded [Unity Asset Store EULA](../voice-pop-treasure.md). No new sound,
particle artwork or source license is introduced. Reward credit stays at 1.05
seconds and still follows the model, independent of the visual fragments.

Every effect uses the paused gameplay clock, with no shader `TIME` or independent
particle timer. Retarget, canceled input, menu, hidden page and a new round clear
contact/rejection feedback. Reduced motion keeps static correctness cues and the
combined acquired artwork, omitting pressure, union motion, fragments and bloom.
Reproduce and verify the material maps with `tools/prepare-jelly-material.py`
and its `--check` option. Their lossless imports disable alpha-border repair and
premultiplication because alpha is distance data, not display transparency.

The same seeded interaction was rendered before and after at 390 x 844, with
additional checks at 1366 x 768 and 844 x 390. Frame inspection covers mutual
contact, rejection, the connected surface, readable union and release fragments;
a normal-speed silent comparison remains in the ignored local review output.
Native regressions cover different approach directions, preview purity, wrong
attempts, pause/cancel/new-round cleanup and reduced motion. Chromium and iPhone
WebKit runs cover real input, completed fusion, learning credit, chest opening,
portrait and short landscape. These are local renders and simulated browser
devices, not physical phone or subjective audio approval.

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

Batch supply checks compare each dispatched group with its committed previews,
including a partially filled final group. Each tile descends over multiple frames
and lands on its own stationary projection. Native model, view and flow checks
cover frozen anticipation and descent during fusion, support changes and the
complete full-board rescue window.
Desktop and phone captures cover the external queue and fixed-ratio well. After
live resize, Windows WebKit retains its previously documented
[page-compositor limitation](../qa/2026-09-11-steady-gameplay.md): composed page
captures can be blank while the raw canvas renders correctly. Both captures are
retained; the raw canvas and touch/keyboard interactions pass at 390 x 844 and
844 x 390. This does not establish physical iPhone rotation behavior.
