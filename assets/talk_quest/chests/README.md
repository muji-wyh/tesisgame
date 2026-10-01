# Talk Quest reward containers

All twenty containers are original procedural vector artwork in
[`talk_quest_chest.gd`](../../../scripts/talk_quest_chest.gd). Their geometry and
opening mechanisms implement the approved themed chest catalog. They do not
reuse or recolor a single box. No downloaded Unity model, texture, animation or
render is copied into this runtime component.

The renderer draws in a 420 by 370 design space, fits the complete animation
inside its Control and ignores mouse input. Gameplay owns the open button,
reward eligibility, collection and persistence.

## Integration

```gdscript
var chest = preload("res://scripts/talk_quest_chest.gd").new()
chest.configure({"id": "chest-14", "name": "Robot Toolbox"})
chest.reward_revealed.connect(_grant_earned_reward)
chest.opening_finished.connect(_show_next_action)
chest.play_open()
```

`configure` accepts an `id` from `chest-01` through `chest-20`, or an integer
`index` from 1 through 20. Optional `name` and `accent` fields are supported;
`accent` may be a Color or an HTML color string. Invalid indices are clamped.

- `play_open()` starts a five-second sequence and ignores repeated calls while
  that sequence is running.
- `hold_reached` emits once at 1.20 seconds.
- `reward_revealed` emits once at 3.36 seconds.
- `opening_finished` emits once at 5.00 seconds.
- `release_reached` and `opened` are compatibility aliases at 3.36 and 5.00
  seconds respectively. Connect either the primary signal or its alias, not
  both, when granting a reward.
- `reset_closed()` returns to the unopened pose without emitting signals.
- `set_reduced_motion(true)` preserves the event timing and switches to the
  final pose at the reveal marker, with static reward decoration.
- `set_preview_time(seconds)` sets a deterministic inspection pose without
  emitting gameplay events. Call `reset_closed()` before returning to play.
- `get_animation_state()` exposes the ID, mode, elapsed time, opening amount
  and whether the current sequence has emitted its reward signal.

Animation pauses when hidden. The controller should keep the visible chest on
screen through `opening_finished`. Both normal and reduced-motion sequences
use the same signal ordering, including when a long frame crosses several cues.

## Provenance

- Authorship: original vector geometry and animation authored for this repository.
- Source design: the approved twenty-container Talk Quest catalog.
- Third-party source files copied or modified: none.
- Unity chest packages: retained in the separate asset-review source collection;
  they are not used by these authored runtime variants.
- The robot revealed by chest 14 is a decorative companion preview. Gameplay
  controls the actual companion collection and unlock.
- `manifest.json` lists each design and its opening mechanism.

## Render review

The October 1, 2026 native art review captured all twenty containers closed,
mid-opening at 2.55 seconds, fully open at 5 seconds, and in a 320-pixel
reduced-motion view. The contact sheets were visually inspected. The final
harness run produced 129 PNGs across scenes and chests with zero capture
failures and no rendering errors. Outputs are in
`build/talk-quest-art-review/`; the harness is
`tests/godot/talk_quest_art_review.gd`.
