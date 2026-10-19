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

`scripts/jelly_footprint.gd` measures the supplied real font at 16 displayed
pixels and a 32-pixel cell pitch. `plan(text, font, break_offsets, insets,
reserved)` chooses the smallest area within one to six columns and one to two
rows, preferring one row on equal area. Pass actual image/badge reservations;
`reserved.x` removes text width and `reserved.y` removes text height.

The planner preserves all spelling and uses only approved breaks. An exceptional
unbreakable token receives a six-by-two footprint and `requires_read: true`, with
the unchanged spelling. The view must expose the paused, scrollable Read detail;
this planner does not itself render that view. Cache footprints for the round.
Viewport resizing must not recompute logical dimensions.

## Word Jelly integration

`WordJellyModel.configure` accepts reviewed `word.morphology` only when its sense
ID and exact text match the word. Invalid reviewed data fails configuration.
`uses_authored_morphology()` identifies rounds containing reviewed analyses;
legacy and authored pieces may coexist, but cannot cross their merge rules.

`parts_compatible(left, right)` answers logical compatibility for board and
preview cards. `can_merge(left, right)` checks a playable merge, including the
authored result's full placement. `merge_candidate(left, right, check_space = true)` uses the same
resolver and returns `invalid`, `partial`, `complete`, or `needs_room`, plus a
physical result preview when accepted. Neither query allocates IDs or mutates
the board. `compatible_pairs(check_space = true)` limits hints to settled,
unreserved board pieces and results that can fit. A `needs_room` attempt keeps
the original pieces and does not emit an incorrect-answer cue.

Authored tiles carry their semantic state in `composition`. Their `kind` is
`part` until complete, then `word`; partial `word` data is empty. Physical
`width`, `height`, `preferred_width`, and `preferred_height` stay fixed through
gravity, repositioning, and drag cancellation. `label_lines`,
`approved_break_offsets`, and `requires_read` are the frozen measured layout.
`label_reserved_width` reserves 12 reference pixels for a badge and 24 more for
a completed word's picture, in addition to 4/3/4/3-pixel text insets.

Fusion events carry `composition_status`. A partial fusion has an empty `word`
payload and no reward, completed-word speech, collection count, or mastery.
Manually composed whole words emit eligible evidence only on collection.
Atomic whole-word exposure and assisted completion remain collectable without
emitting spelling or mastery evidence. All Word Jelly bonus wins use the
legacy two-part category (50 coins), at the existing one-percent chance,
independent of component count or footprint. Receipt reservation and retry
continue to provide exactly-once settlement.

An optional `commit_collection(payload)` callback gates every collection,
including a zero-coin collection, on durable persistence. Its isolated payload
includes `event_id`, the current round `generation`, the complete tile snapshot
in `a`, `word`, `coins`, `fragments`, and the collection-batch metadata. The
adapter can use `a.composition` to distinguish unassisted composition, assisted
completion, and atomic exposure. It must persist the exposure and any wallet
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

The authored preview is a six-element lane array, not six required cards. An
anchor contains the tile plus `preview_column` and `preview_span`. Its covered
lanes contain `{reservation: tile_id, anchor: column}`; unused lanes are empty
objects. The FIFO head waits for contiguous lanes and never displaces shown
cards. A wave snapshots advertised IDs before admission so refilled cards do
not depart in that wave. Admission tests the full width and height through the
advertised columns, retaining blocked identities and fragments. Consecutive
arrivals wait for the preceding body's full height to clear every shared lane.

The next wave's timer is the existing 20-to-10-second collection-stage baseline
multiplied by `max(1, preview_area / 6)`. It is frozen until the next successful
wave. Atomic collection advances the stage once; partial fusion never does.
The initial board uses an 18-cell occupied-area budget for authored rounds.

## Rollout

Growth Word Jelly receives only the independently reviewed overlay described
in [Growth morphology](growth-morphology.md). Its resolver decorates each real
vocabulary record before filtering; pending and invalid entries cannot enter
the round or fall back to midpoint spelling chunks. The generated index and
release audit record how much of the 1,550-entry individual review is complete.
Whole-form exposure does not grant composition mastery. Legacy model-only
fixtures retain historical behavior for regression comparison. Professional
pilot analyses with pending review remain ineligible for the reviewed
composition path.

Run the focused native suite with:

```text
node tools/run-godot.cjs --headless --path . --script res://tests/godot/morphology_tests.gd
node tools/run-godot.cjs --headless --path . --script res://tests/godot/word_jelly_morphology_tests.gd
```
