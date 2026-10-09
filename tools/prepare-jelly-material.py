"""Derive distance/material maps from the acquired Jelly Squash illustrations.

The PNG alpha channel is signed distance data, not display opacity. Runtime
shaders reconstruct the original silhouette while joining textured surfaces.
Only Pillow is required; the Euclidean distance transform is implemented here.
"""

import argparse
import hashlib
import json
import math
from pathlib import Path

from PIL import Image, __version__ as pillow_version


ROOT = Path(__file__).resolve().parent.parent
SOURCE_MANIFEST = ROOT / "docs/assets/jelly-match.json"
MANIFEST = ROOT / "docs/assets/jelly-material.json"
COLORS = ("coral", "mint", "sky", "lilac")
SIZE = (320, 320)
DISTANCE_RANGE = 128.0
ALPHA_THRESHOLD = 128
INFINITY = float("inf")


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def relative(path):
    return path.relative_to(ROOT).as_posix()


def import_settings(path):
    source = "res://" + relative(path)
    path_hash = hashlib.md5(source.encode("utf-8")).hexdigest()
    # Letter-only resource identifiers are valid and bounded below 2^63.
    uid = "".join(chr(ord("a") + value % 26) for value in hashlib.sha256(source.encode("utf-8")).digest()[:12])
    imported = f"res://.godot/imported/{path.name}-{path_hash}.ctex"
    return f'''[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://{uid}"
path="{imported}"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{source}"
dest_files=["{imported}"]

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
process/fix_alpha_border=false
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
'''


def distance_line(values):
    """Exact squared Euclidean lower envelope, with nearest feature indices."""
    candidates = [index for index, value in enumerate(values) if value < INFINITY]
    if not candidates:
        return [INFINITY] * len(values), [-1] * len(values)
    sites = [candidates[0]]
    boundaries = [-INFINITY, INFINITY]
    for position in candidates[1:]:
        while True:
            previous = sites[-1]
            crossing = ((values[position] + position * position)
                        - (values[previous] + previous * previous)) / (2 * (position - previous))
            if crossing > boundaries[-2]:
                break
            sites.pop()
            boundaries.pop()
        boundaries[-1] = crossing
        boundaries.append(INFINITY)
        sites.append(position)
    distances, indices = [], []
    site = 0
    for position in range(len(values)):
        # Equal-distance ties choose the earlier site in each axis.
        while boundaries[site + 1] < position:
            site += 1
        nearest = sites[site]
        distances.append((position - nearest) ** 2 + values[nearest])
        indices.append(nearest)
    return distances, indices


def distance_field(mask, width, height):
    """Return exact squared distances and nearest feature pixel coordinates."""
    rows, row_indices = [], []
    for y in range(height):
        values = [0.0 if mask[y * width + x] else INFINITY for x in range(width)]
        distances, indices = distance_line(values)
        rows.append(distances)
        row_indices.append(indices)
    distances = [0.0] * (width * height)
    nearest = [(0, 0)] * (width * height)
    for x in range(width):
        column, indices = distance_line([rows[y][x] for y in range(height)])
        for y in range(height):
            feature_y = indices[y]
            if feature_y < 0:
                raise ValueError("The source must contain both interior and exterior pixels")
            distances[y * width + x] = column[y]
            nearest[y * width + x] = (row_indices[feature_y][x], feature_y)
    return distances, nearest


def prepare(image):
    if image.mode != "RGBA" or image.size != SIZE:
        raise ValueError("Source surfaces must retain their original 320 x 320 RGBA coordinates")
    pixels = list(image.get_flattened_data())
    inside = [pixel[3] >= ALPHA_THRESHOLD for pixel in pixels]
    outside_distance, nearest = distance_field(inside, *SIZE)
    inside_distance, _ = distance_field([not value for value in inside], *SIZE)
    output = []
    for index, pixel in enumerate(pixels):
        if inside[index]:
            color = pixel[:3]
            signed_distance = -math.sqrt(inside_distance[index])
        else:
            source_x, source_y = nearest[index]
            color = pixels[source_y * SIZE[0] + source_x][:3]
            signed_distance = math.sqrt(outside_distance[index])
        alpha = round(255 * min(1.0, max(0.0, 0.5 + signed_distance / DISTANCE_RANGE)))
        output.append(color + (alpha,))
    result = Image.new("RGBA", SIZE)
    result.putdata(output)
    return result


