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

The header's **Pause** control has two actions: tap to pause, or pull downward
until it glows and sounds, then release to finish. Pause stays on the current
screen with a mild shade, no dialog and no instruction tooltip. The button says
**Resume** and its gel gently tugs up and down while its hit rectangle stays
fixed. Reduced motion keeps it still. An early, incomplete pull springs
back without pausing or ending play. The labels say **Pull to finish**, then
**Release to finish** once armed. Keyboard/controller activation or P pauses;
the same button, P, Escape or controller Back returns to the same round.
Shift+Enter on the focused control opens the accessible finish confirmation.
Finishing or letting the full-board danger countdown expire first shows
**Round complete** or **Game over**, respectively, with its own sound. This
noninteractive 3.2-second effect precedes the settlement modal; held input cannot
skip it. Backgrounding freezes its clock and stops its sound without replaying
the cue on return. Reduced motion keeps the readable message without zoom or
rotation. Light enters before the heading instead of replacing the board abruptly.
A clear adds the acquired mastery medal, local sparkle reactions and the existing
CC0 human group cheer. Failure uses a gentler cool-colored reaction and keeps
earned treasure safe. The clear also launches the full viewport's two-sided
confetti fountains: paper spreads, tumbles and drifts all the way below the screen
bottom over 6.4 seconds, continuing independently over the ensuing result rather
than being cut off at the well or the top third of the display.
The modal then shows the score, completed words and
earned chest, including an empty result. There is no standalone Jelly result
page. Home and Play again save and collect pending treasure before leaving.
Play again starts a fresh round, as does selecting the finished mode from Home.
A failed save keeps settlement open for retry.

## Jelly Words

Jelly Words opens a scrollable **99-stage journey**, climbing from stage 1 at
the bottom to stage 99 at the top, across eleven scenic chapters of nine stages.
Entry focuses the current frontier. Acquired adventure medallions keep numbers
and their three rating stars separate. A permanently named **Challenge** action
with the acquired mastery medal sits at the upper right, with a 44-pixel touch
height. Its wallet font follows UI scale and its title fits the remaining header,
so neither the action nor a giant tooltip covers the coin total. There is no
large wooden footer taking space from the map.
Cleared stages can be replayed; only the next uncleared
stage is available beyond them. Each map node prominently shows its best
one-, two- or three-star rating. Replaying cannot downgrade it or skip an unlock.
Progress and frozen word recipes are separate for Everyday English and each
professional career/module. A recipe remains replayable after its words have
been mastered, provided the original reviewed identities are still available.
After a new contiguous clear, sourced golden light travels along the route from
the completed node to the next over 850 ms. That node then opens its padlock and
pops into its available state over 650 ms. Every later locked node retains a
padlock with restrained light. Reopening the map, replaying an old clear or
changing learning context cannot replay a progression unlock. Reduced motion
presents the final state directly; hidden/background maps stop their effect clock.

Each real round begins with a sourced, input-transparent Ready/Go flourish, not
an opaque instruction dialog. Its first 820 ms reserve the stage and supply clock;
the exact Go boundary enables play, and the remaining flourish fades away.
Pause/backgrounding freezes that same entry rather than billing stage time.
Completed word goals draw their sourced check with a small pop and success light,
silently remain marked for three active seconds, then fade/slide out and close their list space
over 380 ms. Pending goals move into the vacated slots; targets already completed
when entering or reloading do not refill the list. Completed rows show no Done
label, countdown, fraction or increment text; reduced motion shows the full check
without drawing or scaling it and retains the same silent three-second wait.

### Bramble and the stolen Word Compass

Jelly World now follows **Bramble**, a smug, mischievous rabbit who steals Pip's
Word Compass. The same rival returns with a new trick at each encounter, so the
chase has a recognizable opponent rather than unrelated disposable enemies.
His teasing targets the chase and stolen treasure, never the learner's
intelligence, English mistakes or personal characteristics.

