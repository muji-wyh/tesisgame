"""Convert the acquired Bunny, preserving its mesh/materials, with authored Boss clips."""

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector

SOURCE_SHA = "981a92e69550d090ab08d55bc8eb8d26fac406fa35be5807025496cd29115705"
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
        raise RuntimeError("The acquired Bunny does not match its reviewed source hash.")
    output, review = Path(args.output), Path(args.review)
    output.mkdir(parents=True, exist_ok=True)
    review.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=args.source, use_anim=True)
    rig = next(obj for obj in bpy.data.objects if obj.type == "ARMATURE")
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
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
        # These are game-authored skeletal gestures, not mislabeled publisher takes.
        aim("UpperArm.L", (side("UpperArm.L") * 0.18, -0.08, -1))
        aim("UpperArm.R", (side("UpperArm.R") * 0.18, -0.08, -1))
        wave = math.sin(p * math.tau)
        bounce = math.sin(p * math.pi) ** 2
        bones["Head"].rotation_euler.z = 0.045 * wave
        bones["Ear1.L"].rotation_euler.x = 0.055 * math.sin(p * math.tau - 0.4)
        bones["Ear1.R"].rotation_euler.x = 0.055 * math.sin(p * math.tau + 0.4)
        bones["Torso"].rotation_euler.x = 0.025 * wave
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
        elif clip == "Hit":
            bones["Torso"].rotation_euler.x = -0.32 * bounce
            bones["Head"].rotation_euler.x = 0.2 * bounce
            bones["Ear1.L"].rotation_euler.x += 0.4 * bounce
            bones["Ear1.R"].rotation_euler.x += 0.4 * bounce
        elif clip == "Taunt":
            aim("UpperArm.L", (side("UpperArm.L") * 0.58, -0.15, 0.40 + 0.22 * wave))
            aim("UpperArm.R", (side("UpperArm.R") * 0.58, -0.15, 0.40 - 0.22 * wave))
            bones["Head"].rotation_euler.z = 0.18 * math.sin(p * math.tau * 2)
            bones["Torso"].rotation_euler.z = 0.065 * wave
            bones["Torso"].rotation_euler.x = 0.07 * abs(math.sin(p * math.tau * 2))
            aim_from_parent("LowerArm.L", (side("LowerArm.L") * 0.10, -0.22, 1.0 + 0.12 * wave))
            aim_from_parent("LowerArm.R", (side("LowerArm.R") * 0.10, -0.22, 1.0 - 0.12 * wave))
            bones["Ear1.L"].rotation_euler.z = 0.15 * wave
            bones["Ear1.R"].rotation_euler.z = -0.15 * wave
        elif clip == "Celebrate":
            aim("UpperArm.L", (side("UpperArm.L") * 0.5, 0, 1))
            aim("UpperArm.R", (side("UpperArm.R") * 0.5, 0, 1))
            bones["UpperLeg.L"].rotation_euler.x = 0.16 * abs(wave)
            bones["UpperLeg.R"].rotation_euler.x = 0.16 * abs(wave)
            bones["Head"].rotation_euler.z = 0.18 * wave
            bones["Torso"].rotation_euler.z = 0.12 * wave
        elif clip == "Escape":
            foot_position("Foot.L", (0, -0.12 * source_height * wave, 0.05 * source_height * max(0, wave)))
            foot_position("Foot.R", (0, 0.12 * source_height * wave, 0.05 * source_height * max(0, -wave)))
            aim("UpperArm.L", (side("UpperArm.L") * 0.28, -0.45 * wave, -1))
            aim("UpperArm.R", (side("UpperArm.R") * 0.28, 0.45 * wave, -1))
            turn_world("Torso", (1, 0, 0), 0.16)

    authored = []
    for clip, seconds in CLIPS.items():
        action = bpy.data.actions.new(clip)
        rig.animation_data_create()
        rig.animation_data.action = action
        frames = round(seconds * 24)
        for frame in range(frames + 1):
            scene.frame_set(frame)
            pose(clip, frame / frames)
            for bone in bones:
                bone.keyframe_insert("rotation_euler", frame=frame, group=bone.name)
                bone.keyframe_insert("location", frame=frame, group=bone.name)
        rig.animation_data.action = None
        track = rig.animation_data.nla_tracks.new()
        track.name = clip
        track.strips.new(clip, 0, action)
        authored.append({"name": clip, "seconds": seconds, "origin": "game-authored skeletal animation"})
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
              "meshes": [{"name": mesh.name, "vertices": len(mesh.data.vertices)} for mesh in meshes]}
    manifest_path = output.parent / "manifest.json"
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest["model"]["sha256"] = report["model_sha256"]
        manifest["model"]["bytes"] = report["model_bytes"]
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (review / "conversion.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report))


if __name__ == "__main__":
    main()
