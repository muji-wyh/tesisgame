# Voice Pop slice sound

Voice Pop hits use `Cut2.wav` from the user's local **Casual Game Music Pack 1.4**.
The source is copied byte for byte: stereo 44.1 kHz, 16-bit PCM, 4,275 frames
(96.94 ms). It starts within 2.1 ms at −40 dBFS, has zero-valued first/last
samples and no full-scale samples. Its −0.105 dBFS peak becomes approximately
−12.50 dBFS through the existing 0.24 effect gain. No trimming, normalization,
extra layer or pitch change is applied.

Import from a local copy of the user-provided pack, then build normally:

```powershell
node tools/import-pop-sfx.cjs "D:/uwork/AssetsSource"
npm run build:web
```

`voice-pop-sfx.json` pins the source path and SHA-256. The importer refuses a
different file and does not modify the source pack. Raw imported audio remains
under ignored `assets/imported-audio/`; the provider's terms apply, independently
of the repository's code license. The source `.meta` identifies `licenseType:
Store`; no additional redistribution rights are claimed.

The imported effect is included in the startup PCK, so the first hit does not
wait for an audio request. The exporter verifies that a present local override
can also be loaded from the finished PCK. A development checkout without the
pack uses the existing short original `select.wav` click. Match/Memory and other
cues keep their existing audio.

The effect uses the existing single effect player. Rapid hits replace the prior
sound, and mute, mode changes and page suspension stop it through the existing
audio lifecycle. It does not start background music or word pronunciation while
Voice Pop is listening.
