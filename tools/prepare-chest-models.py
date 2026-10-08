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
    kinds = ['harvest-keepsake', 'lagoon-pearl', 'moonstone-vault', 'meadow-explorer', 'strawberry-bonbon']
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
from mathutils import Matrix, Vector


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

DESIGNS = {
    'harvest-keepsake': ('poly-style-fantasy-chest', 'additional-chest-previews/poly-style-4a', 'Meshes.fbx', 'Treasure_Chest_4a.prefab'),
    'lagoon-pearl': ('poly-style-fantasy-chest', 'additional-chest-previews/poly-style-1a', 'Meshes.fbx', 'Treasure_Chest_1a.prefab'),
    'moonstone-vault': ('stylized-chests', 'chest-prefab-previews/epic-chest', 'EpicChest_FBX.fbx', 'EpicChest_PF_BIRP.prefab'),
    'meadow-explorer': ('low-poly-chest-animated', 'additional-chest-previews/low-poly-blue', 'Chest_Animated.fbx', 'Chest_Green.prefab'),
    'strawberry-bonbon': ('poly-style-fantasy-chest', 'additional-chest-previews/poly-style-2a', 'Meshes.fbx', 'Treasure_Chest_2a.prefab'),
}


def linear(hex_color):
    rgb = [int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in rgb]


def material(name, color, metallic=0.0, roughness=.43):
    result = bpy.data.materials.new(name)
    result.use_nodes = True
    shader = result.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*linear(color), 1)
    shader.inputs['Metallic'].default_value = metallic
    shader.inputs['Roughness'].default_value = roughness
    shader.inputs['Specular IOR Level'].default_value = .28
    return result


