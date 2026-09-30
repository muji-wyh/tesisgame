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


func _clip(seconds: float = 0.25) -> AudioStreamWAV:
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = 22050
	var pcm := PackedByteArray()
	pcm.resize(int(22050 * seconds) * 2)
	pcm.fill(0)
	clip.data = pcm
	return clip


func _run() -> void:
	await _result_lifecycle()
	print("Pop result audio: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _result_lifecycle() -> void:
	var directory: String = "user://pop-result-audio-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
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
	check(view.game.phase == "finished" and view.game.hits == 1 and view._results.visible,
		"The completed round reaches its result with the actual hit count")
	check(not app._pop_speech_active and not view._listening,
		"Completing the round stops microphone input before review playback")
	check(not app.audio.voice.playing,
		"Showing the simplified result never starts automatic report narration")
	check(not app._status_announcement.begins_with("Pip says:"),
		"Result completion does not announce the removed spoken report")
	var summary: Dictionary = view.game.summary()
	var review_words: Array = []
	review_words.append_array(summary.hit_words)
	review_words.append_array(summary.missed_words)
	check(view._review_buttons.size() == review_words.size() and review_words.size() >= 2,
		"Both popped and missed words remain available for individual pronunciation")
	for index in range(review_words.size()):
		var word: Dictionary = review_words[index]
		app.audio.cache["res://" + str(word.audio)] = _clip(4.0)
		app.audio.stop_voice()
		view._review_buttons[index].pressed.emit()
		check(app.audio.voice.playing and app.audio.voice.stream == app.audio.cache["res://" + str(word.audio)]
			and not app.audio.music.playing,
			"Tapping the result word " + str(word.text) + " plays only its pronunciation")
		check(view.game.summary() == summary, "Review pronunciation cannot change the completed round's scores or words")
	var first_review: Button = view._review_buttons[0]
	for action in ["more", "hidden", "mute", "stop_voice"]:
		first_review.pressed.emit()
		check(app.audio.voice.playing, action + " starts with a real review word playing")
		match action:
			"more": app._show_collection()
			"hidden": app.on_page_hidden()
			"mute": app.audio.set_muted(true)
			"stop_voice": app.audio.stop_voice()
		check(not app.audio.voice.playing,
			action + " stops review audio immediately without reviving report narration")
		if action == "more":
			first_review.pressed.emit()
			check(not app.audio.voice.playing, "A covered result word cannot pronounce behind the menu")
		match action:
			"more": app._hide_collection()
			"hidden": app.on_page_visible()
			"mute": app.audio.set_muted(false)
		check(not app.audio.voice.playing,
			action + " never resumes speech without a fresh word tap")
	first_review.pressed.emit()
	check(app.audio.voice.playing, "Review words work again after menu, background, and mute transitions")
	view.replay_button.pressed.emit()
	preload("res://tests/godot/player_flow_fixture.gd").choose_pop_player(app)
	view.set_process(false)
	check(view.game.phase == "ready" and view.game.hits == 0 and not view._results.visible
		and not app.audio.voice.playing,
		"Play again clears the result and its pronunciation while waiting for fresh microphone readiness")
	first_review.pressed.emit()
	check(not app.audio.voice.playing, "A stale result word cannot play over the next round's listening gate")
	app._on_voice_state([true, true, "Listening."])
	view._advance_game(view.game.remaining)
	check(view.game.phase == "finished" and not app.audio.voice.playing,
		"The next completed round also remains free of automatic narration")
	for destination in ["match", "memory"]:
		var review: Dictionary = view.game.summary().missed_words[0]
		app._pop_hear(review)
		check(app.audio.voice.playing, destination + " transition starts with an active result pronunciation")
		app.choose_mode(destination)
		check(app._mode_id == destination and not app.audio.voice.playing,
			"Leaving the result for " + destination + " stops the previous word without stale report callbacks")
		app._pop_hear(review)
		check(not app.audio.voice.playing, "A late Voice Pop word callback is ignored in " + destination)
		app.choose_mode("pop")
		preload("res://tests/godot/player_flow_fixture.gd").choose_pop_player(app)
		view.set_process(false)
		app._on_voice_state([true, true, "Listening."])
		view._advance_game(view.game.remaining)
		check(view.game.phase == "finished" and not app.audio.voice.playing,
			"Returning from " + destination + " can complete another round without automatic speech")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
