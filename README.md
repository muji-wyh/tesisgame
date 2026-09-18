# Pip and Words

A **Godot game delivered on the Web** for early English learners. Gameplay, cards, audio, chest animation and celebrations run in GDScript. The HTML shell hosts the exported engine and integrates browser sizing, accessibility announcements, lifecycle events and read-only asset URLs.

Players need a browser, not a Godot installation. The game is a static website
with no game backend or external image service. Optional voice play uses the
browser's speech-recognition provider.

## Run and build

Development prerequisites: **Godot 4.7**, its matching **Web export templates**, and **Node.js 24**. The `godot` executable must be on PATH; alternatively, set `GODOT_BIN` to its executable path.

```powershell
npm ci
npm start
```

`npm start` imports the resources, exports Godot to Web, and serves the result at `http://127.0.0.1:4173`.

To build without starting a server:

```powershell
npm run build:web
```

The deliverable is **the entire `build\web` directory**. Keep its HTML, JavaScript, WebAssembly, PCK, audio-worklet, on-demand `.sample` audio, icon and `.br` files together. Deploy that directory to a static HTTPS host; do not deploy just the HTML file or open it using `file://`. The host must serve `.wasm` as `application/wasm`.

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
Chest taps also lead Pip through a dance: left wing, right wing, then alternating
hip swings. Quick taps form a short, bounded sequence. A quiet original tune is
synthesized locally after the first interaction; its sound control can mute it.
Music stops when loading ends or the page hides, and returning never starts it
without another interaction. Reduced motion keeps clear pose feedback.
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

Word pronunciations and immediate sound effects stay in the startup **PCK alongside WASM**.
The eight background tracks, twenty-eight game prompts and Voice Pop report recordings
are separate, content-hashed Godot `.sample` resources. Their URLs are embedded in HTML, so no extra startup manifest
request is needed. The build opens the actual exported PCK to confirm that word speech is
present and both the optional source resources and their imported payloads are absent.

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

The game uses compact square icon actions and four small mode tabs, leaving the cards as the
main focus. Pip and the success/mistake indicators form one compact status cluster;
Learn has no score counter. Memory's marked pairs retain their progress. Card positions stay fixed
through feedback. Main actions have filled buttons; secondary navigation stays quiet.
On wider screens the mode tabs share the header row. Tall Learn cards keep the
illustration and word near the top instead of leaving a large empty upper area.

**More** opens **Pip** and **Medals**, with an icon to return. Eight larger world
icons share the top header on wider screens and wrap below it on small screens.
Choosing one keeps the current page and scroll position open while changing the
look and sound, without resetting the game, selection, or hints. An unsaved change
shows an in-page retry notice. Medal and gift goals live here rather than above the cards.
Results keep the chest or bear, word review, and the next action without game-mode
controls. Learn has no bottom buttons: its display is the navigation and pronunciation
surface, with a compact `1/5` counter in the card's upper-right corner. Slides use the
same appearance during tapping and dragging; keyboard/controller focus remains visible.

**Pip the duck** is the game's round, wide-eyed companion. He appears on the
loading screen, board, results, collection, reward previews, and voice panel.
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

The outfit follows the selected world; a medal preview uses that medal's world.
The same wardrobe appears in Pip's speaking poses, quiet gestures and dances,
with hats following his head and clothes following his body. Dressing Pip does
not require a purchase or a new reward. The loading and voice companions use
the same themed artwork, and the loader reads the saved world when available.

Start in **Match**, with its tab selected and the matching board ready.
Choose **Learn** for a large picture with its written word. Swipe left for
the next word or right for the previous word; mouse dragging works too. Tap the
display to hear the word. With the display focused, use **Left/Right** or the Xbox
D-pad/left stick to browse, and **Enter**, **Space**, or Xbox **A** to hear it.
The card follows the drag and reveals the neighboring word, then settles into
place on release. Edges resist dragging beyond the lesson. Reduced motion keeps
direct finger tracking but removes the settling animation.
Six pictures also have short, noun-specific play reactions: the ball hops, bell
swings, rocket lifts, fish swims, boat rocks, and flower grows. Tap or use the
existing keyboard/controller activation to replay them. The written word and
input target stay still; new input cancels old motion, and nothing is queued.
These reactions also work without sound. Reduced motion keeps the original
static picture and normal pronunciation instead.
The first and last words do not wrap or start a game automatically. Swipes never
play audio, and navigation still works when sound is unavailable. Learn never awards points.
The tabs are ordered **Match**, **Learn**, **Memory**, **Voice Pop**; entry and reload select Match.

