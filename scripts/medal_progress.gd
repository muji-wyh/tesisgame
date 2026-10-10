extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const SAVE_VERSION: int = 1
const PAIR_SAVE_VERSION: int = 1
const PAIR_MODES: Array[String] = ["match", "memory"]
const PAIRS_PER_ROUND: int = 5

var counts: Dictionary = {}
var legacy_rewards: Dictionary = {}
var error: String = ""

var _save_path: String
var _legacy_path: String
var _loaded: bool = false
var _browser_storage: Object
var _browser_snapshot: Variant = null
var _pair_state: Dictionary = {
	"match": {"dry_rounds": 0, "round": {}},
	"memory": {"dry_rounds": 0, "round": {}}
}


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
	if browser_text != null and not browser_text is String:
		return _fail("Could not read browser medal progress. Browser storage may be unavailable.")
	_browser_snapshot = browser_text
	var status: int
	if browser_text != null:
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
	var next_pair_state: Dictionary = {
		"match": {"dry_rounds": 0, "round": {}},
		"memory": {"dry_rounds": 0, "round": {}}
	}
	if not migrating:
		var version: Variant = config.get_value("medals", "version", -1)
		if typeof(version) != TYPE_INT or version != SAVE_VERSION:
			return _fail("The medal save version is missing, invalid, or unsupported; expected version %d." % SAVE_VERSION)
		var saved_counts: Variant = config.get_value("medals", "counts", false)
		if not _validate_counts(saved_counts):
			return false
		next_counts = saved_counts.duplicate()
		if config.has_section("pair_chests"):
			var pair_version: Variant = config.get_value("pair_chests", "version", -1)
			if typeof(pair_version) != TYPE_INT or pair_version != PAIR_SAVE_VERSION:
				return _fail("The pair chest save version is missing, invalid, or unsupported.")
			var saved_pairs: Variant = config.get_value("pair_chests", "state", false)
			if not _validate_pair_state(saved_pairs):
				return false
			next_pair_state = saved_pairs.duplicate(true)
	var earned := _read_legacy()
	if not error.is_empty():
		return false
	var archives: Dictionary = {}
	for id in earned:
		if Data.medal(id).is_empty():
			archives[id] = true
		elif migrating:
			next_counts[id] = Data.PIECES_PER_MEDAL
	if (migrating or (_browser_storage != null and browser_text == null)) and not _persist(next_counts, next_pair_state):
		return false
	counts = next_counts
	_pair_state = next_pair_state
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
	if not _validate_fragment(fragment):
		return false
	var id: String = fragment.medal_id
	var before: int = fragment.before
	var after: int = fragment.after
	var current := count_for(id)
	if current == after:
		return true
	if current != before:
		return _fail("The captured fragment for %s is stale or out of order: expected %d pieces, found %d." % [id, before, current])
	if not _fragment_in_order(id):
		return false
	var next_counts := counts.duplicate()
	next_counts[id] = after
	if not _validate_counts(next_counts) or not _persist(next_counts):
		return false
	counts = next_counts
	return true


func pair_round(mode: String) -> Dictionary:
	if not PAIR_MODES.has(mode):
		return {}
	return _pair_state[mode].round.duplicate(true)


func pair_dry_rounds(mode: String) -> int:
	return int(_pair_state[mode].dry_rounds) if PAIR_MODES.has(mode) else 0


func begin_pair_round(mode: String, id: String, proposed_pair: int) -> Dictionary:
	error = ""
	if not _pair_ready(mode, id):
		return {}
	if proposed_pair < 0 or proposed_pair > PAIRS_PER_ROUND:
		_fail("The chest reveal pair must be zero or an integer from one to five.")
		return {}
	var current: Dictionary = pair_round(mode)
	if not current.is_empty() and str(current.id) == id:
		return current
	if not current.is_empty() and bool(current.awarded) and not bool(current.settled):
		_fail("Save the earned chest before starting another " + mode + " round.")
		return {}
	var next_state: Dictionary = _pair_state.duplicate(true)
	var next_round: Dictionary
	if not current.is_empty() and not bool(current.awarded) and not bool(current.completed):
		# A restart can change the board, but never rerolls its reserved chance.
		next_round = current
		next_round.id = id
	else:
		next_round = {"id": id, "pair": maxi(1, proposed_pair) if pair_dry_rounds(mode) >= 2 else proposed_pair,
			"awarded": false, "settled": false, "completed": false, "theme": "", "fragment": {}}
	next_state[mode].round = next_round
	if not _commit_pair_state(next_state):
		return {}
	return pair_round(mode)


func record_pair_reward(mode: String, id: String, theme: String) -> bool:
	error = ""
	if not _pair_ready(mode, id):
		return false
	var current: Dictionary = pair_round(mode)
	if current.is_empty() or str(current.id) != id:
		return _fail("The chest belongs to a different or missing " + mode + " round.")
	if bool(current.awarded):
		return true
	if bool(current.completed) or int(current.pair) == 0:
		return _fail("This " + mode + " round has no reserved chest to award.")
	var fragment: Dictionary = next_fragment(theme)
	if not error.is_empty():
		return false
	var next_state: Dictionary = _pair_state.duplicate(true)
	next_state[mode].dry_rounds = 0
	next_state[mode].round.awarded = true
	next_state[mode].round.theme = theme
	next_state[mode].round.fragment = fragment
	return _commit_pair_state(next_state)


