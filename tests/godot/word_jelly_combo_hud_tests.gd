extends SceneTree

const Combo = preload("res://scripts/word_jelly_combo.gd")
const Style = preload("res://scripts/ui_style.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _state(count: int = 3, remaining: float = 8.0, bonus: int = 1) -> Dictionary:
	return {"count": count, "tier": 1, "rank": "C", "event_id": "merge-%d" % count,
		"bonus": bonus, "remaining": remaining, "seconds": 8.0}


func _rect(values: Array) -> Rect2:
	return Rect2(values[0], values[1], values[2], values[3])


func _run() -> void:
	var hud := Combo.new()
	root.add_child(hud)
	hud.configure(Rect2(12, 18, 196, 72), 1.0)
	hud.set_state(_state(), true)
	var fresh: Dictionary = hud.snapshot()
	check(bool(fresh.get("timer_visible", false)) and is_equal_approx(float(fresh.get("time_ratio", 0.0)), 1.0),
		"Every active combo shows a full countdown progress bar")
	check(str(fresh.get("bonus_text", "")).contains("+1") and str(fresh.get("bonus_text", "")).contains("COMBO"),
		"The gold reward explicitly names its combo source and exact increment")
	check(int(fresh.get("bonus_font_size", 0)) >= 16,
		"The ordinary combo reward uses a materially larger readout than the former twelve-pixel detail")
	hud.advance(0.20)
	var serial: int = int(hud.snapshot().pulse_serial)
	hud.set_state(_state(3, 4.0), true)
	check(is_equal_approx(float(hud.snapshot().get("time_ratio", 0.0)), 0.5)
		and int(hud.snapshot().pulse_serial) == serial,
		"Countdown updates drain the bar without replaying success or reward feedback")
	var theme_updates: Array[int] = [0]
	hud._rank_label.theme_changed.connect(func() -> void: theme_updates[0] += 1)
	for tick in range(100):
		hud.set_timer(4.0 - tick * 0.01, 8.0)
	check(theme_updates[0] == 0, "A running countdown updates only its bar, not label themes or text layout every frame")
	hud.set_state(_state(4, 8.0, 0), true)
	check(hud.snapshot().bonus_visible and str(hud.snapshot().get("bonus_text", "")).contains("+1"),
		"A rapid collection does not erase the just-earned combo coin acknowledgement")
	hud.advance(2.0)
	check(not hud.snapshot().bonus_visible and hud.snapshot().visible,
		"The bounded coin acknowledgement settles while the active combo remains")
	for dimensions: Vector2 in [Vector2(196, 72), Vector2(144, 72), Vector2(128, 56), Vector2(94, 44)]:
		for scale_factor: float in [0.75, 1.0, 1.5]:
			for steady: bool in [false, true]:
				hud.reset()
				hud.configure(Rect2(Vector2(12, 18), dimensions / scale_factor), scale_factor, steady)
				var state: Dictionary = _state(999999, 1.0, 3)
				state.rank = "SSS"
				state.tier = 6
				hud.set_state(state, true)
				hud.advance(0.10)
				var snapshot: Dictionary = hud.snapshot()
				var bounds: Rect2 = _rect(snapshot.rect)
				check(snapshot.input_transparent, "Timer and rewards never intercept play input")
				for key: String in ["rank_rect", "count_rect", "bonus_rect", "timer_rect"]:
					check(snapshot.has(key), "The HUD exposes its " + key + " bounds")
					if snapshot.has(key):
						check(bounds.grow(0.1).encloses(_rect(snapshot[key])),
							"%s fits the combo slot at %s, scale %.2f, reduced %s: %s inside %s" %
								[key, dimensions, scale_factor, steady, _rect(snapshot[key]), bounds])
				for label: Label in [hud._rank_label, hud._count_label, hud._bonus_label]:
					var pixels: int = label.get_theme_font_size("font_size")
					check(Style.HEADING_FONT.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x <= label.size.x + 0.1,
						"Long exact counts and reward captions fit without truncation")
				if steady:
					check(is_equal_approx(float(snapshot.pop_scale), 1.0) and not snapshot.pulse_active
						and bool(snapshot.get("timer_visible", false)),
						"Reduced motion retains the real countdown without decorative scaling")
	hud.set_state({})
	check(not hud.snapshot().visible and not hud.snapshot().bonus_visible
		and is_zero_approx(float(hud.snapshot().get("time_ratio", -1.0))),
		"A reset hides both the ended combo and its reward and empties the countdown")
	hud.free()
	print("Word Jelly combo HUD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
