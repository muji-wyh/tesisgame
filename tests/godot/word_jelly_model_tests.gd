extends SceneTree

const Model = preload("res://scripts/word_jelly_model.gd")
const Motion = preload("res://scripts/jelly_motion.gd")
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
	_test_merging_and_collection()
	_test_current_age_validation()
	_test_repeated_merge_and_fragments()
	_test_collection_timeline_and_pause()
	_test_collection_gravity()
	_test_gravity_partial_support()
	_test_gravity_held_stack()
	_test_gravity_reserved_operations()
	_test_gravity_simultaneous_collections()
	_test_gravity_settlement_determinism()
	_test_growth_after_gravity()
	_test_gravity_wallet_failure()
	_test_gravity_lifecycle()
	_test_wallet_retry()
	_test_chests()
	_test_packing_and_growth()
	_test_target_placement()
	_test_edge_placement()
	_test_fusion_reservations()
	_test_deferred_growth()
	_test_growth_after_settlement()
	_test_splitting()
	_test_nested_splits()
	_test_split_placement()
	_test_split_supported_destinations()
	_test_split_vertical_landing_tie()
	_test_split_sibling_support()
	_test_split_concurrent_support()
	_test_split_reservations()
	_test_growth_after_split()
	_test_split_determinism()
	_test_split_wallet_history()
	_test_split_lifecycle()
	_test_split_danger()
	_test_full_board()
	_test_independent_operations()
	_test_lifecycle_reentry()
	_test_supply_and_determinism()
	_test_arrival_timing()
	_test_arrival_readiness_and_pause()
	_test_arrival_automatic_timing()
	_test_arrival_full_board_determinism()
	_test_arrival_reachable_lanes()
	_test_arrival_reserved_lanes()
	_test_arrival_same_lane_spacing()
	print("Word Jelly model: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _word(text: String, age: int = 3, word_id: String = "") -> Dictionary:
	return {"id": text if word_id.is_empty() else word_id, "text": text, "min_age": age,
		"image": "assets/images/words/cat.png", "audio": "assets/audio/words/cat.wav"}


func _model(words: Array = []) -> RefCounted:
	var model := Model.new()
	model.configure([_word("cat"), _word("caterpillar"), _word("sunflower")] if words.is_empty() else words, 3, 42)
	model.spawn_interval = 10000.0
	return model


func _tile(id: int, text: String, mass: int = 1, fragments: int = 0, word: Dictionary = {}) -> Dictionary:
	return {"id": id, "text": text, "mass": mass, "parts_count": mass, "fragments": fragments,
		"chest": fragments > 0, "word": word.duplicate(true), "kind": "word" if not word.is_empty() else "root",
		"column": id % Model.COLUMNS, "row": Model.ROWS - 1, "width": 1, "height": 1,
		"age": Model.SETTLE_SECONDS, "settling": false, "arrival": false, "falling_rows": 0}


func _board(model, pieces: Array[String], fragments: Array[int] = []) -> void:
	model.cells.clear()
	for index in range(pieces.size()):
		var tile: Dictionary = _tile(1000 + index, pieces[index], 1, fragments[index] if index < fragments.size() else 0)
		tile.column = index % Model.COLUMNS
		tile.row = Model.ROWS - 1 - int(index / Model.COLUMNS)
		model.cells.append(tile)


func _placed_tile(id: int, text: String, column: int, row: int, mass: int = 1, fragments: int = 0, word: Dictionary = {}) -> Dictionary:
	var tile: Dictionary = _tile(id, text, mass, fragments, word)
	tile.column = column
	tile.row = row
	tile.width = mini(mass, Model.COLUMNS)
	tile.height = ceili(float(mass) / Model.COLUMNS)
	return tile


func _footprint(tile: Dictionary) -> Rect2i:
	return Rect2i(int(tile.column), int(tile.row), int(tile.width), int(tile.height))


func _fill_rows(model, first_row: int, last_row: int) -> void:
	var next_id: int = 2000
	for row in range(first_row, last_row + 1):
		for column in range(Model.COLUMNS):
			var occupied: bool = false
			for tile: Dictionary in model.cells:
				if _footprint(tile).has_point(Vector2i(column, row)):
					occupied = true
					break
			if not occupied:
				model.cells.append(_placed_tile(next_id, "x", column, row))
				next_id += 1


func _assert_reservations(model, label: String) -> void:
	var results: Array[Rect2i] = []
	for active: Dictionary in model.fusions:
		var destinations: Array = [active.result] if str(active.operation) == "merge" else active.get("results", [])
		for destination: Dictionary in destinations:
			var footprint: Rect2i = _footprint(destination)
			for previous: Rect2i in results:
				check(not footprint.intersects(previous), label + ": independent future footprints never overlap")
			for tile: Dictionary in model.cells:
				if int(tile.id) not in [int(active.a_id), int(active.b_id)]:
					check(not footprint.intersects(_footprint(tile)), label + ": live neighbors cannot occupy a reserved destination")
			results.append(footprint)


func _merge(model, source: int, target: int) -> Dictionary:
	model.step(Model.SETTLE_SECONDS)
	check(model.try_merge(source, target) == "merged", "available jellies can merge")
	if model.fusions.is_empty():
		return {}
	var result_id: int = int(model.fusions.back().result.id)
	model.step(Model.FUSION_SECONDS)
	return model.cell(result_id)


func _assert_board(model, label: String) -> void:
	var ids: Dictionary = {}
	var occupied: Dictionary = {}
	for tile in model.cells:
		check(not ids.has(tile.id), label + ": unique tile ID")
		ids[tile.id] = true
		check(int(tile.column) >= 0 and int(tile.row) >= 0 and int(tile.width) >= 1 and int(tile.height) >= 1
			and int(tile.column) + int(tile.width) <= Model.COLUMNS and int(tile.row) + int(tile.height) <= Model.ROWS,
			label + ": every rectangular footprint stays within six columns and eight rows")
		for y in range(int(tile.row), int(tile.row) + int(tile.height)):
			for x in range(int(tile.column), int(tile.column) + int(tile.width)):
				var key: int = y * Model.COLUMNS + x
				check(not occupied.has(key), label + ": footprints never overlap")
				occupied[key] = tile.id
		check(int(tile.mass) >= 1 and int(tile.fragments) >= 0, label + ": mass and fragments remain valid")
	check(model.upcoming.size() == Model.UPCOMING_COUNT, label + ": six committed previews remain available")
	for tile in model.upcoming:
		check(not ids.has(tile.id), label + ": queued IDs remain distinct")
		ids[tile.id] = true


func _observe(model) -> Dictionary:
	var events: Dictionary = {"collections": [], "attempts": [], "cues": [], "milestones": [], "completed": []}
	model.collected.connect(func(id: String, word: Dictionary, coins: int, fragments: int) -> void:
		events.collections.append({"id": id, "word": word, "coins": coins, "fragments": fragments}))
	model.word_attempted.connect(func(id: String, words: Array[String], correct: bool) -> void:
		events.attempts.append({"id": id, "words": words, "correct": correct}))
	model.cue_requested.connect(func(cue: String) -> void: events.cues.append(cue))
	model.chest_milestone.connect(func(previous: int, tier: int) -> void: events.milestones.append([previous, tier]))
	model.fusion_completed.connect(func(payload: Dictionary, fragments: int) -> void:
		events.completed.append({"payload": payload, "fragments": fragments}))
	return events


func _test_configuration() -> void:
	var model := Model.new()
	check(not model.configure([], 3, 1), "empty vocabulary is rejected")
	check(model.phase == "finished" and not model.error.is_empty(), "empty vocabulary has a useful failure state")
	var words: Array = [_word("cat"), _word(" CAT ", 3, "duplicate-spelling"), _word("dog", 3, "cat"),
		_word("rocket", 6), {"id": "missing-media", "text": "test", "min_age": 3}]
	check(model.configure(words, 3, 1), "eligible pictured words configure")
	check(model.cells.size() == Model.INITIAL_SETTLED_TILES, "round starts with twelve parts")
	check(model.upcoming.size() == 6 and Model.COLUMNS == 6, "six columns and previews")
	for tile in model.cells:
		check(str(tile.text) in ["ca", "t"], "duplicate IDs, duplicate spelling, other ages, and incomplete media are omitted")
		check(tile.word.is_empty() and not model.collect(int(tile.id)), "an unmerged root cannot be collected")
	_assert_board(model, "initial board")
	check(model.configure([_word("cat")], 0, 1), "Baby uses the first vocabulary age")
	check(model.configure([_word("advanced", 12)], 99, 1), "12+ uses age twelve vocabulary")
	var configured := _word("sunflower")
	configured.jelly_parts = ["sun", "flower"]
	model.configure([configured], 3, 1)
	check(model.cells[0].text == "sun" and model.cells[1].text == "flower", "explicit curated parts override fallback chunks")


func _test_merging_and_collection() -> void:
	var model = _model([_word("cat")])
	var events: Dictionary = _observe(model)
	_board(model, ["ca", "t"], [1, 1])
	check(model.try_merge(1000, 1001) == "merged", "drag source concatenates before target")
	check(model.cells.size() == 2 and model.fusions.size() == 1, "both bodies remain reserved during fusion")
	check(not model.collect(1000) and model.try_merge(1000, 1001) == "ignored", "reserved bodies cannot collect or merge twice")
	model.step(Model.FUSION_SECONDS - 0.01)
	check(model.cells.size() == 2 and events.collections.is_empty(), "fusion has a real duration and earns nothing")
	model.step(0.01)
	check(model.cells.size() == 1 and model.cells[0].text == "cat", "fusion creates one persistent concatenated jelly")
	var result: Dictionary = model.cells[0]
	check(not model.is_settled(result) and bool(result.settling), "the fixed fusion rectangle reserves its final settlement window before new input")
	check(result.word.id == "cat" and result.kind == "word", "exact current vocabulary match reveals its word image")
	check(result.mass == 2 and result.fragments == 2 and result.width > 1, "merged jelly grows and preserves both fragments")
	check(result.skin == 1001, "merged body retains the target jelly skin across the animation boundary")
	check(model.fragment_count == 0 and model.collected_coins == 0 and events.attempts.is_empty(), "fusion alone awards no coins, fragments, or learning attempt")
	check(events.completed.size() == 1 and events.completed[0].fragments == 0, "fusion completion is distinct from collection")
	model.step(Model.SETTLE_SECONDS)
	check(model.collect(int(result.id)), "valid merged jelly can be tapped")
	check(not model.collect(int(result.id)), "repeat taps are reserved")
	model.step(Model.COLLECT_SECONDS)
	check(model.cells.is_empty() and model.cleared_pairs == 1, "collection removes the merged word once")
	check(model.collected_coins == 100 and model.fragment_count == 2, "both parts earn coins and both fragments collect")
	check(events.collections.size() == 1 and events.attempts.size() == 1, "collection emits one payout and one learning attempt")
	check(events.collections[0].coins == 100 and events.collections[0].fragments == 2, "collection payload has exact payout and fragments")
	check(events.cues.count("pop") == 1, "collection has exactly one disappearance cue")
	var result_summary: Dictionary = model.finish_round()
	check(result_summary.coins == 100 and result_summary.words.size() == 1, "round summary includes collected words and coins")


func _test_current_age_validation() -> void:
	var model := Model.new()
	model.configure([_word("cat"), _word("rocket", 6)], 6, 2)
	model.spawn_interval = 10000.0
	_board(model, ["ca", "t", "roc", "ket"])
	var younger: Dictionary = _merge(model, 1000, 1001)
	check(younger.word.is_empty() and not model.collect(int(younger.id)), "a lower-age word does not become collectible")
	var current: Dictionary = _merge(model, 1002, 1003)
	check(current.word.id == "rocket", "current-age word resolves its image")
	model = _model([_word("ice cream")])
	_board(model, ["ice ", "cream"])
	var spaced: Dictionary = _merge(model, 1000, 1001)
	check(spaced.word.id == "ice cream" and spaced.text == "ice cream", "multiword vocabulary preserves its separator")
	model = _model([_word("cat")])
	_board(model, ["t", "ca"])
	var backwards: Dictionary = _merge(model, 1000, 1001)
	check(backwards.text == "tca" and backwards.word.is_empty(), "source-target ordering is meaningful")
	check(not model.collect(int(backwards.id)), "unrecognized merged text remains on the board")


func _test_repeated_merge_and_fragments() -> void:
	var model = _model([_word("cat"), _word("caterpillar")])
	_board(model, ["ca", "t", "er", "pillar"], [1, 1, 1, 1])
	var first: Dictionary = _merge(model, 1000, 1001)
	check(first.word.id == "cat", "first merge already forms a word")
	var second: Dictionary = _merge(model, int(first.id), 1002)
	check(second.text == "cater" and second.word.is_empty(), "valid word can merge further and lose its current match")
	var third: Dictionary = _merge(model, int(second.id), 1003)
	check(third.text == "caterpillar" and third.word.id == "caterpillar", "larger compound can become a valid word again")
	check(third.mass == 4 and third.fragments == 4, "every root and fragment survives repeated merges")
	check(Model.coins_for_tile(third) > Model.coins_for_tile(first), "larger jellies earn more coins")
	model.step(Model.SETTLE_SECONDS)
	model.collect(int(third.id))
	model.step(Model.COLLECT_SECONDS)
	check(model.collected_coins == 200 and model.fragment_count == 4, "larger word collects the entire accumulated reward")
	check(model.chest_tier == 1 and model.chest_count == 1, "four fragments unlock a chest")


func _test_collection_timeline_and_pause() -> void:
	var model = _model([_word("cat")])
	_board(model, ["ca", "t"])
	model.try_merge(1000, 1001)
	model.set_paused(true)
	model.step(1000.0)
	check(model.cells.size() == 2 and float(model.fusions[0].elapsed) == 0.0, "pause freezes fusion and supply clocks")
	model.set_paused(false)
	model.step(Model.FUSION_SECONDS + Model.SETTLE_SECONDS)
	var tile_id: int = int(model.cells[0].id)
	var events: Dictionary = _observe(model)
	model.collect(tile_id)
	model.step(Model.POP_SECONDS - 0.01)
	check(events.cues.is_empty() and model.collected_coins == 0, "collection does not pop or credit early")
	model.step(0.01)
	check(events.cues == ["pop"] and model.collected_coins == 0, "disappearance starts before reward credit")
	model.set_paused(true)
	model.step(10.0)
	check(model.cells.size() == 1 and model.collected_coins == 0, "pause during disappearance preserves the reservation")
	model.set_paused(false)
	model.step(Model.COLLECT_SECONDS - Model.POP_SECONDS)
	check(model.cells.is_empty() and model.collected_coins == 100, "resumed collection credits once")
	var snapshot: Dictionary = model.snapshot()
	model.step(-1.0)
	model.step(NAN)
	model.step(INF)
	check(model.snapshot() == snapshot, "invalid time steps cannot corrupt model state")


func _gravity_tower():
	var model = _model([_word("cat")])
	model.cells.assign([
		_placed_tile(1000, "cat", 1, 7, 2, 4, _word("cat")),
		_placed_tile(1001, "ca", 1, 6, 1, 2),
		_placed_tile(1002, "t", 1, 5, 1, 1),
		_placed_tile(1003, "x", 5, 7)
	])
	model.cells[1].skin = 3
	return model


func _test_collection_gravity() -> void:
	var model = _gravity_tower()
	var events: Dictionary = _observe(model)
	var lower: Dictionary = model.cell(1001)
	var upper: Dictionary = model.cell(1002)
	check(model.collect(1000), "a lower word can be collected beneath a stack")
	model.step(Model.COLLECT_SECONDS - 0.001)
	check(model.cell(1001).row == 6 and model.cell(1002).row == 5 and model.collected_coins == 0,
		"disappearing support stays reserved until its payment commits")
	model.step(0.001)
	check(model.cell(1001).row == 7 and model.cell(1002).row == 6
		and model.cell(1001).column == 1 and model.cell(1002).column == 1,
		"successful collection moves the entire unsupported stack down in its original column")
	for original: Dictionary in [lower, upper]:
		var tile: Dictionary = model.cell(int(original.id))
		check(tile.text == original.text and tile.mass == original.mass and tile.fragments == original.fragments
			and tile.word == original.word, "falling preserves body identity, word content, mass, and carried fragments")
		check(bool(tile.falling) and tile.falling_rows == 1 and tile.age == 0.0 and bool(tile.settling) and not bool(tile.arrival),
			"falling publishes a fresh settlement and exact vertical travel for the view")
	check(model.cell(1001).skin == 3 and _footprint(model.cell(1003)) == Rect2i(5, 7, 1, 1),
		"collection gravity preserves skins and already-supported neighboring bodies")
	check(model.try_merge(1001, 1002) == "ignored" and not model.can_drop_now(), "falling bodies and supply wait until their landing finishes")
	check(model.collected_coins == 100 and model.fragment_count == 4 and model.chest_tier == 1
		and events.collections.size() == 1 and events.attempts.size() == 1 and events.milestones == [[0, 1]],
		"falling leaves the original word's single coin, fragment, learning, and chest payout unchanged")
	model.set_paused(true)
	var before: Dictionary = model.snapshot()
	model.step(20.0)
	check(model.snapshot() == before, "pause freezes an in-progress collection fall")
	model.set_paused(false)
	model.step(Model.SETTLE_SECONDS)
	check(model.is_settled(model.cell(1001)) and model.is_settled(model.cell(1002)) and not model._gravity_pending,
		"landing returns both children to play and clears finished gravity work")
	check(bool(model.cell(1001).falling) and model.cell(1001).falling_rows == 1,
		"landing keeps its last fall provenance so the view cannot emit a second impact cue")
	_assert_supported_tiles(model, [1001, 1002], "collected stack")
	_assert_board(model, "collected stack")


func _test_gravity_partial_support() -> void:
	for mass: int in [3, 7]:
		var model = _model([_word("cat")])
		var body: Dictionary = _placed_tile(1001, "wide", 2 if mass == 3 else 0, 0, mass, 3)
		model.cells.assign([_placed_tile(1000, "cat", 0, 7, 2, 0, _word("cat")), body])
		for row in range(4, Model.ROWS):
			model.cells.append(_placed_tile(2000 + row, "x", 4, row))
		model.collect(1000)
		model.step(Model.COLLECT_SECONDS)
		var landed: Dictionary = model.cell(1001)
		check(landed.row == 4 - int(body.height) and landed.column == body.column
			and landed.width == body.width and landed.height == body.height,
			"wide or tall bodies stop at their first partial support instead of jumping to a lower gap")
		check(landed.falling_rows == landed.row and landed.mass == mass and landed.fragments == 3,
			"multirow falls retain exact travel, wrapped size, mass, and fragments")
		_assert_supported_tiles(model, [1001], "partial support")
		_assert_board(model, "partial support")


func _test_gravity_held_stack() -> void:
	var model = _gravity_tower()
	model.set_held_tile(1001)
	model.collect(1000)
	model.step(Model.COLLECT_SECONDS)
	check(model.cell(1001).row == 6 and model.cell(1002).row == 5 and model._gravity_pending,
		"a held body keeps its anchor and supports the upper stack while gravity is pending")
	model.set_paused(true)
	model.set_held_tile(-1)
	check(model.cell(1001).row == 6 and model.cell(1002).row == 5 and model._gravity_pending,
		"releasing a held body while paused only clears the hold and retains pending motion")
	model.set_paused(false)
	check(model.cell(1001).row == 7 and model.cell(1002).row == 6
		and model.cell(1001).age == 0.0 and model.cell(1002).age == 0.0,
		"resume settles the released support first and the upper stack in the same pass")
	_assert_board(model, "released held stack")
	model = _model([_word("cat")])
	var compressed: Dictionary = _placed_tile(1001, "large", 1, 6, 2)
	compressed.width = 1
	model.cells.assign([_placed_tile(1000, "cat", 0, 7, 2, 0, _word("cat")), compressed])
	model.set_held_tile(1001)
	model.collect(1000)
	model.step(Model.COLLECT_SECONDS)
	check(_footprint(model.cell(1001)) == Rect2i(1, 6, 1, 1), "collection cannot resize or shift a held compressed body during growth restoration")
	model.set_held_tile(-1)
	check(model.cell(1001).width == 2 and model.cell(1001).row == 6 and not model.is_settled(model.cell(1001)),
		"released compressed body first finishes its reserved growth pose")
	model.step(Model.SETTLE_SECONDS)
	check(model.cell(1001).row == 7 and bool(model.cell(1001).falling), "deferred gravity resumes after the released body's growth settles")
	_assert_board(model, "released compressed body")


func _test_gravity_reserved_operations() -> void:
	var model = _model([_word("cat")])
	model.cells.assign([_placed_tile(1000, "cat", 0, 7, 2, 0, _word("cat")),
		_placed_tile(1001, "a", 0, 6), _placed_tile(1002, "b", 1, 6), _placed_tile(1003, "x", 0, 4)])
	check(model.try_merge(1001, 1002) == "merged" and model.collect(1000), "a lower collection can overlap an upper merge")
	var destination: Dictionary = model.fusions[0].result.duplicate(true)
	model.step(Model.COLLECT_SECONDS)
	check(_footprint(model.cell(1001)) == Rect2i(0, 6, 1, 1) and _footprint(model.cell(1002)) == Rect2i(1, 6, 1, 1),
		"pending gravity never moves the live inputs of an active merge")
	check(model.cell(1003).row == 5, "an independent falling body stops above the active merge reservation")
	_assert_reservations(model, "gravity beside active merge")
	model.step(Model.FUSION_SECONDS - Model.COLLECT_SECONDS)
	check(_footprint(model.cell(int(destination.id))) == _footprint(destination), "merge handover still commits its frozen target even with pending gravity")
	model.step(Model.SETTLE_SECONDS - 0.001)
	check(_footprint(model.cell(int(destination.id))) == _footprint(destination), "merged target finishes its landing before collection gravity can move it")
	model.step(0.001)
	check(model.cell(int(destination.id)).row == 7 and model.cell(1003).row == 6
		and bool(model.cell(int(destination.id)).falling), "deferred collection gravity settles the merged body and the stack above it afterward")
	_assert_board(model, "gravity after reserved merge")
	model = _model([_word("cat")])
	model.cells.assign([_placed_tile(1000, "cat", 0, 7, 2, 0, _word("cat")),
		_placed_tile(1001, "a", 0, 6, 1, 1), _placed_tile(1002, "b", 1, 6, 1, 2)])
	var parent: Dictionary = _merge(model, 1001, 1002)
	model.step(Model.SETTLE_SECONDS)
	check(model.split(int(parent.id)) and model.collect(1000), "a collection can begin beneath already reserved split children")
	var children: Array = model.fusions[0].results.duplicate(true)
	model.step(Model.COLLECT_SECONDS)
	check(not model.cell(int(parent.id)).is_empty(), "collection keeps the active split parent in its frozen pose")
	_assert_reservations(model, "gravity beside active split")
	model.step(Model.SPLIT_SECONDS - Model.COLLECT_SECONDS)
	for child: Dictionary in children:
		check(_footprint(model.cell(int(child.id))) == _footprint(child), "split children commit their announced endpoints before deferred falling")
	model.step(Model.SETTLE_SECONDS)
	check(model.cell(1001).row == 7 and model.cell(1002).row == 7
		and model.cell(1001).fragments == 1 and model.cell(1002).fragments == 2,
		"split children settle into the subsequently cleared support gap with their fragments intact")
	_assert_board(model, "gravity after reserved split")


func _test_gravity_simultaneous_collections() -> void:
	var model = _model([_word("cat")])
	model.cells.assign([_placed_tile(1000, "cat", 0, 7, 2, 1, _word("cat")),
		_placed_tile(1001, "cat", 0, 6, 2, 2, _word("cat")), _placed_tile(1002, "x", 0, 5)])
	check(model.collect(1000) and model.collect(1001), "two stacked valid words can collect at one timestamp")
	model.step(Model.COLLECT_SECONDS)
	check(model.cell(1002).row == 7 and model.cell(1002).falling_rows == 2 and model.cell(1002).age == 0.0,
		"simultaneous removals produce one complete fall instead of an unnecessary stop at the first empty row")
	check(model.collected_coins == 200 and model.fragment_count == 3 and model.cleared_pairs == 2,
		"batched stack settlement preserves both independent collection rewards")
	_assert_board(model, "simultaneous collection gravity")


func _test_gravity_settlement_determinism() -> void:
	var states: Array[Dictionary] = []
	for sliced: bool in [false, true]:
		var model = _gravity_tower()
		model.set_held_tile(1001)
		model.collect(1000)
		model.step(Model.COLLECT_SECONDS)
		for tile: Dictionary in model.cells:
			if int(tile.id) == 1001 or int(tile.id) == 1003:
				tile.age = Model.SETTLE_SECONDS - (0.1 if int(tile.id) == 1001 else 0.3)
				tile.settling = true
		model.set_held_tile(-1)
		for index in range(5 if sliced else 1):
			model.step(0.05 if sliced else 0.25)
		check(model.cell(1001).row == 7 and model.cell(1002).row == 6
			and is_equal_approx(float(model.cell(1001).age), 0.15),
			"gravity starts at the first eligible body's boundary while another body is still settling")
		states.append(model.snapshot())
	for index in range(states[0].cells.size()):
		var whole: Dictionary = states[0].cells[index]
		var sliced: Dictionary = states[1].cells[index]
		check(whole.id == sliced.id and _footprint(whole) == _footprint(sliced)
			and is_equal_approx(float(whole.age), float(sliced.age)) and whole.settling == sliced.settling
			and whole.get("falling", false) == sliced.get("falling", false) and whole.falling_rows == sliced.falling_rows,
			"coarse and fine frames agree on fall destinations, clocks, readiness, and motion metadata")
	check(states[0].collected_coins == states[1].collected_coins and states[0].score == states[1].score,
		"gravity time slicing cannot alter collected rewards")


func _test_growth_after_gravity() -> void:
	var model = _model([_word("cat")])
	var compressed: Dictionary = _placed_tile(1001, "chunk", 0, 5, 2, 2)
	compressed.width = 1
	model.cells.assign([_placed_tile(1000, "cat", 1, 7, 2, 0, _word("cat")), compressed,
		_placed_tile(1002, "x", 0, 6), _placed_tile(1003, "x", 0, 7)])
	_fill_rows(model, 0, 5)
	var held_id: int = -1
	for tile: Dictionary in model.cells:
		if tile.column == 1 and tile.row == 4:
			held_id = int(tile.id)
	model.set_held_tile(held_id)
	model.collect(1000)
	model.step(Model.COLLECT_SECONDS)
	check(model.cell(1001).width == 1 and model.cell(1001).row == 5 and model._growth_pending,
		"a growth attempt blocked before gravity is retried after falling vacates a neighboring cell")
	model.step(Model.SETTLE_SECONDS)
	check(_footprint(model.cell(1001)) == Rect2i(0, 5, 2, 1) and model.cell(1001).fragments == 2
		and not model.is_settled(model.cell(1001)), "space released by falling restores a compressed body's full size after landing")
	check(model.cell(held_id).row == 4, "growth retry keeps the held support's logical anchor unchanged")
	model.set_held_tile(-1)
	_assert_board(model, "growth after gravity")


func _test_gravity_wallet_failure() -> void:
	var model = _model([_word("cat")])
	model.cells.assign([_placed_tile(1000, "cat", 0, 7, 2, 1, _word("cat")),
		_placed_tile(1001, "cat", 0, 6, 2, 2, _word("cat")), _placed_tile(1002, "x", 0, 5)])
	var calls: Array = []
	model.credit_collection = func(receipt: String, coins: int) -> Dictionary:
		calls.append([receipt, coins])
		return {"ok": calls.size() != 2}
	model.collect(1000)
	model.collect(1001)
	model.step(Model.COLLECT_SECONDS)
	var retry_id: String = str(model._collection_event_ids[1001])
	check(model.collected_coins == 100 and model.cell(1001).row == 7 and model.cell(1002).row == 6,
		"failed upper payment retains its word and releases its reservation for gravity from the successful lower collection")
	check(not model.collect(1001), "retained failed word waits for its fall to land before a payment retry")
	model.step(Model.SETTLE_SECONDS)
	check(model.collect(1001), "failed word remains collectible after landing")
	model.step(Model.COLLECT_SECONDS)
	check(calls.size() == 3 and calls[2] == [retry_id, 100] and model.collected_coins == 200
		and model.fragment_count == 3 and model.cell(1002).row == 7,
		"falling preserves the failed word's idempotent receipt and retry pays exactly once")
	model.credit_collection = Callable()
	model = _gravity_tower()
	model.credit_collection = func(_receipt: String, _coins: int) -> Dictionary: return {"ok": false}
	model.collect(1000)
	model.step(Model.COLLECT_SECONDS)
	check(model.cell(1001).row == 6 and model.cell(1002).row == 5 and not model._gravity_pending,
		"a failed collection alone neither removes support nor initiates gravity")
	model.credit_collection = Callable()


func _test_gravity_lifecycle() -> void:
	var model = _gravity_tower()
	model.set_held_tile(1001)
	model.collect(1000)
	model.step(Model.COLLECT_SECONDS)
	model.finish_round()
	var before: Dictionary = model.snapshot()
	model.set_held_tile(-1)
	model.step(100.0)
	check(model.snapshot() == before, "ending a round prevents deferred held-stack gravity from mutating the finished board")
	model.configure([_word("cat")], 3, 13)
	check(not model._gravity_pending and model._held_tile_id == -1,
		"configuration clears pending collection gravity and stale held ownership")
	model = _gravity_tower()
	model.collected.connect(func(_id: String, _word_data: Dictionary, _coins: int, _fragments: int) -> void:
		model.configure([_word("cat")], 3, 14), CONNECT_ONE_SHOT)
	model.collect(1000)
	model.step(Model.COLLECT_SECONDS)
	check(model.cells.size() == Model.INITIAL_SETTLED_TILES and model.collected_coins == 0 and not model._gravity_pending,
		"reconfiguration in a reward callback cannot apply old collection gravity to the new round")
	_assert_board(model, "reconfigured gravity lifecycle")


func _test_wallet_retry() -> void:
	var model = _model([_word("cat")])
	_board(model, ["ca", "t"])
	var merged: Dictionary = _merge(model, 1000, 1001)
	model.step(Model.SETTLE_SECONDS)
	var calls: Array = []
	model.credit_collection = func(event_id: String, amount: int) -> Dictionary:
		calls.append({"id": event_id, "amount": amount, "present": not model.cell(int(merged.id)).is_empty()})
		return {"ok": calls.size() > 1}
	model.collect(int(merged.id))
	model.step(Model.COLLECT_SECONDS)
	check(model.cells.size() == 1 and model.collected_coins == 0 and model.fusions.is_empty(), "failed wallet save preserves retryable word and grants nothing")
	check(not model.error.is_empty(), "failed save exposes a recoverable error")
	check(model.collect(int(merged.id)), "failed wallet transaction can retry")
	model.step(Model.COLLECT_SECONDS)
	check(calls.size() == 2 and calls[0].id == calls[1].id, "retry uses the same stable wallet event ID")
	check(calls[0].present and calls[1].present and calls[1].amount == 100, "wallet receives exact amount before irreversible removal")
	check(model.cells.is_empty() and model.collected_coins == 100 and model.error.is_empty(), "successful retry completes exactly once")
	model.credit_collection = Callable()
	model = _model([_word("cat")])
	_board(model, ["ca", "t"])
	merged = _merge(model, 1000, 1001)
	model.step(Model.SETTLE_SECONDS)
	var pause_calls: Array = []
	model.credit_collection = func(event_id: String, amount: int) -> Dictionary:
		pause_calls.append([event_id, amount])
		model.set_paused(true)
		return {"ok": true}
	model.collect(int(merged.id))
	model.step(Model.COLLECT_SECONDS)
	check(model.cells.size() == 1 and model.paused, "pause in wallet callback defers removal safely")
	model.set_paused(false)
	model.step(0.01)
	check(pause_calls.size() == 1 and model.collected_coins == 100, "resuming a credited collection does not pay again")
	model.credit_collection = Callable()
	model = _model([_word("cat")])
	_board(model, ["ca", "t"])
	merged = _merge(model, 1000, 1001)
	model.step(Model.SETTLE_SECONDS)
	model.credit_collection = func(_event_id: String, _amount: int) -> Dictionary:
		model.set_paused(true)
		return {"ok": true}
	model.collect(int(merged.id))
	model.step(Model.COLLECT_SECONDS)
	var finished: Dictionary = model.finish_round()
	check(finished.coins == 100 and finished.words.size() == 1, "exit while a credited collection is paused includes the accepted transaction")
	model.credit_collection = Callable()


func _test_chests() -> void:
	var model = _model([_word("cat")])
	var events: Dictionary = _observe(model)
	for fragments in [4, 5]:
		_board(model, ["ca", "t"], [fragments, 0])
		var merged: Dictionary = _merge(model, 1000, 1001)
		model.step(Model.SETTLE_SECONDS)
		model.collect(int(merged.id))
		model.step(Model.COLLECT_SECONDS)
	check(model.fragment_count == 9 and model.chest_tier == 2 and model.chest_count == 1, "subsequent fragments upgrade the same chest")
	check(events.milestones == [[0, 1], [1, 2]], "unlock and upgrade each emit their visual milestone")
	check(events.collections.size() == 2 and events.collections[1].fragments == 5, "multi-fragment collections report the full stack")


func _test_packing_and_growth() -> void:
	var model = _model()
	var parts: Array[String] = []
	for index in range(12):
		parts.append("a")
	_board(model, parts)
	var current_id: int = 1000
	for index in range(1, 10):
		var merged: Dictionary = _merge(model, current_id, 1000 + index)
		current_id = int(merged.id)
		_assert_board(model, "growing merge %d" % index)
	var large: Dictionary = model.cell(current_id)
	check(int(large.width) == 6 and int(large.height) >= 2 and int(large.mass) == 10, "large jelly occupies multiple rows within the six-column well")
	check(str(large.text).length() == 10, "wrapping never truncates accumulated text")
	check(Model.coins_for_tile(large) == 500, "large jelly value follows accumulated root mass")


func _test_target_placement() -> void:
	var model = _model([_word("cat")])
	model.cells.assign([
		_placed_tile(1000, "ca", 0, 7, 1, 1),
		_placed_tile(1001, "t", 3, 1, 1, 2),
		_placed_tile(1002, "x", 5, 5)
	])
	var neighbor: Rect2i = _footprint(model.cell(1002))
	check(model.try_merge(1000, 1001) == "merged", "a lower source can merge into an upper target")
	var planned: Dictionary = model.fusions[0].result.duplicate(true)
	check(planned.row == 1 and planned.width == 2 and absf(float(planned.column) + 1.0 - 3.5) <= 0.5,
		"the frozen footprint stays beside the upper target instead of returning to the floor")
	var merge_obstacles: Dictionary = model._occupied()
	check(int(planned.row) + int(planned.height) < Model.ROWS and not merge_obstacles.has(2 * Model.COLUMNS + int(planned.column))
		and not merge_obstacles.has(2 * Model.COLUMNS + int(planned.column) + 1),
		"split support rules do not make an unsupported upper merge sink toward the floor")
	model.step(Model.FUSION_SECONDS)
	var merged: Dictionary = model.cell(int(planned.id))
	check(_footprint(merged) == _footprint(planned), "fusion handover commits the exact preannounced destination")
	check(_footprint(model.cell(1002)) == neighbor, "merging does not move an unrelated jelly")
	check(merged.mass == 2 and merged.fragments == 3 and merged.text == "cat", "target placement preserves all merged content and fragments")
	model.step(Model.SETTLE_SECONDS)
	model.cells.append(_placed_tile(1003, "cat", 0, 7, 2, 0, _word("cat")))
	check(model.collect(1003), "a lower word can be collected underneath the upper merge")
	model.step(Model.COLLECT_SECONDS)
	check(model.cell(int(planned.id)).column == planned.column and model.cell(int(planned.id)).row == Model.ROWS - 1
		and model.cell(1002).column == neighbor.position.x and model.cell(1002).row == Model.ROWS - 1,
		"collecting a lower word settles unsupported anchors vertically without changing their columns")
	_assert_board(model, "stable target placement")
	model = _model([_word("cat")])
	model.cells.assign([_placed_tile(1000, "ca", 0, 7, 4, 2), _placed_tile(1001, "t", 5, 1, 1, 3)])
	_fill_rows(model, 0, Model.ROWS - 1)
	check(model.try_merge(1000, 1001) == "merged", "a crowded target accepts a much larger distant source")
	planned = model.fusions[0].result.duplicate(true)
	check(_footprint(planned) == Rect2i(5, 1, 1, 1), "crowded fallback keeps the target footprint instead of the distant larger source")
	model.step(Model.FUSION_SECONDS)
	merged = model.cell(int(planned.id))
	check(_footprint(merged) == _footprint(planned) and merged.mass == 5 and merged.fragments == 5,
		"temporary target-sized compression preserves full mass and every fragment")
	_assert_board(model, "crowded target fallback")


func _test_edge_placement() -> void:
	for target_row: int in [0, 1, Model.ROWS - 1]:
		var model = _model([_word("caterpillar")])
		model.cells.assign([
			_placed_tile(1000, "cater", 0, 6 if target_row == Model.ROWS - 1 else 7, 6, 2),
			_placed_tile(1001, "pillar", 5, target_row, 1, 3)
		])
		check(model.try_merge(1000, 1001) == "merged", "an edge target accepts growth across a wrapped row")
		var planned: Dictionary = model.fusions[0].result.duplicate(true)
		check(planned.column == 0 and planned.width == 6 and planned.height == 2 and planned.row <= target_row,
			"wrapped growth fits six columns without sinking below its target row")
		check(int(planned.row) >= 0 and int(planned.row) + int(planned.height) <= Model.ROWS,
			"top and bottom edge destinations remain inside the well")
		model.step(Model.FUSION_SECONDS)
		check(_footprint(model.cell(int(planned.id))) == _footprint(planned), "edge fusion and final footprint share one placement")
		_assert_board(model, "wrapped edge placement")


func _test_fusion_reservations() -> void:
	for stagger: float in [0.0, 0.1]:
		var model = _model([_word("cat")])
		model.cells.assign([
			_placed_tile(1000, "ca", 0, 7), _placed_tile(1001, "t", 1, 4),
			_placed_tile(1002, "ca", 5, 7), _placed_tile(1003, "t", 3, 4),
			_placed_tile(1004, "x", 0, 4), _placed_tile(1005, "x", 4, 4)
		])
		_fill_rows(model, 5, 7)
		check(model.try_merge(1000, 1001) == "merged", "the first fusion can reserve the shared gap")
		var first: Dictionary = model.fusions[0].result.duplicate(true)
		check(_footprint(first).has_point(Vector2i(2, 4)), "the first planned body occupies the sole neighboring gap")
		if stagger > 0.0:
			model.step(stagger)
		check(model.try_merge(1002, 1003) == "merged", "a disjoint second fusion remains playable")
		var second: Dictionary = model.fusions[1].result.duplicate(true)
		check(not _footprint(first).intersects(_footprint(second)), "the second fusion cannot promise the first fusion's gap")
		_assert_reservations(model, "simultaneous reservations")
		var incoming: Array[Dictionary] = model.upcoming.duplicate(true)
		check(model.drop_now(), "manual supply can arrive while independent bodies merge")
		for tile: Dictionary in incoming:
			var arrived: Dictionary = model.cell(int(tile.id))
			check(not arrived.is_empty() and not _footprint(arrived).intersects(_footprint(first))
				and not _footprint(arrived).intersects(_footprint(second)), "incoming roots skip both reserved future footprints")
		_assert_reservations(model, "reservations after a manual drop")
		model.step(Model.FUSION_SECONDS - stagger)
		check(_footprint(model.cell(int(first.id))) == _footprint(first), "the first completed operation retains its frozen destination")
		if stagger > 0.0:
			check(model.fusions.size() == 1 and _footprint(model.cell(1002)) == Rect2i(5, 7, 1, 1)
				and _footprint(model.cell(1003)) == Rect2i(3, 4, 1, 1), "completing one fusion cannot move the other fusion's live inputs")
			check(_footprint(model.fusions[0].result) == _footprint(second), "the pending animation keeps its reserved destination")
			_assert_reservations(model, "reservation after an earlier completion")
			model.step(stagger)
		check(_footprint(model.cell(int(second.id))) == _footprint(second), "the second completion commits its own collision-free destination")
		_assert_board(model, "completed simultaneous placements")


func _crowded_growth_model():
	var model = _model([_word("cat")])
	model.cells.clear()
	for index in range(4):
		var tile: Dictionary = _tile(1000 + index, "ca" if index == 0 else "t" if index == 1 else "cat",
			4 if index < 2 else 2, 2 if index == 0 else 3 if index == 1 else 1,
			{} if index < 2 else _word("cat"))
		tile.width = int(tile.mass)
		tile.column = 0 if index < 2 else 4
		tile.row = 7 if index in [0, 2] else 6
		model.cells.append(tile)
	for index in range(36):
		model.cells.append(_placed_tile(1004 + index, "a", index % Model.COLUMNS, 5 - int(index / Model.COLUMNS)))
	return model


func _test_deferred_growth() -> void:
	var model = _crowded_growth_model()
	check(not model._has_free_cell(), "explicit legal footprints fill the crowded growth fixture")
	model.step(Model.SETTLE_SECONDS)
	_assert_board(model, "crowded growth fixture")
	var merged: Dictionary = _merge(model, 1000, 1001)
	var merged_id: int = int(merged.id)
	check(merged.mass == 8 and merged.width == 4 and merged.height == 1,
		"a crowded merge preserves a legal smaller footprint when its preferred size cannot fit")
	check(merged.fragments == 5 and merged.text == "cat" and Model.coins_for_tile(merged) == 400,
		"temporary compression preserves word content, all fragments, and full coin value")
	_assert_board(model, "compressed growth")
	model.step(Model.SETTLE_SECONDS)
	check(model.collect(1002), "the first neighboring word can free some room")
	model.step(Model.COLLECT_SECONDS)
	merged = model.cell(merged_id)
	check(merged.width == 4 and merged.height == 1 and merged.fragments == 5,
		"failed preferred repacking keeps the current legal footprint and fragments")
	_assert_board(model, "insufficient growth space")
	model.step(Model.SETTLE_SECONDS)
	check(model.collect(1003), "the second neighboring word frees the remaining growth space")
	model.step(Model.COLLECT_SECONDS)
	merged = model.cell(merged_id)
	check(merged.width == 4 and merged.height == 1 and merged.row == Model.ROWS - 1 and merged.mass == 8,
		"gravity preserves legal compression when settled neighbors occupy the preferred wrapped footprint")
	check(merged.fragments == 5 and merged.text == "cat" and merged.word.id == "cat",
		"restored growth keeps the exact merged word and carried fragments")
	check(model.is_settled(merged) and not bool(merged.settling), "an unmoved compressed body does not restart settlement after another collection")
	_assert_board(model, "gravity-constrained growth")
	var first_layout: Array[Dictionary] = model.cells.duplicate(true)
	model._restore_growth()
	check(model.cells == first_layout, "restoring unchanged footprints is stable and does not restart settlement")
	model.step(Model.SETTLE_SECONDS)
	check(model.collect(merged_id), "the expanded word remains collectible")
	model.step(Model.COLLECT_SECONDS)
	check(model.collected_coins == 600 and model.fragment_count == 7,
		"compression and restored growth preserve the exact final coin and fragment payout")
	model = _model([_word("cat")])
	model.cells.clear()
	var fixed_origin: Dictionary = _tile(1000, "cat", 8, 2, _word("cat"))
	fixed_origin.column = 0
	fixed_origin.row = Model.ROWS - 2
	fixed_origin.width = 4
	model.cells.append(fixed_origin)
	model._restore_growth()
	merged = model.cell(1000)
	check(merged.column == 0 and merged.row == Model.ROWS - 2 and merged.width == 6 and merged.height == 2,
		"same-position growth restores the full preferred footprint")
	check(not model.is_settled(merged) and bool(merged.settling),
		"dimension-only growth prevents collection until its visual settlement completes")


func _test_growth_after_settlement() -> void:
	var final_states: Array[Dictionary] = []
	for sliced: bool in [false, true]:
		var model = _crowded_growth_model()
		check(model.try_merge(1000, 1001) == "merged", "a crowded merge starts before neighboring collections")
		var id: int = int(model.fusions[0].result.id)
		model.step(0.55)
		check(model.collect(1002) and model.collect(1003), "two neighbors can clear while the existing fusion is running")
		var until_collection: float = Model.COLLECT_SECONDS
		if sliced:
			for index in range(42):
				model.step(until_collection / 42.0)
		else:
			model.step(until_collection)
		var merged: Dictionary = model.cell(id)
		check(merged.width == 4 and merged.height == 1 and not model.is_settled(merged),
			"space freed during settlement cannot replace the frozen fusion footprint early")
		check(model._growth_pending and model.cleared_pairs == 2, "deferred growth remembers newly freed room without another player action")
		var settle_remaining: float = Model.SETTLE_SECONDS - float(merged.age)
		model.step(settle_remaining - 0.001)
		check(model.cell(id).width == 4, "compressed body remains unchanged just before its settlement boundary")
		model.step(0.002)
		merged = model.cell(id)
		check(merged.width == 4 and merged.height == 1 and merged.column == 0 and merged.row == 7,
			"settlement completion lets the deferred merged body fall into the newly cleared lower row")
		check(not model.is_settled(merged) and merged.fragments == 5 and Model.coins_for_tile(merged) == 400,
			"deferred falling reserves fresh settlement and preserves the full compressed reward")
		_assert_board(model, "deferred falling after settlement")
		final_states.append({"rect": _footprint(merged), "age": float(merged.age), "coins": model.collected_coins,
			"fragments": model.fragment_count, "mass": int(merged.mass), "text": str(merged.text)})
	check(final_states[0].rect == final_states[1].rect and is_equal_approx(final_states[0].age, final_states[1].age)
		and final_states[0].coins == final_states[1].coins and final_states[0].fragments == final_states[1].fragments
		and final_states[0].mass == final_states[1].mass and final_states[0].text == final_states[1].text,
		"whole and sliced frames agree on deferred falling placement, readiness, words, and rewards")


func _test_splitting() -> void:
	var model = _model([_word("cat")])
	_board(model, ["t", "ca", "x"], [2, 3, 1])
	model.cells[0].skin = 2
	model.cells[1].skin = 5
	var originals: Array = model.cells.duplicate(true)
	check(not model.can_split(originals[0]) and not model.split(1000), "a single root cannot split")
	var parent: Dictionary = _merge(model, 1000, 1001)
	var id: int = int(parent.id)
	check(model.can_split(parent) and not model.split(id), "invalid history is discoverable but waits for its merge to settle")
	model.step(Model.SETTLE_SECONDS)
	model.set_paused(true)
	check(not model.split(id), "a paused round cannot begin a split")
	model.set_paused(false)
	var events: Dictionary = _observe(model)
	var payments: Array = []
	model.credit_collection = func(receipt: String, coins: int) -> Dictionary:
		payments.append([receipt, coins])
		return {"ok": true}
	var next_id: int = model._next_tile_id
	var interval: float = model.spawn_interval
	check(model.split(id), "an invalid merged jelly can undo its last merge")
	var active: Dictionary = model.fusions[0].duplicate(true)
	check(active.operation == "split" and active.a_id == id and active.b_id == id
		and active.a == active.b and active.result.is_empty() and active.word.is_empty(), "split payload reserves one parent and exposes no collectible result")
	check(active.results.size() == 2 and active.results[0].id == 1000 and active.results[1].id == 1001,
		"split destinations keep the exact source-target order and original identities")
	check(not model.split(id) and model.try_merge(id, 1002) == "ignored", "an active split cannot start twice or participate in a merge")
	check(not model.snapshot().cells[0].has("children"), "public tile snapshots do not contain recursive ancestry")
	_assert_reservations(model, "split reservation")
	model.step(Model.SPLIT_SECONDS - 0.01)
	check(not model.cell(id).is_empty() and model.cell(1000).is_empty() and events.completed.is_empty(), "children do not commit before the split animation ends")
	model.set_paused(true)
	var paused: Dictionary = model.snapshot()
	model.step(5.0)
	check(model.snapshot() == paused, "pause freezes the entire split and supply timeline")
	model.set_paused(false)
	model.step(0.01)
	check(model.cell(id).is_empty() and model.cells.size() == 3 and not model._merge_history.has(id), "split replaces only its parent and removes its consumed history entry")
	for index in range(2):
		var child: Dictionary = model.cell(int(originals[index].id))
		for key in ["id", "text", "mass", "parts_count", "fragments", "chest", "word", "kind", "skin"]:
			check(child[key] == originals[index][key], "split preserves each child's " + str(key))
		check(_footprint(child) == _footprint(active.results[index]), "restored body lands at its frozen split endpoint")
		check(not model.is_settled(child) and bool(child.settling), "restored body settles before accepting new input")
	check(_footprint(model.cell(1002)) == _footprint(originals[2]), "splitting never moves an unrelated jelly")
	check(model._next_tile_id == next_id and model.merged_count == 1 and model.spawn_interval == interval,
		"undo does not allocate new tiles or change merge totals or difficulty")
	check(model.cleared_pairs == 0 and model.collected_coins == 0 and model.fragment_count == 0
		and model.chest_count == 0 and model.chest_tier == 0 and payments.is_empty(), "split earns no score, wallet payment, fragments, or chest rewards")
	check(events.completed.size() == 1 and events.completed[0].fragments == 0 and events.cues == ["release"]
		and events.collections.is_empty() and events.attempts.is_empty() and events.milestones.is_empty(), "split emits one silent-reward completion and no collection or disappearance events")
	_assert_board(model, "basic split")
	model.credit_collection = Callable()


func _test_nested_splits() -> void:
	var model = _model([_word("cat")])
	_board(model, ["ca", "t", "er", "x"], [1, 2, 3, 4])
	var word: Dictionary = _merge(model, 1000, 1001)
	var inner: Dictionary = _merge(model, int(word.id), 1002)
	var outer: Dictionary = _merge(model, int(inner.id), 1003)
	model.step(Model.SETTLE_SECONDS)
	check(model.split(int(outer.id)), "nested invalid merge can split once")
	model.step(Model.SPLIT_SECONDS)
	check(model.can_split(model.cell(int(inner.id))) and model.cell(1003).fragments == 4,
		"outer undo restores its invalid child history and separate root fragments")
	check(not model.split(int(inner.id)), "nested undo waits for restored children to settle")
	model.step(Model.SETTLE_SECONDS)
	check(model.split(int(inner.id)), "the restored invalid child can split again")
	model.step(Model.SPLIT_SECONDS)
	var restored: Dictionary = model.cell(int(word.id))
	check(restored.word == word.word and restored.kind == "word" and restored.text == "cat" and restored.fragments == 3,
		"nested undo recovers the valid child's exact word image, text, and fragments")
	check(not model.can_split(restored) and not model.split(int(restored.id)), "a valid restored word stays collectible rather than splittable")
	check(model._merge_history.size() == 1 and model._merge_history.has(int(word.id)), "undo erases only the two consumed parent histories")
	model.step(Model.SETTLE_SECONDS)
	check(model.collect(int(restored.id)), "a restored valid word collects normally")
	model.step(Model.COLLECT_SECONDS)
	check(model.collected_coins == 100 and model.fragment_count == 3 and model.cells.size() == 2,
		"restored word awards only its own mass and fragments")
	check(model._merge_history.is_empty(), "terminal collection prunes the restored word's ancestry")
	_assert_board(model, "nested undo")


func _constrain_split_board(model, parent_id: int, origin: Vector2i, gaps: Array[Vector2i]) -> void:
	var parent: Dictionary = model.cell(parent_id)
	parent.column = origin.x
	parent.row = origin.y
	parent.width = 1
	parent.height = 1
	parent.age = Model.SETTLE_SECONDS
	parent.settling = false
	model.cells.assign([parent])
	for row in range(Model.ROWS):
		for column in range(Model.COLUMNS):
			var position := Vector2i(column, row)
			if position != origin and not position in gaps:
				model.cells.append(_placed_tile(3000 + row * Model.COLUMNS + column, "x", column, row))


func _test_split_placement() -> void:
	var model = _model()
	_board(model, ["a", "b", "c"])
	var sibling: Dictionary = _merge(model, 1001, 1002)
	var parent: Dictionary = _merge(model, 1000, int(sibling.id))
	_constrain_split_board(model, int(parent.id), Vector2i(2, 3), [Vector2i(3, 3), Vector2i(0, 3)])
	check(model.split(int(parent.id)), "joint search finds a full-size pair in a corridor plus singleton")
	var planned: Array = model.fusions[0].results.duplicate(true)
	check(_footprint(planned[0]) == Rect2i(0, 3, 1, 1) and _footprint(planned[1]) == Rect2i(2, 3, 2, 1),
		"small child yields the nearby corridor to its larger sibling instead of forcing unnecessary compression")
	var neighbors: Array = model.cells.slice(1).duplicate(true)
	_assert_reservations(model, "joint split placement")
	model.step(Model.SPLIT_SECONDS)
	for neighbor: Dictionary in neighbors:
		check(_footprint(model.cell(int(neighbor.id))) == _footprint(neighbor), "crowded split does not repack any unrelated neighbor")
	_assert_board(model, "joint split completion")
	model = _model()
	var a: Dictionary = _placed_tile(1000, "a", 0, 7, 4, 2)
	var b: Dictionary = _placed_tile(1001, "b", 5, 7, 3, 3)
	a.width = 2
	b.width = 1
	model.cells.assign([a, b])
	parent = _merge(model, 1000, 1001)
	_constrain_split_board(model, int(parent.id), Vector2i(2, 3), [Vector2i(3, 3), Vector2i(5, 3)])
	check(model.split(int(parent.id)), "prior saved footprints remain available when preferred sizes cannot fit")
	planned = model.fusions[0].results.duplicate(true)
	check(planned[0].width == 2 and planned[1].width == 1 and planned[0].mass == 4 and planned[1].mass == 3,
		"saved-footprint fallback retains full child mass instead of unnecessarily compressing both to one cell")
	model.step(Model.SPLIT_SECONDS)
	_assert_board(model, "saved split footprints")
	model = _model()
	model.cells.assign([_placed_tile(1000, "a", 0, 7, 2, 2), _placed_tile(1001, "b", 2, 7, 3, 3)])
	parent = _merge(model, 1000, 1001)
	_constrain_split_board(model, int(parent.id), Vector2i(0, 0), [Vector2i(5, 7)])
	check(model.split(int(parent.id)), "split searches below a top-row parent when only a distant cell is free")
	planned = model.fusions[0].results.duplicate(true)
	check(planned[0].width == 1 and planned[1].width == 1 and planned[0].height == 1 and planned[1].height == 1,
		"two isolated cells allow the final one-cell compression fallback")
	check(planned[0].mass == 2 and planned[1].mass == 3 and planned[0].fragments == 2 and planned[1].fragments == 3,
		"extreme compression keeps each child's separate mass and fragments")
	model.step(Model.SPLIT_SECONDS)
	_assert_board(model, "isolated split footprints")
	model = _model()
	_board(model, ["a", "b"])
	parent = _merge(model, 1000, 1001)
	_constrain_split_board(model, int(parent.id), Vector2i(0, 0), [])
	var before: Dictionary = model.snapshot()
	var history: Dictionary = model._merge_history.duplicate(true)
	var receipts: Dictionary = model._collection_event_ids.duplicate(true)
	var next_event: int = model._next_event_id
	var next_tile: int = model._next_tile_id
	check(model.can_split(model.cell(int(parent.id))) and not model.split(int(parent.id)), "a crowded semantic split refuses when two child cells cannot fit")
	check(model.snapshot() == before and model._merge_history == history and model._collection_event_ids == receipts
		and model._next_event_id == next_event and model._next_tile_id == next_tile, "rejected split is atomic across board, clocks, rewards, ancestry, receipts, and ID allocation")
	_assert_board(model, "rejected split")


func _test_split_supported_destinations() -> void:
	var model = _model()
	_board(model, ["na", "ba"], [1, 2])
	var parent: Dictionary = _merge(model, 1000, 1001)
	parent.column = 1
	parent.row = 5
	parent.age = Model.SETTLE_SECONDS
	parent.settling = false
	model.cells.assign([parent, _placed_tile(2000, "x", 1, 6),
		_placed_tile(2001, "x", 1, 7), _placed_tile(2002, "x", 2, 7)])
	var neighbors: Array = model.cells.slice(1).duplicate(true)
	check(model.split(int(parent.id)), "a parent above a lower gap can split into two supported destinations")
	var children: Array = model.fusions[0].results.duplicate(true)
	check(_footprint(children[0]) == Rect2i(1, 5, 1, 1) and _footprint(children[1]) == Rect2i(2, 6, 1, 1),
		"supported child stays near the parent while ba descends into the empty cell below its half")
	check(children[0].text == "na" and children[1].text == "ba" and children[0].fragments == 1 and children[1].fragments == 2,
		"lower destinations preserve both child identities and separate fragments")
	_assert_reservations(model, "split above lower gap")
	model.step(Model.SPLIT_SECONDS)
	for child: Dictionary in children:
		check(_footprint(model.cell(int(child.id))) == _footprint(child), "gap-filling child lands at the frozen animation destination")
	for neighbor: Dictionary in neighbors:
		check(_footprint(model.cell(int(neighbor.id))) == _footprint(neighbor), "filling the split gap leaves every unrelated jelly fixed")
	model.step(Model.SETTLE_SECONDS)
	check(_footprint(model.cell(1001)) == Rect2i(2, 6, 1, 1), "ba stays supported after the split settlement finishes")
	_assert_supported_tiles(model, [1000, 1001], "split above lower gap")
	_assert_board(model, "supported split above lower gap")


func _test_split_vertical_landing_tie() -> void:
	var model = _model()
	_board(model, ["na", "ba"])
	var parent: Dictionary = _merge(model, 1000, 1001)
	parent.column = 1
	parent.row = 5
	parent.age = Model.SETTLE_SECONDS
	parent.settling = false
	model.cells.assign([parent, _placed_tile(2000, "x", 1, 6), _placed_tile(2001, "x", 1, 7),
		_placed_tile(2002, "x", 2, 7), _placed_tile(2003, "x", 3, 6), _placed_tile(2004, "x", 3, 7)])
	check(model.split(int(parent.id)), "a split can choose between equally near lower and side support")
	var children: Array = model.fusions[0].results.duplicate(true)
	check(_footprint(children[0]) == Rect2i(1, 5, 1, 1) and _footprint(children[1]) == Rect2i(2, 6, 1, 1),
		"ba descends into its own column instead of sidestepping onto equally near support to the right")
	_assert_reservations(model, "vertical landing tie")
	model.step(Model.SPLIT_SECONDS + Model.SETTLE_SECONDS)
	check(_footprint(model.cell(1001)) == Rect2i(2, 6, 1, 1), "vertical tie-break remains the frozen landing after animation and settlement")
	_assert_supported_tiles(model, [1000, 1001], "vertical landing tie")
	_assert_board(model, "vertical landing tie")


func _test_split_sibling_support() -> void:
	var model = _model()
	_board(model, ["na", "ba"])
	var parent: Dictionary = _merge(model, 1000, 1001)
	_constrain_split_board(model, int(parent.id), Vector2i(2, 2),
		[Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 3), Vector2i(2, 4), Vector2i(2, 5), Vector2i(2, 6), Vector2i(2, 7)])
	check(model.split(int(parent.id)), "two split children can settle together in a single-column opening")
	var children: Array = model.fusions[0].results.duplicate(true)
	check(children[0].column == 2 and children[1].column == 2
		and mini(int(children[0].row), int(children[1].row)) == 6 and maxi(int(children[0].row), int(children[1].row)) == 7,
		"lower child rests on the floor and supports its sibling instead of both floating in the opening")
	check(children[0].id == 1000 and children[1].id == 1001,
		"vertical sibling support does not reorder the saved children")
	_assert_reservations(model, "stacked sibling destinations")
	var incoming: Array = model.upcoming.duplicate(true)
	check(model.drop_now(), "supply can use space above a reserved supported sibling stack")
	for preview: Dictionary in incoming:
		var arrived: Dictionary = model.cell(int(preview.id))
		if arrived.is_empty():
			continue
		for child: Dictionary in children:
			check(not _footprint(arrived).intersects(_footprint(child)), "supply cannot take either supported sibling destination")
	_assert_reservations(model, "supported sibling reservations after supply")
	model.step(Model.SPLIT_SECONDS)
	for child: Dictionary in children:
		check(_footprint(model.cell(int(child.id))) == _footprint(child), "concurrent supply does not change either frozen supported endpoint")
	_assert_supported_tiles(model, [1000, 1001], "supported sibling stack")
	_assert_board(model, "supported siblings after supply")


