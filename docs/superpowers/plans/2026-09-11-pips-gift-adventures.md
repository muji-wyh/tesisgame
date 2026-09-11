# Pip's Gift Adventures Implementation Plan

> **For agentic workers:** Use subagent-driven development for the independent
> state/model and room-view tasks; root owns host integration and release.

**Goal:** Make practice purposeful by choosing a gift, learning its word, earning
it through existing games, then playing a short interactive sequence with Pip.

**Architecture:** Extend existing playroom persistence and model lesson selection.
The room emits a gift request; game_ui coordinates save, lesson and reward flow.
Room toy stages remain transient presentation state, with no new saved economy.

**Tech Stack:** Godot 4.7.1, existing Node/Playwright, Azure Static Web Apps.

**Spec:** `docs/superpowers/specs/2026-09-11-pips-gift-adventures-design.md`

## Global constraints

Preserve existing saves, learning-word continuity, one-piece rewards, pending
chests, imported art, controller/keyboard/touch support and reduced motion.
No dependencies or new external assets. Do not alter the header/playfield geometry.

## Task 1: Saved gift goal and lesson selection

Files: `scripts/playroom_state.gd`, `scripts/game_model.gd`, their existing native tests.
Interfaces: `goal_item_id: String`; `set_goal(id: String, counts: Dictionary) -> bool`;
`selected_goal(counts: Dictionary) -> Dictionary` returns the catalog entry with
`remaining_pieces` (zero when owned). `set_goal` validates a locked gift and saves
its theme as `preferred_theme_id` atomically. Empty/unselected goal returns `{}`.
Extend `Model.reset(..., required_word_id: String = "")` without changing default
behavior; a new lesson must include the known required word and exclude confusables.

- [x] Add failing behavior tests for migration, atomic failed save, preservation
  during other room/sticker writes, exact multi-medal progress and completed goals.
- [x] Implement optional goal persistence and derived progress using catalog/medals.
- [x] Test and implement required lesson nouns for all six worlds while preserving
  the default seed/repeat semantics and five unique compatible words.

## Task 2: Room goal controls and three-step toys

Files: `scripts/playroom_view.gd`, `tests/godot/playroom_view_tests.gd`.
Interfaces: new `goal_requested(id: String)` signal and `goal_button: Button`,
included in `controls()` for existing host input/focus wiring. Keep existing
signals and public controls. Use state `selected_goal(counts)` to show resume/use.

- [x] Add failing checks for locked goal request, ready-goal use, guard against
  swipes/hidden room, and all toy stage/replay/quiet-motion outcomes.
- [x] Add the contextual goal button and noun-specific three-step interaction;
  retain Back, generous targets and the shared Pip slot.
- [x] Verify stage results are visually distinct with and without motion and
  repeated input cannot stack processing or award progress.

## Task 3: Host integration and actual browser loop

Files: `scripts/game_ui.gd`, new `tests/godot/gift_adventure_tests.gd`,
new `tests/browser/gift-adventure.spec.cjs`, `package.json`, README and web help.
Root adds a required-word argument to `new_round`, wires goal_requested, protects
pending rewards, chooses the six documented topics and updates the existing goal
caption. Owned goals equip through `_select_room_item`; ordinary claims stay intact.

- [x] Add focused scene tests and implement the complete goal/navigation flow.
- [x] Exercise the actual exported browser loop using existing metrics/tap helpers,
  including a last-piece fixture, reload, saving failure and keyboard navigation.
- [x] Inspect phone/desktop gift preview, lesson, reward and all six toy sequences.
- [x] Update the gameplay/help documentation, including the stale Unity import status.

## Task 4: Release

- [x] Review diffs and run relevant native/Node/browser checks; resolve findings.
- [x] Build with the verified 19-image Unity overrides and check the real PCK.
- [ ] Commit, merge main, push and deploy the tested export.
- [ ] Verify production HTML/PCK hashes and actual goal/lesson/toy behavior; sync
  main's local preview and record QA evidence with the known browser limitations.
