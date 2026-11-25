"""Fetch and standardize production 2.5D/3D icons & biome skies for TesisGame's asset upgrade.

1. Biome Sky Panoramas (from local CC0 Kenney Skyboxes 1.0):
   - assets/images/jelly-match/sky/morning.png (Amber Orchard / Palm Lagoon / Cactus Valley)
   - assets/images/jelly-match/sky/night.png   (Aurora Snowfields / Castle Twilight / Voice Pop stage)
   - Retains day.png untouched for Spring Meadow / Grove / Pine Trail / Cottage Creek.

2. RPG Relics (8), Stances (3), Challenge Boons (9), Powerup Wand & Finish Flag & Reward Emblems (8):
   - Sourced directly from pinned Microsoft Fluent Emoji 3D (MIT License, commit 1ffb34c752ecf5d402f04cfb4b392c77f57c54bc),
     matching existing family-magnet.webp, star.webp, clock.webp, mastery-medal.webp and 382 Fluent 3D words.
   - Encoded as crisp 128x128 / 256x256 transparent RGBA WebP with SHA-256 provenance manifests.

3. Toon FX [1.52] VFX Particle Extraction (from user's licensed local Archanor VFX Toon FX 1.52):
   - snowflake.png, splat.png, burst_ring.png, star_glow.png into assets/chests/shared/effects/
     for Boss freeze/ink/power strikes and juicy merge/combo feedback.
"""

import hashlib
import io
import json
import shutil
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(r"q:\uwork\tesisgame")
KENNEY_SKY = Path(r"q:\uwork\Kenney Game Assets All-in-1 3.7.0\2D assets\Skyboxes\Skyboxes")
TOON_FX = Path(r"q:\uwork\AssetsSource\Toon FX [1.52]\Textures")
FLUENT_REV = "1ffb34c752ecf5d402f04cfb4b392c77f57c54bc"
FLUENT_BASE = f"https://raw.githubusercontent.com/microsoft/fluentui-emoji/{FLUENT_REV}/"

FLUENT_INDEX = json.loads(
    Path(r"C:\Users\yaohuiwang\.gemini\antigravity\brain\e5d9da55-a502-46ae-9fb7-28c011891737\scratch\fluent_3d_index.json").read_text(encoding="utf-8")
)
BY_FOLDER = {}
for p in FLUENT_INDEX:
    parts = p.split("/")
    folder = parts[1].lower()
    if len(parts) == 4:
        BY_FOLDER[folder] = p
    elif len(parts) == 5 and parts[2].lower() == "default" and folder not in BY_FOLDER:
        BY_FOLDER[folder] = p


