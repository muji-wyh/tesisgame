class_name WordJellyModel
extends RefCounted
## Persistent word-part jellies: merging builds a word; collecting earns it.

signal changed
signal word_attempted(attempt_id: String, word_ids: Array[String], correct: bool)
signal fusion_started(payload: Dictionary)
signal collection_started(payload: Dictionary)
signal fusion_completed(payload: Dictionary, awarded: int)
signal collected(event_id: String, word: Dictionary, coins: int, fragments: int)
signal cue_requested(cue: String)
signal fragments_awarded(count: int)
signal chest_milestone(previous_tier: int, new_tier: int)
signal finished(result: Dictionary)
signal powerup_feedback(kind: String, success: bool)
signal powerup_drag_started(payload: Dictionary)
signal powerup_fragment_arrived(payload: Dictionary)

const RewardProgress = preload("res://scripts/jelly_reward_progress.gd")
const Motion = preload("res://scripts/jelly_motion.gd")
const WordSampler = preload("res://scripts/word_sampler.gd")
const CoinEconomy = preload("res://scripts/coin_economy.gd")
const COLUMNS: int = 6
const ROWS: int = 8
const CAPACITY: int = COLUMNS * ROWS
const INITIAL_SETTLED_TILES: int = COLUMNS * 3
const DROP_COUNT: int = 6
const UPCOMING_COUNT: int = 6
const SETTLE_SECONDS: float = 0.36
const ARRIVAL_STAGGER: float = 0.15
const ARRIVAL_ORDER: Array[int] = [0, 3, 1, 4, 2, 5]
const FUSION_SECONDS: float = 0.76
const SPLIT_SECONDS: float = 0.45
const COLLECT_SECONDS: float = 0.42
const POP_SECONDS: float = 0.18
const BATCH_BEAT_SECONDS: float = 0.10
const BATCH_POP_SECONDS: float = 0.06
const COIN_DROP_CHANCE: float = CoinEconomy.JELLY_BONUS_CHANCE
const INITIAL_SPAWN_INTERVAL: float = 20.0
const MIN_SPAWN_INTERVAL: float = 16.0
const FULL_SECONDS: float = 10.0
const CHEST_UNLOCK_FRAGMENTS: int = RewardProgress.CHEST_UNLOCK_FRAGMENTS
const CHEST_UPGRADE_FRAGMENTS: int = RewardProgress.CHEST_UPGRADE_FRAGMENTS
const EPSILON: float = 0.000001
const POWERUP_PRICES: Dictionary = CoinEconomy.POWERUP_BASE_PRICES
const POWERUP_MERGE_BEAT_SECONDS: float = 0.2
const POWERUP_DRAG_SECONDS: float = 0.3
const POWERUP_FRAGMENT_FLIGHT: float = 0.42
const POWERUP_FRAGMENT_STAGGER: float = 0.18
const POWERUP_FRAGMENT_RECOVERY: float = 0.35

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
var purchase_powerup: Callable

var _words: Array[Dictionary] = []
var _word_lookup: Dictionary = {}
var _supply: Array[Dictionary] = []
var _supply_pending: Array[Dictionary] = []
var _completed_words: Dictionary = {}
var _result: Dictionary = {}
var _word_counts: Dictionary = {}
var _word_service: Dictionary = {}
var practice_weight_for: Callable
var _supply_words: int = 0
var _next_tile_id: int = 1
var _next_event_id: int = 1
var _collection_event_ids: Dictionary = {}
var _collection_coin_rewards: Dictionary = {}
var _merge_history: Dictionary = {}
var _generation: int = 0
var _growth_pending: bool = false
var _gravity_pending: bool = false
var _held_tile_id: int = -1
var _dragged_tile_id: int = -1
var _collection_batch_active: bool = false
var _collection_batch_ids: Array[int] = []
var _collection_batch_cursor: int = 0
var _collection_batch_started: int = 0
var _collection_batch_completed: int = 0
var _collection_batch_skipped: int = 0
var _collection_batch_elapsed: float = 0.0
var _collection_batch_next_in: float = 0.0
var _collection_batch_event_id: String = ""
var _collection_batch_serial: int = 0
var _rng := RandomNumberGenerator.new()
var _coin_rng := RandomNumberGenerator.new()
var _powerup: Dictionary = {}
var _powerup_uses: Dictionary = {"auto_merge": 0, "fragments": 0}
var _powerup_ids: Array[int] = []
var _powerup_purchasing: bool = false
var _powerup_committing: bool = false
var _finishing_powerup: bool = false
var _finish_after_purchase: bool = false
var _settle_after_purchase: bool = false


func configure(words: Array, level: int, seed_value: int = -1) -> bool:
	if _powerup_purchasing or _finishing_powerup:
		return false
	var previous_generation: int = _generation
	finish_powerup()
	if previous_generation != _generation:
		return false
	_generation += 1
	cells.clear()
	upcoming.clear()
	fusions.clear()
	_words.clear()
	_word_lookup.clear()
	_supply.clear()
	_supply_pending.clear()
	_completed_words.clear()
	_collection_event_ids.clear()
	_collection_coin_rewards.clear()
	_merge_history.clear()
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
	_word_counts.clear()
	_word_service.clear()
	_supply_words = 0
	_next_tile_id = 1
	_next_event_id = 1
	_growth_pending = false
	_gravity_pending = false
	_held_tile_id = -1
	_dragged_tile_id = -1
	_reset_collection_batch()
	_powerup.clear()
	_powerup_ids.clear()
	_finish_after_purchase = false
	_settle_after_purchase = false
	error = ""
	if seed_value < 0:
		_rng.randomize()
		_coin_rng.randomize()
	else:
		_rng.seed = seed_value
		# Coin rolls must not alter word supply, fragments, or automatic matching.
		_coin_rng.seed = seed_value ^ 0x434F494E
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
	_powerup_uses = {"auto_merge": 0, "fragments": 0}
	phase = "playing"
	_fill_upcoming()
	for index in range(INITIAL_SETTLED_TILES):
		_spawn_tile(false)
	changed.emit()
	return true


static func normalize_word(value: String) -> String:
	var pieces: PackedStringArray = value.strip_edges().to_lower().replace("\t", " ").replace("\n", " ").split(" ", false)
	return " ".join(pieces)


func powerup_active() -> bool:
	return _powerup_purchasing or bool(_powerup.get("active", false))


func powerup_price(kind: String) -> int:
	return CoinEconomy.powerup_price(kind, int(_powerup_uses.get(kind, 0)))


func powerup_snapshot() -> Dictionary:
	return _powerup.duplicate(true) if not _powerup.is_empty() else {
		"active": false, "kind": "", "receipt_id": "", "stage": "", "elapsed": 0.0,
		"duration": 0.0, "source_id": -1, "target_id": -1, "source": {}, "target": {},
		"completed": 0, "total": 0, "arrivals": [], "drags": [], "clock": 0.0,
		"started_at": 0.0, "next_launch_at": 0.0, "contact_played": false, "contact_pending": false}


func can_activate_powerup(kind: String) -> bool:
	if not POWERUP_PRICES.has(kind) or phase != "playing" or paused or powerup_active() \
		or _finishing_powerup or collection_batch_active() or _held_tile_id >= 0 \
		or not fusions.is_empty() or _settling_remaining() > EPSILON or cells.is_empty():
		return false
	return kind == "fragments" or not _powerup_pair(false).is_empty()


