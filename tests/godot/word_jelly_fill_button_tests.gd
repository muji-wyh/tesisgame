extends SceneTree

const FillButton = preload("res://scripts/word_jelly_fill_button.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var button := FillButton.new()
	root.add_child(button)
	button.position = Vector2(30, 30)
	button.size = Vector2(88, 44)
	await process_frame
	var toggles: Array[bool] = []
	button.toggled.connect(func(value: bool) -> void:
		toggles.append(value)
		button.set_state(value, false))
	check(button.text.is_empty() and button.tooltip_text.is_empty() and button.get_children().is_empty(),
		"The control has no visible text, tooltip or hidden label implementation")
	button.set_state(true, false)
	button.advance(0.2)
	var on: Dictionary = button.snapshot()
	check(on.on and on.glow and on.flowing and button.button_pressed, "On immediately owns a persistent active presentation")
	var before: float = on.elapsed
	for frame in range(140):
		button.advance(0.1)
	check(button.snapshot().elapsed > before + 13.9 and button.snapshot().flowing,
		"The running effect lasts beyond ten cycles instead of ending like purchase feedback")
	check(toggles.is_empty(), "Persistent feedback never issues a toggle or gameplay action")
	button.pause_feedback(true)
	before = button.snapshot().elapsed
	button.advance(3.0)
	check(button.snapshot().elapsed == before and button.snapshot().glow and not button.snapshot().flowing,
		"Pause freezes motion while retaining the clearly enabled style")
	button.pause_feedback(false)
	button.advance(0.1)
	check(button.snapshot().elapsed > before, "Resume continues the owned local clock")
	button.set_reduced_motion(true)
	before = button.snapshot().elapsed
	button.advance(3.0)
	check(button.snapshot().elapsed == before and button.snapshot().glow and not button.snapshot().flowing,
		"Reduced motion communicates On without moving particles or arrows")
	button.set_state(true, true, false)
	button.disabled = true
	check(button.snapshot().thumb_x == on.thumb_x, "A forced-on lock cannot freeze its thumb in the Off position")
	button.advance(0.2)
	check(button.snapshot().on and button.snapshot().locked and button.snapshot().flowing,
		"Challenge's disabled input is not mistaken for an inactive mode")
	check(str(button.get("accessibility_name")).contains("Required in Challenge"),
		"The icon-only locked state retains its full accessible meaning")
	button.disabled = false
	button.set_state(false, false)
	button.advance(0.2)
	check(not button.snapshot().on and not button.snapshot().glow and not button.snapshot().flowing
		and button.snapshot().thumb_x < on.thumb_x,
		"Off removes the running light and returns the status thumb to the other side")
	before = button.snapshot().elapsed
	button.advance(3.0)
	check(button.snapshot().elapsed == before, "Off does not secretly keep a running effect clock")
	button.set_state(true, false)
	button.hide()
	button.advance(3.0)
	check(button.snapshot().elapsed == before, "A hidden control cannot accumulate unseen feedback")
	button.show()
	for invalid: float in [0.0, -1.0, NAN, INF]:
		button.advance(invalid)
	check(button.snapshot().elapsed == before, "Invalid deltas cannot alter presentation")
	for scale_value: float in [0.65, 1.0, 1.5, 1175.0 / 480.0, 3.2]:
		button.set_ui_scale(scale_value)
		for width: float in [88.0, 120.0, 184.0]:
			button.size = Vector2(width, 44.0) / scale_value
			var state: Dictionary = button.snapshot()
			for key: String in ["icon_rect", "track_rect"]:
				var rect: Array = state[key]
				check(Rect2(Vector2.ZERO, button.size).encloses(Rect2(rect[0], rect[1], rect[2], rect[3])),
					"Artwork and status stay inside every small and highly scaled target")
			check(button.custom_minimum_size.x * scale_value >= 87.9 and button.custom_minimum_size.y * scale_value >= 43.9,
				"Removing text never shrinks the 88 by 44 display-pixel touch target")
	button.set_ui_scale(1.0)
	button.size = Vector2(88, 44)
	button.set_state(false, false)
	button.grab_focus()
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_SPACE
		event.physical_keycode = KEY_SPACE
		event.pressed = pressed
		root.push_input(event)
		await process_frame
	check(toggles == [true] and button.snapshot().on,
		"Native keyboard activation still dispatches exactly one owner-confirmed toggle")
	button.reset()
	check(button.snapshot().on and button.snapshot().elapsed == 0.0,
		"Presentation reset cannot switch off the model's selected mode")
	button.queue_free()
	await process_frame
	print("Icon-only Fill button: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
