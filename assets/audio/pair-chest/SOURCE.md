# Hidden chest discovery cheer

- Title: Cheers
- Creator: AuraVoice, published as Nocturnal_Vanguard
- Source page: https://opengameart.org/content/cheers-0
- Source file: https://opengameart.org/sites/default/files/cheers_1.ogg
- License: CC0 1.0, https://creativecommons.org/publicdomain/zero/1.0/
- The source author identifies this as their own voice work and permits use
  without credit. The source tags identify happy female group cheering.
- Acquisition: downloaded from the source file on 2026-10-14, converted and
  integrated as `discovery.wav`. No preview recording or Pip voice is used.
- Original SHA256: `10d9f614307127a8c2b2b129e9a291b6071c8fc91f1fed4916f78ad47c956b25`
- Integrated SHA256: `e6cf4cab7528df927e7401bb2516b0bbd75d61f9bee00a5c9426667d377a77cb`
- Original: mono Vorbis, 48 kHz, 2.029146 seconds.
- Integrated: mono PCM16, 44.1 kHz, 1.75 seconds, no looping or import normalization.
- Processing: retain seconds 0.10 through 1.85, apply 3 ms entrance and 50 ms exit
  fades, resample to 44.1 kHz. No pitch shift, gain change, or additional layers.
- Animation: not applicable; audio only.

Jelly's round-clear presentation also reuses this exact integrated human cheer.
The dedicated round-end player preserves its original pitch and complete 1.75
seconds; failure retains its separate acquired cue. Mute, backgrounding and
navigation use the existing round-end cleanup instead of replaying old cheering.

The inspected source peaks at -4.19 dBFS with RMS -18.51 dBFS and no clipping.
Trimming removes the leading silence without cutting the vocal attack. Signal
analysis and runtime playback checks do not establish subjective listening
quality on a physical device.

Reproduce from the acquired original with FFmpeg:

```powershell
ffmpeg -i cheers_1.ogg -af 'atrim=start=0.10:end=1.85,asetpts=PTS-STARTPTS,afade=t=in:d=0.003,afade=t=out:st=1.70:d=0.05' -ac 1 -ar 44100 -c:a pcm_s16le discovery.wav
```
