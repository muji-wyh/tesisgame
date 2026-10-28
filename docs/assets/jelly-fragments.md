# Jelly Match chest fragments

Each chest-marked jelly consumed by a successful merge awards one chest fragment
within the current round; merging two marked jellies awards two fragments, and
ordinary unmarked merges do not award fragments. Four fragments form the first
chest; every five additional fragments upgrade that same chest. The result
contains one final chest, with its earned tier, rather than the intermediate
chests. These tiers are separate from Pip's vocabulary mastery level.

## Motion reference

The user supplied `C:/uworks/841558b760f51a655715393be5238950.mp4` as an animation
reference. It is a 27.8-second, 1280 x 576, 30 fps recording. Its creator and
redistribution license were not supplied. No image or audio is extracted from
this video into the game.

The inspected chest upgrades around 1.3-1.9, 2.9-3.5 and 4.5-5.1 seconds use a
brief anticipation, lift and turn, a local light accent that reveals the new
chest, and a clear landing. Rank-up sequences around 16.2-18.0 and 23.8-26.0
seconds add rays followed by side fountains of confetti that spread and fall
across the screen. The still review samples the complete video at one frame per
second and the relevant sequences at five frames per second. These samples
establish visible beats; they do not constitute a normal-speed audio review.

The adaptation preserves the existing 0.65-second pickup flight and progress
fill. The whole closed chest travels from its HUD anchor to the upper-center
area, growing throughout its flight, rotates at full size, and retraces the same
path back to its anchor. First-chest synthesis and upgrades follow one straight
line in both directions. The chest stays upright during travel and enlarges
gradually; the acquired 3D model stays visible throughout the journey. The paths respond to
the HUD position and viewport, without an intermediate stop at screen center.
Match and Memory retain their existing direct flight.
All thirty tiers use their acquired closed 3D assemblies for the full journey
and vertical-axis turn, with a fixed camera envelope and no pitch or screen-plane
roll. The former tier-five-and-later flat-image/cosine turn is removed.
Real sides, back panels, thickness and attached fittings remain visible as the
chest rotates. The existing two-surface pool and independent reward ownership
remain. The first twelve tiers also use Blender-refined CC0 bases; original
files, separate lids, source UVs and opening clips are preserved. Source,
creator, license, conversion hashes and animations are recorded in
`assets/chests/polished-cc0/manifest.json`; the five private designs retain their
existing softer three-segment source conversion. No replacement geometric chest
or new audio is introduced.
Intermediate chests never run final opening or saving callbacks; the gameplay
model alone owns fragment credit and tier changes.

After pickup, the 2.65-second performance reaches the upper destination at
0.84 seconds in one smooth flight, without a waypoint at the viewport center.
Position and scale share the same eased progress: the chest reaches its maximum
size exactly on arrival, with no second enlargement at the destination. The
full turn runs from 0.90 to 1.82 seconds. Material change, local flash, reward
sound and confetti share the 1.36-second midpoint. This places the Jelly Words
milestone peak after its 1.95-second word-picture reading beat. The return runs
from 1.98 to 2.65 seconds, reversing the same straight path and scale to recover
the original position and size without
fading the chest away. First-chest and pair rewards target a 176px silhouette;
upgrades target 216px, fitted to the available viewport on small screens.
When several earned tiers are queued, this is one continuous multi-revolution
spin at the same upper-screen fitting envelope. The angle never resets or
stops between tiers: every full 0.92-second revolution reveals exactly one
successive material with its own sourced flash/rays and reward cue. Assembly
plays once; the chest returns only after the final full turn. Multi-level jumps
enqueue each real intermediate tier rather than substituting a single turn.
A next pickup that has not visibly arrived holds the same chest at the top.
Each earned tier keeps its own reveal sound and model-owned progress; presentation
neither manufactures intermediate chests nor skips a final level. The source
chest, rays and local flashes remain the same acquired artwork.

An upgrade also shows its real **previous level → new level** beneath the enlarged
chest, such as **Lv3 → Lv4**. One compact dark-teal strip keeps the old value
smaller and muted and the new value larger and warm gold. Its values come from
the committed milestone payload, not the current HUD tier or target-minus-one.
The strip fades in as the chest reaches its upper destination and leaves with
the existing return, without extending the performance or pausing play. Each
queued upgrade retains the just-revealed pair for 450 ms before showing the next
turn's pair, so a completed level cannot disappear on the same frame as its cue.
First-chest synthesis does not invent a Lv0 transition. Reduced motion keeps a
static level pair near the existing HUD chest. Pause, hiding and round cleanup
hide the same input-transparent presentation.

