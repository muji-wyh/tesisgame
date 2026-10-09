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
queuing another call. The native generic greeting pool and its random-selection
state were removed with Pip's room. Voice Pop retains the first and third clips
on its separate happy and sad reaction channel. Voice Pop hits retain Pip's celebration motion
but omit his happy call; missed targets retain the sad call. Match and Memory
keep visual Pip reactions without duck calls, including their result screens. The old result
high-five and spoken report are retired. Growth-stage voice previews use their
documented Ava recordings. Ordinary word pronunciation and quiet growth gestures
retain their existing audio behavior.
