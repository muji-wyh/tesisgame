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
	if not app.get("_mode_id") == "learn":
		check(false, "New players start with a visible picture-word lesson")
		app.free()
		quit(1)
		return
	var directory := "user://lesson-scene-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/playroom.cfg"
	root.add_child(app)
	await process_frame
	await process_frame
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	check(app._lesson.is_visible_in_tree() and app.model.lesson_words.size() == 5, "Learn exposes exactly five concrete associations")
	var lesson: Array = app.model.lesson_words.duplicate(true)
	var world: String = app.model.theme_id
	for mode in ["match", "sky", "listen", "learn", "match"]:
		app.choose_mode(mode)
		check(app.model.lesson_words == lesson and app.model.theme_id == world, "Mode " + mode + " retains the exact lesson and world")
		check(app.model.successes == 0 and app.model.mistakes == 0, "Mode change resets only the attempt")
		if mode in ["sky", "listen"]:
			check(lesson.has(app._choice.current_target), "Choice questions use the learned words")
	check(app._message.is_visible_in_tree() and app._message.text.contains("no match"), "The two unmatched cards are explained visibly")
	var wrong: Array = []
	for card in app.model.cards:
		if wrong.is_empty() or (card.kind != wrong[0].kind and card.word.id != wrong[0].word.id):
			wrong.append(card)
		if wrong.size() == 2:
			break
	app.cards[wrong[0].id].pressed.emit()
	app.cards[wrong[1].id].pressed.emit()
	check(app._match_feedback.is_visible_in_tree() and app.model.phase == "feedback", "Wrong Match reveals a persistent correct association")
	check(app.feedback_timer.is_stopped(), "Tap feedback waits for Continue")
	check(app.model.missed_word_ids.has(wrong[0].word.id) and app.model.missed_word_ids.has(wrong[1].word.id), "Both mixed-up words enter review")
	app._show_collection()
	app._match_feedback.finished.emit()
	check(app.model.phase == "feedback", "Covered Continue cannot advance the challenge")
	app._hide_collection()
	app._match_feedback.finished.emit()
	check(app.model.phase == "waiting", "Continue resumes the same challenge")
	app.model.phase = "lost"
	app._refresh()
	check(app._found_words.get_child_count() == 5, "Review includes all five lesson words")
	check(app._found_words.get_child(0).get_meta("word_id") == wrong[0].word.id, "Review presents missed words first")
	app._replay()
	check(app.model.lesson_words == lesson, "Repeat lesson intentionally retains the words")
	app.choose_mode("learn")
	app._lesson.next_button.pressed.emit()
	check(app.model.successes == 0 and app.medal_progress.counts.is_empty(), "Browsing Learn never scores or awards pieces")
	app.choose_mode("listen")
	check(app._status_announcement.contains("No sound. Choose the picture for " + str(app._choice.current_target.text)), "Silent Listen starts with an accessible written target instead of an unavailable Hear instruction")
	app.audio.available = false
	app._choice_hear(app._choice.current_target)
	check(app._choice.target_word_label.text.contains(app._choice.current_target.text), "Unavailable audio exposes the target word")
	app._choice._choose(0)
	app._choice_hear(app._choice.current_target)
	check(app._status_announcement == str(app._choice.current_target.text) + ". Look at the picture and say the word.", "Feedback Hear reinforces the visible association")
	app._choice.continue_feedback()
	check(app._status_announcement.contains("No sound. Choose the picture.") and app._status_announcement.contains(app._choice.current_target.text), "Continue announces the resumed silent question and its written target")
	app.choose_mode("learn")
	for index in range(4):
		app._lesson.next_button.pressed.emit()
	check(app._valid_focus(app._default_focus()), "The last silent lesson word keeps an enabled keyboard/controller target")
	app.audio.available = true
	app.audio.set_muted(false)
	app._audio_status("")
	check(not app._lesson.hear_button.disabled and app._choice.audio_available, "Audio recovery restores Hear across learning views")
	app.audio.status_changed.emit("Sound could not load. You can keep playing. Tap a card to try again.")
	check(not app._lesson.hear_button.disabled and app._choice.audio_available, "Optional music failure does not disable bundled word pronunciation")
	app.choose_mode("listen")
	var missing_word: Dictionary = app._choice.current_target.duplicate()
	missing_word.audio = "assets/audio/voice/word-missing-test.wav"
	app._choice_hear(missing_word)
	check(not app._choice.audio_available and app._choice.target_word_label.text.contains(missing_word.text), "Actual word playback failure exposes the written Listen target")
	check(app._status_announcement == "No sound. Choose the picture. " + str(missing_word.text) + ".", "Failed pronunciation announces the fallback instead of another Hear instruction")
	app.audio.status_changed.emit("")
	check(not app._choice.audio_available, "A later optional music success cannot erase an actual word failure")
	app._choice_hear(app._choice.current_target)
	check(app._choice.audio_available, "Retrying a bundled word restores the listening question")
	app.audio.set_muted(true)
	app._audio_status("")
	check(app._lesson.hear_button.disabled and not app._choice.audio_available, "Muted audio consistently exposes the silent learning fallback")
	app.new_round()
	check(app.model.lesson_words != lesson, "New adventure selects fresh words")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Lesson scene: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
