extends SceneTree

const Feel = preload("res://scripts/chest_feel.gd")
const PhraseModel = preload("res://scripts/phrase_game_model.gd")
const WordArt = preload("res://scripts/word_art.gd")
const PlayerFixture = preload("res://tests/godot/player_flow_fixture.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _settle() -> void:
	for frame in range(4):
		await process_frame


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	var directory := "user://phrase-scene-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Phrase scene tests use isolated saves")
	var app = load("res://scenes/main.tscn").instantiate()
	if not app.get_property_list().any(func(property: Dictionary) -> bool: return property.name == "_phrase"):
		check(false, "The real main scene includes Phrase Builder")
		app.free()
		quit(1)
		return
	var progress_script = app.medal_progress.get_script()
	app.medal_progress = progress_script.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	PlayerFixture.install(app, directory)
	root.add_child(app)
	await _settle()
	app.set_reduced_motion(true)
	app.audio.set_muted(false)
	await _choose_age(app, "3")
	app.choose_theme("spring")
	await _choose_mode(app, "phrase")
	var view = app._phrase
	_check_first_candidate_row(view)
	check(app._mode_id == "phrase" and app.MODES.has("phrase") and app._mode_buttons.size() == 5,
		"The library launches Phrase Builder alongside all four other modes")
	check(view.is_visible_in_tree() and not app.grid.visible and not app._memory.visible and not app._pop.visible,
		"Phrase Builder owns the visible playfield")
	check(view.game.questions.size() == 3 and view.game.phase == "building" and view.game.completed == 0,
		"The real scene starts exactly three unanswered phrases")
	if view.game.questions.size() != 3:
		await _finish(app, directory)
		return
	check(view.game.questions.all(func(question: Dictionary) -> bool: return question.level == "basic"),
		"A new Phrase Builder round uses the selected age range")
	check(view.pip.is_visible_in_tree() and view.pip.get_script() == app.duck.get_script(),
		"The new game uses the existing animated Pip character")
	check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + view.game.current_question().audio),
		"Entering the mode reads the current phrase immediately without a spoken guide")
	check(view.listen_button.is_visible_in_tree()
		and not view.snapshot().has("transcript") and not view.snapshot().prompt_text_visible,
		"One waveform control presents the spoken prompt without a separate heading or eye helper")
	check(view._progress is ProgressBar and view.snapshot().progress.value == 0
		and view.snapshot().progress.total == 3 and view.snapshot().progress.visible,
		"The visible progress bar starts with none of the three phrases completed")
	check(view.answer_buttons.all(func(button: Button) -> bool: return button.text.is_empty()),
		"The unanswered phrase uses an answer line without numbered placeholders")
	view.finished.emit()
	app.chest_button.button_down.emit()
	check(app.model.phase != "won" and not app._holding_chest and _pieces(app) == 0,
		"Early completion signals and chest presses cannot skip the three questions")
	view.option_buttons[0].pressed.emit()
	check(view.game.answer == [0] and view.answer_buttons[0].text == view.game.options[0].text,
		"A real word-bank button fills the first answer slot")
	check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + view.game.options[0].audio),
		"Choosing a word plays its existing pronunciation")
	check(not view.option_buttons[0].visible and not view.answer_buttons[0].disabled,
		"A chosen tile leaves the bank and remains removable from the answer")
	await _check_interruptions(app)
	await _check_muted_help(app)
	var questions_before_age: Array = view.game.questions.duplicate(true)
	var answer_before_age: Array = view.game.answer.duplicate()
	await _choose_age(app, "12")
	check(app._catalog_age == 12 and app.growth.level == 0 and app.growth.age == 0 and view.game.questions == questions_before_age
		and view.game.answer == answer_before_age,
		"Previewing a future age preserves the current phrase and cannot unlock words")
	view.answer_buttons[0].pressed.emit()
	check(view.game.answer.is_empty(), "Tapping the chosen word returns it to the bank")
	await _check_controller_and_keyboard(app)
	await _check_dragging(app)
	var target: Array = view.game.current_question().words
	var wrong_order: Array = target.duplicate()
	wrong_order.reverse()
	_select_words(view, wrong_order)
	for attempt in range(4):
		view.action_button.pressed.emit()
		check(view.game.feedback == "wrong" and view.game.phase == "building" and view.game.completed == 0
			and app.model.phase != "won" and _pieces(app) == 0,
			"Wrong attempt %d remains editable without a life limit or reward" % (attempt + 1))
		check(view.answer_buttons.all(func(button: Button) -> bool: return not button.disabled),
			"Wrong feedback leaves every chosen word available for correction")
		check(not view.snapshot().celebrating and not view.action_button.disabled,
			"Wrong answers can be retried immediately without a celebration gate")
	check(view.game.mistakes == 4 and app.audio.pair_feedback.playing
		and app.audio.pair_feedback.stream == load("res://assets/imported-audio/pair-feedback/wrong.wav")
		and not app.audio.voice.playing,
		"Incorrect submissions keep the wrong sound without spoken correction instructions")
	while view.game.answer.size() > 1:
		view.answer_buttons[0].pressed.emit()
	check(view.game.answer.size() == 1 and view.answer_buttons[0].text == target[0],
		"Answer buttons can remove misplaced words while keeping the correctly positioned word")
	_select_words(view, target.slice(1))
	view.action_button.pressed.emit()
	view.pip.set_process(false)
	check(view.game.phase == "correct" and view.game.completed == 1 and view.action_button.text == "Continue",
		"A repaired phrase offers an explicit Continue action")
	check(view.snapshot().prompt_text_visible
		and view.snapshot().progress.value == 1,
		"Correct feedback reveals the completed phrase in the waveform and advances progress once")
	check(app.audio.pair_feedback.playing
		and app.audio.pair_feedback.stream == load("res://assets/imported-audio/pair-feedback/right.wav")
		and app.audio.voice.stream == load("res://" + view.game.current_question().audio),
		"Correct feedback plays the right sound and repeats the completed phrase")
	check(app.model.phase != "won" and _pieces(app) == 0, "The first correct phrase does not unlock a chest")
	await _check_celebration_gate(app, "The first corrected phrase")
	await _settle()
	check(view.game.question_index == 0, "Correct feedback waits for Continue instead of advancing on a timer")
	view.action_button.pressed.emit()
	check(view.game.question_index == 1 and view.game.phase == "building" and view.game.answer.is_empty(),
		"Continue starts a clean second question")
	check(not view.snapshot().prompt_text_visible and view.snapshot().progress.value == 1,
		"The next spoken question preserves progress and clears the previous written phrase")
	view.listen_button.pressed.emit()
	check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + view.game.current_question().audio),
		"The unified waveform replays the next question's phrase")
	app.set_reduced_motion(false)
	_solve(view)
	check(view.game.completed == 2 and app.model.phase != "won" and _pieces(app) == 0,
		"Two correct phrases still leave the reward locked")
	await _check_celebration_gate(app, "The second phrase")
	view.action_button.pressed.emit()
	_solve(view)
	check(view.game.completed == 3 and view.game.phase == "correct" and view.completion_pending
		and app.model.phase != "won" and _pieces(app) == 0,
		"The third correct phrase starts a distinct round celebration without claiming a reward early")
	await _check_round_celebration(app)
	check(view.game.phase == "finished" and app.model.phase == "won" and app.model.chest_state == "closed"
		and app.chest_button.is_visible_in_tree() and not view.visible and not app._new_adventure_button.visible,
		"Choosing Open chest after celebrating enters the existing unopened-chest result screen")
	check(not app.audio.voice.playing, "The chest transition does not play spoken completion instructions")
	view.finished.emit()
	view.action_button.pressed.emit()
	check(_pieces(app) == 0 and app.model.chest_state == "closed", "Duplicate phrase completion cannot award a treasure")
	await _check_chest_and_new_adventure(app, directory, progress_script)
	await _check_celebration_interruptions(app)
	await _check_layout(app, directory)
	var stopped: Dictionary = view.game.snapshot()
	await _choose_mode(app, "match")
	view.option_buttons[0].pressed.emit()
	view.action_button.pressed.emit()
	view.listen_button.pressed.emit()
	view.finished.emit()
	check(app._mode_id == "match" and app.model.phase != "won" and view.game.snapshot() == stopped and _pieces(app) == 1,
		"Leaving Phrase Builder rejects stale tiles, audio and completion callbacks")
	await _finish(app, directory)


