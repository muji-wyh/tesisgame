# Three Hints Per Round Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow three successful Match hints per round, show the remaining count, and release the verified Web build.

**Architecture:** Keep `GameModel.request_hint()` as the only hint entry point for touch, keyboard, and Xbox. Replace the boolean spent flag with one remaining counter that decrements only when a new valid pair is highlighted; the UI derives its label and enabled state from that counter.

**Tech Stack:** Godot 4.7 GDScript, Node.js 24, Playwright 1.63, Azure Static Web Apps CLI.

## Global Constraints

- Keep the existing eight-card, three-pair Match rules and scoring.
- Start each successful new round with exactly three hints.
- Do not spend a hint during feedback, after the round, when no pair exists, or while another hint is still highlighted.
- Changing the reward world never refills hints; starting a new round restores all three.
- Touch, keyboard, and Xbox must share the same model counter.
- Add no dependency, save field, telemetry, or new gameplay mode.
- Leave the user's unrelated `.gitignore` edit unstaged.

---

### Task 1: Model the Three-Hint Allowance

**Files:**
- Modify: `scripts/game_model.gd:3-220`
- Modify: `tests/godot/run_tests.gd:288-360`
- Modify: `tests/godot/adventure_model_tests.gd:80-92`
- Modify: `tests/godot/adventure_scene_tests.gd:50-106`
- Modify: `tests/godot/voice_model_tests.gd:78-124`

**Interfaces:**
- Consumes: `request_hint() -> bool`, `hint_ids: Array[String]`, `reset(...) -> bool`
- Produces: `const MAX_HINTS := 3`, `hints_remaining: int`, unchanged `request_hint() -> bool`

- [ ] **Step 1: Write failing counter tests**

Update the focused model test to assert:

```gdscript
check(model.hints_remaining == 3, "A new round starts with three hints")
check(model.request_hint() and model.hints_remaining == 2, "A successful hint spends one allowance")
check(not model.request_hint() and model.hints_remaining == 2,
	"An active hint cannot be spent twice")
```

After clearing the current highlight, request two more hints and assert:

```gdscript
check(model.request_hint() and model.hints_remaining == 1, "The second hint is available")
model.select(model.hint_ids[0])
model.select(model.hint_ids[0])
check(model.request_hint() and model.hints_remaining == 0, "The third hint is available")
check(not model.request_hint() and model.hints_remaining == 0, "A fourth hint is rejected")
```

Replace `hint_used` assertions in the adventure and voice tests with exact remaining-count assertions.

- [ ] **Step 2: Run the focused model tests and verify failure**

Run:

```powershell
node tools\run-godot.cjs --headless --path . --script res://tests/godot/run_tests.gd
node tools\run-godot.cjs --headless --path . --script res://tests/godot/adventure_model_tests.gd
node tools\run-godot.cjs --headless --path . --script res://tests/godot/voice_model_tests.gd
```

Expected: failures because `MAX_HINTS` and `hints_remaining` do not exist and the second/third hint requests are rejected.

- [ ] **Step 3: Implement the minimal model counter**

In `scripts/game_model.gd`:

```gdscript
const MAX_HINTS: int = 3

var hint_ids: Array[String] = []
var hints_remaining: int = MAX_HINTS
```

In `reset()`:

```gdscript
hint_ids.clear()
hints_remaining = MAX_HINTS
```

At the start of `request_hint()`:

```gdscript
if hints_remaining <= 0 or not hint_ids.is_empty() or not phase in ["waiting", "matching"]:
	return false
```

After a valid pair is assigned:

```gdscript
hint_ids.assign([card.id, partner_id])
hints_remaining -= 1
```

Remove the stored `hint_used` boolean.

- [ ] **Step 4: Run focused native tests**

Run the three commands from Step 2 plus:

```powershell
node tools\run-godot.cjs --headless --path . --script res://tests/godot/adventure_scene_tests.gd
```

Expected: all checks pass with zero failures.

- [ ] **Step 5: Commit the model change**

```powershell
git add scripts\game_model.gd tests\godot\run_tests.gd tests\godot\adventure_model_tests.gd tests\godot\adventure_scene_tests.gd tests\godot\voice_model_tests.gd
git commit -m "feat: allow three hints per round" -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 2: Show Remaining Hints and Update Player-Facing Text

**Files:**
- Modify: `scripts/game_ui.gd:400-420,1808-1820`
- Modify: `tests/browser/godot.spec.cjs:695-760`
- Modify: `README.md:233-241,346-350`
- Modify: `web/shell.html:216-225`
- Modify: `changelog.md:45-53`

**Interfaces:**
- Consumes: `GameModel.MAX_HINTS`, `GameModel.hints_remaining`, `GameModel.hint_ids`
- Produces: button labels `Hint 3`, `Hint 2`, `Hint 1`, and `Used`

- [ ] **Step 1: Write failing UI assertions**

In the native UI test, assert:

```gdscript
check(app.hint_button.text == "Hint 3" and not app.hint_button.disabled,
	"A new Match round shows all three hints")
