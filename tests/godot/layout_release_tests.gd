extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")

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
	var directory := "user://layout-release-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	app._presentation.muted = true
	app._presentation.reduced_motion = true
	app._presentation.has_motion_override = true
	check(app._presentation.save_preferences(), "Layout release uses isolated presentation preferences")
	root.size = Vector2i(679, 900)
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	app._show_mode_menu()
	await settle()
	var mode_button: Button = app._mode_buttons[1]
	mode_button.grab_focus()
	var original_cards: Array = app.model.cards.duplicate(true)
	for dimensions in [Vector2i(680, 900), Vector2i(679, 900), Vector2i(1366, 900), Vector2i(320, 568)]:
		root.size = dimensions
		await settle()
		check(root.gui_get_focus_owner() == mode_button, "Focused mode survives popover reflow at " + str(dimensions))
		check(app.model.cards == original_cards, "Resize preserves the round at " + str(dimensions))
		mode_button.grab_focus()
	app._hide_mode_menu()
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
		for phase in ["won"]:
			# Use a persisted chest reservation; chance outcomes have separate coverage.
			Fixture.earn_pair_chest(app)
			app.model.phase = phase
			app.model.chest_state = "opened"
			app._refresh()
			await settle()
			check(viewport.encloses(app._result_retry_button.get_global_rect()), "Result saving retry stays visible at %s: %s" % [dimensions, phase])
		app._save_error = false
		app.model.phase = "waiting"
		app._refresh()
		app._show_collection()
		await settle()
		if app._world_choices.is_visible_in_tree():
			app.theme_buttons[0].grab_focus()
			app._move_focus(Vector2.RIGHT)
			check(root.gui_get_focus_owner() == app.theme_buttons[1],
				"Controller Right traverses the visible world strip at " + str(dimensions))
		else:
			check(app._compact_world.is_visible_in_tree() and app._valid_focus(app._compact_world),
				"Short layouts expose the compact world control instead of the hidden strip")
			var next_theme: String = app.Model.THEMES[posmod(app.Model.THEMES.find(app.model.theme_id) + 1, app.Model.THEMES.size())]
			var cards_before: Array = app.model.cards.duplicate(true)
			app._compact_world.grab_focus()
			app._controller_accept()
			check(app.model.theme_id == next_theme and app.model.cards == cards_before,
				"Controller activation cycles the compact world control without replacing the round")
		var scale: float = app.Style.ui_scale(app)
		var back_height: float = app._collection_back.size.y * scale
		check(back_height >= 44 and back_height <= 46, "More keeps its compact Back target at " + str(dimensions))
		for control in [app._collection_title, app._collection_back]:
			check(viewport.encloses(control.get_global_rect()), "The room header remains on screen at %s: %s" % [dimensions, control.name])
		app._layout_collection()
		await settle()
		check(absf(app._collection_back.size.y * scale - back_height) <= 1,
			"Relayout does not change the room's Back target height")
		app._hide_collection()
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Layout release: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
