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
Consecutive greetings use different clips. Another manual tap is accepted only
after the current action and call finish; taps during that interval are ignored
without queuing a later reaction. Voice Pop hits retain Pip's celebration motion
but omit his happy call; missed targets retain the sad call. The old result
high-five and spoken report are retired. Ordinary word pronunciation and
automatic idle dances use their existing audio behavior.

Talk Quest victories play the bouncy double call at 0 seconds, the derpy double
at 1 second, and the bouncy double again at 2 seconds during Pip's 3.2-second
dance. These use the same acquired recordings, with per-call pitch and gain.
One cancellable scheduler owns the sequence. Mute, page hiding, pause, leaving
Quest, and entering the treasure room stop both queued calls and the current
reaction voice without interrupting a chest-opening sound.