func _assert_supported_tiles(model, tile_ids: Array[int], label: String) -> void:
	for id: int in tile_ids:
		var tile: Dictionary = model.cell(id)
		var bottom: int = int(tile.row) + int(tile.height)
		var supported: bool = bottom == Model.ROWS
		var support_strip := Rect2i(int(tile.column), bottom, int(tile.width), 1)
		for other: Dictionary in model.cells:
			if int(other.id) != id and support_strip.intersects(_footprint(other)):
				supported = true
		check(supported, label + ": each restored child has actual floor or jelly support below its bottom edge")


func _test_split_concurrent_support() -> void:
	var model = _model()
	_board(model, ["na", "ba", "te", "ra"])
	var lower: Dictionary = _merge(model, 1000, 1001)
	var upper: Dictionary = _merge(model, 1002, 1003)
	for parent: Dictionary in [lower, upper]:
		parent.column = 1
		parent.row = 5 if int(parent.id) == int(lower.id) else 4
		parent.age = Model.SETTLE_SECONDS
		parent.settling = false
	model.cells.assign([lower, upper, _placed_tile(2000, "x", 1, 6),
		_placed_tile(2001, "x", 1, 7), _placed_tile(2002, "x", 2, 7)])
	check(model.split(int(lower.id)) and model.split(int(upper.id)), "stacked parents can split concurrently with committed support reservations")
	var lower_children: Array = model.fusions[0].results.duplicate(true)
	var upper_children: Array = model.fusions[1].results.duplicate(true)
	check(_footprint(lower_children[0]) == Rect2i(1, 5, 1, 1) and _footprint(lower_children[1]) == Rect2i(2, 6, 1, 1),
		"lower split reserves the supported gap-filling pair")
	check(upper_children[0].column == 1 and upper_children[1].column == 1
		and mini(int(upper_children[0].row), int(upper_children[1].row)) == 3
		and maxi(int(upper_children[0].row), int(upper_children[1].row)) == 4,
		"upper split uses future child support instead of the lower parent's disappearing right half")
	_assert_reservations(model, "concurrent supported split reservations")
	model.step(Model.SPLIT_SECONDS)
	for children: Array in [lower_children, upper_children]:
		for child: Dictionary in children:
			check(_footprint(model.cell(int(child.id))) == _footprint(child), "concurrent supported split retains every frozen endpoint at handover")
	_assert_supported_tiles(model, [1000, 1001, 1002, 1003], "concurrent split completion")
	_assert_board(model, "concurrent supported split completion")
	model.step(Model.SETTLE_SECONDS)
	_assert_supported_tiles(model, [1000, 1001, 1002, 1003], "concurrent split settlement")


