extends SceneTree

const PairReward = preload("res://scripts/pair_chest_reward.gd")
const Flight = preload("res://scripts/chest_reward_flight.gd")
const Data = preload("res://scripts/game_data.gd")
const THEMES := ["spring", "summer", "autumn", "winter", "ocean", "space", "jungle", "candy"]

var checks: int = 0
var failures: int = 0
var cues: Array[String] = []
var reveals: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 640)
	var data := Data.new()
	if not data.load_all():
		check(false, "Pair rewards use the acquired game chest manifests")
		quit(1)
		return
	var view := PairReward.new()
	root.add_child(view)
	view.size = Vector2(960, 640)
	view.set_toast_bounds(Rect2(100, 72, 760, 46))
	view.cue_requested.connect(func(id: String, cue: String) -> void: cues.append(id + ":" + cue))
	view.confetti_requested.connect(func(id: String) -> void: reveals.append(id))
	check(view.configure("round-a", "spring", data.chests, false), "A valid round configures its existing theme chest")
	check(not view.snapshot().active and not view.visible and view.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"The empty reward row adds no visible content or input target")
	check(not view.show_pair_result("old-round", true), "A stale pair callback cannot show treasure in the current round")
	check(not view.show_pair_result("round-a", false, false), "The owner can omit routine no-chest messages")
	check(view.show_pair_result("round-a", false), "A requested no-chest result appears")
	check(view.snapshot().message == "No chest this pair" and not view.snapshot().earned and not view.chest.visible,
		"A failed drop is a small text acknowledgement without fake treasure")
	view.advance(PairReward.MISS_SECONDS + 0.01)
	check(not view.snapshot().active and not view.visible and cues.is_empty(), "No-chest feedback quietly clears without sound or paper")
	check(view.show_pair_result("round-a", true), "A committed successful pair starts the chest result")
	view.advance(PairReward.REVEAL_SECONDS - 0.01)
	check(cues.is_empty() and reveals.is_empty(), "Paper and sound wait for the actual reveal beat")
	view.advance(0.02)
	check(cues == ["round-a:reward"] and reveals == ["round-a"] and view.snapshot().performance_active,
		"The reveal emits one round-bound sound and one request for the shared screen overlay")
	check(not view.show_pair_result("round-a", true) and not view.show_pair_result("round-a", false),
		"Duplicate or later pairs cannot restart the earned chest or replace its status")
	var before_pause: float = view.snapshot().elapsed
	view.set_paused(true)
	view.advance(5.0)
	check(view.snapshot().elapsed == before_pause and reveals == ["round-a"],
		"Menu or background pause preserves the current timeline without another reveal")
	view.set_paused(false)
	view.advance(0.1)
	check(view.snapshot().elapsed > before_pause and cues.size() == 1 and reveals.size() == 1,
		"Resume continues without replaying the reward cue or screen overlay request")
	view.advance(1.0)
	check(view.snapshot().performance_active and reveals.size() == 1,
		"The compact chest performance continues independently after its single reveal request")
	view.advance(2.0)
	check(not view.snapshot().performance_active and view.snapshot().active and view.snapshot().earned,
		"The performance ends while its earned chest remains visible")
	check(view.snapshot().message == "Chest ready" and view.snapshot().chest_mode == "closed" and reveals.size() == 1,
		"The compact settled status retains a closed chest without opening or repeated paper")
	check(view.chest.scale == Vector2.ONE and is_zero_approx(view.chest.rotation), "The closed chest settles exactly to its authored dimensions")
	for theme_id: String in THEMES:
		check(view.configure("theme-" + theme_id, theme_id, data.chests, true)
			and view.show_pair_result("theme-" + theme_id, true), "The earned preview supports source chest theme " + theme_id)
		view.advance(0.5)
		check(view.chest.theme_id == theme_id and view.chest.mode == "closed" and view.chest.piece_count() > 0,
			"Theme " + theme_id + " reuses real closed chest artwork")
		check(view.chest.scale == Vector2.ONE and is_zero_approx(view.chest.rotation) and reveals == ["round-a"],
			"Reduced motion preserves a static earned status in " + theme_id)
		view.advance(PairReward.REWARD_SECONDS)
		check(not view.snapshot().performance_active and view.snapshot().earned,
			"Reduced motion completes the same presentation deadline for " + theme_id)
	for area: Rect2 in [Rect2(12, 64, 336, 46), Rect2(12, 40, 780, 46), Rect2(12, 64, 184, 42)]:
		view.set_toast_bounds(area)
		check(area.encloses(view.snapshot().toast_rect), "The status remains inside the host's reserved toolbar row")
		check(view.mouse_filter == Control.MOUSE_FILTER_IGNORE and view._title.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and view.chest.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"All pair reward visuals leave gameplay input with the live board")
	view.clear()
	view.advance(10.0)
	check(not view.snapshot().active and view.snapshot().round_id.is_empty() and not view.visible,
		"Leaving a round removes every transient and persistent reward visual")
	view.configure("reentrant", "spring", data.chests, false)
	view.cue_requested.connect(func(id: String, _cue: String) -> void:
		if id == "reentrant":
			view.clear())
	view.show_pair_result("reentrant", true)
	view.advance(PairReward.REVEAL_SECONDS + 0.01)
	check(not view.snapshot().active and view.snapshot().round_id.is_empty() and not view.visible
		and reveals.count("reentrant") <= 1,
		"A host navigation during the sound cue cannot revive an obsolete reward")
	await check_turn(view, data)
	view.free()
	print("Pair chest reward: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check_turn(view, data) -> void:
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(390, 844), Vector2i(568, 320)]:
		root.size = dimensions
		view.position = Vector2(8, 64)
		view.size = Vector2(dimensions.x - 16, 34)
		view.set_toast_bounds(Rect2(Vector2.ZERO, view.size))
		view.configure("turn-%s" % dimensions, "jungle", data.chests, false)
		view.show_pair_result("turn-%s" % dimensions, true)
		await process_frame
		var before: float = maxf(view.chest.closed_art_rect().size.x, view.chest.closed_art_rect().size.y)
		var rest: Dictionary = view.snapshot().motion
		var resting_chest: Rect2 = view.snapshot().chest_rect
		check_growth_and_reverse(view, "Modeled pair chest at %s" % dimensions)
		var departures: Array[Dictionary] = []
		for step in range(1, 12):
			view.advance(Flight.TOP_SECONDS * float(step) / 12.0 - float(view.snapshot().elapsed))
			departures.append(view.snapshot().motion)
		view.advance(Flight.TOP_SECONDS - float(view.snapshot().elapsed))
		var pose: Dictionary = view.snapshot().motion
		var upper: Vector2 = pose.center
		var screen_upper: Vector2 = view.get_global_transform_with_canvas() * upper
		check(absf(screen_upper.x - float(dimensions.x) * 0.5) < 0.1 and screen_upper.y < float(dimensions.y) * 0.36
			and float(pose.edge) * float(pose.scale) >= before * 3.0 and is_zero_approx(float(pose.yaw)),
			"%s reaches the upper center already at its full enlarged size before the reward turn" % dimensions)
		var route: Vector2 = upper - Vector2(rest.center)
		var last_progress: float = 0.0
		for departure: Dictionary in departures:
			var offset: Vector2 = Vector2(departure.center) - Vector2(rest.center)
			var progress: float = offset.dot(route) / route.length_squared()
			check(absf(offset.cross(route)) / route.length() < 0.1 and progress > last_progress and progress < 1.0,
				"%s flies directly from the HUD to the upper center without visiting the screen center" % dimensions)
			check(departure.phase == "depart" and float(departure.scale) > 1.0
				and is_zero_approx(float(departure.yaw)) and is_zero_approx(float(departure.roll)),
				"The pair reward grows during its direct flight and saves its turn for arrival")
			last_progress = progress
		view.advance(Flight.REVEAL_SECONDS - float(view.snapshot().elapsed))
		pose = view.snapshot().motion
		check(view.snapshot().live_turn and float(pose.edge) * float(pose.scale) >= before * 3.0
			and Vector2(pose.center).is_equal_approx(upper) and is_equal_approx(float(pose.yaw), PI),
			"%s turns the already enlarged acquired chest silhouette at its upper destination" % dimensions)
		check(view._title.modulate.a < 0.01 and view._surface_layer.modulate.a < 0.01,
			"The enlarged chest takes visual priority over the compact status pill")
		var model = view._models._pool[1]
		var safe := Rect2(Vector2.ZERO, Vector2(dimensions))
		var contained: bool = true
		for age: float in [1.36, 1.55, 1.72, Flight.TURN_END]:
			view.advance(age - float(view.snapshot().elapsed))
			pose = view.snapshot().motion
			var bounds: Rect2 = model.closed_bounds()
			var unit: float = float(pose.edge) / maxf(bounds.size.x, bounds.size.y)
			var transform: Transform2D = view.get_global_transform_with_canvas() * Transform2D(
				float(pose.roll), Vector2.ONE * float(pose.scale), 0.0, pose.center)
			for corner in range(8):
				var projected: Vector2 = model._project_point(model._rig.transform * model._closed_box.get_endpoint(corner))
				contained = contained and safe.has_point(transform * ((projected - bounds.get_center()) * unit))
		check(contained and is_equal_approx(float(pose.yaw), TAU),
			"%s keeps the real model inside the viewport throughout a complete closed-chest turn" % dimensions)
		view.set_paused(true)
		var paused: Dictionary = view.snapshot().motion
		view.advance(0.2)
		check(view.snapshot().motion == paused and not view._models._active and not view.snapshot().overlay_visible,
			"Pausing freezes the pose and hides the flight without leaving its extra 3D render surface active")
		view.set_paused(false)
		view.set_reduced_motion(true)
		check(not view.snapshot().live_turn and not view._models._active
			and view.chest.modulate.a == 1.0 and view.chest.scale == Vector2.ONE,
			"Reduced motion immediately restores the original still chest without a turn or flash")
		view.set_reduced_motion(false)
		view.advance(Flight.RETURN_START - float(view.snapshot().elapsed))
		check(Vector2(view.snapshot().motion.center).is_equal_approx(upper),
			"The chest finishes its turn in the upper area before flying back")
		view.advance((Flight.PERFORMANCE_SECONDS - Flight.RETURN_START) * 0.5)
		pose = view.snapshot().motion
		check(Vector2(pose.center).distance_to(rest.center) < upper.distance_to(rest.center)
			and float(pose.scale) > 1.0,
			"The return flight moves toward the original chest while recovering its size")
		view.advance(Flight.PERFORMANCE_SECONDS)
		check(not view._models._active and view.chest.modulate.a == 1.0 and view.chest.scale == Vector2.ONE
			and view._title.modulate.a == 1.0 and view._surface_layer.modulate.a == 1.0,
			"Completion returns to the original chest and status without keeping an animated viewport alive")
		check(view.snapshot().chest_rect.is_equal_approx(resting_chest)
			and Vector2(view.snapshot().motion.center).is_equal_approx(rest.center),
			"The final status keeps the exact original chest anchor without a pill-width jump")
	await check_overlay_lifecycle(view, data)
	check_sprite_flight(view, data)
	view.clear()
	check(view._models._pool.is_empty() and not view.snapshot().active and not view.snapshot().overlay_visible,
		"Clearing the round releases the reusable turned model and viewport overlay")


