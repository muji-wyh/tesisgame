extends SceneTree

const Model = preload("res://scripts/word_jelly_model.gd")
const Boss = preload("res://scripts/word_jelly_boss_run.gd")
const BossCatalog = preload("res://scripts/word_jelly_boss_catalog.gd")
const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
const Data = preload("res://scripts/game_data.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")
var checks: int = 0
var failures: int = 0
var words: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func make_model(number: int = 9, level: int = 1):
	var plan: Dictionary = Catalog.make_plan(number, words, 3, 71)
	plan.boss = BossCatalog.encounter(number)
	plan.merged_level_limit = level
	var model = Model.new()
	model.allow_cross_age = true
	check(model.configure(plan.words, 3, 71) and model.bind_stage(plan), "Boss fights bind to real reviewed stage physics")
	model.cells.clear()
	model.upcoming.clear()
	model._supply.clear()
	model._supply_pending.clear()
	model.spawn_interval = 10000.0
	return model


func put(model, tile: Dictionary, column: int) -> Dictionary:
	tile.column = column
	tile.row = 7
	tile.age = 100.0
	tile.settling = false
	tile.falling = false
	tile.arrival = false
	model.cells.append(tile)
	return tile


func test_status_rules() -> void:
	var model = make_model(27)
	var word: Dictionary = model.stage_run.words[0]
	var root_tile: Dictionary = put(model, model._new_word_root(word), 0)
	var picture: Dictionary = put(model, model._new_picture_tile(word), 1)
	check(model.boss.apply_status("freeze", int(root_tile.id)), "A Boss can freeze a real body")
	model.set_held_tile(int(root_tile.id))
	check(not model.begin_drag(int(root_tile.id)) and not model.can_merge(root_tile, picture)
		and model.try_merge(int(picture.id), int(root_tile.id)) == "blocked" and model._held_tile_id < 0,
		"Freeze blocks dragging and matching in either direction")
	model.step(2.999)
	check(model.boss.frozen(int(root_tile.id)), "Freeze remains active before the exact three-second boundary")
	model.step(0.001)
	check(not model.boss.frozen(int(root_tile.id)), "Freeze expires exactly at three active-play seconds")
	model.boss.apply_status("ink", int(root_tile.id))
	check(model.can_merge(root_tile, picture), "Obscuring contents never changes the underlying valid match")
	model.boss.apply_status("lock", int(root_tile.id))
	model.boss.apply_status("lock", int(root_tile.id))
	check(not model.boss.apply_status("lock", int(root_tile.id)) and model.boss.locks(int(root_tile.id)) == 2,
		"A third lock is ineffective")
	var before: int = model.merged_count
	check(model.try_merge(int(root_tile.id), int(picture.id)) == "unlocked"
		and model.boss.locks(int(root_tile.id)) == 1 and model.merged_count == before,
		"A valid forward match removes one lock without consuming or crediting the pair")
	check(model.try_merge(int(picture.id), int(root_tile.id)) == "unlocked"
		and model.boss.locks(int(root_tile.id)) == 0 and model.cells.size() == 2,
		"A valid reverse match removes the second lock and preserves both bodies")
	check(model.try_merge(int(root_tile.id), int(picture.id)) == "merged",
		"Once unlocked, the next ordinary match uses the established fusion")


func test_combat_clock_and_damage() -> void:
	var run := Boss.new()
	run.configure(BossCatalog.encounter(9), 71)
	check(run.collect_hit("word:1", 1, 0, {}) and run.health == 84,
		"A committed Lv1 collection has a useful fourteen-point attack")
	check(not run.collect_hit("word:1", 1, 0, {}) and run.health == 84,
		"Duplicate collection acknowledgements cannot hit twice")
	run.charge_merge(false, true)
	run.collect_hit("word:2", 1, 4, {})
	check(run.health < 70 and run.charge == 0, "Manual charge and combo strengthen the next collection attack")
	run.configure(BossCatalog.encounter(45), 71)
	run.advance(2.2, [{"id": 1, "column": 0, "row": 7}], true)
	check(run.broken_remaining == 0.0, "A kick is telegraphed before it damages the supply")
	run.advance(Boss.WINDUP_SECONDS, [], true)
	check(run.broken_remaining == 8.0 and run.snapshot().drop_limit == 2,
		"The giant kick damages supply for exactly eight seconds")
	run.advance(100.0, [], false)
	check(run.broken_remaining == 8.0, "An interrupted battle freezes the supply-repair clock")
	run.advance(7.999, [], true)
	check(run.snapshot().drop_limit == 2, "Damaged supply remains restricted until the boundary")
	run.advance(0.001, [], true)
	check(run.snapshot().drop_limit == 5, "The full five-slot supply returns exactly after eight active seconds")
	run.configure(BossCatalog.encounter(36), 71)
	run.advance(2.2, [{"id": 1, "column": 0, "row": 7}], true)
	var health: int = run.health
	run.collect_hit("clone:1", 1, 0, {})
	run.collect_hit("clone:2", 1, 0, {})
	check(run.clones == 0 and run.health == health, "Two genuine collected-word attacks disperse the shadow doubles")
	run.collect_hit("clone:3", 1, 0, {})
	check(run.health < health, "The revealed Boss receives the next attack")


