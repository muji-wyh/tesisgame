extends SceneTree

const REACTIONS := ["high-five", "peekaboo", "flutter"]

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(360, 300)
	var duck = load("res://scripts/duck_mascot.gd").new()
	root.add_child(duck)
	duck.position = Vector2(100, 70)
	duck.size = Vector2(112, 112)
	duck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	duck.set_process(false)
	_check_direct_reactions(duck)
	var proactive_ready := _check_proactive_contract(duck)
	if proactive_ready:
		_check_idle_timing(duck)
		_check_activity_preemption(duck)
		_check_idle_suppression(duck)
	if DisplayServer.get_name() != "headless":
		await _check_drawn_reactions(duck)
		if proactive_ready:
			await _check_drawn_invitations(duck)
	duck.free()
	print("Proactive Pip: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _advance(duck, seconds: float) -> void:
	for step in range(ceili(seconds / 0.05)):
		duck._process(0.05)


func _check_direct_reactions(duck) -> void:
	duck.set_growth_level(12)
	var original_rect: Rect2 = duck.get_global_rect()
	var children: int = duck.get_child_count()
	var captions: Array[String] = []
	for kind in REACTIONS:
		duck.settle()
		var caption: String = duck.perform_trick(kind)
		check(not caption.is_empty() and caption.length() < 65 and not captions.has(caption),
			kind + " returns its own short English caption")
		captions.append(caption)
		check(duck._idle_action == kind and duck._idle_left > 0.0 and duck._idle_left <= 2.5,
			kind + " immediately begins one finite intentional visual reaction")
		check(duck.pose != 0, kind + " has a readable non-resting expression immediately")
		var duration: float = duck._idle_left
		duck._process(0.2)
		check(duck._idle_action == kind and duck._idle_left < duration,
			kind + " visibly persists while advancing toward its end")
		for press in range(24):
			duck.perform_trick(kind)
		check(duck._idle_left <= duration, kind + " repeated taps preserve the current action without stacking")
		var stable_bounds := true
		for step in range(52):
			duck._process(0.05)
			stable_bounds = stable_bounds and duck.get_global_rect() == original_rect
			stable_bounds = stable_bounds and duck.scale == Vector2.ONE and is_zero_approx(duck.rotation)
			stable_bounds = stable_bounds and duck.get_child_count() == children
		check(duck._idle_action.is_empty() and is_zero_approx(duck._idle_left),
			kind + " removes transient artwork by itself")
		check(stable_bounds,
			kind + " never moves the Button bounds or creates effect/audio nodes")
	duck.settle()
	duck.perform_trick("high-five")
	check(duck.perform_trick("unknown") == "" and duck._idle_action == "high-five",
		"An unknown reaction cannot interrupt a valid explicit high five")
	duck.set_reduced_motion(true)
	for kind in REACTIONS:
		var caption: String = duck.perform_trick(kind)
		var initial_pose: int = duck.pose
		_advance(duck, 20.0)
		check(not caption.is_empty() and duck._idle_action == kind and duck.pose == initial_pose
			and duck.pose != 0 and is_zero_approx(duck._idle_left) and not duck.is_processing(),
			kind + " remains an intentional static pose and caption under reduced motion")
	duck.settle()
	check(duck._idle_action.is_empty(), "Reduced-motion new trick artwork still supports explicit cleanup")
	duck.set_reduced_motion(false)
	duck.settle()


func _check_proactive_contract(duck) -> bool:
	duck.set_growth_level(3)
	duck.settle()
	check(not _observe_idle(duck, 40.0), "Unsolicited invitations are disabled by default")
	check(duck.has_method("note_activity"), "Pip exposes note_activity for meaningful user input")
	check(duck.has_method("set_proactive_allowed"), "Pip exposes a separate proactive allowance gate")
	return duck.has_method("note_activity") and duck.has_method("set_proactive_allowed")


func _observe_idle(duck, seconds: float) -> bool:
	var observed := false
	for step in range(ceili(seconds / 0.05)):
		duck._process(0.05)
		observed = observed or not duck._idle_action.is_empty()
	return observed


func _wait_for_invitation(duck) -> float:
	for step in range(500):
		duck.set_proactive_allowed(true)
		duck.set_idle_paused(false)
		duck.set_speaking(false)
		duck.set_reduced_motion(false)
		duck._process(0.05)
		if not duck._idle_action.is_empty():
			return (step + 1) * 0.05
	return -1.0


func _finish_invitation(duck) -> float:
	var original_rect: Rect2 = duck.get_global_rect()
	var children: int = duck.get_child_count()
	var stable_bounds := true
	for step in range(80):
		duck._process(0.05)
		stable_bounds = stable_bounds and duck.get_global_rect() == original_rect
		stable_bounds = stable_bounds and duck.scale == Vector2.ONE and is_zero_approx(duck.rotation)
		stable_bounds = stable_bounds and duck.get_child_count() == children
		if duck._idle_action.is_empty():
			check(stable_bounds, "Every invitation frame preserves input bounds and creates no effect/audio nodes")
			return (step + 1) * 0.05
	return -1.0


func _is_quiet_interval(seconds: float) -> bool:
	# Allow one 50 ms observation step at the upper boundary.
	return seconds >= 6.0 and seconds <= 9.05


func _start_invitation(duck) -> void:
	duck.settle()
	duck.set_proactive_allowed(true)
	duck.note_activity()
	check(_is_quiet_interval(_wait_for_invitation(duck)), "A fresh invitation waits six to nine quiet seconds")


func _check_idle_timing(duck) -> void:
	var original_rect: Rect2 = duck.get_global_rect()
	var children: int = duck.get_child_count()
	var events: Array[String] = []
	var record_press := func() -> void: events.append("pressed")
	duck.pressed.connect(record_press)
	duck.settle()
	duck.set_proactive_allowed(true)
	duck.note_activity()
	var wait_before: float = duck._idle_wait
	_advance(duck, 2.0)
	var wait_after: float = duck._idle_wait
	for refresh in range(40):
		duck.set_proactive_allowed(true)
		duck.set_idle_paused(false)
		duck.set_speaking(false)
		duck.set_reduced_motion(false)
	check(wait_before >= 6.0 and wait_before <= 9.0 and is_equal_approx(wait_after, wait_before - 2.0)
		and is_equal_approx(duck._idle_wait, wait_after),
		"Unchanged frame-by-frame setters do not restart or advance the idle interval")
	duck.note_activity()
	var gestures: Array[String] = []
	for invitation in range(4):
		var waited := _wait_for_invitation(duck)
		check(_is_quiet_interval(waited),
			"Invitation %d starts after six to nine quiet seconds, including after the previous one ends" % invitation)
		if waited < 0.0:
			break
		var kind: String = duck._idle_action
		gestures.append(kind)
		check(not duck._growth_action_manual
			and is_zero_approx(duck.reaction_left) and not duck.speaking,
			"An invitation stays separate from intentional feedback and speaking")
		var duration := _finish_invitation(duck)
		var expected_seconds := 1.8
		check(absf(duration - expected_seconds) <= 0.051
			and duck._idle_wait >= 6.0 and duck._idle_wait <= 9.0,
			kind + " completes its bounded routine, then starts a fresh six to nine second cooldown")
	check(gestures == ["wave", "wave", "wave", "wave"],
		"The initial companion repeats only its first unlocked wave")
	check(events.is_empty() and duck.get_child_count() == children,
		"Idle activity emits no activation and creates no audio, speech or effect nodes")
	check(duck.get_global_rect() == original_rect and duck.scale == Vector2.ONE and is_zero_approx(duck.rotation),
		"The entire quiet cycle preserves the Button's exact input bounds")
	duck.pressed.disconnect(record_press)
	duck.note_activity()
	duck._process(60.0)
	check(duck._idle_action.is_empty() and _is_quiet_interval(_wait_for_invitation(duck)),
		"A delayed engine frame cannot catch up or immediately replay missed invitations")
	duck.note_activity()


func _check_activity_preemption(duck) -> void:
	duck.set_growth_level(12)
	_start_invitation(duck)
	duck.note_activity()
	check(duck._idle_action.is_empty() and is_zero_approx(duck._idle_left) and duck.pose == 0
		and duck._idle_wait >= 6.0 and duck._idle_wait <= 9.0,
		"Meaningful activity immediately cancels and settles an invitation")
	check(_is_quiet_interval(_wait_for_invitation(duck)), "Activity restarts a full quiet interval")
	duck.perform_trick("wave")
	var remaining: float = duck._idle_left
	duck.note_activity()
	check(duck._growth_action_manual and duck._idle_action == "wave" and duck._idle_left == remaining,
		"Activity never cancels or restarts a user-requested trick")
	duck.set_proactive_allowed(false)
	check(duck._idle_action == "wave" and duck._idle_left == remaining,
		"Closing the proactive gate cannot cancel unrelated explicit artwork")
	duck.settle()
	duck.react("happy")
	remaining = duck.reaction_left
	duck.note_activity()
	check(duck.pose == 3 and duck.reaction_left == remaining,
		"Activity preserves unrelated ordinary feedback and its remaining duration")
	duck.set_reduced_motion(true)
	duck.react("happy")
	var face: String = duck.expression_name()
	remaining = duck.reaction_left
	duck.note_activity()
	duck.set_proactive_allowed(true)
	check(duck.pose == 3 and duck.expression_name() == face and duck.reaction_left == remaining,
		"Activity and allowance changes preserve the static reduced-motion face and its deadline")
	duck._process(0.3)
	check(duck.pose == 3 and duck.expression_name() == face and duck.reaction_left > 0.0,
		"Reduced-motion greeting feedback keeps one still expression during its finite interval")
	duck._process(remaining)
	check(is_zero_approx(duck.reaction_left) and duck.expression_name() == "neutral" and not duck.is_processing(),
		"The reduced-motion greeting expires without leaving stale artwork or a processing loop")
	duck.set_reduced_motion(false)
	for kind in REACTIONS:
		_start_invitation(duck)
		duck.perform_trick(kind)
		check(duck._growth_action_manual and duck._idle_action == kind,
			kind + " immediately replaces an invitation with an intentional reaction")
		duck.note_activity()
		check(duck._idle_action == kind, kind + " survives input notification after the deliberate action")
	duck.settle()


func _check_idle_suppression(duck) -> void:
	for reason in ["disallowed", "paused", "hidden", "speaking", "reduced"]:
		_start_invitation(duck)
		match reason:
			"disallowed": duck.set_proactive_allowed(false)
			"paused": duck.set_idle_paused(true)
			"hidden": duck.hide()
			"speaking": duck.set_speaking(true)
			"reduced": duck.set_reduced_motion(true)
		check(duck._idle_action.is_empty() and is_zero_approx(duck._idle_left),
			reason + " immediately removes unsolicited motion and overlays")
		check(not _observe_idle(duck, 40.0), reason + " cannot accumulate or perform invitations")
		match reason:
			"disallowed": duck.set_proactive_allowed(true)
			"paused": duck.set_idle_paused(false)
			"hidden": duck.show()
			"speaking": duck.set_speaking(false)
			"reduced": duck.set_reduced_motion(false)
		check(_is_quiet_interval(_wait_for_invitation(duck)), reason + " resumes with a fresh quiet interval")
	_start_invitation(duck)
	duck.react("happy")
	check(duck._idle_action.is_empty() and duck.pose == 3 and duck.reaction_left > 0.0,
		"Ordinary feedback takes priority over the unsolicited invitation")
	duck._process(0.2)
	check(duck._idle_action.is_empty() and duck.reaction_left > 0.0,
		"Feedback never overlaps an invitation")
	duck.settle()
	duck.set_proactive_allowed(false)


func _capture(duck) -> PackedByteArray:
	duck.set_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	return image.get_region(Rect2i(duck.get_global_rect().grow(12.0))).get_data()


func _check_drawn_reactions(duck) -> void:
	duck.settle()
	var resting: PackedByteArray = await _capture(duck)
	var drawings: Array[PackedByteArray] = []
	for kind in REACTIONS:
		duck.perform_trick(kind)
		duck._process(0.31)
		var early: PackedByteArray = await _capture(duck)
		check(not early.is_empty() and early != resting and not drawings.has(early),
			kind + " produces distinctive nonzero sprite/overlay pixels, not only a caption")
		drawings.append(early)
		_advance(duck, 0.68)
		check(await _capture(duck) != early, kind + " has an actual bounded visual progression")
		duck.settle()
	duck.set_reduced_motion(true)
	drawings.clear()
	for kind in REACTIONS:
		duck.perform_trick(kind)
		var image: PackedByteArray = await _capture(duck)
		check(image != resting,
			kind + " uses the calm happy reduced-motion illustration")
		drawings.append(image)
		_advance(duck, 4.0)
		check(await _capture(duck) == image, kind + " reduced-motion artwork does not animate")
	duck.settle()
	duck.set_reduced_motion(false)


func _check_drawn_invitations(duck) -> void:
	duck.set_growth_level(12)
	duck.settle()
	var resting: PackedByteArray = await _capture(duck)
	var seen: Array[String] = []
	var actions: Array[String] = duck.growth_actions()
	for invitation in range(actions.size()):
		_start_invitation(duck)
		var kind: String = duck._idle_action
		var duration: float = duck._idle_duration()
		_advance(duck, duration * 0.25)
		var pixels: PackedByteArray = await _capture(duck)
		check(not pixels.is_empty() and pixels != resting,
			kind + " invitation uses the growth stage's real articulated artwork")
		seen.append(kind)
		var frames: Array[PackedByteArray] = [pixels]
		for sample in range(2):
			_advance(duck, duration * 0.2)
			var next_frame: PackedByteArray = await _capture(duck)
			check(duck._idle_action == kind and not next_frame.is_empty()
				and next_frame != resting and not frames.has(next_frame),
				kind + " visibly advances throughout its finite invitation")
			frames.append(next_frame)
		duck.note_activity()
		check(await _capture(duck) == resting, "Activity removes unsolicited " + kind + " artwork immediately")
	check(actions.all(func(kind: String) -> bool: return seen.has(kind)),
		"Rendered validation covers every unlocked action at the final growth stage")
	duck.set_proactive_allowed(false)
