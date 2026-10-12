class_name WordJellyModel
extends RefCounted
## Persistent word-part jellies: merging builds a word; collecting earns it.

signal changed
signal word_attempted(attempt_id: String, word_ids: Array[String], correct: bool)
signal fusion_started(payload: Dictionary)
signal fusion_completed(payload: Dictionary, awarded: int)
signal collected(event_id: String, word: Dictionary, coins: int, fragments: int)
signal cue_requested(cue: String)
signal fragments_awarded(count: int)
signal chest_milestone(previous_tier: int, new_tier: int)
signal finished(result: Dictionary)

const RewardProgress = preload("res://scripts/jelly_reward_progress.gd")
const COLUMNS: int = 6
const ROWS: int = 8
const CAPACITY: int = COLUMNS * ROWS
const INITIAL_SETTLED_TILES: int = 12
const DROP_COUNT: int = 6
const UPCOMING_COUNT: int = 6
const SETTLE_SECONDS: float = 0.36
const FUSION_SECONDS: float = 0.76
const COLLECT_SECONDS: float = 0.42
const POP_SECONDS: float = 0.18
const INITIAL_SPAWN_INTERVAL: float = 14.0
const MIN_SPAWN_INTERVAL: float = 10.0
const FULL_SECONDS: float = 10.0
const CHEST_UNLOCK_FRAGMENTS: int = RewardProgress.CHEST_UNLOCK_FRAGMENTS
const CHEST_UPGRADE_FRAGMENTS: int = RewardProgress.CHEST_UPGRADE_FRAGMENTS
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
var collected_coins: int = 0
var merged_count: int = 0
var spawn_interval: float = INITIAL_SPAWN_INTERVAL
var spawn_elapsed: float = 0.0
var full_elapsed: float = -1.0
var error: String = ""
var credit_collection: Callable

var _words: Array[Dictionary] = []
var _word_lookup: Dictionary = {}
var _supply: Array[Dictionary] = []
var _completed_words: Dictionary = {}
var _result: Dictionary = {}
var _word_index: int = 0
var _supply_words: int = 0
var _next_tile_id: int = 1
var _next_event_id: int = 1
var _collection_event_ids: Dictionary = {}
var _generation: int = 0
var _rng := RandomNumberGenerator.new()


func configure(words: Array, level: int, seed_value: int = -1) -> bool:
	_generation += 1
	cells.clear()
	upcoming.clear()
	fusions.clear()
	_words.clear()
	_word_lookup.clear()
	_supply.clear()
	_completed_words.clear()
	_collection_event_ids.clear()
	_result.clear()
	phase = "finished"
	paused = false
	cleared_pairs = 0
	fragment_count = 0
	chest_tier = 0
	chest_count = 0
	generated_tiles = 0
	collected_coins = 0
	merged_count = 0
	spawn_interval = INITIAL_SPAWN_INTERVAL
	spawn_elapsed = 0.0
	full_elapsed = -1.0
	_word_index = 0
	_supply_words = 0
	_next_tile_id = 1
	_next_event_id = 1
	error = ""
	if seed_value < 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	var ids: Dictionary = {}
	for candidate in words:
		if not candidate is Dictionary or not _eligible(candidate, level):
			continue
		var normalized: String = normalize_word(str(candidate.text))
		if ids.has(str(candidate.id)) or _word_lookup.has(normalized):
			continue
		var word: Dictionary = candidate.duplicate(true)
		ids[str(word.id)] = true
		_words.append(word)
		_word_lookup[normalized] = word
	if _words.is_empty():
		error = "Word Jelly needs at least one pictured word for this age."
		changed.emit()
		return false
	for index in range(_words.size() - 1, 0, -1):
		var other: int = _rng.randi_range(0, index)
		var temporary: Dictionary = _words[index]
		_words[index] = _words[other]
		_words[other] = temporary
	# Keep the curriculum priority without making equal-priority rounds identical.
	_words.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("_growth_priority", 0)) > int(b.get("_growth_priority", 0)))
	phase = "playing"
	_fill_upcoming()
	for index in range(INITIAL_SETTLED_TILES):
		_spawn_tile(false)
	changed.emit()
	return true