### Voice Pop

Choose Voice Pop to request speech permission. The 30-second clock starts only when
the microphone is listening. Broad peach/pink and blue/violet light follows the
rounded screen edges and diffuses softly inward, while illustrated word capsules
fly up in gentle arcs. Say the English name
of a visible object to pop it with a slash, shards, and a shockwave. Words always
appear with their matching pictures and follow the age level chosen in More.
The HUD shows recognized speech as it changes, including interim speech and words
that do not score. Long sentences keep their newest two lines in view. Pausing,
finishing or leaving clears that text.

Hits earn 10 points, plus 2 for each step of the current combo (up to 10 bonus
points). Dropped objects end the combo; there is no losing screen. Pip reports the
actual results in a speech bubble after 30 seconds. His three report pages cover
your round, the words and combos you achieved, and a specific word to practise.
Choose My highlights / Coach me to continue, Hear Pip to replay his current
report, or tap Pip for a high-five. His beak follows actual summary playback.
Review any word's recorded pronunciation or play another round. The result view
scrolls by touch, wheel and keyboard focus without showing a scrollbar.
Pip uses prerecorded Jenny Neural speech with the same friendly delivery as the
word recordings. Whole sentences report the actual hit count and best combo;
the review and coaching pages include words from the completed round. The four
result tiles retain the exact hits, distinct words, combo and score. New report
clips download only when needed, without adding to the startup pack. Playback
does not depend on an installed browser TTS voice or runtime speech credentials.

Microphone denial, missing hardware, or speech-service errors show a retry action.
More, backgrounding, and recognition interruptions pause the current round; Resume
continues it without resetting the score. Leaving the mode or finishing stops
recognition. Browser speech can process audio remotely; the game does not save
recordings or transcripts. A secure browser with SpeechRecognition support is
required; unsupported browsers show an explanation and a way back to Match.
Reduced motion keeps a static edge glow and simpler hit feedback.
Switch between them to practise the same lesson.
Sky and Listen have been removed. Match keeps the eight-card, three-pair puzzle.
Correct and wrong feedback stays on the cards and clears automatically after a short
pause; there is no footer or extra confirmation step. Selecting the next unmatched
card continues immediately. Tap any card, including a completed pair, to hear its
word again without changing the score. Each winning round earns one ordinary medal piece.
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
all five pairs opens the normal chest for one saved medal piece.
**New adventure** is the normal result action; **Repeat lesson** has been removed.
**Retry saving** appears only if reward storage needs recovery, without restarting play.
**New adventure** on
results starts a fresh five-word Learn lesson directly. The manual Explore
picker has been removed. Existing room choices, world preferences, and journey
metadata are preserved; a failed write keeps play available and offers
**Retry saving** in the header without resetting the current word.
The result shelf reviews all five words, with missed words first. Swipe or drag
horizontally to reveal them without a scrollbar; a stationary tap replays a word.
Keyboard and controller focus still scroll the final word into view. Drags,
cancelled gestures, and multiple touches never trigger pronunciation or rewards.
Result actions stay compact and centered rather than stretching across the page.
Save retries and newly unlocked toy actions use the same styling.

**Medals** groups rewards on world-colored treasure shelves. Empty slots are
original duck-faced mystery eggs; collected pieces retain their actual artwork
and counts. Quieter surfaces and wider spacing keep the medals distinct, without
repeating "Complete" or "Surprise!" under every item. Earlier rewards use compact,
named chips rather than a second full-size grid. Pip joins the next-treasure guide,
and medal artwork gives a small
wiggle on hover or keyboard focus without moving its input target. Reduced
motion and hidden views stop these reactions. These effects never award pieces.

The eight worlds are **Spring**, **Summer**, **Autumn**, **Winter**, **Ocean**,
**Space**, **Jungle** and **Candy**, with **48 active medals**: six per world.
The 200-word vocabulary spans 12 adventures, including ocean discovery, space trips,
garden trails, and music makers. Pictures are original SVG illustrations generated by
the existing local art pipeline, and every word has its own spoken recording.

