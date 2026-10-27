extends SceneTree

const Map = preload("res://scripts/word_jelly_map.gd")
const Jelly = preload("res://scripts/word_jelly.gd")
const Skill = preload("res://scripts/word_jelly_skill_reveal.gd")
const Data = preload("res://scripts/game_data.gd")
const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
const BossCatalog = preload("res://scripts/word_jelly_boss_catalog.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")
const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func capture_ui(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	for frame in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa/jelly-followup")
	check(root.get_texture().get_image().save_png("res://build/qa/jelly-followup/" + name + ".png") == OK,
		"Capture the actual " + name)


func test_map() -> void:
	var map := Map.new()
	root.add_child(map)
	map.size = Vector2(393, 700)
	map.open({"highest_cleared": 0, "merged_level": 1, "boss_markers": [1, 3]}, false)
	map.set_process(false)
	check(map.snapshot().unlock.phase == "done" and not map._nodes[0].boss.visible,
		"A new save neither invents an unlock animation nor spoils the opening Boss")
	var next := {"highest_cleared": 1, "merged_level": 1, "boss_markers": [3]}
	map.configure(next, false)
	map.set_process(false)
	check(map.snapshot().unlock.from == 1 and map.snapshot().unlock.to == 2
		and map.snapshot().unlock.phase == "route" and map._nodes[1].padlock.visible,
		"A new clear starts a journey from the completed node, with its destination still visibly locked")
	map._process(Map.ROUTE_SECONDS - 0.001)
	check(map.snapshot().unlock.phase == "route" and map._nodes[1].padlock.visible,
		"The route reaches the next stage before the actual lock-opening beat")
	map._process(0.001 + Map.UNLOCK_SECONDS * 0.5)
	check(map.snapshot().unlock.phase == "node" and map._nodes[1].face.scale.x > 1.1
		and map._nodes[1].padlock.modulate.a < 0.6,
		"Arrival opens the lock with an explicit sourced-light flourish and node pop")
	map._process(Map.UNLOCK_SECONDS)
	check(map.snapshot().unlock.phase == "done" and not map._nodes[1].padlock.visible
		and map._nodes[2].padlock.visible and map._nodes[98].padlock.visible,
		"Only the newly opened lock disappears; every future stage retains its lock marker")
	map.close()
	map.open(next, false)
	map.set_process(false)
	check(map.snapshot().unlock.phase == "done", "Reopening or replaying preserved progress cannot replay an unlock")
	map.configure({"highest_cleared": 2, "merged_level": 1}, true)
	check(map.snapshot().unlock.phase == "done" and not map._nodes[2].padlock.visible
		and not map.is_processing(), "Reduced motion directly presents the earned state without a moving route")
	map.free()


func test_entry_and_lv1(data, words: Array) -> void:
	var legacy_banner = Jelly.StageBanner.new()
	root.add_child(legacy_banner)
	legacy_banner.set_stage({"number": 2, "mastered": 0, "total": 4}, true)
	check(not legacy_banner.ready_pending() and legacy_banner._title.text == "Stage 2",
		"An unbound progressive wave keeps its existing immediate supply handoff instead of freezing a new round")
	legacy_banner.present_stage_clear(Jelly.WordModel.STAGE_CLEAR_NOTICE_SECONDS)
	legacy_banner.advance(0.8)
	check(legacy_banner._card.visible and legacy_banner._card.modulate.a > 0.0
		and legacy_banner._card.modulate.a < 1.0,
		"The short clear notice fades before the model's automatic sweep boundary")
	legacy_banner.advance(0.2)
	check(not legacy_banner._card.visible, "The clear notice ends at the actual one-second handoff")
	legacy_banner.set_stage({"number": 2, "mastered": 0, "total": 4}, true)
	legacy_banner.advance(1.2)
	check(legacy_banner._card.visible, "A new ordinary arrival restores its original longer presentation")
	legacy_banner.free()
	var view := Jelly.new()
	root.add_child(view)
	view.size = Vector2(1000, 700)
	var plan: Dictionary = Catalog.make_plan(1, words, 3, 71)
	plan.boss = BossCatalog.encounter(1, true)
	plan.merged_level_limit = 1
	check(view.configure(plan.words, 3, Data.theme("spring"), data.chests, false, 71)
		and view.game.bind_stage(plan), "The entry uses the real opening stage and its Lv1-only progression")
	view.set_process(false)
	view.set_stage_progress({"kind": "main", "number": 1, "total": plan.words.size(), "mastered": 0,
		"seconds_remaining": 120.0, "seconds_total": 120.0}, true)
	view._process(0.5)
	check(view.game.paused and is_zero_approx(view.game.stage_run.elapsed)
		and view._stage_banner.snapshot().entry_phase == "ready",
		"Ready artwork does not charge the player's stage or supply clock")
	view.pause(true, true)
	var frozen: float = view._stage_banner._elapsed
	view._process(0.3)
	check(view._stage_banner._elapsed == frozen, "A real pause freezes the game-start effect")
	view.pause(false)
	view._process(view.StageBanner.READY_SECONDS - frozen)
	check(not view.game.paused and view._stage_banner._title.text == "Go!"
		and is_zero_approx(view.game.stage_run.elapsed),
		"Go enables real input at the exact boundary without billing the earlier Ready time")
	view._process(0.1)
	check(is_equal_approx(view.game.stage_run.elapsed, 0.1),
		"Only active time after Go advances the stage")
	view.game.cells.clear()
	view.game.upcoming.clear()
	view.game._supply.clear()
	view.game._supply_pending.clear()
	var word: Dictionary = view.game.stage_run.words[0]
	for tile: Dictionary in [view.game._new_word_root(word), view.game._new_picture_tile(word)]:
		tile.column = view.game.cells.size()
		tile.row = 7
		tile.age = 100.0
		tile.settling = false
		view.game.cells.append(tile)
	var first: int = int(view.game.cells[0].id)
	var second: int = int(view.game.cells[1].id)
	check(view.game.try_merge(first, second) == "merged",
		"The actual stage-one word and picture can form Lv1 despite the higher-level upgrade cap")
	view.game.step(view.WordModel.FUSION_SECONDS + view.WordModel.SETTLE_SECONDS)
	check(view.game.cells.size() == 1 and view.game.is_valid_word(view.game.cells[0])
		and int(view.game.cells[0].merge_level) == 1,
		"The first stage produces a real collectible Lv1 Jelly, not a locked upgrade or a placeholder")
	view.game.drag_blocked.emit("level_locked")
	check(view.find_child("JellyRoomNotice", true, false) == null and not view.snapshot().drag.needs_room,
		"A blocked higher upgrade cannot open the misleading Make room board-covering notice")
	view._sync_boss()
	check(not view._boss_view.visible, "The first-stage visitor stays secret while the lesson remains live")
	view.free()


func test_skills(word: Dictionary) -> void:
	var skill := Skill.new()
	root.add_child(skill)
	var acceptances: Array[int] = []
	skill.accepted.connect(func() -> void: acceptances.append(1))
	for level in range(2, 10):
		skill.size = Vector2(390, 500)
		check(skill.present(level, word, false) and skill.snapshot().level == level
			and not skill.snapshot().description.is_empty(), "Every earned level explains its actual collection skill")
		check(skill.snapshot().preview_targets == [4, 6, 8, 4, 8, 12, 22, 24][level - 2],
			"Skill %d previews its correct local/column/cross/ring/board footprint" % level)
		skill._continue.pressed.emit()
		check(skill.visible and acceptances.size() == level - 2, "A held old accept cannot skip an unread unlock")
		skill.advance(1.1)
		for dimensions: Vector2 in [Vector2(320, 220), Vector2(393, 500), Vector2(1000, 600)]:
			skill.size = dimensions
			skill._layout()
			var bounds := Rect2(Vector2.ZERO, dimensions)
			for control: Control in [skill._title, skill._level_label, skill._description, skill._demo, skill._continue]:
				check(bounds.grow(0.1).encloses(control.get_rect()),
					"The skill artwork, explanation and Continue remain inside a real short/phone/desktop surface")
		skill._continue.pressed.emit()
		check(not skill.visible and acceptances.size() == level - 1, "Each read skill accepts exactly once")
	skill.free()


func test_level_and_finale(data, words: Array) -> void:
	var map := Map.new()
	root.add_child(map)
	for dimensions: Vector2i in [Vector2i(1366, 768), Vector2i(393, 852), Vector2i(844, 390)]:
		root.size = dimensions
		map.size = dimensions
		map.open({"highest_cleared": 98, "merged_level": 4, "coins": 970, "boss_markers": [3, 5, 7, 9, 18, 36, 63, 99]}, true)
		map.set_process(false)
		check(map.snapshot().merged_level_indicator.level == 4 and map._merged_level_badge._label.text == "Jelly Lv4",
			"The map explicitly names the unlocked Jelly cap instead of confusing it with Pip or treasure levels")
		check(map._challenge.text == "Challenge" and map._challenge.tooltip_text.is_empty()
			and not map._challenge.get_rect().intersects(map._heading.get_rect())
			and (not map._wallet.visible or not map._challenge.get_rect().intersects(map._wallet.get_rect())),
			"The sourced-medal Challenge action is always named and leaves the scaled wallet readable")
		check(map._nodes[98].boss.visible and map._nodes[98].boss_aura.visible
			and map._nodes[98].boss.size.x > map._nodes[2].boss.size.x * 1.7,
			"The finale uses a distinct enlarged real Boss portrait and acquired energy aura")
		await capture_ui("final-boss-map-%d" % dimensions.x)
	map.configure({"highest_cleared": 0, "merged_level": 1, "boss_markers": [3]}, true)
	check(map._nodes[98].boss.visible and map._nodes[98].boss.disabled and not map._nodes[4].boss.visible,
		"Only the special finale and the next future encounter are revealed; a locked finale is not playable")
	map.free()
	for dimensions: Vector2i in [Vector2i(1366, 768), Vector2i(393, 852), Vector2i(844, 390)]:
		root.size = dimensions
		var view := Jelly.new()
		root.add_child(view)
		view.size = dimensions
		var plan: Dictionary = Catalog.make_plan(3, words, 3, 71)
		plan.merged_level_limit = 4
		plan.boss = BossCatalog.encounter(3)
		check(view.configure(plan.words, 3, Data.theme("spring"), data.chests, false, 71)
			and view.game.bind_stage(plan), "The current-level indicator uses a genuinely bound Boss round")
		view.set_stage_progress(view.game.stage_run.snapshot(), true)
		view.set_process(false)
		view._layout()
		var badge: Rect2 = view._merged_level_badge.get_rect()
		check(view._merged_level_badge.visible and view.snapshot().merged_level_indicator.text == "Jelly Lv4"
			and Rect2(Vector2.ZERO, view.size).grow(0.1).encloses(badge),
			"The actual playable Boss HUD clearly retains the unlocked Jelly level on desktop and phones")
		for reserved: Rect2 in [view._board, view._preview_rect, view.collect_button.get_rect(),
			view._combo_hud.get_rect(), view._boss_view._character_rect]:
			check(not badge.intersects(reserved), "The level badge never covers the well, supply, controls, combo or Boss")
		await capture_ui("current-jelly-level-%d" % dimensions.x)
		view.free()


func test_challenge_best_hud() -> void:
	root.size = Vector2i(393, 852)
	var directory: String = "user://challenge-hud-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Challenge HUD uses isolated real save storage")
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	for frame in range(6):
		await process_frame
	app.audio.set_muted(true)
	app.set_process(false)
	app._show_mode_menu()
	app.choose_mode("word_jelly")
	for frame in range(6):
		await process_frame
	check(app._campaign.store.record_challenge_stage("growth", 5), "Prepare a real historical best of Stage 5")
	app._campaign.request_challenge()
	for frame in range(6):
		await process_frame
	var view = app._word_jelly
	view.set_process(false)
	for frame in range(40):
		view._process(0.05)
		app._advance_ui(0.05)
	check(view.game.stage_run.challenge_stage == 1 and view._practice_panel._subtitle.text == "Best stage 5"
		and view._practice_panel._subtitle.is_visible_in_tree() and view.game.stage_run.remaining > 0.0,
		"Entering the real phone Challenge immediately shows current Stage 1 and its persisted historical best")
	await capture_ui("challenge-stage-1-best-5")
	var goals: Array = view.game.stage_run.snapshot().practice.duplicate(true)
	view.game.cells.clear()
	for goal: Dictionary in goals:
		var definition: Dictionary = view.game.stage_run.words.filter(func(word: Dictionary) -> bool:
			return str(word.id) == str(goal.word_id))[0]
		var tile: Dictionary = view.game._new_word_root(definition)
		view.game._set_merged_word(tile, definition, 1, true)
		tile.column = 0
		tile.row = 7
		tile.age = 100.0
		tile.settling = false
		view.game.cells.append(tile)
		view._sync_tiles()
		view._collect(int(tile.id))
		for frame in range(12):
			view._process(0.05)
			app._advance_ui(0.05)
	check(view.game.stage_run.challenge_stage == 2 and view.game.stage_run.snapshot().pressure.level == 2
		and app._campaign.store.challenge_best_stage("growth") == 5,
		"The full actual goal batch starts Stage 2 without overwriting a higher historical best")
	view._drop_next()
	for frame in range(68):
		view._process(0.05)
		app._advance_ui(0.05)
	await capture_ui("challenge-stage-2-time-goals")
	app.audio.halt()
	app.free()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1000, 760)
	var data := Data.new()
	check(data.load_all(), "Presentation contracts use the real vocabulary and acquired artwork")
	var words: Array = data.words.filter(func(word: Dictionary) -> bool: return Data.word_age(word) == 3) \
		.map(func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	test_map()
	test_entry_and_lv1(data, words)
	test_skills(words[0])
	await test_level_and_finale(data, words)
	await test_challenge_best_hud()
	print("Jelly presentation refinements: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
