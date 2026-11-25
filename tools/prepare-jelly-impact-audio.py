"""Prepare deterministic Nintendo-style Jelly impact foley cues from acquired CC0 recordings.

Builds five short, prompt-onset mono 44.1 kHz PCM16 cues in assets/audio/jelly-impact/:
  - merge-snap.wav      : Crisp bubble-pop transient + soft rubbery body + warm harmonic tail
  - merge-thump.wav     : Round bouncy 140-220Hz punchy gel thump for high-level merges & pops
  - collect-charge.wav  : Playful upward inhale/swell before a Jelly pops
  - contact-snap.wav    : Crisp magnetic lock-in water-drop click when dragging over a valid match
  - wrong-bounce.wav    : Cartoon elastic double-boing recoil for rejected drops

All inputs are verified CC0-1.0 recordings from Kenney Interface/Impact Sounds and the project's
already-approved CC0 collect-pop.wav. No generated oscillators or third-party game rips.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

import numpy as np
import soundfile as sf


ROOT = Path(__file__).resolve().parents[1]
KENNEY_DEFAULT = ROOT.parent / "Kenney Game Assets All-in-1 3.7.0/Audio"
SOURCE_DIR = ROOT / "docs/assets/sources/jelly-impact"
DEST = ROOT / "assets/audio/jelly-impact"
MANIFEST = ROOT / "docs/assets/jelly-impact-audio.json"
RATE = 44100
BASE_POP = ROOT / "assets/audio/jelly-match/collect-pop.wav"
BASE_POP_HASH = "17fc1d02e944481eda7f392e1a5a1a1b375693a2868692ff85966b19048e1b3a"

KENNEY_SOURCES = {
    "soft_heavy": "Impact Sounds/Audio/impactSoft_heavy_001.ogg",
    "soft_med": "Impact Sounds/Audio/impactSoft_medium_002.ogg",
    "punch_med": "Impact Sounds/Audio/impactPunch_medium_001.ogg",
    "drop_1": "Interface Sounds/Audio/drop_002.ogg",
    "drop_2": "Interface Sounds/Audio/drop_004.ogg",
    "pluck_1": "Interface Sounds/Audio/pluck_001.ogg",
    "pluck_2": "Interface Sounds/Audio/pluck_002.ogg",
    "max_rise": "Interface Sounds/Audio/maximize_006.ogg",
    "bong": "Interface Sounds/Audio/bong_001.ogg",
    "confirm": "Interface Sounds/Audio/confirmation_002.ogg",
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def db(value: float) -> float:
    return float(20.0 * np.log10(max(float(value), 1e-12)))


def smooth(value: np.ndarray) -> np.ndarray:
    v = np.clip(value, 0.0, 1.0)
    return v * v * (3.0 - 2.0 * v)


def one_pole_lowpass(x: np.ndarray, cutoff_hz: float) -> np.ndarray:
    rc = 1.0 / (2.0 * np.pi * cutoff_hz)
    dt = 1.0 / RATE
    alpha = dt / (rc + dt)
    out = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha * (x[i] - acc)
        out[i] = acc
    return out


def resample_pitch(data: np.ndarray, pitch: float) -> np.ndarray:
    if abs(pitch - 1.0) < 1e-6:
        return data.copy()
    idx = np.arange(0.0, len(data) - 1.0, pitch)
    return np.interp(idx, np.arange(len(data)), data)


def decode_source(path: Path) -> np.ndarray:
    decoded = subprocess.check_output(
        ["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE), "-f", "f64le", "-"]
    )
    data = np.frombuffer(decoded, dtype="<f8").copy()
    data -= np.mean(data)
    peak = max(float(np.max(np.abs(data))), 1e-9)
    above = np.flatnonzero(np.abs(data) > peak * 0.015)
    if len(above) > 0:
        start = max(0, int(above[0]) - 22)
        end = min(len(data), int(above[-1]) + 441)
        data = data[start:end]
    edge = np.arange(len(data))
    data *= smooth(edge / 32.0) * smooth((len(data) - 1 - edge) / 360.0)
    data /= max(float(np.max(np.abs(data))), 1e-9)
    return data


def acquire(kenney_dir: Path) -> None:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    for key, rel in KENNEY_SOURCES.items():
        src = kenney_dir / rel
        if not src.exists():
            raise FileNotFoundError(f"Missing Kenney CC0 audio source: {src}")
        shutil.copyfile(src, SOURCE_DIR / src.name)
    for pack in ["Interface Sounds", "Impact Sounds"]:
        lic = kenney_dir / pack / "License.txt"
        if lic.exists():
            shutil.copyfile(lic, SOURCE_DIR / (pack.lower().replace(" ", "-") + "-license.txt"))
    (SOURCE_DIR / ".gdignore").write_text("", encoding="utf-8")


def read_sources() -> dict[str, np.ndarray]:
    assert digest(BASE_POP) == BASE_POP_HASH, "Approved collect-pop.wav must remain unchanged"
    pop, rate = sf.read(BASE_POP)
    assert rate == RATE
    pop = np.asarray(pop, dtype=np.float64)
    pop /= max(float(np.max(np.abs(pop))), 1e-9)
    result: dict[str, np.ndarray] = {"pop": pop}
    for key, rel in KENNEY_SOURCES.items():
        path = SOURCE_DIR / Path(rel).name
        result[key] = decode_source(path)
    return result


def mix_layers(layers: list[tuple[np.ndarray, float, float, float]], max_sec: float, target_dbfs: float) -> np.ndarray:
    buf = np.zeros(round(max_sec * RATE), dtype=np.float64)
    last = 0
    for clip, start_sec, gain, pitch in layers:
        seg = resample_pitch(clip, pitch) * gain
        start = round(start_sec * RATE)
        end = min(len(buf), start + len(seg))
        if end > start:
            buf[start:end] += seg[: end - start]
            last = max(last, end)
    active = np.flatnonzero(np.abs(buf[:last]) > 0.0002)
    if len(active) > 0:
        last = min(len(buf), int(active[-1]) + 441)
    out = buf[:last].copy()
    edge = np.arange(len(out))
    # 0.5ms de-click attack keeps transient razor-sharp (<2ms) while ensuring zero-start/end samples.
    out *= smooth(edge / 22.0) * smooth((len(out) - 1 - edge) / 441.0)
    peak = max(float(np.max(np.abs(out))), 1e-9)
    out *= (10.0 ** (target_dbfs / 20.0)) / peak
    out[0] = 0.0
    out[-1] = 0.0
    return out


def render_all(sources: dict[str, np.ndarray]) -> dict[str, np.ndarray]:
    # Round warm rubbery sub-body sculpted from real Kenney impactSoft/impactPunch recordings.
    warm_thump = one_pole_lowpass(sources["soft_heavy"], 320.0)
    warm_thump /= max(float(np.max(np.abs(warm_thump))), 1e-9)
    punch_body = one_pole_lowpass(sources["punch_med"], 480.0)
    punch_body /= max(float(np.max(np.abs(punch_body))), 1e-9)

    # 1. merge-snap.wav: crisp bubble pop at t=0 + rubbery soft body + joyful wooden/marimba pluck sparkle
    merge_snap = mix_layers(
        [
            (sources["pop"], 0.000, 0.92, 1.18),
            (sources["drop_1"], 0.000, 0.52, 1.12),
            (warm_thump, 0.004, 0.68, 0.94),
            (sources["pluck_2"], 0.012, 0.34, 1.06),
        ],
        max_sec=0.38,
        target_dbfs=-6.5,
    )

    # 2. merge-thump.wav: warm round Nintendo "ponk / boomp" weight layer for upgrades & collect pops
    merge_thump = mix_layers(
        [
            (warm_thump, 0.000, 0.95, 0.86),
            (punch_body, 0.000, 0.58, 0.90),
            (sources["soft_med"], 0.003, 0.38, 0.78),
            (sources["bong"], 0.006, 0.24, 1.08),
        ],
        max_sec=0.32,
        target_dbfs=-6.8,
    )

    # 3. collect-charge.wav: quick buoyant inhale/swell before the pop moment (fits inside 180ms!)
    charge_clip = sources["max_rise"][: round(0.17 * RATE)]
    collect_charge = mix_layers(
        [
            (charge_clip, 0.000, 0.78, 1.24),
            (sources["drop_2"], 0.000, 0.26, 0.92),
        ],
        max_sec=0.22,
        target_dbfs=-10.0,
    )

    # 4. contact-snap.wav: ultra-crisp magnetic water-drop tick on valid match lock
    contact_snap = mix_layers(
        [
            (sources["drop_1"], 0.000, 0.82, 1.32),
            (sources["pluck_1"], 0.003, 0.36, 1.45),
        ],
        max_sec=0.16,
        target_dbfs=-8.5,
    )

    # 5. wrong-bounce.wav: cartoon rubber double-boing recoil for rejected merge
    wrong_bounce = mix_layers(
        [
            (sources["soft_med"], 0.000, 0.75, 0.82),
            (sources["drop_2"], 0.002, 0.55, 0.76),
            (sources["drop_2"], 0.068, 0.42, 0.64),
        ],
        max_sec=0.28,
        target_dbfs=-8.0,
    )

    return {
        "merge-snap": merge_snap,
        "merge-thump": merge_thump,
        "collect-charge": collect_charge,
        "contact-snap": contact_snap,
        "wrong-bounce": wrong_bounce,
    }


def prepare_import(path: Path) -> None:
    settings = path.with_suffix(path.suffix + ".import")
    source = "res://" + path.relative_to(ROOT).as_posix()
    imported = "res://.godot/imported/" + path.name + "-" + hashlib.md5(source.encode()).hexdigest() + ".sample"
    if settings.exists():
        text = settings.read_text(encoding="utf-8")
        text, replaced = re.subn(r"^compress/mode=.*$", "compress/mode=0", text, flags=re.MULTILINE)
        if replaced == 1:
            settings.write_text(text.replace("\r\n", "\n"), encoding="utf-8", newline="\n")
            return
    content = f"""[remap]

