# Enjoyable Play Implementation Plan

**Goal:** Make Word Buddies easier to enjoy repeatedly through clear round limits,
fresher rounds, and clear collection goals, then release the finished game.

**Architecture:** Keep the current eight-card, three-pair Godot game. Extend the
existing model for hint limits and deck selection, and the existing UI for
collection progress. Reuse the current audio, artwork, hints, rewards,
and local save format; do not introduce another game framework.

**Tech stack:** Godot 4.7, GDScript, Node.js 24, the existing native assertions and
Playwright suite, and the existing Azure Static Web Apps deployment script.

**Follow-up scope:** The chest-reveal plan supersedes the original whole-reward
storage constraints with three-piece medals and a safe save migration. The user
also requested optional browser voice matching; its microphone Listen button is
distinct from the previously removed word-playback Listen control.

## Research and design decision

Reviewed on September 9, 2026. These are features described in the publishers'
App Store listings, not independent evidence of learning gains or retention.
Store prices, catalog sizes, reviews, and marketing efficacy claims are not used
to justify this design.

| Comparable game | Strength or distinctive feature | Suitable lesson for Word Buddies |
| --- | --- | --- |
| [Khan Academy Kids](https://apps.apple.com/us/app/khan-academy-kids/id1378467217) | Character-led activities, a broad library, and child-oriented reading support. | Give children room to explore and repeat without making every error an exit. |
| [Duolingo ABC](https://apps.apple.com/us/app/learn-to-read-duolingo-abc/id1440502568) | Short interactive lessons, read-aloud support, mini-games, and rewards between learning steps. | Keep the three-match round short, preserve spoken hints, and make progress understandable. |
| [Teach Your Monster to Read](https://apps.apple.com/us/app/teach-your-monster-to-read/id828392046) | A player-created character, a continuing journey, and visible progress through reading activities. | Let the existing seasonal collection act as a small, chosen goal instead of adding a new campaign. |
| [Lingokids](https://apps.apple.com/us/app/lingokids-play-and-learn/id1002043426) | A varied mix of games, stories, songs, and self-paced repetition. | Reduce repetitive consecutive boards while preserving a stable, learnable interaction. |

All four publishers describe ad-free play. Preserve this game's no-account,
no-ad, no-purchase experience. Do not copy their characters, artwork, sounds,
stories, branded terminology, or proprietary lesson content.

### Approaches considered

| Approach | Benefit | Cost or drawback | Decision |
| --- | --- | --- | --- |
| Deepen the existing matching loop | More choice, less frustration, clearer progress; uses current assets. | Still one core mini-game. | Implement now. |
| Add a separate listening mini-game | More interaction variety. | New rules, layout, and audio-unavailable behavior; more cognitive load. | Defer until play observation shows matching itself is the limitation. |
| Build an adventure map and avatar system | Stronger narrative and customization. | Substantial new artwork, saved state, navigation, and longer sessions. | Out of scope for this release. |

### Baseline included in this release

The working tree already contains free star-marked hints, keyboard/controller
hint focus, consecutive-match celebrations, and uncollected rewards before
duplicates. Preserve and release these changes rather than reimplementing them.
The Git checkout is already on `main`, initially even with `origin/main`.

### Chosen behavior

1. **Round limits:** Following the owner's September 9 revision, every round
   ends after three mistakes and allows one successful hint request. The
   unlimited-attempt Practice mode and its toggle are removed. Cancelling a
   selection, completing a match, changing seasons, or leaving/returning to
   the board never refills the hint. Only a new round resets the allowance.
2. **Fresh replay:** Ordinary new rounds exclude the previous board's five words
   when at least five other words exist. Small vocabularies still produce valid
   boards. Explicitly seeded rounds remain independent of previous state and
   reproducible. Retain only the previous board, not a learner profile.
3. **Seasonal goals:** The subsequent chest plan changes each season to six
   medals, each built from three fragments. Show completed medals out of six
   and partial-piece counts separately. Remember
   a manually chosen season for ordinary replays so children can finish that
   collection. Before any manual choice, rounds still choose a random season.
   Explicit seeded rounds and browser reloads keep their existing behavior.

## Global constraints

- Keep eight cards, exactly three complete pairs, and two unmatched distractors.
- Every round has a three-mistake limit and one hint; there is no alternate mode.
- No timers, daily streak pressure, leaderboards, purchases, tracking, or accounts.
- No new dependencies, generated media, runtime downloads, or save schema.
- Reuse the existing finite star effects; honor reduced motion throughout.
- All new actions must work with touch, keyboard, and the existing Xbox focus navigation.
- Keep controls at least 48 CSS pixels at the supported minimum viewport.
- Do not reintroduce the removed Mute, Listen, FX, or long instruction controls.
- Save each earned reward once before animation; never award one for using a hint.
- Respect modal focus, page hiding, chest locks, and optional-audio failures.
- Include the already-existing, related uncommitted changes. Do not commit
  generated output, private credentials, or unrelated files.
- Commit and publish only after the implementation and its checks are complete.

## File responsibilities

| File | Responsibility |
| --- | --- |
| `scripts\game_model.gd` | Per-round hint allowance, correct/wrong rules, and fresh deck selection. |
| `scripts\game_ui.gd` | Hint availability, passive mistake badges, season choice, and collection counts. |
| `scripts\word_card.gd` | Existing hint-star rendering. |
| `tests\godot\run_tests.gd` | Model invariants and native control/lifecycle assertions. |
| `tests\browser\godot.spec.cjs` | Real exported-game input, replay, and persistence checks. |
| `tests\browser\collection-scroll.spec.cjs` | Existing rendered collection scrolling regressions. |
| `web\shell.html` | Accessible browser help, not a second gameplay implementation. |
| `README.md` | Current play instructions and a link to this plan. |

## Task 1: One hint and three mistakes per round

**Interface:** Add `hint_used: bool = false` to the model. Only `reset()`
clears it; `request_hint()` sets it when it actually finds a pair.

- [x] Remove the unlimited-attempt mode, its model API, and its UI toggle.
  Keep the original three-mistake loss threshold and encouraging loss screen.
- [x] Assert that repeat hint requests fail without changing the board, focus,
  scoring, or hint pair, and that invalid requests do not consume a new hint.
- [x] Keep the spent state through matches, cancellation, seasons, modal/page
  lifecycle, and failed resets. Display `Used` and disable the hint button.
- [x] Run the native suite before and after implementation:

```powershell
node tools\run-godot.cjs --headless --path . --script res://tests/godot/run_tests.gd
```

- [x] Exercise touch, keyboard, and Xbox against the exported game to confirm
  they share one hint. Confirm three mistakes end a hinted round and replay
  restores the allowance.

## Task 2: Fresh boards and chosen seasonal goals

**Interfaces:** Preserve `reset(words: Array, seed_value: int = -1) -> bool`.
Use UI-only `_preferred_theme: String` and `_collection_headings: Dictionary`.

- [x] Add a native ten-word fixture that produces two disjoint successive
  unseeded boards. Exercise five-to-nine-word fallback vocabularies and retain
  the existing seeded-deck equality assertion.
- [x] After shuffling the pool, prefer words not on the previous board for
  unseeded resets only, when the filtered pool contains at least five entries.
  Use the existing `cards` as history; do not persist or grow a history list.
- [x] Add native assertions that manually choosing Summer survives unseeded
  replay, but does not override an explicit seed. Assert that season
  changes never grant a reward or restart the current board.
- [x] Remember successful `choose_theme(id)` calls in `_preferred_theme`.
  Apply it after `model.reset()` inside the existing `_rebuilding` section of
  `new_round()` only when `seed_value < 0`.
- [x] Retain a reference to each existing season heading. Derive its count from
  `Data.rewards(theme_id)` and `collected_rewards`, not another saved counter:

```gdscript
var rewards: Array = Data.rewards(theme_id)
var count: int = rewards.filter(
    func(reward: Dictionary) -> bool: return collected_rewards.has(reward.id)
).size()
```

- [x] Render `Spring 3/6` for completed-medal progress and
  `Spring complete! 6/6` for completion, using the actual season/count.
  Include the selected season's count in the collection announcement.
- [x] Extend browser replay coverage to compare discovered words across
  consecutive rounds, confirm the chosen background remains, and confirm
  collection counts survive reload. Keep the existing swipe and preview flows.

## Task 3: Playability, documentation, and release

- [x] Update README and browser help to describe round limits, fresh boards, session
  season choice, and collection goals. Keep the old Challenge rules explicit.
- [x] Run the native suite and existing web-export contract checks; build the
  actual export:

```powershell
node tools\run-godot.cjs --headless --path . --script res://tests/godot/run_tests.gd
node --test tests\web-export.test.cjs tests\deployment.test.cjs
npm run build:web
```

- [x] Run the existing Playwright runner for round limits, fresh replay, season
  goals, hints, loss, reward delivery/preview, resizing, modal focus, and
  collection scrolling on its desktop, iPhone, and iPad projects. Resolve
  regressions rather than weakening gameplay assertions.
- [x] Inspect desktop and small-phone screenshots of available and spent hints,
  with hints, in the collection, and after winning. Confirm the minimum 48px
  targets, no clipping, and a static reduced-motion presentation.
### Release procedure

1. Review the full diff and run `git diff --check`. Fetch `origin` again.
  If `main` is still current, no artificial merge commit is needed. If the
  remote advanced, integrate it without resetting/rebasing away local work,
  then rerun the affected checks.
2. Stage only the explicit source/docs/test paths from this plan. Commit
  with `Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>`,
  then `git push origin main`. Never force-push.
3. Deploy the verified export with the repository's existing command:

```powershell
npm run deploy -- -SkipBuild
```

4. Compare production HTML's fingerprinted game pack to the built export;
  open the live game and exercise the hint limit, a win/chest, and collection
  progress. Verify that failures are surfaced and no secrets appear in output.

### Verification note

The scrolling regression initially used a screenshot taken after release as
the release position. Trace timing showed that capture already included most
of the glide. The check now compares against the actual 80px finger endpoint,
retaining its minimum movement, deceleration, and stop-on-touch assertions.
All four rendered scrolling checks passed on three consecutive runs; the
production scrolling algorithm was not changed.

## Acceptance and follow-up

Completion means the planned behavior is implemented, the source is committed
and pushed to `main`, and the same build is playable in production at
`https://gentle-forest-02ff42900.3.azurestaticapps.net`.

Functional checks cannot establish that children find a game more enjoyable.
A later parent-guided play observation should look for whether a child can
recover from a mistake, understand the round limits, choose a season goal,
and voluntarily try another short round. Do not add telemetry or claim
measured engagement gains without that evidence.
