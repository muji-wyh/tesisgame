"""Prepare one private, sourced, looping atlas for merged Jelly tier accents."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


CELL = 96
FRAMES = 32
COLUMNS = 16
SUPERSAMPLE = 4
LOOP_SECONDS = 3.2
TAU = math.tau
OUTPUT_RELATIVE = Path("assets/images/jelly-level-fx")
ATLAS_RESOURCE_PATH = f"res://{OUTPUT_RELATIVE.as_posix()}/atlas.png"
ATLAS_IMPORT_UID = "uid://biae2b4tnphiv"
REQUIRED_IMPORT_PARAMS = {
    "compress/mode": "0",
    "mipmaps/generate": "false",
    "process/premult_alpha": "false",
    "process/size_limit": "0",
}
KENNEY_DEFAULT = "Q:/uwok/Kenney Game Assets All-in-1 3.7.0/2D assets/Particle Pack/PNG (Transparent)"
TOON_DEFAULT = "Q:/uwok/AssetsSource/Toon FX [1.52]/Textures"
SOURCES = {
    "bubble": ("toon", "bubble_white.png", 76011, "a63454f2080d70c66ce3d39ff015b99ef0d89a05f8f07d6517bdc792480dfdbe"),
    "soap": ("toon", "bubble_soap.png", 232595, "2b762c08b12f8bfbdb875579ec9bf19060c4bf324abb5ee812be5b288fc1034f"),
    "flower": ("toon", "flowerpink2x2.png", 168457, "008c9ab9a814a5a790d11f31616941c85108822ddd9594f21307b2c62babe321"),
    "fire": ("toon", "fire2x2.png", 163322, "76fc9167104d9fc044381b52e6ababfb089c01d6d464af90df140fef75f40952"),
    "star": ("toon", "star.png", 124889, "d82ce5749291fbff8a90b30c3b98523f77a1b24e0b7e52d6131a6a836a28a8dd"),
    "rays": ("toon", "glowlines.png", 19013, "75ecb9a8d2c20b4892dc45160decb6d18387ce3892f7fc8ee2401d5f8773d8c1"),
    "ring": ("kenney", "circle_02.png", 43380, "8a2112a6a5610c7cdcbfe8af0a5162b42dfb3431c63f494743945337b7981e51"),
    "spiral": ("kenney", "twirl_03.png", 81463, "69baaab4bc68473e9f926dc249a1d1b58f759c88906e10ac859bf43ac3cfbc8b"),
    "prism": ("kenney", "magic_03.png", 58093, "c2ef5fe86cd2fd08e5b9768389ab6580b346c391db3c7c09fc9b0a63e00ec4ce"),
    "ribbon": ("kenney", "trace_03.png", 42254, "a8c05800698cd502c3416a1f2335292544d52b3c8624c3c829a534c52b364860"),
    "crescent": ("kenney", "slash_01.png", 25465, "cb4787978122bb863866a1681af22a7dec39a4566f08c400f233740eb1d3730c"),
    "constellation": ("kenney", "magic_01.png", 81687, "398479ea280c8161d0b6d509ca97eefb27e989c7832b404abcb65faae3e922ff"),
    "glint": ("kenney", "star_06.png", 35453, "65d3ff5aa87ec0770c11fe1293fdc70cdc5ccf0eabc2e2fd6a1ead922051035e"),
}
PROFILES = [
    ("pearl", "Pearl bubbles", ["bubble"], "Three pearly bubbles gently rise around the outside of the gel."),
    ("ripple", "Twin crystal ripples", ["ring"], "Two nested aqua rings breathe out of phase around the perimeter."),
    ("spiral", "Sapphire spiral", ["spiral", "glint"], "Opposing blue and lavender arcs turn with a small orbiting glint."),
    ("firework", "Golden firework bloom", ["fire", "rays"], "Five outward golden flamelets breathe around a restrained radial bloom."),
    ("cascade", "Rose cascade", ["flower"], "Three pink flowers flutter down the two sides with staggered translucent tails."),
    ("bouquet", "Prismatic bouquet", ["prism", "soap"], "Four diamond points shimmer in different colors with two iridescent bubbles."),
    ("aurora", "Aurora ribbons", ["ribbon", "crescent"], "Mint and violet wavy light strands sway at the sides with a soft upper ribbon."),
    ("constellation", "Constellation shimmer", ["constellation", "star", "glint"], "A fine five-node constellation surrounds five independently twinkling rim stars."),
    ("grand_bouquet", "Grand golden crown", ["star", "rays", "glint"], "A three-star gold crest glows above the Jelly with small lower-rim accents."),
]


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def clamp(value: float) -> float:
    return min(1.0, max(0.0, value))


def colorize(source: Image.Image, color: tuple[int, int, int], opacity: float) -> Image.Image:
    result = source.copy()
    alpha = result.getchannel("A").point(lambda value: round(value * clamp(opacity)))
    rgb = ImageChops.multiply(result.convert("RGB"), Image.new("RGB", result.size, color))
    result = rgb.convert("RGBA")
    result.putalpha(alpha)
    return result


def stamp(canvas: Image.Image, source: Image.Image, point: tuple[float, float],
          extent: tuple[float, float], color: tuple[int, int, int] = (255, 255, 255),
          opacity: float = 1.0, angle: float = 0.0) -> None:
    if opacity <= 0.001:
        return
    artwork = colorize(source, color, opacity)
    artwork = artwork.resize((max(1, round(extent[0] * SUPERSAMPLE)),
                              max(1, round(extent[1] * SUPERSAMPLE))), Image.Resampling.LANCZOS)
    if angle:
        artwork = artwork.rotate(angle, resample=Image.Resampling.BICUBIC, expand=True)
    at = (round(point[0] * SUPERSAMPLE - artwork.width * 0.5),
          round(point[1] * SUPERSAMPLE - artwork.height * 0.5))
    canvas.alpha_composite(artwork, at)


def cell_variant(source: Image.Image, index: int) -> Image.Image:
    half_x, half_y = source.width // 2, source.height // 2
    x, y = index % 2 * half_x, index // 2 * half_y
    return source.crop((x, y, x + half_x, y + half_y))


def quadrant_color(source: Image.Image) -> Image.Image:
    """Keep the source's alpha contour and shade its four diamond points."""
    result = source.copy()
    colors = [(244, 202, 255), (142, 239, 255), (255, 222, 151), (170, 255, 214)]
    tint = Image.new("RGB", result.size)
    pixels = tint.load()
    for y in range(result.height):
        for x in range(result.width):
            angle = math.atan2(y - result.height / 2, x - result.width / 2)
            index = round(angle / (math.pi / 2)) % 4
            pixels[x, y] = colors[index]
    rgb = ImageChops.multiply(result.convert("RGB"), tint)
    result = rgb.convert("RGBA")
    result.putalpha(source.getchannel("A"))
    return result


