extends SceneTree

const Model = preload("res://scripts/word_jelly_model.gd")

class ObservedModel extends "res://scripts/word_jelly_model.gd":
	var plan_calls: int = 0
	var reject_plan: bool = false
	func authored_completion_plan(captured_only: bool = false, family: String = "",
		input_limit: int = -1, generated: Dictionary = {}) -> Dictionary:
		plan_calls += 1
		if reject_plan:
			return {"status": "unavailable", "steps": []}
		return super.authored_completion_plan(captured_only, family, input_limit, generated)

var checks: int = 0
var failures: int = 0
var word: Dictionary = {"id": "cat", "text": "cat", "min_age": 3,
	"image": "res://assets/images/ui/modes/cat.webp", "audio": "fixture:cat"}


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func fixture() -> ObservedModel:
	var model := ObservedModel.new()
	check(model.configure([word], 3, 93871), "A real pictured word configures the availability fixture")
	model.spawn_interval = 10000.0
	model.cells.clear()
	for index in range(2):
		var tile: Dictionary = model._new_word_root(word, 1)
		model._set_merged_word(tile, word, 1, true)
		tile.merge({"column": index, "row": Model.ROWS - 1, "age": 100.0,
			"settling": false, "falling": false, "arrival": false}, true)
		model.cells.append(tile)
	model.plan_calls = 0
	return model


func fresh(model: ObservedModel, kind: String = "auto_merge") -> bool:
	return Model.POWERUP_PRICES.has(kind) and model._powerup_inputs_ready() \
		and not model._powerup_pair(false).is_empty()


func check_equivalent(model: ObservedModel, message: String) -> void:
	var expected: bool = fresh(model)
	check(model.can_activate_powerup("auto_merge") == expected \
		and model.can_activate_powerup("family_merge") == expected, message)


func _test_idle_queries() -> void:
	var model := fixture()
	var before: Array = model.cells.duplicate(true)
	var next_id: int = model._next_tile_id
	var rng_state: int = model._rng.state
	check(model.can_activate_powerup("auto_merge") and model.plan_calls == 1,
		"The first toolbar query checks one legal complete path")
	for frame in range(60):
		check(model.can_activate_powerup("family_merge") and model.can_activate_powerup("auto_merge"),
			"Both toolbar controls retain the same legal availability")
	check(model.plan_calls == 1, "Repeated settled-board queries share one search across controls and frames")
	check(model.cells == before and model._next_tile_id == next_id and model._rng.state == rng_state,
		"Read-only queries never move bodies, allocate IDs or consume random supply")
	for frame in range(30):
		model.step(1.0 / 60.0)
		check(model.can_activate_powerup("auto_merge"), "Clock-only model steps retain the available path")
	check(model.plan_calls == 1, "Settled age and periodic changed signals do not repeat the search")
	check(not model.can_activate_powerup("fragments") and not model.can_activate_powerup("unknown") \
		and model.plan_calls == 1, "Retired and unknown tools do not consult a cached legal tool")
	model.cells[0].column = 2
	check(model.can_activate_powerup("auto_merge") and model.plan_calls == 2,
		"In-place geometry changes invalidate the advertised route")
	model.cells[1].word.id = "another-sense"
	check(not model.can_activate_powerup("family_merge") and model.plan_calls == 3,
		"Nested word identity changes invalidate a previously legal pair")
	check(not model.can_activate_powerup("auto_merge") and model.plan_calls == 3,
		"An unchanged impossible board also avoids repeated completion searches")
	model.cells[1].word.id = word.id
	check_equivalent(model, "Restored nested word data agrees with an uncached legal-path search")


