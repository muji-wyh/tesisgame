"""Bake local-only vocabulary motion studies on the acquired Kenney character rig.

Run with Blender --background --factory-startup --python-exit-code 1 --python
tools/vocabulary-art/render-animations.py -- <word IDs> [--poses] [--output-dir PATH].
The accepted static illustrations and shipped game assets are never overwritten.
"""
import argparse
import importlib.util
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

spec = importlib.util.spec_from_file_location("scenes", Path(__file__).with_name("render-scenes.py"))
art = importlib.util.module_from_spec(spec)
spec.loader.exec_module(art)
OUT = art.ROOT / "animated"
FPS = 24
STUDIES = {
    "walk": (40, "A cheerful alternating walk with planted steps, swinging arms and a relaxed counter-turn."),
    "run": (20, "A bright, athletic stride with pumping elbows, lifted knees and a brief flight phase."),
    "jump": (64, "Eager preparation, a joyful open-arm leap, a soft two-foot landing and a proud recovery."),
    "open": (80, "Pull the handle, reveal the doorway and proudly present it. The open state holds before replay."),
    "close": (80, "Push the door shut with a small effort, then give a pleased nod. The closed state holds before replay."),
    "drink": (80, "Eagerly lift the glass, take a clear sip, then lower it with a satisfied reaction."),
    "eat": (80, "Lift the bread for a bite, then lower it and give a contented little chewing nod."),
    "hello": (72, "A friendly head tilt, an open-handed three-beat wave and a gentle return to rest."),
}


def smooth(value):
    value = max(0.0, min(1.0, value))
    return value * value * (3.0 - 2.0 * value)


def ramp(t, start, end):
    return smooth((t - start) / (end - start))


def mix(a, b, t):
    return Vector(a).lerp(Vector(b), t)


def reset(rig):
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    rig.pose.bones["Head"].scale = (1.12,) * 3
    bpy.context.view_layer.update()


def shift_hips(rig, dz=0, dy=0):
    bone = rig.pose.bones["HipsCtrl"]
    bone.matrix = Matrix.Translation((0, dy, dz)) @ bone.matrix
    bpy.context.view_layer.update()


def turn_bone(rig, name, angle, axis):
    bone = rig.pose.bones[name]
    pivot = bone.head.copy()
    bone.matrix = Matrix.Translation(pivot) @ Matrix.Rotation(angle, 4, axis) @ Matrix.Translation(-pivot) @ bone.matrix
    bpy.context.view_layer.update()


def cheerful_materials(objects):
    """Retain the acquired UVs, clothing and material; animate only the eyelids."""
    eyes_open = bpy.data.images.load(str(art.SKINS / "child-cheerful.png"), check_existing=True)
    eyes_closed = bpy.data.images.load(str(art.SKINS / "child-cheerful-blink.png"), check_existing=True)
    controls = []
    for obj in objects:
        if obj.type != "MESH":
            continue
        for material in obj.data.materials:
            nodes = material.node_tree.nodes
            skin = next(n for n in nodes if n.type == "TEX_IMAGE")
            skin.image = eyes_open
            blink = nodes.new("ShaderNodeTexImage")
            blink.image = eyes_closed
            blend = nodes.new("ShaderNodeMixRGB")
            blend.name = "Expressive eyelids"
            material.node_tree.links.new(skin.outputs["Color"], blend.inputs[1])
            material.node_tree.links.new(blink.outputs["Color"], blend.inputs[2])
            material.node_tree.links.new(blend.outputs[0], nodes.get("Principled BSDF").inputs["Base Color"])
            controls.append(blend.inputs[0])
    return controls


def blink_amount(word, phase):
    # Two- to three-frame blinks accompany a glance or landing rather than
    # repeating at an unrelated global clock across all the word pictures.
    centers = {"walk": (.70,), "run": (), "jump": (.69,), "open": (.13, .78),
               "close": (.12, .79), "drink": (.73,), "eat": (.75,), "hello": (.32, .78)}
    width = .035 if STUDIES[word][0] >= 64 else .045
    return max([1.0 - smooth(abs(phase-center)/width) for center in centers[word]] or [0.0])


