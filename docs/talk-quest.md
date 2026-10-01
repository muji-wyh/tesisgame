# Talk Quest

Talk Quest contains twelve everyday conversations, an eighteen-line birthday boss conversation, and a twenty-line cooperative toy workshop. Adam and Yoki are the only speakers. The campaign has 170 sentences and fourteen distinct approved creature assignments.

Open the **Talk Quest** tab and choose the first unlocked adventure. Read both
characters' turns. **Speak** starts browser recognition; the current prompt and
recognized words stay visible together. **Hear line** stops the microphone and
reads the prompt using the browser's English voice. Press **Speak** again when
ready. **Type** offers the same sentence matching without a microphone; submit
with **Say it** or Enter. There is no penalty for a mistaken sentence.

**Map** pauses the adventure. **Continue saved adventure** restores the exact
line or unopened treasure, including after reloading. A pending victory or chest
must be collected before starting another adventure. Browser backgrounding and
mode changes stop listening, and resuming always waits for a new Speak gesture.
The treasure shelf shows all twenty designs; repeat a completed adventure to
earn the six additional designs. Saved progression is shared on this device.

The workshop has no health, damage, attack, or defeat logic. Before each of its five repairs, choose the correct part from three illustrated options. The parts are a wheel, a wing, a ribbon, a screw, and a winding key. A wrong choice provides friendly feedback without a penalty. Each chosen part then enables four successful lines. The requester and helper exchange roles for each toy. Choosing a part, completing a repair, and completing the workshop are separate events.

Runtime monsters use the acquired, rigged source assets documented in
[the monster provenance](assets/talk-quest-monsters.md). Environments, treasure
mechanisms, and part illustrations are original procedural art based on the
reviewed plan. Hit and friendly defeat reactions are authored gameplay motion;
they are not represented as source-pack animation clips.

## Content

`talk_quest_data.gd` returns copied dictionaries through `level(number)`, `levels()`, `chest(id)`, `chests()`, and `repairs()`. Level numbers are one-based. Each level supplies:

- `number`, `id`, `title`, `kind`, and `cooperative`.
- `scene_id` and `scene` with `id`, `name`, `accent`, `description`, and `props`.
- `monster_id`, `monster_name`, and `source_creature`.
- `chest_id` and `lines`; each line has `id`, `uid`, `speaker`, and `text`.
- Workshop lines additionally include `repair_id`, `repair_name`, `repair_index`, `repair_step`, and `role`.

The reviewed chest IDs are `chest-01` through `chest-20`. Their presentation duration is 5 seconds, with hold and reveal markers at 1.20 and 3.36 seconds. The first clear of each level uses its corresponding chest. The first six replays award designs 15 through 20; subsequent replays cycle through all twenty designs. The companion chest remains gated until the workshop has been completed.

## Model integration

The pure `RefCounted` model emits `changed` for observable state changes. Its public state includes `phase`, `level_number`, `level`, `line_index`, `hp`, `max_hp`, `round_id`, `last_transcript`, `feedback`, `repaired_toys`, `selected_parts`, `completed_levels`, `unlocked_level`, `collected_chests`, `total_clears`, and `companion_unlocked`.

| Call | Behavior |
| --- | --- |
| `start_level(number) -> bool` | Starts or restarts an unlocked conversation. |
| `current_prompt() -> Dictionary` | Returns the current line with `index`, `line_number`, and `total_lines`; empty after the last line. |
| `speech_target() -> Dictionary` | Returns `round_id` and `target_uid`; target zero means listening must not score. |
| `submit_speech_event(event) -> Dictionary` | Validates the original browser occurrence and prompt binding. |
| `submit_transcript(text) -> Dictionary` | The explicit typed practice action; uses the same sentence validator. |
| `pause()`, `resume() -> Dictionary` | Pause retains the previous stage. Resume returns that stage in `result.phase`. |
| `finish_victory() -> Dictionary` | Moves from the final animation stage to the chest stage. |
| `open_chest() -> Dictionary` | Commits one reward and one clear, then enters `complete`. |
| `current_chest() -> Dictionary` | Returns the deterministic reward for the current attempt. |
| `current_part_choices() -> Array[Dictionary]` | Returns the current workshop trio, each with `id`, `label`, and `shape`; empty outside an unfinished workshop. |
| `choose_part(id) -> Dictionary` | Selects a shown part; `accepted` indicates a processed choice and `correct` indicates that the gate opened. |
| `has_correct_part() -> bool` | Reports whether the current repair has its part; always true for ordinary conversations. |
| `is_unlocked(number)`, `is_paused()`, `is_cooperative()` | Query helpers. |
| `clear_count(number)`, `progress_ratio()` | Return a level's durable clear count and the current line progress. |
| `stop()` | Abandons the in-memory attempt; pause and checkpoint first to preserve Continue Saved. |