func activate_powerup(kind: String) -> bool:
	if not can_activate_powerup(kind):
		return false
	var generation: int = _generation
	var receipt_id: String = _event_id("powerup-" + kind)
	var price: int = powerup_price(kind)
	# Lock the board while persistence runs, including reentrant lifecycle calls.
	_powerup_purchasing = true
	var response: Variant = purchase_powerup.call(receipt_id, kind, price) if purchase_powerup.is_valid() else {}
	_powerup_purchasing = false
	if generation != _generation:
		return false
	if not response is Dictionary or not bool(response.get("ok", false)) or bool(response.get("duplicate", false)):
		_settle_after_purchase = false
		powerup_feedback.emit(kind, false)
		if generation == _generation and not powerup_active():
			cue_requested.emit("powerup_wrong")
		if _finish_after_purchase and generation == _generation:
			_finish_after_purchase = false
			finish_round()
		return false
	# Commit the next price before feedback or lifecycle callbacks can reenter.
	_powerup_uses[kind] = int(_powerup_uses.get(kind, 0)) + 1
	_powerup_ids.clear()
	for tile: Dictionary in cells:
		_powerup_ids.append(int(tile.id))
	_powerup = {"active": true, "kind": kind, "receipt_id": receipt_id, "stage": "ready",
		"elapsed": 0.0, "duration": 0.0, "source_id": -1, "target_id": -1,
		"source": {}, "target": {}, "completed": 0, "total": 0, "arrivals": [], "drags": [],
		"clock": 0.0, "started_at": 0.0, "next_launch_at": 0.0, "contact_played": false, "contact_pending": false}
	if kind == "fragments":
		_prepare_powerup_fragments()
	# The paid obligation exists before any user callback may pause or leave.
	if _settle_after_purchase or _finish_after_purchase:
		_settle_after_purchase = false
		finish_powerup()
		if _finish_after_purchase:
			_finish_after_purchase = false
			finish_round()
		return true
	powerup_feedback.emit(kind, true)
	if not _same_powerup(generation, receipt_id):
		return true
	if not paused:
		cue_requested.emit("powerup_success")
	if _same_powerup(generation, receipt_id) and not paused:
		_advance_powerup()
	if generation == _generation:
		changed.emit()
	return true


func finish_powerup(silent: bool = true) -> void:
	if _powerup_purchasing:
		_settle_after_purchase = true
		return
	if not powerup_active() or _finishing_powerup:
		return
	var was_paused: bool = paused
	var was_blocked: bool = is_blocking_signals()
	var generation: int = _generation
	_finishing_powerup = true
	if silent:
		set_block_signals(true)
	paused = false
	# Every merge reduces the captured set. This bounded drain also completes
	# the normal fusion, gravity and settlement without collecting any word.
	for boundary in range(CAPACITY * (ROWS + 6)):
		if not powerup_active() or generation != _generation:
			break
		step(10.0)
	paused = was_paused
	_finishing_powerup = false
	set_block_signals(was_blocked)
	if generation == _generation:
		changed.emit()


func _same_powerup(generation: int, receipt_id: String) -> bool:
	return generation == _generation and bool(_powerup.get("active", false)) \
		and str(_powerup.get("receipt_id", "")) == receipt_id


func _powerup_pair(captured_only: bool = true, random_source: bool = false) -> Array[int]:
	var candidates: Array = []
	for source: Dictionary in cells:
		if (captured_only and not _powerup_ids.has(int(source.id))) or not is_settled(source) \
			or is_fusing(int(source.id)) or _reserved_for_powerup(int(source.id)):
			continue
		for target: Dictionary in cells:
			if int(source.id) == int(target.id) or (captured_only and not _powerup_ids.has(int(target.id))) or not is_settled(target) \
				or is_fusing(int(target.id)) or _reserved_for_powerup(int(target.id)):
				continue
			if _word_lookup.has(normalize_word(str(source.text) + str(target.text))):
				if not random_source:
					return [int(source.id), int(target.id)]
				# Each eligible source appears once, regardless of how many targets
				# it can use. Availability checks never consume the seeded RNG.
				candidates.append([int(source.id), int(target.id)])
				break
	var pair: Array[int] = []
	if not candidates.is_empty():
		pair.assign(candidates[_rng.randi_range(0, candidates.size() - 1)])
	return pair


func _reserved_for_powerup(tile_id: int) -> bool:
	if not bool(_powerup.get("active", false)) or str(_powerup.get("kind", "")) != "auto_merge":
		return false
	for drag: Dictionary in _powerup.drags:
		if tile_id in [int(drag.source_id), int(drag.target_id)]:
			return true
	return false


func _sync_powerup_drag() -> void:
	# Legacy consumers follow the oldest drag; the full array owns every live
	# reservation and keeps each overlapping journey on its independent clock.
	if not _powerup.drags.is_empty():
		var drag: Dictionary = _powerup.drags[0]
		_powerup.stage = "drag"
		for key: String in ["source_id", "target_id", "source", "target", "elapsed", "duration", "started_at", "contact_played", "contact_pending"]:
			_powerup[key] = drag[key]
		_held_tile_id = int(drag.source_id)
	else:
		_powerup.source_id = -1
		_powerup.target_id = -1
		_powerup.source = {}
		_powerup.target = {}
		_powerup.contact_played = false
		_powerup.contact_pending = false
		_held_tile_id = -1


func _prepare_powerup_fragments() -> void:
	var total: int = _rng.randi_range(CoinEconomy.TREASURE_FRAGMENT_MIN, CoinEconomy.TREASURE_FRAGMENT_MAX)
	var pending_counts: Dictionary = {}
	for tile: Dictionary in cells:
		pending_counts[int(tile.id)] = int(tile.fragments)
	for index in range(total):
		var candidates: Array[int] = []
		for id: int in _powerup_ids:
			if int(pending_counts[id]) == 0:
				candidates.append(id)
		if candidates.is_empty():
			candidates = _powerup_ids.duplicate()
		var id: int = candidates[_rng.randi_range(0, candidates.size() - 1)]
		pending_counts[id] = int(pending_counts[id]) + 1
		_powerup.arrivals.append({"tile_id": id, "index": index, "at": POWERUP_FRAGMENT_FLIGHT + index * POWERUP_FRAGMENT_STAGGER, "arrived": false})
	_powerup.stage = "arrivals"
	_powerup.total = total
	_powerup.duration = POWERUP_FRAGMENT_FLIGHT + (total - 1) * POWERUP_FRAGMENT_STAGGER + POWERUP_FRAGMENT_RECOVERY


func _advance_powerup() -> void:
	if not bool(_powerup.get("active", false)) or paused or phase != "playing":
		return
	var generation: int = _generation
	var receipt_id: String = str(_powerup.receipt_id)
	if str(_powerup.kind) == "fragments":
		for arrival: Dictionary in _powerup.arrivals:
			if bool(arrival.arrived) or float(_powerup.elapsed) + EPSILON < float(arrival.at):
				continue
			arrival.arrived = true
			var index: int = _index_for_id(int(arrival.tile_id))
			if index < 0:
				continue
			_grant_powerup_fragment(cells[index])
			_powerup.completed = int(_powerup.completed) + 1
			powerup_fragment_arrived.emit({"tile_id": int(arrival.tile_id), "index": int(arrival.index),
				"total": int(_powerup.total), "fragments": int(cells[index].fragments), "receipt_id": receipt_id})
			if not _same_powerup(generation, receipt_id) or paused:
				return
			cue_requested.emit("powerup_fragment")
			if not _same_powerup(generation, receipt_id) or paused:
				return
		if float(_powerup.elapsed) + EPSILON >= float(_powerup.duration):
			_complete_powerup()
		return
	for drag: Dictionary in _powerup.drags.duplicate():
		if float(drag.elapsed) + EPSILON < float(drag.duration):
			continue
		# Keep both endpoints reserved if an audio callback pauses the round.
		# Resume the same arrival without replaying its contact cue.
		if not bool(drag.contact_played):
			drag.contact_pending = true
			drag.contact_played = true
			_sync_powerup_drag()
			cue_requested.emit("contact")
			if not _same_powerup(generation, receipt_id) or paused:
				return
		# A callback can drain this same paid obligation. Do not commit an
		# arrival again after that nested advance already transferred it.
		if not _powerup.drags.has(drag):
			continue
		drag.contact_pending = false
		_powerup.drags.erase(drag)
		_powerup.stage = "fusion"
		_sync_powerup_drag()
		_powerup_committing = true
		try_merge(int(drag.source_id), int(drag.target_id), true)
		_powerup_committing = false
		if not _same_powerup(generation, receipt_id) or paused:
			return
	# Launches and arrivals have separate boundaries: a new 300 ms journey
	# begins every 200 ms while earlier drags and fusions remain in flight.
	var launch_ready: bool = float(_powerup.clock) + EPSILON >= float(_powerup.next_launch_at)
	var pair: Array[int] = _powerup_pair(true, launch_ready)
	if not pair.is_empty() and launch_ready:
		var drag: Dictionary = {"source_id": pair[0], "target_id": pair[1],
			"source": cell(pair[0]), "target": cell(pair[1]), "elapsed": 0.0,
			"duration": POWERUP_DRAG_SECONDS, "started_at": float(_powerup.clock),
			"contact_played": false, "contact_pending": false}
		_powerup.drags.append(drag)
		_powerup.next_launch_at = float(_powerup.clock) + POWERUP_MERGE_BEAT_SECONDS
		_powerup.total = int(_powerup.total) + 1
		_sync_powerup_drag()
		var payload: Dictionary = powerup_snapshot()
		# The event identifies the new launch even when an older drag still
		# represents the snapshot. Consumers can animate all entries in drags.
		payload.merge(drag.duplicate(true), true)
		powerup_drag_started.emit(payload)
		if _same_powerup(generation, receipt_id) and not paused:
			cue_requested.emit("pick")
		return
	_sync_powerup_drag()
	if not _powerup.drags.is_empty():
		return
	if pair.is_empty():
		if not fusions.is_empty():
			_powerup.stage = "fusion"
			_powerup.elapsed = float(fusions[0].elapsed)
			_powerup.duration = float(fusions[0].duration)
			return
		if _settling_remaining() > EPSILON:
			if str(_powerup.stage) != "settling":
				_powerup.stage = "settling"
				_powerup.elapsed = 0.0
			_powerup.duration = float(_powerup.elapsed) + _settling_remaining()
			return
		_complete_powerup()
		return
	# A newly available pair can wait for the remaining beat. Missed beats
	# never accumulate: the next deadline is based on the actual launch time.
	_powerup.stage = "ready"
	_powerup.elapsed = 0.0
	_powerup.duration = maxf(0.0, float(_powerup.next_launch_at) - float(_powerup.clock))