static func normalize_word(value: String) -> String:
	var pieces: PackedStringArray = value.strip_edges().to_lower().replace("\t", " ").replace("\n", " ").split(" ", false)
	return " ".join(pieces)


func try_merge(a_id: int, b_id: int, held_source: bool = false) -> String:
	if phase != "playing" or paused or a_id == b_id or is_fusing(a_id) or is_fusing(b_id):
		return "ignored"
	var a: Dictionary = cell(a_id)
	var b: Dictionary = cell(b_id)
	if a.is_empty() or b.is_empty() or (not held_source and not is_settled(a)) or not is_settled(b):
		return "ignored"
	var mass: int = int(a.mass) + int(b.mass)
	var result: Dictionary = _new_tile(str(a.text) + str(b.text), mass, int(a.fragments) + int(b.fragments))
	result.skin = int(b.get("skin", b.id))
	var active: Dictionary = {
		"operation": "merge", "a_id": a_id, "b_id": b_id,
		"a": a.duplicate(true), "b": b.duplicate(true), "result": result,
		"word": result.word.duplicate(true), "attempt_id": _event_id("merge"),
		"elapsed": 0.0, "duration": FUSION_SECONDS, "pop_at": FUSION_SECONDS,
		"popped": false
	}
	fusions.append(active)
	var generation: int = _generation
	fusion_started.emit(active.duplicate(true))
	if _can_continue(generation) and _fusion_index(str(active.attempt_id)) >= 0:
		cue_requested.emit("merge")
		if _can_continue(generation):
			changed.emit()
	return "merged"


func collect(tile_id: int) -> bool:
	if phase != "playing" or paused or is_fusing(tile_id):
		return false
	var tile: Dictionary = cell(tile_id)
	if tile.is_empty() or not is_settled(tile) or not is_valid_word(tile):
		return false
	if not _collection_event_ids.has(tile_id):
		_collection_event_ids[tile_id] = _event_id("collect")
	var active: Dictionary = {
		"operation": "collect", "a_id": tile_id, "b_id": tile_id,
		"a": tile.duplicate(true), "b": tile.duplicate(true), "result": {},
		"word": tile.word.duplicate(true), "attempt_id": str(_collection_event_ids[tile_id]),
		"coins": coins_for_tile(tile), "fragments": int(tile.fragments),
		"elapsed": 0.0, "duration": COLLECT_SECONDS, "pop_at": POP_SECONDS,
		"popped": false, "credited": false
	}
	fusions.append(active)
	var generation: int = _generation
	fusion_started.emit(active.duplicate(true))
	if _can_continue(generation):
		changed.emit()
	return true


