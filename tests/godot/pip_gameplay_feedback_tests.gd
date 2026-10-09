extends SceneTree

var checks: int = 0
var failures: int = 0
var missed_batches: Array[int] = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	await _check_pair_audio()
	var directory := "user://pip-gameplay-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	preload("res://tests/godot/player_flow_fixture.gd").install(app, directory)
	root.size = Vector2i(480, 900)
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_reduced_motion(false)
	app.audio.set_muted(false)
	app._pop.missed.connect(func(count: int) -> void: missed_batches.append(count))
	_check_match(app)
	_check_match_voice_answers(app)
	await _check_match_voice_final_tail(app)
	await _check_match_audio_tail(app)
	_check_memory(app)
	_check_pop(app)
	_check_preferences(app)
	_check_lifecycle(app)
	app.audio.halt()
	# Give the audio mixer time to release stopped playback before exiting.
	await create_timer(0.1).timeout
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Pip gameplay feedback: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _start(app, mode: String) -> void:
	check(app.new_round(84, true, "", mode), "The " + mode + " fixture starts a fresh playable round")
	if mode == "pop":
		preload("res://tests/godot/player_flow_fixture.gd").choose_pop_player(app)
		app._pop.set_process(false)
		app._on_voice_state([true, true, "Listening."])


func _match_word(app) -> Dictionary:
	for card in app.model.cards:
		if card.kind == "word" and not app.model.card_by_id(card.word.id + ":image").is_empty():
			return card
	return {}


func _match_answer(app, correct: bool) -> Dictionary:
	var first: Dictionary = _match_word(app)
	var second: String = first.word.id + ":image"
	if not correct:
		for card in app.model.cards:
			if card.kind == "image" and card.word.id != first.word.id:
				second = card.id
				break
	app.cards[first.id].pressed.emit()
	app.cards[second].pressed.emit()
	return first.word


func _memory_answer(app, correct: bool) -> Dictionary:
	var memory = app._memory
	var first: Dictionary = memory.memory.cards[0]
	var second: int = -1
	for index in range(1, memory.memory.cards.size()):
		var candidate: Dictionary = memory.memory.cards[index]
		if candidate.kind != first.kind and (candidate.word.id == first.word.id) == correct:
			second = index
			break
	check(second >= 0, "The Memory fixture contains the requested result")
	memory.card_buttons[0].pressed.emit()
	memory.card_buttons[second].pressed.emit()
	return memory.memory.cards[second].word


func _phrase_answer(app) -> void:
	var view = app._phrase
	for id in view.game.current_question().words:
		var option_index: int = -1
		for index in range(view.game.options.size()):
			if view.game.options[index].id == id:
				option_index = index
				break
		check(option_index >= 0, "The phrase fixture contains each requested word")
		if option_index < 0:
			return
		view.option_buttons[option_index].pressed.emit()
	view.action_button.pressed.emit()


func _reaction_playing(app) -> bool:
	return app.audio.pip_reaction != null and app.audio.pip_reaction.playing


func _expect_reaction(app, correct: bool, context: String, voiced: bool = true) -> void:
	check(app.duck._gameplay_reaction == ("happy" if correct else "sad"), context + " gives Pip the matching emotion")
	check(_reaction_playing(app) == voiced, context + (" plays a dedicated duck call" if voiced else " keeps Pip's reaction silent"))
	check(app.duck.visible and app.duck.size.x > 0.0, context + " keeps Pip visible in the game header")


func _check_match(app) -> void:
	for correct in [true, false]:
		_start(app, "match")
		var first: Dictionary = _match_word(app)
		app.cards[first.id].pressed.emit()
		check(app.duck._gameplay_reaction.is_empty() and not _reaction_playing(app),
			"Selecting only one Match card never judges an unfinished answer")
		app._controller_back()
		var word: Dictionary = _match_answer(app, correct)
		var context: String = "A correct Match pair" if correct else "A wrong Match pair"
		_expect_reaction(app, correct, context, false)
		check((app.model.matched_ids.size() / 2) == (1 if correct else 0) and app.model.mistakes == (0 if correct else 1),
			context + " changes the existing score exactly once")
		if correct:
			check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + word.audio),
				context + " preserves its vocabulary pronunciation")
		else:
			check(not app.audio.voice.playing, context + " has no spoken correction")
		check(app.audio.pair_feedback.playing and app.audio.pair_feedback.stream == load(
			app.audio.PAIR_FEEDBACK_PATHS[correct]), context + " uses the supplied answer effect")
		app._update_duck()
		check(app.duck._gameplay_reaction == ("happy" if correct else "sad"),
			context + " remains expressive while speech updates Pip's beak")


