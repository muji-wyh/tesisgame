"""Prepare one fixed bubble-pop collection cue from the acquired CC0 recording.

Requires FFmpeg, NumPy and SoundFile. The complete original OGG is preserved
with its source notice; no generated layers, transposition or time stretching.
"""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess

import numpy as np
import soundfile as sf


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/assets/sources/jelly-collection-audio/farfadet46-pop.ogg"
SOURCE_HASH = "d55886ec5b145045d1abd13926675b93646a8865e53e1f7a3a58cfbb7b733cff"
DESTINATION = ROOT / "assets/audio/jelly-match/collect-pop.wav"
MANIFEST = ROOT / "docs/assets/jelly-collection-audio.json"
RATE = 44100
SOURCE_OFFSET = 0.131
DURATION = 0.100
FRAMES = round(RATE * DURATION)
FILTERS = "highpass=f=65,lowpass=f=6500"
PEAK_DBFS = -7.5
SOURCE_PAGE = "https://opengameart.org/content/bubbles-pop"
SOURCE_DOWNLOAD = "https://opengameart.org/sites/default/files/pop.ogg"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def db(value):
    return float(20 * np.log10(max(float(value), 1e-12)))


def smooth(value):
    value = np.clip(value, 0, 1)
    return value * value * (3 - 2 * value)


def metrics(data):
    above = np.flatnonzero(np.abs(data) > 0.01)
    return {
        "seconds": len(data) / RATE,
        "sample_rate": RATE, "channels": 1, "pcm_bits": 16,
        "peak_dbfs": round(db(np.max(np.abs(data))), 3),
        "rms_dbfs": round(db(np.sqrt(np.mean(data * data))), 3),
        "onset_minus_40_dbfs_seconds": round(int(above[0]) / RATE, 6) if len(above) else None,
        "energy_before_next_batch_beat_percent": round(
            100 * np.sum(data[:round(0.120 * RATE)] ** 2) / np.sum(data ** 2), 3),
        "dc_offset": float(np.mean(data)),
    }


def render():
    decoded = subprocess.check_output([
        "ffmpeg", "-v", "error", "-i", str(SOURCE), "-af", FILTERS,
        "-ac", "1", "-ar", str(RATE), "-f", "f64le", "-",
    ])
    full = np.frombuffer(decoded, dtype="<f8")
    start = round(SOURCE_OFFSET * RATE)
    data = full[start:start + FRAMES].copy()
    if len(data) != FRAMES:
        raise ValueError("The acquired source does not contain the expected complete pop window.")
    data -= np.mean(data)
    time = np.arange(FRAMES) / RATE
    data *= smooth(time / 0.001) * smooth((DURATION - time - 1 / RATE) / 0.012)
    data *= 10 ** (PEAK_DBFS / 20) / np.max(np.abs(data))
    return data


def write_preview(clip):
    directory = ROOT / "build/jelly-collection-audio"
    directory.mkdir(parents=True, exist_ok=True)
    output = np.zeros(round(3.0 * RATE))
    # One isolated pop, then twelve identical pops at the real batch spacing.
    # This is an asset preview at gameplay gain, not an engine-mixed capture.
    for when in [0.2] + [1.0 + index * 0.12 for index in range(12)]:
        start = round(when * RATE)
        output[start:start + FRAMES] += clip * 0.90
    assert np.max(np.abs(output)) < 0.95
    sf.write(directory / "one-pop-and-rapid-collection.wav", output, RATE, subtype="PCM_16")


