# Pip and Words

A **Godot game delivered on the Web** for early English learners. Gameplay, cards, audio, chest animation and celebrations run in GDScript. The HTML shell hosts the exported engine and integrates browser sizing, accessibility announcements and lifecycle events.

Players need a browser, not a Godot installation. The game is a static website
with no game backend or external image service. Voice Pop is a single-player
game that uses the browser's system speech-recognition provider.

## Run and build

Development prerequisites: **Godot 4.7**, its matching **Web export templates**, and **Node.js 24**. The `godot` executable must be on PATH; alternatively, set `GODOT_BIN` to its executable path.

```powershell
npm ci
npm start
```

`npm start` imports the resources, exports Godot to Web, and serves the result at `http://127.0.0.1:41773`.

To build without starting a server:

```powershell
npm run build:web
```

The deliverable is **the entire `build\web` directory**. Keep its HTML, JavaScript, WebAssembly, PCK, audio-worklet, icon and `.br` files together. All music, speech and sound effects are inside the PCK. Deploy that directory to a static HTTPS host; do not deploy just the HTML file or open it using `file://`. The host must serve `.wasm` as `application/wasm`.

Speech recognition needs no model preparation or additional game download.
Rebuilding an older export removes its generated local speech models and retired
multiplayer and voice-profile scripts while preserving unrelated output files.

The build fingerprints engine files and the game pack independently, then generates Brotli
sidecars with Node's built-in compressor. Azure serves the compressed variants automatically;
uncompressed files remain available for other clients. Hashed assets can be cached for a year
without mixing old and new game versions, and game-only changes reuse the same engine URL.
HTML revalidates so returning players discover updates. Each build removes obsolete generated
asset names without deleting unrelated files in the output directory.

Chest and illustration textures use 85%-quality WebP imports at their existing resolution.
The original SVG/PNG artwork is unchanged. This reduces the game-pack download without
removing words, reducing the collection, or adding image requests during play.

The maintained HTML shell includes an inline, dependency-free treasure toy: tap it, wiggle
it sideways, use Enter/Space, or press Xbox A while the game downloads. The chest bounces,
peeks open, and makes stars, hearts or bubbles; every five taps brings a little star party.
Pip dances automatically: wing raises followed by grounded hip sways, including
while the ready screen waits for **Enter game**. His toes stay planted, heels rock
with the weight shift, and his upper body follows the waist with a slight delay.
Tap Pip or the chest to interrupt him
with a jump, a shy head scratch or a playful bonk and bounce back. The three
reactions appear in shuffled groups without consecutive repeats. Pip ignores
additional taps until both the current reaction and call finish, then resumes dancing.
A quiet original tune starts after the first interaction, with sound enabled by
default. Leaving the page stops both music and movement. Returning resumes the
dance, with music waiting for another interaction. Reduced motion stops automatic
dancing and gives each tap a distinct still pose and readable response.
Repeated taps do not show a browser highlight or select the caption, while keyboard focus
and pinch zoom remain available. It works before the engine script arrives and needs no
extra image, font or audio downloads, or device-motion permission. Effects are capped at 12 particles,
respect reduced motion, and stop when the page is hidden or loading ends. Controller
polling runs only while a connected controller can use the loading toy.
Sparkles are temporary loading-screen play, not saved collection rewards.

Engine and game-pack requests start together. A labeled **Startup estimate** moves
through **20%**, **50%**, **80%**, and **98%** as startup advances.
The last stage includes engine initialization; **100% is shown
only when the native game is ready**. Fast or cached starts do not wait for the
staged animation. A separate Game data line shows the real loaded byte counts.
Reduced motion uses milestone steps, hiding the page pauses pacing, and failed
downloads stop progress and show an English error with a retry button.

All audio is bundled in the startup **PCK alongside WASM**: word pronunciations,
game effects, Pip sounds, eight background tracks, ten game prompts, 51 legacy
Voice Pop report recordings and 88 themed chest cues. Once startup finishes,
playback needs no further audio downloads. The build opens the actual exported
PCK and loads the required audio resources to verify that they are present and
playable. Retired arrival and opening voice prompts remain excluded.

