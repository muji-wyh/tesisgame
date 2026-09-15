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
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_reduced_motion(true)
	app.choose_mode("learn")
	await process_frame
	await process_frame
	app._lesson.picture_button.pressed.emit()
	check(app.audio.voice.playing, "Hear starts the displayed lesson word")
	app._lesson._move(1)
	check(not app.audio.voice.playing, "Next stops the old pronunciation before displaying another word")
	app._lesson.picture_button.pressed.emit()
	app._lesson._move(-1)
	check(not app.audio.voice.playing, "Previous also stops the old pronunciation")
	app._lesson.picture_button.grab_focus()
	app._show_collection()
	check(not app._focus_candidates().has(app._lesson.picture_button) and not app.audio.voice.playing,
		"The covered Learn picture stays outside modal focus and pronunciation")
	app._hide_collection()
	check(root.gui_get_focus_owner() == app._lesson.picture_button and app._valid_focus(app._lesson.picture_button),
		"Returning from More restores focus to the same playable Learn picture")
	app.choose_mode("match")
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
	app.choose_mode("learn")
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
	app.choose_mode("learn")
	app._lesson.picture_button.pressed.emit()
	app._show_collection()
	check(not app.audio.voice.playing, "Opening rewards stops speech about a now-covered picture")
	app.medal_progress.counts["spring-1"] = 3
	app._refresh_collection()
	app._select_room_item("toy-ball")
	app._room.action_button.pressed.emit()
	check(app.audio.voice.playing, "The current room toy pronounces its word")
	app._room.item_buttons["toy-spring"].pressed.emit()
	check(app._room._toy.word_id == "flower" and not app.audio.voice.playing, "Choosing an owned toy stops the word for the replaced toy")
	app._room.action_button.pressed.emit()
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
	app.audio.halt()
	app.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("UI audio flow: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


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
