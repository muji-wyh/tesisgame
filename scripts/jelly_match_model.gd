class_name JellyMatchModel
extends RefCounted

signal changed
signal word_attempted(attempt_id: String, word_ids: Array[String], correct: bool)
signal fusion_started(payload: Dictionary)
signal cue_requested(cue: String)
signal chest_awarded(count: int)
signal finished(result: Dictionary)

const COLUMNS: int = 4
const ROWS: int = 6
const CAPACITY: int = COLUMNS * ROWS
const INITIAL_PAIRS: int = 4
const SETTLE_SECONDS: float = 0.45
# Leave time to listen, find the picture, and drag before the next pair arrives.
const INITIAL_SPAWN_INTERVAL: float = 7.0
const MIN_SPAWN_INTERVAL: float = 3.5
const SPEEDUP_PER_PAIR: float = 0.07
const FUSION_SECONDS: float = 1.05
const POP_SECONDS: float = 0.7
const FULL_SECONDS: float = 8.0
const EPSILON: float = 0.000001

var cells: Array[Dictionary] = []
var fusion: Dictionary = {}
var phase: String = "finished"
var paused: bool = false
var cleared_pairs: int = 0
var chest_count: int = 0
var generated_pairs: int = 0
var spawn_interval: float = INITIAL_SPAWN_INTERVAL
var spawn_elapsed: float = 0.0
var full_elapsed: float = -1.0
var error: String = ""

var _words: Array[Dictionary] = []
var _word_index: int = 0
var _next_tile_id: int = 1
var _attempt_count: int = 0
var _completed_words: Dictionary = {}
var _result: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _generation: int = 0


func configure(words: Array, level: int, seed_value: int = -1) -> bool:
	_generation += 1
	cells.clear()
	fusion.clear()
	_words.clear()
	_completed_words.clear()
	_result.clear()
	phase = "finished"
	paused = false
	cleared_pairs = 0
	chest_count = 0
	generated_pairs = 0
	spawn_interval = INITIAL_SPAWN_INTERVAL
	spawn_elapsed = 0.0
	full_elapsed = -1.0
	_word_index = 0
	_next_tile_id = 1
	_attempt_count = 0
	error = ""
	if seed_value < 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	var seen: Dictionary = {}
	for candidate in words:
		if not candidate is Dictionary or not _eligible(candidate, level):
			continue
		var word_id: String = str(candidate.id)
		if seen.has(word_id):
			continue
		seen[word_id] = true
		_words.append(candidate.duplicate(true))
	if _words.is_empty():
		error = "Jelly Match needs at least one pictured word for this level."
		changed.emit()
		return false
	# Randomize equal priorities before a stable curriculum ordering, so a new
	# round practises current unmastered words without always starting identically.
	for index in range(_words.size() - 1, 0, -1):
		var other: int = _rng.randi_range(0, index)
		var word: Dictionary = _words[index]
		_words[index] = _words[other]
		_words[other] = word
	var order: Dictionary = {}
	for index in range(_words.size()):
		order[str(_words[index].id)] = index
	_words.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_priority: int = int(a.get("_growth_priority", 0))
		var b_priority: int = int(b.get("_growth_priority", 0))
		return a_priority > b_priority if a_priority != b_priority else int(order[str(a.id)]) < int(order[str(b.id)]))
	phase = "playing"
	for index in range(INITIAL_PAIRS):
		_spawn_pair()
	changed.emit()
	return true


