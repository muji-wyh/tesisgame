extends SceneTree

var checks: int = 0
var failures: int = 0
var answers: Array = []
var endings: Array = []
var heard: Array = []
var progress: Array = []
var ready_prompts: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	check(FileAccess.file_exists("res://scripts/choice_game.gd"), "The choice modes have a native Godot control")
	if failures:
		quit(1)
		return
	var game = load("res://scripts/choice_game.gd").new()
	root.add_child(game)
	check(game.has_method("continue_feedback") and game.has_method("set_audio_available"),
		"Choice games provide explicit continuation and a visible audio fallback")
	if failures:
		game.queue_free()
		await process_frame
		quit(1)
		return
	game.size = Vector2(456, 200)
	game.answer_chosen.connect(func(word: Dictionary, correct: bool): answers.append([word.id, correct]))
	game.round_finished.connect(func(won: bool, words: Array): endings.append([won, words]))
	game.hear_requested.connect(func(word: Dictionary): heard.append(word.id))
	game.progress_changed.connect(func(good: int, bad: int): progress.append([good, bad]))
	game.prompt_ready.connect(func(): ready_prompts += 1)
	var words: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	var palette: Dictionary = load("res://scripts/game_data.gd").theme("spring")
	await process_frame
	for mode in ["sky", "listen"]:
		game.start_round(words, mode, palette, 71)
		if "--screenshots" in OS.get_cmdline_user_args():
			await _capture(game, mode)
		var first: Dictionary = game.current_target.duplicate(true)
		var choices: Array = game.choices.duplicate(true)
		game.start_round(words, mode, palette, 99)
		game.start_round(words, mode, palette, 71)
		check(game.current_target == first and game.choices == choices, "Seeded %s prompts reproduce target and answer order" % mode)
		check(game.status == "asking" and game.successes == 0 and game.mistakes == 0, "A new %s round resets its state" % mode)
		check(game.controls().size() == (3 if mode == "listen" else 2), "Only the %s mode's active buttons enter navigation" % mode)
		if mode == "listen":
			_check_main_replay(game, "Asking")
		else:
			_check_blocked_replay(game, "Sky asking")
		var before_answers: int = answers.size()
		var before_prompts: int = ready_prompts
		var wrong: int = _answer_index(game, false)
		var question_rects: Array = _question_rects(game)
		game.answer_buttons[wrong].pressed.emit()
		check(game.status == "feedback" and game.mistakes == 1 and game.successes == 0,
			"A wrong answer opens feedback and records one attempt")
		check(answers.size() == before_answers + 1 and not answers.back()[1], "One attempt emits exactly one incorrect answer")
		check(game.controls().size() == (5 if mode == "listen" else 4) and game.feedback_view.visible
			and game.feedback_view.current_word.id == first.id
			and game.feedback_view.word_label.text == first.text
			and game.feedback_view.picture.texture.resource_path == "res://" + first.image,
			"Wrong feedback teaches the correct picture and word with Hear, Continue and reachable answers")
		check(game._stage.visible and game.answer_buttons.all(func(button: Button) -> bool: return button.visible and not button.disabled), "Answer feedback keeps the question and both answer cards visible and usable")
		check(_question_rects(game) == question_rects, "Entering feedback does not move the target or answers")
		check(not game.feedback_view.get_global_rect().intersects(game._stage.get_global_rect()) and game.answer_buttons.all(func(button: Button) -> bool: return not game.feedback_view.get_global_rect().intersects(button.get_global_rect())), "Compact feedback does not cover the question or answer cards")
		if mode == "listen":
			_check_main_replay(game, "Wrong feedback")
			_check_feedback_replay_guards(game)
		else:
			_check_blocked_replay(game, "Sky feedback")
		if "--screenshots" in OS.get_cmdline_user_args():
			await _capture(game, mode + "-correction")
		await create_timer(0.8).timeout
		check(game.status == "feedback" and game.current_target == first,
			"Correction remains visible until the learner explicitly continues")
		game.pause(true)
		game.continue_feedback()
		game.feedback_view.action_button.pressed.emit()
		check(game.status == "feedback" and game.current_target == first, "A modal pause prevents delayed feedback progression")
		game.set_palette(load("res://scripts/game_data.gd").theme("winter"))
		check(game.status == "feedback" and game.current_target == first and game.mistakes == 1,
			"Season palette changes preserve a paused question and progress")
		game.pause(false)
		game.continue_feedback()
		check(game.current_target == first and game.choices == choices and game.status == "asking",
			"A mistake retries the same target and answer positions")
		check(_question_rects(game) == question_rects, "Retrying a mistake restores input without moving the board")
		check(ready_prompts == before_prompts + 1, "Re-enabled choices notify the host to restore controller focus")
		game.pause(true)
		before_answers = answers.size()
		game.answer_buttons[_answer_index(game, true)].pressed.emit()
		check(answers.size() == before_answers and game.controls().is_empty(), "A paused question blocks native and synthetic input")
		game.pause(false)
		var seen: Array[String] = []
		var before_endings: int = endings.size()
		for index in range(5):
			check(not seen.has(game.current_target.id), "Successful targets do not repeat within a round")
			seen.append(game.current_target.id)
			check(game.choices.size() == 2 and game.choices[0].id != game.choices[1].id
				and _answer_index(game, true) >= 0, "Each prompt offers one correct word and a different alternative")
			var right: int = _answer_index(game, true)
			question_rects = _question_rects(game)
			game.answer_buttons[right].pressed.emit()
			check(game.successes == index + 1 and game.mistakes == 1, "A correct answer awards one success before Continue")
			check(game.feedback_view.current_word == game.current_target and game.feedback_view.word_label.visible
				and game.feedback_view.picture.visible, "A successful answer reinforces that exact picture-word association")
			check(_question_rects(game) == question_rects and game._stage.visible and game.answer_buttons[right].visible, "Correct answers, including the final one, preserve the visible question geometry")
			if mode == "listen" and index in [0, 4]:
				_check_main_replay(game, "Final win feedback" if index == 4 else "Correct feedback")
			game.feedback_view.action_button.pressed.emit()
		check(game.status == "won" and endings.size() == before_endings + 1 and endings.back()[0],
			"Five correct answers finish with exactly one win")
		check(game.found_words.size() == 5 and endings.back()[1].size() == 5 and progress.back() == [5, 1],
			"Winning reports the five earned words and final progress")
		game.continue_feedback()
		game.answer_buttons[0].pressed.emit()
		check(endings.size() == before_endings + 1 and game.successes == 5, "Completed rounds ignore delayed callbacks and taps")
		_check_blocked_replay(game, mode + " completed win")
		game.start_round(words, mode, palette, 17)
		game.answer_buttons[_answer_index(game, true)].pressed.emit()
		game.continue_feedback()
		for attempt in range(3):
			game.answer_buttons[_answer_index(game, false)].pressed.emit()
			if mode == "listen" and attempt == 2:
				_check_main_replay(game, "Final loss feedback")
			game.continue_feedback()
		check(game.status == "lost" and game.mistakes == 3 and game.successes == 1 and not endings.back()[0],
			"Three mistakes end the round after retaining earlier success")
		check(game.found_words.size() == 1 and endings.back()[1].size() == 1,
			"A loss reports only the successfully learned word")
		_check_blocked_replay(game, mode + " completed loss")
		game.start_round(words, mode, palette, 17)
		game.set_reduced_motion(true)
		for dimensions in [Vector2(456, 200), Vector2(960, 360), Vector2(240, 200)]:
			game.start_round(words, mode, palette, 17)
			game.size = dimensions
			await process_frame
			await process_frame
			for control in game.controls():
				check(control.size.x >= 72 and control.size.y >= 72, "Choice controls retain 72px minimum touch targets")
				check(game.get_global_rect().grow(0.1).encloses(control.get_global_rect()), "Choice controls fit their assigned play area")
			check(not game.answer_buttons[0].get_global_rect().intersects(game.answer_buttons[1].get_global_rect()),
				"Answer touch targets remain separate")
			var asking_rects: Array = _question_rects(game)
			game.answer_buttons[_answer_index(game, false)].pressed.emit()
			check(_question_rects(game) == asking_rects and game._stage.visible,
				"Responsive feedback retains the exact question layout at " + str(dimensions))
			check(not game.feedback_view.get_global_rect().intersects(game._stage.get_global_rect()) and game.answer_buttons.all(func(button: Button) -> bool: return not game.feedback_view.get_global_rect().intersects(button.get_global_rect())),
				"Responsive feedback stays beside or below the complete question at " + str(dimensions))
			for control in game.controls():
				check(game.get_global_rect().grow(0.1).encloses(control.get_global_rect()), "Responsive feedback actions stay inside the game")
			game.continue_feedback()
		check(game.status == "asking" and game.successes == 0, "Reduced motion and resizing leave the question unchanged")
		game.set_reduced_motion(false)
		game.start_round(words, mode, palette, 42)
		game.answer_buttons[_answer_index(game, true)].pressed.emit()
		before_endings = endings.size()
		game.stop()
		_check_blocked_replay(game, mode + " stopped")
		game.continue_feedback()
		game.answer_buttons[0].pressed.emit()
		game.hear_button.pressed.emit()
		check(game.status == "stopped" and game.controls().is_empty() and endings.size() == before_endings,
			"Stopping cancels pending feedback and input without delivering a result")
		_check_feedback_answers(game, words, palette, mode)
	game.start_round(words, "listen", palette, 17)
	var fallback_target: Dictionary = game.current_target.duplicate()
	game.set_audio_available(false)
	if "--screenshots" in OS.get_cmdline_user_args():
		await _capture(game, "listen-no-sound")
	check(game.target_word_label.visible and game.target_word_label.text == fallback_target.text
		and not game.controls().has(game.hear_button) and game.controls().size() == 2,
		"A silent Listen question visibly names its target and retains answerable picture choices")
	var heard_before: int = heard.size()
	game.hear_button.pressed.emit()
	check(heard.size() == heard_before, "Missing audio cannot trigger a dead Hear action")
	game.set_audio_available(true)
	check(not game.target_word_label.visible and game.hear_button.visible and game.current_target == fallback_target,
		"Recovered audio restores listening without changing the question")
	game.answer_buttons[_answer_index(game, false)].pressed.emit()
	game.set_audio_available(false)
	check(game.feedback_view.word_label.text == fallback_target.text and game.controls().size() == 3,
		"A playback failure during correction keeps the right answer visible, Continue and both answers usable")
	game.set_audio_available(true)
	var semantic_words: Array = words.filter(func(word: Dictionary):
		return word.id in ["earth", "planet", "comet", "meteor", "rocket"])
	var data = load("res://scripts/game_data.gd")
	for seed_value in range(30):
		game.start_round(semantic_words, "sky", palette, seed_value)
		for question in range(5):
			check(not data.confusable_words(game.choices[0].id, game.choices[1].id),
				"Semantic alternatives never demand an arbitrary choice between overlapping labels")
			game.answer_buttons[_answer_index(game, true)].pressed.emit()
			game.continue_feedback()
	var indistinguishable: Array = []
	for index in range(5):
		var word: Dictionary = words[0].duplicate()
		word.id = "same-name-%d" % index
		indistinguishable.append(word)
	game.start_round(indistinguishable, "sky", palette, 1)
	check(game.status == "unavailable" and game.controls().is_empty()
		and game.status_label.text.contains("different"),
		"An ambiguous custom pool shows an explanation instead of a misleading choice")
	game.start_round(words.slice(0, 4), "sky", palette, 1)
	check(game.status == "unavailable" and game.controls().is_empty(), "Too little vocabulary cannot start an unwinnable round")
	game.start_round([words[0], words[0], words[0], words[0], words[0]], "sky", palette, 1)
	check(game.status == "unavailable", "Duplicate vocabulary cannot count as five distinct targets")
	game.start_round(words, "unknown", palette, 1)
	check(game.status == "unavailable", "Unknown choice modes stay inactive")
	var holder := VBoxContainer.new()
	holder.size = Vector2(456, 200)
	root.add_child(holder)
	var entering = load("res://scripts/choice_game.gd").new()
	entering.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_child(entering)
	entering.hide()
	entering.start_round(words, "sky", palette, 31)
	entering.show()
	await process_frame
	await process_frame
	check(entering._motion != null and entering._motion.is_running()
		and entering.target_picture.position.y < entering._picture_position.y,
		"The first picture still arrives after a newly shown container finishes layout")
	var initial_motion = entering._motion
	entering.set_audio_available(entering.audio_available)
	check(entering._motion == initial_motion and entering._motion.is_running(), "An unchanged audio status cannot interrupt a visible Sky arrival")
	entering.answer_buttons[_answer_index(entering, true)].pressed.emit()
	entering.continue_feedback()
	await process_frame
	await process_frame
	check(entering._motion == null and entering.target_picture.position == entering._picture_position, "Later Sky questions replace the picture in place without another entrance animation")
	entering.start_round(words, "sky", palette, 32)
	entering.stop()
	await process_frame
	await process_frame
	check(entering._motion == null and entering.status == "stopped", "Stopping invalidates an arrival waiting for layout")
	entering.start_round(words, "sky", palette, 35)
	entering.set_reduced_motion(true)
	entering.set_reduced_motion(false)
	await process_frame
	await process_frame
	check(entering._motion == null, "Cancelling motion cannot revive a previously queued arrival")
	entering.start_round(words, "sky", palette, 33)
	entering.start_round(words, "listen", palette, 34)
	await process_frame
	await process_frame
	check(entering._motion == null and entering.mode_id == "listen" and entering.hear_button.visible,
		"Switching modes invalidates a previous deferred picture arrival")
	holder.queue_free()
	game.queue_free()
	await process_frame
	print("Choice modes: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_feedback_answers(game, words: Array, palette: Dictionary, mode: String) -> void:
	game.set_reduced_motion(true)
	game.start_round(words, mode, palette, 71)
	var first: Dictionary = game.current_target.duplicate(true)
	var choices: Array = game.choices.duplicate(true)
	var right: int = _answer_index(game, true)
	var wrong: int = _answer_index(game, false)
	var rects: Array = _question_rects(game)
	var before_answers: int = answers.size()
	var before_progress: int = progress.size()
	var asking: Array = _choice_state(game)
	game._choose(-1)
	game._choose(game.choices.size())
	check(_choice_state(game) == asking, "%s invalid indices cannot score an unanswered question" % mode)
	game.answer_buttons[wrong].grab_focus()
	game.answer_buttons[wrong].pressed.emit()
	check(game.feedback_view.action_button.has_focus(), "%s grading a wrong answer moves actual keyboard/controller focus to Continue" % mode)
	var controls: Array = game.controls()
	check(controls.size() == (5 if mode == "listen" else 4) and controls[0] == game.feedback_view.action_button
		and controls.has(game.feedback_view.picture_button)
		and controls.slice(controls.size() - 2) == game.answer_buttons,
		"%s feedback keeps Continue first and both visible answers reachable by keyboard/controller" % mode)
	check(game.answer_buttons.all(func(button: Button) -> bool: return button.visible and not button.disabled),
		"%s feedback answers accept pointer input" % mode)
	var style = load("res://scripts/ui_style.gd")
	for state in ["normal", "hover", "pressed"]:
		check(game.answer_buttons[right].get_theme_stylebox(state).border_color == style.GOOD
			and game.answer_buttons[wrong].get_theme_stylebox(state).border_color == style.WRONG,
			"%s usable feedback retains correct/wrong colors in %s" % [mode, state])
	var frozen: Array = _choice_state(game)
	game._choose(-1)
	game._choose(game.choices.size())
	check(_choice_state(game) == frozen, "%s invalid answer indices cannot dismiss or score feedback" % mode)
	for guard in ["paused", "hidden"]:
		if guard == "paused":
			game.pause(true)
		else:
			game.hide()
		game.answer_buttons[right].pressed.emit()
		game.answer_buttons[wrong].pressed.emit()
		game.continue_feedback()
		check(_choice_state(game) == frozen and game.controls().is_empty(),
			"%s %s feedback blocks answer taps and continuation without altering the question" % [mode, guard])
		if guard == "paused":
			game.pause(false)
		else:
			game.show()
	check(_question_rects(game) == rects, "%s showing or resuming feedback preserves the question geometry" % mode)
	game.answer_buttons[right].grab_focus()
	game.answer_buttons[right].pressed.emit()
	check(game.status == "feedback" and game.current_target == first and game.choices == choices
		and game.successes == 1 and game.mistakes == 1,
		"%s tapping the visible correct answer during wrong feedback grades the same question immediately" % mode)
	check(answers.size() == before_answers + 2 and progress.size() == before_progress + 2 and answers.back() == [first.id, true]
		and game.found_words == [first] and progress.back() == [1, 1],
		"%s correction tap awards exactly one success and emits exactly one answer/progress update" % mode)
	check(game.feedback_view.action_button.has_focus(), "%s grading a correction returns actual focus to Continue" % mode)
	check(_question_rects(game) == rects and game._stage.visible and game.feedback_view.visible,
		"%s correction tap keeps the original target, answers and feedback in place" % mode)

	# Either old answer is an explicit next-question action after correct feedback.
	for advance_index in range(2):
		game.start_round(words, mode, palette, 17)
		first = game.current_target.duplicate(true)
		rects = _question_rects(game)
		game.answer_buttons[_answer_index(game, true)].pressed.emit()
		before_answers = answers.size()
		before_progress = progress.size()
		game.answer_buttons[advance_index].pressed.emit()
		check(game.status == "asking" and game.current_target.id != first.id and game.successes == 1 and game.mistakes == 0,
			"%s old answer %d advances correct feedback to the next unanswered question" % [mode, advance_index])
		check(answers.size() == before_answers and progress.size() == before_progress and game.found_words == [first],
			"%s old answer %d cannot blindly score the newly presented question" % [mode, advance_index])
		check(_question_rects(game) == rects and not game.feedback_view.visible,
			"%s advancing with an old answer retains the question geometry" % mode)

	game.start_round(words, mode, palette, 17)
	first = game.current_target.duplicate(true)
	choices = game.choices.duplicate(true)
	wrong = _answer_index(game, false)
	before_answers = answers.size()
	var before_endings: int = endings.size()
	for attempt in range(3):
		game.answer_buttons[wrong].pressed.emit()
		check(game.status == "feedback" and game.current_target == first and game.choices == choices
			and game.mistakes == attempt + 1 and game.successes == 0 and answers.size() == before_answers + attempt + 1,
			"%s another wrong feedback tap records only another attempt on the same question" % mode)
	check(endings.size() == before_endings, "%s final loss feedback waits for an explicit action" % mode)
	before_progress = progress.size()
	frozen = _choice_state(game)
	game._choose(-1)
	check(_choice_state(game) == frozen, "%s invalid input cannot leave terminal feedback" % mode)
	game.answer_buttons[_answer_index(game, true)].pressed.emit()
	check(game.status == "lost" and game.successes == 0 and game.mistakes == 3
		and answers.size() == before_answers + 3 and progress.size() == before_progress
		and endings.size() == before_endings + 1 and not endings.back()[0],
		"%s tapping even the correct answer after the last mistake only opens the loss result" % mode)
	frozen = _choice_state(game)
	game.answer_buttons[0].pressed.emit()
	game.continue_feedback()
	check(_choice_state(game) == frozen, "%s a completed loss cannot score or finish again" % mode)

	game.start_round(words, mode, palette, 17)
	for index in range(5):
		game.answer_buttons[_answer_index(game, true)].pressed.emit()
		if index < 4:
			game.continue_feedback()
	before_answers = answers.size()
	before_progress = progress.size()
	before_endings = endings.size()
	check(game.status == "feedback" and game.successes == 5, "%s final success still presents its association feedback" % mode)
	game.answer_buttons[0].pressed.emit()
	check(game.status == "won" and game.successes == 5 and game.mistakes == 0
		and answers.size() == before_answers and progress.size() == before_progress
		and endings.size() == before_endings + 1 and endings.back()[0],
		"%s tapping an answer after final success opens the win result without another score" % mode)
	frozen = _choice_state(game)
	game.answer_buttons[1].pressed.emit()
	game.continue_feedback()
	check(_choice_state(game) == frozen, "%s a completed win cannot score or finish again" % mode)

	game.start_round(words, mode, palette, 17)
	game.answer_buttons[_answer_index(game, false)].pressed.emit()
	game.stop()
	frozen = _choice_state(game)
	game.answer_buttons[0].pressed.emit()
	game.answer_buttons[1].pressed.emit()
	game.continue_feedback()
	check(_choice_state(game) == frozen and game.controls().is_empty(), "%s stopped feedback blocks all stale answer actions" % mode)
	game.set_reduced_motion(false)


func _choice_state(game) -> Array:
	return [game.status, game.current_target.duplicate(true), game.choices.duplicate(true), game.successes, game.mistakes,
		game.found_words.duplicate(true), answers.size(), endings.size(), progress.size(), ready_prompts]


func _check_main_replay(game, label: String) -> void:
	var before: Array = _choice_state(game)
	var rects: Array = _question_rects(game)
	var feedback: Array = [game.feedback_view.visible, game.feedback_view.current_word.duplicate(true), game.feedback_view.heading_label.text]
	var count: int = heard.size()
	check(game.hear_button.visible and not game.hear_button.disabled and game.controls().has(game.hear_button),
		label + " exposes the large Hear button to pointer and keyboard navigation")
	if game.status == "feedback":
		check(game.controls()[0] == game.feedback_view.action_button and game.feedback_view.action_button.has_focus(),
			label + " still defaults to Continue after grading")
	game.hear_button.grab_focus()
	check(game.hear_button.has_focus(), label + " permits keyboard focus on the large Hear button")
	game.hear_button.pressed.emit()
	game.hear_button.pressed.emit()
	check(heard.size() == count + 2 and heard.slice(count) == [game.current_target.id, game.current_target.id],
		label + " replays the same current target on every large Hear press")
	check(_choice_state(game) == before and _question_rects(game) == rects
		and [game.feedback_view.visible, game.feedback_view.current_word, game.feedback_view.heading_label.text] == feedback,
		label + " replay leaves scores, question, feedback and geometry unchanged")


func _check_blocked_replay(game, label: String) -> void:
	var before: Array = _choice_state(game)
	var count: int = heard.size()
	game.hear_button.pressed.emit()
	check(heard.size() == count and _choice_state(game) == before and not game.controls().has(game.hear_button),
		label + " cannot replay or navigate to the large Hear button")


func _check_feedback_replay_guards(game) -> void:
	game.pause(true)
	check(game.hear_button.disabled, "Paused Listen feedback disables its large Hear button")
	_check_blocked_replay(game, "Paused Listen feedback")
	game.pause(false)
	game.hide()
	_check_blocked_replay(game, "Hidden Listen feedback")
	game.show()
	game.set_audio_available(false)
	check(game.target_word_label.visible and game.target_word_label.text == game.current_target.text
		and not game.hear_button.visible and game.hear_button.disabled and game.feedback_view.visible,
		"Losing audio during feedback replaces large Hear with the same written target")
	_check_blocked_replay(game, "Silent Listen feedback")
	game.set_audio_available(true)
	check(game.hear_button.visible and not game.hear_button.disabled and not game.target_word_label.visible
		and game.controls().has(game.hear_button) and game.feedback_view.visible,
		"Recovering audio during feedback restores large Hear without leaving the correction")
	var count: int = heard.size()
	game.hear_button.pressed.emit()
	check(heard.size() == count + 1 and heard.back() == game.current_target.id,
		"Recovered feedback replays its current target immediately")


func _question_rects(game) -> Array:
	return [game._stage.get_rect(), game.target_picture.get_rect(), game.answer_buttons[0].get_rect(),
		game.answer_buttons[1].get_rect(), game.feedback_view.get_rect(), game.custom_minimum_size]


func _answer_index(game, correct: bool) -> int:
	for index in range(game.choices.size()):
		if (game.choices[index].id == game.current_target.id) == correct:
			return index
	return -1


func _capture(game, mode: String) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 480)
	game.size = Vector2(456, 200)
	game.set_reduced_motion(true)
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := "res://build/visuals"
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = root.get_texture().get_image().get_region(Rect2i(0, 0, 456, 200))
	check(image.save_png(directory + "/choice-" + mode + ".png") == OK, "The native choice scene renders to an image")
	game.set_reduced_motion(false)
