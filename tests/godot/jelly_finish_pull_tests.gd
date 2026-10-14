extends SceneTree

const Finish = preload("res://scripts/jelly_finish_button.gd")
const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(5):
		await process_frame


func pointer(point: Vector2, pressed: bool, touch: bool = false, index: int = 0) -> void:
	if touch:
		var event := InputEventScreenTouch.new()
		event.position = point
		event.index = index
		event.pressed = pressed
		root.push_input(event, true)
	else:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, true)


func motion(point: Vector2, touch: bool = false, index: int = 0) -> void:
	if touch:
		var event := InputEventScreenDrag.new()
		event.position = point
		event.index = index
		root.push_input(event, true)
	else:
		var event := InputEventMouseMotion.new()
		event.position = point
		event.global_position = point
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(event, true)


func key_accept() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		root.push_input(event, true)


func relax(button) -> void:
	for frame in range(180):
		button.advance(1.0 / 60.0)


func check_tap_response(button, context: String, cues: Array[int], commits: Array[int], requests: Array[int]) -> void:
	var fixed_target: Rect2 = button.get_global_rect()
	var peak: float = 0.0
	var recovery: float = 0.0
	var safe: bool = true
	var stable_target: bool = true
	for frame in range(120):
		button.advance(1.0 / 60.0)
		var state: Dictionary = button.snapshot()
		peak = maxf(peak, float(state.visual_pull))
		recovery = minf(recovery, float(state.visual_pull))
		safe = safe and not state.pulling and not state.armed and not state.glow
		stable_target = stable_target and button.get_global_rect().is_equal_approx(fixed_target)
	check(peak > float(button.snapshot().threshold) * 0.2 and peak < float(button.snapshot().threshold),
		context + ": a tap visibly demonstrates a short downward pull below the finish threshold")
	check(recovery < -0.1 and absf(recovery) < 8.0,
		context + ": the tap demonstration has a small elastic overshoot on its return")
	check(safe and cues.is_empty() and commits.is_empty() and requests.is_empty(),
		context + ": the demonstration never captures a pointer, arms, sounds ready, or finishes")
	check(stable_target, context + ": the tap demonstration preserves the header layout and hit target")
	check(not button.snapshot().tap_hint and not button.snapshot().returning and absf(float(button.snapshot().visual_pull)) < 0.5,
		context + ": the tap demonstration returns to its resting shape")


func check_tap_interruption(button) -> void:
	var start: Vector2 = button.get_global_rect().get_center()
	pointer(start, true, true)
	motion(start + Vector2(3, 2), true)
	pointer(start + Vector2(3, 2), false, true)
	check(button.snapshot().tap_hint, "A small touch wobble still receives the downward tap demonstration")
	button.advance(0.1)
	check(float(button.snapshot().visual_pull) > 0.0, "The explicit tap cue begins immediately")
	button.set_hint_allowed(false)
	button.advance(0.04)
	check(button.snapshot().tap_hint and float(button.snapshot().visual_pull) > 0.0,
		"Suppressing idle invitations does not suppress the player's explicit tap feedback")
	button.set_hint_allowed(true)
	pointer(start, true, true)
	check(button.is_pulling() and not button.snapshot().tap_hint and is_zero_approx(float(button.snapshot().visual_pull)),
		"A new touch interrupts the demonstration and gives direct control of the jelly")
	motion(start + Vector2(0, 24), true)
	motion(start, true)
	pointer(start, false, true)
	check(not button.snapshot().tap_hint, "A deliberate drag returning to its start is not mistaken for a tap")
	button.cancel_pull(true)
	for interruption: String in ["cancel", "disable", "hide", "resize", "focus", "app_focus"]:
		pointer(start, true)
		pointer(start, false)
		button.advance(0.1)
		check(button.snapshot().tap_hint and float(button.snapshot().visual_pull) > 0.0,
			"The tap demonstration is active before " + interruption)
		match interruption:
			"cancel": button.cancel_pull(true)
			"disable":
				button.disabled = true
				button.advance(1.0 / 60.0)
			"hide": button.hide()
			"resize":
				button.size += Vector2(1, 0)
				await settle()
			"focus": button.release_focus()
			"app_focus": button.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(not button.snapshot().tap_hint and is_zero_approx(float(button.snapshot().visual_pull)),
			interruption + ": interruption clears the tap cue without leaving a stretched button")
		button.disabled = false
		button.show()
		button.advance(1.0 / 60.0)
		start = button.get_global_rect().get_center()
		button.advance(0.2)
		check(not button.snapshot().tap_hint and is_zero_approx(float(button.snapshot().visual_pull)),
			interruption + ": the interrupted cue cannot restart later")
	pointer(start, true)
	button.release_pointer(-1)
	await process_frame
	check(not button.is_pulling() and not button.snapshot().tap_hint,
		"A missing host release safely cancels without pretending the player tapped")
	button.size = Vector2(84, 44)
	await settle()


