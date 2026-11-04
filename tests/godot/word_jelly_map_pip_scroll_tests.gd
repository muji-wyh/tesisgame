extends "res://tests/godot/word_jelly_map_tests.gd"
## Real route scrolling owns Pip's wake cue and bounded supported recovery.

var _scroll_deltas: Array[float] = []
var _scroll_states: Array[String] = []


func _freeze(view) -> void:
	view.set_process(false)
	view._pip.set_process(false)
	view._scroll.set_process(false)


func _advance(pip, seconds: float) -> void:
	var remaining: float = seconds
	while remaining > 0.000001:
		var step: float = minf(1.0 / 60.0, remaining)
		pip._process(step)
		remaining -= step


func _sleep(pip) -> void:
	pip.reset_rest()
	pip.set_process(false)
	_advance(pip, 3.01)
	check(pip.rest_snapshot().state == "sleeping", "The scroll fixture begins with a genuinely sleeping guide")


func _vector(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2(INF, INF)


func _delta_sum(start: int) -> float:
	var total: float = 0.0
	for index in range(start, _scroll_deltas.size()):
		total += _scroll_deltas[index]
	return total


func _target_geometry(view) -> Array:
	var result: Array = []
	for button: BaseButton in _buttons(view):
		if button.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			result.append([button.get_instance_id(), button.position, button.size, button.scale])
	return result


func _check_supported(view, expected: Array, art: String) -> void:
	var pip = view._pip
	var highest: int = int(view._state.highest_cleared)
	var item: Dictionary = view._nodes[highest]
	var expected_support: Vector2 = item.button.get_global_transform() * item.face.get_transform() \
		* Vector2(item.face.size.x * 0.5, 0)
	var actual_support: Vector2 = pip.get_global_transform() * pip.support_point()
	check(actual_support.distance_to(expected_support) < 0.01 and _target_geometry(view) == expected,
		"Scroll feedback follows the medallion rim without resizing or moving native input targets")
	check(pip._outfit_dance_sheet.resource_path == art and pip.scale.x > 0.0,
		"The scroll performance retains the acquired unmirrored artwork")
	var transforms: Array[Transform2D] = pip.rest_transforms()
	check(transforms.size() == 6, "Scrolling retains the six-part character contract")
	for transform: Transform2D in transforms:
		check(is_equal_approx(transform.determinant(), 1.0),
			"Scroll inertia and gripping rotate rigid artwork parts without flattening them")


func _check_bounded(pip) -> void:
	var inertia: Dictionary = pip.rest_snapshot().inertia
	var offset: Vector2 = _vector(inertia.offset)
	var velocity: Vector2 = _vector(inertia.velocity)
	check(offset.is_finite() and velocity.is_finite() and is_finite(float(inertia.angle))
		and is_finite(float(inertia.angular_velocity)) and is_finite(float(inertia.platform_velocity)),
		"Scroll recovery remains finite under the supplied input and frame interval")
	check(offset.length() <= 12.0 and absf(rad_to_deg(float(inertia.angle))) <= 12.0,
		"The inertial body stays within a small supported displacement and readable tilt")


func _wheel(point: Vector2, direction: int, factor: float = 1.0) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN if direction > 0 else MOUSE_BUTTON_WHEEL_UP
	event.factor = factor
	event.pressed = true
	event.position = point
	event.global_position = point
	root.push_input(event, true)
	await process_frame


func _open(view, highest: int = 55, reduced: bool = false) -> void:
	view.set_active(true)
	view.open(_state(highest), reduced)
	await _settle()
	view._nodes[highest].button.release_focus()
	_freeze(view)
	view._pip.set_audio_enabled(true)


func _settle_pip(pip) -> void:
	for frame in range(360):
		pip._process(1.0 / 60.0)
		var state: String = str(pip.rest_snapshot().state)
		if not _scroll_states.has(state):
			_scroll_states.append(state)
		if pip.rest_snapshot().state == "awake" and not pip.rest_snapshot().gripping:
			return
	check(false, "Scroll recovery returns control to the ordinary awake perch within six seconds")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	_holder = Control.new()
	root.add_child(_holder)
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var view = load(MAP_PATH).new()
	_holder.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.stage_selected.connect(func(number: int) -> void: _stage_events.append(number))
	view._scroll.user_scroll_delta.connect(func(distance: float) -> void: _scroll_deltas.append(distance))
	await _settle()
	await _open(view)
	var pip = view._pip
	var scroll = view._scroll
	_sleep(pip)
	var count: int = int(pip.rest_snapshot().wake_count)
	var scroll_count: int = int(pip.rest_snapshot().scroll_wake_count)
	var event_count: int = _scroll_deltas.size()
	scroll.scroll_vertical += 16
	await _settle()
	_freeze(view)
	view.focus_frontier()
	await _settle()
	_freeze(view)
	view._layout()
	check(_scroll_deltas.size() == event_count and int(pip.rest_snapshot().wake_count) == count
		and pip.rest_snapshot().state == "sleeping",
		"Programmatic offset, focus reveal and layout recenter cannot impersonate user scrolling")

	var geometry: Array = _target_geometry(view)
	var art: String = pip._outfit_dance_sheet.resource_path
	var point: Vector2 = scroll.get_global_rect().position + Vector2(18, scroll.size.y * 0.5)
	var offset: int = scroll.scroll_vertical
	var peeps: int = int(pip.rest_snapshot().audio.wake_requests)
	await _wheel(point, 1)
	_freeze(view)
	check(scroll.scroll_vertical > offset and _delta_sum(event_count) == float(scroll.scroll_vertical - offset),
		"A real wheel notch publishes only the distance the route actually moved")
	check(pip.rest_snapshot().wake_source == "scroll" and int(pip.rest_snapshot().scroll_wake_count) == scroll_count + 1
		and int(pip.rest_snapshot().wake_count) == count + 1
		and int(pip.rest_snapshot().audio.wake_requests) == peeps + 1
		and pip.rest_snapshot().state == "scroll-startled",
		"The first real movement wakes sleeping Pip once with one scroll-owned peep")
	_advance(pip, 0.016)
	check(_vector(pip.rest_snapshot().inertia.offset).y > 0.0,
		"As the wheel moves the stage upward, Pip's body initially lags downward")
	_check_supported(view, geometry, art)
	_check_bounded(pip)
	var wake_elapsed: float = float(pip.rest_snapshot().wake_elapsed)
	await _wheel(point, 1, 0.5)
	_freeze(view)
	check(int(pip.rest_snapshot().scroll_wake_count) == scroll_count + 1
		and int(pip.rest_snapshot().audio.wake_requests) == peeps + 1
		and float(pip.rest_snapshot().wake_elapsed) >= wake_elapsed,
		"More notches extend the grip without replaying the wake cue or restarting recovery")
	scroll.cancel_drag()
	_settle_pip(pip)
	check(_scroll_states.has("scroll-settling") and _scroll_states.has("awake"),
		"The scroll wake passes through physical settling before ordinary awake rest")
	var quiet: float = float(pip.rest_snapshot().quiet_seconds)
	check(pip.rest_snapshot().state == "awake" and quiet < 0.2,
		"The quiet countdown starts after the physical scroll response settles")
	_advance(pip, maxf(0.0, 2.95 - quiet))
	check(pip.rest_snapshot().state == "awake", "A settled scroll wake retains the full three-second quiet delay")
	_advance(pip, 0.07)
	check(pip.rest_snapshot().state == "sleeping" and int(pip.rest_snapshot().wake_count) == count + 1,
		"Pip resumes its original sleep performance after three settled quiet seconds")

	await _open(view)
	_sleep(pip)
	event_count = _scroll_deltas.size()
	offset = scroll.scroll_vertical
	count = int(pip.rest_snapshot().scroll_wake_count)
	peeps = int(pip.rest_snapshot().audio.wake_requests)
	point = scroll.get_global_rect().position + Vector2(18, scroll.size.y * 0.55)
	await _touch(point, true, 23)
	await _touch_move(point + Vector2(0, -32), 23)
	await _touch_move(point + Vector2(0, -64), 23)
	await _touch(point + Vector2(0, -64), false, 23)
	_freeze(view)
	check(scroll.scroll_vertical > offset and _delta_sum(event_count) == float(scroll.scroll_vertical - offset)
		and int(pip.rest_snapshot().scroll_wake_count) == count + 1
		and int(pip.rest_snapshot().audio.wake_requests) == peeps + 1 and _stage_events.is_empty(),
		"A real touch drag supplies one stream of actual movement and never selects a stage")
	check(scroll.is_coasting(), "Releasing the real drag starts the existing route coast")
	offset = scroll.scroll_vertical
	event_count = _scroll_deltas.size()
	for frame in range(3):
		scroll._process(1.0 / 60.0)
		pip._process(1.0 / 60.0)
	check(scroll.scroll_vertical > offset and _scroll_deltas.size() > event_count
		and _delta_sum(event_count) == float(scroll.scroll_vertical - offset)
		and int(pip.rest_snapshot().scroll_wake_count) == count + 1
		and int(pip.rest_snapshot().audio.wake_requests) == peeps + 1,
		"Coasting continues actual scroll feedback without inventing another wake event")
	scroll.cancel_drag()
	_freeze(view)
	geometry = _target_geometry(view)
	_check_supported(view, geometry, art)

	await _open(view)
	_sleep(pip)
	geometry = _target_geometry(view)
	pip.scroll_motion(24.0)
	_advance(pip, 0.016)
	var before_reverse: float = _vector(pip.rest_snapshot().inertia.velocity).y
	pip.scroll_motion(-24.0)
	_advance(pip, 0.016)
	check(before_reverse > 0.0 and _vector(pip.rest_snapshot().inertia.velocity).y < 0.0,
		"Reversing platform movement reverses the inertial response instead of replaying a fixed wiggle")
	_check_bounded(pip)
	for frame in range(24):
		pip.scroll_motion(3.0)
		pip._process(1.0 / 60.0)
	check(pip.rest_snapshot().gripping and pip.rest_snapshot().state == "scroll-gripping",
		"Sustained actual movement lets Pip complete its protective grip")
	var grasped: Array[Transform2D] = pip.rest_transforms()
	var tips: Array[Vector2] = [grasped[2] * pip.grip_tip(2), grasped[3] * pip.grip_tip(3)]
	for distance: float in [6.0, -6.0, 3.0]:
		pip.scroll_motion(distance)
		pip._process(1.0 / 60.0)
		var transforms: Array[Transform2D] = pip.rest_transforms()
		check((transforms[2] * pip.grip_tip(2)).distance_to(tips[0]) < 0.25
			and (transforms[3] * pip.grip_tip(3)).distance_to(tips[1]) < 0.25,
			"Both sourced wing tips stay planted while the supported body responds to movement")
		_check_supported(view, geometry, art)
		_check_bounded(pip)
	for distance: float in [1000000000000.0, -1000000000000.0, 0.000000001, 0.0]:
		pip.scroll_motion(distance)
		pip._process(0.001)
		_check_bounded(pip)
	var inertia: Dictionary = pip.rest_snapshot().inertia.duplicate(true)
	for invalid: float in [NAN, INF, -INF]:
		pip.scroll_motion(invalid)
	check(pip.rest_snapshot().inertia == inertia, "Invalid distances cannot contaminate pending inertial state")
	for delta: float in [NAN, INF, -1.0, 0.0]:
		pip._process(delta)
	check(pip.rest_snapshot().inertia == inertia, "Invalid frame intervals leave physical recovery unchanged")
	pip._process(10.0)
	_check_bounded(pip)
	await _open(view)
	_sleep(pip)
	count = int(pip.rest_snapshot().scroll_wake_count)
	pip.pointer_activity()
	check(pip.rest_snapshot().wake_source == "pointer" and not pip.rest_snapshot().gripping
		and int(pip.rest_snapshot().scroll_wake_count) == count,
		"An ordinary pointer disturbance keeps the existing wake behavior and scroll provenance separate")

	for highest: int in [98, 0]:
		await _open(view, highest)
		scroll.scroll_vertical = 0 if highest == 98 else roundi(scroll._maximum())
		await _settle()
		_freeze(view)
		_sleep(pip)
		event_count = _scroll_deltas.size()
		count = int(pip.rest_snapshot().wake_count)
		offset = scroll.scroll_vertical
		point = scroll.get_global_rect().position + Vector2(18, scroll.size.y * 0.5)
		await _wheel(point, -1 if highest == 98 else 1)
		_freeze(view)
		check(scroll.scroll_vertical == offset and _scroll_deltas.size() == event_count
			and int(pip.rest_snapshot().wake_count) == count,
			"A wheel pressed against the route boundary cannot wake Pip without actual movement")

	await _open(view)
	_sleep(pip)
	pip.scroll_motion(24.0)
	_advance(pip, 0.1)
	view.set_active(false)
	var paused: Dictionary = pip.rest_snapshot().inertia.duplicate(true)
	pip.scroll_motion(48.0)
	_advance(pip, 4.0)
	check(pip.rest_snapshot().inertia == paused and _vector(paused.offset).is_zero_approx()
		and not pip.rest_snapshot().gripping and not pip.is_processing(),
		"Pausing discards grip and inertia and rejects late scroll feedback")
	await _open(view)
	_sleep(pip)
	pip.scroll_motion(24.0)
	_advance(pip, 0.1)
	scroll.scroll_vertical = 0
	await _settle()
	_freeze(view)
	check(not pip.is_visible_in_tree() and _vector(pip.rest_snapshot().inertia.offset).is_zero_approx()
		and not pip.rest_snapshot().gripping,
		"Moving the supported stage offscreen clears its physical response")
	view.focus_frontier()
	await _settle()
	_freeze(view)
	_sleep(pip)
	pip.scroll_motion(24.0)
	view.close()
	paused = pip.rest_snapshot().inertia.duplicate(true)
	pip.scroll_motion(48.0)
	_advance(pip, 4.0)
	check(pip.rest_snapshot().inertia == paused and _vector(paused.offset).is_zero_approx()
		and not pip.rest_snapshot().gripping and not scroll.is_scrolling(),
		"Closing discards inertia and ignores a delayed scroll event")

	await _open(view, 55, true)
	pip.reset_rest()
	pip._sleep_timer.timeout.emit()
	point = scroll.get_global_rect().position + Vector2(18, scroll.size.y * 0.5)
	await _wheel(point, 1)
	_freeze(view)
	check(pip.rest_snapshot().wake_source == "scroll" and pip.rest_snapshot().gripping
		and not pip.is_processing() and not pip._sleep_timer.is_stopped()
		and pip._sleep_timer.time_left > 2.7,
		"Reduced motion acknowledges a scroll with a static grip and the full quiet timer")
	var static_grip: Array[Transform2D] = pip.rest_transforms()
	var quiet_remaining: float = pip._sleep_timer.time_left
	scroll.cancel_drag()
	await create_timer(0.6).timeout
	check(pip.rest_transforms() == static_grip and not pip.is_processing()
		and pip.expression_name() == "neutral" and pip.rest_snapshot().state == "awake"
		and not pip.rest_snapshot().gripping
		and _vector(pip.rest_snapshot().inertia.offset).is_zero_approx()
		and _vector(pip.rest_snapshot().inertia.velocity).is_zero_approx(),
		"The bounded reduced-motion reaction releases its grip and returns to a neutral face without body motion")
	check(not pip._sleep_timer.is_stopped() and pip._sleep_timer.time_left <= quiet_remaining - 0.5
		and pip._sleep_timer.time_left >= quiet_remaining - 0.9,
		"Static grip release and face recovery preserve the quiet deadline from the last actual movement")
	pip._sleep_timer.timeout.emit()
	check(pip.rest_snapshot().state == "sleeping" and pip.rest_snapshot().sleep_stage == "upright-snoring"
		and not pip.rest_snapshot().gripping and not pip.is_processing(),
		"The reduced quiet deadline returns to static upright sleep")
	view.close()
	await create_timer(0.1).timeout
	_holder.free()
	_finish()
