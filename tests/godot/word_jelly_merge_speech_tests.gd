extends SceneTree

const Audio = preload("res://scripts/game_audio.gd")
const Jelly = preload("res://scripts/word_jelly.gd")
const Data = preload("res://scripts/game_data.gd")
const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const CAT: String = "res://assets/audio/voice/word-cat.wav"
const DOG: String = "res://assets/audio/voice/word-dog.wav"

class DelayedAudio extends "res://scripts/game_audio.gd":
	signal recording_loaded

	func _stream(path: String, loop: bool = false) -> AudioStream:
		if path == "res://assets/audio/voice/word-cat.wav":
			await recording_loaded
		return await super._stream(path, loop)

var checks: int = 0
var failures: int = 0
var data = Data.new()
var words: Array = []
var merged: Array[Dictionary] = []
var tapped: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(5):
		await process_frame


func _reset_view(view, pieces: Array[String], reduced: bool = false) -> Array[int]:
	check(view.configure(words, 3, Data.theme("spring"), data.chests, reduced, 42),
		"The speech fixture uses production vocabulary, artwork, and recordings")
	view.set_process(false)
	view.game.spawn_interval = 10000.0
	view.credit_collection = func(_id: String, _amount: int) -> Dictionary: return {"ok": true}
	view.purchase_powerup = func(_id: String, _kind: String, _price: int) -> Dictionary: return {"ok": true}
	view.game.cells.clear()
	var ids: Array[int] = []
	for index in range(pieces.size()):
		var tile: Dictionary = view.game._new_tile(pieces[index], 1, 0)
		tile.column = index
		tile.row = view.game.ROWS - 1
		view.game.cells.append(tile)
		ids.append(int(tile.id))
	view._sync_tiles()
	view._layout()
	view._process(0.0)
	merged.clear()
	tapped.clear()
	return ids


func _finish_recording(audio) -> void:
	# Drive the player's natural-completion signal without depending on wall time.
	audio.voice.stop()
	audio.voice.finished.emit()


func _advance(view, seconds: float) -> void:
	var remaining: float = seconds
	while remaining > 0.000001:
		var delta: float = minf(0.025, remaining)
		view._process(delta)
		remaining -= delta


func _check_merge_events() -> void:
	var view := Jelly.new()
	root.add_child(view)
	view.size = Vector2(1000, 720)
	view.word_merged.connect(func(word: Dictionary) -> void: merged.append(word))
	view.word_requested.connect(func(word: Dictionary) -> void: tapped.append(word))
	for reduced: bool in [false, true]:
		var ids: Array[int] = _reset_view(view, ["ca", "t"], reduced)
		check(view.game.try_merge(ids[0], ids[1]) == "merged", "A manual prefix-first merge starts")
		check(not bool(view.game.fusions[0].automatic), "Manual fusion retains its pronunciation origin")
		check(merged.is_empty(), "Contact does not pronounce an unfinished merge")
		_advance(view, view.game.FUSION_SECONDS - 0.001)
		check(merged.is_empty(), "Pronunciation waits for the complete fusion animation")
		view._process(0.002)
		check(merged.size() == 1 and merged[0].id == "cat" and merged[0].audio == words[0].audio,
			"Exactly one completed merge requests its full production word in either motion preference")
		_advance(view, view.game.SETTLE_SECONDS * 3.0)
		check(merged.size() == 1 and view.game.collectable_ids().size() == 1,
			"Settlement does not replay pronunciation or collect the word")
		check(view.game.collect(view.game.collectable_ids()[0]), "A completed word can still be collected deliberately")
		view._process(view.game.COLLECT_SECONDS)
		check(merged.size() == 1 and tapped.size() == 1,
			"Direct collection retains its explicit tap pronunciation without another merge request")
	var ids: Array[int] = _reset_view(view, ["ca", "t"])
	check(view.game.try_merge(ids[1], ids[0]) == "wrong", "A reversed invalid word is rejected")
	_advance(view, 1.0)
	check(merged.is_empty() and tapped.is_empty(), "Rejected contact never requests a pronunciation")
	check(view.game.try_merge(ids[0], ids[1]) == "merged", "The valid direction can still merge after rejection")
	view._process(view.game.FUSION_SECONDS * 0.5)
	view.pause(true)
	view._process(10.0)
	check(merged.is_empty(), "A paused fusion cannot finish or pronounce its result")
	view.pause(false)
	_advance(view, view.game.FUSION_SECONDS)
	check(merged.size() == 1, "Resuming a pending fusion pronounces the committed result once")
	for reduced: bool in [false, true]:
		_reset_view(view, ["ca", "t", "do", "g", "ca", "t"], reduced)
		check(view.game.activate_powerup("auto_merge"), "Auto Merge starts with three valid pairs")
		view._process(view.game.POWERUP_DRAG_SECONDS)
		check(view.game.fusions.size() == 1 and bool(view.game.fusions[0].automatic),
			"An automatic fusion retains its origin through the delayed completion")
		view.pause(true)
		view._process(1.0)
		check(merged.is_empty(), "Pausing Auto Merge cannot request pronunciation")
		view.pause(false)
		for frame in range(500):
			if not view.game.powerup_active():
				break
			view._process(0.01)
		check(not view.game.powerup_active() and merged.is_empty() and view.game.merged_count == 3,
			"Every automatic merge stays unspoken through the final overlapping fusion in either motion preference")
		check(tapped.is_empty() and view.game.collected_coins == 0 and view.game.collectable_ids().size() == 3,
			"Silent Auto Merge leaves every completed word available for deliberate collection")
		check(view.game.start_collection_batch(), "The player can separately collect the automatic results")
		_advance(view, 3.0)
		check(merged.is_empty() and tapped.is_empty(), "Batch Collect never requests or repeats an automatic word pronunciation")
	_reset_view(view, ["ca", "t", "do", "g"])
	check(view.game.activate_powerup("auto_merge"), "A pending paid operation can be stopped")
	view._process(0.1)
	view.stop()
	check(merged.is_empty() and not view.game.powerup_active(),
		"Leaving silently drains paid merges without speaking hidden results")
	view.free()


