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
	for frame in range(8):
		await process_frame

func _run() -> void:
	var directory := "user://layout-release-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.size = Vector2i(679, 900)
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	var mode_button: Button = app._mode_buttons[1]
	mode_button.grab_focus()
	var original_cards: Array = app.model.cards.duplicate(true)
	for dimensions in [Vector2i(680, 900), Vector2i(679, 900), Vector2i(1366, 900), Vector2i(320, 568)]:
		root.size = dimensions
		await settle()
		check(root.gui_get_focus_owner() == mode_button, "Focused mode survives header reflow at " + str(dimensions))
		check(app.model.cards == original_cards, "Resize preserves the round at " + str(dimensions))
		mode_button.grab_focus()
	for dimensions in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1366, 900)]:
		root.size = dimensions
		await settle()
		app._save_error = true
		app._refresh()
		await settle()
		var viewport: Rect2 = Rect2(Vector2.ZERO, app.size).grow(1)
		for control in [app._storage_retry_button, app.collection_button, app.hint_button, app._voice_button]:
			if control.is_visible_in_tree():
				check(viewport.encloses(control.get_global_rect()), "Storage failure keeps header control on screen at %s: %s" % [dimensions, control.name])
		for phase in ["won", "lost"]:
			app.model.phase = phase
			app._refresh()
			await settle()
			check(viewport.encloses(app._result_retry_button.get_global_rect()), "Result saving retry stays visible at %s: %s" % [dimensions, phase])
		app._save_error = false
		app.model.phase = "waiting"
		app._refresh()
		app._show_collection()
		app._show_reward_section("medals")
		await settle()
		if app._world_grid.columns == 3:
			app.theme_buttons[0].grab_focus()
			app._move_focus(Vector2.DOWN)
			check(root.gui_get_focus_owner() == app.theme_buttons[3], "Controller Down reaches the second row of worlds on a narrow screen")
		app.medal_progress.counts["space-2"] = 3
		app._refresh_collection()
		await settle()
		app._open_reward_preview("space-2")
		await settle()
		var scale: float = app.Style.ui_scale(app)
		var preview_height: float = app._preview_wear_button.size.y * scale
		check(preview_height >= 44 and preview_height <= 46, "Opening a reward keeps the shared compact action height at %s: %s CSS px" % [dimensions, preview_height])
		check(viewport.encloses(app._preview_wear_button.get_global_rect()), "Preview display action stays on screen at " + str(dimensions))
		for control in [app._preview_title, app._preview_close]:
			check(viewport.encloses(control.get_global_rect()), "Long reward title keeps preview header on screen at %s: %s" % [dimensions, control.name])
		app._layout_collection()
		await settle()
		check(absf(app._preview_wear_button.size.y * scale - preview_height) <= 1, "Relayout does not change the preview action height")
		app._hide_reward_preview()
		app._hide_collection()
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Layout release: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
