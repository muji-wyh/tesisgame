extends SceneTree

const Celebration = preload("res://scripts/jelly_chest_celebration.gd")
const Flight = preload("res://scripts/chest_reward_flight.gd")
const RewardModel = preload("res://scripts/chest_reward_model.gd")
const ChestModel = preload("res://scripts/chest_model_view.gd")
const Jelly = preload("res://scripts/jelly_match.gd")
const Data = preload("res://scripts/game_data.gd")
const BEFORE = preload("res://assets/chests/energy/closed.png")
const AFTER = preload("res://assets/chests/royal/closed.png")

var checks: int = 0
var failures: int = 0
var heard: Array[Dictionary] = []
var reveals: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1000, 720)
	var view := Celebration.new()
	root.add_child(view)
	view.position = Vector2(24, 60)
	view.size = Vector2(952, 636)
	view.set_chest_anchor(Rect2(20, 16, 72, 72))
	view.cue_requested.connect(func(cue: String) -> void:
		heard.append({"cue": cue, "state": view.snapshot()}))
	view.confetti_requested.connect(func() -> void: reveals.append(view.snapshot()))
	_check_timeline(view)
	_check_queue(view)
	_check_reentry(view)
	_check_reduced_motion(view)
	_check_layouts(view)
	_check_flight_route(view)
	_check_upgrade_containment(view)
	_check_model_lifecycle(view)
	view.clear()
	view.free()
	_check_closed_models()
	_check_owner_lifecycle()
	print("Jelly chest celebration: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _begin(view, previous: int = 0, tier: int = 1, reduced: bool = false) -> void:
	view.clear()
	heard.clear()
	reveals.clear()
	view.reduced_motion = reduced
	view.enqueue(previous, tier, BEFORE, AFTER)


func _check_timeline(view) -> void:
	_begin(view)
	check(view.is_active() and not view.visible and view.snapshot().kind == "synthesis",
		"Synthesis reserves its timeline without obscuring the fragment flight")
	view.advance(Celebration.ARRIVAL_SECONDS - 0.01)
	check(not view.visible and heard.is_empty(), "A fragment gets its entire flight before assembly begins")
	view.advance(0.02)
	check(view.visible and heard.size() == 1 and heard[0].cue == "assemble"
		and is_equal_approx(float(heard[0].state.elapsed), Celebration.ARRIVAL_SECONDS),
		"Assembly sound is published at the precise flight-arrival boundary")
	view.advance(Celebration.REVEAL_SECONDS - 0.02)
	check(not view.snapshot().revealed and heard.size() == 1,
		"The new chest and reward sound wait until the assembly finishes")
	view.advance(0.02)
	check(view.snapshot().revealed and heard.size() == 2 and heard[1].cue == "reward"
		and is_equal_approx(float(heard[1].state.elapsed), Celebration.ARRIVAL_SECONDS + Celebration.REVEAL_SECONDS),
		"The finished chest reveal and reward sound share one exact boundary")
	check(reveals.size() == 1 and reveals[0].kind == "synthesis"
		and is_equal_approx(float(reveals[0].elapsed), Celebration.ARRIVAL_SECONDS + Celebration.REVEAL_SECONDS),
		"The first unlocked chest requests shared paper at its exact reveal boundary")
	view.advance(Celebration.PERFORMANCE_SECONDS - Celebration.REVEAL_SECONDS)
	check(not view.is_active() and not view.visible and heard.size() == 2,
		"A completed synthesis releases the scene without looping its animation")
	view.advance(30.0)
	check(heard.size() == 2 and reveals.size() == 1, "An idle timeline cannot replay reward sound or paper")
	_begin(view, 1, 2)
	var before: Dictionary = view.snapshot()
	for delta: float in [-1.0, 0.0, INF, NAN]:
		view.advance(delta)
	check(view.snapshot() == before and heard.is_empty(), "Invalid clock samples leave queued rewards untouched")
	view.advance(Celebration.ARRIVAL_SECONDS + Celebration.REVEAL_SECONDS + 0.1)
	check(heard.size() == 2
		and is_equal_approx(float(heard[0].state.elapsed), Celebration.ARRIVAL_SECONDS)
		and is_equal_approx(float(heard[1].state.elapsed), Celebration.ARRIVAL_SECONDS + Celebration.REVEAL_SECONDS),
		"A stalled frame still publishes assembly and reveal at their separate authored boundaries")
	check(reveals.size() == 1 and reveals[0].kind == "upgrade" and reveals[0].tier == 2,
		"Upgrade publishes its precise level with one shared screen-overlay request")
	view.reduced_motion = true
	view.reduced_motion = false
	check(reveals.size() == 1, "Changing motion preferences cannot replay an already published milestone")


func _check_queue(view) -> void:
	_begin(view)
	view.enqueue(1, 2, BEFORE, AFTER)
	check(view.snapshot().queued == 2 and view.snapshot().tier == 1,
		"A later upgrade queues behind synthesis without replacing the earned first chest")
	var total: float = Celebration.ARRIVAL_SECONDS + Celebration.PERFORMANCE_SECONDS
	view.advance(total + Celebration.ARRIVAL_SECONDS + 0.05)
	check(view.snapshot().queued == 1 and view.snapshot().tier == 2 and view.snapshot().kind == "upgrade"
		and is_equal_approx(float(view.snapshot().elapsed), Celebration.ARRIVAL_SECONDS + 0.05),
		"Queued upgrades consume only time remaining after the previous presentation")
	check(heard.size() == 3 and heard[0].cue == "assemble" and heard[1].cue == "reward"
		and heard[2].cue == "assemble", "Queue order preserves each chest's own sound sequence")
	view.advance(total)
	check(not view.is_active() and heard.size() == 4 and heard[3].cue == "reward"
		and reveals.size() == 2 and reveals[0].tier == 1 and reveals[1].tier == 2,
		"Each queued milestone completes exactly once")
	view.enqueue(3, 3, BEFORE, AFTER)
	view.enqueue(3, 2, BEFORE, AFTER)
	check(not view.is_active(), "Repeated or regressive tier transitions cannot start a presentation")


func _check_reentry(view) -> void:
	for at: String in ["assemble", "reward"]:
		for replace: bool in [false, true]:
			_begin(view)
			view.enqueue(1, 2, BEFORE, AFTER)
			var interrupt: Callable = func(cue: String) -> void:
				if cue != at:
					return
				view.clear()
				if replace:
					view.enqueue(2, 3, BEFORE, AFTER)
			view.cue_requested.connect(interrupt)
			view.advance(20.0)
			view.cue_requested.disconnect(interrupt)
			check(heard.size() == (1 if at == "assemble" else 2),
				"Clearing during %s prevents every remaining stale cue" % at)
			if replace:
				check(view.snapshot().tier == 3 and view.snapshot().queued == 1
					and is_zero_approx(float(view.snapshot().elapsed)) and not view.visible,
					"A replacement reward starts from its own flight clock after synchronous reentry")
			else:
				check(not view.is_active() and not view.visible,
					"A cleared timeline cannot reactivate a queued old reward")


func _check_reduced_motion(view) -> void:
	_begin(view, 2, 3, true)
	view.advance(Celebration.ARRIVAL_SECONDS - 0.01)
	check(not view.visible, "Reduced motion preserves the fragment arrival gate")
	view.advance(0.02)
	check(view.visible and reveals.is_empty(),
		"Reduced motion shows the static HUD chest without flying paper")
	view.advance(Celebration.REVEAL_SECONDS)
	check(view.snapshot().revealed and reveals.is_empty() and heard.size() == 2,
		"Reduced motion preserves the same reward gate and one sound per milestone")
	var still: Dictionary = view.snapshot().motion
	check(is_zero_approx(float(still.yaw)) and is_zero_approx(float(still.pitch))
		and is_zero_approx(float(still.roll)) and is_zero_approx(float(still.depth))
		and is_equal_approx(float(still.scale), 1.0) and is_equal_approx(float(still.sprite_scale_x), 1.0),
		"Reduced motion removes flight and rotation while retaining the authored chest dimensions")
	view.advance(Celebration.PERFORMANCE_SECONDS)
	check(not view.is_active(), "Static presentation finishes after the same duration")


func _check_layouts(view) -> void:
	_begin(view, 1, 2)
	view.advance(Celebration.ARRIVAL_SECONDS + Celebration.REVEAL_SECONDS + 0.1)
	for dimensions: Vector2 in [Vector2(1366, 600), Vector2(390, 640), Vector2(320, 220), Vector2(844, 235)]:
		view.size = dimensions
		var anchor := Rect2(Vector2(16, 12), Vector2.ONE * minf(72.0, dimensions.y * 0.25))
		view.set_chest_anchor(anchor)
		check(_rect(view.snapshot().anchor).is_equal_approx(anchor),
			"%s retains the supplied HUD location as the flight's return anchor" % dimensions)
	check(view.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and view.find_children("*", "BaseButton", true, false).is_empty(),
		"The HUD celebration cannot capture a game gesture")
	check(view.find_children("*", "Label", true, false).is_empty(),
		"An in-game chest milestone does not add a modal title over the board")


func _rect(values: Array) -> Rect2:
	return Rect2(Vector2(float(values[0]), float(values[1])), Vector2(float(values[2]), float(values[3])))


func _pose_at(view, age: float) -> Dictionary:
	view._elapsed = Celebration.ARRIVAL_SECONDS + age
	view._started = true
	view._revealed = age >= Celebration.REVEAL_SECONDS
	view._sync()
	var pose: Dictionary = view._motion(age)
	var edge: float = minf(view._anchor.size.x, view._anchor.size.y)
	var placement: Dictionary = view._placement(pose, edge, view._anchor.get_center())
	return placement


func _check_flight_route(view) -> void:
	for layout: Dictionary in [
		{"viewport": Vector2i(1000, 720), "position": Vector2(164, 200), "size": Vector2(672, 480), "anchor": Rect2(20, 408, 44, 44)},
		{"viewport": Vector2i(390, 844), "position": Vector2(8, 188), "size": Vector2(374, 640), "anchor": Rect2(20, 580, 36, 36)},
		{"viewport": Vector2i(844, 390), "position": Vector2(80, 80), "size": Vector2(684, 290), "anchor": Rect2(20, 230, 36, 36)},
	]:
		root.size = layout.viewport
		view.position = layout.position
		view.size = layout.size
		view.set_chest_anchor(layout.anchor)
		_check_flight_choreography(view, layout.anchor)
	root.size = Vector2i(1000, 720)
	view.position = Vector2(164, 200)
	view.size = Vector2(672, 480)
	view.set_chest_anchor(Rect2(20, 408, 44, 44))
	_begin(view, 1, 2)
	view.advance(Celebration.ARRIVAL_SECONDS + Flight.TOP_SECONDS * 0.5)
	var elapsed: float = view._elapsed
	var cue_count: int = heard.size()
	root.size = Vector2i(390, 844)
	view.position = Vector2(8, 188)
	view.size = Vector2(374, 640)
	var resized_anchor := Rect2(20, 580, 36, 36)
	view.set_chest_anchor(resized_anchor)
	check(is_equal_approx(view._elapsed, elapsed) and heard.size() == cue_count,
		"A viewport and anchor change during departure cannot restart the clock or its sound")
	var resized_upper: Dictionary = _pose_at(view, Flight.TOP_SECONDS)
	var resized_safe: Rect2 = view._flight_bounds()
	check(absf(float(resized_upper.center.x) - resized_safe.get_center().x) < 0.1
		and float(resized_upper.center.y) < resized_safe.position.y + resized_safe.size.y * 0.4,
		"An in-flight resize keeps the only destination in the resized upper screen")
	var resized_midway: Dictionary = _pose_at(view, Flight.TOP_SECONDS * 0.5)
	var resized_route: Vector2 = Vector2(resized_upper.center) - resized_anchor.get_center()
	var resized_offset: Vector2 = Vector2(resized_midway.center) - resized_anchor.get_center()
	check(absf(resized_offset.cross(resized_route)) / resized_route.length() < 0.1
		and resized_offset.dot(resized_route) > 0.0 and resized_offset.dot(resized_route) < resized_route.length_squared(),
		"The resized upgrade keeps a straight route toward its sole upper destination")
	var resized_arrival: Dictionary = _pose_at(view, Flight.PERFORMANCE_SECONDS)
	check(Vector2(resized_arrival.center).is_equal_approx(resized_anchor.get_center())
		and is_equal_approx(float(resized_arrival.scale), 1.0), "The resized flight returns to the current chest anchor")
	view.hide()
	view.set_chest_anchor(Rect2(22, 578, 36, 36))
	check(not view.visible and not view._flight_surface.is_visible_in_tree(),
		"Updating a hidden celebration anchor cannot reshow its independent screen overlay")
	view.clear()
	root.size = Vector2i(1000, 720)
	view.position = Vector2(24, 60)
	view.size = Vector2(952, 636)


func _check_flight_choreography(view, anchor: Rect2) -> void:
	var safe: Rect2 = view._flight_bounds()
	check(not safe.get_center().is_equal_approx(view.size * 0.5),
		"The flight fixture distinguishes the screen center from a bounded game area's center")
	for previous: int in range(6):
		_begin(view, previous, previous + 1)
		var departure: Dictionary = _pose_at(view, 0.0)
		var upper: Dictionary = _pose_at(view, Flight.TOP_SECONDS)
		var peak: Dictionary = _pose_at(view, Flight.REVEAL_SECONDS)
		var turned: Dictionary = _pose_at(view, Flight.TURN_END)
		var returning: Dictionary = _pose_at(view, lerpf(Flight.RETURN_START, Flight.PERFORMANCE_SECONDS, 0.5))
		var arrived: Dictionary = _pose_at(view, Flight.PERFORMANCE_SECONDS)
		_check_reversible_growth(view, "Tier %d at %s" % [previous + 1, root.size])
		check(Vector2(departure.center).is_equal_approx(anchor.get_center()) and is_equal_approx(float(departure.scale), 1.0),
			"Tier %d departs from its exact chest anchor at the resting size" % (previous + 1))
		check(absf(float(upper.center.x) - safe.get_center().x) < 0.1 and float(upper.center.y) < safe.position.y + safe.size.y * 0.4,
			"Tier %d reaches its only destination in the upper screen" % (previous + 1))
		var route: Vector2 = Vector2(upper.center) - anchor.get_center()
		var last_progress: float = 0.0
		var max_deviation: float = 0.0
		var max_travel_scale: float = 1.0
		var max_yaw: float = 0.0
		var max_pitch: float = 0.0
		var max_roll: float = 0.0
		var max_depth: float = 0.0
		var max_model_weight: float = 0.0
		for step in range(1, 24):
			var outbound: Dictionary = _pose_at(view, Flight.TOP_SECONDS * float(step) / 24.0)
			var offset: Vector2 = Vector2(outbound.center) - anchor.get_center()
			var progress: float = offset.dot(route) / route.length_squared()
			var deviation: float = absf(offset.cross(route)) / route.length()
			check(progress > last_progress and progress < 1.0 and outbound.phase == "depart",
				"Tier %d at %s advances toward its sole upper destination without an intermediate stop" % [previous + 1, root.size])
			max_deviation = maxf(max_deviation, deviation)
			max_travel_scale = maxf(max_travel_scale, float(outbound.scale))
			max_yaw = maxf(max_yaw, absf(float(outbound.yaw)))
			max_pitch = maxf(max_pitch, absf(float(outbound.pitch)))
			max_roll = maxf(max_roll, absf(float(outbound.roll)))
			max_depth = maxf(max_depth, float(outbound.depth))
			max_model_weight = maxf(max_model_weight, float(outbound.model_weight))
			last_progress = progress
		check(max_deviation < 0.1 and max_travel_scale > 1.1 and is_zero_approx(max_yaw)
			and is_zero_approx(max_pitch) and is_zero_approx(max_roll) and max_depth > 0.9,
			"Tier %d grows along a straight approach with no pitch, roll or premature turn" % (previous + 1))
		if previous < 4:
			check(max_model_weight > 0.9 and not view._model_sample.is_empty(),
				"The acquired three-dimensional chest is visible during the tier %d flight" % (previous + 1))
		check(is_zero_approx(float(upper.yaw)) and is_zero_approx(float(upper.pitch))
			and is_zero_approx(float(upper.roll))
			and float(upper.scale) > 1.3,
			"The chest reaches its full enlarged size and levels at the upper destination before turning")
		check(Vector2(peak.center).distance_to(upper.center) < 0.1 and float(peak.scale) > 1.3
			and float(peak.yaw) > 0.1 and float(peak.yaw) < TAU,
			"The reveal rotates the already enlarged chest at its upper-screen destination")
		check(is_equal_approx(float(turned.yaw), TAU) and Vector2(turned.center).distance_to(upper.center) < 0.1,
			"The chest completes a full closed turn before beginning its return")
		check(Vector2(returning.center).distance_to(anchor.get_center()) < Vector2(upper.center).distance_to(anchor.get_center())
			and float(returning.scale) < float(peak.scale),
			"The return visibly approaches the anchor while recovering the resting size")
		var return_offset: Vector2 = Vector2(returning.center) - anchor.get_center()
		var outbound_midway: Dictionary = _pose_at(view, Flight.TOP_SECONDS * 0.5)
		check(absf(return_offset.cross(route)) / route.length() < 0.1
			and Vector2(returning.center).distance_to(outbound_midway.center) < 0.01
			and absf(float(returning.scale) - float(outbound_midway.scale)) < 0.0001,
			"Tier %d retraces the same straight route with the matching outbound size" % (previous + 1))
		check(Vector2(arrived.center).is_equal_approx(anchor.get_center()) and is_equal_approx(float(arrived.scale), 1.0)
			and is_zero_approx(wrapf(float(arrived.roll), -PI, PI)) and is_zero_approx(float(arrived.pitch))
			and is_zero_approx(float(arrived.depth)), "The chest lands exactly at its original anchor without residual tilt or depth")
		for boundary: float in [Flight.TOP_SECONDS, Flight.TURN_START,
			Flight.REVEAL_SECONDS, Flight.TURN_END, Flight.RETURN_START, Flight.PERFORMANCE_SECONDS]:
			var before: Dictionary = _pose_at(view, boundary - 0.0001)
			var after: Dictionary = _pose_at(view, boundary + 0.0001)
			check(Vector2(before.center).distance_to(after.center) < 0.1 and absf(float(before.scale) - float(after.scale)) < 0.01
				and absf(float(before.yaw) - float(after.yaw)) < 0.01 and absf(float(before.roll) - float(after.roll)) < 0.01
				and absf(float(before.pitch) - float(after.pitch)) < 0.01 and absf(float(before.depth) - float(after.depth)) < 0.01
				and absf(float(before.model_weight) - float(after.model_weight)) < 0.01,
				"Tier %d stays continuous across the %.2f-second flight boundary" % [previous + 1, boundary])


func _check_reversible_growth(view, label: String, steps: int = 24) -> void:
	var departure: Dictionary = _pose_at(view, 0.0)
	var top: Dictionary = _pose_at(view, Flight.TOP_SECONDS)
	var raw_top: Dictionary = view._motion(Flight.TOP_SECONDS)
	var previous_raw_scale: float = 1.0
	var previous_fitted_scale: float = 1.0
	for step in range(1, steps + 1):
		var fraction: float = float(step) / float(steps)
		var outbound_age: float = Flight.TOP_SECONDS * fraction
		var return_age: float = lerpf(Flight.RETURN_START, Flight.PERFORMANCE_SECONDS, 1.0 - fraction)
		var outbound: Dictionary = _pose_at(view, outbound_age)
		var raw_outbound: Dictionary = view._motion(outbound_age)
		var returning: Dictionary = _pose_at(view, return_age)
		var raw_returning: Dictionary = view._motion(return_age)
		var expected_scale: float = lerpf(1.0, float(raw_top.scale), smoothstep(0.0, 1.0, fraction))
		check(float(raw_outbound.scale) > previous_raw_scale
			and absf(float(raw_outbound.scale) - expected_scale) < 0.0001,
			"%s grows continuously throughout outbound sample %d, reaching its peak on arrival" % [label, step])
		check(float(outbound.scale) > previous_fitted_scale
			and float(outbound.scale) <= float(top.scale) + 0.0001,
			"%s preserves strictly increasing visible size after viewport fitting at sample %d" % [label, step])
		check(Vector2(raw_outbound.center).distance_to(raw_returning.center) < 0.01
			and absf(float(raw_outbound.scale) - float(raw_returning.scale)) < 0.0001,
			"%s samples the same route and size in reverse at sample %d" % [label, step])
		var expected_center: Vector2 = Vector2(departure.center).lerp(top.center, smoothstep(0.0, 1.0, fraction))
		check(Vector2(outbound.center).distance_to(expected_center) < 0.1
			and Vector2(outbound.center).distance_to(returning.center) < 0.01
			and absf(float(outbound.scale) - float(returning.scale)) < 0.0001
			and is_zero_approx(float(outbound.pitch)) and is_zero_approx(float(outbound.roll))
			and is_zero_approx(float(returning.pitch)) and is_zero_approx(float(returning.roll)),
			"%s retains a straight upright outbound and return route after viewport fitting at sample %d" % [label, step])
		previous_raw_scale = float(raw_outbound.scale)
		previous_fitted_scale = float(outbound.scale)
	for step in range(13):
		var age: float = lerpf(Flight.TOP_SECONDS, Flight.RETURN_START, float(step) / 12.0)
		var pose: Dictionary = _pose_at(view, age)
		var raw: Dictionary = view._motion(age)
		check(is_equal_approx(float(raw.scale), float(raw_top.scale))
			and is_equal_approx(float(pose.scale), float(top.scale))
			and Vector2(pose.center).distance_to(top.center) < 0.1
			and is_zero_approx(float(pose.pitch)) and is_zero_approx(float(pose.roll)),
			"%s holds its arrival position and size while turning only around the vertical axis" % label)
		if int(view._events[0].tier) > 4:
			check(is_equal_approx(float(pose.sprite_scale_x), cos(float(pose.yaw))),
				"%s projects its source artwork horizontally for the vertical-axis turn" % label)


func _check_upgrade_containment(view) -> void:
	for previous in range(0, 6):
		_begin(view, previous, previous + 1)
		var contained: bool = true
		var recovered: bool = true
		var upright: bool = true
		var frames: int = ceili(Celebration.PERFORMANCE_SECONDS * 60.0)
		for frame in range(frames + 1):
			var age: float = minf(float(frame) / 60.0, Celebration.PERFORMANCE_SECONDS)
			view._elapsed = Celebration.ARRIVAL_SECONDS + age
			view._started = true
			view._revealed = age >= Celebration.REVEAL_SECONDS
			view._sync()
			for dimensions: Vector2 in [Vector2(1366, 600), Vector2(390, 640), Vector2(320, 220), Vector2(844, 235)]:
				root.size = Vector2i(dimensions)
				view.position = Vector2(12, 40)
				view.size = dimensions
				for screen_anchor: Rect2 in [Rect2(6, 4, 43, 43), Rect2(6, dimensions.y - 36, 38, 32), Rect2(dimensions.x - 49, 4, 43, 43)]:
					var anchor := Rect2(screen_anchor.position - view.position, screen_anchor.size)
					view.set_chest_anchor(anchor)
					view._sync()
					var pose: Dictionary = view._motion(age)
					upright = upright and is_zero_approx(float(pose.pitch)) and is_zero_approx(float(pose.roll))
					var edge: float = minf(anchor.size.x, anchor.size.y)
					var placement: Dictionary = view._placement(pose, edge, anchor.get_center())
					var transform := Transform2D(float(pose.roll), Vector2.ONE * float(placement.scale), 0.0, placement.center)
					var safe: Rect2 = view._flight_bounds().grow(0.01)
					contained = contained and safe.encloses(transform * Rect2(Vector2.ONE * -edge * 0.5, Vector2.ONE * edge))
					if not view._model_sample.is_empty():
						var tier: int = previous + 1 if view._revealed or previous == 0 else previous
						var model = view._models._pool[tier]
						upright = upright and model._rig.basis.y.is_equal_approx(Vector3.UP)
						var bounds: Rect2 = model.closed_bounds()
						var unit: float = edge / maxf(bounds.size.x, bounds.size.y)
						for corner in range(8):
							var projected: Vector2 = model._project_point(model._rig.transform * model._closed_box.get_endpoint(corner))
							contained = contained and safe.has_point(transform * ((projected - bounds.get_center()) * unit))
					if frame == 0 or frame == frames:
						recovered = recovered and Vector2(placement.center).is_equal_approx(anchor.get_center()) \
							and is_equal_approx(float(placement.scale), 1.0)
		check(contained, "Chest transition %d keeps every turned model corner and static fallback inside the viewport" % previous)
		check(upright, "Chest transition %d keeps the pose and real model upright throughout acquisition or upgrade" % previous)
		check(recovered, "Chest transition %d starts and settles at the original HUD position and size" % previous)
		for dimensions: Vector2 in [Vector2(1366, 600), Vector2(390, 640), Vector2(320, 220), Vector2(844, 235)]:
			root.size = Vector2i(dimensions)
			view.position = Vector2(12, 40)
			view.size = dimensions
			for screen_anchor: Rect2 in [Rect2(6, 4, 43, 43), Rect2(6, dimensions.y - 36, 38, 32), Rect2(dimensions.x - 49, 4, 43, 43)]:
				view.set_chest_anchor(Rect2(screen_anchor.position - view.position, screen_anchor.size))
				_check_reversible_growth(view, "Fitted tier %d at %s from %s" % [previous + 1, dimensions, screen_anchor.position], 12)
	root.size = Vector2i(1000, 720)


func _models_stopped(models) -> bool:
	for model in models._pool.values():
		if model.snapshot().active or model.render_target_update_mode != SubViewport.UPDATE_DISABLED:
			return false
	return true


func _check_model_lifecycle(view) -> void:
	_begin(view, 1, 2)
	check(view._models._pool.size() == 2 and _models_stopped(view._models),
		"The incoming and outgoing models prepare without rendering during fragment flight")
	view.advance(Celebration.ARRIVAL_SECONDS + 0.35)
	check(not view._model_sample.is_empty() and view._models._pool[1].snapshot().active,
		"The visible upgrade samples its live closed model on the existing reward clock")
	var elapsed: float = view._elapsed
	view.reduced_motion = true
	check(view._model_sample.is_empty() and _models_stopped(view._models)
		and is_equal_approx(view._elapsed, elapsed),
		"Enabling reduced motion stops all model rendering without restarting the milestone")
	view.reduced_motion = false
	check(not view._model_sample.is_empty() and is_equal_approx(view._elapsed, elapsed),
		"Restoring motion resamples the same point of the three-dimensional turn")
	view.hide()
	check(_models_stopped(view._models), "A hidden presentation disables both model render targets immediately")
	view.show()
	view.advance(Celebration.PERFORMANCE_SECONDS)
	check(not view.is_active() and view._model_sample.is_empty() and _models_stopped(view._models),
		"A completed milestone retains no active renderer or stale model sample")
	_begin(view, 2, 3, true)
	view.advance(Celebration.ARRIVAL_SECONDS + Celebration.REVEAL_SECONDS + 0.2)
	check(view.visible and view._model_sample.is_empty() and _models_stopped(view._models),
		"A wholly reduced-motion milestone never requests a three-dimensional render")
	view.clear()
	check(view._models._pool.is_empty() and view._models.get_child_count() == 0
		and view._model_sample.is_empty(),
		"Clearing a round detaches every model surface and its last texture sample")


func _check_closed_models() -> void:
	var models := RewardModel.new()
	root.add_child(models)
	models.set_active(false)
	for tier in range(1, 5):
		models.prepare(tier)
		check(models._pool.has(tier), "Chest tier %d loads its acquired articulated model" % tier)
		if not models._pool.has(tier):
			continue
		check(models._pool.size() <= RewardModel.POOL_LIMIT and models.get_child_count() <= 2,
			"Preparing tier %d keeps at most two model surfaces attached" % tier)
		var model = models._pool[tier]
		var sample: Dictionary = models.sample(tier, 0.0)
		check(not sample.is_empty() and sample.texture != null and sample.bounds.has_area(),
			"Tier %d exposes its real render surface and stable closed framing" % tier)
		var rest: Array = model.snapshot().parts.duplicate(true)
		var camera: Transform3D = model._camera.transform
		var camera_size: float = model._camera.size
		var closed: Rect2 = model.closed_bounds()
		var envelope: Rect2 = model.design_bounds()
		model.set_pose(0.75, 0.5, 0.4, 2.0, 1.0, Color.YELLOW, false)
		check(model.snapshot().parts != rest, "Tier %d has a genuine opening mechanism to keep shut during a reward turn" % tier)
		var closed_throughout: bool = true
		var fixed_camera: bool = true
		var contained: bool = true
		var genuine_yaw: bool = true
		for index in range(17):
			var yaw: float = float(index) / 16.0 * TAU
			models.sample(tier, yaw)
			var state: Dictionary = model.snapshot()
			closed_throughout = closed_throughout and state.parts == rest and state.open_amount == 0.0 \
				and state.pressure == 0.0 and state.light_strength == 0.0
			fixed_camera = fixed_camera and model._camera.transform == camera \
				and is_equal_approx(model._camera.size, camera_size) \
				and model.closed_bounds() == closed and model.design_bounds() == envelope
			genuine_yaw = genuine_yaw and model._rig.basis.x.is_equal_approx(Basis(Vector3.UP, yaw).x)
			for corner in range(8):
				var point: Vector2 = model._project_point(model._rig.transform * model._closed_box.get_endpoint(corner))
				contained = contained and Rect2(0, 0, 1024, 1024).has_point(point)
		check(closed_throughout, "Tier %d turns with the exact closed lid, lock and handle poses and no cavity light" % tier)
		check(genuine_yaw, "Tier %d rotates the actual three-dimensional rig through a full turn" % tier)
		check(fixed_camera and contained, "Tier %d fits every turned corner inside one fixed camera crop" % tier)
		var genuine_pitch: bool = true
		var pitched_containment: bool = true
		var pitched_closed: bool = true
		var pitched_camera: bool = true
		for pitch: float in [-0.22, 0.22]:
			for index in range(17):
				var yaw: float = float(index) / 16.0 * TAU
				var pitched: Dictionary = models.sample(tier, yaw, pitch)
				var expected_basis: Basis = Basis.from_euler(Vector3(pitch, yaw, 0.0))
				genuine_pitch = genuine_pitch and model._rig.basis.is_equal_approx(expected_basis)
				var state: Dictionary = model.snapshot()
				pitched_closed = pitched_closed and state.parts == rest and is_zero_approx(float(state.open_amount)) \
					and is_zero_approx(float(state.pressure)) and is_zero_approx(float(state.light_strength))
				pitched_camera = pitched_camera and model._camera.transform == camera \
					and is_equal_approx(model._camera.size, camera_size) and model.closed_bounds() == closed \
					and model.design_bounds() == envelope
				var projected_bounds: Rect2 = pitched.turn_bounds
				for corner in range(8):
					var point: Vector2 = model._project_point(model._rig.transform * model._closed_box.get_endpoint(corner))
					pitched_containment = pitched_containment and Rect2(0, 0, 1024, 1024).has_point(point) \
						and projected_bounds.grow(0.01).has_point(point)
		check(genuine_pitch and pitched_closed,
			"Tier %d pitches the real closed geometry without opening its lid or lighting its cavity" % tier)
		check(pitched_camera and pitched_containment,
			"Tier %d fits pitched and yawed model corners in a fixed camera and accurate projected bounds" % tier)
		model.set_display_size(Vector2(2000, 2000))
		check(model.snapshot().resolution == 512 and _models_stopped(models),
			"Tier %d respects the small HUD render budget and stays disabled when inactive" % tier)
	check(models._pool.size() == 2 and models._pool.has(3) and models._pool.has(4),
		"Advancing through four tiers retains only the latest two reusable model surfaces")
	var before_invalid: Array = models._order.duplicate()
	check(models.sample(0, 0.0).is_empty() and models.sample(5, 0.0).is_empty()
		and models.sample(4, NAN).is_empty() and models.sample(4, INF).is_empty()
		and models.sample(4, 0.0, NAN).is_empty() and models.sample(4, 0.0, INF).is_empty()
		and models._order == before_invalid,
		"Unsupported art and invalid angles use the static fallback without growing or mutating the pool")
	models.set_active(true)
	models.sample(4, 0.6)
	var active = models._pool[4]
	check(active.render_target_update_mode == SubViewport.UPDATE_ONCE,
		"A changed reward angle schedules one render instead of an unconditional viewport loop")
	active.render_target_update_mode = SubViewport.UPDATE_DISABLED
	models.sample(4, 0.6)
	check(active.render_target_update_mode == SubViewport.UPDATE_DISABLED,
		"Sampling an unchanged closed turn does not render again")
	models.set_active(false)
	models.sample(4, 0.9)
	check(_models_stopped(models), "Sampling a paused reward cannot reactivate either model renderer")
	var retired: Array = models._pool.values()
	models.clear()
	var detached: bool = true
	for model in retired:
		detached = detached and model.get_parent() == null and not model.snapshot().active \
			and model.render_target_update_mode == SubViewport.UPDATE_DISABLED
	check(detached and models._pool.is_empty() and models._order.is_empty(),
		"Clearing the pool disables and detaches every viewport before deferred disposal")
	_check_original_opening(models)
	models.free()


func _check_original_opening(models) -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RewardModel.MANIFEST_PATH))
	var style: Dictionary = catalog.styles.harvest
	var original: Dictionary = style.duplicate(true)
	var model := ChestModel.new()
	root.add_child(model)
	check(model.configure(style), "The original opening scene still accepts its unmodified source style")
	var camera: Transform3D = model._camera.transform
	var camera_size: float = model._camera.size
	var framing: Rect2 = model.design_bounds()
	model.set_pose(0.78, 0.3, 0.2, 0.45, 0.9, Color.YELLOW, false)
	var opening: Dictionary = model.snapshot().duplicate(true)
	models.prepare(2)
	models.sample(2, PI)
	check(style == original and models._styles.harvest == original,
		"Reward framing overrides neither the original style nor the shared catalog")
	check(model.snapshot() == opening and model._camera.transform == camera
		and is_equal_approx(model._camera.size, camera_size) and model.design_bounds() == framing,
		"A separate reward turn leaves an already opening chest and its camera untouched")
	model.set_closed_turn(PI)
	model.set_pose(0.78, 0.3, 0.2, 0.45, 0.9, Color.YELLOW, false)
	check(model.snapshot() == opening and model._camera.transform == camera
		and model.design_bounds() == framing,
		"Normal continuous opening can resume exactly after a closed-turn sample")
	model.free()


