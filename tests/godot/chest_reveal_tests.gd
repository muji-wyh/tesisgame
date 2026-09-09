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


func _run() -> void:
	var data = load("res://scripts/game_data.gd").new()
	check(data.load_all(), "Chest reveal assets load")
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	chest.size = Vector2(320, 320)
	chest.configure_skin(data.theme("spring"), data.chests)
	check(chest.has_method("play_tap"), "The chest has a finite short-tap reaction")
	if chest.has_method("play_tap"):
		chest.play_tap()
		check(chest._tap_remaining > 0.0 and not is_zero_approx(chest._art.rotation),
			"A short tap immediately wiggles the closed chest")
		for tap in range(20):
			chest.play_tap()
		check(chest._tap_remaining <= 0.35, "Rapid taps replace the finite reaction instead of stacking")
		chest._process(0.4)
		check(is_zero_approx(chest._tap_remaining) and is_zero_approx(chest._art.rotation),
			"The short-tap reaction settles without changing the chest state")
		check(chest.mode == "closed", "Tapping never opens a chest")
		chest.set_hold_progress(0.8)
		check(chest._glint.visible, "Holding reveals a native latch glow")
		chest.set_hold_progress(0.0)
		check(not chest._glint.visible, "Cancelling the hold removes its glow")
		chest.reduced_motion = true
		chest.play_tap()
		chest.set_hold_progress(0.8)
		check(is_zero_approx(chest._art.rotation) and not chest._glint.visible,
			"Reduced motion keeps tap and hold reactions static")
		chest.set_hold_progress(0.0)
		chest.start_open(false)
		chest.play_tap()
		check(is_zero_approx(chest._tap_remaining), "An opening chest ignores short-tap play")
	chest.free()
	var effect = load("res://scripts/celebration.gd").new()
	root.add_child(effect)
	effect.configure(data.chests)
	var start_method: Dictionary = effect.get_method_list().filter(
		func(value: Dictionary) -> bool: return value.name == "start")[0]
	check(start_method.args.size() == 3, "Celebrations support a small fragment burst")
	if start_method.args.size() == 3:
		effect.start(data.theme("spring"), false, true)
		check(effect.particle_count() == 24, "A fragment gets exactly 24 bounded particles")
		effect.start(data.theme("spring"), false)
		check(effect.particle_count() == 72, "A completed medal keeps the full 72-particle celebration")
		effect.start(data.theme("winter"), true, true)
		check(effect.particle_count() == 0, "Reduced-motion fragments do not produce particles")
	effect.free()
	var medal_path := "res://scripts/medal_view.gd"
	check(FileAccess.file_exists(medal_path), "A shared native medal-piece view exists")
	if FileAccess.file_exists(medal_path):
		var medal = load(medal_path).new()
		root.add_child(medal)
		medal.size = Vector2(120, 90)
		var texture: Texture2D = load("res://assets/images/rewards/spring-1.svg")
		for count in range(4):
			medal.configure(texture, count, Color("#438363"))
			check(medal.pieces == count and medal.fragment_index == -1,
				"The shared medal view represents zero through three pieces")
		medal.configure(texture, 2, Color("#438363"), 1)
		check(medal.fragment_index == 1 and medal.texture == texture,
			"The flying piece uses the same artwork and exact destination sector")
		medal.configure(texture, 3, Color("#438363"))
		check(medal.fragment_index == -1, "A complete medal removes the fragment-only mask")
		medal.configure(null, 0, Color("#606a73"))
		check(medal.texture == null and medal.pieces == 0, "Empty medals need no eagerly loaded image")
		medal.free()
	print("Chest reveal: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
