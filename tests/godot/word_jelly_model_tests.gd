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
	_test_rejected_merge_atomicity()
	_test_repeated_merge_and_fragments()
	_test_collection_timeline_and_pause()
	_test_collection_batch_rhythm()
	_test_collection_batch_candidates()
	_test_collection_batch_settlement()
	_test_collection_batch_reserved_motion()
	_test_collection_batch_pause_and_cancel()
	_test_collection_batch_wallet()
	_test_collection_batch_lifecycle()
	_test_collection_batch_determinism()
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
	_test_automatic_support_settlement()
	_test_reposition_bounds_and_falls()
	_test_reposition_support_and_growth()
	_test_reposition_support_loss()
	_test_reposition_legacy_gravity()
	_test_reposition_reservations_and_guards()
	_test_reposition_history_and_rewards()
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
	_test_supply_packets()
	_test_all_age_complementary_supply()
	_test_supply_preview_stability()
	_test_arrival_timing()
	_test_arrival_readiness_and_pause()
	_test_arrival_automatic_timing()
	_test_arrival_full_board_determinism()
	_test_arrival_reachable_lanes()
	_test_arrival_reserved_lanes()
	_test_arrival_same_lane_spacing()
	_test_arrival_mixed_lane_readiness()
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
	for boundary in range(Model.ROWS + 2):
		if model.is_settled(model.cell(source)) and model.is_settled(model.cell(target)):
			break
		model.step(Model.SETTLE_SECONDS)
	check(model.try_merge(source, target) == "merged", "available jellies can merge")
	if model.fusions.is_empty():
		return {}
	var result_id: int = int(model.fusions.back().result.id)
	model.step(Model.FUSION_SECONDS)
	return model.cell(result_id)


func _legacy_parent(model, source: int, target: int) -> Dictionary:
	# Install a historical invalid merge and its actual ancestry directly.
	# New gameplay must pass try_merge's current-age, forward-word validation.
	model.step(Model.SETTLE_SECONDS)
	for boundary in range(Model.ROWS + 2):
		if model.is_settled(model.cell(source)) and model.is_settled(model.cell(target)):
			break
		model.step(Model.SETTLE_SECONDS)
	var a: Dictionary = model.cell(source).duplicate(true)
	var b: Dictionary = model.cell(target).duplicate(true)
	var parent: Dictionary = model._new_tile(str(a.text) + str(b.text), int(a.mass) + int(b.mass), int(a.fragments) + int(b.fragments))
	check(parent.word.is_empty(), "a legacy fixture explicitly represents an unrecognized historical parent")
	var excluded: Array[int] = [source, target]
	var destination: Vector2i = model._position_near(model._occupied(excluded), int(parent.width), int(parent.height), b)
	if destination.x < 0:
		parent.width = b.width
		parent.height = b.height
		destination = Vector2i(int(b.column), int(b.row))
	parent.column = destination.x
	parent.row = destination.y
	parent.skin = int(b.get("skin", b.id))
	parent.age = 0.0
	parent.settling = true
	model.cells.assign(model.cells.filter(func(tile: Dictionary) -> bool: return int(tile.id) not in [source, target]))
	model.cells.append(parent)
	model._merge_history[int(parent.id)] = [a, b]
	model.merged_count += 1
	model._restore_growth(int(parent.id))
	model._gravity_pending = true
	model._resume_pending_motion()
	return model.cell(int(parent.id))


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
	check(model.cells.size() == Model.INITIAL_SETTLED_TILES, "round starts with eighteen parts")
	for row in range(Model.ROWS):
		check(model.cells.filter(func(tile: Dictionary) -> bool: return int(tile.row) == row).size()
			== (Model.COLUMNS if row >= Model.ROWS - 3 else 0), "Exactly the bottom three rows start full")
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
	_assert_supply_conservation(model.cells, [configured], "curated two-part opening", false)


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
	check(model.try_merge(1000, 1001) == "wrong" and model.fusions.is_empty(),
		"a lower-age word is rejected before either part can merge")
	var current: Dictionary = _merge(model, 1002, 1003)
	check(current.word.id == "rocket", "current-age word resolves its image")
	model = _model([_word("ice cream")])
	_board(model, ["ice ", "cream"])
	var spaced: Dictionary = _merge(model, 1000, 1001)
	check(spaced.word.id == "ice cream" and spaced.text == "ice cream", "multiword vocabulary preserves its separator")
	model = _model([_word("cat")])
	_board(model, ["t", "ca"])
	check(model.try_merge(1000, 1001) == "wrong" and model.cells.size() == 2 and model.fusions.is_empty(),
		"a reverse-only word keeps both original parts separate")


func _rejection_state(model) -> Dictionary:
	return {"snapshot": model.snapshot(), "history": model._merge_history.duplicate(true),
		"receipts": model._collection_event_ids.duplicate(true), "next_tile": model._next_tile_id,
		"next_event": model._next_event_id, "held": model._held_tile_id,
		"growth": model._growth_pending, "gravity": model._gravity_pending,
		"generation": model._generation, "rng": model._rng.state,
		"supply": model._supply.duplicate(true), "pending_supply": model._supply_pending.duplicate(true)}


func _test_rejected_merge_atomicity() -> void:
	var model = _model([_word("small"), _word("sleep"), _word("cat")])
	var events: Dictionary = _observe(model)
	var emitted: Dictionary = {"changed": 0, "fusion": 0, "payments": 0}
	model.changed.connect(func() -> void: emitted.changed += 1)
	model.fusion_started.connect(func(_payload: Dictionary) -> void: emitted.fusion += 1)
	model.credit_collection = func(_id: String, _coins: int) -> Dictionary:
		emitted.payments += 1
		return {"ok": true}
	for pair: Array in [["ll", "sma"], ["sa", "sleep"], ["ca", "te"], ["cat", "er"]]:
		var pieces: Array[String] = []
		pieces.assign(pair)
		_board(model, pieces, [2, 3])
		model.set_held_tile(1000)
		emitted.changed = 0
		var before: Dictionary = _rejection_state(model)
		var cues_before: int = events.cues.size()
		check(model.try_merge(1000, 1001, true) == "wrong", "only an exact forward current-age spelling can merge: " + str(pair))
		check(_rejection_state(model) == before, "rejection preserves all board, reward, history, held, reservation, clock, and ID state")
		check(events.cues.size() == cues_before + 1 and events.cues.back() == "wrong",
			"an eligible rejected attempt requests one negative cue")
	check(events.attempts.is_empty() and events.collections.is_empty() and events.completed.is_empty()
		and emitted == {"changed": 0, "fusion": 0, "payments": 0}, "rejected words cause no learning penalty, fusion, payout, or board change event")
	_board(model, ["sma", "ll"], [2, 3])
	check(model.try_merge(1000, 1001, true) == "merged" and model.fusions[0].result.text == "small"
		and model.fusions[0].result.fragments == 5, "the same complementary pieces succeed in forward order and retain all fragments")
	model.credit_collection = Callable()
	model = _model()
	model.configure([_word("cat", 3), _word("rocket", 6), _word("advanced", 12)], 6, 42)
	for pair: Array in [["ca", "t"], ["adva", "nced"]]:
		var pieces: Array[String] = []
		pieces.assign(pair)
		_board(model, pieces, [1, 1])
		var before: Dictionary = _rejection_state(model)
		check(model.try_merge(1000, 1001) == "wrong" and _rejection_state(model) == before,
			"both younger and older dictionary spellings reject atomically at the current age")
	model = _model([_word("cat")])
	_board(model, ["ca", "t", "ll", "sma"], [1, 1, 2, 3])
	check(model.try_merge(1000, 1001) == "merged", "independent valid fusion begins before rejection")
	var before: Dictionary = _rejection_state(model)
	events = _observe(model)
	check(model.try_merge(1002, 1003) == "wrong" and _rejection_state(model) == before,
		"rejecting another pair preserves every concurrent fusion and frozen destination")
	check(model.try_merge(1000, 1003) == "ignored" and model.try_merge(1002, 1002) == "ignored"
		and model.try_merge(-99, 1003) == "ignored" and events.cues == ["wrong"], "reserved, self, and missing targets are ignored without extra negative cues")
	model.set_paused(true)
	check(model.try_merge(1002, 1003) == "ignored" and events.cues == ["wrong"], "pause rejects input without a negative cue")
	model = _model([_word("cat")])
	_board(model, ["ca", "t", "er"], [2, 3, 4])
	var word: Dictionary = _merge(model, 1000, 1001)
	model.step(Model.SETTLE_SECONDS)
	model.credit_collection = func(_id: String, _coins: int) -> Dictionary: return {"ok": false}
	check(model.collect(int(word.id)), "a formed word can have an outstanding wallet retry before rejection")
	model.step(Model.COLLECT_SECONDS)
	check(not model._merge_history.is_empty() and not model._collection_event_ids.is_empty(),
		"rejection history fixture contains real ancestry and a persisted retry identity")
	model.set_held_tile(int(word.id))
	before = _rejection_state(model)
	events = _observe(model)
	check(model.try_merge(int(word.id), 1002, true) == "wrong" and _rejection_state(model) == before
		and events.cues == ["wrong"] and events.attempts.is_empty(),
		"rejected growth preserves a completed word, its ancestry, retry receipt, held anchor, and every carried fragment")
	model.credit_collection = Callable()
	for replace_round: bool in [false, true]:
		var lifecycle_model = _model([_word("cat")])
		_board(lifecycle_model, ["t", "ca"], [2, 3])
		var after_callback: Dictionary = {}
		lifecycle_model.cue_requested.connect(func(cue: String) -> void:
			check(cue == "wrong", "reentrant rejection delivers the negative cue")
			if replace_round:
				lifecycle_model.configure([_word("cat")], 3, 19)
			else:
				lifecycle_model.finish_round()
			after_callback.assign(_rejection_state(lifecycle_model)), CONNECT_ONE_SHOT)
		check(lifecycle_model.try_merge(1000, 1001) == "wrong" and _rejection_state(lifecycle_model) == after_callback,
			"ending or replacing the round in the negative cue leaves no stale merge work afterward")


