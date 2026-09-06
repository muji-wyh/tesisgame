# Godot Web Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the HTML game implementation with a Godot game exported to Web, using the supplied animated-chest artwork and retaining the established English learning game.

**Architecture:** Godot owns gameplay, controls, audio, chest animation and effects. A custom HTML export shell only hosts the engine canvas, handles browser sizing/loading/accessibility preferences, and provides integration with an existing website. The delivered directory is `build\web`; it is a static website, not a native application and not the old JavaScript game inside a Godot wrapper.

**Tech Stack:** Installed Godot 4.7 stable, GDScript, Compatibility rendering, single-threaded Web export, existing Node test runner and Playwright. No backend or external runtime services.

---

## Locked decisions

- Continue on `feat-seasonal-word-buddies`; the completed HTML baseline is preserved in commit `e8b3771`.
- Keep `words.json` as the sole vocabulary source and reuse all existing word pictures, voices, rewards, failure artwork, SFX and BGM.
- The provided free demo contains three designs. Spring and autumn use differently tinted Royal chests, summer uses Energy, and winter uses the reconstructed multipart Crystal chest. All four retain their distinct music, speech, sounds, colors and effects.
- Copy only 19 selected PNGs. Preserve source bytes and provenance; do not copy Unity executables, scripts, materials, prefabs or `.meta` files into the Godot runtime.
- Use a 480-unit minimum canvas dimension with expanding aspect ratio. Minimum control size is 72 units, equivalent to 48 CSS pixels at a 320-pixel minimum viewport dimension.
- Portrait uses two columns/four rows; landscape or square uses four columns/two rows. No scrolling, cropped pictures or automatic orientation reset.
- Web export is single-threaded and uses Compatibility/WebGL 2. Do not introduce shared-array-buffer or cross-origin-isolation requirements.
- The export shell handles safe-area insets and dynamic viewport changes. Browser motion preferences and a manual Reduce motion menu item are supported.
- The maintained HTML source is an export shell, not a second gameplay implementation. Old HTML-only tests will be replaced rather than counted as proof of the port.

## File ownership and boundaries

| Files | Responsibility |
|---|---|
| `project.godot`, `scenes\main.tscn` | Engine settings and main Control scene |
| `scripts\game_model.gd` | Pure round state, card creation, matching, thresholds and reward lock |
| `scripts\game_data.gd` | JSON loading/validation, four theme definitions, imported chest manifest |
| `scripts\game_ui.gd` | Native controls, responsive layout, feedback timer and presentation wiring |
| `scripts\word_card.gd` | Image/word button with stable touch bounds and fitted text |
| `scripts\ui_style.gd` | Shared readable typography and control styles |
| `scripts\game_audio.gd` | Three reusable native audio players, loops, ducking, mute and lifecycle |
| `scripts\chest_view.gd` | Imported complete poses/multipart assembly and native opening animation |
| `scripts\celebration.gd` | Bounded native light layers, rings and 72 distributed particles |
| `assets\chests\**`, `tools\import-chests.cjs` | Selected source artwork, manifest and repeatable import |
| `web\shell.html`, `export_presets.cfg` | Browser host and reproducible Web export settings |
| `tools\build-web.cjs`, `tools\run-godot.cjs`, `tools\prepare-godot.cjs` | Import/export orchestration, real process exit handling and build-directory preparation |
| `tests\godot\run_tests.gd` | Actual GDScript model, resource and UI lifecycle/layout assertions |
| `tests\browser\godot.spec.cjs` | Actual exported-engine loading, input, resizing, embedding and touch-to-reward play |
| `tests\assets.test.cjs`, `tests\chest-assets.test.cjs` | Reused generated media and imported PNG contracts |
| `README.md`, `package.json`, `.gitignore`, `.gitattributes` | Web-first run/deploy commands and reproducible source metadata |

## Task 1: Import the chest artwork

- [x] Write standalone `node:test` coverage for the absent manifest and selected PNGs; run it and observe missing-file failures.
- [x] Implement the importer and run it against the user-provided source directory.
- [x] Parse only the nine Crystal SpriteRenderer records and their ancestor transforms. Preserve Unity file IDs as strings. Convert the composed y-up matrix to y-down pixel coordinates:

```javascript
function godotTransform(world, pixelsPerUnit) {
  const unit = 100 / pixelsPerUnit;
  return [
    world[0] * unit, -world[1] * unit,
    -world[2] * unit, world[3] * unit,
    world[4] * 100, -world[5] * 100
  ];
}
```

