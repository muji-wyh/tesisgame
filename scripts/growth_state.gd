extends RefCounted
## Durable, device-local learning progress, independent of treasure rewards.

const VERSION: int = 1
const FIRST_LEVEL: int = 3
const LAST_LEVEL: int = 12
const MASTERY_STREAK: int = 6
const MAX_RECEIPTS: int = 4096
const MAX_EVENT_LENGTH: int = 256
const MAX_SAVE_ATTEMPTS: int = 3
static var _id_sequence: int = 0

var level: int = FIRST_LEVEL
var completed: bool = false
var ready: bool = false
var error: String = ""

var _path: String
var _host: Object
var _word_ages: Dictionary = {}
var _cohorts: Dictionary = {}
var _streaks: Dictionary = {}
var _receipts: Array[String] = []
var _receipt_set: Dictionary = {}
var _pending: Array[Dictionary] = []
var _pending_ids: Dictionary = {}
var _configured: bool = false


static func make_round_id() -> String:
	_id_sequence += 1
	var random := RandomNumberGenerator.new()
	random.randomize()
	return "round-%s-%x-%x-%x" % [str(int(Time.get_unix_time_from_system() * 1000.0)), Time.get_ticks_usec(), random.randi(), _id_sequence]


func _init(path: String = "user://growth-v1.cfg", host: Object = null) -> void:
	_path = path
	_host = host
	if _host == null and OS.has_feature("web"):
		_host = JavaScriptBridge.get_interface("wordBuddiesHost")


func configure(words: Array) -> bool:
	if not _pending.is_empty():
		return _fail("Save your pending learning progress before changing the vocabulary.")
	var ages: Dictionary = {}
	var cohorts: Dictionary = {}
	for age in range(FIRST_LEVEL, LAST_LEVEL + 1):
		cohorts[age] = []
	for word in words:
		if not word is Dictionary or not word.get("id") is String or String(word.id).strip_edges().is_empty() \
			or not _whole_number(word.get("min_age"), FIRST_LEVEL, LAST_LEVEL) or ages.has(word.id):
			return _fail("Learning words need unique IDs and a whole-number age from 3 to 12.")
		ages[word.id] = int(word.min_age)
		cohorts[int(word.min_age)].append(word.id)
	if ages.is_empty():
		return _fail("Learning progress needs a vocabulary.")
	_word_ages = ages
	_cohorts = cohorts
	_configured = true
	ready = false
	error = ""
	return true


func load_state() -> bool:
	if not _pending.is_empty():
		return _fail("Your learning progress is waiting to be saved. Please retry saving.")
	ready = false
	error = ""
	if not _configured or _path.is_empty():
		return _fail("Configure the vocabulary and a save path before loading learning progress.")
	var saved: Dictionary = _read_state()
	if saved.is_empty():
		return false
	_use_saved(saved)
	ready = true
	return true


func _read_state() -> Dictionary:
	var config := ConfigFile.new()
	var missing: bool = false
	var saved_text: Variant = null
	if _host != null:
		saved_text = _host.growthState()
		if saved_text == null:
			missing = true
		elif not saved_text is String or config.parse(saved_text) != OK:
			return _invalid_save("Could not read your learning progress. Please retry.")
	elif OS.has_feature("web"):
		return _invalid_save("Learning progress storage is unavailable. Please retry.")
	else:
		if not _restore_previous():
			return {}
		var result: Error = config.load(_path)
		missing = result == ERR_FILE_NOT_FOUND and not FileAccess.file_exists(_path) and not DirAccess.dir_exists_absolute(_path)
		if result != OK and not missing:
			return _invalid_save("Could not read your learning progress. Please retry.")
	var next_level: int = FIRST_LEVEL
	var next_streaks: Dictionary = {}
	var next_receipts: Array[String] = []
	var receipt_ids: Dictionary = {}
	if not missing:
		for key in ["version", "level", "streaks", "receipts"]:
			if not config.has_section_key("growth", key):
				return _invalid_save("Your learning progress save is incomplete.")
		if config.get_value("growth", "version") != VERSION:
			return _invalid_save("This learning progress save needs a supported version.")
		var saved_level: Variant = config.get_value("growth", "level")
		var saved_streaks: Variant = config.get_value("growth", "streaks")
		var saved_receipts: Variant = config.get_value("growth", "receipts")
		if not _whole_number(saved_level, FIRST_LEVEL, LAST_LEVEL) or not saved_streaks is Dictionary \
			or not saved_receipts is Array or saved_receipts.size() > MAX_RECEIPTS:
			return _invalid_save("Your learning progress could not be understood.")
		next_level = int(saved_level)
		for id in saved_streaks:
			if not id is String or not _word_ages.has(id) \
				or not _whole_number(saved_streaks[id], 0, MASTERY_STREAK) \
				or (int(_word_ages[id]) > next_level and int(saved_streaks[id]) > 0):
				return _invalid_save("Your learning progress contains an invalid word streak.")
			if int(saved_streaks[id]) > 0:
				next_streaks[id] = int(saved_streaks[id])
		for receipt in saved_receipts:
			if not _valid_event_id(receipt) or receipt_ids.has(receipt):
				return _invalid_save("Your learning progress contains an invalid answer receipt.")
			next_receipts.append(receipt)
			receipt_ids[receipt] = true
	return {"level": next_level, "streaks": next_streaks, "receipts": next_receipts, "text": saved_text}


