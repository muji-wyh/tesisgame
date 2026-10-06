# Match and Memory feedback review

Date: 2026-10-07

## Scope

- Both pairing modes use the right and wrong excerpts from the user's
  `right_and_wrong.mp4`. Acquisition details, extraction windows, levels and
  hashes are recorded in [the audio manifest](../assets/pair-feedback-audio.json).
- Wrong Match answers have no spoken correction. Pip keeps visual reactions
  without calls during Match and Memory play or their results.
- Match continues until all cards are matched, with no correct counter, streak
  or three-error loss state. Mistakes remain only as optional leaderboard data.
- Obsolete wrong/loss recordings, the old spoken-match effect, loss artwork,
  generation code and UI paths have been removed.

## Native and packaging checks

- All 80 selected native suites passed. The exhaustive vocabulary layout suite
  was excluded because its existing full-catalog run repeatedly exceeded the
  600-second limit; the age, card, general layout and release layout suites passed.
- All 294 tests across 21 Node test files passed, with no failures or skips.
- After adjusting microphone-enabled taps to preserve the final answer's tail,
  the gameplay feedback suite passed again: 149 assertions, no failures.
- The final Web export passed its pack checks: both sourced effects are present,
  retired resources are absent, and the 350 word recordings remain available.
- The build receipt verified 2,226 input files and 17 unchanged output files.

## Browser checks

All 10 selected desktop Chromium cases passed after updating the retired-rule
fixtures and removing a redundant board scan from the New adventure test.
The checks use the actual exported game and WebAudio buffers.
They cover right/wrong outcomes in both modes, silent Pip reactions and results,
retained Home greetings, cue timing, speech answer sequencing, and removal of
the speech panel's Match counters. Repeated errors work offline on the same
board and all five pairs still complete it. New adventure rotates the lesson
and saves its protected unopened reward exactly once.

Both focused iPhone WebKit cases passed: repeated wrong pairs followed by full
completion, and the listening panel without Match counters. Desktop and iPhone
screenshots were inspected. Match has no score or error badges, while Memory
retains its own counters. Windows WebKit has no WebAudio in this setup, so these
checks validate touch, layout and state; Chromium supplies the audio evidence.

The extraction review used source frames, waveform boundaries and signal levels.
Audio input is unavailable to the agent, so this review does not claim subjective
listening. Runtime checks verify recorded buffer duration, playback rate, signal
energy, single-play behavior and channel lifecycle.
