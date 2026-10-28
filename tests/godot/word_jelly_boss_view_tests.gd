extends SceneTree

const View = preload("res://scripts/word_jelly_boss_view.gd")
const Run = preload("res://scripts/word_jelly_boss_run.gd")
const Catalog = preload("res://scripts/word_jelly_boss_catalog.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func capture_state(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute("res://build/qa/jelly-boss")
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://build/qa/jelly-boss/" + name + ".png") == OK,
		"Capture the real " + name + " beat using the acquired character and compass")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1000, 760)
	var sky := TextureRect.new()
	sky.texture = load("res://assets/images/jelly-match/sky/day.png")
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky.size = root.size
	root.add_child(sky)
	var view := View.new()
	root.add_child(view)
	view.size = root.size
	var run := Run.new()
	run.configure(Catalog.encounter(18), 71)
	var board := Rect2(280, 100, 340, 580)
	var dock := Rect2(634, 130, 210, 330)
	view.layout_battle(dock, board, 1.0)
	check(view.sync(run.snapshot(), {}, 1, false), "The real acquired skinned Boss loads with its source materials")
	for clip: String in ["Idle", "Throw", "Kick", "Snatch", "Hit", "Taunt", "Celebrate", "Escape"]:
		check(clip in view._actor.animation_names(), "The converted source includes the explicit authored %s clip" % clip)
	var faces: Array[Node] = view._actor._model.find_children("*", "MeshInstance3D", true, false)
	var face: MeshInstance3D = faces[0] as MeshInstance3D if faces.size() == 1 else null
	check(face != null and face.mesh.get_blend_shape_count() == 3,
		"The replacement Frog retains its real skinned mesh and three original-eye expression shapes")
	if face != null:
		view._actor.pose("Hit", 0.25)
		var wide: int = face.find_blend_shape_by_name("WideEyes")
		check(wide >= 0 and face.get_blend_shape_value(wide) > 0.90,
			"An actual native impact visibly opens the source eyes, not only a diagnostic clip name")
		view._actor.pose("Taunt", 1.0)
		var wink: int = face.find_blend_shape_by_name("Blink.L")
		check(wink >= 0 and face.get_blend_shape_value(wink) > 0.90,
			"The native taunt contains a real one-eye wink")
	var capture: bool = OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless"
	if capture:
		DirAccess.make_dir_recursive_absolute("res://build/qa/jelly-boss")
		view._character.position = Vector2(320, 80)
		view._character.size = Vector2(360, 540)
		for clip: String in ["Idle", "Throw", "Kick", "Snatch", "Hit", "Taunt", "Celebrate", "Escape"]:
			var at: float = {"Idle": 0.45, "Throw": 0.65, "Kick": 0.6, "Snatch": 0.6,
				"Hit": 0.25, "Taunt": 1.0, "Celebrate": 0.5, "Escape": 0.35}[clip]
			view._actor.pose(clip, at)
			for frame in range(3):
				await process_frame
			await RenderingServer.frame_post_draw
			var body: Image = view._actor.get_texture().get_image()
			var occupied: Rect2i = body.get_used_rect()
			check(occupied.position.x > 0 and occupied.position.y > 0
				and occupied.end.x < body.get_width() and occupied.end.y < body.get_height(),
				"The actual %s silhouette retains every hand, finger and foot inside its transparent camera frame: %s" % [clip, occupied])
			var path: String = "res://build/qa/jelly-boss/%s.png" % clip.to_lower()
			check(root.get_texture().get_image().save_png(path) == OK, "Capture actual rendered %s deformation" % clip)
	view.layout_battle(dock, board, 1.0)
	check(dock.grow(0.1).encloses(view._character.get_rect()) and not board.intersects(view._character.get_rect()),
		"The full-body Boss stands in the side dock, not inside the board or an information row")
	var state: Dictionary = view.snapshot()
	check(state.heading.is_empty() and state.health_text.is_empty() and state.energy_segments == 8
		and is_equal_approx(float(state.health_fraction), 1.0),
		"Health uses sourced energy effects without permanent names, instructions or a numeric HP panel")
	var cues: Array[String] = []
	view.audio_requested.connect(func(cue: String) -> void: cues.append(cue))
	run.collect_hit("presentation:hit", 1, 0, {})
	view.sync(run.snapshot(), {}, 1, true)
	check(float(view.snapshot().health_fraction) < float(view.snapshot().energy_fraction),
		"A committed attack keeps its energy target pending while the real sourced bolt is still in flight")
	run.advance(0.28, [], true)
	view.sync(run.snapshot(), {}, 1, true)
	await capture_state("drama-attack-in-flight")
	run.advance(View.HIT_FLIGHT_SECONDS - 0.29, [], true)
	view.sync(run.snapshot(), {}, 1, true)
	check(cues.count("boss-hit") == 0 and view.snapshot().clip != "Hit"
		and is_equal_approx(float(view.snapshot().energy_fraction), 1.0),
		"Bramble cannot recoil, lose visible energy or sound hit before the bolt reaches him")
	run.advance(0.02, [], true)
	view.sync(run.snapshot(), {}, 1, true)
	check(cues.count("boss-hit") == 1 and view.snapshot().clip == "Hit"
		and view._character.position.x > view._character_rect.position.x,
		"The visual contact owns one synchronized hit cue, skeletal reaction and planted recoil")
	view.sync(run.snapshot(), {}, 1, true)
	check(cues.count("boss-hit") == 1, "Repeated status/layout refreshes cannot replay a hit cue")
	run.advance(0.08, [], true)
	view.sync(run.snapshot(), {}, 1, true)
	await capture_state("drama-attack-contact")
	run.advance(0.16, [], true)
	view.sync(run.snapshot(), {}, 1, true)
	check(is_equal_approx(float(view.snapshot().health_fraction), float(view.snapshot().energy_fraction)),
		"After contact the visual energy settles promptly to the authoritative committed health")
	run.collect_hit("presentation:finishing-word", 9, 0, {})
	view.sync(run.snapshot(), {}, 1, true)
	check(cues.count("boss-win") == 0, "A final award does not announce victory before its visual impact")
	run.advance(View.HIT_FLIGHT_SECONDS + 0.01, [], false)
	view.sync(run.snapshot(), {}, 1, true)
	check(cues.count("boss-win") == 1 and view.snapshot().dialogue == "Bramble beaten!",
		"The decisive impact has an unmistakable victory response rather than another ordinary taunt")
	run.advance(0.14, [], false)
	view.sync(run.snapshot(), {}, 1, true)
	await capture_state("drama-victory-impact")
	run.advance(3.5 - View.HIT_FLIGHT_SECONDS - 0.15, [], false)
	view.sync(run.snapshot(), {}, 1, true)
	check(view.snapshot().speaker == "Pip" and not view._dialogue.text.is_empty(),
		"The escape exchanges a real reply with Pip instead of leaving a silent retreat")
	check(view.snapshot().clip != "Taunt" and cues.count("boss-win") == 1
		and view.snapshot().compass_visible,
		"A beaten Bramble retreats instead of instantly mocking again; the stolen objective remains visible")
	await capture_state("drama-victory-reply")
	check(dock.grow(0.1).encloses(view._character.get_rect()) and not board.intersects(view._character.get_rect()),
		"Even the ending keeps the Boss beside the board instead of opening a giant dialog")
	check(view._dialogue.size.y <= 52.1 and view._dialogue.max_lines_visible == 2
		and view._dialogue.get_theme_font_size("font_size") >= 16,
		"The ending gives its short two-line payoff readable emphasis without a board-sized text surface")
	var intro := Run.new()
	intro.configure(Catalog.encounter(1, true), 71)
	view.sync(intro.snapshot(), {}, 2, false)
	check(not view.visible and view.snapshot().dialogue.is_empty(),
		"Stage one has no watching visitor, name, health or entrance hint before the ambush")
	intro.begin_ending("cleared")
	intro.advance(0.75, [], false)
	view.sync(intro.snapshot(), {}, 2, false)
	check(view.visible and dock.grow(0.1).encloses(view._character.get_rect()),
		"The story visitor actually enters from the edge and stops beside the board")
	await capture_state("drama-compass-theft")
	intro.advance(1.75, [], false)
	view.sync(intro.snapshot(), {}, 2, false)
	await capture_state("drama-chase-challenge")
	var kick_run := Run.new()
	kick_run.configure(Catalog.encounter(18), 71)
	kick_run.advance(2.2, [{"id": 1, "column": 0, "row": 7}], true)
	kick_run.advance(Run.WINDUP_SECONDS, [], true)
	view.layout_battle(dock, board, 1.0, Rect2(280, 40, 340, 54))
	view.sync(kick_run.snapshot(), {}, 3, false)
	var foot: Vector2 = view._character.position + view._character.size * Vector2(0.5, view.Actor.FOOT_Y)
	check(view._preview.grow(8.0).has_point(foot),
		"The giant kick physically reaches the current preview instead of a fixed unrelated screen row")
	view.reduced_motion = true
	var still_run := Run.new()
	still_run.configure(Catalog.encounter(3), 71)
	view.sync(still_run.snapshot(), {}, 4, false)
	var still_position: Vector2 = view._character.position
	still_run.collect_hit("presentation:reduced-hit", 1, 0, {})
	view.sync(still_run.snapshot(), {}, 4, false)
	check(view._character.position == still_position and view._character.rotation == 0.0
		and is_equal_approx(float(view.snapshot().energy_fraction), float(view.snapshot().health_fraction)),
		"Reduced motion communicates the real hit immediately without recoil or a flying-bolt delay")
	var finale := Run.new()
	finale.configure(Catalog.encounter(99), 71)
	finale.health = 1
	finale.collect_hit("presentation:final-compass", 1, 0, {})
	finale.advance(2.2, [], false)
	view.reduced_motion = false
	view.sync(finale.snapshot(), {}, 5, false)
	check(view.snapshot().clip == "Idle" and view.snapshot().dialogue.contains("You win"),
		"The final rival admits defeat instead of taunting while returning the actual compass")
	await capture_state("drama-compass-recovered")
	view.free()
	sky.free()
	print("Jelly Boss presentation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
