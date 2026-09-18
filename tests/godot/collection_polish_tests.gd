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
	check(app.MODES.keys() == ["match", "learn", "memory", "pop"],
		"The original mode tabs precede Voice Pop")
	check(app._mode_id == "match" and app.grid.is_visible_in_tree() and not app._lesson.is_visible_in_tree(),
		"Entering the game opens the Match board")
	check(app.find_child("Mode_match", true, false).button_pressed and not app.find_child("Mode_learn", true, false).button_pressed
		and app.cards.size() == 8 and app.model.hints_remaining == 3 and not app._voice_mode,
		"Match starts selected with a ready board, three hints, and no microphone")
	check(app._mode_buttons.map(func(button: Button) -> String: return button.text) == ["Match", "Learn", "Memory", "Voice Pop"],
		"The actual controls follow the requested tab order")
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
			check(button.size.y * scale >= 48 and button.size.y * scale <= 52,
				"Result actions have compact, usable CSS heights at %s" % dimensions)
			check(button.size.x * scale <= 180,
				"Result actions do not stretch into oversized bars at %s" % dimensions)
			check(app.get_global_rect().encloses(button.get_global_rect()),
				"Result actions stay inside the viewport at %s" % dimensions)
			check(button.get_theme_font_size("font_size") * scale >= 14
				and button.get_theme_font_size("font_size") * scale < 16,
				"Result labels use a consistent readable CSS type size")
			check(is_equal_approx(button.get_global_rect().get_center().x, app._result_footer.get_global_rect().get_center().x),
				"The sole result action stays centered in its footer")
			var surface: StyleBoxFlat = button.get_theme_stylebox("normal")
			check(surface.bg_color.a > 0.9 and surface.border_width_top > 0,
				"The active result action has a real button surface rather than floating text")
	app._save_error = false
	app._refresh()
	root.size = Vector2i(768, 1024)
	app._show_collection()
	app._show_reward_section("medals")
	await settle()
	check(app.duck.is_visible_in_tree() and app._next_goal.is_ancestor_of(app.duck),
		"Pip is present in the next-treasure guide on Medals")
	check(app._medals_duck_slot.get_global_rect().encloses(app.duck.get_global_rect()),
		"Pip fits the guide slot without covering its text or neighboring artwork")
	var shelves: Variant = app.get("_collection_shelves")
	check(shelves is Array and shelves.size() == 8,
		"Each world has its own treasure shelf")
	for slot in app._reward_slots.values():
		check(slot.picture.get("mystery_egg") == true and slot.picture.texture == null
			and slot.picture.pieces == 0 and slot.button.disabled,
			"Empty rewards are mystery eggs without loading or granting their artwork")
		check(slot.label.text == "0/3", "Empty rewards keep their real fragment count without repeated copy")
	var counts: Dictionary = app.medal_progress.counts.duplicate(true)
	app._play_duck()
	check(app.medal_progress.counts == counts and not app._preview_page.visible,
		"Playing with Pip does not grant or open an unearned reward")
	var picture = app._reward_slots["spring-1"].picture
	check(picture.has_method("wiggle"), "Medal artwork has a bounded playful reaction")
	if picture.has_method("wiggle"):
		var button: Button = app._reward_slots["spring-1"].button
		var rect: Rect2 = button.get_global_rect()
		picture.wiggle(false)
		var tween: Tween = picture.get("_wiggle")
		if tween != null:
			tween.pause()
			tween.custom_step(0.045)
		check(not is_zero_approx(picture.rotation), "The artwork visibly reacts during a wiggle")
		check(button.get_global_rect().is_equal_approx(rect), "Wiggling artwork does not move its input target")
		picture.hide()
		check(is_zero_approx(picture.rotation) and picture.scale == Vector2.ONE,
			"Hidden artwork cancels its reaction")
		picture.show()
		app.set_reduced_motion(false)
		picture.wiggle(false)
		tween = picture.get("_wiggle")
		if tween != null:
			tween.pause()
			tween.custom_step(0.045)
		app.set_reduced_motion(true)
		check(is_zero_approx(picture.rotation), "Enabling reduced motion cancels an in-progress medal reaction")
		picture.wiggle(true)
		check(is_zero_approx(picture.rotation) and picture.scale == Vector2.ONE,
			"Reduced motion keeps medal artwork still")
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
