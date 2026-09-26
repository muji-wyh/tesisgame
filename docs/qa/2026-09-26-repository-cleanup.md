# Repository cleanup — 2026-09-26

## Audit scope

The baseline contained 1,625 present tracked/source files: 1,262 asset files,
98 documentation files, 56 native script/UID files, two scenes, 162 test files,
28 tools, three Web files, 13 root files and the build-directory ignore marker.
The audit covered reference paths, dynamic resource naming, asset manifests,
test entry points, generation tools, current documentation and ignored output.

All 28 native scripts and both scenes remain reachable. Asset hashes found no
identical-content duplicates. All 630 original import metadata files had source
files; the vocabulary, themed resources, chest manifest and recorded audio
accounted for the assets. Private imported media retain their documented
fallbacks and provenance.

## Changes

- Replaced repeated npm shell chains with an explicit test runner. The default
  plan runs every native and Node test file once, includes Pip audio checks,
  preserves focused commands and vocabulary-test frame timing, and offers
  `node tools/run-tests.cjs --list` for inspection.
- Removed unused room button tracking and its uncalled duck-trick handler,
  unreachable medal mystery artwork and wiggle logic, and an unused button
  style. Contrast coverage now exercises the actual action-button styles.
- Removed eight unused CSS variables from both color schemes, two unused test
  imports and a duplicate browser-render helper.
- Removed 18 unused messages from the active voice catalog and generation
  requirements. Removed ten unmodified recording/import pairs, totaling
  1,894,012 WAV source bytes (1,899,108 bytes including import metadata). Eight existing
  ocean/space/jungle/candy arrival/opening recordings and their modified import
  metadata remain unchanged and excluded from the Web export. Active effects,
  theme voices, word pronunciations and Voice Pop reports remain available.
- Updated current documentation to match the result actions, available modes,
  voice catalog and confusable-word selection rules.
- Repaired four stale page-visibility test fixtures. They now resume the page
  after checking hidden-page cancellation, before simulating more interactions.
  This preserves every assertion and restores 13 previously skipped reward
  animation checks; chest timing and behavior remain unchanged.

## Retained files and further opportunities

- The original 594 modified import files remain protected by the pre-existing
  hash snapshot. The eight preserved legacy recordings can be considered for
  removal together with those import changes in a separate cleanup.
- Asset generators, importers and source/provenance manifests remain useful
  for reproducing shipped artwork and audio. Historical plans and QA reports
  describe earlier versions and remain as release evidence.
- Legacy save migration and test observation helpers still have consumers.
  The hidden Memory status label supplies accessibility announcements.
- The ignored build directory contained about 2.68 GB. Its retired
  `multiplayer-toolchain` and `multiplayer` caches account for about 2.16 GB;
  these are local cleanup candidates, not shipped source dependencies. Local
  caches and prior test evidence were retained.
- Splitting the large game UI or consolidating progression calculations would
  require a separate behavior-focused refactor. No whole remaining native
  script or scene was identified as safe to delete.

## Validation

- Every native suite passed: 56 scripts and 72,460 checks. The initial `npm test`
  exposed the stale visibility fixtures described above. After repairing those
  fixtures, the main suite passed its 1,500 assertions; a diagnostic run then
  completed the remaining 55 native suites with no failures. These results are
  combined coverage, not a claim that one uninterrupted `npm test` run passed.
- All 12 Node test files passed, totaling 153 tests. After restoring complete
  provenance coverage for the retained Jungle/Candy recordings, the four
  world-audio tests passed again.
- Syntax checks passed for 70 CommonJS files, three PowerShell scripts and one
  Python script. `git diff --check` passed.
- An independent SHA-256 comparison confirmed that all 594 original modified
  import files remain byte-for-byte unchanged.
- `npm run build:web` succeeded: 13.63 MB compressed startup payload and 69
  on-demand audio assets, down from 87. The exported pack contains all 200 word
  pronunciations and excludes all 138 active optional source/import paths.
- A second check opened the final fingerprinted pack and confirmed that all 18
  retired voice source paths and the eight preserved imported payloads are
  absent. The final HTML contains exactly 69 optional audio URLs, and the
  output directory contains no stale generated audio files.

- Focused browser regression completed with 11 passes, four skips and no
  failures across desktop Chromium, iPhone WebKit and iPad WebKit. Coverage
  includes dark-theme loading contrast, reduced motion, room scrolling,
  optional audio, the Voice action and saved room rewards. Two WebKit cases
  require Chromium touch dispatch; two cannot run because this Windows WebKit
  runtime exposes no WebAudio. The browser suite supplies speech events and
  does not measure real-person recognition accuracy.

- Visual review confirmed the desktop room, Voice control and a fresh 320px
  WebKit room. Live resizing reproduces the existing
  [Windows WebKit presentation/capture limitation](2026-09-11-steady-gameplay.md#windows-webkit-resize-investigation):
  the composed page screenshot is blank while the raw canvas renders the full
  room. A focused diagnostic found correct geometry, no WebGL context loss and
  a normal page screenshot after reloading at 320px. The original focused test
  and diagnostic each passed again. Raw-canvas verification does not establish
  that the resized WebKit window is displayed correctly; this existing
  limitation remains. No product changes were made for it.

Local evidence: `build/repo-cleanup-native-fixture-check.log`,
`build/repo-cleanup-diagnostic.log`,
`build/repo-cleanup-diagnostic-failures.json`,
`build/repo-cleanup-provenance-check.log`,
`build/repo-cleanup-build.log`, `build/repo-cleanup-export-check.log`,
`build/repo-cleanup-browser.log`, `build/repo-cleanup-resize-canvas.log`,
`build/repo-cleanup-inventory.json`, `test-results/repo-cleanup/` and
`test-results/repo-cleanup-resize-canvas/`. No production deployment was performed.
