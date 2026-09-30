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

Normalization runs on the complete recognized text before token extraction,
including the vocabulary spelling `yoyo` for `yo yo` and `yo-yo`. Browser
recognition requests three alternatives, but only the first candidate can
score. Additional candidates are available only through opt-in diagnostics.

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
result revisions, alternatives, and rejection details. Detailed collection is
off by default. The game neither records audio nor persists or uploads these
diagnostic transcripts. Console export is a separate manual action.

See the [September 30 integration record](qa/2026-09-30-speech-recognition.md)
for automated coverage and the physical-device test matrix. Simulated browser
results verify integration; they do not establish real recognition accuracy
or word-end-to-feedback latency.
