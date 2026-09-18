# Stay and play before entering

The loading playground now stays open after the game is ready. Its 52-pixel
Enter game button is disabled during download/preparation and enabled after
the existing 20/50/80/98/100 percent sequence finishes. Ready text invites the
player to keep dancing or enter. Chest taps, Pip's poses and optional music
continue without a time limit. Loading completion never steals keyboard focus.

Godot remains paused and its canvas inert until explicit entry. Enter resumes
the game once, stops the playground music/animations and focuses the canvas
without scrolling. Xbox A still plays with the chest; a new Start press enters
on release, preventing that same press from opening My Rewards. Held buttons
across readiness, visibility changes and controller disconnects cannot enter.
Startup failures remove entry and retain the existing Retry recovery.

The compact layout also fits 320 by 320 pixels. Existing browser flow helpers
now click the entry button after every successful page load or reload.

## Local verification

- 67 Node checks passed for host speech, persistence, export packaging and
  embedded Pip wardrobes. No native gameplay code changed.
- Web export verified 200 word pronunciations and 174 optional paths with no
  failures. Startup is 14.72 MB with 87 on-demand audio assets. Tested pack:
  `game-c3aa9edf8cc78e55.pck`.
- Loading tests cover the staged progress sequence, minute-long retained
  playground, touch/keyboard/mouse entry, duplicate readiness/clicks, real music
  retention and shutdown, controller release, error recovery and paused native
  game input. Real startup also passed at normal and four-times-slower CPU.
- All 55 desktop loading/startup scenarios passed, including the corrected
  caption test rerun. Seven additional desktop game regressions passed: actual
  engine loading, native touch selection, held controller A, ordinary and
  below-fold iframe entry, persistent Memory pairs and Voice Pop recovery.
- iPhone and iPad WebKit passed all 12 selected entry, real card input,
  controller, loading music capability and retained-playground cases.
- Actual rendered screenshots were reviewed at 1366x768, 390x844, 844x390,
  320x568 and 320x320, plus the real ready and entered game screens.
- A pre-existing caption-selection test was trying to double-click the hidden
  accessibility-only sparkle count. It now targets the visible caption.
- The below-fold embedding test explicitly scrolls the host iframe into view
  before clicking Enter. It verifies that background loading does not scroll
  the host page and entry focus does not move the user's scroll position.

Audio playback was measured in Chromium. Windows WebKit has no AudioContext;
its checks verify the explicit unavailable state and working entry/dances.
Speech tests use fixtures and do not open a real microphone.

Evidence: `build/voice-pop-qa/loading-enter-*`.

## Reproduction

```powershell
node --test tests/voice-host.test.cjs tests/playroom-host.test.cjs tests/web-export.test.cjs tests/pip-wardrobe.test.cjs
npm run build:web
npx playwright test tests/browser/loading.spec.cjs tests/browser/startup.spec.cjs --project desktop-chromium
```
