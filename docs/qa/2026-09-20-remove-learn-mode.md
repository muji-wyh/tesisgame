# Remove the Learn game mode

The game now offers Match, Memory and Voice Pop. Learn's view, swipe/controller
navigation and bootstrap dependency are removed. Three equally sized tabs keep
44-pixel touch targets on narrow screens and share the header on desktop.

New adventure and locked-toy gift tasks enter Match directly. Match and Memory
still share five vocabulary words. Completed cards and the result review retain
pronunciation. A stale mode-switch request for Learn is ignored without resetting
the current round; an obsolete explicit new-round destination falls back to Match.

Age preferences, medal pieces, toys, sticker records and world choices retain
their existing save formats. Fresh vocabulary rounds record topic visits;
switching between modes does not add visits. Reward-save recovery still protects
unclaimed pieces before starting a new adventure.

## Verification

- Updated native and browser scenarios to use the remaining games. Removed only
  Learn-specific swipe tests; retained shared audio, navigation, collection,
  persistence, reward, age and animation coverage.
- Six desktop adventure checks passed: win/loss entry into a fresh Match game,
  result-word drag versus tap behavior, More preserving a selected card, and
  a failed save followed by retry and reload.
- Nine desktop core checks passed: three visible mode targets at 320x568 and
  1280x800, shared words across Match/Memory, completed-card pronunciation,
  gift earning/reload and failed-save recovery, Memory's saved reward and next
  game, plus Voice Pop permission denial, pending-permission exit and a scored
  round with two distinct hit sounds and Pip's report.
- Actual desktop and compact screenshots were reviewed for the three-tab layout
  and unobstructed game board.
- The final export passed its startup-pack verification: 200 word pronunciations,
  all eight random slice sounds and 174 optional resource paths, with zero
  failures. Startup download is 14.95 MB, with 87 on-demand audio assets.
- Four iPhone/iPad WebKit profile checks passed: switching all three modes at
  compact/desktop widths, reloading into Match, and completing a round before
  starting a new Match adventure. Fresh phone and tablet page screenshots show
  the three tabs and complete, unobstructed card boards.

The full native/Node npm chain exposed an existing card-presentation fixture that
listed six background colors while iterating eight themes. Its Jungle/Candy
expectations were added, and validation resumed from that failed suite. Earlier
successful suites were retained. The strengthened expansion-scene checks were
also rerun separately.

The completed chain covers all 51 native suites: 71,926 checks with zero final
failures, plus the separate 60-check expansion rerun. The three Node stages
recorded 186 passes, zero failures and one skip for an unavailable external
source asset pack (these are executions, including repeated voice-host tests).
Pop narration's 56 assertions passed; its headless process reported five
ObjectDB instances leaked at exit. This is a remaining test-exit warning.

Browser speech uses fixtures and never opens a real microphone. Windows WebKit
has no AudioContext; actual sound playback is checked in Chromium.

The live-resize page screenshots reproduced the existing Windows WebKit
presentation/capture limitation documented in `2026-09-10-memory-garden.md` and
`2026-09-11-steady-gameplay.md`. Page screenshots and raw canvas rendering are
checked separately; a fresh reload must still produce a populated page image.
The strengthened three-mode capture checks passed on Chromium and both WebKit
profiles (three cases). The retained raw phone/tablet canvas images were reviewed
at 320 pixels wide and show all three labels and the complete card board.
These checks use emulated device profiles, not physical iPhone/iPad hardware.

Evidence: `build/remove-learn-native*.log` and
`build/voice-pop-qa/remove-learn-*`.

## Production

Runtime commit `e75c581` was fast-forwarded into `main`, pushed to `origin/main`
and deployed to `https://gentle-forest-02ff42900.3.azurestaticapps.net/`.
All four startup files fetched from production match the tested local export
byte for byte (SHA-256), including `game-bafa475766ebbcaa.pck`. Hashes are retained
in `2026-09-20-remove-learn-production-manifest.json`.

Two fresh production Chromium checks passed: all three mode targets at compact
and desktop widths with Match restored on reload, and a completed Match round
followed by a new adventure entering Match directly. Production screenshots
were reviewed, including the three tabs at 320 pixels wide.
