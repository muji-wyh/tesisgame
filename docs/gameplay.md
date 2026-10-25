# Gameplay reference

**Grow with Pip** is an English vocabulary game with Match, Memory, Phrase Builder,
single-player Voice Pop, Jelly Match and Jelly Words. It starts on Home, where players choose a game. There are no
accounts, usernames, identity avatars, leaderboards or Pip's room.

## Growing together

Every device starts at **Lv0** with **Baby Pip**. The age-labelled vocabulary
cohorts are 3, 4, 5, 6, 7, 8, 9, 10, 11 and 12+. These form an editorial
English-as-a-second-language learning sequence, not developmental standards or a
native-English vocabulary checklist. Experience levels and Pip's age are independent.

A correct completed activity adds one to each unique involved word. A wrong
answer resets its involved words. Three consecutive correct answers mark a word
**Mastered**. First-time mastery adds permanent experience toward Lv99. Mastering
the complete current cohort grows Pip to that age and unlocks the next cohort.
Previously earned levels and ages never decrease, even when a mastered word needs
practice again. Hints, pronunciation, peek, cancelled selections and idle time give no credit.

New word selections gently favor unfinished learning: mastered words carry a
relative weight of **0.8**, while unmastered words carry **1.0**. Review remains
part of every mode. A mistake restores the word's normal weight. Continuous Jelly
and Voice Pop supply follows current mastery as play continues, while keeping
existing previews and complete word groups. The current-age vocabulary rule is unchanged.

The persistent level display and progress bar show new words mastered toward the
next experience level. The display or **Word library** opens the vocabulary library. It
includes all words in each cohort, their 0-2 practice streaks or Mastered labels,
pronunciation and short meanings. Each age uses one continuous scrolling grid;
all its words are reachable without page controls, and nearby pictures load as
the player scrolls. Future cohorts are clearly previews: browsing them cannot
change the game's earned level or age.

Word Library has **Everyday English** and **Professional English** categories.
Professional vocabulary uses the same Grow with Pip Home and six games. Choose
a career and module, then **Use this vocabulary** to return Home. Browsing alone
does not change the active vocabulary or the paused round. A module still in
preparation can be selected, but its games remain unavailable until its content
is ready. The chosen vocabulary is remembered on this device independently of
the last played round. Ready modules download their media when a game is chosen.

The active professional vocabulary is identified on Home. Its Pip wears that
career's dedicated outfit and shows a career level, derived from earned mastery
of unique terms in that career using the usual level curve. Shared terms count
once in each relevant career. Earned mastery survives later mistakes; viewing
words and changing vocabulary award no experience. The gameplay header and
reward celebrations keep the same career Pip. Returning to everyday vocabulary
restores the saved everyday level, age, and appearance.

Everyday Home leads with a larger, age-specific Pip and a shared-growth welcome. Its
journey shows the current vocabulary cohort's mastered words and the next Pip
appearance, independently of mastery levels. Completing all growth stages turns
the journey into a recap without promising another appearance. The six games
follow this welcome; vocabulary and sound choices remain secondary.

Each Home game card shows a miniature example of its actual mechanic: linking
a picture and word, turning Memory cards, speaking to pop a flying word card,
ordering phrase pieces, merging a Jelly Match pair, or building and collecting
a Jelly Words word. The Jelly Words card matches `cat` with its separate picture,
then shows a chest fragment flying into a Royal chest, its lid opening, and a fan of
gold coins. This shows the treasure reward alongside word construction.
These decorative examples use fixed interface artwork and
do not select curriculum words, load another age's vocabulary, or earn rewards.
All six cards automatically loop silent demonstrations with staggered timing,
readable result holds and soft resets. Pointer and keyboard focus still belong
to the whole card. Hidden Home and background tabs pause the examples; returning
resumes them. The system reduced-motion setting keeps every example static,
including a completed word and open chest on the Jelly Words card.
The reused artwork and source rights are recorded in the
[mode illustration attribution](../assets/images/ui/modes/ATTRIBUTION.md).

