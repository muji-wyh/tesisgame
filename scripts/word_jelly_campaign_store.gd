extends RefCounted
## Progression and unpaid settlement journal; never grants coins or changes mastery.

const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
const BossCatalog = preload("res://scripts/word_jelly_boss_catalog.gd")
const VERSION: int = 3
const MAX_CONTEXTS: int = 256
const MAX_COMPLETED: int = 64
const MAX_RESULT_FIELDS: int = 32
const MAX_COMPLETED_WORDS: int = 128
const MAX_ID_LENGTH: int = 512
const MAX_SAVE_BYTES: int = 2 * 1024 * 1024
const MAX_SCALAR: int = 9007199254740991
const CONTEXT_KEYS: Array[String] = ["highest_cleared", "recipes", "ratings", "pending", "completed",
	"boss_victories", "challenge_best_stage"]
const RESULT_KEYS: Array[String] = ["kind", "number", "outcome", "stars"]
const TIME_FIELDS: Array[String] = ["time_elapsed", "seconds_remaining", "seconds_total", "seconds_added"]
const TRANSIENT_FIELDS: Array[String] = ["words", "practice", "image", "audio", "morphology",
	"media", "texture", "animation", "word_definitions"]

var ready: bool = false
var error: String = ""
var _path: String
var _host: Object
var _saved_text: Variant = null
var _contexts: Dictionary = {}


func _init(path: String = "user://jelly-campaign-v1.cfg", host: Object = null) -> void:
	_path = path
	_host = host
	if _host == null and OS.has_feature("web"):
		_host = JavaScriptBridge.get_interface("wordBuddiesHost")


func load_state() -> bool:
	ready = false
	error = ""
	if _path.is_empty():
		return _fail("Choose a campaign save path before loading stages.")
	if _host == null and not OS.has_feature("web") and not _recover_previous():
		return false
	var stored: Dictionary = _read_snapshot()
	if not stored.ok:
		return false
	var next_contexts: Dictionary = {}
	if stored.text != null:
		var config := ConfigFile.new()
		if config.parse(stored.text) != OK or config.get_sections().size() != 1 \
			or not config.has_section("campaign") or config.get_section_keys("campaign").size() != 2:
			return _fail("Your campaign save could not be understood. It has not been reset.")
		var version: Variant = config.get_value("campaign", "version", null)
		if not version is int or version not in [1, 2, VERSION]:
			return _fail("This campaign save needs a supported version.")
		var contexts: Variant = config.get_value("campaign", "contexts", null)
		if version < VERSION and contexts is Dictionary:
			contexts = contexts.duplicate(true)
			for state: Variant in contexts.values():
				if version == 1 and state is Dictionary and state.size() == 5 and not state.has("boss_victories"):
					state["boss_victories"] = []
				if state is Dictionary and state.size() == 6 and not state.has("challenge_best_stage"):
					state["challenge_best_stage"] = 0
		var validation_error: String = _contexts_error(contexts)
		if not validation_error.is_empty():
			return _fail(validation_error)
		next_contexts = contexts.duplicate(true)
	_contexts = next_contexts
	_saved_text = stored.text
	ready = true
	return true


func available(context: String, number: int) -> bool:
	if not _readable(context):
		return false
	if number < 1 or number > Catalog.MAX_STAGE:
		return _fail("Choose a main stage from 1 to 99.")
	return number <= mini(int(_context(context).highest_cleared) + 1, Catalog.MAX_STAGE)


func highest_cleared(context: String) -> int:
	if not _readable(context):
		return 0
	return int(_context(context).highest_cleared)


func frontier(context: String) -> int:
	if not _readable(context):
		return 0
	return mini(int(_context(context).highest_cleared) + 1, Catalog.MAX_STAGE)


func best_stars(context: String, number: int) -> int:
	if not _readable(context):
		return 0
	if number < 1 or number > Catalog.MAX_STAGE:
		_fail("Choose a main stage from 1 to 99 before reading its stars.")
		return 0
	return int(_context(context).ratings.get(str(number), 0))


