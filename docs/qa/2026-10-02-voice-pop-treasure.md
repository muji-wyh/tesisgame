# Voice Pop earned treasure

Voice Pop starts each round with zero chest opportunities. Accepted speech
earns one chest at each of 100, 200, and 300 points, with a cap of three.
The result action opens a dedicated page showing the complete batch together.
Every chest in that batch has a different physical design.

## Behavior checked

- Score milestones, progress, award feedback, natural round completion, and
  reset on a fresh round follow the existing scoring and combo rules.
- One-, two-, and three-chest batches retain their selected themes and opening
  state. Saved pending treasure is resumed before starting another round.
- Hold cancellation, controller input, overlays, page backgrounding, reduced
  motion, and exactly-once persistence use the shared chest lifecycle.
- A released chest remains open while the remaining chests stay available.
  Failed storage writes are retryable without rerolling or duplicating rewards.
- Desktop, portrait, small-phone, and landscape layouts keep all three chest
  controls visible and separate, with at least 44 CSS pixel touch targets.
- Five source-derived chest designs extend the shared catalog to eight unique
  theme designs. Original package provenance and frame hashes are recorded in
  `assets/chests/downloaded/SOURCE.txt` and its manifest.

## Integration checks

- `voice_pop_reward_tests.gd`: 2,083 checks passed, including independent timing
  of time-bonus and chest-award messages across seven playfield sizes.
- `pop_reward_room_tests.gd`: 205 checks passed, including hidden zero-size
  initialization, deferred container placement, showing, and reentering the
  room under the project's normal viewport scaling, plus the single-line title
  and its font-height bounds.
- `pop_reward_flow_tests.gd`: 19 checks passed through the actual main scene.
- `pop_result_audio_tests.gd`: 71 checks passed.
- `talk_quest_reward_chest_tests.gd`: 1,602 checks passed.
- `talk_quest_reward_flow_tests.gd`: 38 checks passed.
- Shared `chest_feel_tests.gd`: 1,499 assertions passed, including visible-model
  fitting, source alpha containment, and opening bounds for the downloaded art.
- Shared `chest_reveal_tests.gd`: 2,011 assertions passed, including lighting
  coordinates after transparent sprite padding is cropped.
- `tests/pop-reward-host.test.cjs` and `tests/chest-assets.test.cjs`: 25 tests
  passed, including storage failures, independent mode storage, asset hashes,
  source provenance, and downloaded frame coverage.
- `tests/web-export.test.cjs` and `tests/test-runner.test.cjs`: 28 tests passed.
- `tests/browser/pop-treasure.spec.cjs`: both complete flows passed in desktop
  Chromium and iPhone WebKit (2 passed, 4.4 minutes). They cover earning three
  distinct chests, the score cap, natural round completion, hold cancellation,
  backgrounding before release, opening, leaving and returning, and reloading
  partially and fully opened treasure. Output is recorded in
  `build/pop-treasure-browser-verified.log`.

Native integration output is in `build/pop-treasure-integration-verified.log`.
The visual harness at `tests/godot/pop_treasure_visual_review.gd` renders the
actual game and treasure room at 1366x768, 390x844, 320x568, 844x390, and 667x375.
All 19 captures were generated successfully. Desktop, phone, small-phone,
landscape, simultaneous score awards, held/released chest effects, and completed
reduced-motion images were inspected in `build/pop-treasure-review`. Inspection
led to fitting downloaded artwork by its visible silhouette and separating
simultaneous time/chest badges. Final screenshots confirm both corrections.

The browser flow also exposed stale label and container geometry after opening
the treasure page. The room now settles deferred layout changes and republishes
the final control rectangles used by input and accessibility. The "Your treasure"
heading does not wrap and sizes its font to fit its header slot. The final
export passed a focused restored-room check in desktop Chromium and iPhone
WebKit (2 passed, 43.6 seconds). Both screenshots were inspected: the title,
instructions, three distinct chests, and Back control remain visible without
overlap. Output is in `build/pop-treasure-final-preview.log`; screenshots are in
`build/pop-treasure-final-preview-results`.

## Web package

The final `npm run build:web` passed. The actual exported startup pack loads
all eight chest types and all 43 downloaded opening frames. It also verifies
350 word pronunciations, 12 game effects, and 224 required audio paths without failures.
The compressed startup download is 20.46 MB. Build output and verification are
recorded in `build/pop-treasure-web-build-final.log`.

The local preview is
<http://127.0.0.1:41773>. These changes have not been deployed.
