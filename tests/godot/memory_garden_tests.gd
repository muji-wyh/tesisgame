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
	view.purchase_peek = func(_ordinal: int, _price: int) -> Dictionary: return {"ok": true, "duplicate": false}
	check(view.has_method("begin_peek") and view.has_method("end_peek"), "Memory exposes timed reveal and explicit cancellation")
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
	check(view.status_label.text == "Start game" and not view.status_label.visible and progress == [[0, 0]],
		"A round keeps its status available to Root without visible prompt text")
	check(view.controls() == [view.start_button] and view.start_button.visible and not view.study_button.visible,
		"Start game is the only initial keyboard target")
	check(view.snapshot().awaiting_start and not view.snapshot().started and view.snapshot().reward_tier == 6,
		"The view exposes the explicit initial gate and available reward tier")
	check(view.snapshot().cards.all(func(card: Dictionary) -> bool: return not card.has("word_id") and not card.has("text")),
		"Prepared snapshot cards cannot leak their hidden answers")
	view.card_buttons[0].pressed.emit()
	view.begin_peek()
	check(not view.memory.started and view.memory.selected_indices.is_empty() and revealed.is_empty(),
		"Card and eye callbacks cannot bypass Start game")
	view.start_button.pressed.emit()
	check(view.memory.started and view.memory.studying and view.memory.peek_remaining == 10.0 and view.memory.peeks == 1,
		"Start game begins exactly one free ten-second observation")
	check(view.snapshot().cards.all(func(card: Dictionary) -> bool: return card.has("word_id") and card.has("text") and card.face_up),
		"Observation snapshots identify only the visibly revealed fronts")
	view.start_button.pressed.emit()
	for card in view.card_buttons:
		card.pressed.emit()
	check(view.memory.peeks == 1 and view.memory.attempts == 0 and revealed.is_empty(),
		"Repeated Start and observation taps cannot reveal, score or restart")
	view.end_peek()
	check(view.controls().size() == 11 and view.controls().has(view.study_button) and not view.start_button.visible,
		"Start matching restores ten concealed card targets and the paid eye")
	check(view.study_button.text.is_empty() and view.study_button.symbol == view.study_button.Symbol.EYE,
		"The sole reveal control is a drawn eye without toggle text")
	check(view.study_button.tooltip_text.is_empty()
		and view.study_button.accessibility_name.to_lower().contains("reveal")
		and view.study_button.accessibility_name.contains("5")
		and not view.study_button.accessibility_name.contains("Hold"),
		"The eye explains its timed reveal accessibly without a hover popup")
	check(view.find_child("MemoryFeedback", true, false) == null and view.find_child("MemoryReviewHint", true, false) == null,
		"No correction footer or reserved hint area exists")
	check(view.find_child("FlowerProgress", true, false) == null and view.find_child("FlowerCount", true, false) == null,
		"Memory leaves progress visuals to Root's Pip cluster")
	var positions := _positions(view)
	var eye_bounds: Rect2 = view.study_button.get_rect()
	var nodes: Array = view.card_buttons.duplicate()
	var order: Array = view.memory.cards.duplicate(true)
	_check_resting_faces(view)
	_check_layout(view)
	var first := _index(view, words[0].id, "word")
	var partner := _index(view, words[0].id, "image")
	var wrong := _index(view, words[1].id, "image")
	view.card_buttons[first].pressed.emit()
	check(view.memory.selected_indices == [first] and view.memory.attempts == 0 and not view.card_buttons[first].face_up,
		"A first selection keeps the answer concealed without counting an attempt")
	check(revealed.is_empty() and view.card_buttons[first].word_label.text.is_empty(), "The first selection emits no pronunciation or answer text")
	check(view.status_label.text == "Choose one more card", "Selection status gives the next action without disclosing a word")
	check(view.card_buttons[first].get_theme_stylebox("normal").border_color == Data.theme("spring").accent,
		"The first concealed card acknowledges selection with a border")
	view.card_buttons[first].pressed.emit()
	check(view.memory.selected_indices.is_empty() and view.memory.attempts == 0 and revealed.is_empty(),
		"Repeated selection cancels without scoring or a false reveal")
	view.card_buttons[first].pressed.emit()
	view.study_button.pressed.emit()
	check(view.memory.studying and view.memory.selected_indices.is_empty(), "Clicking the eye clears an unfinished selection")
	check(view.study_button.engaged and view.controls() == [view.study_button], "The active eye is open and remains the only playable control")
	check(not view.status_label.visible and view.status_label.text.contains("5"), "Later observation keeps its five-second clock available to the host")
	for index in range(10):
		check(view.memory.is_revealed(index) and (view.card_buttons[index].picture.visible or view.card_buttons[index].word_label.visible),
			"Every revealed card exposes its original front")
		view.card_buttons[index].pressed.emit()
	check(view.memory.attempts == 0 and answers.is_empty(), "Card presses during the countdown cannot submit an answer")
	view.set_palette(Data.theme("ocean"))
	view.pause(true)
	check(not view.memory.studying and not view.study_button.engaged and view.controls().is_empty(), "Pausing releases the eye and blocks all controls")
	view.study_button.pressed.emit()
	check(not view.memory.studying, "A paused reveal is ignored")
	view.pause(false)
	view.study_button.button_up.emit()
	check(not view.memory.studying and view.memory.selected_indices.is_empty(), "A stale release after resuming is harmless")
	check(_positions(view) == positions and view.card_buttons == nodes and view.memory.cards == order,
		"Selection, timed reveal, pause and palette changes preserve every card target and identity")
	_check_resting_faces(view)
	view.card_buttons[first].pressed.emit()
	view.card_buttons[wrong].pressed.emit()
	check(view.memory.phase == "feedback" and view.memory.attempts == 1, "A mismatch submits exactly one attempt")
	check(answers == [[[words[0], words[1]], false]], "Mismatch reports both real word associations in selection order")
	check(view.study_button.visible and view.study_button.disabled and view.controls().size() == 10 and not view.status_label.visible,
		"Mismatch feedback keeps every card available to dismiss it while blocking the eye")
	check(view.status_label.text == "Not a pair." and revealed.size() == 1
		and view.card_buttons[first].face_up and view.card_buttons[wrong].face_up,
		"Second-card commitment reveals both faces together and emits one attempt pronunciation")
	check(_positions(view) == positions and view.study_button.get_rect() == eye_bounds,
		"Wrong feedback preserves all board and header geometry")
	for index in [first, wrong]:
		check(view.card_buttons[index].get_theme_stylebox("normal").border_color == Style.WRONG,
			"The mismatched cards themselves retain wrong feedback frames")
	await create_timer(0.85).timeout
	view._feedback_timer.timeout.emit()
	check(view.memory.phase == "feedback" and endings.is_empty() and view._feedback_timer.is_stopped(),
		"A mismatch remains visible beyond the old deadline and ignores stale timer callbacks")
	view.pause(true)
	view.card_buttons[first].pressed.emit()
	view.continue_feedback()
	await create_timer(0.8).timeout
	check(view.memory.phase == "feedback" and view.controls().is_empty(), "Pause suspends feedback and ignores explicit continuation")
	view.pause(false)
	view.hide()
	view.card_buttons[wrong].pressed.emit()
	view.continue_feedback()
	await create_timer(0.8).timeout
	check(view.memory.phase == "feedback" and view.controls().is_empty(), "A hidden board cannot finish a pending answer")
	view.show()
	await create_timer(0.8).timeout
	check(view.memory.phase == "feedback" and view.card_buttons[first].face_up and view.card_buttons[wrong].face_up,
		"Returning to the visible board still waits for a card click")
	await _mouse(view.card_buttons[first], true)
	await _mouse(view.card_buttons[first], false)
	check(view.memory.phase == "waiting" and view.memory.selected_indices.is_empty() and endings.is_empty(),
		"Clicking an open mismatch card hides the pair without making a new selection")
	check(_positions(view) == positions and view.memory.cards == order, "Dismissal never shuffles or moves cards")
	_check_resting_faces(view)
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
		check(card.picture.visible == (card.card_data.kind == "image")
			and card.word_label.visible == (card.card_data.kind == "word") and card.disabled and card.match_mark.visible,
			"Planted words and pictures stay face up after feedback with their match badge")
		check(card.focus_mode == Control.FOCUS_NONE, "Planted cards leave playable focus navigation")
		card.pressed.emit()
	check(view.memory.attempts == 5 and view.controls().size() == 9, "Planted cards cannot score again")
	view.begin_peek()
	check(view.memory.is_revealed(first) and view.memory.is_revealed(partner), "A new reveal also reveals planted fronts")
	view.end_peek()
	check(view.memory.is_revealed(first) and view.memory.is_revealed(partner) and view.memory.matched_word_ids == [words[0].id],
		"Ending a peek keeps both planted faces visible with their progress")
	_check_resting_faces(view)
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
	check(not view.memory.studying and view.memory.attempts == 9 and progress.back() == [5, 9], "Final eye and card shortcuts cannot alter score or delay completion")
	await create_timer(0.8).timeout
	check(view.memory.phase == "won" and endings.size() == 1 and endings[0][0] and endings[0][1].size() == 5,
		"The fifth pair automatically wins exactly once with all five words")
	view.continue_feedback()
	view.study_button.pressed.emit()
	view.study_button.button_up.emit()
	check(endings.size() == 1 and view.controls().is_empty(), "Delayed input cannot win twice")
	_check_resting_faces(view)
	var stale: Button = view.card_buttons[0]
	var reveal_count := revealed.size()
	view.start_round(words, Data.theme("spring"), 71)
	stale.pressed.emit()
	check(view.memory.selected_indices.is_empty() and revealed.size() == reveal_count, "An old queued-for-free button cannot reveal the restarted round")
	check(view.memory.cards == order and view.memory.attempts == 0 and view.memory.matched_word_ids.is_empty(), "Restart clears progress and preserves seeded reproducibility")
	_start_matching(view)
	view.card_buttons[first].pressed.emit()
	view.card_buttons[wrong].pressed.emit()
	await create_timer(0.35).timeout
	view.start_round(words, Data.theme("spring"), 71)
	_start_matching(view)
	view.card_buttons[first].pressed.emit()
	await create_timer(0.8).timeout
	check(view.memory.phase == "matching" and view.memory.selected_indices == [first] and view.memory.attempts == 0,
		"A restarted round clears the old mismatch without disturbing its new first selection")
	view.card_buttons[wrong].pressed.emit()
	view.stop()
	await create_timer(0.8).timeout
	view.continue_feedback()
	check(view.memory.phase == "stopped" and endings.size() == 1, "Stop clears a pending mismatch without a stale result")
	view.start_round(words, Data.theme("spring"), 71)
	_start_matching(view)
	view.card_buttons[0].pressed.emit()
	var stopped_button: Button = view.card_buttons[1]
	view.stop()
	stopped_button.pressed.emit()
	view.begin_peek()
	view.end_peek()
	check(view.memory.phase == "stopped" and view.memory.selected_indices.is_empty() and view.controls().is_empty(), "Stop cancels transient selections and rejects every input")
	view.start_round([], Data.theme("spring"), 3)
	check(view.card_buttons.is_empty() and view.controls().is_empty() and not view.status_label.text.is_empty(), "Invalid content explains the error and leaves no stale playable board")
	await _check_feedback_continuation(view, words)
	await _check_matched_fronts(view, words)
	await _check_selection_and_hover(view, words)
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


