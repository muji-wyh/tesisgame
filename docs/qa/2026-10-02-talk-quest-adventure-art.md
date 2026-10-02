# Talk Quest adventure art refresh

This local update gives the fourteen existing locations and creatures a more
grounded 3D adventure presentation. Word combat, rewards, and saved progression
retain their existing behavior.

## Presentation

- Continuous ground and architecture replace the small raised dioramas.
- Perspective framing adapts to wide, portrait, and compact landscape views.
- Natural palettes, layered distant terrain, room-specific furnishings, and
  procedural wood, stone, plaster, tile, and sand surfaces add depth.
- Creature material profiles distinguish fur, skin, stone, and shell surfaces;
  matte eye whites reduce distracting glare.
- Fourteen anatomy-specific gestures and weight-dependent anticipation and
  recoil supplement source animation without adding model geometry.
- A dark slate word arena improves separation from the scene and retains clear
  card and remaining-word contrast.

The fourteen licensed GLBs, source meshes, rigs, IDs, and exported animation
clips are unchanged. No new third-party asset downloads were required. Runtime
gestures and attack reactions are authored effects, not verified source clips.

## Native verification

- Monster lifecycle and animation: 260 assertions passed.
- Scene and combat integration: 610 checks passed.
- Compact layout: 153 checks passed.
- Final rendered review: 25 captures across all fourteen stages, two idle poses,
  impact, six phone stages, landscape, and a compact reduced-motion view.

The final captures show distinct room dressing, complete phone monster
silhouettes, and readable controls and word cards. The rendering harness is
`tests/godot/talk_quest_adventure_review.gd`; screenshots are generated under
`build/talk-quest-adventure/`. Native logs are
`build/quest-adventure-native.log` and
`build/quest-adventure-render-final.log`.

The native Windows renderer uses ANGLE on Microsoft Basic Render Driver.
These checks establish rendering and layout behavior, not performance on a
physical phone. The capture harness uses dummy audio and does not activate a
microphone.

## Web verification

The Web export completed with a 25.01 MB compressed startup download. Pack
verification checked 350 word pronunciations, 12 game effects, and 224 required
audio paths without failures. The build log is
`build/quest-adventure-web-build.log`.

Both focused Chromium browser cases passed against the final exported build:

- First-adventure word attacks, victory, chest opening, reload, and exactly-once
  reward restoration.
- A 320 by 568 portrait viewport, 568 by 320 landscape, and portrait return,
  with all fourteen map destinations reachable without scrolling, usable word
  cards, reduced motion, and unavailable-speech behavior.

Browser tests use mocked speech recognition and do not establish physical
microphone or phone behavior. The log is `build/quest-adventure-browser.log`;
captures are under `build/quest-adventure-browser/`.

The final game pack is `game-33cbb7784ec41632.pck`. The local preview is served
at `http://127.0.0.1:41773/`. This update has not been committed or deployed.
