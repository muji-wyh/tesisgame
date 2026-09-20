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


class SharedDownloadAudio extends "res://scripts/game_audio.gd":
	signal completed
	var download_count: int = 0
	var answer: Resource

	func _download(_url: String) -> Resource:
		download_count += 1
		await completed
		return answer

	func resolve(resource: Resource) -> void:
		answer = resource
		completed.emit()


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
	await _shared_download_failure()
	await _report_lifecycle()
	print("Pop narration: %d checks, %d failures" % [checks, failures])
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
	check(audio.narration_state == "loading" and not audio.narration.playing, "A pending first download keeps Pip silent")
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
		"An old download cannot revive a cancelled request")
	audio.waiting["old-page"] = true
	audio.waiting["new-page"] = true
	audio.narrate(["old-page"])
	audio.narrate(["new-page"])
	audio.resolve("old-page", first)
	check(not audio.narration.playing and audio.narration_state == "loading", "A stale page cannot interrupt the latest page's loading state")
	audio.resolve("new-page", second)
	check(audio.narration.playing and audio.narration.stream == second, "Only the latest page may start after overlapping downloads")
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
			action + " cancels pending narration and prevents a late download from starting it")
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


func _shared_download_failure() -> void:
	var audio := SharedDownloadAudio.new()
	root.add_child(audio)
	audio.interact("spring", false)
	var path: String = "res://assets/audio/pop/shared-download-test.wav"
	audio.remote_audio[path] = "controlled-download"
	for request in range(4):
		audio.narrate([path])
	check(audio.download_count == 1 and audio.narration_state == "loading", "Rapid Hear requests share one actual stream download")
	audio.resolve(null)
	await process_frame
	check(audio.download_count == 1 and audio.narration_state == "unavailable" and not audio.narration.playing,
		"Shared failure releases all obsolete waiters without a chain of automatic retries")
	audio.narrate([path])
	check(audio.download_count == 2 and audio.narration_state == "loading", "A fresh user retry is allowed to make one new download")
	var loaded: AudioStream = _clip()
	audio.resolve(loaded)
	check(audio.narration.playing and audio.narration.stream == loaded, "A successful explicit retry uses the newly loaded stream")
	audio.halt()
	audio.queue_free()
	await process_frame


