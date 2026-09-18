# Voice Pop fruit-slice variation

The eight finished mixes in the user's `FruitSlice_Arcade_05/wav` directory
replace the single Voice Pop hit effect. Apple, orange, watermelon, pineapple,
banana, strawberry, peach and coconut all participate in the same random pool;
the sound does not depend on which vocabulary word was hit. Each audible hit
draws uniformly from every available sound except the immediately preceding one.
Sound randomness uses its own generator and cannot alter gameplay or rewards.

`voice-pop-random-slices.json` records exact source hashes, destinations,
durations and format. The importer checks all eight selected source files against
the source manifest, checks their actual WAV format and peak, and copies their
bytes unchanged. It does not import previews, reference audio or separate layers.
Godot retains stereo 48 kHz playback, with uncompressed PCM imports and no
normalization, trimming, looping, or pitch variation. Original PCM24 source WAVs
remain unchanged; Godot's PCM stream uses its supported 16-bit representation.

The existing effect channel and volume are retained. Fast hits restart the
channel, so effects cannot pile up at excessive volume. Muting, backgrounding,
leaving Voice Pop and recognition deduplication retain their existing behavior.
The eight small effects are bundled in the initial game pack to avoid a
first-hit network delay. Web export rejects a partial or invalid local set.

Raw user-provided WAVs and import metadata remain under the repository's existing
`assets/imported-audio/` ignore rule. The published compiled game includes them.
Clean source checkouts without the local pack retain the previous short effect,
or the original select effect if neither local import exists.

To reproduce the local import and export:

```powershell
node tools/import-pop-slices.cjs 'D:/uwork/AssetsSource/AIGenSFX/FruitSlice_Arcade_05/wav'
npm run build:web
```
