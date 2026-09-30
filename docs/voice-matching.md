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
  same forms to prevent revised interim/final transcripts from hitting twice.
- Matching uses complete tokens, including Unicode letters, numbers, and
  apostrophes. Substrings, possessives, and approximate spellings are not answers.
- Equivalence is based on the recognized sound, not sentence meaning. For
  example, `I` and `be` count when `eye` and `bee` are active. Some groups include
  common pronunciation variants such as `ant/aunt` and `root/route`.

The table is local game data. It adds no speech model, download, microphone
permission, or network request. Add reviewed groups and regression examples
when extending the vocabulary; do not apply fuzzy spelling or generate plurals
from aliases (`be` must not become `bes`, for example).
