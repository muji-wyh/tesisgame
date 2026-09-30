# Local players and leaderboards

Players and scores belong to the current device and browser profile. There are no accounts, uploads, or cross-device synchronization. Clearing site data, using a different browser, or ending a private browsing session can remove this data.

The menu has **Players** and **Leaderboards** entries. Up to ten players can choose an emoji avatar and a name with 1–20 characters. Names may use Unicode; control characters are rejected. Player IDs distinguish profiles even when names match. Creating and selecting players does not record voices or require voice enrollment. Voice Pop continues to use its existing microphone flow for gameplay.

When entering from the loading screen for the first time, create a player before continuing to the game. The avatar and name must be saved successfully before the welcome flow completes. Existing players skip this step.

## Ranking rules

Each player has one personal best per mode. Boards combine completed rounds across themes and age selections.

| Mode | Eligible result | Ranking |
| --- | --- | --- |
| Voice Pop | Finished round | Most hits. Combo score does not break ties. |
| Match | Win | Fewest misses, then fewest hints used. |
| Memory | Win | Fewest turns, then fewest peeks. |

Matching ranking values share a place, using competition ranks such as **1, 1, 3**. Profile creation order keeps the display stable among ties; it does not break the tie. A worse or equal result never replaces a personal best.

Before every Voice Pop round, tap a player's avatar or name to start immediately. **Add player** sits below the player-choice frame. Creating a player returns to the choices and focuses the new avatar; tap it to start. The round keeps that identity, and its finished score saves automatically before the leaderboard celebration. Voice Pop results do not ask for the player again. If saving fails, **Retry saving** keeps the same player and round.

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
```

Coverage includes ties and all ranking rules, profile limits and validation, first-player onboarding, explicit Voice Pop player selection, automatic score attribution, failed saves and retry, corrupt save preservation, native recovery, repeated attribution, rank movement, browser reload, narrow layouts, and reduced motion. Browser microphone fixtures exercise the normal game result flow without recording a real voice. Real-device browser testing remains useful for keyboard behavior, touch scrolling, and rendering performance.
