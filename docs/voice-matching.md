# Voice matching

Match and Voice Pop share the explicit English homophone groups in
`scripts/speech_words.gd`. A transcript such as `bare`, `be`, `I`, `knows`, or
`symbol` can match the active vocabulary word `bear`, `bee`, `eye`, `nose`, or
`cymbal`. The browser still displays its original transcript; hits, review words,
and saved scores use the canonical vocabulary entry.

- Match checks only complete, unmatched pairs on the current board. One spoken
  token selects at most one pair, preferring exact spelling if both equivalent
  spellings are available. Repeated tokens do not enqueue the same pair twice.
- Voice Pop checks only live targets. Its existing singular/plural handling is
  preserved; equivalent plural sounds are listed explicitly. Targets with
  overlapping accepted forms cannot spawn together. The browser receives these
  same forms to keep revised interim/final transcripts attached to one spoken
  occurrence. Distinct occurrences can score distinct targets, including when
  the same word is spoken twice.
- Both modes accept reviewed space/hyphen spellings for `seahorse`, `sunflower`,
  `sunglasses`, `pinecone`, and `yoyo`. The shared `COMPOUND_PARTS` configuration
  also lists Voice Pop's legal plural variants. A compound and its component
  targets cannot be dealt or thrown together. `sun flower` can still name two
  separate targets when `sunflower` is absent; joined `sunflower` cannot.
- Matching uses complete tokens, including Unicode letters, numbers, and
  apostrophes. Substrings, possessives, and approximate spellings are not answers.
- Equivalence is based on the recognized sound, not sentence meaning. For
  example, `I` and `be` count when `eye` and `bee` are active. Some groups include
  common pronunciation variants such as `ant/aunt` and `root/route`.

The table is local game data. It adds no speech model, download, microphone
permission, or network request. Add reviewed groups and regression examples
when extending the vocabulary; do not apply fuzzy spelling or generate plurals
from aliases (`be` must not become `bes`, for example).

## Browser recognition

Voice Pop displays interim transcripts immediately but waits until a candidate
has been stable for 150 ms before scoring it. Final results can commit
immediately. Once a spoken occurrence has scored, a later spelling correction
cannot score another target. The browser binds each candidate to its current
target UID; native scoring rechecks the round, event ID, live target, and
accepted form. After a candidate's first callback, later revisions cannot
transfer it to a newly thrown card with the same word. The browser does not
provide word timestamps, so a delayed first callback cannot be attributed to
an earlier flight. This does not add scoring after a target has fallen.

The native matcher normalizes reviewed phrases against eligible target forms.
The browser aligns underlying word occurrences before choosing the longest
eligible compound span, retaining each member's original target snapshot.
Joined/spaced revisions share those occurrences; a consumed member makes the
whole revised span consumed. This prevents a corrected compound from awarding
a second hit to one of its parts. No arbitrary adjacent-word concatenation is
used. The native lexicon is sent once through `configureSpeechLexicon` rather
than maintaining a second browser alias table.

Recognition requests three alternatives, but only the first candidate can
score. Additional candidates are available only through opt-in diagnostics.

Native Pop callbacks acknowledge accepted hits through a synchronous
`receipt.accepted` property on the second callback argument. Godot discards
Callable return values across `JavaScriptBridge.create_callback`, so a return
value alone cannot confirm consumption in the browser. Diagnostic actions use
the same explicit acknowledgement in their third argument. Rejected or stale
callbacks leave the acknowledgement false.

On browsers exposing `onaudiostart`, the recognizer's `start` event only means
the service started. The game starts or resumes after `audiostart`, or a
nonempty valid result if that arrives first. An eight-second watchdog starts
after the service event, excluding time spent granting permission. Failure
stops that attempt and offers Retry. Older APIs without the capture-event
property retain their start-event fallback. Late events are checked against
the current recognizer and round before affecting the game.

Normal browser recognition does not set contextual `phrases`.

## Optional on-device experiment

