"""Prepare the selected CC0 Jelly Squash artwork and material sound recordings."""

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
    "water-splash-slime-sfx.zip": "7cd39abb49d4362a37ba18dc0e454c7dc1d08029d4e5b683149046bc237b2eba",
}
BOING_SHA256 = "9c6af38ca79332ad3fa66ad1229179d2a91655c1157d3620e21ef676f54d9fdd"
PALETTES = {"coral": 0.0, "mint": 0.34, "sky": 0.50, "lilac": 0.72}
WHITE_CENTER = 0.40
WHITE_CONTOUR = 0.24
SATURATION_SCALE = 0.88
MINT_SATURATION_SCALE = 0.78
SOUNDS = {
    "danger": ("question_001.ogg", -12.0),
}
SAMPLE_RATE = 44100
MATERIAL_AUDIO_SOURCES = [
    {"creator": "rubberduck", "title": "40 CC0 water / splash / slime SFX",
     "page": "https://opengameart.org/content/40-cc0-water-splash-slime-sfx",
     "download": "https://opengameart.org/sites/default/files/water-splash-slime-sfx.zip",
     "archive_sha256": ARCHIVES["water-splash-slime-sfx.zip"], "license": "CC0-1.0",
     "status": "Original archive acquired; slime_09.ogg and slime_16.ogg adapted into merge, elastic clear, and soft landing cues",
     "description": "Creator's slime recordings; the pack is partly recorded from real slime",
     "animations": "Not applicable; one-shot audio recordings"},
    {"creator": "Aeva", "title": "BOING!", "page": "https://opengameart.org/content/boing",
     "download": "https://opengameart.org/sites/default/files/boing.flac",
     "sha256": BOING_SHA256, "license": "CC0-1.0",
     "status": "Original FLAC acquired; a short pitched and damped excerpt integrated under the clear's slime transient",
     "description": "Authored spring sound made with an Arturia MicroFreak; not rubber foley",
     "animations": "Not applicable; one-shot audio recording"},
]


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


def smoothstep(low, high, value):
    amount = min(1.0, max(0.0, (value - low) / (high - low)))
    return amount * amount * (3.0 - 2.0 * amount)


def prepare_images(source):
    original = Image.open(source).convert("RGBA")
    if original.size != (297, 251):
        raise ValueError("The selected source must be the face-free Jelly (3).png")
    output = ROOT / "assets/images/jelly-match"
    output.mkdir(parents=True, exist_ok=True)
    records = []
    for color, hue_shift in PALETTES.items():
        saturation_scale = MINT_SATURATION_SCALE if color == "mint" else SATURATION_SCALE
        pixels = []
        for index, (red, green, blue, alpha) in enumerate(original.get_flattened_data()):
            hue, saturation, value = colorsys.rgb_to_hsv(red / 255, green / 255, blue / 255)
            channels = colorsys.hsv_to_rgb((hue + hue_shift) % 1, saturation * saturation_scale, value)
            x = (index % original.width) / (original.width - 1)
            y = (index // original.width) / (original.height - 1)
            # Preserve a light reading area while recovering the source's outer
            # contour and foot. Continuous transitions retain the painted detail.
            center = smoothstep(0.08, 0.28, x) * smoothstep(0.08, 0.28, 1.0 - x)
            center *= 1.0 - smoothstep(0.80, 0.99, y)
            white_mix = WHITE_CONTOUR + (WHITE_CENTER - WHITE_CONTOUR) * center
            pixels.append(tuple(round((channel * (1.0 - white_mix) + white_mix) * 255)
                                for channel in channels) + (alpha,))
        recolored = Image.new("RGBA", original.size)
        recolored.putdata(pixels)
        canvas = Image.new("RGBA", (320, 320))
        canvas.paste(recolored, (11, 34))
        destination = output / f"gel-{color}.png"
        canvas.save(destination, optimize=True)
        records.append({"path": relative(destination), "kind": "gel_surface", "sha256": sha256(destination),
                        "source": "png/separate/Jellies/Blank/Jelly (3).png", "source_sha256": sha256(source),
                        "size": [320, 320], "art_bounds": [11, 34, 297, 251],
                        "hue_shift_turns": hue_shift, "saturation_scale": saturation_scale,
                        "white_mix": {"center": WHITE_CENTER, "contour": WHITE_CONTOUR,
                                      "horizontal_transition": [0.08, 0.28],
                                      "foot_transition": [0.80, 0.99],
                                      "interpolation": "smoothstep",
                                      "coordinates": "Normalized source artwork before transparent padding"}})
    shadow_source = source.parents[2] / "Shadow.png"
    shadow = Image.open(shadow_source)
    if shadow.mode != "RGBA" or shadow.size != (334, 150):
        raise ValueError("The contact shadow must be the acquired separate/Shadow.png")
    shadow_destination = output / "contact-shadow.png"
    shutil.copyfile(shadow_source, shadow_destination)
    records.append({"path": relative(shadow_destination), "kind": "contact_shadow",
                    "sha256": sha256(shadow_destination), "source": "png/separate/Shadow.png",
                    "source_sha256": sha256(shadow_source), "size": [334, 150],
                    "processing": "Unmodified original PNG; runtime placement, tint and opacity only",
                    "maximum_alpha": shadow.getchannel("A").getextrema()[1]})
    shutil.copyfile(ROOT / "assets/talk_quest/map/licenses/cc0-1.0.txt", output / "LICENSE-CC0.txt")
    return records


def decode_material(source, filters):
    decoded = subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(source),
                                       "-af", filters, "-f", "f32le", "-ac", "1", "-ar", str(SAMPLE_RATE), "-"])
    values = array.array("f")
    values.frombytes(decoded)
    peak = max(map(abs, values))
    if peak <= 0 or not all(math.isfinite(value) for value in values):
        raise ValueError(f"Invalid material recording: {source}")
    return [value / peak for value in values]


