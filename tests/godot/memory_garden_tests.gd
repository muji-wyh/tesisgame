extends SceneTree

const Data = preload("res://scripts/game_data.gd")

var checks: int = 0
var failures: int = 0
var revealed: Array = []
var answers: Array = []
var progress: Array = []
var endings: Array = []
var heard: Array = []
var prompts: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var path := "res://scripts/memory_garden.gd"
	check(FileAccess.file_exists(path), "The Memory Garden view exists")
	if not FileAccess.file_exists(path):
		_finish()
		return
	var script = load(path)
	check(script != null and script.can_instantiate(), "The Memory Garden view compiles")
	if script == null or not script.can_instantiate():
		_finish()
		return
	var words: Array = []
	for word in JSON.parse_string(FileAccess.get_file_as_string("res://words.json")):
		if word.id in ["cat", "dog", "fish", "duck", "cow"]:
			words.append(word)
	check(words.size() == 5, "Five safe lesson records are available")
	var view = script.new()
	root.add_child(view)
	view.size = Vector2(456, 200)
	view.card_revealed.connect(func(word: Dictionary, kind: String, index: int) -> void: revealed.append([word, kind, index]))
	view.answer_chosen.connect(func(pairs: Array, correct: bool) -> void: answers.append([pairs.duplicate(true), correct]))
	view.progress_changed.connect(func(successes: int, attempts: int) -> void: progress.append([successes, attempts]))
	view.round_finished.connect(func(won: bool, found: Array) -> void: endings.append([won, found]))
	view.hear_requested.connect(func(word: Dictionary) -> void: heard.append(word))
	view.prompt_ready.connect(func() -> void: prompts.append(true))
	view.start_round(words, Data.theme("spring"), 71)
	await _settle()
	check(view.memory.cards.size() == 10 and view.card_buttons.size() == 10, "The lesson has ten stationary card buttons")
	check(view.status_label.text == "Find a pair.", "The opening prompt is short and clear")
	check(progress == [[0, 0]], "A round starts at zero flowers and zero attempts")
	check(view.controls().size() == 11 and view.controls().has(view.study_button), "Keyboard navigation includes ten cards and Study")
	check(not view.feedback_view.visible, "Teaching feedback is initially hidden")
	var positions: Array = _positions(view)
	var nodes: Array = view.card_buttons.duplicate()
	var order: Array = view.memory.cards.duplicate(true)
	_check_concealed(view)
	_check_layout(view, 5)
	var word_index: int = _index(view, words[0].id, "word")
	var other_word: int = _index(view, words[1].id, "word")
	var picture_index: int = _index(view, words[0].id, "image")
	var wrong_picture: int = _index(view, words[1].id, "image")
	view.card_buttons[word_index].pressed.emit()
	check(view.memory.selected_indices == [word_index] and view.memory.attempts == 0, "A first reveal does not spend an attempt")
	check(revealed.size() == 1 and revealed[0] == [view.memory.cards[word_index].word, "word", word_index], "The view announces exactly the revealed card")
	check(view.status_label.text == "Word: " + words[0].text, "Revealed words are named in status")
	view.card_buttons[other_word].pressed.emit()
	check(view.memory.selected_indices == [other_word] and view.memory.attempts == 0, "A same-kind choice replaces the unfinished selection for free")
	check(not view.card_buttons[word_index].word_label.visible, "The replaced word conceals again")
	view.card_buttons[other_word].pressed.emit()
	check(view.memory.selected_indices.is_empty() and view.memory.attempts == 0, "Pressing the same card cancels without an attempt")
	check(revealed.size() == 2, "Cancelling never emits a false reveal")
	view.card_buttons[word_index].pressed.emit()
	view.study_button.pressed.emit()
	check(view.memory.studying and view.memory.selected_indices.is_empty(), "Study cancels an unfinished selection")
	check(view.study_button.text == "Return to play" and view.controls() == [view.study_button], "Study offers only Return to play")
	for index in range(10):
		check(view.memory.is_revealed(index), "Study reveals the same board")
		check(view.card_buttons[index].picture.visible or view.card_buttons[index].word_label.visible, "Every studied card exposes its front")
		view.card_buttons[index].pressed.emit()
	check(view.memory.attempts == 0 and answers.is_empty(), "Synthetic Study card presses cannot submit an attempt")
	view.set_palette(Data.theme("ocean"))
	view.pause(true)
	view.study_button.pressed.emit()
	check(view.memory.studying and view.controls().is_empty(), "Pause blocks a synthetic Return to play")
	for button in view.card_buttons:
		check(button.focus_mode == Control.FOCUS_NONE, "Paused Study cards cannot take keyboard focus")
	view.pause(false)
	view.study_button.pressed.emit()
	check(not view.memory.studying and view.memory.selected_indices.is_empty(), "Return to play hides unmatched cards")
	for button in view.card_buttons:
		check(button.focus_mode == Control.FOCUS_ALL, "Return to play restores normal card focus")
	check(_positions(view) == positions and view.card_buttons == nodes and view.memory.cards == order, "Study, pause and palette changes preserve card nodes and positions")
	_check_concealed(view)
	view.card_buttons[word_index].pressed.emit()
	view.card_buttons[wrong_picture].pressed.emit()
	check(view.memory.phase == "feedback" and view.memory.attempts == 1, "An opposite-kind mismatch submits exactly one attempt")
	check(answers.size() == 1 and answers[0] == [[words[0], words[1]], false], "Mismatch reports the two real associations in selection order")
	check(view.feedback_view.visible and view.feedback_view.current_word == words[0], "Mismatch teaches the first real association")
	check(view.feedback_view.word_label.text == words[0].text and view.feedback_view.picture.texture.resource_path == "res://" + words[0].image, "Teaching pairs the actual text with its own picture")
	check(view.feedback_view.action_button.text == "Continue", "Feedback waits for an explicit Continue")
	check(not view.study_button.visible and not view.card_buttons[0].is_visible_in_tree(), "Feedback takes over the full playfield")
	var count_before: int = prompts.size()
	view.feedback_view.next_button.pressed.emit()
	check(view.feedback_view.current_word == words[1] and view.feedback_view.word_label.text == words[1].text, "Next teaches the other selected association")
	check(prompts.size() > count_before, "Feedback navigation refreshes available host controls")
	view.feedback_view.previous_button.pressed.emit()
	check(view.feedback_view.current_word == words[0], "Previous returns to the first association")
	view.card_buttons[picture_index].pressed.emit()
	view.study_button.pressed.emit()
	check(view.memory.attempts == 1 and not view.memory.studying, "Feedback rejects synthetic card and Study input")
	view.set_audio_available(false)
	view.feedback_view.hear_button.pressed.emit()
	check(heard.is_empty() and view.feedback_view.hear_button.disabled, "Unavailable audio rejects synthetic Hear input")
	check(not view.feedback_view.action_button.disabled and view.feedback_view.picture.visible, "Silent feedback still teaches and permits Continue")
	view.set_audio_available(true)
	view.feedback_view.hear_button.pressed.emit()
	check(heard == [words[0]], "Available audio requests only the displayed association")
	view.pause(true)
	view.continue_feedback()
	view.feedback_view.action_button.pressed.emit()
	check(view.memory.phase == "feedback" and view.controls().is_empty(), "Paused feedback cannot continue")
	view.pause(false)
	view.hide()
	view.continue_feedback()
	view.feedback_view.action_button.pressed.emit()
	check(view.memory.phase == "feedback" and view.controls().is_empty(), "Hidden feedback cannot continue")
	view.show()
	await create_timer(0.8).timeout
	check(view.memory.phase == "feedback" and endings.is_empty(), "Feedback has no timer or automatic result")
	view.feedback_view.action_button.pressed.emit()
	check(view.memory.phase == "waiting" and not view.feedback_view.visible, "Continue returns to the same waiting board")
	check(_positions(view) == positions and view.memory.cards == order, "Mismatches never shuffle or move cards")
	_check_concealed(view)
	for attempt in range(3):
		view.card_buttons[word_index].pressed.emit()
		view.card_buttons[wrong_picture].pressed.emit()
		view.continue_feedback()
	check(view.memory.mistakes == 4 and view.memory.phase == "waiting" and endings.is_empty(), "Memory exploration has no three-mistake loss")
	view.card_buttons[word_index].pressed.emit()
	view.pause(true)
	view.card_buttons[picture_index].pressed.emit()
	view.study_button.pressed.emit()
	view.set_palette(Data.theme("space"))
	view.set_reduced_motion(true)
	check(view.memory.selected_indices == [word_index] and view.memory.attempts == 4, "Pausing and settings preserve an unfinished attempt")
	view.pause(false)
	view.hide()
	view.card_buttons[picture_index].pressed.emit()
	check(view.memory.attempts == 4, "Hidden board rejects synthetic selection")
	view.show()
	view.card_buttons[picture_index].pressed.emit()
	check(view.memory.matched_word_ids == [words[0].id] and view.memory.phase == "feedback", "A correct pair plants one flower before Continue")
	check(answers.back() == [[words[0]], true] and progress.back() == [1, 5], "Correct submission reports one association and flowers/attempts")
	check(not view.feedback_view.next_button.visible, "Correct feedback teaches its single association")
	view.continue_feedback()
	for index in [word_index, picture_index]:
		var card = view.card_buttons[index]
		check(card.picture.visible and card.word_label.visible and card.disabled, "A planted card keeps both picture and word visible")
		check(card.focus_mode == Control.FOCUS_NONE, "Planted cards cannot take focus from playable controls")
		check(card.picture.modulate.a == 1.0 and card.word_label.modulate.a == 1.0, "Planted associations remain readable")
		card.pressed.emit()
	check(view.memory.attempts == 5, "Planted cards reject duplicate synthetic input")
	check(view.controls().size() == 9, "Planted pairs leave the active keyboard controls")
	view.study_button.pressed.emit()
	view.study_button.pressed.emit()
	check(view.memory.is_revealed(word_index) and view.memory.is_revealed(picture_index), "Study return retains completed pairs")
	_check_concealed(view)
	for dimensions in [Vector2(456, 200), Vector2(456, 600), Vector2(288, 600), Vector2(960, 320), Vector2(456, 456), Vector2(400, 400), Vector2(456, 460), Vector2(456, 200)]:
		view.size = dimensions
		await _settle()
		var columns: int = 5 if (dimensions.x >= 420 and dimensions.x >= dimensions.y * 1.3) or (dimensions.x >= 392 and dimensions.y < 460) else 2
		_check_layout(view, columns)
		check(view.memory.cards == order and view.card_buttons == nodes and view.memory.attempts == 5, "Resizing preserves the same board and progress")
		view.study_button.pressed.emit()
		_check_layout(view, columns)
		view.study_button.pressed.emit()
	for word in words.slice(1):
		view.card_buttons[_index(view, word.id, "image")].pressed.emit()
		view.card_buttons[_index(view, word.id, "word")].pressed.emit()
		check(endings.is_empty() and view.memory.phase == "feedback", "Every planted pair waits for Continue, including the fifth")
		view.feedback_view.action_button.pressed.emit()
	check(view.memory.phase == "won" and endings.size() == 1 and endings[0][0], "The fifth Continue wins exactly once")
	check(endings[0][1].size() == 5 and progress.back() == [5, 9], "Victory returns all five words and actual attempt count")
	view.continue_feedback()
	view.feedback_view.action_button.pressed.emit()
	view.study_button.pressed.emit()
	for button in view.card_buttons:
		button.pressed.emit()
	check(endings.size() == 1 and view.controls().is_empty(), "Delayed result inputs cannot win twice")
	var stale_button: Button = view.card_buttons[0]
	var old_reveal_count: int = revealed.size()
	view.start_round(words, Data.theme("spring"), 71)
	stale_button.pressed.emit()
	check(view.memory.selected_indices.is_empty() and revealed.size() == old_reveal_count, "An old queued-for-free button cannot reveal the restarted board")
	check(view.memory.cards == order and view.memory.attempts == 0 and view.memory.matched_word_ids.is_empty(), "Restart resets progress with reproducible seeded positions")
	view.card_buttons[word_index].pressed.emit()
	view.card_buttons[wrong_picture].pressed.emit()
	for dimensions in [Vector2(456, 600), Vector2(456, 200), Vector2(288, 600), Vector2(456, 200)]:
		view.size = dimensions
		await _settle()
		check(view.feedback_view.size == view.size and view.feedback_view.position == Vector2.ZERO, "Feedback fills exactly the assigned area after a resize")
		for control in [view.feedback_view.hear_button, view.feedback_view.previous_button, view.feedback_view.next_button, view.feedback_view.action_button, view.feedback_view.picture, view.feedback_view.word_label]:
			check(view.get_global_rect().grow(0.5).encloses(control.get_global_rect()), "Teaching art, text and controls stay inside the resized playfield")
		check(view.memory.attempts == 1 and view.memory.phase == "feedback", "Resizing feedback preserves the pending attempt")
	view.stop()
	view.feedback_view.action_button.pressed.emit()
	check(view.memory.phase == "stopped" and endings.size() == 1, "Stop rejects a pending feedback callback")
	view.start_round(words, Data.theme("spring"), 71)
	view.card_buttons[0].pressed.emit()
	view.stop()
	view.card_buttons[1].pressed.emit()
	view.study_button.pressed.emit()
	view.continue_feedback()
	check(view.memory.phase == "stopped" and view.memory.selected_indices.is_empty() and view.controls().is_empty(), "Stop cancels transient selection and rejects every input")
	view.start_round(words, Data.theme("spring"), 71)
	view.study_button.pressed.emit()
	view.study_button.grab_focus()
	check(root.gui_get_focus_owner() == view.study_button, "Return to play can own keyboard focus")
	await _tap_control(view.card_buttons[0])
	check(root.gui_get_focus_owner() == view.study_button, "Tapping a disabled Study card retains Return to play focus")
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame
	check(not view.memory.studying, "Enter still returns to play after tapping a Study card")
	check(view.memory.attempts == 0 and view.memory.selected_indices.is_empty(), "Study pointer and keyboard input do not score or reveal a selection")
	for button in view.card_buttons:
		check(button.focus_mode == Control.FOCUS_ALL, "Keyboard Return restores every unmatched card's focus eligibility")
	view.start_round([], Data.theme("spring"), 3)
	check(view.controls().is_empty() and view.card_buttons.is_empty(), "An invalid lesson leaves no playable stale board")
	check(not view.status_label.text.is_empty(), "Invalid content has a visible explanation")
	view.queue_free()
	await process_frame
	_finish()


