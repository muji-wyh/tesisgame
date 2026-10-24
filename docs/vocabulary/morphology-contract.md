# Authored morphology contract

`scripts/morphology_analysis.gd` validates morphology schema 1. It does not infer
parts from spelling, execute suffix-stripping rules, or establish editorial
correctness. Pending content can be structurally audited with
`compile(value, false)`. Playable resolver configuration requires reviewed
content by default. The executable examples in `tests/godot/morphology_tests.gd`
are test fixtures, not approved production vocabulary.

## Data

Each lexeme's `morphology` object has these fields:

| Field | Contract |
| --- | --- |
| `schema` | `1` |
| `id` | Stable analysis ID, unique in the round |
| `lexeme_id` | Canonical lexical sense ID |
| `text` | Exact completed spelling, including case, spaces, punctuation, and digits |
| `kind` | `atomic`, `morphological`, `compound`, or `phrase` |
| `review` | Object with explicit `status: pending` or `status: reviewed`; retain reviewer and evidence here |
| `parts` | Ordered array of distinct local part occurrences |
| `nodes` | Authored ordered binary composition DAG |
| `roots` | IDs of alternative complete nodes; each must cover all parts and spell `text` exactly |

A part has `id`, `canonical_id`, `type`, `canonical`, `surface`, and optional
`break_offsets`. Supported types are `atomic`, `root`, `stem`, `prefix`, `suffix`,
`compound`, `combining_form`, `word`, and `abbreviation`. Canonical identities
distinguish meanings; local occurrence IDs distinguish repeated phrase tokens.
For example, the two occurrences of `very` in a phrase have distinct local IDs
but may share a canonical identity.

A node has `id`, `left`, `right`, `surface`, `rule`, and optional `break_offsets`.
Both children must cover adjacent ordered spans without overlap. `surface` is
the exact authored result: `happy` plus `-ness` produces `happiness` only when
that output is explicitly authored. The `rule` field describes the editorial
choice; the engine does not turn it into a generative spelling algorithm.
Alternative binary paths may converge on the same result signature.

Break offsets are increasing Unicode character offsets inside the exact
surface. They authorize display wrapping, not additional Jellies. Include
reviewed phrase-space boundaries explicitly. A space, hyphen, or apparent
suffix does not authorize a break by itself. Reviewed classical combining
forms require nonempty `review.references`; meaningful source and subject
review remain editorial responsibilities.

An atomic entry has one part, no nodes, and its part ID as its only completion
root. `MRI` uses `kind: atomic`, a part of type `abbreviation`, and the exact
surface `MRI`. It is never decomposed into individual letters.

## Resolver API

`scripts/morphology_resolver.gd` exposes:

- `configure(analyses, require_reviewed = true)`: validate and install a catalog.
  Failure leaves the last valid catalog intact and sets `error`.
- `source_tiles(analysis_id)`: fresh part states with typed canonical metadata.
- `resolve(left, right, placement = Callable(), board = [])`: return
  `invalid`, `partial`, `complete`, or `needs_room` with an isolated result.
- `compatible_pairs(tiles, placement = Callable())`: the same legal ordered
  joins for hints and compatibility highlighting.
- `completion_plan(tiles, placement = Callable(), maximum_states = 1024)`:
  find a shortest successful completion path without modifying the board.

Tile states contain `signature`, `text`, ordered `part_signatures`, `part_count`,
approved `break_offsets`, graph `candidates`, `lexeme_ids`, `complete`,
`lexeme_id`, `composed`, `assisted`, `mastery_eligible`, `fragments`, and ordered
`origins`. Source states also expose `part_type`, `canonical_id`, and
`canonical`. The game may add physical IDs, positions, and supply metadata.
Origins may be augmented with supply-group identity before composition.

The canonical part hash includes the canonical sense ID and form, and excludes
contextual type, local occurrence IDs, and supply groups. A base may therefore
be atomic in one target and a stem or compound component in another.
Composition hashes include ordered canonical part hashes and the exact surface.
Equivalent source pieces can therefore combine across groups, while different
senses, spellings, and component order remain distinguishable. Returned
dictionaries are isolated snapshots; changing them cannot rewrite the rules.