On a new journey, stage 1 first teaches ordinary construction and collection.
After its real word goals are completed, Bramble ambushes Pip, claims the compass,
laughs and escapes toward the next encounter at stage 3. This is a **story defeat**, not a failed
learning assessment: committed learning, coins and treasure remain safe, stage 2
opens normally, and no Boss-victory medal or merged-level unlock is fabricated.
Existing saves keep their frontier and do not replay an unavoidable opening loss.
Before this ambush there is no stage-one Boss marker, watching-visitor message,
character, health display or named chase hint. Ordinary word construction still
produces collectible Lv1 Jelly; the cap restricts higher merged upgrades, not
the root/picture match. Blocked gestures give a compact material response rather
than the misleading, board-covering "Make room" panel.

| Boss stage | New trick and story beat | First-victory merged cap | Retreat |
| --- | --- | --- | --- |
| 3 | Freeze; Pip catches the compass thief's trail | Lv2 | Scrambles away |
| 5 | Ink; a new crossing reveals that the compass can open hidden routes | Lv3 | Distracts Pip and slips away |
| 7 | Two-layer locks; matching words break Bramble's locked passage | Lv4 | Pretends it was only a warm-up |
| 9 | Shadow doubles; two collected-word hits disperse the decoys | Lv5 | Panics when his real identity is found |
| 18 | Giant kick; Pip repairs the broken sky and continues the chase | Lv6 | Promises a new surprise farther ahead |
| 36 | Snatch; Bramble grabs a construction piece, flings it away, and loses it back into Next | Lv7 | Runs off without taking earned words |
| 63 | Borrowed shield; two hits break his last defensive trick | Lv8 | Leaves a final challenge at the castle |
| 99 | Mixed-color storm; all the learned tricks combine in the last rematch | Lv9 | Returns the compass and admits defeat |

Only the next **ordinary future** Boss is marked on the map. Every already-unlocked
Boss stage retains its marker for rematches; later locked Boss locations are
not all revealed. The finale at stage 99 is an intentional exception: an enlarged
actual Bramble portrait, dark-purple sourced rays and extra summit space make
the final opponent visible and imposing without horror art. Its locked marker
cannot start the stage. Stage 1 remains unmarked to preserve its surprise.
Boss markers use Bramble's actual portrait rather than a `BOSS` text
badge; the face can open its unlocked stage without covering the number or
earned stars. Both the map and active board show a separate acquired-Jelly
**Jelly LvN** badge for the unlocked merged-level cap, not Pip's level or chest tier.
The eight encounter identities remain stable after this schedule change, so
previously earned levels remain earned. A pending old-roster victory can still
finish its original journal; newly authored settlements identify the new roster.

Bramble's full acquired, skinned body stands beside the well throughout battle
and the ending; it never moves into an information bar or a giant story dialog.
Game-authored bent-arm gestures, attacks and grounded reactions make him a
visible opponent. Eight sourced purple energy glints and draining local light
represent his health; there is no permanent name/instruction block or numeric HP
rail. Taunts use bounded two-line subtitles. The ambush enters from the edge,
and every retreat leaves from that same side-standing position.
The acquired Word Compass remains visibly in his possession during battle.
After the ambush, the map names the next real Boss stage; wider layouts also
name its first-win Jelly-level unlock, never an already-earned duplicate reward.
Short, trick-specific challenges and an admitted defeat replace generic banter.

A distinct Boss first victory also presents **New skill unlocked** in settlement,
with the earned Jelly, its level, the exact collection footprint and a view-only
illustrated demonstration. Continue becomes available after the initial reveal,
so held input cannot skip the explanation. Rematches do not show another unlock;
the pending victory journal retains ownership of the earned level.

**Attacking:** a successfully committed merged-word collection fires an attack.
Lv1 already deals 14 base damage; Lv2–Lv9 deal 38, 72, 116, 176, 248, 344, 464
and 620. Manual construction charges the next shot, and an active combo adds
damage. A pending/failed save and duplicate acknowledgement cannot fire another
attack. Automatic construction still earns no learning by itself; collecting
its completed word uses the normal learning rules and can attack. Boss stages
require **both** Bramble's defeat and every fixed word quota. Finishing only one
cannot announce a clear or grant a level. If Bramble is defeated first, he stays
exhausted beside the board with no attacks, victory speech or retreat while
the remaining word goals continue. Reviewed partners remain available when
all words are done first but the Boss still needs hits.
The visible attack takes 550 ms to reach Bramble. Its hit cue, skeletal response,
small planted recoil and 240 ms energy depletion share that contact boundary.
The authoritative collection receipt and damage still commit at collection;
the presentation does not defer a save or grant a second hit. Decoys and shields
name their blocked impact instead of showing a misleading zero-damage number.
Reduced motion presents the real hit immediately without travel or recoil.

