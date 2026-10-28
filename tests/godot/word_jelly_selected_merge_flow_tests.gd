extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Data = preload("res://scripts/game_data.gd")
const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")
var checks: int = 0
var failures: int = 0
var seed_value: int = 1900


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(5):
		await process_frame


func click(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
		await process_frame


func capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	await settle()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa/jelly-revision")
	check(root.get_texture().get_image().save_png("res://build/qa/jelly-revision/" + name + ".png") == OK,
		"Capture the actual " + name)


func prepare(app) -> Array:
	seed_value += 1
	check(app.new_round(seed_value, false, "", "word_jelly"), "Start the actual application's Word Jelly route")
	await settle()
	var view = app._word_jelly
	view.set_process(false)
	var words: Array = app._learning_words().filter(func(word: Dictionary) -> bool:
		return not str(word.get("image", "")).is_empty()).slice(0, 2).map(
			func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	check(view.configure(words, app.growth.learning_age(), Data.theme(app.model.theme_id),
		app.data.chests, false, seed_value), "Use current-age production words, pictures and the real control layout")
	view.game.cells.clear()
	view.game.spawn_interval = 10000.0
	for index in range(4):
		var tile: Dictionary = view.game._new_word_root(words[index / 2]) if index % 2 == 0 \
			else view.game._new_picture_tile(words[index / 2])
		put(view.game, tile)
	Fixture.unlock_auto_collect(app)
	app._sync_jelly()
	view.set_process(false)
	view._sync_tiles()
	view._layout()
	view._process(0.0)
	await settle()
	return words


func put(model, tile: Dictionary) -> void:
	var at: Vector2i = model._free_position(model._occupied(), 1, 1)
	tile.column = at.x
	tile.row = at.y
	tile.age = 100.0
	tile.settling = false
	tile.arrival = false
	model.cells.append(tile)


func test_selection(app) -> void:
	var words: Array = await prepare(app)
	var view = app._word_jelly
	var model = view.game
	for level in [2, 3]:
		var body: Dictionary = model._new_word_root(words[0])
		model._set_merged_word(body, words[0], level, true)
		put(model, body)
	view._sync_tiles()
	view._layout()
	view._process(0.0)
	await settle()
	var selected: int = int(model.cells[0].id)
	var unrelated: Array[int] = [int(model.cells[2].id), int(model.cells[3].id)]
	var before: int = app.coin_wallet.balance
	var receipts: int = app.coin_wallet._receipts.size()
	var generated: int = model.generated_tiles
	var growth: Dictionary = app.growth.snapshot().streaks.duplicate(true)
	var spoken: Array = []
	var on_word: Callable = func(word: Dictionary) -> void: spoken.append(word.id)
	view.word_requested.connect(on_word)
	await click(view.powerup_buttons.family_merge)
	check(view.snapshot().family_selection.active and view.powerup_buttons.family_merge.snapshot().title == "Pick Jelly"
		and app.coin_wallet.balance == before and not model.powerup_active() and model._held_tile_id < 0,
		"A real Magnet click arms a visible choice without spending, holding a body or picking at random")
	await capture("magnet-pick-jelly")
	view._drop_next()
	check(view.drop_button.disabled and not view.snapshot().preview.enabled
		and not view.navigation_controls().has(view.drop_button) and model.generated_tiles == generated,
		"Keyboard/controller supply activation is unavailable during target selection, not just pointer drops")
	await click(view.drop_button)
	check(view.snapshot().family_selection.active and model.generated_tiles == generated and spoken.is_empty(),
		"The supply cannot dispatch or read a word while the player is choosing a board Jelly")
	await click(view._tiles[selected])
	check(model.powerup_active() and model.powerup_snapshot().kind == "family_merge"
		and model.powerup_snapshot().family_word_id == words[0].id
		and not view.snapshot().family_selection.active and app.coin_wallet.balance == before - 200
		and app.coin_wallet._receipts.size() == receipts + 1 and app._status_announcement.contains("Magnet purchased"),
		"The actual selected board Jelly commits one correctly named, durable two-hundred-coin purchase")
	view._process(0.16)
	check(not view._powerup_effects.stamps.is_empty(), "Selected-family motion uses the actual automatic-flight presentation")
	for frame in range(300):
		if not model.powerup_active():
			break
		view._process(0.04)
	check(not model.powerup_active() and model.cells.size() == 3
		and model.cells.any(func(tile: Dictionary) -> bool: return tile.get("word", {}).get("id") == words[0].id and tile.merge_level == 6),
		"Roots, pictures and different levels of the chosen family finish one real Lv6 Jelly")
	check(not model.cell(unrelated[0]).is_empty() and not model.cell(unrelated[1]).is_empty()
		and spoken.is_empty() and model.cleared_pairs == 0 and model.combo_coins == 0
		and app.growth.snapshot().streaks == growth and app.coin_wallet.balance == before - 200,
		"Selection cannot accidentally collect, pronounce, spend again or consume another family")
	view.word_requested.disconnect(on_word)


func test_cancel_and_fill(app) -> void:
	await prepare(app)
	var view = app._word_jelly
	var before: int = app.coin_wallet.balance
	await click(view.powerup_buttons.family_merge)
	await click(view.powerup_buttons.family_merge)
	check(not view.snapshot().family_selection.active and app.coin_wallet.balance == before,
		"Pressing Magnet again cancels the real selector without a charge")
	await click(view.powerup_buttons.family_merge)
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await process_frame
	check(not view.snapshot().family_selection.active and app.coin_wallet.balance == before,
		"Controller Back and keyboard Cancel leave no target or paid obligation")
	await click(view.powerup_buttons.family_merge)
	view.pause(true)
	check(not view.snapshot().family_selection.active, "Pause clears the selector instead of resurrecting a stale target after resume")
	view.pause(false)
	var generated: int = view.game.generated_tiles
	check(view.navigation_controls().has(view._fill_button),
		"The optional Fill switch belongs to the actual controller navigation surface")
	await click(view._fill_button)
	view._process(0.01)
	check(view.game.fill_mode and view.game.generated_tiles > generated,
		"The real optional Fill button starts normal advertised supply flights")
	await click(view._fill_button)
	check(not view.game.fill_mode, "Main/unbound play can turn Fill back off while already launched pieces settle")
	view._process(2.0)
	await click(view._fill_button)
	check(view.game.fill_mode, "The ordinary Fill preference can be on before entering Challenge")
	var words: Array = view.game._words.duplicate(true)
	var plan: Dictionary = Catalog.make_plan(0, words, app.growth.learning_age(), seed_value, true)
	check(view.game.bind_stage(plan), "Bind the actual ninety-second Challenge model: " + str(plan.get("error", "")) + view.game.error)
	view._refresh_controls()
	view._layout()
	await click(view._fill_button)
	check(view._fill_button.disabled and view._fill_button.button_pressed and view.game.fill_mode
		and view.snapshot().fill_control.locked, "Challenge visibly forces Fill on and rejects a real attempt to switch it off")
	check(view.configure(words, app.growth.learning_age(), Data.theme(app.model.theme_id), app.data.chests, false, seed_value)
		and view.game.fill_mode and not view.game.fill_mode_locked(),
		"Leaving Challenge restores the independent ordinary Fill preference rather than persisting the forced lock")


func test_keyboard_and_controller(app) -> void:
	for controller: bool in [false, true]:
		await prepare(app)
		var view = app._word_jelly
		var id: int = int(view.game.cells[0].id)
		var before: int = app.coin_wallet.balance
		await click(view.powerup_buttons.family_merge)
		view._tiles[id].grab_focus()
		for pressed: bool in [true, false]:
			if controller:
				var button := InputEventJoypadButton.new()
				button.button_index = JOY_BUTTON_A
				button.pressed = pressed
				Input.parse_input_event(button)
			else:
				var key := InputEventKey.new()
				key.keycode = KEY_ENTER
				key.pressed = pressed
				Input.parse_input_event(key)
			await process_frame
		check(view.game.powerup_active() and view.game.powerup_snapshot().selected_id == id
			and app.coin_wallet.balance == before - 200 and view.game.cleared_pairs == 0,
			"A focused keyboard/controller target buys its explicit family instead of pronouncing or collecting it")
		view.game.finish_powerup()


func test_layouts(app) -> void:
	await prepare(app)
	var view = app._word_jelly
	var words: Array = view.game._words.duplicate(true)
	var plan: Dictionary = Catalog.make_plan(2, words, app.growth.learning_age(), seed_value)
	check(view.game.bind_stage(plan), "Use a real main plan so all four paid tools are laid out: " + str(plan.get("error", "")) + view.game.error)
	for dimensions: Vector2i in [Vector2i(1366, 768), Vector2i(768, 1024), Vector2i(393, 852), Vector2i(320, 480), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		view.set_process(false)
		view._layout()
		view._refresh_controls()
		var controls: Array = [view._fill_button, view.collect_button]
		controls.append_array(view.powerup_buttons.values())
		for index in range(controls.size()):
			var bounds: Rect2 = controls[index].get_global_rect()
			check(view.get_global_rect().grow(0.1).encloses(bounds)
				and not bounds.intersects(view._global_rect(view._board))
				and bounds.size.x * app.Style.ui_scale(app) >= 43.9
				and bounds.size.y * app.Style.ui_scale(app) >= 43.9,
				"Fill, Collect and every paid target fit without covering Jelly reading space at %s: %s" % [dimensions, bounds])
			for previous in range(index):
				check(not bounds.intersects(controls[previous].get_global_rect()),
					"No paid, free or fill targets overlap at %s" % dimensions)
		check(view._fill_button.get_global_rect().end.y < view.collect_button.get_global_rect().position.y,
			"Fill stays immediately above Auto Collect in every responsive layout")
		if dimensions.x == 393:
			await capture("phone-controls")


func review_rendered_states(app) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	var view = app._word_jelly
	root.size = Vector2i(1011, 663)
	await settle()
	view.set_process(false)
	view.game.set_fill_mode(true)
	for frame in range(480):
		view._process(0.025)
		if view.game.cells.size() == view.WordModel.CAPACITY and view.game._settling_remaining() <= view.WordModel.EPSILON:
			break
	check(view.game.cells.size() == view.WordModel.CAPACITY,
		"The failure review uses a genuinely full busy board, not an easier empty background")
	var main: Dictionary = view.game.stage_run.snapshot()
	view.set_stage_progress(main)
	view._layout()
	await capture("main-rating-and-controls")
	app._round_end.begin(app._round_id + ":review-desktop", true, false)
	app._round_end.advance(1.45)
	await capture("game-over-desktop")
	app._round_end.stop()
	root.size = Vector2i(393, 852)
	await settle()
	view.set_process(false)
	view._layout()
	app._round_end.begin(app._round_id + ":review-phone", true, false)
	app._round_end.advance(1.45)
	await capture("game-over-phone")
	app._round_end.stop()
	var plan: Dictionary = Catalog.make_plan(0, view.game._words, app.growth.learning_age(), seed_value, true)
	check(view.game.bind_stage(plan), "The rendering fixture binds its real Challenge mode")
	var run = view.game.stage_run
	run.challenge_stage = 7
	run._challenge_goals.clear()
	run._append_challenge_stage()
	view.game._sync_challenge_pressure()
	var state: Dictionary = run.snapshot()
	state.challenge_best_stage = 7
	view.set_stage_progress(state)
	app._sync_stage_heading()
	view._layout()
	view._refresh_controls()
	await capture("challenge-stage-7")
	check(view._practice_panel._record_badge.snapshot().text == "Stage 7",
		"The rendered compact medal explicitly includes Stage before its seventh-stage numeral")
	app._reward_confetti.set_paused(false)
	app._reward_confetti.burst("review:upper-launch")
	app._reward_confetti.advance(0.95)
	check(app._reward_confetti.snapshot().visible and app._reward_confetti.is_active(),
		"The native upper-launch capture contains actual visible paper")
	await capture("paper-upper-launch")
	app._reward_confetti.advance(1.8)
	await capture("paper-natural-descent")
	app._reward_confetti.clear()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(480, 800)
	var directory: String = "user://selected-jelly-flow-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = preload("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await settle()
	Fixture.enter_mode(app, "match")
	app.set_process(false)
	app.audio.set_muted(true)
	check(app.coin_wallet.credit_amount("fixture:magnet-funding", 2000).ok, "Fund only isolated native test storage")
	app._coin_flight.sync(app.coin_wallet.balance)
	await test_selection(app)
	await test_keyboard_and_controller(app)
	await test_cancel_and_fill(app)
	await test_layouts(app)
	await review_rendered_states(app)
	app.audio.halt()
	app.queue_free()
	await settle()
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Selected Jelly input and Fill UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
