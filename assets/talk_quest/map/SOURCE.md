# Talk Quest atlas artwork

These are downloaded production assets prepared for the level-select atlas.
They are static artwork. Chapter transitions, focus motion, and current-stop
animation are provided by the game; the source packs contain no animations.
No monster artwork is included in this map.

## Required attribution

**Cartography brushes for GIMP by yd, licensed CC BY 3.0. Adapted by cropping,
resizing, tinting, and compositing into Talk Quest map artwork.**

- Source: https://opengameart.org/content/cartography-brushes-for-gimp
- Creator: https://opengameart.org/users/yd
- License: https://creativecommons.org/licenses/by/3.0/
- Original archive: `YD_Cartography_Brushes.zip`
- Used for the fourteen landmark illustrations and engraved trees, mountains,
  and ships in the atlas backgrounds.

The smaller original brush illustrations retain their source detail and
resolution limits. Each destination combines its distinct main engraving with
source neighboring buildings and trees on a 256-pixel transparent canvas.
Small brushes stay close to native scale within that composition rather than
being enlarged to fill the canvas. Linear filtering and mipmaps are enabled
for phone display.

## Other acquired sources

| Artwork | Creator | Original source | License | Use |
| --- | --- | --- | --- | --- |
| Fantasy World Map | yd | https://opengameart.org/content/fantasy-world-map-0 | CC0 1.0 | Original layered paper, coastlines, ocean and waves; chapter crops exclude the source preview's place names |
| Cartography Pack | Kenney | https://opengameart.org/content/cartography-pack | CC0 1.0 | Compass, flag and banner artwork |
| UI Pack: RPG Expansion | Kenney Vleugels | https://kenney.nl/assets/ui-pack-rpg-expansion | CC0 1.0 | Framed buttons, chapter panel, level medallion and navigation arrows |
| Game Icons | Kenney Vleugels | https://kenney.nl/assets/game-icons | CC0 1.0 | Completion star, lock and trail stamp |

CC0 license: https://creativecommons.org/publicdomain/zero/1.0/
Original Kenney license files are preserved in `licenses/`. Source URLs,
download URLs, archive SHA-256 digests, acquisition status and motion status
are also recorded in `manifest.json`. The Web build carries source credits.

## Acquisition and preparation

Original archives are downloaded under
`C:/uworks/TalkQuest/downloads/map-refresh/`. The `FantasyWorldMap.xcf` file is
the actual source document, not the gallery preview. Its unlabeled layers were
exported with `gimpformats` and Pillow into `xcf-layers/`:

```python
from pathlib import Path
from gimpformats.gimpXcfDocument import GimpDocument

source = Path("C:/uworks/TalkQuest/downloads/map-refresh")
output = source / "xcf-layers"
output.mkdir(exist_ok=True)
document = GimpDocument(str(source / "FantasyWorldMap.xcf"))
for layer in document.raw_layers:
    layer.image.save(output / (layer.name + ".png"))
```

`tools/prepare-quest-map-assets.py` crops source coastlines into three chapter
regions, combines them with original paper and ocean textures, adds a subdued
coastline treatment, and places original engraved scenery. Interface panels
combine a source UI frame with the source paper texture. Landmark alpha masks
are preserved while the ink is tinted for readability.

```powershell
python tools/prepare-quest-map-assets.py --source C:/uworks/TalkQuest/downloads/map-refresh
```

The additional `YD_Cartography_Set02.zip` and MELLE parchment preview were
examined locally but are **not** used in the shipped atlas. They are not part
of its runtime source attribution or dependency set.
