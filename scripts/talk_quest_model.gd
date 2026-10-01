extends RefCounted

signal changed

const Data = preload("res://scripts/talk_quest_data.gd")
const SAVE_VERSION: int = 1
const DAMAGE_PER_LINE: int = 10
const MAX_TEXT_LENGTH: int = 512
const MAX_EVENT_ID_LENGTH: int = 160
const MAX_FINAL_EVENTS: int = 16384
const MAX_LEVEL_CLEARS: int = 100000
const ACTIVE_PHASES: Array[String] = ["playing", "victory", "chest"]
const CONTRACTIONS: Dictionary = {
	"who's": "who is", "what's": "what is", "where's": "where is",
	"it's": "it is", "that's": "that is", "there's": "there is", "here's": "here is",
	"i'm": "i am", "you're": "you are", "we're": "we are", "they're": "they are",
	"let's": "let us", "can't": "can not", "cannot": "can not", "won't": "will not",
	"don't": "do not", "doesn't": "does not", "didn't": "did not",
	"isn't": "is not", "aren't": "are not", "wasn't": "was not", "weren't": "were not",
	"couldn't": "could not", "wouldn't": "would not", "shouldn't": "should not",
	"haven't": "have not", "hasn't": "has not", "hadn't": "had not",
	"i'll": "i will", "you'll": "you will", "we'll": "we will", "they'll": "they will",
	"i've": "i have", "you've": "you have", "we've": "we have", "they've": "they have"
}

var phase: String = "ready"
var level_number: int = 1
var level: Dictionary = {}
var line_index: int = 0
var hp: int = 0
var max_hp: int = 0
var round_id: String = ""
var last_transcript: String = ""
var feedback: String = ""
var repaired_toys: Array[String] = []
var selected_parts: Array[String] = []
var completed_levels: Array[int] = []
var unlocked_level: int = 1
var collected_chests: Array[String] = []
var total_clears: int = 0
var companion_unlocked: bool = false

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


func _init() -> void:
	_level_clears.resize(Data.LEVEL_COUNT)
	_level_clears.fill(0)
	_set_level(1, 0)
	_new_round()


func start_level(number: int) -> bool:
	if not is_unlocked(number) or _level_clears[number - 1] >= MAX_LEVEL_CLEARS:
		return false
	_clear_active_run()
	_set_level(number, 0)
	_run_serial += 1
	_run_id = "tq-run-%d-%d-%d" % [get_instance_id(), Time.get_ticks_usec(), _run_serial]
	_run_clear_number = _level_clears[number - 1] + 1
	_chest_id = _select_chest(number)
	phase = "playing"
	changed.emit()
	return true


func is_unlocked(number: int) -> bool:
	return number >= 1 and number <= Data.LEVEL_COUNT and number <= unlocked_level


func clear_count(number: int) -> int:
	return _level_clears[number - 1] if number >= 1 and number <= Data.LEVEL_COUNT else 0


func is_cooperative() -> bool:
	return level.get("cooperative", false)


func progress_ratio() -> float:
	return float(line_index) / float(level.lines.size()) if not level.is_empty() else 0.0


func current_prompt() -> Dictionary:
	if phase not in ["playing", "paused"] or line_index >= level.lines.size():
		return {}
	var prompt: Dictionary = level.lines[line_index].duplicate(true)
	prompt.index = line_index
	prompt.line_number = line_index + 1
	prompt.total_lines = level.lines.size()
	return prompt


func speech_target() -> Dictionary:
	return {"round_id": round_id, "target_uid": line_index + 1 if phase == "playing" else 0}


func current_chest() -> Dictionary:
	return Data.chest(_chest_id) if not _chest_id.is_empty() else {}


func current_part_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if not is_cooperative() or phase not in ["playing", "paused"] or line_index >= level.lines.size():
		return choices
	var repair_index: int = floori(float(line_index) / 4.0)
	for choice: Dictionary in Data.REPAIRS[repair_index].choices:
		choices.append(choice.duplicate(true))
	return choices


func has_correct_part() -> bool:
	if not is_cooperative():
		return true
	if line_index >= level.lines.size():
		return selected_parts.size() == Data.REPAIR_COUNT
	var repair_index: int = floori(float(line_index) / 4.0)
	return selected_parts.size() > repair_index \
		and selected_parts[repair_index] == Data.REPAIRS[repair_index].correct_part