func _check_memory(app) -> void:
	for correct in [true, false]:
		_start(app, "memory")
		var word: Dictionary = _memory_answer(app, correct)
		var context: String = "A correct Memory pair" if correct else "A wrong Memory pair"
		_expect_reaction(app, correct, context, false)
		check(app._memory.memory.attempts == 1 and app._memory.memory.mistakes == (0 if correct else 1)
			and app._memory.memory.matched_word_ids.size() == (1 if correct else 0),
			context + " preserves the original pair scoring")
		check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + word.audio),
			context + " keeps pronouncing the second visible card")
		app._update_duck()
		check(app.duck._gameplay_reaction == ("happy" if correct else "sad"),
			context + " survives the regular header refresh")


func _check_pop(app) -> void:
	_start(app, "pop")
	var view = app._pop
	var batches_before: int = missed_batches.size()
	view.receive_transcript("unrelated gobbledygook")
	check(view.game.hits == 0 and view.game.misses == 0 and missed_batches.size() == batches_before
		and app.duck._gameplay_reaction.is_empty() and not _reaction_playing(app),
		"Unrecognized speech never creates a missed target, sad face, or duck call")
	var word: Dictionary = view.game.targets[0].word
	view.receive_transcript(word.text)
	_expect_reaction(app, true, "A spoken Voice Pop hit", false)
	check(view.game.hits == 1 and view.game.score == 10 and view.game.misses == 0,
		"A spoken hit keeps the established score and combo rules")
	check(app.audio.last_pop_player() != null and app.audio.last_pop_player().playing
		and not app.audio.effect.playing and not app.audio.voice.playing and not app.audio.music.playing,
		"The Pop slice plays without word prompts or background music")
	var slice_player: AudioStreamPlayer = app.audio.last_pop_player()
	var slice_rng: int = app.audio._pop_slice_rng.state
	view.receive_transcript(word.text)
	check(view.game.hits == 1 and view.game.misses == 0 and missed_batches.size() == batches_before,
		"A repeated transcript cannot duplicate a hit or turn it into a miss")
	check(app.audio.last_pop_player() == slice_player and app.audio._pop_slice_rng.state == slice_rng,
		"A repeated transcript cannot play another slice or consume its random choice")
	app._on_voice_state([true, false, "Listening paused. Continuing..."])
	check(view._reconnecting and app.duck._gameplay_reaction == "happy" and not _reaction_playing(app)
		and slice_player.playing,
		"Normal speech-recognizer rollover does not cut off a just-earned celebration or slice tail")
	app._on_voice_state([true, true, "Listening."])
	check(view.game.hits == 1 and missed_batches.size() == batches_before,
		"Recognizer rollover resumes the same score without manufacturing missed words")
	_start(app, "pop")
	batches_before = missed_batches.size()
	view._advance_game(8.0)
	_expect_reaction(app, false, "Expired Voice Pop targets")
	check(view.game.misses >= 2 and missed_batches.size() == batches_before + 1
		and missed_batches.back() == view.game.misses,
		"One slow frame emits one response carrying the actual count of expired targets")
	check(not app.audio.music.playing and not app.audio.voice.playing,
		"A missed target's call keeps listening free of music and spoken prompts")
	view._advance_game(0.0)
	check(missed_batches.size() == batches_before + 1, "Redrawing the same expiry batch cannot repeat sadness")


