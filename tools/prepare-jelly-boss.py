"""Convert the acquired Frog with expressive, game-authored Boss and facial clips."""

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector

SOURCE_SHA = "b716387a7be20268652e64b36aff88a8a46169ed8401051b422bebdacf00af76"
CLIPS = {"Idle": 2.4, "Throw": 1.0, "Kick": 1.4, "Snatch": 1.2,
         "Hit": 0.5, "Taunt": 2.0, "Celebrate": 2.0, "Escape": 1.0}


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--review", required=True)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    if digest(args.source) != SOURCE_SHA:
        raise RuntimeError("The acquired Frog does not match its reviewed source hash.")
    output, review = Path(args.output), Path(args.review)
    output.mkdir(parents=True, exist_ok=True)
    review.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=args.source, use_anim=True)
    rig = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    source_actions = [action.name for action in bpy.data.actions]
    rig.animation_data_clear()
    for mesh in meshes:
        mesh.animation_data_clear()
        for material in mesh.data.materials:
            if material and material.use_nodes:
                principled = next((node for node in material.node_tree.nodes
                                   if node.type == "BSDF_PRINCIPLED"), None)
                if principled:
                    principled.inputs["Roughness"].default_value = 0.72
                    principled.inputs["Metallic"].default_value = 0.0
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    bones = rig.pose.bones
    required = ["Root", "Head", "Torso", "UpperArm.L", "UpperArm.R", "LowerArm.L", "LowerArm.R",
                "UpperLeg.L", "UpperLeg.R", "LowerLeg.L", "LowerLeg.R",
                "Foot.L", "Foot.R", "PoleTarget.L", "PoleTarget.R"]
    if any(name not in bones for name in required):
        raise RuntimeError("The acquired Frog is missing its inspected source rig controls.")
    for bone in bones:
        bone.rotation_mode = "XYZ"
    # The acquired rig uses Root-parented foot and pole controls. Rebuild their
    # two-bone IK before baking; rotating those controls as FK detaches the feet.
    for suffix in ["L", "R"]:
        lower = bones["LowerLeg." + suffix]
        ik = lower.constraints.new("IK")
        ik.target = rig
        ik.subtarget = "Foot." + suffix
        ik.pole_target = rig
        ik.pole_subtarget = "PoleTarget." + suffix
        ik.chain_count = 2
    scene = bpy.context.scene
    scene.render.fps = 24
    scene.frame_start = 0
    rig_rotation = rig.matrix_world.to_quaternion()
    source_points = [mesh.matrix_world @ Vector(corner) for mesh in meshes for corner in mesh.bound_box]
    source_height = max(point.z for point in source_points) - min(point.z for point in source_points)
    face = next(mesh for mesh in meshes if mesh.name == "Frog")
    head_group = face.vertex_groups["Head"].index
    for material in list(face.data.materials):
        if material.name == "Frog_Main":
            shader = next(node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
            shader.inputs["Base Color"].default_value = (0.24, 0.68, 0.49, 1)
        elif material.name == "Frog_Secondary":
            # Keep the actual mouth dark; lighten only the source belly/spot faces.
            belly = material.copy()
            belly.name = "Bramble_Cream_Belly"
            shader = next(node for node in belly.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
            shader.inputs["Base Color"].default_value = (0.88, 0.75, 0.49, 1)
            original_index = list(face.data.materials).index(material)
            face.data.materials.append(belly)
            for polygon in face.data.polygons:
                if polygon.material_index != original_index:
                    continue
                head_weight = sum(sum(group.weight for group in face.data.vertices[index].groups
                                      if group.group == head_group) for index in polygon.vertices) / len(polygon.vertices)
                if head_weight < 0.4:
                    polygon.material_index = len(face.data.materials) - 1
    eye_vertices = set()
    for polygon in face.data.polygons:
        material = face.data.materials[polygon.material_index]
        if material and material.name.startswith(("Eye_Black", "Eye_White")):
            eye_vertices.update(polygon.vertices)
    if not eye_vertices:
        raise RuntimeError("The original Frog eye surfaces must be present for facial animation.")
    face.shape_key_add(name="Basis")
    face_keys = {}
    for side_name, sign in [("L", 1), ("R", -1)]:
        indices = [index for index in eye_vertices if (face.matrix_world @ face.data.vertices[index].co).x * sign > 0]
        if not indices:
            raise RuntimeError("Both original eyes need inspectable source vertices.")
        center = sum((face.matrix_world @ face.data.vertices[index].co for index in indices), Vector()) / len(indices)
        key = face.shape_key_add(name="Blink." + side_name)
        for index in indices:
            point = face.matrix_world @ face.data.vertices[index].co
            point.z = center.z + (point.z - center.z) * 0.07
            key.data[index].co = face.matrix_world.inverted() @ point
        face_keys[key.name] = key
    wide = face.shape_key_add(name="WideEyes")
    for sign in [-1, 1]:
        indices = [index for index in eye_vertices if (face.matrix_world @ face.data.vertices[index].co).x * sign > 0]
        center = sum((face.matrix_world @ face.data.vertices[index].co for index in indices), Vector()) / len(indices)
        for index in indices:
            point = face.matrix_world @ face.data.vertices[index].co
            point.x = center.x + (point.x - center.x) * 1.12
            point.z = center.z + (point.z - center.z) * 1.30
            wide.data[index].co = face.matrix_world.inverted() @ point
    face_keys[wide.name] = wide

    def aim(name, direction):
        bone = bones[name]
        rest = rig_rotation @ bone.bone.matrix_local.to_quaternion()
        original = rest @ Vector((0, 1, 0))
        turn = original.rotation_difference(Vector(direction).normalized())
        bone.rotation_euler = (rest.inverted() @ turn @ rest).to_euler("XYZ")

    def turn_world(name, axis, angle):
        bone = bones[name]
        rest = rig_rotation @ bone.bone.matrix_local.to_quaternion()
        bone.rotation_euler = (rest.inverted() @ Quaternion(Vector(axis), angle) @ rest).to_euler("XYZ")

    def aim_from_parent(name, direction):
        bpy.context.view_layer.update()
        bone = bones[name]
        parent_delta = bone.parent.matrix.to_quaternion() @ bone.parent.bone.matrix_local.to_quaternion().inverted()
        base = rig_rotation @ parent_delta @ bone.bone.matrix_local.to_quaternion()
        turn = (base @ Vector((0, 1, 0))).rotation_difference(Vector(direction).normalized())
        bone.rotation_euler = (base.inverted() @ turn @ base).to_euler("XYZ")

    def side(name):
        return 1 if (rig.matrix_world @ bones[name].bone.head_local).x > 0 else -1

    def foot_position(name, displacement):
        bones[name].location = bones[name].bone.matrix_local.to_3x3().inverted() @ (
            rig.matrix_world.to_3x3().inverted() @ Vector(displacement))

    def pose(clip, p):
        for bone in bones:
            bone.rotation_euler = (0, 0, 0)
            bone.location = (0, 0, 0)
            bone.scale = (1, 1, 1)
        for key in face_keys.values():
            key.value = 0.0
        # These are game-authored skeletal gestures, not mislabeled publisher takes.
        aim("UpperArm.L", (side("UpperArm.L") * 0.18, -0.08, -1))
        aim("UpperArm.R", (side("UpperArm.R") * 0.18, -0.08, -1))
        wave = math.sin(p * math.tau)
        bounce = math.sin(p * math.pi) ** 2
        bones["Head"].rotation_euler.z = 0.075 * wave
        bones["Torso"].rotation_euler.x = 0.035 * wave
        blink = max(0.0, 1.0 - abs(p - 0.24) / 0.045) if clip == "Idle" else 0.0
        face_keys["Blink.L"].value = blink
        face_keys["Blink.R"].value = blink
        if clip == "Throw":
            windup = math.sin(min(p / 0.55, 1) * math.pi / 2)
            release = max(0, min((p - 0.55) / 0.2, 1))
            recover = max(0, min((p - 0.75) / 0.25, 1))
            direction = Vector((side("UpperArm.R") * 0.25, 0.8 * windup - 1.8 * release, -1 + 1.65 * windup))
            direction = direction.lerp(Vector((side("UpperArm.R") * 0.18, -0.08, -1)), recover)
            aim("UpperArm.R", direction)
            bones["LowerArm.R"].rotation_euler.x = -0.9 * windup * (1 - release)
            bones["Torso"].rotation_euler.z = (-0.22 * windup + 0.4 * release) * (1 - recover)
            bones["Head"].rotation_euler.z = 0.12 * windup * (1 - recover)
            face_keys["WideEyes"].value = math.sin(release * math.pi) * (1 - recover)
        elif clip == "Kick":
            strike = math.sin(math.pi * max(0, min((p - 0.18) / 0.67, 1)))
            turn_world("Torso", (1, 0, 0), -0.2 * strike)
            foot_position("Foot.R", (0, -0.22 * source_height * strike, 0.19 * source_height * strike))
        elif clip == "Snatch":
            bones["Torso"].rotation_euler.x = 0.38 * bounce
            aim("UpperArm.L", (side("UpperArm.L") * 0.22, -bounce, -1 + bounce * 0.8))
            aim("UpperArm.R", (side("UpperArm.R") * 0.22, -bounce, -1 + bounce * 0.8))
            bones["LowerArm.R"].rotation_euler.x = -0.65 * bounce
            bones["LowerArm.L"].rotation_euler.x = -0.65 * bounce
            bones["UpperLeg.L"].rotation_euler.x = -0.3 * bounce
            face_keys["Blink.L"].value = bounce * 0.45
            face_keys["Blink.R"].value = bounce * 0.45
        elif clip == "Hit":
            bones["Torso"].rotation_euler.x = -0.42 * bounce
            bones["Head"].rotation_euler.x = 0.28 * bounce
            face_keys["WideEyes"].value = bounce
        elif clip == "Taunt":
            aim("UpperArm.L", (side("UpperArm.L") * 0.58, -0.15, 0.40 + 0.22 * wave))
            aim("UpperArm.R", (side("UpperArm.R") * 0.58, -0.15, 0.40 - 0.22 * wave))
            bones["Head"].rotation_euler.z = 0.18 * math.sin(p * math.tau * 2)
            bones["Torso"].rotation_euler.z = 0.065 * wave
            bones["Torso"].rotation_euler.x = 0.07 * abs(math.sin(p * math.tau * 2))
            aim_from_parent("LowerArm.L", (side("LowerArm.L") * 0.20, -1.0, 0.38 + 0.10 * wave))
            aim_from_parent("LowerArm.R", (side("LowerArm.R") * 0.20, -1.0, 0.38 - 0.10 * wave))
            face_keys["Blink.L"].value = math.sin(p * math.pi) ** 6 * 0.95
            for suffix in ["L", "R"]:
                for finger in ["Pinky", "Middle", "Index"]:
                    for joint in range(1, 4):
                        bones[f"{finger}{joint}.{suffix}"].rotation_euler.x = 0.22 * (0.5 + 0.5 * wave)
        elif clip == "Celebrate":
            aim("UpperArm.L", (side("UpperArm.L") * 0.5, 0, 1))
            aim("UpperArm.R", (side("UpperArm.R") * 0.5, 0, 1))
            bones["UpperLeg.L"].rotation_euler.x = 0.16 * abs(wave)
            bones["UpperLeg.R"].rotation_euler.x = 0.16 * abs(wave)
            bones["Head"].rotation_euler.z = 0.18 * wave
            bones["Torso"].rotation_euler.z = 0.12 * wave
            face_keys["Blink.L"].value = abs(wave) * 0.50
            face_keys["Blink.R"].value = abs(wave) * 0.50
        elif clip == "Escape":
            foot_position("Foot.L", (0, -0.12 * source_height * wave, 0.05 * source_height * max(0, wave)))
            foot_position("Foot.R", (0, 0.12 * source_height * wave, 0.05 * source_height * max(0, -wave)))
            aim("UpperArm.L", (side("UpperArm.L") * 0.28, -0.45 * wave, -1))
            aim("UpperArm.R", (side("UpperArm.R") * 0.28, 0.45 * wave, -1))
            turn_world("Torso", (1, 0, 0), 0.16)
            bones["Head"].rotation_euler.x = 0.14
            face_keys["Blink.L"].value = 0.30
            face_keys["Blink.R"].value = 0.30

    authored = []
    for clip, seconds in CLIPS.items():
        action = bpy.data.actions.new(clip)
        rig.animation_data_create()
        rig.animation_data.action = action
        face_action = bpy.data.actions.new(clip + "_Face")
        face.data.shape_keys.animation_data_create()
        face.data.shape_keys.animation_data.action = face_action
        frames = round(seconds * 24)
        for frame in range(frames + 1):
            scene.frame_set(frame)
            pose(clip, frame / frames)
            for bone in bones:
                bone.keyframe_insert("rotation_euler", frame=frame, group=bone.name)
                bone.keyframe_insert("location", frame=frame, group=bone.name)
            for key in face_keys.values():
                key.keyframe_insert("value", frame=frame, group="Original eye surfaces")
        rig.animation_data.action = None
        track = rig.animation_data.nla_tracks.new()
        track.name = clip
        track.strips.new(clip, 0, action)
        face.data.shape_keys.animation_data.action = None
        face_track = face.data.shape_keys.animation_data.nla_tracks.new()
        face_track.name = clip
        face_track.strips.new(clip, 0, face_action)
        authored.append({"name": clip, "seconds": seconds, "origin": "game-authored skeletal and original-eye morph animation"})
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for mesh in meshes:
        mesh.select_set(True)
    bpy.context.view_layer.objects.active = rig
    model = output / "bramble.glb"
    bpy.ops.export_scene.gltf(filepath=str(model), export_format="GLB", use_selection=True,
                             export_animations=True, export_animation_mode="NLA_TRACKS",
                             export_force_sampling=True, export_frame_range=False,
                             export_skins=True, export_yup=True)
    report = {"source_sha256": SOURCE_SHA, "model_sha256": digest(model),
              "model_bytes": model.stat().st_size, "animations": authored,
              "source_actions_inspected": source_actions, "facial_shapes": list(face_keys),
              "meshes": [{"name": mesh.name, "vertices": len(mesh.data.vertices)} for mesh in meshes]}
    manifest_path = output.parent / "manifest.json"
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest["model"]["sha256"] = report["model_sha256"]
        manifest["model"]["bytes"] = report["model_bytes"]
        manifest["source"]["title"] = "Frog, 50+ Monsters Bundle"
        manifest["source"]["fbx_sha256"] = SOURCE_SHA
        manifest["source"]["source_action_count"] = len(source_actions)
        manifest["source"]["animation_inventory"] = "docs/assets/talk-quest-monsters.json, lpm-frog"
        manifest["model"]["facial_shapes"] = list(face_keys)
        manifest["model"]["material_adaptations"] = "Game-authored mint-jade skin and cream belly/spot finish; source eye surfaces and dark mouth retained."
        manifest["model"]["animation_origin"] = "Game-authored skeletal motion and blink/wink/wide-eye morphs on the acquired Frog; publisher clips are not relabeled."
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (review / "conversion.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