def pitched_layer(values, seconds, speed, offset=0.0):
    # Resample an acquired recording, preserving its material harmonics. The
    # clear's damped pitch motion follows elastic recoil, not a generated tone.
    output = []
    position = offset * SAMPLE_RATE
    for index in range(round(seconds * SAMPLE_RATE)):
        start = int(position)
        fraction = position - start
        value = values[start] * (1.0 - fraction) + values[start + 1] * fraction if start + 1 < len(values) else 0.0
        output.append(value)
        position += speed(index / SAMPLE_RATE) if callable(speed) else speed
    return output


def save_material_cue(name, values, peak_dbfs, attack, release, layers, processing):
    frames = len(values)
    faded = [value * min(1.0, index / (attack * SAMPLE_RATE),
                        (frames - 1 - index) / (release * SAMPLE_RATE)) for index, value in enumerate(values)]
    gain = 10 ** (peak_dbfs / 20.0) / max(map(abs, faded))
    pcm = array.array("h", (round(value * gain * 32767) for value in faded))
    destination = ROOT / "assets/audio/jelly-match" / f"{name}.wav"
    with wave.open(str(destination), "wb") as recording:
        recording.setparams((1, 2, SAMPLE_RATE, frames, "NONE", "not compressed"))
        recording.writeframes(pcm.tobytes())
    peak = max(map(abs, pcm)) / 32768
    rms = math.sqrt(sum((value / 32768) ** 2 for value in pcm) / frames)
    onset = next(index for index, value in enumerate(pcm) if abs(value) / 32768 > 0.01)
    return {"id": name, "path": relative(destination), "sha256": sha256(destination),
            "source": " + ".join(layer["source"] for layer in layers), "layers": layers,
            "processing": processing, "seconds": round(frames / SAMPLE_RATE, 6),
            "sample_rate": SAMPLE_RATE, "channels": 1, "pcm_bits": 16,
            "peak_dbfs": round(20 * math.log10(peak), 3), "rms_dbfs": round(20 * math.log10(rms), 3),
            "onset_minus_40_dbfs_seconds": round(onset / SAMPLE_RATE, 6),
            "attack_frames": round(attack * SAMPLE_RATE), "release_frames": round(release * SAMPLE_RATE),
            "loop": False}


