# Jelly Words

Jelly Words reuses the acquired production assets from [Jelly Match](jelly-match.md),
the [Kenney daylight panorama](jelly-sky.md), the
[Kenney garden edges](jelly-garden.md), and the
[chest-fragment presentation](jelly-fragments.md). Their source, acquisition,
and license records remain in the linked asset documents.

## Continuous chapter journey

The existing eleven scenic chapters are nine-stage sections on one continuous
upward route, not pages.
Their acquired sky, hills, trees, cottage, snow, palms, cactus, mountains and
castle remain unchanged. All 99 native stage bodies share the same world
coordinates and scroll surface, so neighboring chapters can appear together.
Each chapter's cream title landmark and real stage range sit inside the route,
between its first stage and the preceding chapter. The fixed page strip and its
previous/next controls are removed. Entry scrolls to the earned frontier;
browsing and wallet/status refreshes cannot alter saved unlocks, stars or recipes,
or pull the viewport away from its actual position.

The map props are existing Kenney **Background Elements Remastered 1.0** PNGs,
acquired from the user's local collection under **CC0-1.0**. Exact source and
runtime hashes, original paths and the retained license are in
[`assets/images/jelly-campaign/sources.json`](../../assets/images/jelly-campaign/sources.json).
Stage medallions remain the acquired Kenney **UI Pack - Adventure 1.1** artwork,
also CC0-1.0, with their
[unchanged source record](../../assets/images/ui/jelly-map/sources.json).
The existing Paweł Kuna / Tabler **MIT** Home artwork retains its path and
[control-source provenance](../../assets/images/ui/controls/sources.json).
The map header groups Home, the journey title and its next-Boss hint together.
Saved coins, upgrades and Challenge share one aligned desktop row; phones keep
the title and wallet above two full-height actions. The upgrade entry uses a
single mint surface around the existing gel and level text, without nesting the
standalone in-game level badge's frame. The compact wallet reuses the acquired
[Toon FX gold coin](coins.md), and Challenge retains the acquired Microsoft
[Fluent medal](vocabulary-mastery.md). These are static, integrated assets;
no new artwork, purchase or source animation is introduced.
These are integrated static source assets, not new acquisitions, animations,
generated scenery or marketplace previews. The cream chapter cards are interface
layout primitives. The actual pre-change map and corresponding source medallion,
pine and cottage PNGs were inspected before this presentation change.

Normal unlock motion keeps its 850 ms route and 650 ms padlock release, including
the real connecting path from one chapter's final stage to the next chapter.
Pause, hidden/background state and reduced motion retain the existing lifecycle.
The final Boss portrait preserves its acquired aspect ratio and uses a compact
size in a short landscape viewport so its actual Stage 99 action stays reachable.

The map's presentation takes its emotional anchor from the integrated storybook
[Pip artwork and six-part choreography](pip-growth.md), not a newly acquired
character. Pip rests on the actual next medallion's upper rim, using the saved
growth age or requested career wardrobe. The existing torso layer sits behind
the medallion while folded wings and the sleepy head sit in front; individual
parts rotate around their real joints without flattening the character. The
map-only controller in `scripts/word_jelly_map_pip.gd` adds quiet breathing and
blinks, and raises the head on real stage hover or focus without delaying entry.
It does not change the header's age-specific gestures or add a shared action.
This reuses original project artwork under the repository
ISC declaration; the original illustrator is still unrecorded and no separate
illustrator license is claimed. Baby and age-three atlas poses were inspected
alongside the actual phone map before integration. The actual baby part and
expression-head atlases were inspected again before this supported pose.
These remain static source layers with game-authored motion, not newly acquired
artwork or source animation clips. Pip and its foreground layer are decorative
and cannot intercept a stage tap or enter keyboard navigation. At the current
Boss node, the existing portrait uses the free flank so it does not occupy Pip's
perch; the final portrait retains its distinct purple frame and sourced aspect.