importer="wav"
type="AudioStreamWAV"
path="{imported}"

[deps]

source_file="{source}"
dest_files=["{imported}"]

[params]

force/8_bit=false
force/mono=false
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode=0
edit/loop_begin=0
edit/loop_end=-1
compress/mode=0
"""
    settings.write_text(content, encoding="utf-8", newline="\n")


def metrics(data: np.ndarray) -> dict:
    above = np.flatnonzero(np.abs(data) > 0.01)
    onset = round(int(above[0]) / RATE, 6) if len(above) > 0 else 0.0
    return {
        "seconds": round(len(data) / RATE, 6),
        "frames": len(data),
        "sample_rate": RATE,
        "channels": 1,
        "pcm_bits": 16,
        "peak_dbfs": round(db(np.max(np.abs(data))), 3),
        "rms_dbfs": round(db(np.sqrt(np.mean(data**2))), 3),
        "onset_minus_40_dbfs_seconds": onset,
    }


def generate(kenney_dir: Path) -> None:
    acquire(kenney_dir)
    sources = read_sources()
    DEST.mkdir(parents=True, exist_ok=True)
    rendered = render_all(sources)
    audio_records = []
    for name, data in rendered.items():
        path = DEST / f"{name}.wav"
        sf.write(path, data, RATE, subtype="PCM_16")
        prepare_import(path)
        saved, _ = sf.read(path)
        audio_records.append(
            {
                "id": name,
                "path": path.relative_to(ROOT).as_posix(),
                "sha256": digest(path),
                **metrics(saved),
            }
        )
    source_records = []
    for key, rel in KENNEY_SOURCES.items():
        is_impact = rel.startswith("Impact")
        copied = SOURCE_DIR / Path(rel).name
        source_records.append(
            {
                "id": key,
                "creator": "Kenney",
                "pack": "Impact Sounds 1.0" if is_impact else "Interface Sounds 1.0",
                "source_page": "https://kenney.nl/assets/impact-sounds"
                if is_impact
                else "https://kenney.nl/assets/interface-sounds",
                "license": "CC0-1.0",
                "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
                "original_in_collection": rel,
                "path": copied.relative_to(ROOT).as_posix(),
                "sha256": digest(copied),
            }
        )
    manifest = {
        "version": 1,
        "created_on": "2026-11-25",
        "name": "Jelly Words Nintendo-grade tactile impact foley",
        "tool": "tools/prepare-jelly-impact-audio.py",
        "runtime_script": "scripts/game_audio.gd",
        "base_pop": {
            "path": "assets/audio/jelly-match/collect-pop.wav",
            "creator": "farfadet46",
            "license": "CC0-1.0",
            "sha256": BASE_POP_HASH,
        },
        "audio_sources": source_records,
        "audio": audio_records,
        "processing": "Float decode; mono 44.1 kHz PCM16; leading-silence trim (<2ms onset); lowpass body sculpting & deterministic CC0 layering; smooth zero endpoints. No oscillators.",
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    verify()


def verify() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    for entry in manifest["audio"]:
        path = ROOT / entry["path"]
        assert digest(path) == entry["sha256"], path
        data, rate = sf.read(path)
        assert rate == RATE and data.ndim == 1 and np.all(np.isfinite(data))
        assert data[0] == 0.0 and data[-1] == 0.0, f"Nonzero endpoints: {path}"
        assert metrics(data)["onset_minus_40_dbfs_seconds"] < 0.008, f"Slow attack: {path}"
        imp = path.with_suffix(path.suffix + ".import").read_text(encoding="utf-8")
        assert "compress/mode=0" in imp
    print(f"Verified {len(manifest['audio'])} Jelly impact foley cues (PCM16, prompt <8ms attack).")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--acquire-from", type=Path, default=KENNEY_DEFAULT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    verify() if args.check else generate(args.acquire_from)