app.hint_button.pressed.emit()
check(app.hint_button.text == "Hint 2" and app.hint_button.disabled,
	"An active first hint shows two remaining and blocks duplicate spending")
```

After clearing the highlight, assert the button re-enables; after the third successful request, assert `Used` and disabled.

Update the browser scenario to consume hints through touch and Xbox, verify an active hint cannot be spent twice, reject the fourth request, and confirm Repeat restores a hint.

- [ ] **Step 2: Run focused UI tests and verify failure**

Run:

```powershell
node tools\run-godot.cjs --headless --path . --script res://tests/godot/run_tests.gd
npx playwright test godot.spec.cjs --project=desktop-chromium --grep "three hints per round"
```

Expected: failures because the button still uses the old `Hint`/`Used` boolean behavior.

- [ ] **Step 3: Implement the UI state**

Initialize the button with:

```gdscript
hint_button.text = "Hint 3"
hint_button.tooltip_text = "Three hints per round (Xbox X)"
```

In `_refresh()`:

```gdscript
var hint_active: bool = not model.hint_ids.is_empty()
hint_button.visible = playing and _mode_id == "match"
hint_button.disabled = model.hints_remaining <= 0 or hint_active or not model.phase in ["waiting", "matching"]
hint_button.focus_mode = Control.FOCUS_NONE if hint_button.disabled else Control.FOCUS_ALL
hint_button.text = "Used" if model.hints_remaining <= 0 else "Hint %d" % model.hints_remaining
hint_button.tooltip_text = (
	"No hints left. Start a new round for three more."
	if model.hints_remaining <= 0
	else "Hint active. Follow the stars before using another."
	if hint_active
	else "%d hints left (Xbox X)" % model.hints_remaining
)
```

Keep `_request_hint()` unchanged apart from reading the model's new state through `_refresh()`.

- [ ] **Step 4: Update current documentation**

Change current help text to say three hints per round, the button shows the remaining count, and only a new round restores all three. Update the Xbox row to “Use one of the round's three hints.”

Add a new top changelog entry:

```markdown
## 2026-09-14

- Increased Match to three hints per round. The Hint button shows the remaining count,
  all input methods share the allowance, and active or invalid requests spend nothing.
```

- [ ] **Step 5: Run focused UI and browser tests**

Run:

```powershell
node tools\run-godot.cjs --headless --path . --script res://tests/godot/run_tests.gd
npx playwright test godot.spec.cjs --project=desktop-chromium --grep "three hints per round|keyboard hints"
```

Expected: all selected tests pass.

- [ ] **Step 6: Commit UI, tests, and docs**

```powershell
git add scripts\game_ui.gd tests\browser\godot.spec.cjs README.md web\shell.html changelog.md
git commit -m "feat: show three round hints" -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 3: Verify, Push, Deploy, and Confirm Production

**Files:**
- Verify generated output: `build\web\`
- Do not stage: `build\web\`, `.gitignore`

**Interfaces:**
- Consumes: existing `npm test`, `npm run build:web`, `npm run deploy -- -SkipBuild`
- Produces: pushed `main` and production at `https://gentle-forest-02ff42900.3.azurestaticapps.net/`

- [ ] **Step 1: Run full verification**

```powershell
npm test
npm run build:web
npx playwright test godot.spec.cjs --project=desktop-chromium --grep "three hints per round|keyboard hints"
git diff --check
```

Expected: native/Node suites pass, Web export succeeds, focused browser tests pass, and `git diff --check` is clean.

- [ ] **Step 2: Confirm branch and remote state**

```powershell
git fetch origin
git rev-list --left-right --count HEAD...origin/main
git status --short
```

Expected: local `main` is ahead only; `.gitignore` may remain as the user's unrelated unstaged edit.

- [ ] **Step 3: Push**

```powershell
git push origin main
```

Expected: `main` advances without force-push.

- [ ] **Step 4: Deploy the verified export**

```powershell
npm run deploy -- -SkipBuild
```

Expected: Azure Static Web Apps deployment succeeds for `gentle-forest-02ff42900.3.azurestaticapps.net`.

- [ ] **Step 5: Verify production**

Fetch production HTML, identify its game pack, and compare it to the local built HTML/PCK. Open production in Chromium, enter Match, use three hints with the current highlight cleared between requests, and confirm a fourth request does not change the hint.
