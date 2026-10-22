# Jelly Words

Jelly Words reuses the acquired production assets from [Jelly Match](jelly-match.md),
the [Kenney daylight panorama](jelly-sky.md), the
[Kenney garden edges](jelly-garden.md), and the
[chest-fragment presentation](jelly-fragments.md). Their source, acquisition,
and license records remain in the linked asset documents.

| Material | Source, creator, license | Integration and animation |
| --- | --- | --- |
| Four gel skins and contact shadow | Zuhria Alfitra / pzUH, GameArt2D Jelly Squash Free Sprites, CC0 1.0; acquired and integrated previously | The actual mint skin was inspected before reuse. The rounded-square painted contours and material maps keep the ordinary Jelly size through every composition stage. The source is static; runtime contact, continuous union, collection, and settling are authored by this game. |
| Word pictures and pronunciation | Existing current-age vocabulary packs; individual acquisition and license records remain in the vocabulary asset manifests | The normal WordArt loader supplies picture-only source jellies and the picture above merged words. Roots have no picture. Existing animated artwork remains supported. |
| Chest models, local light accents, paper confetti | Existing acquired chest and particle assets; creators and licenses recorded in the linked fragment record | The shared ChestCelebration and RewardConfetti timelines provide first-chest synthesis, upgrade rotation, enlargement, flash, and paper bursts. Reused as integrated assets, not source previews. |
| Contact, merge, and disappear audio | User-selected contact and merge WAVs; original creators greenlinker and rubberduck, CC0. The approved fixed bubble pop and acquired Kenney CC0 layers provide level cues; exact provenance is in [Jelly level feedback](jelly-level-feedback.md) | Contact fires on the first eligible approach or painted-body touch, merge on commitment, and the level-specific cue on collection release. Lv1 keeps the approved bubble pop. |
| Rejected merge audio | Existing user-supplied wrong-answer excerpt; creator, acquisition status and unsupplied license terms are recorded in [pair feedback](pair-feedback-audio.md) | Reuses the integrated 860 ms `wrong.wav` at gain 0.48 once when a failed drop separates. No new extraction, processing or animation asset. |

The board has five columns and eight rows, holding 40 cells and opening with at
most 15 jellies across three rows. Every jelly keeps a 1:1 square aspect ratio.
Reviewed entries use meaningful roots and exact authored spelling transformations.
Root labels use positional hyphens, such as `un-`, `-believe-`, and `-able`.
An atomic word such as `cat` supplies a whole-word root plus a separate cat picture.
Picture jellies show only their artwork. After roots form a complete word, join
it with its matching picture to create a Lv1 merged jelly. A word without a
picture becomes merged as soon as its spelling is complete. Unreviewed fallback
content stays whole; it is never cut into arbitrary letter groups. See the
[morphology contract](../vocabulary/morphology-contract.md) for editorial rules.

Merged jellies show the full word, its available picture, a warm rim, and sourced
light accents. Two merged jellies with the same vocabulary identity and level
combine into the next level, up to Lv9. Lv2–9 show their number at the upper-right;
carried chest fragments use the opposite corner. All stages retain one ordinary
cell. Joining, picture matching, and upgrading do not collect rewards or learning
credit. Collection owns the existing reward transaction and eligible manual
learning evidence; an upgrade does not multiply mastery or coin payouts.
Manual collection requires a click or tap released in under 500 ms on the same
merged jelly without dragging. Holding for 500 ms or longer never collects on
release; the held jelly can still be dragged into another matching merged jelly.

Each level has distinct collection motion and audio. Lv4 is a radial firework
bloom; higher levels add layered blooms, comet trails, or a bouquet finale.
The effect begins at the model's collection pop, remains input-transparent, and
clears on pause or exit. Reduced motion uses a compact still light accent.
Profiles and acquired material are recorded in [Jelly level feedback](jelly-level-feedback.md).

Lv1 collections do not award bonus coins. Lv2 through Lv9 use independent collection
chances of 2%, 4%, 6%, 10%, 16%, 28%, 50%, and 80%, with respective payouts of
50, 100, 150, 200, 250, 300, 350, and 450 coins. Both probability and amount increase
with merge level, independently of component count and footprint. Opening chests
is the main source of coins. A collection without bonus coins still records
the learned word and collects all carried chest fragments, without a coin
flight or coin sound. The roll is retained across collection retries and uses
a separate random stream from word supply and powerups. Merging preserves all
fragment markers, while tapping the complete word collects them.
Carried fragments use a compact upper-left stack of at most two current-tier
chest icons. One or two fragments remain directly countable; larger stacks show
their exact total in a small cream count capsule. The group fits inside the
jelly with a separate space above the spelling, so repeat Treasure purchases
cannot create a row of icons across neighboring bodies. A brief, local receive
pop follows the existing fragment-arrival clock; reduced motion keeps it still.
This reuses the acquired chest texture and its existing source/license records
in [Jelly fragments](jelly-fragments.md) and [chest replacement](chest-refresh.md).
The chest is a static cropped render here, with runtime scale animation; no new
artwork or audio is acquired. The count capsule is an interface layout primitive.
All source parts, intermediate compositions, atomic words, completed words, and
previews use one ordinary square cell. The five-column, eight-row well uses a
responsive cell pitch; neither spelling length nor accumulated parts
enlarge a body. This is the former ordinary Jelly display size, not a fixed
32-pixel rendering size. Labels fit the available square at a minimum of 13
displayed pixels and wrap only at approved boundaries. Overflow uses an ellipsis
while preserving the full spelling in accessibility text and the Read detail.
Hold an overflowed Jelly still for 450 ms, or focus it and press R, to pause and read. Moving
more than seven displayed pixels cancels the hold; quick taps still collect
completed words. The Read detail also works for supply previews without dropping
them. Resizing never changes logical footprints.
The model owns the merge and collection clocks, wallet receipt, fragment count,
and chest tier. Visual callbacks never grant coins.

