extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const SAVE_VERSION: int = 1

var counts: Dictionary = {}
var legacy_rewards: Dictionary = {}
var error: String = ""

var _save_path: String
var _legacy_path: String
var _loaded: bool = false
var _browser_storage: Object


func _init(save_path: String = "user://medals.cfg", legacy_path: String = "user://rewards.cfg", browser_storage: Object = null) -> void:
	_save_path = save_path
	_legacy_path = legacy_path
	_browser_storage = browser_storage
	if _browser_storage == null and OS.has_feature("web"):
		_browser_storage = JavaScriptBridge.get_interface("wordBuddiesHost")


func load_progress() -> bool:
	error = ""
	_loaded = false
	if OS.has_feature("web") and _browser_storage == null:
		return _fail("Browser medal storage is unavailable.")
	var save := ProjectSettings.globalize_path(_save_path).simplify_path()
	var legacy := ProjectSettings.globalize_path(_legacy_path).simplify_path()
	if OS.get_name() == "Windows":
		save = save.to_lower()
		legacy = legacy.to_lower()
	if _save_path.is_empty() or _legacy_path.is_empty() or legacy in [save, save + ".pending", save + ".previous"]:
		return _fail("Medal progress and legacy rewards need separate, nonempty save paths.")
	var config := ConfigFile.new()
	var browser_text: Variant = _browser_storage.medalProgress() if _browser_storage != null else null
	var status: int
	if browser_text != null:
		if not browser_text is String:
			return _fail("Could not read browser medal progress. Browser storage may be unavailable.")
		status = config.parse(browser_text)
		if status != OK:
			return _fail("Could not load browser medal progress: %s." % error_string(status))
	else:
		if not _restore_previous():
			return false
		status = _read_config(config, _save_path, "medal progress")
		if not error.is_empty():
			return false
	var migrating: bool = status == ERR_FILE_NOT_FOUND
	var next_counts: Dictionary = {}
	if not migrating:
		var version: Variant = config.get_value("medals", "version", -1)
		if typeof(version) != TYPE_INT or version != SAVE_VERSION:
			return _fail("The medal save version is missing, invalid, or unsupported; expected version %d." % SAVE_VERSION)
		var saved_counts: Variant = config.get_value("medals", "counts", false)
		if not _validate_counts(saved_counts):
			return false
		next_counts = saved_counts.duplicate()
	var earned := _read_legacy()
	if not error.is_empty():
		return false
	var archives: Dictionary = {}
	for id in earned:
		if Data.medal(id).is_empty():
			archives[id] = true
		elif migrating:
			next_counts[id] = Data.PIECES_PER_MEDAL
	if (migrating or (_browser_storage != null and browser_text == null)) and not _persist(next_counts):
		return false
	counts = next_counts
	legacy_rewards = archives
	_loaded = true
	return true


func count_for(id: String) -> int:
	if Data.medal(id).is_empty():
		return 0
	return counts.get(id, 0)


func completed_count(theme_id: String = "") -> int:
	var completed: int = 0
	var seasons: Array = Data.THEMES.keys() if theme_id.is_empty() else [theme_id]
	for season in seasons:
		for medal in Data.medals(season):
			if count_for(medal.id) == Data.PIECES_PER_MEDAL:
				completed += 1
	return completed


func next_fragment(theme_id: String) -> Dictionary:
	error = ""
	if not Data.THEMES.has(theme_id):
		_fail("Unknown medal season: " + theme_id + ".")
		return {}
	if not _loaded:
		_fail("Load medal progress successfully before selecting a fragment.")
		return {}
	for medal in Data.medals(theme_id):
		var before := count_for(medal.id)
		if before < Data.PIECES_PER_MEDAL:
			return {
				"medal_id": medal.id,
				"before": before,
				"after": before + 1,
				"completed": before + 1 == Data.PIECES_PER_MEDAL
			}
	return {}


func claim(fragment: Dictionary) -> bool:
	error = ""
	if not _loaded:
		return _fail("Load medal progress successfully before claiming a fragment.")
	var id: Variant = fragment.get("medal_id")
	if typeof(id) != TYPE_STRING or Data.medal(id).is_empty():
		return _fail("The captured fragment needs a known active medal ID.")
	var before: Variant = fragment.get("before")
	var after: Variant = fragment.get("after")
	if typeof(before) != TYPE_INT or typeof(after) != TYPE_INT:
		return _fail("Captured fragment counts must be integers, not strings or decimal values.")
	if before < 0 or before >= Data.PIECES_PER_MEDAL or after != before + 1 or after > Data.PIECES_PER_MEDAL:
		return _fail("A captured fragment must add exactly one piece within the medal's three-piece limit.")
	var completed: Variant = fragment.get("completed")
	if typeof(completed) != TYPE_BOOL or completed != (after == Data.PIECES_PER_MEDAL):
		return _fail("The captured fragment's completion flag does not match its count.")
	var current := count_for(id)
	if current == after:
		return true
	if current != before:
		return _fail("The captured fragment for %s is stale or out of order: expected %d pieces, found %d." % [id, before, current])
	for medal in Data.medals(Data.medal(id).theme):
		if count_for(medal.id) < Data.PIECES_PER_MEDAL:
			if medal.id != id:
				return _fail("Finish the first incomplete medal, %s, before awarding a piece to %s." % [medal.id, id])
			break
	var next_counts := counts.duplicate()
	next_counts[id] = after
	if not _validate_counts(next_counts) or not _persist(next_counts):
		return false
	counts = next_counts
	return true


