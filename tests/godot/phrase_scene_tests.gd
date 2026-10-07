extends SceneTree

const Feel = preload("res://scripts/chest_feel.gd")
const PhraseModel = preload("res://scripts/phrase_game_model.gd")
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
	app.playroom_save_path = directory + "/playroom.cfg"
	app._presentation.path = directory + "/presentation.cfg"
	PlayerFixture.install(app, directory)
	root.add_child(app)
	await _settle()
	app.set_reduced_motion(true)
	app.audio.set_muted(false)
	await _choose_age(app, "4-6")
	app.choose_theme("spring")
	await _choose_mode(app, "phrase")
	var view = app._phrase
	check(app._mode_id == "phrase" and app.MODES.has("phrase") and app._mode_buttons.size() == 4,
		"The library launches Phrase Builder alongside all three existing modes")
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
	check(view.transcript_button.text.is_empty() and view.transcript_button.get("accessibility_name") == "Show the written phrase",
		"The eye helper has an accessible name without a visible text label")
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
	await _choose_age(app, "10-plus")
	check(app.playroom_state.age_band_id == "10-plus" and view.game.questions == questions_before_age
		and view.game.answer == answer_before_age,
		"Changing age in Pip's room preserves the current phrase and applies to the next round")
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
	check(view.transcript_button.disabled and view.transcript_button.text.is_empty()
		and not view.navigation_controls().has(view.transcript_button),
		"Correct feedback shows the phrase and removes its inactive eye toggle from navigation")
	view.transcript_button.pressed.emit()
	check(view.snapshot().transcript_visible and view.game.phase == "correct",
		"An old transcript signal cannot hide the completed phrase")
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
	check(not view.transcript_button.disabled and view.navigation_controls().has(view.transcript_button),
		"The next question restores the actionable transcript helper")
	var transcript_shown: bool = view.snapshot().transcript_visible
	view.transcript_button.pressed.emit()
	check(view.snapshot().transcript_visible != transcript_shown, "The restored transcript button changes the next question's written hint")
	view.transcript_button.pressed.emit()
	app.set_reduced_motion(false)
	_solve(view)
	check(view.game.completed == 2 and app.model.phase != "won" and _pieces(app) == 0,
		"Two correct phrases still leave the reward locked")
	await _check_celebration_gate(app, "The second phrase")
	view.action_button.pressed.emit()
	_solve(view)
	check(view.game.completed == 3 and view.game.phase == "correct" and view.snapshot().round_celebrating
		and app.model.phase != "won" and _pieces(app) == 0,
		"The third correct phrase starts a distinct round celebration without claiming a reward early")
	await _check_round_celebration(app)
	check(view.game.phase == "finished" and app.model.phase == "won" and app.model.chest_state == "closed"
		and app.chest_button.is_visible_in_tree() and not view.visible and not app._new_adventure_button.visible,
		"Completing the celebration automatically enters the existing unopened-chest result screen")
	check(not app.audio.voice.playing, "The chest transition does not play spoken completion instructions")
	view.finished.emit()
	view.action_button.pressed.emit()
	check(_pieces(app) == 0 and app.model.chest_state == "closed", "Duplicate phrase completion cannot award a treasure")
	await _check_chest_and_new_adventure(app, directory, progress_script)
	await _check_celebration_interruptions(app)
	await _check_round_celebration_interruptions(app)
	await _check_layout(app)
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
	var before: Dictionary = view.game.snapshot()
	var pieces_before: int = _pieces(app)
	var audio_gate: Callable = view.completion_audio_playing
	var narration_pending: Array[bool] = [true]
	view.completion_audio_playing = func() -> bool: return narration_pending[0]
	var completions: Array[bool] = []
	var record := func() -> void: completions.append(true)
	view.finished.connect(record)
	check(view.snapshot().round_celebrating and not view.snapshot().completion_animation_done
		and is_equal_approx(view.pip._gameplay_left, view.ROUND_CELEBRATION_SECONDS),
		"Finishing the third phrase reserves the full round celebration interval")
	check(view._heading.text == "You did it!" and view._feedback.text == "3 phrases complete"
		and view._heading.is_visible_in_tree() and view._feedback.is_visible_in_tree(),
		"The completion stage clearly distinguishes the round win from an individual correct answer")
	_check_round_controls_hidden(view)
	for attempt in range(6):
		view.action_button.pressed.emit()
		view.listen_button.pressed.emit()
		view.transcript_button.pressed.emit()
		view.finished.emit()
		app.chest_button.button_down.emit()
	root.gui_release_focus()
	app._controller_accept()
	root.gui_release_focus()
	await _enter_key()
	check(view.game.snapshot() == before and app.model.phase != "won" and not app._holding_chest
		and not app.chest_button.is_visible_in_tree() and _pieces(app) == pieces_before,
		"Repeated actions, keyboard, controller and early chest presses cannot skip the round celebration")
	completions.clear()
	view.pip.gameplay_reaction_finished.emit(false)
	check(not view.snapshot().completion_animation_done, "An unrelated sad reaction cannot finish the round celebration")
	view.pip._process(view.ROUND_CELEBRATION_SECONDS - 0.01)
	check(view.snapshot().round_celebrating and not view.snapshot().completion_animation_done
		and view.game.snapshot() == before and app.model.phase != "won",
		"The round celebration remains visible immediately before Pip finishes")
	view.pip._process(0.02)
	await _settle()
	check(view.snapshot().round_celebrating and view.snapshot().completion_animation_done
		and view.game.snapshot() == before and app.model.phase != "won" and completions.is_empty(),
		"Natural animation completion waits for the final phrase recording before entering the chest")
	narration_pending[0] = false
	app.audio.stop_voice()
	await _settle()
	check(view.game.phase == "finished" and app.model.phase == "won" and completions == [true]
		and not view.snapshot().round_celebrating and _pieces(app) == pieces_before,
		"The stopped recording allows exactly one automatic transition without awarding the unopened chest")
	view.action_button.pressed.emit()
	view.pip.gameplay_reaction_finished.emit(true)
	view.pip._process(4.0)
	await _settle()
	check(completions == [true] and _pieces(app) == pieces_before,
		"Late animation callbacks and extra time cannot repeat round completion")
	view.finished.disconnect(record)
	view.completion_audio_playing = audio_gate