func boss_victories(context: String) -> Array:
	if not _readable(context):
		return []
	return _context(context).boss_victories.duplicate()


func merged_level(context: String) -> int:
	return BossCatalog.merged_level(boss_victories(context))


func challenge_best_stage(context: String) -> int:
	return int(_context(context).challenge_best_stage) if _readable(context) else 0


func record_challenge_stage(context: String, stage: int) -> bool:
	error = ""
	if not _readable(context):
		return false
	if stage < 1 or stage > 16384:
		return _fail("A Challenge record needs a supported positive stage.")
	if not _current_snapshot_matches():
		return false
	var state: Dictionary = _context(context)
	if stage <= int(state.challenge_best_stage):
		return true
	if not _can_add_context(context):
		return false
	var next: Dictionary = _contexts.duplicate(true)
	var changed: Dictionary = state.duplicate(true)
	changed.challenge_best_stage = stage
	next[context] = changed
	return _commit(next)


func recipe(context: String, number: int) -> Dictionary:
	if not _readable(context):
		return {}
	if number < 1 or number > Catalog.MAX_STAGE:
		_fail("Choose a main stage from 1 to 99 before reading its recipe.")
		return {}
	return _context(context).recipes.get(str(number), {}).duplicate(true)


func reserve_plan(context: String, plan: Dictionary) -> bool:
	error = ""
	if not _readable(context):
		return false
	var reserved: Dictionary = Catalog.to_recipe(plan)
	if reserved.has("error"):
		return _fail(str(reserved.error))
	if reserved.kind != "main":
		return _fail("Only numbered main stages reserve campaign recipes.")
	var state: Dictionary = _context(context)
	var number: int = int(reserved.number)
	if number > mini(int(state.highest_cleared) + 1, Catalog.MAX_STAGE):
		return _fail("Clear the current frontier before reserving a later stage.")
	if not _current_snapshot_matches():
		return false
	var key: String = str(number)
	if state.recipes.has(key):
		if state.recipes[key] != reserved:
			return _fail("This stage already has an immutable recipe. Replay its original saved targets.")
		return true
	if not _can_add_context(context):
		return false
	var next: Dictionary = _contexts.duplicate(true)
	var changed: Dictionary = state.duplicate(true)
	changed.recipes[key] = reserved.duplicate(true)
	next[context] = changed
	return _commit(next)


func queue_result(context: String, round_id: String, result: Dictionary) -> bool:
	error = ""
	if not _readable(context):
		return false
	if not _valid_id(round_id):
		return _fail("A campaign settlement needs a valid round identity.")
	var state: Dictionary = _context(context)
	var validation_error: String = _result_error(result, state)
	if not validation_error.is_empty():
		return _fail(validation_error)
	if not _current_snapshot_matches():
		return false
	var fingerprint: String = _result_hash(result)
	for completed: Dictionary in state.completed:
		if completed.round_id == round_id:
			if completed.result_hash != fingerprint:
				return _fail("This completed round already has a different immutable result.")
			return true
	if not state.pending.is_empty():
		if state.pending.round_id == round_id:
			var saved: Dictionary = _stored_result(state.pending.result)
			var proposed: Dictionary = _stored_result(result)
			if saved.is_empty() or proposed.is_empty():
				return false
			if saved == proposed:
				return true
		return _fail("Finish the saved settlement before queuing another or changing its result.")
	if not _can_add_context(context):
		return false
	var next: Dictionary = _contexts.duplicate(true)
	var changed: Dictionary = state.duplicate(true)
	changed.pending = {"round_id": round_id, "result": result.duplicate(true)}
	next[context] = changed
	return _commit(next)


func pending(context: String) -> Dictionary:
	if not _readable(context):
		return {}
	return _context(context).pending.duplicate(true)