func _advance_owner(view, seconds: float) -> void:
	var remaining: float = seconds
	while remaining > 0.000001:
		var delta: float = minf(0.05, remaining)
		view._process(delta)
		remaining -= delta


func _check_owner_lifecycle() -> void:
	var data := Data.new()
	check(data.load_all(), "Presentation ownership uses the production chest manifest")
	var words: Array = data.words.filter(func(word: Dictionary) -> bool:
		return int(word.min_age) <= 3 and not str(word.get("image", "")).is_empty()).slice(0, 12)
	var view := Jelly.new()
	root.add_child(view)
	view.set_process(false)
	view.size = Vector2(1000, 720)
	check(view.configure(words, 3, Data.theme("spring"), data.chests, false, 42),
		"A real Jelly view owns the reward timeline")
	view._chest_milestone(0, 1)
	_advance_owner(view, 0.3)
	view.pause(true)
	var paused: Dictionary = view._reward_presentation.snapshot()
	var board: Dictionary = view.game.snapshot()
	_advance_owner(view, 8.0)
	check(view._reward_presentation.snapshot() == paused and view.game.snapshot() == board,
		"Opening the menu freezes reward timing and gameplay together")
	view.pause(false)
	view.hide()
	_advance_owner(view, 8.0)
	check(view._reward_presentation.snapshot() == paused,
		"A hidden game cannot advance reward visuals or play late reward sounds")
	view.show()
	_advance_owner(view, 0.4)
	check(view._reward_presentation.visible and view._can_play() and not view.drop_button.disabled
		and not view.game.paused and is_equal_approx(view.game.spawn_elapsed, 0.7),
		"Returning resumes the same reward and the playable board together")
	view.stop()
	check(not view._reward_presentation.is_active() and not view._reward_presentation.visible,
		"Leaving Jelly immediately removes the old reward and its queue")
	_check_pending_fusions(view, words, data.chests)
	_check_active_gameplay(view, words, data.chests)
	_check_later_pickup(view, words, data.chests)
	_check_finish_during_reward(view, words, data.chests)
	view.configure(words, 3, Data.theme("spring"), data.chests, false, 42)
	view._chest_milestone(0, 1)
	view.advance_reward_presentation(Celebration.ARRIVAL_SECONDS + Celebration.PERFORMANCE_SECONDS - 0.03)
	view._process(0.1)
	check(not view._reward_presentation.is_active() and is_equal_approx(view.game.spawn_elapsed, 0.1),
		"The frame advances gameplay in full even when the chest effect ends partway through it")
	for at: String in ["assemble", "reward"]:
		for action: String in ["stop", "reconfigure"]:
			view.configure(words, 3, Data.theme("spring"), data.chests, false, 42)
			view._chest_milestone(0, 1)
			view.advance_reward_presentation(Celebration.ARRIVAL_SECONDS - 0.05 if at == "assemble"
				else Celebration.ARRIVAL_SECONDS + Celebration.REVEAL_SECONDS - 0.05)
			var interrupt: Callable = func(cue: String) -> void:
				if cue != at:
					return
				if action == "stop":
					view.stop()
				else:
					view.configure(words, 3, Data.theme("spring"), data.chests, false, 72)
			view.audio_requested.connect(interrupt)
			view._process(0.2)
			view.audio_requested.disconnect(interrupt)
			check(not view._reward_presentation.is_active(),
				"Synchronous %s during %s cannot retain an old presentation" % [action, at])
			if action == "stop":
				check(not view._configured and view.game.paused,
					"The old frame cannot unpause a game stopped from its sound callback")
			else:
				check(view._configured and is_zero_approx(view.game.spawn_elapsed)
					and view.game.fragment_count == 0,
					"The old frame cannot advance or reward a replacement round")
	view.stop()
	view.free()


