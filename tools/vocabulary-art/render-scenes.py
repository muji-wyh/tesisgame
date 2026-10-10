"""Render the selected Lv3 vocabulary scenes from acquired CC0 Kenney models."""
import bpy
import importlib.util
import math
import json
import sys
from pathlib import Path
from mathutils import Matrix, Vector

ROOT=Path(__file__).resolve().parents[2] / 'build' / 'word-art-review'
spec=importlib.util.spec_from_file_location('study',Path(__file__).with_name('render-studio.py'))
study=importlib.util.module_from_spec(spec)
spec.loader.exec_module(study)
SOURCE=ROOT/'model-source'
SKINS=Path(__file__).with_name('skins')
OUT=ROOT/'blender-study'

def point(rig,name,target):
    bpy.context.view_layer.update()
    bone=rig.pose.bones[name]
    rotate=(bone.tail-bone.head).rotation_difference(Vector(target)-bone.head)
    bone.matrix=Matrix.Translation(bone.head)@rotate.to_matrix().to_4x4()@Matrix.Translation(-bone.head)@bone.matrix
    bpy.context.view_layer.update()

def reach(rig,side,target,bend=(0,0,-1)):
    bpy.context.view_layer.update()
    target=rig.matrix_world.inverted()@Vector(target)
    arm=rig.pose.bones[side+'Arm']
    fore=rig.pose.bones[side+'ForeArm']
    shoulder=arm.head.copy()
    direction=target-shoulder
    first=(arm.tail-arm.head).length
    second=(fore.tail-fore.head).length
    distance=min(direction.length,first+second-.001)
    direction.normalize()
    normal=Vector(bend)-Vector(bend).dot(direction)*direction
    if normal.length<.01:normal=Vector((0,-1,0))
    normal.normalize()
    along=(first*first-second*second+distance*distance)/(2*distance)
    height=math.sqrt(max(0,first*first-along*along))
    elbow=shoulder+along*direction+height*normal
    point(rig,side+'Arm',elbow)
    point(rig,side+'ForeArm',target)

def person(pose='stand',female=False):
    before=set(bpy.data.objects)
    base=SOURCE/'animated-characters-protagonists'
    bpy.ops.import_scene.fbx(filepath=str(base/'Model'/'characterMedium.fbx'))
    objs=[o for o in bpy.data.objects if o not in before]
    rig=next(o for o in objs if o.type=='ARMATURE')
    rig.animation_data_clear()
    for bone in rig.pose.bones:
        bone.rotation_mode='QUATERNION'
    for obj in objs:
        if obj.type!='MESH':continue
        mat=bpy.data.materials.new('Edited Kenney family skin')
        mat.use_nodes=True
        shader=mat.node_tree.nodes.get('Principled BSDF')
        tex=mat.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image=bpy.data.images.load(str(SKINS/('mother.png' if female else 'child.png')))
        mat.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color'])
        obj.data.materials.clear()
        obj.data.materials.append(mat)
    if female:
        # A rounded bob extends the acquired character's existing painted hair.
        # This sculpted accessory makes the parent silhouette clear at card size.
        bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=32,location=(0,.23,3.0))
        hair=bpy.context.object
        hair.name='Parent bob back'
        hair.scale=(.62,.38,.79)
        hair.data.materials.append(material('Soft dark brown hair',(.04,.021,.014),.48))
        for polygon in hair.data.polygons:polygon.use_smooth=True
        objs.append(hair)
    study.prepare_materials(objs)
    rig.pose.bones['Head'].scale=(1.12,1.12,1.12)
    arms={
        'stand':[(.52,-.03,1.77),(.6,-.16,1.22),(-.52,-.03,1.77),(-.6,-.16,1.22)],
        'walk':[(.52,-.36,1.83),(.62,-.7,1.45),(-.53,.2,1.8),(-.65,.38,1.3)],
        'run':[(.53,-.35,1.88),(.5,-.8,2.15),(-.55,.4,2.02),(-.65,.1,2.55)],
        'jump':[(.65,-.12,2.8),(.85,-.2,3.4),(-.65,-.12,2.8),(-.85,-.2,3.4)],
        'hello':[(.52,-.03,1.77),(.6,-.16,1.22),(-.82,-.12,2.56),(-.88,-.22,3.1)],
        'open':[(.55,-.28,1.9),(.72,-.85,2.1),(-.52,-.03,1.77),(-.6,-.16,1.22)],
        'close':[(.62,-.2,2.24),(.85,-.75,2.65),(-.52,-.03,1.77),(-.6,-.16,1.22)],
        'sit':[(.6,-.2,1.88),(.65,-.65,1.6),(-.6,-.2,1.88),(-.65,-.65,1.6)],
    }
    for name,target in zip(['LeftArm','LeftForeArm','RightArm','RightForeArm'],arms.get(pose,arms['stand'])):
        point(rig,name,target)
    if pose in ['walk','run']:
        energetic=pose=='run'
        point(rig,'LeftUpLeg',(.22,-.55 if energetic else -.35,.88))
        point(rig,'LeftLeg',(.25,-.66 if energetic else -.45,.23))
        point(rig,'RightUpLeg',(-.24,.65 if energetic else .4,.83))
        point(rig,'RightLeg',(-.26,.88 if energetic else .55,1.17 if energetic else .24))
    if pose in ['sit','jump']:
        for side,sign in [('Left',1),('Right',-1)]:
            point(rig,side+'UpLeg',(sign*.32,-.5,1.1 if pose=='sit' else .95))
            point(rig,side+'Leg',(sign*.38,-.55,.5))
    return rig,objs

