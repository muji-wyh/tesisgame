extends SceneTree

const Model = preload("res://scripts/word_jelly_model.gd")
const Motion = preload("res://scripts/jelly_motion.gd")
var checks: int = 0
var failures: int = 0
var _coin_seed_cache: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	_test_configuration()
	_test_auto_collect_unlock()
	_test_merging_and_collection()
	_test_rare_coin_drop_boundary()
	_test_collection_without_coin_drop()
	_test_rare_coin_drop_retry_and_pause()
	_test_rare_coin_drop_batch()
	_test_rare_coin_drop_frequency_and_independence()
	_test_current_age_validation()
	_test_rejected_merge_atomicity()
	_test_repeated_merge_and_fragments()
	_test_nested_merge_collection_receipts()
	_test_collection_timeline_and_pause()
	_test_level_collection_anticipation()
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
	_test_drag_support_removal()
	_test_drag_gravity_delay()
	_test_drag_partial_support()
	_test_drag_return_capacity()
	_test_drag_same_cell_release()
	_test_drag_finish_lifecycle()
	_test_gravity_reserved_operations()
	_test_gravity_simultaneous_collections()
	_test_gravity_settlement_determinism()
	_test_cell_size_after_gravity()
	_test_gravity_wallet_failure()
	_test_gravity_lifecycle()
	_test_wallet_retry()
	_test_chests()
	_test_repeated_merge_cell_size()
	_test_target_placement()
	_test_edge_placement()
	_test_automatic_support_settlement()
	_test_reposition_bounds_and_falls()
	_test_reposition_support_and_cell_size()
	_test_reposition_support_loss()
	_test_reposition_locked_gravity()
	_test_reposition_reservations_and_guards()
	_test_reposition_reward_retry()
	_test_fusion_reservations()
	_test_crowded_merge_cell_size()
	_test_cell_size_after_settlement()
	_test_full_board()
	_test_independent_operations()
	_test_lifecycle_reentry()
	_test_supply_and_determinism()
	_test_mastery_supply()
	_test_supply_packets()
	_test_all_age_complementary_supply()
	_test_supply_preview_stability()
	_test_immediate_manual_batches()
	_test_arrival_timing()
	_test_arrival_readiness_and_pause()
	_test_arrival_automatic_timing()
	_test_pacing_progression()
	_test_pacing_cycle_commit()
	_test_pacing_boundary_determinism()
	_test_arrival_full_board_determinism()
	_test_arrival_reachable_lanes()
	_test_arrival_preview_columns()
	_test_arrival_blocked_preview_slots()
	_test_arrival_reserved_lanes()
	_test_arrival_same_lane_spacing()
	_test_arrival_mixed_lane_readiness()
	_test_powerup_eligibility()
	_test_powerup_payment_atomicity()
	_test_powerup_price_progression()
	_test_powerup_auto_timeline()
	_test_powerup_auto_rhythm()
	_test_powerup_auto_random_sources()
	_test_powerup_auto_completion_during_drag()
	_test_powerup_auto_chain()
	_test_powerup_auto_interleaved_authored_paths()
	_test_powerup_manual_guards()
	_test_powerup_fragment_timeline()
	_test_powerup_fragment_launch_rhythm()
	_test_powerup_fragment_launch_reentry()
	_test_powerup_fragment_repeats()
	_test_powerup_fragment_changed_reentry()
	_test_powerup_fragment_repeat_failure()
	_test_powerup_fragment_repeat_lifecycle()
	_test_powerup_fragments_on_nested_word()
	_test_powerup_pause_and_clocks()
	_test_powerup_determinism()
	_test_powerup_finish_and_lifecycle()
	_test_powerup_payment_reentry()
	_test_finish_reasons()
	_test_powerup_presentation_reentry()
	print("Word Jelly model: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _word(text: String, age: int = 3, word_id: String = "") -> Dictionary:
	return {"id": text if word_id.is_empty() else word_id, "text": text, "min_age": age,
		"image": "assets/images/words/cat.png", "audio": "assets/audio/words/cat.wav"}


func _model(words: Array = [], force_coin_drop: bool = true) -> RefCounted:
	var model := Model.new()
	model.configure([_word("cat"), _word("caterpillar"), _word("sunflower")] if words.is_empty() else words, 3, 42)
	# Batch mechanics use an explicitly unlocked learner; the gate has its own cases.
	model.set_pip_level(3)
	model.spawn_interval = 10000.0
	if force_coin_drop:
		# Existing wallet and gravity fixtures explicitly exercise the rare winning branch.
		# Natural probability, zero rewards, and mixed batches have dedicated tests below.
		var winning_seed: int = _coin_seed_between(0.0, 0.02)
		model._coin_rng.seed = winning_seed
		var observed: WeakRef = weakref(model)
		model.collection_started.connect(func(_payload: Dictionary) -> void:
			var active_model: RefCounted = observed.get_ref()
			if active_model != null:
				active_model._coin_rng.seed = winning_seed)
	return model


func _coin_seed_between(minimum: float, maximum: float) -> int:
	var key: Vector2 = Vector2(minimum, maximum)
	if _coin_seed_cache.has(key):
		return int(_coin_seed_cache[key])
	var probe := RandomNumberGenerator.new()
	for seed_value in range(1000000):
		probe.seed = seed_value
		var roll: float = probe.randf()
		if roll >= minimum and roll < maximum:
			_coin_seed_cache[key] = seed_value
			return seed_value
	check(false, "the coin fixture can find a real RNG seed in its requested probability interval")
	return -1


func _tile(id: int, text: String, mass: int = 1, fragments: int = 0, word: Dictionary = {}) -> Dictionary:
	if text.begins_with("merged:"):
		var fields: PackedStringArray = text.split(":")
		var level: int = int(fields[2])
		var result: Dictionary = _tile(id, fields[1], 2 * level, fragments, _word(fields[1]))
		result.merge_level = level
		return result
	var picture: bool = text.begins_with("picture:")
	var spelling: String = text.trim_prefix("picture:")
	var semantic: Dictionary = word.duplicate(true) if not word.is_empty() else _word(spelling)
	return {"id": id, "text": spelling, "display_text": "" if picture else spelling,
		"jelly_kind": "merged" if not word.is_empty() else "picture" if picture else "root",
		"merge_level": 1 if not word.is_empty() else 0,
		"word_candidate": semantic if word.is_empty() and not picture else {},
		"image_word": semantic if picture or not word.is_empty() else {},
		"mastery_eligible": not word.is_empty(), "assisted": false,
		"mass": mass, "parts_count": mass, "fragments": fragments,
		"chest": fragments > 0, "word": word.duplicate(true), "kind": "word" if not word.is_empty() else "chunk",
		"column": id % Model.COLUMNS, "row": Model.ROWS - 1, "width": 1, "height": 1,
		"preferred_width": 1, "preferred_height": 1,
		"age": Model.SETTLE_SECONDS, "settling": false, "arrival": false, "falling_rows": 0}


func _board(model, pieces: Array[String], fragments: Array[int] = []) -> void:
	model.cells.clear()
	for index in range(pieces.size()):
		var tile: Dictionary = _tile(1000 + index, pieces[index], 1, fragments[index] if index < fragments.size() else 0)
		var candidate: Dictionary = model._word_lookup.get(Model.normalize_word(str(tile.text)), {})
		if not candidate.is_empty():
			if tile.jelly_kind == "picture":
				tile.image_word = candidate.duplicate(true)
			elif tile.jelly_kind == "root":
				tile.word_candidate = candidate.duplicate(true)
		tile.column = index % Model.COLUMNS
		tile.row = Model.ROWS - 1 - int(index / Model.COLUMNS)
		model.cells.append(tile)


func _placed_tile(id: int, text: String, column: int, row: int, mass: int = 1, fragments: int = 0, word: Dictionary = {}) -> Dictionary:
	var tile: Dictionary = _tile(id, text, mass, fragments, word)
	tile.column = column
	tile.row = row
	return tile


func _reward_tile(id: int, text: String, column: int, row: int, mass: int = 2, fragments: int = 0, word: Dictionary = {}) -> Dictionary:
	var tile: Dictionary = _placed_tile(id, text, column, row, mass, fragments, word)
	tile.merge_level = 2
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
		var destinations: Array = [active.result] if str(active.operation) == "merge" else []
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


func _assert_board(model, label: String) -> void:
	var ids: Dictionary = {}
	var occupied: Dictionary = {}
	for tile in model.cells:
		check(not ids.has(tile.id), label + ": unique tile ID")
		ids[tile.id] = true
		check(int(tile.column) >= 0 and int(tile.row) >= 0 and int(tile.width) >= 1 and int(tile.height) >= 1
			and int(tile.column) + int(tile.width) <= Model.COLUMNS and int(tile.row) + int(tile.height) <= Model.ROWS,
			label + ": every rectangular footprint stays within five columns and eight rows")
		for y in range(int(tile.row), int(tile.row) + int(tile.height)):
			for x in range(int(tile.column), int(tile.column) + int(tile.width)):
				var key: int = y * Model.COLUMNS + x
				check(not occupied.has(key), label + ": footprints never overlap")
				occupied[key] = tile.id
		check(int(tile.mass) >= 1 and int(tile.fragments) >= 0, label + ": mass and fragments remain valid")
		check(int(tile.width) == 1 and int(tile.height) == 1
			and int(tile.preferred_width) == 1 and int(tile.preferred_height) == 1,
			label + ": every source and merged word retains one ordinary cell")
	check(model.upcoming.size() == Model.UPCOMING_COUNT, label + ": five committed previews remain available")
	for tile in model.upcoming:
		check(not ids.has(tile.id), label + ": queued IDs remain distinct")
		check(int(tile.width) == 1 and int(tile.height) == 1
			and int(tile.preferred_width) == 1 and int(tile.preferred_height) == 1,
			label + ": queued bodies retain one ordinary cell")
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


func _powerup_model(kind: String):
	var model = _model([_word("cat"), _word("cater"), _word("dog")])
	if kind == "auto_merge":
		_board(model, ["picture:cat", "cat", "merged:cat:1", "dog", "picture:dog", "x"], [1, 2, 3, 4, 5, 6])
	else:
		_board(model, ["cat", "picture:cat", "dog", "picture:dog", "x", "y"], [0, 0, 0, 0, 3, 7])
	return model


func _accept_powerup_payments(model) -> Array:
	var payments: Array = []
	model.purchase_powerup = func(receipt_id: String, kind: String, price: int) -> Dictionary:
		payments.append({"id": receipt_id, "kind": kind, "price": price})
		return {"ok": true, "duplicate": false}
	return payments


func _observe_powerups(model) -> Dictionary:
	var events: Dictionary = {"feedback": [], "drags": [], "arrivals": []}
	model.powerup_feedback.connect(func(kind: String, success: bool) -> void:
		events.feedback.append([kind, success]))
	model.powerup_drag_started.connect(func(payload: Dictionary) -> void:
		events.drags.append(payload.duplicate(true)))
	model.powerup_fragment_arrived.connect(func(payload: Dictionary) -> void:
		events.arrivals.append(payload.duplicate(true)))
	return events


func _board_fragments(model) -> int:
	var total: int = 0
	for tile: Dictionary in model.cells:
		total += int(tile.fragments)
	return total


func _approximately_equal_state(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		return false
	if left is float:
		return is_equal_approx(float(left), float(right))
	if left is Dictionary:
		if left.size() != right.size():
			return false
		for key: Variant in left:
			if not right.has(key) or not _approximately_equal_state(left[key], right[key]):
				return false
		return true
	if left is Array:
		if left.size() != right.size():
			return false
		for index in range(left.size()):
			if not _approximately_equal_state(left[index], right[index]):
				return false
		return true
	return left == right


func _test_powerup_eligibility() -> void:
	check(Model.POWERUP_PRICES == {"auto_merge": 600, "fragments": 200, "extra_time": 100},
		"paid powers expose their first-purchase prices")
	for kind: String in ["auto_merge", "fragments"]:
		for blocked_by: String in ["paused", "held", "settling", "fusion", "collection", "batch", "finished", "empty"]:
			var model = _powerup_model(kind)
			var payments: Array = _accept_powerup_payments(model)
			match blocked_by:
				"paused":
					model.set_paused(true)
				"held":
					model.set_held_tile(1000)
				"settling":
					model.cells[0].age = 0.0
					model.cells[0].settling = true
				"fusion":
					_board(model, ["cat", "picture:cat", "cat", "picture:cat"])
					model.try_merge(1000, 1001)
				"collection", "batch":
					model.cells.assign([_placed_tile(1000, "cat", 0, 7, 2, 0, _word("cat")),
						_placed_tile(1001, "cat", 2, 7), _placed_tile(1002, "picture:cat", 3, 7)])
					if blocked_by == "collection":
						model.collect(1000)
					else:
						model.start_collection_batch()
				"finished":
					model.finish_round()
				"empty":
					model.cells.clear()
			var before: Dictionary = model.snapshot()
			check(not model.can_activate_powerup(kind) and not model.activate_powerup(kind),
				kind + " rejects " + blocked_by + " boards before payment")
			check(payments.is_empty() and model.snapshot() == before and not model.powerup_active(),
				"ineligible paid power preserves the board and never invokes the wallet: " + blocked_by)
			model.purchase_powerup = Callable()
	var model = _model([_word("cat")])
	_board(model, ["cat", "x"])
	var payments: Array = _accept_powerup_payments(model)
	check(not model.can_activate_powerup("auto_merge") and not model.activate_powerup("auto_merge")
		and payments.is_empty(), "automatic merging cannot charge for a board without an exact dictionary pair")
	check(model.can_activate_powerup("fragments"), "fragment delivery remains available without a possible word")
	check(not model.activate_powerup("unknown") and not model.can_activate_powerup("unknown")
		and payments.is_empty(), "an unknown power cannot make a wallet request")
	model.purchase_powerup = Callable()
	model = _model()
	model.configure([_word("cat", 3), _word("rocket", 6), _word("advanced", 12)], 6, 42)
	_board(model, ["cat", "picture:cat", "advanced", "picture:advanced"])
	payments = _accept_powerup_payments(model)
	check(not model.activate_powerup("auto_merge") and payments.is_empty(),
		"automatic merging excludes both younger and older words from its paid eligibility search")
	model.purchase_powerup = Callable()


func _test_powerup_payment_atomicity() -> void:
	for kind: String in ["auto_merge", "fragments"]:
		var model = _powerup_model(kind)
		var before: Dictionary = model.snapshot()
		check(not model.activate_powerup(kind) and not model.powerup_active() and model.snapshot() == before,
			"a missing purchase adapter cannot provide a free " + kind + " power")
		for response: Dictionary in [{"ok": false}, {"ok": true, "duplicate": true}]:
			model = _powerup_model(kind)
			var calls: Array = []
			var events: Dictionary = _observe_powerups(model)
			var regular_events: Dictionary = _observe(model)
			before = model.snapshot()
			var rng_state: int = model._rng.state
			model.purchase_powerup = func(receipt_id: String, requested: String, price: int) -> Dictionary:
				calls.append([receipt_id, requested, price])
				check(model.cells == before.cells and not model.powerup_snapshot().active,
					"the wallet is called before any paid animation or effect is committed")
				return response.duplicate(true)
			check(not model.activate_powerup(kind) and not model.powerup_active(),
				"failed and duplicate purchases do not begin a power")
			check(calls.size() == 1 and not str(calls[0][0]).is_empty()
				and calls[0][1] == kind and calls[0][2] == Model.POWERUP_PRICES[kind],
				"purchase persistence receives one receipt, the requested power, and its exact price")
			check(model.cells == before.cells and model.upcoming == before.upcoming
				and model._rng.state == rng_state
				and model.collected_coins == 0 and model.fragment_count == 0,
				"failed or duplicate payment changes no pieces, fragments, rewards, supply, or random draw")
			check(events.drags.is_empty() and events.arrivals.is_empty()
				and regular_events.completed.is_empty() and regular_events.collections.is_empty(),
				"failed payment has no merge, fragment, collection, or completion presentation")
			model.purchase_powerup = Callable()
		model = _powerup_model(kind)
		var payments: Array = _accept_powerup_payments(model)
		var events: Dictionary = _observe_powerups(model)
		check(model.activate_powerup(kind), "a new successfully persisted power activates")
		var receipt: String = str(model.powerup_snapshot().receipt_id)
		check(payments.size() == 1 and receipt == payments[0].id and events.feedback == [[kind, true]],
			"an accepted power exposes its persisted receipt and one success response")
		model.finish_powerup(true)
		if kind == "auto_merge":
			_board(model, ["cat", "picture:cat"])
		check(model.activate_powerup(kind) and payments.size() == 2 and payments[1].id != receipt,
			"separate accepted activations receive distinct wallet receipts")
		model.finish_powerup(true)
		model.purchase_powerup = Callable()


func _test_powerup_price_progression() -> void:
	for kind: String in ["auto_merge", "fragments"]:
		var model = _model([_word("cat")])
		var other: String = "fragments" if kind == "auto_merge" else "auto_merge"
		var prices: Array = [600, 900, 1200, 1200] if kind == "auto_merge" else [200, 300, 400, 400]
		for index in range(prices.size()):
			_board(model, ["cat", "picture:cat"])
			var expected: int = prices[index]
			check(model.powerup_price(kind) == expected and model.snapshot().powerup_prices[kind] == expected,
				"each successful-use tier exposes the exact next " + kind + " price")
			for response: Dictionary in [{"ok": false, "reason": "insufficient"}, {"ok": false, "reason": "storage"}, {"ok": true, "duplicate": true}]:
				model.purchase_powerup = func(_receipt_id: String, _requested: String, _price: int) -> Dictionary:
					return response.duplicate()
				check(not model.activate_powerup(kind) and model.powerup_price(kind) == expected
					and model.snapshot().powerup_uses[kind] == index,
					"insufficient, unsaved, and duplicate purchases cannot advance a price tier")
			var payments: Array = _accept_powerup_payments(model)
			check(model.activate_powerup(kind) and payments.size() == 1 and payments[0].price == expected,
				"a successful purchase pays its quoted current price")
			check(model.snapshot().powerup_uses[kind] == index + 1
				and model.powerup_price(kind) == prices[mini(index + 1, prices.size() - 1)]
				and model.powerup_price(other) == Model.POWERUP_PRICES[other],
				"payment advances only its own price and caps repeat-use cost")
			if kind == "auto_merge":
				check(not model.activate_powerup(kind) and payments.size() == 1,
					"an active automatic merge cannot spend or escalate again")
			else:
				check(model.can_activate_powerup(kind), "Treasure remains purchasable during its delivery animation")
			model.finish_powerup(true)
			model.set_paused(true)
			model.set_paused(false)
			check(model.snapshot().powerup_uses[kind] == index + 1,
				"pausing or completing the animation preserves the successful-use count")
		check(model.configure([_word("cat")], 3, 42) and model.powerup_price(kind) == prices[0]
			and model.snapshot().powerup_uses == {"auto_merge": 0, "fragments": 0},
			"only a new round resets both powerup prices to their first-use tier")
		model.purchase_powerup = Callable()
	check(Model.coins_for_tile({"mass": 40}) == 0 and Model.coin_drop_chance_for_tile({"mass": 40}) == 0.0,
		"mass without an eligible merged level cannot earn a collection bonus")


func _test_powerup_auto_timeline() -> void:
	var model = _model([_word("cat")])
	_board(model, ["picture:cat", "cat"], [2, 3])
	var payments: Array = _accept_powerup_payments(model)
	var events: Dictionary = _observe_powerups(model)
	var regular_events: Dictionary = _observe(model)
	check(model.activate_powerup("auto_merge"), "Automatic merging accepts the picture before its matching root")
	var active: Dictionary = model.powerup_snapshot()
	check(active.active and active.kind == "auto_merge" and active.stage == "drag"
		and active.source_id == 1000 and active.target_id == 1001,
		"The paid sequence starts with a visible picture-to-root drag")
	check(active.source.text == "cat" and active.target.text == "cat" and events.drags.size() == 1,
		"the drag exposes both intact endpoint bodies for its presentation")
	active.source.text = "changed snapshot"
	active.target.fragments = 999
	active.drags[0].source.text = "changed nested snapshot"
	active.drags[0].target.fragments = 888
	check(model.powerup_snapshot().source.text == "cat" and model.powerup_snapshot().drags[0].source.text == "cat"
		and model.cell(1000).fragments == 2,
		"presentation snapshots cannot mutate the captured power or live bodies")
	check(is_equal_approx(Model.POWERUP_DRAG_SECONDS, 0.25), "each automatic drag uses the complete 250 ms transfer")
	check(is_equal_approx(Model.POWERUP_MERGE_BEAT_SECONDS, 0.20), "Automatic launches follow the requested 200 ms beat")
	model.step(Model.POWERUP_DRAG_SECONDS - 0.001)
	check(model.powerup_snapshot().stage == "drag" and model.fusions.is_empty() and model.cells.size() == 2,
		"both bodies remain separate for the complete transfer before its final millisecond")
	model.step(0.001)
	check(model.powerup_snapshot().stage == "fusion" and model.fusions.size() == 1
		and model.fusions[0].a_id == 1000 and model.fusions[0].b_id == 1001,
		"250 ms starts the automatic fusion using the advertised ordered endpoints")
	model.step(Model.POWERUP_FUSION_SECONDS - 0.001)
	check(model.cells.size() == 2 and model.powerup_active(), "paid fusion keeps its complete 110 ms presentation")
	model.step(0.001)
	check(model.cells.size() == 1 and model.cells[0].text == "cat" and model.cells[0].fragments == 5
		and model.powerup_snapshot().stage == "settling" and not model.is_settled(model.cells[0]),
		"fusion hands over a pictured persistent word with all carried fragments")
	model.step(Model.POWERUP_SETTLE_SECONDS - 0.001)
	check(model.powerup_active(), "the paid sequence reserves the result until its short landing finishes")
	model.step(0.001)
	check(not model.powerup_active() and model.is_settled(model.cells[0]) and payments.size() == 1,
		"the one-pair purchase ends precisely after drag, fusion, and settlement")
	check(model.collected_coins == 0 and model.fragment_count == 0 and model.cleared_pairs == 0
		and regular_events.collections.is_empty() and regular_events.attempts.is_empty()
		and regular_events.cues.count("pop") == 0,
		"automatic fusion neither collects words nor grants coins, chest progress, or learning credit")
	model.purchase_powerup = Callable()


func _test_powerup_auto_rhythm() -> void:
	var model = _model([_word("cat"), _word("dog"), _word("sun")])
	_board(model, ["cat", "picture:cat", "dog", "picture:dog", "sun", "picture:sun"], [1, 2, 3, 4, 5, 6])
	for index in range(model.cells.size()):
		model.cells[index].column = int(index / 2) * 2
		model.cells[index].row = Model.ROWS - 2 + index % 2
	var payments: Array = _accept_powerup_payments(model)
	var events: Dictionary = _observe_powerups(model)
	var regular_events: Dictionary = _observe(model)
	check(model.activate_powerup("auto_merge"), "One saved purchase starts the first complete hybrid path")
	model.step(Model.POWERUP_MERGE_BEAT_SECONDS - 0.001)
	check(events.drags.size() == 1 and model.powerup_snapshot().drags.size() == 1,
		"Auto keeps the next independent flight pending until its 200 ms launch boundary")
	model.step(0.001)
	var overlapping: Dictionary = model.powerup_snapshot()
	check(events.drags.size() == 2 and overlapping.drags.size() == 2 and model.fusions.is_empty(),
		"the second independent flight starts at 200 ms while the first is still traveling")
	if overlapping.drags.size() == 2:
		check(is_equal_approx(float(overlapping.drags[0].elapsed), 0.20)
			and is_zero_approx(float(overlapping.drags[1].elapsed)),
			"overlapping flights retain independent elapsed times")
	for frame in range(600):
		model.step(0.01)
		var active_drags: Array = model.powerup_snapshot().drags
		check(model.fusions.size() <= 1 and active_drags.size() <= 2,
			"the 200 ms beat allows two 250 ms flights while keeping each fusion independent")
		var reserved_ids: Array[int] = []
		for drag: Dictionary in active_drags:
			for id: int in [int(drag.source_id), int(drag.target_id)]:
				check(not reserved_ids.has(id), "overlapping flights never reserve the same endpoint")
				reserved_ids.append(id)
		for fusion: Dictionary in model.fusions:
			for id: int in [int(fusion.a_id), int(fusion.b_id)]:
				check(not reserved_ids.has(id), "a fusion endpoint cannot be reused by a live flight")
				reserved_ids.append(id)
		_assert_reservations(model, "overlapping hybrid Auto")
	check(events.drags.size() == 3 and payments.size() == 1 and model.collectable_ids().size() == 3
		and not model.powerup_active(), "One purchase settles all three independent picture matches")
	for index in range(events.drags.size()):
		var drag: Dictionary = events.drags[index]
		check(model.parts_compatible(drag.source, drag.target), "Every Auto launch is a valid whole-word picture pair")
		check(model.is_settled(drag.source) and model.is_settled(drag.target),
			"each launch captures settled endpoints before reserving them for its flight")
		check(is_equal_approx(float(drag.started_at), index * 0.20)
			and is_equal_approx(float(drag.duration), 0.25),
			"the three independent flights start at 0, 200 and 400 ms and each lasts 250 ms")
	check(_board_fragments(model) == 21 and regular_events.attempts.is_empty() and regular_events.collections.is_empty(),
		"Automatic picture matching conserves every fragment without collecting or claiming mastery")
	_assert_board(model, "overlapping automatic final board")
	model.purchase_powerup = Callable()

func _test_powerup_auto_random_sources() -> void:
	for seed_value in range(1, 17):
		var models: Array = [_model([_word("cat"), _word("dog"), _word("sun")]),
			_model([_word("cat"), _word("dog"), _word("sun")])]
		var orders: Array = []
		for copy_index in range(models.size()):
			var model = models[copy_index]
			_board(model, ["cat", "picture:cat", "dog", "picture:dog", "sun", "picture:sun"])
			for index in range(model.cells.size()):
				model.cells[index].column = int(index / 2) * 2
				model.cells[index].row = Model.ROWS - 2 + index % 2
			model._rng.seed = seed_value
			_accept_powerup_payments(model)
			var events: Dictionary = _observe_powerups(model)
			var rng_before: int = model._rng.state
			for query in range(8):
				check(model.can_activate_powerup("auto_merge"), "Repeated availability reads find a complete hybrid path")
			check(model._rng.state == rng_before, "Preflight never consumes the supply RNG")
			check(model.activate_powerup("auto_merge"), "A preflighted path accepts its purchase")
			if copy_index == 0:
				model.step(6.0)
			else:
				for frame in range(600):
					model.step(0.01)
			var order: Array[int] = []
			for drag: Dictionary in events.drags:
				order.append(int(drag.source_id))
				check(model.parts_compatible(drag.source, drag.target), "Every planned launch remains semantically valid")
			check(order.size() == 3 and model.collectable_ids().size() == 3 and not model.powerup_active(),
				"The deterministic path exhausts all three whole-word picture pairs")
			orders.append(order)
			model.purchase_powerup = Callable()
		check(orders[0] == orders[1] and _approximately_equal_state(_rejection_state(models[0]), _rejection_state(models[1])),
			"Coarse and fine frames reproduce the same hybrid source path and final state")

func _test_powerup_auto_completion_during_drag() -> void:
	var model = _model([_word("cat")])
	var pieces: Array[String] = []
	for index in range(24):
		pieces.append("cat" if index % 2 == 0 else "picture:cat")
	_board(model, pieces)
	var payments: Array = _accept_powerup_payments(model)
	var events: Dictionary = _observe_powerups(model)
	check(model.activate_powerup("auto_merge"), "A larger board starts one paid hybrid stream")
	model.step(Model.POWERUP_DRAG_SECONDS + Model.POWERUP_FUSION_SECONDS - 0.01)
	check(events.drags.size() == 2 and model.powerup_snapshot().drags.size() == 1 and model.fusions.size() == 1,
		"the first fusion keeps its endpoints reserved while the next independent flight continues")
	var first_result_id: int = int(model.fusions[0].result.id)
	model.step(0.02)
	check(model.merged_count == 1 and model.powerup_snapshot().drags.size() == 1
		and not model.is_settled(model.cell(first_result_id)),
		"a completed fusion settles while the next flight continues on its independent clock")
	for drag: Dictionary in events.drags:
		check(model.is_settled(drag.source) and model.is_settled(drag.target)
			and int(drag.source_id) != first_result_id and int(drag.target_id) != first_result_id,
			"no launch can reuse the new result before its landing settles")
	model.finish_powerup(true)
	check(not model.powerup_active() and model.collectable_ids().size() == 1 and payments.size() == 1,
		"The paid stream completes picture matches and additive upgrades without another payment")
	var represented_levels: int = 0
	for tile: Dictionary in model.cells:
		represented_levels += int(tile.merge_level)
		check(int(tile.merge_level) <= Model.MAX_MERGE_LEVEL, "Automatic upgrades never exceed Lv9")
	check(represented_levels == 9 and int(model.cells[0].mass) == 24
		and model.merged_count == 24 - model.cells.size() and model.collected_coins == 0
		and model.compatible_pairs().is_empty(),
		"The exhausted stream preserves all source mass in a single capped Lv9 word")
	_assert_board(model, "automatic picture-and-level stream")
	model.purchase_powerup = Callable()

func _test_powerup_auto_chain() -> void:
	var model = _powerup_model("auto_merge")
	var payments: Array = _accept_powerup_payments(model)
	var events: Dictionary = _observe_powerups(model)
	var regular_events: Dictionary = _observe(model)
	var generated: int = model.generated_tiles
	check(model.activate_powerup("auto_merge"), "a chain of complementary pairs accepts one purchase")
	model.step(6.0)
	check(not model.powerup_active() and model.merged_count == 3 and model.cells.size() == 3,
		"automatic merging recomputes pairs after each result and resolves both independent and chained words")
	var words: Dictionary = {}
	for tile: Dictionary in model.cells:
		words[str(tile.text)] = tile
	check(words.has("cat") and words.has("dog") and words.has("x")
		and words.cat.mass == 4 and words.cat.merge_level == 2 and words.cat.fragments == 6 and words.dog.fragments == 9,
		"the new cat result can upgrade with another Lv1 cat while unrelated pieces and all fragments are preserved")
	check(payments.size() == 1 and events.drags.size() == 3 and regular_events.completed.size() == 3,
		"one purchase owns the entire recomputed merge sequence with one presentation per pair")
	for index in range(events.drags.size()):
		var drag: Dictionary = events.drags[index]
		check(model.is_settled(drag.source) and model.is_settled(drag.target)
			and is_equal_approx(float(drag.started_at), index * 0.20),
			"independent matches and the dependent level upgrade launch on the 200 ms grid with settled endpoints")
	check(model.generated_tiles == generated and model.collected_coins == 0 and model.fragment_count == 0
		and regular_events.collections.is_empty(), "automatic merging consumes only captured board pieces and never collects them")
	_assert_board(model, "paid automatic chain")
	check(not model.can_activate_powerup("auto_merge") and not model.activate_powerup("auto_merge")
		and payments.size() == 1, "a completed exhausted chain cannot charge again without a new valid pair")
	check(model.collect(int(words.cat.id)), "the automatically built word still needs an ordinary collection")
	model.step(Model.COLLECT_SECONDS)
	check(model.collected_coins == 50 and model.fragment_count == 6,
		"manual collection of the automatic Lv2 result retains its bonus and carried fragments")
	model.purchase_powerup = Callable()


func _test_powerup_auto_interleaved_authored_paths() -> void:
	var authored_words: Array = []
	for parts: Array in [["rain", "bow"], ["sun", "flower"]]:
		var spelling: String = str(parts[0]) + str(parts[1])
		var word: Dictionary = _word(spelling)
		word.morphology = {"schema": 1, "id": "fixture:" + spelling, "lexeme_id": spelling,
			"text": spelling, "kind": "morphological",
			"review": {"status": "reviewed", "reviewer": "automated-test-fixture"},
			"parts": [{"id": "left", "canonical_id": "fixture:" + str(parts[0]), "type": "root",
				"canonical": parts[0], "surface": parts[0]},
				{"id": "right", "canonical_id": "fixture:" + str(parts[1]), "type": "root",
				"canonical": parts[1], "surface": parts[1]}],
			"nodes": [{"id": "whole", "left": "left", "right": "right", "surface": spelling,
				"rule": "test_authored_join", "break_offsets": [str(parts[0]).length()]}], "roots": ["whole"]}
		authored_words.append(word)
	var model = _model(authored_words)
	model.cells.clear()
	var pictures: Dictionary = {}
	for word: Dictionary in authored_words:
		for state: Dictionary in model._morphology.source_tiles(str(word.morphology.id)):
			state.fragments = 1
			model.cells.append(model._new_composition_tile(state))
		var picture: Dictionary = model._new_picture_tile(word, 1)
		pictures[str(word.id)] = int(picture.id)
		model.cells.append(picture)
	for state: Dictionary in model._morphology.source_tiles(str(authored_words[0].morphology.id)):
		state.fragments = 1
		model.cells.append(model._new_composition_tile(state))
	for index in range(model.cells.size()):
		model.cells[index].column = index % Model.COLUMNS
		model.cells[index].row = Model.ROWS - 1 - int(index / Model.COLUMNS)
		model.cells[index].age = Model.SETTLE_SECONDS
		model.cells[index].settling = false
	var payments: Array = _accept_powerup_payments(model)
	var events: Dictionary = _observe_powerups(model)
	var regular_events: Dictionary = _observe(model)
	check(model.activate_powerup("auto_merge") and events.drags.size() == 1,
		"two authored pictured paths accept one purchase with a competing duplicate root pair")
	if events.drags.is_empty():
		model.purchase_powerup = Callable()
		return
	var first_word: String = str(events.drags[0].source.text) + str(events.drags[0].target.text)
	check(pictures.has(first_word) and model._reserved_for_powerup(int(pictures.get(first_word, -1))),
		"the first authored path reserves its future picture before the spelling has reached contact")
	model.step(0.20)
	check(events.drags.size() == 2 and model.powerup_snapshot().drags.size() == 2,
		"an independent authored spelling begins at 200 ms before the first spelling finishes")
	var spellings: Array[String] = []
	for drag: Dictionary in events.drags:
		spellings.append(str(drag.source.text) + str(drag.target.text))
	spellings.sort()
	check(spellings == ["rainbow", "sunflower"],
		"a competing root pair cannot start another path using the already reserved picture")
	model.step(0.19)
	check(events.drags.size() == 2 and regular_events.completed.size() == 1,
		"the first spelling can finish landing at 390 ms without launching its dependent step early")
	model.step(0.01)
	model.step(0.20)
	check(events.drags.size() == 4 and regular_events.completed.size() == 2,
		"both authored paths launch their own picture match on the 400 and 600 ms beats")
	if events.drags.size() == 4 and regular_events.completed.size() == 2:
		for index in range(4):
			var drag: Dictionary = events.drags[index]
			check(is_equal_approx(float(drag.started_at), index * 0.20)
				and model.is_settled(drag.source) and model.is_settled(drag.target),
				"interleaved authored steps stay on the launch grid and never reuse an unsettled result")
		for index in range(2):
			var drag: Dictionary = events.drags[index + 2]
			var result: Dictionary = regular_events.completed[index].payload.result
			check(int(drag.source_id) == int(result.id)
				and int(drag.target_id) == int(pictures[str(result.text)]),
				"each dependent picture match uses its own path's completed spelling and reserved picture")
	model.step(1.0)
	check(not model.powerup_active() and events.drags.size() == 4 and model.merged_count == 4
		and model.collectable_ids().size() == 2 and model.cells.size() == 4 and payments.size() == 1,
		"interleaved authored paths finish once and leave the competing incomplete roots untouched")
	check(_board_fragments(model) == 8 and model.collected_coins == 0 and model.fragment_count == 0
		and regular_events.collections.is_empty() and regular_events.attempts.is_empty(),
		"overlapping authored paths preserve carried fragments without collecting or granting mastery")
	_assert_board(model, "interleaved authored automatic paths")
	model.purchase_powerup = Callable()


func _test_powerup_manual_guards() -> void:
	for kind: String in ["auto_merge", "fragments"]:
		var model = _model([_word("cat")])
		var root_tile: Dictionary = _placed_tile(1003, "x", 4, 7)
		model.cells.assign([_placed_tile(1000, "cat", 0, 7), _placed_tile(1001, "picture:cat", 1, 7),
			_placed_tile(1002, "cat", 2, 7, 2, 0, _word("cat")), root_tile])
		var payments: Array = _accept_powerup_payments(model)
		check(model.activate_powerup(kind), "stable mixed board can start the paid power")
		var before: Dictionary = model.snapshot()
		var held_before: int = model._held_tile_id
		check(model.try_merge(1000, 1001) == "ignored" and not model.collect(1002)
			and not model.start_collection_batch(),
			"paid sequencing blocks manual merge, collection, and collect-all")
		check(not model.can_reposition(1000, 0, 6) and not model.reposition(1000, 0, 6)
			and not model.can_drop_now() and not model.drop_now(), "paid sequencing blocks reposition and supply input")
		var lift_candidate: int = held_before if held_before >= 0 else 1000
		check(not model.begin_drag(lift_candidate) and not model.is_lifted(lift_candidate),
			"paid automatic motion cannot detach a manually requested source from its support footprint")
		model.set_held_tile(1000)
		check(model._held_tile_id == held_before and not model.can_activate_powerup("auto_merge")
			and not model.activate_powerup("auto_merge") and payments.size() == 1,
			"paid sequencing prevents held input and overlapping automatic merge purchases")
		if kind == "auto_merge":
			check(not model.can_activate_powerup("fragments") and not model.activate_powerup("fragments")
				and payments.size() == 1, "Auto merge retains exclusive use of the board")
		else:
			check(model.can_activate_powerup("fragments"), "Another Treasure purchase can join the reserved delivery sequence")
		check(model.snapshot() == before, "blocked manual actions do not mutate a reserved paid sequence")
		model.finish_powerup(true)
		model.purchase_powerup = Callable()


func _test_powerup_fragment_timeline() -> void:
	var model = _powerup_model("fragments")
	var payments: Array = _accept_powerup_payments(model)
	var events: Dictionary = _observe_powerups(model)
	var regular_events: Dictionary = _observe(model)
	var original: int = _board_fragments(model)
	check(model.activate_powerup("fragments"), "fragment delivery accepts a stable occupied board")
	var active: Dictionary = model.powerup_snapshot()
	var total: int = int(active.total)
	check(active.stage == "arrivals" and total >= 2 and total <= 8 and active.arrivals.size() == total,
		"one fragment purchase reserves a random two-to-eight arrival sequence")
	check(_board_fragments(model) == original and events.arrivals.is_empty(),
		"payment reserves fragment destinations without applying them before arrival")
	var reserved_ids: Array[int] = []
	for index in range(total):
		var arrival: Dictionary = active.arrivals[index]
		check(is_equal_approx(float(arrival.at), 0.42 + index * 0.18) and not arrival.arrived,
			"fragment arrivals have a 420 ms lead-in followed by 180 ms beats")
		if index < 4:
			check(int(arrival.tile_id) in [1000, 1001, 1002, 1003] and int(arrival.tile_id) not in reserved_ids,
				"fragment-free bodies are selected before adding more fragments to an already marked body")
		reserved_ids.append(int(arrival.tile_id))
	check(is_equal_approx(float(active.duration), 0.42 + (total - 1) * 0.18 + 0.35),
		"the fragment sequence includes the final 350 ms impact recovery")
	var elapsed: float = 0.0
	for index in range(total):
		var deadline: float = 0.42 + index * 0.18
		model.step(deadline - elapsed - 0.001)
		check(events.arrivals.size() == index and _board_fragments(model) == original + index,
			"fragment application waits for its exact arrival deadline")
		model.step(0.001)
		elapsed = deadline
		check(events.arrivals.size() == index + 1 and _board_fragments(model) == original + index + 1,
			"one fragment applies atomically at each staggered arrival")
		var payload: Dictionary = events.arrivals[index]
		var target: Dictionary = model.cell(int(payload.tile_id))
		check(payload.tile_id == reserved_ids[index] and int(payload.total) == total
			and int(payload.fragments) == int(target.fragments) and bool(target.chest)
			and str(payload.receipt_id) == str(payments[0].id),
			"arrival presentation identifies the reserved target, persisted purchase, and updated fragment count")
	model.step(0.349)
	check(model.powerup_active(), "fragment impact recovery remains reserved until its last millisecond")
	model.step(0.001)
	check(not model.powerup_active() and payments.size() == 1 and _board_fragments(model) == original + total,
		"all purchased fragments apply once and the sequence ends after recovery")
	check(model.fragment_count == 0 and model.collected_coins == 0 and model.chest_tier == 0
		and regular_events.collections.is_empty() and regular_events.milestones.is_empty(),
		"delivered fragments remain on jellies until collection and do not immediately unlock a chest")
	model.purchase_powerup = Callable()


func _test_powerup_fragment_launch_rhythm() -> void:
	var observations: Array[Array] = []
	for coarse: bool in [true, false]:
		var model = _powerup_model("fragments")
		_accept_powerup_payments(model)
		var events: Array[Dictionary] = []
		var observe_cue: Callable = func(cue: String) -> void:
			if cue in ["powerup_fragment_launch", "powerup_fragment"]:
				var state: Dictionary = model.powerup_snapshot()
				events.append({"cue": cue, "at": float(state.elapsed)})
		model.cue_requested.connect(observe_cue)
		check(model.activate_powerup("fragments") and events.size() == 1
			and events[0].cue == "powerup_fragment_launch" and is_zero_approx(float(events[0].at)),
			"the first fragment appearance cue fires at purchase time without waiting for a frame")
		var active: Dictionary = model.powerup_snapshot()
		var total: int = int(active.total)
		check(bool(active.arrivals[0].launched) and not bool(active.arrivals[0].arrived)
			and active.arrivals.filter(func(item: Dictionary) -> bool: return bool(item.launched)).size() == 1,
			"an audible first launch marks only its own visible flight and grants no fragment early")
		if coarse:
			model.step(5.0)
		else:
			for frame in range(500):
				model.step(0.01)
		var launches: Array = events.filter(func(event: Dictionary) -> bool: return event.cue == "powerup_fragment_launch")
		var arrivals: Array = events.filter(func(event: Dictionary) -> bool: return event.cue == "powerup_fragment")
		check(not model.powerup_active() and launches.size() == total and arrivals.size() == total,
			"every visible Treasure fragment has one appearance cue and one destination cue")
		for index in range(total):
			check(is_equal_approx(float(launches[index].at), index * Model.POWERUP_FRAGMENT_STAGGER)
				and is_equal_approx(float(arrivals[index].at) - float(launches[index].at), Model.POWERUP_FRAGMENT_FLIGHT),
				"each staggered appearance precedes its matching destination by the full flight duration")
		var previous: float = -1.0
		for event: Dictionary in events:
			check(float(event.at) + Model.EPSILON >= previous,
				"coarse stepping dispatches fragment launch and arrival sounds in chronological order")
			previous = float(event.at)
		var completed: Dictionary = model.powerup_snapshot()
		check(completed.arrivals.all(func(item: Dictionary) -> bool: return bool(item.launched) and bool(item.arrived)),
			"completed delivery keeps both phases committed so later stepping cannot replay them")
		var count: int = events.size()
		model.step(1.0)
		check(events.size() == count, "finished fragment sounds never replay on later frames")
		observations.append(events)
		model.cue_requested.disconnect(observe_cue)
		model.purchase_powerup = Callable()
	check(_approximately_equal_state(observations[0], observations[1]),
		"coarse and fine frames have identical fragment appearance and destination cue timing")


func _test_powerup_fragment_launch_reentry() -> void:
	for launch_number: int in [1, 2]:
		for action: String in ["pause", "drain", "finish", "configure", "advance"]:
			var model = _powerup_model("fragments")
			var payments: Array = _accept_powerup_payments(model)
			var original: int = _board_fragments(model)
			var observed: Dictionary = {"launches": 0, "arrivals": 0, "handled": false, "total": 0, "replacement": {}}
			var observe_cue: Callable = func(cue: String) -> void:
				if cue == "powerup_fragment":
					observed.arrivals += 1
				if cue != "powerup_fragment_launch":
					return
				observed.launches += 1
				if observed.handled or int(observed.launches) != launch_number:
					return
				observed.handled = true
				var state: Dictionary = model.powerup_snapshot()
				observed.total = int(state.total)
				check(bool(state.arrivals[launch_number - 1].launched)
					and not bool(state.arrivals[launch_number - 1].arrived),
					"the launch flag is committed before a sound callback can reenter the delivery")
				if action == "pause":
					model.set_paused(true)
				elif action == "drain":
					model.finish_powerup(true)
				elif action == "finish":
					model.finish_round()
				elif action == "configure":
					check(model.configure([_word("sunflower")], 3, 9),
						"a launch callback can replace the round after silently fulfilling the paid delivery")
					observed.replacement = model.snapshot()
				else:
					model.step(4.0)
			model.cue_requested.connect(observe_cue)
			check(model.activate_powerup("fragments"), "a paid delivery permits a reentrant appearance callback")
			if launch_number > 1:
				model.step(Model.POWERUP_FRAGMENT_STAGGER)
			check(bool(observed.handled) and payments.size() == 1,
				"both immediate and later appearance callbacks run once against the accepted purchase")
			if action == "pause":
				var paused_state: Dictionary = model.snapshot()
				var paused_cues: Array[int] = [int(observed.launches), int(observed.arrivals)]
				model.step(5.0)
				check(model.paused and model.snapshot() == paused_state
					and [int(observed.launches), int(observed.arrivals)] == paused_cues,
					"pausing at fragment appearance freezes the board and both sound phases")
				model.set_paused(false)
				model.step(5.0)
			if action == "configure":
				check(model.snapshot() == observed.replacement and model.phase == "playing"
					and not model.powerup_active() and int(observed.launches) == launch_number and int(observed.arrivals) == 0,
					"round replacement cancels every stale launch, arrival, and remaining frame of the old delivery")
			else:
				check(not model.powerup_active() and _board_fragments(model) == original + int(observed.total)
					and model.powerup_snapshot().completed == observed.total,
					"appearance callback interruption preserves every purchased fragment exactly once")
				if action in ["pause", "advance"]:
					check(int(observed.launches) == int(observed.total) and int(observed.arrivals) == int(observed.total),
						"resumed and reentrant advancement never repeats or skips a fragment's two sound phases")
				else:
					check(int(observed.launches) == launch_number and int(observed.arrivals) == 0,
						"silent settlement drains the accepted delivery without catch-up appearance or arrival sounds")
				check(model.phase == ("finished" if action == "finish" else "playing"),
					"appearance callback lifecycle changes preserve the requested round state")
			model.cue_requested.disconnect(observe_cue)
			model.purchase_powerup = Callable()


func _test_powerup_fragment_repeats() -> void:
	var model = _powerup_model("fragments")
	var payments: Array = _accept_powerup_payments(model)
	var events: Dictionary = _observe_powerups(model)
	var cues: Array[String] = []
	model.cue_requested.connect(func(cue: String) -> void: cues.append(cue))
	model.powerup_feedback.connect(func(_kind: String, success: bool) -> void:
		if success:
			check(not model.activate_powerup("fragments") and not model.activate_powerup("auto_merge"),
				"purchase feedback cannot recursively create another debit"))
	var original: int = _board_fragments(model)
	var starts: Array[float] = [0.0, 0.10, 0.19]
	var prices: Array[int] = [200, 300, 400]
	var totals: Array[int] = []
	var prior: Dictionary = {}
	var timeline_id: String = ""
	for purchase in range(starts.size()):
		if purchase > 0:
			model.step(starts[purchase] - starts[purchase - 1])
			prior = model.powerup_snapshot()
		check(model.can_activate_powerup("fragments") and model.activate_powerup("fragments"),
			"Treasure can be purchased again before any earlier fragment arrives")
		var state: Dictionary = model.powerup_snapshot()
		if purchase == 0:
			timeline_id = str(state.receipt_id)
		check(is_equal_approx(float(state.elapsed), starts[purchase]) and str(state.receipt_id) == timeline_id,
			"a repeat purchase preserves the original delivery clock and timeline identity")
		check(payments.size() == purchase + 1 and int(payments[purchase].price) == prices[purchase],
			"each rapid click pays its current quoted price exactly once")
		var bought: Array = state.arrivals.filter(func(item: Dictionary) -> bool:
			return str(item.receipt_id) == str(payments[purchase].id))
		check(bought.size() >= 2 and bought.size() <= 8, "each independent receipt reserves its own two-to-eight fragments")
		totals.append(bought.size())
		for index in range(bought.size()):
			check(is_equal_approx(float(bought[index].at), starts[purchase] + 0.42 + index * 0.18)
				and int(bought[index].total) == bought.size(),
				"each added purchase starts its own full flight and stagger without waiting for earlier tails")
		if purchase > 0:
			check(state.arrivals.slice(0, prior.arrivals.size()) == prior.arrivals,
				"new Treasure purchases preserve all existing destinations, deadlines, and arrival states")
		check(not model.can_activate_powerup("auto_merge") and not model.activate_powerup("auto_merge"),
			"automatic merging stays unavailable while any purchased fragments are in flight")
	var active: Dictionary = model.powerup_snapshot()
	check(_board_fragments(model) == original and events.arrivals.is_empty(),
		"three rapid payments never grant fragments before their visible arrival")
	var reserved_ids: Array[int] = []
	for arrival: Dictionary in active.arrivals.slice(0, 4):
		reserved_ids.append(int(arrival.tile_id))
	check(reserved_ids.size() == 4 and reserved_ids.has(1000) and reserved_ids.has(1001)
		and reserved_ids.has(1002) and reserved_ids.has(1003),
		"later purchases include earlier pending markers when preferring unmarked jelly bodies")
	model.set_paused(true)
	model.step(4.0)
	check(model.powerup_snapshot() == active and not model.can_activate_powerup("fragments"),
		"pause freezes every overlapping delivery and prevents purchases")
	model.set_paused(false)
	model.step(0.50)
	var running: Dictionary = model.powerup_snapshot()
	var expected: Array = running.arrivals.filter(func(item: Dictionary) -> bool:
		return float(item.at) <= float(running.elapsed) + Model.EPSILON)
	check(events.arrivals.size() == expected.size() and _board_fragments(model) == original + expected.size(),
		"coarse frames cross every interleaved receipt deadline without delaying newly appended flights")
	var previous_at: float = -1.0
	for event: Dictionary in events.arrivals:
		var scheduled: Dictionary = active.arrivals[int(event.index)]
		check(float(event.at) + Model.EPSILON >= previous_at and is_equal_approx(float(event.at), float(scheduled.at))
			and str(event.receipt_id) == str(scheduled.receipt_id) and str(event.timeline_id) == timeline_id
			and int(event.total) == int(scheduled.total),
			"overlapping arrivals emit in time order with their own receipt and exact presentation deadline")
		previous_at = float(event.at)
	model.step(5.0)
	var total: int = totals.reduce(func(sum: int, value: int) -> int: return sum + value, 0)
	check(not model.powerup_active() and _board_fragments(model) == original + total
		and events.arrivals.size() == total and cues.count("powerup_fragment") == total
		and cues.count("powerup_fragment_launch") == total
		and cues.count("powerup_success") == 3 and payments.size() == 3,
		"every repeated purchase finishes once with its own feedback and one launch and arrival cue per fragment")
	check(model.powerup_snapshot().completed == total and model.powerup_snapshot().total == total
		and model.powerup_price("fragments") == 400 and model.fragment_count == 0 and model.chest_count == 0,
		"combined delivery totals are conserved without collecting fragments or changing capped pricing")
	model.purchase_powerup = Callable()


func _test_powerup_fragment_changed_reentry() -> void:
	var model = _powerup_model("fragments")
	var payments: Array = _accept_powerup_payments(model)
	for purchase in range(2):
		var attempted: Dictionary = {"value": false}
		model.changed.connect(func() -> void:
			if attempted.value:
				return
			attempted.value = true
			check(model.can_activate_powerup("fragments"),
				"the final purchase notification exposes an immediately available Treasure button")
			check(not model.activate_powerup("fragments"),
				"a synchronous final change callback cannot recursively create another paid delivery"), CONNECT_ONE_SHOT)
		check(model.activate_powerup("fragments") and attempted.value and payments.size() == purchase + 1,
			"each outer click completes one charge even when its final notification tries to purchase again")
		check(model.can_activate_powerup("fragments"),
			"the next independent click remains eligible after the guarded notification returns")
	model.finish_powerup(true)
	model.purchase_powerup = Callable()


func _test_powerup_fragment_repeat_failure() -> void:
	var model = _powerup_model("fragments")
	var payments: Array = _accept_powerup_payments(model)
	var events: Dictionary = _observe_powerups(model)
	var cues: Array[String] = []
	model.cue_requested.connect(func(cue: String) -> void: cues.append(cue))
	var original: int = _board_fragments(model)
	check(model.activate_powerup("fragments"), "one accepted Treasure delivery exists before a repeat fails")
	model.step(0.12)
	var active: Dictionary = model.powerup_snapshot()
	var board: Array = model.cells.duplicate(true)
	for response: Dictionary in [{"ok": false, "reason": "insufficient"}, {"ok": false, "reason": "storage"}, {"ok": true, "duplicate": true}]:
		model.purchase_powerup = func(_receipt: String, _kind: String, price: int) -> Dictionary:
			check(price == 300, "failed repeats retain the next successful-use price")
			return response.duplicate()
		check(not model.activate_powerup("fragments") and model.powerup_snapshot() == active
			and model.cells == board and model.powerup_price("fragments") == 300,
			"a failed repeat preserves all pending deliveries, existing fragments, and price")
	check(events.feedback == [["fragments", true], ["fragments", false], ["fragments", false], ["fragments", false]]
		and cues.count("powerup_wrong") == 3,
		"insufficient, unsaved, and duplicate repeats give negative feedback while earlier deliveries continue")
	model.step(5.0)
	check(not model.powerup_active() and _board_fragments(model) == original + int(active.total)
		and events.arrivals.size() == int(active.total) and payments.size() == 1,
		"failed repeats neither lose nor duplicate the already-paid fragments")
	model.purchase_powerup = Callable()


func _test_powerup_fragment_repeat_lifecycle() -> void:
	for action: String in ["drain", "finish"]:
		var model = _powerup_model("fragments")
		var payments: Array = _accept_powerup_payments(model)
		var events: Dictionary = _observe_powerups(model)
		var original: int = _board_fragments(model)
		model.activate_powerup("fragments")
		model.step(0.1)
		model.activate_powerup("fragments")
		var total: int = int(model.powerup_snapshot().total)
		model.set_paused(true)
		if action == "finish":
			model.finish_round()
		else:
			model.finish_powerup(true)
		check(not model.powerup_active() and _board_fragments(model) == original + total
			and model.powerup_snapshot().completed == total and payments.size() == 2 and events.arrivals.is_empty(),
			"silent lifecycle completion drains every accepted repeat without late effects or another charge")
		check(model.phase == ("finished" if action == "finish" else "playing")
			and model.fragment_count == 0 and model.collected_coins == 0,
			"repeat settlement preserves the requested lifecycle and leaves fragments uncollected")
		model.purchase_powerup = Callable()
	var model = _powerup_model("fragments")
	var payments: Array = _accept_powerup_payments(model)
	model.activate_powerup("fragments")
	var duration: float = float(model.powerup_snapshot().duration)
	model.step(duration - 0.01)
	var previous: Dictionary = model.powerup_snapshot()
	check(model.can_activate_powerup("fragments") and model.activate_powerup("fragments")
		and payments.size() == 2 and is_equal_approx(float(model.powerup_snapshot().elapsed), duration - 0.01)
		and int(model.powerup_snapshot().completed) == int(previous.total),
		"Treasure stays available through the previous purchase's final impact recovery")
	model.finish_powerup(true)
	model.purchase_powerup = Callable()


func _test_powerup_fragments_on_nested_word() -> void:
	for original_fragments: Array in [[0, 0, 0], [1, 2, 3]]:
		var model = _model([_word("cat"), _word("cater"), _word("caterpillar")])
		var amounts: Array[int] = []
		amounts.assign(original_fragments)
		_board(model, ["cat", "picture:cat", "merged:cat:1"], amounts)
		var cat: Dictionary = _merge(model, 1000, 1001)
		var cater: Dictionary = _merge(model, int(cat.id), 1002)
		model.step(Model.SETTLE_SECONDS * 2.0)
		var original: int = _board_fragments(model)
		_accept_powerup_payments(model)
		check(model.activate_powerup("fragments"), "a nested valid word can receive a fragment purchase")
		var total: int = int(model.powerup_snapshot().total)
		model.finish_powerup(true)
		check(model.cells.size() == 1 and model.cell(int(cater.id)).fragments == original + total
			and bool(model.cell(int(cater.id)).chest), "every purchased fragment stays on the only eligible merged word")
		model.cells.append(_placed_tile(2000, "merged:cat:2", Model.COLUMNS - 1, 7, 1, 2))
		var final_word: Dictionary = _merge(model, int(cater.id), 2000)
		check(final_word.text == "cat" and final_word.merge_level == 4 and final_word.mass == 8 and final_word.fragments == original + total + 2,
			"a later valid merge retains the purchased fragments and the new target's fragments")
		model.step(Model.SETTLE_SECONDS * 2.0)
		check(model.collect(int(final_word.id)), "the nested word remains manually collectible after its paid effect")
		model.step(Model.collection_seconds(int(final_word.merge_level)))
		check(model.cells.is_empty() and model.fragment_count == original + total + 2,
			"collecting the final word awards every original and purchased fragment exactly once")
		model.purchase_powerup = Callable()


func _test_powerup_pause_and_clocks() -> void:
	for kind: String in ["auto_merge", "fragments"]:
		var model = _powerup_model(kind)
		_accept_powerup_payments(model)
		model.spawn_interval = 20.0
		model.spawn_elapsed = 19.9
		var generated: int = model.generated_tiles
		var upcoming: Array = model.upcoming.duplicate(true)
		check(model.activate_powerup(kind), "paid sequence starts near the automatic supply deadline")
		model.step(0.225 if kind == "auto_merge" else Model.POWERUP_DRAG_SECONDS * 0.5)
		model.set_paused(true)
		var before: Dictionary = model.snapshot()
		var active: Dictionary = model.powerup_snapshot()
		if kind == "auto_merge":
			check(active.drags.size() == 2, "Pause freezes both overlapping flights before their contact boundaries")
		model.step(50.0)
		check(model.snapshot() == before and model.powerup_snapshot() == active,
			"pause freezes paid sequence, board motion, and supply at the exact same point")
		model.set_paused(false)
		model.step(0.10)
		check(model.spawn_elapsed == 19.9 and model.generated_tiles == generated and model.upcoming == upcoming,
			"an active paid sequence preserves the automatic supply countdown and advertised roots")
		model.finish_powerup(true)
		check(model.spawn_elapsed == 19.9 and model.generated_tiles == generated,
			"silently draining a paid effect consumes no supply time")
		model.step(0.099)
		check(model.generated_tiles == generated, "normal supply resumes with its preserved remaining time")
		model.step(0.001)
		check(model.generated_tiles == generated + Model.DROP_COUNT, "the preserved supply deadline fires once after the paid effect")
		model.purchase_powerup = Callable()
		model = _model([_word("cat")])
		var pieces: Array[String] = []
		for index in range(Model.CAPACITY):
			pieces.append("x")
		pieces[0] = "cat"
		pieces[1] = "picture:cat"
		_board(model, pieces)
		model.step(0.001)
		model.full_elapsed = Model.FULL_SECONDS - 0.1
		_accept_powerup_payments(model)
		check(model.activate_powerup(kind), "a stable full board permits a paid rescue before danger expires")
		model.step(0.20)
		check(model.phase == "playing" and is_equal_approx(model.full_elapsed, Model.FULL_SECONDS - 0.1),
			"paid presentation freezes the active danger deadline without resetting it")
		model.finish_powerup(true)
		check(model.phase == "playing" and is_equal_approx(model.full_elapsed, Model.FULL_SECONDS - 0.1),
			"draining a paid effect preserves its frozen danger clock until normal play resumes")
		model.step(0.10)
		if kind == "auto_merge":
			check(model.phase == "playing" and model.cells.size() == Model.CAPACITY - 1 and model.full_elapsed < 0.0,
				"an ordinary-cell Auto merge frees one cell and clears danger when play resumes")
		else:
			check(model.phase == "finished", "a fragment award frees no cell, so preserved danger resumes and expires")
		model.purchase_powerup = Callable()


func _test_powerup_determinism() -> void:
	for kind: String in ["auto_merge", "fragments"]:
		var large = _powerup_model(kind)
		var fine = _powerup_model(kind)
		var large_payments: Array = _accept_powerup_payments(large)
		var fine_payments: Array = _accept_powerup_payments(fine)
		var large_events: Dictionary = _observe_powerups(large)
		var fine_events: Dictionary = _observe_powerups(fine)
		large.activate_powerup(kind)
		fine.activate_powerup(kind)
		check(large.powerup_snapshot() == fine.powerup_snapshot(),
			"equal seeds reserve identical paid targets, receipts, and random fragment totals")
		large.step(6.0)
		for index in range(600):
			fine.step(0.01)
		check(not large.powerup_active() and not fine.powerup_active()
			and _approximately_equal_state(_rejection_state(large), _rejection_state(fine)),
			"coarse and fine frames agree on the paid result, supply clocks, and rewards: " + kind)
		check(_approximately_equal_state(large_events, fine_events) and large_payments == fine_payments,
			"frame slicing preserves every paid drag, fragment impact, and single payment: " + kind)
		large.purchase_powerup = Callable()
		fine.purchase_powerup = Callable()
	var observed_totals: Dictionary = {}
	for seed_value in range(1, 25):
		var model = _model([_word("cat")])
		model.configure([_word("cat")], 3, seed_value)
		_board(model, ["cat", "picture:cat"])
		_accept_powerup_payments(model)
		model.activate_powerup("fragments")
		var total: int = int(model.powerup_snapshot().total)
		check(total >= 2 and total <= 8, "every seeded purchase stays within its advertised random two-to-eight fragment range")
		observed_totals[total] = true
		model.finish_powerup(true)
		check(_board_fragments(model) == total, "fragment randomization never duplicates or drops a reserved reward")
		model.purchase_powerup = Callable()
	check(observed_totals.size() > 1, "different seeds vary the fragment purchase total")
	check(observed_totals.has(2) and observed_totals.has(8), "seeded purchases can award both advertised fragment range endpoints")


func _test_powerup_finish_and_lifecycle() -> void:
	for kind: String in ["auto_merge", "fragments"]:
		for progress: float in [0.0, 0.225, 0.30, 0.37, 1.20]:
			var model = _powerup_model(kind)
			var payments: Array = _accept_powerup_payments(model)
			var events: Dictionary = _observe_powerups(model)
			var regular_events: Dictionary = _observe(model)
			model.activate_powerup(kind)
			var expected_fragments: int = _board_fragments(model) + (int(model.powerup_snapshot().total) if kind == "fragments" else 0)
			model.step(progress)
			model.set_paused(true)
			var presentation: Dictionary = events.duplicate(true)
			var cues: Array = regular_events.cues.duplicate()
			model.finish_powerup(true)
			check(not model.powerup_active() and model.paused and payments.size() == 1
				and _board_fragments(model) == expected_fragments,
				"silent lifecycle completion preserves pause and deterministically finishes the accepted effect")
			check(events == presentation and regular_events.cues == cues,
				"silent completion emits no catch-up drag, fragment, feedback, or cue storm")
			check(model.fusions.is_empty() and model.collected_coins == 0 and model.fragment_count == 0,
				"silent completion leaves no unpaid collection or orphan fusion")
			if kind == "auto_merge":
				check(model.merged_count == 3 and model.cells.size() == 3,
					"exiting in drag, fusion, or landing still applies every accepted automatic merge")
			var before: Dictionary = model.snapshot()
			model.finish_powerup(true)
			check(model.snapshot() == before and payments.size() == 1,
				"repeated lifecycle completion cannot reapply or repurchase a paid effect")
			model.purchase_powerup = Callable()
		for replace_round: bool in [false, true]:
			var model = _powerup_model(kind)
			var payments: Array = _accept_powerup_payments(model)
			var events: Dictionary = _observe_powerups(model)
			model.activate_powerup(kind)
			var expected_fragments: int = _board_fragments(model) + (int(model.powerup_snapshot().total) if kind == "fragments" else 0)
			model.step(0.20)
			model.set_paused(true)
			var presentation: Dictionary = events.duplicate(true)
			if replace_round:
				model.configure([_word("cat")], 3, 9)
				check(model.cells.size() == Model.INITIAL_SETTLED_TILES and model.fusions.is_empty()
					and not model.powerup_active(),
					"reconfiguration drains the old accepted power before installing an independent fresh board")
			else:
				var result: Dictionary = model.finish_round()
				check(model.phase == "finished" and not model.powerup_active() and model.fusions.is_empty()
					and _board_fragments(model) == expected_fragments and result.coins == 0 and result.words.is_empty(),
					"round exit applies an accepted power while preserving uncollected rewards on the finished board")
				if kind == "auto_merge":
					check(model.merged_count == 3 and model.cells.size() == 3,
						"round exit completes the full accepted automatic chain")
			check(payments.size() == 1 and events == presentation,
				"round replacement and round finish neither repay nor replay a paid presentation")
			model.purchase_powerup = Callable()


func _test_powerup_payment_reentry() -> void:
	for kind: String in ["auto_merge", "fragments"]:
		var model = _powerup_model(kind)
		var calls: Array = []
		model.purchase_powerup = func(receipt_id: String, requested: String, price: int) -> Dictionary:
			calls.append([receipt_id, requested, price])
			check(not model.activate_powerup("auto_merge") and not model.activate_powerup("fragments"),
				"purchase persistence cannot recursively buy a second power")
			return {"ok": true, "duplicate": false}
		check(model.activate_powerup(kind) and calls.size() == 1, "the guarded outer purchase commits only once")
		model.finish_powerup(true)
		model.purchase_powerup = Callable()
		model = _powerup_model(kind)
		calls = []
		model.purchase_powerup = func(receipt_id: String, requested: String, price: int) -> Dictionary:
			calls.append([receipt_id, requested, price])
			model.set_paused(true)
			return {"ok": true, "duplicate": false}
		check(model.activate_powerup(kind) and model.paused and model.powerup_active(),
			"pause during accepted payment retains the purchased effect for eventual completion")
		var expected_fragments: int = _board_fragments(model) + (int(model.powerup_snapshot().total) if kind == "fragments" else 0)
		model.finish_powerup(true)
		check(not model.powerup_active() and calls.size() == 1 and _board_fragments(model) == expected_fragments,
			"the accepted paused payment finishes once without invoking persistence again")
		model.purchase_powerup = Callable()
		for callback_action: String in ["configure", "finish", "settle"]:
			model = _powerup_model(kind)
			calls = []
			var before: Dictionary = model.snapshot()
			var generation: int = model._generation
			var original_fragments: int = _board_fragments(model)
			model.purchase_powerup = func(receipt_id: String, requested: String, price: int) -> Dictionary:
				calls.append([receipt_id, requested, price])
				match callback_action:
					"configure":
						check(not model.configure([_word("cat")], 3, 9),
							"configuration is rejected while a purchase response is unresolved")
					"finish":
						model.finish_round()
					"settle":
						model.finish_powerup(true)
				check(model.phase == "playing" and model._generation == generation and model.cells == before.cells,
					"purchase callbacks cannot discard or mutate the board before persistence answers")
				return {"ok": true, "duplicate": false}
			check(model.activate_powerup(kind) and calls.size() == 1 and model._generation == generation,
				"reentrant lifecycle requests preserve exactly one accepted purchase on its original round")
			if callback_action == "configure":
				check(model.powerup_active() and model.phase == "playing",
					"rejected reconfiguration allows the accepted original purchase to animate normally")
				model.finish_powerup(true)
			else:
				check(not model.powerup_active() and model.phase == ("finished" if callback_action == "finish" else "playing"),
					"deferred finish and drain requests run only after the accepted purchase can be completed")
			if kind == "auto_merge":
				check(model.merged_count == 3 and model.cells.size() == 3,
					"a lifecycle callback cannot lose any paid automatic merges")
			else:
				check(_board_fragments(model) == original_fragments + int(model.powerup_snapshot().total),
					"a lifecycle callback cannot lose any purchased fragment arrivals")
			model.purchase_powerup = Callable()


func _test_finish_reasons() -> void:
	for kind: String in ["auto_merge", "fragments"]:
		for accepted: bool in [false, true]:
			var model = _powerup_model(kind)
			var finished: Array[Dictionary] = []
			model.finished.connect(func(result: Dictionary) -> void: finished.append(result))
			model.purchase_powerup = func(_receipt: String, _kind: String, _price: int) -> Dictionary:
				model.finish_round("danger")
				model.finish_round()
				return {"ok": accepted, "duplicate": false}
			check(model.activate_powerup(kind) == accepted, "Deferred ending preserves the original payment result")
			check(model.phase == "finished" and not model.powerup_active() and finished.size() == 1
				and finished[0].reason == "danger" and model.finish_round().reason == "danger",
				"Accepted and rejected payments retain the first ending reason through deferred completion")
			model.purchase_powerup = Callable()
	var model = _powerup_model("auto_merge")
	_accept_powerup_payments(model)
	check(model.activate_powerup("auto_merge"), "An accepted power exists before reentrant result settlement")
	model.changed.connect(func() -> void: model.finish_round(), CONNECT_ONE_SHOT)
	check(model.finish_round("danger").reason == "danger" and model.merged_count == 3,
		"Reentrant completion while draining an accepted power keeps the original ending reason")
	model.purchase_powerup = Callable()
	check(model.configure([_word("cat")], 3, 9) and model.finish_round().reason == "finished",
		"A new round clears its predecessor's danger ending reason")


func _test_powerup_presentation_reentry() -> void:
	for action: String in ["pause", "drain", "finish"]:
		var model = _powerup_model("auto_merge")
		var payments: Array = _accept_powerup_payments(model)
		var handled: Dictionary = {"contact": false}
		model.cue_requested.connect(func(cue: String) -> void:
			if cue != "contact" or handled.contact:
				return
			handled.contact = true
			var pending: Array = model.powerup_snapshot().drags.filter(func(drag: Dictionary) -> bool:
				return bool(drag.contact_pending))
			check(pending.size() == 1 and bool(pending[0].contact_played) and model.fusions.is_empty(),
				"the contact cue can interrupt after the announced handover but before the merge commits")
			if action == "pause":
				model.set_paused(true)
			elif action == "drain":
				model.finish_powerup(true)
			else:
				model.finish_round())
		check(model.activate_powerup("auto_merge"), "automatic power accepts before a reentrant contact callback")
		model.step(Model.POWERUP_DRAG_SECONDS)
		check(handled.contact, "the original pair reaches its contact boundary")
		if action == "pause":
			check(model.paused and model.powerup_active() and model.fusions.is_empty(),
				"contact-time pause retains an accepted power without inventing an active fusion")
			var before: Dictionary = model.snapshot()
			model.step(50.0)
			check(model.snapshot() == before, "contact-time pause preserves its reserved source without advancing")
			model.set_paused(false)
			model.step(6.0)
		check(not model.powerup_active() and model.fusions.is_empty() and model._held_tile_id == -1
			and model.merged_count == 3 and model.cells.size() == 3 and payments.size() == 1,
			"contact interruption resumes or drains the original chain exactly once without a held-source deadlock")
		check(_board_fragments(model) == 21 and model.collected_coins == 0 and model.fragment_count == 0,
			"contact callback lifecycle changes preserve every carried fragment and leave collection rewards untouched")
		check(model.phase == ("finished" if action == "finish" else "playing"),
			"contact callback round exit takes effect only after the accepted chain is fulfilled")
		model.purchase_powerup = Callable()
	var model = _powerup_model("auto_merge")
	_accept_powerup_payments(model)
	var attempted: Dictionary = {"count": 0}
	model.fusion_started.connect(func(_payload: Dictionary) -> void:
		attempted.count += 1
		check(model.try_merge(1003, 1004, true) == "ignored" and not model.start_collection_batch(),
			"callbacks during an authorized automatic fusion cannot start an independent manual operation"), CONNECT_ONE_SHOT)
	model.activate_powerup("auto_merge")
	model.step(6.0)
	check(attempted.count == 1 and model.merged_count == 3 and not model.powerup_active(),
		"rejected callback input leaves the paid merge chain intact")
	model.purchase_powerup = Callable()
	for trigger: String in ["feedback", "arrival"]:
		for kind: String in (["auto_merge", "fragments"] if trigger == "feedback" else ["fragments"]):
			model = _powerup_model(kind)
			var payments: Array = _accept_powerup_payments(model)
			var after_callback: Dictionary = {}
			if trigger == "feedback":
				model.powerup_feedback.connect(func(_kind: String, success: bool) -> void:
					if success:
						check(model.configure([_word("sunflower")], 3, 9),
							"success feedback may replace the round after silently draining the accepted purchase")
						after_callback.merge(model.snapshot(), true), CONNECT_ONE_SHOT)
			else:
				model.powerup_fragment_arrived.connect(func(_payload: Dictionary) -> void:
					check(model.configure([_word("sunflower")], 3, 9),
						"a fragment impact callback may replace the round after silently delivering its remaining purchase")
					after_callback.merge(model.snapshot(), true), CONNECT_ONE_SHOT)
			model.activate_powerup(kind)
			if trigger == "arrival":
				model.step(2.0)
			check(not after_callback.is_empty() and model.snapshot() == after_callback and payments.size() == 1
				and not model.powerup_active() and model.fusions.is_empty(),
				"generation replacement from a paid presentation prevents all stale follow-on effects and time consumption")
			check(model.generated_tiles == Model.INITIAL_SETTLED_TILES and model.merged_count == 0
				and model.collected_coins == 0 and model.fragment_count == 0,
				"a presentation callback starts the replacement round with clean supply and rewards")
			model.purchase_powerup = Callable()
	for outer_action: String in ["configure", "finish"]:
		model = _powerup_model("auto_merge")
		var payments: Array = _accept_powerup_payments(model)
		model.activate_powerup("auto_merge")
		var replacement: Dictionary = {}
		model.changed.connect(func() -> void:
			check(model.configure([_word("sunflower")], 3, 9),
				"the final silent-drain change notification can install a replacement round")
			replacement.merge(model.snapshot(), true), CONNECT_ONE_SHOT)
		if outer_action == "configure":
			check(not model.configure([_word("dog")], 3, 13),
				"an outer configure call stops when its paid drain callback has already replaced the round")
		else:
			model.finish_round()
		check(not replacement.is_empty() and model.snapshot() == replacement and model.phase == "playing"
			and payments.size() == 1 and not model.powerup_active(),
			"an outer lifecycle call cannot reset or finish a newer round installed by its drain callback")
		model.purchase_powerup = Callable()


func _test_configuration() -> void:
	var model := Model.new()
	check(model.snapshot().max_merge_level == 9, "The public model snapshot exposes the nine-level merge cap")
	check(not model.configure([], 3, 1), "empty vocabulary is rejected")
	check(model.phase == "finished" and not model.error.is_empty(), "empty vocabulary has a useful failure state")
	var words: Array = [_word("cat"), _word(" CAT ", 3, "duplicate-spelling"), _word("dog", 3, "cat"),
		_word("rocket", 6), {"id": "missing-media", "text": "test", "min_age": 3}]
	check(model.configure(words, 3, 1), "eligible pictured words configure")
	check(model.cells.size() == Model.INITIAL_SETTLED_TILES, "round starts with fifteen parts")
	for row in range(Model.ROWS):
		check(model.cells.filter(func(tile: Dictionary) -> bool: return int(tile.row) == row).size()
			== (Model.COLUMNS if row >= Model.ROWS - 3 else 0), "Exactly the bottom three rows start full")
	check(model.upcoming.size() == 5 and Model.COLUMNS == 5, "five columns and previews")
	for tile in model.cells:
		check(str(tile.text) in ["cat", "picture:cat"], "duplicate IDs, duplicate spelling, other ages, and incomplete media are omitted")
		check(tile.word.is_empty() and not model.collect(int(tile.id)), "an unmerged root cannot be collected")
	_assert_board(model, "initial board")
	check(model.configure([_word("cat")], 0, 1), "Baby uses the first vocabulary age")
	check(model.configure([_word("advanced", 12)], 99, 1), "12+ uses age twelve vocabulary")
	var configured := _word("sunflower")
	configured.jelly_parts = ["sun", "flower"]
	model.configure([configured], 3, 1)
	_assert_supply_conservation(model.cells, [configured], "curated two-part opening")


func _test_merging_and_collection() -> void:
	var model = _model([_word("cat")])
	var events: Dictionary = _observe(model)
	_board(model, ["cat", "picture:cat"], [1, 1])
	check(model.try_merge(1000, 1001) == "merged", "The whole root matches its picture")
	check(model.cells.size() == 2 and model.fusions.size() == 1, "both bodies remain reserved during fusion")
	check(not model.collect(1000) and model.try_merge(1000, 1001) == "ignored", "reserved bodies cannot collect or merge twice")
	model.step(Model.FUSION_SECONDS - 0.01)
	check(model.cells.size() == 2 and events.collections.is_empty(), "fusion has a real duration and earns nothing")
	model.step(0.01)
	check(model.cells.size() == 1 and model.cells[0].text == "cat", "Fusion creates one persistent pictured word")
	var result: Dictionary = model.cells[0]
	check(not model.is_settled(result) and bool(result.settling), "the fixed fusion rectangle reserves its final settlement window before new input")
	check(result.word.id == "cat" and result.kind == "word", "exact current vocabulary match reveals its word image")
	check(result.mass == 2 and result.fragments == 2 and result.width == 1 and result.height == 1,
		"merged jelly preserves both fragments in one ordinary cell")
	check(result.skin == 1001, "merged body retains the target jelly skin across the animation boundary")
	check(model.fragment_count == 0 and model.collected_coins == 0 and events.attempts.is_empty(), "fusion alone awards no coins, fragments, or learning attempt")
	check(events.completed.size() == 1 and events.completed[0].fragments == 0, "fusion completion is distinct from collection")
	model.step(Model.SETTLE_SECONDS)
	check(model.collect(int(result.id)), "valid merged jelly can be tapped")
	check(not model.collect(int(result.id)), "repeat taps are reserved")
	model.step(Model.COLLECT_SECONDS)
	check(model.cells.is_empty() and model.cleared_pairs == 1, "collection removes the merged word once")
	check(model.collected_coins == 0 and model.fragment_count == 2, "Lv1 earns no coin bonus and both carried fragments collect")
	check(events.collections.size() == 1 and events.attempts.size() == 1, "collection emits one payout and one learning attempt")
	check(events.collections[0].coins == 0 and events.collections[0].fragments == 2, "collection payload has exact payout and fragments")
	check(events.cues.count("pop") == 1, "collection has exactly one disappearance cue")
	var result_summary: Dictionary = model.finish_round()
	check(result_summary.coins == 0 and result_summary.words.size() == 1, "round summary includes collected words and coins")
	check(result_summary.reason == "finished" and model.finish_round("danger").reason == "finished",
		"An explicit exit remains distinct from danger and cannot be relabeled after completion")


func _test_rare_coin_drop_boundary() -> void:
	var chances: Array[float] = [0.0, 0.02, 0.04, 0.12, 0.20, 0.30, 0.40, 0.50, 0.80]
	var amounts: Array[int] = [0, 50, 100, 150, 200, 250, 300, 350, 450]
	var rejected_model = _model([_word("cat")], false)
	_board(rejected_model, ["cat", "picture:cat"])
	var untouched_state: int = rejected_model._coin_rng.state
	check(not rejected_model.collect(1000) and not rejected_model.collect(1001) and not rejected_model.collect(-1)
		and rejected_model._coin_rng.state == untouched_state and rejected_model._collection_coin_rewards.is_empty(),
		"roots, pictures and missing IDs never create a receipt or consume a coin chance")
	for kind: String in ["root", "picture"]:
		var invalid: Dictionary = _tile(1000, "merged:cat:6")
		invalid.jelly_kind = kind
		check(Model.coins_for_tile(invalid) == 0 and Model.coin_drop_chance_for_tile(invalid) == 0.0,
			"a level field cannot grant bonus eligibility to an unmerged body")
	var missing_word: Dictionary = _tile(1000, "merged:cat:6")
	missing_word.word = {}
	check(Model.coins_for_tile(missing_word) == 0 and Model.coin_drop_chance_for_tile(missing_word) == 0.0,
		"a merged marker without a valid word has no bonus")
	for level in range(1, Model.MAX_MERGE_LEVEL + 1):
		var chance: float = chances[level - 1]
		var intervals: Array[Vector2] = [Vector2(0.0, 0.0001), Vector2(0.9999, 1.0001)]
		if level > 1:
			intervals.append(Vector2(chance - 0.0001, chance))
			intervals.append(Vector2(chance, chance + 0.0001))
		for interval: Vector2 in intervals:
			var seed_value: int = _coin_seed_between(interval.x, interval.y)
			var probe := RandomNumberGenerator.new()
			probe.seed = seed_value
			var roll: float = probe.randf()
			for mass: int in [2, 12]:
				var model = _model([_word("cat")], false)
				var tile: Dictionary = _placed_tile(1000, "merged:cat:%d" % level, 0, 7)
				tile.mass = mass
				tile.parts_count = mass
				tile.fragments = 2
				model.cells.assign([tile])
				check(Model.coins_for_tile(tile) == amounts[level - 1]
					and is_equal_approx(Model.coin_drop_chance_for_tile(tile), chance),
					"level %d odds and amount are independent of mass and roots" % level)
				model._coin_rng.seed = seed_value
				var coin_state_before: int = model._coin_rng.state
				var board_rng_state: int = model._rng.state
				model.set_paused(true)
				check(not model.collect(1000) and model._coin_rng.state == coin_state_before,
					"a paused collection does not consume a coin chance")
				model.set_paused(false)
				var expected_coins: int = amounts[level - 1] if roll < chance else 0
				check(model.collect(1000) and int(model.fusions[0].coins) == expected_coins,
					"level %d pays only for a roll strictly below its probability boundary" % level)
				var coin_rng_state: int = model._coin_rng.state
				check(coin_rng_state == (coin_state_before if level == 1 else probe.state),
					"Lv1 consumes no random draw; each eligible collection draws exactly once")
				check(not model.collect(1000) and model._coin_rng.state == coin_rng_state,
					"repeated taps during collection cannot reroll")
				check(model._rng.state == board_rng_state, "coin rolls leave supply and powerup randomness untouched")
				model._complete_operation(str(model.fusions[0].attempt_id))
				check(model.collected_coins == expected_coins and model.fragment_count == 2 and model.cleared_pairs == 1,
					"each level settles its reserved payout and all carried fragments once")
				check(model._collection_coin_rewards.is_empty() and model._collection_event_ids.is_empty()
					and not model.collect(1000) and model._coin_rng.state == coin_rng_state,
					"committed collection releases its reservation and cannot pay or roll again")


func _test_collection_without_coin_drop() -> void:
	var model = _model([_word("cat")], false)
	model.cells.assign([_reward_tile(1000, "cat", 0, 7, 2, 4, _word("cat"))])
	model._coin_rng.seed = _coin_seed_between(0.1, 0.9)
	var calls: Array = []
	model.credit_collection = func(receipt: String, coins: int) -> Dictionary:
		calls.append([receipt, coins])
		return {"ok": false}
	var events: Dictionary = _observe(model)
	check(model.collect(1000) and int(model.fusions[0].coins) == 0,
		"an ordinary nonwinning word starts its disappearance with no coin reward")
	var coin_rng_state: int = model._coin_rng.state
	model.step(Model.POP_SECONDS)
	model.set_paused(true)
	var paused_snapshot: Dictionary = model.snapshot()
	model.step(5.0)
	check(model.snapshot() == paused_snapshot and model._coin_rng.state == coin_rng_state,
		"pausing a nonwinning collection freezes its animation and its already-decided chance")
	model.set_paused(false)
	model.step(Model.COLLECT_SECONDS - Model.POP_SECONDS)
	check(calls.is_empty() and model.error.is_empty() and model.cells.is_empty(),
		"a nonwinning collection bypasses the coin wallet even when that wallet would reject payment")
	check(model.collected_coins == 0 and model.fragment_count == 4 and model.chest_tier == 1,
		"ordinary collections still supply chest fragments without routine coin income")
	check(events.collections.size() == 1 and events.collections[0].coins == 0 and events.collections[0].fragments == 4
		and events.attempts.size() == 1 and events.milestones == [[0, 1]] and events.cues == ["jelly-collect-lv2", "chest"],
		"zero-coin collection retains learning credit, disappearance feedback, and chest unlock presentation")
	var result: Dictionary = model.finish_round()
	check(result.coins == 0 and result.words.size() == 1,
		"round results retain learned words when their coin chance did not win")
	model.credit_collection = Callable()


func _test_rare_coin_drop_retry_and_pause() -> void:
	var model = _model([_word("cat")], false)
	var configured_coin_state: int = model._coin_rng.state
	model.cells.assign([_reward_tile(1000, "cat", 0, 7, 2, 3, _word("cat"))])
	model._coin_rng.seed = _coin_seed_between(0.0, 0.01)
	var calls: Array = []
	model.credit_collection = func(receipt: String, coins: int) -> Dictionary:
		calls.append([receipt, coins])
		if calls.size() > 1:
			model.set_paused(true)
		return {"ok": calls.size() > 1}
	check(model.collect(1000), "a rare winning word starts a retryable payment")
	var receipt: String = str(model.fusions[0].attempt_id)
	model.step(Model.COLLECT_SECONDS)
	check(calls == [[receipt, 50]] and model.cells.size() == 1 and model.collected_coins == 0
		and int(model._collection_coin_rewards[receipt]) == 50,
		"a failed wallet keeps the winning outcome and the original word without granting rewards")
	model._coin_rng.seed = _coin_seed_between(0.1, 0.9)
	var retry_rng_state: int = model._coin_rng.state
	check(model.collect(1000) and model._coin_rng.state == retry_rng_state and int(model.fusions[0].coins) == 50,
		"retrying a winning collection reuses its outcome without consuming even a losing next roll")
	model.step(Model.COLLECT_SECONDS)
	check(model.paused and calls == [[receipt, 50], [receipt, 50]] and model.collected_coins == 0,
		"pause in the successful wallet callback safely defers removal after one accepted payment")
	model.set_paused(false)
	model.step(0.01)
	check(calls.size() == 2 and model.cells.is_empty() and model.collected_coins == 50 and model.fragment_count == 3
		and model._coin_rng.state == retry_rng_state and model._collection_coin_rewards.is_empty(),
		"resuming a credited winning collection neither rerolls nor repays its saved bonus")
	model.credit_collection = Callable()
	model.cells.assign([_reward_tile(1001, "cat", 0, 7, 2, 0, _word("cat"))])
	check(model.collect(1001) and not model._collection_coin_rewards.is_empty(),
		"a new pending word owns an independent outcome")
	model.configure([_word("cat")], 3, 42)
	check(model._collection_coin_rewards.is_empty() and model._collection_event_ids.is_empty()
		and model._coin_rng.state == configured_coin_state,
		"new-round configuration discards pending outcomes and reproducibly resets the separate coin stream")


func _test_rare_coin_drop_batch() -> void:
	var model = _model([_word("cat")], false)
	_batch_board(model, 3)
	var probe := RandomNumberGenerator.new()
	var mixed_seed: int = -1
	for seed_value in range(100000):
		probe.seed = seed_value
		if probe.randf() >= 0.02 and probe.randf() < 0.02 and probe.randf() >= 0.02:
			mixed_seed = seed_value
			break
	check(mixed_seed >= 0, "a real seeded batch contains nonwinning, winning, and nonwinning words")
	model._coin_rng.seed = mixed_seed
	var calls: Array = []
	model.credit_collection = func(receipt: String, coins: int) -> Dictionary:
		calls.append([receipt, coins])
		return {"ok": calls.size() > 1}
	var events: Dictionary = _observe(model)
	check(model.start_collection_batch(), "a mixed batch retains the normal rhythmic collection action")
	model.step(Model.BATCH_BEAT_SECONDS)
	check(model.cleared_pairs == 1 and model.collected_coins == 0 and calls.is_empty(),
		"the first ordinary batch word clears without a wallet call")
	model.step(Model.BATCH_BEAT_SECONDS)
	var failed_receipt: String = str(model._collection_event_ids[1001])
	check(not model.collection_batch_active() and model.cleared_pairs == 1 and calls == [[failed_receipt, 50]],
		"only the rare winning word can encounter a coin-save failure and stop the batch")
	var retry_rng_state: int = model._coin_rng.state
	check(model.collect(1001) and model._coin_rng.state == retry_rng_state,
		"manual retry after a batch failure preserves its winning draw and the next word's chance")
	model.step(Model.COLLECT_SECONDS)
	check(model.start_collection_batch(), "the remaining nonwinning word can continue in a new batch")
	model.step(Model.BATCH_BEAT_SECONDS)
	check(calls == [[failed_receipt, 50], [failed_receipt, 50]] and model.collected_coins == 50
		and model.cleared_pairs == 3 and model.fragment_count == 3 and model.cells.is_empty(),
		"a mixed batch grants only the one winning bonus while collecting all words and fragments")
	check(events.collections.size() == 3 and events.collections[0].coins == 0
		and events.collections[1].coins == 50 and events.collections[2].coins == 0 and events.attempts.size() == 3,
		"per-word events preserve both probability outcomes across batch failure and manual retry")
	model.credit_collection = Callable()
	var coarse = _model([_word("cat")], false)
	var fine = _model([_word("cat")], false)
	for active in [coarse, fine]:
		_batch_board(active, 3)
		active._coin_rng.seed = mixed_seed
		active.start_collection_batch()
	coarse.step(Model.BATCH_BEAT_SECONDS * 3.0)
	for frame in range(roundi(Model.BATCH_BEAT_SECONDS * 300.0)):
		fine.step(0.01)
	check(coarse.collected_coins == 50 and fine.collected_coins == 50 and coarse.cells == fine.cells
		and coarse._coin_rng.state == fine._coin_rng.state and coarse.cleared_pairs == fine.cleared_pairs,
		"frame slicing cannot change the independent batch outcomes or grant additional coin chances")


func _test_rare_coin_drop_frequency_and_independence() -> void:
	var small = _model([_word("cat")], false)
	var large = _model([_word("cat")], false)
	var probe := RandomNumberGenerator.new()
	probe.seed = 19372026
	small._coin_rng.seed = probe.seed
	large._coin_rng.seed = probe.seed
	var wins: int = 0
	const SAMPLES: int = 20000
	for sample in range(SAMPLES):
		var expected_win: bool = probe.randf() < 0.02
		wins += int(expected_win)
		for model in [small, large]:
			var mass: int = 2 if model == small else 12
			model.cells.assign([_reward_tile(1000 + sample, "cat", 0, Model.ROWS - ceili(float(mass) / Model.COLUMNS), mass, 0, _word("cat"))])
			if model == large:
				model._rng.randi()
			check(model.collect(1000 + sample), "the frequency sample is an actual accepted word collection")
			check(int(model.fusions[0].coins) == (50 if expected_win else 0),
				"every collection draws exactly once with mass-independent odds and an independent board RNG")
			# Commit the normal transaction directly; probability checks do not need animation frames.
			model._complete_operation(str(model.fusions[0].attempt_id))
	check(wins >= 280 and wins <= 520,
		"twenty thousand deterministic collection chances keep the long-run rate near two percent")
	check(small.collected_coins == wins * 50 and large.collected_coins == wins * 50
		and small.cleared_pairs == SAMPLES and large.cleared_pairs == SAMPLES,
		"rare bonuses are identical for two-piece and larger words and leaving most collections coin-free")
	check(small._coin_rng.state == probe.state and large._coin_rng.state == probe.state
		and small._collection_coin_rewards.is_empty() and large._collection_coin_rewards.is_empty(),
		"all coin decisions consume one independent draw and retain no completed-outcome cache")


func _test_current_age_validation() -> void:
	var model := Model.new()
	model.configure([_word("cat"), _word("rocket", 6)], 6, 2)
	model.spawn_interval = 10000.0
	_board(model, ["cat", "picture:cat", "rocket", "picture:rocket"])
	check(model.try_merge(1000, 1001) == "wrong" and model.fusions.is_empty(),
		"a lower-age word is rejected before either part can merge")
	var current: Dictionary = _merge(model, 1002, 1003)
	check(current.word.id == "rocket", "current-age word resolves its image")
	model = _model([_word("ice cream")])
	_board(model, ["ice cream", "picture:ice cream"])
	var spaced: Dictionary = _merge(model, 1000, 1001)
	check(spaced.word.id == "ice cream" and spaced.text == "ice cream", "multiword vocabulary preserves its separator")
	model = _model([_word("cat")])
	_board(model, ["picture:cat", "cat"])
	check(model.try_merge(1000, 1001) == "merged" and model.fusions.size() == 1,
		"A picture dragged onto its root matches the same exact word sense")


func _rejection_state(model) -> Dictionary:
	return {"snapshot": model.snapshot(), "coin_rewards": model._collection_coin_rewards.duplicate(true),
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
	for pair: Array in [["picture:small", "cat"], ["sa", "sleep"], ["cat", "te"], ["cat", "er"]]:
		var pieces: Array[String] = []
		pieces.assign(pair)
		_board(model, pieces, [2, 3])
		model.set_held_tile(1000)
		emitted.changed = 0
		var before: Dictionary = _rejection_state(model)
		var cues_before: int = events.cues.size()
		check(model.try_merge(1000, 1001, true) == "wrong", "only an exact forward current-age spelling can merge: " + str(pair))
		check(_rejection_state(model) == before, "rejection preserves all board, reward, held, reservation, clock, and ID state")
		check(events.cues.size() == cues_before + 1 and events.cues.back() == "wrong",
			"an eligible rejected attempt requests one negative cue")
	check(events.attempts.is_empty() and events.collections.is_empty() and events.completed.is_empty()
		and emitted == {"changed": 0, "fusion": 0, "payments": 0}, "rejected words cause no learning penalty, fusion, payout, or board change event")
	_board(model, ["small", "picture:small"], [2, 3])
	check(model.try_merge(1000, 1001, true) == "merged" and model.fusions[0].result.text == "small"
		and model.fusions[0].result.fragments == 5, "the same complementary pieces succeed in forward order and retain all fragments")
	model.credit_collection = Callable()
	model = _model()
	model.configure([_word("cat", 3), _word("rocket", 6), _word("advanced", 12)], 6, 42)
	for pair: Array in [["cat", "picture:cat"], ["advanced", "picture:advanced"]]:
		var pieces: Array[String] = []
		pieces.assign(pair)
		_board(model, pieces, [1, 1])
		var before: Dictionary = _rejection_state(model)
		check(model.try_merge(1000, 1001) == "wrong" and _rejection_state(model) == before,
			"both younger and older dictionary spellings reject atomically at the current age")
	model = _model([_word("cat")])
	_board(model, ["cat", "picture:cat", "picture:small", "small"], [1, 1, 2, 3])
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
	_board(model, ["merged:cat:1", "merged:cat:1", "er"], [2, 3, 4])
	var word: Dictionary = _merge(model, 1000, 1001)
	model.step(Model.SETTLE_SECONDS)
	model.credit_collection = func(_id: String, _coins: int) -> Dictionary: return {"ok": false}
	check(model.collect(int(word.id)), "a formed word can have an outstanding wallet retry before rejection")
	model.step(Model.COLLECT_SECONDS)
	check(not model._collection_event_ids.is_empty() and not model._collection_coin_rewards.is_empty(),
		"rejection fixture retains its failed collection receipt and locked coin reward")
	model.set_held_tile(int(word.id))
	before = _rejection_state(model)
	var prior_combo: Dictionary = before.snapshot.combo.duplicate(true)
	before.snapshot.combo.count = 0
	before.snapshot.combo.rank = "D"
	before.snapshot.combo.tier = 0
	before.snapshot.combo.bonus = 0
	before.snapshot.combo.remaining = 0.0
	before.snapshot.combo.next_bonus = 0
	before.snapshot.combo.event_id = ""
	events = _observe(model)
	check(model.try_merge(int(word.id), 1002, true) == "wrong" and _rejection_state(model) == before
		and events.cues == ["wrong"] and events.attempts.is_empty(),
		"rejected growth preserves a completed word, its retry receipt, held anchor, and every carried fragment")
	check(int(prior_combo.count) > 0 and model.combo_snapshot().count == 0
		and model.combo_snapshot().best == prior_combo.best and model.combo_snapshot().coins == prior_combo.coins,
		"an actual rejected merge resets its active combo while preserving the round's best and saved coins")
	model.credit_collection = Callable()
	for replace_round: bool in [false, true]:
		var lifecycle_model = _model([_word("cat")])
		_board(lifecycle_model, ["picture:cat", "small"], [2, 3])
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
	_board(model, ["cat", "picture:cat", "merged:cat:1", "merged:cat:2"], [1, 1, 1, 1])
	var first: Dictionary = _merge(model, 1000, 1001)
	check(first.word.id == "cat", "first merge already forms a word")
	var second: Dictionary = _merge(model, int(first.id), 1002)
	check(second.text == "cat" and second.word.id == "cat" and second.merge_level == 2, "a valid word can grow only into another current-age word")
	var third: Dictionary = _merge(model, int(second.id), 1003)
	check(third.text == "cat" and third.word.id == "cat" and third.merge_level == 4, "Two Lv2 words add into a Lv4 merged Jelly")
	check(third.mass == 8 and third.fragments == 4, "every root and fragment survives repeated merges")
	check(Model.coins_for_tile(first) == 0 and Model.coins_for_tile(second) == 50 and Model.coins_for_tile(third) == 150, "each real upgrade raises its level-based potential bonus")
	model.step(Model.SETTLE_SECONDS)
	model.collect(int(third.id))
	model.step(Model.collection_seconds(int(third.merge_level)))
	check(model.collected_coins == 150 and model.fragment_count == 4, "larger word collects the entire accumulated reward")
	check(model.chest_tier == 1 and model.chest_count == 1, "four fragments unlock a chest")


func _test_nested_merge_collection_receipts() -> void:
	var model = _model([_word("cat"), _word("cater"), _word("caterpillar"), _word("dog")])
	_board(model, ["merged:cat:1", "merged:cat:1", "merged:cat:2", "merged:cat:2", "merged:dog:1", "merged:dog:1"], [1, 1, 2, 3, 1, 1])
	var cat: Dictionary = _merge(model, 1000, 1001)
	var dog: Dictionary = _merge(model, 1004, 1005)
	model.step(Model.SETTLE_SECONDS * 2.0)
	var calls: Array = []
	var payment: Dictionary = {"ok": false}
	model.credit_collection = func(receipt: String, coins: int) -> Dictionary:
		calls.append([receipt, coins])
		return payment.duplicate()
	check(model.collect(int(cat.id)) and model.collect(int(dog.id)), "independent formed words can retain failed collection receipts")
	model.step(Model.COLLECT_SECONDS)
	var cat_receipt: String = str(model._collection_event_ids[int(cat.id)])
	var dog_receipt: String = str(model._collection_event_ids[int(dog.id)])
	var dog_reward: int = int(model._collection_coin_rewards[dog_receipt])
	check(model.try_merge(int(cat.id), 1002) == "merged", "a word with a failed collection can grow into another valid word")
	var cater_id: int = int(model.fusions[0].result.id)
	model.step(Model.FUSION_SECONDS - 0.001)
	check(model._collection_event_ids.get(int(cat.id), "") == cat_receipt and model._collection_coin_rewards.has(cat_receipt),
		"the consumed word's retry identity remains intact until its replacement commits")
	model.step(0.001)
	check(not model._collection_event_ids.has(int(cat.id)) and not model._collection_coin_rewards.has(cat_receipt),
		"committing a valid merge releases the consumed word's obsolete receipt and reserved coin roll")
	check(model._collection_event_ids.get(int(dog.id), "") == dog_receipt and model._collection_coin_rewards[dog_receipt] == dog_reward,
		"merging another word leaves the independent failed reward locked to its original receipt")
	model.step(Model.SETTLE_SECONDS * 2.0)
	check(model.collect(cater_id), "the larger word owns a new independent collection attempt")
	model.step(Model.collection_seconds(int(model.cell(cater_id).merge_level)))
	var cater_receipt: String = str(model._collection_event_ids[cater_id])
	check(cater_receipt != cat_receipt, "a larger result never reuses the consumed child's collection receipt")
	var final_word: Dictionary = _merge(model, cater_id, 1003)
	check(not model._collection_event_ids.has(cater_id) and not model._collection_coin_rewards.has(cater_receipt)
		and final_word.merge_level == 6 and final_word.mass == 12 and final_word.fragments == 7,
		"a second valid merge also releases its consumed retry while preserving all mass and fragments")
	model.step(Model.SETTLE_SECONDS * 2.0)
	payment.ok = true
	check(model.collect(int(dog.id)), "the untouched failed word can retry normally")
	model.step(Model.COLLECT_SECONDS)
	check(calls.back() == [dog_receipt, dog_reward], "the untouched retry keeps its exact receipt and locked coin amount")
	model.step(Model.SETTLE_SECONDS * 2.0)
	check(model.collect(int(final_word.id)), "the nested result collects only its own final reward")
	model.step(Model.collection_seconds(int(final_word.merge_level)))
	check(model._collection_event_ids.is_empty() and model._collection_coin_rewards.is_empty()
		and model.collected_coins == 300 and model.fragment_count == 9 and model.cleared_pairs == 2,
		"terminal collection leaves no consumed retry data and pays only the two collected words")
	model.credit_collection = Callable()


func _test_collection_timeline_and_pause() -> void:
	var model = _model([_word("cat")])
	_board(model, ["cat", "picture:cat"])
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
	check(model.cells.is_empty() and model.collected_coins == 0 and model.cleared_pairs == 1, "resumed Lv1 collection settles once at 420 ms without coins")
	var snapshot: Dictionary = model.snapshot()
	model.step(-1.0)
	model.step(NAN)
	model.step(INF)
	check(model.snapshot() == snapshot, "invalid time steps cannot corrupt model state")


func _test_level_collection_anticipation() -> void:
	var pop_times: Array[float] = [0.18, 0.18, 0.18, 0.66, 0.72, 0.78, 0.84, 0.90, 0.96]
	var collection_times: Array[float] = [0.42, 0.42, 0.42, 0.90, 0.96, 1.02, 1.08, 1.14, 1.20]
	for level in range(1, Model.MAX_MERGE_LEVEL + 1):
		check(is_equal_approx(Model.collection_pop_seconds(level), pop_times[level - 1])
			and is_equal_approx(Model.collection_seconds(level), collection_times[level - 1]),
			"Lv%d has its deliberate manual anticipation and unchanged post-pop reward interval" % level)
		check(is_equal_approx(Model.collection_pop_seconds(level, true), 0.04)
			and is_equal_approx(Model.collection_seconds(level, true), 0.12),
			"Lv%d keeps the existing batch pop and collection beat" % level)
		var batch = _model([_word("cat")])
		_board(batch, ["merged:cat:%d" % level], [3])
		var batch_events: Dictionary = _observe(batch)
		check(batch.start_collection_batch(), "Every supported level can use batch collection")
		batch.step(0.039)
		check(batch_events.cues.is_empty() and batch.cleared_pairs == 0, "Batch anticipation does not pop before 40 ms")
		batch.step(0.001)
		check(batch_events.cues == ["pop" if level == 1 else "jelly-collect-lv%d" % level]
			and batch.cleared_pairs == 0, "Each batch level pops at 40 ms without granting rewards early")
		batch.step(0.079)
		check(batch.cleared_pairs == 0, "Each batch level remains reserved until 120 ms")
		batch.step(0.001)
		check(batch.cleared_pairs == 1 and batch.fragment_count == 3 and not batch.collection_batch_active(),
			"Each batch level completes on the requested 120 ms beat")
		if level < 4:
			continue
		var model = _model([_word("cat")])
		_board(model, ["merged:cat:%d" % level], [3])
		var events: Dictionary = _observe(model)
		var commits: Array = []
		model.commit_collection = func(payload: Dictionary) -> Dictionary:
			commits.append(payload.duplicate(true))
			return {"ok": true}
		check(model.collect(1000), "A high-level word begins its longer collection anticipation")
		var pending: Dictionary = model.fusions[0].duplicate(true)
		check(is_equal_approx(float(pending.pop_at), pop_times[level - 1])
			and is_equal_approx(float(pending.duration), collection_times[level - 1]),
			"The published collection timeline drives both visual anticipation and sound")
		model.step(pop_times[level - 1] - 0.001)
		check(events.cues.is_empty() and commits.is_empty() and model.cleared_pairs == 0
			and not model.cell(1000).is_empty() and not model.collect(1000),
			"The charging Jelly stays reserved with no early pop, payment, or repeated collection")
		model.set_paused(true)
		var paused_state: Dictionary = model.snapshot()
		model.step(5.0)
		check(model.snapshot() == paused_state and events.cues.is_empty() and commits.is_empty(),
			"Pausing during charge freezes its precise remaining anticipation")
		model.set_paused(false)
		model.step(0.001)
		check(events.cues == ["jelly-collect-lv%d" % level] and commits.is_empty() and model.cleared_pairs == 0,
			"Resuming crosses the high-level pop boundary once without paying before the reward boundary")
		model.set_paused(true)
		paused_state = model.snapshot()
		model.step(5.0)
		check(model.snapshot() == paused_state and events.cues.size() == 1, "Pause after the burst cannot replay its sound")
		model.set_paused(false)
		model.step(collection_times[level - 1] - pop_times[level - 1] - 0.001)
		check(commits.is_empty() and model.cleared_pairs == 0 and not model.cell(1000).is_empty(),
			"Post-burst recovery retains the source until the exact collection boundary")
		model.step(0.001)
		check(commits.size() == 1 and commits[0].merge_level == level and commits[0].attempt_id == pending.attempt_id
			and model.cells.is_empty() and model.fragment_count == 3 and events.attempts.size() == 1
			and events.collections.size() == 1 and model.collected_coins == Model.coins_for_tile(pending.a),
			"The delayed collection commits its original receipt, level, reward, and learning event exactly once")
		model.step(10.0)
		check(commits.size() == 1 and events.cues.count("jelly-collect-lv%d" % level) == 1 and events.attempts.size() == 1,
			"Late frames cannot duplicate a finished high-level burst or its rewards")
		model.commit_collection = Callable()
		var coarse = _model([_word("cat")])
		var fine = _model([_word("cat")])
		var coarse_events: Dictionary = _observe(coarse)
		var fine_events: Dictionary = _observe(fine)
		for active in [coarse, fine]:
			_board(active, ["merged:cat:%d" % level], [3])
			active.collect(1000)
		coarse.step(3.0)
		for frame in range(300):
			fine.step(0.01)
		check(_approximately_equal_state(coarse.snapshot(), fine.snapshot()) and _approximately_equal_state(coarse_events, fine_events)
			and coarse_events.cues.count("jelly-collect-lv%d" % level) == 1 and coarse_events.collections.size() == 1,
			"A single late frame and fine simulation produce identical high-level pops, rewards, and final state")


func _gravity_tower():
	var model = _model([_word("cat")])
	model.cells.assign([
		_reward_tile(1000, "cat", 1, 7, 2, 4, _word("cat")),
		_placed_tile(1001, "cat", 1, 6, 1, 2),
		_placed_tile(1002, "picture:cat", 1, 5, 1, 1),
		_placed_tile(1003, "x", Model.COLUMNS - 1, 7)
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
	check(model.cell(1001).skin == 3 and _footprint(model.cell(1003)) == Rect2i(Model.COLUMNS - 1, 7, 1, 1),
		"collection gravity preserves skins and already-supported neighboring bodies")
	check(model.try_merge(1001, 1002) == "ignored" and model.can_drop_now(), "falling bodies wait for landing while supply remains available")
	check(model.collected_coins == 50 and model.fragment_count == 4 and model.chest_tier == 1
		and events.collections.size() == 1 and events.attempts.size() == 1 and events.milestones == [[0, 1]],
		"falling leaves the original word's single coin, fragment, learning, and chest payout unchanged")
	model.set_paused(true)
	var before: Dictionary = model.snapshot()
	model.step(20.0)
	check(model.snapshot() == before, "pause freezes an in-progress collection fall")
	model.set_paused(false)
	model.step(Model.SETTLE_SECONDS)
	check(float(model.cell(1001).age) < model.settle_duration(model.cell(1001))
		and float(model.cell(1002).age) < model.settle_duration(model.cell(1002)) and model.merged_count == 0,
		"the collected stack genuinely falls in slow motion while outward marks land")
	model.step(float(model.hit_stop_snapshot().remaining))
	model.step(maxf(model.settle_duration(model.cell(1001)) - float(model.cell(1001).age),
		model.settle_duration(model.cell(1002)) - float(model.cell(1002).age)))
	check(float(model.cell(1001).age) + Model.EPSILON >= model.settle_duration(model.cell(1001))
		and float(model.cell(1002).age) + Model.EPSILON >= model.settle_duration(model.cell(1002)),
		"both children reach their physical landing before the Lv2 blast can match them")
	check(bool(model.cell(1001).falling) and model.cell(1001).falling_rows == 1,
		"landing keeps its last fall provenance so the view cannot emit a second impact cue")
	_assert_supported_tiles(model, [1001, 1002], "collected stack")
	_assert_board(model, "collected stack")
	for frame in range(100):
		model.step(0.04)
		if not model.powerup_active() and not model._gravity_pending:
			break
	check(model.cell(1001).is_empty() and model.cell(1002).is_empty() and model.merged_count == 1
		and not model._gravity_pending,
		"the collected Lv2 word then matches its affected child with the landed partner and finishes gravity")


func _test_gravity_partial_support() -> void:
	for mass: int in [3, 7]:
		var model = _model([_word("cat")])
		var body: Dictionary = _placed_tile(1001, "merged", 4, 0, mass, 3)
		model.cells.assign([_placed_tile(1000, "cat", 0, 7, 2, 0, _word("cat")), body])
		for row in range(4, Model.ROWS):
			model.cells.append(_placed_tile(2000 + row, "x", 4, row))
		model.collect(1000)
		model.step(Model.COLLECT_SECONDS)
		var landed: Dictionary = model.cell(1001)
		check(landed.row == 4 - int(body.height) and landed.column == body.column
			and landed.width == body.width and landed.height == body.height,
			"merged words stop at the first support in their own column")
		check(landed.falling_rows == landed.row and landed.mass == mass and landed.fragments == 3,
			"ordinary-cell falls retain exact travel, part count, and fragments")
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
	var merged: Dictionary = _placed_tile(1001, "large", 1, 6, 2)
	model.cells.assign([_placed_tile(1000, "cat", 1, 7, 2, 0, _word("cat")), merged])
	model.set_held_tile(1001)
	model.collect(1000)
	model.step(Model.COLLECT_SECONDS)
	check(_footprint(model.cell(1001)) == Rect2i(1, 6, 1, 1), "collection cannot resize or shift a held merged body")
	model.set_held_tile(-1)
	check(model.cell(1001).width == 1 and model.cell(1001).row == 7 and not model.is_settled(model.cell(1001)),
		"released merged body falls directly without growing first")
	model.step(Model.SETTLE_SECONDS)
	check(model.cell(1001).row == 7 and model.is_settled(model.cell(1001)), "the released body settles at the ordinary fall boundary")
	_assert_board(model, "released merged body")


func _test_drag_support_removal() -> void:
	var model = _model([_word("hat"), _word("nose")])
	var hat: Dictionary = _placed_tile(1000, "hat", 1, 7, 2, 3, _word("hat"))
	var nose: Dictionary = _placed_tile(1001, "nose", 1, 6, 2, 2, _word("nose"))
	hat.skin = 4
	nose.skin = 6
	model.cells.assign([hat.duplicate(true), nose.duplicate(true), _placed_tile(1002, "x", Model.COLUMNS - 1, 7)])
	var events: Dictionary = _observe(model)
	check(not model.begin_drag(1000) and not model.is_lifted(1000),
		"an unheld word cannot silently detach itself from the board")
	model.set_held_tile(1000)
	model.step(0.10)
	check(not model.is_lifted(1000) and model.cell(1001).row == 6 and not bool(model.cell(1001).get("falling", false)),
		"merely pressing or selecting hat leaves nose resting on its unchanged support")
	check(model.begin_drag(1000) and model.is_lifted(1000),
		"an actual drag lifts hat out of the board's support occupancy")
	model.step(Model.DRAG_GRAVITY_DELAY_SECONDS - 0.001)
	check(model.cell(1001).row == 6 and not bool(model.cell(1001).get("falling", false)),
		"nose remains at its original row for the first 599 ms after hat moves away")
	model.set_paused(true)
	model.step(10.0)
	model.set_paused(false)
	check(model.cell(1001).row == 6, "pause preserves the last millisecond of the support delay")
	model.step(0.001)
	var falling: Dictionary = model.cell(1001)
	check(falling.column == 1 and falling.row == 7 and bool(falling.falling) and falling.falling_rows == 1
		and bool(falling.settling) and is_zero_approx(float(falling.age)) and not bool(falling.arrival),
		"nose begins a natural one-row fall exactly 600 ms after hat is lifted")
	for original: Dictionary in [hat, nose]:
		var live: Dictionary = model.cell(int(original.id))
		for key: String in ["id", "text", "word", "mass", "parts_count", "fragments", "chest", "kind", "skin", "width", "height"]:
			check(live[key] == original[key], "lifting support preserves the body's " + key)
	model.set_paused(true)
	var paused: Dictionary = model.snapshot()
	model.step(10.0)
	check(model.snapshot() == paused and model.is_lifted(1000),
		"pause freezes the lifted source and the unsupported body's in-progress fall")
	model.set_paused(false)
	model.step(Model.SETTLE_SECONDS)
	check(model.is_settled(model.cell(1001)) and model.cell(1001).row == 7,
		"nose lands in the vacated hat footprint before the pointer is released")
	model.set_held_tile(-1)
	var restored: Dictionary = model.cell(1000)
	check(not model.is_lifted(1000) and model._held_tile_id == -1
		and restored.width == hat.width and restored.height == hat.height
		and not _footprint(restored).intersects(_footprint(model.cell(1001))),
		"cancelling after nose occupies the old position restores hat's whole body without overlap or loss")
	check(model.cell(1001).row == 7 and model.cell(1001).column == 1,
		"cancellation never moves the already landed nose back into the air")
	model.step(Model.SETTLE_SECONDS * 2.0)
	check(_board_fragments(model) == 5 and model.cells.size() == 3
		and events.collections.is_empty() and events.attempts.is_empty() and events.completed.is_empty()
		and model.collected_coins == 0 and model.fragment_count == 0 and model.merged_count == 0,
		"dragging and cancelling preserve words, fragments, and rewards exactly")
	_assert_supported_tiles(model, [1000, 1001], "cancelled drag above an occupied origin")
	_assert_board(model, "cancelled drag above an occupied origin")
	var settled: Dictionary = model.snapshot()
	model.set_held_tile(-1)
	check(model.snapshot() == settled, "a late repeated cancellation cannot move or duplicate the restored word")


func _test_drag_gravity_delay() -> void:
	for release: String in ["held", "reposition", "direct_reposition", "cancel"]:
		var model = _gravity_tower()
		model.cell(1003).row = 3
		model.set_held_tile(1000)
		if release == "direct_reposition":
			check(model.reposition(1000, 3, 3), "direct placement also delays the abandoned stack")
		else:
			check(model.begin_drag(1000), "the timing fixture starts a real support drag")
		model.step(0.20)
		check(model.cell(1001).row == 6 and model.cell(1002).row == 5,
			"the whole abandoned stack stays in place during its grace period")
		check(model.cell(1003).row == 7,
			"the support delay does not freeze unrelated gravity elsewhere on the board")
		if release == "reposition":
			check(model.reposition(1000, 3, 3), "a held support can be placed before the deadline")
		elif release == "cancel":
			model.set_held_tile()
			check(model.cell(1000).row == 7 and model.cell(1000).column == 1,
				"early cancellation restores the support to its still-vacant original cell")
		if release in ["reposition", "direct_reposition"]:
			check(model.cell(1000).row == 7 and model.cell(1000).column == 3,
				"the manually placed source itself starts falling immediately")
		model.step(0.399)
		check(model.cell(1001).row == 6 and model.cell(1002).row == 5,
			"releasing or repositioning does not shorten the original 600 ms delay")
		model.step(0.001)
		if release == "cancel":
			check(model.cell(1001).row == 6 and model.cell(1002).row == 5
				and model._drag_gravity_delays.is_empty(),
				"restored support cancels the delayed fall without a later timer jump")
		else:
			check(model.cell(1001).row == 7 and model.cell(1002).row == 6
				and is_zero_approx(float(model.cell(1001).age)),
				"the entire unsupported stack begins falling at the original deadline")
		model.step(Model.SETTLE_SECONDS)
		if release == "held":
			model.set_held_tile()
			model.step(Model.SETTLE_SECONDS)
		_assert_board(model, "delayed support " + release)
	var fine = _gravity_tower()
	var coarse = _gravity_tower()
	for model in [fine, coarse]:
		model.set_held_tile(1000)
		model.begin_drag(1000)
	for tick in range(70):
		fine.step(0.01)
	coarse.step(0.70)
	for id: int in [1001, 1002]:
		check(_footprint(fine.cell(id)) == _footprint(coarse.cell(id))
			and is_equal_approx(float(fine.cell(id).age), float(coarse.cell(id).age))
			and is_equal_approx(float(coarse.cell(id).age), 0.10),
			"a coarse frame advances only the fall time remaining after the 600 ms delay")
	var model = _gravity_tower()
	model.set_held_tile(1000)
	model.begin_drag(1000)
	model.step(0.20)
	model.set_held_tile()
	model.set_held_tile(1000)
	model.begin_drag(1000)
	model.step(0.599)
	check(model.cell(1001).row == 6, "a fresh drag after cancellation owns a fresh 600 ms delay")
	model.step(0.001)
	check(model.cell(1001).row == 7, "the second drag starts gravity at its own deadline")
	model = _gravity_tower()
	model.set_held_tile(1000)
	model.begin_drag(1000)
	check(model.reposition(1000, 3, 3), "the old support can leave a waiting child behind")
	model.set_held_tile(1001)
	check(model.begin_drag(1001) and model.reposition(1001, 0, 3),
		"a waiting child remains interactive and can itself be moved")
	check(model.cell(1001).row == 7 and bool(model.cell(1001).falling),
		"moving a waiting child clears its old delay so its own drop starts immediately")
	model.finish_round()
	check(model._drag_gravity_delays.is_empty(), "round exit discards outstanding support timers")
	model.configure([_word("cat")], 3, 42)
	check(model._drag_gravity_delays.is_empty(), "a new round cannot inherit support timers")


func _test_drag_partial_support() -> void:
	for mass: int in [3, 7]:
		var model = _model([_word("hat")])
		var hat: Dictionary = _placed_tile(1000, "hat", 0, 7, 2, 2, _word("hat"))
		var support_column: int = 3 if mass == 3 else Model.COLUMNS - 1
		var upper: Dictionary = _placed_tile(1001, "upper", support_column, 6, mass, 3)
		model.cells.assign([hat.duplicate(true), upper.duplicate(true), _placed_tile(1002, "x", support_column, 7)])
		model.set_held_tile(1000)
		check(model.begin_drag(1000), "a word can be lifted beside an independently supported merged neighbor")
		model.step(Model.SETTLE_SECONDS)
		check(_footprint(model.cell(1001)) == _footprint(upper) and not bool(model.cell(1001).get("falling", false)),
			"lifting another cell does not disturb the merged neighbor's real support")
		model.set_held_tile(-1)
		model.step(Model.SETTLE_SECONDS)
		check(_board_fragments(model) == 5 and model.collected_coins == 0 and model.fragment_count == 0,
			"a partially supported drag and cancellation do not consume either body's treasure")
		_assert_supported_tiles(model, [1000, 1001], "partial support during a real drag")
		_assert_board(model, "partial support during a real drag")


func _test_drag_return_capacity() -> void:
	var model = _model([_word("hat"), _word("nose"), _word("cat")])
	var hat: Dictionary = _placed_tile(1000, "hat", 0, 7, 2, 3, _word("hat"))
	hat.skin = 4
	var merged: Dictionary = _placed_tile(1002, "cat", 2, 7, 2, 4, _word("cat"))
	model.cells.assign([hat.duplicate(true), _placed_tile(1001, "nose", 0, 6, 2, 2, _word("nose")), merged])
	_fill_rows(model, 4, 7)
	var events: Dictionary = _observe(model)
	_assert_board(model, "crowded drag fixture")
	var initial_count: int = model.cells.size()
	var initial_generated: int = model.generated_tiles
	model.set_held_tile(1000)
	check(model.begin_drag(1000), "a merged source can lift out of a physically supported crowded board")
	model.step(Model.SETTLE_SECONDS * 3.0)
	check(model.cell(1001).row == 7 and model.is_settled(model.cell(1001)),
		"the return-capacity reservation never holds the unsupported stack in the air")
	check(model.cell(1002).width == 1 and model.cell(1002).height == 1,
		"an independent merged body keeps its ordinary cell while the live drag reserves a return cell")
	var excluded_ids: Array[int] = []
	var drops: int = 0
	for attempt in range(Model.ROWS + 2):
		model._restore_growth()
		model.step(Model.SETTLE_SECONDS * 2.0)
		if not model.can_drop_now():
			break
		var previous_count: int = model.cells.size()
		check(model.drop_now(), "real incoming supply can use spare capacity during an active drag")
		drops += 1
		check(model.cells.size() > previous_count and model._occupied(excluded_ids, false).size() < Model.CAPACITY,
			"incoming supply adds bodies but never consumes the lifted source's last return cell")
		model.step(2.0)
		check(model.phase == "playing" and model.is_lifted(1000),
			"repeated arrivals retain the live lifted source until the player releases it")
	check(drops >= 3 and not model.can_drop_now() and model._occupied(excluded_ids, false).size() == Model.CAPACITY - 1,
		"repeated supply stops exactly at the single remaining real return cell")
	var before_cancel: Dictionary = {}
	for tile: Dictionary in model.cells:
		before_cancel[int(tile.id)] = tile.duplicate(true)
	var expected_fragments: int = _board_fragments(model)
	model.set_held_tile(-1)
	model.step(Model.SETTLE_SECONDS * 2.0)
	check(not model.is_lifted(1000) and model._held_tile_id == -1 and model._dragged_tile_id == -1,
		"cancelling at capacity restores the lifted source and clears every live drag identity")
	check(model.cell(1000).width == 1 and model.cell(1000).height == 1,
		"the full board uses its one-cell return capacity without discarding the merged source")
	check(model.cells.size() == initial_count + model.generated_tiles - initial_generated
		and model.cells.size() == before_cancel.size() and _board_fragments(model) == expected_fragments,
		"a crowded cancellation retains all original and newly supplied bodies and carried fragments")
	var restored_ids: Array[int] = []
	for tile: Dictionary in model.cells:
		restored_ids.append(int(tile.id))
		var original: Dictionary = before_cancel[int(tile.id)]
		for key: String in ["id", "text", "word", "mass", "parts_count", "fragments", "chest", "kind", "skin"]:
			check(tile.get(key) == original.get(key), "crowded cancellation preserves every body's " + key)
	check(model.collected_coins == 0 and model.fragment_count == 0
		and model.merged_count == 0 and events.collections.is_empty() and events.attempts.is_empty() and events.completed.is_empty(),
		"crowded return preserves source contents and never invents collection or merge rewards")
	_assert_supported_tiles(model, restored_ids, "crowded drag cancellation")
	_assert_board(model, "crowded drag cancellation")


func _test_drag_same_cell_release() -> void:
	for locked: bool in [false, true]:
		var model = _model([_word("hat"), _word("cat")])
		var hat: Dictionary = _placed_tile(1000, "hat", 0, 6, 2, 3, _word("hat"))
		hat.placement_locked = locked
		model.cells.assign([hat, _placed_tile(1001, "cat", 0, 7, 2, 0, _word("cat"))])
		model.set_held_tile(1000)
		check(model.begin_drag(1000) and model.collect(1001),
			"a lifted body can lose its support while its original placement is still free")
		model.step(Model.COLLECT_SECONDS)
		check(model.reposition(1000, 0, 6), "a lifted source can release over its unchanged logical cell")
		var restored: Dictionary = model.cell(1000)
		check(bool(restored.placement_locked) == locked and not model.is_lifted(1000)
			and model._held_tile_id == -1 and model._dragged_tile_id == -1,
			"same-cell release preserves the existing growth lock and clears the active drag")
		check(restored.row == 7 and bool(restored.falling) and restored.falling_rows == 1,
			"same-cell release immediately falls onto the floor when its previous support was collected")
		model.step(Model.SETTLE_SECONDS)
		_assert_board(model, "same-cell lifted release")


func _test_drag_finish_lifecycle() -> void:
	for accepted_merge: bool in [false, true]:
		var model = _model([_word("hat"), _word("hats"), _word("nose")])
		model.cells.assign([_placed_tile(1000, "hat", 0, 7, 2, 3, _word("hat")),
			_placed_tile(1001, "nose", 0, 6, 2, 2, _word("nose")), _placed_tile(1002, "merged:hat:1", 4, 7, 2, 1)])
		var events: Dictionary = _observe(model)
		model.set_held_tile(1000)
		check(model.begin_drag(1000), "finish cleanup fixture lifts a supporting source")
		model.step(Model.DRAG_GRAVITY_DELAY_SECONDS + Model.SETTLE_SECONDS)
		var result_id: int = -1
		if accepted_merge:
			check(model.try_merge(1000, 1002, true) == "merged", "the lifted prefix can enter an accepted merge")
			result_id = int(model.fusions[0].result.id)
			model.step(Model.FUSION_SECONDS * 0.5)
		model.set_paused(true)
		var result: Dictionary = model.finish_round()
		check(model.phase == "finished" and model.fusions.is_empty() and model._held_tile_id == -1
			and model._dragged_tile_id == -1 and not model.is_lifted(1000),
			"finishing during a live drag or accepted airborne merge clears every pending drag and operation")
		check(model.cell(1001).row == 7 and _board_fragments(model) == 6
			and model.collected_coins == 0 and model.fragment_count == 0 and result.coins == 0 and result.words.is_empty()
			and events.collections.is_empty() and events.attempts.is_empty(),
			"finish cleanup retains the fallen stack and all carried fragments without awarding uncollected words")
		var mass: int = 0
		for tile: Dictionary in model.cells:
			mass += int(tile.mass)
			check(not model.is_lifted(int(tile.id)), "finished boards contain no airborne support exclusions")
		check(mass == 6, "finishing mid-drag preserves the total mass of every jelly")
		if accepted_merge:
			check(model.cells.size() == 2 and model.cell(1000).is_empty() and model.cell(1002).is_empty()
				and model.cell(result_id).text == "hat" and model.cell(result_id).mass == 4 and model.cell(result_id).merge_level == 2
				and model.cell(result_id).fragments == 4 and events.completed.size() == 1 and model.merged_count == 1,
				"finish completes an already accepted lifted merge once without resurrecting its old source rectangle")
		else:
			check(model.cells.size() == 3 and model.cell(1000).text == "hat" and events.completed.is_empty(),
				"finish restores a freely held source without creating a merge")
		_assert_board(model, "finish during a lifted source")
		var finished_state: Dictionary = model.snapshot()
		check(model.finish_round() == result and model.snapshot() == finished_state,
			"repeated finish cannot repeat a lifted source's merge or restoration")
		check(model.configure([_word("hat"), _word("nose")], 3, 42)
			and model._held_tile_id == -1 and model._dragged_tile_id == -1 and not model.is_lifted(1000)
			and model.fusions.is_empty(),
			"a replacement round discards every old lifted identity and pending operation")
		_assert_board(model, "new round after a lifted source")


func _test_gravity_reserved_operations() -> void:
	var model = _model([_word("cat")])
	model.cells.assign([_placed_tile(1000, "cat", 0, 7, 2, 0, _word("cat")),
		_placed_tile(1001, "cat", 0, 6), _placed_tile(1002, "picture:cat", 1, 6), _placed_tile(1003, "x", 1, 4)])
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


func _test_gravity_simultaneous_collections() -> void:
	var model = _model([_word("cat")])
	model.cells.assign([_reward_tile(1000, "cat", 0, 7, 2, 1, _word("cat")),
		_reward_tile(1001, "cat", 0, 6, 2, 2, _word("cat")), _reward_tile(1002, "x", 0, 5)])
	check(model.collect(1000) and model.collect(1001), "two stacked valid words can collect at one timestamp")
	model.step(Model.COLLECT_SECONDS)
	check(model.cell(1002).row == 7 and model.cell(1002).falling_rows == 2 and model.cell(1002).age == 0.0,
		"simultaneous removals produce one complete fall instead of an unnecessary stop at the first empty row")
	check(model.collected_coins == 100 and model.fragment_count == 3 and model.cleared_pairs == 2,
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


func _test_cell_size_after_gravity() -> void:
	var model = _model([_word("cat")])
	var merged: Dictionary = _placed_tile(1001, "chunk", 0, 5, 2, 2)
	model.cells.assign([_placed_tile(1000, "cat", 1, 7, 2, 0, _word("cat")), merged,
		_placed_tile(1002, "x", 0, 6), _placed_tile(1003, "x", 0, 7)])
	_fill_rows(model, 0, 5)
	var held_id: int = -1
	for tile: Dictionary in model.cells:
		if tile.column == 1 and tile.row == 4:
			held_id = int(tile.id)
	model.set_held_tile(held_id)
	model.collect(1000)
	model.step(Model.COLLECT_SECONDS)
	check(model.cell(1001).width == 1 and model.cell(1001).row == 5,
		"neighboring collection leaves a supported merged body's ordinary cell unchanged")
	model.step(Model.SETTLE_SECONDS)
	check(_footprint(model.cell(1001)) == Rect2i(0, 5, 1, 1) and model.cell(1001).fragments == 2
		and model.is_settled(model.cell(1001)), "newly freed room never grows or restarts a settled merged body")
	check(model.cell(held_id).row == 4, "neighboring gravity keeps the held support's logical anchor unchanged")
	model.set_held_tile(-1)
	_assert_board(model, "stable cell after gravity")


func _test_gravity_wallet_failure() -> void:
	var model = _model([_word("cat")])
	model.cells.assign([_reward_tile(1000, "cat", 0, 7, 2, 1, _word("cat")),
		_reward_tile(1001, "cat", 0, 6, 2, 2, _word("cat")), _reward_tile(1002, "x", 0, 5)])
	var calls: Array = []
	model.credit_collection = func(receipt: String, coins: int) -> Dictionary:
		calls.append([receipt, coins])
		return {"ok": calls.size() != 2}
	model.collect(1000)
	model.collect(1001)
	model.step(Model.COLLECT_SECONDS)
	var retry_id: String = str(model._collection_event_ids[1001])
	check(model.collected_coins == 50 and model.cell(1001).row == 7 and model.cell(1002).row == 6,
		"failed upper payment retains its word and releases its reservation for gravity from the successful lower collection")
	check(not model.collect(1001), "retained failed word waits for its fall to land before a payment retry")
	model.step(Model.SETTLE_SECONDS)
	check(model.collect(1001), "failed word remains collectible after landing")
	model.step(Model.COLLECT_SECONDS)
	check(calls.size() == 3 and calls[2] == [retry_id, 50] and model.collected_coins == 100
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
	model.cells.assign([_reward_tile(1000, "cat", 2, 2, 2, 3, _word("cat"))])
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
	var events: Dictionary = _observe(model)
	_board(model, ["merged:cat:1", "merged:cat:1"])
	var merged: Dictionary = _merge(model, 1000, 1001)
	model.step(Model.SETTLE_SECONDS)
	var calls: Array = []
	model.credit_collection = func(event_id: String, amount: int) -> Dictionary:
		calls.append({"id": event_id, "amount": amount, "present": not model.cell(int(merged.id)).is_empty()})
		return {"ok": calls.size() > 1}
	model.collect(int(merged.id))
	model.step(Model.COLLECT_SECONDS)
	check(model.cells.size() == 1 and model.collected_coins == 0 and model.fusions.is_empty(), "failed wallet save preserves retryable word and grants nothing")
	check(events.attempts.is_empty(), "an uncommitted collection cannot grant mastery before its wallet retry")
	check(not model.error.is_empty(), "failed save exposes a recoverable error")
	check(model.collect(int(merged.id)), "failed wallet transaction can retry")
	model.step(Model.COLLECT_SECONDS)
	check(calls.size() == 2 and calls[0].id == calls[1].id, "retry uses the same stable wallet event ID")
	check(calls[0].present and calls[1].present and calls[1].amount == 50, "wallet receives exact amount before irreversible removal")
	check(model.cells.is_empty() and model.collected_coins == 50 and model.error.is_empty(), "successful retry completes exactly once")
	check(events.attempts == [{"id": calls[0].id, "words": ["cat"], "correct": true}],
		"a successful retry grants one mastery attempt under the original collection receipt")
	check(not model.collect(int(merged.id)), "an already-collected word cannot retry its mastery award")
	model.step(Model.COLLECT_SECONDS)
	check(events.attempts.size() == 1, "later steps cannot repeat mastery for a completed collection")
	model.credit_collection = Callable()
	model = _model([_word("cat")])
	events = _observe(model)
	_board(model, ["merged:cat:1", "merged:cat:1"])
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
	check(pause_calls.size() == 1 and model.collected_coins == 50 and events.attempts.size() == 1,
		"resuming a credited collection pays and grants mastery exactly once")
	model.credit_collection = Callable()
	model = _model([_word("cat")])
	events = _observe(model)
	_board(model, ["merged:cat:1", "merged:cat:1"])
	merged = _merge(model, 1000, 1001)
	model.step(Model.SETTLE_SECONDS)
	model.credit_collection = func(_event_id: String, _amount: int) -> Dictionary:
		model.set_paused(true)
		return {"ok": true}
	model.collect(int(merged.id))
	var receipt: String = str(model.fusions[0].attempt_id)
	model.step(Model.COLLECT_SECONDS)
	check(events.attempts.is_empty(), "a credited collection waiting for paused settlement has not granted mastery yet")
	var finished: Dictionary = model.finish_round()
	check(finished.coins == 50 and finished.words.size() == 1, "exit while a credited collection is paused includes the accepted transaction")
	check(events.attempts == [{"id": receipt, "words": ["cat"], "correct": true}],
		"finishing a credited collection while paused retains its one mastery attempt")
	model.finish_round()
	model.step(Model.COLLECT_SECONDS)
	check(events.attempts.size() == 1, "repeated paused finish and later steps do not duplicate settled mastery")
	model.credit_collection = Callable()


func _test_auto_collect_unlock() -> void:
	var model := Model.new()
	check(model.pip_level == 0 and not model.auto_collect_unlocked()
		and Model.AUTO_COLLECT_UNLOCK_LEVEL == 3, "A new model keeps Auto Collect locked until Pip Lv3")
	check(model.configure([_word("advanced", 12)], 12, 42) and model.pip_level == 0
		and not model.auto_collect_unlocked(), "Advanced vocabulary age cannot unlock a new Pip's Auto Collect")
	model.configure([_word("cat")], 3, 42)
	model.spawn_interval = 10000.0
	_batch_board(model, 3)
	var events: Dictionary = _observe(model)
	for level: int in [-1, 0, 1, 2]:
		model.set_pip_level(level)
		var before: Dictionary = model.snapshot()
		var rng_state: int = model._coin_rng.state
		check(before.pip_level == maxi(0, level) and not before.auto_collect_unlocked
			and before.auto_collect_unlock_level == 3, "Locked snapshots expose the current Pip level and exact unlock boundary")
		check(not model.start_collection_batch() and not model._begin_collection(1000, 1),
			"Every automatic collection entry refuses Pip below Lv3")
		check(model.snapshot() == before and model._coin_rng.state == rng_state
			and events.collections.is_empty(), "A locked attempt cannot reserve a word, roll coins, change combo, or start a batch")
	check(model.collect(1000), "Pip Lv2 retains ordinary manual collection")
	model.step(Model.collection_seconds(2))
	check(model.cleared_pairs == 1 and model.fragment_count == 1 and model.combo_count == 1
		and events.collections.size() == 1, "Manual collection below the unlock still grants its normal fragment and combo")
	for level: int in [3, 4, 99]:
		model = _model([_word("cat")], false)
		model.set_pip_level(level)
		_batch_board(model, 3)
		check(model.auto_collect_unlocked() and model.start_collection_batch(), "Pip Lv%d can start Auto Collect" % level)
		model.step(Model.BATCH_BEAT_SECONDS * 3.0)
		check(model.cleared_pairs == 3 and model.combo_count == 3 and not model.collection_batch_active(),
			"Unlocked Auto Collect keeps the normal three-word rhythm and combo")
	model = _model([_word("cat")], false)
	_batch_board(model, 3)
	model.start_collection_batch()
	model.step(0.03)
	var receipt: String = str(model.fusion.attempt_id)
	model.set_pip_level(2)
	check(not model.collection_batch_active() and str(model.fusion.attempt_id) == receipt,
		"Losing the unlock cancels queued words while preserving the started transaction")
	model.step(2.0)
	check(model.cleared_pairs == 1 and model.cells.size() == 2 and model.combo_count == 1,
		"A downgrade settles only the already-started word and does not reset its combo")
	model.set_pip_level(3)
	check(not model.collection_batch_active() and model.start_collection_batch(),
		"Regaining Lv3 requires a fresh explicit Auto Collect command")
	model.step(2.0)
	check(model.cleared_pairs == 3 and model.combo_count == 3, "A fresh unlocked command collects each remaining word once")
	model = _model([_word("cat")], false)
	_batch_board(model, 3)
	model.start_collection_batch()
	model.pip_level = 0
	model.step(2.0)
	check(model.cleared_pairs == 1 and not model.collection_batch_active(),
		"The batch scheduler rechecks the unlock even when direct state mutation bypasses its setter")
	model = _model([_word("cat")], false)
	_batch_board(model, 3)
	var pending: Array = []
	model.commit_collection = func(payload: Dictionary) -> Dictionary:
		pending.append(payload.duplicate(true))
		return {"pending": true}
	model.start_collection_batch()
	model.step(1.0)
	model.set_pip_level(0)
	check(pending.size() == 1 and not model.collection_batch_active() and model.cleared_pairs == 0,
		"A profile becoming unavailable preserves the pending save without starting another word")
	model.resolve_collection_commit(str(pending[0].event_id), int(pending[0].generation), {"ok": true})
	model.step(2.0)
	check(model.cleared_pairs == 1 and model.cells.size() == 2 and model.combo_count == 1 and pending.size() == 1,
		"A late save acknowledgment after locking settles the original word exactly once")
	model.commit_collection = Callable()


func _batch_board(model, count: int = 9) -> void:
	model.cells.clear()
	for index in range(count):
		var row: int = Model.ROWS - ceili(float(count) / 3.0) + int(index / 3)
		model.cells.append(_reward_tile(1000 + index, "cat", (index % 3) * 2, row, 2, 1, _word("cat")))


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
			model.step(Model.BATCH_BEAT_SECONDS - 0.001)
			check(starts.size() == index and payouts.size() == index - 1,
				"neither the next collection nor its preceding payout runs before 140 ms")
			model.step(0.001)
			expected_time += Model.BATCH_BEAT_SECONDS
		check(starts.size() == index + 1, "exact beat boundary starts one collection")
		var start: Dictionary = starts[index]
		check(start.id == expected_ids[index], "the captured spatial order is preserved across collection gravity")
		check(start.batch and start.index == index + 1 and start.total == expected_ids.size(), "presentation receives stable batch index and total")
		check(is_equal_approx(float(start.time), expected_time) and start.collections_running == 1,
			"each rhythmic start occurs at its authoritative time with one collecting body")
		check(model.collected_coins == index * 50, "only preceding completed transactions have earned coins")
		check(payouts.size() == index, "each 140 ms boundary commits exactly one preceding word")
		if index > 0:
			check(is_equal_approx(float(payouts[index - 1].time), expected_time),
				"authoritative coin and fragment payouts follow the exact 140 ms cadence")
	model.step(Model.BATCH_BEAT_SECONDS - 0.001)
	check(model.collection_batch_active() and payouts.size() == 8,
		"the final word also retains its complete 140 ms transaction")
	model.step(0.001)
	check(not model.collection_batch_active() and model.cells.is_empty(), "the batch ends only after its final transaction completes")
	check(model.collection_batch_snapshot().completed == 9 and model.collection_batch_snapshot().remaining == 0, "completed status accounts for every collected word")
	check(model.collected_coins == 450 and model.fragment_count == 9 and model.cleared_pairs == 9, "all coins and fragments use normal once-only collection rewards")
	check(events.collections.size() == 9 and events.attempts.size() == 9 and events.cues.count("jelly-collect-lv2") == 9, "every word gets one collection, learning attempt and disappearance cue")
	check(events.milestones == [[0, 1], [1, 2]], "batch fragments preserve normal chest unlock and upgrade milestones")
	check(payouts.size() == 9 and is_equal_approx(float(payouts.back().time), 1.08)
		and is_equal_approx(float(model.collection_batch_snapshot().elapsed), 1.08),
		"Nine words use the exact faster 1.08-second batch without extra gaps")
	var coin_total: int = model.collected_coins
	model.step(1.0)
	check(model.collected_coins == coin_total and not model.start_collection_batch(), "an empty batch has no repeat rewards")


func _test_collection_batch_candidates() -> void:
	var model = _model([_word("cat")])
	_board(model, ["cat", "picture:cat", "x", "y"])
	var valid: Dictionary = _merge(model, 1000, 1001)
	check(model.collectable_ids() == [int(valid.id)], "only valid merged words are eligible, including their final wobble")
	check(model.start_collection_batch() and model.fusions.is_empty(), "a just-merged word can queue while its finishing wobble settles")
	# A later word is not silently added to the button's captured set.
	model.cells.append(_placed_tile(9000, "cat", 0, 1, 2, 0, _word("cat")))
	model.step(2.0)
	check(model.cleared_pairs == 1 and not model.cell(9000).is_empty(), "the click collects only its original word IDs")
	check(model.cell(1002).text == "x" and model.cell(1003).text == "y", "unmatched roots remain separate after batch collection")
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
			check(is_equal_approx(float(starts[index].time), Model.SETTLE_SECONDS + index * Model.BATCH_BEAT_SECONDS)
				and is_equal_approx(float(payouts[index].time), Model.SETTLE_SECONDS + (index + 1) * Model.BATCH_BEAT_SECONDS),
				"initial settlement cannot introduce later gaps into the 140 ms collection cadence")
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
	model.cells.append(_placed_tile(9000, "x", 0, 2))
	var starts: Array = _observe_batch(model)
	var payouts: Array = _observe_batch_payouts(model)
	model.start_collection_batch()
	model.step(Model.BATCH_BEAT_SECONDS)
	check(starts.size() == 2 and payouts.size() == 1,
		"an unsupported captured word starts on the next 140 ms beat")
	check(_footprint(model.cell(1002)) == Rect2i(4, 4, 1, 1),
		"queued captured words keep their original footprint until their collection beat")
	check(model.cell(9000).row == 7 and bool(model.cell(9000).get("falling", false)),
		"ordinary roots still fall after a collected word while batch targets are reserved")
	model.step(Model.BATCH_BEAT_SECONDS * 2.0)
	check(starts.size() == 3 and payouts.size() == 3 and not model.collection_batch_active(),
		"floating captured words all collect without waiting for gravity")
	for index in range(starts.size()):
		check(is_equal_approx(float(starts[index].time), index * Model.BATCH_BEAT_SECONDS)
			and is_equal_approx(float(payouts[index].time), (index + 1) * Model.BATCH_BEAT_SECONDS),
			"reserved batch bodies retain exact 140 ms starts and payouts")
	check(model.cells.size() == 1 and model.cell(9000).row == 7,
		"collecting the reserved batch leaves the unrelated root on its support")
	model = _model([_word("cat")])
	_batch_board(model, 3)
	for tile: Dictionary in model.cells:
		tile.row = 4
	model.start_collection_batch()
	model.step(Model.BATCH_BEAT_SECONDS)
	model.cancel_collection_batch()
	model.step(1.2)
	check(model.cleared_pairs == 2 and model.collected_coins == 100 and model.cells.size() == 1,
		"cancelling reserves no later payout beyond the already-started word")
	check(_footprint(model.cell(1002)) == Rect2i(4, 7, 1, 1) and model.is_settled(model.cell(1002)),
		"cancelling releases the remaining ordinary cell for its natural fall")
	check(model.collect(1002), "the released word remains manually collectable after cancellation")
	model.step(Model.COLLECT_SECONDS)
	check(model.collected_coins == 150 and model.cells.is_empty(),
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
	model.step(Model.BATCH_BEAT_SECONDS - 0.051)
	check(model.cleared_pairs == 0 and model.collection_batch_active(),
		"resume preserves the final millisecond of the current 140 ms transaction")
	model.cancel_collection_batch()
	model.step(0.001)
	check(model.cleared_pairs == 1 and not model.collection_batch_active(),
		"cancelling the queue still finishes the current word at its preserved 140 ms deadline")
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
	check(calls.size() == 2 and model.cleared_pairs == 1 and model.collected_coins == 50, "wallet failure stops the batch at the failed word without subsequent payments")
	check(not model.collection_batch_active() and model.cells.size() == 2 and not model.error.is_empty(), "failed and queued words remain available with a recoverable error")
	check(model.collect(1001), "a failed batch word can retry through ordinary collection")
	model.step(Model.COLLECT_SECONDS)
	check(calls.size() == 3 and calls[1][0] == calls[2][0] and calls[2][1] == 50, "wallet retry keeps its original receipt and amount")
	check(model.start_collection_batch(), "remaining unattempted word can be batch-collected after retry")
	model.step(Model.BATCH_BEAT_SECONDS)
	check(model.cleared_pairs == 3 and model.collected_coins == 150 and calls.size() == 4, "retry and new batch still award each captured word exactly once")
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
	check(paused_calls.size() == 3 and model.cleared_pairs == 3 and model.collected_coins == 150, "resuming a credited batch does not repeat payment and continues its queue")
	model.credit_collection = Callable()


func _test_collection_batch_lifecycle() -> void:
	var model = _model([_word("cat")])
	_batch_board(model, 3)
	model.start_collection_batch()
	model.step(Model.BATCH_BEAT_SECONDS)
	var result: Dictionary = model.finish_round()
	model.step(5.0)
	check(result.coins == 50 and model.cells.size() == 2 and not model.collection_batch_active(), "finishing a round cancels queued words and includes only committed collections")
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
	model.step(Model.BATCH_BEAT_SECONDS)
	result = model.finish_round()
	check(result.coins == 50 and model.cleared_pairs == 1 and not model.collection_batch_active(), "exit while paused commits the accepted batch receipt and cancels all later words")
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
		_board(model, ["cat", "picture:cat"], [fragments, 0])
		var merged: Dictionary = _merge(model, 1000, 1001)
		model.step(Model.SETTLE_SECONDS)
		model.collect(int(merged.id))
		model.step(Model.COLLECT_SECONDS)
	check(model.fragment_count == 9 and model.chest_tier == 2 and model.chest_count == 1, "subsequent fragments upgrade the same chest")
	check(events.milestones == [[0, 1], [1, 2]], "unlock and upgrade each emit their visual milestone")
	check(events.collections.size() == 2 and events.collections[1].fragments == 5, "multi-fragment collections report the full stack")


func _test_repeated_merge_cell_size() -> void:
	var model = _model([_word("cat")])
	model.cells.clear()
	var current: Dictionary = _placed_tile(1000, "merged:cat:1", 0, 7, 2, 1)
	model.cells.append(current)
	for level in range(2, Model.MAX_MERGE_LEVEL + 1):
		var sibling: Dictionary = _placed_tile(1000 + level, "merged:cat:1", 1, 7, 2, 1)
		model.cells.append(sibling)
		current = _merge(model, int(current.id), int(sibling.id))
		check(current.merge_level == level and current.mass == 2 * level,
			"Additive joins retain every represented root while advancing through all nine levels")
		_assert_board(model, "level %d ordinary geometry" % level)
	check(current.width == 1 and current.height == 1 and current.merge_level == 9,
		"The highest merged level keeps precisely the ordinary source size")
	check(Model.coins_for_tile(current) == 450 and is_equal_approx(Model.coin_drop_chance_for_tile(current), 0.80),
		"The real Lv9 upgrade chain grants an eighty-percent chance of its 450-coin reward")

func _test_target_placement() -> void:
	var model = _model([_word("cat")])
	model.cells.assign([
		_placed_tile(1000, "cat", 0, 7, 1, 1),
		_placed_tile(1001, "picture:cat", 3, 1, 1, 2),
		_placed_tile(1002, "x", Model.COLUMNS - 1, 5)
	])
	var neighbor: Rect2i = _footprint(model.cell(1002))
	check(model.try_merge(1000, 1001) == "merged", "a lower source can merge into an upper target")
	var planned: Dictionary = model.fusions[0].result.duplicate(true)
	check(_footprint(planned) == Rect2i(3, 1, 1, 1),
		"the frozen ordinary cell stays exactly on the upper target")
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
	model.cells.assign([_placed_tile(1000, "cat", 0, 7, 4, 2), _placed_tile(1001, "picture:cat", Model.COLUMNS - 1, 1, 1, 3)])
	_fill_rows(model, 0, Model.ROWS - 1)
	check(model.try_merge(1000, 1001) == "merged", "a crowded target accepts a distant source with several accumulated parts")
	planned = model.fusions[0].result.duplicate(true)
	check(_footprint(planned) == Rect2i(Model.COLUMNS - 1, 1, 1, 1), "a full board still reserves exactly the target cell")
	model.step(Model.FUSION_SECONDS)
	merged = model.cell(int(planned.id))
	check(_footprint(merged) == _footprint(planned) and merged.mass == 5 and merged.fragments == 5,
		"ordinary-cell merging preserves full mass and every fragment")
	_assert_board(model, "crowded target placement")


func _test_edge_placement() -> void:
	for target_row: int in [0, 1, Model.ROWS - 1]:
		var model = _model([_word("caterpillar")])
		model.cells.assign([
			_placed_tile(1000, "caterpillar", 0, 6 if target_row == Model.ROWS - 1 else 7, 6, 2),
			_placed_tile(1001, "picture:caterpillar", Model.COLUMNS - 1, target_row, 1, 3)
		])
		check(model.try_merge(1000, 1001) == "merged", "an edge target accepts a merged word with seven accumulated parts")
		var planned: Dictionary = model.fusions[0].result.duplicate(true)
		check(_footprint(planned) == Rect2i(Model.COLUMNS - 1, target_row, 1, 1),
			"every edge merge uses the target's ordinary cell without shifting sideways")
		check(int(planned.row) >= 0 and int(planned.row) + int(planned.height) <= Model.ROWS,
			"top and bottom edge destinations remain inside the well")
		model.step(Model.FUSION_SECONDS)
		check(_footprint(model.cell(int(planned.id))) == _footprint(planned), "edge fusion and final footprint share one placement")
		model.step(Model.SETTLE_SECONDS * 2.0)
		check(model.cell(int(planned.id)).row == Model.ROWS - 1 and model.is_settled(model.cell(int(planned.id))),
			"a seven-part merged word finishes in the ordinary bottom row after its reserved handover")
		_assert_board(model, "ordinary edge placement")


func _test_automatic_support_settlement() -> void:
	var model = _model([_word("cat")])
	model.cells.assign([_placed_tile(1000, "cat", 0, 7), _placed_tile(1001, "picture:cat", 4, 7),
		_placed_tile(1002, "x", 0, 6)])
	check(model.try_merge(1000, 1001) == "merged", "moving a lower root into a merge can remove its old support")
	model.step(Model.FUSION_SECONDS)
	check(model.cell(1002).row == 7 and bool(model.cell(1002).falling),
		"a merge settles the unsupported stack left behind by its source")
	model.step(Model.SETTLE_SECONDS)
	_assert_supported_tiles(model, [1002], "support removed by merge")
	model = _model()
	var merged: Dictionary = _placed_tile(1000, "large", 2, 2, 7, 3)
	model.cells.assign([merged])
	model._restore_growth()
	check(_footprint(model.cell(1000)) == Rect2i(2, 2, 1, 1) and model.is_settled(model.cell(1000)),
		"size restoration does not grow or restart an ordinary merged word")
	model._gravity_pending = true
	model.step(Model.SETTLE_SECONDS * 2.0)
	check(_footprint(model.cell(1000)) == Rect2i(2, 7, 1, 1) and model.is_settled(model.cell(1000))
		and not model._gravity_pending, "an ordinary merged body falls in its own column to real support")
	_assert_board(model, "automatic merged-word fall")


func _test_reposition_bounds_and_falls() -> void:
	var model = _model([_word("cat")])
	var original: Dictionary = _placed_tile(1000, "cat", 0, 7, 2, 3, _word("cat"))
	original.skin = 4
	model.cells.assign([original, _placed_tile(1001, "x", 4, 3)])
	var events: Dictionary = _observe(model)
	var before: Dictionary = model.snapshot()
	for position: Vector2i in [Vector2i(-1, 0), Vector2i(Model.COLUMNS, 0), Vector2i(0, -1), Vector2i(0, Model.ROWS), Vector2i(4, 3), Vector2i(0, 7)]:
		check(not model.can_reposition(1000, position.x, position.y)
			and not model.reposition(1000, position.x, position.y), "invalid, occupied, and unchanged full-body placements are rejected")
		check(model.snapshot() == before, "a rejected placement leaves position, footprint, clocks, and rewards unchanged")
	check(not model.can_reposition(-1, 2, 1) and not model.reposition(-1, 2, 1), "missing tile IDs cannot reserve a placement")
	check(model.can_reposition(1000, 2, 1) and model.reposition(1000, 2, 1), "a complete merged jelly can be placed in any empty ordinary cell")
	var moved: Dictionary = model.cell(1000)
	check(_footprint(moved) == Rect2i(2, 7, 1, 1) and bool(moved.placement_locked)
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
	check(_footprint(model.cell(1000)) == Rect2i(2, 7, 1, 1) and not model._gravity_pending and not model._growth_pending,
		"a released word finishes on the floor without keeping pending-motion flags alive")
	before = model.snapshot()
	check(not model.reposition(1000, 2, 7) and model.snapshot() == before,
		"releasing an already supported word at its current coordinate preserves its existing state")
	check(model.reposition(1000, 4, 1), "a moved cell can land above an existing support in another column")
	model.step(Model.SETTLE_SECONDS)
	check(_footprint(model.cell(1000)) == Rect2i(4, 6, 1, 1), "a merged word stops above the support in its own column")
	_assert_supported_tiles(model, [1000], "manual merged-word drop")
	_assert_board(model, "manual merged-word drop")
	model = _model()
	model.cells.assign([_placed_tile(1000, "longword", 0, 6, 7, 2)])
	check(not model.can_reposition(1000, Model.COLUMNS, 0) and not model.reposition(1000, 0, Model.ROWS),
		"high-part-count words obey the same board edges as ordinary sources")
	check(model.reposition(1000, Model.COLUMNS - 1, 0), "a seven-part jelly can use the last board column")
	model.step(Model.SETTLE_SECONDS * 2.0)
	check(_footprint(model.cell(1000)) == Rect2i(Model.COLUMNS - 1, 7, 1, 1) and bool(model.cell(1000).placement_locked)
		and model.cell(1000).falling_rows == 7 and model.cell(1000).mass == 7,
		"a high-part-count word falls as one ordinary cell without losing its content")
	_assert_supported_tiles(model, [1000], "manual high-part-count drop")
	_assert_board(model, "manual high-part-count drop")


func _test_reposition_support_and_cell_size() -> void:
	var model = _gravity_tower()
	model.set_held_tile(1001)
	model.collect(1000)
	model.step(Model.COLLECT_SECONDS)
	check(model.cell(1001).row == 6 and model.cell(1002).row == 5, "held source keeps its old stack stable while support is collected")
	check(model.reposition(1001, 3, 3), "a held source can commit its explicit destination after lower support changes")
	check(model.cell(1001).row == 7 and bool(model.cell(1001).placement_locked) and bool(model.cell(1001).falling)
		and model.cell(1002).row == 5 and not bool(model.cell(1002).get("falling", false)),
		"manual relocation drops the released body immediately and delays the abandoned upper stack")
	model.set_held_tile(-1)
	model.step(Model.DRAG_GRAVITY_DELAY_SECONDS + Model.SETTLE_SECONDS)
	check(model.cell(1001).row == 7 and model.cell(1001).column == 3 and model.is_settled(model.cell(1001)) and not model._gravity_pending,
		"releasing the drag anchor preserves the chosen column through the natural landing")
	model.cells.append(_placed_tile(9000, "x", 3, 1))
	model._gravity_pending = true
	model.step(Model.SETTLE_SECONDS)
	check(model.cell(9000).row == 6 and model.cell(1001).row == 7,
		"a manually moved body supports naturally falling neighbors only at its actual landing position")
	_assert_board(model, "manual position supports a falling neighbor")
	model = _model()
	var merged: Dictionary = _placed_tile(1000, "large", 0, 7, 7, 2)
	model.cells.assign([merged])
	check(model.reposition(1000, 2, 2), "a seven-part merged word moves as one ordinary cell")
	model.step(Model.SETTLE_SECONDS)
	model._restore_growth()
	model._gravity_pending = true
	model.step(2.0)
	check(_footprint(model.cell(1000)) == Rect2i(2, 7, 1, 1) and bool(model.cell(1000).placement_locked)
		and not model._gravity_pending and not model._growth_pending,
		"size restoration preserves the ordinary moved cell and column after gravity brings it to the floor")


func _test_reposition_support_loss() -> void:
	for mass: int in [1, 3, 7]:
		var model = _model([_word("cat")])
		var column: int = 4
		var body: Dictionary = _placed_tile(1000, "part", 0, 0, mass, 2)
		model.cells.assign([body, _reward_tile(1001, "cat", 4, 7, 2, 4, _word("cat"))])
		var height: int = int(body.height)
		var width: int = int(body.width)
		var events: Dictionary = _observe(model)
		check(model.reposition(1000, column, 2), "the complete released footprint fits above a partial supporting word")
		check(_footprint(model.cell(1000)) == Rect2i(column, 7 - height, width, height)
			and bool(model.cell(1000).falling) and model.cell(1000).falling_rows == 5 - height,
			"all part counts stop at the first real support under their ordinary cell")
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
			and model.collected_coins == 50 and model.fragment_count == 4 and events.collections.size() == 1,
			"the resumed fall preserves moved content and pays only the collected support once")
		model.step(Model.SETTLE_SECONDS)
		_assert_supported_tiles(model, [1000], "manual support removed")
		_assert_board(model, "manual support removed")
	var model = _model([_word("cat")])
	model.cells.assign([_reward_tile(1000, "x", 0, 7), _reward_tile(1001, "cat", 4, 7, 2, 0, _word("cat"))])
	check(model.reposition(1000, 4, 6), "a release can also land directly on an existing body")
	check(_footprint(model.cell(1000)) == Rect2i(4, 6, 1, 1) and not bool(model.cell(1000).falling)
		and model.cell(1000).falling_rows == 0 and not model.is_settled(model.cell(1000)),
		"an already supported release keeps the usual landing wobble without inventing a downward fall")
	model.step(Model.SETTLE_SECONDS)
	check(model.is_settled(model.cell(1000)) and not model._gravity_pending, "a supported release settles without persistent gravity work")


func _test_reposition_locked_gravity() -> void:
	for mass: int in [1, 7]:
		for pause_release: bool in [false, true]:
			var model = _model()
			var body: Dictionary = _placed_tile(1000, "placed", 0, 1, mass, 3)
			body.placement_locked = true
			model.cells.assign([body, _placed_tile(1001, "x", 0, 0)])
			model.set_held_tile(1000)
			model.step(0.1)
			check(model.cell(1000).row == 1 and model.cell(1001).row == 0,
				"a held manual placement still anchors its stack until release")
			model.set_paused(pause_release)
			model.set_held_tile(-1)
			if pause_release:
				check(model.cell(1000).row == 1 and model._gravity_pending,
					"a paused unchanged release queues gravity without moving the held stack")
				model.set_paused(false)
			var landing_row: int = Model.ROWS - int(body.height)
			check(model.cell(1000).row == landing_row and model.cell(1000).column == 0
				and bool(model.cell(1000).falling) and model.cell(1000).falling_rows == landing_row - 1,
				"a placement lock cannot keep an unsupported body floating after an unchanged release")
			check(model.cell(1001).row == landing_row - 1 and bool(model.cell(1001).falling),
				"releasing a manually placed body also lowers the stack it used to support")
			model.step(Model.SETTLE_SECONDS)
			check(model.cell(1000).mass == mass and model.cell(1000).fragments == 3
				and not model._gravity_pending and model.collected_coins == 0,
				"manual placement recovery preserves its content and completes without rewards")
			_assert_supported_tiles(model, [1000, 1001], "manual placement recovery")
			_assert_board(model, "manual placement recovery")


func _test_reposition_reservations_and_guards() -> void:
	var model = _model([_word("cat")])
	model.cells.assign([_placed_tile(1000, "x", Model.COLUMNS - 1, 7), _placed_tile(1001, "cat", 0, 1), _placed_tile(1002, "picture:cat", 2, 1)])
	check(model.try_merge(1001, 1002) == "merged", "a concurrent merge reserves its target cell")
	check(not model.reposition(1000, 2, 1), "reposition cannot occupy a cell reserved by a future merge body")
	check(not model.reposition(1001, 3, 3), "a live fusion source cannot be repositioned")
	model = _model([_word("cat")])
	_batch_board(model, 3)
	model.start_collection_batch()
	check(not model.can_reposition(1002, 3, 2) and not model.reposition(1002, 3, 2), "a batch keeps all explicit placement input gated")
	model.step(Model.BATCH_BEAT_SECONDS * 3.0)
	check(model.cleared_pairs == 3 and is_equal_approx(float(model.collection_batch_snapshot().elapsed), Model.BATCH_BEAT_SECONDS * 3.0),
		"rejected manual movement preserves the three exact 140 ms batch transactions")
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


func _test_reposition_reward_retry() -> void:
	var model = _model([_word("cat")])
	_board(model, ["merged:cat:1", "merged:cat:1"], [2, 3])
	var word: Dictionary = _merge(model, 1000, 1001)
	model.step(Model.SETTLE_SECONDS)
	var receipts: Array[String] = []
	model.credit_collection = func(receipt: String, _amount: int) -> Dictionary:
		receipts.append(receipt)
		return {"ok": receipts.size() > 1}
	check(model.collect(int(word.id)), "a valid word can retain a failed payment receipt before moving")
	model.step(Model.COLLECT_SECONDS)
	var reward_rolls: Dictionary = model._collection_coin_rewards.duplicate(true)
	check(model.reposition(int(word.id), 2, 2), "a word with a failed payment can be moved without losing its retry")
	check(model._collection_coin_rewards == reward_rolls and receipts.size() == 1,
		"reposition preserves the locked coin reward and never calls wallet persistence")
	model.step(Model.SETTLE_SECONDS)
	check(model.collect(int(word.id)), "a positioned word remains collectable after its handover")
	model.step(Model.COLLECT_SECONDS)
	check(receipts.size() == 2 and receipts[0] == receipts[1] and model.collected_coins == 50
		and model.fragment_count == 5 and model.cells.is_empty(), "manual reposition preserves exact retry identity and once-only coin and fragment rewards")
	model.credit_collection = Callable()


func _test_fusion_reservations() -> void:
	for stagger: float in [0.0, 0.1]:
		var model = _model([_word("cat")])
		model.cells.assign([
			_placed_tile(1000, "cat", 0, 7), _placed_tile(1001, "picture:cat", 1, 4),
			_placed_tile(1002, "cat", Model.COLUMNS - 1, 7), _placed_tile(1003, "picture:cat", 3, 4),
			_placed_tile(1004, "x", 0, 4), _placed_tile(1005, "x", 4, 4)
		])
		_fill_rows(model, 5, 7)
		check(model.try_merge(1000, 1001) == "merged", "the first fusion can reserve its target cell")
		var first: Dictionary = model.fusions[0].result.duplicate(true)
		check(_footprint(first) == Rect2i(1, 4, 1, 1), "the first planned body leaves the neighboring gap available")
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
			check(model.fusions.size() == 1 and _footprint(model.cell(1002)) == Rect2i(Model.COLUMNS - 1, 7, 1, 1)
				and _footprint(model.cell(1003)) == Rect2i(3, 4, 1, 1), "completing one fusion cannot move the other fusion's live inputs")
			check(_footprint(model.fusions[0].result) == _footprint(second), "the pending animation keeps its reserved destination")
			_assert_reservations(model, "reservation after an earlier completion")
			model.step(stagger)
		check(_footprint(model.cell(int(second.id))) == _footprint(second), "the second completion commits its own collision-free destination")
		_assert_board(model, "completed simultaneous placements")


func _crowded_merge_model():
	var model = _model([_word("cat")])
	model.cells.clear()
	for index in range(4):
		var tile: Dictionary = _tile(1000 + index, "cat" if index == 0 else "picture:cat" if index == 1 else "cat",
			4 if index < 2 else 2, 2 if index == 0 else 3 if index == 1 else 1,
			{} if index < 2 else _word("cat"))
		tile.column = 0 if index < 2 else 1
		tile.row = 7 if index in [0, 2] else 6
		model.cells.append(tile)
	_fill_rows(model, 0, Model.ROWS - 1)
	return model


func _test_crowded_merge_cell_size() -> void:
	var model = _crowded_merge_model()
	check(not model._has_free_cell(), "ordinary cells fill the crowded merge fixture")
	model.step(Model.SETTLE_SECONDS)
	_assert_board(model, "crowded merge fixture")
	var merged: Dictionary = _merge(model, 1000, 1001)
	var merged_id: int = int(merged.id)
	check(merged.mass == 8 and merged.width == 1 and merged.height == 1,
		"a full board accepts an eight-part result in the target's ordinary cell")
	check(merged.fragments == 5 and merged.text == "cat" and Model.coins_for_tile(merged) == 0,
		"ordinary-cell sizing preserves word content, all fragments, and Lv1 zero-bonus eligibility")
	check(model.cells.size() == Model.CAPACITY - 1, "a completed join releases exactly one cell of board capacity")
	_assert_board(model, "crowded ordinary merge")
	model.step(Model.SETTLE_SECONDS)
	check(model.collect(1002), "the first neighboring word can free some room")
	model.step(Model.COLLECT_SECONDS)
	merged = model.cell(merged_id)
	check(merged.width == 1 and merged.height == 1 and merged.fragments == 5,
		"freed neighboring space never enlarges the merged body or changes its fragments")
	_assert_board(model, "neighboring collection")
	model.step(Model.SETTLE_SECONDS)
	check(model.collect(1003), "the second neighboring word remains collectable after its fall")
	model.step(Model.COLLECT_SECONDS)
	merged = model.cell(merged_id)
	check(merged.width == 1 and merged.height == 1 and merged.row == Model.ROWS - 1 and merged.mass == 8,
		"gravity preserves the ordinary merged cell and accumulated part count")
	check(merged.fragments == 5 and merged.text == "cat" and merged.word.id == "cat",
		"neighboring motion keeps the exact merged word and carried fragments")
	check(model.is_settled(merged) and not bool(merged.settling), "an unmoved ordinary body does not restart settlement after another collection")
	_assert_board(model, "stable merged body after gravity")
	var first_layout: Array[Dictionary] = model.cells.duplicate(true)
	model._restore_growth()
	check(model.cells == first_layout, "restoring unchanged footprints is stable and does not restart settlement")
	model.step(Model.SETTLE_SECONDS)
	check(model.collect(merged_id), "the eight-part word remains collectible")
	model.step(Model.COLLECT_SECONDS)
	check(model.collected_coins == 0 and model.fragment_count == 7,
		"ordinary-cell placement preserves the exact final coin and fragment payout")
	model = _model([_word("cat")])
	model.cells.clear()
	var fixed_origin: Dictionary = _tile(1000, "cat", 8, 2, _word("cat"))
	fixed_origin.column = 0
	fixed_origin.row = Model.ROWS - 1
	model.cells.append(fixed_origin)
	var original: Dictionary = fixed_origin.duplicate(true)
	model._restore_growth()
	merged = model.cell(1000)
	check(merged == original and model.is_settled(merged),
		"high-part-count settled words never resize or become unavailable when size restoration runs")


func _test_cell_size_after_settlement() -> void:
	var final_states: Array[Dictionary] = []
	for sliced: bool in [false, true]:
		var model = _crowded_merge_model()
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
		check(merged.width == 1 and merged.height == 1 and not model.is_settled(merged),
			"space freed during settlement cannot enlarge or move the frozen fusion cell early")
		check(model._gravity_pending and model.cleared_pairs == 2, "deferred gravity remembers unsupported bodies without another player action")
		var settle_remaining: float = Model.SETTLE_SECONDS - float(merged.age)
		model.step(settle_remaining - 0.001)
		check(_footprint(model.cell(id)) == Rect2i(0, 6, 1, 1), "the frozen ordinary cell remains unchanged just before its settlement boundary")
		model.step(0.002)
		merged = model.cell(id)
		check(merged.width == 1 and merged.height == 1 and merged.column == 0 and merged.row == 7,
			"settlement completion lets the deferred merged body fall into the newly cleared lower row")
		check(not model.is_settled(merged) and merged.fragments == 5 and Model.coins_for_tile(merged) == 0,
			"deferred falling reserves fresh settlement and preserves Lv1 zero-bonus eligibility")
		_assert_board(model, "deferred falling after settlement")
		final_states.append({"rect": _footprint(merged), "age": float(merged.age), "coins": model.collected_coins,
			"fragments": model.fragment_count, "mass": int(merged.mass), "text": str(merged.text)})
	check(final_states[0].rect == final_states[1].rect and is_equal_approx(final_states[0].age, final_states[1].age)
		and final_states[0].coins == final_states[1].coins and final_states[0].fragments == final_states[1].fragments
		and final_states[0].mass == final_states[1].mass and final_states[0].text == final_states[1].text,
		"whole and sliced frames agree on deferred falling placement, readiness, words, and rewards")


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


func _test_full_board() -> void:
	var model = _model([_word("cat")])
	var parts: Array[String] = []
	for index in range(Model.CAPACITY):
		parts.append("a")
	parts[0] = "cat"
	parts[1] = "picture:cat"
	_board(model, parts)
	check(not model.can_drop_now(), "full board blocks manual supply")
	var merged: Dictionary = _merge(model, 1000, 1001)
	check(merged.mass == 2, "even a full board allows a merge")
	_assert_board(model, "full board merge")
	model.step(Model.SETTLE_SECONDS + 0.01)
	check(model.full_elapsed < 0.0 and model.can_drop_now(), "merging into one ordinary cell frees capacity and clears full-board danger")
	check(model.drop_now(), "the single reopened lane admits one fresh preview")
	model.step(3.0)
	check(model.full_elapsed >= 0.0, "danger begins only after settled occupancy fills the well")
	model.set_paused(true)
	var elapsed: float = model.full_elapsed
	model.step(Model.FULL_SECONDS)
	check(model.full_elapsed == elapsed and model.phase == "playing", "pause freezes full-board danger")
	model.set_paused(false)
	model.step(Model.FULL_SECONDS)
	check(model.phase == "finished", "unrelieved full board ends the round")
	check(model.finish_round().reason == "danger", "Danger expiry identifies its game-over result")


func _test_independent_operations() -> void:
	var model = _model([_word("cat")])
	_board(model, ["merged:cat:1", "merged:cat:1", "merged:cat:1", "merged:cat:1"], [1, 1, 1, 1])
	check(model.try_merge(1000, 1001) == "merged" and model.try_merge(1002, 1003) == "merged", "disjoint pairs can fuse concurrently")
	check(model.try_merge(1000, 1002) == "ignored", "concurrent fusions reserve their source IDs")
	model.step(Model.FUSION_SECONDS + Model.SETTLE_SECONDS)
	check(model.cells.size() == 2 and model.cells[0].text == "cat" and model.cells[1].text == "cat", "concurrent pairs become two distinct persistent words")
	var events: Dictionary = _observe(model)
	check(model.collect(int(model.cells[0].id)) and model.collect(int(model.cells[1].id)), "disjoint valid words can collect concurrently")
	model.step(Model.COLLECT_SECONDS)
	check(model.cells.is_empty() and model.collected_coins == 100 and model.fragment_count == 4, "concurrent collections conserve all coins and fragments")
	check(events.milestones == [[0, 1]] and events.collections.size() == 2, "simultaneous rewards unlock a chest exactly once")


func _test_lifecycle_reentry() -> void:
	var model = _model([_word("cat")])
	_board(model, ["merged:cat:1", "merged:cat:1"])
	var events: Dictionary = _observe(model)
	model.fusion_started.connect(func(_payload: Dictionary) -> void: model.finish_round(), CONNECT_ONE_SHOT)
	model.try_merge(1000, 1001)
	check(model.phase == "finished" and model.fusions.is_empty() and events.cues.is_empty(), "ending during merge start suppresses stale cue and work")
	check(model.finish_round().coins == 0, "interrupted merge grants no reward")
	model = _model([_word("cat")])
	events = _observe(model)
	_board(model, ["merged:cat:1", "merged:cat:1"])
	var merged: Dictionary = _merge(model, 1000, 1001)
	model.step(Model.SETTLE_SECONDS)
	model.collect(int(merged.id))
	model.step(Model.POP_SECONDS)
	var interrupted: Dictionary = model.finish_round()
	model.step(100.0)
	check(interrupted.coins == 0 and model.collected_coins == 0 and model.cells.size() == 1 and events.attempts.is_empty(),
		"ending before collection credit grants neither rewards nor mastery")
	model = _model([_word("cat")])
	events = _observe(model)
	_board(model, ["merged:cat:1", "merged:cat:1"])
	merged = _merge(model, 1000, 1001)
	model.step(Model.SETTLE_SECONDS)
	model.credit_collection = func(_id: String, _amount: int) -> Dictionary:
		model.configure([_word("sunflower")], 3, 11)
		return {"ok": true}
	model.collect(int(merged.id))
	model.step(Model.COLLECT_SECONDS)
	check(model.cells.size() == Model.INITIAL_SETTLED_TILES and model.collected_coins == 0 and model.fusions.is_empty(), "wallet callback cannot mutate a replaced round")
	check(events.attempts.is_empty(), "replacing a round before collection commit grants no old-word mastery")
	model.credit_collection = Callable()
	for action: String in ["pause", "finish", "reconfigure"]:
		model = _model([_word("cat")])
		events = _observe(model)
		_board(model, ["merged:cat:1", "merged:cat:1"])
		merged = _merge(model, 1000, 1001)
		model.step(Model.SETTLE_SECONDS)
		var on_collected: Callable = func(id: String, _word_data: Dictionary, _coins: int, _fragments: int) -> void:
			check(events.attempts == [{"id": id, "words": ["cat"], "correct": true}],
				"mastery is committed before the collection presentation can " + action)
			match action:
				"pause": model.set_paused(true)
				"finish": model.finish_round()
				"reconfigure": model.configure([_word("sunflower")], 3, 11)
		model.collected.connect(on_collected, CONNECT_ONE_SHOT)
		model.collect(int(merged.id))
		model.step(Model.COLLECT_SECONDS)
		if action == "finish":
			check(model.phase == "finished" and model.finish_round().coins == 50 and model.finish_round().words.size() == 1,
				"ending inside reward callback sees an atomically committed result")
		elif action == "pause":
			check(model.paused and model.collected_coins == 50, "presentation pause follows the committed collection")
			model.set_paused(false)
		else:
			check(model.collected_coins == 0 and model.cells.size() == Model.INITIAL_SETTLED_TILES,
				"presentation reconfiguration starts a clean round after old-word mastery is retained")
		model.step(Model.COLLECT_SECONDS)
		check(events.attempts.size() == 1, "collection mastery survives presentation " + action + " without replay")
	model = _model([_word("cat")])
	events = _observe(model)
	_board(model, ["merged:cat:1", "merged:cat:1"], [2, 2])
	merged = _merge(model, 1000, 1001)
	model.step(Model.SETTLE_SECONDS)
	model.word_attempted.connect(func(_id: String, _words: Array[String], _correct: bool) -> void:
		model.configure([_word("sunflower")], 3, 11), CONNECT_ONE_SHOT)
	model.collect(int(merged.id))
	model.step(Model.COLLECT_SECONDS)
	check(events.attempts.size() == 1 and events.collections.is_empty() and events.milestones.is_empty(),
		"reconfiguration from mastery suppresses the old collection presentation and chest milestone")
	check(model.collected_coins == 0 and model.fragment_count == 0 and model.fusions.is_empty()
		and model.cells.size() == Model.INITIAL_SETTLED_TILES,
		"a mastery callback cannot apply the old collection to its replacement round")


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
	check(a.can_drop_now(), "manual supply remains available while the prior batch falls")
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


func _test_mastery_supply() -> void:
	var words: Array = []
	var mastered_ids: Dictionary = {}
	for text: String in ["cat", "dog", "hat", "sun", "moon", "star", "fish", "duck", "book", "ball", "car", "tree", "boat", "frog", "apple", "bird"]:
		words.append(_word(text))
		if words.size() <= 8:
			mastered_ids[text] = true
	var live: Dictionary = {"active": false, "calls": 0}
	var model := Model.new()
	model.practice_weight_for = func(word: Dictionary) -> float:
		live.calls += 1
		return 0.8 if bool(live.active) and mastered_ids.has(str(word.id)) else 1.0
	check(model.configure(words, 3, 419), "a mixed live-mastery catalog starts Jelly Words")
	model.spawn_interval = 10000.0
	var preview: Array = model.upcoming.duplicate(true)
	var before_calls: int = int(live.calls)
	live.active = true
	model._fill_upcoming()
	check(model.upcoming == preview, "new mastery cannot replace already advertised Jelly Words chunks")
	var emitted: Array = model.cells.duplicate(true)
	for packet_index in range(481):
		preview = model.upcoming.duplicate(true)
		emitted.append_array(preview)
		model.cells.clear()
		check(model.drop_now(int(preview[0].id)), "weighted Jelly Words supply continues over many catalog cycles")
		for root: Dictionary in preview:
			var released: Dictionary = model.cell(int(root.id))
			check(str(released.text) == str(root.text) and int(released.supply_group) == int(root.supply_group)
				and int(released.supply_part) == int(root.supply_part) and int(released.fragments) == int(root.fragments),
				"mastery weighting preserves committed chunk spelling, pairing, and fragments")
		model.step(_latest_arrival_ready(model))
	var counts: Dictionary = {}
	var group_parts: Dictionary = {}
	for root: Dictionary in emitted:
		var group: int = int(root.supply_group)
		group_parts[group] = int(group_parts.get(group, 0)) + 1
		if int(root.supply_part) == 0:
			var id: String = str(root.source_word_id)
			counts[id] = int(counts.get(id, 0)) + 1
	var mastered: int = 0
	var unmastered: int = 0
	for word_id: String in counts:
		if mastered_ids.has(word_id):
			mastered += int(counts[word_id])
		else:
			unmastered += int(counts[word_id])
	var ratio: float = float(mastered) / float(unmastered)
	check(ratio > 0.76 and ratio < 0.84,
		"Jelly Words gently lowers mastered source frequency beyond the opening packets: %.3f" % ratio)
	check(counts.size() == words.size() and counts.values().min() >= 60,
		"every mastered Jelly Words entry remains available for regular review")
	check(group_parts.values().all(func(count: int) -> bool: return count == 2),
		"long weighted supply still emits both complementary chunks for every selected word")
	check(int(live.calls) > before_calls and model.phase == "playing",
		"future packets consult live mastery without restarting the Jelly Words round")


func _curated_word(text: String, parts: Array[String]) -> Dictionary:
	var word: Dictionary = _word(text)
	word.jelly_parts = parts
	return word


func _assert_supply_packet(packet: Array, label: String) -> void:
	check(packet.size() == Model.UPCOMING_COUNT, label + ": each advertised packet contains five roots")
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
		var expected_parts: Array = [str(source.text), str(source.text)]
		check(int(root.get("supply_parts", 0)) == expected_parts.size(), label + ": the complete source part count survives mixing")
		check(part_index >= 0 and part_index < expected_parts.size(), label + ": original part indexes stay in range")
		if part_index < 0 or part_index >= expected_parts.size():
			continue
		check(str(root.text) == str(expected_parts[part_index]), label + ": every part retains its exact curated spelling")
		check(int(root.mass) == 1 and int(root.parts_count) == 1 and int(root.width) == 1 and int(root.height) == 1
			and str(root.jelly_kind) == ("root" if part_index == 0 else "picture") and root.word.is_empty(), label + ": mixing preserves one-cell unmerged roots")
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
		var expected_parts: Array = [str(group.source.text), str(group.source.text)]
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
					if part_index == 0:
						spelling = str(group.parts[part_index].text)
			check(spelling == str(group.source.text), label + ": all emitted parts reconstruct their vocabulary word")
			check(int(group.fragments) == (1 if group_id % 2 == 0 else 0),
				label + ": complete source emissions preserve the established fragment frequency")
	return groups


func _test_supply_packets() -> void:
	var cat: Dictionary = _curated_word("cat", ["cat", "picture:cat"])
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
				check(model.generated_tiles == generated_before + Model.DROP_COUNT, label + ": each released packet contributes exactly five roots")
				for root: Dictionary in preview:
					var released: Dictionary = model.cell(int(root.id))
					for key in ["text", "mass", "parts_count", "fragments", "chest", "supply_group", "supply_part", "supply_parts", "source_word_id"]:
						check(released.get(key) == root.get(key), label + ": release preserves advertised " + key)
				var ready: float = _latest_arrival_ready(model)
				model.step(ready)
				repeated.step(ready)
				check(model.snapshot() == repeated.snapshot(), label + ": packet mixing and arrival remain deterministic across rounds of supply")
				check(model.can_drop_now(), label + ": the next packet remains available after batch recovery")
			var groups: Dictionary = _assert_supply_conservation(emitted, words, label)
			if vocabulary_index == 2:
				var crossed_groups: int = 0
				for group: Dictionary in groups.values():
					if group.packets.size() > 1:
						crossed_groups += 1
				check(crossed_groups > 0, label + ": complementary pairs crossing five-root packet boundaries retain both original parts")


func _test_all_age_complementary_supply() -> void:
	var vocabulary: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	check(vocabulary is Array and not vocabulary.is_empty(), "Production vocabulary loads for the hybrid supply audit")
	if not vocabulary is Array or vocabulary.is_empty():
		return
	var audited: int = 0
	for age in range(3, 13):
		var model := Model.new()
		check(model.configure(vocabulary, age, 42), "Every supported age has eligible hybrid vocabulary")
		for word: Dictionary in vocabulary:
			if not model._eligible(word, age):
				continue
			model.cells.clear()
			model.fusions.clear()
			var root: Dictionary = model._new_word_root(word)
			check(root.text == str(word.text),
				"Unreviewed production vocabulary remains an intact root: " + str(word.id))
			root.column = 0
			model.cells.append(root)
			if str(word.get("image", "")).is_empty():
				check(model.is_valid_word(root), "An image-less atomic source is immediately merged")
			else:
				var picture: Dictionary = model._new_picture_tile(word)
				picture.column = 1
				model.cells.append(picture)
				check(model.try_merge(int(picture.id), int(root.id)) == "merged"
					and str(model.fusions[0].word.id) == str(word.id),
					"The exact production picture and root match in either direction: " + str(word.id))
			audited += 1
	check(audited > 100, "The audit exercises the complete eligible production vocabulary")
	for spelling: String in ["rainbow", "sunflower", "ice cream", "cat"]:
		var word: Dictionary = _word(spelling)
		word.jelly_parts = ["arbitrary", "chunks"]
		var model = _model([word])
		var supplied_roots: Array = model.upcoming.filter(func(tile: Dictionary) -> bool: return tile.get("jelly_kind") == "root")
		check(not supplied_roots.is_empty() and supplied_roots.all(func(tile: Dictionary) -> bool: return tile.text == spelling),
			"Legacy chunk hints cannot split the actual supply preview without reviewed morphology")

func _test_supply_preview_stability() -> void:
	var model = _model([_curated_word("cat", ["cat", "picture:cat"]), _curated_word("sunflower", ["sun", "flow", "er"])])
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
	check(not model.drop_now(int(preview[0].id)) and model.upcoming == following, "a stale token cannot consume the following packet while its predecessor is falling")
	model.step(_latest_arrival_ready(model))
	check(model.upcoming == following, "settling the current packet preserves the next advertised packet byte for byte")


func _test_immediate_manual_batches() -> void:
	var model = _model([_word("cat")])
	var previous: Array = model.cells.duplicate(true)
	for batch in range(5):
		var advertised: Array = model.upcoming.duplicate(true)
		check(model.can_drop_now() and model.drop_now(int(advertised[0].id)),
			"each immediate Next activation accepts its committed packet before earlier arrivals land")
		check(model.cells.slice(0, previous.size()) == previous and is_zero_approx(model.spawn_elapsed),
			"a rapid packet does not rewind or relocate any previously released body")
		for item: Dictionary in advertised:
			var arrival: Dictionary = model.cell(int(item.id))
			check(not arrival.is_empty() and arrival.text == item.text and arrival.fragments == item.fragments
				and is_zero_approx(float(arrival.age)), "rapid packets preserve every root and carried chest fragment exactly once")
		previous = model.cells.duplicate(true)
		_assert_board(model, "rapid packet %d" % batch)
	check(model.cells.size() == Model.CAPACITY and model.full_elapsed < 0.0,
		"rapid packets reserve a full board while danger still waits for landing")
	var full: Dictionary = model.snapshot()
	check(not model.can_drop_now() and not model.drop_now() and model.snapshot() == full,
		"rapid dispatch still refuses to consume roots when every entry lane is reserved")
	_assert_arrival_lane_clearance(model, "rapid packets")
	model.step(_latest_arrival_ready(model))
	check(is_zero_approx(model.full_elapsed), "danger begins only after the last rapid packet recovers")
	_assert_board(model, "rapid packets after landing")


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
	var onset_slots: Array[int] = [0, 3, 1, 4, 2]
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
				"unrestricted lanes launch in the alternating 0, 3, 1, 4, 2 preview-slot order")
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
	for tile: Dictionary in model.cells:
		if model.is_settled(tile) and model.parts_compatible(model.cell(first_id), tile):
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
	check(model.can_drop_now(), "Next remains available while earlier roots recover")
	var frozen: Dictionary = model.snapshot()
	model.set_paused(true)
	model.step(5.0)
	check(model.cells == frozen.cells and model.upcoming == frozen.upcoming and model.spawn_elapsed == frozen.spawn_elapsed,
		"pause freezes arrival positions, stagger ages, and the next supply clock")
	model.set_paused(false)
	model.step(first_ready - first_contact - 0.001)
	check(not model.is_settled(model.cell(first_id)) and model.can_drop_now(), "the body's input waits for recovery without blocking Next")
	model.step(0.001)
	check(model.is_settled(model.cell(first_id)) and not bool(model.cell(first_id).settling), "first root becomes ready at its own exact recovery boundary")
	check(not model.is_settled(model.cell(last_id)) and model.can_drop_now(), "the last staggered root retains its later readiness deadline independently of Next")
	model.step(last_ready - first_ready)
	check(model.can_drop_now(), "Next remains available after the complete batch recovers")
	for id in incoming:
		check(model.is_settled(model.cell(id)) and not bool(model.cell(id).settling), "each arrived root completes its settling flag and readiness together")
	check(model.try_merge(first_id, target_id) == "merged", "An arrived root or picture can match after recovery")
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
	check(automatic.generated_tiles == Model.INITIAL_SETTLED_TILES + Model.DROP_COUNT, "automatic supply starts one five-root batch at its existing deadline")
	for id in incoming:
		check(manual.cell(id) == automatic.cell(id), "manual and automatic arrival share identities, placement, delays, and clocks")
	var latest_ready: float = _latest_arrival_ready(automatic)
	automatic.step(latest_ready)
	check(automatic.can_drop_now() and is_equal_approx(automatic.spawn_elapsed, latest_ready), "descent does not pause or restart the next automatic supply timer")
	check(is_equal_approx(automatic.spawn_interval, 20.0) and is_equal_approx(Model.MIN_SPAWN_INTERVAL, 10.0),
		"a fresh round keeps the twenty-second opening while successful play can earn the ten-second floor")


func _pacing_ready_word(model) -> int:
	var completed: int = model.cleared_pairs
	var interval: float = model.spawn_interval
	_board(model, ["cat", "picture:cat"])
	var word: Dictionary = _merge(model, 1000, 1001)
	model.step(Model.SETTLE_SECONDS)
	check(model.cleared_pairs == completed and is_equal_approx(model.spawn_interval, interval),
		"building a valid word does not count as a collection or change the advertised supply interval")
	return int(word.get("id", -1))


func _test_pacing_progression() -> void:
	var model := Model.new()
	model.configure([_word("cat")], 3, 42)
	var events: Dictionary = _observe(model)
	check(model.cleared_pairs == 0 and is_equal_approx(model.spawn_interval, 20.0),
		"zero completed collections retain the beginner supply interval")
	for count in range(1, 25):
		var id: int = _pacing_ready_word(model)
		var interval: float = model.spawn_interval
		check(model.collect(id), "pacing progression uses an accepted completed-word collection")
		model.step(Model.COLLECT_SECONDS)
		check(model.cleared_pairs == count and events.collections.size() == count
			and is_equal_approx(model.spawn_interval, interval),
			"each real collection commits success once while retaining the current packet's advertised interval")
		var generated: int = model.generated_tiles
		if count % 8 != 0:
			check(model.drop_now(), "manual Next applies earned pacing immediately without adding a cooldown")
		else:
			model.step(model.spawn_interval - model.spawn_elapsed - 0.001)
			check(model.generated_tiles == generated, "the current packet keeps its full advertised deadline after collection")
			model.step(0.001)
		var expected_interval: float = maxf(10.0, 20.0 - floorf(float(count) / 4.0) * 2.0)
		check(model.generated_tiles == generated + Model.DROP_COUNT and is_zero_approx(model.spawn_elapsed)
			and is_equal_approx(model.spawn_interval, expected_interval),
			"%d successfully collected words start the next five-root cycle at %.1f seconds" % [count, expected_interval])
	check(model.configure([_word("cat")], 3, 42) and model.cleared_pairs == 0
		and is_zero_approx(model.spawn_elapsed) and is_equal_approx(model.spawn_interval, 20.0),
		"a replacement round restores the beginner supply interval and discards earned acceleration")


func _pacing_prime_stage(model) -> void:
	for count in range(1, Model.CLEARS_PER_DIFFICULTY_STAGE):
		var id: int = _pacing_ready_word(model)
		check(model.collect(id), "A pacing stage is earned with ordinary word collection")
		model.step(Model.COLLECT_SECONDS)
		check(model.cleared_pairs == count and is_equal_approx(model.spawn_interval, 20.0),
			"Fewer than four collections retain the opening stage")


func _test_pacing_cycle_commit() -> void:
	for dispatch: String in ["automatic", "manual", "blocked"]:
		var model := Model.new()
		model.configure([_word("cat")], 3, 42)
		_pacing_prime_stage(model)
		var id: int = _pacing_ready_word(model)
		model.step(Model.INITIAL_SPAWN_INTERVAL - model.spawn_elapsed - Model.COLLECT_SECONDS - 0.1)
		check(model.collect(id), "a late-cycle completed word can start its ordinary collection")
		model.step(Model.COLLECT_SECONDS)
		var generated: int = model.generated_tiles
		var upcoming: Array = model.upcoming.duplicate(true)
		check(model.cleared_pairs == 4 and generated == Model.INITIAL_SETTLED_TILES
			and is_equal_approx(model.spawn_interval, 20.0) and is_equal_approx(model.spawn_elapsed, 19.9),
			"a successful collection near release cannot advance anticipation or dispatch a surprise batch")
		if dispatch == "blocked":
			_fill_rows(model, 0, Model.ROWS - 1)
			check(not model.drop_now(), "a sealed well still rejects manual supply")
			model._spawn_drop()
			check(model.generated_tiles == generated and model.upcoming == upcoming
				and is_equal_approx(model.spawn_interval, 20.0),
				"a packet that cannot place any root cannot latch pending difficulty")
			continue
		if dispatch == "manual":
			check(model.drop_now(int(upcoming[0].id)), "manual Next can immediately release the advertised roots")
		else:
			model.step(0.099)
			check(model.generated_tiles == generated, "the loaded preview retains its original remaining time")
			model.step(0.001)
		check(model.generated_tiles == generated + Model.DROP_COUNT and is_zero_approx(model.spawn_elapsed)
			and is_equal_approx(model.spawn_interval, 18.0),
			"a successful %s dispatch starts a full faster cycle after four collected words" % dispatch)
		for tile: Dictionary in upcoming:
			check(not model.cell(int(tile.id)).is_empty(), "difficulty changes preserve the advertised root identities")
	var failed = _model([_word("cat")])
	failed.spawn_interval = Model.INITIAL_SPAWN_INTERVAL
	_batch_board(failed, 1)
	failed.credit_collection = func(_id: String, _amount: int) -> Dictionary: return {"ok": false}
	check(failed.collect(1000), "the failed-save fixture starts a real lucky collection")
	failed.step(Model.COLLECT_SECONDS)
	check(failed.cleared_pairs == 0 and failed.drop_now() and is_equal_approx(failed.spawn_interval, 20.0),
		"a failed collection save never earns faster supply on the next dispatch")
	failed.credit_collection = Callable()


func _test_pacing_boundary_determinism() -> void:
	for lead: float in [0.0, 0.1]:
		var whole := Model.new()
		var sliced := Model.new()
		for model in [whole, sliced]:
			model.configure([_word("cat")], 3, 42)
			_pacing_prime_stage(model)
			var id: int = _pacing_ready_word(model)
			model.step(Model.INITIAL_SPAWN_INTERVAL - model.spawn_elapsed - Model.COLLECT_SECONDS - lead)
			check(model.collect(id), "boundary pacing uses a real completed-word collection")
		var duration: float = Model.COLLECT_SECONDS + lead + 0.25
		whole.step(duration)
		var remaining: float = duration
		while remaining > Model.EPSILON:
			var delta: float = minf(0.01, remaining)
			sliced.step(delta)
			remaining -= delta
		var snapshots: Array = [whole.snapshot(), sliced.snapshot()]
		for state: Dictionary in snapshots:
			state.spawn_elapsed = snappedf(float(state.spawn_elapsed), 0.000001)
			state.combo.remaining = snappedf(float(state.combo.remaining), 0.000001)
			for cell: Dictionary in state.cells:
				cell.age = snappedf(float(cell.age), 0.000001)
		check(snapshots[0] == snapshots[1] and whole.cleared_pairs == 4
			and whole.generated_tiles == Model.INITIAL_SETTLED_TILES + Model.DROP_COUNT
			and is_equal_approx(whole.spawn_interval, 18.0) and is_equal_approx(whole.spawn_elapsed, 0.25),
			"coarse and fine frames latch the same next interval when collection finishes before or exactly on dispatch")


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


func _test_arrival_preview_columns() -> void:
	for dispatch: String in ["manual", "automatic"]:
		var model = _model([_word("cat")])
		model.cells.clear()
		var roofs: Array[int] = [4, 7, 3, 6, 2]
		for column in range(Model.COLUMNS):
			for row in range(roofs[column], Model.ROWS):
				model.cells.append(_placed_tile(2000 + row * Model.COLUMNS + column, "x", column, row))
		for batch_index in range(2):
			var advertised: Array = model.upcoming.duplicate(true)
			if dispatch == "manual":
				check(model.drop_now(int(advertised[0].id)), "Consecutive manual packets can enter before the earlier packet settles")
			else:
				model.step(model.spawn_interval - model.spawn_elapsed)
			for slot in range(advertised.size()):
				var tile: Dictionary = model.cell(int(advertised[slot].id))
				check(not tile.is_empty() and tile.text == advertised[slot].text and tile.column == slot
					and tile.row == roofs[slot] - batch_index - 1 and tile.arrival_index == slot,
					"%s supply drops the committed preview straight into its own open column even above uneven stacks" % dispatch)
			_assert_board(model, "%s preview lanes, batch %d" % [dispatch, batch_index])
	var blocked = _model([_word("cat")])
	blocked.cells.clear()
	for row in range(Model.ROWS):
		blocked.cells.append(_placed_tile(2000 + row, "x", 0, row))
	var advertised: Array = blocked.upcoming.duplicate(true)
	check(blocked.drop_now(), "Open preview columns can release while the first column remains blocked")
	for slot in range(advertised.size()):
		var tile: Dictionary = blocked.cell(int(advertised[slot].id))
		if slot == 0:
			check(tile.is_empty() and blocked.upcoming[slot] == advertised[slot],
				"A blocked preview retains its original slot and complete identity")
			continue
		check(not tile.is_empty() and tile.arrival_index == slot and tile.text == advertised[slot].text,
			"Skipping a blocked first column preserves every later root's visible launch slot")
		check(tile.column == slot and tile.row == Model.ROWS - 1,
			"Every admitted root falls only into its own column without a redirected neighbor")
	_assert_arrival_lane_clearance(blocked, "blocked preview lane")
	_assert_board(blocked, "fixed blocked preview slot")


func _blocked_preview_model():
	var model = _model([_word("father"), _word("happy"), _word("sleep"), _word("play"), _word("foot")])
	model.cells.assign([_placed_tile(1000, "play", 0, 0, 2, 1, _word("play")),
		_placed_tile(1001, "foot", 4, 0, 2, 1, _word("foot")),
		_placed_tile(1002, "play", 1, 0, 2, 1, _word("play"))])
	for column in [0, 1, 4]:
		for row in range(1, Model.ROWS):
			model.cells.append(_placed_tile(2000 + row * Model.COLUMNS + column, "x", column, row))
	model.upcoming.clear()
	var parts: Array[String] = ["fat", "hap", "sle", "her", "py"]
	for slot in range(parts.size()):
		model.upcoming.append(model._new_tile(parts[slot], 1, 1 if slot % 2 == 0 else 0))
	return model


func _assert_advertised_root(tile: Dictionary, advertised: Dictionary, column: int, row: int, label: String) -> void:
	check(not tile.is_empty(), label + ": the expected advertised root arrives")
	if tile.is_empty():
		return
	check(tile.column == column and tile.row == row and tile.arrival_index == column,
		label + ": the root retains its own preview column and launch slot")
	for key in ["id", "text", "mass", "parts_count", "fragments", "chest", "word", "kind"]:
		check(tile.get(key) == advertised.get(key), label + ": arrival preserves advertised " + key)


func _test_arrival_blocked_preview_slots() -> void:
	for dispatch: String in ["manual", "automatic"]:
		var model = _blocked_preview_model()
		var original: Array = model.upcoming.duplicate(true)
		var generated: int = model.generated_tiles
		var existing_count: int = model.cells.size()
		for batch in range(3):
			var advertised: Array = model.upcoming.duplicate(true)
			if dispatch == "manual":
				check(model.drop_now(), "manual release accepts the two open middle columns")
			else:
				model.spawn_elapsed = model.spawn_interval - 0.01
				model.step(0.01)
			check(model.generated_tiles == generated + (batch + 1) * 2 and model.cells.size() == existing_count + (batch + 1) * 2,
				"%s release adds exactly the two admitted roots while three preview columns are blocked" % dispatch)
			check(is_zero_approx(model.spawn_elapsed), "%s partial release resets the supply timer once" % dispatch)
			for slot in range(Model.UPCOMING_COUNT):
				var tile: Dictionary = model.cell(int(advertised[slot].id))
				if slot in [2, 3]:
					_assert_advertised_root(tile, advertised[slot], slot, Model.ROWS - 1 - batch,
						"%s middle-column batch %d slot %d" % [dispatch, batch, slot])
					check(model.upcoming[slot].id != advertised[slot].id,
						"only a departing preview slot receives a fresh root")
				else:
					check(tile.is_empty() and model.upcoming[slot] == original[slot],
						"fat, hap, and py stay byte-for-byte in their blocked preview slots")
			_assert_board(model, "%s screenshot lanes batch %d" % [dispatch, batch])
		var waiting: Array = model.upcoming.duplicate(true)
		check(model.collect(1000) and model.collect(1002), "collecting the two left roof words reopens their sealed preview columns")
		model.step(Model.COLLECT_SECONDS + Model.SETTLE_SECONDS)
		check(model.upcoming == waiting, "opening a lane does not consume or slide any waiting preview")
		check(model.drop_now(), "newly opened left columns release alongside the still-open middle columns")
		for slot in range(Model.UPCOMING_COUNT):
			if slot < 4:
				_assert_advertised_root(model.cell(int(waiting[slot].id)), waiting[slot], slot, 0 if slot < 2 else Model.ROWS - 4,
					"reopened left columns slot %d" % slot)
			else:
				check(model.upcoming[slot] == original[slot] and model.cell(int(original[slot].id)).is_empty(),
					"the right blocked previews remain untouched when only the left roof clears")
		waiting = model.upcoming.duplicate(true)
		check(model.collect(1001), "collecting the right roof word reopens the remaining preview column")
		model.step(Model.COLLECT_SECONDS + Model.SETTLE_SECONDS)
		check(model.drop_now(), "the original right previews can enter once their own roof clears")
		for slot in [4]:
			_assert_advertised_root(model.cell(int(original[slot].id)), original[slot], slot, 0,
				"reopened right columns slot %d" % slot)
		for slot in [0, 1]:
			check(model.upcoming[slot] == waiting[slot], "newly full left columns retain their replacement previews")
		_assert_board(model, "%s reopened screenshot lanes" % dispatch)


func _test_arrival_reserved_lanes() -> void:
	var model = _model([_word("cat")])
	model.cells.assign([_placed_tile(1000, "cat", 0, 0), _placed_tile(1001, "picture:cat", 1, 3)])
	for column in range(2, Model.COLUMNS):
		model.cells.append(_placed_tile(2000 + column, "x", column, 0))
	check(model.try_merge(1000, 1001) == "merged", "arrival reservation fixture commits an ordinary future word")
	var reserved: Dictionary = model.fusions[0].result.duplicate(true)
	check(_footprint(reserved) == Rect2i(1, 3, 1, 1),
		"future word reserves its target's entry lane before the visual merge finishes")
	var preview: Array = model.upcoming.duplicate(true)
	var generated_before: int = model.generated_tiles
	for batch in range(3):
		var advertised: Dictionary = model.upcoming[1].duplicate(true)
		check(model.drop_now(), "the remaining entry lane accepts one root during each partial dispatch")
		var tile: Dictionary = model.cell(int(advertised.id))
		_assert_advertised_root(tile, advertised, 1, 2 - batch, "arrival above reserved result")
		check(is_equal_approx(Model.arrival_delay(tile), 0.3 + float(batch) * 0.4),
			"repeated partial dispatch preserves the slot stagger and same-column clearance")
		check(model.generated_tiles == generated_before + batch + 1,
			"each dispatch consumes exactly one root from the only open preview column")
		for slot in [0, 2, 3, 4]:
			check(model.cell(int(preview[slot].id)).is_empty() and model.upcoming[slot] == preview[slot],
				"reserved and occupied top lanes retain every waiting preview in its own slot")
	check(not model.can_drop_now(), "the third same-column arrival seals the remaining reachable entry")
	var full: Dictionary = model.snapshot()
	check(not model.drop_now() and model.snapshot() == full, "a sealed reservation cannot consume any replacement preview")
	_assert_reservations(model, "arrival respects a future word roof")
	_assert_board(model, "partial arrival into a reserved lane")


func _test_arrival_same_lane_spacing() -> void:
	var model = _model([_word("cat")])
	model.cells.clear()
	for column in range(Model.COLUMNS - 1):
		model.cells.append(_placed_tile(2000 + column, "x", column, 0))
	var waiting: Array = model.upcoming.duplicate(true)
	var incoming: Array[int] = []
	var clearance: float = 0.4
	for index in range(6):
		var advertised: Dictionary = model.upcoming[Model.COLUMNS - 1].duplicate(true)
		incoming.append(int(advertised.id))
		check(model.drop_now(), "one open lane accepts its own preview on each immediate partial dispatch")
		var tile: Dictionary = model.cell(int(advertised.id))
		check(tile.column == Model.COLUMNS - 1 and tile.row == Model.ROWS - 1 - index,
			"the only reachable lane stacks new roots from the floor upward")
		check(tile.arrival_index == Model.COLUMNS - 1 and is_equal_approx(Model.arrival_delay(tile), 0.45 + float(index) * clearance),
			"repeated use of the last slot retains its stagger and 400 milliseconds of headroom")
		check(is_equal_approx(Model.arrival_contact_at(tile), Model.arrival_delay(tile) + Motion.contact_at(tile))
			and is_equal_approx(Model.settle_duration(tile), Model.arrival_delay(tile) + Motion.ready_at(tile)),
			"contact and input readiness use the stored lane delay")
		for slot in range(Model.COLUMNS - 1):
			check(model.upcoming[slot] == waiting[slot] and model.cell(int(waiting[slot].id)).is_empty(),
				"repeated use of the last slot never consumes a blocked earlier preview")
	_assert_arrival_lane_clearance(model, "same-lane batch")
	var by_readiness: Array[Dictionary] = _arrivals_by_readiness(model)
	var last_id: int = int(by_readiness.back().id)
	var last_ready: float = Model.settle_duration(model.cell(last_id))
	model.step(last_ready - 0.001)
	check(model.can_drop_now() and not model.is_settled(model.cell(last_id)),
		"long lane stagger delays the body interaction without disabling available supply")
	model.step(0.001)
	check(model.can_drop_now() and model.is_settled(model.cell(last_id)),
		"the next supply stays available after the last same-lane root recovers")
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
	check(model.drop_now(), "uneven lanes admit only their three open preview slots")
	for slot in range(incoming.size()):
		var tile: Dictionary = model.cell(incoming[slot])
		if slot < 3:
			check(not tile.is_empty() and int(tile.column) == slot and int(tile.arrival_index) == slot,
				"the first staircase dispatch retains the three admitted preview columns")
		else:
			check(tile.is_empty() and model.upcoming[slot].id == incoming[slot],
				"sealed staircase columns retain their original preview roots")
	check(model.drop_now(), "the second staircase dispatch fills only its two remaining open columns")
	var final_id: int = int(model.upcoming[0].id)
	check(model.drop_now(), "the third staircase dispatch fills only its final open column")
	var by_readiness: Array[Dictionary] = _arrivals_by_readiness(model)
	var last_id: int = int(by_readiness.back().id)
	var last_ready: float = Model.settle_duration(model.cell(last_id))
	var final_slot_ready: float = Model.settle_duration(model.cell(incoming[2]))
	check(last_id == final_id and final_slot_ready < last_ready,
		"repeated use of slot zero can recover after the first dispatch's last admitted preview")
	check(is_equal_approx(Model.arrival_delay(model.cell(final_id)), 0.8),
		"the third slot-zero root waits behind both earlier same-column arrivals")
	_assert_arrival_lane_clearance(model, "uneven-lane batch")
	model.step(final_slot_ready)
	check(model.is_settled(model.cell(incoming[2])) and not model.is_settled(model.cell(last_id))
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
