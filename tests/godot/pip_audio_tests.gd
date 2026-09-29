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
	await _check_bundled_greetings()
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
		audio.stop_voice()
		audio.play_pip()
		var path: String = audio.voice.stream.resource_path if audio.voice.stream != null else ""
		valid = valid and audio.voice.playing and PIP_PATHS.has(path)
		repeating = repeating or path == previous
		stacked = stacked or audio.effect.playing or audio.narration.playing or audio.get_children() != players
		seen[path] = true
		previous = path
		var state: int = audio._pip_rng.state
		var request: int = audio._playback_requests.get(audio.voice, 0)
		for repeated in range(4): audio.play_pip()
		check(audio.is_pip_busy() and audio._pip_rng.state == state
			and audio._playback_requests.get(audio.voice, 0) == request and audio.voice.stream.resource_path == path,
			"Repeated audio requests preserve the playing recording, request and random choice")
	check(valid and seen.size() == PIP_PATHS.size(), "Successive completed Pip greetings play every supplied sound on the voice channel")
	check(not repeating, "Consecutive Pip greetings never choose the same clip")
	check(not stacked, "Pip greetings never stack effect, narration or player nodes")
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


func _check_bundled_greetings() -> void:
	var audio = load("res://scripts/game_audio.gd").new()
	root.add_child(audio)
	audio.interact("spring", false)
	audio.play_pip()
	check(audio.is_pip_busy() and audio.voice.playing,
		"The first greeting starts immediately from the game pack")
	var state: int = audio._pip_rng.state
	var request: int = audio._playback_requests.get(audio.voice, 0)
	for repeated in range(5): audio.play_pip()
	check(audio._pip_rng.state == state and audio._playback_requests.get(audio.voice, 0) == request,
		"Repeated taps do not queue or replace an active greeting")
	await create_timer(audio.voice.stream.get_length() + 0.2).timeout
	check(not audio.is_pip_busy() and not audio.voice.playing,
		"The real recording's end releases the greeting gate")
	audio.play_pip()
	check(audio.is_pip_busy() and audio.voice.playing, "The next deliberate greeting is immediately available")
	audio.halt()
	check(not audio.is_pip_busy() and not audio.voice.playing, "Halting releases the greeting immediately")
	await process_frame
	check(not audio.voice.playing, "No delayed audio can revive a halted greeting")
	audio.interact("winter", false)
	audio.play_pip()
	audio.say("res://assets/audio/voice/word-duck.wav")
	check(not audio.is_pip_busy() and audio.voice.playing,
		"A different pronunciation releases the old Pip owner on the shared voice channel")
	audio.halt()
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
	for blocked in ["swipe", "paused"]:
		app.audio.halt()
		state = app.audio._pip_rng.state
		event_count = interactions.size()
		app._collection_dragged = blocked == "swipe"
		playground.pause(blocked == "paused")
		app.duck.pressed.emit()
		check(not app.audio.voice.playing and app.audio._pip_rng.state == state and interactions.size() == event_count,
			"A " + blocked + " Home interaction cannot leak a Pip greeting")
	app._collection_dragged = false
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
	check(app.audio.active and app.audio.music.playing and not app.audio.voice.playing
		and not app.audio.narration.playing and not app.audio.effect.playing,
		"Returning to the page restores background music without replaying a stale greeting")
	await _check_serialized_routes(app)
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


