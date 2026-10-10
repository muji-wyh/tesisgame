"""Prepare licensed Toon FX coin artwork without importing Unity behaviors."""

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


SOURCE_SHA256 = "ee6f261c5c0ef92aeef1f1885375336d472f166bd6835ee18957626f46a98077"
GOLD_STOPS = (
    (111, (146, 94, 12)),
    (165, (226, 156, 27)),
    (200, (255, 206, 65)),
    (236, (255, 239, 157)),
    (255, (255, 250, 210)),
)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def gold_channel(channel):
    lut = []
    for value in range(256):
        color = GOLD_STOPS[0][1][channel]
        for (low, first), (high, last) in zip(GOLD_STOPS, GOLD_STOPS[1:]):
            if value < low:
                break
            weight = min(1, (value - low) / (high - low))
            color = round(first[channel] + (last[channel] - first[channel]) * weight)
        lut.append(color)
    return lut


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path(
        "C:/uworks/AssetsSource/Toon FX [1.52]/Textures/coins.png"))
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parent)
    args = parser.parse_args()
    source_hash = digest(args.source)
    if source_hash != SOURCE_SHA256:
        raise SystemExit("The acquired coin source differs from the inspected version.")
    original = Image.open(args.source).convert("RGBA")
    if original.size != (1024, 1024):
        raise SystemExit("Expected the inspected 1024px four-angle coin atlas.")
    luminance = original.getchannel("R")
    colored = Image.merge("RGBA", tuple(
        luminance.point(gold_channel(channel)) for channel in range(3)
    ) + (original.getchannel("A"),))
    atlas = Image.new("RGBA", (256, 256))
    frames = []
    for index in range(4):
        x, y = index % 2, index // 2
        # The common crop preserves the relative width of each authored angle.
        frame = colored.crop((x * 512 + 48, y * 512 + 48,
                              x * 512 + 464, y * 512 + 464))
        frame = frame.resize((128, 128), Image.Resampling.LANCZOS)
        frames.append(frame)
        atlas.paste(frame, (x * 128, y * 128))
    args.output.mkdir(parents=True, exist_ok=True)
    frames[0].save(args.output / "gold-coin.png", optimize=True)
    atlas.save(args.output / "gold-coins.png", optimize=True)
    manifest = {
        "source": {
            "title": "Toon FX", "version": "1.52",
            "creator": "Kenneth Foldal Moe (Archanor VFX)",
            "url": "https://assetstore.unity.com/packages/vfx/particles/toon-fx-25601",
            "license": "Standard Unity Asset Store EULA",
            "license_url": "https://unity.com/legal/as-terms",
            "local_path": str(args.source).replace("\\", "/"),
            "sha256": source_hash,
            "dimensions": [1024, 1024],
            "status": "Previously acquired local package; inspected and converted",
        },
        "processing": {
            "cell_crop": [48, 48, 464, 464],
            "gold_luminance_stops": GOLD_STOPS,
            "resampling": "Pillow Lanczos with original alpha",
            "unity_code_or_prefabs_imported": False,
        },
        "outputs": {
            name: {"size": list(Image.open(args.output / name).size),
                   "bytes": (args.output / name).stat().st_size,
                   "sha256": digest(args.output / name)}
            for name in ("gold-coin.png", "gold-coins.png")
        },
        "atlas": {"columns": 2, "rows": 2, "cell_size": [128, 128],
                  "angles": ["front", "edge", "flat", "tilted"],
                  "animation": "Four authored views, not a sequential spin flipbook"},
    }
    (args.output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    review = Image.new("RGB", (840, 360), "#fbf7ed")
    drawing = ImageDraw.Draw(review)
    drawing.text((20, 12), "Toon FX gold adaptation: front / edge / flat / tilted", fill="#3f3527")
    for index, frame in enumerate(frames):
        review.paste(frame, (24 + index * 180, 42), frame)
    drawing.text((20, 202), "HUD readability: 24 / 32 / 40 / 48 pixels", fill="#3f3527")
    for index, edge in enumerate((24, 32, 40, 48)):
        small = frames[0].resize((edge, edge), Image.Resampling.LANCZOS)
        review.paste(small, (24 + index * 104, 236), small)
        drawing.text((24 + index * 104, 295), str(edge), fill="#3f3527")
    drawing.rectangle((480, 198, 820, 340), fill="#233b43")
    for index, frame in enumerate(frames):
        small = frame.resize((64, 64), Image.Resampling.LANCZOS)
        review.paste(small, (492 + index * 80, 235), small)
    review.save(args.output / "review-contact.png", optimize=True)
    print(json.dumps(manifest["outputs"], indent=2))


if __name__ == "__main__":
    main()