Atomic source states are immediately complete but have no mastery evidence.
Partial states remain mergeable and never become mastery evidence. Completion
from unassisted composition is eligible evidence; callers still own assessment
policy, collection receipts, speech, and reward settlement. Assisted ancestry
is propagated and cannot establish mastery.

The placement hook receives four isolated snapshots:
`(left, right, result, simulated_board)`. Return `false` or `{ok: false}` when
the full footprint cannot be placed; both original inputs remain intact.
Return `{ok: true, placement: {column, row, width, height}}` to carry physical
placement into later plan steps. The hook must reserve/exclude input footprints
against its supplied board, without mutating live state.

Auto merge planning reports `placement_checked: false` when no hook was supplied.
Such a semantic plan is not sufficient authorization to charge. The caller must
check the entire placed path before purchase and revalidate live state before
execution. Steps use `input:N` and `step:N` references. Search is bounded by
1,024 queued states and 16,384 ordered pair checks; exhaustion returns
`unavailable/search_limit`, never a fabricated plan.
Every intermediate in an accepted plan must be consumed into its completed
target. An unrelated partial cannot be used merely to free placement space.

Different outputs for the same input signatures return `ambiguous_surface`.
Different completed sense IDs for one result return `ambiguous_sense`. The round
content resolver must select one intended sense and spelling form before play.

## Footprints

Word Jelly assigns every source, partial composition, and completed word the
same one-by-one footprint. This preserves the former ordinary Jelly size in the
responsive five-column, eight-row well, with a 1:1 aspect ratio for every jelly.
Semantic part count never changes size.
Merges reserve the same cell geometry used by their animation, collision, gravity,
and preview. Resizing changes display scale, not logical dimensions.

Compact labels preserve exact spelling and approved breaks, use at least 13
physical pixels, and show an ellipsis when needed. The full spelling remains in
the accessible name and the paused Read detail, reached by holding an overflowed Jelly for
450 ms or pressing R while focused. Quick collection and drag gestures retain
their existing behavior.

`scripts/jelly_footprint.gd` remains a general measured-text helper: its standalone
`plan` API measures at 16 pixels and a 32-pixel reference pitch, choosing a
one-to-six-column, one-to-two-row rectangle. Word Jelly uses its authored wrapping
helper only; this planner no longer decides gameplay body dimensions.

## Word Jelly integration

`WordJellyModel.configure` accepts reviewed `word.morphology` only when its sense
ID and exact text match the word. Invalid reviewed data fails configuration.
`uses_authored_morphology()` identifies rounds containing reviewed analyses;
whole-word fallback roots and reviewed parts may coexist; only reviewed graphs split words.

`parts_compatible(left, right)` answers logical compatibility for board and
preview cards. `can_merge(left, right)` checks a playable merge, including the
authored result's full placement. `merge_candidate(left, right, check_space = true)` uses the same
resolver and returns `invalid`, `partial`, `complete`, or `needs_room`, plus a
physical result preview when accepted. Neither query allocates IDs or mutates
the board. `compatible_pairs(check_space = true)` limits hints to settled,
unreserved board pieces and results that can fit. A `needs_room` attempt keeps
the original pieces and does not emit an incorrect-answer cue.

Authored root tiles carry their semantic state in `composition`. Game tiles add
`jelly_kind` (`root`, `picture`, or `merged`), `display_text`, `word_candidate`,
`image_word`, `merge_level`, `mastery_eligible`, and `assisted`. Root captions
add positional edge hyphens without changing the resolver's exact spelling.
Only merged tiles have nonempty `word` and levels 1 through 6. Picture tiles
have `image_word` but no visible text. Completed pictured roots remain roots
until they match that exact picture sense. Image-free complete words become
merged immediately. All physical footprints remain one ordinary cell.

