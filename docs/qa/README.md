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
| [Talk Quest retirement](2026-10-06-talk-quest-removal.md) | Complete mode and resource removal, three-mode library, 80 passing native suites, 295 Node tests, 11 browser passes, and explicit timeout/audio-runtime limits |
| [Cross-page presentation](2026-10-03-game-taste.md) | Illustrated game library, shared typography and surfaces, persistent presentation settings, and responsive page review |
| [Approved Ava voice](2026-10-03-ava-speech.md) | Full 360-recording migration, exact approved profile, provenance, preserved nonverbal audio, and playback regression checks |
| [Native rendered-frame performance](2026-10-03-performance.md) | Five paired repeats over seven main-scene workloads; 12.63% lower aggregate active frame time on the Windows software renderer, with raw samples, source identities, exposure caveats, and a disclosed exit warning |
| [Hidden scrollbars](2026-10-02-hidden-scrollbars.md) | Hidden native and Web rails, retained overflow gestures and focus navigation, and compact-screen regressions |
| [Talk Quest victory and treasure room](2026-10-02-talk-quest-victory.md) | Pip dance and recorded cheers, sourced reward scenery, gesture/save regressions, and full-app responsive captures |
| [Talk Quest live transcript](2026-10-02-talk-quest-live-transcript.md) | Immediate raw hypotheses, separate scoring, lifecycle clearing, and bounded responsive captions |
| [Talk Quest countdown and Pip rematch](2026-10-02-talk-quest-pip-loss.md) | Ten-second saved-word migration, Pip's sad-to-encouraging sequence, cancellable calls, and responsive renderer evidence |
| [Talk Quest atlas refresh](2026-10-02-talk-quest-map.md) | Sourced chapter maps, fourteen destination compositions, responsive and full-caption checks, and renderer evidence |
| [Repository optimization review](2026-10-02-repository-optimization.md) | Card refresh reuse, hidden-page pause preservation, unchanged host snapshots, and verified build reuse; 81 Godot suites, 302 Node tests, 27 selected browser cases, production content verification and startup smoke check passed |
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
Talk Quest was retired on 2026-10-06; its campaign, atlas, creatures, speech,
and treasure-room reports also describe a removed mode. Their sources,
licensing notes, experiments, and migration evidence remain useful even though
the corresponding UI or runtime no longer ships.

Browser speech fixtures simulate callbacks. WebKit emulation does not prove
physical Safari audio or microphone behavior. Native/offline captures do not
establish mobile frame rate, speaker latency, or recognition accuracy. Retain
each report's explicit device and measurement limits when citing its results.
