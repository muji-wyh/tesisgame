# Authored Jelly renderer review

The real Word Jelly view was rendered and visually inspected at 320 × 568,
390 × 844, 844 × 390, and 1280 × 800. Each size has a board capture, a full-width
two-row preview, and both ends of the horizontally scrollable Read detail. A
180 × 220 capture verifies the safe pause explanation. All 17 PNGs were
inspected after the final layout changes.

The scene uses production Jelly skins, backdrop, buttons, font, and reward art.
Its spelling entries are explicit automated fixtures, with the existing cat
image and audio reused solely for layout. These images do not establish
Professional curriculum media readiness or editorial approval. Rendering used
Windows ANGLE on Microsoft Basic Render Driver, a software renderer; this is
layout evidence, not a device performance measurement.

## Findings and fixes

- Godot retained the inherited label minimum height when the authored rectangle
  was assigned before its font and text. A 33-pixel body could retain a 50-pixel
  label, and a 70-pixel two-row body a 103-pixel label. Applying authored metrics
  before the rectangle keeps both lines inside the measured body.
- Exceptional spellings place the 44-pixel Read target beside their spelling
  preview, so the target cannot cover the label at the minimum supported pitch.
- Authored picture and fragment reservations now occupy their separate horizontal
  slots, centered within the body. Fragment animation retains that measured fit.
- Resizing preserves logical identities, positions, and footprints. Read and
  undersized views pause the supply clock and restore the same board.

The final renderer run passed 473 checks with zero failures. The authored view
regression suite passed 112 checks with zero failures. This review found no
remaining label clipping, Read overlap, or misplaced two-row preview after the
fix. It does not replace touch-device, assistive-technology, or listening review.

## Reproduce

```text
node tools/capture-word-jelly-morphology.cjs
node tools/run-godot.cjs --headless --path . --script res://tests/godot/word_jelly_morphology_view_tests.gd
```

The capture command writes `build/professional-english/jelly-render-gallery.html`,
`jelly-render-report.json`, `jelly-render.log`, and 17 named PNGs. The JSON records
the actual viewport, font sizes, authored lines, tile rectangles, label rectangles,
and Read scroll positions. Build evidence remains local and ignored by Git.
