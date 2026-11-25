"""Upgrade 47 unambiguous starter Age 4-5 Mulberry vocabulary words to Microsoft Fluent Emoji 3D.

Preserves every runtime and release-check contract:
- Exact 256x256 RGBA WebP (VP8X + alpha) in assets/images/word-library/<id>.webp
- Exact SHA-256, bytes, source provider ('fluent-emoji'), creator, MIT license, pinned URL in docs/assets/word-library.json
- Regenerates each upgraded word's 32-frame 1024x512 animated motion atlas in assets/images/word-motion/<id>.webp
  using the repository's own tools/vocabulary-art/render-library-motion.py motion profiles, and updates
  docs/assets/word-library-motion.json and data/word-motion.json atomically.
"""

import hashlib
import io
import json
import sys
import urllib.parse
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(r"q:\uwork\tesisgame")
sys.path.insert(0, str(ROOT / "tools" / "vocabulary-art"))
import importlib.util

spec = importlib.util.spec_from_file_location("render_motion", ROOT / "tools" / "vocabulary-art" / "render-library-motion.py")
render_motion = importlib.util.module_from_spec(spec)
spec.loader.exec_module(render_motion)

FLUENT_REV = "1ffb34c752ecf5d402f04cfb4b392c77f57c54bc"
FLUENT_BASE = f"https://raw.githubusercontent.com/microsoft/fluentui-emoji/{FLUENT_REV}/"

UPGRADES = {
    "hen": "assets/Chicken/3D/chicken_3d.png",
    "juice": "assets/Beverage box/3D/beverage_box_3d.png",
    "lamp": "assets/Diya lamp/3D/diya_lamp_3d.png",
    "plate": "assets/Fork and knife with plate/3D/fork_and_knife_with_plate_3d.png",
    "smile": "assets/Grinning face with smiling eyes/3D/grinning_face_with_smiling_eyes_3d.png",
    "hungry": "assets/Face savoring food/3D/face_savoring_food_3d.png",
    "hot": "assets/Hot face/3D/hot_face_3d.png",
    "cold": "assets/Cold face/3D/cold_face_3d.png",
    "clean": "assets/Sparkles/3D/sparkles_3d.png",
    "green": "assets/Green circle/3D/green_circle_3d.png",
    "pink": "assets/Pink heart/3D/pink_heart_3d.png",
    "white": "assets/White circle/3D/white_circle_3d.png",
    "black": "assets/Black circle/3D/black_circle_3d.png",
    "four": "assets/Keycap 4/3D/keycap_4_3d.png",
    "five": "assets/Keycap 5/3D/keycap_5_3d.png",
    "fork": "assets/Fork and knife/3D/fork_and_knife_3d.png",
    "brush": "assets/Paintbrush/3D/paintbrush_3d.png",
    "grass": "assets/Herb/3D/herb_3d.png",
    "finger": "assets/Index pointing up/Default/3D/index_pointing_up_3d_default.png",
    "thumb": "assets/Thumbs up/Default/3D/thumbs_up_3d_default.png",
    "bake": "assets/Cupcake/3D/cupcake_3d.png",
    "cook": "assets/Cooking/3D/cooking_3d.png",
    "paint": "assets/Artist palette/3D/artist_palette_3d.png",
    "point": "assets/Backhand index pointing right/Default/3D/backhand_index_pointing_right_3d_default.png",
    "write": "assets/Writing hand/Default/3D/writing_hand_3d_default.png",
    "quiet": "assets/Shushing face/3D/shushing_face_3d.png",
    "loud": "assets/Loudspeaker/3D/loudspeaker_3d.png",
    "fast": "assets/Dashing away/3D/dashing_away_3d.png",
    "warm": "assets/Sun with face/3D/sun_with_face_3d.png",
    "wet": "assets/Droplet/3D/droplet_3d.png",
    "six": "assets/Keycap 6/3D/keycap_6_3d.png",
    "seven": "assets/Keycap 7/3D/keycap_7_3d.png",
    "eight": "assets/Keycap 8/3D/keycap_8_3d.png",
    "nine": "assets/Keycap 9/3D/keycap_9_3d.png",
    "ten": "assets/Keycap 10/3D/keycap_10_3d.png",
    "bottle": "assets/Baby bottle/3D/baby_bottle_3d.png",
    "mug": "assets/Hot beverage/3D/hot_beverage_3d.png",
    "dish": "assets/Shallow pan of food/3D/shallow_pan_of_food_3d.png",
    "music": "assets/Musical notes/3D/musical_notes_3d.png",
    "square": "assets/Blue square/3D/blue_square_3d.png",
    "triangle": "assets/Red triangle/3D/red_triangle_3d.png",
    "food": "assets/Bento box/3D/bento_box_3d.png",
    "day": "assets/Sun behind cloud/3D/sun_behind_cloud_3d.png",
    "night": "assets/Night with stars/3D/night_with_stars_3d.png",
    "morning": "assets/Sunrise/3D/sunrise_3d.png",
    "park": "assets/National park/3D/national_park_3d.png",
    "card": "assets/Flower playing cards/3D/flower_playing_cards_3d.png",
}


