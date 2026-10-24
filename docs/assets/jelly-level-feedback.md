# Jelly Words level collection feedback

Merged words have six levels and keep the ordinary one-cell Jelly body. Matching
words add their levels, including unequal pairs; results greater than Lv6 are
ineligible. Their collection feedback uses one accepted model release for the
body disappearance, board effect and sound. Presentation never grants rewards.
The existing Lv1-Lv6 recordings and reward values remain unchanged.

| Level | Board effect | Post-release lifetime | Existing audio signature |
| --- | --- | --- | --- |
| 1 | Pearl pop: compact mint sparkle release | 0.80 s | Approved fixed bubble pop |
| 2 | Twin ripple: two concentric cyan releases | 1.10 s | Bubble pop with a short glass accent |
| 3 | Spiral lift: rising sapphire curl | 1.45 s | Bubble pop, rising interface accent and glass tail |
| 4 | Firework bloom: gold spokes, three colored blossoms, descending embers | 2.80 s | Bubble pop, bell bloom and staggered glass crackles |
| 5 | Rose cascade: staggered pink and gold blossoms in two descending pairs | 3.10 s | Two glass releases at different pitches |
| 6 | Prismatic bouquet: a central release and six surrounding colored blossoms | 3.40 s | Rising accent, bell body and ascending glass details |

Manual Lv1-Lv3 collections release at 180 ms. Lv4-Lv6 first contract the actual
painted Jelly, gather light at its core and build to release at 660, 720 and
780 ms respectively. Sound and board sparks share that exact release boundary.
The collection transaction finishes 240 ms later, while its noninteractive
sparks continue. Lv4's secondary blossoms open 280, 406 and 532 ms after the
main explosion. Radial speed decays, then gravity visibly curves the sparkling
trails downward. Saturated tips and persistent tapered texture trails keep the
colored flowers readable against the bright sky and neighboring gel skins.

The effects reuse the acquired particle artwork below. There is no opaque
screen overlay, camera shake, new hit target or reward callback. Radius, spark
count and composition increase through the six levels. Batch collection retains
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
180 ms anticipation for Lv1-Lv3, 660/720/780 ms for Lv4-Lv6, and a compact 40 ms
squeeze during each automatic collection beat. The top card reaches 40 percent
width and 50 percent height before its 100 ms outward release, then settles by
470 ms. The complete picture and spelling return to their resting size.

Each card displays one of six related frame effects. Its reading surface lasts
1.95 seconds individually or 0.86 seconds in batches, reduced to 0.62 seconds
on narrow screens or 0.48 seconds in short regions. At Lv4-Lv6, automatic
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
| 6 | Prismatic bouquet: six multicolor blossoms and the richest trails |

Popup blossom releases span 0.16, 0.38 and 0.48 seconds at Lv4-Lv6 for both manual
and automatic collection. Their trails use five, six and seven trajectory samples
respectively. Automatic collection keeps 62 percent of the manual spark count
and its compact reading-card dimensions and margins. Lv4-Lv6 use the same bloom
geometry in both collection modes, independently of those reading-card margins,
so consecutive fireworks can overlap without shortening their bloom or descent.
The 140 ms collection cadence is unchanged. Each effect respects the existing
control exclusions. Reduced
motion uses static colored stars and local light through the effect's lifetime;
the reading card still fades on its own schedule. Pause, late-frame catchup,
resize and exit use the existing presentation clock.
No additional artwork or audio was acquired for the six-level update.

The top-card charge update reuses the same three acquired textures, re-inspected
over a dark backing before implementation. Only texture placement, tint, scale,
opacity and timing changed; their source, creator, license and acquisition
status remain in the table below. The core glow, inward streams and outward
trails are runtime animation of these static production textures.

