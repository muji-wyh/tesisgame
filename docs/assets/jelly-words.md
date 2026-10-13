# Jelly Words

Jelly Words reuses the acquired production assets from [Jelly Match](jelly-match.md),
the [Kenney layered garden](jelly-garden.md), and the
[chest-fragment presentation](jelly-fragments.md). No new artwork was downloaded.

| Material | Source, creator, license | Integration and animation |
| --- | --- | --- |
| Four gel skins and contact shadow | Zuhria Alfitra / pzUH, GameArt2D Jelly Squash Free Sprites, CC0 1.0; acquired and integrated previously | The actual mint skin was inspected before reuse. Existing painted contours and material maps stretch with the accumulated parts. The source is static; runtime contact, continuous union, growth, collection, and settling are authored by this game. |
| Word pictures and pronunciation | Existing current-age vocabulary packs; individual acquisition and license records remain in the vocabulary asset manifests | The normal WordArt loader supplies the exact dictionary picture only after a valid word is built. Existing animated word artwork remains supported. |
| Chest models, local light accents, paper confetti | Existing acquired chest and particle assets; creators and licenses recorded in the linked fragment record | The shared ChestCelebration and RewardConfetti timelines provide first-chest synthesis, upgrade rotation, enlargement, flash, and paper bursts. Reused as integrated assets, not source previews. |
| Contact, merge, and disappear audio | User-selected contact and merge WAVs; original creators greenlinker and rubberduck, CC0. Existing clear combines rubberduck and Aeva CC0 recordings; exact provenance in the Jelly Match records | Contact fires on first painted-body contact, merge on commitment, and the unchanged clear cue on collection release. No new recording or processing. |
| Rejected merge audio | Existing user-supplied wrong-answer excerpt; creator, acquisition status and unsupplied license terms are recorded in [pair feedback](pair-feedback-audio.md) | Reuses the integrated 860 ms `wrong.wav` at gain 0.48 once when a failed drop separates. No new extraction, processing or animation asset. |

The six-column board starts with eighteen settled chunks in three full bottom
rows. Letter chunks concatenate in drag-source then drop-target order. A merge
is accepted only when that exact spelling is in the selected learning-age
dictionary; reverse-only matches and incomplete prefixes are rejected.
Each supplied word has two complementary chunks at every age, so it can be
completed in one valid merge. Authored longer chunk sequences combine adjacent
parts at a balanced boundary. A completed word is collectible, and its picture
and warm gel rim indicate readiness without adding a
floating instruction label. Each original chunk adds mass and 50 coins; merging
preserves all fragment markers, while tapping the complete word collects them.
Long spellings fit their actual wrapped font lines so a two-part body keeps
every letter visible beside its picture.
The model owns the merge and collection clocks, wallet receipt, fragment count,
and chest tier. Visual callbacks never grant coins.

Two [coin powerups](jelly-powerups.md) share the board controls. Auto merge costs
1,500 coins and moves matching bodies into their targets one at a time, leaving
the completed words on the board for ordinary collection. Treasure costs 500
coins and delivers a random total of one to five carried fragments to the current
board, preferring bodies without fragments. Payment is persisted before either
ability starts. Supply and danger clocks wait while the ability runs; Home and
Finish confirmation pause it. Neither ability collects words, grants coins, or
credits learning progress by itself.

Automatic merges, splits, and restored growth check for support after the
fusion handover and settle vertically onto the nearest body or the floor.
Dragging into empty space snaps the entire jelly footprint to the nearest
grid position, preserving the original finger offset. A translucent
copy of the acquired gel skin previews the destination, with a mint rim for a
fitting space and a coral rim when blocked. Drops outside the well or without
enough space return to the previous position; painted-body contact still takes
priority for merging. After release, an unsupported jelly immediately falls
from the final pointer position onto the nearest supporting body or the floor.
The full footprint determines support, and the fall keeps the chosen column
and body size. Removing its support starts another fall; bodies above its
former position also settle. Moving preserves its word,
picture, mass, merge history, fragments, and reward receipt without paying coins.
Reduced motion keeps the same placement rules and static preview, placing
the body directly at its supported destination.

New six-root supply packets mix parts from different words, leaving intervening
roots between siblings whenever the packet permits it. The same arrangement
feeds the three opening rows. Word provenance, part order, and fragment markers
stay attached to each root; already visible previews are never reshuffled.
Neighboring bodies leave a nine-percent cell gap for clearer separation.

