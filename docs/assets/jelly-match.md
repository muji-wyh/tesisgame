# Jelly Match artwork and sound

Jelly Match uses acquired, face-free jelly artwork beneath the existing word
pictures and labels. A shared silhouette, consistent upper-left highlights and
muted color variants give the board a soft material without competing with the
learning content. The appearance comes from a production illustration; animation
deforms that illustration rather than replacing it with flat geometry.
Both jelly modes share the sourced [Kenney daylight panorama](jelly-sky.md),
with quiet [garden foliage](jelly-garden.md) along the perimeter.

Jelly Words reuses the acquired coral skin and its signed-distance material.
A per-instance shader hue preserves the original highlights, shaded contours
and alpha while identifying exact-word partners. Idle pairs have distinct hues;
selecting a chunk recolors its ordered word completions to the same hue. Both
fusion lobes and the upcoming preview use the same palette.
The default shader hue is disabled in Jelly Match, preserving its four skins.
This is a runtime color adaptation of the integrated CC0 artwork below, with
no new asset acquisition or baked animation.

## Sources and acquired material

| Material | Creator and original source | License and status | Available animation |
| --- | --- | --- | --- |
| Finish flag icon | Paweł Kuna, [Tabler Icons v3.35.0](https://github.com/tabler/tabler-icons/blob/v3.35.0/icons/outline/flag-check.svg) | MIT. Downloaded, visually inspected and integrated as `assets/images/ui/finish-flag.svg`. [Attribution and adaptation](../../assets/images/ui/ATTRIBUTION.md) and original license retained. | Static vector artwork; button states use the existing native input lifecycle and click cue. |
| Gel tile surface | Zuhria Alfitra, also known as pzUH, [Jelly Squash Free Sprites](https://www.gameart2d.com/jelly-squash-free-sprites.html), GameArt2D | CC0 1.0 under the creator's [Free Assets License](https://www.gameart2d.com/license.html). Downloaded from the original site on October 9, 2026; all six blank bodies inspected, then the smooth third body adapted and integrated. | The source supplies static bodies, separate faces and vector originals. It does not include baked animation clips. Squash, merge, settling and clear motion are authored by the game. |
| Selected contact and merge cues | greenlinker, [Slime stretching and squeezing](https://freesound.org/people/greenlinker/sounds/794270/), and rubberduck, [40 CC0 water / splash / slime SFX](https://opengameart.org/content/40-cc0-water-splash-slime-sfx); locally adapted and selected by the user | CC0 1.0. The greenlinker HQ MP3 preview and rubberduck original OGG pack were acquired; the greenlinker original WAV was not acquired. The two selected WAVs are copied unchanged into `assets/imported-audio/jelly-interaction/`. [Exact selections, hashes and processing history](jelly-interaction-audio.json). | One-shot audio only. Contact lasts 0.135 seconds; the selected v3 merge lasts 0.440 seconds. No animation is included. |
| Merge motion reference | User-supplied `jelly_merging.mp4`; original creator not supplied | Inspected locally as a motion reference. License not supplied; none of its artwork or soundtrack is integrated. SHA-256: `383f1ce4218e2502368416abb402c3fe1c9b89351be14535ce08163da65b521f`. | 2.93-second, 30 fps recording. The useful passage shows two soft bodies forming a narrow bridge, widening the shared waist and relaxing into one body. |
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

Drag contact traces the painted body at alpha 128/255, with a maximum contour
simplification error of half a source pixel. The cached outline follows the held
body's stretch, foot pivot, selection lift and pointer anchor. Slight silhouette
overlap previews a partner; release confirms the pair. Transparent corners and
the separate shadow do not collide. If multiple bodies touch, the nearest body
wins regardless of word correctness. Feedback deformation stays outside this
test so its own squash cannot toggle contact, and the deep-overlap separation
effect fades out at the edges to keep barely touching bodies together.

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

Supply dispatches four tiles together. Twelve settled tiles fill the bottom
three rows of the initial matching layout. The first automatic batch waits for
the full ten-second interval; the upcoming area can still release it immediately
on request.
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
tile has settled and the well has room, including during a fusion. It uses the same
four-tile dispatch, column selection, gravity and landing projections as a timed
drop; a nearly full board still accepts only its remaining capacity. The supply
clock resets after an accepted manual drop, so the next timed batch receives a
full interval. Dropping a batch does not score a point, award treasure or record
a learning attempt.

Fusion reserves only its own two tiles. Other pairs, pronunciation, automatic
supply, manual supply and Finish remain available during the merge and clear
animation. Airborne tiles and the full-board countdown keep advancing. A clear
stops the warning when it actually makes space; a clear exactly at the countdown
deadline wins. Finish cancels unfinished pairs without crediting them, while
retaining completed scores, learning attempts and fragments. Gravity responds to
each completed pair immediately, including when other fusions are still active.

In both Jelly modes, pull Finish downward until it glows, then release to end
the round. An early release returns the button and keeps playing. Keyboard and
controller activation use a centered confirmation card with the existing
typography and theme palette. Keep playing receives default focus; Escape or
controller Back also resumes the round. Supply, fusions, collection beats,
danger clocks, chest effects and confetti pause while the player decides,
including across page backgrounding. Committing Finish immediately opens the
settlement modal over the frozen board. Automatic full-board expiry opens the
same modal after its warning completes.

The control has the accessible name `Drop the next jellies` without a hover popup, while
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
Menu pause freezes the pose; fusion leaves anticipation running. New supply starts at rest; a full board
and reduced motion display neutral previews. No new visual or audio asset is
introduced for anticipation; the existing CC0 gel skins and contact shadow are
reused.

Each landing projection reuses the same acquired gel silhouette at its actual
destination, without word, picture or chest content. It remains stationary while
its incoming tile descends, then disappears at contact. The original painted
contact shadow still accompanies the landing. No additional placeholder artwork
is introduced. Descent and the supply clock continue during fusion; a shifted support
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
and inward skin pressure identify an opposite-kind pair with the same word ID;
a coral contour and opposed recoil identify an incompatible pair. These visual
states communicate directly on the jelly skins without floating text labels.
These previews do not submit learning attempts. Only a committed wrong drop
resets learning, and only a completed fusion grants success and treasure.

The continuous fusion skin samples four derivative material maps documented in
[the material manifest](jelly-material.json). RGB preserves the acquired painted
surface, including its existing highlights; alpha stores signed distance to that
exact source silhouette. Smooth distance-field union gives the contact neck a
continuous contour. Moving meniscus light, lower-edge attenuation and a restrained
highlight add thickness without warping the separate picture or word. These are
runtime material effects, not additional sourced animation clips.

The 1.05-second committed timeline remains unchanged. The shared skin inherits
both actual held centers and stretches at release. A thin bridge forms while the
two lobes remain distinct for approximately the first 0.17 seconds. The neck then
widens as both sides gather around their common center, completing the union at
0.55 seconds. Paint gradually flows into the destination color. The original
learning faces fade before the combined picture and word appear, avoiding double
text during the transition. One gentle recovery leads into compression from
0.60 to 0.70 seconds, then the body springs upward and retracts. Deep-overlap
drops briefly express two pressure lobes from their actual held pose; edge drops
retain their existing separation. The existing pop cue at 0.70 seconds
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

Each fully cleared pair earns one point. Both Jelly modes settle immediately
in a modal over the frozen board, with no standalone results page or intervening
Pip celebration. Finish uses `Round complete`; danger expiry uses `Game over`.
The modal displays the score, completed word count, and final chest tier or
`No chest this round`. Four fragments unlock one chest; every five more upgrade
it. Hold the earned chest to open it inside the modal. `Play again` saves and
collects pending chest coins before starting a new round; save failures retain
the modal for retry. `Home` returns to the mode menu and preserves pending
treasure. See
[chest fragments](jelly-fragments.md) for the reward and animation details.

| Event | Runtime path | Original source | Duration | Peak |
| --- | --- | --- | ---: | ---: |
| Falling gel makes contact | `assets/audio/jelly-match/land.wav` | rubberduck `slime_16.ogg` | 220 ms | −16.0 dBFS |
| Two jelly surfaces first touch | `assets/imported-audio/jelly-interaction/contact.wav` | User-selected Wet & Springy / Contact; greenlinker and rubberduck | 135 ms | −14.143 dBFS |
| Two gel bodies commit to a merge | `assets/imported-audio/jelly-interaction/merge-together-v3.wav` | User-selected Jelly Merge Together v3; greenlinker and rubberduck | 440 ms | −14.473 dBFS |
| Completed item clears with elastic release | `assets/audio/jelly-match/clear.wav` | rubberduck `slime_16.ogg` with Aeva `boing.flac` | 340 ms | −7.5 dBFS |
| Each full-board countdown beat | `assets/audio/jelly-match/danger.wav` | `Audio/question_001.ogg` | 491 ms | −12.00 dBFS |

These are measurements of the final PCM files. The selected contact and v3 merge
retain their approved samples, duration and pitch; their RMS levels are −31.615
and −30.613 dBFS. Both use runtime gain 1.0 with the existing pronunciation duck.
The former 620 ms merge remains in the historical material asset record but is
no longer assigned to gameplay. The clear retains its original WAV checksum,
runtime gain 0.90 and 0.70-second trigger. Its gel-skin release and spring layer
are unchanged.

Contact plays once when a dragged jelly first touches another body's outline,
including a new contact first detected at pointer-up. Holding the same contact
does not replay it. Separating or moving to a different partner allows a new
contact cue. Contact never submits a learning answer and uses an idle channel
so it cannot replace active clear, warning or reward sounds.

The landing derivative uses a single `slime_16.ogg` layer with an 85 Hz high-pass
and 1,100 Hz low-pass filter. Compression uses threshold 0.07, ratio 4, a 2 ms
attack and a 45 ms release. Playback starts 4 ms into the filtered recording at
0.86 speed, with exponential damping `exp(-7t)`, a 16 ms onset fade and an 85 ms
tail fade. Its final peak is −16 dBFS before the separate runtime gain of 0.35.
The resulting PCM RMS is −32.520 dBFS, with onset above −40 dBFS at 12.79 ms.
The softer attack and reduced high-frequency energy replace the former shared
chest step cue. That original recording remains unchanged for chest interaction
and Pip's celebration.

The historical material conversion uses FFmpeg floating-point decode,
stereo-to-mono mix and 44.1 kHz PCM16 output. Those material cues use edited
envelopes, layered recordings and pitch/time adaptation.
The importer and manifest record the source files and exact processing recipe.
Gain must be applied before PCM conversion: some source Vorbis recordings exceed
0 dBFS when decoded to floating point. Attack and tail fades keep the delivered
file edges at zero, with headroom for the existing game mix. The countdown cue
retains its previous conversion and measured output. The two selected interaction
WAVs instead remain byte-for-byte 48 kHz stereo PCM24 copies. Godot imports them
as uncompressed PCM16 with no normalization, trimming or playback-rate change.

Drive each cue from the same committed event as its visible contact or release.
The merge starts at fusion time 0; the clear starts at the existing 0.70-second
pop node. Both end within the unchanged 1.05-second fusion timeline. Audio does
not move the success-credit boundary or change matching, difficulty or rewards.
Do not play merge or clear for every animation frame or every affected card.
The full-board clock triggers one danger recording at each remaining second,
including entry. The board's rim light uses that same eight-second clock. Its
primary beat holds for 180 ms and fades by 550 ms; a weaker second beat gradually
enters during the latter half of the countdown. Amber progresses through hot
orange to scarlet, and two bright highlights accelerate around the rounded rim.
Quiet intervals separate the flashes. A faint inner glow fades into the board,
leaving the learning faces clear; the board and its
input geometry do not move. No full-screen flash or additional warning label is
introduced. Reduced motion removes traveling highlights and repeated flashes,
retaining a stationary glow with gradual color and intensity changes.

Jelly Match and Jelly Words share this escalating warning presentation. The
exterior light footprint grows from 12 to 72 screen pixels within an 80-pixel
drawing margin. Its textured corona grows broader and brighter. A softer interior
spill reaches 10 to 24 screen pixels inward as urgency rises, using an exponential
falloff so the word faces stay legible. The inner spill reuses the same acquired
light texture and amber-to-scarlet color; it joins the rim without extending the
strong exterior glints over the jellies. Two traveling glints leave luminous
tails that lengthen with speed, growing from a deliberate 0.07 to 0.72 laps per
second. The continuous orbit integrates a quadratic speed curve using the real
normalized rescue clock, so both modes reach the same urgency without phase
jumps. Each existing beat sends a soft wave outward and a faint echo inward; the
second beat enters later for the final buildup. Reduced motion removes glints,
tails, waves and flashes while retaining gradual inner and outer glow growth
and color change. The eight-second
Match and ten-second Words rescue windows and audio stay unchanged.

The rim reuses the acquired `portal_glow.png` from Bobardo's Modern 2D Animated
Chests Pack_FREE Demo 1.0.2, under the existing Standard Unity Asset Store EULA
record in [treasure assets](../voice-pop-treasure.md). Its local source mapping
remains in `assets/chests/SOURCE.txt`. The elongated highlights reuse
`assets/chests/milestone/sparkle.png` from Kenneth Foldal Moe / Archanor VFX's
acquired Toon FX 1.52, under the same EULA; original source, license, acquisition
status and byte-identical hash remain in [the fragment record](jelly-fragments.md#extra-motion-textures).
Both integrated files are static 512 x 512 textures, inspected over a dark
background before reuse. Their rim motion is authored by the game, with no
independent timer or shader `TIME` and no new audio asset.

A completed rescue immediately stops warning audio and removes the light once
the fusion actually makes space. Starting a match keeps the countdown running.
Pause, hidden page, blocked interaction, stop, new round and expiry suppress the
light; resume restores its saved phase without restarting a beat.

The expanded warning was compared before and after on the same seeded full boards
in both modes at 393 x 852 and 1473 x 1175. The 48 local rendered frames cover
opening, middle and late bright beats, a quiet interval, the late secondary
beat and reduced motion. Existing native view regressions verify progressive
intensity, interruption, exact phase restoration, completed rescue and the
unchanged deadline. These are rendered and automated checks, not physical
phone or subjective audio approval.

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
source shadow PNG, four historical material WAVs and the manifest. The separate
selected interaction WAVs are not regenerated by this importer.
`--images-only` retains existing audio files and their complete
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

At the earlier 620 ms merge and clear integration, those replacement files passed source/hash,
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
cover concurrent anticipation and descent during fusion, support changes and the
complete full-board rescue window.
Desktop and phone captures cover the external queue and fixed-ratio well. After
live resize, Windows WebKit retains its previously documented
[page-compositor limitation](../qa/2026-09-11-steady-gameplay.md): composed page
captures can be blank while the raw canvas renders correctly. Both captures are
retained; the raw canvas and touch/keyboard interactions pass at 390 x 844 and
844 x 390. This does not establish physical iPhone rotation behavior.

## Jelly Words picture reveal

The upper picture-and-spelling reveal reuses the exact current-age word texture
through `WordArt`, including its existing animation and recorded pronunciation.
Those acquired and integrated vocabulary sources remain catalogued in
`docs/assets/word-library.json` and `data/word-motion.json`; no new word artwork
is synthesized.

The short light accent uses the already integrated
`assets/chests/particles/portal_glow.png` from Bobardo's Modern 2D Animated Chests.
The painted glints reuse `assets/chests/milestone/sparkle.png` from Toon FX 1.52,
by Kenneth Foldal Moe / Archanor VFX, under the Standard Unity Asset Store EULA.
The original sources, acquisition records and texture hashes are preserved in
`assets/chests/SOURCE.txt` and [Jelly fragments](jelly-fragments.md). These are
static production textures animated by the reveal; no new assets are acquired.

Each collection creates an independent content-sized burst in the upper
playfield, with varied placement and scale and an elastic entrance. Direct taps
retain the 1.95-second reading beat and selected-word pronunciation. Collect
batches launch a new burst every 100 ms, retaining older bursts for 480-860 ms
according to screen space; batch pickups never pronounce words. The unchanged
`clear.wav` cue fires at the 180 ms manual-pop boundary or the 60 ms batch-pop
boundary. Speech ducking, mute and interruption rules remain shared with
ordinary gameplay. See [Jelly Words](jelly-words.md) for the active reveal and
collection behavior.
