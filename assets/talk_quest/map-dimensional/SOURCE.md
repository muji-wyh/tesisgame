# Talk Quest miniature archipelago artwork

The fourteen islands use acquired production models, assembled into distinct
miniature destinations and rendered as transparent 768-pixel images. The map
contains no creature portraits. These are renders of actual downloaded source
geometry and palette textures, not marketplace preview screenshots.

## Acquired sources

| Source | Creator | License | Use |
| --- | --- | --- | --- |
| [Fantasy Town Kit 2.0](https://kenney.nl/assets/fantasy-town-kit) | Kenney | CC0 1.0 | Timber and plaster buildings, roofs, windmill, market stalls, fountain, lamps, garden details |
| [Nature Kit](https://kenney.nl/assets/nature-kit) | Kenney | CC0 1.0 | Irregular raised island terrain, trees, rocks, bridges, paths, campsite, flowers, foliage, beach props |
| [Castle Kit](https://kenney.nl/assets/castle-kit) | Kenney | CC0 1.0 | Friendly blue-roof towers, arched gateways, flags and royal workshop architecture; no siege weapons are used |
| [Background Elements](https://kenney.nl/assets/background-elements) | Kenney | CC0 1.0 | Original transparent cloud artwork |
| [Kloofendal 48d Partly Cloudy](https://polyhaven.com/a/kloofendal_48d_partly_cloudy) | Greg Zaal / Poly Haven | CC0 1.0 | Tone-mapped sky-only crop of the original 2K HDRI; source ground scenery is excluded |

Original downloads are retained under
`C:/uworks/TalkQuest/downloads/map-dimensional/`. Their acquisition manifest
records original URLs and SHA-256 hashes. Original Kenney licenses and a CC0
license copy are preserved in `licenses/`. Poly Haven's original source page
identifies Greg Zaal as creator and explicitly applies CC0 1.0.

The interface textures referenced from the preceding `map/` directory retain
their original provenance in [that source record](../map/SOURCE.md): Kenney
Cartography, UI Pack RPG Expansion, Game Icons, and yd's CC0 Fantasy World Map
paper used in the prepared panel textures. No yd engraved building brushes
are part of these new miniature scenes.

## Preparation

The Blender preparation tool loads original GLB mesh geometry, UV mapping,
and source palette materials. Modular wall and roof pieces form complete
buildings. The source irregular `platform_grass` or `platform_beach` mesh is
scaled into a thick island plinth; source rock formations, trees, foliage,
and props give it detail and scale. It does not add replacement mesh primitives.

Every scene uses the same orthographic view direction, warm directional area
light, restrained sky fill, and Cycles contact shadows. Framing is fitted to the
actual source meshes with a ten-percent safety margin. Alpha is preserved, so
the runtime can place the islands at different depths without opaque cards.

The sky finishing tool decodes the original Radiance image, tone-maps it with a
Reinhard curve, crops only the upper hemisphere, then brightens the blue sky and
restrains contrast to keep playable islands in the foreground. The source cloud is copied
without drawing a replacement shape. Separate original-model renders provide
a bridge, flag, stone route, grove, and distant island for parallax composition.

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python tools/prepare-quest-dimensional-map.py -- --levels all --size 768 --samples 64
python tools/finish-quest-dimensional-map.py
```

`model-usage.json` lists the source model names. `manifest.json` records the
fourteen destinations, source and license metadata, prepared texture hashes,
dimensions, and reproduction tools. The repository contains only prepared
runtime images and source records, not complete asset-pack archives.

## Motion status

The selected source models and artwork are static. No source animation clips
are present in this integration. Inertial map movement, parallax, selection
feedback, and any ambient drifting are runtime presentation effects. The
source renders have been inspected as artwork; physical-device performance
and live interaction are separate runtime checks.