func _matching_pair(view, marked: bool = false) -> Array[int]:
	for a: Dictionary in view.game.cells:
		if view.game.is_fusing(int(a.id)) or not view._settled(a) or (marked and not bool(a.chest)):
			continue
		for b: Dictionary in view.game.cells:
			if not view.game.is_fusing(int(b.id)) and view._settled(b) and a.word.id == b.word.id and a.kind != b.kind:
				return [int(a.id), int(b.id)]
	return []


func _check_pending_fusions(view, words: Array, manifest: Dictionary) -> void:
	view.configure(words, 3, Data.theme("spring"), manifest, false, 42)
	# The model threshold is tested separately; seed its already earned three
	# fragments so this fixture isolates a menu opened between sibling clears.
	view.game.fragment_count = 3
	var first: Array[int] = _matching_pair(view, true)
	check(first.size() == 2 and view.game.try_merge(first[0], first[1]) == "correct",
		"The unlock fixture begins with a real marked fusion")
	_advance_owner(view, 0.2)
	var second: Array[int] = _matching_pair(view)
	check(second.size() == 2 and view.game.try_merge(second[0], second[1]) == "correct",
		"Another accepted fusion retains its independent completion deadline")
	var other: Array[int] = _matching_pair(view)
	check(other.size() == 2, "An unrelated pair remains available before the fragment threshold")
	var point: Vector2 = view._tiles[other[0]].get_global_rect().get_center()
	check(view._press(4, point), "An unrelated jelly can be held before synthesis queues")
	view._move(point + Vector2(24.0, 0.0))
	_advance_owner(view, 0.85)
	check(view.game.fusions.size() == 1 and view._reward_presentation.is_active()
		and not view._reward_presentation.visible and view.game.fragment_count == 4,
		"The fourth fragment queues synthesis while the later accepted jelly finishes")
	check(view._can_play() and view.snapshot().drag.active and int(view.snapshot().drag.source) == other[0],
		"A queued chest presentation cannot interrupt a drag while a sibling is still disappearing")
	_advance_owner(view, 0.21)
	check(view.game.fusions.is_empty() and view.game.cleared_pairs == 2
		and view._reward_presentation.is_active() and view._can_play() and not view.game.paused
		and view.snapshot().drag.active and int(view.snapshot().drag.source) == other[0],
		"The last sibling clear leaves both gameplay and the held drag running during synthesis")
	_advance_owner(view, 0.65)
	check(not view._reward_presentation.visible,
		"Synthesis waits for the arriving fragment's visible progress fill")
	_advance_owner(view, 0.3)
	check(view._reward_presentation.visible and view.game.fragment_count == 4 and view.game.chest_count == 1,
		"Synthesis then starts once with the previously committed single chest")
	_advance_owner(view, Celebration.REVEAL_SECONDS)
	check(view._reward_presentation.snapshot().revealed and view.snapshot().drag.active
		and int(view.snapshot().drag.source) == other[0],
		"The chest reveal reaches its paper-request beat without dropping the held jelly")
	var destination: Vector2 = view._tiles[other[1]].get_global_rect().get_center()
	view._move(destination)
	view._release(destination)
	check(view.game.fusions.size() == 1 and not view.snapshot().drag.active
		and view._reward_presentation.snapshot().revealed,
		"Releasing the preserved drag onto its partner accepts a new fusion during the reward reveal")
	check(not view.finish_button.disabled and view.navigation_controls().has(view.finish_button),
		"Finish remains available during an in-game chest celebration")
	view.stop()


