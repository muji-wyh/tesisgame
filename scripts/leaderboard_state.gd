extends RefCounted

const SAVE_VERSION: int = 1
const MAX_PROFILES: int = 10
const MAX_RECEIPTS: int = 4096
const MAX_VALUE: int = 1000000
const MODES: Array[String] = ["pop", "match", "memory"]
const AVATARS: Array[String] = ["duck", "cat", "dog", "fox", "panda", "frog", "unicorn", "rocket", "star", "rainbow", "bear", "rabbit"]

static var _id_sequence: int = 0

var ready: bool = false
var error: String = ""
var profiles: Array[Dictionary] = []

var _bests: Dictionary = {"pop": {}, "match": {}, "memory": {}}
var _receipts: Array[Dictionary] = []
var _save_path: String
var _browser_storage: Object


func _init(save_path: String = "user://leaderboards-v1.cfg", browser_storage: Object = null) -> void:
	_save_path = save_path
	_browser_storage = browser_storage
	if _browser_storage == null and OS.has_feature("web"):
		_browser_storage = JavaScriptBridge.get_interface("wordBuddiesHost")


static func make_round_id() -> String:
	return "round-" + _unique_id()


static func _unique_id() -> String:
	_id_sequence += 1
	var random := RandomNumberGenerator.new()
	random.randomize()
	return "%s-%x-%x-%x" % [str(int(Time.get_unix_time_from_system() * 1000.0)), Time.get_ticks_usec(), random.randi(), _id_sequence]


func load_state() -> bool:
	error = ""
	ready = false
	if _save_path.is_empty():
		return _fail("The leaderboard needs a nonempty save path.")
	if OS.has_feature("web") and _browser_storage == null:
		return _fail("Browser leaderboard storage is unavailable.")
	var config := ConfigFile.new()
	var missing: bool = false
	if _browser_storage != null:
		var browser_text: Variant = _browser_storage.leaderboardState()
		if browser_text == null:
			missing = true
		elif not browser_text is String:
			return _fail("Could not read players and leaderboards. Browser storage may be unavailable.")
		else:
			var parsed := config.parse(browser_text)
			if parsed != OK:
				return _fail("Could not load players and leaderboards: %s." % error_string(parsed))
	else:
		if not _restore_previous():
			return false
		var loaded := config.load(_save_path)
		missing = loaded == ERR_FILE_NOT_FOUND and not FileAccess.file_exists(_save_path) and not DirAccess.dir_exists_absolute(_save_path)
		if loaded != OK and not missing:
			return _fail("Could not load players and leaderboards: %s." % error_string(loaded))
	var next_profiles: Array[Dictionary] = []
	var next_bests: Dictionary = {"pop": {}, "match": {}, "memory": {}}
	var next_receipts: Array[Dictionary] = []
	if not missing:
		var version: Variant = config.get_value("leaderboard", "version", null)
		if typeof(version) != TYPE_INT or version != SAVE_VERSION:
			return _fail("The leaderboard save version is missing, invalid, or unsupported.")
		var saved_profiles: Variant = config.get_value("leaderboard", "profiles", null)
		var saved_bests: Variant = config.get_value("leaderboard", "bests", null)
		var saved_receipts: Variant = config.get_value("leaderboard", "receipts", null)
		if not saved_profiles is Array or saved_profiles.size() > MAX_PROFILES:
			return _fail("The leaderboard save needs at most ten players.")
		var player_ids: Dictionary = {}
		for profile in saved_profiles:
			if not profile is Dictionary or not _valid_id(profile.get("id")) or not profile.get("name") is String or not profile.get("avatar") is String:
				return _fail("The leaderboard save contains an invalid player.")
			if player_ids.has(profile.id) or not _valid_name(profile.name) or profile.name != profile.name.strip_edges() or not AVATARS.has(profile.avatar):
				return _fail("The leaderboard save contains an invalid player name, avatar, or duplicate ID.")
			player_ids[profile.id] = true
			next_profiles.append({"id": profile.id, "name": profile.name, "avatar": profile.avatar})
		if not saved_bests is Dictionary or saved_bests.size() != MODES.size():
			return _fail("The leaderboard save needs a board for each game mode.")
		for mode in MODES:
			if not saved_bests.get(mode) is Dictionary:
				return _fail("The leaderboard save contains an invalid board.")
			for player_id in saved_bests[mode]:
				var result: Variant = saved_bests[mode][player_id]
				if not player_ids.has(player_id) or not result is Dictionary or _normalized_result(mode, result).is_empty():
					return _fail("The leaderboard save contains an invalid result.")
				next_bests[mode][player_id] = _normalized_result(mode, result)
		if not saved_receipts is Array or saved_receipts.size() > MAX_RECEIPTS:
			return _fail("The leaderboard save contains an invalid round history.")
		var receipt_ids: Dictionary = {}
		for receipt in saved_receipts:
			if not receipt is Dictionary or not _valid_id(receipt.get("id")) or not receipt.get("mode") is String or not receipt.get("player_id") is String:
				return _fail("The leaderboard save contains an invalid round receipt.")
			if receipt_ids.has(receipt.id) or not MODES.has(receipt.mode) or not player_ids.has(receipt.player_id):
				return _fail("The leaderboard save contains a duplicate or unrecognized round receipt.")
			if not next_bests[receipt.mode].has(receipt.player_id):
				return _fail("The leaderboard save contains a round receipt without a result.")
			receipt_ids[receipt.id] = true
			next_receipts.append({"id": receipt.id, "mode": receipt.mode, "player_id": receipt.player_id})
	profiles = next_profiles
	_bests = next_bests
	_receipts = next_receipts
	ready = true
	return true


