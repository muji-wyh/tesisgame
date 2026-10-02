extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const VERSION: int = 1
const MAX_RECEIPTS: int = 4096

var ready: bool = false
var error: String = ""
var round_id: String = ""
var entries: Array[Dictionary] = []
var last_open_was_duplicate: bool = false
var _receipts: Array[String] = []
var _path: String
var _host: Object


func _init(path: String = "user://pop-rewards-v1.cfg", host: Object = null) -> void:
	_path = path
	_host = host
	if _host == null and OS.has_feature("web"):
		_host = JavaScriptBridge.get_interface("wordBuddiesHost")


func load_state() -> bool:
	ready = false
	error = ""
	var config := ConfigFile.new()
	var missing: bool = false
	if _host != null:
		var text: Variant = _host.popRewardState()
		if text == null:
			missing = true
		elif not text is String or config.parse(text) != OK:
			return _fail("Could not read your treasure. Please retry.")
	elif OS.has_feature("web"):
		return _fail("Treasure storage is unavailable. Please retry.")
	else:
		if not FileAccess.file_exists(_path) and FileAccess.file_exists(_path + ".previous"):
			if DirAccess.rename_absolute(_path + ".previous", _path) != OK:
				return _fail("Could not restore your treasure. Please retry.")
		var result: Error = config.load(_path)
		missing = result == ERR_FILE_NOT_FOUND and not FileAccess.file_exists(_path)
		if result != OK and not missing:
			return _fail("Could not read your treasure. Please retry.")
	var next_id: String = ""
	var next_entries: Array[Dictionary] = []
	var next_receipts: Array[String] = []
	if not missing:
		if config.get_value("treasure", "version", null) != VERSION:
			return _fail("This treasure save needs a supported version.")
		var saved_id: Variant = config.get_value("treasure", "round_id", null)
		var saved_entries: Variant = config.get_value("treasure", "entries", null)
		var saved_receipts: Variant = config.get_value("treasure", "receipts", null)
		if not saved_id is String or saved_id.is_empty() or saved_id.length() > 200 \
			or not saved_entries is Array or saved_entries.is_empty() or saved_entries.size() > 3 \
			or not saved_receipts is Array or saved_receipts.size() > MAX_RECEIPTS:
			return _fail("Your treasure save could not be understood.")
		var themes: Array[String] = []
		for entry in saved_entries:
			if not entry is Dictionary or not entry.get("theme") is String or not Data.THEMES.has(entry.theme) \
				or themes.has(entry.theme) or not entry.get("opened") is bool:
				return _fail("Your treasure save contains an invalid chest.")
			themes.append(entry.theme)
			next_entries.append({"theme": entry.theme, "opened": entry.opened})
		for receipt in saved_receipts:
			if not receipt is String or receipt.is_empty() or receipt.length() > 200 or next_receipts.has(receipt):
				return _fail("Your treasure history could not be understood.")
			next_receipts.append(receipt)
		next_id = saved_id
	round_id = next_id
	entries = next_entries
	_receipts = next_receipts
	ready = true
	return true


func has_pending() -> bool:
	for entry in entries:
		if not entry.opened:
			return true
	return false


func create_batch(id: String, themes: Array[String]) -> bool:
	if not load_state():
		return false
	if id == round_id:
		return true
	if id.is_empty() or id.length() > 200 or themes.is_empty() or themes.size() > 3:
		return _fail("This round has no treasure to open.")
	if has_pending():
		return _fail("Open your saved treasure before starting another reward batch.")
	if _receipts.has(id):
		return _fail("The treasure from that round has already been opened.")
	var next_entries: Array[Dictionary] = []
	var seen: Array[String] = []
	for theme_id in themes:
		if not Data.THEMES.has(theme_id) or seen.has(theme_id):
			return _fail("Choose different treasure styles for this round.")
		seen.append(theme_id)
		next_entries.append({"theme": theme_id, "opened": false})
	if not _persist(id, next_entries, _receipts):
		return false
	round_id = id
	entries = next_entries
	return true


func mark_opened(id: String, index: int) -> bool:
	last_open_was_duplicate = false
	if not load_state():
		return false
	if id != round_id or index < 0 or index >= entries.size():
		return _fail("This chest no longer belongs to the saved round.")
	if entries[index].opened:
		last_open_was_duplicate = true
		return true
	var next: Array[Dictionary] = entries.duplicate(true)
	next[index].opened = true
	var complete: bool = true
	for entry in next:
		complete = complete and bool(entry.opened)
	var receipts: Array[String] = _receipts.duplicate()
	if complete and not receipts.has(id):
		receipts.append(id)
		if receipts.size() > MAX_RECEIPTS:
			receipts.pop_front()
	if not _persist(id, next, receipts):
		return false
	entries = next
	_receipts = receipts
	return true


func _persist(id: String, next: Array[Dictionary], receipts: Array[String]) -> bool:
	var config := ConfigFile.new()
	config.set_value("treasure", "version", VERSION)
	config.set_value("treasure", "round_id", id)
	config.set_value("treasure", "entries", next)
	config.set_value("treasure", "receipts", receipts)
	if _host != null:
		var result: Variant = _host.savePopRewardState(config.encode_to_text())
		if result is bool and result:
			return true
		return _fail("Could not save your treasure. Please retry.")
	if OS.has_feature("web"):
		return _fail("Treasure storage is unavailable. Please retry.")
	if config.save(_path + ".pending") != OK:
		return _fail("Could not save your treasure. Please retry.")
	if FileAccess.file_exists(_path + ".previous") and DirAccess.remove_absolute(_path + ".previous") != OK:
		return _fail("Could not preserve your treasure. Please retry.")
	var had_previous: bool = FileAccess.file_exists(_path)
	if had_previous and DirAccess.rename_absolute(_path, _path + ".previous") != OK:
		return _fail("Could not preserve your treasure. Please retry.")
	if DirAccess.rename_absolute(_path + ".pending", _path) != OK:
		if had_previous:
			DirAccess.rename_absolute(_path + ".previous", _path)
		return _fail("Could not save your treasure. Please retry.")
	if had_previous:
		DirAccess.remove_absolute(_path + ".previous")
	return true


func _fail(message: String) -> bool:
	error = message
	return false
