#!/usr/bin/env python3
"""Bake downloaded chest meshes into small, transparent runtime opening sequences.

The verified Unity prefab exports under TalkQuest retain source geometry, materials,
texture mapping and transform hierarchy. No downloaded scripts are executed. Run
Blender with --background --factory-startup --disable-autoexec --python this-file
-- --render, then run Python this-file --pack. Pass --source-root to relocate the
existing TalkQuest archive and verified review exports.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/chests/downloaded"
WORK = ROOT / "build/chest-bakes"
DEFAULT_SOURCE = Path(r"C:\uworks\TalkQuest")
FRAME_SIZE = 320
STYLES = {
    "harvest": {"label": "Harvest Wood", "source": "casual-chests", "folder": "chest-prefab-previews/chest-t3", "manifest": "chest-prefab-previews.json", "method": "Source openT3 clip sampled by Unity", "existing": "opening-*.png"},
    "tide": {"label": "Tide Blue", "source": "low-poly-chest-animated", "folder": "additional-chest-previews/low-poly-blue", "manifest": "additional-chest-previews.json", "method": "Opening half of source Chest_Open_Close clip sampled by Unity", "existing": "sample-0[0-6].png"},
    "nebula": {"label": "Nebula Vault", "source": "stylized-chests", "folder": "chest-prefab-previews/epic-chest", "manifest": "chest-prefab-previews.json", "method": "Authored magnetic lid lift using original separate lid mesh", "direction": [1.2, 1.8, 1.1]},
    "bramble": {"label": "Bramble Chest", "source": "poly-style-fantasy-chest", "folder": "additional-chest-previews/poly-style-3a", "manifest": "additional-chest-previews.json", "method": "Authored hinge rotation using original separate lid and source pivot", "direction": [1.2, -1.8, 1.1]},
    "bonbon": {"label": "Bonbon Barrel", "source": "poly-style-fantasy-chest", "folder": "additional-chest-previews/poly-style-2a", "manifest": "additional-chest-previews.json", "method": "Authored hinge rotation using original separate lid and source pivot", "direction": [1.2, -1.8, 1.1]},
}

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))

def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")

def transformed_geometry(entry):
    from mathutils import Matrix, Vector
    conversion=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
    transform=conversion @ Matrix([entry["matrix"][r*4:r*4+4] for r in range(4)])
    normal_matrix=transform.to_3x3().inverted().transposed()
    vertices=[transform @ Vector((v["x"],v["y"],v["z"])) for v in entry["vertices"]]
    normals=[(normal_matrix @ Vector((v["x"],v["y"],v["z"]))).normalized() for v in entry["normals"]]
    return vertices,normals


def render_monster(document,exported,path,animation=False,union=None,camera_direction=(0.75,-2,0.65)):
    import bpy
    from mathutils import Vector
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    scene.cycles.device="CPU"
    scene.cycles.samples=12
    scene.cycles.use_denoising=True
    scene.render.threads_mode="FIXED"
    scene.render.threads=4
    scene.render.resolution_x=320
    scene.render.resolution_y=320
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.render.image_settings.color_mode="RGBA"
    scene.render.film_transparent=True
    scene.view_settings.view_transform="Standard"
    scene.view_settings.look="None"
    world=bpy.data.worlds.new("Review World")
    world.use_nodes=True
    world.node_tree.nodes["Background"].inputs["Color"].default_value=(0.82,0.88,1,1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value=0.55
    scene.world=world
    material_cache={}
    all_vertices=[]
    for entry in exported["meshes"]:
        vertices,normals=transformed_geometry(entry)
        all_vertices.extend(vertices)
        faces,indices=[],[]
        for slot,sub in enumerate(entry["submeshes"]):
            for i in range(0,len(sub["indices"]),3):
                face=sub["indices"][i:i+3]
                a,b,c=face
                if (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).dot(normals[a]+normals[b]+normals[c])<0:
                    face=[a,c,b]
                faces.append(face)
                indices.append(slot)
        mesh=bpy.data.meshes.new(entry["meshName"])
        mesh.from_pydata(vertices,[],faces)
        mesh.update()
        obj=bpy.data.objects.new(entry["name"],mesh)
        scene.collection.objects.link(obj)
        uv=mesh.uv_layers.new(name="Source UV")
        for polygon,slot in zip(mesh.polygons,indices):
            polygon.material_index=slot
            polygon.use_smooth=True
            for loop in polygon.loop_indices:
                source_uv=entry["uv"][mesh.loops[loop].vertex_index]
                uv.data[loop].uv=(source_uv["x"],source_uv["y"])
        mesh.normals_split_custom_set_from_vertices(normals)
        for info in entry["materials"]:
            if info["guid"] not in material_cache:
                material=bpy.data.materials.new(info["name"])
                material.use_nodes=True
                nodes=material.node_tree.nodes
                nodes.clear()
                links=material.node_tree.links
                out=nodes.new("ShaderNodeOutputMaterial")
                shader=nodes.new("ShaderNodeBsdfPrincipled")
                links.new(shader.outputs["BSDF"],out.inputs["Surface"])
                shader.inputs["Base Color"].default_value=info["linearColor"]
                shader.inputs["Metallic"].default_value=info["metallic"]
                shader.inputs["Roughness"].default_value=max(0.08,1-info["smoothness"])
                if info["texturePath"]:
                    tex=nodes.new("ShaderNodeTexImage")
                    tex.image=bpy.data.images.load(document["texture_files"][info["texturePath"]],check_existing=True)
                    uv_map=nodes.new("ShaderNodeTexCoord")
                    scale=nodes.new("ShaderNodeVectorMath")
                    scale.operation="MULTIPLY_ADD"
                    scale.inputs[1].default_value=(*info["textureScale"],1)
                    scale.inputs[2].default_value=(*info["textureOffset"],0)
                    links.new(uv_map.outputs["UV"],scale.inputs[0])
                    links.new(scale.outputs["Vector"],tex.inputs["Vector"])
                    multiply=nodes.new("ShaderNodeMixRGB")
                    multiply.blend_type="MULTIPLY"
                    multiply.inputs[0].default_value=1
                    multiply.inputs[2].default_value=info["linearColor"]
                    links.new(tex.outputs["Color"],multiply.inputs[1])
                    links.new(multiply.outputs[0],shader.inputs["Base Color"])
                    if info["mode"]==1:
                        threshold=nodes.new("ShaderNodeMath")
                        threshold.operation="GREATER_THAN"
                        threshold.inputs[1].default_value=info["cutoff"]
                        links.new(tex.outputs["Alpha"],threshold.inputs[0])
                        links.new(threshold.outputs[0],shader.inputs["Alpha"])
                if info["metallicMapEnabled"] and info["metallicTexturePath"]:
                    tex=nodes.new("ShaderNodeTexImage")
                    tex.image=bpy.data.images.load(document["texture_files"][info["metallicTexturePath"]],check_existing=True)
                    tex.image.colorspace_settings.name="Non-Color"
                    split=nodes.new("ShaderNodeSeparateColor")
                    links.new(tex.outputs["Color"],split.inputs["Color"])
                    links.new(split.outputs["Red"],shader.inputs["Metallic"])
                    smooth=nodes.new("ShaderNodeMath")
                    smooth.operation="MULTIPLY"
                    smooth.inputs[1].default_value=info["glossMapScale"]
                    links.new(tex.outputs["Alpha"],smooth.inputs[0])
                    rough=nodes.new("ShaderNodeMath")
                    rough.operation="SUBTRACT"
                    rough.inputs[0].default_value=1
                    links.new(smooth.outputs[0],rough.inputs[1])
                    links.new(rough.outputs[0],shader.inputs["Roughness"])
                material_cache[info["guid"]]=material
            mesh.materials.append(material_cache[info["guid"]])
    vertices=union or all_vertices
    low=Vector(tuple(min(v[i] for v in vertices) for i in range(3)))
    high=Vector(tuple(max(v[i] for v in vertices) for i in range(3)))
    center=(low+high)/2
    size=(high-low).length
    def aim(obj):
        obj.rotation_euler=(center-obj.location).to_track_quat("-Z","Y").to_euler()
    for name,light_direction,power in [("Key",(-3,-4,5),95),("Fill",(4,-2,3),60),("Rim",(1,4,4),85)]:
        light_data=bpy.data.lights.new(name,"AREA")
        light_data.energy=power*size*size
        light_data.shape="DISK"
        light_data.size=size*2
        light=bpy.data.objects.new(name,light_data)
        scene.collection.objects.link(light)
        light.location=center+Vector(light_direction)*size
        aim(light)
    camera_data=bpy.data.cameras.new("Review Camera")
    camera=bpy.data.objects.new("Review Camera",camera_data)
    scene.collection.objects.link(camera)
    camera.location=center+Vector(camera_direction).normalized()*size*3
    aim(camera)
    camera_data.type="ORTHO"
    camera_data.clip_start=0.001
    camera_data.clip_end=10000
    screen=[camera.rotation_euler.to_matrix().transposed()@(v-center) for v in vertices]
    camera_data.ortho_scale=max(max(v.x for v in screen)-min(v.x for v in screen),max(v.y for v in screen)-min(v.y for v in screen))*1.22
    scene.camera=camera
    scene.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)
    return {"mesh_count":len(exported["meshes"]),"vertices":sum(len(m["vertices"]) for m in exported["meshes"]),"triangles":sum(sum(len(s["indices"])//3 for s in m["submeshes"]) for m in exported["meshes"]),"material_guids":list(material_cache)}


def sampled_pose(original, style, progress):
    from mathutils import Matrix, Vector
    frame = {**original, "meshes": [dict(mesh) for mesh in original["meshes"]]}
    for mesh in frame["meshes"]:
        matrix = Matrix([mesh["matrix"][r * 4:r * 4 + 4] for r in range(4)])
        if style == "nebula" and mesh["name"] == "Cube.023":
            # Its separate source cover translates as a rigid magnetic lid.
            matrix = Matrix.Translation(Vector((0, progress * 1.25 - 0.10, 0))) @ matrix
        elif mesh["name"].startswith("Opened_"):
            # The publisher's rest prefab has a 60-degree open lid; the source
            # origin is its real hinge. Preserve the pivot and scale.
            location, rotation, scale = matrix.decompose()
            matrix = Matrix.Translation(location) @ Matrix.Rotation(math.radians(60) * progress, 4, "X") @ Matrix.Diagonal((*scale, 1))
        mesh["matrix"] = [matrix[r][c] for r in range(4) for c in range(4)]
    return frame


def render(source_root):
    for style, config in STYLES.items():
        if "existing" in config:
            continue
        document = read(source_root / "processing" / config["manifest"])
        original = read(source_root / "asset-review/media" / config["folder"] / "rest.json")
        frames = [sampled_pose(original, style, i / 8) for i in range(9)]
        union = [v for frame in frames for mesh in frame["meshes"] for v in transformed_geometry(mesh)[0]]
        folder = WORK / style
        folder.mkdir(parents=True, exist_ok=True)
        for index, frame in enumerate(frames):
            path = folder / f"frame-{index:02}.png"
            render_monster(document, frame, path, animation=True, union=union, camera_direction=config["direction"])
        print(f"CHEST_BAKE_READY {style}", flush=True)


def source_provenance(source_root, source_id):
    catalogs = ["sources.downloaded.json", "sources.chests.json", "sources.additional-chests.json"]
    record = None
    for catalog in catalogs:
        path = source_root / "asset-review" / catalog
        if path.exists():
            values = read(path)
            for value in (values if isinstance(values, list) else values.get("sources", [])):
                if value["id"] == source_id and value.get("provenance", {}).get("package_sha256"):
                    record = value
    if record is None:
        raise ValueError(f"No verified source provenance for {source_id}")
    source = record["provenance"]
    metadata = source["package_metadata"]
    product_id = str(metadata["id"])
    archive = next((source_root / "downloads" / source_id).glob("*.unitypackage"))
    assert digest(archive) == source["package_sha256"], source_id
    return {
        "title": metadata["title"], "publisher": metadata["publisher"]["label"],
        "version": metadata["version"], "product_id": product_id,
        "url": f"https://assetstore.unity.com/packages/slug/{product_id}",
        "package_sha256": source["package_sha256"],
        "license": "Unity Asset Store Standard EULA; embedded game artwork only",
    }


def pack(source_root):
    from PIL import Image, ImageDraw, ImageFont
    extension = {"version": 1, "generator": "tools/prepare-downloaded-chests.py", "styles": {}, "sources": {}, "files": []}
    sheet = Image.new("RGB", (FRAME_SIZE * 3, (FRAME_SIZE + 36) * len(STYLES)), "#edf2f7")
    font = ImageFont.truetype(r"C:\Windows\Fonts\arial.ttf", 20)
    for row, (style, config) in enumerate(STYLES.items()):
        source_folder = source_root / "asset-review/media" / config["folder"]
        original_frames = sorted(source_folder.glob(config["existing"])) if "existing" in config else sorted((WORK / style).glob("frame-*.png"))
        assert len(original_frames) >= 6, f"Missing rendered frames: {style}"
        paths, bounds, frame_hashes = [], [], []
        for index, original in enumerate(original_frames):
            with Image.open(original) as image:
                image = image.convert("RGBA").resize((FRAME_SIZE, FRAME_SIZE), Image.Resampling.LANCZOS)
                box = image.getchannel("A").getbbox()
                assert box and min(box[:2]) > 0 and max(box[2:]) < FRAME_SIZE, f"Clipped source frame: {original}"
                bounds.append(box)
                target = OUTPUT / style / f"frame-{index:02}.png"
                target.parent.mkdir(parents=True, exist_ok=True)
                # Preserve smooth source colors and alpha; lossless PNG is kept
                # small by its 320px runtime size and a short opening sequence.
                image.save(target, optimize=True)
                relative = target.relative_to(ROOT).as_posix()
                frame_hashes.append(digest(target))
                paths.append(relative)
                extension["files"].append({"path": relative, "sha256": frame_hashes[-1], "bytes": target.stat().st_size, "width": FRAME_SIZE, "height": FRAME_SIZE})
                if index in [0, len(original_frames) // 2, len(original_frames) - 1]:
                    column = [0, len(original_frames) // 2, len(original_frames) - 1].index(index)
                    sheet.paste(image, (column * FRAME_SIZE, row * (FRAME_SIZE + 36)), image)
        assert len(set(frame_hashes)) >= 5, f"Insufficient opening motion: {style}"
        union = [min(b[0] for b in bounds), min(b[1] for b in bounds), max(b[2] for b in bounds), max(b[3] for b in bounds)]
        closed = bounds[0]
        extension["styles"][style] = {
            "name": config["label"], "source": config["source"], "frames": paths,
            "closed_bounds": list(closed), "motion_bounds": union,
            "cavity": [(closed[0] + closed[2]) * 0.5, closed[1] + (closed[3] - closed[1]) * 0.48],
            "method": config["method"], "export_sha256": digest(source_folder / "rest.json"),
        }
        extension["sources"][config["source"]] = source_provenance(source_root, config["source"])
        ImageDraw.Draw(sheet).text((16, row * (FRAME_SIZE + 36) + FRAME_SIZE + 5), config["label"] + " | closed / opening / open", fill="#17263c", font=font)
    write(OUTPUT / "manifest.json", extension)
    WORK.mkdir(parents=True, exist_ok=True)
    sheet.save(WORK / "review.png")
    print(json.dumps({"styles": len(extension["styles"]), "frames": len(extension["files"]), "bytes": sum(f["bytes"] for f in extension["files"])}))


if __name__ == "__main__":
    arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--pack", action="store_true")
    args = parser.parse_args(arguments)
    if args.render:
        render(args.source_root)
    if args.pack:
        pack(args.source_root)
