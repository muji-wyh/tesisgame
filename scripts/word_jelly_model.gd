class_name WordJellyModel
extends RefCounted
## Roots build spelling, pictures confirm meaning, and matching words level up.

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
signal drag_blocked(reason: String)
signal combo_changed(state: Dictionary)

const RewardProgress = preload("res://scripts/jelly_reward_progress.gd")
const Motion = preload("res://scripts/jelly_motion.gd")
const WordSampler = preload("res://scripts/word_sampler.gd")
const CoinEconomy = preload("res://scripts/coin_economy.gd")
const MorphologyResolver = preload("res://scripts/morphology_resolver.gd")
const StageRun = preload("res://scripts/word_jelly_stage_run.gd")
const LABEL_FONT = preload("res://assets/fonts/heading.tres")
const COLUMNS: int = 5
const ROWS: int = 8
const CAPACITY: int = COLUMNS * ROWS
const MAX_MERGE_LEVEL: int = 9
const INITIAL_SETTLED_TILES: int = COLUMNS * 3
const DROP_COUNT: int = COLUMNS
const UPCOMING_COUNT: int = COLUMNS
const SETTLE_SECONDS: float = 0.36
const DRAG_GRAVITY_DELAY_SECONDS: float = 0.60
const ARRIVAL_STAGGER: float = 0.15
const ARRIVAL_SLOT_CLEARANCE: float = 0.36
const ARRIVAL_ORDER: Array[int] = [0, 3, 1, 4, 2]
const FUSION_SECONDS: float = 0.76
const COLLECT_SECONDS: float = 0.42
const POP_SECONDS: float = 0.18
const BATCH_BEAT_SECONDS: float = 0.12
const BATCH_POP_SECONDS: float = 0.04
const COMBO_SECONDS: float = 8.0
const BLAST_MARK_BEAT_SECONDS: float = 0.06
const BLAST_TIME_SCALE: float = 0.12
const BLAST_FREEZE_SECONDS: float = 0.10
const BLAST_MARK_WINDUP_SECONDS: float = 0.18
const BLAST_MARK_FLIGHT_SECONDS: float = 0.42
const BLAST_MARK_RECOVERY_SECONDS: float = 0.10
const AUTO_COLLECT_UNLOCK_LEVEL: int = 3
const INITIAL_SPAWN_INTERVAL: float = 20.0
const MIN_SPAWN_INTERVAL: float = 10.0
const CLEARS_PER_DIFFICULTY_STAGE: int = 4
const SPEEDUP_PER_STAGE: float = 2.0
const FULL_SECONDS: float = 10.0
const CHEST_UNLOCK_FRAGMENTS: int = RewardProgress.CHEST_UNLOCK_FRAGMENTS
const CHEST_UPGRADE_FRAGMENTS: int = RewardProgress.CHEST_UPGRADE_FRAGMENTS
const EPSILON: float = 0.000001
const POWERUP_PRICES: Dictionary = CoinEconomy.POWERUP_BASE_PRICES
const POWERUP_MERGE_BEAT_SECONDS: float = 0.20
const POWERUP_DRAG_SECONDS: float = 0.25
const POWERUP_FUSION_SECONDS: float = 0.11
const POWERUP_SETTLE_SECONDS: float = 0.03
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
var credit_combo: Callable
var combo_count: int = 0
var combo_best: int = 0
var combo_coins: int = 0
var _combo_bonus: int = 0
var _combo_remaining: float = 0.0
var _combo_event: String = ""
var _combo_pending: String = ""
var _combo_committing: bool = false
var _finish_after_combo: bool = false
var commit_collection: Callable
var purchase_powerup: Callable
var allow_cross_age: bool = false
var pip_level: int = 0

var _words: Array[Dictionary] = []
var _word_lookup: Dictionary = {}
var _words_by_id: Dictionary = {}
var _authored_words: Dictionary = {}
var _morphology := MorphologyResolver.new()
var _sense_resolvers: Dictionary = {}
var _footprints: Dictionary = {}
var authored_morphology: bool = false
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
var _generation: int = 0
var _growth_pending: bool = false
var _gravity_pending: bool = false
var _held_tile_id: int = -1
var _dragged_tile_id: int = -1
var _drag_gravity_delays: Dictionary = {}
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
var _blast_rng := RandomNumberGenerator.new()
var _blast_queue: Array[Dictionary] = []
var _powerup: Dictionary = {}
var _powerup_uses: Dictionary = {"auto_merge": 0, "fragments": 0}
var _powerup_ids: Array[int] = []
var _powerup_purchasing: bool = false
var _powerup_activating: bool = false
var _powerup_committing: bool = false
var _finishing_powerup: bool = false
var _finish_after_purchase: bool = false
var _finish_reason: String = ""
var _settle_after_purchase: bool = false
var _finish_after_collection_commit: bool = false
var stage_run: StageRun
var fall_speed_scale: float = 1.0
var _stage_ending: bool = false
var _stage_finalizing: bool = false
var _stage_spawn_interval: float = INITIAL_SPAWN_INTERVAL
var _stage_pressure_level: int = 0
var _stage_time_pending: String = ""
var _stage_clear_feedback: float = 0.0


func configure(words: Array, level: int, seed_value: int = -1) -> bool:
	if _powerup_purchasing or _finishing_powerup or _combo_committing:
		return false
	var previous_generation: int = _generation
	_blast_queue.clear()
	finish_powerup()
	if previous_generation != _generation:
		return false
	_generation += 1
	stage_run = null
	_stage_ending = false
	_stage_finalizing = false
	_stage_pressure_level = 0
	_stage_time_pending = ""
	_stage_clear_feedback = 0.0
	fall_speed_scale = 1.0
	cells.clear()
	upcoming.clear()
	fusions.clear()
	_words.clear()
	_word_lookup.clear()
	_words_by_id.clear()
	_authored_words.clear()
	_sense_resolvers.clear()
	_footprints.clear()
	authored_morphology = false
	_supply.clear()
	_supply_pending.clear()
	_completed_words.clear()
	_collection_event_ids.clear()
	_collection_coin_rewards.clear()
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
	combo_count = 0
	combo_best = 0
	combo_coins = 0
	_combo_bonus = 0
	_combo_remaining = 0.0
	_combo_event = ""
	_combo_pending = ""
	_combo_committing = false
	_finish_after_combo = false
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
	_drag_gravity_delays.clear()
	_reset_collection_batch()
	_powerup.clear()
	_powerup_ids.clear()
	_finish_after_purchase = false
	_finish_reason = ""
	_settle_after_purchase = false
	_finish_after_collection_commit = false
	error = ""
	if seed_value < 0:
		_rng.randomize()
		_coin_rng.randomize()
		_blast_rng.randomize()
	else:
		_rng.seed = seed_value
		# Coin rolls must not alter word supply, fragments, or automatic matching.
		_coin_rng.seed = seed_value ^ 0x434F494E
		_blast_rng.seed = seed_value ^ 0x424C4153
	var ids: Dictionary = {}
	var analyses: Array = []
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
		_words_by_id[str(word.id)] = word
		if _reviewed_morphology(word):
			if str(word.morphology.get("lexeme_id", "")) != str(word.id) or str(word.morphology.get("text", "")) != str(word.text):
				error = "Reviewed morphology must match the word's sense ID and exact spelling."
				changed.emit()
				return false
			analyses.append(word.morphology)
			_authored_words[str(word.id)] = str(word.morphology.get("id", ""))
	if _words.is_empty():
		error = "Word Jelly needs at least one eligible word."
		changed.emit()
		return false
	if not _morphology.configure(analyses):
		error = _morphology.error
		changed.emit()
		return false
	authored_morphology = not analyses.is_empty()
	_powerup_uses = {"auto_merge": 0, "fragments": 0}
	phase = "playing"
	_fill_upcoming()
	var initial_area: int = 0
	for index in range(INITIAL_SETTLED_TILES):
		if authored_morphology:
			var next: Dictionary = _first_preview_tile()
			if next.is_empty() or initial_area + int(next.width) * int(next.height) > INITIAL_SETTLED_TILES:
				break
			initial_area += int(next.width) * int(next.height)
		if not _spawn_tile(false):
			break
	if authored_morphology:
		_schedule_spawn_interval()
	changed.emit()
	return true


func stage_transition_ready() -> bool:
	return phase == "playing" and not powerup_active() and not collection_batch_active() \
		and fusions.is_empty() and _held_tile_id < 0 and _dragged_tile_id < 0 \
		and not _powerup_activating and not _powerup_committing and not _finishing_powerup and _blast_queue.is_empty()


func bind_stage(plan: Dictionary) -> bool:
	if not stage_transition_ready():
		error = "Wait for the current Jelly operation before starting a stage."
		return false
	var attempt := StageRun.new()
	if not attempt.configure(plan):
		error = attempt.error
		return false
	stage_run = attempt
	_stage_spawn_interval = float(plan.spawn_interval)
	fall_speed_scale = float(plan.fall_speed_scale)
	if stage_run.kind == "challenge":
		_sync_challenge_pressure()
	_schedule_spawn_interval()
	spawn_elapsed = 0.0
	error = ""
	changed.emit()
	return true


func stage_ending() -> bool:
	return _stage_ending


func _stage_clock_running() -> bool:
	return stage_run != null and not _stage_ending and not powerup_active() \
		and not collection_batch_active() and not _has_pending_collection_commit() and error.is_empty()


func _decide_stage(reason: String) -> void:
	if stage_run == null or _stage_ending:
		return
	if stage_run.outcome.is_empty() and not stage_run.decide(reason):
		error = stage_run.error
		return
	_stage_ending = true
	_stage_clear_feedback = 0.62 if stage_run.outcome == "cleared" else 0.0
	_restore_dragged_tile()
	_held_tile_id = -1
	_blast_queue.clear()
	_pump_stage_finish()


func _pump_stage_finish() -> void:
	if not _stage_ending or phase != "playing" or paused or not error.is_empty() \
		or powerup_active() or not fusions.is_empty() or collection_batch_active() \
		or _has_pending_collection_commit() or not _combo_pending.is_empty():
		return
	if _settling_remaining() > EPSILON:
		return
	if not collectable_ids().is_empty():
		start_collection_batch()
		return
	if _stage_clear_feedback > EPSILON:
		return
	_stage_finalizing = true
	finish_round("cleared" if stage_run.outcome == "cleared" else "timeout" if stage_run.outcome == "timeout" \
		else "danger" if stage_run.outcome == "blocked" else "finished")
	_stage_finalizing = false


func retry_stage_finish() -> void:
	if stage_run == null or not _stage_ending or phase != "playing":
		return
	error = ""
	_pump_stage_finish()
	changed.emit()


func settle_stage_finish() -> bool:
	if stage_run == null or phase == "finished":
		return true
	if not _stage_ending:
		_decide_stage("exit")
	var was_paused: bool = paused
	paused = false
	for index in range(1200):
		if phase == "finished" or not error.is_empty() or _has_pending_collection_commit():
			break
		step(0.05)
	paused = was_paused
	if phase != "finished" and error.is_empty() and not _has_pending_collection_commit():
		error = "The remaining Jelly rewards could not finish. Choose Retry saving."
	return phase == "finished"


func _sync_challenge_pressure() -> void:
	if stage_run == null or stage_run.kind != "challenge":
		return
	var pressure: Dictionary = stage_run.challenge_pressure()
	if int(pressure.level) == _stage_pressure_level:
		return
	_stage_pressure_level = int(pressure.level)
	_stage_spawn_interval = float(pressure.spawn_interval)
	fall_speed_scale = float(pressure.fall_speed_scale)
	for word: Dictionary in stage_run.words_for_pressure():
		if not _words_by_id.has(str(word.id)):
			_words_by_id[str(word.id)] = word.duplicate(true)
			_word_lookup[normalize_word(str(word.text))] = word.duplicate(true)
			if _reviewed_morphology(word):
				_authored_words[str(word.id)] = str(word.morphology.id)
	var analyses: Array = _words_by_id.values().filter(func(word: Dictionary) -> bool: return _reviewed_morphology(word)) \
		.map(func(word: Dictionary) -> Dictionary: return word.morphology)
	if not _morphology.configure(analyses):
		error = "The next challenge vocabulary cannot be composed: " + _morphology.error
		return
	_sense_resolvers.clear()
	_words.assign(stage_run.words_for_pressure())
	_schedule_spawn_interval()


func retire_mastered_words(word_ids: Array) -> void:
	# Stop creating new packets, but finish every issued packet so a board root
	# cannot lose its picture or remaining composition parts.
	var retired: Dictionary = {}
	for word_id: Variant in word_ids:
		retired[str(word_id)] = true
	if retired.is_empty():
		return
	_words = _words.filter(func(word: Dictionary) -> bool: return not retired.has(str(word.id)))
	_fill_upcoming()
	changed.emit()