**Counterplay:** attacks have a visible wind-up and distinct blue, purple and
golden projectiles. Their paths use a fixed launch/landing position and a
gravity-shaped arc. Moving a targeted body, holding it, or accepting an operation
before impact makes an obsolete shot miss rather than hit a different word.

- Blue freeze prevents selection, dragging, matching and collection for exactly
  three active-play seconds. A clock/progress effect counts down; a sourced
  thaw burst restores the original body and its contents.
- Purple ink obscures the picture and spelling for five active-play seconds.
  It changes only presentation, not identity, legal matching, rewards or
  collection. It never changes the underlying learning answer.
- Golden locks cap at two. One and two padlocks have distinct visible markers.
  Dragging either legal matching direction removes one lock from each locked
  participant without consuming the pair, scoring a merge, paying combo coins or
  recording learning. The next gesture after the last lock performs the real
  merge. Invalid matches cannot unlock a body; a third lock does nothing.
- The giant kick is telegraphed before impact. Its damaged sky dispatches at most
  two actual bodies per requested or automatic batch for eight active seconds.
  Advertised waiting partners are retained. The ordinary five-slot supply
  returns at the exact boundary with repair feedback.
- Snatch avoids held, fusing and promised bodies and does not confiscate completed
  merged words. The grabbed piece visibly leaves the screen, then returns to
  the head of the ordinary supply with its original identity and fragments.
  It cannot orphan its spelling/picture partner or manufacture learning credit.

Manual pause, hidden pages, pending saves and automatic operation ownership keep
combat/status clocks consistent with the existing active-play rules. Reduced
motion retains readable targeting/status marks without leaps, spins or particle
travel. Freeze and lock state is cleared for the already-established terminal
collection sweep, so the final overlay cannot strand a remaining merged word.

On a loss, Bramble taunts and leaves a renewed challenge. On a win, Pip celebrates,
the characters exchange a short readable reply, and Bramble's escape uses its
encounter's scramble, distraction, swagger or panic style. His final defeat
returns the compass. These performances finish before the ordinary Round
complete/settlement sequence; rewards still use their original saved receipts.
The decisive impact explicitly announces Bramble's defeat; he does not resume a
smug taunt immediately after losing. His concession and Pip's next-stage pursuit
occupy separate short beats. The finale admits defeat and visibly returns the
same compass; its larger theft/return framing uses the original acquired art.
The vocal reaction is an acquired human laugh with subtitle dialogue, not a
claim that every written line has a corresponding spoken recording.