func _test_repeated_merge_and_fragments() -> void:
	var model = _model([_word("cat"), _word("cater"), _word("caterpillar")])
	_board(model, ["ca", "t", "er", "pillar"], [1, 1, 1, 1])
	var first: Dictionary = _merge(model, 1000, 1001)
	check(first.word.id == "cat", "first merge already forms a word")
	var second: Dictionary = _merge(model, int(first.id), 1002)
	check(second.text == "cater" and second.word.id == "cater", "a valid word can grow only into another current-age word")
	var third: Dictionary = _merge(model, int(second.id), 1003)
	check(third.text == "caterpillar" and third.word.id == "caterpillar", "repeated exact forward words can build a larger compound")
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
	model.step(0.179)
	check(events.cues.is_empty() and model.collected_coins == 0, "manual collection does not pop or credit before 180 ms")
	model.step(0.001)
	check(events.cues == ["pop"] and model.collected_coins == 0, "manual disappearance starts at 180 ms before reward credit")
	model.set_paused(true)
	model.step(10.0)
	check(model.cells.size() == 1 and model.collected_coins == 0, "pause during disappearance preserves the reservation")
	model.set_paused(false)
	model.step(0.239)
	check(model.cells.size() == 1 and model.collected_coins == 0, "resumed manual collection remains uncredited before 420 ms")
	model.step(0.001)
	check(model.cells.is_empty() and model.collected_coins == 100, "resumed manual collection credits once at 420 ms")
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
		_placed_tile(1001, "ca", 0, 6), _placed_tile(1002, "t", 1, 6), _placed_tile(1003, "x", 0, 4)])
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
	var parent: Dictionary = _legacy_parent(model, 1001, 1002)
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
	model.set_held_tile(1000)
	model.collect(1000)
	model.set_held_tile(-1)
	check(not model._gravity_pending and model._held_tile_id == -1,
		"releasing a pointer after its collection commits does not schedule an unrelated gravity pass")
	model.step(Model.COLLECT_SECONDS)
	check(model.cell(1001).row == 6 and model.cell(1002).row == 5 and not model._gravity_pending,
		"a failed collection alone neither removes support nor initiates gravity")
	model.credit_collection = Callable()
	model = _model([_word("cat")])
	model.cells.assign([_placed_tile(1000, "cat", 2, 2, 2, 3, _word("cat"))])
	model.credit_collection = func(_receipt: String, _coins: int) -> Dictionary: return {"ok": false}
	model.set_held_tile(1000)
	check(model.collect(1000), "a held upper word can start its normal collection")
	model.set_held_tile(-1)
	model.step(Model.COLLECT_SECONDS)
	check(model.cell(1000).row == 2 and model.is_settled(model.cell(1000)) and not model._gravity_pending
		and model.collected_coins == 0 and model.fragment_count == 0,
		"a failed wallet leaves an upper collected word immediately available at its unchanged retry position")
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


func _batch_board(model, count: int = 9) -> void:
	model.cells.clear()
	for index in range(count):
		var row: int = Model.ROWS - ceili(float(count) / 3.0) + int(index / 3)
		model.cells.append(_placed_tile(1000 + index, "cat", (index % 3) * 2, row, 2, 1, _word("cat")))


func _observe_batch(model) -> Array:
	var starts: Array = []
	var observed: WeakRef = weakref(model)
	model.collection_started.connect(func(payload: Dictionary) -> void:
		var active_model: RefCounted = observed.get_ref()
		starts.append({"id": int(payload.a_id), "batch": bool(payload.batch),
			"index": int(payload.batch_index), "total": int(payload.batch_total),
			"time": float(active_model.collection_batch_snapshot().elapsed),
			"collections_running": active_model.fusions.filter(func(active: Dictionary) -> bool: return str(active.operation) == "collect").size()}))
	return starts


func _observe_batch_payouts(model) -> Array:
	var payouts: Array = []
	var observed: WeakRef = weakref(model)
	model.collected.connect(func(id: String, _word_data: Dictionary, coins: int, fragments: int) -> void:
		var active_model: RefCounted = observed.get_ref()
		payouts.append({"id": id, "coins": coins, "fragments": fragments,
			"time": float(active_model.collection_batch_snapshot().elapsed)}))
	return payouts


func _test_collection_batch_rhythm() -> void:
	var model = _model([_word("cat")])
	_batch_board(model)
	var events: Dictionary = _observe(model)
	var starts: Array = _observe_batch(model)
	var payouts: Array = _observe_batch_payouts(model)
	var expected_ids: Array[int] = [1000, 1001, 1002, 1005, 1004, 1003, 1006, 1007, 1008]
	check(model.collectable_ids() == expected_ids, "batch candidates sweep upper rows first and alternate horizontal direction")
	check(model.start_collection_batch(), "a batch snapshots every currently completed word")
	check(not model.start_collection_batch(), "repeated button activation cannot duplicate a running batch")
	check(starts.size() == 1 and is_zero_approx(float(starts[0].time)), "the first word responds immediately")
	check(model.collection_batch_snapshot().remaining == 9, "remaining count includes the in-flight collection")
	check(not model.collect(1001) and model.try_merge(1001, 1002) == "ignored", "batch words cannot be manually collected or merged during their reserved sequence")
	check(not model.drop_now(), "manual drops do not interrupt a batch")
	model.set_held_tile(1001)
	check(model._held_tile_id == -1, "a batch cannot acquire a new drag anchor")
	var expected_time: float = 0.0
	for index in range(expected_ids.size()):
		if index > 0:
			model.step(0.099)
			check(starts.size() == index and payouts.size() == index - 1,
				"neither the next collection nor its preceding payout runs before 100 ms")
			model.step(0.001)
			expected_time += 0.10
		check(starts.size() == index + 1, "exact beat boundary starts one collection")
		var start: Dictionary = starts[index]
		check(start.id == expected_ids[index], "the captured spatial order is preserved across collection gravity")
		check(start.batch and start.index == index + 1 and start.total == expected_ids.size(), "presentation receives stable batch index and total")
		check(is_equal_approx(float(start.time), expected_time) and start.collections_running == 1,
			"each rhythmic start occurs at its authoritative time with one collecting body")
		check(model.collected_coins == index * 100, "only preceding completed transactions have earned coins")
		check(payouts.size() == index, "each 100 ms boundary commits exactly one preceding word")
		if index > 0:
			check(is_equal_approx(float(payouts[index - 1].time), expected_time),
				"authoritative coin and fragment payouts follow the exact 100 ms cadence")
	model.step(0.099)
	check(model.collection_batch_active() and payouts.size() == 8,
		"the final word also retains its complete 100 ms transaction")
	model.step(0.001)
	check(not model.collection_batch_active() and model.cells.is_empty(), "the batch ends only after its final transaction completes")
	check(model.collection_batch_snapshot().completed == 9 and model.collection_batch_snapshot().remaining == 0, "completed status accounts for every collected word")
	check(model.collected_coins == 900 and model.fragment_count == 9 and model.cleared_pairs == 9, "all coins and fragments use normal once-only collection rewards")
	check(events.collections.size() == 9 and events.attempts.size() == 9 and events.cues.count("pop") == 9, "every word gets one collection, learning attempt and disappearance cue")
	check(events.milestones == [[0, 1], [1, 2]], "batch fragments preserve normal chest unlock and upgrade milestones")
	check(payouts.size() == 9 and is_equal_approx(float(payouts.back().time), 0.9)
		and is_equal_approx(float(model.collection_batch_snapshot().elapsed), 0.9),
		"nine words take 0.9 seconds with no acceleration or extra breathing gaps")
	var coin_total: int = model.collected_coins
	model.step(1.0)
	check(model.collected_coins == coin_total and not model.start_collection_batch(), "an empty batch has no repeat rewards")


func _test_collection_batch_candidates() -> void:
	var model = _model([_word("cat")])
	_board(model, ["ca", "t", "x", "y"])
	var invalid: Dictionary = _legacy_parent(model, 1002, 1003)
	var valid: Dictionary = _merge(model, 1000, 1001)
	check(model.collectable_ids() == [int(valid.id)], "only valid merged words are eligible, including their final wobble")
	check(model.start_collection_batch() and model.fusions.is_empty(), "a just-merged word can queue while its finishing wobble settles")
	check(not model.split(int(invalid.id)), "manual splitting waits while the batch is active")
	# A later word is not silently added to the button's captured set.
	model.cells.append(_placed_tile(9000, "cat", 0, 1, 2, 0, _word("cat")))
	model.step(2.0)
	check(model.cleared_pairs == 1 and not model.cell(9000).is_empty(), "the click collects only its original word IDs")
	check(not model.cell(int(invalid.id)).is_empty() and model.can_split(model.cell(int(invalid.id))), "invalid merged words survive batch collection with their split history")
	model.step(Model.SETTLE_SECONDS)
	check(model.split(int(invalid.id)), "normal invalid-word splitting resumes after the batch")
	model = _model([_word("cat")])
	_batch_board(model, 3)
	model.set_held_tile(1000)
	check(not 1000 in model.collectable_ids() and not model.start_collection_batch(), "a held word is excluded and a live drag cannot start batch collection")
	model.set_held_tile()
	var manual_payloads: Array = []
	model.collection_started.connect(func(payload: Dictionary) -> void: manual_payloads.append(payload), CONNECT_ONE_SHOT)
	check(model.collect(1000), "manual collection remains supported")
	check(manual_payloads.size() == 1 and not bool(manual_payloads[0].batch)
		and manual_payloads[0].batch_index == 0 and manual_payloads[0].batch_total == 0, "manual collection uses the shared presentation signal without batch metadata")
	check(model.collectable_ids() == [1001, 1002], "already-collecting words are excluded from the new batch snapshot")
	var starts: Array = _observe_batch(model)
	check(model.start_collection_batch() and starts.is_empty(), "a manual collection already in flight finishes before the batch starts")
	model.step(Model.COLLECT_SECONDS)
	check(starts.size() == 1 and starts[0].id == 1001, "batch begins as soon as an earlier manual collection completes")
	model.step(2.0)
	check(model.cleared_pairs == 3 and model.collection_batch_snapshot().completed == 2, "preexisting manual rewards stay separate from batch accounting")