func _read_config(config: ConfigFile, path: String, description: String) -> int:
	var status := config.load(path)
	if status == OK:
		return status
	if status == ERR_FILE_NOT_FOUND and not FileAccess.file_exists(path) and not DirAccess.dir_exists_absolute(path):
		return status
	_fail("Could not load %s from %s: %s." % [description, path, error_string(status)])
	return status


func _read_legacy() -> Dictionary:
	var config := ConfigFile.new()
	if _read_config(config, _legacy_path, "earlier rewards") != OK:
		return {}
	var ids: Variant = config.get_value("rewards", "ids", false)
	if not ids is Array and not ids is PackedStringArray:
		_fail("The earlier rewards save needs a rewards/ids list of reward IDs.")
		return {}
	var earned: Dictionary = {}
	for id in ids:
		if typeof(id) != TYPE_STRING or Data.reward(id).is_empty():
			_fail("The earlier rewards save contains an invalid or unknown reward ID.")
			return {}
		earned[id] = true
	return earned


func _validate_counts(value: Variant) -> bool:
	if not value is Dictionary:
		return _fail("The medal save needs a dictionary of counts keyed by active medal ID.")
	for id in value:
		if typeof(id) != TYPE_STRING or Data.medal(id).is_empty():
			return _fail("The medal save contains an invalid, unknown, or archived medal ID.")
		var count: Variant = value[id]
		if typeof(count) != TYPE_INT or count < 0 or count > Data.PIECES_PER_MEDAL:
			return _fail("The saved count for %s must be an integer between 0 and %d." % [id, Data.PIECES_PER_MEDAL])
	return true


func _persist(next_counts: Dictionary) -> bool:
	var config := ConfigFile.new()
	config.set_value("medals", "version", SAVE_VERSION)
	config.set_value("medals", "counts", next_counts)
	if _browser_storage != null:
		if not bool(_browser_storage.saveMedalProgress(config.encode_to_text())):
			return _fail("Could not save browser medal progress. Browser storage may be unavailable or full.")
		return true
	if not _restore_previous():
		return false
	var staged := _save_path + ".pending"
	var file := FileAccess.open(staged, FileAccess.WRITE)
	if file == null:
		_fail("Could not open the staged medal save at %s: %s." % [staged, error_string(FileAccess.get_open_error())])
		_discard_staged(staged)
		return false
	var written: bool = file.store_string(config.encode_to_text())
	file.flush()
	var status := file.get_error()
	file.close()
	if not written or status != OK:
		if status == OK:
			status = ERR_FILE_CANT_WRITE
		_fail("Could not write medal progress to %s: %s." % [staged, error_string(status)])
		_discard_staged(staged)
		return false
	# Windows rename can delete its destination before a move fails.
	# Keep one prior save and move the staged file into an empty destination.
	var previous := _save_path + ".previous"
	var moved_previous: bool = FileAccess.file_exists(_save_path)
	if moved_previous:
		status = DirAccess.rename_absolute(_save_path, previous)
		if status != OK:
			_fail("Could not preserve the previous medal save at %s: %s." % [_save_path, error_string(status)])
			_discard_staged(staged)
			return false
	status = DirAccess.rename_absolute(staged, _save_path)
	if status != OK:
		_fail("Could not replace the medal save at %s: %s." % [_save_path, error_string(status)])
		if moved_previous:
			var restored := DirAccess.rename_absolute(previous, _save_path)
			if restored != OK:
				error += " Previous progress is retained at %s; restoring it failed: %s." % [previous, error_string(restored)]
		_discard_staged(staged)
		return false
	return true


func _restore_previous() -> bool:
	if FileAccess.file_exists(_save_path) or DirAccess.dir_exists_absolute(_save_path):
		return true
	var previous := _save_path + ".previous"
	if DirAccess.dir_exists_absolute(previous):
		return _fail("The interrupted medal save has an unreadable previous-save path: " + previous + ".")
	if FileAccess.file_exists(previous):
		var status := DirAccess.rename_absolute(previous, _save_path)
		if status != OK:
			return _fail("Could not restore previous medal progress from %s: %s." % [previous, error_string(status)])
	return true


func _discard_staged(path: String) -> void:
	if FileAccess.file_exists(path):
		var status := DirAccess.remove_absolute(path)
		if status != OK:
			error += " Could not remove the unfinished save: %s." % error_string(status)


func _fail(message: String) -> bool:
	error = message
	return false