func complete_result(context: String, round_id: String) -> bool:
	error = ""
	if not _readable(context):
		return false
	if not _valid_id(round_id):
		return _fail("Completing a settlement needs its original valid round identity.")
	var state: Dictionary = _context(context)
	if not _current_snapshot_matches():
		return false
	for completed: Dictionary in state.completed:
		if completed.round_id == round_id:
			return true
	if state.pending.is_empty() or state.pending.round_id != round_id:
		return _fail("This round has no matching pending settlement. Another result has not been removed.")
	var result: Dictionary = state.pending.result
	var changed: Dictionary = state.duplicate(true)
	if result.kind == "main" and result.outcome == "cleared":
		var number: int = int(result.number)
		var highest: int = int(state.highest_cleared)
		if number > highest + 1:
			return _fail("A campaign clear must extend the contiguous frontier, not skip stages.")
		changed.highest_cleared = maxi(highest, number)
		var key: String = str(number)
		changed.ratings[key] = maxi(int(changed.ratings.get(key, 0)), int(result.stars))
		if bool(result.get("boss_victory", false)) and int(result.boss_id) not in changed.boss_victories:
			changed.boss_victories.append(int(result.boss_id))
			changed.boss_victories.sort()
	if result.kind == "challenge":
		changed.challenge_best_stage = maxi(int(changed.challenge_best_stage), int(result.get("challenge_stage", 0)))
	changed.completed.append({"round_id": round_id, "result_hash": _result_hash(result)})
	while changed.completed.size() > MAX_COMPLETED:
		changed.completed.pop_front()
	changed.pending = {}
	var next: Dictionary = _contexts.duplicate(true)
	next[context] = changed
	return _commit(next)


func _commit(next_contexts: Dictionary) -> bool:
	var validation_error: String = _contexts_error(next_contexts)
	if not validation_error.is_empty():
		return _fail(validation_error)
	var config := ConfigFile.new()
	config.set_value("campaign", "version", VERSION)
	config.set_value("campaign", "contexts", next_contexts)
	var text: String = config.encode_to_text()
	if text.to_utf8_buffer().size() > MAX_SAVE_BYTES:
		return _fail("Campaign storage is full. This change has not been saved.")
	if _host != null:
		if not _host_method("saveJellyCampaignState"):
			return _fail("Campaign storage is unavailable. The host cannot save stages.")
		var acknowledged: Variant = _host.saveJellyCampaignState(text, _saved_text)
		if not acknowledged is bool or not acknowledged:
			return _fail("Your campaign has not saved. Retry; reload if another session changed it.")
	elif OS.has_feature("web"):
		return _fail("Campaign storage is unavailable. Please retry.")
	elif not _persist_native(text):
		return false
	_contexts = next_contexts
	_saved_text = text
	return true


func _persist_native(text: String) -> bool:
	if not _current_snapshot_matches():
		return false
	var staging: String = _path + ".pending"
	var previous: String = _path + ".previous"
	var file := FileAccess.open(staging, FileAccess.WRITE)
	if file == null:
		return _fail("Your campaign has not saved. Could not write its staging file.")
	file.store_string(text)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return _fail("Your campaign has not saved. Could not finish writing its staging file.")
	if not _current_snapshot_matches():
		return false
	if DirAccess.dir_exists_absolute(previous):
		return _fail("Your campaign has not saved. Its recovery path is unavailable.")
	if FileAccess.file_exists(previous) and DirAccess.remove_absolute(previous) != OK:
		return _fail("Could not preserve your previous campaign. Please retry.")
	var had_previous: bool = FileAccess.file_exists(_path)
	if had_previous and DirAccess.rename_absolute(_path, previous) != OK:
		return _fail("Could not preserve your previous campaign. Please retry.")
	if DirAccess.rename_absolute(staging, _path) != OK:
		if had_previous and DirAccess.rename_absolute(previous, _path) != OK:
			return _fail("Campaign replacement failed. The last committed save remains in its recovery file.")
		return _fail("Your campaign has not saved. Please retry.")
	if had_previous:
		DirAccess.remove_absolute(previous)
	return true


