"""Render high-craft 3D miniature Storybook props & biome backdrops from acquired Kenney 3D kits.

Uses Blender 5.3 (EEVEE / Workbench / Cycles) with warm top-left storybook lighting,
soft ambient bounce, subtle rim light, and transparent backgrounds so every rendered
asset matches TesisGame's 3D Atelier chests and 3D Pirate Boss.

All source geometry comes from the user-supplied CC0 Kenney Game Assets All-in-1 3.7.0.
Outputs are saved into assets/images/jelly-campaign/, assets/images/jelly-match/garden/,
and assets/images/jelly-match/sky/, plus a review contact sheet in build/qa/.
"""

import hashlib
import json
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Euler, Vector

ROOT = Path(r"q:\uwork\tesisgame")
KENNEY_3D = Path(r"q:\uwork\Kenney Game Assets All-in-1 3.7.0\3D assets")
KENNEY_SKY = Path(r"q:\uwork\Kenney Game Assets All-in-1 3.7.0\2D assets\Skyboxes\Skyboxes")

OUT_CAMPAIGN = ROOT / "assets" / "images" / "jelly-campaign"
OUT_GARDEN = ROOT / "assets" / "images" / "jelly-match" / "garden"
OUT_SKY = ROOT / "assets" / "images" / "jelly-match" / "sky"
OUT_REVIEW = ROOT / "build" / "qa" / "asset-upgrade-3d"


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def setup_render(width, height, transparent=True, samples=24):
    scene = bpy.context.scene
    # Use Cycles CPU with OpenImageDenoise or EEVEE if available; Cycles CPU at small res with denoising is rock-solid headless!
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_adaptive_sampling = True
    scene.cycles.adaptive_threshold = 0.03
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 4
    scene.cycles.diffuse_bounces = 2
    scene.cycles.glossy_bounces = 2
    scene.cycles.transparent_max_bounces = 4

    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = transparent
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA" if transparent else "RGB"
    scene.render.image_settings.compression = 15

    # Warm storybook AgX / Standard color management (bright, vivid, clean colors)
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.08
    scene.view_settings.gamma = 1.0


def setup_world_light(sky_color=(0.82, 0.90, 0.98), strength=0.65):
    scene = bpy.context.scene
    world = bpy.data.worlds.new("StorybookWorld")
    scene.world = world
    world.use_nodes = True
    nodes = world.node_tree.nodes
    bg = nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (*sky_color, 1.0)
        bg.inputs["Strength"].default_value = strength


def add_storybook_lights(sun_color=(1.0, 0.94, 0.82), sun_energy=3.4, fill_color=(0.76, 0.89, 1.0), fill_energy=1.35):
    # Warm top-left key sun (matches Atelier chests & gel highlights)
    sun_data = bpy.data.lights.new("KeySun", type="SUN")
    sun_data.energy = sun_energy
    sun_data.color = sun_color
    sun_data.angle = math.radians(14.0)
    sun_obj = bpy.data.objects.new("KeySun", sun_data)
    bpy.context.collection.objects.link(sun_obj)
    sun_obj.rotation_euler = Euler((math.radians(46), math.radians(-18), math.radians(-38)), "XYZ")

    # Cool sky fill from right-front
    fill_data = bpy.data.lights.new("SkyFill", type="SUN")
    fill_data.energy = fill_energy
    fill_data.color = fill_color
    fill_data.angle = math.radians(38.0)
    fill_obj = bpy.data.objects.new("SkyFill", fill_data)
    bpy.context.collection.objects.link(fill_obj)
    fill_obj.rotation_euler = Euler((math.radians(62), math.radians(24), math.radians(125)), "XYZ")

    # Gentle back-rim sun to separate miniature silhouettes crisply
    rim_data = bpy.data.lights.new("WarmRim", type="SUN")
    rim_data.energy = 0.95
    rim_data.color = (1.0, 0.96, 0.86)
    rim_data.angle = math.radians(20.0)
    rim_obj = bpy.data.objects.new("WarmRim", rim_data)
    bpy.context.collection.objects.link(rim_obj)
    rim_obj.rotation_euler = Euler((math.radians(32), math.radians(0), math.radians(160)), "XYZ")


def resolve_glb(kit, name):
    for fmt in ("GLB format", "GLTF format"):
        candidate = KENNEY_3D / kit / "Models" / fmt / f"{name}.glb"
        if candidate.exists():
            return candidate
    raise FileNotFoundError(f"Missing GLB: {kit}/{name}")