Vocabulary selection also supplies the setting: everyday words use Pip's garden,
while professional vocabulary uses its workplace palette and available artwork.
Saved treasure batches retain their original theme.

See [growth rules and persistence](growth-system.md) and the
[curriculum research](vocabulary/growth-curriculum.md) for the complete mapping.

## Match

Tap a word and its matching picture. A correct pair stays visible, linked and
available for pronunciation. A mismatch resets both involved words' streaks;
the player can correct it and continue until all five pairs match. There is no
three-mistake loss or visible correct/error counter. Card positions stay stable.

The Hint item costs 100, 150, then 200 coins, with every further purchase staying
at 200. There is no per-round use limit; the button shows only its next coin price.
Payment must save before matching partners are highlighted; insufficient coins
or a save failure preserves the board, wallet and next price. Repeated input
cannot charge again for an active hint. A new round resets the price to 100.
Completed cards can replay
the word without adding mastery. The optional microphone interface can select
words through speech; it follows the same successful-pair boundary.

## Memory

Turn over two cards to find a word-picture pair. Correct pairs remain revealed;
unmatched cards turn back after feedback. A correct pair credits its word once.
A mismatch resets both involved words. There is no visible correct/error count.

Click or tap the eye button to reveal every card. The first successful reveal in
a round lasts 10 seconds; later reveals last 5 seconds. A countdown and glowing
progress bar show the remaining time, then unmatched cards hide automatically.
Releasing the pointer, touch, key or controller button, moving away, and changing
focus do not shorten the reveal. Repeated activation during the countdown neither
extends it nor charges again. Escape, Xbox B, Home, opening a collection, or a
page/input interruption cancels the reveal. Looking at cards does not change mastery.
The first reveal in a round is free; later reveals cost 100, 200, then 300
coins, with further reveals staying at 300. The button shows the next price.
A declined payment starts no countdown and does not advance the price or use count.

## Phrase Builder

Listen to a short phrase, then drag or tap the candidate word cards onto the
answer line. Dragging an answer card reorders the line during the gesture.
Candidates remain on a single horizontal rail; scrolling reveals longer banks.
Words with authentic illustrations retain them in the candidate bank and answer.
Contextual words such as articles and abstract concepts use clear text cards.

The compact waveform bar replays the phrase. With sound muted it also displays
the text. Individual cards retain word pronunciation. There are no spoken guide
prompts or Pip calls. **Check answer** is available after every answer position
has a word. Incomplete checks and moving cards do not affect mastery.

Correct phrases credit every unique target word. Wrong phrases reset the target
words and any chosen distractor, leaving unused candidates unchanged. The player
can continue correcting without a failure limit. Pip briefly celebrates between
questions; after three correct phrases the shared completion celebration begins.

## Voice Pop

Start the microphone, then say a live target word to pop it. There is no player
picker. Speech matching, live captions, the round timer and combo time bonuses
remain available. At the deadline, the board freezes behind the shared settlement
modal, which shows the score, popped-word count and final earned chest. The
standalone results page and its word-review controls have been removed.

A successfully spoken live target credits its word once, even when recognition
delivers repeated interim and final callbacks. An explicit final wrong answer
bound to a live target resets that word. Silence, expiry, unbound speech and
recognition errors do not reset mastery. Speech input stops before settlement
opens. See [speech matching](voice-matching.md) for targeting details.

Voice Pop gives each target a 35% chance of a chest marker. A marked hit earns
one fragment; four unlock a chest and each additional five upgrade it. The
round saves its final chest tier before opening settlement, including zero-chest
rounds. Hold the chest to open it in the modal; Home and Play again automatically
save and collect any unopened treasure before leaving. Play again waits for a new
microphone gesture. Earlier saved multi-chest batches use the same durable claims.
Progression and durable claims are described in
[Voice Pop treasure](voice-pop-treasure.md).

## Shared settlement