func _check_audio_queue() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	audio.interact("spring", false)
	audio.say_queued(CAT)
	check(audio.voice.playing and audio.voice.stream == load(CAT), "The first merged word begins immediately")
	var request: int = int(audio._playback_requests[audio.voice])
	audio.say_queued(DOG)
	audio.say_queued(CAT)
	check(audio.voice.stream == load(CAT) and int(audio._playback_requests[audio.voice]) == request
		and audio._voice_queue == [DOG, CAT], "Rapid merges queue in order without restarting or truncating the current recording")
	_finish_recording(audio)
	check(audio.voice.playing and audio.voice.stream == load(DOG) and audio._voice_queue == [CAT],
		"Natural completion starts the next queued word exactly once")
	_finish_recording(audio)
	check(audio.voice.playing and audio.voice.stream == load(CAT) and audio._voice_queue.is_empty(),
		"Separate merges of the same word each retain their pronunciation")
	_finish_recording(audio)
	check(not audio.voice.playing and audio._voice_queue.is_empty(), "Finishing the queue leaves no replay")
	for interruption: String in ["say", "stop", "halt", "mute"]:
		audio.set_muted(false)
		audio.interact("spring", false)
		audio.say_queued(CAT)
		audio.say_queued(CAT)
		match interruption:
			"say": audio.say(DOG)
			"stop": audio.stop_voice()
			"halt": audio.halt()
			"mute": audio.set_muted(true)
		check(audio._voice_queue.is_empty() and not audio._voice_queue_loading,
			interruption + " discards pending merge speech")
		if interruption == "say":
			check(audio.voice.playing and audio.voice.stream == load(DOG), "An explicit word tap takes priority immediately")
		else:
			check(not audio.voice.playing, interruption + " stops the current recording")
		_finish_recording(audio)
		check(not audio.voice.playing and audio._voice_queue.is_empty(), interruption + " cannot replay canceled words through a late finish")
	audio.say_queued(CAT)
	check(not audio.voice.playing and audio._voice_queue.is_empty(), "Muted events never enter the pronunciation queue")
	audio.set_muted(false)
	audio.interact("spring", false)
	audio.say_queued("res://assets/audio/voice/missing-merge-test.wav")
	audio.say_queued(DOG)
	check(audio.voice.playing and audio.voice.stream == load(DOG), "A missing recording cannot block later valid words")
	audio.halt()
	audio.free()


