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

Like FootisesGame3, this uses a manual Azure Static Web Apps deployment: app `tesisgame`,
Free tier, resource group `rg-footises`, East Asia, in the **Visual Studio Enterprise
Subscription**. The separate `footises-game` app is not changed.

With Azure CLI signed in and the Static Web Apps CLI (`swa`) installed, deploy the existing
`build\web` export from the repository root:

```powershell
$env:SWA_CLI_DEPLOYMENT_TOKEN = az staticwebapp secrets list `
    --subscription "Visual Studio Enterprise Subscription" `
    --name tesisgame --resource-group rg-footises `
    --query "properties.apiKey" --output tsv
if ($LASTEXITCODE -ne 0 -or !$env:SWA_CLI_DEPLOYMENT_TOKEN) { throw "Azure deployment token unavailable." }
try {
    swa deploy .\build\web --swa-config-location .\web --env production
    if ($LASTEXITCODE -ne 0) { throw "Azure deployment failed." }
} finally {
    Remove-Item Env:\SWA_CLI_DEPLOYMENT_TOKEN
}
```

`web\staticwebapp.config.json` supplies engine MIME types, immutable caching for hashed assets,
and `Cache-Control: no-cache` for HTML and other unversioned files. `Vary: Accept-Encoding`
keeps compressed and uncompressed responses distinct in caches. The build copies this
configuration into the export; the deployment command also explicitly selects the source
configuration. Run `npm run build:web` before publishing source or import-setting changes.

## Embed in a website

Upload the export together under a path such as `/games/word-buddies/`, then embed it:

```html
<iframe
  src="/games/word-buddies/index.html"
  title="Word Buddies"
  allow="autoplay; fullscreen"
  style="display:block;width:100%;height:100dvh;border:0">
</iframe>
```

Give the frame a usable size, with a minimum content dimension of 320 CSS pixels. The game follows its container, handles safe-area padding, and preserves the current round when resized. The standalone game has no page scrolling. Browser audio still begins with player interaction; the iframe permission does not bypass autoplay policy.

## Play

Find three matching word/picture pairs among **eight cards**. One extra word and one extra picture have no matching partner. Three correct matches win; three mistakes end the round. Clicking another card of the same kind changes the selection without a penalty. Clicking the selected card cancels it. Matches and mistakes appear as green and red icons in the top-left instead of text counters. Correct pairs bounce; incorrect pairs shake.

Each round starts with a random **Spring (green)**, **Summer (red)**, **Autumn (yellow)** or **Winter (white)** theme. Four always-visible seasonal buttons change the appearance and music without resetting progress. The compact **FX** button toggles reduced motion. Buttons, celebration colors and reward icons follow the same palette; Winter keeps dark outlines for readability.

The winning chest follows the selected theme and can be dragged inside its panel. Hold it for 1.2 seconds to charge it: the shake intensifies until the existing 1.8-second reveal starts with imported chest artwork, native light layers, two expanding rings, 72 seasonal particles and a reward medallion. Releasing early or dragging cancels the charge. Themes have different particle trajectories, palettes, music, effects and English speech. Theme switching is disabled during opening. Later theme changes do not alter the earned reward or grant another one.

Each season has ten named reward variants. Opened rewards are stored locally and appear on the **Rewards** page; locked slots remain hidden until earned. Reduced motion skips moving feedback and reveals the reward immediately after the required hold. **Play again** starts a new round. Audio starts with normal game interaction and stops on hiding, loss or reset; returning from a hidden page does not force autoplay. The loss screen uses the encouraging bear, a gentle effect and prerecorded English speech.

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

The eight word pictures live together in `assets\images\words`. Word/reward/bear SVGs, English prompt scripts and synthesized SFX were generated for this project. Prerecorded speech is generated locally using **Microsoft Zira Desktop (en-US)**; players do not need that voice installed.

```powershell
node tools\generate-images.cjs
node tools\generate-sfx.cjs
powershell.exe -NoProfile -File .\tools\generate-voices.ps1
```

Edit `voice-prompts.json` to change the spoken prompts. New optional prompt IDs must also be covered by the Web preset's exclusions; the build rejects optional audio accidentally left in the PCK. When adding a word, add its image-generation definition, JSON entry and pronunciation recording. Run `npm run build:web` afterward: the vocabulary, word pronunciations and immediate effects are packaged into Godot's PCK, while optional music and prompts are published beside it. There is no second runtime word list.

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
node tools\import-chests.cjs "C:\uworks\tesisgameu\Assets\Modern 2D Animated Chests Pack_FREE Demo"
```

The supplied source directory is read-only to this workflow. `assets\chests\SOURCE.txt` records provenance. The free demo has three designs, not four independently authored seasonal chest models.

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

The native suite exercises actual GDScript state transitions, distractors, independent thresholds, reward locking, audio lifecycle, resource loading, seasonal palettes, responsive Control bounds and scene wiring. Node tests cover generated media, imported chest files and Web-export contracts. Playwright runs the **exported Godot engine**, including touch input, resizing, browser audio, delayed/failed optional downloads, stale-playback suppression, loading errors and iframe embedding.

The Windows Playwright WebKit runtime exposes WebGL 2 but not AudioContext or OffscreenCanvas. In that environment the real Godot Dummy audio driver is selected and the host reports the missing capability. An ordinary multisampled canvas selects Emscripten's built-in shader presentation path, avoiding that runtime's repeated framebuffer-blit error. No fake WebAudio or WebGL APIs are substituted. Chromium exercises real browser audio APIs.

Real iPhone/iPad testing remains important for physical audio playback, browser-bar changes, safe areas, split view and background/foreground behavior.

To render reference screenshots from the native development scene:

```powershell
node tools\run-godot.cjs --path . --audio-driver Dummy --rendering-driver opengl3_angle --script res://tests/godot/render_scenes.gd
```

On Windows, this uses ANGLE rendering and the Dummy audio driver so screenshot generation does not require a physical sound device. Screenshots go to the ignored `build\visuals` directory. `.godot` and exported build products are not committed; import metadata and source assets are maintained.

The migration plan is `docs\superpowers\plans\2026-09-07-godot-web-migration.md`. The previous HTML implementation remains available in Git history at `e8b3771`.
