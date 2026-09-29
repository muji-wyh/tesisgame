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
	check(is_equal_approx(Feel.RELEASE_TIME, 2.16) and Feel.OPEN_SECONDS - Feel.RELEASE_TIME >= 1.4,
		"The compact buildup preserves the physical release and reward settling time")
	check(is_equal_approx(Feel.UNLOCK_TIME - Feel.ANTICIPATION_TIME, 0.14),
		"The final pressure rise leads the lock release by 140 milliseconds")
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
		var first_star: float = (Feel.HOLD_SECONDS + Feel.RELEASE_TIME) / (3.0 * Feel.HOLD_SECONDS)
		chest.set_hold_progress(first_star - 0.001)
		check(not cues.any(func(item): return item[1] == "charge_step"),
			theme + " waits for one third of the complete progress before its first star")
		chest.set_hold_progress(first_star + 0.001)
		check(cues.back() == [theme, "charge_step", 1] and chest.mode == "closed",
			theme + " lights the first star just before hold confirmation")
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
		check(pulse_times.size() == 15, theme + " emits fifteen distinct automatic tension beats")
		for index in range(2, pulse_times.size()):
			check(float(Feel.PULSE_TIMES[index]) - float(Feel.PULSE_TIMES[index - 1])
				<= float(Feel.PULSE_TIMES[index - 1]) - float(Feel.PULSE_TIMES[index - 2]) + 0.00001
				and pulse_times[index] - pulse_times[index - 1]
				<= pulse_times[index - 1] - pulse_times[index - 2] + 1.0 / 60.0 + 0.00001,
				theme + " accelerates into a rapid final roll with at most one frame of delivery quantization")
		check(not cues.any(func(item): return item[1] in ["unlock", "release", "settle"]),
			theme + " keeps physical release and settlement silent throughout buildup")
		chest._advance_animation(0.05)
		check(cues.back() == [theme, "anticipation", 0], theme + " transitions its rapid roll into the final pressure rise")
		var final_pose: Array = _poses(chest)
		chest._advance_animation(Feel.UNLOCK_TIME - chest.hold_effect_snapshot().opening_time - 0.01)
		check(_poses(chest) != final_pose and cues.back() == [theme, "anticipation", 0],
			theme + " continues loading its physical mechanism right up to unlocking")
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
		chest._advance_animation(Feel.SETTLE_TIME - chest.hold_effect_snapshot().opening_time - 0.01)
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
	chest._advance_animation(0.72)
	check(cues.filter(func(item): return item[1] == "tension_pulse") == [["space", "tension_pulse", 4]],
		"A stalled frame coalesces the dense rhythm into its newest live beat")
	chest._advance_animation(0.025)
	check(chest.hold_effect_snapshot().pulse_motion > 0.0,
		"The coalesced fourth opening beat develops its matching signed body impulse")
	chest._advance_animation(0.066)
	check(cues.filter(func(item): return item[1] == "tension_pulse") ==
		[["space", "tension_pulse", 4], ["space", "tension_pulse", 5]],
		"A recovered frame continues with the next live beat without replaying the missing three")
	var cue_count: int = cues.size()
	chest.finish_immediately()
	chest._advance_animation(Feel.OPEN_SECONDS)
	check(cues.size() == cue_count, "Finishing after a stall never replays missed beats or final release")
	chest.clear()
	chest.configure_skin(data.theme("space"), data.chests)
	chest.start_open(false)
	chest._advance_animation(1.57)
	cues.clear()
	chest._advance_animation(0.24)
	check(cues.filter(func(item): return item[1] == "tension_pulse") == [["space", "tension_pulse", 14]],
		"A 240-millisecond frame coalesces overlapping late pulses into its newest live beat")
	chest._advance_animation(0.025)
	check(chest.hold_effect_snapshot().pulse_motion > 0.0,
		"The coalesced fourteenth beat develops one positive impulse without old strikes")
	chest.clear()
	chest.configure_skin(data.theme("space"), data.chests)
	chest.start_open(false)
	cues.clear()
	chest._advance_animation(float(Feel.PULSE_TIMES.back()) + 0.051)
	check(cues.filter(func(item): return item[1] == "tension_pulse") == [["space", "tension_pulse", 15]],
		"The last live beat remains audible when delivered 51 milliseconds late")
	chest._advance_animation(0.020)
	check(chest.hold_effect_snapshot().pulse_motion < 0.0,
		"A late final strike still develops its impulse before the final pressure rise")
	chest._advance_animation(0.015)
	check(is_zero_approx(chest.hold_effect_snapshot().pulse_motion)
		and cues.back() == ["space", "anticipation", 0],
		"The final drive replaces a delayed rhythmic kick without repeating its sound")
	chest.clear()
	chest.configure_skin(data.theme("space"), data.chests)
	chest.start_open(false)
	cues.clear()
	chest._advance_animation(Feel.ANTICIPATION_TIME + 0.001)
	check(not cues.any(func(item): return item[1] == "tension_pulse")
		and is_zero_approx(chest.hold_effect_snapshot().pulse_motion),
		"A frame returning during the final drive never invents a stale rhythmic strike")
	for return_time in [Feel.ANTICIPATION_TIME + 0.10, Feel.RELEASE_TIME + 0.02]:
		chest.clear()
		chest.configure_skin(data.theme("space"), data.chests)
		chest.start_open(false)
		cues.clear()
		chest._advance_animation(return_time)
		check(not cues.any(func(item): return item[1] in ["tension_pulse", "anticipation"]),
			"A long frame at %.2f seconds skips the stale transition rise and prior rhythmic strikes" % return_time)
		chest.finish_immediately()
		check(not cues.any(func(item): return item[1] == "anticipation"),
			"Finishing after a stalled final drive cannot replay its transition rise")
	chest.free()
	_check_shared_pulse_motion(data)
	_check_small_stage_pixels(data)
	_check_pressure_release(data)
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
		var previous_direction: float = 0.0
		for index in range(Feel.HOLD_PULSE_TIMES.size()):
			var beat: float = float(Feel.HOLD_PULSE_TIMES[index])
			chest.set_hold_progress((beat + 0.00001) / Feel.HOLD_SECONDS)
			var onset: Dictionary = chest.hold_effect_snapshot()
			chest.set_hold_progress((beat + 0.025) / Feel.HOLD_SECONDS)
			var struck: Dictionary = chest.hold_effect_snapshot()
			var direction: float = signf(struck.pulse_motion)
			check(struck.cues.filter(func(cue): return cue.cue == "hold_pulse").size() == index + 1
				and absf(onset.pulse_motion) > 0.0 and absf(struck.pulse_motion) > absf(onset.pulse_motion),
				"The %s hold beat %d responds immediately then accelerates into its body motion" % [theme, index + 1])
			check(index == 0 or direction != previous_direction,
				"The %s hold alternates its body impulse with each material strike" % theme)
			previous_direction = direction
		check(Feel.HOLD_PULSE_TIMES[0] <= 0.08,
			theme + " authors its first rhythmic cue within eighty milliseconds of pressing")
		chest.set_hold_progress(1.0)
		chest.start_open(false)
		var early: float = 0.0
		var late: float = 0.0
		for index in range(Feel.PULSE_TIMES.size()):
			var beat: float = float(Feel.PULSE_TIMES[index])
			chest._advance_animation(beat + 0.00001 - chest.hold_effect_snapshot().opening_time)
			var onset: Dictionary = chest.hold_effect_snapshot()
			chest._advance_animation(0.025)
			var struck: Dictionary = chest.hold_effect_snapshot()
			var amplitude: float = absf(struck.pulse_motion)
			var direction: float = signf(struck.pulse_motion)
			check(struck.cues.filter(func(cue): return cue.cue == "tension_pulse").size() == index + 1
				and amplitude > absf(onset.pulse_motion) and absf(onset.pulse_motion) > 0.0,
				"The %s tension beat %d accelerates into motion after the matching audible cue" % [theme, index + 1])
			check(direction != previous_direction and direction == signf(struck.physical_pose.rotation),
				"The %s opening carries the alternating rocking direction through confirmation" % theme)
			if theme != "candy":
				check(is_equal_approx(struck.physical_pose.scale_x, 1.0) and is_equal_approx(struck.physical_pose.scale_y, 1.0),
					"The %s rigid body keeps its dimensions while its mechanism strains" % theme)
			if index < 3:
				early += amplitude
			elif index >= Feel.PULSE_TIMES.size() - 3:
				late += amplitude
			previous_direction = direction
		check(late > early * 1.25, theme + " builds a stronger final roll without requiring a large flat slide")
		chest._advance_animation(Feel.ANTICIPATION_TIME - chest.hold_effect_snapshot().opening_time + 0.001)
		var final_pose: Array = _poses(chest)
		chest._advance_animation(Feel.UNLOCK_TIME - chest.hold_effect_snapshot().opening_time - 0.01)
		check(_poses(chest) != final_pose and is_zero_approx(chest.hold_effect_snapshot().pulse_motion),
			theme + " carries continuous physical strain from its last strike into unlocking")
	chest.free()