The hybrid planner combines reviewed root paths, their final picture join, and
same-sense upgrades that add the two input levels, including different levels.
The combined level must not exceed nine; Lv9 cannot upgrade. Its queries neither
mutate the board nor allocate identities. Fusion events carry `composition_status`
and `merge_kind` to distinguish roots, pictures, and upgrades. Root assembly
waiting for a picture gives no completed-word speech or collection reward.
Manual picture matches and composed image-free words become eligible for
learning evidence only on collection. Image-free atomic exposure and assisted
completion remain collectable without mastery. Any assisted constituent keeps
the upgraded result assisted. Levels do not multiply learning credit.

Word Jelly collection bonuses depend on the merged level, independently of
component count or footprint. Lv1 has no bonus. Lv2–9 respectively have a 2%,
4%, 12%, 20%, 30%, 40%, 50%, or 80% chance of 50, 100, 150, 200, 250, 300,
350, or 450 coins. Each eligible collection reserves one roll; receipt reservation
and retry provide exactly-once settlement. Collect starts ready words at 140 ms
intervals without pronunciation.

An optional `commit_collection(payload)` callback gates every collection,
including a zero-coin collection, on durable persistence. Its isolated payload
includes `event_id`, the current round `generation`, the complete tile snapshot
in `a`, `word`, `coins`, `fragments`, `merge_level`, `mastery_eligible`, and
collection-batch metadata. The adapter uses these game-level fields and
`a.assisted` to distinguish manual matching, assisted completion, and exposure. It must persist the exposure and any wallet
reward together before returning `{ok: true}`. Supplying this callback replaces
the legacy coin-only `credit_collection` callback.

Return `{pending: true}` for asynchronous storage, then acknowledge with
`resolve_collection_commit(event_id, generation, response)`. A successful
response is `{ok: true}`; `{ok: false, error: "..."}` preserves the original
body, receipt identity, and reward roll for manual retry, and stops the current
collection batch. Invalid responses also fail without consuming the body.
Pending collections submit only once while unrelated animations and merges
continue. Duplicate, missing, and previous-generation acknowledgments are
ignored. A success received while paused remains confirmed until resume or
round completion, without a second persistence call. Manual finish and danger
completion wait for pending storage, so the final result includes accepted
collections. Callbacks may acknowledge synchronously because the obligation is
installed before the callback runs.

`authored_completion_plan(captured_only = false)` checks every step's full
rectangle before Auto merge can charge. An available partial alone is not
enough. During an accepted sequence, steps run one at a time and gravity waits
until completion, preserving the checked geometry. The selected steps remain
pinned until that target completes, even if a different word becomes placeable
partway through. Pause and exit draining
retain the accepted obligation; the result records assisted ancestry.

The authored preview is a five-element lane array with up to five cards. An
anchor contains the tile plus `preview_column` and `preview_span`. Its covered
lanes contain `{reservation: tile_id, anchor: column}`; unused lanes are empty
objects. The FIFO head waits for contiguous lanes and never displaces shown
cards. A wave snapshots advertised IDs before admission so refilled cards do
not depart in that wave. Admission tests the full width and height through the
advertised columns, retaining blocked identities and fragments. Consecutive
arrivals wait for the preceding body's full height to clear every shared lane.

The next wave's timer is the existing 20-to-10-second collection-stage baseline
multiplied by `max(1, preview_area / 5)`. It is frozen until the next successful
wave. Atomic collection advances the stage once; partial fusion never does.
The initial board uses a 15-cell occupied-area budget for authored rounds,
within the well's 40-cell capacity.

## Rollout

Growth Word Jelly receives only the independently reviewed overlay described
in [Growth morphology](growth-morphology.md). Its resolver decorates each real
vocabulary record before filtering; pending and invalid entries cannot enter
the round or fall back to midpoint spelling chunks. The generated index and
release audit record how much of the 1,550-entry individual review is complete.
Image-free whole-form exposure does not grant mastery. Model fixtures use
explicit word-picture pairs or reviewed composition graphs. Professional
pilot analyses with pending review remain ineligible for the reviewed
composition path.

Run the focused native suite with:

```text
node tools/run-godot.cjs --headless --path . --script res://tests/godot/morphology_tests.gd
node tools/run-godot.cjs --headless --path . --script res://tests/godot/word_jelly_morphology_tests.gd
```
