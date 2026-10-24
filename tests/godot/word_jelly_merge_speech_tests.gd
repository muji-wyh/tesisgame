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
	view.set_pip_level(3)
	check(view.configure(words, 3, Data.theme("spring"), data.chests, reduced, 42),
		"The speech fixture uses production vocabulary, artwork, and recordings")
	view.set_process(false)
	view.game.spawn_interval = 10000.0
	view.credit_collection = func(_id: String, _amount: int) -> Dictionary: return {"ok": true}
	view.purchase_powerup = func(_id: String, _kind: String, _price: int) -> Dictionary: return {"ok": true}
	view.game.cells.clear()
	var ids: Array[int] = []
	for index in range(pieces.size()):
		var word: Dictionary = words[1] if pieces[index] in ["dog-root", "dog-picture"] else words[0]
		var tile: Dictionary = view.game._new_picture_tile(word) if pieces[index] in ["cat-picture", "dog-picture"] else view.game._new_word_root(word)
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
		var ids: Array[int] = _reset_view(view, ["cat-root", "cat-picture"], reduced)
		check(view.game.try_merge(ids[0], ids[1]) == "merged", "A manual word-picture merge starts")
		check(not bool(view.game.fusions[0].automatic), "Manual fusion retains its pronunciation origin")
		check(merged.size() == 1 and merged[0].id == "cat" and merged[0].audio == words[0].audio,
			"Accepting a valid manual merge requests its full production word immediately in either motion preference")
		_advance(view, view.game.FUSION_SECONDS - 0.001)
		check(merged.size() == 1, "The liquid fusion continues without delaying or repeating its word")
		view._process(0.002)
		check(merged.size() == 1 and merged[0].id == "cat" and merged[0].audio == words[0].audio,
			"Completing the fusion never repeats its accepted-merge pronunciation")
		_advance(view, view.game.SETTLE_SECONDS * 3.0)
		check(merged.size() == 1 and view.game.collectable_ids().size() == 1,
			"Settlement does not replay pronunciation or collect the word")
		check(view.game.collect(view.game.collectable_ids()[0]), "A completed word can still be collected deliberately")
		view._process(view.game.COLLECT_SECONDS)
		check(merged.size() == 1 and tapped.size() == 1,
			"Direct collection retains its explicit tap pronunciation without another merge request")
	var ids: Array[int] = _reset_view(view, ["cat-root", "cat-picture"])
	var wrong_picture: Dictionary = view.game.cells[view.game._index_for_id(ids[1])]
	wrong_picture.image_word = words[1].duplicate(true)
	check(view.game.try_merge(ids[1], ids[0]) == "wrong", "A different word picture is rejected")
	_advance(view, 1.0)
	check(merged.is_empty() and tapped.is_empty(), "Rejected contact never requests a pronunciation")
	view.pause(true)
	check(view.game.try_merge(ids[0], ids[1]) == "ignored" and merged.is_empty(),
		"A paused board cannot accept a merge or request its pronunciation")
	view.pause(false)
	wrong_picture.image_word = words[0].duplicate(true)
	check(view.game.try_merge(ids[0], ids[1]) == "merged", "The matching picture can merge after rejection")
	check(merged.size() == 1, "The accepted word is requested before the next animation frame")
	view._process(view.game.FUSION_SECONDS * 0.5)
	view.pause(true)
	view._process(10.0)
	check(merged.size() == 1 and view.game.merged_count == 0,
		"A paused fusion cannot finish or repeat its accepted word")
	view.pause(false)
	_advance(view, view.game.FUSION_SECONDS)
	check(merged.size() == 1 and view.game.merged_count == 1,
		"Resuming completes the pending fusion without requesting its pronunciation again")
	ids = _reset_view(view, ["cat-root", "cat-picture"])
	var duplicate_results: Array[String] = []
	var pause_on_word: Callable = func(_word: Dictionary) -> void:
		duplicate_results.append(view.game.try_merge(ids[0], ids[1]))
		view.pause(true)
	view.word_merged.connect(pause_on_word)
	check(view.game.try_merge(ids[0], ids[1]) == "merged", "A valid merge can synchronously pause from its word callback")
	view.word_merged.disconnect(pause_on_word)
	check(duplicate_results == ["ignored"] and merged.size() == 1 and view.game.paused,
		"The accepted fusion is reserved before speech callbacks can attempt the same merge again")
	_advance(view, 1.0)
	check(merged.size() == 1 and view.game.merged_count == 0,
		"A synchronous pause prevents animation advancement without duplicating the word event")
	view.pause(false)
	_advance(view, 1.0)
	check(merged.size() == 1 and view.game.merged_count == 1,
		"The accepted fusion completes exactly once after its synchronous pause resumes")
	for reduced: bool in [false, true]:
		_reset_view(view, ["cat-root", "cat-picture", "dog-root", "dog-picture"], reduced)
		check(view.game.activate_powerup("auto_merge"), "Auto Merge starts with two distinct word-picture pairs")
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
		check(not view.game.powerup_active() and merged.is_empty() and view.game.merged_count == 2,
			"Every automatic merge stays unspoken through the final sequential fusion in either motion preference")
		check(tapped.is_empty() and view.game.collected_coins == 0 and view.game.collectable_ids().size() == 2,
			"Silent Auto Merge leaves every completed word available for deliberate collection")
		check(view.game.start_collection_batch(), "The player can separately collect the automatic results")
		_advance(view, 3.0)
		check(merged.is_empty() and tapped.is_empty(), "Batch Collect never requests or repeats an automatic word pronunciation")
	_reset_view(view, ["cat-root", "cat-picture", "dog-root", "dog-picture"])
	check(view.game.activate_powerup("auto_merge"), "A pending paid operation can be stopped")
	view._process(0.1)
	view.stop()
	check(merged.is_empty() and not view.game.powerup_active(),
		"Leaving silently drains paid merges without speaking hidden results")
	view.free()


