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


func capture_frame(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute("res://build/qa/jelly-boss")
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://build/qa/jelly-boss/" + name + ".png") == OK,
		"Capture the actual in-application " + name)


func defeat(app) -> void:
	var game = app._word_jelly.game
	var captured_ending: bool = false
	for frame in range(40):
		advance(app, 0.05)
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
	for required_word: Dictionary in game.stage_run.words:
		var missing: int = int(game.stage_run.goals[required_word.id]) - int(game.stage_run.current[required_word.id])
		for index in range(missing):
			var tile: Dictionary = game._new_word_root(required_word)
			game._set_merged_word(tile, required_word, 1, true)
			tile.column = index % 5
			tile.row = 7
			tile.age = 100.0
			tile.settling = false
			game.cells.append(tile)
			app._word_jelly._sync_tiles()
			check(game.collect(int(tile.id)), "The Boss victory still needs every remaining word goal")
			for frame in range(12):
				advance(app, 0.05)
	for frame in range(700):
		advance(app, 0.05)
		if game.snapshot().clear_phase == "announcement" \
			and game._stage_clear_feedback < 0.5 and not captured_ending:
			captured_ending = true
			await capture_frame("clear-before-sweep")
		if app._campaign.map.visible:
			return
	check(false, "Boss escape and saved rewards return to the map: " + game.error + " / " + app._campaign.error)


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
	for number in range(1, 3):
		var plan: Dictionary = Catalog.make_plan(number, words, 3, 71)
		check(store.reserve_plan("growth", plan) and store.queue_result("growth", "setup:%d" % number,
			{"kind": "main", "number": number, "outcome": "cleared", "stars": 3})
			and store.complete_result("growth", "setup:%d" % number), "Prepare a genuine contiguous earlier-stage record")
	app._campaign._show_map()
	Fixture.dismiss_jelly_upgrade_intro(app)
	await settle()
	app._campaign.request_stage(3)
	await settle()
	for frame in range(60):
		if not app._campaign.starting:
			break
		await process_frame
	app._word_jelly.set_process(false)
	check(app._word_jelly.game.boss.active() and app._word_jelly.game.merged_level_limit == 1
		and app._word_jelly._boss_view.visible and not app._campaign.map.visible,
		"Selecting the marked first Boss stage opens the actual character, battle objective and Lv1 limit: "
		+ JSON.stringify({"error": app._campaign.error, "starting": app._campaign.starting,
			"map": app._campaign.map.visible, "upgrades": app._campaign.upgrades.visible,
			"intro": app._campaign.store.upgrade_state().intro, "model_error": app._word_jelly.game.error}))
	if app._word_jelly.game.stage_run == null:
		app.audio.halt()
		app.free()
		await settle()
		quit(1)
		return
	var capture: bool = OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless"
	if capture:
		DirAccess.make_dir_recursive_absolute("res://build/qa/jelly-boss")
	for frame in range(6):
		advance(app, 0.05)
	await capture_frame("ready")
	for frame in range(13):
		advance(app, 0.05)
	await capture_frame("go")
	for frame in range(20):
		advance(app, 0.05)
	for dimensions: Vector2i in [Vector2i(1366, 768), Vector2i(393, 852), Vector2i(390, 664), Vector2i(320, 480), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		var view = app._word_jelly
		check((not view._layout_too_small and Rect2(Vector2.ZERO, view.size).grow(0.1).encloses(view._board)) \
			or (dimensions == Vector2i(320, 480) and view._layout_too_small and view.game.paused and view._size_cover.visible),
			"The Boss well fits the actual viewport or explicitly pauses an undersized screen instead of shrinking below readable cells: %s pitch=%.12f field=%s board=%s" % [
				dimensions, view._pitch * app.Style.ui_scale(view), view.size, view._board])
		check(not view._practice_panel._compact
			and view._practice_panel.get_rect().end.x <= view._board.position.x
			and not view._practice_panel.get_rect().intersects(view._preview_rect),
			"Boss targets remain in their reserved left column, never a top carousel")
		var actor: Rect2 = view._boss_view._character_rect
		check(not actor.intersects(view._board) and not actor.intersects(view._preview_rect)
			and not actor.intersects(view._practice_panel.get_rect())
			and not actor.intersects(view.collect_button.get_rect()) and Rect2(Vector2.ZERO, view.size).grow(0.1).encloses(actor),
			"The Boss stands outside the actual playable well, supply and Collect at %s" % dimensions)
		for button: Control in view.powerup_buttons.values():
			check(not actor.intersects(button.get_rect()), "The side-standing Boss leaves every tool usable")
		check(not actor.intersects(view._combo_hud.get_rect()),
			"The combo badge and Boss use distinct responsive side/header space")
		var dialogue: Label = view._boss_view._dialogue
		if not view._layout_too_small and dialogue.visible:
			check(dialogue.get_line_count() <= 2 and dialogue.get_visible_line_count() >= dialogue.get_line_count(),
				"The actual two-line challenge remains readable at %s: lines=%d visible=%d rect=%s font=%d" % [
					dimensions, dialogue.get_line_count(), dialogue.get_visible_line_count(),
					dialogue.get_rect(), dialogue.get_theme_font_size("font_size")])
		if capture:
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://build/qa/jelly-boss/battle-%d.png" % dimensions.x) == OK,
				"Capture the actual complete Boss application layout")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(480, 480)
	root.size = Vector2i(376, 852)
	await settle()
	var web_view = app._word_jelly
	var web_pitch: float = web_view._pitch * app.Style.ui_scale(web_view)
	check(is_equal_approx(app.Style.ui_scale(web_view), 376.0 / 480.0)
		and is_equal_approx(web_pitch, 32.0) and not web_view._layout_too_small
		and not web_view.game.paused,
		"Web's fractional phone scale keeps a mathematically 32px seven-column Boss board playable: %.12f" % web_pitch)
	root.size = Vector2i(320, 480)
	await settle()
	check(web_view._layout_too_small and web_view.game.paused and web_view._size_cover.visible,
		"The Web-scale boundary tolerance never admits a genuinely undersized board")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	await settle()
	await defeat(app)
	check(app._campaign.map.visible and store.merged_level() == 1
		and store.boss_victories("growth") == [1] and store.highest_cleared("growth") == 3,
		"The complete first Boss journey persists its victory and next stage without a Jelly unlock")
	var result: Dictionary = app._round_result
	check(result.get("boss", {}).get("outcome") == "defeated" and result.campaign.outcome == "cleared"
		and app.coin_wallet.balance == 150 and store.pending("growth").is_empty(),
		"Boss celebration/escape keeps the existing exact clear coins and fully completed settlement")
	var map_state: Dictionary = app._campaign.map.snapshot()
	check(map_state.boss_markers == [3, 5] and map_state.merged_level == 1,
		"The map keeps the unlocked rematch and exposes only the next future Boss")
	app._campaign.request_stage(3)
	await settle()
	app._word_jelly.set_process(false)
	check(app._word_jelly.game.merged_level_limit == 1, "The next real attempt still uses the coin-owned level")
	await defeat(app)
	check(store.merged_level() == 1 and app.coin_wallet.balance == 300,
		"A full rematch pays its normal clear reward without changing Jelly ownership")
	app.audio.halt()
	app.free()
	await settle()
	print("Jelly Boss application: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
