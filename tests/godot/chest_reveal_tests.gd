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
		chest._advance_animation(0.4)
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
	_check_themed_chests(data)
	_check_hold_feedback(data)
	_check_hold_bounds(data)
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


func _check_themed_chests(data) -> void:
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	chest.size = Vector2(320, 320)
	var opened_themes: Array[String] = []
	chest.opened.connect(func() -> void: opened_themes.append(chest.theme_id))
	for theme_id in data.THEMES:
		chest.clear()
		chest.reduced_motion = true
		var palette: Dictionary = data.theme(theme_id)
		chest.configure_skin(palette, data.chests)
		var before: int = opened_themes.size()
		chest.start_open(true)
		chest.configure_skin(palette, data.chests)
		chest.start_open(true)
		chest.finish_immediately()
		check(chest.mode == "opened" and chest.theme_id == theme_id
			and opened_themes.size() == before + 1 and opened_themes.back() == theme_id,
			"Refreshing the earned " + theme_id + " chest keeps it open without awarding again")
		for dimensions in [Vector2(320, 190), Vector2(180, 400), Vector2(640, 420)]:
			chest.size = dimensions
			chest.set_drag_offset(Vector2.ZERO)
			var stage := Rect2(Vector2.ZERO, chest.size).grow(0.5)
			var visible_pieces := 0
			var outside: Array[String] = []
			for piece in chest._pieces:
				var sprite: Sprite2D = piece.node
				if not sprite.is_visible_in_tree() or sprite.modulate.a <= 0.001:
					continue
				visible_pieces += 1
				var transform: Transform2D = chest.get_global_transform().affine_inverse() * sprite.get_global_transform()
				var bounds: Rect2 = sprite.get_rect()
				for corner in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
					if not stage.has_point(transform * corner):
						outside.append(str(piece.role) + " at " + str(transform * corner))
			check(visible_pieces > 0 and outside.is_empty(),
				"The opened %s chest keeps every transformed artwork corner inside %s without clipping: %s" % [theme_id, dimensions, outside])
	chest.free()


func _check_hold_feedback(data) -> void:
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	chest.size = Vector2(320, 240)
	chest.configure_skin(data.theme("spring"), data.chests)
	var openings: Array[String] = []
	chest.opened.connect(func() -> void: openings.append(chest.theme_id))
	chest.begin_hold()
	var state: Dictionary = chest.hold_effect_snapshot()
	check(state.active and state.phase == "holding" and state.percent == 0 and state.text.contains("0%"),
		"Holding exposes semantic zero-percent progress before the first game frame")
	chest.set_hold_progress(0.45)
	state = chest.hold_effect_snapshot()
	check(state.active and state.percent == 16 and state.text.contains("16%") and not state.status.is_empty()
		and state.animated and state.spark_count > 0,
		"Confirmation contributes its real elapsed share of the complete progress")
	chest.set_hold_progress(2.0)
	chest._advance_animation(2.0)
	check(chest.hold_effect_snapshot().percent == 35 and chest.mode == "closed" and openings.is_empty(),
		"Completing confirmation never opens the chest or reports the whole buildup complete")
	chest.set_hold_progress(0.0)
	check(not chest.hold_effect_snapshot().active and not chest._charge.visible and not chest._glint.visible
		and is_zero_approx(chest.hold_progress), "Releasing immediately clears the ring, glow and hold state")
	chest._advance_animation(3.0)
	check(not chest.hold_effect_snapshot().active and chest.mode == "closed" and openings.is_empty(),
		"Cancelled charging has no delayed animation or open callback")
	chest.begin_hold()
	check(chest.hold_effect_snapshot().percent == 0, "A new hold starts at zero instead of inheriting the cancelled charge")
	chest.set_hold_progress(0.7)
	chest.stop_reaction()
	check(not chest.hold_effect_snapshot().active and is_zero_approx(chest.hold_progress),
		"Stopping a reaction clears every hold effect immediately")
	chest.set_hold_progress(0.6)
	chest.hide()
	chest.set_hold_progress(0.9)
	check(not chest.hold_effect_snapshot().active and not chest.is_processing() and is_zero_approx(chest.hold_progress),
		"Hidden chests stop charging and reject late progress updates")
	chest.show()
	check(not chest.hold_effect_snapshot().active, "Returning to the chest cannot resurrect an interrupted hold")
	chest.reduced_motion = true
	chest.begin_hold()
	chest.set_hold_progress(0.63)
	var pose: Transform2D = chest._art.transform
	var effect_bounds: Dictionary = chest.hold_effect_snapshot().bounds
	for delta in [0.08, 0.25, 1.5]:
		chest._advance_animation(delta)
		state = chest.hold_effect_snapshot()
		check(state.active and state.percent == 63 and state.text.contains("63%") and not state.animated
			and state.spark_count == 0 and chest._art.transform == pose and state.bounds == effect_bounds,
			"Reduced motion retains semantic progress without bob, shake, moving sparks or shifting effects")
	chest.set_hold_progress(0.0)
	check(not chest.hold_effect_snapshot().active, "Reduced-motion progress also clears immediately on cancel")
	chest.reduced_motion = false
	chest.begin_hold()
	chest.set_hold_progress(1.0)
	chest.start_open(false)
	state = chest.hold_effect_snapshot()
	check(state.active and state.phase == "gathering" and state.percent == 35 and not state.status.is_empty()
		and chest.mode == "opening" and openings.is_empty(),
		"Confirmation flows into automatic gathering without resetting or finishing progress")
	chest.start_open(false)
	chest._advance_animation(1.0)
	state = chest.hold_effect_snapshot()
	check(state.active and state.percent > 50 and state.percent < 70 and state.phase == "building"
		and state.spark_count > 0 and openings.is_empty(),
		"Automatic buildup keeps semantic progress advancing with gathering sparks")
	chest._advance_animation(Feel.RELEASE_TIME - 1.0 + 0.01)
	state = chest.hold_effect_snapshot()
	check(state.active and state.percent == 100 and state.phase == "release" and state.spark_count > 0,
		"Only the final physical release reaches 100 percent and scatters sparks")
	chest._advance_animation(Feel.SETTLE_TIME - Feel.RELEASE_TIME)
	check(not chest.hold_effect_snapshot().active and chest.mode == "opening" and openings.is_empty(),
		"The progress effects finish after release while the reward settles")
	chest._advance_animation(Feel.OPEN_SECONDS - chest.hold_effect_snapshot().opening_time - 0.01)
	check(chest.mode == "opening" and openings.is_empty(), "The complete 3.8-second automatic opening precedes the reward")
	chest._advance_animation(0.02)
	chest.start_open(false)
	chest.finish_immediately()
	check(chest.mode == "opened" and openings.size() == 1 and not chest.hold_effect_snapshot().active,
		"Completion emits exactly once, even after repeated open and finish calls")
	chest.clear()
	chest.configure_skin(data.theme("winter"), data.chests)
	chest.begin_hold()
	chest.set_hold_progress(1.0)
	chest.start_open(false)
	chest.clear()
	chest._advance_animation(Feel.OPEN_SECONDS + 1.0)
	check(chest.mode == "closed" and not chest.hold_effect_snapshot().active and openings.size() == 1,
		"Clearing during release removes the effect and prevents a stale open callback")
	chest.free()


