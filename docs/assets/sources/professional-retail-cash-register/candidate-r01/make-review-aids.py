"""Assemble review aids only after root's native run; never changes candidate pixels."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib
import json

BASE = Path(__file__).resolve().parent
OUTPUT = BASE / 'output'
ART = BASE.parent.parent
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 14)
small = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 12)
states = ['match-unmatched', 'match-matched', 'memory-unmatched', 'memory-matched']
targets = [OUTPUT / 'style-comparison-native-crops.png', OUTPUT / 'style-comparison-native-crops-2x.png', OUTPUT / 'source-cue-review.png', OUTPUT / 'review-aids.json']
assert all(not path.exists() for path in targets), 'Preserve previous review aids'
canvas = Image.new('RGB', (704, 430), '#f6f3e9')
draw = ImageDraw.Draw(canvas)
draw.text((16, 8), 'Style comparison: native card crops assembled without rescaling', font=font, fill='#233c38')
sources = [('Cash register candidate: review pending', OUTPUT), ('Accepted shopping cart (historical native crops)', ART / 'shopping-cart' / 'candidate'), ('Accepted shopping basket (historical native crops)', ART / 'shopping-basket' / 'candidate')]
inputs = []
for row, (label, folder) in enumerate(sources):
    y = 50 + row * 122
    draw.text((16, y - 20), label, font=font, fill='#233c38')
    for column, state in enumerate(states):
        x = 16 + column * 172
        path = folder / (state + '.png')
        image = Image.open(path).convert('RGB')
        assert image.size == ((126, 72) if column < 2 else (144, 74))
        canvas.paste(image, (x, y))
        draw.text((x, y + 78), state, font=small, fill='#233c38')
        inputs.append({'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
draw.text((16, 414), 'Style aid only. No image or module acceptance; no alternate reader/drawer comparison is claimed.', font=small, fill='#233c38')
canvas.save(targets[0])
canvas.resize((1408, 860), Image.Resampling.NEAREST).save(targets[1])

raw_path = OUTPUT / 'render-raw.png'
raw = Image.open(raw_path).convert('RGBA')
assert raw.size == (768, 768)
regions = [
    {'cue': 'Main display face', 'box': [249, 249, 519, 386]},
    {'cue': 'Physical key bank', 'box': [307, 380, 480, 520]},
    {'cue': 'Drawer front and handle', 'box': [138, 515, 483, 699]},
    {'cue': 'Secondary receipt', 'box': [214, 359, 350, 489]},
    {'cue': 'Upper display face', 'box': [442, 91, 607, 224]},
]
cue_sheet = Image.new('RGB', (1104, 470), '#f6f3e9')
cue_draw = ImageDraw.Draw(cue_sheet)
cue_draw.text((16, 12), 'Source cue regions at native render scale; minimum-card visibility still needs visual review', font=font, fill='#233c38')
for index, region in enumerate(regions):
    x = 16 + (index % 3) * 364
    y = 50 + (index // 3) * 204
    cue_draw.text((x, y), region['cue'], font=font, fill='#233c38')
    crop = raw.crop(region['box'])
    cue_sheet.paste(crop, (x, y + 20), crop)
cue_draw.text((16, 450), 'Original blank display faces are retained. These observed rectangles are review guides, not semantic tests.', font=small, fill='#233c38')
cue_sheet.save(targets[2])
record = {'scope': 'Static review-aid assembly only; candidate PNG and native crops are unchanged.', 'candidate_acceptance': False, 'cue_visibility_acceptance': False, 'historical_inputs': inputs, 'source_render': {'path': str(raw_path), 'sha256': hashlib.sha256(raw_path.read_bytes()).hexdigest()}, 'source_region_basis': 'Manually observed rectangles in the exact inspected 768 x 768 positive-z-right-low source capture. Same camera/centering is used by the candidate.', 'regions': regions, 'outputs': [{'path': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()} for path in targets[:-1]]}
with targets[-1].open('x', encoding='utf-8', newline='\n') as file:
    file.write(json.dumps(record, indent=2) + '\n')
print(json.dumps({'review_aids': len(targets) - 1, 'acceptance': False}))
