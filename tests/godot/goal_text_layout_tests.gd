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


func check_text(app, id: String, state: String) -> void:
	var card: Button = app._room.item_buttons[id]
	var label: Label = app._room.goal_label if app._room.goal_label.visible and app._room.goal_label.get_parent() == card else app._room._item_labels[id]
	var scale: float = app.Style.ui_scale(app)
	var inner: Rect2 = card.get_global_rect().grow(-4 / scale)
	check(inner.encloses(label.get_global_rect()),
		"%s %s at scale %.3f: text=%s card=%s minimum=%s font=%d line-gap=%d" % [
			id, state, scale, label.get_global_rect(), card.get_global_rect(), label.get_minimum_size(),
			label.get_theme_font_size("font_size"), label.get_theme_constant("line_spacing")])
	check(label.get_line_count() == 3 and label.get_theme_font_size("font_size") * scale >= 12,
		"The complete three-line state stays readable instead of being clipped or shrunk away")
	check(absf(card.size.y * scale - 128) <= 1, "Fitting text does not change the fixed card height")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(480, 480)
	root.size = Vector2i(1024, 768)
	var directory := "user://goal-text-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	for theme in app.model.THEMES:
		app.medal_progress.counts[theme + "-1"] = 1
	app._show_collection()
	for dimensions in [Vector2i(320, 568), Vector2i(640, 480), Vector2i(1024, 768), Vector2i(1366, 768), Vector2i(1536, 1152)]:
		root.size = dimensions
		await settle()
		for theme in app.model.THEMES:
			var id: String = "toy-" + theme
			app._room.item_buttons[id].pressed.emit()
			await settle()
			check_text(app, id, "preview")
			app._room.show_item_error(id, "Not saved\nTap arrow to retry", "The toy goal could not be saved. Try again.")
			await settle()
			check_text(app, id, "save error")
			app._room._activate_action()
			app._room.show_item_error(id, "Not saved\nTap again to retry", "The toy selection could not be saved. Try again.")
			await settle()
			check_text(app, id, "selection save error")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Goal text layout: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
