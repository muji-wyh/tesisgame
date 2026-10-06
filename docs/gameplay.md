# Gameplay reference

This is the detailed current gameplay reference. Start with the
[project README](../README.md) for setup and the [documentation index](README.md)
for implementation and asset references.

The game uses a shared warm paper palette, bundled Nunito typography, and compact
icon actions. Pip and the current mode title open an illustrated game library.
Each choice explains its core action and whether it uses a microphone. The library
pauses play without changing progress, and Back, Escape, or an outside tap returns
to the current round. It also exposes saved sound and motion preferences; motion
follows the system until the player makes an explicit choice. These preferences
also apply to the loading screen on the next visit. Match and Memory
keep the cards as the main focus. Pip and the success/mistake indicators form one compact status cluster;
Memory's marked pairs retain their progress. Card positions stay fixed
through feedback. Main actions have filled buttons; secondary navigation stays quiet.
The header keeps the playfield clear of persistent mode tabs.

**More** opens **Pip's room**, with an icon to return. Age choices stay at the top,
toys stay at the bottom, and the world strip sits
just above the toys. Each strip scrolls horizontally without a visible scrollbar.
Pip's playground fills the remaining space; the page itself never scrolls.
The room has perspective side walls, timber flooring, an inset window with a
themed outdoor view, soft daylight, and contact shadows under Pip and the toys.
Its architecture redraws on resize or a world change; play effects remain separate.
Choosing a world keeps the current page open while changing the
look and sound, without resetting the game, selection, or hints. An unsaved change
shows an in-page retry notice. Locked toy cards show gift progress below the room.
Results keep the chest, word review, and the next action without game-mode
controls. Keyboard and controller focus remains visible across the available games.

Scrollable lists and strips retain momentum after a swipe or mouse drag and
settle gradually. Mouse-wheel scrolling also eases to a stop. This applies to
age vocabulary, the age/world/toy strips, Voice Pop results
and microphone prompts, player lists and leaderboards. Touching a moving list stops it without activating a card;
a stationary tap then selects the item. Keyboard and controller navigation
stop momentum and reveal the focused control. Scrollbar rails stay hidden.
Loading, speech diagnostics, live captions, and art credits use the browser's
native touch momentum. Pip's playground remains fixed.

**Pip the duck** is the game's round, wide-eyed companion. He appears on the
loading screen, board, results, playroom, and voice panel.
The upper-left Pip opens the game-mode menu. In his room and other companion
views, tap him to cycle through a dance, a crunchy carrot snack, a bubble party,
a high five, peekaboo, and a fluttering hello; he also reacts to selections, matches, hints,
season changes, and rewards. These reactions never change scoring or saved progress.

Pip has a complete outfit for each world, with both a hat and clothing:

| World | Pip's outfit |
|---|---|
| Spring | Flowered straw hat and green overalls. |
| Summer | Coral cap and aqua striped shirt. |
| Autumn | Leaf beret, knitted top and golden scarf. |
| Winter | Bobble hat, blue coat and warm scarf. |
| Ocean | Sailor cap and sailor suit. |
| Space | Clear helmet and a spacesuit with a control panel. |
| Jungle | Safari hat and a pocketed explorer vest. |
| Candy | Chef's hat and pink apron over a mint shirt. |

The outfit follows the selected world.
The same wardrobe appears in Pip's speaking poses, quiet gestures and dances,
with hats following his head and clothes following his body. Dressing Pip does
not require a purchase or a new reward. The loading and voice companions use
the same themed artwork, and the loader reads the saved world when available.