Open with `?speechLocal=1` to expose the collapsed preparation controls before
a Voice Pop round or while paused. Ordinary visits do not probe, download, or
display this experiment. A manual check validates API support and calls
`SpeechRecognition.available({ langs: ['en-US'], processLocally: true })`.

If English is downloadable, the user must activate **Download English**.
`install()` runs from that gesture with the same options; a second availability
check must return `available` before the pack is considered ready. The browser
manages the download, and this API exposes no reliable byte progress. Checking
or preparing never opens the microphone. Unsupported or failed preparation
leaves ordinary browser recognition available.

Only a new round beginning with an enabled, ready pack selects
`processLocally = true`. Readiness changes and toggles do not replace the
backend within the current round. When contextual phrases are supported,
the complete round vocabulary receives boost 1 and live targets receive
boost 4. Target changes update hints without restarting; a rejected hint
configuration retries without hints. Match keeps its ordinary browser backend.

The experiment uses the browser's English pack, not the removed multiplayer
WASM runtime. API availability varies by browser and platform; iPhone and iPad
Chrome must not be assumed to support desktop Chrome's local APIs. Keep the
experiment off by default until human speech and device comparisons justify it.

## Diagnostics and validation

`wordBuddiesHost.speechDiagnostics()` returns counters and the actual backend.
Use `wordBuddiesHost.setSpeechDiagnostics(true)` to opt into bounded in-memory
result revisions, alternatives, rejection/cancellation reasons, session IDs,
and supported capture/sound/speech lifecycle events. The record ring holds
200 events; alternative text is limited to 2,000 characters. Detailed collection is
off by default. The game neither records audio nor persists or uploads these
diagnostic transcripts. Console export is a separate manual action.

### iPhone/iPad speech check

Open the game with `?speechDebug=1`, enter the game, and choose **Speech check**.
The diagnostic panel pauses the game and accepts microphone input only after
**Start listening**. It uses the ordinary browser recognizer even if the local
experiment flag is also present. Practice never expires its target, advances
the game clock, grants rewards, or saves leaderboard scores. Closing leaves a
Voice Pop round paused for explicit retry, with no automatic microphone restart.

The fixed 24-word pass includes short words, homophones, and the reviewed
compounds. The original transcript, up to three returned alternatives, and the
actual first-candidate match are shown separately. **Correct**, **Wrong**, and
**No result** review the transcription and advance the prompt without restarting
recognition. Count a valid homophone as correct. A different-word or silence
control can be selected before starting to measure unwanted target hits.

Repeat the same pass with **Normal**, **Reduced · 35%**, and **Silent** sound
levels. The first two use real launch, slice, missed-word Pip, and Match hit
assets on a fixed schedule. The reduced setting changes only these diagnostic
channels; it is not a new production-volume default. Stop listening before
changing the condition. Also compare device speakers with headphones at the
same distance and device volume. Record the device/OS version and adult/child
speaker category in **Test details**; do not enter player names.

**Copy report** is an explicit clipboard action. If clipboard access fails,
selectable report text is displayed instead. Reports remain in tab memory,
with at most 120 reviewed attempts, 12 revisions per attempt, and 500 bounded
diagnostic events. No audio is recorded and no report is persisted or uploaded.
The report includes target match rate, manually reviewed text/no-result rates,
and control false-hit rate; missing control samples produce `null`, not an
assumed zero error rate. Temporary audio gains reset and audio stops on
exit/background; the comparison form and report remain only in tab memory.

Report times are browser callback times, not captured word timestamps. A real
word-end-to-feedback measurement needs separate human observation. Normal
gameplay remains at 50 seconds with existing bonuses and the 150 ms observation
window. Desktop local phrase hints do not become available on iOS through this
diagnostic panel, and a second `getUserMedia` stream is not opened to pretend
that its audio constraints control WebKit's recognizer.

See the [September 30 integration record](qa/2026-09-30-speech-recognition.md)
and the [October 1 iOS diagnostic record](qa/2026-10-01-speech-diagnostics.md)
for automated coverage and the physical-device test matrix. Simulated browser
results verify integration; they do not establish real recognition accuracy
or word-end-to-feedback latency.
