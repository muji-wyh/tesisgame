# QA history

Files in this directory are dated evidence for a particular revision. They are
not current feature specifications or promises that old commands still exist.
Preserve successful and failed observations as recorded; use the
[current documentation index](../README.md) and maintained test inventory for
today's behavior. Local `build/` and `test-results/` paths may be absent from a
clean checkout, and historical export hashes must not be used as release targets.

## Useful checkpoints

| Record | What it establishes at that revision |
| --- | --- |
| [Talk Quest](2026-10-01-talk-quest.md) | Fourteen-level campaign and combined-worktree art/regression evidence; isolated release passed eight native suites, 237 Node tests, and two Chromium cases; Windows WebKit rotation captures retain the documented presentation limitation |
| [Repository cleanup](2026-10-01-repository-cleanup.md) | Retired narration assets, current documentation indexes, and compatibility regression checks |
| [Single-player speech restoration](2026-09-26-single-player-speech.md) | Removal of multiplayer models and enrolled voices; predates today's local leaderboard flow |
| [SpeechRecognition integration](2026-09-30-speech-recognition.md) | Interim stability, target binding, optional browser-managed local pack, and acoustic test limitations |
| [Medals removal](2026-09-24-medals-removal.md) | Removal of the collection page while retaining rewards and toys |
| [Chest result cleanup](2026-09-29-chest-result-cleanup.md) | Removal of post-opening collectible presentation |
| [Five-second chest](2026-09-29-chest-five-seconds.md) | Shortened performance; later release/pause changes refine it |
| [Chest anticipation pause](2026-09-30-chest-anticipation-pause.md) | Loaded pose and quiet interval before release |
| [Bundled audio](2026-09-29-bundled-audio.md) | Replacement of on-demand game audio with startup-pack resources |
| [Prior repository cleanup](2026-09-29-repository-cleanup.md) | Earlier retired assets and compatibility intentionally retained |

The September 23–24 multiplayer, voice-user, identify-user, and speaker-accuracy
records describe a removed prototype. Earlier Learn, Words album, Medals,
30-second Voice Pop reports, and on-demand-audio records are also historical.
Their sources, licensing notes, experiments, and migration evidence remain
useful even though the corresponding UI or runtime no longer ships.

Browser speech fixtures simulate callbacks. WebKit emulation does not prove
physical Safari audio or microphone behavior. Native/offline captures do not
establish mobile frame rate, speaker latency, or recognition accuracy. Retain
each report's explicit device and measurement limits when citing its results.