Every **first** Boss victory unlocks one further merged level after durable
settlement. Replays pay their existing clear reward but never farm new levels.
Unlocks follow the same Everyday/professional-module context separation as the
journey. Version-one saves migrate without resetting recipes, stars, pending
settlements or progress, and without inventing Boss wins for old ordinary clears.
Players may revisit those unlocked stages to earn their new Boss medals.
See [Bramble's source and animation record](../assets/jelly-boss/SOURCE.md).

Stage 1 has three word goals, adding one per stage up to eight. Each attempt
starts its counters at zero, separately from Pip's permanent three-answer
mastery. A committed **LvN** collection contributes **N goal units**, including
**Auto Collect** and a later collection of a word constructed by automatic
matching. Quotas clamp at their required amount; overflow does not skip a later
Challenge batch. The pickup, wallet receipt and learning attempt still happen
only once. Merely merging
does not fill a collection goal. Words whose quota is satisfied stop creating
new packets, but already issued roots, pictures and queued partners remain
available: retiring a word must never strand an old piece.

Difficulty follows a nine-stage wave: Discover, Practice, Build, Breather, Mix,
Flow, Reward, Prepare and Finale. Chapter quotas gradually grow from one to six,
with selected extra repetitions and chapter finales. Breather and Reward stages
give more room instead of increasing pressure every time. Time budgets account
for each reviewed word's real parts, picture matching and supply throughput;
they are not a fixed subtraction from the preceding stage.

The countdown has three star phases based on the **original active-play budget**:
clearing before its first third earns three stars, before its second third earns
two, and later earns one. Pauses, reading overlays, automatic sequences and
pending saves do not consume active time. **+30 sec** costs 100 coins, then 150,
200, 250 and so on per attempt; a saved purchase extends the deadline but never
restores an expired star tier. Remaining time fills the progress background,
with a right-aligned clock and larger acquired rating stars; the current Stage
moves into the top game heading. Crossing a star boundary produces a short sourced sparkle and fading
star rather than silently changing the rating. Reduced motion updates it still.
A saved extension refills the remaining-time bar independently of the rating:
the bar uses remaining seconds, while lost stars stay lost.
A failed or duplicate purchase cannot charge twice.

Completing every goal locks a clear; timer expiry locks a failure. A settled,
blocked top starts the original **ten-second flashing warning**, not an immediate
failure. Clearing space cancels that warning; pause and automatic/pending
transactions freeze it. Its expiry locks a failure. The remaining merged words are then automatically
collected; these cleanup pickups cannot change the locked goals, outcome or
star rating. Existing reward/save rules apply, with Retry saving on failure.
The same sourced frame warns during the final ten seconds of a stage deadline,
even on a non-full board. If both warnings apply, the more urgent clock owns one
frame rather than stacking flashes. Added time above ten seconds clears the
deadline warning without changing the saved star thresholds.
After a genuine clear, the board first runs at 0.12 speed for 350 ms, then shows
the clear notice and cheer for one second. Only afterward does it automatically
collect leftover merged Jellies, including their high-level impact freezes.
Settlement waits for the full sweep and its board bursts, reading tails and
treasure feedback. It does not repeat a second late clear announcement.
Failure keeps its separate Game over handoff after safe cleanup.
Treasure opening and arrival-driven coins then finish
automatically, then the game saves the clear and returns to the map. A pending
settlement survives reload and is recovered with its original receipt.
Any older retained treasure is settled with its original quote before returning;
it is not counted again in this attempt's star multiplier.
Settlement lights earned stars one by one, shows the base-and-star multiplication,
and animates stars toward the clear-coin count before those saved coins fly to
the wallet. Refreshes, retries and background interruptions cannot replay payment.

The in-game **Home** action asks before leaving a live campaign. Keep playing
resumes the same attempt; Exit runs the normal merged-word sweep and settlement,
then returns Home only after saving succeeds. Entering Jelly Words again opens
its stage map rather than resuming the abandoned board.

The separate **Survival Challenge** starts with 90 seconds and ends in Game over
at zero. It has its own stages, not numbered campaign clears or star bonuses.
Stage 1 has a batch of up to three word targets, each requiring one committed
collection. **All** targets must be completed before the next stage begins.
Later stages add target variety up to sixteen and raise each target's quota
every two early stages. After the variety limit is reached, each subsequent
stage raises the quota, so difficulty still increases after the speed caps.
Stages also increase actual fall speed and supply pressure toward the established
2.2-speed and three-second limits.
Each newly completed target grants ten seconds, capped at 90 remaining seconds.
There are no random extra-time drops or paid Challenge time purchases.
Pending/failed/duplicate collection receipts cannot grant time or advance a stage.
The top heading names **Challenge** and its current Stage. The timer and target
counts remain visible; historical **Best Stage** is an acquired medal and a warm
numeric badge, not a second title or a `Goals +10s` explanation. A newly saved
record gives its number a short old-to-new lift, glow and sparkle response.
Each positive committed time award has a separate 1.6-second clock-side badge
showing the actual added duration, including fractional headroom below the
90-second cap. Close awards combine their real amounts in the same badge.
The sourced clock/light accents and one short digit response do not launch
confetti or change the timer. Pause freezes the feedback; reduced motion keeps
its amount and static highlight.
Each completed target batch launches the shared smaller sourced-paper preset
once, without stopping play. The best is saved when a higher
stage is reached, separately per learning route; a lower replay cannot overwrite it.
Version-three campaign saves read versions one and two without inventing a
Challenge record or resetting existing stars, recipes or Boss victories.
Pause, input interruptions and automatic collection preserve the active clock.
Challenge can also end on a blocked top or intentional Finish and retains the
existing combo, rare-collection and chest coins without unlocking a campaign stage.

After Game over, Challenge stays on its result summary until the player chooses
**Back to map** or **Try again**. Both are still, separately readable actions:
Try again is primary and starts a fresh Stage 1 Challenge in the same learning
route with 90 seconds; Back to map leaves the saved result. Neither breathes,
scales or cycles idle sparkles. It shows the reached Stage, level-weighted
active collection total and saved record medal. The comparison freezes the old
best before the first eager save of the run: saving the reached Stage early
cannot suppress a genuine breakthrough. A new best adds the numeric medal
animation and one reduced-count paper celebration after durable settlement.
Lower or tied records do not replay it. Save failure exposes Retry save and
keeps returning disabled; refreshes and retries do not restart an announced award.
Reduced motion retains the medal, exact number and static return highlight.
The acquired medal and actual digit widths share one centered award group.
Paper retains its established count, sizes, paths and lifetime but renders behind
the Challenge dialog's reading window rather than over its result or actions.

Illustrated goal cards use proportional green background fill. Each saved
increase has a small card-local number/art pop; a newly completed item instead
draws only its check, with golden sparkle and one confirmation sound.
It silently waits three active seconds before exiting; reloaded completed items
do not replay the celebration or reappear. Desktop retains exact fractions for
pending goals; compact campaign chips omit numbers, while Challenge chips retain
their stage-specific target counts. The same live scroll component
clears only its cross-axis minimum when resized, preserving both gutter bounds
and a genuine scroll range.

Paying combo merges launch their earned coins from the gold **COMBO BONUS**
display into the header wallet. Its saved total is authoritative immediately,
but the displayed number rolls upward only as each coin arrives. One to three
acquired sprites represent the exact bonus; manual pause freezes the flight and
number roll. Save retries cannot duplicate the reward or its presentation.

Join reviewed roots on a five-column, eight-row board, then match the complete
spelling with its separate picture. Positional hyphens show the missing sides: `un-`,
`-believe-`, and `-able`. Roots follow their authored composition and spelling
changes; arbitrary letter chunks are not accepted. An atomic word such as
`cat` starts as one whole-word root plus a picture-only Jelly. Pictures match
the exact vocabulary meaning in either drag direction. A word without a picture
becomes merged as soon as its spelling is complete. Invalid combinations separate
with elastic feedback and a negative sound, without creating a merged body.

Merged Jellies show the word and its available picture, with a brighter rim and
glints. New Jelly World journeys start with only Lv1 unlocked. Two merged
Jellies of the same word add their levels, including different levels; the result
clamps to the currently unlocked Boss-earned cap rather than rejecting an overflow.
With Lv4 unlocked, Lv2 + Lv3 produces Lv4 in either direction, manually or through
Auto merge. All input mass and carried fragments survive the clamp.
For example, Lv2 plus Lv7 and Lv7 plus Lv5 both produce
Lv9; all input fragments and mass survive. Levels 2–9 have an upper-right numeral.
Each of the nine levels has a distinct collection effect and sound. Board
Lv4–9 pickups use a compact, short outward burst without falling embers; their
separate top popovers retain the larger firework and falling tails. Every board and top-popover
firework layer originates at that Jelly's own center, never an unrelated screen
position. Larger levels retain broader, denser radial layers without changing
the existing nine collection recordings or adding a separate popover sound.
An incoming matching Jelly can also be dropped onto a result still merging:
the accepted first union hands off into the next animation using the existing
drag handoff, rather than rejecting the result until its old animation ends.
Semantic checks, failed combo saves and generation guards still protect every input.
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

Both Jelly modes have a Pause control in the header. Pause, or P on a keyboard,
switches that same control to Resume and freezes supply, danger, combo and automatic matching
clocks. Resume continues the same round; Escape or controller Back also resumes.
Returning from a hidden tab does not dismiss an explicit pause. Active word
popovers and marking effects keep their paused age instead of being deleted.

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

Jelly World's Boss-progression rules strengthen the early support footprint:
Lv1 marks **two** adjacent bodies, Lv2 four, Lv3 six, and Lv4 the complete
one-cell ring. Lv5 retains its column identity and Lv6 its cross; Lv7 adds up
to four outer-ring bodies to the full inner ring, Lv8 retains its capped two
rings, and Lv9 retains the board. Frozen/locked/reserved bodies are not consumed
by a paid or automatic matching plan. The older unbound model reference above
remains for compatibility tests; active campaign/challenge play uses these
stronger footprints. Coin odds and immutable wallet quotes are unchanged.

Edges clip the footprint; absent neighbors are not replaced by distant bodies.
Random selection does not favor bodies with a match and uses a separate stream
from word supply and coin rolls. Held, already fusing and promised batch
collection bodies are protected.

After collection commits, a blast with affected bodies first holds the world
still for 100 ms, then slows board motion, animated word art and garden light to
0.12 speed without darkening the well. The sourced energy remains centered on
the collected body. A 180 ms source windup releases accelerating light
with dense, tapered trails; each group travels for 420 ms on an independent
real-time clock. The complete marking interval lasts 600-900 ms.
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
that flies toward its left-hand root. Identical words add levels with the output
capped at Lv9. Unmatched marks fade without consuming a body or inventing a
word. All carried fragments survive the automatic union.

The free sequence reuses the automatic matching flight, fusion and settling
clock; it never purchases an item or increases its repeat price. It does not
collect its results or make an automatic combo coin payment. Each committed
automatic match does extend the combo; collecting the resulting word later
records its normal collection learning evidence. Results retain their original
assisted-construction metadata. Batch
Collect finishes its captured pickups first, then coalesces overlapping blast
marks into one bounded sequence so two explosions cannot consume the same
endpoint twice. Failed collection saves do not trigger a blast; retry retains
the original outcome and receipt. Pause freezes marks and flights, while leaving
the round clears queued reactions and settles active automatic matching without
collecting their results.
High-level **Lv4-Lv9 Auto Collect** pickups independently hold the board for
100 ms at their actual 40 ms release, even if every other Jelly is reserved for
the batch or no later chain target exists. This impact is not deferred to the
end-of-batch chain. Each pickup retains its 120 ms motion beat plus that hold;
Lv1-Lv3 stay unchanged. Board effects, reading art and ambient motion use the
model's actual consumed motion segments, so a coarse frame cannot skip the freeze.
The interface/audio keep their own clocks and `Engine.time_scale` remains one.

Auto merge costs 600, 900, then 1200 coins for further uses in the same round;
Treasure costs 200, 300, then 400. Each item has its own successful-use count,
and its button displays the next price. Treasure still distributes 2–8 fragments;
Auto merge follows validated paths of root joins, picture matches and
same-word upgrades whose output is capped at nine. It launches an eligible
pair every 100 ms, while each 320 ms flight stays visibly in motion. Three
independent paths can all be traveling before the first contact; a fuller board
can have four staggered flights at once.
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
words at 120 ms intervals without pronunciation. Each Auto Merge takes 320 ms
to fly, 110 ms to fuse, and 30 ms to settle. Its 100 ms launch interval runs
independently of that 320 ms sequence.
Each reveal has its own randomly varied position and size, fits its picture and
spelling, and enters with elastic squash and stretch. Successive reveals coexist
and fade independently instead of replacing one another. They do not intercept
board input. Pauses freeze them; normal campaign completion waits for their tails
instead of clearing them early. Reduced motion keeps
the picture and spelling steady.

The numbered campaign uses current learning-age or ready-module vocabulary,
favoring words still being practised. Earlier recipes rebind their exact saved
words instead of silently changing a replay. Stage-clear confetti is restrained
to the upper third of the screen with 24–72 papers and a short tail; it does not
cover the whole well. Unsuccessful saves cannot unlock or celebrate another stage.

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
