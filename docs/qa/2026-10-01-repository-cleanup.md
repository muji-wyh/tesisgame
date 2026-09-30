# Repository cleanup

The audit followed production callers, resource lookup paths, export inventory,
test runners, and documentation links. It preserves the current three game
modes and saved progress; it does not restore retired feature plans.

## Removed code and assets

The simplified Voice Pop result had no production caller of `narrate()`, but
the dedicated narrator, queue, state signal, UI gates, generator, prompt
catalog, and recordings remained. This cleanup removes that subsystem and
the unused `unique_words` summary field. Result words still play individually
through the normal voice channel, with coverage for replay, mode changes,
backgrounding, menus, and mute.

The retired bank contained 51 WAVs and 51 import sidecars: 102 files totaling
9,533,059 bytes. Before removal, their exact working copies were copied and
SHA256-verified under the ignored local directory
`build/retired-assets-backup-20261001-002723`. That includes pre-existing import
metadata changes. A separate snapshot of all 1,017 tracked import sidecars
protects unrelated local metadata during validation. Historical provider and
source hashes remain in [report provenance](../assets/pop-voice.md).

Packaging no longer reads the retired prompt catalog. Export rules and the
actual PCK verifier reject the old recordings. Rebuilding an old output still
removes obsolete hashed files and retired multiplayer/model outputs: that
cleanup remains necessary even though those runtimes are gone.

## Documentation and fixtures

- The README now gives the current setup and game overview. Detailed material
  lives in [gameplay](../gameplay.md), [development](../development.md), and
  [media workflows](../assets/generated-media.md), linked from maintained indexes.
- Corrected player attribution, leaderboards, speech hints, Pip tap handling,
  audio-bank priority, and chest behavior, including the in-game accessible
  help's player-selection and result instructions. Twenty old plans/specifications and
  seven retired speech QA records explicitly identify their historical scope.
  Licensing, provenance, migration evidence, and original measurements remain.
- Deployment tests now use isolated exports instead of depending on a real
  `build/web`, including checks that missing exports fail before Azure calls.
- Renamed the obsolete narration suite to `pop_result_audio_tests` and retained
  active word-review coverage. Pip tests no longer assume the old four-player
  audio layout; they still verify that repeated taps do not add players or
  replace the current greeting. The gameplay-feedback fixture halts audio,
  allows mixer cleanup, and deletes its temporary save files on teardown.
- Browser result checks previously required complete silence, predating
  automatic leaderboard attribution. They now require exactly one short
  `correct.wav` score-save cue and still exclude reports, coaching, and music.
  The first browser run found this stale expectation in both result cases;
  production playback was not changed to satisfy it.

Reward accounting, toy unlocks, legacy save migration, current browser speech,
local player records, optional licensed overrides, and browser audio recovery
remain unchanged. Compatibility code was not removed simply because it refers
to a retired screen or uses a legacy storage key.

## Validation

- 41 distinct native suites passed, totaling 62,581 checks/assertions, covering
  models, UI, current audio, Pip, word review, saved rewards, legacy playrooms,
  and leaderboards. The initial stale four-channel assertion was corrected and
  the affected suite passed on rerun; the remaining suites then completed.
- 217 Node tests passed across core assets, generators, export, deployment,
  speech hosts, local speech preparation, save hosts, and keyboard handling.
  The tooling audit also passed the updated world-audio inventory checks.
- The final documentation audit checked 133 relative links across 104 Markdown
  files with no missing targets; documented current npm commands exist in
  `package.json`.
- The release export passed the actual PCK check for 350 pronunciations,
  12 general effects, and 224 required source/imported audio paths, with all
  51 report clips absent. Compressed startup transfer decreased from 19.43 MB
  to 18.06 MB, about 7%. The game pack is `game-4a5d5ee7b663a8c3.pck`; the
  unchanged engine is `engine-ab20058469bff805`.
- After import, native tests, and export, all 966 retained tracked import
  sidecars matched their original working-copy hashes. Only the 51 intentionally
  retired sidecars were absent; unrelated pre-existing metadata changes remain
  outside the cleanup commit.
- All 12 selected browser cases passed: ten desktop Chromium and two Android
  Chromium emulation cases. The two desktop result cases passed after updating
  the stale silence expectation. Coverage includes first-entry audio, suspended
  context recovery, Match/Memory speech and Pip reactions, serialized Pip taps,
  Voice Pop slices/missed-target calls, mode-exit audio restoration, result
  playback, and real offline word audio with no later audio HTTP requests.
- The final help-text rebuild retained the exact verified game-pack and engine
  hashes. Exported help contains the current player-selection instructions, and
  the real Chromium first-entry audio smoke passed again on that final export.

Browser speech input is simulated. Android emulation checks browser behavior,
not physical phone audio, microphone recognition accuracy, or device performance.

The native recovery fixture still emits its pre-existing headless focus warning
while passing. A verbose diagnostic run of gameplay feedback outlasted two
short real-audio "still playing" assertions while logging resource loads; its
standard run passed before and after the teardown cleanup. No production sound
duration or assertion was relaxed. After the cleanup, the standard fixture
passed 114 assertions without its previous leaked-audio-object warning.

Local logs use the `build/repository-cleanup-20261001-` prefix. Godot imports,
native runs, Web exports, and browser jobs are serialized against this checkout.
