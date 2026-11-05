extends SceneTree
## Preserve full-board collection, gravity and detached public ownership.

const Model = preload("res://scripts/word_jelly_model.gd")
const Data = preload("res://scripts/game_data.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")
const COHORT := ["cat", "dog", "sun", "ball", "car", "apple", "fish", "duck", "cow"]
const SEED: int = 73021
var checks: int = 0
var failures: int = 0


class ReferenceModel extends "res://scripts/word_jelly_model.gd":
	# These two methods are the unoptimized 69ddd037 collection helpers. Keep
	# this independent oracle when changing the production fast paths.
	func _collection_batch_settling_remaining() -> float:
		var remaining: float = 0.0
		for tile_id: int in _collection_batch_ids:
			var tile: Dictionary = cell(tile_id)
			if not tile.is_empty():
				remaining = maxf(remaining, settle_duration(tile) - float(tile.age))
		return remaining

	func _settle_collected_stack() -> void:
		if _authored_auto_active():
			return
		_gravity_pending = false
		var ordered: Array[Dictionary] = cells.duplicate()
		ordered.sort_custom(_gravity_order)
		var occupied: Dictionary = {}
		for tile: Dictionary in cells:
			if not bool(tile.get("lifted", false)):
				_count_gravity_footprint(occupied, int(tile.column), int(tile.row), int(tile.width), int(tile.height), 1)
		for active: Dictionary in fusions:
			if str(active.operation) == "merge":
				var result: Dictionary = active.result
				_count_gravity_footprint(occupied, int(result.column), int(result.row), int(result.width), int(result.height), 1)
		for tile: Dictionary in ordered:
			if is_fusing(int(tile.id)) or int(tile.id) == _held_tile_id or _reserved_for_collection(int(tile.id)) \
				or _reserved_for_powerup(int(tile.id)) or not is_settled(tile):
				_gravity_pending = true
				continue
			var contributes: bool = not bool(tile.get("lifted", false))
			if contributes:
				_count_gravity_footprint(occupied, int(tile.column), int(tile.row), int(tile.width), int(tile.height), -1)
			var row: int = int(tile.row)
			if _drag_gravity_delays.has(int(tile.id)):
				if row + int(tile.height) < ROWS and _fits(occupied, int(tile.column), row + 1, int(tile.width), int(tile.height)):
					if contributes:
						_count_gravity_footprint(occupied, int(tile.column), row, int(tile.width), int(tile.height), 1)
					_gravity_pending = true
					continue
				_drag_gravity_delays.erase(int(tile.id))
			while row + int(tile.height) < ROWS and _fits(occupied, int(tile.column), row + 1, int(tile.width), int(tile.height)):
				row += 1
			if contributes:
				_count_gravity_footprint(occupied, int(tile.column), row, int(tile.width), int(tile.height), 1)
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


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var data := Data.new()
	check(data.load_all(), "Collection regression loads the actual production vocabulary")
	var words: Array[Dictionary] = []
	for id: String in COHORT:
		for word: Dictionary in data.words:
			if str(word.id) == id:
				words.append(Morphology.decorate(word))
				break
	check(words.size() == COHORT.size(), "All nine pictured Age 3 words are available")
	if words.size() == COHORT.size():
		_check_direct_gravity(words)
		_check_ownership(words)
		for scenario: String in ["normal", "initial-falling", "new-supply"]:
			_check_timeline(words, scenario, Model.CAPACITY)
		for scenario: String in ["start-cancel", "start-pause", "start-new-round", "reward-cancel", "reward-new-round", "credit-pause"]:
			_check_timeline(words, scenario, 12)
	print("Word Jelly collection model: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _fixture(model, words: Array[Dictionary], count: int) -> void:
	check(model.configure(words.duplicate(true), 3, SEED), "Collection fixture configures authored vocabulary")
	model.set_pip_level(99)
	model.spawn_interval = 10000.0
	model.cells.clear()
	for index in range(count):
		var word: Dictionary = words[(index * 5 + int(index / Model.MAX_MERGE_LEVEL)) % words.size()]
		var tile: Dictionary = model._new_word_root(word, 1)
		model._set_merged_word(tile, word, index % Model.MAX_MERGE_LEVEL + 1, true)
		tile.column = index % Model.COLUMNS
		tile.row = Model.ROWS - 1 - int(index / Model.COLUMNS)
		tile.age = 2.0
		tile.arrival = false
		tile.falling = false
		tile.settling = false
		model.cells.append(tile)
	model.merged_count = count
	if count == Model.CAPACITY:
		var levels: Dictionary = {}
		var ids: Dictionary = {}
		for tile: Dictionary in model.cells:
			levels[int(tile.merge_level)] = true
			ids[str(tile.word.id)] = true
		check(model.authored_morphology and levels.size() == Model.MAX_MERGE_LEVEL and ids.size() == COHORT.size(),
			"The full board contains all nine authored words and every merged level")


func _pair(words: Array[Dictionary], count: int) -> Array:
	var models: Array = [ReferenceModel.new(), Model.new()]
	for model in models:
		_fixture(model, words, count)
	return models


func _state(model) -> Dictionary:
	return {"snapshot": model.snapshot(), "gravity": model._gravity_pending,
		"growth": model._growth_pending, "delays": model._drag_gravity_delays.duplicate(true),
		"held": model._held_tile_id, "dragged": model._dragged_tile_id,
		"batch_serial": model._collection_batch_serial, "batch_event": model._collection_batch_event_id,
		"next_tile": model._next_tile_id, "next_event": model._next_event_id,
		"generation": model._generation,
		"rng": model._rng.state, "coin_rng": model._coin_rng.state, "blast_rng": model._blast_rng.state}


func _parity(models: Array, message: String) -> void:
	var a: Dictionary = _state(models[0])
	var b: Dictionary = _state(models[1])
	check(a == b and JSON.stringify(a) == JSON.stringify(b), message)


func _check_direct_gravity(words: Array[Dictionary]) -> void:
	for scenario: String in ["reserved", "empty", "unreserved", "new-cell", "falling", "held", "fusion", "cancelled", "auto"]:
		var models: Array = _pair(words, 12)
		for model in models:
			model._collection_batch_active = true
			model._collection_batch_started = 1
			for tile: Dictionary in model.cells:
				model._collection_batch_ids.append(int(tile.id))
			model._collection_batch_ids.append(1000000)
			model._collection_batch_ids.append(int(model.cells[0].id))
			model._gravity_pending = true
			if scenario == "empty":
				model.cells.clear()
			elif scenario in ["unreserved", "held", "fusion"]:
				while model._collection_batch_ids.has(int(model.cells[0].id)):
					model._collection_batch_ids.erase(int(model.cells[0].id))
			elif scenario == "new-cell":
				var added: Dictionary = model._new_picture_tile(words[0])
				added.column = 0
				added.row = 0
				added.age = 2.0
				model.cells.append(added)
			elif scenario == "cancelled":
				model.cancel_collection_batch()
			elif scenario == "auto":
				model._powerup = model.powerup_snapshot()
				model._powerup.active = true
				model._powerup.kind = "auto_merge"
				model._powerup.stage = "impact"
				model._powerup.duration = model.BLAST_FREEZE_SECONDS
			if scenario == "falling":
				model.cells[0].age = 0.03
				model.cells[0].arrival = true
				model.cells[0].arrival_delay = 0.1
				model.cells[0].falling_rows = 5
				model.cells[0].settling = true
			if scenario == "held":
				model._held_tile_id = int(model.cells[0].id)
				model._drag_gravity_delays[int(model.cells[1].id)] = 0.4
			if scenario == "fusion":
				var a: Dictionary = model.cells[0].duplicate(true)
				var b: Dictionary = model.cells[1].duplicate(true)
				var result: Dictionary = a.duplicate(true)
				result.id = 9000
				result.column = int(model.cells[2].column)
				result.row = int(model.cells[2].row)
				model.fusions.append({"operation": "merge", "a_id": a.id, "b_id": b.id,
					"a": a, "b": b, "result": result, "attempt_id": "overlap-test", "elapsed": 0.1,
					"duration": 0.76, "held_for_drag": false})
		var before: Array = [JSON.stringify(models[0].cells), JSON.stringify(models[1].cells)]
		check(models[0]._collection_batch_settling_remaining() == models[1]._collection_batch_settling_remaining(),
			scenario + ": missing and repeated IDs preserve the exact settlement deadline")
		for index in range(models.size()):
			check(JSON.stringify(models[index].cells) == before[index], scenario + ": reading the deadline leaves live bodies untouched")
		for pass_index in range(3):
			for model in models:
				model._settle_collected_stack()
			_parity(models, "%s: gravity pass %d preserves complete model and JSON state" % [scenario, pass_index])
			if scenario == "reserved" and pass_index == 0:
				# An edited captured list must affect the very next gravity call.
				for model in models:
					var id: int = int(model.cells[0].id)
					while model._collection_batch_ids.has(id):
						model._collection_batch_ids.erase(id)


func _check_ownership(words: Array[Dictionary]) -> void:
	var model := Model.new()
	_fixture(model, words, 12)
	var shared: Dictionary = {"nested": [{"revision": 0}]}
	model.cells[0].ownership_probe = shared
	model.cells[1].ownership_probe = shared
	var retained: Dictionary = model.snapshot()
	var retained_bytes: String = JSON.stringify(retained)
	var detached: Dictionary = model.cell(int(model.cells[0].id))
	detached.ownership_probe.nested[0].revision = 2
	check(int(model.cells[0].ownership_probe.nested[0].revision) == 0,
		"The public cell accessor still owns a detached nested graph")
	model._collection_batch_ids.assign([int(model.cells[0].id), int(model.cells[1].id), 1000000])
	model._collection_batch_settling_remaining()
	shared.nested[0].revision = 3
	var fresh: Dictionary = model.snapshot()
	check(int(fresh.cells[0].ownership_probe.nested[0].revision) == 3
		and int(fresh.cells[1].ownership_probe.nested[0].revision) == 3
		and JSON.stringify(retained) == retained_bytes and int(detached.ownership_probe.nested[0].revision) == 2,
		"Synchronous internal reads preserve live edits and every retained public snapshot")
	var edited: Dictionary = model.snapshot()
	edited.cells[0].ownership_probe.nested[0].revision = 4
	check(int(edited.cells[1].ownership_probe.nested[0].revision) == 3
		and int(model.cells[0].ownership_probe.nested[0].revision) == 3,
		"Separate public cell graphs never share nested writes")


func _observer_state() -> Dictionary:
	return {"start": false, "reward": false, "credit": false, "action": "",
		"generation_before": -1, "generation_after": -1, "batch_active_after": true,
		"paused_after": false, "configured": false, "retained_events": [], "retained_bytes": []}


func _retain_event(events: Array, fired: Dictionary, event: Array) -> void:
	# Keep the emitted graph itself: cloning here would hide later alias writes.
	events.append(event)
	fired.retained_events.append(event)
	fired.retained_bytes.append(JSON.stringify(event))


func _apply_callback(model, fired: Dictionary, scenario: String, words: Array[Dictionary]) -> void:
	fired.action = scenario
	fired.generation_before = model._generation
	if scenario.ends_with("cancel"):
		model.cancel_collection_batch()
	elif scenario.ends_with("pause"):
		model.set_paused(true)
	elif scenario.ends_with("new-round"):
		fired.configured = model.configure(words.duplicate(true), 3, SEED + 7)
		model.spawn_interval = 10000.0
	fired.generation_after = model._generation
	fired.batch_active_after = model.collection_batch_active()
	fired.paused_after = model.paused


func _check_retained_events(fired: Dictionary, label: String) -> void:
	for index in range(fired.retained_events.size()):
		check(JSON.stringify(fired.retained_events[index]) == fired.retained_bytes[index],
			"%s: emitted graph %d retains its original nested data" % [label, index])


func _observe(model, events: Array, scenario: String, words: Array[Dictionary], fired: Dictionary) -> void:
	var subject: WeakRef = weakref(model)
	model.changed.connect(func() -> void: events.append(["changed"]))
	model.cue_requested.connect(func(cue: String) -> void: events.append(["cue", cue]))
	model.fusion_started.connect(func(payload: Dictionary) -> void:
		_retain_event(events, fired, ["fusion_started", payload]))
	model.fusion_completed.connect(func(payload: Dictionary, fragments: int) -> void:
		_retain_event(events, fired, ["fusion_completed", payload, fragments]))
	model.collection_started.connect(func(payload: Dictionary) -> void:
		_retain_event(events, fired, ["collection_started", payload])
		if fired.start:
			return
		fired.start = true
		if scenario in ["start-cancel", "start-pause", "start-new-round"]:
			_apply_callback(subject.get_ref(), fired, scenario, words))
	model.word_attempted.connect(func(id: String, ids: Array[String], correct: bool) -> void:
		_retain_event(events, fired, ["word_attempted", id, ids, correct]))
	model.combo_changed.connect(func(payload: Dictionary) -> void:
		_retain_event(events, fired, ["combo", payload]))
	model.collected.connect(func(id: String, word: Dictionary, coins: int, fragments: int) -> void:
		_retain_event(events, fired, ["collected", id, word, coins, fragments])
		if fired.reward:
			return
		fired.reward = true
		if scenario in ["reward-cancel", "reward-new-round"]:
			_apply_callback(subject.get_ref(), fired, scenario, words))
	model.fragments_awarded.connect(func(amount: int) -> void: events.append(["fragments", amount]))
	model.chest_milestone.connect(func(previous: int, current: int) -> void: events.append(["chest", previous, current]))
	model.credit_collection = func(id: String, coins: int) -> Dictionary:
		events.append(["credit", id, coins])
		if scenario == "credit-pause" and not fired.credit:
			fired.credit = true
			_apply_callback(subject.get_ref(), fired, scenario, words)
		return {"ok": true}


func _check_timeline(words: Array[Dictionary], scenario: String, count: int) -> void:
	var models: Array = _pair(words, count)
	var events: Array = [[], []]
	var fired: Array = [_observer_state(), _observer_state()]
	var initial_generations: Array[int] = [models[0]._generation, models[1]._generation]
	for index in range(models.size()):
		var model = models[index]
		if scenario == "initial-falling":
			model.cells[0].age = 0.03
			model.cells[0].arrival = true
			model.cells[0].arrival_delay = 0.15
			model.cells[0].falling_rows = 6
			model.cells[0].settling = true
		if scenario == "credit-pause":
			var first_id: int = model.collectable_ids()[0]
			var event_id: String = model._event_id("collect")
			model._collection_event_ids[first_id] = event_id
			model._collection_coin_rewards[event_id] = 50
		_observe(model, events[index], scenario, words, fired[index])
		check(model.start_collection_batch(), scenario + ": the actual Auto Collect action starts")
	_parity(models, scenario + ": complete activation state agrees")
	for observer: Dictionary in fired:
		_check_retained_events(observer, scenario + " activation")
	var retained: Array = [models[0].snapshot(), models[1].snapshot()]
	var retained_bytes: Array = [JSON.stringify(retained[0]), JSON.stringify(retained[1])]
	var added: bool = false
	var resumed: bool = false
	for frame in range(180):
		if models[0].paused:
			for model in models:
				model.step(0.7)
			_parity(models, scenario + ": synchronous callback pause freezes both timelines")
			for model in models:
				model.set_paused(false)
			resumed = true
		if scenario == "new-supply" and not added and models[0].cleared_pairs > 0:
			for model in models:
				var position: Vector2i = model._arrival_position(model._occupied())
				check(position.x >= 0, "A real cleared entrance admits the unreserved supplied picture")
				var tile: Dictionary = model._new_picture_tile(words[0])
				tile.column = position.x
				tile.row = position.y
				tile.age = 0.0
				tile.falling = true
				tile.falling_rows = 1
				tile.settling = true
				model.cells.append(tile)
				model._gravity_pending = true
			added = true
		for model in models:
			model.step([1.0 / 60.0, 0.083, 0.4, 0.7][frame % 4])
		_parity(models, "%s: time slice %d preserves all public fields, deadlines, RNG and pending gravity" % [scenario, frame])
		check(events[0] == events[1] and JSON.stringify(events[0]) == JSON.stringify(events[1]),
			scenario + ": observed collection signals and wallet callbacks retain complete payloads and order")
		for observer: Dictionary in fired:
			_check_retained_events(observer, "%s time slice %d" % [scenario, frame])
		check(JSON.stringify(retained[0]) == retained_bytes[0] and JSON.stringify(retained[1]) == retained_bytes[1],
			scenario + ": advancing the batch never changes a retained activation snapshot")
		if not models[0].collection_batch_active() and models[0].fusions.is_empty() and not models[0]._gravity_pending:
			break
	if scenario in ["normal", "initial-falling", "new-supply"]:
		check(models[1].cleared_pairs == count and not models[1].collection_batch_active()
			and int(models[1].collection_batch_snapshot().skipped) == 0,
			scenario + ": all 56 mixed-Lv captured bodies complete once with zero skipped pickups")
		check(models[1].cells.size() == (1 if scenario == "new-supply" else 0),
			scenario + ": automatic collection leaves only the later unreserved supply")
		var receipts: Dictionary = {}
		var collection_count: int = 0
		var learning_count: int = 0
		for event: Array in events[1]:
			if str(event[0]) == "collected":
				collection_count += 1
				receipts[str(event[1])] = true
			elif str(event[0]) == "word_attempted":
				learning_count += 1
				check(bool(event[3]), "Every automatic pickup records a correct vocabulary answer")
		check(collection_count == count and learning_count == count and receipts.size() == count,
			scenario + ": every captured body emits exactly one distinct reward and learning receipt")
	if scenario.ends_with("pause"):
		check(resumed, scenario + ": the synchronous callback actually paused and resumed collection")
	if scenario in ["start-cancel", "start-pause", "start-new-round", "reward-cancel", "reward-new-round", "credit-pause"]:
		for index in range(models.size()):
			var observer: Dictionary = fired[index]
			var model = models[index]
			check(str(observer.action) == scenario and int(observer.generation_before) == initial_generations[index],
				scenario + ": each model actually entered the requested synchronous callback")
			if scenario.ends_with("new-round"):
				check(bool(observer.configured) and int(observer.generation_after) == initial_generations[index] + 1
					and model._generation == observer.generation_after and not bool(observer.batch_active_after)
					and not model.collection_batch_active() and model.cleared_pairs == 0,
					scenario + ": a successful new generation replaces the batch without old-round rewards")
			elif scenario.ends_with("cancel"):
				check(int(observer.generation_after) == initial_generations[index] and model._generation == initial_generations[index]
					and not bool(observer.batch_active_after) and not model.collection_batch_active() and model.cleared_pairs == 1,
					scenario + ": cancellation retains one already-started pickup and prevents later batch pickups")
			else:
				check(bool(observer.paused_after) and int(observer.generation_after) == initial_generations[index]
					and model._generation == initial_generations[index] and model.cleared_pairs == count
					and not model.collection_batch_active(),
					scenario + ": pause occurs in the current generation and every pickup completes after resuming")
	if scenario == "credit-pause":
		check(bool(fired[1].credit), "The seeded reward actually reached the wallet callback")
	if scenario == "new-supply":
		check(added, "The full-board collection test actually inserted later unreserved supply")
	for model in models:
		model.credit_collection = Callable()
