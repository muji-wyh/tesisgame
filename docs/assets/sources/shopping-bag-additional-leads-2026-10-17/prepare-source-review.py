"""Retain source evidence and make image-only size studies; no game execution."""

from datetime import datetime, timezone
from hashlib import sha256
import json
from pathlib import Path
import re
import urllib.request

from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[3]
SOURCE = ROOT / "acquired/3dicons-bag-dynamic-color.png"
BASKET = REPO / "professional-media/fbbdcb9b9eb07999d6891eb900d07ab84de5b9946913c55b6cde36d92b7c9eb3.png"


def digest(path):
    return sha256(path.read_bytes()).hexdigest()


def write_json(name, value):
    with (ROOT / name).open("x", encoding="utf-8", newline="\n") as output:
        json.dump(value, output, indent=2, ensure_ascii=True)
        output.write("\n")


def save_image(image, name):
    with (ROOT / name).open("xb") as output:
        image.save(output, format="PNG", optimize=True)


for folder in ["source-evidence", "size-study"]:
    (ROOT / folder).mkdir(exist_ok=True)

retrievals = []
for name, url in [
    ("source-evidence/icon-page.html", "https://3dicons.co/icons/f71a3e-bag?angle=dynamic"),
    ("source-evidence/library-v1-license-page.html", "https://old.3dicons.co/"),
    ("source-evidence/CC0-1.0-legalcode.txt", "https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt"),
]:
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=30) as response:
        body = response.read()
        decoded = body.decode("utf-8")
        if re.search(r"[\u3400-\u9fff]", decoded):
            raise ValueError("Non-English source content needs a narrower retained excerpt.")
        with (ROOT / name).open("xb") as output:
            output.write(body)
        retrievals.append({
            "requested_url": url,
            "final_url": response.url,
            "http_status": response.status,
            "retrieved_at_utc": datetime.now(timezone.utc).isoformat(),
            "retained_path": name,
            "bytes": len(body),
            "sha256": sha256(body).hexdigest(),
            "content_type": response.headers.get("Content-Type"),
        })

write_json("source-evidence/retrievals.json", retrievals)

source = Image.open(SOURCE).convert("RGBA")
original_metadata = Image.open(SOURCE)
alpha_bounds = source.getchannel("A").getbbox()
left, top, right, bottom = alpha_bounds
margin = 16
crop_bounds = [max(0, left - margin), max(0, top - margin),
               min(source.width, right + margin), min(source.height, bottom + margin)]
cropped = source.crop(crop_bounds)
cropped.thumbnail((512, 512), Image.Resampling.LANCZOS)
save_image(cropped, "size-study/bag-crop-512-study.png")

basket = Image.open(BASKET).convert("RGBA")
font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 13)
small_font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 11)
sheet = Image.new("RGB", (710, 340), "#edf0ed")
draw = ImageDraw.Draw(sheet)
draw.text((14, 12), "Source-image size study only - no native WordCard, badge, or delivery verification", font=font, fill="#253e34")
columns = [("Original 2400px", source), ("Crop + 512px study", cropped), ("Accepted basket reference", basket)]
rows = [
    ("Match area 102 x 52 | alpha 1.00", (102, 52), 1.0, "#fffef9"),
    ("Match area 102 x 52 | alpha 0.68", (102, 52), 0.68, "#e7f5e9"),
    ("Memory area 120 x 54 | alpha 1.00", (120, 54), 1.0, "#fffef9"),
    ("Memory area 120 x 54 | alpha 0.68", (120, 54), 0.68, "#e7f5e9"),
]
measurements = []
for col, (label, artwork) in enumerate(columns):
    x = 265 + col * 145
    draw.text((x - 8, 42), label, font=small_font, fill="#253e34")
    for row, (row_label, area_size, alpha, background) in enumerate(rows):
        y = 65 + row * 65
        if col == 0:
            draw.text((14, y + 18), row_label, font=small_font, fill="#253e34")
        fitted = ImageOps.contain(artwork, area_size, Image.Resampling.LANCZOS)
        fitted.putalpha(fitted.getchannel("A").point(lambda a: round(a * alpha)))
        area = Image.new("RGBA", area_size, background)
        position = ((area.width - fitted.width) // 2, (area.height - fitted.height) // 2)
        area.alpha_composite(fitted, position)
        sheet.paste(area.convert("RGB"), (x, y))
        measurements.append({"variant": label, "area_size": area_size, "image_size": fitted.size,
                             "alpha_multiplier": alpha, "background": background})

save_image(sheet, "size-study/source-size-comparison.png")
save_image(sheet.resize((2130, 1020), Image.Resampling.NEAREST), "size-study/source-size-comparison-3x.png")

write_json("size-study/measurements.json", {
    "scope": "Pillow image-only simulation. No Godot, native renderer, WordCard instantiation, test, or build was run.",
    "source": {"path": str(SOURCE.relative_to(ROOT)), "sha256": digest(SOURCE),
               "bytes": SOURCE.stat().st_size, "format": original_metadata.format,
               "mode": original_metadata.mode, "size": original_metadata.size,
               "frames": getattr(original_metadata, "n_frames", 1), "alpha_bounds": alpha_bounds,
               "source_render_metadata": original_metadata.info},
    "study_crop": {"path": "size-study/bag-crop-512-study.png", "sha256": digest(ROOT / "size-study/bag-crop-512-study.png"),
                   "crop_ltrb": crop_bounds, "source_pixel_margin": margin, "size": cropped.size,
                   "compressed_bytes": (ROOT / "size-study/bag-crop-512-study.png").stat().st_size,
                   "decoded_bytes": cropped.width * cropped.height * 8,
                   "status": "size_study_only_not_accepted_or_integrated"},
    "reference": {"path": str(BASKET.relative_to(REPO)).replace("\\", "/"), "sha256": digest(BASKET)},
    "measurements": measurements,
    "limitations": ["Pillow Lanczos differs from runtime texture sampling.",
                    "Matched alpha is simulated; match badge, border, pair tint, and feedback motion are absent.",
                    "Background colors are WordCard's default unmatched and unpaired matched fills.",
                    "The actual matched pair can use a different tint.",
                    "No production-loader, cache, release, readiness, or participant-recognition claim."],
})
print(json.dumps({"source_sha256": digest(SOURCE), "crop_size": cropped.size,
                  "crop_sha256": digest(ROOT / "size-study/bag-crop-512-study.png"),
                  "source_evidence_files": len(retrievals)}))