Start in **Match**, with the matching board ready.
Tap a word and its matching picture; completed cards remain available for pronunciation.
Completed pairs share a numbered, colored badge on both cards. Every completed
pair keeps its smooth connection until the round ends. The latest pair has a
stronger line; tap either completed card to emphasize its partner and connection
while hearing the word again. Earlier connections remain visible. Stable routes
and light outlines separate crossings between the card groups. The curves adapt
to portrait and landscape and clear with a new round; incorrect pairs never
receive a connection.
Use the arrow keys or Xbox D-pad/left stick to focus a card, and **Enter**,
**Space**, or Xbox **A** to activate it.
Six pictures also have short, noun-specific play reactions: the ball hops, bell
swings, rocket lifts, fish swims, boat rocks, and flower grows. Tap or use the
existing keyboard/controller activation to replay them. The written word and
input target stay still; new input cancels old motion, and nothing is queued.
These reactions also work without sound. Reduced motion keeps the original
static picture and normal pronunciation instead.
Tap the upper-left Pip to choose **Match**, **Memory**, or **Voice Pop**. The current mode is marked in the library. Selecting a mode
closes the menu; selecting the current mode keeps the round. Tap outside or use
Escape / controller Back to dismiss it. Entry and reload select Match.

### Voice Pop

Voice Pop is a single-player game using the system speech service exposed by
`SpeechRecognition` or `webkitSpeechRecognition`. Before each round, tap the
player's avatar or name to start; no voice enrollment is required. The menu's
**Players** entry manages up to ten local names and emoji avatars. First-time
entry from the loading screen requires creating one player. See
[local players and leaderboards](local-leaderboards.md) for attribution,
ranking rules, and save recovery.

Select a player in Voice Pop to request speech permission. The initial 50-second clock starts only when
the microphone is listening. A narrow peach/pink and blue/violet glow follows the
screen edges, meets at right-angle corners and diffuses softly inward.
Illustrated word capsules fly up in gentle arcs, with occasional volleys of two
or three words. Capsules follow their own flight paths and can pass through one
another without collision or deflection. Say the English name
of a visible object to pop it with a slash, shards, and a shockwave. Words always
appear with their matching pictures and follow the age level chosen in More.
The HUD shows recognized speech as it changes, including interim speech and words
that do not score. Long sentences keep their newest two lines in view. Pausing,
finishing or leaving clears that text.

Ordinary browser recognition does not set contextual phrases. The optional
on-device experiment uses the round vocabulary and stronger live-target hints
only when the browser supports them. Voice Pop displays interim text immediately;
a word must remain stable for 150 ms to score, while a final result can score
immediately. Only the top recognition alternative can score. An observed
candidate remains bound to the targets visible at its first callback, so later
revisions cannot hit a replacement card. Recognized text still needs to match
a target. The game accepts a small, explicit set of
homophones: sun/son, flower/flour, pear/pair and plane/plain, including their
regular plurals. Similar spellings and arbitrary partial words are not accepted.

The live caption distinguishes unclear speech and words that do not match a
current target. These messages do not pause the clock or
award points. Browsers do not supply reliable word timestamps, so late results
still need a current target when received. No accuracy percentage is implied by
these safeguards.

Hits earn 10 points, plus 2 for each step of the current combo (up to 10 bonus
points). The second hit in a streak adds 3 seconds to the clock; the third adds
5 seconds. Each award displays a large gold **+3s / +5s** time-bonus badge above
the flying cards, with a burst, particles flowing into the clock and a timer
pulse. The 1.8-second effect becomes a static badge in reduced motion. Dropped
objects end the streak, so a later streak can earn these bonuses again.
There is no losing screen. When the extended clock runs out,
the result view shows the selected player's avatar and name beside **HITS**,
**Play again**, a compact leaderboard, and lists of popped and missed words.
The finished score is attributed automatically to the player selected before
the round, with a short success cue confirming the save. A rank improvement
animates that player's row upward. The hit total
counts up, settles with a brief scale pulse and
sparkles, and keeps a gentle glow. Reduced motion shows the complete total
immediately with a static glow. Score and combo statistics remain
in the game model but are not displayed on this page.

Tap a word to replay its recorded pronunciation; cards show the picture and word
without a repetition count. The result view scrolls by touch, wheel and keyboard
focus without showing a scrollbar. It has no Pip report or automatic narration.
The retired report subsystem and its recordings are no longer shipped;
its [provenance record](assets/pop-voice.md) remains historical.

