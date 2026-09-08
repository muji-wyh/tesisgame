# Word Buddies

A **Godot game delivered on the Web** for early English learners. Gameplay, cards, audio, chest animation and celebrations run in GDScript. The HTML shell hosts the exported engine and integrates browser sizing, accessibility announcements, lifecycle events and read-only asset URLs.

Players need a browser, not a Godot installation. The game is a static website with no backend, cloud speech service or external image service.

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

Engine and game-pack requests start together. The progress bar tracks actual downloaded
bytes; completion of the download is distinguished from the engine being ready. Failed
downloads, including interrupted response bodies, show an English error and a retry button.

Word pronunciations and immediate sound effects stay in the startup **PCK alongside WASM**.
The four background tracks and sixteen other spoken prompts are separate, content-hashed
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
  allow="autoplay; fullscreen; gamepad"
  style="display:block;width:100%;height:100dvh;border:0">
</iframe>
```

Give the frame a usable size, with a minimum content dimension of 320 CSS pixels. The game follows its container, handles safe-area padding, and preserves the current round when resized. The standalone game has no page scrolling. Browser audio still begins with player interaction; the iframe permission does not bypass autoplay policy.

## Play

Find three matching word/picture pairs among **eight cards**. One extra word and one extra picture have no matching partner. Three correct matches win; three mistakes end the round. Clicking another card of the same kind changes the selection without a penalty. Clicking the selected card cancels it. Illustrated green match badges and gentle coral mismatch badges show progress in the top-left instead of plain text counters. Correct pairs bounce; incorrect pairs shake.

Each round starts with a random **Spring (green)**, **Summer (red)**, **Autumn (yellow)** or **Winter (white)** theme. Four always-visible seasonal buttons change the appearance and music without resetting progress or showing a redundant switch-season tooltip. Motion follows the device or browser's reduced-motion preference; there is no extra FX control. Buttons, celebration colors and reward icons follow the same palette; Winter keeps dark outlines for readability.

The vocabulary pool contains **100 short, concrete English words** for parent-guided play
with young children. Each round still uses only five different words on eight cards, rather
than showing the whole pool at once. Tap a picture or word to hear its pronunciation.

The winning chest follows the selected theme and can be dragged inside its panel. Hold it for 1.2 seconds to charge it: the shake intensifies without displaying a progress bar, then the existing 1.8-second reveal starts with imported chest artwork, native light layers, two expanding rings, 72 seasonal particles and a reward medallion. Releasing early or dragging cancels the charge. Themes have different particle trajectories, palettes, music, effects and English speech. Theme switching is disabled during opening. Later theme changes do not alter the earned reward or grant another one.

After the reveal, the earned medallion pops up and flies into the **My rewards** entry,
which gives a small arrival bounce. The reward is saved before this cosmetic animation;
opening the collection, replaying, or hiding the page cannot lose or duplicate it.
Reduced motion keeps a static reveal instead of the flight.

Each season has ten named reward variants with ten different generated illustrations.
Opened rewards are stored locally and appear on the **My rewards** page; locked slots
keep their artwork and names hidden. Tap an earned tile to open its larger, named seasonal
preview. Taps alternate between a bounce, a twirl and a little hug, with Spring hearts,
Summer stars, Autumn leaves or Winter snowflakes. Every five taps brings a bigger
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

**Play again** starts a new round. Audio starts with normal game interaction and stops on
hiding, loss or reset; returning from a hidden page does not force autoplay. The loss screen
uses the encouraging bear, a gentle effect and prerecorded English speech. Tap the bear
or focus it and press Xbox A for a happy wiggle, little hearts and rotating encouragement.
Bear play never restarts lost-round music or changes the result. Reduced motion keeps the
encouragement without movement, and Play again remains the initial controller action.

### Xbox controller

| Control | Action |
|---|---|
| D-pad / left stick | Move focus between available controls. |
| A | Activate the focused control; hold to open a won chest. |
| B | Cancel the selected card, close a reward preview, or go back. |
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

The 100 word pictures live together in `assets\images\words`. Word/reward/bear SVGs, English prompt scripts and synthesized SFX were generated for this project. Prerecorded speech uses **Microsoft Jenny Neural (en-US)** with a warm, friendly delivery and a slightly slower pace. Azure Speech is used only to generate the source recordings; ordinary builds and gameplay do not call a speech service or need speech credentials. All 100 word recordings remain in the startup PCK; only background music and non-word prompts download on demand.

The collection keeps words to 2-6 lowercase letters and covers familiar picture-book topics:

| Topic | Words |
|---|---:|
| Animals | 24 |
| Food and drinks | 20 |
| Body parts | 10 |
| Clothes | 8 |
| Nature | 9 |
| Vehicles | 7 |
| Toys and books | 6 |
| Home objects | 8 |
| Everyday items | 8 |

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
Voice and sound-effect imports are unchanged. The four BGM `.wav.import` files retain the
`force/mono` and `force/max_rate` settings for retuning; rebuild after changing them.

The chest artwork and music retain their providers' terms; this repository's code license does not grant additional rights to those assets. Confirm distribution permissions before publishing them. The original source packs are not modified.

## Development

```powershell
npm test
npm run test:browser
npm run test:all
```

The native suite exercises actual GDScript state transitions, distractors, independent thresholds, reward locking and flight, audio lifecycle, resource loading, seasonal palettes, responsive Control bounds and scene wiring. Node tests cover generated media, texture import settings, imported chest files, Web-export contracts and deployment-script failure handling. Playwright runs the **exported Godot engine**, including touch input, resizing, browser audio, delayed/failed optional downloads, stale-playback suppression, the interactive loader, interrupted downloads, loading errors and iframe embedding.

The Windows Playwright WebKit runtime exposes WebGL 2 but not AudioContext or OffscreenCanvas. In that environment the real Godot Dummy audio driver is selected and the host reports the missing capability. An ordinary multisampled canvas selects Emscripten's built-in shader presentation path, avoiding that runtime's repeated framebuffer-blit error. No fake WebAudio or WebGL APIs are substituted. Chromium exercises real browser audio APIs.

Real iPhone/iPad testing remains important for physical audio playback, browser-bar changes, safe areas, split view and background/foreground behavior.

To render reference screenshots from the native development scene:

```powershell
node tools\run-godot.cjs --path . --audio-driver Dummy --rendering-driver opengl3_angle --script res://tests/godot/render_scenes.gd
```

On Windows, this uses ANGLE rendering and the Dummy audio driver so screenshot generation does not require a physical sound device. Screenshots go to the ignored `build\visuals` directory. `.godot` and exported build products are not committed; import metadata and source assets are maintained.

The migration plan is `docs\superpowers\plans\2026-09-07-godot-web-migration.md`. The previous HTML implementation remains available in Git history at `e8b3771`.