func _check_active_gameplay(view, words: Array, manifest: Dictionary) -> void:
	for reduced: bool in [false, true]:
		view.configure(words, 3, Data.theme("spring"), manifest, reduced, 42)
		view._chest_milestone(0, 1)
		_advance_owner(view, Celebration.ARRIVAL_SECONDS + Celebration.REVEAL_SECONDS + 0.03)
		check(view._reward_presentation.visible and view._reward_presentation.snapshot().revealed
			and view._reward_presentation.snapshot().reduced_motion == reduced,
			"The input fixture reaches a live chest reveal with the selected motion preference")
		var pair: Array[int] = _matching_pair(view)
		check(pair.size() == 2, "The live reward screen retains an available pair")
		var point: Vector2 = view._tiles[pair[0]].get_global_rect().get_center()
		var destination: Vector2 = view._tiles[pair[1]].get_global_rect().get_center()
		check(view._press(4, point), "A fresh touch can pick up a jelly during the reward effect")
		view._move(destination)
		view._release(destination)
		check(view.game.fusions.size() == 1 and view._reward_presentation.visible and not view.game.paused,
			"A fresh drag can start a fusion while the HUD chest celebrates")
		var count: int = view.game.generated_tiles
		view.drop_button.pressed.emit()
		check(view.game.generated_tiles == count + 4 and view._reward_presentation.visible,
			"The next-wave control dispatches all four jellies during the chest effect")
		_advance_owner(view, 0.1)
		check(is_equal_approx(float(view.game.fusions[0].elapsed), 0.1)
			and is_equal_approx(float(view.game.spawn_elapsed), 0.1),
			"Fusion, falling supply and the next spawn clock continue alongside the reward effect")
		var snapshot: Dictionary = view.game.snapshot()
		view.pause(true)
		var reward: Dictionary = view._reward_presentation.snapshot()
		_advance_owner(view, 1.0)
		check(view.game.cells == snapshot.cells and view.game.fusions == snapshot.fusions
			and view._reward_presentation.snapshot() == reward,
			"An explicit menu pause still freezes an active fusion and chest effect together")
		check(not view._reward_presentation._flight_surface.is_visible_in_tree(),
			"A paused Jelly celebration cannot draw above Home or the vocabulary page")
		var original_size: Vector2 = view.size
		view.size = Vector2(390, 700)
		view._layout()
		for preference: bool in [true, false]:
			view.set_reduced_motion(preference)
			check(not view._reward_presentation._flight_surface.is_visible_in_tree()
				and is_equal_approx(float(view._reward_presentation.snapshot().elapsed), float(reward.elapsed)),
				"Resizing or changing motion preferences cannot reshow a paused Jelly flight")
		view.set_reduced_motion(reduced)
		view.size = original_size
		view._layout()
		view.pause(false)
		check(view._reward_presentation._flight_surface.is_visible_in_tree()
			and is_equal_approx(float(view._reward_presentation.snapshot().elapsed), float(reward.elapsed)),
			"Resuming Jelly restores the same visible chest pose without restarting its clock")
		view.configure(words, 3, Data.theme("spring"), manifest, reduced, 42)
		view._chest_milestone(0, 1)
		view.advance_reward_presentation(Celebration.ARRIVAL_SECONDS + Celebration.REVEAL_SECONDS + 0.03)
		view.game.spawn_elapsed = view.game.spawn_interval - 0.05
		count = view.game.generated_tiles
		view._process(0.1)
		check(view.game.generated_tiles == count + 4 and view._reward_presentation.visible
			and is_equal_approx(view.game.spawn_elapsed, 0.05),
			"A natural spawn deadline releases supply without waiting for confetti to finish")
		view.configure(words, 3, Data.theme("spring"), manifest, reduced, 42)
		while view.game.cells.size() < view.game.CAPACITY:
			view.game.drop_now()
			view.game.step(view.game.SETTLE_SECONDS)
		view._sync_tiles()
		view._refresh_hud()
		view._chest_milestone(0, 1)
		view.advance_reward_presentation(Celebration.ARRIVAL_SECONDS + Celebration.REVEAL_SECONDS + 0.03)
		var danger: float = view.game.full_elapsed
		view._process(0.2)
		check(danger >= 0.0 and is_equal_approx(view.game.full_elapsed, danger + 0.2)
			and view._reward_presentation.visible and view.game.phase == "playing",
			"A full board continues its danger countdown during the same HUD reward effect")
	view.stop()