func step(delta: float) -> void:
	if phase != "playing" or paused or not is_finite(delta) or delta <= 0.0:
		return
	var generation: int = _generation
	var remaining: float = delta
	while remaining > EPSILON and _can_continue(generation):
		var consumed: float = remaining
		for active in fusions:
			var boundary: float = float(active.duration)
			if str(active.operation) == "collect" and not bool(active.popped):
				boundary = float(active.pop_at)
			consumed = minf(consumed, maxf(0.0, boundary - float(active.elapsed)))
		var full: bool = not _has_free_cell()
		var danger_running: bool = full and full_elapsed >= 0.0
		var next_second: float = minf(FULL_SECONDS, floorf(full_elapsed + EPSILON) + 1.0)
		if danger_running:
			consumed = minf(consumed, maxf(0.0, next_second - full_elapsed))
		elif full:
			consumed = minf(consumed, maxf(0.0, _settling_remaining()))
		else:
			consumed = minf(consumed, maxf(0.0, spawn_interval - spawn_elapsed))
		for tile in cells:
			tile.age = float(tile.age) + consumed
			tile.settling = float(tile.age) + EPSILON < SETTLE_SECONDS
		for active in fusions:
			active.elapsed = float(active.elapsed) + consumed
		if danger_running:
			full_elapsed += consumed
		elif not full:
			spawn_elapsed += consumed
		remaining -= consumed
		for active in fusions.duplicate():
			if not _can_continue(generation):
				break
			if _fusion_index(str(active.attempt_id)) < 0:
				continue
			if str(active.operation) == "collect" and not bool(active.popped) and float(active.elapsed) + EPSILON >= POP_SECONDS:
				active.popped = true
				cue_requested.emit("pop")
				if not _can_continue(generation):
					break
			if float(active.elapsed) + EPSILON >= float(active.duration):
				_complete_operation(str(active.attempt_id))
		if not _can_continue(generation):
			break
		if not _has_free_cell():
			if full_elapsed < 0.0 and _settling_remaining() <= EPSILON:
				full_elapsed = 0.0
				cue_requested.emit("danger")
				if not _can_continue(generation):
					break
			if danger_running and full_elapsed + EPSILON >= next_second:
				if full_elapsed + EPSILON >= FULL_SECONDS:
					finish_round()
				else:
					cue_requested.emit("danger")
		else:
			full_elapsed = -1.0
			if spawn_elapsed + EPSILON >= spawn_interval:
				spawn_elapsed = 0.0
				_spawn_drop()
	if generation == _generation:
		changed.emit()


func set_paused(value: bool) -> void:
	if paused != value:
		paused = value
		changed.emit()


func can_drop_now() -> bool:
	return phase == "playing" and not paused and not upcoming.is_empty() and _has_free_cell() and _settling_remaining() <= EPSILON


func drop_now(expected_first_id: int = -1) -> bool:
	if not can_drop_now() or (expected_first_id != -1 and expected_first_id != int(upcoming[0].id)):
		return false
	spawn_elapsed = 0.0
	_spawn_drop()
	changed.emit()
	return true


func cell(tile_id: int) -> Dictionary:
	var index: int = _index_for_id(tile_id)
	return {} if index < 0 else cells[index].duplicate(true)


func tile_by_id(tile_id: int) -> Dictionary:
	return cell(tile_id)


func is_fusing(tile_id: int) -> bool:
	for active in fusions:
		if tile_id == int(active.a_id) or tile_id == int(active.b_id):
			return true
	return false


func is_settled(tile: Dictionary) -> bool:
	return not tile.is_empty() and float(tile.get("age", 0.0)) + EPSILON >= SETTLE_SECONDS


func is_valid_word(tile: Dictionary) -> bool:
	return int(tile.get("mass", 0)) > 1 and not tile.get("word", {}).is_empty()


static func coins_for_tile(tile: Dictionary) -> int:
	var mass: int = maxi(1, int(tile.get("mass", tile.get("parts_count", 1))))
	return 50 * mass


func score() -> int:
	return cleared_pairs


static func reward_progress(total: int) -> Dictionary:
	return RewardProgress.reward_progress(total)


func snapshot() -> Dictionary:
	var state: Dictionary = {
		"cells": cells.duplicate(true), "upcoming": upcoming.duplicate(true),
		"fusion": fusion.duplicate(true), "fusions": fusions.duplicate(true),
		"phase": phase, "paused": paused, "cleared_pairs": cleared_pairs, "score": score(),
		"collected_coins": collected_coins, "merged_count": merged_count,
		"chest_count": chest_count, "generated_tiles": generated_tiles,
		"spawn_interval": spawn_interval, "spawn_elapsed": spawn_elapsed, "full_elapsed": full_elapsed,
		"full_remaining": maxf(0.0, FULL_SECONDS - full_elapsed) if full_elapsed >= 0.0 else -1.0,
		"error": error, "result": _result.duplicate(true)
	}
	state.merge(reward_progress(fragment_count), true)
	return state


