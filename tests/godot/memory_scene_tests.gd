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
	var app = load("res://scenes/main.tscn").instantiate()
	if not app.get_property_list().any(func(p: Dictionary) -> bool: return p.name == "_memory"):
		check(false, "Main scene offers the fifth Memory mode")
		app.free()
		quit(1)
		return
	var directory := "user://memory-scene-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var progress_script = app.medal_progress.get_script()
	app.medal_progress = progress_script.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/playroom.cfg"
	root.add_child(app)
	await process_frame
	await process_frame
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	app.choose_theme("spring")
	var lesson: Array = app.model.lesson_words.duplicate(true)
	app.choose_mode("memory")
	await process_frame
	await process_frame
	var view = app._memory
	check(view.is_visible_in_tree() and app._mode_buttons.size() == 5, "The Memory tab opens a playable fifth mode")
	check(app.model.lesson_words == lesson and app.model.theme_id == "spring", "Memory retains the lesson and selected world")
	check(not app._mistakes.visible and not app.grid.visible and not app._choice.visible, "Memory hides the three-mistake HUD and other boards")
	check(app._status_announcement.contains("Memory") and app._status_announcement.contains("0 of 5"), "Memory announces its own goal and progress")
	var board: Array = view.memory.cards.duplicate(true)
	view.card_buttons[0].pressed.emit()
	check(view.memory.selected_indices == [0], "An actual card button reveals a card")
	app._controller_back()
	check(view.memory.selected_indices.is_empty(), "Xbox B or Escape cancels a Memory selection")
	view.card_buttons[0].grab_focus()
	app._controller_accept()
	check(view.memory.selected_indices == [0], "Xbox A reveals the focused Memory card")
	app.choose_mode("memory")
	check(view.memory.selected_indices == [0] and view.memory.cards == board, "Clicking the active tab retains the attempt")
	app.on_page_hidden()
	app.set_reduced_motion(false)
	app.set_reduced_motion(true)
	app.choose_theme("ocean")
	check(view.memory.selected_indices == [0] and view.memory.cards == board, "Page hiding, motion and palette changes preserve the board")
	view.card_buttons[0].grab_focus()
	app._show_collection()
	view.card_buttons[1].pressed.emit()
	view.study_button.pressed.emit()
	app.choose_mode("match")
	check(view.memory.selected_indices == [0] and not view.memory.studying and app._mode_id == "memory", "Covered controls cannot mutate the attempt")
	app._hide_collection()
	check(root.gui_get_focus_owner() == view.card_buttons[0], "Closing rewards restores the selected card's keyboard focus")
	view.study_button.pressed.emit()
	check(view.memory.studying and view.memory.selected_indices.is_empty(), "Study clears unfinished selections")
	check(app._default_focus() == view.study_button, "Return to play is the default Study control")
	app._controller_back()
	check(not view.memory.studying, "Xbox B or Escape returns from Study without resetting the board")
	var word_index := -1
	var image_index := -1
	for index in range(board.size()):
		if board[index].kind == "word":
			word_index = index
			break
	for index in range(board.size()):
		if board[index].kind == "image" and board[index].word.id != board[word_index].word.id:
			image_index = index
			break
	for attempt in range(4):
		view.card_buttons[word_index].pressed.emit()
		view.card_buttons[image_index].pressed.emit()
		check(app.model.phase != "lost" and app.model.missed_word_ids.is_empty(), "Memory exploration never marks vocabulary missed or ends the game")
		check(app._default_focus() == view.feedback_view.action_button, "Explicit Continue is the feedback focus")
		app._show_collection()
		view.continue_feedback()
		check(view.memory.phase == "feedback", "Covered feedback cannot continue")
		app._hide_collection()
		view.feedback_view.action_button.pressed.emit()
	check(view.memory.attempts == 4 and app.model.mistakes == 0, "Memory counts attempts independently of three-strike modes")
	for word in lesson:
		for index in range(board.size()):
			if board[index].word.id == word.id:
				view.card_buttons[index].pressed.emit()
		check(app.model.phase != "won", "A correct pair waits for explicit Continue before any win")
		view.feedback_view.action_button.pressed.emit()
	check(app.model.phase == "won" and app.model.successes == 5, "Five completed pairs enter the ordinary victory screen")
	check(not view.visible and app._found_words.get_child_count() == 5, "The result reviews all five practised words")
	check(app.medal_progress.counts.is_empty(), "Completing Memory alone does not fabricate a reward claim")
	app._open_chest()
	check(app.medal_progress.count_for("ocean-1") == 1, "Memory grants one ordinary piece in the selected world")
	view.continue_feedback()
	view.round_finished.emit(true, lesson)
	app._on_chest_opened()
	app._open_chest()
	check(app.medal_progress.count_for("ocean-1") == 1, "Duplicate completion and chest callbacks cannot award extra pieces")
	var reloaded = progress_script.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	check(reloaded.load_progress() and reloaded.count_for("ocean-1") == 1, "Memory rewards survive storage reload")
	app._replay()
	check(app._mode_id == "memory" and app.model.lesson_words == lesson and app.model.theme_id == "ocean", "Repeat preserves mode, lesson and world")
	check(view.memory.attempts == 0 and view.memory.matched_word_ids.is_empty(), "Repeat clears the prior attempt")
	app.choose_mode("learn")
	view.round_finished.emit(true, lesson)
	check(app.model.phase != "won" and view.memory.phase == "stopped", "Leaving Memory blocks stale completion")
	for mode in ["match", "sky", "listen"]:
		app.choose_mode(mode)
		check(app._mode_id == mode and app.model.lesson_words == lesson, "Existing " + mode + " mode remains reachable with the same lesson")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Memory scene: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