func _powerup_boundary() -> float:
	if not bool(_powerup.get("active", false)):
		return INF
	if str(_powerup.kind) == "fragments":
		for arrival: Dictionary in _powerup.arrivals:
			if not bool(arrival.arrived):
				return maxf(0.0, float(arrival.at) - float(_powerup.elapsed))
		return maxf(0.0, float(_powerup.duration) - float(_powerup.elapsed))
	var boundary: float = INF
	for drag: Dictionary in _powerup.drags:
		boundary = minf(boundary, maxf(0.0, float(drag.duration) - float(drag.elapsed)))
	var launch_in: float = float(_powerup.next_launch_at) - float(_powerup.clock)
	if launch_in > EPSILON:
		boundary = minf(boundary, launch_in)
	var settlement: float = _next_settlement()
	if settlement > EPSILON:
		boundary = minf(boundary, settlement)
	return boundary


func _complete_powerup() -> void:
	_powerup.active = false
	_powerup.stage = "complete"
	_powerup.source_id = -1
	_powerup.target_id = -1
	_powerup.source = {}
	_powerup.target = {}
	_powerup.drags.clear()
	_powerup.contact_played = false
	_powerup.contact_pending = false
	_held_tile_id = -1
	_powerup_ids.clear()


func _grant_powerup_fragment(tile: Dictionary) -> void:
	tile.fragments = int(tile.fragments) + 1
	tile.chest = true
	# A historical merged body may later split repeatedly. Store each new
	# marker in one descendant at every level so no split loses or copies it.
	var descendants: Array = _merge_history.get(int(tile.id), [])
	if not descendants.is_empty():
		var selected: Dictionary = descendants[0]
		for child: Dictionary in descendants:
			if int(child.fragments) < int(selected.fragments):
				selected = child
		_grant_powerup_fragment(selected)


func try_merge(a_id: int, b_id: int, held_source: bool = false) -> String:
	if phase != "playing" or paused or collection_batch_active() or (powerup_active() and not _powerup_committing) or a_id == b_id or is_fusing(a_id) or is_fusing(b_id):
		return "ignored"
	# The internal authorization is consumed before emitting any callbacks.
	_powerup_committing = false
	var a: Dictionary = cell(a_id)
	var b: Dictionary = cell(b_id)
	if a.is_empty() or b.is_empty() or (not held_source and not is_settled(a)) or not is_settled(b) or is_lifted(b_id):
		return "ignored"
	# Only the dragged prefix followed by this target may form the current word.
	# Reject before allocating IDs or reserving either body.
	if not _word_lookup.has(normalize_word(str(a.text) + str(b.text))):
		cue_requested.emit("wrong")
		return "wrong"
	var mass: int = int(a.mass) + int(b.mass)
	var result: Dictionary = _new_tile(str(a.text) + str(b.text), mass, int(a.fragments) + int(b.fragments))
	result.skin = int(b.get("skin", b.id))
	var position: Vector2i = _position_near(_occupied([a_id, b_id]), int(result.width), int(result.height), b)
	if position.x < 0:
		# Keep a crowded merge at its destination until room for growth opens up.
		result.width = int(b.width)
		result.height = int(b.height)
		position = Vector2i(int(b.column), int(b.row))
	result.column = position.x
	result.row = position.y
	var active: Dictionary = {
		"operation": "merge", "a_id": a_id, "b_id": b_id,
		"a": a.duplicate(true), "b": b.duplicate(true), "result": result,
		"word": result.word.duplicate(true), "attempt_id": _event_id("merge"),
		"elapsed": 0.0, "duration": FUSION_SECONDS, "pop_at": FUSION_SECONDS,
		"popped": false
	}
	fusions.append(active)
	if _dragged_tile_id == a_id:
		# The accepted fusion owns the airborne source from this point onward.
		_dragged_tile_id = -1
	var generation: int = _generation
	fusion_started.emit(active.duplicate(true))
	if _can_continue(generation) and _fusion_index(str(active.attempt_id)) >= 0:
		cue_requested.emit("merge")
		if _can_continue(generation):
			changed.emit()
	return "merged"


func can_split(tile: Dictionary) -> bool:
	return int(tile.get("mass", 0)) > 1 and not is_valid_word(tile) \
		and _merge_history.has(int(tile.get("id", -1)))


func split(tile_id: int) -> bool:
	if phase != "playing" or paused or powerup_active() or collection_batch_active() or is_fusing(tile_id):
		return false
	var parent: Dictionary = cell(tile_id)
	if not is_settled(parent) or not can_split(parent) or is_lifted(tile_id):
		return false
	var results: Array[Dictionary] = _split_placements(parent)
	if results.size() != 2:
		return false
	var active: Dictionary = {
		"operation": "split", "a_id": tile_id, "b_id": tile_id,
		"a": parent.duplicate(true), "b": parent.duplicate(true), "result": {},
		"results": results, "word": {}, "attempt_id": _event_id("split"),
		"elapsed": 0.0, "duration": SPLIT_SECONDS, "pop_at": SPLIT_SECONDS,
		"popped": false
	}
	fusions.append(active)
	var generation: int = _generation
	fusion_started.emit(active.duplicate(true))
	if _can_continue(generation) and _fusion_index(str(active.attempt_id)) >= 0:
		cue_requested.emit("release")
		if _can_continue(generation):
			changed.emit()
	return true


func collect(tile_id: int) -> bool:
	if powerup_active() or collection_batch_active():
		return false
	return _begin_collection(tile_id)