Each manual drop completing a whole word requests its pronunciation immediately when the
merge is accepted, alongside the fusion animation. This removes the previous
760 ms wait for the animation to finish, using the unchanged
[Ava Sweet recordings](ava-voice.md). Animation completion never repeats the cue. Rapid manual
completions immediately replace earlier speech, keeping pronunciation aligned
with the accepted merge. Auto Merge
keeps the fusion sound effects without pronouncing or queuing its completed words.
Contact, rejected drops, and moving a completed word do not start pronunciation.
Collect cancels pending merge speech and retains its sound-effect rhythm;
direct word taps still pronounce the selected word. Leaving play or muting
clears speech without replaying it on return. Picture-only jellies and complete
spellings awaiting a picture also pronounce their word when tapped; partial
roots remain silent.

Two [coin powerups](jelly-powerups.md) share the board controls. Auto merge costs
600 coins initially, then 900 and 1200 on further uses in the round. It joins
compatible roots, finishes picture matching, or upgrades equal-level words.
It leaves merged jellies on the board for ordinary collection. The planner checks
an entire completion path and all intermediate rectangles before charging.
Eligible pairs launch every 200 ms, each with a 250 ms flight, 110 ms fusion,
and 30 ms settlement. Flights overlap; only steps that need an earlier result
wait for that result to settle. Partial-only paths cannot buy the tool.
Its assisted result remains collectable without creating mastery evidence.
Treasure costs 200,
300, then 400 coins per round and delivers a random total of two to eight carried fragments to the current
board, preferring bodies without fragments. Payment is persisted before either
ability starts. Treasure can be purchased again during delivery, with each paid
batch starting its own flights immediately on the shared animation timeline.
The two prices advance independently after successful payment;
failed or duplicate payments do not advance them. Supply and danger clocks wait while the ability runs; Home and
the Finish pull gesture pause it. Neither ability collects words, grants coins, or
credits learning progress by itself.

Automatic merges keep the board positions fixed while their reserved paths run.
After the operation finishes, unsupported jellies settle vertically onto the
nearest body or the floor.
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

A manual pair remains draggable during its fusion. Picking either visible lobe
moves the whole joining pair while the existing merge clock continues. When the
clock finishes, its single result inherits the same pointer and finger offset.
Releasing earlier completes that already accepted pair once, then uses the
ordinary placement or merge rules for the resulting body. Canceling movement
returns the animation to its reserved slot. Pressing a fusion never collects it.

While held, the reserved result supplies word-family guidance and merge
eligibility before the fusion finishes. Contact follows both painted joining
lobes, then the resulting body. Matching partners receive the same expanded
approach margin as ordinary drags; other bodies respond only at painted contact.
The existing gel materials receive the same directional pressure and contact
rim on both sides. Completing the fusion retains the pointer, target and single
contact cue without committing a second merge until release.
Automatic powerup playback retains its existing exclusive input ownership.

Valid drag targets offer merge contact within 6 percent of a tile's shorter side,
capped at 4 screen pixels beyond the painted source contour, including corners.
The closest eligible match in that margin takes priority over unrelated touching
neighbors. Without a nearby match, nonmatching bodies retain the original
silhouette-overlap threshold and closest-contact selection.
The same selected target is used for the release, so the early cue is actionable.
Matching surfaces lean slightly toward each other instead of recoiling apart;
ordinary tiles and active fusion lobes use the same attraction. Contact feedback
does not move its own detection contour, preventing flicker while held still.

New five-part supply packets mix parts from different words, leaving intervening
pieces between siblings whenever the packet permits it. Word provenance, part
order, and fragment markers stay attached to each piece, including targets that
span packet boundaries; already visible previews are never reshuffled.
Neighboring bodies leave a nine-percent cell gap for clearer separation.