Microphone denial, missing hardware, or speech-service errors show a retry action.
More, backgrounding, and recognition interruptions pause the current round; Resume
continues it without resetting the score. Leaving the mode or finishing stops
recognition. Browser speech can process audio remotely; the game does not save
recordings or transcripts. Voice Pop needs a secure browser with SpeechRecognition
or webkitSpeechRecognition support and an available speech service.
Unsupported devices show an explanation and a way back to Match.
Reduced motion keeps a static edge glow and simpler hit feedback.

Crossing 100, 200, or 300 points earns one chest opportunity, up to three per
round, with a visible award effect. **Open chests (N)** on the result page shows
all earned chests together in different styles. Their hold-to-open interaction
matches Match mode, and unopened rewards survive leaving or reloading. See
[Voice Pop treasure](voice-pop-treasure.md) for persistence and the shared catalog.

### Match and Memory

Switch between Match and Memory to practise the same lesson.
Sky and Listen have been removed. Match uses a ten-card, five-pair puzzle.
Correct and wrong feedback stays on the cards and clears automatically after a short
pause; there is no footer or extra confirmation step. Selecting the next unmatched
card continues immediately. Tap any card, including a completed pair, to hear its
word again without changing the score. Each winning round advances saved gift progress once.
Correct Match feedback repeats the matched noun rather than a generic praise
clip. Completing or replaying either half of one of the six playful pairs also
reacts on its picture partner, with no extra score or reward. Microphone mode
continues to suppress game audio. Memory retains its existing noun speech and
card flips without a competing picture animation.
**Memory** plants a garden by finding five hidden word-picture pairs among ten cards.
Card backs are themed illustrated tiles: large **Aa** lettering for words,
and a drawn photo icon for pictures, with smaller kind captions and corner
numbers. Their colors depend only on the theme and kind, never on the hidden
word or its matching partner. **Hold the eye icon** to flip every card
face up; release it to hide only unmatched cards. Correct pairs keep their word and
picture face up with a green checkmark for the rest of the round. Peeking never resets
progress. Keyboard players can hold Space or Enter; Xbox players
can hold A on the eye. Feedback stays on the board and clears automatically,
without a bottom panel. There is no countdown or three-mistake loss, and exploratory
misses do not enter the missed-word list. Completing
all five pairs opens the normal chest for one saved step of gift progress.
**New adventure** appears only after the chest opens and its reward saves.
It floats at the bottom-right without reserving space or moving the chest.
**Repeat lesson** has been removed.
**Retry saving** appears only if reward storage needs recovery, without restarting play.
**New adventure** on
results starts a fresh Match game with five vocabulary words. The manual Explore
picker has been removed. Existing room choices, world preferences, and journey
metadata are preserved; a failed write keeps play available and offers
**Retry saving** in the header without resetting the current word.
The result word strip has been removed. The chest fills the result area before,
during and after opening. Save recovery uses a floating **Retry saving** button
and a visible status message, preserving the same chest framing.

The **Medals** page, tab, and reward preview have been removed. Ordinary chest
results show only the chest until the next action becomes available. Toy unlocks
are announced to assistive technology and can be selected from the playroom.
Chest rewards, piece progress, toy unlocks, and existing saves remain available.
More opens the playroom directly, with age choices at the top and worlds above
the bottom toy strip.

The eight worlds are **Spring**, **Summer**, **Autumn**, **Winter**, **Ocean**,
**Space**, **Jungle** and **Candy**. Their saved gift progress retains six reward
records per world, with 48 records in total.
The 350-word vocabulary spans 12 adventures, including ocean discovery, space trips,
garden trails, and music makers. Pictures are original SVG illustrations generated by
the existing local art pipeline, and every word has its own spoken recording.

Jungle and Candy retain these reward records for save compatibility:

| World | Saved reward records | Toy unlocked by its first completed record |
|---|---|---|
| Jungle | Monkey, Tree Frog, Tiger, Elephant, Bamboo, Waterfall. | Jungle monkey. |
| Candy | Party Cake, Cookie, Lollipop, Wrapped Candy, Ice Cream, Candy Castle. | Candy cake. |

