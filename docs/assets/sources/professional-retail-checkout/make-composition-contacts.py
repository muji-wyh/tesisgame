from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

base = Path(__file__).resolve().parent / 'composition-probe'
report = json.loads((base / 'report.json').read_text())
font_path = Path('C:/Windows/Fonts/arial.ttf')
font = ImageFont.truetype(str(font_path), 18) if font_path.exists() else ImageFont.load_default()
sheet = Image.new('RGBA', (1056, 1040), '#f6f3e9')
draw = ImageDraw.Draw(sheet)
draw.text((16, 10), 'Checkout composition probes | Unaccepted source-rendered alternatives', font=font, fill='#232329')
contacts = Image.new('RGB', (704, 1000), '#f6f3e9')
for index, probe in enumerate(report['probes']):
    name = probe['name']
    x, y = (index % 2) * 528, (index // 2) * 490 + 48
    image = Image.open(base / name / 'checkout.png').convert('RGBA')
    sheet.alpha_composite(image, (x + 8, y))
    note = 'Floor cropped at viewport edges; failed check' if name.startswith('tiled') else 'All local technical checks passed'
    draw.text((x + 12, y + 434), name, font=font, fill='#232329')
    draw.text((x + 12, y + 459), note, font=font, fill='#623d31' if name.startswith('tiled') else '#304f43')
    contacts.paste(Image.open(base / name / 'actual-word-card-contact.png').convert('RGB'), (0, index * 250))
for filename, image in [('composition-contact.png', sheet.convert('RGB')), ('all-native-word-card-contacts.png', contacts)]:
    output = base / filename
    if output.exists():
        raise RuntimeError('Preserve existing QA evidence')
    image.save(output)
    print(output)