On pointer press, every settled target that legally composes with the selected part in
source-then-target order receives a violet local glow, a slow light sweep across
the acquired gel paint, and a gentle 3.5-5.5 percent breathing enlargement of
its skin. Keyboard source selection shows the same candidates. The cue reuses
the acquired `portal_glow.png` from Bobardo's Modern 2D Animated Chests, under
the Standard Unity Asset Store EULA documented in
[treasure assets](../voice-pop-treasure.md), with its source mapping in
`assets/chests/manifest.json`.
Both source textures are static; these cues are runtime animation. The portal's
authored wisps have lifted opacity and a wider falloff, layered above the contact
shadow and below the gel, so the breathing light remains visible against the pale
garden. The violet halo keeps a bright baseline from the first selected frame; a
wide violet contour with a cream keyline separates it from ordinary merged-word
readiness. Two larger gold
shoulder glints reuse the integrated Toon FX 1.52 sparkle by Kenneth Foldal Moe
(Archanor VFX), under the Standard Unity Asset Store EULA recorded in the
[fragment asset record](jelly-fragments.md); its source image is static, with
alternating soft twinkles authored at runtime. No new artwork
or audio was acquired. Lettering, pictures, fragment markers, hit areas and rewards
stay unchanged. Release, cancellation or leaving play clears the cue. Reduced
motion keeps static light, glints and the painted rim without a sweep or enlargement.
Selected merged words also highlight every settled merged word with the same
word ID, including different levels and Lv9. This word-family cue does not change
upgrade eligibility: only equal levels below Lv9 can merge.
Actual merge contact uses the same resolver as manual merging and Auto merge. Reviewed partial joins are valid; results that
lack room do not light up or incur an incorrect-answer penalty. Root joins follow
the reviewed reading order. Word-picture matching and equal-level upgrades work
in either drag direction. Incompatible targets keep their resting paint.
Every other physical contact still compresses
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

Supply releases across alternating columns (1, 4, 2, 5, 3), with 0.15 seconds
between starts. The bodies accelerate under the existing gravity and recover
after landing. Shared entry lanes retain extra clearance so a later piece cannot
overtake an earlier one. Each preview slot refills after its own departing body
has cleared it. Reduced motion keeps the same readiness clocks while placing
bodies directly at their reserved destinations. Automatic supply starts
with a twenty-second baseline interval. Every four successful completed-word collections reduce
the next cycle's interval by two seconds, down to ten seconds after twenty
collections. Tap and Collect pickups count equally; idle time, merge-only play,
Auto Merge, and failed collections do not increase difficulty. Each successful
packet dispatch, automatic or manual, fixes the interval for the following
cycle. Collections never shorten the current Next countdown, and rejected
dispatches leave it intact. New rounds restore the twenty-second opening
baseline interval. Reviewed rounds multiply that baseline by
`max(1, preview occupied area / 5)` for the next wave; atomic collections count
once, while partial merges never count. The existing danger grace period remains independent. This polish
reuses the integrated gel artwork and landing
audio above; it adds no downloaded assets.

The committed preview has five lanes, with each jelly using one square slot.
Unused lanes remain empty. The next FIFO card waits for a contiguous
span without rearranging cards. Each card enters through its advertised columns
only when its full rectangle fits; a sealed entry keeps its identity, exact text,
and fragments in the same preview span. A dispatch launches only cards already
advertised at its start, even when their departures immediately refill lanes.
Repeated dispatches preserve safe arrival spacing within each column. A timed
partial release also cancels a held tray press, preventing pointer-up from
releasing the replacements a second time.
The cloud environment and recessed rim are documented in [Jelly Words well](jelly-well.md).

The Collect button snapshots all completed word jellies currently on the board.
It collects them from the upper rows downward, alternating direction across
rows, with one pickup every 200 ms. Each batch collection finishes within that
same beat, keeping reward transactions sequential, with the existing pop sound
at 60 ms to match the squash and release. Each jelly squashes, lifts
with alternating sideways drift, and clears through the ordinary wallet and
fragment transaction. Unmatched parts remain on the board.
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

Collection uses the merged jelly's level-specific cue, with the fixed bubble pop
at Lv1. The former seven-note cycle remains historical asset material only.
Each collected word now owns an
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

Stage progress occupies its own compact row above the supply tray, or a two-line
badge in the action rail on short landscape screens. Each stage
holds ten unmastered targets, or the remaining eligible words when fewer are
available. A saved mastery removes future root and picture supply for that word,
including advertised previews, without deleting existing board bodies or their
rewards. Stage changes preserve the round and reward receipts. The 1.8-second
arrival banner uses a small elastic entrance, acquired portal light and six
acquired sparkle accents around a cream text card; it never receives input.
Reduced motion keeps a steady card with fades. Pause and exit dismiss the banner.
The portal texture is by Bobardo under the Standard Unity Asset Store EULA;
the sparkle is by Kenneth Foldal Moe / Archanor VFX under the same license,
with acquisition records in [Jelly fragments](jelly-fragments.md). Both inspected
textures were already integrated static artwork; their banner motion is authored
at runtime. The stage cue reuses the integrated chest-reference reward recording
documented there. No additional assets were downloaded.