Every game mode settles in a responsive modal over its completed board. Match,
Memory and Phrase Builder retain their completion celebration inside that modal,
then offer their existing chest and replay actions. Voice Pop shows its result
immediately. Both Jelly modes first show a 1.8-second end message over the frozen
board, with a distinct acquired sound for danger expiry or ordinary completion,
then open settlement. No mode opens a standalone settlement page.

## Shared Jelly controls and settlement

Both Jelly modes begin with three rows. Their board stays within a bounded game
area; the chest sits in the header and the controls adapt to leave room for play.
The preview releases the next batch on demand without a cooldown. The sourced
panoramic sky has slow drift and daylight changes; Home, the notebook, page
hiding and Finish confirmation pause play and scenery. Reduced motion keeps the
sky still. See [Jelly sky](assets/jelly-sky.md) for the artwork and rendering.

Jelly Match starts with ten seconds between automatic batches. Every four completed
pairs reduce the next cycle's interval by one second, reaching a five-second
minimum after twenty pairs. Jelly Words uses the collection-based progression
described below. In both modes, each successfully dispatched batch fixes the
interval for the following cycle, including a requested early batch. Completing
matches or words never shortens the countdown already running in Next. Idle
time does not raise difficulty; a new round restores the opening interval.

Pull Finish downward until it glows and sounds, then release to finish. An early
release springs back without ending play; tapping demonstrates the pull. Keyboard
and controller activation use a Keep playing / Finish confirmation instead.
Finishing or letting the full-board danger countdown expire first shows
**Round complete** or **Game over**, respectively, with its own sound. This
noninteractive 1.8-second effect precedes the settlement modal; held input cannot
skip it. Backgrounding freezes its clock and stops its sound without replaying
the cue on return. Reduced motion keeps the readable message without zoom or
rotation. The modal then shows the score, completed words and
earned chest, including an empty result. There is no standalone Jelly result
page. Home and Play again save and collect pending treasure before leaving.
Play again starts a fresh round, as does selecting the finished mode from Home.
A failed save keeps settlement open for retry.

## Jelly Words

Join reviewed roots on a five-column, eight-row board, then match the complete
spelling with its separate picture. Positional hyphens show the missing sides: `un-`,
`-believe-`, and `-able`. Roots follow their authored composition and spelling
changes; arbitrary letter chunks are not accepted. An atomic word such as
`cat` starts as one whole-word root plus a picture-only Jelly. Pictures match
the exact vocabulary meaning in either drag direction. A word without a picture
becomes merged as soon as its spelling is complete. Invalid combinations separate
with elastic feedback and a negative sound, without creating a merged body.

Merged Jellies show the word and its available picture, with a brighter rim and
glints. Two merged Jellies of the same word add their levels, including different
levels, up to Lv9. For example, Lv2 plus Lv7 becomes Lv9; a total above nine stays
separate. Levels 2–9 have an upper-right numeral. Each of the nine levels has a
distinct collection effect and sound; Lv4 contracts, gathers energy, bursts into
colorful fireworks, and lets its glowing embers fall. Every board and top-popover
firework layer originates at that Jelly's own center, never an unrelated screen
position. Larger levels retain broader, denser radial layers without changing
the existing nine collection recordings or adding a separate popover sound.
The complete
[level feedback reference](assets/jelly-level-feedback.md) describes these effects.

Jellies can move to another position where they fit. Unsupported bodies fall
vertically onto the next support or floor. Bodies above a dragged-away jelly wait
600 ms before falling; collecting a supporting word also releases them. Held
bodies and active merges finish before their deferred fall. Roots, pictures and
every merged level keep the same ordinary
rounded-square cell with a 1:1 aspect ratio. The well holds 40 cells and opens
with at most 15 jellies across three rows. Long labels use reviewed line breaks
or an ellipsis; hold a clipped label, or focus it and press R, to pause and read
its full spelling.

