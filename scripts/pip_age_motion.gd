extends RefCounted

const PATH := "res://data/pip-age-motions.json"
static var _catalog: Dictionary = {}


static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_catalog = parsed
	return _catalog


static func actions(age: int) -> Array[String]:
	var result: Array[String] = []
	for id in catalog().get("stages", {}).get(str(age), []):
		result.append(str(id))
	return result


static func clip(id: String) -> Dictionary:
	return catalog().get("clips", {}).get(id, {})


static func sample(id: String, progress: float, reduced: bool = false) -> Dictionary:
	var definition: Dictionary = clip(id)
	var beats: Array = definition.get("beats", [])
	var p: float = float(definition.get("still", 0.5)) if reduced else clampf(progress, 0.0, 1.0)
	var parts: Array[Vector3] = []
	for index in range(1, beats.size()):
		var start: Dictionary = beats[index - 1]
		var finish: Dictionary = beats[index]
		if p > float(finish.time):
			continue
		var blend: float = smoothstep(0.0, 1.0, (p - float(start.time)) / (float(finish.time) - float(start.time)))
		for part in range(6):
			var a: Array = start.parts[part]
			var b: Array = finish.parts[part]
			parts.append(Vector3(a[0], a[1], a[2]).lerp(Vector3(b[0], b[1], b[2]), blend))
		var envelope: float = smoothstep(0.0, 0.14, p) * (1.0 - smoothstep(0.82, 1.0, p))
		return {"parts": parts, "face": str(finish.face) if blend >= 0.5 else str(start.face),
			"inset": float(definition.get("inset", 0.0)) * envelope}
	return {"parts": [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO], "face": "neutral", "inset": 0.0}
