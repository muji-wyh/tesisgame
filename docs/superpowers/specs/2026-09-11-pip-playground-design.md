# Pip's interactive reward room

The room becomes a small playable space. Keep the existing earned toys,
backgrounds, vocabulary labels, gift goals, stickers and saved choices.

- Tap Pip to poke: a brief surprised reaction and a quack. A held stroke
  across Pip is petting instead; show closed eyes, a lean and hearts, without
  also firing a poke on release.
- Drag the equipped toy and release to throw it. Show the held object,
  direction preview, flight and landing. Pip catches a nearby throw or runs
  after a missed one. The ball returns for another throw; other toys retain
  their own word and reaction. Locked previews cannot be thrown.
- Tap blank space to move Pip to that point, clamped to the room's floor.
  Nearby targets use a walk, distant targets a run; another tap redirects.
  Show the destination and a distinct walking/running gait.
- Keep visible Pet, Poke, Toss and Call shortcuts for keyboard/controller
  access. Retain the existing toy action sequence as another way to play.

Expand the room and its floor. The scene owns presses that start on Pip,
the toy or the floor. The catalog outside it retains dragging and wheel
scrolling. One pointer owns one gesture; a touch and its emulated mouse
events must not produce two actions. Releasing outside, losing focus,
opening another rewards section or hiding the page cancels held input.

Use a dedicated `pip_playground.gd` control for transient gesture, movement
and toy-flight state. Move the existing duck slot so the shared host never
snaps Pip back. Extend `duck_mascot.gd` only for room expressions and gait;
the header mascot keeps its current behavior. Use existing artwork and
Godot drawing/input APIs, without a new engine, package or save version.

Petting, poking, movement and throwing do not award pieces or write saves.
Clamp movement and toys after resizing. Reduced motion keeps each action
usable with immediate stable outcomes and suppresses decorative motion.

Verify real mouse and touch input, gesture/scroll ownership, position and
trajectory changes, catch/fetch outcomes, keyboard shortcuts, locked toys,
interruption/re-entry, reduced motion, and unchanged scores/saves. Inspect
desktop and phone screenshots, then run the existing regression suite.
Commit, merge to main, push and deploy the tested Web export, retaining the
previous local preview and verifying production files and interactions.
