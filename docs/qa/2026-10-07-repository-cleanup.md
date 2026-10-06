# Repository cleanup — 2026-10-07

The audit followed runtime callers, signal connections, generated resource paths,
catalogs, build inputs, test runners, and the actual exported pack. It covered
tracked source and runtime assets, including private assets selected for export.
All 1,250 word illustrations and pronunciations remain active.

## Removed runtime code

- Removed Match's missed-word list and review-order builder, left over after
  removal of the result word strip. Current lessons, unlimited attempts, and
  optional leaderboard mistake totals remain intact.
- Removed an unused speech-normalization helper, picture factory, mode-heading
  alias, treasure-batch query, and unsubscribed audio failure signal. The active
  speech matcher and missing-audio status reporting remain covered by tests.
- Removed the unreachable baked-frame chest renderer. The catalog requires live
  models for downloaded chests; the original three styles still use their source
  pieces and rigs. Hold, opening, cancellation, and reward handling are retained.
- Removed retired favorite/sticker mutation APIs. Historical save fields remain
  readable, validated, and preserved by current settings and room operations.
  Compatibility fixtures now seed the historical file format directly.
- Removed unused browser layout helpers, an unused visual-review preload, and
  the obsolete three-error Match failure capture.

## Exported assets

Two static Nunito fonts belong to the HTML loading shell, while the native game
uses the variable font through its body and heading resources. The editable
wardrobe sheet is input to the outfit generator; the game loads the generated
theme sheets. Exact export exclusions remove these three unused pack copies
without deleting their reproducible source files or changing the shell fonts.

The previous pack contained 210,683 bytes of their imported payloads and remap
files, before pack-directory and alignment overhead. The pack verifier now
rejects both their source paths and hashed imported copies, and loads the active
interface fonts. The Node check also verifies the shell embeds the original
font bytes and that runtime fonts and generated outfits remain exportable.

No other tracked runtime assets were confirmed unused. Licensed chest models,
optional artwork and audio fallbacks, original word-art generators, provenance,
and save migration remain necessary. No orphaned tracked import or UID sidecars
were found. Ignored local source archives and old QA outputs are not runtime
assets and were preserved.

## Validation

- All 312 Node tests passed, with no failures or skips.
- All 27 selected native suites passed, totaling 53,248 assertions/checks.
  Coverage includes all 1,250 words' lesson reachability, speech matching,
  Match and Memory, legacy save validation and recovery, current preferences,
  all eight chest styles, reward persistence, and the paginated age catalog.
- The initial steady-Match run reported three focus failures. Diagnostics showed
  that its internal round reset settled the prior unopened chest and left focus
  on the room button. Synthetic `pressed` signals do not acquire GUI focus. The
  fixture now establishes board focus after reset, matching the public New
  adventure handoff; all 1,801 checks then passed with assertions unchanged.
  Production focus behavior was not changed. The recovery suite still emits its
  previously documented headless focus warning while passing all 78 assertions.
- Browser validation exposed an initial treasure-layout snapshot with a zero
  scroll limit although a third chest was below the viewport. Layout publication
  now runs after the queued scroll-container sort. The native scrolling suite
  checks a restored, parent-sized desktop list before the first gesture and at
  the wheel endpoint, including actual versus published bounds and unchanged
  saved rewards. All 53 checks passed; the 377 room and 19 reward-flow checks
  also passed after this change.
- The eight-world outfit capture exceeded its 150-second overall timeout while
  making progress. Its trace completed all eight worlds and all 28 visual
  comparisons in about 172 seconds without an assertion failure. The test now
  allows 240 seconds for software WebGL runners, with all assertions retained.
- All seven selected desktop Chromium scenarios passed after the focused
  repairs. They cover all five live chest models, real hold/open/save behavior,
  the game library across viewport sizes, Memory eye release, the floating New
  adventure action, all eight outfits, and preservation of legacy sticker saves
  through world changes and reload. The two affected cases passed on rerun.
- Both mobile WebKit smoke scenarios passed: game-library layout/navigation and
  preservation of saved sticker records through world changes and reload.
  Captured desktop chest/library and mobile room images were visually reviewed.
  These are automated browser checks, not physical Safari or WebAudio validation.
- The release export passed its actual-pack checks: all 1,250 illustrations and
  pronunciations, eight chest styles, five live models, active interface fonts,
  10 general effects, and 224 required source/imported audio paths are present;
  the three build-only resources and retired content are absent.
- Compressed startup payload decreased from 38,739,459 to 38,535,554 bytes
  (203,905 bytes saved). The game pack is `game-c23f994c07d22f6a.pck`; the engine
  remains `engine-9ce25b5d2f802dd7`. These are packaged transfer sizes, not load-time
  or frame-rate measurements.
- The build receipt verifies 5,832 source inputs and 17 output files. All 2,902
  tracked import and UID sidecars retain their pre-cleanup hashes.

Validation evidence is recorded locally under `build/cleanup-20261007/`. Godot
imports, native runs, exports, and browser jobs were serialized.
