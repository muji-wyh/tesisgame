extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	await _result_lifecycle()
	print("Pop result audio: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _result_lifecycle() -> void:
	var directory: String = "user://pop-result-audio-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	preload("res://tests/godot/player_flow_fixture.gd").install(app, directory)
	root.size = Vector2i(390, 844)
	root.add_child(app)
	await process_frame
	await process_frame
	app.choose_mode("pop")
	app._configure_pop(37)
	preload("res://tests/godot/player_flow_fixture.gd").choose_pop_player(app)
	var view = app._pop
	view.set_process(false)
	app._on_voice_state([true, true, "Listening."])
	view._advance_game(3.0)
	check(not view.game.targets.is_empty(), "A listening round launches words before the result integration check")
	if not view.game.targets.is_empty():
		view.receive_transcript(str(view.game.targets[0].word.text))
	view._advance_game(view.game.remaining)
	await process_frame
	check(view.game.phase == "finished" and view.game.hits == 1 and view.snapshot().board_frozen,
		"The completed round retains its actual hit count on a frozen board")
	check(app._settlement_dialog.is_visible_in_tree() and app._pop_rewards.is_visible_in_tree(),
		"Voice Pop opens the shared settlement dialog directly")
	check(not app._pop_speech_active and not view._listening,
		"Completing the round stops microphone input before settlement")
	check(not app.audio.voice.playing,
		"Showing settlement never starts automatic report narration")
	check(view.find_child("PopResults", true, false) == null and view.controls().is_empty(),
		"The removed standalone review page cannot expose late word-playback actions")
	var summary: Dictionary = view.game.summary()
	for action in ["more", "hidden", "mute", "stop_voice"]:
		match action:
			"more": app._show_collection()
			"hidden": app.on_page_hidden()
			"mute": app.audio.set_muted(true)
			"stop_voice": app.audio.stop_voice()
		check(not app.audio.voice.playing,
			action + " leaves the completed round silent")
		match action:
			"more": app._hide_collection()
			"hidden": app.on_page_visible()
			"mute": app.audio.set_muted(false)
		view.receive_transcript("a stale completed word")
		check(not app.audio.voice.playing and not view._listening and view.game.summary() == summary,
			action + " never resumes speech or alters the completed result")
	app._pop_rewards._back.pressed.emit()
	preload("res://tests/godot/player_flow_fixture.gd").choose_pop_player(app)
	view.set_process(false)
	check(view.game.phase == "ready" and view.game.hits == 0 and not view.snapshot().board_frozen
		and not app.audio.voice.playing,
		"Play again clears the frozen board while waiting for fresh microphone readiness")
	app._on_voice_state([true, true, "Listening."])
	view._advance_game(view.game.remaining)
	check(view.game.phase == "finished" and not app.audio.voice.playing,
		"The next completed round also remains free of automatic narration")
	for destination in ["match", "memory"]:
		preload("res://tests/godot/player_flow_fixture.gd").enter_mode(app, destination)
		check(app._mode_id == destination and not app._mode_menu_open() and not app.audio.voice.playing,
			"Leaving settlement for " + destination + " stops all previous speech")
		preload("res://tests/godot/player_flow_fixture.gd").enter_mode(app, "pop")
		check(app._mode_id == "pop" and not app._mode_menu_open(), "Returning from " + destination + " reaches Voice Pop through Home")
		preload("res://tests/godot/player_flow_fixture.gd").choose_pop_player(app)
		view.set_process(false)
		app._on_voice_state([true, true, "Listening."])
		view._advance_game(view.game.remaining)
		check(view.game.phase == "finished" and not app.audio.voice.playing,
			"Returning from " + destination + " can complete another round without automatic speech")
	app.audio.halt()
	await process_frame
	app.queue_free()
	await process_frame
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