func _test_collection_batch_settlement() -> void:
	for moving_index: int in [0, 1]:
		var settling_model = _model([_word("cat")])
		_batch_board(settling_model, 3)
		settling_model.cells[moving_index].age = 0.0
		settling_model.cells[moving_index].settling = true
		var starts: Array = _observe_batch(settling_model)
		var payouts: Array = _observe_batch_payouts(settling_model)
		settling_model.start_collection_batch()
		settling_model.step(Model.SETTLE_SECONDS - 0.001)
		check(starts.is_empty(), "batch waits once for every captured word's existing settlement")
		settling_model.step(0.001)
		check(starts.size() == 1 and is_equal_approx(float(starts[0].time), Model.SETTLE_SECONDS),
			"the initial settlement boundary starts collection even when a later word was moving")
		settling_model.step(2.0)
		check(settling_model.cleared_pairs == 3 and starts.size() == 3 and payouts.size() == 3,
			"an initially moving batch completes all captured words")
		for index in range(starts.size()):
			check(is_equal_approx(float(starts[index].time), Model.SETTLE_SECONDS + index * 0.10)
				and is_equal_approx(float(payouts[index].time), Model.SETTLE_SECONDS + (index + 1) * 0.10),
				"initial settlement cannot introduce later gaps into the 100 ms collection cadence")
	var model = _model([_word("cat")])
	_batch_board(model, 3)
	model.start_collection_batch()
	model.cells.remove_at(1)
	model.step(2.0)
	check(model.cleared_pairs == 2 and model.collection_batch_snapshot().skipped == 1 and not model.collection_batch_active(), "a vanished captured ID is skipped without blocking or awarding a missing word")
	model = _model([_word("cat")])
	_batch_board(model, 3)
	model.spawn_interval = Model.INITIAL_SPAWN_INTERVAL
	model.spawn_elapsed = Model.INITIAL_SPAWN_INTERVAL - 0.2
	model.start_collection_batch()
	model.step(0.21)
	check(model.generated_tiles == Model.INITIAL_SETTLED_TILES + Model.DROP_COUNT and model.collection_batch_active(), "automatic arrival clocks continue normally during collection")
	check(model.cells.any(func(tile: Dictionary) -> bool: return bool(tile.get("arrival", false))), "automatic drops retain their normal staggered arrival bodies")


func _test_collection_batch_reserved_motion() -> void:
	var model = _model([_word("cat")])
	_batch_board(model, 3)
	for tile: Dictionary in model.cells:
		tile.row = 4
	model.cells[2].width = 1
	model.cells.append(_placed_tile(9000, "x", 0, 2))
	var starts: Array = _observe_batch(model)
	var payouts: Array = _observe_batch_payouts(model)
	model.start_collection_batch()
	model.step(0.10)
	check(starts.size() == 2 and payouts.size() == 1,
		"an unsupported captured word starts on the next 100 ms beat")
	check(_footprint(model.cell(1002)) == Rect2i(4, 4, 1, 1),
		"queued captured words keep their original footprint until their collection beat")
	check(model.cell(9000).row == 7 and bool(model.cell(9000).get("falling", false)),
		"ordinary roots still fall after a collected word while batch targets are reserved")
	model.step(0.20)
	check(starts.size() == 3 and payouts.size() == 3 and not model.collection_batch_active(),
		"floating and compressed words all collect without waiting for growth or gravity")
	for index in range(starts.size()):
		check(is_equal_approx(float(starts[index].time), index * 0.10)
			and is_equal_approx(float(payouts[index].time), (index + 1) * 0.10),
			"reserved batch bodies retain exact 100 ms starts and payouts")
	check(model.cells.size() == 1 and model.cell(9000).row == 7,
		"collecting the reserved batch leaves the unrelated root on its support")
	model = _model([_word("cat")])
	_batch_board(model, 3)
	for tile: Dictionary in model.cells:
		tile.row = 4
	model.cells[2].width = 1
	model.start_collection_batch()
	model.step(0.10)
	model.cancel_collection_batch()
	model.step(1.2)
	check(model.cleared_pairs == 2 and model.collected_coins == 200 and model.cells.size() == 1,
		"cancelling reserves no later payout beyond the already-started word")
	check(_footprint(model.cell(1002)) == Rect2i(4, 7, 2, 1) and model.is_settled(model.cell(1002)),
		"cancelling releases the remaining word for its deferred growth and natural fall")
	check(model.collect(1002), "the released word remains manually collectable after cancellation")
	model.step(Model.COLLECT_SECONDS)
	check(model.collected_coins == 300 and model.cells.is_empty(),
		"manual retry after cancellation credits the remaining word once")


func _test_collection_batch_pause_and_cancel() -> void:
	var model = _model([_word("cat")])
	_batch_board(model, 3)
	model.set_paused(true)
	check(not model.start_collection_batch(), "paused play cannot begin a batch")
	model.set_paused(false)
	model.start_collection_batch()
	model.step(0.05)
	model.set_paused(true)
	var before: Dictionary = model.snapshot()
	model.step(8.0)
	check(model.snapshot() == before, "pause freezes batch rhythm, current transaction and board clocks together")
	model.set_paused(false)
	model.step(0.049)
	check(model.cleared_pairs == 0 and model.collection_batch_active(),
		"resume preserves the final millisecond of the current 100 ms transaction")
	model.cancel_collection_batch()
	model.step(0.001)
	check(model.cleared_pairs == 1 and not model.collection_batch_active(),
		"cancelling the queue still finishes the current word at its preserved 100 ms deadline")
	model.step(2.0)
	check(model.cleared_pairs == 1 and model.cells.size() == 2 and not model.collection_batch_active(), "cancelling releases queued words without awarding them")
	check(model.start_collection_batch(), "remaining words can start a fresh batch after cancellation")
	model.step(0.03)
	model.cancel_collection_batch()
	model.step(2.0)
	check(model.cleared_pairs == 2 and model.cells.size() == 1, "cancelled queues let the one already-started transaction finish normally")
	check(model.collect(1002), "the final uncollected word remains manually collectable")
	model.step(Model.COLLECT_SECONDS)
	check(model.cleared_pairs == 3, "manual collection after cancellation grants the remaining reward once")


func _test_collection_batch_wallet() -> void:
	var model = _model([_word("cat")])
	_batch_board(model, 3)
	var calls: Array = []
	model.credit_collection = func(event_id: String, amount: int) -> Dictionary:
		calls.append([event_id, amount])
		return {"ok": calls.size() != 2}
	model.start_collection_batch()
	model.step(5.0)
	check(calls.size() == 2 and model.cleared_pairs == 1 and model.collected_coins == 100, "wallet failure stops the batch at the failed word without subsequent payments")
	check(not model.collection_batch_active() and model.cells.size() == 2 and not model.error.is_empty(), "failed and queued words remain available with a recoverable error")
	check(model.collect(1001), "a failed batch word can retry through ordinary collection")
	model.step(Model.COLLECT_SECONDS)
	check(calls.size() == 3 and calls[1][0] == calls[2][0] and calls[2][1] == 100, "wallet retry keeps its original receipt and amount")
	check(model.start_collection_batch(), "remaining unattempted word can be batch-collected after retry")
	model.step(0.10)
	check(model.cleared_pairs == 3 and model.collected_coins == 300 and calls.size() == 4, "retry and new batch still award each captured word exactly once")
	model.credit_collection = Callable()
	model = _model([_word("cat")])
	_batch_board(model, 3)
	model.credit_collection = func(_id: String, _amount: int) -> Dictionary:
		model.configure([_word("cat")], 3, 7)
		return {"ok": true}
	model.start_collection_batch()
	model.step(5.0)
	check(model.cleared_pairs == 0 and model.fusions.is_empty() and model.collection_batch_snapshot().total == 0,
		"round replacement inside wallet persistence cannot commit an old batch into the new round")
	model.credit_collection = Callable()
	model = _model([_word("cat")])
	_batch_board(model, 3)
	var paused_calls: Array = []
	model.credit_collection = func(event_id: String, amount: int) -> Dictionary:
		paused_calls.append([event_id, amount])
		if paused_calls.size() == 1:
			model.set_paused(true)
		return {"ok": true}
	model.start_collection_batch()
	model.step(3.0)
	check(model.paused and paused_calls.size() == 1 and model.cleared_pairs == 0, "a wallet callback can pause an accepted batch transaction before its presentation commits")
	model.set_paused(false)
	model.step(3.0)
	check(paused_calls.size() == 3 and model.cleared_pairs == 3 and model.collected_coins == 300, "resuming a credited batch does not repeat payment and continues its queue")
	model.credit_collection = Callable()


