extends RefCounted
## A round owns a copy of its learning identity, never a live Home preference.

const MODES: Array[String] = ["match", "memory", "phrase", "pop", "jelly", "word_jelly"]
const GROWTH_REVISION: String = "growth-v1"


static func growth(age: int, mode: String) -> Dictionary:
	return {"track": "growth", "course_id": "growth", "module_id": str(age),
		"curriculum_revision": GROWTH_REVISION, "mode": mode}


static func professional(course: String, module: String, revision: String, mode: String) -> Dictionary:
	return {"track": "professional", "course_id": course, "module_id": module,
		"curriculum_revision": revision, "mode": mode}


static func validate(value: Variant) -> String:
	if not value is Dictionary:
		return "Choose a learning path before starting a round."
	for key in ["track", "course_id", "module_id", "curriculum_revision", "mode"]:
		if not value.get(key) is String or not _valid_id(value[key]):
			return "The learning context needs a valid %s." % key
	if value.track not in ["growth", "professional"] or value.mode not in MODES:
		return "Choose an available learning path and game."
	if value.track == "growth":
		if value.course_id != "growth" or value.curriculum_revision != GROWTH_REVISION \
			or value.module_id not in ["3", "4", "5", "6", "7", "8", "9", "10", "11", "12"]:
			return "Choose an available Growth age."
	return ""


static func freeze(value: Dictionary) -> Dictionary:
	if not validate(value).is_empty():
		return {}
	var result: Dictionary = {}
	for key in ["track", "course_id", "module_id", "curriculum_revision", "mode"]:
		result[key] = value[key]
	result.make_read_only()
	return result


static func identity(value: Dictionary, include_mode: bool = true) -> String:
	if not validate(value).is_empty():
		return ""
	var parts: Array = [value.track, value.course_id, value.module_id, value.curriculum_revision]
	if include_mode:
		parts.append(value.mode)
	# JSON separates values without delimiter collisions in imported identifiers.
	return JSON.stringify(parts)


static func same_round(left: Dictionary, right: Dictionary) -> bool:
	var key: String = identity(left)
	return not key.is_empty() and key == identity(right)


static func _valid_id(value: String) -> bool:
	if value.is_empty() or value.length() > 128:
		return false
	for character in value:
		if character not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.:":
			return false
	return true
