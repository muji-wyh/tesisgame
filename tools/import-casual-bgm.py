"""Verify or restore the reviewed CC0 music from its original downloaded loops."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs/assets/casual-bgm.json"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path,
                        help="Directory containing the two extracted original music packs")
    parser.add_argument("--check", action="store_true", help="Verify existing game WAVs without importing")
    args = parser.parse_args()
    tracks = json.loads(MANIFEST.read_text(encoding="utf-8"))["files"]
    if args.check:
        for track in tracks:
            if digest(ROOT / track["path"]) != track["sha256"]:
                raise ValueError(f"The reviewed music changed: {track['path']}")
        print(f"Verified {len(tracks)} reviewed background tracks.")
        return
    if args.source_root is None:
        parser.error("Provide --source-root or --check.")
    for track in tracks:
        if digest(args.source_root / track["sourceFile"]) != track["sourceSha256"]:
            raise ValueError(f"Original source does not match: {track['sourceFile']}")
    # Validate every converted file before replacing any active game recording.
    (ROOT / "build").mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="casual-bgm-", dir=ROOT / "build") as staging:
        for track in tracks:
            converted = Path(staging) / f"{track['theme']}.wav"
            subprocess.run([
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-nostdin", "-n",
                "-i", str(args.source_root / track["sourceFile"]),
                "-af", (f"volume={track['gainDb']:.4f}dB,afade=t=in:d=0.003,"
                        f"afade=t=out:st={track['frames'] / 44100 - 0.003:.9f}:d=0.003"),
                "-ac", "2", "-ar", "44100",
                "-c:a", "pcm_s16le", "-map_metadata", "-1", "-fflags", "+bitexact", str(converted)
            ], check=True)
            if digest(converted) != track["sha256"]:
                raise ValueError("Conversion differs from the reviewed recording; check the manifest's FFmpeg version.")
        for track in tracks:
            (Path(staging) / f"{track['theme']}.wav").replace(ROOT / track["path"])
    print(f"Restored {len(tracks)} reviewed background tracks.")


if __name__ == "__main__":
    main()
