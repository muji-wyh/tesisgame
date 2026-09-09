extends SceneTree

const OUTPUT := "res://build/visuals"


func _initialize() -> void:
	_run.call_deferred()


func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image.save_png(OUTPUT + "/" + name + ".png") != OK:
		printerr("Could not save the game viewport: " + name)
		quit(1)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var save_directory := OUTPUT + "/.render-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(save_directory)
	root.size = Vector2i(960, 720)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(save_directory + "/medals.cfg", save_directory + "/legacy.cfg")
	root.add_child(app)
	await process_frame
	await process_frame
	if not app.data.error.is_empty():
		printerr(app.data.error)
		quit(1)
		return
	app.audio.set_muted(true)
	app.set_reduced_motion(false)
	app.new_round(105)
	await _capture("board-desktop")
	root.size = Vector2i(390, 844)
	await _capture("board-phone")
	root.size = Vector2i(960, 720)
	for season in ["spring", "summer", "autumn", "winter"]:
		app.new_round(105)
		for word in app.model.cards:
			if word.kind != "word":
				continue
			for picture in app.model.cards:
				if picture.kind == "image" and word.word.id == picture.word.id:
					app.model.select(word.id)
					app.model.select(picture.id)
					app.model.resolve_feedback()
		app.choose_theme(season)
		await create_timer(0.2).timeout
		await _capture(season + "-closed")
		app.chest_button.button_down.emit()
		app._process(1.21)
		app.chest_button.button_up.emit()
		await create_timer(0.72).timeout
		await _capture(season + "-burst")
		await create_timer(2.0).timeout
		await _capture(season + "-reward")
	print("Rendered the actual Godot board and all four seasonal fragment reveals.")
	app.queue_free()
	await process_frame
	var saves := DirAccess.open(save_directory)
	for filename in saves.get_files():
		DirAccess.remove_absolute(save_directory + "/" + filename)
	DirAccess.remove_absolute(save_directory)
	quit()