func _begin_collection(tile_id: int, batch_index: int = 0) -> bool:
	if phase != "playing" or paused or powerup_active() or is_fusing(tile_id):
		return false
	var tile: Dictionary = cell(tile_id)
	if tile.is_empty() or not is_settled(tile) or not is_valid_word(tile) or is_lifted(tile_id):
		return false
	if not _collection_event_ids.has(tile_id):
		_collection_event_ids[tile_id] = _event_id("collect")
		# Reserve one independent roll per collection, including wallet retries.
		_collection_coin_rewards[_collection_event_ids[tile_id]] = coins_for_tile(tile) if _coin_rng.randf() < COIN_DROP_CHANCE else 0
	var active: Dictionary = {
		"operation": "collect", "a_id": tile_id, "b_id": tile_id,
		"a": tile.duplicate(true), "b": tile.duplicate(true), "result": {},
		"word": tile.word.duplicate(true), "attempt_id": str(_collection_event_ids[tile_id]),
		"coins": int(_collection_coin_rewards[_collection_event_ids[tile_id]]), "fragments": int(tile.fragments),
		"elapsed": 0.0, "duration": BATCH_BEAT_SECONDS if batch_index > 0 else COLLECT_SECONDS,
		"pop_at": BATCH_POP_SECONDS if batch_index > 0 else POP_SECONDS,
		"popped": false, "credited": false,
		"batch": batch_index > 0, "batch_index": batch_index,
		"batch_total": _collection_batch_ids.size() if batch_index > 0 else 0,
		"batch_id": _collection_batch_serial if batch_index > 0 else 0
	}
	fusions.append(active)
	if batch_index > 0:
		_collection_batch_event_id = str(active.attempt_id)
		_collection_batch_started += 1
		_collection_batch_next_in = BATCH_BEAT_SECONDS
	var generation: int = _generation
	fusion_started.emit(active.duplicate(true))
	if _can_continue(generation) and _fusion_index(str(active.attempt_id)) >= 0:
		collection_started.emit(active.duplicate(true))
	if _can_continue(generation):
		changed.emit()
	return true


func collectable_ids() -> Array[int]:
	var candidates: Array[Dictionary] = []
	if phase != "playing":
		return []
	for tile: Dictionary in cells:
		if is_valid_word(tile) and not is_fusing(int(tile.id)) and int(tile.id) != _held_tile_id:
			candidates.append(tile)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.row) != int(b.row):
			return int(a.row) < int(b.row)
		return int(a.column) < int(b.column) if a.column != b.column else int(a.id) < int(b.id))
	var ids: Array[int] = []
	var row_ids: Array[int] = []
	var last_row: int = -1
	var reverse_row: bool = false
	for tile: Dictionary in candidates:
		if int(tile.row) != last_row and not row_ids.is_empty():
			if reverse_row:
				row_ids.reverse()
			ids.append_array(row_ids)
			row_ids.clear()
			reverse_row = not reverse_row
		last_row = int(tile.row)
		row_ids.append(int(tile.id))
	if reverse_row:
		row_ids.reverse()
	ids.append_array(row_ids)
	return ids


func collection_batch_active() -> bool:
	return _collection_batch_active


func collection_batch_snapshot() -> Dictionary:
	return {
		"active": collection_batch_active(), "total": _collection_batch_ids.size(),
		"started": _collection_batch_started, "completed": _collection_batch_completed,
		"skipped": _collection_batch_skipped,
		"remaining": _collection_batch_ids.size() - _collection_batch_cursor + (1 if not _collection_batch_event_id.is_empty() else 0) if collection_batch_active() else 0,
		"elapsed": _collection_batch_elapsed, "next_in": _collection_batch_next_in,
		"ids": _collection_batch_ids.duplicate()
	}


func start_collection_batch() -> bool:
	if phase != "playing" or paused or powerup_active() or collection_batch_active() or _held_tile_id >= 0:
		return false
	var ids: Array[int] = collectable_ids()
	if ids.is_empty():
		return false
	_reset_collection_batch()
	_collection_batch_ids = ids
	_collection_batch_active = true
	var generation: int = _generation
	_advance_collection_batch()
	if generation == _generation:
		changed.emit()
	return true


func cancel_collection_batch() -> void:
	if not collection_batch_active():
		return
	_collection_batch_active = false
	_collection_batch_next_in = 0.0
	# An already-started collection keeps its normal transaction boundary.
	changed.emit()


func _reset_collection_batch() -> void:
	_collection_batch_active = false
	_collection_batch_ids.clear()
	_collection_batch_cursor = 0
	_collection_batch_started = 0
	_collection_batch_completed = 0
	_collection_batch_skipped = 0
	_collection_batch_elapsed = 0.0
	_collection_batch_next_in = 0.0
	_collection_batch_event_id = ""
	_collection_batch_serial += 1


func _advance_collection_batch() -> void:
	if not collection_batch_active() or phase != "playing" or paused:
		return
	# Let existing motion finish once, then keep the captured bodies in place
	# so later gravity or growth cannot stretch the 100 ms collection beat.
	if _collection_batch_started == 0 and _collection_batch_settling_remaining() > EPSILON:
		return
	# A manual collection started before the button was pressed can finish,
	# but the batch never overlaps two collection animations or transactions.
	for active: Dictionary in fusions:
		if str(active.operation) == "collect":
			return
	if _collection_batch_cursor >= _collection_batch_ids.size():
		_collection_batch_active = false
		_collection_batch_next_in = 0.0
		return
	if _collection_batch_next_in > EPSILON:
		return
	while _collection_batch_cursor < _collection_batch_ids.size():
		var tile_id: int = _collection_batch_ids[_collection_batch_cursor]
		var tile: Dictionary = cell(tile_id)
		if tile.is_empty() or not is_valid_word(tile) or is_fusing(tile_id):
			_collection_batch_cursor += 1
			_collection_batch_skipped += 1
			continue
		if not is_settled(tile) or tile_id == _held_tile_id:
			return
		_collection_batch_cursor += 1
		_begin_collection(tile_id, _collection_batch_cursor)
		return
	_collection_batch_active = false
	_collection_batch_next_in = 0.0


func _collection_batch_boundary() -> float:
	if not collection_batch_active():
		return INF
	if _collection_batch_started == 0:
		var settling: float = _collection_batch_settling_remaining()
		if settling > EPSILON:
			return settling
	if _collection_batch_next_in > EPSILON:
		return _collection_batch_next_in
	if _collection_batch_cursor < _collection_batch_ids.size():
		var tile: Dictionary = cell(_collection_batch_ids[_collection_batch_cursor])
		if not tile.is_empty() and not is_settled(tile):
			return maxf(0.0, settle_duration(tile) - float(tile.age))
	return INF


func _collection_batch_settling_remaining() -> float:
	var remaining: float = 0.0
	for tile_id: int in _collection_batch_ids:
		var tile: Dictionary = cell(tile_id)
		if not tile.is_empty():
			remaining = maxf(remaining, settle_duration(tile) - float(tile.age))
	return remaining


func _reserved_for_collection(tile_id: int) -> bool:
	return collection_batch_active() and _collection_batch_ids.has(tile_id)