func finish_round() -> Dictionary:
	if phase == "finished":
		return _result.duplicate(true)
	var generation: int = _generation
	# A persistence callback may pause after accepting payment. That accepted
	# transaction must enter the round result even when the player exits paused.
	for pending in fusions.duplicate():
		if str(pending.operation) == "collect" and bool(pending.get("credited", false)):
			_complete_operation(str(pending.attempt_id))
			if generation != _generation or phase == "finished":
				return _result.duplicate(true)
	phase = "finished"
	fusions.clear()
	_result = {"cleared_pairs": cleared_pairs, "score": score(), "coins": collected_coins, "words": []}
	_result.merge(reward_progress(fragment_count), true)
	for word in _completed_words.values():
		_result.words.append(word.duplicate(true))
	var result: Dictionary = _result.duplicate(true)
	finished.emit(result.duplicate(true))
	if generation == _generation:
		changed.emit()
	return result


func _eligible(word: Dictionary, level: int) -> bool:
	for key in ["id", "text", "image", "audio"]:
		if not word.get(key) is String or str(word[key]).strip_edges().is_empty():
			return false
	return int(word.get("min_age", 3)) == clampi(level, 3, 12) and normalize_word(str(word.text)).length() >= 2


func _parts_for_word(word: Dictionary) -> Array[String]:
	var text: String = normalize_word(str(word.text))
	var supplied: Array[String] = []
	if word.get("jelly_parts") is Array:
		for part in word.jelly_parts:
			if not part is String or str(part).is_empty():
				supplied.clear()
				break
			supplied.append(str(part).to_lower())
		if supplied.size() >= 2 and "".join(supplied) == text:
			return supplied
	var count: int = 3 if text.length() >= 7 else 2
	var parts: Array[String] = []
	var start: int = 0
	for index in range(count):
		var end: int = ceili(float(text.length()) * float(index + 1) / float(count))
		parts.append(text.substr(start, end - start))
		start = end
	return parts


func _new_tile(text: String, mass: int, fragments: int) -> Dictionary:
	var word: Dictionary = _word_lookup.get(normalize_word(text), {}) if mass > 1 else {}
	var size: Vector2i = _preferred_size(mass)
	var tile: Dictionary = {
		"id": _next_tile_id, "text": text, "mass": mass, "parts_count": mass,
		"fragments": fragments, "chest": fragments > 0,
		"word": word.duplicate(true), "kind": "word" if not word.is_empty() else "root",
		"column": 0, "row": ROWS - size.y, "width": size.x, "height": size.y,
		"age": SETTLE_SECONDS, "settling": false, "arrival": false, "falling_rows": 0
	}
	_next_tile_id += 1
	return tile


func _preferred_size(mass: int) -> Vector2i:
	if mass <= COLUMNS:
		return Vector2i(maxi(1, mass), 1)
	return Vector2i(COLUMNS, mini(ROWS, ceili(float(mass) / float(COLUMNS))))


func _fill_upcoming() -> void:
	while upcoming.size() < UPCOMING_COUNT:
		if _supply.is_empty():
			_build_supply()
		upcoming.append(_supply.pop_front())


func _build_supply() -> void:
	# Every word's ordered chunks arrive in the same bounded supply packet, so a
	# player never needs a chunk that only exists in another age's vocabulary.
	var word: Dictionary = _words[_word_index % _words.size()]
	_word_index += 1
	_supply_words += 1
	var parts: Array[String] = _parts_for_word(word)
	var marked: int = _rng.randi_range(0, parts.size() - 1) if _supply_words % 2 == 0 else -1
	for index in range(parts.size()):
		_supply.append(_new_tile(parts[index], 1, 1 if index == marked else 0))


func _spawn_drop() -> void:
	for index in range(DROP_COUNT):
		if not _spawn_tile(true):
			break


func _spawn_tile(arrival: bool) -> bool:
	if upcoming.is_empty():
		return false
	var position: Vector2i = _free_position(_occupied(), 1, 1)
	if position.x < 0:
		return false
	var tile: Dictionary = upcoming.pop_front()
	tile.column = position.x
	tile.row = position.y
	tile.age = 0.0 if arrival else SETTLE_SECONDS
	tile.settling = arrival
	tile.arrival = arrival
	tile.falling_rows = ROWS - position.y if arrival else 0
	cells.append(tile)
	generated_tiles += 1
	_fill_upcoming()
	return true