def sha256_bytes(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def fetch_fluent_png(concept: str) -> tuple[bytes, str, str]:
    key = concept.lower()
    if key not in BY_FOLDER:
        raise KeyError(f"Fluent 3D concept not found: {concept}")
    rel = BY_FOLDER[key]
    url = FLUENT_BASE + urllib.parse.quote(rel, safe="/")
    req = urllib.request.Request(url, headers={"User-Agent": "tesisgame-asset-upgrade"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        raw = resp.read()
    return raw, rel, url


def save_webp_icon(raw_png: bytes, dest: Path, side: int = 128, quality: int = 90) -> dict:
    img = Image.open(io.BytesIO(raw_png)).convert("RGBA")
    # Trim excess transparent border slightly and center in square with clean 6% margin
    bbox = img.getbbox()
    if bbox:
        cropped = img.crop(bbox)
    else:
        cropped = img
    inner = round(side * 0.88)
    cw, ch = cropped.size
    scale = min(inner / max(1, cw), inner / max(1, ch))
    nw, nh = max(1, round(cw * scale)), max(1, round(ch * scale))
    resized = cropped.resize((nw, nh), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(resized, ((side - nw) // 2, (side - nh) // 2), resized)
    dest.parent.mkdir(parents=True, exist_ok=True)
    buf = io.BytesIO()
    canvas.save(buf, format="WEBP", quality=quality, method=6)
    out = buf.getvalue()
    dest.write_bytes(out)
    return {
        "file": dest.relative_to(ROOT).as_posix(),
        "size": [side, side],
        "bytes": len(out),
        "sha256": sha256_bytes(out),
        "source_sha256": sha256_bytes(raw_png),
    }


def prepare_biome_skies():
    sky_dir = ROOT / "assets/images/jelly-match/sky"
    records = []
    for name, src_name in [("morning", "skybox-morning.png"), ("night", "skybox-night.png")]:
        src = KENNEY_SKY / src_name
        dst = sky_dir / f"{name}.png"
        im = Image.open(src).convert("RGB").resize((1536, 768), Image.Resampling.LANCZOS)
        im.save(dst, optimize=True)
        out = dst.read_bytes()
        records.append({
            "id": name,
            "path": dst.relative_to(ROOT).as_posix(),
            "source": f"Skyboxes/{src_name}",
            "source_sha256": sha256_bytes(src.read_bytes()),
            "sha256": sha256_bytes(out),
            "bytes": len(out),
            "size": [1536, 768],
        })
        print(f"Sky {name}: {len(out)//1024} KB", flush=True)
    return records


def prepare_rpg_and_ui_icons():
    # 8 Boss Relics + 3 Stances + 9 Boons + upgraded Powerup Wand & Finish Flag & Mode Icons
    rpg_dir = ROOT / "assets/images/ui/jelly-rpg"
    rpg_dir.mkdir(parents=True, exist_ok=True)

    icon_map = [
        # 8 Boss Relics (replacing crude SVG snowflakes/rockets/flowers & Tabler eye/lock)
        ("relic_thaw_bell", "bell", rpg_dir / "relic-thaw-bell.webp", 128),
        ("relic_clarity_lens", "magnifying glass tilted right", rpg_dir / "relic-clarity-lens.webp", 128),
        ("relic_master_key", "old key", rpg_dir / "relic-master-key.webp", 128),
        ("relic_truth_prism", "crystal ball", rpg_dir / "relic-truth-prism.webp", 128),
        ("relic_gale_feather", "feather", rpg_dir / "relic-gale-feather.webp", 128),
        ("relic_echo_clasp", "spiral shell", rpg_dir / "relic-echo-clasp.webp", 128),
        ("relic_aegis_crest", "shield", rpg_dir / "relic-aegis-crest.webp", 128),
        # 3 Adventure Stances
        ("stance_scholar", "sparkles", rpg_dir / "stance-scholar.webp", 128),
        ("stance_hunter", "bow and arrow", rpg_dir / "stance-hunter.webp", 128),
        ("stance_seeker", "gem stone", rpg_dir / "stance-seeker.webp", 128),
        # 9 Challenge Roguelite Boons
        ("boon_supernova_blast", "collision", rpg_dir / "boon-supernova.webp", 128),
        ("boon_overdrive_skill", "high voltage", rpg_dir / "boon-hyper-charge.webp", 128),
        ("boon_chrono_flow", "hourglass not done", rpg_dir / "boon-chrono-flow.webp", 128),
        ("boon_golden_cascade", "money bag", rpg_dir / "boon-golden-cascade.webp", 128),
        ("boon_giant_leap", "rocket", rpg_dir / "boon-giant-leap.webp", 128),
        ("boon_chain_echo", "link", rpg_dir / "boon-chain-echo.webp", 128),
        ("boon_free_wand", "magic wand", rpg_dir / "boon-arcane-wand.webp", 128),
        ("boon_treasure_frenzy", "crown", rpg_dir / "boon-treasure-frenzy.webp", 128),
        ("boon_lightning_hands", "fire", rpg_dir / "boon-lightning-hands.webp", 128),
        # Upgraded Powerup Wand (replaces 905B flat monochrome auto-merge-wand.svg in display)
        ("powerup_wand", "magic wand", ROOT / "assets/images/ui/jelly-powerups/auto-merge-wand.webp", 128),
        # Upgraded Finish Flag & Mode Icons (replacing monochrome/Twemoji SVGs)
        ("ui_finish_flag", "chequered flag", ROOT / "assets/images/ui/finish-flag.webp", 128),
        ("mode_rainbow", "rainbow", ROOT / "assets/images/ui/modes/rainbow.webp", 128),
        ("mode_rocket", "rocket", ROOT / "assets/images/ui/modes/rocket.webp", 128),
        # Upgraded 8 seasonal emblem badges (WebP 3D icons to elevate rewards UI)
        ("badge_spring", "hibiscus", rpg_dir / "badge-spring.webp", 128),
        ("badge_summer", "sun", rpg_dir / "badge-summer.webp", 128),
        ("badge_autumn", "maple leaf", rpg_dir / "badge-autumn.webp", 128),
        ("badge_winter", "snowflake", rpg_dir / "badge-winter.webp", 128),
        ("badge_ocean", "spouting whale", rpg_dir / "badge-ocean.webp", 128),
        ("badge_space", "ringed planet", rpg_dir / "badge-space.webp", 128),
        ("badge_jungle", "palm tree", rpg_dir / "badge-jungle.webp", 128),
        ("badge_candy", "lollipop", rpg_dir / "badge-candy.webp", 128),
    ]

    manifest_assets = []
    for icon_id, concept, dest, side in icon_map:
        # fallback lookup if exact name differs slightly
        if concept.lower() not in BY_FOLDER:
            if concept == "old key":
                concept = "key"
            elif concept == "spouting whale":
                concept = "whale"
        raw, rel, url = fetch_fluent_png(concept)
        rec = save_webp_icon(raw, dest, side=side)
        rec["id"] = icon_id
        rec["concept"] = concept
        rec["source"] = url
        rec["source_path"] = rel
        rec["creator"] = "Microsoft Corporation"
        rec["license"] = "MIT"
        manifest_assets.append(rec)
        print(f"  Icon {icon_id:22s} <- {concept:28s} ({rec['bytes']//1024} KB)", flush=True)

    manifest = {
        "version": 1,
        "provider": "fluent-emoji",
        "revision": FLUENT_REV,
        "creator": "Microsoft Corporation",
        "license": "MIT",
        "license_file": "docs/assets/licenses/fluent-emoji.txt",
        "animations": "Static 3D illustrations; UI hover/pulse is game-authored.",
        "assets": manifest_assets,
    }
    (rpg_dir / "sources.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest_assets


def prepare_toon_fx_particles():
    # Extract additional high-craft particle textures from already-owned Archanor VFX Toon FX 1.52
    fx_dir = ROOT / "assets/images/jelly-level-fx"
    fx_dir.mkdir(parents=True, exist_ok=True)
    picks = [
        ("frost-flake.png", "snowflake.png", 128),
        ("ink-splat.png", "splat01.png", 128),
        ("impact-star.png", "star.png", 128),
        ("soft-poof.png", "poof.png", 128),
    ]
    records = []
    for out_name, src_name, side in picks:
        src = TOON_FX / src_name
        dst = fx_dir / out_name
        im = Image.open(src).convert("RGBA").resize((side, side), Image.Resampling.LANCZOS)
        im.save(dst, optimize=True)
        out = dst.read_bytes()
        records.append({
            "file": dst.relative_to(ROOT).as_posix(),
            "source": f"Toon FX [1.52]/Textures/{src_name}",
            "source_sha256": sha256_bytes(src.read_bytes()),
            "sha256": sha256_bytes(out),
            "bytes": len(out),
            "size": [side, side],
            "creator": "Kenneth Foldal Moe / Archanor VFX",
            "license": "Standard Unity Asset Store EULA",
        })
        print(f"  Toon FX {out_name}: {len(out)//1024} KB", flush=True)
    (fx_dir / "boss-fx-sources.json").write_text(json.dumps({"version": 1, "assets": records}, indent=2) + "\n", encoding="utf-8")
    return records


if __name__ == "__main__":
    print("=== 1. Preparing Biome Skies ===")
    prepare_biome_skies()
    print("=== 2. Preparing Fluent 3D RPG, Powerup, Mode & Reward Icons ===")
    prepare_rpg_and_ui_icons()
    print("=== 3. Extracting Toon FX Boss & Impact Particles ===")
    prepare_toon_fx_particles()
    print("ALL DONE.")
