"""Prepare the selected CC0 Jelly Squash artwork and Kenney interface cues."""

import argparse
import array
import colorsys
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import wave
import zipfile

from PIL import Image, __version__ as pillow_version


ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "docs/assets/jelly-match.json"
ARCHIVES = {
    "jelly.zip": "b6ae4b056a6c9025a5c7865bfca054cfb60cba997074c2ee252cd69d2cbe9131",
    "kenney-interface-sounds.zip": "f2193d072726d6758a5f7871b2dcc54dcce0d5c35c6f0a62f92549b327c81232",
}
PALETTES = {"coral": 0.0, "mint": 0.34, "sky": 0.50, "lilac": 0.72}
SOUNDS = {
    "merge": ("drop_002.ogg", -8.0),
    "clear": ("pluck_002.ogg", -6.0),
    "danger": ("question_001.ogg", -12.0),
}


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def relative(path):
    return path.relative_to(ROOT).as_posix()


def extract_verified(source_dir, name, destination):
    archive = source_dir / name
    if sha256(archive) != ARCHIVES[name]:
        raise ValueError(f"Unexpected source archive: {name}")
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as bundle:
        for entry in bundle.infolist():
            target = (destination / entry.filename).resolve()
            if not target.is_relative_to(destination.resolve()):
                raise ValueError(f"Unsafe archive member: {entry.filename}")
        bundle.extractall(destination)


def prepare_images(source):
    original = Image.open(source).convert("RGBA")
    if original.size != (297, 251):
        raise ValueError("The selected source must be the face-free Jelly (3).png")
    output = ROOT / "assets/images/jelly-match"
    output.mkdir(parents=True, exist_ok=True)
    records = []
    for color, hue_shift in PALETTES.items():
        pixels = []
        for red, green, blue, alpha in original.get_flattened_data():
            hue, saturation, value = colorsys.rgb_to_hsv(red / 255, green / 255, blue / 255)
            channels = colorsys.hsv_to_rgb((hue + hue_shift) % 1, saturation, value)
            # Lighten the acquired painting for picture/word legibility; retain
            # every original highlight, shaded contour, and alpha edge.
            pixels.append(tuple(round((channel * 0.54 + 0.46) * 255) for channel in channels) + (alpha,))
        recolored = Image.new("RGBA", original.size)
        recolored.putdata(pixels)
        canvas = Image.new("RGBA", (320, 320))
        canvas.paste(recolored, (11, 34))
        destination = output / f"gel-{color}.png"
        canvas.save(destination, optimize=True)
        records.append({"path": relative(destination), "sha256": sha256(destination),
                        "source": "png/separate/Jellies/Blank/Jelly (3).png", "source_sha256": sha256(source),
                        "size": [320, 320], "art_bounds": [11, 34, 297, 251],
                        "hue_shift_turns": hue_shift, "white_mix": 0.46})
    shutil.copyfile(ROOT / "assets/talk_quest/map/licenses/cc0-1.0.txt", output / "LICENSE-CC0.txt")
    return records


def prepare_sounds(source_dir):
    output = ROOT / "assets/audio/jelly-match"
    output.mkdir(parents=True, exist_ok=True)
    records = []
    for name, (source_name, target_peak_dbfs) in SOUNDS.items():
        source = source_dir / "Audio" / source_name
        decoded = subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(source),
                                           "-f", "f32le", "-ac", "1", "-ar", "44100", "-"])
        values = array.array("f")
        values.frombytes(decoded)
        peak = max(abs(value) for value in values)
        if peak <= 0 or not all(math.isfinite(value) for value in values):
            raise ValueError(f"Invalid source audio: {source_name}")
        gain = 10 ** (target_peak_dbfs / 20) / peak
        attack, release = 44, 441
        pcm = array.array("h", (round(value * gain * min(1, index / attack,
                              (len(values) - 1 - index) / release) * 32767)
                              for index, value in enumerate(values)))
        destination = output / f"{name}.wav"
        with wave.open(str(destination), "wb") as recording:
            recording.setparams((1, 2, 44100, len(pcm), "NONE", "not compressed"))
            recording.writeframes(pcm.tobytes())
        actual_peak = max(abs(value) for value in pcm) / 32768
        rms = (sum((value / 32768) ** 2 for value in pcm) / len(pcm)) ** 0.5
        onset = next((index for index, value in enumerate(pcm) if abs(value) / 32768 > 0.01), 0)
        records.append({"id": name, "path": relative(destination), "sha256": sha256(destination),
                        "source": "Audio/" + source_name, "source_sha256": sha256(source),
                        "seconds": round(len(pcm) / 44100, 6), "sample_rate": 44100, "channels": 1,
                        "pcm_bits": 16, "source_decoded_peak_dbfs": round(20 * math.log10(peak), 3),
                        "linear_gain": round(gain, 9), "peak_dbfs": round(20 * math.log10(actual_peak), 3),
                        "rms_dbfs": round(20 * math.log10(rms), 3), "onset_minus_40_dbfs_seconds": round(onset / 44100, 6),
                        "attack_frames": attack, "release_frames": release,
                        "pitch_shift": 0, "time_stretch": 1, "loop": False})
    shutil.copyfile(source_dir / "License.txt", output / "LICENSE-Kenney.txt")
    return records