func _check_tile_taps() -> void:
	var view := Jelly.new()
	root.add_child(view)
	view.size = Vector2(1000, 720)
	var spoken: Array[Dictionary] = []
	view.word_requested.connect(func(word: Dictionary) -> void: spoken.append(word))
	for reduced: bool in [false, true]:
		var ids: Array[int] = _reset_view(view, ["cat-root", "dog-picture"], reduced)
		spoken.clear()
		for index in range(ids.size()):
			var tile = view._tiles[ids[index]]
			var point: Vector2 = tile.get_global_rect().get_center()
			check(view._press(-1, point), "The complete spelling and picture accept a pointer press")
			check(spoken.size() == index, "Pressing a tile does not speak before a deliberate tap completes")
			view._release(point)
			check(spoken.size() == index + 1 and spoken[-1].id == words[index].id,
				"A pointer tap pronounces the exact spelling or picture word once")
		check(view.game.fusions.is_empty() and view.game.cells.size() == 2 and view.game.cleared_pairs == 0,
			"Listening to a source spelling or picture does not collect or merge it")
		for index in range(ids.size()):
			view.cancel_input()
			view._activate(ids[index])
			check(spoken.size() == 3 + index and spoken[-1].id == words[index].id
				and view._keyboard_source == ids[index],
				"Keyboard activation speaks once and retains source selection for a later merge")
		view.cancel_input()
		view.pause(true)
		view._tap_tile(ids[0])
		view._activate(ids[1])
		check(spoken.size() == 4, "A paused board cannot pronounce source tiles")
		view.pause(false)
		var partial: Dictionary = view.game._new_tile("ca", 1, 0)
		partial.column = 2
		partial.row = view.game.ROWS - 1
		view.game.cells.append(partial)
		view._sync_tiles()
		view._tap_tile(int(partial.id))
		view._activate(int(partial.id))
		check(spoken.size() == 4, "A partial root never pronounces a guessed whole word")
	view.free()