func replace_stage_words(words: Array, level: int) -> bool:
	if not stage_transition_ready():
		return false
	# Keep historical definitions so an older body can still finish its spelling,
	# picture match, level upgrade, or collection after the next stage begins.
	var next_words: Array[Dictionary] = []
	var next_ids: Dictionary = {}
	var next_texts: Dictionary = {}
	var definitions: Dictionary = _words_by_id.duplicate(true)
	for candidate: Variant in words:
		if not candidate is Dictionary or not _eligible(candidate, level):
			continue
		var word_id: String = str(candidate.id)
		var normalized: String = normalize_word(str(candidate.text))
		if next_ids.has(word_id) or next_texts.has(normalized):
			continue
		var word: Dictionary = candidate.duplicate(true)
		next_words.append(word)
		next_ids[word_id] = true
		next_texts[normalized] = word
		definitions[word_id] = word
	if next_words.is_empty():
		return false
	var analyses: Array = []
	var authored: Dictionary = {}
	for word: Dictionary in definitions.values():
		if not _reviewed_morphology(word):
			continue
		if str(word.morphology.get("lexeme_id", "")) != str(word.id) or str(word.morphology.get("text", "")) != str(word.text):
			return false
		analyses.append(word.morphology)
		authored[str(word.id)] = str(word.morphology.get("id", ""))
	var next_morphology := MorphologyResolver.new()
	if not next_morphology.configure(analyses):
		return false
	_words = next_words
	_words_by_id = definitions
	_word_lookup.merge(next_texts, true)
	_authored_words = authored
	_morphology = next_morphology
	_sense_resolvers.clear()
	authored_morphology = not analyses.is_empty()
	_fill_upcoming()
	spawn_elapsed = 0.0
	full_elapsed = -1.0
	_schedule_spawn_interval()
	changed.emit()
	return true


static func normalize_word(value: String) -> String:
	var pieces: PackedStringArray = value.strip_edges().to_lower().replace("\t", " ").replace("\n", " ").split(" ", false)
	return " ".join(pieces)


func powerup_active() -> bool:
	return _powerup_purchasing or bool(_powerup.get("active", false))


func gameplay_time_scale() -> float:
	if bool(_powerup.get("active", false)) and str(_powerup.kind) == "blast" and str(_powerup.stage) == "mark":
		return 0.0 if float(_powerup.elapsed) + EPSILON < BLAST_FREEZE_SECONDS else BLAST_TIME_SCALE
	return 1.0


func presentation_delta(delta: float) -> float:
	if gameplay_time_scale() >= 1.0:
		return delta
	var elapsed: float = float(_powerup.elapsed)
	var frozen: float = minf(delta, maxf(0.0, BLAST_FREEZE_SECONDS - elapsed))
	var slowed: float = minf(delta - frozen, maxf(0.0, float(_powerup.duration) - elapsed - frozen))
	return slowed * BLAST_TIME_SCALE + delta - frozen - slowed


func hit_stop_snapshot() -> Dictionary:
	var scale: float = gameplay_time_scale()
	return {"active": scale < 1.0, "time_scale": scale, "paused": paused,
		"phase": "freeze" if is_zero_approx(scale) else "slow" if scale < 1.0 else "",
		"remaining": maxf(0.0, float(_powerup.duration) - float(_powerup.elapsed)) if scale < 1.0 else 0.0}


func powerup_price(kind: String) -> int:
	return CoinEconomy.powerup_price(kind, int(_powerup_uses.get(kind, 0)))


func powerup_snapshot() -> Dictionary:
	if not _powerup.is_empty():
		# Rendering needs live journeys, not the resolver's full word graphs.
		var snapshot: Dictionary = _powerup.duplicate()
		snapshot.erase("plans")
		snapshot.erase("next_plan_id")
		return snapshot.duplicate(true)
	return {
		"active": false, "kind": "", "receipt_id": "", "stage": "", "elapsed": 0.0,
		"duration": 0.0, "source_id": -1, "target_id": -1, "source": {}, "target": {},
		"completed": 0, "total": 0, "arrivals": [], "drags": [], "clock": 0.0,
		"started_at": 0.0, "next_launch_at": 0.0, "contact_played": false, "contact_pending": false}


func can_activate_powerup(kind: String) -> bool:
	if _stage_ending:
		return false
	if kind == "extra_time":
		return stage_run != null and stage_run.kind == "main" and stage_run.outcome.is_empty() \
			and stage_run.can_add_time() \
			and stage_run.remaining > EPSILON and phase == "playing" and not paused \
			and not _powerup_purchasing and _combo_pending.is_empty()
	var repeat_treasure: bool = kind == "fragments" and str(_powerup.get("kind", "")) == "fragments"
	if not POWERUP_PRICES.has(kind) or phase != "playing" or paused or _powerup_purchasing \
		or (powerup_active() and not repeat_treasure) \
		or _finishing_powerup or collection_batch_active() or _held_tile_id >= 0 \
		or not fusions.is_empty() or not _blast_queue.is_empty() or _settling_remaining() > EPSILON or cells.is_empty():
		return false
	return kind == "fragments" or not _powerup_pair(false).is_empty()


func activate_powerup(kind: String) -> bool:
	if _powerup_activating or not can_activate_powerup(kind):
		return false
	var generation: int = _generation
	# Separate clicks may overlap flights; nested purchase callbacks may not pay again.
	_powerup_activating = true
	var purchased: bool = _purchase_extra_time() if kind == "extra_time" else _purchase_powerup(kind)
	if generation == _generation:
		changed.emit()
	_powerup_activating = false
	return purchased


func _purchase_extra_time() -> bool:
	if _stage_time_pending.is_empty():
		_stage_time_pending = _event_id("extra-time")
	var receipt: String = _stage_time_pending
	var generation: int = _generation
	var price: int = powerup_price("extra_time")
	_powerup_purchasing = true
	var response: Variant = purchase_powerup.call(receipt, "extra_time", price) if purchase_powerup.is_valid() else {}
	_powerup_purchasing = false
	if generation != _generation:
		return false
	if not response is Dictionary or not bool(response.get("ok", false)):
		error = str(response.get("error", "Extra time could not be saved. Please retry.")) if response is Dictionary \
			else "Extra time could not be saved. Please retry."
		powerup_feedback.emit("extra_time", false)
		return false
	if not stage_run.add_time(receipt):
		error = stage_run.error
		return false
	_powerup_uses.extra_time = int(_powerup_uses.get("extra_time", 0)) + 1
	_stage_time_pending = ""
	error = ""
	powerup_feedback.emit("extra_time", true)
	cue_requested.emit("powerup_success")
	if _finish_after_purchase:
		_finish_after_purchase = false
		finish_round()
	return true


func _purchase_powerup(kind: String) -> bool:
	var generation: int = _generation
	var receipt_id: String = _event_id("powerup-" + kind)
	var previous_timeline: String = str(_powerup.get("receipt_id", ""))
	var price: int = powerup_price(kind)
	# Lock the board while persistence runs, including reentrant lifecycle calls.
	_powerup_purchasing = true
	var response: Variant = purchase_powerup.call(receipt_id, kind, price) if purchase_powerup.is_valid() else {}
	_powerup_purchasing = false
	if generation != _generation:
		return false
	if not response is Dictionary or not bool(response.get("ok", false)) or bool(response.get("duplicate", false)):
		var settle_pending: bool = _settle_after_purchase
		_settle_after_purchase = false
		if settle_pending:
			finish_powerup()
		if generation != _generation:
			return false
		powerup_feedback.emit(kind, false)
		if generation == _generation and (not powerup_active() or _same_powerup(generation, previous_timeline)):
			cue_requested.emit("powerup_wrong")
		if _finish_after_purchase and generation == _generation:
			_finish_after_purchase = false
			finish_round()
		return false
	# Commit the next price before feedback or lifecycle callbacks can reenter.
	_powerup_uses[kind] = int(_powerup_uses.get(kind, 0)) + 1
	if not bool(_powerup.get("active", false)):
		_begin_powerup_timeline(kind, receipt_id)
	var timeline_id: String = str(_powerup.receipt_id)
	if kind == "fragments":
		_prepare_powerup_fragments(receipt_id)
	# The paid obligation exists before any user callback may pause or leave.
	if _settle_after_purchase or _finish_after_purchase:
		_settle_after_purchase = false
		finish_powerup()
		if _finish_after_purchase:
			_finish_after_purchase = false
			finish_round()
		return true
	powerup_feedback.emit(kind, true)
	if not _same_powerup(generation, timeline_id):
		return true
	if not paused:
		cue_requested.emit("powerup_success")
	if _same_powerup(generation, timeline_id) and not paused:
		_advance_powerup()
	return true


func _begin_powerup_timeline(kind: String, receipt_id: String) -> void:
	_powerup_ids.clear()
	for tile: Dictionary in cells:
		_powerup_ids.append(int(tile.id))
	_powerup = {"active": true, "kind": kind, "receipt_id": receipt_id, "stage": "ready",
		"elapsed": 0.0, "duration": 0.0, "source_id": -1, "target_id": -1,
		"source": {}, "target": {}, "completed": 0, "total": 0, "arrivals": [], "drags": [],
		"plans": [], "next_plan_id": 0, "clock": 0.0, "started_at": 0.0,
		"next_launch_at": 0.0, "contact_played": false, "contact_pending": false}


func _blast_target_ids(origin: Dictionary, level: int) -> Array[int]:
	var inner: Array[int] = []
	var outer: Array[int] = []
	var selected: Array[int] = []
	if level <= 1:
		return selected
	for tile: Dictionary in cells:
		var id: int = int(tile.id)
		if id == int(origin.get("id", -1)) or id in [_held_tile_id, _dragged_tile_id] \
			or is_fusing(id) or is_lifted(id) or _reserved_for_collection(id) or _reserved_for_powerup(id):
			continue
		var dx: int = absi(int(tile.column) - int(origin.column))
		var dy: int = absi(int(tile.row) - int(origin.row))
		var distance: int = maxi(dx, dy)
		if level >= 9 or (level == 5 and dx == 0) or (level == 6 and (dx == 0 or dy == 0)):
			selected.append(id)
		elif distance == 1:
			inner.append(id)
		elif distance == 2:
			outer.append(id)
	if level in [5, 6, 9]:
		return selected
	if level <= 4:
		_shuffle_blast_ids(inner)
		selected.assign(inner.slice(0, mini(level - 1, inner.size())))
		return selected
	selected = inner
	if level == 8:
		_shuffle_blast_ids(outer)
		selected.append_array(outer.slice(0, mini(14, outer.size())))
	return selected


func _shuffle_blast_ids(ids: Array[int]) -> void:
	for index in range(ids.size() - 1, 0, -1):
		var other: int = _blast_rng.randi_range(0, index)
		var saved: int = ids[index]
		ids[index] = ids[other]
		ids[other] = saved


func _queue_collection_blast(completed: Dictionary) -> void:
	var level: int = clampi(int(completed.get("merge_level", 1)), 1, MAX_MERGE_LEVEL)
	if level <= 1 or not _finish_reason.is_empty() or _stage_ending:
		return
	var targets: Array[int] = _blast_target_ids(completed.a, level)
	if targets.is_empty():
		return
	var origin: Dictionary = {"column": completed.a.column, "row": completed.a.row,
		"width": 1, "height": 1, "level": level}
	_blast_queue.append({"event_id": str(completed.attempt_id), "level": level,
		"origin": origin, "target_ids": targets})


func _start_pending_blast() -> void:
	if _blast_queue.is_empty() or powerup_active() or collection_batch_active() or not fusions.is_empty() \
		or _held_tile_id >= 0 or _dragged_tile_id >= 0 or paused or phase != "playing":
		return
	var origins: Dictionary = {}
	var targets: Array[int] = []
	var level: int = 1
	var event_id: String = str(_blast_queue[0].event_id)
	# Batch pickups keep their accepted bodies; overlapping blasts share one
	# bounded marking beat and consume each captured body at most once.
	for blast: Dictionary in _blast_queue:
		level = maxi(level, int(blast.level))
		for id: int in blast.target_ids:
			if cell(id).is_empty():
				continue
			if not origins.has(id):
				targets.append(id)
			if not origins.has(id) or int(origins[id].level) < int(blast.level):
				origins[id] = blast.origin.duplicate()
	_blast_queue.clear()
	if targets.is_empty():
		return
	var distances: Dictionary = {}
	for id: int in targets:
		var target: Dictionary = cell(id)
		distances[id] = Vector2(float(target.column) - float(origins[id].column),
			float(target.row) - float(origins[id].row)).length_squared()
	targets.sort_custom(func(a: int, b: int) -> bool:
		return a < b if is_equal_approx(float(distances[a]), float(distances[b])) else distances[a] < distances[b])
	_begin_powerup_timeline("blast", "blast:" + event_id)
	var group_size: int = maxi(1, ceili(targets.size() / 6.0))
	var groups: int = ceili(float(targets.size()) / group_size)
	var first_impact: float = BLAST_MARK_WINDUP_SECONDS + BLAST_MARK_FLIGHT_SECONDS
	_powerup.stage = "mark"
	_powerup.duration = first_impact + (groups - 1) * BLAST_MARK_BEAT_SECONDS
	_powerup.blast = {"level": level, "target_ids": targets, "origins": origins,
		"marked": 0, "group_size": group_size, "next_mark_at": first_impact, "used_ids": {}}
	cue_requested.emit("blast_wave")


