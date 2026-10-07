extends RefCounted

const CATALOG_PATH: String = "res://phrases.json"
const LEVELS: Array[String] = ["basic", "growing", "advanced"]


static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not FileAccess.file_exists(CATALOG_PATH):
		return result
	var source = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not source is Array:
		return result
	var seen_ids: Dictionary = {}
	var seen_text: Dictionary = {}
	for entry in source:
		if not _valid_entry(entry):
			return []
		if seen_ids.has(entry.id) or seen_text.has(entry.text):
			return []
		seen_ids[entry.id] = true
		seen_text[entry.text] = true
		result.append(entry.duplicate(true))
	return result


static func for_age(age_band: String) -> Array[Dictionary]:
	var level: String = {"4-6": "basic", "7-9": "growing", "10+": "advanced", "10-plus": "advanced"}.get(age_band, "")
	var result: Array[Dictionary] = []
	for phrase in entries():
		if age_band == "all" or phrase.level == level:
			result.append(phrase)
	return result


static func _valid_entry(entry: Variant) -> bool:
	if not entry is Dictionary:
		return false
	for key in ["id", "text", "level", "picture_id", "audio"]:
		if not entry.get(key) is String or String(entry[key]).strip_edges().is_empty():
			return false
	if not LEVELS.has(entry.level) or not entry.get("words") is Array:
		return false
	if entry.words.size() < 2 or entry.words.size() > 4:
		return false
	var ids: Array[String] = []
	for id in entry.words:
		if not id is String or String(id).is_empty() or ids.has(id):
			return false
		ids.append(id)
	return ids.has(entry.picture_id) and entry.audio == "assets/audio/voice/phrase-%s.wav" % entry.id