Existing medal IDs, completed pieces and earlier rewards are retained when these
worlds are added; their reward progress begins empty in an existing save.

Open **More** to visit **Pip's playroom**. A ball is playable immediately.
The first three saved chest rewards in each world unlock its toy, making nine toys including
the starter ball. Every earned toy appears directly on the floor of **Pip's home**.
Tap a toy to play with it immediately; choosing a different toy starts its first
step in that same tap. Drag any earned toy to toss it to Pip. The other toys stay
visible and playable. Only toys you
have not earned remain in the cards below the room, with their exact requirements.
Newly earned toys move into the home automatically, and the lower list disappears
when all nine are owned. Locked cards use their own world colors and show the
illustration beside the name and progress in one horizontal strip.
Previewing a locked gift keeps the equipped toy and all earned pieces intact.
The Rooms/backdrop chooser has been removed. Existing saved backgrounds remain
intact and continue to render; they are not advertised as new gifts or goals.
The room canvas stays fixed while the age, world, and locked-toy strips scroll
horizontally by touch, mouse drag, wheel, or keyboard focus without scrollbars.
A stationary floor tap still calls Pip; direct duck and unlocked-toy gestures
retain their play interactions. Pet Pip directly, tap Pip for a surprise, or drag a toy
to toss it. The locked toy cards stay at the bottom below the world strip, with no
separate shortcut buttons, step caption or toy action button. Tap the toy itself to
advance its three play steps and replay; keyboard and controller activation
work on the toy too. To leave a locked preview, choose a toy inside Pip's home.
Choose a locked toy to preview it without moving the page. Its card shows the
remaining pieces and an inline arrow to start or continue its adventure; there
is no separate **Help Pip get this** row. The arrow saves the goal and starts a
related five-word adventure in its reward world. The lesson includes the desired
toy's word. Match and Memory keep those same
five words; only normal wins and opened chests earn pieces. The goal caption shows
the chosen gift and remaining pieces, including its world if you switch away.
The locked card lets you continue the goal. Once earned, play with the toy in the
home, including after reload; completed gifts have no extra **Use toy** arrow.
If choosing a different toy cannot be saved, its play action waits and a short
message beside that toy offers a retry. Locked-card selection keeps scroll and
card positions stable; keyboard/controller focus reveals each toy or card.
An unopened or unsaved chest must be collected before starting a gift adventure.
An explicitly chosen gift lesson always includes its toy's noun, even when that
noun belongs to an older age level; the other four words respect the selected
age level. Ordinary lessons keep the full age filter.
Water a flower, roll a ball, offer an apple, ring a bell, listen to a shell, launch
a rocket, swing with the jungle monkey or decorate the candy cake with Pip.
Each toy has three steps you control, such as rolling, returning and catching
the ball or readying, igniting and launching the rocket. The monkey swings,
waves and gives a high five; the cake is set down, frosted and covered in sprinkles.
Every step shows and pronounces its noun; tap the toy after the last step to reset
for another round. Step feedback remains available to assistive technology.
Toy play is temporary and never grants extra medals. Reduced motion
shows each stage's static result. The next gift shows its name and
remaining pieces. Newly unlocked gifts become available in the playroom after the reward saves.
Previously saved favorite medals remain displayed in the playroom.
Toy, legacy backdrop, and favorite data save together immediately in browser storage, or in
`user://playroom-v2.cfg` in native builds. The earlier favorite is migrated, and medal
progress remains unchanged. Failed reads/writes show a retryable notice.

The Words album and word-sticker display have been removed. Existing saved word
fields remain intact for compatibility, but games no longer collect new stickers.
The compact world icons keep their full tooltip and accessibility names.

Card selections ripple and successful matches sparkle. Effects
are bounded and respect reduced motion; the same controls work with touch, keyboard, and Xbox.

