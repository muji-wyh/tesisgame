extends RefCounted
## Durable word mastery, earned experience levels and independent Pip ages.

const VERSION: int = 2
const FIRST_LEVEL: int = 0
const LAST_LEVEL: int = 99
const FIRST_AGE: int = 3
const LAST_AGE: int = 12
const MASTERY_STREAK: int = 6
const MAX_RECEIPTS: int = 4096
const MAX_EVENT_LENGTH: int = 256
const MAX_SAVE_ATTEMPTS: int = 3
# The cost of reaching each level from Lv1 through Lv99. The fixed curve
# fits the 1,550-word curriculum; adding vocabulary never moves earned goals.
const LEVEL_COSTS: Array[int] = [
	1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 4, 5,
	5, 5, 6, 6, 6, 6, 7, 7, 7, 7, 8, 8,
	8, 9, 9, 9, 10, 10, 10, 10, 11, 11, 11, 12,
	12, 12, 12, 13, 13, 13, 14, 14, 14, 15, 15, 15,
	15, 16, 16, 16, 17, 17, 17, 17, 18, 18, 18, 18,
	19, 19, 19, 20, 20, 20, 21, 21, 21, 22, 22, 22,
	22, 23, 23, 23, 24, 24, 24, 24, 24, 25, 25, 26,
	26, 26, 26, 27, 27, 27, 27, 28, 28, 28, 29, 29,
	29, 30, 30,
]
static var _id_sequence: int = 0

var level: int = FIRST_LEVEL
var age: int = 0
var completed: bool = false
var ready: bool = false
var error: String = ""

var _path: String
var _host: Object
var _word_ages: Dictionary = {}
var _cohorts: Dictionary = {}
var _streaks: Dictionary = {}
var _mastered_words: Dictionary = {}
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


static func level_cost(target_level: int) -> int:
	return LEVEL_COSTS[target_level - 1] if target_level > FIRST_LEVEL and target_level <= LAST_LEVEL else 0


static func level_threshold(target_level: int) -> int:
	var count: int = 0
	for index in range(clampi(target_level, FIRST_LEVEL, LAST_LEVEL)):
		count += LEVEL_COSTS[index]
	return count


static func level_for_mastered(count: int) -> int:
	var threshold: int = 0
	for index in range(LAST_LEVEL):
		threshold += LEVEL_COSTS[index]
		if count < threshold:
			return index
	return LAST_LEVEL


func _init(path: String = "user://growth-v1.cfg", host: Object = null) -> void:
	# Retain the original storage location so existing learners migrate in place.
	_path = path
	_host = host
	if _host == null and OS.has_feature("web"):
		_host = JavaScriptBridge.get_interface("wordBuddiesHost")


func configure(words: Array) -> bool:
	if not _pending.is_empty():
		return _fail("Save your pending learning progress before changing the vocabulary.")
	var ages: Dictionary = {}
	var cohorts: Dictionary = {}
	for cohort in range(FIRST_AGE, LAST_AGE + 1):
		cohorts[cohort] = []
	for word in words:
		if not word is Dictionary or not word.get("id") is String or String(word.id).strip_edges().is_empty() \
			or not _whole_number(word.get("min_age"), FIRST_AGE, LAST_AGE) or ages.has(word.id):
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
	for attempt in range(MAX_SAVE_ATTEMPTS):
		var saved: Dictionary = _read_state()
		if saved.is_empty():
			return false
		if saved.get("migrated", false) and not _persist(saved.level, saved.age, saved.streaks,
			saved.mastered_words, saved.receipts, saved.text):
			continue
		_use_saved(saved)
		ready = true
		return true
	return false


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
	var next: Dictionary = {"level": FIRST_LEVEL, "age": 0, "streaks": {}, "mastered_words": {},
		"receipts": [], "text": saved_text, "migrated": false}
	if missing:
		return next
	for key in ["version", "level", "streaks", "receipts"]:
		if not config.has_section_key("growth", key):
			return _invalid_save("Your learning progress save is incomplete.")
	var version: Variant = config.get_value("growth", "version")
	if not _whole_number(version, 1, VERSION):
		return _invalid_save("This learning progress save needs a supported version.")
	var legacy: bool = int(version) == 1
	var saved_level: Variant = config.get_value("growth", "level")
	var saved_streaks: Variant = config.get_value("growth", "streaks")
	var saved_receipts: Variant = config.get_value("growth", "receipts")
	if not _whole_number(saved_level, FIRST_AGE if legacy else FIRST_LEVEL, LAST_AGE if legacy else LAST_LEVEL) \
		or not saved_streaks is Dictionary or not saved_receipts is Array or saved_receipts.size() > MAX_RECEIPTS:
		return _invalid_save("Your learning progress could not be understood.")
	if legacy:
		next.age = 0 if int(saved_level) == FIRST_AGE else int(saved_level) - 1
		next.migrated = true
	else:
		for key in ["age", "mastered_words"]:
			if not config.has_section_key("growth", key):
				return _invalid_save("Your learning progress save is incomplete.")
		var saved_age: Variant = config.get_value("growth", "age")
		if not _valid_age(saved_age):
			return _invalid_save("Your learning progress contains an invalid Pip age.")
		next.age = int(saved_age)
	var eligible_age: int = _learning_age_for(next.age)
	for id in saved_streaks:
		if not id is String or not _word_ages.has(id) \
			or not _whole_number(saved_streaks[id], 0, MASTERY_STREAK) \
			or (int(_word_ages[id]) > eligible_age and int(saved_streaks[id]) > 0):
			return _invalid_save("Your learning progress contains an invalid word streak.")
		if int(saved_streaks[id]) > 0:
			next.streaks[id] = int(saved_streaks[id])
	if legacy:
		# Old levels marked the cohort being learned, so preceding cohorts were
		# earned even if a later mistake has already reset one of their streaks.
		for id in _word_ages:
			if int(_word_ages[id]) < int(saved_level) or int(next.streaks.get(id, 0)) == MASTERY_STREAK:
				next.mastered_words[id] = true
		next.age = _advance_age(next.age, next.streaks)
	else:
		var saved_mastered: Variant = config.get_value("growth", "mastered_words")
		if not saved_mastered is Array or saved_mastered.size() > _word_ages.size():
			return _invalid_save("Your learning progress contains an invalid mastery history.")
		for id in saved_mastered:
			if not id is String or not _word_ages.has(id) or next.mastered_words.has(id) or int(_word_ages[id]) > eligible_age:
				return _invalid_save("Your learning progress contains an invalid mastery history.")
			next.mastered_words[id] = true
		for id in next.streaks:
			if int(next.streaks[id]) == MASTERY_STREAK and not next.mastered_words.has(id):
				return _invalid_save("Your learning progress is missing a mastered word.")
	next.level = level_for_mastered(next.mastered_words.size())
	if not legacy and int(saved_level) != int(next.level):
		return _invalid_save("Your learning level does not match its saved mastery history.")
	var receipt_ids: Dictionary = {}
	for receipt in saved_receipts:
		if not _valid_event_id(receipt) or receipt_ids.has(receipt):
			return _invalid_save("Your learning progress contains an invalid answer receipt.")
		next.receipts.append(receipt)
		receipt_ids[receipt] = true
	return next


