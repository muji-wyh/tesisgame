"""Author and render Pip's sculpted growth models with Blender 5.2.

Run: blender --background --python tools/pip-growth/render.py -- --ages 0,6,12 --preview
The source meshes are authored for this project, informed by the original Pip
illustration. No Kenney mesh is incorporated. Each age has six separable roots.
"""
import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build' / 'pip-models'
OUT.mkdir(parents=True, exist_ok=True)
ARGS = argparse.ArgumentParser()
ARGS.add_argument('--ages', default='0,3,4,5,6,7,8,9,10,11,12')
ARGS.add_argument('--preview', action='store_true')
ARGS.add_argument('--save-models', action='store_true')
ARGS.add_argument('--faces', help='Render only these comma-separated expression heads.')
ARGS.add_argument('--parts', help='Render only these comma-separated articulated body parts.')
args = ARGS.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])

# Crown height, cheek width, head height, shoulder height, hem height, torso width.
FORMS = {
    0: (2.32, .71, 1.30, 1.22, .23, .52),
    3: (2.40, .68, 1.24, 1.31, .26, .52),
    4: (2.47, .65, 1.18, 1.40, .28, .51),
    5: (2.54, .62, 1.13, 1.50, .30, .51),
    6: (2.64, .59, 1.06, 1.66, .34, .50),
    7: (2.69, .575, 1.025, 1.73, .37, .50),
    8: (2.75, .555, .99, 1.82, .40, .505),
    9: (2.80, .54, .97, 1.88, .43, .49),
    10: (2.84, .525, .94, 1.94, .46, .485),
    11: (2.89, .51, .92, 2.00, .49, .49),
    12: (2.92, .49, .90, 2.05, .52, .47),
}
PALETTE = {0: 'f7e6a1', 3: 'ffe18a', 4: 'ffda6d', 5: 'ffd15e',
           6: 'ffd15e', 7: 'f9c858', 8: 'f7c657', 9: 'f6c75e',
           10: 'f4c361', 11: 'f4c96d', 12: 'f5cd77'}
ACCENTS = {0: 'eee7d3', 3: '62c9bc', 4: '728ccf', 5: 'eea94c',
           6: 'dc756e', 7: '52a885', 8: 'aa83c4', 9: '559db7',
           10: '467ba3', 11: 'bc705d', 12: '477f78'}
EXPRESSIONS = ['neutral', 'listening', 'thinking', 'delighted', 'proud',
               'encourage', 'surprised', 'sleepy', 'wink', 'blink', 'speaking']
PARTS = ['body', 'head', 'left-wing', 'right-wing', 'left-foot', 'right-foot']
MATERIALS = {}
part = 'body'


def srgb(value):
    return value / 12.92 if value < .04045 else ((value + .055) / 1.055) ** 2.4


def material(name, color, roughness=.48, coat=.08):
    key = (name, color)
    if key in MATERIALS:
        return MATERIALS[key]
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*[srgb(int(color[i:i+2], 16) / 255) for i in (0, 2, 4)], 1)
    mat.use_nodes = True
    node = mat.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value = mat.diffuse_color
    node.inputs['Roughness'].default_value = roughness
    node.inputs['Coat Weight'].default_value = coat
    node.inputs['Coat Roughness'].default_value = .28
    MATERIALS[key] = mat
    return mat


def finish(obj, name, mat):
    obj.name = name
    obj['pip_part'] = part
    obj.data.materials.append(mat)
    for polygon in getattr(obj.data, 'polygons', []):
        polygon.use_smooth = True
    return obj