def compose(level: int, frame: int, art: dict[str, Image.Image]) -> Image.Image:
    phase = frame / FRAMES
    clock = phase * TAU
    canvas = Image.new("RGBA", (CELL * SUPERSAMPLE, CELL * SUPERSAMPLE))
    if level == 1:
        for index, (x, y, edge) in enumerate([(12, 39, 15), (82, 64, 12), (69, 13, 11)]):
            bob = math.sin(clock + index * 2.1)
            stamp(canvas, art["bubble"], (x + bob * 1.2, y - bob * 3.0), (edge, edge),
                  (255, 246, 209), 0.78 + 0.14 * math.cos(clock + index))
    elif level == 2:
        for index in range(2):
            swell = math.sin(clock + index * math.pi)
            edge = 78 + index * 9 + swell * 4.0
            stamp(canvas, art["ring"], (48, 48), (edge, edge * 0.91),
                  (132, 231, 252) if index == 0 else (216, 254, 255), 0.68 + swell * 0.10,
                  index * 17)
    elif level == 3:
        for index in range(2):
            stamp(canvas, art["spiral"], (48, 48), (88, 88),
                  (159, 179, 255) if index == 0 else (205, 226, 255), 0.80 if index == 0 else 0.56,
                  phase * 360 + index * 180)
        angle = clock + 0.55
        stamp(canvas, art["glint"], (48 + math.cos(angle) * 38, 48 + math.sin(angle) * 35),
              (12, 12), (231, 224, 255), 0.94)
    elif level == 4:
        stamp(canvas, art["rays"], (48, 48), (87, 87), (255, 206, 93),
              0.31 + math.sin(clock) * 0.07, math.sin(clock) * 7.0)
        for index in range(5):
            angle = -math.pi / 2 + index * TAU / 5
            pulse = math.sin(clock + index * 1.15)
            radius = 36 + pulse * 1.7
            point = (48 + math.cos(angle) * radius, 48 + math.sin(angle) * radius)
            stamp(canvas, cell_variant(art["fire"], index % 4), point,
                  (14 + pulse, 18 + pulse * 1.5), (255, 222, 131), 0.84 + pulse * 0.12,
                  -math.degrees(angle) - 90)
    elif level == 5:
        for index in range(3):
            age = (phase + index / 3 + 0.18) % 1.0
            opacity = 0.90 * math.sin(age * math.pi) ** 1.2
            x = 12 + math.sin(clock + index * 2.1) * 2.7 if index != 1 else 83 + math.sin(clock + 2) * 2
            y = 19 + age * 60
            edge = 15 if index == 1 else 14
            stamp(canvas, cell_variant(art["flower"], 0), (x, y), (edge, edge),
                  (255, 229, 255), opacity, math.sin(clock + index) * 20)
    elif level == 6:
        stamp(canvas, art["prism_colored"], (48, 48), (88, 88), opacity=0.87 + math.sin(clock) * 0.06,
              angle=math.sin(clock) * 5)
        for index, point in enumerate([(12, 74), (83, 23)]):
            bob = math.sin(clock + index * math.pi)
            stamp(canvas, art["soap"], (point[0] + bob, point[1] - bob * 2.0), (12, 12),
                  opacity=0.79 + bob * 0.10)
    elif level == 7:
        for index in range(2):
            bob = math.sin(clock + index * 1.7)
            x = 10 + bob * 2.1 if index == 0 else 86 + bob * 2.1
            stamp(canvas, art["ribbon_cropped"], (x, 48 + bob * 1.8), (10, 63),
                  (171, 255, 225) if index == 0 else (222, 185, 255), 0.89 + bob * 0.08,
                  bob * 6)
        stamp(canvas, art["crescent"], (48, 15 + math.sin(clock) * 1.6), (64, 18),
              (178, 255, 232), 0.75, math.sin(clock) * 4)
    elif level == 8:
        stamp(canvas, art["constellation"], (48, 48), (91, 91), (173, 196, 255),
              0.70 + math.sin(clock) * 0.08, math.sin(clock) * 3.0)
        points = [(48, 18), (82, 37), (71, 77), (25, 77), (14, 37)]
        colors = [(219, 228, 255), (171, 252, 249), (245, 222, 255), (255, 234, 186), (184, 209, 255)]
        for index, point in enumerate(points):
            twinkle = (math.sin(clock + index * 1.9) + 1) * 0.5
            stamp(canvas, art["star"], point, (9 + twinkle * 4, 9 + twinkle * 4), colors[index],
                  0.69 + twinkle * 0.29, math.sin(clock + index) * 12)
    elif level == 9:
        stamp(canvas, art["rays"], (48, 48), (91, 91), (255, 210, 102),
              0.37 + math.sin(clock) * 0.06, math.sin(clock) * 9.0)
        for index, (x, y, edge) in enumerate([(32, 18, 13), (48, 12, 16), (64, 18, 13)]):
            bob = math.sin(clock + index * 0.6)
            stamp(canvas, art["star"], (x, y - bob * 0.9), (edge, edge), (255, 225, 124),
                  0.92 + bob * 0.06, bob * 5)
        for index, point in enumerate([(13, 60), (82, 62), (29, 83), (68, 82)]):
            twinkle = (math.cos(clock + index * 1.6) + 1) * 0.5
            stamp(canvas, art["glint"], point, (7 + twinkle * 3, 7 + twinkle * 3), (255, 237, 159),
                  0.62 + twinkle * 0.30)
    # This is a content exclusion mask, not replacement particle artwork.
    mask = Image.new("L", canvas.size, 255)
    ImageDraw.Draw(mask).rounded_rectangle(tuple(round(value * SUPERSAMPLE) for value in (30, 27, 66, 70)),
                                           radius=9 * SUPERSAMPLE, fill=0)
    canvas.putalpha(ImageChops.multiply(canvas.getchannel("A"), mask))
    return canvas.resize((CELL, CELL), Image.Resampling.LANCZOS)