func _next_blast_merge() -> Dictionary:
	for id: int in _powerup.blast.target_ids:
		if _powerup.blast.used_ids.has(id):
			continue
		var source: Dictionary = cell(id)
		if source.is_empty() or not is_settled(source) or is_fusing(id) or is_lifted(id) or _reserved_for_powerup(id):
			continue
		for target: Dictionary in cells:
			var target_id: int = int(target.id)
			if target_id == id or not _powerup_ids.has(target_id) or not is_settled(target) \
				or is_fusing(target_id) or is_lifted(target_id) or _reserved_for_powerup(target_id):
				continue
			if parts_compatible(source, target) and can_merge(source, target):
				return {"source_id": id, "target_id": target_id, "reverse": false}
			if parts_compatible(target, source) and can_merge(target, source):
				return {"source_id": id, "target_id": target_id, "reverse": true}
	return {}


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


func _powerup_pair(captured_only: bool = true) -> Array[int]:
	var plan: Dictionary = authored_completion_plan(captured_only)
	if plan.get("status") == "complete":
		return [int(plan.first_source_id), int(plan.first_target_id)]
	return []


func _next_powerup_merge() -> Dictionary:
	if str(_powerup.kind) == "blast":
		return _next_blast_merge()
	# Independent paths may overlap, while each path keeps its future roots and
	# picture reserved until its final result exists. Prefer ready continuations.
	for plan: Dictionary in _powerup.plans:
		var job: Dictionary = _powerup_plan_job(plan)
		if not job.is_empty():
			return job
	var plan: Dictionary = authored_completion_plan(true)
	if plan.get("status") != "complete":
		return {}
	plan.plan_id = int(_powerup.next_plan_id)
	_powerup.next_plan_id = int(_powerup.next_plan_id) + 1
	plan.result_ids = {}
	plan.launched_steps = {}
	plan.reserved_ids = []
	# The resolver's input table also contains unused roots. Reserve only the
	# references actually consumed by this complete path so others can launch.
	for pending: Dictionary in plan.steps:
		for key: String in ["left_ref", "right_ref"]:
			var reference: String = str(pending[key])
			if reference.begins_with("input:"):
				var tile_id: int = _plan_tile_id(plan, reference)
				if not plan.reserved_ids.has(tile_id):
					plan.reserved_ids.append(tile_id)
	_powerup.plans.append(plan)
	return _powerup_plan_job(plan)


func _powerup_plan_job(plan: Dictionary) -> Dictionary:
	for index in range(plan.steps.size()):
		if plan.launched_steps.has(index):
			continue
		var pending: Dictionary = plan.steps[index]
		var source_id: int = _plan_tile_id(plan, str(pending.left_ref))
		var target_id: int = _plan_tile_id(plan, str(pending.right_ref))
		var source: Dictionary = cell(source_id)
		var target: Dictionary = cell(target_id)
		if source.is_empty() or target.is_empty() or not is_settled(source) or not is_settled(target) \
			or is_fusing(source_id) or is_fusing(target_id) or is_lifted(source_id) or is_lifted(target_id):
			continue
		if can_merge(source, target):
			return {"plan": plan, "step_index": index, "source_id": source_id, "target_id": target_id}
	return {}


func _plan_tile_id(plan: Dictionary, reference: String) -> int:
	if reference.begins_with("input:"):
		return int(plan.input_ids[int(reference.trim_prefix("input:"))])
	return int(plan.result_ids.get(int(reference.trim_prefix("step:")), -1))


func _reserved_for_powerup(tile_id: int) -> bool:
	if not _authored_auto_active():
		return false
	for drag: Dictionary in _powerup.drags:
		if tile_id in [int(drag.source_id), int(drag.target_id)]:
			return true
	for plan: Dictionary in _powerup.plans:
		if plan.reserved_ids.has(tile_id) or plan.result_ids.values().has(tile_id):
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


func _prepare_powerup_fragments(receipt_id: String) -> void:
	var total: int = _rng.randi_range(CoinEconomy.TREASURE_FRAGMENT_MIN, CoinEconomy.TREASURE_FRAGMENT_MAX)
	var start: float = float(_powerup.elapsed)
	var pending_counts: Dictionary = {}
	for tile: Dictionary in cells:
		pending_counts[int(tile.id)] = int(tile.fragments)
	for arrival: Dictionary in _powerup.arrivals:
		if not bool(arrival.arrived):
			pending_counts[int(arrival.tile_id)] = int(pending_counts[int(arrival.tile_id)]) + 1
	for index in range(total):
		var candidates: Array[int] = []
		for id: int in _powerup_ids:
			if int(pending_counts[id]) == 0:
				candidates.append(id)
		if candidates.is_empty():
			candidates = _powerup_ids.duplicate()
		var id: int = candidates[_rng.randi_range(0, candidates.size() - 1)]
		pending_counts[id] = int(pending_counts[id]) + 1
		_powerup.arrivals.append({"tile_id": id, "index": _powerup.arrivals.size(),
			"receipt_id": receipt_id, "total": total,
			"at": start + POWERUP_FRAGMENT_FLIGHT + index * POWERUP_FRAGMENT_STAGGER,
			"launched": false, "arrived": false})
	_powerup.stage = "arrivals"
	_powerup.total = int(_powerup.total) + total
	_powerup.duration = maxf(float(_powerup.duration), start + POWERUP_FRAGMENT_FLIGHT + (total - 1) * POWERUP_FRAGMENT_STAGGER + POWERUP_FRAGMENT_RECOVERY)


func _advance_powerup() -> void:
	if not bool(_powerup.get("active", false)) or paused or phase != "playing":
		return
	var generation: int = _generation
	var receipt_id: String = str(_powerup.receipt_id)
	if str(_powerup.kind) == "blast" and str(_powerup.stage) == "mark":
		var blast: Dictionary = _powerup.blast
		while int(blast.marked) < blast.target_ids.size() and float(_powerup.elapsed) + EPSILON >= float(blast.next_mark_at):
			blast.marked = mini(blast.target_ids.size(), int(blast.marked) + int(blast.group_size))
			blast.next_mark_at = float(blast.next_mark_at) + BLAST_MARK_BEAT_SECONDS
			cue_requested.emit("blast_mark")
			if not _same_powerup(generation, receipt_id) or paused:
				return
		if float(_powerup.elapsed) + EPSILON < float(_powerup.duration):
			return
		_powerup.stage = "ready"
		_powerup.elapsed = 0.0
		_powerup.duration = BLAST_MARK_RECOVERY_SECONDS
		_powerup.next_launch_at = float(_powerup.clock) + BLAST_MARK_RECOVERY_SECONDS
	if str(_powerup.kind) == "blast" and str(_powerup.stage) == "ready" and int(_powerup.total) == 0 \
		and float(_powerup.clock) + EPSILON < float(_powerup.next_launch_at):
		return
	if str(_powerup.kind) == "fragments":
		for arrival: Dictionary in _powerup.arrivals.duplicate():
			if bool(arrival.arrived):
				continue
			if not bool(arrival.launched) and float(_powerup.elapsed) + EPSILON >= float(arrival.at) - POWERUP_FRAGMENT_FLIGHT:
				# Commit before presentation callbacks may pause, drain, or replace
				# this delivery. Resuming never replays an already visible launch.
				arrival.launched = true
				cue_requested.emit("powerup_fragment_launch")
				if not _same_powerup(generation, receipt_id) or paused:
					return
			if bool(arrival.arrived) or float(_powerup.elapsed) + EPSILON < float(arrival.at):
				continue
			arrival.arrived = true
			var index: int = _index_for_id(int(arrival.tile_id))
			if index < 0:
				continue
			_grant_powerup_fragment(cells[index])
			_powerup.completed = int(_powerup.completed) + 1
			powerup_fragment_arrived.emit({"tile_id": int(arrival.tile_id), "index": int(arrival.index),
				"total": int(arrival.total), "fragments": int(cells[index].fragments),
				"receipt_id": str(arrival.receipt_id), "timeline_id": receipt_id, "at": float(arrival.at)})
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
		try_merge(int(drag.source_id), int(drag.target_id), true, drag)
		_powerup_committing = false
		if not _same_powerup(generation, receipt_id) or paused:
			return
	# Start one journey per beat even while an independent journey is in flight.
	# A dependent step waits for its result to settle and joins a later beat.
	var launch_ready: bool = float(_powerup.clock) + EPSILON >= float(_powerup.next_launch_at)
	var job: Dictionary = {}
	# Search once per beat during motion; avoid rerunning the authored resolver
	# on every render frame while all usable paths are already reserved.
	if launch_ready or (_powerup.drags.is_empty() and fusions.is_empty() and _settling_remaining() <= EPSILON):
		job = _next_powerup_merge()
	if launch_ready:
		# Empty beats are skipped, never accumulated into a burst when a result
		# becomes ready. Pause freezes this same model clock.
		_powerup.next_launch_at = float(_powerup.next_launch_at) + POWERUP_MERGE_BEAT_SECONDS
	if not job.is_empty() and launch_ready:
		var is_blast: bool = str(_powerup.kind) == "blast"
		if is_blast:
			_powerup.blast.used_ids[int(job.source_id)] = true
			_powerup.blast.used_ids[int(job.target_id)] = true
		else:
			job.plan.launched_steps[int(job.step_index)] = true
		var drag: Dictionary = {"source_id": int(job.source_id), "target_id": int(job.target_id),
			"source": cell(int(job.source_id)), "target": cell(int(job.target_id)), "elapsed": 0.0,
			"plan_id": -1 if is_blast else int(job.plan.plan_id), "step_index": -1 if is_blast else int(job.step_index),
			"reverse": bool(job.get("reverse", false)),
			"duration": POWERUP_DRAG_SECONDS, "started_at": float(_powerup.clock),
			"contact_played": false, "contact_pending": false}
		_powerup.drags.append(drag)
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
	if job.is_empty():
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
	# A newly available pair waits for the next scheduled beat.
	_powerup.stage = "ready"
	_powerup.elapsed = 0.0
	_powerup.duration = maxf(0.0, float(_powerup.next_launch_at) - float(_powerup.clock))


func _powerup_boundary() -> float:
	if not bool(_powerup.get("active", false)):
		return INF
	if str(_powerup.kind) == "fragments":
		var next: float = maxf(0.0, float(_powerup.duration) - float(_powerup.elapsed))
		for arrival: Dictionary in _powerup.arrivals:
			if not bool(arrival.arrived):
				if not bool(arrival.launched):
					next = minf(next, maxf(0.0, float(arrival.at) - POWERUP_FRAGMENT_FLIGHT - float(_powerup.elapsed)))
				next = minf(next, maxf(0.0, float(arrival.at) - float(_powerup.elapsed)))
		return next
	if str(_powerup.kind) == "blast" and str(_powerup.stage) == "mark":
		var boundary: float = maxf(0.0, float(_powerup.duration) - float(_powerup.elapsed))
		if float(_powerup.elapsed) + EPSILON < BLAST_FREEZE_SECONDS:
			boundary = minf(boundary, BLAST_FREEZE_SECONDS - float(_powerup.elapsed))
		if int(_powerup.blast.marked) < _powerup.blast.target_ids.size():
			boundary = minf(boundary, maxf(0.0, float(_powerup.blast.next_mark_at) - float(_powerup.elapsed)))
		return boundary
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
	_powerup.plans.clear()
	_powerup.contact_played = false
	_powerup.contact_pending = false
	_held_tile_id = -1
	_powerup_ids.clear()
	_growth_pending = true
	_gravity_pending = true


func _grant_powerup_fragment(tile: Dictionary) -> void:
	tile.fragments = int(tile.fragments) + 1
	tile.chest = true


func try_merge(a_id: int, b_id: int, held_source: bool = false, powerup_job: Dictionary = {}) -> String:
	if _stage_ending and not _powerup_committing:
		return "ignored"
	if not _combo_pending.is_empty():
		return "ignored"
	if phase != "playing" or paused or collection_batch_active() or (powerup_active() and not _powerup_committing) or a_id == b_id or is_fusing(a_id) or is_fusing(b_id):
		return "ignored"
	var automatic: bool = _powerup_committing
	# The internal authorization is consumed before emitting any callbacks.
	_powerup_committing = false
	var a: Dictionary = cell(a_id)
	var b: Dictionary = cell(b_id)
	var target_ready: bool = is_settled(b) or (held_source and not automatic and is_contactable(b))
	if a.is_empty() or b.is_empty() or (not held_source and not is_settled(a)) or not target_ready or is_lifted(b_id):
		return "ignored"
	# Validate spelling and the full result rectangle before consuming IDs.
	var reverse: bool = automatic and bool(powerup_job.get("reverse", false))
	var candidate: Dictionary = merge_candidate(b, a, false) if reverse else merge_candidate(a, b)
	if reverse and candidate.status in ["partial", "complete"]:
		var destination: Vector2i = _drag_return_position(_occupied([a_id, b_id]), 1, 1, b)
		if destination.x < 0:
			candidate = {"status": "needs_room", "result": {}}
		else:
			candidate.result.column = destination.x
			candidate.result.row = destination.y
	if candidate.status == "needs_room":
		return "needs_room"
	if not candidate.status in ["partial", "complete"]:
		var generation: int = _generation
		_reset_combo()
		if generation != _generation:
			return "wrong"
		cue_requested.emit("wrong")
		return "wrong"
	var result: Dictionary = candidate.result
	result.id = _next_tile_id
	_next_tile_id += 1
	if automatic:
		result.assisted = true
		result.mastery_eligible = false
		if result.has("composition"):
			result.composition.assisted = true
			result.composition.mastery_eligible = false
	result.skin = int(b.get("skin", b.id))
	var active: Dictionary = {
		"operation": "merge", "automatic": automatic, "a_id": a_id, "b_id": b_id,
		"a": a.duplicate(true), "b": b.duplicate(true), "result": result,
		"word": result.word.duplicate(true), "attempt_id": _event_id("merge"),
		"composition_status": candidate.status,
		"merge_level": int(result.get("merge_level", 0)),
		"merge_kind": str(candidate.get("merge_kind", "roots")),
		"elapsed": 0.0, "duration": POWERUP_FUSION_SECONDS if automatic else FUSION_SECONDS,
		"pop_at": POWERUP_FUSION_SECONDS if automatic else FUSION_SECONDS,
		"popped": false
	}
	if automatic:
		active.powerup_plan_id = int(powerup_job.get("plan_id", -1))
		active.powerup_step_index = int(powerup_job.get("step_index", -1))
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