def move_group(objs,scale=1,location=(0,0,0),yaw=0):
    root=bpy.data.objects.new('Scene subject',None)
    bpy.context.collection.objects.link(root)
    for obj in objs:
        if obj.parent not in objs:
            obj.parent=root
    root.scale=(scale,)*3
    root.location=location
    root.rotation_euler.z=yaw
    bpy.context.view_layer.update()
    return root

def prop(name):
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE/'furniture-kit'/'Models'/'GLTF format'/(name+'.glb')))
    objs=[o for o in bpy.data.objects if o not in before]
    study.prepare_materials(objs)
    return objs

def model(pack,name,span,location=(0,0,0),yaw=0):
    before=set(bpy.data.objects)
    variant='GLTF format' if pack=='furniture-kit' else 'GLB format'
    bpy.ops.import_scene.gltf(filepath=str(SOURCE/pack/'Models'/variant/(name+'.glb')))
    objs=[o for o in bpy.data.objects if o not in before]
    study.prepare_materials(objs)
    bpy.context.view_layer.update()
    pts=[o.matrix_world@Vector(c) for o in objs if o.type=='MESH' for c in o.bound_box]
    lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
    scale=span/max(hi-lo)
    root=move_group(objs,scale=scale,yaw=yaw)
    shift=Vector((-(lo.x+hi.x)*.5,-(lo.y+hi.y)*.5,-lo.z))*scale
    root.location=Vector(location)+Matrix.Rotation(yaw,3,'Z')@shift
    bpy.context.view_layer.update()
    return objs,root

def finish(word,meshes):
    study.setup(meshes,word+'.png')
    bpy.context.scene.render.filepath=str(OUT/(word+'.png'))
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(word+'.blend')))
    bpy.ops.render.render(write_still=True)

def material(name,color,rough=.45):
    mat=bpy.data.materials.new(name)
    mat.use_nodes=True
    shader=mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=(*color,1)
    shader.inputs['Roughness'].default_value=rough
    return mat

def pointer(location):
    # A dimensional teaching pointer annotates the sourced comparison objects.
    mat=material('Teaching pointer gold',(.92,.48,.065))
    bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.055,depth=.35,location=Vector(location)+Vector((0,0,.3)))
    bpy.context.object.data.materials.append(mat)
    bpy.ops.mesh.primitive_cone_add(vertices=48,radius1=.005,radius2=.2,depth=.28,location=location)
    bpy.context.object.data.materials.append(mat)

def still_life(word):
    study.clear()
    if word=='bed':model('furniture-kit','bedSingle',3.4)
    elif word=='cup':model('food-kit','cup-tea',2.6,yaw=-.7)
    elif word=='water':
        objects,root=model('food-kit','glass',2.6)
        for obj in objects:
            if obj.type!='MESH':continue
            mat=material('Clear blue glass',(.65,.88,1.0),.28)
            shader=mat.node_tree.nodes.get('Principled BSDF')
            shader.inputs['Transmission Weight'].default_value=.3
            shader.inputs['IOR'].default_value=1.45
            obj.data.materials.clear();obj.data.materials.append(mat)
        bpy.ops.mesh.primitive_cone_add(vertices=96,radius1=.65,radius2=.75,depth=1.68,location=(0,0,1.08))
        water=bpy.context.object
        water.name='Contained drinking water'
        mat=material('Clean drinking water',(.26,.75,.95),.2)
        mat.node_tree.nodes.get('Principled BSDF').inputs['Transmission Weight'].default_value=.18
        water.data.materials.append(mat)
        for polygon in water.data.polygons:polygon.use_smooth=True
    elif word in ['one','two','three']:
        positions={'one':[(0,0,0)],'two':[(-.8,0,0),(.8,0,0)],'three':[(-.8,0,0),(.8,0,0),(0,0,1.3)]}[word]
        for xyz in positions:model('food-kit','apple',1.5,xyz)
    elif word in ['big','small']:
        model('food-kit','apple',2.4,(-.8,0,0))
        model('food-kit','apple',.92,(1.15,0,0))
        pointer((-.8,0,2.85) if word=='big' else (1.15,0,1.43))
    elif word in ['in','on']:
        model('furniture-kit','cardboardBoxOpen' if word=='in' else 'cardboardBoxClosed',2.4)
        model('food-kit','apple',1.35,(0,0,.45 if word=='in' else 1.48))
    elif word=='toy':
        model('toy-car-kit','vehicle-racer',2.7,(-.25,-.2,0),yaw=-.3)
        model('toy-car-kit','item-cone',1.45,(1.1,.85,0))
    else:return False
    finish(word,[o for o in bpy.context.scene.objects if o.type=='MESH'])
    return True

