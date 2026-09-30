extends SceneTree

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
	var directory := "user://ui-audio-flow-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/playroom.cfg"
	preload("res://tests/godot/player_flow_fixture.gd").install(app, directory)
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_reduced_motion(true)
	app.choose_mode("memory")
	await process_frame
	await process_frame
	var memory_card: Button = app._memory.card_buttons[0]
	memory_card.pressed.emit()
	check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + app._memory.memory.cards[0].word.audio),
		"Revealing a Memory card pronounces its displayed word")
	memory_card.pressed.emit()
	check(not app.audio.voice.playing, "Concealing the selected Memory card stops its pronunciation")
	memory_card.pressed.emit()
	memory_card.grab_focus()
	app._show_collection()
	check(not app._focus_candidates().has(memory_card) and not app.audio.voice.playing,
		"The covered Memory card stays outside modal focus and pronunciation")
	app._hide_collection()
	check(root.gui_get_focus_owner() == memory_card and app._valid_focus(memory_card),
		"Returning from More restores focus to the same playable Memory card")
	app.choose_mode("match")
	check(not app.audio.voice.playing, "Changing game mode stops the prior card's pronunciation")
	var first: Dictionary = app.model.cards.filter(func(card: Dictionary) -> bool:
		return card.kind == "word" and not app.model.card_by_id(card.word.id + ":image").is_empty())[0]
	var other: Dictionary = app.model.cards.filter(func(card: Dictionary) -> bool: return card.kind == "image" and card.word.id != first.word.id)[0]
	app._select_card(first.id)
	check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + first.word.audio),
		"Selecting a Match word pronounces that exact card")
	app._select_card(other.id)
	check(app.model.phase == "feedback" and app.audio.voice.playing
		and app.audio.voice.stream == load("res://assets/audio/voice/wrong.wav"),
		"Wrong Match gives its existing audio cue while the chosen cards show the feedback")
	app._controller_back()
	check(not app.audio.voice.playing, "Back stops answer speech when returning to the board")
	app._select_card(first.id)
	app._select_card(first.word.id + ":image")
	var progress: Array = _match_progress(app)
	for id in [first.id, first.word.id + ":image"]:
		check(not app.cards[id].disabled, "Either completed Match card remains a real replay button")
		app.audio.stop_voice()
		app.cards[id].pressed.emit()
		check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + first.word.audio),
			"A completed " + id + " replays the matched word's actual pronunciation")
		check(_match_progress(app) == progress, "Matched-card pronunciation never changes scoring, hints, selection, or rewards")
	app.cards[first.id].grab_focus()
	app._show_collection()
	app.cards[first.id].pressed.emit()
	check(not app.audio.voice.playing and _match_progress(app) == progress
		and not app._focus_candidates().has(app.cards[first.id]),
		"A matched card cannot pronounce or change progress behind More")
	app._hide_collection()
	check(root.gui_get_focus_owner() == app.cards[first.id] and app._valid_focus(app.cards[first.id]),
		"Returning from More restores the matched card's ordinary replay focus")
	app._controller_back()
	var matched_picture: Button = app.cards[first.word.id + ":image"]
	progress = _match_progress(app)
	app.audio.set_muted(true)
	await _tap_control(matched_picture)
	check(root.gui_get_focus_owner() == matched_picture and not app.audio.voice.playing,
		"A real pointer tap can focus a muted matched picture without pretending to pronounce: expected=%s focus=%s rect=%s voice_playing=%s" % [
			matched_picture, root.gui_get_focus_owner(), matched_picture.get_global_rect(), app.audio.voice.playing])
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame
	check(_match_progress(app) == progress and not app.audio.voice.playing,
		"Pointer and Enter replay on a completed card cannot select it, spend hints, or duplicate progress")
	app.audio.set_muted(false)
	app.cards[other.id].pressed.emit()
	progress = _match_progress(app)
	app.cards[first.id].pressed.emit()
	check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + first.word.audio)
		and _match_progress(app) == progress,
		"Matched replay replaces another pronunciation without cancelling the selected unmatched card")
	app._on_voice_state([true, true, "Listening"])
	progress = _match_progress(app)
	app.cards[first.id].pressed.emit()
	check(not app.audio.voice.playing and not app.audio.music.playing and _match_progress(app) == progress,
		"Voice recognition's quiet guard also blocks matched-card replay")
	app._stop_voice()
	app.new_round(21, true)
	for card in app.model.cards:
		if card.kind == "word" and not app.model.card_by_id(card.word.id + ":image").is_empty():
			app.cards[card.id].pressed.emit()
			app.cards[card.word.id + ":image"].pressed.emit()
			app._continue_match()
	progress = _match_progress(app)
	for id in app.model.matched_ids:
		app.cards[id].pressed.emit()
	check(app.model.phase == "won" and not app.audio.voice.playing and _match_progress(app) == progress,
		"Hidden matched cards cannot replay or score behind the result")
	app.choose_mode("memory")
	var memory = app._memory
	var a: int = 0
	var b: int = -1
	for index in range(1, memory.memory.cards.size()):
		if memory.memory.cards[index].kind != memory.memory.cards[a].kind and memory.memory.cards[index].word.id != memory.memory.cards[a].word.id:
			b = index
			break
	memory._choose(a)
	memory._choose(b)
	var visible_word: Dictionary = memory.memory.cards[b].word
	check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + visible_word.audio)
		and memory.memory.is_revealed(b),
		"Memory pronounces the second revealed card instead of a removed correction panel")
	await create_timer(0.8).timeout
	check(memory.memory.phase == "waiting" and not app.audio.voice.playing
		and not memory.memory.is_revealed(a) and not memory.memory.is_revealed(b),
		"Automatic Memory continuation stops speech as unmatched pictures turn back")
	memory.card_buttons[a].pressed.emit()
	memory.card_buttons[b].pressed.emit()
	var next_card := -1
	for index in range(memory.memory.cards.size()):
		if memory.memory.cards[index].word.id != memory.memory.cards[a].word.id and memory.memory.cards[index].word.id != memory.memory.cards[b].word.id:
			next_card = index
			break
	var attempts: int = memory.memory.attempts
	check(app.audio.voice.playing, "The previous Memory card's speech is active before the shortcut")
	memory.card_buttons[next_card].pressed.emit()
	check(memory.memory.phase == "matching" and memory.memory.selected_indices == [next_card]
		and memory.memory.attempts == attempts and memory.memory.feedback_words.is_empty(),
		"Memory first-tap shortcut selects exactly the new card without another attempt")
	check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + memory.memory.cards[next_card].word.audio),
		"Memory first-tap shortcut replaces old feedback speech with the tapped card's actual word")
	app.choose_mode("match")
	app.choose_mode("memory")
	memory = app._memory
	a = 0
	for index in range(1, memory.memory.cards.size()):
		if memory.memory.cards[index].kind != memory.memory.cards[a].kind and memory.memory.cards[index].word.id != memory.memory.cards[a].word.id:
			b = index
			break
	memory.card_buttons[a].pressed.emit()
	memory.card_buttons[b].pressed.emit()
	check(app.audio.voice.playing, "The revealed Memory card's speech is active before a peek")
	memory.study_button.button_down.emit()
	check(memory.memory.studying and memory.memory.phase == "waiting" and not app.audio.voice.playing
		and memory.memory.attempts == 1,
		"Holding the eye stops feedback speech and preserves the existing attempt")
	memory.study_button.button_up.emit()
	check(not memory.memory.studying and memory.memory.phase == "waiting" and not app.audio.voice.playing and memory.memory.attempts == 1,
		"Releasing the eye stays silent and preserves progress")
	app.choose_mode("match")
	app.cards[app.model.cards[0].id].pressed.emit()
	app._show_collection()
	check(not app.audio.voice.playing, "Opening rewards stops speech about a now-covered picture")
	app.medal_progress.counts["spring-1"] = 3
	app._refresh_collection()
	app._select_room_item("toy-ball")
	app._room.toy_button.pressed.emit()
	check(app.audio.voice.playing, "The current room toy pronounces its word")
	app._room.item_buttons["toy-spring"].pressed.emit()
	check(app._room._toy.word_id == "flower" and app._room._stage == 1 and app.audio.voice.playing
		and app.audio.voice.stream == load("res://assets/audio/voice/word-flower.wav"),
		"The first tap on an owned floor toy replaces the previous word with its own pronunciation and action")
	app._room.toy_button.pressed.emit()
	check(app.audio.voice.playing, "The replacement toy can pronounce its word")
	app._hide_collection()
	check(not app.audio.voice.playing, "Leaving the room stops the hidden toy's word")
	app.choose_mode("match")
	for exit_path in ["stop", "speech_end", "rewards", "hidden"]:
		app.new_round(21, true)
		app._on_voice_state([true, true, "Listening"])
		var word: String = ""
		for card in app.model.cards:
			if card.kind == "word" and not app.model.card_by_id(card.word.id + ":image").is_empty():
				word = card.word.text
				break
		app._on_voice_result([word, true])
		check(app.model.phase == "feedback" and not app.feedback_timer.is_stopped(), "Voice feedback initially has its automatic timer")
		var next_id: String = ""
		for id in app.cards:
			if not app.model.matched_ids.has(id):
				next_id = id
				break
		app.cards[next_id].pressed.emit()
		check(app.cards[next_id].disabled and app.model.phase == "feedback" and app.model.successes == 1,
			"Card input cannot skip automatic voice feedback")
		match exit_path:
			"stop": app._stop_voice()
			"speech_end": app._on_voice_state([false, false, "Stopped"])
			"rewards": app._show_collection()
			"hidden": app.on_page_hidden()
		check(not app.feedback_timer.is_stopped(), exit_path + " retains the pending automatic feedback transition")
		if exit_path in ["rewards", "hidden"]:
			check(app.feedback_timer.paused, exit_path + " pauses the pending transition while play is covered")
			await create_timer(0.8).timeout
			check(app.model.phase == "feedback" and app.model.successes == 1,
				exit_path + " cannot advance a covered board")
			if exit_path == "rewards":
				app._hide_collection()
			else:
				app.on_page_visible()
		check(not app.feedback_timer.paused, exit_path + " resumes automatic progress without a footer action")
		check(not app.cards[next_id].disabled, exit_path + " immediately restores card input without another refresh")
		await create_timer(0.8).timeout
		check(app.model.phase == "waiting" and app.model.successes == 1 and app.feedback_timer.is_stopped(),
			exit_path + " automatically clears feedback exactly once")
		app.cards[next_id].pressed.emit()
		check(app.model.phase == "matching" and app.model.selected_id == next_id,
			"The first tap after automatic progress selects the actual tapped card")
		app.new_round(21, true)
		app._on_voice_state([true, true, "Listening"])
		app._on_voice_result([word, true])
		app._stop_voice()
		app.cards[next_id].pressed.emit()
		check(app.model.phase == "matching" and app.model.selected_id == next_id
			and app.model.successes == 1 and app.feedback_timer.is_stopped(),
			"Stopping Voice also permits the immediate next-card shortcut before its timer expires")
	_check_pop_launch_audio(app)
	await _check_pop_hit_audio(app)
	await _check_pop_exit_audio(app)
	app.audio.halt()
	_check_pop_slice_choices()
	app.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("UI audio flow: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_pop_launch_audio(app) -> void:
	app.new_round(84, true, "", "pop")
	preload("res://tests/godot/player_flow_fixture.gd").choose_pop_player(app)
	var view = app._pop
	view.set_process(false)
	var launches: Array[int] = []
	var record_launch := func(uid: int) -> void: launches.append(uid)
	view.launched.connect(record_launch)
	app._on_voice_state([true, false, "Opening microphone..."])
	check(launches.is_empty() and not app.audio.pop_launch.playing,
		"Waiting for microphone permission cannot throw a word or play a launch")
	app._on_voice_state([true, true, "Listening."])
	var player: AudioStreamPlayer = app.audio.pop_launch
	check(launches == [1] and player.playing and player.stream != null,
		"The first visible word plays its launch as soon as listening starts")
	check(not app.audio.music.playing and not app.audio.voice.playing and not app.audio.effect.playing,
		"Throwing a word does not start background music, a prompt, or a button sound")
	var request: int = app.audio._playback_requests[player]
	app._on_voice_state([true, true, "Listening."])
	view.snapshot()
	view._layout()
	view.set_reduced_motion(true)
	view.set_reduced_motion(false)
	check(launches == [1] and app.audio._playback_requests[player] == request,
		"Repeated listening state, layout, snapshots and motion preferences never replay a throw")
	view._advance_game(2.15)
	check(launches == [1, 2] and app.audio._playback_requests[player] == request + 1,
		"The next real target has exactly one separate launch cue")
	request = app.audio._playback_requests[player]
	view.receive_transcript(view.game.targets[0].word.text)
	check(app.audio.last_pop_player().playing and player.playing
		and app.audio._playback_requests[player] == request,
		"A hit keeps the launch tail and slice on separate audio channels")
	app._on_voice_state([true, false, "Listening paused. Continuing..."])
	app._on_voice_state([true, true, "Listening."])
	check(launches == [1, 2] and app.audio._playback_requests[player] == request,
		"Recognizer rollover cannot replay an existing target's launch")
	app._on_voice_state([true, false, "Speech network error. Tap Retry."])
	check(not player.playing and player.stream == null,
		"An actual speech error stops an in-flight launch immediately")
	app._on_voice_state([true, true, "Listening."])
	check(launches == [1, 2] and not player.playing,
		"Retrying a paused round never replays the cleared launch")
	app.new_round(85, true, "", "pop")
	preload("res://tests/godot/player_flow_fixture.gd").choose_pop_player(app)
	view.set_process(false)
	launches.clear()
	app._on_voice_state([true, true, "Listening."])
	request = app.audio._playback_requests[player]
	view._advance_game(3.0)
	view._advance_game(0.01)
	check(launches == [1] and view.game.targets.size() == 2
		and app.audio._playback_requests[player] == request,
		"A long frame never catches up an older target's missed launch sound")
	for transition in ["home", "hidden", "mode_exit", "mute", "finish"]:
		app.new_round(86, true, "", "pop")
		preload("res://tests/godot/player_flow_fixture.gd").choose_pop_player(app)
		view.set_process(false)
		app._on_voice_state([true, true, "Listening."])
		check(player.playing, transition + " starts during an audible throw")
		match transition:
			"home": app._show_collection()
			"hidden": app.on_page_hidden()
			"mode_exit": app.choose_mode("match")
			"mute": app.audio.set_muted(true)
			"finish": view._advance_game(view.game.remaining)
		check(not player.playing and player.stream == null,
			transition + " stops and clears the launch sound")
		if transition == "home": app._hide_collection()
		elif transition == "hidden": app.on_page_visible()
		elif transition == "mute": app.audio.set_muted(false)
		check(not player.playing, transition + " cannot replay a previous throw on return")
	view.launched.disconnect(record_launch)
	app.choose_mode("match")


func _check_pop_hit_audio(app) -> void:
	app.choose_mode("pop")
	preload("res://tests/godot/player_flow_fixture.gd").choose_pop_player(app)
	app.audio.set_muted(false)
	await process_frame
	app._on_voice_state([true, true, "Listening. Say an English word."])
	var channel_count: int = app.audio.get_child_count()
	var expected_paths: Array[String] = app.audio._pop_slice_paths.duplicate()
	if expected_paths.is_empty():
		expected_paths.append(_slice_fallback())
	check(_pop_hit_visible_word(app, 3.0) and _pop_playing(app.audio) == 1
		and expected_paths.has(_last_slice_path(app.audio)),
		"A real spoken target plays one selected reference slice, or the clean-checkout fallback")
	var first_player: AudioStreamPlayer = app.audio.last_pop_player()
	var first_path: String = _last_slice_path(app.audio)
	check(not app.audio.music.playing and not app.audio.voice.playing
		and not app.audio.effect.playing,
		"Popping a target uses its dedicated slice voice without BGM, UI clicks or word/report speech")
	check(_pop_hit_visible_word(app) and _pop_playing(app.audio) == 2
		and expected_paths.has(_last_slice_path(app.audio))
		and (expected_paths.size() < 2 or _last_slice_path(app.audio) != first_path)
		and app.audio.last_pop_player() != first_player and first_player.playing
		and app.audio.get_child_count() == channel_count,
		"Consecutive real targets preserve the previous slice tail on separate bounded voices")
	var last_path: String = app.audio._last_pop_slice_path
	var random_state: int = app.audio._pop_slice_rng.state
	app.audio.set_muted(true)
	check(_pop_playing(app.audio) == 0 and not app.audio.active, "Muting immediately stops every active Voice Pop slice")
	check(_pop_hit_visible_word(app, 1.8) and _pop_playing(app.audio) == 0 and not app.audio.active
		and app.audio._last_pop_slice_path == last_path and app.audio._pop_slice_rng.state == random_state,
		"A muted spoken hit still scores without playing or consuming a random slice")
	app.audio.set_muted(false)
	check(_pop_hit_visible_word(app, 2.2) and _pop_playing(app.audio) == 1
		and expected_paths.has(_last_slice_path(app.audio))
		and (expected_paths.size() < 2 or _last_slice_path(app.audio) != last_path),
		"The next unmuted spoken hit resumes the pool without repeating the last audible slice")
	app.choose_mode("match")
	check(_pop_playing(app.audio) == 0, "Leaving Voice Pop stops all active hit sounds")
	app.choose_mode("pop")
	preload("res://tests/godot/player_flow_fixture.gd").choose_pop_player(app)
	await process_frame
	app._on_voice_state([true, true, "Listening. Say an English word."])
	check(_pop_hit_visible_word(app, 3.0) and _pop_playing(app.audio) == 1, "A new Pop round can start a fresh hit sound")
	var hits_before_hide: int = app._pop.game.hits
	app.on_page_hidden()
	check(_pop_playing(app.audio) == 0 and not app.audio.active and not _pop_hit_visible_word(app)
		and app._pop.game.hits == hits_before_hide,
		"Backgrounding stops the slice and ignores a late word for a remaining target")
	app.on_page_visible()
	check(_pop_playing(app.audio) == 0 and not app.audio.active and not _pop_hit_visible_word(app)
		and app._pop.game.hits == hits_before_hide,
		"Returning to the page cannot replay an old slice or accept words before listening resumes")


func _check_pop_exit_audio(app) -> void:
	for destination in ["match", "memory"]:
		for state in ["pending", "listening", "denied", "report", "muted"]:
			app.choose_mode("pop")
			preload("res://tests/godot/player_flow_fixture.gd").choose_pop_player(app)
			app._pop.set_process(false)
			if state in ["listening", "report", "muted"]:
				app._on_voice_state([true, true, "Listening."])
			elif state == "denied":
				app._on_voice_state([true, false, "Microphone permission was denied."])
			if state == "report":
				app._pop._advance_game(app._pop.game.remaining)
			if state == "muted":
				app.audio.set_muted(true)
			app.choose_mode(destination)
			var label: String = "Leaving %s Voice Pop for %s" % [state, destination]
			check(app._mode_id == destination and not app._voice_mode and not app._pop_speech_active,
				label + " clears microphone input and quiet-mode guards")
			check(not app.audio.voice.playing and not app.audio.effect.playing
				and _pop_playing(app.audio) == 0,
				label + " cannot carry over an old word, hit or report")
			check(app.audio.muted == (state == "muted") and app.audio.active == (state != "muted")
				and app.audio.music.playing == (state != "muted"),
				label + " restores background music immediately while preserving the mute choice")
			var word: Dictionary
			if destination == "match":
				word = app.model.cards[0].word
				app.cards[app.model.cards[0].id].pressed.emit()
			else:
				word = app._memory.memory.cards[0].word
				app._memory.card_buttons[0].pressed.emit()
			check(app.audio.voice.playing == (state != "muted") and app.audio.effect.playing == (state != "muted"),
				label + " permits the new card's pronunciation and selection sound unless muted")
			if state != "muted":
				check(app.audio.voice.stream == load("res://" + word.audio),
					label + " pronounces the destination card's exact word")
			app.audio.set_muted(false)
			app._pop.set_process(true)
	app.choose_mode("pop")
	preload("res://tests/godot/player_flow_fixture.gd").choose_pop_player(app)
	app.on_page_hidden()
	app.choose_mode("match")
	check(not app.audio.active and not app.audio.music.playing,
		"A mode change delivered to a hidden page cannot restore background audio")
	app.on_page_visible()
	await process_frame


func _slice_fallback() -> String:
	var previous := "res://assets/imported-audio/pop-slice.wav"
	return previous if ResourceLoader.exists(previous) else "res://assets/audio/sfx/select.wav"


func _pop_playing(audio) -> int:
	var playing: int = 0
	for player: AudioStreamPlayer in audio._pop_players:
		playing += int(player.playing)
	return playing


func _last_slice_path(audio) -> String:
	var player: AudioStreamPlayer = audio.last_pop_player()
	return player.stream.resource_path if player != null and player.stream != null else ""


func _draw_slice_sequence(audio, count: int, seed_value: int) -> Array[String]:
	audio._pop_slice_rng.seed = seed_value
	audio._last_pop_slice_path = ""
	var paths: Array[String] = []
	var all_played := true
	for draw in range(count):
		audio.cue("pop-slice")
		var player: AudioStreamPlayer = audio.last_pop_player()
		all_played = all_played and player != null and player.playing and player.stream != null
		paths.append(_last_slice_path(audio))
	check(all_played, "Every seeded cue starts an actual AudioStream on one of the three slice voices")
	return paths


func _check_pop_slice_choices() -> void:
	var audio = load("res://scripts/game_audio.gd").new()
	root.add_child(audio)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/assets/voice-pop-random-slices.json"))
	var available_paths: Array[String] = []
	var declared_paths: Array[String] = []
	for asset in manifest.assets:
		var path: String = "res://" + str(asset.destination)
		declared_paths.append(path)
		if ResourceLoader.exists(path):
			available_paths.append(path)
			var stream: AudioStreamWAV = load(path)
			check(stream != null and stream.mix_rate == int(asset.sampleRate) and stream.stereo
				and absf(stream.get_length() - float(asset.seconds)) <= 1.0 / float(asset.sampleRate),
				"The playable " + str(asset.id) + " slice preserves the source duration, stereo and sample rate")
	check(declared_paths.size() == 8 and audio.POP_SLICE_PATHS == declared_paths,
		"The runtime declares exactly the eight fruit slices from the source manifest")
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/assets/voice-pop-reference-audio.json"))
	var reference_paths: Array[String] = []
	var complete_reference: bool = true
	for asset in reference.assets:
		var path: String = "res://" + str(asset.destination)
		reference_paths.append(path)
		var stream: AudioStreamWAV = load(path) if ResourceLoader.exists(path) else null
		var valid: bool = stream != null and stream.mix_rate == int(asset.sampleRate) and not stream.stereo \
			and absf(stream.get_length() - float(asset.seconds)) <= 1.0 / float(asset.sampleRate)
		complete_reference = complete_reference and valid
		if stream != null:
			check(valid, "The " + str(asset.id) + " reference variant preserves its authored mono format and duration")
	check(reference_paths.size() == 3 and audio.POP_REFERENCE_PATHS == reference_paths,
		"The runtime declares exactly the three reference variants from their source manifest")
	check(audio._pop_slice_paths == (reference_paths if complete_reference else available_paths),
		"Startup prefers a complete reference bank and otherwise selects the playable legacy pool")
	# Exercise the same selector in a clean checkout using real tracked clips.
	# The scene assertions above independently verify the actual imported pool.
	var pool: Array[String] = audio._pop_slice_paths.duplicate()
	if pool.size() < 2:
		pool.clear()
		for name in ["select", "correct", "wrong", "loss", "spring-arrive", "summer-arrive", "autumn-arrive", "winter-arrive"]:
			pool.append("res://assets/audio/sfx/" + name + ".wav")
	audio._pop_slice_paths = pool.duplicate()
	audio.interact("spring", false)
	var effect: AudioStreamPlayer = audio.effect
	var channels: int = audio.get_child_count()
	check(audio._pop_players.size() == 3, "Voice Pop has exactly three preallocated slice voices")
	var first_player: AudioStreamPlayer
	for index in range(4):
		audio.cue("pop-slice")
		var player: AudioStreamPlayer = audio.last_pop_player()
		if index == 0:
			first_player = player
		check(_pop_playing(audio) == mini(index + 1, 3) and audio.get_child_count() == channels,
			"Rapid hit %d never allocates or plays more than three slice voices" % (index + 1))
		if index == 3:
			check(player == first_player, "The fourth rapid slice replaces the oldest voice without adding a channel")
	audio.stop_pop_slices()
	check(_pop_playing(audio) == 0 and audio._pop_players.all(func(player: AudioStreamPlayer) -> bool: return player.stream == null),
		"Stopping slices clears every voice and its retained stream")
	var sequence := _draw_slice_sequence(audio, 1024, 19092026)
	var histogram: Dictionary = {}
	var transitions: Dictionary = {}
	var consecutive_differ := true
	for index in range(sequence.size()):
		var path: String = sequence[index]
		histogram[path] = int(histogram.get(path, 0)) + 1
		if index > 0:
			consecutive_differ = consecutive_differ and path != sequence[index - 1]
			transitions[sequence[index - 1] + "|" + path] = true
	check(consecutive_differ and sequence.all(func(path: String) -> bool: return pool.has(path)),
		"A fixed-seed 1024-hit run never repeats its previous clip or selects outside the available pool")
	check(histogram.size() == pool.size() and transitions.size() == pool.size() * (pool.size() - 1),
		"The seeded sample reaches every available clip and every allowed next-clip transition")
	var expected_frequency: float = float(sequence.size()) / pool.size()
	check(histogram.values().all(func(count: int) -> bool:
		return count >= expected_frequency * 0.5 and count <= expected_frequency * 1.5),
		"The deterministic sample distributes choices across the pool without a dominant clip")
	check(_draw_slice_sequence(audio, 32, 19092026) == sequence.slice(0, 32)
		and _draw_slice_sequence(audio, 32, 27102026) != sequence.slice(0, 32),
		"A saved random seed reproduces the sound sequence, while another seed changes it")
	seed(73191)
	var expected_global_random := randi()
	seed(73191)
	audio.cue("pop-slice")
	check(randi() == expected_global_random, "Sound selection does not consume the global vocabulary/reward random generator")
	var last: String = audio._last_pop_slice_path
	var state_before: int = audio._pop_slice_rng.state
	audio.set_muted(true)
	for request in range(4):
		audio.interact("spring", false)
		audio.cue("pop-slice")
	check(_pop_playing(audio) == 0 and not effect.playing and audio._pop_slice_rng.state == state_before and audio._last_pop_slice_path == last,
		"Muted cues do not draw or advance the anti-repeat history")
	audio.set_muted(false)
	audio.halt()
	audio.cue("pop-slice")
	check(_pop_playing(audio) == 0 and not effect.playing and audio._pop_slice_rng.state == state_before and audio._last_pop_slice_path == last,
		"An inactive controller cannot play or consume its next random choice")
	audio.interact("spring", false)
	audio._pop_slice_paths.assign([pool[0]])
	var single := _draw_slice_sequence(audio, 4, 17)
	check(single == [pool[0], pool[0], pool[0], pool[0]], "A partial installation containing one slice can repeat its only playable resource")
	audio._pop_slice_paths.assign([pool[0], pool[1]])
	var pair := _draw_slice_sequence(audio, 12, 17)
	check(pair.all(func(path: String) -> bool: return path in [pool[0], pool[1]])
		and range(1, pair.size()).all(func(index: int) -> bool: return pair[index] != pair[index - 1]),
		"A two-slice installation alternates without choosing any missing fruit")
	audio._pop_slice_paths.clear()
	state_before = audio._pop_slice_rng.state
	audio.cue("pop-slice")
	check(_pop_playing(audio) > 0 and _last_slice_path(audio) == _slice_fallback() and audio._pop_slice_rng.state == state_before,
		"An empty pool uses the earlier slice or tracked select fallback without drawing a missing file")
	check(audio.effect == effect and audio.get_child_count() == channels
		and audio._pop_players.size() == 3 and not effect.playing
		and not audio.music.playing and not audio.voice.playing,
		"All pool sizes and repeated draws reuse the same three voices without UI effects, music or extra nodes")
	audio.halt()
	audio.free()


func _pop_hit_visible_word(app, elapsed: float = 0.0) -> bool:
	var view = app._pop
	if elapsed > 0.0:
		view._advance_game(elapsed)
	if not view.is_visible_in_tree() or view.game.targets.is_empty():
		return false
	var hits_before: int = view.game.hits
	view.receive_transcript(str(view.game.targets[0].word.text))
	return view.game.hits == hits_before + 1


func _match_progress(app) -> Array:
	return [app.model.phase, app.model.successes, app.model.mistakes, app.model.hints_remaining,
		app.model.streak, app.model.selected_id, app.model.matched_ids.duplicate(),
		app.medal_progress.counts.duplicate(), app.playroom_state.collected_word_ids.duplicate()]


func _tap_control(control: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	motion.global_position = motion.position
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
