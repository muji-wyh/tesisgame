# Home learning path renderer review

The real `GameLibrary` and `ProfessionalCatalog` were rendered at 320 × 568,
390 × 844, 844 × 390, and 1280 × 800. Each size includes the path choice,
the longest career card with keyboard focus, the empty search result, the module
list with keyboard focus, a pending selection, and the retry state with keyboard
focus. All 24 final PNGs were visually inspected.

The selected career is Manufacturing & Maintenance. The selected module is
People, schedules, and workplace communication. Titles and summaries come from
the real catalog. Loading and failure messages are simulated view states; the
capture does not modify saved progress or the wallet. Workplace artwork and
curriculum review remain pending and are presented that way in the interface.

Rendering used Windows ANGLE on Microsoft Basic Render Driver, a software
renderer. This is layout evidence, not a device performance measurement.

## Findings

- The path cards stack at narrow sizes and use two columns at wider sizes.
- Long career descriptions and module titles wrap inside their cards without
  overlapping adjacent rows.
- Keyboard focus has a visible outline. Production `ScrollContainer.follow_focus`
  brings the entire focused career card into view at all four sizes.
- The empty search state explains the result while preserving path navigation.
- The pending state keeps Cancel reachable. The error state enables Retry and
  displays its keyboard focus outline. The module preparation message remains
  visible in both states.
- Selection actions wrap at 320 pixels without exceeding the content area.

The final renderer run passed 729 checks with zero failures. No production Home
layout changes were needed after this review. The capture harness was corrected
to rely on production focus scrolling, rather than duplicating it with an
immediate explicit scroll call. This was a harness correction, not a product bug.
The review does not replace touch-device or assistive-technology review.

## Reproduce

```text
node tools/capture-learning-path-selector.cjs
```

The command writes `build/professional-english/home-render-gallery.html`,
`home-render-report.json`, `home-render.log`, and 24 named PNGs. The report records
viewport dimensions, card text and geometry, selector state, scroll position,
and the focused control rectangle. Build evidence remains local and ignored by
Git.