func test_levels_and_story() -> void:
	check(BossCatalog.STAGES.size() == 8 and BossCatalog.merged_level([]) == 1
		and BossCatalog.merged_level([1, 1, 2]) == 3
		and BossCatalog.merged_level([1, 2, 3, 4, 5, 6, 7, 8]) == 9,
		"Only distinct first victories unlock the eight remaining merged levels")
	check(BossCatalog.map_markers(1) == [9] and BossCatalog.map_markers(20) == [9, 18, 27],
		"Map markers include unlocked Bosses and only the next future encounter")
	var model = make_model()
	var word: Dictionary = model.stage_run.words[0]
	var first: Dictionary = model._new_word_root(word)
	model._set_merged_word(first, word, 1, true)
	var second: Dictionary = model._new_word_root(word)
	model._set_merged_word(second, word, 1, true)
	put(model, first, 0)
	put(model, second, 1)
	check(model.try_merge(int(first.id), int(second.id)) == "level_locked" and model.cells.size() == 2,
		"Locked merged levels cannot consume their inputs, mass or carried treasure")
	model.boss.apply_status("lock", int(first.id))
	check(model.try_merge(int(second.id), int(first.id)) == "unlocked"
		and model.boss.locks(int(first.id)) == 0 and model.cells.size() == 2,
		"A level cap cannot make a matching locked merged word permanently impossible to unlock")
	check(model._blast_target_ids({"id": -1, "column": 0, "row": 6}, 1).size() == 2,
		"Lv1 now reaches two nearby bodies instead of having no support ability")
	var intro := Boss.new()
	intro.configure(BossCatalog.encounter(1, true), 71)
	intro.begin_ending("cleared")
	check(intro.outcome == "ambushed" and not intro.presentation_ready(),
		"The successful tutorial leads to the story defeat, not a fabricated Boss victory")
	intro.advance(Boss.ENDING_SECONDS, [], false)
	check(intro.presentation_ready(), "The ambush/taunt/escape finishes before normal settlement")


func test_snatch_recovery() -> void:
	var model = make_model(63, 6)
	var word: Dictionary = model.stage_run.words[0]
	var tile: Dictionary = put(model, model._new_word_root(word, 3), 0)
	tile.source_word_id = word.id
	var id: int = int(tile.id)
	model.boss._projectile("snatch", tile)
	model.step(Boss.WINDUP_SECONDS + Boss.FLIGHT_SECONDS)
	check(model.cell(id).is_empty() and model._boss_returning.size() == 1,
		"A completed grab removes its actual unreserved body from the board")
	model.step(1.4)
	var restored: Array = model.upcoming.filter(func(item: Dictionary) -> bool: return int(item.get("id", -1)) == id)
	if restored.is_empty():
		restored = model._supply.filter(func(item: Dictionary) -> bool: return int(item.get("id", -1)) == id)
	check(restored.size() == 1 and int(restored[0].fragments) == 3
		and restored[0].source_word_id == tile.source_word_id,
		"The exact grabbed identity and carried fragments return once, without orphaning a partner")
	check(model.cleared_pairs == 0 and model.fragment_count == 0 and model.collected_coins == 0,
		"Snatching and returning a construction piece cannot manufacture learning or rewards")


func _run() -> void:
	var data := Data.new()
	check(data.load_all(), "Load the real vocabulary for Boss integration")
	words = data.words.filter(func(word: Dictionary) -> bool: return Data.word_age(word) == 3) \
		.map(func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	test_status_rules()
	test_combat_clock_and_damage()
	test_levels_and_story()
	test_snatch_recovery()
	print("Jelly Boss rules: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
