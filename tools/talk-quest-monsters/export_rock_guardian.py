"""Export the original Mini Legion HP golem with authored skeletal clips.

Run with Blender, for example::

    blender --background --factory-startup --python export_rock_guardian.py -- \
        --output build/talk-quest-giants/rock-guardian.glb

The publisher's mesh, UVs and HP texture are retained. The source FBX has no
actions; the separate binary Unity humanoid clips cannot be safely retargeted
by Blender. Idle, Attack and Hit are therefore explicitly authored here on the
original deforming skeleton. No source files or publisher scripts are changed.
"""

import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector
import numpy as np


SOURCE_ROOT = Path(
    "C:/uworks/TalkQuest/sources/mini-legion-rock-golem/2bcdcd9755adeb1d/tree/"
    "Assets/Mini Legion Rock Golem PBR HP Polyart"
)


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def assign(rig, action):
    rig.animation_data_create()
    rig.animation_data.action = action
    if action and action.slots:
        rig.animation_data.action_slot = action.slots[0]


def vertices(meshes):
    graph = bpy.context.evaluated_depsgraph_get()
    result = []
    for obj in meshes:
        evaluated = obj.evaluated_get(graph)
        mesh = evaluated.to_mesh()
        points = np.empty(len(mesh.vertices) * 3, dtype=np.float64)
        mesh.vertices.foreach_get("co", points)
        points = points.reshape((-1, 3))
        transform = np.array(evaluated.matrix_world)
        result.append(points @ transform[:3, :3].T + transform[:3, 3])
        evaluated.to_mesh_clear()
    return np.concatenate(result)


def cardinal(vector):
    index = max(range(3), key=lambda i: abs(vector[i]))
    result = Vector((0, 0, 0))
    result[index] = 1 if vector[index] > 0 else -1
    return result


def source_basis(rig):
    def point(name):
        return rig.matrix_world @ rig.data.bones[name].head_local

    up = cardinal(point("Head") - point("Hips"))
    feet_forward = sum(
        (point("Toes_" + side) - point("Foot_" + side) for side in ("L", "R")),
        Vector((0, 0, 0)),
    )
    feet_forward -= up * feet_forward.dot(up)
    if feet_forward.length < 0.001:
        raise ValueError("Source foot orientation is ambiguous")
    front = cardinal(feet_forward)
    right = up.cross(front).normalized()
    return right, front, up


def limit_weights(meshes, rig):
    changed = 0
    maximum = 0
    deform = {bone.name for bone in rig.data.bones}
    for obj in meshes:
        group_names = {group.index: group.name for group in obj.vertex_groups}
        for vertex in obj.data.vertices:
            entries = sorted(
                ((item.group, item.weight) for item in vertex.groups
                 if group_names[item.group] in deform and item.weight > 0),
                key=lambda pair: pair[1], reverse=True,
            )
            if not entries:
                raise ValueError("The source contains an unbound mesh vertex")
            retained = entries[:4]
            if len(entries) > 4:
                changed += 1
            for item in list(vertex.groups):
                obj.vertex_groups[item.group].remove([vertex.index])
            total = sum(weight for _, weight in retained)
            for group, weight in retained:
                obj.vertex_groups[group].add([vertex.index], weight / total, "REPLACE")
            maximum = max(maximum, len(retained))
    return {"maximum_influences": maximum, "vertices_pruned": changed, "normalized": True}


