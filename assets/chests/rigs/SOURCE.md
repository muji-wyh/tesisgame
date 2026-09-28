# Derived chest animation layers

These ten PNGs are deterministic derivatives of the four original Royal and
Energy chest poses from **Modern 2D Animated Chests Pack_FREE Demo 1.0.2**.
The original files, original manifest, Crystal parts, particle textures and
source record are unchanged. Source attribution and terms remain those of
[the imported source record](../SOURCE.txt); this preparation adds no license.

No generated artwork, image-generation service or replacement vector chest
was used. Visible surfaces come from the original PNGs. Previously occluded
paint behind the moving lock is reconstructed from adjacent pixels of those
same PNGs. The finished layers retain the source's material shading, silhouette,
perspective and color detail.

## Reproduce

From the repository root, run:

```sh
python -m pip install Pillow==12.2.0 numpy==2.4.6
python tools/prepare-chest-rigs.py
```

The script checks the four source SHA-256 values before doing any work, then
writes trimmed layers and `assets/chests/rigs.json`. It also checks the source
hashes afterward. The manifest records each original hash, derived hash,
dimensions, byte count, crop, rest anchor and pivot, plus the tool versions.
There are no timestamps or random operations. A second run under the recorded
versions produces the same PNGs and manifest. Original PNG trailing bytes are
never rewritten; derived images are ordinary normalized RGBA PNGs.

`build/chest-feel-assets/` contains full-canvas layer PNGs, composited closed and
open views, contact sheets against light and dark backgrounds, and a JSON
report comparing the layered closed view with the original. QA outputs are
development artifacts, not game resources.

## Geometry contract

Both styles use the original 1024 by 1024 canvas, a top-left origin and positive
y downward. Part pivots are normalized from the **top left**, unlike the
unchanged original Crystal manifest's Unity convention. A pivot outside the
trimmed image is intentional. Place a trimmed texture at:

```text
top_left = position - pivot * [width, height]
```

This exactly recovers its original canvas crop. `lid_outer` and `lid_inner`
share an anchor at the physical hinge; `lid_inner` is the upright source pose.
The runtime contracts the outside lid toward its hinge until edge-on, then
expands the inside surface. It does not crossfade complete chest frames.

| Style | Shared hinge | Lock anchor | Back-to-front order |
| --- | --- | --- | --- |
| Royal | 540, 475 | 316, 534 | lid_inner, interior, body, lid_outer, latch |
| Energy | 600, 460 | 369, 648 | lid_inner, interior, body, lid_outer, core |

`body` and `interior` use anchor 512, 512. Exact explicit polygon landmarks
live in `GEOMETRY` in the preparation script. `rigs.json` is the runtime and
verification contract; it does not replace `assets/chests/manifest.json`.

## Preparation operations

1. Divide the closed pose at a manually traced lower lid contour. The body
   keeps the original footprint and foreground details throughout animation.
2. Trace the Royal shield or Energy core, including a ten-pixel margin for
   existing contact shadow. Extract it as an independently moving part.
3. Fill the covered area using continuously sampled neighboring silver/gold
   paint and belt pixels. Affine sampling follows the surface perspective;
   it does not tile a small swatch. A six-pixel inward feather retains the
   source paint at the repair edge. Repairs are covered by the original lock
   at rest, and remain present when it releases or rotates.
4. Trace the upright inside lid from the original open pose. Retain its gold
   rim, inner shading and hinge hardware.
5. Add the original open rim/cavity behind the fixed body, inside the closed
   lid silhouette. Remove the open pose's duplicate shield/core using nearby
   cavity or rim pixels. Royal retains an eight-pixel hidden underlap beneath
   the hinge to protect against sampling cracks. Energy's actual rear rim is
   traced separately: hinge hardware and lower-lid fragments above that rim
   belong exclusively to `lid_inner`. Summer keeps its complete hinge when
   opened, while Space's detached cover exposes a clean, continuous rim.
6. Crop each part to its nonzero alpha bounds and record exact placement.
   Clear RGB values on fully transparent derived pixels. QA also includes
   `energy-detached-base.png` to inspect the cavity without a lid above it.

These are lightweight 2D rigs, not newly modeled 3D chests. Hidden surfaces
are locally reconstructed; the source's two poses have slightly different
body geometry, so the rig deliberately keeps the closed body's fixed shape
instead of blending between the two whole images. The original Energy hinge
has a small open gap; it is retained rather than painted as a new solid part.

Godot texture sidecars use `compress/mode=1` and `compress/lossy_quality=0.85`,
consistent with the existing chest textures. Runtime animation, contact
shadows, accents, theme materials, reduced motion and sound are implemented
separately from these source-derived assets.
