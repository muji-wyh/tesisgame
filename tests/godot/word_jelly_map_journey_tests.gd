extends "res://tests/godot/word_jelly_map_tests.gd"
## Saved frontier progression owns one run, jump and supported landing.

const JOURNEY_OUTPUT := "res://build/qa/jelly-map-journey"
const MOTION_FPS: int = 30


func _freeze(view) -> void:
	view.set_process(false)
	view._pip.set_process(false)
	view._scroll.set_process(false)


func _journey_state(highest: int, context: String = "growth") -> Dictionary:
	var state: Dictionary = _state(highest)
	state.context_key = context
	state.pip_age = 3
	return state


func _journey(view) -> Dictionary:
	return view.snapshot().get("guide", {}).get("journey", {})


func _point(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary and value.has_all(["x", "y"]):
		return Vector2(float(value.x), float(value.y))
	return Vector2(INF, INF)


func _rim(view, number: int) -> Vector2:
	var item: Dictionary = view._nodes[number - 1]
	return item.button.position + item.face.get_transform() * Vector2(item.face.size.x * 0.5, 0.0)


func _guide_support(view) -> Vector2:
	return view._pip.position + view._pip.support_point()


func _targets(view) -> Array:
	var result: Array = []
	for button: BaseButton in _buttons(view):
		if button.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			result.append([button.get_instance_id(), button.position, button.size, button.scale])
	return result


func _pose_distance(left: Array[Transform2D], right: Array[Transform2D]) -> float:
	var distance := 0.0
	for index in range(mini(left.size(), right.size())):
		for point: Vector2 in [Vector2(60, 40), Vector2(60, 100)]:
			distance = maxf(distance, (left[index] * point).distance_to(right[index] * point))
	return distance


func _check_sample(view, phase: String, elapsed: float) -> void:
	var sample: Dictionary = _journey(view)
	check(sample.active and str(sample.phase) == phase and absf(float(sample.elapsed) - elapsed) < 0.0001,
		"The saved frontier follows the shared %s beat at %.3f seconds: %s" % [phase, elapsed, sample])
	check(is_finite(float(sample.progress)) and float(sample.progress) >= 0.0 and float(sample.progress) <= 1.0
		and _point(sample.support).is_finite() and _point(sample.source_support).is_finite()
		and _point(sample.target_support).is_finite(),
		"The actual journey publishes finite support positions and bounded progress")
	check(_point(sample.support).distance_to(_guide_support(view)) < 0.01
		and view._pip.journey_active(), "Map trajectory and the articulated companion share the same live journey")
	var transforms: Array[Transform2D] = view._pip.rest_transforms()
	check(transforms.size() == 6, "Moving retains the acquired six-part character rig")
	for transform: Transform2D in transforms:
		check(is_equal_approx(transform.determinant(), 1.0), "Journey motion keeps the sourced artwork rigid")


func _advance_to(view, elapsed: float) -> void:
	var previous: float = float(_journey(view).elapsed)
	check(elapsed >= previous, "The journey fixture samples its real clock in forward order")
	var remaining: float = maxf(0.0, elapsed - previous)
	while remaining > 0.0:
		var step: float = minf(1.0 / 60.0, remaining)
		view._process(step)
		var current: float = float(_journey(view).elapsed)
		if current <= previous:
			break
		previous = current
		remaining = maxf(0.0, elapsed - current)
	_freeze(view)


func _start(view, number: int, appearance: Dictionary = {}, context: String = "growth") -> void:
	view.set_active(true)
	view.close()
	var source: Dictionary = _journey_state(number - 1, context)
	source.merge(appearance, true)
	view.open(source, false)
	_freeze(view)
	await _settle()
	view._nodes[number - 1].button.release_focus()
	_freeze(view)
	var target: Dictionary = _journey_state(number, context)
	target.merge(appearance, true)
	view.open(target, false)
	_freeze(view)
	await _settle()
	_freeze(view)


func _save_journey(view, name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	_freeze(view)
	check(DirAccess.make_dir_recursive_absolute(JOURNEY_OUTPUT) == OK, "Journey captures use the ignored QA directory")
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(JOURNEY_OUTPUT + "/" + name + ".png") == OK,
		"Retain the actual %s journey frame" % name)
	_freeze(view)


func _check_landing(view, number: int, targets: Array) -> void:
	check(not _journey(view).active and not view._pip.journey_active(),
		"Completing the timeline releases both trajectory and rig ownership exactly once")
	check(_guide_support(view).distance_to(_rim(view, number)) < 0.01,
		"Pip lands on the real painted next-stage rim without an endpoint snap")
	check(_targets(view) == targets and _stage_events.is_empty(),
		"Running and landing preserve every native hit target and never select a stage")
	check(view._pip.rest_snapshot().state == "awake" and not view._pip.rest_snapshot().snoring
		and float(view._pip.rest_snapshot().quiet_seconds) < 0.001,
		"Landing returns Pip awake and starts a fresh three-second quiet deadline")


func _check_no_journey(view, message: String) -> void:
	check(not _journey(view).active and not view._pip.journey_active(), message)


func _check_continuity(view, number: int) -> void:
	var previous_support: Vector2 = _guide_support(view)
	var previous_pose: Array[Transform2D] = view._pip.rest_transforms()
	var source_rect: Rect2 = view._nodes[number - 1].button.get_rect()
	var target_rect: Rect2 = view._nodes[number].button.get_rect()
	var wake_count: int = int(view._pip.rest_snapshot().wake_count)
	var wake_requests: int = int(view._pip.rest_snapshot().audio.wake_requests)
	var phases: Array[String] = [str(_journey(view).phase)]
	var total: float = view.ROUTE_SECONDS + view.UNLOCK_SECONDS
	var frame_count: int = ceili(total * 60.0)
	for frame in range(1, frame_count + 1):
		var elapsed: float = minf(total, float(frame) / 60.0)
		_advance_to(view, elapsed)
		var sample: Dictionary = _journey(view)
		var pose: Array[Transform2D] = view._pip.rest_transforms()
		var support: Vector2 = _guide_support(view)
		if not phases.has(str(sample.phase)):
			phases.append(str(sample.phase))
		check(previous_support.distance_to(support) < 16.0 / view._scale
			and _pose_distance(previous_pose, pose) < 15.0,
			"Each 60 fps frame joins the route and rigid pose without a teleport: %d to %d frame %d (%s)" %
				[number, number + 1, frame, str(sample.phase)])
		check(view._nodes[number - 1].button.get_rect() == source_rect
			and view._nodes[number].button.get_rect() == target_rect
			and _point(sample.source_support).distance_to(_rim(view, number)) < 0.01
			and _point(sample.target_support).distance_to(_rim(view, number + 1)) < 0.01,
			"Every journey frame preserves native source/target geometry and follows the painted rims")
		check(int(view._pip.rest_snapshot().wake_count) == wake_count
			and int(view._pip.rest_snapshot().audio.wake_requests) == wake_requests
			and not view._pip.rest_snapshot().snoring and not view._pip.rest_snapshot().gripping,
			"Continuous travel emits no startled wake or sleeping response")
		previous_support = support
		previous_pose = pose
	check(phases == ["depart", "run", "jump", "land", "done"],
		"A full 60 fps traversal visits each owned phase in order before returning to rest")
	check(_guide_support(view).distance_to(_rim(view, number + 1)) < 0.01,
		"The continuously sampled journey still ends exactly on its destination rim")


func _check_landing_handoff(view) -> void:
	var total: float = view.ROUTE_SECONDS + view.UNLOCK_SECONDS
	_advance_to(view, total - 0.0001)
	var support: Vector2 = _guide_support(view)
	var before: Array[Transform2D] = view._pip.rest_transforms()
	check(_journey(view).active and _journey(view).phase == "land"
		and view._pip.journey_active(), "The immediate pre-handoff frame still belongs to landing")
	_advance_to(view, total)
	check(not _journey(view).active and not view._pip.journey_active()
		and _guide_support(view).distance_to(support) < 0.01
		and _pose_distance(before, view._pip.rest_transforms()) < 0.05,
		"The exact landing-to-rest handoff changes ownership without a support or artwork snap")
	var settled: Array[Transform2D] = view._pip.rest_transforms()
	view._process(0.0001)
	check(not _journey(view).active and _guide_support(view).distance_to(support) < 0.01
		and _pose_distance(settled, view._pip.rest_transforms()) < 0.05,
		"The immediate post-handoff frame retains the supported resting pose")
	_freeze(view)


func _check_wardrobes(view) -> void:
	var profiles: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/pip-professional.json")).profiles
	var course_id: String = str(profiles[0].course_id)
	var cases: Array[Dictionary] = [
		{"name": "Baby", "appearance": {"pip_age": 0}, "context": "growth"},
		{"name": "Age 12", "appearance": {"pip_age": 12}, "context": "growth"},
		{"name": course_id, "appearance": {"pip_profile": {"course_id": course_id, "level": 4}},
			"context": "professional:%s:module03" % course_id}]
	for item: Dictionary in cases:
		await _start(view, 5, item.appearance, str(item.context))
		var art: String = view._pip._outfit_dance_sheet.resource_path
		check(not art.is_empty(), "The %s journey uses an acquired character atlas" % str(item.name))
		for beat: Dictionary in [
			{"phase": "run", "elapsed": view.DEPART_SECONDS + view.RUN_SECONDS * 0.5},
			{"phase": "jump", "elapsed": view.ROUTE_SECONDS + view.JUMP_SECONDS * 0.5},
			{"phase": "land", "elapsed": view.ROUTE_SECONDS + view.JUMP_SECONDS + view.LAND_SECONDS * 0.5}]:
			_advance_to(view, float(beat.elapsed))
			_check_sample(view, str(beat.phase), float(beat.elapsed))
			check(view._pip._outfit_dance_sheet.resource_path == art,
				"The %s wardrobe stays on the same acquired atlas through %s" % [str(item.name), str(beat.phase)])
			if item.appearance.has("pip_profile"):
				check(view.snapshot().guide.course_id == course_id,
					"The professional journey retains its supplied career instead of borrowing an everyday appearance")
			else:
				check(view._pip.growth_age == int(item.appearance.pip_age),
					"The everyday journey retains the supplied Baby or older Pip anatomy")
		_check_landing_handoff(view)


func _capture_motion(view, number: int, dimensions: Vector2i, name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture-motion") or DisplayServer.get_name() == "headless":
		return
	await _resize(dimensions)
	await _start(view, number)
	var directory: String = JOURNEY_OUTPUT + "/motion/" + name
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Sequential motion frames use the ignored QA directory")
	var total: float = view.ROUTE_SECONDS + view.UNLOCK_SECONDS
	var frames: int = ceili((total + 0.4) * MOTION_FPS)
	for frame in range(frames + 1):
		_advance_to(view, minf(total, float(frame) / MOTION_FPS))
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(directory + "/frame-%04d.png" % frame) == OK,
			"Save native map motion at 30 fps: %s frame %d" % [name, frame])
		_freeze(view)
	print("Journey motion capture: %s (%d frames at %d fps)" % [directory, frames + 1, MOTION_FPS])


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
	view.open(_journey_state(4), false)
	_freeze(view)
	var contract: Dictionary = _journey(view)
	var valid: bool = contract.has_all(["active", "from", "to", "phase", "progress", "elapsed",
		"support", "source_support", "target_support", "direction"])
	check(valid and view.has_method("_journey_active") and view._pip.has_method("journey_active"),
		"The actual map exposes its trajectory and articulated journey contract")
	if not valid or not view.has_method("_journey_active") or not view._pip.has_method("journey_active"):
		_holder.free()
		_finish()
		return
	_check_no_journey(view, "Opening saved progress cannot invent a newly completed stage")
	check(is_equal_approx(view.ROUTE_SECONDS, view.DEPART_SECONDS + view.RUN_SECONDS)
		and is_equal_approx(view.UNLOCK_SECONDS, view.JUMP_SECONDS + view.LAND_SECONDS),
		"The existing route and unlock share the departure, run, jump and landing durations")

	await _start(view, 5)
	var targets: Array = _targets(view)
	var initial: Dictionary = _journey(view)
	check(initial.from == 5 and initial.to == 6 and view._journey_active(),
		"A newly saved frontier moves only from its completed stage to the next stage")
	_check_sample(view, "depart", 0.0)
	check(_point(initial.support).distance_to(_rim(view, 5)) < 0.01
		and _point(initial.support).distance_to(_point(initial.source_support)) < 0.01,
		"Return starts at the completed stage's actual rim instead of teleporting to the frontier")
	await _save_journey(view, "depart-1366x768")
	_advance_to(view, view.DEPART_SECONDS * 0.5)
	_check_sample(view, "depart", view.DEPART_SECONDS * 0.5)
	_advance_to(view, view.DEPART_SECONDS + view.RUN_SECONDS * 0.25)
	_check_sample(view, "run", view.DEPART_SECONDS + view.RUN_SECONDS * 0.25)
	var first_step: Array[Transform2D] = view._pip.rest_transforms()
	var first_support: Vector2 = _guide_support(view)
	await _save_journey(view, "run-1366x768")
	_advance_to(view, view.DEPART_SECONDS + view.RUN_SECONDS * 0.40)
	_check_sample(view, "run", view.DEPART_SECONDS + view.RUN_SECONDS * 0.40)
	check(_guide_support(view).distance_to(first_support) > 3.0 / view._scale
		and _pose_distance(first_step, view._pip.rest_transforms()) > 0.5,
		"Route progress includes actual travel and changing foot-and-wing articulation")
	var running: Dictionary = _journey(view)
	var refreshed: Dictionary = _journey_state(5)
	refreshed.coins += 173
	view.configure(refreshed, false)
	_freeze(view)
	check(_journey(view) == running, "An ordinary wallet refresh preserves trajectory position, phase and elapsed time")
	var open_pose: Array[Transform2D] = view._pip.rest_transforms()
	view.open(refreshed, false)
	_freeze(view)
	check(_journey(view) == running and _pose_distance(open_pose, view._pip.rest_transforms()) < 0.001,
		"Opening the same saved map mid-run preserves its owned pose and timeline")
	view._pip.pointer_activity()
	view._pip.scroll_motion(80.0)
	view._pip._process(4.0)
	check(_journey(view) == running and not view._pip.rest_snapshot().snoring
		and not view._pip.rest_snapshot().gripping and float(view._pip.rest_snapshot().quiet_seconds) < 0.001,
		"Pointer, scroll wake and quiet clocks cannot replace the committed journey pose")
	view.set_active(false)
	var paused: Dictionary = _journey(view)
	view._process(20.0)
	check(_journey(view) == paused, "Backgrounding freezes the route without unseen motion")
	view.set_active(true)
	_freeze(view)
	check(_journey(view) == paused, "Resuming preserves the visible travel beat without catching up wall-clock time")
	view._process(20.0)
	_freeze(view)
	check(_journey(view).active and _journey(view).phase == "run"
		and float(_journey(view).elapsed) > float(paused.elapsed)
		and float(_journey(view).elapsed) - float(paused.elapsed) <= 0.10001,
		"A long resumed browser frame advances at most a tenth of a second and retains the run")
	_advance_to(view, view.ROUTE_SECONDS + view.JUMP_SECONDS * 0.5)
	_check_sample(view, "jump", view.ROUTE_SECONDS + view.JUMP_SECONDS * 0.5)
	check(_guide_support(view).y < _point(_journey(view).target_support).y - 2.0 / view._scale,
		"The real airborne midpoint clears the destination rim before landing")
	await _save_journey(view, "jump-1366x768")
	_advance_to(view, view.ROUTE_SECONDS + view.JUMP_SECONDS + view.LAND_SECONDS * 0.5)
	_check_sample(view, "land", view.ROUTE_SECONDS + view.JUMP_SECONDS + view.LAND_SECONDS * 0.5)
	var total: float = view.ROUTE_SECONDS + view.UNLOCK_SECONDS
	_advance_to(view, total)
	_check_landing(view, 6, targets)
	await _save_journey(view, "land-1366x768")
	view.open(_journey_state(5), false)
	_freeze(view)
	_check_no_journey(view, "Reopening or replaying the unchanged frontier cannot repeat the journey")

	for dimensions: Vector2i in SIZES:
		await _resize(dimensions)
		await _start(view, 9)
		var sample: Dictionary = _journey(view)
		check(sample.from == 9 and sample.to == 10 and sample.active and view.snapshot().guide.visible,
			"Crossing the real chapter boundary retains a visible 9-to-10 journey at %s" % dimensions)
		_advance_to(view, view.DEPART_SECONDS + view.RUN_SECONDS * 0.5)
		var elapsed: float = float(_journey(view).elapsed)
		view._layout()
		_freeze(view)
		check(absf(float(_journey(view).elapsed) - elapsed) < 0.0001
			and _point(_journey(view).support).distance_to(_guide_support(view)) < 0.01,
			"Responsive relayout retargets the same journey without resetting its clock at %s" % dimensions)
		if dimensions in [Vector2i(1366, 768), Vector2i(393, 852)]:
			await _save_journey(view, "boundary-run-%dx%d" % [dimensions.x, dimensions.y])
		check(view.show_chapter(3), "The player can still browse another chapter during decorative travel")
		_advance_to(view, total)
		_freeze(view)
		check(view.show_chapter(2), "The player can return to the earned chapter after offscreen landing")
		_check_no_journey(view, "An offscreen journey completes once instead of replaying on chapter return")
		check(_guide_support(view).distance_to(_rim(view, 10)) < 0.01,
			"The chapter-boundary journey finishes on the stage 10 rim at %s" % dimensions)

	await _resize(Vector2i(1366, 768))
	await _start(view, 9)
	_advance_to(view, view.DEPART_SECONDS + view.RUN_SECONDS * 0.5)
	var resize_age: float = float(_journey(view).elapsed)
	await _resize(Vector2i(393, 852))
	_freeze(view)
	check(absf(float(_journey(view).elapsed) - resize_age) < 0.0001 and _journey(view).active
		and _point(_journey(view).support).distance_to(_guide_support(view)) < 0.01,
		"Changing viewport during a run keeps one clock and retargets the same source and destination")
	view.close()
	_check_no_journey(view, "Closing cancels the trajectory and acquired rig together")
	view.open(_journey_state(9), false)
	_freeze(view)
	_check_no_journey(view, "Returning after close cannot resurrect cancelled travel")
	view.configure(_journey_state(11), false)
	_freeze(view)
	_check_no_journey(view, "A noncontiguous progress update cannot fabricate a run across missing stages")
	view.configure(_journey_state(10), false)
	_freeze(view)
	_check_no_journey(view, "A lower saved frontier cannot be presented as forward progression")
	view.configure(_journey_state(11, "professional:retail:module03"), false)
	_freeze(view)
	_check_no_journey(view, "Changing learning scope cannot inherit the previous context's journey")
	await _start(view, 9)
	view.set_reduced_motion(true)
	_freeze(view)
	_check_no_journey(view, "Enabling reduced motion cancels an active journey")
	check(_guide_support(view).distance_to(_rim(view, 10)) < 0.01,
		"Reduced motion immediately retains the supported next-stage meaning")
	view.configure(_journey_state(10), true)
	_freeze(view)
	_check_no_journey(view, "Reduced-motion progression has no hidden run or airborne timeline")

	await _resize(Vector2i(1366, 768))
	await _start(view, 5)
	_check_continuity(view, 5)
	await _start(view, 5)
	_check_landing_handoff(view)
	await _start(view, 98)
	check(_journey(view).active and _journey(view).from == 98 and _journey(view).to == 99,
		"Clearing stage 98 still has a valid journey to the existing final stage")
	_check_continuity(view, 98)
	check(view.snapshot().guide.stage == 99 and view.snapshot().guide.visible,
		"The last valid landing retains Pip on the stage 99 frontier")
	await _check_wardrobes(view)
	view.open(_journey_state(98), false)
	_freeze(view)
	view.configure(_journey_state(99), false)
	_freeze(view)
	_check_no_journey(view, "Clearing the final stage cannot create a stage 100 journey")
	check(not view.snapshot().guide.visible, "A completed campaign has no false next-stage companion")
	await _capture_motion(view, 5, Vector2i(1366, 768), "desktop-stage-5-6")
	await _capture_motion(view, 9, Vector2i(393, 852), "phone-stage-9-10")
	view.close()
	_holder.free()
	print("Word Jelly map journey: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
