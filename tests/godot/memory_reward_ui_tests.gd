extends SceneTree

const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const Countdown = preload("res://scripts/memory_peek_countdown.gd")
const Badge = preload("res://scripts/memory_reward_badge.gd")

var checks: int = 0
var failures: int = 0
var skips: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(390, 844)
	var data := Data.new()
	if not data.load_all():
		check(false, "Memory reward UI requires the acquired chest manifest")
		quit(1)
		return
	var clock := Countdown.new()
	root.add_child(clock)
	clock.skip_requested.connect(func() -> void: skips += 1)
	for dimensions: Vector2 in [Vector2(238, 52), Vector2(184, 52), Vector2(500, 44)]:
		clock.size = dimensions
		clock.configure(10.0, 10.0, Data.theme("spring"), false)
		clock.show()
		await process_frame
		var state: Dictionary = clock.snapshot()
		var action: Rect2 = clock.action_button.get_rect()
		check(state.phase == "observation" and not state.phase_label.is_empty(), "The live clock explicitly labels observation")
		check(action.size.y >= 44.0 and action.size.x >= 96.0, "Start matching retains its touch target at %s" % dimensions)
		check(Rect2(Vector2.ZERO, dimensions).encloses(action), "The action stays inside its fixed header row at %s" % dimensions)
		check(clock.bar_rect().end.x <= action.position.x - 4.0, "The countdown does not overlap its Start matching action")
		check(clock.action_button.focus_mode == Control.FOCUS_ALL, "The host can include the real action in keyboard/controller focus")
	clock.set_paused(true)
	clock.action_button.pressed.emit()
	check(skips == 0 and clock.action_button.disabled, "Pause suppresses skip activation")
	clock.set_paused(false)
	clock.action_button.pressed.emit()
	clock.action_button.pressed.emit()
	check(skips == 1 and clock.action_button.disabled, "One observation can request its transition only once")
	clock.configure(0.0, 10.0, Data.theme("spring"), true)
	check(not clock.action_button.visible and clock.progress() == 0.0, "Expiry removes the obsolete observation action")
	clock.configure(5.0, 5.0, Data.theme("spring"), true)
	check(not clock.action_button.disabled and clock.snapshot().seconds == 5, "A later real observation restores the action and accurate time")
	check(not clock.is_processing(), "Reduced motion keeps the clock legible without its ambient animation")

	var badge := Badge.new()
	root.add_child(badge)
	badge.position = Vector2(12, 100)
	badge.size = Vector2(112, 52)
	check(badge.configure("memory-a", 6, data.chests, Data.theme("spring"), false), "A fresh round configures the highest available production chest")
	await process_frame
	check(badge.snapshot().tier == 6 and badge.snapshot().theme_id == "winter" and badge.chest.closed_art_rect().has_area(),
		"The top Memory reward uses the integrated Crystal chest")
	check(not badge.snapshot().animating and badge.snapshot().change_count == 0, "A fresh header does not play a damage reaction")
	var original: Rect2 = badge.get_rect()
	var chest_origin: Vector2 = badge.chest.position
	for tier in [5, 4, 3, 2, 1, 0]:
		check(badge.configure("memory-a", tier, data.chests, Data.theme("spring"), false), "A mismatch accepts the model's lower tier")
		badge.advance(0.12)
		check(badge.snapshot().animating and (not badge.chest.scale.is_equal_approx(Vector2.ONE) or not is_zero_approx(badge.chest.rotation)),
			"A decrement has a restrained local scale/rotation response")
		check(badge.get_rect() == original and badge.chest.position == chest_origin, "A decrement never moves the header or chest anchor")
		var elapsed: float = badge.snapshot().elapsed
		badge.configure("memory-a", tier, data.chests, Data.theme("spring"), false)
		check(badge.snapshot().elapsed == elapsed and badge.snapshot().change_count == 6 - tier, "A layout refresh cannot replay the same decrement")
		badge.set_paused(true)
		badge.advance(1.0)
		check(badge.snapshot().elapsed == elapsed, "Pause freezes the reaction without changing the earned tier")
		badge.set_paused(false)
		badge.advance(1.0)
		check(not badge.snapshot().animating and badge.chest.scale == Vector2.ONE and badge.chest.rotation == 0.0,
			"The reaction settles exactly at the original pose")
	check(badge.visible and badge.snapshot().grey and badge.snapshot().text == "No chest", "Tier zero retains a grey production chest and clear text")
	check(badge.chest._pieces[0].node.material == badge._empty_material, "Tier zero desaturates this instance's artwork")
	badge.configure("memory-b", 6, data.chests, Data.theme("spring"), true)
	badge.configure("memory-b", 5, data.chests, Data.theme("spring"), true)
	check(badge.snapshot().tier == 5 and not badge.snapshot().animating and badge.chest.scale == Vector2.ONE and badge.chest.rotation == 0.0,
		"Reduced motion communicates the changed tier without a moving marker")
	badge.reset()
	badge.advance(5.0)
	check(not badge.visible and badge.snapshot().round_id.is_empty() and not badge.snapshot().animating,
		"Reset cancels pending feedback and removes the old round")
	badge.configure("memory-c", 6, data.chests, Data.theme("spring"), false)
	check(badge.snapshot().change_count == 0 and not badge.snapshot().animating, "A later round never replays a previous mismatch")
	check(not badge.configure("", 6, data.chests, Data.theme("spring"), false) and badge.snapshot().round_id == "memory-c",
		"An invalid configuration preserves the current marker")
	# At 320 CSS pixels the real reserved badge is 85.84 CSS pixels wide.
	# Exercise that allocation at the same 2/3 canvas scale as the web export.
	root.content_scale_size = Vector2i(480, 960)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(320, 640)
	await process_frame
	var ui_scale: float = Style.ui_scale(badge)
	badge.size = Vector2(85.84, 52.0) / ui_scale
	for tier in [6, 0]:
		badge.configure("memory-narrow", tier, data.chests, Data.theme("spring"), true)
		var font_size: int = badge.tier_label.get_theme_font_size("font_size")
		check(font_size * ui_scale >= 11.0, "Narrow reward text never shrinks below 11 CSS pixels")
		check(badge.tier_label.text == ("Chest\nLv 6" if tier > 0 else "No\nchest"),
			"A narrow badge uses complete compact text without reducing its artwork")
		for line: String in badge.tier_label.text.split("\n"):
			check(Style.HEADING_FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= badge.tier_label.size.x,
				"Every displayed narrow reward line fits: %s" % line)
		check(is_equal_approx(badge.chest.size.x * ui_scale, 56.0), "Compact text preserves the production chest display size")
	badge.size = Vector2(112, 52) / ui_scale
	badge.configure("memory-wide", 6, data.chests, Data.theme("spring"), true)
	check(badge.tier_label.text == "Chest\nLevel 6", "Wider layouts retain the full level label")
	badge.configure("memory-wide", 0, data.chests, Data.theme("spring"), true)
	check(badge.tier_label.text == "No chest", "Wider layouts retain the single-line empty label")
	clock.queue_free()
	badge.queue_free()
	await process_frame
	print("Memory reward UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
