# Pair chest acknowledgement

`scripts/pair_chest_reward.gd` presents Match and Memory pair drops in a reserved
46 CSS-pixel toolbar row above the cards. It does not roll for a drop, grant or
save treasure, stop gameplay, open a chest, or own keyboard/controller focus.
The host supplies the round identity, theme manifest and actual earned result.

## Reward rules

Match and Memory each draw one 50% base chance per round. An eligible round
chooses one of its five successful pairs as the reveal point; incorrect answers,
repeated taps and pronunciation replay never draw additional chances. Once a
chest appears, remaining pairs retain the same single earned chest. Each mode
tracks its own completed dry rounds: after two without treasure, the next round
is guaranteed a chest. The guarantee raises the overall long-run drop rate above
the base 50%; it is not five independent 50% pair rolls.

Reservations and pity share the existing atomic medal save. Abandoning or
reloading an unfinished unawarded round keeps its reservation and does not count
another dry round. A successful reveal saves chest ownership, its theme and its
captured contents before effects play. Opening, leaving an earned round, or
reloading settles those contents once. Save failures preserve the pending result
and expose the existing Retry rewards action. Pair rewards never alter word
mastery credit.

The final pair finishes its small reward acknowledgement before the normal
Pip completion sequence. That sequence retains Open chest but does not repeat
the already-played chest cue or confetti. The reserved HUD row does not change
height when the acknowledgement appears or clears; short landscape uses 34 CSS
pixels. At heights of 360 CSS pixels or less, Match and Memory use a 44-pixel
header and tighter outer spacing to preserve 44-pixel card targets even with
speech controls visible. Menu, notebook and background pauses hide and freeze
the inline effect.

A new earned chest appears with a short grounded hop and settles beside
"Chest found!". The 0.12-second reveal drives its `reward` cue, the small local
light accent and the shared viewport confetti. GameUI keeps the paper in its own
CanvasLayer for a 6.4-second burst, including over four seconds of slow descent.
The compact chest presentation still ends at 1.95 seconds; the paper tail continues
through the same round's result and opening screens. The closed chest then remains
as "Chest ready" until the host clears the round. Later pair callbacks cannot
restart the earned chest or overwrite it with an unsuccessful drop.

The optional "No chest this pair" acknowledgement lasts 0.8 seconds. It has no
chest, sound, surface panel or paper. Reduced motion keeps the earned artwork
and text still, with no moving light or confetti and the same completion gate.
Pause freezes the timeline; resume continues it without replaying sound. All
visible controls ignore pointer input, and confetti remains in the current game.

## Existing assets and rights

No assets were acquired for this component. The actual closed theme design is
rendered through `ChestView`, including the original Royal, Energy and Crystal
illustration and the five integrated 3D replacements. The illustration source
mapping remains in `assets/chests/SOURCE.txt`; the downloaded models, creators,
Unity Asset Store Standard EULA, acquisition records and available source clips
remain in [the chest replacement record](chest-refresh.md). This presentation
does not run any source opening clip.

The existing `portal_glow.png` comes from the acquired Modern 2D Animated Chests
Pack free demo, with its byte-for-byte mapping in the same source record. The
radial rays, sparkle and paper use already acquired Toon FX 1.52 textures by
Kenneth Foldal Moe (Archanor VFX), under the Standard Unity Asset Store EULA.
Exact source paths, hashes, license and acquisition status remain in
[the fragment effect record](jelly-fragments.md). Their trajectories and opacity
are game-authored; no video imagery or Unity particle scripts are copied.

The original Royal closed texture and existing sparkle/ray textures were
inspected before reuse. The source chest and light artwork remains intact.
The compact panel is interface layout, not replacement chest art. A visible
3D chest warms its closed render for three frames, then retains its texture
without running an idle or opening animation.

## Host API and verification

- `configure(round_id, theme_id, chest_manifest, reduced_motion)` validates the
  theme and starts a fresh presentation state when the round identity changes.
- `show_pair_result(round_id, earned, notify_miss = true)` accepts only the
  current round; subsequent calls cannot replace an already earned chest.
- `set_toast_bounds(Rect2)` receives the reserved HUD area in component-local units.
- `advance(delta)`, `set_paused(bool)`, `set_reduced_motion(bool)` and `clear()`
  let the owning game control timing and lifecycle without pausing gameplay.
- `snapshot()` distinguishes `performance_active` from a settled earned status.
  A final pair may finish its visual before the owner moves to a result page.
- `confetti_requested(round_id)` emits once at reveal; GameUI owns the viewport
  layer, independent clock and round-scoped deduplication.
- `cue_requested(round_id, "reward")` is presentation-only; the host retains
  pronunciation ducking, mute handling and audio cancellation.

`tests/godot/pair_chest_reward_tests.gd` covers source themes, timing, viewport
reveal signaling, duplicate and stale results, pause, reduced motion, narrow HUD
bounds, pointer pass-through, clearing and reentrant navigation from a cue.
`pair_chest_progress_tests.gd` covers the separate pity records, durable
reservations, save failures, reload recovery, legacy migration, stale browser
tabs and exactly-once settlement. `pair_chest_flow_tests.gd` drives actual Match
and Memory card controls, including the first and final reward pairs, continued
play during effects, hidden opening controls and accessible pair status.

Native scene captures at 1000 x 800, 390 x 844, 844 x 390, 320 x 568 and
568 x 320 verify both modes
with paper partway down the viewport and a second pair accepted during the
reward animation. Local review output is stored in the ignored
`build/pair-chest-review/` and `build/pair-chest-compact-review/` directories and
excluded from the Web export. These
captures were muted; they do not establish subjective listening quality.
