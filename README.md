# Word Buddies

A **Godot game delivered on the Web** for early English learners. Gameplay, cards, audio, chest animation and celebrations run in GDScript. The HTML shell only hosts the exported engine and integrates browser sizing, accessibility announcements and lifecycle events.

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

The deliverable is **the entire `build\web` directory**. Keep its HTML, JavaScript, WebAssembly, PCK, audio-worklet and icon files together. Deploy that directory to a static HTTPS host; do not deploy just the HTML file or open it using `file://`. The host must serve `.wasm` as `application/wasm`.

The Web preset uses Compatibility rendering, WebGL 2 and single-threaded export. It does not require SharedArrayBuffer, COOP/COEP headers, a service worker or cross-origin isolation. When updating a deployment, replace the complete export and invalidate old cached files, or use a versioned deployment directory.

To serve an existing export without rebuilding:

```powershell
npm run serve:web
```

For development in the editor, open `project.godot`. The maintained browser shell is `web\shell.html`; `build\web\index.html` is generated and should not be edited.

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

Find three matching word/picture pairs among **eight cards**. One extra word and one extra picture have no matching partner. Three correct matches win; three mistakes end the round. Clicking another card of the same kind changes the selection without a penalty. Clicking the selected card cancels it. Both counters accumulate independently.

Each round starts with a random **Spring**, **Summer**, **Autumn** or **Winter** theme. The season menu changes the appearance and music without resetting progress; it also contains **Reduce motion**.

The winning chest follows the selected theme. Opening it captures that reward's theme and starts a 1.8-second charge-and-reveal sequence with imported chest artwork, native light layers, two expanding rings, 72 seasonal particles and a reward medallion. Themes have different particle trajectories, palettes, music, effects and English speech. Theme switching is disabled during opening. Later theme changes do not alter the earned reward or grant another one.

Reduced motion reveals the reward immediately without moving effects. **Mute**, **Listen** and **Play again** control audio and replay. Audio waits for interaction and stops on hiding, muting, loss or reset; returning from a hidden page does not force autoplay. The loss screen uses the encouraging bear, a gentle effect and prerecorded English speech.

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

Edit `voice-prompts.json` to change the spoken prompts. When adding a word, add its image-generation definition, JSON entry and pronunciation recording. Run `npm run build:web` afterward: the vocabulary and imported media are packaged into Godot's PCK, not fetched from a second runtime word list.

## Chest artwork

Selected artwork is imported from the user-provided **Modern 2D Animated Chests Pack_FREE Demo 1.0.2**. Its three source designs become four seasonal treatments:

| Season | Source chest | Treatment |
|---|---|---|
| Spring | Royal | Green-tinted gold, pink/green flower burst and fluttering petals. |
| Summer | Energy | Warm gold, bright sun rays and outward-spinning sparks. |
| Autumn | Royal | Warm amber tint, falling leaves and drifting confetti. |
| Winter | Crystal | Nine-part assembled chest, icy orbiting snowflakes and crystal light. |

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

The chest artwork and music retain their providers' terms; this repository's code license does not grant additional rights to those assets. Confirm distribution permissions before publishing them. The original source packs are not modified.

## Development

```powershell
npm test
npm run test:browser
npm run test:all
```

The native suite exercises actual GDScript state transitions, distractors, independent thresholds, reward locking, audio lifecycle, resource loading, responsive Control bounds and scene wiring. Node tests cover generated media, imported chest files and Web-export contracts. Playwright runs the **exported Godot engine**, including touch input, resizing, browser audio, loading errors and iframe embedding.

The Windows Playwright WebKit runtime exposes WebGL 2 but not AudioContext or OffscreenCanvas. In that environment the real Godot Dummy audio driver is selected, and Listen reports the missing capability. An ordinary multisampled canvas selects Emscripten's built-in shader presentation path, avoiding that runtime's repeated framebuffer-blit error. No fake WebAudio or WebGL APIs are substituted. Chromium exercises real browser audio APIs.

Real iPhone/iPad testing remains important for physical audio playback, browser-bar changes, safe areas, split view and background/foreground behavior.

To render reference screenshots from the native development scene:

```powershell
node tools\run-godot.cjs --path . --audio-driver Dummy --rendering-driver opengl3_angle --script res://tests/godot/render_scenes.gd
```

On Windows, this uses ANGLE rendering and the Dummy audio driver so screenshot generation does not require a physical sound device. Screenshots go to the ignored `build\visuals` directory. `.godot` and exported build products are not committed; import metadata and source assets are maintained.

The migration plan is `docs\superpowers\plans\2026-09-07-godot-web-migration.md`. The previous HTML implementation remains available in Git history at `e8b3771`.