func pair_pose_at(view, age: float) -> Dictionary:
	view._elapsed = age
	view._layout()
	return view.snapshot().motion


func pair_pose_contained(view, pose: Dictionary) -> bool:
	var safe: Rect2 = view.get_viewport_rect().grow(0.01)
	var local := Rect2(-view._art_rect.size * 0.5, view._art_rect.size)
	var transform: Transform2D = view.get_global_transform_with_canvas() * Transform2D(
		float(pose.roll), Vector2.ONE * float(pose.scale), 0.0, pose.center)
	for point: Vector2 in [local.position, Vector2(local.end.x, local.position.y), local.end,
		Vector2(local.position.x, local.end.y)]:
		if not safe.has_point(transform * point):
			return false
	if not view._model_sample.is_empty():
		var model = view._models._pool[view._model_tier]
		var bounds: Rect2 = model.closed_bounds()
		var unit: float = float(pose.edge) / maxf(bounds.size.x, bounds.size.y)
		for corner in range(8):
			var projected: Vector2 = model._project_point(model._rig.transform * model._closed_box.get_endpoint(corner))
			if not safe.has_point(transform * ((projected - bounds.get_center()) * unit)):
				return false
	return true


func check_growth_and_reverse(view, label: String) -> void:
	# Sample visual placement independently, then restore the owner clock so
	# the real advance calls still exercise every authored cue and lifecycle.
	var original_age: float = view._elapsed
	var cue_count: int = cues.size()
	var reveal_count: int = reveals.size()
	var top: Dictionary = pair_pose_at(view, Flight.TOP_SECONDS)
	var last_scale: float = 1.0
	for step in range(1, 25):
		var fraction: float = float(step) / 24.0
		var outbound: Dictionary = pair_pose_at(view, Flight.TOP_SECONDS * fraction)
		var contained: bool = pair_pose_contained(view, outbound)
		var returning: Dictionary = pair_pose_at(view,
			lerpf(Flight.RETURN_START, Flight.PERFORMANCE_SECONDS, 1.0 - fraction))
		contained = contained and pair_pose_contained(view, returning)
		check(float(outbound.scale) > last_scale
			and absf(float(outbound.scale) - lerpf(1.0, float(top.scale), smoothstep(0.0, 1.0, fraction))) < 0.0001,
			"%s grows on every outbound sample %d and reaches its full size on arrival" % [label, step])
		check(Vector2(outbound.center).distance_to(returning.center) < 0.01
			and absf(float(outbound.scale) - float(returning.scale)) < 0.0001,
			"%s reverses its exact fitted route and size at sample %d" % [label, step])
		check(contained, "%s keeps both travel samples %d inside the viewport" % [label, step])
		last_scale = float(outbound.scale)
	for step in range(13):
		var pose: Dictionary = pair_pose_at(view,
			lerpf(Flight.TOP_SECONDS, Flight.RETURN_START, float(step) / 12.0))
		check(is_equal_approx(float(pose.scale), float(top.scale)),
			label + " holds its arrival size through the top turn without growing again")
	pair_pose_at(view, original_age)
	check(cues.size() == cue_count and reveals.size() == reveal_count,
		label + " visual sampling leaves the actual sound and confetti gates untouched")


