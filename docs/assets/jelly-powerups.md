# Jelly Words powerups

The Auto merge, Magnet and Treasure purchase controls share a quiet pearl surface.
A full-width title sits above the sourced item artwork and a plain coin-price
row, so narrow phone controls do not squeeze the title beside the icon. Neutral
cream surfaces share one border treatment; the sourced artwork identifies the
tool instead of giving every card a different colored frame.
Their artwork stays separate from the stable touch target, title, and coin price.
Auto merge costs 600, 900, then 1200 coins per round;
Magnet and Treasure each cost 200, 300, then 400. Each item tracks successful purchases separately
and shows its next price without resetting the current feedback animation.
The latter uses the same current chest texture as the jelly fragment markers
once its cropped image is ready. The acquired Royal fallback stays visible while
that viewport warms up, without a synchronous GPU readback.

The purchase controls, Fill and Collect share one action group. Fill sits directly
above Collect. The three paid tools (four in main stages, including extra time)
use a side rail when it preserves larger Jelly reading space. Wide rails use two
columns; narrow footers wrap rather than overlap. Ordinary paid controls are
56 display pixels high, using compact 44-pixel controls on short screens and Boss
layouts. Fill always keeps a 44-pixel target. The group retains bottom padding.
Fill and Collect span the complete rail, including above a two-column tool grid.
Fill is an icon-only toggle: acquired downward chevrons feed a small stack of
the actual gel artwork. A separate thumb changes position as well as color.
Off is a still cream control; On has a mint rim, continuous downward icon flow,
soft local acquired glow and two tiny sourced glints. The cue stays alive while
the mode is On, including when the board is full or Challenge locks the switch.
The existing lock appears inside the enabled thumb in Challenge. There are no
Fill, On, Off, tooltip, or helper labels. The complete name and selected/required
state remain accessible to screen readers.
One quiet cream backing groups the controls; only Collect is a strong green
primary action. The divider remains visible but uses the same fine neutral edge.

## Selected-family Magnet

Press Magnet, then choose a board Jelly. The button changes to **Pick Jelly**;
pressing it again, Back/Escape, pause or leaving cancels without spending.
The preview cannot dispatch or pronounce a word in selection mode. No random
target is substituted, and no coins are charged until a valid chosen family has
a complete ordinary merge path. Holding a target briefly lights its word family.
Roots, pictures and different merged levels are grouped by their actual word
identity, never their gel color or printed substring.

One saved purchase uses the existing overlapping automatic-flight planner.
It preserves unlocked levels, real occupancy, carried fragments and frozen/locked
eligibility. Only legal complete paths are consumed; missing partners are not
invented. Other families stay on the board. It never automatically collects,
grants construction mastery or mints manual-merge combo coins. A later successful
collection owns its usual learning and rewards. The next price is independent of
Auto merge, Treasure and extra time.

Fill continuously releases real advertised supply into each physically clear
entrance. Later Jellies begin falling while earlier ones are still airborne,
without waiting for a whole packet to land or settle. Landing space is reserved
before departure, and entrance spacing follows the real fall speed so bodies
cannot pass through one another. Preview replacements wait for that same real
entrance clearance, including faster stages, rather than fading over a body
that is still leaving the tray. It stops when no reachable vacancy remains;
switching it off leaves already dispatched Jellies to finish falling normally.
It never fills instantly or bypasses paid-operation, drag, pause, save or ending
ownership. Main/unbound play has an independent optional preference.
Challenge always enables Fill and disables its
switch; this forced value never overwrites the ordinary preference.

Items remain usable while unrelated supply is falling. Auto merge and Magnet
still need a legal settled pair; incoming supply is not mistaken for unsettled
board support that would make an operation unsafe. A saved item temporarily owns
new supply, while already dispatched Jellies continue their normal descent.
After the item finishes, Fill resumes automatically without changing its selected
preference. Treasure retains its live moving-body targets and repeat-purchase
behavior, and extra time retains its independent stage-clock purchase.

## Artwork and acquisition

