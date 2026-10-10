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
| Finish flag icon | Paweł Kuna, [Tabler Icons v3.35.0](https://github.com/tabler/tabler-icons/blob/v3.35.0/icons/outline/flag-check.svg) | MIT. Downloaded, visually inspected and integrated as `assets/images/ui/finish-flag.svg`. [Attribution and adaptation](../../assets/images/ui/ATTRIBUTION.md) and original license retained. | Static vector artwork; button states use the existing native input lifecycle and click cue. |
| Gel tile surface | Zuhria Alfitra, also known as pzUH, [Jelly Squash Free Sprites](https://www.gameart2d.com/jelly-squash-free-sprites.html), GameArt2D | CC0 1.0 under the creator's [Free Assets License](https://www.gameart2d.com/license.html). Downloaded from the original site on October 9, 2026; all six blank bodies inspected, then the smooth third body adapted and integrated. | The source supplies static bodies, separate faces and vector originals. It does not include baked animation clips. Squash, merge, settling and clear motion are authored by the game. |
| Contact shadow | Same acquired Jelly Squash pack, `png/separate/Shadow.png` | Same CC0 1.0 license. Inspected and copied byte-for-byte to `assets/images/jelly-match/contact-shadow.png`; source and output hashes are identical. | Static 334 × 150 RGBA texture, maximum alpha 26/255. Runtime placement, tint and opacity establish contact independently of the moving gel. The pack's `WithShadow` bodies include faces and are not used. |
| Gel contact and fusion recordings | rubberduck, [40 CC0 water / splash / slime SFX](https://opengameart.org/content/40-cc0-water-splash-slime-sfx) | CC0 1.0. Original archive acquired; `slime_09.ogg` and `slime_16.ogg` selected for the landing, merge and clear derivatives. The creator's source page records the license and describes some slime recordings as made from real slime; it does not identify which individual files use that technique. | One-shot recordings; no loops. The delivered cues layer, shape and time the acquired recordings. |
| Elastic release layer | Aeva, [BOING!](https://opengameart.org/content/boing) | CC0 1.0. Original `boing.flac` acquired from the creator's OpenGameArt upload and selected for the clear derivative. The source page records the license. | One authored spring sound made with an Arturia MicroFreak. This is a synthesized source recording, not rubber foley. The delivered layer is pitched and shaped to fit the release. |
| Countdown warning cue | Kenney, [Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds) | CC0 1.0. Original archive downloaded; `Audio/question_001.ogg` decoded, adapted and integrated as `danger.wav`. The original pack license is retained. | One-shot recording; no loop. |
| Word artwork and pronunciation | Existing Grow with Pip vocabulary | Reused unchanged, with existing [vocabulary](growth-vocabulary.md), [Mulberry](mulberry-vocabulary.md) and [Ava](ava-voice.md) provenance. | Existing pronunciation playback; artwork is static. |
| Earned chest cue | Existing [chest reference audio](chest-reference-audio.md) | Reuse `assets/imported-audio/chest-reference/reward.wav` without a duplicate. Its existing user-supplied source and embedded-game restrictions remain in force; it is not relabeled CC0. | Existing one-shot reward cue. |
| Landing contact cue | rubberduck, [40 CC0 water / splash / slime SFX](https://opengameart.org/content/40-cc0-water-splash-slime-sfx), `slime_16.ogg` | CC0 1.0. The already acquired recording is filtered, slowed and damped into `assets/audio/jelly-match/land.wav`; source and derivative hashes and processing are recorded in the manifest. | A 220 ms one-shot with a rounded attack and fading gel contact, triggered once per landing group at low gain with speech ducking and the established interruption lifecycle. |
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
retirement share the actual contact boundary. The eight-second rescue countdown
is independent of this motion.
Only the painted body deforms; the learning picture, label and hit bounds retain
their layout. Input becomes available after the same clock completes.

Supply dispatches four tiles together. Six settled tiles provide the initial
matching layout. The first automatic batch waits for the full ten-second
interval; the upcoming area can still release it immediately on request.
Each cleared pair shortens the interval by 0.05 seconds, down to a six-second
minimum after 80 pairs. This leaves nine seconds at 20 pairs and 7.5 seconds at
50 pairs. New rounds and replays receive the same opening interval. Four committed upcoming
tiles appear outside the well: a compact two-by-two group on wide screens and
a horizontal strip above it on phones. There is no visible heading or countdown
bar. Their picture/word kind, artwork and chest markers come from the actual
queue. A batch first uses each available column once, then stacks additional
arrivals above one another if fewer columns have space. A nearly full board
accepts only the remaining capacity and preserves the unused preview entries.
The bounded supply bags preserve a possible match on every full board.

The entire upcoming area also acts as a manual drop control. A tap or click
releases the displayed batch immediately when the round is active, every board
tile has settled, no pair is fusing and the well has room. It uses the same
four-tile dispatch, column selection, gravity and landing projections as a timed
drop; a nearly full board still accepts only its remaining capacity. The supply
clock resets after an accepted manual drop, so the next timed batch receives a
full interval. Dropping a batch does not score a point, award treasure or record
a learning attempt.

The control has the accessible name and tooltip `Drop the next jellies`, while
the visible layout retains its four previews without a `Next` label or progress
bar. Keyboard and controller users can focus the whole area and activate it.
The individual preview tiles remain decorative and cannot be dragged or matched.
A pointer gesture belongs to the batch displayed when it began; if natural
supply advances before release, the old gesture cannot drop the replacement
batch. Moving more than 12 screen pixels cancels the tap. Pause, leaving the
page and starting a new round discard pending taps, and a board drag blocks
manual supply activation.

An accepted manual drop plays the existing brief pick cue once. The falling
batch then uses the existing soft landing feedback at contact. Manual supply
introduces no new artwork or audio assets, and preserves the current mute,
pronunciation priority and interruption behavior.

Upcoming bodies stay planted while the acquired skin briefly compresses, spreads
at its lower lobe and settles through a damped rebound. Pressure impulses follow
the actual supply clock, rising from 0.65 to 2.8 Hz; strain builds toward 6% near
release. Each squeeze takes 70 ms, followed by one small overshoot and a dying
tail. A delayed crown sway and slight slot offsets keep the four bodies from
moving in rigid unison. The painted foot stays fixed above the source contact
shadow; labels, pictures, chest markers and input rectangles remain stationary.
Pause and fusion freeze the same pose. New supply starts at rest; a full board
and reduced motion display neutral previews. No new visual or audio asset is
introduced for anticipation; the existing CC0 gel skins and contact shadow are
reused.

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

Only releasing a dragged jelly on another settled jelly submits a match attempt.
Taps and keyboard/controller activations pronounce the word without retaining a
selection or judging a pair. Repeated taps never grant learning credit or clear
an existing streak, including taps on incompatible words. The movement threshold
keeps small finger motion from turning an ordinary tap into a match attempt.

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
the recorded [Unity Asset Store EULA](../voice-pop-treasure.md). Particle artwork
and its license remain unchanged. The material sounds below use newly acquired
CC0 recordings. Reward credit stays at 1.05 seconds and still follows the model,
independent of the visual fragments or audio duration.

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

| Event | Runtime path | Original source | Duration | Peak |
| --- | --- | --- | ---: | ---: |
| Falling gel makes contact | `assets/audio/jelly-match/land.wav` | rubberduck `slime_16.ogg` | 220 ms | −16.0 dBFS |
| Two gel bodies commit to a merge | `assets/audio/jelly-match/merge.wav` | rubberduck `slime_09.ogg`, with a quieter `slime_16.ogg` contact layer | 620 ms | −9.0 dBFS |
| Completed item clears with elastic release | `assets/audio/jelly-match/clear.wav` | rubberduck `slime_16.ogg` with Aeva `boing.flac` | 340 ms | −7.5 dBFS |
| Each full-board countdown beat | `assets/audio/jelly-match/danger.wav` | `Audio/question_001.ogg` | 491 ms | −12.00 dBFS |

These are measurements of the final PCM files. The merge and clear RMS levels
are −22.824 and −23.186 dBFS; onset above −40 dBFS is 5.35 and 0.70 ms respectively.
The merge combines a short contact with a longer pressure envelope to support
the visible union. The clear combines a gel-skin release with a compressed,
pitched spring layer to support the upward rebound. These replace the former
Kenney drop and pluck cues. The attention source remains a question cue rather
than an error buzzer. Wetness, elasticity and comfort are intended qualities;
they require listening in the game mix, and cannot be established from file
names, source descriptions or waveform inspection.

The landing derivative uses a single `slime_16.ogg` layer with an 85 Hz high-pass
and 1,100 Hz low-pass filter. Compression uses threshold 0.07, ratio 4, a 2 ms
attack and a 45 ms release. Playback starts 4 ms into the filtered recording at
0.86 speed, with exponential damping `exp(-7t)`, a 16 ms onset fade and an 85 ms
tail fade. Its final peak is −16 dBFS before the separate runtime gain of 0.35.
The resulting PCM RMS is −32.520 dBFS, with onset above −40 dBFS at 12.79 ms.
The softer attack and reduced high-frequency energy replace the former shared
chest step cue. That original recording remains unchanged for chest interaction
and Pip's celebration.

Conversion uses FFmpeg floating-point decode, stereo-to-mono mix and 44.1 kHz
PCM16 output. The new material cues use edited envelopes, layered recordings and
pitch/time adaptation; their original duration and pitch are not retained.
The importer and manifest record the source files and exact processing recipe.
Gain must be applied before PCM conversion: some source Vorbis recordings exceed
0 dBFS when decoded to floating point. Attack and tail fades keep the delivered
file edges at zero, with headroom for the existing game mix. The countdown cue
retains its previous conversion and measured output.

Drive each cue from the same committed event as its visible contact or release.
The merge starts at fusion time 0; the clear starts at the existing 0.70-second
pop node. Both end within the unchanged 1.05-second fusion timeline. Audio does
not move the success-credit boundary or change matching, difficulty or rewards.
Do not play merge or clear for every animation frame or every affected card.
The full-board clock triggers one danger recording at each remaining second,
including entry. The border uses that same clock: bright for 180 ms, fading to
its normal outline by 550 ms, then resting until the next second. Reduced motion
uses a steady warning outline. A matching contact immediately stops warning
audio and removes the border flash; pause, exit and expiry stop the warning too.
Tap pronunciation remains the primary learning sound. While a word plays,
duck Jelly Match effects by 6 dB and use a small bounded voice pool. The original
12 dB duck made the short merge/clear transients too attenuated under frequent
pronunciation. Current gains are 0.64 for pick, 0.38 for release, 0.35 for land,
1.0 for merge, 0.90 for clear, 0.52 for danger and 0.36 for reward. Pick, release
and land only use idle channels; they cannot cut off a warning, answer or reward.
The landing cue uses the dedicated `land.wav` derivative once per contact group,
following the same pronunciation priority; overlapping tiles must not multiply
the transient. Its audible weight and comfort require runtime listening, and
are not established by the processing recipe or waveform measurements.
Mute, pause, backgrounding and leaving the mode must stop pending and playing
Jelly cues. Reuse the existing chest reward gain and lifecycle for earned chests.

## Reproduction and validation

The acquired sources are retained under `build/jelly-match-sources/`:

- `jelly.zip` and `kenney-interface-sounds.zip`, from the original URLs in the manifest.
- `water-splash-slime-sfx.zip`, from [rubberduck's original archive](https://opengameart.org/sites/default/files/water-splash-slime-sfx.zip), SHA-256 `7cd39abb49d4362a37ba18dc0e454c7dc1d08029d4e5b683149046bc237b2eba`.
- `boing.flac`, from [Aeva's original recording](https://opengameart.org/sites/default/files/boing.flac), SHA-256 `9c6af38ca79332ad3fa66ad1229179d2a91655c1157d3620e21ef676f54d9fdd`.

With Python, Pillow 12.2.0 and FFmpeg available:

```powershell
python tools/import-jelly-match-assets.py
python tools/import-jelly-match-assets.py --images-only
python tools/import-jelly-match-assets.py --check
```

The importer verifies the original archive and recording hashes, extracts only
into its source directory, and reproduces four adapted gel PNGs, the unchanged
source shadow PNG, four WAVs and the manifest. Full imports reproduce the new
material cues. `--images-only` retains existing audio files and their complete
provenance, including the rubberduck and Aeva sources, while regenerating artwork.
The check mode only reads files and verifies hashes, texture format, PCM format,
zero edges and headroom; it also verifies the shadow matches its original source
hash. Normal game builds use the acquired files and need no asset service or
network synthesis.

The original rubberduck recordings were decoded and measured for duration,
envelope, spectral energy and headroom. This review tool channel reports that
audio input is unsupported, so no subjective audition or listening approval is
claimed. The earlier `kenney-audition.wav` in the ignored source directory is a
review of the former cues, not evidence for the new mixture.

At the merge and clear integration, those replacement files passed source/hash,
PCM, edge and headroom checks. An image-only import preserved their complete
manifest. The 74 native audio checks and desktop Chromium WebAudio regression
passed with the rebuilt game:
observed decoded buffers were 0.620 and 0.340 seconds with distinct fingerprints.
Real drag, pronunciation, consecutive taps, mute, menu pause/resume and exit
retained their expected playback behavior. The isolated final cue timeline is
available at `build/jelly-audio-refinement/jelly-material-timeline.wav`; it uses
the runtime gains and model timing, and is not a gameplay recording.
The Windows iPhone WebKit test runtime has no available WebAudio; gameplay and
layout coverage remain separate. Technical checks do not establish subjective
mix quality, repeated-play fatigue or sound on physical speakers.

The soft landing update passed the source/hash and PCM checks, all 74 native
audio checks and all 40 focused Web export/audio tests. The rebuilt game also
passed the desktop Chromium WebAudio regression: the dedicated landing samples
played from the offline bundle, remained distinct from empty-drop feedback, and
respected mute, menu pause/resume and exit. Direct listening remains unavailable
in this review environment; these results establish playback and lifecycle,
not subjective listening approval.

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
