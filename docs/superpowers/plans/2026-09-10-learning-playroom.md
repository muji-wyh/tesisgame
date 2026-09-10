# Learning and Pip's Room Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development to implement the bounded tasks below. Keep each task's files isolated and review the actual diff before integration.

**Goal:** Make word–picture learning explicit and rewarding, integrate free Unity Store art through Unity CLI, then commit and deploy the improved game.

**Architecture:** Keep Godot, existing medal progression and the browser host. Introduce one reusable association view and a stable five-word lesson shared by modes. Use one small playroom state/catalog plus a dedicated room view, with ownership derived from medals. Unity is an offline art import step.

**Tech Stack:** Godot 4.7 GDScript; Node.js tooling and Playwright; installed Unity CLI with Unity 6000.6.0f1; existing Azure Static Web Apps deployment.

**Spec:** `docs/superpowers/specs/2026-09-10-learning-playroom-design.md`

**Current status:** Learning, semantic artwork, and Pip's room are implemented.
Native and browser verification and the final web export have passed. Unity Store research and the CLI
import tool are ready, but actual package acquisition/import remains pending:
Computer Use was stopped by the user's Escape input, and permission to resume is
awaiting a reply. The game improvements can be released independently.

## Global constraints

- Same five lesson words across Learn/Match/Sky/Listen until New adventure.
- Existing three-mistake quiz limit and one-piece reward remain; Learn has no scoring.
- Touch, keyboard, controller, responsive layout and reduced motion remain supported.
- Preserve all existing saves; successful browser saves survive immediate reload.
- Imported licensed source packages are not published in the public repository.
- Real Unity CLI import and deployed use are required, not merely a planned pipeline.

## Task 1: Learning presentation and quiz feedback

**Files:** new `scripts/word_lesson.gd`; modify `scripts/choice_game.gd`, `scripts/game_data.gd`; new `tests/godot/learning_controls_tests.gd`; adjust affected choice tests.

**Interfaces:** `WordLesson.show_words(words: Array, heading: String, action_text: String = "Play Match")`, `WordLesson.controls() -> Array[Control]`, signals `hear_requested(word: Dictionary)` and `finished`; `ChoiceGame.continue_feedback()` and `ChoiceGame.set_audio_available(value: bool)`; `Data.confusable_words(first: String, second: String) -> bool`.

- [x] Add focused failing checks for visible picture/text identity, correct feedback target, explicit Continue, rapid-answer locks, semantic exclusions and audio fallback.
- [x] Implement the reusable large picture/word/Hear view with previous/next/action buttons and small-screen layout.
- [x] Implement self-paced choice feedback and safe distractor selection; preserve five-correct/three-mistake scoring.
- [x] Run the changed native suites and report exact source interfaces to root.

## Task 2: Playroom state and room interactions

**Files:** new `scripts/playroom_state.gd`, `scripts/playroom_view.gd`, `tests/godot/playroom_state_tests.gd`, `tests/godot/playroom_view_tests.gd`; root owns `game_ui.gd` and browser-host integration.

**Interfaces:** `PlayroomState.new(save_path: String = "user://playroom-v2.cfg", browser_storage: Object = null)`; `load_state(legacy_favorite: String = "") -> bool`; fields `toy_id`, `backdrop_id`, `favorite_id`, `error`; `select_item(id: String, counts: Dictionary) -> bool`; `set_favorite(id: String) -> bool`; `catalog() -> Array[Dictionary]`, `owned(item: Dictionary, counts: Dictionary) -> bool`, `next_gift(counts: Dictionary) -> Dictionary`. `PlayroomView.configure(state, counts, palette, reduced_motion)`; signals `item_selected(id: String)`, `word_requested(word_id: String)`, `toy_played(kind: String)`; `controls() -> Array[Control]`.

- [x] Add checks for starter access, exact medal thresholds, unknown/locked IDs, favourite migration, invalid data and failed writes.
- [x] Implement stable catalog IDs and save only selections; derive unlocks from existing medal counts.
- [x] Build the room and selectors, visible locked requirements, distinct toy interactions and static reduced-motion results.
- [x] Verify state reload and interaction independence from medal progress. Report interfaces to root.

## Task 3: Unity import and semantic artwork

**Files:** new `tools/import-unity-art.ps1` and mapping/provenance documentation; targeted existing art generator changes; imported licensed art ignored by Git; asset validation tests.

- [ ] Finish Asset Store acquisition after user browser login and any required agreement step.
- [ ] Inspect archive paths and art; select exact vocabulary/reward uses and record source hashes.
- [ ] Import the art-only package with the installed Unity CLI into `build/unity-asset-staging`, verify imported results and produce only needed Godot textures.
- [x] Repair the original ambiguous objects through the existing art generators; render a contact sheet and inspect it.
- [ ] Verify the final catalog's labels, images and audio refer to the same concrete objects, including originals used without the licensed pack.

## Task 4: Main UI, lesson continuity and save bridge

**Files:** `scripts/game_ui.gd`, `scripts/game_model.gd`, `scripts/word_card.gd`, `web/shell.html`, browser/native integration tests, `package.json`, README and changelog.

- [x] Add failing checks for lesson continuity, correction details, review order, visible instructions and browser playroom persistence.
- [x] Add Learn mode and keep the five-word lesson stable across practice modes; add Repeat lesson/New adventure.
- [x] Integrate self-paced Match association/correction and missed-word review, with existing voice queue behavior accounted for.
- [x] Replace the small playroom strip with the room view; wire synchronous state save, migrated favourite and named gift progress/reveal.
- [x] Make matched cards reinforce the picture–word association, and compact navigation enough for phone layouts.
- [x] Run native/Node tests, build the current export, exercise and inspect all changed screens in browser.

## Task 5: Release

- [x] Review source diff and imported asset provenance; verify no secrets or restricted source package are staged.
- [ ] Commit the working change, integrate into main and push.
- [ ] Deploy the tested current `build/web` through `npm run deploy -- -SkipBuild`.
- [ ] Verify the production game pack SHA256, actual Learn and quiz flows, imported artwork and room interactions.
- [ ] Mark the goal complete only after every explicit user requirement is verified.

## Verification evidence

See [the QA record](../../qa/2026-09-10-learning-playroom.md): 5,475 Godot checks,
89 Node passes with one unavailable-source skip, and 225 browser passes with 18
environment-specific skips. The final export and local release smoke passed;
production verification follows deployment. Real Unity acquisition/import and its
deployed visual verification remain open.