func _body_center(chest) -> Vector2:
	for piece in chest._pieces:
		if piece.role in ["body", "chest"]:
			var sprite: Sprite2D = piece.node
			return sprite.get_screen_transform() * sprite.get_rect().get_center()
	return Vector2.ZERO


func _stage_point(chest, value: Dictionary) -> Vector2:
	return chest.get_screen_transform() * Vector2(value.x, value.y)


func _check_small_stage_pixels(data) -> void:
	var previous_mode: int = root.content_scale_mode
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	chest.set_process(false)
	for theme in data.THEMES:
		for dimensions in [Vector2(320, 72), Vector2(320, 110)]:
			chest.clear()
			chest.size = dimensions
			chest.configure_skin(data.theme(theme), data.chests)
			chest.begin_hold()
			chest.set_hold_progress((float(Feel.HOLD_PULSE_TIMES[0]) - 0.001) / Feel.HOLD_SECONDS)
			var before: Vector2 = _body_center(chest)
			chest.set_hold_progress((float(Feel.HOLD_PULSE_TIMES[0]) + 0.00001) / Feel.HOLD_SECONDS)
			chest.set_hold_progress((float(Feel.HOLD_PULSE_TIMES[0]) + 0.025) / Feel.HOLD_SECONDS)
			var first: float = _body_center(chest).distance_to(before)
			check(first >= 0.5, "%s at %s: the first accelerating hold beat is visible at %.2f screen pixels" % [theme, dimensions, first])
			var pressed: Vector2 = _body_center(chest)
			chest.cancel_hold()
			check(_body_center(chest).distance_to(pressed) < 0.1,
				"Cancelling %s at %s begins from the actual last body position without snapping" % [theme, dimensions])
			chest._advance_animation(Feel.CANCEL_SECONDS + 0.001)
			check(is_zero_approx(chest.hold_effect_snapshot().pulse_motion),
				"Cancelled %s at %s leaves no live or delayed rhythm" % [theme, dimensions])
			var last: float = float(Feel.PULSE_TIMES.back())
			chest.clear()
			chest.configure_skin(data.theme(theme), data.chests)
			chest.start_open(false)
			var late: float = 0.0
			for beat in Feel.PULSE_TIMES:
				chest._advance_animation(float(beat) - 0.001 - chest.hold_effect_snapshot().opening_time)
				before = _body_center(chest)
				var planted: Dictionary = chest.hold_effect_snapshot()
				chest._advance_animation(0.00101)
				chest._advance_animation(0.025)
				if is_equal_approx(float(beat), last):
					late = _body_center(chest).distance_to(before)
					var struck: Dictionary = chest.hold_effect_snapshot()
					var base_delta: Vector2 = _stage_point(chest, struck.grounding_pivot) - _stage_point(chest, planted.grounding_pivot)
					var shadow_delta: Vector2 = _stage_point(chest, struck.ground_center) - _stage_point(chest, planted.ground_center)
					check(absf(base_delta.y) < 1.0 and absf(shadow_delta.x) < absf(base_delta.x) * 0.5,
						"The %s base remains grounded and its shadow resists the body rocking at %s" % [theme, dimensions])
					if theme != "candy":
						check(absf((_body_center(chest) - before).x) > absf(base_delta.x),
							"The %s upper body rocks farther than its feet at %s" % [theme, dimensions])
			check(late >= 2.0 and late > first, "%s at %s: the final roll grows to %.2f screen pixels while retaining weight" % [theme, dimensions, late])
	chest.free()
	root.content_scale_mode = previous_mode