The two new medal shelves add distinct treasures:

| World | Six medals | Toy unlocked by its first completed medal |
|---|---|---|
| Jungle | Monkey, Tree Frog, Tiger, Elephant, Bamboo, Waterfall. | Jungle monkey. |
| Candy | Party Cake, Cookie, Lollipop, Wrapped Candy, Ice Cream, Candy Castle. | Candy cake. |

Existing medal IDs, completed pieces and earlier rewards are retained when these
worlds are added; the new shelves begin empty in an existing save.

Open **More > Pip** to visit **Pip's playroom**. A ball is playable immediately.
Each world's first completed medal unlocks its toy, making nine toys including
the starter ball.
Choose an owned toy, or preview a locked toy and its exact requirement.
Toy cards use their own world colors, larger illustrations and a wider
side-by-side layout when space permits. **Using** marks only the equipped toy;
**Preview** and **Goal** are separate descriptions, not additional selections.
Previewing a locked gift keeps the equipped toy and all earned pieces intact.
The Rooms/backdrop chooser has been removed. Existing saved backgrounds remain
intact and continue to render; they are not advertised as new gifts or goals.
Drag blank areas of the room canvas, including locked toy previews, to scroll.
A stationary floor tap still calls Pip; direct duck and unlocked-toy gestures
retain their play interactions.
Choose a locked toy to preview it without moving the page. Its card shows the
remaining pieces and an inline arrow to start or continue its adventure; there
is no separate **Help Pip get this** row. The arrow saves the goal and starts a
related five-word adventure in its reward world. The lesson includes the desired
toy's word. Learn, Match, and Memory keep those same
five words; only normal wins and opened chests earn pieces. The goal caption shows
the chosen gift and remaining pieces, including its world if you switch away.
The same card lets you continue the goal or use its toy once earned, including after reload.
Save failures appear on the affected card. Pointer selection keeps scroll and card
positions stable; keyboard/controller focus still reveals the full card and its action.
An unopened or unsaved chest must be collected before starting a gift adventure.
An explicitly chosen gift lesson always includes its toy's noun, even when that
noun belongs to an older age level; the other four words respect the selected
age level. Ordinary lessons keep the full age filter.
Water a flower, roll a ball, offer an apple, ring a bell, listen to a shell, launch
a rocket, swing with the jungle monkey or decorate the candy cake with Pip.
Each toy has three steps you control, such as rolling, returning and catching
the ball or readying, igniting and launching the rocket. The monkey swings,
waves and gives a high five; the cake is set down, frosted and covered in sprinkles.
Every step shows and pronounces its noun; a finished sequence offers replay.
Toy play is temporary and never grants extra medals. Reduced motion
shows each stage's static result. The next gift shows its name and
remaining pieces. Newly unlocked gifts offer **Try it with Pip** after the reward saves.
Open an earned medal and choose **Display with Pip** to save it as the playroom's favorite.
Toy, backdrop, and favorite save together immediately in browser storage, or in
`user://playroom-v2.cfg` in native builds. The earlier favorite is migrated, and medal
progress remains unchanged. Failed reads/writes show a retryable notice.

The Words album and word-sticker display have been removed. Existing saved word
fields remain intact for compatibility, but games no longer collect new stickers.
Medals uses uniform tiles grouped by world, with the next medal goal alongside the
collection. The compact world icons keep their full tooltip and accessibility names.

Card selections ripple and successful matches sparkle. Effects
are bounded and respect reduced motion; the same controls work with touch, keyboard, and Xbox.

Pip's beak follows the actual pronunciation/prompt player, including delayed
audio downloads and page transitions, rather than merely reacting to a button
press. Background music and sound effects do not make him talk. During microphone
play he listens instead. Reduced motion uses static speaking/greeting poses.
After 6–9 seconds of inactivity in normal play or Pip's room, Pip may wave,
offer a high five, play peekaboo, look around, stretch, preen, hop or dance.
Small gestures last 1.8 seconds and dances last 3.2 seconds, followed by another
full quiet interval. Input, held pointers, Peek, speech and answer feedback take priority.
Invitations make no sound, change no status text, and never start recording,
spend hints or alter progress. They stop in previews, background tabs and with
reduced motion. Pip's touch target stays in place. Repeated room pokes now
alternate between a tickle, high five, peekaboo and flutter without new controls.
Godot and the inline HTML mascot use the same wardrobe sources. The build embeds
the loader's themed poses and dance parts, so its companion needs no additional
image request.