func step(delta: float) -> void:
	if paused or phase != "playing" or not is_finite(delta) or delta <= 0.0:
		return
	var generation: int = _generation
	var remaining: float = delta
	while remaining > EPSILON and phase == "playing" and not paused and generation == _generation:
		if not fusion.is_empty():
			var boundary: float = FUSION_SECONDS
			if not bool(fusion.popped):
				boundary = POP_SECONDS
			var elapsed: float = float(fusion.elapsed)
			var consumed: float = minf(remaining, maxf(0.0, boundary - elapsed))
			_age_cells(consumed)
			fusion.elapsed = elapsed + consumed
			remaining -= consumed
			if not bool(fusion.popped) and float(fusion.elapsed) + EPSILON >= POP_SECONDS:
				fusion.popped = true
				cue_requested.emit("pop")
				if generation != _generation or phase != "playing" or paused:
					break
			if not fusion.is_empty() and float(fusion.elapsed) + EPSILON >= FUSION_SECONDS:
				_complete_fusion()
		elif cells.size() >= CAPACITY:
			if full_elapsed < 0.0:
				_start_danger()
				if generation != _generation or phase != "playing" or paused:
					break
				if not fusion.is_empty():
					continue
			var next_second: float = minf(FULL_SECONDS, floorf(full_elapsed + EPSILON) + 1.0)
			var consumed: float = minf(remaining, maxf(0.0, next_second - full_elapsed))
			_age_cells(consumed)
			full_elapsed += consumed
			remaining -= consumed
			if full_elapsed + EPSILON >= FULL_SECONDS:
				finish_round()
			elif full_elapsed + EPSILON >= next_second:
				cue_requested.emit("danger")
		else:
			var consumed: float = minf(remaining, maxf(0.0, spawn_interval - spawn_elapsed))
			_age_cells(consumed)
			spawn_elapsed += consumed
			remaining -= consumed
			if spawn_elapsed + EPSILON >= spawn_interval:
				spawn_elapsed = 0.0
				_spawn_pair()
				if cells.size() >= CAPACITY:
					_start_danger()
	if generation == _generation:
		changed.emit()


func try_merge(a_id: int, b_id: int) -> String:
	if paused or phase != "playing" or not fusion.is_empty() or a_id == b_id:
		return "ignored"
	var a_index: int = _index_for_id(a_id)
	var b_index: int = _index_for_id(b_id)
	if a_index < 0 or b_index < 0:
		return "ignored"
	var a: Dictionary = cells[a_index]
	var b: Dictionary = cells[b_index]
	if float(a.age) + EPSILON < SETTLE_SECONDS or float(b.age) + EPSILON < SETTLE_SECONDS:
		return "ignored"
	_attempt_count += 1
	var attempt_id: String = "jelly-%d" % _attempt_count
	var word_ids: Array[String] = [str(a.word.id)]
	if str(b.word.id) != word_ids[0]:
		word_ids.append(str(b.word.id))
	if a.word.id != b.word.id or a.kind == b.kind:
		var generation: int = _generation
		word_attempted.emit(attempt_id, word_ids, false)
		if generation == _generation and phase == "playing":
			cue_requested.emit("wrong")
			changed.emit()
		return "wrong"
	fusion = {
		"a_id": a_id, "b_id": b_id,
		"a": a.duplicate(true), "b": b.duplicate(true),
		"word": a.word.duplicate(true), "attempt_id": attempt_id,
		"elapsed": 0.0, "duration": FUSION_SECONDS,
		"pop_at": POP_SECONDS, "popped": false
	}
	var generation: int = _generation
	fusion_started.emit(fusion.duplicate(true))
	if generation == _generation and phase == "playing" and not fusion.is_empty():
		cue_requested.emit("merge")
		changed.emit()
	return "correct"


func set_paused(value: bool) -> void:
	if paused == value:
		return
	paused = value
	changed.emit()


func tile_by_id(tile_id: int) -> Dictionary:
	var index: int = _index_for_id(tile_id)
	return {} if index < 0 else cells[index].duplicate(true)


func score() -> int:
	# Only completed fusions count; an interrupted merge has earned no point.
	return cleared_pairs


func snapshot() -> Dictionary:
	return {
		"cells": cells.duplicate(true), "fusion": fusion.duplicate(true),
		"phase": phase, "paused": paused, "cleared_pairs": cleared_pairs, "score": score(),
		"chest_count": chest_count, "generated_pairs": generated_pairs,
		"spawn_interval": spawn_interval, "spawn_elapsed": spawn_elapsed,
		"full_elapsed": full_elapsed,
		"full_remaining": maxf(0.0, FULL_SECONDS - full_elapsed) if full_elapsed >= 0.0 else -1.0,
		"error": error, "result": _result.duplicate(true)
	}