func _recover_previous() -> bool:
	if DirAccess.dir_exists_absolute(_path):
		return _fail("Campaign storage is unavailable: its save path is a directory.")
	if not FileAccess.file_exists(_path) and FileAccess.file_exists(_path + ".previous"):
		if DirAccess.rename_absolute(_path + ".previous", _path) != OK:
			return _fail("Could not restore your previous campaign. It has not been reset.")
	return true


func _read_snapshot() -> Dictionary:
	var text: Variant = null
	if _host != null:
		if not _host_method("jellyCampaignState"):
			_fail("Campaign storage is unavailable. The host cannot read stages.")
			return {"ok": false}
		text = _host.jellyCampaignState()
	elif OS.has_feature("web"):
		_fail("Campaign storage is unavailable. Please retry.")
		return {"ok": false}
	elif DirAccess.dir_exists_absolute(_path):
		_fail("Campaign storage is unavailable: its save path is a directory.")
		return {"ok": false}
	elif FileAccess.file_exists(_path):
		var file := FileAccess.open(_path, FileAccess.READ)
		if file == null or file.get_length() > MAX_SAVE_BYTES:
			_fail("Could not read your campaign, or its save exceeds the supported size.")
			return {"ok": false}
		text = file.get_as_text()
		var read_error: Error = file.get_error()
		file.close()
		if read_error != OK and read_error != ERR_FILE_EOF:
			_fail("Could not finish reading your campaign. It has not been reset.")
			return {"ok": false}
	if text != null and (not text is String or text.is_empty() or text.to_utf8_buffer().size() > MAX_SAVE_BYTES):
		_fail("Campaign storage is unreadable or exceeds its supported size. It has not been reset.")
		return {"ok": false}
	return {"ok": true, "text": text}


func _current_snapshot_matches() -> bool:
	var stored: Dictionary = _read_snapshot()
	if not stored.ok:
		return false
	if stored.text != _saved_text:
		return _fail("Your campaign changed in another session. Reload before changing its progress.")
	return true


func _host_method(method: String) -> bool:
	# JavaScriptObject forwards dynamic host methods rather than listing them.
	return _host.has_method(method) or _host.get_class() == "JavaScriptObject"


func _readable(context: String) -> bool:
	if not ready:
		if error.is_empty():
			_fail("Load your campaign successfully before reading or changing its stages.")
		return false
	if not _valid_context(context):
		return _fail("Use growth or a stable professional career/module context, without an age key.")
	return true


func _can_add_context(context: String) -> bool:
	if not _contexts.has(context) and _contexts.size() >= MAX_CONTEXTS:
		return _fail("Campaign storage has reached its supported context limit.")
	return true


func _context(context: String) -> Dictionary:
	return _contexts.get(context, {"highest_cleared": 0, "recipes": {}, "ratings": {},
		"pending": {}, "completed": [], "boss_victories": [], "challenge_best_stage": 0})


func _contexts_error(value: Variant) -> String:
	if not value is Dictionary or value.size() > MAX_CONTEXTS:
		return "Your campaign contains an invalid or oversized context collection."
	for context: Variant in value:
		if not _valid_context(context):
			return "Your campaign contains an invalid learning context. It has not been reset."
		var validation_error: String = _context_error(value[context])
		if not validation_error.is_empty():
			return validation_error
	return ""


