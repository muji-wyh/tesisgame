"""Recolor the acquired Fluent star without replacing its modeled silhouette."""

import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DIRECTORY = ROOT / "assets/images/ui/jelly-goals"
SOURCE = DIRECTORY / "star.webp"
SOURCE_SHA = "cfbd55db7e7d74c5d68c4f881bbdb7102488ad67d5a24bafc897f2866532f100"
PALETTES = {
    "bronze": ("#633c28", "#b67449", "#efbd81", "#fff2d6"),
    "silver": ("#375875", "#87b1ce", "#d4ebfb", "#f3fcff"),
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    if digest(SOURCE) != SOURCE_SHA:
        raise RuntimeError("The acquired Fluent star has changed; review its artwork before recoloring.")
    source = Image.open(SOURCE).convert("RGBA")
    record_path = DIRECTORY / "sources.json"
    record = json.loads(record_path.read_text(encoding="utf-8"))
    record["shared_illustrations"] = [
        item for item in record["shared_illustrations"]
        if item["id"] not in ("rating-bronze", "rating-silver")
    ]
    for finish, colors in PALETTES.items():
        palette = [tuple(int(color[i:i + 2], 16) for i in (1, 3, 5)) for color in colors]
        result = source.copy()
        pixels = []
        data = source.tobytes()
        stops = [0.0, 0.65, 0.90, 1.0]
        for offset in range(0, len(data), 4):
            r, g, b, alpha = data[offset:offset + 4]
            shade = max(0.0, min(1.0, ((0.2126 * r + 0.7152 * g + 0.0722 * b) / 255 - 0.20) / 0.76))
            stop = next((index for index in range(3) if shade <= stops[index + 1]), 2)
            blend = (shade - stops[stop]) / (stops[stop + 1] - stops[stop])
            rgb = tuple(round(palette[stop][i] * (1 - blend) + palette[stop + 1][i] * blend) for i in range(3))
            pixels.append((*rgb, alpha))
        result.putdata(pixels)
        output = DIRECTORY / f"rating-{finish}.png"
        result.save(output, "PNG", optimize=True)
        if result.getchannel("A").tobytes() != source.getchannel("A").tobytes():
            raise RuntimeError("The rating adaptation must preserve the original star silhouette exactly.")
        original = next(item for item in record["shared_illustrations"] if item["id"] == "star")
        entry = dict(original)
        entry.pop("reused_from", None)
        entry.update({
            "id": f"rating-{finish}",
            "file": output.relative_to(ROOT).as_posix(),
            "adapted_from": SOURCE.relative_to(ROOT).as_posix(),
            "source_image_sha256": SOURCE_SHA,
            "integrated_sha256": digest(output),
            "processing": f"Game-authored {finish} luminance palette; original alpha, contour and lighting detail retained. tools/prepare-jelly-rating.py",
            "status": "Derived locally from the acquired production artwork; native presentation review is recorded separately from source inspection.",
        })
        record["shared_illustrations"].append(entry)
        print(f"{finish}: {output.name}, {digest(output)}")
    record_path.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