The Web preset uses Compatibility rendering, WebGL 2 and single-threaded export. It does not require SharedArrayBuffer, COOP/COEP headers, a service worker or cross-origin isolation. When updating a deployment, replace the complete export; do not rename hashed files or omit their `.br` sidecars.

To serve an existing export without rebuilding:

```powershell
npm run serve:web
```

For development in the editor, open `project.godot`. The maintained browser shell is `web\shell.html`; `build\web\index.html` is generated and should not be edited.

## Azure deployment

Production: `https://gentle-forest-02ff42900.3.azurestaticapps.net`

This uses a manual Azure Static Web Apps deployment: app `tesisgame`, Free tier,
resource group `rg-footises`, East Asia, in the **Visual Studio Enterprise
Subscription**.

With Azure CLI signed in and the Static Web Apps CLI (`swa`) installed, build and publish:

```powershell
npm run deploy
```

This runs `tools\deploy-web.ps1` with Windows PowerShell 5.1 or newer. The script
builds the Web export, explicitly selects the personal subscription
`2909b61b-7489-445e-9039-2fd51429745b` without changing your Azure CLI default,
confirms the production hostname, and keeps the deployment token in the process
environment only. Build, authentication, and deployment failures stop the command;
the previous token environment and working directory are restored afterward.
It does not commit or push Git changes.

To publish an export you have already built:

```powershell
npm run deploy -- -SkipBuild
```

`web\staticwebapp.config.json` supplies engine MIME types, immutable caching for hashed assets,
and `Cache-Control: no-cache` for HTML and other unversioned files. `Vary: Accept-Encoding`
keeps compressed and uncompressed responses distinct in caches. The build copies this
configuration into the export; the deployment script also explicitly selects the source
configuration. Omit `-SkipBuild` after changing source files or import settings.

## Embed in a website

Upload the export together under a path such as `/games/word-buddies/`, then embed it:

```html
<iframe
  src="/games/word-buddies/index.html"
  title="Pip and Words"
  allow="autoplay; fullscreen; gamepad; microphone"
  style="display:block;width:100%;height:100dvh;border:0">
</iframe>
```

Give the frame a usable size, with a minimum content dimension of 320 CSS pixels. The game follows its container, handles safe-area padding, and preserves the current round when resized. The standalone game has no page scrolling. Browser audio still begins with player interaction; the iframe permission does not bypass autoplay policy.

## Play

The game uses compact square icon actions and three small mode tabs, leaving the cards as the
main focus. Pip and the success/mistake indicators form one compact status cluster;
Memory's marked pairs retain their progress. Card positions stay fixed
through feedback. Main actions have filled buttons; secondary navigation stays quiet.
On wider screens the mode tabs share the header row.

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
Results keep the chest or bear, word review, and the next action without game-mode
controls. Keyboard and controller focus remains visible across the available games.

**Pip the duck** is the game's round, wide-eyed companion. He appears on the
loading screen, board, results, playroom, and voice panel.
Tap him to cycle through a dance, a crunchy carrot snack, a bubble party,
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

Start in **Match**, with its tab selected and the matching board ready.
Tap a word and its matching picture; completed cards remain available for pronunciation.
Use the arrow keys or Xbox D-pad/left stick to focus a card, and **Enter**,
**Space**, or Xbox **A** to activate it.
Six pictures also have short, noun-specific play reactions: the ball hops, bell
swings, rocket lifts, fish swims, boat rocks, and flower grows. Tap or use the
existing keyboard/controller activation to replay them. The written word and
input target stay still; new input cancels old motion, and nothing is queued.
These reactions also work without sound. Reduced motion keeps the original
static picture and normal pronunciation instead.
The tabs are ordered **Match**, **Memory**, **Voice Pop**; entry and reload select Match.

### Voice Pop

Voice Pop is a single-player game using the system speech service exposed by
`SpeechRecognition` or `webkitSpeechRecognition`. It starts directly without
a mode selection or voice enrollment.