func _context_error(value: Variant) -> String:
	if not value is Dictionary or value.size() != CONTEXT_KEYS.size() or not value.has_all(CONTEXT_KEYS):
		return "A campaign context needs its complete progression and journal."
	if not value.highest_cleared is int or value.highest_cleared < 0 or value.highest_cleared > Catalog.MAX_STAGE \
		or not value.recipes is Dictionary or value.recipes.size() > Catalog.MAX_STAGE \
		or not value.ratings is Dictionary or value.ratings.size() != value.highest_cleared \
		or not value.completed is Array or value.completed.size() > MAX_COMPLETED \
		or not value.pending is Dictionary:
		return "Your campaign contains an invalid frontier, recipe collection, ratings or journal."
	if not value.boss_victories is Array or value.boss_victories.size() > BossCatalog.STAGES.size():
		return "Your campaign contains invalid Boss victory evidence."
	if not value.challenge_best_stage is int or value.challenge_best_stage < 0 or value.challenge_best_stage > 16384:
		return "Your Challenge best stage must be a supported nonnegative whole stage."
	var previous_boss: int = 0
	for id: Variant in value.boss_victories:
		if not id is int or id <= previous_boss or id > BossCatalog.STAGES.size() \
			or BossCatalog.STAGES[id - 1] > int(value.highest_cleared):
			return "Boss victories must be distinct, ordered and belong to cleared stages."
		previous_boss = id
	for key: Variant in value.recipes:
		var number: int = _stage_key(key)
		if number == 0 or number > mini(int(value.highest_cleared) + 1, Catalog.MAX_STAGE):
			return "Your campaign contains a locked or out-of-range recipe."
		var recipe_error: String = Catalog.recipe_error(value.recipes[key])
		if not recipe_error.is_empty():
			return recipe_error
		if value.recipes[key].kind != "main" or value.recipes[key].number != number:
			return "A saved main-stage recipe must match its numbered map position."
	for number in range(1, int(value.highest_cleared) + 1):
		var key: String = str(number)
		if not value.recipes.has(key) or not value.ratings.get(key) is int \
			or value.ratings[key] < 1 or value.ratings[key] > 3:
			return "Your campaign clear history must be contiguous and retain its best stars and recipes."
	var completed_ids: Dictionary = {}
	for completed: Variant in value.completed:
		if not completed is Dictionary or completed.size() != 2 \
			or not _valid_id(completed.get("round_id")) or not _valid_hash(completed.get("result_hash")) \
			or completed_ids.has(completed.round_id):
			return "Your campaign contains an invalid completed-round receipt."
		completed_ids[completed.round_id] = true
	if not value.pending.is_empty():
		if value.pending.size() != 2 or not _valid_id(value.pending.get("round_id")) \
			or completed_ids.has(value.pending.round_id):
			return "Your campaign contains an invalid pending-round identity."
		var result_error: String = _result_error(value.pending.get("result"), value)
		if not result_error.is_empty():
			return result_error
	return ""