func _test_collection_batch_lifecycle() -> void:
	var model = _model([_word("cat")])
	_batch_board(model, 3)
	model.start_collection_batch()
	model.step(0.10)
	var result: Dictionary = model.finish_round()
	model.step(5.0)
	check(result.coins == 100 and model.cells.size() == 2 and not model.collection_batch_active(), "finishing a round cancels queued words and includes only committed collections")
	model = _model([_word("cat")])
	_batch_board(model, 3)
	model.collection_started.connect(func(_payload: Dictionary) -> void:
		model.configure([_word("cat")], 3, 7), CONNECT_ONE_SHOT)
	model.start_collection_batch()
	check(model.collection_batch_snapshot().total == 0 and model.fusions.is_empty() and model.cleared_pairs == 0, "reconfiguration inside collection presentation discards the old batch and operation")
	_assert_board(model, "batch reconfigured from start")
	model = _model([_word("cat")])
	_batch_board(model, 3)
	model.collected.connect(func(_id: String, _word_data: Dictionary, _coins: int, _fragments: int) -> void:
		model.configure([_word("cat")], 3, 7), CONNECT_ONE_SHOT)
	model.start_collection_batch()
	model.step(5.0)
	check(model.collection_batch_snapshot().total == 0 and model.cleared_pairs == 0 and model.generated_tiles == Model.INITIAL_SETTLED_TILES,
		"reconfiguration during reward callback cannot start stale queued words or consume new-round time")
	model = _model([_word("cat")])
	_batch_board(model, 3)
	model.collected.connect(func(_id: String, _word_data: Dictionary, _coins: int, _fragments: int) -> void:
		model.cancel_collection_batch(), CONNECT_ONE_SHOT)
	model.start_collection_batch()
	model.step(5.0)
	check(model.cleared_pairs == 1 and model.cells.size() == 2 and not model.collection_batch_active(), "cancelling from the reward callback cannot start a stale follow-on collection")
	model = _model([_word("cat")])
	_batch_board(model, 3)
	model.credit_collection = func(_id: String, _amount: int) -> Dictionary:
		model.set_paused(true)
		return {"ok": true}
	model.start_collection_batch()
	model.step(0.10)
	result = model.finish_round()
	check(result.coins == 100 and model.cleared_pairs == 1 and not model.collection_batch_active(), "exit while paused commits the accepted batch receipt and cancels all later words")
	model.credit_collection = Callable()


func _test_collection_batch_determinism() -> void:
	var large = _model([_word("cat")])
	var fine = _model([_word("cat")])
	for model in [large, fine]:
		_batch_board(model)
	var large_starts: Array = _observe_batch(large)
	var fine_starts: Array = _observe_batch(fine)
	large.start_collection_batch()
	fine.start_collection_batch()
	large.step(6.0)
	for index in range(600):
		fine.step(0.01)
	check(large_starts.size() == fine_starts.size(), "coarse and fine frames start the same batch collections")
	for index in range(large_starts.size()):
		check(large_starts[index].id == fine_starts[index].id
			and is_equal_approx(float(large_starts[index].time), float(fine_starts[index].time)), "frame partitioning preserves batch order and exact rhythmic start time")
	check(large.collected_coins == fine.collected_coins and large.fragment_count == fine.fragment_count and large.cells == fine.cells,
		"coarse and fine batch stepping preserve identical board and rewards")
	check(is_equal_approx(float(large.collection_batch_snapshot().elapsed), float(fine.collection_batch_snapshot().elapsed)), "batch duration stops at the final transaction regardless of frame size")
	check(is_equal_approx(large.spawn_elapsed, fine.spawn_elapsed), "collection sequencing does not distort the automatic arrival clock")


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
	# Synthetic exact-word chain isolates mass and packing mechanics.
	var vocabulary: Array = []
	for length in range(2, 11):
		vocabulary.append(_word("a".repeat(length)))
	var model = _model(vocabulary)
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
		"the fusion reserves its upper endpoint before any later support settlement")
	model.step(Model.FUSION_SECONDS)
	var merged: Dictionary = model.cell(int(planned.id))
	check(_footprint(merged) == _footprint(planned), "fusion handover commits the exact preannounced destination")
	check(model.cell(1002).column == neighbor.position.x and model.cell(1002).row == Model.ROWS - 1
		and bool(model.cell(1002).falling), "merge completion also settles an unrelated unsupported jelly")
	check(merged.mass == 2 and merged.fragments == 3 and merged.text == "cat", "target placement preserves all merged content and fragments")
	model.step(Model.SETTLE_SECONDS)
	check(model.cell(int(planned.id)).column == planned.column and model.cell(int(planned.id)).row == Model.ROWS - 1
		and bool(model.cell(int(planned.id)).falling) and not model.is_settled(model.cell(int(planned.id))),
		"an unsupported merged word begins a natural vertical fall after its handover wobble")
	model.step(Model.SETTLE_SECONDS)
	check(model.is_settled(model.cell(int(planned.id))) and not model._gravity_pending,
		"the merged word finishes on actual support without requiring a later collection")
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
		model.step(Model.SETTLE_SECONDS * 2.0)
		check(model.cell(int(planned.id)).row == Model.ROWS - 2 and model.is_settled(model.cell(int(planned.id))),
			"a large wrapped merge finishes on the floor after its reserved handover")
		_assert_board(model, "wrapped edge placement")


func _test_automatic_support_settlement() -> void:
	var model = _model([_word("cat")])
	model.cells.assign([_placed_tile(1000, "ca", 0, 7), _placed_tile(1001, "t", 4, 7),
		_placed_tile(1002, "x", 0, 6)])
	check(model.try_merge(1000, 1001) == "merged", "moving a lower root into a merge can remove its old support")
	model.step(Model.FUSION_SECONDS)
	check(model.cell(1002).row == 7 and bool(model.cell(1002).falling),
		"a merge settles the unsupported stack left behind by its source")
	model.step(Model.SETTLE_SECONDS)
	_assert_supported_tiles(model, [1002], "support removed by merge")
	model = _model()
	_board(model, ["t", "ca"])
	var parent: Dictionary = _legacy_parent(model, 1000, 1001)
	parent.column = 0
	parent.row = 5
	parent.age = Model.SETTLE_SECONDS
	parent.settling = false
	model.cells.assign([parent, _placed_tile(2000, "x", 0, 4)])
	check(model.split(int(parent.id)), "an upper invalid word can split into supported lower destinations")
	model.step(Model.SPLIT_SECONDS + Model.SETTLE_SECONDS)
	_assert_supported_tiles(model, [1000, 1001, 2000], "support removed by split")
	check(model.cell(2000).row > 4, "splitting settles a neighbor that loses the parent's old support")
	model = _model()
	var compressed: Dictionary = _placed_tile(1000, "large", 2, 2, 7, 3)
	compressed.width = 2
	compressed.height = 1
	model.cells.assign([compressed])
	model._restore_growth()
	check(model.cell(1000).width == 6 and model.cell(1000).height == 2 and model._gravity_pending,
		"automatic wrapped growth schedules support settlement for its enlarged body")
	model.step(Model.SETTLE_SECONDS * 2.0)
	check(_footprint(model.cell(1000)) == Rect2i(0, 6, 6, 2) and model.is_settled(model.cell(1000))
		and not model._gravity_pending, "a grown wrapped body cannot remain suspended above empty rows")
	_assert_board(model, "automatic wrapped growth and fall")


func _test_reposition_bounds_and_falls() -> void:
	var model = _model([_word("cat")])
	var original: Dictionary = _placed_tile(1000, "cat", 0, 7, 2, 3, _word("cat"))
	original.skin = 4
	model.cells.assign([original, _placed_tile(1001, "x", 4, 3)])
	var events: Dictionary = _observe(model)
	var before: Dictionary = model.snapshot()
	for position: Vector2i in [Vector2i(-1, 0), Vector2i(5, 0), Vector2i(0, -1), Vector2i(0, 8), Vector2i(3, 3), Vector2i(0, 7)]:
		check(not model.can_reposition(1000, position.x, position.y)
			and not model.reposition(1000, position.x, position.y), "invalid, occupied, and unchanged full-body placements are rejected")
		check(model.snapshot() == before, "a rejected placement leaves position, footprint, clocks, and rewards unchanged")
	check(not model.can_reposition(-1, 2, 1) and not model.reposition(-1, 2, 1), "missing tile IDs cannot reserve a placement")
	check(model.can_reposition(1000, 2, 1) and model.reposition(1000, 2, 1), "an entire wide jelly can be placed in a fitting empty space")
	var moved: Dictionary = model.cell(1000)
	check(_footprint(moved) == Rect2i(2, 7, 2, 1) and bool(moved.placement_locked)
		and not model.is_settled(moved) and bool(moved.settling) and bool(moved.falling)
		and moved.falling_rows == 6 and is_zero_approx(float(moved.age)),
		"an unsupported release immediately plans a fall in the chosen column while preserving its whole footprint")
	for key: String in ["id", "text", "word", "mass", "parts_count", "fragments", "chest", "kind", "skin"]:
		check(moved[key] == original[key], "reposition preserves the jelly's " + key)
	check(events.collections.is_empty() and events.attempts.is_empty() and events.cues.is_empty()
		and model.collected_coins == 0 and model.fragment_count == 0 and model.merged_count == 0,
		"manual reposition emits no collection, learning, sound, fragment, or coin reward")
	model.step(Model.SETTLE_SECONDS - 0.001)
	check(not model.is_settled(model.cell(1000)), "manual drop remains unavailable until its last landing millisecond")
	model.step(0.001)
	check(model.is_settled(model.cell(1000)), "manual drop completes at the ordinary settle boundary")
	model.step(2.0)
	check(_footprint(model.cell(1000)) == Rect2i(2, 7, 2, 1) and not model._gravity_pending and not model._growth_pending,
		"a released word finishes on the floor without keeping pending-motion flags alive")
	before = model.snapshot()
	check(not model.reposition(1000, 2, 7) and model.snapshot() == before,
		"releasing an already supported word at its current coordinate preserves its existing state")
	check(model.reposition(1000, 3, 1), "a moved footprint may overlap its own old cells when the full destination is free")
	model.step(Model.SETTLE_SECONDS)
	check(_footprint(model.cell(1000)) == Rect2i(3, 6, 2, 1), "a wide drop stops when its right edge reaches another body's support")
	_assert_supported_tiles(model, [1000], "manual wide drop")
	_assert_board(model, "manual wide drop")
	model = _model()
	model.cells.assign([_placed_tile(1000, "wrapped", 0, 6, 7, 2)])
	check(not model.can_reposition(1000, 1, 0) and not model.reposition(1000, 0, 7),
		"wrapped placement validates both the six-column width and the second occupied row")
	check(model.reposition(1000, 0, 0), "a wrapped jelly can be placed at the top when its complete body fits")
	model.step(Model.SETTLE_SECONDS * 2.0)
	check(_footprint(model.cell(1000)) == Rect2i(0, 6, 6, 2) and bool(model.cell(1000).placement_locked)
		and model.cell(1000).falling_rows == 6,
		"a manually released multirow body falls to the floor with its full height intact")
	_assert_supported_tiles(model, [1000], "manual wrapped drop")
	_assert_board(model, "manual wrapped drop")