def polish_materials(objs, roughness_floor=0.45, tint=None):
    visited = set()
    for obj in objs:
        if obj.type != "MESH" or not obj.data:
            continue
        for slot in obj.material_slots:
            mat = slot.material
            if not mat or mat.name in visited:
                continue
            visited.add(mat.name)
            if not mat.use_nodes:
                continue
            nodes = mat.node_tree.nodes
            links = mat.node_tree.links
            bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
            if not bsdf:
                continue
            # Soft miniature clay/matte storybook feel
            rough = bsdf.inputs.get("Roughness")
            if rough and not rough.is_linked:
                rough.default_value = max(roughness_floor, min(0.78, rough.default_value))
            spec = bsdf.inputs.get("Specular IOR Level")
            if spec and not spec.is_linked:
                spec.default_value = 0.35
            if tint is not None:
                bc = bsdf.inputs.get("Base Color")
                if bc:
                    if bc.is_linked:
                        from_sock = bc.links[0].from_socket
                        mix = nodes.new("ShaderNodeMix")
                        mix.data_type = "RGBA"
                        mix.blend_type = "MULTIPLY"
                        mix.inputs["Factor"].default_value = tint[3]
                        mix.inputs["B"].default_value = (tint[0], tint[1], tint[2], 1.0)
                        links.new(from_sock, mix.inputs["A"])
                        links.new(mix.outputs["Result"], bc)
                    else:
                        c = bc.default_value
                        f = tint[3]
                        bc.default_value = (
                            c[0] * (1 - f) + c[0] * tint[0] * f,
                            c[1] * (1 - f) + c[1] * tint[1] * f,
                            c[2] * (1 - f) + c[2] * tint[2] * f,
                            c[3],
                        )


def import_glb(kit, name, location=(0, 0, 0), rotation_deg=(0, 0, 0), scale=1.0, tint=None):
    path = resolve_glb(kit, name)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    created = [o for o in bpy.data.objects if o not in before]
    parent = bpy.data.objects.new(f"Group_{kit}_{name}", None)
    bpy.context.collection.objects.link(parent)
    roots = [o for o in created if o.parent is None]
    for r in roots:
        r.parent = parent
    bpy.context.view_layer.update()
    # Ground-center the imported group on Z=0 and center X/Y
    min_v, max_v = bounds_of(created)
    cx = (min_v.x + max_v.x) * 0.5
    cy = (min_v.y + max_v.y) * 0.5
    cz = min_v.z
    for r in roots:
        r.location -= Vector((cx, cy, cz))
    parent.location = Vector(location)
    parent.rotation_euler = Euler(tuple(math.radians(a) for a in rotation_deg), "XYZ")
    if isinstance(scale, (int, float)):
        parent.scale = Vector((scale, scale, scale))
    else:
        parent.scale = Vector(scale)
    polish_materials(created, tint=tint)
    return parent, created, path


def bounds_of(objs):
    bpy.context.view_layer.update()
    xs, ys, zs = [], [], []
    for o in objs:
        if o.type == "MESH":
            for corner in o.bound_box:
                w = o.matrix_world @ Vector(corner)
                xs.append(w.x)
                ys.append(w.y)
                zs.append(w.z)
    if not xs:
        return Vector((0, 0, 0)), Vector((1, 1, 1))
    return Vector((min(xs), min(ys), min(zs))), Vector((max(xs), max(ys), max(zs)))


