# Pip greeting sounds

The three user-selected WAVs from `D:/uwork/AssetsSource/AIGenSFX/duck_gaga`
are committed in `assets/audio/pip/`, with their original PCM samples preserved.
`pip-sounds.json` records each file's SHA-256, duration and format. Re-import with
`node tools/import-pip-sounds.cjs [source-directory]`; normal builds need no external source folder.

Source provenance supplied beside the original audio:

- `Duck_Quack_Single/duck_quack_innocent_deep_short_04.json`
- `Duck_Quack_Double_Cartoon/manifest.json`

Both identify the underlying recording as [WavJunction.com, Freesound 456770](https://freesound.org/people/WavJunction.com/sounds/456770/), licensed CC0 1.0. The selected double-call versions and single-call version match their source SHA-256 records.

Loading-page greetings are embedded in the HTML so they work before Godot loads.
All three recordings remain active in that browser loading-page pool. Consecutive
loading-page greetings use different clips and busy taps are ignored without
queuing another call. Loading-page sounds stop when gameplay begins.

Pip's gameplay reactions are visual only across all modes, including Voice Pop
hits and misses, growth actions, and result-screen interactions. The native
duck-call channel and theme welcome narration are removed. Educational word
and phrase pronunciations, music, and ordinary interaction and reward effects
remain available. The old result high-five and spoken report are also retired.

The original duck recordings remain for the pregame loading toy and source
history. Growth-stage voice recordings remain available in the separate art
preview with their documented Ava profile; they do not play during gameplay.
