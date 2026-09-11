# Sky and Listen feedback accepts answers

The user's Sky screenshot showed the correct `harp` answer beside a wrong
`piano` answer, but both buttons were disabled until Continue. Sky and Listen
share that input path; both now accept the visible answer during feedback.

- After a mistake, tapping an answer immediately retries that same question.
  The correct answer earns one success; another wrong answer counts one attempt.
- After a correct answer, tapping either old answer advances to the next
  question without applying the old button position to an unseen new answer.
- After the final success or third mistake, a tap only opens the result.
  Continue remains available throughout, and invalid, hidden, paused and
  completed input cannot advance or score.
- Red/green feedback stays visible on enabled buttons, including hover/press.
  Each graded answer moves keyboard/controller focus to Continue, preventing
  repeated accept presses from automatically resubmitting a wrong answer.
  Players can still navigate or click the answers to retry.
- Feedback pronunciation is retained. Retrying replaces the old pronunciation
  with the same displayed word; advancing or finishing stops it. Listen's
  feedback picture remains its replay control.

## Verification

The native regression failed before the fix with **43 failures in 388
assertions**. The final focused suite passed **400 assertions**, zero failures,
including feedback colors, stable geometry, real Continue focus, exact scoring,
signal counts and both final outcomes. Logs:
`build/responsive-choice-native-red.log` and
`build/responsive-choice-native-green.log`.

The browser regression reproduced the old bug in both modes: Sky's `root`
answer and Listen's `goat` picture remained on wrong feedback for the full
10-second assertion window after clicking the correct visible answer. The
report, traces and screenshots are under `build/responsive-choice/red-report.json`
and `build/responsive-choice/red-results/`.

`npm test` passed **27 native suites, 18,542 checks/assertions**, zero failures;
**100 Node passes**, zero failures, one existing external chest-source skip.
This includes 54 audio-flow assertions and the earlier Match regression.
Log: `build/responsive-choice-tests.log`. Independent code review found no
remaining blocker.

`npm run build:web` passed, including the exported-pack pronunciation checks.
Startup transfer remains **12.11 MB**, with 28 audio assets loaded on demand.
No images, licensed Unity inputs or audio assets were changed.
Log: `build/responsive-choice-build.log`.

The frozen export was verified through HTTP at port 4181:

- Pack: `game-24ce685982a4e8d6.pck`.
- Pack SHA256: `24ce685982a4e8d6c0ca708a018fd3b29206b566b1d4914af3e95a2628479242`.
- HTML SHA256: `f8237eafad6f0f017d4cb42788c576bdccabe76f09eddd75f23a2c81a7653f29`.

Five distinct local browser cases passed against that frozen export: Sky and
Listen on desktop Chromium and iPhone WebKit, plus the desktop Sky
pronunciation/Continue case. The interaction cases exercise first-tap same-word
correction, Continue, answer-driven advance without changing score, terminal
answer taps, stable question artwork and fixed button positions. Desktop and
phone screenshots were inspected independently.

The first browser run passed three cases; the two Sky cases reached results
but exposed an incorrect test expectation (`Try again` instead of the existing
`Good try!` result text). Only that expectation was corrected, then those two
cases passed against the same build. Both reports and their screenshots/traces
are preserved in `build/responsive-choice/green-report.json`,
`green-results/`, `green-corrected-report.json` and `green-corrected-results/`.
No product change or rebuild was needed after the initial browser run.
