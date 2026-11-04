extends "res://tests/godot/word_jelly_map_tests.gd"
## Sleep timing and pointer ownership on the actual campaign map.


func _advance(pip, seconds: float) -> void:
	var remaining: float = seconds
	while remaining > 0.00001:
		var step: float = minf(0.05, remaining)
		pip._process(step)
		remaining -= step


func _freeze(view) -> void:
	view.set_process(false)
	view._pip.set_process(false)


func _move(point: Vector2, relative: Vector2 = Vector2(1, 0)) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	root.push_input(event, true)
	await process_frame


func _sleep(pip) -> void:
	pip.reset_rest()
	pip.set_process(false)
	_advance(pip, 3.01)
	check(pip.rest_snapshot().state == "sleeping", "Three quiet seconds put the actual guide to sleep")


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
	await _settle()
	var state: Dictionary = _state(55)
	view.open(state, false)
	await _settle()
	view._nodes[55].button.release_focus()
	_freeze(view)
	var pip = view._pip
	var geometry: Array = _geometry(view)
	var support: Array = pip.rest_snapshot().support
	pip.reset_rest()
	pip.set_process(false)
	check(pip.rest_snapshot().state == "awake" and not pip.rest_snapshot().snoring,
		"Opening starts with an awake guide rather than already playing a snore")
	_advance(pip, 2.90)
	check(pip.rest_snapshot().state == "awake", "Pip remains awake before the requested three-second delay")
	_advance(pip, 0.09)
	check(pip.rest_snapshot().state == "awake", "The idle threshold cannot round down to less than three seconds")
	_advance(pip, 0.02)
	check(pip.rest_snapshot().state == "sleeping" and pip.rest_snapshot().snoring,
		"Crossing three quiet seconds starts sleeping and its snore together")
	_advance(pip, 0.3)
	check(pip.expression_name() == "sleepy", "Sleeping uses the existing soft closed-eye expression")
	var sleeping: Array[Transform2D] = pip.rest_transforms()
	_advance(pip, 0.2)
	check(pip.rest_transforms() != sleeping and pip.rest_snapshot().support == support,
		"The sleeping body breathes without moving its supporting stage")
	var sleep_age: float = float(pip.rest_snapshot().quiet_seconds)
	view.configure(state, false)
	_freeze(view)
	check(pip.rest_snapshot().state == "sleeping" and float(pip.rest_snapshot().quiet_seconds) == sleep_age,
		"An ordinary wallet/status refresh neither wakes Pip nor restarts its idle clock")

	var count: int = int(pip.rest_snapshot().wake_count)
	await _move(Vector2(15, root.size.y - 20))
	_freeze(view)
	check(pip.rest_snapshot().state == "sleeping" and int(pip.rest_snapshot().wake_count) == count,
		"Pointer motion elsewhere on the map does not startle the resting guide")
	var head_point: Vector2 = pip.get_global_rect().position + pip.size * Vector2(0.5, 0.3)
	check(not view._nodes[55].button.get_global_rect().has_point(head_point),
		"The hover probe targets Pip above the medallion instead of relying on stage hover")
	await _move(head_point)
	_freeze(view)
	check(int(pip.rest_snapshot().wake_count) == count + 1 and not pip.rest_snapshot().snoring
		and pip.rest_snapshot().state != "sleeping",
		"A real mouse hover over input-transparent Pip stops snoring and wakes it once")
	check(float(pip.rest_snapshot().wake_direction) < 0.0,
		"At rightmost stage 56, Pip slips inward away from the screen edge")
	check(pip.disabled and pip.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and pip._foreground.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and not view.navigation_controls().has(pip),
		"The new hover reaction cannot claim clicks or add a keyboard target")
	var states: Array[String] = [str(pip.rest_snapshot().state)]
	var reaction_poses: Array = []
	for index in range(34):
		_advance(pip, 0.05)
		var sample: Dictionary = pip.rest_snapshot()
		if not states.has(str(sample.state)):
			states.append(str(sample.state))
		var transforms: Array[Transform2D] = pip.rest_transforms()
		if not reaction_poses.has(transforms):
			reaction_poses.append(transforms)
		for transform: Transform2D in transforms:
			check(is_equal_approx(transform.determinant(), 1.0),
				"The near-fall articulates rigid sourced parts without flattening Pip")
		check(_geometry(view) == geometry and sample.support == support,
			"The slip and climb keep native map input targets and the supporting rim fixed")
		if index == 6:
			var elapsed: float = float(sample.wake_elapsed)
			await _move(head_point + Vector2(1, 0))
			_freeze(view)
			check(int(pip.rest_snapshot().wake_count) == count + 1
				and float(pip.rest_snapshot().wake_elapsed) >= elapsed,
				"Moving again during the scramble cannot restart its timeline or duplicate its cue")
	check(states.has("slipping") and states.has("climbing") and states.has("awake")
		and reaction_poses.size() > 10,
		"One hover performs a visible slip, climb and complete return to its perch")
	var quiet: float = float(pip.rest_snapshot().quiet_seconds)
	check(quiet < 0.3, "The three quiet seconds begin after Pip finishes climbing back")
	_advance(pip, 2.95 - quiet)
	check(pip.rest_snapshot().state == "awake", "Recovery is followed by the full quiet delay")
	_advance(pip, 0.07)
	check(pip.rest_snapshot().state == "sleeping" and pip.rest_snapshot().snoring
		and int(pip.rest_snapshot().wake_count) == count + 1,
		"A cursor left stationary over Pip still allows it to fall asleep and snore again")
	await _move(head_point + Vector2(-1, 0))
	_freeze(view)
	check(int(pip.rest_snapshot().wake_count) == count + 2,
		"A later hover disturbance can replay the complete wake reaction")
	await _click(view._nodes[55].button)
	_freeze(view)
	check(_stage_events == [56], "Stage selection stays immediate during the near-fall recovery")

	view.set_active(false)
	var paused: Dictionary = pip.rest_snapshot()
	_advance(pip, 5.0)
	pip.pointer_activity()
	check(pip.rest_snapshot() == paused and not pip.is_processing() and not pip.rest_snapshot().snoring,
		"An inactive map cannot continue a snore, wake choreography or quiet clock")
	view.set_active(true)
	await _settle()
	_freeze(view)
	_sleep(pip)
	view.close()
	var closed: Dictionary = pip.rest_snapshot()
	await _move(head_point)
	_advance(pip, 5.0)
	check(pip.rest_snapshot() == closed and not pip.is_processing() and not pip.rest_snapshot().snoring,
		"Closing cancels the sleeping guide and rejects late pointer input")
	view.open(state, false)
	await _settle()
	_freeze(view)
	check(pip.rest_snapshot().state == "awake" and float(pip.rest_snapshot().quiet_seconds) < 0.2,
		"Reopening begins a fresh three-second wait without replaying a hidden startle")
	pip.reset_rest()
	_advance(pip, 2.8)
	pip.pointer_activity()
	_freeze(view)
	_advance(pip, 0.3)
	check(pip.rest_snapshot().state == "awake" and float(pip.rest_snapshot().quiet_seconds) < 0.31,
		"Activity while already awake restarts the quiet delay rather than replaying a startle")
	_advance(pip, 2.71)
	check(pip.rest_snapshot().state == "sleeping",
		"The renewed quiet delay ends three seconds after the last disturbance")

	view.set_reduced_motion(true)
	_freeze(view)
	pip.reset_rest()
	check(not pip.is_processing() and not pip._sleep_timer.is_stopped(),
		"Reduced motion uses a bounded sleep timer without a per-frame animation owner")
	pip._sleep_timer.start(0.5)
	pip.set_reduced_motion(false)
	_freeze(view)
	_advance(pip, 0.49)
	check(pip.rest_snapshot().state == "awake",
		"Restoring motion preserves the last half-second of the existing quiet deadline")
	_advance(pip, 0.02)
	check(pip.rest_snapshot().state == "sleeping",
		"Changing motion preference does not restart the three-second wait")
	pip.set_reduced_motion(true)
	pip.reset_rest()
	pip._sleep_timer.timeout.emit()
	check(pip.rest_snapshot().state == "sleeping" and pip.expression_name() == "sleepy",
		"Reduced motion still reaches the recognizable sleeping state after its timer")
	var reduced_clock: float = pip._idle_time
	var reduced_pose: Array[Transform2D] = pip.rest_transforms()
	_advance(pip, 0.3)
	check(pip._idle_time == reduced_clock and pip.rest_transforms() == reduced_pose,
		"Reduced sleeping does not breathe or drift between static frames")
	count = int(pip.rest_snapshot().wake_count)
	pip.pointer_activity()
	check(pip.rest_snapshot().state == "awake" and not pip.rest_snapshot().snoring
		and int(pip.rest_snapshot().wake_count) == count + 1 and not pip.is_processing(),
		"Reduced motion acknowledges a disturbance with an awake face and no falling animation")
	view.set_active(false)
	check(pip._sleep_timer.is_stopped(), "Backgrounding cancels the reduced-motion sleep deadline")
	pip._sleep_timer.timeout.emit()
	check(pip.rest_snapshot().state == "awake" and not pip.rest_snapshot().snoring,
		"A stale sleep callback cannot resume the companion on an inactive map")
	view.set_active(true)
	view.open(_state(57), false)
	await _settle()
	_freeze(view)
	_sleep(pip)
	pip.pointer_activity()
	check(float(pip.rest_snapshot().wake_direction) > 0.0,
		"At leftmost stage 58, Pip slips inward without mirroring its artwork")
	view.close()
	_holder.free()
	_finish()
