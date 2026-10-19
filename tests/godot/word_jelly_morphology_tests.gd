extends SceneTree

const Model = preload("res://scripts/word_jelly_model.gd")
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
	_test_partial_and_final()
	_test_foundation01_current()
	_test_foundation02_current()
	_test_atomic_exposure_and_retry()
	_test_space_and_hints()
	_test_auto_completion()
	_test_auto_timing_and_lifecycle()
	_test_auto_keeps_preflighted_route()
	_test_preview_and_arrival()
	_test_footprint_and_schedule()
	_test_supply_conservation()
	_test_async_collection_commit()
	_test_collection_commit_lifecycle()
	_test_collection_commit_batch()
	print("Word Jelly morphology: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _part(id: String, form: String, type: String = "root") -> Dictionary:
	return {"id": id, "canonical_id": type + ":" + form, "type": type,
		"canonical": form, "surface": form}


func _node(id: String, left: String, right: String, surface: String, breaks: Array = []) -> Dictionary:
	return {"id": id, "left": left, "right": right, "surface": surface,
		"rule": "test_authored_join", "break_offsets": breaks}


func _word(id: String, text: String, parts: Array, nodes: Array = [], breaks: Array = []) -> Dictionary:
	if parts.size() == 1:
		parts[0].break_offsets = breaks
	return {"id": "sense:" + id, "text": text, "min_age": 3,
		"image": "assets/images/words/cat.png", "audio": "assets/audio/words/cat.wav",
		"morphology": {"schema": 1, "id": id, "lexeme_id": "sense:" + id,
			"text": text, "kind": "atomic" if parts.size() == 1 else "morphological",
			# Executable fixtures do not claim production editorial review.
			"review": {"status": "reviewed", "reviewer": "automated-test-fixture"},
			"parts": parts, "nodes": nodes,
			"roots": [parts[0].id] if parts.size() == 1 else [nodes.back().id]}}


func _atomic(text: String = "MRI") -> Dictionary:
	return _word(text, text, [_part("whole", text, "abbreviation")])


func _three() -> Dictionary:
	return _word("unhelpful", "unhelpful", [_part("un", "un-", "prefix"), _part("help", "help"), _part("ful", "-ful", "suffix")],
		[_node("helpful", "help", "ful", "helpful", [4]), _node("whole", "un", "helpful", "unhelpful", [2, 6])])


func _four() -> Dictionary:
	return _word("unpredictability", "unpredictability", [_part("un", "un-", "prefix"), _part("predict", "predict"),
		_part("able", "-able", "suffix"), _part("ity", "-ity", "suffix")],
		[_node("predictable", "predict", "able", "predictable", [7]),
		_node("unpredictable", "un", "predictable", "unpredictable", [2, 9]),
		_node("whole", "unpredictable", "ity", "unpredictability", [2, 9, 13])])


func _model(word: Dictionary = {}) -> RefCounted:
	var model := Model.new()
	check(model.configure([_three() if word.is_empty() else word], 3, 42), "The authored fixture configures")
	model.spawn_interval = 10000.0
	model.cells.clear()
	return model


func _sources(model: RefCounted, analysis: String, fragments: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for state: Dictionary in model._morphology.source_tiles(analysis):
		state.fragments = fragments
		var tile: Dictionary = model._new_composition_tile(state)
		var position: Vector2i = model._free_position(model._occupied(), int(tile.width), int(tile.height))
		tile.column = position.x
		tile.row = position.y
		model.cells.append(tile)
		result.append(tile)
	return result


func _settle(model: RefCounted) -> void:
	model.step(3.0)


func _merge(model: RefCounted, left: Dictionary, right: Dictionary) -> Dictionary:
	check(model.try_merge(int(left.id), int(right.id)) == "merged", "An authored pair starts its fusion")
	if model.fusions.is_empty():
		return {}
	var result_id: int = int(model.fusions[0].result.id)
	_settle(model)
	return model.cell(result_id)


func _filler(id: int, column: int, row: int) -> Dictionary:
	return {"id": id, "text": "x", "mass": 1, "parts_count": 1, "fragments": 0,
		"word": {}, "kind": "chunk", "column": column, "row": row, "width": 1, "height": 1,
		"age": Model.SETTLE_SECONDS, "settling": false, "arrival": false, "falling": false}


func _fill_except_tiles(model: RefCounted) -> void:
	var occupied: Dictionary = model._occupied()
	for row in range(Model.ROWS):
		for column in range(Model.COLUMNS):
			if not occupied.has(row * Model.COLUMNS + column):
				model.cells.append(_filler(2000 + row * Model.COLUMNS + column, column, row))


func _test_configuration() -> void:
	var model := Model.new()
	check(model.configure([_atomic("I")], 3, 1) and model.uses_authored_morphology(), "Reviewed one-character whole entries are playable")
	var initial_area: int = 0
	for tile: Dictionary in model.cells:
		initial_area += int(tile.width) * int(tile.height)
		check(tile.kind == "word" and tile.text == "I" and tile.mass == 1, "Atomic supply preserves the exact whole spelling")
	check(initial_area <= Model.INITIAL_SETTLED_TILES, "Initial authored supply uses occupied area instead of piece count")
	var professional: Dictionary = _atomic()
	professional.erase("min_age")
	professional.track = "professional"
	professional.practice_modes = ["word_jelly"]
	check(model.configure([professional], 9, 2) and model.uses_authored_morphology()
		and model.cells[0].word.id == "sense:MRI" and not model.cells[0].word.has("min_age"),
		"Reviewed Professional MRI is independent of Growth age and needs no synthetic age field")
	professional.practice_modes = ["memory"]
	check(not model.configure([professional], 9, 2), "Professional Word Jelly requires explicit practice-mode eligibility")
	professional.practice_modes = ["word_jelly"]
	professional.morphology.review.status = "pending"
	check(not model.configure([professional], 9, 2), "Pending Professional morphology cannot fall back to legacy chunks")
	var pending: Dictionary = _three()
	pending.morphology.review.status = "pending"
	check(not model.configure([pending], 3, 2), "Pending Growth analyses cannot fall back to midpoint spelling chunks")
	var pending_overlay: Dictionary = _atomic().duplicate(true)
	pending_overlay.erase("morphology")
	pending_overlay.morphology_status = "pending"
	check(not model.configure([pending_overlay], 3, 2), "An explicit pending Growth overlay cannot enter play without an analysis")
	pending_overlay = _atomic().duplicate(true)
	pending_overlay.morphology_status = "invalid"
	check(not model.configure([pending_overlay], 3, 2), "A mismatched Growth overlay cannot reuse an attached reviewed graph")
	var malformed: Dictionary = _three()
	malformed.morphology.nodes[0].left = "missing"
	check(not model.configure([malformed], 3, 3) and model.phase == "finished", "Malformed reviewed content cannot enter play")
	malformed = _three()
	malformed.morphology.lexeme_id = "another-sense"
	check(not model.configure([malformed], 3, 3), "Reviewed analysis identity must match the selected lexeme")


func _test_partial_and_final() -> void:
	var model = _model()
	var pieces: Array[Dictionary] = _sources(model, "unhelpful", 1)
	var events: Array = []
	var attempts: Array = []
	model.fusion_completed.connect(func(payload: Dictionary, reward: int): events.append([payload.duplicate(true), reward]))
	model.word_attempted.connect(func(event_id: String, ids: Array[String], correct: bool): attempts.append([event_id, ids, correct]))
	check(model.parts_compatible(pieces[1], pieces[2]) and not model.parts_compatible(pieces[0], pieces[1]), "The palette uses authored logical compatibility")
	var partial: Dictionary = _merge(model, pieces[1], pieces[2])
	check(partial.text == "helpful" and partial.kind == "part" and partial.word.is_empty(), "Three-part targets keep a legal intermediate incomplete")
	check(events.size() == 1 and events[0][0].composition_status == "partial" and events[0][0].word.is_empty() and events[0][1] == 0,
		"Partial fusion has no whole-word pronunciation payload or reward")
	check(not model.collect(int(partial.id)) and model.cleared_pairs == 0 and attempts.is_empty() and model.fragment_count == 0,
		"Partial composition is not a collection, speed-stage increment, or mastery event")
	var whole: Dictionary = _merge(model, pieces[0], partial)
	check(whole.text == "unhelpful" and whole.mass == 3 and whole.fragments == 3 and whole.composition.mastery_eligible,
		"Manual completion preserves all semantic parts and carried fragments")
	check(events.back()[0].composition_status == "complete" and events.back()[0].word.id == "sense:unhelpful" and attempts.is_empty(),
		"Only the completed fusion exposes the whole-word payload, without pre-collection mastery")
	check(model.collect(int(whole.id)), "The completed authored target is collectable")
	_settle(model)
	check(model.cleared_pairs == 1 and model.fragment_count == 3 and attempts.size() == 1, "A manual completion emits one mastery event only on collection")
	model = _model(_four())
	pieces = _sources(model, "unpredictability")
	partial = _merge(model, pieces[1], pieces[2])
	partial = _merge(model, pieces[0], partial)
	whole = _merge(model, partial, pieces[3])
	check(whole.text == "unpredictability" and whole.mass == 4 and whole.composition.part_signatures.size() == 4,
		"Four-part authored transformation does not concatenate visible affix markers")


func _winning_seed() -> int:
	var rng := RandomNumberGenerator.new()
	for seed_value in range(100000):
		rng.seed = seed_value
		if rng.randf() < Model.COIN_DROP_CHANCE:
			return seed_value
	return -1


func _test_atomic_exposure_and_retry() -> void:
	var model = _model(_atomic())
	var whole: Dictionary = _sources(model, "MRI", 2)[0]
	var attempts: Array = []
	var payments: Array = []
	model.word_attempted.connect(func(event_id: String, ids: Array[String], correct: bool): attempts.append([event_id, ids, correct]))
	model.credit_collection = func(event_id: String, coins: int) -> Dictionary:
		payments.append([event_id, coins])
		return {"ok": payments.size() > 1}
	model._coin_rng.seed = _winning_seed()
	check(Model.COIN_DROP_CHANCE == 0.01 and Model.coins_for_tile(whole) == 50, "Atomic collection uses the same fixed bonus and one-percent odds")
	check(model.collect(int(whole.id)), "Atomic exposure can collect its complete Jelly")
	_settle(model)
	var rng_state: int = model._coin_rng.state
	check(model.cleared_pairs == 0 and model.cells.size() == 1 and attempts.is_empty(), "Failed bonus persistence leaves atomic exposure uncommitted")
	check(model.collect(int(whole.id)) and model._coin_rng.state == rng_state, "Retry reuses the reserved rare-roll outcome")
	_settle(model)
	check(payments.size() == 2 and payments[0] == payments[1] and payments[0][1] == 50, "Retry retains the same receipt and fixed bonus")
	check(model.cleared_pairs == 1 and model.collected_coins == 50 and model.fragment_count == 2 and attempts.is_empty(),
		"Atomic collection advances speed once without spelling or mastery evidence")
	check(not model.collect(int(whole.id)) and model._collection_event_ids.is_empty(), "A committed atomic receipt cannot pay twice")
	model.credit_collection = Callable()


func _test_space_and_hints() -> void:
	var model = _model()
	var pieces: Array[Dictionary] = _sources(model, "unhelpful")
	# Separate the legal pair so their released cells cannot hold its full result.
	pieces[1].column = 0
	pieces[1].row = 0
	pieces[2].column = 4
	pieces[2].row = 7
	pieces[0].column = 0
	pieces[0].row = 5
	_fill_except_tiles(model)
	var before: Array = model.cells.duplicate(true)
	var next_tile: int = model._next_tile_id
	var next_event: int = model._next_event_id
	var cues: Array = []
	model.cue_requested.connect(func(cue: String): cues.append(cue))
	check(model.parts_compatible(pieces[1], pieces[2]), "Lack of room does not change linguistic compatibility")
	check(model.merge_candidate(pieces[1], pieces[2]).status == "needs_room" and model.compatible_pairs().is_empty(),
		"Live hints exclude a legal result that cannot fit its full rectangle")
	check(not model.can_merge(pieces[1], pieces[2]), "The fast view query retains authored placement requirements")
	check(model.try_merge(int(pieces[1].id), int(pieces[2].id)) == "needs_room", "Manual fusion reports room separately from incorrect spelling")
	check(model.cells == before and model.fusions.is_empty() and model._next_tile_id == next_tile and model._next_event_id == next_event and cues.is_empty(),
		"A blocked fusion consumes no inputs, IDs, events, or penalty cues")
	var purchases: Array = []
	model.purchase_powerup = func(receipt: String, kind: String, price: int) -> Dictionary:
		purchases.append([receipt, kind, price])
		return {"ok": true}
	check(not model.can_activate_powerup("auto_merge") and not model.activate_powerup("auto_merge") and purchases.is_empty(),
		"Auto merge never charges for a completion blocked by geometry")
	model.purchase_powerup = Callable()
	# A first partial fits, but neither of the later complete-word rectangles does.
	model = _model()
	pieces = _sources(model, "unhelpful")
	pieces[0].column = 0
	pieces[0].row = 0
	pieces[1].column = 0
	pieces[1].row = 7
	pieces[2].column = 4
	pieces[2].row = 7
	_fill_except_tiles(model)
	model.cells.erase(model.cell(2000 + 7 * Model.COLUMNS + 2))
	check(model.merge_candidate(pieces[1], pieces[2]).status == "partial" and model.authored_completion_plan().status == "unavailable",
		"Auto checks future result geometry even when its first partial can fit")


func _test_auto_completion() -> void:
	var model = _model()
	var pieces: Array[Dictionary] = _sources(model, "unhelpful")
	model.cells.erase(pieces[0])
	var purchases: Array = []
	model.purchase_powerup = func(receipt: String, kind: String, price: int) -> Dictionary:
		purchases.append([receipt, kind, price])
		return {"ok": true}
	check(model.parts_compatible(pieces[1], pieces[2]) and not model.can_activate_powerup("auto_merge") and not model.activate_powerup("auto_merge"),
		"A partial-only path cannot buy Auto merge")
	check(purchases.is_empty(), "Unavailable completion has no purchase callback")
	model.cells.append(pieces[0])
	var plan: Dictionary = model.authored_completion_plan()
	check(plan.status == "complete" and plan.placement_checked and plan.steps.size() == 2, "Auto preflights the full authored completion and every result rectangle")
	var attempts: Array = []
	model.word_attempted.connect(func(event_id: String, ids: Array[String], correct: bool): attempts.append([event_id, ids, correct]))
	check(model.activate_powerup("auto_merge") and purchases.size() == 1, "One valid complete plan starts one paid obligation")
	model.set_paused(true)
	var paused_state: Dictionary = model.snapshot()
	model.step(30.0)
	check(model.snapshot() == paused_state, "A paused authored Auto merge does not advance")
	model.finish_powerup()
	check(not model.powerup_active() and model.paused and model.cells.size() == 1 and model.cells[0].text == "unhelpful", "Silent exit draining finishes all authored steps while preserving pause")
	check(model.merged_count == 2 and model.cleared_pairs == 0 and model.cells[0].composition.assisted and not model.cells[0].composition.mastery_eligible,
		"Assisted completion remains uncollected and cannot create mastery evidence")
	model.set_paused(false)
	_settle(model)
	check(model.collect(int(model.cells[0].id)), "The settled assisted whole word remains collectable")
	_settle(model)
	check(model.cleared_pairs == 1 and attempts.is_empty() and purchases.size() == 1, "Collecting Auto's result does not manufacture unassisted mastery or another charge")
	model.purchase_powerup = Callable()


func _test_auto_timing_and_lifecycle() -> void:
	var expected: Array = []
	for large_frame: bool in [false, true]:
		var model = _model(_four())
		_sources(model, "unpredictability", 1)
		var purchases: Array = []
		model.purchase_powerup = func(receipt: String, kind: String, price: int) -> Dictionary:
			purchases.append([receipt, kind, price])
			return {"ok": true}
		check(model.activate_powerup("auto_merge"), "A four-part completion can start normal Auto play")
		if large_frame:
			model.step(10.0)
		else:
			for frame in range(300):
				model.step(1.0 / 30.0)
				check(model.fusions.size() <= 1 and model.powerup_snapshot().drags.size() <= 1, "Authored Auto reserves one checked step at a time")
		check(not model.powerup_active() and model.cells.size() == 1 and model.cells[0].text == "unpredictability"
			and model.cells[0].fragments == 4 and model.merged_count == 3 and purchases.size() == 1,
			"Normal Auto completes all four parts once for both fine and coarse frame sizes")
		var outcome: Array = [model.cells[0].text, model.cells[0].width, model.cells[0].height, model.cells[0].row,
			model.cells[0].column, model.cells[0].fragments, model.merged_count]
		if large_frame:
			check(outcome == expected, "Auto completion geometry and rewards are independent of frame partition")
		else:
			expected = outcome
		model.purchase_powerup = Callable()
	var exiting = _model()
	_sources(exiting, "unhelpful", 1)
	var events: Array = []
	exiting.finished.connect(func(result: Dictionary): events.append(result.duplicate(true)))
	exiting.purchase_powerup = func(_receipt: String, _kind: String, _price: int) -> Dictionary:
		exiting.finish_round("leave")
		return {"ok": true}
	check(exiting.activate_powerup("auto_merge") and exiting.phase == "finished" and not exiting.powerup_active()
		and exiting.cells.size() == 1 and exiting.cells[0].text == "unhelpful" and events.size() == 1,
		"Leaving inside an accepted purchase callback drains the full authored obligation exactly once")
	exiting.purchase_powerup = Callable()


func _test_auto_keeps_preflighted_route() -> void:
	var alternate: Dictionary = _word("unacceptable", "unacceptable",
		[_part("un", "un-", "prefix"), _part("acceptable", "acceptable", "stem")],
		[_node("whole", "un", "acceptable", "unacceptable", [2])])
	var model := Model.new()
	check(model.configure([_three(), alternate], 3, 42), "The competing completion fixture configures")
	model.spawn_interval = 10000.0
	model.cells.clear()
	var pieces: Array[Dictionary] = _sources(model, "unhelpful")
	var others: Array[Dictionary] = _sources(model, "unacceptable")
	model.cells.erase(others[0])
	pieces[0].column = 0
	pieces[0].row = 2
	pieces[1].column = 4
	pieces[1].row = 7
	pieces[2].column = 0
	pieces[2].row = 0
	others[1].column = 0
	others[1].row = 7
	_fill_except_tiles(model)
	for column in range(4):
		model.cells.erase(model.cell(2000 + 4 * Model.COLUMNS + column))
	check(model.merge_candidate(pieces[0], others[1]).status == "needs_room"
		and model.authored_completion_plan().steps.size() == 2,
		"Only the two-step target has a complete placeable route at purchase")
	model.purchase_powerup = func(_receipt: String, _kind: String, _price: int) -> Dictionary: return {"ok": true}
	var launches: Array = []
	model.powerup_drag_started.connect(func(payload: Dictionary): launches.append([payload.source_id, payload.target_id]))
	check(model.activate_powerup("auto_merge"), "The checked route begins before its first merge frees competing space")
	model.step(6.0)
	var completed: Array = model.cells.filter(func(tile: Dictionary) -> bool: return model.is_valid_word(tile))
	check(not model.powerup_active() and launches.size() == 2 and completed.size() == 1 and completed[0].text == "unhelpful"
		and not model.cell(int(others[1].id)).is_empty(),
		"Auto completes the route it started instead of stranding its partial for a newly unlocked competing word")
	model.purchase_powerup = Callable()


func _preview(model: RefCounted, tiles: Array, columns: Array) -> void:
	model.upcoming.assign([{}, {}, {}, {}, {}, {}])
	for index in range(tiles.size()):
		var tile: Dictionary = tiles[index]
		var column: int = int(columns[index])
		tile.preview_column = column
		tile.preview_span = tile.width
		model.upcoming[column] = tile
		for lane in range(column + 1, column + int(tile.width)):
			model.upcoming[lane] = {"reservation": int(tile.id), "anchor": column}


func _test_preview_and_arrival() -> void:
	var model = _model()
	var pieces: Array[Dictionary] = _sources(model, "unhelpful", 1)
	model.cells.clear()
	var wide: Dictionary = pieces[1]
	var other: Dictionary = pieces[2]
	check(wide.width >= 2 and other.width >= 2, "Preview fixtures span multiple lanes")
	_preview(model, [wide], [0])
	var head: Dictionary = model._new_composition_tile(model._morphology.source_tiles("unhelpful")[1])
	head.width = 4
	model._supply.assign([head, other])
	# Two isolated gaps are insufficient for a four-lane FIFO head.
	model.upcoming[3] = {"reservation": int(wide.id), "anchor": 0}
	model.upcoming[5] = {"reservation": int(wide.id), "anchor": 0}
	var before: Array = model.upcoming.duplicate(true)
	model._fill_upcoming()
	check(model.upcoming == before and int(model._supply[0].id) == int(head.id), "A wide FIFO head waits rather than skipping, moving, or replacing advertised cards")
	_preview(model, [wide, other], [0, 3])
	model._supply.clear()
	model.cells.append(_filler(9000, int(wide.width) - 1, 0))
	var blocked: Dictionary = wide.duplicate(true)
	var advertised: Array = [int(wide.id), int(other.id)]
	model._spawn_drop()
	check(model.upcoming[0] == blocked and model.upcoming[1].reservation == wide.id, "Any blocked covered lane preserves the whole advertised identity and fragments")
	check(model.cell(int(other.id)).column == 3 and model.cell(int(other.id)).width == other.width, "An unblocked spanning card enters through its advertised columns")
	for tile: Dictionary in model.cells:
		check(int(tile.id) == 9000 or int(tile.id) in advertised, "Refilled previews cannot depart in the same wave")
	var occupied: Dictionary = {}
	model._occupy(occupied, 0, 0, 6, 1)
	check(model._arrival_position(occupied, 0, 2, 2).x < 0, "Empty pockets below a roof are inaccessible from the preview")
	occupied.clear()
	model._occupy(occupied, 1, 2, 1, 1)
	check(model._arrival_position(occupied, 0, 2, 2) == Vector2i(0, 0), "Full-height admission stops before any covered-column obstruction")
	# A short follower must wait for a taller predecessor to leave every shared lane.
	model.cells.clear()
	wide.height = 2
	wide.row = 6
	wide.column = 0
	wide.arrival = true
	wide.age = 0.0
	wide.falling_rows = 8
	wide.arrival_delay = 0.1
	wide.arrival_index = 0
	model.cells.append(wide)
	_preview(model, [other], [1])
	model._spawn_drop()
	var follower: Dictionary = model.cell(int(other.id))
	check(not follower.is_empty() and float(follower.arrival_delay) >= 0.1 + sqrt(4.0 / 12.5),
		"Shared-lane clearance uses the preceding card's full height")


func _test_footprint_and_schedule() -> void:
	var model = _model(_atomic("Supercalifragilisticexpialidocious"))
	var whole: Dictionary = _sources(model, "Supercalifragilisticexpialidocious")[0]
	check(whole.width == 6 and whole.height == 2 and whole.requires_read and whole.text == "Supercalifragilisticexpialidocious",
		"An unwrappable target preserves exact spelling and requests the full Read view")
	var dimensions := Vector2i(whole.width, whole.height)
	model._restore_growth()
	model.set_held_tile(int(whole.id))
	check(model.begin_drag(int(whole.id)), "A measured body can be lifted")
	model.set_held_tile()
	_settle(model)
	check(Vector2i(whole.width, whole.height) == dimensions and not whole.get("lifted", false), "Drag cancellation and gravity never shrink a measured body")
	model.cells.clear()
	_preview(model, [whole], [0])
	model.cleared_pairs = 4
	model._schedule_spawn_interval()
	check(model.preview_area() == 12 and model.spawn_interval == 36.0, "The next wave uses baseline eighteen times preview area over six")
	model.cleared_pairs = 8
	model.step(0.1)
	check(model.spawn_interval == 36.0, "Later collection stages do not change the already advertised timer")
	model._schedule_spawn_interval()
	check(model.spawn_interval == 32.0, "The following schedule applies the new stage and the same measured area")


func _test_supply_conservation() -> void:
	var words: Array[String] = ["the", "very", "small", "fox", "runs", "home", "today"]
	var parts: Array = []
	var nodes: Array = []
	var surface: String = ""
	for index in range(words.size()):
		parts.append(_part("p%d" % index, words[index], "word"))
		surface += (" " if index else "") + words[index]
		if index > 0:
			nodes.append(_node("n%d" % index, "p0" if index == 1 else "n%d" % (index - 1), "p%d" % index, surface))
	var model = _model(_word("seven-part-phrase", surface, parts, nodes))
	model.upcoming.clear()
	model._supply.clear()
	model._supply_pending.clear()
	model._supply_words = 0
	var groups: Dictionary = {}
	for index in range(42):
		var tile: Dictionary = model._next_supply_tile()
		var group: int = int(tile.supply_group)
		if not groups.has(group):
			groups[group] = {"parts": [], "fragments": 0}
		groups[group].parts.append(int(tile.supply_part))
		groups[group].fragments += int(tile.fragments)
		check(tile.supply_parts == 7 and tile.composition.origins[0].supply_group == group,
			"Packet mixing preserves every authored occurrence and its origin")
	check(groups.size() == 6, "Seven-part targets span six-lane packets without losing or adding groups")
	for group: int in groups:
		groups[group].parts.sort()
		check(groups[group].parts == [0, 1, 2, 3, 4, 5, 6] and groups[group].fragments == (1 if group % 2 == 0 else 0),
			"Every supplied target retains seven parts and the every-second-target fragment rule")


func _test_async_collection_commit() -> void:
	var model := Model.new()
	check(model.configure([_atomic(), _three()], 3, 42), "The asynchronous commit fixture configures")
	model.cells.clear()
	model.spawn_interval = 10000.0
	var atomic: Dictionary = _sources(model, "MRI", 2)[0]
	var pieces: Array[Dictionary] = _sources(model, "unhelpful")
	model._coin_rng.seed = 42
	var submissions: Array = []
	var attempts: Array = []
	var fallback_calls: Array = []
	model.commit_collection = func(payload: Dictionary) -> Dictionary:
		submissions.append(payload.duplicate(true))
		payload.a.fragments = 999
		return {"pending": true}
	model.credit_collection = func(receipt: String, coins: int) -> Dictionary:
		fallback_calls.append([receipt, coins])
		return {"ok": true}
	model.word_attempted.connect(func(receipt: String, ids: Array[String], correct: bool): attempts.append([receipt, ids, correct]))
	check(model.collect(int(atomic.id)), "An ordinary zero-coin collection reaches its commit gate")
	model.step(0.5)
	check(submissions.size() == 1 and submissions[0].coins == 0 and submissions[0].event_id == submissions[0].attempt_id
		and int(submissions[0].generation) == model._generation and model.fusions[0].commit_pending,
		"Every collection, including zero coins, sends one immutable generation-scoped payload")
	check(model.cleared_pairs == 0 and model.fragment_count == 0 and not model.cell(int(atomic.id)).is_empty()
		and atomic.fragments == 2 and attempts.is_empty(), "Pending persistence preserves the body, fragments, and learning state")
	check(model.try_merge(int(pieces[1].id), int(pieces[2].id)) == "merged", "Independent board operations can continue during a pending collection")
	model.step(20.0)
	check(submissions.size() == 1 and model.merged_count == 1 and model.cleared_pairs == 0,
		"Waiting never resubmits per frame or stalls an independent fusion")
	var first: Dictionary = submissions[0]
	var rng_state: int = model._coin_rng.state
	check(model.resolve_collection_commit(first.event_id, first.generation, {"ok": false, "error": "Retry this collection."})
		and model.error == "Retry this collection." and model.fusions.is_empty(), "A failed commit restores manual retry with the adapter's error")
	check(model.collect(int(atomic.id)) and model._coin_rng.state == rng_state, "Commit retry retains its deterministic receipt and coin decision")
	model.step(0.5)
	check(submissions.size() == 2 and submissions[1].event_id == first.event_id and submissions[1].coins == first.coins,
		"Retry submits the same collection identity and reward without duplicating settlement")
	model.set_paused(true)
	check(model.resolve_collection_commit(first.event_id, first.generation, {"ok": true}) and model.cleared_pairs == 0,
		"A successful acknowledgment received while paused preserves the visual boundary")
	check(not model.resolve_collection_commit(first.event_id, first.generation, {"ok": true}), "A duplicate acknowledgment cannot settle twice")
	model.set_paused(false)
	model.step(0.01)
	check(model.cleared_pairs == 1 and model.fragment_count == 2 and fallback_calls.is_empty() and attempts.is_empty()
		and model.cell(int(atomic.id)).is_empty(), "Resume commits the accepted atomic exposure once without invoking the legacy wallet or mastery path")
	model.commit_collection = Callable()
	model.credit_collection = Callable()
	# Reconfiguration invalidates a late result, even if the caller supplies a live receipt ID.
	model = _model(_atomic())
	atomic = _sources(model, "MRI")[0]
	model.commit_collection = func(payload: Dictionary) -> Dictionary:
		submissions.append(payload.duplicate(true))
		return {"pending": true}
	model.collect(int(atomic.id))
	model.step(0.5)
	var stale: Dictionary = submissions.back()
	model.configure([_atomic()], 3, 42)
	model.cells.clear()
	model.spawn_interval = 10000.0
	atomic = _sources(model, "MRI")[0]
	model.collect(int(atomic.id))
	model.step(0.5)
	var current: Dictionary = submissions.back()
	check(not model.resolve_collection_commit(current.event_id, stale.generation, {"ok": true}) and model.cleared_pairs == 0,
		"A prior round's generation cannot acknowledge a current collection")
	check(model.resolve_collection_commit(current.event_id, current.generation, {"ok": true}) and model.cleared_pairs == 1,
		"The current round's acknowledgment remains independently valid")
	model.commit_collection = Callable()


func _test_collection_commit_lifecycle() -> void:
	for ending: String in ["leave", "danger"]:
		var model = _model(_atomic())
		var atomic: Dictionary = _sources(model, "MRI", 1)[0]
		_fill_except_tiles(model)
		var submissions: Array = []
		var endings: Array = []
		model.commit_collection = func(payload: Dictionary) -> Dictionary:
			submissions.append(payload.duplicate(true))
			return {"pending": true}
		model.finished.connect(func(result: Dictionary): endings.append(result.duplicate(true)))
		model.collect(int(atomic.id))
		model.step(0.5)
		if ending == "leave":
			check(model.finish_round("leave").is_empty(), "Leaving waits for an already submitted collection")
		model.step(60.0)
		check(model.phase == "playing" and endings.is_empty() and submissions.size() == 1,
			"Pending collection at %s cannot spin the clock or abandon its commit" % ending)
		var payload: Dictionary = submissions[0]
		check(model.resolve_collection_commit(payload.event_id, payload.generation, {"ok": true})
			and model.phase == "finished" and endings.size() == 1 and endings[0].reason == ending
			and endings[0].cleared_pairs == 1 and endings[0].fragment_count == 1,
			"The acknowledged collection enters the deferred %s result exactly once" % ending)
		model.commit_collection = Callable()
	var immediate = _model(_atomic())
	var atomic: Dictionary = _sources(immediate, "MRI")[0]
	var count: Array = []
	immediate.commit_collection = func(payload: Dictionary) -> Dictionary:
		count.append(payload.event_id)
		immediate.resolve_collection_commit(payload.event_id, payload.generation, {"ok": true})
		return {"ok": true}
	immediate.collect(int(atomic.id))
	immediate.step(2.0)
	check(count.size() == 1 and immediate.cleared_pairs == 1 and immediate.cells.is_empty(),
		"A synchronous acknowledgment inside the adapter callback cannot double-settle")
	immediate.commit_collection = Callable()


func _test_collection_commit_batch() -> void:
	var model = _model(_atomic())
	for index in range(3):
		_sources(model, "MRI", 1)
	model._coin_rng.seed = _winning_seed()
	var submissions: Array = []
	var fallback_calls: Array = []
	model.commit_collection = func(payload: Dictionary) -> Dictionary:
		submissions.append(payload.duplicate(true))
		return {"pending": true}
	model.credit_collection = func(receipt: String, coins: int) -> Dictionary:
		fallback_calls.append([receipt, coins])
		return {"ok": true}
	check(model.start_collection_batch(), "A collection batch starts with asynchronous storage")
	model.step(4.0)
	check(submissions.size() == 1 and submissions[0].coins == 50 and submissions[0].batch
		and model.collection_batch_snapshot().started == 1 and model.cells.size() == 3,
		"A pending winning collection holds the next batch transaction and all bodies")
	var first: Dictionary = submissions[0]
	var rng_state: int = model._coin_rng.state
	model.resolve_collection_commit(first.event_id, first.generation, {"ok": false})
	check(not model.collection_batch_active() and model.cleared_pairs == 0 and model.cells.size() == 3,
		"Failed batch persistence cancels the queued sequence without consuming words")
	check(model.collect(int(first.a_id)) and model._coin_rng.state == rng_state,
		"A failed batch collection can retry manually without rerolling its bonus")
	model.step(0.5)
	check(submissions.size() == 2 and submissions[1].event_id == first.event_id and submissions[1].coins == 50,
		"The manual retry retains the exact winning receipt and fifty-coin amount")
	model.resolve_collection_commit(first.event_id, first.generation, {"ok": true})
	check(model.cleared_pairs == 1 and model.collected_coins == 50 and model.fragment_count == 1
		and fallback_calls.is_empty(), "One acknowledgment settles bonus, fragments, and exposure through the shared callback")
	check(model.start_collection_batch(), "The remaining words can start a fresh batch after retry")
	model.step(4.0)
	check(submissions.size() == 3 and model.collection_batch_snapshot().started == 1,
		"The resumed batch also waits for its first persistence acknowledgment")
	var second: Dictionary = submissions.back()
	model.cancel_collection_batch()
	model.resolve_collection_commit(second.event_id, second.generation, {"ok": true})
	model.step(4.0)
	check(model.cleared_pairs == 2 and model.cells.size() == 1 and submissions.size() == 3,
		"Canceling a batch retains its submitted collection and leaves unstarted words alone")
	model.commit_collection = Callable()
	model.credit_collection = Callable()


func _foundation01_word(entry: Dictionary) -> Dictionary:
	# Model fixtures use the actual accepted graph and existing test media. This
	# does not pass or replace the separate draft lesson/media admission gates.
	return {"id": entry.id, "text": entry.text, "track": "professional",
		"practice_modes": entry.practice_modes.duplicate(), "morphology": entry.morphology.duplicate(true),
		"image": "assets/images/words/cat.png", "audio": "assets/audio/words/cat.wav"}


func _test_foundation01_current() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/lexemes/foundation-module01.json"))
	var atomic_count: int = 0
	for entry: Dictionary in document.lexemes:
		if entry.morphology.kind != "atomic":
			continue
		atomic_count += 1
		var model = _model(_foundation01_word(entry))
		var pieces: Array[Dictionary] = _sources(model, entry.morphology.id)
		check(pieces.size() == 1 and pieces[0].text == entry.text and pieces[0].kind == "word", "Actual intact Foundation01 graph supplies one whole Jelly: " + entry.text)
		var attempts: Array = []
		var collected: Array = []
		model.word_attempted.connect(func(event_id: String, ids: Array[String], correct: bool): attempts.append([event_id, ids, correct]))
		model.collected.connect(func(event_id: String, word: Dictionary, coins: int, fragments: int): collected.append([event_id, word, coins, fragments]))
		model.credit_collection = func(_id: String, _coins: int) -> Dictionary: return {"ok": true}
		_settle(model)
		check(model.collect(int(pieces[0].id)), "Actual atomic whole is collectable: " + entry.text)
		_settle(model)
		check(collected.size() == 1 and collected[0][1].id == entry.id and attempts.is_empty(), "Atomic collection retains its exact exposure identity without spelling mastery: " + entry.text)
		check(model.cleared_pairs == 1 and model.merged_count == 0, "Atomic exposure is a deliberate collection, never a composition: " + entry.text)
		model.credit_collection = Callable()
	check(atomic_count == 16, "Every current Foundation01 atomic treatment was exercised")
	var entry: Dictionary = document.lexemes.filter(func(row: Dictionary) -> bool: return row.id == "signature.written-name.n")[0]
	var model = _model(_foundation01_word(entry))
	var pieces: Array[Dictionary] = _sources(model, entry.morphology.id, 1)
	var events: Array = []
	var attempts: Array = []
	var collections: Array = []
	var payments: Array = []
	model.fusion_completed.connect(func(payload: Dictionary, reward: int): events.append([payload.duplicate(true), reward]))
	model.word_attempted.connect(func(event_id: String, ids: Array[String], correct: bool): attempts.append([event_id, ids, correct]))
	model.collected.connect(func(event_id: String, word: Dictionary, coins: int, fragments: int): collections.append([event_id, word, coins, fragments]))
	model.credit_collection = func(event_id: String, coins: int) -> Dictionary:
		payments.append([event_id, coins])
		return {"ok": true}
	check(model.merge_candidate(pieces[0], pieces[1]).status == "partial" and model.parts_compatible(pieces[0], pieces[1]), "Manual merge, palette and hint agree on the legal signature partial")
	check(not model.parts_compatible(pieces[1], pieces[0]) and not model.parts_compatible(pieces[0], pieces[2]), "Reversed and skipped signature parts are incompatible")
	var partial: Dictionary = _merge(model, pieces[0], pieces[1])
	check(partial.text == "signate" and partial.approved_break_offsets == [4.0] and partial.kind == "part" and partial.word.is_empty(), "Actual signature graph retains the bound intermediate and its readable boundary")
	check(events.size() == 1 and events[0][0].composition_status == "partial" and events[0][0].word.is_empty() and events[0][1] == 0, "Signature partial has no completed-word payload or fusion reward")
	check(not model.collect(int(partial.id)) and collections.is_empty() and attempts.is_empty() and payments.is_empty(), "Bound signate cannot collect, persist a reward or emit vocabulary assessment")
	check(model.cleared_pairs == 0 and model.fragment_count == 0 and model.collected_coins == 0 and model._completed_words.is_empty(), "Partial signature does not advance rewards or completed vocabulary")
	var plan: Dictionary = model.authored_completion_plan()
	check(plan.status == "complete" and plan.placement_checked and plan.steps.size() == 1, "Auto shares the accepted remaining signature join and preflights its full footprint")
	var final: Dictionary = _merge(model, partial, pieces[2])
	check(final.text == "signature" and final.approved_break_offsets == [4.0, 6.0] and final.word.id == entry.id and final.composition.mastery_eligible, "Manual final-e loss produces the exact unassisted signature word")
	check(attempts.is_empty() and collections.is_empty() and payments.is_empty(), "Completed fusion still waits for explicit collection")
	check(model.collect(int(final.id)), "Completed signature is collectable")
	_settle(model)
	check(collections.size() == 1 and attempts.size() == 1 and attempts[0][1] == [entry.id] and attempts[0][2], "Only deliberate final collection emits one exact spelling assessment")
	check(model.fragment_count == 3 and model.cleared_pairs == 1, "Final collection settles only the three carried fragments once")
	model.credit_collection = Callable()
	model = _model(_foundation01_word(entry))
	_sources(model, entry.morphology.id)
	var assisted_attempts: Array = []
	model.word_attempted.connect(func(event_id: String, ids: Array[String], correct: bool): assisted_attempts.append([event_id, ids, correct]))
	model.purchase_powerup = func(_id: String, _kind: String, _price: int) -> Dictionary: return {"ok": true}
	model.credit_collection = func(_id: String, _coins: int) -> Dictionary: return {"ok": true}
	check(model.activate_powerup("auto_merge"), "Signature Auto executes the same complete two-step authored plan")
	model.finish_powerup()
	_settle(model)
	check(model.cells.size() == 1 and model.cells[0].text == "signature" and model.cells[0].composition.assisted and not model.cells[0].composition.mastery_eligible, "Automatic final spelling preserves assistance through the bound intermediate")
	check(model.collect(int(model.cells[0].id)), "Assisted signature remains collectable")
	_settle(model)
	check(assisted_attempts.is_empty(), "Assisted signature cannot manufacture unassisted spelling mastery")
	model.purchase_powerup = Callable()
	model.credit_collection = Callable()


func _foundation02_word(entry: Dictionary) -> Dictionary:
	# Synthetic test media admit actual accepted graphs to the isolated model.
	# These fixtures cannot establish production lesson, image or audio readiness.
	return {"id": entry.id, "text": entry.text, "track": "professional",
		"practice_modes": entry.practice_modes.duplicate(), "morphology": entry.morphology.duplicate(true),
		"image": "assets/images/words/cat.png", "audio": "assets/audio/words/cat.wav"}


func _test_foundation02_current() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/lexemes/foundation-module02.json"))
	var counts: Dictionary = {}
	for entry: Dictionary in document.lexemes:
		var graph: Dictionary = entry.morphology
		counts[graph.kind] = int(counts.get(graph.kind, 0)) + 1
		var model = _model(_foundation02_word(entry))
		var pieces: Array[Dictionary] = _sources(model, graph.id, 1)
		check(pieces.size() == graph.parts.size(), "Actual Foundation02 supply contains every whole authored input: " + entry.text)
		for index in range(pieces.size()):
			check(pieces[index].text == graph.parts[index].surface and pieces[index].column >= 0 and pieces[index].row >= 0, "Whole source has a legal board footprint: " + entry.text)
		var attempts: Array = []
		var collections: Array = []
		model.word_attempted.connect(func(event_id: String, ids: Array[String], correct: bool): attempts.append([event_id, ids, correct]))
		model.collected.connect(func(event_id: String, word: Dictionary, coins: int, fragments: int): collections.append([event_id, word, coins, fragments]))
		model.credit_collection = func(_id: String, _coins: int) -> Dictionary: return {"ok": true}
		var whole: Dictionary = {}
		if graph.kind == "atomic":
			whole = pieces[0]
			check(whole.text == entry.text and whole.kind == "word" and not whole.composition.mastery_eligible, "Atomic source is an exact complete exposure: " + entry.text)
		else:
			var plan: Dictionary = model.authored_completion_plan()
			check(plan.status == "complete" and plan.placement_checked and plan.steps.size() == 1, "Full authored result footprint passes manual/Auto preflight: " + entry.text)
			check(model.parts_compatible(pieces[0], pieces[1]) and not model.parts_compatible(pieces[1], pieces[0]), "Palette and manual merge respect authored order: " + entry.text)
			whole = _merge(model, pieces[0], pieces[1])
			check(whole.get("text") == entry.text and whole.get("word", {}).get("id") == entry.id, "Manual result retains the exact Foundation02 sense: " + entry.text)
			check(whole.get("approved_break_offsets") == graph.nodes[0].break_offsets and whole.get("composition", {}).get("mastery_eligible", false), "Manual result keeps authored boundaries and eligibility: " + entry.text)
		check(attempts.is_empty() and collections.is_empty(), "Supply and composition wait for deliberate collection: " + entry.text)
		_settle(model)
		check(model.collect(int(whole.get("id", -1))), "Current Foundation02 whole is collectable: " + entry.text)
		_settle(model)
		check(collections.size() == 1 and collections[0][1].id == entry.id and model.cleared_pairs == 1, "Exactly one collection credits the selected sense: " + entry.text)
		if graph.kind == "atomic":
			check(attempts.is_empty() and model.merged_count == 0, "Atomic exposure creates no composition assessment: " + entry.text)
		else:
			check(attempts.size() == 1 and attempts[0][1] == [entry.id] and attempts[0][2] and model.merged_count == 1, "One deliberate unassisted composition emits one exact assessment: " + entry.text)
		check(not model.collect(int(whole.get("id", -1))), "A consumed whole cannot be collected twice: " + entry.text)
		model.credit_collection = Callable()
	check(counts == {"atomic":34, "morphological":16}, "Every current Foundation02 atomic and multipart treatment reached the model")
	for entry: Dictionary in document.lexemes:
		if entry.text not in ["submit", "reject", "error", "missing", "urgent", "procedure", "clarification", "broken", "solution"]:
			continue
		var model = _model(_foundation02_word(entry))
		_sources(model, entry.morphology.id)
		var attempts: Array = []
		model.word_attempted.connect(func(event_id: String, ids: Array[String], correct: bool): attempts.append([event_id, ids, correct]))
		model.purchase_powerup = func(_id: String, _kind: String, _price: int) -> Dictionary: return {"ok": true}
		model.credit_collection = func(_id: String, _coins: int) -> Dictionary: return {"ok": true}
		var plan: Dictionary = model.authored_completion_plan()
		check(plan.status == "complete" and plan.placement_checked, "Auto checks the whole actual result footprint first: " + entry.text)
		check(model.activate_powerup("auto_merge"), "Auto executes the actual Foundation02 graph: " + entry.text)
		model.finish_powerup()
		_settle(model)
		check(model.cells.size() == 1 and model.cells[0].text == entry.text and model.cells[0].composition.assisted and not model.cells[0].composition.mastery_eligible, "Auto retains authored spelling and assistance: " + entry.text)
		if model.cells.size() == 1:
			check(model.collect(int(model.cells[0].id)), "Assisted current whole remains collectable: " + entry.text)
		_settle(model)
		check(attempts.is_empty(), "Assisted collection cannot manufacture independent mastery: " + entry.text)
		model.purchase_powerup = Callable()
		model.credit_collection = Callable()
