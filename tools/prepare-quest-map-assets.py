"""Prepare Talk Quest atlas artwork from downloaded CC0 and CC BY 3.0 assets.

Run with --source pointing at the acquired map-refresh directory. Source XCF
layers must first be exported with gimpformats (documented in SOURCE.md).
No terrain, landmark, or interface artwork is procedurally drawn here: all
outputs are crops, color treatments, or compositions of source image pixels.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image, ImageChops, ImageEnhance, ImageFilter, ImageOps


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def ink(image: Image.Image, color: str = "#554633", opacity: float = 1.0) -> Image.Image:
    image = image.convert("RGBA")
    alpha = image.getchannel("A").point(lambda a: round(a * opacity))
    result = Image.new("RGBA", image.size, color)
    result.putalpha(alpha)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "assets/talk_quest/map")
    args = parser.parse_args()
    source, out = args.source, args.output
    out.mkdir(parents=True, exist_ok=True)
    (out / "licenses").mkdir(exist_ok=True)
    cartography = source / "cartography/PNG/Retina"
    ui = source / "ui-rpg/PNG"
    icons = source / "game-icons/PNG/Black/2x"
    layers = source / "xcf-layers"
    yd = source / "yd-brushes/YD_Cartography_Brushes"

    paper = Image.open(layers / "paper.png").convert("RGBA")
    land = Image.open(layers / "landmass.png").convert("RGBA")
    ocean = Image.open(layers / "ocean.png").convert("RGBA")
    waves = Image.open(layers / "waves.png").convert("RGBA")
    grid = Image.open(layers / "grid.png").convert("RGBA")
    crop = (42, 40, 1558, 1160)
    paper = paper.crop(crop).convert("RGB")
    paper = ImageEnhance.Brightness(ImageEnhance.Color(paper).enhance(0.75)).enhance(1.47)
    water_texture = ImageOps.colorize(ImageOps.grayscale(ocean.crop(crop)), "#607f76", "#afbaa4")
    water = Image.blend(paper, water_texture, 0.54)
    land_texture = Image.blend(paper, ImageEnhance.Brightness(land.crop(crop).convert("RGB")).enhance(1.3), 0.18)
    land_alpha = land.crop(crop).getchannel("A")
    atlas = Image.composite(land_texture, water, land_alpha).convert("RGBA")
    wave_pixels = waves.crop(crop)
    wave_alpha = ImageChops.multiply(ImageOps.grayscale(wave_pixels), wave_pixels.getchannel("A"))
    wave_alpha = ImageChops.multiply(wave_alpha, ImageOps.invert(land_alpha)).point(lambda a: round(a * 0.23))
    wave_ink = Image.new("RGBA", atlas.size, "#f0e1bc")
    wave_ink.putalpha(wave_alpha)
    atlas = Image.alpha_composite(atlas, wave_ink)
    atlas = Image.alpha_composite(atlas, ink(grid.crop(crop), "#665841", 0.075))

    # Different real regions of the same authored coastline keep the atlas
    # coherent while providing distinct geography for its three chapters.
    regions = [(758, 500, 1268, 860), (265, 0, 1148, 270), (410, 850, 1035, 1120)]
    backgrounds = []
    decoration_sets = [
        [("MAP9/trees/tree05", .12, .15, 98), ("MAP1/mount04", .61, .12, 185), ("MAP9/ships/ship04", .88, .88, 125), ("MAP9/trees/tree08", .39, .84, 90), ("MAP1/mount09", .09, .69, 142)],
        [("MAP1/mount04", .18, .13, 185), ("MAP9/trees/tree06", .70, .15, 90), ("MAP9/ships/ship04", .89, .88, 122), ("MAP9/trees/tree09", .82, .70, 88), ("MAP1/mount02", .35, .85, 165)],
        [("MAP9/trees/tree07", .16, .19, 95), ("MAP1/mount05", .63, .13, 190), ("MAP9/ships/ship03", .10, .66, 120), ("MAP9/trees/tree04", .58, .85, 96), ("MAP1/mount09", .82, .68, 154)],
    ]
    for index, (region, decorations) in enumerate(zip(regions, decoration_sets), start=1):
        chapter_mask = land_alpha.crop(region).resize((1600, 1200), Image.Resampling.LANCZOS)
        chapter_land = paper.resize((1600, 1200), Image.Resampling.LANCZOS)
        chapter_water = water.resize((1600, 1200), Image.Resampling.LANCZOS)
        chapter = Image.composite(chapter_land, chapter_water, chapter_mask).convert("RGBA")
        coast = ImageChops.subtract(chapter_mask.filter(ImageFilter.MaxFilter(9)), chapter_mask).point(lambda a: round(a * 0.42))
        coast_ink = Image.new("RGBA", chapter.size, "#655741")
        coast_ink.putalpha(coast)
        chapter.alpha_composite(coast_ink)
        chapter_waves = ImageChops.multiply(wave_alpha.resize(chapter.size), ImageOps.invert(chapter_mask))
        wave_ink = Image.new("RGBA", chapter.size, "#f4e4bd")
        wave_ink.putalpha(chapter_waves)
        chapter.alpha_composite(wave_ink)
        for name, x, y, extent in decorations:
            path = yd / f"{name}.gbr"
            if not path.exists():
                raise FileNotFoundError(path)
            decoration = ink(Image.open(path), opacity=0.40)
            decoration = ImageOps.contain(decoration, (extent, extent), Image.Resampling.LANCZOS)
            wanted_land = "/ships/" not in name
            px, py = round(x * chapter.width), round(y * chapter.height)
            candidates = [(px + dx, py + dy) for dx in range(-180, 181, 30) for dy in range(-150, 151, 30)]
            candidates.sort(key=lambda point: (point[0] - px) ** 2 + (point[1] - py) ** 2)
            for cx, cy in candidates:
                if 65 < cx < 1535 and 65 < cy < 1135 and (chapter_mask.getpixel((cx, cy)) > 180) == wanted_land:
                    px, py = cx, cy
                    break
            chapter.alpha_composite(decoration, (px - decoration.width // 2, py - decoration.height // 2))
        compass = ink(Image.open(cartography / "compass.png"), opacity=0.42)
        chapter.alpha_composite(compass, (1432, 1015))
        # Small groves and ridgelines use the original engraving pixels at
        # approximately native scale, with whitespace left around map stops.
        grove_centers = [(.34, .49), (.72, .56)] if index != 2 else [(.32, .48), (.70, .62)]
        for grove_index, (gx, gy) in enumerate(grove_centers):
            for tree_index, (dx, dy) in enumerate([(-62, -27), (-15, -42), (34, -27), (72, 10), (-37, 24), (13, 36)]):
                tree_name = f"tree{1 + (index * 3 + grove_index * 4 + tree_index) % 10:02}.gbr"
                tree = ink(Image.open(yd / "MAP9/trees" / tree_name), opacity=0.43)
                px = round(gx * 1600 + dx)
                py = round(gy * 1200 + dy)
                if chapter_mask.getpixel((px, py)) > 180:
                    chapter.alpha_composite(tree, (px - tree.width // 2, py - tree.height // 2))
        for mountain_index, (mx, my) in enumerate([(.47, .43), (.55, .455), (.61, .45)]):
            mountain = ink(Image.open(yd / f"MAP1/mount{4 + (index + mountain_index) % 4:02}.gbr"), opacity=0.33)
            px, py = round(mx * 1600), round(my * 1200)
            if chapter_mask.getpixel((px, py)) > 180:
                chapter.alpha_composite(mountain, (px - mountain.width // 2, py - mountain.height // 2))
        filename = f"atlas-{index:02}.png"
        chapter.convert("RGB").save(out / filename, optimize=True)
        backgrounds.append(f"res://assets/talk_quest/map/{filename}")

    landmark_names = ["MAP9/houses/house01", "MAP14/house01", "MAP9/houses/house03", "MAP9/houses/house06", "MAP9/settlement01", "MAP14/house03", "MAP12/settlement01", "MAP14/house02", "MAP12/settlement02", "MAP9/ships/ship04", "MAP14/house04", "MAP6/settlement", "MAP14/house05", "MAP14/house06"]
    landmarks = []
    for level, name in enumerate(landmark_names, start=1):
        filename = f"level-{level:02}.png"
        origin = yd / f"{name}.gbr"
        if not origin.exists():
            raise FileNotFoundError(origin)
        canvas = Image.new("RGBA", (256, 256))
        main_source = Image.open(origin).convert("RGBA")
        # Compose a small place instead of magnifying a small source brush.
        # At the map's rendered size these pixels are generally downsampled.
        main_ratio = min(1.32, 182 / main_source.width, 174 / main_source.height)
        main_size = (round(main_source.width * main_ratio), round(main_source.height * main_ratio))
        main = ink(main_source, "#473420").resize(main_size, Image.Resampling.LANCZOS)
        forest_first = 1 + (level * 2) % 10
        scenery = [
            (yd / f"MAP9/trees/tree{forest_first:02}.gbr", 54, 122, .66, .92),
            (yd / f"MAP9/trees/tree{1 + forest_first % 10:02}.gbr", 203, 151, .69, .89),
            (yd / f"MAP9/trees/tree{1 + (forest_first + 3) % 10:02}.gbr", 32, 183, .64, .76),
        ]
        if level != 12:
            rear_left = 1 + level % 6
            rear_right = 1 + (level + 2) % 6
            scenery += [
                (yd / f"MAP9/houses/house{rear_left:02}.gbr", 78, 164, .63, .84),
                (yd / f"MAP9/houses/house{rear_right:02}.gbr", 190, 206, .66, .84),
            ]
        else:
            scenery += [
                (yd / "MAP9/trees/tree08.gbr", 95, 155, .63, .96),
                (yd / "MAP9/trees/tree02.gbr", 173, 179, .65, .96),
            ]
        for scene_source, px, baseline, opacity, scale in scenery:
            piece = ink(Image.open(scene_source), "#584631", opacity)
            piece = piece.resize((round(piece.width * scale), round(piece.height * scale)), Image.Resampling.LANCZOS)
            canvas.alpha_composite(piece, (px - piece.width // 2, baseline - piece.height))
        canvas.alpha_composite(main, ((256 - main.width) // 2, 246 - main.height))
        canvas.save(out / filename, optimize=True)
        landmarks.append(f"res://assets/talk_quest/map/{filename}")

    ui_assets = {
        "panel": (ui / "buttonLong_beige.png", False),
        "badge": (ui / "buttonRound_beige.png", False),
        "cleared": (icons / "star.png", True),
        "locked": (icons / "locked.png", True),
        "current": (cartography / "flag.png", True),
        "trail": (icons / "minus.png", True),
        "previous": (ui / "arrowBrown_left.png", False),
        "next": (ui / "arrowBrown_right.png", False),
        "compass": (cartography / "compass.png", True),
        "banner": (cartography / "banner.png", True),
        "button": (ui / "buttonLong_beige.png", False),
        "button_pressed": (ui / "buttonLong_beige_pressed.png", False),
        "frame": (ui / "panel_beige.png", False),
    }
    ui_manifest = {}
    for name, (origin, tint) in ui_assets.items():
        filename = f"ui-{name}.png"
        if tint:
            ink(Image.open(origin)).save(out / filename, optimize=True)
        else:
            shutil.copyfile(origin, out / filename)
        ui_manifest[name] = f"res://assets/talk_quest/map/{filename}"
    panel = Image.open(out / "ui-panel.png").convert("RGBA")
    grain = paper.crop((250, 200, 1150, 500)).resize(panel.size, Image.Resampling.LANCZOS).convert("RGBA")
    grain.putalpha(panel.getchannel("A"))
    Image.blend(panel, grain, 0.18).save(out / "ui-panel.png", optimize=True)
    trail = Image.open(out / "ui-trail.png").convert("RGBA")
    trail.crop(trail.getchannel("A").getbbox()).save(out / "ui-trail.png", optimize=True)

    source_entries = [
        ("yd-fantasy-world-map", "Fantasy World Map", "yd", "https://opengameart.org/content/fantasy-world-map-0", "https://opengameart.org/sites/default/files/FantasyWorldMap.xcf", "FantasyWorldMap.xcf"),
        ("kenney-cartography", "Cartography Pack", "Kenney", "https://opengameart.org/content/cartography-pack", "https://opengameart.org/sites/default/files/cartographypack.zip", "cartographypack.zip"),
        ("kenney-ui-rpg", "UI Pack: RPG Expansion", "Kenney Vleugels", "https://kenney.nl/assets/ui-pack-rpg-expansion", "https://kenney.nl/media/pages/assets/ui-pack-rpg-expansion/7ec4a46657-1677661824/kenney_ui-pack-rpg-expansion.zip", "kenney-ui-rpg.zip"),
        ("kenney-game-icons", "Game Icons", "Kenney Vleugels", "https://kenney.nl/assets/game-icons", "https://kenney.nl/media/pages/assets/game-icons/1ebf9c14af-1677661579/kenney_game-icons.zip", "kenney-game-icons.zip"),
    ]
    sources = []
    for source_id, title, creator, url, download, filename in source_entries:
        sources.append({"id": source_id, "title": title, "creator": creator, "url": url, "downloadUrl": download, "license": "CC0 1.0", "licenseUrl": "https://creativecommons.org/publicdomain/zero/1.0/", "sha256": digest(source / filename), "acquisitionStatus": "Downloaded and extracted from the original public asset source", "animations": "Static artwork; no source animation"})
    sources.append({"id": "yd-cartography-brushes", "title": "Cartography brushes for GIMP", "creator": "yd", "url": "https://opengameart.org/content/cartography-brushes-for-gimp", "downloadUrl": "https://opengameart.org/sites/default/files/YD_Cartography_Brushes.zip", "license": "CC BY 3.0", "licenseUrl": "https://creativecommons.org/licenses/by/3.0/", "sha256": digest(source / "YD_Cartography_Brushes.zip"), "acquisitionStatus": "Downloaded and extracted from the original public asset source", "animations": "Static artwork; no source animation", "attribution": "Cartography brushes for GIMP by yd, licensed CC BY 3.0. Adapted by cropping, resizing, tinting, and compositing into Talk Quest map artwork."})
    manifest = {"version": 1, "backgrounds": backgrounds, "landmarks": landmarks, "landmarkSourceNames": landmark_names, "ui": ui_manifest, "sources": sources, "preparation": "Authored XCF layers cropped and color-treated; source cartography sprites placed as engraved scenery. No generated terrain or placeholder illustrations.", "animation": "Source assets are static; interface movement is provided separately by the game."}
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    for source_file, target_file in [("cartography/License.txt", "kenney-cartography.txt"), ("ui-rpg/license.txt", "kenney-ui-rpg.txt"), ("game-icons/License.txt", "kenney-game-icons.txt")]:
        shutil.copyfile(source / source_file, out / "licenses" / target_file)
    for import_file in out.glob("*.png.import"):
        text = import_file.read_text(encoding="utf-8")
        import_file.write_text(text.replace("mipmaps/generate=false", "mipmaps/generate=true"), encoding="utf-8")
    print(json.dumps({"backgrounds": len(backgrounds), "landmarks": len(landmarks), "ui": len(ui_manifest), "output": str(out)}, indent=2))


if __name__ == "__main__":
    main()
