"""Render the remaining household vocabulary from acquired Kenney CC0 meshes."""
import hashlib
import importlib.util
import json
from pathlib import Path

import bpy
from mathutils import Vector

spec = importlib.util.spec_from_file_location("scenes", Path(__file__).with_name("render-scenes.py"))
art = importlib.util.module_from_spec(spec)
spec.loader.exec_module(art)
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/word-art-review/library-source/kenney"
OUT.mkdir(parents=True, exist_ok=True)
PROPS = {"pillow": ("furniture-kit", "pillow", "A soft pillow for resting the head"),
         "fan": ("furniture-kit", "ceilingFan", "An electric fan with turning blades"),
         "pot": ("food-kit", "pot", "A deep cooking pot with two handles")}

files = []
for word, (pack, model, meaning) in PROPS.items():
    art.study.clear()
    objects, group = art.model(pack, model, 3)
    if word in ("pillow", "pot"):
        for obj in objects:
            if obj.type != "MESH":
                continue
            obj.modifiers.clear()
            smooth = obj.modifiers.new("Rounded acquired silhouette", "SUBSURF")
            smooth.levels = smooth.render_levels = 2
            for material in obj.data.materials:
                shader = material.node_tree.nodes.get("Principled BSDF")
                shader.inputs["Roughness"].default_value = .82 if word == "pillow" else .3
                shader.inputs["Coat Weight"].default_value = 0 if word == "pillow" else .14
    center = art.study.setup(objects, word + ".png")
    scene = bpy.context.scene
    if word == "fan":
        scene.camera.location = center + Vector((2.5, -3.5, -4.5))
        art.study.aim(scene.camera, center)
        bpy.ops.object.light_add(type="AREA", location=center + Vector((0, -3, -5)))
        fill = bpy.context.object
        fill.data.energy = 350
        fill.data.shape = "DISK"
        fill.data.size = 4
        art.study.aim(fill, center)
    scene.render.resolution_x = scene.render.resolution_y = 512
    scene.render.filepath = str(OUT / (word + ".png"))
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / (word + ".blend")))
    bpy.ops.render.render(write_still=True)
    variant = "GLTF format" if pack == "furniture-kit" else "GLB format"
    mesh = art.SOURCE / pack / "Models" / variant / (model + ".glb")
    files.append({"id": word, "local": str((OUT / (word + ".png")).relative_to(ROOT)).replace("\\", "/"),
                  "source": {"provider": "kenney-blender", "creator": "Kenney; Grow with Pip (studio adaptation)",
                             "license": "CC0-1.0", "url": "https://kenney.nl/assets/" + pack,
                             "sha256": hashlib.sha256((OUT / (word + ".png")).read_bytes()).hexdigest(),
                             "model": model + ".glb", "modelSha256": hashlib.sha256(mesh.read_bytes()).hexdigest(),
                             "meaning": meaning, "record": "docs/assets/lv3-vocabulary.json",
                             "transformation": "Acquired production mesh with softened surface normals, studio lighting and an isolated teaching composition rendered in Blender."}})
(Path(__file__).with_name("kenney-library-map.json")).write_text(json.dumps({"files": files}, indent=2) + "\n", encoding="utf-8")