Completed route edges have a warm gold center; an unearned road stays cream.
Only the actual frontier gets the larger acquired medallion, mint Play tray,
local portal glow and a restrained sourced glint. These light textures are the
already integrated Modern2DChests portal and Archanor Toon FX sparkle recorded in
[Jelly fragments](jelly-fragments.md), under their existing Unity Asset Store
licenses, not new purchases or source previews. A hover lifts the medallion over
140 ms, while its owned pointer press seats it immediately. Neither response
moves the native stage target or changes ratings and progress. Existing click
audio remains unchanged. Tree and foliage PNGs sway gently around their base;
cottages, cactus, mountains and castles remain rigid. These are game-authored
transforms of static scenery, not supplied animation clips. Reduced motion keeps
the current-stage hierarchy and Pip still; hidden, offscreen and inactive guides
stop their idle clock, and a canceled scroll contact clears its press response.

## Board presentation

The existing warning light has a wider exterior corona: it grows from 20 to
112 display pixels over the unchanged rescue clock, with 128 pixels of canvas
padding and a softer outward falloff. The fine traveling rim, interior spill,
color progression, beat and reduced-motion policy are unchanged. The acquired
portal-glow and sparkle textures retain their existing rights and integration;
no new artwork, timer, full-screen tint or input layer is added.

The Ready/Go flourish, coin-upgrade ability previews and completed-goal
retirement reuse these integrated gel skins, actual vocabulary pictures and
the same sourced portal/ray/sparkle textures. The upgrade scene samples the real
campaign collection selector on a complete seven-column, eight-row board,
including all 55 other bodies for Lv9. The illustration never collects, pays,
or records learning. Completion uses the existing sourced
Tabler check mark (Paweł Kuna, MIT); its source SVG paths stay unchanged.
A game-authored mask progressively reveals the tick inside the source circle,
followed by a silent three-active-second hold and 380 ms exit. There is no Done
label, visible timer or completion count. The round-clear medal reuses Microsoft Fluent Emoji's acquired MIT
mastery medal, whose original provenance remains in [Vocabulary mastery](vocabulary-mastery.md).
The full two-edge paper fountain reuses the acquired Archanor Toon FX paper
texture described in [Jelly fragments](jelly-fragments.md); no new artwork is
claimed or acquired for these revisions.

