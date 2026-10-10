# Voice Pop treasure

Voice Pop starts with zero fragments. Each spawned word card has a 35% chance
of carrying a chest marker, fixed to that card identity. Successfully slicing a
marked card earns one fragment; unmarked cards keep their usual score and
learning credit. Missing a card gives no fragment. Repeated speech callbacks
cannot credit the same card twice.

Four fragments unlock one chest. Every five additional fragments upgrade that
same chest. Jelly Match and Voice Pop share the progression calculation and
artwork sequence: Jungle, Autumn, Ocean, Space, Spring, Winter. Levels above six
continue using Winter artwork. The round saves only its final upgraded chest.
Scores, combos, time bonuses, and word mastery retain their existing rules.

The gameplay HUD shows the current chest level and fragments toward the next
milestone. A marked card's reward flies toward the HUD. Synthesis and upgrades
reuse Jelly Match's chest performance, production glow and Toon FX confetti;
upgrades celebrate across the full screen. The microphone and round timer pause
during the performance and resume afterward. Menus, backgrounding, reduced
motion, and leaving the mode follow the same cancellation boundaries as gameplay.
The result shows the actual score, fragment count and final chest level, with an
Open chest action only when treasure exists. A round below four fragments does
not create a chest or show a chest celebration.

The integrated marker and chest artwork comes from the existing licensed chest
catalog below. Effects and audio reuse [Jelly's fragment asset record](assets/jelly-fragments.md).
No new source artwork is acquired for this change.

The batch and opened flags are saved on this device under
`wordBuddies.popRewards` (native fallback `user://pop-rewards-v1.cfg`). Older
saves with up to three tierless chests remain readable. Play again starts a fresh
round while retaining unopened treasure; the result action also exposes pending
chests from earlier rounds. Returning to the mode resumes saved treasure.
Storage failures retain the earned final level and offer Retry save. Round
receipts prevent duplicate batches. Pop surprises do not modify medal progress.

Match and Memory independently roll a 50% chance of one chest per completed
round. The outcome is fixed when the round starts and cannot be rerolled by
reopening menus, resuming, or clicking again. A round without treasure still
celebrates all matched words and offers Play again. Phrase Builder retains its
existing guaranteed chest.

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
