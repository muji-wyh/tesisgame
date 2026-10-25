# Jelly Words level collection feedback

Merged words have nine levels and keep the ordinary one-cell Jelly body. Matching
words add their levels, including unequal pairs; results greater than Lv9 are
ineligible. Their collection feedback uses one accepted model release for the
body disappearance, board effect and sound. Presentation never grants rewards.
All nine existing recordings remain byte-identical. Reward values are documented in the coin economy record.

| Level | Board effect | Post-release lifetime | Existing audio signature |
| --- | --- | --- | --- |
| 1 | Pearl pop: compact mint sparkle release | 0.80 s | Approved fixed bubble pop |
| 2 | Twin ripple: two concentric cyan releases | 1.10 s | Bubble pop with a short glass accent |
| 3 | Spiral lift: rising sapphire curl | 1.45 s | Bubble pop, rising interface accent and glass tail |
| 4 | Firework bloom: gold spokes, three colored blossoms, descending embers | 2.80 s | Bubble pop, bell bloom and staggered glass crackles |
| 5 | Rose cascade: staggered pink and gold layers with descending embers | 3.10 s | Two glass releases at different pitches |
| 6 | Prismatic bouquet: a central release and six colored radial layers | 3.40 s | Rising accent, bell body and ascending glass details |
| 7 | Aurora crown: layered violet and mint radial blossoms | 3.60 s | Confirmation chimes with contrasting glass pitches |
| 8 | Constellation shower: four staggered pairs of gold and blue blossoms | 3.80 s | Bell body, rising chime steps and glass details |
| 9 | Grand bouquet: a central release and nine multicolor blossoms | 4.00 s | Bell, rising accent, two chimes and ten glass details |

Manual Lv1-Lv3 collections release at 180 ms. Lv4-Lv9 first contract the actual
painted Jelly, gather light at its core and build to release at 660, 720,
780, 840, 900 and 960 ms respectively. Sound and board sparks share that exact release boundary.
The collection transaction finishes 240 ms later, while its noninteractive
sparks continue. Lv4's secondary blossoms open 280, 406 and 532 ms after the
main explosion. Radial speed decays, then gravity visibly curves the sparkling
trails downward. Saturated tips and persistent tapered texture trails keep the
colored flowers readable against the bright sky and neighboring gel skins.

The effects reuse the acquired particle artwork below. There is no opaque
screen overlay, camera shake, new hit target or reward callback. Radius, spark
count and composition increase through the nine levels. Batch collection retains
its 40 ms release within each 140 ms beat; board effects use 75 percent of their
manual lifetime, 66 percent of their radius and, for fireworks, 45 percent of
their sparks. At most twelve effects coexist. Older effects can be retired when
that pool is full. Reduced motion uses a 420 ms static group of acquired glints
and local light. The owning view supplies the clock and established pause/exit
cleanup; no particle timer advances gameplay.

## Collected-word popup

The picture-and-spelling card appears as soon as collection is accepted. It
visibly contracts toward a luminous core as colored sparkle streams converge,
then opens into radial star trails and elastic overshoot at the same release
boundary as the board Jelly and its sound. This applies to every level: a short
180 ms anticipation for Lv1-Lv3, 660/720/780/840/900/960 ms for Lv4-Lv9, and a compact 40 ms
squeeze during each automatic collection beat. The top card reaches 40 percent
width and 50 percent height before its 100 ms outward release, then settles by
470 ms. The complete picture and spelling return to their resting size.

Each card displays one of nine related frame effects. Its reading surface lasts
1.95 seconds individually or 0.86 seconds in batches, reduced to 0.62 seconds
on narrow screens or 0.48 seconds in short regions. At Lv4-Lv9, automatic
collection keeps the popup fireworks alive for 1.95 seconds after release,
independently of the compact picture-and-spelling card. The text fades on its
original schedule while the noninteractive sparks continue, then the retained
effect entry is removed. Lv1-Lv3 keep their existing compact batch effects.