func _start_matching(view) -> void:
	view.start_game()
	view.end_peek()


func _check_feedback_continuation(view, words: Array) -> void:
	view.size = Vector2(456, 200)
	for outcome in ["wrong", "correct"]:
		view.start_round(words, Data.theme("spring"), 71)
		_start_matching(view)
		await _settle()
		var first := _index(view, words[0].id, "word")
		var second := _index(view, words[0 if outcome == "correct" else 1].id, "image")
		var target := _index(view, words[2].id, "word")
		var before_reveals := revealed.size()
		view.card_buttons[first].pressed.emit()
		check(not view.card_buttons[first].face_up and revealed.size() == before_reveals,
			outcome + ": selecting a first card cannot expose or pronounce its answer")
		view.card_buttons[second].pressed.emit()
		check(view.card_buttons[first].face_up and view.card_buttons[second].face_up and revealed.size() == before_reveals + 1,
			outcome + ": committing a second distinct card reveals both in one attempt")
		check(view.memory.last_correct == (outcome == "correct") and view.memory.mistakes == (0 if outcome == "correct" else 1),
			outcome + ": correctness includes the word-picture kind requirement")
		var score: Array = [view.memory.attempts, view.memory.mistakes, view.memory.matched_word_ids.duplicate(), answers.size(), progress.size(), endings.size()]
		var order: Array = view.memory.cards.duplicate(true)
		var positions := _positions(view)
		var reveal_count := revealed.size()
		for index in [-1, 10]:
			view._choose(index)
		view.study_button.pressed.emit()
		view.begin_peek()
		check(view.memory.phase == "feedback" and not view.memory.studying and revealed.size() == reveal_count,
			outcome + ": invalid indices and eye input cannot dismiss feedback")
		if outcome == "correct":
			for index in [first, second, target]:
				view._choose(index)
			await _mouse(view.card_buttons[target], true)
			await _mouse(view.card_buttons[target], false)
			check(view.controls().is_empty() and not view._feedback_timer.is_stopped(),
				"Correct feedback keeps its timer and blocks card shortcuts")
		else:
			check(view.controls().size() == 10 and view._feedback_timer.is_stopped(),
				"Wrong feedback exposes all card targets without scheduling a timeout")
		check([view.memory.attempts, view.memory.mistakes, view.memory.matched_word_ids, answers.size(), progress.size(), endings.size()] == score,
			outcome + ": blocked input cannot double-score or purchase an observation")
		check(view.memory.cards == order and _positions(view) == positions, outcome + ": every target remains stationary")
		await create_timer(0.85).timeout
		if outcome == "wrong":
			check(view.memory.phase == "feedback" and view.memory.selected_indices == [first, second]
				and view.card_buttons[first].face_up and view.card_buttons[second].face_up,
				"Waiting past the old feedback duration keeps the wrong pair exposed")
			await _mouse(view.card_buttons[target], true)
			await _hover(view.study_button, true)
			await _mouse(view.study_button, false)
			check(view.memory.phase == "feedback" and view.memory.selected_indices == [first, second],
				"Releasing outside the pressed card cancels dismissal and keeps the wrong pair exposed")
			await _hover(view.card_buttons[target])
			await _mouse(view.card_buttons[target], true)
			check(view.memory.phase == "feedback", "Pressing a new card waits for its completed click before hiding the mismatch")
			await _mouse(view.card_buttons[target], false)
		else:
			check(view.memory.phase == "waiting" and view.memory.selected_indices.is_empty(),
				"Correct feedback restores matching automatically")
			view.card_buttons[target].pressed.emit()
		for index in [first, second]:
			check(view.card_buttons[index].face_up == (outcome == "correct"), outcome + ": only a correct pair remains face up")
		check(view.memory.selected_indices == [target] and not view.card_buttons[target].face_up and revealed.size() == reveal_count,
			outcome + ": the next card click becomes a concealed first selection")
		check([view.memory.attempts, view.memory.mistakes, view.memory.matched_word_ids, answers.size(), progress.size(), endings.size()] == score,
			outcome + ": continuing with a new card emits no additional score or answer feedback")
		view.card_buttons[target].pressed.emit()
		check(view.memory.phase == "waiting" and view.memory.selected_indices.is_empty(),
			outcome + ": the newly selected card can be cancelled normally")


