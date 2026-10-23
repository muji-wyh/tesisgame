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

The picture-and-spelling card shares the accepted collection event and displays
one of six related frame effects. It retains its opaque reading surface and
existing lifetime: 1.95 seconds individually, 0.86 seconds in batches, reduced
to 0.62 seconds on narrow screens or 0.48 seconds in short regions. The board
owns the extended falling tails; the card can finish independently.

| Level | Popup signature |
| --- | --- |
| 1 | Pearl greeting: mint glints and local light |
| 2 | Crystal ripple: two cyan sparkle waves |
| 3 | Sapphire spiral: blue stars around the reading card |
| 4 | Golden fireworks: two gold blooms with short radial trails |
| 5 | Double cascade: four rose/gold blooms with falling embers |
| 6 | Prismatic bouquet: six multicolor blossoms and the richest trails |

Manual popup blossom releases span 0.16, 0.38 and 0.48 seconds at Lv4-Lv6.
Batch releases use `0.075 + level * 0.007` seconds, at most 117 ms, preserving
the 140 ms cadence. Each card reserves its own effect halo and respects the
existing control exclusions. Reduced motion keeps static colored stars and
light. Pause, late-frame catchup, resize and exit use the card's existing clock.
No additional artwork or audio was acquired for the six-level update.

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
