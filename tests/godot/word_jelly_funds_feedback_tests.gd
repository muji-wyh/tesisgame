extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Data = preload("res://scripts/game_data.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")
const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
var checks := 0
var failures := 0
var baseline := false
var output := ""


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(4):
		await process_frame


func click(view, control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		root.push_input(event)
		view.set_process(false)
		await process_frame
	view.set_process(false)


func capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	await settle()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output + "/" + name + ".png") == OK,
		"Capture the actual low-balance interaction")


func reject(view, kind: String) -> void:
	var button = view.powerup_buttons[kind]
	button.reset()
	check(not button.disabled, "A legally usable but unaffordable item remains clickable")
	await click(view, button)
	if kind == "family_merge":
		if not baseline:
			check(button.snapshot().get("funds_warning", false) and view._family_selecting,
				"Magnet explains the shortfall immediately without silently choosing or charging a family")
		await click(view, view._tiles[int(view.game.cells[0].id)])
	view._process(0.12)
	view.set_process(false)
	if not baseline:
		check(button.snapshot().get("funds_warning", false) and button.snapshot().title == "Need coins",
			"An actual insufficient-funds receipt has an explicit local money explanation")
		check(button.snapshot().get("missing_coins", 0) == view.game.powerup_price(kind),
			"The warning retains the actual shortfall without changing the quoted price")


func _run() -> void:
	baseline = OS.get_cmdline_user_args().has("--baseline")
	output = "res://build/qa/jelly-item-funds-" + ("before" if baseline else "after")
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(393, 852)
	var directory := "user://item-funds-review-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
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
	app.set_reduced_motion(false)
	check(app.new_round(1901, false, "", "word_jelly"), "Use a real isolated zero-coin player")
	await settle()
	var view = app._word_jelly
	view.set_process(false)
	var words: Array = app._learning_words().filter(func(word: Dictionary) -> bool:
		return not str(word.get("image", "")).is_empty()).slice(0, 3).map(
			func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	check(view.configure(words, app.growth.learning_age(), Data.theme(app.model.theme_id),
		app.data.chests, false, 1901), "Use production items and vocabulary")
	check(view.game.bind_stage(Catalog.make_plan(2, words, app.growth.learning_age(), 1901)),
		"All four ordinary paid items have genuine current prices")
	view.game.cells.clear()
	view.game._stage_spawn_interval = 10000.0
	view.game.spawn_interval = 10000.0
	for index in range(4):
		var tile: Dictionary = view.game._new_word_root(words[index / 2]) if index % 2 == 0 else view.game._new_picture_tile(words[index / 2])
		var at: Vector2i = view.game._free_position(view.game._occupied(), 1, 1)
		tile.merge({"column": at.x, "row": at.y, "age": 100.0, "arrival": false, "settling": false}, true)
		view.game.cells.append(tile)
	view._sync_tiles()
	app._sync_jelly()
	view.set_process(false)
	for frame in range(100):
		if not view._stage_banner.ready_pending():
			break
		view._process(0.05)
	view._layout()
	await settle()
	var wallet: Variant = app.coin_wallet._saved_text
	var receipts: int = app.coin_wallet._receipts.size()
	for kind: String in ["auto_merge", "family_merge", "fragments", "extra_time"]:
		for button in view.powerup_buttons.values():
			button.reset()
		await reject(view, kind)
		check(app.coin_wallet.balance == 0 and app.coin_wallet._saved_text == wallet
			and app.coin_wallet._receipts.size() == receipts and not view.game.powerup_active()
			and int(view.game.snapshot().powerup_uses.get(kind, 0)) == 0,
			"Rejected feedback neither spends, stores a purchase nor runs the item")
		if kind == "extra_time" and not baseline:
			check(view.game.error.is_empty(), "An ordinary shortfall does not leave a sticky error over the stage")
		await capture("393x852-" + kind)
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1366, 768)
		await settle()
		view.set_process(false)
		view._layout()
		await reject(view, "auto_merge")
		await capture("1366x768-auto_merge")
		view.set_reduced_motion(true)
		await reject(view, "fragments")
		await capture("1366x768-reduced")
	if not baseline:
		check(app.coin_wallet.credit_amount("fixture:partial-item-cost", 150).ok, "Use a real partially funded wallet")
		app._coin_flight.sync(app.coin_wallet.balance)
		view._refresh_controls()
		var button = view.powerup_buttons.fragments
		button.reset()
		await click(view, button)
		check(button.snapshot().funds_warning and button.snapshot().missing_coins == 50
			and button.snapshot().price_text == "200" and app.coin_wallet.balance == 150,
			"A partially funded purchase explains only the real shortfall and never changes its price or balance")
	app.audio.halt()
	app.queue_free()
	await settle()
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Insufficient coin feedback: %d checks, %d failures%s" % [checks, failures, " (baseline)" if baseline else ""])
	quit(1 if failures else 0)