func step(delta: float) -> void:
	if phase != "playing" or paused or _powerup_purchasing or not is_finite(delta) or delta <= 0.0:
		return
	var generation: int = _generation
	var remaining: float = delta
	while remaining > EPSILON and _can_continue(generation):
		_resume_pending_motion()
		_advance_collection_batch()
		_advance_powerup()
		if not _can_continue(generation):
			break
		if _finishing_powerup and not powerup_active():
			break
		var powerup_running: bool = powerup_active()
		var consumed: float = remaining
		consumed = minf(consumed, _collection_batch_boundary())
		consumed = minf(consumed, _powerup_boundary())
		if _growth_pending and _settling_remaining() > EPSILON:
			consumed = minf(consumed, _settling_remaining())
		if _gravity_pending and _next_settlement() > EPSILON:
			consumed = minf(consumed, _next_settlement())
		for active in fusions:
			var boundary: float = float(active.duration)
			if str(active.operation) == "collect" and not bool(active.popped):
				boundary = float(active.pop_at)
			consumed = minf(consumed, maxf(0.0, boundary - float(active.elapsed)))
		var full: bool = not _has_free_cell()
		var danger_running: bool = full and full_elapsed >= 0.0 and not powerup_running
		var next_second: float = minf(FULL_SECONDS, floorf(full_elapsed + EPSILON) + 1.0)
		if danger_running:
			consumed = minf(consumed, maxf(0.0, next_second - full_elapsed))
		elif full and not powerup_running:
			consumed = minf(consumed, maxf(0.0, _settling_remaining()))
		elif not powerup_running:
			consumed = minf(consumed, maxf(0.0, spawn_interval - spawn_elapsed))
		for tile in cells:
			tile.age = float(tile.age) + consumed
			tile.settling = float(tile.age) + EPSILON < settle_duration(tile)
		for active in fusions:
			active.elapsed = float(active.elapsed) + consumed
		if powerup_running:
			_powerup.elapsed = float(_powerup.elapsed) + consumed
			_powerup.clock = float(_powerup.clock) + consumed
			if str(_powerup.kind) == "auto_merge":
				for drag: Dictionary in _powerup.drags:
					drag.elapsed = minf(float(drag.duration), float(drag.elapsed) + consumed)
				_sync_powerup_drag()
		if collection_batch_active():
			_collection_batch_elapsed += consumed
			_collection_batch_next_in = maxf(0.0, _collection_batch_next_in - consumed)
		if danger_running:
			full_elapsed += consumed
		elif not full and not powerup_running:
			spawn_elapsed += consumed
		remaining -= consumed
		for active in fusions.duplicate():
			if not _can_continue(generation):
				break
			if _fusion_index(str(active.attempt_id)) < 0:
				continue
			if str(active.operation) == "collect" and not bool(active.popped) and float(active.elapsed) + EPSILON >= float(active.pop_at):
				active.popped = true
				cue_requested.emit("pop")
				if not _can_continue(generation):
					break
			if float(active.elapsed) + EPSILON >= float(active.duration):
				_complete_operation(str(active.attempt_id))
		if not _can_continue(generation):
			break
		_resume_pending_motion()
		_advance_collection_batch()
		_advance_powerup()
		if not _can_continue(generation):
			break
		if powerup_running:
			if _finishing_powerup and not powerup_active():
				break
			continue
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
		if not paused:
			_resume_pending_motion()
		changed.emit()


func set_held_tile(tile_id: int = -1) -> void:
	if powerup_active() or (collection_batch_active() and tile_id >= 0):
		return
	var held_id: int = tile_id if _index_for_id(tile_id) >= 0 else -1
	if _held_tile_id == held_id:
		return
	if _dragged_tile_id >= 0 and _dragged_tile_id != held_id:
		_restore_dragged_tile()
	if _held_tile_id >= 0 and not is_fusing(_held_tile_id):
		# Even an unchanged release must reconsider support beneath its old anchor.
		# An accepted operation owns its own support change after it commits.
		_gravity_pending = true
	_held_tile_id = held_id
	_resume_pending_motion()
	changed.emit()


func begin_drag(tile_id: int) -> bool:
	if phase != "playing" or paused or powerup_active() or collection_batch_active() \
		or tile_id != _held_tile_id or is_fusing(tile_id):
		return false
	if _dragged_tile_id == tile_id:
		return true
	var index: int = _index_for_id(tile_id)
	if index < 0 or _dragged_tile_id >= 0 or not is_settled(cells[index]):
		return false
	var source: Dictionary = cells[index]
	var removed_support: bool = false
	for tile: Dictionary in cells:
		if int(tile.id) == tile_id or bool(tile.get("lifted", false)):
			continue
		if int(tile.row) + int(tile.height) == int(source.row) \
			and int(tile.column) < int(source.column) + int(source.width) \
			and int(source.column) < int(tile.column) + int(tile.width):
			removed_support = true
			break
	_dragged_tile_id = tile_id
	source.lifted = true
	if removed_support:
		_gravity_pending = true
		_resume_pending_motion()
	changed.emit()
	return true


func is_lifted(tile_id: int) -> bool:
	var index: int = _index_for_id(tile_id)
	return index >= 0 and bool(cells[index].get("lifted", false))


func _restore_dragged_tile() -> void:
	var index: int = _index_for_id(_dragged_tile_id)
	if index < 0 or is_fusing(_dragged_tile_id):
		_dragged_tile_id = -1
		return
	var tile: Dictionary = cells[index]
	var occupied: Dictionary = _occupied([_dragged_tile_id], false)
	var extent := Vector2i(int(tile.width), int(tile.height))
	var original_extent: Vector2i = extent
	var position: Vector2i = _drag_return_position(occupied, extent.x, extent.y, tile)
	if position.x < 0:
		# Retain as much of the original body as possible if falling stacks have
		# fragmented its old space. Mass, word data and ancestry remain intact.
		var best_area: int = 0
		for height in range(1, original_extent.y + 1):
			for width in range(1, original_extent.x + 1):
				if width * height <= best_area:
					continue
				var candidate: Vector2i = _drag_return_position(occupied, width, height, tile)
				if candidate.x >= 0:
					best_area = width * height
					position = candidate
					extent = Vector2i(width, height)
		if position.x < 0:
			return
		if extent.x != int(tile.width) or extent.y != int(tile.height):
			tile.placement_locked = false
	tile.column = position.x
	tile.row = position.y
	tile.width = extent.x
	tile.height = extent.y
	tile.lifted = false
	tile.age = SETTLE_SECONDS
	tile.settling = false
	tile.arrival = false
	tile.falling = false
	tile.falling_rows = 0
	_dragged_tile_id = -1
	_growth_pending = true
	_gravity_pending = true


func _drag_return_position(occupied: Dictionary, width: int, height: int, anchor: Dictionary) -> Vector2i:
	var center := Vector2(float(anchor.column) + float(anchor.width) * 0.5,
		float(anchor.row) + float(anchor.height) * 0.5)
	var nearest := Vector2i(-1, -1)
	var distance: float = INF
	for row in range(ROWS - height, -1, -1):
		for column in range(COLUMNS - width + 1):
			var candidate := Vector2(column + width * 0.5, row + height * 0.5)
			var candidate_distance: float = center.distance_squared_to(candidate)
			if candidate_distance < distance and _fits(occupied, column, row, width, height):
				nearest = Vector2i(column, row)
				distance = candidate_distance
	return nearest


func can_reposition(tile_id: int, column: int, row: int) -> bool:
	if phase != "playing" or paused or powerup_active() or collection_batch_active() or is_fusing(tile_id):
		return false
	var tile: Dictionary = cell(tile_id)
	if tile.is_empty() or (tile_id != _held_tile_id and not is_settled(tile)):
		return false
	if column == int(tile.column) and row == int(tile.row) and not is_lifted(tile_id):
		return false
	var width: int = int(tile.width)
	var height: int = int(tile.height)
	if column < 0 or row < 0 or column + width > COLUMNS or row + height > ROWS:
		return false
	return _fits(_occupied([tile_id]), column, row, width, height)


func reposition(tile_id: int, column: int, row: int) -> bool:
	if not can_reposition(tile_id, column, row):
		return false
	var tile: Dictionary = cells[_index_for_id(tile_id)]
	var changed_position: bool = column != int(tile.column) or row != int(tile.row)
	tile.column = column
	tile.row = row
	# This preserves the chosen footprint during later automatic growth only;
	# it never exempts a manually placed body from gravity.
	if changed_position:
		tile.placement_locked = true
	# Make this release eligible for the support pass immediately, without a
	# floating handover wobble before the actual fall begins.
	tile.age = SETTLE_SECONDS
	tile.settling = false
	tile.arrival = false
	tile.falling = false
	tile.falling_rows = 0
	tile.lifted = false
	if _dragged_tile_id == tile_id:
		_dragged_tile_id = -1
	if _held_tile_id == tile_id:
		_held_tile_id = -1
	# Preserve the chosen column and full footprint while dropping onto support.
	# Bodies left above the old position also settle into the newly opened space.
	_growth_pending = true
	_gravity_pending = true
	_resume_pending_motion()
	if not bool(tile.falling):
		tile.age = 0.0
		tile.settling = true
	if _has_free_cell():
		full_elapsed = -1.0
	changed.emit()
	return true


