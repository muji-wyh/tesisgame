# Wider top Jelly fireworks - 2026-10-24

The collected-word fireworks at Lv4-Lv6 now open into broader blossoms and
continue into longer downward trails. Their cosmetic canvas extends below the
reading region so the lower blossoms are no longer cut off at its edge. All
effects draw beneath all live word cards and keep their rotated artwork clear
of the existing control exclusions.

Card sizing, placement, anticipation, reading time, collection transactions,
board fireworks, and audio retain their existing behavior. The three acquired
particle textures were inspected again; their source and license records remain
in [Jelly level feedback](../assets/jelly-level-feedback.md#acquired-material).

## Native verification

Four focused suites passed with 31,221 checks/assertions:

| Suite | Checks/assertions |
| --- | ---: |
| Word reveal | 11,195 |
| Word Jelly view | 19,743 |
| Hybrid view | 182 |
| Board collection effects | 101 |

New regressions cover separate bounded effect space without smaller cards,
upward spokes turning down, rotated texture clearance around live controls,
reduced-motion stability, and effects beneath concurrent reading surfaces.
Existing release timing, repeated collections, resize, and cleanup checks pass.

The deterministic study compares 479 baseline (`eca3ddff`) and final native frames across
Lv3/Lv4/Lv6, desktop, portrait, landscape, manual collection, batches, and reduced
motion. Every matched frame preserves fusion states, board effect states, and
all non-effect reading-card fields. Inspected before/after stills show wider
top blossoms and visible falling tails at 1.5 seconds after release, with clean
card text during repeated pickups. These are silent native samples, not physical
device performance or audio playback measurements.

## Web verification

The Web build passed content and native pack validation, then recorded 13,600
source inputs and 117 output files in its receipt. The resulting game pack is
`game-0dc7aeade135343d.pck.br` (38,457,125 compressed bytes).

The real-input additive merge case passed in desktop Chromium and Android
Chromium emulation. It creates seven matching words, merges through Lv6,
rejects an over-limit merge, and collects the result. Both runs observed the
visible contracting card, full-opacity release, and a rendered top-firework
tail after 1.1 seconds while retaining the reward and board-bouquet checks.
Both captured Web tail screenshots were inspected. The targeted browser fixture
now reflects the visible charge introduced in `2c1c6958`; its former invisible
charge assertion was obsolete. All action deadlines remain unchanged.

Evidence is preserved under `build/qa/jelly-fireworks-2026-10-24/`, including
baseline sources and hashes, `matched-comparison.json`, suite logs, comparison
sheets, and silent 30 fps comparison clips. `after-r01` and
`after-r02-before-layer-fix` are intermediate evidence; `after-r02` is final.