func hold_merge_for_drag(event_id: String, held: bool) -> bool:
	var index: int = _fusion_index(event_id)
	if index < 0 or str(fusions[index].operation) != "merge":
		return false
	if held and (phase != "playing" or paused or powerup_active() or collection_batch_active()):
		return false
	fusions[index].held_for_drag = held
	return true


func complete_merge_drag(event_id: String) -> void:
	var index: int = _fusion_index(event_id)
	if phase != "playing" or paused or index < 0 or not bool(fusions[index].get("held_for_drag", false)):
		return
	_complete_operation(event_id)


func collect(tile_id: int) -> bool:
	if _stage_ending or powerup_active() or collection_batch_active():
		return false
	return _begin_collection(tile_id)


static func collection_pop_seconds(level: int, batch: bool = false) -> float:
	if batch:
		return BATCH_POP_SECONDS
	match clampi(level, 1, MAX_MERGE_LEVEL):
		4: return 0.66
		5: return 0.72
		6: return 0.78
		7: return 0.84
		8: return 0.90
		9: return 0.96
	return POP_SECONDS


static func collection_seconds(level: int, batch: bool = false) -> float:
	if batch:
		return BATCH_BEAT_SECONDS
	return COLLECT_SECONDS + collection_pop_seconds(level) - POP_SECONDS


