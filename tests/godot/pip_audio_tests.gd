extends SceneTree

const PIP_PATHS := [
	"res://assets/audio/pip/duck_double_01_bouncy.wav",
	"res://assets/audio/pip/duck_double_03_derpy.wav",
	"res://assets/audio/pip/duck_quack_innocent_deep_short_04.wav",
]

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	await _check_audio_selection()
	await _check_click_routes()
	print("Pip audio: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_audio_selection() -> void:
	var audio = load("res://scripts/game_audio.gd").new()
	root.add_child(audio)
	check(audio.PIP_SOUND_PATHS == PIP_PATHS, "Pip's random pool contains exactly the three supplied duck sounds")
	for path in PIP_PATHS:
		var clip: Resource = load(path)
		check(clip is AudioStreamWAV and clip.get_length() > 0.05,
			"The imported Pip clip is a playable nonempty WAV: " + path.get_file())
	var players: Array[Node] = audio.get_children()
	check(players.size() == 4 and players.all(func(player: Node) -> bool: return player is AudioStreamPlayer),
		"Pip uses the existing audio channels without adding a parallel playback stack")
	audio._pip_rng.seed = 20260920
	seed(41872)
	var expected_global: int = randi()
	seed(41872)
	var slice_state: int = audio._pop_slice_rng.state
	audio.next_pip_sound()
	check(randi() == expected_global and audio._pop_slice_rng.state == slice_state,
		"Choosing a duck sound does not advance gameplay or fruit-slice randomness")
	audio.interact("spring", false)
	var seen: Dictionary = {}
	var previous: String = audio._last_pip_path
	var valid := true
	var repeating := false
	var stacked := false
	for index in range(32):
		audio.play_pip()
		var path: String = audio.voice.stream.resource_path if audio.voice.stream != null else ""
		valid = valid and audio.voice.playing and PIP_PATHS.has(path)
		repeating = repeating or path == previous
		stacked = stacked or audio.effect.playing or audio.narration.playing or audio.get_children() != players
		seen[path] = true
		previous = path
	check(valid and seen.size() == PIP_PATHS.size(), "Repeated Pip taps actually play every supplied sound on the voice channel")
	check(not repeating, "Consecutive Pip greetings never choose the same clip")
	check(not stacked, "Rapid Pip taps replace the greeting without stacking effect, narration or player nodes")
	for blocked in ["inactive", "muted", "unavailable"]:
		audio.halt()
		audio.muted = blocked == "muted"
		audio.available = blocked != "unavailable"
		audio.active = blocked != "inactive"
		var state: int = audio._pip_rng.state
		var last: String = audio._last_pip_path
		audio.play_pip()
		check(not audio.voice.playing and audio._pip_rng.state == state and audio._last_pip_path == last,
			"An " + blocked + " Pip greeting stays silent and preserves the last audible choice")
	audio.available = true
	audio.set_muted(false)
	check(not audio.voice.playing, "Unmuting never replays a greeting the player tapped while muted")
	audio.interact("spring", false)
	audio.play_pip()
	audio.set_muted(true)
	check(not audio.voice.playing and not audio.active, "Mute immediately stops an active imported duck greeting")
	audio.queue_free()
	await process_frame


func _check_click_routes() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(480, 900)
	var directory := "user://pip-audio-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	app._mode_id = "match"
	root.add_child(app)
	await _settle()
	app.set_reduced_motion(true)
	app.audio.halt()
	app.medal_progress.counts["spring-1"] = 1
	app._refresh_collection()
	var saved: Dictionary = _saved_files(directory)
	var progress: Array = _progress(app)
	var players: Array[Node] = app.audio.get_children()
	app._update_duck()
	var before: int = _voice_requests(app)
	await _tap(app.duck.get_global_rect().get_center())
	_check_greeting(app, before, "A real header mouse click")
	for guard in ["_voice_mode", "_pop_speech_active"]:
		app.audio.halt()
		var state: int = app.audio._pip_rng.state
		app.set(guard, true)
		app.duck.pressed.emit()
		check(not app.audio.voice.playing and app.audio._pip_rng.state == state,
			"Pip stays silent while " + guard + " owns the microphone")
		app.set(guard, false)
	app._show_collection()
	app._collection_scroll.scroll_vertical = 0
	await _settle()
	app._update_duck()
	var playground = app._room.playground
	var interactions: Array[String] = []
	playground.interaction.connect(func(kind: String, _message: String) -> void: interactions.append(kind))
	for method in ["mouse", "touch"]:
		playground.cancel()
		app.audio.halt()
		before = _voice_requests(app)
		var events_before: int = interactions.size()
		await _tap(app.duck.get_global_rect().get_center(), method)
		_check_greeting(app, before, "A real Home " + method + " poke")
		check(interactions.slice(events_before) == ["poke"],
			"A Home " + method + " poke emits once without duplicate emulated mouse feedback")
		app.audio.halt()
		before = _voice_requests(app)
		events_before = interactions.size()
		var center: Vector2 = app.duck.get_global_rect().get_center()
		await _button(center - Vector2(22, 0), true, method)
		await _motion(center + Vector2(26, 0), Vector2(48, 0), method)
		await _button(center + Vector2(26, 0), false, method)
		_check_greeting(app, before, "A real Home " + method + " pet")
		check(interactions.slice(events_before) == ["pet"],
			"A Home " + method + " pet emits one greeting after the stroke")
	app.audio.halt()
	before = _voice_requests(app)
	app.duck.pressed.emit()
	_check_greeting(app, before, "Keyboard or controller activation of the Home Pip button")
	app.audio.set_muted(true)
	var state: int = app.audio._pip_rng.state
	var event_count: int = interactions.size()
	app.duck.pressed.emit()
	check(not app.audio.voice.playing and app.audio._pip_rng.state == state and interactions.size() == event_count + 1,
		"Muted Home pokes retain their visual response without drawing or playing a greeting")
	app.audio.set_muted(false)
	for blocked in ["swipe", "inertia", "paused"]:
		app.audio.halt()
		state = app.audio._pip_rng.state
		event_count = interactions.size()
		app._collection_dragged = blocked == "swipe"
		app._collection_velocity = Vector2(20, 0) if blocked == "inertia" else Vector2.ZERO
		playground.pause(blocked == "paused")
		app.duck.pressed.emit()
		check(not app.audio.voice.playing and app.audio._pip_rng.state == state and interactions.size() == event_count,
			"A " + blocked + " Home interaction cannot leak a Pip greeting")
	app._collection_dragged = false
	app._collection_velocity = Vector2.ZERO
	playground.pause(false)
	app._hide_collection()
	app.audio.halt()
	state = app.audio._pip_rng.state
	playground.poke()
	check(not app.audio.voice.playing and app.audio._pip_rng.state == state,
		"The hidden Home cannot greet during gameplay")
	app.duck.pressed.emit()
	app.on_page_hidden()
	check(not app.audio.voice.playing and not app.audio.narration.playing and not app.audio.active,
		"Backgrounding the page stops the imported Pip greeting")
	app.on_page_visible()
	await _settle()
	check(not app.audio.voice.playing and not app.audio.active,
		"Returning to the page does not restart a stale greeting")
	check(app.audio.get_children() == players, "All native Pip click routes keep the same four audio players")
	check(_progress(app) == progress, "Pip sounds leave the lesson, cards, medals, toys, backdrop and reward goal unchanged")
	check(_saved_files(directory) == saved, "Pip greetings do not write or alter any saved progress")
	app.audio.halt()
	await create_timer(0.1).timeout
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)


