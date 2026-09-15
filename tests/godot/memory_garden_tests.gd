extends SceneTree

const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")

var checks: int = 0
var failures: int = 0
var revealed: Array = []
var answers: Array = []
var progress: Array = []
var endings: Array = []
var prompts: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1200, 1000)
	var script = load("res://scripts/memory_garden.gd")
	check(script != null and script.can_instantiate(), "The native Memory view compiles")
	if script == null or not script.can_instantiate():
		_finish()
		return
	var view = script.new()
	check(view.has_method("begin_peek") and view.has_method("end_peek"), "Memory exposes held reveal and release, not a Study toggle")
	check(not view.get_property_list().any(func(property: Dictionary) -> bool: return property.name == "feedback_view"),
		"Memory no longer owns a lesson feedback footer")
	if not view.has_method("begin_peek") or not view.has_method("end_peek"):
		view.free()
		_finish()
		return
	root.add_child(view)
	view.size = Vector2(456, 200)
	view.set_reduced_motion(true)
	view.card_revealed.connect(func(word: Dictionary, kind: String, index: int) -> void: revealed.append([word, kind, index]))
	view.answer_chosen.connect(func(words: Array, correct: bool) -> void: answers.append([words.duplicate(true), correct]))
	view.progress_changed.connect(func(successes: int, attempts: int) -> void: progress.append([successes, attempts]))
	view.round_finished.connect(func(won: bool, found: Array) -> void: endings.append([won, found]))
	view.prompt_ready.connect(func() -> void: prompts.append(true))
	var words: Array = []
	for word in JSON.parse_string(FileAccess.get_file_as_string("res://words.json")):
		if word.id in ["cat", "dog", "fish", "duck", "cow"]:
			words.append(word)
	check(words.size() == 5, "Five safe lesson records are available")
	view.start_round(words, Data.theme("spring"), 71)
	await _settle()
	check(view.memory.cards.size() == 10 and view.card_buttons.size() == 10, "A round contains ten fixed card buttons")
	check(view.status_label.text == "Find a pair." and not view.status_label.visible and progress == [[0, 0]],
		"A round keeps its status available to Root without visible prompt text")
	check(view.controls().size() == 11 and view.controls().has(view.study_button), "Keyboard navigation includes ten cards and the eye")
	check(view.study_button.text.is_empty() and view.study_button.symbol == view.study_button.Symbol.EYE,
		"The sole reveal control is a drawn eye without toggle text")
	check(view.study_button.tooltip_text == "Hold to reveal all cards. Release to hide them.", "The eye explains both hold and release")
	check(view.find_child("MemoryFeedback", true, false) == null and view.find_child("MemoryReviewHint", true, false) == null,
		"No correction footer or reserved hint area exists")
	check(view.find_child("FlowerProgress", true, false) == null and view.find_child("FlowerCount", true, false) == null,
		"Memory leaves progress visuals to Root's Pip cluster")
	var positions := _positions(view)
	var eye_bounds: Rect2 = view.study_button.get_rect()
	var nodes: Array = view.card_buttons.duplicate()
	var order: Array = view.memory.cards.duplicate(true)
	_check_concealed(view)
	_check_layout(view)
	var first := _index(view, words[0].id, "word")
	var other := _index(view, words[1].id, "word")
	var partner := _index(view, words[0].id, "image")
	var wrong := _index(view, words[1].id, "image")
	view.card_buttons[first].pressed.emit()
	check(view.memory.selected_indices == [first] and view.memory.attempts == 0, "A first reveal is free")
	check(revealed == [[view.memory.cards[first].word, "word", first]], "Only the selected card is announced")
	check(view.status_label.text == "Word: " + words[0].text, "The selected word is named in status")
	view.card_buttons[other].pressed.emit()
	check(view.memory.selected_indices == [other] and not view.card_buttons[first].word_label.visible,
		"Same-kind reselection hides the previous front")
	view.card_buttons[other].pressed.emit()
	check(view.memory.selected_indices.is_empty() and view.memory.attempts == 0 and revealed.size() == 2,
		"Repeated selection cancels without scoring or a false reveal")
	view.card_buttons[first].pressed.emit()
	view.study_button.button_down.emit()
	check(view.memory.studying and view.memory.selected_indices.is_empty(), "Holding the eye clears an unfinished selection")
	check(view.study_button.engaged and view.controls() == [view.study_button], "The held eye is open and remains the only playable control")
	check(not view.status_label.visible and view.status_label.text == "Release to hide.", "Held status remains available but never adds visible instructions")
	for index in range(10):
		check(view.memory.is_revealed(index) and (view.card_buttons[index].picture.visible or view.card_buttons[index].word_label.visible),
			"Every held card exposes its original front")
		view.card_buttons[index].pressed.emit()
	check(view.memory.attempts == 0 and answers.is_empty(), "Held card presses cannot submit an answer")
	view.set_palette(Data.theme("ocean"))
	view.pause(true)
	check(not view.memory.studying and not view.study_button.engaged and view.controls().is_empty(), "Pausing releases the eye and blocks all controls")
	view.study_button.button_down.emit()
	check(not view.memory.studying, "A paused hold is ignored")
	view.pause(false)
	view.study_button.button_up.emit()
	check(not view.memory.studying and view.memory.selected_indices.is_empty(), "A stale release after resuming is harmless")
	check(_positions(view) == positions and view.card_buttons == nodes and view.memory.cards == order,
		"Selection, hold, pause and palette changes preserve every card target and identity")
	_check_concealed(view)
	view.card_buttons[first].pressed.emit()
	view.card_buttons[wrong].pressed.emit()
	check(view.memory.phase == "feedback" and view.memory.attempts == 1, "A mismatch submits exactly one attempt")
	check(answers == [[[words[0], words[1]], false]], "Mismatch reports both real word associations in selection order")
	check(view.study_button.visible and not view.study_button.disabled and not view.status_label.visible, "Only the eye remains visible above standalone nonfinal feedback")
	check(_positions(view) == positions and view.study_button.get_rect() == eye_bounds,
		"Wrong feedback preserves all board and header geometry")
	for index in [first, wrong]:
		check(view.card_buttons[index].get_theme_stylebox("normal").border_color == Style.WRONG,
			"The mismatched cards themselves retain wrong feedback frames")
	await create_timer(0.35).timeout
	check(view.memory.phase == "feedback" and endings.is_empty(), "Feedback remains visible for roughly 0.7 seconds")
	view.pause(true)
	view.continue_feedback()
	await create_timer(0.8).timeout
	check(view.memory.phase == "feedback" and view.controls().is_empty(), "Pause suspends feedback and ignores explicit continuation")
	view.pause(false)
	view.hide()
	view.continue_feedback()
	await create_timer(0.8).timeout
	check(view.memory.phase == "feedback" and view.controls().is_empty(), "A hidden board cannot finish a pending answer")
	view.show()
	await create_timer(0.8).timeout
	check(view.memory.phase == "waiting" and endings.is_empty(), "Visible feedback continues automatically without a footer")
	check(_positions(view) == positions and view.memory.cards == order, "Automatic feedback never shuffles or moves cards")
	_check_concealed(view)
	for attempt in range(3):
		view.card_buttons[first].pressed.emit()
		view.card_buttons[wrong].pressed.emit()
		view.continue_feedback()
	check(view.memory.mistakes == 4 and view.memory.phase == "waiting" and endings.is_empty(), "Memory has no three-mistake loss")
	view.card_buttons[first].pressed.emit()
	var word_bounds: Rect2 = view.card_buttons[first].word_label.get_rect()
	var word_font: int = view.card_buttons[first].word_label.get_theme_font_size("font_size")
	var picture_bounds: Rect2 = view.card_buttons[partner].picture.get_rect()
	view.pause(true)
	view.card_buttons[partner].pressed.emit()
	view.begin_peek()
	view.set_palette(Data.theme("space"))
	check(view.memory.selected_indices == [first] and view.memory.attempts == 4, "Pausing and settings preserve a normal unfinished attempt")
	view.pause(false)
	view.hide()
	view.card_buttons[partner].pressed.emit()
	check(view.memory.attempts == 4, "Hidden boards reject synthetic selection")
	view.show()
	view.card_buttons[partner].pressed.emit()
	check(view.memory.matched_word_ids == [words[0].id] and view.memory.phase == "feedback", "A correct answer immediately records one matched word")
	check(answers.back() == [[words[0]], true] and progress.back() == [1, 5], "Correct submission reports one association and real attempts")
	check(view.card_buttons[first].word_label.get_rect() == word_bounds and view.card_buttons[first].word_label.get_theme_font_size("font_size") == word_font
		and view.card_buttons[partner].picture.get_rect() == picture_bounds, "Planting preserves the original front layout")
	check(_positions(view) == positions and view.card_buttons.all(func(card: Button) -> bool: return card.is_visible_in_tree()),
		"Correct feedback keeps all ten remembered positions visible")
	view.continue_feedback()
	for index in [first, partner]:
		var card = view.card_buttons[index]
		check(not card.picture.visible and not card.word_label.visible and card.disabled and card.match_mark.visible,
			"Planted fronts hide after feedback but keep their match badge")
		check(card.focus_mode == Control.FOCUS_NONE, "Planted cards leave playable focus navigation")
		card.pressed.emit()
	check(view.memory.attempts == 5 and view.controls().size() == 9, "Planted cards cannot score again")
	view.begin_peek()
	check(view.memory.is_revealed(first) and view.memory.is_revealed(partner), "A new hold also reveals planted fronts")
	view.end_peek()
	check(not view.memory.is_revealed(first) and not view.memory.is_revealed(partner) and view.memory.matched_word_ids == [words[0].id],
		"Releasing hides planted faces without losing progress")
	_check_concealed(view)
	for dimensions in [Vector2(456, 200), Vector2(456, 600), Vector2(288, 600), Vector2(960, 320), Vector2(456, 456), Vector2(400, 400)]:
		view.size = dimensions
		await _settle()
		_check_layout(view)
		check(view.memory.cards == order and view.card_buttons == nodes and view.memory.attempts == 5, "Resizing preserves the board and score")
		view.begin_peek()
		_check_layout(view)
		view.end_peek()
	for word in words.slice(1):
		view.card_buttons[_index(view, word.id, "image")].pressed.emit()
		view.card_buttons[_index(view, word.id, "word")].pressed.emit()
		check(endings.is_empty() and view.memory.phase == "feedback", "Each correct pair displays bounded in-board feedback")
		if view.memory.matched_word_ids.size() < 5:
			view.continue_feedback()
	check(view.study_button.disabled and view.controls().is_empty(), "Final feedback has no remaining input targets")
	view.begin_peek()
	view._choose(-1)
	for card in view.card_buttons:
		card.pressed.emit()
	check(not view.memory.studying and view.memory.attempts == 9 and progress.back() == [5, 9], "Final hold and card shortcuts cannot alter score or delay completion")
	await create_timer(0.8).timeout
	check(view.memory.phase == "won" and endings.size() == 1 and endings[0][0] and endings[0][1].size() == 5,
		"The fifth pair automatically wins exactly once with all five words")
	view.continue_feedback()
	view.study_button.button_down.emit()
	view.study_button.button_up.emit()
	check(endings.size() == 1 and view.controls().is_empty(), "Delayed input cannot win twice")
	_check_concealed(view)
	var stale: Button = view.card_buttons[0]
	var reveal_count := revealed.size()
	view.start_round(words, Data.theme("spring"), 71)
	stale.pressed.emit()
	check(view.memory.selected_indices.is_empty() and revealed.size() == reveal_count, "An old queued-for-free button cannot reveal the restarted round")
	check(view.memory.cards == order and view.memory.attempts == 0 and view.memory.matched_word_ids.is_empty(), "Restart clears progress and preserves seeded reproducibility")
	view.card_buttons[first].pressed.emit()
	view.card_buttons[wrong].pressed.emit()
	await create_timer(0.35).timeout
	view.start_round(words, Data.theme("spring"), 71)
	view.card_buttons[first].pressed.emit()
	await create_timer(0.8).timeout
	check(view.memory.phase == "matching" and view.memory.selected_indices == [first] and view.memory.attempts == 0,
		"A restarted round cancels the old feedback deadline without disturbing its new first selection")
	view.card_buttons[wrong].pressed.emit()
	view.stop()
	await create_timer(0.8).timeout
	view.continue_feedback()
	check(view.memory.phase == "stopped" and endings.size() == 1, "Stop cancels a pending timer without a stale result")
	view.start_round(words, Data.theme("spring"), 71)
	view.card_buttons[0].pressed.emit()
	view.stop()
	view.card_buttons[1].pressed.emit()
	view.begin_peek()
	view.end_peek()
	check(view.memory.phase == "stopped" and view.memory.selected_indices.is_empty() and view.controls().is_empty(), "Stop cancels transient selections and rejects every input")
	view.start_round([], Data.theme("spring"), 3)
	check(view.card_buttons.is_empty() and view.controls().is_empty() and not view.status_label.text.is_empty(), "Invalid content explains the error and leaves no stale playable board")
	await _check_feedback_shortcuts(view, words)
	await _check_catalog_text(view)
	view.queue_free()
	await process_frame
	_finish()


