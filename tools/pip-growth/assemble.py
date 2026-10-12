"""Assemble reviewed illustration layers into the existing 120-unit mascot rig."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'build' / 'pip-models'
TARGET = ROOT / 'assets' / 'images' / 'mascots' / 'growth'
PREVIEW = ROOT / 'web' / 'preview' / 'pip-growth' / 'art'
PARTS = ['body', 'head', 'left-wing', 'right-wing', 'left-foot', 'right-foot']
EXPRESSIONS = ['neutral', 'listening', 'thinking', 'delighted', 'proud', 'encourage', 'surprised', 'sleepy', 'wink', 'blink']
AGES = [0,3,4,5,6,7,8,9,10,11,12]
SIZE = 360
ARGS = argparse.ArgumentParser()
ARGS.add_argument('--preview', action='store_true')
args = ARGS.parse_args()


def contact(files, target):
    width, height = 1440, 810
    sheet = Image.new('RGB', (width, height), '#f6f3e9')
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype(str(ROOT/'assets/fonts/Nunito-800.ttf'), 17)
    small = ImageFont.truetype(str(ROOT/'assets/fonts/Nunito-600.ttf'), 13)
    draw.text((30,22),'Pip grows up',font=ImageFont.truetype(str(ROOT/'assets/fonts/Nunito-800.ttf'),30),fill='#344e4b')
    draw.text((30,62),'Storybook character artwork / actual 44 px and 56 px header sizes',font=small,fill='#677672')
    for index,(age,file) in enumerate(files):
        x, y = 24+(index%6)*234, 100+(index//6)*347
        draw.rounded_rectangle((x,y,x+220,y+332),radius=20,fill='#fffdf6',outline='#e4dfd1',width=1)
        draw.text((x+16,y+13),'Baby' if age==0 else f'Age {age}'+('+' if age==12 else ''),font=font,fill='#344e4b')
        source=Image.open(file).convert('RGBA')
        sheet.paste(source.resize((215,215),Image.Resampling.LANCZOS),(x+2,y+37),source.resize((215,215),Image.Resampling.LANCZOS))
        draw.rounded_rectangle((x+13,y+261,x+207,y+320),radius=12,fill='#e9eee3')
        for size,dx in [(44,44),(56,117)]:
            mini=source.resize((size,size),Image.Resampling.LANCZOS)
            sheet.paste(mini,(x+dx,y+263+(56-size)//2),mini)
    sheet.save(target)


def load(directory, name):
    source=Image.open(directory/(name+'.png')).convert('RGBA')
    grounded=Image.new('RGBA',source.size)
    grounded.alpha_composite(source,(0,9))
    return grounded


def compose(parts, heads, pivots, shadow_radius, expression='neutral', pose=None):
    image=Image.new('RGBA',(SIZE,SIZE))
    ImageDraw.Draw(image).ellipse(((61-shadow_radius)*3,107*3,(61+shadow_radius)*3,117*3),fill=(101,112,138,36))
    pose=pose or {}
    for index in [4,5,0,1,2,3]:
        layer=heads[expression].copy() if index==1 else parts[index].copy()
        dx,dy,angle=pose.get(index,(0,0,0))
        if angle:
            layer=layer.rotate(-angle,Image.Resampling.BICUBIC,center=tuple(v*3 for v in pivots[index]))
        image.alpha_composite(layer,(round(dx*3),round(dy*3)))
    return image


def atlas(images, path):
    result=Image.new('RGBA',(SIZE*len(images),SIZE))
    for i,image in enumerate(images): result.alpha_composite(image,(i*SIZE,0))
    result.save(path,optimize=True)
    (PREVIEW/path.name).write_bytes(path.read_bytes())


if args.preview:
    contact([(age,SOURCE/str(age)/'preview.png') for age in AGES],ROOT/'build/pip-model-direction.png')
else:
    files=[]
    bounds=[]
    for age in AGES:
        directory=SOURCE/str(age)
        meta=json.loads((directory/'model.json').read_text())
        meta['motionPivots']=[[x,y+3] for x,y in meta['motionPivots']]
        parts=[load(directory,name) for name in PARTS]
        heads={expression:load(directory,'head' if expression=='neutral' else expression) for expression in EXPRESSIONS+['speaking']}
        composed=lambda expression='neutral',pose=None: compose(parts,heads,meta['motionPivots'],meta['shadowRadius'],expression,pose)
        neutral=composed()
        neutral.save(directory/'assembled.png')
        files.append((age,directory/'assembled.png'))
        stem='pip-baby' if age==0 else f'pip-lv{age}'
        sheets={
            '': [neutral,composed('speaking'),composed('blink'),composed('encourage',{2:(0,0,79),1:(0,0,4)})],
            '-idle': [composed('thinking',{1:(-1,-.5,-5)}),composed('proud',{1:(0,-2,0),2:(0,0,35),3:(0,0,-35)}),
                      composed('wink',{1:(1,0,5)}),composed('sleepy',{1:(1,2,8),2:(0,0,25)})],
            '-parts':parts,
            '-expressions':[composed(expression) for expression in EXPRESSIONS],
            '-expression-heads':[heads[expression] for expression in EXPRESSIONS],
        }
        for suffix,images in sheets.items():
            atlas(images,TARGET/(stem+suffix+'.png'))
            for i,image in enumerate(images):
                box=image.getchannel('A').getbbox()
                if box is None or box[0]<3 or box[1]<3 or box[2]>SIZE-3 or box[3]>SIZE-3:
                    raise ValueError(f'Frame touches its neighbor: age={age}, sheet={suffix}, cell={i}, bounds={box}')
                bounds.append({'age':age,'sheet':suffix,'cell':i,'bounds':box})
    (ROOT/'build/pip-model-bounds.json').write_text(json.dumps(bounds,indent=2)+'\n')
    contact(files,ROOT/'build/pip-model-integrated.png')
    print(f'Assembled {len(AGES)*5} matching PNG atlases; {len(bounds)} cell bounds verified.')
