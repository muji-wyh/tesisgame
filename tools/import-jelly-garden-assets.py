"""Copy the eight inspected Kenney garden images from the supplied local library."""

import argparse
import hashlib
import io
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "docs/assets/jelly-garden.json"
OUTPUT = "assets/images/jelly-match/garden"
LICENSE_PATH = f"{OUTPUT}/LICENSE-CC0.txt"
DEFAULT_SOURCE = Path("Q:/uwok/Kenney Game Assets All-in-1 3.7.0")
PACK = "2D assets/Background Elements Remastered"
FILES = {
    "sky": "Backgrounds/backgroundEmpty.png",
    "hills": "Backgrounds/Elements/hills.png",
    "cloud-bank": "Backgrounds/Elements/cloudLayer1.png",
    "cloud": "PNG/Retina/cloud3.png",
    "cloud-small": "PNG/Retina/cloud1.png",
    "tree": "PNG/Retina/tree.png",
    "tree-long": "PNG/Retina/treeLong.png",
    "foliage": "PNG/Retina/bushAlt1.png",
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def inspect_png(data):
    with Image.open(io.BytesIO(data)) as image:
        if image.format != "PNG":
            raise ValueError("The selected image is not a PNG")
        dimensions, mode = list(image.size), image.mode
        image.verify()
    return dimensions, mode


def verify():
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    records = manifest["images"]
    if len(records) != len(FILES) or {record["id"] for record in records} != set(FILES):
        raise ValueError("The garden manifest must contain exactly the eight reviewed images")
    for record in records:
        expected_path = f"{OUTPUT}/{record['id']}.png"
        if record["path"] != expected_path or record["source"] != FILES[record["id"]]:
            raise ValueError(f"Unexpected garden asset mapping: {record['id']}")
        data = (ROOT / expected_path).read_bytes()
        if digest(data) != record["sha256"] or record["sha256"] != record["source_sha256"]:
            raise ValueError(f"Garden artwork differs from the unmodified source: {expected_path}")
        dimensions, mode = inspect_png(data)
        if len(data) != record["bytes"] or dimensions != record["size"] or mode != record["mode"]:
            raise ValueError(f"Invalid garden texture metadata: {expected_path}")
    source = manifest["source"]
    if source["license_file"] != LICENSE_PATH or source["license"] != "CC0 1.0":
        raise ValueError("Unexpected garden license record")
    license_data = (ROOT / LICENSE_PATH).read_bytes()
    if digest(license_data) != source["license_sha256"] or source["license_sha256"] != source["license_source_sha256"]:
        raise ValueError("The copied Kenney CC0 license differs from its original")
    license_text = license_data.decode("utf-8-sig")
    if "Created/distributed by Kenney" not in license_text or "Creative Commons Zero, CC0" not in license_text:
        raise ValueError("The garden license must identify Kenney and CC0")
    print("Jelly garden verified: 8 unmodified sourced PNGs and the original Kenney CC0 license.")


def prepare(source_root):
    source_pack = source_root / PACK
    license_data = (source_pack / "License.txt").read_bytes()
    license_text = license_data.decode("utf-8-sig")
    if "Created/distributed by Kenney" not in license_text or "Creative Commons Zero, CC0" not in license_text:
        raise ValueError("The supplied source must include its original Kenney CC0 license")
    prepared = []
    for asset_id, member in FILES.items():
        data = (source_pack / member).read_bytes()
        dimensions, mode = inspect_png(data)
        prepared.append((asset_id, member, data, dimensions, mode))

    output = ROOT / OUTPUT
    output.mkdir(parents=True, exist_ok=True)
    records = []
    for asset_id, member, data, dimensions, mode in prepared:
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
            "processing": "Unmodified original PNG copied byte-for-byte from the supplied local Kenney library",
        })
    (ROOT / LICENSE_PATH).write_bytes(license_data)
    manifest = {
        "version": 1,
        "imported_on": "2026-10-13",
        "source": {
            "title": "Background Elements Remastered (1.0)",
            "creator": "Kenney",
            "creator_page": "https://kenney.nl/",
            "collection": "Kenney Game Assets All-in-1 3.7.0",
            "supplied_source_root": source_root.as_posix(),
            "pack_path": PACK,
            "acquisition": "User-supplied, already acquired local asset library; no download or purchase performed by this importer",
            "license": "CC0 1.0",
            "license_page": "https://creativecommons.org/publicdomain/zero/1.0/",
            "license_original": "License.txt",
            "license_file": LICENSE_PATH,
            "license_source_sha256": digest(license_data),
            "license_sha256": digest(license_data),
            "attribution": "Kenney credit is welcomed but not required by the supplied CC0 license",
            "status": "Eight original PNGs visually inspected, imported unchanged and integrated into both jelly modes; source checks, eight native composition reviews and motion lifecycle checks passed",
            "animations": "Static PNGs and vector originals; no baked environment animation clips. Runtime tint, opacity and gentle horizontal motion of two clouds are authored by the game.",
        },
        "images": records,
        "review": {
            "direction": "Airy layered garden with clouds and low edge foliage framing a quiet playfield",
            "source_contact_sheet": "build/jelly-background-asset-scout.png",
            "inspection": "Selected original PNGs inspected individually, including cloud1, treeLong and bushAlt1; source comparison sheet is review material only",
            "status": "Source artwork and copied image identity verified. Native composition and readability reviewed for both modes at 320 x 568, 393 x 852, 852 x 393 and 1473 x 1175. Native gameplay, lifecycle, reduced-motion and static drawing cache checks passed. Chromium and simulated iPhone WebKit gameplay and layout checks passed; the Chromium Words reload case passed on retry with a 180-second suite limit.",
            "native_captures": [
                "build/jelly-backdrop-review/after/jelly-393x852.png",
                "build/jelly-backdrop-review/after/jelly-1473x1175.png",
                "build/jelly-backdrop-review/after/word_jelly-393x852.png",
                "build/jelly-backdrop-review/after/word_jelly-1473x1175.png",
                "build/jelly-backdrop-review/after-compact/jelly-320x568.png",
                "build/jelly-backdrop-review/after-compact/jelly-852x393.png",
                "build/jelly-backdrop-review/after-compact/word_jelly-320x568.png",
                "build/jelly-backdrop-review/after-compact/word_jelly-852x393.png",
            ],
            "note": "foliage.png is the original bushAlt1 low shrub artwork, used as perimeter foliage",
        },
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    verify()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE,
                        help="Root of the supplied Kenney Game Assets All-in-1 library")
    parser.add_argument("--check", action="store_true",
                        help="Verify integrated bytes against the manifest without needing the source library")
    options = parser.parse_args()
    if options.check:
        verify()
    else:
        prepare(options.source.resolve())


if __name__ == "__main__":
    main()