func _use_saved(saved: Dictionary) -> void:
	level = int(saved.level)
	age = int(saved.age)
	_streaks = saved.streaks
	_mastered_words = saved.mastered_words
	_receipts.assign(saved.receipts)
	_receipt_set.clear()
	for receipt in _receipts:
		_receipt_set[receipt] = true
	completed = age == LAST_AGE
	error = ""


func learning_age() -> int:
	return _learning_age_for(age)


func _learning_age_for(earned_age: int) -> int:
	return FIRST_AGE if earned_age == 0 else mini(earned_age + 1, LAST_AGE)


func record_attempt(event_id: String, word_ids: Array, correct: bool) -> Dictionary:
	if not ready:
		return _outcome(false, false, false, level, age, "Load learning progress successfully before recording an answer.")
	if not _valid_event_id(event_id) or word_ids.is_empty():
		return _outcome(false, false, false, level, age, "An answer needs a valid event ID and at least one word.")
	if _receipt_set.has(event_id) or _pending_ids.has(event_id):
		var duplicate: Dictionary = retry_pending()
		duplicate["duplicate"] = true
		duplicate["ignored"] = true
		return duplicate
	var eligible: Array[String] = []
	for id in word_ids:
		if not id is String or not _word_ages.has(id):
			return _outcome(false, false, false, level, age, "An answer contains an unknown learning word.")
		# Capture eligibility now. A delayed save cannot credit a future cohort
		# after an earlier queued answer has made Pip old enough to learn it.
		if int(_word_ages[id]) <= learning_age() and not eligible.has(id):
			eligible.append(id)
	_pending.append({"id": event_id, "words": eligible, "correct": correct})
	_pending_ids[event_id] = true
	var result: Dictionary = retry_pending()
	result["accepted"] = true
	result["ignored"] = eligible.is_empty()
	return result


