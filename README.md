# Grow with Pip

A Godot game delivered as a static website for early English learners. Gameplay,
audio, animations, and local progress run on the device. The browser shell
handles loading, accessibility, audio recovery, and speech recognition.

[Play the deployed game](https://gentle-forest-02ff42900.3.azurestaticapps.net/)

## Current game

- **Match:** five word-picture pairs, hint purchases at 100, 150, then 200 coins with no per-round use limit, optional spoken answers and unlimited retries.
- **Memory:** five hidden pairs, with a click-to-peek eye that reveals cards for 10 seconds on the first use in each round and 5 seconds on later uses. Mismatched cards stay face up until a card is clicked; choosing a different hidden card also starts the next selection.
- **Phrase Builder:** listen, drag pictured or contextual word tiles into order, and complete three phrases to earn a chest. Everyday English uses the current learning age from a catalog of 330 recorded phrases; Professional English uses the selected module. Earlier everyday words appear only as prerequisites for those phrases. Retries are unlimited.
- **Voice Pop:** speak visible words during a 50-second round. Marked targets supply fragments that unlock and upgrade one chest. Results retain scores, chest progress and word review.
- **Jelly Match:** drag falling pictures onto their words in a four-column well. Matching jellies merge, bounce away, and credit one learning success. Make room before the eight-second full-board countdown ends; marked pairs earn chests. The pace increases as pairs are cleared. Earned treasure is saved when the round ends or you change modes.
- **Jelly Words:** build words from reviewed roots, then match their pictures in a five-column, eight-row well. Image-free words become merged when complete. Merge identical words, including different levels, to add their levels up to Lv6; a total above six stays separate. Every stage keeps the ordinary rounded-square size and 1:1 aspect ratio. The six levels have distinct collection effects and audio, including staged Lv4 fireworks. Tap to collect all carried chest fragments. Lv1 gives no bonus coins; Lv2–6 increase the bonus chance and amount, from 2% for 50 coins to 16% for 250 coins. Collect gathers ready words at 140 ms intervals. Auto merge launches an eligible pair every 200 ms with overlapping 250 ms flights. Manual learning credit is recorded only on collection; automatic merges and image-free atomic exposure do not earn mastery.
- **Growth:** everyone starts at Lv0 with Baby Pip. Each word needs three consecutive correct answers in any applicable mode. A wrong answer resets the involved words. First-time word mastery increases Lv up to Lv99; mastering the entire current age cohort grows Pip and unlocks the next cohort, through Age 12+. Earned levels and ages never decrease.
- **Word Library:** Everyday English and Professional English share Grow with Pip. Select a career/module and use its vocabulary on the same Home, with a dedicated Pip outfit and a level based on earned mastery in that career. Switching back restores everyday Pip and progress. Modules still in preparation are clearly marked and cannot start a game. For everyday vocabulary, the progress bar opens all words in a selected age cohort, including saved mastery and pronunciation. Other ages load when viewed; the next age preloads at 90% mastery of the current cohort. Gameplay uses only current-age questions. Later ages can be previewed but cannot be selected to skip progression. The 1,550-word curriculum is an editorial English-as-a-second-language sequence, not a developmental assessment.
- **Pip:** ten stage appearances and cumulative action repertoires accompany growth. Run `npm run preview:pip` to review the assets at [localhost](http://127.0.0.1:41774/). The asset preview is not published with the game.
- **Settings and treasure:** the selected vocabulary supplies the garden or workplace setting. Three-second round celebrations and existing chest rewards remain available. Usernames, identity avatars, leaderboards and Pip's room have been retired.

Voice Pop uses `SpeechRecognition` or `webkitSpeechRecognition` by default.
Browser support, a secure page, microphone permission, and a functioning speech
service are required; the browser may process audio remotely. The game does not
save microphone recordings or transcripts. Word matching accepts explicit
homophones and guards revised recognition events against duplicate hits.
The `?speechLocal=1` experiment exposes optional browser-managed on-device
English preparation. It remains off by default and does not bundle a WASM
speech model. Automated speech tests do not establish acoustic accuracy.

Startup opens the shared Home before downloading vocabulary media. Everyday play
or browsing loads the current learning age's pictures, animations and recorded
words on demand. The next age preloads at 90% mastery of the current age; browsing
another age downloads that age on demand. Shared music and game
effects remain in the core pack. Browsers still require a trusted interaction
to enable playback. Pip ignores another manual tap until the
current gesture finishes. Reduced motion keeps readable state and simpler
feedback. Touch, keyboard, and Xbox controller input share the game controls.

Detailed rules and behavior:

- [Gameplay reference](docs/gameplay.md)
- [Voice Pop treasure and shared chest models](docs/voice-pop-treasure.md)
- [Growth rules and persistence](docs/growth-system.md)
- [Pip stage art and voices](docs/assets/pip-growth.md)
- [Speech matching and the local experiment](docs/voice-matching.md)
- [Voice Pop slice feedback](docs/voice-pop-slice-feedback.md)
- [Chest timing, sound, and input handling](docs/assets/chest-feel.md)

## Run and build

Install **Godot 4.7**, its matching **Web export templates**, and **Node.js 24**.
Put `godot` on PATH or set `GODOT_BIN` to the executable path.

Before building a fresh checkout, restore the licensed
[animated chest inputs](docs/voice-pop-treasure.md#shared-chest-catalog).
These models stay local and ship inside the compiled game pack.

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
core and vocabulary packs, worklet, configuration, and Brotli files together to a static HTTPS
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
node tools/run-tests.cjs growth
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
environment. It does not commit or push Git changes. A successful build records
source and output fingerprints outside the published directory. Use
`npm run deploy -- -SkipBuild` to publish that verified export; deployment refuses
missing, stale, altered, or incomplete builds before contacting Azure.

See [development and deployment](docs/development.md) for the hosting target,
iframe permissions, cache behavior, audio recovery, and detailed verification.

## Source and documentation

`words.json` is the canonical vocabulary. All 1,550 recorded pronunciations and eight
spoken prompts use the approved Microsoft Ava Neural voice (`-15%` rate, `+8Hz`
pitch). [Voice regeneration](docs/assets/ava-voice.md) uses Python, `edge-tts`,
and FFmpeg; ordinary builds and playback use the bundled WAVs offline. Some optional artwork and
sound overrides come from user-provided licensed sources and remain outside
Git. Clean checkouts use the tracked fallbacks. Their rights are independent
of the repository's code license.

- [Documentation index](docs/README.md): current references and source ownership.
- [Asset index](docs/assets/README.md): generation, import workflows, and provenance.
- [Dated QA evidence](docs/qa/README.md): scope, outcomes, and known limitations.
- [Historical plans](docs/superpowers/README.md): prior designs, including removed features.
- [Changelog](changelog.md): historical changes, not a list of current features.

Talk Quest, Medals and Words collection pages, Learn/Sky/Listen modes, speaker
enrollment, and multiplayer recognition have been retired. Saved reward and legacy
preference data remain for compatibility; local player profiles do not store
voiceprints. Historical documents must not be used as instructions to restore
retired features.