func _check_celebration_gate(app, context: String) -> void:
	var view = app._phrase
	view.pip.set_process(false)
	var before: Dictionary = view.game.snapshot()
	var pieces_before: int = _pieces(app)
	var completions: Array[bool] = []
	var record := func(correct: bool) -> void: completions.append(correct)
	view.pip.gameplay_reaction_finished.connect(record)
	check(view.snapshot().celebrating and view.action_button.disabled
		and not view.navigation_controls().has(view.action_button),
		context + " reserves time for Pip before exposing the next action")
	check(view.pip._gameplay_reaction == "happy" and view.pip.pose == 3
		and is_equal_approx(view.pip._gameplay_left, view.pip.GAMEPLAY_HAPPY_SECONDS),
		context + " starts the full 1.25-second happy reaction")
	for attempt in range(6):
		view.action_button.pressed.emit()
		view.finished.emit()
	app._controller_accept()
	await _enter_key()
	check(view.snapshot().celebrating and view.game.snapshot() == before and app.model.phase != "won"
		and _pieces(app) == pieces_before,
		context + " cannot be skipped by rapid callbacks, keyboard, controller or early completion")
	view.pip.gameplay_reaction_finished.emit(false)
	check(view.snapshot().celebrating and view.action_button.disabled,
		context + " ignores an unrelated sad-reaction completion")
	completions.clear()
	view.pip._process(view.pip.GAMEPLAY_HAPPY_SECONDS - 0.01)
	view.action_button.pressed.emit()
	check(view.snapshot().celebrating and view.action_button.disabled and view.game.snapshot() == before
		and view.pip._gameplay_reaction == "happy" and completions.is_empty(),
		context + " stays locked immediately before the happy reaction ends")
	if view.reduced_motion:
		check(view.pip.reduced_motion and view.pip.pose == 3,
			"Reduced motion keeps a static happy Pip for the same brief celebration interval")
	view.pip._process(0.02)
	check(not view.snapshot().celebrating and not view.action_button.disabled
		and view.navigation_controls().has(view.action_button) and completions == [true],
		context + " enables its explicit next action on exactly one natural completion")
	check(view.game.snapshot() == before and app.model.phase != "won" and _pieces(app) == pieces_before,
		context + " finishing Pip's reaction neither advances the question nor opens a chest automatically")
	view.pip._process(2.0)
	check(completions == [true] and view.game.snapshot() == before,
		context + " does not emit repeated completion when more time passes")
	view.pip.gameplay_reaction_finished.disconnect(record)
	view.listen_button.pressed.emit()
	check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + view.game.current_question().audio),
		context + " still lets the learner replay the phrase after celebrating")


func _check_round_celebration(app) -> void:
	var view = app._phrase
	var celebration = app._round_celebration
	celebration.set_process(false)
	var before: Dictionary = view.game.snapshot()
	var pieces_before: int = _pieces(app)
	var completions: Array[bool] = []
	var record := func() -> void: completions.append(true)
	view.finished.connect(record)
	check(celebration.snapshot().active and not celebration.snapshot().ready and view.completion_pending,
		"The third phrase hands its completed round to the shared celebration")
	check(not view.is_visible_in_tree() and not view.action_button.visible
		and view.navigation_controls().is_empty(),
		"The pending phrase has no second completion panel or navigable gameplay controls")
	for attempt in range(6):
		view.action_button.pressed.emit()
		view.listen_button.pressed.emit()
		view.finished.emit()
		celebration.action_button.pressed.emit()
		app.chest_button.button_down.emit()
	root.gui_release_focus()
	app._controller_accept()
	root.gui_release_focus()
	await _enter_key()
	check(view.game.snapshot() == before and app.model.phase != "won" and not app._holding_chest
		and not app.chest_button.is_visible_in_tree() and _pieces(app) == pieces_before,
		"Repeated phrase callbacks and input cannot bypass the shared performance")
	completions.clear()
	app.set_process(false)
	celebration.set_narration_playing(true)
	celebration.advance(3.01)
	check(not celebration.snapshot().ready and view.game.snapshot() == before and app.model.phase != "won",
		"The final phrase recording can outlast the shared animation without being interrupted")
	app.audio.stop_voice()
	celebration.set_narration_playing(false)
	check(celebration.snapshot().ready and not celebration.action_button.disabled
		and view.game.phase == "correct" and completions.is_empty() and _pieces(app) == pieces_before,
		"Completing animation and pronunciation enables the shared Open chest invitation")
	celebration.advance(4.0)
	check(view.game.snapshot() == before and app.model.phase != "won" and completions.is_empty(),
		"The ready invitation waits for an explicit click")
	celebration.action_button.pressed.emit()
	check(view.game.phase == "finished" and app.model.phase == "won" and completions == [true]
		and not view.completion_pending and not celebration.snapshot().active and _pieces(app) == pieces_before,
		"Accepting the shared invitation finishes Phrase and enters its unopened chest exactly once")
	view.action_button.pressed.emit()
	view.pip.gameplay_reaction_finished.emit(true)
	view.pip._process(4.0)
	check(completions == [true] and _pieces(app) == pieces_before,
		"Late local Pip events cannot repeat completion of the shared invitation")
	view.finished.disconnect(record)
	app.set_process(true)