The wider Lv4-Lv6 popup fireworks use a separate cosmetic canvas, leaving card
size, placement and reading time intact. Their blossom radii target 72, 92 and
116 display pixels respectively, capped at 28 percent of the cosmetic canvas
width. Manual and automatic collection share these radii; compact reading cards
no longer reduce the firework's size. On short canvases, the vertical trajectory
uses `min(1, canvas height / (bloom radius * 3.3))`, preserving the broad horizontal
spread. Launch centers fit the canvas using the bloom radius and vertical scale.
Spark tips and tapered trail stamps are 30 percent larger than the preceding
fireworks version. Drag slows the outward release before gravity bends even the
upward spokes down; short samples of that path form tapered trails instead of
keeping each ember tied to its burst origin.
Each ember lives for up to 1.72 seconds, limited by the remaining effect time
after its blossom delay and an 80 ms end margin. Manual and automatic fireworks
use the same descending path and later fade; only the automatic spark density
is reduced. The full 1.95-second effect lifetime lets falling tails finish after
compact reading cards disappear.

The cosmetic canvas extends toward the middle of the playfield, up to 58 percent
of its height or 440 display pixels; short landscape layouts retain at least
their reading region. This gives lower blossoms room to fall past the old card
halo. Every rotated texture stamp respects the existing control exclusions,
and all fireworks draw behind all live reading surfaces during rapid pickups.
The chest unlock prompt also stays above the enlarged fireworks.
Reduced motion keeps the existing still light and stars. Board effects, source
textures, sound, collection cadence and reward rules are unchanged.

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
| Glass, confirmation and rise recordings | Kenney [Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds), CC0 1.0 | Acquired from the user's existing local All-in-1 3.7.0 collection. Complete `glass_004.ogg`, `glass_006.ogg`, `confirmation_003.ogg` and `maximize_007.ogg` are preserved with the original license in `docs/assets/sources/jelly-level-feedback/`. Audio-only one-shots; adapted and layered into Lv2-Lv9 WAVs. Lv2-Lv6 remain active; Lv7-Lv9 recordings are retained as historical assets. |
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
`jelly-collect-lv6` for the other five levels, at original runtime pitch 1.0.
Combo increments use a separate bounded pool of rising accents described in
[Jelly Words combo audio](jelly-combo-audio.md); these level recordings are unchanged.
Former Lv7-Lv9 recordings, layer recipes and hashes remain in the manifest as
archived acquisition evidence; they are absent from the active Jelly cue registry. Eight protected higher-level audio
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

The audio check validates all preserved source/output hashes: six active cues
and three archived recordings. Running `tools/prepare-jelly-level-audio.py`
without `--check` reproduces the original nine recordings and the historical
`build/jelly-level-feedback/levels-1-through-9.wav` listening preview; it does
not add levels to gameplay. The generator retains current runtime metadata.
The Lv1 file remains byte-identical to the approved recording.

The board harness writes to `build/jelly-level-feedback/six-levels/`. It renders
a six-level sheet, nine Lv4 timeline samples through 2.75 seconds, three portrait
phase samples, reduced motion and a six-release batch. `--frames` adds 105 silent
30 fps frames comparing Lv1, Lv4 and Lv6. The sheet deliberately retains the
ordinary Jelly as a size reference; individual release samples remove it.
These are native production-texture studies, separate from end-to-end input
and audio evidence.

The popup harness writes to `build/jelly-reveal-feedback/six-levels/` and uses
real `WordRevealCard`, `WordReveal` and `WordJelly` controls with the acquired
cat/apple artwork and sky/garden backdrop. It records a six-level sheet, Lv4/Lv6
timelines, 1366 x 768 desktop, 390 x 844 portrait and 844 x 390 landscape fixtures,
normal/reduced motion, and 140 ms batches. Its silent frames compare Lv1/Lv4/Lv6
and all six batch releases. `--batch-only` renders just the four small-screen
batch studies. `--baseline` captures the currently checked-out version; capture
it before edits or against an older revision for a true before/after comparison.

The focused effect suite verifies six profiles, release synchronization,
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
cadences describe those historical runs, not the current six-level game.
Former Lv7-Lv9 recordings and their source/layer/hash records are retained in
the JSON manifest as archived assets. No historical preview is presented as a
new six-level screenshot, a current gameplay recording or a physical-device
audio review.
