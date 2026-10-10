# Jelly Match chest fragments

Each chest-marked jelly consumed by a successful merge awards one chest fragment
within the current round; merging two marked jellies awards two fragments, and
ordinary unmarked merges do not award fragments. Four fragments form the first
chest; every five additional fragments upgrade that same chest. The result
contains one final chest, with its earned tier, rather than the intermediate
chests. These tiers are separate from Pip's vocabulary mastery level.

## Motion reference

The user supplied `C:/uworks/841558b760f51a655715393be5238950.mp4` as an animation
reference. It is a 27.8-second, 1280 x 576, 30 fps recording. Its creator and
redistribution license were not supplied. No image or audio is extracted from
this video into the game.

The inspected chest upgrades around 1.3-1.9, 2.9-3.5 and 4.5-5.1 seconds use a
brief anticipation, lift and turn, a local light accent that reveals the new
chest, and a clear landing. Rank-up sequences around 16.2-18.0 and 23.8-26.0
seconds add rays followed by side fountains of confetti that spread and fall
across the screen. The still review samples the complete video at one frame per
second and the relevant sequences at five frames per second. These samples
establish visible beats; they do not constitute a normal-speed audio review.

The adaptation preserves the existing 0.65-second pickup flight. Synthesis
assembles four portions of the actual closed-chest artwork. Upgrade motion uses
the closed chest, a local glow, one material-change accent, and full-screen
paper confetti. Intermediate chests never run the final opening or saving
callbacks. Motion, sound and the chest-change accent share one performance
clock. The gameplay model owns fragment credit and tier changes; the visual
timeline does not grant rewards.

After the pickup reaches the HUD, the milestone performance lasts 2.15 seconds.
Its preparation and convergence lead to the chest reveal at 0.72 seconds; the
sound accent, upgraded art and confetti emission use this same reveal event.
The chest settles while the paper spreads across the viewport and falls away.
Synthesis uses the same reveal rhythm without the upgrade's full-screen burst.

## Chest art

The tier progression reuses the integrated designs in this order:

| Tier | Existing design | Source record |
| --- | --- | --- |
| 1 | Meadow Explorer (`bramble`, Jungle) | Acquired Ekrem C. chest, warm wood and green frame |
| 2 | Harvest Keepsake (`harvest`, Autumn) | Acquired Batata Studio chest, amber wood and gold trim |
| 3 | Lagoon Pearl (`tide`, Ocean) | Acquired Batata Studio chest, pearl frame and wing ornaments |
| 4 | Moonstone Vault (`nebula`, Space) | Acquired Bobardo chest, lilac enamel and a gemstone |
| 5 | Royal (`royal`, Spring) | Existing Modern 2D Animated Chests source artwork |
| 6 and higher | Crystal (`crystal`, Winter) | Existing layered Modern 2D Animated Chests artwork |

The numerical tier continues above six; the highest integrated chest design
remains in use. Every additional five fragments still produces an upgrade.
The first four sources, their Unity Asset Store Standard EULA, source and output
hashes, separate body/lid geometry, and available animation clips are documented
in [the chest replacement record](chest-refresh.md) and
`assets/chests/downloaded/manifest.json`. Royal and Crystal retain the source
record in `assets/chests/SOURCE.txt`, `assets/chests/manifest.json`, and
[round completion](round-celebration.md). The tier system does not introduce a
new acquisition or claim a new license for those existing assets.

## Confetti source and preparation

| Field | Evidence |
| --- | --- |
| Title / version | Toon FX 1.52 |
| Creator | Kenneth Foldal Moe (Archanor VFX), named in the acquired package README |
| Official source | [Toon FX, product 25601](https://assetstore.unity.com/packages/vfx/particles/toon-fx-25601) |
| License | [Standard Unity Asset Store EULA](https://unity.com/legal/as-terms), confirmed on the official listing on 2026-10-10; the listing identifies an Extension Asset |
| Acquisition | Pre-existing locally acquired source package at `C:/uworks/AssetsSource/Toon FX [1.52]`; no new purchase or listing-preview download |
| Selected source | `Textures/confetti2x2_smoothed.png`, 512 x 512 RGBA |
| Source / output SHA-256 | `14606c1eacc47550afdaddb920b8102363108d72a0ad02997366cd894bae4108` |
| Runtime input | `assets/images/jelly-match/confetti.png`, copied byte-for-byte; lossless Godot texture import |
| Source animation | Static 2 x 2 particle atlas; the package also contains Unity rain and explosion prefabs |
| Integrated animation | Game-authored screen-space trajectories, tint, rotation and paper flutter; Unity prefabs and scripts are not imported or executed |

The source sheet contains rounded square, star, circle and triangle silhouettes
in its four 256 x 256 regions. Its monochrome artwork is deliberately intended
for recoloring, as explained by the package README. The game uses the rounded
square region as paper. White source pixels retain
their alpha contours and receive palette colors at draw time.

The atlas was inspected over a dark background to reveal its transparent shape
edges, then compared with the non-smoothed original. The exact source remains a
private build input and ships only inside the compiled game pack, consistently
with the existing licensed Unity artwork policy. The local source, official
listing and previously retained extraction audit establish distinct acquisition,
inspection and integration states; a listing image is not used as game art.

To restore this private input from the acquired package, preserving its reviewed
hash and generating lossless Godot import settings:

```powershell
node tools/prepare-jelly-reward-art.cjs
npm run import
```

Pass the exact PNG path as the optional first argument when the acquired pack is
stored elsewhere. An unexpected hash or image format fails before changing the
runtime input. The original reviewed atlas is 17,134 bytes. The original Unity
material, particle prefabs and source README remain outside the repository.
The Web build checks the private atlas hash, exact size and lossless import
settings before starting Godot import. It does not restore or replace an asset
silently. The focused `jelly-reward-art` Node suite covers missing and altered
inputs, import-setting failures, exact copying and idempotent restoration.

The existing `assets/chests/particles/portal_glow.png` supplies the local light
accent under its recorded source rights. Existing chest cue recordings can be
reused without copying a new soundtrack from this motion reference; their
provenance and extraction limits remain in
[the chest audio record](chest-reference-audio.md).

## Lifecycle and review boundary

Queued milestone visuals must stay attached to their round and fragment event.
Menu/background pauses freeze their clocks. Leaving the mode or starting a new
round clears visual events and sound. A completed tier transition must not replay
or save another chest when resumed. Concurrent merges may queue several visual
milestones while the model retains their final tier exactly once. Reduced motion
keeps the same chest/tier outcome and readable text, with no lift, turn or falling
confetti.

Ignored source-review outputs are in `build/jelly-fragments-review/`. They are
local review artifacts, not public routes or shipped content. The source-frame
inspection and resource checks are separate from gameplay and sound review.

The final real-scene captures cover synthesis and upgrade at 1280 x 800, plus
project-scaled 390 x 844 portrait and 844 x 390 landscape. Frame review confirmed
sharp chest artwork, viewport-wide paper distribution, and separated, unclipped
title, chest and level labels. Normal-speed recordings include the runtime cue
track. Cue timestamps and audio peaks were checked; subjective timbre and
physical-device playback remain outside this review.

Focused native tests cover the four-then-five thresholds, concurrent merges,
menu pause/resume during pending fusions, exact presentation boundaries,
reentrant stop/new-round callbacks, reduced motion, final-tier persistence,
save retry and duplicate reward protection. The private confetti input also
passes read-only source, format, hash and import-setting validation.