def repair_source_bind(rig, meshes):
    """Correct this legacy FBX's mixed root/child units and bake its own pose.

    Blender imports the root Hips translation in meters but child bind offsets
    in centimeters. The mesh object itself has the correct 0.01 conversion.
    Uniformly scaling child offsets around Hips aligns the original skeleton
    with its original skin. Baking the publisher's initial pose then makes a
    coherent neutral stance without retaining the inconsistent imported bind.
    """
    conversion = meshes[0].matrix_world.to_scale()[0] / rig.matrix_world.to_scale()[0]
    if abs(conversion - 0.01) > 0.00001:
        raise ValueError("The source FBX unit conversion differs from the inspected source")
    original = {bone.name: (bone.location.copy(), bone.rotation_quaternion.copy(), bone.scale.copy())
                for bone in rig.pose.bones}
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    pivot = rig.data.edit_bones["Hips"].head.copy()
    for bone in rig.data.edit_bones:
        bone.head = pivot + (bone.head - pivot) * conversion
        bone.tail = pivot + (bone.tail - pivot) * conversion
    bpy.ops.object.mode_set(mode="OBJECT")
    for bone in rig.pose.bones:
        location, rotation, scale = original[bone.name]
        bone.location = location * conversion
        bone.rotation_quaternion = rotation
        bone.scale = scale
    bpy.context.view_layer.update()
    graph = bpy.context.evaluated_depsgraph_get()
    posed_vertices = {}
    for obj in meshes:
        evaluated = obj.evaluated_get(graph)
        evaluated_mesh = evaluated.to_mesh()
        if len(evaluated_mesh.vertices) != len(obj.data.vertices):
            raise ValueError("Source pose changed mesh topology")
        coords = np.empty(len(evaluated_mesh.vertices) * 3, dtype=np.float32)
        evaluated_mesh.vertices.foreach_get("co", coords)
        posed_vertices[obj.name] = coords
        evaluated.to_mesh_clear()
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    for obj in meshes:
        obj.data.vertices.foreach_set("co", posed_vertices[obj.name])
        obj.data.update()
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    return {"source_child_bind_offset_scale": conversion, "pivot": "Hips",
            "neutral_stance": "Publisher initial pose, baked after unit correction",
            "original_weights_and_bone_hierarchy_preserved": True}


def install_texture(meshes, path):
    image = bpy.data.images.load(str(path), check_existing=False)
    original_size = list(image.size)
    if max(image.size) > 1024:
        factor = 1024.0 / max(image.size)
        image.scale(round(image.size[0] * factor), round(image.size[1] * factor))
    image.pack()
    material = bpy.data.materials.new("HP_Golem")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = image
    shader.inputs["Roughness"].default_value = 0.84
    shader.inputs["Metallic"].default_value = 0.0
    material.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    material.node_tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    for obj in meshes:
        if not obj.data.uv_layers:
            raise ValueError("The original HP mesh is missing UV coordinates")
        obj.data.materials.clear()
        obj.data.materials.append(material)
        for polygon in obj.data.polygons:
            polygon.material_index = 0
    return {"name": material.name, "texture_source": str(path), "texture_sha256": sha256(path),
            "original_size": original_size, "embedded_size": list(image.size),
            "uv_mapping": "Original Golem.fbx UVs", "tint": [1, 1, 1, 1]}


def author_clip(rig, name, frames, axes):
    """Apply small source-local rotations derived from anatomical world axes."""
    assign(rig, None)
    action = bpy.data.actions.new(name)
    assign(rig, action)
    keyed = ["Spine", "Head", "Upper_Arm_L", "Upper_Arm_R", "Lower_Arm_L", "Lower_Arm_R"]
    local_axes = {}
    for bone_name in keyed:
        bone = rig.pose.bones[bone_name]
        bone.rotation_mode = "QUATERNION"
        basis = (rig.matrix_world @ bone.bone.matrix_local).to_3x3().inverted()
        local_axes[bone_name] = [(basis @ axis).normalized() for axis in axes]
    for frame, angles in frames:
        for bone_name in keyed:
            bone = rig.pose.bones[bone_name]
            bone.location = (0, 0, 0)
            bone.scale = (1, 1, 1)
            pitch, roll, yaw = angles.get(bone_name, (0, 0, 0))
            right, front, up = local_axes[bone_name]
            bone.rotation_quaternion = (
                Quaternion(right, math.radians(pitch))
                @ Quaternion(front, math.radians(roll))
                @ Quaternion(up, math.radians(yaw))
            )
            bone.keyframe_insert("rotation_quaternion", frame=frame, group=bone_name)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        key.interpolation = "BEZIER"
                        key.handle_left_type = "AUTO_CLAMPED"
                        key.handle_right_type = "AUTO_CLAMPED"
    action.use_fake_user = True
    return action