Pip's beak follows the actual pronunciation/prompt player during word playback
and page transitions. Background music and sound effects do not make
him talk. During microphone
play he listens instead. Reduced motion uses static speaking/greeting poses.
After 6–9 seconds of inactivity in normal play, Pip may wave,
offer a high five, play peekaboo, look around, stretch, preen, hop or dance.
Small gestures last 1.8 seconds and dances last 3.2 seconds, followed by another
full quiet interval. Input, held pointers, Peek, speech and answer feedback take priority.
Invitations make no sound, change no status text, and never start recording,
spend hints or alter progress. They stop in previews, background tabs and with
reduced motion. Pip's touch target stays in place. In Pip's Home, the loading
page's 5.28-second dance starts automatically: left wing, right wing, then a
grounded hip sway. Tapping Pip replaces the dance with a jump, shy head scratch,
or playful bonk; each shuffled group of three contains every reaction once.
Pip accepts another tap only after the current action and call finish;
ignored taps are not queued. Stroking, walking and toy
play pause the dance, which resumes after a short quiet beat. Reduced motion
uses distinct static tap poses and disables automatic dancing.
Godot and the inline HTML mascot use the same wardrobe sources. The build embeds
the loader's themed poses and dance parts, so its companion needs no additional
image request.

Find five matching word/picture pairs among **ten cards**. Every word has a matching picture. The round finishes when every pair is matched, with unlimited retries. Clicking another card of the same kind changes the selection without a penalty. Clicking the selected card cancels it. Match has no correct-answer counter or mistake-limit badges. Matched cards stay available for pronunciation without changing completion.
Match and Memory use the right/wrong sound effects extracted from the supplied
reference video. Wrong answers have no spoken correction, and Pip reacts visually
without a duck call in either mode. Both sounds keep their natural tails when the
brief card feedback clears; a new selection, hint, or replay replaces the previous
answer sound. Muting, leaving the board, or hiding the page stops it.

Each round is a small **word adventure**: Animal friends, Picnic time, Great outdoors,
Dress up, On the move, Play time, At home, Head to toe, Ocean discovery, Space trip,
Garden trail, or Music makers. All five words on the matching board
belong to its topic. New adventure chooses a different available topic and fresh words.
Custom word lists with too few related words use a mixed Word explorers board; seeded
rounds remain reproducible. Changing the season keeps the current adventure.

After completing a round, the review shelf shows all five words.
Tap a word's picture, or focus it and press Enter/Xbox A, to hear it again and make Pip
react. These word buttons never spend a hint or grant another reward.

Free Unity Asset Store artwork is evaluated with the offline [Unity import pipeline](assets/unity-art.md).
Downloaded licensed packages and selected overrides stay out of this public repository;
the original SVG illustrations remain usable fallbacks. The tool validates paths,
selects PNGs, invokes Unity CLI, and verifies byte hashes before copying textures
into Godot. Food Icons Pack 1.0 was acquired through Unity's official workflow;
19 selected images were imported with the installed Unity CLI, verified as
transparent Sprites and deployed. Builds with these verified local overrides use
the selected PNGs; clean checkouts retain the original SVG fallbacks. See the
provenance record for selection, hashes and release evidence.

Use the **lightbulb icon** (or Xbox **X**) when you get stuck. An electric arc connects a real unmatched
picture and word directly, with a pulsing bright core, split lightning filaments, branching sparks and contact bursts;
its word is spoken. The bolt and hinted cards share the current world's colors and update immediately when the theme changes.
The connection follows the straight axis between both cards, including diagonal pairs. Hints follow your selected card when it has a
partner; otherwise they point to a complete pair. Each round has **three hints**, with no
score penalty. The icon's small badge shows how many remain, including zero; only a new
round restores all three.
Hint works directly from a correct or wrong answer's feedback while the round is
still playable; it dismisses that feedback and highlights the next unmatched pair.
Cancelling selection, completing a match, or changing seasons does not refill them. You
still tap both cards to make the match. Hints move focus to the next suggested card,
so keyboard and controller players can continue with **Enter** or **A**.

Correct matches make a small star burst. Match has no streak or score counter;
the matched cards show which pairs are complete. Reduced motion keeps a static
electric connection without moving particles.

