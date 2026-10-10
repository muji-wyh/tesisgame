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
	app._presentation.path = directory + "/presentation.cfg"
	preload("res://tests/godot/player_flow_fixture.gd").install(app, directory)
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	check(app.MODES.keys() == ["match", "memory", "pop", "phrase", "jelly"],
		"The game offers Match, Memory, Voice Pop, Phrase Builder, and Jelly Match in that order")
	check(app._mode_id == "match" and app.grid.is_visible_in_tree() and not app._memory.is_visible_in_tree(),
		"Entering the game opens the Match board")
	check(app.find_child("Mode_match", true, false).button_pressed and app.find_child("Mode_learn", true, false) == null
		and app.cards.size() == 10 and app.model.hints_remaining == 3 and not app._voice_mode,
		"Match starts selected with a ready board, three hints, and no microphone")
	check(app._mode_buttons.map(func(button: Button) -> String: return str(button.name)) == ["Mode_match", "Mode_memory", "Mode_pop", "Mode_phrase", "Mode_jelly"],
		"The actual mode choices preserve their requested order inside the popover")
	# This fixture exercises an earned chest; chance outcomes have separate coverage.
	app.model.chest_earned = true
	app.model.phase = "won"
	app.model.chest_state = "opened"
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
			check(app._default_focus() == button, "The active result action is the default completed-result focus")
			var minimum_height: float = 48.0 if save_error else 56.0
			var expected_width: float = 176.0 if save_error else 240.0
			check(button.size.y * scale >= minimum_height and button.size.y * scale <= minimum_height + 4,
				"Retry stays compact and New adventure has a prominent touch target at %s" % dimensions)
			check(button.size.x * scale >= expected_width and button.size.x * scale <= expected_width + 4.0,
				"The floating result action preserves its compact width at %s" % dimensions)
			check(app.get_global_rect().encloses(button.get_global_rect()),
				"Result actions stay inside the viewport at %s" % dimensions)
			var minimum_font_size: float = 14.0 if save_error else 20.0
			check(button.get_theme_font_size("font_size") * scale >= minimum_font_size
				and button.get_theme_font_size("font_size") * scale < minimum_font_size + 2,
				"Retry labels stay readable and New adventure uses larger primary-action text")
			var inset: Vector2 = (app._outcome.get_global_rect().end - button.get_global_rect().end) * scale
			check(button.get_parent() == app._outcome and inset.x >= 15.0 and inset.x <= 17.0
				and inset.y >= 15.0 and inset.y <= 17.0,
				"The result action floats at the bottom-right with a safe inset at %s" % dimensions)
			check(app._stage.get_global_rect().is_equal_approx(app._outcome.get_global_rect()),
				"Both normal and retry actions leave the chest stage at full size")
			check(app._treasure_backdrop.show_theme_name == not save_error,
				"Save notices replace the world badge so their text cannot overlap on phones")
			var surface: StyleBoxFlat = button.get_theme_stylebox("normal")
			check(surface.bg_color.a > 0.9 and surface.border_width_top > 0,
				"The active result action has a real button surface rather than floating text")
	app._save_error = false
	app._pending_fragment = {"medal_id": "spring-1", "after": 1}
	app._refresh()
	check(not app._new_adventure_button.visible and not app._result_retry_button.visible
		and app._valid_focus(app._default_focus()), "Pending reward persistence keeps New adventure hidden with a valid fallback focus")
	var pending_lesson: Array = app.model.lesson_words.duplicate(true)
	app._new_adventure_button.pressed.emit()
	check(app.model.phase == "won" and app.model.lesson_words == pending_lesson,
		"A stale action cannot leave while the opened reward is still awaiting persistence")
	app._pending_fragment.clear()
	app._refresh()
	root.size = Vector2i(768, 1024)
	app._show_collection()
	await settle()
	check(app._age_catalog.is_visible_in_tree() and app._growth_summary.is_visible_in_tree(),
		"The growth page presents mastery progress and the word catalog")
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
