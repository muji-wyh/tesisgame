"""Render seven short, diatonic collection cues from the acquired jelly recording.

Requires FFmpeg with Rubber Band, NumPy and SoundFile. No synthesized layers.
The original clear.wav is retained as the reproducible, licensed source master.
"""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess

import numpy as np
import soundfile as sf


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/audio/jelly-match/clear.wav"
SOURCE_HASH = "d53876591d14e97ff0db6a769525af180eb8a700c7727ccdc1349141421acc5f"
DEST = SOURCE.parent
MANIFEST = ROOT / "docs/assets/jelly-collection-audio.json"
RATE = 44100
DURATION = 0.240
FRAMES = round(RATE * DURATION)
NOTES = [("do", -5), ("re", -3), ("mi", -1), ("fa", 0),
         ("sol", 2), ("la", 4), ("ti", 6)]


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


def render(semitones):
    ratio = 2 ** (semitones / 12)
    filters = (
        f"rubberband=tempo={0.340 / DURATION:.12f}:pitch={ratio:.12f}:"
        "transients=crisp:detector=percussive:window=short:pitchq=quality,"
        "highpass=f=65,lowpass=f=6500"
    )
    decoded = subprocess.check_output([
        "ffmpeg", "-v", "error", "-i", str(SOURCE), "-af", filters,
        "-ac", "1", "-ar", str(RATE), "-f", "f64le", "-",
    ])
    data = np.frombuffer(decoded, dtype="<f8").copy()
    data = np.pad(data, (0, max(0, FRAMES - len(data))))[:FRAMES]
    data -= np.mean(data)
    time = np.arange(FRAMES) / RATE
    # An immediate gel transient followed by a damped tail leaves the next
    # 120 ms batch onset distinct, without adding a sequencer or delaying input.
    data *= np.exp(-9.0 * np.maximum(0, time - 0.030))
    data *= smooth(time / 0.002) * smooth((DURATION - time - 1 / RATE) / 0.045)
    return data, filters


def write_preview(clips):
    directory = ROOT / "build/jelly-collection-audio"
    directory.mkdir(parents=True, exist_ok=True)
    # A scale followed by two ascending cycles at the real batch spacing.
    # The second run demonstrates the same Ti-to-Do wrap as live collection.
    events = [(0.25 + index * 0.32, index) for index in range(7)]
    pattern = [index % len(NOTES) for index in range(14)]
    events += [(2.90 + index * 0.12, note) for index, note in enumerate(pattern)]
    output = np.zeros(round(4.80 * RATE))
    for when, note in events:
        start = round(when * RATE)
        # Include the existing gameplay collection gain.
        output[start:start + FRAMES] += clips[note] * 0.90
    assert np.max(np.abs(output)) < 0.95
    sf.write(directory / "seven-notes-and-rapid-collection.wav", output, RATE, subtype="PCM_16")


