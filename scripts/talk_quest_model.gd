extends RefCounted

signal changed

const Data = preload("res://scripts/talk_quest_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const SpeechWords = preload("res://scripts/speech_words.gd")
const SAVE_VERSION: int = 2
const DAMAGE_PER_WORD: int = 1
const MAX_TARGETS: int = 3
const WORD_LIFETIME: float = 10.0
const MAX_TEXT_LENGTH: int = 512
const MAX_EVENT_ID_LENGTH: int = 160
const MAX_FINAL_EVENTS: int = 16384
const MAX_LEVEL_CLEARS: int = 100000
const EPSILON: float = 0.000001
const ACTIVE_PHASES: Array[String] = ["playing", "victory", "chest"]

var phase: String = "ready"
var level_number: int = 1
var level: Dictionary = {}
var hp: int = 0
var max_hp: int = 0
var total_words: int = 0
var spawned: int = 0
var hits: int = 0
var misses: int = 0
var elapsed: float = 0.0
var targets: Array[Dictionary] = []
var round_id: String = ""
var last_transcript: String = ""
var feedback: String = ""
var completed_levels: Array[int] = []
var unlocked_level: int = 1
var collected_chests: Array[String] = []
var total_clears: int = 0
var companion_unlocked: bool = false
# Kept for older presentation diagnostics; sentences no longer drive combat.
var line_index: int = 0
var repaired_toys: Array[String] = []
var selected_parts: Array[String] = []

var _level_clears: Array[int] = []
var _paused_phase: String = "playing"
var _consumed_speech_events: Dictionary = {}
var _round_serial: int = 0
var _manual_serial: int = 0
var _run_serial: int = 0
var _run_id: String = ""
var _run_clear_number: int = 0
var _chest_id: String = ""
var _reward_claimed: bool = false
var _rng := RandomNumberGenerator.new()
var _aliases: Dictionary = {}
var _spawn_counts: Dictionary = {}
var _next_spawn_at: float = 0.0


func _init() -> void:
	_level_clears.resize(Data.LEVEL_COUNT)
	_level_clears.fill(0)
	_rng.randomize()
	_set_level(1)
	_new_round()


func start_level(number: int, seed_value: int = -1) -> bool:
	if not is_unlocked(number) or _level_clears[number - 1] >= MAX_LEVEL_CLEARS:
		return false
	_clear_active_run()
	_set_level(number)
	if level.words.is_empty():
		return false
	if seed_value >= 0:
		_rng.seed = seed_value
	_run_serial += 1
	_run_id = "tq-run-%d-%d-%d" % [get_instance_id(), Time.get_ticks_usec(), _run_serial]
	_run_clear_number = _level_clears[number - 1] + 1
	_chest_id = _select_chest(number)
	phase = "playing"
	_spawn()
	_next_spawn_at = _spawn_interval()
	changed.emit()
	return true


func advance(delta: float) -> void:
	if phase != "playing" or not is_finite(delta) or delta <= 0.0:
		return
	var end_time: float = elapsed + delta
	var previous_spawned: int = spawned
	var previous_misses: int = misses
	# Resolve launches and landings at their event time, including slow frames.
	# A large delta cannot skip misses, exceed the word budget, or extend a flight.
	while phase == "playing" and elapsed < end_time:
		var event_time: float = minf(end_time, _next_spawn_at)
		for target in targets:
			event_time = minf(event_time, elapsed + maxf(0.0, target.lifetime - target.age))
		var step: float = maxf(0.0, event_time - elapsed)
		for target in targets:
			target.age = minf(target.lifetime, target.age + step)
		elapsed = event_time
		_expire_targets()
		if phase != "playing":
			break
		if _next_spawn_at <= elapsed + EPSILON:
			_spawn()
			_next_spawn_at = elapsed + _spawn_interval() if spawned < total_words else INF
	if spawned != previous_spawned or misses != previous_misses:
		changed.emit()


func is_unlocked(number: int) -> bool:
	return number >= 1 and number <= Data.LEVEL_COUNT and number <= unlocked_level


func clear_count(number: int) -> int:
	return _level_clears[number - 1] if number >= 1 and number <= Data.LEVEL_COUNT else 0


func is_cooperative() -> bool:
	return false


func progress_ratio() -> float:
	return float(hits) / float(max_hp) if max_hp > 0 else 0.0


func current_prompt() -> Dictionary:
	if phase not in ["playing", "paused"] or targets.is_empty():
		return {}
	var target: Dictionary = targets[0]
	return {
		"uid": target.uid, "id": target.word.id, "text": target.word.text,
		"speaker": "", "index": hits, "line_number": hits + 1, "total_lines": max_hp
	}


func speech_target() -> Dictionary:
	return {"round_id": round_id, "target_uid": targets[0].uid if phase == "playing" and not targets.is_empty() else 0}


func speech_targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if phase == "playing":
		for target in targets:
			result.append({
				"uid": target.uid, "text": target.word.text, "forms": target.forms.duplicate(),
				"remaining_ms": maxf(0.0, (target.lifetime - target.age) * 1000.0)
			})
	return result


func vocabulary() -> Array[String]:
	var result: Array[String] = []
	for word: Dictionary in level.words:
		result.append(word.text)
	return result


func current_chest() -> Dictionary:
	return Data.chest(_chest_id) if not _chest_id.is_empty() else {}


func current_part_choices() -> Array[Dictionary]:
	return []


func has_correct_part() -> bool:
	return true


func choose_part(_id: String) -> Dictionary:
	var result: Dictionary = _result("not_choosing")
	result.correct = false
	return result


func submit_transcript(text: String) -> Dictionary:
	# Native tests and accessibility integrations share the same bound validator.
	# Browser speech must retain the original occurrence and target binding.
	_manual_serial += 1
	var event: Dictionary = speech_target()
	event.merge({"event_id": "practice-%d-%d" % [get_instance_id(), _manual_serial], "text": text, "stage": "final"})
	var result: Dictionary = submit_speech_event(event)
	result.input = "practice"
	return result


func submit_speech_event(event: Dictionary) -> Dictionary:
	if phase != "playing":
		return _result("not_playing")
	if not event.has_all(["event_id", "round_id", "target_uid", "text", "stage"]):
		return _result("missing_binding")
	if not event.event_id is String or event.event_id.strip_edges().is_empty() \
		or event.event_id.length() > MAX_EVENT_ID_LENGTH or not event.round_id is String \
		or not event.text is String or event.text.length() > MAX_TEXT_LENGTH \
		or not event.stage is String or event.stage not in ["interim", "final"]:
		return _result("invalid_metadata")
	if event.round_id != round_id:
		return _result("stale_round")
	if _consumed_speech_events.has(event.event_id):
		return _result("duplicate_event")
	if not _is_bounded_integer(event.target_uid, 1, total_words):
		return _result("invalid_target")
	if event.has("received_at_ms") and not _is_nonnegative_number(event.received_at_ms):
		return _result("invalid_timestamp")
	if _consumed_speech_events.size() >= MAX_FINAL_EVENTS:
		return _result("session_limit")
	var target: Dictionary = {}
	for active in targets:
		if active.uid == int(event.target_uid) and active.age + EPSILON < active.lifetime:
			target = active
			break
	if target.is_empty():
		return _result("stale_target")
	last_transcript = event.text.strip_edges()
	var tokens: Array[String] = SpeechWords.tokens(last_transcript, target.forms)
	var matches: bool = tokens.size() == 1 and target.forms.has(tokens[0])
	if event.stage == "final" or matches:
		_consumed_speech_events[event.event_id] = true
	if not matches:
		feedback = ""
		changed.emit()
		return _result("interim" if event.stage == "interim" else "word_mismatch", true)
	var hit: Dictionary = target.duplicate(true)
	targets.erase(target)
	hits += 1
	line_index = hits
	hp = maxi(0, max_hp - hits)
	feedback = ""
	if hp == 0:
		phase = "victory"
		targets.clear()
	elif targets.is_empty() and spawned < total_words:
		_next_spawn_at = minf(_next_spawn_at, elapsed + 0.45)
	var result: Dictionary = _result("matched", true)
	result.merge({
		"matched": true, "completed": phase == "victory", "damage": DAMAGE_PER_WORD,
		"target": hit, "word": hit.word, "target_uid": hit.uid,
		"prompt": {"uid": hit.uid, "id": hit.word.id, "text": hit.word.text, "speaker": ""}
	}, true)
	changed.emit()
	return result


func pause() -> Dictionary:
	if phase not in ACTIVE_PHASES:
		return _result("not_active")
	_paused_phase = phase
	phase = "paused"
	_clear_recognition()
	_new_round()
	changed.emit()
	return _result("paused", true)


func resume() -> Dictionary:
	if phase != "paused":
		return _result("not_paused")
	phase = _paused_phase
	_clear_recognition()
	_new_round()
	changed.emit()
	return _result("resumed", true)


func is_paused() -> bool:
	return phase == "paused"


func stop() -> void:
	_clear_active_run()
	phase = "ready"
	changed.emit()


func finish_victory() -> Dictionary:
	if phase != "victory":
		return _result("not_victory")
	phase = "chest"
	changed.emit()
	return _result("chest_ready", true)


func open_chest() -> Dictionary:
	if _reward_claimed or phase == "complete":
		return _result("already_rewarded")
	if phase != "chest" or hp != 0 or hits != max_hp:
		return _result("chest_not_ready")
	if _run_clear_number != _level_clears[level_number - 1] + 1:
		return _result("invalid_reward")
	var first_clear: bool = _level_clears[level_number - 1] == 0
	var new_chest: bool = not collected_chests.has(_chest_id)
	var previous_unlock: int = unlocked_level
	_level_clears[level_number - 1] += 1
	_reward_claimed = true
	phase = "complete"
	_rebuild_progress()
	var result: Dictionary = _result("rewarded", true)
	result.merge({
		"completed": true, "reward_id": _chest_id, "chest": current_chest(),
		"first_clear": first_clear, "new_chest": new_chest,
		"new_unlock": unlocked_level if unlocked_level > previous_unlock else 0,
		"companion_unlocked": companion_unlocked
	}, true)
	changed.emit()
	return result


func has_saved_run() -> bool:
	return not _reward_claimed and _run_clear_number > 0 and (phase in ACTIVE_PHASES or phase == "paused")


func export_progress() -> Dictionary:
	var result: Dictionary = {"version": SAVE_VERSION, "completion_counts": _level_clears.duplicate(), "run": {}}
	if has_saved_run():
		var saved_targets: Array[Dictionary] = []
		for target in targets:
			var saved: Dictionary = target.duplicate(true)
			saved.word_id = target.word.id
			saved.erase("word")
			saved.erase("forms")
			saved_targets.append(saved)
		result.run = {
			"level_number": level_number, "hits": hits, "misses": misses, "spawned": spawned,
			"elapsed": elapsed, "next_spawn_in": maxf(0.0, _next_spawn_at - elapsed) if spawned < total_words else 0.0,
			"targets": saved_targets, "phase": _paused_phase if phase == "paused" else phase,
			"clear_number": _run_clear_number, "run_id": _run_id
		}
	return result


func import_progress(progress: Variant) -> bool:
	if not progress is Dictionary or not _is_bounded_integer(progress.get("version"), 1, SAVE_VERSION) \
		or not progress.get("completion_counts") is Array:
		return false
	var counts: Array = progress.completion_counts
	var found_gap: bool = false
	for index in range(Data.LEVEL_COUNT):
		var count: int = _clamped_count(counts[index]) if index < counts.size() else 0
		if found_gap:
			count = 0
		if count == 0:
			found_gap = true
		_level_clears[index] = count
	_rebuild_progress()
	_clear_active_run()
	_set_level(1)
	phase = "ready"
	if progress.get("run") is Dictionary:
		if progress.version == 1:
			_restore_legacy_reward(progress.run)
		else:
			_restore_run(progress.run)
	changed.emit()
	return true


func _set_level(number: int) -> void:
	level_number = number
	level = Data.level(number)
	max_hp = level.hp
	hp = max_hp
	total_words = level.word_budget
	line_index = 0
	hits = 0
	misses = 0
	spawned = 0
	elapsed = 0.0
	targets.clear()
	_spawn_counts.clear()
	_aliases.clear()
	_next_spawn_at = 0.0
	for word: Dictionary in level.words:
		_aliases[word.id] = SpeechWords.forms(word.text, true)


func _spawn_interval() -> float:
	return lerpf(2.15, 1.70, float(level_number - 1) / float(Data.LEVEL_COUNT - 1))


func _spawn() -> void:
	if spawned >= total_words or targets.size() >= MAX_TARGETS:
		return
	var candidates: Array[Dictionary] = []
	var fewest: int = 2147483647
	for word: Dictionary in level.words:
		if not _can_spawn(word):
			continue
		var count: int = _spawn_counts.get(word.id, 0)
		if count < fewest:
			fewest = count
			candidates.clear()
		if count == fewest:
			candidates.append(word)
	if candidates.is_empty():
		return
	var word: Dictionary = candidates[_rng.randi_range(0, candidates.size() - 1)]
	var lanes: Array[int] = [0, 1, 2]
	for target in targets:
		lanes.erase(target.lane)
	var lane: int = lanes[_rng.randi_range(0, lanes.size() - 1)]
	var center: float = 0.23 + lane * 0.27
	var x_start: float = center + _rng.randf_range(-0.02, 0.02)
	var x_end: float = center + _rng.randf_range(-0.025, 0.025)
	var peak: float = _rng.randf_range(0.18, 0.38)
	var spin: float = _rng.randf_range(-0.12, 0.12)
	spawned += 1
	targets.append({
		"uid": spawned, "word": word.duplicate(true), "forms": _aliases[word.id].duplicate(),
		"age": 0.0, "lifetime": WORD_LIFETIME, "lane": lane, "volley": false,
		"x_start": x_start, "x_end": x_end, "peak": peak, "spin": spin,
		"x": x_start, "drift": x_end - x_start, "height": peak, "rotation": spin
	})
	_spawn_counts[word.id] = fewest + 1


func _can_spawn(word: Dictionary) -> bool:
	for target in targets:
		if GameData.confusable_words(word.id, target.word.id) or SpeechWords.compounds_conflict(word.text, target.word.text):
			return false
		for form: String in _aliases[word.id]:
			if target.forms.has(form):
				return false
	return true


func _expire_targets() -> void:
	for target in targets.duplicate():
		if target.age + EPSILON < target.lifetime:
			continue
		misses += 1
		targets.erase(target)
	if spawned == total_words and targets.is_empty() and hp > 0:
		phase = "lost"
		_clear_recognition()


func _clear_active_run() -> void:
	_clear_recognition()
	_consumed_speech_events.clear()
	targets.clear()
	selected_parts.clear()
	repaired_toys.clear()
	_run_id = ""
	_run_clear_number = 0
	_chest_id = ""
	_reward_claimed = false
	_paused_phase = "playing"
	_new_round()


func _clear_recognition() -> void:
	last_transcript = ""
	feedback = ""


func _new_round() -> void:
	_round_serial += 1
	round_id = "tq-round-%d-%d-%d" % [get_instance_id(), Time.get_ticks_usec(), _round_serial]


func _select_chest(number: int) -> String:
	if _level_clears[number - 1] == 0:
		return "chest-%02d" % number
	return _replay_chest(total_clears - completed_levels.size())


func _replay_chest(replay_index: int) -> String:
	var number: int = replay_index + 15 if replay_index < 6 else (replay_index - 6) % Data.CHEST_COUNT + 1
	if number == 14 and not companion_unlocked:
		number = 15
	return "chest-%02d" % number


func _rebuild_progress() -> void:
	completed_levels.clear()
	collected_chests.clear()
	total_clears = 0
	for index in range(Data.LEVEL_COUNT):
		total_clears += _level_clears[index]
		if _level_clears[index] > 0:
			completed_levels.append(index + 1)
			collected_chests.append("chest-%02d" % (index + 1))
	unlocked_level = mini(Data.LEVEL_COUNT, completed_levels.size() + 1)
	companion_unlocked = _level_clears[Data.LEVEL_COUNT - 1] > 0
	var replay_clears: int = total_clears - completed_levels.size()
	for index in range(mini(replay_clears, Data.CHEST_COUNT + 6)):
		var id: String = _replay_chest(index)
		if not collected_chests.has(id):
			collected_chests.append(id)
	collected_chests.sort()


func _valid_run_header(saved: Dictionary) -> bool:
	return _is_bounded_integer(saved.get("level_number"), 1, Data.LEVEL_COUNT) \
		and is_unlocked(int(saved.level_number)) \
		and _is_bounded_integer(saved.get("clear_number"), 1, MAX_LEVEL_CLEARS) \
		and int(saved.clear_number) == _level_clears[int(saved.level_number) - 1] + 1 \
		and saved.get("phase") is String and saved.phase in ACTIVE_PHASES


func _restore_run(saved: Dictionary) -> void:
	if not _valid_run_header(saved):
		return
	var restored_level: Dictionary = Data.level(int(saved.level_number))
	if not _is_bounded_integer(saved.get("hits"), 0, restored_level.hp) \
		or not _is_bounded_integer(saved.get("misses"), 0, restored_level.word_budget) \
		or not _is_bounded_integer(saved.get("spawned"), 1, restored_level.word_budget) \
		or not _number_between(saved.get("elapsed"), 0.0, 3600.0) \
		or not _number_between(saved.get("next_spawn_in"), 0.0, 3.0) \
		or not saved.get("targets") is Array or saved.targets.size() > MAX_TARGETS:
		return
	var won: bool = int(saved.hits) == int(restored_level.hp)
	if won != (saved.phase in ["victory", "chest"]):
		return
	if won and (not saved.targets.is_empty() or int(saved.spawned) < int(saved.hits) + int(saved.misses)):
		return
	if not won and (int(saved.spawned) != int(saved.hits) + int(saved.misses) + saved.targets.size() \
		or (saved.targets.is_empty() and int(saved.spawned) == int(restored_level.word_budget))):
		return
	var restored_targets: Array[Dictionary] = []
	var seen_uids: Dictionary = {}
	var seen_lanes: Dictionary = {}
	var seen_forms: Array[String] = []
	for entry: Variant in saved.targets:
		if not entry is Dictionary or not _is_bounded_integer(entry.get("uid"), 1, int(saved.spawned)) \
			or not _is_bounded_integer(entry.get("lane"), 0, MAX_TARGETS - 1) \
			or not entry.get("word_id") is String or seen_uids.has(entry.uid) or seen_lanes.has(entry.lane) \
			or not _valid_saved_lifetime(entry.get("lifetime")) \
			or not _number_between(entry.get("age"), 0.0, float(entry.lifetime) - EPSILON) \
			or not _number_between(entry.get("x_start"), 0.15, 0.85) \
			or not _number_between(entry.get("x_end"), 0.15, 0.85) \
			or not _number_between(entry.get("peak"), 0.1, 0.5) \
			or not _number_between(entry.get("spin"), -0.2, 0.2):
			return
		var word: Dictionary = {}
		for candidate: Dictionary in restored_level.words:
			if candidate.id == entry.word_id:
				word = candidate
				break
		if word.is_empty():
			return
		var forms: Array[String] = SpeechWords.forms(word.text, true)
		for form in forms:
			if seen_forms.has(form):
				return
		seen_forms.append_array(forms)
		seen_uids[entry.uid] = true
		seen_lanes[entry.lane] = true
		# Apply the longer countdown to existing attempts without resetting age.
		restored_targets.append({
			"uid": int(entry.uid), "word": word.duplicate(true), "forms": forms,
			"age": float(entry.age), "lifetime": WORD_LIFETIME, "lane": int(entry.lane), "volley": false,
			"x_start": float(entry.x_start), "x_end": float(entry.x_end), "peak": float(entry.peak), "spin": float(entry.spin),
			"x": float(entry.x_start), "drift": float(entry.x_end) - float(entry.x_start),
			"height": float(entry.peak), "rotation": float(entry.spin)
		})
	_set_level(int(saved.level_number))
	hits = int(saved.hits)
	line_index = hits
	hp = max_hp - hits
	misses = int(saved.misses)
	spawned = int(saved.spawned)
	elapsed = float(saved.elapsed)
	targets = restored_targets
	_next_spawn_at = elapsed + float(saved.next_spawn_in) if spawned < total_words else INF
	_accept_restored_run(saved)


func _restore_legacy_reward(saved: Dictionary) -> void:
	# Sentence checkpoints cannot describe finite word flights. Keep earned
	# progress and completed pending rewards, but restart unfinished battles.
	if not _valid_run_header(saved) or saved.phase not in ["victory", "chest"]:
		return
	var old_level: Dictionary = Data.level(int(saved.level_number))
	if not _is_bounded_integer(saved.get("line_index"), old_level.lines.size(), old_level.lines.size()):
		return
	_set_level(int(saved.level_number))
	hits = max_hp
	line_index = hits
	hp = 0
	spawned = hits
	_accept_restored_run(saved)


func _accept_restored_run(saved: Dictionary) -> void:
	_run_clear_number = int(saved.clear_number)
	_run_serial += 1
	_run_id = "tq-run-%d-%d-%d" % [get_instance_id(), Time.get_ticks_usec(), _run_serial]
	if saved.get("run_id") is String and saved.run_id.length() <= MAX_EVENT_ID_LENGTH:
		var pattern := RegEx.new()
		pattern.compile("^tq-run--?[0-9]+-[0-9]+-[0-9]+$")
		if pattern.search(saved.run_id) != null:
			_run_id = saved.run_id
	_chest_id = _select_chest(level_number)
	_paused_phase = saved.phase
	phase = "paused"


func _result(reason: String, accepted: bool = false) -> Dictionary:
	return {
		"accepted": accepted, "matched": false, "completed": false, "damage": 0,
		"repair_completed": false, "reason": reason, "feedback": feedback,
		"phase": phase, "line_index": line_index, "hp": hp, "hits": hits,
		"misses": misses, "spawned": spawned, "total_words": total_words, "cooperative": false
	}


static func _is_bounded_integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number_between(value, float(minimum), float(maximum)) and float(value) == floor(float(value))


static func _valid_saved_lifetime(value: Variant) -> bool:
	# Earlier word-combat saves used shorter, level-dependent flight windows.
	return _number_between(value, WORD_LIFETIME, WORD_LIFETIME) or _number_between(value, 5.8, 6.8)


static func _number_between(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum


static func _is_nonnegative_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0


static func _clamped_count(value: Variant) -> int:
	if not _is_nonnegative_number(value) or float(value) != floor(float(value)):
		return 0
	return int(minf(float(value), float(MAX_LEVEL_CLEARS)))