func can_drop_now() -> bool:
	return phase == "playing" and not paused and not powerup_active() and not collection_batch_active() and not upcoming.is_empty() and _has_free_cell() and _settling_remaining() <= EPSILON


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
	return not tile.is_empty() and float(tile.get("age", 0.0)) + EPSILON >= settle_duration(tile)


static func arrival_contact_at(tile: Dictionary) -> float:
	return arrival_delay(tile) + Motion.contact_at(tile)


static func arrival_delay(tile: Dictionary) -> float:
	return maxf(0.0, float(tile.get("arrival_delay", _scheduled_arrival_delay(int(tile.get("arrival_index", 0))))))


static func _scheduled_arrival_delay(slot: int) -> float:
	return float(maxi(0, ARRIVAL_ORDER.find(slot))) * ARRIVAL_STAGGER


static func settle_duration(tile: Dictionary) -> float:
	if bool(tile.get("arrival", false)):
		return arrival_delay(tile) + Motion.ready_at(tile)
	return SETTLE_SECONDS


func is_valid_word(tile: Dictionary) -> bool:
	return int(tile.get("mass", 0)) > 1 and not tile.get("word", {}).is_empty()


static func coins_for_tile(tile: Dictionary) -> int:
	# Potential bonus value; collection separately reserves the rare drop roll.
	var mass: int = maxi(1, int(tile.get("mass", tile.get("parts_count", 1))))
	return CoinEconomy.jelly_bonus(mass)


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
		"collectable_ids": collectable_ids(),
		"collection_batch": collection_batch_snapshot(),
		"powerup": powerup_snapshot(),
		"powerup_uses": _powerup_uses.duplicate(),
		"powerup_prices": {"auto_merge": powerup_price("auto_merge"), "fragments": powerup_price("fragments")},
		"error": error, "result": _result.duplicate(true)
	}
	state.merge(reward_progress(fragment_count), true)
	return state


func finish_round() -> Dictionary:
	if _powerup_purchasing:
		_finish_after_purchase = true
		return _result.duplicate(true)
	if _finishing_powerup:
		return _result.duplicate(true)
	if phase == "finished":
		return _result.duplicate(true)
	var generation: int = _generation
	finish_powerup()
	if generation != _generation or phase == "finished":
		return _result.duplicate(true)
	_collection_batch_active = false
	_collection_batch_next_in = 0.0
	# A persistence callback may pause after accepting payment. That accepted
	# transaction must enter the round result even when the player exits paused.
	for pending in fusions.duplicate():
		if str(pending.operation) == "collect" and bool(pending.get("credited", false)):
			_complete_operation(str(pending.attempt_id))
			if generation != _generation or phase == "finished":
				return _result.duplicate(true)
	# A dragged source has already released its support and its old rectangle
	# may now hold another body. Preserve its accepted merge instead of putting
	# that source back through the stack when the round ends mid-animation.
	for pending in fusions.duplicate():
		if str(pending.operation) == "merge" and is_lifted(int(pending.a_id)):
			_complete_operation(str(pending.attempt_id))
			if generation != _generation or phase == "finished":
				return _result.duplicate(true)
	_restore_dragged_tile()
	phase = "finished"
	fusions.clear()
	_dragged_tile_id = -1
	_held_tile_id = -1
	for tile: Dictionary in cells:
		tile.lifted = false
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
			# Exact-word merging needs one complementary pair, even for long words.
			# Preserve authored boundaries by joining adjacent pieces on each side.
			var split: int = 1
			var prefix_length: int = supplied[0].length()
			var best_balance: int = absi(text.length() - prefix_length * 2)
			for index in range(1, supplied.size() - 1):
				prefix_length += supplied[index].length()
				var balance: int = absi(text.length() - prefix_length * 2)
				if balance < best_balance:
					best_balance = balance
					split = index + 1
			return ["".join(supplied.slice(0, split)), "".join(supplied.slice(split))]
	var midpoint: int = ceili(float(text.length()) / 2.0)
	return [text.left(midpoint), text.substr(midpoint)]


