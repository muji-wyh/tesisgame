# SpeechRecognition integration

## Behavior under test

The existing browser speech backend remains the default for Match and Voice
Pop. It uses continuous listening and interim results, and requests up to three
alternatives. The browser may return fewer. Only the first alternative is
eligible to score; lower candidates are diagnostic evidence, not extra answers.
Match keeps its final-result scoring policy.

Voice Pop publishes the complete interim transcript immediately. A candidate
must remain stable for 150 ms before it commits, while a final result can commit
immediately. Each word occurrence retains its identity through revisions. A
second real occurrence can score a second target; correcting an occurrence
that already scored cannot award another hit. Whole-text normalization runs
before splitting words, including `yo yo` and `yo-yo` for `yoyo`.

Candidates bind to a target UID when they appear. Both the browser and native
game validate the round and target before scoring. Unknown speech, expired
targets, duplicate events, old recognition callbacks, and old rounds cannot
award hits. This work adds neither post-drop scoring nor browser-generated
word timestamps: callback time is not the time a player spoke.

The 50-second base round, combo time bonuses, player selection, leaderboard,
homophones, and canonical review words remain in use. Listening still starts
the countdown. Recognition can reconnect between utterances without the game
restarting it for each word.

## Optional desktop local experiment

Open the game with `?speechLocal=1` to expose the experiment. Ordinary visits
remain on the existing browser backend, which may process speech remotely.
The experiment uses Chrome's own English language pack rather than a bundled
WASM model or a paid speech service.

Preparation checks capability and calls:

```js
await SpeechRecognition.available({ langs: ['en-US'], processLocally: true });
```

When a pack needs installation, the user must click the preparation control.
That gesture calls `install()` with the same options and then rechecks
`available()`. Installation completion alone is not readiness. Preparation
uses named states because this API exposes no reliable byte-based percentage.
Unsupported APIs, unavailable packs, and failed preparation leave ordinary
browser recognition available.

Only a new round that starts with a ready pack uses `processLocally = true`.
Completing preparation does not replace the backend during a running or
paused round. When contextual phrases are supported, local recognition
receives the complete round vocabulary at boost 1 and the current target
words at boost 4. A change to the target set updates hints without restarting
recognition. Unsupported hints are omitted; if the browser rejects hints,
recognition retries without them. Ordinary recognition never sets `phrases`,
even if the browser exposes that property.

The local experiment remains off by default until physical-device and human
speech comparisons support enabling it. Chrome API support varies by
platform; iPhone and iPad Chrome cannot be assumed to expose desktop local
speech APIs.

## Diagnostics and privacy

The host exposes `wordBuddiesHost.speechDiagnostics()` for a current diagnostic
snapshot. Explicitly enable bounded in-memory detail collection with
`wordBuddiesHost.setSpeechDiagnostics(true)` when investigating recognition.
It records result revisions, returned alternatives, actual backend mode,
restarts, and scoring rejection reasons. Detailed collection is off by
default. No audio is recorded, and no diagnostic transcript is persisted or
uploaded by the game. Exporting browser console data for a test is a separate
manual action.

## Automated and manual validation

Automated checks cover repeated occurrences, interim replacement, homophone
revisions, stable timing, whole-text normalization, returned alternatives,
complete vocabulary, target binding, lifecycle resets, and local preparation
success/failure. Browser fixtures exercise the actual game bridge and HUD
while replacing microphone recognition. These checks establish integration
behavior, not acoustic recognition accuracy.

The focused Voice Pop browser cases check that ordinary recognition never
sets unsupported phrase hints, an interim word is displayed before scoring,
a corrected committed occurrence cannot score twice, and a lower alternative
cannot produce a hit. The local-preparation case uses the actual availability
and download controls with simulated browser pack APIs: an unprepared round
uses ordinary recognition, preparation does not open the microphone, and the
next ready round supplies the full vocabulary plus stronger active-target
hints without restarting recognition. Existing cases continue to cover full
interim sentences, finalization, failures, mode changes, and obsolete callbacks.

Physical-device and real-person speech testing is still required. Test desktop
Chrome, Android Chrome, and iPhone/iPad Chrome with adults, children, varied
accents, short words, similar pronunciations, consecutive words, and normal
game audio. Compare the stability-window change separately from the local
experiment. Record valid-word coverage, wrong-target hits, duplicate scores,
and measured word-end-to-feedback latency; human audio/video review is needed
to establish word-end timing. No acoustic accuracy or physical-device latency
improvement is claimed by the automated tests.

## Recorded verification

- Voice Pop model: 30,220 assertions passed (`build/speech-api-model.log`).
- Voice Pop scene: 1,606 checks passed (`build/speech-api-scene.log`).
- Match voice model: 654 assertions passed (`build/speech-api-match.log`).
- Match voice feedback: 205 assertions passed (`build/speech-api-match-feedback.log`).
- Browser speech host: 77 tests passed (`build/speech-host-upgrade-tests.log`).
- Local preparation helper: 17 tests passed, including native control input
  isolation. Preparation, export, and test-runner contract checks also passed
  (`build/speech-api-local-node.log`).
- Web export succeeded with all 326 required audio paths verified
  (`build/speech-api-build.log`). Exported speech function blocks were refreshed
  from the final source after the last bounded-history change; the verified
  native pack and engine were unchanged.
- All 15 focused Voice Pop browser cases passed across desktop Chromium,
  iPhone WebKit emulation, and Android Chromium emulation. The initial run
  exposed two Android test timing races: protocol round trips outlasted the
  selected targets. The revised tests observe the real stability timer and
  native scoring within the page; all six affected platform/case combinations
  passed on rerun (`build/speech-api-browser-recheck.log`). No game timing or
  scoring assertions were relaxed. The rerun used a 180-second per-test budget
  for software rendering and navigation; live recognition deadlines were unchanged.
- The experimental preparation panel was visually checked at all three tested
  viewport sizes using the `local-speech-ready.png` artifacts under
  `build/speech-api-browser/`.
- Match homophone feedback passed on all three browser configurations after
  replacing the test's lengthy room keyboard traversal with real touch controls
  (`build/speech-api-match-browser-recheck.log`). The initial Android run
  exhausted its 90-second test budget before recognition began. Word matching,
  audio, lightning feedback, and duplicate-score assertions remain intact.
  In total, all 18 selected browser cases passed after these test-harness fixes.

These artifacts are local build outputs, not source-controlled recordings.