def frame_camera(all_meshes, width, height, elevation_deg=15.0, azimuth_deg=0.0, margin=1.10, bottom_flush=False):
    cam_data = bpy.data.cameras.new("StorybookCam")
    cam_data.type = "ORTHO"
    cam_obj = bpy.data.objects.new("StorybookCam", cam_data)
    bpy.context.collection.objects.link(cam_obj)
    bpy.context.scene.camera = cam_obj

    min_v, max_v = bounds_of(all_meshes)
    center = (min_v + max_v) * 0.5

    elev = math.radians(elevation_deg)
    az = math.radians(azimuth_deg)
    dist = 25.0
    cam_dir = Vector((math.sin(az) * math.cos(elev), -math.cos(az) * math.cos(elev), math.sin(elev)))
    cam_obj.location = center + cam_dir * dist
    look = (center - cam_obj.location).normalized()
    cam_obj.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    bpy.context.view_layer.update()

    # Project all 8 corners of every mesh into camera space to fit cleanly without clipping
    inv = cam_obj.matrix_world.inverted()
    proj_x, proj_y = [], []
    for o in all_meshes:
        if o.type == "MESH":
            for c in o.bound_box:
                p = inv @ (o.matrix_world @ Vector(c))
                proj_x.append(p.x)
                proj_y.append(p.y)
    min_x, max_x = min(proj_x), max(proj_x)
    min_y, max_y = min(proj_y), max(proj_y)
    span_x = max(0.01, max_x - min_x)
    span_y = max(0.01, max_y - min_y)

    aspect = width / height
    # In Blender ORTHO camera, ortho_scale corresponds to the LARGER sensor dimension
    if aspect >= 1.0:
        needed_x = span_x * margin
        needed_y = span_y * margin
        ortho = max(needed_x, needed_y * aspect)
        cam_w = ortho
        cam_h = ortho / aspect
    else:
        needed_x = span_x * margin
        needed_y = span_y * margin
        ortho = max(needed_y, needed_x / aspect)
        cam_h = ortho
        cam_w = ortho * aspect

    cam_data.ortho_scale = ortho
    # Shift camera in its local XY so bounds are centered (or bottom-flush for hills/ground)
    shift_x = (min_x + max_x) * 0.5
    if bottom_flush:
        shift_y = min_y + cam_h * 0.5 - span_y * 0.02
    else:
        shift_y = (min_y + max_y) * 0.5
    right = cam_obj.matrix_world.to_3x3() @ Vector((1, 0, 0))
    up = cam_obj.matrix_world.to_3x3() @ Vector((0, 1, 0))
    cam_obj.location += right * shift_x + up * shift_y
    bpy.context.view_layer.update()
    return cam_obj


