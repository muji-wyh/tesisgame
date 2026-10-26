extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
const Data = preload("res://scripts/game_data.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(6):
		await process_frame


func advance(app, delta: float) -> void:
	app._word_jelly._process(delta)
	app._advance_ui(delta)
	if app._round_celebration_active():
		Fixture.finish_celebration(app)
	for card: Dictionary in app._jelly_rewards._cards:
		if card.art.mode == "opening":
			card.art._advance_animation(delta)


func defeat(app) -> void:
	var game = app._word_jelly.game
	game.cells.clear()
	game.upcoming.clear()
	game._supply.clear()
	game._supply_pending.clear()
	var word: Dictionary = game.stage_run.words[0]
	for index in range(12):
		if game.boss.health == 0:
			break
		var tile: Dictionary = game._new_word_root(word)
		game._set_merged_word(tile, word, 1, true)
		tile.column = index % 5
		tile.row = 7
		tile.age = 100.0
		tile.settling = false
		game.cells.append(tile)
		app._word_jelly._sync_tiles()
		check(game.collect(int(tile.id)), "A real committed merged-word pickup attacks the Boss")
		for frame in range(12):
			advance(app, 0.05)
	for frame in range(700):
		advance(app, 0.05)
		if app._campaign.map.visible:
			return
	check(false, "Boss escape, saved rewards and earned level return to the map: " + game.error + " / " + app._campaign.error)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	var directory: String = "user://boss-flow-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Boss flow owns isolated saves")
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_process(false)
	app._show_mode_menu()
	app.choose_mode("word_jelly")
	await settle()
	var words: Array = app.data.words.filter(func(word: Dictionary) -> bool: return Data.word_age(word) == 3) \
		.map(func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	var store = app._campaign.store
	for number in range(1, 9):
		var plan: Dictionary = Catalog.make_plan(number, words, 3, 71)
		check(store.reserve_plan("growth", plan) and store.queue_result("growth", "setup:%d" % number,
			{"kind": "main", "number": number, "outcome": "cleared", "stars": 3})
			and store.complete_result("growth", "setup:%d" % number), "Prepare a genuine contiguous earlier-stage record")
	app._campaign._show_map()
	app._campaign.request_stage(9)
	await settle()
	app._word_jelly.set_process(false)
	check(app._word_jelly.game.boss.active() and app._word_jelly.game.merged_level_limit == 1
		and app._word_jelly._boss_view.visible and not app._campaign.map.visible,
		"Selecting the marked first Boss stage opens the actual character, battle objective and Lv1 limit")
	var capture: bool = OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless"
	if capture:
		DirAccess.make_dir_recursive_absolute("res://build/qa/jelly-boss")
	for dimensions: Vector2i in [Vector2i(1366, 768), Vector2i(393, 852), Vector2i(390, 664)]:
		root.size = dimensions
		await settle()
		var view = app._word_jelly
		check(not view._layout_too_small and Rect2(Vector2.ZERO, view.size).grow(0.1).encloses(view._board),
			"The playable Boss well fits a real desktop/phone viewport at %s" % dimensions)
		check(view._boss_view._hud.end.y <= view._stage_banner._badge.position.y + 0.1
			and view._stage_banner._badge.end.y <= view._preview_rect.position.y + 0.1,
			"Boss, countdown and source preview reserve separate rows at %s" % dimensions)
		if capture:
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://build/qa/jelly-boss/battle-%d.png" % dimensions.x) == OK,
				"Capture the actual complete Boss application layout")
	root.size = Vector2i(1366, 768)
	await settle()
	defeat(app)
	check(app._campaign.map.visible and store.merged_level("growth") == 2
		and store.boss_victories("growth") == [1] and store.highest_cleared("growth") == 9,
		"The complete first Boss journey persists exactly one unlock and the next stage")
	var result: Dictionary = app._round_result
	check(result.get("boss", {}).get("outcome") == "defeated" and result.campaign.outcome == "cleared"
		and app.coin_wallet.balance == 150 and store.pending("growth").is_empty(),
		"Boss celebration/escape keeps the existing exact clear coins and fully completed settlement")
	var map_state: Dictionary = app._campaign.map.snapshot()
	check(map_state.boss_markers == [9, 18] and map_state.merged_level == 2,
		"The map keeps the unlocked rematch and exposes only the next future Boss")
	app._campaign.request_stage(9)
	await settle()
	app._word_jelly.set_process(false)
	check(app._word_jelly.game.merged_level_limit == 2, "The next real attempt receives the durably unlocked level")
	defeat(app)
	check(store.merged_level("growth") == 2 and app.coin_wallet.balance == 300,
		"A full rematch pays its normal clear reward without duplicating the level unlock")
	app.audio.halt()
	app.free()
	await settle()
	print("Jelly Boss application: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