| Level | Popup signature |
| --- | --- |
| 1 | Pearl greeting: mint starburst, glints and local light |
| 2 | Crystal ripple: radial release and two cyan sparkle waves |
| 3 | Sapphire spiral: sapphire, cyan and rose star trails around the reading card |
| 4 | Golden fireworks: three gold, cyan and rose blooms with radial trails |
| 5 | Double cascade: four rose/gold blooms with falling embers |
| 6 | Prismatic bouquet: six multicolor blossoms and broad falling trails |
| 7 | Aurora crown: seven violet and mint blooms across an upper arc |
| 8 | Constellation shower: eight gold, cyan and rose blooms in staggered pairs |
| 9 | Grand bouquet: nine multicolor blooms with the richest falling trails |

Popup blossom releases span 0.16, 0.38 and 0.48 seconds at Lv4-Lv6 for both manual
and automatic collection. Their trails use five, six and seven trajectory samples
respectively. Lv7-Lv9 release across 0.52, 0.57 and 0.62 seconds, using eight,
eight and nine trail samples. Automatic collection keeps 62 percent of the manual spark count
and its compact reading-card dimensions and margins. Lv4-Lv9 use the same bloom
geometry in both collection modes, independently of those reading-card margins,
so consecutive fireworks can overlap without shortening their bloom or descent.
The 140 ms collection cadence is unchanged. Each effect respects the existing
control exclusions. Reduced
motion uses static colored stars and local light through the effect's lifetime;
the reading card still fades on its own schedule. Pause, late-frame catchup,
resize and exit use the existing presentation clock.
No additional artwork or audio was acquired for the Lv9 extension.

The top-card charge update reuses the same three acquired textures, re-inspected
over a dark backing before implementation. Only texture placement, tint, scale,
opacity and timing changed; their source, creator, license and acquisition
status remain in the table below. The core glow, inward streams and outward
trails are runtime animation of these static production textures.

The wider Lv4-Lv9 popup fireworks use a separate cosmetic canvas, leaving card
size, placement and reading time intact. Their blossom radii target 116, 148,
184, 212, 244 and 280 display pixels respectively. Their responsive width caps
are 30, 32.5, 35, 37.5, 40 and 42.5 percent, preserving a different bloom size
for every tier even on phones. Manual and automatic collection share these radii; compact reading cards
no longer reduce the firework's size. On short canvases, the vertical trajectory
uses `min(1, canvas height / (bloom radius * 2.4))`, preserving the broad horizontal
spread. All launch sites share the collected card's actual center: the wider
canvas provides room for outward trails, not independent screen-space flowers.
The board release likewise anchors every delayed layer to the collected body's
center. Lv7 retains violet/mint layers, Lv8 four staggered color pairs, and Lv9
nine rich multicolor layers. Individual texture stamps still fit the canvas and
live-control exclusions.
Spark tips and tapered trail stamps use a 1.5 size multiplier over the original
fireworks version. Drag slows the outward release before gravity bends even the
upward spokes down; short samples of that path form tapered trails instead of
keeping each ember tied to its burst origin.
Each ember lives for up to 1.72 seconds, limited by the remaining effect time
after its blossom delay and an 80 ms end margin. Manual and automatic fireworks
use the same descending path and later fade; only the automatic spark density
is reduced. The full 1.95-second effect lifetime lets falling tails finish after
compact reading cards disappear.

The cosmetic canvas extends through up to 86 percent
of the playfield height or 680 display pixels; short landscape layouts retain at least
their reading region. This gives lower blossoms room to fall past the old card
halo. Every rotated texture stamp respects the existing control exclusions,
and all fireworks draw behind all live reading surfaces during rapid pickups.
The chest unlock prompt also stays above the enlarged fireworks. Finish, Collect,
the combo badge and both purchase buttons remain explicit effect exclusions.
Reduced motion keeps the existing still light and stars. The wider-canvas
fitting changes no source texture, sound, collection cadence or reward rule.