Choose Voice Pop to request speech permission. The initial 50-second clock starts only when
the microphone is listening. A narrow peach/pink and blue/violet glow follows the
screen edges, meets at right-angle corners and diffuses softly inward.
Illustrated word capsules fly up in gentle arcs, with occasional volleys of two
or three words. Smaller collision boxes give the capsules more room to travel
together. Say the English name
of a visible object to pop it with a slash, shards, and a shockwave. Words always
appear with their matching pictures and follow the age level chosen in More.
The HUD shows recognized speech as it changes, including interim speech and words
that do not score. Long sentences keep their newest two lines in view. Pausing,
finishing or leaving clears that text.

Voice Pop supplies the round's age-appropriate vocabulary as recognition context.
It uses contextual phrases when the browser exposes that optional API; browsers
that lack or reject it continue with ordinary speech recognition. Recognized
text still needs to match a target. The game accepts a small, explicit set of
homophones: sun/son, flower/flour, pear/pair and plane/plain, including their
regular plurals. Similar spellings and arbitrary partial words are not accepted.

The live caption distinguishes unclear speech and words that do not match a
current target. These messages do not pause the clock or
award points. Browsers do not supply reliable word timestamps, so late results
still need a current target when received. No accuracy percentage is implied by
these safeguards.

Hits earn 10 points, plus 2 for each step of the current combo (up to 10 bonus
points). The second hit in a streak adds 3 seconds to the clock; the third adds
5 seconds. Dropped objects end the streak, so a later streak can earn these
bonuses again. There is no losing screen. When the extended clock runs out,
the result view shows only **HITS**, **Play again**, and lists of popped
and missed words. The hit total counts up, settles with a brief scale pulse and
sparkles, and keeps a gentle glow. Reduced motion shows the complete total
immediately with a static glow. Score, unique-word and combo statistics remain
in the game model but are not displayed on this page.

Tap a word to replay its recorded pronunciation; cards show the picture and word
without a repetition count. The result view scrolls by touch, wheel and keyboard
focus without showing a scrollbar. It has no Pip report or automatic narration.
The 51 legacy Jenny Neural report recordings remain in their existing asset
directory and startup pack, but the current result UI does not use them.

Microphone denial, missing hardware, or speech-service errors show a retry action.
More, backgrounding, and recognition interruptions pause the current round; Resume
continues it without resetting the score. Leaving the mode or finishing stops
recognition. Browser speech can process audio remotely; the game does not save
recordings or transcripts. Voice Pop needs a secure browser with SpeechRecognition
or webkitSpeechRecognition support and an available speech service.
Unsupported devices show an explanation and a way back to Match.
Reduced motion keeps a static edge glow and simpler hit feedback.
Switch between them to practise the same lesson.
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
**New adventure** is the normal result action; **Repeat lesson** has been removed.
**Retry saving** appears only if reward storage needs recovery, without restarting play.
**New adventure** on
results starts a fresh Match game with five vocabulary words. The manual Explore
picker has been removed. Existing room choices, world preferences, and journey
metadata are preserved; a failed write keeps play available and offers
**Retry saving** in the header without resetting the current word.
The result shelf reviews all five words, with missed words first. The row is
centered when it fits. Swipe or drag overflowing rows horizontally without a
scrollbar; a stationary tap replays a word.
Keyboard and controller focus still scroll the final word into view. Drags,
cancelled gestures, and multiple touches never trigger pronunciation or rewards.
Result actions stay compact and centered rather than stretching across the page.
Save retries and newly unlocked toy actions use the same styling.

The **Medals** page, tab, and reward preview have been removed. Ordinary chest
results show the chest, review cards and next action. A toy unlock shows
**A gift for Pip!** with **Try it with Pip**.
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
remaining pieces. Newly unlocked gifts offer **Try it with Pip** after the reward saves.
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
Rapid taps replace the current reaction immediately. Stroking, walking and toy
play pause the dance, which resumes after a short quiet beat. Reduced motion
uses distinct static tap poses and disables automatic dancing.
Godot and the inline HTML mascot use the same wardrobe sources. The build embeds
the loader's themed poses and dance parts, so its companion needs no additional
image request.

