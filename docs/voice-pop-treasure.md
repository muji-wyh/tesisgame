# Voice Pop treasure

Every round starts with zero chest opportunities. Accepted spoken hits keep the
existing point and combo rules; crossing 100, 200, and 300 points awards one
chest each, capped at three. The HUD shows points, the chest total, and the next
milestone. Each award produces a gold badge, rays, and particles. Reduced motion
keeps a readable stationary award message.

The result screen offers **Open chests (N)** alongside Play again. The treasure
page keeps every earned chest in one scrollable list, with distinct styles
selected once for the round. Portrait phones show one large chest per row;
wide desktop and short landscape layouts use two columns. Artwork fills each
card without a title, name, or instruction label. Accessible names still explain
how to open each chest. The Back action stays below the scrolling area.

Touch dragging and mouse-wheel input scroll with momentum and no visible
scrollbars. A swipe cancels an unfinished hold; touching a moving list first
stops it. Keyboard and controller focus reveal offscreen chests. Each chest
uses the shared Match hold, cancellation, physical release, light, audio, and
surprise sequence. Only one chest can open at a time. A released chest stays
open, and its surprise remains visible when scrolled away and back, while the
remaining chests retain their own controls.

The batch and opened flags are saved on this device under
`wordBuddies.popRewards` (native fallback `user://pop-rewards-v1.cfg`). Returning
to the results, changing modes, or reloading keeps unopened rewards. Entering
Voice Pop again resumes pending treasure before another round can start. A
storage failure keeps the same selected designs and offers a retry. Pop chest
surprises do not modify shared medal, toy, or Talk Quest progress.

## Shared chest catalog

The eight worlds now use eight different chest types in Match, Memory, and the
Voice Pop treasure room. Talk Quest keeps its twenty reviewed mechanisms.

| World | Chest type | Source |
| --- | --- | --- |
| Spring | Royal | Existing imported 2D rig |
| Summer | Energy | Existing imported 2D rig |
| Autumn | Harvest Ironwood | Casual Chests CHEST_2_T3, live model |
| Winter | Crystal | Existing imported 2D rig |
| Ocean | Tide Captain | Stylized Sea Chest, live model |
| Space | Nebula Crown | Stylized Crowned Chest, live model |
| Jungle | Bramble Relic | POLY STYLE family 5a, live model |
| Candy | Bonbon Gold | Animated Cartoon Treasure Chest, live model |

The five additional designs render real meshes into transparent, adaptive
512-1024 pixel viewports. The sea chest retains 2K runtime maps derived from its
4K source maps; the hand-painted chest keeps its original 512 pixel atlas.
The remaining designs use modeled trim and adapted materials. Source clips or
authored hinges animate continuously, with independent hardware pressure and
real interior lighting. They retain the shared five-second performance,
cancellation, reduced motion, and exactly-once rewards. Source package hashes,
license references, and motion provenance are recorded in
`assets/chests/downloaded/SOURCE.txt` and its manifest.

The GLB files and their Godot import sidecars are private local build inputs
excluded from Git. They ship inside the compiled game pack. Restore them with
Blender running `tools/prepare-chest-models.py`, then run
`python tools/prepare-chest-models.py --optimize` followed by
`node tools/package-chest-models.cjs` before importing or building a fresh
checkout. The retired 320 pixel opening frames are no longer bundled.
