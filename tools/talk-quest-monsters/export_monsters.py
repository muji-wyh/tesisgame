"""Blender conversion of verified, selected FBXs to compact rigged GLBs.

No publisher scripts are loaded. Source files are read-only. Selection of a
source action requires measured skinned-vertex motion within bounded geometry.
"""
import hashlib
import json
import math
from pathlib import Path
import re
import sys
import traceback

import bpy
from mathutils import Vector
import numpy as np


def vertices(meshes):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    output = []
    for obj in meshes:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        local = np.empty(len(mesh.vertices) * 3, dtype=np.float64)
        mesh.vertices.foreach_get("co", local)
        local = local.reshape((-1, 3))
        transform = np.array(evaluated.matrix_world)
        output.append(local @ transform[:3, :3].T + transform[:3, 3])
        evaluated.to_mesh_clear()
    return np.concatenate(output)


def assign(rig, action):
    rig.animation_data_create()
    rig.animation_data.action = action
    if action and action.slots:
        rig.animation_data.action_slot = action.slots[0]


def inspect_action(rig, meshes, action, rest, extent):
    assign(rig, action)
    start, end = action.frame_range
    samples = []
    for frame in np.linspace(start, end, 7):
        bpy.context.scene.frame_set(int(frame), subframe=float(frame % 1))
        samples.append(vertices(meshes))
    points = np.stack(samples)
    movement = float(np.max(np.linalg.norm(points - points[0], axis=2)) / extent)
    max_extent = float(np.ptp(points.reshape((-1, 3)), axis=0).max() / extent)
    loop_error = float(np.max(np.linalg.norm(points[-1] - points[0], axis=1)) / extent)
    displacement = float(np.mean(np.linalg.norm(points - rest, axis=2)) / extent)
    valid = bool(np.isfinite(points).all() and movement > 0.0005 and max_extent < 2.4)
    return {"source_action": action.name, "frame_start": float(start), "frame_end": float(end),
            "duration_seconds": float((end - start) / bpy.context.scene.render.fps),
            "sample_count": 7, "max_vertex_motion_normalized": movement,
            "loop_error_normalized": loop_error, "max_extent_ratio": max_extent,
            "mean_rest_displacement_normalized": displacement, "valid": valid}


def source_semantic(action):
    return action.name.rsplit("|", 1)[-1]


