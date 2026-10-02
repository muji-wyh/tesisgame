"""Convert retained licensed chest sources into continuously animated private GLBs.

Run inside Blender, then run host Python with --optimize. Publisher scripts are
never executed. Source assets remain read-only; derived textures and review
images are written to the ignored build.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import sys


def optimize_published_textures(work, output):
    """Keep normal maps lossless; compact opaque maps without lowering resolution.

    This publication step runs in the host Python with Pillow, after Blender.
    Geometry, source UVs, animation buffers and image dimensions are unchanged.
    """
    import io
    import struct
    from PIL import Image
    for target in output.glob('*.glb'):
        content = target.read_bytes()
        json_length = struct.unpack_from('<I', content, 12)[0]
        document = json.loads(content[20:20 + json_length])
        binary_offset = 20 + json_length
        binary_length = struct.unpack_from('<I', content, binary_offset)[0]
        binary = content[binary_offset + 8:binary_offset + 8 + binary_length]
        normal_images = {document['textures'][m['normalTexture']['index']]['source']
                         for m in document.get('materials', []) if 'normalTexture' in m}
        replacements = {}
        for index, info in enumerate(document.get('images', [])):
            if index in normal_images or info.get('mimeType') != 'image/png':
                continue
            view = document['bufferViews'][info['bufferView']]
            original = binary[view.get('byteOffset', 0):view.get('byteOffset', 0) + view['byteLength']]
            image = Image.open(io.BytesIO(original))
            if image.mode == 'RGBA' and image.getchannel('A').getextrema() != (255, 255):
                continue
            encoded = io.BytesIO()
            image.convert('RGB').save(encoded, format='JPEG', quality=93, subsampling=0, optimize=True)
            if len(encoded.getvalue()) < len(original):
                replacements[info['bufferView']] = encoded.getvalue()
                info['mimeType'] = 'image/jpeg'
        if not replacements:
            continue
        assembled = bytearray()
        for index, view in enumerate(document['bufferViews']):
            original = binary[view.get('byteOffset', 0):view.get('byteOffset', 0) + view['byteLength']]
            payload = replacements.get(index, original)
            assembled.extend(b'\0' * ((-len(assembled)) % 4))
            view['byteOffset'], view['byteLength'] = len(assembled), len(payload)
            assembled.extend(payload)
        document['buffers'][0]['byteLength'] = len(assembled)
        assembled.extend(b'\0' * ((-len(assembled)) % 4))
        encoded_json = json.dumps(document, separators=(',', ':')).encode('utf-8')
        encoded_json += b' ' * ((-len(encoded_json)) % 4)
        packed = struct.pack('<4sII', b'glTF', 2, 12 + 8 + len(encoded_json) + 8 + len(assembled))
        packed += struct.pack('<I4s', len(encoded_json), b'JSON') + encoded_json
        packed += struct.pack('<I4s', len(assembled), b'BIN\0') + assembled
        target.write_bytes(packed)
        report_path = work / (target.stem + '.json')
        report = json.loads(report_path.read_text())
        report['sha256'], report['bytes'] = hashlib.sha256(packed).hexdigest(), len(packed)
        report['materials']['encoding'] = 'Opaque maps use quality93 JPEG at unchanged dimensions; normal maps remain lossless PNG.'
        report_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
        print('CHEST TEXTURES OPTIMIZED', target.name, len(content), len(packed))
    kinds = ['sea', 'painted-gold', 'crowned', 'iron-wood', 'skull']
    reports = [json.loads((work / (kind + '.json')).read_text()) for kind in kinds if (work / (kind + '.json')).exists()]
    (work / 'model-metadata.json').write_text(json.dumps({'models': reports}, indent=2) + '\n', encoding='utf-8')


if '--optimize' in sys.argv:
    optimizer = argparse.ArgumentParser(description='Pack existing chest textures without lowering their resolution.')
    optimizer.add_argument('--optimize', action='store_true')
    optimizer.add_argument('--work', type=Path, default=Path('build/chest-quality'))
    optimizer.add_argument('--output', type=Path, default=Path('assets/chests/models'))
    optimization = optimizer.parse_args(sys.argv[1:])
    if not optimization.work.is_dir() or not optimization.output.is_dir():
        optimizer.error('Both --work and --output must point to completed Blender outputs.')
    optimize_published_textures(optimization.work.resolve(), optimization.output.resolve())
    raise SystemExit(0)

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def assign(obj, action):
    obj.animation_data_create()
    obj.animation_data.action = action
    if action and action.slots:
        obj.animation_data.action_slot = action.slots[0]


def points(meshes):
    graph = bpy.context.evaluated_depsgraph_get()
    result = []
    for obj in meshes:
        evaluated = obj.evaluated_get(graph)
        mesh = evaluated.to_mesh()
        local = np.empty(len(mesh.vertices) * 3)
        mesh.vertices.foreach_get('co', local)
        matrix = np.array(evaluated.matrix_world)
        result.append(local.reshape((-1, 3)) @ matrix[:3, :3].T + matrix[:3, 3])
        evaluated.to_mesh_clear()
    return np.concatenate(result)


def godot_points(value):
    return value[:, [0, 2, 1]] * np.array([1, 1, -1])


def bounds(value):
    return {'min': value.min(axis=0).tolist(), 'max': value.max(axis=0).tolist()}


def image_file(path, work, name, maximum=2048, data=False):
    image = bpy.data.images.load(str(path), check_existing=False)
    source_size = list(image.size)
    if data:
        image.colorspace_settings.name = 'Non-Color'
    if max(image.size) > maximum:
        ratio = maximum / max(image.size)
        image.scale(round(image.size[0] * ratio), round(image.size[1] * ratio))
    image.filepath_raw = str(work / (name + '.png'))
    image.file_format = 'PNG'
    image.save()
    image.pack()
    return image, {'source': str(path), 'source_sha256': sha256(path),
                   'source_dimensions': source_size, 'runtime_dimensions': list(image.size)}


def basic_material(name, albedo, metallic, roughness):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    shader = nodes.get('Principled BSDF')
    shader.inputs['Metallic'].default_value = metallic
    shader.inputs['Roughness'].default_value = roughness
    if albedo:
        node = nodes.new('ShaderNodeTexImage')
        node.image = albedo
        links.new(node.outputs['Color'], shader.inputs['Base Color'])
    return material


def sea_material(directory, work, meshes):
    base, base_info = image_file(directory / 'Textures/T_SeaChest_Base.png', work, 'sea-base')
    normal, normal_info = image_file(directory / 'Textures/T_SeaChest_Normal.png', work, 'sea-normal', data=True)
    pbr, pbr_info = image_file(directory / 'Textures/T_SeaChest_PBR.png', work, 'sea-pbr', data=True)
    material = basic_material('SeaChest_PaintedWood_Bronze', base, 0, 0.5)
    nodes, links = material.node_tree.nodes, material.node_tree.links
    shader = nodes.get('Principled BSDF')
    pbr_node = nodes.new('ShaderNodeTexImage')
    pbr_node.image = pbr
    channels = nodes.new('ShaderNodeSeparateColor')
    links.new(pbr_node.outputs['Color'], channels.inputs['Color'])
    # The retained Shader Graph reads green as roughness and blue as metallic.
    links.new(channels.outputs['Green'], shader.inputs['Roughness'])
    links.new(channels.outputs['Blue'], shader.inputs['Metallic'])
    normal_node = nodes.new('ShaderNodeTexImage')
    normal_node.image = normal
    normal_map = nodes.new('ShaderNodeNormalMap')
    normal_map.inputs['Strength'].default_value = 0.8
    links.new(normal_node.outputs['Color'], normal_map.inputs['Color'])
    links.new(normal_map.outputs['Normal'], shader.inputs['Normal'])
    for obj in meshes:
        obj.data.materials.clear()
        obj.data.materials.append(material)
    return {'textures': [base_info, normal_info, pbr_info],
            'mapping': 'Original UVs, base and normal maps. Source PBR green is roughness; blue is metallic. Custom Unity color/dirt modifiers are not reproduced.'}


def sea_animation(directory, rig):
    clip = directory / 'Animations/A_SeaChest_Open.anim'
    text = clip.read_text(encoding='utf-8-sig')
    section = text.split('  m_RotationCurves:')[1].split('  m_CompressedRotationCurves:')[0]
    assign(rig, None)
    last_frame = 0
    targets = []
    for curve in section.split('  - curve:')[1:]:
        target = re.search(r'    path: (.+)', curve).group(1).split('/')[-1]
        bone = rig.pose.bones[target]
        targets.append(target)
        bone.rotation_mode = 'QUATERNION'
        for time, value in re.findall(r'time: ([\d.e+-]+)\s+value: (\{[^}]+\})', curve):
            components = {k: float(v) for k, v in re.findall(r'([xyzw]): ([\d.e+-]+)', value)}
            bone.rotation_quaternion = Quaternion(tuple(components[k] for k in 'wxyz'))
            frame = round(float(time) * 60)
            bone.keyframe_insert(data_path='rotation_quaternion', frame=frame, group=target)
            last_frame = max(last_frame, frame)
    action = rig.animation_data.action
    action.name = 'Open'
    return [(rig, action)], last_frame, {
        'method': 'Retained source 60 Hz quaternion keys on the original skeletal bones',
        'source_clip': str(clip), 'source_clip_sha256': sha256(clip),
        'targets': targets, 'duration_seconds': last_frame / 60}


def cartoon_material(directory, work, meshes):
    path = directory / 'TreasureChestTexture.png'
    texture, info = image_file(path, work, 'painted-gold-base', maximum=512)
    materials = {
        'TreasureChestGold': basic_material('PaintedGold_Trim', texture, 0.566, 0.51),
        'TreasureChestWood': basic_material('PaintedGold_Wood', texture, 0.06, 0.79),
    }
    for obj in meshes:
        for index, material in enumerate(obj.data.materials):
            obj.data.materials[index] = materials[material.name]
    return {'textures': [info], 'mapping': 'Original painted 512px albedo and UVs without upscaling. Source gold metal response, lower wood metallic response.'}


def cartoon_animation():
    scene = bpy.context.scene
    objects = [bpy.data.objects[name] for name in ['Chest', 'Lid', 'RingLeft', 'RingRight']]
    for obj in objects:
        assign(obj, bpy.data.actions[obj.name + '|Open|BaseLayer'])
    samples = []
    for frame in np.linspace(31, 41, 31):
        scene.frame_set(int(frame), subframe=float(frame % 1))
        samples.append([(obj.location.copy(), obj.rotation_euler.to_quaternion(), obj.scale.copy()) for obj in objects])
    for obj in objects:
        assign(obj, None)
        obj.rotation_mode = 'QUATERNION'
    for frame, values in enumerate(samples):
        for obj, (location, rotation, scale) in zip(objects, values):
            obj.location, obj.rotation_quaternion, obj.scale = location, rotation, scale
            for path in ['location', 'rotation_quaternion', 'scale']:
                obj.keyframe_insert(data_path=path, frame=frame)
    actions = [(obj, obj.animation_data.action) for obj in objects]
    for obj, action in actions:
        action.name = obj.name + '_Open'
    return actions, 30, {'method': 'Original embedded Open take sampled across all four animated source objects',
                         'source_take_frames': [31, 41], 'duration_seconds': 0.5}


def generated_image(name, pixels, work, data=False):
    image = bpy.data.images.new(name, width=pixels.shape[1], height=pixels.shape[0], alpha=True)
    if data:
        image.colorspace_settings.name = 'Non-Color'
    image.pixels.foreach_set(pixels.astype(np.float32).ravel())
    image.filepath_raw = str(work / (name + '.png'))
    image.file_format = 'PNG'
    image.save()
    image.pack()
    return image


def surface_material(name, color, metallic, roughness, work, grain=False):
    """Author a restrained 1K surface texture for source flat-color materials."""
    side = 1024
    y, x = np.mgrid[0:side, 0:side] / side
    rng = np.random.default_rng(8701)
    noise = rng.random((side, side)) - 0.5
    if grain:
        wave = np.sin(y * math.tau * 32 + np.sin(x * math.tau * 2) * 0.8 + np.sin(x * math.tau * 6) * 0.15)
        detail = 1 + wave * 0.13 + noise * 0.06
    else:
        detail = 1 + noise * 0.06 + np.sin(x * math.tau * 43) * 0.012
    pixels = np.ones((side, side, 4))
    pixels[:, :, :3] = np.clip(np.array(color) * detail[:, :, None], 0, 1)
    albedo = generated_image(name + '-albedo', pixels, work)
    material = basic_material(name, albedo, metallic, roughness)
    nodes, links = material.node_tree.nodes, material.node_tree.links
    shader = nodes.get('Principled BSDF')
    rough_pixels = np.ones((side, side, 4))
    rough_pixels[:, :, :3] = np.clip(roughness + noise[:, :, None] * 0.055, 0.15, 0.85)
    rough = generated_image(name + '-roughness', rough_pixels, work, data=True)
    node = nodes.new('ShaderNodeTexImage')
    node.image = rough
    links.new(node.outputs['Color'], shader.inputs['Roughness'])
    return material


def crowned_material(sources, work):
    directory = next((sources / 'stylized-chests').rglob('CrownedChest_BaseColor_TEX.png')).parent
    base, info = image_file(directory / 'CrownedChest_BaseColor_TEX.png', work, 'crowned-source-base', maximum=1024)
    ao, ao_info = image_file(directory / 'CrownedChest_AOmap_TEX.png', work, 'crowned-source-ao', maximum=1024, data=True)
    array = np.array(base.pixels[:]).reshape((1024, 1024, 4))
    ao_array = np.array(ao.pixels[:]).reshape((1024, 1024, 4))
    is_enamel = (array[:, :, 1] > array[:, :, 0] * 1.15) & (array[:, :, 1] > array[:, :, 2] * 1.15)
    luminance = array[:, :, :3].mean(axis=2)
    strength = 0.72 + np.minimum(1, luminance * 2.0) * 0.28
    out = np.ones_like(array)
    out[:, :, :3] = np.where(is_enamel[:, :, None], np.array([0.235, 0.055, 0.40]), np.array([0.23, 0.30, 0.40]))
    out[:, :, :3] *= strength[:, :, None] * (0.60 + 0.40 * ao_array[:, :, :3])
    albedo = generated_image('crowned-amethyst-silver', out, work)
    material = basic_material('Crowned_Amethyst_Silver', albedo, 0.65, 0.32)
    orm = np.ones_like(out)
    orm[:, :, 1] = np.where(is_enamel, 0.40, 0.29)
    orm[:, :, 2] = np.where(is_enamel, 0.12, 0.83)
    data = generated_image('crowned-material-response', orm, work, data=True)
    nodes, links = material.node_tree.nodes, material.node_tree.links
    node = nodes.new('ShaderNodeTexImage')
    node.image = data
    split = nodes.new('ShaderNodeSeparateColor')
    links.new(node.outputs['Color'], split.inputs['Color'])
    shader = nodes.get('Principled BSDF')
    links.new(split.outputs['Green'], shader.inputs['Roughness'])
    links.new(split.outputs['Blue'], shader.inputs['Metallic'])
    gem = basic_material('Crowned_RoseCrystal', None, 0.28, 0.18)
    gem.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.47, 0.09, 0.30, 1)
    crown = basic_material('Crowned_BurnishedSilver', None, 0.84, 0.24)
    crown.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.35, 0.43, 0.60, 1)
    return {'mapped': material, 'gem': gem, 'crown': crown}, {
        'textures': [info, ao_info],
        'mapping': 'Original 1K UV layout and AO retained; game-authored amethyst enamel, dark silver and rose crystal palette with separate metal/roughness response.'}


def prefab_model(kind, sources, work):
    import bmesh
    root = sources.parent
    locations = {
        'crowned': ('chest-prefab-previews/crowned-chest/rest.json', 'stylized-chests', 'CrownedChest_FBX.fbx'),
        'iron-wood': ('chest-prefab-previews/chest-2-t3/rest.json', 'casual-chests', 'CHEST_2_T3.fbx'),
        'skull': ('additional-chest-previews/poly-style-5a/rest.json', 'poly-style-fantasy-chest', 'Meshes.fbx'),
    }
    relative, source_id, filename = locations[kind]
    exported_path = root / 'asset-review/media' / relative
    exported = json.loads(exported_path.read_text(encoding='utf-8-sig'))
    source = next((sources / source_id).rglob(filename))
    conversion = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    materials = {}
    if kind == 'crowned':
        palette, material_info = crowned_material(sources, work)
    elif kind == 'iron-wood':
        palette = {'Wooden': surface_material('Chest_WalnutWood', (0.23, 0.086, 0.025), 0.03, 0.60, work, True),
                   'Metal': surface_material('Chest_ForgedIron', (0.12, 0.155, 0.20), 0.88, 0.32, work),
                   'Metal 1': surface_material('Chest_BrassRivets', (0.56, 0.29, 0.073), 0.8, 0.28, work)}
        material_info = {'textures': [], 'authored_texture_dimensions': [1024, 1024],
                         'mapping': 'Game-authored 1K walnut grain, forged iron and brass surfaces on the original source material slots; source had flat colors.'}
    else:
        palette = {
            'Treasure Chest_5_4': surface_material('Relic_AgedIvory', (0.63, 0.49, 0.30), 0.12, 0.47, work),
            'Treasure Chest_5_3': surface_material('Relic_ForestWood', (0.035, 0.235, 0.105), 0.05, 0.58, work, True),
            'Treasure Chest_5_1': surface_material('Relic_OldBronze', (0.28, 0.14, 0.055), 0.75, 0.35, work),
            'Treasure Chest_5_2': surface_material('Relic_PolishedJade', (0.06, 0.34, 0.23), 0.25, 0.25, work),
            'Treasure Chest': surface_material('Relic_Interior', (0.04, 0.10, 0.056), 0.03, 0.68, work, True),
        }
        material_info = {'textures': [], 'authored_texture_dimensions': [1024, 1024],
                         'mapping': 'Game-authored 1K forest wood, aged bronze, ivory and jade surfaces on original source material slots; source had flat pastel colors.'}
    meshes = []
    lid = None
    for entry in exported['meshes']:
        if entry['name'].startswith('Gold_'):
            continue
        matrix = Matrix([entry['matrix'][r * 4:r * 4 + 4] for r in range(4)])
        is_lid = entry['name'] in {'Cube.019', 'Chest2_T3_Up', 'Opened_3'}
        if kind == 'skull' and is_lid:
            location, rotation, scale = matrix.decompose()
            matrix = Matrix.Translation(location) @ Matrix.Diagonal((*scale, 1))
        transform = conversion @ matrix
        vertices = [transform @ Vector(tuple(v[k] for k in 'xyz')) for v in entry['vertices']]
        normal_matrix = transform.to_3x3().inverted().transposed()
        normals = [(normal_matrix @ Vector(tuple(v[k] for k in 'xyz'))).normalized() for v in entry['normals']]
        pivot = transform.translation.copy() if is_lid else Vector((0, 0, 0))
        if kind == 'crowned' and is_lid:
            # The retained skinned-mesh export is in centimeters while its
            # skeleton-node inventory is in meters; use the source hinge point.
            pivot = Vector((0.0, -109.49230194091797, 123.21912050247192))
        faces, slots = [], []
        for slot, submesh in enumerate(entry['submeshes']):
            for i in range(0, len(submesh['indices']), 3):
                a, b, c = submesh['indices'][i:i + 3]
                if (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).dot(normals[a] + normals[b] + normals[c]) < 0:
                    b, c = c, b
                faces.append((a, b, c))
                slots.append(slot)
        mesh = bpy.data.meshes.new(kind + ('_LidMesh' if is_lid else '_BodyMesh'))
        mesh.from_pydata([v - pivot for v in vertices], [], faces)
        mesh.update()
        obj = bpy.data.objects.new('Lid' if is_lid else 'Body', mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.location = pivot
        for info in entry['materials']:
            name = info['name']
            if kind == 'crowned':
                material = palette['mapped'] if info.get('texturePath') else palette['gem' if '_01_' in name else 'crown']
            else:
                material = palette[name]
            mesh.materials.append(material)
        uv = mesh.uv_layers.new(name='Source UV' if kind == 'crowned' else 'Authored Surface UV')
        for polygon, slot in zip(mesh.polygons, slots):
            polygon.material_index = slot
            polygon.use_smooth = True
            axis = int(np.argmax(np.abs(polygon.normal)))
            axes = [j for j in range(3) if j != axis]
            for loop in polygon.loop_indices:
                index = mesh.loops[loop].vertex_index
                if kind == 'crowned':
                    source_uv = entry['uv'][index]
                    uv.data[loop].uv = (source_uv['x'], source_uv['y'])
                else:
                    coordinate = vertices[index]
                    factor = 1.1 if kind == 'iron-wood' else 3.0
                    uv.data[loop].uv = (coordinate[axes[0]] * factor, coordinate[axes[1]] * factor)
        width = max(v.x for v in vertices) - min(v.x for v in vertices)
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=max(width * 0.000001, 0.0000001))
        bm.to_mesh(mesh)
        bm.free()
        bevel = obj.modifiers.new('Subtle edge highlights', 'BEVEL')
        bevel.width = width * 0.0018
        bevel.segments = 2
        bevel.limit_method = 'ANGLE'
        bevel.angle_limit = 0.55
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.modifier_apply(modifier=bevel.name)
        weighted = obj.modifiers.new('Stable planar normals', 'WEIGHTED_NORMAL')
        weighted.keep_sharp = True
        weighted.weight = 70
        bpy.ops.object.modifier_apply(modifier=weighted.name)
        obj.select_set(False)
        for polygon in mesh.polygons:
            polygon.use_smooth = True
        meshes.append(obj)
        if is_lid:
            lid = obj
    if lid is None:
        raise ValueError('Source prefab has no separate lid')
    angle = -math.radians(85) if kind == 'iron-wood' else math.radians(85)
    source_clip = None
    if kind == 'iron-wood':
        source_clip = next((sources / source_id).rglob('Animations/Chest_2_T3/openT3.anim'))
        # The publisher clip is a simple one-second rotation to 75 degrees.
        angle = -math.radians(75)
    lid.rotation_mode = 'XYZ'
    for frame in range(61):
        progress = frame / 60
        eased = progress * progress * (3 - 2 * progress)
        lid.rotation_euler.x = angle * eased
        lid.keyframe_insert(data_path='rotation_euler', frame=frame)
    actions = [(lid, lid.animation_data.action)]
    actions[0][1].name = 'Open'
    motion = {'method': 'Game-authored continuous eased hinge using the original separate lid and source hinge',
              'duration_seconds': 1.0, 'opening_angle_radians': angle,
              'source_prefab_export': str(exported_path), 'source_prefab_sha256': sha256(exported_path)}
    if source_clip:
        motion['source_reference_clip'] = str(source_clip)
        motion['source_reference_clip_sha256'] = sha256(source_clip)
    material_info['bevel'] = 'Applied two-segment edge bevel at 0.18 percent source body width'
    return source, meshes, actions, 60, motion, material_info


def render(path, meshes, frame, view_bounds):
    scene = bpy.context.scene
    scene.frame_set(frame)
    lower, upper = view_bounds
    center = Vector((lower + upper) / 2)
    bpy.ops.object.camera_add(location=center + Vector((3.8, -6.5, 3.5)))
    camera = bpy.context.object
    camera.rotation_euler = (center - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = max(3.05, (upper - lower).max() * 1.45)
    scene.camera = camera
    for location, energy, size in [((2.7, -4, 5), 850, 4), ((-4, -2, 2), 650, 3), ((2, 3, 4), 1050, 3)]:
        bpy.ops.object.light_add(type='AREA', location=location)
        lamp = bpy.context.object
        lamp.data.energy, lamp.data.size = energy, size
        lamp.rotation_euler = (center - lamp.location).to_track_quat('-Z', 'Y').to_euler()
    scene.world = bpy.data.worlds.new('Chest Review')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.72, 0.8, 0.94, 1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.6
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 6
    scene.render.resolution_x = scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.view_settings.view_transform = 'AgX'
    scene.view_settings.look = 'AgX - Medium High Contrast'
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    for obj in list(scene.objects):
        if obj.type in {'LIGHT', 'CAMERA'}:
            bpy.data.objects.remove(obj, do_unlink=True)


def convert(kind, sources, output, work, skip_previews=False):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = 60
    if kind in {'crowned', 'iron-wood', 'skull'}:
        model, meshes, actions, last_frame, motion, materials = prefab_model(kind, sources, work)
    else:
        if kind == 'sea':
            model = next((sources / 'stylized-sea-chest').rglob('SeaChest.fbx'))
            directory = model.parent.parent
        else:
            model = next((sources / 'cartoon-treasure-chest').rglob('TreasureChestModel.fbx'))
            directory = model.parent
        bpy.ops.import_scene.fbx(filepath=str(model), use_anim=True)
        # The FBX importer replaces the scene frame rate with its source rate.
        # Our authored/sample keys below explicitly use a 60 Hz runtime clock.
        scene.render.fps = 60
        if kind == 'painted-gold':
            # The loose display coins sit outside the treasure and are not its body.
            outside = bpy.data.objects.get('OutsideCoins')
            if outside:
                for obj in list(outside.children_recursive) + [outside]:
                    bpy.data.objects.remove(obj, do_unlink=True)
        meshes = [obj for obj in scene.objects if obj.type == 'MESH']
        if kind == 'sea':
            rig = next(obj for obj in scene.objects if obj.type == 'ARMATURE')
            materials = sea_material(directory, work, meshes)
            actions, last_frame, motion = sea_animation(directory, rig)
        else:
            materials = cartoon_material(directory, work, meshes)
            actions, last_frame, motion = cartoon_animation()
    scene.frame_set(0)
    closed = points(meshes)
    lower, upper = closed.min(axis=0), closed.max(axis=0)
    scale = 2 / (upper[0] - lower[0])
    center = (lower + upper) / 2
    root = bpy.data.objects.new('ChestRoot', None)
    scene.collection.objects.link(root)
    for obj in list(scene.objects):
        if obj != root and obj.parent is None:
            obj.parent = root
    root.scale = (scale,) * 3
    facing = -1 if kind in {'crowned', 'skull'} else 1
    root.rotation_euler.z = math.pi if facing == -1 else 0
    root.location = (-center[0] * scale * facing, -center[1] * scale * facing, -lower[2] * scale)
    sampled = []
    for frame in np.linspace(0, last_frame, 25):
        scene.frame_set(int(frame), subframe=float(frame % 1))
        sampled.append(points(meshes))
    union = np.concatenate(sampled)
    motion_distance = float(np.linalg.norm(sampled[-1] - sampled[0], axis=1).max())
    if motion_distance < 0.5:
        raise ValueError('Chest opening did not produce a substantial geometry change')
    view_bounds = (union.min(axis=0), union.max(axis=0))
    if not skip_previews:
        render(work / (kind + '-closed.png'), meshes, 0, view_bounds)
        render(work / (kind + '-open.png'), meshes, last_frame, view_bounds)
    scene.frame_set(0)
    bpy.context.view_layer.update()
    if kind == 'sea':
        hinge = rig.matrix_world @ rig.pose.bones['Top_bone'].head
    else:
        hinge = bpy.data.objects['Lid'].matrix_world.translation.copy()
    cavity_height = float(hinge.z)
    cavity_front = None
    if kind == 'painted-gold':
        # This source animates lid translation as well as rotation, so the
        # lid's object origin is not a physical hinge. Its body rim is stable.
        body = points([bpy.data.objects['Chest']])
        cavity_height = float(body[:, 2].max())
        cavity_front = float(-body[:, 1].min()) * 0.90
    selected = {action for obj, action in actions}
    for obj, action in actions:
        assign(obj, None)
        for track in list(obj.animation_data.nla_tracks):
            obj.animation_data.nla_tracks.remove(track)
        track = obj.animation_data.nla_tracks.new()
        track.name = 'Open'
        strip = track.strips.new('Open', 0, action)
        strip.name = 'Open'
        if action.slots:
            strip.action_slot = action.slots[0]
        track.mute = True
    for action in list(bpy.data.actions):
        if action not in selected:
            bpy.data.actions.remove(action)
    scene.frame_start, scene.frame_end = 0, last_frame
    target = output / (kind + '.glb')
    bpy.ops.export_scene.gltf(filepath=str(target), export_format='GLB',
        export_animation_mode='NLA_TRACKS', export_anim_slide_to_zero=True,
        export_frame_range=False, export_force_sampling=True,
        export_optimize_animation_size=True, export_skins=True, export_morph=False,
        export_cameras=False, export_lights=False, export_extras=False,
        export_yup=True, export_apply=False, export_def_bones=False,
        export_leaf_bone=False)
    import struct
    payload = target.read_bytes()
    json_length = struct.unpack_from('<I', payload, 12)[0]
    exported = json.loads(payload[20:20 + json_length])
    duration = max(exported['accessors'][sampler['input']]['max'][0]
                   for animation in exported['animations'] for sampler in animation['samplers'])
    if abs(duration - last_frame / 60) > 0.00001:
        raise ValueError(f'Exported animation clock differs from metadata: {duration}')
    closed_godot = godot_points(sampled[0])
    closed_bounds = bounds(closed_godot)
    h = closed_bounds['max'][1]
    if cavity_front is None:
        cavity_front = closed_bounds['max'][2] * 0.90
    if kind == 'sea':
        parts = [{'node': 'Skeleton3D', 'bone': name, 'role': role, 'axis': [1, 0, 0], 'angle': angle}
                 for name, role, angle in [('Top_bone', 'lid', -math.radians(120)),
                                          ('Lock_bone', 'lock', 0.1),
                                          ('Handle_1_bone', 'handle', 0.1),
                                          ('Handle_2_bone', 'handle', 0.1)]]
    elif kind == 'painted-gold':
        parts = [{'node': name, 'role': role, 'axis': [1, 0, 0], 'angle': angle}
                 for name, role, angle in [('Lid', 'lid', -math.radians(70)),
                                          ('RingLeft', 'handle', 0.1), ('RingRight', 'handle', 0.1)]]
    else:
        parts = [{'node': 'Lid', 'role': 'lid', 'axis': [1, 0, 0], 'angle': motion['opening_angle_radians']}]
    result = {'id': kind, 'model': 'res://assets/chests/models/' + target.name,
              'sha256': sha256(target), 'bytes': target.stat().st_size,
              'source_model': str(model), 'source_sha256': sha256(model),
              'materials': materials, 'motion': motion,
              'open_animation': 'Open',
              'open_start': 130 / 60 if kind == 'sea' else 0,
              'open_end': 3.0 if kind == 'sea' else last_frame / 60,
              'model_parts': parts,
              'camera_direction': [0.56, 0.46, 1.0],
              'cavity_3d': [0, cavity_height, 0],
              'seam_3d': [[-0.83, cavity_height, cavity_front],
                          [0.83, cavity_height, cavity_front]],
              'source_hinge_3d': [float(hinge.x), float(hinge.z), float(-hinge.y)],
              'closed_bounds_3d': closed_bounds,
              'motion_bounds_3d': bounds(godot_points(union)),
              'vertex_count': sum(len(o.data.vertices) for o in meshes),
              'triangle_count': sum(len(p.vertices) - 2 for o in meshes for p in o.data.polygons),
              'max_open_vertex_movement': motion_distance,
              'floor_y': 0, 'front_axis': '+Z',
              'preview_closed': str(work / (kind + '-closed.png')),
              'preview_open': str(work / (kind + '-open.png'))}
    (work / (kind + '.json')).write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print('CHEST EXPORTED', kind, result['bytes'], flush=True)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-root', type=Path, default=Path('C:/uworks/TalkQuest/sources'))
    parser.add_argument('--output', type=Path, default=Path('assets/chests/models'))
    parser.add_argument('--work', type=Path, default=Path('build/chest-quality'))
    parser.add_argument('--only', choices=['sea', 'painted-gold', 'crowned', 'iron-wood', 'skull'])
    parser.add_argument('--skip-previews', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    args.output = args.output.resolve()
    args.work = args.work.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    args.work.mkdir(parents=True, exist_ok=True)
    kinds = ['sea', 'painted-gold', 'crowned', 'iron-wood', 'skull']
    for kind in ([args.only] if args.only else kinds):
        convert(kind, args.source_root, args.output, args.work, args.skip_previews)
    reports = [json.loads(p.read_text()) for p in args.work.glob('*.json') if p.stem in kinds]
    (args.work / 'model-metadata.json').write_text(json.dumps({'models': reports}, indent=2) + '\n', encoding='utf-8')
