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
	_check_themed_chests(data)
	_check_hold_feedback(data)
	_check_hold_bounds(data)
	_check_progress_alignment(data)
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
		"Holding has an immediate readable zero-percent start, before the first game frame")
	chest.set_hold_progress(0.45)
	state = chest.hold_effect_snapshot()
	check(state.active and state.percent == 45 and state.text.contains("45%") and not state.status.is_empty()
		and state.animated and state.spark_count > 0,
		"Hold feedback reports the actual progress with a visible status and gathering sparks")
	chest.set_hold_progress(2.0)
	chest._process(2.0)
	check(chest.hold_effect_snapshot().percent == 100 and chest.mode == "closed" and openings.is_empty(),
		"Reaching full visual charge never opens the chest or awards its contents without the game action")
	chest.set_hold_progress(0.0)
	check(not chest.hold_effect_snapshot().active and not chest._charge_label.visible and not chest._glint.visible
		and is_zero_approx(chest.hold_progress), "Releasing immediately clears the ring, percentage, glow and hold state")
	chest._process(3.0)
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
	var badge: Rect2 = chest._charge_label.get_rect()
	for delta in [0.08, 0.25, 1.5]:
		chest._process(delta)
		state = chest.hold_effect_snapshot()
		check(state.active and state.percent == 63 and state.text.contains("63%") and not state.animated
			and state.spark_count == 0 and chest._art.transform == pose and chest._charge_label.get_rect() == badge,
			"Reduced motion retains readable progress without bob, shake, moving sparks or shifting text")
	chest.set_hold_progress(0.0)
	check(not chest.hold_effect_snapshot().active, "Reduced-motion progress also clears immediately on cancel")
	chest.reduced_motion = false
	chest.begin_hold()
	chest.set_hold_progress(1.0)
	chest.start_open(false)
	state = chest.hold_effect_snapshot()
	check(state.active and state.phase == "opening" and state.percent == 100 and state.status == "Unlocking"
		and chest.mode == "opening" and openings.is_empty(),
		"The real open action carries a full-charge readout into one finite release effect")
	chest.start_open(false)
	chest._process(0.73)
	check(chest.hold_effect_snapshot().active and chest.hold_effect_snapshot().spark_count == 0,
		"The release sparks finish before the short full-charge readout disappears")
	chest._process(0.23)
	check(not chest.hold_effect_snapshot().active and chest.mode == "opening" and openings.is_empty(),
		"The release effect finishes while the existing chest opening animation continues")
	chest._process(0.83)
	check(chest.mode == "opening" and openings.is_empty(), "Charge feedback does not shorten the 1.8-second opening timing")
	chest._process(0.02)
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
	chest._process(3.0)
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
			for phase in ["hold", "release", "opening"]:
				if phase == "release":
					chest.start_open(false)
				elif phase == "opening":
					chest._process(0.68)
				var state: Dictionary = chest.hold_effect_snapshot()
				var bounds := Rect2(Vector2(state.bounds.x, state.bounds.y), Vector2(state.bounds.width, state.bounds.height))
				check(state.active and stage.encloses(bounds) and stage.encloses(chest._charge_label.get_rect()),
					"The %s %s halo, sparks and readout stay inside %s" % [theme_id, phase, dimensions])
				var font: Font = chest._charge_label.get_theme_font("font")
				var font_size: int = chest._charge_label.get_theme_font_size("font_size")
				var width: float = font.get_string_size(state.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				check(width + 16.0 / chest._charge_scale <= chest._charge_label.size.x + 0.5
					and font_size * chest._charge_scale >= 14.0,
					"The %s %s percentage fits without truncation at a legible size in %s: text=%s, badge=%s, scale=%s" % [theme_id, phase, dimensions, width, chest._charge_label.size.x, chest._charge_scale])
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


func _check_progress_alignment(data) -> void:
	var chest = load("res://scripts/chest_view.gd").new()
	root.add_child(chest)
	var scale: float = chest.Style.ui_scale(chest)
	for css_width in [320.0, 390.0, 420.0, 600.0]:
		chest.clear()
		chest.size = Vector2(css_width, 300.0) / scale
		chest.configure_skin(data.theme("summer"), data.chests)
		chest.begin_hold()
		var badge: Rect2 = chest._charge_label.get_rect()
		for progress in [0.09, 0.1, 0.99, 1.0]:
			chest.set_hold_progress(progress)
			check(chest._charge_label.get_rect() == badge,
				"The %s CSS-pixel stage keeps its progress badge stationary across digit changes" % css_width)
		chest.start_open(false)
		check(chest._charge_label.get_rect() == badge,
			"The %s CSS-pixel stage keeps the full-charge release readout in the same place" % css_width)
		if css_width < 420:
			check(is_equal_approx((chest.size.x - badge.end.x) * scale, 10.0),
				"The %s CSS-pixel mobile stage right-aligns progress with a 10-pixel inset beside the theme badge" % css_width)
		else:
			check(is_equal_approx(badge.get_center().x, chest.size.x * 0.5),
				"The %s CSS-pixel wide stage preserves centered progress" % css_width)
	chest.free()