def verify():
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    for record in manifest["images"] + manifest["audio"]:
        source = ROOT / record["path"]
        if sha256(source) != record["sha256"]:
            raise ValueError(f"Asset differs from its provenance record: {record['path']}")
    for record in manifest["images"]:
        image = Image.open(ROOT / record["path"])
        if image.mode != "RGBA" or image.size != (320, 320):
            raise ValueError(f"Invalid gel surface: {record['path']}")
    for record in manifest["audio"]:
        with wave.open(str(ROOT / record["path"]), "rb") as recording:
            if (recording.getnchannels(), recording.getsampwidth(), recording.getframerate()) != (1, 2, 44100):
                raise ValueError(f"Invalid cue format: {record['path']}")
            values = array.array("h")
            values.frombytes(recording.readframes(recording.getnframes()))
            if not values or values[0] != 0 or values[-1] != 0 or max(map(abs, values)) >= 32767:
                raise ValueError(f"Clipped or discontinuous cue: {record['path']}")
    print(f"Jelly Match assets verified: {len(manifest['images'])} sourced gel surfaces and {len(manifest['audio'])} non-clipping recorded cues.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, default=ROOT / "build/jelly-match-sources")
    parser.add_argument("--check", action="store_true")
    options = parser.parse_args()
    if options.check:
        verify()
        return
    source_dir = options.source_dir.resolve()
    extract_verified(source_dir, "jelly.zip", source_dir / "jelly")
    extract_verified(source_dir, "kenney-interface-sounds.zip", source_dir / "kenney-interface-sounds")
    manifest = {
        "version": 1, "acquired_on": "2026-10-09", "license": "CC0-1.0",
        "image_source": {"creator": "Zuhria Alfitra (pzUH), GameArt2D", "title": "Jelly Squash Free Sprites",
                         "page": "https://www.gameart2d.com/jelly-squash-free-sprites.html",
                         "download": "https://www.gameart2d.com/uploads/3/0/9/1/30917885/jelly.zip",
                         "license_page": "https://www.gameart2d.com/license.html", "archive_sha256": ARCHIVES["jelly.zip"],
                         "status": "Downloaded and inspected; four adapted PNG surfaces integrated",
                         "animations": "None included; static bodies and separate faces. Runtime deformation is authored separately."},
        "audio_source": {"creator": "Kenney", "title": "Interface Sounds 1.0",
                         "page": "https://kenney.nl/assets/interface-sounds",
                         "download": "https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip",
                         "archive_sha256": ARCHIVES["kenney-interface-sounds.zip"],
                         "status": "Downloaded, decoded and integrated; subjective listening approval remains separate"},
        "image_processing": {"tool": "Pillow", "version": pillow_version,
                             "description": "Hue adaptation and 46 percent white mix of acquired blank Jelly 3; source shading/alpha preserved; transparent square padding only."},
        "images": prepare_images(source_dir / "jelly/png/separate/Jellies/Blank/Jelly (3).png"),
        "audio": prepare_sounds(source_dir / "kenney-interface-sounds"),
        "reuse": {"chest_reward": "assets/imported-audio/chest-reference/reward.wav",
                  "provenance": "docs/assets/chest-reference-audio.json",
                  "chest_art": "Use the current theme's real closed chest through the existing chest renderer; archived rejected skins are not replacements."},
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    verify()


if __name__ == "__main__":
    main()
