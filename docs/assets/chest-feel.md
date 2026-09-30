# Eight-world chest performance

The chest uses a 5-second performance: 1.2 seconds of initial pressure followed
by 3.8 seconds of buildup, opening and settling. Keep holding until the lid
releases 3.36 seconds after the press. That visible release completes input;
letting go preserves the remaining 1.64 seconds of motion, light and sound.
Releasing earlier cancels the performance, stops its sounds and resets progress
while preserving the unopened chest. Reward selection and the save format are
unchanged.

## Motion and timing

`scripts/chest_feel.gd` defines per-world pressure, opening curves, staggering,
spread and decoration. `scripts/chest_view.gd` applies these profiles to derived
Royal/Energy layers and the nine original Crystal parts. Royal lids turn around
the source hinge; the Space cover detaches and floats. Crystal's center unlocks
before its outer facets and reveals an interior cavity. Candy opens in two waves.
Rigid bodies keep their dimensions; Candy intentionally compresses and rebounds.
Body impulses pivot about the base with a short attack and damped return rather
than swinging the sprite around its center. The contact shadow follows that
grounded recoil. Progressive lid pressure and a brightening seam reveal growing
internal force before the lid releases.

The view reserves one measured motion envelope throughout the progress effects
and opening. Local lock/core pressure and the ground shadow respond
inside `begin_hold()`, without waiting for a tween or a network result.
Cancellation clears real progress immediately and returns the pose over 120 ms.
A new hold interrupts that return and starts from zero.

The three stars follow elapsed time up to the lid-release beat. The progress
arc follows it until the final held pose, then completes on release.
There is no visible phase or percentage label; semantic progress remains
available to screen readers. The first star lights just
before the initial hold ends and remains lit as the opening phase begins. Five
holding beats lead into fifteen opening beats. Intervals tighten from 320 ms to
60 ms, and their shared timestamps drive both physical impulses and sounds.
Lock pressure, lid strain, seam light, inward particles and the material loop
rise in intensity. Background music progressively ducks. At opening +1.94 s,
the final roll brakes over 60 ms into a loaded pose. From +2.00 s to +2.16 s,
the chest holds that pose for 160 ms: body, lid strain, shadow, local light and
flowing decoration stop moving while the real progress and input clock continue. Sound takes the
same short breath, quieting the pressure without restarting its source. A tiny
latch clicks inside the hold; the lid then releases immediately at the original
beat. The pause fits inside the existing five seconds.

Release triggers the opening lid, material sound and theme-colored light from
one cue. The flash reaches its crest within 45 ms and expands across the safe
stage extents, with seven broad beams behind the lid, one outward light wave
and twelve long radial streaks. The theme-colored bloom lasts up to 1.02 seconds;
a smaller white core preserves the theme hue and chest silhouette. The progress
crown fades over 160 ms. The light radiates from the opening seam and interior,
while the base and contact shadow preserve the chest's weight.

Hold and opening transitions record their engine-frame origin. Runtime stepping
does not consume the delta from before a press or phase transition, which avoids
early unlocks on slow frames. Deterministic native simulations advance the same
logic through separate step helpers.

`cue_requested(theme_id, cue, step)` is the single performance clock:

| Cue | Time | Consumer |
| --- | --- | --- |
| `press` | Pointer/key/controller hold starts | Contact sound |
| `hold_pulse` | Hold +0.08 s through +1.12 s | Five weighted material beats |
| `charge_step` | 1/3, 2/3, 3/3 of elapsed hold-to-release time | Silent progress stars |
| `cancel` | Release or drag before the lid releases | Stop all performance sounds, brief return sound |
| `opening` | Initial pressure completes at 1.2 s; hold remains active | Continue pressure bed without restarting |
| `tension_pulse` | Opening +0.11 s through +1.86 s | Fifteen accelerating material beats |
| `anticipation` | Opening +1.94 s | Brake for 60 ms, then hold the loaded pose and quiet breath for 160 ms |
| `unlock` | Opening +2.08 s (3.28 s total) | Subtle lock/core sound within the held pose |
| `release` | Opening +2.16 s (3.36 s total) | Complete input; lid, material sound, local theme flash and twelve light streaks |
| `settle` | Opening +2.58 s (3.78 s total) | Material landing sound |
| `opened` | Opening +3.8 s (5 s total), with no further hold required | Save progress before the opened result |

A frame stall consumes expired beats without playing a backlog. A breath cue
more than 80 ms late is skipped; the steady bed still quiets from real progress,
and release stops it. Fast-forward and
explicit new-round settlement remain silent. Backgrounding cancels unreleased
chests and silently settles already released ones. Reduced motion retains the
initial 1.2-second hold and skips the buildup.

`release_reached` marks the irreversible input boundary independently of filtered
sound cues. It is emitted once when the clock crosses the lid-release time, even
if a stalled frame skips that sound. The UI releases input ownership before
disabling the chest button, so its resulting button-up cannot close the chest.
`opened` continues to mark the end of the full physical performance.

The success sound is outside the physical clock: `game_ui.gd` calls it only after
the reward save succeeds. An explicit save retry can acknowledge the newly saved
piece after an interruption, without replaying the opening. Repeated callbacks
cannot grant or announce another piece. New-round auto-claims save the earned
piece silently. Reduced motion skips physical beats and displays the saved result
directly after its shorter hold.

Ordinary chest results show the chest, review cards and next action without a
victory title, instruction or review heading. When vertical space permits, cards
sit below the chest with only their height reserved. Hold instructions and
completion status remain available to screen readers; pending-save and
failed-save messages remain visible.
A toy unlock instead shows **A gift for Pip!** with **Try it with Pip** directly.
Piece counts and medal records still drive persistence and gift requirements,
but the result has no collectible badge, assembly, tap-to-place interaction or
flight to the toolbar. The view owns the release flash and twelve radial light
streaks alongside its existing theme decorations. There is no separate global
release burst or larger post-opening medal celebration.

