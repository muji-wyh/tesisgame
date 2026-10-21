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

The outputs reserve headroom for twelve pickups at the real 120 ms batch spacing.
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