def prepare_material_sounds(source_dir):
    slime = source_dir / "rubberduck-slime"
    boing = source_dir / "boing.flac"
    if sha256(boing) != BOING_SHA256:
        raise ValueError("Unexpected BOING! source recording")
    wet_filter = "highpass=f=85,lowpass=f=4300,acompressor=threshold=0.05:ratio=6:attack=0.1:release=35:makeup=1"
    skin_filter = "highpass=f=95,lowpass=f=3600,acompressor=threshold=0.05:ratio=6:attack=0.1:release=35:makeup=1"
    spring_filter = "highpass=f=90,lowpass=f=2400"
    wet = decode_material(slime / "slime_09.ogg", wet_filter)
    skin = decode_material(slime / "slime_16.ogg", skin_filter)
    spring = decode_material(boing, spring_filter)
    layer = lambda source, **processing: {"source": source.name, "source_sha256": sha256(source), **processing}
    merge_wet = pitched_layer(wet, 0.620, 0.94, 0.024)
    merge_skin = pitched_layer(skin, 0.620, 1.10, 0.004)
    merge = [value * (0.52 + 0.48 * smoothstep(0.0, 0.32, index / SAMPLE_RATE)) + merge_skin[index] * 0.14
             for index, value in enumerate(merge_wet)]
    records = [save_material_cue("merge", merge, -9.0, 0.006, 0.060,
        [layer(slime / "slime_09.ogg", filter=wet_filter, source_offset_seconds=0.024, playback_rate=0.94,
               gain_envelope="0.52 + 0.48 * smoothstep(0, 0.32, seconds)"),
         layer(slime / "slime_16.ogg", filter=skin_filter, source_offset_seconds=0.004, playback_rate=1.10, gain=0.14)],
        "Floating-point decode and filtering before per-layer peak normalization; wet pressure pulses swell through union, with a quiet immediate skin contact. Mix, edge fades, final peak normalization, mono PCM16.")]
    clear_skin = pitched_layer(skin, 0.340, 1.15, 0.004)
    clear_spring = pitched_layer(spring, 0.340,
        lambda t: 1.55 + 0.22 * math.exp(-6.0 * t) * math.sin(2.0 * math.pi * 9.0 * t) + 0.32 * math.exp(-14.0 * t))
    clear = [value * 0.76 + clear_spring[index] * 0.40 * math.exp(-6.5 * index / SAMPLE_RATE)
             for index, value in enumerate(clear_skin)]
    records.append(save_material_cue("clear", clear, -7.5, 0.0025, 0.055,
        [layer(slime / "slime_16.ogg", filter=skin_filter, source_offset_seconds=0.004, playback_rate=1.15, gain=0.76),
         layer(boing, filter=spring_filter, source_offset_seconds=0,
               playback_rate="1.55 + 0.22 * exp(-6t) * sin(2pi * 9t) + 0.32 * exp(-14t)",
               gain_envelope="0.40 * exp(-6.5t)")],
        "Floating-point decode and filtering before per-layer peak normalization; soft slime transient over an acquired spring's damped pitch recoil. Mix, edge fades, final peak normalization, mono PCM16. Starts at the existing 0.700-second release and ends before removal at 1.050 seconds."))
    landing_filter = "highpass=f=85,lowpass=f=1100,acompressor=threshold=0.07:ratio=4:attack=2:release=45:makeup=1"
    landing_skin = decode_material(slime / "slime_16.ogg", landing_filter)
    landing = [value * math.exp(-7.0 * index / SAMPLE_RATE)
               for index, value in enumerate(pitched_layer(landing_skin, 0.220, 0.86, 0.004))]
    records.append(save_material_cue("land", landing, -16.0, 0.016, 0.085,
        [layer(slime / "slime_16.ogg", filter=landing_filter, source_offset_seconds=0.004,
               playback_rate=0.86, gain_envelope="exp(-7t)")],
        "Recorded slime contact with a rounded attack, damped high frequencies and short soft tail; no spring or hard impact layer. Floating-point filtering, pitch resampling, damping, edge fades, -16 dBFS peak normalization and mono PCM16. Runtime gain 0.35; existing landing-group timing and speech ducking are preserved."))
    notice = "Jelly material audio sources (CC0 1.0)\n\n" + "\n\n".join(
        f"{source['title']} by {source['creator']}\n{source['page']}\n{source['description']}" for source in MATERIAL_AUDIO_SOURCES)
    notice += "\n\nLicense: https://creativecommons.org/publicdomain/zero/1.0/\nAdaptations: tools/import-jelly-match-assets.py; provenance: docs/assets/jelly-match.json\n"
    (ROOT / "assets/audio/jelly-match/LICENSE-Material-Audio.txt").write_text(notice, encoding="utf-8")
    return records


