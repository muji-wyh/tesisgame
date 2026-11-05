# Jelly World assets and pricing release

## Result

Auto Merge and word goals share a 25, 50, then 75 coin unit price per net board space freed. Successful-use counters are separate; all word goals share their counter. The unit tier stops increasing after the third use. Owned Auto Merge capacity affects the operation's actual quantity without adding a flat level surcharge. A four-body operation producing one body costs 75, 150, then at most 225 coins.

The live Boss uses the exact optimized Pirate pack supplied from boss01, with its 22 authored clips, semantic mesh anchors, native elastic body and rigid hat. The archived Bramble source is excluded from the startup export.

Chest levels 1–28 use the selected chest01 Atelier materials. Levels 29–99 reuse Aether Vault while retaining their exact level and upgrade effects. Native Open clips and sourced Treasure/Magic contents use the caller's continuous clock. The former chest sprite artwork, original base resources and modular catalogs have been removed; source notices, shared effects and audio remain.

Repeated chest materials share a stable texture reference. Successful native capture releases the model and nested viewports. Headless or unreadable captures retain a paused renderer until a usable capture is available.

The header chest tap multiplies its scale displacement by three: the previous 1.72 peak becomes 3.16. Its 0.92-second lifecycle, input area and reduced-motion behavior are preserved. The fitted artwork and effects share one center inside the viewport. The Word Jelly HUD now invalidates once when tap feedback ends so the ordinary chest returns.

## Native verification

- Coin economy: 2,343 checks passed.
- Jelly model: 121,153 checks passed.
- Merge pricing cache: 476 checks passed.
- Auto Merge capacity/pricing: 836 checks passed.
- Pricing flow: 23 checks passed.
- Powerup application flow: 190 checks passed.
- Selected goal application flow: 182 checks passed.
- Insufficient-funds feedback: 13 checks passed.
- Preview cache and hints: 595 checks passed.
- Full-board drag performance regression: 49 checks passed.
- Chest tier models: 2,967 checks passed; progression: 301; consumers: 14; asset states: 1,546.
- Chest models: 125 checks passed; charge flow: 790; reveal: 2,390; feel: 1,259; upgrade levels: 732.
- Chest tap: 199 checks passed, including recovery, repeated input and reduced motion.
- Jelly view/cache: 3,148 headless and 3,149 native-renderer checks passed, including actual renderer disposal and shared Lv28–99 artwork.
- Pirate Boss presentation: 129 rendered checks passed; result taunt: 111 checks passed.

The native renderer used ANGLE with Microsoft Basic Render Driver. These results validate behavior and source rendering, not PC Chrome frame-rate claims.

## Visual and source checks

The actual native header tap was captured at its 3.16 peak in `build/qa/chest-tap/desktop-peak.png`. Sixteen actual state frames cover Lv1, Lv5, Lv28 and Lv99 in `build/qa/chest-states-release/`. Treasure and Magic renders differ from empty Open states; Lv28 and Lv99 preserve the same final material. The matched UI portraits use one camera and a union alpha crop and retain their source/output hashes in `assets/chests/shared/ui/manifest.json`.

Node checks passed for the 28 model hashes, 99-level mapping, source textures, continuous clips, state contracts, licenses, retained audio, source parsers, web export rules, Pirate geometry and clips, host storage, and complete test-runner registration.

The final live identity audit also corrected the stage-one result, Web help, Pirate integration status and public art credits. Capped-word help now matches the existing merge rejection without a mismatch penalty. The Web export, Pirate and archived Boss suites passed all 54 checks after those corrections.

## Web build and browser verification

The final Web build passed its native pack inventory, deferred vocabulary, required audio and professional-domain checks. The startup game pack is `game-22876eafb06045a6.pck.br`, with 98,583,268 decoded bytes and SHA-256 `22876eafb06045a6c5e6f36ef279c44b8bf5aef23b7d5f4629ecb436e63d8560`.

All nine selected desktop Chromium scenarios passed with mouse input and `hasTouch: false`: Pirate victory and saved progression; Giant Ram and timed repair; Big Bite and returned identity; Jelly charging and paid-save retry; independent Auto Merge charging and capacity recovery; Auto Merge preview, exact debit and 100 ms starts; selected-family hover and purchase; exact goal shortfall; and unaffordable powerup feedback without wallet or board changes. Actual browser captures were inspected for the Pirate, native specials, upgrade page and Auto Merge preview/results.

Eight scenarios passed in the initial release run. The selected-family scenario reached its normal full-board deadline during browser-driver input, with only 44 ms remaining before the click. Its quote and rectangle are now read while paused before immediately resuming and clicking. The targeted recheck passed; the runtime purchase rules are unchanged. Goal-price assertions also cover disabled goals with no legal pair and a zero quote.

Production verification compares the served HTML fingerprint and the complete decoded game pack against the successful build receipt. The local result is written to `build/qa/production-release.json`.
