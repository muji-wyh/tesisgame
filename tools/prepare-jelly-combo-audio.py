"""Adapt acquired Kenney CC0 recordings into short Jelly Words combo accents."""

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess

import numpy as np
import soundfile as sf


ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/audio/jelly-combo"
MANIFEST = ROOT / "docs/assets/jelly-combo-audio.json"
PREVIEW = ROOT / "build/qa/jelly-combo-2026-10-25/audio"
RATE = 44100
SOURCE_DIR = ROOT / "docs/assets/sources/jelly-level-feedback"
SOURCES = {
    "chime": ("confirmation_003.ogg", "9cddaa348f8ba91a913dceb0f5b1b874379af0f5cce71a9df6cf2b744fbc60cd"),
    "spark": ("glass_006.ogg", "d1b959d0a8107b25d643fb3ab96fd6efd05d69ae142ecbea7097063de091b0ca"),
}
# source, offset seconds, layer gain, rate multiplier
LAYERS = {
    "step": [("chime", 0, .72, 1), ("spark", 0, .12, 1)],
    "bright": [("chime", 0, .78, 1), ("spark", 0, .26, 1)],
    "crown": [("chime", 0, .70, 1), ("chime", .008, .25, 1.5), ("spark", 0, .32, 1)],
}
GAINS = [.40, .44, .48]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def smooth(value):
    value = np.clip(value, 0, 1)
    return value * value * (3 - 2 * value)


def read_sources():
    result = {}
    for key, (name, expected) in SOURCES.items():
        path = SOURCE_DIR / name
        assert digest(path) == expected, f"Unexpected acquired source: {path}"
        data = np.frombuffer(subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(path),
                             "-ac", "1", "-ar", str(RATE), "-f", "f64le", "-"]), dtype="<f8").copy()
        data -= np.mean(data)
        edge = np.arange(len(data))
        data *= smooth(edge / (RATE * .001)) * smooth((len(data) - 1 - edge) / (RATE * .015))
        data /= max(np.max(np.abs(data)), 1e-9)
        result[key] = data
    return result


def render(sources, name):
    mixed = np.zeros(round(.36 * RATE))
    last = 0
    for source, when, gain, pitch in LAYERS[name]:
        data = sources[source]
        if pitch != 1:
            data = np.interp(np.arange(0, len(data) - 1, pitch), np.arange(len(data)), data)
        start = round(when * RATE)
        mixed[start:start + len(data)] += data * gain
        last = max(last, start + len(data))
    mixed = mixed[:last]
    mixed *= smooth(np.arange(len(mixed)) / 44) * smooth((len(mixed) - 1 - np.arange(len(mixed))) / 441)
    mixed *= 10 ** (-10.5 / 20) / np.max(np.abs(mixed))
    return mixed


def profile(count):
    tier = 2 if count >= 8 else 1 if count >= 3 else 0
    return list(LAYERS)[tier], 2 ** (1 - np.exp(-(count - 1) / 14)), GAINS[tier]


def sequence(clips, count, spacing, with_collection=False):
    result = np.zeros(round((count * spacing + 1.5) * RATE))
    collection, _ = sf.read(ROOT / "assets/audio/jelly-match/collect-lv6.wav")
    for index in range(count):
        name, pitch, gain = profile(index + 1)
        data = clips[name]
        data = np.interp(np.arange(0, len(data) - 1, pitch), np.arange(len(data)), data) * gain
        start = round(index * spacing * RATE)
        result[start:start + len(data)] += data
        if with_collection:
            result[start:start + len(collection)] += collection * .9
    return result


def metrics(data):
    return {"seconds": round(len(data) / RATE, 6), "sample_rate": RATE, "channels": 1, "pcm_bits": 16,
            "peak_dbfs": round(float(20 * np.log10(max(np.max(np.abs(data)), 1e-12))), 3)}


