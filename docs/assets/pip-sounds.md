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

Pip's lesson and result reactions remain visual only, including Voice Pop
hits and misses, growth actions, and result-screen interactions. The old native
duck-call channel and theme welcome narration are removed. Educational word
and phrase pronunciations, music, and ordinary interaction and reward effects
remain available. The old result high-five and spoken report are also retired.

The original duck recordings remain for the pregame loading toy and source
history. Growth-stage voice recordings remain available in the separate art
preview with their documented Ava profile; they do not play during gameplay.

## Jelly World map sleep and wake

The map companion has a separate, map-owned audio player for the requested
sleep/wake interaction. Each visible sleep inhalation triggers one short cartoon
snore. Hover or actual user scrolling interrupts the snore and plays the existing
0.18-second approved duck recording once when a visible sleeping Pip wakes.
Repeated scroll movement and inertia do not queue additional calls; an already
awake companion grips the stage without replaying the wake cue. Automatic focus
reveal and layout movement do not count as a user scroll wake.
These cues do not restore companion audio in lessons or
result screens. The map's audio gate follows sound preferences, foreground
activity, and visibility; hidden or muted events are discarded rather than queued.

`assets/audio/pip/map-snore.wav` comes from **Sleep** by **LilMati**,
[Freesound 528254](https://freesound.org/people/LilMati/sounds/528254/), released
under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). The creator
describes authoring the sound in FL Studio and tags it as snore, snoring, and
sleeping. This is a finished authored cartoon sound, not synthesized runtime
placeholder audio. The creator cites a song as the inspiration; the source page
does not identify the file as a sample extracted from that song.

Acquisition on 2026-11-04 downloaded the public **high-quality MP3 preview** from
Freesound's CDN. The original source WAV was not downloaded. The acquired preview
is retained at `docs/assets/sources/pip-map-snore/sleep-hq-preview.mp3`; the runtime
WAV is its complete 0.6-second decode to mono, 44.1 kHz, signed 16-bit PCM, without
trimming, normalization, pitch changes, or added effects. Runtime gains are 0.36
for the snore and 0.24 for the startled peep, on separate reusable one-shot players.
Source metadata and both hashes are in
`docs/assets/sources/pip-map-snore/source.json`. Audio assets contain no animation;
the articulated map controller supplies synchronized breathing and recovery.

Acquisition and integration are complete. The clip's duration, envelope, peak,
and format were inspected, and the audio lifecycle has focused automated checks.
The first sample above -45 dBFS occurs at 0.023 ms and the peak at 4.649 ms, so
the cue has no leading silence before the visual inhalation event.
This technical inspection does not establish a subjective listening judgment.