On pointer press, every settled target that completes a current-age word in
source-then-target order receives a warm local glow, a slow light sweep across
the acquired gel paint, and a gentle 3.5-5.5 percent breathing enlargement of
its skin. Keyboard source selection shows the same candidates. The cue reuses
the acquired `portal_glow.png` from Bobardo's Modern 2D Animated Chests, under
the Standard Unity Asset Store EULA documented in
[treasure assets](../voice-pop-treasure.md), with its source mapping in
`assets/chests/manifest.json`.
Both source textures are static; these cues are runtime animation. The portal's
authored wisps have lifted opacity and a wider falloff, layered above the contact
shadow and below the gel, so the breathing light remains visible against the pale
garden. A cream-lit contour connects the glow to the painted body. Two small
shoulder glints reuse the integrated Toon FX 1.52 sparkle by Kenneth Foldal Moe
(Archanor VFX), under the Standard Unity Asset Store EULA recorded in the
[fragment asset record](jelly-fragments.md); its source image is static, with
alternating soft twinkles authored at runtime. No new artwork
or audio was acquired. Lettering, pictures, fragment markers, hit areas and rewards
stay unchanged. Release, cancellation or leaving play clears the cue. Reduced
motion keeps static light, glints and the painted rim without a sweep or enlargement.
All completion feedback, including the contact highlight, uses the same forward
spelling: holding `sma` lights `ll` for `small`, while holding `ll` does not light
`sma`. Every other physical contact still compresses both painted skins and
adds a soft cream glint, with the existing contact sound on first touch. This
neutral pressure cue does not show a red error rim or a completion glow. Moving
apart or canceling clears it; reduced motion keeps the static glint. Releasing
an invalid pair returns the source to its supported position, with a short
elastic separation and a 340 ms rejection accent on both skins. The existing
wrong-answer sound starts once at that release; hovering or canceling does not
play it. Reduced motion uses the same outcome with a steady brief accent.
The next pickup, pause, round finish or navigation stops the previous sound tail.
Rejection preserves both bodies, carried fragments and rewards without recording
a learning attempt. Historical incomplete merged bodies can still be split.

Supply releases across alternating columns (1, 4, 2, 5, 3, 6), with 0.15 seconds
between starts. The bodies accelerate under the existing gravity and recover
after landing. Shared entry lanes retain extra clearance so a later root cannot
overtake an earlier one. Each preview slot refills after its own departing body
has cleared it. Reduced motion keeps the same readiness clocks while placing
bodies directly at their reserved destinations. The six-column board, initial
three rows, 20-to-16-second supply cadence, merge, split, and collection rules
remain unchanged. This polish reuses the integrated gel artwork and landing
audio above; it adds no downloaded assets.

The Collect button snapshots all completed word jellies currently on the board.
It collects them from the upper rows downward, alternating direction across
rows, with one pickup every 100 ms. Each batch collection finishes within that
same beat, keeping reward transactions sequential, with the existing pop sound
at 60 ms to match the squash and release. Each jelly squashes, lifts
with alternating sideways drift, and clears through the ordinary wallet and
fragment transaction. Historical incomplete combinations remain available for splitting.
Existing movement settles before the first pickup; queued words then keep their
places so gravity and deferred growth cannot delay the following beats.
The current batch finishes before another can begin; pause freezes its clock,
leaving the round cancels queued pickups, and a failed wallet save stops the
sequence with the uncollected words intact.

The button reuses the inspected mint gel skin above and the gold coin from
Kenneth Foldal Moe / Archanor VFX's acquired Toon FX 1.52 package, under the
Standard Unity Asset Store EULA; conversion and acquisition details remain in
`assets/coins/manifest.json`. The integrated portal glow, rays and sparkle
textures retain the licenses and source records in the linked chest-fragment
record. These are static source images; the growing coin stack, soft overshoot,
rotating rays and staggered glints are animated in the game. No new asset was
downloaded. Button strength follows the available word count and retains the
batch's initial charge until completion. Reduced motion preserves the count,
static material, stack and light accents without rocking, growth overshoot or
twinkling. Earned chest celebrations queue until the collection rhythm finishes;
their existing flight, upgrade and confetti then play through the shared system.
Focus uses the gel skin's own mint-and-cream contour highlight, replacing the
dark rectangle around its hit target. It remains distinct from the golden charge
rim at high counts, stays steady with reduced motion, and clears when disabled.
Keyboard navigation, activation and touch bounds remain unchanged.

The existing collection pop marks each pickup. Each collected word now owns an
independent picture-and-spelling burst: new words coexist with older ones instead
of replacing them. A separate presentation RNG varies size and position across
the upper playfield, scores overlap against active words, and avoids the chest.
The card measures its actual spelling and picture before fitting its bounds; it
reserves space for the elastic stretch, compression and settling motion. Batch
bursts last 480–860 ms according to the available screen space, with a short
fading tail so dense small-screen collections remain legible. Individual taps retain their
1.95-second reading beat. Pauses and exits clear every entry; reduced motion uses
steady cards with the same content and lifetimes. The vocabulary artwork and
the acquired Bobardo portal glow and Archanor sparkle above are reused, with no
new asset downloads. Batch collection remains silent for pronunciation,
including the final pickup; individual word taps retain their pronunciation.
