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
a Jelly Words word. These decorative examples use fixed interface artwork and
do not select curriculum words, load another age's vocabulary, or earn rewards.
All six cards automatically loop silent demonstrations with staggered timing,
readable result holds and soft resets. Pointer and keyboard focus still belong
to the whole card. Hidden Home and background tabs pause the examples; returning
resumes them. The system reduced-motion setting keeps every example static.
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

The Hint item costs 200 coins per use, with up to three uses per round. Its button
shows the coin price and remaining uses. Payment must save before matching
partners are highlighted; insufficient coins or a save failure preserves the
board and allowance. Repeated input cannot charge again for an active hint.
Completed cards can replay
the word without adding mastery. The optional microphone interface can select
words through speech; it follows the same successful-pair boundary.

## Memory

Turn over two cards to find a word-picture pair. Correct pairs remain revealed;
unmatched cards turn back after feedback. A correct pair credits its word once.
A mismatch resets both involved words. There is no visible correct/error count.

Hold the eye button to peek. Releasing the pointer, touch, key or controller
button closes the eye immediately. Cancellation, interruption and page hiding
also end the peek. Looking at cards does not change mastery.

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
picker. Speech matching, live captions, the round timer, combo time bonuses and
the result's word review remain available. The result page preserves the score,
chest progress, popped and missed words, replay buttons and existing chest action.

A successfully spoken live target credits its word once, even when recognition
delivers repeated interim and final callbacks. An explicit final wrong answer
bound to a live target resets that word. Silence, expiry, unbound speech and
recognition errors do not reset mastery. Speech input stops before celebration
audio starts. See [speech matching](voice-matching.md) for targeting details.

Voice Pop saves its chest batch at the round end. A batch of one, two or three
chests receives the shared celebration before the complete results appear.
A zero-chest round goes directly to results. Chest thresholds and durable claims
are described in [Voice Pop treasure](voice-pop-treasure.md).

## Jelly Words

Join letter chunks on a six-column board. Dragging `ca` onto `t` makes `cat`:
the dragged chunk comes first. Both bodies flow into one larger jelly, which
stays near the drop target and can join another piece. Collecting a supporting
word makes the unsupported stack fall vertically into the gap, with a brief
soft landing. Held bodies and active merges or splits finish before their
deferred fall. Larger bodies and long text wrap across rows when needed;
ordinary merges keep their target height.

The preview, well and Finish control form one group anchored to the bottom of
the available play area, with a 12-pixel inner bottom margin in addition to the
page padding. Resizing keeps the supply above the well and the footer in reach.

At rest, exact-word partners share a painted color, including partners in the
upcoming preview. Other pairs use different hues. Picking up a chunk updates
the color hints: every target that completes a current-age word in the dragged
order shares its color. This also handles chunks with several correct partners,
such as `ca` with either `t` or `n`. Partial three-part builds get a matching
color when one further jelly can finish the word. Color does not restrict merges.

Tap a merged jelly that is not a current vocabulary word to undo its last merge.
Its two previous bodies separate nearby onto supporting jellies or the floor,
with their original chunks, pictures and chest fragments, and refreshed pairing
colors. An invalid
merged part can be split again. Splitting earns no coins or learning credit.
If the well cannot fit two bodies, the jelly gives a brief elastic response and
stays intact until there is room.

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
a warm rim. Tap that word to collect it for 50 coins per original chunk: a
two-part word earns 100 coins, and a three-part word earns 150. Merging alone
does not grant coins or mastery. Failed coin saves preserve the word for retry;
repeated input cannot award the same collection twice.

An accepted word tap also presents its picture and spelling in a brief upper
overlay. The picture rises with a soft glow and painted glints, peaking with
the existing collection pop at 180 ms, while the word's recorded pronunciation
plays once. The overlay never blocks the board. Rapid collections replace it
with the newest word; it fades after a reading hold and clears on pause, exit
or round completion. Reduced motion keeps the picture and spelling steady.

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

Match, Memory and Phrase Builder finish with Pip's three-second celebration and
a closed chest reveal. **Open chest** appears only after the performance and
final pronunciation finish. Clicking it enters the existing hold-to-open page.
The completed chest shows **New adventure** as a lower-right floating action.
Repeated input cannot duplicate rewards. Opening a menu or hiding the page
interrupts safely; an unfinished celebration can replay, while a completed
invitation does not repeat the full performance.

## Controls, accessibility and saves

Touch and mouse input share the same controls. Arrow keys and controller
D-pad/left stick move focus; Enter, Space or controller A activate it. Pip or
the mode heading opens the game library. Escape/controller Back closes an
overlay and returns to the current round. Menu access and exit remain available
during celebrations, but underlying answer, result and chest actions are gated.

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