func _index(view, word_id: String, kind: String) -> int:
	for index in range(view.memory.cards.size()):
		if view.memory.cards[index].word.id == word_id and view.memory.cards[index].kind == kind:
			return index
	return -1


func _positions(view) -> Array:
	var result: Array = []
	for button in view.card_buttons:
		result.append(button.get_rect())
	return result


func _check_concealed(view) -> void:
	for index in range(view.card_buttons.size()):
		if view.memory.is_revealed(index):
			continue
		var card = view.card_buttons[index]
		var kind: String = "Word" if view.memory.cards[index].kind == "word" else "Picture"
		var label: String = "%s %d" % [kind, index + 1]
		check(card.tooltip_text == label, "Concealed tooltips expose only kind and stable position")
		check(card.name == "MemoryCard%d" % (index + 1), "Concealed node names never expose the noun")
		check(not card.picture.visible and not card.word_label.visible and card.word_label.text.is_empty(), "Concealed fronts cannot expose noun text or art")
		var back: Control = card.find_child("CardBack", true, false)
		check(back != null and back.visible, "Every concealed card has a visible back")
		if back != null:
			var back_text := ""
			for child in back.find_children("*", "Label", true, false):
				back_text += child.text + " "
			check(kind in back_text and str(index + 1) in back_text, "Backs show their kind and stable number")
		for property in card.get_property_list():
			if property.name == "accessibility_name":
				check(card.get("accessibility_name") == label, "Concealed accessibility labels never expose the noun")


