# Word Buddies

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
Repeated taps do not show a browser highlight or select the caption, while keyboard focus
and pinch zoom remain available. It works before the engine script arrives and needs no
extra images, fonts, audio, or device-motion permission. Effects are capped at 12 particles,
respect reduced motion, and stop when the page is hidden or loading ends. Controller
polling runs only while a connected controller can use the loading toy.
Sparkles are temporary loading-screen play, not saved collection rewards.

Engine and game-pack requests start together. A labeled **Startup estimate** moves
quickly to **35%**, pauses briefly, advances to **75%**, pauses again, and reaches
**95%**. The final few percent follow remaining game-data loading; **100% is shown
only when the native game is ready**. Fast or cached starts do not wait for the
staged animation. A separate Game data line shows the real loaded byte counts.
Reduced motion uses milestone steps, hiding the page pauses pacing, and failed
downloads stop progress and show an English error with a retry button.

Word pronunciations and immediate sound effects stay in the startup **PCK alongside WASM**.
The six background tracks and twenty-two other spoken prompts are separate, content-hashed
Godot `.sample` resources. Their URLs are embedded in HTML, so no extra startup manifest
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
  title="Word Buddies"
  allow="autoplay; fullscreen; gamepad; microphone"
  style="display:block;width:100%;height:100dvh;border:0">
</iframe>
```

Give the frame a usable size, with a minimum content dimension of 320 CSS pixels. The game follows its container, handles safe-area padding, and preserves the current round when resized. The standalone game has no page scrolling. Browser audio still begins with player interaction; the iframe permission does not bypass autoplay policy.

## Play

**Pip the duck** is the game's round, wide-eyed companion. He appears on the
loading screen, board, results, collection, reward previews, and voice panel.
Tap him to cycle through a dance, a crunchy carrot snack, and a bubble party; he also reacts to selections, matches, hints,
season changes, and rewards. These reactions never change scoring or saved progress.

Start in **Learn**: a large picture appears beside its written word. Press **Hear**,
then use **Previous** and **Next** to explore all five words. Learn never awards points.
Switch between **Learn**, **Match**, **Sky**, **Listen**, and **Memory** to practise the same lesson.
Match keeps the eight-card,
three-pair puzzle. Sky words brings a picture down to two word choices; Listen offers a
Hear button and two pictures. Both choice games need five correct answers before three
mistakes, with no timer or speed penalty. Each winning mode earns one ordinary medal piece.
Every answer shows its correct picture, word, and Hear button until **Continue**.
Wrong Match attempts explain the two different words or an unpaired card.
Voice play retains timed feedback so a spoken sentence can finish its queued matches.
**Memory** plants a garden by finding five hidden word-picture pairs among ten cards.
Card backs show their kind and position. Flip a word and its picture; matched pairs stay
visible, and each pair grows a flower. **Study** reveals the same board without scoring;
**Return to play** hides unmatched cards while retaining their positions and completed pairs.
Wrong pairs show both correct associations until **Continue**. There is no timer or
three-mistake loss, and exploratory misses do not enter the missed-word list. Completing
all five pairs opens the normal chest for one saved medal piece. Repeat reshuffles the board.
Listen exposes the written target if sound is unavailable. Semantically overlapping
labels such as shell/clam and earth/planet never compete as right/wrong options.
**Repeat lesson** keeps the words, mode, and chosen world. **Explore** in Learn and
**New adventure** on results open **Pip's adventures**: choose any of twelve illustrated
destinations or **Surprise me** to start a new five-word lesson in Learn. **Back** returns
to the current attempt and card. Revisiting a place samples fresh words when enough fit.

The book remembers places visited and suggests an unvisited destination, then the least
recently visited. **Visited** means a lesson was opened, not that its words are mastered.
All topics are available immediately. Visits and the chosen reward world share the existing
room-choice save; a failed write keeps play available and offers **Retry** in the book.
The result shelf reviews all five words, with missed words first, and replays their speech.

The six worlds include **Ocean** and **Space**, with 36 active medals in total.
The 140-word vocabulary spans 12 adventures, including ocean discovery, space trips,
garden trails, and music makers. Pictures are original SVG illustrations generated by
the existing local art pipeline, and every word has its own spoken recording.

Open **My rewards** to visit **Pip's playroom**. A ball is playable immediately.
Each world's first completed medal unlocks its toy, and its third unlocks a backdrop.
Mix owned toys and rooms, or preview a locked gift and its exact requirement.
Water a flower, roll a ball, offer an apple, ring a bell, listen to a shell, or launch
a rocket with Pip; each toy pronounces its noun. The next gift shows its name and
remaining pieces. Newly unlocked gifts offer **Try it with Pip** after the reward saves.
Open an earned medal and choose **Display with Pip** to save it as the playroom's favorite.
Toy, backdrop, and favorite save together immediately in browser storage, or in
`user://playroom-v2.cfg` in native builds. The earlier favorite is migrated, and medal
progress remains unchanged. Failed reads/writes show a retryable notice.
Card selections ripple, successful matches sparkle, and choice answers celebrate. Effects
are bounded and respect reduced motion; the same controls work with touch, keyboard, and Xbox.

