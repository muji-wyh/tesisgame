"""Create a topology-safe, game-sized derivative of the authored Pirate.

Run with Blender CLI. The original blend is never overwritten. Meshes with
shape keys are reduced through disposable proxies, with a fixed barycentric
correspondence transferring their deformation onto the reduced topology.
"""
from pathlib import Path
import argparse
import json
import math
import sys

import bpy
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree


ROOT = Path(__file__).resolve().parents[1]
MORPH_NAMES = ('Bite_Open', 'Eye_Squint', 'Smile_Smirk', 'Tongue_Out')
parser = argparse.ArgumentParser()
parser.add_argument('--source', default='Q:/uwok/boss/pirate-slime.blend')
parser.add_argument('--output', default=str(ROOT / 'build/pirate/pirate-game.raw.glb'))
parser.add_argument('--blend', default='Q:/uwok/boss/game-ready/pirate-game.blend')
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])


def target_triangles(name, count):
    limits = (
        ('sculpted asymmetric body', 4800),
        ('tailored crown seam', 160),
        ('folded', 1000), ('crown', 900), ('piping', 650),
        ('crescent', 200), ('band', 180), ('strap', 220),
        ('recessed curved', 300), ('soft lip', 280),
        ('tongue', 120), ('tooth', 100),
        ('eyepatch', 180), ('Eyepatch', 180),
        ('highlight', 100), ('smil', 120),
    )
    for fragment, limit in limits:
        if fragment in name:
            return min(count, limit)
    return min(count, 160)


def finish_for(name):
    if name.startswith(('Hat | warm antique', 'Crescent |')):
        return 'Gold'
    if name.startswith('Hat |'):
        return 'Cloth'
    if name.startswith('Eyepatch |'):
        return 'Leather'
    if name.startswith(('Slime |', 'Ear |')):
        return 'Skin'
    return 'Face'


def create_finishes():
    specs = {'Skin': (.34, 0), 'Cloth': (.72, 0),
             'Leather': (.56, 0), 'Gold': (.34, .28), 'Face': (.43, 0)}
    result = {}
    for name, (roughness, metal) in specs.items():
        mat = bpy.data.materials.new('Pirate / ' + name)
        mat.use_nodes = True
        shader = mat.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Base Color'].default_value = (1, 1, 1, 1)
        shader.inputs['Roughness'].default_value = roughness
        shader.inputs['Metallic'].default_value = metal
        color = mat.node_tree.nodes.new('ShaderNodeVertexColor')
        color.layer_name = 'Color'
        mat.node_tree.links.new(color.outputs['Color'], shader.inputs['Base Color'])
        result[name] = mat
    return result


