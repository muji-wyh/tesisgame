"""Inspect and prepare selected Unity Store PNGs; never extract untrusted paths/code."""
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import struct
import sys
import tarfile
import tempfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def safe_path(value):
    parts = value.split("/")
    require(value and not value.startswith("/") and "\\" not in value
            and ":" not in value and "\x00" not in value
            and all(part not in ("", ".", "..") for part in parts),
            f"Unsafe archive or asset path: {value!r}")
    return value


def read_package(filename):
    require(Path(filename).stat().st_size <= 512 * 1024 * 1024, "Package exceeds 512 MB")
    package_bytes = Path(filename).read_bytes()
    assets = {}
    with tarfile.open(fileobj=io.BytesIO(package_bytes), mode="r:gz") as archive:
        members = archive.getmembers()
        require(len(members) <= 20000 and sum(m.size for m in members) <= 512 * 1024 * 1024,
                "Expanded package exceeds inspection limits")
        seen = set()
        groups = {}
        for member in members:
            name = member.name.rstrip("/")
            safe_path(name)
            require(member.isdir() or member.isfile(), f"Unsafe linked/special archive member: {name}")
            require(name.casefold() not in seen, f"Duplicate archive member: {name}")
            seen.add(name.casefold())
            parts = name.split("/")
            if member.isfile() and len(parts) == 2 and re.fullmatch(r"[a-fA-F0-9]{32}", parts[0]):
                groups.setdefault(parts[0], {})[parts[1]] = member
        paths = set()
        for guid, files in groups.items():
            if "pathname" not in files:
                continue
            require(files["pathname"].size <= 4096, "Asset pathname exceeds limit")
            pathname = archive.extractfile(files["pathname"]).read().decode("utf-8-sig").splitlines()
            require(len(pathname) in (1, 2) and (len(pathname) == 1 or
                    re.fullmatch(r"[a-fA-F0-9]{32}", pathname[1])), "Malformed Unity asset pathname")
            source = pathname[0].strip()
            safe_path(source)
            require(source.startswith("Assets/"), f"Unsafe asset path outside Assets: {source}")
            require(source.casefold() not in paths, f"Duplicate asset path: {source}")
            paths.add(source.casefold())
            if PurePosixPath(source).suffix.lower() != ".png" or "asset" not in files:
                continue
            require(files["asset"].size <= 16 * 1024 * 1024, f"PNG exceeds 16 MB: {source}")
            data = archive.extractfile(files["asset"]).read()
            require(len(data) >= 24 and data[:8] == b"\x89PNG\r\n\x1a\n" and data[12:16] == b"IHDR",
                    f"Invalid PNG: {source}")
            width, height = struct.unpack(">II", data[16:24])
            require(0 < width <= 4096 and 0 < height <= 4096, f"PNG dimensions exceed limits: {source}")
            assets[source] = {"source": source, "guid": guid, "sha256": sha256(data),
                              "width": width, "height": height, "data": data}
    return sha256(package_bytes), assets


def inspect(filename):
    digest, assets = read_package(filename)
    return {"package_sha256": digest,
            "images": [{k: v for k, v in item.items() if k != "data"} for item in assets.values()]}


