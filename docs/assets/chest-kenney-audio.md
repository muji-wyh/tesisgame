# Kenney chest audio

The active chest bank uses 11 shared, locally bundled cues from nine Kenney
recordings. The source is the user's **Kenney Game Assets All-in-1 3.7.0 / Audio**
collection. The five source packs identify Kenney as creator and license their
content under **CC0**. Their original license notices are retained alongside the
converted WAVs in `assets/audio/chest-kenney/`.

[The manifest](chest-kenney-audio.json) records the original pack paths, source
URLs and hashes, acquisition/integration status, processed hashes, measurements,
and exact source layers. These are acquired and integrated audio assets, not
source previews. Animation availability is not applicable.

| Stage | Source material and treatment |
| --- | --- |
| Press and accelerating beats | Impact Sounds light wood contacts, then progressively more RPG Audio latch detail; 120–180 ms clips keep the final 50 ms beat gaps distinct |
| Pressure | A steady 260 ms window from RPG Audio `creak1`, filtered and overlapped into an 800 ms periodic texture; the existing gameplay curve controls pitch and gain |
| Anticipation | Foley Sounds `woosh8`, quickly decaying into the existing held breath |
| Unlock | A trimmed, filtered 75 ms `metalLatch` contact |
| Release | Light wood onset, short door hinge and air layers, then Music Jingles `jingles-steel_00` with its natural musical decay |
| Settle/cancel | Filtered, low-level wood contact |
| Saved reward | Interface Sounds `confirmation_002`, a separate 560 ms acknowledgement |

The physical timeline is unchanged: 650 ms hold, release at 1.59 seconds after
press, completion at 2.65 seconds. The release cue lasts 1.44 seconds, retaining
380 ms of decay after motion completes. The receipt plays only after a successful
save. Coin cues remain independent and unchanged. Cancellation, mute, background
handling, reduced motion and the three-channel overlap limit remain intact.

Audio is decoded to float before filtering and gain adjustment, because several
source OGG decodes exceed full scale. The delivered files are 44,100 Hz mono
PCM16, with no compression or import normalization. Recorded peaks are limited
to 0.36–0.72 except the quieter pressure/anticipation layers. No generated tones
or noise are added. All themes share the same 365 KB bank and cache resources.
The old reference clips remain unchanged for other game modes. The prior themed
support assets remain archived in the repository and are excluded from the
runtime export because the shared Kenney bank replaces their live playback.

Rebuild from the acquired local collection:

```powershell
python tools/import-chest-kenney.py 'Q:/uwok/Kenney Game Assets All-in-1 3.7.0/Audio'
npm run import
```

The importer requires FFmpeg and NumPy. Keep each tracked WAV import at
`compress/mode=0`; `tools/chest-kenney-audio.cjs` validates source hashes, PCM
format, frame counts and required package inventory.

Review covers source metadata, signal envelopes, output headroom, cue scheduling,
and engine-rendered before/after captures. Direct auditory input is unavailable
in the agent tools; waveform measurements do not establish perceived timbre or
physical speaker quality. `node tools/capture-chest-feel.cjs spring` produces
an actual engine-mixed preview for listening, with no substitute soundtrack.
