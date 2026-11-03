extends SceneTree

const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
const Run = preload("res://scripts/word_jelly_stage_run.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
const BossCatalog = preload("res://scripts/word_jelly_boss_catalog.gd")
const BossRun = preload("res://scripts/word_jelly_boss_run.gd")
const Data = preload("res://scripts/game_data.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")
var checks := 0
var failures := 0
var words: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _test_workload_curve() -> void:
	check(Model.INITIAL_SETTLED_TILES == Catalog.BOARD_COLUMNS * Catalog.OPENING_ROWS
		and Model.DROP_COUNT == Catalog.BOARD_COLUMNS,
		"The timer's shared twenty-one/seven assumptions match actual opening and dispatch geometry")
	var first: Dictionary = Catalog.make_plan(1, words, 3, 71)
	check(first.seconds == 90.0 and first.words.size() == 3
		and first.goals.values().all(func(value: int) -> bool: return value == 1),
		"Stage one remains a funded, safe three-word teaching round")
	for number in [2, 6, 18, 36, 63, 98, 99]:
		var maximum: float = {2: 65.0, 6: 70.0, 18: 90.0, 36: 110.0, 63: 150.0, 98: 130.0, 99: 160.0}[number]
		for seed_value in range(100):
			var plan: Dictionary = Catalog.make_plan(number, words, 3, seed_value)
			check(plan.ok and plan.seconds <= maximum and plan.seconds >= 50.0,
				"Stage %d has a genuinely tighter pictured-word budget at seed %d: %.0fs" % [number, seed_value, plan.seconds])
			check(plan == Catalog.make_plan(number, words, 3, seed_value),
				"The harder recipe stays deterministic rather than reacting to owned upgrades")
	check(Catalog.make_plan(99, words, 3, 71).spawn_interval < 10.0,
		"Late ordinary supply pressure no longer bottoms out at the old ten-second cadence")
	check(Catalog.clear_reward(1, 1, 0).bonus >= 50,
		"Difficulty never removes the first-clear fifty-coin funding guarantee")


func _test_challenge_batch_time() -> void:
	var run := Run.new()
	check(run.configure(Catalog.make_plan(0, words, 3, 71, true)), "Configure a real bounded Challenge")
	run.advance(30.0)
	var goals: Array = run.snapshot().practice
	for index in range(goals.size()):
		check(run.record_collection("difficulty:challenge:%d" % index, str(goals[index].word_id)),
			"A real collected word completes its own Challenge objective")
		if index == 0:
			check(run.remaining == 60.0 and run.take_time_bonus() == 0.0,
				"Completing one word cannot repeatedly restore ten seconds")
	check(run.challenge_stage == 2 and run.remaining == 72.0 and run.take_time_bonus() == 12.0,
		"Completing the entire first batch grants one twelve-second headroom-bounded refund")
	var before: float = run.remaining
	run.record_collection("difficulty:challenge:0", str(goals[0].word_id))
	check(run.remaining == before and run.take_time_bonus() == 0.0,
		"An already paid batch cannot replay its time reward")
	run.challenge_stage = 25
	check(int(run.challenge_pressure().word_limit) <= 8, "Late batches keep a readable eight-word active window")


func _test_visible_boss_counters() -> void:
	var definition: Dictionary = BossCatalog.encounter(99)
	var boss := BossRun.new()
	boss.configure(definition, 71)
	check(boss.health >= 1300 and boss.clones == 2 and boss.ward == 0,
		"The finale starts with visible counter layers, not an unannounced two-hit finish")
	for index in range(2):
		boss.collect_hit("difficulty:clone:%d" % index, 9, 0, {})
	check(boss.health == int(definition.health) and boss.clones == 0 and boss.ward == 0,
		"The existing visible doubles each own one real counter interaction")
	boss.collect_hit("difficulty:high-hit", 9, 0, {})
	check(int(definition.health) - boss.health == BossCatalog.DAMAGE[9],
		"High-level Jelly damage is retained exactly rather than silently capped")
	check(BossCatalog.encounter(3).health == 98 and BossCatalog.encounter(1, true).intro,
		"The first encounter and nonpunitive teaching ambush retain their established character")


func _full_model(number: int):
	var plan: Dictionary = Catalog.make_plan(number, words, 3, 71, number == 0)
	plan["merged_level_limit"] = 1
	var model := Model.new()
	check(model.configure(plan.words, 3, 71) and model.bind_stage(plan), "Bind the real late-stage space rules")
	model.spawn_interval = 10000.0
	model._stage_spawn_interval = 10000.0
	model.cells.clear()
	for index in range(Model.CAPACITY):
		var tile: Dictionary = model._new_word_root(plan.words[0])
		model._set_merged_word(tile, plan.words[0], 1, true)
		tile.merge({"column": index % Model.COLUMNS, "row": int(index / Model.COLUMNS),
			"age": 100.0, "falling": false, "settling": false, "arrival": false}, true)
		model.cells.append(tile)
	model.step(0.01)
	return model


func _test_single_space_recovery() -> void:
	for number: int in [1, 6, 18, 36, 63, 99, 0]:
		var model = _full_model(number)
		var warning: Dictionary = model.danger_recovery_snapshot()
		check(model.full_elapsed >= 0.0 and warning.required_spaces == 1 and warning.spaces_needed == 1,
			"Every stage and Challenge asks for only one real empty cell")
		var committed: Array[Dictionary] = []
		model.collected.connect(func(_id: String, _word: Dictionary, _coins: int, _fragments: int) -> void:
			committed.append(model.danger_recovery_snapshot()), CONNECT_ONE_SHOT)
		check(model.collect(int(model.cells[0].id)), "Free Lv1 provides a legal one-cell recovery")
		model.step(Model.COLLECT_SECONDS - 0.001)
		check(model.full_elapsed >= 0.0, "A still-owned collection footprint does not invent an early vacancy")
		model.step(0.002)
		var recovery: Dictionary = model.danger_recovery_snapshot()
		check(committed.size() == 1 and not committed[0].active and committed[0].empty_spaces == 1
			and committed[0].spaces_needed == 0 and model.full_elapsed < 0.0 and model.stage_run.outcome.is_empty(),
			"The first committed vacancy immediately stops danger before any following dispatch")
		if number == 0:
			check(model.fill_mode and model.fill_mode_locked(),
				"Challenge keeps its actual automatic Fill rule after a one-space rescue")
		else:
			check(recovery.empty_spaces == 1 and model.can_drop_now(),
				"The one freed entrance immediately restores legal manual Next input")
		model.step(0.1)
		check(model.full_elapsed < 0.0, "A remaining vacancy cannot restart the full-board countdown")
		if number != 0:
			check(model.drop_now(), "A genuinely freed entrance can accept its advertised replacement")
		model.step(2.0)
		check(model.cells.size() == Model.CAPACITY and model.full_elapsed >= 0.0 and model.full_elapsed < 2.0,
			"Refilling the final vacancy starts a fresh warning only after the new body settles")
	var paused = _full_model(36)
	paused.step(1.0)
	var elapsed: float = paused.full_elapsed
	paused.set_paused(true)
	paused.step(20.0)
	check(paused.full_elapsed == elapsed, "Explicit pause cannot consume the harder rescue window")


func _test_recovery_geometry_and_ownership() -> void:
	var hidden = _full_model(36)
	for index in range(hidden.cells.size() - 1, -1, -1):
		if int(hidden.cells[index].row) == 3 and int(hidden.cells[index].column) == 0:
			hidden.cells.remove_at(index)
	var holes: Dictionary = hidden.danger_recovery_snapshot()
	check(holes.reachable_spaces == 0 and holes.empty_spaces == 1 and holes.spaces_needed == 0
		and not holes.can_receive_next,
		"A single internal vacancy counts even while every advertised entry remains blocked")
	hidden._refresh_full_recovery()
	check(hidden.full_elapsed < 0.0, "Any real vacancy ends the warning without an extra reachable-space requirement")
	hidden.step(0.1)
	check(hidden.full_elapsed < 0.0 and not hidden.can_drop_now(),
		"Blocked Next input cannot restart a full-board warning while an internal vacancy remains")
	var held = _full_model(36)
	var held_id: int = int(held.cells[0].id)
	held.set_held_tile(held_id)
	check(held.begin_drag(held_id), "A legal drag keeps its safe cancellation destination")
	check(held.danger_recovery_snapshot().empty_spaces == 0,
		"A lifted body still owns its return cell and cannot fake a committed vacancy")
	held._refresh_full_recovery()
	check(held.full_elapsed >= 0.0, "Holding a body does not clear a full board before an actual release")
	held.set_held_tile()
	var merging = _full_model(36)
	merging.merged_level_limit = 9
	check(merging.try_merge(int(merging.cells[0].id), int(merging.cells[1].id)) == "merged",
		"An actual legal merge reserves its destination rather than a test-only geometry placeholder")
	check(merging.danger_recovery_snapshot().empty_spaces == 0,
		"The in-flight fusion cannot release its source or future destination early")
	merging.step(Model.FUSION_SECONDS + 0.001)
	check(merging.danger_recovery_snapshot().empty_spaces == 1 and merging.full_elapsed < 0.0,
		"The committed two-to-one merge immediately ends danger with its single real vacancy")
	var challenge = _full_model(0)
	var original: Dictionary = challenge.danger_recovery_snapshot()
	challenge.stage_run.challenge_stage = 11
	challenge._sync_challenge_pressure()
	var continued: Dictionary = challenge.danger_recovery_snapshot()
	check(original.duration == 8.0 and original.required_spaces == 1
		and continued.duration == original.duration and continued.required_spaces == original.required_spaces,
		"A new Challenge batch retains the announced warning duration and the same one-space recovery rule")
	var incoming = _full_model(36)
	incoming.cells[10].age = 0.0
	incoming.cells[10].arrival = true
	incoming.cells[10].arrival_delay = 0.15
	var generated: int = incoming.generated_tiles
	incoming.step(0.2)
	check(incoming.cells[10].age > 0.19 and incoming.generated_tiles == generated and incoming.full_elapsed >= 0.0,
		"Already owned airborne bodies keep moving while recovery blocks only new dispatch")


func _run() -> void:
	var data := Data.new()
	check(data.load_all(), "Difficulty uses the current reviewed vocabulary and acquired pictures")
	words = data.words.filter(func(word: Dictionary) -> bool: return Data.word_age(word) == 3) \
		.map(func(word: Dictionary) -> Dictionary: return Morphology.decorate(word)) \
		.filter(func(word: Dictionary) -> bool: return word.morphology.parts.size() == 1 and not str(word.image).is_empty())
	check(words.size() >= 8, "The curve has a real eight-family pictured-word pool")
	_test_workload_curve()
	_test_challenge_batch_time()
	_test_visible_boss_counters()
	_test_single_space_recovery()
	_test_recovery_geometry_and_ownership()
	print("Jelly difficulty pressure: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
