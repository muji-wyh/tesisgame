# Talk Quest retirement — 2026-10-06

Talk Quest was removed from the game library, native scenes and controllers,
speech and persistence bridge, dedicated audio banks, Web accessibility help,
and build inventory. Match, Memory, and Voice Pop remain available. Their
players, leaderboards, shared rewards, and speech flows remain supported.

Existing Quest saves are left untouched and are no longer read. Tracked runtime
artwork, implementation, and dedicated tools/tests were removed. Historical
provenance remains archived; ignored private source assets are preserved locally
and excluded from both Godot import and Web export.

## Validation

- `npm test`: the first 46 native suites passed. The existing exhaustive
  `vocabulary_layout_tests.gd` suite reached its 600-second timeout without
  emitting an assertion failure. This run is not a complete passing `npm test`.
- The remaining 34 native suites were then run sequentially and passed, bringing
  the total to 80 passing native suites and one timed-out suite. Coverage includes
  stale Quest-mode rejection, the three-entry library, saved progress, responsive
  layouts, all remaining modes, speech lifecycle, audio, and shared chests.
- All 21 Node suites passed: 295 tests, zero failures or skips.
- `npm run build:web` passed. The verifier mounted the actual exported pack,
  inspected its complete directory inventory, and found zero retired Quest
  resources. It also verified 350 pronunciations, 12 game effects, all 8 chest
  types, 5 animated chest models, and the required audio resources.
- Focused Playwright checks across desktop Chromium and iPhone WebKit completed
  with 11 passes and one skip. They cover library navigation, persistent settings,
  speech hypothesis correction, permissions and microphone release, Match speech
  scoring, and mode-switch audio recovery. WebKit's audio case was skipped
  because this Windows runtime exposes no WebAudio; Chromium exercised playback.
- Library captures were inspected at desktop, phone portrait, phone landscape,
  medium-height phone, and 320 by 320 sizes. Bounds checks cover 390 by 420,
  390 by 600, 390 by 640, 390 by 844, 844 by 390, and 1280 by 800 as well.
  Raw canvas captures accompany page screenshots because Windows WebKit can
  present a blank compositor image after resizing.

The compressed startup payload decreased from 33,115,498 to 27,069,132 bytes
(18.26%). These are the versioned engine and game Brotli payloads, not an estimate
of network throughput or load time.

Local evidence is retained under `build/quest-removal-*.log` and
`test-results/game-library-*`. Speech fixtures simulate recognition callbacks;
they do not establish physical-device microphone accuracy or Safari audio.