func _new_tile(text: String, mass: int, fragments: int) -> Dictionary:
	var word: Dictionary = _word_lookup.get(normalize_word(text), {}) if mass > 1 else {}
	var size: Vector2i = _preferred_size(mass)
	var tile: Dictionary = {
		"id": _next_tile_id, "text": text, "mass": mass, "parts_count": mass,
		"fragments": fragments, "chest": fragments > 0,
		"word": word.duplicate(true), "kind": "word" if not word.is_empty() else "root",
		"column": 0, "row": ROWS - size.y, "width": size.x, "height": size.y,
		"age": SETTLE_SECONDS, "settling": false, "arrival": false, "arrival_index": 0, "arrival_delay": 0.0,
		"falling": false, "falling_rows": 0, "placement_locked": false
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
	# Mix only a new six-root packet. Advertised preview identities never move,
	# and any word crossing a packet boundary keeps its remaining chunks first.
	while _supply_pending.size() < UPCOMING_COUNT:
		var word: Dictionary = WordSampler.next_word(_words, _rng, _word_counts, _word_service, practice_weight_for)
		_supply_words += 1
		var parts: Array[String] = _parts_for_word(word)
		var marked: int = _rng.randi_range(0, parts.size() - 1) if _supply_words % 2 == 0 else -1
		for index in range(parts.size()):
			var tile: Dictionary = _new_tile(parts[index], 1, 1 if index == marked else 0)
			tile.supply_group = _supply_words
			tile.supply_part = index
			tile.supply_parts = parts.size()
			tile.source_word_id = str(word.id)
			_supply_pending.append(tile)
	var packet: Array[Dictionary] = []
	for index in range(UPCOMING_COUNT):
		packet.append(_supply_pending.pop_front())
	var best: Dictionary = {"score": 2147483647, "order": []}
	_search_supply_order(packet, [], 0, best)
	for index: int in best.order:
		_supply.append(packet[index])


func _search_supply_order(packet: Array[Dictionary], order: Array[int], score: int, best: Dictionary) -> void:
	if score >= int(best.score):
		return
	if order.size() == packet.size():
		best.score = score
		best.order = order.duplicate()
		return
	# Six slots have at most 720 arrangements. Deterministic scoring avoids a
	# greedy tail that leaves siblings adjacent when a separated order exists.
	for index in range(packet.size()):
		if index in order:
			continue
		var next_score: int = score
		for previous in range(order.size()):
			var distance: int = order.size() - previous
			var neighbor: Dictionary = packet[order[previous]]
			if int(packet[index].supply_group) == int(neighbor.supply_group):
				next_score += 1000 if distance == 1 else (10 if distance == 2 else 0)
			elif distance == 1 and packet[index].source_word_id == neighbor.source_word_id:
				next_score += 100
		order.append(index)
		_search_supply_order(packet, order, next_score, best)
		order.pop_back()


func _spawn_drop() -> void:
	var column_delays: Dictionary = {}
	for index in range(DROP_COUNT):
		if not _spawn_tile(true, index):
			break
		var tile: Dictionary = cells.back()
		var column: int = int(tile.column)
		if column_delays.has(column):
			# Give the preceding root at least one row of clearance before the
			# next root starts down the same entry lane. A shared lane keeps its
			# floor-up order even when other lanes use an alternating release.
			tile.arrival_delay = maxf(float(tile.arrival_delay), float(column_delays[column]) + sqrt(2.0 / Motion.ARRIVAL_GRAVITY))
		column_delays[column] = float(tile.arrival_delay)


func _spawn_tile(arrival: bool, arrival_index: int = 0) -> bool:
	if upcoming.is_empty():
		return false
	var occupied: Dictionary = _occupied()
	var position: Vector2i = _arrival_position(occupied) if arrival else _free_position(occupied, 1, 1)
	if position.x < 0:
		return false
	var tile: Dictionary = upcoming.pop_front()
	tile.column = position.x
	tile.row = position.y
	tile.age = 0.0 if arrival else SETTLE_SECONDS
	tile.settling = arrival
	tile.arrival = arrival
	tile.arrival_index = arrival_index if arrival else 0
	tile.arrival_delay = _scheduled_arrival_delay(arrival_index) if arrival else 0.0
	tile.falling_rows = position.y + 1 if arrival else 0
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
	elif str(completed.operation) == "split":
		fusions.remove_at(operation_index)
		_complete_split(completed)
	elif str(completed.operation) == "collect":
		var generation: int = _generation
		if int(completed.coins) > 0 and not bool(completed.get("credited", false)) and credit_collection.is_valid():
			var response: Variant = credit_collection.call(event_id, int(completed.coins))
			if generation != _generation or phase != "playing" or _fusion_index(event_id) < 0:
				return
			if not response is Dictionary or not bool(response.get("ok", false)):
				fusions.remove_at(_fusion_index(event_id))
				error = "The coin reward could not be saved. Tap the word to try again."
				_collection_batch_event_id = ""
				cancel_collection_batch()
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
	# The fusion already ends at this reserved rectangle. Allow its final wobble
	# to settle before accepting another drag or collection.
	result.age = 0.0
	result.settling = true
	result.arrival = false
	result.falling = false
	result.falling_rows = 0
	result.placement_locked = false
	cells.append(result)
	if _held_tile_id in [int(a.id), int(b.id)]:
		_held_tile_id = -1
	# Keep ancestry outside public tile snapshots, so repeated merges do not
	# recursively duplicate the entire tree on every frame or animation event.
	_merge_history[int(result.id)] = [completed.a.duplicate(true), completed.b.duplicate(true)]
	_restore_growth(int(result.id))
	_gravity_pending = true
	merged_count += 1
	if bool(_powerup.get("active", false)) and str(_powerup.kind) == "auto_merge":
		_powerup_ids.erase(int(a.id))
		_powerup_ids.erase(int(b.id))
		_powerup_ids.append(int(result.id))
		_powerup.completed = int(_powerup.completed) + 1
		if _powerup.drags.is_empty():
			_powerup.stage = "settling"
			_powerup.elapsed = 0.0
			_powerup.duration = SETTLE_SECONDS
	if _has_free_cell():
		full_elapsed = -1.0
	completed.result = cell(int(result.id))
	completed.word = completed.result.word.duplicate(true)
	var generation: int = _generation
	fusion_completed.emit(completed, 0)
	if _can_continue(generation):
		changed.emit()


func _complete_split(completed: Dictionary) -> void:
	var parent_id: int = int(completed.a_id)
	var index: int = _index_for_id(parent_id)
	if index < 0:
		return
	cells.remove_at(index)
	# Commit both destinations before callbacks can spawn or merge another body.
	# Their own histories and failed wallet receipts remain available for undo.
	for child: Dictionary in completed.results:
		var restored: Dictionary = child.duplicate(true)
		restored.age = 0.0
		restored.settling = true
		restored.arrival = false
		restored.falling = false
		restored.falling_rows = 0
		restored.lifted = false
		restored.placement_locked = false
		cells.append(restored)
	if _held_tile_id == parent_id:
		_held_tile_id = -1
	_merge_history.erase(parent_id)
	_collection_coin_rewards.erase(_collection_event_ids.get(parent_id, ""))
	_collection_event_ids.erase(parent_id)
	# Wrapped parents may release padding cells. Reconsider compressed neighbors
	# only after both frozen split destinations have finished settling.
	_growth_pending = true
	_gravity_pending = true
	# A split does not restart an existing full-board deadline.
	if _has_free_cell():
		full_elapsed = -1.0
	var generation: int = _generation
	fusion_completed.emit(completed, 0)
	if _can_continue(generation):
		changed.emit()


func _discard_history(tile_id: int) -> void:
	var pending: Array[int] = [tile_id]
	while not pending.is_empty():
		var current_id: int = pending.pop_back()
		for child: Dictionary in _merge_history.get(current_id, []):
			pending.append(int(child.id))
		_merge_history.erase(current_id)
		_collection_coin_rewards.erase(_collection_event_ids.get(current_id, ""))
		_collection_event_ids.erase(current_id)


func _complete_collection(completed: Dictionary) -> void:
	var index: int = _index_for_id(int(completed.a_id))
	if index < 0:
		return
	cells.remove_at(index)
	if _held_tile_id == int(completed.a_id):
		_held_tile_id = -1
	_discard_history(int(completed.a_id))
	_restore_growth()
	# Wait until all operations at this timestamp finish before moving the stack.
	# Failed payments leave their body in place and never initiate gravity.
	_gravity_pending = true
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
	if bool(completed.get("batch", false)) and int(completed.get("batch_id", -1)) == _collection_batch_serial:
		_collection_batch_completed += 1
		_collection_batch_event_id = ""
		if _collection_batch_cursor >= _collection_batch_ids.size():
			_collection_batch_active = false
			_collection_batch_next_in = 0.0
	spawn_interval = maxf(MIN_SPAWN_INTERVAL, INITIAL_SPAWN_INTERVAL - float(cleared_pairs) * 0.04)
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


func _restore_growth(excluded_id: int = -1) -> void:
	# Growth can reuse nearby space. Its settled result and any neighbors that
	# lose support then fall. Manual footprints keep their chosen size and column.
	_growth_pending = false
	for tile in cells:
		var extent: Vector2i = _preferred_size(int(tile.mass))
		if int(tile.width) == extent.x and int(tile.height) == extent.y:
			continue
		if bool(tile.get("placement_locked", false)):
			continue
		if is_fusing(int(tile.id)):
			continue
		if int(tile.id) == excluded_id or int(tile.id) == _held_tile_id or _reserved_for_collection(int(tile.id)) \
			or _reserved_for_powerup(int(tile.id)) or not is_settled(tile):
			# Another collection may free space during this body's final wobble.
			_growth_pending = true
			continue
		var position: Vector2i = _position_near(_occupied([int(tile.id)]), extent.x, extent.y, tile)
		if position.x < 0:
			continue
		tile.column = position.x
		tile.row = position.y
		tile.width = extent.x
		tile.height = extent.y
		tile.age = 0.0
		tile.settling = true
		tile.arrival = false
		tile.falling = false
		tile.falling_rows = 0
		_gravity_pending = true


func _resume_pending_motion() -> void:
	if phase != "playing" or paused:
		return
	if _growth_pending and _settling_remaining() <= EPSILON:
		_restore_growth()
	if _gravity_pending:
		_settle_collected_stack()


func _settle_collected_stack() -> void:
	_gravity_pending = false
	var ordered: Array[Dictionary] = cells.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var bottom_a: int = int(a.row) + int(a.height)
		var bottom_b: int = int(b.row) + int(b.height)
		if bottom_a != bottom_b:
			return bottom_a > bottom_b
		if a.column != b.column:
			return int(a.column) < int(b.column)
		return int(a.id) < int(b.id))
	for tile: Dictionary in ordered:
		if is_fusing(int(tile.id)) or int(tile.id) == _held_tile_id or _reserved_for_collection(int(tile.id)) \
			or _reserved_for_powerup(int(tile.id)) or not is_settled(tile):
			# Keep fusion endpoints, held anchors and queued pickups intact. A later
			# operation or settlement boundary retries their support settlement.
			_gravity_pending = true
			continue
		var occupied: Dictionary = _occupied([int(tile.id)], false)
		var row: int = int(tile.row)
		while row + int(tile.height) < ROWS and _fits(occupied, int(tile.column), row + 1, int(tile.width), int(tile.height)):
			row += 1
		if row == int(tile.row):
			continue
		tile.falling_rows = row - int(tile.row)
		tile.row = row
		tile.age = 0.0
		tile.settling = true
		tile.arrival = false
		tile.falling = true
		_gravity_pending = true
		_growth_pending = true