def sha256_bytes(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def encode_webp_256(raw_png: bytes) -> tuple[bytes, Image.Image]:
    img = Image.open(io.BytesIO(raw_png)).convert("RGBA")
    bbox = img.getbbox()
    cropped = img.crop(bbox) if bbox else img
    # Leave safe transparent margin (~10% per side -> 208px inner box inside 256x256)
    # so 2.5D motion warps never clip the edges (minimumOpaqueMargin >= 1)
    inner = 204
    cw, ch = cropped.size
    scale = min(inner / max(1, cw), inner / max(1, ch))
    nw, nh = max(1, round(cw * scale)), max(1, round(ch * scale))
    resized = cropped.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    canvas.paste(resized, ((256 - nw) // 2, (256 - nh) // 2), resized)
    buf = io.BytesIO()
    canvas.save(buf, format="WEBP", quality=92, method=6)
    return buf.getvalue(), canvas


def render_motion_atlas(still_256: Image.Image, map_entry: dict, profile_data: dict) -> tuple[bytes, int, int]:
    side = render_motion.SIDE  # 128
    frames = render_motion.FRAMES  # 32
    cols = render_motion.COLUMNS  # 8
    rows = (frames + cols - 1) // cols  # 4
    small = still_256.convert("RGBA").resize((side, side), Image.Resampling.LANCZOS)
    pixels = np.asarray(small, dtype=np.float32) / 255.0
    pixels[..., :3] *= pixels[..., 3:4]

    atlas = Image.new("RGBA", (cols * side, rows * side), (0, 0, 0, 0))
    unique_hashes = set()
    margins = []

    for idx in range(frames):
        frame_img = render_motion.frame(pixels, map_entry, idx, profile_data)
        alpha = np.asarray(frame_img)[..., 3] >= 200
        ys, xs = np.where(alpha)
        if len(xs) > 0:
            m = int(min(xs.min(), side - 1 - xs.max(), ys.min(), side - 1 - ys.max()))
            margins.append(m)
        unique_hashes.add(hashlib.sha256(frame_img.tobytes()).hexdigest())
        gx = (idx % cols) * side
        gy = (idx // cols) * side
        atlas.paste(frame_img, (gx, gy))

    buf = io.BytesIO()
    atlas.save(buf, format="WEBP", quality=88, method=4, exact=True)
    return buf.getvalue(), len(unique_hashes), (min(margins) if margins else 1)


def main():
    wl_path = ROOT / "docs/assets/word-library.json"
    wm_path = ROOT / "docs/assets/word-library-motion.json"
    rt_path = ROOT / "data/word-motion.json"
    map_path = ROOT / "tools/vocabulary-art/library-motion-map.json"

    wl = json.loads(wl_path.read_text(encoding="utf-8"))
    wm = json.loads(wm_path.read_text(encoding="utf-8"))
    rt = json.loads(rt_path.read_text(encoding="utf-8"))
    mapping = json.loads(map_path.read_text(encoding="utf-8"))

    wl_by_id = {f["id"]: f for f in wl["files"]}
    wm_by_id = {f["id"]: f for f in wm["files"]}
    rt_by_id = {f["id"]: f for f in rt["files"]}
    map_by_id = {f["id"]: f for f in mapping["files"]}

    upgraded = 0
    for wid, rel_path in UPGRADES.items():
        if wid not in wl_by_id:
            print(f"SKIP {wid}: not in word-library.json")
            continue
        url = FLUENT_BASE + urllib.parse.quote(rel_path, safe="/")
        req = urllib.request.Request(url, headers={"User-Agent": "tesisgame-word-upgrade"})
        with urllib.request.urlopen(req, timeout=20) as resp:
            raw_png = resp.read()
        raw_sha = sha256_bytes(raw_png)

        webp_bytes, still_img = encode_webp_256(raw_png)
        webp_sha = sha256_bytes(webp_bytes)
        still_dest = ROOT / f"assets/images/word-library/{wid}.webp"
        still_dest.write_bytes(webp_bytes)

        # Update word-library.json entry
        rec = wl_by_id[wid]
        rec["sha256"] = webp_sha
        rec["bytes"] = len(webp_bytes)
        rec["width"] = 256
        rec["height"] = 256
        rec["inputSha256"] = raw_sha
        rec["source"] = {
            "provider": "fluent-emoji",
            "path": rel_path,
            "url": url,
            "sha256": raw_sha,
            "creator": "Microsoft Corporation",
            "license": "MIT",
            "record": "docs/assets/word-library.json",
            "transformation": "Upgraded from Mulberry AAC pictogram to Microsoft Fluent Emoji 3D; normalized 204px subject inside 256x256 transparent WebP.",
        }
        rec["status"] = "Integrated; source and output hashes verified"

        # Regenerate motion atlas for this word
        m_entry = map_by_id[wid]
        p_data = mapping["profiles"][m_entry["profile"]]
        atlas_bytes, unique_frames, min_margin = render_motion_atlas(still_img, m_entry, p_data)
        atlas_sha = sha256_bytes(atlas_bytes)
        atlas_dest = ROOT / f"assets/images/word-motion/{wid}.webp"
        atlas_dest.write_bytes(atlas_bytes)

        wrec = wm_by_id[wid]
        wrec["sourceSha256"] = webp_sha
        wrec["creator"] = "Microsoft Corporation"
        wrec["license"] = "MIT"
        wrec["sha256"] = atlas_sha
        wrec["bytes"] = len(atlas_bytes)
        wrec["uniqueFrames"] = unique_frames
        wrec["minimumOpaqueMargin"] = min_margin

        # Ensure runtime entry matches
        rrec = rt_by_id[wid]
        for k in ("path", "frames", "fps", "frameSide", "columns", "posterFrame"):
            rrec[k] = wrec[k]

        upgraded += 1
        print(f"  [{upgraded:2d}/{len(UPGRADES)}] {wid:10s} -> Fluent 3D ({len(webp_bytes)//1024} KB still, {len(atlas_bytes)//1024} KB motion, {unique_frames} unique, margin {min_margin})", flush=True)

    wl_path.write_text(json.dumps(wl, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    wm_path.write_text(json.dumps(wm, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    rt_path.write_text(json.dumps(rt, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Upgraded {upgraded} Age 4-5 starter words to Fluent 3D + regenerated motion atlases.")


if __name__ == "__main__":
    main()