Pip's beak follows the actual pronunciation/prompt player, including delayed
audio downloads and page transitions, rather than merely reacting to a button
press. Background music and sound effects do not make him talk. During microphone
play he listens instead. Reduced motion uses static speaking/greeting poses.
While you learn, Pip occasionally looks around, stretches his wings, preens,
waves, or makes two small hops. Each gesture lasts under two seconds, with
6–10 quiet seconds between them. Speech and player reactions take priority;
idle gestures make no sound and do not change progress. They stop in background
tabs and with reduced motion. Pip's touch target stays in place.
The same original four-pose SVG supplies both Godot and the inline HTML mascot,
so the loading companion needs no additional image request.

Find three matching word/picture pairs among **eight cards**. One extra word and one extra picture have no matching partner. Three correct matches win; three mistakes end the round. Clicking another card of the same kind changes the selection without a penalty. Clicking the selected card cancels it. Illustrated green match badges and gentle coral mismatch badges show progress in the top-left instead of plain text counters. Correct pairs bounce; incorrect pairs shake.

Each round is a small **word adventure**: Animal friends, Picnic time, Great outdoors,
Dress up, On the move, Play time, At home, Head to toe, Ocean discovery, Space trip,
Garden trail, or Music makers. All five words on the matching board
belong to its topic. The adventure book lets the player choose a topic; Surprise me chooses
a different available adventure and fresh words.
Custom word lists with too few related words use a mixed Word explorers board; seeded
rounds remain reproducible. Changing the season keeps the current adventure.

The **My rewards** button previews your next medal and its piece count. After a round,
the review shelf shows all five words, even if the round ended with mistakes.
Tap a word's picture, or focus it and press Enter/Xbox A, to hear it again and make Pip
react. These word buttons never spend a hint or grant another reward.

Free Unity Asset Store artwork is evaluated with the offline [Unity import pipeline](docs/assets/unity-art.md).
Downloaded licensed packages and selected overrides stay out of this public repository;
the original SVG illustrations remain usable fallbacks. The tool validates paths,
selects PNGs, invokes Unity CLI, and verifies byte hashes before copying textures
into Godot. New package acquisition and real import are still pending; this release
uses the original word illustrations. See the provenance record for current status.

Use **Hint** (or Xbox **X**) when you get stuck. A real unmatched pair gets gold borders
and star badges, and its word is spoken. Hints follow your selected card when it has a
partner; otherwise they point to a complete pair. Each round has **one hint**, with no
score penalty. The button becomes **Used** afterward; only a new round restores it.
Cancelling selection, completing a match, or changing seasons does not refill it. You
still tap both cards to make the match. Hints move focus to the next suggested card,
so keyboard and controller players can continue with **Enter** or **A**.

Correct matches now make small star bursts. Consecutive matches grow the celebration
and show **2 in a row!** or **3 in a row!** beside the match badges, without a countdown.
Mistakes reset the streak, not earned matches; hints do not break it. Reduced motion
keeps the encouragement and hint stars without moving particles.

Rounds start with a random **Spring**, **Summer**, **Autumn**, **Winter**, **Ocean**, or **Space** theme until you choose one. Your chosen world is remembered across lessons and reloads. Six theme buttons change the appearance and music without resetting progress. Motion follows the device or browser's reduced-motion preference. Buttons, celebration colors, and reward icons follow the same palette; Winter keeps dark outlines for readability.

