# Local players and leaderboards

Players and scores belong to the current device and browser profile. There are no accounts, uploads, or cross-device synchronization. Clearing site data, using a different browser, or ending a private browsing session can remove this data.

The menu has **Players** and **Leaderboards** entries. Up to ten players can choose an emoji avatar and a name with 1–20 characters. Names may use Unicode; control characters are rejected. Player IDs distinguish profiles even when names match. Creating and selecting players does not record voices or require voice enrollment. Voice Pop continues to use its existing microphone flow for gameplay.

When entering from the loading screen for the first time, create a player before continuing to the game. The avatar and name must be saved successfully before the welcome flow completes. Existing players skip this step.

## Editing and removing players

Open **Players** in the menu. Each player has **Edit** and **Remove** actions.

- **Edit** changes the name and emoji avatar. **Save changes** keeps the same player ID, creation order, personal bests, and round ownership. Editing remains available when all ten player spots are occupied.
- **Remove** opens a confirmation naming the player. **Keep player** cancels; **Remove player** deletes that profile, its personal bests in every mode, and its round receipts. Removal cannot be undone and makes the player slot available again.
- **Cancel**, the panel's **Back** button, Escape, or controller Back discard a pending edit or removal before leaving the Players screen. Failed writes retain the draft or confirmation for retry.

Names and avatars update on leaderboards and the current Voice Pop result. Removing the current Voice Pop player discards their unfinished or completed round and requires a new player selection. A saved Match or Memory result belonging to a removed player cannot be reassigned to another player. Removing the last player immediately requires creating a new one.

Talk Quest progress, medals, treasure collections, playroom state, and earned Match chests are shared on the device and survive profile removal. Editing a name on mobile uses the same native text input as player creation and retains its 16 CSS-pixel minimum font to prevent focus zoom.

## Ranking rules

Each player has one personal best per mode. Boards combine completed rounds across themes and age selections.

| Mode | Eligible result | Ranking |
| --- | --- | --- |
| Voice Pop | Finished round | Most hits. Combo score does not break ties. |
| Match | Win | Fewest misses, then fewest hints used. |
| Memory | Win | Fewest turns, then fewest peeks. |

Matching ranking values share a place, using competition ranks such as **1, 1, 3**. Profile creation order keeps the display stable among ties; it does not break the tie. A worse or equal result never replaces a personal best.

Before every Voice Pop round, tap a player's avatar or name to start immediately. **Add player** sits below the player-choice frame. Creating a player returns to the choices and focuses the new avatar; tap it to start. The round keeps that identity, and its finished score saves automatically before the leaderboard celebration. Voice Pop results do not ask for the player again. If saving fails, **Retry saving** keeps the same player and round.

The Voice Pop player picker keeps the shared Pip header visible. Tap Pip to switch game modes or **More** to visit Pip's room; returning from the room restores the picker. The microphone stays off until a player is selected. First-player onboarding still requires creating a profile before continuing.

The Voice Pop result places the player's avatar and name beside the hit total. Its embedded leaderboard shows the ranking rows directly, without introductory copy, repeated player attribution, mode tabs, or a personal-best heading. The menu's full leaderboard retains its mode selection and ranking explanations.

Result-page touch scrolling follows the finger's distance at the current display scale and coasts to a stop after release. Player lists and full leaderboards use the same momentum. Dragging a word or Play again does not activate it, and a browser-canceled gesture cannot become a tap. Touching a moving list stops it before another tap can activate an item. Once the player scrolls during a rank celebration, that celebration stops moving the page automatically, including while the list is coasting. Name fields retain native text editing and mobile keyboard behavior.

After a Match or Memory round, select who played and save the result. A saved round stays assigned to that player. The leaderboard appears with the result; the menu also provides access to every mode's board. Match and Memory players can still be created from their result screens when needed.

When a saved personal best improves the player's place, their avatar and name move upward while displaced rows make room, with a gold trail, glow, and sparkles. First entries have a separate arrival celebration. A higher score that retains the same rank does not claim a rank increase. Reduced motion displays the final ordering directly. Hiding or rebuilding the panel settles the effect, and reopening a saved result does not replay the improvement.

## Persistence and recovery

`scripts/leaderboard_state.gd` owns validation, personal bests, rankings, and round attribution. Its versioned ConfigFile record is independent of playroom and reward progress:

- Web: localStorage key `wordBuddies.leaderboards` through `wordBuddiesHost.leaderboardState()` and `saveLeaderboardState(text)`.
- Native: `user://leaderboards-v1.cfg`, staged through `.pending` with a `.previous` recovery file.

Opening an empty leaderboard does not write a save. Changes are applied in memory only after storage accepts the complete record. A failed profile or score save remains retryable and does not create a player, a rank change, or a round receipt. Invalid and unsupported saves are preserved with an error instead of being silently replaced.

Before each write, the state reloads the latest record to retain changes made by another local view. This protects sequential writes from stale views; localStorage is not a multi-device or transactional shared database.

Successful submissions retain the most recent 4,096 round IDs, their modes, and their assigned player IDs. Repeating a retained submission is idempotent, including after reload. Reassigning it to another player or mode is rejected. Oldest receipts are retired to bound storage growth; personal bests remain. Round IDs are generated independently for each new game.

The browser's `leaderboard-status` dataset exposes JSON diagnostics for UI tests. It is read-only and never interprets player names as HTML or changes persisted results.

## Validation

Run native state and scene coverage plus host storage tests:

```sh
npm run test:leaderboards
```

Run only the browser storage bridge tests:

```sh
node --test tests/leaderboard-host.test.cjs
```

Build before running the focused browser suite, and run Godot, export, and browser jobs sequentially:

```sh
npm run build:web
npx playwright test tests/browser/leaderboards.spec.cjs --project=desktop-chromium --project=iphone-webkit
npx playwright test tests/browser/player-management.spec.cjs --project=desktop-chromium --project=iphone-webkit
```

Coverage includes ties and all ranking rules, profile limits and validation, editing and confirmed removal, first-player onboarding, explicit Voice Pop player selection, automatic score attribution, failed saves and retry, corrupt save preservation, native recovery, repeated attribution, rank movement, browser reload, narrow layouts, and reduced motion. Profile management also checks stale actions, removal of the current round's player, last-player onboarding, preservation of shared saves, and mobile editor zoom. Browser microphone fixtures exercise the normal game result flow without recording a real voice. Real-device browser testing remains useful for keyboard behavior, touch scrolling, and rendering performance.