func _index(view, word_id: String, kind: String) -> int:
	for index in range(view.memory.cards.size()):
		if view.memory.cards[index].word.id == word_id and view.memory.cards[index].kind == kind:
			return index
	return -1


func _positions(view) -> Array:
	return view.card_buttons.map(func(card: Button) -> Rect2: return card.get_global_rect())


func _check_feedback_shortcuts(view, words: Array) -> void:
	view.size = Vector2(456, 200)
	for action in ["wrong-word", "wrong-image", "wrong-third", "correct-third", "wrong-peek", "correct-peek"]:
		view.start_round(words, Data.theme("spring"), 71)
		await _settle()
		var first := _index(view, words[0].id, "word")
		var second := _index(view, words[0 if action.begins_with("correct") else 1].id, "image")
		var target := first if action == "wrong-word" else second if action == "wrong-image" else _index(view, words[2].id, "word")
		view.card_buttons[first].pressed.emit()
		view.card_buttons[second].pressed.emit()
		var score: Array = [view.memory.attempts, view.memory.mistakes, view.memory.matched_word_ids.duplicate(), answers.size(), progress.size(), endings.size()]
		var order: Array = view.memory.cards.duplicate(true)
		var positions := _positions(view)
		var reveal_count := revealed.size()
		view._choose(-1)
		view._choose(10)
		if action.begins_with("correct"):
			view.card_buttons[first].pressed.emit()
			view.card_buttons[second].pressed.emit()
		check(view.memory.phase == "feedback" and revealed.size() == reveal_count, action + ": invalid and planted targets cannot dismiss feedback")
		for blocked in ["paused", "hidden"]:
			if blocked == "paused": view.pause(true)
			else: view.hide()
			view.card_buttons[target].pressed.emit()
			view.begin_peek()
			check(view.memory.phase == "feedback" and not view.memory.studying and revealed.size() == reveal_count, action + ": blocked feedback rejects all shortcuts")
			if blocked == "paused": view.pause(false)
			else: view.show()
		if action.ends_with("peek"):
			await _mouse(view.study_button, true)
			check(view.memory.studying and view.memory.phase == "waiting" and view.memory.selected_indices.is_empty(), action + ": the first press immediately begins a peek")
			check(root.gui_get_focus_owner() == view.study_button and view.controls() == [view.study_button], action + ": held focus stays on the eye")
			view.card_buttons[target].pressed.emit()
			check(revealed.size() == reveal_count, action + ": a peek never falsely pronounces a selected card")
			await _mouse(view.study_button, false)
			check(not view.memory.studying and view.memory.phase == "waiting", action + ": releasing returns directly to play")
		else:
			await _mouse(view.card_buttons[target], true)
			await _mouse(view.card_buttons[target], false)
			check(view.memory.phase == "matching" and view.memory.selected_indices == [target], action + ": one tap resolves feedback and selects the tapped card")
			check(revealed.size() == reveal_count + 1 and revealed.back()[2] == target and root.gui_get_focus_owner() == view.card_buttons[target],
				action + ": the actual tapped card retains focus and emits exactly one reveal")
		check([view.memory.attempts, view.memory.mistakes, view.memory.matched_word_ids, answers.size(), progress.size(), endings.size()] == score,
			action + ": the shortcut never double-scores an answer")
		check(view.memory.cards == order and _positions(view) == positions, action + ": every target remains stationary")
		await create_timer(0.8).timeout
		check(view.memory.phase == ("waiting" if action.ends_with("peek") else "matching"), action + ": the cancelled timer cannot affect the next selection")


