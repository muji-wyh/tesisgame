"""Prepare source sky layers and provenance after the Blender miniature render."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageEnhance


def read_hdr(path):
    """Read the original Radiance RGBE scanlines without a lossy intermediate."""
    with path.open("rb") as stream:
        while stream.readline().strip():
            pass
        resolution = stream.readline().split()
        height, width = int(resolution[1]), int(resolution[3])
        pixels = np.zeros((height, width, 4), dtype=np.uint8)
        for y in range(height):
            header = stream.read(4)
            if header[:2] != b"\x02\x02":
                raise ValueError("Expected modern RGBE run-length encoding")
            for channel in range(4):
                x = 0
                while x < width:
                    count = stream.read(1)[0]
                    if count > 128:
                        length = count - 128
                        pixels[y, x:x + length, channel] = stream.read(1)[0]
                    else:
                        length = count
                        pixels[y, x:x + length, channel] = list(stream.read(length))
                    x += length
    return pixels[:, :, :3].astype(float) * np.exp2(pixels[:, :, 3:4].astype(float) - 136)


parser = argparse.ArgumentParser()
parser.add_argument("--source", default="C:/uworks/TalkQuest/downloads/map-dimensional")
parser.add_argument("--output", default="C:/uworks/tesisgame/assets/talk_quest/map-dimensional")
args = parser.parse_args()
source = Path(args.source)
output = Path(args.output)
output.mkdir(parents=True, exist_ok=True)
hdr = read_hdr(source / "kloofendal_48d_partly_cloudy_2k.hdr")
# Reinhard tone mapping preserves the acquired cloud texture, with no painted sky.
toned = np.power((hdr * .8) / (1.0 + hdr * .8), 1 / 2.2)
sky_source = Image.fromarray(np.uint8(np.clip(toned * 255, 0, 255)), "RGB")
preview = source / "sky-tone-mapped-preview.jpg"
sky_source.save(preview, quality=92)
# Only the upper hemisphere is used: the source landscape never enters the map.
sky = sky_source.crop((280, 20, 1816, 480)).resize((2048, 768), Image.Resampling.LANCZOS)
sky = ImageEnhance.Color(sky).enhance(1.45)
sky = ImageEnhance.Brightness(sky).enhance(1.32)
sky = ImageEnhance.Contrast(sky).enhance(.82)
sky.save(output / "sky.png", optimize=True)

# The original source cloud shape remains intact in the drifting foreground art.
cloud_source = source / "background-elements/PNG/cloud4.png"
cloud = Image.open(cloud_source).convert("RGBA")
cloud.save(output / "decoration-cloud.png", optimize=True)

old = json.loads((output.parent / "map/manifest.json").read_text())
acquired = json.loads((source / "acquisition-manifest.json").read_text())
titles = {"fantasy-town-kit": "Fantasy Town Kit 2.0", "castle-kit": "Castle Kit", "nature-kit": "Nature Kit", "background-elements": "Background Elements"}
sources = []
licenses = output / "licenses"
licenses.mkdir(exist_ok=True)
for entry in acquired:
    item = {"id": entry["id"], "title": entry.get("title", titles.get(entry["id"], entry["id"])), "creator": entry["creator"], "url": entry["sourceUrl"], "downloadUrl": entry["downloadUrl"], "license": entry["license"], "licenseUrl": entry["licenseUrl"], "sha256": entry["sha256"], "acquisitionStatus": "Downloaded original source and prepared for runtime integration", "animations": "Static acquired artwork or original model geometry; no authored source animation clips"}
    sources.append(item)
    original_license = source / entry["id"] / "License.txt"
    if original_license.exists():
        shutil.copyfile(original_license, licenses / (entry["id"] + ".txt"))
sources.extend([entry for entry in old["sources"] if entry["id"] in ("kenney-ui-rpg", "kenney-game-icons", "kenney-cartography", "yd-fantasy-world-map")])
shutil.copyfile(output.parent / "map/licenses/cc0-1.0.txt", licenses / "cc0-1.0.txt")
landmark_titles = ["Front Door Cottage", "Fountain Courtyard", "Windmill Bakery", "Village Wardrobe", "Woodland Bridge", "Art Pavilion", "Harvest Market", "Autumn Library", "Canopy Garden", "Coach Gateway", "Seaside Citadel", "Woodland Camp", "Festival Plaza", "Royal Toy Workshop"]
manifest = {
    "version": 1,
    "backgrounds": ["res://assets/talk_quest/map-dimensional/sky.png"],
    "landmarks": [f"res://assets/talk_quest/map-dimensional/level-{i:02}.png" for i in range(1, 15)],
    "landmarkSourceNames": landmark_titles,
    "ui": old["ui"],
    "decorations": {name: f"res://assets/talk_quest/map-dimensional/decoration-{name.replace('_', '-')}.png" for name in ("distant_island", "cloud", "bridge", "flag", "trail", "grove")},
    "sources": sources,
    "preparation": "Fourteen miniature island scenes assembled from original acquired Kenney GLB geometry and palette textures, rendered at 768 pixels with consistent isometric view, warm area lights, ray-traced contact shadows, and transparent background. No replacement mesh primitives. Original irregular platform mesh is scaled into raised island terrain. Sky is a tone-mapped sky-only crop of Greg Zaal's acquired HDRI. Foreground cloud is an acquired Kenney PNG.",
    "animation": "Source assets are static; scrolling, parallax, selection feedback, and ambient movement belong to the game presentation.",
    "render": {"engine": "Blender Cycles", "samples": 64, "resolution": [768, 768], "reproducibleTool": "tools/prepare-quest-dimensional-map.py", "finishingTool": "tools/finish-quest-dimensional-map.py"},
    "assets": [],
}
for path in sorted(output.glob("*.png")):
    image = Image.open(path)
    manifest["assets"].append({"path": "res://" + path.relative_to(output.parents[2]).as_posix(), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "bytes": path.stat().st_size, "size": list(image.size)})
(output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print("Prepared sky, cloud, licenses, and dimensional map manifest")