def reduced_mesh(source):
    original = source.data
    original.calc_loop_triangles()
    basis = [v.co.copy() for v in original.vertices]
    if original.shape_keys:
        basis = [v.co.copy() for v in original.shape_keys.key_blocks['Basis'].data]
    shapes = {name: [v.co.copy() for v in original.shape_keys.key_blocks[name].data]
              if original.shape_keys and name in original.shape_keys.key_blocks else basis
              for name in MORPH_NAMES}
    opened = shapes['Bite_Open']
    # Hidden neutral mouth surfaces are tiny; simplify their visible open pose.
    use_open = source.name.startswith('Bite |')
    reference = opened if use_open else basis
    valid = [t for t in original.loop_triangles
             if (reference[t.vertices[1]] - reference[t.vertices[0]]).cross(
                 reference[t.vertices[2]] - reference[t.vertices[0]]).length_squared > 1e-18]
    tris = [tuple(t.vertices) for t in valid]
    materials = [t.material_index for t in valid]
    mesh = bpy.data.meshes.new(source.name + ' reduced proxy')
    mesh.from_pydata(reference, [], tris)
    for material in original.materials:
        mesh.materials.append(material)
    for poly, index in zip(mesh.polygons, materials):
        poly.material_index = index
        poly.use_smooth = True
    proxy = bpy.data.objects.new(source.name + ' proxy', mesh)
    bpy.context.scene.collection.objects.link(proxy)
    bpy.ops.object.select_all(action='DESELECT')
    proxy.select_set(True)
    bpy.context.view_layer.objects.active = proxy
    count = len(tris)
    target = target_triangles(source.name, count)
    if target < count:
        modifier = proxy.modifiers.new('Silhouette reduction', 'DECIMATE')
        modifier.ratio = target / count
        modifier.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    mesh = proxy.data
    mesh.calc_loop_triangles()
    tree = BVHTree.FromPolygons(reference, tris, all_triangles=True)
    neutral, morph = [], {name: [] for name in MORPH_NAMES}
    max_projection = 0.0
    for vertex in mesh.vertices:
        point = vertex.co
        nearest, normal, index, distance = tree.find_nearest(point)
        if nearest is None:
            raise RuntimeError('Morph projection failed for ' + source.name)
        max_projection = max(max_projection, distance)
        a, b, c = tris[index]
        edge1, edge2 = reference[b] - reference[a], reference[c] - reference[a]
        delta = nearest - reference[a]
        aa, ab, bb = edge1.dot(edge1), edge1.dot(edge2), edge2.dot(edge2)
        da, db = delta.dot(edge1), delta.dot(edge2)
        denominator = aa * bb - ab * ab
        if abs(denominator) > 1e-20:
            weight_b = (bb * da - ab * db) / denominator
            weight_c = (aa * db - ab * da) / denominator
            weight_a = 1 - weight_b - weight_c
        else:
            closest = min((a, b, c), key=lambda k: (nearest - reference[k]).length_squared)
            weight_a, weight_b, weight_c = (int(closest == k) for k in (a, b, c))
        def transfer(coordinates):
            return coordinates[a] * weight_a + coordinates[b] * weight_b + coordinates[c] * weight_c
        # Keep the optimized visible pose exactly, transferring only its delta.
        if use_open:
            neutral.append(point + transfer(basis) - transfer(opened))
        else:
            neutral.append(point.copy())
        for name in MORPH_NAMES:
            morph[name].append(point.copy() if use_open and name == 'Bite_Open' else
                               neutral[-1] + transfer(shapes[name]) - transfer(basis))
        if not all(math.isfinite(value) for co in [neutral[-1], *[morph[n][-1] for n in MORPH_NAMES]] for value in co):
            raise RuntimeError('Non-finite transferred geometry in ' + source.name)
    result = {
        'name': source.name, 'source_triangles': count,
        'triangles': len(mesh.loop_triangles),
        'proxy_pose': 'Bite_Open' if use_open else 'Basis',
        'max_proxy_projection_distance': round(max_projection, 8),
        'neutral': neutral, 'morph': morph,
        'faces': [(tuple(t.vertices), t.material_index) for t in mesh.loop_triangles],
    }
    bpy.data.objects.remove(proxy, do_unlink=True)
    if mesh.users == 0:
        bpy.data.meshes.remove(mesh)
    return result


bpy.ops.wm.open_mainfile(filepath=args.source)
scene = bpy.context.scene
scene.frame_set(1)
bpy.context.view_layer.update()
collection = bpy.data.collections['CHARACTER | Captain Clover']
sources = [o for o in collection.objects if o.type == 'MESH']
body = bpy.data.objects['Slime | sculpted asymmetric body']
key_tracks = []
for track in body.data.shape_keys.animation_data.nla_tracks:
    for strip in track.strips:
        key_tracks.append((track.name, track.mute, strip.action, strip.action_slot,
                           strip.action_frame_start, strip.action_frame_end))