func _begin_collection(tile_id: int, batch_index: int = 0) -> bool:
	if batch_index > 0 and not auto_collect_unlocked() and not _stage_ending:
		return false
	if phase != "playing" or paused or powerup_active() or not _combo_pending.is_empty() or is_fusing(tile_id):
		return false
	var tile: Dictionary = cell(tile_id)
	if tile.is_empty() or not is_settled(tile) or not is_valid_word(tile) or is_lifted(tile_id):
		return false
	if not _collection_event_ids.has(tile_id):
		_collection_event_ids[tile_id] = _event_id("collect")
		# Eligible collections reserve one independent roll; retries reuse its outcome.
		var chance: float = coin_drop_chance_for_tile(tile)
		_collection_coin_rewards[_collection_event_ids[tile_id]] = coins_for_tile(tile) if chance > 0.0 and _coin_rng.randf() < chance else 0
	var active: Dictionary = {
		"operation": "collect", "a_id": tile_id, "b_id": tile_id,
		"a": tile.duplicate(true), "b": tile.duplicate(true), "result": {},
		"word": tile.word.duplicate(true), "attempt_id": str(_collection_event_ids[tile_id]),
		"merge_level": int(tile.get("merge_level", 1)),
		"mastery_eligible": _collection_mastery_eligible(tile),
		"coins": int(_collection_coin_rewards[_collection_event_ids[tile_id]]), "fragments": int(tile.fragments),
		"elapsed": 0.0, "duration": collection_seconds(int(tile.get("merge_level", 1)), batch_index > 0),
		"pop_at": collection_pop_seconds(int(tile.get("merge_level", 1)), batch_index > 0),
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


func _collection_mastery_eligible(tile: Dictionary) -> bool:
	if bool(tile.get("mastery_eligible", false)):
		return true
	var word: Dictionary = tile.get("word", {})
	return bool(tile.get("assisted", false)) and (_has_word_picture(word)
		or str(word.get("morphology", {}).get("kind", "atomic")) != "atomic")


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


func set_pip_level(level: int) -> void:
	var next_level: int = maxi(0, level)
	if pip_level == next_level:
		return
	pip_level = next_level
	if not auto_collect_unlocked() and collection_batch_active():
		cancel_collection_batch()
	else:
		changed.emit()


func auto_collect_unlocked() -> bool:
	return pip_level >= AUTO_COLLECT_UNLOCK_LEVEL


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
	if (not auto_collect_unlocked() and not _stage_ending) or not _combo_pending.is_empty():
		return false
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
	if not auto_collect_unlocked() and not _stage_ending:
		cancel_collection_batch()
		return
	if not collection_batch_active() or phase != "playing" or paused:
		return
	# Let existing motion finish once, then keep the captured bodies in place
	# so later gravity or growth cannot stretch the collection beat.
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
	if phase != "playing" or paused or _powerup_purchasing or not _combo_pending.is_empty() or not is_finite(delta) or delta <= 0.0:
		return
	var generation: int = _generation
	var remaining: float = delta
	while remaining > EPSILON and _can_continue(generation):
		_pump_stage_finish()
		if not _can_continue(generation) or (_stage_ending and not error.is_empty()):
			break
		_start_pending_blast()
		if not _can_continue(generation):
			break
		_resume_pending_motion()
		_advance_collection_batch()
		_advance_powerup()
		if not _can_continue(generation):
			break
		if _finishing_powerup and not powerup_active():
			break
		var powerup_running: bool = powerup_active()
		var time_scale: float = gameplay_time_scale()
		var combo_running: bool = combo_count > 0 and not powerup_running and not _has_pending_collection_commit()
		var stage_clock: bool = _stage_clock_running()
		var consumed: float = remaining
		if stage_clock and stage_run.kind == "main":
			consumed = minf(consumed, maxf(0.0, stage_run.remaining))
		if combo_running:
			consumed = minf(consumed, maxf(0.0, _combo_remaining))
		consumed = minf(consumed, _collection_batch_boundary())
		consumed = minf(consumed, _powerup_boundary())
		if time_scale > 0.0:
			consumed = minf(consumed, _next_drag_gravity_boundary() / time_scale)
			if _growth_pending and _settling_remaining() > EPSILON:
				consumed = minf(consumed, _settling_remaining() / time_scale)
			if _gravity_pending and _next_settlement() > EPSILON:
				consumed = minf(consumed, _next_settlement() / time_scale)
		for active in fusions:
			if bool(active.get("commit_pending", false)):
				continue
			var boundary: float = float(active.duration)
			if str(active.operation) == "collect" and not bool(active.popped):
				boundary = float(active.pop_at)
			if time_scale > 0.0:
				consumed = minf(consumed, maxf(0.0, boundary - float(active.elapsed)) / time_scale)
		var full: bool = not _has_free_cell()
		var ending_wait: bool = _finish_after_collection_commit or _stage_ending
		var danger_running: bool = full and full_elapsed >= 0.0 and not powerup_running and not ending_wait and stage_run == null
		var next_second: float = minf(FULL_SECONDS, floorf(full_elapsed + EPSILON) + 1.0)
		if danger_running:
			consumed = minf(consumed, maxf(0.0, next_second - full_elapsed))
		elif full and not powerup_running and not ending_wait:
			var settling: float = _settling_remaining()
			if stage_run == null or settling > EPSILON:
				consumed = minf(consumed, maxf(0.0, settling))
		elif not powerup_running and not ending_wait:
			consumed = minf(consumed, maxf(0.0, spawn_interval - spawn_elapsed))
		# Mark impacts keep real-time deadlines while only the board's motion slows.
		var motion_delta: float = consumed * time_scale
		for tile in cells:
			tile.age = float(tile.age) + motion_delta
			tile.settling = float(tile.age) + EPSILON < settle_duration(tile)
			if tile.has("settle_seconds") and not bool(tile.settling):
				# The short landing belongs only to this automatic merge. Later
				# manual drops and gravity use the ordinary body motion again.
				tile.erase("settle_seconds")
				tile.age = maxf(float(tile.age), SETTLE_SECONDS)
		for active in fusions:
			if not bool(active.get("commit_pending", false)):
				active.elapsed = float(active.elapsed) + motion_delta
		_advance_drag_gravity_delays(motion_delta)
		if powerup_running:
			_powerup.elapsed = float(_powerup.elapsed) + consumed
			_powerup.clock = float(_powerup.clock) + consumed
			if _authored_auto_active():
				for drag: Dictionary in _powerup.drags:
					drag.elapsed = minf(float(drag.duration), float(drag.elapsed) + consumed)
				_sync_powerup_drag()
		if collection_batch_active():
			_collection_batch_elapsed += consumed
			_collection_batch_next_in = maxf(0.0, _collection_batch_next_in - consumed)
		if danger_running:
			full_elapsed += consumed
		elif not full and not powerup_running and not ending_wait:
			spawn_elapsed += consumed
		remaining -= consumed
		if _stage_ending:
			_stage_clear_feedback = maxf(0.0, _stage_clear_feedback - consumed)
		if stage_clock:
			stage_run.advance(consumed)
		if combo_running:
			_combo_remaining = maxf(0.0, _combo_remaining - consumed)
			if _combo_remaining <= EPSILON:
				_reset_combo()
				if not _can_continue(generation):
					break
		for active in fusions.duplicate():
			if not _can_continue(generation):
				break
			if _fusion_index(str(active.attempt_id)) < 0:
				continue
			if bool(active.get("commit_pending", false)):
				continue
			if str(active.operation) == "collect" and not bool(active.popped) and float(active.elapsed) + EPSILON >= float(active.pop_at):
				active.popped = true
				var merge_level: int = clampi(int(active.get("merge_level", 1)), 1, MAX_MERGE_LEVEL)
				cue_requested.emit("pop" if merge_level == 1 else "jelly-collect-lv%d" % merge_level)
				if not _can_continue(generation):
					break
			if float(active.elapsed) + EPSILON >= float(active.duration):
				_complete_operation(str(active.attempt_id))
			if not _combo_pending.is_empty():
				return
		if not _can_continue(generation):
			break
		if stage_run != null and not _stage_ending:
			_resume_pending_motion()
			if stage_run.outcome == "cleared":
				_decide_stage("cleared")
			elif stage_clock and stage_run.check_deadline():
				_decide_stage("timeout")
			elif not powerup_active() and not _has_free_cell() and _settling_remaining() <= EPSILON and fusions.is_empty():
				_decide_stage("blocked")
		_pump_stage_finish()
		if not _can_continue(generation):
			break
		_resume_pending_motion()
		_advance_collection_batch()
		_advance_powerup()
		if not _can_continue(generation):
			break
		if powerup_running or _finish_after_collection_commit or _stage_ending:
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
					finish_round("danger")
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
	if powerup_active() or (not _combo_pending.is_empty() and tile_id >= 0) or (collection_batch_active() and tile_id >= 0):
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
	if _stage_ending or phase != "playing" or paused or not _combo_pending.is_empty() or powerup_active() or collection_batch_active() \
		or tile_id != _held_tile_id or is_fusing(tile_id):
		return false
	if _dragged_tile_id == tile_id:
		return true
	var index: int = _index_for_id(tile_id)
	if index < 0 or _dragged_tile_id >= 0 or not is_settled(cells[index]):
		return false
	var source: Dictionary = cells[index]
	if source.has("composition") and _drag_return_after_motion(source).x < 0:
		drag_blocked.emit("needs_room")
		return false
	_delay_drag_support(source)
	_drag_gravity_delays.erase(tile_id)
	_dragged_tile_id = tile_id
	source.lifted = true
	_resume_pending_motion()
	changed.emit()
	return true


func _delay_drag_support(source: Dictionary) -> void:
	for tile: Dictionary in cells:
		if int(tile.id) == int(source.id) or bool(tile.get("lifted", false)):
			continue
		if int(tile.row) + int(tile.height) == int(source.row) \
			and int(tile.column) < int(source.column) + int(source.width) \
			and int(source.column) < int(tile.column) + int(tile.width):
			# Keeping the direct child in place also supports the rest of its stack.
			_drag_gravity_delays[int(tile.id)] = DRAG_GRAVITY_DELAY_SECONDS
			_gravity_pending = true


func _next_drag_gravity_boundary() -> float:
	var boundary: float = INF
	for remaining: float in _drag_gravity_delays.values():
		boundary = minf(boundary, remaining)
	return boundary


func _advance_drag_gravity_delays(delta: float) -> void:
	for tile_id: int in _drag_gravity_delays.keys():
		var remaining: float = float(_drag_gravity_delays[tile_id]) - delta
		if remaining <= EPSILON or _index_for_id(tile_id) < 0:
			_drag_gravity_delays.erase(tile_id)
			_gravity_pending = true
		else:
			_drag_gravity_delays[tile_id] = remaining


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
	if position.x < 0 and not tile.has("composition"):
		# Retain as much of the original body as possible if falling stacks have
		# fragmented its old space. Mass, word data and fragments remain intact.
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
	if position.x < 0:
		return
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


func _drag_return_after_motion(anchor: Dictionary, additional: Dictionary = {}) -> Vector2i:
	# Keep a return rectangle outside every remaining body's vertical fall path.
	# This projection owns only geometry: it never moves live bodies, advances
	# operations, pays rewards, or uses the return reservation as support.
	var occupied: Dictionary = {}
	var current: Array[Dictionary] = []
	var projected: Array[Dictionary] = []
	var consumed: Array[int] = []
	var reserved: Dictionary = {}
	for active: Dictionary in fusions:
		consumed.append(int(active.a_id))
		consumed.append(int(active.b_id))
		if str(active.operation) == "merge":
			projected.append(active.result.duplicate())
			_occupy(reserved, int(active.result.column), int(active.result.row), int(active.result.width), int(active.result.height))
	for tile: Dictionary in cells:
		if int(tile.id) == int(anchor.id) or bool(tile.get("lifted", false)):
			continue
		current.append(tile.duplicate())
	if not additional.is_empty():
		current.append(additional.duplicate())
	# Project the positions neighbors will commit after the support delay. The
	# return reservation must remain available once that delayed fall begins.
	current.sort_custom(_gravity_order)
	for tile: Dictionary in current:
		if int(tile.id) in consumed or not is_settled(tile):
			continue
		var obstacles: Dictionary = reserved.duplicate()
		for other: Dictionary in current:
			if int(other.id) != int(tile.id):
				_occupy(obstacles, int(other.column), int(other.row), int(other.width), int(other.height))
		while int(tile.row) + int(tile.height) < ROWS and _fits(obstacles, int(tile.column), int(tile.row) + 1, int(tile.width), int(tile.height)):
			tile.row = int(tile.row) + 1
	for tile: Dictionary in current:
		_occupy(occupied, int(tile.column), int(tile.row), int(tile.width), int(tile.height))
		if not int(tile.id) in consumed:
			projected.append(tile)
	projected.sort_custom(_gravity_order)
	for tile: Dictionary in projected:
		var obstacles: Dictionary = {}
		for other: Dictionary in projected:
			if int(other.id) != int(tile.id):
				_occupy(obstacles, int(other.column), int(other.row), int(other.width), int(other.height))
		var start_row: int = int(tile.row)
		var row: int = start_row
		while row + int(tile.height) < ROWS and _fits(obstacles, int(tile.column), row + 1, int(tile.width), int(tile.height)):
			row += 1
		_occupy(occupied, int(tile.column), start_row, int(tile.width), int(tile.height) + row - start_row)
		tile.row = row
	return _drag_return_position(occupied, int(anchor.width), int(anchor.height), anchor)


func can_reposition(tile_id: int, column: int, row: int) -> bool:
	if _stage_ending or phase != "playing" or paused or not _combo_pending.is_empty() or powerup_active() or collection_batch_active() or is_fusing(tile_id):
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
	if changed_position and not is_lifted(tile_id):
		_delay_drag_support(tile)
	_drag_gravity_delays.erase(tile_id)
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
	return not _stage_ending and phase == "playing" and not paused and _combo_pending.is_empty() and not powerup_active() and not collection_batch_active() and not _first_preview_tile().is_empty() and _has_free_cell()


func drop_now(expected_first_id: int = -1) -> bool:
	var first: Dictionary = _first_preview_tile()
	if not can_drop_now() or (expected_first_id != -1 and expected_first_id != int(first.get("id", -1))):
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


func is_contactable(tile: Dictionary) -> bool:
	if tile.is_empty() or is_fusing(int(tile.id)) or is_lifted(int(tile.id)):
		return false
	if is_settled(tile):
		return true
	# A falling body can receive a held drop before landing. Scheduled arrivals
	# remain owned by the supply tray until their individual departure begins.
	if bool(tile.get("arrival", false)):
		return float(tile.age) + EPSILON >= arrival_delay(tile)
	return bool(tile.get("falling", false))


static func arrival_contact_at(tile: Dictionary) -> float:
	return arrival_delay(tile) + Motion.contact_at(tile)


static func arrival_delay(tile: Dictionary) -> float:
	return maxf(0.0, float(tile.get("arrival_delay", _scheduled_arrival_delay(int(tile.get("arrival_index", 0))))))


static func _scheduled_arrival_delay(slot: int) -> float:
	return float(maxi(0, ARRIVAL_ORDER.find(slot))) * ARRIVAL_STAGGER


static func settle_duration(tile: Dictionary) -> float:
	if bool(tile.get("arrival", false)):
		return arrival_delay(tile) + Motion.ready_at(tile)
	return float(tile.get("settle_seconds", SETTLE_SECONDS))


func is_valid_word(tile: Dictionary) -> bool:
	if tile.has("jelly_kind"):
		return tile.jelly_kind == "merged" and not tile.get("word", {}).is_empty()
	if tile.has("composition"):
		return bool(tile.composition.get("complete", false)) and not tile.get("word", {}).is_empty()
	return int(tile.get("mass", 0)) > 1 and not tile.get("word", {}).is_empty()


static func coin_drop_chance_for_tile(tile: Dictionary) -> float:
	if str(tile.get("jelly_kind", "")) != "merged" or tile.get("word", {}).is_empty():
		return 0.0
	return CoinEconomy.jelly_bonus_chance(int(tile.get("merge_level", 0)))


static func coins_for_tile(tile: Dictionary) -> int:
	# Potential collection bonus: level governs it independently of roots or mass.
	if str(tile.get("jelly_kind", "")) != "merged" or tile.get("word", {}).is_empty():
		return 0
	return CoinEconomy.jelly_bonus(int(tile.get("merge_level", 0)))


func score() -> int:
	return cleared_pairs


static func reward_progress(total: int) -> Dictionary:
	return RewardProgress.reward_progress(total)


func snapshot() -> Dictionary:
	var state: Dictionary = {
		"cells": cells.duplicate(true), "upcoming": upcoming.duplicate(true),
		"fusion": fusion.duplicate(true), "fusions": fusions.duplicate(true),
		"phase": phase, "paused": paused, "cleared_pairs": cleared_pairs, "score": score(),
		"collected_coins": collected_coins, "merged_count": merged_count, "combo": combo_snapshot(),
		"chest_count": chest_count, "generated_tiles": generated_tiles,
		"spawn_interval": spawn_interval, "spawn_elapsed": spawn_elapsed, "full_elapsed": full_elapsed,
		"full_remaining": maxf(0.0, FULL_SECONDS - full_elapsed) if full_elapsed >= 0.0 else -1.0,
		"collectable_ids": collectable_ids(),
		"collection_batch": collection_batch_snapshot(),
		"max_merge_level": MAX_MERGE_LEVEL,
		"pip_level": pip_level, "auto_collect_unlocked": auto_collect_unlocked(),
		"auto_collect_unlock_level": AUTO_COLLECT_UNLOCK_LEVEL,
		"powerup": powerup_snapshot(),
		"campaign": stage_run.snapshot() if stage_run != null else {},
		"stage_ending": _stage_ending, "fall_speed_scale": fall_speed_scale,
		"hit_stop": hit_stop_snapshot(),
		"queued_blasts": _blast_queue.size(),
		"powerup_uses": _powerup_uses.duplicate(),
		"powerup_prices": {"auto_merge": powerup_price("auto_merge"), "fragments": powerup_price("fragments"),
			"extra_time": powerup_price("extra_time")},
		"error": error, "result": _result.duplicate(true)
	}
	state.authored_morphology = authored_morphology
	state.merge(reward_progress(fragment_count), true)
	return state


func finish_round(reason: String = "finished") -> Dictionary:
	if stage_run != null and not _stage_finalizing and phase != "finished":
		if _powerup_purchasing:
			_finish_after_purchase = true
			return _result.duplicate(true)
		if _combo_committing:
			_finish_after_combo = true
			return _result.duplicate(true)
		_decide_stage("blocked" if reason == "danger" else "timeout" if reason == "timeout" else "exit")
		return _result.duplicate(true)
	if phase == "finished" or _finishing_powerup:
		return _result.duplicate(true)
	# Payment and accepted-power settlement can reenter this method. Keep the
	# original ending cause until that round's final result has been emitted.
	if _finish_reason.is_empty():
		_finish_reason = reason
	if _combo_committing:
		_finish_after_combo = true
		return _result.duplicate(true)
	if _powerup_purchasing:
		_finish_after_purchase = true
		return _result.duplicate(true)
	if _has_pending_collection_commit():
		_finish_after_collection_commit = true
		return _result.duplicate(true)
	var generation: int = _generation
	_blast_queue.clear()
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
	_combo_remaining = 0.0
	fusions.clear()
	_dragged_tile_id = -1
	_held_tile_id = -1
	_drag_gravity_delays.clear()
	for tile: Dictionary in cells:
		tile.lifted = false
	_combo_pending = ""
	_result = {"reason": _finish_reason, "cleared_pairs": cleared_pairs, "score": score(), "coins": collected_coins + combo_coins,
		"combo_coins": combo_coins, "best_combo": combo_best, "words": []}
	_result.merge(reward_progress(fragment_count), true)
	if stage_run != null:
		_result["campaign"] = stage_run.snapshot()
	for word in _completed_words.values():
		_result.words.append(word.duplicate(true))
	var result: Dictionary = _result.duplicate(true)
	finished.emit(result.duplicate(true))
	if generation == _generation:
		changed.emit()
	return result


func _eligible(word: Dictionary, level: int) -> bool:
	for key in ["id", "text", "audio"]:
		if not word.get(key) is String or str(word[key]).strip_edges().is_empty():
			return false
	if word.has("image") and not word.image is String:
		return false
	if str(word.get("track", "")) == "professional":
		return _reviewed_morphology(word) and word.get("practice_modes") is Array \
			and "word_jelly" in word.practice_modes
	# Growth resolution supplies an explicit review state. A pending or invalid
	# analysis must never turn back into the former midpoint spelling exercise.
	if word.has("morphology_status") or word.has("morphology"):
		if str(word.get("morphology_status", "reviewed")) != "reviewed" or not _reviewed_morphology(word):
			return false
	return (allow_cross_age or int(word.get("min_age", 3)) == clampi(level, 3, 12)) and not normalize_word(str(word.text)).is_empty()


static func _reviewed_morphology(word: Dictionary) -> bool:
	return word.get("morphology") is Dictionary and word.morphology.get("review") is Dictionary \
		and word.morphology.review.get("status") == "reviewed"


func _composition_state(tile: Dictionary) -> Dictionary:
	var state: Dictionary = tile.composition.duplicate(true)
	for key: String in ["id", "column", "row", "width", "height", "fragments"]:
		if tile.has(key):
			state[key] = tile[key]
	return state


func _composition_footprint(state: Dictionary) -> Dictionary:
	var signature: String = str(state.signature)
	if not _footprints.has(signature):
		# Spelling and composition describe content, never physical board size.
		# The view lays out the full spelling at its actual ordinary-cell scale.
		var text: String = str(state.text)
		var text_width: float = LABEL_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_footprints[signature] = {"width": 1, "height": 1, "lines": [text],
			"requires_read": text_width > 56.0, "label_reserved_width": 0.0}
	return _footprints[signature].duplicate(true)


func _new_composition_tile(state: Dictionary, allocate_id: bool = true) -> Dictionary:
	var semantic: String = _root_spelling(str(state.text))
	var tile: Dictionary = _new_tile(semantic, int(state.part_count), int(state.get("fragments", 0)), allocate_id)
	var layout: Dictionary = _composition_footprint(state)
	tile.composition = state.duplicate(true)
	var context: Dictionary = _composition_context(state)
	var candidate: Dictionary = {}
	if not context.is_empty() and str(context.node.id) in context.analysis.roots:
		candidate = _words_by_id.get(str(context.analysis.lexeme_id), {}).duplicate(true)
	tile.word = {}
	tile.word_candidate = candidate
	tile.image_word = {}
	tile.jelly_kind = "root"
	tile.kind = "part"
	tile.merge_level = 0
	tile.display_text = _root_caption(state)
	tile.assisted = bool(state.get("assisted", false))
	tile.mastery_eligible = false
	if not candidate.is_empty() and not _has_word_picture(candidate):
		_set_merged_word(tile, candidate, 1, bool(state.get("mastery_eligible", false)))
	tile.width = int(layout.width)
	tile.height = int(layout.height)
	tile.preferred_width = tile.width
	tile.preferred_height = tile.height
	tile.row = ROWS - int(tile.height)
	tile.requires_read = bool(layout.requires_read)
	tile.label_lines = [tile.display_text]
	tile.approved_break_offsets = []
	var prefix_trim: int = 1 if str(state.text).begins_with("-") else 0
	for offset: Variant in state.get("break_offsets", []):
		var semantic_offset: int = int(offset) - prefix_trim
		if semantic_offset > 0 and semantic_offset < semantic.length():
			tile.approved_break_offsets.append(offset if prefix_trim == 0 else semantic_offset)
	tile.label_reserved_width = layout.label_reserved_width
	return tile


static func _root_spelling(value: String) -> String:
	return value.trim_prefix("-").trim_suffix("-")


func _root_caption(state: Dictionary) -> String:
	var spelling: String = _root_spelling(str(state.text))
	# The authored span, not the part's incidental surface punctuation, tells
	# the player which sides still need another root. Prefer its source context.
	var context: Dictionary = _composition_context(state)
	if context.is_empty():
		return spelling
	return ("-" if int(context.node.start) > 0 else "") + spelling \
		+ ("-" if int(context.node.end) < context.analysis.parts.size() else "")


func _composition_context(state: Dictionary) -> Dictionary:
	# A planning resolver may restrict available targets. Context remains the
	# live round's authored context, so speculative and manual tiles agree.
	var candidates: Array = _morphology._states.get(str(state.get("signature", "")), state).get("candidates", [])
	var selected: Dictionary = {} if candidates.is_empty() else candidates[0]
	for origin: Variant in state.get("origins", []):
		for candidate: Dictionary in candidates:
			if candidate.analysis_id == origin.get("analysis_id", ""):
				selected = candidate
				break
		if not selected.is_empty() and selected.get("analysis_id") == origin.get("analysis_id", ""):
			break
	if selected.is_empty():
		return {}
	var analysis: Dictionary = _morphology._analyses.get(str(selected.analysis_id), {})
	var node: Dictionary = analysis.get("nodes", {}).get(str(selected.node_id), {})
	if node.is_empty():
		return {}
	return {"analysis": analysis, "node": node}


static func _has_word_picture(word: Dictionary) -> bool:
	return not str(word.get("image", "")).strip_edges().is_empty()


func _set_merged_word(tile: Dictionary, word: Dictionary, level: int, eligible: bool) -> void:
	tile.word = word.duplicate(true)
	tile.word_candidate = {}
	tile.image_word = word.duplicate(true) if _has_word_picture(word) else {}
	tile.text = str(word.text)
	tile.display_text = str(word.text)
	tile.jelly_kind = "merged"
	tile.kind = "word"
	tile.merge_level = clampi(level, 1, MAX_MERGE_LEVEL)
	tile.mastery_eligible = eligible and not bool(tile.get("assisted", false))
	tile.label_lines = [tile.display_text]


func _new_word_root(word: Dictionary, fragments: int = 0, allocate_id: bool = true) -> Dictionary:
	var tile: Dictionary = _new_tile(str(word.text), 1, fragments, allocate_id)
	tile.word_candidate = word.duplicate(true)
	if not _has_word_picture(word):
		# An image-less atomic word is available immediately, but merely seeing
		# it is not evidence of an independently solved spelling or picture match.
		_set_merged_word(tile, word, 1, false)
	return tile


func _new_picture_tile(word: Dictionary, fragments: int = 0, allocate_id: bool = true) -> Dictionary:
	var tile: Dictionary = _new_tile(str(word.text), 1, fragments, allocate_id)
	tile.jelly_kind = "picture"
	tile.kind = "picture"
	tile.display_text = ""
	tile.image_word = word.duplicate(true)
	tile.word_candidate = {}
	tile.label_lines = []
	return tile


func _joined_word_tile(left: Dictionary, right: Dictionary, word: Dictionary, level: int,
	eligible: bool) -> Dictionary:
	var tile: Dictionary = _new_tile(str(word.text), int(left.mass) + int(right.mass),
		int(left.fragments) + int(right.fragments), false)
	tile.assisted = bool(left.get("assisted", false)) or bool(right.get("assisted", false))
	_set_merged_word(tile, word, level, eligible)
	return tile


func _place_composition(left: Dictionary, right: Dictionary, state: Dictionary,
	board: Array = [], fixed_occupied: Dictionary = {}) -> Dictionary:
	var layout: Dictionary = _composition_footprint(state)
	var occupied: Dictionary
	if board.is_empty():
		occupied = _occupied([int(left.get("id", -1)), int(right.get("id", -1))])
	else:
		occupied = fixed_occupied.duplicate()
		for tile: Dictionary in board:
			var same_left: bool = tile.get("plan_ref", "") == left.get("plan_ref", "") if left.has("plan_ref") else tile.get("id") == left.get("id")
			var same_right: bool = tile.get("plan_ref", "") == right.get("plan_ref", "") if right.has("plan_ref") else tile.get("id") == right.get("id")
			if not same_left and not same_right:
				_occupy(occupied, int(tile.column), int(tile.row), int(tile.width), int(tile.height))
	# Search the whole board, including space below the target. Every accepted
	# result reserves its ordinary cell before the fusion starts.
	var position: Vector2i = _drag_return_position(occupied, int(layout.width), int(layout.height), right)
	return {"ok": position.x >= 0, "placement": {"column": position.x, "row": position.y,
		"width": int(layout.width), "height": int(layout.height)}}


func _resolve_composition(left: Dictionary, right: Dictionary) -> Dictionary:
	var resolved: Dictionary = _morphology.resolve(left, right)
	if str(resolved.get("reason", "")) != "ambiguous_sense":
		return resolved
	# A later stage can introduce another sense with the same spelling. Old
	# roots retain their original analysis, so matching origins disambiguate it.
	var shared: Dictionary = {}
	for left_origin: Dictionary in left.get("origins", []):
		for right_origin: Dictionary in right.get("origins", []):
			var analysis_id: String = str(left_origin.get("analysis_id", ""))
			if not analysis_id.is_empty() and analysis_id == str(right_origin.get("analysis_id", "")):
				shared[analysis_id] = true
	if shared.size() != 1:
		return resolved
	var analysis_id: String = str(shared.keys()[0])
	var analysis: Dictionary = _morphology._analyses.get(analysis_id, {})
	var word: Dictionary = _words_by_id.get(str(analysis.get("lexeme_id", "")), {})
	if word.is_empty():
		return resolved
	if not _sense_resolvers.has(analysis_id):
		var focused := MorphologyResolver.new()
		if not focused.configure([word.morphology]):
			return resolved
		_sense_resolvers[analysis_id] = focused
	var resolver: RefCounted = _sense_resolvers[analysis_id]
	return resolver.resolve(left, right)


func merge_candidate(left: Dictionary, right: Dictionary, check_space: bool = true) -> Dictionary:
	if left.is_empty() or right.is_empty() or int(left.get("id", -1)) == int(right.get("id", -2)):
		return {"status": "invalid", "result": {}}
	var left_kind: String = str(left.get("jelly_kind", "root"))
	var right_kind: String = str(right.get("jelly_kind", "root"))
	var tile: Dictionary = {}
	var merge_kind: String = "roots"
	if left_kind == "merged" and right_kind == "merged":
		var level: int = _merged_upgrade_level(left, right)
		if level == 0:
			return {"status": "invalid", "result": {}}
		tile = _joined_word_tile(left, right, left.word, level,
			bool(left.get("mastery_eligible", false)) or bool(right.get("mastery_eligible", false)))
		merge_kind = "upgrade"
	elif (left_kind == "root" and right_kind == "picture") or (left_kind == "picture" and right_kind == "root"):
		var root: Dictionary = left if left_kind == "root" else right
		var picture: Dictionary = right if right_kind == "picture" else left
		var candidate: Dictionary = root.get("word_candidate", {})
		if candidate.is_empty() or not _words_by_id.has(str(candidate.get("id", ""))) \
			or str(candidate.get("id", "")) != str(picture.get("image_word", {}).get("id", "")):
			return {"status": "invalid", "result": {}}
		tile = _joined_word_tile(left, right, candidate, 1, true)
		merge_kind = "picture"
	elif left_kind == "root" and right_kind == "root" and left.has("composition") and right.has("composition"):
		var resolved: Dictionary = _resolve_composition(_composition_state(left), _composition_state(right))
		if not resolved.status in ["partial", "complete"]:
			return {"status": resolved.status, "result": {}}
		tile = _new_composition_tile(resolved.tile, false)
	else:
		return {"status": "invalid", "result": {}}
	if check_space:
		var position: Vector2i = _drag_return_position(_occupied([int(left.id), int(right.id)]), 1, 1, right)
		if position.x < 0:
			return {"status": "needs_room", "result": {}}
		tile.column = position.x
		tile.row = position.y
	return {"status": "complete" if is_valid_word(tile) else "partial", "result": tile, "merge_kind": merge_kind}


func uses_authored_morphology() -> bool:
	return authored_morphology


static func _merged_upgrade_level(left: Dictionary, right: Dictionary) -> int:
	var word_id: String = str(left.get("word", {}).get("id", ""))
	if word_id.is_empty() or word_id != str(right.get("word", {}).get("id", "")):
		return 0
	var left_level: int = int(left.get("merge_level", 1))
	var right_level: int = int(right.get("merge_level", 1))
	if left_level < 1 or right_level < 1 or left_level > MAX_MERGE_LEVEL or right_level > MAX_MERGE_LEVEL:
		return 0
	return mini(left_level + right_level, MAX_MERGE_LEVEL)


func parts_compatible(left: Dictionary, right: Dictionary) -> bool:
	# Palette classification evaluates every visible pair; keep it semantic
	# without copying complete word records or constructing speculative tiles.
	if left.is_empty() or right.is_empty() or int(left.get("id", -1)) == int(right.get("id", -2)):
		return false
	var left_kind: String = str(left.get("jelly_kind", "root"))
	var right_kind: String = str(right.get("jelly_kind", "root"))
	if left_kind == "merged" and right_kind == "merged":
		return _merged_upgrade_level(left, right) > 0
	if left_kind == "picture" and right_kind == "root":
		return not right.get("word_candidate", {}).is_empty() \
			and _words_by_id.has(str(right.word_candidate.id)) \
			and str(right.word_candidate.id) == str(left.get("image_word", {}).get("id", ""))
	if left_kind == "root" and right_kind == "picture":
		return not left.get("word_candidate", {}).is_empty() \
			and _words_by_id.has(str(left.word_candidate.id)) \
			and str(left.word_candidate.id) == str(right.get("image_word", {}).get("id", ""))
	return left_kind == "root" and right_kind == "root" and left.has("composition") and right.has("composition") \
		and _resolve_composition(left.composition, right.composition).status in ["partial", "complete"]


func can_merge(left: Dictionary, right: Dictionary) -> bool:
	return merge_candidate(left, right).status in ["partial", "complete"]


func compatible_pairs(check_space: bool = true) -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	for left: Dictionary in cells:
		if not is_settled(left) or is_fusing(int(left.id)) or is_lifted(int(left.id)):
			continue
		for right: Dictionary in cells:
			if int(left.id) == int(right.id) or not is_settled(right) or is_fusing(int(right.id)) or is_lifted(int(right.id)):
				continue
			var candidate: Dictionary = merge_candidate(left, right, check_space)
			if candidate.status in ["partial", "complete"]:
				pairs.append({"source_id": int(left.id), "target_id": int(right.id), "status": candidate.status})
	return pairs


func authored_completion_plan(captured_only: bool = false) -> Dictionary:
	var available: Array[Dictionary] = []
	for tile: Dictionary in cells:
		if not is_settled(tile) or is_fusing(int(tile.id)) or is_lifted(int(tile.id)) \
			or (captured_only and not _powerup_ids.has(int(tile.id))) or _reserved_for_powerup(int(tile.id)):
			continue
		available.append(tile)
	if available.size() < 2:
		return {"status": "unavailable", "steps": []}
	# Completed spellings and upgrades are already complete one-step plans.
	for left: Dictionary in available:
		for right: Dictionary in available:
			if not parts_compatible(left, right):
				continue
			var direct: Dictionary = merge_candidate(left, right)
			if direct.status == "complete":
				return {"status": "complete", "steps": [{"left_ref": "input:0", "right_ref": "input:1",
					"result_ref": "step:0", "result": direct.result.duplicate(true),
					"placement": {"column": direct.result.column, "row": direct.result.row, "width": 1, "height": 1}}],
					"tile": direct.result.duplicate(true), "input_ids": [int(left.id), int(right.id)],
					"first_source_id": int(left.id), "first_target_id": int(right.id), "placement_checked": true}
	var pictures: Dictionary = {}
	for tile: Dictionary in available:
		if str(tile.get("jelly_kind", "")) == "picture":
			pictures[str(tile.image_word.id)] = tile
	# Do not charge for a spelling-only path whose required picture is absent.
	# Restrict the resolver to targets that can actually finish on this board.
	var analyses: Array = []
	for word: Dictionary in _words_by_id.values():
		if _authored_words.has(str(word.id)) and (not _has_word_picture(word) or pictures.has(str(word.id))):
			analyses.append(word.morphology)
	if analyses.is_empty():
		return {"status": "unavailable", "steps": []}
	var plan: Dictionary = _authored_spelling_plan(available, pictures, analyses)
	if plan.status == "complete":
		return plan
	# Cumulative stage definitions can contain identical spellings with different
	# senses. Retry a single authored context without mixing its root origins.
	var spellings: Dictionary = {}
	for analysis: Dictionary in analyses:
		var spelling: String = normalize_word(str(analysis.text))
		spellings[spelling] = int(spellings.get(spelling, 0)) + 1
	for analysis: Dictionary in analyses:
		if int(spellings[normalize_word(str(analysis.text))]) > 1:
			plan = _authored_spelling_plan(available, pictures, [analysis], str(analysis.id))
			if plan.status == "complete":
				return plan
	return plan


func _authored_spelling_plan(available: Array[Dictionary], pictures: Dictionary,
	analyses: Array, origin_analysis: String = "") -> Dictionary:
	var resolver := MorphologyResolver.new()
	if not resolver.configure(analyses):
		return {"status": "unavailable", "steps": []}
	var states: Array = []
	var ids: Array[int] = []
	for tile: Dictionary in available:
		if str(tile.get("jelly_kind", "root")) == "root" and tile.has("composition") \
			and resolver._states.has(str(tile.composition.signature)):
			if not origin_analysis.is_empty() and not tile.composition.get("origins", []).any(
				func(origin: Dictionary) -> bool: return str(origin.get("analysis_id", "")) == origin_analysis):
				continue
			states.append(_composition_state(tile))
			ids.append(int(tile.id))
	if states.size() < 2:
		return {"status": "unavailable", "steps": []}
	var fixed: Dictionary = _occupied(ids)
	var fit: Callable = func(a: Dictionary, b: Dictionary, result: Dictionary, board: Array) -> Dictionary:
		return _place_composition(a, b, result, board, fixed)
	var accept: Callable = func(state: Dictionary) -> bool:
		var tile: Dictionary = _new_composition_tile(state, false)
		return is_valid_word(tile) or (not tile.word_candidate.is_empty() and pictures.has(str(tile.word_candidate.id)))
	var plan: Dictionary = resolver.completion_plan(states, fit, MorphologyResolver.MAX_PLAN_STATES, accept)
	if plan.status == "complete":
		var completed: Dictionary = _new_composition_tile(plan.tile, false)
		if str(completed.jelly_kind) == "root":
			var picture: Dictionary = pictures[str(completed.word_candidate.id)]
			var next_index: int = plan.steps.size()
			var merged: Dictionary = _joined_word_tile(completed, picture, completed.word_candidate, 1, true)
			merged.column = int(picture.column)
			merged.row = int(picture.row)
			plan.steps.append({"left_ref": "step:%d" % (next_index - 1), "right_ref": "input:%d" % ids.size(),
				"result_ref": "step:%d" % next_index, "result": merged.duplicate(true),
				"placement": {"column": picture.column, "row": picture.row, "width": 1, "height": 1}})
			ids.append(int(picture.id))
			plan.tile = merged
		else:
			plan.tile = completed
		plan.input_ids = ids.duplicate()
		plan.first_source_id = ids[int(str(plan.steps[0].left_ref).trim_prefix("input:"))]
		plan.first_target_id = ids[int(str(plan.steps[0].right_ref).trim_prefix("input:"))]
	return plan


func _authored_auto_active() -> bool:
	return powerup_active() and str(_powerup.get("kind", "")) in ["auto_merge", "blast"]


func _new_tile(text: String, mass: int, fragments: int, allocate_id: bool = true) -> Dictionary:
	var word: Dictionary = _word_lookup.get(normalize_word(text), {}) if mass > 1 else {}
	if _authored_words.has(str(word.get("id", ""))):
		word = {}
	var size: Vector2i = _preferred_size(mass)
	var tile: Dictionary = {
		"id": _next_tile_id if allocate_id else -1, "text": text, "mass": mass, "parts_count": mass,
		"display_text": text, "jelly_kind": "root", "merge_level": 0,
		"word_candidate": {}, "image_word": {}, "mastery_eligible": false, "assisted": false,
		"fragments": fragments, "chest": fragments > 0,
		"word": word.duplicate(true), "kind": "word" if not word.is_empty() else "chunk",
		"column": 0, "row": ROWS - size.y, "width": size.x, "height": size.y,
		"preferred_width": size.x, "preferred_height": size.y,
		"age": SETTLE_SECONDS, "settling": false, "arrival": false, "arrival_index": 0, "arrival_delay": 0.0,
		"falling": false, "falling_rows": 0, "placement_locked": false
	}
	if allocate_id:
		_next_tile_id += 1
	if not word.is_empty():
		_set_merged_word(tile, word, 1, true)
	return tile


func _preferred_size(_mass: int) -> Vector2i:
	return Vector2i.ONE


func _fill_upcoming() -> void:
	if authored_morphology:
		while upcoming.size() < UPCOMING_COUNT:
			upcoming.append({})
		while true:
			var has_gap: bool = false
			for slot: Dictionary in upcoming:
				has_gap = has_gap or slot.is_empty()
			if not has_gap:
				return
			if _supply.is_empty():
				_build_supply()
			if _supply.is_empty():
				return
			var next: Dictionary = _supply[0]
			var width: int = int(next.width)
			var anchor: int = -1
			for column in range(COLUMNS - width + 1):
				var fits: bool = true
				for lane in range(column, column + width):
					fits = fits and upcoming[lane].is_empty()
				if fits:
					anchor = column
					break
			if anchor < 0:
				return
			var tile: Dictionary = _supply.pop_front()
			tile.preview_column = anchor
			tile.preview_span = width
			upcoming[anchor] = tile
			for lane in range(anchor + 1, anchor + width):
				upcoming[lane] = {"reservation": int(tile.id), "anchor": anchor}
		return
	while upcoming.size() < UPCOMING_COUNT:
		var tile: Dictionary = _next_supply_tile()
		if tile.is_empty():
			return
		upcoming.append(tile)


func _first_preview_tile() -> Dictionary:
	for slot: Dictionary in upcoming:
		if slot.has("id"):
			return slot
	return {}


func _release_preview_slot(anchor: int) -> Dictionary:
	var tile: Dictionary = upcoming[anchor]
	for index in range(upcoming.size()):
		if index == anchor or int(upcoming[index].get("reservation", -1)) == int(tile.id):
			upcoming[index] = {}
	return tile


func preview_area() -> int:
	var area: int = 0
	for tile: Dictionary in upcoming:
		if tile.has("id"):
			area += int(tile.width) * int(tile.height)
	return area


func _schedule_spawn_interval() -> void:
	if stage_run != null:
		spawn_interval = _stage_spawn_interval
		return
	var stage: int = floori(float(cleared_pairs) / CLEARS_PER_DIFFICULTY_STAGE)
	var baseline: float = maxf(MIN_SPAWN_INTERVAL, INITIAL_SPAWN_INTERVAL - stage * SPEEDUP_PER_STAGE)
	spawn_interval = baseline * maxf(1.0, float(preview_area()) / float(COLUMNS)) if authored_morphology else baseline


func _next_supply_tile() -> Dictionary:
	if _supply.is_empty():
		_build_supply()
	return {} if _supply.is_empty() else _supply.pop_front()


func _build_supply() -> void:
	# Mix only a new supply packet. Advertised preview identities never move,
	# and any word crossing a packet boundary keeps its remaining chunks first.
	while _supply_pending.size() < UPCOMING_COUNT and not _words.is_empty():
		var word: Dictionary = WordSampler.next_word(_words, _rng, _word_counts, _word_service, practice_weight_for)
		_supply_words += 1
		var authored_parts: Array = _morphology.source_tiles(str(_authored_words[word.id])) if _authored_words.has(word.id) else []
		var root_count: int = maxi(1, authored_parts.size())
		var part_count: int = root_count + (1 if _has_word_picture(word) else 0)
		var marked: int = _rng.randi_range(0, part_count - 1) if _supply_words % 2 == 0 else -1
		for index in range(part_count):
			var fragments: int = 1 if index == marked else 0
			var tile: Dictionary
			if index == root_count:
				tile = _new_picture_tile(word, fragments)
			elif authored_parts.is_empty():
				tile = _new_word_root(word, fragments)
			else:
				var state: Dictionary = authored_parts[index]
				state.fragments = fragments
				state.origins[0].supply_group = _supply_words
				state.origins[0].supply_part = index
				tile = _new_composition_tile(state)
			tile.supply_group = _supply_words
			tile.supply_part = index
			tile.supply_parts = part_count
			tile.source_word_id = str(word.id)
			_supply_pending.append(tile)
	var packet: Array[Dictionary] = []
	for index in range(mini(UPCOMING_COUNT, _supply_pending.size())):
		packet.append(_supply_pending.pop_front())
	if packet.is_empty():
		return
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
	# Five slots have at most 120 arrangements. Deterministic scoring avoids a
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
	var previous_generated: int = generated_tiles
	var advertised: Dictionary = {}
	for index in range(upcoming.size()):
		if upcoming[index].has("id"):
			advertised[index] = int(upcoming[index].id)
	var column_delays: Dictionary = {}
	var slot_delays: Dictionary = {}
	# Concurrent batches reserve their destinations immediately. Preserve the
	# entry spacing of earlier arrivals without delaying the next input.
	for tile: Dictionary in cells:
		if bool(tile.get("arrival", false)) and not is_settled(tile):
			var slot: int = int(tile.get("arrival_index", 0))
			var departure: float = arrival_delay(tile) - float(tile.age)
			var clearance: float = departure + sqrt(2.0 * int(tile.height) / Motion.ARRIVAL_GRAVITY)
			for column in range(int(tile.column), int(tile.column) + int(tile.width)):
				column_delays[column] = maxf(float(column_delays.get(column, -INF)), clearance)
			slot_delays[slot] = maxf(float(slot_delays.get(slot, -INF)), departure + ARRIVAL_SLOT_CLEARANCE)
	for index in range(DROP_COUNT):
		if not advertised.has(index) or int(upcoming[index].get("id", -1)) != int(advertised[index]):
			continue
		if not _spawn_tile(true, index):
			continue
		var tile: Dictionary = cells.back()
		tile.arrival_delay = maxf(float(tile.arrival_delay), float(slot_delays.get(index, 0.0)))
		for column in range(int(tile.column), int(tile.column) + int(tile.width)):
			if column_delays.has(column):
				tile.arrival_delay = maxf(float(tile.arrival_delay), float(column_delays[column]))
		for column in range(int(tile.column), int(tile.column) + int(tile.width)):
			column_delays[column] = float(tile.arrival_delay) + sqrt(2.0 * int(tile.height) / Motion.ARRIVAL_GRAVITY)
	if generated_tiles > previous_generated:
		# Completed collections set the next packet's pace. Keep the current
		# Next timer intact so a late Collect cannot unexpectedly release it.
		_schedule_spawn_interval()


func _spawn_tile(arrival: bool, arrival_index: int = 0) -> bool:
	if upcoming.is_empty() or (arrival and (arrival_index < 0 or arrival_index >= upcoming.size())):
		return false
	if authored_morphology and not arrival:
		arrival_index = -1
		for index in range(upcoming.size()):
			if upcoming[index].has("id"):
				arrival_index = index
				break
		if arrival_index < 0:
			return false
	if not upcoming[arrival_index].has("id"):
		return false
	var preview: Dictionary = upcoming[arrival_index] if arrival or authored_morphology else upcoming[0]
	var occupied: Dictionary = _occupied()
	var width: int = int(preview.width) if authored_morphology else 1
	var height: int = int(preview.height) if authored_morphology else 1
	var position: Vector2i = _arrival_position(occupied, arrival_index, width, height) if arrival else _free_position(occupied, width, height)
	if position.x < 0 or not _arrival_preserves_drag_return(preview, position, arrival):
		return false
	# A visible preview owns its column until it can enter. Refill only that
	# slot so blocked parts never slide sideways or get replaced by a neighbor.
	var tile: Dictionary = _release_preview_slot(arrival_index) if authored_morphology else (upcoming[arrival_index] if arrival else upcoming.pop_front())
	if arrival and not authored_morphology:
		upcoming[arrival_index] = _next_supply_tile()
	tile.column = position.x
	tile.row = position.y
	tile.age = 0.0 if arrival else SETTLE_SECONDS
	tile.settling = arrival
	tile.arrival = arrival
	tile.arrival_index = arrival_index if arrival else 0
	tile.arrival_delay = _scheduled_arrival_delay(arrival_index) if arrival else 0.0
	if arrival and stage_run != null:
		tile.arrival_delay = float(tile.arrival_delay) / fall_speed_scale
		tile.motion_speed_scale = fall_speed_scale
	tile.falling_rows = position.y + height if arrival else 0
	cells.append(tile)
	generated_tiles += 1
	_fill_upcoming()
	return true


func _complete_operation(event_id: String) -> void:
	if not _combo_pending.is_empty():
		return
	var operation_index: int = _fusion_index(event_id)
	if operation_index < 0:
		return
	var completed: Dictionary = fusions[operation_index].duplicate(true)
	if str(completed.operation) == "merge":
		if cell(int(completed.a_id)).is_empty() or cell(int(completed.b_id)).is_empty():
			fusions.remove_at(operation_index)
			return
		if not bool(completed.get("automatic", false)) and not _credit_merge_combo(event_id):
			return
		operation_index = _fusion_index(event_id)
		if operation_index < 0:
			return
		completed = fusions[operation_index].duplicate(true)
		fusions.remove_at(operation_index)
		_complete_merge(completed)
	elif str(completed.operation) == "collect":
		var generation: int = _generation
		if bool(completed.get("commit_pending", false)):
			return
		if commit_collection.is_valid() and not bool(completed.get("commit_confirmed", false)):
			# Install the pending obligation before an adapter can synchronously
			# acknowledge, pause, leave, or replace the round from its callback.
			fusions[operation_index].commit_pending = true
			var payload: Dictionary = completed.duplicate(true)
			payload.event_id = event_id
			payload.generation = generation
			var response: Variant = commit_collection.call(payload)
			if generation != _generation or _fusion_index(event_id) < 0:
				return
			if response is Dictionary and bool(response.get("pending", false)):
				return
			resolve_collection_commit(event_id, generation, response if response is Dictionary else {})
			return
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


func resolve_collection_commit(event_id: String, generation: int, response: Dictionary) -> bool:
	if generation != _generation or phase != "playing":
		return false
	var index: int = _fusion_index(event_id)
	if index < 0 or str(fusions[index].operation) != "collect" or not bool(fusions[index].get("commit_pending", false)):
		return false
	if bool(response.get("pending", false)):
		return true
	if not bool(response.get("ok", false)):
		fusions.remove_at(index)
		error = str(response.get("error", "The collection could not be saved. Tap the word to try again."))
		if error.is_empty():
			error = "The collection could not be saved. Tap the word to try again."
		_collection_batch_event_id = ""
		cancel_collection_batch()
	else:
		fusions[index].commit_pending = false
		fusions[index].commit_confirmed = true
		fusions[index].credited = true
		if not paused:
			_complete_operation(event_id)
	if generation != _generation:
		return true
	if _finish_after_collection_commit and not _has_pending_collection_commit():
		_finish_after_collection_commit = false
		finish_round(_finish_reason)
	else:
		changed.emit()
	return true


func _has_pending_collection_commit() -> bool:
	for active: Dictionary in fusions:
		if bool(active.get("commit_pending", false)):
			return true
	return false


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
	var held_for_drag: bool = bool(completed.get("held_for_drag", false))
	result.age = SETTLE_SECONDS if held_for_drag else 0.0
	if bool(completed.get("automatic", false)):
		result.settle_seconds = POWERUP_SETTLE_SECONDS
	result.settling = not held_for_drag
	result.arrival = false
	result.falling = false
	result.falling_rows = 0
	result.placement_locked = false
	cells.append(result)
	if _held_tile_id in [int(a.id), int(b.id)]:
		_held_tile_id = -1
	if held_for_drag:
		_held_tile_id = int(result.id)
	# Consumed words cannot return after a valid merge. Release any failed
	# collection rolls only when their replacement has committed.
	_discard_collection_reward(int(a.id))
	_discard_collection_reward(int(b.id))
	_restore_growth(int(result.id))
	_gravity_pending = true
	merged_count += 1
	if _authored_auto_active():
		for plan: Dictionary in _powerup.plans:
			if int(plan.plan_id) != int(completed.get("powerup_plan_id", -1)):
				continue
			plan.result_ids[int(completed.powerup_step_index)] = int(result.id)
			if plan.result_ids.size() >= plan.steps.size():
				_powerup.plans.erase(plan)
			break
		_powerup_ids.erase(int(a.id))
		_powerup_ids.erase(int(b.id))
		_powerup_ids.append(int(result.id))
		_powerup.completed = int(_powerup.completed) + 1
		if _powerup.drags.is_empty():
			_powerup.stage = "settling"
			_powerup.elapsed = 0.0
			_powerup.duration = settle_duration(result)
	if _has_free_cell():
		full_elapsed = -1.0
	completed.result = cell(int(result.id))
	completed.word = completed.result.word.duplicate(true)
	var generation: int = _generation
	_advance_combo(str(completed.attempt_id), int(completed.get("combo_bonus", 0)))
	if generation != _generation:
		return
	fusion_completed.emit(completed, 0)
	if generation == _generation and _finish_after_combo:
		_finish_after_combo = false
		finish_round(_finish_reason)
		return
	if _can_continue(generation):
		changed.emit()


func _discard_collection_reward(tile_id: int) -> void:
	_collection_coin_rewards.erase(_collection_event_ids.get(tile_id, ""))
	_collection_event_ids.erase(tile_id)


func _complete_collection(completed: Dictionary) -> void:
	var index: int = _index_for_id(int(completed.a_id))
	if index < 0:
		return
	cells.remove_at(index)
	if _held_tile_id == int(completed.a_id):
		_held_tile_id = -1
	_discard_collection_reward(int(completed.a_id))
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
	if stage_run != null and not _stage_ending:
		stage_run.record_collection(str(completed.attempt_id), str(completed.word.id))
		if stage_run.kind == "challenge":
			_sync_challenge_pressure()
		elif stage_run.current.has(str(completed.word.id)) \
			and int(stage_run.current[completed.word.id]) >= int(stage_run.goals[completed.word.id]):
			_words = _words.filter(func(word: Dictionary) -> bool: return str(word.id) != str(completed.word.id))
	if bool(completed.get("batch", false)) and int(completed.get("batch_id", -1)) == _collection_batch_serial:
		_collection_batch_completed += 1
		_collection_batch_event_id = ""
		if _collection_batch_cursor >= _collection_batch_ids.size():
			_collection_batch_active = false
			_collection_batch_next_in = 0.0
	full_elapsed = -1.0
	var generation: int = _generation
	_queue_collection_blast(completed)
	_advance_combo(str(completed.attempt_id), 0, false)
	if generation != _generation:
		return
	# A committed pickup owns its learning evidence, including paused settlement.
	# Record it before presentation callbacks can pause, end, or replace the round.
	var word_ids: Array[String] = [str(completed.word.id)]
	if bool(completed.get("mastery_eligible", completed.a.get("mastery_eligible", false))):
		word_attempted.emit(str(completed.attempt_id), word_ids, true)
	if generation != _generation:
		return
	combo_changed.emit(combo_snapshot())
	if generation != _generation:
		return
	collected.emit(str(completed.attempt_id), completed.word.duplicate(true), coins, awarded)
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


func _reset_combo() -> void:
	combo_count = 0
	_combo_bonus = 0
	_combo_remaining = 0.0
	_combo_event = ""
	combo_changed.emit(combo_snapshot())


func combo_snapshot() -> Dictionary:
	var tier: int = 0
	for threshold: int in [3, 6, 10, 15, 25, 40]:
		if combo_count >= threshold:
			tier += 1
	return {"count": combo_count, "best": combo_best, "coins": combo_coins,
		"rank": ["D", "C", "B", "A", "S", "SS", "SSS"][tier], "tier": tier,
		"bonus": _combo_bonus, "next_bonus": CoinEconomy.jelly_combo_bonus(combo_count + 1),
		"remaining": _combo_remaining, "seconds": COMBO_SECONDS,
		"event_id": _combo_event, "pending": not _combo_pending.is_empty() and not _combo_committing}


func _advance_combo(event_id: String, bonus: int, feedback: bool = true) -> void:
	combo_count += 1
	combo_best = maxi(combo_best, combo_count)
	combo_coins += bonus
	_combo_bonus = bonus
	_combo_remaining = COMBO_SECONDS
	_combo_event = event_id
	if feedback:
		combo_changed.emit(combo_snapshot())


func _credit_merge_combo(event_id: String) -> bool:
	var index: int = _fusion_index(event_id)
	var active: Dictionary = fusions[index]
	if not active.has("combo_bonus"):
		active.combo_bonus = CoinEconomy.jelly_combo_bonus(combo_count + 1)
	if int(active.combo_bonus) == 0 or bool(active.get("combo_credited", false)) or not credit_combo.is_valid():
		return true
	var generation: int = _generation
	_combo_pending = event_id
	_combo_committing = true
	var response: Variant = credit_combo.call(event_id, int(active.combo_bonus))
	if generation != _generation or _fusion_index(event_id) < 0:
		return false
	_combo_committing = false
	if not response is Dictionary or not bool(response.get("ok", false)):
		error = "The combo coins could not be saved. Choose Retry saving to finish this merge."
		if _finish_after_combo:
			_finish_after_combo = false
			fusions.remove_at(_fusion_index(event_id))
			_combo_pending = ""
			finish_round(_finish_reason)
			return false
		changed.emit()
		return false
	active.combo_credited = true
	_combo_pending = ""
	error = ""
	return true


func retry_combo_credit() -> void:
	if _combo_pending.is_empty() or _combo_committing or phase != "playing":
		return
	var event_id: String = _combo_pending
	_combo_pending = ""
	_complete_operation(event_id)
	changed.emit()


func _restore_growth(excluded_id: int = -1) -> void:
	# Normalize older transient bodies without allowing semantic part counts to
	# enlarge ordinary cells. Held and reserved bodies finish their current motion.
	_growth_pending = false
	if _authored_auto_active():
		_growth_pending = true
		return
	for tile in cells:
		if tile.has("composition"):
			continue
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
	if _authored_auto_active():
		return
	_gravity_pending = false
	var ordered: Array[Dictionary] = cells.duplicate()
	ordered.sort_custom(_gravity_order)
	for tile: Dictionary in ordered:
		if is_fusing(int(tile.id)) or int(tile.id) == _held_tile_id or _reserved_for_collection(int(tile.id)) \
			or _reserved_for_powerup(int(tile.id)) or not is_settled(tile):
			# Keep fusion endpoints, held anchors and queued pickups intact. A later
			# operation or settlement boundary retries their support settlement.
			_gravity_pending = true
			continue
		var occupied: Dictionary = _occupied([int(tile.id)], false)
		var row: int = int(tile.row)
		if _drag_gravity_delays.has(int(tile.id)):
			if row + int(tile.height) < ROWS and _fits(occupied, int(tile.column), row + 1, int(tile.width), int(tile.height)):
				_gravity_pending = true
				continue
			# Returning the support before the deadline cancels this pending fall.
			_drag_gravity_delays.erase(int(tile.id))
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


func _gravity_order(a: Dictionary, b: Dictionary) -> bool:
	var bottom_a: int = int(a.row) + int(a.height)
	var bottom_b: int = int(b.row) + int(b.height)
	if bottom_a != bottom_b:
		return bottom_a > bottom_b
	if a.column != b.column:
		return int(a.column) < int(b.column)
	return int(a.id) < int(b.id)


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
	if reserve_drag_return and _dragged_tile_id >= 0 and not _dragged_tile_id in excluded_ids:
		# A moving return footprint protects cancellation from arrivals and growth.
		# Gravity never sees this reservation, so it cannot act as hidden support.
		var anchor: Dictionary = cell(_dragged_tile_id)
		if not anchor.is_empty():
			var width: int = int(anchor.width) if anchor.has("composition") else 1
			var height: int = int(anchor.height) if anchor.has("composition") else 1
			var position: Vector2i = _drag_return_after_motion(anchor) if anchor.has("composition") else \
				_drag_return_position(_occupied([], false), width, height, anchor)
			if position.x >= 0:
				_occupy(occupied, position.x, position.y, width, height)
	return occupied


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
	if _first_preview_tile().is_empty():
		return _arrival_position(_occupied()).x >= 0
	if authored_morphology:
		var occupied: Dictionary = _occupied()
		for index in range(upcoming.size()):
			var tile: Dictionary = upcoming[index]
			if not tile.has("id"):
				continue
			var position: Vector2i = _arrival_position(occupied, index, int(tile.width), int(tile.height))
			if position.x >= 0 and _arrival_preserves_drag_return(tile, position):
				return true
		return false
	return _arrival_position(_occupied()).x >= 0


func _arrival_preserves_drag_return(preview: Dictionary, position: Vector2i, arrival: bool = true) -> bool:
	if _dragged_tile_id < 0:
		return true
	var held: Dictionary = cell(_dragged_tile_id)
	if not held.has("composition"):
		return true
	var incoming: Dictionary = preview.duplicate()
	incoming.column = position.x
	incoming.row = position.y
	incoming.age = 0.0 if arrival else SETTLE_SECONDS
	incoming.arrival = arrival
	return _drag_return_after_motion(held, incoming).x >= 0


func _arrival_position(occupied: Dictionary, preferred_column: int = -1, width: int = 1, height: int = 1) -> Vector2i:
	var position := Vector2i(-1, -1)
	for column in range(COLUMNS - width + 1):
		if preferred_column >= 0 and column != preferred_column:
			continue
		if not _fits(occupied, column, 0, width, height):
			continue
		var landing_row: int = 0
		while landing_row + height < ROWS and _fits(occupied, column, landing_row + 1, width, height):
			landing_row += 1
		# A supplied part can enter only through its advertised column. Without
		# a specified column, this also checks whether any entrance is available.
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