| Runtime material | Original source, creator, and rights | Acquisition and animation |
| --- | --- | --- |
| Fill chevrons and lock, `assets/images/ui/controls/chevron-left.svg` and `lock.svg` | Paweł Kuna, Tabler Icons 3.35.0, MIT. Original URLs, source hashes and unchanged-path integration are recorded in `assets/images/ui/controls/sources.json`; the MIT license remains in `assets/images/ui/LICENSE-Tabler.txt`. | Already acquired. Their actual source-scale review was inspected before this reuse. The chevron is rotated downward, not redrawn; its repeating descent/fade is game-authored. The source SVGs have no animation clips. The round-restart refresh icon was inspected but deliberately not reused for a mode switch. |
| Fill gel stack, `assets/images/jelly-match/gel-mint.png` and `gel-sky.png` | Zuhria Alfitra / pzUH, GameArt2D Jelly Squash Free Sprites, CC0 1.0. Existing source and acquisition details remain in [Jelly Words](jelly-words.md) and [Jelly Match](jelly-match.md). | Already acquired and integrated. The actual mint material was inspected before composing the icon; source crop and aspect ratio are preserved. Static source artwork; no new model, skin or animation is claimed. |
| `assets/images/ui/jelly-powerups/auto-merge-wand.svg` | Kenney, [Cursor Pack 1.1](https://kenney.nl/assets/cursor-pack), `Vector/Basic/tool_wand.svg`. CC0 1.0; the original pack license is retained beside the SVG as `LICENSE-Kenney.txt`. | Acquired in the user's local Kenney All-in-1 3.7.0 collection. The original vector and 64px PNG were inspected at 32–40px before the SVG was copied byte-for-byte. Static white artwork, with a violet runtime tint; it has no source animation. |
| `assets/images/ui/jelly-powerups/family-magnet.webp` | Microsoft Corporation, Fluent Emoji 3D Magnet, MIT. Original URL, original/output hashes and existing word-library provenance are retained in `assets/images/ui/jelly-powerups/sources.json`. | Previously acquired pink horseshoe magnet with silver tips, inspected before an exact-byte core-UI copy. This is integrated artwork, not a marketplace preview or a deferred age-eight dependency. Static source image; no source animation. |
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
touch target never changes. An insufficient balance uses a muted price row
and warm readable price text while preserving clickability; only unavailable or busy actions
are disabled. There are no tooltips or explanatory overlays.

Insufficient coins have a more explicit, separate 1.15-second response. The
clicked card briefly says **Need coins**, warms its surface and rim, and makes
the acquired coin and unchanged price row recoil and settle. The tool artwork
stays still: the cost, not a broken wand or chest, is the cause. The existing
`gold-coin.png` and sourced local glow are reused without new artwork or
celebration sparkles. The accessible name retains the actual tool, exact quoted
cost and actual missing-coin amount. The ordinary title returns automatically.
Rapid retries restart one bounded response; they do not stack effects, debit
coins, advance item prices, open a dialog or move the hit area.

The wallet's explicit `reason: insufficient` outcome owns this explanation.
A failed save, duplicate receipt or invalid Magnet target keeps its own normal
rejection and cannot inherit an old low-balance hint. A known low balance also
warns on the first Magnet press while preserving its free target-selection and
cancellation steps. Unknown wallet balances are not treated as known zero coins.
Pause hides and freezes the transient warning; reduced motion keeps its readable
warm state and wording without coin scaling or price motion, including when the
preference changes mid-response.

Treasure has no cooldown: it remains available while earlier Treasure fragments
are flying or their arrival effects are fading. Each click pays its current
quoted price independently and launches another two to eight fragments. New
flights overlap existing ones without restarting or skipping them. Insufficient
funds still trigger rejection feedback and leave all paid deliveries intact.
Auto merge retains its exclusive board operation.

Collect uses a full-width green action with a sourced word-jelly illustration,
a stable title and a contained completed-word count badge. During collection
the number becomes the remaining count; the full meaning stays available in
the existing accessible name. Narrow controls retain the same bounded number
under the title. No coin illustration suggests a collection fee. The mint, sky and
lilac gel skins and Microsoft Fluent Emoji cat are existing integrated artwork;
their unchanged source, creator, license and acquisition records are linked in
[Jelly Words](jelly-words.md). The empty state keeps the illustration and zero count visible. Typography fits
both width and line height in the existing UI scale, without the old eight-unit
minimum that overflowed highly scaled desktop controls. Accumulated words retain the existing charge, growth,
local light and sparkle rhythm, while each pickup gives the illustration a
small compress-and-lift beat. This styling does not change collection
eligibility or reward amounts, and count changes never move the hit area.

The game owner advances the button clock. Pausing freezes the clock and hides
the transient pose and light; hidden controls do not advance. Reset clears the
transient presentation without issuing a purchase. Reduced motion uses a static
0.32-second light accent with no scale, translation, or rotation. The minimum
target is 88 by 56 display pixels normally, or 88 by 44 in compact layouts,
scaled through the existing UI scale.

Fill has its own persistent mode clock rather than borrowing a purchase's
short success effect. The downward cycle lasts 1.4 seconds, with a quiet
2.8-second local glow breath; the status thumb crosses in 160 ms. These effects
do not dispatch supply or modify a gameplay clock. Pause freezes the pose and
retains the active style. Reduced motion retains the mint surface, downward
icon, glow and thumb position without continuous motion. Hidden/finished
controls stop advancing, and reset clears only presentation. On/Off, Challenge
ownership, real hit bounds and the ordinary preference are unchanged. Forced,
paused and reduced-motion states put the thumb on the actual selected side
immediately rather than freezing it halfway across.

Paid controls use the normal Button `pressed` signal; Fill retains its native
`toggled` path. The model and wallet own eligibility, spending, rewards, busy
state, and cancellation; button animation never commits a transaction.

## Reused sound and world effects

The game owner plays the existing pair-feedback `right.wav` on a committed
purchase and `wrong.wav` for insufficient funds, both at the established 0.48
gain. These are reused from `assets/imported-audio/pair-feedback/`; their existing
user-supplied provenance and unspecified source license remain unchanged. No
new extraction, source audio claim, or CC0 attribution is applied to them.
The source recording, processing and embedded-game limits remain documented in
[answer feedback sounds](pair-feedback-audio.md).

Auto merge and Magnet select an eligible pair on each 100 ms launch beat, starting
immediately after purchase. Each automatic flight lasts 320 ms, followed by a
110 ms fusion and 30 ms settlement. Consecutive flights overlap for 220 ms;
the next launch does not wait for the preceding 460 ms sequence to finish.
Manual gestures retain their existing timing. Every moving source and its
target stay reserved until contact, and each path preserves the inputs needed
by its later steps. Independent pairs can launch while earlier paths continue.
A step that needs an earlier result waits for that result to settle. If no pair
is eligible, the operation waits without compressing missed beats. The existing
arcing motion, gentle stretch, target glow, and sparkle trail follow each flight's
own clock. Contact starts the liquid merge and its cue at the destination.
Completed words remain
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
