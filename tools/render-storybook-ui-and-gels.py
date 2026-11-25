"""Render tactile 3D sculpted Jelly World UI Chrome, Map Medallions, Memory Card Backs,
and glossy 2.5D translucent Jelly Gel skins via Blender 5.3 Cycles.

Every rendered asset adheres strictly to runtime contracts:
- Gel skins: 320x320 RGBA, exact rounded-rect silhouette matching center (159.5, 159.5),
  half-extents (148.5, 125.5), corner radius 56, foot at y=285, bright readable center
  for word pictures & labels, luscious wet jelly specular arc & subsurface glow!
- Map Medallions: 160x160 RGBA sculpted gold/ivory stone (stage-open), slate/pewter (stage-locked),
  royal plum & antique gold (stage-boss).
- 9-Slice UI Chrome: symmetrical 128x128 tactile game panels & buttons (parchment, wood-banner,
  emerald primary button, honey-gold button, ivory card, frosted toybox well frame) + Memory card backs.
"""

import hashlib
import json
import math
from pathlib import Path

import bpy
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from mathutils import Euler, Vector

ROOT = Path(r"q:\uwork\tesisgame")
OUT_GELS = ROOT / "assets" / "images" / "jelly-match"
OUT_MAP_UI = ROOT / "assets" / "images" / "ui" / "jelly-map"
OUT_CHROME = ROOT / "assets" / "images" / "ui" / "chrome"
OUT_MEMORY = ROOT / "assets" / "images" / "ui" / "memory"


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def setup_cycles(w, h, samples=32):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_adaptive_sampling = True
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 6
    scene.cycles.diffuse_bounces = 3
    scene.cycles.glossy_bounces = 3
    scene.cycles.transmission_bounces = 4
    scene.render.resolution_x = w
    scene.render.resolution_y = h
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.exposure = 0.05


def add_studio_lights(warmth=1.0):
    scene = bpy.context.scene
    world = bpy.data.worlds.new("UIStudioWorld")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.92, 0.95, 0.99, 1.0)
    bg.inputs["Strength"].default_value = 0.65

    # Soft studio top-left key area light for glossy speculars
    key = bpy.data.lights.new("KeyArea", type="AREA")
    key.shape = "DISK"
    key.size = 3.2
    key.energy = 110.0
    key.color = (1.0, 0.96 if warmth > 0.5 else 0.98, 0.88 if warmth > 0.5 else 1.0)
    key_obj = bpy.data.objects.new("KeyArea", key)
    bpy.context.collection.objects.link(key_obj)
    key_obj.location = Vector((-2.4, -2.6, 3.8))
    key_obj.rotation_euler = (Vector((0, 0, 0)) - key_obj.location).to_track_quat("-Z", "Y").to_euler()

    # Soft bottom-right warm bounce light (subsurface / bottom glow)
    bounce = bpy.data.lights.new("BounceArea", type="AREA")
    bounce.shape = "DISK"
    bounce.size = 3.8
    bounce.energy = 42.0
    bounce.color = (1.0, 0.94, 0.84)
    bounce_obj = bpy.data.objects.new("BounceArea", bounce)
    bpy.context.collection.objects.link(bounce_obj)
    bounce_obj.location = Vector((2.6, -2.2, -1.6))
    bounce_obj.rotation_euler = (Vector((0, 0, 0)) - bounce_obj.location).to_track_quat("-Z", "Y").to_euler()

    # Front soft fill
    fill = bpy.data.lights.new("FrontFill", type="AREA")
    fill.shape = "RECTANGLE"
    fill.size = 5.0
    fill.energy = 32.0
    fill.color = (0.94, 0.98, 1.0)
    fill_obj = bpy.data.objects.new("FrontFill", fill)
    bpy.context.collection.objects.link(fill_obj)
    fill_obj.location = Vector((0.4, -4.5, 1.2))
    fill_obj.rotation_euler = (Vector((0, 0, 0)) - fill_obj.location).to_track_quat("-Z", "Y").to_euler()