def prepare_sounds(source_dir):
    output = ROOT / "assets/audio/jelly-match"
    output.mkdir(parents=True, exist_ok=True)
    records = prepare_material_sounds(source_dir.parent)
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
        expected_size = (334, 150) if record["kind"] == "contact_shadow" else (320, 320)
        if image.mode != "RGBA" or image.size != expected_size or list(image.size) != record["size"]:
            raise ValueError(f"Invalid jelly artwork: {record['path']}")
        if record["kind"] == "contact_shadow" and record["sha256"] != record["source_sha256"]:
            raise ValueError("The acquired contact shadow must remain unmodified")
    for record in manifest["audio"]:
        with wave.open(str(ROOT / record["path"]), "rb") as recording:
            if (recording.getnchannels(), recording.getsampwidth(), recording.getframerate()) != (1, 2, 44100):
                raise ValueError(f"Invalid cue format: {record['path']}")
            values = array.array("h")
            values.frombytes(recording.readframes(recording.getnframes()))
            if not values or values[0] != 0 or values[-1] != 0 or max(map(abs, values)) >= 32767:
                raise ValueError(f"Clipped or discontinuous cue: {record['path']}")
    print(f"Jelly Match assets verified: {len(manifest['images'])} sourced artwork textures and {len(manifest['audio'])} non-clipping recorded cues.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, default=ROOT / "build/jelly-match-sources")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--images-only", action="store_true", help="Regenerate artwork while retaining existing audio files and provenance")
    options = parser.parse_args()
    if options.check:
        verify()
        return
    source_dir = options.source_dir.resolve()
    extract_verified(source_dir, "jelly.zip", source_dir / "jelly")
    if not options.images_only:
        extract_verified(source_dir, "kenney-interface-sounds.zip", source_dir / "kenney-interface-sounds")
        extract_verified(source_dir, "water-splash-slime-sfx.zip", source_dir / "rubberduck-slime")
    existing = json.loads(MANIFEST.read_text(encoding="utf-8")) if options.images_only else {}
    manifest = {
        "version": 3, "acquired_on": "2026-10-09", "license": "CC0-1.0",
        "image_source": {"creator": "Zuhria Alfitra (pzUH), GameArt2D", "title": "Jelly Squash Free Sprites",
                         "page": "https://www.gameart2d.com/jelly-squash-free-sprites.html",
                         "download": "https://www.gameart2d.com/uploads/3/0/9/1/30917885/jelly.zip",
                         "license_page": "https://www.gameart2d.com/license.html", "archive_sha256": ARCHIVES["jelly.zip"],
                         "status": "Downloaded and inspected; four adapted gel surfaces and an unmodified contact shadow integrated",
                         "animations": "None included; static bodies and separate faces. Runtime deformation is authored separately."},
        "audio_source": existing["audio_source"] if options.images_only else {"creator": "Kenney", "title": "Interface Sounds 1.0",
                         "page": "https://kenney.nl/assets/interface-sounds",
                         "download": "https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip",
                         "archive_sha256": ARCHIVES["kenney-interface-sounds.zip"],
                         "status": "Downloaded, decoded and integrated for the countdown warning; former drop/pluck feedback replaced by material recordings"},
        **({"material_audio_sources": existing["material_audio_sources"]} if "material_audio_sources" in existing
           else {} if options.images_only else {"material_audio_sources": MATERIAL_AUDIO_SOURCES}),
        "image_processing": {"tool": "Pillow", "version": pillow_version,
                             "description": "Acquired blank Jelly 3: hue variants, 88 percent source saturation (78 percent for mint), continuous 40 percent center to 24 percent contour white mix. Original silhouette, painted detail and alpha preserved. Separate contact shadow copied unchanged."},
        "images": prepare_images(source_dir / "jelly/png/separate/Jellies/Blank/Jelly (3).png"),
        "audio": existing["audio"] if options.images_only else prepare_sounds(source_dir / "kenney-interface-sounds"),
        "reuse": {"chest_reward": "assets/imported-audio/chest-reference/reward.wav",
                  "provenance": "docs/assets/chest-reference-audio.json",
                  "pick": {"path": "assets/imported-audio/ui-click/select.wav",
                           "provenance": "docs/assets/ui-click-audio.json"},
                  "release": {"path": "assets/imported-audio/chest-reference/step.wav",
                              "provenance": "docs/assets/chest-reference-audio.json"},
                  "chest_art": "Use the current theme's real closed chest through the existing chest renderer; archived rejected skins are not replacements."},
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    verify()


if __name__ == "__main__":
    main()