- [x] Record texture dimensions, source-relative paths, SHA256, pivots, sorting orders and flips. Reject missing/duplicate parts, unsupported transforms, and differing existing destination files.
- [x] Run `node --test tests\chest-assets.test.cjs`. Expected: every imported-file/manifest test passes and rerunning the importer preserves bytes.

## Task 2: Establish the engine and state-machine contract

- [x] Add `tests\godot\run_tests.gd` with executable assertions against the real GDScript model. Before implementation, `godot --headless --path . --script res://tests/godot/run_tests.gd` must fail because the model is missing.
- [x] Set the project main scene to `res://scenes/main.tscn`; use these engine settings:

```ini
[display]
window/size/viewport_width=480
window/size/viewport_height=480
window/size/window_width_override=960
window/size/window_height_override=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/default_filters/use_nearest_mipmap_filter=false
textures/vram_compression/import_s3tc_bptc=true
textures/vram_compression/import_etc2_astc=true
```

- [x] Model state is `waiting`, `matching`, `feedback`, `won` or `lost`. Each reset samples five distinct words, creates three complete pairs plus one unmatched word and one unmatched picture, then shuffles eight stable card IDs.
- [x] Selecting the current card cancels. Same-kind selection replaces it without penalty. Opposite kinds score only when IDs match. During feedback, all input is locked; resolving feedback either resumes waiting or ends at three successes/mistakes.
- [x] Keep reward state in the model: `closed`, `opening`, `opened`, with a captured reward theme. Theme changes during opening are rejected; later changes cannot mutate the earned reward.
- [x] Validate JSON before creating cards: array, at least five entries, unique IDs/text/images, lowercase 2-6-letter words, and safe local image/audio paths. Errors are explicit English messages.
- [x] Run the native test command through `node tools\run-godot.cjs --headless --path . --script res://tests/godot/run_tests.gd`. Expected: deterministic shuffle, distractor, selection, counter, theme and one-shot reward assertions pass, with the real Windows process status propagated.

## Task 3: Build the native touch interface and audio

- [x] Extend native tests to instantiate the actual main scene, activate Button signals/input, and inspect bounds at the documented viewport sizes.
- [x] Build one full-rect Control with background, safe margins, header, score row, board/result area and feedback/status labels. Header includes theme/motion menu, Mute and Listen.
- [x] Create eight persistent button slots for a round. Image controls ignore intrinsic minimum size and preserve aspect. Word labels fit their allotted cell. Matched cards remain in position.
- [x] Use a single 700ms feedback Timer. Stop it on replay; callbacks must first confirm the current model phase.
- [x] Winning displays the selected seasonal chest; losing displays the existing encouraging bear, English message, loss sound and voice. Replay resets the model, card controls, animation and audio while preserving mute/motion preferences.
- [x] Use three AudioStreamPlayers. Music gain is 0.12, effect gain 0.24 and voice gain 0.64, with music ducked to 0.04 during speech. Duplicate looping WAV streams before assigning loop points, so shared resources are not mutated.
- [x] Start audio only after interaction. Stop all channels on page hiding/mute/reset; Listen explicitly resumes after hiding. Missing/unsupported audio produces a visible English status rather than a silent failure.
- [x] Run the native tests at 320x320, 375x667, 390x844, 430x932, 844x390, 768x1024, 834x1194, 1194x834, 1024x1366 and 507x1024. Expected: controls remain in bounds and the game state survives resizing.

## Task 4: Port the chest presentation and celebration

- [x] Add assertions for complete-pose textures, nine-part Crystal assembly, opening duration, cancellation and one-shot completion.
- [x] Royal/Energy render aligned closed/open images. Crystal uses the imported matrices, pivots and draw ordering; fit the assembled rest bounds, not nine individually centered images.
- [x] Animate the visual artwork only, not the clickable Control. Opening charges, moves the artwork, changes pose and reveals the reward at 1.8 seconds. Crystal trim parts separate using their original rest transforms.
- [x] Celebration uses imported glow, ray, ring, spark, burst and orb textures plus generated seasonal reward tokens. Each particle category independently spans the full circle:

```gdscript
func particle_angle(index: int, count: int) -> float:
    return TAU * float(index) / float(count)
```