Rounds start with a random **Spring**, **Summer**, **Autumn**, **Winter**, **Ocean**,
**Space**, **Jungle** or **Candy** theme until you choose one. Your chosen world is
remembered across lessons and reloads. The eight direct world icons in **More**
change the appearance, Pip's outfit and music without resetting progress; Xbox
LB/RB remain shortcuts during play. Motion follows the device or browser's
reduced-motion preference. Buttons, celebration colors, and reward icons follow
the same palette; Winter keeps dark outlines for readability.

The refreshed UI pairs green with blossom pink, coral with aqua, copper with
plum, ice blue with violet, teal with coral, space violet with gold, jungle green
with amber, and candy pink with mint. Room
walls and toy-card illustration backgrounds add color without reducing text
contrast. Existing word and reward artwork is retained; Jungle and Candy add
their own original reward illustrations.

Accepted Match, Memory and toy-card clicks give a short content press
and bounce. The button and grid never move, Memory retains its existing flip,
and the six noun-specific picture reactions still play. Repeated clicks replace
the animation; navigation, resizing and reduced motion settle it immediately.
Game-card taps also make a brief themed ripple and eight small sparkles.
Correct/wrong feedback keeps priority, and these visual effects never score
another answer or move a clickable target.

The vocabulary pool contains **350 illustrated English words** for parent-guided play.
Matching rounds use five different words on ten cards;
Memory uses those five words on ten cards. Tap a matching card to hear its pronunciation.

In **Match**, a two-column board puts all five pictures in the left column and
all five words in the right column. A two-row board puts all pictures in the top
row and all words in the bottom row. Each type keeps its shuffled order; matching
partners are not deliberately lined up. Resizing preserves the current round and hints.

Choose a vocabulary level using the four direct **Age** buttons in **More**:

| Choice | Words shown in the catalogue | Vocabulary for the next lesson |
|---|---|---|
| All | All 350 words. | All 350 words, without a difficulty preference; the default for new and existing saves. |
| Ages 4-6 | 148 basic picture words, such as cat, apple, ball, and rocket. | Basic words. |
| Ages 7-9 | 112 growing words, such as helmet, pumpkin, and puzzle. | Basic and growing words, with growing vocabulary preferred. |
| Ages 10+ | 90 advanced words, such as helicopter, astronaut, and xylophone. | All levels, with advanced vocabulary preferred. |

The latest expansion adds 50 nouns to each level: basic words such as lemon, tent,
and pencil; growing words such as butterfly, avocado, and backpack; and advanced
words such as chameleon, glacier, and microscope. Each has an original picture and
a prerecorded Ava Neural pronunciation using the approved sweet voice profile. The three levels contain 148 basic,
112 growing, and 90 advanced words. Each age catalogue contains only its own
level; lessons for higher ages retain earlier words for review.

Age ranges are **suggested vocabulary guides, not reading-age assessments or restrictions**.
Choose whichever level feels right; age selection does not collect a birthdate.
Local player names and avatars are separate from the vocabulary preference.
Every topic remains playable at every level, with earlier words available for review.
The choice is saved on this device and applies to the **next lesson**. Switching between
Match and Memory keeps the current five words and their active level. Changing
the age never resets a round, its hints, medal pieces, or toys. An unsuccessful save
keeps the confirmed selection and offers a visible tap-to-retry message.
Tapping any age, including the selected age, opens its complete illustrated
vocabulary across every topic in alphabetical order. Ages 7-9 excludes basic
words, and Ages 10+ excludes basic and growing words. All includes every level.
The heading shows the word
count. Tap a picture to hear its recorded pronunciation; swipe vertically or use
the mouse wheel to browse without a scrollbar. Keyboard and controller focus
reveal offscreen cards. The age choices remain at the top for switching lists.
Back returns to Pip's room, and Back again returns to the unchanged game.
The age row stays at the top even on short screens. Horizontal scrolling keeps
all four choices reachable.