func _complete_operation(event_id: String) -> void:
	var operation_index: int = _fusion_index(event_id)
	if operation_index < 0:
		return
	var completed: Dictionary = fusions[operation_index].duplicate(true)
	if str(completed.operation) == "merge":
		fusions.remove_at(operation_index)
		_complete_merge(completed)
	else:
		var generation: int = _generation
		if not bool(completed.get("credited", false)) and credit_collection.is_valid():
			var response: Variant = credit_collection.call(event_id, int(completed.coins))
			if generation != _generation or phase != "playing" or _fusion_index(event_id) < 0:
				return
			if not response is Dictionary or not bool(response.get("ok", false)):
				fusions.remove_at(_fusion_index(event_id))
				error = "The coin reward could not be saved. Tap the word to try again."
				return
			fusions[_fusion_index(event_id)].credited = true
			completed.credited = true
			if paused:
				return
		fusions.remove_at(_fusion_index(event_id))
		error = ""
		_complete_collection(completed)


func _complete_merge(completed: Dictionary) -> void:
	var a: Dictionary = cell(int(completed.a_id))
	var b: Dictionary = cell(int(completed.b_id))
	if a.is_empty() or b.is_empty():
		return
	for index in range(cells.size() - 1, -1, -1):
		if int(cells[index].id) in [int(a.id), int(b.id)]:
			cells.remove_at(index)
	var result: Dictionary = completed.result.duplicate(true)
	# A newly joined body must land even when its packed position equals the
	# factory default. Its visible travel and input readiness share this clock.
	result.age = 0.0
	result.settling = true
	result.arrival = false
	result.falling_rows = 0
	var candidates: Array[Dictionary] = cells.duplicate(true)
	candidates.append(result)
	if not _pack(candidates):
		# A full well may lack a contiguous rectangle for the preferred growth.
		# Retain the larger input's legal footprint until later space is available;
		# logical mass, word content, fragments, and coins are never discarded.
		var anchor: Dictionary = a if int(a.width) * int(a.height) >= int(b.width) * int(b.height) else b
		result.column = int(anchor.column)
		result.row = int(anchor.row)
		result.width = int(anchor.width)
		result.height = int(anchor.height)
		cells.append(result)
	else:
		cells = candidates
	merged_count += 1
	full_elapsed = -1.0
	completed.result = cell(int(result.id))
	completed.word = completed.result.word.duplicate(true)
	var generation: int = _generation
	fusion_completed.emit(completed, 0)
	if _can_continue(generation):
		changed.emit()


func _complete_collection(completed: Dictionary) -> void:
	var index: int = _index_for_id(int(completed.a_id))
	if index < 0:
		return
	cells.remove_at(index)
	_collection_event_ids.erase(int(completed.a_id))
	var candidates: Array[Dictionary] = cells.duplicate(true)
	if _pack(candidates):
		cells = candidates
	var coins: int = int(completed.coins)
	var awarded: int = int(completed.fragments)
	cleared_pairs += 1
	collected_coins += coins
	fragment_count += awarded
	var previous_tier: int = chest_tier
	var reward: Dictionary = reward_progress(fragment_count)
	chest_tier = int(reward.chest_tier)
	chest_count = int(reward.chest_count)
	_completed_words[str(completed.word.id)] = completed.word.duplicate(true)
	spawn_interval = maxf(MIN_SPAWN_INTERVAL, INITIAL_SPAWN_INTERVAL - float(cleared_pairs) * 0.08)
	full_elapsed = -1.0
	var generation: int = _generation
	# Commit all rewards before callbacks. A callback may end or replace a round.
	collected.emit(str(completed.attempt_id), completed.word.duplicate(true), coins, awarded)
	if not _can_continue(generation):
		return
	var word_ids: Array[String] = [str(completed.word.id)]
	word_attempted.emit(str(completed.attempt_id), word_ids, true)
	if not _can_continue(generation):
		return
	if awarded > 0:
		fragments_awarded.emit(awarded)
		if not _can_continue(generation):
			return
		if chest_tier > previous_tier:
			chest_milestone.emit(previous_tier, chest_tier)
			if not _can_continue(generation):
				return
		cue_requested.emit("chest")
	if _can_continue(generation):
		changed.emit()