def rings(name, profile, mat, segments=48, center=(0, 0), power=2):
    """Sculpt a surface from independent, intentionally shaped cross sections."""
    vertices, faces = [], []
    for row in profile:
        z, rx, ry = row[:3]
        offset = row[3] if len(row) > 3 else 0
        for i in range(segments):
            t = i * math.tau / segments
            c, s = math.cos(t), math.sin(t)
            vertices.append((center[0] + rx * math.copysign(abs(c)**(2/power), c),
                             center[1] + offset + ry * math.copysign(abs(s)**(2/power), s), z))
    for j in range(len(profile)-1):
        for i in range(segments):
            a, b = j*segments+i, j*segments+(i+1)%segments
            faces.append((a,b,b+segments,a+segments))
    faces.append(tuple(reversed(range(segments))))
    faces.append(tuple((len(profile)-1)*segments+i for i in range(segments)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    sub = obj.modifiers.new('Sculpted surface continuity', 'SUBSURF')
    sub.levels = sub.render_levels = 2
    return finish(obj, name, mat)


def pebble(name, location, scale, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20, location=location)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, mat)


def stroke(name, points, radius, mat):
    curve = bpy.data.curves.new(name, 'CURVE')
    curve.dimensions = '3D'
    curve.resolution_u = 16
    curve.bevel_depth = radius
    curve.bevel_resolution = 4
    curve.use_fill_caps = True
    spline = curve.splines.new('BEZIER')
    spline.bezier_points.add(len(points)-1)
    for p, co in zip(spline.bezier_points, points):
        p.co = co
        p.handle_left_type = p.handle_right_type = 'AUTO'
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat)


def patch(name, outline, depth, mat, bevel=.035):
    # Extruded custom outlines form bibs, clothing panels and webbed toes.
    vertices = [(x,y,z) for x,y,z in outline] + [(x,y+depth,z) for x,y,z in outline]
    n = len(outline)
    faces = [tuple(reversed(range(n))), tuple(range(n, n*2))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    soft = obj.modifiers.new('Bound fabric edges', 'BEVEL')
    soft.width = bevel
    soft.segments = 3
    return finish(obj, name, mat)


def feather(name, points, widths, mat):
    """Tapered, curved feather mesh, not stacked primitives."""
    vertices, faces = [], []
    for (x,y,z), width in zip(points, widths):
        for i in range(12):
            t = math.tau*i/12
            vertices.append((x+math.cos(t)*width, y+math.sin(t)*width*.43,z))
    for j in range(len(points)-1):
        for i in range(12):
            a,b=j*12+i,j*12+(i+1)%12
            faces.append((a,b,b+12,a+12))
    faces += [tuple(reversed(range(12))),tuple((len(points)-1)*12+i for i in range(12))]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(vertices,[],faces)
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    sub=obj.modifiers.new('Feather softness','SUBSURF')
    sub.levels=sub.render_levels=2
    return finish(obj,name,mat)


def clear():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)


