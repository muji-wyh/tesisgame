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
	_test_whole_and_picture()
	_test_authored_spelling()
	_test_no_picture()
	_test_levels_and_fragments()
	_test_all_level_pairs()
	_test_collection_retry()
	_test_assistance()
	_test_supply_packets()
	print("Word Jelly hybrid: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _word(text: String = "cat", picture: bool = true) -> Dictionary:
	return {"id": "hybrid:" + text, "text": text, "min_age": 3,
		"image": "assets/images/words/cat.png" if picture else "", "audio": "assets/audio/words/cat.wav"}


func _composed(picture: bool = true) -> Dictionary:
	var word: Dictionary = _word("unbelievable", picture)
	word.morphology = {"schema": 1, "id": "hybrid-unbelievable", "lexeme_id": word.id,
		"text": word.text, "kind": "morphological",
		"review": {"status": "reviewed", "reviewer": "automated-test-fixture"},
		"parts": [
			{"id": "un", "canonical_id": "prefix:un", "type": "prefix", "canonical": "un-", "surface": "un-"},
			{"id": "believe", "canonical_id": "root:believe", "type": "root", "canonical": "believe", "surface": "believe"},
			{"id": "able", "canonical_id": "suffix:able", "type": "suffix", "canonical": "-able", "surface": "-able"}],
		"nodes": [
			{"id": "believable", "left": "believe", "right": "able", "surface": "believable", "rule": "drop_final_e", "break_offsets": [6]},
			{"id": "whole", "left": "un", "right": "believable", "surface": "unbelievable", "rule": "prefix", "break_offsets": [2, 8]}],
		"roots": ["whole"]}
	return word


func _model(words: Array = []) -> RefCounted:
	var model := Model.new()
	check(model.configure([_word()] if words.is_empty() else words, 3, 71), "Hybrid vocabulary configures")
	model.cells.clear()
	model.spawn_interval = 10000.0
	return model


func _put(model: RefCounted, tile: Dictionary) -> Dictionary:
	var at: Vector2i = model._free_position(model._occupied(), 1, 1)
	tile.column = at.x
	tile.row = at.y
	model.cells.append(tile)
	return tile


func _roots(model: RefCounted, word: Dictionary, fragments: int = 0) -> Array[Dictionary]:
	var tiles: Array[Dictionary] = []
	for state: Dictionary in model._morphology.source_tiles(str(word.morphology.id)):
		state.fragments = fragments
		tiles.append(_put(model, model._new_composition_tile(state)))
	return tiles


func _join(model: RefCounted, left: Dictionary, right: Dictionary) -> Dictionary:
	check(model.try_merge(int(left.id), int(right.id)) == "merged", "A legal hybrid pair starts merging")
	if model.fusions.is_empty():
		return {}
	var id: int = int(model.fusions.back().result.id)
	model.step(2.0)
	var tile: Dictionary = model.cell(id)
	check(not tile.is_empty(), "The accepted merge settles into a persistent Jelly")
	if not tile.is_empty():
		check(tile.width == 1 and tile.height == 1 and tile.preferred_width == 1 and tile.preferred_height == 1,
			"Every root, picture match, and upgrade keeps the ordinary 1 by 1 size")
	return tile


func _ready(model: RefCounted, word: Dictionary, level: int = 1, fragments: int = 0) -> Dictionary:
	var tile: Dictionary = model._new_word_root(word, fragments)
	model._set_merged_word(tile, word, level, true)
	return _put(model, tile)


func _test_whole_and_picture() -> void:
	var word: Dictionary = _word()
	var model: RefCounted = _model()
	var root: Dictionary = _put(model, model._new_word_root(word, 2))
	var picture: Dictionary = _put(model, model._new_picture_tile(word, 3))
	check(root.jelly_kind == "root" and root.display_text == "cat" and root.word.is_empty()
		and root.word_candidate.id == word.id and not model.collect(root.id), "A whole root still needs its picture")
	check(picture.jelly_kind == "picture" and picture.display_text.is_empty() and picture.word.is_empty()
		and picture.image_word.id == word.id and not model.collect(picture.id), "Picture Jelly carries art without a visible caption or collection gate")
	check(model.parts_compatible(root, picture) and model.parts_compatible(picture, root), "Text-picture matching works in either drag direction")
	var other: Dictionary = model._new_picture_tile(_word("dog"))
	check(not model.parts_compatible(root, other), "An unrelated picture never matches")
	other.image_word = word.duplicate(true)
	other.image_word.id = "other-cat-sense"
	check(not model.parts_compatible(root, other), "Matching uses the exact sense identity, not identical text")
	var attempts: Array = []
	model.word_attempted.connect(func(event: String, ids: Array[String], correct: bool): attempts.append([event, ids, correct]))
	var merged: Dictionary = _join(model, picture, root)
	check(merged.jelly_kind == "merged" and merged.merge_level == 1 and merged.word.id == word.id
		and merged.image_word.id == word.id and merged.fragments == 5 and merged.mastery_eligible, "Picture and root make an eligible Lv1 word with all fragments")
	check(attempts.is_empty(), "Matching itself never commits learning progress")
	check(model.collect(merged.id), "The resulting merged word can be collected")
	model.step(2.0)
	check(attempts.size() == 1 and model.fragment_count == 5, "Only committed collection records mastery and awards held fragments")
	var left: Dictionary = model._new_tile("c", 1, 0)
	var right: Dictionary = model._new_tile("at", 1, 0)
	check(not model.parts_compatible(left, right), "Arbitrary legacy letter chunks are not accepted as roots")
	var supplied_roots: Array = model.upcoming.filter(func(tile: Dictionary) -> bool: return tile.get("jelly_kind") == "root")
	check(not supplied_roots.is_empty() and supplied_roots.all(func(tile: Dictionary) -> bool: return tile.text == "cat"),
		"Unreviewed words reach the supply preview as whole roots")


func _test_authored_spelling() -> void:
	var word: Dictionary = _composed()
	var model: RefCounted = _model([word])
	var roots: Array[Dictionary] = _roots(model, word, 1)
	check(roots[0].text == "un" and roots[0].display_text == "un-"
		and roots[1].display_text == "-believe-" and roots[2].display_text == "-able", "Reviewed source positions produce the requested prefix, middle, and suffix marks")
	var picture: Dictionary = _put(model, model._new_picture_tile(word, 2))
	check(not model.parts_compatible(roots[1], picture) and not model.parts_compatible(roots[0], roots[1]),
		"Pictures require a complete spelling and roots require an authored join")
	var partial: Dictionary = _join(model, roots[1], roots[2])
	check(partial.text == "believable" and partial.display_text == "-believable" and partial.word.is_empty()
		and partial.word_candidate.is_empty() and partial.jelly_kind == "root", "The reviewed drop-e rule produces a meaningful partial root")
	var spelled: Dictionary = _join(model, roots[0], partial)
	check(spelled.text == "unbelievable" and spelled.display_text == "unbelievable"
		and spelled.word.is_empty() and spelled.word_candidate.id == word.id and not model.collect(spelled.id), "Completed pictured spelling waits for its own picture")
	var merged: Dictionary = _join(model, spelled, picture)
	check(merged.word.id == word.id and merged.fragments == 5 and merged.merge_level == 1, "The final picture match conserves all root and picture fragments")


func _test_no_picture() -> void:
	var atomic: Dictionary = _word("idea", false)
	var model: RefCounted = _model([atomic])
	var tile: Dictionary = _put(model, model._new_word_root(atomic, 1))
	check(tile.jelly_kind == "merged" and tile.merge_level == 1 and tile.word.id == atomic.id
		and tile.image_word.is_empty() and model.is_valid_word(tile), "An image-less atomic word is immediately collectable")
	check(not tile.mastery_eligible, "Atomic exposure alone does not claim independent mastery")
	atomic.erase("image")
	check(model.configure([atomic], 3, 71), "A missing image field is supported as well as an empty image")
	var word: Dictionary = _composed(false)
	model = _model([word])
	var roots: Array[Dictionary] = _roots(model, word)
	var partial: Dictionary = _join(model, roots[1], roots[2])
	var complete: Dictionary = _join(model, roots[0], partial)
	check(complete.jelly_kind == "merged" and complete.merge_level == 1 and complete.mastery_eligible,
		"An authored image-less spelling becomes merged immediately upon completion")
	var base: Dictionary = _word("believe", false)
	base.morphology = {"schema": 1, "id": "hybrid-believe", "lexeme_id": base.id, "text": base.text,
		"kind": "atomic", "review": {"status": "reviewed", "reviewer": "automated-test-fixture"},
		"parts": [{"id": "whole", "canonical_id": "root:believe", "type": "root", "canonical": "believe", "surface": "believe"}],
		"nodes": [], "roots": ["whole"]}
	model = _model([base, word])
	roots = _roots(model, word)
	check(roots[1].jelly_kind == "root" and roots[1].display_text == "-believe-" and roots[1].word_candidate.is_empty(),
		"A middle source retains its authored role when the same base is a separate image-less lexeme")
	var standalone: Dictionary = model._new_composition_tile(model._morphology.source_tiles("hybrid-believe")[0])
	check(standalone.jelly_kind == "merged" and standalone.word.id == base.id,
		"The same base supplied as its own atomic word still merges immediately without art")
	partial = _join(model, roots[1], roots[2])
	complete = _join(model, roots[0], partial)
	check(complete.jelly_kind == "merged" and complete.word.id == word.id,
		"Shared lexical roots cannot strand an image-less multipart supply packet")
	var intermediate: Dictionary = word.duplicate(true)
	intermediate.id = "hybrid:believable"
	intermediate.text = "believable"
	intermediate.morphology.id = "hybrid-believable"
	intermediate.morphology.lexeme_id = intermediate.id
	intermediate.morphology.text = intermediate.text
	intermediate.morphology.parts = intermediate.morphology.parts.slice(1)
	intermediate.morphology.nodes = intermediate.morphology.nodes.slice(0, 1)
	intermediate.morphology.roots = ["believable"]
	model = _model([intermediate, word])
	_roots(model, word)
	var contextual_plan: Dictionary = model.authored_completion_plan()
	check(contextual_plan.status == "complete" and contextual_plan.steps.size() == 2
		and contextual_plan.tile.word.id == word.id, "Auto continues past an intermediate that is another context's standalone lexeme")
	model.purchase_powerup = func(_event: String, _kind: String, _price: int) -> Dictionary: return {"ok": true}
	check(model.activate_powerup("auto_merge"), "A shared intermediate still has a complete preflighted path")
	model.finish_powerup(false)
	check(model.cells.size() == 1 and model.cells[0].word.id == word.id,
		"The planned contextual completion matches the actual manual resolver at every step")


func _test_levels_and_fragments() -> void:
	var word: Dictionary = _word()
	var model: RefCounted = _model()
	var current: Dictionary = _ready(model, word, 1, 1)
	var cues: Array[String] = []
	var attempts: Array = []
	model.cue_requested.connect(func(cue: String): cues.append(cue))
	model.word_attempted.connect(func(event: String, ids: Array[String], correct: bool): attempts.append([event, ids, correct]))
	for level in range(2, Model.MAX_MERGE_LEVEL + 1):
		var addition: Dictionary = _ready(model, word, 1, 1)
		check(model.parts_compatible(current, addition), "A same-word Lv1 can add to every level below Lv6")
		current = _join(model, current, addition)
		check(current.merge_level == level and current.fragments == level, "Upgrades add levels and preserve both fragment stores")
		check(attempts.is_empty(), "Level upgrades do not award mastery before collection")
		var other_word: Dictionary = _ready(model, _word("dog"), level)
		check(not model.parts_compatible(current, other_word), "Different word identities never upgrade together")
		model.cells.erase(other_word)
	var max_twin: Dictionary = _ready(model, word, 1)
	check(not model.parts_compatible(current, max_twin) and model.merge_candidate(current, max_twin).status == "invalid",
		"Lv6 is a hard cap and cannot create Lv7")
	model.cells.erase(max_twin)
	var payloads: Array = []
	model.collection_started.connect(func(payload: Dictionary): payloads.append(payload))
	check(model.collect(current.id), "Max-level merged words remain collectable")
	model.step(Model.collection_pop_seconds(6))
	check("jelly-collect-lv6" in cues and payloads[0].merge_level == 6 and payloads[0].mastery_eligible,
		"Collection exposes the level and plays its distinct sound at the pop boundary")
	model.step(2.0)
	check(attempts.size() == 1 and model.fragment_count == 6, "One collected high-level word records one learning event and all accumulated fragments")
	for level in range(1, Model.MAX_MERGE_LEVEL + 1):
		var pick: Dictionary = _ready(model, word, level)
		cues.clear()
		check(model.collect(pick.id), "Each implemented level is collectable")
		model.step(Model.collection_pop_seconds(level) - 0.01)
		check(cues.is_empty(), "Collection audio waits for the shared visible pop boundary")
		model.step(0.02)
		check(cues == ["pop" if level == 1 else "jelly-collect-lv%d" % level], "Every level chooses its dedicated collection sound")
		model.step(2.0)
	model = _model()
	var a: Dictionary = _ready(model, word, 2, 2)
	var b: Dictionary = _ready(model, word, 4, 3)
	while model.cells.size() < Model.CAPACITY:
		_put(model, model._new_tile("filler", 1, 0))
	var upgraded: Dictionary = _join(model, a, b)
	check(upgraded.merge_level == 6 and model.cells.size() == Model.CAPACITY - 1 and upgraded.fragments == 5,
		"A crowded board can upgrade in the consumed pair's ordinary cell")


func _test_all_level_pairs() -> void:
	check(Model.MAX_MERGE_LEVEL == 6, "Merged Jellies have exactly six supported levels")
	for left_level in range(1, Model.MAX_MERGE_LEVEL + 1):
		for right_level in range(1, Model.MAX_MERGE_LEVEL + 1):
			var model: RefCounted = _model()
			var left: Dictionary = _ready(model, _word(), left_level, left_level + 1)
			var right: Dictionary = _ready(model, _word(), right_level, right_level + 2)
			var combined: int = left_level + right_level
			var allowed: bool = combined <= Model.MAX_MERGE_LEVEL
			var label: String = "Lv%d + Lv%d" % [left_level, right_level]
			var cells_before: Array = model.cells.duplicate(true)
			var next_id: int = model._next_tile_id
			var next_event: int = model._next_event_id
			var supply_rng: int = model._rng.state
			var coin_rng: int = model._coin_rng.state
			check(model.parts_compatible(left, right) == allowed and model.can_merge(left, right) == allowed,
				label + " agrees across highlights and manual merge eligibility")
			var plan: Dictionary = model.authored_completion_plan()
			check((plan.status == "complete") == allowed, label + " uses the same rule in Auto Merge preflight")
			check(model.cells == cells_before and model._next_tile_id == next_id and model._next_event_id == next_event
				and model._rng.state == supply_rng and model._coin_rng.state == coin_rng,
				label + " preflight never mutates board, identity, or reward randomness")
			if allowed:
				check(plan.tile.merge_level == combined, label + " previews the exact level sum")
				var result: Dictionary = _join(model, left, right)
				check(result.merge_level == combined and result.fragments == combined + 3 and result.mass == 2,
					label + " commits the level sum with every carried fragment and source mass")
			else:
				check(model.try_merge(left.id, right.id) == "wrong" and model.cells == cells_before
					and model._next_tile_id == next_id and model._next_event_id == next_event and model.fusions.is_empty(),
					label + " rejects atomically instead of clamping or consuming either Jelly")
	var model: RefCounted = _model()
	var left: Dictionary = _ready(model, _word(), 2)
	var right: Dictionary = _ready(model, _word(), 3)
	right.word.id = "other-sense:cat"
	check(not model.parts_compatible(left, right), "Equal spelling cannot merge two different word senses")
	right.word.id = left.word.id
	right.merge_level = 0
	check(not model.parts_compatible(left, right) and model.merge_candidate(left, right).status == "invalid",
		"A malformed level cannot create a valid upgrade")
	model._set_merged_word(right, _word(), 99, true)
	check(right.merge_level == 6, "Creating a merged word cannot expose unsupported higher levels")


func _test_collection_retry() -> void:
	var model: RefCounted = _model()
	var merged: Dictionary = _ready(model, _word(), 4, 3)
	var commits: Array = []
	var attempts: Array = []
	model.commit_collection = func(payload: Dictionary) -> Dictionary:
		commits.append(payload.duplicate(true))
		return {"ok": commits.size() > 1}
	model.word_attempted.connect(func(event: String, ids: Array[String], correct: bool): attempts.append([event, ids, correct]))
	check(model.collect(merged.id), "A collection begins before persistence resolves")
	model.step(2.0)
	check(not model.cell(merged.id).is_empty() and model.fragment_count == 0 and attempts.is_empty(),
		"A rejected save leaves the same upgraded Jelly and no learning reward")
	check(model.collect(merged.id), "The failed collection is retryable")
	model.step(2.0)
	check(commits.size() == 2 and commits[0].attempt_id == commits[1].attempt_id
		and commits[0].coins == commits[1].coins and commits[1].merge_level == 4
		and attempts.size() == 1 and model.fragment_count == 3, "A retry preserves event identity, coin roll, level, and exactly-once rewards")


func _test_assistance() -> void:
	var word: Dictionary = _composed()
	var model: RefCounted = _model([word])
	_roots(model, word, 1)
	check(model.authored_completion_plan().status == "unavailable", "Auto merge never sells a pictured completion without the matching picture")
	_put(model, model._new_picture_tile(word, 1))
	var plan: Dictionary = model.authored_completion_plan()
	check(plan.status == "complete" and plan.steps.size() == 3 and plan.tile.jelly_kind == "merged",
		"Auto merge preflights the two reviewed root joins and final picture match")
	model.purchase_powerup = func(_event: String, _kind: String, _price: int) -> Dictionary: return {"ok": true}
	check(model.activate_powerup("auto_merge"), "A complete hybrid route can purchase Auto merge")
	model.finish_powerup(false)
	check(model.cells.size() == 1 and model.cells[0].jelly_kind == "merged"
		and model.cells[0].fragments == 4 and model.cells[0].assisted and not model.cells[0].mastery_eligible,
		"Automatic root and picture joins finish, preserve fragments, and retain assistance")
	var attempts: Array = []
	model.word_attempted.connect(func(event: String, ids: Array[String], correct: bool): attempts.append([event, ids, correct]))
	check(model.collect(model.cells[0].id), "Assisted words are still collectable")
	model.step(2.0)
	check(attempts.is_empty() and model.fragment_count == 4, "Assisted collection awards inventory without claiming independent mastery")
	model = _model()
	_ready(model, _word(), 2, 2)
	_ready(model, _word(), 3, 3)
	model.purchase_powerup = func(_event: String, _kind: String, _price: int) -> Dictionary: return {"ok": true}
	check(model.activate_powerup("auto_merge"), "Auto merge also supports eligible level-up pairs")
	model.finish_powerup(false)
	check(model.cells.size() == 1 and model.cells[0].merge_level == 5 and model.cells[0].fragments == 5
		and not model.cells[0].mastery_eligible, "Automatic upgrades conserve level and fragments without learning credit")
	model = _model()
	_ready(model, _word(), 4, 2)
	_ready(model, _word(), 3, 3)
	var purchases: Array = []
	model.purchase_powerup = func(event: String, _kind: String, _price: int) -> Dictionary:
		purchases.append(event)
		return {"ok": true}
	check(not model.can_activate_powerup("auto_merge") and not model.activate_powerup("auto_merge")
		and purchases.is_empty() and model.cells.size() == 2,
		"An over-cap pair never sells an unavailable Auto Merge or consumes either word")


func _test_supply_packets() -> void:
	var words: Array = [_word(), _composed(), _word("idea", false)]
	var model := Model.new()
	check(model.configure(words, 3, 107), "Mixed roots, pictures, and image-less words configure together")
	var inventory: Array[Dictionary] = []
	inventory.append_array(model.cells)
	for slot: Dictionary in model.upcoming:
		if slot.has("id"):
			inventory.append(slot)
	for index in range(240):
		inventory.append(model._next_supply_tile())
	var groups: Dictionary = {}
	for tile: Dictionary in inventory:
		check(tile.width == 1 and tile.height == 1, "All supplied kinds use ordinary Jelly geometry")
		var group: int = int(tile.supply_group)
		if not groups.has(group):
			groups[group] = []
		groups[group].append(tile)
	for group: int in groups:
		var packet: Array = groups[group]
		if packet.size() < int(packet[0].supply_parts):
			continue
		var positions: Array = []
		var picture_count: int = 0
		var fragments: int = 0
		for tile: Dictionary in packet:
			positions.append(tile.supply_part)
			picture_count += 1 if tile.jelly_kind == "picture" else 0
			fragments += int(tile.fragments)
		positions.sort()
		check(positions == range(packet.size()), "Supply packets preserve each source exactly once across preview boundaries")
		check(picture_count == (0 if packet[0].source_word_id == "hybrid:idea" else 1),
			"Every pictured word supplies exactly one matching picture, and image-less words supply none")
		check(fragments == (1 if group % 2 == 0 else 0), "Picture-inclusive packets preserve the established fragment cadence")