At rest, compatible authored partners share a painted color, including partners
in the upcoming preview. Other pairs use different hues. Picking up a part
updates the hints: legal targets in the dragged order share its color, glow and
gently pulse. The age-seven `tooth` part can join either `brush` or `paste` when
those words are in the round. Reverse-only partners keep their resting paint
and receive no highlight: dragging `brush` does not cue `tooth`, because the
authored graph requires `tooth` first. All jellies still react to physical
contact, including invalid pairs.

Automatic batches start 20 seconds apart. Every four successfully collected words
reduce the next cycle's interval by two seconds, reaching a ten-second minimum
after twenty collections. Tap and Collect pickups both count; idle time,
merging alone, Auto Merge, and unsuccessful collections do not. A successful
batch dispatch fixes the next cycle's interval, so the current Next countdown
never shrinks when a word is collected. Tapping the preview can still release
the next batch early. The five-slot preview sits above the well: each jelly
leaves its visible slot, accelerates straight down its corresponding column and
compresses briefly on contact before becoming playable. A small stagger separates the releases;
only a sealed column redirects a root into reachable space. The preview is already
mixed and keeps its committed order when released. Successive arrivals in one
lane keep enough spacing to avoid overlap. Arrivals
stop at the first support reachable from above, never inside an enclosed hole.
Sealing every entrance starts the existing full-well countdown. Reduced motion
places incoming bodies directly on their supports with the same readiness clock.

Lv1 collection gives no bonus coins. From Lv2 onward, each merged word collected
by a tap or Collect has one independent chance of a level-based bonus:

| Merge level | Coin chance | Coins when awarded |
| --- | ---: | ---: |
| Lv1 | 0% | 0 |
| Lv2 | 2% | 50 |
| Lv3 | 4% | 100 |
| Lv4 | 12% | 150 |
| Lv5 | 20% | 200 |
| Lv6 | 30% | 250 |
| Lv7 | 40% | 300 |
| Lv8 | 50% | 350 |
| Lv9 | 80% | 450 |

Higher levels increase both the chance and the award; component count and footprint
do not change that level's policy. Opening chests provides additional coins.
Collection banks all carried fragments. A manually solved
picture match or root composition records learning only on collection;
automatic merges and image-free atomic exposure do not earn mastery.
Successful manual merges and collections build a visible combo and refill its
eight-second countdown bar. The bar drains during active play; reaching zero
or an invalid merge ends the current chain, without removing saved coins or its
best count. A success completed at or after expiry starts a fresh chain.
Preview drops and stage transitions do not directly reset or refill it.
Pauses, saving waits and automatic matching sequences freeze its clock.
Automatic Collect adds one per committed word, while paid Auto Merge stays
neutral. Manual merges award one coin at combo 3-5, two at 6-9 and three at 10
or above. Collection still uses its separate level-based coin chance. A rank
badge advances through D/C/B/A/S/SS/SSS with sourced sparkle/ray flares and a
rising accent on each increment. Earned merge coins display a larger gold
**COMBO BONUS +N** acknowledgement for up to 1.8 seconds, including through an
immediate bonus-free collection. The countdown turns warm red in its last
quarter. Reduced motion keeps the real countdown and a steady readable badge.
Merging and upgrading alone do not grant mastery. Combo payment failures keep
the merge inputs and original receipt for Retry saving without paying twice.
Failed coin saves preserve the word and its original reward for retry;
repeated input cannot reroll or award the same collection twice.

### Collection blast matching

Each durably collected merged jelly keeps its existing level-specific explosion,
then applies this footprint to current board bodies:

| Collected level | Affected bodies |
| --- | --- |
| Lv1 | Direct collection only |
| Lv2 | One randomly selected body among the eight neighboring cells |
| Lv3 | Two randomly selected bodies among those eight cells |
| Lv4 | Three randomly selected bodies among those eight cells |
| Lv5 | All other bodies in the source column |
| Lv6 | All other bodies in the source row and column |
| Lv7 | The complete one-cell surrounding ring, at most eight bodies |
| Lv8 | Two surrounding rings, capped at eight inner and fourteen outer bodies |
| Lv9 | Every other available board body |