func _check_celebration_interruptions(app) -> void:
	var view = app._phrase
	var pieces_before: int = _pieces(app)
	app.set_reduced_motion(false)
	for interruption in ["menu", "growth", "background", "hidden", "stop"]:
		check(app.new_round(73, false, "", "phrase"), "A fresh phrase round starts for celebration interruption: " + interruption)
		await _settle()
		_solve(view)
		var before: Dictionary = view.game.snapshot()
		var completions: Array[bool] = []
		var record := func(correct: bool) -> void: completions.append(correct)
		view.pip.gameplay_reaction_finished.connect(record)
		check(view.snapshot().celebrating and view.action_button.disabled,
			"Pip is celebrating before " + interruption)
		if interruption == "menu":
			app._mode_heading_button.pressed.emit()
		elif interruption == "growth":
			app.collection_button.pressed.emit()
		elif interruption == "background":
			app.on_page_hidden()
		elif interruption == "hidden":
			view.hide()
		else:
			view.stop()
		view.pip._process(2.0)
		check(not view.snapshot().celebrating and view.pip._gameplay_reaction.is_empty()
			and completions.is_empty() and view.game.snapshot() == before,
			"Opening " + interruption + " cancels the celebration without emitting natural completion")
		view.pip.gameplay_reaction_finished.emit(true)
		check(view.game.snapshot() == before and app.model.phase != "won" and _pieces(app) == pieces_before,
			"A stale Pip completion cannot advance the covered phrase behind " + interruption)
		view.pip.gameplay_reaction_finished.disconnect(record)
		if interruption == "menu":
			app._mode_panel.close_button.pressed.emit()
		elif interruption == "growth":
			app._collection_back.pressed.emit()
		elif interruption == "background":
			app.on_page_visible()
		elif interruption == "hidden":
			view.show()
		else:
			app._resume_phrase()
		await _settle()
		check(not view.snapshot().celebrating and not view.action_button.disabled and view.game.snapshot() == before,
			"Returning from " + interruption + " preserves the solved phrase with Continue ready")
		view.pip.gameplay_reaction_finished.emit(true)
		check(view.game.snapshot() == before and _pieces(app) == pieces_before,
			"A duplicate interrupted completion never advances the resumed phrase")
	check(app.new_round(91, false, "", "phrase"), "A fresh round starts before checking stale celebration across reconfiguration")
	await _settle()
	_solve(view)
	check(view.snapshot().celebrating, "The outgoing round has an unfinished celebration")
	check(app.new_round(92, false, "", "phrase"), "Reconfiguration replaces an actively celebrating round")
	await _settle()
	var replacement: Dictionary = view.game.snapshot()
	view.pip.gameplay_reaction_finished.emit(true)
	view.pip.gameplay_reaction_finished.emit(false)
	view.pip._process(2.0)
	check(not view.snapshot().celebrating and view.game.phase == "building" and view.game.completed == 0
		and view.action_button.disabled and view.game.snapshot() == replacement and _pieces(app) == pieces_before,
		"Late reaction callbacks cannot unlock or advance a new unanswered round")
	app.set_reduced_motion(true)


func _check_controller_and_keyboard(app) -> void:
	var view = app._phrase
	var before: Dictionary = view.game.snapshot()
	view.option_buttons[0].grab_focus()
	app._controller_accept()
	check(view.game.answer == [0], "Controller accept places the focused word-bank tile")
	view.answer_buttons[0].grab_focus()
	app._controller_accept()
	check(view.game.answer.is_empty(), "Controller accept returns the focused answer tile")
	view.option_buttons[1].grab_focus()
	await _enter_key()
	check(view.game.answer == [1], "Native Enter selects exactly the focused word-bank tile")
	view.answer_buttons[0].grab_focus()
	await _enter_key()
	check(view.game.answer.is_empty(), "Native Enter removes the focused answer tile")
	check(view.game.snapshot() == before, "Controller and keyboard editing preserve the question, progress and mistakes")


func _enter_key() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame


func _check_dragging(app) -> void:
	var view = app._phrase
	var before: Dictionary = view.game.snapshot()
	for method in ["mouse", "touch"]:
		await _drag_card(view, view.option_buttons[0].get_global_rect().get_center(),
			view.answer_buttons[0].get_global_rect().get_center(), method, "answer", 0)
		check(view.game.answer == [0] and not view.option_buttons[0].visible,
			method + " moves one bank card into the answer without a release-generated removal")
		check(app.audio.voice.stream == load("res://" + view.game.options[0].audio),
			method + " placement retains the chosen word's pronunciation")
		var tap_point: Vector2 = view.answer_buttons[0].get_global_rect().get_center()
		await _pointer_button(tap_point, true, method)
		await _pointer_motion(tap_point + Vector2(2, 1), Vector2(2, 1), method)
		check(not view.snapshot().dragging, method + " tiny finger or pointer movement remains a tap")
		await _pointer_button(tap_point + Vector2(2, 1), false, method)
		check(view.game.answer.is_empty() and view.option_buttons[0].visible,
			method + " tap returns the word once and restores its bank card")
		await _drag_card(view, view.option_buttons[0].get_global_rect().get_center(),
			view.answer_buttons[0].get_global_rect().get_center(), method, "answer", 0)
		await _drag_card(view, view.option_buttons[1].get_global_rect().get_center(),
			view.answer_buttons[0].get_global_rect().get_center(), method, "answer", 0)
		check(view.game.answer == [1, 0], method + " inserts a bank word ahead of an occupied answer slot")
		await _drag_card(view, view.answer_buttons[1].get_global_rect().get_center(),
			view.answer_buttons[0].get_global_rect().get_center(), method, "answer", 0)
		check(view.game.answer == [0, 1], method + " reorders selected words without removing either card")
		var held_answer: Dictionary = view.game.snapshot()
		var held_start: Vector2 = view.answer_buttons[0].get_global_rect().get_center()
		var held_end: Vector2 = view.answer_buttons[1].get_global_rect().get_center()
		await _pointer_button(held_start, true, method)
		await _pointer_motion(held_end, held_end - held_start, method)
		await _enter_key()
		app._controller_accept()
		check(view.snapshot().dragging and view.game.snapshot() == held_answer,
			method + " keeps pointer ownership when keyboard or controller activates the held answer")
		view.option_buttons[2].grab_focus()
		await _enter_key()
		app._controller_accept()
		check(view.snapshot().dragging and view.game.snapshot() == held_answer,
			method + " prevents keyboard or controller bank edits during an owned drag")
		await _pointer_button(held_end, false, method, true)
		check(view.game.snapshot() == held_answer, method + " canceling mixed input leaves both selected words intact")
		var answer_zone := _snapshot_rect(view.snapshot().answer_drop)
		await _drag_card(view, view.answer_buttons[0].get_global_rect().get_center(),
			Vector2(answer_zone.end.x - 2, answer_zone.get_center().y), method, "answer")
		check(view.game.answer == [1, 0], method + " can move the first word to the end of the answer")
		await _drag_card(view, view.answer_buttons[1].get_global_rect().get_center(),
			_snapshot_rect(view.snapshot().bank_drop).get_center(), method, "bank")
		check(view.game.answer == [1] and view.option_buttons[0].visible,
			method + " returns a selected word to the bank without adding it again")
		var partial: Dictionary = view.game.snapshot()
		await _drag_card(view, view.answer_buttons[0].get_global_rect().get_center(), Vector2(2, 2), method, "")
		check(view.game.snapshot() == partial, method + " outside drop leaves a selected card in its original position")
		await _drag_card(view, view.option_buttons[2].get_global_rect().get_center(), Vector2(2, 2), method, "")
		check(view.game.snapshot() == partial and view.option_buttons[2].visible,
			method + " invalid bank drop does not consume a word")
		await _drag_card(view, view.option_buttons[2].get_global_rect().get_center(),
			view.answer_buttons[1].get_global_rect().get_center(), method, "answer", 1, true)
		check(view.game.snapshot() == partial, method + " canceled release never commits a valid drop preview")
		await _drag_card(view, view.answer_buttons[0].get_global_rect().get_center(),
			_snapshot_rect(view.snapshot().bank_drop).get_center(), method, "bank")
		check(view.game.snapshot() == before, method + " editing leaves question, completion and mistakes unchanged")
		for index in range(view.answer_buttons.size()):
			view.option_buttons[index].pressed.emit()
		var full: Dictionary = view.game.snapshot()
		await _drag_card(view, view.option_buttons[view.answer_buttons.size()].get_global_rect().get_center(),
			view.answer_buttons[0].get_global_rect().get_center(), method, "*")
		check(view.game.snapshot() == full, method + " cannot replace an answer by dropping an extra bank card into a full phrase")
		while not view.game.answer.is_empty():
			view.answer_buttons[0].pressed.emit()
		await _check_drag_interruptions(app, method)
		await _check_pointer_release_fallback(app, method)
		check(view.game.snapshot() == before, method + " interrupted drags preserve the whole round")


