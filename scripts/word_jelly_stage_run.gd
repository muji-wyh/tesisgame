extends RefCounted
## Active-play attempt state. The caller owns commits, pauses and timer-boundary ordering.

const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
const MAX_RECEIPTS: int = 16384
const MAX_TIME_RECEIPTS: int = 4096
const MAX_ID_LENGTH: int = 512
const MAX_ADDED_SECONDS: int = 86400
const MAX_ELAPSED: float = 1000000000.0
const OUTCOMES: Array[String] = ["cleared", "timeout", "blocked", "exit"]

var error: String = ""
var kind: String = ""
var number: int = 0
var words: Array[Dictionary] = []
var goals: Dictionary = {}
var current: Dictionary = {}
var initial_seconds: float = 0.0
var elapsed: float = 0.0
var remaining: float = 0.0
var outcome: String = ""
var collection_count: int = 0
var boss_objective: bool = false
var boss_defeated: bool = false
var _configured: bool = false
var _chapter: int = 1
var _title: String = ""
var _profile: String = ""
var _added_seconds: int = 0
var _final_stars: int = 0
var _collection_receipts: Dictionary = {}
var _time_receipts: Dictionary = {}


func configure(plan: Dictionary) -> bool:
	_reset()
	var recipe: Dictionary = Catalog.to_recipe(plan)
	if recipe.has("error"):
		return _fail(str(recipe.error))
	kind = str(recipe.kind)
	number = int(recipe.number)
	_chapter = int(recipe.chapter)
	_title = str(recipe.title)
	_profile = str(recipe.profile)
	words.assign(plan.words.duplicate(true))
	goals = recipe.goals.duplicate(true)
	for id: String in goals:
		current[id] = 0
	initial_seconds = float(recipe.seconds)
	remaining = initial_seconds
	_configured = true
	return true


func record_collection(event_id: String, word_id: String) -> bool:
	error = ""
	if not _active():
		return false
	if not _valid_id(event_id) or not _valid_id(word_id):
		return _fail("A committed collection needs valid receipt and word identities.")
	if _collection_receipts.has(event_id):
		if _collection_receipts[event_id] != word_id:
			return _fail("This collection receipt already belongs to a different word.")
		return false
	if _collection_receipts.size() >= MAX_RECEIPTS:
		return _fail("This attempt's collection receipt limit has been reached. End the attempt before collecting more.")
	_collection_receipts[event_id] = word_id
	collection_count += 1
	if kind == "main" and goals.has(word_id):
		current[word_id] = mini(int(goals[word_id]), int(current[word_id]) + 1)
		if _goals_met() and not boss_objective:
			decide("cleared")
	return true


func advance(delta: float) -> void:
	error = ""
	if not _configured:
		_fail("Configure an attempt before advancing its active-play timer.")
		return
	if not is_finite(delta) or delta < 0.0 or delta > MAX_ELAPSED - elapsed:
		_fail("Active-play time must be finite, nonnegative and within the supported duration.")
		return
	if not outcome.is_empty():
		return
	elapsed += delta
	if kind == "main":
		remaining = maxf(0.0, initial_seconds + float(_added_seconds) - elapsed)


func check_deadline() -> bool:
	error = ""
	if not _configured:
		return _fail("Configure an attempt before checking its deadline.")
	if not outcome.is_empty() or kind != "main" or remaining > 0.0:
		return false
	return decide("timeout")


func decide(reason: String) -> bool:
	error = ""
	if reason not in OUTCOMES:
		return _fail("Choose a supported attempt outcome.")
	if not _active():
		return false
	if reason == "cleared" and (kind != "main" or (not boss_defeated if boss_objective else not _goals_met())):
		return _fail("Every main-stage collection goal must be committed before clearing the attempt.")
	if reason == "timeout" and kind != "main":
		return _fail("An untimed challenge has no timeout outcome.")
	_final_stars = stars_now() if reason == "cleared" else 0
	outcome = reason
	return true


func can_add_time(seconds: int = 30) -> bool:
	return _configured and kind == "main" and outcome.is_empty() and seconds > 0 \
		and seconds <= MAX_ADDED_SECONDS and _time_receipts.size() < MAX_TIME_RECEIPTS \
		and _added_seconds <= MAX_ADDED_SECONDS - seconds