func finish_pair_round(mode: String, id: String) -> bool:
	error = ""
	if not _pair_ready(mode, id):
		return false
	var current: Dictionary = pair_round(mode)
	if current.is_empty() or str(current.id) != id:
		return _fail("The completed round is not the active " + mode + " round.")
	if bool(current.completed):
		return true
	if int(current.pair) > 0 and not bool(current.awarded):
		return _fail("Save this round's earned chest before completing the round.")
	var next_state: Dictionary = _pair_state.duplicate(true)
	next_state[mode].round.completed = true
	if not bool(current.awarded):
		next_state[mode].dry_rounds = mini(2, pair_dry_rounds(mode) + 1)
	return _commit_pair_state(next_state)


func settle_pair_reward(mode: String, id: String) -> bool:
	error = ""
	if not _pair_ready(mode, id):
		return false
	var current: Dictionary = pair_round(mode)
	if current.is_empty() or str(current.id) != id or not bool(current.awarded):
		return _fail("There is no earned chest for this " + mode + " round.")
	if bool(current.settled):
		return true
	var next_counts: Dictionary = counts.duplicate()
	var fragment: Dictionary = current.fragment
	if not fragment.is_empty():
		var medal_id: String = fragment.medal_id
		if count_for(medal_id) != int(fragment.before):
			return _fail("The pending chest's medal fragment is stale; preserve it and retry saving.")
		if not _fragment_in_order(medal_id):
			return false
		next_counts[medal_id] = int(fragment.after)
	var next_state: Dictionary = _pair_state.duplicate(true)
	next_state[mode].round.settled = true
	# Contents and consumption share one save, so interruption cannot grant twice.
	if not _persist(next_counts, next_state):
		return false
	counts = next_counts
	_pair_state = next_state
	return true


func _pair_ready(mode: String, id: String) -> bool:
	if not _loaded:
		return _fail("Load medal progress successfully before changing pair chest progress.")
	if not PAIR_MODES.has(mode):
		return _fail("Pair chest progress supports Match and Memory only.")
	if id.is_empty() or id.length() > 200:
		return _fail("Pair chest progress needs a nonempty round ID of at most 200 characters.")
	return true


func _commit_pair_state(next_state: Dictionary) -> bool:
	if not _validate_pair_state(next_state) or not _persist(counts, next_state):
		return false
	_pair_state = next_state
	return true


func _validate_pair_state(value: Variant) -> bool:
	if not value is Dictionary or value.size() != PAIR_MODES.size():
		return _fail("Pair chest progress needs separate Match and Memory records.")
	for mode in PAIR_MODES:
		var entry: Variant = value.get(mode)
		if not entry is Dictionary:
			return _fail("The " + mode + " chest progress is missing or invalid.")
		var dry: Variant = entry.get("dry_rounds")
		if typeof(dry) != TYPE_INT or dry < 0 or dry > 2:
			return _fail("Consecutive rounds without a chest must be an integer from zero to two.")
		var round: Variant = entry.get("round")
		if not round is Dictionary:
			return _fail("The reserved " + mode + " round must be a dictionary.")
		if round.is_empty():
			continue
		var id: Variant = round.get("id")
		var pair: Variant = round.get("pair")
		if typeof(id) != TYPE_STRING or id.is_empty() or id.length() > 200 \
			or typeof(pair) != TYPE_INT or pair < 0 or pair > PAIRS_PER_ROUND:
			return _fail("A reserved chest needs a round ID and a valid reveal pair.")
		for flag in ["awarded", "settled", "completed"]:
			if typeof(round.get(flag)) != TYPE_BOOL:
				return _fail("Reserved chest status flags must be booleans.")
		var theme: Variant = round.get("theme")
		var fragment: Variant = round.get("fragment")
		if typeof(theme) != TYPE_STRING or not fragment is Dictionary:
			return _fail("The reserved chest theme or captured fragment is invalid.")
		if bool(round.awarded):
			if pair == 0 or dry != 0 or not Data.THEMES.has(theme):
				return _fail("An earned chest needs a reserved pair, a theme, and a reset dry streak.")
			if not fragment.is_empty() and (not _validate_fragment(fragment) or str(Data.medal(fragment.medal_id).theme) != theme):
				return _fail("The earned chest's captured fragment does not match its theme.")
		elif bool(round.settled) or not theme.is_empty() or not fragment.is_empty() \
			or (bool(round.completed) and pair > 0) or (not bool(round.completed) and dry == 2 and pair == 0):
			return _fail("An unearned chest cannot contain a reward or bypass its guarantee.")
	return true


func _validate_fragment(fragment: Dictionary) -> bool:
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
	return true


func _fragment_in_order(id: String) -> bool:
	for medal in Data.medals(Data.medal(id).theme):
		if count_for(medal.id) < Data.PIECES_PER_MEDAL:
			if medal.id != id:
				return _fail("Finish the first incomplete medal, %s, before awarding a piece to %s." % [medal.id, id])
			break
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


func _persist(next_counts: Dictionary, next_pair_state: Dictionary = {}) -> bool:
	var config := ConfigFile.new()
	config.set_value("medals", "version", SAVE_VERSION)
	config.set_value("medals", "counts", next_counts)
	config.set_value("pair_chests", "version", PAIR_SAVE_VERSION)
	config.set_value("pair_chests", "state", _pair_state if next_pair_state.is_empty() else next_pair_state)
	if _browser_storage != null:
		var current: Variant = _browser_storage.medalProgress()
		if current != null and not current is String:
			return _fail("Could not read browser medal progress. Browser storage may be unavailable.")
		if current != _browser_snapshot:
			return _fail("Progress changed in another tab. Reload this page before saving rewards.")
		var next_text: String = config.encode_to_text()
		if not bool(_browser_storage.saveMedalProgress(next_text)):
			return _fail("Could not save browser medal progress. Browser storage may be unavailable or full.")
		_browser_snapshot = next_text
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
