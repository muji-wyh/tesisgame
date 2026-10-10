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
    "walk": (40, "A jaunty planted walk with heel-to-toe steps, generous arm swings and a bright forward-facing grin."),
    "run": (20, "A springy running stride with lifted knees, strong opposing elbows and a delighted open expression."),
    "jump": (64, "An eager deep crouch, joyful open-arm leap, soft two-foot landing and a proud happy finish."),
    "open": (80, "Pull the handle, turn back with a delighted grin and present the open doorway with a generous free-hand gesture."),
    "close": (80, "Push the door shut, turn back with a proud open smile and give a clear pleased nod while retaining the handle."),
    "drink": (80, "Eagerly lift the glass, take a clear sip, then lower it with a closed-eye smile and a pleased hand-to-chest reaction."),
    "eat": (80, "Lift the bread for a bite, then share a contented closed-eye smile with two soft chewing nods."),
    "hello": (72, "A broad palm-led three-beat wave, bright grin and playful delayed head-and-shoulder follow-through."),
}
REVIEW_PHASES = {
    "walk": (0, .125, .25, .375, .5, .625, .75, .875),
    "run": (0, .125, .25, .375, .5, .625, .75, .875),
    "jump": (0, .19, .30, .45, .62, .68, .82, .984),
    "open": (0, .14, .36, .59, .73, .82, .90, .987),
    "close": (0, .14, .36, .59, .73, .82, .90, .987),
    "drink": (0, .10, .29, .46, .62, .75, .84, .987),
    "eat": (0, .10, .29, .46, .62, .75, .84, .987),
    "hello": (0, .12, .25, .35, .45, .55, .70, .85, .986),
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
    rig.pose.bones["Head"].scale = (1.15,) * 3
    bpy.context.view_layer.update()


def shift_hips(rig, dz=0, dy=0, dx=0):
    bone = rig.pose.bones["HipsCtrl"]
    bone.matrix = Matrix.Translation((dx, dy, dz)) @ bone.matrix
    bpy.context.view_layer.update()


def turn_bone(rig, name, angle, axis):
    bone = rig.pose.bones[name]
    pivot = bone.head.copy()
    bone.matrix = Matrix.Translation(pivot) @ Matrix.Rotation(angle, 4, axis) @ Matrix.Translation(-pivot) @ bone.matrix
    bpy.context.view_layer.update()


def cheerful_materials(objects):
    """Keep acquired UVs/materials and key purposeful face states with the action."""
    images = {name: bpy.data.images.load(str(art.SKINS / filename), check_existing=True)
              for name, filename in {"smile": "child-cheerful.png", "delighted": "child-cheerful-delighted.png",
                                     "pleased": "child-cheerful-pleased.png", "blink": "child-cheerful-blink.png"}.items()}
    controls = {name: [] for name in ("delighted", "pleased", "blink")}
    for obj in objects:
        if obj.type != "MESH":
            continue
        for material in obj.data.materials:
            nodes = material.node_tree.nodes
            skin = next(n for n in nodes if n.type == "TEX_IMAGE")
            skin.image = images["smile"]
            previous = skin.outputs["Color"]
            for name in controls:
                expression = nodes.new("ShaderNodeTexImage")
                expression.image = images[name]
                blend = nodes.new("ShaderNodeMixRGB")
                blend.name = "Expression " + name
                blend.inputs[0].default_value = 0
                material.node_tree.links.new(previous, blend.inputs[1])
                material.node_tree.links.new(expression.outputs["Color"], blend.inputs[2])
                previous = blend.outputs[0]
                controls[name].append(blend.inputs[0])
            material.node_tree.links.new(previous, nodes.get("Principled BSDF").inputs["Base Color"])
    return controls


def blink_amount(word, phase):
    # Two- to three-frame blinks accompany a glance or landing rather than
    # repeating at an unrelated global clock across all the word pictures.
    centers = {"walk": (.70,), "run": (), "jump": (.69,), "open": (.13, .78),
               "close": (.12, .79), "drink": (.73,), "eat": (.75,), "hello": (.32, .78)}
    width = .035 if STUDIES[word][0] >= 64 else .045
    return max([1.0 - smooth(abs(phase-center)/width) for center in centers[word]] or [0.0])


def expression_amounts(word, phase):
    """Smiles share the decisive action beat; satisfaction belongs after contact."""
    pleased = 0.0
    if word in ("walk", "run"):
        delighted = (.55 if word == "walk" else .80) + .18 * math.sin(phase * math.tau) ** 2
    elif word == "jump":
        delighted = .15 + .85 * (ramp(phase, .15, .29) - ramp(phase, .68, .85))
        pleased = .72 * (ramp(phase, .73, .80) - ramp(phase, .86, .97))
    elif word in ("open", "close"):
        delighted = .18 + .82 * ramp(phase, .59, .73)
        pleased = .48 * (ramp(phase, .77, .81) - ramp(phase, .84, .90))
    elif word in ("drink", "eat"):
        delighted = .32 * (ramp(phase, .01, .08) - ramp(phase, .26, .34))
        pleased = .95 * (ramp(phase, .68, .75) - ramp(phase, .89, .99))
    else:
        delighted = .15 + .85 * (ramp(phase, .03, .20) - ramp(phase, .81, .98))
    return {"delighted": delighted, "pleased": pleased,
            "blink": blink_amount(word, phase) * (1 - pleased)}


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
    root = art.move_group(objects, yaw=-.38 if word in ("walk", "run") else -.12)
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
        stride = .94 if running else .65
        # The support foot travels back at an even rate; the swing foot clears the floor.
        counter_turn = math.sin(phase * 2 * math.pi)
        shift_hips(rig, (-.09 + .13 * math.cos(phase * 4 * math.pi)) if running else (-.06 + .075 * math.cos(phase * 4 * math.pi)),
                   dx=(.035 if running else .055) * counter_turn)
        turn_bone(rig, "HipsCtrl", -.055 * counter_turn, "Z")
        turn_bone(rig, "Spine", (.17 if running else .13) * counter_turn, "Z")
        turn_bone(rig, "Spine", .11 if running else .035, "X")
        for side, offset, sign in [("Left", 0, 1), ("Right", .5, -1)]:
            p = (phase + offset) % 1
            stance = .38 if running else .60
            if p < stance:
                support = p / stance
                y = -stride + 2 * stride * support
                push = ramp(support, .70, 1)
                z = .20 + (.10 if running else .065) * push
                lift = .08 * (1 - ramp(support, .04, .25)) + .10 * push
            else:
                swing = (p - stance) / (1 - stance)
                y = stride * (1 - 2 * smooth(swing))
                push_release = 1 - ramp(swing, 0, .20)
                heel_prepare = ramp(swing, .80, 1)
                z = .20 + (.85 if running else .39) * math.sin(math.pi * swing) + (.10 if running else .065) * push_release
                lift = .20 * math.sin(math.pi * swing) + .10 * push_release + .08 * heel_prepare
            foot(rig, side, (sign * .23, y + .15, z), lift)
            swing = math.cos((phase + offset) * 2 * math.pi)
            hand(rig, side, (sign * (.49 if running else .65), -.25 + (.62 if running else .46) * swing,
                             (2.09 if running else 1.57) + (.23 if running else .21) * swing),
                 (sign * .16, .35, -1) if running else None)
        if running:
            # The pelvis rises only during the two short unsupported parts of the stride.
            support_phase = phase % .5
            root.location.z = .16 * math.sin((support_phase - .38) / .12 * math.pi) if support_phase > .38 else 0
        art.point(rig, "Head", (.11 * math.sin((phase-.05) * math.tau), -.14, 3.87))
        turn_bone(rig, "Head", -.055 * counter_turn, "Z")
    elif word == "jump":
        anticipation = ramp(phase, .05, .21) - ramp(phase, .23, .34)
        crouch = .39 * (ramp(phase, .05, .22) - ramp(phase, .25, .33))
        landing = .32 * (ramp(phase, .60, .66) - ramp(phase, .68, .80))
        grounded(rig, crouch + landing)
        flight = (phase - .32) / .30
        root.location.z = 1.04 * 4 * flight * (1 - flight) if 0 < flight < 1 else 0
        raise_arm = ramp(phase, .22, .36) - ramp(phase, .61, .80)
        proud = ramp(phase, .77, .85) - ramp(phase, .91, .99)
        turn_bone(rig, "Spine", .12 * anticipation + .08 * landing, "X")
        for side, sign in [("Left", 1), ("Right", -1)]:
            target = mix((sign * .61, -.15 + .38 * anticipation, 1.36),
                         (sign * 1.02, -.15, 3.34), raise_arm)
            target = mix(target, (sign * .74, -.37, 2.05), proud)
            hand(rig, side, target)
            if proud > 0:
                palm = mix((sign * .02, -.02, -.18), (sign * .10, -.11, .10), proud)
                art.point(rig, side + "Hand", target + palm)
            if 0 < flight < 1:
                peak = math.sin(flight * math.pi)
                foot(rig, side, (sign * (.28 + .08 * peak), .15 + .29 * peak, .20 + .28 * peak), .08 * peak)
        art.point(rig, "Head", (.10 * proud, -.07 - .18 * (crouch + landing), 3.88))
        turn_bone(rig, "Head", -.065 * raise_arm + .09 * proud, "X")
    elif word in ("open", "close"):
        motion = ramp(phase, .14, .59)
        effort = math.sin(math.pi * motion)
        pleased = ramp(phase, .61, .77)
        grounded(rig, .055 * effort)
        turn_bone(rig, "Spine", .06 * effort, "X")
        turn_bone(rig, "Spine", .14 * pleased, "Z")
        angle = (-5 - 35 * motion) if word == "open" else (-40 + 35 * motion)
        leaf = extra["leaf"]
        hinge = extra["hinge"]
        leaf.matrix_world = Matrix.Translation(hinge) @ Matrix.Rotation(math.radians(angle), 4, "Z") @ Matrix.Translation(-hinge) @ extra["base"]
        bpy.context.view_layer.update()
        grip_world = leaf.matrix_world @ extra["handle"]
        target = rig.matrix_world.inverted() @ grip_world
        hand(rig, "Left", target)
        art.point(rig, "LeftHand", target + rig.matrix_world.inverted().to_3x3() @ Vector((-.04, -.02, 0)))
        free_hand = mix((-.58, -.13, 1.38),
                        (-.84, .50, 2.30) if word == "open" else (-.64, .24, 2.26), pleased)
        hand(rig, "Right", free_hand)
        art.point(rig, "RightHand", free_hand + mix((0, 0, -.18), (-.14, .08, .12), pleased))
        nod = math.sin(math.pi * (phase-.73)/.17) if .73 < phase < .90 else 0
        art.point(rig, "Head", (.10 * pleased, -.28 + .15 * pleased, 3.82))
        # Look back toward the learner once the doorway state is established;
        # keep the body and gripping hand anchored to the door throughout.
        turn_bone(rig, "Head", 1.06 * pleased, "Z")
        turn_bone(rig, "Head", .14 * nod, "X")
    elif word in ("drink", "eat"):
        anticipation = ramp(phase, .015, .06) - ramp(phase, .08, .15)
        contented = ramp(phase, .66, .75) - ramp(phase, .89, .99)
        grounded(rig, .04 * anticipation)
        turn_bone(rig, "Spine", -.05 * contented, "X")
        turn_bone(rig, "Spine", .07 * contented, "Z")
        lift = ramp(phase, .09, .29) - ramp(phase, .61, .79)
        pivot = extra["held"]
        local = mix((.08, -.64, 1.80), (.04, -.68, 2.72 if word == "drink" else 2.78), lift)
        sip = ramp(phase, .37, .46) - ramp(phase, .55, .63)
        pivot.location = rig.matrix_world @ local
        pivot.rotation_euler = (-(.55 * sip if word == "drink" else .06 * lift), 0, root.rotation_euler.z + .15)
        bpy.context.view_layer.update()
        hand(rig, "Left", rig.matrix_world.inverted() @ (pivot.matrix_world @ Vector((.20, 0, -.08))))
        if word == "eat":
            hand(rig, "Right", rig.matrix_world.inverted() @ (pivot.matrix_world @ Vector((-.20, 0, -.06))))
        reaction_phase = max(0, min(1, (phase - .70) / .25))
        nod = (.11 if word == "eat" else .085) * math.sin(reaction_phase * math.pi * (4 if word == "eat" else 2)) * contented
        art.point(rig, "Head", (.13 * contented, -.04 - .10 * sip, 3.84))
        turn_bone(rig, "Head", nod, "X")
        turn_bone(rig, "Head", -.11 * contented, "Y")
        if word == "drink":
            free_hand = mix((-.58, -.13, 1.38), (-.55, -.32, 1.84), .60 * lift)
            free_hand = mix(free_hand, (-.40, -.48, 2.17), contented)
            hand(rig, "Right", free_hand)
            art.point(rig, "RightHand", free_hand + mix((0, 0, -.18), (.14, -.03, .04), contented))
    elif word == "hello":
        grounded(rig, .065 * (ramp(phase, .04, .12) - ramp(phase, .14, .23)))
        lift = ramp(phase, .055, .22) - ramp(phase, .78, .97)
        wave = math.sin((phase - .23) * math.pi * 10) * (ramp(phase, .22, .31) - ramp(phase, .70, .79))
        follow = math.sin((phase - .27) * math.pi * 10) * (ramp(phase, .24, .33) - ramp(phase, .72, .82))
        turn_bone(rig, "Spine", .07 * follow * lift, "Z")
        turn_bone(rig, "Spine", .045 * lift, "Y")
        target = mix((-.58, -.13, 1.38), (-.95 + .24 * wave, -.25, 3.24), lift)
        hand(rig, "Right", target)
        palm = mix((-.035, -.02, -.19), (-.035 + .19 * wave, -.035, .22), lift)
        art.point(rig, "RightHand", target + palm)
        hand(rig, "Left", mix((.58, -.13, 1.38), (.54, -.35, 1.82), lift))
        art.point(rig, "Head", (.19 * lift + .055 * follow, -.07, 3.84))
        turn_bone(rig, "Head", -.055 * follow * lift, "Z")
    amounts = expression_amounts(word, phase)
    for expression, controls in extra["expressions"].items():
        for control in controls:
            control.default_value = amounts[expression]
    bpy.context.view_layer.update()


def frame_bounds(meshes):
    graph = bpy.context.evaluated_depsgraph_get()
    return [o.evaluated_get(graph).matrix_world @ Vector(c) for o in meshes for c in o.evaluated_get(graph).bound_box]


def render(word, poses_only=False, bake_only=False):
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
        for controls in extra["expressions"].values():
            for control in controls:
                control.keyframe_insert("default_value", frame=frame + 1)
        for bone in rig.pose.bones:
            for prop in ("location", "rotation_quaternion", "scale"):
                bone.keyframe_insert(prop, frame=frame + 1)
        for obj in moving:
            for prop in ("location", "rotation_euler", "scale"):
                obj.keyframe_insert(prop, frame=frame + 1)
        points.extend(frame_bounds(meshes))
        if word in ("open", "close"):
            desired = extra["leaf"].matrix_world @ extra["handle"]
            actual = rig.matrix_world @ rig.pose.bones["LeftHand"].head
            contact.append((actual - desired).length)
        elif word in ("drink", "eat"):
            for side, grip in [("Left", (.20, 0, -.08))] + ([("Right", (-.20, 0, -.06))] if word == "eat" else []):
                desired = extra["held"].matrix_world @ Vector(grip)
                actual = rig.matrix_world @ rig.pose.bones[side + "Hand"].head
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
    # Fit every baked pose, then keep about 14 px of geometric clearance at the
    # 256 px authoring size. This makes face and palm accents larger in tiny cards.
    camera.data.ortho_scale = max(xmax - xmin, ymax - ymin) * 1.12
    # One high, broad shadow source keeps the small illustration grounded without
    # several long shadows competing with the hand and foot silhouettes.
    lights = [o for o in scene.objects if o.type == "LIGHT"]
    for light in lights[1:]:
        light.data.use_shadow = False
    extent = camera.data.ortho_scale / 1.12
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
        "animation": "Locally authored articulated performance with planted contacts, follow-through and event-timed expressions",
        "expression": "Keyed bright grin, delighted open smile, closed-eye pleased smile and blinks adapted from the acquired Kenney child skin",
        "performanceRevision": "expressive-action-2",
        "loop": "cut-after-hold" if word in ("open", "close") else "continuous",
        "cameraScale": camera.data.ortho_scale,
        "maximumHandContactError": max(contact) if contact else None,
    }
    (directory / "metadata.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    if bake_only:
        print("ANIMATION_BAKE_COMPLETE", word, json.dumps(metadata), flush=True)
        return
    frames = sorted(set(1 + min(count - 1, round(phase * count)) for phase in REVIEW_PHASES[word])) if poses_only else range(1, count + 1)
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
    parser.add_argument("--bake-only", action="store_true", help="Save the complete keyed scene and contact metadata without rendering pixels.")
    parser.add_argument("--output-dir", type=Path, default=OUT,
                        help="Keep experimental poses separate from accepted full frame sequences.")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    OUT = args.output_dir.resolve()
    OUT.mkdir(parents=True, exist_ok=True)
    for word in args.words or STUDIES:
        render(word, args.poses, args.bake_only)
