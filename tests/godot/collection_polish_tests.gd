extends SceneTree

const PlayerFlow = preload("res://tests/godot/player_flow_fixture.gd")

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
	PlayerFlow.install(app, directory)
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	check(app.MODES.keys() == ["match", "memory", "pop", "phrase", "jelly", "word_jelly"],
		"The game retains all six supported mode identifiers")
	check(app._mode_buttons.map(func(button: Button) -> String: return str(button.name)) == ["Mode_word_jelly", "Mode_match", "Mode_memory", "Mode_pop", "Mode_phrase", "Mode_jelly"],
		"Home presents all six games with Jelly Words first")
	PlayerFlow.enter_mode(app, "match")
	await settle()
	check(app._mode_id == "match" and not app._mode_menu_open()
		and app.grid.is_visible_in_tree() and not app._memory.is_visible_in_tree(),
		"Choosing Match from Home opens its playable board")
	check(app.find_child("Mode_match", true, false).button_pressed and app.find_child("Mode_learn", true, false) == null
		and app.cards.size() == 10 and app.model.hints_used == 0 and not app._voice_mode,
		"Match starts selected with a ready board, no hint purchases, and no microphone")
	# Use a persisted chest reservation; chance outcomes have separate coverage.
	PlayerFlow.earn_pair_chest(app)
	app.model.phase = "won"
	check(app._settle_pair_reward(), "The result fixture has a durably settled chest before checking its actions")
	app._refresh()
	for dimensions in [Vector2i(320, 568), Vector2i(768, 1024), Vector2i(1366, 768)]:
		root.size = dimensions
		for save_error in [false, true]:
			app._save_error = save_error
			app._refresh()
			await settle()
			var scale: float = app.Style.ui_scale(app)
			var button: Button = app._single_result.retry_button if save_error else app._single_result.replay_button
			check(button.is_visible_in_tree() and not button.disabled
				and app._single_result.replay_button.disabled == save_error
				and app._single_result.retry_button.is_visible_in_tree() == save_error,
				"Settlement enables Play again after saving and exposes Retry saving only on failure")
			check(app._default_focus() == button, "The active result action is the default completed-result focus")
			check(button.size.y * scale >= 44.0 and button.size.x * scale >= 44.0,
				"Settlement actions retain comfortable touch targets at %s" % dimensions)
			check(app.get_global_rect().encloses(button.get_global_rect()),
				"Result actions stay inside the viewport at %s" % dimensions)
			check(button.get_theme_font_size("font_size") * scale >= 14.0,
				"Settlement labels stay readable at %s" % dimensions)
			var panel: Rect2 = app._settlement_dialog.panel.get_global_rect()
			check(app._settlement_dialog.is_ancestor_of(button) and panel.encloses(button.get_global_rect())
				and app.grid.is_visible_in_tree(),
				"Saving and retry both remain in a dialog over the completed board at %s" % dimensions)
			check(app._single_result.caption.is_visible_in_tree(),
				"The settlement explains its opened or failed-save state inside the dialog")
			var surface: StyleBoxFlat = button.get_theme_stylebox("normal")
			check(surface.bg_color.a > 0.9 and surface.border_width_top > 0,
				"The active result action has a real button surface rather than floating text")
	app._save_error = false
	app._pending_fragment = {"medal_id": "spring-1", "after": app.medal_progress.count_for("spring-1") + 1}
	app._refresh()
	check(app._single_result.replay_button.disabled and not app._single_result.retry_button.visible
		and app._valid_focus(app._default_focus()), "Pending reward persistence keeps Play again disabled with a valid fallback focus")
	var pending_lesson: Array = app.model.lesson_words.duplicate(true)
	app._single_result.replay_button.pressed.emit()
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
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Collection polish: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
