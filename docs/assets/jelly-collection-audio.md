# Jelly collection bubble pop

Jelly Words Lv1 and Jelly Match play the same short bubble pop for every accepted
collection. This recording uses one fixed authored pitch, with no random sample
choice or per-collection transposition. Higher Jelly Words levels use the
[level collection feedback profiles](jelly-level-feedback.md).

The gameplay clocks use Jelly Match's fusion release, Jelly Words'
180 ms manual-pop boundary, and its 60 ms batch-pop boundary within each 250 ms
collection beat. `collect-pop.wav` is cached at startup and required in the core
Web pack. It uses the existing bounded Jelly audio players, collection gain 0.90,
speech ducking and mute, pause and exit cancellation.

## Source and delivered asset

The source is **farfadet46's [bubbles 'pop'](https://opengameart.org/content/bubbles-pop)**,
released as **CC0 1.0**. The creator describes it as a bubble-pop effect for games.
It is an authored sound effect; this record does not claim a recording of a
physical bubble. No animation asset is supplied or needed.

The original [pop.ogg](https://opengameart.org/sites/default/files/pop.ogg) was
downloaded on 2026-10-21 and is preserved byte for byte at
`docs/assets/sources/jelly-collection-audio/farfadet46-pop.ogg`. Its SHA-256 is
`d55886ec5b145045d1abd13926675b93646a8865e53e1f7a3a58cfbb7b733cff`.
This is the acquired original download, not an unacquired source preview.
The source notice and CC0 link are also retained in
`assets/audio/jelly-match/LICENSE-Bubble-Pop.txt`.

The complete original lasts about 276 ms but its main pop begins at about
135 ms. Preparation keeps the 131–231 ms window, preserving the attack and
natural tail at their original speed and pitch. It applies a 65 Hz high-pass,
6500 Hz low-pass, DC removal, 1 ms onset fade, 12 ms end fade and peak adjustment.
No spring, musical, voice or generated layer is added.

The delivered `assets/audio/jelly-match/collect-pop.wav` is **100 ms**, 44.1 kHz
mono PCM16, with a **−7.50 dBFS** peak. Twelve repeats at the recorded 120 ms
verification spacing reach **−8.42 dBFS** after the existing 0.90 collection gain.
Current gameplay uses 250 ms batch spacing. Godot imports
use no compression, automatic trimming, normalization or looping. These are
signal measurements, not subjective loudness or physical speaker assessments.

The former collection-note WAVs and `clear.wav` stay unchanged for historical
provenance and independent fixtures. They are no longer the Jelly collection
sound. Their original rubberduck and Aeva licenses remain beside those files.

## Rebuild and verification

```powershell
python tools/prepare-jelly-collection-audio.py
python tools/prepare-jelly-collection-audio.py --check
```

The generator requires NumPy, SoundFile and FFmpeg. It uses the preserved local
source, verifies its hash, prepares the single fixed cue, and records the output
hash and exact processing in [the manifest](jelly-collection-audio.json).
Verification checks PCM format, onset, zero-valued boundaries, headroom and
repeated batch playback.

`build/jelly-collection-audio/one-pop-and-rapid-collection.wav` contains one
isolated pop followed by twelve identical pops at gameplay gain and the recorded
120 ms verification spacing.
It is an asset preview, not an engine-mixed capture. Direct auditory input is
unavailable in the agent tools. The user approved this audio preview on
2026-10-21; this does not imply physical-device gameplay testing.

Verification on 2026-10-21 passed the audio preparation checks, three focused
packaging tests, native Jelly audio (195 checks), Jelly Match flow (421 checks)
and Jelly Words flow (757 checks), and the production Web export. Desktop
Chromium passed the Jelly Match audio/lifecycle case and the focused Jelly Words
manual collection, batch collection and mute case. The browser checks observe
the same decoded recording at playback rate 1.0 and verify bundled offline
playback. That verification used the former 120 ms Words batch cadence; current
gameplay uses 250 ms.