func _check_serialized_routes(app) -> void:
	var cached: Dictionary = app.audio.cache.duplicate()
	for in_home in [false, true]:
		if in_home: app._show_collection()
		else: app._hide_collection()
		await _settle()
		app._update_duck()
		var context := "Home" if in_home else "Header"
		for sound_outlasts_motion in [false, true]:
			app.audio.halt()
			app.duck.settle()
			app.set_reduced_motion(false)
			for path in PIP_PATHS:
				app.audio.cache[path] = _silence(1.5 if sound_outlasts_motion else 0.1)
			var before: int = _voice_requests(app)
			app.duck.pressed.emit()
			app.duck.set_process(false)
			check(app.audio.is_pip_busy() and app.duck.is_manual_action_busy(),
				context + " activation starts both the action and its greeting")
			var caption: String = app._status_announcement
			var index: int = app._duck_trick_index
			var rng: int = app.audio._pip_rng.state
			for repeated in range(4): app.duck.pressed.emit()
			await _tap(app.duck.get_global_rect().get_center())
			check(_voice_requests(app) == before + 1 and app.audio._pip_rng.state == rng
				and app._status_announcement == caption and app._duck_trick_index == index,
				context + " repeated button and pointer activations do not restart audio, advance actions or change feedback")
			if sound_outlasts_motion:
				app.duck._process(4.0)
				app.duck.set_process(false)
				check(not app.duck.is_manual_action_busy() and app.audio.is_pip_busy(),
					context + " test reaches finished motion while the longer real audio is still playing")
			else:
				await _wait_for_voice(app.audio)
				check(app.duck.is_manual_action_busy() and not app.audio.is_pip_busy(),
					context + " test reaches finished audio while its longer motion is still running")
			app.duck.pressed.emit()
			await _tap(app.duck.get_global_rect().get_center())
			check(_voice_requests(app) == before + 1 and app._status_announcement == caption
				and app._duck_trick_index == index,
				context + " continues rejecting taps until both motion and sound have finished")
			app.duck._process(4.0)
			app.duck.set_process(false)
			await _wait_for_voice(app.audio)
			check(not app.duck.is_manual_action_busy() and not app.audio.is_pip_busy()
				and _voice_requests(app) == before + 1,
				context + " becomes idle without replaying any ignored tap")
			app.duck.pressed.emit()
			check(_voice_requests(app) == before + 2,
				context + " accepts the next deliberate gesture after both channels finish")
		app.audio.halt()
		app.duck.settle()
		app.set_reduced_motion(true)
		for path in PIP_PATHS: app.audio.cache[path] = _silence(0.2)
		var before: int = _voice_requests(app)
		app.duck.pressed.emit()
		app.duck.pressed.emit()
		check(not app.duck.is_manual_action_busy() and app.audio.is_pip_busy() and _voice_requests(app) == before + 1,
			context + " reduced motion keeps a static pose while its real greeting blocks repeats")
		await _wait_for_voice(app.audio)
		app.duck.pressed.emit()
		check(_voice_requests(app) == before + 2,
			context + " static reduced-motion artwork does not lock input after sound completion")
		app.on_page_hidden()
		check(not app.audio.is_pip_busy() and not app.duck.is_manual_action_busy(),
			context + " background cleanup cancels both manual action owners")
		app.on_page_visible()
		await _settle()
		before = _voice_requests(app)
		app.duck.pressed.emit()
		check(_voice_requests(app) == before + 1,
			context + " accepts a new gesture after foreground recovery")
		app.audio.halt()
		app.duck.settle()
		app.audio.available = false
		app.duck.pressed.emit()
		check(not app.audio.is_pip_busy() and not app.audio.voice.playing,
			context + " unavailable audio cannot leave a phantom sound owner")
		var unavailable_caption: String = app._status_announcement
		app.duck.pressed.emit()
		check(app._status_announcement != unavailable_caption,
			context + " remains usable with static reduced-motion feedback and unavailable audio")
		app.audio.available = true
		app.audio.halt()
		app.duck.settle()
	app.audio.cache = cached
	app._hide_collection()
	app.set_reduced_motion(true)
	app._update_duck()


func _silence(seconds: float) -> AudioStreamWAV:
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(int(seconds * clip.mix_rate) * 2)
	data.fill(0)
	clip.data = data
	return clip


func _wait_for_voice(audio) -> void:
	for attempt in range(60):
		if not audio.voice.playing: break
		await create_timer(0.05).timeout
	check(not audio.voice.playing and not audio.is_pip_busy(), "The real AudioStreamPlayer completion releases Pip's audio owner")


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
