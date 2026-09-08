# Gameplay UI and Rewards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simplify the game UI, add animated match feedback, persistent seasonal reward collections, and a draggable long-press chest.

**Architecture:** Keep the existing single Godot scene and state model. Add reward metadata and persistence to the existing data/model flow, then implement all visual behavior in `game_ui.gd` and `chest_view.gd` using native Controls and Tweens.

**Tech Stack:** Godot 4.7, GDScript, existing Node/Godot/Playwright test runners.

## Global Constraints

- Do not add dependencies or a second scene framework.
- Keep reduced-motion support.
- Generate one distinct SVG for each of the forty named reward variants.
- Store collected reward IDs in `user://rewards.cfg`.
- A chest opens only after a stationary 1.2-second hold.

---

### Task 1: Reward model and persistence

**Files:**
- Modify: `scripts/game_data.gd`
- Modify: `scripts/game_model.gd`
- Modify: `tests/godot/run_tests.gd`

**Interfaces:**
- Produces: `GameData.rewards(theme_id: String) -> Array`, `GameData.reward(reward_id: String) -> Dictionary`
- Produces: `GameModel.begin_open(reward_id: String) -> bool`, `reward_id: String`

- [ ] **Step 1: Write failing reward tests**

Add assertions that every theme exposes ten unique IDs, unknown reward IDs return an empty dictionary, opening captures the supplied reward ID, and reset clears it.

- [ ] **Step 2: Run the native test**

Run: `npm test`

Expected: FAIL because reward APIs and `reward_id` do not exist.

- [ ] **Step 3: Add minimal reward data and state**

Use one ten-name array per theme in `game_data.gd`; derive IDs as `<theme>-<1..10>`, reuse `theme.symbol`, and return dictionaries containing `id`, `theme`, `name`, `number`, and `symbol`. Add `reward_id` to the model and require a non-empty ID in `begin_open`.

- [ ] **Step 4: Run the native test**

Run: `npm test`

Expected: PASS.

### Task 2: UI, collection, feedback, and chest gestures

**Files:**
- Modify: `scripts/game_ui.gd`
- Modify: `scripts/chest_view.gd`
- Modify: `tests/godot/run_tests.gd`
- Modify: `tests/browser/godot.spec.cjs`

**Interfaces:**
- Consumes: `Data.rewards`, `Data.reward`, `model.reward_id`
- Produces: `set_hold_progress(progress: float)`, `set_drag_offset(offset: Vector2)`, `reset_position()`

- [ ] **Step 1: Write failing scene tests**

Assert that the removed brand/audio controls are absent, four theme buttons and a rewards button exist, score labels contain only repeated symbols, correct/wrong feedback changes card transforms, short presses do not open, a completed 1.2-second hold opens, and drag offsets remain inside the stage.

- [ ] **Step 2: Run the native test**

Run: `npm test`

Expected: FAIL on the new UI and gesture assertions.

- [ ] **Step 3: Simplify the header**

Remove brand, Mute, Listen, popup menu, and visible instruction copy. Add score icon labels at the left, four image-backed season buttons, a compact reduced-motion button, and a Rewards button.

- [ ] **Step 4: Add feedback animation**

For correct feedback, set both card pivots and scales to `0.82`, then tween to `1.0` with `TRANS_BACK`. For wrong feedback, tween position/rotation through alternating offsets and return both controls exactly to their starting transforms. Skip these tweens when reduced motion is enabled.

- [ ] **Step 5: Add chest drag and hold**

Track `button_down`, `button_up`, and `gui_input`. Cancel charging after 10 units of movement, clamp the artwork inside the stage, and call `_open_chest()` only after 1.2 seconds. Pass charge progress and drag offset into `chest_view.gd`; the increasing shake is the only progress feedback.

- [ ] **Step 6: Add collection overlay**

Load collected IDs from `user://rewards.cfg`, save the newly opened reward once, and render forty slots in a ScrollContainer. Each slot uses that reward's distinct SVG and shows its name/number when collected, or `?` when locked. Back hides the overlay without resetting gameplay.

- [ ] **Step 7: Update browser chest interaction**

Replace click-based chest opening with a pointer hold longer than 1.2 seconds. Remove selectors/assertions for Mute and Listen.

- [ ] **Step 8: Run all tests**

Run: `npm run test:all`

Expected: PASS.

### Task 3: Documentation and delivery

**Files:**
- Modify: `README.md`

**Interfaces:** None.

- [ ] **Step 1: Update player documentation**

Document top-left icon counters, direct season buttons, animated feedback, draggable long-press chest, ten rewards per season, and the collection page. Remove Mute/Listen instructions.

- [ ] **Step 2: Build and inspect the final export**

Run: `npm run build:web`

Expected: Godot Web export completes successfully.

- [ ] **Step 3: Commit, merge, and push**

The work is already on `main`; stage only intended source/docs/test changes, commit with the required co-author trailer, then run `git push origin main`.
