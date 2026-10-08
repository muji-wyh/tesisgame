# Voice Pop treasure

Every round starts with zero chest opportunities. Accepted spoken hits keep the
existing point and combo rules; crossing 100, 200, and 300 points awards one
chest each, capped at three. The HUD shows points, the chest total, and the next
milestone. Each award produces a gold badge, rays, and particles. Reduced motion
keeps a readable stationary award message.

The result screen shows the round's points and three gold progress bars for
100, 200, and 300 points. Each row shows cumulative points toward its goal
(150 points gives 100/100, 150/200, and 150/300), an earned or remaining label,
and a chest icon. The reward summary does not create or consume rewards, and
scores above 300 keep all three bars full. Zero-score results retain the goals
without claiming a chest. The compact layout keeps the actions visible on small
phones; short landscape screens put them before the scrollable reward rows.

The icons reuse the integrated Royal closed pose from **Modern 2D Animated
Chests Pack FREE Demo 1.0.2**, by **Bobardo**, Unity Asset Store product **360538**,
under the **Standard Unity Asset Store EULA**. The original source mapping and
hash are in `assets/chests/SOURCE.txt` and `assets/chests/manifest.json`; the
acquired artwork is already a production asset. A cropped atlas removes its
transparent margins without changing the source image. These static icons
represent earned opportunities, not the randomly selected reward-room designs
or their opened state; the existing rig still handles actual chest animation.

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
surprises do not modify shared medal or toy progress.

## Shared chest catalog

The eight worlds now use eight different chest types in Match, Memory, and the
Voice Pop treasure room.

| World | Chest type | Source |
| --- | --- | --- |
| Spring | Royal | Existing imported 2D rig |
| Summer | Energy | Existing imported 2D rig |
| Autumn | Harvest Keepsake | POLY STYLE Treasure_Chest_4a, live model |
| Winter | Crystal | Existing imported 2D rig |
| Ocean | Lagoon Pearl | POLY STYLE Treasure_Chest_1a, live model |
| Space | Moonstone Vault | Bobardo Epic Chest, live model |
| Jungle | Meadow Explorer | Ekrem Low Poly Chest Animated, live model |
| Candy | Strawberry Bonbon | POLY STYLE Treasure_Chest_2a, live model |

The five additional designs render real meshes into transparent, adaptive
512-1024 pixel viewports. Moonstone remaps the original 1024 pixel Epic atlas
and retains its source ambient occlusion. The remaining designs use source
geometry and UVs with adapted pastel, wood and pearl material colors. Four
game-authored hinges and Moonstone's magnetic cover lift animate continuously,
with pressure feedback and real interior lighting. They retain the shared
five-second performance, cancellation, reduced motion, and exactly-once rewards. Source package hashes,
license references, and motion provenance are recorded in
`assets/chests/downloaded/SOURCE.txt` and its manifest. Exact source designs,
geometry adaptations and available source animations are documented in
[the chest asset record](assets/chest-refresh.md).

The GLB files and their Godot import sidecars are private local build inputs
excluded from Git. They ship inside the compiled game pack. Restore them with
Blender running `tools/prepare-chest-models.py`, then run
`python tools/prepare-chest-models.py --optimize` followed by
`node tools/package-chest-models.cjs` before importing or building a fresh
checkout. The retired 320 pixel opening frames are no longer bundled.
