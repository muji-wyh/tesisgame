# Forgiving matching contact in a crowded board

The reported carrot drag grazed its matching picture while overlapping bird,
walk and tooth. Physical contact with an unrelated neighbor returned before the
matching search, so the carrot picture kept only its word-family glow and the
drop could not merge it.

Dragging now selects the nearest valid match within the expanded painted contour
before considering unrelated contact. The matching margin is 28 percent of the
shorter tile side, capped at 24 screen pixels, with rounded corner expansion.
Neutral contact keeps its original painted-overlap threshold when no match is
nearby. The selected cue remains the actual release target for ordinary drags,
active fusions and the natural handoff to a completed result. Merge eligibility,
levels and rewards are unchanged. All rendering reuses the acquired artwork
recorded in [Jelly Words](../assets/jelly-words.md).

## Verification

- A copy of the preceding production script failed 68 of 316 new assertions,
  reproducing the missed diagonal target and failed advertised drop. The fixed
  interaction suite passes all 1,517 checks at 1000 x 720 and 390 x 844, with
  normal and reduced motion.
- New cases cover eight approach directions, distant matches, actual overlap
  with unrelated neighbors, an early drop during fusion, natural fusion
  completion, the consumed target and preserved neighbors.
- Full Word Jelly view: 19,482 assertions, zero failures. Neutral/rejection
  fixtures now exclude nearby valid matches so they test their original
  behavior independently of the requested matching priority.
- Drag performance contract: 40 assertions, zero failures, including one
  presentation pass per input burst and at most one eligibility check per
  partner in a pass.

Native render evidence is retained in the ignored `build/qa/crowded-match/`
directory. Identical phone input selects bird with neutral contact in the old
script and carrot with matching contact in the fixed script. Release produces
zero and one merge respectively. The active-fusion case produces its expected
two merges. Desktop and reduced-motion captures also select and merge carrot.
The before/after, active-fusion and reduced-motion contact images were visually
inspected. These are native desktop renders at the stated sizes, not physical
device recordings. No audio changes or listening claims are part of this fix.

The directory contains the baseline script and failure log, passing test logs,
five 36-frame captures, contact crops, a before/after video and release logs.
