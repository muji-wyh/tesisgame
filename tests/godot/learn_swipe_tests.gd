extends SceneTree

var checks := 0
var failures := 0
var heard: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(4):
		await process_frame


func pointer(point: Vector2, pressed: bool, touch: bool = false, index: int = 0, canceled: bool = false, device: int = 0) -> void:
	var event: InputEvent
	if touch:
		event = InputEventScreenTouch.new()
		event.index = index
		event.canceled = canceled
	else:
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = point
	event.pressed = pressed
	event.device = device
	root.push_input(event, true)
	await process_frame


func motion(point: Vector2, relative: Vector2, touch: bool = false) -> void:
	var event: InputEvent = InputEventScreenDrag.new() if touch else InputEventMouseMotion.new()
	event.position = point
	event.relative = relative
	if touch:
		event.index = 0
	else:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)
	await process_frame


func drag(center: Vector2, delta: Vector2, touch: bool = false) -> void:
	var start := center - delta * 0.5
	await pointer(start, true, touch)
	for step in range(1, 5):
		await motion(start + delta * step / 4, delta / 4, touch)
	await pointer(start + delta, false, touch)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(480, 800)
	var directory := "user://learn-swipe-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.choose_mode("learn")
	await settle()
	var lesson = app._lesson
	lesson.set_audio_available(true)
	lesson.hear_requested.connect(func(word: Dictionary) -> void: heard.append(word.id))
	var words: Array = app.model.lesson_words.duplicate(true)
	check(lesson.controls() == [lesson.picture_button], "Learn exposes only its picture, not bottom action buttons")
	check(lesson._card.get_rect().end.y >= lesson.size.y - 1, "The display uses the space released by the bottom buttons")
	var center: Vector2 = lesson.picture_button.get_global_rect().get_center()
	var home: Vector2 = lesson.picture_button.position
	lesson.set_reduced_motion(false)
	await pointer(center, true)
	await motion(center - Vector2(80, 0), Vector2(-80, 0))
	check(lesson.picture_button.get_theme_stylebox("focus") is StyleBoxEmpty,
		"A pointer drag does not paint a selected or focused card outline")
	check(lesson.picture_button.tooltip_text.is_empty(),
		"On-card guidance does not become a floating tooltip over a held drag")
	check(is_equal_approx(lesson.picture_button.position.x, home.x - 80),
		"The card follows horizontal dragging before the word changes")
	check(lesson.current_word.id == words[0].id, "A held slide does not commit a word early")
	var preview: Button = lesson.get("_slide_preview")
	check(preview != null and preview.visible and preview.disabled and preview.focus_mode == Control.FOCUS_NONE
		and preview.get_node("Word").text == words[1].text and preview.get("accessibility_name") == words[1].text,
		"The adjacent word has the correct visible and accessible name but is never another input target")
	check(preview.get_node("Progress").text == "2/5"
		and preview.get_rect().encloses(Rect2(preview.position + preview.get_node("Progress").position, preview.get_node("Progress").size)),
		"The sliding preview carries its own counter inside the adjacent card")
	await motion(center - Vector2(24, 0), Vector2(56, 0))
	check(is_equal_approx(lesson.picture_button.position.x, home.x - 24), "Reversing a drag continues to track the pointer")
	await motion(center, Vector2(24, 0))
	check(lesson.picture_button.position.is_equal_approx(home), "Returning the pointer to its start returns the slide too")
	await motion(center - Vector2(80, 0), Vector2(-80, 0))
	await pointer(center - Vector2(80, 0), false)
	check(lesson.current_word.id == words[1].id, "Releasing the dragged slide commits once")
	await create_timer(0.3).timeout
	check(lesson.picture_button.position.is_equal_approx(home), "The new slide settles back into its normal position")
	lesson._move(-1)
	await pointer(center, true)
	await motion(center + Vector2(80, 0), Vector2(80, 0))
	check(lesson.picture_button.position.x > home.x and lesson.picture_button.position.x < home.x + 40,
		"Dragging past the first word gives gentle edge resistance")
	lesson.cancel_swipe()
	check(lesson.picture_button.position.is_equal_approx(home), "Cancel restores the dragged card immediately")
	for touch in [false, true]:
		await drag(center, Vector2(-144, 0), touch)
		check(lesson.current_word.id == words[1].id, "A left swipe advances exactly one word")
		check(lesson.progress_label.text == "2/5", "Swipe navigation updates the visible position")
		await drag(center, Vector2(144, 0), touch)
		check(lesson.current_word.id == words[0].id, "A right swipe returns to the previous word")
		var before := heard.size()
		await drag(center, Vector2(144, 0))
		check(lesson.current_word.id == words[0].id, "The first word does not wrap backward")
		await pointer(center, true, true)
		await pointer(center, true, false, 0, false, InputEvent.DEVICE_ID_EMULATION)
		await pointer(center, false, true)
		await pointer(center, false, false, 0, false, InputEvent.DEVICE_ID_EMULATION)
		check(heard.size() == before + 1, "A touch and its emulated mouse pronounce only once")
		before = heard.size()
		await pointer(Vector2(-20, center.y), true)
		await pointer(center, false)
		await pointer(center, true)
		await pointer(Vector2(-20, center.y), false)
		check(heard.size() == before and lesson.current_word.id == words[0].id,
			"A gesture must start and finish in the display")
		await pointer(center, true, touch)
		await pointer(center, false, touch)
		check(heard.size() == before + 1 and heard.back() == words[0].id, "A tap still pronounces the displayed word once")
		for delta in [Vector2(6, 0), Vector2(0, 100), Vector2(-80, 110)]:
			await drag(center, delta, touch)
			check(lesson.current_word.id == words[0].id, "Short, vertical, or diagonal movement cannot turn a page")
			if delta.length() > 12:
				check(heard.size() == before + 2, "A drag never becomes a pronunciation tap")
	var before := heard.size()
	for step in range(7):
		await drag(center, Vector2(-144, 0))
	check(lesson.current_word.id == words.back().id and lesson.progress_label.text == "5/5",
		"The final word stays available instead of wrapping or starting a game")
	check(heard.size() == before, "Swiping never autoplays a word")
	lesson.set_audio_available(false)
	check(lesson.controls() == [lesson.picture_button] and not lesson.picture_button.disabled,
		"Silent Learn keeps its swipe and keyboard surface usable")
	lesson.picture_button.grab_focus()
	app._move_focus(Vector2.LEFT)
	check(lesson.current_word.id == words[3].id and lesson.picture_button.has_focus(),
		"Controller left changes the word without leaving the display")
	var key := InputEventKey.new()
	key.keycode = KEY_LEFT
	key.pressed = true
	root.push_input(key, true)
	await process_frame
	key.pressed = false
	root.push_input(key, true)
	check(lesson.current_word.id == words[2].id, "The left arrow navigates without bottom buttons")
	check(lesson.picture_button.get_theme_stylebox("focus") is StyleBoxFlat,
		"Keyboard navigation retains its distinct focus outline")
	var current: String = lesson.current_word.id
	await pointer(center, true, true)
	await motion(center - Vector2(100, 0), Vector2(-100, 0), true)
	await pointer(center - Vector2(100, 0), false, true, 0, true)
	check(lesson.current_word.id == current, "Canceled touch cannot switch a word")
	await pointer(center, true, true)
	await pointer(center + Vector2(20, 0), true, true, 1)
	await pointer(center - Vector2(100, 0), false, true)
	await pointer(center + Vector2(20, 0), false, true, 1)
	check(lesson.current_word.id == current, "A multi-touch gesture cannot accidentally turn a page")
	await pointer(center, true)
	app._show_collection()
	await pointer(center - Vector2(144, 0), false)
	app._hide_collection()
	await settle()
	check(lesson.current_word.id == current, "Leaving Learn during a gesture cancels the pending swipe")
	await pointer(center, true)
	app.on_page_hidden()
	app.on_page_visible()
	await pointer(center - Vector2(144, 0), false)
	check(lesson.current_word.id == current, "Page hiding rejects a late pointer release")
	await pointer(center, true)
	root.size = Vector2i(800, 480)
	await settle()
	await pointer(center - Vector2(144, 0), false)
	check(lesson.current_word.id == current, "Resizing cancels a gesture instead of changing the word")
	app.set_reduced_motion(true)
	center = lesson.picture_button.get_global_rect().get_center()
	await drag(center, Vector2(-144, 0), true)
	check(lesson.current_word.id == words[3].id and lesson.picture_button.scale == Vector2.ONE,
		"Reduced motion still turns words without moving or scaling the display")
	check(app.model.successes == 0 and app.model.mistakes == 0 and app.model.hints_remaining == 3
		and app.medal_progress.counts.is_empty() and app.playroom_state.collected_word_ids.is_empty(),
		"Learning gestures never score, spend hints, or award collectibles")
	await pointer(center, true)
	app.choose_mode("match")
	await pointer(center - Vector2(144, 0), false)
	check(app._mode_id == "match" and app.model.selected_id.is_empty()
		and app.model.successes == 0 and app.model.mistakes == 0,
		"Switching modes cancels a pending Learn gesture without selecting or scoring a Match card")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Learn swipes: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
