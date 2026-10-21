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
	_test_explicit_cross_age_pool()
	_test_retirement_and_exhaustion(false)
	_test_retirement_and_exhaustion(true)
	_test_stage_preserves_old_bodies_and_rewards()
	_test_stage_waits_for_collection_commit()
	_test_invalid_replacement_is_atomic()
	_test_later_stage_same_spelling_sense()
	print("Word Jelly stage model: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _word(index: int, reviewed: bool = false) -> Dictionary:
	var spelling: String = "word" + char(97 + index)
	var word: Dictionary = {"id": "stage:" + spelling, "text": spelling, "min_age": 3 + index % 10,
		"image": "assets/images/words/cat.png", "audio": "assets/audio/words/cat.wav"}
	if reviewed:
		word.morphology = {"schema": 1, "id": "stage-analysis-" + spelling, "lexeme_id": word.id,
			"text": spelling, "kind": "atomic", "review": {"status": "reviewed", "reviewer": "automated-test-fixture"},
			"parts": [{"id": "whole", "canonical_id": "root:" + spelling,
				"type": "root", "canonical": spelling, "surface": spelling}], "nodes": [], "roots": ["whole"]}
	return word


func _pool(reviewed: bool = false) -> Array:
	var words: Array = []
	for index in range(10):
		words.append(_word(index, reviewed))
	return words


func _test_explicit_cross_age_pool() -> void:
	var legacy := Model.new()
	check(legacy.configure(_pool(), 3, 42) and legacy._words.size() == 1,
		"Legacy callers retain exact-age filtering")
	var stages := Model.new()
	stages.allow_cross_age = true
	check(stages.configure(_pool(), 3, 42) and stages._words.size() == 10,
		"An explicit stage pool accepts all ten eligible words across ages")
	var invalid: Dictionary = _word(12)
	invalid.morphology_status = "pending"
	check(stages.configure([invalid, _word(0)], 3, 42) and stages._words.size() == 1,
		"Cross-age play never admits pending morphology")


func _test_retirement_and_exhaustion(reviewed: bool) -> void:
	var model := Model.new()
	model.allow_cross_age = true
	check(model.configure(_pool(reviewed), 3, 42), "The stage supply fixture configures")
	var board: Array = model.cells.duplicate(true)
	var retired: Array[String] = []
	for index in range(8):
		retired.append(str(_word(index).id))
	model.retire_mastered_words(retired)
	check(model._words.size() == 2 and model.cells == board,
		"Mastering eight words retains all existing bodies while narrowing future supply to two words")
	for packet: Array in [model.upcoming, model._supply, model._supply_pending]:
		for tile: Dictionary in packet:
			check(not str(tile.get("source_word_id", "")) in retired,
				"Mastered words leave visible preview and both internal supply queues immediately")
	for drop in range(20):
		model.cells.clear()
		check(model.drop_now(), "The two remaining words can keep replenishing the board")
		for tile: Dictionary in model.cells:
			check(str(tile.get("source_word_id", "")) in [str(_word(8).id), str(_word(9).id)],
				"Every subsequent body comes from the unmastered remainder of the same stage")
	model.retire_mastered_words([str(_word(8).id), str(_word(9).id)])
	check(model._words.is_empty() and model._supply.is_empty() and model._supply_pending.is_empty()
		and model._first_preview_tile().is_empty() and not model.can_drop_now(),
		"An exhausted stage supplies no stale words and disables further drops")
	model.cells.clear()
	model.step(100.0)
	check(model.phase == "playing" and model.cells.is_empty() and model.full_elapsed < 0.0,
		"Waiting for a new stage never invents words or a false full-board countdown")


func _put(model: RefCounted, tile: Dictionary) -> Dictionary:
	var position: Vector2i = model._free_position(model._occupied(), 1, 1)
	tile.column = position.x
	tile.row = position.y
	model.cells.append(tile)
	return tile


func _test_stage_preserves_old_bodies_and_rewards() -> void:
	var word: Dictionary = _word(0, true)
	var model := Model.new()
	model.allow_cross_age = true
	check(model.configure([word], 3, 42), "The first stage has reviewed morphology")
	model.cells.clear()
	var state: Dictionary = model._morphology.source_tiles(str(word.morphology.id))[0]
	state.fragments = 3
	var root: Dictionary = _put(model, model._new_composition_tile(state))
	var picture: Dictionary = _put(model, model._new_picture_tile(word, 4))
	model.fragment_count = 5
	model.collected_coins = 150
	model.cleared_pairs = 12
	var board: Array = model.cells.duplicate(true)
	model.retire_mastered_words([word.id])
	check(model.stage_transition_ready() and model.replace_stage_words([_word(11, true)], 3),
		"A safe boundary installs the next cross-age stage")
	check(model.cells == board and model.fragment_count == 5 and model.collected_coins == 150 and model.cleared_pairs == 12,
		"Changing stage preserves the board, carried fragments, and all accumulated rewards")
	check(model.try_merge(int(root.id), int(picture.id)) == "merged",
		"An older reviewed root can still finish its picture match after stage replacement")
	var result_id: int = int(model.fusions[0].result.id)
	check(not model.stage_transition_ready() and not model.replace_stage_words([_word(12)], 3),
		"An active fusion prevents a stage replacement")
	model.step(Model.FUSION_SECONDS + Model.SETTLE_SECONDS)
	var result: Dictionary = model.cell(result_id)
	check(result.word.id == word.id and result.fragments == 7 and result.mastery_eligible,
		"The old merge retains its identity, fragments, and earned mastery eligibility")
	check(model.collect(result_id), "The old word can still be collected")
	model.step(Model.COLLECT_SECONDS)
	check(model.fragment_count == 12 and model.cleared_pairs == 13,
		"Collecting old carried fragments adds them once to the current round")
	for tile: Dictionary in model.upcoming:
		if tile.has("id"):
			check(str(tile.source_word_id) == str(_word(11).id), "Only next-stage words appear in the new preview")


func _test_stage_waits_for_collection_commit() -> void:
	var model := Model.new()
	model.allow_cross_age = true
	var word: Dictionary = _word(0)
	check(model.configure([word], 3, 4), "A transactional stage configures")
	model.cells.clear()
	var tile: Dictionary = model._new_word_root(word, 3)
	model._set_merged_word(tile, word, 4, true)
	_put(model, tile)
	var pending: Dictionary = {}
	model.commit_collection = func(payload: Dictionary) -> Dictionary:
		pending.merge(payload, true)
		return {"pending": true}
	model.collect(int(tile.id))
	model.step(Model.COLLECT_SECONDS)
	check(not pending.is_empty() and not model.stage_transition_ready()
		and not model.replace_stage_words([_word(1)], 3) and model.fragment_count == 0,
		"A pending durable collection must resolve before a stage can advance")
	check(model.resolve_collection_commit(str(pending.event_id), int(pending.generation), {"ok": false}),
		"A rejected save resolves without granting mastery or rewards")
	check(model._words.size() == 1 and model.fragment_count == 0 and not model.cell(int(tile.id)).is_empty(),
		"A failed collection leaves its word and reward available for retry")
	model.collect(int(tile.id))
	model.step(Model.COLLECT_SECONDS)
	check(model.resolve_collection_commit(str(pending.event_id), int(pending.generation), {"ok": true}),
		"The original collection receipt can be saved successfully on retry")
	model.retire_mastered_words([word.id])
	check(model.stage_transition_ready() and model.replace_stage_words([_word(1)], 3)
		and model.fragment_count == 3 and model.cleared_pairs == 1,
		"Only the successful receipt can retire the stage word and preserve its reward into the next stage")
	check(not model.resolve_collection_commit(str(pending.event_id), int(pending.generation), {"ok": true})
		and model.fragment_count == 3, "A stale acknowledgement cannot repeat a completed stage reward")
	model.commit_collection = Callable()


func _test_invalid_replacement_is_atomic() -> void:
	var model := Model.new()
	model.allow_cross_age = true
	model.configure([_word(0, true)], 3, 42)
	var snapshot: Dictionary = model.snapshot()
	var broken: Dictionary = _word(1, true)
	broken.morphology.lexeme_id = "invalid-sense"
	check(not model.replace_stage_words([broken], 3) and model.snapshot() == snapshot,
		"An invalid future pool cannot mutate the current stage or its queued supply")


func _compound(sense: String) -> Dictionary:
	return {"id": "rainbow:" + sense, "text": "rainbow", "min_age": 8,
		"image": "assets/images/words/cat.png", "audio": "assets/audio/words/cat.wav",
		"morphology": {"schema": 1, "id": "rainbow-analysis:" + sense, "lexeme_id": "rainbow:" + sense,
			"text": "rainbow", "kind": "morphological", "review": {"status": "reviewed", "reviewer": "automated-test-fixture"},
			"parts": [{"id": "rain", "canonical_id": "root:rain", "type": "root", "canonical": "rain", "surface": "rain"},
				{"id": "bow", "canonical_id": "root:bow", "type": "root", "canonical": "bow", "surface": "bow"}],
			"nodes": [{"id": "whole", "left": "rain", "right": "bow", "surface": "rainbow", "rule": "compound", "break_offsets": [4]}],
			"roots": ["whole"]}}


func _test_later_stage_same_spelling_sense() -> void:
	var older: Dictionary = _compound("older")
	var newer: Dictionary = _compound("newer")
	var model := Model.new()
	model.allow_cross_age = true
	check(model.configure([older], 3, 12), "The original compound sense configures")
	model.cells.clear()
	var old_parts: Array[Dictionary] = []
	for state: Dictionary in model._morphology.source_tiles(str(older.morphology.id)):
		old_parts.append(_put(model, model._new_composition_tile(state)))
	_put(model, model._new_picture_tile(older, 2))
	model.retire_mastered_words([older.id])
	check(model.replace_stage_words([newer], 3) and model._words[0].id == newer.id,
		"A new unmastered sense with the same spelling can enter a later stage")
	var new_parts: Array[Dictionary] = []
	for state: Dictionary in model._morphology.source_tiles(str(newer.morphology.id)):
		new_parts.append(_put(model, model._new_composition_tile(state)))
	_put(model, model._new_picture_tile(newer, 3))
	var old_merge: Dictionary = model.merge_candidate(old_parts[0], old_parts[1])
	var new_merge: Dictionary = model.merge_candidate(new_parts[0], new_parts[1])
	check(old_merge.status == "partial" and old_merge.result.word_candidate.id == older.id
		and new_merge.status == "partial" and new_merge.result.word_candidate.id == newer.id,
		"Old and new matching root origins resolve their own exact sense identity")
	check(not model.parts_compatible(old_parts[0], new_parts[1]),
		"Roots from two ambiguous senses cannot silently substitute for one another")
	model.purchase_powerup = func(_receipt: String, _kind: String, _price: int) -> Dictionary: return {"ok": true}
	check(model.activate_powerup("auto_merge"), "Auto merge still plans complete paths for retained and new senses")
	model.finish_powerup(true)
	var ids: Array[String] = []
	for tile: Dictionary in model.cells:
		if model.is_valid_word(tile):
			ids.append(str(tile.word.id))
	check(ids.size() == 2 and older.id in ids and newer.id in ids,
		"Auto merge completes both senses without merging their equal spellings into one identity")
	check(model.cells[0].fragments + model.cells[1].fragments == 5,
		"Cross-stage automatic paths preserve all carried fragments")
	model.purchase_powerup = Callable()
