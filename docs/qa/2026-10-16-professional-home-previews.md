# Professional Home preview renderer review

The actual `GameLibrary`, real `ProfessionalCatalog`, and reviewed Retail &
Checkout and Software & Data PNGs were rendered at 320 × 568, 390 × 844,
844 × 390, and 1280 × 800. Every career and size includes the initial module
list, the last module with keyboard focus, a pending selection, focused Cancel,
and focused Retry. All 40 final PNGs were visually inspected on 2026-10-16.

These are the integrated 512 × 320 Home previews described in
`docs/assets/professional-themes.md`, composed from acquired Kenney CC0 assets.
They are not full workplace scenes. Both theme profiles and the real modules
remain pending. Loading and error states are simulated; this capture does not
write learning progress or wallet data.

## Findings and fixes

- A 180-pixel preview previously pushed the first module below the initial
  844 × 390 viewport. Preview height is now 72 CSS pixels when viewport height
  is at most 440 pixels. The first complete module is visible without scrolling
  at every tested size.
- Loading status and Cancel previously fell below the initial 320 × 568 and
  844 × 390 viewports. At heights up to 600 CSS pixels, Home now collapses the
  decorative preview while loading or displaying a recovery error. The current
  career and module title, status, Cancel, and Retry fit without scrolling.
- Normal browsing and completed recovery restore the current career preview.
  Repeated and changed artwork updates preserve the compact layout. Artwork
  remains loaded during a temporary collapse and keeps its original aspect
  ratio whenever visible. Layout is queued only when its state changes.
- Production focus scrolling brings the complete last module and action buttons
  into view. Keyboard outlines are visible; wrapping does not clip module text.
- Switching to Nursing clears the prior image. Missing Nursing artwork is not
  replaced with either reviewed preview.

The final renderer run passed **1,421 checks with zero failures**. Focused
learning-path and theme-art suites passed **211** and **11** checks respectively,
also with zero failures. An earlier Retry focus failure was corrected by waiting
for container layout after the status changed; it was a capture timing issue,
not a production focus bug.

Rendering used Windows ANGLE on Microsoft Basic Render Driver, a software
renderer. This establishes layout behavior, not device performance or
assistive-technology compatibility. It does not approve the unfinished full
workplace themes or curriculum media.

## Reproduce

```text
node tools/capture-professional-home-previews.cjs
node tools/run-godot.cjs --headless --path . --script res://tests/godot/learning_path_selector_tests.gd
node tools/run-godot.cjs --headless --path . --script res://tests/godot/learning_theme_art_tests.gd
```

The capture command writes
`build/professional-english/home-preview-render-gallery.html`,
`home-preview-render-report.json`, `home-preview-render.log`, and 40 named PNGs.
The report records viewport dimensions, module text and geometry, selector
state, preview identity and visibility, scroll position, and keyboard focus.
Build evidence remains local and ignored by Git.
