# Voice Pop feedback acceptance

Follow-up to the released Voice Pop mode: make Pip visibly explain the round,
remove the result scrollbar, improve the listening glow, and show live speech.

## Changes

- Pip presents a speech bubble with three pages: actual hits/score, named hit
  words and best combo, then a real round word to practise. Each page can be
  heard again; high-five retains the report and speaks its feedback. Zero-hit
  rounds give accurate encouragement. Mouth animation follows actual speech
  start/end/cancellation callbacks, with stale callbacks rejected.
- Results use hidden scrollbars while retaining wheel/touch scrolling and
  keyboard focus reveal. Bottom spacing prevents fractional-scale clipping of
  the final word. Compact screens place Replay/Back before the statistics so
  long coaching text cannot push the main actions across the clipping edge.
  Scrolling never changes scores.
- One full-viewport glow replaces the two frames. Narrow edge strips combine
  a bright core, inward falloff and slow blue/cyan/violet/pink/warm movement.
  The center remains clear and pointer events pass through. Only actual
  listening enables the glow; reduced motion uses static light.
- The HUD displays the current browser speech hypothesis, including
  interim revisions and non-matching speech. This is separate from deduplicated
  scoring. Long sentences show the newest two lines, reserving the font's actual
  line height; the bounded buffer keeps the newest 2,000 characters. Pause,
  completion and exit clear the text; it is not saved.

## Siri reference

Inspected the Siri product-knowledge and contact-update images in Apple's
[official Apple Intelligence announcement](https://www.apple.com/newsroom/2024/06/introducing-apple-intelligence-for-iphone-ipad-and-mac/).
The reference shows a bright screen edge with light diffusing inward and large
color regions, rather than a second inner frame. Reference images are retained
only as ignored research artifacts, not shipped in the game.

## Verification

- [x] `npm run test:voice-pop`: 20,334 model assertions, 658 native scene checks,
  and 52 browser-host tests passed. Covers whole interim sentences, revisions,
  no duplicate scoring, stale callbacks, three truthful report pages, zero-hit
  reports, narration lifecycle, hidden scrollbars and final-word focus reveal.
  Compact one-hit and zero-hit rounds check the complete Replay/Back bounds on
  all three report pages and again after each page's high five.
- [x] `npm run test:layout-release`: all 53 layout checks passed.
- [x] The first integrated desktop pass completed all 24 Voice Pop/Match speech
  tests. The final compact-spacing and two-line-caption corrections are isolated
  to the Voice Pop view and are covered by the final checks below.
- [x] Isolated glow checks passed in Chromium and WebKit at 390x844 and 1366x768:
  all edges/corners illuminate, center remains transparent, clicks pass through,
  stop immediately hides it, and reduced motion disables all four animations.
- [x] Final exported-game browser checks: 30 cases across desktop Chromium,
  iPhone WebKit and iPad WebKit passed (27 general cases plus all three complete
  round/report cases). The mobile report cases use canvas touch events instead
  of the unsupported mobile WebKit wheel API.
- [x] All 35 compact screenshots reviewed: 21 regular-round, 12 zero-hit and two
  long-speech views at 320x568 and 844x390. All three pages and each page's high
  five keep Replay/Back fully visible. The final review word remains reachable
  and plays its pronunciation; no scrollbar appears. Long speech shows the
  newest two complete lines, and exiting restores Match.
- [x] iPhone touch A/B checks verify actual movement while the finger remains
  down: starting in the report bubble, its surrounding gap, the statistics
  panel or its gap changes scroll from zero; downward swipes return to zero.
  This distinguishes touch scrolling from automatic keyboard-focus reveal.
- [ ] Commit, main merge/push, production deployment and verification.

Evidence is under ignored `build/voice-pop-qa/`: `feedback-final-native.log`,
`feedback-final-build.log`, `feedback-final-regression-tests.json`,
`feedback-final-desktop-report-tests.json`, `feedback-tested-manifest.json`, and
`feedback-compact/` with `report.json`, `zero-results-report.json`,
`long-transcript-report.json`, `mobile-touch-ab-report.json` and
`mobile-touch-final-tests.json`. `siri-reference/` retains the official reference
images, repeatable isolated glow probe, screenshots and `aura-report.json`.

Speech tests use supplied recognition events and never capture a physical
microphone. They verify the shipping host and game flow, not the provider's
real-world transcription accuracy.

## Release candidate

The final export is 13.24 MB compressed at startup, with 28 optional audio
resources. Pack validation found all 200 word pronunciations and checked all 56
optional resource paths without failures. The engine version is unchanged.

| File | SHA256 |
| --- | --- |
| `index.html` | `55db2c41cb27e8da5bc2e268e9c8a85b34950490497c7bb17e5378d702d9b957` |
| `game-9651e6515167d63f.pck` | `9651e6515167d63fce4ca9e7b5d85ec432c6ca08d1c54fa70e7ecb55d49a456d` |
| `engine-c8ca3724771088b0.js` | `13ce7253b63b49b659e9eee7fbdcec1d9b4e3d5c8bd1b5460c4065bd0ea68b31` |
| `engine-c8ca3724771088b0.wasm` | `35116f68540ac41acf7d71ea457added91b5e960a9cca3e2acc72918eaf01277` |