def setup_front_ortho_cam(ortho_scale=2.2):
    cam_data = bpy.data.cameras.new("OrthoCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ortho_scale
    cam_obj = bpy.data.objects.new("OrthoCam", cam_data)
    bpy.context.collection.objects.link(cam_obj)
    cam_obj.location = Vector((0.0, -5.0, 0.0))
    cam_obj.rotation_euler = Euler((math.radians(90), 0, 0), "XYZ")
    bpy.context.scene.camera = cam_obj
    return cam_obj


def make_pbr_mat(name, color, roughness=0.32, metallic=0.0, coat=0.0, subsurface=0.0, emission_strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = coat
        bsdf.inputs["Coat Roughness"].default_value = 0.08
    if "Subsurface Weight" in bsdf.inputs:
        bsdf.inputs["Subsurface Weight"].default_value = subsurface
    if emission_strength > 0 and "Emission Strength" in bsdf.inputs:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def make_medallion(out_path: Path, rim_color, face_color, accent_color, metallic_rim=0.55, notches=0):
    clear_scene()
    setup_cycles(160, 160, samples=36)
    add_studio_lights()
    setup_front_ortho_cam(ortho_scale=2.28)

    # Outer sculpted rim torus-disk
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=1.0, depth=0.22, location=(0, 0, 0), rotation=(math.radians(90), 0, 0))
    base = bpy.context.active_object
    bpy.ops.object.modifier_add(type="BEVEL")
    base.modifiers["Bevel"].width = 0.06
    base.modifiers["Bevel"].segments = 5
    bpy.ops.object.shade_smooth()
    base.data.materials.append(make_pbr_mat("RimMat", rim_color, roughness=0.28, metallic=metallic_rim, coat=0.45))

    # Raised beveled outer ring
    bpy.ops.mesh.primitive_torus_add(
        major_segments=64, minor_segments=24, major_radius=0.92, minor_radius=0.095,
        location=(0, -0.07, 0), rotation=(math.radians(90), 0, 0)
    )
    ring = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    ring.data.materials.append(make_pbr_mat("OuterRingMat", rim_color, roughness=0.24, metallic=metallic_rim, coat=0.55))

    # Inner recessed ceramic/parchment face (calm bright center for stage numbers!)
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=0.83, depth=0.14, location=(0, -0.05, 0), rotation=(math.radians(90), 0, 0))
    face = bpy.context.active_object
    bpy.ops.object.modifier_add(type="BEVEL")
    face.modifiers["Bevel"].width = 0.03
    face.modifiers["Bevel"].segments = 4
    bpy.ops.object.shade_smooth()
    face.data.materials.append(make_pbr_mat("FaceMat", face_color, roughness=0.42, metallic=0.0, coat=0.25))

    # Subtle inner accent trim ring
    bpy.ops.mesh.primitive_torus_add(
        major_segments=64, minor_segments=16, major_radius=0.82, minor_radius=0.028,
        location=(0, -0.115, 0), rotation=(math.radians(90), 0, 0)
    )
    trim = bpy.context.active_object
    bpy.ops.object.shade_smooth()
    trim.data.materials.append(make_pbr_mat("AccentMat", accent_color, roughness=0.22, metallic=0.65, coat=0.5))

    # Optional decorative studs / compass notches around the rim (for Boss medallion)
    if notches > 0:
        stud_mat = make_pbr_mat("StudMat", accent_color, roughness=0.20, metallic=0.75, coat=0.6)
        for i in range(notches):
            ang = math.tau * i / notches
            bpy.ops.mesh.primitive_uv_sphere_add(
                segments=16, ring_count=12, radius=0.058,
                location=(math.cos(ang) * 0.92, -0.14, math.sin(ang) * 0.92)
            )
            stud = bpy.context.active_object
            bpy.ops.object.shade_smooth()
            stud.data.materials.append(stud_mat)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.filepath = str(out_path)
    bpy.ops.render.render(write_still=True)