def generate():
    if digest(SOURCE) != SOURCE_HASH:
        raise ValueError("The acquired bubble-pop source differs from its recorded checksum.")
    sf.write(DESTINATION, render(), RATE, subtype="PCM_16")
    saved, _ = sf.read(DESTINATION)
    source = {
        "creator": "farfadet46", "title": "bubbles 'pop'", "page": SOURCE_PAGE,
        "download": SOURCE_DOWNLOAD, "license": "CC0-1.0",
        "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
        "path": SOURCE.relative_to(ROOT).as_posix(), "sha256": SOURCE_HASH,
        "status": "Complete original OGG downloaded on 2026-10-21, inspected and preserved locally; the adapted WAV is integrated.",
        "description": "Creator identifies this as a bubble-pop sound for games. Source is an authored sound effect, not claimed to be a physical bubble recording.",
        "animations": "Not applicable; one-shot audio recording",
    }
    record = {
        "version": 2, "created_on": "2026-10-21", "event": "pop",
        "modes": ["Jelly Words", "Jelly Match"],
        "status": "One acquired bubble-pop recording adapted and integrated into both modes' collection event.",
        "creator": "farfadet46; local trimming, filtering and level adjustment",
        "license": "CC0-1.0", "license_url": source["license_url"],
        "source": source, "recordings": [source],
        "animations": "Audio only; uses the existing manual, batch and fusion collection event boundaries.",
        "processing": {
            "tool": "tools/prepare-jelly-collection-audio.py",
            "ffmpeg": subprocess.check_output(["ffmpeg", "-version"], text=True).splitlines()[0],
            "description": "Float decode, mono conversion, silence trim, high-pass and low-pass filters, DC removal, smooth boundary fades and peak adjustment. Original authored pitch and speed; no generated, voice, musical or spring layers.",
            "source_offset_seconds": SOURCE_OFFSET, "seconds": DURATION,
            "ffmpeg_filter": FILTERS, "fade_in_seconds": 0.001, "fade_out_seconds": 0.012,
            "peak_ceiling_dbfs": PEAK_DBFS, "runtime_gain": 0.90, "runtime_pitch": 1.0,
            "pronunciation_duck_db": -6,
            "playback_sequence": "Use this same fixed recording once per accepted live pop event. No note sequence, pitch variation or random sample choice. Existing event timing is unchanged.",
        },
        "retired_assets": "The prior collect-do/re/mi/fa/sol/la/ti WAVs and clear.wav remain unchanged for historical provenance and independent fixtures; Jelly collection no longer uses them.",
        "verification": "Source and output hashes, PCM format, onset, headroom, zero boundaries and repeated 120 ms batch spacing checked by --check. Waveform checks do not establish subjective listening or physical-device preference.",
        "audio": [{"id": "collect-pop", "path": DESTINATION.relative_to(ROOT).as_posix(),
                   "sha256": digest(DESTINATION), "pitch_ratio": 1.0, **metrics(saved)}],
    }
    MANIFEST.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    write_preview(saved)
    verify()


def verify():
    record = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assert digest(SOURCE) == SOURCE_HASH, "The acquired original must remain unchanged."
    assert record["version"] == 2 and len(record["audio"]) == 1
    asset = record["audio"][0]
    assert asset["id"] == "collect-pop" and asset["pitch_ratio"] == 1.0
    assert record["processing"]["runtime_pitch"] == 1.0
    assert digest(DESTINATION) == asset["sha256"], DESTINATION
    info = sf.info(DESTINATION)
    assert (info.frames, info.samplerate, info.channels, info.subtype) == (FRAMES, RATE, 1, "PCM_16")
    data, _ = sf.read(DESTINATION)
    measured = metrics(data)
    assert measured == {key: asset[key] for key in measured}, DESTINATION
    assert np.all(np.isfinite(data)) and data[0] == data[-1] == 0
    assert measured["peak_dbfs"] <= -7.49 and abs(measured["dc_offset"]) < 0.001
    assert measured["onset_minus_40_dbfs_seconds"] < 0.008
    assert measured["energy_before_next_batch_beat_percent"] == 100.0
    delay = round(0.12 * RATE)
    repeated = np.zeros(FRAMES + 11 * delay)
    for index in range(12):
        repeated[index * delay:index * delay + FRAMES] += data * 0.90
    peak = float(np.max(np.abs(repeated)))
    assert peak < 0.95
    print(f"Verified one fixed 100 ms bubble pop; peak {measured['peak_dbfs']:.3f} dBFS; "
          f"120 ms batch peak {db(peak):.2f} dBFS.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    verify() if args.check else generate()
