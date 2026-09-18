# Pip's quiet-time dances

Pip previously waited 12–16 seconds for a small gesture and never volunteered
a complete dance. Quiet gameplay and the playroom now start a 3.2-second dance
after 6–9 seconds of inactivity. Alternating wing raises, side-to-side sways and
soft hops rotate between the existing seven short greetings. A complete dance
returns about every 17–23 seconds while the player remains idle.

The native mascot uses independently animated body, head, wing and foot layers
from the existing loading-screen art. The Button itself does not move or scale.
There is no automatic music, speech, status announcement or saved-progress change.

## Attention and lifecycle

- Meaningful input cancels an idle routine immediately and restarts the quiet timer.
- Deliberate tricks, room movement, feedback and pronunciation take priority.
- Voice Pop uses its own phase, with microphone opening, listening, reconnection
  and active rounds suppressing idle routines. Narration loading and playback
  also suppress them, including the prerecorded report player.
- Background/hidden pages stop work; returning begins a fresh quiet interval.
  Reduced motion disables autonomous gestures. Medals, reward previews and
  results retain their existing dedicated feedback behavior.

## Verification

Native suites cover timing, the three routines and seven existing gestures,
speech/input interruption, lifecycle, stable click bounds, no audio/nodes/save
side effects, and actual rendered frames. A visual review caught an atlas-source
scaling error: Godot imports SVGs at 3×. The renderer now crops using the imported
texture height, while joint positions remain in the original 120-unit coordinates.
A first-frame comparison to the resting mascot protects against incorrect
cropping even when the erroneous image still moves.

Original rendered pose evidence is in ignored `build/lively-pip-native/`.
Browser evidence is in ignored `build/voice-pop-qa/lively-pip-*`.

- Native: proactive Pip 310 assertions with actual rendering; mascot 127 with
  actual rendering; engagement scene 47; playground 89; playful controls 50;
  UI audio flow 70; Voice Pop scene 760; report narration 56. All passed.
  The narration suite also reports five ObjectDB cleanup warnings at test exit.
- Chromium: all four Pip browser cases passed, including multi-step automatic
  dance, six deliberate reactions, multi-touch release/cancel, reduced motion
  and both visibility/page lifecycle transitions. Lesson pixels and saved state
  remain unchanged during autonomous motion.
- iPhone WebKit profile: automatic multi-step dance, six deliberate reactions,
  reduced motion and stable lesson/save state passed. This is an emulated
  browser profile, not physical iPhone testing.
- Inspected original native frames and browser screenshots at 390×844 and
  1366×768, plus a real-time room dance sequence. No broken anatomy, clipping
  or adjacent-control obstruction remained. Room status and console stayed clean.
- Web export: 200 startup pronunciations and 158 optional paths passed pack
  validation; compressed startup is 13.28 MB with 79 on-demand audio assets.

## Production acceptance

Runtime commit `4694734` was fast-forwarded to `main`, pushed and deployed using
the exact tested export (`npm run deploy -- -SkipBuild`). Production HTML,
JavaScript, WASM and game pack matched local SHA-256 hashes. The deployed pack
is `game-f27c565eeddbda2d.pck`.

Both production Chromium checks passed: real-time multi-step idle dancing with
unchanged lesson/saves and reduced-motion behavior, plus all six deliberate
reactions. The original production screenshot was also reviewed. Hash evidence
is in `build/voice-pop-qa/lively-pip-production-manifest.json`.

Live version: https://gentle-forest-02ff42900.3.azurestaticapps.net/?v=4694734
