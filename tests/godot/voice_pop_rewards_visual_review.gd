extends SceneTree
## Render fragment markers, chest performances and results using isolated saves.

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
var app
var directory: String
var output: String
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _capture(label: String, dimensions: Vector2i) -> void:
	root.size = dimensions
	for frame in range(5):
		await process_frame
	app._layout()
	app._pop._results.scroll_vertical = 0
	for frame in range(5):
		await process_frame
		await RenderingServer.frame_post_draw
	var stem: String = "%s/%s-%dx%d" % [output, label, dimensions.x, dimensions.y]
	if root.get_texture().get_image().save_png(stem + ".png") != OK:
		failed = true
	var record := FileAccess.open(stem + ".json", FileAccess.WRITE)
	record.store_string(JSON.stringify(app._pop.snapshot(), "  "))
	record.close()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	output = "res://build/pop-reward-review/" + (args[0] if not args.is_empty() else "after")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	directory = "user://pop-result-review-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	Fixture.install(app, directory)
	root.add_child(app)
	app.audio.muted = true
	for frame in range(5):
		await process_frame
	app.choose_mode("pop")
	app.set_reduced_motion(false)
	Fixture.choose_pop_player(app)
	app._pop.set_listening(true, true, "Listening.")
	app._pop.set_process(false)
	for attempt in range(9):
		while app._pop.game.targets.is_empty():
			app._pop._advance_game(0.15)
		app._pop.game.targets[0].chest = true
		app._pop.game.targets[0].age = float(app._pop.game.targets[0].lifetime) * 0.45
		app._pop._refresh_targets()
		if attempt == 2:
			app._pop._advance_hud_feedback(3.0)
			app._pop._advance_slices(3.0)
			app._pop._loot_flights.clear()
			for dimensions in [Vector2i(1366, 768), Vector2i(390, 844), Vector2i(844, 390)]:
				await _capture("marker", dimensions)
		app._pop._listening_tick_usec = -1
		app._pop.receive_transcript(str(app._pop.game.targets[0].word.text))
		if app._pop.reward_presentation_active():
			app._pop.advance_reward_presentation(1.53)
			for dimensions in [Vector2i(1366, 768), Vector2i(390, 844), Vector2i(844, 390)]:
				await _capture("upgrade" if attempt == 8 else "unlock", dimensions)
			app._pop.advance_reward_presentation(2.0)
			app._pop.set_listening(true, true, "Listening.")
	app._pop._advance_game(app._pop.game.remaining + 1.0)
	Fixture.finish_celebration(app)
	app._pop._advance_result_feedback(2.0)
	for dimensions in [Vector2i(1366, 768), Vector2i(390, 844), Vector2i(320, 568), Vector2i(844, 390)]:
		await _capture("final-tier", dimensions)
	app.audio.halt()
	app.queue_free()
	await process_frame
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Voice Pop reward review captured to " + output)
	quit(1 if failed else 0)