def limb(rig, first_name, second_name, target, bend):
    """Two-bone reach in rig space, preserving acquired segment lengths."""
    bpy.context.view_layer.update()
    first = rig.pose.bones[first_name]
    second = rig.pose.bones[second_name]
    shoulder = first.head.copy()
    direction = Vector(target) - shoulder
    a, b = first.length, second.length
    distance = max(abs(a - b) + .002, min(direction.length, a + b - .002))
    direction.normalize()
    normal = Vector(bend) - Vector(bend).dot(direction) * direction
    if normal.length < .01:
        normal = Vector((0, -1, 0))
    normal.normalize()
    along = (a * a - b * b + distance * distance) / (2 * distance)
    elbow = shoulder + along * direction + math.sqrt(max(0, a * a - along * along)) * normal
    art.point(rig, first_name, elbow)
    art.point(rig, second_name, target)


def hand(rig, side, target, bend=None):
    limb(rig, side + "Arm", side + "ForeArm", target,
         bend or (1 if side == "Left" else -1, -.35, -.7))


def foot(rig, side, target, toe_lift=0):
    limb(rig, side + "UpLeg", side + "Leg", target, (0, -1, 0))
    ankle = rig.pose.bones[side + "Foot"].head.copy()
    art.point(rig, side + "Foot", ankle + Vector((.04 if side == "Left" else -.04, -.24, -.18 + toe_lift)))


def relaxed_arms(rig):
    hand(rig, "Left", (.58, -.13, 1.38))
    hand(rig, "Right", (-.58, -.13, 1.38))


def grounded(rig, crouch=0):
    shift_hips(rig, -crouch)
    for side, sign in [("Left", 1), ("Right", -1)]:
        foot(rig, side, (sign * .24, .15, .20))


def setup(word):
    art.study.clear()
    rig, objects = art.person("stand")
    expression_controls = cheerful_materials(objects)
    root = art.move_group(objects, yaw=-.65 if word in ("walk", "run") else -.12)
    extras = {}
    if word in ("open", "close"):
        root.scale = (.82,) * 3
        root.location = (1.68, -.25, 0)
        root.rotation_euler.z = -1.3
        door = art.prop("doorway")
        art.move_group(door, scale=3.5, location=(0, .15, 0))
        leaf = next(o for o in door if o.type == "MESH" and "doorway" not in o.name.lower())
        leaf.rotation_mode = "XYZ"
        bpy.context.view_layer.update()
        corners = [Vector(c) for c in leaf.bound_box]
        low = Vector(tuple(min(p[i] for p in corners) for i in range(3)))
        high = Vector(tuple(max(p[i] for p in corners) for i in range(3)))
        extras = {
            "leaf": leaf, "base": leaf.matrix_world.copy(),
            "hinge": leaf.matrix_world @ Vector((low.x, (low.y + high.y) * .5, low.z)),
            "handle": Vector((high.x - .04, low.y - .006, low.z + (high.z - low.z) * .53)),
        }
    elif word in ("drink", "eat"):
        held, held_root = art.model("food-kit", "glass" if word == "drink" else "loaf", .64)
        # Pivot about the center of the object, so the grip travels with the prop.
        bpy.context.view_layer.update()
        points = [o.matrix_world @ Vector(c) for o in held if o.type == "MESH" for c in o.bound_box]
        center = Vector(tuple((min(p[i] for p in points) + max(p[i] for p in points)) / 2 for i in range(3)))
        pivot = bpy.data.objects.new("Held object grip", None)
        bpy.context.collection.objects.link(pivot)
        pivot.location = center
        bpy.context.view_layer.update()
        world = held_root.matrix_world.copy()
        held_root.parent = pivot
        held_root.matrix_world = world
        extras = {"held": pivot}
    extras["expressions"] = expression_controls
    return rig, root, extras