func _check_concealed(view) -> void:
	for index in range(view.card_buttons.size()):
		if view.memory.is_revealed(index):
			continue
		var card = view.card_buttons[index]
		var kind: String = "Word" if view.memory.cards[index].kind == "word" else "Picture"
		var planted: bool = view.memory.matched_word_ids.has(view.memory.cards[index].word.id)
		var label: String = "%s %d" % [kind, index + 1] + (". Planted." if planted else "")
		check(card.tooltip_text == label and card.name == "MemoryCard%d" % (index + 1), "Concealed labels reveal only kind, position and matched progress")
		check(not card.picture.visible and not card.word_label.visible and card.word_label.text.is_empty(), "Hidden fronts expose no noun text or picture")
		var back: Control = card.find_child("CardBack", true, false)
		check(back != null and back.visible, "Every concealed card shows a back")
		if back != null:
			var text := ""
			for child in back.find_children("*", "Label", true, false):
				text += child.text + " "
			check(kind in text and str(index + 1) in text, "Backs keep their kind and stable position number")
		for property in card.get_property_list():
			if property.name == "accessibility_name":
				check(card.get("accessibility_name") == label, "Hidden accessibility names do not leak the word")


func _check_layout(view) -> void:
	var bounds: Rect2 = view.get_global_rect().grow(0.5)
	var ui_scale: float = Style.ui_scale(view)
	var gap: float = ceilf(8 / ui_scale)
	var columns: int = 2 if view.size.x < view.size.y else 5
	var rows: int = 10 / columns
	var cell := Vector2((view.size.x - gap * (columns - 1)) / columns, (view._board.size.y - gap * (rows - 1)) / rows)
	check(is_equal_approx(view.study_button.size.x, view.study_button.size.y), "The eye keeps a square hitbox")
	check(not view.status_label.visible, "Status never occupies a visible row")
	check(is_equal_approx(view._board.position.y, ceilf(44 / ui_scale)), "Standalone Memory reserves only its 44 CSS pixel eye row")
	check(is_equal_approx(view._board.position.x, 0) and is_equal_approx(view._board.size.x, view.size.x)
		and is_equal_approx(view._board.position.y + view._board.size.y, view.size.y), "The board fills all space below its single header")
	check(is_equal_approx(view.card_buttons.back().get_global_rect().end.y, view.get_global_rect().end.y), "No footer space remains beneath the last row")
	for control in view.card_buttons + [view.study_button]:
		check(bounds.encloses(control.get_global_rect()), "Every target fits its assigned view at " + str(view.size))
		check(control.size.x * ui_scale >= 44 and control.size.y * ui_scale >= 44, "Available layouts retain at least 44 CSS pixel touch targets")
		check(control.focus_mode == (Control.FOCUS_NONE if control.disabled else Control.FOCUS_ALL), "Only enabled controls can take focus")
	for index in range(view.card_buttons.size()):
		var card = view.card_buttons[index]
		var position := Vector2((index % columns) * (cell.x + gap), (index / columns) * (cell.y + gap))
		check(card.position.is_equal_approx(position) and card.size.is_equal_approx(cell),
			"Every card fills its regular %dx%d cell without ragged or centered partial rows at %s" % [columns, rows, view.size])
		check(not card.get_global_rect().intersects(view.study_button.get_global_rect()), "The eye never overlaps a card")
		for other in range(index):
			check(not card.get_rect().intersects(view.card_buttons[other].get_rect()), "Card targets never overlap")
		for decoration in card.find_children("*", "Control", true, false):
			check(decoration.mouse_filter == Control.MOUSE_FILTER_IGNORE and decoration.focus_mode == Control.FOCUS_NONE, "Card decoration leaves input to the fixed Button")


func _check_catalog_text(view) -> void:
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	for dimensions in [Vector2(456, 200), Vector2(456, 216), Vector2(400, 200), Vector2(456, 480), Vector2(288, 600)]:
		view.size = dimensions
		for start in range(0, catalog.size(), 5):
			view.start_round(catalog.slice(start, start + 5), Data.theme("spring"), 71)
			await _settle()
			var positions := _positions(view)
			view.begin_peek()
			for card in view.card_buttons:
				check(card.size.x >= 44 and card.size.y >= 44, "Catalog cards keep usable targets")
				if card.card_data.kind != "word":
					continue
				var label: Label = card.word_label
				var font_size: int = label.get_theme_font_size("font_size")
				var font: Font = label.get_theme_font("font")
				check(font_size >= 12 and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= label.size.x,
					"The full catalog word fits its Memory card: " + label.text)
				check(font.get_height(font_size) <= label.size.y, "The complete word height fits its card")
			check(_positions(view) == positions, "Revealing catalog words never changes card geometry")
			view.end_peek()


func _mouse(control: Control, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = control.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame


func _settle() -> void:
	await process_frame
	await process_frame


func _finish() -> void:
	print("Memory Garden: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