func _check_matched_fronts(view, words: Array) -> void:
	view.set_reduced_motion(false)
	view.start_round(words, Data.theme("spring"), 83)
	_start_matching(view)
	await _settle()
	var positions := _positions(view)
	var order: Array = view.memory.cards.duplicate(true)
	view.card_buttons[_index(view, words[0].id, "word")].pressed.emit()
	view.card_buttons[_index(view, words[0].id, "image")].pressed.emit()
	await create_timer(1.0).timeout
	check(view.memory.phase == "waiting" and view.memory.matched_word_ids == [words[0].id],
		"Animated correct feedback automatically settles with one planted pair")
	_check_resting_faces(view)
	view.card_buttons[_index(view, words[1].id, "word")].pressed.emit()
	view.card_buttons[_index(view, words[2].id, "image")].pressed.emit()
	await create_timer(1.0).timeout
	check(view.memory.phase == "feedback" and view.memory.attempts == 2 and view.memory.mistakes == 1,
		"A later wrong pair stays exposed while preserving the planted pair")
	var planted := _index(view, words[0].id, "image")
	var score: Array = [answers.size(), revealed.size(), progress.size(), endings.size()]
	check(not view.card_buttons[planted].disabled and view.controls().has(view.card_buttons[planted]),
		"A planted card is available to dismiss a waiting mismatch")
	await _mouse(view.card_buttons[planted], true)
	await _mouse(view.card_buttons[planted], false)
	await create_timer(0.25).timeout
	check(view.memory.phase == "waiting" and view.memory.selected_indices.is_empty()
		and view.card_buttons[planted].face_up and view.card_buttons[planted].disabled
		and [answers.size(), revealed.size(), progress.size(), endings.size()] == score,
		"Clicking a planted card only hides the wrong pair, preserving its own face and the score")
	_check_resting_faces(view)
	view.begin_peek()
	await create_timer(0.25).timeout
	for index in range(view.card_buttons.size()):
		var card = view.card_buttons[index]
		check(view.memory.is_revealed(index) and (card.picture.visible or card.word_label.visible),
			"An animated peek reveals the complete partially planted board")
	view.end_peek()
	await create_timer(0.25).timeout
	_check_resting_faces(view)
	view.begin_peek()
	await create_timer(0.25).timeout
	view.pause(true)
	check(not view.memory.studying and view.controls().is_empty(), "Pausing cancels a peek on a partially planted board")
	_check_resting_faces(view)
	view.pause(false)
	view.end_peek()
	await create_timer(0.25).timeout
	_check_resting_faces(view)
	check(view.memory.phase == "waiting" and view.memory.matched_word_ids == [words[0].id]
		and view.memory.attempts == 2 and view.memory.mistakes == 1 and view.memory.selected_indices.is_empty(),
		"Peek cancellation and pause recovery preserve only the earned pair and its score")
	check(view.memory.cards == order and _positions(view) == positions, "Persistent matched fronts preserve every remembered position")
	view.set_reduced_motion(true)


