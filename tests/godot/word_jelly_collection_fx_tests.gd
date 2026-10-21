extends SceneTree

const Effects = preload("res://scripts/word_jelly_collection_fx.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var patterns: Dictionary = {}
	var cues: Dictionary = {}
	var previous_radius: float = 0.0
	var previous_sparks: int = 0
	for level in range(1, 10):
		var data: Dictionary = Effects.profile(level)
		check(data.level == level, "Every level is addressable")
		check(not patterns.has(data.pattern), "Every level has a distinct motion signature")
		check(not cues.has(data.cue), "Every level has a distinct cue")
		check(float(data.radius) > previous_radius and int(data.sparks) > previous_sparks,
			"Scale and detail retain progression headroom")
		patterns[data.pattern] = true
		cues[data.cue] = true
		previous_radius = float(data.radius)
		previous_sparks = int(data.sparks)
	check(Effects.profile(4).pattern == "firework", "Lv4 is specifically a firework bloom")
	check(Effects.cue_for_level(1) == "pop", "Lv1 uses the approved fixed pop")
	check(Effects.profile(-1).level == 1 and Effects.profile(99).level == 9, "Profiles clamp to supported levels")
	var fx := Effects.new()
	root.add_child(fx)
	fx.configure_layout(Rect2(30.0, 50.0, 390.0, 700.0), 1.0)
	check(fx.mouse_filter == Control.MOUSE_FILTER_IGNORE and fx.focus_mode == Control.FOCUS_NONE,
		"Celebrations never own gameplay input or keyboard focus")
	for level in range(1, 10):
		fx.present(Vector2(180.0, 300.0), level, Color("#4bafa3"), false, 0.0, 0.18)
	var pending: Dictionary = fx.snapshot()
	check(pending.active_count == 9, "Independent collections coexist")
	for state: Dictionary in pending.entries:
		check(not state.popped and is_equal_approx(float(state.delay), 0.18), "Effects wait for the actual pop clock")
		check(state.origin == [180.0, 300.0], "Parent-coordinate origin survives layout offset")
	fx.advance(0.179)
	for state: Dictionary in fx.snapshot().entries:
		check(not state.popped, "No pre-release celebration")
	fx.advance(0.002)
	for state: Dictionary in fx.snapshot().entries:
		check(state.popped, "Every effect crosses the same pop boundary")
	var frozen: Dictionary = fx.snapshot()
	fx.advance(-1.0)
	fx.advance(NAN)
	fx.advance(0.0)
	check(frozen == fx.snapshot(), "Invalid and paused clock advances do not move effects")
	fx.advance(2.0)
	check(fx.snapshot().active_count == 0 and not fx.visible, "Every tail finishes without callbacks")
	fx.present(Vector2(200.0, 350.0), 4, Color.GOLD, true, 0.10, 0.06)
	check(fx.snapshot().entries[0].popped, "Late batch dispatch resumes at its real post-pop age")
	check(float(fx.snapshot().entries[0].duration) <= 0.84, "Batch effects preserve a bounded recovery")
	fx.reset()
	check(not fx.visible and fx.snapshot().active_count == 0, "Exit clears all queued and active effects")
	fx.set_reduced_motion(true)
	fx.present(Vector2(180.0, 300.0), 9, Color.GOLD, false, 0.0, 0.18)
	check(fx.snapshot().entries[0].reduced_motion, "Reduced motion is exposed in evidence")
	check(is_equal_approx(float(fx.snapshot().entries[0].duration), 0.42), "Reduced motion uses a brief static accent")
	fx.advance(0.61)
	check(fx.snapshot().active_count == 0, "Reduced motion follows the same release and cleanup clock")
	fx.set_reduced_motion(false)
	for index in range(30):
		fx.present(Vector2(180.0, 300.0), 9, Color.GOLD, true)
	check(fx.snapshot().active_count == Effects.MAX_ACTIVE, "Repeated input has a bounded visual pool")
	fx.reset()
	fx.present(Vector2(180.0, 300.0), 4, Color.GOLD, false, 99.0)
	fx.present(Vector2(NAN, 10.0), 4, Color.GOLD)
	check(fx.snapshot().active_count == 0, "Expired and invalid origins cannot create stale effects")
	fx.free()
	print("Jelly level collection effects: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
