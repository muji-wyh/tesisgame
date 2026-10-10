"""Adapt the acquired Kenney child atlas for the vocabulary motion performances.

Only the expression changes; the approved clothing, hair and skin are retained.
Run with the project's Pillow-enabled Python before rendering the animations.
"""
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).with_name("skins")
SCALE = 4


def curve(points, steps=48):
    a, b, c, d = points
    return [tuple((1-t)**3*a[n] + 3*(1-t)**2*t*b[n] + 3*(1-t)*t*t*c[n] + t**3*d[n]
                  for n in range(2)) for t in [i/steps for i in range(steps+1)]]


def draw_curve(draw, points, fill, width):
    draw.line([(round(x*SCALE), round(y*SCALE)) for x, y in curve(points)],
              fill=fill, width=width*SCALE, joint="curve")


def make_skin(blink=False):
    image = Image.open(ROOT / "child.png").convert("RGBA")
    skin = image.getpixel((315, 256))
    image = image.resize((image.width*SCALE, image.height*SCALE), Image.Resampling.LANCZOS)
    draw = ImageDraw.Draw(image)
    draw.rectangle((301*SCALE, 251*SCALE, 348*SCALE, 280*SCALE), fill=skin)
    # A small open smile reads at 48 px without exaggerating the whole face.
    upper = curve(((304, 259), (313, 264), (333, 264), (343, 257)))
    lower = curve(((343, 257), (338, 279), (312, 280), (304, 259)))
    draw.polygon([(round(x*SCALE), round(y*SCALE)) for x, y in upper+lower], fill="#9f443b")
    draw_curve(draw, ((310, 263), (318, 266), (332, 265), (338, 262)), "#fff0dc", 3)
    draw_curve(draw, ((318, 273), (323, 275), (330, 274), (334, 271)), "#ee8a79", 3)
    if blink:
        for x in (287, 356):
            draw.rectangle(((x-12)*SCALE, 209*SCALE, (x+12)*SCALE, 233*SCALE), fill=skin)
            draw_curve(draw, ((x-8, 223), (x-4, 217), (x+4, 217), (x+8, 223)), "#552419", 4)
    else:
        for x in (283, 352):
            draw.ellipse((x*SCALE, 214*SCALE, (x+4)*SCALE, 218*SCALE), fill="#fff0dc")
    image.resize((1024, 1024), Image.Resampling.LANCZOS).save(
        ROOT / ("child-cheerful-blink.png" if blink else "child-cheerful.png"))


if __name__ == "__main__":
    make_skin()
    make_skin(blink=True)
