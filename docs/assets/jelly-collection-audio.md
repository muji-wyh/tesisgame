# Jelly collection notes

Jelly Words and Jelly Match share seven short collection cues in an ascending
cycle: **Do, Re, Mi, Fa, Sol, La, Ti, then Do again**. The sequence starts at Do
and advances once per accepted live `pop` event. Both modes share the next note,
which is preserved through mute, pause and mode changes. Suppressed cues do not
advance the sequence. Collection playback does not use a random choice.

The bank retains the existing gel-skin and elastic spring recording, with
major-scale intervals of 0, 2, 4, 5, 7, 9 and 11 semitones above Do. The range
straddles the original cue, from five semitones below to six above. These are
relative musical degrees: the source retains its elastic pitch movement and
is not a set of sustained concert-pitch notes.

Each cue lasts **240 ms**, with a 2 ms edge fade, a damped body and a 45 ms
tail fade. More than 99.5% of each file's energy falls before the next 120 ms
batch beat, giving each new collection a distinct attack. The files have a
common RMS of -24.966 dBFS and peaks at or below -7.5 dBFS. The worst of all
49 adjacent-note combinations at the actual batch spacing reaches -8.24 dBFS
after the existing 0.90 collection gain. These are waveform measurements,
not a listening preference or a full-mix loudness assessment.

The gameplay event clocks remain unchanged: Jelly Match's fusion release,
Jelly Words' 180 ms manual-pop boundary, and its 60 ms batch-pop boundary
within each 120 ms collection beat. The seven streams are cached at startup
and required in the core Web pack. They use the existing three-player pool,
speech ducking, mute, pause and exit cancellation. Runtime playback uses pitch
1.0; pitch and envelope processing are already baked into each asset.

## Source and delivered material

| Material | Creator / original source | License and acquisition | Integration |
| --- | --- | --- | --- |
| Gel-skin recording, `slime_16.ogg` | rubberduck, [40 CC0 water / splash / slime SFX](https://opengameart.org/content/40-cc0-water-splash-slime-sfx) | CC0 1.0; original OGG archive previously acquired | Existing `clear.wav` composite; its source hash and processing remain in [Jelly Match's manifest](jelly-match.json). |
| Elastic spring recording, `boing.flac` | Aeva, [BOING!](https://opengameart.org/content/boing) | CC0 1.0; original FLAC previously acquired; authored on an Arturia MicroFreak | Existing `clear.wav` composite; this is a synthesized source recording, not rubber foley. |
| Seven collection notes | Local adaptation of the two acquired recordings | Same CC0 sources; no new samples, oscillators or cloud generation | `assets/audio/jelly-match/collect-{do,re,mi,fa,sol,la,ti}.wav`; integrated in both modes. |

All delivered notes are 44.1 kHz mono PCM16 WAV, with uncompressed Godot
imports, no automatic trimming or normalization, and no loops. These are
audio-only assets with no animation clips. The unchanged 340 ms `clear.wav`
is retained as the source master, rather than used for live collections.
The [bank manifest](jelly-collection-audio.json) records its SHA-256, the
original creators and licenses, the exact per-note processing and output hashes.

## Rebuild and checks

```powershell
python tools/prepare-jelly-collection-audio.py
python tools/prepare-jelly-collection-audio.py --check
```

The generator requires NumPy, SoundFile and FFmpeg with Rubber Band. It
transposes and compresses the original recording, then shapes and level-matches
the results. It checks file identity, format, onset, zero boundaries, clipping,
relative intervals, RMS consistency and every adjacent-note overlap. It also
writes `build/jelly-collection-audio/seven-notes-and-rapid-collection.wav`:
the seven-note scale followed by two ascending cycles at the 120 ms collection
spacing, demonstrating the same Ti-to-Do wrap used in gameplay.

Native audio checks cover the seven cached files, ascending cyclic playback,
one advance per accepted event, sequence continuity across interruptions, bounded
voices, speech ducking and cancellation of delayed playback. Browser checks exercise real Jelly Match and Jelly Words collections,
including a three-word batch, mute and offline playback. Physical-device
listening remains a separate check; decoded output does not establish timbral
preference.