func _pack(tiles: Array[Dictionary]) -> bool:
	# A crowded merge may temporarily keep a smaller legal footprint. Restore
	# full growth as soon as the entire preferred layout fits, without partially
	# changing live footprints when that attempt still has too little room.
	var preferred: Array[Dictionary] = tiles.duplicate(true)
	for tile in preferred:
		var extent: Vector2i = _preferred_size(int(tile.mass))
		if int(tile.width) != extent.x or int(tile.height) != extent.y:
			tile.width = extent.x
			tile.height = extent.y
			tile.age = 0.0
			tile.settling = true
			tile.arrival = false
			tile.falling_rows = 0
	if _pack_footprints(preferred):
		for index in range(tiles.size()):
			tiles[index].merge(preferred[index], true)
		return true
	return _pack_footprints(tiles)


func _pack_footprints(tiles: Array[Dictionary]) -> bool:
	# Largest-first, bottom-left packing has a stable result across frame rates.
	# Work on copies so a failed layout never partially moves the live board.
	var ordered: Array[Dictionary] = tiles.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_area: int = int(a.width) * int(a.height)
		var b_area: int = int(b.width) * int(b.height)
		return a_area > b_area if a_area != b_area else int(a.id) < int(b.id))
	var occupied: Dictionary = {}
	var positions: Dictionary = {}
	for tile in ordered:
		var position: Vector2i = _free_position(occupied, int(tile.width), int(tile.height))
		if position.x < 0:
			return false
		positions[int(tile.id)] = position
		_occupy(occupied, position.x, position.y, int(tile.width), int(tile.height))
	for tile in tiles:
		var position: Vector2i = positions[int(tile.id)]
		if int(tile.column) != position.x or int(tile.row) != position.y:
			tile.falling_rows = maxi(0, position.y - int(tile.row))
			tile.column = position.x
			tile.row = position.y
			tile.age = 0.0
			tile.settling = true
			tile.arrival = false
	return true


func _occupied() -> Dictionary:
	var occupied: Dictionary = {}
	for tile in cells:
		_occupy(occupied, int(tile.column), int(tile.row), int(tile.width), int(tile.height))
	return occupied


func _occupy(occupied: Dictionary, column: int, row: int, width: int, height: int) -> void:
	for y in range(row, row + height):
		for x in range(column, column + width):
			occupied[y * COLUMNS + x] = true


func _free_position(occupied: Dictionary, width: int, height: int) -> Vector2i:
	for row in range(ROWS - height, -1, -1):
		for column in range(COLUMNS - width + 1):
			var clear: bool = true
			for y in range(row, row + height):
				for x in range(column, column + width):
					if occupied.has(y * COLUMNS + x):
						clear = false
						break
				if not clear:
					break
			if clear:
				return Vector2i(column, row)
	return Vector2i(-1, -1)


func _has_free_cell() -> bool:
	return _occupied().size() < CAPACITY


func _settling_remaining() -> float:
	var remaining: float = 0.0
	for tile in cells:
		remaining = maxf(remaining, SETTLE_SECONDS - float(tile.age))
	return maxf(0.0, remaining)


func _index_for_id(tile_id: int) -> int:
	for index in range(cells.size()):
		if int(cells[index].id) == tile_id:
			return index
	return -1


func _fusion_index(event_id: String) -> int:
	for index in range(fusions.size()):
		if str(fusions[index].attempt_id) == event_id:
			return index
	return -1


func _event_id(operation: String) -> String:
	var event_id: String = "word-jelly-%d-%s-%d" % [_generation, operation, _next_event_id]
	_next_event_id += 1
	return event_id


func _can_continue(generation: int) -> bool:
	return generation == _generation and phase == "playing" and not paused