The connector reuses Paweł Kuna's already acquired Tabler Icons 3.35.0
`assets/images/ui/controls/chevron-right.svg`, MIT, with unchanged source paths.
Its original URL and hashes remain in `assets/images/ui/controls/sources.json`
and its license in `assets/images/ui/LICENSE-Tabler.txt`. The source-scale icon
review and the actual chest turn were inspected before reuse. This is static
source artwork with no animation clips; the text, panel and timing are ordinary
game-authored interface presentation. No new chest, particles or audio is acquired.

The flight draws on a noninteractive viewport layer, outside gameplay clipping.
Its source coordinates and actual turned silhouette remain tied to the current
HUD layout. Both upgrade models share one fitted envelope, so the tier change
cannot push the return onto a different path at the screen edge.
Hiding the owner, entering Home or the word library, pausing, or
clearing the round hides this layer and stops the active model renderers.
Reduced motion keeps a static chest at its HUD anchor and the same reward gate.

The chest settles in its existing gameplay HUD while the paper spreads across
the viewport and falls away. There is no dimming panel, centered reward page,
input lock, or automatic gameplay pause. Jelly dragging, merging, dropping,
danger countdowns and Finish remain available; Voice Pop keeps its timer,
targets and microphone running. Only actual menu, background and voice-session
pauses freeze the effects. End-of-round results keep their existing flow.
Jelly Match and Voice Pop synthesis and upgrades retain their full-screen
chest burst. Jelly Words instead starts paper only when its current learning
stage is durably completed, including the final partial stage; obtaining or
upgrading its chest does not launch paper.
The shared `reward_confetti.gd` renderer accompanies earned-chest reveals in
Match, Memory, Voice Pop and Jelly Match. GameUI owns its
dedicated viewport CanvasLayer, so arena clipping, layout bounds and the game
header cannot cut off the paper. A reveal starts one independent 6.4-second
burst of 85-267 paper pieces, scaled to viewport area and UI density. This removes
another third of the preceding 128-400 population, rounded to the nearest whole
paper for each viewport and UI scale. The smaller upper-third preset likewise
drops from 8-24 to 5-16 pieces. The same acquired atlas now uses a 22-34px base edge
instead of 18-28px, making each paper about twenty percent larger. Chest
bursts use the current round, mode and chest tier; Jelly Words stage bursts
use the round and stage number. Both cannons start at the lower screen sides
and crest in the upper quarter before drifting down. Papers are not initialized
at arbitrary heights across the whole screen.
Each paper strip is 1.5 times its base edge in length and 0.65 times in width,
with its full rotated footprint kept inside the viewport sides. The chest and Pip retain
their original completion gates while the paper continues over the current
game or result screen.
In the Challenge result, a game-authored screen-space mask lets this same paper
pass behind the actual responsive dialog, keeping its title, medal and two
actions readable. It does not change particle counts, paths, duration or input.
Other modes retain their existing full-screen presentation.

A 0.55-0.8-second launch spreads across the full width;
the descent then takes more than four seconds. Independent air currents, opposing
tumbles with changing angular speed, and two-axis flutter keep the paper from
moving as one band. The acquired rounded-square texture bends along each strip's
center, with continuous front/back shading as it turns. Wider launch heights and
distinct upper-band peaks vary the descent without changing terminal speed by
height. All papers share the same elapsed-time drag curve: a 240 ms acceleration
approaches a viewport-scaled terminal drift. Fall distance is never normalized
to a paper's remaining lifetime or distance to the bottom, eliminating the old
fast-top/slow-bottom artifact. Each reward identity seeds its own repeatable arrangement without consuming
gameplay randomness. Each piece stays opaque until its
entire footprint passes below the viewport bottom, with staggered exits.
Menu and background pauses hide and freeze the tail. Leaving the round or
starting another clears it; reduced motion suppresses it. Round identity
prevents an already announced chest from bursting again at the finale.