func _test_reposition_support_and_growth() -> void:
	var model = _gravity_tower()
	model.set_held_tile(1001)
	model.collect(1000)
	model.step(Model.COLLECT_SECONDS)
	check(model.cell(1001).row == 6 and model.cell(1002).row == 5, "held source keeps its old stack stable while support is collected")
	check(model.reposition(1001, 3, 3), "a held source can commit its explicit destination after lower support changes")
	check(model.cell(1001).row == 7 and bool(model.cell(1001).placement_locked) and bool(model.cell(1001).falling)
		and model.cell(1002).row == 7 and bool(model.cell(1002).falling),
		"manual relocation immediately drops both the released body and the abandoned upper stack onto real support")
	model.set_held_tile(-1)
	model.step(Model.SETTLE_SECONDS)
	check(model.cell(1001).row == 7 and model.cell(1001).column == 3 and model.is_settled(model.cell(1001)) and not model._gravity_pending,
		"releasing the drag anchor preserves the chosen column through the natural landing")
	model.cells.append(_placed_tile(9000, "x", 3, 1))
	model._gravity_pending = true
	model.step(Model.SETTLE_SECONDS)
	check(model.cell(9000).row == 6 and model.cell(1001).row == 7,
		"a manually moved body supports naturally falling neighbors only at its actual landing position")
	_assert_board(model, "manual position supports a falling neighbor")
	model = _model()
	var compressed: Dictionary = _placed_tile(1000, "large", 0, 7, 7, 2)
	compressed.width = 2
	compressed.height = 1
	model.cells.assign([compressed])
	check(model.reposition(1000, 2, 2), "the actual compressed body can move where its complete current footprint fits")
	model.step(Model.SETTLE_SECONDS)
	model._restore_growth()
	model._gravity_pending = true
	model.step(2.0)
	check(_footprint(model.cell(1000)) == Rect2i(2, 7, 2, 1) and bool(model.cell(1000).placement_locked)
		and not model._gravity_pending and not model._growth_pending,
		"deferred growth preserves the moved compressed footprint and column while gravity still brings it to the floor")


func _test_reposition_support_loss() -> void:
	for mass: int in [1, 3, 7]:
		var model = _model([_word("cat")])
		var column: int = 0 if mass == 7 else 2 if mass == 3 else 4
		var body: Dictionary = _placed_tile(1000, "part", 0, 0, mass, 2)
		model.cells.assign([body, _placed_tile(1001, "cat", 4, 7, 2, 4, _word("cat"))])
		var height: int = int(body.height)
		var width: int = int(body.width)
		var events: Dictionary = _observe(model)
		check(model.reposition(1000, column, 2), "the complete released footprint fits above a partial supporting word")
		check(_footprint(model.cell(1000)) == Rect2i(column, 7 - height, width, height)
			and bool(model.cell(1000).falling) and model.cell(1000).falling_rows == 5 - height,
			"single, wide, and wrapped manual drops stop at the first support under any part of their bottom edge")
		check(events.collections.is_empty() and events.attempts.is_empty() and events.cues.is_empty(),
			"finding support during a manual drop never creates a reward or learning attempt")
		_assert_supported_tiles(model, [1000], "manual partial support")
		_assert_board(model, "manual partial support")
		model.step(Model.SETTLE_SECONDS)
		check(model.collect(1001), "the actual supporting word remains collectable after the moved body lands")
		model.step(Model.COLLECT_SECONDS)
		check(_footprint(model.cell(1000)) == Rect2i(column, Model.ROWS - height, width, height)
			and bool(model.cell(1000).falling) and model.cell(1000).falling_rows == 1,
			"removing support resumes gravity for every manually moved footprint without changing its chosen column")
		check(model.cell(1000).mass == mass and model.cell(1000).fragments == 2
			and model.collected_coins == 100 and model.fragment_count == 4 and events.collections.size() == 1,
			"the resumed fall preserves moved content and pays only the collected support once")
		model.step(Model.SETTLE_SECONDS)
		_assert_supported_tiles(model, [1000], "manual support removed")
		_assert_board(model, "manual support removed")
	var model = _model([_word("cat")])
	model.cells.assign([_placed_tile(1000, "x", 0, 7), _placed_tile(1001, "cat", 4, 7, 2, 0, _word("cat"))])
	check(model.reposition(1000, 4, 6), "a release can also land directly on an existing body")
	check(_footprint(model.cell(1000)) == Rect2i(4, 6, 1, 1) and not bool(model.cell(1000).falling)
		and model.cell(1000).falling_rows == 0 and not model.is_settled(model.cell(1000)),
		"an already supported release keeps the usual landing wobble without inventing a downward fall")
	model.step(Model.SETTLE_SECONDS)
	check(model.is_settled(model.cell(1000)) and not model._gravity_pending, "a supported release settles without persistent gravity work")


func _test_reposition_legacy_gravity() -> void:
	for mass: int in [1, 7]:
		for pause_release: bool in [false, true]:
			var model = _model()
			var body: Dictionary = _placed_tile(1000, "legacy", 0, 1, mass, 3)
			body.placement_locked = true
			model.cells.assign([body, _placed_tile(1001, "x", 0, 0)])
			model.set_held_tile(1000)
			model.step(0.1)
			check(model.cell(1000).row == 1 and model.cell(1001).row == 0,
				"a held legacy placement still anchors its stack until release")
			model.set_paused(pause_release)
			model.set_held_tile(-1)
			if pause_release:
				check(model.cell(1000).row == 1 and model._gravity_pending,
					"a paused unchanged release queues gravity without moving the held stack")
				model.set_paused(false)
			var landing_row: int = Model.ROWS - int(body.height)
			check(model.cell(1000).row == landing_row and model.cell(1000).column == 0
				and bool(model.cell(1000).falling) and model.cell(1000).falling_rows == landing_row - 1,
				"an old placement lock cannot keep an unsupported body floating after an unchanged release")
			check(model.cell(1001).row == landing_row - 1 and bool(model.cell(1001).falling),
				"releasing a legacy floating body also lowers the stack it used to support")
			model.step(Model.SETTLE_SECONDS)
			check(model.cell(1000).mass == mass and model.cell(1000).fragments == 3
				and not model._gravity_pending and model.collected_coins == 0,
				"legacy placement recovery preserves its content and completes without rewards")
			_assert_supported_tiles(model, [1000, 1001], "legacy placement recovery")
			_assert_board(model, "legacy placement recovery")


func _test_reposition_reservations_and_guards() -> void:
	var model = _model([_word("cat")])
	model.cells.assign([_placed_tile(1000, "x", 5, 7), _placed_tile(1001, "ca", 0, 1), _placed_tile(1002, "t", 2, 1)])
	check(model.try_merge(1001, 1002) == "merged", "a concurrent merge reserves a new neighboring cell")
	check(not model.reposition(1000, 1, 1), "reposition cannot occupy an empty-looking cell reserved by a future merge body")
	check(not model.reposition(1001, 3, 3), "a live fusion source cannot be repositioned")
	model = _model()
	_board(model, ["t", "ca"])
	var parent: Dictionary = _legacy_parent(model, 1000, 1001)
	parent.column = 0
	parent.row = 1
	parent.age = Model.SETTLE_SECONDS
	parent.settling = false
	model.cells.assign([parent, _placed_tile(2000, "x", 5, 7)])
	check(model.split(int(parent.id)), "a split reserves empty cells below its original body")
	var child: Dictionary = model.fusions[0].results[0]
	check(not model.reposition(2000, int(child.column), int(child.row)), "reposition honors every pending split child destination")
	model = _model([_word("cat")])
	_batch_board(model, 3)
	model.start_collection_batch()
	check(not model.can_reposition(1002, 3, 2) and not model.reposition(1002, 3, 2), "a batch keeps all explicit placement input gated")
	model.step(0.30)
	check(model.cleared_pairs == 3 and is_equal_approx(float(model.collection_batch_snapshot().elapsed), 0.30),
		"rejected manual movement preserves the three exact 100 ms batch transactions")
	model = _model()
	_board(model, ["x"])
	model.set_paused(true)
	check(not model.reposition(1000, 2, 2), "paused play cannot change an explicit position")
	model.set_paused(false)
	model.cells[0].age = 0.0
	model.cells[0].settling = true
	check(not model.reposition(1000, 2, 2), "an unheld settling body cannot be moved")
	model.set_held_tile(1000)
	check(model.reposition(1000, 2, 2), "the currently held source may finish a deliberate placement during recovery")
	model.finish_round()
	check(not model.reposition(1000, 3, 2), "finished rounds cannot accept a late drag release")
	model.configure([_word("cat")], 3, 42)
	check(model.cells.all(func(tile: Dictionary) -> bool: return not bool(tile.get("placement_locked", false))),
		"new rounds discard explicit placement locks")


