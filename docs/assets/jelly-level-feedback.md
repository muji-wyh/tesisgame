# Jelly Words level collection feedback

All merged words use the ordinary one-cell Jelly body. Their collection feedback
has nine profiles, driven by the existing accepted collection pop boundary.
Effects never grant rewards or delay control. The main peak starts at the same
release as its sound; the light and sparks then recover independently of the
model's collection transaction.

| Level | Visual signature | Audio signature |
| --- | --- | --- |
| 1 | Small pearl-like sparkle pop | The unchanged, user-approved fixed bubble pop |
| 2 | Two concentric sparkle releases | Bubble pop with one short glass accent |
| 3 | A rising spiral and local radial light | Bubble pop, rising interface accent and glass tail |
| 4 | Firework bloom: rapid radial release, ember trails and falling sparks | Bubble pop, soft bell bloom and staggered glass crackles |
| 5 | Two staggered blooms | Two glass releases at different pitches |
| 6 | An upward comet crown with descending trails | Rising accent, bell body and four ascending glass details |
| 7 | Counter-rotating aurora orbits | Two overlapping glass colors and a chime answer |
| 8 | Three constellation blooms and a falling shower | Bell body with a three-part chime response |
| 9 | Central firework, four satellite blooms and dense star trails | Layered bell/chime bouquet followed by a staggered glass tail |

Radius, spark density and composition increase across levels. The celebration
stays near the collected Jelly, with no camera shake, opaque overlay, modal or
new hit target. The render scale follows the view's physical UI scale. Small
regions fit the effect radius; batch collection retains each signature at lower
density, shorter duration and a smaller radius. At most twelve effects coexist.
Reduced motion shows a brief, static group of acquired glints and a local glow;
the level cue and reward remain unchanged. The owning view supplies the clock,
freezes it during pause and resets it when leaving or restarting the round.

## Collected-word popup

The reading popup now receives the accepted Jelly's merge level. The board's
collection release and the popup are two views of the same collection event;
neither owns rewards or advances gameplay. The picture and spelling retain their
opaque, readable surface while acquired light and star textures celebrate around
its perimeter. Color, layered releases, movement pattern and star density grow
across the nine levels, including the required firework identity at Lv4.

| Level | Popup signature |
| --- | --- |
| 1 | Pearl greeting: mint glints and a gentle local light |
| 2 | Crystal ribbon: cyan stars around the frame |
| 3 | Sapphire spiral: blue stars turn around the reading card |
| 4 | Golden fireworks: staggered gold blooms with bright spark cores |
| 5 | Rose cascade: three pink releases and falling tails |
| 6 | Comet coronation: a rising crown of cyan and green sparks |
| 7 | Aurora embrace: contrasting colors travel in opposite directions |
| 8 | Starlight festival: five constellation releases with longer star trails |
| 9 | Prismatic finale: six multicolor blooms, bright cores and dense trailing stars |

The popup uses the existing reading lifetime: 1.95 seconds for individual
collections, 0.86 seconds for batches, shortened to 0.62 seconds on narrow
screens and 0.48 seconds in short regions. Batch effects reach their peak sooner
and reduce their density to preserve the 250 ms automatic collection rhythm.
Placement reserves the animated card and its level-specific effect halo while
respecting the existing control exclusions. Reduced motion keeps a static,
colored star setting and light around the same picture and spelling.

Popup effects share the owning card's elapsed time, so pause, late-frame catchup,
resize and exit follow the established reveal lifecycle. The effect has no hit
target or independent timers. This addition reuses the existing visual textures
listed below and introduces no additional asset or audio acquisition. Existing
collection sounds and their timing remain unchanged.

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
| Glass, confirmation and rise recordings | Kenney [Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds), CC0 1.0 | Acquired from the user's existing local All-in-1 3.7.0 collection. Complete `glass_004.ogg`, `glass_006.ogg`, `confirmation_003.ogg` and `maximize_007.ogg` are preserved with the original license in `docs/assets/sources/jelly-level-feedback/`. Audio-only one-shots; adapted and layered into Lv2-Lv9 WAVs. |
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
faster than the current 250 ms automatic collection rhythm.
Every level starts promptly, has zeroed boundaries, and is mono 44,100 Hz PCM16.
The existing Lv1 pop retains its own approved peak; higher cues have a maximum
solo peak of -8.5 dBFS and a repeated-batch ceiling below 0.78 at runtime gain 0.90.
They use `pop` for Lv1 and `jelly-collect-lv2` through `jelly-collect-lv9` for the
other levels, at original runtime pitch 1.0. Eight protected higher-level audio
channels preserve the longest tail through 120 ms batch pickups; board contact
and warning cues keep their existing separate three-channel pool. Both pools
share the established stop, mute and pronunciation-duck behavior. The importer
explicitly disables Godot WAV compression to preserve the authored PCM.

## Reproduction and review

```powershell
python tools/prepare-jelly-level-audio.py --check
python tools/prepare-jelly-level-audio.py
```