def load_sources(args: argparse.Namespace) -> tuple[dict[str, Image.Image], list[dict]]:
    roots = {"toon": args.toon_root, "kenney": args.kenney_root}
    images, records = {}, []
    for key, (package, filename, expected_bytes, expected_hash) in SOURCES.items():
        source = roots[package] / filename
        data = source.read_bytes()
        if len(data) != expected_bytes or digest(data) != expected_hash:
            raise ValueError(f"The acquired {package} source differs from the inspected original: {source}")
        image = Image.open(source).convert("RGBA")
        images[key] = image
        records.append({"id": key, "source_id": package, "original_relative_path":
                        f"Textures/{filename}" if package == "toon" else f"PNG (Transparent)/{filename}",
                        "local_source": str(source).replace("\\", "/"), "bytes": len(data),
                        "sha256": expected_hash, "dimensions": list(image.size),
                        "acquisition_status": "Previously user-acquired locally; original source bytes verified before composition",
                        "animation": "Four supplied particle/view cells, used as static variants here; Unity particle playback is not imported"
                        if "2x2" in filename else "Static transparent particle artwork; no source animation clip"})
    images["prism_colored"] = quadrant_color(images["prism"])
    ribbon = images["ribbon"]
    visible_ribbon = ribbon.getchannel("A").point(lambda value: 255 if value >= 16 else 0)
    images["ribbon_cropped"] = ribbon.crop(visible_ribbon.getbbox())
    return images, records