def render(word):
    if word in ['bed','cup','water','one','two','three','big','small','in','on','toy']:
        still_life(word)
        return
    study.clear()
    if word in ['walk','run','jump','hello']:
        rig,objs=person(word)
        yaw=-.48 if word in ['walk','run'] else 0
        move_group(objs,yaw=yaw,location=(0,0,.35 if word=='jump' else 0))
    elif word in ['open','close']:
        rig,objs=person(word)
        move_group(objs,scale=.74,location=(-.4,-.82,0) if word=='open' else (1.88,-.6,0),yaw=.5 if word=='open' else -1.65)
        door=prop('doorway')
        move_group(door,scale=3.5,location=(0,.15,0),yaw=0)
        leaf=next(o for o in door if o.type=='MESH' and 'doorway' not in o.name.lower())
        bounds=[Vector(c) for c in leaf.bound_box]
        lo=Vector(tuple(min(p[i] for p in bounds) for i in range(3)))
        hi=Vector(tuple(max(p[i] for p in bounds) for i in range(3)))
        hinge=leaf.matrix_world@Vector((lo.x,(lo.y+hi.y)*.5,lo.z))
        turn=Matrix.Rotation(math.radians(-64 if word=='open' else -8),4,'Z')
        leaf.matrix_world=Matrix.Translation(hinge)@turn@Matrix.Translation(-hinge)@leaf.matrix_world
        bpy.context.view_layer.update()
        target=leaf.matrix_world@Vector((hi.x-.04,lo.y-.006,lo.z+(hi.z-lo.z)*.53))
        reach(rig,'Left' if word=='open' else 'Right',target)
    elif word in ['drink','eat']:
        rig,objs=person('stand')
        move_group(objs,yaw=-.25)
        held,root=model('food-kit','glass' if word=='drink' else 'loaf',.63,(0,-.66,2.55),yaw=.2)
        if word=='drink':root.rotation_euler.x=.4
        reach(rig,'Left',(.25,-.73,2.65),bend=(1,-1,-1))
        if word=='eat':reach(rig,'Right',(-.25,-.78,2.68),bend=(-1,-1,-1))
        point(rig,'Head',(0,-.13,3.7))
    elif word=='sit':
        rig,objs=person('sit')
        chair,_=model('furniture-kit','chairRounded',2.35,(0,.1,0),yaw=math.pi)
        move_group(objs,location=(0,-.23,-.3))
    elif word=='play':
        rig,objs=person('sit')
        move_group(objs,location=(0,0,-.55),yaw=-.1)
        model('toy-car-kit','vehicle-racer',1.2,(.15,-1.2,0),yaw=.4)
        reach(rig,'Left',(.35,-1.07,.54),bend=(1,0,-1))
    elif word=='go':
        rig,objs=person('walk')
        move_group(objs,location=(-.75,-.3,0),yaw=.8)
        model('furniture-kit','doorwayOpen',3.45,(1.3,.72,0),yaw=-.2)
    elif word=='help':
        left,left_objs=person('stand')
        right,right_objs=person('sit',female=True)
        move_group(left_objs,location=(-.82,0,0),yaw=-.5)
        move_group(right_objs,scale=.8,location=(.84,-.1,-.2),yaw=.35)
        meet=Vector((.1,-.6,1.7))
        reach(left,'Left',meet,bend=(0,-1,-1))
        reach(right,'Right',meet,bend=(0,-1,-1))
    else:raise ValueError(word)
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    bpy.context.view_layer.update()
    report=[]
    for obj in bpy.context.scene.objects:
        row={'name':obj.name,'type':obj.type,'world':list(obj.matrix_world.translation)}
        if obj.type=='MESH':
            pts=[obj.matrix_world@Vector(c) for c in obj.bound_box]
            row['lo']=[min(p[i] for p in pts) for i in range(3)]
            row['hi']=[max(p[i] for p in pts) for i in range(3)]
        if obj.type=='ARMATURE':
            row['hands']={name:list(obj.matrix_world@obj.pose.bones[name].head) for name in ['LeftHand','RightHand']}
        report.append(row)
    (OUT/(word+'-scene.json')).write_text(json.dumps(report,indent=2))
    target=study.setup(meshes,word+'.png')
    # Lower view for character actions so hands and feet keep a clear silhouette.
    cam=bpy.context.scene.camera
    offset=cam.location-target
    if word in ['open','close']:offset.x=-abs(offset.x)
    offset.z*=.62
    cam.location=target+offset
    study.aim(cam,target)
    bpy.context.scene.render.filepath=str(OUT/(word+'.png'))
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(word+'.blend')))
    bpy.ops.render.render(write_still=True)

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    for word in args or ['water','bed','cup','close','drink','eat','go','help','jump','open','play','run','sit','walk','big','small','in','on','one','two','three','toy','hello']:
        render(word)
