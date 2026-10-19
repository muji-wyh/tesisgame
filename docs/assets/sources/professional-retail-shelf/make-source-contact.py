from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
base=Path(__file__).resolve().parent
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',14)
small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',12)
for folder,title in [('source-inspection','Original source models: all geometry, materials and objects preserved.'),('composition-exploration','Composition exploration: source frame and two original boxes, other product nodes hidden.')]:
 p=base/folder
 if not (p/'report.json').exists(): continue
 record=json.loads((p/'report.json').read_text())
 views=record['captures'];rows=(len(views)+3)//4
 canvas=Image.new('RGB',(1088,rows*300+36),'#f6f3e9');d=ImageDraw.Draw(canvas)
 for i,view in enumerate(views):
  x=8+(i%4)*272;y=8+(i//4)*300
  im=Image.open(p/view['file']).convert('RGB');im.thumbnail((256,256),Image.Resampling.LANCZOS)
  canvas.paste(im,(x,y));d.text((x,y+260),view['file'].removesuffix('.png'),font=font,fill='#233c38')
 d.text((8,rows*300+8),title,font=small,fill='#233c38')
 canvas.save(p/'contact.png')