def generate():
    if digest(SOURCE) != SOURCE_HASH:
        raise ValueError("The preserved collection source differs from its recorded checksum.")
    source_record = json.loads((ROOT / "docs/assets/jelly-match.json").read_text(encoding="utf-8"))
    raw = [render(semitones) for _, semitones in NOTES]
    # One common RMS target also respects the original -7.5 dBFS peak ceiling.
    # Equal RMS is a technical match, not a claim of equal perceived loudness.
    target_rms = min(10 ** (-23.2 / 20), *(
        10 ** (-7.5 / 20) * np.sqrt(np.mean(data ** 2)) / np.max(np.abs(data))
        for data, _ in raw
    ))
    assets, clips = [], []
    for (note, semitones), (data, filters) in zip(NOTES, raw):
        data *= target_rms / np.sqrt(np.mean(data ** 2))
        destination = DEST / f"collect-{note}.wav"
        sf.write(destination, data, RATE, subtype="PCM_16")
        saved, _ = sf.read(destination)
        clips.append(saved)
        assets.append({
            "id": f"collect-{note}", "degree": note, "semitones_from_source": semitones,
            "semitones_from_do": semitones + 5, "pitch_ratio": 2 ** (semitones / 12),
            "path": destination.relative_to(ROOT).as_posix(), "sha256": digest(destination),
            "ffmpeg_filter": filters, **metrics(saved),
        })
    record = {
        "version": 1, "created_on": "2026-10-15", "event": "pop",
        "modes": ["Jelly Words", "Jelly Match"],
        "status": "Derived from acquired audio and integrated into both modes' collection event.",
        "creator": "rubberduck and Aeva; local editing and transposition for Jelly collection",
        "license": "CC0-1.0", "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
        "source": {"path": SOURCE.relative_to(ROOT).as_posix(), "sha256": SOURCE_HASH,
                   "provenance": "docs/assets/jelly-match.json",
                   "status": "Existing integrated 340 ms derivative retained unchanged as the source master."},
        "recordings": source_record["material_audio_sources"],
        "animations": "Audio only; uses the existing manual, batch and fusion collection event boundaries.",
        "scale": "Relative major scale: Do Re Mi Fa Sol La Ti, 0/2/4/5/7/9/11 semitones above Do. The source has elastic pitch motion; these are relative degrees, not concert-pitch C-major tones.",
        "processing": {"tool": "tools/prepare-jelly-collection-audio.py",
                       "ffmpeg": subprocess.check_output(["ffmpeg", "-version"], text=True).splitlines()[0],
                       "description": "Rubber Band transposition and time compression of the complete acquired composite recording; no oscillators, new recordings or cloud audio model.",
                       "seconds": DURATION, "fade_in_seconds": 0.002, "fade_out_seconds": 0.045,
                       "damping": "exp(-9 * max(0, t - 0.030))", "common_rms_dbfs": db(target_rms),
                       "runtime_gain": 0.90, "pronunciation_duck_db": -6,
                       "playback_sequence": "Do, Re, Mi, Fa, Sol, La, Ti, then repeat from Do. Start at Do and advance once per accepted live pop event. Preserve the next note through mute, pause and mode changes; suppressed cues do not advance. No changes to collection timing."},
        "verification": "PCM format, hashes, distinct samples, onset, headroom, zero boundaries and batch overlap checked by --check. Actual listening and physical-device preference are not established by waveform checks.",
        "audio": assets,
    }
    MANIFEST.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    write_preview(clips)
    verify()


def verify():
    record = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assert digest(SOURCE) == SOURCE_HASH, "The original cue must remain unchanged."
    assert len(record["audio"]) == 7
    assert len({asset["sha256"] for asset in record["audio"]}) == 7
    clips, levels = [], []
    for index, asset in enumerate(record["audio"]):
        path = ROOT / asset["path"]
        assert digest(path) == asset["sha256"], path
        info = sf.info(path)
        assert (info.frames, info.samplerate, info.channels, info.subtype) == (FRAMES, RATE, 1, "PCM_16")
        data, _ = sf.read(path)
        measured = metrics(data)
        assert measured == {key: asset[key] for key in measured}, path
        assert np.all(np.isfinite(data)) and data[0] == data[-1] == 0
        assert measured["peak_dbfs"] <= -7.49 and abs(measured["dc_offset"]) < 0.001
        assert measured["onset_minus_40_dbfs_seconds"] < 0.008
        assert measured["energy_before_next_batch_beat_percent"] > 90
        assert asset["semitones_from_do"] == [0, 2, 4, 5, 7, 9, 11][index]
        levels.append(measured["rms_dbfs"])
        clips.append(data)
    assert max(levels) - min(levels) < 0.01
    # Every adjacent pair at the real 120 ms batch spacing retains headroom.
    peak = 0.0
    delay = round(0.12 * RATE)
    for first in clips:
        for second in clips:
            mix = np.pad(first, (0, delay)) + np.pad(second, (delay, 0))
            peak = max(peak, float(np.max(np.abs(mix * 0.90))))
    assert peak < 0.95
    print(f"Verified 7 unique 240 ms cues; RMS spread {max(levels) - min(levels):.3f} dB; "
          f"worst 120 ms batch overlap {db(peak):.2f} dBFS.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    verify() if args.check else generate()
