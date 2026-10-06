# Casual background music

The October 2, 2026 music refresh replaces all eight theme recordings with
distinct tracks by [Juhani Junkala](https://juhanijunkala.com/). The selection
uses town and calm JRPG cues for the game's casual play and reward screens.
The original musical loops run from 46 to 112 seconds.

## Sources and license

The tracks come from [JRPG Pack 2 Towns](https://opengameart.org/content/jrpg-pack-2-towns)
and [JRPG Pack 4 Calm](https://opengameart.org/content/jrpg-pack-4-calm), both
released under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).
The author's included license states: "These music tracks have been released
under CC0 creative commons license. You can do anything you want with these tunes."
The original notices are retained for [Towns](licenses/juhani-junkala-jrpg-pack-2-towns.txt)
and [Calm](licenses/juhani-junkala-jrpg-pack-4-calm.txt).

| Theme | Track | Pack | Loop length |
| --- | --- | --- | ---: |
| Spring | Home Town | Towns | 90.00 s |
| Summer | Sunshine Coast | Towns | 112.34 s |
| Autumn | A Place I Call Home | Calm | 46.45 s |
| Winter | Peaceful Days | Calm | 64.00 s |
| Ocean | Sand Castles | Calm | 71.11 s |
| Space | Where Time Stands Still | Towns | 75.51 s |
| Jungle | Bazaar | Towns | 110.34 s |
| Candy | Childhood Friends | Calm | 102.86 s |

[The active manifest](casual-bgm.json) records package download URLs, archive
and source SHA-256 hashes, the per-theme output hashes, durations, gain changes,
and measured source levels. Each theme retains its existing path,
`assets/audio/bgm/<theme>.wav`.

## Preparation and playback

The original Ogg recordings remain unchanged. Conversion produces 44.1 kHz
stereo PCM16 WAVs, applying a fixed gain calculated for approximately -20 LUFS
with at least 3 dB of true-peak headroom. Three-millisecond fades at the two
file edges reduce loop-boundary discontinuities. The processing retains each
complete musical loop without time stretching, cuts, or dynamic compression.
FFmpeg 9.0.2 is the recorded conversion version; exact output hashes are required
when restoring the files.

The existing Godot imports convert these sources to mono 22.05 kHz compressed
resources for the startup game pack. Playback loops the full imported recording.
Runtime gain remains 0.12 normally and 0.04 under spoken prompts, with the existing
chest ducking. Voice Pop keeps music silent during microphone recognition;
its reward screens use the shared theme music and chest mix.

Verify the active WAVs without changing them:

```powershell
python tools/import-casual-bgm.py --check
```

To restore the recorded conversion from the downloaded sources, use a directory
containing `jrpg-pack-2-towns` and `jrpg-pack-4-calm` with the original filenames
listed in the manifest:

```powershell
python tools/import-casual-bgm.py --source-root C:\uworks\casual-bgm-research
```

The importer verifies every original source hash, prepares all eight converted
files, and verifies their output hashes before replacing any active WAV. A
conversion mismatch stops the import. Run the normal Web build afterward to
refresh Godot imports and bundle the replacements; ordinary builds do not
download or regenerate music.

The local source archives, extracted originals, and source evidence are retained
under `C:\uworks\casual-bgm-research`. The previous eight game WAVs were backed
up under `C:\uworks\BGM\previous-2026-10-02`. These machine-local directories
are separate from the tracked active recordings and provenance.

## Previous recordings

The earlier spring, summer, autumn, and winter tracks came from the
user-provided Casual Game Music Pack 1.4. Ocean, space, jungle, and candy used
original synthesized scores from `tools/generate-world-bgm.cjs`. The dated
[Jungle and Candy manifest](jungle-candy-audio.json) preserves the original
September 18 recordings and hashes; its BGM entries describe superseded music.
The retained arrival effects and spoken theme greetings still use that provenance.

The legacy BGM generator now preserves existing files by default, including
when called without command-line arguments. `--missing` explicitly selects
the same behavior. `--replace` deliberately restores the four original
synthesized world scores; it does not restore the current downloaded music.
Use `import-casual-bgm.py` for the active soundtrack.