func _test_split_reservations() -> void:
	var model = _model()
	_board(model, ["a", "b", "c", "d", "e", "f"])
	var a: Dictionary = _merge(model, 1000, 1001)
	var b: Dictionary = _merge(model, 1002, 1003)
	model.step(Model.SETTLE_SECONDS)
	check(model.split(int(a.id)) and model.split(int(b.id)), "disjoint parents can split concurrently")
	var destinations: Array = model.fusions[0].results.duplicate(true)
	destinations.append_array(model.fusions[1].results.duplicate(true))
	check(model.try_merge(1004, 1005) == "merged", "another pair can merge during two splits")
	_assert_reservations(model, "split and merge reservations")
	var incoming: Array = model.upcoming.duplicate(true)
	check(model.drop_now(), "new roots can enter unreserved space during a split")
	for preview: Dictionary in incoming:
		var arrived: Dictionary = model.cell(int(preview.id))
		for child: Dictionary in destinations:
			check(not _footprint(arrived).intersects(_footprint(child)), "incoming root cannot claim a reserved split destination")
	_assert_reservations(model, "split reservations after a drop")
	model.step(Model.SPLIT_SECONDS)
	check(model.fusions.size() == 1 and model.fusions[0].operation == "merge", "both splits can finish while an independent merge remains reserved")
	for child: Dictionary in destinations:
		check(_footprint(model.cell(int(child.id))) == _footprint(child), "concurrent split completion uses its own frozen destination")
	_assert_reservations(model, "remaining merge after split completion")
	model.step(Model.FUSION_SECONDS - Model.SPLIT_SECONDS)
	_assert_board(model, "concurrent split merge and drop")