func _use_saved(saved: Dictionary) -> void:
	level = int(saved.level)
	_streaks = saved.streaks
	_receipts.assign(saved.receipts)
	_receipt_set.clear()
	for receipt in _receipts:
		_receipt_set[receipt] = true
	completed = level == LAST_LEVEL and _cohort_mastered(level, _streaks)
	error = ""


func record_attempt(event_id: String, word_ids: Array, correct: bool) -> Dictionary:
	if not ready:
		return _outcome(false, false, false, level, "Load learning progress successfully before recording an answer.")
	if not _valid_event_id(event_id) or word_ids.is_empty():
		return _outcome(false, false, false, level, "An answer needs a valid event ID and at least one word.")
	if _receipt_set.has(event_id) or _pending_ids.has(event_id):
		var duplicate: Dictionary = retry_pending()
		duplicate["duplicate"] = true
		duplicate["ignored"] = true
		return duplicate
	var eligible: Array[String] = []
	for id in word_ids:
		if not id is String or not _word_ages.has(id):
			return _outcome(false, false, false, level, "An answer contains an unknown learning word.")
		# Capture eligibility now. A delayed save must not credit future vocabulary
		# after an earlier queued answer has unlocked that age.
		if int(_word_ages[id]) <= level and not eligible.has(id):
			eligible.append(id)
	_pending.append({"id": event_id, "words": eligible, "correct": correct})
	_pending_ids[event_id] = true
	var result: Dictionary = retry_pending()
	result["accepted"] = true
	result["ignored"] = eligible.is_empty()
	return result


func retry_pending() -> Dictionary:
	var before: int = level
	if not ready:
		return _outcome(false, false, false, before, "Load learning progress successfully before retrying an answer.")
	if _pending.is_empty() and _host == null:
		error = ""
		return _outcome(true, true, false, before)
	var previous_expected: Variant = null
	for attempt in range(MAX_SAVE_ATTEMPTS):
		# Another tab may have saved a mistake or promotion since this instance
		# loaded. Replay events on that state; merging maximum streaks would undo
		# real wrong answers. Event eligibility stays as captured on acceptance.
		var saved: Dictionary = _read_state() if _host != null else {
			"level": level, "streaks": _streaks, "receipts": _receipts, "text": null}
		if saved.is_empty():
			return _outcome(true, false, false, before)
		if attempt > 0 and saved.text == previous_expected:
			return _outcome(true, false, false, before)
		var next_streaks: Dictionary = saved.streaks.duplicate()
		var next_receipts: Array[String] = []
		next_receipts.assign(saved.receipts)
		var seen: Dictionary = {}
		for receipt in next_receipts:
			seen[receipt] = true
		var next_level: int = maxi(level, int(saved.level))
		var changed_words: Array[String] = []
		var new_events: int = 0
		for event in _pending:
			if seen.has(event.id):
				continue
			new_events += 1
			for id: String in event.words:
				var previous: int = int(next_streaks.get(id, 0))
				var value: int = mini(MASTERY_STREAK, previous + 1) if event.correct else 0
				if value > 0:
					next_streaks[id] = value
				else:
					next_streaks.erase(id)
				if value != previous and not changed_words.has(id):
					changed_words.append(id)
			while next_level < LAST_LEVEL and _cohort_mastered(next_level, next_streaks):
				next_level += 1
			next_receipts.append(event.id)
			seen[event.id] = true
			if next_receipts.size() > MAX_RECEIPTS:
				next_receipts.pop_front()
		var duplicate: bool = not _pending.is_empty() and new_events == 0
		if new_events > 0 or next_level != int(saved.level):
			if not _persist(next_level, next_streaks, next_receipts, saved.text):
				previous_expected = saved.text
				continue
		_use_saved({"level": next_level, "streaks": next_streaks, "receipts": next_receipts})
		_pending.clear()
		_pending_ids.clear()
		var result: Dictionary = _outcome(true, true, duplicate, before)
		result["changed_words"] = changed_words
		return result
	return _outcome(true, false, false, before)