def author_clips(rig, axes):
    idle = [
        (0, {}),
        (20, {"Spine": (2.4, 0, 0), "Head": (-2.0, 0, -1.5),
              "Upper_Arm_L": (-2.5, 1.8, 0), "Upper_Arm_R": (-2.5, -1.8, 0),
              "Lower_Arm_L": (-2, 0, 0), "Lower_Arm_R": (-2, 0, 0)}),
        (40, {"Spine": (-1.7, 0, 0), "Head": (1.6, 0, 1.5),
              "Upper_Arm_L": (1.6, -1.3, 0), "Upper_Arm_R": (1.6, 1.3, 0)}),
        (60, {}),
    ]
    attack = [
        (0, {}),
        (9, {"Spine": (-7, 0, -5), "Head": (4, 0, 3),
             "Upper_Arm_L": (-62, 12, 0), "Upper_Arm_R": (-62, -12, 0),
             "Lower_Arm_L": (-30, 0, 0), "Lower_Arm_R": (-30, 0, 0)}),
        (15, {"Spine": (13, 0, 3), "Head": (-6, 0, 0),
              "Upper_Arm_L": (22, -8, 0), "Upper_Arm_R": (22, 8, 0),
              "Lower_Arm_L": (7, 0, 0), "Lower_Arm_R": (7, 0, 0)}),
        (23, {"Spine": (4, 0, 0), "Upper_Arm_L": (8, 0, 0),
              "Upper_Arm_R": (8, 0, 0)}),
        (36, {}),
    ]
    hit = [
        (0, {}),
        (4, {"Spine": (-13, 4, -8), "Head": (10, -5, 8),
             "Upper_Arm_L": (-18, 9, 0), "Upper_Arm_R": (-9, -7, 0),
             "Lower_Arm_L": (-12, 0, 0), "Lower_Arm_R": (-6, 0, 0)}),
        (10, {"Spine": (4, -2, 3), "Head": (-4, 2, -3),
              "Upper_Arm_L": (6, -3, 0), "Upper_Arm_R": (3, 2, 0)}),
        (21, {}),
    ]
    return {name: author_clip(rig, name, frames, axes)
            for name, frames in (("Idle", idle), ("Attack", attack), ("Hit", hit))}


def inspect_clip(rig, meshes, action):
    assign(rig, action)
    start, end = action.frame_range
    points = []
    for frame in np.linspace(start, end, 13):
        bpy.context.scene.frame_set(int(frame), subframe=float(frame % 1))
        points.append(vertices(meshes))
    points = np.stack(points)
    motion = np.linalg.norm(points - points[0], axis=2)
    # Subtract centroid translation to prove internal deformation, not root bob.
    centered = points - points.mean(axis=1, keepdims=True)
    deformation = np.linalg.norm(centered - centered[0], axis=2)
    maximum = float(deformation.max())
    if not np.isfinite(points).all() or maximum < 0.002:
        raise ValueError("Authored clip does not visibly deform skinned vertices: " + action.name)
    max_extent = float(np.ptp(points.reshape((-1, 3)), axis=0).max())
    if max_extent > 3.8 or float(motion.max()) > 2.0:
        raise ValueError("Authored clip exceeds safe normalized bounds: " + action.name
                         + " extent=" + str(max_extent) + " motion=" + str(float(motion.max())))
    return {"export_name": action.name, "provenance": "Authored skeletal animation",
            "source_animation": None, "loop": action.name == "Idle",
            "frame_start": float(start), "frame_end": float(end),
            "duration_seconds": float((end - start) / bpy.context.scene.render.fps),
            "sample_count": len(points), "max_vertex_motion": float(motion.max()),
            "max_centered_vertex_deformation": maximum,
            "max_extent": max_extent,
            "moving_vertex_fraction": float((deformation.max(axis=0) > 0.001).mean()),
            "loop_error": float(np.linalg.norm(points[-1] - points[0], axis=1).max()),
            "bounds_blender": {"min": points.min(axis=(0, 1)).tolist(),
                               "max": points.max(axis=(0, 1)).tolist()},
            "root_translation_animated": False, "valid": True}


def glb_summary(path):
    data = path.read_bytes()
    length, kind = struct.unpack_from("<I4s", data, 12)
    if kind != b"JSON":
        raise ValueError("GLB is missing its JSON chunk")
    document = json.loads(data[20:20 + length])
    animations = [entry["name"] for entry in document.get("animations", [])]
    if set(animations) != {"Idle", "Attack", "Hit"}:
        raise ValueError("Unexpected exported clips: " + repr(animations))
    if any("WEIGHTS_1" in primitive["attributes"]
           for mesh in document["meshes"] for primitive in mesh["primitives"]):
        raise ValueError("GLB contains more than four weights per vertex")
    return {"animations": animations, "skins": len(document.get("skins", [])),
            "skin_joints": [len(skin["joints"]) for skin in document.get("skins", [])],
            "embedded_images": len(document.get("images", [])),
            "animation_channels": {entry["name"]: len(entry["channels"])
                                   for entry in document.get("animations", [])}}


