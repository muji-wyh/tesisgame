# Jelly garden artwork

The integrated **Kenney Background Elements Remastered (1.0)** artwork creates
an airy layered garden for Jelly Match and Jelly Words. Pale clouds and distant
hills provide depth; trees and low foliage belong at the outer scene edges so
the colorful jelly pieces and vocabulary remain the focus.

## Source, rights and current status

- Creator: [Kenney](https://kenney.nl/), identified in the pack's original license.
- Original material: the user-supplied, already acquired
  `Q:/uwok/Kenney Game Assets All-in-1 3.7.0/2D assets/Background Elements Remastered`
  directory. This task did not download or purchase the pack.
- License: **CC0 1.0**. The original supplied
  [license file](../../assets/images/jelly-match/garden/LICENSE-CC0.txt) permits
  personal, educational and commercial use; attribution is optional.
- Imported on October 13, 2026: eight inspected original PNGs and the original
  license copied byte-for-byte into the repository. Source and destination
  hashes are recorded in [the manifest](jelly-garden.json).
- Animation availability: static PNG artwork and vector originals; no baked
  environment animation clips. Runtime tint, opacity and gentle horizontal motion
  of two clouds are game-authored presentation. Original image pixels remain
  unchanged.
- Integration: all eight images are used by the shared backdrop for Jelly Match
  and Jelly Words. The cloud bank's lower edge fades into the sky in wide layouts.
  GameUI pause and reduced-motion hooks stop the two drifting clouds.
- Validation status: source artwork and copied file identity verified. Native
  composition and readability reviewed in both modes at 320 x 568, 393 x 852,
  852 x 393 and 1473 x 1175. Lifecycle and reduced-motion checks passed.
  Chromium and simulated iPhone WebKit gameplay and layout checks passed.

## Selected material

All source paths below are relative to the supplied pack directory. Imported
PNGs are in `assets/images/jelly-match/garden/`.

| Imported file | Original source | Intended role |
| --- | --- | --- |
| `sky.png` | `Backgrounds/backgroundEmpty.png` | Complete pale sky, cloud and distant-hill illustration |
| `hills.png` | `Backgrounds/Elements/hills.png` | Separate transparent distant-hill layer |
| `cloud-bank.png` | `Backgrounds/Elements/cloudLayer1.png` | Transparent cloud bank with soft lower fade |
| `cloud.png` | `PNG/Retina/cloud3.png` | Rounded larger cloud |
| `cloud-small.png` | `PNG/Retina/cloud1.png` | Alternate rounded cloud |
| `tree.png` | `PNG/Retina/tree.png` | Tapered tree at a scene edge |
| `tree-long.png` | `PNG/Retina/treeLong.png` | Tall tree for a second perimeter silhouette |
| `foliage.png` | `PNG/Retina/bushAlt1.png` | Low layered shrub used as edge foliage |

`foliage.png` is the source shrub illustration. Its pointed leaf
tips work as a small cropped foreground cluster, outside the interactive board.
The imported files preserve source dimensions, transparency and all original
pixels. Runtime fitting should preserve their aspect ratios.

The ignored `build/jelly-background-asset-scout.png` sheet compares source
artwork; it is not a screenshot of the game. The selected PNGs were also
inspected directly, including both clouds, both trees and the shrub. The
alternative New Platformer Pack and Platformer Assets Candy materials remain
source review only and are not imported for this direction.

## Runtime review evidence

Four native after captures were visually reviewed for the garden composition,
word contrast, cropped tree and foliage edges, and phone/desktop framing:

- `build/jelly-backdrop-review/after/jelly-393x852.png`
- `build/jelly-backdrop-review/after/jelly-1473x1175.png`
- `build/jelly-backdrop-review/after/word_jelly-393x852.png`
- `build/jelly-backdrop-review/after/word_jelly-1473x1175.png`

These are runtime captures, separate from the source comparison sheet. They
establish the reviewed still composition. Compact portrait and landscape captures
are in `build/jelly-backdrop-review/after-compact/`. The native Jelly Words flow
suite passed 95 checks; Jelly Match passed 403 checks after updating its obsolete
Home preview field assertion.

The shared garden lifecycle suite passed 145 checks covering input pass-through,
Home, notebook and browser-background pauses, replay, initial reduced motion and
resuming the same cloud phase. A rendered standalone run passed 28 checks,
including evidence that cloud transforms leave static scenery drawing cached.
Both 60- and 80-second cloud cycles stay within eight CSS pixels horizontally
and move at less than one CSS pixel per second. These captures used ANGLE's
software renderer; they are composition evidence, not device performance results.

Browser checks covered real Jelly Match drags in portrait and short landscape,
and Jelly Words merging, pictured-word collection, one-time coin credit, Home
pause/resume, responsive layout and wallet restoration after a reload. Both
Chromium and simulated iPhone WebKit passed. The initial Chromium Words run
reached its 90-second suite limit during the final page reload; the complete
retry passed with a 180-second limit. Screenshots and logs are retained under
`build/jelly-garden-browser/` and `build/jelly-garden-browser-retry/`.

## Reproduction

With Python and Pillow available:

```powershell
python tools/import-jelly-garden-assets.py
python tools/import-jelly-garden-assets.py --check
```

Use `--source <library-root>` when the supplied All-in-1 library is stored in a
different location. The importer reads only the eight selected PNGs and the
pack's license. It performs no image conversion, recoloring or resampling.
`--check` needs only the repository: it verifies the exact selected mappings,
source/destination hashes, PNG format, dimensions, color modes, byte sizes and
original license. Normal builds do not require the external source library.
