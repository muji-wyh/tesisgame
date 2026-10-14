# Jelly daytime sky

The selected **Kenney Skyboxes (1.0)** daytime panorama adds softly shaded clouds
and a bright upper-right sun to the Jelly environment. The entire source panorama
is retained at half resolution for runtime spherical projection. This is sourced
sky artwork, not a generated cloud or geometric environment placeholder.

## Source, rights and preparation

- Creator: [Kenney](https://kenney.nl/), as identified in the original license.
- Original material: the user-supplied, already acquired
  `Q:/uwok/Kenney Game Assets All-in-1 3.7.0/2D assets/Skyboxes` directory.
  No download or purchase was needed.
- Source file: `Skyboxes/skybox-day.png`, a 4096 x 2048 paletted PNG. The complete
  2:1 equirectangular image includes its original clouds and sun.
- License: **CC0 1.0**. The original supplied
  [license](../../assets/images/jelly-match/sky/LICENSE-CC0.txt) allows personal,
  educational and commercial use; credit is optional. Its source bytes and hash
  are preserved. The license identifies the pack's creation date as July 14, 2026.
- Preparation: imported on October 14, 2026. Pillow expands the original palette
  to RGB and resizes to **2048 x 1024** with `Image.Resampling.LANCZOS`, then saves
  an optimized RGB PNG. The conversion applies no crop, recoloring, repainting,
  alpha extraction or artificial detail. The original 4K file remains in the
  supplied library and is not duplicated in the repository.
- Runtime material: [day.png](../../assets/images/jelly-match/sky/day.png), with
  source and output hashes, dimensions, processing steps and decoded RGB pixel
  hash recorded in [the manifest](jelly-sky.json). The smaller texture requires
  about 8 MiB if expanded to four GPU channels, rather than about 32 MiB for the
  original. Actual GPU storage depends on the renderer's import format.
- Current status: source artwork inspected, converted, verified and integrated
  into the shared Jelly Match and Jelly Words backdrop. Runtime review evidence
  is recorded below, separately from the source contact sheets.

## Motion availability and runtime presentation

The source pack contains five static panorama images. It supplies no animation
clips, independently movable clouds, sunlight simulation or day/night system.
The sun and clouds are baked into the selected picture.

The CanvasItem shader projects the panorama with perspective framing adjusted
for the viewport aspect ratio. It restores gentle blue cloud depth, a soft sun
and a pale horizon while keeping the board readable. The existing sourced
garden remains at the low outer edges. Its old sky and flat cloud sprites are
no longer drawn over the panorama.

Game-authored motion adds a 180-second horizontal drift cycle, limited to
0.07 radians (about four degrees) in either direction, and a 120-second cycle
of restrained light intensity and warmth. Atmospheric light follows the sun
painted into the source. This is a 2D background treatment, not a physical
day/night simulation, independently animated clouds or dynamic object shadows.

The material uses one panorama texture sample per pixel. Game time supplies
its uniforms instead of shader `TIME`: Home, notebook, browser-background and
Finish pauses freeze the current phase. Reduced motion uses the neutral phase
and stops ambient processing. Static garden layers stay cached while shader
uniforms update. The shared board and Next tray have quiet pearl surfaces,
soft blue-grey rims and a light inner edge; the control layout and input bounds
are unchanged.

## Source review

All five Skyboxes panoramas and the day/morning details were inspected alongside
the existing Background Elements Remastered garden, Voxel Pack sky textures,
New Platformer backgrounds, light particles and the Nature Kit scene preview.
Daytime was selected for soft cloud depth and a cheerful outdoor atmosphere.
Night and alien variants are too dark or saturated for this direction. The
faceted Nature Kit scene would compete with the Jelly silhouettes and add a
separate 3D environment to the current 2D game.

The ignored source review sheets are:

- `build/jelly-environment-20261014-source-scout.png`
- `build/jelly-environment-20261014-sky-detail.png`
- `build/jelly-environment-20261014-light-scout.png`

These show source material, not completed gameplay or device evidence. The
pack's `Sample (Day).png` and `Sample (Night).png` contain preview branding and
are not used in the runtime material. No other sky variant, particle light or
Nature Kit model was imported for this selection.

## Runtime review evidence

Both Jelly modes were reviewed at 320 x 568, 393 x 852, 852 x 393 and
1473 x 1175. The final native captures are retained in:

- `build/jelly-backdrop-review/sky-ui-final/`
- `build/jelly-backdrop-review/sky-ui-final-compact/`
- `build/jelly-backdrop-review/sky-ui-final-daylight30/`

The first pass was too grey and enlarged the soft source sun excessively.
The final projection widens the phone field of view and restores gentle blue
cloud detail while reducing the broad sun wash. The 30-second samples establish
the appearance at a different light phase; they do not represent normal-speed
animation playback.

The lifecycle suite passed 185 checks. A rendered standalone run passed 56,
including static scenery draw caching while daylight changes. Coverage includes
Home, notebook, browser-background and Finish pauses, replay, system reduced
motion, resize, ignored input, finite shader values and continuous phase wrapping
over twenty simulated minutes. All eight before/after layout comparisons keep
board, preview, Finish, chest, Collect, powerup and Jelly bounds within 0.05 pixels.
These native captures use ANGLE software rendering and establish composition
and behavior; they are not physical-device performance measurements.

An eight-second real-time capture is retained at
`build/jelly-backdrop-review/sky-ui-final-motion/daylight-8s.mp4`, alongside 41
source frames and a timestamped report with shader and backdrop hashes. The
capture spans 8.04 real seconds and 8.03 ambient-clock seconds. Frames at zero,
four and eight seconds were inspected for restrained, continuous drift and
light changes. This is frame-sequence review, not a claim of external player
playback or a full-frame-rate device benchmark.

Private browser checks exercise real Home entry, the three initial rows, Next
dispatch and natural landing, Home pause/resume of the same round, and the system
reduced-motion setting. Desktop Chromium passed both Jelly modes, including
1473 x 1175 and 852 x 393 resizing. Initial simulated iPhone WebKit gameplay and
rendering also passed in both modes.

A separate Windows WebKit compatibility limit was reproduced: dynamically
resizing the simulated iPhone from 390 x 664 to 320 x 568 leaves the full canvas
at its clear color for more than three seconds, although gameplay remains live
and the WebGL context is not lost. The identical flow against the unchanged
deployed baseline reproduces the same failure. This is not a passed resize
check or evidence of physical iPhone behavior. First-run, bounded retry and
baseline artifacts are retained in `build/jelly-sky-browser/`,
`build/jelly-sky-browser-retry/` and `build/jelly-sky-browser-baseline/`.

Four additional fresh WebKit contexts passed the complete flow at 320 x 568
and 852 x 393, in both Jelly modes, with reduced motion enabled before startup.
All compact and landscape captures were visually reviewed without clipping.
Together with the two desktop cases, six end-to-end browser flows passed with
no page, game-script or shader errors. The consolidated evidence is
`build/jelly-sky-browser-validation.json`. Fixed-size coverage does not erase
the dynamic-resize limitation above.

## Reproduction

With Python and Pillow available:

```powershell
python tools/import-jelly-sky-assets.py
python tools/import-jelly-sky-assets.py --check
```

`--check` is read-only and needs only repository files. It checks the selected
source identity against pinned SHA-256 values, the copied original CC0 license,
the exact conversion metadata, PNG format, dimensions, mode, encoded byte hash
and decoded RGB pixel hash. It does not claim to read an unavailable source file.

Use `--source <library-root>` to prepare from another location. Adding it to
`--check` also reads and hashes the actual original source, replays the RGB and
Lanczos conversion and checks that its pixels match the imported texture. Normal
game builds need only the imported texture and license, with no external library
or network dependency.
