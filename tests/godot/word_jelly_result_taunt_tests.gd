extends SceneTree

const Taunt = preload("res://scripts/word_jelly_result_taunt.gd")
const RewardRoom = preload("res://scripts/pop_reward_room.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _rect(values: Array) -> Rect2:
	return Rect2(values[0], values[1], values[2], values[3])


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(640, 520)
	var room := RewardRoom.new()
	root.add_child(room)
	await process_frame
	for context: Dictionary in [
		{"reason": "danger"},
		{"campaign": {"kind": "main", "outcome": "cleared"}, "reason": "timeout"},
		{"campaign": {"kind": "main", "outcome": "aborted"}, "reason": "home"},
		{"campaign": {"kind": "challenge", "outcome": "finished"}, "reason": "home"},
	]:
		room._result_context = context
		check(not room.wants_result_boss(), "Success, voluntary exits and non-World results cannot trigger a taunt: %s" % context)
	for context: Dictionary in [
		{"campaign": {"kind": "main", "outcome": "timeout"}, "reason": "timeout"},
		{"campaign": {"kind": "main", "outcome": "blocked"}, "reason": "danger"},
		{"campaign": {"kind": "challenge", "outcome": "finished"}, "reason": "danger"},
		{"campaign": {"kind": "challenge", "outcome": "timeout"}, "reason": "timeout"},
	]:
		room._result_context = context
		check(room.wants_result_boss(), "Real numbered and Challenge failures share the same presentation eligibility: %s" % context)
	check(not room._result_boss._actor._loaded, "Eligibility checks never eagerly load the private character")
	room.free()
	await process_frame
	var view := Taunt.new()
	root.add_child(view)
	view.configure_layout(Rect2(20, 20, 300, 320), 1.0)
	check(view.present("fixture:taunt:1", false), "Load the acquired Bramble rig rather than a portrait substitute")
	view.set_active(true)
	var state: Dictionary = view.snapshot()
	check(state.model_loaded and state.clip == "Taunt" and "Taunt" in view._actor.animation_names(),
		"The saved result uses the actual authored skeletal Taunt clip")
	check(view.mouse_filter == Control.MOUSE_FILTER_IGNORE and view.focus_mode == Control.FOCUS_NONE
		and view._image.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and view._effects.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Neither the character nor its effects can take a retry or upgrade gesture")
	var skeleton: Skeleton3D = view._actor._skeleton
	check(skeleton != null and skeleton.find_bone("Middle1.L") >= 0 and skeleton.find_bone("Middle1.R") >= 0,
		"Magic follows the acquired rig's actual palm-base joints")
	view.advance(0.5)
	var before: Dictionary = view.snapshot()
	view.advance(0.5)
	state = view.snapshot()
	check(state.pose_time == 1.0 and state.pose_count > before.pose_count and state.effects > 0.8,
		"The live rig and local effect reach their shared one-second taunt peak")
	check(state.hand_points.size() == 2 and state.hand_points != before.hand_points,
		"Visible hand effects follow deformation, not unrelated fixed screen points")
	for point: Array in state.hand_points:
		check(Rect2(Vector2.ZERO, view.size).encloses(Rect2(Vector2(point[0], point[1]), Vector2.ONE)),
			"Both real palm anchors stay inside the result performance area")
	var meshes: Array[Node] = view._actor._model.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() == 1 and meshes[0] is MeshInstance3D:
		var mesh: MeshInstance3D = meshes[0]
		var wink: int = mesh.find_blend_shape_by_name("Blink.L")
		check(wink >= 0 and mesh.get_blend_shape_value(wink) > 0.9,
			"The peak includes the inspected real one-eye wink")
	else:
		check(false, "Bramble retains the inspected single skinned body")
	var poses: int = state.pose_count
	check(view.present("fixture:taunt:1", false) and view.snapshot().elapsed == 1.0
		and view.snapshot().pose_count == poses,
		"Repeated result, layout and wallet refreshes cannot restart the gesture")
	view.set_active(false)
	view.advance(10.0)
	check(view.snapshot().elapsed == 1.0 and view.snapshot().pose_count == poses
		and view._actor.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"Background and page departure stop both the animation clock and its 3D viewport")
	view.set_active(true)
	view.advance(0.2)
	check(is_equal_approx(float(view.snapshot().elapsed), 1.2), "Resume continues the original performance")
	view.advance(10.0)
	state = view.snapshot()
	check(state.elapsed == Taunt.DURATION and state.pose_time < Taunt.TAUNT_SECONDS and state.effects == 0.0,
		"The finite gesture settles without looping its first pose or a perpetual burst")
	poses = state.pose_count
	for frame in range(120):
		view.advance(0.05)
	check(view.snapshot().pose_count == poses, "An idle result performs no repeated skeletal sampling")
	view.hide()
	view.advance(1.0)
	check(view._actor.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"A hidden result cannot keep rendering a detached Boss viewport")
	view.show()
	check(view.snapshot().elapsed == Taunt.DURATION, "Showing a saved result does not replay its taunt")
	check(view.present("fixture:taunt:2", true, true), "Reduced motion can load a new, positively acknowledged record")
	state = view.snapshot()
	check(state.reduced_motion and state.elapsed == Taunt.DURATION and state.pose_time == Taunt.STEADY_SAMPLE
		and state.caption.begins_with("Nice run!") and state.effects <= 0.16,
		"Reduced motion uses a real still wink and soft light without mocking a new best")
	poses = state.pose_count
	view.advance(1.0)
	check(view.snapshot().pose_count == poses, "Steady mode has no repeated 3D or particle motion")
	view.set_reduced_motion(false)
	view.advance(1.0)
	check(view.snapshot().elapsed == Taunt.DURATION and view.snapshot().effects == 0.0,
		"Changing motion preference does not start a second taunt")
	for factor: float in [0.65, 1.0, 1.5, 2.45, 3.2]:
		for dimensions: Vector2 in [Vector2(300, 260), Vector2(170, 240), Vector2(280, 120), Vector2(248, 130)]:
			view.configure_layout(Rect2(Vector2.ZERO, dimensions / factor), factor)
			var bounds := Rect2(Vector2.ZERO, view.size).grow(0.1)
			var image: Rect2 = _rect(view.snapshot().image_rect)
			check(bounds.encloses(image) and bounds.encloses(view._caption.get_rect()),
				"Real model framing and its short dialogue fit at scale %s, size %s: image=%s, caption=%s, minimum=%s" % [
					factor, dimensions, image, view._caption.get_rect(), view._caption.get_minimum_size()])
			check(not image.grow(-0.02).intersects(view._caption.get_rect()),
				"The gesture never paints through its own readable dialogue")
			for point: Array in view.snapshot().hand_points:
				check(bounds.has_point(Vector2(point[0], point[1])),
					"Resizing preserves actual hand-to-effect ownership")
	check(view.find_children("*", "AudioStreamPlayer", true, false).is_empty(),
		"The persistent result does not layer another laugh over existing defeat or record audio")
	view.reset()
	check(not view.visible and not view.snapshot().active and view.snapshot().round_id.is_empty(),
		"A new result clears ownership and hidden rendering")
	view.free()
	print("Game over Bramble performance: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
