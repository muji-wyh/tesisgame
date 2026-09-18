# Voice Pop: short slice feedback

Voice Pop reused the 650 ms `correct.wav` melody for every popped target. Hits
now select the user's `Casual Game Music Pack 1.4/Sound Effects/Cut2.wav`: a
96.94 ms cut effect with a roughly 2 ms audible onset. Other modes keep their
existing feedback. The original file is copied unchanged and uses the existing
effect gain of 0.24.

The source hash is pinned in `docs/assets/voice-pop-sfx.json`. Licensed raw audio
stays in ignored `assets/imported-audio/`, and the imported stream is bundled
inside the PCK. The Web export verifies that it can load the actual selected
stream, preventing an accidental development-fallback release. A checkout
without the local pack still runs with the original short select click.

## Verification

- The native UI audio suite passed 81 checks, including real Voice Pop
  recognition/hit flow selecting the imported stream, rapid hits sharing the
  same player, no accompanying music/speech, mute, mode exit and page lifecycle.
- All 18 asset checks passed; all 22 Web export/deployment checks passed.
  The asset count assertion was updated for the dance atlas added in the
  previous release; the image compression checks remain intact.
- Export verification confirmed the slice is in the PCK, along with all 200
  vocabulary recordings, while all 158 optional audio paths remain excluded.

Browser checks use recognition fixtures and never capture a physical microphone.
They observe real AudioBufferSource playback durations for each hit and check
that finalizing the same interim result cannot repeat the sound.

The complete local Chromium round passed: both distinct hits played a short
AudioBuffer exactly once, followed by the existing natural report, replay and
review interactions. The actual hit screenshot was checked. Evidence is under
ignored `build/voice-pop-qa/pop-slice-local*`. Web startup remains 13.28 MB with
79 on-demand audio assets; the slice requires no separate request.

## Production acceptance

Runtime commit `d70f3fc` was merged to `main`, pushed and deployed with
`npm run deploy -- -SkipBuild`. Production HTML, engine JavaScript/WASM and
`game-97c2d5c613dd6073.pck` matched the tested export's SHA-256 hashes.

The complete production Chromium round passed. Both hit buffers measured
0.0969375 seconds, matching the selected source after browser resampling; the
same final recognition did not replay a hit. Results narration and review
continued to work. Evidence is under `build/voice-pop-qa/pop-slice-production*`.

Live version: https://gentle-forest-02ff42900.3.azurestaticapps.net/?v=d70f3fc