func _check_hold_bounds(data) -> void:
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	for theme_id in data.THEMES:
		for dimensions in [Vector2(320, 320), Vector2(320, 110), Vector2(320, 72), Vector2(180, 120), Vector2(180, 400), Vector2(640, 190)]:
			chest.clear()
			chest.size = dimensions
			chest.configure_skin(data.theme(theme_id), data.chests)
			chest.reduced_motion = false
			chest.begin_hold()
			chest.set_hold_progress(0.95)
			var stage := Rect2(Vector2.ZERO, dimensions).grow(0.5)
			check(chest._charge_color == data.theme(theme_id).accent,
				"The %s charge ring follows its chest's theme palette" % theme_id)
			for phase in ["hold", "gathering", "building", "anticipation", "release"]:
				if phase == "gathering":
					chest.start_open(false)
				elif phase == "building":
					chest._advance_animation(1.0)
				elif phase == "anticipation":
					chest._advance_animation(Feel.ANTICIPATION_TIME - 1.0 + 0.01)
				elif phase == "release":
					chest._advance_animation(Feel.RELEASE_TIME - Feel.ANTICIPATION_TIME)
				var state: Dictionary = chest.hold_effect_snapshot()
				var bounds := Rect2(Vector2(state.bounds.x, state.bounds.y), Vector2(state.bounds.width, state.bounds.height))
				check(state.active and bounds.has_area() and stage.encloses(bounds),
					"The %s %s halo and sparks stay inside %s" % [theme_id, phase, dimensions])
				var outside: Array[String] = []
				for piece in chest._pieces:
					var sprite: Sprite2D = piece.node
					if sprite.modulate.a <= 0.001:
						continue
					var transform: Transform2D = chest.get_global_transform().affine_inverse() * sprite.get_global_transform()
					var rect: Rect2 = sprite.get_rect()
					for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
						if not stage.has_point(transform * corner):
							outside.append(str(piece.role) + " at " + str(transform * corner))
				check(outside.is_empty(), "The %s %s chest artwork remains unclipped in %s: %s" % [theme_id, phase, dimensions, outside])
	chest.free()
