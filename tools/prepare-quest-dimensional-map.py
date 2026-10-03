"""Render acquired Kenney models into the Talk Quest miniature world map.

Run with Blender in background mode. Geometry and palette textures come from
the original CC0 source archives recorded beside the resulting artwork.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import random
import sys

import bpy
from mathutils import Matrix, Vector


parser = argparse.ArgumentParser()
parser.add_argument("--source", default="C:/uworks/TalkQuest/downloads/map-dimensional")
parser.add_argument("--output", default="C:/uworks/tesisgame/assets/talk_quest/map-dimensional")
parser.add_argument("--levels", default="all")
parser.add_argument("--size", type=int, default=768)
parser.add_argument("--samples", type=int, default=48)
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
source = Path(args.source)
output = Path(args.output)
output.mkdir(parents=True, exist_ok=True)

TOWN = "fantasy-town-kit"
NATURE = "nature-kit"
CASTLE = "castle-kit"
cache = {}
instances = []
used_models = set()


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


clear_scene()
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = args.samples
scene.cycles.use_denoising = True
scene.cycles.max_bounces = 5
scene.cycles.diffuse_bounces = 3
scene.render.resolution_x = args.size
scene.render.resolution_y = args.size
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.image_settings.color_depth = "8"
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.world.color = (0.30, 0.36, 0.45)
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.68, 0.80, 1.0, 1.0)
scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.35

source_collection = bpy.data.collections.new("Acquired source meshes")
scene.collection.children.link(source_collection)
source_collection.hide_render = True


def light(name, position, power, size, color):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = power
    data.shape = "DISK"
    data.size = size
    data.color = color
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.location = position
    obj.rotation_euler = (Vector((0, 0, 1)) - obj.location).to_track_quat("-Z", "Y").to_euler()


light("Warm sky key", (-5, -6, 11), 1450, 4.5, (1.0, 0.85, 0.65))
light("Cool sky fill", (5, 3, 7), 400, 6.0, (0.70, 0.86, 1.0))
camera_data = bpy.data.cameras.new("Isometric miniature camera")
camera = bpy.data.objects.new("Isometric miniature camera", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.type = "ORTHO"
camera_data.ortho_scale = 10.0
camera.location = (10, -14, 12)
camera.rotation_euler = (Vector((0, 0, 1.6)) - camera.location).to_track_quat("-Z", "Y").to_euler()


def load_model(pack, name):
    key = (pack, name)
    used_models.add(f"{pack}/{name}.glb")
    if key in cache:
        return cache[key]
    path = next((source / pack).rglob(name + ".glb"))
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    created = set(bpy.data.objects) - before
    meshes = []
    for obj in created:
        if obj.type != "MESH":
            continue
        mesh = obj.data.copy()
        mesh.transform(obj.matrix_world)
        copy = bpy.data.objects.new(f"Source {pack} {name}", mesh)
        source_collection.objects.link(copy)
        meshes.append(copy)
    for obj in created:
        bpy.data.objects.remove(obj, do_unlink=True)
    points = [v.co for obj in meshes for v in obj.data.vertices]
    minimum = Vector(tuple(min(v[i] for v in points) for i in range(3)))
    maximum = Vector(tuple(max(v[i] for v in points) for i in range(3)))
    cache[key] = (meshes, minimum, maximum)
    return cache[key]


def model(pack, name, x=0, y=0, z=0, scale=1.0, rotation=0, anchor="ground"):
    meshes, minimum, maximum = load_model(pack, name)
    dimensions = scale if isinstance(scale, tuple) else (scale, scale, scale)
    offset = Vector((0, 0, -minimum.z)) if anchor == "ground" else Vector((0, 0, 0))
    transform = Matrix.Translation(Vector((x, y, z))) @ Matrix.Rotation(math.radians(rotation), 4, "Z") @ Matrix.Diagonal((*dimensions, 1)) @ Matrix.Translation(offset)
    for original in meshes:
        obj = original.copy()
        obj.data = original.data
        scene.collection.objects.link(obj)
        obj.matrix_world = transform
        obj.hide_render = False
        instances.append(obj)


def house(x, y, z=1.06, size=1.12, stories=1, roof="roof-gable", angle=0):
    for story in range(stories):
        for side in range(4):
            part = "wall-door" if side == 3 and story == 0 else ("wall-wood-window-glass" if story else "wall-window-shutters")
            model(TOWN, part, x, y, z + story * size, size, angle + side * 90, anchor="origin")
    model(TOWN, roof, x, y, z + size * stories, size, angle, anchor="origin")
    if stories < 3:
        model(TOWN, "chimney", x - size * .24, y + size * .18, z + size * stories + size * .28, size * .5)


def tower(x, y, z=1.07, size=1.0, height=1):
    model(CASTLE, "tower-square-base-color", x, y, z, size)
    for floor in range(height):
        model(CASTLE, "tower-square-mid-windows", x, y, z + size * (floor + 1), size)
    model(CASTLE, "tower-square-top-roof-high-windows", x, y, z + size * (height + 1), size)


def landscape(level):
    rng = random.Random(200 + level)
    model(NATURE, "platform_beach" if level == 11 else "platform_grass", scale=(7.8, 7.8, 14.0), rotation=(level % 3 - 1) * 10)
    for i in range(7):
        a = i * math.tau / 7
        model(NATURE, ["rock_largeA", "rock_largeC", "rock_largeF"][i % 3], math.cos(a) * 2.25, math.sin(a) * 1.9, .12, (.90, .90, 1.5), rotation=i * 47)
    tree_names = ["tree_oak", "tree_detailed", "tree_pineRoundA", "tree_pineTallA"]
    if level in (11,):
        tree_names = ["tree_palmDetailedTall", "tree_palmBend"]
    if level in (8, 12):
        tree_names = ["tree_oak_fall", "tree_detailed_fall", "tree_pineTallA"]
    for i, (x, y) in enumerate([(-2.0, .65), (-1.5, 1.65), (.6, 1.85), (1.75, 1.25)]):
        model(NATURE, tree_names[i % len(tree_names)], x, y, 1.02, rng.uniform(1.05, 1.7), rotation=i * 70)
    for i, (x, y) in enumerate([(-1.9, -.6), (2.1, -.7), (-.9, -1.65), (1.3, -1.55)]):
        model(NATURE, "plant_bushDetailed", x, y, 1.01, .8 + rng.random() * .6, rotation=i * 72)
        model(NATURE, ["flower_purpleC", "flower_yellowC", "flower_redC"][i % 3], x + .25, y - .18, 1.03, 1.1)
    for i in range(3):
        model(NATURE, "path_stone", -.2, -.7 - i * .4, 1.045, .43, 90)


def content(level):
    if level == 1:
        house(-.35, .1, size=1.45, roof="roof-gable")
        model(TOWN, "fence", .85, -1, 1.03, .9)
        model(TOWN, "lantern", .85, -.8, 1.03, .75)
    elif level == 2:
        model(TOWN, "fountain-round-detail", .15, -.15, 1.08, 1.0)
        model(TOWN, "fountain-center", .15, -.15, 1.2, 1.0)
        house(-1.0, 1.0, size=.9, roof="roof-point")
        model(TOWN, "hedge-curved", -1.3, -.8, 1.04, 1.2, 90)
    elif level == 3:
        house(-.2, .35, size=1.25, stories=2, roof="roof-point")
        model(TOWN, "windmill", -.2, -.30, 3.35, .65, 90, anchor="origin")
        model(NATURE, "crops_wheatStageB", 1.2, -.65, 1.07, 1.15)
        model(TOWN, "cart", 1.3, .35, 1.05, .8, 25)
    elif level == 4:
        house(-.35, .35, size=1.10, stories=2, roof="roof-high-point")
        house(.8, .0, size=.85, roof="roof-gable")
        model(TOWN, "stairs-wide-stone-handrail", -.35, -.65, 1.07, .9, 180)
    elif level == 5:
        model(NATURE, "bridge_woodRound", -.2, -.2, 1.05, 1.8, 15)
        model(NATURE, "tree_oak", -.75, 1.0, 1.05, 2.2)
        model(TOWN, "stall-bench", 1.0, -.9, 1.08, 1.1, 10)
        model(NATURE, "mushroom_redGroup", -1.5, -.7, 1.07, 1.3)
    elif level == 6:
        for x, y in [(-.65, -.5), (-.65, .6), (.65, -.5), (.65, .6)]:
            model(TOWN, "pillar-wood", x, y, 1.06, 1.4)
        model(TOWN, "roof-point", 0, .1, 2.45, 1.75)
        model(TOWN, "stall-bench", 0, 0, 1.08, 1.2, 90)
        model(TOWN, "banner-green", .8, -.5, 1.4, .8, 90)
    elif level == 7:
        for i, (x, y) in enumerate([(-1, .2), (.65, .55), (.8, -.9)]):
            model(TOWN, "stall-red" if i % 2 == 0 else "stall-green", x, y, 1.07, 1.35, 0 if i < 2 else 90)
        model(TOWN, "cart-high", -1.1, -1.1, 1.07, .8, 45)
        model(NATURE, "crop_pumpkin", -.85, -.15, 1.75, 1.3)
    elif level == 8:
        house(-.3, .15, size=1.25, stories=2, roof="roof-high-gable")
        tower(.95, .8, size=.72, height=1)
        model(TOWN, "lantern", .8, -1.15, 1.07, .9)
    elif level == 9:
        model(NATURE, "tree_oak", -.2, .4, 1.03, 2.9)
        model(NATURE, "bridge_stoneRoundNarrow", .3, -.65, 1.07, 1.4, 15)
        for x, y in [(-1.3, -.9), (1.3, .1)]:
            model(NATURE, "fence_simple", x, y, 1.07, 1.1, 45)
        model(NATURE, "mushroom_redTall", -.9, .1, 1.07, 1.6)
    elif level == 10:
        model(CASTLE, "wall-doorway", 0, .55, 1.08, 1.7)
        model(CASTLE, "tower-square-top-roof", -.85, .55, 2.9, .9)
        model(CASTLE, "tower-square-top-roof", .85, .55, 2.9, .9)
        model(TOWN, "cart-high", 0, -.7, 1.07, 1.2, 25)
        model(NATURE, "sign", -1.3, -.6, 1.07, 1.2, 25)
    elif level == 11:
        tower(-.5, .6, size=.78, height=0)
        tower(.75, .6, size=.68, height=0)
        model(CASTLE, "wall-doorway", .1, .4, 1.08, .9)
        model(NATURE, "canoe", -.3, -1.2, 1.04, .72, -25)
        model(NATURE, "pot_large", 1.25, -.5, 1.06, 1.3)
    elif level == 12:
        model(NATURE, "tent_detailedOpen", -.55, .05, 1.07, 2.3, 15)
        model(NATURE, "campfire_logs", .85, -.8, 1.07, 1.35)
        model(NATURE, "log_stackLarge", .9, .5, 1.07, 1.2)
        model(TOWN, "lantern", -.9, -1.1, 1.07, .7)
    elif level == 13:
        model(TOWN, "fountain-round", .0, -.2, 1.05, .8)
        house(-.8, .7, size=1.0, roof="roof-point")
        model(TOWN, "stall-red", 1.0, .1, 1.07, 1.15, 90)
        for x, y in [(-1.6, -.5), (.9, -1.25), (.7, 1.2)]:
            model(CASTLE, "flag-pennant", x, y, 1.07, 1.8)
    else:
        tower(-.9, .6, size=.8, height=1)
        tower(.95, .6, size=.8, height=1)
        model(CASTLE, "wall-doorway", 0, .15, 1.07, 1.3)
        tower(0, 1.0, z=1.08, size=.88, height=2)
        model(CASTLE, "bridge-draw", 0, -.75, 1.08, 1.3)
        model(CASTLE, "flag", 0, 1.0, 4.58, 1.0)


def clean_instances():
    for obj in instances:
        bpy.data.objects.remove(obj, do_unlink=True)
    instances.clear()


def render(path):
    bpy.context.view_layer.update()
    inverse = camera.matrix_world.inverted()
    points = [inverse @ (obj.matrix_world @ v.co) for obj in instances for v in obj.data.vertices]
    min_x, max_x = min(p.x for p in points), max(p.x for p in points)
    min_y, max_y = min(p.y for p in points), max(p.y for p in points)
    camera.location += camera.matrix_world.to_quaternion() @ Vector(((min_x + max_x) * .5, (min_y + max_y) * .5, 0))
    camera.data.ortho_scale = max(max_x - min_x, max_y - min_y) * 1.10
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


levels = range(1, 15) if args.levels == "all" else [int(v) for v in args.levels.split(",")]
for level in levels:
    clean_instances()
    landscape(level)
    content(level)
    render(output / f"level-{level:02}.png")

if args.levels == "all":
    for name, pack, asset, scale in [
        ("bridge", NATURE, "bridge_woodRound", 1.0),
        ("flag", CASTLE, "flag-pennant", 1.0),
        ("trail", NATURE, "path_stone", 1.0),
        ("grove", NATURE, "tree_oak", 1.0),
    ]:
        clean_instances()
        model(pack, asset, scale=scale)
        render(output / f"decoration-{name}.png")
    clean_instances()
    model(NATURE, "platform_grass", scale=(7.8, 7.8, 14.0))
    for i, (x, y) in enumerate([(-1.8, 0), (-.8, 1.0), (.6, .7), (1.7, -.2), (-.5, -.6)]):
        model(NATURE, ["tree_pineTallA", "tree_oak", "tree_detailed"][i % 3], x, y, 1.05, 1.6)
    model(NATURE, "rock_largeC", -.5, -1.2, 1.03, 1.0)
    render(output / "decoration-distant-island.png")

(output / "model-usage.json").write_text(json.dumps(sorted(used_models), indent=2) + "\n", encoding="utf-8")
print("DIMENSIONAL_MAP_RENDER_COMPLETE")
