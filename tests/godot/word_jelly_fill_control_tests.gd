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


func click(view) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = view._fill_button.get_global_rect().get_center()
		event.global_position = event.position
		root.push_input(event)
		view.set_process(false)
		await process_frame
	view.set_process(false)


func capture(view, name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	if not baseline and view._fill_button.has_method("advance"):
		view._fill_button.advance(0.2)
	await settle()
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image.save_png(output + "/" + name + ".png") == OK, "Save actual " + name)
	var area: Rect2 = view._fill_button.get_global_rect().grow(4.0)
	var ratio: Vector2 = Vector2(image.get_size()) / root.get_visible_rect().size
	var crop := Rect2i((area.position * ratio).floor(), (area.size * ratio).ceil())
	crop = crop.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	check(image.get_region(crop).save_png(output + "/" + name + "-button.png") == OK, "Save the actual Fill control")


func capture_flow(view) -> void:
	if baseline or not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(output + "/flow")
	for frame in range(64):
		view._fill_button.advance(0.05)
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var ratio: Vector2 = Vector2(image.get_size()) / root.get_visible_rect().size
		var area: Rect2 = view._fill_button.get_global_rect().grow(4.0)
		var crop := Rect2i((area.position * ratio).floor(), (area.size * ratio).ceil())
		check(image.get_region(crop).save_png(output + "/flow/frame-%04d.png" % frame) == OK,
			"Render the actual persistent local mode effect")


func _run() -> void:
	baseline = OS.get_cmdline_user_args().has("--baseline")
	output = "res://build/qa/jelly-fill-icon-" + ("before" if baseline else "after")
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(393, 852)
	var directory := "user://fill-icon-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
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
	check(app.new_round(1901, false, "", "word_jelly"), "Open real Jelly Words")
	await settle()
	var view = app._word_jelly
	view.set_process(false)
	var words: Array = app._learning_words().filter(func(word: Dictionary) -> bool:
		return not str(word.get("image", "")).is_empty()).slice(0, 3).map(
			func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	check(view.configure(words, app.growth.learning_age(), Data.theme(app.model.theme_id),
		app.data.chests, false, 1901), "Use production artwork")
	check(view.game.bind_stage(Catalog.make_plan(2, words, app.growth.learning_age(), 1901)), "Bind ordinary optional Fill")
	view.game._stage_spawn_interval = 10000.0
	view.game.spawn_interval = 10000.0
	Fixture.unlock_auto_collect(app)
	app._sync_jelly()
	view.set_process(false)
	for frame in range(100):
		if not view._stage_banner.ready_pending():
			break
		view._process(0.05)
	for dimensions: Vector2i in [Vector2i(393, 852), Vector2i(320, 480), Vector2i(1366, 768), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		view.set_process(false)
		view._layout()
		view._refresh_controls()
		await capture(view, "%dx%d-off" % [dimensions.x, dimensions.y])
		var interactive: bool = not view._fill_button.disabled
		if interactive:
			await click(view)
			check(view.game.fill_mode and view._fill_button.button_pressed, "Actual input switches Fill on")
		else:
			check(view._layout_too_small, "Only the established size pause owns this unavailable switch")
			view.game.set_fill_mode(true)
			view._refresh_controls()
		if not baseline:
			check(view._fill_button.text.is_empty() and view._fill_button.get_children().is_empty(),
				"No Fill, On, Off or other visible text is substituted for artwork")
			if view._fill_button.has_method("snapshot"):
				var before: float = float(view._fill_button.snapshot().elapsed)
				view._fill_button.advance(0.4)
				check(view._paused or float(view._fill_button.snapshot().elapsed) > before, "Enabled unpaused local feedback keeps running")
		await capture(view, "%dx%d-on" % [dimensions.x, dimensions.y])
		if dimensions.x == 393:
			await capture_flow(view)
		if interactive:
			await click(view)
			check(not view.game.fill_mode, "Actual input switches Fill back off")
		else:
			view.game.set_fill_mode(false)
			view._refresh_controls()
	if not baseline:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_size = Vector2i(480, 480)
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		root.size = Vector2i(1473, 1175)
		await settle()
		view.set_process(false)
		view.game.set_fill_mode(true)
		view._layout()
		view._refresh_controls()
		await capture(view, "1473x1175-scaled-on")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(393, 852)
	await settle()
	view.set_process(false)
	check(view.game.bind_stage(Catalog.make_plan(0, words, app.growth.learning_age(), 1901, true)), "Use actual forced Challenge Fill")
	view._refresh_controls()
	view._layout()
	await click(view)
	check(view.game.fill_mode and view._fill_button.disabled, "Locked Challenge input cannot switch Fill off")
	if not baseline and view._fill_button.has_method("snapshot"):
		view._fill_button.advance(0.4)
		check(view._fill_button.snapshot().locked and view._fill_button.snapshot().flowing,
			"Locked does not make an enabled mode look inactive")
		view.game.step(4.0)
		var elapsed: float = view._fill_button.snapshot().elapsed
		view._process(0.05)
		view.set_process(false)
		check(view.game.cells.size() == view.WordModel.CAPACITY
			and view._fill_button.snapshot().elapsed > elapsed,
			"The real owner keeps the mode cue running even after the well is full")
	await capture(view, "393x852-challenge")
	if not baseline and view._fill_button.has_method("snapshot"):
		view.pause(true)
		var before: Dictionary = view._fill_button.snapshot()
		view._fill_button.advance(2.0)
		check(view._fill_button.snapshot().elapsed == before.elapsed, "Actual pause freezes the feedback clock")
		await capture(view, "393x852-paused")
		view.pause(false)
		view.set_process(false)
		view.set_reduced_motion(true)
		check(not view._fill_button.snapshot().flowing and view._fill_button.snapshot().on,
			"Reduced motion preserves the active style without moving effects")
		await capture(view, "393x852-reduced")
	app.audio.halt()
	app.queue_free()
	await settle()
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Icon-only Fill application: %d checks, %d failures%s" % [checks, failures, " (baseline)" if baseline else ""])
	quit(1 if failures else 0)