func _test_growth_after_split() -> void:
	var model = _model()
	model.cells.assign([_placed_tile(1000, "a", 0, 2, 4), _placed_tile(1001, "b", 0, 3, 4)])
	var parent: Dictionary = _merge(model, 1000, 1001)
	parent.column = 0
	parent.row = 2
	parent.age = Model.SETTLE_SECONDS
	parent.settling = false
	model.cells.assign([parent])
	_fill_rows(model, 0, Model.ROWS - 1)
	var neighbor_id: int = -1
	for tile: Dictionary in model.cells:
		if tile.column == 5 and tile.row == 4:
			tile.mass = 2
			tile.parts_count = 2
			neighbor_id = int(tile.id)
	check(neighbor_id >= 0 and not model._has_free_cell(), "wrapped split growth fixture begins fully occupied")
	var original_neighbor: Rect2i = _footprint(model.cell(neighbor_id))
	check(model.split(int(parent.id)), "wrapped parent can restore two full-size four-part bodies")
	var children: Array = model.fusions[0].results.duplicate(true)
	model.step(Model.SPLIT_SECONDS)
	check(model._occupied().size() < Model.CAPACITY and model._growth_pending and _footprint(model.cell(neighbor_id)) == original_neighbor,
		"split releases wrapped padding and schedules growth without moving neighbors at handover")
	for child: Dictionary in children:
		check(_footprint(model.cell(int(child.id))) == _footprint(child), "wrapped split commits each frozen child endpoint")
	model.step(Model.SETTLE_SECONDS - 0.001)
	check(_footprint(model.cell(neighbor_id)) == original_neighbor, "compressed neighbor waits for both split children to finish settling")
	model.step(0.001)
	var grown: Dictionary = model.cell(neighbor_id)
	check(grown.width == 2 and grown.height == 1 and not model.is_settled(grown),
		"freed wrapped padding restores the compressed neighbor after split settlement")
	for child: Dictionary in children:
		check(_footprint(model.cell(int(child.id))) == _footprint(child), "deferred growth never displaces either restored child")
	_assert_board(model, "growth after wrapped split settlement")


