extends SceneTree
## Check Pip's real victory presentation without reading or writing player saves.

const Celebration = preload("res://scripts/talk_quest_celebration.gd")
const OUTPUT := "res://build/talk-quest-celebration-review"
const LAYOUTS := [
	{"label": "desktop", "size": Vector2i(720, 400)},
	{"label": "phone", "size": Vector2i(366, 360)},
	{"label": "small-phone", "size": Vector2i(296, 214)},
	{"label": "compact-landscape", "size": Vector2i(328, 140)},
]

var checks: int = 0
var failures: int = 0
var _capture: bool = false


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _check_lifecycle(view) -> void:
	var completions: Array[int] = [0]
	view.finished.connect(func() -> void: completions[0] += 1)
	view.reset()
	check(view.begin("ocean") and view.active and view.pip.dancing and view.pip.theme_id == "ocean",
		"A fresh victory begins the real Pip dance in the selected world's costume")
	view._process(0.8)
	var elapsed: float = view.elapsed
	var progress: float = view.pip.dance_progress
	for refresh in range(6):
		check(not view.begin("ocean"), "Refreshing the same victory does not start another celebration")
	check(is_equal_approx(view.elapsed, elapsed) and is_equal_approx(view.pip.dance_progress, progress),
		"Simple refreshes preserve the dance's current beat")
	view.pause()
	view._process(2.0)
	check(view.paused and is_equal_approx(view.elapsed, elapsed) and not view.is_processing(),
		"Pause freezes the current beat without emitting completion")
	check(completions[0] == 0, "Pausing never advances the surrounding reward flow")
	view.resume()
	view._process(0.4)
	check(not view.paused and view.active and view.elapsed > elapsed,
		"Explicit resume continues the remaining celebration")
	elapsed = view.elapsed
	view.hide()
	view._process(1.0)
	view.show()
	check(view.paused and is_equal_approx(view.elapsed, elapsed) and not view.begin("ocean"),
		"Hiding and redisplaying the component cannot replay or silently resume its dance")
	view.resume()
	view._process(Celebration.DURATION - view.elapsed - 0.01)
	check(view.active and completions[0] == 0, "The dance remains active until its 3.2-second presentation completes")
	view._process(0.02)
	check(view.settled and not view.active and not view.pip.dancing and completions[0] == 1,
		"Natural completion produces one happy settled pose and one completion signal")
	view._process(10.0)
	view.begin("ocean")
	view.settle()
	check(completions[0] == 1 and not view.is_processing() and view.snapshot().pip.emotion == "happy",
		"Repeated settlement and later frames cannot emit another completion")
	view.reset()
	view.begin("winter")
	view._process(0.5)
	view.settle()
	check(completions[0] == 1 and view.settled and view.pip.theme_id == "winter",
		"Quiet settlement on a restored chest preserves its costume without triggering a new transition")
	view.set_companion_mode(true)
	check(not view.headline.visible and not view.note.visible and view.snapshot().companion_mode,
		"Companion mode leaves the happy Pip artwork without a duplicate chest headline")
	view.reset()
	view.set_companion_mode(false)
	view.set_reduced_motion(true)
	check(view.begin("spring") and not view.pip.dancing and view.active and view.is_processing(),
		"Reduced motion shows a static happy Pip while retaining the victory interval")
	view._process(1.0)
	check(not view.pip.dancing and view.snapshot().pip.pose == "wave" and view.active,
		"The reduced-motion pose stays happy and still throughout the interval")
	view.set_reduced_motion(false)
	check(view.pip.dancing and is_equal_approx(view.elapsed, 1.0),
		"Changing motion preferences preserves elapsed victory time")
	view.set_reduced_motion(true)
	view._process(2.21)
	check(view.settled and completions[0] == 2 and not view.is_processing(),
		"Reduced motion completes on schedule without leaving an animation loop")
	view.reset()
	check(not view.visible and not view.active and not view.settled and is_zero_approx(view.elapsed),
		"Reset clears the presentation so a later victory can celebrate again")
	view.set_reduced_motion(false)


func _check_geometry(view, label: String) -> void:
	var bounds := Rect2(Vector2.ZERO, view.size)
	check(bounds.encloses(view.pip.get_rect()), label + " contains the complete Pip art slot")
	if not view.companion_mode:
		check(bounds.encloses(view.headline.get_rect()) and bounds.encloses(view.note.get_rect()),
			label + " contains both congratulatory lines")
		check(not view.pip.get_rect().intersects(view.headline.get_rect())
			and not view.pip.get_rect().intersects(view.note.get_rect())
			and not view.headline.get_rect().intersects(view.note.get_rect()),
			label + " separates Pip from the congratulatory copy")
	check(view.mouse_filter == Control.MOUSE_FILTER_IGNORE and view.pip.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and view.pip.focus_mode == Control.FOCUS_NONE,
		label + " leaves underlying navigation and treasure gestures available")


func _render(view) -> Image:
	view.set_process(false)
	view.pip.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _save(view, label: String) -> void:
	if not _capture:
		return
	var frame: Image = await _render(view)
	check(frame != null and not frame.is_empty() and frame.save_png(OUTPUT + "/" + label + ".png") == OK,
		"The actual Pip celebration renders " + label)


func _run() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture")
	if _capture and DisplayServer.get_name() == "headless":
		printerr("Celebration capture requires the real renderer; omit --headless and use --audio-driver Dummy.")
		quit(1)
		return
	if _capture:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var view = Celebration.new()
	root.add_child(view)
	view.size = Vector2(720, 400)
	view.set_ui_scale(1.0)
	_check_lifecycle(view)
	for layout: Dictionary in LAYOUTS:
		root.size = layout.size
		view.size = Vector2(layout.size)
		view.reset()
		view.begin("spring")
		view._process(0.4)
		view.layout()
		_check_geometry(view, str(layout.label))
		await _save(view, str(layout.label) + "-dance")
		view.settle()
		await _save(view, str(layout.label) + "-happy")
	view.set_companion_mode(true)
	root.size = Vector2i(120, 120)
	view.size = Vector2(120, 120)
	_check_geometry(view, "chest companion")
	await _save(view, "chest-companion")
	view.set_companion_mode(false)
	view.set_ui_scale(2.0)
	view.size = Vector2(183, 180)
	_check_geometry(view, "stretched phone")
	check(view.note.get_theme_font_size("font_size") * 2.0 >= 12.0
		and view.note.get_theme_font_size("font_size") * 2.0 <= 17.0,
		"The application's stretched viewport retains readable physical caption size")
	if _capture:
		view.set_ui_scale(1.0)
		root.size = Vector2i(366, 360)
		view.size = Vector2(366, 360)
		view.reset()
		view.set_reduced_motion(true)
		view.begin("spring")
		var first: Image = await _render(view)
		view._process(1.2)
		var second: Image = await _render(view)
		check(first.get_data() == second.get_data(), "Reduced motion preserves identical rendered happy Pip pixels over time")
		check(second.save_png(OUTPUT + "/phone-reduced-motion.png") == OK,
			"The reduced-motion Pip pose is available for visual review")
	view.free()
	print("Talk Quest celebration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