The stage sequence is `ready -> playing -> victory -> chest -> complete`. `paused` retains `playing`, `victory`, or `chest` privately. Presentation code completes the monster's final animation before calling `finish_victory()`, and calls `open_chest()` at the reward reveal. Both stage actions are guarded against repeated calls. The workshop uses the `victory` stage for waking, stretching, waving, and celebrating without combat.

## Speech events

External speech must supply its original binding:

```json
{
  "event_id": "recognition-occurrence-id",
  "round_id": "round-captured-when-listening-began",
  "target_uid": 1,
  "text": "Knock, knock.",
  "stage": "final"
}
```

`stage` is `interim` or `final`. An optional `received_at_ms` must be a finite nonnegative number. The browser must retain the same occurrence ID and original prompt binding when an interim result becomes final. It must not rebind a delayed result to the currently visible prompt.

Every result supplies `accepted`, `matched`, `completed`, `damage`, `repair_completed`, `reason`, `feedback`, `phase`, `line_index`, `hp`, and `cooperative`. `accepted` means valid input was processed; only `matched` advances a sentence. A successful match also supplies the completed `prompt`, its `target_uid`, and any `repair_id`. Typed practice adds `input: "practice"`.

Interim results update the visible recognition without awarding progress. Final occurrences are consumed even when their sentences do not match. One occurrence cannot advance two lines. Pause, resume, a new attempt, and restoring a save invalidate previous speech round bindings. Wrong final answers show the whole sentence again and carry no penalty.

The workshop also consumes but does not score final speech while its part gate is closed. A successful part selection creates a new `round_id`, invalidating speech captured before the choice. Stop existing recognition before selecting a part, then bind the next listening session to the new `speech_target()`. Part selection never advances a line or completes a toy by itself. Repeating an already successful selection is a no-op.

Matching compares the entire sentence after lowercasing, punctuation and whitespace normalization, and a fixed list of explicit contraction expansions. All words, negation, numbers, and Unicode letters remain significant. There is no fuzzy, substring, noun-only, or homophone matching.

## Checkpoints and privacy

Save `export_progress()` after accepted lines and stage transitions, particularly after `open_chest()`. The desktop host stores this dictionary in `user://talk_quest.cfg`; the web host uses the local storage key `wordBuddies.talkQuest`.

The save contains only a version, fourteen clear counters, and an optional unfinished run with its level, next line index, stage, next clear number, generated run ID, and `selected_parts`. The latter is an ordered prefix of canonical part IDs, such as `["wheel", "wing"]`. It never includes spoken input, transcripts, recognition event IDs, or recordings. The model derives health, completed repairs, collection IDs, total clears, and unlocks from the validated counters and line index.

`import_progress(value) -> bool` rejects an unsupported save root, bounds counters, ignores unknown fields, and rejects inconsistent pending runs. It restores a valid pending conversation, victory, or chest as `paused`; `has_saved_run()` enables Continue Saved and `resume()` restores the saved stage. Recognition state is cleared and a new speech round is generated. A chest is committed atomically with its clear count, so a stale pending reward cannot be combined with committed progress and awarded again.

Workshop saves preserve the difference between a part selected before a group's first sentence and a part not yet selected. Invalid IDs, missing required selections, or choices for future groups reject the pending run. Earlier version-one saves without the optional `selected_parts` field retain their spoken progress by inferring parts only for groups already begun.

## Verification

The model suite is `tests/godot/talk_quest_model_tests.gd`. It covers the content catalog, complete-sentence matching, speech metadata and replay protection, pause/resume, part gates and their saved selections, all campaign health and repair transitions, twenty-design reward reachability, guarded reward commits, private checkpoints, and malformed saves. Run it through the project's serialized Godot test workflow; do not run imports or exports concurrently with other Godot processes for this project.