func _check_pointer_release_fallback(app, method: String) -> void:
	var view = app._phrase
	var before: Dictionary = view.game.snapshot()
	var owner: int = 31 if method == "touch" else -1
	var start: Vector2 = view.option_buttons[0].get_global_rect().get_center()
	var end: Vector2 = view.answer_buttons[0].get_global_rect().get_center()
	await _pointer_button(start, true, method)
	await _pointer_motion(end, end - start, method)
	view.release_pointer(42 if method == "touch" else 31)
	await _settle()
	check(view.snapshot().dragging and view.game.snapshot() == before,
		method + " ignores a global release from a pointer that does not own the drag")
	view.release_pointer(owner)
	await _settle()
	check(not view.snapshot().dragging and view.game.snapshot() == before,
		method + " global release cancels when the canvas never receives its matching release")
	await _pointer_button(end, false, method)
	check(view.game.snapshot() == before, method + " a delayed canvas release cannot revive a canceled gesture")
	await _pointer_button(start, true, method)
	await _pointer_motion(end, end - start, method)
	view.release_pointer(owner)
	await _pointer_button(end, false, method)
	await _settle()
	check(view.game.answer == [0] and not view.snapshot().dragging,
		method + " normal canvas release commits before its deferred global fallback")
	view.answer_buttons[0].pressed.emit()
	start = view.option_buttons[0].get_global_rect().get_center()
	await _pointer_button(start, true, method)
	await _pointer_motion(end, end - start, method)
	view.release_pointer(owner)
	# Finish the old gesture and start another before its deferred callback runs.
	_push_pointer_button(end, false, method)
	start = view.option_buttons[1].get_global_rect().get_center()
	_push_pointer_button(start, true, method)
	end = view.answer_buttons[1].get_global_rect().get_center()
	await _pointer_motion(end, end - start, method)
	await _settle()
	check(view.snapshot().dragging and view.snapshot().drag_word == view.game.options[1].id
		and view.game.answer == [0], method + " stale release fallback cannot cancel a newer gesture from the same pointer")
	await _pointer_button(end, false, method, true)
	view.answer_buttons[0].pressed.emit()
	check(view.game.snapshot() == before, method + " fallback ownership checks preserve phrase progress and mistakes")


func _check_drag_interruptions(app, method: String) -> void:
	var view = app._phrase
	for interruption in ["menu", "growth", "background", "resize"]:
		var before: Dictionary = view.game.snapshot()
		var start: Vector2 = view.option_buttons[0].get_global_rect().get_center()
		var end: Vector2 = view.answer_buttons[0].get_global_rect().get_center()
		await _pointer_button(start, true, method)
		await _pointer_motion(end, end - start, method)
		check(view.snapshot().dragging and view.game.snapshot() == before,
			method + " has an uncommitted drag before " + interruption)
		if interruption == "menu":
			app._mode_heading_button.pressed.emit()
		elif interruption == "growth":
			app.collection_button.pressed.emit()
		elif interruption == "background":
			app.on_page_hidden()
		else:
			root.size = Vector2i(1320, 760)
		await _settle()
		check(not view.snapshot().dragging and view.snapshot().drag_word.is_empty(),
			method + " clears the drag preview when interrupted by " + interruption)
		await _pointer_button(end, false, method)
		check(view.game.snapshot() == before, method + " late release cannot commit behind " + interruption)
		if interruption == "menu":
			app._mode_panel.close_button.pressed.emit()
		elif interruption == "growth":
			app._collection_back.pressed.emit()
		elif interruption == "background":
			app.on_page_visible()
		else:
			root.size = Vector2i(1366, 768)
		await _settle()
		check(not view.snapshot().paused and not view.snapshot().dragging and view.game.snapshot() == before,
			method + " resumes the same answer after " + interruption)