The winning chest follows the selected theme and can be dragged inside its panel.
A short press compresses the lock or body immediately and releases with a 120 ms
return. The full performance lasts **5 seconds**. Keep holding through the initial
pressure and buildup until the lid releases and the light flashes, about **3.36
seconds** after pressing. You can then let go while the remaining **1.64 seconds**
of opening and settling finish automatically. Three stars and a progress arc fill through the buildup, completing
at the lid release. Phase text and percentages are available to screen readers
without a visible label. Five material beats begin 80 ms into the hold, followed
by fifteen opening beats. Their spacing tightens from 320 ms to a 60 ms roll,
with each strike driving a weighted recoil about the body's base. The contact
shadow grounds the chest while growing lid pressure and brighter seams make the
approaching release visible. A shared curve builds intensity early and continues
through confirmation without restarting. Material impacts retain their low body
as a quieter pressure texture rises and background music recedes; the progress
stars add no competing clicks. Three strike textures add detail and brightness
as the rhythm tightens. The last roll brakes over 60 ms into a 160 ms loaded
hold with a quiet pressure bed; a subtle unlock precedes release. Release opens a broad theme-colored
bloom, seven beams and an outward light wave. The flash peaks within 45 ms and
fades over 1.02 seconds as the chest settles; the progress crown fades immediately
to make room for it. A compact material crack and low-mid impact load the base
into a tighter contact shadow while the lid accelerates upward. The lid or
facets meet a mechanical stop 420 ms after release, with a small, quickly damped
return synchronized to the contact sound. The body stays grounded, and rigid
themes retain their dimensions; Candy keeps its elastic deformation.
Each world keeps its own material motion and sound. The art fit stays
fixed throughout.
Releasing or dragging before the lid releases cancels immediately; a fresh press
interrupts the return and starts from zero. Once the lid releases, letting go
keeps its motion, light and sound running. Opening More or hiding the page cancels
an unreleased chest, or silently finishes one whose lid has already released.
Reduced motion keeps readable progress and shows the saved result directly after
the initial 1.2-second hold.
Browser accessibility exposes progress without repeated live announcements.
Changing worlds cannot reroll an opening or alter an earned fragment.

Chest sounds use a dedicated four-player pool. Entering a world preloads its eleven
short, original procedural Foley clips from the game pack; unavailable samples
use a small local fallback immediately. Skipping motion cannot replay missed cues.
The success accent plays only after persistence succeeds, once per reward.
Muting, backgrounding and leaving the result stop all chest channels.

Each win earns **one fragment**. **Three fragments complete a medal**, and each
season has **six medals**. The next piece always advances the first unfinished
medal in that season; there are no duplicate fragments or rare missing pieces.
These records support gift progress without a post-opening collectible display.
Ordinary chest results omit the victory title, instruction and word list. Hold
instructions and completion announcements remain accessible to screen readers.
The chest's local flash and twelve radial light streaks accompany release;
theme decorations remain around the chest. Save notices remain visible.
A newly unlocked toy is announced as **A gift for Pip!** and is available in the
playroom. There is no medal badge, piece assembly, tap-to-place action, toolbar
flight or larger medal-completion celebration. A complete season keeps its
saved progress when future chests open.

After opening, one random cosmetic gift flies out and fades. It has no album,
saved ownership, or effect on reward progress. Reduced motion shows a brief
still gift. [Chest feel](assets/chest-feel.md) documents the shared timing,
sound bank, theme treatments, and input-release boundary.

Rewards are saved before the opened result appears. Hiding the page cancels an
unreleased chest and silently saves an already released one. Explicitly starting a new round still settles the earned
claim once. Reduced motion shows the saved result immediately after its shorter hold.
If saving fails, **Retry saving** retries the same piece instead of rerolling,
pretending it was saved, or silently discarding it.

Earlier whole rewards are preserved in saved data: existing rewards 1-6 become
complete medals; earned rewards 7-10 retain
their IDs. Native versioned progress uses `user://medals.cfg`;
the old `user://rewards.cfg` is left unchanged. Corrupt or unsupported saves show
an error rather than being reset.

Web builds save medal progress immediately in browser storage so a quick reload
cannot lose a newly earned piece. Existing browser filesystem saves migrate on
load, while native builds retain the transactional `user://medals.cfg` save.