func _check_greeting(app, before: int, context: String) -> void:
	var path: String = app.audio.voice.stream.resource_path if app.audio.voice.stream != null else ""
	check(app.audio.voice.playing and PIP_PATHS.has(path), context + " plays an imported duck sound")
	check(_voice_requests(app) == before + 1, context + " starts exactly one greeting")
	app._update_duck()
	check(app.duck.speaking, context + " opens Pip's beak with the real audio")


func _voice_requests(app) -> int:
	return app.audio._playback_requests.get(app.audio.voice, 0)


func _progress(app) -> Array:
	var state = app.playroom_state
	return [app.model.phase, app.model.successes, app.model.mistakes, app.model.hints_remaining,
		app.model.cards.duplicate(true), app.model.lesson_words.duplicate(true), app.medal_progress.counts.duplicate(true),
		state.toy_id, state.backdrop_id, state.favorite_id, state.goal_item_id, state.recent_topic_ids.duplicate(),
		state.collected_word_ids.duplicate(), state.displayed_word_id]


func _saved_files(directory: String) -> Dictionary:
	var result: Dictionary = {}
	for filename in DirAccess.get_files_at(directory):
		result[filename] = FileAccess.get_file_as_bytes(directory + "/" + filename)
	return result


func _settle() -> void:
	await process_frame
	await process_frame


func _tap(point: Vector2, method: String = "mouse") -> void:
	if method == "mouse":
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		root.push_input(motion, true)
		await process_frame
	await _button(point, true, method)
	await _button(point, false, method)


func _button(point: Vector2, pressed: bool, method: String) -> void:
	if method == "touch":
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	else:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame


func _motion(point: Vector2, relative: Vector2, method: String) -> void:
	if method == "touch":
		var event := InputEventScreenDrag.new()
		event.index = 0
		event.position = point
		event.relative = relative
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	else:
		var event := InputEventMouseMotion.new()
		event.position = point
		event.global_position = point
		event.relative = relative
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(event, true)
	await process_frame
