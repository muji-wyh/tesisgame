"""Reimport exported GLBs in Blender and verify actual skinned animation motion."""
import json
from pathlib import Path
import sys

import bpy
import numpy as np


def world_vertices(meshes):
    result = []
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in meshes:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        values = np.empty(len(mesh.vertices) * 3, dtype=np.float64)
        mesh.vertices.foreach_get("co", values)
        matrix = np.array(evaluated.matrix_world)
        result.append(values.reshape((-1, 3)) @ matrix[:3, :3].T + matrix[:3, 3])
        evaluated.to_mesh_clear()
    return np.concatenate(result)


root = Path(sys.argv[sys.argv.index("--") + 1])
manifest = json.loads((root / "assets/talk_quest/monsters/manifest.json").read_text())
results = []
for creature in manifest["creatures"]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(root / "assets/talk_quest/monsters" / creature["file"]))
    rigs = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if len(rigs) != 1 or not meshes:
        raise ValueError("Export lost the complete rig/mesh: " + creature["id"])
    rig = rigs[0]
    for obj in bpy.context.scene.objects:
        if obj.animation_data:
            for track in obj.animation_data.nla_tracks:
                track.mute = True
    actions = list(bpy.data.actions)
    clips = []
    for action in actions:
        rig.animation_data_create()
        rig.animation_data.action = action
        if action.slots:
            rig.animation_data.action_slot = action.slots[0]
        samples = []
        start, end = action.frame_range
        for frame in np.linspace(start, end, 7):
            bpy.context.scene.frame_set(int(frame), subframe=float(frame % 1))
            samples.append(world_vertices(meshes))
        points = np.stack(samples)
        motion = float(np.max(np.linalg.norm(points - points[0], axis=2)))
        bounds = np.ptp(points.reshape((-1, 3)), axis=0)
        valid = bool(np.isfinite(points).all() and motion > 0.001 and max(bounds) < 4.8)
        if not valid:
            raise ValueError("Exported animation does not deform the complete mesh: " + creature["id"] + "/" + action.name)
        clips.append({"name": action.name, "max_vertex_motion": motion,
                      "sampled_extent": list(bounds), "samples": 7, "status": "verified-moving-skinned-mesh"})
    if len(clips) != len(creature["animations"]):
        raise ValueError("Exported animation count changed during reimport")
    results.append({"id": creature["id"], "rigs": len(rigs), "meshes": len(meshes), "clips": clips})
target = root / "build/talk-quest-monsters/roundtrip-validation.json"
target.write_text(json.dumps({"version": 1, "status": "passed", "creatures": results}, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"status": "passed", "creatures": len(results), "clips": sum(len(r["clips"]) for r in results), "report": str(target)}))
