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
	var target_rects: Array = view.card_buttons.map(func(card: Button) -> Rect2: return card.get_global_rect())
	var field_rect: Rect2 = view.get_global_rect()
	view.card_buttons[0].pressed.emit()
	await process_frame
	await process_frame
	check(view.memory.selected_indices == [0], "An actual card button reveals a card")
	check(view.get_global_rect() == field_rect and view.card_buttons.map(func(card: Button) -> Rect2: return card.get_global_rect()) == target_rects, "A first reveal does not move the host playfield or any Memory target")
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
		await process_frame
		await process_frame
		check(view.card_buttons.all(func(card: Button) -> bool: return card.is_visible_in_tree()), "The real scene keeps every remembered card visible during feedback")
		check(view.get_global_rect() == field_rect and view.card_buttons.map(func(card: Button) -> Rect2: return card.get_global_rect()) == target_rects, "Feedback does not resize or move the host board")
		check(app.model.phase != "lost" and app.model.missed_word_ids.is_empty(), "Memory exploration never marks vocabulary missed or ends the game")
		check(app._default_focus() == view.feedback_view.action_button, "Explicit Continue is the feedback focus")
		app._show_collection()
		view.continue_feedback()
		check(view.memory.phase == "feedback", "Covered feedback cannot continue")
		app._hide_collection()
		view.feedback_view.action_button.pressed.emit()
		await process_frame
		await process_frame
		check(view.get_global_rect() == field_rect and view.card_buttons.map(func(card: Button) -> Rect2: return card.get_global_rect()) == target_rects, "Continue retains the original host card targets")
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
	await _check_host_layout(app)
	if "--screenshots" in OS.get_cmdline_user_args():
		await _capture_scenes(app)
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Memory scene: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_host_layout(app) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for dimensions in [Vector2i(480, 480), Vector2i(480, 900), Vector2i(480, 480)]:
		root.size = dimensions
		app.choose_mode("listen")
		app.choose_mode("memory")
		for frame in range(4):
			await process_frame
		var view = app._memory
		var bounds: Rect2 = root.get_visible_rect().grow(0.5)
		check(bounds.encloses(view.get_global_rect()), "Mode changes and resizing keep the Memory playfield on screen at " + str(dimensions))
		check(bounds.encloses(view.feedback_view.get_global_rect()), "The reserved review stays on screen after changing modes at " + str(dimensions))
		for card in view.card_buttons:
			check(bounds.encloses(card.get_global_rect()), "Every Memory target fits the real host after resizing")


func _capture_scenes(app) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	app.set_reduced_motion(false)
	app.choose_theme("spring")
	for dimensions in [Vector2i(480, 480), Vector2i(480, 900)]:
		root.size = dimensions
		app.choose_mode("match")
		app.choose_mode("memory")
		await process_frame
		await process_frame
		var view = app._memory
		var first := -1
		var partner := -1
		var wrong := -1
		for index in range(view.memory.cards.size()):
			if view.memory.cards[index].kind == "word":
				first = index
				break
		for index in range(view.memory.cards.size()):
			var card: Dictionary = view.memory.cards[index]
			if card.kind == "image":
				if card.word.id == view.memory.cards[first].word.id:
					partner = index
				else:
					wrong = index
		var prefix := "memory-%dx%d-" % [dimensions.x, dimensions.y]
		await _save_capture(prefix + "waiting")
		view.card_buttons[first].pressed.emit()
		await _save_capture(prefix + "reveal")
		view.card_buttons[wrong].pressed.emit()
		await _save_capture(prefix + "wrong-1")
		view.feedback_view.next_button.pressed.emit()
		await _save_capture(prefix + "wrong-2")
		view.continue_feedback()
		view.card_buttons[first].pressed.emit()
		view.card_buttons[partner].pressed.emit()
		await _save_capture(prefix + "correct")
		view.continue_feedback()
		await _save_capture(prefix + "continue")


func _save_capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := "res://build/visuals"
	DirAccess.make_dir_recursive_absolute(directory)
	check(root.get_texture().get_image().save_png(directory + "/" + filename + ".png") == OK, "The actual Memory scene renders " + filename)
