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
		await _check_drawn_room_reactions(duck)
		if proactive_ready:
			await _check_drawn_invitations(duck)
	if proactive_ready:
		_check_playground(duck)
	duck.free()
	print("Proactive Pip: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _advance(duck, seconds: float) -> void:
	for step in range(ceili(seconds / 0.05)):
		duck._process(0.05)


func _check_direct_reactions(duck) -> void:
	var original_rect: Rect2 = duck.get_global_rect()
	var children: int = duck.get_child_count()
	var captions: Array[String] = []
	for kind in REACTIONS:
		duck.settle()
		var caption: String = duck.perform_trick(kind)
		check(not caption.is_empty() and caption.length() < 65 and not captions.has(caption),
			kind + " returns its own short English caption")
		captions.append(caption)
		check(duck._trick == kind and duck._trick_left > 0.0 and duck._trick_left <= 2.5,
			kind + " immediately begins one finite intentional visual reaction")
		check(duck.pose != 0, kind + " has a readable non-resting expression immediately")
		var duration: float = duck._trick_left
		duck._process(0.2)
		check(duck._trick == kind and duck._trick_left < duration,
			kind + " visibly persists while advancing toward its end")
		for press in range(24):
			duck.perform_trick(kind)
		check(duck._trick_left <= duration, kind + " repeated taps replace rather than stack")
		var stable_bounds := true
		for step in range(52):
			duck._process(0.05)
			stable_bounds = stable_bounds and duck.get_global_rect() == original_rect
			stable_bounds = stable_bounds and duck.scale == Vector2.ONE and is_zero_approx(duck.rotation)
			stable_bounds = stable_bounds and duck.get_child_count() == children
		check(duck._trick.is_empty() and is_zero_approx(duck._trick_left),
			kind + " removes transient artwork by itself")
		check(stable_bounds,
			kind + " never moves the Button bounds or creates effect/audio nodes")
	duck.perform_trick("high-five")
	check(duck.perform_trick("unknown") == "" and duck._trick == "high-five",
		"An unknown reaction cannot interrupt a valid explicit high five")
	duck.set_reduced_motion(true)
	for kind in REACTIONS:
		var caption: String = duck.perform_trick(kind)
		var initial_pose: int = duck.pose
		_advance(duck, 20.0)
		check(not caption.is_empty() and duck._trick == kind and duck.pose == initial_pose
			and duck.pose != 0 and is_zero_approx(duck._trick_left) and not duck.is_processing(),
			kind + " remains an intentional static pose and caption under reduced motion")
	duck.clear_trick()
	check(duck._trick.is_empty(), "Reduced-motion new trick artwork still supports explicit cleanup")
	duck.set_reduced_motion(false)
	duck.settle()


func _check_proactive_contract(duck) -> bool:
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
	for step in range(60):
		duck._process(0.05)
		if duck._idle_action.is_empty():
			return (step + 1) * 0.05
	return -1.0


func _start_invitation(duck) -> void:
	duck.settle()
	duck.set_proactive_allowed(true)
	duck.note_activity()
	check(_wait_for_invitation(duck) >= 12.0, "A fresh invitation waits for genuine inactivity")


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
	check(wait_before >= 12.0 and is_equal_approx(wait_after, wait_before - 2.0)
		and is_equal_approx(duck._idle_wait, wait_after),
		"Unchanged frame-by-frame setters do not restart or advance the idle interval")
	duck.note_activity()
	var gestures: Array[String] = []
	for invitation in range(7):
		var waited := _wait_for_invitation(duck)
		check(waited >= 12.0 and waited <= 20.0,
			"Invitation %d requires at least twelve quiet seconds, including after the previous one ends" % invitation)
		if waited < 0.0:
			break
		gestures.append(duck._idle_action)
		check(duck._trick.is_empty() and duck._room_reaction.is_empty()
			and is_zero_approx(duck.reaction_left) and not duck.speaking,
			"An invitation stays separate from intentional feedback and speaking")
		var duration := _finish_invitation(duck)
		check(duration > 0.0 and duration <= 2.5 and duck._idle_wait >= 12.0,
			"An invitation settles after one short gesture, then starts a fresh cooldown")
	check(gestures.slice(0, 3) == ["wave", "high-five", "peekaboo"],
		"The quiet cycle offers a wave, a high five and a peek rather than constant bouncing")
	check(["look", "stretch", "preen", "hop"].all(func(kind: String) -> bool: return gestures.has(kind)),
		"The extended quiet cycle retains Pip's existing idle repertoire")
	check(events.is_empty() and duck.get_child_count() == children,
		"Idle activity emits no activation and creates no audio, speech or effect nodes")
	check(duck.get_global_rect() == original_rect and duck.scale == Vector2.ONE and is_zero_approx(duck.rotation),
		"The entire quiet cycle preserves the Button's exact input bounds")
	duck.pressed.disconnect(record_press)
	duck.note_activity()
	duck._process(60.0)
	check(duck._idle_action.is_empty() and _wait_for_invitation(duck) >= 12.0,
		"A delayed engine frame cannot catch up or immediately replay missed invitations")
	duck.note_activity()


func _check_activity_preemption(duck) -> void:
	_start_invitation(duck)
	duck.note_activity()
	check(duck._idle_action.is_empty() and is_zero_approx(duck._idle_left) and duck.pose == 0
		and duck._idle_wait >= 12.0, "Meaningful activity immediately cancels and settles an invitation")
	check(_wait_for_invitation(duck) >= 12.0, "Activity restarts a full quiet interval")
	duck.perform_trick("snack")
	var remaining: float = duck._trick_left
	duck.note_activity()
	check(duck._idle_action.is_empty() and duck._trick == "snack" and duck._trick_left == remaining,
		"Activity never cancels or restarts a user-requested trick")
	duck.set_proactive_allowed(false)
	check(duck._trick == "snack" and duck._trick_left == remaining,
		"Closing the proactive gate cannot cancel unrelated explicit artwork")
	duck.clear_trick()
	duck.react("happy")
	remaining = duck.reaction_left
	duck.note_activity()
	check(duck.pose == 3 and duck.reaction_left == remaining,
		"Activity preserves unrelated ordinary feedback and its remaining duration")
	duck.set_reduced_motion(true)
	duck.react("happy")
	duck.note_activity()
	duck.set_proactive_allowed(true)
	check(duck.pose == 3 and not duck.is_processing(),
		"Activity and allowance changes preserve static reduced-motion feedback")
	duck.set_reduced_motion(false)
	for kind in REACTIONS:
		_start_invitation(duck)
		duck.perform_trick(kind)
		check(duck._idle_action.is_empty() and duck._trick == kind,
			kind + " immediately replaces an invitation with an intentional reaction")
		duck.note_activity()
		check(duck._trick == kind, kind + " survives input notification after the deliberate action")
	duck.settle()


func _check_idle_suppression(duck) -> void:
	for reason in ["disallowed", "paused", "hidden", "speaking", "reduced", "walking"]:
		_start_invitation(duck)
		match reason:
			"disallowed": duck.set_proactive_allowed(false)
			"paused": duck.set_idle_paused(true)
			"hidden": duck.hide()
			"speaking": duck.set_speaking(true)
			"reduced": duck.set_reduced_motion(true)
			"walking": duck.set_room_motion("walk")
		check(duck._idle_action.is_empty() and is_zero_approx(duck._idle_left),
			reason + " immediately removes unsolicited motion and overlays")
		check(not _observe_idle(duck, 40.0), reason + " cannot accumulate or perform invitations")
		match reason:
			"disallowed": duck.set_proactive_allowed(true)
			"paused": duck.set_idle_paused(false)
			"hidden": duck.show()
			"speaking": duck.set_speaking(false)
			"reduced": duck.set_reduced_motion(false)
			"walking": duck.clear_room_interaction()
		check(_wait_for_invitation(duck) >= 12.0, reason + " resumes with a fresh quiet interval")
	_start_invitation(duck)
	duck.react("happy")
	check(duck._idle_action.is_empty() and duck.pose == 3 and duck.reaction_left > 0.0,
		"Ordinary feedback takes priority over the unsolicited invitation")
	duck._process(0.2)
	check(duck._idle_action.is_empty() and duck.reaction_left > 0.0,
		"Feedback never overlaps an invitation")
	_start_invitation(duck)
	duck.react_in_room("pet")
	check(duck._idle_action.is_empty() and duck._room_reaction == "pet" and duck.pose == 2,
		"A room interaction immediately settles an invitation")
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
		duck.clear_trick()
	duck.set_reduced_motion(true)
	drawings.clear()
	for kind in REACTIONS:
		duck.perform_trick(kind)
		var image: PackedByteArray = await _capture(duck)
		check(image != resting and not drawings.has(image),
			kind + " has its own reduced-motion illustration")
		drawings.append(image)
		_advance(duck, 4.0)
		check(await _capture(duck) == image, kind + " reduced-motion artwork does not animate")
	duck.settle()
	duck.set_reduced_motion(false)


func _check_drawn_invitations(duck) -> void:
	duck.settle()
	var resting: PackedByteArray = await _capture(duck)
	var seen: Array[String] = []
	for invitation in range(7):
		_start_invitation(duck)
		var kind: String = duck._idle_action
		duck._process(0.31)
		var pixels: PackedByteArray = await _capture(duck)
		if kind in ["wave", "high-five", "peekaboo"]:
			seen.append(kind)
			check(pixels != resting, kind + " invitation uses real sprite/overlay artwork")
		duck.note_activity()
		check(await _capture(duck) == resting, "Activity removes all unsolicited " + kind + " pixels immediately")
	check(seen.size() == 3, "Rendered validation covers all three invitation illustrations")
	duck.set_proactive_allowed(false)


func _check_drawn_room_reactions(duck) -> void:
	duck.settle()
	var resting: PackedByteArray = await _capture(duck)
	for reduced in [false, true]:
		duck.set_reduced_motion(reduced)
		var drawings: Array[PackedByteArray] = []
		for kind in REACTIONS:
			duck.react_in_room(kind)
			duck._process(0.19)
			var early: PackedByteArray = await _capture(duck)
			check(early != resting and not drawings.has(early),
				kind + " room feedback has distinct real artwork with reduced motion " + str(reduced))
			drawings.append(early)
			_advance(duck, 0.5)
			var later: PackedByteArray = await _capture(duck)
			check(later == early if reduced else later != early,
				kind + " room artwork respects the selected motion preference")
			duck.clear_room_interaction()
			check(await _capture(duck) == resting, kind + " room artwork is completely removed by cleanup")
	duck.set_reduced_motion(false)
	duck.settle()


func _check_playground(duck) -> void:
	var stage := Control.new()
	stage.size = Vector2(360, 300)
	root.add_child(stage)
	var slot := Control.new()
	stage.add_child(slot)
	var toy := Button.new()
	stage.add_child(toy)
	var label := Label.new()
	label.text = "ball"
	stage.add_child(label)
	var playground = load("res://scripts/pip_playground.gd").new()
	stage.add_child(playground)
	playground.setup(slot, toy, label)
	playground.set_duck(duck)
	duck.reparent(slot)
	duck.position = Vector2.ZERO
	duck.size = Vector2(96, 96)
	playground.layout_room(stage.size)
	var reports: Array[String] = []
	var captions: Array[String] = []
	var starts: Array[bool] = []
	var toy_taps: Array[bool] = []
	playground.interaction.connect(func(kind: String, message: String) -> void:
		reports.append(kind)
		captions.append(message))
	playground.interaction_started.connect(func() -> void: starts.append(true))
	playground.toy_tapped.connect(func() -> void: toy_taps.append(true))
	var bounds: Rect2 = duck.get_global_rect()
	for tap in range(12):
		var count_before := reports.size()
		playground.poke()
		var expected: String = ["poke", "high-five", "peekaboo", "flutter"][tap % 4]
		check(reports.slice(count_before) == ["poke"] and playground.interaction_kind == "poke"
			and duck._room_reaction == expected and duck._trick.is_empty() and duck.pose != 0,
			"Room tap %d keeps the Poke event contract while visibly responding with %s" % [tap + 1, expected])
		check(duck._room_reaction_left > 0.0 and duck._room_reaction_left <= 1.1,
			expected + " remains one short room response")
		_advance(duck, 2.0)
		check(duck._room_reaction.is_empty(), expected + " room artwork cleans itself up")
	check(captions.slice(0, 4).size() == 4 and captions.slice(0, 4).all(
		func(message: String) -> bool: return captions.slice(0, 4).count(message) == 1),
		"Room poke variation has four distinct captions")
	check(captions.slice(0, 4) == captions.slice(4, 8) and captions.slice(4, 8) == captions.slice(8, 12),
		"The room variation repeats a bounded four-step progression without persistence")
	check(duck.get_global_rect() == bounds and playground.toy_phase == "idle",
		"Poke variation never moves the hit target or starts a toy sequence")
	for reduced in [false, true]:
		duck.set_reduced_motion(reduced)
		playground.configure("ball", false, reduced, duck.accent)
		for kind in REACTIONS:
			duck.react_in_room(kind)
			var initial_pose: int = duck.pose
			duck.note_activity()
			check(duck._room_reaction == kind and duck.pose == initial_pose and duck.pose != 0,
				kind + " room feedback survives meaningful activity notification")
			if reduced:
				_advance(duck, 20.0)
				check(duck._room_reaction == kind and is_zero_approx(duck._room_reaction_left)
					and duck.pose == initial_pose and not duck.is_processing(),
					kind + " room response remains static under reduced motion")
			playground.cancel()
			check(duck._room_reaction.is_empty() and duck._trick.is_empty(),
				"Cancel fully clears the room-owned " + kind + " illustration")
	duck.set_reduced_motion(false)
	playground.configure("ball", false, false, duck.accent)
	_check_held_room_gestures(duck, playground, slot, toy)
	playground.cancel()
	playground.configure("ball", true, false, duck.accent)
	var report_count := reports.size()
	var start_count := starts.size()
	var toy_count := toy_taps.size()
	var room_state: Array = [playground.duck_position, playground.target_position,
		playground.toy_phase, toy.position, toy.scale, toy.rotation, label.text]
	playground.toss_to_pip()
	_room_press(playground, toy.get_global_rect().get_center(), true)
	_room_drag(playground, toy.get_global_rect().get_center() - Vector2(70, 25))
	_room_press(playground, toy.get_global_rect().get_center() - Vector2(70, 25), false)
	check(not playground.flight_active and playground.toy_phase == "idle"
		and reports.size() == report_count and starts.size() == start_count and toy_taps.size() == toy_count,
		"Neither a direct toss nor a pointer gesture can activate a locked toy")
	playground.cancel()
	_start_invitation(duck)
	_advance(duck, 90.0)
	check(reports.size() == report_count and starts.size() == start_count and toy_taps.size() == toy_count
		and room_state == [playground.duck_position, playground.target_position,
			playground.toy_phase, toy.position, toy.scale, toy.rotation, label.text],
		"Proactive room activity emits no interaction/status/toy signal and changes no room state or labels")
	playground.configure("ball", false, false, duck.accent)
	playground.pet()
	check(playground.interaction_kind == "pet" and duck._room_reaction == "pet",
		"Pet remains available after richer room pokes")
	playground.call_pip()
	check(not playground.motion_kind.is_empty(), "Call still starts the existing room movement")
	playground.toss_to_pip()
	check(playground.flight_active and playground.toy_phase == "flying",
		"Toss still launches the owned toy using the existing physics")
	playground.cancel()
	duck.reparent(root)
	stage.free()


func _room_press(playground, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	playground._input(event)


func _room_drag(playground, point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	playground._input(event)


func _check_held_room_gestures(duck, playground, slot: Control, toy: Button) -> void:
	for held in ["duck", "toy", "floor"]:
		playground.cancel()
		_start_invitation(duck)
		var point: Vector2 = slot.get_global_rect().get_center() if held == "duck" else toy.get_global_rect().get_center() if held == "toy" else Vector2(180, 284)
		_room_press(playground, point, true)
		check(duck._idle_action.is_empty() and playground.is_processing(),
			"Pressing the " + held + " immediately preempts an invitation and observes the held gesture")
		var invited_while_held := false
		for step in range(500):
			if playground.is_processing():
				playground._process(0.05)
			duck._process(0.05)
			invited_while_held = invited_while_held or not duck._idle_action.is_empty()
		check(not invited_while_held, "Holding the " + held + " cannot trigger an unsolicited invitation")
		_room_press(playground, point, false)
		playground.cancel()
		check(not playground.is_processing() and playground._pointer == -1,
			"Releasing/canceling the " + held + " removes the temporary gesture processing")
		check(_wait_for_invitation(duck) >= 12.0, "After the " + held + " gesture Pip resumes only after a new quiet interval")
	playground.cancel()
	duck.note_activity()
	var waiting: float = duck._idle_wait
	var hover := InputEventMouseMotion.new()
	hover.position = Vector2(180, 270)
	playground._input(hover)
	check(duck._idle_wait == waiting, "Uncaptured hover motion is not meaningful room activity")
