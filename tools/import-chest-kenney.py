"""Build the chest-only Foley bank from the user's local Kenney Audio collection.

Requires FFmpeg and NumPy. No synthesized oscillators or noise are added.
Usage: python tools/import-chest-kenney.py "<Kenney collection>/Audio"
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
DESTINATION = "assets/audio/chest-kenney"
DURATIONS = {
    "press": 0.11, "charge": 0.8, "step": 0.12, "step-detail": 0.15,
    "step-roll": 0.18, "cancel": 0.23, "opening": 0.21, "unlock": 0.075,
    "release": 1.44, "settle": 0.26, "reward": 0.56,
}
SOURCES = {
    "wood": "Impact Sounds/Audio/impactWood_light_000.ogg",
    "wood-detail": "Impact Sounds/Audio/impactWood_light_004.ogg",
    "wood-stop": "Impact Sounds/Audio/impactWood_medium_002.ogg",
    "latch": "RPG Audio/Audio/metalLatch.ogg",
    "friction": "RPG Audio/Audio/creak1.ogg",
    "hinge": "RPG Audio/Audio/doorOpen_1.ogg",
    "air": "Foley Sounds/Audio/Woosh/woosh8.ogg",
    "bloom": "Music Jingles/Audio (Steeldrum)/jingles-steel_00.ogg",
    "receipt": "Interface Sounds/Audio/confirmation_002.ogg",
}
PACK_PAGES = {
    "Impact Sounds": "https://kenney.nl/assets/impact-sounds",
    "RPG Audio": "https://kenney.nl/assets/rpg-audio",
    "Foley Sounds": "https://kenney.nl/assets/foley-sounds",
    "Music Jingles": "https://kenney.nl/assets/music-jingles",
    "Interface Sounds": "https://kenney.nl/assets/interface-sounds",
}


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def fade(samples, attack=0.001, release=0.012):
    samples = samples.copy()
    first = min(len(samples), round(attack * RATE))
    last = min(len(samples), round(release * RATE))
    if first:
        samples[:first] *= np.linspace(0, 1, first)
    if last:
        samples[-last:] *= np.linspace(1, 0, last)
    return samples


def level(samples, peak):
    return samples * (peak / max(float(np.max(np.abs(samples))), 1e-9))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    args = parser.parse_args()
    destination = ROOT / DESTINATION
    destination.mkdir(parents=True, exist_ok=True)
    decoded = {}
    used = {}
    layers = {}

    def recording(name, start=0, seconds=None, filters="", peak=1.0):
        key = (name, filters)
        if key not in decoded:
            command = ["ffmpeg", "-v", "error", "-i", str(args.source / SOURCES[name])]
            if filters:
                command += ["-af", filters]
            command += ["-ar", str(RATE), "-ac", "1", "-f", "f32le", "-"]
            decoded[key] = np.frombuffer(subprocess.check_output(command), dtype="<f4").astype(np.float64)
        begin = round(start * RATE)
        end = len(decoded[key]) if seconds is None else begin + round(seconds * RATE)
        samples = decoded[key][begin:end].copy()
        if not len(samples):
            raise ValueError(f"Empty source window: {name}")
        return level(samples, peak)

    def mix(cue, name, start=0, seconds=None, at=0, peak=1.0, filters="", attack=0.001, release=0.012):
        samples = fade(recording(name, start, seconds, filters, peak), attack, release)
        offset = round(at * RATE)
        count = min(len(samples), len(used[cue]) - offset)
        used[cue][offset:offset + count] += samples[:count]
        layers[cue].append({"source": name, "start": start, "seconds": seconds, "at": at,
                            "peak": peak, "filters": filters, "attack": attack, "release": release})

    for cue, seconds in DURATIONS.items():
        used[cue] = np.zeros(round(seconds * RATE))
        layers[cue] = []

    # The three short attacks gain latch detail without adding unscheduled beats.
    mix("press", "wood", seconds=0.11, filters="highpass=f=130,lowpass=f=3200")
    mix("step", "wood", seconds=0.12, filters="highpass=f=130,lowpass=f=3200")
    mix("step-detail", "wood-detail", seconds=0.15, peak=0.85, filters="highpass=f=130,lowpass=f=3800")
    mix("step-detail", "latch", start=0.032, seconds=0.095, at=0.004, peak=0.20, filters="lowpass=f=3800")
    mix("step-roll", "wood-detail", seconds=0.18, peak=0.8, filters="highpass=f=130,lowpass=f=4200")
    mix("step-roll", "latch", start=0.032, seconds=0.105, at=0.003, peak=0.33, filters="lowpass=f=4200")
    mix("step-roll", "air", start=0.105, seconds=0.09, at=0.009, peak=0.09, filters="lowpass=f=3000")

    # Overlap a steady friction window into a periodic bed; the scene supplies
    # the rising pitch/gain. Exclude the source's later isolated loud creak.
    grain = recording("friction", 0.12, 0.26, "highpass=f=400,lowpass=f=2200")
    window = np.sin(np.linspace(0, np.pi, len(grain))) ** 2
    weights = np.zeros(len(used["charge"]))
    for index in range(8):
        indices = (np.arange(len(grain)) + round(index * 0.1 * RATE)) % len(weights)
        used["charge"][indices] += grain * window
        weights[indices] += window
    used["charge"] /= np.maximum(weights, 0.001)
    layers["charge"] = [{"source": "friction", "start": 0.12, "seconds": 0.26,
                         "filters": "highpass=f=400,lowpass=f=2200", "processing":
                         "Eight periodic overlap-add grains, 100 ms hop, squared-sine window, normalized overlap weights"}]

    mix("cancel", "wood-stop", seconds=0.23, filters="highpass=f=150,lowpass=f=1700")
    mix("opening", "air", start=0.107, seconds=0.21, filters="lowpass=f=2100")
    # Brake quickly into the held breath; do not put a second rise in the pause.
    time = np.arange(len(used["opening"])) / RATE
    used["opening"] *= np.exp(-time / 0.022)
    mix("unlock", "latch", start=0.032, seconds=0.075, filters="highpass=f=700,lowpass=f=4300", release=0.010)

    # One material onset, a short hinge/air movement, then the original musical
    # decay. The receipt remains separate and only plays after a successful save.
    mix("release", "wood", seconds=0.12, peak=0.52, filters="highpass=f=120,lowpass=f=3000")
    mix("release", "hinge", start=0.12, seconds=0.56, at=0.006, peak=0.25,
        filters="highpass=f=170,lowpass=f=3300", attack=0.004, release=0.080)
    mix("release", "air", start=0.087, seconds=0.30, at=0.018, peak=0.20,
        filters="highpass=f=300,lowpass=f=3500", attack=0.008, release=0.060)
    mix("release", "bloom", at=0.025, peak=0.66, filters="highpass=f=170,lowpass=f=5000",
        attack=0.014, release=0.045)
    mix("settle", "wood-stop", seconds=0.26, peak=1.0, filters="highpass=f=130,lowpass=f=2400")
    mix("reward", "receipt", filters="highpass=f=200,lowpass=f=4800", release=0.032)

    peaks = {"press": 0.40, "charge": 0.46, "step": 0.58, "step-detail": 0.60,
             "step-roll": 0.63, "cancel": 0.36, "opening": 0.24, "unlock": 0.68,
             "release": 0.72, "settle": 0.48, "reward": 0.60}
    assets = []
    for cue, samples in used.items():
        samples = level(fade(samples, 0.0005 if cue == "charge" else 0.001,
                             0.0005 if cue == "charge" else 0.010), peaks[cue])
        pcm = np.round(samples * 32767).astype("<i2")
        target = destination / f"{cue}.wav"
        with wave.open(str(target), "wb") as output:
            output.setparams((1, 2, RATE, len(pcm), "NONE", "not compressed"))
            output.writeframes(pcm.tobytes())
        data = target.read_bytes()
        measured = pcm.astype(np.float64) / 32767
        assets.append({"id": cue, "destination": f"{DESTINATION}/{cue}.wav",
                       "sha256": sha256(data), "bytes": len(data), "seconds": DURATIONS[cue],
                       "sampleRate": RATE, "channels": 1, "bitDepth": 16,
                       "peakDbfs": round(20 * np.log10(np.max(np.abs(measured))), 4),
                       "rmsDbfs": round(20 * np.log10(np.sqrt(np.mean(measured ** 2))), 4),
                       "layers": layers[cue], "outputPeak": peaks[cue],
                       "envelope": "Exponential 22 ms brake" if cue == "opening" else "Source envelope with boundary fades"})

    sources = []
    packs = sorted({source.split("/")[0] for source in SOURCES.values()})
    for pack in packs:
        license_text = (args.source / pack / "License.txt").read_text(encoding="utf-8-sig")
        if "CC0" not in license_text or "Kenney" not in license_text:
            raise ValueError(f"Unverified license: {pack}")
        (destination / f"LICENSE-{pack.replace(' ', '-').lower()}.txt").write_text(license_text, encoding="utf-8")
    for name, source in SOURCES.items():
        pack = source.split("/")[0]
        sources.append({"id": name, "path": source, "sha256": sha256((args.source / source).read_bytes()),
                        "creator": "Kenney", "url": PACK_PAGES[pack], "license": "CC0-1.0",
                        "status": "Acquired from user-provided local collection; processed and integrated",
                        "animations": "Not applicable (audio)"})
    manifest = {"collection": "Kenney Game Assets All-in-1 3.7.0 / Audio", "sources": sources,
                "processing": "FFmpeg float decode/filter, NumPy source layering/fades/peak scaling, mono PCM16 at 44100 Hz",
                "review": "Source metadata, waveform/envelope and actual runtime output measured. Direct auditory review unavailable in the agent tools; engine-mixed preview provided for listening.",
                "assets": assets}
    (ROOT / "docs/assets/chest-kenney-audio.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Built {len(assets)} chest cues from {len(sources)} Kenney sources ({sum(asset['bytes'] for asset in assets)} bytes).")


if __name__ == "__main__":
    main()
