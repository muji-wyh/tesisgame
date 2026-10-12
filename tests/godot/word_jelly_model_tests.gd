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
	_test_merging_and_collection()
	_test_current_age_validation()
	_test_repeated_merge_and_fragments()
	_test_collection_timeline_and_pause()
	_test_wallet_retry()
	_test_chests()
	_test_packing_and_growth()
	_test_deferred_growth()
	_test_full_board()
	_test_independent_operations()
	_test_lifecycle_reentry()
	_test_supply_and_determinism()
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
	check(not model.is_settled(result) and bool(result.settling), "new merged result reserves its settlement window even when packed at its default coordinates")
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


func _test_deferred_growth() -> void:
	var model = _model([_word("cat")])
	model.cells.clear()
	for index in range(4):
		var tile: Dictionary = _tile(1000 + index, "ca" if index == 0 else "t" if index == 1 else "cat",
			4 if index < 2 else 2, 2 if index == 0 else 3 if index == 1 else 1,
			{} if index < 2 else _word("cat"))
		tile.width = int(tile.mass)
		model.cells.append(tile)
	for index in range(36):
		model.cells.append(_tile(1004 + index, "a"))
	check(model._pack(model.cells), "full preferred footprints can create the crowded growth fixture")
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
	check(merged.width == 6 and merged.height == 2 and merged.mass == 8,
		"collecting enough neighboring words restores a compressed jelly to its preferred wrapped size")
	check(merged.fragments == 5 and merged.text == "cat" and merged.word.id == "cat",
		"restored growth keeps the exact merged word and carried fragments")
	check(not model.is_settled(merged) and bool(merged.settling), "restored growth reserves its settlement window")
	_assert_board(model, "restored growth")
	var first_layout: Array[Dictionary] = model.cells.duplicate(true)
	check(model._pack(model.cells) and model.cells == first_layout,
		"repacking the restored footprints is stable and does not restart settlement")
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
	check(model._pack(model.cells), "a compressed footprint can expand without changing its top-left corner")
	merged = model.cell(1000)
	check(merged.column == 0 and merged.row == Model.ROWS - 2 and merged.width == 6 and merged.height == 2,
		"same-position growth restores the full preferred footprint")
	check(not model.is_settled(merged) and bool(merged.settling),
		"dimension-only growth prevents collection until its visual settlement completes")


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
