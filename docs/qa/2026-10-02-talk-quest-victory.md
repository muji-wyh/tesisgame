# Talk Quest victory and treasure room

The final word impact starts a full 3.2-second Pip dance and a cancellable
sequence of the shipped recorded double quacks. Refreshes do not replay it.
Pausing or leaving stops the calls; resuming presents a quiet happy companion.
Reduced motion shows a smiling pose and still reaches the reward.

The reward stage uses Midnight68's CC0 interior illustrations, acquired Bobardo
particle textures, and Kenney's CC0 interface frame. Source details and hashes
are in `assets/talk_quest/treasure/manifest.json` and `SOURCE.md`. Seven textures
add 261,862 bytes before import. Existing twenty reward identities, opening
mechanisms, confirmation, cancellation, and durable collection remain intact.

The previous battle effects clear before the reward. Presentation rectangles
are recalculated for victory, reward, and paused reward instead of retaining
the previous layout. Physical UI scaling selects the room and typography.

## Verification

- Victory flow: 77 checks passed, including real word wins, one celebration,
  pause/resume, cancellation, durable reward idempotence, and reduced motion.
- Quest audio: 147 checks passed, including three recorded call timings,
  mute, page hiding, mode changes, and preserving chest audio during Pip cleanup.
- Existing scene: 693 checks passed across all fourteen adventures.
- Existing reward flow: 38 checks passed, including failed saves and retry.
- Compact layout: 166 checks passed.
- Live transcript: 53 checks passed.
- Pip component: 45 headless checks and 56 rendered checks passed.
- Existing Pip reaction audio: 25 checks passed.
- Host, export, and test-runner Node suites: 63 tests passed.
- Actual main scene: 275 checks passed and 16 captures produced under production
  canvas scaling at 1440x900, 390x844, 320x568, and 568x320.
- Web build succeeded; packaged texture/audio checks reported zero failures.
  The receipt at `2026-10-02T13:47:16.493Z` verified 2,313 source inputs and
  16 exported files. The compressed startup is 31.63 MB.
- The in-app browser loaded the new local build, entered the game, and displayed
  Talk Quest with no reported console errors. `browser-map.png` records startup
  verification; the native capture matrix records the actual reward states.

The initial full-app capture exposed a stale wrapped-label minimum height under
desktop scaling; the final capture verifies its correction. Battle word-effect
tails and an opaque source-frame center were also removed from the reward view.
The Map label now rescales with the physical viewport so it stays readable
after resizing from desktop to phone.
Captures are in `build/talk-quest-victory-app-review/`. Each layout includes
victory, closed chest, physical release, and collected states. The harness uses
isolated player files and never changes real player progress.

Rendering used the Windows ANGLE compatibility backend and Dummy audio driver.
Audio tests verify routing, sourced clips, pitch/gain, and cancellation; they do
not establish acoustic output or latency on a physical phone. No production
deployment is part of this change.