Find three matching word/picture pairs among **eight cards**. One extra word and one extra picture have no matching partner. Three correct matches win; three mistakes end the round. Clicking another card of the same kind changes the selection without a penalty. Clicking the selected card cancels it. Illustrated green match badges and gentle coral mismatch badges show progress in the top-left. Matched cards stay available for pronunciation, not for scoring again.

Each round is a small **word adventure**: Animal friends, Picnic time, Great outdoors,
Dress up, On the move, Play time, At home, Head to toe, Ocean discovery, Space trip,
Garden trail, or Music makers. All five words on the matching board
belong to its topic. New adventure chooses a different available topic and fresh words.
Custom word lists with too few related words use a mixed Word explorers board; seeded
rounds remain reproducible. Changing the season keeps the current adventure.

**More > Medals** previews your next medal and its piece count. After a round,
the review shelf shows all five words, even if the round ended with mistakes.
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

Use the **lightbulb icon** (or Xbox **X**) when you get stuck. A real unmatched pair gets gold borders
and star badges, and its word is spoken. Hints follow your selected card when it has a
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
keeps the encouragement and hint stars without moving particles.

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

Accepted Match, Learn, Memory and toy-card clicks give a short content press
and bounce. The button and grid never move, Memory retains its existing flip,
and the six noun-specific picture reactions still play. Repeated clicks replace
the animation; navigation, resizing and reduced motion settle it immediately.
Game-card taps also make a brief themed ripple and eight small sparkles.
Correct/wrong feedback keeps priority, and these visual effects never score
another answer or move a clickable target.

The vocabulary pool contains **200 illustrated English words** for parent-guided play.
Matching rounds use five different words on eight cards;
Memory uses those five words on ten cards. Tap a matching card to hear its pronunciation.

In **Match**, a two-column board puts all four pictures in the left column and
all four words in the right column. A two-row board puts all pictures in the top
row and all words in the bottom row. Each type keeps its shuffled order; matching
partners are not deliberately lined up. Resizing preserves the current round and hints.

Choose a vocabulary level using the four direct **Age** buttons in **More**:

| Choice | Vocabulary |
|---|---|
| All | All 200 words, without a difficulty preference; the default for new and existing saves. |
| Ages 4-6 | 98 basic picture words, such as cat, apple, ball, and rocket. |
| Ages 7-9 | 160 basic and growing words; growing vocabulary such as helmet, pumpkin, and puzzle is preferred. |
| Ages 10+ | All 200 words; advanced vocabulary such as helicopter, astronaut, and xylophone is preferred. |

Age ranges are **suggested vocabulary guides, not reading-age assessments or restrictions**.
Choose whichever level feels right; no birthdate, profile, or account is collected.
Every topic remains playable at every level, with earlier words available for review.
The choice is saved on this device and applies to the **next lesson**. Switching between
Match, Learn, and Memory keeps the current five words and their active level. Changing
the age never resets a round, its hints, medal pieces, or toys. An unsuccessful save
keeps the confirmed selection and offers a visible tap-to-retry message.
On very short screens, the age row scrolls with the collection so reward tiles
remain usable without shrinking the controls.

The winning chest follows the selected theme and can be dragged inside its panel.
A short tap gives a little wiggle and glint. Hold it for **1.2 seconds** to charge it:
the shake and latch glow build without a progress bar, followed by the existing
**1.8-second opening**. Releasing early or dragging cancels charging. Changing seasons
cannot reroll an opening or alter an earned fragment.

Each win earns **one fragment**. **Three fragments complete a medal**, and each
season has **six medals**. The next piece always advances the first unfinished
medal in that season; there are no duplicate fragments or rare missing pieces.
An ordinary reveal uses 24 seasonal particles and snaps the new piece into the
visible partial medal. Tap the chest panel or press A/Enter to place it sooner.
Finishing a medal triggers the larger 72-particle celebration and a flight into
the collection under **More**. A complete season can still celebrate future wins without
inventing more medals or resetting the collection.

