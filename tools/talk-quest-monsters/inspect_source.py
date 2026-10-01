"""Inspect source rigs and animation actions in Blender without changing sources."""
import json
from pathlib import Path
import sys

import bpy

source = Path(sys.argv[sys.argv.index("--") + 1])
output = Path(sys.argv[sys.argv.index("--") + 2])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(source), use_anim=True)
actions = []
for action in bpy.data.actions:
    curves = []
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                curves.extend(bag.fcurves)
    actions.append({"name": action.name, "frames": list(action.frame_range),
                    "slots": [{"name": slot.identifier, "target": slot.target_id_type} for slot in action.slots],
                    "curve_count": len(curves), "paths": sorted({curve.data_path for curve in curves})})
report = {"source": str(source), "blender": bpy.app.version_string,
          "objects": [{"name": obj.name, "type": obj.type,
                       "parent": obj.parent.name if obj.parent else None,
                       "location": list(obj.location), "scale": list(obj.scale),
                       "dimensions": list(obj.dimensions),
                       "bones": [bone.name for bone in obj.data.bones] if obj.type == "ARMATURE" else [],
                       "active_action": obj.animation_data.action.name if obj.animation_data and obj.animation_data.action else None,
                       "modifiers": [{"type": mod.type, "object": getattr(getattr(mod, "object", None), "name", None)} for mod in obj.modifiers]}
                      for obj in bpy.context.scene.objects], "actions": actions}
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(report, indent=2), encoding="utf-8")
print(json.dumps({"output": str(output), "actions": len(actions), "objects": len(report["objects"])}))
