class_name JellyMatchModel
extends RefCounted

signal changed
signal word_attempted(attempt_id: String, word_ids: Array[String], correct: bool)
signal fusion_started(payload: Dictionary)
signal fusion_completed(payload: Dictionary, awarded: int)
signal cue_requested(cue: String)
signal fragments_awarded(count: int)
signal chest_milestone(previous_tier: int, new_tier: int)
signal finished(result: Dictionary)

const Motion = preload("res://scripts/jelly_motion.gd")
const COLUMNS: int = 4
const ROWS: int = 6
const CAPACITY: int = COLUMNS * ROWS
const INITIAL_SETTLED_TILES: int = 6
const DROP_COUNT: int = 4
const UPCOMING_COUNT: int = DROP_COUNT
const SUPPLY_BATCH_PAIRS: int = 3
const SETTLE_SECONDS: float = Motion.MAX_SETTLE_SECONDS
# Leave time to listen, find the picture, and drag before the next drop arrives.
const INITIAL_SPAWN_INTERVAL: float = 10.0
const MIN_SPAWN_INTERVAL: float = 6.0
const SPEEDUP_PER_PAIR: float = 0.05
const FUSION_SECONDS: float = 1.05
const POP_SECONDS: float = 0.7
const FULL_SECONDS: float = 8.0
const CHEST_UNLOCK_FRAGMENTS: int = 4
const CHEST_UPGRADE_FRAGMENTS: int = 5
const EPSILON: float = 0.000001

var cells: Array[Dictionary] = []
var upcoming: Array[Dictionary] = []
var fusions: Array[Dictionary] = []
var fusion: Dictionary:
	get:
		return {} if fusions.is_empty() else fusions[0]
var phase: String = "finished"
var paused: bool = false
var cleared_pairs: int = 0
var fragment_count: int = 0
var chest_tier: int = 0
var chest_count: int = 0
var generated_tiles: int = 0
var spawn_interval: float = INITIAL_SPAWN_INTERVAL
var spawn_elapsed: float = 0.0
var full_elapsed: float = -1.0
var error: String = ""

var _words: Array[Dictionary] = []
var _supply: Array[Dictionary] = []
var _word_index: int = 0
var _supply_pairs: int = 0
var _last_supply_word: String = ""
var _next_tile_id: int = 1
var _attempt_count: int = 0
var _completed_words: Dictionary = {}
var _result: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _generation: int = 0


func configure(words: Array, level: int, seed_value: int = -1) -> bool:
	_generation += 1
	cells.clear()
	upcoming.clear()
	fusions.clear()
	_words.clear()
	_supply.clear()
	_completed_words.clear()
	_result.clear()
	phase = "finished"
	paused = false
	cleared_pairs = 0
	fragment_count = 0
	chest_tier = 0
	chest_count = 0
	generated_tiles = 0
	spawn_interval = INITIAL_SPAWN_INTERVAL
	spawn_elapsed = 0.0
	full_elapsed = -1.0
	_word_index = 0
	_supply_pairs = 0
	_last_supply_word = ""
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
	_fill_upcoming()
	for index in range(INITIAL_SETTLED_TILES):
		_spawn_tile(false)
	changed.emit()
	return true