def pose(word, phase, rig, root, extra):
    reset(rig)
    root.location.z = 0
    root.rotation_euler.x = root.rotation_euler.y = 0
    relaxed_arms(rig)
    if word in ("walk", "run"):
        running = word == "run"
        stride = .88 if running else .57
        # The support foot travels back at an even rate; the swing foot clears the floor.
        shift_hips(rig, (-.075 + .10 * math.cos(phase * 4 * math.pi)) if running else (-.035 + .045 * math.cos(phase * 4 * math.pi)))
        counter_turn = math.sin(phase * 2 * math.pi)
        turn_bone(rig, "Spine", (.105 if running else .07) * counter_turn, "Z")
        for side, offset, sign in [("Left", 0, 1), ("Right", .5, -1)]:
            p = (phase + offset) % 1
            stance = .40 if running else .60
            if p < stance:
                y = -stride + 2 * stride * (p / stance)
                z = .20
                lift = 0
            else:
                swing = (p - stance) / (1 - stance)
                y = stride * (1 - 2 * smooth(swing))
                z = .20 + (.72 if running else .32) * math.sin(math.pi * swing)
                lift = .16 * math.sin(math.pi * swing)
            foot(rig, side, (sign * .23, y + .15, z), lift)
            swing = math.cos((phase + offset) * 2 * math.pi)
            hand(rig, side, (sign * (.43 if running else .60), -.25 + (.50 if running else .35) * swing,
                             (2.04 if running else 1.55) + (.16 if running else .12) * swing),
                 (sign * .16, .35, -1) if running else None)
        if running:
            # The pelvis rises only during the two short unsupported parts of the stride.
            support_phase = phase % .5
            root.location.z = .10 * math.sin((support_phase - .40) / .10 * math.pi) if support_phase > .40 else 0
        art.point(rig, "Head", (.04 * counter_turn, -.07, 3.85))
    elif word == "jump":
        crouch = .31 * (ramp(phase, .06, .22) - ramp(phase, .25, .34))
        landing = .25 * (ramp(phase, .60, .67) - ramp(phase, .68, .81))
        grounded(rig, crouch + landing)
        flight = (phase - .33) / .29
        root.location.z = .95 * 4 * flight * (1 - flight) if 0 < flight < 1 else 0
        raise_arm = ramp(phase, .23, .37) - ramp(phase, .61, .85)
        for side, sign in [("Left", 1), ("Right", -1)]:
            anticipation = ramp(phase, .06, .21) - ramp(phase, .23, .35)
            hand(rig, side, mix((sign * .58, -.15 + .28 * anticipation, 1.40),
                                (sign * .99, -.09, 3.32), raise_arm))
            if 0 < flight < 1:
                foot(rig, side, (sign * .32, .15 + .22 * math.sin(flight * math.pi), .20 + .20 * math.sin(flight * math.pi)))
        art.point(rig, "Head", (.05 * raise_arm, -.06 - .12 * (crouch + landing), 3.85))
    elif word in ("open", "close"):
        grounded(rig)
        motion = ramp(phase, .14, .59)
        angle = (-5 - 35 * motion) if word == "open" else (-40 + 35 * motion)
        leaf = extra["leaf"]
        hinge = extra["hinge"]
        leaf.matrix_world = Matrix.Translation(hinge) @ Matrix.Rotation(math.radians(angle), 4, "Z") @ Matrix.Translation(-hinge) @ extra["base"]
        bpy.context.view_layer.update()
        grip_world = leaf.matrix_world @ extra["handle"]
        target = rig.matrix_world.inverted() @ grip_world
        hand(rig, "Left", target)
        art.point(rig, "LeftHand", target + rig.matrix_world.inverted().to_3x3() @ Vector((-.04, -.02, 0)))
        pleased = ramp(phase, .62, .78)
        free_hand = mix((-.58, -.13, 1.38), (-.90, .08, 1.95), pleased)
        hand(rig, "Right", free_hand)
        art.point(rig, "RightHand", free_hand + mix((0, 0, -.18), (-.17, 0, .07), pleased))
        nod = .085 * math.sin(math.pi * (phase-.67)/.18) if .67 < phase < .85 else 0
        art.point(rig, "Head", (.08 * pleased, -.28 + .13 * pleased - nod, 3.80))
        # Look back toward the learner once the doorway state is established;
        # keep the body and gripping hand anchored to the door throughout.
        turn_bone(rig, "Head", .92 * pleased, "Z")
    elif word in ("drink", "eat"):
        grounded(rig)
        lift = ramp(phase, .09, .32) - ramp(phase, .62, .82)
        pivot = extra["held"]
        local = mix((.08, -.64, 1.80), (.04, -.68, 2.72 if word == "drink" else 2.78), lift)
        sip = ramp(phase, .37, .46) - ramp(phase, .55, .63)
        pivot.location = rig.matrix_world @ local
        pivot.rotation_euler = (-(.55 * sip if word == "drink" else .06 * lift), 0, root.rotation_euler.z + .15)
        bpy.context.view_layer.update()
        hand(rig, "Left", rig.matrix_world.inverted() @ (pivot.matrix_world @ Vector((.20, 0, -.08))))
        if word == "eat":
            hand(rig, "Right", rig.matrix_world.inverted() @ (pivot.matrix_world @ Vector((-.20, 0, -.06))))
        contented = ramp(phase, .64, .72) - ramp(phase, .88, .99)
        nod = (.045 if word == "eat" else .025) * math.sin(phase * math.pi * 16) * contented
        art.point(rig, "Head", (.065 * contented, -.03 - .09 * sip + nod, 3.82))
        if word == "drink":
            hand(rig, "Right", mix((-.58, -.13, 1.38), (-.57, -.25, 1.76), .60 * lift + .30 * contented))
    elif word == "hello":
        grounded(rig, .025 * (ramp(phase, .05, .13) - ramp(phase, .14, .22)))
        lift = ramp(phase, .06, .23) - ramp(phase, .77, .95)
        wave = math.sin((phase - .23) * math.pi * 10) * (ramp(phase, .22, .31) - ramp(phase, .70, .79))
        target = mix((-.58, -.13, 1.38), (-.83 + .18 * wave, -.20, 3.21), lift)
        hand(rig, "Right", target)
        palm = mix((-.035, -.02, -.19), (-.035 + .13 * wave, -.02, .21), lift)
        art.point(rig, "RightHand", target + palm)
        hand(rig, "Left", mix((.58, -.13, 1.38), (.58, -.27, 1.65), lift))
        art.point(rig, "Head", (.12 * lift + .018 * wave, -.04, 3.82))
    for control in extra["expressions"]:
        control.default_value = blink_amount(word, phase)
    bpy.context.view_layer.update()


