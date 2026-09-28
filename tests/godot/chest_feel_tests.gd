extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _poses(chest) -> Array:
	var values: Array = [chest._art.transform]
	for piece in chest._pieces:
		values.append(piece.node.transform)
	return values


func _run() -> void:
	var data = load("res://scripts/game_data.gd").new()
	check(data.load_all(), "The original imported artwork remains valid")
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	chest.set_process(false)
	chest.size = Vector2(440, 360)
	var cues: Array = []
	var openings: Array = []
	chest.cue_requested.connect(func(theme_id: String, cue: String, step: int) -> void:
		cues.append([theme_id, cue, step]))
	chest.opened.connect(func() -> void: openings.append(chest.theme_id))
	var family_poses: Dictionary = {}
	for theme in data.THEMES:
		chest.clear()
		chest.reduced_motion = false
		chest.configure_skin(data.theme(theme), data.chests)
		chest.set_process(false)
		cues.clear()
		var rest: Array = _poses(chest)
		chest.begin_hold()
		check(_poses(chest) != rest, theme + " responds in the press call before any frame or timer")
		check(cues == [[theme, "press", 0]], theme + " emits a single contact beat")
		chest.set_hold_progress(0.45)
		check(_poses(chest).slice(1) != rest.slice(1),
			theme + " builds pressure in its lock, core or facets as well as its body")
		chest.begin_hold()
		check(is_equal_approx(chest.hold_progress, 0.45), theme + " ignores duplicate hold starts")
		chest.set_hold_progress(0.8)
		chest.set_hold_progress(1.0)
		chest.set_hold_progress(1.0)
		check(cues.filter(func(item): return item[1] == "charge_step") ==
			[[theme, "charge_step", 1], [theme, "charge_step", 2], [theme, "charge_step", 3]],
			theme + " emits exactly one beat for each real progress milestone")
		var previous: int = openings.size()
		chest.start_open(false)
		check(cues.back() == [theme, "opening", 0], theme + " stops charge at the start of opening")
		chest._process(0.25)
		check(chest.hold_effect_snapshot().opening_time == 0.0 and cues.back() == [theme, "opening", 0],
			theme + " cannot spend the frame delta from before its opening transition")
		chest._advance_animation(0.09)
		check(not cues.any(func(item): return item[1] == "unlock"), theme + " keeps the initial anticipation pause")
		chest._advance_animation(0.04)
		check(cues.back() == [theme, "unlock", 0], theme + " unlock sound follows the actual lock beat")
		chest._advance_animation(0.20)
		check(cues.back() == [theme, "release", 0], theme + " releases at the lid-motion beat")
		chest._advance_animation(0.27)
		var style: String = data.theme(theme).chest
		if not family_poses.has(style):
			family_poses[style] = []
		var poses: Array = _poses(chest)
		check(not family_poses[style].has(poses), theme + " has distinct physical motion within its shared artwork family")
		family_poses[style].append(poses)
		if style != "crystal":
			check(chest.piece_count() >= 4, theme + " uses a layered body, interior, lid and lock")
			check(not chest._pieces.any(func(piece): return piece.role in ["closed", "open"]),
				theme + " moves real parts instead of dissolving between whole frames")
		chest._advance_animation(0.34)
		var fit_before: float = chest.hold_effect_snapshot().get("fitted_scale", -1.0)
		chest._advance_animation(0.03)
		var fit_after: float = chest.hold_effect_snapshot().get("fitted_scale", -2.0)
		check(fit_before > 0.0 and is_equal_approx(fit_before, fit_after),
			theme + " keeps the same fitted scale when the progress badge disappears")
		check(cues.back() == [theme, "settle", 0], theme + " plays one settle beat")
		chest._advance_animation(0.82)
		check(openings.size() == previous and chest.mode == "opening", theme + " does not grant a reward before 1.8 seconds")
		chest._advance_animation(0.02)
		chest.finish_immediately()
		check(openings.size() == previous + 1 and chest.mode == "opened", theme + " opens once at the existing deadline")
		check(cues.filter(func(item): return item[1] in ["unlock", "release", "settle"]).size() == 3,
			theme + " never duplicates physical beats on repeated finish")

		chest.clear()
		chest.configure_skin(data.theme(theme), data.chests)
		cues.clear()
		chest.begin_hold()
		chest.set_hold_progress(0.8)
		chest.cancel_hold()
		check(chest.hold_progress == 0.0 and not chest.hold_effect_snapshot().active,
			theme + " cancels real progress immediately while the body returns")
		check(cues.back() == [theme, "cancel", 0], theme + " cancels sound immediately")
		chest._process(0.25)
		check(is_equal_approx(chest.hold_effect_snapshot().cancel_remaining, 0.12),
			theme + " keeps the complete visual return even when cancelled on a slow frame")
		chest._advance_animation(0.06)
		chest.begin_hold()
		check(chest.hold_progress == 0.0 and chest.hold_effect_snapshot().active,
			theme + " can restart halfway through its visual return")
		chest.cancel_hold()
		chest._advance_animation(0.13)
		check(_poses(chest) == rest, theme + " returns every physical part to rest within 120 milliseconds")
		var count: int = cues.size()
		chest._advance_animation(3.0)
		check(cues.size() == count and chest.mode == "closed", theme + " has no stale release after cancellation")

		chest.begin_hold()
		chest.start_open(false)
		count = cues.size()
		previous = openings.size()
		chest.finish_immediately()
		check(cues.size() == count and openings.size() == previous + 1,
			theme + " skips physical sounds when fast-forwarding an earned opening")
		chest.clear()
		chest.configure_skin(data.theme(theme), data.chests)
		chest.reduced_motion = true
		chest.begin_hold()
		chest.set_hold_progress(0.5)
		rest = _poses(chest)
		chest._advance_animation(0.5)
		check(_poses(chest) == rest, theme + " keeps reduced-motion charging static")
		count = cues.size()
		previous = openings.size()
		chest.start_open(true)
		check(chest.mode == "opened" and openings.size() == previous + 1 and cues.size() == count + 1,
			theme + " reduced motion only emits opening, then immediately completes")
	chest.free()
	_check_crystal_mechanism(data)
	_check_motion_bounds(data)
	print("Chest feel: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_crystal_mechanism(data) -> void:
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	chest.set_process(false)
	chest.size = Vector2(440, 360)
	for theme in ["winter", "ocean", "candy"]:
		chest.clear()
		chest.reduced_motion = false
		chest.configure_skin(data.theme(theme), data.chests)
		check(chest.hold_effect_snapshot().interior_open == 0.0, theme + " has no open cavity while closed")
		chest.start_open(false)
		chest._advance_animation(0.319)
		var core_moves: bool = false
		var panels_wait: bool = true
		for piece in chest._pieces:
			var rest: Transform2D = piece.rest
			var actual: Transform2D = piece.node.transform
			var displacement: float = actual.origin.distance_to(rest.origin)
			if piece.role == "01":
				core_moves = displacement > 5.0
			elif piece.role != "chest":
				panels_wait = panels_wait and displacement < 1.0 and absf(actual.get_rotation() - rest.get_rotation()) < 0.002
		check(core_moves and panels_wait, theme + " unlocks its source central crystal before its outer panels move")
		check(chest.hold_effect_snapshot().interior_open == 0.0, theme + " keeps the cavity sealed until the release beat")
		chest._advance_animation(0.18)
		var cavity: float = chest.hold_effect_snapshot().interior_open
		check(cavity > 0.0 and cavity < 1.0, theme + " reveals interior depth as the panels separate")
		chest._advance_animation(0.3)
		check(chest.hold_effect_snapshot().interior_open == 1.0, theme + " leaves an open interior after its panels release")
		chest.clear()
		check(chest.hold_effect_snapshot().interior_open == 0.0, theme + " removes interior depth when resetting the reward view")
	chest.free()


func _check_motion_bounds(data) -> void:
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	chest.set_process(false)
	for theme in data.THEMES:
		for dimensions in [Vector2(320, 320), Vector2(320, 110), Vector2(320, 72), Vector2(180, 120), Vector2(180, 400), Vector2(640, 190)]:
			chest.clear()
			chest.size = dimensions
			chest.reduced_motion = false
			chest.configure_skin(data.theme(theme), data.chests)
			chest.begin_hold()
			chest.set_hold_progress(0.99)
			chest.start_open(false)
			var prior: float = 0.0
			var outside: Array[String] = []
			var stage := Rect2(Vector2.ZERO, dimensions).grow(0.5)
			for time in [0.0, 0.12, 0.31, 0.44, 0.61, 0.76, 0.95, 1.2, 1.8]:
				chest._advance_animation(time - prior)
				prior = time
				var state: Dictionary = chest.hold_effect_snapshot()
				var physical: Dictionary = state.physical_bounds
				var bounds := Rect2(Vector2(physical.x, physical.y), Vector2(physical.width, physical.height))
				if not stage.encloses(bounds) or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
					outside.append("%.2fs: %s" % [time, bounds])
			check(outside.is_empty(), "The %s material motion stays inside %s through every physical beat: %s" % [theme, dimensions, outside])
	chest.free()
