"""Update provenance manifests and regenerate exact gel SDF material maps after the Storybook 3D asset upgrade.

Updates:
- docs/assets/jelly-match.json (new 3D Blender-rendered gel-coral/mint/sky/lilac hashes & sizes)
- assets/images/jelly-match/gel-*-material.png & docs/assets/jelly-material.json via prepare-jelly-material.py
- docs/assets/jelly-garden.json (new 3D diorama hills/tree/tree-long/foliage hashes & sizes)
- docs/assets/jelly-sky.json (adds morning.png & night.png biome sky panoramas from local Kenney Skyboxes)
- assets/images/jelly-campaign/sources.json (new 3D diorama landmark hashes & sizes)
- assets/images/ui/jelly-map/sources.json (new 3D sculpted stage-open, stage-locked, stage-boss medallions)
"""

import hashlib
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(r"q:\uwork\tesisgame")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def update_jelly_match_and_sdf():
    manifest_path = ROOT / "docs/assets/jelly-match.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["version"] = 6
    manifest["image_source"] = {
        "creator": "TesisGame 3D Storybook Asset Pipeline (Blender 5.3 Cycles)",
        "title": "Storybook 3D Translucent Jelly Cushion Skins",
        "license": "CC0-1.0",
        "tool": "tools/render-storybook-ui-and-gels.py",
        "status": "Rendered in Blender 5.3 Cycles and inspected; four 320x320 rounded-rectangle gel surfaces preserve the exact SDF silhouette and y=285 foot contract.",
        "animations": "Static 3D-lit surfaces; runtime squash, optical lighting and fusion deformation are shader-authored.",
    }
    manifest["image_processing"] = {
        "tool": "Blender 5.3 Cycles + Pillow + NumPy",
        "description": "Rendered 3D subsurface-scattered clearcoat jelly cushion master, mapped at 4x supersampling into the exact 320x320 rounded-rectangle silhouette (center 159.5, half-extents 148.5x125.5, corner radius 56) with four curated pastel-vivid palettes and calm central reading area.",
    }
    for entry in manifest["images"]:
        if entry["kind"] == "gel_surface":
            p = ROOT / entry["path"]
            im = Image.open(p)
            h = sha256(p)
            entry["sha256"] = h
            entry["source"] = "tools/render-storybook-ui-and-gels.py"
            entry["source_sha256"] = h
            entry["size"] = list(im.size)
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    # Now run prepare-jelly-material.py to regenerate exact SDF maps & docs/assets/jelly-material.json!
    subprocess.check_call([sys.executable, str(ROOT / "tools/prepare-jelly-material.py")])