func _check_round_controls_hidden(view) -> void:
	for button: Button in view.option_buttons + view.answer_buttons \
		+ [view.listen_button, view.transcript_button, view.action_button]:
		check(not button.is_visible_in_tree() and button.disabled,
			"The completion stage hides and disables " + str(button.name))
	check(not view._progress.is_visible_in_tree() and view.navigation_controls().is_empty(),
		"The completion stage has no redundant progress count or hidden navigable controls")


func _start_round_celebration(app, seed_value: int) -> void:
	check(app.new_round(seed_value, false, "", "phrase"), "A fresh round starts for final celebration coverage")
	await _settle()
	var view = app._phrase
	for question in range(3):
		_solve(view)
		if question < 2:
			view.pip._process(view.pip.GAMEPLAY_HAPPY_SECONDS + 0.01)
			view.action_button.pressed.emit()
	check(view.snapshot().round_celebrating and view.game.completed == 3,
		"Solving all three real questions enters the final celebration fixture")


func _check_round_celebration_interruptions(app) -> void:
	var view = app._phrase
	var pieces_before: int = _pieces(app)
	var audio_gate: Callable = view.completion_audio_playing
	view.completion_audio_playing = func() -> bool: return true
	for interruption in ["menu", "room", "background", "hidden"]:
		app.set_reduced_motion(interruption == "background")
		await _start_round_celebration(app, 108)
		var before: Dictionary = view.game.snapshot()
		view.pip._process(0.8)
		if interruption == "menu":
			app._mode_heading_button.pressed.emit()
		elif interruption == "room":
			app.collection_button.pressed.emit()
		elif interruption == "background":
			app.on_page_hidden()
		else:
			view.hide()
		view.pip._process(4.0)
		view.pip.gameplay_reaction_finished.emit(true)
		view.finished.emit()
		check(view.snapshot().round_celebrating and not view.snapshot().completion_animation_done
			and view.pip._gameplay_reaction.is_empty() and view.game.snapshot() == before
			and app.model.phase != "won" and _pieces(app) == pieces_before,
			"Opening " + interruption + " preserves a pending win without finishing it offscreen")
		if interruption == "menu":
			app._mode_panel.close_button.pressed.emit()
		elif interruption == "room":
			app._collection_back.pressed.emit()
		elif interruption == "background":
			app.on_page_visible()
		else:
			view.show()
		await _settle()
		view.pip.set_process(false)
		check(view.snapshot().round_celebrating and not view.snapshot().completion_animation_done
			and view.pip._gameplay_reaction == "happy"
			and view.pip._gameplay_left > view.ROUND_CELEBRATION_SECONDS - 0.25
			and view.pip._gameplay_left <= view.ROUND_CELEBRATION_SECONDS
			and view.game.snapshot() == before,
			"Returning from " + interruption + " restarts the full completion celebration")
		_check_round_controls_hidden(view)
		if view.reduced_motion:
			check(view.pip.pose == 3 and view.pip.reduced_motion,
				"Reduced motion keeps the completion scene readable with a static happy Pip")
		view.pip._process(view.ROUND_CELEBRATION_SECONDS + 0.01)
		await _settle()
		check(view.snapshot().completion_animation_done and app.model.phase != "won"
			and _pieces(app) == pieces_before,
			"The resumed completion still obeys the final recording gate after " + interruption)
	await _start_round_celebration(app, 109)
	view.stop()
	app._resume_phrase()
	view.pip.gameplay_reaction_finished.emit(true)
	view.pip._process(4.0)
	await _settle()
	check(not view.snapshot().round_celebrating and app.model.phase != "won" and _pieces(app) == pieces_before,
		"Stopping cancels the pending round completion even if its old callback arrives after resume")
	await _start_round_celebration(app, 110)
	for dimensions in [Vector2i(1366, 768), Vector2i(390, 844), Vector2i(844, 390), Vector2i(320, 320)]:
		root.size = dimensions
		await _settle()
		var bounds: Rect2 = view.get_global_rect().grow(0.75)
		for control: Control in [view.pip, view._heading, view._feedback]:
			check(control.is_visible_in_tree() and bounds.encloses(control.get_global_rect()),
				"The completion " + str(control.name) + " stays on screen at " + str(dimensions))
		check(not view.pip.get_global_rect().grow(-0.75).intersects(view._heading.get_global_rect())
			and not view._heading.get_global_rect().grow(-0.75).intersects(view._feedback.get_global_rect()),
			"Pip and completion text remain separate at %s: Pip %s, heading %s, caption %s" % [
				dimensions, view.pip.get_global_rect(), view._heading.get_global_rect(), view._feedback.get_global_rect()])
	check(app.new_round(111, false, "", "phrase"), "Reconfiguration replaces an unfinished completion stage")
	await _settle()
	var replacement: Dictionary = view.game.snapshot()
	view.completion_audio_playing = audio_gate
	view.pip.gameplay_reaction_finished.emit(true)
	view.pip._process(4.0)
	await _settle()
	check(not view.snapshot().round_celebrating and not view.snapshot().completion_animation_done
		and view.game.snapshot() == replacement and view.game.completed == 0 and app.model.phase != "won"
		and _pieces(app) == pieces_before,
		"Late final-celebration events cannot advance a replacement round or award its old win")
	app.set_reduced_motion(true)