def epic_material(sources, work):
    directory = next((sources / 'stylized-chests').rglob('EpicChest_BaseMap_01_TEX.png')).parent
    source = directory / 'EpicChest_BaseMap_01_TEX.png'
    ao_path = directory / 'EpicChest_AOmap_01_TEX.png'
    base = bpy.data.images.load(str(source), check_existing=True)
    ao = bpy.data.images.load(str(ao_path), check_existing=True)
    width, height = base.size
    pixels = np.array(base.pixels[:], dtype=np.float32).reshape((height, width, 4))
    shadow = np.array(ao.pixels[:], dtype=np.float32).reshape((height, width, 4))
    # Recolor the publisher's atlas regions while retaining its UV layout and AO.
    frame = pixels[:, :, 2] > pixels[:, :, 0] * 1.15
    interior = pixels[:, :, :3].max(axis=2) < .12
    mapped = np.empty_like(pixels)
    mapped[:, :, :3] = linear('a48adc')
    mapped[frame, :3] = linear('d9e6f2')
    mapped[interior, :3] = linear('564783')
    mapped[:, :, :3] *= .66 + .34 * shadow[:, :, 0:1]
    mapped[:, :, 3] = 1
    atlas = generated_image('moonstone-source-atlas', mapped, work)
    result = material('Moonstone_SourceAtlas', 'ffffff', .12, .36)
    node = result.node_tree.nodes.new('ShaderNodeTexImage')
    node.image = atlas
    result.node_tree.links.new(node.outputs['Color'], result.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
    return result, [{'source': str(p), 'source_sha256': sha256(p), 'source_dimensions': [width, height],
                     'runtime_dimensions': [width, height]} for p in (source, ao_path)]


def palette(kind, sources, work):
    colors = {
        'harvest-keepsake': {'Treasure Chest_4_4': ('db9b55', .02), 'Treasure Chest_4_2': ('b8773e', .02),
                            'Treasure Chest_4_3': ('b99869', .30), 'Treasure Chest_4_1': ('f5dfaf', .18),
                            'Treasure Chest_5_1': ('c5a674', .25)},
        'lagoon-pearl': {'Treasure Chest_1_4': ('448faa', .12), 'Treasure Chest_1_2': ('daeff0', .15),
                        'Treasure Chest_1_3': ('77c4ca', .04), 'Treasure Chest_1_1': ('f6e4bf', .22)},
        'strawberry-bonbon': {'Treasure Chest_2_3': ('eaa4b0', .02), 'Treasure Chest_2_2': ('f4d5a6', .06),
                             'Treasure Chest_2_1': ('ffedce', .10), 'Treasure Chest_2_4': ('ce6f91', .06),
                             'Treasure Chest_3_2': ('b36686', .12)},
        'meadow-explorer': {'M_Yellow': ('efce7d', .30), 'M_Gray': ('66ab79', .06), 'M_Brown': ('b77949', .01)},
    }
    if kind == 'moonstone-vault':
        atlas, textures = epic_material(sources, work)
        return {'EpicChest_01_MAT_BIRP': atlas, 'EpicChest_02_MAT_BIRP': material('Moonstone_Gem', '72d3d3', .15, .23)}, textures
    result = {name: material(kind + '_' + name.replace(' ', '_'), color, metal)
              for name, (color, metal) in colors[kind].items()}
    result['Treasure Chest'] = material(kind + '_Interior', '755449' if kind != 'lagoon-pearl' else '315e6b', 0, .64)
    result['Missing source material - neutral review fallback'] = material(kind + '_Inset', 'bfe1df' if kind == 'lagoon-pearl' else 'f4d5a6', .08)
    return result, []


def prefab_model(kind, sources, work):
    import bmesh
    source_id, folder, filename, prefab_name = DESIGNS[kind]
    exported_path = sources.parent / 'asset-review/media' / folder / 'rest.json'
    exported = json.loads(exported_path.read_text(encoding='utf-8-sig'))
    source = next((sources / source_id).rglob(filename))
    prefab = next((sources / source_id).rglob(prefab_name))
    conversion = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
    mapped, textures = palette(kind, sources, work)
    meshes, lid = [], None
    for entry in exported['meshes']:
        if entry['name'].startswith('Gold_'):
            continue
        matrix = Matrix([entry['matrix'][r * 4:r * 4 + 4] for r in range(4)])
        is_lid = entry['name'].startswith('Opened_') or entry['name'] in {'Cube.023', 'Chest_Up'}
        if entry['name'].startswith('Opened_'):
            location, rotation, scale = matrix.decompose()
            matrix = Matrix.Translation(location) @ Matrix.Diagonal((*scale, 1))
        transform = conversion @ matrix
        source_vertices = [Vector(tuple(v[k] for k in 'xyz')) for v in entry['vertices']]
        if kind == 'strawberry-bonbon' and is_lid:
            # The source studs are part of its bands. Lower their pointed tops
            # into small rounded fittings without changing the barrel silhouette.
            for vertex in source_vertices:
                if vertex.y > .269:
                    vertex.y = .269 + (vertex.y - .269) * .12
        vertices = [transform @ v for v in source_vertices]
        normal_matrix = transform.to_3x3().inverted().transposed()
        normals = [(normal_matrix @ Vector(tuple(v[k] for k in 'xyz'))).normalized() for v in entry['normals']]
        pivot = transform.translation.copy() if is_lid else Vector((0, 0, 0))
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
            mesh.materials.append(mapped[info['name']])
        uv = mesh.uv_layers.new(name='Source UV')
        for polygon, slot in zip(mesh.polygons, slots):
            polygon.material_index = slot
            for loop in polygon.loop_indices:
                value = entry['uv'][mesh.loops[loop].vertex_index]
                uv.data[loop].uv = (value['x'], value['y'])
        width = max(v.x for v in vertices) - min(v.x for v in vertices)
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=max(width * .000001, .0000001))
        if kind == 'harvest-keepsake' and is_lid:
            # The connected lid shell is the largest island. The other islands
            # are the source skull/bone clasp and six pointed ornaments.
            remaining, islands = set(bm.verts), []
            while remaining:
                island, pending = set(), [next(iter(remaining))]
                while pending:
                    vertex = pending.pop()
                    if vertex in island:
                        continue
                    island.add(vertex)
                    pending.extend(edge.other_vert(vertex) for edge in vertex.link_edges)
                remaining.difference_update(island)
                islands.append(island)
            shell = max(islands, key=len)
            bmesh.ops.delete(bm, geom=[v for v in bm.verts if v not in shell], context='VERTS')
        bm.to_mesh(mesh)
        bm.free()
        bevel = obj.modifiers.new('Soft source edges', 'BEVEL')
        bevel.width, bevel.segments = width * .0028, 3
        bevel.limit_method, bevel.angle_limit = 'ANGLE', .55
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.modifier_apply(modifier=bevel.name)
        for polygon in mesh.polygons:
            polygon.use_smooth = True
        weighted = obj.modifiers.new('Stable planar normals', 'WEIGHTED_NORMAL')
        weighted.keep_sharp, weighted.weight = True, 70
        bpy.ops.object.modifier_apply(modifier=weighted.name)
        obj.select_set(False)
        meshes.append(obj)
        if is_lid:
            lid = obj
    if lid is None:
        raise ValueError('The source must include a separate lid')
    lift = kind == 'moonstone-vault'
    angle = 0.0 if lift else math.radians(92)
    lid.rotation_mode = 'XYZ'
    base_location = lid.location.copy()
    for frame in range(61):
        t = frame / 60
        eased = t * t * (3 - 2 * t)
        if lift:
            lid.location = base_location + Vector((0, 0, 1.16 * eased))
        else:
            lid.rotation_euler.x = angle * eased
        lid.keyframe_insert(data_path='location' if lift else 'rotation_euler', frame=frame)
    actions = [(lid, lid.animation_data.action)]
    actions[0][1].name = 'Open'
    motion = {'method': 'Game-authored continuous magnetic lift on the original separate cover' if lift else
              'Game-authored continuous hinge on the original separate lid and hinge pivot',
              'duration_seconds': 1, 'opening_angle_radians': angle,
              'source_prefab_export': str(exported_path), 'source_prefab_sha256': sha256(exported_path),
              'design_reference': str(prefab.relative_to(next((sources / source_id).iterdir()) / 'tree')).replace('\\', '/'),
              'source_design_sha256': sha256(prefab)}
    material_info = {'textures': textures, 'mapping': 'Source geometry and UVs; game-authored pastel enamel, warm wood and pearl material colors. '
                     + ('Source atlas regions recolored with retained source ambient occlusion.' if lift else
                        'Original source material slots preserved; missing review slots deliberately mapped to theme inset material.'),
                     'bevel': 'Three-segment edge bevel at 0.28 percent source width'}
    return source, meshes, actions, 60, motion, material_info


