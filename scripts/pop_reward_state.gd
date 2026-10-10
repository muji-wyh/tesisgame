extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const VERSION: int = 1
const MAX_RECEIPTS: int = 4096
const DEFAULT_PATH: String = "user://pop-rewards-v1.cfg"

var storage_kind: String = "pop"
var max_chests: int = 3
var allow_repeated_themes: bool = false
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
	if storage_kind not in ["pop", "jelly"] or max_chests < 0:
		return _fail("This treasure storage configuration is unavailable.")
	var config := ConfigFile.new()
	var missing: bool = false
	if _host != null:
		var text: Variant = _host.jellyRewardState() if storage_kind == "jelly" else _host.popRewardState()
		if text == null:
			missing = true
		elif not text is String or config.parse(text) != OK:
			return _fail("Could not read your treasure. Please retry.")
	elif OS.has_feature("web"):
		return _fail("Treasure storage is unavailable. Please retry.")
	else:
		var path: String = _storage_path()
		if not FileAccess.file_exists(path) and FileAccess.file_exists(path + ".previous"):
			if DirAccess.rename_absolute(path + ".previous", path) != OK:
				return _fail("Could not restore your treasure. Please retry.")
		var result: Error = config.load(path)
		missing = result == ERR_FILE_NOT_FOUND and not FileAccess.file_exists(path)
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
			or not saved_entries is Array or saved_entries.is_empty() \
			or (max_chests > 0 and saved_entries.size() > max_chests) \
			or not saved_receipts is Array or saved_receipts.size() > MAX_RECEIPTS:
			return _fail("Your treasure save could not be understood.")
		var themes: Array[String] = []
		var reward_ids: Dictionary = {}
		for index in range(saved_entries.size()):
			var entry: Variant = saved_entries[index]
			if not entry is Dictionary or not entry.get("theme") is String or not Data.THEMES.has(entry.theme) \
				or (not allow_repeated_themes and themes.has(entry.theme)) or not entry.get("opened") is bool:
				return _fail("Your treasure save contains an invalid chest.")
			themes.append(entry.theme)
			# Old inventories lacked per-chest identity. Derive it before any
			# pruning or append can move the entry to a different batch/index.
			var reward_id: Variant = entry.get("reward_id", _reward_id(saved_id, index))
			if not _valid_reward_id(reward_id) or reward_ids.has(reward_id):
				return _fail("Your treasure save contains an invalid or repeated reward ID.")
			reward_ids[reward_id] = true
			var restored: Dictionary = {"theme": entry.theme, "opened": entry.opened, "reward_id": reward_id}
			if entry.has("tier"):
				if not entry.tier is int or entry.tier < 1:
					return _fail("Your treasure save contains an invalid chest level.")
				restored["tier"] = entry.tier
			next_entries.append(restored)
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


func create_batch(id: String, themes: Array[String], tiers: Array[int] = []) -> bool:
	if not load_state():
		return false
	if id == round_id:
		return true
	if id.is_empty() or id.length() > 200 or themes.is_empty() or (max_chests > 0 and themes.size() > max_chests):
		return _fail("This round has no treasure to open.")
	if not tiers.is_empty() and (tiers.size() != themes.size()
		or tiers.any(func(tier: int) -> bool: return tier < 0)):
		return _fail("This round has an invalid chest level.")
	if has_pending() and not _keeps_pending_batches():
		return _fail("Open your saved treasure before starting another reward batch.")
	if _receipts.has(id):
		if _keeps_pending_batches():
			return true
		return _fail("The treasure from that round has already been opened.")
	var next_entries: Array[Dictionary] = []
	var receipts: Array[String] = _receipts.duplicate()
	if _keeps_pending_batches():
		# Keep unopened loot across replays. Retired batch IDs remain receipts so
		# a delayed callback cannot append the same round's treasure twice.
		for entry in entries:
			if not entry.opened:
				next_entries.append(entry.duplicate())
		if not round_id.is_empty() and not receipts.has(round_id):
			receipts.append(round_id)
			if receipts.size() > MAX_RECEIPTS:
				receipts.pop_front()
	var seen: Array[String] = []
	if not allow_repeated_themes:
		for entry in next_entries:
			seen.append(str(entry.theme))
	for index in range(themes.size()):
		var theme_id: String = themes[index]
		if not Data.THEMES.has(theme_id) or (not allow_repeated_themes and seen.has(theme_id)):
			return _fail("Choose different treasure styles for this round.")
		seen.append(theme_id)
		var entry: Dictionary = {"theme": theme_id, "opened": false, "reward_id": _reward_id(id, index)}
		if not tiers.is_empty() and tiers[index] > 0:
			entry["tier"] = tiers[index]
		next_entries.append(entry)
	if max_chests > 0 and next_entries.size() > max_chests:
		return _fail("Your saved treasure has no room for this batch.")
	if not _persist(id, next_entries, receipts):
		return false
	round_id = id
	entries = next_entries
	_receipts = receipts
	return true


func _keeps_pending_batches() -> bool:
	# Uncapped inventories retain earned treasure when a new round is replayed.
	return storage_kind == "jelly" or max_chests == 0


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
	var reward_ids: Dictionary = {}
	for entry in next:
		var reward_id: Variant = entry.get("reward_id")
		if not _valid_reward_id(reward_id) or reward_ids.has(reward_id):
			return _fail("This treasure has an invalid or repeated reward ID.")
		reward_ids[reward_id] = true
	var config := ConfigFile.new()
	config.set_value("treasure", "version", VERSION)
	config.set_value("treasure", "round_id", id)
	config.set_value("treasure", "entries", next)
	config.set_value("treasure", "receipts", receipts)
	if _host != null:
		var result: Variant = _host.saveJellyRewardState(config.encode_to_text()) if storage_kind == "jelly" \
			else _host.savePopRewardState(config.encode_to_text())
		if result is bool and result:
			return true
		return _fail("Could not save your treasure. Please retry.")
	if OS.has_feature("web"):
		return _fail("Treasure storage is unavailable. Please retry.")
	var path: String = _storage_path()
	if config.save(path + ".pending") != OK:
		return _fail("Could not save your treasure. Please retry.")
	if FileAccess.file_exists(path + ".previous") and DirAccess.remove_absolute(path + ".previous") != OK:
		return _fail("Could not preserve your treasure. Please retry.")
	var had_previous: bool = FileAccess.file_exists(path)
	if had_previous and DirAccess.rename_absolute(path, path + ".previous") != OK:
		return _fail("Could not preserve your treasure. Please retry.")
	if DirAccess.rename_absolute(path + ".pending", path) != OK:
		if had_previous:
			DirAccess.rename_absolute(path + ".previous", path)
		return _fail("Could not save your treasure. Please retry.")
	if had_previous:
		DirAccess.remove_absolute(path + ".previous")
	return true


func _storage_path() -> String:
	return "user://jelly-rewards-v1.cfg" if storage_kind == "jelly" and _path == DEFAULT_PATH else _path


func _reward_id(id: String, index: int) -> String:
	return "%s:%s:%d" % [storage_kind, id, index]


func _valid_reward_id(value: Variant) -> bool:
	if not value is String or value.length() > 512 or not value.begins_with(storage_kind + ":") \
		or value.length() <= storage_kind.length() + 1 or value.strip_edges() != value:
		return false
	for index in range(value.length()):
		if value.unicode_at(index) < 32 or value.unicode_at(index) == 127:
			return false
	return true


func _fail(message: String) -> bool:
	error = message
	return false