func _check_pending_audio() -> void:
	for interruption: String in ["stop", "halt", "mute", "say"]:
		var audio := DelayedAudio.new()
		root.add_child(audio)
		audio.interact("spring", false)
		audio.say_queued(CAT)
		audio.say_queued(DOG)
		check(audio._voice_queue_loading and not audio.voice.playing,
			"Loading a queued recording reserves its place without starting later speech")
		match interruption:
			"stop": audio.stop_voice()
			"halt": audio.halt()
			"mute": audio.set_muted(true)
			"say": audio.say(DOG)
		audio.recording_loaded.emit()
		check(audio._voice_queue.is_empty() and not audio._voice_queue_loading,
			interruption + " invalidates both the loading request and its waiting words")
		check(audio.voice.playing and audio.voice.stream == load(DOG) if interruption == "say" else not audio.voice.playing,
			interruption + " prevents an old asynchronous load from replacing newer playback state")
		audio.halt()
		audio.free()


func _prepare_app(app) -> void:
	Fixture.enter_mode(app, "word_jelly")
	await settle()
	_reset_view(app._word_jelly, ["ca", "t", "do", "g"])
	app._sync_jelly()
	app.audio.set_muted(false)
	app.audio.interact(app.model.theme_id, false)
	app.audio.stop_voice()


func _check_app_routes() -> void:
	var directory: String = "user://word-jelly-merge-speech-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = preload("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await settle()
	await _prepare_app(app)
	var view = app._word_jelly
	var voice_request: int = int(app.audio._playback_requests.get(app.audio.voice, 0))
	view._activate_powerup("auto_merge")
	_advance(view, 4.0)
	check(view.game.merged_count == 2 and not view.game.powerup_active() and view.game.cleared_pairs == 0,
		"The application finishes both automatic fusions without collecting them")
	check(not app.audio.voice.playing and app.audio._voice_queue.is_empty()
		and int(app.audio._playback_requests.get(app.audio.voice, 0)) == voice_request,
		"Auto Merge never starts or queues a word recording in the application")
	var completed: Dictionary = view.game.cell(view.game.collectable_ids()[0])
	view._activate(int(completed.id))
	check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + str(completed.word.audio)),
		"A deliberate tap on an automatically merged word still pronounces it")
	app.audio.stop_voice()
	var ids: Array[int] = _reset_view(view, ["ca", "t", "do", "g"])
	check(view.game.try_merge(ids[0], ids[1]) == "merged" and view.game.try_merge(ids[2], ids[3]) == "merged",
		"The application accepts two independent word fusions")
	_advance(view, view.game.FUSION_SECONDS + view.game.SETTLE_SECONDS * 3.0)
	check(app.audio.voice.playing and app.audio.voice.stream == load(CAT) and app.audio._voice_queue == [DOG],
		"Committed application merges route to noninterrupting production word playback")
	view._collect_all()
	check(view.game.collection_batch_active() and not app.audio.voice.playing and app.audio._voice_queue.is_empty(),
		"Collect cancels residual merge narration before its first pickup")
	_advance(view, 3.0)
	_finish_recording(app.audio)
	check(not app.audio.voice.playing and app.audio._voice_queue.is_empty(),
		"The final batch pickup cannot replay a queued merge word")
	for interruption: String in ["home", "hidden", "finish", "mute"]:
		await _prepare_app(app)
		view.word_merged.emit(words[0])
		view.word_merged.emit(words[1])
		check(app.audio.voice.playing and app.audio._voice_queue.size() == 1,
			interruption + " starts with one speaking word and one waiting word")
		match interruption:
			"home": app._show_mode_menu()
			"hidden": app.on_page_hidden()
			"finish": view.finish_button.accessibility_requested.emit()
			"mute": app.audio.set_muted(true)
		check(not app.audio.voice.playing and app.audio._voice_queue.is_empty(),
			interruption + " cancels spoken and queued merge words")
		view.word_merged.emit(words[0])
		check(not app.audio.voice.playing and app.audio._voice_queue.is_empty(),
			interruption + " rejects merge narration while gameplay is unavailable")
		if interruption == "hidden":
			app.on_page_visible()
		elif interruption == "finish":
			app._cancel_jelly_finish()
		elif interruption == "mute":
			app.audio.set_muted(false)
		check(not app.audio.voice.playing and app.audio._voice_queue.is_empty(),
			interruption + " restoration does not replay old pronunciations")
	app.audio.halt()
	app.queue_free()
	await settle()
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1000, 720)
	check(data.load_all(), "Production vocabulary is available")
	for id: String in ["cat", "dog"]:
		for word: Dictionary in data.words:
			if str(word.id) == id:
				words.append(word.duplicate(true))
	check(words.size() == 2, "Both speech fixtures have production entries")
	_check_merge_events()
	_check_audio_queue()
	_check_pending_audio()
	await _check_app_routes()
	await settle()
	print("Jelly Words merge speech: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