## Collection blast marks and automatic flights

The [gameplay footprint table](../gameplay.md#collection-blast-matching) defines
Lv1 direct collection, random local Lv2-Lv4 targets, Lv5 column, Lv6 cross,
Lv7 one ring, Lv8 capped two rings and Lv9 the board. Only a successfully saved
collection queues the reaction. The model captures exact body IDs; missing,
held, fusing and promised batch pickups are not cosmetic substitute targets.

The acquired portal light, radial rays and four-point sparkle gather at the
collected body's actual position. Board motion and ambient Jelly effects run at
0.12 speed during marking; no global engine time scale is changed. An 80 ms
windup precedes accelerating 260 ms outward bolts with five tapered texture
samples. Up to six groups launch 60 ms apart, nearer bodies first. Each impact
marks its body and requests audio on arrival, never at launch. The last impact
ends slow motion immediately, followed by a 100 ms normal-speed planted recovery
before the established automatic 250 ms journeys and ordinary short union.
Targets compress by up to 22 percent around their existing foot pivot and
support shadow, then rebound by up to six percent without bobbing or camera
shake. Reduced motion uses still source/target marks, no traveling light or
deformation, and the established simplified matching flight.
Batch pickups retain their 140 ms cadence and coalesce overlapping marks before
matching; one bounded sequence consumes each original endpoint at most once.
Neither the visual layer nor audio decides a match, pays coins, changes item
prices or records learning.

The source wave reuses acquired `chest-kenney/settle.wav` at gain 0.55, and marking
impacts reuse `chest-kenney/step-detail.wav` at gain 0.36, both at original pitch.
Their recorded material attacks replace the light combo chimes without altering
the collection or combo recordings. Kenney's `impactWood_medium_002.ogg` and
`impactWood_light_004.ogg` are from Impact Sounds 1.0; the latter impact also
contains `metalLatch.ogg` from RPG Audio. All are CC0 1.0, previously acquired
from the user's local collection and already integrated. These are audio-only
one-shots, not animation clips; sources, licenses, processing and unchanged
output hashes remain in [the Kenney chest manifest](chest-kenney-audio.json).
Marking is a secondary cue and does not replace an occupied gameplay channel.
No new artwork or audio was acquired; the three actual textures were
re-inspected together over a dark backing before this reuse.

The centered-firework presentation keeps the existing collection sound bank.
No additional top-popover firework recording or sound request is included.

## Acquired material

The three existing production particle textures were inspected in a local source
sheet before reuse. They remain authored artwork; the runtime only places,
rotates, scales and fades texture stamps. No drawn geometry replaces particle
art, and no additional Unity package was acquired.

| Material | Source, creator and license | Acquisition and animation |
| --- | --- | --- |
| Portal wisps | `Particles/Textures/portal_glow.png` from Modern 2D Animated Chests Pack_FREE Demo 1.0.2, Bobardo; Standard Unity Asset Store EULA | Previously acquired and integrated. Static texture, reused for local light. Original mapping: `assets/chests/SOURCE.txt` and `assets/chests/manifest.json`; inherited source-rights record: [Jelly fragments](jelly-fragments.md). |
| Radial rays and four-point sparkle | Toon FX 1.52, Kenneth Foldal Moe / Archanor VFX, [official product 25601](https://assetstore.unity.com/packages/vfx/particles/toon-fx-25601); [Standard Unity Asset Store EULA](https://unity.com/legal/as-terms) | Previously acquired private `glowlines.png` and `sparkle.png`, integrated byte-for-byte under `assets/chests/milestone/`. Static textures; trajectories are authored in the game. Source hashes and acquisition evidence remain in [Jelly fragments](jelly-fragments.md#extra-motion-textures). These private inputs ship only inside the compiled game. |
| Fixed bubble pop | farfadet46, [bubbles 'pop'](https://opengameart.org/content/bubbles-pop), CC0 1.0 | Existing approved 100 ms `collect-pop.wav` remains byte-identical; the same sample is the transient in higher-level mixes. Original OGG, adaptation and source license are in [the collection manifest](jelly-collection-audio.json). |
| Glass, confirmation and rise recordings | Kenney [Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds), CC0 1.0 | Acquired from the user's existing local All-in-1 3.7.0 collection. Complete `glass_004.ogg`, `glass_006.ogg`, `confirmation_003.ogg` and `maximize_007.ogg` are preserved with the original license in `docs/assets/sources/jelly-level-feedback/`. Audio-only one-shots; adapted and layered into Lv2-Lv9 WAVs. All nine recordings are active; Lv7-Lv9 were reverified and reactivated without changing their bytes. |
| Bell body | Kenney [Impact Sounds 1.0](https://kenney.nl/assets/impact-sounds), CC0 1.0 | Complete `impactBell_heavy_002.ogg` and the source license acquired from the same local collection and preserved with the other originals. Audio-only one-shot, adapted and layered into milestone cues. |

Exact source hashes, output hashes, layer offsets, resampling ratios, source
identity and PCM measurements are in [the manifest](jelly-level-feedback.json).
The asset generator decodes floating-point audio, removes boundary silence,
applies short smooth fades and mixes only recorded source material. Higher
levels differ in timbre, rhythm, pitch and layer structure; their gain is fixed.
No oscillator, synthetic placeholder tone, voice or soundtrack extraction is
introduced. Audio imports must preserve pitch, disable normalization/looping and
use the existing mute, speech ducking and pause/exit cleanup.

The outputs reserve headroom even for twelve pickups spaced 120 ms apart,
faster than the current 140 ms automatic collection rhythm.
Every level starts promptly, has zeroed boundaries, and is mono 44,100 Hz PCM16.
The existing Lv1 pop retains its own approved peak; higher cues have a maximum
solo peak of -8.5 dBFS and a repeated-batch ceiling below 0.78 at runtime gain 0.90.
Active gameplay uses `pop` for Lv1 and `jelly-collect-lv2` through
`jelly-collect-lv9` for the other eight levels, at original runtime pitch 1.0.
Combo increments use a separate bounded pool of rising accents described in
[Jelly Words combo audio](jelly-combo-audio.md); these level recordings are unchanged.
Lv7-Lv9 retain their existing source layers and hashes and are included in the
active registry and startup pack. Eight protected higher-level audio
channels preserve the longest tail through 120 ms batch pickups; board contact
and warning cues keep their existing separate three-channel pool. Both pools
share the established stop, mute and pronunciation-duck behavior. The importer
explicitly disables Godot WAV compression to preserve the authored PCM.

## Reproduction and review

```powershell
python tools/prepare-jelly-level-audio.py --check
node tools/run-godot.cjs --headless --path . --script res://tests/godot/word_jelly_collection_fx_tests.gd
node tools/run-godot.cjs --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --audio-driver Dummy --disable-vsync --max-fps 30 --resolution 1440x740 --script res://tools/capture-word-jelly-levels.gd -- --frames
node tools/run-godot.cjs --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --audio-driver Dummy --disable-vsync --max-fps 30 --resolution 1366x768 --script res://tools/capture-word-jelly-reveals.gd
node tools/run-godot.cjs --path . --script res://tools/capture-word-jelly-fireworks.gd
```

The audio check validates all preserved source/output hashes for nine active cues. Running `tools/prepare-jelly-level-audio.py`
without `--check` reproduces the original nine recordings and the
`build/jelly-level-feedback/levels-1-through-9.wav` listening preview; it does
not add levels to gameplay. The generator retains current runtime metadata.
The Lv1 file remains byte-identical to the approved recording.

The board harness writes to `build/jelly-level-feedback/nine-levels/`. It renders
a nine-level sheet, nine Lv4 timeline samples through 2.75 seconds, three portrait
phase samples, reduced motion and a nine-release batch. `--frames` adds 105 silent
30 fps frames comparing Lv1, Lv4 and Lv6. The sheet deliberately retains the
ordinary Jelly as a size reference; individual release samples remove it.
These are native production-texture studies, separate from end-to-end input
and audio evidence.

The popup harness writes to `build/jelly-reveal-feedback/nine-levels/` and uses
real `WordRevealCard`, `WordReveal` and `WordJelly` controls with the acquired
cat/apple artwork and sky/garden backdrop. It records a nine-level sheet, Lv4/Lv9
timelines, 1366 x 768 desktop, 390 x 844 portrait and 844 x 390 landscape fixtures,
normal/reduced motion, and 140 ms batches. Its silent frames compare Lv1/Lv4/Lv6
and all nine batch releases. `--batch-only` renders just the four small-screen
batch studies. `--baseline` captures the currently checked-out version; capture
it before edits or against an older revision for a true before/after comparison.

The focused effect suite verifies nine profiles, release synchronization,
late-frame catchup, long firework phases, radial deceleration and ember descent,
input transparency, bounded pooling, reduced motion and cleanup. The texture
source sheet was re-inspected for this update. Automated audio measurements do
not establish subjective timbre or physical-device mixing; the unchanged audio
still requires actual playback for those judgments.

The six-level board study completed 120 native captures without renderer errors
on 2026-10-24. The level sheet, Lv4 blossom and late-descent stills, portrait
samples at 0.55, 1.80 and 2.40 seconds, batch and reduced-motion samples were
inspected. The first phone pass exposed undersized, faint ember tips; larger
saturated texture stamps, longer tapered trails and a later fade made the
colored bloom and descent readable in the same scene. The focused effect suite
passed 101 checks after that adjustment. These stills and deterministic frame
sequences establish sampled appearance and timing, not physical-device motion
or an audio playback review.

The integrated fireworks harness writes 148 silent production-view samples to
`build/qa/six-level-jelly/`, including 121 phone frames at 30 fps from contraction
through ember descent, desktop, reduced motion and batch fixtures. It drives
the actual collection clock with a deterministic board. Pending fireworks also
follow layout changes during charge, without resetting their release clock;
already released tails keep their existing position.

The top-card anticipation study uses
`tools/capture-word-jelly-top-charge.gd -- --frames` with the same native renderer
options above. It writes to `build/qa/top-jelly-charge/after/`: 144 sampled states
for Lv3 and Lv6 across desktop, portrait and landscape, manual/batch/reduced
motion, plus two 91-frame portrait sequences at 30 fps. `--baseline` saves the
currently loaded implementation in a separate baseline directory. For the
2026-10-24 comparison, 144 true baseline states were rendered from isolated
copies of revision `70498eac`; the current scripts stayed in place.

The before/after charge and burst samples, batch layouts and reduced-motion
layouts were inspected. Lv3 reaches 59 percent width at 120 ms and Lv6 reaches
41 percent at 720 ms; both peak at 117 percent width and 120 percent height
100 ms after release. Reduced-motion samples keep the original scale. These
silent native samples verify composition and sampled timing, not physical-device
performance or audio. The focused reveal, full view, hybrid view, application
flow and level-audio suites passed after the update.

The 2026-10-25 automatic-collection study is saved under
`build/qa/jelly-auto-collect-fx-2026-10-25/`. It compares 138 matched native
states per version across desktop, portrait and short landscape, including
Lv4-Lv6 and twelve consecutive high-level pickups. Falling top tails remain
visible at 1.5 seconds and leave no visible effect at 1.95 seconds. Gameplay,
board effects, controls and shared reading-card geometry match the baseline.
The reveal, view, hybrid, flow and model suites passed 145,071 checks; their
logs are in `build/qa/jelly-batch-fireworks-2026-10-25/`. These are silent native
samples, with no physical-device performance or audio-playback claim.
The exported Web build also passed 43 export checks and the real-input Collect
regression in desktop Chromium and Android Chromium emulation. Both browser
cases retained the Lv6 top tail after its reading card disappeared, then
removed it without additional rewards; artifacts are in the study's `browser/`
directory.

The larger-bloom follow-up is saved under
`build/qa/jelly-firework-scale-2026-10-25/`, with 174 matched native states per
version. At release +1.1 seconds, the isolated Lv6 portrait automatic-firework
mask grows from 254 by 173 to 296 by 289 pixels, with 2.17 times the painted
pixels. Manual petals and cascade height also grow; fitted launch centers mean
the complete bouquet is not uniformly wider in every layout. The same-input
comparison preserves gameplay and reading-card geometry. Reduced-motion frames
are unchanged, and the chest prompt remains above the enlarged fireworks.
The focused reveal, view and collection-effect suites passed 33,130 checks;
logs are in `build/qa/jelly-firework-size-2026-10-25/`. The capture report records
the pixel-mask method and source hashes; these are silent native samples.
The final Web build passed the existing Lv6 manual-collection regression in
desktop Chromium and the Collect regression in Android Chromium emulation.
Their inspected top-tail screenshots show the larger bouquets at about 1.17
seconds. The automatic case still collects two words in 280 ms, retains the
1.95-second effect lifetime and removes the effects without extra rewards.
Browser screenshots and geometry snapshots are in the study's `browser/`
directory, with `browser.log` and a compact `browser-summary.json` alongside it.

## Historical nine-level evidence

The former nine-level board and popup studies remain in their original output
directories outside `six-levels/`. They include the original board suite's 87
checks, the original audio suite's 104 checks, the 203-capture popup study and
older 350, 250 and 200 ms batch studies. Their counts, nine-level labels and
cadences describe those historical runs. The current nine-level extension
uses the later broad falling fireworks and 140 ms batch timing. The same
Lv7-Lv9 recordings are now active again; no historical preview is presented
as new evidence or as a physical-device audio review.


## Lv7-Lv9 verification, October 25, 2026

The current extension preserves Lv6's existing four-hue popup palette and the
broader radial release with downward-curving trails. Higher levels add distinct
blossom arrangements and bounded detail. Bloom radius grows only until it reaches
the existing cosmetic canvas limit; text, controls and touch targets do not move
to make room. The top effect lasts 1.95 seconds after release in manual and
automatic collection. Its card still fades on the original reading schedule.
Board effects retain their bounded twelve-entry pool, so older local effects
may retire when that pool fills; the top card fireworks and audio use separate
lifetimes and pools.

`tools/capture-word-jelly-fireworks.gd -- --high-levels` captures 74 native phases
at 390 x 844 and 1000 x 720: Lv7, Lv8 and Lv9, plus a three-word automatic
collection and reduced motion. Evidence is retained in
`build/qa/jelly-lv9-2026-10-25/`. These are sampled native production views,
not physical-device recordings. The source texture sheet was inspected before
the existing portal, rays and sparkle artwork were reused.

Focused native checks passed: 188 board-effect, 14,911 reading-popup, 105 level
audio and 36 tile-performance assertions. All nine audio resources retain their
recorded hashes. Lv7-Lv9 each peak at -8.5 dBFS solo; their repeated 120 ms mixes
peak at -8.422, -9.244 and -9.415 dBFS. The longest tail is 0.937279 seconds,
shorter than the protected channel's 1.12-second reuse interval during automatic
collection. Combined 24-pickup/combo mixes at 140 ms were checked for every
level from Lv4 through Lv9; the highest peak is -5.848 dBFS. No audio bytes,
authored gain or pitch changed. These measurements do not establish subjective
listening quality or physical-device mixing.
