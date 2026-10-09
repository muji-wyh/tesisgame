extends SceneTree

const Model = preload("res://scripts/jelly_match_model.gd")

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
	_test_fusion_timeline()
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


func _observe(model) -> Dictionary:
	var events: Dictionary = {"attempts": [], "cues": [], "fusions": [], "chests": [], "finished": []}
	model.word_attempted.connect(func(attempt_id: String, word_ids: Array[String], correct: bool) -> void:
		events.attempts.append({"id": attempt_id, "words": word_ids.duplicate(), "correct": correct}))
	model.cue_requested.connect(func(cue: String) -> void: events.cues.append(cue))
	model.fusion_started.connect(func(payload: Dictionary) -> void: events.fusions.append(payload.duplicate(true)))
	model.chest_awarded.connect(func(count: int) -> void: events.chests.append(count))
	model.finished.connect(func(result: Dictionary) -> void: events.finished.append(result.duplicate(true)))
	return events


func _pair(model, require_settled: bool = true, chest_only: bool = false) -> Array[int]:
	for a in model.cells:
		for b in model.cells:
			if int(a.id) == int(b.id) or a.word.id != b.word.id or a.kind == b.kind:
				continue
			if require_settled and (float(a.age) + Model.EPSILON < Model.SETTLE_SECONDS
				or float(b.age) + Model.EPSILON < Model.SETTLE_SECONDS):
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
	for balance in balances.values():
		check(int(balance) == 0, label + ": word and picture supply remains balanced")
	check(model.cells.size() <= Model.CAPACITY and model.cells.size() % 2 == 0,
		label + ": board capacity and paired supply hold")
	if not model.cells.is_empty():
		check(not _pair(model, false).is_empty(), label + ": every nonempty board contains an actual pair")


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
	check(model.phase == "playing" and model.cells.size() == 8, "The initial board has eight tiles")
	check(model.generated_pairs == 4 and model.spawn_interval == 3.5, "Four pairs start at a 3.5 second spawn interval")
	var initial_ids: Array[String] = []
	var initial_chests: int = 0
	for cell in model.cells:
		if not initial_ids.has(str(cell.word.id)):
			initial_ids.append(str(cell.word.id))
		check(cell.word.min_age <= 3 and not str(cell.word.image).is_empty(), "Only pictured age-appropriate words enter the board")
		check(cell.age == 0.0, "Initial tiles use the same settling gate as later tiles")
		check(int(cell.falling_rows) == int(cell.row) + 1, "New tiles fall from the top of the board to their destination row")
		initial_chests += 1 if cell.chest else 0
	check(initial_ids.size() == 4 and initial_ids.all(func(id: String) -> bool:
		return id in ["word-0", "word-1", "word-2", "word-3"]), "Current unmastered words appear before lower learning-priority tiers")
	check(initial_chests == 1, "The third initial pair contains exactly one chest")
	var second = Model.new()
	second.configure(words, 3, 19)
	check(model.snapshot() == second.snapshot(), "A fixed seed reproduces the complete initial board")
	var copied: Dictionary = model.snapshot()
	var first_word: String = str(model.cells[0].word.id)
	copied.cells[0].word.id = "changed"
	copied.cells.clear()
	check(model.cells.size() == 8 and model.cells[0].word.id == first_word, "Snapshots cannot mutate model cells or words")
	var tile: Dictionary = model.tile_by_id(int(model.cells[0].id))
	tile.word.id = "changed"
	check(model.cells[0].word.id == first_word and model.tile_by_id(-1).is_empty(), "Tile lookup returns an isolated copy or an empty dictionary")
	check(not second.configure([context_only, _word("future", 4)], 3, 1)
		and second.cells.is_empty() and second.phase == "finished", "An empty eligible catalog fails without a partial board")
	check(not second.configure(_vocabulary(), 2, 1), "Levels below the starting age do not leak age-three words")
	check(second.configure([_word("only")], 3, 2) and second.cells.size() == 8,
		"A small pictured catalog can repeat paired words without becoming unsolvable")
	var different_orders: Dictionary = {}
	for seed_value in range(8):
		second.configure(_vocabulary(), 3, seed_value)
		var order: Array[String] = []
		for cell in second.cells:
			order.append(str(cell.word.id))
		different_orders[JSON.stringify(order)] = true
	check(different_orders.size() > 1, "Equal-priority words vary across seeded rounds")
	model.step(28.0)
	for index in range(model.cells.size()):
		var expected_priority: int = 2 if index < 8 else (1 if index < 16 else 0)
		check(int(model.cells[index].word._growth_priority) == expected_priority,
			"Current unmastered, earlier unmastered and mastered tiers enter in order")
	_assert_board(model, "Initial board")


func _test_supply_and_gravity() -> void:
	for seed_value in range(12):
		var model = Model.new()
		model.configure(_vocabulary(), 3, seed_value)
		model.step(3.49)
		check(model.cells.size() == 8, "A pair does not spawn before its interval")
		model.step(0.01)
		check(model.cells.size() == 10 and model.generated_pairs == 5, "Each interval supplies exactly two tiles")
		for pair_index in range(5, 12):
			model.step(model.spawn_interval)
			_assert_board(model, "Seed %d, generated pair %d" % [seed_value, pair_index + 1])
		check(model.cells.size() == 24 and model.full_elapsed == 0.0, "A filled board starts its countdown immediately")
		var chest_tiles: int = 0
		for cell in model.cells:
			chest_tiles += 1 if cell.chest else 0
		check(chest_tiles == 4, "Every third generated pair supplies exactly one chest tile")
		model.step(0.45)
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