func check_component() -> void:
	root.size = Vector2i(640, 720)
	var button = Finish.new()
	root.add_child(button)
	button.position = Vector2(400, 24)
	button.size = Vector2(84, 44)
	button.configure(Color("e2a268"), 1.0, false)
	button.set_process(false)
	var cues: Array[int] = []
	var commits: Array[int] = []
	var requests: Array[int] = []
	button.threshold_reached.connect(func() -> void: cues.append(1))
	button.finish_committed.connect(func() -> void: commits.append(1))
	button.accessibility_requested.connect(func() -> void: requests.append(1))
	await settle()
	var start: Vector2 = button.get_global_rect().get_center()
	var threshold: float = float(button.snapshot().threshold)
	check(threshold >= 70.0 and threshold <= 110.0, "Finish needs a deliberate but reachable pull distance")
	for touch: bool in [false, true]:
		var context: String = "touch" if touch else "mouse"
		pointer(start, true, touch)
		check(button.is_pulling(), context + ": the header target owns a real pointer press")
		pointer(start, false, touch)
		check(commits.is_empty() and requests.is_empty(), context + ": a tap neither finishes nor opens keyboard confirmation")
		check_tap_response(button, context, cues, commits, requests)
		pointer(start, true, touch)
		motion(start - Vector2(0, threshold * 0.2), touch)
		check(not button.snapshot().armed and float(button.snapshot().progress) <= 0.01,
			context + ": upward movement cannot arm a downward gesture")
		motion(start + Vector2(threshold * 2.0, threshold * 1.2), touch)
		check(not button.snapshot().armed and cues.is_empty(),
			context + ": a mostly sideways drag cannot arm Finish outside its pull lane")
		motion(start + Vector2(0, threshold * 0.4), touch)
		button.advance(0.08)
		var short_pull: Dictionary = button.snapshot()
		check(short_pull.pulling and not short_pull.armed and float(short_pull.visual_pull) > 0.0,
			context + ": a partial drag deforms the jelly while remaining reversible")
		motion(start + Vector2(0, threshold * 0.8), touch)
		button.advance(0.08)
		check(float(button.snapshot().visual_pull) > float(short_pull.visual_pull),
			context + ": longer pulls produce greater deformation")
		pointer(start + Vector2(0, threshold * 0.8), false, touch)
		check(not button.is_pulling() and commits.is_empty() and cues.is_empty(),
			context + ": releasing below threshold cancels without a success cue")
		relax(button)
		check(not button.snapshot().returning and absf(float(button.snapshot().visual_pull)) < 0.5,
			context + ": cancellation springs completely back to the stable header target")
		pointer(start, true, touch)
		motion(start + Vector2(0, threshold * 1.15), touch)
		button.advance(0.08)
		check(button.snapshot().armed and float(button.snapshot().glow) > 0.0 and cues.size() == 1,
			context + ": crossing the threshold arms, lights, and signals once")
		var header_target: Rect2 = button.get_global_rect()
		motion(start + Vector2(0, threshold * 6.0), touch)
		check(float(button.snapshot().visual_pull) <= float(button.snapshot().max_pull)
			and button.get_global_rect().is_equal_approx(header_target),
			context + ": a very long pull remains bounded without pushing header layout or its hit target")
		for repeat in range(4):
			motion(start + Vector2(0, threshold * 1.3), touch)
		check(cues.size() == 1 and commits.is_empty(), context + ": holding beyond the threshold never repeats the cue or commits early")
		if touch:
			pointer(start + Vector2(0, threshold * 1.3), false, true, 1)
			check(button.is_pulling() and commits.is_empty(), "A second finger cannot release the first finger's Finish gesture")
		motion(start + Vector2(0, threshold * 0.3), touch)
		check(not button.snapshot().armed, context + ": retreating below the threshold disarms the release")
		motion(start + Vector2(0, threshold * 1.15), touch)
		check(button.snapshot().armed and cues.size() == 1,
			context + ": reentering the threshold restores the glow without repeating its sound")
		motion(start + Vector2(0, threshold * 0.3), touch)
		pointer(start + Vector2(0, threshold * 0.3), false, touch)
		check(commits.is_empty(), context + ": retreat and release preserves the round")
		relax(button)
		cues.clear()
		pointer(start, true, touch)
		motion(start + Vector2(0, threshold * 1.15), touch)
		button.cancel_pull()
		pointer(start + Vector2(0, threshold * 1.15), false, touch)
		check(commits.is_empty() and not button.is_pulling(), context + ": cancellation invalidates the later translated release")
		relax(button)
		cues.clear()
		pointer(start, true, touch)
		motion(start + Vector2(0, threshold * 1.15), touch)
		button.release_pointer(0 if touch else -1)
		await process_frame
		check(not button.is_pulling() and commits.is_empty(),
			context + ": a host release without its engine event safely cancels the gesture")
		pointer(start + Vector2(0, threshold * 1.15), false, touch)
		check(commits.is_empty(), context + ": a stale release cannot revive the canceled gesture")
		relax(button)
		cues.clear()
		pointer(start, true, touch)
		motion(start + Vector2(0, threshold * 1.15), touch)
		button.release_pointer(0 if touch else -1)
		pointer(start + Vector2(0, threshold * 1.15), false, touch)
		pointer(start + Vector2(0, threshold * 1.15), false, touch)
		await process_frame
		check(commits.size() == 1, context + ": an armed release commits exactly once even if release repeats")
		commits.clear()
		cues.clear()
		button.cancel_pull(true)
	await check_tap_interruption(button)
	check(commits.is_empty() and cues.is_empty() and requests.is_empty(),
		"Tap feedback and its interruptions never trigger finishing or a ready cue")
	button.disabled = true
	pointer(start, true)
	motion(start + Vector2(0, threshold * 2.0))
	pointer(start + Vector2(0, threshold * 2.0), false)
	check(not button.is_pulling() and commits.is_empty(), "Disabled Finish cannot capture or commit a gesture")
	button.disabled = false
	button.grab_focus()
	key_accept()
	check(requests.size() == 1 and commits.is_empty(), "Keyboard activation requests the accessible safe confirmation")
	button.configure(Color("e2a268"), 1.0, true)
	button.set_hint_allowed(true)
	pointer(start, true)
	pointer(start, false)
	button.advance(0.2)
	check(not button.snapshot().tap_hint and is_zero_approx(float(button.snapshot().visual_pull)) and commits.is_empty(),
		"Reduced motion keeps tap feedback stationary and never finishes the round")
	var idle_peak: float = 0.0
	for frame in range(1200):
		button.advance(1.0 / 60.0)
		idle_peak = maxf(idle_peak, absf(float(button.snapshot().idle_cue)))
	check(is_zero_approx(idle_peak), "Reduced motion suppresses idle invitation bounces")
	pointer(start, true)
	motion(start + Vector2(0, threshold * 1.15))
	check(button.snapshot().armed, "Reduced motion preserves the explicit pull-and-release action")
	button.cancel_pull(true)
	button.configure(Color("e2a268"), 1.0, false)
	button.set_hint_allowed(true)
	idle_peak = 0.0
	for frame in range(1800):
		button.advance(1.0 / 60.0)
		idle_peak = maxf(idle_peak, absf(float(button.snapshot().idle_cue)))
	check(idle_peak > 0.0, "An idle round occasionally invites a downward pull")
	button.set_hint_allowed(false)
	relax(button)
	check(is_zero_approx(float(button.snapshot().idle_cue)), "Busy or hidden gameplay suppresses the idle invitation")
	button.queue_free()
	await settle()