def prepare(filename, mapping_path, output, root):
    digest, assets = read_package(filename)
    mapping = json.loads(Path(mapping_path).read_text(encoding="utf-8-sig"))
    package = mapping["package"]
    require(package.get("sha256") == digest, "Package SHA256 does not match mapping")
    require(all(isinstance(package.get(key), str) and package[key].strip()
                for key in ("title", "url", "version", "license")), "Package provenance is incomplete")
    vocabulary = {word["id"] for word in json.loads((Path(root) / "words.json").read_text(encoding="utf-8"))}
    selected = mapping["images"]
    require(isinstance(selected, list) and selected, "Mapping must select at least one PNG")
    seen = set()
    selected_sources = set()
    for image in selected:
        word, source = image["word"], image["source"]
        require(word in vocabulary and re.fullmatch(r"[a-z]+", word), f"Unknown vocabulary word: {word}")
        require(word not in seen, f"Duplicate vocabulary mapping: {word}")
        seen.add(word)
        require(source not in selected_sources, f"One PNG cannot illustrate multiple nouns: {source}")
        selected_sources.add(source)
        require(source in assets, f"Selected PNG is missing: {source}")
        require(image["sha256"] == assets[source]["sha256"], f"Selected PNG SHA256 mismatch: {source}")
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    art_package = output / "selected-art.unitypackage"
    with tarfile.open(art_package, "w:gz") as archive:
        for image in selected:
            asset = assets[image["source"]]
            # Fresh built-in texture metadata excludes third-party import settings and references.
            metadata = (f"fileFormatVersion: 2\nguid: {asset['guid']}\nTextureImporter:\n"
                        "  serializedVersion: 13\n  textureType: 8\n  spriteMode: 1\n  alphaIsTransparency: 1\n")
            for name, data in {"asset": asset["data"], "asset.meta": metadata.encode(),
                               "pathname": f"Assets/WordBuddiesImport/{image['word']}.png".encode()}.items():
                member = tarfile.TarInfo(f"{asset['guid']}/{name}")
                member.size = len(data)
                archive.addfile(member, io.BytesIO(data))
    result = {"package": package, "art_package": str(art_package),
              "art_package_sha256": sha256(art_package.read_bytes()),
              "images": [{**image, "width": assets[image["source"]]["width"],
                          "height": assets[image["source"]]["height"]} for image in selected]}
    (output / "prepared.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


def verify(prepared_path, staging, root):
    report = json.loads(Path(prepared_path).read_text(encoding="utf-8"))
    validated = []
    for image in report["images"]:
        word = image["word"]
        require(re.fullmatch(r"[a-z]+", word), "Invalid prepared vocabulary id")
        source = Path(staging) / "Assets" / "WordBuddiesImport" / f"{word}.png"
        require(source.is_file(), f"Unity did not import {word}")
        data = source.read_bytes()
        require(sha256(data) == image["sha256"], f"Unity imported bytes differ for {word}")
        require(source.with_suffix(".png.meta").is_file(), f"Unity texture metadata is missing for {word}")
        validated.append((word, data))
    root = Path(root).resolve()
    destination = root / "assets" / "imported-unity"
    require(destination.resolve() == destination, "Override directory is redirected outside its expected game location")
    manifest = destination / "manifest.json"
    require(manifest.resolve() == manifest, "Unrecognized managed manifest path")
    previous = {}
    if manifest.exists():
        require(manifest.is_file() and manifest.resolve() == manifest, "Unrecognized managed manifest path")
        saved = json.loads(manifest.read_text(encoding="utf-8"))
        for image in saved["images"]:
            word, digest = image["word"], image["sha256"]
            require(re.fullmatch(r"[a-z]+", word) and re.fullmatch(r"[a-f0-9]{64}", digest)
                    and word not in previous, "Invalid previous managed artwork record")
            previous[word] = digest
    existing = []
    # A directory under this reserved location is not managed by this importer.
    if destination.exists():
        require(all(not entry.is_dir() for entry in destination.iterdir()), "Unrecognized directory in managed artwork")
        existing = [entry for entry in destination.iterdir() if entry.suffix.lower() == ".png"]
    for path in existing:
        require(path.name == path.stem + ".png" and path.stem in previous
                and path.is_file() and path.resolve() == path, f"Unrecognized managed PNG: {path.name}")
        require(sha256(path.read_bytes()) == previous[path.stem], f"Previously managed PNG was modified: {path.name}")
    selected = {word for word, _ in validated}
    obsolete = []
    for word in previous.keys() - selected:
        path = destination / f"{word}.png"
        if path.exists():
            obsolete.append(path)
        remap = path.with_suffix(".png.import")
        if remap.exists():
            require(remap.is_file() and remap.resolve() == remap, f"Unrecognized managed Godot remap: {remap.name}")
            parts = re.split(r"(?m)^\[([^\]]+)\]\s*$", remap.read_text(encoding="utf-8"))
            sections = dict(zip(parts[1::2], parts[2::2]))
            require(re.search(r'(?m)^importer="texture"\s*$', sections.get("remap", ""))
                    and re.search(r'(?m)^source_file="res://assets/imported-unity/' + word + r'\.png"\s*$', sections.get("deps", "")),
                    f"Unrecognized managed Godot remap: {remap.name}")
            obsolete.append(remap)
    # All incoming and existing artwork is checked before replacing or removing anything.
    destination.mkdir(parents=True, exist_ok=True)
    for word, data in validated:
        with tempfile.NamedTemporaryFile(dir=destination, suffix=".tmp", delete=False) as staged:
            staged.write(data)
            temporary = Path(staged.name)
        temporary.replace(destination / f"{word}.png")
    for path in obsolete:
        path.unlink()
    report["verified_imported_images"] = len(validated)
    report["staging_project"] = str(Path(staging).resolve())
    manifest.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


if __name__ == "__main__":
    try:
        command, *arguments = sys.argv[1:]
        require(command in ("inspect", "prepare", "verify"), "Expected inspect, prepare or verify")
        result = {"inspect": inspect, "prepare": prepare, "verify": verify}[command](*arguments)
        print(json.dumps(result, indent=2))
    except (ValueError, KeyError, TypeError, OSError, tarfile.TarError) as error:
        print(f"Unity art: {error}", file=sys.stderr)
        sys.exit(1)
