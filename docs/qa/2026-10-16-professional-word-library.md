# Professional application and word library review

The actual application was rendered at 320 × 568, 390 × 844, 844 × 390,
and 1280 × 800. Each viewport includes the Professional Match game, its open
word library, and the selected term detail. All 12 final PNGs were inspected.

## Fixture scope

These captures use synthetic content from `professional_application_flow_tests.gd`
and the clearly labelled `RenderCatalog` in
`professional_application_visual_review.gd`. The 50 terms share the existing
`assets/images/words/absent.png` image; they are deliberately not a usable
Professional curriculum. The media fixture also supplies
`assets/audio/jelly-match/collect-do.wav` to exercise scoped resource ownership.
Playback is muted during capture. Neither that sound nor the repeated image is
approved Professional pronunciation or workplace artwork.

The standalone library tests use the existing `bank.webp` vocabulary artwork
only to test a real image in the layout. These fixtures do not establish content
review, media acquisition, semantic image accuracy, pronunciation quality, or
readiness of any production module.

Rendering used Windows ANGLE with Microsoft Basic Render Driver. This is layout
and resource-lifecycle evidence, not a physical-device performance or speech test.
All saves are isolated test profiles.

## Findings and correction

- The Professional header shows the selected career and learned count in place
  of Growth progress. Long career titles stay within the header button; the
  library displays the complete title.
- The library exit, search field, and scroll viewport remain within the actual
  application at all four sizes. Term cards wrap their definitions and use one
  column on the portrait phones and two columns on wider viewports.
- Pagination creates at most eight term rows and the detail owns one selected
  image. Closing the library releases that image immediately.
- The initial review found that revealing an entire detail taller than the
  scroll viewport aligned its bottom and cut off the selected illustration.
  Selection now scrolls to the top of the detail. The final 320 × 568 and
  844 × 390 captures show the complete illustration first. Pronunciation,
  meaning, examples, and skill evidence remain available by scrolling.
- The targeted regression reserves application-header space and verifies tall
  detail behavior at both 320 × 568 and 844 × 390. It checks the whole picture
  after a term tap and the reachable pronunciation button and full skill summary.

The final standalone library suite passed **130 checks with zero failures**.
The final integrated renderer passed **48 checks with zero failures** and wrote
12 screenshots. This review does not establish production curriculum readiness
or replace touch-device and assistive-technology review.

## Reproduce

```text
node tools/run-godot.cjs --headless --path . --audio-driver Dummy --script res://tests/godot/professional_word_library_tests.gd
node tools/run-godot.cjs --path . --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/godot/professional_application_visual_review.gd
```

The renderer writes `build/professional-english/application-review/report.json`
and `{width}x{height}-{game,library,detail}.png`. Build evidence remains local and
ignored by Git. The standalone test also supports `-- --capture` with a renderer
and writes its separate fixture captures under
`build/visuals/professional-word-library`.
