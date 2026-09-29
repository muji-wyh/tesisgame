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
	var directory := "user://pip-gameplay-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.size = Vector2i(480, 900)
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_reduced_motion(false)
	app.audio.set_muted(false)
	app._pop.missed.connect(func(count: int) -> void: missed_batches.append(count))
	_check_match(app)
	_check_memory(app)
	_check_pop(app)
	_check_preferences(app)
	_check_lifecycle(app)
	app.queue_free()
	await process_frame
	print("Pip gameplay feedback: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _start(app, mode: String) -> void:
	check(app.new_round(84, true, "", mode), "The " + mode + " fixture starts a fresh playable round")
	if mode == "pop":
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


func _reaction_playing(app) -> bool:
	return app.audio.pip_reaction != null and app.audio.pip_reaction.playing


func _expect_reaction(app, correct: bool, context: String) -> void:
	check(app.duck._gameplay_reaction == ("happy" if correct else "sad"), context + " gives Pip the matching emotion")
	check(_reaction_playing(app), context + " plays a dedicated duck call")
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
		_expect_reaction(app, correct, context)
		check(app.model.successes == (1 if correct else 0) and app.model.mistakes == (0 if correct else 1),
			context + " changes the existing score exactly once")
		var speech: String = "res://" + word.audio if correct else "res://assets/audio/voice/wrong.wav"
		check(app.audio.voice.playing and app.audio.voice.stream == load(speech),
			context + " preserves the existing word or correction recording alongside the call")
		app._update_duck()
		check(app.duck._gameplay_reaction == ("happy" if correct else "sad"),
			context + " remains expressive while speech updates Pip's beak")


func _check_memory(app) -> void:
	for correct in [true, false]:
		_start(app, "memory")
		var word: Dictionary = _memory_answer(app, correct)
		var context: String = "A correct Memory pair" if correct else "A wrong Memory pair"
		_expect_reaction(app, correct, context)
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
	_expect_reaction(app, true, "A spoken Voice Pop hit")
	check(view.game.hits == 1 and view.game.score == 10 and view.game.misses == 0,
		"A spoken hit keeps the established score and combo rules")
	check(app.audio.last_pop_player() != null and app.audio.last_pop_player().playing
		and not app.audio.effect.playing and not app.audio.voice.playing and not app.audio.music.playing,
		"The duck call accompanies the Pop slice without word prompts or background music")
	var slice_player: AudioStreamPlayer = app.audio.last_pop_player()
	var slice_rng: int = app.audio._pop_slice_rng.state
	view.receive_transcript(word.text)
	check(view.game.hits == 1 and view.game.misses == 0 and missed_batches.size() == batches_before,
		"A repeated transcript cannot duplicate a hit or turn it into a miss")
	check(app.audio.last_pop_player() == slice_player and app.audio._pop_slice_rng.state == slice_rng,
		"A repeated transcript cannot play another slice or consume its random choice")
	app._on_voice_state([true, false, "Listening paused. Continuing..."])
	check(view._reconnecting and app.duck._gameplay_reaction == "happy" and _reaction_playing(app)
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
	for mode in ["match", "memory", "pop"]:
		_start(app, mode)
		app.set_reduced_motion(true)
		app.audio.set_muted(true)
		if mode == "match":
			_match_answer(app, true)
		elif mode == "memory":
			_memory_answer(app, true)
		else:
			app._pop.receive_transcript(app._pop.game.targets[0].word.text)
		check(app.duck._gameplay_reaction == "happy" and app.duck.scale == Vector2.ONE
			and is_zero_approx(app.duck.rotation),
			"Muted reduced-motion " + mode + " still shows the successful emotion without moving the input target")
		check(not _reaction_playing(app) and not app.audio.voice.playing and not app.audio.effect.playing
			and app.audio._pop_players.all(func(player: AudioStreamPlayer) -> bool: return not player.playing),
			"Muted " + mode + " suppresses the call and existing effects")
		check((app._pop.game.hits if mode == "pop" else app.model.successes) == 1,
			"Accessibility settings do not change " + mode + " scoring")
		app.audio.set_muted(false)
		check(not _reaction_playing(app), "Unmuting " + mode + " does not replay the suppressed call")
		app.set_reduced_motion(false)


func _check_lifecycle(app) -> void:
	for transition in ["speech_pause", "home", "hidden", "new_round", "mode_exit"]:
		_start(app, "pop")
		var view = app._pop
		view.receive_transcript(view.game.targets[0].word.text)
		view._advance_game(0.8)
		var before: Array = [view.game.hits, view.game.misses, missed_batches.size()]
		check(_reaction_playing(app) and not app.duck._gameplay_reaction.is_empty(),
			transition + " begins during real hit feedback with another target still in flight")
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
		view._advance_game(30.0)
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