func choose_part(id: String) -> Dictionary:
	if phase != "playing" or not is_cooperative() or line_index >= level.lines.size():
		return _part_result("not_choosing")
	if has_correct_part():
		return _part_result("part_already_selected")
	var choices: Array[Dictionary] = current_part_choices()
	var selected: Dictionary = {}
	for choice in choices:
		if choice.id == id:
			selected = choice
			break
	if selected.is_empty():
		return _part_result("invalid_part")
	var repair_index: int = floori(float(line_index) / 4.0)
	var repair: Dictionary = Data.REPAIRS[repair_index]
	if id != repair.correct_part:
		feedback = "That piece belongs to another toy. Try a different part."
		changed.emit()
		return _part_result("wrong_part", true)
	selected_parts.append(id)
	_clear_recognition()
	# Speech captured before the gate opened cannot become a later line hit.
	_new_round()
	feedback = "The %s fits! Read the sentence together." % str(selected.label).to_lower()
	var result: Dictionary = _part_result("part_selected", true, true)
	result.part_id = id
	result.repair_id = repair.id
	changed.emit()
	return result


func submit_transcript(text: String) -> Dictionary:
	# The explicit practice action shares the sentence validator, but external
	# microphone results must use submit_speech_event with their original binding.
	_manual_serial += 1
	var event: Dictionary = speech_target()
	event.merge({
		"event_id": "practice-%d-%d" % [get_instance_id(), _manual_serial],
		"text": text, "stage": "final"
	})
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
	if not _is_bounded_integer(event.target_uid, 1, level.lines.size()):
		return _result("invalid_target")
	if int(event.target_uid) != line_index + 1:
		return _result("stale_target")
	if event.has("received_at_ms") and not _is_nonnegative_number(event.received_at_ms):
		return _result("invalid_timestamp")
	if event.stage == "final" and _consumed_speech_events.size() >= MAX_FINAL_EVENTS:
		return _result("session_limit")
	last_transcript = event.text.strip_edges()
	if event.stage == "interim":
		feedback = "Listening..."
		changed.emit()
		return _result("interim", true)
	# Every final attempt is consumed, including a mismatch. A revised result
	# cannot be rebound to another line or award the same line a second time.
	_consumed_speech_events[event.event_id] = true
	if not has_correct_part():
		feedback = "Choose the piece that will help this toy first."
		changed.emit()
		return _result("part_required", true)
	var prompt: Dictionary = current_prompt()
	if not sentence_matches(last_transcript, prompt.text):
		feedback = "Try the whole sentence: " + prompt.text if not last_transcript.is_empty() \
			else "I did not catch that. Try saying: " + prompt.text
		changed.emit()
		return _result("sentence_mismatch", true)
	line_index += 1
	var damage: int = 0 if is_cooperative() else DAMAGE_PER_LINE
	hp = maxi(0, hp - damage)
	var repair_completed: bool = is_cooperative() and prompt.repair_step == 4
	if repair_completed:
		repaired_toys.append(prompt.repair_id)
	feedback = "Great teamwork!" if is_cooperative() else "Great speaking!"
	var completed: bool = line_index == level.lines.size()
	if completed:
		phase = "victory"
		feedback = "All five toys are ready!" if is_cooperative() else "You did it!"
	var result: Dictionary = _result("matched", true)
	result.merge({
		"matched": true, "completed": completed, "damage": damage,
		"repair_completed": repair_completed, "repair_id": prompt.get("repair_id", ""),
		"prompt": prompt, "target_uid": prompt.uid
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
	# A caller that wants Continue Saved should pause and checkpoint first.
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
	if phase != "chest" or line_index != level.lines.size():
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
	return not _reward_claimed and _run_clear_number > 0 \
		and (phase in ACTIVE_PHASES or phase == "paused")


func export_progress() -> Dictionary:
	# Recognition text, event IDs, recordings, and transient feedback never enter
	# persistent storage. HP, repairs, unlocks, and collections are derived.
	var result: Dictionary = {
		"version": SAVE_VERSION, "completion_counts": _level_clears.duplicate(), "run": {}
	}
	if has_saved_run():
		result.run = {
			"level_number": level_number, "line_index": line_index,
			"phase": _paused_phase if phase == "paused" else phase,
			"clear_number": _run_clear_number, "run_id": _run_id,
			"selected_parts": selected_parts.duplicate()
		}
	return result


func import_progress(progress: Variant) -> bool:
	if not progress is Dictionary or progress.get("version") != SAVE_VERSION \
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
	_set_level(1, 0)
	phase = "ready"
	if progress.get("run") is Dictionary:
		_restore_run(progress.run)
	changed.emit()
	return true


static func normalize_sentence(text: String) -> String:
	var cleaned: String = text.to_lower().replace("\u2019", "'").replace("\u2018", "'")
	var pattern := RegEx.new()
	# Preserve all words, numbers, Unicode letters, and internal apostrophes.
	# Sentence punctuation may vary; extra words and negation cannot disappear.
	pattern.compile("[\\p{L}\\p{N}_]+(?:'[\\p{L}\\p{N}_]+)*")
	var words: Array[String] = []
	for token in pattern.search_all(cleaned):
		var word: String = token.get_string()
		words.append(CONTRACTIONS.get(word, word))
	return " ".join(words)


static func sentence_matches(spoken: String, expected: String) -> bool:
	if spoken.length() > MAX_TEXT_LENGTH or expected.is_empty():
		return false
	var normalized: String = normalize_sentence(spoken)
	return not normalized.is_empty() and normalized == normalize_sentence(expected)


func _set_level(number: int, completed_lines: int) -> void:
	level_number = number
	level = Data.level(number)
	line_index = clampi(completed_lines, 0, level.lines.size())
	max_hp = 0 if is_cooperative() else level.lines.size() * DAMAGE_PER_LINE
	hp = 0 if is_cooperative() else max_hp - line_index * DAMAGE_PER_LINE
	repaired_toys.clear()
	if is_cooperative():
		for index in range(line_index):
			var prompt: Dictionary = level.lines[index]
			if prompt.repair_step == 4:
				repaired_toys.append(prompt.repair_id)


func _clear_active_run() -> void:
	_clear_recognition()
	_consumed_speech_events.clear()
	selected_parts.clear()
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
	# The companion is earned by completing all five workshop repairs.
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
	# After six bonus rewards and one full cycle, every obtainable design has
	# appeared. This bound also keeps loading a large valid counter inexpensive.
	var replay_clears: int = total_clears - completed_levels.size()
	for index in range(mini(replay_clears, Data.CHEST_COUNT + 6)):
		var id: String = _replay_chest(index)
		if not collected_chests.has(id):
			collected_chests.append(id)
	collected_chests.sort()


func _restore_run(saved: Dictionary) -> void:
	if not _is_bounded_integer(saved.get("level_number"), 1, Data.LEVEL_COUNT):
		return
	var number: int = int(saved.level_number)
	if not is_unlocked(number) or _level_clears[number - 1] >= MAX_LEVEL_CLEARS:
		return
	if not _is_bounded_integer(saved.get("clear_number"), 1, MAX_LEVEL_CLEARS) \
		or int(saved.clear_number) != _level_clears[number - 1] + 1:
		return
	var restored_level: Dictionary = Data.level(number)
	if not _is_bounded_integer(saved.get("line_index"), 0, restored_level.lines.size()):
		return
	if not saved.get("phase") is String or saved.phase not in ACTIVE_PHASES:
		return
	var completed_lines: int = int(saved.line_index)
	var saved_phase: String = saved.phase
	if completed_lines < restored_level.lines.size() and saved_phase != "playing":
		return
	if completed_lines == restored_level.lines.size() and saved_phase == "playing":
		saved_phase = "victory"
	var restored_parts: Array[String] = []
	if restored_level.cooperative:
		var minimum_parts: int = ceili(float(completed_lines) / 4.0)
		var maximum_parts: int = mini(floori(float(completed_lines) / 4.0) + 1, Data.REPAIR_COUNT)
		if saved.has("selected_parts"):
			if not saved.selected_parts is Array or saved.selected_parts.size() < minimum_parts \
				or saved.selected_parts.size() > maximum_parts:
				return
			for index in range(saved.selected_parts.size()):
				if not saved.selected_parts[index] is String \
					or saved.selected_parts[index] != Data.REPAIRS[index].correct_part:
					return
				restored_parts.append(saved.selected_parts[index])
		else:
			# Earlier version-one checkpoints predate the part gate. Retain their
			# spoken progress, inferring a part only for a group already begun.
			for index in range(minimum_parts):
				restored_parts.append(Data.REPAIRS[index].correct_part)
	_set_level(number, completed_lines)
	selected_parts = restored_parts
	_run_clear_number = int(saved.clear_number)
	_run_serial += 1
	_run_id = "tq-run-%d-%d-%d" % [get_instance_id(), Time.get_ticks_usec(), _run_serial]
	if saved.get("run_id") is String and saved.run_id.length() <= MAX_EVENT_ID_LENGTH:
		var id_pattern := RegEx.new()
		id_pattern.compile("^tq-run-[0-9]+-[0-9]+-[0-9]+$")
		if id_pattern.search(saved.run_id) != null:
			_run_id = saved.run_id
	_chest_id = _select_chest(number)
	_paused_phase = saved_phase
	phase = "paused"


func _result(reason: String, accepted: bool = false) -> Dictionary:
	return {
		"accepted": accepted, "matched": false, "completed": false, "damage": 0,
		"repair_completed": false, "reason": reason, "feedback": feedback,
		"phase": phase, "line_index": line_index, "hp": hp,
		"cooperative": is_cooperative()
	}


func _part_result(reason: String, accepted: bool = false, correct: bool = false) -> Dictionary:
	var result: Dictionary = _result(reason, accepted)
	result.correct = correct
	return result


static func _is_bounded_integer(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float):
		return false
	var number: float = float(value)
	return is_finite(number) and number == floor(number) and number >= minimum and number <= maximum


static func _is_nonnegative_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0


static func _clamped_count(value: Variant) -> int:
	if not _is_nonnegative_number(value) or float(value) != floor(float(value)):
		return 0
	return int(minf(float(value), float(MAX_LEVEL_CLEARS)))
