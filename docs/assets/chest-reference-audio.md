# Chest opening reference audio

The user supplied `C:/uworks/sound_effect-chest_openning.mp4` for a requested
chest-audio adaptation using 33–47 seconds as the reference. The supplied
recording identifies Duolingo;
the original sound designer and license terms were not supplied. No independent
redistribution license is asserted. The source is acquired and the excerpts
are extracted locally, rather than being source previews. The video remains
outside the repository and the WAVs are covered by `assets/imported-audio/` in
`.gitignore`; only the compiled game pack contains the finished recordings.
No animation asset is acquired or changed by this audio import.

Five shared recordings replace the corresponding cue in every chest theme:

| Cue | Source start | Duration | Gain | Boundary fades |
| --- | ---: | ---: | ---: | --- |
| step | 34.215 s | 0.24 s | 1.2 | 2 ms / 20 ms |
| step-detail | 36.280 s | 0.24 s | 1.2 | 2 ms / 20 ms |
| step-roll | 38.030 s | 0.24 s | 1.2 | 2 ms / 20 ms |
| release | 43.950 s | 1.50 s | 2.2 | 2 ms / 50 ms |
| reward | 45.580 s | 1.20 s | 2.2 | 5 ms / 80 ms |

The importer verifies the source SHA-256, decodes the complete AAC track before
sample-accurate cutting, and writes mono PCM16 at 44.1 kHz. It applies only the
listed gain and boundary fades, preserving the original pitch and timing.
There is no synthesis, filtering, normalization, compression, or looping.
The remaining six cues (`press`, `charge`, `cancel`, `opening`, `unlock`, and
`settle`) retain their original per-theme WAVs, for 48 original WAVs and
five shared reference WAVs. The 40 replaced theme copies are removed.

Reproduce the private build inputs with FFmpeg installed:

```powershell
node tools/import-chest-reference.cjs 'C:/uworks/sound_effect-chest_openning.mp4'
npm run import
```

[The generated manifest](chest-reference-audio.json) records source and output
hashes, source windows, processing settings, and measured signal levels.
Packaging requires the complete shared bank, validates its hashes and PCM
format, and includes each cue once in the required resource inventory. The
build receipt tracks both the manifest and its validator so changed audio
contracts require a fresh export. Signal measurements do not constitute a
claim of subjective listening approval.
