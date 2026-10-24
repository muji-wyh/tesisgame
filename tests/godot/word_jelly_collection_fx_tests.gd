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
	var previous_seconds: float = 0.0
	check(Effects.PROFILES.size() == 9, "Merged jellies have exactly nine collection profiles")
	for level in range(1, 10):
		var data: Dictionary = Effects.profile(level)
		check(data.level == level, "Every level is addressable")
		check(not patterns.has(data.pattern), "Every level has a distinct motion signature")
		check(not cues.has(data.cue), "Every level has a distinct cue")
		check(float(data.radius) > previous_radius and int(data.sparks) > previous_sparks,
			"Scale and detail retain progression headroom")
		check(float(data.seconds) > previous_seconds, "Higher levels retain more time for their release and tail")
		patterns[data.pattern] = true
		cues[data.cue] = true
		previous_radius = float(data.radius)
		previous_sparks = int(data.sparks)
		previous_seconds = float(data.seconds)
	check(Effects.profile(4).pattern == "firework", "Lv4 is specifically a firework bloom")
	check(float(Effects.profile(4).seconds) >= 2.5, "Lv4 has time for a blossom and descending ember tail")
	check(Effects.cue_for_level(1) == "pop", "Lv1 uses the approved fixed pop")
	check(Effects.profile(-1).level == 1 and Effects.profile(99).level == 9, "Profiles clamp to the nine supported levels")
	check(Effects.cue_for_level(99) == "jelly-collect-lv9", "Out-of-range levels clamp to the final acquired cue")
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
		check(state.phase == "waiting", "The effects renderer leaves anticipation to the real jelly")
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
	check(fx.snapshot().active_count == 6, "The six firework profiles remain after the short pops finish")
	for state: Dictionary in fx.snapshot().entries:
		check(state.phase == "falling_embers", "Longer firework tails enter their final descending beat")
	fx.advance(2.1)
	check(fx.snapshot().active_count == 0 and not fx.visible, "Every tail finishes without callbacks")
	fx.present(Vector2(200.0, 350.0), 4, Color.GOLD, true, 0.10, 0.06)
	check(fx.snapshot().entries[0].popped, "Late batch dispatch resumes at its real post-pop age")
	check(float(fx.snapshot().entries[0].duration) >= 2.0 and float(fx.snapshot().entries[0].duration) < float(Effects.profile(4).seconds),
		"Batch collection keeps a complete ember tail at reduced duration and density")
	fx.reset()
	check(not fx.visible and fx.snapshot().active_count == 0, "Exit clears all queued and active effects")
	fx.set_reduced_motion(true)
	fx.present(Vector2(180.0, 300.0), 6, Color.GOLD, false, 0.0, 0.18)
	check(fx.snapshot().entries[0].reduced_motion, "Reduced motion is exposed in evidence")
	check(is_equal_approx(float(fx.snapshot().entries[0].duration), 0.42), "Reduced motion uses a brief static accent")
	fx.advance(0.61)
	check(fx.snapshot().active_count == 0, "Reduced motion follows the same release and cleanup clock")
	fx.set_reduced_motion(false)
	fx.present(Vector2(180.0, 300.0), 4, Color.GOLD)
	check(fx.snapshot().entries[0].phase == "explosion", "Lv4 release begins with the explosion")
	fx.advance(0.55)
	check(fx.snapshot().entries[0].phase == "blossom", "Lv4 opens its colored blossoms before the descent")
	fx.advance(1.0)
	check(fx.snapshot().entries[0].phase == "falling_embers", "Lv4 leaves time for falling embers")
	fx.reset()
	var outward: Vector2 = fx._firework_trajectory(0.0, 0.3, 0.5, 100.0, 4)
	var blossom: Vector2 = fx._firework_trajectory(0.0, 1.0, 0.5, 100.0, 4)
	var ember: Vector2 = fx._firework_trajectory(0.0, 2.0, 0.5, 100.0, 4)
	check(outward.x > 60.0, "Firework spokes make a decisive initial radial release")
	check(ember.x - blossom.x < blossom.x - outward.x, "Radial velocity decays after the initial explosion")
	check(ember.y - blossom.y > 20.0, "Embers descend rather than only fading in their expanded positions")
	for level in range(4, 10):
		for group in range(1, int(Effects.profile(level).bursts)):
			check(fx._firework_delay(level, group) > 0.0 and fx._firework_delay(level, group) < 0.46,
				"Secondary blossoms follow the main release before the final descent")
	for level in range(7, 10):
		var centers: Array[Vector2] = []
		for group in range(int(Effects.profile(level).bursts)):
			var center: Vector2 = fx._firework_offset(level, group, 100.0)
			check(not centers.has(center), "Higher-level blossoms have separate release origins")
			centers.append(center)
		fx.present(Vector2(180.0, 300.0), level, Color.GOLD, true)
		check(is_equal_approx(float(fx.snapshot().entries.back().duration), float(Effects.profile(level).seconds) * 0.75),
			"Higher automatic collections retain their complete scheduled board tail")
	fx.reset()
	for index in range(30):
		fx.present(Vector2(180.0, 300.0), 6, Color.GOLD, true)
	check(fx.snapshot().active_count == Effects.MAX_ACTIVE, "Repeated input has a bounded visual pool")
	fx.reset()
	fx.present(Vector2(180.0, 300.0), 4, Color.GOLD, false, 99.0)
	fx.present(Vector2(NAN, 10.0), 4, Color.GOLD)
	check(fx.snapshot().active_count == 0, "Expired and invalid origins cannot create stale effects")
	fx.free()
	print("Jelly level collection effects: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
