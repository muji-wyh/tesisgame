from pathlib import Path
from PIL import Image, ImageChops, ImageOps, ImageDraw, ImageFont, ImageFilter
import json

base = Path(__file__).resolve().parent
source = base.parent / 'motion-r01'
candidate = base / 'candidate'
review = base / 'review'
candidate.mkdir(exist_ok=True)
review.mkdir(exist_ok=True)
environment = Image.open(source / 'renders/environment.png').convert('RGBA')
frames = [Image.open(source / f'renders/composite-{i:02d}.png').convert('RGBA') for i in range(16)]
rest = frames[0]

def rgb_diff(a, b):
    return ImageChops.difference(a.convert('RGB'), b.convert('RGB'))

def maximum_channel(image):
    r, g, b = image.split()
    return ImageChops.lighter(ImageChops.lighter(r, g), b)

mask = maximum_channel(rgb_diff(environment, rest)).point(lambda p: 255 if p else 0)
# Extend opacity into three source pixels of unchanged background to protect filtered edges.
mask = mask.filter(ImageFilter.MaxFilter(7))
props = rest.copy()
props.putalpha(mask)
combined = Image.alpha_composite(environment, props)
assert rgb_diff(combined, rest).getbbox() is None
motion_mask = Image.new('L', rest.size)
for frame in frames[1:]:
    motion_mask = ImageChops.lighter(motion_mask, maximum_channel(rgb_diff(frame, rest)))
bounds = motion_mask.getbbox()
assert bounds is not None
l, t, r, b = bounds
padding = 8
l = max(0, l-padding); t = max(0, t-padding)
r = min(rest.width, r+padding); b = min(rest.height, b+padding)
w, h = r-l, b-t
sheet = Image.new('RGBA', (w*4, h*4))
for index, frame in enumerate(frames):
    patch = frame.crop((l,t,r,b))
    sheet.paste(patch, ((index%4)*w, (index//4)*h))
    reproduced = combined.copy()
    reproduced.paste(patch, (l,t))
    assert rgb_diff(reproduced, frame).getbbox() is None
loop = Image.open(source / 'renders/loop-end.png').convert('RGB')
assert rgb_diff(loop, rest).getbbox() is None
assert rgb_diff(frames[8], rest).getbbox() is None
environment.save(candidate / 'environment.png')
props.save(candidate / 'props.png')
rest.save(candidate / 'home.png')
sheet.save(candidate / 'curtain-hem-sway-sheet.png')
rest.save(review / 'nursing-full-rest.png')
phone_frames = [f.resize((296,296), Image.Resampling.LANCZOS) for f in frames]
phone_frames[0].save(review / 'source-phone-motion.gif', save_all=True, append_images=phone_frames[1:], duration=500, loop=0, disposal=2)
frames[0].save(review / 'source-full-motion.png', save_all=True, append_images=frames[1:], duration=500, loop=0, default_image=False)
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',16)
bold=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',21)
contact=Image.new('RGB',(1216,1336),'#f4f5ef')
draw=ImageDraw.Draw(contact)
draw.text((16,12),'Authored lower-hem sway | all 16 source poses at actual 296 x 296',font=bold,fill='#253b35')
draw.text((16,43),'8-second cycle, 2 FPS. Upper 55% and 29 hardware meshes remain fixed.',font=font,fill='#253b35')
for i,frame in enumerate(phone_frames):
    x=8+(i%4)*304; y=80+(i//4)*314
    draw.text((x,y),f'{i:02d} | {i/2:.1f} s',font=font,fill='#253b35')
    contact.paste(frame.convert('RGB'),(x,y+20))
contact.save(review / 'all-source-phone-poses.png')
poses=Image.new('RGB',(1536,552),'#f4f5ef')
draw=ImageDraw.Draw(poses)
for i,(name,label) in enumerate([('rest','Rest: 0.0 s'),('positive-extreme','Positive extreme: 2.0 s'),('negative-extreme','Negative extreme: 6.0 s')]):
    draw.text((i*512+15,12),label,font=bold,fill='#253b35')
    poses.paste(Image.open(source/f'renders/textile-{name}.png').resize((512,512),Image.Resampling.LANCZOS),(i*512,40))
poses.save(review/'textile-rest-and-extremes.png')
for size in [(320,568),(390,844),(844,390),(1280,800)]:
    for i,label in [(0,'rest'),(4,'positive-extreme'),(12,'negative-extreme')]:
        ImageOps.fit(frames[i],size,method=Image.Resampling.LANCZOS,centering=(.5,.5)).save(review/f'source-covered-{size[0]}x{size[1]}-{label}.png')
accepted=Image.open(base.parent/'static-r03/renders/composite.png').convert('RGB')
rest_difference=maximum_channel(rgb_diff(rest,accepted))
changed=sum(1 for p in rest_difference.get_flattened_data() if p)
maximum=max(rest_difference.get_flattened_data())
comparison=Image.new('RGB',(1024,552),'#f4f5ef')
draw=ImageDraw.Draw(comparison)
draw.text((12,12),'Accepted static source',font=bold,fill='#253b35')
draw.text((524,12),'Authored topology at rest',font=bold,fill='#253b35')
comparison.paste(accepted.resize((512,512),Image.Resampling.LANCZOS),(0,40))
comparison.paste(rest.convert('RGB').resize((512,512),Image.Resampling.LANCZOS),(512,40))
comparison.save(review/'accepted-static-vs-motion-rest.png')
report={'status':'scratch_authored_motion_pending_independent_review','props_mask_unchanged_background_margin_pixels':3,'layer_composite_exact':True,'all_motion_composites_exact':True,'loop_endpoint_matches_rest_exactly':True,'half_cycle_matches_rest_exactly':True,'source_motion_bounds':list(bounds),'patch_bounds':[l,t,w,h],'sheet_size':list(sheet.size),'frame_count':16,'duration_seconds':8,'clip':{'id':'nursing-curtain-hem-sway','columns':4,'rows':4,'frame_count':16,'rest_frame':0,'frames_per_second':2,'rect':[l/rest.width,t/rest.height,w/rest.width,h/rest.height]},'accepted_static_rest_comparison':{'changed_pixels':changed,'maximum_channel_difference':maximum,'reason':'Source triangle subdivision introduces rasterization/interpolation differences at rest; the accepted camera, silhouette, composition, source materials and corrected normals are retained.'},'motion_changed_pixels':sum(1 for p in motion_mask.get_flattened_data() if p),'scope':'Source scene renders, source poses and evidence GIF/APNG only. No live runtime or production approval.'}
(base/'layer-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
