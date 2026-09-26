# Single-player system speech restoration — 2026-09-26

## Behavior

- Voice Pop starts directly with the browser's `SpeechRecognition` or
  `webkitSpeechRecognition` service. Multiplayer selection, voice enrollment,
  speaker identification and player rankings have been removed.
- The single-player round retains vocabulary hints, explicit homophones, live
  captions, scoring, pause/resume and the recorded Pip report.
- Builds no longer prepare or publish local speech models. Rebuilding removes
  known retired runtime assets while preserving unrelated output files.
- Cleanup removes unused round/view state and the unused palette argument,
  simplifies recognition deduplication, and drops obsolete test fixture counters
  and duplicate mode-button geometry calculations.

## Validation

- Native Voice Pop model: 20,439 assertions passed; scene: 728 checks passed
  across six viewport sizes; narration: 60 checks passed.
- `npm run test:flow`: 12 native suites, 2,742 checks passed.
- Node speech-host, report-asset, Web-export and deployment contracts: 82 tests
  passed, including prefixed browser recognition and safe retired-asset cleanup.
- `npm run build:web` succeeded: 13.64 MB compressed startup payload, 87 optional
  audio assets, 200 word pronunciations verified in the pack and no retired
  multiplayer/profile assets remaining in the export.
- `npx playwright test tests/browser/voice-pop.spec.cjs tests/browser/voice.spec.cjs tests/browser/theme-picker.spec.cjs --workers=2`:
  87 passed, zero failures, across desktop Chromium, iPhone WebKit and iPad
  WebKit configurations. Each configuration passed the complete 30-second round,
  permission/retry lifecycle, scoring, report, replay, layout and theme checks.
- After cleanup, reran the native model and scene suites, all 56 speech-host
  tests and 23 export/deployment tests, and rebuilt the Web export successfully.
  Nine focused browser checks passed across the same three configurations,
  covering direct recognition startup, revised interim captions and scoring,
  permission recovery and microphone release on mode exit. Their artifacts are
  in `test-results/solo-system-cleanup/`.
- Inspected desktop play, results and room screenshots, plus iPhone room and
  results screenshots. The test server uses port 4173 independently of the
  existing development server on port 41773.
- All 594 pre-existing resource import files remained byte-for-byte unchanged.

Evidence is in ignored `build/solo-system-*.log` files and `test-results/`.
Browser tests supply speech events without opening a physical microphone; device
configurations verify browser behavior and layout, not real-person recognition
accuracy. No production deployment was performed.
