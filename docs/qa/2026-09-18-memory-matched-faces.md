# Memory keeps correct pairs face up

After successful feedback, `continue_feedback()` cleared the current selection,
and `is_revealed()` only checked selection and Peek. This covered a completed
pair again while retaining its green checkmarks. The model now also treats
matched word IDs as revealed. Both the picture and noun remain visible for the
rest of the round; wrong pairs and unselected cards remain concealed.

The Peek tooltip and README now explain that release hides only unmatched
cards. Score, fixed card positions, disabled matched cards and new-round reset
behavior are unchanged.

## Verification

The new browser pixel regression failed against the previous exported game:
a matched card changed 88.3% of its sampled interior when Peek revealed it.
This confirmed the test detects the reported defect rather than just checking
the score or green mark.

Six focused native suites passed: Memory model (700), Memory Garden (7,333),
Memory Peek (213), Memory scene (174), Memory back design (4,979), and shared
card polish (212). Checks cover visible front/back nodes, automatic feedback,
later mismatches, Peek release, pause/resume, compact resizing, duplicate
selection rejection, completion and reset.

All nine browser cases passed on the tested Web export: desktop Chromium,
iPhone WebKit and iPad WebKit each exercised persistent matched fronts with
normal and reduced motion, plus feedback shortcuts through a complete round.
Pixel comparisons verify matched faces remain unchanged through Peek, a later
mistake and closing More, while unmatched cards are revealed and hidden.
Desktop and phone screenshots were visually reviewed.

Local evidence: `build/voice-pop-qa/memory-faces-before*` and
`build/voice-pop-qa/memory-faces-local*`. Tested game pack:
`game-71a5c6d0a586e5c5.pck`.