finishes = create_finishes()
finish_names = list(finishes)
groups = {}
report = []
open_body_tree = None
for source in sources:
    # The parent pivot is animated, so bake only the mesh-local static transform.
    transform = source.matrix_basis.copy()
    parent = source.parent
    group = groups.setdefault(parent.name, {'parent': parent, 'verts': [],
                                            'shapes': {n: [] for n in MORPH_NAMES},
                                            'faces': [], 'mats': [], 'colors': []})
    result = reduced_mesh(source)
    offset = len(group['verts'])
    neutral_points = [transform @ point for point in result.pop('neutral')]
    shapes = {name: [transform @ point for point in points]
              for name, points in result.pop('morph').items()}
    open_points = shapes['Bite_Open']
    faces = result.pop('faces')
    if source == body:
        open_body_tree = BVHTree.FromPolygons(open_points, [f[0] for f in faces], all_triangles=True)
    elif source.name.startswith(('Bite | recessed', 'Bite | rounded')):
        # Refit the visible lining against the *reduced* indented body. Independent
        # triangulations otherwise cross at the pocket even when both match the
        # original smooth surface. Neutral hidden geometry remains unchanged.
        clearance = .045 if 'recessed' in source.name else .070
        for point in open_points:
            hit, _normal, _index, _distance = open_body_tree.ray_cast(
                Vector((point.x, -5, point.z)), Vector((0, 1, 0)))
            if hit is not None:
                point.y = min(point.y, hit.y - clearance)
        result['open_pose_clearance'] = clearance
    group['verts'].extend(neutral_points)
    for morph in MORPH_NAMES:
        group['shapes'][morph].extend(shapes[morph])
    for indices, mat_index in faces:
        mat = source.data.materials[mat_index]
        shader = mat.node_tree.nodes.get('Principled BSDF')
        color = tuple(shader.inputs['Base Color'].default_value)
        group['faces'].append(tuple(index + offset for index in indices))
        group['mats'].append(finish_names.index(finish_for(mat.name)))
        group['colors'].append(color)
    report.append(result)
    print('Reduced', result['name'], result['source_triangles'], '->', result['triangles'], flush=True)

for group in groups.values():
    parent = group['parent']
    hat = 'hat' in parent.name
    name = 'Pirate_Hat' if hat else 'Pirate_Body'
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(group['verts'], [], group['faces'])
    for material in finishes.values():
        mesh.materials.append(material)
    color = mesh.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='CORNER')
    for poly, mat_index, rgba in zip(mesh.polygons, group['mats'], group['colors']):
        poly.material_index = mat_index
        poly.use_smooth = True
        for loop in poly.loop_indices:
            color.data[loop].color = rgba
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.parent = parent
    obj.matrix_parent_inverse = Matrix.Identity(4)
    if not hat:
        obj.shape_key_add(name='Basis')
        for morph in MORPH_NAMES:
            key = obj.shape_key_add(name=morph)
            for vertex, point in zip(key.data, group['shapes'][morph]):
                vertex.co = point
            key.value = 0
        keys = mesh.shape_keys
        keys.animation_data_create()
        for track_name, muted, action, slot, start, end in key_tracks:
            track = keys.animation_data.nla_tracks.new()
            track.name, track.mute = track_name, muted
            strip = track.strips.new(track_name, 1, action)
            strip.action_slot = slot
            strip.action_frame_start, strip.action_frame_end = start, end
            strip.extrapolation = 'NOTHING'
for source in sources:
    bpy.data.objects.remove(source, do_unlink=True)
scene.frame_set(1)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
for obj in collection.objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = bpy.data.objects['Captain Clover | animated root']
output = Path(args.output)
output.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', use_selection=True,
    export_animations=True, export_frame_range=False, export_animation_mode='ACTIONS',
    export_merge_animation='ACTION', export_force_sampling=True, export_yup=True,
    export_extras=True, export_morph=True, export_morph_animation=True,
    export_optimize_animation_size=False)
blend = Path(args.blend)
blend.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
(output.parent / 'geometry-report.json').write_text(json.dumps({
    'source': str(Path(args.source)), 'optimized_blend': str(blend),
    'algorithm': 'Decimated visible-pose proxy with fixed barycentric morph delta transfer',
    'materials': finish_names, 'meshes': report,
    'triangles': sum(r['triangles'] for r in report),
}, indent=2) + '\n', encoding='utf-8')
print('PIRATE GAME DERIVATIVE COMPLETE:', output, flush=True)
