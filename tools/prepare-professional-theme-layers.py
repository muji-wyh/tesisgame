"""Derive lossless review layers from an acquired-asset theme render.

This produces candidates only. It never edits a theme profile or changes its
readiness. The source renderer must retain the same camera, light and geometry
for every frame and write a repeated resting pose.
"""

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageOps


def image(path):
    result = Image.open(path).convert("RGBA")
    if result.size != (768, 768) or result.getchannel("A").getextrema() != (255, 255):
        raise ValueError(f"Expected an opaque 768-square source render: {path}")
    return result


def changed(a, b):
    channels = ImageChops.difference(a.convert("RGB"), b.convert("RGB")).split()
    return ImageChops.lighter(ImageChops.lighter(channels[0], channels[1]), channels[2])


def require_equal(a, b, description):
    if a.tobytes() != b.tobytes():
        raise ValueError(description)


def prepare(source, output, clip_id, fps):
    if output.exists():
        raise ValueError("Keep earlier outputs; select a new candidate directory.")
    names = ["environment-rest.png", "composition-rest.png", "loop-end.png"]
    names += [f"composite-{index:02d}.png" for index in range(16)]
    sources = {name: image(source / name) for name in names}
    environment, rest = sources[names[0]], sources[names[1]]
    frames = [sources[name] for name in names[3:]]
    require_equal(rest, sources["loop-end.png"], "The repeated rest pose contains temporal noise.")
    require_equal(rest, frames[0], "Frame zero must be the actual reduced-motion rest pose.")
    mask = changed(environment, rest).point(lambda value: 255 if value else 0)
    props = rest.copy()
    props.putalpha(mask)
    composed = Image.alpha_composite(environment, props)
    require_equal(composed, rest, "The static layers do not reconstruct every source pixel.")
    union = Image.new("L", rest.size)
    for frame in frames:
        union = ImageChops.lighter(union, changed(rest, frame))
    bounds = union.getbbox()
    if bounds is None:
        raise ValueError("The source frames contain no visible motion pixels.")
    left, top, right, bottom = bounds
    left, top = max(0, left - 8), max(0, top - 8)
    right, bottom = min(768, right + 8), min(768, bottom + 8)
    width, height = right - left, bottom - top
    if width > 192 or height > 256:
        raise ValueError(f"Motion exceeds the reviewed frame budget: {width}x{height}.")
    sheet = Image.new("RGBA", (width * 4, height * 4))
    for index, frame in enumerate(frames):
        patch = frame.crop((left, top, right, bottom))
        sheet.paste(patch, ((index % 4) * width, (index // 4) * height))
        reconstructed = composed.copy()
        reconstructed.paste(patch, (left, top))
        require_equal(reconstructed, frame, f"Motion frame {index} loses source pixels.")

    output.mkdir(parents=True)
    environment.save(output / "environment.png")
    props.save(output / "props.png")
    sheet.save(output / "motion-sheet.png")
    rest.save(output / "composition-rest.png")
    frames[0].save(output / "motion-review.gif", save_all=True,
                   append_images=frames[1:], duration=round(1000 / fps), loop=0)
    covers = []
    for viewport in [(320, 568), (390, 844), (844, 390), (1280, 800)]:
        scale = max(viewport[0] / 768, viewport[1] / 768)
        offset = ((viewport[0] - 768 * scale) / 2, (viewport[1] - 768 * scale) / 2)
        projected = [left * scale + offset[0], top * scale + offset[1], width * scale, height * scale]
        covers.append({"viewport": list(viewport), "motion_rect": projected,
                       "fully_inside": projected[0] >= 0 and projected[1] >= 0
                       and projected[0] + projected[2] <= viewport[0]
                       and projected[1] + projected[3] <= viewport[1]})
        ImageOps.fit(rest, viewport, method=Image.Resampling.LANCZOS).save(
            output / f"source-cover-{viewport[0]}x{viewport[1]}.png")
    assets = []
    for filename in ["environment.png", "props.png", "motion-sheet.png"]:
        path = output / filename
        dimensions = Image.open(path).size
        assets.append({"file": filename, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                       "compressed_bytes": path.stat().st_size, "width": dimensions[0],
                       "height": dimensions[1], "decoded_bytes": dimensions[0] * dimensions[1] * 8})
    report = {"schema": 1, "status": "candidate_pending_gameplay_visual_review",
              "source_directory": str(source),
              "sources": [{"file": name, "sha256": hashlib.sha256((source / name).read_bytes()).hexdigest()}
                          for name in names],
              "static_reconstruction_exact": True, "all_motion_reconstructions_exact": True,
              "loop_endpoint_exact": True, "motion_union_pixels": list(bounds),
              "crop_pixels": [left, top, width, height], "assets": assets,
              "decoded_bytes": sum(asset["decoded_bytes"] for asset in assets),
              "clip": {"id": clip_id, "columns": 4, "rows": 4, "frame_count": 16,
                       "rest_frame": 0, "frames_per_second": fps,
                       "rect": [left / 768, top / 768, width / 768, height / 768]},
              "cover_checks": covers,
              "limitations": "Source covers exclude game UI. The GIF is a review derivative. "
                              "No production integration, human recognition, audio or device acceptance."}
    (output / "layer-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: report[key] for key in ["status", "crop_pixels", "decoded_bytes", "cover_checks"]}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--clip-id", required=True)
    parser.add_argument("--fps", type=float, default=2)
    args = parser.parse_args()
    if not 0 < args.fps <= 60:
        parser.error("fps must be in (0, 60].")
    prepare(args.source_dir.resolve(), args.output.resolve(), args.clip_id, args.fps)