func _check_celebration_interruptions(app) -> void:
	var view = app._phrase
	var pieces_before: int = _pieces(app)
	app.set_reduced_motion(false)
	for interruption in ["menu", "room", "background", "hidden", "stop"]:
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
		elif interruption == "room":
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
		elif interruption == "room":
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
	for interruption in ["menu", "room", "background", "resize"]:
		var before: Dictionary = view.game.snapshot()
		var start: Vector2 = view.option_buttons[0].get_global_rect().get_center()
		var end: Vector2 = view.answer_buttons[0].get_global_rect().get_center()
		await _pointer_button(start, true, method)
		await _pointer_motion(end, end - start, method)
		check(view.snapshot().dragging and view.game.snapshot() == before,
			method + " has an uncommitted drag before " + interruption)
		if interruption == "menu":
			app._mode_heading_button.pressed.emit()
		elif interruption == "room":
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
		elif interruption == "room":
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
	await _pointer_button(start, true, method)
	check(not view.snapshot().dragging, method + " waits for movement before starting a card drag")
	await _pointer_motion(end, end - start, method)
	var preview: Dictionary = view.snapshot()
	check(preview.dragging and not preview.drag_word.is_empty() and view.game.snapshot() == before,
		method + " shows a drag preview while preserving the answer until release")
	if drop_kind != "*":
		check(preview.drop_kind == drop_kind, method + " identifies the expected drop destination: " + drop_kind)
	if drop_index >= 0:
		check(preview.drop_index == drop_index, method + " previews the final word position")
	if method == "touch":
		await _pointer_button(end, true, "emulated")
		await _pointer_button(end, false, "emulated")
		check(view.snapshot().dragging and view.game.snapshot() == before,
			"Emulated mouse events cannot finish or mutate the owning touch drag")
	await _pointer_button(end, false, method, canceled)
	await _settle()
	check(not view.snapshot().dragging and view.snapshot().drag_word.is_empty(),
		method + " release clears the drag preview")