func finish_round() -> Dictionary:
	if phase == "finished":
		return _result.duplicate(true)
	# An interrupted fusion has not cleared its tiles yet, so it earns no attempt
	# or chest. Previously completed clears are already reflected in the result.
	phase = "finished"
	fusion.clear()
	_result = {"cleared_pairs": cleared_pairs, "score": score(), "chest_count": chest_count, "words": []}
	for word in _completed_words.values():
		_result.words.append(word.duplicate(true))
	var result: Dictionary = _result.duplicate(true)
	finished.emit(result.duplicate(true))
	changed.emit()
	return result


func _eligible(word: Dictionary, level: int) -> bool:
	for key in ["id", "text", "image", "audio"]:
		if not word.get(key) is String or str(word[key]).strip_edges().is_empty():
			return false
	var minimum_age: int = int(word.get("min_age", 3))
	return minimum_age >= 3 and minimum_age <= mini(level, 12)


func _spawn_pair() -> void:
	if _words.is_empty() or cells.size() + 2 > CAPACITY:
		return
	var word: Dictionary = _words[_word_index % _words.size()]
	_word_index += 1
	generated_pairs += 1
	# Initial pairs participate in this cadence; the third starting pair has one
	# chest. Paired supply and two-tile clears preserve a match on every full board.
	var marked_index: int = _rng.randi_range(0, 1) if generated_pairs % 3 == 0 else -1
	var first_is_word: bool = _rng.randi_range(0, 1) == 0
	for index in range(2):
		var column: int = _spawn_column()
		var height: int = _column_height(column)
		cells.append({
			"id": _next_tile_id, "word": word.duplicate(true),
			"kind": "word" if (index == 0) == first_is_word else "picture",
			"column": column, "row": ROWS - height - 1,
			"chest": index == marked_index, "age": 0.0, "falling_rows": ROWS - height
		})
		_next_tile_id += 1


func _spawn_column() -> int:
	var shortest: int = ROWS
	var candidates: Array[int] = []
	for column in range(COLUMNS):
		var height: int = _column_height(column)
		if height < shortest:
			shortest = height
			candidates.clear()
		if height == shortest and height < ROWS:
			candidates.append(column)
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _column_height(column: int) -> int:
	var height: int = 0
	for cell in cells:
		if int(cell.column) == column:
			height += 1
	return height


func _index_for_id(tile_id: int) -> int:
	for index in range(cells.size()):
		if int(cells[index].id) == tile_id:
			return index
	return -1


func _age_cells(delta: float) -> void:
	for cell in cells:
		cell.age = float(cell.age) + delta


func _start_danger() -> void:
	if full_elapsed >= 0.0:
		return
	full_elapsed = 0.0
	cue_requested.emit("danger")


func _complete_fusion() -> void:
	var completed: Dictionary = fusion.duplicate(true)
	fusion.clear()
	var awarded: int = 0
	for index in range(cells.size() - 1, -1, -1):
		if int(cells[index].id) in [int(completed.a_id), int(completed.b_id)]:
			awarded += 1 if bool(cells[index].chest) else 0
			cells.remove_at(index)
	_apply_gravity()
	full_elapsed = -1.0
	cleared_pairs += 1
	chest_count += awarded
	spawn_interval = maxf(MIN_SPAWN_INTERVAL, INITIAL_SPAWN_INTERVAL - cleared_pairs * SPEEDUP_PER_PAIR)
	_completed_words[str(completed.word.id)] = completed.word.duplicate(true)
	var generation: int = _generation
	var word_ids: Array[String] = [str(completed.word.id)]
	word_attempted.emit(str(completed.attempt_id), word_ids, true)
	if generation != _generation:
		return
	if awarded > 0:
		chest_awarded.emit(awarded)
		if generation == _generation and phase == "playing":
			cue_requested.emit("chest")


func _apply_gravity() -> void:
	for column in range(COLUMNS):
		var stack: Array[Dictionary] = []
		for cell in cells:
			if int(cell.column) == column:
				stack.append(cell)
		stack.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.row) > int(b.row))
		for index in range(stack.size()):
			var row: int = ROWS - index - 1
			if int(stack[index].row) != row:
				stack[index].falling_rows = row - int(stack[index].row)
				stack[index].row = row
				stack[index].age = 0.0
