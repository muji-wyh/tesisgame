extends SceneTree

const ResultScroll = preload("res://scripts/result_scroll.gd")
const ReviewScroll = preload("res://scripts/review_scroll.gd")

var checks := 0
var failures := 0
var activations := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(6):
		await process_frame


func _offset(scroll, horizontal: bool) -> int:
	return scroll.scroll_horizontal if horizontal else scroll.scroll_vertical


func _set_offset(scroll, horizontal: bool, value: int) -> void:
	if horizontal:
		scroll.scroll_horizontal = value
	else:
		scroll.scroll_vertical = value


func _maximum(scroll, horizontal: bool) -> int:
	var bar: ScrollBar = scroll.get_h_scroll_bar() if horizontal else scroll.get_v_scroll_bar()
	return maxi(0, roundi(bar.max_value - bar.page))


func _axis(horizontal: bool, distance: float) -> Vector2:
	return Vector2(distance, 0) if horizontal else Vector2(0, distance)


func _point(scroll, horizontal: bool) -> Vector2:
	var local := Vector2(240, 60) if horizontal else Vector2(160, 240)
	return scroll.get_global_transform_with_canvas() * local


func _visible_choice_point(scroll) -> Vector2:
	for button: Button in scroll.get_child(0).get_children():
		var visible: Rect2 = button.get_global_rect().intersection(scroll.get_global_rect())
		if visible.size.x > 40 and visible.size.y > 40:
			return visible.get_center()
	check(false, "A stopped-list tap fixture has a visible choice")
	return scroll.get_global_rect().get_center()


func _send(scroll, event: InputEvent) -> void:
	root.push_input(event, true)
	# Only gesture timestamps use wall time. Integrate momentum at a fixed rate
	# below so a fast headless runner cannot alter the deceleration assertions.
	scroll.set_process(false)


func _pointer(scroll, point: Vector2, down: bool, touch: bool, canceled: bool = false, index: int = 0, native: bool = false) -> void:
	var event: InputEvent
	if touch:
		event = InputEventScreenTouch.new()
		event.index = index
	else:
		event = InputEventMouseButton.new()
		event.device = 0 if native else InputEvent.DEVICE_ID_EMULATION
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.position = point
	event.pressed = down
	event.canceled = canceled
	_send(scroll, event)


func _motion(scroll, point: Vector2, touch: bool, native: bool = false) -> void:
	var event: InputEvent
	if touch:
		event = InputEventScreenDrag.new()
		event.index = 0
	else:
		event = InputEventMouseMotion.new()
		event.device = 0 if native else InputEvent.DEVICE_ID_EMULATION
		event.global_position = point
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = point
	# Positions, not mismatched physical-pixel deltas, own the gesture.
	event.relative = Vector2(-300, -300)
	_send(scroll, event)


func _advance(scroll, frames: int) -> void:
	for frame in range(frames):
		scroll._process(1.0 / 60.0)
		scroll.set_process(false)


func _reset(scroll, horizontal: bool, value: int = 120) -> void:
	scroll.cancel_drag()
	root.gui_release_focus()
	_set_offset(scroll, horizontal, value)
	await settle()


