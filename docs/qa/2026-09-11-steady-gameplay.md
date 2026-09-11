# Steady gameplay — release verification

Answering now keeps the playfield visible. Match and Memory retain card positions
and original word/image faces through mistakes, successful pairs and Continue.
Sky and Listen retain the target and both answers during review. Feedback uses
space reserved before the first answer, with a fixed Continue position for both
one-word and two-word corrections. Learn continues to page in place.

## Cause and changes

The baseline at `37fd98d` reproduced the jump in desktop Chromium and iPhone
WebKit. Both profiles recorded 28 input/screenshot states with unchanged canvas
bounds, viewport, scroll, document time origin and navigation count. The jump
came from hiding the entire board to show WordLesson after each answer. The
different one-word/two-word layouts also moved Continue by about 61–65 CSS px.

- The four answer modes now reserve a compact review area below or beside the
  board. Wrong answers and successful answers change feedback in that area.
- Matched cards retain their original image or word, position and font size.
  Match no longer bounces/scales correct cards or shakes incorrect cards.
  Local marks, color and particles still communicate the result.
- Sky's entrance is limited to the first question: 12 px over 0.24 seconds.
  Further questions update in place, including with normal motion enabled.
- The compact picture is a pronunciation button. Continue remains in the same
  slot, with previous/next slots reserved for reviewing multiple associations.
- Browser screenshot review caught clipped feedback headings. Compact headings
  now use short instructions and reserve counter space only for multiple words;
  new-sticker headings keep the complete word and fit their available width.
- Small square Memory uses four columns so complete nouns remain readable.
  Narrow cards fit text to their actual label width. A catalog-wide text-width
  regression covers all 140 words across five small-card sizes.
- Learn's keyboard/controller focus now advances to an enabled control at the
  endpoints. Rewards restores the control focused before the modal opened.
- The main content container now shrinks back after temporary minimum-size
  changes, preventing stale clipping after resizing or switching modes.

## Verification evidence

The new native Match regression first failed 131 checks on the previous layout.
The browser regression also failed on the previous export because the untouched
card disappeared during wrong-answer feedback. These red results are retained
under `build/steady-match-red.log` and `build/steady-flow-baseline/red-results/`.
The baseline report and its geometry/screenshot records are under
`build/steady-flow-baseline/`.

Native checks cover stable card/control bounds, original matched faces, wrong
retry and correct Continue, modal focus, input locks, small and resized viewports,
and both motion settings. Memory also has 12 reviewed native screenshots at
480×480 and 480×900. Small square Match retains its 48 physical px touch target.

Browser checks use actual pointer/touch actions and reuse the original card and
Continue coordinates. They compare screenshot patches of untouched cards and
targets, complete all five Memory pairs, claim a Match chest, retry choice
questions, and page Learn forward/backward. Browser device profiles are desktop
Chromium, iPhone WebKit and iPad WebKit; normal-motion cases also use 320×568.

Final `npm test` passed: **27 native suites, 18,262 checks/assertions**, zero
failures; **100 Node passes**, zero failures, one pre-existing external
chest-source skip. Log: `build/steady-flow-native-final.log`.

`npm run build:web` passed with Godot 4.7.1: **12.11 MB** startup transfer,
140 word pronunciations and 28 audio assets loaded on demand. Running Godot
against the actual exported PCK verified **19 Unity texture overrides and 140
original fallback images**, zero failures. All 19 source and compiled-texture
hashes remain identical to the previous art release. Logs and the machine-readable
asset report are `build/steady-flow-build-final.log` and
`build/steady-flow-art-verification.json`.

The frozen export, verified through HTTP at port 4181, contains:

- Pack: `game-6c1c21a4707383e7.pck` (5,756,644 bytes).
- Pack SHA256: `6c1c21a4707383e7e0ab5867ef98c2c4c2d464167cd56bec3a4d309e563eadf1`.
- HTML SHA256: `9b9e2d7a8956a53dcb73a46c3502ea4384b7f70e2942aa57a0d4d52c291ffd81`.

Host browser regressions passed **30/30** (desktop Chromium 17, iPhone WebKit 8,
iPad WebKit 5), with zero failures, skips or retries. They cover rewards and
adventure return, a gift-to-Match-to-chest loop and reload, real browser audio,
speech input/stop/fallback, controller reconnect, orientation, small-screen
navigation and denied-save recovery. Report: `build/host-regression-report.json`.

The first final-export continuity run completed **47/48** cases: desktop Chromium
16/16, iPhone WebKit 16/16 and iPad WebKit 15/16. The remaining iPad case reached
the 90-second whole-test limit after completing all five Memory pairs, claiming
and saving its piece, repeating the lesson, and revealing the ninth card in the
repeated board. Its trace shows continuing correct input responses, with no
individual assertion timeout. The original failure evidence remains in
`build/steady-flow-baseline/final-report.json` and `final-results/`.

An independent pixel scan read all **206** final-run screenshots. The only six
solid-color images were the known Memory live-resize states described below;
the other 200 images were neither blank nor nearly blank. The full image list
and pixel statistics are in `build/steady-flow-final-image-scan.json`.

The targeted Memory small-layout rerun passed on all three profiles with actual
pixel assertions and both page and raw-canvas PNGs retained. Initial portrait
and Study page images had at least 64 sampled colors. After resize, the two Windows
WebKit profiles had one page color but 108–193 raw-canvas colors; desktop kept
rendering in both captures. The explicit presentation limitation annotation is
restricted to Windows WebKit after a live resize with exactly one page color.
Initial page images and all raw-canvas images must show rendered content.

The two-round iPad Memory case also reached the original 90-second budget on
its first isolated rerun despite completing its final assertions. Only that
full-flow case now has a 120-second total budget; individual assertion deadlines
are unchanged. Its final isolated rerun passed **1/1 in 32.3 seconds**, confirming
the multi-profile run's timing variability without a functional assertion failure.
The targeted reports are `build/steady-flow-baseline/rendering-regression-report.json`
and `build/steady-flow-baseline/memory-complete-report.json`. The initial timeout
reports remain intact. All 48 continuity scenarios now have passing evidence,
subject to the explicit WebKit presentation limit below.

### Windows WebKit resize investigation

Visual inspection caught a gap that input assertions alone missed: after a live
viewport resize, Windows WebKit's page screenshots showed a solid background.
The same sequence reproduced on both the untouched baseline at port 4173
(`game-2c5d82a29e601ea7.pck`) and this export at port 4181. A separate diagnostic
case and the two-version comparison completed with no JS errors or WebGL context
loss. GL draw calls and animation frames continued throughout.

Raw PNGs read from the same canvas showed the complete rendered game at 320×320
and 640×320, including all ten Memory cards, Study and the reserved review area.
This isolates an existing Windows WebKit presentation/capture limitation rather
than a new Godot layout regression. It does **not** establish that the affected
WebKit runtime's displayed window is correct; raw canvas validation is explicitly
separate from composed page validation. Original page screenshots and raw PNGs
are retained together under `build/memory-resize-compare-results/`, with context,
frame and draw-call records in each case's `states.json`.

## Limits

The separate Chrome Canary first uncached WASM compilation delay is not fixed by
this gameplay change. Windows WebKit device profiles do not replace physical
iPhone/iPad testing. Existing word recordings are reused. The licensed Unity
import remains an ignored local input; clean checkouts use the SVG fallbacks.
At the extreme 320×320 viewport, Memory cards are about 44×34 CSS px; they remain
operable, but their height is below the 44 px touch-target recommendation.
