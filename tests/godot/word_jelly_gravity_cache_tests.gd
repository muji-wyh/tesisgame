extends "res://tests/godot/word_jelly_model_tests.gd"
## Compare pass-local occupancy with the previous per-body gravity algorithm.

class ReferenceModel extends "res://scripts/word_jelly_model.gd":
	var occupancy_queries: int = 0

	func _occupied(excluded_ids: Array[int] = [], reserve_drag_return: bool = true) -> Dictionary:
		occupancy_queries += 1
		return super._occupied(excluded_ids, reserve_drag_return)

	func _settle_collected_stack() -> void:
		if _authored_auto_active():
			return
		_gravity_pending = false
		var ordered: Array[Dictionary] = cells.duplicate()
		ordered.sort_custom(_gravity_order)
		for tile: Dictionary in ordered:
			if is_fusing(int(tile.id)) or int(tile.id) == _held_tile_id or _reserved_for_collection(int(tile.id)) \
				or _reserved_for_powerup(int(tile.id)) or not is_settled(tile):
				_gravity_pending = true
				continue
			var occupied: Dictionary = _occupied([int(tile.id)], false)
			var row: int = int(tile.row)
			if _drag_gravity_delays.has(int(tile.id)):
				if row + int(tile.height) < ROWS and _fits(occupied, int(tile.column), row + 1, int(tile.width), int(tile.height)):
					_gravity_pending = true
					continue
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

class CountedModel extends "res://scripts/word_jelly_model.gd":
	var occupancy_queries: int = 0

	func _occupied(excluded_ids: Array[int] = [], reserve_drag_return: bool = true) -> Dictionary:
		occupancy_queries += 1
		return super._occupied(excluded_ids, reserve_drag_return)


func _run() -> void:
	for count: int in [49, Model.CAPACITY]:
		for seed_value: int in [73021, 9173, 42]:
			for scenario: String in ["settled", "removed-support", "drag-delay", "merge-collection", "staggered"]:
				_check_timeline(count, seed_value, scenario, [0.7, 0.8, 0.5])
				_check_timeline(count, seed_value, scenario, [0.07, 0.29, 0.000001, 0.31, 0.42, 0.41, 0.5])
	_check_overlap_ownership()
	_check_query_work()
	print("Word Jelly gravity occupancy: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _configure_pair(count: int, seed_value: int) -> Array:
	var reference := ReferenceModel.new()
	var current := CountedModel.new()
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var board: Array[Dictionary] = []
	for index in range(count):
		var tile: Dictionary = _tile(1000 + index, "cat" if index % 2 == 0 else "picture:cat")
		tile.column = index % Model.COLUMNS
		tile.row = Model.ROWS - 1 - int(index / Model.COLUMNS)
		tile.age += random.randf_range(0.0, 2.0)
		board.append(tile)
	# Storage order must not replace the deterministic bottom-up support order.
	for index in range(board.size() - 1, 0, -1):
		var other: int = random.randi_range(0, index)
		var temporary: Dictionary = board[index]
		board[index] = board[other]
		board[other] = temporary
	for model in [reference, current]:
		check(model.configure([_word("cat")], 3, seed_value), "The paired gravity fixture configures real model vocabulary")
		model.set_pip_level(3)
		model.spawn_interval = 10000.0
		model.cells.assign(board.duplicate(true))
		model._gravity_pending = true
	return [reference, current]


func _check_timeline(count: int, seed_value: int, scenario: String, deltas: Array) -> void:
	var pair: Array = _configure_pair(count, seed_value)
	var cue_sequences: Array = [[], []]
	for index in range(pair.size()):
		var model = pair[index]
		var cues: Array = cue_sequences[index]
		model.cue_requested.connect(func(cue: String) -> void: cues.append(cue))
		match scenario:
			"removed-support", "staggered":
				model.cells.remove_at(model._index_for_id(1000))
				if scenario == "staggered":
					model.cells[model._index_for_id(1007)].age = 0.07
					model.cells[model._index_for_id(1009)].age = 0.22
			"drag-delay":
				model.set_held_tile(1000)
				check(model.begin_drag(1000), "The full-board fixture lifts a real supporting body")
			"merge-collection":
				var pickup: Dictionary = model.cells[model._index_for_id(1004)]
				model._set_merged_word(pickup, _word("cat"), 1, true)
				check(model.try_merge(1000, 1001) == "merged" and model.collect(1004),
					"A crowded board owns concurrent real fusion and collection reservations")
	var label: String = "%d bodies, seed %d, %s" % [count, seed_value, scenario]
	check(_gravity_state(pair[0]) == _gravity_state(pair[1]), label + ": initial states agree")
	for delta in deltas:
		for model in pair:
			model.step(float(delta))
		check(_gravity_state(pair[0]) == _gravity_state(pair[1]),
			label + ": footprints, clocks, flags, reservations and rewards agree after each time slice")
		check(cue_sequences[0] == cue_sequences[1], label + ": danger, landing and collection cues preserve their sequence")
	check(pair[0].phase == "playing" and pair[1].phase == "playing", label + ": both real model timelines remain playable")


func _gravity_state(model) -> Dictionary:
	return {"snapshot": model.snapshot(), "gravity": model._gravity_pending, "growth": model._growth_pending,
		"drag_delays": model._drag_gravity_delays.duplicate(true)}


func _check_overlap_ownership() -> void:
	var pair: Array = _configure_pair(49, 73021)
	for model in pair:
		var wide: Dictionary = _placed_tile(1000, "cat", 0, 4)
		wide.width = 2
		wide.height = 2
		model.cells.assign([wide, _placed_tile(1001, "cat", 0, 7),
			_placed_tile(1002, "cat", 3, 6), _placed_tile(1003, "picture:cat", 4, 7),
			_placed_tile(1004, "cat", 1, 5)])
		# Future footprints can overlap their owners. Explicitly exercise shared
		# keys so excluding a body cannot erase a different reservation's cells.
		model.fusions.assign([{"operation": "merge", "a_id": 1002, "b_id": 1003,
			"result": {"column": 0, "row": 5, "width": 2, "height": 1}}])
		model._settle_collected_stack()
	check(pair[0].cells == pair[1].cells and pair[0]._gravity_pending == pair[1]._gravity_pending,
		"Overlapping multi-cell bodies and future reservations retain independent occupancy ownership")
	check(pair[1].cell(1000).row == 4, "A shared reservation still blocks the wide body's first downward step")


func _check_query_work() -> void:
	var pair: Array = _configure_pair(Model.CAPACITY, 73021)
	for model in pair:
		model.occupancy_queries = 0
		model._settle_collected_stack()
	check(pair[0].occupancy_queries == Model.CAPACITY and pair[1].occupancy_queries == 0,
		"Full-board gravity replaces 56 complete occupancy rebuilds with one local footprint map")
	check(pair[0].cells == pair[1].cells and not pair[1]._gravity_pending,
		"The reduced work preserves a fully supported 56-body board")
