# Chest result cleanup - 2026-09-29

Post-opening collectible presentation has been removed: the medal badge and
piece counter, fragment assembly, tap-to-place input, medal completion burst and
flight to the More button. These nodes, tweens and callbacks are removed rather
than hidden. Result copy and browser instructions no longer promise collectibles.

The existing 10.5-second chest performance keeps its small seasonal release
burst. An ordinary saved result reads `Chest opened!` and
`Ready for another adventure?`. A newly unlocked toy immediately offers
`A gift for Pip!` and `Try it with Pip`. Exhausted worlds use the same ordinary
result without adding or resetting progress.

Reward storage, save retries, legacy saves and toy thresholds remain unchanged.
Saved favorite medals in Pip's room are outside this result-only change.

## Verification

- Editor parsing passed. Seven affected native suites passed 2,256 checks:
  core 1,478, adventure scene 330, expansion scene 61, medal scene 64,
  medals removal 74, gift adventure 130 and chest charge flow 119.
- Regression coverage checks that closed, normal, reduced-motion, background,
  failed-save, retry, toy-unlock and exhausted-world results have no collectible
  artwork or flight. It retains persistence, duplicate-callback, focus and
  immediate toy-action coverage.
- Web-export and deployment contracts passed 23 Node tests. The Web build
  passed its startup-pack verification with 200 bundled pronunciations and
  282 optional paths checked. Startup download remains 13.87 MB; the new pack
  is `game-158603182e3d86f2.pck`.
- Five focused browser cases passed: desktop and iPhone WebKit standard
  opening, desktop reduced motion, failed save/retry and chosen toy
  unlock/reload/play. No cases were skipped or retried.
- Visual inspection of desktop standard, reduced-motion and toy-unlock
  results, plus the iPhone WebKit result, found no collectible badge, counter
  or assembly artwork. The chest, review words and next actions remain visible
  without clipped result copy. WebKit is a simulated viewport/runtime check,
  not physical-device validation.

Generated logs and visual evidence stay in ignored `build/` paths. Native logs
use `chest-clean-<suite>.log`; parse, build and Node logs use
`chest-no-collectibles-<check>.log`. Browser results and screenshots are in
`chest-no-collectibles-browser/`, with its list log alongside.