func _check_selection_and_hover(view, words: Array) -> void:
	view.size = Vector2(456, 320)
	view.start_round(words, Data.theme("spring"), 91)
	await _settle()
	var first := _index(view, words[0].id, "word")
	var partner := _index(view, words[0].id, "image")
	var other_word := _index(view, words[1].id, "word")
	var other_picture := _index(view, words[1].id, "image")
	var first_back = view.card_buttons[first].find_child("CardBack", true, false)
	var original_fill: Color = first_back.fill_color
	view.start_game()
	await _hover(view.card_buttons[first])
	check(view.card_buttons[first].disabled and view.card_buttons[partner].disabled
		and _highlighted_indices(view) == [mini(first, partner), maxi(first, partner)],
		"Real pointer hover lights exactly the word-picture pair while observation keeps both cards disabled")
	await _mouse(view.card_buttons[first], true)
	await _mouse(view.card_buttons[first], false)
	check(view.memory.selected_indices.is_empty() and view.memory.attempts == 0,
		"Hovering an observed pair does not make observation cards clickable")
	view.end_peek()
	check(_highlighted_indices(view).is_empty(), "Closing observation removes the pair hint before its answers are concealed")
	await _hover(view.card_buttons[partner])
	check(_highlighted_indices(view).is_empty(), "Hovering a concealed card cannot disclose its partner")
	var before: Array = [answers.size(), revealed.size(), progress.size()]
	view.card_buttons[first].pressed.emit()
	check(view.card_buttons[first].is_selection_visible() and first_back.fill_color != original_fill
		and not view.card_buttons[first].face_up and view.snapshot().cards[first].selection_visible,
		"First selection keeps a persistent outline and changed back surface without revealing the word")
	view.card_buttons[other_word].pressed.emit()
	check(view.memory.selected_indices == [other_word] and not view.card_buttons[first].is_selection_visible()
		and first_back.fill_color == original_fill and view.card_buttons[other_word].is_selection_visible(),
		"Choosing a second word transfers the visible selection and restores the earlier back")
	check(view.memory.attempts == 0 and view.memory.mistakes == 0 and view.memory.reward_tier() == 6
		and [answers.size(), revealed.size(), progress.size()] == before and view._feedback_timer.is_stopped(),
		"Same-kind word changes emit no answer, audio, progress, feedback deadline, or chest penalty")
	view.card_buttons[other_word].pressed.emit()
	check(not view.card_buttons[other_word].is_selection_visible(), "Cancelling a selection removes its persistent outline")
	view.card_buttons[partner].pressed.emit()
	view.card_buttons[other_picture].pressed.emit()
	check(view.memory.selected_indices == [other_picture] and view.card_buttons[other_picture].is_selection_visible()
		and not view.card_buttons[partner].is_selection_visible() and view.memory.attempts == 0
		and [answers.size(), revealed.size(), progress.size()] == before,
		"Same-kind picture changes also transfer the concealed selection without an attempt")
	view.card_buttons[other_picture].pressed.emit()
	view.card_buttons[first].pressed.emit()
	view.card_buttons[partner].pressed.emit()
	view.continue_feedback()
	await _hover(view.card_buttons[first])
	check(view.card_buttons[first].disabled and view.card_buttons[partner].disabled
		and _highlighted_indices(view) == [mini(first, partner), maxi(first, partner)]
		and view.card_buttons[first].match_mark.active and view.card_buttons[partner].match_mark.active,
		"Hovering a matched disabled card lights both fronts and their shared pair badges")
	await _hover(view.card_buttons[partner])
	check(_highlighted_indices(view) == [mini(first, partner), maxi(first, partner)],
		"The picture and word both drive the same paired hover glow")
	await _hover(view.card_buttons[other_word])
	check(_highlighted_indices(view).is_empty() and view.memory.attempts == 1 and view.memory.mistakes == 0,
		"Leaving the matched pair removes its light without changing the score")
	await _hover(view.card_buttons[first])
	view.pause(true)
	check(_highlighted_indices(view).is_empty(), "Pausing clears hover light from both matched fronts")
	view.pause(false)
	await _hover(view.card_buttons[other_word])
	view.begin_peek()
	await _hover(view.card_buttons[other_picture])
	check(_highlighted_indices(view) == [mini(other_word, other_picture), maxi(other_word, other_picture)],
		"A paid eyes-open interval also enables hover pairing for unmatched fronts")
	var stale = view.card_buttons[other_picture]
	view.start_round(words, Data.theme("spring"), 91)
	stale.mouse_entered.emit()
	check(_highlighted_indices(view).is_empty() and not view.memory.started,
		"Restart disconnects stale hover callbacks and clears the old pair highlight")


