# Jelly Words powerups

The Auto merge and Treasure purchase controls share a quiet pearl surface.
A full-width title sits above the sourced item artwork and a separate coin-price
capsule, so narrow phone controls no longer squeeze the title beside the icon.
Their artwork stays separate from the stable touch target, title, and coin price.
Auto merge costs 600, 900, then 1200 coins per round;
Treasure costs 200, 300, then 400. Each item tracks successful purchases separately
and shows its next price without resetting the current feedback animation.
The latter uses the same current chest texture as the jelly fragment markers
once its cropped image is ready. The acquired Royal fallback stays visible while
that viewport warms up, without a synchronous GPU readback.

The purchase controls and Collect share one action group. When a side layout
allows a larger board, Auto merge and Treasure stack above Collect in a single
144-pixel-wide rail to the right, separated from the well by 12 display pixels.
The well and rail are centered as one group; on short screens the rail may
extend beside the supply row without entering the header. Otherwise the controls
form a compact footer under the well, with Collect in the middle. Each action
is 56 display pixels high, and the group retains twelve-pixel bottom padding.

## Artwork and acquisition

| Runtime material | Original source, creator, and rights | Acquisition and animation |
| --- | --- | --- |
| `assets/images/ui/jelly-powerups/auto-merge-wand.svg` | Kenney, [Cursor Pack 1.1](https://kenney.nl/assets/cursor-pack), `Vector/Basic/tool_wand.svg`. CC0 1.0; the original pack license is retained beside the SVG as `LICENSE-Kenney.txt`. | Acquired in the user's local Kenney All-in-1 3.7.0 collection. The original vector and 64px PNG were inspected at 32–40px before the SVG was copied byte-for-byte. Static white artwork, with a violet runtime tint; it has no source animation. |
| Current chest marker texture | Existing acquired chest rendering and tier selection, documented in [Jelly fragments](jelly-fragments.md) and [chest replacement](chest-refresh.md). | Reuses the owner's current cropped texture, including its cached model render. No new chest is downloaded. The button animates this still texture; it does not play a source rig or opening clip. |
| Royal fallback, `assets/chests/royal/closed.png` | Bobardo, [Modern 2D Animated Chests FREE Demo 1.0.2](https://assetstore.unity.com/packages/2d/modern-2d-animated-chests-free-demo-360538), `Chests/Royal/Sprites/SPR_Royal_Close.png`. Existing Unity Asset Store Standard EULA acquisition; see `assets/chests/SOURCE.txt`. | Already integrated and inspected. The known transparent margins are excluded when used as a compact icon. Static closed-chest artwork; existing source open art and other game animations are not triggered by this button. |
| `assets/coins/gold-coin.png` | Kenneth Foldal Moe / Archanor VFX, Toon FX 1.52, under its recorded Unity Asset Store Standard EULA. See [coin artwork](coins.md) and `assets/coins/manifest.json`. | Existing acquired, processed and integrated price icon. Static artwork; no new copy or acquisition. |
| `assets/chests/particles/portal_glow.png` | Existing Modern 2D Animated Chests particle artwork, with source mapping in `assets/chests/SOURCE.txt`. | Already acquired and integrated static glow. Its placement, color and opacity are authored by the game. |
| `assets/chests/milestone/sparkle.png` | Kenneth Foldal Moe / Archanor VFX, Toon FX 1.52, under the recorded Unity Asset Store Standard EULA. Source details and hashes are in [Jelly fragments](jelly-fragments.md). | Existing acquired four-point glint, inspected before reuse. Static texture with game-authored appearance timing; no Unity prefab or shader is imported. |

The wand's local acquired source is
`Q:/uwok/Kenney Game Assets All-in-1 3.7.0/UI assets/Cursor Pack/Vector/Basic/tool_wand.svg`.
Source and integrated SVG SHA-256:
`5e1df66b84ec85ce679673d6c8b97d392c450f312cc58b6ec84f1b5194f9fbb1`.
The rounded interface panels are layout primitives, not replacement prop art.

For the October 2026 interface refinement, Kenney's locally acquired UI Pack 2.0,
UI Pack - Adventure, UI Adventure Pack, and Fantasy UI Borders previews were
inspected. The actual neutral `UI Pack/PNG/Grey/Double/button_rectangle_depth_gradient.png`
and `button_rectangle_depth_flat.png`, and `UI Adventure Pack/PNG/buttonLong_grey.png`
were also inspected. Their grey bevels, square edges, or chipped fantasy surfaces
were not integrated because they compete with the existing soft jelly material.
These remain review candidates in this project; their locally acquired files are
not integrated, and the existing wand, chest, coin, and gel assets are retained.
The source packs are by Kenney and carry their local CC0 1.0 licenses;
these inspected interface images are static and contain no animation.

## Feedback and lifecycle

Successful purchases give the sourced icon a short upward pop, a restrained
turn, and local glints over 0.62 seconds. Rejection uses a 0.42-second damped
sideways recoil and warm amber light. Titles and prices stay level, and the
touch target never changes. An insufficient balance uses a neutral price capsule
and warm readable price text while preserving clickability; only unavailable or busy actions
are disabled. There are no tooltips or explanatory overlays.

Treasure has no cooldown: it remains available while earlier Treasure fragments
are flying or their arrival effects are fading. Each click pays its current
quoted price independently and launches another two to eight fragments. New
flights overlap existing ones without restarting or skipping them. Insufficient
funds still trigger rejection feedback and leave all paid deliveries intact.
Auto merge retains its exclusive board operation.

Collect uses a horizontal mint capsule with a larger sourced word-jelly
illustration on the left and the title and inline word count together on the
right. There is no separate count badge or coin illustration. The mint, sky and
lilac gel skins and Microsoft Fluent Emoji cat are existing integrated artwork;
their unchanged source, creator, license and acquisition records are linked in
[Jelly Words](jelly-words.md). The empty state keeps this illustration and the
"0 words" count visible. Accumulated words retain the existing charge, growth,
local light and sparkle rhythm, while each pickup gives the illustration a
small compress-and-lift beat. This styling does not change collection
eligibility or reward amounts, and count changes never move the hit area.

The game owner advances the button clock. Pausing freezes the clock and hides
the transient pose and light; hidden controls do not advance. Reset clears the
transient presentation without issuing a purchase. Reduced motion uses a static
0.32-second light accent with no scale, translation, or rotation. The minimum
target is 88 by 56 display pixels, scaled through the existing UI scale.

The controls only emit the normal Button `pressed` signal. The model and wallet
own eligibility, spending, rewards, busy state, and cancellation; button
animation never commits a transaction.

## Reused sound and world effects

The game owner plays the existing pair-feedback `right.wav` on a committed
purchase and `wrong.wav` for insufficient funds, both at the established 0.48
gain. These are reused from `assets/imported-audio/pair-feedback/`; their existing
user-supplied provenance and unspecified source license remain unchanged. No
new extraction, source audio claim, or CC0 attribution is applied to them.
The source recording, processing and embedded-game limits remain documented in
[answer feedback sounds](pair-feedback-audio.md).

Auto merge selects an eligible source Jelly on each 400 ms beat and
finds a matching target, starting immediately after purchase. Each automatic drag
lasts 160 ms, followed by a 200 ms fusion and 40 ms settlement. Manual gestures
retain their existing timing. Every moving source and its target stay reserved
until contact; later beats can use other available pairs.
If only moving or settling pairs remain, the operation waits for an eligible
pair without compressing missed beats. The existing arcing motion, gentle
stretch, target glow, and sparkle trail follow each flight's own clock. Contact
starts the liquid merge and its cue at the destination. Completed words remain
on the board until the player collects them.

Automatic movement reuses the ordinary pick, contact, and merge cues. Treasure
flights reuse the existing current chest texture, `portal_glow.png`, and
`milestone/sparkle.png`. Each scheduled fragment launch plays
`assets/audio/fragments/appear.wav`, and its delivery plays
`assets/audio/fragments/arrive.wav`, both at gain 0.45. These distinct acquired
Kenney CC0 recordings, their preparation and their independent four-channel
mix are documented in [fragment audio](jelly-fragments.md#fragment-audio).
The first flight arrives after 0.42 seconds and subsequent deliveries are
staggered by 0.18 seconds. Launches and arrivals each emit once at their actual
timeline boundaries, including overlapping purchases, and do not replay after
a pause. The cues belong to the owner's committed purchase and delivery
events; the button itself plays no sound.