The three room strips follow horizontal drags without activating a choice on
release. Their scroll positions are independent, with no visible scrollbars or
whole-page scrolling. Keyboard and controller focus reveal offscreen choices.
Pip and earned toys remain inside the fixed playground during play and resizing.
A won reward is still revealed immediately after the required hold.

**New adventure** starts a fresh round, avoiding the previous board's words when at least
five unused words are available. Small vocabularies still produce a complete board;
explicit seeds remain reproducible. Audio starts with normal game interaction and stops on
hiding or reset; returning from a hidden page does not force autoplay. Match has no
failure screen: every board remains playable until all pairs are complete.

### Match voice play

On a supported browser, click the **filled microphone button** to start listening immediately;
click it again to stop.
Its white mic and listening waves stand out without enlarging the compact header.
Unavailable voice input stays visibly disabled with an explanation.
The compact panel shows the recognized text live, with a
larger Pip and animated listening bars. Pip sways while listening and nods, waves,
or tilts as words arrive; these are status
animations, not a measurement of microphone volume. Reduced motion keeps them
static. Only final
recognized words count, because interim text can change as recognition settles.
For example, **"I see a doll"** matches the doll word and picture if both are still
available on the board.

Matching is case-insensitive and uses whole English words: `doll` does not match
`dollars`. Distractors, unrelated speech, and already matched words do not score
or cost a mistake. A sentence containing several available words is resolved
through the same match-feedback sequence, once per pair.
Each accepted voice match plays the same sourced right sound as touch matching and connects its
picture and word with themed lightning for one second. Queued words receive
their own full second before the next match, including the last pair before
the result screen. Reduced motion uses a static bolt with the same duration.

Click **Voice** again to exit. Completing a board, replaying, opening a
playroom, or hiding the page also stops listening. Game music and spoken
prompts are quiet while voice mode is enabled so the game cannot match its own
audio. Touch matching remains available.

Voice play uses the browser's standard or prefixed `SpeechRecognition` API with
`en-US`; it needs browser support, a secure page, and microphone permission.
**Your browser's speech provider may process the audio remotely. This game does
not record or save microphone audio or transcripts.** The microphone starts only
from an explicit Voice activation, never on page load. Permission and service
errors are visible and never trigger an automatic permission-retry loop.
Turn Voice off and on to retry, or use the cards when speech is unavailable.
An embedding site must also allow `microphone` in its iframe permissions.

### Xbox controller

| Control | Action |
|---|---|
| D-pad / left stick | Move focus between available controls. |
| A | Activate the focused control; hold the eye to peek, or hold a chest until its lid releases. Let go before the lid releases to cancel. |
| B | Cancel the selected card, exit voice play, or go back. |
| X | Use one of the round's three hints and focus a card in the suggested pair. |
| LB / RB | Change the game season without restarting the round. |
| Y / Menu | Open or close More (Pip's room, world and age choices), preserving the game. |

Choose **New adventure** with A to start another round. Locked rewards are skipped during
navigation; completed Match cards remain available to hear again. Releasing A or
disconnecting also releases a held Memory eye. Releasing A early cancels an incomplete chest
charge; reconnecting retains the current round. A held on the loading toy must be released
before selecting a native game control. If the browser keeps controller-only audio muted,
tap or click the game once to enable sound.

Web and native playback both load audio directly from packaged Godot resources.
All sounds arrive with the initial game pack; decoded streams are cached for the
session. The browser caches the immutable game-pack URL between visits, and an
audio change gives the pack a new content hash. No runtime audio request or
temporary downloaded file is needed. Muting, page transitions and backgrounding
stop the appropriate players; resource failures cannot restart hidden music or
replace a newer word.
Returning to a visible game resumes only background music that was already playing;
cancelled words, Pip calls and reward sounds remain stopped. Background music stays
off in Voice Pop or while the microphone is active. The shell resumes Godot's existing audio context after a
browser interruption, with trusted pointer and keyboard gestures retrying if autoplay
policy blocks foreground recovery. No page refresh or extra sound toggle is required.