func _highlighted_indices(view) -> Array:
	var result: Array = []
	for index in range(view.card_buttons.size()):
		if view.card_buttons[index].is_pair_highlighted():
			result.append(index)
	return result


func _hover(control: Control, pressed: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = control.get_global_rect().get_center()
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event, true)
	await _settle()


func _check_resting_faces(view) -> void:
	for index in range(view.card_buttons.size()):
		var card = view.card_buttons[index]
		var kind: String = "Word" if view.memory.cards[index].kind == "word" else "Picture"
		var planted: bool = view.memory.matched_word_ids.has(view.memory.cards[index].word.id)
		var label: String = "%s %d" % [kind, index + 1]
		var back: Control = card.find_child("CardBack", true, false)
		check(view.memory.is_revealed(index) == planted and card.face_up == planted,
			"A resting board keeps exactly its planted cards face up")
		if planted:
			label += ": " + view.memory.cards[index].word.text + ". Pair %d." % (view.memory.matched_word_ids.find(view.memory.cards[index].word.id) + 1)
			var pair_number: int = view.memory.matched_word_ids.find(view.memory.cards[index].word.id) + 1
			check(card.match_mark.pair_number == pair_number, "Both matched card kinds share a numbered badge readable without color")
			for partner in view.card_buttons:
				if partner.card_data.word.id == card.card_data.word.id:
					check(partner.match_mark.pair_number == pair_number and partner.match_mark.tint == card.match_mark.tint,
						"The pair retains one stable number and color on both cards")
			check(card.picture.visible == (kind == "Picture") and card.word_label.visible == (kind == "Word")
				and card.word_label.text == view.memory.cards[index].word.text,
				"Each planted card displays its original picture or word front")
			check(back != null and not back.visible and card.disabled and card.match_mark.visible,
				"Planted cards hide their backs, keep their badges and reject further selection")
		else:
			check(not card.picture.visible and not card.word_label.visible and card.word_label.text.is_empty(), "Hidden fronts expose no noun text or picture")
			check(back != null and back.visible, "Every unmatched resting card shows a back")
			if back != null:
				var text := ""
				for child in back.find_children("*", "Label", true, false):
					text += child.text + " "
				check(kind in text and str(index + 1) in text, "Backs keep their kind and stable position number")
		check(card.tooltip_text.is_empty() and card.name == "MemoryCard%d" % (index + 1),
			"Resting cards preserve their position without exposing hover popups")
		for property in card.get_property_list():
			if property.name == "accessibility_name":
				check(card.get("accessibility_name") == label, "Accessibility names follow the same revealed and concealed card state")