func _check_preferences(app) -> void:
	for mode in ["match", "memory", "pop", "phrase"]:
		_start(app, mode)
		app.set_reduced_motion(true)
		app.audio.set_muted(true)
		if mode == "match":
			_match_answer(app, true)
		elif mode == "memory":
			_memory_answer(app, true)
		elif mode == "phrase":
			_phrase_answer(app)
		else:
			app._pop.receive_transcript(app._pop.game.targets[0].word.text)
		var mascot = app._phrase.pip if mode == "phrase" else app.duck
		check(mascot._gameplay_reaction == "happy" and mascot.scale == Vector2.ONE
			and is_zero_approx(mascot.rotation),
			"Muted reduced-motion " + mode + " still shows the successful emotion without moving the input target")
		check(not _reaction_playing(app) and not app.audio.voice.playing and not app.audio.effect.playing and not app.audio.pair_feedback.playing
			and app.audio._pop_players.all(func(player: AudioStreamPlayer) -> bool: return not player.playing),
			"Muted " + mode + " suppresses the call and existing effects")
		var completed: int = app._pop.game.hits if mode == "pop" else app._memory.memory.matched_word_ids.size() if mode == "memory" else app._phrase.game.completed if mode == "phrase" else app.model.matched_ids.size() / 2
		check(completed == 1,
			"Accessibility settings do not change " + mode + " scoring")
		app.audio.set_muted(false)
		check(not _reaction_playing(app), "Unmuting " + mode + " does not replay the suppressed call")
		app.set_reduced_motion(false)


func _check_lifecycle(app) -> void:
	for transition in ["speech_pause", "home", "hidden", "new_round", "mode_exit"]:
		_start(app, "pop")
		var view = app._pop
		view._advance_game(6.0)
		_expect_reaction(app, false, transition + " after a missed word")
		var missed_call: AudioStream = app.audio.pip_reaction.stream
		view.receive_transcript(view.game.targets[0].word.text)
		var before: Array = [view.game.hits, view.game.misses, missed_batches.size()]
		check(_reaction_playing(app) and app.audio.pip_reaction.stream == missed_call
			and is_equal_approx(app.audio.pip_reaction.pitch_scale, 0.8)
			and app.duck._gameplay_reaction == "happy" and app.audio.last_pop_player().playing,
			transition + " begins during a celebrating hit without replacing the missed word's call")
		match transition:
			"speech_pause": app._on_voice_state([true, false, "Speech network error. Tap Retry."])
			"home": app._show_collection()
			"hidden": app.on_page_hidden()
			"new_round": app.new_round(85, true)
			"mode_exit": app.choose_mode("memory")
		check(not _reaction_playing(app) and app.duck._gameplay_reaction.is_empty()
			and app.audio._pop_players.all(func(player: AudioStreamPlayer) -> bool: return not player.playing),
			transition + " clears the active call and emotion immediately")
		check(missed_batches.size() == before[2], transition + " never classifies a cleared target as missed")
		view._advance_game(view.game.remaining)
		check(missed_batches.size() == before[2] and not _reaction_playing(app),
			transition + " prevents late simulation work from restarting feedback")
		if transition in ["speech_pause", "home", "hidden"]:
			check(view.game.hits == before[0] and view.game.misses == before[1],
				transition + " retains earned progress while the round is paused")
		if transition == "home":
			app._hide_collection()
		elif transition == "hidden":
			app.on_page_visible()
		check(not _reaction_playing(app)
			and app.audio._pop_players.all(func(player: AudioStreamPlayer) -> bool: return not player.playing),
			transition + " does not replay old feedback on return")


func _check_pair_audio() -> void:
	var audio = load("res://scripts/game_audio.gd").new()
	root.add_child(audio)
	var players: Array[Node] = audio.get_children()
	for correct in [true, false]:
		var path: String = audio.PAIR_FEEDBACK_PATHS[correct]
		var clip: AudioStreamWAV = load(path)
		check(clip != null and clip.mix_rate == 44100 and clip.format == AudioStreamWAV.FORMAT_16_BITS
			and clip.loop_mode == AudioStreamWAV.LOOP_DISABLED and clip.get_length() > 0.7 and clip.get_length() < 1.0,
			"Each supplied answer effect retains a complete, nonlooping recording")
		audio.interact("spring", false)
		audio.play_pair_feedback(correct)
		check(audio.pair_feedback.playing and audio.pair_feedback.stream == clip
			and is_equal_approx(audio.pair_feedback.pitch_scale, 1.0)
			and is_equal_approx(db_to_linear(audio.pair_feedback.volume_db), audio.PAIR_FEEDBACK_GAIN),
			"Pair feedback plays its supplied clip at the authored pitch and bounded gain")
		check(not audio.voice.playing and audio.pip_reaction == null and audio.get_children() == players,
			"Pair feedback adds no spoken prompt, quack or dynamically allocated player")
		audio.halt(true)
		check(audio.pair_feedback.playing, "Speech rollover preserves the current answer effect")
		audio.halt()
		check(not audio.pair_feedback.playing and audio.pair_feedback.stream == null,
			"Ordinary lifecycle cleanup stops and releases the answer effect")
	for blocked in ["inactive", "muted", "unavailable"]:
		audio.active = blocked != "inactive"
		audio.muted = blocked == "muted"
		audio.available = blocked != "unavailable"
		audio.play_pair_feedback(false)
		check(not audio.pair_feedback.playing, "An " + blocked + " answer effect stays silent")
	audio.queue_free()
	await process_frame


