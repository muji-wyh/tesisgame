# Jelly Words

Jelly Words reuses the acquired production assets from [Jelly Match](jelly-match.md),
the [Kenney daylight panorama](jelly-sky.md), the
[Kenney garden edges](jelly-garden.md), and the
[chest-fragment presentation](jelly-fragments.md). Their source, acquisition,
and license records remain in the linked asset documents.

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
floating instruction label. Each collected word has an independent 1% chance
of bonus coins, worth 50 coins for two chunks or 100 for three or more. Opening chests
is the main source of coins. A collection without bonus coins still records
the learned word and collects all carried chest fragments, without a coin
flight or coin sound. The roll is retained across collection retries and uses
a separate random stream from word supply and powerups. Merging preserves all
fragment markers, while tapping the complete word collects them.
Carried fragments use a compact lower-right stack of at most two current-tier
chest icons. One or two fragments remain directly countable; larger stacks show
their exact total in a small cream count capsule. The group fits inside the
jelly with a separate space below the spelling, so repeat Treasure purchases
cannot create a row of icons across neighboring bodies. A brief, local receive
pop follows the existing fragment-arrival clock; reduced motion keeps it still.
This reuses the acquired chest texture and its existing source/license records
in [Jelly fragments](jelly-fragments.md) and [chest replacement](chest-refresh.md).
The chest is a static cropped render here, with runtime scale animation; no new
artwork or audio is acquired. The count capsule is an interface layout primitive.
Long spellings fit their actual wrapped font lines so a two-part body keeps
every letter visible beside its picture.
The model owns the merge and collection clocks, wallet receipt, fragment count,
and chest tier. Visual callbacks never grant coins.

Each valid manual drop requests its word pronunciation immediately when the
merge is accepted, alongside the fusion animation. This removes the previous
760 ms wait for the animation to finish, using the unchanged
[Ava Sweet recordings](ava-voice.md). Animation completion never repeats the cue. Rapid manual
completions queue their words in order so each recording can finish. Auto Merge
keeps the fusion sound effects without pronouncing or queuing its completed words.
Contact, rejected drops, and moving a completed word do not start pronunciation.
Collect cancels pending merge speech and retains its sound-effect rhythm;
direct word taps still pronounce the selected word. Leaving play or muting
clears queued speech without replaying it on return.

Two [coin powerups](jelly-powerups.md) share the board controls. Auto merge costs
600 coins initially, then 900 and 1200 on further uses in the round. It launches
a random eligible Jelly every 200 ms, dragging it into
its matching target over 300 ms. Consecutive flights briefly overlap, leaving
the completed words on the board for ordinary collection. Treasure costs 200,
300, then 400 coins per round and delivers a random total of two to eight carried fragments to the current
board, preferring bodies without fragments. Payment is persisted before either
ability starts. Treasure can be purchased again during delivery, with each paid
batch starting its own flights immediately on the shared animation timeline.
The two prices advance independently after successful payment;
failed or duplicate payments do not advance them. Supply and danger clocks wait while the ability runs; Home and
the Finish pull gesture pause it. Neither ability collects words, grants coins, or
credits learning progress by itself.

Automatic merges and restored growth check for support after the
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
picture, mass, fragments, and reward receipt without paying coins.
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
garden. The wider amber halo keeps a bright baseline between pulses; a stronger
cream-lit contour and surface sweep connect it to the painted body. Two larger
shoulder glints reuse the integrated Toon FX 1.52 sparkle by Kenneth Foldal Moe
(Archanor VFX), under the Standard Unity Asset Store EULA recorded in the
[fragment asset record](jelly-fragments.md); its source image is static, with
alternating soft twinkles authored at runtime. No new artwork
or audio was acquired. Lettering, pictures, fragment markers, hit areas and rewards
stay unchanged. Release, cancellation or leaving play clears the cue. Reduced
motion keeps static light, glints and the painted rim without a sweep or enlargement.
All completion feedback, including the contact highlight, uses the same forward
spelling: holding `sma` lights `ll` for `small`, while holding `ll` does not light
`sma`. Incompatible targets keep their resting paint, including reverse partners
that share an idle pair color: holding `t` never recolors or lights `ca`, while
holding `ca` lights `t` for `cat`. Every other physical contact still compresses
both painted skins and adds a soft cream glint, with the existing contact sound on first touch. This
neutral pressure cue does not show a red error rim or a completion glow. Moving
apart or canceling clears it; reduced motion keeps the static glint. Releasing
an invalid pair returns the source to its supported position, with a short
elastic separation and a 340 ms rejection accent on both skins. The existing
wrong-answer sound starts once at that release; hovering or canceling does not
play it. Reduced motion uses the same outcome with a steady brief accent.
The next pickup, pause, round finish or navigation stops the previous sound tail.
Rejection preserves both bodies, carried fragments and rewards without recording
a learning attempt.

