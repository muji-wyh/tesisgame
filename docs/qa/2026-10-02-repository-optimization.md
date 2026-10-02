# Repository optimization review

This review covers runtime refresh paths, browser status publication, build and
deployment integrity, and maintained documentation. It preserves the preceding
authorized gameplay, chest, presentation, and audio changes in this checkout.

## Concrete improvements

- [Word cards](../../scripts/word_card.gd) reuse their style resources when
  computed colors, corners, and borders are unchanged. Text fitting avoids
  repeating an identical font-size override. Input state, badges, feedback, and
  animation still update. Memory card backs similarly skip repeated palette
  layout work while invalidating for changed colors or display scale.
  [Card coverage](../../tests/godot/card_polish_tests.gd) checks resource reuse
  and the transitions that must create new styles.
- Closing More while the page is hidden now retains the paused Match/Memory
  feedback and Voice Pop reward state. Foregrounding resumes normal behavior.
  [Recovery coverage](../../tests/godot/ui_recovery_tests.gd) exercises wrong
  answers, hidden-menu closure, and a saved unopened chest, with an isolated
  reward save fixture.
- The [browser host](../../web/shell.html) skips unchanged Voice Pop attributes
  and identical Talk Quest snapshots. Changed values still publish normally;
  repeated status and geometry reports no longer cause redundant DOM writes.
- [Web packaging](../../tools/package-web.cjs) reuses an existing Brotli
  sidecar only when its complete stream decompresses to the current source
  bytes. Stale, truncated, malformed, appended, or concatenated streams are
  recompressed. Filename hashes are lookup hints, not proof of cache validity.
  This removes repeated compression work for verified unchanged assets;
  no build-time improvement is claimed without measurement.
- A [successful-build receipt](../../tools/web-build-receipt.cjs) fingerprints
  runtime inputs, local licensed assets, and the complete export. The receipt
  lives at `build/web-build.json`, outside the published directory. Builds
  invalidate any old receipt and reject runtime input changes during export.
  Deployment verifies current inputs and outputs before contacting Azure,
  including when `-SkipBuild` is used. Focused fixtures cover invalid caches,
  missing or stale receipts, and altered inputs or outputs.
- The [documentation index](../README.md), [gameplay guide](../gameplay.md),
  and [development guide](../development.md) now describe current finite
  Talk Quest word combat, Voice Pop chest milestones and persistence, animated
  chest prerequisites, and verified build reuse. Historical reports retain
  their original scope and evidence.

## Remaining architecture and measurement limits

`scripts/game_ui.gd` and `web/shell.html` remain large controllers combining
mode orchestration, lifecycle, speech, accessibility, and presentation.
Further separation should extract small boundaries under the existing
integration coverage. This review makes bounded corrections rather than a
large rewrite whose behavior would be harder to verify.

Browser speech fixtures simulate recognition callbacks. Browser WebAudio
checks can establish scheduling and browser output, but not physical speaker
latency or microphone recognition accuracy. Android viewport emulation does
not establish phone performance, and WebKit emulation does not establish
physical iPhone behavior. Reproducing the release also requires the documented
local licensed asset inputs.

## Validation and deployment

- `npm test`: all 81 Godot suites and all 302 Node tests across 21 suites passed.
  The native run includes 16,201 expanded-word layout checks, 249 card-polish
  checks, 6,589 Memory-back checks, and 75 recovery checks. The full local log
  is `build/repo-optimization/full-tests.log`.
- All 65 local links in the changed maintained Markdown documents resolve.
- `npm run build:web` succeeded using the normal packager. The startup pack
  verified all 350 word pronunciations, 12 game effects, 230 required audio
  paths, five animated chest models, giant creatures, and reference slice
  sounds. Compressed startup assets total 29.28 MB.
- Release files: `engine-9ce25b5d2f802dd7` and `game-f670f1bf56398e72.pck`.
  `node tools/web-build-receipt.cjs --verify` confirmed 2,223 source inputs and
  15 output files unchanged. Local build log: `build/repo-optimization/web-build.log`.
- All 23 selected Chromium release cases passed across desktop (13) and
  Android viewport emulation (10), including the targeted reruns below. They
  cover all five live chest models, player persistence, Match/Memory/Pop audio
  scheduling, keyboard recovery, Quest combat/rewards/pause/loss/retry, and
  Pop speech/menu recovery. Four additional iPhone/iPad WebKit keyboard cases
  passed. These are selected release regressions, not the entire browser suite;
  the emulation and speech-fixture limits above still apply.
- The initial Android keyboard-reopening run exceeded its 300-second whole-test
  deadline. Its trace shows an ordinary status read at the deadline, followed
  by successful final reopen, rename persistence, and error assertions. The
  original failed run is retained in `build/repo-optimization/browser-results`.
  Rerunning the identical case with `--trace=off` passed in 4.4 minutes, without
  changing assertions, action deadlines, viewport, or Pixel 7 DPR 2.625.
  The initial run was stopped after the viewport/keyboard case passed. The
  follow-up disabled keyboard tracing; Talk Quest retained lightweight failure
  traces with passive screenshot/snapshot capture disabled. Logs are retained
  separately as `browser-tests.log` and `android-no-trace.log` in the same QA folder.
- The initial Android natural-loss case reached its 40-second encounter wait
  with all eight words spawned, seven missed, and the last word still expiring.
  Trace samples show continuous unpaused progress at roughly 0.57 simulation
  seconds per wall second under software rendering. The encounter poll now
  allows 60 seconds and attaches bounded progress diagnostics on failure;
  the 120-second test budget and all loss/save/retry/layout assertions remain.
  The targeted rerun passed in 1.5 minutes. Its log is `android-rematch.log`;
  the four WebKit results are in `webkit-tests.log`.
- Desktop timing artifacts record trusted tap to cue-source start at 1.0-3.9 ms
  for six Match clicks and 1.3-2.9 ms for nine Memory reveals. Nine Voice Pop
  cues start 2.1-3.0 ms before hit publication, including a chest award. These
  are browser scheduling observations, not physical audible onset; the Pop
  context reports 10 ms base latency and 64 ms output latency separately.
- Deployed to [production](https://gentle-forest-02ff42900.3.azurestaticapps.net/?v=f670f1bf56398e72)
  on October 2, 2026 with `tools/deploy-web.ps1 -SkipBuild`, after the script
  reverified the receipt. All six live startup files (HTML, engine JS/WASM,
  two audio worklets, and the game pack) returned HTTP 200 and matched the
  tested build's SHA-256 hashes. HTML remains `no-cache`; hashed files retain
  immutable caching, and WASM uses the correct MIME type. Evidence is in
  `build/repo-optimization/production-after.json` and `deploy.log`.
- A fresh Chromium session at the production URL passed startup, the real
  entry-button gesture, visible game canvas, and player-control publication,
  without page or game-script errors. Evidence is in `production-browser.json`
  and `production-startup.png` in the same QA folder. This is a production
  startup smoke check; the gameplay regressions above ran against the identical
  local build.
