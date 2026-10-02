# Talk Quest presentation polish

This local working-tree update improves the existing fourteen-level mode. It
does not change sentence matching, speech binding, rewards, or saved progression.

## Changes

- The atlas uses location landmarks, chapter regions, trails, water, bridges,
  and animated destination beacons. Monster portraits have been removed.
- All fourteen stages have distinct generated 3D environments, with beveled
  props, floor detail, lighting, shadows, and restrained ambient motion.
- Source skeletal idle animation is combined with per-creature gestures,
  breathing, wing movement, recoil, hit flashes, and a friendly retreat.
- Buttons, prompts, health, word attacks, victory, and treasure have coordinated
  feedback. The workshop uses repair progress and celebration instead of combat.
- Portrait framing keeps character movement within the viewport. The stage
  header stays above the 3D scene. Reduced motion stops traveling and spatial
  effects while retaining readable feedback.

## Native verification

`npm run test:talk-quest` passed:

| Suite | Checks |
| --- | ---: |
| Campaign model | 1,490 |
| Monster animation | 260 |
| Atlas and input geometry | 486 |
| Scene lifecycle | 121 |
| Browser host unit tests | 11 |

The rendered harness `tests/godot/talk_quest_visual_review.gd` produced 29 captures
of all fourteen stages, desktop and phone maps, narrow layouts, two idle poses, traveling words,
impact, reduced motion, victory, and treasure. Screenshots and logs are generated
under `build/talk-quest-polish/` and `build/talk-quest-polish-*.log`. Visual review
corrected washed-out lighting, small character framing, portrait wing clipping,
oversized celebration particles, and insufficient feedback-text contrast.

The final visual run used `--audio-driver Dummy` because an earlier run could
not initialize the local WASAPI output device. This harness verifies visuals;
it does not exercise the physical audio device.

The local Windows renderer falls back to ANGLE on Microsoft Basic Render Driver.
These are functional and visual checks, not measurements on physical mobile
hardware. Existing unrelated speech changes remain in the working tree.

## Web export and browser checks

`npm run build:web` completed with a 20.02 MB compressed startup download.
Its pack check verified all 224 required audio paths. The local preview is served
at `http://127.0.0.1:41773/`.

Chromium passed the focused Hear-line/lifecycle case and the phone-sized typing,
rotation, and reward case. Initial WebKit runs exposed test harness races:
the first 3D frame outlasted the gameplay polling deadline, and scrolling used a
zero range before container layout had published it. The harness now awaits its
existing render barrier and validates scrollbar geometry before native input;
the gameplay assertions and 10-second state deadline remain unchanged.

WebKit passed Hear-line/lifecycle after that correction. A subsequent missed
treasure tap prompted an input-geometry investigation. Two diagnostic runs
passed without a game change. The final harness waits for the chest layout to
render and publish stable button and scroll geometry before making one real
tap; it does not retry a missed tap or change scoring and reward assertions.
The clean final typing/reward run passed in 1.8 minutes, covering portrait,
landscape, portrait return, all six first-level lines, chest opening,
background/resume, a single committed reward, and the next adventure.

The focused browser cases passed in Chromium and mobile-configured WebKit.
They use mocked speech recognition and native interface input; no physical
microphone was activated. The Windows WebKit page compositor can capture a
blank image after rotation, an existing driver limitation. Raw canvas captures
remain rendered and pass the existing color-content assertions. These checks
do not establish physical iPhone compatibility.

The final clean WebKit log is
`build/talk-quest-polish-webkit-harness-final.log`; its screenshots are under
`build/talk-quest-polish/webkit-harness-final/`. The in-app browser preview was
also inspected for the new map and final speaker-badge layout. This update has
not been committed or deployed.