Supply releases across alternating columns (1, 4, 2, 5, 3, 6), with 0.15 seconds
between starts. The bodies accelerate under the existing gravity and recover
after landing. Shared entry lanes retain extra clearance so a later root cannot
overtake an earlier one. Each preview slot refills after its own departing body
has cleared it. Reduced motion keeps the same readiness clocks while placing
bodies directly at their reserved destinations. The six-column board, initial
three rows, merge, and collection rules remain unchanged. Automatic supply starts
with a twenty-second interval. Every four successful completed-word collections reduce
the next cycle's interval by two seconds, down to ten seconds after twenty
collections. Tap and Collect pickups count equally; idle time, merge-only play,
Auto Merge, and failed collections do not increase difficulty. Each successful
packet dispatch, automatic or manual, fixes the interval for the following
cycle. Collections never shorten the current Next countdown, and rejected
dispatches leave it intact. New rounds restore the twenty-second opening
interval; the existing danger grace period remains independent. This polish
reuses the integrated gel artwork and landing
audio above; it adds no downloaded assets.

The committed six-root preview is mixed before it is shown. Each slot releases
straight into its corresponding board column, including above uneven stacks.
A sealed entry keeps its root in the same preview slot until that column opens.
Each dispatch releases at most one root per open column and refills only those
departing slots; blocked roots keep their IDs, letters, and carried fragments.
Repeated dispatches preserve safe arrival spacing within each column. A timed
partial release also cancels a held tray press, preventing pointer-up from
releasing the replacements a second time.
The cloud environment and recessed rim are documented in [Jelly Words well](jelly-well.md).

The Collect button snapshots all completed word jellies currently on the board.
It collects them from the upper rows downward, alternating direction across
rows, with one pickup every 120 ms. Each batch collection finishes within that
same beat, keeping reward transactions sequential, with the existing pop sound
at 60 ms to match the squash and release. Each jelly squashes, lifts
with alternating sideways drift, and clears through the ordinary wallet and
fragment transaction. Unmatched roots remain on the board.
Existing movement settles before the first pickup; queued words then keep their
places so gravity and deferred growth cannot delay the following beats.
The current batch finishes before another can begin; pause freezes its clock,
leaving the round cancels queued pickups, and a failed wallet save stops the
sequence with the uncollected words intact.

The Collect button uses a horizontal mint capsule with a soft lower lip. A larger
completed-word jelly illustration sits on the left; the Collect title and an
inline word count sit together on the right. The count reads "1 word" or
"N words" while ready and "N left" during collection, without a separate badge.
The empty state retains its illustration and readable "0 words" count.
The surface is an interface layout primitive. The inspected mint, sky and lilac
gel skins above form an accumulating fan of completed-word jellies. Its front
picture reuses the integrated Microsoft
Fluent Emoji 3D cat (MIT), already shipped in the core interface; exact source,
creator and acquisition records remain in the
[Home illustration attribution](../../assets/images/ui/modes/ATTRIBUTION.md).
Collection primarily clears words and gathers their fragments, while bonus
coins remain rare; the button uses the word illustration rather than coin art.

Collect sits directly above Auto merge with the same width and horizontal
alignment. A visible rule centered in a twenty-pixel gap separates free
collection from the two coin-priced tools. This rule is a decorative interface
primitive and does not receive input. Side layouts keep this action group at
the bottom of the right rail, with Treasure eight pixels below Auto merge.
Other layouts place Collect above the left purchase control below the well;
the divider spans both purchase controls in their shared bottom row.

The well and side rail are centered together, with a twelve-pixel gap between
them. The rail ranges from 88 to 144 display pixels wide so small screens
retain room for readable word jellies. Controls are 56 display pixels high;
Collect can shrink to 44 pixels on very short screens to preserve the gap.
The layout preserves space below the header and twelve-pixel bottom padding.
Collection reveals avoid the chest and Collect artwork.

The integrated portal glow, rays and sparkle textures retain the licenses and
source records in the linked chest-fragment record. These are static acquired
images; the unfurling jelly fan, surface overshoot, rotating local rays and
staggered glints are runtime animation. No new asset was downloaded. Button
strength follows the available word count and retains the batch's initial
charge until completion. Each pickup compresses and lifts the illustration on
the existing collection beat. The label, count placement and touch area remain
steady. Light stays around the illustration, clear of the title and count.
Reduced motion preserves the count, layered artwork and static light accents
without rocking, growth overshoot or twinkling. A rounded teal focus contour
follows the capsule without a dark rectangular outline and clears when disabled.
Keyboard navigation, activation, collection cadence and rewards remain unchanged;
each layout keeps stable touch bounds as the available count changes. Earned
chest celebrations still queue until collection ends.

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
