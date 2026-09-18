# Jungle and candy audio

The two new worlds each provide a background track, two chest effects and three
spoken prompts. Their source paths, formats, durations and SHA-256 hashes are
recorded in `jungle-candy-audio.json`.

The six spoken prompts use the existing Microsoft Azure Speech voice:
`en-US-JennyNeural`, `friendly` style, degree `1.15`, rate `-8%`. Generation uses
24 kHz PCM, then the existing FFmpeg conversion retains quiet word endings and a
gentle tail in 22.05 kHz PCM16 mono. The prompts come from `voice-prompts.json`.
Independent Azure speech recognition confirmed all six phrases. Five matched
word for word after ignoring punctuation; the sixth was transcribed as
“Welcome to Candyland.” for “Welcome to candy land!”, a spacing difference.

The music and effects are original scores and additive synthesis written for
this game. Jungle uses rounded wooden-key tones and a quiet low pulse; candy
uses soft toy-piano overtones. Each track has its own melody and bass progression.
The effects retain smooth attack/release envelopes and headroom. No Unity Store
or other third-party recording is used for these twelve new source files.

Generate missing files with the existing authorized Azure configuration in the
README, then run:

```powershell
node tools/generate-voices.cjs --missing
node tools/generate-world-bgm.cjs --missing
node tools/generate-sfx.cjs --missing
```

Only six voice files, two background tracks and four effects were generated in
this expansion. SHA-256 comparison confirmed that all 295 previously existing
WAV files remained byte for byte unchanged. The BGM and SFX generators also
avoid rewriting identical outputs during full regeneration.

The two background tracks and six prompts are optional Web downloads. Packaging
requires their Godot imports, so import the source WAVs through the normal build
before collecting optional audio. The four small effects stay in the startup
game pack. Missing or failed optional downloads continue through the existing
audio error/retry path without blocking gameplay.

Validation covered all eight BGM tracks, all twenty effects, 228 vocabulary and
prompt recordings, six-prompt missing-only synthesis, old-file preservation,
deterministic new music/effects and all eight new optional Web audio paths:

```powershell
node --test tests/voice-generation.test.cjs tests/world-audio.test.cjs
node --test --test-name-pattern='voice|English|pronunciation|background tracks|original effects|chest openings|SFX generator' tests/assets.test.cjs
```