## Cosmetic gift surprise

After the full opening completes, one random cosmetic gift appears above the
chest: a star, ball, rocket, kite, robot or doll. It follows an upward arc with
rotation and sparkles, then fades within 2.4 seconds. Reduced motion shows the
gift in a fixed position for 1.1 seconds instead of playing the flight.

`assets/chests/surprises/` contains the six small transparent SVGs, derived from
the existing hand-drawn word icons. They retain their outlines, colors and
details; only the pale circular backplate and floor shadow are removed.

This surprise is a temporary visual effect. It has no collectible album,
progress counter or saved storage, and does not change rewards or ownership.
Existing toy unlocks and the **Try it with Pip** action remain independent.

## Original sound bank

`assets/audio/chests/` contains 88 original procedural Foley WAVs (eleven cues per
world), generated by `tools/generate-chest-audio.cjs`. There are no recordings,
external voices, model files or API requests in this sound bank.

| World | Sound ingredients |
| --- | --- |
| Spring | Light wood, filtered leaf noise, short bell resonances |
| Summer | Pressure noise, bright release transient, warm ringing tail |
| Autumn | Lower wood impact, metal clicks, hinge/landing textures |
| Winter | Sparse high resonances, crystal taps and ice tail |
| Ocean | Low-pass pressure, bubble pitch curves, soft water noise |
| Space | Modulated servo tone, magnetic clicks, airlock noise |
| Jungle | Tension modulation, wooden knock, vine/leaf noise |
| Candy | Elastic pitch sweeps, soft impact and small bright rattles |

Each theme includes `press`, `charge`, `step`, `step-detail`, `step-roll`, `cancel`,
`opening`, `unlock`, `release`, `settle` and `reward`. Holding and opening beats
progress from grounded contact through detailed impacts to a bright rolling
texture, keeping a fixed body pitch. The separate pressure texture rises gently
in pitch until anticipation. The 240 ms `opening` clip gathers a short breath,
then falls into a quiet tail over 60 ms. Residual roll tails are cleared; the
pressure source stays live at a fixed pitch and low gain throughout the hold.
Music ducks further and the latch stays subtle, leaving contrast for release.
The release
combines an immediate low-mid impact and crisp crack with an expanding air bloom
and diffuse theme-colored shimmer. The strongest impact lands inside 45 ms;
the audible 300-500 ms bloom supports the flash before fading by the end of the
680 ms clip. The quieter lid stop can overlap the bloom without cutting it off.
Background music stays ducked through the physical release. Progress stars
remain silent. The separate 740 ms saved-reward accent resolves upward and has
consistent energy across all eight themes; it only plays after saving succeeds.
Release and reward clips target source RMS levels of 0.17 and 0.12, with a 0.78
peak ceiling and playback gains of 0.86 and 0.54. Their layered envelopes provide
contrast while preserving mixing headroom, rather than raising every sound.
WAVs are mono, 16-bit PCM at 22,050 Hz,
1,549,152 bytes in total. Regenerate and inspect their hashes and dynamics with:

```powershell
node tools/generate-chest-audio.cjs --report
```

The complete bank is bundled in the startup PCK and loaded by the pack verifier.
`prepare_chest(theme_id)` caches the selected world's clips directly from the
pack. `chest_sound_bank.gd` supplies small 11,025 Hz deterministic local
replacements if a resource is unavailable. Playback requires no later download.

One loop player and three rotating one-shot players bound overlap. They are
independent of word playback, card effects and music. Muting, backgrounding, changing
worlds and leaving the result stop the chest performance. A resource failure
cannot delay input, animation or saving.

## Verification and previews

`npm run test:chest-charge` covers local motion, cue order, cancellation,
sound-resource validity, bounded channels, real-scene reward saves and retries.
`tests/browser/chest-charge.spec.cjs` exercises the exported game, observes
browser cue/audio scheduling and verifies playback without later audio requests. These software
measurements do not include display scanout, speaker/Bluetooth latency or physical
mobile performance.

`tools/capture-chest-feel.gd` is an isolated native art/audio preview. It performs
a short cancelled press and a full opening on a neutral background without
reading or writing reward storage. It uses the actual view and audio players,
including Godot Movie Maker's offline audio mix. Its receipt accent illustrates
the preview's completion; actual persistence ordering is tested in the game scene.

After importing the project, generate the eight 640 x 640 previews and their
gallery with Godot, FFmpeg and ffprobe available on PATH:

```powershell
node tools/capture-chest-feel.cjs
```

Outputs go to `build/chest-feel/`: 7.5-second MP4s with the engine's mixed audio,
twelve stills per world, motion grids, resource hashes, cue/media reports and
`index.html`. Each gallery also has a content-hashed entry point, and embedded
media URLs carry content hashes so updated captures cannot reuse stale previews.
Stills sample delivered recoil cues after 33 ms, the anticipation brake after
30 ms, the held pose after 90 ms and 190 ms, the release flash after 60 ms,
and the opening lid after 200 ms. A side-by-side comparison uses the same
640 x 640 crop for both held poses; real progress may still advance between them.
Mixed-audio checks measure the quiet hold separately from the preceding roll
and the following release. The gallery can hide theme names for a listening
and motion review. Capturing
with a fixed 60 fps is an offline render setting, not a mobile frame-rate result.

The 80 ms input and 50 ms audio-alignment numbers remain device-validation
targets. Distinct motion signatures and audio hashes do not by themselves prove
that listeners can reliably identify every world without its name.