def metadata(records: list[dict], output: Path) -> dict:
    return {"version": 1, "prepared_on": "2026-11-04", "generator": "tools/prepare-merged-jelly-fx.py",
            "status": "Source-derived private runtime atlas generated and inspected locally; runtime integration is separate",
            "sources": {
                "toon": {"title": "Toon FX 1.52", "creator": "Kenneth Foldal Moe / Archanor VFX",
                         "source_url": "https://assetstore.unity.com/packages/vfx/particles/toon-fx-25601",
                         "license": "Standard Unity Asset Store EULA; embedded game artwork only",
                         "license_record": "docs/assets/jelly-fragments.md#confetti-source-and-preparation",
                         "acquisition_status": "Pre-existing user-acquired package; no new purchase",
                         "animation": "Static particle images and separate Unity prefabs; no Unity prefab or script imported"},
                "kenney": {"title": "Particle Pack 1.1", "creator": "Kenney",
                           "source_url": "https://kenney.nl/assets/particle-pack", "license": "CC0-1.0",
                           "license_file": "assets/chests/sources/states/kenney-particles/LICENSE.txt",
                           "source_collection": "User-acquired Kenney Game Assets All-in-1 3.7.0",
                           "acquisition_status": "Pre-existing local source collection; original files verified",
                           "animation": "Static transparent particle sprites; motion authored by the game"}},
            "input_files": records,
            "atlas": {"path": "assets/images/jelly-level-fx/atlas.png", "dimensions": [1536, 1728],
                      "cell_size": [CELL, CELL], "columns": COLUMNS, "rows": 18,
                      "frames_per_level": FRAMES, "level_count": 9, "loop_seconds": LOOP_SECONDS,
                      "frame_order": "Each level occupies two consecutive rows; frames 0..15 in the first and 16..31 in the second",
                      "sampling": "RGBA, four-times supersampled source compositions; frame 0 is a distinct static tier cue",
                      "animation": "Game-authored 3.2-second loop from static source motifs; runtime interpolates adjacent frames",
                      "sha256": digest(output.read_bytes()), "bytes": output.stat().st_size,
                      "distribution": "Private derived artwork embedded in the compiled game; atlas and imports remain ignored"},
            "profiles": [{"level": level, "id": item[0], "name": item[1], "source_motifs": item[2],
                          "recipe": item[3], "atlas_rows": [(level - 1) * 2, (level - 1) * 2 + 1],
                          "content_exclusion": "Transparent center preserves pictures and spelling; source motifs frame the rim"}
                         for level, item in enumerate(PROFILES, 1)]}