Fragments are saved before their assembly animation. Hiding the page or replaying
during opening finishes the earned claim once, then settles its visuals.
Reduced motion shows the saved piece immediately after the hold.
If saving fails, **Retry saving** retries the same piece instead of rerolling,
pretending it was saved, or silently discarding it.

Collection headings show completed medals, such as **Spring 2/6**. Tiles show
empty, partial (**1/3**, **2/3**), or complete medals. Earlier whole rewards are
preserved: existing rewards 1-6 become complete medals; earned rewards 7-10 remain
available under **Earlier rewards**. Native versioned progress uses `user://medals.cfg`;
the old `user://rewards.cfg` is left unchanged. Corrupt or unsupported saves show
an error rather than being reset.

Web builds save medal progress immediately in browser storage so a quick reload
cannot lose a newly earned piece. Existing browser filesystem saves migrate on
load, while native builds retain the transactional `user://medals.cfg` save.

Tap an earned tile to open its larger seasonal preview; partial medals reveal
only their earned pieces. Taps alternate between a bounce, a twirl and a little hug, with Spring hearts,
Summer stars, Autumn leaves, Winter snowflakes, Ocean bubbles, Space stars,
Jungle leaves or Candy hearts. Every five taps brings a bigger
high-five party. The visible play count starts fresh when a preview opens and never grants
another reward. These finite, native effects use at most twelve shapes and no new downloads;
rapid taps replace the previous reaction instead of stacking animations.

Collection swipes follow the finger one-to-one, then glide and slow naturally on release.
A new touch stops the glide without opening the tile underneath. Scrolling stops at the
edges and when leaving the collection; wheel and keyboard scrolling remain available
without visible scrollbars. Controller navigation brings earned rewards back into view
even after touch scrolling. Reduced motion keeps direct finger scrolling, disables the
automatic glide, and gives static preview feedback, including the high-five message.
A won reward is still revealed immediately after the required hold.

**Play again** starts a fresh round, avoiding the previous board's words when at least
five unused words are available. Small vocabularies still produce a complete board;
explicit seeds remain reproducible. Audio starts with normal game interaction and stops on
hiding, loss or reset; returning from a hidden page does not force autoplay. The loss screen
uses the encouraging bear, a gentle effect and prerecorded English speech. Tap the bear
or focus it and press Xbox A for a happy wiggle, little hearts and rotating encouragement.
Bear play never restarts lost-round music or changes the result. Reduced motion keeps the
encouragement without movement, and Play again remains the initial controller action.

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

Click **Voice** again to exit. Winning, losing, replaying, opening a
collection/preview, or hiding the page also stops listening. Game music and spoken
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
| A | Activate the focused control; hold the eye to peek, hold a chest to open it, or tap to place its piece. |
| B | Cancel the selected card, exit voice play, close a reward preview, or go back. |
| X | Use one of the round's three hints and focus a card in the suggested pair. |
| LB / RB | Change the game season without restarting the round. |
| Y / Menu | Open or close More (Pip, Medals, and direct world choices), not restart the game. |

Choose **Play again** with A to start another round. Locked rewards are skipped during
navigation; completed Match cards remain available to hear again. Releasing A or
disconnecting also releases a held Memory eye. Releasing A early cancels an incomplete chest
charge; reconnecting retains the current round. A held on the loading toy must be released
before selecting a native game control. If the browser keeps controller-only audio muted,
tap or click the game once to enable sound.

Particle textures load only for the first animated celebration, rather than delaying startup.
Reduced-motion players do not load those unused textures.

On the Web, background music and non-word speech download only when requested. Card input,
word pronunciation, scoring and chest opening never wait for them. Native HTTP requests share
in-flight downloads, use a 15-second timeout and 4 MB limit, and check resource signatures and
content hashes before loading. Decoded sounds are cached for the session; the browser caches
their immutable URLs between visits. Temporary resource files are removed after loading.
Old requests cannot restart hidden music, play the previous theme or replace a newer
word. Failed downloads show a non-blocking notice and can be retried with another interaction.
Editor/native play continues to use local audio.

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

