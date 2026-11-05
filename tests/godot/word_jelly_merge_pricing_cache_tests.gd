extends SceneTree

const Model = preload("res://scripts/word_jelly_model.gd")
const BossCatalog = preload("res://scripts/word_jelly_boss_catalog.gd")

class ObservedModel extends Model:
	var simple_calls: int = 0
	var timeline_calls: int = 0

	func _simple_auto_merge_preview(capacity: int) -> Dictionary:
		simple_calls += 1
		return super._simple_auto_merge_preview(capacity)

	func _powerup_forecast() -> WordJellyModel:
		timeline_calls += 1
		return super._powerup_forecast()

var checks: int = 0
var failures: int = 0
var words: Array = [
	{"id": "cat", "text": "cat", "min_age": 3,
		"image": "res://assets/images/ui/modes/cat.webp", "audio": "fixture:cat"},
	{"id": "dog", "text": "dog", "min_age": 3,
		"image": "res://assets/images/ui/modes/cat.webp", "audio": "fixture:dog"},
	{"id": "hat", "text": "hat", "min_age": 3,
		"image": "res://assets/images/ui/modes/cat.webp", "audio": "fixture:hat"}]


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func fixture(level: int = 1) -> ObservedModel:
	var model := ObservedModel.new()
	check(model.configure(words, 3, 95103), "The pricing cache uses valid complete pictured word identities")
	model.cells.clear()
	model.auto_merge_level = level
	model.spawn_interval = 10000.0
	model._growth_pending = false
	model._gravity_pending = false
	model._drag_gravity_delays.clear()
	return model


func put(model: ObservedModel, tile: Dictionary) -> void:
	var at: Vector2i = model._free_position(model._occupied(), int(tile.width), int(tile.height))
	check(at.x >= 0, "Every pricing input occupies a genuine non-overlapping board position")
	tile.merge({"column": at.x, "row": at.y, "age": 100.0,
		"arrival": false, "falling": false, "settling": false}, true)
	model.cells.append(tile)


func pair(model: ObservedModel, word: Dictionary) -> void:
	put(model, model._new_word_root(word, 1))
	put(model, model._new_picture_tile(word, 2))


func merged(model: ObservedModel, word: Dictionary, level: int) -> void:
	var tile: Dictionary = model._new_word_root(word, 1)
	model._set_merged_word(tile, word, level, true)
	put(model, tile)


func gameplay_state(model: ObservedModel) -> Dictionary:
	# Avoid snapshot(), whose public price fields intentionally populate caches.
	return {"cells": model.cells.duplicate(true), "fusions": model.fusions.duplicate(true),
		"phase": model.phase, "paused": model.paused, "elapsed": model.spawn_elapsed,
		"next_tile": model._next_tile_id, "next_event": model._next_event_id,
		"rng": model._rng.state, "coins_rng": model._coin_rng.state, "blast_rng": model._blast_rng.state,
		"boss": model.boss.snapshot(), "uses": model._powerup_uses.duplicate(),
		"generated": model.generated_tiles, "merged": model.merged_count,
		"fragments": model.fragment_count, "coins": model.collected_coins,
		"words": model._words_by_id.duplicate(true), "powerup": model._powerup.duplicate(true)}


func timeline_preview(model: ObservedModel) -> Dictionary:
	var forecast: WordJellyModel = model._powerup_forecast()
	forecast._begin_powerup_timeline("auto_merge", "independent-pricing-parity")
	forecast.finish_powerup()
	check(not forecast.powerup_active() and forecast.error.is_empty(), "The independent real timeline finishes every captured path")
	return {"capacity": model.auto_merge_capacity(),
		"result_count": int(forecast._powerup.completed_results),
		"reduction_count": maxi(0, model.cells.size() - forecast.cells.size()),
		"input_ids": forecast._powerup.used_input_ids.keys()}