func create_profile(player_name: String, avatar: String) -> Dictionary:
	error = ""
	if not ready:
		return _failure("Load players and leaderboards successfully before adding a player.")
	var normalized := player_name.strip_edges()
	if not _valid_name(normalized) or _has_controls(player_name):
		return _failure("Enter a name with 1 to 20 characters and no control characters.")
	if not AVATARS.has(avatar):
		return _failure("Choose an available avatar.")
	if not load_state():
		return _failure(error)
	if profiles.size() >= MAX_PROFILES:
		return _failure("This device already has ten players.")
	var profile := {"id": "player-" + _unique_id(), "name": normalized, "avatar": avatar}
	var next_profiles: Array[Dictionary] = profiles.duplicate(true)
	next_profiles.append(profile)
	if not _persist(next_profiles, _bests, _receipts):
		return _failure(error)
	profiles = next_profiles
	return {"ok": true, "profile": profile.duplicate(true), "error": ""}


func board(mode: String) -> Array[Dictionary]:
	return _board(mode, _bests)


func round_submission(round_id: String) -> Dictionary:
	for receipt in _receipts:
		if receipt.id == round_id:
			return receipt.duplicate(true)
	return {}


func submit_round(round_id: String, mode: String, player_id: String, result: Dictionary) -> Dictionary:
	error = ""
	if not ready:
		return _failure("Load players and leaderboards successfully before saving a result.")
	if not _valid_id(round_id) or not MODES.has(mode):
		return _failure("Choose a valid round and game mode.")
	var normalized := _normalized_result(mode, result)
	if normalized.is_empty():
		return _failure("This round does not contain a valid completed result.")
	# Re-read before writing so another menu or tab's latest changes are retained.
	if not load_state():
		return _failure(error)
	if not _has_player(player_id):
		return _failure("Choose a player saved on this device.")
	var before := board(mode)
	var old_rank := _rank(before, player_id)
	for receipt in _receipts:
		if receipt.id != round_id:
			continue
		if receipt.mode != mode or receipt.player_id != player_id:
			return _failure("This round has already been saved for another player or mode.")
		return {"ok": true, "error": "", "duplicate": true, "improved": false, "personal_best": false,
			"first_entry": false, "old_rank": old_rank, "new_rank": old_rank, "player_id": player_id,
			"before": before, "after": before.duplicate(true)}
	var next_bests: Dictionary = _bests.duplicate(true)
	var previous: Dictionary = next_bests[mode].get(player_id, {})
	var personal_best: bool = previous.is_empty() or _better(mode, normalized, previous)
	if personal_best:
		next_bests[mode][player_id] = normalized
	var next_receipts: Array[Dictionary] = _receipts.duplicate(true)
	next_receipts.append({"id": round_id, "mode": mode, "player_id": player_id})
	if next_receipts.size() > MAX_RECEIPTS:
		next_receipts.pop_front()
	if not _persist(profiles, next_bests, next_receipts):
		return _failure(error)
	_bests = next_bests
	_receipts = next_receipts
	var after := board(mode)
	var new_rank := _rank(after, player_id)
	return {"ok": true, "error": "", "duplicate": false,
		"improved": old_rank > 0 and new_rank < old_rank, "personal_best": personal_best,
		"first_entry": previous.is_empty(), "old_rank": old_rank, "new_rank": new_rank,
		"player_id": player_id, "before": before, "after": after}


