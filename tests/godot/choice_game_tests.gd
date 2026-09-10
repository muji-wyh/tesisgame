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
			var count: int = heard.size()
			game.hear_button.pressed.emit()
			check(heard.size() == count + 1 and heard.back() == first.id, "Hear requests the current target without changing scores")
			check(game.successes == 0 and game.mistakes == 0, "Pronunciation has no scoring side effects")
		var before_answers: int = answers.size()
		var before_prompts: int = ready_prompts
		var wrong: int = _answer_index(game, false)
		game.answer_buttons[wrong].pressed.emit()
		for tap in range(6):
			game.answer_buttons[wrong].pressed.emit()
		check(game.status == "feedback" and game.mistakes == 1 and game.successes == 0,
			"A wrong answer locks repeated attempts during feedback")
		check(answers.size() == before_answers + 1 and not answers.back()[1], "One attempt emits exactly one incorrect answer")
		check(game.controls().size() == 2 and game.feedback_view.visible
			and game.feedback_view.current_word.id == first.id
			and game.feedback_view.word_label.text == first.text
			and game.feedback_view.picture.texture.resource_path == "res://" + first.image,
			"Wrong feedback teaches the correct picture and written word with Hear and Continue")
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
			game.answer_buttons[right].pressed.emit()
			game.answer_buttons[right].pressed.emit()
			check(game.successes == index + 1 and game.mistakes == 1, "A repeated correct tap awards one success")
			check(game.feedback_view.current_word == game.current_target and game.feedback_view.word_label.visible
				and game.feedback_view.picture.visible, "A successful answer reinforces that exact picture-word association")
			game.feedback_view.action_button.pressed.emit()
		check(game.status == "won" and endings.size() == before_endings + 1 and endings.back()[0],
			"Five correct answers finish with exactly one win")
		check(game.found_words.size() == 5 and endings.back()[1].size() == 5 and progress.back() == [5, 1],
			"Winning reports the five earned words and final progress")
		game.continue_feedback()
		game.answer_buttons[0].pressed.emit()
		check(endings.size() == before_endings + 1 and game.successes == 5, "Completed rounds ignore delayed callbacks and taps")
		game.start_round(words, mode, palette, 17)
		game.answer_buttons[_answer_index(game, true)].pressed.emit()
		game.continue_feedback()
		for attempt in range(3):
			game.answer_buttons[_answer_index(game, false)].pressed.emit()
			game.continue_feedback()
		check(game.status == "lost" and game.mistakes == 3 and game.successes == 1 and not endings.back()[0],
			"Three mistakes end the round after retaining earlier success")
		check(game.found_words.size() == 1 and endings.back()[1].size() == 1,
			"A loss reports only the successfully learned word")
		game.start_round(words, mode, palette, 17)
		game.set_reduced_motion(true)
		for dimensions in [Vector2(456, 200), Vector2(960, 360), Vector2(240, 200)]:
			game.size = dimensions
			await process_frame
			await process_frame
			for control in game.controls():
				check(control.size.x >= 72 and control.size.y >= 72, "Choice controls retain 72px minimum touch targets")
				check(game.get_global_rect().grow(0.1).encloses(control.get_global_rect()), "Choice controls fit their assigned play area")
			check(not game.answer_buttons[0].get_global_rect().intersects(game.answer_buttons[1].get_global_rect()),
				"Answer touch targets remain separate")
		check(game.status == "asking" and game.successes == 0, "Reduced motion and resizing leave the question unchanged")
		game.set_reduced_motion(false)
		game.start_round(words, mode, palette, 42)
		game.answer_buttons[_answer_index(game, true)].pressed.emit()
		before_endings = endings.size()
		game.stop()
		game.continue_feedback()
		game.answer_buttons[0].pressed.emit()
		game.hear_button.pressed.emit()
		check(game.status == "stopped" and game.controls().is_empty() and endings.size() == before_endings,
			"Stopping cancels pending feedback and input without delivering a result")
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
	check(game.feedback_view.word_label.text == fallback_target.text and game.controls().size() == 1,
		"A playback failure during correction keeps the right answer visible and Continue usable")
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
