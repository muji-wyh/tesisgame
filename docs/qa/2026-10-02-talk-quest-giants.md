# Talk Quest giant creature refresh

This local update replaces three active creatures with distinct acquired models:

| Level | Identity | Source design |
| ---: | --- | --- |
| 1 | Stonewarden | Handpainted Mini Legion Rock Golem |
| 12 | Stormwing | Animated Witch and Dragon Monster, dragon |
| 14 | Embermaw | Siuniaev GolemMonster |

The other eleven creatures remain active. Campaign progression, fourteen unique
level assignments, finite word budgets, rewards and save data retain their
existing behavior. The prior scene and music refreshes remain in place.

## Art and animation

All three GLBs retain the original mesh, UVs, skeleton and embedded painted
albedo, capped at 1024 by 1024 pixels. Their combined size is 4,656,416 bytes.
Reusable licensed assets remain private build inputs and are embedded in the
compiled game pack. Source and conversion provenance are recorded in
[the asset documentation](../assets/talk-quest-giants.md).

Stonewarden uses game-authored skeletal Idle, Attack and Hit clips. Its exporter
corrects source FBX bind-unit inconsistencies before authoring motion; it does
not represent the original Unity Humanoid muscle clips as transferred.
Stormwing and Embermaw use verified source Idle, Attack, Hit and Defeat clips.
Conversion validation samples skinned vertex movement and animated bounds.

A low camera and larger standing bodies establish scale. Attack and raised-hand
impact gestures receive extra framing room before the camera returns close.
Periodic threat gestures provide visible motion during play without changing
damage or the word budget. Reduced motion disables those gestures and camera
movement. Pausing freezes skeletal reactions and their camera tween.

## Native verification

The complete Talk Quest group passed 4,932 native checks and 24 host tests
after model integration. This covered progression, fourteen distinct active
creatures, actual skeleton motion, original textures, source clip duration,
save compatibility, compact layout, combat and reward persistence. The log is
`build/quest-giants-native.log`.

Final camera changes passed 142 giant lifecycle assertions, 610 scene checks
and 153 compact layout checks, recorded separately in
`build/quest-giants-final-native.log`. This includes source/camera pause and
resume, impact interruption and switching to reduced motion during a camera
return. Rendered review produced 26 captures using
`tests/godot/talk_quest_giant_review.gd`; captures are generated under
`build/talk-quest-giants/review/`. It covers desktop idle, attack, impact and
defeat, phone idle and combat gestures, landscape, and compact reduced motion.

The native Windows renderer uses ANGLE on Microsoft Basic Render Driver.
These checks establish rendering and layout behavior, not physical phone
performance. The capture harness uses dummy audio and does not activate a
microphone.

## Web verification

The final Web export completed with a 25.94 MB compressed startup download.
Pack verification confirmed all three giant models and their supplemental
manifest, 350 word pronunciations, 12 game effects and 224 required audio
paths. The game pack is `game-95ded192b7713085.pck`; the build log is
`build/quest-giants-web-build.log`.

Both focused Chromium cases passed against that export:

- First-stage word attacks, victory, chest opening, reload and exactly-once
  reward restoration. The exported screenshot shows the new Stonewarden.
- A 320 by 568 portrait viewport, 568 by 320 landscape, and portrait return,
  with all fourteen map destinations reachable without scrolling, readable
  word cards, reduced motion and unavailable-speech behavior.

The log is `build/quest-giants-browser.log`; captures are under
`build/quest-giants-browser/`. Browser checks use mocked speech recognition,
so they do not establish physical microphone behavior.

Publication checks covered assets, chest sources, theme audio, Web packaging,
deployment failure handling and the test runner. The texture inventory still
expected only the original 481 imports; it now verifies the 43 additional chest
frames against their manifest while retaining the original-art count. All 20
asset checks passed after that correction; the other 64 checks passed without
changes. The downloaded chest frames remain private local build inputs, with
only their provenance, manifest and baker committed. These publication changes
do not alter the already verified game pack.

The reviewed local preview is served at `http://127.0.0.1:41773/`. This QA
record was completed before the subsequent commit and production deployment.
