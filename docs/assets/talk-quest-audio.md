# Talk Quest combat audio

> Archived on 2026-10-06. Talk Quest has been removed from the game. This
> document preserves the former implementation, source provenance, and review
> evidence. Its asset paths, interfaces, and commands describe that revision;
> they are not current build prerequisites or instructions to restore the mode.
> Retained manifests and license records do not mean the runtime assets ship.

Talk Quest uses three original synthesized one-shot effects. They contain no
speech, recordings, downloaded samples, or third-party dependencies. The full
source is `tools/generate-quest-audio.cjs`; its seeded noise and mathematical
oscillators reproduce the checked-in PCM files exactly.

| File | Duration | Character | Playback gain |
| --- | --- | --- | --- |
| `assets/audio/quest/launch.wav` | 0.24 s | Warm magic projectile core, descending tip, and a soft moving air rush | 0.50 |
| `assets/audio/quest/impact.wav` | 0.36 s | Rounded low impact, filtered contact grains, and a short pair of sparks | 0.50 |
| `assets/audio/quest/defeat.wav` | 0.90 s | Three loose crumbling pieces followed by a gentle ascending C-major resolve | 0.55 |

The intended trigger points are projectile launch after a recognized word,
projectile contact with the monster, and the final monster defeat. Launch and
impact are separate cues so contact remains synchronized to the visible hit.
These cues use the game's existing sound setting and do not replace its music.

All files are mono 44.1 kHz, 16-bit uncompressed PCM without loops. Source RMS is
0.18 for launch and impact and 0.17 for defeat; measured peaks are approximately
0.503, 0.608, and 0.533 respectively. Three simultaneous impacts peak below 0.92
at the authored gain, retaining headroom for overlapping effects. Warm energy
around 150–350 Hz gives the effects body on small speakers, while filtered upper
harmonics keep the sound rounded. Soft
attack/release envelopes and a faded DC correction avoid clicks at file ends.

Regenerate the assets and import settings:

```sh
node tools/generate-quest-audio.cjs
npm run import
```

The generator changes only these three WAVs and their import metadata. It skips
identical audio bytes and preserves Godot import UIDs. The import metadata keeps
normalization, trimming, and looping disabled to retain the authored timing and
gain. `tests/quest-audio-assets.test.cjs` verifies deterministic output, PCM
format, levels, boundaries, spectral balance, and stable imports.
