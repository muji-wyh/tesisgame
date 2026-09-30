# Pip and Words

A Godot game delivered as a static website for early English learners. Gameplay,
audio, animations, and local progress run on the device. The browser shell
handles loading, accessibility, audio recovery, and speech recognition.

[Play the deployed game](https://gentle-forest-02ff42900.3.azurestaticapps.net/)

## Current game

- **Match:** five word-picture pairs, three hints, and optional spoken answers.
- **Memory:** five hidden pairs, with a hold-to-peek control and no countdown.
- **Voice Pop:** select a local player, then speak visible words during a
  50-second round. The second consecutive hit adds 3 seconds; the third adds
  5 seconds. Occasional volleys throw several words together. Cards do not collide.
- **Players and leaderboards:** up to ten names and emoji avatars on the current
  device. First-time entry requires creating a player. Voice Pop selects the
  player before each round and saves the result automatically; Match and Memory
  attribute results afterward. Personal bests rank separately for each mode.
- **Eight worlds and 350 words:** choose a theme during loading or in Pip's room.
  Age preferences guide the vocabulary; they do not collect a birthdate.
- **Chests and toys:** winning Match or Memory advances saved gift progress.
  The chest has a five-second performance; releasing before the visible lid
  release cancels it. A temporary flying gift is cosmetic. Earned toys remain
  playable in Pip's room.

Voice Pop uses `SpeechRecognition` or `webkitSpeechRecognition` by default.
Browser support, a secure page, microphone permission, and a functioning speech
service are required; the browser may process audio remotely. The game does not
save microphone recordings or transcripts. Word matching accepts explicit
homophones and guards revised recognition events against duplicate hits.
The `?speechLocal=1` experiment exposes optional browser-managed on-device
English preparation. It remains off by default and does not bundle a WASM
speech model. Automated speech tests do not establish acoustic accuracy.

All game audio ships in the initial game pack. Browsers still require a trusted
interaction to enable playback. Pip ignores another manual tap until the
current action and call finish. Reduced motion keeps readable state and simpler
feedback. Touch, keyboard, and Xbox controller input share the game controls.

Detailed rules and behavior:

- [Gameplay reference](docs/gameplay.md)
- [Local players and leaderboards](docs/local-leaderboards.md)
- [Speech matching and the local experiment](docs/voice-matching.md)
- [Voice Pop slice feedback](docs/voice-pop-slice-feedback.md)
- [Chest timing, sound, and input handling](docs/assets/chest-feel.md)

## Run and build

Install **Godot 4.7**, its matching **Web export templates**, and **Node.js 24**.
Put `godot` on PATH or set `GODOT_BIN` to the executable path.

```powershell
npm ci
npm start
```

This imports resources, exports the game, and serves it at
`http://127.0.0.1:41773`. To build or serve separately:

```powershell
npm run build:web
npm run serve:web
```

The complete `build/web` directory is the deliverable. Deploy all engine,
game-pack, worklet, configuration, and Brotli files together to a static HTTPS
host; do not open the export with `file://`. Hashed assets support immutable
caching, while HTML revalidates. The single-threaded Compatibility export needs
WebGL 2, without SharedArrayBuffer or cross-origin isolation.

The maintained shell is `web/shell.html`; exported HTML is generated. Edit the
native project through `project.godot`. Source assets and import metadata are
maintained; `.godot`, exports, and QA captures are local build products.

## Verify

```powershell
npm test
npm run test:browser
```

`npm test` imports and runs each native and Node suite once. Browser testing
builds and exercises the exported Godot game. Run Godot imports, native tests,
exports, and browser jobs sequentially against one checkout. To inspect or run
focused suites:

```powershell
node tools/run-tests.cjs --list
npm run test:voice-pop
npm run test:leaderboards
npm run test:chest-charge
```

Browser speech fixtures inject recognition results instead of recording a
microphone. WebKit emulation does not verify physical Safari audio, keyboards,
or recognition accuracy. Real-device checks remain necessary.

## Deploy

With Azure CLI signed in and the Static Web Apps CLI installed:

```powershell
npm run deploy
```

The script builds and publishes to the configured `tesisgame` Azure Static Web
App. It verifies the target and keeps the deployment token in the process
environment. It does not commit or push Git changes. Use
`npm run deploy -- -SkipBuild` only when the complete export already reflects
the intended source.

See [development and deployment](docs/development.md) for the hosting target,
iframe permissions, cache behavior, audio recovery, and detailed verification.

## Source and documentation

`words.json` is the canonical vocabulary. Recorded pronunciations use Microsoft
Jenny Neural; generating new recordings requires Azure Speech credentials and
FFmpeg, while ordinary builds and playback do not. Some optional artwork and
sound overrides come from user-provided licensed sources and remain outside
Git. Clean checkouts use the tracked fallbacks. Their rights are independent
of the repository's code license.

- [Documentation index](docs/README.md): current references and source ownership.
- [Asset index](docs/assets/README.md): generation, import workflows, and provenance.
- [Dated QA evidence](docs/qa/README.md): scope, outcomes, and known limitations.
- [Historical plans](docs/superpowers/README.md): prior designs, including removed features.
- [Changelog](changelog.md): historical changes, not a list of current features.

Medals and Words collection pages, Learn/Sky/Listen modes, speaker enrollment,
and multiplayer recognition have been retired. Saved reward, toy, and legacy
preference data remain for compatibility; local player profiles do not store
voiceprints. Historical documents must not be used as instructions to restore
retired features.