func _drag_card(view, start: Vector2, end: Vector2, method: String, drop_kind: String,
		drop_index: int = -1, canceled: bool = false) -> void:
	var before: Dictionary = view.game.snapshot()
	var original_rects: Array[Rect2] = []
	for button: Button in view.answer_buttons:
		original_rects.append(button.get_global_rect())
	await _pointer_button(start, true, method)
	check(not view.snapshot().dragging, method + " waits for movement before starting a card drag")
	await _pointer_motion(start + Vector2(0, -24), Vector2(0, -24), method)
	await _pointer_motion(end, end - start, method)
	var preview: Dictionary = view.snapshot()
	check(preview.dragging and not preview.drag_word.is_empty() and view.game.snapshot() == before,
		method + " shows a drag preview while preserving the answer until release")
	check(view._preview.icon == view._source.icon,
		method + " retains the selected word's picture or contextual text presentation while dragging")
	if drop_kind != "*":
		check(preview.drop_kind == drop_kind, method + " identifies the expected drop destination: " + drop_kind)
	if drop_index >= 0:
		check(preview.drop_index == drop_index, method + " previews the final word position")
	if preview.drop_kind == "answer":
		await _check_live_reflow(view, before, original_rects, end, method)
	var landing: Rect2 = _snapshot_rect(preview.drop_rect) if preview.drop_kind == "answer" else Rect2()
	if method == "touch":
		await _pointer_button(end, true, "emulated")
		await _pointer_button(end, false, "emulated")
		check(view.snapshot().dragging and view.game.snapshot() == before,
			"Emulated mouse events cannot finish or mutate the owning touch drag")
	await _pointer_button(end, false, method, canceled)
	await _settle()
	check(not view.snapshot().dragging and view.snapshot().drag_word.is_empty(),
		method + " release clears the drag preview")
	_check_answer_pictures(view)
	if canceled and is_zero_approx(view.snapshot().answer_rail.max_scroll):
		for index in range(before.answer.size()):
			check(view.answer_buttons[index].get_global_rect().is_equal_approx(original_rects[index]),
				method + " cancel restores each word's position after live reordering")
	if landing.has_area() and not canceled:
		var placed: int = -1
		for index in range(view.game.answer.size()):
			if view.game.options[view.game.answer[index]].id == preview.drag_word:
				placed = index
		check(placed >= 0 and landing.is_equal_approx(view.answer_buttons[placed].get_global_rect()),
			method + " landing highlight matches the word's final compact position and size")


func _check_live_reflow(view, before: Dictionary, original_rects: Array[Rect2], point: Vector2, method: String) -> void:
	await create_timer(0.15).timeout
	var held: Dictionary = view.snapshot()
	var dragged: int = before.option_ids.find(held.drag_word)
	var order: Array = before.answer.duplicate()
	order.erase(dragged)
	order.insert(mini(held.drop_index, order.size()), dragged)
	var previous_end: float = -INF
	for word: int in order:
		var index: int = before.answer.find(word)
		var rect: Rect2 = _snapshot_rect(held.drop_rect) if word == dragged else view.answer_buttons[index].get_global_rect()
		check(rect.position.x >= previous_end, method + " held cards already leave a non-overlapping gap at the new position")
		previous_end = rect.end.x
		if word != dragged and order.find(word) != index and is_zero_approx(held.answer_rail.max_scroll):
			check(not is_equal_approx(rect.position.x, original_rects[index].position.x),
				method + " neighboring words visibly move before the pointer is released")
	if before.answer.has(dragged):
		check(is_zero_approx(view._source.modulate.a), method + " lifted answer has one visible card instead of a duplicate")
	var held_rects: Array[Rect2] = []
	for button: Button in view.answer_buttons:
		held_rects.append(button.get_global_rect())
	for repeat in range(3):
		await _pointer_motion(point, Vector2.ZERO, method)
		check(view.snapshot().drop_index == held.drop_index and view.game.snapshot() == before,
			method + " repeated hovering cannot oscillate the preview or commit the answer")
		for index in range(before.answer.size()):
			check(view.answer_buttons[index].get_global_rect().is_equal_approx(held_rects[index]),
				method + " stationary drag keeps neighboring cards stable")


func _snapshot_rect(values: Array) -> Rect2:
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


func _check_answer_pictures(view) -> void:
	for index in range(view.answer_buttons.size()):
		var button: Button = view.answer_buttons[index]
		if index < view.game.answer.size():
			var option_index: int = view.game.answer[index]
			var picture_path: String = str(view.game.options[option_index].image)
			var expected: Texture2D = WordArt.texture(picture_path)
			check(button.icon == expected and button.icon == view.option_buttons[option_index].icon,
				"The placed word retains its source picture or contextual text presentation after editing")
		else:
			check(button.icon == null and not button.visible,
				"Unused answer positions clear their old pictures")


func _pointer_button(point: Vector2, pressed: bool, method: String, canceled: bool = false) -> void:
	_push_pointer_button(point, pressed, method, canceled)
	await process_frame


func _push_pointer_button(point: Vector2, pressed: bool, method: String, canceled: bool = false) -> void:
	if method == "touch":
		var event := InputEventScreenTouch.new()
		event.index = 31
		event.position = point
		event.pressed = pressed
		event.canceled = canceled
		root.push_input(event, true)
	else:
		var event := InputEventMouseButton.new()
		event.device = -1 if method == "emulated" else 0
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		event.canceled = canceled
		root.push_input(event, true)


func _pointer_motion(point: Vector2, relative: Vector2, method: String) -> void:
	if method == "touch":
		var event := InputEventScreenDrag.new()
		event.index = 31
		event.position = point
		event.relative = relative
		root.push_input(event, true)
	else:
		var event := InputEventMouseMotion.new()
		event.position = point
		event.global_position = point
		event.relative = relative
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(event, true)
	await process_frame


func _check_interruptions(app) -> void:
	var view = app._phrase
	for interruption in ["menu", "growth", "background"]:
		view.listen_button.pressed.emit()
		check(app.audio.voice.playing, "Listen plays the phrase before opening " + interruption)
		var before: Dictionary = view.game.snapshot()
		if interruption == "menu":
			app._mode_heading_button.pressed.emit()
		elif interruption == "growth":
			app.collection_button.pressed.emit()
		else:
			app.on_page_hidden()
		check(view.snapshot().paused and view.navigation_controls().is_empty() and not app.audio.voice.playing,
			"Opening " + interruption + " pauses phrase interaction and stops speech")
		for button in view.option_buttons + view.answer_buttons + [view.action_button, view.listen_button]:
			button.pressed.emit()
		view.finished.emit()
		app.audio.voice.finished.emit()
		check(view.game.snapshot() == before and not app.audio.voice.playing and app.model.phase != "won",
			"Covered phrase controls and stale audio callbacks cannot mutate the game behind " + interruption)
		if interruption == "menu":
			app._mode_panel.close_button.pressed.emit()
		elif interruption == "growth":
			app._collection_back.pressed.emit()
		else:
			app.on_page_visible()
		await _settle()
		check(not view.snapshot().paused and not view.navigation_controls().is_empty()
			and view.game.snapshot() == before and not app.audio.voice.playing,
			"Closing " + interruption + " resumes the same answer without replaying interrupted speech")


func _check_muted_help(app) -> void:
	var view = app._phrase
	app._mode_heading_button.pressed.emit()
	app._mode_panel.sound_button.pressed.emit()
	app._mode_panel.close_button.pressed.emit()
	await _settle()
	check(app.audio.muted and view.snapshot().prompt_text_visible and view.listen_button.is_visible_in_tree()
		and view.listen_button._caption.text == view.game.current_question().text,
		"Sound off automatically exposes the written phrase so the game remains playable")
	view.listen_button.pressed.emit()
	check(not app.audio.voice.playing, "Listen respects the shared sound-off setting")
	app._mode_heading_button.pressed.emit()
	app._mode_panel.sound_button.pressed.emit()
	app._mode_panel.close_button.pressed.emit()
	await _settle()
	check(not app.audio.muted and not app.audio.voice.playing, "Unmuting does not replay old instructions")