def frame_bounds(meshes):
    graph = bpy.context.evaluated_depsgraph_get()
    return [o.evaluated_get(graph).matrix_world @ Vector(c) for o in meshes for c in o.evaluated_get(graph).bound_box]


def render(word, poses_only=False):
    count, description = STUDIES[word]
    print("ANIMATION_START", word, "poses" if poses_only else "full", flush=True)
    directory = OUT / word
    directory.mkdir(parents=True, exist_ok=True)
    rig, root, extra = setup(word)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    moving = [root] + [extra[k] for k in ("held", "leaf") if k in extra]
    points = []
    contact = []
    for frame in range(count):
        bpy.context.scene.frame_set(frame + 1)
        pose(word, frame / count, rig, root, extra)
        for control in extra["expressions"]:
            control.keyframe_insert("default_value", frame=frame + 1)
        for bone in rig.pose.bones:
            for prop in ("location", "rotation_quaternion", "scale"):
                bone.keyframe_insert(prop, frame=frame + 1)
        for obj in moving:
            for prop in ("location", "rotation_euler", "scale"):
                obj.keyframe_insert(prop, frame=frame + 1)
        if frame % 4 == 0 or frame == count - 1:
            points.extend(frame_bounds(meshes))
        if word in ("open", "close"):
            desired = extra["leaf"].matrix_world @ extra["handle"]
            actual = rig.matrix_world @ rig.pose.bones["LeftHand"].head
            contact.append((actual - desired).length)
        if (frame + 1) % 20 == 0 or frame == count - 1:
            print("ANIMATION_BAKED", word, frame + 1, "of", count, flush=True)
    for action in bpy.data.actions:
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:
                            key.interpolation = "LINEAR"
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end = 1, count
    scene.render.fps = FPS
    scene.frame_set(1)
    target = art.study.setup(meshes, "unused.png")
    camera = scene.camera
    center = Vector(tuple((min(p[i] for p in points) + max(p[i] for p in points)) / 2 for i in range(3)))
    direction = Vector((2.4 if word in ("open", "close") else 1.15, -3.0, .8)).normalized()
    camera.location = center + direction * 18
    art.study.aim(camera, center)
    bpy.context.view_layer.update()
    local = [camera.matrix_world.inverted() @ p for p in points]
    xmin, xmax = min(p.x for p in local), max(p.x for p in local)
    ymin, ymax = min(p.y for p in local), max(p.y for p in local)
    camera.location += camera.matrix_world.to_quaternion() @ Vector(((xmin + xmax) / 2, (ymin + ymax) / 2, 0))
    camera.data.ortho_scale = max(xmax - xmin, ymax - ymin) * 1.17
    # One high, broad shadow source keeps the small illustration grounded without
    # several long shadows competing with the hand and foot silhouettes.
    lights = [o for o in scene.objects if o.type == "LIGHT"]
    for light in lights[1:]:
        light.data.use_shadow = False
    extent = camera.data.ortho_scale / 1.17
    lights[0].location = center + Vector((-1.2, -1.8, 8)) * extent
    lights[0].data.size = extent * 5
    lights[0].data.energy *= 1.4
    art.study.aim(lights[0], center)
    # A real shadow catcher makes contact and height legible while retaining alpha.
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.045))
    floor = bpy.context.object
    floor.name = "Studio contact shadow"
    floor.is_shadow_catcher = True
    floor.data.materials.append(art.material("Neutral shadow catcher", (.65, .65, .65)))
    scene.cycles.samples = 20
    scene.cycles.use_animated_seed = False
    scene.render.use_persistent_data = True
    scene.render.resolution_x = scene.render.resolution_y = 256
    scene.render.filepath = str(directory / "frame-")
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / (word + ".blend")))
    metadata = {
        "id": word, "fps": FPS, "frames": count, "duration": count / FPS,
        "description": description, "source": "Adapted acquired Kenney CC0 character and prop meshes",
        "animation": "Locally authored cheerful skeletal / prop motion with timed blinks",
        "expression": "Smile and eyelid adaptation of the acquired Kenney child skin",
        "loop": "cut-after-hold" if word in ("open", "close") else "continuous",
        "cameraScale": camera.data.ortho_scale,
        "maximumHandContactError": max(contact) if contact else None,
    }
    (directory / "metadata.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    frames = sorted(set([1, count // 4, count // 2, count * 3 // 4, count])) if poses_only else range(1, count + 1)
    if poses_only:
        for frame in frames:
            scene.frame_set(frame)
            scene.render.filepath = str(directory / ("frame-%04d.png" % frame))
            bpy.ops.render.render(write_still=True)
    else:
        bpy.ops.render.render(animation=True)
    print("ANIMATION_COMPLETE", word, len(frames), json.dumps(metadata), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("words", nargs="*", choices=list(STUDIES))
    parser.add_argument("--poses", action="store_true")
    parser.add_argument("--output-dir", type=Path, default=OUT,
                        help="Keep experimental poses separate from accepted full frame sequences.")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    OUT = args.output_dir.resolve()
    OUT.mkdir(parents=True, exist_ok=True)
    for word in args.words or STUDIES:
        render(word, args.poses)
