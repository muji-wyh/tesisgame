# Jungle and candy audio

The September 18, 2026 expansion supplied original jungle and candy music,
arrival effects, and spoken prompts. On October 2, the two background tracks
were replaced with Juhani Junkala's CC0 recordings as part of the
[eight-theme casual BGM refresh](casual-bgm.md). The two original arrival effects
remain active. On October 3, all spoken recordings, including the two theme
greetings, were replaced by the approved [Ava voice](ava-voice.md). The dated
[jungle-candy-audio.json](jungle-candy-audio.json) retains the original source
paths, formats, durations, and SHA-256 hashes; its historical hashes describe the
superseded synthesized scores and Jenny greetings. [casual-bgm.json](casual-bgm.json)
and [ava-voice.json](ava-voice.json) describe the current music and speech at those paths.

Chest interactions use the separate authored material bank described in
[Chest feel](chest-feel.md). The original expansion also included arrival and
opening voice prompts and opening jingles. Those four recordings and two
jingles are retired and removed from the active source assets.

The original six spoken prompts used the existing Microsoft Azure Speech voice:
`en-US-JennyNeural`, `friendly` style, degree `1.15`, rate `-8%`. Generation used
24 kHz PCM, then the former FFmpeg conversion retained quiet word endings and a
gentle tail in 22.05 kHz PCM16 mono. The two active greetings remain in
`voice-prompts.json`.
Independent Azure speech recognition confirmed all six phrases. Five matched
word for word after ignoring punctuation; the sixth was transcribed as
“Welcome to Candyland.” for “Welcome to candy land!”, a spacing difference.

The original music and effects were scores and additive synthesis written for
this game. The former jungle track used rounded wooden-key tones and a quiet
low pulse; candy used soft toy-piano overtones. Each had its own melody and bass
progression. The retained effects have smooth attack/release envelopes and
headroom. No Unity Store or other third-party recording was used for the twelve
original September 18 source files.

Generate missing voices with the current [Ava workflow](ava-voice.md), retain the
original effects, and verify the current music:

```powershell
node tools/generate-voices.cjs --missing
node tools/generate-sfx.cjs --missing
python tools/import-casual-bgm.py --check
```

Only six voice files, two background tracks, and four effects were generated in
the September 18 expansion. Its SHA-256 comparison confirmed that all 295
previously existing WAV files remained byte for byte unchanged. The legacy
`generate-world-bgm.cjs` preserves existing tracks by default and retains an
explicit `--replace` option for reproducing the original scores. Restore the
active downloaded tracks with the [casual BGM importer](casual-bgm.md).

The replacement background tracks, two Ava theme greetings, and two arrival
effects, along with the current chest material bank, are bundled in the startup game pack.
Packaging requires their Godot imports,
so import the source WAVs through the normal build before validating the required
audio. The pack verifier loads the exported resources to confirm they are playable;
no audio download is needed after startup.

The September 18 validation covered all eight BGM tracks, all twenty effects, 228 vocabulary and
prompt recordings, six-prompt missing-only synthesis, old-file preservation,
deterministic new music/effects and all eight original optional Web audio paths.
The maintained tests pin the two retained original arrival effects, reproduce the
superseded jungle and candy scores against their historical hashes, and verify
the required current music and greeting paths inside the bundled-audio contract:

```powershell
node --test tests/voice-generation.test.cjs tests/world-audio.test.cjs
node --test --test-name-pattern='voice|English|pronunciation|background tracks|active effects|SFX generator' tests/assets.test.cjs
```