func _test_eligibility_and_arrivals() -> void:
	var model := fixture()
	check(model.can_activate_powerup("auto_merge"), "The eligibility fixture begins with an available path")
	model.paused = true
	check(not model.can_activate_powerup("auto_merge") and model.plan_calls == 1,
		"Pausing blocks the tool before reading a previous available result")
	model.paused = false
	model._held_tile_id = int(model.cells[0].id)
	check(not model.can_activate_powerup("auto_merge") and model.plan_calls == 1,
		"A held body cannot activate a previously advertised tool")
	model._held_tile_id = -1
	model.cells[0].age = 0.0
	check(not model.can_activate_powerup("auto_merge"), "Real support settlement blocks toolbar activation")
	model.cells[0].arrival = true
	check(not model.can_activate_powerup("auto_merge") and model.plan_calls == 2,
		"Unsettled supply may allow the toolbar clock but cannot supply a missing settled input")
	model.cells[0].age = 100.0
	check(model.can_activate_powerup("auto_merge") and model.plan_calls == 3,
		"An arrival crossing its settled boundary makes its newly legal path available")
	model.cells[0].lifted = true
	check(not model.can_activate_powerup("auto_merge") and model.plan_calls == 4,
		"A directly lifted input invalidates the available complete path")
	model.cells[0].lifted = false
	check_equivalent(model, "Restoring an input produces the same result as a fresh query")
	model.phase = "finished"
	check(not model.can_activate_powerup("family_merge"), "A finished game never reuses playing availability")


func _test_levels_and_boss() -> void:
	var model := fixture()
	check(model.can_activate_powerup("auto_merge"), "The level fixture begins with an upgradeable pair")
	model.merged_level_limit = 1
	check(not model.can_activate_powerup("auto_merge") and model.plan_calls == 2,
		"Changing the permanent cap immediately removes capped merged inputs")
	model.merged_level_limit = 2
	check(model.can_activate_powerup("family_merge") and model.plan_calls == 3,
		"Raising the permanent cap restores the newly legal path")
	model.cells[0].merge_level = 2
	model.cells[1].merge_level = 2
	check(not model.can_activate_powerup("auto_merge") and model.plan_calls == 4,
		"In-place level changes cannot reuse the lower-level pair's availability")
	model.merged_level_limit = 9
	model.auto_merge_level = 3
	model._campaign_level_rules = true
	check_equivalent(model, "Changed saved levels and campaign rules agree with a fresh query")
	var before_calls: int = model.plan_calls
	model.boss._statuses[int(model.cells[0].id)] = {"freeze": 1.0}
	check(not model.can_activate_powerup("auto_merge") and model.plan_calls == before_calls + 1,
		"A new Boss freeze invalidates a previously complete path")
	model.boss._statuses[int(model.cells[0].id)].freeze = 0.5
	check(not model.can_activate_powerup("family_merge") and model.plan_calls == before_calls + 1,
		"A continuing freeze does not repeat the same blocked search each frame")
	model.boss._statuses[int(model.cells[0].id)] = {"locks": 1}
	check(not model.can_activate_powerup("auto_merge") and model.plan_calls == before_calls + 2,
		"Boss locks exclude automatic inputs independently of freeze")
	model.boss._statuses.clear()
	check(model.can_activate_powerup("auto_merge") and model.plan_calls == before_calls + 3,
		"Removing the last Boss restriction restores availability immediately")
	model.allow_cross_age = true
	model.fall_speed_scale = 1.6
	model._gravity_pending = true
	check_equivalent(model, "Changed eligibility, fall and gravity rules agree with a fresh search")


func _authored_word() -> Dictionary:
	return {"id": "sense:helpful", "text": "helpful", "min_age": 3, "image": "", "audio": "fixture:helpful",
		"morphology": {"schema": 1, "id": "helpful", "lexeme_id": "sense:helpful", "text": "helpful",
			"kind": "morphological", "review": {"status": "reviewed", "reviewer": "automated-test-fixture"},
			"parts": [{"id": "help", "canonical_id": "root:help", "type": "root", "canonical": "help", "surface": "help"},
				{"id": "ful", "canonical_id": "suffix:ful", "type": "suffix", "canonical": "-ful", "surface": "-ful"}],
			"nodes": [{"id": "whole", "left": "help", "right": "ful", "surface": "helpful",
				"rule": "test_authored_join", "break_offsets": [4]}], "roots": ["whole"]}}