def source_records():
    manifest = json.loads(SOURCE_MANIFEST.read_text(encoding="utf-8"))
    records = {entry["path"]: entry for entry in manifest["images"]}
    selected = []
    for color in COLORS:
        path = ROOT / f"assets/images/jelly-match/gel-{color}.png"
        entry = records[relative(path)]
        if entry["kind"] != "gel_surface" or sha256(path) != entry["sha256"]:
            raise ValueError(f"Source differs from its acquired-art provenance: {relative(path)}")
        selected.append((color, path, entry))
    return manifest, selected


def build():
    source_manifest, selected = source_records()
    records = []
    for color, source, entry in selected:
        destination = source.with_name(f"gel-{color}-material.png")
        image = prepare(Image.open(source))
        image.save(destination, optimize=True)
        sidecar = destination.with_suffix(".png.import")
        sidecar.write_text(import_settings(destination), encoding="utf-8")
        records.append({
            "path": relative(destination), "sha256": sha256(destination),
            "source": relative(source), "source_sha256": entry["sha256"],
            "original_source": entry["source"], "original_source_sha256": entry["source_sha256"],
            "size": list(SIZE), "mode": "RGBA", "alpha_is_opacity": False,
            "import": relative(sidecar),
        })
    provenance = {
        "version": 1,
        "source_manifest": relative(SOURCE_MANIFEST),
        "source": source_manifest["image_source"],
        "license": source_manifest["license"],
        "status": "Derived from the integrated acquired artwork; material maps for runtime shader sampling",
        "animation": "No baked animation. Runtime distance-field blending deforms the acquired painted surfaces.",
        "processing": {
            "tool": "tools/prepare-jelly-material.py", "pillow_version": pillow_version,
            "dimensions": list(SIZE), "source_alpha_threshold": ALPHA_THRESHOLD,
            "distance": "Exact two-pass squared Euclidean lower envelope, followed by square root; distances between pixel centers",
            "sign": "Negative inside the original alpha >= 128 silhouette; positive outside",
            "alpha": "round(255 * clamp(0.5 + signed_distance_pixels / 128, 0, 1)); round uses nearest integer with ties to even",
            "distance_range_pixels": DISTANCE_RANGE,
            "rgb": "Original RGB retained inside the silhouette; exterior RGB copied from the nearest interior pixel",
            "tie_break": "Equal-distance nearest pixels prefer smaller y, then smaller x",
            "runtime_decode": "signed_distance_pixels = (sample.a - 0.5) * 128; alpha is data and must not be used as display opacity",
            "source_preservation": "The original gel PNGs are read-only inputs and are not modified",
            "godot_import": "Lossless; no mipmaps, alpha border repair or premultiplication. Alpha is distance data, including zero inside the painted body.",
        },
        "images": records,
    }
    MANIFEST.write_text(json.dumps(provenance, indent=2) + "\n", encoding="utf-8")
    verify()


def verify():
    _, selected = source_records()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    records = {entry["source"]: entry for entry in manifest["images"]}
    if len(records) != len(COLORS):
        raise ValueError("The material manifest must contain exactly four acquired color variants")
    for _, source, original in selected:
        record = records[relative(source)]
        path = ROOT / record["path"]
        if record["source_sha256"] != original["sha256"] or sha256(path) != record["sha256"]:
            raise ValueError(f"Material/source differs from its provenance: {relative(path)}")
        actual = Image.open(path)
        if actual.mode != "RGBA" or actual.size != SIZE or actual.tobytes() != prepare(Image.open(source)).tobytes():
            raise ValueError(f"Material does not reproduce from the acquired source: {relative(path)}")
        settings = (ROOT / record["import"]).read_text(encoding="utf-8")
        for expected in ("compress/mode=0", "mipmaps/generate=false", "process/fix_alpha_border=false", "process/premult_alpha=false"):
            if expected not in settings.splitlines():
                raise ValueError(f"Material import must retain raw distance and RGB: {record['import']}: {expected}")
    print("Verified four Jelly material maps, source provenance, exact distance encoding and extended painted RGB.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify hashes and exact reconstruction without writing files")
    arguments = parser.parse_args()
    verify() if arguments.check else build()