func step(delta: float) -> void:
	if paused or phase != "playing" or not is_finite(delta) or delta <= 0.0:
		return
	var generation: int = _generation
	var remaining: float = delta
	while remaining > EPSILON and phase == "playing" and not paused and generation == _generation:
		if not fusions.is_empty():
			# Advance every active merge to the next shared event boundary. Supply,
			# airborne tiles, and danger stay paused until the final merge releases.
			var consumed: float = remaining
			for active in fusions:
				var boundary: float = FUSION_SECONDS if bool(active.popped) else POP_SECONDS
				consumed = minf(consumed, maxf(0.0, boundary - float(active.elapsed)))
			for active in fusions:
				active.elapsed = float(active.elapsed) + consumed
			remaining -= consumed
			# A callback may add, stop, or replace merges. Iterate the current batch
			# only, and recheck each receipt before publishing another event.
			for active in fusions.duplicate():
				if generation != _generation or phase != "playing" or paused:
					break
				if _fusion_index(str(active.attempt_id)) < 0:
					continue
				if not bool(active.popped) and float(active.elapsed) + EPSILON >= POP_SECONDS:
					active.popped = true
					cue_requested.emit("pop")
					if generation != _generation or phase != "playing" or paused:
						break
				if float(active.elapsed) + EPSILON >= FUSION_SECONDS:
					_complete_fusion(str(active.attempt_id))
		elif cells.size() >= CAPACITY:
			var settling: float = _settling_remaining()
			if settling > EPSILON:
				var settle_delta: float = minf(remaining, settling)
				_age_cells(settle_delta)
				remaining -= settle_delta
				if _settling_remaining() > EPSILON:
					continue
			if full_elapsed < 0.0:
				_start_danger()
				if generation != _generation or phase != "playing" or paused:
					break
				if not fusions.is_empty():
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
				_spawn_drop()
	if generation == _generation:
		changed.emit()


func can_drop_now() -> bool:
	return phase == "playing" and not paused and fusions.is_empty() \
		and cells.size() < CAPACITY and not upcoming.is_empty() \
		and _settling_remaining() <= EPSILON


func drop_now(expected_first_id: int = -1) -> bool:
	if not can_drop_now():
		return false
	if expected_first_id != -1 and expected_first_id != int(upcoming[0].id):
		return false
	# Dispatch the advertised batch without advancing any existing tile or clock.
	# The next automatic batch receives its full interval after this release.
	spawn_elapsed = 0.0
	_spawn_drop()
	changed.emit()
	return true


func try_merge(a_id: int, b_id: int, held_source: bool = false) -> String:
	if paused or phase != "playing" or a_id == b_id or is_fusing(a_id) or is_fusing(b_id):
		return "ignored"
	var a_index: int = _index_for_id(a_id)
	var b_index: int = _index_for_id(b_id)
	if a_index < 0 or b_index < 0:
		return "ignored"
	var a: Dictionary = cells[a_index]
	var b: Dictionary = cells[b_index]
	# A drag that began on a settled tile may outlive another pair's clear.
	# Gravity can retarget that held source without invalidating the gesture.
	if (not held_source and not is_settled(a)) or not is_settled(b):
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
	var active: Dictionary = {
		"a_id": a_id, "b_id": b_id,
		"a": a.duplicate(true), "b": b.duplicate(true),
		"word": a.word.duplicate(true), "attempt_id": attempt_id,
		"elapsed": 0.0, "duration": FUSION_SECONDS,
		"pop_at": POP_SECONDS, "popped": false
	}
	fusions.append(active)
	var generation: int = _generation
	fusion_started.emit(active.duplicate(true))
	if generation == _generation and phase == "playing" and not paused and _fusion_index(attempt_id) >= 0:
		cue_requested.emit("merge")
		if generation == _generation and phase == "playing":
			changed.emit()
	return "correct"


func set_paused(value: bool) -> void:
	if paused == value:
		return
	paused = value
	changed.emit()


func is_fusing(tile_id: int) -> bool:
	for active in fusions:
		if tile_id == int(active.a_id) or tile_id == int(active.b_id):
			return true
	return false


func is_settled(cell: Dictionary) -> bool:
	return not cell.is_empty() and float(cell.get("age", 0.0)) + EPSILON >= Motion.ready_at(cell)


func tile_by_id(tile_id: int) -> Dictionary:
	var index: int = _index_for_id(tile_id)
	return {} if index < 0 else cells[index].duplicate(true)


func score() -> int:
	# Only completed fusions count; an interrupted merge has earned no point.
	return cleared_pairs