func _check_chest_and_new_adventure(app, directory: String, progress_script: GDScript) -> void:
	app.set_reduced_motion(false)
	app.chest_button.button_down.emit()
	app.set_process(false)
	check(app._holding_chest and app.chest.hold_effect_snapshot().active, "The standard chest button starts its hold gesture")
	app._advance_ui(0.25)
	app.chest_button.button_up.emit()
	check(app.model.chest_state == "closed" and _pieces(app) == 0, "A short chest hold cancels without awarding anything")
	app.chest_button.button_down.emit()
	app.set_process(false)
	app._advance_ui(Feel.HOLD_SECONDS)
	app.chest.set_process(false)
	check(app.model.chest_state == "opening" and _pieces(app) == 0, "A complete hold enters the existing opening timeline")
	app.chest._advance_animation(Feel.RELEASE_TIME + 0.01)
	app.chest_button.button_up.emit()
	check(app.chest.opening_committed() and _pieces(app) == 0, "Letting go after the lid releases preserves the opening")
	app.chest._advance_animation(Feel.OPEN_SECONDS)
	check(app.model.chest_state == "opened" and _pieces(app) == 1 and app.chest.hold_effect_snapshot().surprise.active
		and app._new_adventure_button.is_visible_in_tree(),
		"The finished opening saves one ordinary reward and reveals New adventure")
	app._phrase.finished.emit()
	app.chest.opened.emit()
	app.chest_button.button_down.emit()
	check(_pieces(app) == 1, "Duplicate phrase and chest completion signals cannot award a second piece")
	var saved = progress_script.new(directory + "/medals.cfg", directory + "/legacy.cfg")
	check(saved.load_progress() and saved.count_for("spring-1") == 1, "The Phrase Builder reward survives a real save reload")
	app.set_process(true)
	app.chest.set_process(true)
	app.set_reduced_motion(true)
	app._new_adventure_button.pressed.emit()
	await _settle()
	check(app._mode_id == "phrase" and app._phrase.is_visible_in_tree() and app._phrase.game.questions.size() == 3
		and app._phrase.game.phase == "building" and app._phrase.game.completed == 0 and app._phrase.game.mistakes == 0,
		"Public New adventure starts another fresh three-question Phrase Builder round")
	check(app._phrase.game.questions.all(func(question: Dictionary) -> bool: return int(question.min_age) <= app.growth.learning_age()),
		"The next Phrase Builder round uses the earned level rather than a future catalogue preview")
	check(_pieces(app) == 1 and not app.chest.hold_effect_snapshot().surprise.active,
		"A new phrase round keeps saved progress and clears the previous displayed gift")


func _check_first_candidate_row(view) -> void:
	var bank_rect: Rect2 = _snapshot_rect(view.snapshot().bank.rect)
	var previous: Button
	for button: Button in view.option_buttons:
		if not button.is_visible_in_tree():
			continue
		var rect: Rect2 = button.get_global_rect()
		check(rect.position.y >= bank_rect.position.y - 0.5 and rect.end.y <= bank_rect.end.y + 0.5,
			"The first-render candidate " + button.text + " fits vertically inside the bank without a resize or interaction")
		if previous != null:
			check(previous.get_global_rect().end.x <= rect.position.x - 0.5,
				"First-render candidates " + previous.text + " and " + button.text + " have a visible gap without overlapping")
		_check_button_text_fit(button, "first question before interaction")
		previous = button