func _test_reposition_history_and_rewards() -> void:
	var model = _model([_word("cat")])
	_board(model, ["ca", "t"], [2, 3])
	var word: Dictionary = _merge(model, 1000, 1001)
	model.step(Model.SETTLE_SECONDS)
	var receipts: Array[String] = []
	model.credit_collection = func(receipt: String, _amount: int) -> Dictionary:
		receipts.append(receipt)
		return {"ok": receipts.size() > 1}
	check(model.collect(int(word.id)), "a valid word can retain a failed payment receipt before moving")
	model.step(Model.COLLECT_SECONDS)
	var ancestry: Array = model._merge_history[int(word.id)].duplicate(true)
	check(model.reposition(int(word.id), 2, 2), "a word with a failed payment can be moved without losing its retry")
	check(model._merge_history[int(word.id)] == ancestry and receipts.size() == 1,
		"reposition preserves merge ancestry and never calls wallet persistence")
	model.step(Model.SETTLE_SECONDS)
	check(model.collect(int(word.id)), "a positioned word remains collectable after its handover")
	model.step(Model.COLLECT_SECONDS)
	check(receipts.size() == 2 and receipts[0] == receipts[1] and model.collected_coins == 100
		and model.fragment_count == 5 and model.cells.is_empty(), "manual reposition preserves exact retry identity and once-only coin and fragment rewards")
	model.credit_collection = Callable()
	model = _model()
	_board(model, ["t", "ca"], [2, 3])
	check(model.reposition(1000, 0, 2) and model.reposition(1001, 2, 2), "both original parts can have explicit placements before a merge")
	model.step(Model.SETTLE_SECONDS)
	var parent: Dictionary = _legacy_parent(model, 1000, 1001)
	check(not bool(parent.placement_locked), "a new merged body cannot inherit either source's explicit placement lock")
	model.step(Model.SETTLE_SECONDS * 2.0)
	check(model.reposition(int(parent.id), 1, 3), "the merged invalid word can receive its own explicit placement")
	model.step(Model.SETTLE_SECONDS)
	check(model.split(int(parent.id)), "reposition preserves the invalid word's original split ancestry")
	for planned: Dictionary in model.fusions[0].results:
		check(not bool(planned.placement_locked), "split destinations clear historical source placement locks before presentation")
	model.step(Model.SPLIT_SECONDS + Model.SETTLE_SECONDS)
	for id: int in [1000, 1001]:
		check(not bool(model.cell(id).placement_locked), "restored split children use natural support rather than their old explicit locks")
	check(model.cell(1000).text == "t" and model.cell(1001).text == "ca"
		and model.cell(1000).fragments == 2 and model.cell(1001).fragments == 3,
		"moving, merging, moving again, and splitting preserves the original parts and separate fragments")
	_assert_supported_tiles(model, [1000, 1001], "split after explicit placement")
	_assert_board(model, "split ancestry after explicit placement")


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
	var parent: Dictionary = _legacy_parent(model, 1000, 1001)
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
	var inner: Dictionary = _legacy_parent(model, int(word.id), 1002)
	var outer: Dictionary = _legacy_parent(model, int(inner.id), 1003)
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
	var sibling: Dictionary = _legacy_parent(model, 1001, 1002)
	var parent: Dictionary = _legacy_parent(model, 1000, int(sibling.id))
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
	parent = _legacy_parent(model, 1000, 1001)
	_constrain_split_board(model, int(parent.id), Vector2i(2, 3), [Vector2i(3, 3), Vector2i(5, 3)])
	check(model.split(int(parent.id)), "prior saved footprints remain available when preferred sizes cannot fit")
	planned = model.fusions[0].results.duplicate(true)
	check(planned[0].width == 2 and planned[1].width == 1 and planned[0].mass == 4 and planned[1].mass == 3,
		"saved-footprint fallback retains full child mass instead of unnecessarily compressing both to one cell")
	model.step(Model.SPLIT_SECONDS)
	_assert_board(model, "saved split footprints")
	model = _model()
	model.cells.assign([_placed_tile(1000, "a", 0, 7, 2, 2), _placed_tile(1001, "b", 2, 7, 3, 3)])
	parent = _legacy_parent(model, 1000, 1001)
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
	parent = _legacy_parent(model, 1000, 1001)
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
	var parent: Dictionary = _legacy_parent(model, 1000, 1001)
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
	var parent: Dictionary = _legacy_parent(model, 1000, 1001)
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
	var parent: Dictionary = _legacy_parent(model, 1000, 1001)
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
	var lower: Dictionary = _legacy_parent(model, 1000, 1001)
	var upper: Dictionary = _legacy_parent(model, 1002, 1003)
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
	_board(model, ["a", "b", "c", "d", "ca", "t"])
	var a: Dictionary = _legacy_parent(model, 1000, 1001)
	var b: Dictionary = _legacy_parent(model, 1002, 1003)
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
	var parent: Dictionary = _legacy_parent(model, 1000, 1001)
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
		var a: Dictionary = _legacy_parent(model, 1000, 1001)
		var b: Dictionary = _legacy_parent(model, 1002, 1003)
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
	var parent: Dictionary = _legacy_parent(model, int(cat.id), 1002)
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
	parent = _legacy_parent(model, int(cat.id), 1002)
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
		var parent: Dictionary = _legacy_parent(model, 1000, 1001)
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
	var parent: Dictionary = _legacy_parent(model, 1000, 1001)
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
	var parent: Dictionary = _legacy_parent(model, 1000, 1001)
	model.step(Model.SETTLE_SECONDS + 2.0)
	var elapsed: float = model.full_elapsed
	check(elapsed >= 2.0 and model.split(int(parent.id)), "full board permits undo while its existing danger deadline is running")
	model.step(Model.SPLIT_SECONDS)
	check(is_equal_approx(model.full_elapsed, elapsed + Model.SPLIT_SECONDS), "split cannot restart a full-board deadline when it frees no occupied cell")
	model.step(Model.SETTLE_SECONDS)
	elapsed = model.full_elapsed
	check(model.try_merge(1000, 1001) == "wrong", "restored invalid roots reject a new merge while danger remains active")
	model.step(Model.FUSION_SECONDS)
	check(is_equal_approx(model.full_elapsed, elapsed + Model.FUSION_SECONDS), "a rejected merge after undo preserves the full-board deadline without occupancy relief")
	model.step(Model.FULL_SECONDS - model.full_elapsed)
	check(model.phase == "finished", "undo and rejected attempts cannot postpone a full board's expiry")


func _test_full_board() -> void:
	var model = _model([_word("cat")])
	var parts: Array[String] = []
	for index in range(Model.CAPACITY):
		parts.append("a")
	parts[0] = "ca"
	parts[1] = "t"
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


func _curated_word(text: String, parts: Array[String]) -> Dictionary:
	var word: Dictionary = _word(text)
	word.jelly_parts = parts
	return word


func _assert_supply_packet(packet: Array, label: String) -> void:
	check(packet.size() == Model.UPCOMING_COUNT, label + ": each advertised packet contains six roots")
	for index in range(1, packet.size()):
		check(int(packet[index].get("supply_group", -1)) != int(packet[index - 1].get("supply_group", -1)),
			label + ": sibling chunks have an intervening root when other source groups are available")


func _assert_supply_conservation(roots: Array, words: Array, label: String, allow_partial_tail: bool = true) -> Dictionary:
	var sources: Dictionary = {}
	for word: Dictionary in words:
		sources[str(word.id)] = word
	var ids: Dictionary = {}
	var groups: Dictionary = {}
	for root_index in range(roots.size()):
		var root: Dictionary = roots[root_index]
		check(not ids.has(int(root.id)), label + ": each original root appears exactly once")
		ids[int(root.id)] = true
		for key in ["supply_group", "supply_part", "supply_parts"]:
			check(root.get(key) is int, label + ": emitted roots retain integer " + key)
		var group_id: int = int(root.get("supply_group", -1))
		var part_index: int = int(root.get("supply_part", -1))
		var source: Dictionary = sources.get(str(root.get("source_word_id", "")), {})
		check(group_id > 0 and not source.is_empty(), label + ": every root identifies its source-word emission")
		if group_id <= 0 or source.is_empty():
			continue
		var expected_parts: Array = source.get("expected_parts", source.jelly_parts)
		check(int(root.get("supply_parts", 0)) == expected_parts.size(), label + ": the complete source part count survives mixing")
		check(part_index >= 0 and part_index < expected_parts.size(), label + ": original part indexes stay in range")
		if part_index < 0 or part_index >= expected_parts.size():
			continue
		check(str(root.text) == str(expected_parts[part_index]), label + ": every part retains its exact curated spelling")
		check(int(root.mass) == 1 and int(root.parts_count) == 1 and int(root.width) == 1 and int(root.height) == 1
			and str(root.kind) == "root" and root.word.is_empty(), label + ": mixing preserves one-cell unmerged roots")
		check(int(root.fragments) in [0, 1] and bool(root.chest) == (int(root.fragments) == 1),
			label + ": source fragments remain attached to their original roots")
		if not groups.has(group_id):
			groups[group_id] = {"source": source, "parts": {}, "fragments": 0, "packets": {}}
		var group: Dictionary = groups[group_id]
		check(str(group.source.id) == str(source.id), label + ": an emission never combines parts from different source words")
		check(not group.parts.has(part_index), label + ": no original source part is duplicated")
		group.parts[part_index] = root
		group.fragments += int(root.fragments)
		group.packets[int(root_index / Model.UPCOMING_COUNT)] = true
	var group_ids: Array = groups.keys()
	group_ids.sort()
	check(not group_ids.is_empty(), label + ": supply contains traceable source groups")
	for index in range(group_ids.size()):
		var group_id: int = int(group_ids[index])
		var group: Dictionary = groups[group_id]
		var expected_parts: Array = group.source.get("expected_parts", group.source.jelly_parts)
		var complete: bool = group.parts.size() == expected_parts.size()
		check(group_id == index + 1, label + ": FIFO source emissions are conserved without gaps")
		check(complete or (allow_partial_tail and index == group_ids.size() - 1),
			label + ": only the last packet boundary may leave a source word awaiting its remaining chunks")
		for part_index in range(group.parts.size()):
			check(group.parts.has(part_index), label + ": observed source chunks form an intact original prefix")
		check(int(group.fragments) <= 1, label + ": mixing cannot duplicate a source-word chest fragment")
		if complete:
			var spelling: String = ""
			for part_index in range(expected_parts.size()):
				if group.parts.has(part_index):
					spelling += str(group.parts[part_index].text)
			check(spelling == str(group.source.text), label + ": all emitted parts reconstruct their vocabulary word")
			check(int(group.fragments) == (1 if group_id % 2 == 0 else 0),
				label + ": complete source emissions preserve the established fragment frequency")
	return groups