func _check_layout(view) -> void:
	var bounds: Rect2 = view.get_global_rect().grow(0.5)
	var ui_scale: float = Style.ui_scale(view)
	var gap: float = ceilf(8 / ui_scale)
	var columns: int = Style.word_board_columns(view._board.size, ui_scale, Vector2.ONE * gap)
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
	# Editorial metadata now covers legacy entries too; their preserved prefix
	# remains the canonical original set (also verified by the asset contract).
	var legacy: Array = catalog.slice(0, 350)
	check(legacy.size() == 350 and legacy.front().id == "cat" and legacy.back().id == "abacus", "Synthetic tiny component fixtures retain the complete legacy vocabulary")
	var lesson: Array = catalog.filter(func(word: Dictionary) -> bool: return word.id in ["cat", "dog", "fish", "duck", "cow"])
	# The tiny standalone fixtures predate the expanded vocabulary and are not
	# produced by the game host. Keep their original 350-word regression coverage;
	# the full vocabulary also runs in six real viewports in vocabulary_layout_tests.
	for fixture in [[Vector2(456, 200), legacy], [Vector2(456, 216), legacy], [Vector2(400, 200), legacy],
		[Vector2(456, 480), catalog], [Vector2(288, 600), catalog],
		[Vector2(456, 392), catalog], [Vector2(820, 302), catalog]]:
		view.size = fixture[0]
		view.start_round(lesson, Data.theme("spring"), 71)
		await _settle()
		var positions := _positions(view)
		view.start_game()
		for card in view.card_buttons:
			check(card.size.x >= 44 and card.size.y >= 44, "Catalog cards keep usable targets")
			if card.card_data.kind != "word":
				continue
			var label: Label = card.word_label
			var original: String = label.text
			for word: Dictionary in fixture[1]:
				label.text = word.text
				card._fit_text()
				var font_size: int = label.get_theme_font_size("font_size")
				var font: Font = label.get_theme_font("font")
				check(font_size >= 12 and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= label.size.x,
					"The catalog word fits its Memory card: " + label.text)
				check(font.get_height(font_size) <= label.size.y, "The complete word height fits its card")
			label.text = original
			card._fit_text()
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