static func reward_progress(total: int) -> Dictionary:
	var fragments: int = maxi(0, total)
	var tier: int = 0
	var progress: int = fragments
	var required: int = CHEST_UNLOCK_FRAGMENTS
	if fragments >= CHEST_UNLOCK_FRAGMENTS:
		tier = 1 + int((fragments - CHEST_UNLOCK_FRAGMENTS) / float(CHEST_UPGRADE_FRAGMENTS))
		progress = (fragments - CHEST_UNLOCK_FRAGMENTS) % CHEST_UPGRADE_FRAGMENTS
		required = CHEST_UPGRADE_FRAGMENTS
	return {
		"fragment_count": fragments, "chest_tier": tier,
		"chest_count": 1 if tier > 0 else 0,
		"fragments_toward_next": progress, "fragments_required": required
	}


func snapshot() -> Dictionary:
	var state: Dictionary = {
		"cells": cells.duplicate(true), "upcoming": upcoming.duplicate(true),
		"fusion": fusion.duplicate(true), "fusions": fusions.duplicate(true),
		"phase": phase, "paused": paused, "cleared_pairs": cleared_pairs, "score": score(),
		"chest_count": chest_count, "generated_tiles": generated_tiles,
		"spawn_interval": spawn_interval, "spawn_elapsed": spawn_elapsed,
		"full_elapsed": full_elapsed,
		"full_remaining": maxf(0.0, FULL_SECONDS - full_elapsed) if full_elapsed >= 0.0 else -1.0,
		"error": error, "result": _result.duplicate(true)
	}
	state.merge(reward_progress(fragment_count), true)
	return state


func finish_round() -> Dictionary:
	if phase == "finished":
		return _result.duplicate(true)
	# An interrupted fusion has not cleared its tiles yet, so it earns no attempt
	# or fragment. Previously completed clears are already reflected in the result.
	phase = "finished"
	fusions.clear()
	_result = {"cleared_pairs": cleared_pairs, "score": score(), "words": []}
	_result.merge(reward_progress(fragment_count))
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


func _spawn_drop() -> void:
	var used_columns: Array[int] = []
	var column_counts: Dictionary = {}
	for index in range(mini(DROP_COUNT, CAPACITY - cells.size())):
		var column: int = _spawn_column(used_columns)
		var ordinal: int = int(column_counts.get(column, 0))
		_spawn_tile(true, column, ordinal)
		column_counts[column] = ordinal + 1
		if not used_columns.has(column):
			used_columns.append(column)


func _spawn_tile(arrival: bool = true, column: int = -1, entry_offset: int = 0) -> void:
	if _words.is_empty() or cells.size() >= CAPACITY:
		return
	var tile: Dictionary = upcoming.pop_front()
	if column < 0:
		column = _spawn_column()
	var height: int = _column_height(column)
	tile.merge({
		"column": column, "row": ROWS - height - 1,
		"age": 0.0, "falling_rows": ROWS - height + entry_offset if arrival else 0,
		"arrival": arrival
	})
	if not arrival:
		tile.age = Motion.ready_at(tile)
	cells.append(tile)
	generated_tiles += 1
	_fill_upcoming()


func _fill_upcoming() -> void:
	while upcoming.size() < UPCOMING_COUNT:
		if _supply.is_empty():
			_build_supply_batch()
		upcoming.append(_supply.pop_front())


func _build_supply_batch() -> void:
	# Each bounded bag has two interleaved waves of complementary halves. Legal
	# clears preserve its word balance, leaving at most three unmatched halves
	# in any supply prefix: a full board therefore always contains a real match.
	var first_wave: Array[Dictionary] = []
	var second_wave: Array[Dictionary] = []
	for index in range(mini(SUPPLY_BATCH_PAIRS, _words.size())):
		var word: Dictionary = _words[_word_index % _words.size()]
		_word_index += 1
		_supply_pairs += 1
		var marked_half: int = _rng.randi_range(0, 1) if _supply_pairs % 3 == 0 else -1
		var first_is_word: bool = _rng.randi_range(0, 1) == 0
		for half in range(2):
			var tile: Dictionary = {
				"id": _next_tile_id, "word": word.duplicate(true),
				"kind": "word" if (half == 0) == first_is_word else "picture",
				"chest": half == marked_half
			}
			_next_tile_id += 1
			if half == 0:
				first_wave.append(tile)
			else:
				second_wave.append(tile)
	_shuffle_wave(first_wave, _last_supply_word)
	_shuffle_wave(second_wave, str(first_wave.back().word.id))
	_supply.append_array(first_wave)
	_supply.append_array(second_wave)
	_last_supply_word = str(second_wave.back().word.id)


