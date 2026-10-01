# Talk Quest scene artwork

The runtime scene artwork is original procedural vector art in
[`talk_quest_backdrop.gd`](../../../scripts/talk_quest_backdrop.gd). It is not a
Unity package, a screenshot of a source asset, or a derivative of the downloaded
review assets. No third-party texture, model, font, or animation is embedded in
these fourteen backgrounds.

Each environment has its own composition and props. Godot draws the artwork in a
960 by 540 design space and fits the complete scene inside its Control. Ambient
updates are limited to 30 redraws per second and stop while the Control is hidden.
Cached rounded surfaces and modest polygon counts keep the component suitable
for the Web renderer. No independent canvas, viewport, lighting pass, imported
texture or shader is required.

`manifest.json` records the level-to-art mapping and the animation intent.
Dialogue data remains the authority for lesson names, dialogue and completion.

## Integration

```gdscript
var backdrop = preload("res://scripts/talk_quest_backdrop.gd").new()
backdrop.configure(1)
backdrop.set_progress(0.5)
backdrop.set_reduced_motion(false)
backdrop.celebrate()
```

`configure_level(level, scene_data)` is an alias for `configure(level, scene_data)`.
Both accept an optional Dictionary for forward-compatible scene metadata.
`set_progress` accepts a normalized value and smoothly approaches it. The
workshop also accepts `set_repair_count(0..5)`; completed stations display an
intact toy and a star. Gameplay must call this only after a repair succeeds.

Reduced motion freezes ambient movement and immediately applies progress.
Celebration is decorative and never changes dialogue, scoring, or repair state.
`celebrate()` should be called only after the gameplay controller records success.

## Provenance

- Authorship: original vector geometry authored for this repository.
- Source design: the approved fourteen-scene Talk Quest catalog.
- Third-party source files copied or modified: none.
- Imported source asset licenses required by this artwork: none.
- Validation: the native art-review harness rendered every scene at start and
  completion, including 320-pixel views. The contact sheets were visually
  inspected. The integrated character and dialogue layout is checked separately.

## Render review

Run `node tools/run-godot.cjs --path . --script
res://tests/godot/talk_quest_art_review.gd` with a real renderer. It writes
individual PNGs and contact sheets to `build/talk-quest-art-review/`.
The October 1, 2026 run completed with 129 captures across scenes and chests,
zero capture failures and no rendering errors. The local renderer used ANGLE
with Godot's Compatibility mode.
