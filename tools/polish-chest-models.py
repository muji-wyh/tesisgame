"""Round the acquired CC0 chest edges while retaining original lids, UVs and clips."""

import hashlib
import json
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "assets/chests/catalog-cc0"
OUTPUT = ROOT / "assets/chests/polished-cc0"
BASES = ("kenney-survival", "kenney-platformer", "kenney-mini-dungeon", "kaykit-dungeon")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    record = json.loads((SOURCES / "sources.json").read_text(encoding="utf-8"))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    entries = []
    for family in BASES:
        source = SOURCES / family / "chest.glb"
        acquired = next(item for item in record["files"] if item.get("path") == source.relative_to(ROOT).as_posix())
        expected = acquired.get("output_sha256", acquired.get("sha256"))
        if not expected or digest(source) != expected:
            raise RuntimeError(f"The acquired {family} bytes no longer match their source record.")
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(source))
        meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
        if not meshes:
            raise RuntimeError(f"{family} has no acquired mesh.")
        points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
        width = max(point.x for point in points) - min(point.x for point in points)
        if width <= 0:
            raise RuntimeError(f"{family} has invalid source dimensions.")
        before = sum(len(obj.data.vertices) for obj in meshes)
        for obj in meshes:
            bpy.context.view_layer.objects.active = obj
            bm = bmesh.new()
            bm.from_mesh(obj.data)
            bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=width * 0.000001)
            bm.to_mesh(obj.data)
            bm.free()
            bevel = obj.modifiers.new("Source edge highlights", "BEVEL")
            bevel.width = width * 0.008
            bevel.segments = 2
            bevel.limit_method = "ANGLE"
            bevel.angle_limit = math.radians(35)
            bevel.use_clamp_overlap = True
            bevel.harden_normals = True
            obj.modifiers.move(len(obj.modifiers) - 1, 0)
            bpy.ops.object.modifier_apply(modifier=bevel.name)
            normals = obj.modifiers.new("Weighted source panels", "WEIGHTED_NORMAL")
            normals.keep_sharp = True
            bpy.ops.object.modifier_apply(modifier=normals.name)
        target = OUTPUT / f"{family}.glb"
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.export_scene.gltf(
            filepath=str(target), export_format="GLB", use_selection=True,
            export_animations=True, export_animation_mode="NLA_TRACKS",
            export_force_sampling=True, export_frame_range=False, export_yup=True)
        attribution = next(item for item in record["sources"] if item["id"] == acquired["source_id"])
        entries.append({
            "source_id": acquired["source_id"],
            "creator": attribution["creator"],
            "source": attribution["url"],
            "license": attribution["license_id"],
            "license_file": attribution["license_file"],
            "original": source.relative_to(ROOT).as_posix(),
            "source_sha256": expected,
            "file": target.relative_to(ROOT).as_posix(),
            "sha256": digest(target),
            "bytes": target.stat().st_size,
            "source_vertices": before,
            "refined_vertices": sum(len(obj.data.vertices) for obj in meshes),
            "animations": sorted({track.name for obj in bpy.data.objects if obj.animation_data
                                  for track in obj.animation_data.nla_tracks}),
            "processing": "Weld coincident source positions without changing UV loops; 0.8%-width two-segment edge bevel and weighted panel normals. Original separate lid, local transforms, palette, materials and animation tracks retained.",
            "status": "Converted from acquired CC0 originals; native runtime review is separate from this conversion record.",
        })
    (OUTPUT / "manifest.json").write_text(json.dumps({
        "version": 1, "blender": bpy.app.version_string,
        "converter": "tools/polish-chest-models.py",
        "source_policy": "Original acquired files are never overwritten. These are source-derived CC0 chest bases, not new geometric stand-ins.",
        "models": entries,
    }, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(entries))


if __name__ == "__main__":
    main()