func _occupied(excluded_ids: Array[int] = [], reserve_drag_return: bool = true) -> Dictionary:
	var occupied: Dictionary = {}
	for tile in cells:
		if not int(tile.id) in excluded_ids and not bool(tile.get("lifted", false)):
			_occupy(occupied, int(tile.column), int(tile.row), int(tile.width), int(tile.height))
	# A fusion owns its future footprint throughout the animation, so another
	# merge or incoming batch cannot take its destination before handover.
	for active in fusions:
		if str(active.operation) == "merge":
			var result: Dictionary = active.result
			_occupy(occupied, int(result.column), int(result.row), int(result.width), int(result.height))
		elif str(active.operation) == "split":
			for child: Dictionary in active.results:
				_occupy(occupied, int(child.column), int(child.row), int(child.width), int(child.height))
	if reserve_drag_return and _dragged_tile_id >= 0 and not _dragged_tile_id in excluded_ids:
		# A moving spare cell protects cancellation from new arrivals and growth.
		# Gravity never sees this reservation, so it cannot act as hidden support.
		var anchor: Dictionary = cell(_dragged_tile_id)
		if not anchor.is_empty():
			var position: Vector2i = _drag_return_position(_occupied([], false), 1, 1, anchor)
			if position.x >= 0:
				_occupy(occupied, position.x, position.y, 1, 1)
	return occupied


func _split_sizes(child: Dictionary) -> Array[Vector2i]:
	var sizes: Array[Vector2i] = [_preferred_size(int(child.mass))]
	for size: Vector2i in [Vector2i(int(child.width), int(child.height)), Vector2i.ONE]:
		if not size in sizes:
			sizes.append(size)
	return sizes


func _split_placements(parent: Dictionary) -> Array[Dictionary]:
	var children: Array = _merge_history[int(parent.id)]
	var sizes_a: Array[Vector2i] = _split_sizes(children[0])
	var sizes_b: Array[Vector2i] = _split_sizes(children[1])
	var options: Array[Dictionary] = []
	for a_size: Vector2i in sizes_a:
		for b_size: Vector2i in sizes_b:
			options.append({"a": a_size, "b": b_size,
				"area": a_size.x * a_size.y + b_size.x * b_size.y, "order": options.size()})
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.area) > int(b.area) if a.area != b.area else int(a.order) < int(b.order))
	var occupied: Dictionary = _occupied([int(parent.id)])
	var outgoing_ids: Array[int] = [int(parent.id)]
	for active: Dictionary in fusions:
		outgoing_ids.append(int(active.a_id))
		outgoing_ids.append(int(active.b_id))
	# Outgoing bodies still block placement, but only their reserved results
	# can support a child after concurrent animations have completed.
	var support_occupied: Dictionary = _occupied(outgoing_ids, false)
	var center := Vector2(float(parent.column) + float(parent.width) * 0.5,
		float(parent.row) + float(parent.height) * 0.5)
	for option: Dictionary in options:
		var positions: Array[Vector2i] = _split_pair(occupied, support_occupied, option.a, option.b, center)
		if positions.size() != 2:
			continue
		var results: Array[Dictionary] = []
		for index in range(2):
			var child: Dictionary = children[index].duplicate(true)
			var size: Vector2i = option.a if index == 0 else option.b
			child.column = positions[index].x
			child.row = positions[index].y
			child.width = size.x
			child.height = size.y
			child.age = 0.0
			child.settling = true
			child.arrival = false
			child.falling = false
			child.falling_rows = 0
			child.placement_locked = false
			results.append(child)
		return results
	return []


func _split_pair(occupied: Dictionary, support_occupied: Dictionary, size_a: Vector2i, size_b: Vector2i, center: Vector2) -> Array[Vector2i]:
	var candidates_a: Array[Rect2i] = _split_candidates(occupied, size_a)
	var candidates_b: Array[Rect2i] = _split_candidates(occupied, size_b)
	var target_a: Vector2 = center - Vector2(float(size_b.x) * 0.5, 0.0)
	var target_b: Vector2 = center + Vector2(float(size_a.x) * 0.5, 0.0)
	var nearest: Array[Vector2i] = []
	var distance: float = INF
	var horizontal_distance: float = INF
	# Search pairs together: a small child must not consume the only corridor
	# that can fit its larger sibling. Every board row is available for undo.
	for a: Rect2i in candidates_a:
		var a_offset: Vector2 = Vector2(a.position) + Vector2(a.size) * 0.5 - target_a
		for b: Rect2i in candidates_b:
			if a.intersects(b):
				continue
			if not _split_has_support(a, b, support_occupied) or not _split_has_support(b, a, support_occupied):
				continue
			var b_offset: Vector2 = Vector2(b.position) + Vector2(b.size) * 0.5 - target_b
			var candidate_distance: float = a_offset.length_squared() + b_offset.length_squared()
			var candidate_horizontal: float = a_offset.x * a_offset.x + b_offset.x * b_offset.x
			# On equal travel, drop into a gap instead of hopping sideways.
			if candidate_distance < distance or (is_equal_approx(candidate_distance, distance) and candidate_horizontal < horizontal_distance):
				nearest.assign([a.position, b.position])
				distance = candidate_distance
				horizontal_distance = candidate_horizontal
	return nearest


func _split_has_support(body: Rect2i, sibling: Rect2i, occupied: Dictionary) -> bool:
	if body.end.y == ROWS:
		return true
	for column in range(body.position.x, body.end.x):
		if occupied.has(body.end.y * COLUMNS + column) or sibling.has_point(Vector2i(column, body.end.y)):
			return true
	return false


func _split_candidates(occupied: Dictionary, size: Vector2i) -> Array[Rect2i]:
	var candidates: Array[Rect2i] = []
	for row in range(ROWS - size.y + 1):
		for column in range(COLUMNS - size.x + 1):
			if _fits(occupied, column, row, size.x, size.y):
				candidates.append(Rect2i(Vector2i(column, row), size))
	return candidates


func _position_near(occupied: Dictionary, width: int, height: int, anchor: Dictionary) -> Vector2i:
	var center := Vector2(float(anchor.column) + float(anchor.width) * 0.5, float(anchor.row) + float(anchor.height) * 0.5)
	var nearest := Vector2i(-1, -1)
	var distance: float = INF
	# Reserve the nearest fusion or growth endpoint first. Unsupported bodies
	# fall only after that visual handover finishes its settling window.
	for row in range(mini(int(anchor.row), ROWS - height), -1, -1):
		for column in range(COLUMNS - width + 1):
			var candidate := Vector2(column + width * 0.5, row + height * 0.5)
			var candidate_distance: float = center.distance_squared_to(candidate)
			if candidate_distance < distance and _fits(occupied, column, row, width, height):
				nearest = Vector2i(column, row)
				distance = candidate_distance
	return nearest


func _fits(occupied: Dictionary, column: int, row: int, width: int, height: int) -> bool:
	for y in range(row, row + height):
		for x in range(column, column + width):
			if occupied.has(y * COLUMNS + x):
				return false
	return true


func _occupy(occupied: Dictionary, column: int, row: int, width: int, height: int) -> void:
	for y in range(row, row + height):
		for x in range(column, column + width):
			occupied[y * COLUMNS + x] = true


func _free_position(occupied: Dictionary, width: int, height: int) -> Vector2i:
	for row in range(ROWS - height, -1, -1):
		for column in range(COLUMNS - width + 1):
			if _fits(occupied, column, row, width, height):
				return Vector2i(column, row)
	return Vector2i(-1, -1)


func _has_free_cell() -> bool:
	return _arrival_position(_occupied()).x >= 0


func _arrival_position(occupied: Dictionary) -> Vector2i:
	var position := Vector2i(-1, -1)
	for column in range(COLUMNS):
		var row: int = 0
		while row < ROWS and not occupied.has(row * COLUMNS + column):
			row += 1
		var landing_row: int = row - 1
		if landing_row > position.y:
			position = Vector2i(column, landing_row)
	return position


func _settling_remaining() -> float:
	var remaining: float = 0.0
	for tile in cells:
		remaining = maxf(remaining, settle_duration(tile) - float(tile.age))
	return maxf(0.0, remaining)


func _next_settlement() -> float:
	var boundary: float = INF
	for tile: Dictionary in cells:
		var remaining: float = settle_duration(tile) - float(tile.age)
		if remaining > EPSILON:
			boundary = minf(boundary, remaining)
	return 0.0 if is_inf(boundary) else boundary


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