func _board(mode: String, bests: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not MODES.has(mode):
		return rows
	for profile_index in range(profiles.size()):
		var profile: Dictionary = profiles[profile_index]
		if not bests[mode].has(profile.id):
			continue
		var result: Dictionary = bests[mode][profile.id]
		rows.append({"player_id": profile.id, "name": profile.name, "avatar": profile.avatar, "_order": profile_index,
			"rank": 0, "metric": result.get("hits", result.get("mistakes", result.get("attempts", 0))),
			"label": _label(mode, result), "result": result.duplicate(true)})
	# Sorting is stable for ties: profile creation order only determines display order.
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if _better(mode, a.result, b.result):
			return true
		return a._order < b._order if not _better(mode, b.result, a.result) else false)
	for index in range(rows.size()):
		rows[index].rank = index + 1
		if index > 0 and not _better(mode, rows[index - 1].result, rows[index].result):
			rows[index].rank = rows[index - 1].rank
	for row in rows:
		row.erase("_order")
	return rows


static func _normalized_result(mode: String, result: Dictionary) -> Dictionary:
	if mode == "pop":
		return {"hits": result.hits} if _valid_number(result.get("hits")) else {}
	if typeof(result.get("won")) != TYPE_BOOL or result.get("won") != true:
		return {}
	if mode == "match" and _valid_number(result.get("mistakes")) and _valid_number(result.get("hints_used")):
		return {"won": true, "mistakes": result.mistakes, "hints_used": result.hints_used}
	if mode == "memory" and _valid_number(result.get("attempts")) and _valid_number(result.get("peeks")):
		return {"won": true, "attempts": result.attempts, "peeks": result.peeks}
	return {}


static func _better(mode: String, left: Dictionary, right: Dictionary) -> bool:
	if mode == "pop":
		return left.hits > right.hits
	if mode == "match":
		return left.mistakes < right.mistakes or (left.mistakes == right.mistakes and left.hints_used < right.hints_used)
	return left.attempts < right.attempts or (left.attempts == right.attempts and left.peeks < right.peeks)


static func _label(mode: String, result: Dictionary) -> String:
	if mode == "pop":
		return "%d %s" % [result.hits, "hit" if result.hits == 1 else "hits"]
	if mode == "match":
		return "%d %s · %d %s" % [result.mistakes, "miss" if result.mistakes == 1 else "misses", result.hints_used, "hint" if result.hints_used == 1 else "hints"]
	return "%d %s · %d %s" % [result.attempts, "turn" if result.attempts == 1 else "turns", result.peeks, "peek" if result.peeks == 1 else "peeks"]