def render_preview(path, center, extent):
    scene = bpy.context.scene
    bpy.ops.object.camera_add(location=center + Vector((3.1, -5.3, 2.6)).normalized() * extent * 3)
    camera = bpy.context.object
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = extent * 1.3
    scene.camera = camera
    for offset, energy in [((3, -4, 5), 700), ((-3, -2, 3), 400), ((2, 4, 4), 450)]:
        bpy.ops.object.light_add(type="AREA", location=center + Vector(offset) * extent)
        light = bpy.context.object
        light.data.energy = energy * extent * extent
        light.data.size = extent * 4
        light.rotation_euler = (center - light.location).to_track_quat("-Z", "Y").to_euler()
    scene.world = bpy.data.worlds.new("Preview World")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.7, 0.77, 0.88, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.5
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 12
    scene.cycles.use_denoising = True
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 6
    scene.render.resolution_x = scene.render.resolution_y = 420
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "Standard"
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def convert(job, preview_directory):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = 30
    source = Path(job["source_file"])
    if hashlib.sha256(source.read_bytes()).hexdigest() != job["source_sha256"]:
        raise ValueError("Source model changed since independent inventory")
    bpy.ops.import_scene.fbx(filepath=str(source), use_anim=True)
    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    rigs = [obj for obj in scene.objects if obj.type == "ARMATURE"]
    if not meshes or len(rigs) != 1:
        raise ValueError("Expected complete meshes with one source armature")
    rig = rigs[0]
    if any(not any(mod.type == "ARMATURE" and mod.object == rig for mod in obj.modifiers) for obj in meshes):
        raise ValueError("An imported mesh is not bound to the source rig")
    materials = {entry["name"].removesuffix("::Material"): entry for entry in job["embedded_materials"]}
    used = {obj.data.materials[p.material_index] for obj in meshes for p in obj.data.polygons}
    material_records = []
    for material in used:
        if material is None or material.name not in materials:
            raise ValueError("A source material could not be resolved")
        color = materials[material.name]["properties"]["DiffuseColor"]
        material.diffuse_color = (*color, 1.0)
        material.use_nodes = True
        material.node_tree.nodes.clear()
        output = material.node_tree.nodes.new("ShaderNodeOutputMaterial")
        shader = material.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
        shader.inputs["Base Color"].default_value = (*color, 1.0)
        shader.inputs["Roughness"].default_value = 0.72
        shader.inputs["Metallic"].default_value = 0.0
        material.node_tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
        material_records.append({"name": material.name, "source_linear_diffuse": color})
    rig.data.pose_position = "REST"
    bpy.context.view_layer.update()
    rest = vertices(meshes)
    lower, upper = rest.min(axis=0), rest.max(axis=0)
    extent = float((upper - lower).max())
    rig.data.pose_position = "POSE"
    bpy.context.view_layer.update()
    action_pool = list(bpy.data.actions)
    patterns = {"Idle": r"^(idle|flying_idle)", "Hit": r"^(hit|damage)", "Defeat": r"^(death|die|dead)",
                "Celebrate": r"^(wave|yes|dance|victory)"}
    selection, inspected = {}, {}
    for role, pattern in patterns.items():
        candidates = [a for a in action_pool if re.match(pattern, source_semantic(a), re.I)]
        records = []
        for action in candidates:
            record = inspect_action(rig, meshes, action, rest, extent)
            inspected[action.name] = record
            if record["valid"]:
                if role == "Idle" and record["loop_error_normalized"] > 0.2:
                    continue
                records.append((action, record))
        if records:
            if role == "Idle":
                action, record = min(records, key=lambda pair: pair[1]["mean_rest_displacement_normalized"] + pair[1]["loop_error_normalized"])
            else:
                action, record = min(records, key=lambda pair: pair[1]["mean_rest_displacement_normalized"])
            selection[role] = (action, record)
    if "Idle" not in selection:
        raise ValueError("No bounded moving source idle was found")
    assign(rig, selection["Idle"][0])
    scene.frame_set(round(selection["Idle"][1]["frame_start"]))
    scale = 2.0 / extent
    center_xy = (lower + upper) / 2
    root = bpy.data.objects.new("MonsterRoot", None)
    scene.collection.objects.link(root)
    for obj in list(scene.objects):
        if obj is not root and obj.parent is None:
            obj.parent = root
    root.scale = (scale, scale, scale)
    root.location = (-float(center_xy[0]) * scale, -float(center_xy[1]) * scale, -float(lower[2]) * scale)
    bpy.context.view_layer.update()
    preview_center = Vector((0, 0, float((upper[2] - lower[2]) * scale / 2)))
    if preview_directory:
        render_preview(preview_directory / (job["id"] + ".png"), preview_center, 2.0)
        for obj in list(scene.objects):
            if obj.type in {"CAMERA", "LIGHT"}:
                bpy.data.objects.remove(obj, do_unlink=True)
    assign(rig, None)
    for track in list(rig.animation_data.nla_tracks):
        rig.animation_data.nla_tracks.remove(track)
    for action in action_pool:
        if all(action != selected[0] for selected in selection.values()):
            bpy.data.actions.remove(action)
    animation_report = {}
    for role, (action, record) in selection.items():
        action.name = role
        action.use_fake_user = True
        track = rig.animation_data.nla_tracks.new()
        track.name = role
        strip = track.strips.new(role, 0, action)
        if action.slots:
            strip.action_slot = action.slots[0]
        strip.name = role
        track.mute = True
        animation_report[role] = dict(record, export_name=role, loop=role == "Idle")
    target = Path(job["output"])
    target.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(target), export_format="GLB",
                              export_animation_mode="NLA_TRACKS", export_anim_slide_to_zero=True,
                              export_frame_range=False, export_force_sampling=True,
                              export_optimize_animation_size=True, export_anim_single_armature=True,
                              export_skins=True, export_morph=False, export_cameras=False, export_lights=False,
                              export_extras=False, export_yup=True, export_apply=False,
                              export_def_bones=False, export_leaf_bone=False)
    return {"id": job["id"], "name": job["name"], "source_path": job["source_path"],
            "source_sha256": job["source_sha256"], "file": target.name,
            "sha256": hashlib.sha256(target.read_bytes()).hexdigest(), "bytes": target.stat().st_size,
            "rig_bones": len(rig.data.bones), "mesh_objects": len(meshes),
            "vertices": sum(len(obj.data.vertices) for obj in meshes),
            "triangles": sum(sum(len(poly.vertices) - 2 for poly in obj.data.polygons) for obj in meshes),
            "normalized_extent": 2.0, "normalized_height": float((upper[2] - lower[2]) * scale),
            "front_axis": "+Z", "floor_y": 0.0, "materials": sorted(material_records, key=lambda x:x["name"]),
            "animations": animation_report, "inspected_source_actions": list(inspected.values()),
            "procedural_fallbacks": [role for role in patterns if role not in selection]}


document = json.loads(Path(sys.argv[sys.argv.index("--") + 1]).read_text(encoding="utf-8"))
report = {"version": 1, "blender": bpy.app.version_string, "creatures": [], "errors": []}
preview_dir = Path(document["preview_directory"]) if document.get("preview_directory") else None
if preview_dir:
    preview_dir.mkdir(parents=True, exist_ok=True)
for job in document["jobs"]:
    try:
        report["creatures"].append(convert(job, preview_dir))
        print("EXPORTED " + job["id"], flush=True)
    except Exception as error:
        traceback.print_exc()
        report["errors"].append({"id": job["id"], "error": str(error)})
    Path(document["report"]).write_text(json.dumps(report, indent=2), encoding="utf-8")
if report["errors"]:
    raise RuntimeError("One or more monster exports failed; inspect the conversion report")