func _test_authored_board() -> void:
	var model := ObservedModel.new()
	var authored: Dictionary = _authored_word()
	check(model.configure([authored], 3, 391), "A reviewed test analysis configures authored availability")
	model.spawn_interval = 10000.0
	model.cells.clear()
	for source: Dictionary in model._morphology.source_tiles("helpful"):
		var tile: Dictionary = model._new_composition_tile(source)
		tile.merge({"column": model.cells.size() * 2, "row": Model.ROWS - 1, "age": 100.0,
			"settling": false, "falling": false, "arrival": false}, true)
		model.cells.append(tile)
	model.plan_calls = 0
	check(model.can_activate_powerup("auto_merge") and model.plan_calls == 1,
		"The cache checks the actual authored completion path")
	var suffix: Dictionary = model.cells.pop_back()
	check(not model.can_activate_powerup("family_merge") and model.plan_calls == 2,
		"Removing a required authored suffix invalidates the cached complete path")
	model.cells.append(suffix)
	check(model.can_activate_powerup("family_merge") and model.plan_calls == 3,
		"Restoring a required authored suffix restores its legal completion")
	var signature: String = str(model.cells[0].composition.signature)
	model.cells[0].composition.signature = "not-an-authored-state"
	check_equivalent(model, "In-place composition edits cannot reuse the original authored path")
	model.cells[0].composition.signature = signature
	check_equivalent(model, "Restoring the authored state agrees with fresh planning")
	var before_calls: int = model.plan_calls
	check(model.replace_stage_words([authored], 3), "The supported stage-word update replaces its configured resolver")
	check(model.can_activate_powerup("family_merge") and model.plan_calls == before_calls + 1,
		"A stage-word replacement searches the new configured vocabulary before reusing availability")
	var plan: Dictionary = preload("res://scripts/word_jelly_stage_catalog.gd").make_plan(0, [authored], 3, 591, true)
	model.stage_run = preload("res://scripts/word_jelly_stage_run.gd").new()
	check(plan.ok and model.stage_run.configure(plan), "The cache regression uses actual challenge pressure rules")
	model.stage_run.challenge_stage = 13
	before_calls = model.plan_calls
	model._sync_challenge_pressure()
	check(model.can_activate_powerup("auto_merge") and model.plan_calls == before_calls + 1,
		"Challenge pressure reconfiguration invalidates availability even when the resolver object is reused")


func _test_fresh_activation_and_reset() -> void:
	var model := fixture()
	var payments: Array = []
	model.purchase_powerup = func(id: String, kind: String, price: int) -> Dictionary:
		payments.append([id, kind, price])
		return {"ok": true, "duplicate": false}
	check(model.can_activate_powerup("auto_merge") and model.plan_calls == 1,
		"The activation fixture has already advertised an available toolbar action")
	model.reject_plan = true
	check(not model.activate_powerup("auto_merge") and model.plan_calls == 2 and payments.is_empty(),
		"Activation independently rechecks a real path and cannot charge from the read-only cached answer")
	check(not model.activate_family_merge("cat") and model.plan_calls == 3 and payments.is_empty(),
		"Family activation also revalidates before any payment")
	model.reject_plan = false
	var before_calls: int = model.plan_calls
	check(model.activate_powerup("auto_merge") and model.plan_calls > before_calls \
		and payments.size() == 1 and payments[0][2] == 200,
		"A fresh successful activation preserves the exact single saved purchase")
	model.purchase_powerup = Callable()
	model.finish_powerup()
	check(model.configure([word], 3, 93871), "The same model can start a fresh round after an accepted operation")
	model.cells.clear()
	model.plan_calls = 0
	check(not model.can_activate_powerup("auto_merge") and model.plan_calls == 0,
		"Reset never leaks the previous round's cached available path onto an empty board")
	var replacement := fixture()
	model.cells.assign(replacement.cells.duplicate(true))
	check(model.can_activate_powerup("auto_merge") and model.plan_calls == 1,
		"A reset model searches its replacement board before advertising a new path")


func _run() -> void:
	_test_idle_queries()
	_test_eligibility_and_arrivals()
	_test_levels_and_boss()
	_test_authored_board()
	_test_fresh_activation_and_reset()
	print("Word Jelly cached powerup availability: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