func retry_pending() -> Dictionary:
	var before: int = level
	var before_age: int = age
	if not ready:
		return _outcome(false, false, false, before, before_age, "Load learning progress successfully before retrying an answer.")
	if _pending.is_empty() and _host == null:
		error = ""
		return _outcome(true, true, false, before, before_age)
	var previous_expected: Variant = null
	for attempt in range(MAX_SAVE_ATTEMPTS):
		# Rebase on the current shared streaks; maximum-merging would erase real
		# mistakes. Only permanently earned ages and unique word history unite.
		var saved: Dictionary = _read_state() if _host != null else {
			"level": level, "age": age, "streaks": _streaks, "mastered_words": _mastered_words,
			"receipts": _receipts, "text": null}
		if saved.is_empty():
			return _outcome(true, false, false, before, before_age)
		if attempt > 0 and saved.text == previous_expected:
			return _outcome(true, false, false, before, before_age)
		var next_streaks: Dictionary = saved.streaks.duplicate()
		var next_mastered: Dictionary = saved.mastered_words.duplicate()
		for id in _mastered_words:
			next_mastered[id] = true
		var next_receipts: Array[String] = []
		next_receipts.assign(saved.receipts)
		var seen: Dictionary = {}
		for receipt in next_receipts:
			seen[receipt] = true
		var next_age: int = maxi(age, int(saved.age))
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
				if value == MASTERY_STREAK:
					next_mastered[id] = true
				if value != previous and not changed_words.has(id):
					changed_words.append(id)
			next_age = _advance_age(next_age, next_streaks)
			next_receipts.append(event.id)
			seen[event.id] = true
			if next_receipts.size() > MAX_RECEIPTS:
				next_receipts.pop_front()
		var next_level: int = level_for_mastered(next_mastered.size())
		var duplicate: bool = not _pending.is_empty() and new_events == 0
		if new_events > 0 or next_age != int(saved.age) or next_mastered.size() != saved.mastered_words.size() or saved.get("migrated", false):
			if not _persist(next_level, next_age, next_streaks, next_mastered, next_receipts, saved.text):
				previous_expected = saved.text
				continue
		_use_saved({"level": next_level, "age": next_age, "streaks": next_streaks,
			"mastered_words": next_mastered, "receipts": next_receipts})
		_pending.clear()
		_pending_ids.clear()
		var result: Dictionary = _outcome(true, true, duplicate, before, before_age)
		result["changed_words"] = changed_words
		return result
	return _outcome(true, false, false, before, before_age)


func streak(id: String) -> int:
	return int(_streaks.get(id, 0))


func is_mastered(id: String) -> bool:
	return _word_ages.has(id) and streak(id) == MASTERY_STREAK


func snapshot() -> Dictionary:
	var total: int = 0
	var mastered: int = 0
	var steps: int = 0
	for id: String in _cohorts.get(learning_age(), []):
		total += 1
		steps += streak(id)
		if is_mastered(id):
			mastered += 1
	var total_mastered: int = 0
	for id in _word_ages:
		if is_mastered(id):
			total_mastered += 1
	var max_level: bool = level == LAST_LEVEL
	var requirement: int = level_cost(level + 1)
	var level_mastered: int = 0 if max_level else _mastered_words.size() - level_threshold(level)
	return {"level": level, "label": "Lv%d" % level,
		"age": age, "age_label": "Baby" if age == 0 else ("Age 12+" if age == LAST_AGE else "Age %d" % age),
		"learning_age": learning_age(), "completed": completed,
		"mastered": mastered, "total": total,
		"progress": float(mastered) / float(total) if total > 0 else 0.0,
		"practice_progress": float(steps) / float(total * MASTERY_STREAK) if total > 0 else 0.0,
		"total_mastered": total_mastered, "lifetime_mastered": _mastered_words.size(),
		"level_progress": 1.0 if max_level else float(level_mastered) / float(requirement),
		"level_mastered": level_mastered, "level_required": requirement,
		"level_remaining": maxi(0, requirement - level_mastered), "level_completed": max_level,
		"total_words": _word_ages.size(), "streaks": _streaks.duplicate(), "threshold": MASTERY_STREAK,
		"ready": ready, "save_ok": ready and _pending.is_empty(),
		"pending_count": _pending.size(), "error": error}


func _advance_age(earned_age: int, values: Dictionary) -> int:
	var next_age: int = earned_age
	while next_age < LAST_AGE and _cohort_mastered(_learning_age_for(next_age), values):
		next_age = _learning_age_for(next_age)
	return next_age


func _cohort_mastered(cohort: int, values: Dictionary) -> bool:
	var words: Array = _cohorts.get(cohort, [])
	if words.is_empty():
		return false
	for id in words:
		if int(values.get(id, 0)) < MASTERY_STREAK:
			return false
	return true


func _outcome(accepted: bool, save_ok: bool, duplicate: bool, before: int, before_age: int, message: String = "") -> Dictionary:
	if not message.is_empty():
		error = message
	return {"accepted": accepted, "save_ok": save_ok, "duplicate": duplicate,
		"leveled_up": level > before, "previous_level": before, "level": level,
		"aged_up": age > before_age, "previous_age": before_age, "age": age,
		"completed": completed, "pending_count": _pending.size(), "error": error}


func _valid_age(value: Variant) -> bool:
	return _whole_number(value, 0, 0) or _whole_number(value, FIRST_AGE, LAST_AGE)


func _persist(next_level: int, next_age: int, next_streaks: Dictionary, next_mastered: Dictionary,
	next_receipts: Array, expected_text: Variant = null) -> bool:
	var mastered_ids: Array = next_mastered.keys()
	mastered_ids.sort()
	var config := ConfigFile.new()
	config.set_value("growth", "version", VERSION)
	config.set_value("growth", "level", next_level)
	config.set_value("growth", "age", next_age)
	config.set_value("growth", "streaks", next_streaks)
	config.set_value("growth", "mastered_words", mastered_ids)
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
