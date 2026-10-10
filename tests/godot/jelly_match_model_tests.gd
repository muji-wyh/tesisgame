extends SceneTree

const Model = preload("res://scripts/jelly_match_model.gd")
const Motion = preload("res://scripts/jelly_motion.gd")
const INITIAL_COUNT: int = Model.INITIAL_SETTLED_TILES

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	_test_configuration()
	_test_supply_and_gravity()
	_test_queue_contract()
	_test_manual_drop()
	_test_manual_drop_guards()
	_test_manual_drop_partial_batch()
	_test_partial_and_stacked_drops()
	_test_supply_fairness()
	_test_fall_physics()
	_test_landing_timeline()
	_test_fusion_timeline()
	_test_overlapping_fusions()
	_test_concurrent_fusion_lifecycle()
	_test_held_source_after_gravity()
	_test_concurrent_fusion_reentry()
	_test_fusion_freezes_arrival()
	_test_wrong_and_ignored_attempts()
	_test_full_board_timeout()
	_test_danger_rescue_and_pause()
	_test_finish_and_reset()
	_test_long_round()
	_test_catalog_levels()
	_test_signal_reentry()
	_test_danger_signal_reentry()
	print("Jelly Match model: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _word(word_id: String, age: int = 3) -> Dictionary:
	return {
		"id": word_id, "text": word_id.capitalize(), "min_age": age,
		"image": "assets/images/words/%s.png" % word_id,
		"audio": "assets/audio/words/%s.wav" % word_id
	}


func _vocabulary(count: int = 16) -> Array:
	var words: Array = []
	for index in range(count):
		words.append(_word("word-%d" % index))
	return words


func _initial_fill_seconds() -> float:
	return ceilf(float(Model.CAPACITY - INITIAL_COUNT) / Model.DROP_COUNT) * Model.INITIAL_SPAWN_INTERVAL


func _danger_start_seconds() -> float:
	return _initial_fill_seconds() + Motion.ready_at({"row": 0, "falling_rows": 1, "arrival": true})


func _settle_remaining(model) -> float:
	var remaining: float = 0.0
	for cell in model.cells:
		remaining = maxf(remaining, Motion.ready_at(cell) - float(cell.age))
	return remaining


func _observe(model) -> Dictionary:
	var events: Dictionary = {"attempts": [], "cues": [], "fusions": [], "completed": [], "chests": [], "finished": []}
	model.word_attempted.connect(func(attempt_id: String, word_ids: Array[String], correct: bool) -> void:
		events.attempts.append({"id": attempt_id, "words": word_ids.duplicate(), "correct": correct}))
	model.cue_requested.connect(func(cue: String) -> void: events.cues.append(cue))
	model.fusion_started.connect(func(payload: Dictionary) -> void: events.fusions.append(payload.duplicate(true)))
	model.fusion_completed.connect(func(payload: Dictionary, awarded: int) -> void:
		events.completed.append({"fusion": payload.duplicate(true), "awarded": awarded}))
	model.chest_awarded.connect(func(count: int) -> void: events.chests.append(count))
	model.finished.connect(func(result: Dictionary) -> void: events.finished.append(result.duplicate(true)))
	return events


func _pair(model, require_settled: bool = true, chest_only: bool = false) -> Array[int]:
	for a in model.cells:
		for b in model.cells:
			if int(a.id) == int(b.id) or a.word.id != b.word.id or a.kind == b.kind:
				continue
			if model.is_fusing(int(a.id)) or model.is_fusing(int(b.id)):
				continue
			if require_settled and (not model.is_settled(a) or not model.is_settled(b)):
				continue
			if chest_only and not bool(a.chest) and not bool(b.chest):
				continue
			return [int(a.id), int(b.id)]
	return []


func _assert_board(model, label: String) -> void:
	var positions: Dictionary = {}
	var ids: Dictionary = {}
	var balances: Dictionary = {}
	for cell in model.cells:
		check(int(cell.column) >= 0 and int(cell.column) < Model.COLUMNS
			and int(cell.row) >= 0 and int(cell.row) < Model.ROWS, label + ": tiles stay on the board")
		var position: String = "%d,%d" % [cell.column, cell.row]
		check(not positions.has(position), label + ": tile positions are distinct")
		check(not ids.has(cell.id), label + ": tile IDs are distinct")
		positions[position] = true
		ids[cell.id] = true
		var balance: int = int(balances.get(cell.word.id, 0))
		balances[cell.word.id] = balance + (1 if cell.kind == "word" else -1)
	for column in range(Model.COLUMNS):
		var found_tile: bool = false
		for row in range(Model.ROWS):
			var occupied: bool = positions.has("%d,%d" % [column, row])
			check(not found_tile or occupied, label + ": gravity leaves no holes below a tile")
			found_tile = found_tile or occupied
	var unmatched: int = 0
	for balance in balances.values():
		unmatched += absi(int(balance))
	check(unmatched <= Model.SUPPLY_BATCH_PAIRS, label + ": bounded supply limits unmatched halves")
	check(model.cells.size() <= Model.CAPACITY, label + ": board capacity holds")
	check(model.generated_tiles == model.cells.size() + model.cleared_pairs * 2,
		label + ": every dispatched tile remains on the board or belongs to a completed clear")
	check(model.upcoming.size() == Model.UPCOMING_COUNT, label + ": exactly four committed previews remain")
	for tile in model.upcoming:
		check(not ids.has(tile.id), label + ": queued tiles are distinct from every visible tile")
		ids[tile.id] = true
	if model.cells.size() == Model.CAPACITY:
		check(not _pair(model, false).is_empty(), label + ": a full board always contains an actual pair")


func _test_configuration() -> void:
	var model = Model.new()
	var words: Array = _vocabulary()
	for index in range(words.size()):
		words[index]._growth_priority = 2 if index < 4 else (1 if index < 8 else 0)
	var context_only: Dictionary = _word("context")
	context_only.image = ""
	words.insert(0, context_only)
	words.insert(0, _word("future", 4))
	words.insert(0, {"id": "missing-picture"})
	words.insert(0, null)
	words.append(words[4].duplicate(true))
	check(model.configure(words, 3, 19), "A pictured eligible curriculum starts Jelly Match")
	check(model.phase == "playing" and model.cells.size() == INITIAL_COUNT,
		"The initial board has only six settled tiles and no automatic arrivals")
	check(model.generated_tiles == INITIAL_COUNT and model.spawn_interval == 10.0,
		"Each opening four-tile drop leaves ten seconds to read and match")
	var initial_ids: Array[String] = []
	var initial_chests: int = 0
	for cell in model.cells:
		if not initial_ids.has(str(cell.word.id)):
			initial_ids.append(str(cell.word.id))
		check(cell.word.min_age <= 3 and not str(cell.word.image).is_empty(), "Only pictured age-appropriate words enter the board")
		check(model.is_settled(cell) and not cell.arrival and cell.falling_rows == 0,
			"The six starting tiles are ready without simultaneous falling")
		initial_chests += 1 if cell.chest and not cell.arrival else 0
	check(initial_ids.size() == 3 and model.cells.all(func(cell: Dictionary) -> bool:
		return str(cell.word.id) in ["word-0", "word-1", "word-2", "word-3"]),
		"The opening complete bag practises current unmastered words first")
	check(initial_chests == 1, "The third initial pair contains exactly one chest")
	var second = Model.new()
	second.configure(words, 3, 19)
	check(model.snapshot() == second.snapshot(), "A fixed seed reproduces the complete initial board")
	var copied: Dictionary = model.snapshot()
	var first_word: String = str(model.cells[0].word.id)
	copied.cells[0].word.id = "changed"
	copied.cells.clear()
	copied.upcoming[0].word.id = "changed-queue"
	check(model.cells.size() == INITIAL_COUNT and model.cells[0].word.id == first_word
		and model.upcoming[0].word.id != "changed-queue", "Snapshots cannot mutate model cells, queued tiles, or words")
	var tile: Dictionary = model.tile_by_id(int(model.cells[0].id))
	tile.word.id = "changed"
	check(model.cells[0].word.id == first_word and model.tile_by_id(-1).is_empty(), "Tile lookup returns an isolated copy or an empty dictionary")
	check(not second.configure([context_only, _word("future", 4)], 3, 1)
		and second.cells.is_empty() and second.phase == "finished", "An empty eligible catalog fails without a partial board")
	check(not second.configure(_vocabulary(), 2, 1), "Levels below the starting age do not leak age-three words")
	check(second.configure([_word("only")], 3, 2) and second.cells.size() == INITIAL_COUNT,
		"A small pictured catalog can repeat complementary halves without becoming unsolvable")
	var different_orders: Dictionary = {}
	for seed_value in range(8):
		second.configure(_vocabulary(), 3, seed_value)
		var order: Array[String] = []
		for cell in second.cells:
			order.append(str(cell.word.id))
		different_orders[JSON.stringify(order)] = true
	check(different_orders.size() > 1, "Equal-priority words vary across seeded rounds")
	model.step(_initial_fill_seconds())
	var unique_order: Array[String] = []
	var priorities: Array[int] = []
	for cell in model.cells:
		if not unique_order.has(str(cell.word.id)):
			unique_order.append(str(cell.word.id))
			priorities.append(int(cell.word._growth_priority))
	check(priorities.slice(0, 3).all(func(priority: int) -> bool: return priority == 2)
		and priorities.slice(9).all(func(priority: int) -> bool: return priority == 0),
		"Supply bags preserve curriculum priority while interleaving their selected halves")
	_assert_board(model, "Initial board")


func _test_supply_and_gravity() -> void:
	for seed_value in range(12):
		var model = Model.new()
		model.configure(_vocabulary(), 3, seed_value)
		model.step(9.999)
		check(model.cells.size() == INITIAL_COUNT, "The next drop does not arrive before ten seconds")
		model.step(0.001)
		check(model.cells.size() == INITIAL_COUNT + Model.DROP_COUNT and model.generated_tiles == INITIAL_COUNT + Model.DROP_COUNT,
			"The ten-second boundary supplies exactly four tiles")
		for drop_index in range(4):
			model.step(model.spawn_interval)
			_assert_board(model, "Seed %d, drop %d" % [seed_value, drop_index + 2])
		check(model.cells.size() == 24 and model.full_elapsed == -1.0,
			"The final incoming batch does not begin danger before every tile lands")
		var chest_tiles: int = 0
		for cell in model.cells:
			chest_tiles += 1 if cell.chest else 0
		check(chest_tiles == 4, "Every third generated pair supplies exactly one chest tile")
		model.step(Model.SETTLE_SECONDS)
		check(model.full_elapsed >= 0.0 and model.full_elapsed < Model.SETTLE_SECONDS,
			"Danger starts after every tile in the last drop recovers from landing")
		var pair: Array[int] = _pair(model)
		var previous_rows: Dictionary = {}
		for cell in model.cells:
			previous_rows[cell.id] = int(cell.row)
		check(model.try_merge(pair[0], pair[1]) == "correct", "A full board always provides a usable matching pair")
		model.step(Model.FUSION_SECONDS)
		check(model.cells.size() == 22 and model.full_elapsed == -1.0, "Clearing a pair leaves space and cancels danger")
		for cell in model.cells:
			if int(cell.row) != int(previous_rows[cell.id]):
				check(int(cell.falling_rows) == int(cell.row) - int(previous_rows[cell.id]) and cell.age == 0.0,
					"Gravity restarts falling only across the newly cleared local row distance")
		_assert_board(model, "Gravity after a clear")


func _test_queue_contract() -> void:
	var model = Model.new()
	model.configure(_vocabulary(8), 3, 27)
	var previous_word: String = str(model.cells.back().word.id)
	for index in range(36):
		model.step(_settle_remaining(model))
		while model.cells.size() >= 14:
			var pair: Array[int] = _pair(model)
			model.try_merge(pair[0], pair[1])
			var queue_during_fusion: Array = model.upcoming.duplicate(true)
			model.step(Model.FUSION_SECONDS)
			check(model.upcoming == queue_during_fusion, "A completed match never rewrites the four advertised tiles")
			model.step(_settle_remaining(model))
		var advertised: Array = model.upcoming.duplicate(true)
		var entered: int = model.generated_tiles
		var before_count: int = model.cells.size()
		model.step(model.spawn_interval - model.spawn_elapsed - 0.001)
		check(model.generated_tiles == entered and model.upcoming == advertised,
			"All four previews wait unchanged until their exact dispatch boundary")
		model.step(0.001)
		check(model.generated_tiles == entered + Model.DROP_COUNT and model.cells.size() == before_count + Model.DROP_COUNT,
			"Every unobstructed drop dispatches four tiles at the same boundary")
		for offset in range(Model.DROP_COUNT):
			var arrival: Dictionary = model.cells[before_count + offset]
			var advertised_tile: Dictionary = advertised[offset]
			check(int(arrival.id) == int(advertised_tile.id) and arrival.word == advertised_tile.word
				and arrival.kind == advertised_tile.kind and arrival.chest == advertised_tile.chest,
				"The four advertised identities, words, kinds, and chest markers enter in committed order")
			check(str(arrival.word.id) != previous_word,
				"Distinct-word supply never places immediate matching partners consecutively")
			check(arrival.age == 0.0, "All four arrivals share the same drop clock")
			previous_word = str(arrival.word.id)
		check(model.upcoming.size() == Model.UPCOMING_COUNT
			and model.upcoming.all(func(tile: Dictionary) -> bool:
				return advertised.all(func(previous: Dictionary) -> bool: return tile.id != previous.id)),
			"A complete drop exposes a fresh four-tile preview without repeating consumed entries")
		model.set_paused(true)
		var paused: Dictionary = model.snapshot()
		model.step(50.0)
		check(model.snapshot() == paused, "Pause freezes the committed preview and active descent together")
		model.set_paused(false)
	var one_step = Model.new()
	var split_steps = Model.new()
	one_step.configure(_vocabulary(), 3, 42)
	split_steps.configure(_vocabulary(), 3, 42)
	one_step.step(21.0)
	for index in range(84):
		split_steps.step(0.25)
	var single_snapshot: Dictionary = one_step.snapshot()
	var split_snapshot: Dictionary = split_steps.snapshot()
	for snapshot in [single_snapshot, split_snapshot]:
		for cell in snapshot.cells:
			cell.age = snappedf(float(cell.age), 0.000001)
	check(single_snapshot == split_snapshot,
		"Equivalent elapsed time reproduces the same four-tile drops, queue, board, ages, and counters")


func _test_manual_drop() -> void:
	var model = Model.new()
	var events: Dictionary = _observe(model)
	model.configure(_vocabulary(), 3, 73)
	model.step(2.0)
	var existing: Array = model.cells.duplicate(true)
	var advertised: Array = model.upcoming.duplicate(true)
	var change_count: Array[int] = [0]
	model.changed.connect(func() -> void: change_count[0] += 1)
	check(model.can_drop_now() and model.drop_now(int(advertised[0].id)),
		"A ready board can release its advertised four-tile batch immediately")
	check(model.cells.size() == INITIAL_COUNT + Model.DROP_COUNT
		and model.generated_tiles == INITIAL_COUNT + Model.DROP_COUNT
		and model.cells.slice(0, INITIAL_COUNT) == existing and model.spawn_elapsed == 0.0,
		"Manual dispatch resets only the supply clock without fast-forwarding existing tiles")
	check(change_count[0] == 1 and events.attempts.is_empty() and events.chests.is_empty()
		and events.cues.is_empty() and model.cleared_pairs == 0 and model.chest_count == 0,
		"Manual dispatch publishes its state once without learning, score, or rewards")
	for index in range(Model.DROP_COUNT):
		var arrival: Dictionary = model.cells[INITIAL_COUNT + index]
		check(arrival.id == advertised[index].id and arrival.word == advertised[index].word
			and arrival.kind == advertised[index].kind and arrival.chest == advertised[index].chest
			and arrival.age == 0.0 and arrival.arrival,
			"Manual dispatch preserves every advertised identity and starts its ordinary fall at zero")
	var dispatched: Dictionary = model.snapshot()
	check(not model.can_drop_now() and not model.drop_now()
		and model.snapshot() == dispatched and change_count[0] == 1,
		"Repeated clicks cannot stack another airborne wave or publish a change")
	model.step(Model.INITIAL_SPAWN_INTERVAL - 0.001)
	check(model.generated_tiles == INITIAL_COUNT + Model.DROP_COUNT and model.can_drop_now(),
		"The automatic cadence restarts with a full interval after an early manual batch")
	model.step(0.001)
	check(model.generated_tiles == INITIAL_COUNT + 2 * Model.DROP_COUNT and model.spawn_elapsed == 0.0,
		"The next automatic drop arrives exactly at its reset interval")
	_assert_board(model, "Manual dispatch and resumed cadence")


func _test_manual_drop_guards() -> void:
	var model = Model.new()
	model.configure(_vocabulary(), 3, 73)
	check(model.can_drop_now() and model.drop_now(), "The opening preview can release a batch before the first automatic interval")
	var blocked: Dictionary = model.snapshot()
	check(not model.can_drop_now() and not model.drop_now() and model.snapshot() == blocked,
		"Manually released airborne tiles block another release without changing the board")
	model.step(Model.SETTLE_SECONDS)
	model.set_paused(true)
	blocked = model.snapshot()
	check(not model.can_drop_now() and not model.drop_now() and model.snapshot() == blocked,
		"A paused round rejects manual release without changing its timer or queue")
	model.set_paused(false)
	var pair: Array[int] = _pair(model)
	model.try_merge(pair[0], pair[1])
	blocked = model.snapshot()
	check(not model.can_drop_now() and not model.drop_now() and model.snapshot() == blocked,
		"An active fusion retains its supply pause when the preview is clicked")
	model.step(0.8)
	blocked = model.snapshot()
	check(not model.can_drop_now() and not model.drop_now() and model.snapshot() == blocked,
		"Disappearance also blocks manual release through the end of the fusion")
	model.finish_round()
	blocked = model.snapshot()
	check(not model.can_drop_now() and not model.drop_now() and model.snapshot() == blocked,
		"A finished round cannot consume upcoming tiles")
	model.configure(_vocabulary(), 3, 73)
	model.step(_danger_start_seconds())
	blocked = model.snapshot()
	check(not model.can_drop_now() and not model.drop_now() and model.snapshot() == blocked,
		"A full board rejects manual release without resetting danger")
	model.configure(_vocabulary(), 3, 73)
	model.step(Model.INITIAL_SPAWN_INTERVAL - 0.01)
	var pressed_id: int = int(model.upcoming[0].id)
	model.step(0.01)
	model.step(_settle_remaining(model))
	blocked = model.snapshot()
	check(model.can_drop_now() and not model.drop_now(pressed_id) and model.snapshot() == blocked,
		"A naturally dispatched preview invalidates an older press token even after its wave lands")
	check(model.drop_now(int(model.upcoming[0].id)), "A fresh preview token releases the current committed batch")
	model.configure(_vocabulary(), 3, 73)
	model.step(Model.SETTLE_SECONDS)
	model.upcoming.clear()
	blocked = model.snapshot()
	check(not model.can_drop_now() and not model.drop_now() and model.snapshot() == blocked,
		"An empty preview cannot produce a partial or fabricated manual batch")


func _test_manual_drop_partial_batch() -> void:
	var model = Model.new()
	var events: Dictionary = _observe(model)
	model.configure(_vocabulary(), 3, 73)
	model.step(4.0 * Model.INITIAL_SPAWN_INTERVAL + Model.SETTLE_SECONDS)
	check(model.cells.size() == Model.CAPACITY - 2 and model.can_drop_now(),
		"Two remaining board slots still allow a manual preview release")
	var existing: Array = model.cells.duplicate(true)
	var advertised: Array = model.upcoming.duplicate(true)
	check(model.drop_now(), "Manual release can consume only the prefix that fits on a nearly full board")
	check(model.cells.size() == Model.CAPACITY and model.generated_tiles == Model.CAPACITY
		and model.cells.slice(0, existing.size()) == existing and model.full_elapsed == -1.0,
		"A partial manual batch preserves existing tiles and waits for landing before danger")
	for index in range(2):
		check(model.cells[existing.size() + index].id == advertised[index].id
			and model.cells[existing.size() + index].age == 0.0,
			"A partial batch starts the exact fitting advertised tiles at the normal entry height")
		check(model.upcoming[index] == advertised[index + 2],
			"A partial batch preserves its unconsumed advertised suffix in order")
	model.step(_settle_remaining(model))
	check(model.full_elapsed == 0.0 and events.cues == ["danger"]
		and events.attempts.is_empty() and events.chests.is_empty(),
		"A manually completed board starts the ordinary full countdown only after all arrivals settle")
	_assert_board(model, "Partial manual dispatch")


func _test_partial_and_stacked_drops() -> void:
	for heights in [[6, 6, 6, 5], [6, 6, 6, 4], [6, 6, 6, 3], [6, 6, 6, 2], [6, 6, 5, 3], [5, 5, 5, 5], [6, 6, 6, 6]]:
		var model = Model.new()
		model.configure(_vocabulary(), 3, 61)
		model.step(_initial_fill_seconds())
		var count: int = 0
		var eligible: Array[int] = []
		for column in range(Model.COLUMNS):
			if int(heights[column]) < Model.ROWS:
				eligible.append(column)
			for row_index in range(int(heights[column])):
				var cell: Dictionary = model.cells[count]
				cell.column = column
				cell.row = Model.ROWS - row_index - 1
				cell.age = Model.SETTLE_SECONDS
				cell.falling_rows = 0
				cell.arrival = false
				count += 1
		model.cells.resize(count)
		model.generated_tiles = count
		model.full_elapsed = -1.0
		model.spawn_elapsed = 0.0
		var advertised: Array = model.upcoming.duplicate(true)
		var expected: int = mini(Model.DROP_COUNT, Model.CAPACITY - count)
		model.step(0.01 if expected == 0 else model.spawn_interval)
		check(model.cells.size() == count + expected and model.generated_tiles == count + expected,
			"A drop fills only its available slots without overflow or losing a queued tile")
		var used: Array[int] = []
		var arrivals: Array[Dictionary] = []
		for offset in range(expected):
			var cell: Dictionary = model.cells[count + offset]
			arrivals.append(cell)
			check(cell.id == advertised[offset].id and cell.word == advertised[offset].word
				and cell.kind == advertised[offset].kind and cell.chest == advertised[offset].chest,
				"A constrained drop consumes its exact advertised prefix")
			if offset < eligible.size():
				check(not used.has(int(cell.column)), "Every available column receives one tile before any column receives another")
			used.append(int(cell.column))
			var ordinal: int = used.count(int(cell.column)) - 1
			check(int(cell.falling_rows) == int(cell.row) + 1 + ordinal
				and Motion.travel_rows(cell) <= Model.ROWS and Motion.ready_at(cell) <= Model.SETTLE_SECONDS,
				"Same-column arrivals enter at separate heights within the bounded landing duration")
		for offset in range(Model.UPCOMING_COUNT - expected):
			check(model.upcoming[offset] == advertised[expected + offset],
				"A partial drop preserves every unconsumed advertised tile at the front")
		for a_index in range(arrivals.size()):
			for b_index in range(a_index + 1, arrivals.size()):
				var a: Dictionary = arrivals[a_index].duplicate(true)
				var b: Dictionary = arrivals[b_index].duplicate(true)
				if a.column != b.column:
					continue
				for age_fraction in [0.0, 0.3, 0.7, 1.0]:
					a.age = Motion.contact_at(a) * age_fraction
					b.age = Motion.contact_at(b) * age_fraction
					var a_y: float = float(a.row) - float(Motion.sample(a).lift_rows)
					var b_y: float = float(b.row) - float(Motion.sample(b).lift_rows)
					check(absf(a_y - b_y) >= 1.0 - Model.EPSILON,
						"Bodies in the same-column batch stay separated throughout descent")
		if expected > 0:
			check(model.full_elapsed < 0.0, "Even a partial final batch cannot begin danger while airborne")
			var settle_time: float = _settle_remaining(model)
			model.step(settle_time - 0.001)
			check(model.full_elapsed < 0.0, "A full board waits for the slowest arrival's final recovery")
			model.step(0.001)
			check(is_zero_approx(model.full_elapsed), "The last landing starts a complete countdown at zero")


func _test_supply_fairness() -> void:
	for pool_size in [1, 2, 3, 4, 16]:
		for seed_value in range(6):
			var model = Model.new()
			model.configure(_vocabulary(pool_size), 3, seed_value)
			for index in range(40):
				model.step(model.spawn_interval - model.spawn_elapsed)
				model.step(Model.SETTLE_SECONDS)
				_assert_board(model, "Pool %d seed %d dispatch %d" % [pool_size, seed_value, index])
				if model.cells.size() == Model.CAPACITY or index % 5 == 0:
					var pair: Array[int] = _pair(model)
					if not pair.is_empty():
						check(model.try_merge(pair[0], pair[1]) == "correct",
							"A full board or ordinary practice can clear a real pair from interleaved supply")
						model.step(Model.FUSION_SECONDS)
				check(model.phase == "playing", "Full-board rescue remains possible after any tested sequence of legal clears")


func _test_fall_physics() -> void:
	var shallow: Dictionary = {"row": 1, "falling_rows": 2, "age": 0.0, "arrival": true}
	var deep: Dictionary = {"row": 5, "falling_rows": 6, "age": 0.0, "arrival": true}
	check(Motion.contact_at(deep) < 1.0 and Motion.contact_at(deep) > 0.75,
		"A six-row arrival reaches the floor in under a second while retaining a visible descent")
	var previous_y: float = float(deep.row) - float(Motion.sample(deep).lift_rows)
	var previous_displacement: float = 0.0
	var displacement_gain: float = -1.0
	for elapsed: float in [0.1, 0.2, 0.3, 0.4]:
		shallow.age = elapsed
		deep.age = elapsed
		var deep_y: float = float(deep.row) - float(Motion.sample(deep).lift_rows)
		var shallow_y: float = float(shallow.row) - float(Motion.sample(shallow).lift_rows)
		check(is_equal_approx(deep_y, shallow_y),
			"Arrivals fall through the same height at equal elapsed time regardless of their destination")
		var displacement: float = deep_y - previous_y
		check(displacement > previous_displacement,
			"Each equal time slice covers more distance as gravity accelerates the arrival")
		if previous_displacement > 0.0:
			var gain: float = displacement - previous_displacement
			if displacement_gain >= 0.0:
				check(is_equal_approx(gain, displacement_gain),
					"The increase in speed remains constant before contact instead of easing toward the floor")
			displacement_gain = gain
		previous_displacement = displacement
		previous_y = deep_y
	var small_collapse: Dictionary = {"row": 5, "falling_rows": 1, "age": 0.0, "arrival": false}
	var large_collapse: Dictionary = {"row": 5, "falling_rows": 4, "age": 0.0, "arrival": false}
	for elapsed: float in [0.04, 0.08, 0.12]:
		small_collapse.age = elapsed
		large_collapse.age = elapsed
		check(is_equal_approx(Motion.travel_rows(small_collapse) - float(Motion.sample(small_collapse).lift_rows),
			Motion.travel_rows(large_collapse) - float(Motion.sample(large_collapse).lift_rows)),
			"Local collapses share their own consistent acceleration across different cleared gaps")
	shallow.age = Motion.contact_at(shallow) + Motion.COMPRESSION_SECONDS
	deep.age = Motion.contact_at(deep) + Motion.COMPRESSION_SECONDS
	var shallow_pose: Dictionary = Motion.sample(shallow)
	var deep_pose: Dictionary = Motion.sample(deep)
	check(float(deep_pose.stretch.y) < float(shallow_pose.stretch.y) - 0.02
		and float(deep_pose.stretch.x) > float(shallow_pose.stretch.x),
		"A longer fall produces a visibly firmer and wider planted compression")
	for boundary: float in [Motion.contact_at(deep), Motion.contact_at(deep) + Motion.COMPRESSION_SECONDS,
		Motion.contact_at(deep) + Motion.COMPRESSION_SECONDS + Motion.REBOUND_SECONDS, Motion.ready_at(deep)]:
		deep.age = boundary - 0.000001
		var before: Dictionary = Motion.sample(deep)
		deep.age = boundary + 0.000001
		var after: Dictionary = Motion.sample(deep)
		check(Vector2(before.stretch).distance_to(Vector2(after.stretch)) < 0.001
			and absf(float(before.lift_rows) - float(after.lift_rows)) < 0.001,
			"Descent, compression, rebound, and recovery join without a position or scale discontinuity")
	var contact: float = Motion.contact_at(deep)
	var settle_duration: float = Motion.ready_at(deep) - contact
	for index in range(41):
		deep.age = contact + settle_duration * float(index) / 40.0
		var pose: Dictionary = Motion.sample(deep)
		check(is_zero_approx(float(pose.lift_rows)), "The landing remains planted throughout compression and recovery")
		if float(deep.age) >= contact + Motion.COMPRESSION_SECONDS:
			check(float(pose.stretch.y) <= 1.04, "The recovery stays restrained instead of bouncing into another jump")
	deep.age = Motion.ready_at(deep)
	check(Motion.sample(deep).stretch.is_equal_approx(Vector2.ONE) and Motion.ready_at(deep) <= Model.SETTLE_SECONDS,
		"The strongest impact returns to its exact neutral scale within the shared input bound")


func _test_landing_timeline() -> void:
	var short_drop: Dictionary = {"row": 4, "falling_rows": 1, "age": 0.0, "arrival": false}
	var long_drop: Dictionary = {"row": 5, "falling_rows": 6, "age": 0.0, "arrival": true}
	check(Motion.travel_rows(short_drop) == 1.0 and Motion.travel_rows(long_drop) == 6.0
		and Motion.contact_at(short_drop) < Motion.contact_at(long_drop)
		and Motion.ready_at(short_drop) < Motion.ready_at(long_drop) and Motion.ready_at(long_drop) <= Model.SETTLE_SECONDS,
		"Local gravity lands sooner than a full descent, and both share the bounded input timeline")
	long_drop.age = Motion.contact_at(long_drop)
	check(is_zero_approx(Motion.sample(long_drop).lift_rows), "Contact reaches its support without sinking below it")
	long_drop.age += Motion.COMPRESSION_SECONDS
	var compressed: Dictionary = Motion.sample(long_drop)
	check(compressed.stretch.y < 0.9 and compressed.stretch.x > 1.0 and compressed.compression > 0.99,
		"The planted contact visibly compresses before recovery")
	long_drop.age = Motion.ready_at(long_drop)
	check(Motion.sample(long_drop).stretch.is_equal_approx(Vector2.ONE) and is_zero_approx(Motion.sample(long_drop).bend),
		"Input readiness coincides with the settled, undeformed body")
	var model = Model.new()
	model.configure(_vocabulary(), 3, 8)
	model.step(3.0 * model.spawn_interval)
	var arriving: Dictionary = model.cells.back()
	var pair: Array[int] = []
	var ready_time: float = Motion.ready_at(arriving)
	for cell in model.cells:
		if cell.word.id == arriving.word.id and cell.kind != arriving.kind:
			pair = [int(arriving.id), int(cell.id)]
			ready_time = maxf(ready_time, Motion.ready_at(cell) - float(cell.age))
	check(pair.size() == 2, "Interleaved supply eventually brings the incoming counterpart of a waiting tile")
	if pair.is_empty():
		return
	model.step(ready_time - 0.001)
	check(model.try_merge(pair[0], pair[1]) == "ignored", "A recovering jelly cannot match just before its ready boundary")
	model.step(0.001)
	check(model.try_merge(pair[0], pair[1]) == "correct", "The exact shared ready boundary enables a matching pair")


func _test_fusion_timeline() -> void:
	var model = Model.new()
	var events: Dictionary = _observe(model)
	model.configure(_vocabulary(), 3, 8)
	model.drop_now()
	var count_before: int = model.cells.size()
	var pair: Array[int] = _pair(model, false, true)
	check(model.try_merge(int(model.cells.back().id), pair[0]) == "ignored", "An incoming tile cannot start a fusion")
	model.step(0.25)
	var saved_spawn: float = model.spawn_elapsed
	var incoming_id: int = int(model.cells.back().id)
	var saved_age: float = float(model.cells.back().age)
	check(model.try_merge(pair[0], pair[1]) == "correct", "A settled word and its picture begin fusion")
	check(events.fusions.size() == 1 and events.cues == ["merge"], "Fusion emits its payload and merge cue once")
	check(events.fusions[0].a.id == pair[0] and events.fusions[0].b.id == pair[1],
		"Fusion payload preserves both source tiles for presentation")
	check(model.cells.size() == count_before and events.attempts.is_empty(), "Starting fusion keeps tiles and delays learning credit")
	check(model.try_merge(pair[1], pair[0]) == "ignored", "Repeated input during fusion cannot double-credit")
	model.step(0.69)
	check(events.cues == ["merge"], "The pop cue waits for the fusion pop point")
	model.step(0.01)
	check(events.cues == ["merge", "pop"], "The pop cue occurs at 0.7 seconds")
	model.step(0.349)
	check(model.cells.size() == count_before and events.attempts.is_empty(), "A nearly finished fusion does not credit early")
	check(is_equal_approx(float(model.tile_by_id(incoming_id).age), saved_age),
		"An incoming tile freezes in the air throughout fusion")
	model.step(0.001)
	check(model.cells.size() == count_before - 2 and model.fusion.is_empty() and model.cleared_pairs == 1,
		"The 1.05 second fusion clears exactly two tiles")
	check(is_equal_approx(model.spawn_elapsed, saved_spawn), "Spawning remains frozen throughout fusion")
	check(events.attempts.size() == 1 and events.attempts[0].correct
		and events.attempts[0].words.size() == 1, "A successful clear emits one unique-word learning event")
	check(model.chest_count == 1 and events.chests == [1] and events.cues == ["merge", "pop", "chest"],
		"Chest credit and its cue happen once after a marked pair clears")
	check(model.try_merge(pair[0], pair[1]) == "ignored" and events.attempts.size() == 1,
		"Removed tile IDs cannot replay learning or rewards")
	check(is_equal_approx(model.spawn_interval, 9.95), "The first clear gently reduces the ten-second interval by 0.05 seconds")
	_assert_board(model, "Completed fusion")


func _test_overlapping_fusions() -> void:
	var model = Model.new()
	var events: Dictionary = _observe(model)
	model.configure(_vocabulary(), 3, 31)
	model.step(_danger_start_seconds() + 3.0)
	var first: Array[int] = _pair(model, true, true)
	var original: Dictionary = model.snapshot()
	check(model.try_merge(first[0], first[1]) == "correct", "A first marked pair starts during danger")
	model.step(0.4)
	var second: Array[int] = _pair(model, true, true)
	check(second.size() == 2 and model.try_merge(second[0], second[1]) == "correct",
		"An independent settled pair starts while the first pair is still merging")
	check(model.fusions.size() == 2 and model.fusion.a_id == first[0]
		and is_equal_approx(float(model.fusions[0].elapsed), 0.4)
		and is_zero_approx(float(model.fusions[1].elapsed)),
		"Concurrent fusions retain independent clocks and the oldest compatibility snapshot")
	check(model.is_fusing(first[0]) and model.is_fusing(first[1])
		and model.is_fusing(second[0]) and model.is_fusing(second[1]) and not model.is_fusing(-1),
		"Both participants of every active fusion are reserved")
	var snapshot: Dictionary = model.snapshot()
	snapshot.fusions[1].word.id = "tampered"
	snapshot.fusions[0].elapsed = 100.0
	snapshot.fusions.clear()
	check(model.fusions.size() == 2 and model.fusions[1].word.id != "tampered"
		and is_equal_approx(float(model.fusion.elapsed), 0.4),
		"Concurrent fusion snapshots cannot mutate model timelines or vocabulary")
	var third: Array[int] = _pair(model)
	check(model.try_merge(first[1], first[0]) == "ignored"
		and model.try_merge(second[0], third[0]) == "ignored"
		and model.try_merge(third[0], second[1]) == "ignored"
		and events.attempts.is_empty() and events.fusions.size() == 2,
		"Reserved source and target tiles cannot earn duplicate or incorrect attempts")
	var wrong: Array[int] = []
	for cell in model.cells:
		if not model.is_fusing(int(cell.id)) and cell.word.id != model.tile_by_id(third[0]).word.id:
			wrong = [third[0], int(cell.id)]
			break
	check(wrong.size() == 2 and model.try_merge(wrong[0], wrong[1]) == "wrong",
		"A wrong drag between unreserved tiles is still judged during another fusion")
	check(events.attempts.size() == 1 and not events.attempts[0].correct and model.fusions.size() == 2,
		"An independent mistake leaves both running fusions intact")
	model.step(0.3)
	check(events.cues.count("pop") == 1 and model.fusions[0].popped and not model.fusions[1].popped,
		"Each overlapping pair emits pop only at its own 0.7 second point")
	model.step(0.35)
	check(model.cleared_pairs == 1 and model.cells.size() == Model.CAPACITY - 2
		and model.fusions.size() == 1 and model.fusion.a_id == second[0]
		and is_equal_approx(float(model.fusion.elapsed), 0.65),
		"The first pair clears at 1.05 seconds while the newer pair keeps its original clock")
	check(model.chest_count == 1 and events.chests == [1] and events.completed.size() == 1
		and events.completed[0].fusion.a_id == first[0] and events.completed[0].fusion.b_id == first[1]
		and events.completed[0].awarded == 1,
		"A completed pair publishes exactly its own source tiles and earned chest")
	for cell in model.cells:
		var previous: Dictionary = {}
		for candidate in original.cells:
			if candidate.id == cell.id:
				previous = candidate
		check(cell == previous, "Earlier clears do not move or age any tile while another fusion is active")
	check(model.upcoming == original.upcoming and model.generated_tiles == original.generated_tiles
		and is_equal_approx(model.spawn_elapsed, float(original.spawn_elapsed)) and model.full_elapsed == -1.0,
		"Overlapping clears keep supply paused and the first completed rescue cancels danger")
	model.step(0.05)
	check(events.cues.count("pop") == 2 and model.fusion.popped,
		"The second elastic pop follows its own clock instead of the previous clear")
	model.step(0.35)
	check(model.fusions.is_empty() and model.fusion.is_empty() and model.cleared_pairs == 2
		and model.chest_count == 2 and events.completed.size() == 2 and events.chests == [1, 1],
		"Both overlapping pairs complete independently with one success and one chest each")
	check(events.attempts.size() == 3 and events.attempts[1].correct and events.attempts[2].correct
		and events.attempts[1].id != events.attempts[2].id
		and events.completed[1].fusion.a_id == second[0]
		and is_equal_approx(float(events.completed[1].fusion.elapsed), Model.FUSION_SECONDS),
		"Completion receipts identify the exact pair and cannot duplicate learning credit")
	check(model.upcoming == original.upcoming and model.generated_tiles == original.generated_tiles
		and is_equal_approx(model.spawn_elapsed, float(original.spawn_elapsed)),
		"Falling and supply remain frozen through the final disappearance boundary")
	_assert_board(model, "Concurrent fusion final gravity")
	model.step(0.05)
	check(is_equal_approx(model.spawn_elapsed, float(original.spawn_elapsed) + 0.05),
		"The supply clock resumes only after all active fusions finish")


func _test_concurrent_fusion_lifecycle() -> void:
	var model = Model.new()
	var events: Dictionary = _observe(model)
	model.configure(_vocabulary(), 3, 42)
	var first: Array[int] = _pair(model, true, true)
	model.try_merge(first[0], first[1])
	model.step(0.8)
	var second: Array[int] = _pair(model)
	check(model.try_merge(second[0], second[1]) == "correct" and model.fusions.size() == 2,
		"Another drag can begin a fusion during the first pair's disappearance")
	var incoming: Dictionary = model.cells.back().duplicate(true)
	model.set_paused(true)
	var paused: Dictionary = model.snapshot()
	var cues: Array = events.cues.duplicate()
	model.step(10.0)
	check(model.snapshot() == paused and events.cues == cues,
		"Menu pause freezes all concurrent timelines, airborne tiles, and sounds")
	var third: Array[int] = _pair(model)
	check(model.try_merge(third[0], third[1]) == "ignored", "A paused round rejects an otherwise independent pair")
	model.set_paused(false)
	model.step(0.25)
	check(model.cleared_pairs == 1 and model.fusions.size() == 1
		and is_equal_approx(float(model.fusion.elapsed), 0.25)
		and model.tile_by_id(int(incoming.id)) == incoming,
		"Resume preserves overlap timing and freezes an incoming tile until the last pair finishes")
	var result: Dictionary = model.finish_round()
	check(result.cleared_pairs == 1 and result.chest_count == 1 and model.fusions.is_empty()
		and events.attempts.size() == 1 and events.completed.size() == 1,
		"Finishing retains an earlier completed pair but cancels every pending fusion")
	model.step(20.0)
	check(model.finish_round() == result and events.finished.size() == 1 and events.chests == [1],
		"Finishing or stepping an interrupted overlap cannot repeat rewards")
	model.configure(_vocabulary(), 3, 42)
	first = _pair(model)
	model.try_merge(first[0], first[1])
	second = _pair(model)
	model.try_merge(second[0], second[1])
	model.step(0.5)
	model.configure(_vocabulary(), 3, 42)
	check(model.fusions.is_empty() and model.cleared_pairs == 0 and model.chest_count == 0
		and model.generated_tiles == INITIAL_COUNT and model.spawn_elapsed == 0.0,
		"A new round drops every overlapping timeline and reservation without carrying score")
	var attempts: int = events.attempts.size()
	model.step(2.0)
	check(events.attempts.size() == attempts and events.completed.size() == 1,
		"Reset timelines cannot complete later in a new round")


func _test_held_source_after_gravity() -> void:
	var model = Model.new()
	var events: Dictionary = _observe(model)
	model.configure(_vocabulary(), 3, 42)
	var pair: Array[int] = _pair(model)
	var source_index: int = model._index_for_id(pair[0])
	var target_index: int = model._index_for_id(pair[1])
	model.cells[source_index].age = 0.0
	model.cells[source_index].falling_rows = 1
	check(model.try_merge(pair[0], pair[1]) == "ignored" and model.fusions.is_empty(),
		"A newly falling source cannot be picked up through ordinary merge input")
	model.cells[target_index].age = 0.0
	model.cells[target_index].falling_rows = 1
	check(model.try_merge(pair[0], pair[1], true) == "ignored" and events.fusions.is_empty(),
		"An existing held source cannot bypass the target's landing gate")
	model.cells[target_index].age = Model.SETTLE_SECONDS
	check(model.try_merge(pair[0], pair[1], true) == "correct" and model.fusions.size() == 1,
		"A drag already held before gravity can release onto a settled matching target")
	check(model.try_merge(pair[0], pair[1], true) == "ignored" and events.fusions.size() == 1,
		"An existing held source cannot bypass a fusion reservation")
	model.step(Model.FUSION_SECONDS)
	check(events.attempts.size() == 1 and events.attempts[0].correct and model.cleared_pairs == 1,
		"A held source accepted after gravity earns exactly one normal learning receipt")


func _test_concurrent_fusion_reentry() -> void:
	for action: String in ["pause", "finish", "reset"]:
		var model = Model.new()
		var events: Dictionary = _observe(model)
		model.configure(_vocabulary(), 3, 42)
		var first: Array[int] = _pair(model)
		model.try_merge(first[0], first[1])
		var second: Array[int] = _pair(model)
		model.try_merge(second[0], second[1])
		var interrupt: Callable = func(cue: String) -> void:
			if cue != "pop":
				return
			match action:
				"pause":
					model.set_paused(true)
				"finish":
					model.finish_round()
				"reset":
					model.configure(_vocabulary(), 3, 42)
		model.cue_requested.connect(interrupt)
		model.step(2.0)
		check(events.cues.count("pop") == 1 and events.attempts.is_empty() and events.completed.is_empty(),
			"A synchronous %s at one pop prevents stale sibling events or rewards" % action)
		model.cue_requested.disconnect(interrupt)
		if action == "pause":
			check(model.fusions.size() == 2 and model.fusions[0].popped and not model.fusions[1].popped,
				"Pause during a shared pop boundary retains the unannounced sibling event")
			model.set_paused(false)
			model.step(0.35)
			check(model.cleared_pairs == 2 and events.cues.count("pop") == 2 and events.completed.size() == 2,
				"Resume publishes each interrupted simultaneous event exactly once")
		else:
			check(model.fusions.is_empty(), "Finish or reset removes every concurrent reservation")
	for action: String in ["finish", "reset"]:
		var model = Model.new()
		var events: Dictionary = _observe(model)
		model.configure(_vocabulary(), 3, 42)
		var first: Array[int] = _pair(model, true, true)
		model.try_merge(first[0], first[1])
		var second: Array[int] = _pair(model)
		model.try_merge(second[0], second[1])
		var interrupt: Callable = func(_payload: Dictionary, _awarded: int) -> void:
			if action == "finish":
				model.finish_round()
			else:
				model.configure(_vocabulary(), 3, 42)
		model.fusion_completed.connect(interrupt)
		model.step(2.0)
		check(events.attempts.size() == 1 and events.completed.size() == 1
			and events.chests.is_empty() and events.cues.count("chest") == 0 and model.fusions.is_empty(),
			"A synchronous %s from a completion cannot leak the old chest cue or sibling completion" % action)
		check(model.chest_count == (1 if action == "finish" else 0),
			"A completion callback retains earned rewards only in the finished round")
	var chained = Model.new()
	var chained_events: Dictionary = _observe(chained)
	chained.configure(_vocabulary(), 3, 42)
	var pair: Array[int] = _pair(chained)
	chained.try_merge(pair[0], pair[1])
	var add_at_pop: Callable = func(cue: String) -> void:
		if cue == "pop" and chained_events.fusions.size() == 1:
			var next: Array[int] = _pair(chained)
			chained.try_merge(next[0], next[1])
	chained.cue_requested.connect(add_at_pop)
	chained.step(1.75)
	check(chained.cleared_pairs == 2 and chained.fusions.is_empty()
		and chained_events.cues.count("merge") == 2 and chained_events.cues.count("pop") == 2,
		"A pair accepted during an event callback gets its full independent timeline within a long frame")


func _test_fusion_freezes_arrival() -> void:
	var model = Model.new()
	model.configure(_vocabulary(), 3, 31)
	model.drop_now()
	model.step(0.25)
	var incoming: Dictionary = model.cells.back().duplicate(true)
	var pair: Array[int] = []
	for support in model.cells:
		if int(support.column) != int(incoming.column) or not model.is_settled(support):
			continue
		for other in model.cells:
			if support.word.id == other.word.id and support.kind != other.kind:
				pair = [int(support.id), int(other.id)]
	check(pair.size() == 2, "The incoming column has a settled supporting pair available for a retargeted landing")
	if pair.is_empty():
		return
	var original_y: float = float(incoming.row) - float(Motion.sample(incoming).lift_rows)
	var committed: Array = model.upcoming.duplicate(true)
	model.try_merge(pair[0], pair[1])
	model.step(Model.FUSION_SECONDS - 0.001)
	check(model.tile_by_id(int(incoming.id)) == incoming,
		"Fusion suspends every property of the airborne tile before its support clears")
	model.step(0.001)
	var retargeted: Dictionary = model.tile_by_id(int(incoming.id))
	var resumed_y: float = float(retargeted.row) - float(Motion.sample(retargeted).lift_rows)
	check(int(retargeted.row) > int(incoming.row) and retargeted.arrival
		and is_equal_approx(float(retargeted.age), float(incoming.age)) and is_equal_approx(resumed_y, original_y),
		"Removing support extends the fall without teleporting or restarting its descent")
	check(model.upcoming == committed, "A moving landing target cannot rewrite advertised supply")
	model.step(0.05)
	var resumed: Dictionary = model.tile_by_id(int(incoming.id))
	check(float(resumed.age) > float(incoming.age)
		and float(resumed.row) - float(Motion.sample(resumed).lift_rows) > resumed_y,
		"The frozen arrival continues downward immediately after fusion completes")


func _test_wrong_and_ignored_attempts() -> void:
	var model = Model.new()
	var events: Dictionary = _observe(model)
	model.configure(_vocabulary(), 3, 4)
	model.step(Model.SETTLE_SECONDS)
	var a: int = int(model.cells[0].id)
	var b: int = int(model.cells[2].id)
	var expected_words: Array[String] = [str(model.cells[0].word.id), str(model.cells[2].word.id)]
	check(model.try_merge(a, b) == "wrong", "Different words are a wrong merge")
	check(events.attempts.size() == 1 and not events.attempts[0].correct
		and events.attempts[0].words == expected_words, "Wrong merges reset both unique involved words")
	check(model.cells.size() == INITIAL_COUNT and model.fusion.is_empty() and model.cleared_pairs == 0,
		"Wrong merges leave the board playable without rewards")
	check(model.try_merge(a, a) == "ignored" and model.try_merge(a, 100000) == "ignored"
		and events.attempts.size() == 1, "Self and unknown tile IDs do not create learning events")
	model.set_paused(true)
	check(model.try_merge(a, b) == "ignored" and events.attempts.size() == 1, "Paused input is ignored")
	model.set_paused(false)
	model.configure([_word("same")], 3, 4)
	model.step(Model.SETTLE_SECONDS)
	var same_kind: Array[int] = []
	for cell in model.cells:
		if cell.kind == "word":
			same_kind.append(int(cell.id))
	check(model.try_merge(same_kind[0], same_kind[1]) == "wrong", "Two word tiles cannot match even when their word is identical")
	check(events.attempts.back().words == ["same"], "A same-word mistake resets that word once")
	model.finish_round()
	var attempts: int = events.attempts.size()
	check(model.try_merge(same_kind[0], same_kind[1]) == "ignored" and events.attempts.size() == attempts,
		"Finished input cannot create learning events")


func _test_full_board_timeout() -> void:
	var model = Model.new()
	var events: Dictionary = _observe(model)
	model.configure(_vocabulary(), 3, 9)
	model.step(_danger_start_seconds())
	check(model.cells.size() == 24 and is_equal_approx(float(model.snapshot().full_remaining), 8.0),
		"Four drops and the final batch's landing expose the full eight-second countdown")
	check(events.cues == ["danger"], "A newly full board emits one warning at elapsed zero")
	for second in range(7):
		model.step(0.999)
		check(events.cues.size() == second + 1, "A warning never precedes its next one-second boundary")
		model.step(0.001)
		check(model.phase == "playing" and events.finished.is_empty(), "Each remaining second still allows a matching chance")
		check(events.cues.size() == second + 2 and events.cues.count("danger") == second + 2
			and is_equal_approx(model.full_elapsed, float(second + 1)),
			"Each displayed remaining second has exactly one warning on its own clock boundary")
	model.step(0.999)
	check(model.phase == "playing", "A nearly expired countdown does not end early")
	model.step(0.001)
	check(model.phase == "finished" and events.finished.size() == 1, "A continuously full board ends exactly once at eight seconds")
	check(events.cues.size() == 8 and events.cues.count("danger") == 8,
		"Exactly eight warning beats cover elapsed zero through seven, without an expiry cue")
	check(events.finished[0].chest_count == 0 and events.finished[0].cleared_pairs == 0
		and events.finished[0].words.is_empty(), "Uncleared chest tiles do not award rewards")
	var ended: Dictionary = model.snapshot()
	model.step(100.0)
	model.finish_round()
	check(events.finished.size() == 1 and model.snapshot() == ended, "Time and repeated finish calls cannot replay a completed round")
	var giant_step = Model.new()
	var giant_events: Dictionary = _observe(giant_step)
	giant_step.configure(_vocabulary(), 3, 9)
	giant_step.step(1000.0)
	check(giant_step.phase == "finished" and giant_events.cues == events.cues,
		"A long frame preserves the complete spawn and danger event sequence")


func _test_danger_rescue_and_pause() -> void:
	var model = Model.new()
	var events: Dictionary = _observe(model)
	model.configure(_vocabulary(), 3, 14)
	model.step(_danger_start_seconds() + Model.FULL_SECONDS - 0.1)
	check(model.phase == "playing" and model.full_elapsed > 7.8, "The last countdown fraction remains playable")
	var pair: Array[int] = _pair(model)
	var danger: float = model.full_elapsed
	var warnings: int = events.cues.count("danger")
	check(warnings == 8, "A late rescue follows all eight warning beats of the original countdown")
	check(model.try_merge(pair[0], pair[0]) == "ignored" and model.full_elapsed == danger,
		"A canceled drop does not reset the full-board countdown")
	check(model.try_merge(pair[0], pair[1]) == "correct", "A correct merge can rescue a nearly expired full board")
	model.step(0.6)
	check(model.full_elapsed == danger and model.phase == "playing" and events.cues.count("danger") == warnings,
		"Fusion freezes danger and emits no warning during a committed rescue")
	model.set_paused(true)
	var paused_state: Dictionary = model.snapshot()
	var paused_cues: Array = events.cues.duplicate()
	model.step(50.0)
	check(model.snapshot() == paused_state and events.cues == paused_cues,
		"Pause freezes cell age, fusion, spawning, countdown, and audio cues together")
	model.set_paused(false)
	model.step(0.45)
	check(model.cells.size() == 22 and model.full_elapsed == -1.0 and events.finished.is_empty()
		and events.cues.count("danger") == warnings,
		"Completing the rescue cancels the old countdown")
	model.step(model.spawn_interval)
	check(model.cells.size() == 24 and model.full_elapsed == -1.0,
		"A partial replacement batch fills the two free slots but waits for landing before danger")
	model.step(_settle_remaining(model))
	check(model.cells.size() == 24 and is_zero_approx(model.full_elapsed) and events.cues.count("danger") == warnings + 1,
		"The replacement batch's final landing starts a fresh, complete danger window")
	model.set_paused(true)
	paused_state = model.snapshot()
	paused_cues = events.cues.duplicate()
	model.step(20.0)
	check(model.snapshot() == paused_state and events.cues == paused_cues,
		"A paused full board cannot schedule another warning")
	model.set_paused(false)
	model.step(0.999)
	check(events.cues == paused_cues, "Resume keeps the original beat phase without replaying its entry warning")
	model.step(0.001)
	check(events.cues.count("danger") == warnings + 2, "The next resumed warning waits for the next clock boundary")
	model.step(6.9)
	check(model.phase == "playing" and events.cues.count("danger") == warnings + 8,
		"Resumed danger retains its remaining time and exact remaining warning beats")


func _test_finish_and_reset() -> void:
	var model = Model.new()
	var events: Dictionary = _observe(model)
	model.configure(_vocabulary(), 3, 5)
	model.step(Model.SETTLE_SECONDS)
	var pair: Array[int] = _pair(model, true, true)
	model.try_merge(pair[0], pair[1])
	model.step(Model.FUSION_SECONDS)
	model.step(Model.SETTLE_SECONDS)
	pair = _pair(model)
	model.try_merge(pair[0], pair[1])
	model.step(0.8)
	var result: Dictionary = model.finish_round()
	check(result.chest_count == 1 and result.cleared_pairs == 1 and result.score == 1 and model.snapshot().score == 1 and result.words.size() == 1,
		"Explicit exit preserves completed rewards and unique successful words")
	check(model.fusion.is_empty() and events.attempts.size() == 1 and events.finished.size() == 1,
		"Exit cancels an unfinished fusion without success credit")
	model.step(10.0)
	check(model.finish_round() == result and events.chests == [1] and events.finished.size() == 1,
		"Repeated exit cannot duplicate a reward or finish event")
	result.words[0].id = "tampered"
	check(model.finish_round().words[0].id != "tampered", "Finish results cannot mutate saved model state")
	model.set_paused(true)
	check(model.configure(_vocabulary(), 3, 5), "A finished or paused model can start a new round")
	check(model.phase == "playing" and not model.paused and model.fusion.is_empty()
		and model.chest_count == 0 and model.cleared_pairs == 0 and model.full_elapsed == -1.0,
		"Configure resets all lifecycle and reward state")
	model.step(Model.SETTLE_SECONDS)
	pair = _pair(model)
	model.try_merge(pair[0], pair[1])
	model.step(Model.FUSION_SECONDS)
	check(events.attempts.back().id == "jelly-1", "Attempt IDs restart within the caller's new round namespace")
	model.finish_round()
	check(events.finished.size() == 2, "Each configured round produces one independent finish")


func _test_long_round() -> void:
	var model = Model.new()
	var events: Dictionary = _observe(model)
	model.configure([_word("repeat")], 3, 2)
	for index in range(100):
		while _pair(model, false).is_empty():
			model.step(model.spawn_interval - model.spawn_elapsed)
		model.step(Model.SETTLE_SECONDS)
		var pair: Array[int] = _pair(model)
		check(not pair.is_empty(), "A long round always has a pair available after supply settles")
		if pair.is_empty():
			break
		check(model.try_merge(pair[0], pair[1]) == "correct", "Long-round matching remains responsive")
		model.step(Model.FUSION_SECONDS)
		check(model.spawn_interval >= 6.0 and model.spawn_interval <= 10.0,
			"Spawn acceleration always remains within its specified limits")
		if model.cleared_pairs in [20, 50, 80]:
			var expected_interval: float = 9.0 if model.cleared_pairs == 20 else 7.5 if model.cleared_pairs == 50 else 6.0
			check(is_equal_approx(model.spawn_interval, expected_interval),
				"%d completed pairs leave %.1f seconds between four-tile drops" % [model.cleared_pairs, expected_interval])
			var generated: int = model.generated_tiles
			var expected_drop: int = mini(Model.DROP_COUNT, Model.CAPACITY - model.cells.size())
			model.step(model.spawn_interval - model.spawn_elapsed - 0.001)
			check(model.generated_tiles == generated, "An accelerated drop still waits for its complete interval")
			model.step(0.001)
			check(model.generated_tiles == generated + expected_drop,
				"An accelerated boundary dispatches one batch, limited only by available space")
		elif model.cleared_pairs == 79:
			check(model.spawn_interval > 6.0, "The fastest pace is not reached before eighty completed pairs")
		_assert_board(model, "Long-round clear %d" % index)
	check(model.cleared_pairs == 100 and model.spawn_interval == 6.0, "Long play holds the minimum six-second interval")
	check(model.chest_count > 3, "Jelly rewards have no unrelated three-chest cap")
	var awarded: int = 0
	for count in events.chests:
		awarded += int(count)
	check(awarded == model.chest_count and events.attempts.size() == 100,
		"Repeated play credits exactly one success per clear and exactly its marked tiles")
	var attempt_ids: Dictionary = {}
	for attempt in events.attempts:
		check(not attempt_ids.has(attempt.id), "Every accepted learning event has a unique round-local receipt")
		attempt_ids[attempt.id] = true
	var result: Dictionary = model.finish_round()
	check(result.words.size() == 1 and result.words[0].id == "repeat", "Result review words are unique despite repeated successful practice")


func _test_catalog_levels() -> void:
	var vocabulary: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	for level in range(3, 13):
		var model = Model.new()
		check(model.configure(vocabulary, level, level), "Every growth level has enough pictured words for Jelly Match")
		model.step(_initial_fill_seconds() + Model.SETTLE_SECONDS)
		for cell in model.cells:
			check(int(cell.word.get("min_age", 3)) <= level and not str(cell.word.image).is_empty(),
				"The real curriculum respects pictured eligibility at level %d" % level)
		_assert_board(model, "Curriculum level %d" % level)
		var before: Dictionary = model.snapshot()
		model.step(-1.0)
		model.step(0.0)
		model.step(INF)
		model.step(NAN)
		check(model.snapshot() == before, "Invalid time deltas do not mutate the board")


func _test_signal_reentry() -> void:
	var model = Model.new()
	var events: Dictionary = _observe(model)
	model.configure(_vocabulary(), 3, 42)
	model.step(Model.SETTLE_SECONDS)
	var exit_on_pop: Callable = func(cue: String) -> void:
		if cue == "pop":
			model.finish_round()
	model.cue_requested.connect(exit_on_pop)
	var pair: Array[int] = _pair(model, true, true)
	model.try_merge(pair[0], pair[1])
	model.step(Model.FUSION_SECONDS)
	check(model.phase == "finished" and events.finished.size() == 1 and events.attempts.is_empty()
		and model.chest_count == 0, "An exit at the pop cue cancels the pending clear safely")
	model.cue_requested.disconnect(exit_on_pop)
	var reset_model = Model.new()
	var reset_events: Dictionary = _observe(reset_model)
	reset_model.configure(_vocabulary(), 3, 12)
	reset_model.step(Model.SETTLE_SECONDS)
	var reset_on_wrong: Callable = func(_id: String, _words: Array[String], correct: bool) -> void:
		if not correct:
			reset_model.configure(_vocabulary(), 3, 12)
	reset_model.word_attempted.connect(reset_on_wrong)
	reset_model.try_merge(int(reset_model.cells[0].id), int(reset_model.cells[2].id))
	check(reset_events.cues.is_empty() and reset_model.generated_tiles == INITIAL_COUNT,
		"A synchronous round reset prevents stale wrong feedback reaching the next round")
	reset_model.word_attempted.disconnect(reset_on_wrong)


func _test_danger_signal_reentry() -> void:
	for action: String in ["pause", "finish", "reset", "fusion"]:
		var model = Model.new()
		var events: Dictionary = _observe(model)
		model.configure(_vocabulary(), 3, 18)
		var interrupt: Callable = func(cue: String) -> void:
			if cue != "danger":
				return
			match action:
				"pause":
					model.set_paused(true)
				"finish":
					model.finish_round()
				"reset":
					model.configure(_vocabulary(), 3, 18)
				"fusion":
					var chosen: Array[int] = _pair(model)
					model.try_merge(chosen[0], chosen[1])
		model.cue_requested.connect(interrupt)
		model.step(_danger_start_seconds() + 0.5)
		var expected: Array = ["danger", "merge"] if action == "fusion" else ["danger"]
		check(events.cues == expected, "A synchronous %s at the warning cannot leak another old countdown cue" % action)
		match action:
			"pause":
				check(model.paused and is_zero_approx(model.full_elapsed), "Pausing inside a warning freezes its clock at the beat")
			"finish":
				check(model.phase == "finished" and events.finished.size() == 1 and model.chest_count == 0,
					"Finishing inside a warning closes the round once without an unearned reward")
			"reset":
				check(model.phase == "playing" and model.generated_tiles == INITIAL_COUNT and model.full_elapsed == -1.0,
					"Resetting inside a warning leaves the new round's supply and countdown untouched")
			"fusion":
				check(not model.fusion.is_empty() and is_zero_approx(model.full_elapsed) and events.attempts.is_empty(),
					"A rescue inside a warning freezes the clock without granting premature learning credit")
		model.cue_requested.disconnect(interrupt)