Find five matching word/picture pairs among **ten cards**. Every word has a matching picture. Five correct matches win; three mistakes end the round. Clicking another card of the same kind changes the selection without a penalty. Clicking the selected card cancels it. Illustrated green match badges and gentle coral mismatch badges show progress in the top-left. Matched cards stay available for pronunciation, not for scoring again.

Each round is a small **word adventure**: Animal friends, Picnic time, Great outdoors,
Dress up, On the move, Play time, At home, Head to toe, Ocean discovery, Space trip,
Garden trail, or Music makers. All five words on the matching board
belong to its topic. New adventure chooses a different available topic and fresh words.
Custom word lists with too few related words use a mixed Word explorers board; seeded
rounds remain reproducible. Changing the season keeps the current adventure.

After a round, the review shelf shows all five words, even if the round ended with mistakes.
Tap a word's picture, or focus it and press Enter/Xbox A, to hear it again and make Pip
react. These word buttons never spend a hint or grant another reward.

Free Unity Asset Store artwork is evaluated with the offline [Unity import pipeline](docs/assets/unity-art.md).
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

Correct matches now make small star bursts. Consecutive matches grow the celebration
and show **2 in a row!** or **3 in a row!** beside the match badges, without a countdown.
Mistakes reset the streak, not earned matches; hints do not break it. Reduced motion
keeps the encouragement and a static electric connection without moving particles.

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

| Choice | Vocabulary |
|---|---|
| All | All 350 words, without a difficulty preference; the default for new and existing saves. |
| Ages 4-6 | 148 basic picture words, such as cat, apple, ball, and rocket. |
| Ages 7-9 | 260 basic and growing words; growing vocabulary such as helmet, pumpkin, and puzzle is preferred. |
| Ages 10+ | All 350 words; advanced vocabulary such as helicopter, astronaut, and xylophone is preferred. |

The latest expansion adds 50 nouns to each level: basic words such as lemon, tent,
and pencil; growing words such as butterfly, avocado, and backpack; and advanced
words such as chameleon, glacier, and microscope. Each has an original picture and
a prerecorded Jenny Neural pronunciation. The three levels contain 148 basic,
112 growing, and 90 advanced words; higher ages retain earlier words for review.

Age ranges are **suggested vocabulary guides, not reading-age assessments or restrictions**.
Choose whichever level feels right; no birthdate, profile, or account is collected.
Every topic remains playable at every level, with earlier words available for review.
The choice is saved on this device and applies to the **next lesson**. Switching between
Match and Memory keeps the current five words and their active level. Changing
the age never resets a round, its hints, medal pieces, or toys. An unsuccessful save
keeps the confirmed selection and offers a visible tap-to-retry message.
The age row stays at the top even on short screens. Horizontal scrolling keeps
all four choices reachable without moving the playground or bottom strips.

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
as the rhythm tightens. The last roll flows into a continuous rising rush, while
the body keeps straining through unlock. Release opens a broad theme-colored
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
Ordinary chest results omit the victory title, instruction and review heading;
the cards sit directly below the chest when vertical space permits. Hold
instructions and completion announcements remain accessible to screen readers.
The chest's local flash and twelve radial light streaks accompany release;
theme decorations remain around the chest. Save notices remain visible.
A newly unlocked toy instead shows **A gift for Pip!** with **Try it with Pip**
directly. There is no medal badge, piece assembly, tap-to-place action, toolbar
flight or larger medal-completion celebration. A complete season keeps its
saved progress when future chests open.

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
hiding, loss or reset; returning from a hidden page does not force autoplay. The loss screen
uses the encouraging bear, a gentle effect and prerecorded English speech. Tap the bear
or focus it and press Xbox A for a happy wiggle, little hearts and rotating encouragement.
Bear play never restarts lost-round music or changes the result. Reduced motion keeps the
encouragement without movement, and New adventure remains the initial controller action.

