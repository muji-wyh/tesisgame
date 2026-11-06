extends SceneTree
## Packet-local occupancy preserves fresh-query supply decisions and callbacks.

const Model = preload("res://scripts/word_jelly_model.gd")
const Data = preload("res://scripts/game_data.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")
var checks: int = 0
var failures: int = 0
var words: Array[Dictionary] = []


class CountedModel extends Model:
	var occupancy_calls: int = 0
	var supply_builds: int = 0
	var drop_queries: int = 0
	var on_supply: Callable

	func _occupied(excluded_ids: Array[int] = [], reserve_drag_return: bool = true) -> Dictionary:
		occupancy_calls += 1
		return super._occupied(excluded_ids, reserve_drag_return)

	func _build_supply() -> void:
		supply_builds += 1
		if on_supply.is_valid():
			var callback: Callable = on_supply
			on_supply = Callable()
			callback.call()
			return
		super._build_supply()

	func can_drop_now() -> bool:
		drop_queries += 1
		return super.can_drop_now()


class ReferenceModel extends CountedModel:
	# Preserve the previous lane-by-lane fresh-occupancy packet as an oracle.
	func _spawn_drop(streaming: bool = false) -> void:
		var generation: int = _generation
		var previous_generated: int = generated_tiles
		var advertised: Dictionary = {}
		for index in range(upcoming.size()):
			if upcoming[index].has("id"):
				advertised[index] = int(upcoming[index].id)
		var delays: Dictionary = _arrival_entry_delays(streaming)
		var column_delays: Dictionary = delays.columns
		var slot_delays: Dictionary = delays.slots
		var dispatched: int = 0
		for index in range(DROP_COUNT):
			if not _can_continue(generation):
				return
			if boss.broken_remaining > EPSILON and dispatched >= 2:
				break
			if not advertised.has(index) or int(upcoming[index].get("id", -1)) != int(advertised[index]):
				continue
			if streaming and _fill_slot_delay(index, delays, _occupied()) > EPSILON:
				continue
			if not _spawn_tile(true, index):
				continue
			dispatched += 1
			var tile: Dictionary = cells.back()
			if streaming:
				tile.fill_stream = true
				if slot_delays.has(index):
					tile.arrival_delay = 0.0
			else:
				tile.erase("fill_stream")
			tile.arrival_delay = maxf(float(tile.arrival_delay), float(slot_delays.get(index, 0.0)))
			for column in range(int(tile.column), int(tile.column) + int(tile.width)):
				if column_delays.has(column):
					tile.arrival_delay = maxf(float(tile.arrival_delay), float(column_delays[column]))
			for column in range(int(tile.column), int(tile.column) + int(tile.width)):
				var speed: float = clampf(float(tile.get("motion_speed_scale", 1.0)), 1.0, 2.2) if streaming else 1.0
				column_delays[column] = float(tile.arrival_delay) + sqrt(2.0 * int(tile.height) / Motion.ARRIVAL_GRAVITY) / speed / FALL_SPEED_SCALE
		if generated_tiles > previous_generated:
			_schedule_spawn_interval()


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _fixture(model, selected: Array[Dictionary], count: int = 14, blocked: Array[int] = []) -> void:
	check(model.configure(selected, int(selected[0].min_age), 73021), "The supply fixture configures eligible production vocabulary")
	model.cells.clear()
	for index in range(count):
		var tile: Dictionary = model._new_word_root(selected[index % selected.size()])
		model._set_merged_word(tile, selected[index % selected.size()], 1, true)
		tile.column = index % Model.COLUMNS
		tile.row = Model.ROWS - 1 - int(index / Model.COLUMNS)
		tile.age = 2.0
		model.cells.append(tile)
	for column: int in blocked:
		for row in range(Model.ROWS - 2):
			var tile: Dictionary = model._new_picture_tile(selected[0])
			tile.column = column
			tile.row = row
			tile.age = 2.0
			model.cells.append(tile)
	model.spawn_interval = 10000.0
	model.full_elapsed = -1.0
	model._gravity_pending = false
	model._growth_pending = false
	model.set_fill_mode(true)
	model.occupancy_calls = 0
	model.supply_builds = 0
	model.drop_queries = 0