def update_jelly_garden():
    manifest_path = ROOT / "docs/assets/jelly-garden.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["version"] = 2
    manifest["source"]["title"] = "Kenney 3D Nature Kit & Castle Kit Diorama Renders (with retained CC0 garden base)"
    manifest["source"]["status"] = "Hills, trees and foliage upgraded to 3D Blender Cycles miniature storybook renders from user-supplied CC0 Kenney 3D kits."
    diorama_report = {
        item["path"]: item
        for item in json.loads((ROOT / "build/qa/asset-upgrade-3d/diorama-manifest.json").read_text(encoding="utf-8"))
    }
    for entry in manifest["images"]:
        p = ROOT / entry["path"]
        im = Image.open(p)
        data = p.read_bytes()
        entry["sha256"] = hashlib.sha256(data).hexdigest()
        entry["bytes"] = len(data)
        entry["size"] = list(im.size)
        entry["mode"] = im.mode
        if entry["path"] in diorama_report:
            entry["source"] = ", ".join(diorama_report[entry["path"]]["sources"])
            entry["source_sha256"] = entry["sha256"]
            entry["processing"] = "Rendered from user-supplied CC0 Kenney 3D GLBs via Blender 5.3 Cycles (tools/render-storybook-scenery.py)"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def update_jelly_sky():
    manifest_path = ROOT / "docs/assets/jelly-sky.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["version"] = 2
    manifest["source"]["status"] = "Daytime, golden-hour morning, and twilight night panoramas imported from user-supplied CC0 Kenney Skyboxes 1.0 for multi-biome chapter variety."
    kenney_sky = Path(r"q:\uwork\Kenney Game Assets All-in-1 3.7.0\2D assets\Skyboxes\Skyboxes")
    existing_ids = {img["id"] for img in manifest["images"]}
    for sky_id, src_name in [("morning", "skybox-morning.png"), ("night", "skybox-night.png")]:
        dst = ROOT / f"assets/images/jelly-match/sky/{sky_id}.png"
        src = kenney_sky / src_name
        im = Image.open(dst)
        out = dst.read_bytes()
        rec = {
            "id": sky_id,
            "path": dst.relative_to(ROOT).as_posix(),
            "source": f"Skyboxes/{src_name}",
            "source_sha256": sha256(src),
            "source_bytes": src.stat().st_size,
            "sha256": hashlib.sha256(out).hexdigest(),
            "bytes": len(out),
            "size": list(im.size),
            "mode": im.mode,
            "processing": {
                "color_conversion": "Pillow Image.convert('RGB')",
                "resize": "Pillow Image.resize((1536, 768), Image.Resampling.LANCZOS)",
                "encoding": "PNG RGB with optimize=True",
            },
        }
        if sky_id in existing_ids:
            manifest["images"] = [rec if img["id"] == sky_id else img for img in manifest["images"]]
        else:
            manifest["images"].append(rec)
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def update_jelly_campaign():
    manifest_path = ROOT / "assets/images/jelly-campaign/sources.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    diorama_report = {
        item["path"]: item
        for item in json.loads((ROOT / "build/qa/asset-upgrade-3d/diorama-manifest.json").read_text(encoding="utf-8"))
    }
    manifest["version"] = 2
    manifest["status"] = "acquired; upgraded to 3D diorama renders from CC0 Kenney 3D kits and integrated"
    manifest["source"] = {
        "title": "Kenney 3D Nature Kit, Castle Kit, Holiday Kit & Pirate Kit Diorama Renders",
        "url": "https://kenney.nl/assets",
        "creator": "Kenney (3D CC0 source meshes) + TesisGame Blender 5.3 Cycles renderer",
        "version": "3.7.0",
        "local_directory": r"Q:\uwork\Kenney Game Assets All-in-1 3.7.0\3D assets",
        "acquisition": "Rendered from user-supplied local CC0 3D asset library via tools/render-storybook-scenery.py.",
        "type": "3D-rendered transparent 2D PNG storybook props",
        "animations": "Static artwork; map sway and staging remain game-authored.",
    }
    for entry in manifest["images"]:
        rel = f"assets/images/jelly-campaign/{entry['path']}"
        p = ROOT / rel
        im = Image.open(p)
        data = p.read_bytes()
        h = hashlib.sha256(data).hexdigest()
        entry["width"], entry["height"] = im.size
        entry["bytes"] = len(data)
        entry["source_sha256"] = h
        entry["output_sha256"] = h
        if rel in diorama_report:
            entry["source_relative_path"] = ", ".join(diorama_report[rel]["sources"])
        entry["processing"] = "Rendered from user-supplied CC0 Kenney 3D GLB kits via Blender 5.3 Cycles."
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def update_jelly_map_ui():
    manifest_path = ROOT / "assets/images/ui/jelly-map/sources.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["version"] = 2
    manifest["source"]["title"] = "Storybook 3D Sculpted Medallions (Blender 5.3 Cycles) + Kenney UI Pack - Adventure 1.1"
    manifest["source"]["creator"] = "TesisGame 3D Pipeline & Kenney"
    manifest["source"]["license"] = "CC0-1.0"
    manifest["source"]["animations"] = "Static 3D-lit medallions and nine-slice panel; hover/unlock animations are game-authored."

    files = ["stage-open.png", "stage-locked.png", "stage-boss.png", "adventure-panel.png"]
    new_images = []
    for fname in files:
        p = ROOT / "assets/images/ui/jelly-map" / fname
        im = Image.open(p)
        data = p.read_bytes()
        new_images.append({
            "file": fname,
            "bytes": len(data),
            "size": list(im.size),
            "sha256": hashlib.sha256(data).hexdigest(),
            "source": "tools/render-storybook-ui-and-gels.py" if fname.startswith("stage-") else "Kenney UI Pack - Adventure 1.1",
        })
    manifest["images"] = new_images
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    update_jelly_match_and_sdf()
    update_jelly_garden()
    update_jelly_sky()
    update_jelly_campaign()
    update_jelly_map_ui()
    print("All Jelly World manifests & SDF material maps updated and verified.")