Edges clip the footprint; absent neighbors are not replaced by distant bodies.
Random selection does not favor bodies with a match and uses a separate stream
from word supply and coin rolls. Held, already fusing and promised batch
collection bodies are protected.

After collection commits, a blast with affected bodies slows board motion to
0.12 speed. An 80 ms source compression releases accelerating light with dense,
tapered trails; each group travels for 260 ms on an independent real-time clock.
Nearer bodies are marked first. A target is marked and sounds only when the
outward energy reaches it, with a sharp planted squash and a damped rebound
rather than floating motion. The last impact immediately restores normal board
speed; a 100 ms grounded recovery precedes automatic matching. This local clock
does not slow the interface, audio or other game modes, and the combo and supply
clocks stay frozen throughout the automatic sequence. Lv1 and empty footprints
do not start slow motion. Reduced motion retains still source/target highlights
without the traveling light, deformation or flashes.

Each marked body
with a legal partner flies to that partner anywhere on the board and merges.
Reviewed spelling order is preserved even when the affected body is the suffix
that flies toward its left-hand root. Identical words may upgrade only when their
sum is at most Lv9. Unmatched marks fade without consuming a body or inventing a
word. All carried fragments survive the automatic union.

The free sequence reuses the automatic matching flight, fusion and settling
clock; it never purchases an item or increases its repeat price. It does not
collect its results, add combo increments or payments, or award independent
mastery. Results remain assisted and available for later collection. Batch
Collect finishes its captured pickups first, then coalesces overlapping blast
marks into one bounded sequence so two explosions cannot consume the same
endpoint twice. Failed collection saves do not trigger a blast; retry retains
the original outcome and receipt. Pause freezes marks and flights, while leaving
the round clears queued reactions and settles active automatic matching without
collecting their results.

Auto merge costs 600, 900, then 1200 coins for further uses in the same round;
Treasure costs 200, 300, then 400. Each item has its own successful-use count,
and its button displays the next price. Treasure still distributes 2–8 fragments;
Auto merge follows validated paths of root joins, picture matches and
same-word upgrades whose combined level is at most nine. It launches an eligible
pair every 200 ms, with each 250 ms flight overlapping the following flight.
A dependent step waits for its
required result to settle; independent pairs can launch while earlier merges
continue. It leaves merged words for manual collection. Failed payments
do not advance a price. A fresh round resets prices. See the
[coin economy plan](coin-economy.md) for income assumptions and spending targets.

A completed manual merge immediately plays the word's recorded pronunciation once,
replacing earlier speech instead of waiting in a queue. Auto
Merge retains fusion sound effects without pronouncing its words. An accepted
word tap also presents its picture and spelling above the board and pronounces
it once. Picture-only jellies and complete spellings awaiting their picture also
pronounce their word on a tap. Partial roots stay silent. Collect gathers ready
words at 140 ms intervals without pronunciation. Each Auto Merge takes 250 ms
to fly, 110 ms to fuse, and 30 ms to settle. Its 200 ms launch interval runs
independently of that 390 ms sequence.
Each reveal has its own randomly varied position and size, fits its picture and
spelling, and enters with elastic squash and stretch. Successive reveals coexist
and fade independently instead of replacing one another. They do not intercept
board input and clear on pause, exit or round completion. Reduced motion keeps
the picture and spelling steady.

Jelly Words selects ten unmastered, independently assessable words for each
stage. Everyday English fills from the earliest unfinished ages, crossing age
boundaries when needed; Professional English stays in the selected ready module.
The set remains fixed until all its words are mastered. Saved mastery immediately
removes a word from future supply and advertised previews. Existing board bodies,
levels, fragments, and receipts survive a stage change. A permanent stage counter
shows mastered targets, and a short light-and-sparkle banner announces each next
stage. Completing the current stage also launches one full-screen confetti burst,
keyed to that stage rather than a chest tier. This includes the last partial
stage when no next-stage vocabulary remains. The final stage can contain fewer
than ten available words; completing the whole eligible pool ends the round.
Unsuccessful saves never advance or celebrate a stage.