func _fling(scroll, horizontal: bool, touch_first: bool = true, paired: bool = true, direction: float = 1.0, release: bool = true, native: bool = false) -> Vector2:
	var origin := _point(scroll, horizontal)
	_pointer(scroll, origin, true, touch_first, false, 0, native)
	if paired:
		_pointer(scroll, origin, true, not touch_first)
	var point := origin
	for step in range(1, 5):
		await create_timer(0.020).timeout
		point = origin - _axis(horizontal, direction * step * 20 * scroll.scale.x)
		_motion(scroll, point, touch_first, native)
		if paired:
			_motion(scroll, point, not touch_first)
	if release:
		_pointer(scroll, point, false, touch_first, false, 0, native)
		if paired:
			_pointer(scroll, point, false, not touch_first)
	return point


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(640, 800)
	for horizontal in [false, true]:
		var scroll = ReviewScroll.new() if horizontal else ResultScroll.new()
		scroll.position = Vector2(20, 20)
		scroll.size = Vector2(350, 120) if horizontal else Vector2(350, 350)
		root.add_child(scroll)
		var body: BoxContainer = HBoxContainer.new() if horizontal else VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.add_child(body)
		for index in range(32):
			var button := Button.new()
			button.text = "Choice %d" % index
			button.custom_minimum_size = Vector2(90, 90)
			button.mouse_filter = Control.MOUSE_FILTER_PASS
			button.pressed.connect(func() -> void: activations += 1)
			body.add_child(button)
		await settle()
		scroll.set_process(false)
		check(_maximum(scroll, horizontal) > 1800, "The momentum fixture has enough overflow on both axes")
		for scale_factor in [0.75, 1.0, 1.5]:
			scroll.scale = Vector2.ONE * scale_factor
			await settle()
			for touch_first in [false, true]:
				await _check_paired_drag(scroll, horizontal, touch_first, scale_factor)
		scroll.scale = Vector2.ONE
		await settle()
		await _check_stop_and_tap(scroll, horizontal)
		await _check_cancellations(scroll, horizontal)
		await _check_boundaries(scroll, horizontal)
		await _check_wheel_and_pan(scroll, horizontal)
		await _check_stale_velocity(scroll, horizontal)
		await _check_native_mouse(scroll, horizontal)
		await _check_native_line_edit(scroll, horizontal)
		scroll.queue_free()
		await process_frame
	print("Scroll momentum: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_paired_drag(scroll, horizontal: bool, touch_first: bool, scale_factor: float) -> void:
	await _reset(scroll, horizontal)
	var label := "horizontal=%s touch-first=%s scale=%.2f" % [horizontal, touch_first, scale_factor]
	var before := activations
	var point: Vector2 = await _fling(scroll, horizontal, touch_first, true, 1.0, false)
	check(_offset(scroll, horizontal) == 200 and scroll.is_pointer_active(),
		"Paired touch/emulated input follows the finger once in local coordinates: " + label)
	_pointer(scroll, point, false, touch_first)
	_pointer(scroll, point, false, not touch_first)
	check(not scroll.is_pointer_active() and scroll.is_scrolling(),
		"Release ends contact and starts momentum: " + label)
	var released := _offset(scroll, horizontal)
	_advance(scroll, 6)
	var early := _offset(scroll, horizontal) - released
	var middle := _offset(scroll, horizontal)
	_advance(scroll, 6)
	var late := _offset(scroll, horizontal) - middle
	check(early > 0 and late >= 0 and early > late,
		"Momentum continues in the same direction and slows over equal intervals: " + label)
	_advance(scroll, 240)
	var stopped := _offset(scroll, horizontal)
	_advance(scroll, 30)
	check(not scroll.is_scrolling() and _offset(scroll, horizontal) == stopped,
		"Momentum settles completely without another native inertial stream: " + label)
	check(activations == before, "Dragging and coasting never activate a crossed choice: " + label)


func _check_stop_and_tap(scroll, horizontal: bool) -> void:
	await _reset(scroll, horizontal)
	await _fling(scroll, horizontal)
	_advance(scroll, 4)
	await settle()
	var before := activations
	var stopped := _offset(scroll, horizontal)
	var point := _visible_choice_point(scroll)
	_pointer(scroll, point, true, true)
	_pointer(scroll, point, true, false)
	_advance(scroll, 12)
	check(_offset(scroll, horizontal) == stopped, "A new finger immediately arrests an active fling")
	_pointer(scroll, point, false, true)
	_pointer(scroll, point, false, false)
	_advance(scroll, 12)
	check(not scroll.is_scrolling() and activations == before and _offset(scroll, horizontal) == stopped,
		"The contact used to stop a fling cannot also activate the choice beneath it")
	await settle()
	_pointer(scroll, point, true, true)
	_pointer(scroll, point, true, false)
	_pointer(scroll, point, false, true)
	_pointer(scroll, point, false, false)
	check(activations == before + 1 and not scroll.is_scrolling(),
		"A separate stationary tap after stopping still activates exactly once")


func _check_cancellations(scroll, horizontal: bool) -> void:
	for cause in ["explicit", "hidden", "resize", "background", "blocked", "keyboard"]:
		await _reset(scroll, horizontal)
		await _fling(scroll, horizontal)
		check(scroll.is_scrolling(), "The cancellation fixture starts with live momentum: " + cause)
		match cause:
			"explicit": scroll.cancel_drag()
			"hidden":
				scroll.hide()
				scroll.show()
			"resize": scroll.resized.emit()
			"background": scroll.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			"blocked":
				scroll.interaction_allowed = func() -> bool: return false
				_advance(scroll, 1)
			"keyboard":
				var key := InputEventKey.new()
				key.keycode = KEY_RIGHT if horizontal else KEY_DOWN
				key.pressed = true
				_send(scroll, key)
				key.pressed = false
				_send(scroll, key)
		await settle()
		var offset := _offset(scroll, horizontal)
		_advance(scroll, 60)
		check(not scroll.is_scrolling() and _offset(scroll, horizontal) == offset,
			"Momentum cannot resume after %s: horizontal=%s before=%d after=%d scrolling=%s pointer=%s coasting=%s" % [
				cause, horizontal, offset, _offset(scroll, horizontal), scroll.is_scrolling(),
				scroll.is_pointer_active(), scroll.is_coasting()])
		scroll.interaction_allowed = Callable()
	for cause in ["canceled", "multiple"]:
		await _reset(scroll, horizontal)
		var before := activations
		var point: Vector2 = await _fling(scroll, horizontal, true, true, 1.0, false)
		if cause == "multiple":
			_pointer(scroll, point + Vector2(10, 10), true, true, false, 1)
			_pointer(scroll, point + Vector2(10, 10), false, true, false, 1)
		_pointer(scroll, point, false, true, cause == "canceled")
		_pointer(scroll, point, false, false)
		var offset := _offset(scroll, horizontal)
		_advance(scroll, 60)
		check(not scroll.is_scrolling() and _offset(scroll, horizontal) == offset and activations == before,
			"An interrupted drag cannot launch momentum or a tap: " + cause)


func _check_boundaries(scroll, horizontal: bool) -> void:
	var maximum := _maximum(scroll, horizontal)
	for direction in [-1.0, 1.0]:
		await _reset(scroll, horizontal, 100 if direction < 0 else maximum - 100)
		await _fling(scroll, horizontal, true, true, direction)
		for frame in range(90):
			_advance(scroll, 1)
			check(_offset(scroll, horizontal) >= 0 and _offset(scroll, horizontal) <= maximum,
				"Inertial scrolling stays within content bounds")
		check(not scroll.is_scrolling() and _offset(scroll, horizontal) == (0 if direction < 0 else maximum),
			"Reaching either content edge stops momentum without jitter")


func _check_wheel_and_pan(scroll, horizontal: bool) -> void:
	await _reset(scroll, horizontal)
	var wheel := InputEventMouseButton.new()
	wheel.position = _point(scroll, horizontal)
	wheel.global_position = wheel.position
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.factor = 1.0
	wheel.pressed = true
	_send(scroll, wheel)
	wheel.pressed = false
	_send(scroll, wheel)
	var released := _offset(scroll, horizontal)
	_advance(scroll, 6)
	check(_offset(scroll, horizontal) > released and scroll.is_scrolling(),
		"A desktop wheel notch keeps a smooth tail after its release")
	_advance(scroll, 240)
	check(not scroll.is_scrolling(), "Wheel scrolling settles instead of drifting indefinitely")
	await _reset(scroll, horizontal)
	var pan := InputEventPanGesture.new()
	pan.position = _point(scroll, horizontal)
	pan.delta = _axis(horizontal, 2.0)
	_send(scroll, pan)
	var after_pan := _offset(scroll, horizontal)
	check(after_pan > 120, "A trackpad pan still moves the content")
	_advance(scroll, 60)
	check(_offset(scroll, horizontal) == after_pan and not scroll.is_scrolling(),
		"Trackpad OS momentum is not amplified by a second synthesized fling")


func _check_stale_velocity(scroll, horizontal: bool) -> void:
	await _reset(scroll, horizontal)
	var point: Vector2 = await _fling(scroll, horizontal, true, true, 1.0, false)
	await create_timer(0.18).timeout
	_pointer(scroll, point, false, true)
	_pointer(scroll, point, false, false)
	var offset := _offset(scroll, horizontal)
	_advance(scroll, 60)
	check(not scroll.is_scrolling() and _offset(scroll, horizontal) == offset,
		"Holding still before release discards stale drag velocity")


func _check_native_mouse(scroll, horizontal: bool) -> void:
	await _reset(scroll, horizontal)
	var before := activations
	await _fling(scroll, horizontal, false, false, 1.0, true, true)
	var released := _offset(scroll, horizontal)
	_advance(scroll, 6)
	check(_offset(scroll, horizontal) > released and activations == before,
		"Desktop mouse dragging has momentum without activating crossed choices")
	scroll.cancel_drag()


func _check_native_line_edit(scroll, horizontal: bool) -> void:
	var body: BoxContainer = scroll.get_child(0)
	var button: Button = body.get_child(0)
	var field := LineEdit.new()
	field.custom_minimum_size = Vector2(160, 60)
	field.virtual_keyboard_show_on_focus = false
	body.add_child(field)
	body.move_child(field, 0)
	await settle()
	for touch_first in [false, true]:
		await _reset(scroll, horizontal, 0)
		field.text = ""
		var point := field.get_global_rect().get_center()
		var label := "horizontal=%s touch-first=%s" % [horizontal, touch_first]
		_pointer(scroll, point, true, touch_first)
		_pointer(scroll, point, true, not touch_first)
		_pointer(scroll, point, false, touch_first)
		_pointer(scroll, point, false, not touch_first)
		check(field.has_focus() and not scroll.is_pointer_active() and not scroll.is_scrolling(),
			"A username-like text field keeps native focus without starting a scroll: " + label)
		for down in [true, false]:
			var key := InputEventKey.new()
			key.keycode = KEY_A
			key.unicode = 97 if down else 0
			key.pressed = down
			_send(scroll, key)
		check(field.text == "a", "The focused field receives typed text through viewport dispatch: " + label)
		await settle()
		point = button.get_global_rect().get_center()
		check(scroll.get_global_rect().has_point(point), "The native-field fixture leaves its next button visible")
		var before := activations
		_pointer(scroll, point, true, touch_first)
		_pointer(scroll, point, true, not touch_first)
		check(scroll.is_pointer_active(), "The next button contact restores scroll gesture ownership: " + label)
		_pointer(scroll, point, false, touch_first)
		_pointer(scroll, point, false, not touch_first)
		check(activations == before + 1 and not scroll.is_scrolling(),
			"A button following a native field tap still activates exactly once: " + label)
	field.queue_free()
	await process_frame
