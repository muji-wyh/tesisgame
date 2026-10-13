# Archived Jelly Match woodland environment

This historical source record was superseded on October 13, 2026 by the
[Kenney layered garden](jelly-garden.md), now used by Jelly Match and Jelly Words.
The original artwork, hashes, license and importer are retained for provenance.

The earlier Jelly Match environment used acquired nature artwork by **Zuhria
Alfitra (pzUH), GameArt2D**, the same creator as the gel surface illustration.
Layered sky, mountains and trees established a woodland clearing around the
four-column play area, with foliage at the perimeter.

## Source, rights and status

- Original source: [Free Nature Platformer Tileset](https://www.gameart2d.com/free-platformer-game-tileset.html).
- Creator: [Zuhria Alfitra / GameArt2D](https://www.gameart2d.com/about.html).
- License: the creator's [Free Assets License](https://www.gameart2d.com/license.html)
  releases this free pack under **CC0 1.0**, allowing commercial and noncommercial
  use without required credit. The repository reuses its existing
  [CC0 license copy](../../assets/images/jelly-match/LICENSE-CC0.txt).
- Acquisition: downloaded from the creator's original archive on October 9,
  2026. The archive is retained in ignored
  `build/jelly-environment-sources/gameart2d-nature.zip`.
- Status: original PNGs downloaded, inspected and previously integrated unchanged;
  replaced in the active jelly backgrounds by the Kenney garden.
  Their source and destination SHA-256 hashes are identical and recorded in
  [the manifest](jelly-environment.json).
- Animation: static PNGs and vector originals; no source animation clips.
  Runtime motion, if used, is presentation authored by the game.

| Integrated file | Original archive member | Purpose |
| --- | --- | --- |
| `assets/images/jelly-match/environment/woodland.png` | `png/BG/BG.png` | Complete layered woodland background |
| `assets/images/jelly-match/environment/tree.png` | `png/Object/Tree_2.png` | Broadleaf tree at the outer scene edge |
| `assets/images/jelly-match/environment/bush.png` | `png/Object/Bush (1).png` | Low foliage near the outer ground line |
| `assets/images/jelly-match/environment/mushroom.png` | `png/Object/Mushroom_1.png` | Small woodland accent outside the play area |

All four are the original source PNG bytes. There is no recoloring, regeneration,
paint-over, resampling or replacement geometry in this preparation. Source
transparency, dimensions and detail are preserved. Runtime fitting must preserve
image proportions and keep high-detail foreground art away from learning content.

## Historical review evidence

The existing Jelly source pack's `BG.png` was inspected and rejected because it
is a flat green field. The retired Talk Quest environment records are historical
and do not provide active artwork for this mode.

GameArt2D's downloaded woodland background and individual tree, bush and mushroom
PNGs were visually inspected alongside Kenney's Background Elements Remastered.
The source comparison is retained in ignored
`build/jelly-environment-sources/environment-source-review.png`. The Kenney
alternative, including its separately inspected clouds, was not integrated in
that original review. The later garden selection has its own source and runtime
record. The comparison sheet is source-art evidence, not a screenshot of the game.

The previous background was static, used aspect-preserving cover fitting, and
placed foreground props at the screen edges. A pale playfield and dark green
labels preserved vocabulary contrast; full-board warning text used dark brown.
Native gameplay, full-board warning and reduced-motion captures were checked at
1366 x 768, 390 x 844, 844 x 390 and 320 x 568. Chromium and simulated iPhone
WebKit gameplay captures were also inspected. Lifecycle checks confirmed that
the previous scenery did not intercept input or remain behind the notebook,
shared celebration, treasure room or other game modes. These results describe
the retired presentation, not the current garden.

## Reproduction

Download the original archive from the URL recorded in the manifest. With Python
and Pillow available:

```powershell
python tools/import-jelly-environment-assets.py
python tools/import-jelly-environment-assets.py --check
```

Use `--archive <path>` when the original ZIP is stored elsewhere. The importer
verifies its complete SHA-256 hash and reads only the four selected members. It
copies their bytes and recreates the manifest without extracting unselected
assets. `--check` performs read-only hash, PNG format, dimension, source identity
and license-presence checks. Normal game builds require only the integrated
images and shared license; no network download or source ZIP is needed.
