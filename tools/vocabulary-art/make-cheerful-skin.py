"""Adapt the acquired Kenney child atlas for the vocabulary motion performances.

Only the expression changes; the approved clothing, hair and skin are retained.
Run with the project's Pillow-enabled Python before rendering the animations.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).with_name("skins")
SCALE = 4


def curve(points, steps=48):
    a, b, c, d = points
    return [tuple((1-t)**3*a[n] + 3*(1-t)**2*t*b[n] + 3*(1-t)*t*t*c[n] + t**3*d[n]
                  for n in range(2)) for t in [i/steps for i in range(steps+1)]]


def draw_curve(draw, points, fill, width):
    draw.line([(round(x*SCALE), round(y*SCALE)) for x, y in curve(points)],
              fill=fill, width=width*SCALE, joint="curve")


def make_skin(expression="smile"):
    image = Image.open(ROOT / "child.png").convert("RGBA")
    skin = image.getpixel((315, 256))
    image = image.resize((image.width*SCALE, image.height*SCALE), Image.Resampling.LANCZOS)
    draw = ImageDraw.Draw(image)
    draw.rectangle((296*SCALE, 251*SCALE, 351*SCALE, 286*SCALE), fill=skin)
    delighted = expression == "delighted"
    if expression == "pleased":
        # A closed, upward smile makes the after-sip/bite response distinct from
        # a laugh. Keep the acquired nose, clothing and face proportions intact.
        draw_curve(draw, ((304, 262), (314, 274), (333, 274), (344, 261)), "#8f4635", 4)
    else:
        upper = curve(((299 if delighted else 301, 256), (312, 263), (334, 263), (348 if delighted else 345, 255)))
        lower = curve(((348 if delighted else 345, 255), (342, 286 if delighted else 280),
                       (307, 287 if delighted else 281), (299 if delighted else 301, 256)))
        draw.polygon([(round(x*SCALE), round(y*SCALE)) for x, y in upper+lower], fill="#833b38")
        draw_curve(draw, ((305, 260), (317, 266), (333, 265), (341, 260)), "#fff4e4", 4)
        draw_curve(draw, ((313, 275 if delighted else 273), (320, 279 if delighted else 276),
                          (332, 278 if delighted else 275), (337, 273 if delighted else 270)), "#ee9182", 4)
    if expression in ("blink", "pleased"):
        for x in (287, 356):
            draw.rectangle(((x-12)*SCALE, 209*SCALE, (x+12)*SCALE, 233*SCALE), fill=skin)
            draw_curve(draw, ((x-8, 223), (x-4, 217), (x+4, 217), (x+8, 223)), "#552419", 4)
    else:
        for x in (283, 352):
            draw.ellipse((x*SCALE, 213*SCALE, (x+5)*SCALE, 218*SCALE), fill="#fff5e7")
    if delighted:
        for x in (287, 356):
            draw.rectangle(((x-24)*SCALE, 183*SCALE, (x+24)*SCALE, 212*SCALE), fill=skin)
            draw_curve(draw, ((x-13, 199), (x-6, 189), (x+6, 189), (x+13, 197)), "#552419", 7)
    blush = Image.new("RGBA", image.size)
    cheeks = ImageDraw.Draw(blush)
    for x in (280, 365):
        cheeks.ellipse(((x-8)*SCALE, 238*SCALE, (x+8)*SCALE, 250*SCALE),
                       fill=(236, 104, 100, 105 if delighted else 65))
    image = Image.alpha_composite(image, blush.filter(ImageFilter.GaussianBlur(2*SCALE)))
    suffix = "" if expression == "smile" else "-" + expression
    image.resize((1024, 1024), Image.Resampling.LANCZOS).save(ROOT / ("child-cheerful" + suffix + ".png"))


if __name__ == "__main__":
    for expression in ("smile", "blink", "delighted", "pleased"):
        make_skin(expression)
