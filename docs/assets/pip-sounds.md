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
The same sounds are bundled in the game for header, reward and Home interactions.
Consecutive greetings use different clips; fast taps replace the previous clip.
Pip's Voice Pop high-five begins with a random greeting, followed by the existing
spoken report. Ordinary word pronunciation and automatic idle dances are unchanged.
