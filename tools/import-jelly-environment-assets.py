"""Copy the inspected CC0 woodland artwork from its original source archive."""

import argparse
import hashlib
import io
import json
from pathlib import Path
import zipfile

from PIL import Image


ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "docs/assets/jelly-environment.json"
ARCHIVE_SHA256 = "a4dabc46ca5c16adb8c6fb550c6cd53affc83fb489f6a151feec34f9ff03a448"
LICENSE_PATH = "assets/images/jelly-match/LICENSE-CC0.txt"
FILES = {
    "woodland": "png/BG/BG.png",
    "tree": "png/Object/Tree_2.png",
    "bush": "png/Object/Bush (1).png",
    "mushroom": "png/Object/Mushroom_1.png",
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def verify():
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if len(manifest["images"]) != len(FILES) or {record["id"] for record in manifest["images"]} != set(FILES):
        raise ValueError("The woodland manifest must contain exactly the four reviewed images")
    for record in manifest["images"]:
        path = ROOT / record["path"]
        data = path.read_bytes()
        expected_path = f"assets/images/jelly-match/environment/{record['id']}.png"
        if record["path"] != expected_path or record["source"] != FILES[record["id"]]:
            raise ValueError(f"Unexpected woodland asset mapping: {record['id']}")
        if digest(data) != record["sha256"] or record["sha256"] != record["source_sha256"]:
            raise ValueError(f"Woodland artwork differs from the unmodified source: {path}")
        with Image.open(io.BytesIO(data)) as image:
            if image.format != "PNG" or list(image.size) != record["size"] or image.mode != record["mode"]:
                raise ValueError(f"Invalid woodland texture: {path}")
            image.verify()
    if manifest["source"]["license_file"] != LICENSE_PATH or not (ROOT / LICENSE_PATH).is_file():
        raise ValueError("The shared CC0 license is missing")
    print("Jelly environment verified: 4 unmodified sourced PNGs and the shared CC0 license.")


def prepare(archive_path):
    if digest(archive_path.read_bytes()) != ARCHIVE_SHA256:
        raise ValueError("Unexpected GameArt2D nature source archive")
    output = ROOT / "assets/images/jelly-match/environment"
    output.mkdir(parents=True, exist_ok=True)
    records = []
    with zipfile.ZipFile(archive_path) as archive:
        # Read only the four approved members; do not extract unrelated artwork,
        # vector projects, or archive paths into the working tree.
        for asset_id, member in FILES.items():
            data = archive.read(member)
            with Image.open(io.BytesIO(data)) as image:
                dimensions, mode = list(image.size), image.mode
                if image.format != "PNG":
                    raise ValueError(f"The selected member is not a PNG: {member}")
                image.verify()
            destination = output / f"{asset_id}.png"
            destination.write_bytes(data)
            records.append({
                "id": asset_id,
                "path": destination.relative_to(ROOT).as_posix(),
                "source": member,
                "source_sha256": digest(data),
                "sha256": digest(data),
                "bytes": len(data),
                "size": dimensions,
                "mode": mode,
                "processing": "Unmodified original PNG copied byte-for-byte from the verified archive",
            })
    manifest = {
        "version": 1,
        "acquired_on": "2026-10-09",
        "source": {
            "title": "Free Nature Platformer Tileset",
            "creator": "Zuhria Alfitra (pzUH), GameArt2D",
            "page": "https://www.gameart2d.com/free-platformer-game-tileset.html",
            "creator_page": "https://www.gameart2d.com/about.html",
            "download": "https://www.gameart2d.com/uploads/3/0/9/1/30917885/freetileset.zip",
            "archive_sha256": ARCHIVE_SHA256,
            "license": "CC0 1.0",
            "license_page": "https://www.gameart2d.com/license.html",
            "license_file": LICENSE_PATH,
            "status": "Original source downloaded and images visually inspected; four unchanged PNGs integrated",
            "animations": "Static PNG and vector source artwork; no baked animation clips. Any runtime motion is authored by the game.",
        },
        "images": records,
        "review": {
            "source_contact_sheet": "build/jelly-environment-sources/environment-source-review.png",
            "status": "Source artwork inspected. Runtime layout, readability and motion are verified separately.",
            "alternative": "Kenney Background Elements Remastered was downloaded and inspected but no files from it are integrated.",
        },
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    verify()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path,
                        default=ROOT / "build/jelly-environment-sources/gameart2d-nature.zip")
    parser.add_argument("--check", action="store_true")
    options = parser.parse_args()
    if options.check:
        verify()
    else:
        prepare(options.archive.resolve())


if __name__ == "__main__":
    main()
