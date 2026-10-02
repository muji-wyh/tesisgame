# Local player editing and removal

The Players menu offers Edit and Remove for every saved player. Editing updates
the name and avatar while retaining the stable ID, profile order, personal bests,
and round receipts. Removal names the player in a confirmation, then deletes only
that player's profile, scores, and receipts. The last removal returns immediately
to first-player creation. Shared Talk Quest, medal, treasure, and room progress
remain intact.

## Lifecycle and persistence checks

- `leaderboard_state_tests.gd`: 450 checks passed, including native and browser
  storage failures, stale managers, full capacity, and removing the final profile.
- `leaderboard_scene_tests.gd`: 339 existing checks passed.
- `player_management_tests.gd`: 344 checks passed. Coverage includes edit
  prefill/cancel, failed reads and writes, retry, duplicate actions, obsolete UI
  callbacks, all ten player slots, controller Back, and narrow layouts.
- The main-scene cases verify active and completed Voice Pop identity updates,
  retirement of a removed player's Pop round, and retirement of saved Match and
  Memory results. Removed results cannot be reassigned, and their result-page
  leaderboard action stays hidden after a refresh.
- Shared save bytes are compared before and after deletions. The fixture uses
  isolated player, Quest, medal, and room storage and mutes unrelated playback.
- The leaderboard host, native-keyboard host, and test-registration suites passed
  all 15 Node tests.

## Browser scope

`tests/browser/player-management.spec.cjs` exercises desktop Chromium and the
iPhone WebKit device profile with one worker. It covers name/avatar editing,
cancel, save failure/retry, persistence on reload, every leaderboard, deletion
confirmation, removing the last player, and creating a fresh identity without
inheriting scores. Mobile assertions check the native editor's minimum 16 CSS-pixel
font, unchanged viewport zoom, and keyboard dismissal.

Shared storage must remain byte-identical around management actions. Reload
normally starts another Match lesson and changes only the room's
`recent_topic_ids` history; the postreload comparison excludes that history line
while still checking the rest of the shared save. The initial run reached the end
of all four product flows but exposed this overly strict test comparison, which
was corrected before the final run.

The final run passed all four cases in 7.2 minutes with process exit 0 and no
page, parse, or script errors. Its log is
`build/player-management-browser-final.log`; screenshots are under
`build/player-management-final-results` with separate desktop and iPhone folders.

Desktop and phone screenshots cover the edited draft, saved player list, named
removal confirmation, and empty-profile onboarding. The list uses visible Edit
and Remove actions, the editor keeps Save and Cancel separate, and removal
focuses Keep player by default. Phone controls fit horizontally and the longer
Players page scrolls vertically.

## Web export

The final `npm run build:web` completed successfully. The startup download is
20.04 MB and 112 required audio assets passed package verification. The local
preview uses `http://127.0.0.1:41773/`. The initial feature validation was local.

## Production deployment

The user subsequently requested deployment. `npm run deploy -- -SkipBuild`
published the tested export to
<https://gentle-forest-02ff42900.3.azurestaticapps.net/>. No runtime source files
were newer than the export. All nine public release files matched the frozen
SHA-256 manifest, including `game-4ed503019721ea64.pck`. The delivered HTML
contains the minimum 16px native-editor font and enables the mobile keyboard.

Both player-management cases passed against production in the iPhone WebKit
device profile in 1.8 minutes, including editing, persistence, removal,
last-player onboarding, native-editor font, and focus checks. No page, parse,
or script errors were reported. This is desktop WebKit device emulation;
physical iOS software-keyboard zoom was not tested.

Deployment and verification evidence is in `build/player-management-deploy.log`,
`build/player-management-release-manifest.json`,
`build/player-management-production-verified.json`, and
`build/player-management-production-browser.log`.
