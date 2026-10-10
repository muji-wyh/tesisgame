"""Shared studio lighting and source-mesh preparation for Lv3 vocabulary renders."""
import bpy
import bmesh
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2] / 'build' / 'word-art-review'
OUT = ROOT / 'blender-study'
OUT.mkdir(parents=True, exist_ok=True)

def clear():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)

def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()

def setup(objects, filename):
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 6
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'None'
    scene.view_settings.exposure = -0.6
    scene.world.color = (0.25, 0.25, 0.25)
    bpy.context.view_layer.update()
    points = [o.matrix_world @ Vector(c) for o in objects if o.type == 'MESH' for c in o.bound_box]
    lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    center = (lo + hi) * 0.5
    extent = max(hi-lo)
    bpy.ops.object.camera_add(location=center+Vector((1.15, -2.4, 1.3))*extent)
    camera = bpy.context.object
    aim(camera, center)
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = extent * 1.35
    scene.camera = camera
    for location, power, color, size in [((-3,-4,6),550,(1,.92,.84),4),((3,-2,3),300,(.84,.9,1),3),((2,3,4),650,(1,.93,.82),3)]:
        bpy.ops.object.light_add(type='AREA', location=center+Vector(location)*extent)
        light=bpy.context.object
        light.data.energy=power*extent*extent
        light.data.shape='DISK'
        light.data.size=size*extent
        light.data.color=color
        aim(light, center)
    scene.render.filepath=str(OUT/filename)
    return center

def prepare_materials(objects):
    for obj in objects:
        if obj.type != 'MESH': continue
        for mat in obj.data.materials:
            if not mat or not mat.use_nodes: continue
            for node in mat.node_tree.nodes:
                if node.type == 'BSDF_PRINCIPLED':
                    node.inputs['Roughness'].default_value=.48
                    node.inputs['Coat Weight'].default_value=.12
                    node.inputs['Coat Roughness'].default_value=.26
        bm=bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
        bm.to_mesh(obj.data)
        bm.free()
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
        # Smooth the acquired mesh rather than replacing its design.
        if any(part in obj.name.lower() for part in ['apple','banana','character','loaf','cup','glass']):
            sub=obj.modifiers.new('Rounded source silhouette','SUBSURF')
            sub.levels=2
            sub.render_levels=2
        # Preserve authored geometry and silhouettes; round only hard joins.
        bevel=obj.modifiers.new('Soft manufactured edges','BEVEL')
        bevel.width=max(obj.dimensions)*.012
        bevel.segments=3
        bevel.limit_method='ANGLE'
        bevel.angle_limit=.6
        for polygon in obj.data.polygons: polygon.use_smooth=True
        if not any(part in obj.name.lower() for part in ['apple','banana','character','loaf','cup','glass']):
            normal=obj.modifiers.new('Preserve broad surfaces','WEIGHTED_NORMAL')
            normal.keep_sharp=True
