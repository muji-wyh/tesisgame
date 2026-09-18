# Eight fruit-slice hit sounds

Voice Pop now chooses from the eight finished mixes in
`D:/uwork/AssetsSource/AIGenSFX/FruitSlice_Arcade_05/wav` on every successful
spoken hit. Every choice excludes the immediately preceding audible sound.
The sound pool is independent of the target word and gameplay random generator.

The original files are copied unchanged into the existing ignored audio
directory. The committed importer and asset manifest record their exact hashes
and reproduce the import. All eight effects are bundled in the startup pack;
their first use never needs a network request. No playback rate changes, loops,
or additional effect channels are introduced.

## Local verification

- Source validation passed for all eight distinct WAVs: stereo PCM24, 48 kHz,
  270 to 369 ms, 661,684 bytes total, with source-manifest hashes preserved.
- 63 Node checks passed for the speech host and Web export.
- Native audio flow: 106 assertions passed. This includes actual hit playback,
  1,024 deterministic draws covering all eight sounds and 56 allowed transitions,
  independent gameplay randomness, mute/unmute, backgrounding, mode exit and
  missing-resource fallback.
- Voice Pop scene: 760 checks passed.
- The Web export verified all eight playable effects in the actual pack, plus
  200 word pronunciations and 174 optional paths, with zero failures.
  Startup is 14.96 MB; tested pack: `game-e1fbee18dc884302.pck`.
- Desktop Chromium and iPhone WebKit both passed the complete two-hit round,
  duplicate speech recognition, score and Pip report scenario. Chromium recorded
  two native WebAudio starts with different PCM fingerprints, stereo 48 kHz,
  playback rate 1 and no loops. The listening round contained exactly the two
  hit sounds, without prompts or music.
- Reviewed actual desktop hit-feedback and mobile result screenshots.

Windows WebKit does not expose AudioContext, so that run checks the unavailable
audio path and gameplay/report behavior. Actual browser sound playback was
measured in Chromium. Speech fixtures do not open a real microphone.

Local evidence: `build/voice-pop-qa/random-slices-local*`.

## Reproduction

```powershell
node tools/import-pop-slices.cjs
npm run import
node tools/run-godot.cjs --headless --path . --script res://tests/godot/ui_audio_flow_tests.gd
node tools/run-godot.cjs --headless --path . --script res://tests/godot/voice_pop_scene_tests.gd
node --test tests/voice-host.test.cjs tests/web-export.test.cjs
npm run build:web
npx playwright test tests/browser/voice-pop.spec.cjs --project desktop-chromium --project iphone-webkit --grep 'a spoken interim word pops'
```
