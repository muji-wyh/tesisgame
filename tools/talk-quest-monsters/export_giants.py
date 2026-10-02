"""Convert retained GolemMonster and ChaDragon sources to animated game GLBs.

Run with Blender's Python. Source files are read-only; embedded source clips are
measured on their skinned meshes before publication. No publisher code is run.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import bpy
import numpy as np
from mathutils import Vector


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def assign(rig, action):
    rig.animation_data_create()
    rig.animation_data.action = action
    if action and action.slots:
        rig.animation_data.action_slot = action.slots[0]


def vertices(meshes):
    graph = bpy.context.evaluated_depsgraph_get()
    points = []
    for obj in meshes:
        evaluated = obj.evaluated_get(graph)
        mesh = evaluated.to_mesh()
        local = np.empty(len(mesh.vertices) * 3)
        mesh.vertices.foreach_get('co', local)
        matrix = np.array(evaluated.matrix_world)
        points.append(local.reshape((-1, 3)) @ matrix[:3, :3].T + matrix[:3, 3])
        evaluated.to_mesh_clear()
    return np.concatenate(points)


def sampled_action(rig, meshes, action, extent):
    assign(rig, action)
    start, end = action.frame_range
    samples = []
    for frame in np.linspace(start, end, 13):
        bpy.context.scene.frame_set(int(frame), subframe=float(frame % 1))
        samples.append(vertices(meshes))
    points = np.stack(samples)
    movement = float(np.max(np.linalg.norm(points - points[0], axis=2)) / extent)
    spread = float(np.ptp(points.reshape((-1, 3)), axis=0).max() / extent)
    if not np.isfinite(points).all() or movement < 0.0005 or spread > 4:
        raise ValueError(f'Invalid or static source animation {action.name}: {movement}, {spread}')
    return points, {
        'source_action': action.name, 'frame_start': float(start), 'frame_end': float(end),
        'duration_seconds': float((end-start) / bpy.context.scene.render.fps),
        'sample_count': len(samples), 'max_vertex_motion_normalized': movement,
        'max_extent_ratio': spread, 'provenance': 'source skeletal animation',
    }


def textured_material(meshes, texture, cache, name):
    image = bpy.data.images.load(str(texture), check_existing=False)
    source_dimensions = list(image.size)
    if max(image.size) > 1024:
        ratio = 1024 / max(image.size)
        image.scale(round(image.size[0] * ratio), round(image.size[1] * ratio))
    image.filepath_raw = str(cache / (name + '-albedo.png'))
    image.file_format = 'PNG'
    image.save()
    image.pack()
    material = bpy.data.materials.new(name + '-source-albedo')
    material.use_nodes = True
    shader = material.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Roughness'].default_value = 0.78
    shader.inputs['Metallic'].default_value = 0.0
    node = material.node_tree.nodes.new('ShaderNodeTexImage')
    node.image = image
    material.node_tree.links.new(node.outputs['Color'], shader.inputs['Base Color'])
    for mesh in meshes:
        mesh.data.materials.clear()
        mesh.data.materials.append(material)
        for polygon in mesh.data.polygons:
            polygon.material_index = 0
    return {'source_texture_sha256': digest(texture), 'source_dimensions': source_dimensions,
            'export_dimensions': list(image.size), 'mapping': 'Original source UVs and albedo; opaque roughness 0.78'}


def render_preview(path, center):
    scene = bpy.context.scene
    bpy.ops.object.camera_add(location=center + Vector((1.8, -6.3, 1.8)))
    camera = bpy.context.object
    camera.rotation_euler = (center - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = 2.7
    scene.camera = camera
    for location, energy in [((3, -4, 5), 700), ((-3, -2, 3), 500), ((2, 4, 4), 900)]:
        bpy.ops.object.light_add(type='AREA', location=location)
        light = bpy.context.object
        light.data.energy = energy
        light.data.size = 4
        light.rotation_euler = (center - light.location).to_track_quat('-Z', 'Y').to_euler()
    scene.world = bpy.data.worlds.new('Giant Review World')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value = (0.7, 0.78, 0.9, 1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value = 0.5
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 16
    scene.cycles.use_denoising = True
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 6
    scene.render.resolution_x = scene.render.resolution_y = 420
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.view_settings.view_transform = 'Standard'
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    for obj in list(scene.objects):
        if obj.type in {'CAMERA', 'LIGHT'}:
            bpy.data.objects.remove(obj, do_unlink=True)


def convert(source_root, output, kind):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = 30
    if kind == 'ember':
        package = next((source_root / 'sources/golem-monster').glob('*/tree'))
        directory = package / 'Assets/SiuniaevCharacters/02_Golem'
        model = directory / 'Models/FBX/Golem.FBX'
        texture = directory / 'Textures/Golem.png'
        creature_id, name = 'giant-ember-golem', 'Embermaw'
    else:
        package = next((source_root / 'sources/witch-dragon').glob('*/tree'))
        directory = package / 'Assets/Character_Witch_Dragon/Models/ChaDragon'
        model = directory / 'ChaDragon.fbx'
        texture = directory / 'Textures/Cha_Dragon.png'
        creature_id, name = 'giant-storm-dragon', 'Stormwing'
    bpy.ops.import_scene.fbx(filepath=str(model), use_anim=True)
    meshes = [obj for obj in scene.objects if obj.type == 'MESH']
    rigs = [obj for obj in scene.objects if obj.type == 'ARMATURE']
    if not meshes or len(rigs) != 1:
        raise ValueError('Expected complete source meshes and one skeleton')
    rig = rigs[0]
    if any(not any(m.type == 'ARMATURE' and m.object == rig for m in obj.modifiers) for obj in meshes):
        raise ValueError('Source mesh lost its skeleton binding')
    selections, clip_sources = {}, {}
    if kind == 'ember':
        for role, token in {'Idle':'idle', 'Attack':'hit', 'Hit':'damage', 'Defeat':'die'}.items():
            selections[role] = next(a for a in bpy.data.actions if token in a.name.split('|'))
            clip_sources[role] = str(model.relative_to(package))
    else:
        for role, token in {'Idle':'Wait', 'Attack':'Attack', 'Hit':'Damage', 'Defeat':'Dead'}.items():
            motion = directory / ('Motions/MotDragon_' + token + '.fbx')
            before_objects, before_actions = set(bpy.data.objects), set(bpy.data.actions)
            bpy.ops.import_scene.fbx(filepath=str(motion), use_anim=True)
            imported = [o for o in bpy.data.objects if o not in before_objects]
            source_rig = next(o for o in imported if o.type == 'ARMATURE')
            if set(rig.data.bones.keys()) != set(source_rig.data.bones.keys()):
                raise ValueError('Dragon animation skeleton differs from mesh skeleton')
            action = next(a for a in bpy.data.actions if a not in before_actions)
            action.use_fake_user = True
            selections[role] = action
            clip_sources[role] = str(motion.relative_to(package))
            for obj in imported:
                bpy.data.objects.remove(obj, do_unlink=True)
    assign(rig, None)
    rig.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    rest = vertices(meshes)
    lower, upper = rest.min(axis=0), rest.max(axis=0)
    extent = float((upper-lower).max())
    rig.data.pose_position = 'POSE'
    sampled, animations = {}, {}
    for role, action in selections.items():
        sampled[role], animations[role] = sampled_action(rig, meshes, action, extent)
        animations[role].update(source_file=clip_sources[role],
                                source_sha256=digest(package / clip_sources[role]), loop=role == 'Idle')
    material = textured_material(meshes, texture, output, creature_id)
    scale = 2 / extent
    center = (lower+upper)/2
    wrapper = bpy.data.objects.new('GiantRoot', None)
    scene.collection.objects.link(wrapper)
    for obj in list(scene.objects):
        if obj != wrapper and obj.parent is None:
            obj.parent = wrapper
    wrapper.scale = (scale,)*3
    wrapper.location = (-float(center[0])*scale, -float(center[1])*scale, -float(lower[2])*scale)
    assign(rig, selections['Idle'])
    scene.frame_set(int(selections['Idle'].frame_range[0]))
    bpy.context.view_layer.update()
    render_preview(output / (creature_id + '.png'), Vector((0, 0, float((upper[2]-lower[2])*scale/2))))
    assign(rig, None)
    for track in list(rig.animation_data.nla_tracks):
        rig.animation_data.nla_tracks.remove(track)
    for action in list(bpy.data.actions):
        if action not in selections.values():
            bpy.data.actions.remove(action)
    for role, action in selections.items():
        action.name = role
        track = rig.animation_data.nla_tracks.new()
        track.name = role
        strip = track.strips.new(role, 0, action)
        if action.slots:
            strip.action_slot = action.slots[0]
        strip.name = role
        track.mute = True
    target = output / (creature_id + '.glb')
    bpy.ops.export_scene.gltf(filepath=str(target), export_format='GLB',
        export_animation_mode='NLA_TRACKS', export_anim_slide_to_zero=True,
        export_frame_range=False, export_force_sampling=True, export_optimize_animation_size=True,
        export_anim_single_armature=True, export_skins=True, export_morph=False,
        export_cameras=False, export_lights=False, export_extras=False, export_yup=True,
        export_apply=False, export_def_bones=False, export_leaf_bone=False)
    # Blender Z-up and front -Y become glTF Y-up and front +Z.
    combat_points = np.concatenate([sampled[r].reshape((-1,3)) for r in ['Idle','Attack','Hit']])
    combat_points = (combat_points - np.array([center[0],center[1],lower[2]])) * scale
    combat_points = combat_points[:, [0,2,1]] * np.array([1,1,-1])
    result = {'id':creature_id, 'name':name, 'file':target.name, 'resource':'res://assets/talk_quest/monsters/'+target.name,
        'sha256':digest(target), 'bytes':target.stat().st_size, 'source_path':str(model.relative_to(package)),
        'source_sha256':digest(model), 'source_texture':str(texture.relative_to(package)), 'material':material,
        'rig_bones':len(rig.data.bones), 'mesh_objects':len(meshes),
        'vertices':sum(len(obj.data.vertices) for obj in meshes),
        'triangles':sum(len(p.vertices)-2 for obj in meshes for p in obj.data.polygons),
        'normalized_extent':2.0, 'normalized_height':float((upper[2]-lower[2])*scale),
        'front_axis':'+Z', 'floor_y':0, 'bounds':{'min':combat_points.min(axis=0).tolist(),'max':combat_points.max(axis=0).tolist()},
        'animations':animations}
    (output / (creature_id + '.json')).write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    print('GIANT EXPORTED', creature_id, result['bytes'], result['bounds'], flush=True)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--only', choices=['ember','dragon'])
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    args.output.mkdir(parents=True, exist_ok=True)
    for kind in ([args.only] if args.only else ['ember','dragon']):
        convert(args.source_root, args.output, kind)
