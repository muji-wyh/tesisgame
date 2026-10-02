# Development and deployment

Maintained build, hosting, and validation instructions. Run commands from the
repository root. See the [project README](../README.md) for the short setup path.

## Run and build

Development prerequisites: **Godot 4.7**, its matching **Web export templates**, and **Node.js 24**. The `godot` executable must be on PATH; alternatively, set `GODOT_BIN` to its executable path.

Restore the licensed [Talk Quest character build inputs](assets/talk-quest-monsters.md#provenance-and-reproducibility)
and [animated chest inputs](voice-pop-treasure.md#shared-chest-catalog)
before importing or building a fresh checkout. Their models and portraits remain
local and are bundled into the compiled game; they are not stored in Git.

The three Unity-derived treasure particles also remain private build inputs.
Restore the prepared `halo.png`, `ray.png`, and `sparkle.png` files to
`assets/talk_quest/treasure/` from the licensed local asset copy before import.
The [treasure artwork record](../assets/talk_quest/treasure/SOURCE.md) identifies
the acquired package, original texture paths, and preparation dimensions;
`assets/talk_quest/treasure/manifest.json` records the expected prepared hashes.
Godot regenerates their ignored import metadata when importing the project.

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

Default speech recognition needs no model preparation or additional game download.
The opt-in `?speechLocal=1` experiment can prepare a browser-managed English
language pack; see [speech matching](voice-matching.md).
For an untimed, unscored real-device comparison, open with `?speechDebug=1`
and choose **Speech check** after entering the game. The diagnostic panel can
compare the actual game sounds at normal, reduced, and silent levels and
copy an in-memory report; see the same speech guide for the test procedure.
Rebuilding an older export removes its generated local speech models and retired
multiplayer and voice-profile scripts while preserving unrelated output files.

The build fingerprints engine files and the game pack independently, then generates Brotli
sidecars with Node's built-in compressor. Azure serves the compressed variants automatically;
uncompressed files remain available for other clients. Hashed assets can be cached for a year
without mixing old and new game versions, and game-only changes reuse the same engine URL.
HTML revalidates so returning players discover updates. Each build removes obsolete generated
asset names without deleting unrelated files in the output directory.

Rebuilds reuse Brotli sidecars only when decompressing the complete sidecar reproduces
the current source bytes. Missing, stale, truncated, or otherwise invalid caches are
recompressed. After verifying the exported game pack and packaging all files, a
successful build writes `build/web-build.json` outside the published directory.
This receipt fingerprints runtime inputs, including local licensed assets, and
every output file. A failed build invalidates the previous receipt.

Chest and illustration textures use 85%-quality WebP imports at their existing resolution.
The original SVG/PNG artwork is unchanged. This reduces the game-pack download without
removing words or artwork, or adding image requests during play.

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
game effects, Pip sounds, eight background tracks, ten game prompts and
88 themed chest cues. Retired Voice Pop report recordings are excluded.
Once startup finishes, playback needs no further audio downloads. The build opens the actual exported
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
Before contacting Azure, it checks the successful build receipt against current
sources and outputs, and requires every engine/game file and compressed sidecar.
It does not commit or push Git changes.

To publish an export you have already built:

```powershell
npm run deploy -- -SkipBuild
```

`web\staticwebapp.config.json` supplies engine MIME types, immutable caching for hashed assets,
and `Cache-Control: no-cache` for HTML and other unversioned files. `Vary: Accept-Encoding`
keeps compressed and uncompressed responses distinct in caches. The build copies this
configuration into the export; the deployment script also explicitly selects the source
configuration. `-SkipBuild` refuses absent, stale, altered, or incomplete builds.
Omit it after changing runtime sources or import settings. Keep unrelated files
out of `build/web`; the entire directory is published.

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

## Development

```powershell
npm test
npm run test:browser
npm run test:all
```

`npm test` imports resources and runs each native and Node suite once. Use
`node tools/run-tests.cjs --list` to inspect the complete plan, or a focused
command such as `npm run test:voice-pop`, `npm run test:talk-quest`, or `npm run test:pip-audio` during
development. Browser checks remain in `npm run test:browser`.

For Talk Quest's model, character, scene, and browser-host tests, followed by its
focused exported-game browser checks:

```powershell
npm run test:talk-quest
npm run test:browser -- talk-quest.spec.cjs
```

The browser command rebuilds the Web export and runs the Talk Quest scenarios
across the configured Chromium and WebKit profiles. Run imports, native tests,
exports, and browser jobs sequentially against one checkout. The
[Talk Quest reference](talk-quest.md) describes finite word encounters, speech
attacks, reward commits, and private checkpoints covered by these suites.

The native suite exercises actual GDScript state transitions, distractors, independent thresholds, reward locking and persistence, audio lifecycle, resource loading, seasonal palettes, responsive Control bounds and scene wiring. Node tests cover generated media, texture import settings, imported chest files, Web-export contracts and deployment-script failure handling. Playwright runs the **exported Godot engine**, including touch input, resizing, browser audio, bundled playback without further audio downloads, stale-playback suppression, the interactive loader, interrupted downloads, loading errors and iframe embedding.

The [historical design index](superpowers/README.md) preserves earlier
research, plans, and decisions, including retired modes and collectible UI.
Use the [current documentation index](README.md) for maintained behavior
and the [QA index](qa/README.md) for dated evidence and its limitations.

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
