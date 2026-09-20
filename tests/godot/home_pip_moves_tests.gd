extends SceneTree

const Moves = preload("res://scripts/pip_loading_moves.gd")
const REACTIONS := ["jump", "shy", "bonk"]

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
	root.size = Vector2i(420, 340)
	_check_articulated_moves()
	var duck = load("res://scripts/duck_mascot.gd").new()
	root.add_child(duck)
	duck.position = Vector2(100, 80)
	duck.size = Vector2(112, 112)
	_check_home_timing(duck)
	_check_home_gates(duck)
	_check_explicit_preemption(duck)
	_check_real_taps(duck)
	duck.free()
	print("Home Pip moves: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _same_pose(first: Array, second: Array, tolerance: float = 0.001) -> bool:
	if first.size() != 6 or second.size() != 6: return false
	for index in range(6):
		for point in [Vector2.ZERO, Vector2(120, 0), Vector2(0, 120)]:
			if (first[index] * point).distance_to(second[index] * point) > tolerance:
				return false
	return true


func _cycle_distance(first: float, second: float, period: float) -> float:
	return absf(fposmod(first - second + period * 0.5, period) - period * 0.5)


func _check_articulated_moves() -> void:
	var neutral: Array[Transform2D] = []
	for index in range(6): neutral.append(Transform2D.IDENTITY)
	check(_same_pose(Moves.dance(0), neutral), "The Home dance begins in Pip's existing complete resting pose")
	check(_same_pose(Moves.dance(0.73), Moves.dance(0.73 + 5.28))
		and _same_pose(Moves.dance(5.28 - 0.00001), Moves.dance(0.00001), 0.05),
		"The 5.28-second dance repeats continuously without a pose jump at the seam")
	var planted := true
	var finite := true
	var leftmost := 1000.0
	var rightmost := -1000.0
	for index in range(241):
		var pose: Array[Transform2D] = Moves.dance(index * 5.28 / 240.0)
		planted = planted and (pose[4] * Vector2(24, 110)).distance_to(Vector2(24, 110)) < 0.001
		planted = planted and (pose[5] * Vector2(99, 111)).distance_to(Vector2(99, 111)) < 0.001
		for transform in pose:
			finite = finite and transform.x.is_finite() and transform.y.is_finite() and transform.origin.is_finite()
			finite = finite and transform.determinant() > 0.5
		var body_center: Vector2 = pose[0] * Vector2(61, 98)
		leftmost = minf(leftmost, body_center.x)
		rightmost = maxf(rightmost, body_center.x)
	check(planted, "Both outside toes stay planted through the entire hip-sway routine")
	check(finite and leftmost < 56 and rightmost > 66,
		"The torso visibly shifts its weight in both directions without collapsed or invalid limb transforms")
	var left_raise: Array[Transform2D] = Moves.dance(0.44)
	var right_raise: Array[Transform2D] = Moves.dance(1.32)
	check(absf(left_raise[2].get_rotation()) > 1.5 and absf(left_raise[3].get_rotation()) < 0.05
		and absf(right_raise[3].get_rotation()) > 1.5 and absf(right_raise[2].get_rotation()) < 0.05,
		"The opening beats raise the left and right wing separately before the hip dance")
	var static_poses: Array = []
	for kind in REACTIONS:
		check(_same_pose(Moves.reaction(kind, 0), neutral) and _same_pose(Moves.reaction(kind, 1), neutral),
			kind + " begins and finishes in the resting silhouette")
		var still: Array[Transform2D] = Moves.reaction(kind, 0, true)
		check(not _same_pose(still, neutral) and _same_pose(still, Moves.reaction(kind, 0.6, true))
			and _same_pose(still, Moves.reaction(kind, 1, true)),
			kind + " has an intentional static reduced-motion pose independent of elapsed time")
		check(static_poses.all(func(previous: Array) -> bool: return not _same_pose(still, previous)),
			kind + " remains visually distinct from the other reduced-motion responses")
		static_poses.append(still)
	var jump: Array[Transform2D] = Moves.reaction("jump", 0.5)
	check((jump[0] * Vector2(61, 98)).y < 85 and (jump[4] * Vector2(24, 110)).y < 100
		and (jump[5] * Vector2(99, 111)).y < 100, "Jump lifts Pip's body and both feet off the floor")
	var shy: Array[Transform2D] = Moves.reaction("shy", 0.2)
	check((shy[3] * Vector2(100, 90)).y < 55 and absf(shy[1].get_rotation()) > 0.08,
		"The shy response brings a wing to the tilted head")
	check((Moves.reaction("bonk", 0.16)[0] * Vector2(61, 98)).x > 64
		and (Moves.reaction("bonk", 0.36)[0] * Vector2(61, 98)).x < 58,
		"The bonk response visibly recoils and rebounds in opposite directions")


func _advance(duck, seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.000001:
		var step: float = minf(0.05, remaining)
		duck._process(step)
		remaining -= step


func _start_home(duck) -> void:
	duck.show()
	duck.set_idle_paused(false)
	duck.set_reduced_motion(false)
	duck.set_speaking(false)
	duck.set_home_playground(true)
	duck.set_proactive_allowed(true)
	duck.settle()
	_advance(duck, 0.4)
	check(duck._idle_action == "home-dance", "Home starts dancing without any player activation")


func _check_home_timing(duck) -> void:
	_start_home(duck)
	var bounds: Rect2 = duck.get_global_rect()
	var children: int = duck.get_child_count()
	var phase: float = duck._idle_left
	var events: Array[bool] = []
	var on_press := func() -> void: events.append(true)
	duck.pressed.connect(on_press)
	for cycle in range(3):
		_advance(duck, 2.64)
		check(duck._idle_action == "home-dance"
			and _cycle_distance(duck._idle_left, phase - 2.64, 5.28) < 0.001
			and not _same_pose(Moves.dance(5.28 - duck._idle_left), Moves.dance(5.28 - phase)),
			"Home dance loop %d advances its phase and articulated artwork halfway through the routine" % (cycle + 1))
		_advance(duck, 2.64)
		check(duck._idle_action == "home-dance" and _cycle_distance(duck._idle_left, phase, 5.28) < 0.001
			and _same_pose(Moves.dance(5.28 - duck._idle_left), Moves.dance(5.28 - phase)),
			"Home repeats full dance loop %d without inserting the header's long idle wait" % (cycle + 1))
	check(duck.get_global_rect() == bounds and duck.scale == Vector2.ONE and is_zero_approx(duck.rotation)
		and duck.get_child_count() == children and events.is_empty(),
		"Automatic dance moves artwork while keeping the input bounds and child nodes stable, with no synthetic presses")
	duck.note_activity()
	_advance(duck, 0.2)
	check(duck._idle_action.is_empty(), "Meaningful activity pauses Home dancing before its short resume beat")
	_advance(duck, 0.2)
	check(duck._idle_action == "home-dance", "Home dancing resumes after the short quiet beat")
	duck.set_home_playground(false)
	check(duck._idle_action.is_empty() and duck._idle_wait >= 6 and duck._idle_wait <= 9,
		"Leaving Home immediately restores the original six-to-nine-second invitation interval")
	_advance(duck, 5.5)
	check(duck._idle_action.is_empty(), "Ordinary pages do not inherit Home's immediate dancing")
	duck.pressed.disconnect(on_press)


func _check_home_gates(duck) -> void:
	for reason in ["disallowed", "paused", "hidden", "speaking", "reduced"]:
		_start_home(duck)
		match reason:
			"disallowed": duck.set_proactive_allowed(false)
			"paused": duck.set_idle_paused(true)
			"hidden": duck.hide()
			"speaking": duck.set_speaking(true)
			"reduced": duck.set_reduced_motion(true)
		_advance(duck, 12)
		check(duck._idle_action.is_empty(), "The " + reason + " gate interrupts and suppresses every Home dance loop")
		if reason in ["paused", "hidden", "reduced"]:
			check(not duck.is_processing(), reason + " leaves no mascot animation process running")
		match reason:
			"disallowed": duck.set_proactive_allowed(true)
			"paused": duck.set_idle_paused(false)
			"hidden": duck.show()
			"speaking": duck.set_speaking(false)
			"reduced": duck.set_reduced_motion(false)
		_advance(duck, 0.4)
		check(duck._idle_action == "home-dance", "Clearing " + reason + " resumes Home dancing after a short quiet beat")


func _check_explicit_preemption(duck) -> void:
	for kind in ["pet", "catch", "walk", "toy"]:
		_start_home(duck)
		if kind == "walk": duck.set_room_motion("walk")
		elif kind == "toy": duck.perform_trick("bubbles")
		else: duck.react_in_room(kind)
		_advance(duck, 0.2)
		check(duck._idle_action.is_empty()
			and (duck._room_motion == "walk" if kind == "walk" else duck._trick == "bubbles" if kind == "toy" else duck._room_reaction == kind),
			"Explicit " + kind + " feedback immediately replaces the Home dance")
		duck.clear_room_interaction()
		duck.clear_trick()
		duck.note_activity()
		_advance(duck, 0.4)
		check(duck._idle_action == "home-dance", "Home dancing resumes after explicit " + kind + " feedback is free")
	for kind in REACTIONS:
		_start_home(duck)
		duck.react_in_room(kind)
		var duration: float = 1.15 if kind == "shy" else 0.85
		check(is_equal_approx(duck._room_reaction_left, duration) and duck._idle_action.is_empty(),
			kind + " replaces dancing with exactly one complete response")
		_advance(duck, duration - 0.05)
		check(duck._room_reaction == kind and duck._idle_action.is_empty(), kind + " completes before automatic dancing can resume")
		_advance(duck, 0.5)
		check(duck._room_reaction.is_empty() and duck._idle_action == "home-dance", kind + " finishes and returns to the automatic dance")
	duck.set_reduced_motion(true)
	for kind in REACTIONS:
		duck.react_in_room(kind)
		var pose: int = duck.pose
		_advance(duck, 12)
		check(duck._room_reaction == kind and duck.pose == pose and pose != 0
			and is_zero_approx(duck._room_reaction_left) and duck._idle_action.is_empty() and not duck.is_processing(),
			kind + " remains a static response without any dance or animation process under reduced motion")
	duck.set_reduced_motion(false)
	duck.settle()


func _check_real_taps(duck) -> void:
	var stage := Control.new()
	root.add_child(stage)
	stage.size = Vector2(400, 304)
	var slot := Control.new()
	stage.add_child(slot)
	var toy := Button.new()
	stage.add_child(toy)
	var label := Label.new()
	stage.add_child(label)
	var playground = load("res://scripts/pip_playground.gd").new()
	stage.add_child(playground)
	playground.setup(slot, toy, label)
	duck.reparent(slot)
	duck.position = Vector2.ZERO
	duck.size = Vector2(96, 112)
	playground.set_duck(duck)
	playground.layout_room(stage.size)
	_start_home(duck)
	var events: Array[String] = []
	var toy_events: Array[bool] = []
	playground.interaction.connect(func(kind: String, _message: String) -> void: events.append(kind))
	playground.toy_tapped.connect(func() -> void: toy_events.append(true))
	var reactions: Array[String] = []
	var bounds: Rect2 = duck.get_global_rect()
	for method in ["mouse", "touch"]:
		for tap in range(6):
			var before: int = events.size()
			var center: Vector2 = duck.get_global_rect().get_center()
			_pointer(center, true, method)
			check(events.size() == before, "A real " + method + " press waits for release before reacting")
			_pointer(center, false, method)
			var kind: String = duck._room_reaction
			check(events.slice(before) == ["poke"] and kind in REACTIONS and duck._idle_action.is_empty(),
				"A real " + method + " tap interrupts the dance with exactly one loading-page reaction")
			check(is_equal_approx(duck._room_reaction_left, 1.15 if kind == "shy" else 0.85)
				and (reactions.is_empty() or reactions.back() != kind),
				"Rapid " + method + " taps replace the previous reaction without duration stacking or immediate repetition")
			reactions.append(kind)
			_advance(duck, 0.04)
	for start in range(0, 12, 3):
		var bag: Array[String] = reactions.slice(start, start + 3)
		check(REACTIONS.all(func(kind: String) -> bool: return bag.count(kind) == 1),
			"Every three real taps show all three responses once before the bag refills")
	check(toy_events.is_empty() and playground.toy_phase == "idle" and duck.get_global_rect() == bounds,
		"Pip's click responses leave the toy and the mascot hit target unchanged")
	_check_toy_preemption(duck, playground, toy, events, toy_events)
	playground.cancel()
	duck.reparent(root)
	stage.free()


func _check_toy_preemption(duck, playground, toy: Button, events: Array[String], toy_events: Array[bool]) -> void:
	for reduced in [false, true]:
		duck.set_reduced_motion(reduced)
		playground.configure("ball", false, reduced, duck.accent)
		for method in ["mouse", "touch"]:
			for gesture in ["tap", "drag"]:
				playground.cancel()
				var pip_center: Vector2 = duck.get_global_rect().get_center()
				_pointer(pip_center, true, method)
				_pointer(pip_center, false, method)
				var context := "%s %s with reduced motion %s" % [method, gesture, reduced]
				check(duck._room_reaction in REACTIONS and playground.toy_phase == "idle" and playground.motion_kind.is_empty(),
					context + " begins with an active Pip response and the currently equipped toy at rest")
				var before: int = events.size()
				var before_taps: int = toy_events.size()
				var toy_center: Vector2 = toy.get_global_rect().get_center()
				_pointer(toy_center, true, method)
				check(duck._room_reaction.is_empty() and is_zero_approx(duck._room_reaction_left)
					and playground._gesture == "toy" and events.size() == before and toy_events.size() == before_taps,
					context + " immediately clears the prior Pip response on toy press while retaining that same pointer")
				if gesture == "tap":
					_pointer(toy_center, false, method)
					check(toy_events.size() == before_taps + 1 and events.size() == before
						and playground.toy_phase == "idle" and playground._pointer == -1,
						context + " releases as exactly one toy tap without a throw or a second Pip response")
				else:
					var end: Vector2 = toy_center + Vector2(-70, -25)
					var previous := toy_center
					for step in range(1, 5):
						var point: Vector2 = toy_center.lerp(end, step / 4.0)
						_motion(point, point - previous, method)
						previous = point
					check(playground.toy_phase == "drag" and playground._gesture == "toy"
						and duck._room_reaction.is_empty() and toy_events.size() == before_taps,
						context + " continues directly from the original press into a held toy drag")
					_pointer(end, false, method)
					check(events.slice(before).count("throw") == 1 and toy_events.size() == before_taps
						and playground._pointer == -1,
						context + " releases that same gesture as one throw without an extra toy tap")
					check((not playground.flight_active and playground.toy_phase == "idle" and events.slice(before).count("catch") == 1)
						if reduced else (playground.flight_active and playground.toy_phase == "flying"),
						context + " preserves immediate reduced-motion completion or the normal animated flight")
	playground.cancel()
	duck.set_reduced_motion(false)


func _pointer(point: Vector2, pressed: bool, method: String) -> void:
	var event: InputEvent
	if method == "touch":
		event = InputEventScreenTouch.new()
		event.index = 0
	else:
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.global_position = point
	event.position = point
	event.pressed = pressed
	root.push_input(event, true)


func _motion(point: Vector2, relative: Vector2, method: String) -> void:
	var event: InputEvent
	if method == "touch":
		event = InputEventScreenDrag.new()
		event.index = 0
	else:
		event = InputEventMouseMotion.new()
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		event.global_position = point
	event.position = point
	event.relative = relative
	root.push_input(event, true)