func _test_split_determinism() -> void:
	var outcomes: Array[Dictionary] = []
	for sliced: bool in [false, true]:
		var model = _model()
		_board(model, ["a", "b", "c", "d"])
		var a: Dictionary = _merge(model, 1000, 1001)
		var b: Dictionary = _merge(model, 1002, 1003)
		model.step(Model.SETTLE_SECONDS)
		model.split(int(a.id))
		model.split(int(b.id))
		var duration: float = Model.SPLIT_SECONDS + Model.SETTLE_SECONDS
		for index in range(81 if sliced else 1):
			model.step(duration / (81.0 if sliced else 1.0))
		outcomes.append(model.snapshot())
	check(outcomes[0].fusions.is_empty() and outcomes[1].fusions.is_empty(), "whole and sliced frames complete simultaneous splits")
	for index in range(outcomes[0].cells.size()):
		var a: Dictionary = outcomes[0].cells[index]
		var b: Dictionary = outcomes[1].cells[index]
		check(a.id == b.id and a.text == b.text and a.mass == b.mass and a.fragments == b.fragments
			and _footprint(a) == _footprint(b) and is_equal_approx(float(a.age), float(b.age)) and a.settling == b.settling,
			"time slicing preserves split identity, placement, content, fragments, and readiness")


func _test_split_wallet_history() -> void:
	var model = _model([_word("cat"), _word("dog")])
	_board(model, ["ca", "t", "er", "do", "g"])
	var cat: Dictionary = _merge(model, 1000, 1001)
	var dog: Dictionary = _merge(model, 1003, 1004)
	model.step(Model.SETTLE_SECONDS)
	var calls: Array = []
	var payment: Dictionary = {"ok": false}
	model.credit_collection = func(receipt: String, coins: int) -> Dictionary:
		calls.append([receipt, coins])
		return payment.duplicate()
	model.collect(int(cat.id))
	model.collect(int(dog.id))
	model.step(Model.COLLECT_SECONDS)
	var cat_receipt: String = str(model._collection_event_ids[int(cat.id)])
	var dog_receipt: String = str(model._collection_event_ids[int(dog.id)])
	var parent: Dictionary = _merge(model, int(cat.id), 1002)
	model.step(Model.SETTLE_SECONDS)
	check(model.split(int(parent.id)), "failed collection can merge and then undo without losing its child")
	model.step(Model.SPLIT_SECONDS + Model.SETTLE_SECONDS)
	check(str(model._collection_event_ids[int(cat.id)]) == cat_receipt, "merge and split preserve the failed child's stable wallet receipt")
	payment.ok = true
	check(model.collect(int(cat.id)), "restored child can retry its failed reward")
	model.step(Model.COLLECT_SECONDS)
	check(calls.size() == 3 and calls[2] == [cat_receipt, 100] and model.collected_coins == 100,
		"restored retry uses the original idempotent payment key and credits once")
	check(not model._collection_event_ids.has(int(cat.id)) and str(model._collection_event_ids[int(dog.id)]) == dog_receipt
		and model._merge_history.has(int(dog.id)), "collecting one restored tree retains the unrelated failed word and receipt")
	model.credit_collection = Callable()
	model = _model([_word("cat"), _word("caterpillar")])
	_board(model, ["ca", "t", "er", "pillar"])
	cat = _merge(model, 1000, 1001)
	model.step(Model.SETTLE_SECONDS)
	model.credit_collection = func(_receipt: String, _coins: int) -> Dictionary: return {"ok": false}
	model.collect(int(cat.id))
	model.step(Model.COLLECT_SECONDS)
	parent = _merge(model, int(cat.id), 1002)
	var final_word: Dictionary = _merge(model, int(parent.id), 1003)
	check(model._merge_history.size() == 3 and model._collection_event_ids.has(int(cat.id)), "merged tree retains nested histories and prior failed receipts until terminal collection")
	model.credit_collection = Callable()
	model.step(Model.SETTLE_SECONDS)
	model.collect(int(final_word.id))
	model.step(Model.COLLECT_SECONDS)
	check(model._merge_history.is_empty() and model._collection_event_ids.is_empty() and model.collected_coins == 200,
		"terminal collection prunes the entire consumed ancestry and descendant receipts without paying old children")


