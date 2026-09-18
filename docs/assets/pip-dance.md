# Pip dance parts atlas

`assets/images/mascots/pip-dance-parts.svg` reuses the original six
`loading-pip-*` SVG groups from the shipped loader in `web/shell.html`.
No new illustration or external artwork is included.

The transparent atlas measures **720 × 120**. Each cell is **120 × 120**, with
the source shape coordinates and colours preserved. The shared outline is
`#785D3E`, width `3`, with round line caps and joins; individual source outline
overrides are retained. Source IDs are omitted, so there are no duplicate IDs.
The loader's shadow is deliberately excluded; the native renderer draws it.

| Index | Part | Atlas region (x, y, width, height) |
| ---: | --- | --- |
| 0 | body | 0, 0, 120, 120 |
| 1 | head | 120, 0, 120, 120 |
| 2 | left-wing | 240, 0, 120, 120 |
| 3 | right-wing | 360, 0, 120, 120 |
| 4 | left-foot | 480, 0, 120, 120 |
| 5 | right-foot | 600, 0, 120, 120 |

Crop each cell as a complete 120-coordinate texture. Do not trim its transparent
padding: the native animation rotates these layers around their source joints.
Godot imports SVGs at 3× resolution in this project. Source texture regions
therefore use the imported texture height (360 pixels per cell); animation
joints and destination rectangles continue to use the 120-unit artwork grid.
For the resting composite, the source paint order is left foot, right foot,
body, head, left wing, right wing. The atlas index order is independent of paint
order.

Validation: all six XML shape subtrees match the source; every cell boundary is
transparent. Rendering and recomposing the six cells in the source paint order
produced an exact pixel match to the original Pip without its shadow (maximum
RGBA channel difference 0). Evidence remains in `build/pip-dance-atlas/`.