func _shuffle_wave(wave: Array[Dictionary], previous_word: String) -> void:
	for index in range(wave.size() - 1, 0, -1):
		var other: int = _rng.randi_range(0, index)
		var tile: Dictionary = wave[index]
		wave[index] = wave[other]
		wave[other] = tile
	if wave.size() > 1 and str(wave[0].word.id) == previous_word:
		var other: int = _rng.randi_range(1, wave.size() - 1)
		var tile: Dictionary = wave[0]
		wave[0] = wave[other]
		wave[other] = tile


func _spawn_column(excluded: Array[int] = []) -> int:
	var shortest: int = ROWS
	var candidates: Array[int] = []
	for column in range(COLUMNS):
		if excluded.has(column):
			continue
		var height: int = _column_height(column)
		if height < shortest:
			shortest = height
			candidates.clear()
		if height == shortest and height < ROWS:
			candidates.append(column)
	if candidates.is_empty() and not excluded.is_empty():
		return _spawn_column()
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


func _settling_remaining() -> float:
	var remaining: float = 0.0
	for cell in cells:
		remaining = maxf(remaining, Motion.ready_at(cell) - float(cell.age))
	return remaining


func _start_danger() -> void:
	if full_elapsed >= 0.0:
		return
	full_elapsed = 0.0
	cue_requested.emit("danger")


func _fusion_index(attempt_id: String) -> int:
	for index in range(fusions.size()):
		if str(fusions[index].attempt_id) == attempt_id:
			return index
	return -1


func _complete_fusion(attempt_id: String) -> void:
	var fusion_index: int = _fusion_index(attempt_id)
	if fusion_index < 0:
		return
	var completed: Dictionary = fusions[fusion_index].duplicate(true)
	fusions.remove_at(fusion_index)
	var awarded: int = 0
	for index in range(cells.size() - 1, -1, -1):
		if int(cells[index].id) in [int(completed.a_id), int(completed.b_id)]:
			awarded += 1 if bool(cells[index].chest) else 0
			cells.remove_at(index)
	# Keep other reserved pairs and held tiles in place while their effects run.
	if fusions.is_empty():
		_apply_gravity()
	full_elapsed = -1.0
	cleared_pairs += 1
	var previous_tier: int = chest_tier
	fragment_count += awarded
	var reward: Dictionary = reward_progress(fragment_count)
	var new_tier: int = int(reward.chest_tier)
	chest_tier = new_tier
	chest_count = int(reward.chest_count)
	completed.merge({
		"fragment_count": fragment_count,
		"previous_chest_tier": previous_tier, "chest_tier": chest_tier
	})
	spawn_interval = maxf(MIN_SPAWN_INTERVAL, INITIAL_SPAWN_INTERVAL - cleared_pairs * SPEEDUP_PER_PAIR)
	_completed_words[str(completed.word.id)] = completed.word.duplicate(true)
	var generation: int = _generation
	var word_ids: Array[String] = [str(completed.word.id)]
	word_attempted.emit(str(completed.attempt_id), word_ids, true)
	if generation != _generation or phase != "playing":
		return
	fusion_completed.emit(completed, awarded)
	if generation != _generation or phase != "playing":
		return
	if awarded > 0:
		fragments_awarded.emit(awarded)
		if generation != _generation or phase != "playing":
			return
		if new_tier > previous_tier:
			chest_milestone.emit(previous_tier, new_tier)
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
				var cell: Dictionary = stack[index]
				var distance: int = row - int(cell.row)
				if bool(cell.get("arrival", false)) and float(cell.age) < Motion.contact_at(cell):
					# A paused incoming tile resumes at the same visible height even
					# when the completed clear moves its landing destination downward.
					cell.row = row
					cell.falling_rows = int(cell.falling_rows) + distance
				else:
					cell.falling_rows = distance
					cell.arrival = false
					cell.row = row
					cell.age = 0.0