func _test_split_lifecycle() -> void:
	for replace_round: bool in [false, true]:
		var model = _model()
		_board(model, ["a", "b"])
		var parent: Dictionary = _merge(model, 1000, 1001)
		model.step(Model.SETTLE_SECONDS)
		var events: Dictionary = _observe(model)
		model.fusion_started.connect(func(_payload: Dictionary) -> void:
			if replace_round:
				model.configure([_word("cat")], 3, 13)
			else:
				model.finish_round(), CONNECT_ONE_SHOT)
		check(model.split(int(parent.id)), "split start is acknowledged before lifecycle callback interrupts it")
		check(model.fusions.is_empty() and events.cues.is_empty() and events.completed.is_empty(), "ending or replacing a round during split start suppresses stale animation and cues")
		if replace_round:
			check(model._merge_history.is_empty() and model._collection_event_ids.is_empty()
				and model.cells.size() == Model.INITIAL_SETTLED_TILES, "configure clears every split history and receipt before creating the new round")
		else:
			model.step(100.0)
			check(not model.cell(int(parent.id)).is_empty() and model.cell(1000).is_empty()
				and model.finish_round().coins == 0, "cancelled split leaves its original parent intact and grants nothing")
	var model = _model()
	_board(model, ["a", "b"])
	var parent: Dictionary = _merge(model, 1000, 1001)
	model.step(Model.SETTLE_SECONDS)
	model.fusion_completed.connect(func(_payload: Dictionary, awarded: int) -> void:
		check(not model.cell(1000).is_empty() and not model.cell(1001).is_empty()
			and model.cell(int(parent.id)).is_empty() and awarded == 0, "completion callbacks see both children atomically restored")
		model.finish_round(), CONNECT_ONE_SHOT)
	model.split(int(parent.id))
	model.step(Model.SPLIT_SECONDS)
	check(model.phase == "finished" and model.finish_round().coins == 0 and model.fusions.is_empty(), "ending inside split completion retains both children and no stale reward")


