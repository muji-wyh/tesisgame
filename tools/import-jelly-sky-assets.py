"""Prepare the inspected Kenney daytime panorama for the shared Jelly backdrop."""

import argparse
import hashlib
import io
import json
from pathlib import Path

from PIL import Image, __version__ as PILLOW_VERSION


ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "docs/assets/jelly-sky.json"
OUTPUT = "assets/images/jelly-match/sky/day.png"
LICENSE_PATH = "assets/images/jelly-match/sky/LICENSE-CC0.txt"
DEFAULT_SOURCE = Path("Q:/uwok/Kenney Game Assets All-in-1 3.7.0")
PACK = "2D assets/Skyboxes"
SOURCE_IMAGE = "Skyboxes/skybox-day.png"
SOURCE_SIZE = [4096, 2048]
SOURCE_BYTES = 1051605
OUTPUT_SIZE = [2048, 1024]
SOURCE_SHA256 = "b7d98fe95157e74b3899a1dd468a1e478005bcd1f668b29b5b42a48cb5358fa2"
LICENSE_SHA256 = "bba7de4552f4a86589fbef2d694c02609643c8d4680e9dbe00407b3474b4a993"
PIXEL_SHA256 = "a35b692e9dd4ceac5758c05d8d14377dbfe74c728b69a012eadb4715754d534d"
PROCESSING = {
    "color_conversion": "Pillow Image.convert('RGB'); no palette grading or recoloring",
    "resize": "Pillow Image.resize((2048, 1024), Image.Resampling.LANCZOS)",
    "encoding": "PNG RGB with optimize=True",
    "crop": "None; the entire 2:1 equirectangular panorama is preserved",
    "other_changes": "No painted additions, alpha extraction, or source-preview content",
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def inspect_png(data):
    with Image.open(io.BytesIO(data)) as image:
        if image.format != "PNG":
            raise ValueError("The selected sky image is not a PNG")
        image.load()
        return list(image.size), image.mode, digest(image.tobytes())


def read_source(source_root):
    pack = source_root / PACK
    source_data = (pack / SOURCE_IMAGE).read_bytes()
    license_data = (pack / "License.txt").read_bytes()
    if digest(source_data) != SOURCE_SHA256 or len(source_data) != SOURCE_BYTES:
        raise ValueError("The daytime panorama differs from the visually inspected Kenney source")
    if digest(license_data) != LICENSE_SHA256:
        raise ValueError("The supplied Skyboxes license differs from the inspected original")
    dimensions, mode, _ = inspect_png(source_data)
    if dimensions != SOURCE_SIZE or mode != "P":
        raise ValueError("Expected the original 4096 x 2048 paletted daytime panorama")
    return source_data, license_data


def convert_source(source_data):
    with Image.open(io.BytesIO(source_data)) as original:
        image = original.convert("RGB").resize(tuple(OUTPUT_SIZE), Image.Resampling.LANCZOS)
        if digest(image.tobytes()) != PIXEL_SHA256:
            raise ValueError("The converted sky pixels differ from the reviewed Lanczos conversion")
        output = io.BytesIO()
        image.save(output, format="PNG", optimize=True)
        return output.getvalue()


def verify(source_root=None):
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    source = manifest["source"]
    if (source["title"] != "Skyboxes (1.0)" or source["creator"] != "Kenney"
            or source["pack_path"] != PACK):
        raise ValueError("Unexpected sky source identity")
    if source["license"] != "CC0 1.0" or source["license_file"] != LICENSE_PATH:
        raise ValueError("Unexpected sky license record")
    license_data = (ROOT / LICENSE_PATH).read_bytes()
    if (digest(license_data) != LICENSE_SHA256
            or source["license_sha256"] != LICENSE_SHA256
            or source["license_source_sha256"] != LICENSE_SHA256):
        raise ValueError("The copied Skyboxes license differs from the original")
    license_text = license_data.decode("utf-8-sig")
    if "Created/distributed by Kenney" not in license_text or "Creative Commons Zero, CC0" not in license_text:
        raise ValueError("The supplied license must identify Kenney and CC0")
    records = manifest["images"]
    if len(records) != 1 or records[0]["id"] != "day":
        raise ValueError("The sky manifest must contain only the reviewed daytime panorama")
    record = records[0]
    if (record["path"] != OUTPUT or record["source"] != SOURCE_IMAGE
            or record["source_sha256"] != SOURCE_SHA256
            or record["source_bytes"] != SOURCE_BYTES
            or record["source_size"] != SOURCE_SIZE or record["source_mode"] != "P"
            or record["processing"] != PROCESSING):
        raise ValueError("Unexpected sky source mapping or conversion provenance")
    data = (ROOT / OUTPUT).read_bytes()
    dimensions, mode, pixel_hash = inspect_png(data)
    if (dimensions != OUTPUT_SIZE or record["size"] != OUTPUT_SIZE
            or mode != "RGB" or record["mode"] != "RGB"
            or pixel_hash != PIXEL_SHA256 or record["pixel_sha256"] != PIXEL_SHA256):
        raise ValueError("The runtime sky differs from the reviewed 2048 x 1024 RGB conversion")
    if digest(data) != record["sha256"] or len(data) != record["bytes"]:
        raise ValueError("The runtime sky bytes do not match their manifest")
    if source_root is not None:
        source_data, original_license = read_source(source_root)
        converted = convert_source(source_data)
        if inspect_png(converted) != inspect_png(data) or original_license != license_data:
            raise ValueError("Replaying the source conversion did not reproduce the integrated material")
    suffix = "; original source and conversion replay checked" if source_root is not None else ""
    print(f"Jelly sky verified: 2048 x 1024 RGB panorama, pinned source/pixel hashes and original Kenney CC0 license{suffix}.")


def prepare(source_root):
    source_data, license_data = read_source(source_root)
    converted = convert_source(source_data)
    destination = ROOT / OUTPUT
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(converted)
    (ROOT / LICENSE_PATH).write_bytes(license_data)
    manifest = {
        "version": 1,
        "imported_on": "2026-10-14",
        "source": {
            "title": "Skyboxes (1.0)",
            "creator": "Kenney",
            "creator_page": "https://kenney.nl/",
            "collection": "Kenney Game Assets All-in-1 3.7.0",
            "supplied_source_root": source_root.as_posix(),
            "pack_path": PACK,
            "acquisition": "User-supplied, already acquired local library; no download or purchase performed",
            "license": "CC0 1.0",
            "license_page": "https://creativecommons.org/publicdomain/zero/1.0/",
            "license_original": "License.txt",
            "license_file": LICENSE_PATH,
            "license_source_sha256": LICENSE_SHA256,
            "license_sha256": LICENSE_SHA256,
            "attribution": "Kenney credit is welcomed but not required by the supplied CC0 license",
            "status": "Original daytime panorama inspected and converted into the repository; runtime integration and review evidence are documented in jelly-sky.md",
            "animations": "Static equirectangular PNG panoramas with baked clouds and sun; no source animation clips, sunlight simulation, or day/night engine system",
        },
        "images": [{
            "id": "day",
            "path": OUTPUT,
            "source": SOURCE_IMAGE,
            "source_sha256": SOURCE_SHA256,
            "source_bytes": len(source_data),
            "source_size": SOURCE_SIZE,
            "source_mode": "P",
            "sha256": digest(converted),
            "pixel_sha256": PIXEL_SHA256,
            "bytes": len(converted),
            "size": OUTPUT_SIZE,
            "mode": "RGB",
            "processing": PROCESSING,
            "conversion_tool": f"Python with Pillow {PILLOW_VERSION}",
        }],
        "review": {
            "direction": "Soft daytime sky, restrained sunlight and a quiet low garden horizon around the Jelly playfield",
            "source_contact_sheet": "build/jelly-environment-20261014-source-scout.png",
            "source_detail_sheet": "build/jelly-environment-20261014-sky-detail.png",
            "inspection": "All five original sky panoramas, the daytime source crop, existing garden layers, and Nature Kit source preview inspected; only the daytime panorama selected",
            "status": "Source selection, license, original hashes and converted pixels verified; runtime framing, motion, readability and browser review are documented separately in jelly-sky.md",
            "alternatives": "Morning, night, alien, space, Nature Kit and particle-light assets remain source review only and are not imported",
            "preview_note": "Sample (Day).png and Sample (Night).png are watermarked source previews; neither is included in the runtime image",
        },
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    verify(source_root)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path,
                        help="Root of the supplied Kenney library; with --check, also replay the original conversion")
    parser.add_argument("--check", action="store_true",
                        help="Check repository pixels, metadata, pinned source identity and license without writing files")
    options = parser.parse_args()
    if options.check:
        verify(options.source.resolve() if options.source is not None else None)
    else:
        prepare((options.source or DEFAULT_SOURCE).resolve())


if __name__ == "__main__":
    main()