def make_3d_gel_skins():
    """Render a luscious, translucent 3D jelly cushion master and produce the 4 palette skins
    preserving the exact 320x320 rounded-rect alpha contract (center 159.5, half 148.5x125.5, r=56)."""
    clear_scene()
    setup_cycles(640, 640, samples=48)
    add_studio_lights(warmth=1.0)
    setup_front_ortho_cam(ortho_scale=2.16)

    # Create a pillowy beveled rounded-rectangle 3D mesh matching 297:251 aspect (1.0 : 0.845)
    # Using a high-res subdivided cube sculpted into a glossy rounded candy jelly pillow
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
    gel = bpy.context.active_object
    gel.scale = (1.96, 0.62, 1.66)
    bpy.ops.object.transform_apply(scale=True)

    bev = gel.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.34
    bev.segments = 8
    bev.limit_method = "NONE"

    sub = gel.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = 2
    sub.render_levels = 3
    bpy.ops.object.shade_smooth()

    # Glossy translucent candy/jelly shader: coral master (will be hue-shifted into 4 palettes cleanly)
    mat = bpy.data.materials.new("JellyCandyMaster")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    # Warm fruity coral base with bright soft subsurface scatter and glossy clearcoat
    bsdf.inputs["Base Color"].default_value = (0.96, 0.42, 0.38, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.14
    bsdf.inputs["IOR"].default_value = 1.42
    if "Subsurface Weight" in bsdf.inputs:
        bsdf.inputs["Subsurface Weight"].default_value = 0.55
    if "Subsurface Scale" in bsdf.inputs:
        bsdf.inputs["Subsurface Scale"].default_value = 0.25
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = 1.0
        bsdf.inputs["Coat Roughness"].default_value = 0.04
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.72
    gel.data.materials.append(mat)

    # Extra crisp specular softbox upper-left for iconic candy jelly shine
    shine = bpy.data.lights.new("JellyGlint", type="AREA")
    shine.shape = "ELLIPSE"
    shine.size = 0.85
    shine.size_y = 0.36
    shine.energy = 140.0
    shine.color = (1.0, 0.99, 0.96)
    shine_obj = bpy.data.objects.new("JellyGlint", shine)
    bpy.context.collection.objects.link(shine_obj)
    shine_obj.location = Vector((-1.15, -2.1, 1.45))
    shine_obj.rotation_euler = (Vector((-0.3, 0, 0.3)) - shine_obj.location).to_track_quat("-Z", "Y").to_euler()

    # Lower rim translucent backlight (makes bottom of jelly glow like real gummy!)
    glow_l = bpy.data.lights.new("JellyUnderGlow", type="AREA")
    glow_l.shape = "DISK"
    glow_l.size = 1.8
    glow_l.energy = 85.0
    glow_l.color = (1.0, 0.86, 0.78)
    glow_obj = bpy.data.objects.new("JellyUnderGlow", glow_l)
    bpy.context.collection.objects.link(glow_obj)
    glow_obj.location = Vector((0.35, -1.6, -1.75))
    glow_obj.rotation_euler = (Vector((0, 0, -0.2)) - glow_obj.location).to_track_quat("-Z", "Y").to_euler()

    tmp = ROOT / "build" / "qa" / "asset-upgrade-3d" / "gel-master-raw.png"
    tmp.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.filepath = str(tmp)
    bpy.ops.render.render(write_still=True)

    # Post-process into exact 320x320 tile contract with identical rounded-rect silhouette mask
    # and bright calm center reading zone + vivid rim + painted upper-left wet specular pill!
    raw = Image.open(tmp).convert("RGBA")
    bbox = raw.getbbox()
    cropped = raw.crop(bbox)

    # Fit cropped 3D render cleanly into the exact rounded-rectangle span at 4x supersampling
    SS = 4
    W, H = 320 * SS, 320 * SS
    cx, cy = 159.5 * SS, 159.5 * SS
    rx, ry, cr = 148.5 * SS, 125.5 * SS, 56.0 * SS
    x0, y0 = round(cx - rx), round(cy - ry)
    bw, bh = round(rx * 2), round(ry * 2)

    body = cropped.resize((bw, bh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    canvas.paste(body, (x0, y0), body)

    # Build supersampled exact rounded-rectangle alpha mask (guarantees 100% identical alpha across all 4 skins
    # and preserves exact y=285 foot support & x=11..308 width)
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rounded_rectangle((cx - rx, cy - ry, cx + rx, cy + ry), radius=cr, fill=255)

    # Convert to float arrays for clean specular/reading-zone shaping and 4 palette tints
    arr = np.asarray(canvas, dtype=np.float32) / 255.0
    m_arr = np.asarray(mask, dtype=np.float32) / 255.0

    # Normalized local coordinates inside the jelly body [-1..1]
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    nx = (xx - cx) / rx
    ny = (yy - cy) / ry

    # Smooth inner reading zone (keeps word labels & pictures crisp and high-contrast while edges stay juicy!)
    center_x = np.clip(1.0 - np.maximum(0.0, np.abs(nx) - 0.50) / 0.42, 0.0, 1.0)
    center_y = np.clip(1.0 - np.maximum(0.0, np.abs(ny + 0.04) - 0.44) / 0.46, 0.0, 1.0)
    center_w = (center_x * center_x * (3 - 2 * center_x)) * (center_y * center_y * (3 - 2 * center_y))

    # Crisp candy-jelly upper-left wet specular capsule + tiny secondary droplet glint
    glint1 = np.exp(-(((nx + 0.56) * 1.9 + (ny + 0.62) * 1.4) ** 2 * 4.5 + ((nx + 0.56) * -0.9 + (ny + 0.62) * 1.3) ** 2 * 24.0))
    glint2 = np.exp(-(((nx + 0.80) ** 2) * 55.0 + ((ny + 0.34) ** 2) * 42.0))
    # Subtle lower-right gummy subsurface bounce crescent
    subglow = np.exp(-(((nx - 0.32) ** 2) * 2.4 + ((ny - 0.68) ** 2) * 14.0)) * 0.24

    # Extract luminance/shading from the 3D coral render so every palette gets crisp 3D form + saturation
    rgb = arr[..., :3]
    lum = rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114
    # Normalize shading curve to preserve bright sunlit jelly feel
    shade = np.clip((lum - 0.22) / 0.68, 0.0, 1.25)

    # 4 curated pastel-vivid Storybook Jelly palettes (edge_deep, body_mid, center_pastel)
    palettes = {
        "coral": (np.array([0.84, 0.31, 0.32]), np.array([0.98, 0.55, 0.50]), np.array([1.00, 0.84, 0.80])),
        "mint":  (np.array([0.22, 0.64, 0.50]), np.array([0.46, 0.84, 0.68]), np.array([0.82, 0.96, 0.90])),
        "sky":   (np.array([0.24, 0.54, 0.82]), np.array([0.48, 0.78, 0.96]), np.array([0.84, 0.93, 1.00])),
        "lilac": (np.array([0.52, 0.37, 0.76]), np.array([0.74, 0.58, 0.94]), np.array([0.92, 0.86, 0.99])),
    }

    # Distance to edge for rich colored gummy rim
    r_box = np.maximum(np.abs(nx), np.abs(ny))
    rim_w = np.clip((r_box - 0.72) / 0.28, 0.0, 1.0)
    rim_w = rim_w * rim_w * (3 - 2 * rim_w)

    for name, (c_deep, c_mid, c_light) in palettes.items():
        # Blend deep -> mid -> light using 3D Cycles shading + center reading mask
        t_mid = np.clip(shade, 0.0, 1.0)[..., None]
        col = c_deep * (1.0 - t_mid) + c_mid * t_mid
        # Soften reading center gently toward creamy pastel tint (keeps dark word labels super legible)
        col = col * (1.0 - center_w[..., None] * 0.44) + c_light * (center_w[..., None] * 0.44)
        # Deepen outer candy rim slightly so jelly tiles separate cleanly on the board
        col = col * (1.0 - rim_w[..., None] * 0.24) + c_deep * (rim_w[..., None] * 0.24)
        # Add subsurface lower-right warm glow
        col = np.clip(col + subglow[..., None] * (c_light * 0.7 + 0.3), 0.0, 1.0)
        # Add crisp glossy top-left specular pills (preserved cleanly through hue-shift shader!)
        spec = np.clip(glint1 * 0.72 + glint2 * 0.55 + np.maximum(0.0, shade - 0.96) * 0.45, 0.0, 0.85)[..., None]
        col = col * (1.0 - spec) + np.array([1.0, 0.995, 0.985]) * spec

        out_rgba = np.zeros((H, W, 4), dtype=np.uint8)
        out_rgba[..., :3] = np.clip(col * 255.0, 0, 255).astype(np.uint8)
        out_rgba[..., 3] = np.clip(m_arr * 255.0, 0, 255).astype(np.uint8)

        im_hi = Image.fromarray(out_rgba, mode="RGBA")
        # Premultiplied-alpha Lanczos downsample to crisp 320x320
        im_out = im_hi.convert("RGBa").resize((320, 320), Image.Resampling.LANCZOS).convert("RGBA")
        dest = OUT_GELS / f"gel-{name}.png"
        im_out.save(dest, optimize=True)
        print(f"  Gel {name}: {dest.stat().st_size // 1024} KB", flush=True)


def make_chrome_assets():
    """Generate crisp 9-slice Storybook UI chrome panels, buttons, well-frame & Memory card backs."""
    OUT_CHROME.mkdir(parents=True, exist_ok=True)
    OUT_MEMORY.mkdir(parents=True, exist_ok=True)

    # Helper to draw supersampled tactile 9-slice rounded wooden/ceramic/glossy UI textures
    def build_panel(dest: Path, size, fill_top, fill_bot, border_outer, border_inner, radius, lip_h=8, highlight_a=120, studs=False):
        SS = 2
        W, H = size[0] * SS, size[1] * SS
        r = radius * SS
        lip = lip_h * SS
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        # Soft drop shadow under panel
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle((4*SS, 5*SS, W-4*SS-1, H-2*SS-1), radius=r, fill=(32, 46, 40, 62))
        sh = sh.filter(ImageFilter.GaussianBlur(3.2 * SS))
        im = Image.alpha_composite(im, sh)

        # Outer 3D bottom-bevel rim
        d = ImageDraw.Draw(im)
        d.rounded_rectangle((3*SS, 3*SS, W-3*SS-1, H-4*SS-1), radius=r, fill=border_outer)
        # Main vertical gradient face inside outer rim
        face_rect = (3*SS + 3*SS, 3*SS + 2*SS, W - 6*SS - 1, H - 4*SS - lip - 1)
        grad = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        gd = ImageDraw.Draw(grad)
        y0, y1 = face_rect[1], face_rect[3]
        for y in range(y0, y1 + 1):
            t = (y - y0) / max(1, y1 - y0)
            c = tuple(round(fill_top[i] * (1 - t) + fill_bot[i] * t) for i in range(3)) + (255,)
            gd.line([(face_rect[0], y), (face_rect[2], y)], fill=c)
        fmask = Image.new("L", (W, H), 0)
        ImageDraw.Draw(fmask).rounded_rectangle(face_rect, radius=max(4, r - 4*SS), fill=255)
        grad.putalpha(fmask)
        im = Image.alpha_composite(im, grad)

        # Inner highlight rim along top edge (tactile glassy/ceramic bevel)
        hl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        hd = ImageDraw.Draw(hl)
        hd.rounded_rectangle(
            (face_rect[0] + 2*SS, face_rect[1] + 2*SS, face_rect[2] - 2*SS, face_rect[1] + max(10*SS, (y1 - y0) // 4)),
            radius=max(4, r - 6*SS),
            fill=(255, 255, 250, highlight_a),
        )
        hl = hl.filter(ImageFilter.GaussianBlur(2.0 * SS))
        # Clip highlight strictly inside face
        hl_arr = np.asarray(hl, dtype=np.float32)
        hl_arr[..., 3] *= np.asarray(fmask, dtype=np.float32) / 255.0
        im = Image.alpha_composite(im, Image.fromarray(hl_arr.astype(np.uint8), "RGBA"))

        # Fine inner stitch/trim border
        trim = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(trim).rounded_rectangle(
            (face_rect[0] + 2*SS, face_rect[1] + 2*SS, face_rect[2] - 2*SS, face_rect[3] - 2*SS),
            radius=max(4, r - 5*SS),
            outline=border_inner,
            width=2 * SS,
        )
        im = Image.alpha_composite(im, trim)

        # Optional corner antique brass studs (for parchment & chapter banners)
        if studs:
            sd = ImageDraw.Draw(im)
            off = 13 * SS
            for sx, sy in [(off, off), (W - off, off), (off, H - off - lip // 2), (W - off, H - off - lip // 2)]:
                sd.ellipse((sx - 3.5*SS, sy - 3.5*SS, sx + 3.5*SS, sy + 3.5*SS), fill=border_outer)
                sd.ellipse((sx - 2.2*SS, sy - 2.5*SS, sx + 1.8*SS, sy + 1.5*SS), fill=(255, 244, 206, 230))

        out = im.convert("RGBa").resize(size, Image.Resampling.LANCZOS).convert("RGBA")
        out.save(dest, optimize=True)
        print(f"  Chrome {dest.name}: {dest.stat().st_size // 1024} KB", flush=True)

    # 9-slice UI panels & buttons (128x128 or 128x96)
    build_panel(OUT_CHROME / "panel-parchment.png", (128, 128),
                (255, 252, 242), (245, 237, 218), (156, 120, 74, 255), (218, 194, 152, 200),
                radius=22, lip_h=5, highlight_a=90, studs=False)
    build_panel(OUT_CHROME / "panel-card.png", (128, 128),
                (255, 254, 249), (248, 244, 234), (188, 199, 184, 255), (255, 255, 255, 190),
                radius=18, lip_h=4, highlight_a=85, studs=False)
    build_panel(OUT_CHROME / "banner-chapter.png", (160, 80),
                (255, 249, 232), (244, 229, 196), (148, 102, 52, 255), (218, 174, 104, 230),
                radius=18, lip_h=5, highlight_a=100, studs=False)
    build_panel(OUT_CHROME / "btn-primary.png", (128, 84),
                (72, 162, 126), (48, 122, 95), (32, 86, 66, 255), (146, 222, 188, 145),
                radius=18, lip_h=6, highlight_a=95)
    build_panel(OUT_CHROME / "btn-primary-hover.png", (128, 84),
                (86, 178, 140), (56, 136, 106), (36, 94, 72, 255), (170, 236, 204, 165),
                radius=18, lip_h=6, highlight_a=120)
    build_panel(OUT_CHROME / "btn-primary-pressed.png", (128, 84),
                (52, 126, 98), (44, 108, 84), (30, 80, 62, 255), (120, 194, 162, 110),
                radius=18, lip_h=2, highlight_a=45)
    build_panel(OUT_CHROME / "btn-gold.png", (128, 84),
                (255, 218, 110), (235, 176, 64), (166, 108, 30, 255), (255, 242, 184, 185),
                radius=18, lip_h=6, highlight_a=130)
    build_panel(OUT_CHROME / "btn-gold-hover.png", (128, 84),
                (255, 228, 134), (244, 190, 82), (176, 118, 36, 255), (255, 248, 206, 205),
                radius=18, lip_h=6, highlight_a=150)
    build_panel(OUT_CHROME / "btn-secondary.png", (128, 84),
                (255, 253, 247), (242, 238, 226), (174, 184, 168, 255), (255, 255, 255, 220),
                radius=18, lip_h=5, highlight_a=110)
    build_panel(OUT_CHROME / "btn-secondary-hover.png", (128, 84),
                (244, 252, 246), (228, 244, 234), (122, 168, 146, 255), (255, 255, 255, 230),
                radius=18, lip_h=5, highlight_a=130)
    build_panel(OUT_CHROME / "btn-secondary-pressed.png", (128, 84),
                (226, 240, 232), (214, 232, 222), (96, 146, 124, 255), (240, 250, 245, 160),
                radius=18, lip_h=2, highlight_a=55)

    # Frosted toybox well frame (transparent hollow interior so cloud well shines through!)
    SS = 2
    W, H = 128 * SS, 128 * SS
    wf = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wd = ImageDraw.Draw(wf)
    # Warm ivory-oak outer frame + soft inner rim shadow, hollow center
    wd.rounded_rectangle((2*SS, 2*SS, W-2*SS-1, H-2*SS-1), radius=20*SS, fill=(144, 112, 74, 225))
    wd.rounded_rectangle((5*SS, 4*SS, W-5*SS-1, H-6*SS-1), radius=17*SS, fill=(232, 206, 164, 240))
    wd.rounded_rectangle((8*SS, 7*SS, W-8*SS-1, H-9*SS-1), radius=14*SS, fill=(176, 146, 102, 230))
    # Punch hollow transparent center
    hole = Image.new("L", (W, H), 255)
    ImageDraw.Draw(hole).rounded_rectangle((11*SS, 11*SS, W-11*SS-1, H-11*SS-1), radius=12*SS, fill=0)
    wf_arr = np.asarray(wf, dtype=np.float32)
    wf_arr[..., 3] *= np.asarray(hole, dtype=np.float32) / 255.0
    wf_out = Image.fromarray(wf_arr.astype(np.uint8), "RGBA").convert("RGBa").resize((128, 128), Image.Resampling.LANCZOS).convert("RGBA")
    wf_out.save(OUT_CHROME / "well-frame.png", optimize=True)
    print(f"  Chrome well-frame.png: {(OUT_CHROME / 'well-frame.png').stat().st_size // 1024} KB", flush=True)

    # Storybook Memory Card Backs (word-back & picture-back, 160x200 ornate patterned cards)
    def build_card_back(dest: Path, bg_top, bg_bot, frame_col, motif_col, star_col):
        SS = 2
        W, H = 160 * SS, 200 * SS
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        # Base card + border
        d.rounded_rectangle((2*SS, 2*SS, W-2*SS-1, H-2*SS-1), radius=18*SS, fill=frame_col)
        # Gradient body
        grad = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        gd = ImageDraw.Draw(grad)
        for y in range(6*SS, H - 8*SS):
            t = (y - 6*SS) / max(1, H - 14*SS)
            c = tuple(round(bg_top[i]*(1-t) + bg_bot[i]*t) for i in range(3)) + (255,)
            gd.line([(6*SS, y), (W - 6*SS, y)], fill=c)
        cmask = Image.new("L", (W, H), 0)
        ImageDraw.Draw(cmask).rounded_rectangle((6*SS, 6*SS, W-6*SS-1, H-8*SS-1), radius=14*SS, fill=255)
        grad.putalpha(cmask)
        im = Image.alpha_composite(im, grad)

        # Subtle quilted storybook diamond lattice inside
        pat = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        pd = ImageDraw.Draw(pat)
        step = 20 * SS
        for x in range(-H, W + H, step):
            pd.line([(x, 0), (x + H, H)], fill=motif_col, width=2*SS)
            pd.line([(x, H), (x + H, 0)], fill=motif_col, width=2*SS)
        pmask = Image.new("L", (W, H), 0)
        ImageDraw.Draw(pmask).rounded_rectangle((14*SS, 14*SS, W-14*SS-1, H-16*SS-1), radius=10*SS, fill=255)
        pat_arr = np.asarray(pat, dtype=np.float32)
        pat_arr[..., 3] *= np.asarray(pmask, dtype=np.float32) / 255.0
        im = Image.alpha_composite(im, Image.fromarray(pat_arr.astype(np.uint8), "RGBA"))

        # Ornate double gold/cream inner frame & corner stars
        fd = ImageDraw.Draw(im)
        fd.rounded_rectangle((12*SS, 12*SS, W-12*SS-1, H-14*SS-1), radius=11*SS, outline=star_col, width=2*SS)
        fd.rounded_rectangle((17*SS, 17*SS, W-17*SS-1, H-19*SS-1), radius=8*SS, outline=(star_col[0], star_col[1], star_col[2], 120), width=1*SS)
        for cx_s, cy_s in [(26*SS, 26*SS), (W-26*SS, 26*SS), (26*SS, H-28*SS), (W-26*SS, H-28*SS)]:
            fd.polygon([(cx_s, cy_s-5*SS), (cx_s+4*SS, cy_s), (cx_s, cy_s+5*SS), (cx_s-4*SS, cy_s)], fill=star_col)

        out = im.convert("RGBa").resize((160, 200), Image.Resampling.LANCZOS).convert("RGBA")
        out.save(dest, optimize=True)
        print(f"  Memory {dest.name}: {dest.stat().st_size // 1024} KB", flush=True)

    build_card_back(OUT_MEMORY / "card-back-picture.png",
                    (66, 134, 112), (44, 102, 86), (32, 76, 64, 255),
                    (255, 248, 224, 28), (246, 214, 136, 225))
    build_card_back(OUT_MEMORY / "card-back-word.png",
                    (255, 250, 238), (242, 232, 210), (176, 146, 98, 255),
                    (176, 146, 98, 26), (196, 152, 86, 210))


def main():
    print("=== 1. Rendering 3D Sculpted Map Medallions ===")
    make_medallion(OUT_MAP_UI / "stage-open.png",
                   rim_color=(0.86, 0.64, 0.28), face_color=(0.99, 0.96, 0.88), accent_color=(0.95, 0.78, 0.36), metallic_rim=0.58)
    make_medallion(OUT_MAP_UI / "stage-locked.png",
                   rim_color=(0.45, 0.54, 0.62), face_color=(0.56, 0.65, 0.72), accent_color=(0.70, 0.78, 0.84), metallic_rim=0.45)
    make_medallion(OUT_MAP_UI / "stage-boss.png",
                   rim_color=(0.82, 0.58, 0.22), face_color=(0.46, 0.26, 0.58), accent_color=(0.98, 0.80, 0.34), metallic_rim=0.72, notches=8)

    print("=== 2. Rendering 3D Glossy Translucent Gel Skins (4 Palettes) ===")
    make_3d_gel_skins()

    print("=== 3. Building 9-Slice Storybook UI Chrome & Memory Card Backs ===")
    make_chrome_assets()
    print("ALL 3D UI & GEL ASSETS COMPLETE.")


if __name__ == "__main__":
    main()