Phrase Builder uses this same paper burst for correct answers on the gameplay
page, alongside its existing success sound and phrase playback. Answer bursts
use the round and attempt identity, so repeated input cannot replay them.
Entering its completed-round chest invitation clears any remaining answer
paper, and the invitation does not launch a chest burst. Gameplay paper shares
the same pause, round cleanup and reduced-motion behavior.

The Jelly Match gameplay HUD uses a segmented halo around the existing chest
art instead of a numeric fragment counter. Four segments fill to unlock the
first chest; five segments fill for each subsequent upgrade. A segment charges
over 0.32 seconds when its pickup flight arrives, with one 0.55-second local
accent using the existing `portal_glow.png` texture documented below. The ring
advances only for time after each actual arrival, even on a slow frame or with
overlapping pickups. Newly launched fragments receive their full flight. A
milestone waits until that visible segment fill completes before animating the
chest inside that same HUD. The reward total remains
committed when the jelly clears; this arrival gate controls presentation only.
The ring holds full until the milestone reveals its chest, then begins the next upgrade.
It has no idle movement and disappears on the result page. Its clock follows
the gameplay owner, including pause and interruption; reduced motion updates
the segments immediately. Exact totals remain available to accessibility tools.
The halo is an interface progress indicator, not replacement chest artwork;
no additional image or sound asset is acquired for this presentation.

## Fragment audio

Fragment appearance and arrival use two distinct acquired recordings from
Kenney's [Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds), under
CC0 1.0. The local All-in-1 3.7.0 source collection supplied `drop_002.ogg` for
appearance and `glass_001.ogg` for arrival. These are integrated recordings,
not source previews, and are separate from coin, UI click and chest-opening cues.
Audio assets contain no animation. The original license, source hashes, output
hashes and measurements are retained in `assets/audio/fragments/manifest.json`
and `assets/audio/fragments/LICENSE.txt`.

The 188 ms appearance cue and 276 ms arrival cue retain their full source lengths
and pitch. Floating-point decoding preserves source peaks above full scale;
a 1 ms attack, 12 ms tail fade and 0.70 peak ceiling prepare mono 44,100 Hz PCM16
WAVs. No generated sound or new layers are added. Godot imports them without
normalization, trimming, looping or compression. Source metadata, waveform,
timing and headroom were inspected; this does not establish auditory quality.

Jelly Match, Jelly Words and Voice Pop play `appear.wav` when a collected
fragment starts its visible flight, then `arrive.wav` when it reaches the chest.
Treasure uses the same pair for each scheduled launch and delivery to its target
jelly. These cues follow actual presentation events, independently of the
already committed reward. Ordinary pickups that transfer directly to the HUD
under reduced motion play only the arrival cue; Treasure retains its existing
delivery timeline.

Four dedicated channels keep fragment tails separate from coins, merges,
warnings and chest milestones. Runtime gain is 0.45, with a further 6 dB
reduction during word pronunciation. Same-kind events less than 60 ms apart
share one audible cue instead of stacking identical attacks; appearance and
arrival have independent grouping clocks. Muting, leaving the round or pausing
the owner stops these channels and clears their grouping clocks. Flight
boundaries are not replayed when gameplay resumes.

Rebuild the two assets and their separated listening preview:

```powershell
node tools/import-fragment-audio.cjs 'Q:/uwok/Kenney Game Assets All-in-1 3.7.0/Audio'
```

`build/fragment-audio-audition.wav` plays the integrated appearance clip, 650 ms
of silence and the integrated arrival clip, at their asset level. The game mix
applies its own lower runtime gain. The importer requires FFmpeg and Node.js.

## Chest art

The tier progression reuses the integrated designs in this order:

| Tier | Existing design | Source record |
| --- | --- | --- |
| 1 | Meadow Explorer (`bramble`, Jungle) | Acquired Ekrem C. chest, warm wood and green frame |
| 2 | Harvest Keepsake (`harvest`, Autumn) | Acquired Batata Studio chest, amber wood and gold trim |
| 3 | Lagoon Pearl (`tide`, Ocean) | Acquired Batata Studio chest, pearl frame and wing ornaments |
| 4 | Moonstone Vault (`nebula`, Space) | Acquired Bobardo chest, lilac enamel and a gemstone |
| 5 | Royal (`royal`, Spring) | Existing Modern 2D Animated Chests source artwork |
| 6 and higher | Crystal (`crystal`, Winter) | Existing layered Modern 2D Animated Chests artwork |

