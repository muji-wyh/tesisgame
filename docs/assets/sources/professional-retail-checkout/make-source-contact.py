from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

base = Path(__file__).resolve().parent
report = json.loads((base / 'source-inspection/report.json').read_text())
out = base / 'source-inspection/contact.png'
if out.exists():
    raise RuntimeError('Preserve existing QA artifacts')
width, tile_w, tile_h = 1200, 300, 330
rows = (len(report['captures']) + 3) // 4
sheet = Image.new('RGB', (width, rows * tile_h + 60), '#f6f3e9')
draw = ImageDraw.Draw(sheet)
font_path = Path('C:/Windows/Fonts/arial.ttf')
font = ImageFont.truetype(str(font_path), 14) if font_path.exists() else ImageFont.load_default()
title_font = ImageFont.truetype(str(font_path), 22) if font_path.exists() else font
draw.text((16, 12), 'Checkout source inspection | Original complete models and included poses', font=title_font, fill='#232329')
draw.text((16, 38), 'Source evidence only. No composed candidate, acceptance, or production integration.', font=font, fill='#44444a')
for index, capture in enumerate(report['captures']):
    x = (index % 4) * tile_w
    y = (index // 4) * tile_h + 60
    im = Image.open(base / 'source-inspection' / capture['file']).convert('RGB')
    im.thumbnail((292, 292), Image.Resampling.LANCZOS)
    sheet.paste(im, (x + (tile_w-im.width)//2, y))
    label = capture['file'].removesuffix('.png').replace('mini-market--', '').replace('mini-characters--', '').replace('food-kit--', '')
    draw.text((x + 8, y + 294), label[:43], font=font, fill='#232329')
    if len(label) > 43:
        draw.text((x + 8, y + 311), label[43:], font=font, fill='#232329')
sheet.save(out)
print(out)