func _result_error(value: Variant, context: Dictionary) -> String:
	if not value is Dictionary or not value.has_all(RESULT_KEYS) or value.size() > MAX_RESULT_FIELDS:
		return "A settlement needs its kind, stage number, outcome and stars within the field limit."
	if not value.kind is String or value.kind not in ["main", "challenge"] \
		or not value.number is int or not value.outcome is String \
		or value.outcome not in ["cleared", "timeout", "blocked", "exit"] \
		or not value.stars is int or value.stars < 0 or value.stars > 3:
		return "A settlement has an invalid kind, stage, terminal outcome or whole star rating."
	if value.kind == "challenge":
		if value.number != 0 or value.stars != 0 or value.outcome == "cleared":
			return "A survival challenge cannot claim a numbered clear or star reward."
	else:
		if value.number < 1 or value.number > Catalog.MAX_STAGE \
			or value.number > mini(int(context.highest_cleared) + 1, Catalog.MAX_STAGE) \
			or not context.recipes.has(str(value.number)):
			return "A main settlement needs its unlocked, reserved stage recipe."
		if (value.stars == 0 if value.outcome == "cleared" else value.stars != 0):
			return "Only a cleared main stage earns one, two or three stars."
	if value.get("boss_victory", false):
		if not value.get("boss_victory") is bool or value.kind != "main" or value.outcome != "cleared" \
			or not value.get("boss_id") is int or value.boss_id < 1 or value.boss_id > BossCatalog.STAGES.size() \
			or (BossCatalog.STAGES[value.boss_id - 1] != value.number \
				and (value.has("boss_roster_version") or BossCatalog.LEGACY_STAGES[value.boss_id - 1] != value.number)):
			return "A Boss unlock needs the original cleared Boss stage and its matching encounter identity."
	if value.has("boss_roster_version") and (not value.boss_roster_version is int or value.boss_roster_version != 2):
		return "The Boss settlement has an unsupported encounter roster."
	if value.has("challenge_stage") and (value.kind != "challenge" or not value.challenge_stage is int \
		or value.challenge_stage < 1 or value.challenge_stage > 16384):
		return "A Challenge result needs its actual supported stage."
	if value.has("challenge_previous_best") and (value.kind != "challenge" or not value.challenge_previous_best is int \
		or value.challenge_previous_best < 0 or value.challenge_previous_best > 16384):
		return "A Challenge comparison needs its actual nonnegative pre-run record."
	for key: Variant in value:
		if not key is String or key.is_empty() or key.length() > 64 or not _field_name(key):
			return "Settlement field names must be bounded stable identifiers."
		if key in TRANSIENT_FIELDS:
			return "Settlement metadata must retain completed word IDs, not transient media definitions."
		var item: Variant = value[key]
		if key == "completed_word_ids":
			if not item is Array or item.size() > MAX_COMPLETED_WORDS:
				return "Settlement word evidence must be a bounded list of completed identities."
			var seen: Dictionary = {}
			for id: Variant in item:
				if not _valid_id(id) or seen.has(id):
					return "Settlement completed-word identities must be valid and distinct."
				seen[id] = true
			continue
		if (key in ["collection_count", "chest_coins", "bonus", "clear_bonus"] or key.ends_with("_coins")) \
			and not item is int:
			return "Settlement counts and coin amounts must be whole numbers."
		if key in TIME_FIELDS and not (item is int or item is float):
			return "Settlement time must be a finite nonnegative number."
		if item is bool:
			continue
		if item is int or item is float:
			if not is_finite(float(item)) or item < 0 or item > MAX_SCALAR:
				return "Settlement numbers must be finite, nonnegative and within the supported range."
			if (key in TIME_FIELDS or key == "collection_count") and item > 1000000000:
				return "Settlement duration or collection count exceeds the supported per-run limit."
			continue
		if item is String and item.length() <= MAX_ID_LENGTH and _plain_text(item):
			continue
		return "Settlement metadata must use bounded scalars, not transient media or full word definitions."
	return ""


func _stage_key(value: Variant) -> int:
	if not value is String or not value.is_valid_int():
		return 0
	var number: int = int(value)
	return number if number >= 1 and number <= Catalog.MAX_STAGE and str(number) == value else 0


func _valid_context(value: Variant) -> bool:
	if not _valid_id(value):
		return false
	if value == "growth":
		return true
	var parts: PackedStringArray = value.split(":", true)
	if parts.size() != 3 or parts[0] != "professional":
		return false
	for component: String in [parts[1], parts[2]]:
		if component.is_empty() or component.length() > 128:
			return false
		for character: String in component:
			if character not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.":
				return false
	return true


func _valid_id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= MAX_ID_LENGTH \
		and value.strip_edges() == value and _plain_text(value)


func _plain_text(value: String) -> bool:
	for index in range(value.length()):
		if value.unicode_at(index) < 32 or value.unicode_at(index) == 127:
			return false
	return true


func _field_name(value: String) -> bool:
	for character: String in value:
		if character not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_":
			return false
	return true


func _valid_hash(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true


func _result_hash(result: Dictionary) -> String:
	return JSON.stringify(result).sha256_text()


func _stored_result(result: Dictionary) -> Dictionary:
	# ConfigFile bounds floating-point precision. Compare retries in that same
	# storage representation, without rounding away changed integer rewards.
	var config := ConfigFile.new()
	config.set_value("settlement", "result", result)
	var stored := ConfigFile.new()
	if stored.parse(config.encode_to_text()) != OK:
		_fail("The saved settlement comparison could not be encoded.")
		return {}
	var value: Variant = stored.get_value("settlement", "result")
	if not value is Dictionary:
		_fail("The saved settlement comparison is not a result dictionary.")
		return {}
	return value


func _fail(message: String) -> bool:
	error = message
	return false