func _state(model) -> Dictionary:
	return {"snapshot": model.snapshot(), "cells": model.cells.duplicate(true),
		"supply": model._supply.duplicate(true), "pending_supply": model._supply_pending.duplicate(true),
		"next_tile": model._next_tile_id, "next_event": model._next_event_id,
		"supply_words": model._supply_words, "rng": model._rng.state,
		"coin_rng": model._coin_rng.state, "blast_rng": model._blast_rng.state,
		"word_counts": model._word_counts.duplicate(true), "word_service": model._word_service.duplicate(true),
		"gravity": model._gravity_pending, "growth": model._growth_pending,
		"delays": model._drag_gravity_delays.duplicate(true)}


func _check_packet(selected: Array[Dictionary], scenario: String, streaming: bool) -> void:
	var reference := ReferenceModel.new()
	var current := CountedModel.new()
	var count: int = Model.CAPACITY if scenario == "full" else 14
	var blocked: Array[int] = []
	if scenario == "blocked":
		blocked.assign([1, 5])
	for model in [reference, current]:
		_fixture(model, selected, count, blocked)
		if scenario == "broken":
			model.boss.broken_remaining = 8.0
		elif scenario == "drag":
			var state: Dictionary = model._morphology.source_tiles(str(model._authored_words[selected[0].id]))[0].duplicate(true)
			var source: Dictionary = model._new_composition_tile(state)
			source.column = 0
			source.row = Model.ROWS - 1
			source.age = 2.0
			model.cells[0] = source
			model.set_held_tile(int(source.id))
			check(model.begin_drag(int(source.id)), "The drag fallback owns a real authored return footprint")
		model.occupancy_calls = 0
		model.supply_builds = 0
	var advertised: Array = current.upcoming.duplicate(true)
	var generated: int = current.generated_tiles
	for model in [reference, current]:
		model._spawn_drop(streaming)
	var reference_queries: int = reference.occupancy_calls
	var current_queries: int = current.occupancy_calls
	check(_state(reference) == _state(current), scenario + ": identity, geometry, delays, supply, counters and RNG match fresh queries")
	if scenario in ["drag", "legacy"]:
		check(current_queries == reference_queries and current_queries > 0, scenario + ": fallback retains the complete fresh-occupancy path")
	else:
		check(current_queries <= 1 + current.supply_builds and current_queries < reference_queries,
			scenario + ": occupancy is rebuilt at most once initially and once after each supply boundary")
	if scenario == "full":
		check(current.generated_tiles == generated and reference_queries == Model.COLUMNS and current_queries == 1,
			"A blocked full-board packet replaces seven complete occupancy scans with one")
	elif scenario == "blocked":
		for column: int in blocked:
			check(current.upcoming[column].id == advertised[column].id, "Blocked lanes retain their exact advertised identity")
	elif scenario == "open" and streaming:
		check(current.generated_tiles == generated + Model.DROP_COUNT and reference_queries == Model.DROP_COUNT * 2,
			"The ordinary seven-body Fill packet previously rebuilt occupancy twice per release")
	for delta: float in [0.02, 0.17, 0.44, 0.31]:
		for model in [reference, current]:
			model.step(delta)
		check(_state(reference) == _state(current), scenario + ": subsequent normal-clock Fill and landing timelines agree")


