extends SceneTree

var checks: int = 0
var failures: int = 0
var heard: Array[String] = []
var changed_words: Array[String] = []
var completions: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	check(FileAccess.file_exists("res://scripts/word_lesson.gd"), "A reusable native word association view exists")
	if failures:
		quit(1)
		return
	var lesson = load("res://scripts/word_lesson.gd").new()
	root.add_child(lesson)
	lesson.size = Vector2(456, 240)
	lesson.hear_requested.connect(func(word: Dictionary): heard.append(word.id))
	lesson.word_changed.connect(func(word: Dictionary): changed_words.append(word.id))
	lesson.finished.connect(func(): completions += 1)
	var words: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json")).slice(0, 5)
	var data = load("res://scripts/game_data.gd")
	lesson.set_palette(data.theme("spring"))
	lesson.show_words(words, "Meet these words")
	await process_frame
	check(lesson.current_word.id == words[0].id and lesson.word_label.text == words[0].text,
		"The first written word belongs to the presented lesson item")
	check(lesson.picture.texture.resource_path == "res://" + words[0].image and lesson.picture.visible,
		"The visible picture belongs to that same written word")
	check(lesson.progress_label.text == "1 of 5" and lesson.heading_label.text == "Meet these words",
		"Learners can see their position and lesson purpose")
	check(heard.is_empty() and changed_words == [words[0].id], "Showing a word announces its identity without autoplaying audio")
	lesson.hear_button.pressed.emit()
	check(heard == [words[0].id], "Hear requests exactly the audio dictionary of the visible picture and text")
	lesson.previous_button.pressed.emit()
	check(lesson.current_word.id == words[0].id and lesson.previous_button.disabled,
		"Previous cannot move before the first word")
	for index in range(1, words.size()):
		lesson.next_button.pressed.emit()
		check(lesson.current_word.id == words[index].id and lesson.word_label.text == words[index].text
			and lesson.picture.texture.resource_path == "res://" + words[index].image,
			"Next keeps picture, written word and heard word aligned")
	lesson.next_button.pressed.emit()
	check(lesson.current_word.id == words.back().id and lesson.next_button.disabled
		and lesson.progress_label.text == "5 of 5", "The last word remains available for unhurried review")
	check(heard.size() == 1, "Browsing words does not unexpectedly play a new voice clip")
	lesson.previous_button.pressed.emit()
	lesson.hear_button.pressed.emit()
	check(heard.back() == words[3].id, "Previous restores that word's pronunciation")
	lesson.set_audio_available(false)
	check(lesson.hear_button.disabled and not lesson.controls().has(lesson.hear_button)
		and lesson.word_label.visible and lesson.picture.visible,
		"Unavailable audio leaves an explicit picture and written association with no dead Hear control")
	lesson.hear_button.pressed.emit()
	check(heard.size() == 2, "An unavailable audio control cannot emit a misleading playback request")
	lesson.set_audio_available(true)
	lesson.pause(true)
	lesson.next_button.pressed.emit()
	lesson.hear_button.pressed.emit()
	lesson.action_button.pressed.emit()
	check(lesson.current_word.id == words[3].id and lesson.controls().is_empty()
		and heard.size() == 2 and completions == 0, "Modal suspension blocks all lesson interaction")
	lesson.pause(false)
	for dimensions in [Vector2(240, 390), Vector2(456, 240), Vector2(960, 240), Vector2(456, 744), Vector2(960, 620)]:
		lesson.size = dimensions
		await process_frame
		await process_frame
		var controls: Array[Control] = lesson.controls()
		for control in controls:
			check(control.size.x >= 72 and control.size.y >= 72, "Lesson controls keep usable touch targets")
			check(lesson.get_global_rect().grow(0.1).encloses(control.get_global_rect()),
				"Lesson %s fits %s: %s" % [control.text, lesson.size, control.get_rect()])
		for first in range(controls.size()):
			for second in range(first + 1, controls.size()):
				check(not controls[first].get_global_rect().intersects(controls[second].get_global_rect()),
					"Lesson touch targets do not overlap")
		check(lesson.picture.size.x >= 72 and lesson.picture.size.y >= 72,
			"The association picture remains large enough to inspect")
		if dimensions == Vector2(456, 744):
			check(lesson._card.size.x >= 400 and lesson._card.size.y <= 420,
				"A tall logical phone viewport uses one broad, bounded association card")
			check(lesson.hear_button.position.y >= lesson._card.get_rect().end.y,
				"Portrait lesson actions sit below the picture-word association")
		if lesson._card.size.y >= 150:
			check(is_equal_approx(lesson.picture.size.x, lesson.picture.size.y)
				and lesson.word_label.position.y - lesson.picture.get_rect().end.y <= 12,
				"The picture and word stay together instead of spanning an empty card")
	lesson.set_reduced_motion(true)
	var before: Dictionary = lesson.current_word.duplicate()
	await create_timer(0.2).timeout
	check(lesson.current_word == before and completions == 0, "Time and reduced-motion settings never advance the lesson")
	lesson.action_button.pressed.emit()
	lesson.action_button.pressed.emit()
	check(completions == 1, "A double activation starts the chosen action only once")
	lesson.show_words([words[0]], "This is the cat", "Continue")
	check(not lesson.previous_button.visible and not lesson.next_button.visible
		and lesson.action_button.text == "Continue" and lesson.controls().size() == 3
		and lesson.controls().has(lesson.picture_button),
		"A one-word correction offers its pronounceable picture, Hear and Continue")
	for dimensions in [Vector2(240, 200), Vector2(456, 200), Vector2(960, 240)]:
		lesson.size = dimensions
		await process_frame
		await process_frame
		check(lesson._card.get_global_rect().grow(0.1).encloses(lesson.word_label.get_global_rect()),
			"The full written word fits inside its correction card at " + str(dimensions))
		for control in lesson.controls():
			check(lesson.get_global_rect().grow(0.1).encloses(control.get_global_rect()),
				"Correction actions remain visible at " + str(dimensions))
	lesson.hide()
	lesson.hear_button.pressed.emit()
	lesson.action_button.pressed.emit()
	check(lesson.controls().is_empty() and completions == 1 and heard.size() == 2,
		"Hidden feedback cannot play sound or continue an old attempt")
	lesson.show_words([], "Review")
	check(lesson.current_word.is_empty() and not lesson.picture.visible and lesson.controls().is_empty(),
		"An empty review never displays or plays stale word data")
	for pair in [["earth", "planet"], ["acorn", "seed"], ["boot", "shoe"], ["shell", "clam"], ["flower", "rose"], ["comet", "meteor"]]:
		check(data.confusable_words(pair[0], pair[1]) and data.confusable_words(pair[1], pair[0]),
			"Overlapping names cannot become contradictory answer alternatives")
	check(not data.confusable_words("cat", "dog") and not data.confusable_words("rocket", "earth"),
		"Visually distinct vocabulary remains available as useful alternatives")
	lesson.queue_free()
	await process_frame
	print("Learning controls: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
