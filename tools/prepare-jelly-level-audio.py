"""Prepare deterministic level collection cues from acquired CC0 recordings.

Lv1 remains the user's approved fixed bubble pop. Active Lv2-Lv9 layer it with
Kenney recordings, without generated oscillators.
Use --acquire-from with the local Kenney Audio directory to restore originals.
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
SOURCE_DIR = ROOT / "docs/assets/sources/jelly-level-feedback"
DEST = ROOT / "assets/audio/jelly-match"
MANIFEST = ROOT / "docs/assets/jelly-level-feedback.json"
RATE = 44100
BASE_HASH = "17fc1d02e944481eda7f392e1a5a1a1b375693a2868692ff85966b19048e1b3a"
SOURCES = {
    "glass": ("Interface Sounds/Audio/glass_004.ogg", "948cbe625a35fbd9cf662a9de88b36a3ca63cdebe3f92df365306a8a252bac68"),
    "spark": ("Interface Sounds/Audio/glass_006.ogg", "d1b959d0a8107b25d643fb3ab96fd6efd05d69ae142ecbea7097063de091b0ca"),
    "chime": ("Interface Sounds/Audio/confirmation_003.ogg", "9cddaa348f8ba91a913dceb0f5b1b874379af0f5cce71a9df6cf2b744fbc60cd"),
    "rise": ("Interface Sounds/Audio/maximize_007.ogg", "43a38a0b0366e8a8e6193bf037af73aab35b45fc52c1fd5a75dc662f0e4a84a1"),
    "bell": ("Impact Sounds/Audio/impactBell_heavy_002.ogg", "5433bb18b0ebd45dd539f2867296a59f023465dc0c17cde19b20fb97b5687ac5"),
}
# source, start seconds, relative layer gain, pitch/rate multiplier
LAYERS = {
    2: [("pop", 0, 1, 1), ("spark", .028, .30, 1)],
    3: [("pop", 0, .95, 1), ("rise", .012, .38, 1), ("glass", .105, .22, 1.25)],
    4: [("pop", 0, .9, 1), ("bell", .008, .29, 1.4)] +
       [("spark", .045 + i * .047, .21 - i * .018, [1.0, 1.5, 1.25][i % 3]) for i in range(6)],
    5: [("pop", 0, .9, 1), ("glass", .014, .43, 1), ("glass", .198, .35, 1.5), ("spark", .24, .16, 1.25)],
    6: [("pop", 0, .85, 1), ("rise", .005, .40, .85), ("bell", .020, .30, 1)] +
       [("spark", .075 + i * .075, .20, [1.0, 1.25, 1.5, 2.0][i]) for i in range(4)],
    7: [("pop", 0, .85, 1), ("chime", .012, .35, .84), ("glass", .07, .22, .75),
        ("glass", .19, .26, 1.25), ("chime", .265, .16, 1.26)],
    8: [("pop", 0, .8, 1), ("bell", .006, .34, .84)] +
       [("chime", .075 + i * .125, .24 - i * .025, [1, 1.26, 1.5][i]) for i in range(3)] +
       [("spark", .16 + i * .053, .12, 1.5) for i in range(5)],
    9: [("pop", 0, .8, 1), ("bell", .006, .40, .75), ("rise", .018, .25, .75),
        ("chime", .085, .30, 1), ("chime", .275, .25, 1.5), ("glass", .39, .23, 2)] +
       [("spark", .10 + i * .062, .16 - i * .009, [1, 1.25, 1.5, 2][i % 4]) for i in range(10)],
}
NAMES = ["Pearl pop", "Twin ripple", "Spiral lift", "Firework bloom", "Double bloom",
         "Comet crown", "Aurora orbit", "Constellation shower", "Grand bouquet"]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def db(value):
    return float(20 * np.log10(max(float(value), 1e-12)))


def smooth(value):
    value = np.clip(value, 0, 1)
    return value * value * (3 - 2 * value)


def acquire(directory):
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    for _, (relative, expected) in SOURCES.items():
        source = directory / relative
        assert digest(source) == expected, f"Unexpected source: {source}"
        shutil.copyfile(source, SOURCE_DIR / source.name)
    for pack in ["Interface Sounds", "Impact Sounds"]:
        shutil.copyfile(directory / pack / "License.txt", SOURCE_DIR / (pack.lower().replace(" ", "-") + "-license.txt"))
    (SOURCE_DIR / ".gdignore").write_text("", encoding="utf-8")


def read_sources():
    assert digest(DEST / "collect-pop.wav") == BASE_HASH, "The approved Lv1 pop must remain unchanged."
    pop, rate = sf.read(DEST / "collect-pop.wav")
    assert rate == RATE
    result = {"pop": pop}
    for key, (relative, expected) in SOURCES.items():
        path = SOURCE_DIR / Path(relative).name
        assert digest(path) == expected, f"Altered source: {path}"
        decoded = subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(path),
                                           "-ac", "1", "-ar", str(RATE), "-f", "f64le", "-"])
        data = np.frombuffer(decoded, dtype="<f8").copy()
        above = np.flatnonzero(np.abs(data) > .004)
        data = data[max(0, int(above[0]) - 44):min(len(data), int(above[-1]) + 441)]
        data -= np.mean(data)
        time = np.arange(len(data)) / RATE
        data *= smooth(time / .001) * smooth((len(data) / RATE - time - 1 / RATE) / .018)
        data *= .45 / max(np.max(np.abs(data)), 1e-9)
        result[key] = data
    return result


def render(level, sources):
    mixed = np.zeros(round(1.4 * RATE))
    for source, when, gain, pitch in LAYERS[level]:
        data = sources[source]
        if pitch != 1:
            data = np.interp(np.arange(0, len(data) - 1, pitch), np.arange(len(data)), data)
        start = round(when * RATE)
        mixed[start:start + len(data)] += data * gain
    active = np.flatnonzero(np.abs(mixed) > .00003)
    mixed = mixed[:min(len(mixed), int(active[-1]) + 882)]
    mixed *= smooth(np.arange(len(mixed)) / 44) * smooth((len(mixed) - 1 - np.arange(len(mixed))) / 882)
    mixed *= 10 ** (-8.5 / 20) / np.max(np.abs(mixed))
    # Reserve headroom for the real 120 ms batch rhythm, not only solo playback.
    repeated = repeated_mix(mixed)
    mixed *= min(1.0, .77 / np.max(np.abs(repeated)))
    return mixed


def repeated_mix(data):
    delay = round(.12 * RATE)
    result = np.zeros(len(data) + delay * 11)
    for i in range(12):
        result[i * delay:i * delay + len(data)] += data * .90
    return result


def metrics(data):
    above = np.flatnonzero(np.abs(data) > .01)
    return {"seconds": round(len(data) / RATE, 6), "frames": len(data), "sample_rate": RATE,
            "channels": 1, "pcm_bits": 16, "peak_dbfs": round(db(np.max(np.abs(data))), 3),
            "rms_dbfs": round(db(np.sqrt(np.mean(data ** 2))), 3),
            "onset_minus_40_dbfs_seconds": round(int(above[0]) / RATE, 6),
            "batch_120ms_peak_dbfs": round(db(np.max(np.abs(repeated_mix(data)))), 3)}


def prepare_import(path):
    settings = path.with_suffix(path.suffix + ".import")
    if settings.exists():
        text = settings.read_text(encoding="utf-8")
        text, replaced = re.subn(r"^compress/mode=.*$", "compress/mode=0", text, flags=re.MULTILINE)
        assert replaced == 1, f"Unexpected WAV import settings: {settings}"
        settings.write_text(text, encoding="utf-8")
        return
    source = "res://" + path.relative_to(ROOT).as_posix()
    imported = "res://.godot/imported/" + path.name + "-" + hashlib.md5(source.encode()).hexdigest() + ".sample"
    settings.write_text(f'''[remap]

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
''', encoding="utf-8")


def generate():
    existing = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    sources = read_sources()
    audio = [{"level": 1, "name": NAMES[0], "cue": "pop", "path": "assets/audio/jelly-match/collect-pop.wav",
              "sha256": BASE_HASH, "processing": "Unchanged approved fixed pop", **metrics(sources["pop"])}]
    for level in range(2, 10):
        path = DEST / f"collect-lv{level}.wav"
        sf.write(path, render(level, sources), RATE, subtype="PCM_16")
        prepare_import(path)
        saved, _ = sf.read(path)
        audio.append({"level": level, "name": NAMES[level - 1], "cue": f"jelly-collect-lv{level}",
                      "path": path.relative_to(ROOT).as_posix(), "sha256": digest(path),
                      "layers": [{"source": source, "seconds": when, "gain": gain, "pitch_ratio": pitch}
                                 for source, when, gain, pitch in LAYERS[level]], **metrics(saved)})
    source_records = []
    for key, (relative, expected) in SOURCES.items():
        is_impact = relative.startswith("Impact")
        source_records.append({"id": key, "creator": "Kenney", "pack": "Impact Sounds 1.0" if is_impact else "Interface Sounds 1.0",
                               "source_page": "https://kenney.nl/assets/impact-sounds" if is_impact else "https://kenney.nl/assets/interface-sounds",
                               "license": "CC0-1.0", "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
                               "original_in_collection": relative,
                               "path": (SOURCE_DIR / Path(relative).name).relative_to(ROOT).as_posix(), "sha256": expected,
                               "status": "Acquired from the user's local Kenney All-in-1 3.7.0 collection; complete original preserved, adapted into level cues.",
                               "animations": "Not applicable; authored one-shot audio recording"})
    record = {"version": 1, "created_on": "2026-10-21", "name": "Jelly Words level collection feedback",
              "status": "Acquired existing production textures and CC0 audio prepared for the integrated level effect timeline.",
              "tool": "tools/prepare-jelly-level-audio.py", "runtime_script": "scripts/word_jelly_collection_fx.gd",
              "audio_sources": source_records,
              "base_pop": {"manifest": "docs/assets/jelly-collection-audio.json", "creator": "farfadet46", "license": "CC0-1.0", "sha256": BASE_HASH},
              "visual_sources": [
                  {"path": "assets/chests/particles/portal_glow.png", "creator": "Bobardo", "source": "Modern 2D Animated Chests Pack_FREE Demo 1.0.2",
                   "source_path": "Modern 2D Animated Chests Pack_FREE Demo 1.0.2/Particles/Textures/portal_glow.png", "license": "Standard Unity Asset Store EULA",
                   "license_url": "https://unity.com/legal/as-terms", "source_record": "assets/chests/manifest.json", "sha256": digest(ROOT / "assets/chests/particles/portal_glow.png"),
                   "status": "Previously acquired and integrated texture, inspected and reused", "animations": "Static authored wisp texture; collection animation authored in the game"},
                  {"paths": ["assets/chests/milestone/rays.png", "assets/chests/milestone/sparkle.png"], "creator": "Kenneth Foldal Moe (Archanor VFX)", "source": "Toon FX 1.52",
                   "source_page": "https://assetstore.unity.com/packages/vfx/particles/toon-fx-25601", "license": "Standard Unity Asset Store EULA", "license_url": "https://unity.com/legal/as-terms",
                   "source_record": "docs/assets/jelly-fragments.md", "sha256": [digest(ROOT / path) for path in ["assets/chests/milestone/rays.png", "assets/chests/milestone/sparkle.png"]],
                   "status": "Previously acquired private inputs, inspected and reused; shipped only inside the compiled game",
                   "animations": "Static radial streak and four-point sparkle textures; game-authored trajectories and fading, no Unity prefab imported"}],
              "processing": "Float decode; mono 44.1 kHz; trimmed boundaries with smooth fades; source sample layering, deterministic resampling and offsets; -8.5 dBFS maximum solo peak and 0.77 batch peak ceiling at 0.90 runtime gain. No synthesized oscillators or procedural sound placeholders.",
              "runtime": {"gain": .90, "pitch": 1.0, "clock": "Existing accepted collection pop boundary", "concurrency": "Eight protected higher-level channels preserve tails at 120 ms batch spacing; shared mute/pause cleanup and no reward callback"},
              "review": "Acquired texture source sheet visually inspected. Audio source format, identity, decoded waveform, onset, headroom and repeated batch mix checked; auditory taste and physical-device mixing require playback review.",
              "audio": audio}
    # This audio tool does not own hand-reviewed visual profiles, acquisition
    # evidence, or art direction. Preserve those fields when refreshing audio.
    audio_owned_fields = {"tool", "audio_sources", "base_pop", "processing", "audio", "runtime"}
    record.update({key: value for key, value in existing.items() if key not in audio_owned_fields})
    record["runtime"].update(existing.get("runtime", {}))
    record["runtime"].update({"active_levels": list(range(1, 10)), "archived_audio_levels": []})
    record["runtime"].pop("archive_note", None)
    MANIFEST.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    preview_dir = ROOT / "build/jelly-level-feedback"
    preview_dir.mkdir(parents=True, exist_ok=True)
    preview = np.zeros(round(9 * 2.0 * RATE))
    for asset in audio:
        data, _ = sf.read(ROOT / asset["path"])
        start = round(((asset["level"] - 1) * 2 + .20) * RATE)
        preview[start:start + len(data)] += data * .90
    sf.write(preview_dir / "levels-1-through-9.wav", preview, RATE, subtype="PCM_16")
    verify()


def verify():
    read_sources()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assert [entry["level"] for entry in manifest["audio"]] == list(range(1, 10))
    assert manifest["runtime"]["active_levels"] == list(range(1, 10))
    assert manifest["runtime"]["archived_audio_levels"] == []
    hashes = set()
    for entry in manifest["audio"]:
        path = ROOT / entry["path"]
        assert digest(path) == entry["sha256"], path
        data, rate = sf.read(path)
        assert rate == RATE and data.ndim == 1 and np.all(np.isfinite(data))
        assert data[0] == data[-1] == 0 and np.max(np.abs(data)) < .43
        assert np.max(np.abs(repeated_mix(data))) < .78
        measured = metrics(data)
        assert measured == {key: entry[key] for key in measured}
        assert measured["onset_minus_40_dbfs_seconds"] < .009
        assert sf.info(path).subtype == "PCM_16"
        imported = path.with_suffix(path.suffix + ".import").read_text(encoding="utf-8")
        for expected in ["compress/mode=0", "edit/normalize=false", "edit/trim=false", "edit/loop_mode=0", "force/8_bit=false"]:
            assert expected in imported, f"Changed import {path}: {expected}"
        hashes.add(entry["sha256"])
    assert len(hashes) == 9, "Every level must have a distinct asset, with the approved pop unchanged."
    assert digest(DEST / "collect-pop.wav") == BASE_HASH
    print("Verified 9 active level cues; approved Lv1 unchanged; all PCM16, prompt attacks and safe 120 ms batch headroom.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--acquire-from", type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.acquire_from:
        acquire(args.acquire_from)
    verify() if args.check else generate()
