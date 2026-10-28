# Jelly Words combo audio

Each actual cumulative combo level-up requests `jelly-combo-N`, where `N` is the
new level. Ordinary progress points do not replay this accent.
`GameAudio.play_jelly_cue()` routes it to `play_word_jelly_combo(N)`.
The sound is presentation only: it does not change the combo, award coins or
delay collection. Reduced motion uses the same audio behavior.

| Combo level | Recording | Detail | Runtime gain |
| --- | --- | --- | --- |
| 1-2 | `assets/audio/jelly-combo/step.wav` | Short confirmation tone with a light glass attack | 0.40 |
| 3-4 | `assets/audio/jelly-combo/bright.wav` | The same tone with a stronger glass accent | 0.44 |
| 5 onward | `assets/audio/jelly-combo/crown.wav` | Confirmation tone, a pitched fifth and glass detail | 0.48 |

All three recordings last 0.322 seconds at their original pitch. Every increment
raises the playback rate with `2 ^ (1 - exp(-(level - 1) / 3))`, approaching an
octave above the first sound. This bounds the range during very long streaks;
the gain stops increasing at level 5. Three dedicated channels let rapid
committed level-ups overlap without replacing pronunciation, contact
feedback, warnings or collection fireworks. A fourth overlapping request reuses
the oldest combo channel. Pronunciation ducks these accents by 6 dB. The existing
Jelly pause, mute, halt and screen-exit cleanup cancels both playing and pending
requests, and resuming does not replay old increments.

## Acquired sources

The update reuses two complete recordings already acquired for Jelly level
feedback. Both are from Kenney's [Interface Sounds 1.0](https://kenney.nl/assets/interface-sounds),
licensed under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).
The originals and the pack license remain under
`docs/assets/sources/jelly-level-feedback/`. This update acquired no new pack
and contains no recording from another game.

| Original | Creator and acquisition | Use |
| --- | --- | --- |
| `confirmation_003.ogg` | Kenney; previously acquired from the user's local All-in-1 3.7.0 collection | Complete short confirmation tone, with a resampled fifth in the highest tier |
| `glass_006.ogg` | Kenney; previously acquired from the same collection | Complete short glass attack in all three tiers |

These are authored one-shot audio recordings; animation is not applicable.
The new integrated WAVs use full-source mono 44.1 kHz decoding, DC removal,
smooth boundary fades and deterministic layering. They import as nonlooping
PCM16 with compression disabled, normalized to a maximum solo peak of -10.5 dBFS.
The original files are preserved byte-for-byte. Source hashes, output hashes,
layer offsets, rate multipliers and mix measurements are recorded in
[the manifest](jelly-combo-audio.json).

## Reproduction and retained earlier evidence

```powershell
python tools/prepare-jelly-combo-audio.py --check
node tools/run-godot.cjs --headless --path . --script res://tests/godot/word_jelly_combo_audio_tests.gd
```

The cumulative-level change reuses those same three WAVs, sources and gains.
Only level ownership and runtime pitch/timbre thresholds change. The following
mixing/browser evidence predates cumulative progression and is retained as
historical evidence, not a fresh auditory review of the new trigger cadence.

Running the preparation tool without `--check` regenerates the three WAVs,
their imports and the manifest. It also writes a listening preview at
`build/qa/jelly-combo-2026-10-25/audio/combo-progression.mp3`: twelve spaced
increments followed by twenty-four increments at the actual 140 ms cadence.

The source identity, licenses, decoded waveforms, full source tails and PCM
headroom were inspected. A twenty-four-increment mix peaks at -16.29 dBFS alone
and -6.95 dBFS when layered with simultaneous existing Lv6 collection cues.
The new audio lifecycle suite passed 117 checks, while the existing level and
Jelly audio suites passed 93 and 195 checks. Startup packaging requires all
three new recordings; its 43 export tests passed.

The final Web build also passed the combo regression in desktop Chromium and
Android Chromium emulation, followed by the existing desktop pictured-word,
menu and reload route: three browser cases passed. The combo cases recorded
three real merges, the first coin at count 3, a neutral fast drop and three
automatic pickups completing in 420 ms. Each pickup raised the combo without
another combo payment. The six recorded playback rates rose from 1.0 to 1.23142.
Both rendered HUD screenshots were inspected; browser evidence is under
`build/qa/jelly-combo-2026-10-25/browser/`, with a compact summary alongside it.

These measurements and tests verify timing, range, routing and cancellation.
Audio ingestion was unavailable in the review environment, so the listening
preview is provided without an auditory or physical-device mixing claim.


The October 25 Lv9 extension rechecks the same 24-pickup, 140 ms combo mix
against each acquired collection recording from Lv4 through Lv9. The recorded
peaks are retained in `jelly-combo-audio.json`; all stay at or below -5.848 dBFS.
The waveform sources, output bytes and gain are unchanged. The later cumulative
update changes playback pitch as documented above.
