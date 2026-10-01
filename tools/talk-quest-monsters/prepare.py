"""Export the approved local source selection; never download or import into Unity."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--source-root", type=Path, required=True)
parser.add_argument("--blender", type=Path, required=True)
parser.add_argument("--only", help="Optional comma-separated selected IDs for diagnosis")
parser.add_argument("--no-previews", action="store_true")
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
work = root / "build/talk-quest-monsters"
work.mkdir(parents=True, exist_ok=True)
selection_path = args.source_root / "processing/monster-roster-selection.json"
selection = json.loads(selection_path.read_text(encoding="utf-8"))
inventory = json.loads((args.source_root / "processing/monster-roster-model-inventory.json").read_text(encoding="utf-8"))
if selection["package_sha256"] != inventory["package_sha256"]:
    raise ValueError("Selection and source inventory belong to different archives")
models = {model["path"]: model for model in inventory["models"]}
selected = selection["creatures"]
if len(selected) != 14 or len({c["designFamily"] for c in selected}) != 14:
    raise ValueError("The approved roster must have fourteen distinct design families")
if args.only:
    allowed = set(args.only.split(","))
    selected = [creature for creature in selected if creature["id"] in allowed]
jobs = []
for creature in selected:
    model = models[creature["sourcePath"]]
    if model["sha256"] != creature["sourceSha256"]:
        raise ValueError("Selected model hash mismatch")
    jobs.append({"id": creature["id"], "name": creature["name"],
                 "source_file": str(Path(inventory["tree"]) / creature["sourcePath"]),
                 "source_path": creature["sourcePath"], "source_sha256": model["sha256"],
                 "embedded_materials": model["fbx_contents"]["embedded_materials"],
                 "output": str(root / "assets/talk_quest/monsters" / (creature["id"] + ".glb"))})
job_path = work / "jobs.json"
job_path.write_text(json.dumps({"jobs": jobs, "report": str(work / "conversion-report.json"),
                               "preview_directory": None if args.no_previews else str(work / "previews")}, indent=2), encoding="utf-8")
subprocess.run([str(args.blender), "--background", "--factory-startup", "--python",
                str(Path(__file__).with_name("export_monsters.py")), "--", str(job_path)], check=True)
report = json.loads((work / "conversion-report.json").read_text())
if report["errors"] or len(report["creatures"]) != len(jobs):
    raise RuntimeError("The conversion did not complete")
report["package_sha256"] = selection["package_sha256"]
report["selection_sha256"] = hashlib.sha256(selection_path.read_bytes()).hexdigest()
(work / "conversion-report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps({"converted": len(report["creatures"]), "total_bytes": sum(c["bytes"] for c in report["creatures"])}))
