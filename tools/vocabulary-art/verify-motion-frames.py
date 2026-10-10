"""Check every authored frame and export compact local review evidence."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT / 'build/word-art-review'
ANIMATED = REVIEW / 'animated'
WORDS = ['walk', 'run', 'jump', 'open', 'close', 'drink', 'eat', 'hello']
rows = []
contact = Image.new('RGB', (5 * 150, 8 * 168), '#eef4eb')
draw = ImageDraw.Draw(contact)
for row_index, word in enumerate(WORDS):
    metadata = json.loads((ANIMATED / word / 'metadata.json').read_text())
    margins, hashes = [], set()
    for index in range(metadata['frames']):
        picture = Image.open(ANIMATED / word / f'frame-{index + 1:04d}.png').convert('RGBA')
        if picture.size != (256, 256):
            raise ValueError(f'Unexpected authored dimensions: {word}/{index}')
        alpha = np.asarray(picture)[..., 3]
        y, x = np.where(alpha >= 200)
        if not len(x):
            raise ValueError(f'Empty authored frame: {word}/{index}')
        margins.append(int(min(x.min(), y.min(), 255 - x.max(), 255 - y.max())))
        hashes.add(hashlib.sha256(picture.tobytes()).hexdigest())
        indices = [0, round((metadata['frames'] - 1) * .25), round((metadata['frames'] - 1) * .5), round((metadata['frames'] - 1) * .75), metadata['frames'] - 1]
        if index in indices:
            column = indices.index(index)
            thumb = picture.resize((128, 128), Image.Resampling.LANCZOS)
            contact.paste(thumb, (column * 150 + 11, row_index * 168 + 12), thumb)
            draw.text((column * 150 + 10, row_index * 168 + 143), f'{word}  {index + 1}', fill='#36594d')
    if min(margins) < 10 or len(hashes) < 10:
        raise ValueError(f'Clipped or static authored animation: {word}')
    rows.append(dict(id=word, frames=metadata['frames'], uniqueFrames=len(hashes), fps=metadata['fps'],
                     dimensions=[256, 256], minMargin=min(margins), contactError=metadata['maximumHandContactError']))
contact.save(ANIMATED / 'cheerful-final-poses.png')
(ANIMATED / 'verification.json').write_text(json.dumps(dict(samples=rows, totalFrames=sum(row['frames'] for row in rows)), indent=2) + '\n')
print(json.dumps(rows))