- [x] Emit twelve seasonal tokens, thirty-six sparks and twenty-four confetti pieces. Add bounded light rays, a light column, two expanding rings and a reward medallion. Fade/clear all effects within 4.8 seconds.
- [x] Reduced motion reveals the final reward immediately without moving particles. Replay, hiding and theme changes clear transient effects; stale opening work cannot award a new round.
- [x] Run the native tests and inspect rendered examples of all four seasonal chests, including the assembled Crystal and opening peak.

## Task 5: Export and host the real Godot Web game

- [x] Add browser tests that initially fail because no exported engine exists.
- [x] Configure one runnable `Web` preset with `variant/thread_support=false`, `variant/extensions_support=false`, and explicit inclusion of `words.json` and `assets/chests/manifest.json`.
- [x] Exclude tests, tools, documentation, Node dependencies and build outputs from the exported pack. Add `.gdignore` where needed to avoid engine scanning of non-game trees.
- [x] Maintain `web\shell.html` as the only HTML host source. Use `$GODOT_URL` and `$GODOT_CONFIG` substitution, an English loading/error overlay, a full-size canvas, and a one-way engine-ready notification from the actual scene.
- [x] Size the canvas to its safe-area container with a ResizeObserver and explicit canvas policy; preserve browser zoom. Subscribe to visibility and reduced-motion changes through a small host bridge, without duplicating gameplay or exposing mutation/cheat APIs.
- [x] Build with the installed matching templates:

```powershell
godot --headless --path . --import
godot --headless --path . --export-release Web build\web\index.html
```

Expected: an actual Godot-generated HTML/JavaScript/WebAssembly/PCK distribution.

- [x] Make `npm start` build and serve `build\web` on port 4173; provide a separate build command for deployment.
- [x] Exercise the exported game in Chromium at desktop/phone/tablet dimensions, test browser input and page resizing, and load it inside an iframe. Report any Windows WebKit platform capability limitation honestly rather than replacing WebGL/audio with fake APIs.

## Task 6: Retire the old runtime and document delivery

- [x] Remove the old HTML gameplay entry and obsolete inline-JavaScript tests after the Godot replacement works. Keep generated-asset tests but decouple them from HTML extraction and allow Godot `.import` sidecars.
- [x] Update README with engine/template prerequisites, Web-first start/build commands, static-host deployment, iframe integration, vocabulary rebuilding, source provenance and real-device limitations.
- [x] Run the native suite, asset suite and exported-browser suite against the final files.
- [x] Inspect the final diff and resolve actual defects; do not modify unrelated user changes.
- [x] Commit the migration on the current feature branch with the required Copilot co-author trailer. Do not push or merge automatically.

## Completion criteria

The persistent repository opens as a Godot project, exports successfully with the installed engine, and serves a playable Godot Web game. All original gameplay rules are exercised against GDScript, the chest art comes from the selected pack, and the four themed rewards are visibly distinct. The delivered Web folder is usable standalone or as an iframe; no native app installation is required for players.

## Integration findings

- Windows GUI executables do not reliably propagate their status through a bare PowerShell invocation. The Node runner waits for the engine process and also treats printed Godot script/export errors as failure.
- The desktop/mobile export texture options require matching S3TC and ETC2/ASTC import settings.
- The supplied PNGs are preserved byte-for-byte, including documented trailing IEND data; the engine imports their image payloads. Crystal's 0.67 ancestor scale and 0.85 base X scale are retained.
- Godot 4.7's JavaScript init wrapper does not forward every WASM promise rejection. The shell handles download rejection directly and surfaces WASM compile/runtime failures instead of leaving an endless loader.
- Windows WebKit has no AudioContext or OffscreenCanvas. The host uses the real Dummy audio driver and a standard multisampled WebGL canvas, selecting Emscripten's existing shader presenter rather than its failing framebuffer-blit path.
- Native screenshots use ANGLE and Dummy audio in this environment. They are stored under `build\visuals`, isolated from Playwright's output cleanup.
- Hiding during opening finalizes the earned reward without leaving a queued pop tween. Rounded panel masking bounds the effects; the disabled theme label keeps readable text.
- Accessibility announcements expose only visible/selected information. The browser reward flow discovers cards through actual touch selections and these announcements, with no gameplay mutation hooks.
- Independent review identified native startup exits and unprotected engine autofocus as additional integration cases. Invalid PCK contents now surface an error/retry through `onExit`; initial focus is owned by the shell's `preventScroll` call. Real browser cases cover both behavior paths, including a below-the-fold iframe.