The 200 word pictures live together in `assets\images\words`. Word/reward/bear SVGs, English prompt scripts and synthesized SFX were generated for this project. Prerecorded speech uses **Microsoft Jenny Neural (en-US)** with a warm, friendly delivery and a slightly slower pace. Azure Speech is used only to generate these source recordings; playback and ordinary builds need no speech credentials. Optional microphone recognition is a separate browser-provided service. All 200 word recordings remain in the startup PCK; only background music and non-word prompts download on demand.

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
| Animals | 29 |
| Food and drinks | 25 |
| Body parts | 15 |
| Clothes and accessories | 21 |
| Nature | 14 |
| Vehicles | 12 |
| Toys and books | 11 |
| Home and everyday objects | 21 |
| Ocean | 13 |
| Space | 13 |
| Garden | 13 |
| Music | 13 |

Original word-art definitions are maintained in `tools\generate-images.cjs` and the small
topic modules under `tools\word-art`. The generated SVGs use simple shapes without fonts,
external images or text labels.

```powershell
node tools\generate-images.cjs
node tools\generate-world-bgm.cjs --missing
node tools\generate-sfx.cjs
```

Edit `voice-prompts.json` to change the spoken prompts. New optional prompt IDs must also be covered by the Web preset's exclusions; the build rejects optional audio accidentally left in the PCK. When adding a word, add its image-generation definition, level-tagged JSON entry, topic membership in `game_data.gd`, and pronunciation recording. Keep at least five non-confusable eligible words per topic at every level. Run `npm run test:ages` and `npm run build:web` afterward: the vocabulary, word pronunciations and immediate effects are packaged into Godot's PCK, while optional music and prompts are published beside it. There is no second runtime word-record list.

The compatible version-one playroom save has an optional `[learning] age_band`
key (`all`, `4-6`, `7-9`, or `10-plus`). Missing keys retain all words; invalid
IDs fail visibly rather than overwriting choices. Existing rewards, journey
history, and legacy sticker collections are preserved, including all 200 words.

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
The game prompt catalog contains 28 messages, including the three Jungle and
three Candy prompts; together with the 200 word recordings it produces 228
files under `assets\audio\voice`. Voice Pop report recordings remain in their
separate directory. Source details, hashes and generation checks for the twelve
new world audio files are in [Jungle and Candy audio](docs/assets/jungle-candy-audio.md).

## Chest artwork

Selected artwork is imported from the user-provided **Modern 2D Animated Chests Pack_FREE Demo 1.0.2**. Its three source designs become four seasonal treatments:

| Season | Source chest | Treatment |
|---|---|---|
| Spring | Royal | Green-tinted gold, green flower burst and fluttering petals. |
| Summer | Energy | Red/pink light, red sun rays and outward-spinning sparks. |
| Autumn | Royal | Yellow-gold light, yellow leaves and drifting confetti. |
| Winter | Crystal | Nine-part assembled chest, outlined white snowflakes and neutral crystal light. |

The importer copies 19 PNGs byte-for-byte, records SHA256 and source paths, and converts the Crystal prefab's rest transforms, pivots, flips and ordering into `assets\chests\manifest.json`. Unity scripts, materials, prefabs and animation clips are **not** executed or shipped; motion is recreated natively in Godot.

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

The native suite exercises actual GDScript state transitions, distractors, independent thresholds, reward locking and flight, audio lifecycle, resource loading, seasonal palettes, responsive Control bounds and scene wiring. Node tests cover generated media, texture import settings, imported chest files, Web-export contracts and deployment-script failure handling. Playwright runs the **exported Godot engine**, including touch input, resizing, browser audio, delayed/failed optional downloads, stale-playback suppression, the interactive loader, interrupted downloads, loading errors and iframe embedding.

The [enjoyable-play plan](docs/superpowers/plans/2026-09-09-enjoyable-play.md)
records the market research, design choices, acceptance criteria, and release process
for round limits, fresh rounds, seasonal goals, and the preceding hint/reward improvements.
The [chest reveal plan](docs/superpowers/plans/2026-09-09-chest-reveal.md) describes
the fragment assembly, six-medal collections, migration, and reward lifecycle.

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
