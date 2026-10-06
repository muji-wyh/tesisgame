extends SceneTree

var checks := 0
var failures := 0


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


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 720)
	var directory := "user://collection-polish-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	check(app.MODES.keys() == ["match", "memory", "pop"],
		"The game offers Match, Memory, and Voice Pop in that order")
	check(app._mode_id == "match" and app.grid.is_visible_in_tree() and not app._memory.is_visible_in_tree(),
		"Entering the game opens the Match board")
	check(app.find_child("Mode_match", true, false).button_pressed and app.find_child("Mode_learn", true, false) == null
		and app.cards.size() == 10 and app.model.hints_remaining == 3 and not app._voice_mode,
		"Match starts selected with a ready board, three hints, and no microphone")
	check(app._mode_buttons.map(func(button: Button) -> String: return str(button.name)) == ["Mode_match", "Mode_memory", "Mode_pop"],
		"The actual mode choices preserve their requested order inside the popover")
	app.model.phase = "lost"
	app._refresh()
	for dimensions in [Vector2i(320, 568), Vector2i(768, 1024), Vector2i(1366, 768)]:
		root.size = dimensions
		for save_error in [false, true]:
			app._save_error = save_error
			app._refresh()
			await settle()
			var scale: float = app.Style.ui_scale(app)
			var button: Button = app._result_retry_button if save_error else app._new_adventure_button
			var inactive: Button = app._new_adventure_button if save_error else app._result_retry_button
			check(button.is_visible_in_tree() and not inactive.is_visible_in_tree(),
				"Results show one normal New adventure action or one conditional save retry")
			check(app._default_focus() == button, "The active result action is the default loss-screen focus")
			var minimum_height: float = 48.0 if save_error else 64.0
			var maximum_width: float = 180.0 if save_error else minf(324.0, app._result_text.size.x * scale + 4.0)
			check(button.size.y * scale >= minimum_height and button.size.y * scale <= minimum_height + 4,
				"Retry stays compact and New adventure has a prominent touch target at %s" % dimensions)
			check(button.size.x * scale <= maximum_width and (save_error or button.size.x * scale >= minf(320.0, app._result_text.size.x * scale) - 4.0),
				"Result action width reflects its intended emphasis within the available column at %s" % dimensions)
			check(app.get_global_rect().encloses(button.get_global_rect()),
				"Result actions stay inside the viewport at %s" % dimensions)
			var minimum_font_size: float = 14.0 if save_error else 24.0
			check(button.get_theme_font_size("font_size") * scale >= minimum_font_size
				and button.get_theme_font_size("font_size") * scale < minimum_font_size + 2,
				"Retry labels stay readable and New adventure uses larger primary-action text")
			check(absf(button.get_global_rect().get_center().x - app._result_footer.get_global_rect().get_center().x) <= 0.5,
				"The sole result action stays centered in its footer at %s: %s in %s" % [dimensions, button.get_global_rect(), app._result_footer.get_global_rect()])
			var surface: StyleBoxFlat = button.get_theme_stylebox("normal")
			check(surface.bg_color.a > 0.9 and surface.border_width_top > 0,
				"The active result action has a real button surface rather than floating text")
	app._save_error = false
	app._refresh()
	root.size = Vector2i(768, 1024)
	app._show_collection()
	await settle()
	check(app.duck.is_visible_in_tree() and app._room.is_ancestor_of(app.duck),
		"Pip remains present in the room")
	var counts: Dictionary = app.medal_progress.counts.duplicate(true)
	app._play_duck()
	check(app.medal_progress.counts == counts, "Playing with Pip does not grant a reward")
	var decoration = load("res://scripts/medal_view.gd").new()
	root.add_child(decoration)
	decoration.scale = Vector2.ONE * 0.6
	decoration.rotation = 0.2
	decoration.size = Vector2.ONE * 48
	check(decoration.scale == Vector2.ONE * 0.6 and is_equal_approx(decoration.rotation, 0.2),
		"Medals outside the shelf keep transforms owned by their reward animations")
	decoration.queue_free()
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Collection polish: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
