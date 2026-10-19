from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
base=Path(__file__).resolve().parent
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',14)
small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',12)
views=['front-three-quarter','front-other-side','rear-three-quarter','front-low','front-center-high','front-left-low','front-eye-level','underside']
canvas=Image.new('RGB',(1088,604),'#f6f3e9');d=ImageDraw.Draw(canvas)
for i,name in enumerate(views):
 x=8+(i%4)*272;y=8+(i//4)*300
 im=Image.open(base/'source-inspection'/f'{name}.png').convert('RGB');im.thumbnail((256,256),Image.Resampling.LANCZOS)
 canvas.paste(im,(x,y));d.text((x,y+260),name,font=font,fill='#233c38')
d.text((8,588),'Montage of original native source views; originals retained at 512 x 512. No source geometry/material edits.',font=small,fill='#233c38')
canvas.save(base/'source-inspection'/'contact.png')
if (base/'candidate'/'match-unmatched.png').exists():
 canvas=Image.new('RGB',(704,430),'#f6f3e9');d=ImageDraw.Draw(canvas)
 d.text((16,8),'Style comparison: existing native card crops, assembled without rescaling',font=font,fill='#233c38')
 terms=[('Pallet candidate',base/'candidate'),('Accepted shopping cart',base.parent/'shopping-cart'/'candidate'),('Accepted shopping basket',base.parent/'shopping-basket'/'candidate')]
 for row,(label,folder) in enumerate(terms):
  y=50+row*122;d.text((16,y-20),label,font=font,fill='#233c38')
  for col,state in enumerate(['match-unmatched','match-matched','memory-unmatched','memory-matched']):
   x=16+col*172;im=Image.open(folder/f'{state}.png').convert('RGB');canvas.paste(im,(x,y));d.text((x,y+78),state,font=small,fill='#233c38')
 d.text((16,414),'Actual pixels from native WordCard crops; style review only, not participant recognition evidence.',font=small,fill='#233c38')
 canvas.save(base/'candidate'/'style-comparison-native-crops.png')
 canvas.resize((1408,860),Image.Resampling.NEAREST).save(base/'candidate'/'style-comparison-native-crops-2x.png')
