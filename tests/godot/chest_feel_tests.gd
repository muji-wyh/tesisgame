extends SceneTree

const Feel = preload("res://scripts/chest_feel.gd")

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
	check(is_equal_approx(Feel.HOLD_SECONDS + Feel.OPEN_SECONDS, 5.0),
		"A confirmed opening has a complete five-second rhythm")
	check(is_equal_approx(Feel.HOLD_SECONDS, 1.2) and is_equal_approx(Feel.OPEN_SECONDS, 3.8),
		"A short confirmation leaves 3.8 seconds for the automatic performance")
	check(is_equal_approx(Feel.RELEASE_TIME, 2.32) and Feel.OPEN_SECONDS - Feel.RELEASE_TIME >= 1.4,
		"The compact buildup preserves the physical release and reward settling time")
	check(is_equal_approx(Feel.UNLOCK_TIME - Feel.ANTICIPATION_TIME, 0.18),
		"The final breath preserves 180 milliseconds of deliberate silence")
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
		chest.set_hold_progress(0.97)
		check(not cues.any(func(item): return item[1] == "charge_step"),
			theme + " waits for one third of the complete progress before its first star")
		chest.set_hold_progress(0.98)
		check(cues.back() == [theme, "charge_step", 1] and chest.mode == "closed",
			theme + " sounds the first star just before hold confirmation")
		chest.set_hold_progress(1.0)
		chest.set_hold_progress(1.0)
		check(cues.filter(func(item): return item[1] == "charge_step") == [[theme, "charge_step", 1]],
			theme + " cannot repeat the first star on a duplicate hold update")
		var previous: int = openings.size()
		chest.start_open(false)
		check(cues.back() == [theme, "opening", 0], theme + " confirms the automatic buildup once")
		chest._process(0.25)
		check(chest.hold_effect_snapshot().opening_time == 0.0 and cues.back() == [theme, "opening", 0],
			theme + " cannot spend the frame delta from before its opening transition")
		var pulse_times: Array[float] = []
		var percent_before: int = chest.hold_effect_snapshot().percent
		var increasing_progress: bool = true
		var sealed: bool = true
		for frame in range(114):
			var pulse_count: int = cues.filter(func(item): return item[1] == "tension_pulse").size()
			chest._advance_animation(1.0 / 60.0)
			var state: Dictionary = chest.hold_effect_snapshot()
			if cues.filter(func(item): return item[1] == "tension_pulse").size() > pulse_count:
				pulse_times.append(state.opening_time)
			increasing_progress = increasing_progress and state.percent >= percent_before and state.percent < 100
			percent_before = state.percent
			sealed = sealed and state.interior_open == 0.0 and openings.size() == previous
		check(increasing_progress and percent_before > 80,
			theme + " continuously advances real progress without reaching 100 during buildup")
		check(sealed, theme + " keeps the reward sealed throughout the escalating buildup")
		check(pulse_times.size() == 9, theme + " emits nine distinct tension beats")
		for index in range(2, pulse_times.size()):
			check(float(Feel.PULSE_TIMES[index]) - float(Feel.PULSE_TIMES[index - 1])
				< float(Feel.PULSE_TIMES[index - 1]) - float(Feel.PULSE_TIMES[index - 2])
				and pulse_times[index] - pulse_times[index - 1]
				<= pulse_times[index - 1] - pulse_times[index - 2] + 1.0 / 60.0,
				theme + " shortens its beat schedule with at most one frame of delivery quantization")
		check(not cues.any(func(item): return item[1] in ["unlock", "release", "settle"]),
			theme + " keeps physical release and settlement silent throughout buildup")
		chest._advance_animation(0.05)
		check(cues.back() == [theme, "anticipation", 0], theme + " cuts into a deliberate final hush")
		var still_pose: Array = _poses(chest)
		chest._advance_animation(0.16)
		check(_poses(chest) == still_pose and cues.back() == [theme, "anticipation", 0],
			theme + " holds still during the breath before unlocking")
		chest._advance_animation(Feel.UNLOCK_TIME - chest.hold_effect_snapshot().opening_time + 0.001)
		check(cues.back() == [theme, "unlock", 0], theme + " unlock sound follows the actual lock beat")
		chest._advance_animation(Feel.RELEASE_TIME - Feel.UNLOCK_TIME)
		check(cues.back() == [theme, "release", 0], theme + " releases at the lid-motion beat")
		check(chest.hold_effect_snapshot().percent == 100,
			theme + " reaches 100 percent at the physical release rather than confirmation")
		check(cues.filter(func(item): return item[1] == "charge_step") ==
			[[theme, "charge_step", 1], [theme, "charge_step", 2], [theme, "charge_step", 3]],
			theme + " emits each whole-performance progress star only once")
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
			theme + " keeps the same fitted scale when the progress effects disappear")
		check(cues.back() == [theme, "settle", 0], theme + " plays one settle beat")
		chest._advance_animation(Feel.OPEN_SECONDS - chest.hold_effect_snapshot().opening_time - 0.01)
		check(openings.size() == previous and chest.mode == "opening", theme + " does not grant a reward before five seconds including confirmation")
		chest._advance_animation(0.02)
		chest.finish_immediately()
		check(openings.size() == previous + 1 and chest.mode == "opened", theme + " opens once at the complete performance deadline")
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
		chest._advance_animation(Feel.OPEN_SECONDS + 1.0)
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
	chest.clear()
	chest.configure_skin(data.theme("space"), data.chests)
	chest.reduced_motion = false
	cues.clear()
	chest.start_open(false)
	chest._advance_animation(0.78)
	check(not cues.any(func(item): return item[1] in ["tension_pulse", "charge_step"]),
		"A stalled frame consumes old tension beats instead of playing an audio backlog")
	check(is_zero_approx(chest.hold_effect_snapshot().pulse_motion)
		and is_zero_approx(chest.hold_effect_snapshot().physical_pose.x),
		"A skipped stale beat cannot create a silent body kick")
	chest._advance_animation(0.061)
	check(cues.filter(func(item): return item[1] == "tension_pulse") == [["space", "tension_pulse", 3]],
		"A recovered frame plays only the next live tension beat")
	var cue_count: int = cues.size()
	chest.finish_immediately()
	chest._advance_animation(Feel.OPEN_SECONDS)
	check(cues.size() == cue_count, "Finishing after a stall never replays missed beats or final release")
	chest.clear()
	chest.configure_skin(data.theme("space"), data.chests)
	chest.start_open(false)
	chest._advance_animation(1.57)
	cues.clear()
	chest._advance_animation(0.23)
	check(cues.filter(func(item): return item[1] == "tension_pulse") == [["space", "tension_pulse", 8]],
		"A 230-millisecond frame coalesces overlapping late pulses into its newest live beat")
	check(chest.hold_effect_snapshot().pulse_motion < 0.0
		and chest.hold_effect_snapshot().physical_pose.x < -0.004,
		"The coalesced eighth beat starts its own negative kick on the sound-delivery frame")
	chest.clear()
	chest.configure_skin(data.theme("space"), data.chests)
	chest.start_open(false)
	cues.clear()
	chest._advance_animation(float(Feel.PULSE_TIMES.back()) + 0.051)
	check(cues.filter(func(item): return item[1] == "tension_pulse") == [["space", "tension_pulse", 9]]
		and chest.hold_effect_snapshot().physical_pose.x > 0.004,
		"The last live beat remains visible and audible when delivered 51 milliseconds late")
	chest._advance_animation(0.025)
	check(is_zero_approx(chest.hold_effect_snapshot().pulse_motion)
		and is_zero_approx(chest.hold_effect_snapshot().physical_pose.x)
		and cues.back() == ["space", "anticipation", 0],
		"The global final breath cuts off a delayed kick before its own return duration")
	chest.clear()
	chest.configure_skin(data.theme("space"), data.chests)
	chest.start_open(false)
	cues.clear()
	chest._advance_animation(Feel.ANTICIPATION_TIME + 0.001)
	check(not cues.any(func(item): return item[1] == "tension_pulse")
		and is_zero_approx(chest.hold_effect_snapshot().pulse_motion),
		"A frame returning during the final breath never invents a late strike or silent kick")
	chest.free()
	_check_shared_pulse_motion(data)
	_check_crystal_mechanism(data)
	_check_motion_bounds(data)
	print("Chest feel: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_shared_pulse_motion(data) -> void:
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	chest.set_process(false)
	chest.size = Vector2(440, 360)
	for theme in data.THEMES:
		chest.clear()
		chest.configure_skin(data.theme(theme), data.chests)
		chest.begin_hold()
		chest.set_hold_progress(0.6)
		chest._advance_animation(0.15)
		var held: Array = _poses(chest)
		chest._advance_animation(0.27)
		check(_poses(chest) == held,
			theme + " holds pressure without an independent periodic shake before confirmation")
		chest.start_open(false)
		var previous_amplitude: float = 0.0
		var previous_direction: float = 0.0
		for index in range(Feel.PULSE_TIMES.size()):
			var beat: float = float(Feel.PULSE_TIMES[index])
			chest._advance_animation(beat - 0.001 - chest.hold_effect_snapshot().opening_time)
			var settled: Dictionary = chest.hold_effect_snapshot()
			check(is_zero_approx(settled.physical_pose.x) and is_zero_approx(settled.physical_pose.rotation),
				"The %s body settles before tension beat %d rather than vibrating off the rhythm" % [theme, index + 1])
			chest._advance_animation(0.00101)
			var struck: Dictionary = chest.hold_effect_snapshot()
			var amplitude: float = absf(struck.physical_pose.x)
			var direction: float = signf(struck.physical_pose.x)
			check(struck.cues.filter(func(cue): return cue.cue == "tension_pulse").size() == index + 1
				and amplitude > 0.004 and direction == signf(struck.pulse_motion),
				"The %s rendered body kicks on the same frame as tension beat %d" % [theme, index + 1])
			check(amplitude > previous_amplitude and (index == 0 or direction != previous_direction),
				"The %s kicks alternate direction and grow stronger toward release" % theme)
			previous_amplitude = amplitude
			previous_direction = direction
		chest._advance_animation(Feel.ANTICIPATION_TIME - chest.hold_effect_snapshot().opening_time + 0.001)
		var hush: Array = _poses(chest)
		chest._advance_animation(0.15)
		check(_poses(chest) == hush and is_zero_approx(chest.hold_effect_snapshot().pulse_motion),
			theme + " ends every kick before the short still breath")
		for frame_delay: float in [0.00001, 1.0 / 120.0, 1.0 / 60.0]:
			chest.clear()
			chest.configure_skin(data.theme(theme), data.chests)
			chest.start_open(false)
			var early: float = 0.0
			var late: float = 0.0
			for index in range(Feel.PULSE_TIMES.size()):
				chest._advance_animation(float(Feel.PULSE_TIMES[index]) + frame_delay
					- chest.hold_effect_snapshot().opening_time)
				var amplitude: float = absf(chest.hold_effect_snapshot().physical_pose.x)
				if index < 3:
					early += amplitude
				elif index >= Feel.PULSE_TIMES.size() - 3:
					late += amplitude
			check(late > early * 1.25,
				"The %s late kicks remain stronger when first rendered %.1f milliseconds after their cues" % [theme, frame_delay * 1000.0])
	chest.free()


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
		chest._advance_animation(Feel.RELEASE_TIME - 0.001)
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
			for time in [0.0] + Feel.PULSE_TIMES + [Feel.ANTICIPATION_TIME, Feel.UNLOCK_TIME,
				Feel.RELEASE_TIME - 0.01, Feel.RELEASE_TIME + 0.12, Feel.RELEASE_TIME + 0.29,
				Feel.RELEASE_TIME + 0.44, Feel.SETTLE_TIME, Feel.OPEN_SECONDS]:
				chest._advance_animation(time - prior)
				prior = time
				var state: Dictionary = chest.hold_effect_snapshot()
				var physical: Dictionary = state.physical_bounds
				var bounds := Rect2(Vector2(physical.x, physical.y), Vector2(physical.width, physical.height))
				if not stage.encloses(bounds) or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
					outside.append("%.2fs: %s" % [time, bounds])
			check(outside.is_empty(), "The %s material motion stays inside %s through every physical beat: %s" % [theme, dimensions, outside])
	chest.free()
