#!/usr/bin/env python3
"""Prepare reproducible, source-derived Royal and Energy chest animation layers."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, __version__ as pillow_version


ROOT = Path(__file__).resolve().parents[1]
CANVAS = (1024, 1024)
CHECKSUMS = {
    "royal/closed.png": "5d56092692cfff431c49856c40237ae31285a8344b20ace4d375b901e201946d",
    "royal/open.png": "95c5d1710ba4d33dce489d7a782a4cd10ce6e7d6465f32c07afa55ccfb9631b3",
    "energy/closed.png": "fde353205c24986d7fdad4c72055b88b53eecc8987a6a407935b8b4933c2c1e8",
    "energy/open.png": "276af1f68e908556831be6d5a466c89f626834624828940f9a501f493070bc75",
}
GEOMETRY = {
    "royal": {
        "hinge": (540, 475),
        "mover": "latch",
        "mover_pivot": (316, 534),
        "lid_edge": [
            (0, 471), (48, 493), (78, 513), (103, 521), (190, 526),
            (230, 531), (397, 553), (433, 555), (474, 565), (507, 575),
            (646, 567), (676, 561), (784, 517), (816, 504), (1024, 485),
        ],
        "mover_outline": [
            (224, 505), (251, 506), (390, 521), (406, 531), (414, 541),
            (414, 684), (406, 700), (396, 708), (325, 741), (307, 742),
            (238, 695), (220, 676), (217, 537),
        ],
        "inner_edge": [
            (0, 267), (121, 262), (155, 304), (213, 389), (276, 448),
            (331, 460), (377, 463), (379, 486), (431, 492), (434, 471),
            (613, 487), (614, 507), (666, 516), (673, 497), (754, 502),
            (785, 507), (836, 507), (1024, 507),
        ],
        "cavity_outline": [
            (96, 514), (276, 438), (430, 450), (757, 490), (788, 513),
            (785, 545), (658, 599), (509, 614), (418, 592), (171, 561),
            (96, 549),
        ],
    },
    "energy": {
        "hinge": (600, 460),
        "mover": "core",
        "mover_pivot": (369, 648),
        "lid_edge": [
            (0, 539), (145, 558), (240, 584), (494, 621), (668, 637),
            (716, 616), (729, 608), (734, 575), (760, 560), (805, 543),
            (839, 568), (861, 554), (1024, 522),
        ],
        "mover_outline": [
            (353, 500), (389, 504), (425, 521), (458, 550), (482, 586),
            (494, 625), (498, 664), (489, 711), (469, 746), (433, 771),
            (391, 787), (354, 784), (321, 771), (291, 750), (267, 719),
            (249, 682), (239, 647), (241, 613), (250, 579), (267, 547),
            (291, 523), (323, 506),
        ],
        "inner_edge": [
            (0, 399), (352, 410), (373, 423), (418, 427), (416, 437),
            (485, 447), (489, 438), (505, 451), (698, 472), (705, 456),
            (763, 463), (784, 479), (853, 475), (899, 425), (1024, 425),
        ],
        "cavity_outline": [
            (143, 497), (352, 410), (792, 456), (859, 477), (861, 548),
            (813, 578), (669, 641), (494, 624), (243, 587), (145, 559),
        ],
        "cavity_back_edge": [
            (0, 548), (145, 501), (164, 490), (357, 438), (374, 434),
            (390, 437), (415, 441), (480, 449), (580, 460), (690, 473),
            (788, 483), (816, 486), (844, 491), (859, 497), (1024, 536),
        ],
    },
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def polygon(points: list[tuple[int, int]]) -> Image.Image:
    mask = Image.new("L", CANVAS)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    return mask


def above(edge: list[tuple[int, int]]) -> Image.Image:
    return polygon([(0, 0), (1024, 0), *reversed(edge)])


def masked(image: Image.Image, mask: Image.Image) -> Image.Image:
    result = image.copy()
    result.putalpha(ImageChops.multiply(image.getchannel("A"), mask))
    data = np.asarray(result).copy()
    data[data[:, :, 3] == 0, :3] = 0
    return Image.fromarray(data)


def sample_transform(source: Image.Image, matrix: tuple[float, ...]) -> Image.Image:
    return source.transform(CANVAS, Image.Transform.AFFINE, matrix,
                            resample=Image.Resampling.BICUBIC)


def blend_hidden_repair(source: Image.Image, repair: Image.Image,
                        mover: Image.Image) -> Image.Image:
    # Keep the outside edge's source paint; reconstruction reaches full
    # opacity inside the extracted part's small source-shadow margin.
    softened = mover.filter(ImageFilter.MinFilter(7)).filter(ImageFilter.GaussianBlur(2))
    softened = ImageChops.multiply(softened, mover)
    result = source.copy()
    result.paste(repair, (0, 0), softened)
    return result


def repair_royal(source: Image.Image, mover: Image.Image) -> Image.Image:
    """Extend nearby source silver panels behind the removable shield only."""
    # Continue a neighboring strip of silver and its sloping gold rim behind
    # the shield. Continuous affine sampling avoids tiled texture or seams.
    repair = sample_transform(source, (0.08, 0, 167, -0.145, 1, 26.3))
    cap = sample_transform(source, (0.10, 0, 412, 0.10, 1, -81))
    cap_mask = above([(0, 521), (1024, 666)])
    repair.paste(cap, (0, 0), cap_mask)
    return blend_hidden_repair(source, repair, mover)


def repair_energy(source: Image.Image, mover: Image.Image) -> Image.Image:
    """Continue the cap, body and sloping turquoise band behind the core."""
    # Compress a real neighboring front strip horizontally, preserving its
    # continuously changing illumination. Its affine vertical shear continues
    # both edges of the turquoise band along the original perspective.
    repair = sample_transform(source, (0.12, 0, 480, -0.15, 1, 77.5))
    return blend_hidden_repair(source, repair, mover)


def write_part(style: str, role: str, image: Image.Image, anchor: tuple[int, int],
               order: int) -> dict:
    bounds = image.getchannel("A").getbbox()
    if not bounds:
        raise ValueError(f"Empty {style}/{role} layer")
    trimmed = image.crop(bounds)
    path = ROOT / "assets/chests/rigs" / style / f"{role}.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    trimmed.save(path, optimize=False, compress_level=9)
    width, height = trimmed.size
    pivot = [(anchor[0] - bounds[0]) / width, (anchor[1] - bounds[1]) / height]
    # Deliberately retain full JSON precision: exact top-left reconstruction
    # avoids seams between complementary source masks.
    assert abs(anchor[0] - pivot[0] * width - bounds[0]) < 1e-9
    assert abs(anchor[1] - pivot[1] * height - bounds[1]) < 1e-9
    return {
        "name": role,
        "role": role,
        "texture": path.relative_to(ROOT).as_posix(),
        "pivot": pivot,
        "position": list(anchor),
        "order": order,
        "crop": list(bounds),
        "width": width,
        "height": height,
        "bytes": path.stat().st_size,
        "sha256": digest(path),
    }


def derive(style: str, images: dict[str, Image.Image]) -> tuple[dict, dict]:
    geometry = GEOMETRY[style]
    closed, opened = images[f"{style}/closed.png"], images[f"{style}/open.png"]
    lid_mask = above(geometry["lid_edge"])
    mover_mask = polygon(geometry["mover_outline"])
    # Include the existing source contact shadow with the moving hardware.
    # The same small margin permits a feathered repair behind its old place.
    mover_mask = mover_mask.filter(ImageFilter.MaxFilter(21))
    inner_mask = above(geometry["inner_edge"])
    repaired = (repair_royal if style == "royal" else repair_energy)(closed, mover_mask)
    # The stable front and footprint always come from the closed source. The
    # added cavity stays behind that front, inside the closed lid silhouette.
    cavity_mask = ImageChops.multiply(polygon(geometry["cavity_outline"]), lid_mask)
    # Underlap the original hinge hardware by eight pixels so subpixel motion
    # cannot reveal a transparent notch between the separately drawn layers.
    cavity_mask = ImageChops.multiply(cavity_mask,
                                     ImageChops.invert(inner_mask.filter(ImageFilter.MinFilter(17))))
    cavity_mask = ImageChops.multiply(cavity_mask, closed.getchannel("A"))
    if style == "energy":
        # Space exposes the entire rear rim when its magnetic cover detaches.
        # Hinge hardware and lower-lid slivers therefore belong only to the
        # inside lid, not the static cavity. Summer still shows these original
        # source pixels when its hinged inside surface becomes visible.
        above_rim = above(geometry["cavity_back_edge"])
        hinge_hardware = Image.new("L", CANVAS)
        hinge_draw = ImageDraw.Draw(hinge_hardware)
        hinge_draw.rectangle((410, 423, 500, 453), fill=255)
        hinge_draw.rectangle((695, 449, 790, 484), fill=255)
        hinge_pixels = ImageChops.multiply(ImageChops.multiply(cavity_mask, above_rim),
                                          hinge_hardware)
        inner_mask = ImageChops.lighter(inner_mask, hinge_pixels)
        cavity_mask = ImageChops.multiply(cavity_mask, ImageChops.invert(above_rim))
    cavity_source = opened.copy()
    if style == "royal":
        cavity_repair = sample_transform(opened, (0.16, 0, 397, 0.05, 1, -18))
        cavity_mover = polygon([(213, 516), (405, 525), (427, 589), (215, 575)])
    else:
        cavity_repair = sample_transform(opened, (0.12, 0, 480, -0.15, 1, 77.5))
        cavity_mover = polygon([(291, 548), (385, 543), (442, 566), (490, 620),
                                (496, 705), (235, 686), (242, 596)])
    cavity_source.paste(cavity_repair, (0, 0), cavity_mover)
    layers = {
        "body": masked(repaired, ImageChops.invert(lid_mask)),
        "interior": masked(cavity_source, cavity_mask),
        "lid_outer": masked(repaired, lid_mask),
        "lid_inner": masked(opened, inner_mask),
        geometry["mover"]: masked(closed, mover_mask),
    }
    # Do not double-paint the source mover: it is an independent physical part.
    # Repairs underneath are intentionally retained on the static surfaces.
    parts = []
    for role, order in [("lid_inner", 0), ("interior", 1), ("body", 2),
                        ("lid_outer", 3), (geometry["mover"], 4)]:
        anchor = geometry["hinge"] if role.startswith("lid_") else (512, 512)
        if role == geometry["mover"]:
            anchor = geometry["mover_pivot"]
        parts.append(write_part(style, role, layers[role], anchor, order))
    rig = {
        "canvas": list(CANVAS),
        "hinge": list(geometry["hinge"]),
        "closed_bounds": list(closed.getchannel("A").getbbox()),
        "parts": parts,
    }
    return rig, layers


def compose(layers: dict, mover: str, opened: bool) -> Image.Image:
    result = Image.new("RGBA", CANVAS)
    roles = ["lid_inner", "interior", "body"] if opened else ["interior", "body", "lid_outer"]
    for role in [*roles, mover]:
        result = Image.alpha_composite(result, layers[role])
    return result


def qa_sheet(style: str, layers: dict, originals: dict, output: Path) -> dict:
    mover = GEOMETRY[style]["mover"]
    closed = compose(layers, mover, False)
    opened = compose(layers, mover, True)
    closed.save(output / f"{style}-closed.png")
    opened.save(output / f"{style}-open.png")
    if style == "energy":
        detached_base = Image.new("RGBA", CANVAS)
        for role in ["interior", "body", mover]:
            detached_base = Image.alpha_composite(detached_base, layers[role])
        detached_base.save(output / "energy-detached-base.png")
    for role, layer in layers.items():
        layer.save(output / f"{style}-{role}-canvas.png")
    panels = [("Source closed", originals[f"{style}/closed.png"]),
              ("Layered closed", closed), ("Layered open", opened),
              ("Body", layers["body"]), ("Exterior lid", layers["lid_outer"]),
              ("Interior lid", layers["lid_inner"]), ("Cavity", layers["interior"]),
              (mover.title(), layers[mover])]
    size = 384
    sheet = Image.new("RGB", (size * 4, (size + 30) * 2), "#152539")
    draw = ImageDraw.Draw(sheet)
    for index, (label, panel) in enumerate(panels):
        x, y = index % 4 * size, index // 4 * (size + 30)
        draw.rectangle((x, y, x + size - 1, y + size + 29),
                       fill="#eaf0f6" if index % 2 == 0 else "#24374a")
        draw.text((x + 12, y + 9), label, fill="#192934" if index % 2 == 0 else "white")
        thumbnail = panel.resize((size, size), Image.Resampling.LANCZOS)
        sheet.paste(thumbnail, (x, y + 30), thumbnail)
    sheet.save(output / f"{style}-contact-sheet.png")
    original = np.asarray(originals[f"{style}/closed.png"]).copy()
    derived = np.asarray(closed).copy()
    # Compare visible, premultiplied color, not irrelevant transparent RGB.
    for pixels in [original, derived]:
        pixels[:, :, :3] = (pixels[:, :, :3].astype(np.uint16) * pixels[:, :, 3:4] // 255)
    difference = np.abs(original.astype(np.int16) - derived.astype(np.int16))
    return {
        "closed_mean_absolute_channel_error": round(float(difference.mean()), 6),
        "closed_changed_pixels": int(np.any(difference > 0, axis=2).sum()),
        "closed_pixels_over_8_levels_error": int(np.any(difference > 8, axis=2).sum()),
        "closed_original_alpha_bounds": list(originals[f"{style}/closed.png"].getchannel("A").getbbox()),
        "closed_derived_alpha_bounds": list(closed.getchannel("A").getbbox()),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--qa-dir", type=Path, default=ROOT / "build/chest-feel-assets")
    args = parser.parse_args()
    args.qa_dir.mkdir(parents=True, exist_ok=True)
    images = {}
    sources = []
    for relative, expected in CHECKSUMS.items():
        path = ROOT / "assets/chests" / relative
        actual = digest(path)
        if actual != expected:
            raise ValueError(f"Source checksum mismatch for {relative}: {actual}")
        images[relative] = Image.open(path).convert("RGBA")
        if images[relative].size != CANVAS:
            raise ValueError(f"Unexpected source canvas for {relative}")
        sources.append({"path": path.relative_to(ROOT).as_posix(), "sha256": actual})
    manifest = {
        "version": 1,
        "source": "Modern 2D Animated Chests Pack_FREE Demo 1.0.2",
        "coordinate_system": "top-left origin, y-down; normalized top-left pivots",
        "generator": "tools/prepare-chest-rigs.py",
        "pillow_version": pillow_version,
        "numpy_version": np.__version__,
        "sources": sources,
        "styles": {},
    }
    report = {"styles": {}, "source_checksums_verified": True}
    for style in GEOMETRY:
        rig, layers = derive(style, images)
        manifest["styles"][style] = rig
        report["styles"][style] = qa_sheet(style, layers, images, args.qa_dir)
        metrics = report["styles"][style]
        if metrics["closed_original_alpha_bounds"] != metrics["closed_derived_alpha_bounds"]:
            raise ValueError(f"Closed footprint changed for {style}")
        if metrics["closed_mean_absolute_channel_error"] > 0.005:
            raise ValueError(f"Closed artwork reconstruction drifted for {style}")
    manifest_path = ROOT / "assets/chests/rigs.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    report["derived_bytes"] = sum(part["bytes"] for rig in manifest["styles"].values() for part in rig["parts"])
    report["manifest_sha256"] = digest(manifest_path)
    (args.qa_dir / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    for relative, expected in CHECKSUMS.items():
        assert digest(ROOT / "assets/chests" / relative) == expected
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
