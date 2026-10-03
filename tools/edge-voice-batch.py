"""Synthesize the approved Ava profile with bounded, resumable Edge TTS requests."""

import argparse
import asyncio
import importlib.metadata
import json
import os
from pathlib import Path
import re
import sys
import uuid


EDGE_TTS_VERSION = "7.2.8"
PROFILE = {"voice": "en-US-AvaNeural", "rate": "-15%", "pitch": "+8Hz", "volume": "+0%"}
MAX_ATTEMPTS = 3
MAX_CONCURRENCY = 2
REQUEST_TIMEOUT_SECONDS = 60


def read_manifest(filename):
    manifest = json.loads(Path(filename).read_text(encoding="utf-8"))
    if manifest.get("edgeTtsVersion") != EDGE_TTS_VERSION or manifest.get("profile") != PROFILE:
        raise ValueError("The batch must use the approved Ava profile and pinned Edge TTS version.")
    cache = Path(manifest["cacheDirectory"])
    if not cache.is_absolute() or not cache.is_dir():
        raise ValueError("The batch cache must be an existing absolute directory.")
    requests = manifest.get("requests")
    if not isinstance(requests, list) or not requests:
        raise ValueError("The batch must contain at least one voice request.")
    seen = set()
    for request in requests:
        if not isinstance(request, dict) or not re.fullmatch(r"[a-z]+(?:-[a-z]+)*", request.get("id", "")):
            raise ValueError("Each voice request needs a safe catalog ID.")
        text = request.get("text", "")
        if not isinstance(text, str) or len(text) > 501 or not re.fullmatch(r"[A-Za-z][A-Za-z0-9 ,.!?'\-]*", text):
            raise ValueError("Each voice request needs short English text.")
        output = Path(request["output"])
        if not output.is_absolute() or output.parent.resolve() != cache.resolve() or not re.fullmatch(r"[a-f0-9]{64}\.mp3", output.name):
            raise ValueError("Voice output must be a keyed MP3 directly inside the batch cache.")
        if output in seen:
            raise ValueError("The batch contains duplicate output paths.")
        seen.add(output)
    return requests


async def synthesize(requests):
    import edge_tts

    pending = iter(requests)
    failed = asyncio.Event()
    errors = []
    completed = 0

    async def worker():
        nonlocal completed
        while not failed.is_set():
            request = next(pending, None)
            if request is None:
                return
            output = Path(request["output"])
            for attempt in range(1, MAX_ATTEMPTS + 1):
                temporary = output.with_name(output.name + "." + uuid.uuid4().hex + ".part")
                try:
                    communication = edge_tts.Communicate(
                        request["text"], **PROFILE, connect_timeout=10, receive_timeout=30
                    )
                    await asyncio.wait_for(communication.save(str(temporary)), timeout=REQUEST_TIMEOUT_SECONDS)
                    if not temporary.is_file() or temporary.stat().st_size == 0:
                        raise RuntimeError("Empty audio response")
                    os.replace(temporary, output)
                    completed += 1
                    if completed % 10 == 0 or completed == len(requests):
                        print(f"Edge TTS cached {completed}/{len(requests)} recordings.", flush=True)
                    break
                except Exception as error:
                    if attempt == MAX_ATTEMPTS:
                        failed.set()
                        errors.append(f"{request['id']} failed after {MAX_ATTEMPTS} attempts ({type(error).__name__}).")
                        return
                    print(f"Retrying {request['id']} ({attempt}/{MAX_ATTEMPTS - 1}; {type(error).__name__}).", flush=True)
                    await asyncio.sleep(2 ** attempt)
                finally:
                    temporary.unlink(missing_ok=True)

    await asyncio.gather(*(worker() for _ in range(MAX_CONCURRENCY)))
    if errors:
        raise RuntimeError(" ".join(errors) + " Completed MP3s remain cached for the next run.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True)
    args = parser.parse_args()
    requests = read_manifest(args.manifest)
    try:
        version = importlib.metadata.version("edge-tts")
    except importlib.metadata.PackageNotFoundError as error:
        raise RuntimeError("Install the pinned dependency with: python -m pip install -r tools/voice-requirements.txt") from error
    if version != EDGE_TTS_VERSION:
        raise RuntimeError(f"Expected edge-tts {EDGE_TTS_VERSION}, found {version}. Install tools/voice-requirements.txt.")
    asyncio.run(synthesize(requests))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