func _test_simple_parity() -> void:
	for owned_level in range(1, 10):
		var model := fixture(owned_level)
		model.merged_level_limit = owned_level
		for index in range(10 + owned_level):
			var word: Dictionary = words[index % words.size()]
			if index % 3 == 0:
				pair(model, word)
			elif index % 3 == 1:
				merged(model, word, 1 + index % 5)
				merged(model, word, 1 + (index + 2) % 5)
			else:
				put(model, model._new_word_root(word, 1))
				put(model, model._new_picture_tile(words[(index + 1) % words.size()], 2))
		var before: Dictionary = gameplay_state(model)
		var preview: Dictionary = model.auto_merge_preview()
		check(model.simple_calls == 1 and model.timeline_calls == 0,
			"Crowded simple boards price every capacity without simulating motion")
		check(preview == timeline_preview(model),
			"Simple mixed-family, mixed-level paths preserve actual input order, result count and board reduction at Lv%d" % owned_level)
		check(gameplay_state(model) == before, "Neither forecasting route changes the live board, vocabulary or random streams")
		check(model.powerup_price("auto_merge") == 25 * maxi(1, int(preview.reduction_count)),
			"The displayed first-use quote prices the real forecast quantity")
		check(model.simple_calls == 1 and model.timeline_calls == 1,
			"Reading the price after pointer-preview consumption reuses the cached result")


func _test_price_and_preview_reuse() -> void:
	var model := fixture()
	for index in range(8):
		pair(model, words[index % words.size()])
	var effects: Array[String] = []
	model.changed.connect(func() -> void: effects.append("changed"))
	model.cue_requested.connect(func(_cue: String) -> void: effects.append("audio"))
	model.powerup_feedback.connect(func(_kind: String, _ok: bool) -> void: effects.append("feedback"))
	model.purchase_powerup = func(_id: String, _kind: String, _price: int) -> Dictionary:
		effects.append("wallet")
		return {"ok": true}
	var before: Dictionary = gameplay_state(model)
	check(model.powerup_price("auto_merge") == 75 and model.simple_calls == 1 and model.timeline_calls == 0,
		"A real visible three-space quote warms the cheap preview before hover")
	var expected: Dictionary = model.auto_merge_preview()
	for query in range(30):
		check(model.auto_merge_preview() == expected and model.powerup_price("auto_merge") == 75,
			"Repeated pointer-preview consumers and price refreshes share one legal result")
	check(effects.is_empty() and gameplay_state(model) == before,
		"Price and hover queries cannot spend, emit audio or feedback, consume RNG, allocate gameplay IDs or change live state")
	var copy: Dictionary = model.auto_merge_preview()
	copy.input_ids.clear()
	check(model.auto_merge_preview() == expected, "A preview consumer cannot edit the cached input IDs")
	check(model.simple_calls == 1 and model.timeline_calls == 0, "Stable repeated consumers perform no additional path search")
	for frame in range(30):
		model.step(1.0 / 60.0)
		check(model.powerup_price("auto_merge") == 75 and model.auto_merge_preview() == expected,
			"Actual settled idle time retains the exact quote and pointer-preview set")
	check(model.simple_calls == 1 and model.timeline_calls == 0, "Idle age never invalidates the common-case pricing cache")
	model.set_paused(true)
	check(model.auto_merge_preview().input_ids.is_empty() and model.powerup_price("auto_merge") == 75,
		"Pause hides actionable targets while retaining the quoted quantity")
	model.set_paused(false)
	check(model.auto_merge_preview() == expected and model.simple_calls == 1,
		"Resume reuses the unchanged settled board's quote without another search")
	model.purchase_powerup = Callable()


func _test_rule_and_status_invalidation() -> void:
	var model := fixture()
	for index in range(12):
		merged(model, words[0], 1)
	check(model.powerup_price("auto_merge") == 75, "A simple board begins at the owned three-output quote")
	model.auto_merge_level = 4
	check(model.powerup_price("auto_merge") == 150 and model.simple_calls == 2,
		"Increasing owned capacity invalidates the cache and prices six real paths")
	model.merged_level_limit = 1
	check(model.auto_merge_preview().result_count == 0 and model.simple_calls == 3,
		"Changing the merged-level cap removes newly ineligible inputs from the cached operation")
	model.merged_level_limit = 9
	check(model.powerup_price("auto_merge") == 150 and model.simple_calls == 4,
		"Restoring the cap restores the complete quantity instead of retaining an empty quote")
	model.boss.configure(BossCatalog.encounter(7), 71)
	model.boss.apply_status("freeze", int(model.cells[0].id))
	check(model.powerup_price("auto_merge") == 125 and model.simple_calls == 5,
		"A new frozen input invalidates the preview and lowers the payable legal quantity")
	model.boss.apply_status("lock", int(model.cells[1].id))
	var preview: Dictionary = model.auto_merge_preview()
	check(model.simple_calls == 6 and preview == timeline_preview(model),
		"A new lock refreshes the exact production capture set even when its total price is unchanged")
	model._gravity_pending = true
	preview = model.auto_merge_preview()
	check(model.simple_calls == 7 and model.timeline_calls == 2 and preview == timeline_preview(model),
		"Pending movement switches to the real timeline rather than reusing a formerly settled shortcut")
	model._gravity_pending = false
	check(model.auto_merge_preview() == preview and model.simple_calls == 8,
		"A safe settled board can return to the common-case planner after motion ownership changes")