def add_storybook_island(radius=1.15, depth=0.28, top_color=(0.36, 0.64, 0.34), rim_color=(0.56, 0.42, 0.28)):
    """Give every map diorama a cozy rounded storybook meadow/earth/snow island base so props
    never look like floating objects pasted onto blue sky."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=radius, depth=depth, location=(0, 0, -depth * 0.46))
    base = bpy.context.active_object
    base.scale = (1.0, 0.72, 1.0)
    bpy.ops.object.transform_apply(scale=True)
    bev = base.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.08
    bev.segments = 4
    bpy.ops.object.shade_smooth()
    mat_rim = bpy.data.materials.new("IslandRim")
    mat_rim.use_nodes = True
    bsdf = mat_rim.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rim_color, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.72
    base.data.materials.append(mat_rim)

    bpy.ops.mesh.primitive_cylinder_add(vertices=40, radius=radius * 0.98, depth=0.10, location=(0, 0, -0.02))
    cap = bpy.context.active_object
    cap.scale = (1.0, 0.72, 1.0)
    bpy.ops.object.transform_apply(scale=True)
    bev2 = cap.modifiers.new("Bevel", "BEVEL")
    bev2.width = 0.045
    bev2.segments = 4
    bpy.ops.object.shade_smooth()
    mat_top = bpy.data.materials.new("IslandTop")
    mat_top.use_nodes = True
    bsdf2 = mat_top.node_tree.nodes.get("Principled BSDF")
    bsdf2.inputs["Base Color"].default_value = (*top_color, 1.0)
    bsdf2.inputs["Roughness"].default_value = 0.66
    cap.data.materials.append(mat_top)
    return [base, cap]


def render_diorama(spec):
    clear_scene()
    w, h = spec["size"]
    setup_render(w, h, transparent=True, samples=spec.get("samples", 28))
    setup_world_light(
        sky_color=spec.get("world_color", (0.86, 0.93, 0.99)),
        strength=spec.get("world_strength", 0.72),
    )
    add_storybook_lights(
        sun_color=spec.get("sun_color", (1.0, 0.94, 0.82)),
        sun_energy=spec.get("sun_energy", 3.2),
        fill_color=spec.get("fill_color", (0.78, 0.90, 1.0)),
        fill_energy=spec.get("fill_energy", 1.35),
    )
    all_meshes = []
    used_sources = []
    island = spec.get("island")
    if island:
        all_meshes.extend(add_storybook_island(
            radius=island.get("radius", 1.15),
            depth=island.get("depth", 0.28),
            top_color=island.get("top", (0.36, 0.64, 0.34)),
            rim_color=island.get("rim", (0.56, 0.42, 0.28)),
        ))
    for item in spec["models"]:
        _, created, src_path = import_glb(
            item["kit"],
            item["name"],
            location=item.get("loc", (0, 0, 0)),
            rotation_deg=item.get("rot", (0, 0, 0)),
            scale=item.get("scale", 1.0),
            tint=item.get("tint", None),
        )
        all_meshes.extend(created)
        rel = src_path.relative_to(KENNEY_3D).as_posix()
        if rel not in used_sources:
            used_sources.append(rel)

    frame_camera(
        all_meshes,
        w,
        h,
        elevation_deg=spec.get("elev", 14.0),
        azimuth_deg=spec.get("az", 12.0),
        margin=spec.get("margin", 1.08),
        bottom_flush=spec.get("bottom_flush", False),
    )
    out_path = Path(spec["output"])
    out_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.filepath = str(out_path)
    bpy.ops.render.render(write_still=True)
    data = out_path.read_bytes()
    return {
        "path": out_path.relative_to(ROOT).as_posix(),
        "size": [w, h],
        "bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "sources": used_sources,
    }


DIORAMAS = [
    # --- Garden / Board & Early Chapter Props (grounded on warm storybook miniature islands) ---
    {
        "id": "garden_tree",
        "output": OUT_GARDEN / "tree.png",
        "size": (360, 420),
        "elev": 16.0, "az": 16.0, "margin": 1.06,
        "island": {"radius": 1.32, "depth": 0.30, "top": (0.34, 0.62, 0.32), "rim": (0.54, 0.40, 0.27)},
        "models": [
            {"kit": "Nature Kit", "name": "tree_detailed", "loc": (-0.10, 0.08, 0.0), "rot": (0, 0, 18), "scale": 1.05, "tint": (0.72, 0.92, 0.60, 0.42)},
            {"kit": "Nature Kit", "name": "tree_small", "loc": (0.68, -0.08, 0.0), "rot": (0, 0, -24), "scale": 0.72, "tint": (0.78, 0.95, 0.64, 0.38)},
            {"kit": "Nature Kit", "name": "plant_bushDetailed", "loc": (-0.72, -0.25, 0.0), "rot": (0, 0, 35), "scale": 0.70, "tint": (0.74, 0.90, 0.58, 0.35)},
            {"kit": "Nature Kit", "name": "flower_yellowA", "loc": (0.36, -0.52, 0.0), "rot": (0, 0, 10), "scale": 0.95},
            {"kit": "Nature Kit", "name": "flower_redA", "loc": (-0.32, -0.55, 0.0), "rot": (0, 0, -25), "scale": 0.90},
            {"kit": "Nature Kit", "name": "rock_smallA", "loc": (0.85, -0.35, 0.0), "rot": (0, 0, 12), "scale": 0.55},
        ],
    },
    {
        "id": "garden_tree_long",
        "output": OUT_GARDEN / "tree-long.png",
        "size": (320, 440),
        "elev": 15.0, "az": -14.0, "margin": 1.06,
        "island": {"radius": 1.15, "depth": 0.28, "top": (0.34, 0.60, 0.34), "rim": (0.52, 0.39, 0.26)},
        "models": [
            {"kit": "Nature Kit", "name": "tree_detailed", "loc": (0.0, 0.06, 0.0), "rot": (0, 0, -22), "scale": (0.82, 0.82, 1.18), "tint": (0.66, 0.88, 0.56, 0.45)},
            {"kit": "Nature Kit", "name": "tree_oak", "loc": (0.56, 0.14, 0.0), "rot": (0, 0, 30), "scale": 0.68, "tint": (0.76, 0.94, 0.60, 0.40)},
            {"kit": "Nature Kit", "name": "plant_bushSmall", "loc": (-0.48, -0.28, 0.0), "rot": (0, 0, 15), "scale": 0.78},
            {"kit": "Nature Kit", "name": "flower_purpleA", "loc": (0.28, -0.45, 0.0), "rot": (0, 0, 15), "scale": 0.9},
        ],
    },
    {
        "id": "garden_foliage",
        "output": OUT_GARDEN / "foliage.png",
        "size": (420, 220),
        "elev": 14.0, "az": 6.0, "margin": 1.04, "bottom_flush": True,
        "models": [
            {"kit": "Nature Kit", "name": "plant_bushLarge", "loc": (-0.75, 0.0, 0.0), "rot": (0, 0, 12), "scale": 1.0, "tint": (0.72, 0.90, 0.58, 0.38)},
            {"kit": "Nature Kit", "name": "plant_bushDetailed", "loc": (0.05, -0.15, 0.0), "rot": (0, 0, -25), "scale": 1.15, "tint": (0.74, 0.92, 0.60, 0.38)},
            {"kit": "Nature Kit", "name": "plant_bushSmall", "loc": (0.85, 0.05, 0.0), "rot": (0, 0, 40), "scale": 1.05, "tint": (0.70, 0.88, 0.56, 0.38)},
            {"kit": "Nature Kit", "name": "flower_yellowB", "loc": (-0.35, -0.55, 0.0), "rot": (0, 0, 10), "scale": 1.1},
            {"kit": "Nature Kit", "name": "flower_purpleA", "loc": (0.50, -0.52, 0.0), "rot": (0, 0, -15), "scale": 1.1},
            {"kit": "Nature Kit", "name": "mushroom_redGroup", "loc": (0.12, -0.58, 0.0), "rot": (0, 0, 20), "scale": 0.85},
        ],
    },
    {
        "id": "garden_hills",
        "output": OUT_GARDEN / "hills.png",
        "size": (1024, 340),
        "elev": 12.0, "az": 0.0, "margin": 1.01, "bottom_flush": True,
        "models": [
            {"kit": "Nature Kit", "name": "ground_grass", "loc": (-2.4, 0.2, 0.0), "rot": (0, 0, 0), "scale": (3.2, 1.8, 1.4), "tint": (0.76, 0.92, 0.64, 0.35)},
            {"kit": "Nature Kit", "name": "ground_grass", "loc": (0.0, 0.4, 0.0), "rot": (0, 0, 0), "scale": (3.6, 2.0, 1.8), "tint": (0.76, 0.92, 0.64, 0.35)},
            {"kit": "Nature Kit", "name": "ground_grass", "loc": (2.4, 0.2, 0.0), "rot": (0, 0, 0), "scale": (3.2, 1.8, 1.3), "tint": (0.76, 0.92, 0.64, 0.35)},
            {"kit": "Nature Kit", "name": "plant_bushLarge", "loc": (-2.6, 0.1, 0.05), "rot": (0, 0, 15), "scale": (1.9, 1.3, 1.15), "tint": (0.74, 0.90, 0.60, 0.38)},
            {"kit": "Nature Kit", "name": "plant_bushLarge", "loc": (-1.1, 0.3, 0.05), "rot": (0, 0, -20), "scale": (2.3, 1.4, 1.45), "tint": (0.74, 0.90, 0.60, 0.38)},
            {"kit": "Nature Kit", "name": "plant_bushDetailed", "loc": (0.4, 0.25, 0.05), "rot": (0, 0, 35), "scale": (2.4, 1.4, 1.55), "tint": (0.74, 0.90, 0.60, 0.38)},
            {"kit": "Nature Kit", "name": "plant_bushLarge", "loc": (1.8, 0.15, 0.05), "rot": (0, 0, 10), "scale": (2.1, 1.3, 1.30), "tint": (0.74, 0.90, 0.60, 0.38)},
            {"kit": "Nature Kit", "name": "plant_bushDetailed", "loc": (2.9, 0.05, 0.05), "rot": (0, 0, -30), "scale": (1.7, 1.2, 1.05), "tint": (0.74, 0.90, 0.60, 0.38)},
            {"kit": "Nature Kit", "name": "tree_small", "loc": (-1.9, 0.35, 0.35), "rot": (0, 0, 15), "scale": 0.72, "tint": (0.72, 0.90, 0.58, 0.38)},
            {"kit": "Nature Kit", "name": "tree_detailed", "loc": (1.5, 0.35, 0.38), "rot": (0, 0, -20), "scale": 0.64, "tint": (0.72, 0.90, 0.58, 0.38)},
            {"kit": "Nature Kit", "name": "flower_yellowA", "loc": (-0.65, -0.35, 0.06), "rot": (0, 0, 0), "scale": 0.85},
            {"kit": "Nature Kit", "name": "flower_purpleB", "loc": (0.85, -0.32, 0.06), "rot": (0, 0, 15), "scale": 0.85},
        ],
    },
    # --- 9 Campaign Chapter Landmarks (each grounded on a matching storybook biome island) ---
    {
        "id": "campaign_tree_pine",
        "output": OUT_CAMPAIGN / "tree-pine.png",
        "size": (340, 440),
        "elev": 15.0, "az": 16.0, "margin": 1.06,
        "island": {"radius": 1.25, "depth": 0.30, "top": (0.28, 0.54, 0.34), "rim": (0.48, 0.38, 0.28)},
        "models": [
            {"kit": "Nature Kit", "name": "tree_pineTallA_detailed", "loc": (0.0, 0.05, 0.0), "rot": (0, 0, 14), "scale": 1.0},
            {"kit": "Nature Kit", "name": "tree_pineSmallA", "loc": (-0.65, -0.15, 0.0), "rot": (0, 0, -25), "scale": 0.85},
            {"kit": "Nature Kit", "name": "rock_smallA", "loc": (0.58, -0.28, 0.0), "rot": (0, 0, 22), "scale": 0.72},
            {"kit": "Nature Kit", "name": "mushroom_red", "loc": (-0.28, -0.50, 0.0), "rot": (0, 0, 10), "scale": 0.78},
        ],
    },
    {
        "id": "campaign_cottage",
        "output": OUT_CAMPAIGN / "cottage.png",
        "size": (420, 360),
        "elev": 18.0, "az": 26.0, "margin": 1.07,
        "island": {"radius": 1.65, "depth": 0.32, "top": (0.38, 0.64, 0.34), "rim": (0.55, 0.41, 0.28)},
        "models": [
            {"kit": "Holiday Kit", "name": "cabin-wall", "loc": (0.0, 0.5, 0.0), "rot": (0, 0, 180), "scale": 1.0},
            {"kit": "Holiday Kit", "name": "cabin-wall", "loc": (-0.5, 0.0, 0.0), "rot": (0, 0, -90), "scale": 1.0},
            {"kit": "Holiday Kit", "name": "cabin-wall", "loc": (0.5, 0.0, 0.0), "rot": (0, 0, 90), "scale": 1.0},
            {"kit": "Holiday Kit", "name": "cabin-doorway-center", "loc": (0.0, -0.5, 0.0), "rot": (0, 0, 0), "scale": 1.0},
            {"kit": "Holiday Kit", "name": "cabin-window-b", "loc": (0.52, -0.02, 0.0), "rot": (0, 0, 90), "scale": 1.0},
            {"kit": "Holiday Kit", "name": "cabin-roof-point", "loc": (0.0, 0.0, 0.96), "rot": (0, 0, 0), "scale": (1.18, 1.18, 1.12)},
            {"kit": "Holiday Kit", "name": "cabin-roof-chimney", "loc": (0.26, 0.14, 1.16), "rot": (0, 0, 0), "scale": 0.9},
            {"kit": "Nature Kit", "name": "tree_detailed", "loc": (-1.15, 0.20, 0.0), "rot": (0, 0, 15), "scale": 0.65, "tint": (0.74, 0.92, 0.58, 0.38)},
            {"kit": "Nature Kit", "name": "plant_bushDetailed", "loc": (0.95, -0.30, 0.0), "rot": (0, 0, 20), "scale": 0.68},
            {"kit": "Nature Kit", "name": "flower_redA", "loc": (-0.68, -0.68, 0.0), "rot": (0, 0, 0), "scale": 0.85},
            {"kit": "Nature Kit", "name": "flower_yellowA", "loc": (0.55, -0.72, 0.0), "rot": (0, 0, 12), "scale": 0.85},
        ],
    },
    {
        "id": "campaign_tree_orange",
        "output": OUT_CAMPAIGN / "tree-orange.png",
        "size": (340, 440),
        "elev": 15.0, "az": -15.0, "margin": 1.06,
        "sun_color": (1.0, 0.88, 0.70), "sun_energy": 3.5,
        "island": {"radius": 1.28, "depth": 0.30, "top": (0.76, 0.56, 0.28), "rim": (0.52, 0.36, 0.22)},
        "models": [
            {"kit": "Nature Kit", "name": "tree_detailed_fall", "loc": (-0.05, 0.05, 0.0), "rot": (0, 0, -18), "scale": 1.05},
            {"kit": "Nature Kit", "name": "tree_small_fall", "loc": (0.64, 0.12, 0.0), "rot": (0, 0, 32), "scale": 0.74},
            {"kit": "Nature Kit", "name": "log_stack", "loc": (-0.54, -0.32, 0.0), "rot": (0, 0, 22), "scale": 0.65},
            {"kit": "Nature Kit", "name": "mushroom_tanGroup", "loc": (0.28, -0.48, 0.0), "rot": (0, 0, -10), "scale": 0.78},
        ],
    },
    {
        "id": "campaign_tree_snow",
        "output": OUT_CAMPAIGN / "tree-snow.png",
        "size": (340, 440),
        "elev": 15.0, "az": 15.0, "margin": 1.06,
        "world_color": (0.82, 0.92, 1.0), "sun_color": (0.96, 0.97, 1.0),
        "island": {"radius": 1.24, "depth": 0.30, "top": (0.88, 0.94, 0.98), "rim": (0.56, 0.66, 0.78)},
        "models": [
            {"kit": "Holiday Kit", "name": "tree-snow-a", "loc": (-0.05, 0.05, 0.0), "rot": (0, 0, 12), "scale": 1.10},
            {"kit": "Holiday Kit", "name": "snow-pile", "loc": (-0.45, -0.22, 0.0), "rot": (0, 0, 25), "scale": 0.85},
            {"kit": "Holiday Kit", "name": "snowman-hat", "loc": (0.56, -0.28, 0.0), "rot": (0, 0, -18), "scale": 0.65},
        ],
    },
    {
        "id": "campaign_tree_pine_snow",
        "output": OUT_CAMPAIGN / "tree-pine-snow.png",
        "size": (340, 440),
        "elev": 15.0, "az": -16.0, "margin": 1.06,
        "world_color": (0.80, 0.90, 1.0), "sun_color": (0.94, 0.96, 1.0),
        "island": {"radius": 1.24, "depth": 0.30, "top": (0.84, 0.92, 0.98), "rim": (0.50, 0.60, 0.74)},
        "models": [
            {"kit": "Holiday Kit", "name": "tree-snow-b", "loc": (0.0, 0.05, 0.0), "rot": (0, 0, -15), "scale": 1.12},
            {"kit": "Holiday Kit", "name": "tree-snow-c", "loc": (-0.56, 0.14, 0.0), "rot": (0, 0, 24), "scale": 0.78},
            {"kit": "Holiday Kit", "name": "rocks-small", "loc": (0.48, -0.30, 0.0), "rot": (0, 0, 18), "scale": 0.85},
        ],
    },
    {
        "id": "campaign_tree_palm",
        "output": OUT_CAMPAIGN / "tree-palm.png",
        "size": (400, 440),
        "elev": 15.0, "az": 16.0, "margin": 1.06,
        "sun_color": (1.0, 0.94, 0.78), "sun_energy": 3.5,
        "island": {"radius": 1.38, "depth": 0.30, "top": (0.92, 0.82, 0.56), "rim": (0.34, 0.72, 0.76)},
        "models": [
            {"kit": "Pirate Kit", "name": "palm-detailed-bend", "loc": (-0.15, 0.05, 0.0), "rot": (0, 0, 12), "scale": 1.05},
            {"kit": "Pirate Kit", "name": "palm-detailed-straight", "loc": (0.62, 0.22, 0.0), "rot": (0, 0, -28), "scale": 0.78},
            {"kit": "Pirate Kit", "name": "rocks-sand-a", "loc": (-0.58, -0.25, 0.0), "rot": (0, 0, 20), "scale": 0.85},
            {"kit": "Pirate Kit", "name": "chest", "loc": (0.42, -0.45, 0.0), "rot": (0, 0, -22), "scale": 0.65},
        ],
    },
    {
        "id": "campaign_cactus",
        "output": OUT_CAMPAIGN / "cactus.png",
        "size": (320, 380),
        "elev": 15.0, "az": -18.0, "margin": 1.08,
        "sun_color": (1.0, 0.90, 0.72), "sun_energy": 3.6,
        "island": {"radius": 1.18, "depth": 0.28, "top": (0.86, 0.68, 0.44), "rim": (0.68, 0.46, 0.28)},
        "models": [
            {"kit": "Nature Kit", "name": "cactus_tall", "loc": (0.0, 0.05, 0.0), "rot": (0, 0, 15), "scale": 1.12},
            {"kit": "Nature Kit", "name": "cactus_short", "loc": (0.58, -0.15, 0.0), "rot": (0, 0, -35), "scale": 0.85},
            {"kit": "Nature Kit", "name": "rock_largeB", "loc": (-0.55, 0.20, 0.0), "rot": (0, 0, 12), "scale": 0.62, "tint": (1.0, 0.82, 0.64, 0.55)},
            {"kit": "Nature Kit", "name": "flower_yellowC", "loc": (0.22, -0.42, 0.0), "rot": (0, 0, 0), "scale": 0.85},
        ],
    },
    {
        "id": "campaign_mountains",
        "output": OUT_CAMPAIGN / "mountains.png",
        "size": (800, 380),
        "elev": 10.0, "az": 4.0, "margin": 1.03, "bottom_flush": True,
        "world_color": (0.85, 0.89, 1.0), "sun_color": (1.0, 0.93, 0.85),
        "models": [
            {"kit": "Nature Kit", "name": "rock_tallB", "loc": (-1.75, 0.20, 0.0), "rot": (0, 0, 18), "scale": (1.55, 1.2, 1.65)},
            {"kit": "Nature Kit", "name": "rock_tallA", "loc": (-0.45, 0.55, 0.0), "rot": (0, 0, -14), "scale": (1.85, 1.3, 2.35)},
            {"kit": "Nature Kit", "name": "rock_tallD", "loc": (0.75, 0.45, 0.0), "rot": (0, 0, 32), "scale": (1.70, 1.2, 2.05)},
            {"kit": "Nature Kit", "name": "rock_tallC", "loc": (1.90, 0.15, 0.0), "rot": (0, 0, 165), "scale": (1.45, 1.1, 1.45)},
            {"kit": "Holiday Kit", "name": "snow-pile", "loc": (-0.45, 0.35, 1.55), "rot": (0, 0, 15), "scale": (1.45, 1.0, 1.10)},
            {"kit": "Holiday Kit", "name": "snow-pile", "loc": (0.75, 0.28, 1.35), "rot": (0, 0, -25), "scale": (1.25, 0.9, 0.95)},
            {"kit": "Nature Kit", "name": "tree_pineTallA_detailed", "loc": (-1.15, -0.45, 0.0), "rot": (0, 0, 10), "scale": 0.58},
            {"kit": "Nature Kit", "name": "tree_pineDefaultB", "loc": (1.25, -0.42, 0.0), "rot": (0, 0, -20), "scale": 0.62},
        ],
    },
    {
        "id": "campaign_castle",
        "output": OUT_CAMPAIGN / "castle.png",
        "size": (440, 400),
        "elev": 17.0, "az": 20.0, "margin": 1.06,
        "world_color": (0.90, 0.88, 1.0), "sun_color": (1.0, 0.92, 0.84),
        "island": {"radius": 1.95, "depth": 0.36, "top": (0.42, 0.66, 0.42), "rim": (0.58, 0.54, 0.62)},
        "models": [
            {"kit": "Castle Kit", "name": "gate", "loc": (0.0, -0.55, 0.0), "rot": (0, 0, 0), "scale": 0.95},
            {"kit": "Castle Kit", "name": "wall", "loc": (-0.75, -0.55, 0.0), "rot": (0, 0, 0), "scale": 0.95},
            {"kit": "Castle Kit", "name": "wall", "loc": (0.75, -0.55, 0.0), "rot": (0, 0, 0), "scale": 0.95},
            {"kit": "Castle Kit", "name": "tower-square-base", "loc": (-1.05, -0.35, 0.0), "rot": (0, 0, 0), "scale": 0.95},
            {"kit": "Castle Kit", "name": "tower-square-mid", "loc": (-1.05, -0.35, 0.88), "rot": (0, 0, 0), "scale": 0.95},
            {"kit": "Castle Kit", "name": "tower-square-roof", "loc": (-1.05, -0.35, 1.72), "rot": (0, 0, 0), "scale": 0.95},
            {"kit": "Castle Kit", "name": "tower-square-base", "loc": (1.05, -0.35, 0.0), "rot": (0, 0, 0), "scale": 0.95},
            {"kit": "Castle Kit", "name": "tower-square-mid", "loc": (1.05, -0.35, 0.88), "rot": (0, 0, 0), "scale": 0.95},
            {"kit": "Castle Kit", "name": "tower-square-roof", "loc": (1.05, -0.35, 1.72), "rot": (0, 0, 0), "scale": 0.95},
            {"kit": "Castle Kit", "name": "tower-hexagon-base", "loc": (0.0, 0.35, 0.0), "rot": (0, 0, 0), "scale": 1.05},
            {"kit": "Castle Kit", "name": "tower-hexagon-mid", "loc": (0.0, 0.35, 0.95), "rot": (0, 0, 0), "scale": 1.05},
            {"kit": "Castle Kit", "name": "tower-hexagon-roof", "loc": (0.0, 0.35, 1.85), "rot": (0, 0, 0), "scale": 1.05},
            {"kit": "Castle Kit", "name": "flag-pennant", "loc": (0.0, 0.35, 2.75), "rot": (0, 0, 15), "scale": 0.9},
            {"kit": "Nature Kit", "name": "tree_detailed", "loc": (-1.55, -0.45, 0.0), "rot": (0, 0, 0), "scale": 0.56, "tint": (0.72, 0.90, 0.58, 0.38)},
            {"kit": "Nature Kit", "name": "plant_bushDetailed", "loc": (1.50, -0.48, 0.0), "rot": (0, 0, 22), "scale": 0.62},
        ],
    },
]


def main():
    OUT_REVIEW.mkdir(parents=True, exist_ok=True)
    results = []
    for spec in DIORAMAS:
        print(f"Rendering {spec['id']} -> {spec['output']} ...", flush=True)
        try:
            rec = render_diorama(spec)
            results.append({"id": spec["id"], **rec})
            print(f"  OK {rec['size']} {rec['bytes']} bytes", flush=True)
        except Exception as exc:
            print(f"  FAIL {spec['id']}: {exc}", file=sys.stderr, flush=True)
            raise
    report_path = OUT_REVIEW / "diorama-manifest.json"
    report_path.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    print(f"Done: rendered {len(results)} 3D storybook props -> {report_path}")


if __name__ == "__main__":
    main()
