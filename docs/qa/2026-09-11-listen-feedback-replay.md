# Listen feedback keeps the large replay button usable

The user's screenshot showed a disabled `Hear the word` button after answering
`tuba`, even though the smaller feedback card could replay it. The large
button's click handler, enabled state and navigation list were all restricted
to the asking state.

The same large button now stays usable during wrong, correct and final
feedback, with the label `Hear again`. It replays the current target through
the existing feedback pronunciation path, preserving the visible question,
feedback, answer positions and scores. Continue remains the default focus
after grading. Paused, hidden, stopped, finished, silent and Sky states retain
their input guards. Losing or restoring audio during feedback also updates
the main replay button and written target in place.

## Verification

Before the fix, the focused native regression reported 13 failures in 437
choice assertions and three failures in 62 audio-flow assertions. After the
fix, all 440 choice assertions and 62 audio-flow assertions passed. The audio
checks stop the existing voice before pressing the actual large Hear button,
then confirm that the displayed target's audio stream starts again. Logs:
`build/listen-replay-native-red.log` and `build/listen-replay-native-green.log`.

`npm test` passed all 27 native suites (18,590 checks/assertions, zero failures)
and 100 Node tests, with one existing external chest-source skip. Independent
code review found no blocker. Log: `build/listen-replay-tests.log`.

The browser regression reproduced the bug in desktop Chromium against the
previous export: clicking the large Hear button after a correct `fish` answer
left the old `Yes! fish` status unchanged throughout the 10-second assertion
window. The iPhone WebKit runtime did not provide AudioContext and was
explicitly skipped in that reproduction; this is not counted as replay
coverage. Browser evidence is under `build/listen-replay/red-report.json`
and `red-results/`.

`npm run build:web` passed, including 140 word pronunciations and 56 optional
path checks. Startup transfer remains 12.11 MB with 28 on-demand audio assets.
No image or audio assets changed. Log: `build/listen-replay-build.log`.

The frozen export was verified through HTTP on port 4181:

- Pack: `game-1f8f7df8271f7e70.pck`.
- Pack SHA256: `1f8f7df8271f7e70bfe8ddf1288e9af93972290346502ad3a5b0e735b9a8e986`.
- HTML SHA256: `940b1ab2274f5baf56c7ee5bde0cc226b811efd2b73047620692d2604c5acb2b`.

All three local browser cases passed in 44.2 seconds, without failures,
skips or flaky cases: desktop and mobile Chromium exercised the large Hear
button with real touch input in wrong and corrected feedback, followed by
safe answer-driven advance; iPhone WebKit verified the written-target audio
fallback. Replay preserved progress, answer artwork and the feedback card in
pixel comparisons. Phone screenshots were inspected independently and show
the enabled `Hear again` button in its original location. Evidence:
`build/listen-replay/green-report.json` and `green-results/`.

## Delivery

Gameplay commit `c7a4dd2` was fast-forwarded into `main` and pushed to
`origin/main`. The local preview at <http://127.0.0.1:4173/> was updated from
71 staged files whose hashes matched the tested export. HTTP verification
confirmed the same HTML and PCK hashes recorded above. The previous preview
is retained at `D:/uwork/tesisgame/build/web-before-listen-1f8f7df`.

`npm run deploy -- -SkipBuild` successfully deployed the frozen export to
<https://gentle-forest-02ff42900.3.azurestaticapps.net/>. The production HTML
and PCK were fetched and matched both SHA256 values above. Deployment log:
`build/listen-replay-deploy.log`.

The same three browser cases then passed against production in 51.8 seconds,
with zero failures, skips or flaky cases. The production mobile screenshot
also confirms the enabled replay button and unchanged feedback layout.
Reports and screenshots: `build/listen-replay/production-report.json` and
`production-results/`. This delivery record is a documentation-only follow-up;
the tested export was not rebuilt or redeployed for it.