def convert(kind, sources, output, work, skip_previews=False):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = 60
    model, meshes, actions, last_frame, motion, materials = prefab_model(kind, sources, work)
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
    facing = -1
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
    hinge = bpy.data.objects['Lid'].matrix_world.translation.copy()
    body = points([bpy.data.objects['Body']])
    cavity_height = float(body[:, 2].max()) if kind == 'moonstone-vault' else float(hinge.z)
    # Fit to the actual source lip, excluding wings, chains, handles and clasps.
    source_lips = {'harvest-keepsake': (.36, -.252), 'lagoon-pearl': (.28, -.265),
                   'strawberry-bonbon': (.48, -.35), 'meadow-explorer': (.30, -.266)}
    if kind in source_lips:
        half_width, source_front = source_lips[kind]
        lip = root.matrix_world @ Vector((0, -source_front, 0))
        cavity_front = float(-lip.y)
        seam_half_width = half_width * scale
    else:
        cavity_front = float(-body[:, 1].min()) * .90
        seam_half_width = (float(body[:, 0].max()) - float(body[:, 0].min())) * .40
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
    parts = [{'node': 'Lid', 'role': 'lid', 'axis': [1, 0, 0], 'angle': motion['opening_angle_radians']}]
    if kind == 'moonstone-vault':
        parts[0]['lift'] = [0, 1.16 * scale, 0]
    result = {'id': kind, 'model': 'res://assets/chests/models/' + target.name,
              'sha256': sha256(target), 'bytes': target.stat().st_size,
              'source_model': str(model), 'source_sha256': sha256(model),
              'materials': materials, 'motion': motion, 'design_reference': motion['design_reference'],
              'source_design_sha256': motion['source_design_sha256'],
              'open_animation': 'Open',
              'open_start': 0,
              'open_end': last_frame / 60,
              'model_parts': parts,
              'camera_direction': [0.56, 0.46, 1.0],
              'cavity_3d': [0, cavity_height, 0],
              'seam_3d': [[-seam_half_width, cavity_height, cavity_front],
                          [seam_half_width, cavity_height, cavity_front]],
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
    parser.add_argument('--only', choices=list(DESIGNS))
    parser.add_argument('--skip-previews', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    args.output.mkdir(parents=True, exist_ok=True)
    args.work.mkdir(parents=True, exist_ok=True)
    reports = [convert(kind, args.source_root.resolve(), args.output.resolve(), args.work.resolve(), args.skip_previews)
               for kind in ([args.only] if args.only else DESIGNS)]
    (args.work / 'model-metadata.json').write_text(json.dumps({'models': reports}, indent=2) + '\n', encoding='utf-8')