def preview(path, rig, idle, height):
    assign(rig, idle)
    scene = bpy.context.scene
    scene.frame_set(0)
    center = Vector((0, 0, height * 0.5))
    bpy.ops.object.camera_add(location=(2.6, -5.4, 2.5))
    camera = bpy.context.object
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 2.65
    scene.camera = camera
    for position, power in [((3, -4, 5), 500), ((-3, -2, 3), 300), ((2, 4, 4), 400)]:
        bpy.ops.object.light_add(type="AREA", location=position)
        light = bpy.context.object
        light.data.energy = power
        light.data.size = 4
        light.rotation_euler = (center - light.location).to_track_quat("-Z", "Y").to_euler()
    scene.world = bpy.data.worlds.new("Preview World")
    scene.world.color = (0.3, 0.3, 0.3)
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
    path.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(path.resolve())
    bpy.ops.render.render(write_still=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, default=SOURCE_ROOT)
    parser.add_argument("--output", type=Path, default=Path("build/talk-quest-giants/rock-guardian.glb"))
    parser.add_argument("--report", type=Path)
    parser.add_argument("--diagnose", action="store_true", help="Inspect source bind transforms without exporting")
    parser.add_argument("--preview", type=Path, help="Optional 420px transparent PNG of the neutral pose")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    source = args.source_root / "Meshes/Golem.fbx"
    texture = args.source_root / "Textures/HP_Golem.png"
    report_path = args.report or args.output.with_suffix(".report.json")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(source), use_anim=False)
    scene = bpy.context.scene
    scene.render.fps = 30
    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    rigs = [obj for obj in scene.objects if obj.type == "ARMATURE"]
    if len(rigs) != 1 or not meshes:
        raise ValueError("Expected one original skeleton and at least one mesh")
    rig = rigs[0]
    if args.diagnose:
        rig.data.pose_position = "POSE"
        bpy.context.view_layer.update()
        posed = vertices(meshes)
        rig.data.pose_position = "REST"
        bpy.context.view_layer.update()
        rested = vertices(meshes)
        inspection = {
            "rig_matrix": [list(row) for row in rig.matrix_world],
            "meshes": [{"name": obj.name, "matrix_world": [list(row) for row in obj.matrix_world],
                        "matrix_parent_inverse": [list(row) for row in obj.matrix_parent_inverse],
                        "local_bounds": [list(min(v.co[i] for v in obj.data.vertices) for i in range(3)),
                                         list(max(v.co[i] for v in obj.data.vertices) for i in range(3))]}
                       for obj in meshes],
            "pose_bounds": [posed.min(axis=0).tolist(), posed.max(axis=0).tolist()],
            "rest_bounds": [rested.min(axis=0).tolist(), rested.max(axis=0).tolist()],
            "bones": [{"name": bone.name, "head": list(bone.bone.head_local),
                       "tail": list(bone.bone.tail_local), "location": list(bone.location),
                       "scale": list(bone.scale), "quaternion": list(bone.rotation_quaternion),
                       "rotation_mode": bone.rotation_mode, "euler": list(bone.rotation_euler),
                       "matrix_basis": [list(row) for row in bone.matrix_basis]}
                      for bone in rig.pose.bones],
        }
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(inspection, indent=2), encoding="utf-8")
        print("Diagnostic report: " + str(report_path), flush=True)
        return
    if any(not any(mod.type == "ARMATURE" and mod.object == rig for mod in obj.modifiers)
           for obj in meshes):
        raise ValueError("All golem geometry must use the original skeleton")
    bind_report = repair_source_bind(rig, meshes)
    axes = source_basis(rig)
    weight_report = limit_weights(meshes, rig)
    material_report = install_texture(meshes, texture)
    actions = author_clips(rig, axes)
    assign(rig, None)
    for bone in rig.pose.bones:
        bone.matrix_basis.identity()
    root = bpy.data.objects.new("MonsterRoot", None)
    scene.collection.objects.link(root)
    for obj in list(scene.objects):
        if obj is not root and obj.parent is None:
            obj.parent = root
    right, front, up = axes
    root.rotation_mode = "QUATERNION"
    root.rotation_quaternion = Matrix((right, -front, up)).to_quaternion()
    rig.data.pose_position = "REST"
    bpy.context.view_layer.update()
    rest = vertices(meshes)
    lower, upper = rest.min(axis=0), rest.max(axis=0)
    scale = 2.0 / float((upper - lower).max())
    center = (lower + upper) * 0.5
    root.scale = (scale, scale, scale)
    root.location = (-float(center[0]) * scale, -float(center[1]) * scale, -float(lower[2]) * scale)
    bpy.context.view_layer.update()
    normalized = vertices(meshes)
    lower, upper = normalized.min(axis=0), normalized.max(axis=0)
    godot_points = normalized[:, [0, 2, 1]] * np.array([1, 1, -1])
    rig.data.pose_position = "POSE"
    bpy.context.view_layer.update()
    animation_report = {name: inspect_clip(rig, meshes, action) for name, action in actions.items()}
    animated_min = np.min([value["bounds_blender"]["min"] for value in animation_report.values()], axis=0)
    animated_max = np.max([value["bounds_blender"]["max"] for value in animation_report.values()], axis=0)
    animated_godot_min = [float(animated_min[0]), float(animated_min[2]), -float(animated_max[1])]
    animated_godot_max = [float(animated_max[0]), float(animated_max[2]), -float(animated_min[1])]
    assign(rig, None)
    scene.frame_set(0)
    for bone in rig.pose.bones:
        bone.matrix_basis.identity()
    for track in list(rig.animation_data.nla_tracks):
        rig.animation_data.nla_tracks.remove(track)
    for name, action in actions.items():
        track = rig.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, 0, action)
        strip.action_slot = action.slots[0]
        strip.name = name
        track.mute = True
    args.output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(args.output), export_format="GLB", export_animation_mode="NLA_TRACKS",
        export_anim_slide_to_zero=True, export_frame_range=False, export_force_sampling=True,
        export_optimize_animation_size=True, export_anim_single_armature=True,
        export_skins=True, export_morph=False, export_cameras=False, export_lights=False,
        export_extras=False, export_yup=True, export_apply=False,
        export_def_bones=False, export_leaf_bone=False,
    )
    report = {
        "id": "giant-rock-guardian", "name": "Rock Guardian", "blender": bpy.app.version_string,
        "source_path": str(source), "source_sha256": sha256(source),
        "file": args.output.name, "output_path": str(args.output.resolve()),
        "bytes": args.output.stat().st_size, "sha256": sha256(args.output),
        "rig_bones": len(rig.data.bones), "mesh_objects": len(meshes),
        "vertices": sum(len(obj.data.vertices) for obj in meshes),
        "triangles": sum(sum(len(poly.vertices) - 2 for poly in obj.data.polygons) for obj in meshes),
        "normalized_extent": float((upper - lower).max()),
        "normalized_height": float(upper[2] - lower[2]),
        "front_axis": "+Z", "floor_y": float(godot_points[:, 1].min()),
        "bounds": {"min": animated_godot_min, "max": animated_godot_max},
        "rest_bounds": {"min": godot_points.min(axis=0).tolist(), "max": godot_points.max(axis=0).tolist()},
        "source_basis": {"right": list(right), "front": list(front), "up": list(up)},
        "weights": weight_report, "materials": [material_report], "bind_repair": bind_report,
        "animations": animation_report, "glb": glb_summary(args.output),
        "animation_note": "Authored on the original deforming rig. The FBX contains no actions; "
                          "binary Unity humanoid muscle clips were not retargeted or represented as source animation.",
        "unity_animation_sources": [
            {"path": str(path), "sha256": sha256(path), "used": False}
            for path in (args.source_root / "Animations").glob("*.anim")
        ],
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    if args.preview:
        preview(args.preview, rig, actions["Idle"], report["normalized_height"])
    print(json.dumps({"output": str(args.output), "report": str(report_path), "bytes": report["bytes"],
                      "clips": report["glb"]["animations"], "height": report["normalized_height"]}), flush=True)


if __name__ == "__main__":
    main()
