# Word Buddies

An English picture-and-word matching game for early learners. It uses one HTML page, a separate JSON vocabulary, and local artwork and audio.

## Run

Use Node.js 24:

```powershell
npm ci
npm start
```

Open `http://127.0.0.1:4173`. Serve the folder over HTTP rather than opening `index.html` as a file: the game loads its vocabulary and media from local URLs. No backend API, cloud speech service, or external image service is needed.

## Play

Find three matching word/picture pairs among **eight cards**. Two extra cards (one word and one picture) have no matching partner. Three correct matches win; three mistakes end the round. Clicking another card of the same kind changes the selection without a penalty. Clicking the selected card cancels that selection.

Each round starts with a random **Spring**, **Summer**, **Autumn**, or **Winter** theme. The theme selector changes the appearance and music without resetting progress. The winning chest follows the selected theme.

Opening a chest locks that reward's theme. Its short charge-and-reveal sequence combines light rays, an energy beam, expanding rings, 72 seasonal particles, and a popping reward medallion. Theme switching is briefly disabled during opening; afterward, changing the page theme does not change the earned reward or grant another one. Reduced-motion mode reveals the reward without the moving effects.

Use **Mute** and **Listen** to control sound. Audio starts only after interaction. If playback is blocked, tap Listen to retry. **Play again** starts a fresh round.

## Vocabulary and original assets

`words.json` is the only vocabulary list. Keep at least five entries so every round can include three pairs and two distinct distractors. Each entry provides:

| Field | Purpose |
|---|---|
| `id` | Unique stable identifier. |
| `text` | A lowercase English word, initially limited to 2–6 letters for readable cards. |
| `image` | Local image URL under `assets/images/words/`. |
| `audio` | Local pronunciation URL under `assets/audio/voice/`. |

Word images are original SVG illustrations in one directory, `assets\images\words`. Reward artwork, chest animations, particles, synthesized sound effects, and English scripts are also original generated assets.

Regenerate the images, sound effects, and prerecorded voices with:

```powershell
node tools\generate-images.cjs
node tools\generate-sfx.cjs
powershell.exe -NoProfile -File .\tools\generate-voices.ps1
```

Voice generation uses **Microsoft Zira Desktop (en-US)** on Windows. Players only need the resulting WAV files, not that voice installed on their device. Edit `voice-prompts.json` to change the English prompts.

Adding a word requires its JSON entry, an original image, and regenerated pronunciation audio. Update the image generator when adding artwork so regeneration preserves it. Reload the page after changing the vocabulary; do not add a second word list to the HTML.

## Background music

Four tracks were copied from the user-provided **Casual Game Music Pack 1.4**:

| Theme | Source track | Local file |
|---|---|---|
| Spring | Flower-Menu-Loop | `assets\audio\bgm\spring.wav` |
| Summer | Ukulele-Menu-v1-Loop | `assets\audio\bgm\summer.wav` |
| Autumn | Banjo-Menu-Loop | `assets\audio\bgm\autumn.wav` |
| Winter | Space-Menu-Loop | `assets\audio\bgm\winter.wav` |

Confirm the music pack's distribution permissions before publishing its tracks. The source pack is not modified.

## Responsive and accessible interaction

The layout targets phones and tablets, including iPhone and iPad Safari. It supports portrait and landscape layouts, safe areas, reduced motion, touch controls, and keyboard activation. Theme changes and device rotation preserve the current game.

WebKit device emulation does not replace real-device testing. Real iPhone/iPad checks should include browser-bar changes, Home Indicator clearance, split view, audio playback, and background/foreground transitions.

The Windows WebKit test build does not expose `AudioContext`. Media-error scenarios supply an audio-graph stand-in, while Chromium and unit tests exercise the graph implementation. Real Safari playback still needs confirmation on a device.

## Development

```powershell
npx playwright install chromium webkit
npm test
npm run test:browser
npm run test:all
```

The browser suite covers desktop Chromium and iPhone/iPad WebKit profiles. Tests include matching, independent cumulative counters, theme persistence, one-shot rewards, responsive bounds, generated media, and loading/playback failures.

The implementation plan is in `docs\superpowers\plans\2026-09-06-seasonal-word-match.md`.