The first command validates existing sources and output hashes without editing.
The second regenerates the eight level cues and an isolated listening preview
at `build/jelly-level-feedback/levels-1-through-9.wav`. Its levels appear in
ascending order every two seconds. This is an asset mix, separate from the
engine's speech/music mix. To restore originals, add `--acquire-from` with the
existing Kenney collection's `Audio` directory; unexpected hashes fail.

`tests/godot/word_jelly_collection_fx_tests.gd` covers distinct levels, the Lv4
firework requirement, pop synchronization, late batch frames, input transparency,
bounded pooling, reduced motion and cleanup.
`tests/godot/word_jelly_level_audio_tests.gd` covers per-level asset identity,
nonlooping PCM import, original runtime pitch, protected channels, speech duck,
mute/pause/exit cleanup and cancellation during delayed resource preparation.
`tools/capture-word-jelly-levels.gd`
creates a nine-level sheet, five Lv4 timeline frames and ordinary six-column
phone-scale and reduced-motion studies from real WordTile controls. These are
isolated native-rendered studies, separate from end-to-end gameplay evidence.

Source texture appearance and audio identity, waveform, onset, headroom and
batch overlap have been inspected. Automated audio measurements do not establish
subjective timbre or physical-device mixing; the listening preview supports the
user's requested later tuning.

The native effect harness produced all eight planned captures, including the
five Lv4 phases and both phone-scale states. The nine-level sheet was inspected
at its exported size: the later profiles retain separate colored trajectories,
and the production Jelly reference stays at one ordinary cell. The effect
lifecycle suite passed 87 checks and the level audio suite passed 104 checks,
including an explicit PCM-import check that caught and corrected Godot's default
WAV compression. These still studies do not establish normal-speed feel or
subjective acoustic quality.

### Popup reproduction

The popup harness uses the real `WordRevealCard`, `WordReveal` and `WordJelly`
controls with production cat/apple artwork and the game's acquired sky/garden
backdrop. It writes only to the ignored `build/jelly-reveal-feedback/` directory.
The `--baseline` option records the card from the checked-out source, so it must
be run before edits or against an older revision to capture the old appearance.
The regular run preserves those files and writes matching `after-*` captures.

```powershell
node tools/run-godot.cjs --path . --rendering-method gl_compatibility --rendering-driver opengl3_angle --audio-driver Dummy --disable-vsync --max-fps 30 --resolution 1366x768 --script res://tools/capture-word-jelly-reveals.gd
ffmpeg -y -framerate 30 -i build/jelly-reveal-feedback/animation/frame-%03d.png -c:v libx264 -pix_fmt yuv420p build/jelly-reveal-feedback/popup-levels-normal-speed.mp4
ffmpeg -y -framerate 30 -i build/jelly-reveal-feedback/batch-animation-250ms/frame-%03d.png -c:v libx264 -pix_fmt yuv420p build/jelly-reveal-feedback/popup-batch-250ms.mp4
```

The output includes one nine-level sheet, eight timeline samples each for Lv4
and Lv9, matching desktop/phone comparisons, and full fixture boards at
1366 x 768, 390 x 844 and 844 x 390. Each board is captured with normal and
reduced motion, both individually and at the current collection rhythm from
`WordJellyModel.BATCH_BEAT_SECONDS` (250 ms).
Deterministic 30 fps frame sequences compare Lv1/Lv4/Lv9 and show all nine
levels arriving 250 ms apart on the portrait fixture. Batch output filenames
include the interval so earlier cadence studies remain available. Add
`-- --batch-only` to render just portrait and short landscape batch stills in
normal and reduced motion, with a separate interval-labeled report.
These are silent native
render studies with explicit board state, not recordings of user input or the
browser/audio mix. Review geometry and effect state in `render-report.json`.

The original popup run at the former 350 ms cadence completed 203 captures
without renderer errors: 31 stills and
172 animation frames. The original desktop/portrait card, nine-level sheet,
Lv4/Lv9 timeline phases, portrait and short landscape fixtures, batch frames and
reduced-motion stills were visually inspected. The final Lv9 popup has six
separated radial blooms, colored side lighting and a second rim-star wave;
the picture and word remain readable. Short landscape placement keeps the
effect clear of the Finish button, and reduced motion retains a static star
setting. Encoded silent previews were checked at 30 fps: 64 frames / 2.133 seconds
for the level comparison and 108 frames / 3.6 seconds for the original portrait
batch. Those earlier batch frames and the `popup-batch-350ms.mp4` preview remain
historical evidence of the 350 ms cadence.
These checks establish rendered appearance and frame timing, not physical-device
audio mixing or an end-to-end browser interaction recording.

After changing the cadence to 250 ms, the focused batch study produced four
fresh native captures without renderer errors: 390 x 844 and 844 x 390, each
with normal and reduced motion. Both overlapping word cards remain readable in
portrait, and the fading previous card stays separate from the incoming card in
short landscape. Effects remain clear of Finish. These current-cadence stills
and their elapsed-time snapshots are recorded in
`batch-250ms-render-report.json`; the historical 350 ms video was not reused as
evidence for the faster cadence.
