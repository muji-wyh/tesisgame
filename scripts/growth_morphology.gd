extends RefCounted
## Add only the separately reviewed analysis for the unchanged Growth identity.

const Morphology = preload("res://scripts/morphology_analysis.gd")
const ROOT: String = "res://data/vocabulary/morphology/"
const MAX_FILE_BYTES: int = 2 * 1024 * 1024
static var _index: Dictionary = {}
static var _cohorts: Dictionary = {}


static func decorate(word: Dictionary) -> Dictionary:
	var age: int = int(word.get("min_age", -1))
	if age < 3 or age > 12:
		return _result(word, "invalid", "This word has no valid Growth cohort.")
	if _index.is_empty():
		_index = _read(ROOT + "index.json")
	if _index.get("schema") != 1 or not _index.get("ages") is Dictionary or not _index.get("sources") is Dictionary:
		return _result(word, "invalid", "Growth word analysis metadata could not be loaded.")
	var key: String = str(age)
	if not _cohorts.has(key):
		var document: Dictionary = _read(ROOT + "age-%02d.json" % age)
		var entries: Dictionary = {}
		if document.get("schema") != 1 or document.get("age") != age \
			or document.get("revision") != _index.get("revision") or not document.get("entries") is Array:
			return _result(word, "invalid", "This Growth cohort's word analyses could not be loaded.")
		for entry: Variant in document.entries:
			if not entry is Dictionary or not _text(entry.get("id")) or entries.has(entry.id):
				return _result(word, "invalid", "This Growth cohort has inconsistent word analysis identities.")
			entries[entry.id] = entry
		if entries.size() != int(_index.ages.get(key, {}).get("total", -1)):
			return _result(word, "invalid", "This Growth cohort's word analysis inventory is incomplete.")
		_cohorts[key] = entries
	return from_entry(word, _cohorts[key].get(str(word.get("id", "")), {}), _index.sources)


static func from_entry(word: Dictionary, entry: Dictionary, sources: Dictionary) -> Dictionary:
	if entry.is_empty():
		return _result(word, "pending", "This word is waiting for its individual morphology review.")
	for field: String in ["id", "text", "min_age", "part_of_speech", "meaning"]:
		if entry.get(field, "") != word.get(field, ""):
			return _result(word, "invalid", "The authored word analysis no longer matches this vocabulary sense.")
	var review: Variant = entry.get("review")
	if not review is Dictionary or not review.get("status") in ["pending", "reviewed"]:
		return _result(word, "invalid", "This word analysis needs an explicit review state.")
	if review.status == "pending":
		return _result(word, "pending", str(review.get("reason", "This word is waiting for its individual morphology review.")))
	if not _text(review.get("reviewer")) or not _date(review.get("date")) or not _text(review.get("rationale")) \
		or not _text(review.get("method")) or not review.get("references") is Array or review.references.is_empty():
		return _result(word, "invalid", "A reviewed word analysis needs named review and source evidence.")
	for reference: Variant in review.references:
		if not reference is String or not sources.get(reference) is Dictionary \
			or not _text(sources[reference].get("title")) or not _text(sources[reference].get("url")) \
			or not _text(sources[reference].get("author")) or not _date(sources[reference].get("consulted")) \
			or not _text(sources[reference].get("evidence")):
			return _result(word, "invalid", "A word analysis refers to unavailable source evidence.")
	if not entry.get("analysis") is Dictionary:
		return _result(word, "invalid", "This reviewed word has no authored composition.")
	var analysis: Dictionary = entry.analysis.duplicate(true)
	analysis["review"] = review.duplicate(true)
	var compiled: Dictionary = Morphology.compile(analysis)
	if not compiled.ok or analysis.get("lexeme_id") != word.get("id") or analysis.get("text") != word.get("text"):
		return _result(word, "invalid", "This word's authored composition is invalid.")
	var result: Dictionary = _result(word, "reviewed", "")
	result["morphology"] = analysis
	return result


static func clear_cache() -> void:
	_index.clear()
	_cohorts.clear()


static func _result(word: Dictionary, status: String, notice: String) -> Dictionary:
	var result: Dictionary = word.duplicate(true)
	result.erase("morphology")
	result["morphology_status"] = status
	result["morphology_notice"] = notice
	return result


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_FILE_BYTES:
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	return value if value is Dictionary else {}


static func _text(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()


static func _date(value: Variant) -> bool:
	if not value is String or value.length() != 10 or value[4] != "-" or value[7] != "-":
		return false
	for index: int in [0, 1, 2, 3, 5, 6, 8, 9]:
		if value[index] < "0" or value[index] > "9":
			return false
	return true
