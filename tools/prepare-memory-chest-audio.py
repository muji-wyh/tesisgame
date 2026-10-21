"""Adapt acquired Kenney recordings for the Memory chest's downward response.

Usage: python tools/prepare-memory-chest-audio.py "<Kenney collection>/Audio"
Requires FFmpeg with Rubber Band and NumPy. No synthesized audio is added.
"""

import argparse
import hashlib
import json
import subprocess
import wave
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
RATE = 44100
DESTINATION = "assets/audio/memory-chest"
SOURCES = {
    "descent": "Interface Sounds/Audio/minimize_006.ogg",
    "landing": "Impact Sounds/Audio/impactWood_medium_002.ogg",
}
PAGES = {
    "Interface Sounds": "https://kenney.nl/assets/interface-sounds",
    "Impact Sounds": "https://kenney.nl/assets/impact-sounds",
}


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def fade(samples, attack=0.004, release=0.025):
    result = samples.copy()
    first, last = round(attack * RATE), round(release * RATE)
    result[:first] *= np.linspace(0, 1, first)
    result[-last:] *= np.linspace(1, 0, last)
    return result


def level(samples, peak):
    return samples * peak / max(float(np.max(np.abs(samples))), 1e-9)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--check", action="store_true", help="Verify recorded delivery hashes and PCM format without rewriting assets")
    args = parser.parse_args()
    manifest_path = ROOT / "docs/assets/memory-chest-audio.json"
    if args.check:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        for source in manifest["sources"]:
            assert sha256((args.source / source["path"]).read_bytes()) == source["sha256"], source["path"]
        for asset in manifest["assets"]:
            target = ROOT / asset["destination"]
            assert sha256(target.read_bytes()) == asset["sha256"], target
            with wave.open(str(target), "rb") as stream:
                assert (stream.getnchannels(), stream.getsampwidth(), stream.getframerate()) == (1, 2, RATE), target
                assert stream.getnframes() == round(asset["seconds"] * RATE), target
                pcm = np.frombuffer(stream.readframes(stream.getnframes()), dtype="<i2")
                assert pcm[0] == 0 and pcm[-1] == 0 and np.max(np.abs(pcm.astype(np.int32))) < 32767, target
        print("Verified two Memory loss cues and their acquired source hashes.")
        return

    destination = ROOT / DESTINATION
    destination.mkdir(parents=True, exist_ok=True)

    def recording(name, filters):
        data = subprocess.check_output([
            "ffmpeg", "-v", "error", "-i", str(args.source / SOURCES[name]),
            "-af", filters, "-ar", str(RATE), "-ac", "1", "-f", "f32le", "-",
        ])
        return np.frombuffer(data, dtype="<f4").astype(np.float64)

    def descent(pitch):
        filters = "highpass=f=110,lowpass=f=1800,rubberband=tempo=1.1176470588:pitch=%s" % pitch
        samples = recording("descent", filters)
        count = round(0.34 * RATE)
        samples = np.pad(samples[:count], (0, max(0, count - len(samples))))
        return fade(level(samples, 0.62), release=0.030), filters

    assets = []
    for name, pitch, seconds in [("downgrade", 1.0, 0.36), ("lost", 0.7491535384, 0.50)]:
        samples = np.zeros(round(seconds * RATE))
        falling, filters = descent(pitch)
        samples[:len(falling)] = falling
        layers = [{"source": "descent", "at": 0, "seconds": 0.34, "filters": filters,
                   "peak": 0.62, "attack": 0.004, "release": 0.030}]
        if name == "lost":
            filters = "highpass=f=90,lowpass=f=950"
            landing = recording("landing", filters)[:round(0.16 * RATE)]
            landing = fade(level(landing, 0.24), attack=0.003, release=0.055)
            offset = round(0.34 * RATE)
            samples[offset:offset + len(landing)] += landing
            layers.append({"source": "landing", "at": 0.34, "seconds": 0.16, "filters": filters,
                           "peak": 0.24, "attack": 0.003, "release": 0.055})
        pcm = np.round(samples * 32767).astype("<i2")
        target = destination / f"{name}.wav"
        with wave.open(str(target), "wb") as stream:
            stream.setparams((1, 2, RATE, len(pcm), "NONE", "not compressed"))
            stream.writeframes(pcm.tobytes())
        measured = pcm.astype(np.float64) / 32767
        assets.append({"id": name, "destination": f"{DESTINATION}/{name}.wav", "seconds": seconds,
                       "sha256": sha256(target.read_bytes()), "bytes": target.stat().st_size,
                       "sampleRate": RATE, "channels": 1, "bitDepth": 16,
                       "peakDbfs": round(float(20 * np.log10(np.max(np.abs(measured)))), 4),
                       "rmsDbfs": round(float(20 * np.log10(np.sqrt(np.mean(measured ** 2)))), 4),
                       "layers": layers})

    for pack in PAGES:
        license_text = (args.source / pack / "License.txt").read_text(encoding="utf-8-sig")
        if "Kenney" not in license_text or "CC0" not in license_text:
            raise ValueError("Unverified license: " + pack)
        (destination / ("LICENSE-" + pack.lower().replace(" ", "-") + ".txt")).write_text(license_text, encoding="utf-8")
    manifest = {
        "collection": "Kenney Game Assets All-in-1 3.7.0 / Audio",
        "sources": [{"id": name, "path": path, "sha256": sha256((args.source / path).read_bytes()),
                     "creator": "Kenney", "url": PAGES[path.split("/")[0]], "license": "CC0-1.0",
                     "status": "Acquired from user-provided local collection; processed and integrated",
                     "animations": "Not applicable (audio)"} for name, path in SOURCES.items()],
        "processing": "FFmpeg float decode and low-pass filtering; Rubber Band duration and pitch adaptation; NumPy boundary fades and peak scaling; mono PCM16 at 44100 Hz",
        "timeline": "Descending cue starts on committed mismatch and ends at the 340 ms chest tier swap. Only final chest loss adds a low wood landing at 340 ms.",
        "runtime": "One bounded answer-feedback player, gain 0.48, pitch 1.0; replaces generic wrong cue on a real tier downgrade; ordinary wrong cue after the chest is already lost.",
        "review": "Source metadata, measured downward frequency trend, envelopes and output headroom inspected. Direct auditory input is unavailable; no subjective listening claim.",
        "assets": assets,
    }
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("Prepared two Memory chest loss cues, %d bytes total." % sum(asset["bytes"] for asset in assets))


if __name__ == "__main__":
    main()
