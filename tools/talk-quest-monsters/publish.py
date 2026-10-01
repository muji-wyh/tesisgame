"""Publish validated GLBs, source thumbnails, and their reproducible provenance."""
import argparse
import hashlib
import json
from pathlib import Path
import struct

from PIL import Image


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_glb(path):
    data = path.read_bytes()
    magic, version, total = struct.unpack_from("<4sII", data)
    if magic != b"glTF" or version != 2 or total != len(data):
        raise ValueError("Invalid GLB container: " + str(path))
    length, kind = struct.unpack_from("<I4s", data, 12)
    if kind != b"JSON":
        raise ValueError("Missing GLB document")
    return json.loads(data[20:20 + length])


def prepare_thumbnail(path):
    with Image.open(path) as source:
        image = source.convert("RGBA")
    source_size = image.size
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("Reviewed source thumbnail has no visible content: " + str(path))
    image = image.crop(bounds)
    image.thumbnail((288, 288), Image.Resampling.LANCZOS)
    # Trim any fully transparent edge left by downsampling before adding an
    # exact output-space margin. No nonzero source-alpha region is cropped
    # before fitting; no background color or source geometry is removed.
    image = image.crop(image.getchannel("A").getbbox())
    padded = Image.new("RGBA", (image.width + 32, image.height + 32), (0, 0, 0, 0))
    padded.paste(image, (16, 16))
    return padded, {"source_dimensions": list(source_size), "source_alpha_bounds": list(bounds),
                    "content_dimensions": list(image.size), "margin_px": 16,
                    "output_dimensions": list(padded.size)}


def publish(root, source_root):
    asset_root = root / "assets/talk_quest/monsters"
    report_path = root / "build/talk-quest-monsters/conversion-report.json"
    report = json.loads(report_path.read_text(encoding="utf-8"))
    selection_path = source_root / "processing/monster-roster-selection.json"
    selection = json.loads(selection_path.read_text(encoding="utf-8"))
    handoff = json.loads((source_root / "processing/monster-roster-creatures.json").read_text(encoding="utf-8"))
    sources = json.loads((source_root / "asset-review/sources.monster-roster.json").read_text(encoding="utf-8"))["sources"][0]
    selected = {item["id"]: item for item in selection["creatures"]}
    if report["errors"] or len(report["creatures"]) != 14 or {item["id"] for item in report["creatures"]} != set(selected):
        raise ValueError("All fourteen approved creatures must be exported successfully")
    entries, thumbnails = [], []
    for item in report["creatures"]:
        path = asset_root / item["file"]
        if digest(path) != item["sha256"]:
            raise ValueError("GLB differs from conversion report: " + item["id"])
        glb = read_glb(path)
        animations = {animation["name"]: animation for animation in glb.get("animations", [])}
        if not glb.get("skins") or set(animations) != set(item["animations"]) or not 1 <= len(animations) <= 4 or "Idle" not in animations:
            raise ValueError("Exported rig/animations do not match inspected source: " + item["id"])
        for animation in animations.values():
            if not animation["channels"] or any(not glb["accessors"][sampler["input"]]["count"] >= 2 for sampler in animation["samplers"]):
                raise ValueError("Empty exported source animation")
        for mesh in glb["meshes"]:
            for primitive in mesh["primitives"]:
                if not {"JOINTS_0", "WEIGHTS_0"}.issubset(primitive["attributes"]):
                    raise ValueError("A mesh lost its skin weights")
        expected_colors = {m["name"]: m["source_linear_diffuse"] for m in item["materials"]}
        for material in glb["materials"]:
            actual = material["pbrMetallicRoughness"]["baseColorFactor"][:3]
            if any(abs(a - b) > 1e-6 for a, b in zip(actual, expected_colors[material["name"]])):
                raise ValueError("Exported base color differs from the FBX source")
        thumbnail = next(c for c in handoff["creatures"] if c["id"] == item["id"])["preview"]
        source_image = source_root / "asset-review" / thumbnail["src"]
        if digest(source_image) != thumbnail["sha256"]:
            raise ValueError("Reviewed source thumbnail changed")
        image, thumbnail_processing = prepare_thumbnail(source_image)
        thumbnail_path = asset_root / (item["id"] + ".png")
        image.save(thumbnail_path, optimize=True)
        entries.append({key: value for key, value in item.items() if key != "inspected_source_actions"})
        entries[-1].update({"resource": "res://assets/talk_quest/monsters/" + item["file"],
                            "thumbnail": "res://assets/talk_quest/monsters/" + thumbnail_path.name,
                            "thumbnail_sha256": digest(thumbnail_path),
                            "thumbnail_processing": thumbnail_processing,
                            "design_family": selected[item["id"]]["designFamily"]})
        thumbnails.append({"id": item["id"], "source": thumbnail["src"],
                           "source_sha256": thumbnail["sha256"], "file": thumbnail_path.name,
                           "sha256": digest(thumbnail_path), "bytes": thumbnail_path.stat().st_size,
                           **thumbnail_processing})
    manifest = {"version": 1, "source_product_id": "380750", "package_sha256": selection["package_sha256"],
                "selection_sha256": digest(selection_path), "normalized_max_extent": 2.0,
                "coordinates": "Godot Y-up, source front +Z, source rest floor y=0",
                "total_glb_bytes": sum(item["bytes"] for item in entries), "creatures": entries}
    (asset_root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    evidence = {"version": 1, "source": {"url": sources["url"], "license": "Standard Unity Asset Store EULA",
                  "listing": sources["listing_verification"], "archive": sources["provenance"]["package_metadata"],
                  "listing_header_comparison": sources["provenance"]["listing_header_comparison"]},
                "package_sha256": selection["package_sha256"], "selection_sha256": digest(selection_path),
                "converter": report["blender"], "manifest_sha256": digest(asset_root / "manifest.json"),
                "conversion": {"source_topology": "Preserved; GLB splits vertices at material and normal boundaries.",
                    "skin_weights": "Four strongest weights per vertex, normalized by the standard glTF exporter for Web compatibility.",
                    "materials": "Exact source FBX linear diffuse values; neutral roughness 0.72, metallic 0; no textures supplied.",
                    "source_animation_selection": "Seven evaluated skinned-mesh samples per candidate; reject nonmoving or unbounded takes. At most four semantic clips exported.",
                    "thumbnails": "Reviewed source previews cropped to nonzero alpha, fitted within 288 by 288 pixels, and padded by 16 transparent pixels on each edge. Source colors and complete silhouettes are retained.",
                    "runtime_authored_motion": "Hit squash/recoil, friendly shrinking retreat, celebration hops, cooperative sleep/breathing/repair glow/wake.",
                    "limitation": "Source action names and sampled deformation are evidence; target-game visual/runtime testing is separate."},
                "thumbnails": thumbnails, "creatures": report["creatures"]}
    evidence_path = root / "docs/assets/talk-quest-monsters.json"
    evidence_path.write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"creatures": len(entries), "glb_bytes": manifest["total_glb_bytes"],
                      "manifest": str(asset_root / "manifest.json"), "evidence": str(evidence_path)}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, required=True)
    args = parser.parse_args()
    publish(Path(__file__).resolve().parents[2], args.source_root)