### Voice play

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
Each accepted voice match plays a short bundled electric cue and connects its
picture and word with themed lightning for one second. Queued words receive
their own full second before the next match, including the last pair before
the result screen. Reduced motion uses a static bolt with the same duration.

Click **Voice** again to exit. Winning, losing, replaying, opening a
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

## Vocabulary and generated media

The visible game name is **Pip and Words**. The internal Godot project identity,
`wordBuddiesHost` API and `wordBuddies.*` storage keys remain unchanged so the
rename preserves existing native and browser saves.

`words.json` is the only vocabulary list. Keep at least five entries:

| Field | Purpose |
|---|---|
| `id` | Unique stable lowercase identifier. |
| `text` | Unique lowercase English word, 2-10 letters. |
| `image` | Unique local picture under `assets/images/words/`. |
| `audio` | Local pronunciation under `assets/audio/voice/`. |
| `level` | `basic`, `growing`, or `advanced`; explicitly authored for every catalogue entry. Older four-field callers default to `basic`; invalid supplied levels are rejected. |

The 350 word pictures live together in `assets\images\words`. Word/reward/bear SVGs, English prompt scripts and synthesized SFX were generated for this project. Prerecorded speech uses **Microsoft Jenny Neural (en-US)** with a warm, friendly delivery and a slightly slower pace. Azure Speech is used only to generate these source recordings; playback and ordinary builds need no speech credentials. Optional microphone recognition is a separate browser-provided service. All 350 word recordings, background music, active prompts and sound effects are included in the startup PCK.

Pip's original pose, idle-action and dance-part sheets are maintained under
`assets\images\mascots`. The regular sheet's four frames are idle, speaking,
blinking and waving. Editable hat and clothing layers for all eight worlds live
in `assets\images\mascots\outfits\wardrobe.svg`. Regenerate the 24 complete
costume sheets with `node tools\generate-pip-outfits.cjs`, or use `--check` to
check that committed sheets match their sources. Native `duck_mascot.gd` loads
the selected costume's pose, idle and dance sheets; the Web build embeds the
themed regular poses and dance parts for the loading and voice companions.

The collection keeps words to 2-10 lowercase letters across twelve picture-word topics:

| Topic | Words |
|---|---:|
| Animals | 57 |
| Food and drinks | 55 |
| Body parts | 17 |
| Clothes and accessories | 31 |
| Nature | 35 |
| Vehicles | 20 |
| Toys and books | 21 |
| Home and everyday objects | 42 |
| Ocean | 18 |
| Space | 19 |
| Garden | 16 |
| Music | 19 |

Original word-art definitions are maintained in `tools\generate-images.cjs` and the small
topic modules under `tools\word-art`. The generated SVGs use simple shapes without fonts,
external images or text labels.

```powershell
node tools\generate-images.cjs
node tools\generate-world-bgm.cjs --missing
node tools\generate-sfx.cjs
```

Edit `voice-prompts.json` to change the spoken prompts. Active prompt IDs must have valid Godot imports and remain included in the Web preset; the build rejects required audio missing from the PCK. When adding a word, add its image-generation definition, level-tagged JSON entry, topic membership in `game_data.gd`, and pronunciation recording. Keep at least five non-confusable eligible words per topic at every level. Run `npm run test:ages` and `npm run build:web` afterward: the vocabulary and all active audio are packaged into Godot's PCK. There is no second runtime word-record list.

The compatible version-one playroom save has an optional `[learning] age_band`
key (`all`, `4-6`, `7-9`, or `10-plus`). Missing keys retain all words; invalid
IDs fail visibly rather than overwriting choices. Existing rewards, journey
history, and legacy sticker collections are preserved, including all 350 words.

### Regenerate natural speech

Voice regeneration and its conversion tests additionally require **FFmpeg** on PATH.
`tools\generate-voices.cjs` uses Jenny's `friendly` style at degree `1.15`, with an 8% slower
speaking rate. A short leading pause keeps card pronunciation responsive. FFmpeg removes
excess final silence while retaining a gentle 160 ms tail, quiet word endings, and pauses
within sentences. It converts the service's 24 kHz output to the existing **22.05 kHz,
PCM16 mono** asset format, preserving the mobile audio import settings.

