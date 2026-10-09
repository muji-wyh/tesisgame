# Gameplay reference

**Grow with Pip** is an English vocabulary game with Match, Memory, Phrase Builder
and single-player Voice Pop. It starts with a playable Match board. There are no
accounts, usernames, identity avatars, leaderboards or Pip's room.

## Growing together

Every device starts at **Lv3**. The age-labelled stages are 3, 4, 5, 6, 7, 8, 9,
10, 11 and 12+. These form an editorial English-as-a-second-language learning
sequence, not developmental standards or a native-English vocabulary checklist.

A correct completed activity adds one to each unique involved word. A wrong
answer resets its involved words. Six consecutive correct answers mark a word
**Mastered**. Mastering the complete current cohort unlocks the next level.
Previously earned levels never decrease, even when a mastered word needs practice
again. Hints, pronunciation, peek, cancelled selections and idle time give no credit.

The persistent level button and progress bar show mastered words in the current
cohort. The button or **More** opens the learning notebook. It includes all words
in each cohort, their 0-6 streaks or Mastered labels, pronunciation and short
meanings. Future cohorts are clearly previews: browsing them cannot change the
game's earned level.

The notebook also offers eight worlds. On short screens a header icon cycles
worlds; on larger screens an illustrated horizontal strip offers direct choices.
Changing worlds preserves the current round. Back returns to the same game.

See [growth rules and persistence](growth-system.md) and the
[curriculum research](vocabulary/growth-curriculum.md) for the complete mapping.

## Match

Tap a word and its matching picture. A correct pair stays visible, linked and
available for pronunciation. A mismatch resets both involved words' streaks;
the player can correct it and continue until all five pairs match. There is no
three-mistake loss or visible correct/error counter. Card positions stay stable.

Three hints per round highlight matching partners. Completed cards can replay
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

## Pip and completion

Pip's earned appearance progresses through ten stages. Each adds a motion to the
previous repertoire. Basic expressions, answer feedback and the full round
celebration are available from Lv3. World selection does not replace the earned
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

The library contains sound and reduced-motion preferences. Motion follows the
system unless explicitly changed. Reduced motion keeps static artwork and clear
feedback while removing unnecessary jumps, sways and glows. Word and phrase
pronunciation remain independently replayable when sound is enabled. Menus use
the shared concise selection cue.

Scrollable rails and catalogs support touch, wheel and keyboard/controller
focus reveal. A tap that stops scrolling does not activate the underlying card.
Screen-reader status communicates current progress, selection and outcomes.

Learning progress saves separately from existing medal and Voice Pop chest
records. Failed writes expose **Retry saving** rather than publishing progress
that was not stored. Clearing browser storage removes local progress. Legacy
names, avatars, scores and age choices cannot grant mastery or skip Lv3; old
reward records are retained for compatibility. See [development](development.md)
for running and deploying the game.