func _check_match_audio_tail(app) -> void:
	for correct in [true, false]:
		_start(app, "match")
		_match_answer(app, correct)
		app.feedback_timer.paused = true
		app._resolve_feedback()
		check(app.model.phase == "waiting" and app.audio.pair_feedback.playing,
			"Automatic Match resolution preserves the complete supplied answer tail")
		if correct:
			var next: String = ""
			for card in app.model.cards:
				if not app.model.matched_ids.has(card.id):
					next = card.id
					break
			app.cards[next].pressed.emit()
		else:
			app._request_hint()
		check(not app.audio.pair_feedback.playing,
			"The next deliberate card or hint stops the previous answer tail")
	_start(app, "match")
	for card in app.model.cards:
		if card.kind != "word":
			continue
		app.cards[card.id].pressed.emit()
		app.cards[card.word.id + ":image"].pressed.emit()
		app.feedback_timer.paused = true
		app._resolve_feedback()
	check(app.model.phase == "won" and app.audio.pair_feedback.playing,
		"The final pair's supplied right effect survives the transition to results")
	await create_timer(1.0).timeout
	check(not app.audio.pair_feedback.playing,
		"The supplied right effect ends naturally without looping on the win screen")


func _check_match_voice_answers(app) -> void:
	for correct in [true, false]:
		_start(app, "match")
		app._on_voice_state([true, true, "Listening."])
		_match_answer(app, correct)
		check(app.model.phase == "feedback" and app.audio.pair_feedback.playing
			and app.audio.pair_feedback.stream == load(app.audio.PAIR_FEEDBACK_PATHS[correct])
			and not app.audio.voice.playing and not _reaction_playing(app) and not app.audio.music.playing,
			"A tapped answer while listening plays its supplied effect without speech or quacks")
		var request: int = app.audio._playback_requests.get(app.audio.pair_feedback, 0)
		app._on_voice_state([true, false, "Listening paused. Continuing..."])
		check(app.audio.pair_feedback.playing and app.audio._playback_requests.get(app.audio.pair_feedback, 0) == request,
			"Recognizer rollover preserves a tapped answer effect without replaying it")
		app._stop_voice()
		check(not app.audio.pair_feedback.playing, "Stopping speech input cancels the answer tail")


func _check_match_voice_final_tail(app) -> void:
	_start(app, "match")
	app._on_voice_state([true, true, "Listening."])
	var words: Array = app.model.cards.filter(func(card: Dictionary) -> bool: return card.kind == "word")
	for card in words.slice(0, words.size() - 1):
		app.cards[card.id].pressed.emit()
		app.cards[card.word.id + ":image"].pressed.emit()
		app.feedback_timer.paused = true
		app._resolve_feedback()
	var finished_phases: Array[String] = []
	var on_finished := func() -> void: finished_phases.append(app.model.phase)
	app.audio.pair_feedback.finished.connect(on_finished)
	app.feedback_timer.paused = false
	var final_card: Dictionary = words.back()
	app.cards[final_card.id].pressed.emit()
	app.cards[final_card.word.id + ":image"].pressed.emit()
	check(is_equal_approx(app.feedback_timer.wait_time, app.VOICE_MATCH_SECONDS)
		and app.feedback_timer.wait_time >= app.audio.pair_feedback.stream.get_length(),
		"A final tapped pair while listening leaves time for the supplied right effect before stopping speech")
	await create_timer(app.VOICE_MATCH_SECONDS + 0.2).timeout
	check(finished_phases == ["feedback"] and app.model.phase == "won" and not app._voice_mode
		and not app.audio.pair_feedback.playing,
		"The final tapped right clip finishes naturally before the win screen retires listening")
	app.audio.pair_feedback.finished.disconnect(on_finished)