func _report_lifecycle() -> void:
	var directory: String = "user://pop-narration-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.size = Vector2i(390, 844)
	root.add_child(app)
	await process_frame
	await process_frame
	app.audio.set_muted(true)
	app.choose_mode("pop")
	app._pop.set_process(false)
	app._on_voice_state([true, true, "Listening."])
	app._pop._advance_game(31.0)
	await process_frame
	var view = app._pop
	var prompts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://pop-voice-prompts.json"))
	var word_a: Dictionary = app.data.words[0]
	var word_b: Dictionary = app.data.words[1]
	var word_c: Dictionary = app.data.words[2]
	var plan: Array[Dictionary] = view._make_report({"hits": 4, "best_combo": 3, "score": 123,
		"unique_words": 2, "hit_words": [word_a, word_b], "missed_words": [word_c]})
	check(plan[0].text == prompts["round-4"] and plan[0].audio == ["res://assets/audio/pop/round-4.wav"],
		"The round caption is exactly the manifest sentence played by one whole recording")
	check(plan[1].audio == ["res://assets/audio/pop/highlights-two.wav", "res://" + str(word_a.audio),
		"res://" + str(word_b.audio), "res://assets/audio/pop/combo-3.wav"],
		"Highlights narrate the real first two words in order and then a complete combo sentence")
	check(plan[2].audio == ["res://assets/audio/pop/practice.wav", "res://" + str(word_c.audio),
		"res://assets/audio/pop/practice-next.wav"] and str(plan[2].text).contains(str(word_c.text)),
		"Coaching prefers a missed word and matches its picture's actual pronunciation")
	plan = view._make_report({"hits": 1, "best_combo": 1, "hit_words": [word_a], "missed_words": []})
	check(plan[1].audio[0] == "res://assets/audio/pop/highlights-one.wav"
		and plan[2].audio == ["res://assets/audio/pop/repeat.wav", "res://" + str(word_a.audio), "res://assets/audio/pop/repeat-next.wav"],
		"One highlight and successful-word coaching use their distinct natural recordings")
	plan = view._make_report({"hits": 0, "best_combo": 0, "hit_words": [], "missed_words": []})
	check(plan[1].text == prompts["no-highlights"] and plan[1].audio == ["res://assets/audio/pop/no-highlights.wav"]
		and plan[2].audio == ["res://assets/audio/pop/ready.wav"],
		"An empty report offers help without inventing words or a combo")
	plan = view._make_report({"hits": 21, "best_combo": 21, "hit_words": [word_a], "missed_words": []})
	check(str(plan[0].text).contains("21 words") and str(plan[0].text).contains("Pip says:")
		and plan[0].audio == ["res://assets/audio/pop/round-fallback.wav"]
		and not plan[1].audio.has("res://assets/audio/pop/combo-20.wav"),
		"Beyond the recorded range, exact text remains and generic encouragement never lies about a count")
	var long_clip: AudioStream = _clip(4.0)
	for id in prompts:
		app.audio.cache["res://assets/audio/pop/" + str(id) + ".wav"] = long_clip
	for word in app.data.words:
		app.audio.cache["res://" + str(word.audio)] = long_clip
	app.audio.set_muted(false)
	view.report_button.pressed.emit()
	check(app.audio.narration.playing and bool(view.snapshot().report_speaking) and view.pip.speaking,
		"Hear Pip starts native narration and projects actual playback to the result mouth and snapshot")
	var first_page: Array = view.report_audio()
	var exposed: Array = view.snapshot().report_audio
	exposed.clear()
	check(view.report_audio() == first_page, "The exposed report audio list cannot mutate the internal page")
	view.next_report_button.pressed.emit()
	check(app.audio.narration.playing and view.report_audio() != first_page
		and app.audio.narration.stream == app.audio.cache[view.report_audio()[0]],
		"Changing pages replaces the old narration with the new page's recorded clips")
	view.pip.pressed.emit()
	check(view.report_audio()[0] == "res://assets/audio/pop/high-five.wav" and view.report_text().begins_with(str(prompts["high-five"])),
		"High five prepends matching visible feedback and recorded audio")
	var greeting: AudioStream = app.audio.narration.stream
	check(greeting != null and greeting.resource_path.begins_with("res://assets/audio/pip/")
		and app.audio.narration.playing and app.audio._narration_streams.size() == view.report_audio().size() + 1
		and not app.audio.voice.playing and not app.audio.effect.playing,
		"A result Pip tap queues one imported greeting before the report on the single narration player")
	app.audio._narration_finished()
	check(app.audio.narration.stream == app.audio.cache[view.report_audio()[0]] and view.pip.speaking,
		"Finishing the greeting continues into the matching high-five sentence without cutting off the report")
	view.pip.pressed.emit()
	check(app.audio.narration.stream != greeting
		and app.audio.narration.stream.resource_path.begins_with("res://assets/audio/pip/")
		and app.audio._narration_streams.size() == view.report_audio().size() + 1,
		"A second Pip tap replaces the queue with a different greeting instead of stacking narration")
	view.report_button.pressed.emit()
	check(app.audio.narration.stream == app.audio.cache[view.report_audio()[0]]
		and app.audio._narration_streams.size() == view.report_audio().size(),
		"Hear Pip replays only the visible report without adding another random greeting")
	var review: Dictionary = view.game.summary().missed_words[0]
	app._pop_hear(review)
	check(not app.audio.narration.playing and app.audio.voice.playing
		and not bool(view.snapshot().report_speaking) and not bool(view.snapshot().report_loading),
		"Listening to a review word ends report narration and immediately clears its UI state")

	for action in ["more", "hidden", "mute", "stop_voice"]:
		view.report_button.pressed.emit()
		check(app.audio.narration.playing, action + " starts from a genuinely speaking report")
		match action:
			"more": app._show_collection()
			"hidden": app.on_page_hidden()
			"mute": app.audio.set_muted(true)
			"stop_voice": app.audio.stop_voice()
		check(not app.audio.narration.playing and not view.pip.speaking
			and not bool(view.snapshot().report_speaking) and not bool(view.snapshot().report_loading),
			action + " clears actual report playback and both projected states immediately")
		match action:
			"more": app._hide_collection()
			"hidden": app.on_page_visible()
			"mute": app.audio.set_muted(false)
		check(not app.audio.narration.playing, action + " never resumes speech without a fresh request")

	view._show_report(0)
	var original_audio: Array = view._report_pages[0].audio
	view._report_pages[0].audio = ["res://assets/audio/pop/absent-narration-test.wav"]
	view.report_button.pressed.emit()
	check(view.report_button.text == "Try Pip again" and not view.pip.speaking,
		"A missing clip leaves a visible read-along fallback with a real retry action")
	app.audio.stop_narration()
	check(view.report_button.text == "Try Pip again" and view._report_kicker.text.contains("READ ALONG"),
		"A later idle notification does not erase the unavailable explanation")
	view._report_pages[0].audio = original_audio
	view.report_button.pressed.emit()
	check(view.pip.speaking and view.report_button.text == "Hear again", "A successful retry clears the error and shows actual playback")
	app.choose_mode("match")
	check(not app.audio.narration.playing and not bool(view.snapshot().report_speaking)
		and not bool(view.snapshot().report_loading) and view.report_audio().is_empty(),
		"Changing modes clears narration, loading, speaking, and the report's exported clip list")
	view.set_report_audio_state("speaking")
	check(not view.pip.speaking and not bool(view.snapshot().report_speaking), "A late playback state cannot animate results after leaving")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