func _test_split_danger() -> void:
	var model = _model()
	var pieces: Array[String] = []
	for index in range(Model.CAPACITY):
		pieces.append("a")
	_board(model, pieces)
	var parent: Dictionary = _merge(model, 1000, 1001)
	model.step(Model.SETTLE_SECONDS + 2.0)
	var elapsed: float = model.full_elapsed
	check(elapsed >= 2.0 and model.split(int(parent.id)), "full board permits undo while its existing danger deadline is running")
	model.step(Model.SPLIT_SECONDS)
	check(is_equal_approx(model.full_elapsed, elapsed + Model.SPLIT_SECONDS), "split cannot restart a full-board deadline when it frees no occupied cell")
	model.step(Model.SETTLE_SECONDS)
	elapsed = model.full_elapsed
	check(model.try_merge(1000, 1001) == "merged", "restored roots can merge again while danger remains active")
	model.step(Model.FUSION_SECONDS)
	check(is_equal_approx(model.full_elapsed, elapsed + Model.FUSION_SECONDS), "merge after undo also preserves a full-board deadline without occupancy relief")
	model.step(Model.FULL_SECONDS - model.full_elapsed)
	check(model.phase == "finished", "repeated merge and undo cannot postpone a full board's expiry")


func _test_full_board() -> void:
	var model = _model([_word("cat")])
	var parts: Array[String] = []
	for index in range(Model.CAPACITY):
		parts.append("a")
	_board(model, parts)
	check(not model.can_drop_now(), "full board blocks manual supply")
	var merged: Dictionary = _merge(model, 1000, 1001)
	check(merged.mass == 2, "even a full board allows a merge")
	_assert_board(model, "full board merge")
	model.step(Model.SETTLE_SECONDS + 0.01)
	check(model.full_elapsed >= 0.0, "danger begins only after settled occupancy fills the well")
	model.set_paused(true)
	var elapsed: float = model.full_elapsed
	model.step(Model.FULL_SECONDS)
	check(model.full_elapsed == elapsed and model.phase == "playing", "pause freezes full-board danger")
	model.set_paused(false)
	model.step(Model.FULL_SECONDS)
	check(model.phase == "finished", "unrelieved full board ends the round")


func _test_independent_operations() -> void:
	var model = _model([_word("cat")])
	_board(model, ["ca", "t", "ca", "t"], [1, 1, 1, 1])
	check(model.try_merge(1000, 1001) == "merged" and model.try_merge(1002, 1003) == "merged", "disjoint pairs can fuse concurrently")
	check(model.try_merge(1000, 1002) == "ignored", "concurrent fusions reserve their source IDs")
	model.step(Model.FUSION_SECONDS + Model.SETTLE_SECONDS)
	check(model.cells.size() == 2 and model.cells[0].text == "cat" and model.cells[1].text == "cat", "concurrent pairs become two distinct persistent words")
	var events: Dictionary = _observe(model)
	check(model.collect(int(model.cells[0].id)) and model.collect(int(model.cells[1].id)), "disjoint valid words can collect concurrently")
	model.step(Model.COLLECT_SECONDS)
	check(model.cells.is_empty() and model.collected_coins == 200 and model.fragment_count == 4, "concurrent collections conserve all coins and fragments")
	check(events.milestones == [[0, 1]] and events.collections.size() == 2, "simultaneous rewards unlock a chest exactly once")


func _test_lifecycle_reentry() -> void:
	var model = _model([_word("cat")])
	_board(model, ["ca", "t"])
	var events: Dictionary = _observe(model)
	model.fusion_started.connect(func(_payload: Dictionary) -> void: model.finish_round(), CONNECT_ONE_SHOT)
	model.try_merge(1000, 1001)
	check(model.phase == "finished" and model.fusions.is_empty() and events.cues.is_empty(), "ending during merge start suppresses stale cue and work")
	check(model.finish_round().coins == 0, "interrupted merge grants no reward")
	model = _model([_word("cat")])
	_board(model, ["ca", "t"])
	var merged: Dictionary = _merge(model, 1000, 1001)
	model.step(Model.SETTLE_SECONDS)
	model.collect(int(merged.id))
	model.step(Model.POP_SECONDS)
	var interrupted: Dictionary = model.finish_round()
	model.step(100.0)
	check(interrupted.coins == 0 and model.collected_coins == 0 and model.cells.size() == 1, "ending before collection credit grants nothing")
	model = _model([_word("cat")])
	_board(model, ["ca", "t"])
	merged = _merge(model, 1000, 1001)
	model.step(Model.SETTLE_SECONDS)
	model.credit_collection = func(_id: String, _amount: int) -> Dictionary:
		model.configure([_word("sunflower")], 3, 11)
		return {"ok": true}
	model.collect(int(merged.id))
	model.step(Model.COLLECT_SECONDS)
	check(model.cells.size() == Model.INITIAL_SETTLED_TILES and model.collected_coins == 0 and model.fusions.is_empty(), "wallet callback cannot mutate a replaced round")
	model.credit_collection = Callable()
	model = _model([_word("cat")])
	_board(model, ["ca", "t"])
	merged = _merge(model, 1000, 1001)
	model.step(Model.SETTLE_SECONDS)
	model.collected.connect(func(_id: String, _word: Dictionary, _coins: int, _fragments: int) -> void: model.finish_round(), CONNECT_ONE_SHOT)
	model.collect(int(merged.id))
	model.step(Model.COLLECT_SECONDS)
	check(model.phase == "finished" and model.finish_round().coins == 100 and model.finish_round().words.size() == 1, "ending inside reward callback sees an atomically committed result")


func _test_supply_and_determinism() -> void:
	var a := Model.new()
	var b := Model.new()
	var words: Array = [_word("cat"), _word("sunflower"), _word("caterpillar")]
	a.configure(words, 3, 73)
	b.configure(words, 3, 73)
	check(a.snapshot() == b.snapshot(), "seeded configuration is deterministic")
	var preview: Array = a.upcoming.duplicate(true)
	check(not a.drop_now(-999), "stale supply identity cannot trigger a batch")
	check(a.drop_now(int(preview[0].id)), "committed preview can release manually")
	for tile in preview:
		check(not a.cell(int(tile.id)).is_empty(), "manual batch releases precisely the advertised roots")
	check(not a.can_drop_now(), "supply waits for prior batch to settle")
	a.step(Model.SETTLE_SECONDS)
	_assert_board(a, "manual drop")
	var whole := Model.new()
	var sliced := Model.new()
	whole.configure(words, 3, 73)
	sliced.configure(words, 3, 73)
	var duration: float = Model.INITIAL_SPAWN_INTERVAL * 2.0
	whole.step(duration)
	for index in range(roundi(duration * 10.0)):
		sliced.step(0.1)
	check(whole.generated_tiles == sliced.generated_tiles and whole.cells.size() == sliced.cells.size(), "large and small time steps dispatch the same supply")
	for index in range(whole.cells.size()):
		check(whole.cells[index].id == sliced.cells[index].id and whole.cells[index].text == sliced.cells[index].text,
			"time slicing preserves tile identity and text")
	_assert_board(whole, "automatic supply")


func _arrival_ids(model) -> Array[int]:
	var ids: Array[int] = []
	for tile: Dictionary in model.upcoming:
		ids.append(int(tile.id))
	return ids


func _test_arrival_timing() -> void:
	var initial = _model([_word("cat")])
	check(initial.cells.size() == Model.INITIAL_SETTLED_TILES, "natural arrival keeps the twelve-root opening")
	for tile: Dictionary in initial.cells:
		check(initial.is_settled(tile) and not bool(tile.arrival) and is_equal_approx(Model.settle_duration(tile), Model.SETTLE_SECONDS),
			"opening roots remain settled with the ordinary recovery clock")
	for row in range(Model.ROWS):
		var model = _model([_word("cat")])
		model.cells.clear()
		_fill_rows(model, row + 1, Model.ROWS - 1)
		var incoming: Array[int] = _arrival_ids(model)
		check(model.drop_now(incoming[0]), "each supported row accepts a manual arrival batch")
		var previous_contact: float = -1.0
		for index in range(incoming.size()):
			var tile: Dictionary = model.cell(incoming[index])
			var stagger: float = float(index) * Model.ARRIVAL_STAGGER
			var expected_contact: float = stagger + sqrt(2.0 * float(row + 1) / Motion.ARRIVAL_GRAVITY)
			check(tile.row == row and tile.column == index and tile.falling_rows == row + 1,
				"arrival distance spans the whole well from one row above the board")
			check(tile.arrival_index == index and bool(tile.arrival) and bool(tile.settling) and tile.age == 0.0,
				"batch roots retain their ordered delay and start on the shared model clock")
			check(is_equal_approx(Model.arrival_contact_at(tile), expected_contact),
				"arrival contact follows board-scaled acceleration and batch stagger")
			check(is_equal_approx(Model.settle_duration(tile), expected_contact + Motion.COMPRESSION_SECONDS + Motion.REBOUND_SECONDS + Motion.RECOVERY_SECONDS),
				"arrival input readiness includes planted compression and complete recovery")
			check(Model.arrival_contact_at(tile) > previous_contact, "equal-height roots contact in a gentle stagger")
			previous_contact = Model.arrival_contact_at(tile)
		_assert_board(model, "arrival row %d" % row)