The personal Azure Speech resource is `tesisgame-speech`, **F0**, in `rg-footises`, East Asia.
The generator spaces requests for that tier, checks that the selected neural style is
available, and keeps existing recordings until the complete batch has been generated and
validated. It fails explicitly rather than silently reverting to a desktop voice.

```powershell
$env:SPEECH_REGION = "eastasia"
$env:SPEECH_KEY = az cognitiveservices account keys list `
    --subscription "Visual Studio Enterprise Subscription" `
    --name tesisgame-speech --resource-group rg-footises `
    --query key1 --output tsv
if ($LASTEXITCODE -ne 0 -or !$env:SPEECH_KEY) { throw "Speech credentials unavailable." }
try {
    node tools\generate-voices.cjs
    if ($LASTEXITCODE -ne 0) { throw "Voice generation failed." }
} finally {
    Remove-Item Env:\SPEECH_KEY
    Remove-Item Env:\SPEECH_REGION
}
```

The existing `tools\generate-voices.ps1` command forwards to the same generator.
Keep keys in the process environment, never in source files or the Web export.
Use `node tools\generate-voices.cjs --missing` to add only absent recordings.
The game prompt catalog contains ten messages: wrong-answer and loss feedback,
plus one greeting for each world. Together with the 350 word recordings, the
generator maintains 360 active files under `assets\audio\voice`. Retired
arrival/opening recordings have been removed; historical provenance remains in
the asset documentation. Legacy Voice Pop report recordings remain in their
separate directory and startup pack; the current result UI does not use them.
Source details, hashes and generation checks are in
[Jungle and Candy audio](docs/assets/jungle-candy-audio.md).

## Chest artwork

Selected artwork is imported from the user-provided **Modern 2D Animated Chests Pack_FREE Demo 1.0.2**. Its three source designs support eight distinct motion and sound treatments:

| Season | Source chest | Treatment |
|---|---|---|
| Spring | Royal | Light wood, unfolding lid, petals and flower bells. |
| Summer | Energy | Heating core, pressure release and a fast lid spring. |
| Autumn | Royal | Heavy wood, metal latch, slower hinge and a small landing recoil. |
| Winter | Crystal | Staggered facets, a central unlock and short ice resonance. |
| Ocean | Crystal | Inward pressure, buoyant release, bubbles and soft water. |
| Space | Energy | Magnetic steps, a floating cover and servo/airlock sounds. |
| Jungle | Royal | Vine tension, a pulled lid, delayed leaves and woody recoil. |
| Candy | Crystal | Elastic compression, a two-beat opening, pops and sugar rattles. |

`scripts/chest_feel.gd` defines shared cue times and per-world motion profiles.
`assets/chests/rigs.json` describes derived Royal/Energy layers; the original
source manifest retains the 14 images used by the current chest. The derived art reuses the original
pixels and textures rather than replacing the silhouette with a new illustration.

The importer copies 14 PNGs byte-for-byte, records SHA256 and source paths, and converts the Crystal prefab's rest transforms, pivots, flips and ordering into `assets\chests\manifest.json`. The retired collectible celebration and its five unused particle textures are no longer included. Unity scripts, materials, prefabs and animation clips are **not** executed or shipped; motion is recreated natively in Godot.

```powershell
node tools\import-chests.cjs "D:\uwork\AssetsSource\Modern 2D Animated Chests Pack_FREE Demo"
```

The supplied source directory is read-only to this workflow. `assets\chests\SOURCE.txt` records provenance. The free demo has three designs, not four independently authored seasonal chest models. Its other `Demo\Sprites` images are locked, watermarked full-version previews, not additional animated chest assets. They are not imported or stripped of their overlays.

## Background music and third-party assets

Voice Pop uses the short `Cut2.wav` effect from the same local music pack.
Import it with `node tools/import-pop-sfx.cjs "D:/uwork/AssetsSource"` before
building. The selected file remains ignored by Git and ships inside the game
pack; see [source and playback details](docs/assets/voice-pop-sfx.md).

Four tracks were copied from the user-provided **Casual Game Music Pack 1.4**:

| Season | Source track | Local file |
|---|---|---|
| Spring | Flower-Menu-Loop | `assets\audio\bgm\spring.wav` |
| Summer | Ukulele-Menu-v1-Loop | `assets\audio\bgm\summer.wav` |
| Autumn | Banjo-Menu-Loop | `assets\audio\bgm\autumn.wav` |
| Winter | Space-Menu-Loop | `assets\audio\bgm\winter.wav` |

Ocean, Space, Jungle and Candy use original scores from
`tools\generate-world-bgm.cjs`, bringing the total to eight tracks. Jungle uses
rounded wooden-key tones and a quiet low pulse; Candy uses soft toy-piano
overtones. Their source music is distinct from the licensed four-season pack.
See [Jungle and Candy audio](docs/assets/jungle-candy-audio.md) for the new music,
chest effects and Jenny Neural prompts.

The stereo 44.1 kHz source WAVs are retained. Godot packages compressed BGM
resources; each track's `.wav.import` records its `force/mono` and `force/max_rate`
settings. Mono 22.05 kHz imports reduce the mobile download size without changing
the source recording. Rebuild after changing these settings.

The chest artwork and music retain their providers' terms; this repository's code license does not grant additional rights to those assets. Confirm distribution permissions before publishing them. The original source packs are not modified.

## Development

```powershell
npm test
npm run test:browser
npm run test:all
```

`npm test` imports resources and runs each native and Node suite once. Use
`node tools/run-tests.cjs --list` to inspect the complete plan, or a focused
command such as `npm run test:voice-pop` or `npm run test:pip-audio` during
development. Browser checks remain in `npm run test:browser`.

The native suite exercises actual GDScript state transitions, distractors, independent thresholds, reward locking and persistence, audio lifecycle, resource loading, seasonal palettes, responsive Control bounds and scene wiring. Node tests cover generated media, texture import settings, imported chest files, Web-export contracts and deployment-script failure handling. Playwright runs the **exported Godot engine**, including touch input, resizing, browser audio, bundled playback without further audio downloads, stale-playback suppression, the interactive loader, interrupted downloads, loading errors and iframe embedding.

The [enjoyable-play plan](docs/superpowers/plans/2026-09-09-enjoyable-play.md)
records the market research, design choices, acceptance criteria, and release process
for round limits, fresh rounds, seasonal goals, and the preceding hint/reward improvements.
The historical [chest reveal plan](docs/superpowers/plans/2026-09-09-chest-reveal.md)
records the earlier collectible presentation, migration, and reward lifecycle.
Its assembly and collection presentation have since been removed; the saved
progress rules remain in use.

The Windows Playwright WebKit runtime exposes WebGL 2 but not AudioContext or OffscreenCanvas. In that environment the real Godot Dummy audio driver is selected and the host reports the missing capability. An ordinary multisampled canvas selects Emscripten's built-in shader presentation path, avoiding that runtime's repeated framebuffer-blit error. No fake WebAudio or WebGL APIs are substituted. Chromium exercises real browser audio APIs.

Real iPhone/iPad testing remains important for physical audio playback, browser-bar changes, safe areas, split view and background/foreground behavior.

Speech automation supplies recognition events instead of opening a physical
microphone. It covers live text, whole-word scoring, permissions, cancellation,
and stale callbacks, not the browser provider's acoustic recognition accuracy.

To render reference screenshots from the native development scene:

```powershell
node tools\run-godot.cjs --path . --audio-driver Dummy --rendering-driver opengl3_angle --script res://tests/godot/render_scenes.gd
```

On Windows, this uses ANGLE rendering and the Dummy audio driver so screenshot generation does not require a physical sound device. Screenshots go to the ignored `build\visuals` directory. `.godot` and exported build products are not committed; import metadata and source assets are maintained.

The migration plan is `docs\superpowers\plans\2026-09-07-godot-web-migration.md`. The previous HTML implementation remains available in Git history at `e8b3771`.