func _snapshot_rect(values: Array) -> Rect2:
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


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
	for interruption in ["menu", "room", "background"]:
		view.listen_button.pressed.emit()
		check(app.audio.voice.playing, "Listen plays the phrase before opening " + interruption)
		var before: Dictionary = view.game.snapshot()
		if interruption == "menu":
			app._mode_heading_button.pressed.emit()
		elif interruption == "room":
			app.collection_button.pressed.emit()
		else:
			app.on_page_hidden()
		check(view.snapshot().paused and view.navigation_controls().is_empty() and not app.audio.voice.playing,
			"Opening " + interruption + " pauses phrase interaction and stops speech")
		for button in view.option_buttons + view.answer_buttons + [view.action_button, view.listen_button, view.transcript_button]:
			button.pressed.emit()
		view.finished.emit()
		app.audio.voice.finished.emit()
		check(view.game.snapshot() == before and not app.audio.voice.playing and app.model.phase != "won",
			"Covered phrase controls and stale audio callbacks cannot mutate the game behind " + interruption)
		if interruption == "menu":
			app._mode_panel.close_button.pressed.emit()
		elif interruption == "room":
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
	check(app.audio.muted and view.snapshot().transcript_visible and view._heading.is_visible_in_tree()
		and view._heading.text == view.game.current_question().text,
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
	check(app._phrase.game.questions.all(func(question: Dictionary) -> bool: return question.level == "advanced"),
		"The next Phrase Builder round applies the age chosen in Pip's room")
	check(_pieces(app) == 1 and not app.chest.hold_effect_snapshot().surprise.active,
		"A new phrase round keeps saved progress and clears the previous displayed gift")


func _check_layout(app) -> void:
	var probe = PhraseModel.new()
	var layout_seed: int = -1
	for seed_value in range(128):
		if probe.reset(app.data.words, "10-plus", seed_value) and probe.current_question().words.size() == 4:
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
		check(view.answer_buttons.size() == 4 and view.option_buttons.size() == 6, "The hardest phrase retains every answer slot and choice")
		var buttons: Array = view.answer_buttons + view.option_buttons + [view.listen_button, view.action_button, view.transcript_button]
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
		check(view.snapshot().transcript_visible and view._heading.is_visible_in_tree()
			and bounds.encloses(view._heading.get_global_rect()), "Muted phrase text stays visible at " + str(dimensions))
		_check_phrase_heading(view, str(dimensions))
		for helper: Button in [view.listen_button, view.transcript_button]:
			check(not view._heading.get_global_rect().grow(-0.5).intersects(helper.get_global_rect().grow(-0.5)),
				"The target phrase and " + str(helper.name) + " do not overlap at " + str(dimensions))
		check(view.navigation_controls().has(app._default_focus()), "The host default focus belongs to a playable phrase control")
	_solve(app._phrase)
	await _settle()
	check(app._phrase.transcript_button.disabled and app._phrase.transcript_button.text.is_empty()
		and app._phrase.snapshot().transcript_visible,
		"The smallest viewport retains the completed phrase and inactive eye helper")
	_check_phrase_heading(app._phrase, "(320, 320), correct feedback")
	for button: Button in app._phrase.answer_buttons + app._phrase.option_buttons \
		+ [app._phrase.listen_button, app._phrase.action_button, app._phrase.transcript_button]:
		if button.is_visible_in_tree():
			_check_button_text_fit(button, "(320, 320), correct feedback")


func _check_phrase_heading(view, context: String) -> void:
	var heading: Label = view._heading
	var font: Font = heading.get_theme_font("font")
	var font_size: int = heading.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(heading.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	check(heading.text == view.game.current_question().text and text_width <= heading.size.x + 0.5,
		"The complete revealed phrase '%s' fits at %s: text %.2f <= width %.2f" % [
			heading.text, context, text_width, heading.size.x])
	check(not heading.get_global_rect().grow(-0.5).intersects(view._progress.get_global_rect().grow(-0.5)),
		"The revealed phrase and question progress do not overlap at " + context)


func _check_button_text_fit(button: Button, context: String) -> void:
	var font: Font = button.get_theme_font("font")
	var font_size: int = button.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var horizontal_padding: float = button.get_theme_stylebox("normal").get_minimum_size().x
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
	check(app.playroom_state.age_band_id == id and app._age_catalog.visible, "The real age button saves " + id)
	app._collection_back.pressed.emit()
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