def contact_sheet(atlas: Image.Image, output: Path) -> None:
    # A source-derived composition preview, rather than a game render.
    width = 5 * 160
    preview = Image.new("RGB", (width, 9 * 144), "#274557")
    draw = ImageDraw.Draw(preview)
    for level, profile in enumerate(PROFILES, 1):
        y = (level - 1) * 144
        draw.text((8, y + 4), f"Lv{level}: {profile[1]}", fill="#f9f4df")
        for column, frame in enumerate([0, 8, 16, 24, 31]):
            x = frame % COLUMNS * CELL
            row = (level - 1) * 2 + frame // COLUMNS
            sprite = atlas.crop((x, row * CELL, x + CELL, row * CELL + CELL))
            preview.paste(sprite, (column * 160 + 32, y + 24), sprite)
            draw.text((column * 160 + 39, y + 124), f"Frame {frame:02d}", fill="#e8ecff")
    output.parent.mkdir(parents=True, exist_ok=True)
    preview.save(output)


def import_values(text: str) -> dict[str, dict[str, str]]:
    """Read the simple scalar entries used by a Godot texture import sidecar."""
    sections: dict[str, dict[str, str]] = {}
    section = ""
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            sections.setdefault(section, {})
        elif section and "=" in line:
            key, value = line.split("=", 1)
            sections[section][key.strip()] = value.strip()
    return sections


def prepare_import(output_dir: Path) -> None:
    sidecar = output_dir / "atlas.png.import"
    existing = import_values(sidecar.read_text(encoding="utf-8")) if sidecar.exists() else {}
    resource_hash = hashlib.md5(ATLAS_RESOURCE_PATH.encode("utf-8")).hexdigest()
    default_path = f"res://.godot/imported/atlas.png-{resource_hash}.ctex"
    remap = existing.get("remap", {})
    uid = remap.get("uid", json.dumps(ATLAS_IMPORT_UID))
    texture_path = remap.get("path", json.dumps(default_path))
    # Keep Godot's established resource identity while enforcing atlas-safe sampling.
    sidecar.write_text(f'''[remap]

importer="texture"
type="CompressedTexture2D"
uid={uid}
path={texture_path}
metadata={{
"vram_texture": false
}}

[deps]

source_file="{ATLAS_RESOURCE_PATH}"
dest_files=[{texture_path}]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.85
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
''', encoding="utf-8")


def readme() -> str:
    rows = "\n".join(f"| {level} | `{item[0]}` | {item[1]} | {item[3]} |" for level, item in enumerate(PROFILES, 1))
    return f"""# Merged Jelly level accents

This private atlas composes previously acquired production particle artwork into
nine different rim effects. Each level keeps a recognizable static frame as well
as a 3.2-second loop. It adds no gameplay rules, text labels, audio or hit targets.
Runtime integration and device rendering are verified separately from this source
composition preview.

| Level | Profile | Effect | Composition |
| --- | --- | --- | --- |
{rows}

`sources.json` records original source locations, creators, licenses, byte counts,
SHA-256 hashes, source animation availability and each composition recipe.
The source images were inspected on dark backgrounds and at small particle size.
Toon FX by Kenneth Foldal Moe / Archanor VFX retains its existing Standard Unity
Asset Store EULA and embedded-game restrictions, documented in
[Jelly fragments](../../../docs/assets/jelly-fragments.md). Kenney's Particle
Pack 1.1 comes from the user's local All-in-1 3.7.0 collection under CC0-1.0; the
existing [license](../../chests/sources/states/kenney-particles/LICENSE.txt) is
retained. No new asset purchase or listing-preview extraction is performed.

The originals are static images. The Toon flower and flame `2x2` sheets contain
four supplied particle views; this composition uses them as static variants and
does not import Unity particle playback. The loop uses game-authored placement,
rotation, tint and alpha. Its transparent
center reserves the learning picture and spelling. No source pixel art is
replaced with procedural shapes, and Unity prefabs and scripts are not executed.

The atlas is 1536 by 1728 RGBA: sixteen columns of 96-pixel cells and eighteen
rows. Each level uses two consecutive rows and thirty-two frames. Frame zero is
the reduced-motion cue. Runtime may interpolate frames for smooth playback and
freeze its local clock outside the existing animation budget. Source composition
is rendered at four times the final size and downsampled for clean small rims.
The original sources remain outside the repository; the derived atlas and Godot
imports remain ignored and ship only inside the compiled game pack.
The generated `atlas.png.import` sidecar uses lossless compression, no mipmaps,
no resizing and straight alpha to preserve the small rim artwork and cell edges.
It preserves an existing texture UID and import path. This sidecar accompanies
the private source-derived atlas and remains ignored with it under the same
embedded-game asset distribution restrictions.

Regenerate from the acquired source roots:

```powershell
python tools/prepare-merged-jelly-fx.py
```

Use `--toon-root`, `--kenney-root` and `--repo-root` to override source or repository
roots. Input hashes are verified before output is written. Use `--check` to
validate the prepared atlas against its recorded hash and layout without needing
the source collection, and validate the required import settings when its sidecar
is present. The contact sheet at
`build/qa/merged-jelly-level-fx/source-atlas-contact.png` previews the actual derived
atlas on a dark background; it is not a game screenshot or physical-device test.
"""