Chest fragments remain attached when either jelly is merged. Two marked pieces
produce two visible markers, and collecting the complete word banks all of its
fragments. Chest creation and upgrades retain the shared enlarged, rotating
reveal and local light accents, but do not launch Jelly Words confetti. Stage
paper scales from 384 to 1,200 pieces with the viewport and covers both its width
and height rather than a small local patch. The game menu, page hiding and word notebook
pause play; the existing Jelly reward room stores earned chests.

## Pip and completion

Everyday Pip's earned appearance progresses through ten stages. Each adds a motion to the
previous repertoire. Basic expressions, answer feedback and the full round
celebration are available from Baby Pip. Professional vocabulary uses the selected
career's dedicated outfit and earned level; switching back restores everyday Pip.
The loader retains its established themed wardrobe.

The [preview](../web/preview/pip-growth/index.html) lets reviewers select every
stage, replay each unlocked action and explicitly hear its voice lines. Voices
use the approved Ava profile. Extra character speech is not gameplay guidance.
Source artwork, animation composition and audio provenance are recorded in
[Pip growth assets](assets/pip-growth.md).

Every mode completes in the shared settlement dialog over its finished game;
there is no separate results page. Match, Memory and Phrase Builder show Pip's
three-second celebration inside the dialog. If a chest was earned, **Open chest**
appears only after the performance and final pronunciation finish, then reveals
the hold-to-open chest in the same dialog.

Chest coins also grow with Pip's earned level shown in the header, using the
current career's progress during professional vocabulary. Each newly quoted
chest tier pays 75 base coins plus `ceil(24 * clamp(Pip Lv, 0, 99) / 99)` bonus
coins: 75 at Lv0, 80 at Lv20 and 99 at Lv99. Settlement shows the base reward,
the saved Pip-level bonus and the total
after opening. The amount is saved when settlement first prepares the chest, so
retries, Home, replay and reload use the same reward. Previously paid chests keep
their original amounts. See [coin rewards](coin-rewards.md) for the full policy.

**Home** and **Play again** occupy the dialog footer. Both actions automatically
save and collect any remaining earned chest rewards, including an unfinished
opening. Save failures expose **Retry save** and block navigation until the reward
is safe. Play again starts a fresh round of the same mode. Home returns to the game
menu; selecting the finished mode starts a new round. An unfinished round still
resumes when selected from Home. The finished game remains visible
with input blocked, and clicking the shade or pressing Escape does not dismiss
settlement. Repeated input cannot duplicate rewards. Hiding the page interrupts
safely; an unfinished celebration can replay, while a completed invitation does
not repeat the full performance.

## Controls, accessibility and saves

Touch and mouse input share the same controls. Arrow keys and controller
D-pad/left stick move focus; Enter, Space or controller A activate it. Home
opens the game library; tapping Pip plays an age-appropriate motion.
Escape/controller Back closes ordinary overlays and returns to the current
round; settlement uses its own Home and Play again actions. Home remains
available during celebrations, but underlying answer and chest actions are
gated.

Home contains the word library and sound control. Motion follows the device's
system setting automatically. Reduced motion keeps static artwork and clear
feedback while removing unnecessary jumps, sways and glows. Word and phrase
pronunciation remain independently replayable when sound is enabled. Menus use
the shared concise selection cue.

Scrollable rails and catalogs support touch, wheel and keyboard/controller
focus reveal. A tap that stops scrolling does not activate the underlying card.
Screen-reader status communicates current progress, selection and outcomes.

Learning progress saves separately from existing medal and Voice Pop chest
records. Failed writes expose **Retry saving** rather than publishing progress
that was not stored. Clearing browser storage removes local progress. Legacy
names, avatars, scores and age choices cannot grant mastery or skip Baby Pip; old
reward records are retained for compatibility. See [development](development.md)
for running and deploying the game.