func _check_layout(app, directory: String) -> void:
	# Advanced layout fixtures load a legitimately unlocked save; browsing future
	# age previews earlier in this suite must not unlock playable vocabulary.
	var saved := ConfigFile.new()
	var growth_path: String = directory + "/growth.cfg"
	check(saved.load(growth_path) == OK, "The advanced layout fixture starts from the saved learning state")
	saved.set_value("growth", "version", 1)
	saved.set_value("growth", "level", 12)
	# Leave this four-word phrase unmastered so the learning-priority selector
	# can choose it ahead of longer, already-mastered phrases in the curriculum.
	var streaks: Dictionary = {}
	for word: Dictionary in app.data.words:
		if not ["bright", "red", "birthday", "balloon"].has(str(word.id)):
			streaks[str(word.id)] = 6
	saved.set_value("growth", "streaks", streaks)
	check(saved.save(growth_path) == OK and app.growth.load_state() and app.growth.age == 12 and app.growth.learning_age() == 12,
		"The advanced layout fixture loads an migrated completed age-12 state with all vocabulary available")
	app._refresh_growth()
	var probe = PhraseModel.new()
	var layout_seed: int = -1
	for seed_value in range(128):
		if probe.reset(app._learning_words(), str(app.growth.learning_age()), seed_value) and probe.current_question().words.size() == 4:
			layout_seed = seed_value
			break
	check(layout_seed >= 0 and app.new_round(layout_seed, false, "", "phrase"), "A four-word, six-choice fixture starts through the real round API")
	app.audio.set_muted(true)
	app._resume_phrase()
	for dimensions in [Vector2i(1366, 768), Vector2i(390, 844), Vector2i(390, 500), Vector2i(390, 540), Vector2i(844, 390), Vector2i(320, 568), Vector2i(320, 320)]:
		root.size = dimensions
		await _settle()
		var view = app._phrase
		var bounds: Rect2 = root.get_visible_rect().grow(0.75)
		var scale_factor: float = app.Style.ui_scale(view)
		check(bounds.encloses(view.get_global_rect()), "Phrase Builder stays within the host at " + str(dimensions))
		check(view.answer_buttons.size() == 4 and view.option_buttons.size() == 6, "The advanced phrase retains every answer slot and choice")
		var buttons: Array = view.answer_buttons + [view.listen_button, view.action_button]
		var visible_buttons: Array[Button] = []
		for button: Button in buttons:
			if not button.is_visible_in_tree():
				continue
			visible_buttons.append(button)
			check(bounds.encloses(button.get_global_rect()), "The " + str(button.name) + " target is on screen at " + str(dimensions))
			check(button.size.x * scale_factor >= 43.9 and button.size.y * scale_factor >= 43.9,
				"The " + str(button.name) + " target remains at least 44 CSS pixels at " + str(dimensions))
			_check_button_text_fit(button, str(dimensions))
		for first in range(visible_buttons.size()):
			for second in range(first):
				check(not visible_buttons[first].get_global_rect().grow(-0.75).intersects(visible_buttons[second].get_global_rect().grow(-0.75)),
					"Phrase controls do not overlap at " + str(dimensions) + ": " + str(visible_buttons[first].name) + "/" + str(visible_buttons[second].name))
		check(view.snapshot().prompt_text_visible and view.listen_button.is_visible_in_tree(), "Muted phrase text stays inside the waveform at " + str(dimensions))
		_check_waveform_text_fit(view, str(dimensions))
		check(view.snapshot().progress.visible and bounds.encloses(view._progress.get_global_rect()),
			"The three-question progress bar remains visible at " + str(dimensions))
		var bank_rect: Rect2 = _snapshot_rect(view.snapshot().bank.rect)
		check(bounds.encloses(bank_rect), "The horizontally clipped bank stays on screen at " + str(dimensions))
		check(absf(view.action_button.get_global_rect().end.x - bank_rect.end.x) <= 1.0,
			"Check answer aligns with the right edge of the play area at " + str(dimensions))
		var row_y: float = view.option_buttons[0].global_position.y
		for button: Button in view.option_buttons:
			check(is_equal_approx(button.global_position.y, row_y), "Candidate words never wrap to another row at " + str(dimensions))
			check(button.size.x * scale_factor >= 43.9 and button.size.y * scale_factor >= 43.9,
				"Scrollable candidate targets retain their touch size at " + str(dimensions))
			_check_button_text_fit(button, str(dimensions))
			button.grab_focus()
			await _settle()
			check(bank_rect.grow(0.75).encloses(button.get_global_rect()),
				"Keyboard or controller focus reveals the complete candidate " + button.text + " at " + str(dimensions))
		check(view.navigation_controls().has(app._default_focus()), "The host default focus belongs to a playable phrase control")
		_select_words(view, view.game.current_question().words)
		await _settle()
		for index in range(view.game.answer.size()):
			var button: Button = view.answer_buttons[index]
			button.grab_focus()
			await _settle()
			check(view._answer_clip.get_global_rect().grow(0.75).encloses(button.get_global_rect()) and button.size.x * scale_factor >= 43.9,
				"Every illustrated answer can be revealed at " + str(dimensions))
			_check_button_text_fit(button, str(dimensions) + ", full answer")
			var text_width: float = button.get_theme_font("font").get_string_size(button.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x * scale_factor
			var picture_width: float = (button.get_theme_constant("icon_max_width") + button.get_theme_constant("h_separation")) * scale_factor
			check(button.size.x * scale_factor <= maxf(64, text_width + 32) + picture_width,
				"Answer word " + button.text + " keeps content-sized padding at " + str(dimensions))
			if index > 0:
				var space: float = (button.position.x - view.answer_buttons[index - 1].get_rect().end.x) * scale_factor
				check(space >= 5.9 and space <= 10.1,
					"Selected answer words stay closely spaced at " + str(dimensions))
		_check_answer_pictures(view)
		while not view.game.answer.is_empty():
			view.answer_buttons[0].pressed.emit()
		if dimensions == Vector2i(320, 320):
			await _check_long_answer_words(view, app.data.words)
		root.gui_release_focus()
	await _check_bank_scroll(app)
	_solve(app._phrase)
	await _settle()
	check(app._phrase.snapshot().prompt_text_visible and app._phrase.snapshot().progress.value == 1,
		"The smallest viewport retains the completed phrase and updated progress")
	await _check_completed_answer_navigation(app)
	_check_waveform_text_fit(app._phrase, "(320, 320), correct feedback")
	for button: Button in app._phrase.answer_buttons + app._phrase.option_buttons \
		+ [app._phrase.listen_button, app._phrase.action_button]:
		if button.is_visible_in_tree():
			_check_button_text_fit(button, "(320, 320), correct feedback")
	await _check_compact_long_prompts(app._phrase)


func _check_completed_answer_navigation(app) -> void:
	var view = app._phrase
	var before: Dictionary = view.game.snapshot()
	check(view.snapshot().answer_rail.max_scroll > 0 and view.navigation_controls().has(view._answer_clip),
		"A completed overflowing phrase exposes its answer line to keyboard and controller navigation")
	view._answer_clip.grab_focus()
	view._scroll_answer(0)
	app._move_focus(Vector2.RIGHT)
	check(view.snapshot().answer_rail.scroll > 0 and view._answer_clip.has_focus(),
		"Controller right scrolls the completed illustrated answer")
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	check(is_zero_approx(view.snapshot().answer_rail.scroll) and view.game.snapshot() == before,
		"Keyboard left reviews the completed pictures without changing the answer")
	app._move_focus(Vector2.UP)
	check(not view._answer_clip.has_focus() and app._valid_focus(root.gui_get_focus_owner()),
		"Controller up leaves the read-only answer line while Continue is waiting for Pip")


func _check_long_answer_words(view, vocabulary: Array) -> void:
	var original: Array[Dictionary] = view.game.options.duplicate(true)
	var words: Array[String] = ["hippopotamus", "parallelogram", "birthday", "balloon"]
	# A wrong answer may include both long distractors and the longest target words.
	for index in range(words.size()):
		for word: Dictionary in vocabulary:
			if word.text == words[index]:
				view.game.options[index] = word.duplicate(true)
				break
	view._rebuild_buttons()
	view._refresh()
	for index in range(words.size()):
		view.option_buttons[index].pressed.emit()
	for button: Button in view.answer_buttons:
		button.grab_focus()
		await _settle()
		check(view._answer_clip.get_global_rect().grow(0.75).encloses(button.get_global_rect()),
			"Long illustrated distractors are fully revealed in a narrow answer")
		_check_button_text_fit(button, "(320, 320), two long distractors")
	_check_answer_pictures(view)
	for dimensions in [Vector2i(390, 500), Vector2i(320, 320)]:
		root.size = dimensions
		await _settle()
		check(view.answer_buttons.back().has_focus() and view._answer_clip.get_global_rect().grow(0.75).encloses(view.answer_buttons.back().get_global_rect()),
			"Resizing keeps the focused illustrated answer fully visible")
	var before: Dictionary = view.game.snapshot()
	view.scroll_answer_to(0)
	var start: Vector2 = view._answer_clip.get_global_rect().get_center()
	await _pointer_button(start, true, "touch")
	await _pointer_motion(start + Vector2(-90, 0), Vector2(-90, 0), "touch")
	await _pointer_button(start + Vector2(-90, 0), false, "touch")
	check(view.snapshot().answer_rail.scroll > 0 and not view.snapshot().dragging and view.game.snapshot() == before,
		"A horizontal swipe reveals illustrated answers without changing their order")
	_check_answer_pictures(view)
	view.scroll_answer_to(0)
	start = view.answer_buttons[0].get_global_rect().get_center()
	await _pointer_button(start, true, "touch")
	await _pointer_motion(start + Vector2(0, -24), Vector2(0, -24), "touch")
	var edge: Vector2 = view._answer_clip.get_global_rect().get_center()
	edge.x = view._answer_clip.get_global_rect().end.x - 3
	await _pointer_motion(edge, edge - start, "touch")
	view._process(3)
	check(view.snapshot().answer_rail.scroll > 0 and view.snapshot().dragging,
		"A lifted answer scrolls at the edge to reach words outside the viewport")
	await _pointer_button(edge, false, "touch")
	check(view.game.answer == [1, 2, 3, 0], "An illustrated answer can be reordered to the far end of an overflowing row")
	_check_answer_pictures(view)
	view.game.clear()
	view.game.options.assign(original)
	view._rebuild_buttons()
	view._refresh()


func _check_bank_scroll(app) -> void:
	var view = app._phrase
	var before: Dictionary = view.game.snapshot()
	check(view.snapshot().bank.max_scroll > 0, "Narrow screens provide horizontal overflow for the full candidate row")
	view.option_buttons[0].grab_focus()
	await _settle()
	var bank_rect: Rect2 = _snapshot_rect(view.snapshot().bank.rect)
	var wheel := InputEventMouseButton.new()
	wheel.position = bank_rect.get_center()
	wheel.global_position = wheel.position
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	root.push_input(wheel, true)
	await _settle()
	check(view.snapshot().bank.scroll > 0 and view.game.snapshot() == before,
		"A real mouse wheel reveals later candidate words without changing the answer")
	root.gui_release_focus()
	view.option_buttons[0].grab_focus()
	await _settle()
	var scroll_before: float = view.snapshot().bank.scroll
	var start: Vector2 = bank_rect.get_center()
	await _pointer_button(start, true, "touch")
	await _pointer_motion(start + Vector2(-64, 1), Vector2(-64, 1), "touch")
	await _pointer_button(start + Vector2(-64, 1), false, "touch")
	check(view.snapshot().bank.scroll > scroll_before and not view.snapshot().dragging
		and view.game.snapshot() == before,
		"A horizontal finger swipe scrolls candidates without selecting or dropping a card")
	var last: Button = view.option_buttons.back()
	last.grab_focus()
	await _settle()
	await _enter_key()
	check(view.game.answer == [view.option_buttons.size() - 1],
		"Keyboard can select a candidate that began outside the clipped row")
	view.answer_buttons[0].pressed.emit()
	check(view.game.snapshot() == before, "Returning the scrolled candidate preserves question progress")


func _check_compact_long_prompts(view) -> void:
	check(root.size == Vector2i(320, 320), "Long phrase regressions use the smallest supported square viewport")
	var original: Dictionary = view.game.current_question().duplicate(true)
	var prompts: Array[String] = [
		"bright red birthday balloon",
		"frozen strawberry dessert",
		"transparent glass",
		"beautiful yellow spring butterfly",
		"fresh strawberry breakfast smoothie"
	]
	for phrase_text in prompts:
		view.listen_button.configure({"text": phrase_text}, true, view._palette.accent)
		await _settle()
		_check_waveform_text_fit(view, "(320, 320), long prompt: " + phrase_text, phrase_text)
	view.listen_button.configure(original, true, view._palette.accent)
	await _settle()
	_check_waveform_text_fit(view, "(320, 320), restored actual phrase")


func _check_waveform_text_fit(view, context: String, expected_text: String = "") -> void:
	var caption: Label = view.listen_button._caption
	if expected_text.is_empty():
		expected_text = view.game.current_question().text
	check(caption.text == expected_text and caption.is_visible_in_tree()
		and view.listen_button.get_global_rect().grow(0.75).encloses(caption.get_global_rect()),
		"The waveform contains the complete written phrase at " + context)
	var font: Font = caption.get_theme_font("font")
	var font_size: int = caption.get_theme_font_size("font_size")
	var measurement := Label.new()
	measurement.text = expected_text
	measurement.autowrap_mode = caption.autowrap_mode
	measurement.max_lines_visible = -1
	measurement.clip_text = true
	measurement.add_theme_font_override("font", font)
	measurement.add_theme_font_size_override("font_size", font_size)
	measurement.add_theme_constant_override("line_spacing", caption.get_theme_constant("line_spacing"))
	measurement.size = caption.size
	measurement.hide()
	view.add_child(measurement)
	var complete_line_count: int = measurement.get_line_count()
	check(complete_line_count >= 1 and complete_line_count <= 2
		and caption.get_line_count() == complete_line_count
		and caption.get_visible_line_count() == complete_line_count,
		"Every line of the unclamped full phrase is visible, including its final word, at " + context)
	measurement.free()
	check(caption.get_line_count() * caption.get_line_height() <= caption.size.y + 0.5,
		"Every wrapped line of the written phrase fits vertically at " + context)
	for word in caption.text.split(" "):
		check(font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= caption.size.x + 0.5,
			"The waveform keeps each word readable without clipping at " + context)


func _check_button_text_fit(button: Button, context: String) -> void:
	var font: Font = button.get_theme_font("font")
	var font_size: int = button.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var horizontal_padding: float = button.get_theme_stylebox("normal").get_minimum_size().x
	if button.icon != null:
		horizontal_padding += button.get_theme_constant("icon_max_width") + button.get_theme_constant("h_separation")
	check(text_width + horizontal_padding <= button.size.x + 0.5,
		"The %s label '%s' fits at %s: text %.2f + style %.2f <= width %.2f" % [
			button.name, button.text, context, text_width, horizontal_padding, button.size.x])


func _choose_mode(app, id: String) -> void:
	app._mode_heading_button.pressed.emit()
	var button := app._mode_panel.find_child("Mode_" + id, true, false) as Button
	check(app._mode_menu_open() and button != null, "The game library exposes " + id)
	if button != null:
		button.pressed.emit()
	await _settle()


func _choose_age(app, id: String) -> void:
	app.collection_button.pressed.emit()
	app._age_buttons[id].pressed.emit()
	await _settle()
	check(app._catalog_age == int(id) and app._age_catalog.visible, "The real age button previews " + id)
	app._collection_back.pressed.emit()
	await _settle()
	check(not app.collection_page.visible, "Back returns from age vocabulary to the game")


func _select_words(view, ids: Array) -> void:
	for id in ids:
		var found: bool = false
		for index in range(view.game.options.size()):
			if view.game.options[index].id == id:
				view.option_buttons[index].pressed.emit()
				found = true
				break
		check(found, "The target word has a real choice button: " + str(id))


func _solve(view) -> void:
	_select_words(view, view.game.current_question().words)
	view.action_button.pressed.emit()
	view.pip.set_process(false)
	check(view.game.phase == "correct", "The actual Check answer button accepts the assembled phrase")


func _pieces(app) -> int:
	var total: int = 0
	for count in app.medal_progress.counts.values():
		total += int(count)
	return total


func _finish(app, directory: String) -> void:
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Phrase scene: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