func check_gameplay(mode: String) -> void:
	root.size = Vector2i(393, 852)
	var directory: String = "user://jelly-pull-%s-%d-%d" % [mode, OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	Fixture.enter_mode(app, mode)
	await settle()
	var view = app._active_jelly()
	view.set_process(false)
	view.game.spawn_interval = 10000.0
	view.game.step(2.0)
	view._process(0.0)
	var button = view.finish_button
	button.set_process(false)
	var completions: Array[Dictionary] = []
	view.round_finished.connect(func(result: Dictionary) -> void: completions.append(result))
	var tap_start: Vector2 = button.get_global_rect().get_center()
	pointer(tap_start, true)
	pointer(tap_start, false)
	button.advance(0.1)
	var before_demo: float = view.game.spawn_elapsed
	view._process(0.2)
	check(button.snapshot().tap_hint and not button.is_pulling() and view.game.spawn_elapsed > before_demo,
		mode + ": the tap demonstration teaches pulling without freezing board simulation")
	check(view.game.phase == "playing" and completions.is_empty() and not app._finish_confirmation_open(),
		mode + ": a teaching tap preserves the game without opening confirmation")
	button.cancel_pull(true)
	for interruption: String in ["home", "resize", "page_hidden", "host_cancel"]:
		var start: Vector2 = button.get_global_rect().get_center()
		var end: Vector2 = start + Vector2(0, float(button.snapshot().threshold) * 1.15)
		pointer(start, true)
		motion(end)
		check(button.snapshot().armed and view._pointer == view.NO_POINTER and not view._dragging,
			mode + ": Finish owns the gesture above the board during " + interruption)
		var elapsed: float = view.game.spawn_elapsed
		view._process(0.35)
		check(is_equal_approx(view.game.spawn_elapsed, elapsed),
			mode + ": supply time stays fixed while the player holds Finish")
		var tile_point: Vector2 = view._tiles[int(view.game.cells[0].id)].get_global_rect().get_center()
		pointer(tile_point, true, true, 7)
		motion(tile_point + Vector2(20, 0), true, 7)
		pointer(tile_point + Vector2(20, 0), false, true, 7)
		check(view._pointer == view.NO_POINTER and not view._dragging and button.is_pulling(),
			mode + ": another finger cannot grab a board jelly during the Finish pull")
		match interruption:
			"home": app._show_mode_menu()
			"resize": root.size = Vector2i(390, 844)
			"page_hidden": app.on_page_hidden()
			"host_cancel": app._on_input_canceled()
		await settle()
		pointer(end, false)
		check(view.game.phase == "playing" and completions.is_empty() and not button.is_pulling(),
			mode + ": " + interruption + " cancels an armed pull without a result")
		match interruption:
			"home": app._hide_mode_menu()
			"resize": root.size = Vector2i(393, 852)
			"page_hidden": app.on_page_visible()
		await settle()
		view._refresh_controls()
		relax(button)
	button.grab_focus()
	key_accept()
	check(app._finish_confirmation_open() and view.game.phase == "playing" and view.game.paused,
		mode + ": actual keyboard activation retains the safe accessible decision")
	app._finish_confirmation.keep_playing_button.pressed.emit()
	await settle()
	var start: Vector2 = button.get_global_rect().get_center()
	var end: Vector2 = start + Vector2(0, float(button.snapshot().threshold) * 1.15)
	pointer(start, true, true)
	motion(end, true)
	check(button.snapshot().armed and view.game.phase == "playing", mode + ": arming waits for the same finger's release")
	pointer(end, false, true)
	pointer(end, false, true)
	await settle()
	check(view.game.phase == "finished" and app._settlement_dialog.is_visible_in_tree() and not view.snapshot().result.visible and not app._finish_confirmation_open()
		and completions.size() == 1, mode + ": deliberate touch release opens exactly one settlement modal directly")
	check(not button.is_visible_in_tree() and not button.is_pulling(), mode + ": results hide and reset the external header action")
	app.audio.halt()
	app.queue_free()
	await settle()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	await check_component()
	for mode: String in ["jelly", "word_jelly"]:
		await check_gameplay(mode)
	print("Jelly pull Finish: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
