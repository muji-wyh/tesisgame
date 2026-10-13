# Jelly Words powerups

The Auto merge and Treasure purchase controls share the game's quiet rounded
interface framing. Their artwork stays separate from the stable touch target,
title, and coin price. Auto merge costs 1500 coins; Treasure costs 500 coins.
The latter uses the same current chest texture as the jelly fragment markers.

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

## Feedback and lifecycle

Successful purchases give the sourced icon a short upward pop, a restrained
turn, and local glints over 0.62 seconds. Rejection uses a 0.42-second damped
sideways recoil and warm amber light. Titles and prices stay level, and the
touch target never changes. An insufficient balance softens the control and
warms its price while preserving clickability; only unavailable or busy actions
are disabled. There are no tooltips or explanatory overlays.

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

Automatic movement reuses the ordinary pick, contact, and merge cues. Treasure
flights reuse the existing current chest texture, `portal_glow.png`, and
`milestone/sparkle.png`. Their arrival cue is the existing Jelly `assemble`
recording, `assets/imported-audio/chest-reference/step-detail.wav`, at gain 0.28,
with the first flight arriving after 0.42 seconds and subsequent arrivals
staggered by 0.18 seconds. The original embedded-game audio provenance remains
in [chest reference audio](chest-reference-audio.md). These cues belong to the
owner's actual purchase and arrival events; the button itself plays no sound.
