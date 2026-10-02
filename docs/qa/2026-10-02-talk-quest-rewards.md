# Talk Quest reward chest parity

Talk Quest now runs its twenty chest mechanisms through the same `ChestView`,
`ChestFeel`, surprise, and audio performance used by Match. The shelf keeps the
reviewed mechanism illustrations. The native reward checkpoint and all fourteen
conversation paths retain their original scoring and collection rules.

## Behavior verified

- Pointer, touch-event cancellation, keyboard-capable buttons, and controller
  acceptance share the explicit hold lifecycle.
- The first 1.2 seconds confirm the gesture; input remains cancelable until
  physical release at 3.36 seconds. The reward saves at completion at 5 seconds.
- Early release, movement, focus loss, global input cancellation, and background
  transitions cannot turn an uncommitted gesture into a reward.
- A committed opening survives release and global cancellation. Backgrounding
  settles it silently. Repeated callbacks cannot replay a reward or surprise.
- Save failure blocks Next and suppresses the success accent. Retrying saves
  the existing reward once and acknowledges only the successful write.
- Reduced motion retains the confirmation hold and completes immediately
  afterward. Changing that preference during opening also completes only once.
- Cleanup belonging to inactive Match cannot stop a committed Quest audio
  performance. The shared backdrop can omit its theme label behind Quest's
  existing stage header.

## Native checks and visual inspection

- `talk_quest_scene_tests.gd`: 171 checks across all fourteen adventures.
- `talk_quest_reward_chest_tests.gd`: 1,602 checks across all twenty designs,
  layouts, animation samples, cancellation, and reduced motion.
- `talk_quest_reward_flow_tests.gd`: 38 main-scene input, audio, persistence,
  retry, and reduced-motion checks.
- Shared `chest_reveal_tests.gd`: 2,011 assertions.
- Shared `chest_feel_tests.gd`: 1,477 assertions.
- Shared `chest_audio_tests.gd`: 2,648 assertions.
- Shared `chest_charge_flow_tests.gd`: 773 assertions.
- Shared `chest_surprise_tests.gd`: 2,356 checks.
- `tests/talk-quest-host.test.cjs`: 11 passing host tests.
- `tests/test-runner.test.cjs`: four passing test-registration checks.

`tests/godot/talk_quest_reward_visual_review.gd` renders the real Quest layout
at desktop, phone, and small-phone sizes. Its 28 captures in
`build/talk-quest-reward` cover holding, gathering, anticipation, physical
release, completion, and all twenty mechanisms at release. Desktop and phone
captures and the twenty-design contact sheet were inspected for framing,
readable instructions, and effect bounds. Intermediate mechanism previews in
that harness retain the already-completed scene's Next button; gameplay tests
verify that normal play enables it only after completion and persistence.

## Web build

`npm run build:web` passed. The packaged startup download is 20.03 MB; all
112 required audio assets were verified inside the game pack. Build output is
available from the existing local preview at `http://127.0.0.1:41773/`.
This verification does not deploy or modify the production site.

## Browser verification

The focused browser run uses the built export on port 41773 and serialized
Chromium and iPhone WebKit workers. The complete iPhone typing case passed at
the original device profile and pixel ratio, including rotation, six accepted
lines, an actual held chest control, background/resume, persistence, and the
next adventure. Normal and reduced-motion chest lifecycle cases also passed
in both Chromium and iPhone WebKit: four focused cases covering cancellation,
retry, before/after-release backgrounding, and exactly-once rewards on resume
and reload. Opened-state screenshots were inspected in both browsers.

The initial Chromium typing case exceeded its 150-second overall test budget
during the portrait-return input stage. Individual browser calls accumulated
software-rendering and trace overhead; no chest or scoring assertion failed.
Its focused rerun uses a build-only configuration with tracing disabled while
preserving the same CSS viewport, input profile, and original desktop pixel
ratio of one. The delivery configuration's `trace: off` is now honored by the
spec rather than overridden at file scope.

The isolated Chromium typing rerun passed in 2.1 minutes with its unchanged
150-second deadline. All six requested browser cases therefore passed across
the initial run and that isolated retry. No application change was needed for
the timeout. Logs are `build/talk-quest-reward/browser-tests.log` and
`browser-typing-retry.log`; reviewed screenshots are
`browser-desktop-chromium-opened.png` and `browser-iphone-webkit-opened.png`
in the same directory.