func _check_immediate_audio() -> void:
	var audio := Audio.new()
	root.add_child(audio)
	audio.interact("spring", false)
	audio.say(CAT)
	check(audio.voice.playing and audio.voice.stream == load(CAT), "The first merged word begins immediately")
	var request: int = int(audio._playback_requests[audio.voice])
	audio.say(DOG)
	check(audio.voice.playing and audio.voice.stream == load(DOG)
		and int(audio._playback_requests[audio.voice]) > request, "A new merged word immediately replaces the previous recording")
	request = int(audio._playback_requests[audio.voice])
	audio.say(DOG)
	check(audio.voice.playing and audio.voice.stream == load(DOG)
		and int(audio._playback_requests[audio.voice]) > request, "A separate merge of the same word restarts its pronunciation")
	_finish_recording(audio)
	_finish_recording(audio)
	check(not audio.voice.playing, "Natural completion and repeated finish signals cannot replay replaced words")
	for interruption: String in ["stop", "halt", "mute"]:
		audio.set_muted(false)
		audio.interact("spring", false)
		audio.say(CAT)
		match interruption:
			"stop": audio.stop_voice()
			"halt": audio.halt()
			"mute": audio.set_muted(true)
		check(not audio.voice.playing, interruption + " stops the current recording")
		_finish_recording(audio)
		check(not audio.voice.playing, interruption + " cannot replay canceled speech through a late finish")
	audio.say(CAT)
	check(not audio.voice.playing, "Muted events never start pronunciation")
	audio.set_muted(false)
	audio.interact("spring", false)
	audio.say("res://assets/audio/voice/missing-merge-test.wav")
	audio.say(DOG)
	check(audio.voice.playing and audio.voice.stream == load(DOG), "A missing recording cannot block a later valid word")
	audio.halt()
	audio.free()


func _check_pending_audio() -> void:
	for interruption: String in ["stop", "halt", "mute", "say"]:
		var audio := DelayedAudio.new()
		root.add_child(audio)
		audio.interact("spring", false)
		audio.say(CAT)
		var pending_request: int = int(audio._playback_requests[audio.voice])
		check(not audio.voice.playing, "An asynchronous recording stays silent until its load finishes")
		match interruption:
			"stop": audio.stop_voice()
			"halt": audio.halt()
			"mute": audio.set_muted(true)
			"say": audio.say(DOG)
		check(int(audio._playback_requests[audio.voice]) > pending_request,
			interruption + " invalidates the pending playback request")
		audio.recording_loaded.emit()
		check(audio.voice.playing and audio.voice.stream == load(DOG) if interruption == "say" else not audio.voice.playing,
			interruption + " prevents an old asynchronous load from replacing newer playback state")
		audio.halt()
		audio.free()