func _lid_poses(chest) -> Array:
	var poses: Array = []
	for piece in chest._pieces:
		if piece.role == "lid_outer" or (chest._style == "crystal" and piece.role not in ["chest", "01"]):
			poses.append(piece.node.transform)
	return poses


func _check_pressure_release(data) -> void:
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	chest.set_process(false)
	chest.size = Vector2(440, 360)
	var colors: Array = []
	for theme in data.THEMES:
		chest.clear()
		chest.reduced_motion = false
		chest.configure_skin(data.theme(theme), data.chests)
		var resting_lid: Array = _lid_poses(chest)
		chest.begin_hold()
		chest.set_hold_progress(0.2)
		var early_pressure: float = chest.hold_effect_snapshot().lid_pressure
		chest.set_hold_progress(1.0)
		chest.start_open(false)
		chest._advance_animation(Feel.ANTICIPATION_TIME)
		var ready: Dictionary = chest.hold_effect_snapshot()
		check(ready.lid_pressure > early_pressure + 0.5 and _lid_poses(chest) != resting_lid,
			theme + " stores visible pressure in its actual lid or facets before the final rise")
		check(is_zero_approx(ready.release_flash), theme + " keeps its release flash out of the buildup")
		var prior_final_pose: Array = _poses(chest)
		var prior_pressure: float = ready.lid_pressure
		var prior_drive: float = ready.final_drive
		for time in [Feel.ANTICIPATION_TIME + 0.06, Feel.UNLOCK_TIME - 0.001,
			Feel.RELEASE_TIME - 0.03, Feel.RELEASE_TIME - 0.001]:
			chest._advance_animation(time - chest.hold_effect_snapshot().opening_time)
			var driving: Dictionary = chest.hold_effect_snapshot()
			check(_poses(chest) != prior_final_pose and driving.lid_pressure > prior_pressure
				and driving.final_drive > prior_drive
				and driving.percent < 100 and driving.interior_open == 0.0,
				"The %s final rise keeps loading a closed chest at %.3f seconds without a stationary gap" % [theme, time])
			prior_final_pose = _poses(chest)
			prior_pressure = driving.lid_pressure
			prior_drive = driving.final_drive
		chest._advance_animation(Feel.RELEASE_TIME - chest.hold_effect_snapshot().opening_time)
		var released: Dictionary = chest.hold_effect_snapshot()
		var release_lid: Array = _lid_poses(chest)
		check(released.release_flash >= 0.5 and released.percent == 100,
			theme + " visibly releases stored light on the same beat that progress reaches 100 percent")
		check(not colors.has(released.release_color), theme + " has a distinct release light color")
		colors.append(released.release_color)
		var origin := Vector2(released.light_origin.x, released.light_origin.y)
		var belongs_to_body: bool = false
		for piece in chest._pieces:
			if piece.role in ["body", "chest"]:
				var rect: Rect2 = piece.node.get_rect()
				var transform: Transform2D = chest._art.transform * piece.node.transform
				var body_bounds := Rect2(transform * rect.position, Vector2.ZERO)
				for corner in [Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
					body_bounds = body_bounds.expand(transform * corner)
				belongs_to_body = body_bounds.has_point(origin)
		check(Rect2(Vector2.ZERO, chest.size).has_point(origin) and belongs_to_body,
			theme + " anchors its light inside the fitted chest instead of the screen center")
		chest._advance_animation(0.065)
		check(chest.hold_effect_snapshot().release_flash >= 0.9 and _lid_poses(chest) != release_lid,
			theme + " opens real parts while its release flash peaks, without a delayed separate celebration")
		for drag in [Vector2.ZERO, Vector2(-440.0, 0.0), Vector2(440.0, 0.0)]:
			chest.set_drag_offset(drag)
			var spread: Dictionary = chest.hold_effect_snapshot()
			var center := Vector2(spread.light_origin.x, spread.light_origin.y)
			var radius := Vector2(spread.release_radius.x, spread.release_radius.y)
			var safe: Dictionary = spread.release_bounds
			var safe_bounds := Rect2(Vector2(safe.x, safe.y), Vector2(safe.width, safe.height))
			check(Rect2(Vector2.ZERO, chest.size).encloses(safe_bounds)
				and safe_bounds.encloses(Rect2(center - radius, radius * 2.0))
				and radius.x > 0.0 and radius.y > 0.0,
				"The %s broad flash remains inside its safe stage even at drag %s" % [theme, drag])
		chest.set_drag_offset(Vector2.ZERO)
		var peak_flash: float = chest.hold_effect_snapshot().release_flash
		chest._advance_animation(0.3)
		check(chest.hold_effect_snapshot().release_flash > 0.0
			and chest.hold_effect_snapshot().release_flash < peak_flash,
			theme + " carries a fading colored tail after its initial flash")
		chest._advance_animation(Feel.OPEN_SECONDS - chest.hold_effect_snapshot().opening_time - 0.01)
		check(is_zero_approx(chest.hold_effect_snapshot().release_flash),
			theme + " lets the single flash decay before the saved reward result")
		chest.finish_immediately()
		check(is_zero_approx(chest.hold_effect_snapshot().release_flash), theme + " leaves no lingering flash on its saved result")
		for interrupted in ["cancel", "skip", "reduced"]:
			chest.clear()
			chest.configure_skin(data.theme(theme), data.chests)
			chest.reduced_motion = interrupted == "reduced"
			chest.begin_hold()
			chest.set_hold_progress(0.8)
			if interrupted == "cancel":
				chest.cancel_hold()
			else:
				chest.start_open(chest.reduced_motion)
				chest.finish_immediately()
			chest._advance_animation(Feel.RELEASE_TIME + 0.065)
			check(is_zero_approx(chest.hold_effect_snapshot().release_flash),
				"The %s %s path cannot replay a missed release flash" % [theme, interrupted])
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
		chest._advance_animation(Feel.UNLOCK_TIME - 0.001)
		var armed_poses: Dictionary = {}
		for piece in chest._pieces:
			armed_poses[piece.role] = piece.node.transform
		chest._advance_animation(Feel.RELEASE_TIME - Feel.UNLOCK_TIME)
		var core_moves: bool = false
		var panels_wait: bool = true
		for piece in chest._pieces:
			var armed: Transform2D = armed_poses[piece.role]
			var actual: Transform2D = piece.node.transform
			var displacement: float = actual.origin.distance_to(armed.origin)
			if piece.role == "01":
				core_moves = displacement > 5.0
			elif piece.role != "chest":
				panels_wait = panels_wait and displacement < 1.0 and absf(actual.get_rotation() - armed.get_rotation()) < 0.002
		check(core_moves and panels_wait, theme + " unlocks its central crystal while its outer panels retain their armed pose")
		check(chest.hold_effect_snapshot().interior_open == 0.0, theme + " keeps the cavity sealed until the release beat")
		chest._advance_animation(0.18)
		var spreading_panels: int = 0
		for piece in chest._pieces:
			if piece.role not in ["chest", "01"]:
				var armed: Transform2D = armed_poses[piece.role]
				var actual: Transform2D = piece.node.transform
				if actual.origin.distance_to(armed.origin) > 5.0:
					spreading_panels += 1
		check(spreading_panels >= 2, theme + " spreads its outer panels only after the release beat")
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
				Feel.RELEASE_TIME - 0.01, Feel.RELEASE_TIME + 0.065, Feel.RELEASE_TIME + 0.12, Feel.RELEASE_TIME + 0.29,
				Feel.RELEASE_TIME + 0.44, Feel.SETTLE_TIME, Feel.OPEN_SECONDS]:
				chest._advance_animation(time - prior)
				prior = time
				var state: Dictionary = chest.hold_effect_snapshot()
				var physical: Dictionary = state.physical_bounds
				var bounds := Rect2(Vector2(physical.x, physical.y), Vector2(physical.width, physical.height))
				if not stage.encloses(bounds) or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
					outside.append("%.2fs: %s" % [time, bounds])
				if is_equal_approx(time, Feel.RELEASE_TIME + 0.065):
					var origin := Vector2(state.light_origin.x, state.light_origin.y)
					var radius := Vector2(state.release_radius.x, state.release_radius.y)
					var safe: Dictionary = state.release_bounds
					var safe_bounds := Rect2(Vector2(safe.x, safe.y), Vector2(safe.width, safe.height))
					check(stage.encloses(safe_bounds) and safe_bounds.encloses(Rect2(origin - radius, radius * 2.0)),
						"The %s release bloom stays within its safe extent at %s" % [theme, dimensions])
					if dimensions.x >= 320.0 and dimensions.x >= dimensions.y * 2.0:
						check(radius.x * 2.0 >= dimensions.x * 0.80,
							"The %s release fills at least eighty percent of its centered wide stage at %s" % [theme, dimensions])
			check(outside.is_empty(), "The %s material motion stays inside %s through every physical beat: %s" % [theme, dimensions, outside])
	chest.free()