func check_overlay_lifecycle(view, data) -> void:
	var parent := Control.new()
	root.add_child(parent)
	parent.position = Vector2(36, 80)
	parent.size = Vector2(280, 140)
	parent.clip_contents = true
	view.reparent(parent)
	view.position = Vector2(10, 16)
	view.size = Vector2(260, 40)
	view.set_toast_bounds(Rect2(Vector2.ZERO, view.size))
	view.configure("clipped-parent", "jungle", data.chests, false)
	view.show_pair_result("clipped-parent", true)
	view.advance(Flight.TOP_SECONDS * 0.5)
	check(view._overlay.layer == 70 and view.snapshot().overlay_visible
		and view._overlay.transform.is_equal_approx(view.get_global_transform_with_canvas())
		and view.chest.get_parent() == view._overlay,
		"The flight uses a viewport overlay with the row's transform rather than the clipped game board")
	var elapsed: float = view.snapshot().elapsed
	parent.hide()
	view.advance(1.0)
	check(not view.snapshot().overlay_visible and not view._models._active
		and is_equal_approx(float(view.snapshot().elapsed), elapsed),
		"Hiding an ancestor immediately removes its flight and freezes its timeline")
	parent.show()
	view.advance(0.1)
	check(view.snapshot().overlay_visible and float(view.snapshot().elapsed) > elapsed,
		"Showing the board resumes its same flight without creating a second overlay")
	view.reparent(root)
	parent.free()


func check_sprite_flight(view, data) -> void:
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(390, 844), Vector2i(568, 320)]:
		root.size = dimensions
		view.position = Vector2(8, 80)
		view.size = Vector2(dimensions.x - 16, 46)
		view.set_toast_bounds(Rect2(Vector2.ZERO, view.size))
		var round_id: String = "sprite-flight-%s" % dimensions
		view.configure(round_id, "spring", data.chests, false)
		view.show_pair_result(round_id, true)
		check_growth_and_reverse(view, "Sprite pair chest at %s" % dimensions)
		var contained: bool = true
		var saw_rotation: bool = false
		for frame in range(160):
			view.advance(1.0 / 60.0)
			var pose: Dictionary = view.snapshot().motion
			contained = contained and pair_pose_contained(view, pose)
			if float(pose.roll) > PI * 0.5 and float(pose.roll) < PI * 1.5:
				saw_rotation = true
		check(contained and saw_rotation and not view.snapshot().live_turn,
			"Source 2D chest art visibly rotates in its own plane while staying inside the %s viewport" % dimensions)
		check(view.chest.scale == Vector2.ONE and is_zero_approx(view.chest.rotation),
			"A source sprite returns to its exact authored pose after its full flight")