func _check_later_pickup(view, words: Array, manifest: Dictionary) -> void:
	view.configure(words, 3, Data.theme("spring"), manifest, false, 42)
	# The fifth pickup is still flying after the first four filled the unlock ring.
	view.game.fragment_count = 5
	view.game.chest_tier = 1
	view.game.chest_count = 1
	view._loot_flights.append({"from": view._board.get_center(), "elapsed": 0.0, "amount": 1})
	view._refresh_hud()
	view._loot_meter.settle()
	view._chest_milestone(0, 1)
	view.advance_reward_presentation(Celebration.ARRIVAL_SECONDS - 0.01)
	view._process(0.02)
	check(view._reward_presentation.visible and view._loot_flights.size() == 1
		and is_equal_approx(float(view._loot_flights[0].elapsed), 0.02)
		and is_equal_approx(float(view._loot_meter.snapshot().displayed), 4.0),
		"A later in-flight pickup cannot postpone celebration for the already filled unlock ring")
	view.stop()


func _check_finish_during_reward(view, words: Array, manifest: Dictionary) -> void:
	view.configure(words, 3, Data.theme("spring"), manifest, false, 42)
	view.game.fragment_count = 3
	var pair: Array[int] = _matching_pair(view, true)
	check(pair.size() == 2 and view.game.try_merge(pair[0], pair[1]) == "correct",
		"The finish fixture unlocks a real chest through a marked match")
	_advance_owner(view, view.game.FUSION_SECONDS + Celebration.ARRIVAL_SECONDS + view._loot_meter.FILL_SECONDS + Celebration.REVEAL_SECONDS + 0.1)
	check(view.game.fragment_count == 4 and view.game.chest_count == 1
		and view._reward_presentation.snapshot().revealed,
		"A committed chest is already earned when its paper-request beat is reached")
	view._chest_milestone(1, 2)
	check(view._reward_presentation.snapshot().queued == 2,
		"Finishing is exercised with both active and queued visual milestones")
	var results: Array[Dictionary] = []
	var record: Callable = func(result: Dictionary) -> void: results.append(result)
	view.round_finished.connect(record)
	view._finish_round()
	view._finish_round()
	_advance_owner(view, 4.0)
	view.round_finished.disconnect(record)
	check(view.game.phase == "finished" and results.size() == 1
		and int(results[0].chest_count) == 1 and int(results[0].chest_tier) == 1
		and int(results[0].fragment_count) == 4 and int(results[0].score) == 1,
		"Finish during confetti settles the exact earned chest once despite repeated confirmations")
	check(not view._reward_presentation.is_active() and not view._reward_presentation.visible,
		"Finishing clears every queued chest motion while its paper tail remains the host's responsibility")
	view.stop()