func _check_callback_mutation() -> void:
	var reference := ReferenceModel.new()
	var current := CountedModel.new()
	var callbacks: Array[Dictionary] = [{"fired": false}, {"fired": false}]
	var models: Array = [reference, current]
	for index in range(models.size()):
		var model = models[index]
		_fixture(model, words)
		model._supply.clear()
		model._supply_pending.clear()
		var subject: WeakRef = weakref(model)
		var receipt: Dictionary = callbacks[index]
		model.practice_weight_for = func(_word: Dictionary) -> float:
			if not receipt.fired:
				receipt.fired = true
				var live = subject.get_ref()
				# Public body edits from application callbacks must affect the next
				# lane immediately, even when they happen inside supply sampling.
				live.cells[0].column = 1
				live.cells[0].row = 0
			return 1.0
	for model in models:
		model._spawn_drop(true)
	check(callbacks.all(func(receipt: Dictionary) -> bool: return receipt.fired), "Both packet paths execute the real external weight callback")
	check(_state(reference) == _state(current), "Supply callback geometry edits invalidate the local map before the next lane")
	check(not current.cells.any(func(tile: Dictionary) -> bool:
		return bool(tile.arrival) and int(tile.arrival_index) == 1), "An entrance blocked by the callback never receives the stale advertised body")


func _check_round_replacement() -> void:
	var model := CountedModel.new()
	_fixture(model, words)
	model._supply.clear()
	model._supply_pending.clear()
	var subject: WeakRef = weakref(model)
	var receipt: Dictionary = {}
	model.on_supply = func() -> void:
		var live = subject.get_ref()
		receipt.ok = live.configure(words, 3, 73022)
		receipt.generation = live._generation
		receipt.cells = live.cells.duplicate(true)
		receipt.upcoming = live.upcoming.duplicate(true)
	model._spawn_drop(true)
	check(bool(receipt.get("ok", false)) and model._generation == receipt.generation,
		"A supply callback can replace the active round during a packet")
	check(model.cells == receipt.cells and model.upcoming == receipt.upcoming,
		"The interrupted packet never marks or reschedules a body belonging to the replacement round")


func _check_boundary_demand() -> void:
	for blocker: String in ["held", "dragged", "fusion", "blast", "hit-stop", "purchasing", "finishing"]:
		var model := CountedModel.new()
		_fixture(model, words)
		match blocker:
			"held": model._held_tile_id = int(model.cells[0].id)
			"dragged": model._dragged_tile_id = int(model.cells[0].id)
			"fusion": model.fusions.append({})
			"blast": model._blast_queue.append({})
			"hit-stop": model._collection_hit_stop = {"remaining": 0.1}
			"purchasing": model._powerup_purchasing = true
			"finishing": model._finishing_powerup = true
		check(is_inf(model._fill_boundary()) and model.drop_queries == 0 and model.occupancy_calls == 0,
			blocker + ": an impossible Fill boundary requests no board-availability scan")


func _run() -> void:
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	check(catalog is Array and Data.validate_words(catalog).is_empty(), "Load validated production vocabulary")
	if failures > 0:
		quit(1)
		return
	for candidate: Dictionary in catalog:
		if int(candidate.min_age) == 3 and words.size() < 6:
			words.append(Morphology.decorate(candidate))
	for scenario: String in ["open", "full", "blocked", "broken", "drag"]:
		_check_packet(words, scenario, true)
	_check_packet(words, "open", false)
	var legacy: Array[Dictionary] = []
	for word: Dictionary in words:
		var plain: Dictionary = word.duplicate(true)
		plain.erase("morphology")
		plain.erase("morphology_status")
		legacy.append(plain)
	_check_packet(legacy, "legacy", true)
	for age: int in [8, 12]:
		var selected: Array[Dictionary] = []
		for candidate: Dictionary in catalog:
			if int(candidate.min_age) == age and selected.size() < 6:
				selected.append(Morphology.decorate(candidate))
		_check_packet(selected, "authored-shapes", true)
	_check_callback_mutation()
	_check_round_replacement()
	_check_boundary_demand()
	print("Word Jelly Fill demand: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