func _test_supply_packets() -> void:
	var cat: Dictionary = _curated_word("cat", ["ca", "t"])
	var dog: Dictionary = _curated_word("dog", ["d", "og"])
	var rainbow: Dictionary = _curated_word("rainbow", ["rain", "b", "ow"])
	var sunflower: Dictionary = _curated_word("sunflower", ["sun", "flow", "er"])
	rainbow.expected_parts = ["rain", "bow"]
	sunflower.expected_parts = ["sun", "flower"]
	var vocabularies: Array = [[cat, dog], [rainbow, sunflower], [cat, rainbow, dog]]
	for vocabulary_index in range(vocabularies.size()):
		var words: Array = vocabularies[vocabulary_index]
		for seed_value in [7, 73, 411]:
			var model := Model.new()
			var repeated := Model.new()
			model.configure(words, 3, seed_value)
			repeated.configure(words, 3, seed_value)
			model.spawn_interval = 10000.0
			repeated.spawn_interval = 10000.0
			var label: String = "mixed supply %d seed %d" % [vocabulary_index, seed_value]
			var emitted: Array = model.cells.duplicate(true)
			check(model.snapshot() == repeated.snapshot(), label + ": the opening and its metadata are seed-deterministic")
			for packet_index in range(3):
				_assert_supply_packet(emitted.slice(packet_index * Model.UPCOMING_COUNT, (packet_index + 1) * Model.UPCOMING_COUNT), label + " opening")
			for packet_index in range(6):
				var preview: Array = model.upcoming.duplicate(true)
				_assert_supply_packet(preview, label + " future packet %d" % packet_index)
				check(preview == repeated.upcoming, label + ": repeated seeds advertise the same future IDs, chunks, and fragments")
				emitted.append_array(preview)
				# Clear only settled fixture bodies, leaving the source and preview queues untouched.
				model.cells.clear()
				repeated.cells.clear()
				var generated_before: int = model.generated_tiles
				check(model.drop_now(int(preview[0].id)) and repeated.drop_now(int(preview[0].id)), label + ": the complete advertised packet releases")
				check(model.generated_tiles == generated_before + Model.DROP_COUNT, label + ": each released packet contributes exactly six roots")
				for root: Dictionary in preview:
					var released: Dictionary = model.cell(int(root.id))
					for key in ["text", "mass", "parts_count", "fragments", "chest", "supply_group", "supply_part", "supply_parts", "source_word_id"]:
						check(released.get(key) == root.get(key), label + ": release preserves advertised " + key)
				var ready: float = _latest_arrival_ready(model)
				model.step(ready)
				repeated.step(ready)
				check(model.snapshot() == repeated.snapshot(), label + ": packet mixing and arrival remain deterministic across rounds of supply")
				check(model.can_drop_now(), label + ": the next packet waits only for the completed batch recovery")
			var groups: Dictionary = _assert_supply_conservation(emitted, words, label)
			if vocabulary_index == 2:
				var crossed_groups: int = 0
				for group: Dictionary in groups.values():
					if group.packets.size() > 1:
						crossed_groups += 1
				check(crossed_groups == 0, label + ": every complementary pair fits wholly inside its six-root packet")


func _test_all_age_complementary_supply() -> void:
	var vocabulary: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	check(vocabulary is Array and not vocabulary.is_empty(), "the complete production vocabulary loads for the supply audit")
	if not vocabulary is Array or vocabulary.is_empty():
		return
	var audited: int = 0
	var expected_total: int = 0
	for age in range(3, 13):
		var model := Model.new()
		check(model.configure(vocabulary, age, 42), "every supported age has an eligible Jelly Words supply")
		var age_count: int = 0
		var expected_age: int = 0
		for word: Dictionary in vocabulary:
			if int(word.min_age) == age and not str(word.image).is_empty() and not str(word.audio).is_empty() and str(word.text).length() >= 2:
				expected_age += 1
			if not model._eligible(word, age):
				continue
			var parts: Array[String] = model._parts_for_word(word)
			check(parts.size() == 2 and not parts[0].strip_edges().is_empty() and not parts[1].strip_edges().is_empty()
				and "".join(parts) == Model.normalize_word(str(word.text)),
				"every production word has two nonempty complementary chunks: age %d %s" % [age, str(word.id)])
			if parts.size() != 2:
				continue
			model.fusions.clear()
			_board(model, parts)
			check(model.try_merge(1000, 1001) == "merged" and str(model.fusions[0].word.id) == str(word.id),
				"each production pair completes in one legal forward merge: " + str(word.id))
			age_count += 1
		check(age_count > 0 and age_count == expected_age, "each age's complete eligible production word set is audited")
		audited += age_count
		expected_total += expected_age
	check(audited == expected_total, "the supply audit covers every production entry with word art, audio, and at least two letters")
	var model = _model()
	for fixture: Dictionary in [
		{"text": "rainbow", "parts": ["rain", "b", "ow"], "expected": ["rain", "bow"]},
		{"text": "sunflower", "parts": ["sun", "flow", "er"], "expected": ["sun", "flower"]},
		{"text": "ice cream", "parts": ["i", "ce ", "cre", "am"], "expected": ["ice ", "cream"]},
		{"text": "cat", "parts": ["wrong", "parts"], "expected": ["ca", "t"]},
		{"text": "cat", "parts": ["c", "", "at"], "expected": ["ca", "t"]}
	]:
		var word: Dictionary = _word(str(fixture.text))
		word.jelly_parts = fixture.parts
		check(model._parts_for_word(word) == fixture.expected, "authored chunks preserve meaningful boundaries or fall back to a complete pair: " + str(fixture))


func _test_supply_preview_stability() -> void:
	var model = _model([_curated_word("cat", ["ca", "t"]), _curated_word("sunflower", ["sun", "flow", "er"])])
	var preview: Array = model.upcoming.duplicate(true)
	model._fill_upcoming()
	model.step(0.1)
	check(model.upcoming == preview, "an advertised packet never reshuffles while waiting or being topped up")
	check(not model.drop_now(-999) and model.upcoming == preview, "a stale release request cannot reshuffle committed previews")
	model.set_paused(true)
	model.step(30.0)
	check(not model.drop_now(int(preview[0].id)) and model.upcoming == preview, "pause retains every advertised root and its order")
	model.set_paused(false)
	check(model.drop_now(int(preview[0].id)), "resuming releases the exact packet advertised before pause")
	var following: Array = model.upcoming.duplicate(true)
	check(not model.drop_now() and model.upcoming == following, "a blocked overlapping drop cannot reshuffle the following packet")
	model.step(_latest_arrival_ready(model))
	check(model.upcoming == following, "settling the current packet preserves the next advertised packet byte for byte")


func _arrival_ids(model) -> Array[int]:
	var ids: Array[int] = []
	for tile: Dictionary in model.upcoming:
		ids.append(int(tile.id))
	return ids


func _arrivals_by_readiness(model) -> Array[Dictionary]:
	var roots: Array[Dictionary] = []
	for tile: Dictionary in model.cells:
		if bool(tile.get("arrival", false)):
			roots.append(tile.duplicate(true))
	roots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return Model.settle_duration(a) < Model.settle_duration(b))
	return roots


func _latest_arrival_ready(model) -> float:
	var ready: float = 0.0
	for tile: Dictionary in model.cells:
		if bool(tile.get("arrival", false)):
			ready = maxf(ready, Model.settle_duration(tile))
	return ready


func _test_arrival_timing() -> void:
	var initial = _model([_word("cat")])
	var onset_slots: Array[int] = [0, 3, 1, 4, 2, 5]
	check(is_equal_approx(Model.ARRIVAL_STAGGER, 0.15), "arrival onsets have a readable 150-millisecond separation")
	check(initial.cells.size() == Model.INITIAL_SETTLED_TILES, "natural arrival keeps the three-row opening")
	for tile: Dictionary in initial.cells:
		check(initial.is_settled(tile) and not bool(tile.arrival) and is_equal_approx(Model.settle_duration(tile), Model.SETTLE_SECONDS),
			"opening roots remain settled with the ordinary recovery clock")
	for row in range(Model.ROWS):
		var model = _model([_word("cat")])
		model.cells.clear()
		_fill_rows(model, row + 1, Model.ROWS - 1)
		var incoming: Array[int] = _arrival_ids(model)
		check(model.drop_now(incoming[0]), "each supported row accepts a manual arrival batch")
		for index in range(incoming.size()):
			var tile: Dictionary = model.cell(incoming[index])
			var stagger: float = float(onset_slots.find(index)) * 0.15
			var expected_contact: float = stagger + sqrt(2.0 * float(row + 1) / Motion.ARRIVAL_GRAVITY)
			check(tile.row == row and tile.column == index and tile.falling_rows == row + 1,
				"arrival distance spans the whole well from one row above the board")
			check(tile.arrival_index == index and bool(tile.arrival) and bool(tile.settling) and tile.age == 0.0,
				"batch roots retain their advertised preview slot and start on the shared model clock")
			check(is_equal_approx(Model.arrival_delay(tile), stagger),
				"unrestricted lanes launch in the alternating 0, 3, 1, 4, 2, 5 preview-slot order")
			check(is_equal_approx(Model.arrival_contact_at(tile), expected_contact),
				"arrival contact follows board-scaled acceleration and batch stagger")
			check(is_equal_approx(Model.settle_duration(tile), expected_contact + Motion.COMPRESSION_SECONDS + Motion.REBOUND_SECONDS + Motion.RECOVERY_SECONDS),
				"arrival input readiness includes planted compression and complete recovery")
		for onset_index in range(1, onset_slots.size()):
			var previous: Dictionary = model.cell(incoming[onset_slots[onset_index - 1]])
			var current: Dictionary = model.cell(incoming[onset_slots[onset_index]])
			check(is_equal_approx(Model.arrival_contact_at(current) - Model.arrival_contact_at(previous), 0.15),
				"equal-height roots contact in the visible onset order without changing preview columns")
		_assert_board(model, "arrival row %d" % row)