func _test_fusion_timeline() -> void:
	var model = Model.new()
	var events: Dictionary = _observe(model)
	model.configure(_vocabulary(), 3, 8)
	var pair: Array[int] = _pair(model, false, true)
	check(model.try_merge(pair[0], pair[1]) == "ignored", "Falling tiles cannot start a fusion")
	model.step(Model.SETTLE_SECONDS)
	var saved_spawn: float = model.spawn_elapsed
	check(model.try_merge(pair[0], pair[1]) == "correct", "A settled word and its picture begin fusion")
	check(events.fusions.size() == 1 and events.cues == ["merge"], "Fusion emits its payload and merge cue once")
	check(events.fusions[0].a.id == pair[0] and events.fusions[0].b.id == pair[1],
		"Fusion payload preserves both source tiles for presentation")
	check(model.cells.size() == 8 and events.attempts.is_empty(), "Starting fusion keeps tiles and delays learning credit")
	check(model.try_merge(pair[1], pair[0]) == "ignored", "Repeated input during fusion cannot double-credit")
	model.step(0.69)
	check(events.cues == ["merge"], "The pop cue waits for the fusion pop point")
	model.step(0.01)
	check(events.cues == ["merge", "pop"], "The pop cue occurs at 0.7 seconds")
	model.step(0.349)
	check(model.cells.size() == 8 and events.attempts.is_empty(), "A nearly finished fusion does not credit early")
	model.step(0.001)
	check(model.cells.size() == 6 and model.fusion.is_empty() and model.cleared_pairs == 1,
		"The 1.05 second fusion clears exactly two tiles")
	check(is_equal_approx(model.spawn_elapsed, saved_spawn), "Spawning remains frozen throughout fusion")
	check(events.attempts.size() == 1 and events.attempts[0].correct
		and events.attempts[0].words.size() == 1, "A successful clear emits one unique-word learning event")
	check(model.chest_count == 1 and events.chests == [1] and events.cues == ["merge", "pop", "chest"],
		"Chest credit and its cue happen once after a marked pair clears")
	check(model.try_merge(pair[0], pair[1]) == "ignored" and events.attempts.size() == 1,
		"Removed tile IDs cannot replay learning or rewards")
	check(model.spawn_interval < 3.5 and model.spawn_interval >= 1.1, "Successful clears accelerate supply within its bounds")
	_assert_board(model, "Completed fusion")


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
	check(model.cells.size() == 8 and model.fusion.is_empty() and model.cleared_pairs == 0,
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
	model.step(28.0)
	check(model.cells.size() == 24 and model.snapshot().full_remaining == 8.0,
		"Eight paired spawns fill the board and expose an eight-second countdown")
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
	model.step(35.9)
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
	check(model.cells.size() == 24 and model.full_elapsed == 0.0 and events.cues.count("danger") == warnings + 1,
		"Filling the board again starts a fresh, complete danger window")
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
	for index in range(75):
		if model.cells.is_empty():
			model.step(model.spawn_interval - model.spawn_elapsed)
		model.step(Model.SETTLE_SECONDS)
		var pair: Array[int] = _pair(model)
		check(not pair.is_empty(), "A long round always has a pair available after supply settles")
		if pair.is_empty():
			break
		check(model.try_merge(pair[0], pair[1]) == "correct", "Long-round matching remains responsive")
		model.step(Model.FUSION_SECONDS)
		check(model.spawn_interval >= 1.1 and model.spawn_interval <= 3.5,
			"Spawn acceleration always remains within its specified limits")
		_assert_board(model, "Long-round clear %d" % index)
	check(model.cleared_pairs == 75 and model.spawn_interval == 1.1, "Acceleration reaches and holds the minimum interval")
	check(model.chest_count > 3, "Jelly rewards have no unrelated three-chest cap")
	var awarded: int = 0
	for count in events.chests:
		awarded += int(count)
	check(awarded == model.chest_count and events.attempts.size() == 75,
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
		model.step(28.45)
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
	check(reset_events.cues.is_empty() and reset_model.generated_pairs == 4,
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
		model.step(28.5)
		var expected: Array = ["danger", "merge"] if action == "fusion" else ["danger"]
		check(events.cues == expected, "A synchronous %s at the warning cannot leak another old countdown cue" % action)
		match action:
			"pause":
				check(model.paused and is_zero_approx(model.full_elapsed), "Pausing inside a warning freezes its clock at the beat")
			"finish":
				check(model.phase == "finished" and events.finished.size() == 1 and model.chest_count == 0,
					"Finishing inside a warning closes the round once without an unearned reward")
			"reset":
				check(model.phase == "playing" and model.generated_pairs == 4 and model.full_elapsed == -1.0,
					"Resetting inside a warning leaves the new round's supply and countdown untouched")
			"fusion":
				check(not model.fusion.is_empty() and is_zero_approx(model.full_elapsed) and events.attempts.is_empty(),
					"A rescue inside a warning freezes the clock without granting premature learning credit")
		model.cue_requested.disconnect(interrupt)