static func _valid_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 0 and value <= MAX_VALUE


static func _valid_name(value: String) -> bool:
	return value.length() >= 1 and value.length() <= 20 and not _has_controls(value)


static func _valid_id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 128 and value == value.strip_edges() and not _has_controls(value)


static func _has_controls(value: String) -> bool:
	for index in range(value.length()):
		var character := value.unicode_at(index)
		if character < 32 or (character >= 127 and character <= 159) or (character >= 0x200b and character <= 0x200f) or (character >= 0x2028 and character <= 0x202e) or (character >= 0x2060 and character <= 0x206f) or character == 0xfeff:
			return true
	return false


func _has_player(player_id: String) -> bool:
	return profiles.any(func(profile: Dictionary) -> bool: return profile.id == player_id)


static func _rank(rows: Array[Dictionary], player_id: String) -> int:
	for row in rows:
		if row.player_id == player_id:
			return row.rank
	return 0


func _persist(next_profiles: Array[Dictionary], next_bests: Dictionary, next_receipts: Array[Dictionary]) -> bool:
	var config := ConfigFile.new()
	config.set_value("leaderboard", "version", SAVE_VERSION)
	config.set_value("leaderboard", "profiles", next_profiles)
	config.set_value("leaderboard", "bests", next_bests)
	config.set_value("leaderboard", "receipts", next_receipts)
	if _browser_storage != null:
		if not bool(_browser_storage.saveLeaderboardState(config.encode_to_text())):
			return _fail("Could not save players and leaderboards. Device storage may be unavailable or full. Try again.")
		return true
	if not _restore_previous():
		return false
	var staged := _save_path + ".pending"
	var file := FileAccess.open(staged, FileAccess.WRITE)
	if file == null:
		_fail("Could not open the staged leaderboard save: %s." % error_string(FileAccess.get_open_error()))
		_discard_staged(staged)
		return false
	var written: bool = file.store_string(config.encode_to_text())
	file.flush()
	var status := file.get_error()
	file.close()
	if not written or status != OK:
		_fail("Could not write players and leaderboards: %s." % error_string(status if status != OK else ERR_FILE_CANT_WRITE))
		_discard_staged(staged)
		return false
	var previous := _save_path + ".previous"
	var moved_previous: bool = FileAccess.file_exists(_save_path)
	if moved_previous:
		status = DirAccess.rename_absolute(_save_path, previous)
		if status != OK:
			_fail("Could not preserve the previous leaderboard save: %s." % error_string(status))
			_discard_staged(staged)
			return false
	status = DirAccess.rename_absolute(staged, _save_path)
	if status != OK:
		_fail("Could not replace the leaderboard save: %s." % error_string(status))
		if moved_previous:
			var restored := DirAccess.rename_absolute(previous, _save_path)
			if restored != OK:
				error += " The previous save remains at %s; recovery failed: %s." % [previous, error_string(restored)]
		_discard_staged(staged)
		return false
	return true


func _restore_previous() -> bool:
	if FileAccess.file_exists(_save_path) or DirAccess.dir_exists_absolute(_save_path):
		return true
	var previous := _save_path + ".previous"
	if DirAccess.dir_exists_absolute(previous):
		return _fail("The interrupted leaderboard save has an unreadable recovery path.")
	if FileAccess.file_exists(previous):
		var status := DirAccess.rename_absolute(previous, _save_path)
		if status != OK:
			return _fail("Could not restore the previous leaderboard save: %s." % error_string(status))
	return true


func _discard_staged(path: String) -> void:
	if FileAccess.file_exists(path):
		var status := DirAccess.remove_absolute(path)
		if status != OK:
			error += " Could not remove the unfinished save: %s." % error_string(status)


func _failure(message: String) -> Dictionary:
	error = message
	return {"ok": false, "error": message, "duplicate": false, "improved": false}


func _fail(message: String) -> bool:
	error = message
	return false