func _test_arrival_readiness_and_pause() -> void:
	var model = _model([_word("cat")])
	var incoming: Array[int] = _arrival_ids(model)
	var target_id: int = int(model.cells[0].id)
	check(model.drop_now(incoming[0]), "arrival readiness fixture releases its committed preview")
	var first_contact: float = Model.arrival_contact_at(model.cell(incoming[0]))
	var first_ready: float = Model.settle_duration(model.cell(incoming[0]))
	var last_ready: float = Model.settle_duration(model.cell(incoming.back()))
	model.step(first_contact)
	check(not model.is_settled(model.cell(incoming[0])) and bool(model.cell(incoming[0]).settling),
		"touching support does not enable a jelly while it is still compressing")
	check(model.try_merge(incoming[0], target_id) == "ignored" and model.try_merge(target_id, incoming[0]) == "ignored",
		"a falling or recovering root cannot be used as a merge source or target")
	check(not model.can_drop_now() and not model.drop_now(), "a new batch cannot overlap the current arrival recovery")
	var frozen: Dictionary = model.snapshot()
	model.set_paused(true)
	model.step(5.0)
	check(model.cells == frozen.cells and model.upcoming == frozen.upcoming and model.spawn_elapsed == frozen.spawn_elapsed,
		"pause freezes arrival positions, stagger ages, and the next supply clock")
	model.set_paused(false)
	model.step(first_ready - first_contact - 0.001)
	check(not model.is_settled(model.cell(incoming[0])) and not model.can_drop_now(), "input remains blocked until the final recovery millisecond")
	model.step(0.001)
	check(model.is_settled(model.cell(incoming[0])) and not bool(model.cell(incoming[0]).settling), "first root becomes ready at its own exact recovery boundary")
	check(not model.is_settled(model.cell(incoming.back())) and not model.can_drop_now(), "the last staggered root retains its later readiness deadline")
	model.step(last_ready - first_ready)
	check(model.can_drop_now(), "supply releases again only after the complete batch is ready")
	for id in incoming:
		check(model.is_settled(model.cell(id)) and not bool(model.cell(id).settling), "each arrived root completes its settling flag and readiness together")
	check(model.try_merge(incoming[0], target_id) == "merged", "an arrived root can merge after recovery")
	model.step(Model.FUSION_SECONDS)
	var merged: Dictionary = model.cells.back()
	check(not bool(merged.arrival) and is_equal_approx(Model.settle_duration(merged), Model.SETTLE_SECONDS),
		"merging an arrived root restores the ordinary merge recovery duration")
	model.step(Model.SETTLE_SECONDS)
	check(model.is_settled(model.cell(int(merged.id))), "merge recovery remains independent of the prior long arrival clock")


func _test_arrival_automatic_timing() -> void:
	var manual := Model.new()
	var automatic := Model.new()
	manual.configure([_word("cat")], 3, 7)
	automatic.configure([_word("cat")], 3, 7)
	var incoming: Array[int] = _arrival_ids(manual)
	manual.drop_now(incoming[0])
	automatic.step(Model.INITIAL_SPAWN_INTERVAL - 0.001)
	check(automatic.generated_tiles == Model.INITIAL_SETTLED_TILES, "natural descent preserves the twenty-second initial supply interval")
	automatic.step(0.001)
	check(automatic.generated_tiles == Model.INITIAL_SETTLED_TILES + Model.DROP_COUNT, "automatic supply starts one six-root batch at its existing deadline")
	for id in incoming:
		check(manual.cell(id) == automatic.cell(id), "manual and automatic arrival share identities, placement, delays, and clocks")
	var latest_ready: float = Model.settle_duration(automatic.cell(incoming.back()))
	automatic.step(latest_ready)
	check(automatic.can_drop_now() and is_equal_approx(automatic.spawn_elapsed, latest_ready), "descent does not pause or restart the next automatic supply timer")
	check(is_equal_approx(automatic.spawn_interval, 20.0) and is_equal_approx(Model.MIN_SPAWN_INTERVAL, 16.0),
		"arrival polish retains the established relaxed supply pacing")


func _test_arrival_full_board_determinism() -> void:
	var whole = _model([_word("cat")])
	var sliced = _model([_word("cat")])
	for model in [whole, sliced]:
		model.cells.clear()
		_fill_rows(model, 1, Model.ROWS - 1)
		check(model.drop_now(), "last open row accepts a batch before full-board danger")
	var latest_ready: float = Model.settle_duration(whole.cells.back())
	whole.step(latest_ready - 0.001)
	check(whole.full_elapsed < 0.0 and whole.phase == "playing", "danger waits for the last staggered arrival to finish recovering")
	whole.step(0.001)
	check(is_zero_approx(whole.full_elapsed), "full-board danger starts exactly when the final arrival becomes ready")
	whole.step(1.5)
	var duration: float = latest_ready + 1.5
	var elapsed: float = 0.0
	while elapsed + Model.EPSILON < duration:
		var delta: float = minf(0.013, duration - elapsed)
		sliced.step(delta)
		elapsed += delta
	check(is_equal_approx(whole.full_elapsed, sliced.full_elapsed) and is_equal_approx(whole.full_elapsed, 1.5),
		"coarse and fine frame slices start the danger clock at the same arrival boundary")
	for index in range(whole.cells.size()):
		var a: Dictionary = whole.cells[index]
		var b: Dictionary = sliced.cells[index]
		check(a.id == b.id and a.column == b.column and a.row == b.row and a.settling == b.settling and is_equal_approx(a.age, b.age),
			"arrival frame slicing preserves placement, readiness, and elapsed ages")
	_assert_board(whole, "full-board arrival")


func _test_arrival_reachable_lanes() -> void:
	var model = _model([_word("cat")])
	model.cells.clear()
	for column in range(Model.COLUMNS):
		model.cells.append(_placed_tile(1000 + column, "x", column, 4))
	var incoming: Array[int] = _arrival_ids(model)
	check(model.drop_now(), "supply can land on a raised roof without filling enclosed holes")
	for index in range(incoming.size()):
		var tile: Dictionary = model.cell(incoming[index])
		check(tile.column == index and tile.row == 3 and tile.falling_rows == 4,
			"a new root stops at the first existing support in its vertical entry lane")
	_assert_board(model, "arrivals above a raised roof")
	model = _model([_word("cat")])
	model.cells.clear()
	for column in range(Model.COLUMNS):
		model.cells.append(_placed_tile(1000 + column, "cat" if column == 0 else "x", column, 0,
			2 if column == 0 else 1, 0, _word("cat") if column == 0 else {}))
	model.cells[0].width = 1
	var preview: Array = model.upcoming.duplicate(true)
	var generated: int = model.generated_tiles
	check(model._occupied().size() < Model.CAPACITY and not model.can_drop_now() and not model.drop_now(),
		"enclosed empty cells cannot admit roots through a completely sealed entry")
	model.step(1.0)
	check(is_equal_approx(model.full_elapsed, 1.0) and model.generated_tiles == generated and model.upcoming == preview,
		"a sealed roof advances danger without consuming or repeatedly respawning the preview")
	check(model.collect(1000), "a valid roof word can reopen the entry")
	model.step(Model.COLLECT_SECONDS + Model.SETTLE_SECONDS)
	check(model.full_elapsed < 0.0 and model.can_drop_now(), "collecting the roof resets danger and reopens reachable entry lanes")
	check(model.drop_now(int(preview[0].id)), "the unchanged preview can enter after the roof is cleared")
	_assert_board(model, "reopened entry after collection")


func _test_arrival_reserved_lanes() -> void:
	var model = _model([_word("cat")])
	model.cells.assign([_placed_tile(1000, "ca", 0, 0), _placed_tile(1001, "t", 2, 3)])
	for column in range(2, Model.COLUMNS):
		model.cells.append(_placed_tile(2000 + column, "x", column, 0))
	check(model.try_merge(1000, 1001) == "merged", "arrival reservation fixture commits a wide future word")
	var reserved: Dictionary = model.fusions[0].result.duplicate(true)
	check(reserved.column == 1 and reserved.row == 3 and reserved.width == 2,
		"future word reserves its neighboring entry lane before the visual merge finishes")
	var incoming: Array[int] = _arrival_ids(model)
	check(model.drop_now(), "remaining entry space accepts arrivals during a merge")
	for index in range(incoming.size()):
		var tile: Dictionary = model.cell(incoming[index])
		if index < 3:
			check(not tile.is_empty() and tile.column == 1 and tile.row == 2 - index,
				"roots stack above the reserved result instead of crossing its future footprint")
		else:
			check(tile.is_empty(), "a partial batch stops when every entry lane is sealed")
	check(not model.can_drop_now() and model.upcoming[0].id == incoming[3],
		"unreleased roots stay committed at the front of the preview after a partial batch")
	_assert_reservations(model, "arrival respects a future word roof")
	_assert_board(model, "partial arrival into a reserved lane")


func _test_arrival_same_lane_spacing() -> void:
	var model = _model([_word("cat")])
	model.cells.clear()
	for column in range(Model.COLUMNS - 1):
		model.cells.append(_placed_tile(2000 + column, "x", column, 0))
	var incoming: Array[int] = _arrival_ids(model)
	check(model.drop_now(), "one deep open entry lane can admit a complete batch")
	var clearance: float = sqrt(2.0 / Motion.ARRIVAL_GRAVITY)
	for index in range(incoming.size()):
		var tile: Dictionary = model.cell(incoming[index])
		check(tile.column == Model.COLUMNS - 1 and tile.row == Model.ROWS - 1 - index,
			"the only reachable lane stacks new roots from the floor upward")
		check(is_equal_approx(Model.arrival_delay(tile), float(index) * clearance),
			"repeated use of one lane gives the preceding root a full row of headroom")
		check(is_equal_approx(Model.arrival_contact_at(tile), Model.arrival_delay(tile) + Motion.contact_at(tile))
			and is_equal_approx(Model.settle_duration(tile), Model.arrival_delay(tile) + Motion.ready_at(tile)),
			"contact and input readiness use the stored lane delay")
	for sample_index in range(160):
		var elapsed: float = float(sample_index) * 0.025
		var previous_y: float = INF
		for id in incoming:
			var tile: Dictionary = model.cell(id)
			var age: float = elapsed - Model.arrival_delay(tile)
			if age < 0.0:
				continue
			tile.age = age
			var y: float = float(tile.row) - float(Motion.sample(tile).lift_rows)
			check(y + 1.0 <= previous_y + Model.EPSILON, "same-lane arrivals keep one full row between visible bodies throughout descent")
			previous_y = y
	var last_ready: float = Model.settle_duration(model.cell(incoming.back()))
	model.step(last_ready - 0.001)
	check(not model.can_drop_now() and not model.is_settled(model.cell(incoming.back())),
		"long lane stagger remains part of the authoritative input lock")
	model.step(0.001)
	check(model.can_drop_now() and model.is_settled(model.cell(incoming.back())),
		"the next supply unlocks after the last same-lane root recovers")
	_assert_board(model, "same-lane arrival settlement")