| Material | Source, creator, license | Integration and animation |
| --- | --- | --- |
| Four gel skins and contact shadow | Zuhria Alfitra / pzUH, GameArt2D Jelly Squash Free Sprites, CC0 1.0; acquired and integrated previously | The actual mint skin was inspected before reuse. The rounded-square painted contours and material maps keep the ordinary Jelly size through every composition stage. The source is static; runtime contact, continuous union, collection, and settling are authored by this game. |
| Word pictures and pronunciation | Existing current-age vocabulary packs; individual acquisition and license records remain in the vocabulary asset manifests | The normal WordArt loader supplies picture-only source jellies and the picture above merged words. Roots have no picture. Existing animated artwork remains supported. |
| Chest models, local light accents, paper confetti | Existing acquired chest and particle assets; creators and licenses recorded in the linked fragment record | The shared ChestCelebration and RewardConfetti timelines provide first-chest synthesis, upgrade rotation, enlargement, flash, and paper bursts. Reused as integrated assets, not source previews. |
| Contact, merge, and disappear audio | User-selected contact and merge WAVs; original creators greenlinker and rubberduck, CC0. The approved fixed bubble pop and acquired Kenney CC0 layers provide level cues; exact provenance is in [Jelly level feedback](jelly-level-feedback.md) | Contact fires on the first eligible approach or painted-body touch, merge on commitment, and the level-specific cue on collection release. Lv1 keeps the approved bubble pop. |
| Rejected merge audio | Existing user-supplied wrong-answer excerpt; creator, acquisition status and unsupplied license terms are recorded in [pair feedback](pair-feedback-audio.md) | Reuses the integrated 860 ms `wrong.wav` at gain 0.48 once when a failed drop separates. No new extraction, processing or animation asset. |
| Upgrade and first-clear example picture | Microsoft Corporation, Fluent Emoji 3D Cat, MIT; the byte-identical acquired `assets/images/ui/modes/cat.webp` copy and upstream revision are recorded in [mode artwork](../../assets/images/ui/modes/ATTRIBUTION.md) | Reused integrated startup artwork, not a source preview or new download. The source is static; target illumination and Jelly material motion are game-authored. |
| Saved-coin and upgrade price artwork | Kenneth Foldal Moe / Archanor VFX, acquired Toon FX 1.52, recorded Standard Unity Asset Store EULA; see [gold coin artwork](coins.md) | Reuses `assets/coins/gold-coin.png` with its existing acquisition, source/output hashes and license. No new art or animation clips are acquired. |
| Auto merge upgrade wand | Kenney, Cursor Pack 1.1, `Vector/Basic/tool_wand.svg`, CC0 1.0; original local acquisition and license are recorded in [Jelly powerups](jelly-powerups.md) | Reuses the inspected, integrated `assets/images/ui/jelly-powerups/auto-merge-wand.svg`. The source is static; its charge response is authored by the game. |
| Upgrade milestone light and audio | Bobardo's acquired Modern 2D Animated Chests portal glow and Kenneth Foldal Moe / Archanor VFX's acquired Toon FX rays/glints, under their recorded Unity Asset Store licenses; Kenney CC0 coin handling and `confirmation_002` audio | Reuses the integrated textures and recordings documented in [Jelly fragments](jelly-fragments.md) and [upgrade charging](coins.md#jelly-upgrade-charging). Effects and sound follow saved contributions and level transitions; no new asset acquisition or source animation is claimed. |

The board has seven columns and eight rows, holding 56 cells and opening with at
most 21 jellies across three rows. Every jelly keeps a 1:1 square aspect ratio.
Reviewed entries use meaningful roots and exact authored spelling transformations.
Root labels use positional hyphens, such as `un-`, `-believe-`, and `-able`.
An atomic word such as `cat` supplies a whole-word root plus a separate cat picture.
Picture jellies show only their artwork. After roots form a complete word, join
it with its matching picture to create a Lv1 merged jelly. A word without a
picture becomes merged as soon as its spelling is complete. Unreviewed fallback
content stays whole; it is never cut into arbitrary letter groups. See the
[morphology contract](../vocabulary/morphology-contract.md) for editorial rules.

Merged jellies show the full word, its available picture, a warm rim, and sourced
light accents. Two merged jellies with the same vocabulary identity combine by
adding their levels, including different levels: Lv1 + Lv3 becomes Lv4 and
Lv2 + Lv7 becomes Lv9. Lv1 is free; the eight higher levels are permanent coin
unlocks shared across Jelly World learning routes. Their sequential prices are
50, 100, 200, 350, 550, 800, 1100 and 1500 coins. Boss wins no longer grant levels.
Sums clamp to the learner's unlocked cap, so Lv2 + Lv3 becomes Lv4 when Lv4 is
unlocked. A merged Jelly already at that cap cannot participate in another
merge; an attempted drop preserves the active combo without matching-error
feedback. All carried mass and fragments survive a legal union. A matching
Jelly can also join a below-cap accepted result while its previous fusion is
still animating.
The map's sourced Jelly LvN badge is an actionable Upgrade entry, while the
active board names the available cap. The first saved Stage 1 clear leads through
a power-discovery modal into a focused Lv2 charging guide; saved clear coins are
already available. Holding the control invests 25 coins per saved pulse toward
the next level, and releasing stops it. A horizontal progress rail marks each
level and shows invested coins against the next-level price. Inspecting a
future ability does not change the next level being funded. Jelly powers and
Auto merge retain independent funding and ownership across leaving and reloads;
recovery resumes a paid contribution's retained receipt without another debit.

The upgrade scene gives the acquired Jelly or wand a large focal position above
the actual ability preview and milestone rail. Saved deposits add a coin flight,
local pulse and coin-handling sound. Crossing a saved level marker adds a
rebound, sourced rays/glints and one reward cue. Effects and sound
carry the milestone without notification copy. Numeric level and coin progress
remain visible; reduced motion uses a still light accent without traveling coins
or body deformation. The acquired gel, wand, coin, glow and audio retain the
source and license records above.

On the board, Lv2–9 show their individual number at the upper-right;
carried chest fragments use the opposite corner. All stages retain one ordinary
cell. Joining, picture matching, and upgrading do not collect rewards or learning
credit. Collection owns the existing reward transaction and eligible manual
learning evidence; an upgrade does not multiply mastery or coin payouts.
Manual collection requires a click or tap released in under 500 ms on the same
merged jelly without dragging. Holding for 500 ms or longer never collects on
release; the held jelly can still be dragged into another matching merged jelly.
A receptive merge result remains a valid held-drop target throughout its final
settling wobble, although picking up or collecting that result still waits for
settlement. Main and Challenge objectives count the collected Jelly's actual
level, while wallet, fragments and learning remain exactly-once transactions.

Picture clues use more of the gel face, including a larger, centered image below
the compact fragment corner. Merged pictures fill the available space above the
caption and between reward badges; the level numeral keeps its font size in a
badge fitted to the digit. Captions retain their 13 displayed-pixel reading floor.
The original acquired pictures, colors, aspect ratios and animation frames remain
unchanged. A subtle darkened silhouette underneath shares the same animated
texture to separate pale details from the gel, without cropping source frames or
loading another animation. Readiness glints stay on the outer rim behind the
learning faces. These changes leave tile positions and input bounds unchanged.

Each level has distinct collection motion and audio. Lv1–3 use pearl, twin-ripple
and spiral releases. Lv4 contracts and gathers light before its gold firework
explodes, opens three colored blossoms, and drops fading embers. Lv5 adds a rose
cascade; Lv6 opens a prismatic bouquet. Lv7 forms an aurora crown, Lv8 showers
constellations, and Lv9 releases a grand bouquet. Manual release occurs at 180 ms
for Lv1–3, then 660, 720, 780, 840, 900 and 960 ms for Lv4–9. The model's
collection transaction finishes 240 ms after release. The separate board effects
last 0.80, 1.10, 1.45, 2.80, 3.10, 3.40, 3.60, 3.80 and 4.00 seconds after
release, remain input-transparent, and clear on pause or exit. Batch collection
keeps its 40 ms release, 120 ms collection motion and 40 ms inter-pickup gap.
Lv4–9 add an independent 100 ms impact hold at release, even when no later
blast target survives. The batch clock includes that hold, without skipping
or advancing its source-centered effects. Batch releases use
with smaller and less dense effects at 75 percent of their manual lifetime.
Reduced motion uses a compact still light accent.
Profiles and acquired material are recorded in [Jelly level feedback](jelly-level-feedback.md).

Lv1 collections do not award bonus coins. Lv2 through Lv9 have independent collection
chances of 2%, 4%, 12%, 20%, 30%, 40%, 50% and 80%, with respective payouts of
50, 100, 150, 200, 250, 300, 350 and 450 coins. Both probability and amount increase
with merge level, independently of component count and footprint. Opening chests
provides additional coins. A collection without bonus coins still records
the learned word and collects all carried chest fragments, without a coin
flight or coin sound. The roll is retained across collection retries and uses
a separate random stream from word supply and powerups. Merging preserves all
fragment markers, while tapping the complete word collects them.
Carried fragments use a compact upper-left stack of at most two current-tier
chest icons. One or two fragments remain directly countable; larger stacks show
their exact total in a small cream count capsule. The group fits inside the
jelly with a separate space above the spelling, so accumulated natural fragments
cannot create a row of icons across neighboring bodies. A brief, local receive
pop follows the existing fragment-arrival clock; reduced motion keeps it still.
This reuses the acquired chest texture and its existing source/license records
in [Jelly fragments](jelly-fragments.md) and [chest replacement](chest-refresh.md).
The chest is a static cropped render here, with runtime scale animation; no new
artwork or audio is acquired. The count capsule is an interface layout primitive.
All source parts, intermediate compositions, atomic words, completed words, and
previews use one ordinary square cell. The seven-column, eight-row well uses a
responsive cell pitch; neither spelling length nor accumulated parts
enlarge a body. This is the former ordinary Jelly display size, not a fixed
32-pixel rendering size. Labels fit the available square at a minimum of 13
displayed pixels and wrap only at approved boundaries. Overflow uses an ellipsis
while preserving the full spelling in accessibility text and the Read detail.
Hold an overflowed Jelly still for 450 ms, or focus it and press R, to pause and read. Moving
more than seven displayed pixels cancels the hold; quick taps still collect
completed words. The Read detail also works for supply previews without dropping
them. Resizing never changes logical footprints.
The layout reserves a vertical left goal column before fitting the seven-column
well. It never relocates pending targets into a top carousel. Narrow goal cards
reuse the same acquired pictures, paid-action controls, exact prices, progress
fill and counts; the smallest rail stacks its contents instead of overlapping
the cost and fraction. Long lists retain real vertical scrolling.
On phones, conflicting actions and the acquired Boss move below the well, with
the Boss still to the right of the action group. Wider screens keep their right
rail. This preserves the existing 32-display-pixel cell minimum rather than
shrinking words to make three narrow columns; genuinely undersized windows pause.
The model owns the merge and collection clocks, wallet receipt, fragment count,
and chest tier. Visual callbacks never grant coins.

The current interface pass takes its material cues from the acquired mint gel
and Fluent medal: cream goal cards keep the word and its separate count on one
reading line, while the free ready-to-Collect action gets a stronger mint
surface than the optional paid tools. Existing charge artwork, input bounds,
body size and timing remain unchanged. The medal and measured numeric glyphs
form one centered group, including five-digit records; highlights support that
subject rather than adding another idle motion. These are layout/type/state
refinements of the integrated production art, not new acquisitions.
Normal word-goal lists start with the individual cards, without a medal,
`Word goals` heading or aggregate completion subtitle. The cards reclaim that
vertical space; the separate countdown and Challenge best-stage records stay intact.

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
compatible roots, finishes picture matching, or adds levels of matching words,
clamping the result to the same unlocked cap as manual merging.
It leaves merged jellies on the board for ordinary collection. The planner checks
an entire completion path and all intermediate rectangles before charging.
The same upgrade scene includes Auto merge: free Lv1 handles up to three
completed, collectable Jellies, and each higher level adds one output up to eleven at Lv9.
Its unchanged upgrade costs and independent saved ownership are documented in
[coin economy](../coin-economy.md). Ingredients and intermediate spelling joins
do not consume output slots; a complete path and its required picture are reserved
together. Each completed product remains separate throughout this use.
The button's sourced gel-and-number badge shows this actual owned capacity.
The accepted click first gives one 100 ms world hit-stop with a local acquired
violet light response. Eligible pairs then launch every 100 ms, each with a 320 ms flight, 110 ms fusion,
and 30 ms settlement. Flights overlap; only steps that need an earlier result
wait for that result to settle. Partial-only paths cannot buy the tool.
Its assisted result remains collectable without creating mastery evidence.
The paid Treasure and +30 sec controls are retired. Their buttons, quotes and
purchase routes are unavailable; natural chest fragments and earned treasure
remain. Auto merge payment is persisted before the action starts, and its price
advances only after successful payment. Failed or duplicate payments do not
advance it. Supply and danger clocks wait while the action runs; Home and the
Finish pull gesture pause it. The action never collects words, grants coins or
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
and body size. Moving a supporting jelly away leaves the stack above its old
position in place for 600 ms before gravity starts. The delay begins when the
drag crosses its movement threshold, continues through placement, and pauses
with the game. Returning the support before the deadline cancels that fall.
The released jelly itself and unrelated stacks retain their ordinary gravity.
Moving preserves its word,
picture, mass, fragments, and reward receipt without paying coins.
Reduced motion keeps the same placement rules and static preview, placing
the body directly at its supported destination.

A manual pair remains draggable during its fusion. Picking either visible lobe
moves the whole joining pair while the existing merge clock continues. When the
clock finishes, its single result inherits the same pointer and finger offset.
Releasing a drag earlier completes that already accepted pair once, then uses the
ordinary placement or merge rules for the resulting body. Canceling movement
returns the animation to its reserved slot. A short tap on either lobe queues
collection of its valid completed word, including when the union finishes under
the finger. The existing neutral contact rim acknowledges the tap; collection
starts after the original union and settling finish. Repeated taps coalesce into
one collection. Moving more than seven displayed pixels or holding for at least
500 ms does not queue collection. A later drag supersedes that body's queued
tap. Pause defers accepted taps; leaving or restarting discards them. Failed
reward saves retain the ordinary explicit retry and the original reward roll.

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

Falling neighbors and supply pictures that have departed the tray remain
available as drag targets before settlement. Contact follows their current
painted position and refreshes each frame, so a stationary held word can catch
its matching picture as it descends. The same slight-touch margin applies;
nonmatches still require silhouette overlap. Releasing a valid catch starts
the union at the visible contact pose and removes the consumed fall animation.
Queued supply items, lifted bodies and accepted fusion endpoints cannot be
caught again. Keyboard and automatic merge commands retain settled targets.

New seven-part supply packets mix parts from different words, leaving intervening
pieces between siblings whenever the packet permits it. Word provenance, part
order, and fragment markers stay attached to each piece, including targets that
span packet boundaries; already visible previews are never reshuffled.
The exact ordering search reuses equivalent per-packet states, preserving its
original first-tie order without repeating the same remaining work.
Neighboring bodies leave a nine-percent cell gap for clearer separation.

On pointer press, every available target that legally composes with the selected
part in source-then-target order gains a cream inner edge and deep teal outer
edge traced from its acquired gel silhouette. The steady contour separates the
target from both pale scenery and crowded neighboring skins. Material light
and a reduced directional spill support that boundary. A brief sheen crosses the skin during the
first second of each three-second cycle. The skin grows to 112 percent over
200 ms, then breathes between 112 and 114.5 percent on a 2.2-second cycle while
the target remains eligible. Newly available targets get their own entrance
even during a long hold. Keyboard source selection shows the same targets.
While at least one target is available, unrelated board skins and their permanent
light accents recede. Pictures, lettering, level and fragment badges retain their
normal appearance. The held source and matching family stay bright; candidates
render above neighboring ordinary bodies and below the dragged source. No targets
means no dimming. Preview and placement controls keep their own presentation.

The distance field continues beyond the texture's transparent margin, allowing
the spill to fade naturally rather than terminating at a rectangular mesh edge.
Shader padding accommodates the light without enlarging the painted body or hit
area. Idle merged-word strength stays below the matching-light threshold. Its
established Bobardo portal texture and Toon FX sparkles retain their existing
presentation; source, creator and Standard Unity Asset Store EULA details remain
in the [fragment asset record](jelly-fragments.md). The underlying acquired Jelly
Squash artwork and CC0 attribution remain in [Jelly Match](jelly-match.md).

Green merge contact keeps its own contour. No new artwork or audio was acquired.
Lettering, pictures, fragment markers, hit areas and rewards stay unchanged.
Release, cancellation or leaving play clears the cue and restores unrelated skins.
Reduced motion keeps the contour and material contrast steady without a sweep or enlargement.
Selected merged words highlight available merged words with the same word ID
only while both remain below the learner's unlocked level cap. Different levels
can combine, with their sum clamped to that cap. A merged Jelly already at the
cap cannot merge with any other Jelly, manually or through Auto merge. Its
contact stays neutral, and releasing preserves both bodies and the active combo
without an incorrect-answer sound or rejection accent.
Actual merge contact uses the same resolver as manual merging and Auto merge. Reviewed partial joins are valid; results that
lack room do not light up or incur an incorrect-answer penalty. Root joins follow
the reviewed reading order. Word-picture matching and additive upgrades work
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

Supply releases across alternating columns (1, 5, 2, 6, 3, 7, 4), with 0.15 seconds
between starts. The bodies accelerate under the existing gravity and recover
after landing. Shared entry lanes retain extra clearance so a later piece cannot
overtake an earlier one. Each preview slot refills after its own departing body
has cleared it. Reduced motion keeps the same readiness clocks while placing
bodies directly at their reserved destinations. Outside campaign-bound rounds, automatic supply starts
with a twenty-second baseline interval. Every four successful completed-word collections reduce
the next cycle's interval by two seconds, down to ten seconds after twenty
collections. Tap and Collect pickups count equally; idle time, merge-only play,
Auto Merge, and failed collections do not increase this legacy unbound-round progression. Each successful
packet dispatch, automatic or manual, fixes the interval for the following
cycle. Collections never shorten the current Next countdown, and rejected
dispatches leave it intact. New rounds restore the twenty-second opening
baseline interval. Reviewed rounds multiply that baseline by
`max(1, preview occupied area / 7)` for the next wave; atomic collections count
once, while partial merges never count. Numbered-stage recipes instead use
the actual 21/7 workload, a 20-to-7.5-second cadence and 1.0-to-1.6 descent scale.
Full-board rescue lasts ten seconds in the first stage, then eight, seven or
six seconds in later stages. Every stage and Challenge stops that countdown
as soon as one real cell becomes vacant, including an internal gap awaiting
gravity. A blocked Next entrance does not keep or restart a full-board warning
while a vacancy remains. Held return cells and unfinished fusion reservations
stay owned until the actual operation commits. The sourced border takes that actual warning duration,
not a hardcoded ten-second shader clock. Its existing colors, glow, beat and
reduced-motion behavior remain unchanged. A short **Free 1 space** hint
temporarily occupies the secondary level badge's bounds without moving goals,
covering cells or adding an input layer. Recovery pauses new dispatch while
owned airborne bodies keep their motion. Opening one space restores the normal
badge and allows supply whenever its separately validated entry lane is clear.
The independent stage timer continues normally.
The same acquired collected-word card prefers space outside the well during
an active rescue, preserving Next, the actual countdown and rescue hint as well.
If that content envelope cannot fit safely on a short screen,
its opaque reading surface stays hidden while its existing effect clock,
separate board burst, spelling labels and pronunciation retain their ownership.
It is not restarted after recovery and no asset or reward is substituted.
This polish
reuses the integrated gel artwork and landing
audio above; it adds no downloaded assets.

The committed preview has seven lanes, with each jelly using one square slot.
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
rows, with one pickup every 140 ms. Each batch collection finishes within that
same beat, keeping reward transactions sequential, with the existing pop sound
at 40 ms to match the squash and release. Ten words finish in 1.4 seconds.
Each jelly squashes, lifts
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
collection from the remaining coin-priced Auto merge tool. This rule is a decorative interface
primitive and does not receive input. Side layouts keep this action group at
the bottom of the right rail, with no empty retired slots. Other layouts place
Collect above Auto merge below the well; the divider spans their shared width.

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
