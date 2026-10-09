extends SceneTree

const Mascot = preload("res://scripts/duck_mascot.gd")

var checks := 0
var failures := 0
var draws := 0
var duck: Mascot


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	duck.set_process(false)
	for frame in range(3):
		await process_frame


func tick(delta: float) -> int:
	var before: int = draws
	duck._process(delta)
	await settle()
	return draws - before


func reset() -> void:
	duck.show()
	duck.set_idle_paused(false)
	duck.set_reduced_motion(false)
	duck.set_proactive_allowed(false)
	duck.settle()
	await settle()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(360, 300)
	duck = Mascot.new()
	duck.position = Vector2(100, 100)
	duck.draw.connect(func() -> void: draws += 1)
	root.add_child(duck)
	duck.size = Vector2(112, 112)
	duck.set_growth_level(12)
	await reset()
	check(draws > 0, "The fixture observes real CanvasItem redraws")
	await _check_discrete_frames()
	await _check_continuous_frames()
	await _check_explicit_changes()
	await _check_small_gameplay_sparkles()
	duck.queue_free()
	await process_frame
	print("Mascot redraws: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_discrete_frames() -> void:
	var before: int = draws
	for frame in range(20):
		await tick(0.025)
	check(draws == before and is_equal_approx(duck._idle_time, 0.5),
		"Quiet idle advances its clock without rebuilding unchanged drawing commands")
	duck._idle_time = 4.40
	check(await tick(0.03) > 0 and duck.pose == 2, "The blink redraws as soon as the eyes close")
	check(await tick(0.05) == 0 and duck.pose == 2, "A held blink reuses the same sheet frame")
	check(await tick(0.13) > 0 and duck.pose == 0, "The blink redraws when the eyes reopen")
	duck.set_speaking(true)
	await settle()
	check(duck.pose == 1, "Speech immediately presents the open beak")
	check(await tick(0.05) == 0, "Speech holds its original sheet frame between beak changes")
	check(await tick(0.08) > 0 and duck.pose == 0, "Speech repaints at the existing eight-frame-per-second boundary")
	before = draws
	duck.set_speaking(false)
	await settle()
	check(draws > before and duck.pose == 0,
		"Stopping speech removes the sound arcs even when its closed-beak pose is unchanged")


func _check_continuous_frames() -> void:
	for action in ["curious", "happy", "wave", "peekaboo", "high-five", "dance-wave", "dance-hop", "success", "miss", "idle"]:
		await reset()
		match action:
			"curious", "happy": duck.react(action)
			"wave", "peekaboo", "high-five", "dance-wave", "dance-hop": duck.perform_trick(action)
			"success", "miss": duck.react_gameplay(action == "success")
			"idle":
				duck.set_proactive_allowed(true)
				duck._idle_wait = 0.01
				await tick(0.02)
		await settle()
		var every_frame := true
		for frame in range(8):
			every_frame = await tick(1.0 / 60.0) > 0 and every_frame
		check(every_frame, "Every original animation frame remains drawn for " + action)
	await reset()
	duck.react("curious")
	await settle()
	duck.reaction_left = 0.001
	check(await tick(0.02) > 0 and duck.pose == 0,
		"A reaction's final clearing frame redraws even when the sheet pose stays unchanged")
	check(await tick(0.02) == 0, "The cleared reaction returns to cached idle drawing")
	await reset()
	duck.perform_trick("wave")
	await settle()
	duck._idle_left = 0.001
	check(await tick(0.02) > 0 and duck._idle_action.is_empty(), "The final trick frame removes every transient effect")
	check(await tick(0.02) == 0, "A completed trick no longer causes continuous redraws")


func _check_explicit_changes() -> void:
	await reset()
	var before: int = draws
	duck.set_growth_level(11)
	await settle()
	check(draws > before, "An earned growth appearance change redraws a quiet mascot")
	before = draws
	duck.size += Vector2(12, 12)
	await settle()
	check(draws > before, "Resizing redraws the source artwork at its new bounds")
	before = draws
	duck.accent = Color.CORAL
	duck.queue_redraw()
	await settle()
	check(draws > before, "The existing explicit accent redraw remains effective")
	duck.set_reduced_motion(true)
	duck.react_gameplay(false)
	await settle()
	check(await tick(0.2) == 0 and duck.pose == 2, "Reduced-motion feedback holds its authored static expression")
	check(await tick(2.0) > 0 and duck._gameplay_reaction.is_empty(), "Reduced-motion feedback still repaints its timed dismissal")
	duck.hide()
	await settle()
	check(await tick(0.1) == 0, "Hidden mascots do not draw or advance their reactions")
	duck.show()
	await settle()
	check(duck.is_visible_in_tree(), "Showing the mascot retains the ordinary visibility lifecycle")


func _check_small_gameplay_sparkles() -> void:
	await reset()
	# These frames sit just above the existing visible-radius guard on each side
	# of the happy envelope. Absolute-coordinate stars used to fail triangulation.
	var samples: Array[float] = [0.00161, 0.0017, 0.0018, 0.002, 0.0022, 0.0028,
		0.9953, 0.9952, 0.9950, 0.9947, 0.9943, 0.9940]
	for edge: float in [52.0, 112.0]:
		duck.size = Vector2.ONE * edge
		duck.react_gameplay(true)
		for progress: float in samples:
			var envelope: float = smoothstep(0.0, 0.055, progress) * (1.0 - smoothstep(0.84, 1.0, progress))
			check(4.0 * envelope > 0.01 and 4.0 * envelope < 0.04,
				"The sparkle regression exercises a visible near-zero radius at %.5f" % progress)
			duck._gameplay_left = duck._gameplay_duration() * (1.0 - progress)
			var before: int = draws
			duck._update_pose()
			await settle()
			check(draws > before and duck._gameplay_reaction == "happy",
				"The complete happy frame renders at edge %.0f and progress %.5f" % [edge, progress])
	await reset()
