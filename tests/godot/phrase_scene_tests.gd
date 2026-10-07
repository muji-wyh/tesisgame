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
	check(app.audio.voice.playing and app.audio.voice.stream == load("res://assets/audio/voice/phrase-intro.wav"),
		"Entering the mode plays its recorded instructions")
	app.audio.voice.finished.emit()
	check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + view.game.current_question().audio),
		"The instruction recording is followed by the current spoken phrase")
	view.finished.emit()
	app.chest_button.button_down.emit()
	check(app.model.phase != "won" and not app._holding_chest and _pieces(app) == 0,
		"Early completion signals and chest presses cannot skip the three questions")
	view.option_buttons[0].pressed.emit()
	check(view.game.answer == [0] and view.answer_buttons[0].text == view.game.options[0].text,
		"A real word-bank button fills the first answer slot")
	check(app.audio.voice.playing and app.audio.voice.stream == load("res://" + view.game.options[0].audio),
		"Choosing a word plays its existing pronunciation")
	check(view.option_buttons[0].disabled and not view.answer_buttons[0].disabled,
		"A chosen tile leaves the bank and remains removable from the answer")
	await _check_interruptions(app)
	await _check_muted_help(app)
	var questions_before_age: Array = view.game.questions.duplicate(true)
	var answer_before_age: Array = view.game.answer.duplicate()
	await _choose_age(app, "10-plus")
	check(app.playroom_state.age_band_id == "10-plus" and view.game.questions == questions_before_age
		and view.game.answer == answer_before_age,
		"Changing age in Pip's room preserves the current phrase and applies to the next round")
	view.clear_button.pressed.emit()
	check(view.game.answer.is_empty(), "The Clear button returns the current answer to the bank")
	await _check_controller_and_keyboard(app)
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
	check(view.game.mistakes == 4 and app.audio.pair_feedback.playing
		and app.audio.pair_feedback.stream == load("res://assets/imported-audio/pair-feedback/wrong.wav")
		and app.audio.voice.stream == load("res://assets/audio/voice/phrase-try-again.wav"),
		"Incorrect submissions have the wrong sound and a recorded correction prompt")
	while view.game.answer.size() > 1:
		view.answer_buttons[0].pressed.emit()
	check(view.game.answer.size() == 1 and view.answer_buttons[0].text == target[0],
		"Answer buttons can remove misplaced words while keeping the correctly positioned word")
	_select_words(view, target.slice(1))
	view.action_button.pressed.emit()
	check(view.game.phase == "correct" and view.game.completed == 1 and view.action_button.text == "Continue",
		"A repaired phrase offers an explicit Continue action")
	check(view.transcript_button.disabled and view.transcript_button.text in ["Phrase shown", "Shown"]
		and not view.navigation_controls().has(view.transcript_button),
		"Correct feedback labels the already shown phrase and removes its inactive toggle from navigation")
	view.transcript_button.pressed.emit()
	check(view.snapshot().transcript_visible and view.game.phase == "correct",
		"An old transcript signal cannot hide the completed phrase")
	check(app.audio.pair_feedback.playing
		and app.audio.pair_feedback.stream == load("res://assets/imported-audio/pair-feedback/right.wav")
		and app.audio.voice.stream == load("res://" + view.game.current_question().audio),
		"Correct feedback plays the right sound and repeats the completed phrase")
	check(app.model.phase != "won" and _pieces(app) == 0, "The first correct phrase does not unlock a chest")
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
	_solve(view)
	check(view.game.completed == 2 and app.model.phase != "won" and _pieces(app) == 0,
		"Two correct phrases still leave the reward locked")
	view.action_button.pressed.emit()
	_solve(view)
	check(view.game.completed == 3 and view.game.phase == "correct" and view.action_button.text == "Open chest"
		and app.model.phase != "won" and _pieces(app) == 0,
		"The third correct phrase offers Open chest without claiming a reward early")
	view.action_button.pressed.emit()
	check(view.game.phase == "finished" and app.model.phase == "won" and app.model.chest_state == "closed"
		and app.chest_button.is_visible_in_tree() and not view.visible and not app._new_adventure_button.visible,
		"Open chest enters the existing unopened-chest result screen")
	check(app.audio.voice.stream == load("res://assets/audio/voice/phrase-complete.wav"),
		"The transition to the chest has a recorded completion prompt")
	view.finished.emit()
	view.action_button.pressed.emit()
	check(_pieces(app) == 0 and app.model.chest_state == "closed", "Duplicate phrase completion cannot award a treasure")
	await _check_chest_and_new_adventure(app, directory, progress_script)
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
		for button in view.option_buttons + view.answer_buttons + [view.action_button, view.clear_button, view.listen_button, view.transcript_button]:
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
	for dimensions in [Vector2i(1366, 768), Vector2i(390, 844), Vector2i(844, 390), Vector2i(320, 568), Vector2i(320, 320)]:
		root.size = dimensions
		await _settle()
		var view = app._phrase
		var bounds: Rect2 = root.get_visible_rect().grow(0.75)
		var scale_factor: float = app.Style.ui_scale(view)
		check(bounds.encloses(view.get_global_rect()), "Phrase Builder stays within the host at " + str(dimensions))
		check(view.answer_buttons.size() == 4 and view.option_buttons.size() == 6, "The hardest phrase retains every answer slot and choice")
		var buttons: Array = view.answer_buttons + view.option_buttons + [view.listen_button, view.action_button, view.clear_button, view.transcript_button]
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
		check(view.navigation_controls().has(app._default_focus()), "The host default focus belongs to a playable phrase control")
	_solve(app._phrase)
	await _settle()
	check(app._phrase.transcript_button.disabled and app._phrase.transcript_button.text == "Shown",
		"The smallest viewport labels its completed phrase with the inactive Shown control")
	for button: Button in app._phrase.answer_buttons + app._phrase.option_buttons \
		+ [app._phrase.listen_button, app._phrase.action_button, app._phrase.clear_button, app._phrase.transcript_button]:
		if button.is_visible_in_tree():
			_check_button_text_fit(button, "(320, 320), correct feedback")


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