The vocabulary pool contains **140 short, concrete English words** for parent-guided play
with young children. Matching rounds use five different words on eight cards; choice modes
introduce one prompt at a time. Tap a matching card to hear its pronunciation.

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
**My rewards**. A complete season can still celebrate future wins without
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
Summer stars, Autumn leaves, Winter snowflakes, Ocean bubbles or Space stars. Every five taps brings a bigger
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

On a supported browser, click **Voice** to start listening immediately; click
**Voice** again to stop. There is no separate Listen button. The panel shows the
recognized text live in a seasonal speech bubble, with Pip and
animated listening bars. The buddy reacts as words arrive; these are status
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
| A | Activate the focused control; hold to open a chest or tap to place its piece. |
| B | Cancel the selected card, exit voice play, close a reward preview, or go back. |
| X | Use the round's one hint and focus a card in the suggested pair. |
| LB / RB | Change the game season without restarting the round. |
| Y / Menu | Open or close My rewards, not restart the game. |

Choose **Play again** with A to start another round. Locked rewards and matched cards are
skipped during navigation. Releasing A early or disconnecting cancels an incomplete chest
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

`words.json` is the only vocabulary list. Keep at least five entries:

| Field | Purpose |
|---|---|
| `id` | Unique stable lowercase identifier. |
| `text` | Unique lowercase English word, 2-6 letters. |
| `image` | Unique local picture under `assets/images/words/`. |
| `audio` | Local pronunciation under `assets/audio/voice/`. |

The 140 word pictures live together in `assets\images\words`. Word/reward/bear SVGs, English prompt scripts and synthesized SFX were generated for this project. Prerecorded speech uses **Microsoft Jenny Neural (en-US)** with a warm, friendly delivery and a slightly slower pace. Azure Speech is used only to generate these source recordings; playback and ordinary builds need no speech credentials. Optional microphone recognition is a separate browser-provided service. All 140 word recordings remain in the startup PCK; only background music and non-word prompts download on demand.

Pip's original sprite sheet is maintained directly in
`assets\images\mascots\pip.svg`. Its four frames are idle, speaking, blinking,
and waving. The build embeds this same sheet in the web shell as a data URI;
native `duck_mascot.gd` uses texture regions from its Godot import.

The collection keeps words to 2-6 lowercase letters and covers familiar picture-book topics:

| Topic | Words |
|---|---:|
| Animals | 24 |
| Food and drinks | 20 |
| Body parts | 10 |
| Clothes and accessories | 16 |
| Nature | 9 |
| Vehicles | 7 |
| Toys and books | 6 |
| Home objects | 8 |
| Everyday items | 8 |
| Ocean | 8 |
| Space | 8 |
| Garden | 8 |
| Music | 8 |

Original word-art definitions are maintained in `tools\generate-images.cjs` and the small
topic modules under `tools\word-art`. The generated SVGs use simple shapes without fonts,
external images or text labels.

```powershell
node tools\generate-images.cjs
node tools\generate-sfx.cjs
```

Edit `voice-prompts.json` to change the spoken prompts. New optional prompt IDs must also be covered by the Web preset's exclusions; the build rejects optional audio accidentally left in the PCK. When adding a word, add its image-generation definition, JSON entry and pronunciation recording. Run `npm run build:web` afterward: the vocabulary, word pronunciations and immediate effects are packaged into Godot's PCK, while optional music and prompts are published beside it. There is no second runtime word list.

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

Four tracks were copied from the user-provided **Casual Game Music Pack 1.4**:

| Season | Source track | Local file |
|---|---|---|
| Spring | Flower-Menu-Loop | `assets\audio\bgm\spring.wav` |
| Summer | Ukulele-Menu-v1-Loop | `assets\audio\bgm\summer.wav` |
| Autumn | Banjo-Menu-Loop | `assets\audio\bgm\autumn.wav` |
| Winter | Space-Menu-Loop | `assets\audio\bgm\winter.wav` |

The original stereo 44.1 kHz WAVs remain unchanged. For the mobile deliverable, Godot imports
background music as compressed **mono 22.05 kHz** audio: a deliberate fidelity/size trade-off.
Voice and sound-effect import settings are unchanged. The six BGM `.wav.import` files retain the
`force/mono` and `force/max_rate` settings for retuning; rebuild after changing them.

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
