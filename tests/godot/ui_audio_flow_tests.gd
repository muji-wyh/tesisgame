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
	app._lesson.hear_button.pressed.emit()
	check(app.audio.voice.playing, "Hear starts the displayed lesson word")
	app._lesson.next_button.pressed.emit()
	check(not app.audio.voice.playing, "Next stops the old pronunciation before displaying another word")
	app._lesson.hear_button.pressed.emit()
	app._lesson.previous_button.pressed.emit()
	check(not app.audio.voice.playing, "Previous also stops the old pronunciation")
	app.choose_mode("match")
	var first: Dictionary = app.model.cards.filter(func(card: Dictionary) -> bool: return card.kind == "word")[0]
	var other: Dictionary = app.model.cards.filter(func(card: Dictionary) -> bool: return card.kind == "image" and card.word.id != first.word.id)[0]
	app._select_card(first.id)
	app._select_card(other.id)
	app._match_feedback.hear_button.pressed.emit()
	check(app.audio.voice.playing, "Match correction can pronounce its first association")
	app._match_feedback.next_button.pressed.emit()
	check(not app.audio.voice.playing, "Changing a correction association stops the old word")
	app._match_feedback.hear_button.pressed.emit()
	app._match_feedback.action_button.pressed.emit()
	check(not app.audio.voice.playing, "Continue stops correction speech when returning to the board")
	for mode in ["sky", "listen"]:
		app.choose_mode(mode)
		var correct: int = 0 if app._choice.choices[0].id == app._choice.current_target.id else 1
		var target: Dictionary = app._choice.current_target
		app._choice._choose(1 - correct)
		app._choice.answer_buttons[correct].pressed.emit()
		check(app._choice.successes == 1 and app._choice.mistakes == 1
			and app.audio.voice.playing and app.audio.voice.stream == load("res://" + target.audio),
			mode + " first-tap correction scores once and pronounces the same visible target")
		check(root.gui_get_focus_owner() == app._choice.feedback_view.action_button,
			mode + " correction leaves keyboard Continue available without another accidental answer")
		app._choice.continue_feedback()
		check(not app.audio.voice.playing, mode + " Continue stops feedback speech before the next question")
		for answer in range(4):
			correct = 0 if app._choice.choices[0].id == app._choice.current_target.id else 1
			app._choice._choose(correct)
			app._choice.feedback_view.hear_button.pressed.emit()
			if answer in [0, 3]:
				app._choice.answer_buttons[correct].pressed.emit()
			else:
				app._choice.feedback_view.action_button.pressed.emit()
			check(not app.audio.voice.playing and app._choice.successes == answer + 2,
				mode + " advancing by an answer or Continue stops the old word without scoring the new prompt")
		check(app.model.phase == "won" and not app.audio.voice.playing, mode + " final answer tap stops pronunciation when entering the result")
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
	var visible_word: Dictionary = memory.feedback_view.current_word
	check(app.audio.voice.stream == load("res://" + visible_word.audio), "Wrong Memory feedback pronounces its visible first association, not the hidden second card")
	memory.feedback_view.next_button.pressed.emit()
	check(not app.audio.voice.playing, "Memory correction Next stops the previous word")
	memory.feedback_view.hear_button.pressed.emit()
	memory.continue_feedback()
	check(not app.audio.voice.playing, "Memory Continue stops speech before hiding unmatched pictures")
	app.choose_mode("learn")
	app._lesson.hear_button.pressed.emit()
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
		check(app.feedback_timer.is_stopped(), exit_path + " stops the voice feedback timer")
		await create_timer(0.8).timeout
		check(app.model.phase == "feedback", exit_path + " preserves the correction until an explicit Continue")
		if app.collection_page.visible:
			app._hide_collection()
		check(not app.cards[next_id].disabled, exit_path + " immediately restores card input without another refresh")
		app.cards[next_id].pressed.emit()
		check(app.model.phase == "matching" and app.model.selected_id == next_id,
			"The first tap after voice ends continues and selects the tapped card")
	app.audio.halt()
	app.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("UI audio flow: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