def generate():
    sources = read_sources()
    DEST.mkdir(parents=True, exist_ok=True)
    spec = importlib.util.spec_from_file_location("level_audio", ROOT / "tools/prepare-jelly-level-audio.py")
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    records, clips = [], {}
    for name in LAYERS:
        path = DEST / f"{name}.wav"
        sf.write(path, render(sources, name), RATE, subtype="PCM_16")
        helper.prepare_import(path)
        data, _ = sf.read(path)
        clips[name] = data
        records.append({"name": name, "path": path.relative_to(ROOT).as_posix(), "sha256": digest(path),
                        "layers": [{"source": source, "seconds": when, "gain": gain, "pitch_ratio": pitch}
                                   for source, when, gain, pitch in LAYERS[name]], **metrics(data)})
    source_records = [{"id": key, "creator": "Kenney", "pack": "Interface Sounds 1.0",
                       "source_page": "https://kenney.nl/assets/interface-sounds", "license": "CC0-1.0",
                       "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
                       "license_file": "docs/assets/sources/jelly-level-feedback/interface-sounds-license.txt",
                       "path": (SOURCE_DIR / name).relative_to(ROOT).as_posix(), "sha256": expected,
                       "status": "Previously acquired from the user's Kenney All-in-1 3.7.0 collection; complete original preserved and reused.",
                       "animations": "Not applicable; authored one-shot audio recording"}
                      for key, (name, expected) in SOURCES.items()]
    record = {"version": 1, "created_on": "2026-10-25", "name": "Jelly Words combo accents",
              "tool": "tools/prepare-jelly-combo-audio.py", "runtime_script": "scripts/game_audio.gd",
              "audio_sources": source_records, "audio": records,
              "processing": "Full-source mono 44.1 kHz decode, DC removal, smooth edge fades, deterministic layering and resampling; PCM16 normalized to -10.5 dBFS. No generated oscillator or third-party game audio.",
              "runtime": {"cue": "jelly-combo-N", "tiers_begin": [1, 3, 8], "gains": GAINS,
                          "pitch_formula": "2 ^ (1 - exp(-(count - 1) / 14))", "pitch_ceiling": 2.0,
                          "channels": 3, "pronunciation_duck_db": -6, "batch_interval_seconds": .14},
              "mix_checks": {"24_combo_140ms": metrics(sequence(clips, 24, .14)),
                             "24_combo_and_lv6_140ms": metrics(sequence(clips, 24, .14, True))},
              "review": "Original hashes, licenses, decoded waveform, full source tails, bounded peak and 140 ms repeated mixes checked. Listening preview provided; this environment did not support audio ingestion, so no auditory or physical-device mix judgment is claimed."}
    MANIFEST.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    PREVIEW.mkdir(parents=True, exist_ok=True)
    preview = np.concatenate([sequence(clips, 12, .48), np.zeros(RATE // 2), sequence(clips, 24, .14)])
    sf.write(PREVIEW / "combo-progression.wav", preview, RATE, subtype="PCM_16")
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", str(PREVIEW / "combo-progression.wav"),
                    "-b:a", "128k", str(PREVIEW / "combo-progression.mp3")], check=True)
    verify()


def verify():
    sources = read_sources()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    clips = {}
    for entry in manifest["audio"]:
        path = ROOT / entry["path"]
        assert digest(path) == entry["sha256"], path
        data, rate = sf.read(path)
        assert rate == RATE and data.ndim == 1 and np.all(np.isfinite(data))
        assert data[0] == data[-1] == 0 and .30 < len(data) / RATE < .34
        assert np.max(np.abs(data)) < .30
        assert np.allclose(data, render(sources, entry["name"]), rtol=0, atol=1 / 32768), f"Regeneration differs: {path}"
        assert "compress/mode=0" in path.with_suffix(".wav.import").read_text(encoding="utf-8")
        clips[entry["name"]] = data
    assert np.max(np.abs(sequence(clips, 24, .14))) < .30
    assert np.max(np.abs(sequence(clips, 24, .14, True))) < .95
    print("Jelly combo audio: 2 source hashes, 3 PCM16 cues, bounded 140 ms combo/Lv6 mixes verified.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    verify() if args.check else generate()