func _prepare_app(app) -> void:
	Fixture.enter_mode(app, "word_jelly")
	await settle()
	_reset_view(app._word_jelly, ["cat-root", "cat-picture", "dog-root", "dog-picture"])
	Fixture.unlock_auto_collect(app)
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
	for source: int in [0, 3]:
		var tile: Dictionary = view.game.cells[source]
		view._tap_tile(int(tile.id))
		var word: Dictionary = tile.word_candidate if source == 0 else tile.image_word
		check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + str(word.audio)), "Source spelling and picture taps route immediately to their exact recording")
	app.audio.stop_voice()
	var voice_request: int = int(app.audio._playback_requests.get(app.audio.voice, 0))
	view._activate_powerup("auto_merge")
	_advance(view, 4.0)
	check(view.game.merged_count == 2 and not view.game.powerup_active() and view.game.cleared_pairs == 0,
		"The application finishes both automatic fusions without collecting them")
	check(not app.audio.voice.playing
		and int(app.audio._playback_requests.get(app.audio.voice, 0)) == voice_request,
		"Auto Merge never requests a word recording in the application")
	var completed: Dictionary = view.game.cell(view.game.collectable_ids()[0])
	view._activate(int(completed.id))
	check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + str(completed.word.audio)),
		"A deliberate tap on an automatically merged word still pronounces it")
	app.audio.stop_voice()
	var ids: Array[int] = _reset_view(view, ["cat-root", "cat-picture", "dog-root", "dog-picture"])
	check(view.game.try_merge(ids[0], ids[1]) == "merged" and view.game.try_merge(ids[2], ids[3]) == "merged",
		"The application accepts two independent word fusions")
	check(app.audio.voice.playing and app.audio.voice.stream == load(DOG),
		"The latest accepted merge immediately replaces earlier speech instead of waiting in a queue")
	var accepted_request: int = int(app.audio._playback_requests.get(app.audio.voice, 0))
	_advance(view, view.game.FUSION_SECONDS + view.game.SETTLE_SECONDS * 3.0)
	check(app.audio.voice.playing and app.audio.voice.stream == load(DOG)
		and int(app.audio._playback_requests.get(app.audio.voice, 0)) == accepted_request,
		"Fusion completion preserves current playback without restarting or duplicating speech")
	view._collect_all()
	check(view.game.collection_batch_active() and not app.audio.voice.playing,
		"Collect cancels residual merge narration before its first pickup")
	_advance(view, 3.0)
	_finish_recording(app.audio)
	check(not app.audio.voice.playing,
		"The final batch pickup cannot replay canceled merge speech")
	for interruption: String in ["home", "hidden", "finish", "mute"]:
		await _prepare_app(app)
		view.word_merged.emit(words[0])
		view.word_merged.emit(words[1])
		check(app.audio.voice.playing and app.audio.voice.stream == load(DOG),
			interruption + " starts with the latest merged word speaking and no delayed words")
		match interruption:
			"home": app._show_mode_menu()
			"hidden": app.on_page_hidden()
			"finish": view.finish_button.accessibility_requested.emit()
			"mute": app.audio.set_muted(true)
		check(not app.audio.voice.playing,
			interruption + " cancels the current merge pronunciation")
		view.word_merged.emit(words[0])
		check(not app.audio.voice.playing,
			interruption + " rejects merge narration while gameplay is unavailable")
		if interruption == "hidden":
			app.on_page_visible()
		elif interruption == "finish":
			app._cancel_jelly_finish()
		elif interruption == "mute":
			app.audio.set_muted(false)
		check(not app.audio.voice.playing,
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
	_check_tile_taps()
	_check_foundation01_speech_boundary()
	_check_immediate_audio()
	_check_pending_audio()
	await _check_app_routes()
	await settle()
	print("Jelly Words merge speech: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_foundation01_speech_boundary() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/lexemes/foundation-module01.json"))
	var entry: Dictionary = document.lexemes.filter(func(row: Dictionary) -> bool: return row.id == "signature.written-name.n")[0]
	# The actual graph is bound to existing fixture media only to inspect events.
	# This does not synthesize, play or approve a Foundation01 recording.
	var word: Dictionary = words[0].duplicate(true)
	word.id = entry.id
	word.text = entry.text
	word.track = "professional"
	word.practice_modes = entry.practice_modes.duplicate()
	word.morphology = entry.morphology.duplicate(true)
	word.erase("min_age")
	var view := Jelly.new()
	root.add_child(view)
	view.size = Vector2(1000, 720)
	var requests: Array = []
	var taps: Array = []
	var attempts: Array = []
	view.word_merged.connect(func(payload: Dictionary): requests.append(payload.duplicate(true)))
	view.word_requested.connect(func(payload: Dictionary): taps.append(payload.duplicate(true)))
	view.word_attempted.connect(func(event_id: String, ids: Array[String], correct: bool): attempts.append([event_id, ids, correct]))
	for reduced: bool in [false, true]:
		check(view.configure([word], 3, Data.theme("spring"), data.chests, reduced, 42), "Actual signature graph configures with explicitly synthetic fixture media")
		view.set_process(false)
		view.game.spawn_interval = 10000.0
		view.game.cells.clear()
		var pieces: Array[Dictionary] = []
		for state: Dictionary in view.game._morphology.source_tiles(entry.morphology.id):
			var tile: Dictionary = view.game._new_composition_tile(state)
			var position: Vector2i = view.game._free_position(view.game._occupied(), int(tile.width), int(tile.height))
			tile.column = position.x
			tile.row = position.y
			view.game.cells.append(tile)
			pieces.append(tile)
		view._sync_tiles()
		view._layout()
		_advance(view, 1.0)
		requests.clear()
		taps.clear()
		check(view.game.try_merge(int(pieces[0].id), int(pieces[1].id)) == "merged", "Signature accepts its authored first join")
		var partial_id: int = int(view.game.fusions[0].result.id)
		check(requests.is_empty(), "Accepting bound signate never requests whole-word speech")
		_advance(view, 2.0)
		check(requests.is_empty() and taps.is_empty() and view.game.cell(partial_id).text == "signate", "Partial animation and settlement remain silent in either motion preference")
		view._tap_tile(partial_id)
		check(taps.is_empty(), "Tapping an authored bound intermediate never pronounces the completed word")
		check(not view.game.collect(partial_id) and requests.is_empty() and taps.is_empty(), "Partial collection refusal cannot leak a pronunciation event")
		check(view.game.try_merge(partial_id, int(pieces[2].id)) == "merged", "Signature accepts final-e loss into the completed word")
		var spelling_id: int = int(view.game.fusions[0].result.id)
		check(requests.is_empty() and taps.is_empty(), "Completing the spelling waits for its picture without leaking whole-word speech")
		_advance(view, 2.0)
		check(not view.game.collect(spelling_id), "A complete pictured spelling still needs its picture Jelly")
		view._tap_tile(spelling_id)
		check(taps.size() == 1 and taps[0].id == entry.id and attempts.is_empty(),
			"Tapping an authored complete spelling pronounces it before picture matching without granting mastery")
		taps.clear()
		var picture: Dictionary = view.game._new_picture_tile(word)
		var picture_position: Vector2i = view.game._free_position(view.game._occupied(), 1, 1)
		picture.column = picture_position.x
		picture.row = picture_position.y
		view.game.cells.append(picture)
		view._sync_tiles()
		_advance(view, 1.0)
		check(view.game.try_merge(spelling_id, int(picture.id)) == "merged", "The completed signature spelling pairs with its exact picture")
		check(requests.size() == 1 and requests[0].id == entry.id and requests[0].audio == word.audio, "Only the accepted picture fusion requests the exact completed-word fixture payload")
		_advance(view, 2.0)
		check(requests.size() == 1 and taps.is_empty() and attempts.is_empty(), "Picture settlement never repeats pronunciation, collects or grants mastery automatically")
	var atomic_count: int = 0
	for atomic_entry: Dictionary in document.lexemes:
		if atomic_entry.morphology.kind != "atomic":
			continue
		atomic_count += 1
		word.id = atomic_entry.id
		word.text = atomic_entry.text
		word.morphology = atomic_entry.morphology.duplicate(true)
		word.practice_modes = atomic_entry.practice_modes.duplicate()
		check(view.configure([word], 3, Data.theme("spring"), data.chests, false, 42), "Actual atomic graph configures with explicitly synthetic fixture media: " + word.text)
		view.set_process(false)
		view.game.spawn_interval = 10000.0
		view.game.cells.clear()
		var whole: Dictionary = view.game._new_composition_tile(view.game._morphology.source_tiles(atomic_entry.morphology.id)[0])
		whole.column = 0
		whole.row = view.game.ROWS - int(whole.height)
		view.game.cells.append(whole)
		var picture: Dictionary = view.game._new_picture_tile(word)
		picture.column = 1
		picture.row = view.game.ROWS - 1
		view.game.cells.append(picture)
		view._sync_tiles()
		view._layout()
		_advance(view, 1.0)
		requests.clear()
		taps.clear()
		attempts.clear()
		view.credit_collection = func(_id: String, _coins: int) -> Dictionary: return {"ok": true}
		check(not view.game.collect(int(whole.id)) and requests.is_empty() and taps.is_empty(), "An atomic text alone cannot collect or pronounce through collection: " + word.text)
		check(view.game.try_merge(int(whole.id), int(picture.id)) == "merged", "An atomic Foundation01 text pairs with its picture: " + word.text)
		var merged_id: int = int(view.game.fusions[0].result.id)
		check(requests.size() == 1 and requests[0].id == word.id and taps.is_empty() and attempts.is_empty(), "Atomic picture matching pronounces once and defers mastery until collection: " + word.text)
		_advance(view, view.game.FUSION_SECONDS + view.game.SETTLE_SECONDS + 0.05)
		check(view.game.collect(merged_id), "The matched atomic word collects through the actual view: " + word.text)
		check(taps.size() == 1 and taps[0].id == word.id and taps[0].audio == word.audio, "Deliberate atomic collection requests its exact whole-word fixture payload: " + word.text)
		_advance(view, 1.0)
		check(requests.size() == 1 and taps.size() == 1 and attempts.size() == 1 and bool(attempts[0][2]), "Manual picture matching earns one learning credit only when collected: " + word.text)
	check(atomic_count == 16, "All sixteen intact units retain the real view's picture-match, speech and collection boundaries")
	view.credit_collection = Callable()
	view.queue_free()
