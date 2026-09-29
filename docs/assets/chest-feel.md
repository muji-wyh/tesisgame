# Eight-world chest performance

The chest requires a continuous 5-second hold: 1.2 seconds of initial pressure
followed by a 3.8-second opening performance. The lid releases 3.36 seconds after
the press, leaving 1.64 seconds for its opening, light and settling. Releasing at
any point before completion cancels the performance, stops its sounds and resets
progress while preserving the unopened chest. Reward selection and the save
format are unchanged.

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

The three stars and progress arc follow elapsed time up to the lid-release beat.
There is no visible phase or percentage label; semantic progress remains
available to screen readers. The first star lights just
before the initial hold ends and remains lit as the opening phase begins. Five
holding beats lead into fifteen opening beats. Intervals tighten from 320 ms to
60 ms, and their shared timestamps drive both physical impulses and sounds.
Lock pressure, lid strain, seam light, inward particles and the material loop
rise in intensity. Background music progressively ducks. From opening +1.80 s,
the last roll blends into continuously increasing strain and a rising air texture.
The pressure bed continues through unlock to release, with no silent stop or
frozen pose. Its opening speed is not slowed down to fill the wait.

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
| `cancel` | Release or drag any time before completion | Stop all performance sounds, brief return sound |
| `opening` | Initial pressure completes at 1.2 s; hold remains active | Continue pressure bed without restarting |
| `tension_pulse` | Opening +0.11 s through +1.86 s | Fifteen accelerating material beats |
| `anticipation` | Opening +1.94 s | Continuous rising bridge over the pressure bed |
| `unlock` | Opening +2.08 s (3.28 s total) | Lock/core sound |
| `release` | Opening +2.16 s (3.36 s total) | Lid, material sound, local theme flash and twelve light streaks |
| `settle` | Opening +2.95 s (4.15 s total) | Material landing sound |
| `opened` | Opening +3.8 s (5 s total) while still held | Save progress before the opened result |

A frame stall consumes expired beats without playing a backlog. A rising bridge
more than 80 ms late is skipped; release still stops the bed. Fast-forward and
explicit new-round settlement remain silent. Backgrounding cancels unfinished
openings. Reduced motion retains the initial 1.2-second hold and skips the buildup.

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
in pitch, and the `opening` clip bridges anticipation into release. The release
combines immediate contact with cavity resonance, outward air and a bright tail;
background music stays ducked through that impact. Progress stars remain silent.
WAVs are mono, 16-bit PCM at 22,050 Hz,
1,549,152 bytes in total. Regenerate and inspect their hashes and dynamics with:

```powershell
node tools/generate-chest-audio.cjs --report
```

The exported bank is optional content-hashed `.sample` audio, excluded from the
startup PCK and checked by the existing pack verifier. `prepare_chest(theme_id)`
preloads only the selected world's clips. `chest_sound_bank.gd` supplies small
11,025 Hz deterministic local replacements, primed one per frame when needed.
Playback never awaits a download, and a late resource only fills the cache.

One loop player and three rotating one-shot players bound overlap. They are
independent of narration, card effects and music. Muting, backgrounding, changing
worlds and leaving the result stop the chest performance. A cold/failing optional
resource cannot delay input, animation or saving.

## Verification and previews

`npm run test:chest-charge` covers local motion, cue order, cancellation,
sound-resource validity, bounded channels, real-scene reward saves and retries.
`tests/browser/chest-charge.spec.cjs` exercises the exported game, observes
browser cue/audio scheduling, and tests missing themed resources. These software
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
nine stills per world, motion grids, resource hashes, cue/media reports and
`index.html`. Each gallery also has a content-hashed entry point, and embedded
media URLs carry content hashes so updated captures cannot reuse stale previews.
Stills sample delivered recoil cues after 33 ms, the release flash after 60 ms,
and the opening lid after 200 ms. The gallery can hide theme names for a listening
and motion review. Capturing
with a fixed 60 fps is an offline render setting, not a mobile frame-rate result.

The 80 ms input and 50 ms audio-alignment numbers remain device-validation
targets. Distinct motion signatures and audio hashes do not by themselves prove
that listeners can reliably identify every world without its name.