The numerical tier continues above six; the highest integrated chest design
remains in use. Every additional five fragments still produces an upgrade.
The first four sources, their Unity Asset Store Standard EULA, source and output
hashes, separate body/lid geometry, and available animation clips are documented
in [the chest replacement record](chest-refresh.md) and
`assets/chests/downloaded/manifest.json`. Royal and Crystal retain the source
record in `assets/chests/SOURCE.txt`, `assets/chests/manifest.json`, and
[round completion](round-celebration.md). The tier system does not introduce a
new acquisition or claim a new license for those existing assets.

## Confetti source and preparation

| Field | Evidence |
| --- | --- |
| Title / version | Toon FX 1.52 |
| Creator | Kenneth Foldal Moe (Archanor VFX), named in the acquired package README |
| Official source | [Toon FX, product 25601](https://assetstore.unity.com/packages/vfx/particles/toon-fx-25601) |
| License | [Standard Unity Asset Store EULA](https://unity.com/legal/as-terms), confirmed on the official listing on 2026-10-10; the listing identifies an Extension Asset |
| Acquisition | Pre-existing locally acquired source package at `C:/uworks/AssetsSource/Toon FX [1.52]`; no new purchase or listing-preview download |
| Selected source | `Textures/confetti2x2_smoothed.png`, 512 x 512 RGBA |
| Source / output SHA-256 | `14606c1eacc47550afdaddb920b8102363108d72a0ad02997366cd894bae4108` |
| Runtime input | `assets/images/jelly-match/confetti.png`, copied byte-for-byte; lossless Godot texture import |
| Source animation | Static 2 x 2 particle atlas; the package also contains Unity rain and explosion prefabs |
| Integrated animation | Game-authored screen-space trajectories, tint, rotation and paper flutter; Unity prefabs and scripts are not imported or executed |

The source sheet contains rounded square, star, circle and triangle silhouettes
in its four 256 x 256 regions. Its monochrome artwork is deliberately intended
for recoloring, as explained by the package README. The game uses the rounded
square region as paper. White source pixels retain
their alpha contours and receive palette colors at draw time.

The atlas was inspected over a dark background to reveal its transparent shape
edges, then compared with the non-smoothed original. The exact source remains a
private build input and ships only inside the compiled game pack, consistently
with the existing licensed Unity artwork policy. The local source, official
listing and previously retained extraction audit establish distinct acquisition,
inspection and integration states; a listing image is not used as game art.

To restore this private input from the acquired package, preserving its reviewed
hash and generating lossless Godot import settings:

```powershell
node tools/prepare-jelly-reward-art.cjs
npm run import
```

Pass the exact PNG path as the optional first argument when the acquired pack is
stored elsewhere. An unexpected hash or image format fails before changing the
runtime input. The original reviewed atlas is 17,134 bytes. The original Unity
material, particle prefabs and source README remain outside the repository.
The Web build checks the private atlas hash, exact size and lossless import
settings before starting Godot import. It does not restore or replace an asset
silently. The focused `jelly-reward-art` Node suite covers missing and altered
inputs, import-setting failures, exact copying and idempotent restoration.

The existing `assets/chests/particles/portal_glow.png` supplies the local light
accent under its recorded source rights. Existing chest cue recordings can be
reused without copying a new soundtrack from this motion reference; their
provenance and extraction limits remain in
[the chest audio record](chest-reference-audio.md).

## Extra motion textures

Chest synthesis and upgrade use two additional textures from the same acquired
Toon FX 1.52 package by Kenneth Foldal Moe (Archanor VFX), under the Standard
Unity Asset Store EULA documented above. Both sources are static, 512 x 512,
8-bit RGBA PNGs. The source `Textures/glowlines.png` provides radial light
streaks and `Textures/sparkle.png` provides a four-point glint; both were
inspected over a dark background. Their animation is authored in the game;
no Unity prefab, shader or script is executed, and no video frames are shipped.

| Acquired source | Private runtime input | Bytes | Source / output SHA-256 |
| --- | --- | ---: | --- |
| `Textures/glowlines.png` | `assets/chests/milestone/rays.png` | 19,013 | `75ecb9a8d2c20b4892dc45160decb6d18387ce3892f7fc8ee2401d5f8773d8c1` |
| `Textures/sparkle.png` | `assets/chests/milestone/sparkle.png` | 50,052 | `e8387f9328d38d0b10706814f0c3500debaf1ba2133a8c80a65ef636a8238856` |

Restore these byte-for-byte private inputs with
`node tools/prepare-chest-milestone-art.cjs`, then run `npm run import`.
The optional first argument is the acquired package's `Textures` directory.
Preparation validates both source hashes, sizes and PNG dimensions before
writing either output, and creates lossless imports without mipmaps, resizing,
channel remapping or alpha premultiplication. The PNGs and their import files
remain ignored and ship only in the compiled game. The Web build verifies
both private inputs without silently restoring them. The focused
`chest-milestone-art` Node suite covers exact copying, preserved resource UIDs,
idempotence, invalid sources and changed import settings.

## Local chest tap

The Jelly Match and Jelly Words HUD chest also responds to a tap with a 920 ms
local enlargement, alternating turn and gold light accent. The source chest art,
Bobardo Modern 2D Animated Chests portal glow, and acquired Toon FX rays/glint
textures above are reused under their existing recorded licenses. These are
integrated production assets; the new tap timeline is authored in the game.
It keeps the HUD anchor and hit area fixed and grants no fragments or rewards.
Repeated taps share one bounded response. Reduced motion uses a 400 ms glow
without enlargement or rotation. Leaving, pausing, finishing, or starting an
earned chest celebration cancels the local response.

## Lifecycle and review boundary

Queued milestone visuals must stay attached to their round and fragment event.
Menu/background pauses freeze their clocks. Leaving the mode or starting a new
round clears visual events and sound. A completed tier transition must not replay
or save another chest when resumed. Concurrent merges may queue several visual
milestones while the model retains their final tier exactly once. Reduced motion
keeps the same chest/tier outcome and readable text, with no lift, turn or falling
confetti.

Ignored source-review outputs are in `build/jelly-fragments-review/`. They are
local review artifacts, not public routes or shipped content. The source-frame
inspection and resource checks are separate from gameplay and sound review.

The earlier real-scene captures cover synthesis and upgrade at 1280 x 800, plus
project-scaled 390 x 844 portrait and 844 x 390 landscape. Frame review confirmed
sharp chest artwork, viewport-wide paper distribution, and separated, unclipped
title, chest and level labels in the previous centered presentation. Normal-speed recordings include the runtime cue
track. Cue timestamps and audio peaks were checked; subjective timbre and
physical-device playback remain outside this review.

Focused native tests cover the four-then-five thresholds, concurrent merges,
menu pause/resume during pending fusions, exact presentation boundaries,
reentrant stop/new-round callbacks, reduced motion, final-tier persistence,
save retry and duplicate reward protection. The private confetti input also
passes read-only source, format, hash and import-setting validation.

The current HUD presentation was captured in the real Jelly scene at 1000 x 800,
390 x 844 and 844 x 390. A 60 fps native capture follows a held drag through
fragment arrival, meter fill, assembly and confetti while the spawn clock keeps
advancing. The reduced-motion captures retain the same HUD without paper.
Those earlier captures used top-level drawing only for paper; the current
chest flight also escapes clipping while Voice Pop's live arena remains clipped. A separate native render verifies full-viewport paper through a clipped
parent and its immediate removal when that parent is hidden. These captures are
muted visual checks; the unchanged reward sounds were not acoustically reviewed.

The revised reference-style motion is captured at 60 fps in the real Jelly
scene, including a held drag, synthesis and a tier 1-to-2 upgrade. Native
390 x 844 and 844 x 390 captures check the local silhouette, rings and paper;
reduced-motion captures retain the closed static HUD art. The capture is muted:
existing assembly/reward recordings and cue times are unchanged, and no new
acoustic-quality claim follows from the visual review. Focused tests verify
all four 3D tiers stay closed and inside a fixed camera envelope through a full
turn, use at most two 512px surfaces, and stop rendering when hidden or cleared.
The original chest-opening mechanism remains independent.

The earlier two-stage screen flight was inspected in local native renders at 1366 x 768,
390 x 844 and 568 x 320 for Jelly Words, Voice Pop and Memory. These are muted
visual fixtures with sampled center, rise, turn, reveal and return frames, not
physical-device or acoustic playback evidence. Focused route and lifecycle tests
cover actual viewport coordinates, small-screen silhouette containment, pause,
Home/library navigation, resize, reduced motion and exact HUD handoff.
