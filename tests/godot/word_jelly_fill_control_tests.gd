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
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
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
	check(view.game.bind_stage(Catalog.make_plan(2, words, app.growth.learning_age(), 1901)), "Bind main stage with default auto-fill")
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
		check(view.game.fill_mode and not view._fill_button.visible and view._fill_button.disabled,
			"Main stage keeps auto-fill on by default with the Fill toggle button removed at %s" % dimensions)
		check(not view.snapshot().fill_control.visible and bool(view.snapshot().fill_control.on),
			"View snapshot reports retired Fill button while auto-fill stays active at %s" % dimensions)
		check(is_equal_approx(view.collect_button.size.x, view.powerup_buttons.auto_merge.size.x),
			"Auto Collect spans the full free-action width without reserving Fill button space at %s" % dimensions)
		check(not view.navigation_controls().has(view._fill_button),
			"Hidden Fill button is excluded from keyboard/controller navigation at %s" % dimensions)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(393, 852)
	await settle()
	view.set_process(false)
	check(view.game.bind_stage(Catalog.make_plan(0, words, app.growth.learning_age(), 1901, true)), "Use actual Challenge Fill")
	view._refresh_controls()
	view._layout()
	check(view.game.fill_mode and not view._fill_button.visible and view._fill_button.disabled,
		"Challenge also keeps auto-fill on with the Fill toggle button removed")
	view.game.step(3.0)
	view._process(0.05)
	view.set_process(false)
	check(view.game.cells.size() == view.WordModel.CAPACITY and view.game.full_elapsed < 0.0 and not view.danger_feedback().active,
		"Auto-fill fills the well promptly and never triggers full-board danger")
	app.audio.halt()
	app.queue_free()
	await settle()
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Icon-only Fill application: %d checks, %d failures%s" % [checks, failures, " (baseline)" if baseline else ""])
	quit(1 if failures else 0)
