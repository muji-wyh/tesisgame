extends SceneTree

var checks: int = 0
var failures: int = 0
var heard: Array[String] = []
var changed_words: Array[String] = []


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
	var words: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json")).slice(0, 5)
	var data = load("res://scripts/game_data.gd")
	lesson.set_palette(data.theme("spring"))
	lesson.show_words(words)
	await process_frame
	var initial_rects: Array = _lesson_rects(lesson)
	lesson.picture_button.grab_focus()
	for index in range(1, words.size()):
		lesson._move(1)
		check(_lesson_rects(lesson) == initial_rects, "Learn keeps its picture and control positions while changing words")
	check(root.gui_get_focus_owner() == lesson.picture_button, "Reaching the last Learn word retains display focus")
	for index in range(words.size() - 1):
		lesson._move(-1)
	check(root.gui_get_focus_owner() == lesson.picture_button, "Reaching the first Learn word retains display focus")
	changed_words.clear()
	lesson.show_words(words)
	check(lesson.current_word.id == words[0].id and lesson.word_label.text == words[0].text,
		"The first written word belongs to the presented lesson item")
	check(lesson.picture.texture.resource_path == "res://" + words[0].image and lesson.picture.visible,
		"The visible picture belongs to that same written word")
	check(lesson.progress_label.text == "1/5" and lesson.progress_label.visible,
		"Learners can see their position without a redundant lesson heading")
	check(lesson.picture is TextureRect and lesson.picture_button.get("accessibility_name") == words[0].text,
		"The picture keeps its exact word as its accessible name, without the overlaid counter")
	check(lesson.progress_label.get_parent() == lesson.picture_button and lesson.progress_label.name == "Progress",
		"The counter belongs to the swipeable picture rather than a separate header")
	for state in ["hover", "pressed", "hover_pressed", "disabled"]:
		check(lesson.picture_button.get_theme_stylebox(state) == lesson.picture_button.get_theme_stylebox("normal"),
			"The Learn picture has no selection or hover glow in its " + state + " state")
	check(heard.is_empty() and changed_words == [words[0].id], "Showing a word announces its identity without autoplaying audio")
	check(lesson.controls() == [lesson.picture_button], "The display is Learn's only action surface")
	lesson.picture_button.pressed.emit()
	check(heard == [words[0].id], "Hear requests exactly the audio dictionary of the visible picture and text")
	lesson._move(-1)
	check(lesson.current_word.id == words[0].id and changed_words == [words[0].id],
		"Moving before the first word neither wraps nor emits another word change")
	for index in range(1, words.size()):
		lesson._move(1)
		check(lesson.current_word.id == words[index].id and lesson.word_label.text == words[index].text
			and lesson.picture.texture.resource_path == "res://" + words[index].image
			and lesson.picture_button.get("accessibility_name") == words[index].text,
			"Next keeps picture, written word and heard word aligned")
	lesson._move(1)
	check(lesson.current_word.id == words.back().id and changed_words.size() == words.size()
		and lesson.progress_label.text == "5/5", "The last word remains available for unhurried review")
	check(heard.size() == 1, "Browsing words does not unexpectedly play a new voice clip")
	lesson._move(-1)
	lesson.picture_button.pressed.emit()
	check(heard.back() == words[3].id, "Previous restores that word's pronunciation")
	lesson.set_audio_available(false)
	check(not lesson.picture_button.disabled and lesson.controls() == [lesson.picture_button]
		and lesson.word_label.visible and lesson.picture.visible,
		"Unavailable audio keeps the picture navigable without pretending pronunciation is available")
	lesson.picture_button.pressed.emit()
	check(heard.size() == 2, "An unavailable audio control cannot emit a misleading playback request")
	check(lesson.hear_hint_label.text.contains("No sound") and _lesson_rects(lesson) == initial_rects,
		"Silent Learn explains unavailable sound without moving its picture, word, counter, or cue")
	lesson.set_audio_available(true)
	lesson.pause(true)
	lesson._move(1)
	lesson.picture_button.pressed.emit()
	check(lesson.current_word.id == words[3].id and lesson.controls().is_empty()
		and lesson.picture_button.disabled and heard.size() == 2, "Modal suspension blocks all lesson interaction")
	lesson.pause(false)
	check(lesson.controls() == [lesson.picture_button] and _lesson_rects(lesson) == initial_rects,
		"Resuming restores the same action surface and stable layout")
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
		check(lesson._card.get_global_rect().encloses(lesson.hear_hint_label.get_global_rect()),
			"The swipe and pronunciation cue stays inside the display")
		var css_scale: float = lesson.Style.ui_scale(lesson)
		check(lesson._card.get_global_rect().encloses(lesson.progress_label.get_global_rect())
			and is_equal_approx(lesson.progress_label.position.y * css_scale, 12)
			and is_equal_approx((lesson._card.size.x - lesson.progress_label.get_rect().end.x) * css_scale, 12),
			"The progress counter stays inside the card with 12 CSS-pixel top and right insets")
		check(lesson._card.get_rect().is_equal_approx(Rect2(Vector2.ZERO, lesson.size)),
			"Learn gives the complete view to its card without a reserved counter row")
		var before_palette: Array = _lesson_rects(lesson)
		lesson.set_palette(data.theme("winter"))
		check(_lesson_rects(lesson) == before_palette and lesson._card.position == lesson._card_home,
			"Changing the world preserves the card's home geometry")
		var font: Font = lesson.word_label.get_theme_font("font")
		var font_size: int = lesson.word_label.get_theme_font_size("font_size")
		check(font.get_string_size(lesson.word_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= lesson.word_label.size.x,
			"The complete displayed word fits without truncation")
		if dimensions == Vector2(456, 744):
			check(lesson._card.size.x >= 400 and lesson._card.get_rect().end.y == lesson.size.y,
				"A tall logical phone viewport gives the display the released button space")
			check(lesson.controls() == [lesson.picture_button],
				"Portrait Learn has no second action surface or bottom row")
		if lesson._card.size.x < lesson._card.size.y * 1.3:
			check(is_equal_approx(lesson.picture.size.x, lesson.picture.size.y)
				and lesson.word_label.position.y - lesson.picture.get_rect().end.y <= 12,
				"The picture and word stay together instead of spanning an empty card")
	lesson.set_reduced_motion(true)
	var before: Dictionary = lesson.current_word.duplicate()
	await create_timer(0.2).timeout
	check(lesson.current_word == before, "Time and reduced-motion settings never advance the lesson")
	lesson.show_words([words[0]])
	check(lesson.current_word == words[0] and not lesson.progress_label.visible
		and lesson.controls() == [lesson.picture_button],
		"A one-word lesson keeps its pronounceable picture without a redundant counter")
	lesson._move(1)
	lesson._move(-1)
	check(lesson.current_word == words[0], "A one-word lesson remains stable in both directions")
	lesson.hide()
	lesson.picture_button.pressed.emit()
	lesson._move(1)
	check(lesson.controls().is_empty() and lesson.current_word == words[0] and heard.size() == 2,
		"A hidden lesson cannot play sound or change words")
	lesson.show_words([words[0], words[0], {"id": "incomplete"}, null, words[1]])
	check(lesson.progress_label.text == "1/2" and lesson.current_word == words[0],
		"Malformed and duplicate entries cannot create stale or repeated lesson cards")
	lesson._move(1)
	check(lesson.current_word == words[1] and lesson.progress_label.text == "2/2",
		"Filtering preserves the order of usable associations")
	lesson.show_words([])
	lesson.picture_button.pressed.emit()
	lesson._move(1)
	check(lesson.current_word.is_empty() and not lesson.picture.visible and not lesson.word_label.visible
		and lesson.picture.texture == null and lesson.controls().is_empty() and lesson.picture_button.disabled,
		"An empty lesson never displays or plays stale word data")
	check(lesson.progress_label.text.is_empty() and not lesson.progress_label.visible and heard.size() == 2,
		"Empty lessons clear progress and block pronunciation")
	lesson.show_words(words)
	check(lesson.current_word == words[0] and lesson.controls() == [lesson.picture_button],
		"A valid lesson recovers from empty input with its first word and active display")
	for pair in [["earth", "planet"], ["acorn", "seed"], ["boot", "shoe"], ["shell", "clam"], ["flower", "rose"], ["comet", "meteor"]]:
		check(data.confusable_words(pair[0], pair[1]) and data.confusable_words(pair[1], pair[0]),
			"Overlapping names cannot become contradictory answer alternatives")
	check(not data.confusable_words("cat", "dog") and not data.confusable_words("rocket", "earth"),
		"Visually distinct vocabulary remains available as useful alternatives")
	lesson.queue_free()
	await process_frame
	print("Learning controls: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _lesson_rects(lesson) -> Array:
	return [lesson._card.get_rect(), lesson.picture.get_rect(), lesson.word_label.get_rect(),
		lesson.progress_label.get_rect(), lesson.hear_hint_label.get_rect()]