func streak(id: String) -> int:
	return int(_streaks.get(id, 0))


func is_mastered(id: String) -> bool:
	return _word_ages.has(id) and streak(id) == MASTERY_STREAK


func snapshot() -> Dictionary:
	var total: int = 0
	var mastered: int = 0
	var steps: int = 0
	for id: String in _cohorts.get(level, []):
		total += 1
		steps += streak(id)
		if is_mastered(id):
			mastered += 1
	var total_mastered: int = 0
	for id in _word_ages:
		if is_mastered(id):
			total_mastered += 1
	return {"level": level, "label": "Lv12+" if level == LAST_LEVEL else "Lv%d" % level,
		"completed": completed, "mastered": mastered, "total": total,
		"progress": float(mastered) / float(total) if total > 0 else 0.0,
		"practice_progress": float(steps) / float(total * MASTERY_STREAK) if total > 0 else 0.0,
		"total_mastered": total_mastered, "total_words": _word_ages.size(),
		"streaks": _streaks.duplicate(), "threshold": MASTERY_STREAK,
		"ready": ready, "save_ok": ready and _pending.is_empty(),
		"pending_count": _pending.size(), "error": error}


func _cohort_mastered(age: int, values: Dictionary) -> bool:
	var words: Array = _cohorts.get(age, [])
	if words.is_empty():
		return false
	for id in words:
		if int(values.get(id, 0)) < MASTERY_STREAK:
			return false
	return true


func _outcome(accepted: bool, save_ok: bool, duplicate: bool, before: int, message: String = "") -> Dictionary:
	if not message.is_empty():
		error = message
	return {"accepted": accepted, "save_ok": save_ok, "duplicate": duplicate,
		"leveled_up": level > before, "previous_level": before, "level": level,
		"completed": completed, "pending_count": _pending.size(), "error": error}


func _persist(next_level: int, next_streaks: Dictionary, next_receipts: Array[String], expected_text: Variant = null) -> bool:
	var config := ConfigFile.new()
	config.set_value("growth", "version", VERSION)
	config.set_value("growth", "level", next_level)
	config.set_value("growth", "streaks", next_streaks)
	config.set_value("growth", "receipts", next_receipts)
	if _host != null:
		if _host.saveGrowthState(config.encode_to_text(), expected_text) == true:
			return true
		return _fail("Your learning progress has not saved yet. Please retry saving.")
	if OS.has_feature("web"):
		return _fail("Learning progress storage is unavailable. Please retry saving.")
	if config.save(_path + ".pending") != OK:
		return _fail("Your learning progress has not saved yet. Please retry saving.")
	if FileAccess.file_exists(_path + ".previous") and DirAccess.remove_absolute(_path + ".previous") != OK:
		return _fail("Could not preserve your learning progress. Please retry saving.")
	var had_previous: bool = FileAccess.file_exists(_path)
	if had_previous and DirAccess.rename_absolute(_path, _path + ".previous") != OK:
		return _fail("Could not preserve your learning progress. Please retry saving.")
	if DirAccess.rename_absolute(_path + ".pending", _path) != OK:
		if had_previous:
			DirAccess.rename_absolute(_path + ".previous", _path)
		return _fail("Your learning progress has not saved yet. Please retry saving.")
	if had_previous:
		DirAccess.remove_absolute(_path + ".previous")
	return true


func _restore_previous() -> bool:
	if not FileAccess.file_exists(_path) and FileAccess.file_exists(_path + ".previous"):
		if DirAccess.rename_absolute(_path + ".previous", _path) != OK:
			return _fail("Could not restore your learning progress. Please retry.")
	return true


func _whole_number(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum


func _valid_event_id(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= MAX_EVENT_LENGTH


func _fail(message: String) -> bool:
	error = message
	return false


func _invalid_save(message: String) -> Dictionary:
	_fail(message)
	return {}