func _check_layout(view, columns: int) -> void:
	var bounds: Rect2 = view.get_global_rect().grow(0.5)
	check(view.card_buttons[1].position.y == view.card_buttons[0].position.y, "The board begins with a shared card row")
	check(view.card_buttons[columns].position.y > view.card_buttons[0].position.y, "The board selects its expected column count")
	for control in view.card_buttons + [view.study_button]:
		check(bounds.encloses(control.get_global_rect()), "Memory controls stay within the assigned playfield at " + str(view.size))
		check(control.size.x >= 44 and control.size.y >= 44, "Every control retains a usable touch target")
		var expected_focus: int = Control.FOCUS_NONE if control in view.card_buttons and control.disabled else Control.FOCUS_ALL
		check(control.focus_mode == expected_focus, "Only active Memory buttons are eligible for keyboard focus")
	for index in range(view.card_buttons.size()):
		var card = view.card_buttons[index]
		check(card.size.x >= 72 and card.size.y >= 72, "Cards retain at least 72-pixel targets")
		for other in range(index):
			check(not card.get_rect().intersects(view.card_buttons[other].get_rect()), "Stationary cards never overlap")
		for decoration in card.find_children("*", "Control", true, false):
			check(decoration.mouse_filter == Control.MOUSE_FILTER_IGNORE and decoration.focus_mode == Control.FOCUS_NONE, "Card art leaves input to its button")
	if columns == 2:
		check(view.study_button.size.y >= 64, "Phone Study remains a practical scaled touch target")


func _settle() -> void:
	await process_frame
	await process_frame


func _tap_control(control: Control) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _finish() -> void:
	print("Memory Garden: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