func _test_arrival_readiness_and_pause() -> void:
	var model = _model([_word("cat")])
	var incoming: Array[int] = _arrival_ids(model)
	var target_id: int = int(model.cells[0].id)
	check(model.drop_now(incoming[0]), "arrival readiness fixture releases its committed preview")
	var by_readiness: Array[Dictionary] = _arrivals_by_readiness(model)
	var first_id: int = int(by_readiness.front().id)
	var last_id: int = int(by_readiness.back().id)
	var incoming_is_prefix: bool = str(model.cell(first_id).text) == "ca"
	for tile: Dictionary in model.cells:
		if model.is_settled(tile) and str(tile.text) == ("t" if incoming_is_prefix else "ca"):
			target_id = int(tile.id)
			break
	var first_contact: float = Model.arrival_contact_at(model.cell(first_id))
	var first_ready: float = Model.settle_duration(model.cell(first_id))
	var last_ready: float = Model.settle_duration(model.cell(last_id))
	model.step(first_contact)
	check(not model.is_settled(model.cell(first_id)) and bool(model.cell(first_id).settling),
		"touching support does not enable a jelly while it is still compressing")
	check(model.try_merge(first_id, target_id) == "ignored" and model.try_merge(target_id, first_id) == "ignored",
		"a falling or recovering root cannot be used as a merge source or target")
	check(not model.can_drop_now() and not model.drop_now(), "a new batch cannot overlap the current arrival recovery")
	var frozen: Dictionary = model.snapshot()
	model.set_paused(true)
	model.step(5.0)
	check(model.cells == frozen.cells and model.upcoming == frozen.upcoming and model.spawn_elapsed == frozen.spawn_elapsed,
		"pause freezes arrival positions, stagger ages, and the next supply clock")
	model.set_paused(false)
	model.step(first_ready - first_contact - 0.001)
	check(not model.is_settled(model.cell(first_id)) and not model.can_drop_now(), "input remains blocked until the final recovery millisecond")
	model.step(0.001)
	check(model.is_settled(model.cell(first_id)) and not bool(model.cell(first_id).settling), "first root becomes ready at its own exact recovery boundary")
	check(not model.is_settled(model.cell(last_id)) and not model.can_drop_now(), "the last staggered root retains its later readiness deadline")
	model.step(last_ready - first_ready)
	check(model.can_drop_now(), "supply releases again only after the complete batch is ready")
	for id in incoming:
		check(model.is_settled(model.cell(id)) and not bool(model.cell(id).settling), "each arrived root completes its settling flag and readiness together")
	check(model.try_merge(first_id if incoming_is_prefix else target_id, target_id if incoming_is_prefix else first_id) == "merged", "an arrived root can merge in word order after recovery")
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
	var latest_ready: float = _latest_arrival_ready(automatic)
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
	var latest_ready: float = _latest_arrival_ready(whole)
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
	var preview: Array = model.upcoming.duplicate(true)
	var generated_before: int = model.generated_tiles
	check(model.drop_now(), "remaining entry space accepts arrivals during a merge")
	for index in range(incoming.size()):
		var tile: Dictionary = model.cell(incoming[index])
		if index < 3:
			check(not tile.is_empty() and tile.column == 1 and tile.row == 2 - index,
				"roots stack above the reserved result instead of crossing its future footprint")
			check(int(tile.arrival_index) == index and is_equal_approx(Model.arrival_delay(tile), float(index) * 0.4),
				"partial same-lane batches preserve preview identity and safe FIFO launch spacing")
		else:
			check(tile.is_empty(), "a partial batch stops when every entry lane is sealed")
			check(model.upcoming[index - 3] == preview[index],
				"every unreleased preview keeps its complete original identity and order after a partial batch")
	check(not model.can_drop_now() and model.upcoming[0].id == incoming[3],
		"unreleased roots stay committed at the front of the preview after a partial batch")
	check(model.generated_tiles == generated_before + 3, "partial batches consume exactly the admitted FIFO prefix")
	_assert_reservations(model, "arrival respects a future word roof")
	_assert_board(model, "partial arrival into a reserved lane")


func _test_arrival_same_lane_spacing() -> void:
	var model = _model([_word("cat")])
	model.cells.clear()
	for column in range(Model.COLUMNS - 1):
		model.cells.append(_placed_tile(2000 + column, "x", column, 0))
	var incoming: Array[int] = _arrival_ids(model)
	check(model.drop_now(), "one deep open entry lane can admit a complete batch")
	var clearance: float = 0.4
	for index in range(incoming.size()):
		var tile: Dictionary = model.cell(incoming[index])
		check(tile.column == Model.COLUMNS - 1 and tile.row == Model.ROWS - 1 - index,
			"the only reachable lane stacks new roots from the floor upward")
		check(is_equal_approx(Model.arrival_delay(tile), float(index) * clearance),
			"repeated use of one lane reserves at least 400 milliseconds of headroom in FIFO landing order")
		check(is_equal_approx(Model.arrival_contact_at(tile), Model.arrival_delay(tile) + Motion.contact_at(tile))
			and is_equal_approx(Model.settle_duration(tile), Model.arrival_delay(tile) + Motion.ready_at(tile)),
			"contact and input readiness use the stored lane delay")
	_assert_arrival_lane_clearance(model, "same-lane batch")
	var by_readiness: Array[Dictionary] = _arrivals_by_readiness(model)
	var last_id: int = int(by_readiness.back().id)
	var last_ready: float = Model.settle_duration(model.cell(last_id))
	model.step(last_ready - 0.001)
	check(not model.can_drop_now() and not model.is_settled(model.cell(last_id)),
		"long lane stagger remains part of the authoritative input lock")
	model.step(0.001)
	check(model.can_drop_now() and model.is_settled(model.cell(last_id)),
		"the next supply unlocks after the last same-lane root recovers")
	_assert_board(model, "same-lane arrival settlement")


func _assert_arrival_lane_clearance(model, label: String) -> void:
	var roots: Array[Dictionary] = _arrivals_by_readiness(model)
	roots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return Model.arrival_delay(a) < Model.arrival_delay(b))
	for sample_index in range(ceili(_latest_arrival_ready(model) / 0.025) + 2):
		var elapsed: float = float(sample_index) * 0.025
		var previous_y: Dictionary = {}
		for root: Dictionary in roots:
			var tile: Dictionary = root.duplicate(true)
			var age: float = elapsed - Model.arrival_delay(tile)
			if age < 0.0:
				continue
			tile.age = age
			var y: float = float(tile.row) - float(Motion.sample(tile).lift_rows)
			var column: int = int(tile.column)
			check(y + 1.0 <= float(previous_y.get(column, INF)) + Model.EPSILON,
				label + ": arrivals retain one full row of physical clearance in actual launch order")
			previous_y[column] = y


func _test_arrival_mixed_lane_readiness() -> void:
	var model = _model([_word("cat")])
	model.cells.clear()
	for column in range(Model.COLUMNS):
		var first_occupied_row: int = maxi(0, 3 - column)
		for row in range(first_occupied_row, Model.ROWS):
			model.cells.append(_placed_tile(2000 + row * Model.COLUMNS + column, "x", column, row))
	var incoming: Array[int] = _arrival_ids(model)
	check(model.drop_now(), "uneven lanes admit the advertised six roots into a three-two-one staircase")
	var by_readiness: Array[Dictionary] = _arrivals_by_readiness(model)
	var last_id: int = int(by_readiness.back().id)
	var last_ready: float = Model.settle_duration(model.cell(last_id))
	var final_slot_ready: float = Model.settle_duration(model.cell(incoming.back()))
	check(last_id == incoming[4] and final_slot_ready < last_ready,
		"same-lane clearance can make an earlier preview slot recover after the final advertised slot")
	for index in range(incoming.size()):
		var tile: Dictionary = model.cell(incoming[index])
		check(int(tile.arrival_index) == index, "uneven lane placement retains the original preview slot identity")
	check(is_equal_approx(Model.arrival_delay(model.cell(incoming[4])), 1.0),
		"the fifth preview root waits behind its earlier same-lane sibling")
	_assert_arrival_lane_clearance(model, "uneven-lane batch")
	model.step(final_slot_ready)
	check(model.is_settled(model.cell(incoming.back())) and not model.is_settled(model.cell(last_id))
		and model.full_elapsed < 0.0, "the last advertised root cannot start danger before the physically latest arrival recovers")
	model.step(last_ready - final_slot_ready - 0.001)
	check(not model.is_settled(model.cell(last_id)) and model.full_elapsed < 0.0,
		"uneven-lane danger remains blocked through the final recovery millisecond")
	model.step(0.001)
	check(model.is_settled(model.cell(last_id)) and is_zero_approx(model.full_elapsed),
		"full-board danger starts at the maximum stored readiness across the whole batch")
	model.step(0.2)
	check(is_equal_approx(model.full_elapsed, 0.2), "uneven-lane danger counts only time after every root recovers")
	_assert_board(model, "uneven-lane arrival settlement")