func _test_airborne_and_large_fallback() -> void:
	var model := fixture()
	for index in range(5):
		pair(model, words[0])
	check(model.powerup_price("auto_merge") == 75, "The airborne fixture first caches a settled complete quote")
	var incoming: Dictionary = model.cells[0]
	incoming.arrival = true
	incoming.arrival_delay = 0.0
	incoming.age = maxf(0.0, Model.settle_duration(incoming) - 0.3)
	var preview: Dictionary = model.auto_merge_preview()
	check(model.timeline_calls == 1 and preview == timeline_preview(model),
		"An airborne input invalidates the cheap quote and preserves real landing-order prediction")
	incoming.age = float(incoming.age) + 0.05
	var previous: int = model.timeline_calls
	preview = model.auto_merge_preview()
	check(model.timeline_calls == previous + 1 and preview == timeline_preview(model),
		"A changed airborne deadline refreshes the real forecast instead of a stale cached price")
	var large := fixture()
	var root: Dictionary = large._new_word_root(words[0])
	root.width = 2
	put(large, root)
	put(large, large._new_picture_tile(words[0]))
	pair(large, words[1])
	preview = large.auto_merge_preview()
	check(large.timeline_calls == 1 and preview == timeline_preview(large),
		"A larger body uses the real placement and movement forecast")


func _test_partial_morphology_fallback() -> void:
	var model := ObservedModel.new()
	var word: Dictionary = {"id": "rainbow", "text": "rainbow", "min_age": 3,
		"image": words[0].image, "audio": "fixture:rainbow",
		"morphology": {"schema": 1, "id": "fixture:pricing:rainbow", "lexeme_id": "rainbow",
			"text": "rainbow", "kind": "morphological",
			"review": {"status": "reviewed", "reviewer": "automated-test-fixture"},
			"parts": [{"id": "a", "canonical_id": "fixture:rain", "type": "root", "canonical": "rain", "surface": "rain"},
				{"id": "b", "canonical_id": "fixture:bow", "type": "root", "canonical": "bow", "surface": "bow"}],
			"nodes": [{"id": "whole", "left": "a", "right": "b", "surface": "rainbow", "rule": "test_authored_join"}],
			"roots": ["whole"]}}
	check(model.configure([word], 3, 83), "An explicit reviewed multipart fixture requires real intermediate steps")
	model.cells.clear()
	model.spawn_interval = 10000.0
	model._growth_pending = false
	model._gravity_pending = false
	for copy in range(3):
		for part: Dictionary in model._morphology.source_tiles(str(word.morphology.id)):
			put(model, model._new_composition_tile(part))
		put(model, model._new_picture_tile(word))
	var preview: Dictionary = model.auto_merge_preview()
	check(model.timeline_calls == 1 and preview.result_count == 3 and preview.reduction_count == 6,
		"Partial spellings retain the accurate full timeline and count all six net joins")
	check(preview == timeline_preview(model) and model.powerup_price("auto_merge") == 150,
		"The multipart fallback preserves the original inputs and the common per-space debit")


func _run() -> void:
	_test_simple_parity()
	_test_price_and_preview_reuse()
	_test_rule_and_status_invalidation()
	_test_airborne_and_large_fallback()
	_test_partial_morphology_fallback()
	print("Word Jelly merge pricing cache: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
