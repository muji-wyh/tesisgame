# Original vocabulary semantic audit

**Goal:** Finish the outstanding review of the 140 original vocabulary pictures,
labels and recordings in the accepted learning plan. Fix demonstrated ambiguity
using the existing SVG artwork pipeline. Unity acquisition and final imported-art
verification remain separate open requirements.

**Scope:** The canonical `words.json` catalog and twelve topics in
`scripts/game_data.gd`. Pip's five autonomous actions and word stickers are already
implemented and deployed; this audit does not introduce another game mode.

## Work

- [x] Render and inspect every actual original illustration. Record the visible
  referent for each noun, with hashes identifying the reviewed files.
- [x] Review actual recordings with an available independent recognition/listening
  method. Record unresolved cases honestly; filenames, synthesis inputs and
  non-silence checks do not establish what a recording says.
- [x] Fix confirmed picture/label mismatches in the existing generators, regenerate
  the corresponding artwork and inspect it at learning and card sizes.
- [x] Record per-word evidence and the limits of this original-only audit; update
  the stale acquisition status in the accepted learning plan.
- [ ] Run appropriate existing checks. If shipped assets change, export once,
  inspect the affected game screens, review the diff, commit, merge, push and
  deploy the tested build. Verify the deployed pack.

## Acceptance

Each original noun has an explicit visual review result and an explicit audio
review result or unresolved status. Changes preserve the 140 stable IDs, recorded
words, five-word lessons, overlapping-word exclusions and player saves. The final
Unity-art acceptance stays unchecked until actual acquisition, CLI import and
deployed use have been demonstrated.

**Results:** Every original image was visually reviewed. Doll and brush had
ambiguous silhouettes and now show a rag doll and a visibly bristled hairbrush.
Whisper exactly transcribed 138 original nouns; sun was transcribed as the
homophone son. Both recognition engines confused the isolated kite recording with
tight. A same-voice replacement says "A kite." and passes direct-file and batch
Whisper checks; SAPI still disagrees at low confidence. The per-word QA record
preserves this limitation and does not claim human listening or recognition
consensus. See `docs/qa/2026-09-11-catalog-semantic-audit.md` and its JSON companion.