func add_time(receipt_id: String, seconds: int = 30) -> bool:
	error = ""
	if not _active():
		return false
	if kind != "main":
		return _fail("An untimed challenge cannot use an extra-time purchase.")
	if not _valid_id(receipt_id) or seconds <= 0 or seconds > MAX_ADDED_SECONDS:
		return _fail("An extra-time purchase needs a valid receipt and a positive bounded duration.")
	if _time_receipts.has(receipt_id):
		if int(_time_receipts[receipt_id]) != seconds:
			return _fail("This saved time purchase has a different duration.")
		return false
	if not can_add_time(seconds):
		return _fail("This attempt has reached its supported extra-time limit.")
	_time_receipts[receipt_id] = seconds
	_added_seconds += seconds
	remaining = maxf(0.0, initial_seconds + float(_added_seconds) - elapsed)
	return true


func stars_now() -> int:
	if not _configured or kind != "main":
		return 0
	if not outcome.is_empty():
		return _final_stars if outcome == "cleared" else 0
	if elapsed < initial_seconds / 3.0:
		return 3
	if elapsed < initial_seconds * 2.0 / 3.0:
		return 2
	return 1


func challenge_pressure() -> Dictionary:
	if not _configured or kind != "challenge":
		return {}
	@warning_ignore("integer_division")
	var level: int = 1 + collection_count / 10
	return {"level": level, "word_limit": mini(3 + level - 1, Catalog.MAX_CHALLENGE_WORDS),
		"spawn_interval": maxf(3.0, 20.0 * pow(0.93, level - 1)),
		"fall_speed_scale": minf(2.2, 1.0 + 0.04 * float(level - 1))}


func words_for_pressure() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _configured or kind != "challenge":
		return result
	var count: int = mini(words.size(), int(challenge_pressure().word_limit))
	for index in range(count):
		result.append(words[index].duplicate(true))
	return result


func snapshot() -> Dictionary:
	var practice: Array[Dictionary] = []
	var ids: Array[String] = []
	var remaining_ids: Array[String] = []
	var mastered: int = 0
	for word: Dictionary in words:
		var id: String = str(word.id)
		ids.append(id)
		if kind != "main":
			continue
		var complete: bool = int(current[id]) >= int(goals[id])
		if complete:
			mastered += 1
		else:
			remaining_ids.append(id)
		practice.append({"id": id, "text": str(word.text), "image": str(word.get("image", "")),
			"current": int(current[id]), "required": int(goals[id]), "mastered": complete})
	return {"kind": kind, "number": number, "chapter": _chapter, "title": _title,
		"profile": _profile, "outcome": outcome, "stars_now": stars_now(),
		"stars": _final_stars if outcome == "cleared" else 0, "time_elapsed": elapsed,
		"seconds_remaining": remaining, "seconds_total": initial_seconds, "seconds_added": _added_seconds,
		"goals": goals.duplicate(true), "current": current.duplicate(true), "practice": practice,
		"word_ids": ids, "remaining_ids": remaining_ids, "total": goals.size(), "mastered": mastered,
		"remaining": remaining_ids.size(), "complete": outcome == "cleared",
		"collection_count": collection_count, "pressure": challenge_pressure(),
		"objective": "boss" if boss_objective else "words", "boss_defeated": boss_defeated}


func _reset() -> void:
	error = ""
	_configured = false
	kind = ""
	number = 0
	words.clear()
	goals.clear()
	current.clear()
	initial_seconds = 0.0
	elapsed = 0.0
	remaining = 0.0
	outcome = ""
	collection_count = 0
	boss_objective = false
	boss_defeated = false
	_chapter = 1
	_title = ""
	_profile = ""
	_added_seconds = 0
	_final_stars = 0
	_collection_receipts.clear()
	_time_receipts.clear()


func _active() -> bool:
	if not _configured:
		return _fail("Configure an attempt before recording play.")
	if not outcome.is_empty():
		return _fail("This attempt already ended; its outcome cannot change.")
	return true


func _goals_met() -> bool:
	if goals.is_empty():
		return false
	for id: String in goals:
		if int(current[id]) < int(goals[id]):
			return false
	return true


func _valid_id(value: String) -> bool:
	if value.is_empty() or value.length() > MAX_ID_LENGTH or value.strip_edges() != value:
		return false
	for index in range(value.length()):
		if value.unicode_at(index) < 32 or value.unicode_at(index) == 127:
			return false
	return true


func _fail(message: String) -> bool:
	error = message
	return false
