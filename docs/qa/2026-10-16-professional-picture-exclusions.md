# Professional picture-choice exclusions

The content resolver now prevents authored overlapping meanings from appearing
together in a Professional picture-game pool. A clear illustration of putting
goods into a bag can correctly answer both *bag* and the broader *pack*; different
labels alone do not make such a choice fair.

## Authoring contract

`Lexeme.media.image.confusable_with` is an optional array of unique canonical
sense IDs. Declare a pair when the current definitions and intended pictures
can make either answer valid, including broader/narrower meanings. The runtime
treats a declaration as symmetric, so authors do not need to duplicate an edge.
Do not infer exclusions from spelling, shared substrings or antonymy. Record
the rationale and exact entry versions in the editorial provenance. Revisit
asset-sensitive pairs when the actual illustrations and crops are available.

Unknown IDs, self references, duplicate IDs and malformed lists fail authoring
validation even in draft content. Runtime readiness rejects malformed lists,
duplicates and self references; global references are checked by the authoring
validator without requiring a cross-course runtime preload.

After seeded ordering, Match, Memory, Jelly Match and Voice Pop receive a
compatible pool. A pair declared in either direction cannot coexist, and each
displayed spelling appears at most once. Alternative senses with the same label
remain candidates until compatibility is resolved; early deduplication could
discard the only sense that belongs to a valid pool.
The first compatible candidates preserve the seed's order. If greedy selection
misses the five-entry minimum for Match or Memory, a bounded-depth search over
the module's at most 50 candidates checks whether a valid minimum exists. A
genuinely insufficient pool returns `mode_unavailable`; it never fills the
round with ambiguous choices. Jelly Match and Voice Pop need one eligible term.

Word Jelly and Phrase Builder retain their existing content. The full library,
module membership and completion requirements retain all senses. A term omitted
from one seeded round can appear in another when it has a feasible pool. Voice Pop consistently respects
`picture_suitable`, matching the other picture-based modes.

Exclusions do not approve artwork, definitions, morphology, audio, professional
practice or module release. Actual card-size and choice-set inspection remains
required. Seven production pairs are integrated with exact editorial provenance
in `data/professional/provenance/retail-picture-exclusions-2026-10-16.json`.
Sole/heel and handle/strap are conditional crop safeguards, not synonym claims.

## Per-sense reachability

Each Match/Memory candidate now needs a compatible five-label set containing
that exact sense. A broad meaning that conflicts with all five narrower meanings
cannot obtain a recognition objective simply because the narrower meanings form
a valid round. Candidate sets are specific to the mode and module. The authored
validator and runtime apply the same rule, including symmetric exclusions and
case/space-normalized displayed labels.

Requirements retain all fifty terms and collect only feasible assessed skills.
Jelly Match can provide a singleton recognition route; Voice Pop provides
speaking instead. A local Phrase focus can provide contextual assessment.
Atomic Word Jelly collection remains exposure and cannot rescue a term with no
scored route. A module containing such a term fails closed before gameplay;
authoring reports `exercise.module_unreachable` and release validation rejects
it. Existing earned completion receipts and historical requirements are untouched.

This correction changes no lexeme, source image, exclusion edge or curriculum
membership. It does not make an unreviewed module playable.

Seven Node picture tests passed, including comparison with exhaustive five-choice
enumeration across 64 small exclusion/duplicate-label graphs. Six targeted
content regressions passed with zero failures/skips. Five native suites passed
549 checks (42 content, 358 picture, 52 adapters, 18 loader and 79 application
flow), zero failures. The native cases exercise actual requirements, atomic and
speaking distinctions, every seeded order of a same-spelling fallback fixture,
and unchanged full libraries. Relevant input hashes stayed unchanged for both
recorded batches. Evidence is in
`build/professional-english/picture-feasibility-review/{content,native}-validation.json`.
The seven-test Node picture result was observed in tool output rather than a
separate persisted log. These are eligibility checks, not new visual or audio
quality claims.

## Exact-search performance follow-up

Independent review found that valid fifty-term modules with only four compatible
groups could spend several seconds searching for a nonexistent five-choice
witness. The resolver and authoring helper now normalize labels and build the
symmetric compatibility graph once. A proper-coloring bound rejects impossible
branches; an inconclusive bound still runs the exact ordered search. Alternative
same-spelling senses remain available until the witness is established.

Root reviewed the final implementation, including the fifty-term runtime limit,
symmetric edges, candidate order, and the distinction between a pruning bound
and an actual witness. A regression using two joined five-cycles verifies that
enough colors cannot falsely establish reachability. No further actionable
correctness finding remained.

Measured headless native checks fell from 5,698 ms to 1.786 ms for the four-group
fixture, and from 4,961 ms to 1.319 ms for the four-label fixture. The unrestricted
fifty-term sample fell from 82.713 ms to 5.840 ms. These are local timing samples,
not a guaranteed latency bound.

Nine Node tests, 1,000 ordered-equivalence cases, and five native suites totaling
576 checks passed. The native input hashes stayed unchanged. Evidence is in
`build/professional-english/picture-performance-review/summary.json` and
`native-validation.json`; the earlier feasibility receipts remain unchanged.

## Earlier exclusion verification

The new Node authoring checks and existing runner-inventory checks passed 7/7,
with zero failures or skips. This result was observed in tool output; there is
no separate persisted log for that invocation.

Five native suites passed with the same ten input-file hashes before and after:

| Suite | Checks | Failures |
| --- | ---: | ---: |
| Learning content | 42 | 0 |
| Picture exclusions | 303 | 0 |
| Game adapters | 52 | 0 |
| Round loader | 18 | 0 |
| Application flow | 79 | 0 |
| Total | 494 | 0 |

Coverage includes either declaration order across seeded rounds, deterministic
replay, nonmutation, full library/requirements retention, non-picture modes,
malformed metadata, impossible pools and a broad first choice that would hide a
valid five-entry pool under greedy selection. Independent code review found no
actionable defect in these mechanics. No new visual or audio quality claim is
made by these tests.

Evidence: `build/professional-english/picture-exclusions-review/native-validation.json`
and its five per-suite logs. The receipt reports `unchanged: true`, no failure,
and records these implementation hashes:

| File | SHA-256 |
| --- | --- |
| `scripts/learning_content_resolver.gd` | `b6f675f78e6f74bc310acc0b228f75ba584972672fd433846d04d2d954fcd199` |
| `data/professional/schemas/common.schema.json` | `4d27b5255e854f57be7a1778bc3aec6c467d0777c44f79ec8219ae617f6c8113` |
| `tools/validate-professional-content.cjs` | `e179b8f89796fae6538124df26735d95ce0894fada24f5e691cdc9be10a6b96e` |

The permanent regressions are `tests/professional-picture-exclusions.test.cjs`
and `tests/godot/professional_picture_exclusions_tests.gd`, both registered in
the vocabulary test group.
