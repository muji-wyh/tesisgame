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
next experience level. The display or **More** opens the learning notebook. It
includes all words in each cohort, their 0-2 practice streaks or Mastered labels,
pronunciation and short meanings. Each age uses one continuous scrolling grid;
all its words are reachable without page controls, and nearby pictures load as
the player scrolls. Future cohorts are clearly previews: browsing them cannot
change the game's earned level or age.

Home leads with a larger, age-specific Pip and a shared-growth welcome. Its
journey shows the current vocabulary cohort's mastered words and the next Pip
appearance, independently of mastery levels. Completing all growth stages turns
the journey into a recap without promising another appearance. The six games
follow this welcome; theme and sound choices remain secondary.

Each Home game card shows a miniature example of its actual mechanic: linking
a picture and word, turning Memory cards, speaking to pop a flying word card,
ordering phrase pieces, merging a Jelly Match pair, or building and collecting
a Jelly Words word. The Jelly Words card continues from `ca` + `t` into `cat`
to a chest fragment flying into a Royal chest, its lid opening, and a fan of
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

Home offers eight illustrated theme choices below the game cards, arranged in
one row on wide screens and two rows on phones. The selected theme is highlighted
and saved automatically. Theme switching is available only on Home, including
controller shoulder shortcuts. Select the current game to continue the same round
with the new theme; saved treasure batches retain their original theme.

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
rounds. Hold the chest to open it in the modal; Home and Play again preserve any
unopened treasure. Play again waits for a new microphone gesture. Earlier saved
multi-chest batches remain claimable. Progression and durable claims are described in
[Voice Pop treasure](voice-pop-treasure.md).

## Shared settlement

Every game mode settles in a responsive modal over its completed board. Match,
Memory and Phrase Builder retain their completion celebration inside that modal,
then offer their existing chest and replay actions. Voice Pop and both Jelly modes
show their result immediately. No mode opens a standalone settlement page.

## Shared Jelly controls and settlement

Both Jelly modes begin with three rows. Their board stays within a bounded game
area; the chest sits in the header and the controls adapt to leave room for play.
The preview releases the next batch on demand without a cooldown. The sourced
panoramic sky has slow drift and daylight changes; Home, the notebook, page
hiding and Finish confirmation pause play and scenery. Reduced motion keeps the
sky still. See [Jelly sky](assets/jelly-sky.md) for the artwork and rendering.

Pull Finish downward until it glows and sounds, then release to finish. An early
release springs back without ending play; tapping demonstrates the pull. Keyboard
and controller activation use a Keep playing / Finish confirmation instead.
Finishing or letting the full-board danger countdown expire opens settlement in
a modal over the frozen board. The modal shows the score, completed words and
earned chest, including an empty result. There is no standalone Jelly result
page. Play again collects pending treasure and starts a new round; Home retains
unopened treasure. Failed saves remain available for retry.

## Jelly Words

Join letter chunks on a six-column board. Dragging `ca` onto `t` makes `cat`:
the dragged chunk comes first, and the joined spelling must be an exact word
in the current learning-age vocabulary. Both bodies flow into one larger jelly
near the drop target. A completed word can join another piece only when their
combination is also a valid word. Invalid combinations separate with elastic
feedback and a negative sound, without creating a merged body.

Jellies can move to another position where they fit. Unsupported bodies fall
vertically onto the next support or floor, including after a supporting word is
collected or dragged away. Held bodies and active merges finish before their
deferred fall. Larger bodies and long text wrap across rows when needed.

At rest, exact-word partners share a painted color, including partners in the
upcoming preview. Other pairs use different hues. Picking up a chunk updates
the hints: targets that complete a word in the dragged order share its color,
glow and gently pulse. This handles chunks with several correct partners, such
as `ca` with either `t` or `n`. Reverse-only partners keep their resting paint
and receive no highlight: dragging `t` does not cue `ca`, because `tca` is not
a word. All jellies still react to physical contact, including invalid pairs.

Automatic batches start 20 seconds apart. Each collected word shortens the
interval by 0.04 seconds, down to a 16-second minimum. Tapping the preview can
still release the next batch early. The preview sits above the well: each jelly
leaves its visible slot, accelerates down its lane and compresses briefly on
contact before becoming playable. A small stagger separates the releases;
successive arrivals in one lane keep enough spacing to avoid overlap. Arrivals
stop at the first support reachable from above, never inside an enclosed hole.
Sealing every entrance starts the existing full-well countdown. Reduced motion
places incoming bodies directly on their supports with the same readiness clock.

An exact word from the current learning-age vocabulary reveals its picture and
a warm rim. Each word collected by a tap or Collect has an independent 1%
chance of bonus coins. A lucky drop awards 50 coins for a two-part word, or 100
for a word with three or more original chunks. Opening chests is the main
coin source. Every collection records learning and banks all carried fragments,
including when no coins drop. Merging alone does not grant coins or mastery.
Failed coin saves preserve the word and its original reward for retry;
repeated input cannot reroll or award the same collection twice.

Auto merge costs 600, 900, then 1200 coins for further uses in the same round;
Treasure costs 200, 300, then 400. Each item has its own successful-use count,
and its button displays the next price. Treasure still distributes 2–8 fragments;
Auto merge launches a random compatible jelly every 200 ms, dragging it to its
target over 300 ms, and leaves completed words for manual collection. Failed payments
do not advance a price. A fresh round resets prices. See the
[coin economy plan](coin-economy.md) for income assumptions and spending targets.

A completed manual merge queues the word's recorded pronunciation once. Auto
Merge retains fusion sound effects without pronouncing its words. An accepted
word tap also presents its picture and spelling above the board and pronounces
it once. Collect gathers ready words at 120 ms intervals without pronunciation.
Each reveal has its own randomly varied position and size, fits its picture and
spelling, and enters with elastic squash and stretch. Successive reveals coexist
and fade independently instead of replacing one another. They do not intercept
board input and clear on pause, exit or round completion. Reduced motion keeps
the picture and spelling steady.

Chest fragments remain attached when either jelly is merged. Two marked pieces
produce two visible markers, and collecting the complete word banks all of its
fragments. Chest creation and upgrades use the shared enlarged, rotating reveal,
light accents and paper confetti. The game menu, page hiding and word notebook
pause play; the existing Jelly reward room stores earned chests.

## Pip and completion

Pip's earned appearance progresses through ten stages. Each adds a motion to the
previous repertoire. Basic expressions, answer feedback and the full round
celebration are available from Baby Pip. World selection does not replace the earned
appearance. The loader retains its established themed wardrobe.

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

**Home** and **Play again** occupy the dialog footer. Play again starts a fresh
round of the same mode. Match, Memory and Phrase Builder require an earned chest
to open and save before replay; save failures expose **Retry save** and block
navigation until the reward is safe. Home preserves the completed round, so
returning to its mode restores the dialog. The finished game remains visible
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
