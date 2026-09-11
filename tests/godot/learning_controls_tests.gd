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
	var initial_rects: Array = _lesson_rects(lesson)
	lesson.next_button.grab_focus()
	for index in range(1, words.size()):
		lesson.next_button.pressed.emit()
		check(_lesson_rects(lesson) == initial_rects, "Learn keeps its picture and control positions while changing words")
	check(root.gui_get_focus_owner() == lesson.action_button, "Reaching the last Learn word moves actual focus from disabled Next to Play Match")
	lesson.previous_button.grab_focus()
	for index in range(words.size() - 1):
		lesson.previous_button.pressed.emit()
	check(root.gui_get_focus_owner() == lesson.next_button, "Reaching the first Learn word moves actual focus from disabled Previous to Next")
	changed_words.clear()
	lesson.show_words(words, "Meet these words")
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
	check(lesson.has_method("set_compact"), "Word associations support a fixed compact feedback region")
	if lesson.has_method("set_compact"):
		_test_compact(lesson, words)
	lesson.queue_free()
	await process_frame
	print("Learning controls: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _lesson_rects(lesson) -> Array:
	return [lesson._card.get_rect(), lesson.picture.get_rect(), lesson.word_label.get_rect(), lesson.hear_button.get_rect(),
		lesson.previous_button.get_rect(), lesson.next_button.get_rect(), lesson.action_button.get_rect()]


func _test_compact(lesson, words: Array) -> void:
	lesson.set_compact(true)
	lesson.set_audio_available(true)
	for dimensions in [Vector2(160, 176), Vector2(240, 176), Vector2(392, 104), Vector2(456, 104)]:
		lesson.size = dimensions
		lesson.show_words([words[0]], "A clear answer", "Continue")
		lesson._layout()
		var one_word_rects := _lesson_rects(lesson)
		var minimum: Vector2 = lesson.custom_minimum_size
		check(minimum.x <= 160 and minimum.y == dimensions.y, "Compact feedback fits its fixed wide or narrow height")
		check(lesson.size == dimensions, "Compact feedback releases the previous width's taller minimum when changing regions")
		check(not lesson.hear_button.visible and lesson.picture_button.tooltip_text.contains("Hear") and lesson.hear_hint_label.text == "Tap to hear", "The compact association visibly explains its picture Hear action without a duplicate Hear button")
		check(lesson.controls() == [lesson.action_button, lesson.picture_button], "One-word feedback prioritizes Continue and its pronounceable picture")
		for title in ["Try again", "Found it!", "New flower!", "New sticker: helicopter!"]:
			lesson.set_heading(title)
			check(lesson.heading_label.text == title and lesson.heading_label.size.x == lesson.size.x,
				"A one-word feedback heading uses its full width and retains the complete notice")
			_check_heading_fits(lesson)
			check(_lesson_rects(lesson) == one_word_rects, "Updating a feedback heading does not move its picture or controls")
		lesson.show_words(words.slice(0, 2), "Compare", "Continue")
		check(_lesson_rects(lesson) == one_word_rects and lesson.custom_minimum_size == minimum, "One-word and two-word feedback keep identical geometry and minimum size")
		for title in ["Try again", "No picture", "No word", "Compare"]:
			lesson.set_heading(title)
			_check_heading_fits(lesson)
			check(not lesson.heading_label.get_rect().intersects(lesson.progress_label.get_rect()), "A two-word heading leaves the progress counter readable")
		lesson.set_palette(load("res://scripts/game_data.gd").theme("winter"))
		check(_lesson_rects(lesson) == one_word_rects, "Changing the theme preserves compact navigation slots and all control positions")
		var action_font: Font = lesson.action_button.get_theme_font("font")
		var action_font_size: int = lesson.action_button.get_theme_font_size("font_size")
		var action_text_width: float = action_font.get_string_size(lesson.action_button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, action_font_size).x
		var action_content_width: float = lesson.action_button.size.x - lesson.action_button.get_theme_stylebox("normal").get_minimum_size().x
		check(action_text_width <= action_content_width, "The complete Continue label fits inside the actual button padding at %s: %s px text in %s px at font %d" % [dimensions, action_text_width, action_content_width, action_font_size])
		var compact_controls: Array[Control] = lesson.controls()
		for control in compact_controls:
			check(control.size.x >= 44 and control.size.y >= 44 and lesson.get_global_rect().grow(0.1).encloses(control.get_global_rect()), "Every compact action fits its region with at least a 44px touch target")
		for first in range(compact_controls.size()):
			for second in range(first + 1, compact_controls.size()):
				check(not compact_controls[first].get_global_rect().intersects(compact_controls[second].get_global_rect()), "Compact feedback touch targets do not overlap")
		var before_heard := heard.size()
		lesson.picture_button.pressed.emit()
		check(heard.size() == before_heard + 1 and heard.back() == words[0].id, "Compact picture pronunciation uses the visible word")
		lesson.next_button.pressed.emit()
		check(lesson.current_word == words[1] and _lesson_rects(lesson) == one_word_rects, "Compact Next changes the word without moving feedback controls")
		lesson.previous_button.pressed.emit()
		check(lesson.current_word == words[0], "Compact Previous keeps both correction words reviewable")
		lesson.set_audio_available(false)
		check(lesson.picture_button.disabled and lesson.hear_hint_label.text == "No sound" and not lesson.controls().has(lesson.picture_button) and lesson.controls().has(lesson.action_button), "Silent compact feedback retains its written answer and Continue")
		lesson.set_audio_available(true)
		lesson.pause(true)
		var current: Dictionary = lesson.current_word
		lesson.next_button.pressed.emit()
		lesson.picture_button.pressed.emit()
		check(lesson.controls().is_empty() and lesson.current_word == current and heard.size() == before_heard + 1, "Paused compact feedback blocks both navigation and audio")
		lesson.pause(false)
	lesson.set_compact(false)
	lesson.size = Vector2(456, 744)
	lesson.show_words(words, "Full Learn")
	check(lesson.hear_button.visible and lesson.previous_button.text == "Previous" and lesson.next_button.text == "Next", "Leaving compact mode restores the complete Learn controls")
	check(lesson.heading_label.get_theme_font_size("font_size") == 18, "Full Learn restores its original heading size")


func _check_heading_fits(lesson) -> void:
	var font: Font = lesson.heading_label.get_theme_font("font")
	var font_size: int = lesson.heading_label.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(lesson.heading_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	check(text_width <= lesson.heading_label.size.x and font_size >= 12,
		"The complete compact heading fits at %s: %s needs %s px in %s px" % [lesson.size, lesson.heading_label.text, text_width, lesson.heading_label.size.x])
