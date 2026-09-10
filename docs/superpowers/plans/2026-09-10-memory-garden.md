# Memory Garden Implementation Plan

> **For agentic workers:** Use coordinated subagents for the independent model and view; root integrates and verifies release.

**Goal:** Add a replayable spatial-memory word-picture game with a growing garden and ordinary saved rewards.

**Architecture:** A RefCounted memory model and a standalone Control feed the existing main scene. Existing WordCard and WordLesson render the associations; the existing chest transaction persists rewards.

**Tech Stack:** Godot 4.7 GDScript, existing Node 24 tools and Playwright. No added dependencies.

**Spec:** `docs/superpowers/specs/2026-09-10-memory-garden-design.md`

## Contracts and tasks

- [x] Implement `scripts/memory_game_model.gd` and `tests/godot/memory_model_tests.gd`. `reset(words: Array, seed_value: int = -1) -> bool` requires exactly five valid, unique and non-confusable word records. `select(index: int) -> String` returns ignored/selected/cancelled/reselected/correct/wrong. `continue_feedback() -> String` returns ignored/ready/won. `set_study(value: bool) -> bool`, `is_revealed(index: int) -> bool` and `stop()` complete the input API. Public state: cards, selected_indices, matched_word_ids, feedback_words, attempts, mistakes, last_correct, phase, studying, error. Cards use `{id, kind, word}`; phase is waiting/matching/feedback/won/stopped. Correct pairs are recorded during feedback; only Continue after the fifth match reaches won.
- [x] Implement `scripts/memory_garden.gd` and `tests/godot/memory_garden_tests.gd`. Public API: `start_round(words, palette, seed_value=-1)`, `pause(value)`, `stop()`, `controls()`, `set_palette(palette)`, `set_audio_available(value)`, `set_reduced_motion(value)`, `continue_feedback()`. Public `memory` holds the model; `card_buttons`, `study_button`, `feedback_view`, `status_label` expose real controls for scene tests. Signals: `card_revealed(word, kind, index)`, `answer_chosen(words, correct)`, `progress_changed(successes, attempts)`, `round_finished(won, found_words)`, `hear_requested(word)`, `prompt_ready`. The view owns deterministic status copy and emits prompt_ready whenever its available controls/status change. It never writes rewards.
- [x] Integrate Memory as the fifth mode in `scripts/game_ui.gd`. Reset/visibility/focus/theme/audio/pause/lifecycle routes include it. Memory progress uses five successes and hides the three-mistake HUD. Memory result calls the existing win path only once, does not mark vocabulary missed, and preserves the lesson and chosen world.
- [x] Add scene integration tests, the three native scripts to npm test, and browser tests. Update shared mode-coordinate helpers from four to five tabs; verify other modes remain reachable. Use real announced card reveals to solve the board without a hidden game-state API. Run native baseline, targeted checks, then full native/Node and browser regression suites after integration.
- [x] Review screenshots and fix actual layout/input findings; independently review the final diff. Update README and QA evidence. Commit, fast-forward main, push and deploy the exact verified build; compare production pack hash and exercise Memory on production before marking complete.
