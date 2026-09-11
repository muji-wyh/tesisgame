# Match feedback accepts the next card

The user could see the `horn` card after a wrong answer but tapping it did
nothing. Match retained the board during feedback while disabling every card.

In manual Match play, the first tap on an unmatched card now acknowledges the
previous answer and selects that exact card, using its existing pronunciation
and selection feedback. Tapping it again cancels the selection. Continue still
works, and the board keeps its original positions.

Matched cards and covered boards remain protected. A tap after the final pair
or third mistake advances only to the result, with chest/replay focus and no
extra score. A stale Continue cannot clear the new selection or pronunciation.
Voice feedback retains its automatic timer and speech queue; card input is
restored immediately when voice ends. Voice transitions update only card state
to preserve existing keyboard focus and avoid refreshing the entire screen.

## Regression evidence

The browser test failed against the previous export at the user's exact trigger:
after pairing `guitar` with the `piano` picture, tapping `horn` left the public
selection status empty for the full 10-second assertion window. Screenshot,
trace and JSON report are retained under `build/responsive-match/red-results/`
and `build/responsive-match/red-report.json`.

The native regression also failed before the fix. It covers first-tap
selection, keyboard focus, repeat taps, stable geometry, invalid/covered/matched
cards, unchanged scores, both result transitions, and stale Continue input.
Audio-flow checks cover four voice exit paths: explicit stop, speech end,
Rewards, and a hidden page. An independent review found no remaining blocker.

`npm test` passed: **27 native suites, 18,456 checks/assertions**, zero failures;
**100 Node passes**, zero failures, one existing external chest-source skip.
Log: `build/responsive-match-tests.log`. This includes the existing Voice focus
test unchanged and the expanded audio-flow and Match regressions.

`npm run build:web` passed, including exported-pack pronunciation checks. Startup
transfer remains **12.11 MB**, with 28 audio assets loaded on demand. The existing
licensed Unity inputs and fallback images were unchanged.
Log: `build/responsive-match-build.log`.

The frozen export was verified over HTTP at port 4181:

- Pack: `game-a65e600cb11d76d6.pck` (5,756,964 bytes).
- Pack SHA256: `a65e600cb11d76d673c59118ffc4058a6bf82d5dc4d33357b8e23dc88d613bc2`.
- HTML SHA256: `ef0e16543b8328dc0b8e2f9a08fcc7d579df61b93303221353b2c6bedfec93e8`.

Browser verification passed all four planned scenarios: the new direct-card
flow on desktop Chromium and iPhone WebKit, plus desktop voice sentence queues
and explicit Voice off/stale-event isolation. The two direct-card cases passed
in **32.8 seconds**, with zero failures, retries or skips. Screenshots confirm
visible selection, stable positions, unchanged progress when continuing, and
the final result. Recorded page/console error lists are empty.

The first desktop run selected its card correctly but failed a score screenshot
comparison: five pixels at the left edge belonged to Pip's speaking effect.
The actual badges were identical. Tightening that edge by two logical pixels
kept both score groups in the assertion; both affected device cases then passed.
The original diagnostic report and pixel-difference images remain available.

Reports: `build/responsive-match/green-report.json` (voice passes and initial
crop diagnostic) and `build/responsive-match/touch-final-report.json` (final
desktop/iPhone passes). Final images are under
`build/responsive-match/touch-final-results/`.

## Delivery

Gameplay commit `6b759cd` was fast-forwarded to `main` and pushed to
`origin/main`. `npm run deploy -- -SkipBuild` successfully deployed the frozen
export to `https://gentle-forest-02ff42900.3.azurestaticapps.net/` without
rebuilding. Log: `build/responsive-match-deploy.log`.

HTTP verification confirmed that production HTML and PCK hashes exactly match
the tested export above. The local preview at `http://127.0.0.1:4173/` was
updated with the same **71 files**, each SHA256-compared before activation;
its HTTP hashes also match. The previous local export was retained at
`D:/uwork/tesisgame/build/web-before-responsive-a65e600`.

Production smoke tests passed **2/2 in 30.0 seconds** on desktop Chromium and
iPhone WebKit, with zero failures, retries or skips. Both runs exercised the
first tap during wrong/correct feedback, keyboard focus, score protection,
retained Continue and the final result on the deployed site. Page/console error
lists were empty; production screenshots were also visually checked.
Report: `build/responsive-match/production-report.json`; screenshots:
`build/responsive-match/production-results/`.