def setup():
    scene=bpy.context.scene
    scene.render.engine='CYCLES'
    scene.cycles.samples=24 if args.preview else 16
    scene.cycles.use_denoising=True
    scene.render.threads_mode='FIXED'
    scene.render.threads=10
    scene.render.resolution_x=scene.render.resolution_y=600 if args.preview else 360
    scene.render.resolution_percentage=100
    scene.render.film_transparent=True
    scene.render.image_settings.file_format='PNG'
    scene.render.image_settings.color_mode='RGBA'
    scene.view_settings.view_transform='Standard'
    scene.view_settings.look='None'
    scene.view_settings.exposure=-.55
    scene.world.color=(.28,.28,.28)
    bpy.ops.object.camera_add(location=(0,-10,1.55))
    camera=bpy.context.object
    camera.rotation_euler=(Vector((0,0,1.55))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO'
    camera.data.ortho_scale=3.6
    scene.camera=camera
    for location,power,color,size in [((-3,-4,6),480,(1,.92,.80),4),((3,-3,3),240,(.80,.9,1),4),((2,2,5),400,(1,.95,.86),3)]:
        bpy.ops.object.light_add(type='AREA',location=location)
        light=bpy.context.object
        light.data.energy=power
        light.data.shape='DISK'
        light.data.size=size
        light.data.color=color
        light.rotation_euler=(Vector((0,0,1.5))-light.location).to_track_quat('-Z','Y').to_euler()


def make_body(age):
    global part
    top,hw,hh,shoulder,hem,bw=FORMS[age]
    down=material('Pip golden down',PALETTE[age])
    wingmat=material('Warm wing feathers','f2bd50' if age>=6 else 'f8d580')
    orange=material('Soft orange bill and feet','efa34a')
    cream=material('Warm ivory cotton','fff2d2',.7)
    accent=material('Age garment',ACCENTS[age],.69)
    ink=material('Deep blue thread','324d58',.7)
    part='body'
    h=shoulder-hem
    shape=[(hem,.18,.17),(hem+.06,bw*.70,.31),
           (hem+h*.20,bw,.39),(hem+h*.47,bw*1.02,.38),
           (hem+h*.76,bw*.91,.32),(shoulder-.06,bw*.65,.245),(shoulder,.20,.18)]
    rings('Pear-shaped duck torso',shape,down)
    if age>=5:
        # A recessed neck keeps the separate head attached during tilted gestures.
        rings('Feathered neck connection',[(shoulder-.16,.18,.17),
              (top-hh+.12,.19,.18),(top-hh+.22,.14,.14)],down)
    if age==0:
        # A visibly hatched silhouette: a broken rim, warm shell thickness, low seat.
        shell=[(.22,.20,.16),(.27,.43,.29),(.46,.56,.38),(.68,.55,.37)]
        obj=rings('Hatched eggshell cup',shell,cream)
        # Crown the shell with a sculpted uneven zigzag rim visible from the front.
        points=[(-.52,-.18,.69),(-.43,-.34,.74),(-.30,-.39,.65),(-.16,-.40,.78),
                (0,-.41,.66),(.17,-.40,.77),(.31,-.36,.65),(.46,-.27,.75),(.54,-.13,.70)]
        stroke('Eggshell broken rim',points,.035,cream)
        for x,z in [(-.29,.47),(.20,.36),(.34,.56)]:
            pebble('Shell fleck',(x,-.381,z),(.037,.013,.026),material('Shell flecks','d9c49b'))
    elif age==3:
        # A broad bib and diaper create toddler proportions at small scale.
        rings('Soft play shorts',[(hem,.20,.18),(hem+.05,bw*.77,.33),(hem+.25,bw*1.035,.405),(hem+.39,bw*.97,.40)],cream)
        patch('Scalloped toddler bib',[(-.28,-.29,shoulder-.10),(.28,-.29,shoulder-.10),
              (.31,-.40,shoulder-.41),(.20,-.445,shoulder-.57),(0,-.46,shoulder-.62),
              (-.20,-.445,shoulder-.57),(-.31,-.40,shoulder-.41)],.07,accent,.045)
        pebble('Bib sun emblem',(0,-.488,shoulder-.40),(.10,.025,.10),cream)
    else:
        garment=accent
        if age==5: garment=material('Raincoat golden ochre','eaa340',.48)
        if age==6: garment=material('First school coral cardigan','d9746b',.67)
        if age==9: garment=material('Maker denim overalls','518ba2',.7)
        # Distinct garment silhouettes: puffed coat, hoodie, short jersey, long jacket.
        width=1.08 if age in [5,8] else 1.0
        gshape=[(hem+.025,bw*.70,.32),(hem+.11,bw*.99*width,.40),
                (hem+h*.38,bw*1.035*width,.405),(hem+h*.75,bw*.93,.34),
                (shoulder-.07,bw*.65,.27),(shoulder-.025,.22,.205)]
        rings('Tailored age garment',gshape,garment)
        if age in [4,9]:
            # Large overall bib and two raised straps; no small decorative clutter.
            rings('Cream undershirt',[(shoulder-.36,bw*.91,.34),(shoulder-.09,bw*.67,.27),(shoulder,.20,.185)],cream)
            patch('Rounded overall bib',[(-.32,-.34,shoulder-.17),(.32,-.34,shoulder-.17),
                 (.30,-.43,hem+.25),(-.30,-.43,hem+.25)],.07,accent,.05)
            for x in [-.24,.24]:
                stroke('Overall shoulder strap',[(x*.65,-.23,shoulder), (x,-.33,shoulder-.16),(x,-.408,shoulder-.40)],.051,accent)
                pebble('Ivory overall button',(x,-.47,shoulder-.34),(.042,.015,.042),cream)
            patch('Overalls front pocket',[(-.19,-.458,hem+.43),(.19,-.458,hem+.43),(.16,-.46,hem+.20),(-.16,-.46,hem+.20)],.025,material('Pocket denim','416a92' if age==4 else '386c83'),.018)
        elif age in [6,11,12]:
            # Open fronts and a high collar give older stages a longer, vertical read.
            patch('Ivory shirt opening',[(-.17,-.32,shoulder-.06),(.17,-.32,shoulder-.06),(.14,-.436,hem+.10),(-.14,-.436,hem+.10)],.035,cream,.02)
            for sign in [-1,1]:
                patch('Folded jacket collar',[(sign*.12,-.32,shoulder-.04),(sign*.32,-.34,shoulder-.15),
                     (sign*.23,-.41,shoulder-.41),(sign*.08,-.41,shoulder-.29)],.045,cream if age<12 else material('Guide collar','99c1a8'),.025)
            if age==6:
                # Oversized first-school backpack is readable outside both shoulders.
                for sign in [-1,1]:
                    pebble('First school backpack side',(sign*.47,.045,hem+h*.63),(.17,.27,.40),material('Backpack turquoise','448e94',.7))
                    stroke('Broad schoolbag strap',[(sign*.26,-.26,shoulder-.04),(sign*.33,-.37,shoulder-.41),(sign*.26,-.43,hem+.12)],.057,material('Backpack turquoise','448e94',.7))
            if age==11:
                for z in [hem+.13,hem+.21]:
                    stroke('Varsity waistband stripe',[(-.32,-.35,z),(0,-.455,z),(.32,-.35,z)],.018,cream)
            if age==12:
                patch('Guide crossbody strap',[(-.29,-.37,shoulder-.20),(-.20,-.39,shoulder-.15),(.34,-.47,hem+.17),(.25,-.49,hem+.12)],.028,material('Canvas crossbody','cbaa70'),.018)
                patch('Guide messenger bag',[(.14,-.45,hem+.47),(.48,-.32,hem+.47),(.49,-.34,hem+.08),(.18,-.49,hem+.08)],.10,material('Canvas satchel','b39058'),.04)
        elif age==7:
            # A light athletic top with broad diagonal sash.
            patch('Sport shirt diagonal',[(-.42,-.31,shoulder-.20),(-.33,-.37,shoulder-.10),(.43,-.35,hem+.23),(.38,-.39,hem+.11)],.035,cream,.025)
        elif age==8:
            # Dropped hood behind the neck and a large kangaroo pocket.
            pebble('Soft raised hood',(0,.05,shoulder-.04),(.49,.33,.37),accent)
            patch('Hoodie kangaroo pocket',[(-.31,-.415,hem+.47),(-.19,-.46,hem+.56),(.19,-.46,hem+.56),(.31,-.415,hem+.47),(.25,-.45,hem+.17),(-.25,-.45,hem+.17)],.025,material('Hoodie pocket','8e69ae',.75),.035)
            for sign in [-1,1]: stroke('Hood drawcord',[(sign*.13,-.34,shoulder-.06),(sign*.12,-.41,shoulder-.42)],.016,cream)
        elif age==10:
            # Unbuttoned overshirt with wide lapels and visibly longer legs.
            patch('Overshirt tee',[(-.15,-.34,shoulder-.04),(.15,-.34,shoulder-.04),(.18,-.45,hem+.10),(-.18,-.45,hem+.10)],.035,cream)
        elif age==5:
            stroke('Raincoat zipper',[(0,-.28,shoulder-.04),(0,-.415,hem+.18)],.018,cream)
            for sign in [-1,1]:
                patch('Raincoat big pocket',[(sign*.17,-.416,hem+.43),(sign*.38,-.34,hem+.43),(sign*.37,-.34,hem+.20),(sign*.16,-.426,hem+.20)],.035,material('Raincoat pockets','cb8833'),.025)
    # Wings lengthen and gain a broad feathered tip as Pip grows.
    wing_length=.42 if age==0 else .48 if age<=4 else .53+(age-5)*.022
    wing_z=shoulder-.17
    for sign,label in [(-1,'left-wing'),(1,'right-wing')]:
        part=label
        wx=sign*(bw*.72)
        feather('Sculpted overlapping wing',[(wx,-.03,wing_z+.09),(wx+sign*.09,-.11,wing_z+.01),
               (wx+sign*.19,-.17,wing_z-wing_length*.45),(wx+sign*.12,-.20,wing_z-wing_length*.88),
               (wx+sign*.045,-.19,wing_z-wing_length)], [.11,.17,.185,.115,.012],wingmat)
        for offset in [0,.095]:
            stroke('Wing feather groove',[(wx+sign*(.13+offset*.2),-.275,wing_z-.24),
                   (wx+sign*(.13-offset*.5),-.27,wing_z-wing_length*.82)],.009,material('Wing seam','d7a441'))
    # Separate leg and webbed-foot roots keep every existing gesture articulated.
    for sign,label in [(-1,'left-foot'),(1,'right-foot')]:
        part=label
        spread=.22 if age<=3 else .25 if age<=6 else .28
        x=sign*spread
        legtop=hem+.16
        rings('Growing leg',[(.20,.075,.08),(legtop,.074,.085)],orange,center=(x,0))
        outline=[(x-.14,-.35,.11),(x-.17,-.22,.115),(x-.09,-.05,.17),
                 (x+.09,-.05,.17),(x+.17,-.22,.115),(x+.14,-.38,.11),
                 (x+.055,-.34,.10),(x,-.41,.10),(x-.055,-.34,.10)]
        patch('Three-toed webbed foot',outline,.05,orange,.025)
        if age==5:
            boot=material('Leaf rain boots','557e65',.44)
            rings('Tall rain boot',[(.12,.16,.23),(.19,.18,.26),(.24,.135,.16),(.48,.125,.14)],boot,center=(x,-.08))
            stroke('Rain boot cuff',[(x-.115,-.11,.47),(x,-.235,.47),(x+.115,-.11,.47)],.025,cream)
        elif age>=7:
            rings('Canvas sneaker',[(.10,.11,.15),(.14,.18,.27),(.23,.17,.26),(.29,.115,.15)],cream,center=(x,-.10))
            stroke('Sneaker foxing',[(x-.14,-.23,.15),(x,-.37,.15),(x+.14,-.23,.15)],.02,material('Sneaker sole','d6c9ae'))
            for z in [.22,.25]: stroke('Sneaker laces',[(x-.065,-.34,z),(x+.065,-.34,z)],.012,ink)


def make_head(age, expression):
    global part
    part='head'
    top,hw,hh,shoulder,hem,bw=FORMS[age]
    bottom=top-hh
    down=material('Pip golden down',PALETTE[age])
    cheek=material('Warm feather cheeks','efb47a' if age<6 else 'e7aa63')
    cream=material('Cream eye white','fff9e5',.36)
    iris=material('Deep chocolate eye','49382b',.23,.3)
    pupil=material('Eye pupil','211e1b',.16,.35)
    shine=material('Eye catchlight','ffffff',.15)
    orange=material('Upper orange bill','efa34a',.37,.16)
    lower=material('Lower bill','d98838',.46)
    mouth=material('Warm smile crease','804529',.5)
    accent=material('Age garment',ACCENTS[age],.69)
    profiles=[(bottom,.10,.12),(bottom+hh*.08,hw*.60,hw*.53),
              (bottom+hh*.24,hw*.98,hw*.68),(bottom+hh*.47,hw,hw*.76),
              (bottom+hh*.72,hw*.93,hw*.72),(bottom+hh*.90,hw*.67,hw*.54),
              (top,.12,.12)]
    rings('Sculpted crown and full duck cheeks',profiles,down)
    # Feather crown evolves from a downy curl to a swept, three-feather crest.
    count=1 if age==0 else 2 if age<=5 else 3
    for index in range(count):
        rootx=(index-(count-1)/2)*.13
        length=.18 if age<=3 else .22 if age<=8 else .25
        sweep=-.15 if age<=4 else .24 if age<=8 else .40
        feather('Age feather crown',[(rootx,.00,top-.12),(rootx+sweep*.2,-.005,top+.025),
                (rootx+sweep*.48,.01,top+length*.79),(rootx+sweep*.85,.02,top+length),
                (rootx+sweep,.03,top+length*(.76-.14*index))],
                [.11,.115,.09,.042,.001],down)
    eyez=bottom+hh*.58
    ex=hw*(.40 if age<6 else .42)
    erx=hw*(.30 if age<=3 else .28 if age<=6 else .265)
    erz=hh*(.205 if age<=3 else .19 if age<=6 else .167)
    if expression=='proud': erz*=.86
    face_y=-hw*.675
    closed=expression in ['blink','sleepy']
    for sign in [-1,1]:
        x=sign*ex
        z=eyez + (.025 if expression=='surprised' else 0)
        is_closed=closed or (expression=='wink' and sign==1) or expression=='delighted'
        if is_closed:
            up=.06 if expression in ['delighted','wink'] else -.065 if expression=='sleepy' else -.025
            stroke('Soft closed eyelid',[(x-erx*.82,face_y-.035,z),(x,face_y-.095,z+up),(x+erx*.82,face_y-.035,z)],.022,iris)
        else:
            eye=pebble('Rounded cream eye',(x,face_y-.01,z),(erx,.065,erz),cream)
            eye.rotation_euler.y=-sign*.10
            direction=.025 if expression=='thinking' else 0
            py=face_y-.074
            pupilx=x+direction-sign*.025
            radius=erx*(.61 if age<=3 else .57)
            pebble('Chestnut iris',(pupilx,py,z-.025),(radius,.025,erz*.68),iris)
            pebble('Deep pupil',(pupilx,py-.022,z-.018),(radius*.64,.011,erz*.51),pupil)
            pebble('Large soft eye light',(pupilx-.03,py-.035,z+erz*.26),(radius*.30,.012,radius*.33),shine)
            pebble('Small reflected eye light',(pupilx+.033,py-.034,z-erz*.34),(radius*.13,.009,radius*.13),shine)
        brow_z=z+erz+.035
        lift=.05 if expression in ['surprised','listening'] else .025 if expression=='encourage' else 0
        if expression=='proud': lift=.045
        if expression=='sleepy': lift=-.035
        if expression=='thinking': lift=.07 if sign==-1 else -.02
        stroke('Friendly eyebrow',[(x-erx*.72,face_y+.035,brow_z+lift),(x,face_y-.025,brow_z+.025+lift),(x+erx*.72,face_y+.035,brow_z+lift)],.018,material('Brow feather shade','a47b3e'))
        pebble('Soft cheek feather patch',(sign*hw*.69,-hw*.58,bottom+hh*.34),(hw*.17,.028,hh*.065),cheek)
    billz=bottom+hh*.27
    bwid=hw*(.60 if age<=4 else .65)
    bill_y=-hw*.68
    opening=.085 if expression in ['speaking','delighted','surprised'] else .023
    if expression=='surprised': bwid*=.74
    # Independent upper and lower bill meshes form the gentle open/closed smile.
    bill= rings('Wide lower duck bill',[(billz-.10-opening,.04,.035),(billz-.085-opening,bwid*.72,.15),
          (billz-.025-opening,bwid*.99,.235),(billz-.005-opening,bwid*.96,.22)],lower,center=(0,bill_y-.035))
    for vertex in bill.data.vertices: vertex.co.z+=.07*(abs(vertex.co.x)/bwid)**2
    rings('Smile interior',[(billz-.04-opening,.04,.03),(billz-.035,bwid*.96,.224),(billz-.01,bwid*.94,.21)],mouth,center=(0,bill_y-.044))
    bill=rings('Sculpted upper duck bill',[(billz-.025,bwid*.96,.22),(billz+.006,bwid,.24),
          (billz+.07,bwid*.79,.19),(billz+.115,bwid*.40,.105),(billz+.12,.07,.05)],orange,center=(0,bill_y-.045))
    for vertex in bill.data.vertices: vertex.co.z+=.055*(abs(vertex.co.x)/bwid)**2
    for sign in [-1,1]:
        pebble('Bill nostril',(sign*bwid*.31,bill_y-.207,billz+.061),(.018,.009,.011),mouth)
    if opening>.05:
        pebble('Little warm tongue',(0,bill_y-.215,billz-.055-opening*.4),(bwid*.40,.024,.025),material('Tongue','df887d'))
    # Large, legible age cues complement anatomy. No occupations or rank insignia.
    if age==4:
        # Broad preschool sun visor with open crown.
        stroke('Preschool soft visor band',[(-hw*.89,-.18,eyez+erz+.13),(0,-hw*.72,eyez+erz+.13),(hw*.89,-.18,eyez+erz+.13)],.065,accent)
        pebble('Preschool sun visor brim',(0,-hw*.71,eyez+erz+.11),(hw*.91,.27,.055),accent)
    elif age==5:
        # A bucket-shaped rain hood surrounds the cheeks, not just a small hat.
        stroke('Rain hood outer rim',[(-hw*.94,-.03,bottom+hh*.26),(-hw*1.07,.01,bottom+hh*.72),
               (-hw*.69,.02,top+.07),(0,.025,top+.14),(hw*.69,.02,top+.07),(hw*1.07,.01,bottom+hh*.72),(hw*.94,-.03,bottom+hh*.26)],.11,material('Raincoat golden ochre','eaa340',.48))
    elif age==7:
        stroke('Sport headband',[(-hw*.95,-.15,top-.29),(0,-hw*.69,top-.30),(hw*.95,-.15,top-.29)],.055,material('Warm ivory cotton','fff2d2',.7))
    elif age==8:
        # Hood raised enough to produce a broad, cozy outline.
        stroke('Hood framing the face',[(-hw*.98,.03,bottom+.10),(-hw*1.09,.05,eyez),(-hw*.70,.07,top+.07),
               (0,.08,top+.14),(hw*.70,.07,top+.07),(hw*1.09,.05,eyez),(hw*.98,.03,bottom+.10)],.10,accent)
    elif age==9:
        # Lightweight round spectacles; the large rims remain legible as a silhouette cue.
        glass=material('Blue glasses frame','345e76',.35)
        for sign in [-1,1]:
            points=[]
            for i in range(13):
                t=math.tau*i/12
                points.append((sign*ex+math.cos(t)*erx*1.20,face_y-.137,eyez+math.sin(t)*erz*1.10))
            stroke('Round curiosity glasses',points,.022,glass)
        stroke('Spectacle bridge',[(-.05,face_y-.15,eyez+.015),(0,face_y-.17,eyez+.04),(.05,face_y-.15,eyez+.015)],.017,glass)
    elif age==10:
        # A reversed cap changes the outline to a clear sideways profile accent.
        rings('Backward canvas cap',[(top-.27,hw*.97,hw*.66),(top-.13,hw*.94,hw*.65),(top+.04,hw*.59,hw*.47),(top+.10,.10,.08)],accent)
        pebble('Backward cap side brim',(.43,.03,top-.24),(.33,.30,.045),accent)
        stroke('Cap stitched panel',[(-.05,-hw*.67,top-.26),(-.07,-hw*.60,top-.10),(-.05,-.26,top+.05)],.014,material('Cap seam','82a3b9'))
    elif age==11:
        # Headphones sit around the neck; clear ear cups broaden this older silhouette.
        for sign in [-1,1]:
            pebble('Neck headphone cushion',(sign*.36,-.15,bottom+.015),(.12,.14,.18),material('Headphone deep blue','344e63',.37))
            pebble('Headphone shell',(sign*.38,-.24,bottom+.015),(.10,.06,.145),material('Headphone ivory','e5d9bd',.38))


def objects_for(part_name=None):
    return [obj for obj in bpy.context.scene.objects if 'pip_part' in obj and (part_name is None or obj['pip_part']==part_name)]


def render(file):
    bpy.context.scene.render.filepath=str(file)
    bpy.ops.render.render(write_still=True)


def pixel(x,z):
    return [60+x/3.6*120, (3.35-z)/3.6*120]


for age in map(int,args.ages.split(',')):
    clear()
    setup()
    make_body(age)
    make_head(age,'neutral')
    directory=OUT/str(age)
    directory.mkdir(exist_ok=True)
    top,hw,hh,shoulder,hem,bw=FORMS[age]
    pivots=[pixel(0,hem+.16),pixel(0,top-hh+.11),pixel(-bw*.72,shoulder-.17),
            pixel(bw*.72,shoulder-.17),pixel(-(.22 if age<=3 else .25 if age<=6 else .28),hem+.03),
            pixel((.22 if age<=3 else .25 if age<=6 else .28),hem+.03)]
    (directory/'model.json').write_text(json.dumps({'age':age,'motionPivots':pivots,
        'shadowRadius':max(22, bw*40+5),'cellPixels':360,'coordinates':'120-unit orthographic front view',
        'form':dict(zip(['crown','cheekWidth','headHeight','shoulder','hem','torsoWidth'],FORMS[age]))},indent=2)+'\n')
    if args.save_models:
        bpy.ops.wm.save_as_mainfile(filepath=str(directory/'pip.blend'),compress=True)
    if args.preview:
        render(directory/'preview.png')
        continue
    if not args.faces:
        for label in args.parts.split(',') if args.parts else PARTS:
            for obj in objects_for(): obj.hide_render=obj['pip_part']!=label
            render(directory/(label+'.png'))
    for obj in objects_for(): obj.hide_render=obj['pip_part']!='head'
    for expression in [] if args.parts else args.faces.split(',') if args.faces else EXPRESSIONS:
        if expression=='neutral': continue
        for obj in objects_for('head'): bpy.data.objects.remove(obj,do_unlink=True)
        make_head(age,expression)
        render(directory/(expression+'.png'))
    print(f'PIP_AGE_RENDER_COMPLETE {age}',flush=True)