def check_prepared(output_dir: Path) -> None:
    manifest = json.loads((output_dir / "sources.json").read_text(encoding="utf-8"))
    image_path = output_dir / "atlas.png"
    data = image_path.read_bytes()
    image = Image.open(image_path)
    if image.mode != "RGBA" or image.size != (1536, 1728):
        raise ValueError("The merged Jelly atlas must be 1536 by 1728 RGBA")
    if digest(data) != manifest["atlas"]["sha256"] or len(data) != manifest["atlas"]["bytes"]:
        raise ValueError("The merged Jelly atlas differs from its inspected source composition")
    if [profile["id"] for profile in manifest["profiles"]] != [profile[0] for profile in PROFILES]:
        raise ValueError("The merged Jelly atlas has a different level profile order")
    for level in range(9):
        if image.crop((0, level * 2 * CELL, CELL, (level * 2 + 1) * CELL)).getchannel("A").getbbox() is None:
            raise ValueError(f"Level {level + 1} needs a visible static frame")
    sidecar = output_dir / "atlas.png.import"
    if sidecar.exists():
        params = import_values(sidecar.read_text(encoding="utf-8")).get("params", {})
        for key, expected in REQUIRED_IMPORT_PARAMS.items():
            if params.get(key) != expected:
                raise ValueError(f"The merged Jelly atlas import needs {key}={expected}")
    print(f"Verified merged Jelly level atlas: {image.size}, 9 levels, 32 frames each")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--toon-root", type=Path, default=Path(TOON_DEFAULT))
    parser.add_argument("--kenney-root", type=Path, default=Path(KENNEY_DEFAULT))
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    output_dir = args.repo_root / OUTPUT_RELATIVE
    if args.check:
        check_prepared(output_dir)
        return
    art, records = load_sources(args)
    atlas = Image.new("RGBA", (1536, 1728))
    for level in range(1, 10):
        for frame in range(FRAMES):
            x = frame % COLUMNS * CELL
            y = ((level - 1) * 2 + frame // COLUMNS) * CELL
            atlas.paste(compose(level, frame, art), (x, y))
    output_dir.mkdir(parents=True, exist_ok=True)
    atlas_path = output_dir / "atlas.png"
    atlas.save(atlas_path, optimize=True)
    (output_dir / "sources.json").write_text(json.dumps(metadata(records, atlas_path), indent=2) + "\n", encoding="utf-8")
    (output_dir / "README.md").write_text(readme(), encoding="utf-8")
    prepare_import(output_dir)
    contact_sheet(atlas, args.repo_root / "build/qa/merged-jelly-level-fx/source-atlas-contact.png")
    check_prepared(output_dir)


if __name__ == "__main__":
    main()
