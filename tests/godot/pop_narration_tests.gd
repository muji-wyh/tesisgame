extends SceneTree

class DeferredAudio extends "res://scripts/game_audio.gd":
	signal released
	var waiting: Dictionary = {}
	var resolved: Dictionary = {}
	var requested: Array[String] = []

	func _stream(path: String, loop: bool = false) -> AudioStream:
		if not waiting.has(path):
			return await super._stream(path, loop)
		requested.append(path)
		while not resolved.has(path):
			await released
		return resolved[path]

	func resolve(path: String, stream: AudioStream) -> void:
		resolved[path] = stream
		released.emit()


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


func _until(predicate: Callable, seconds: float = 2.0) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return bool(predicate.call())


func _run() -> void:
	await _queue_lifecycle()
	await _result_lifecycle()
	print("Pop result audio: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _queue_lifecycle() -> void:
	var audio := DeferredAudio.new()
	root.add_child(audio)
	audio.interact("spring", false)
	var first: AudioStream = _clip()
	var second: AudioStream = _clip()
	audio.cache["first"] = first
	audio.cache["second"] = second
	var states: Array[String] = []
	audio.narration_state_changed.connect(func(state: String) -> void: states.append(state))
	audio.narrate(["first", "second"])
	check(audio.narration.playing and audio.narration.stream == first and audio.narration_state == "speaking",
		"An available page starts its first real AudioStreamPlayer clip")
	check(is_equal_approx(db_to_linear(audio.narration.volume_db), 0.64), "Recorded narration uses the existing word-voice gain")
	check(await _until(func() -> bool: return audio.narration.playing and audio.narration.stream == second),
		"The first clip's real finished signal starts the second clip in order")
	check(await _until(func() -> bool: return audio.narration_state == "idle"),
		"The last clip's real finished signal returns the queue to idle")
	check(not audio.narration.playing and states == ["loading", "speaking", "idle"],
		"A complete page has one truthful loading/speaking/idle lifecycle")

	audio.waiting = {"intro": true, "closing": true}
	audio.narrate(["intro", "closing"])
	check(audio.narration_state == "loading" and not audio.narration.playing, "A pending first preparation keeps Pip silent")
	audio.resolve("intro", first)
	check(audio.requested.has("closing") and not audio.narration.playing and audio.narration_state == "loading",
		"The ready introduction waits for the entire page, including its closing clip")
	audio.resolve("closing", second)
	check(audio.narration.playing and audio.narration.stream == first, "Playback begins only after every page clip is ready")
	audio.stop_narration()
	check(not audio.narration.playing and audio.narration_state == "idle", "Explicit cancellation immediately stops playback")

	audio.waiting["cancelled"] = true
	audio.narrate(["cancelled"])
	audio.stop_narration()
	audio.resolve("cancelled", first)
	check(not audio.narration.playing and audio.narration_state == "idle",
		"An old preparation cannot revive a cancelled request")
	audio.waiting["old-page"] = true
	audio.waiting["new-page"] = true
	audio.narrate(["old-page"])
	audio.narrate(["new-page"])
	audio.resolve("old-page", first)
	check(not audio.narration.playing and audio.narration_state == "loading", "A stale page cannot interrupt the latest page's loading state")
	audio.resolve("new-page", second)
	check(audio.narration.playing and audio.narration.stream == second, "Only the latest page may start after overlapping preparations")
	audio.stop_narration()

	states.clear()
	audio.waiting["missing"] = true
	audio.narrate(["first", "missing"])
	audio.resolve("missing", null)
	check(audio.narration_state == "unavailable" and not audio.narration.playing and not states.has("speaking"),
		"A missing later clip refuses the whole page without speaking a misleading partial report")
	audio.waiting.erase("missing")
	audio.cache["missing"] = second
	audio.narrate(["first", "missing"])
	check(audio.narration.playing and audio.narration_state == "speaking", "Retrying after a failed page can start the complete page")
	audio.stop_narration()
	audio.narrate(["res://assets/audio/pop/absent-narration-test.wav"])
	check(audio.narration_state == "unavailable" and not audio.narration.playing,
		"The production resource loader reports a genuinely absent clip as unavailable")

	for action in ["halt", "mute", "word", "stop_voice"]:
		audio.interact("spring", false)
		var delayed: String = "pending-" + action
		audio.waiting[delayed] = true
		audio.narrate([delayed])
		match action:
			"halt": audio.halt()
			"mute": audio.set_muted(true)
			"word": audio.say("first")
			"stop_voice": audio.stop_voice()
		audio.resolve(delayed, second)
		check(not audio.narration.playing and not audio.narration_state in ["loading", "speaking"],
			action + " cancels pending narration and prevents a late preparation from starting it")
		if action == "word":
			check(audio.voice.playing and audio.voice.stream == first, "A requested word replaces narration with the exact word stream")
		audio.set_muted(false)
		audio.stop_voice()
	audio.interact("spring", false)
	audio.narrate(["first"])
	audio.set_muted(true)
	check(not audio.narration.playing and audio.narration_state == "unavailable", "Muting also stops an already speaking narrator")
	audio.narrate(["first"])
	check(not audio.narration.playing and audio.narration_state == "unavailable", "Hear while muted cannot claim to speak")
	audio.set_muted(false)
	audio.interact("spring", false)
	audio.available = false
	audio.narrate(["first"])
	check(not audio.narration.playing and audio.narration_state == "unavailable", "An unavailable audio device refuses narration")
	audio.available = true
	audio.waiting["leaving-tree"] = true
	audio.narrate(["leaving-tree"])
	root.remove_child(audio)
	audio.resolve("leaving-tree", first)
	check(not audio.narration.playing and audio.narration_state == "idle", "Leaving the scene tree cancels pending narration")
	audio.free()


func _result_lifecycle() -> void:
	var directory: String = "user://pop-result-audio-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.size = Vector2i(390, 844)
	root.add_child(app)
	await process_frame
	await process_frame
	var narration_states: Array[String] = []
	app.audio.narration_state_changed.connect(func(state: String) -> void: narration_states.append(state))
	app.choose_mode("pop")
	app._configure_pop(37)
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
	check(not app.audio.narration.playing and not narration_states.has("loading") and not narration_states.has("speaking"),
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
			and not app.audio.narration.playing and not app.audio.music.playing,
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
		check(not app.audio.voice.playing and not app.audio.narration.playing,
			action + " stops review audio immediately without reviving report narration")
		if action == "more":
			first_review.pressed.emit()
			check(not app.audio.voice.playing, "A covered result word cannot pronounce behind the menu")
		match action:
			"more": app._hide_collection()
			"hidden": app.on_page_visible()
			"mute": app.audio.set_muted(false)
		check(not app.audio.voice.playing and not app.audio.narration.playing,
			action + " never resumes speech without a fresh word tap")
	first_review.pressed.emit()
	check(app.audio.voice.playing, "Review words work again after menu, background, and mute transitions")
	view.replay_button.pressed.emit()
	view.set_process(false)
	check(view.game.phase == "ready" and view.game.hits == 0 and not view._results.visible
		and not app.audio.voice.playing and not app.audio.narration.playing,
		"Play again clears the result and its pronunciation while waiting for fresh microphone readiness")
	first_review.pressed.emit()
	check(not app.audio.voice.playing, "A stale result word cannot play over the next round's listening gate")
	app._on_voice_state([true, true, "Listening."])
	view._advance_game(view.game.remaining)
	check(view.game.phase == "finished" and not app.audio.narration.playing
		and not narration_states.has("loading") and not narration_states.has("speaking"),
		"The next completed round also remains free of automatic narration")
	for destination in ["match", "memory"]:
		var review: Dictionary = view.game.summary().missed_words[0]
		app._pop_hear(review)
		check(app.audio.voice.playing, destination + " transition starts with an active result pronunciation")
		app.choose_mode(destination)
		check(app._mode_id == destination and not app.audio.voice.playing and not app.audio.narration.playing,
			"Leaving the result for " + destination + " stops the previous word without stale report callbacks")
		app._pop_hear(review)
		check(not app.audio.voice.playing, "A late Voice Pop word callback is ignored in " + destination)
		app.choose_mode("pop")
		view.set_process(false)
		app._on_voice_state([true, true, "Listening."])
		view._advance_game(view.game.remaining)
		check(view.game.phase == "finished" and not app.audio.narration.playing,
			"Returning from " + destination + " can complete another round without automatic speech")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
