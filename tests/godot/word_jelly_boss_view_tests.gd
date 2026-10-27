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
	var capture: bool = OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless"
	if capture:
		DirAccess.make_dir_recursive_absolute("res://build/qa/jelly-boss")
		view._character.position = Vector2(320, 80)
		view._character.size = Vector2(360, 540)
		for clip: String in ["Idle", "Throw", "Kick", "Snatch", "Hit", "Taunt", "Celebrate", "Escape"]:
			view._actor.pose(clip, 0.45)
			for frame in range(3):
				await process_frame
			await RenderingServer.frame_post_draw
			var path: String = "res://build/qa/jelly-boss/%s.png" % clip.to_lower()
			check(root.get_texture().get_image().save_png(path) == OK, "Capture actual rendered %s deformation" % clip)
	view.layout_battle(dock, board, 1.0)
	check(dock.grow(0.1).encloses(view._character.get_rect()) and not board.intersects(view._character.get_rect()),
		"The full-body Boss stands in the side dock, not inside the board or an information row")
	var state: Dictionary = view.snapshot()
	check(state.heading.is_empty() and state.health_text.is_empty() and state.energy_segments == 8
		and is_equal_approx(float(state.health_fraction), 1.0),
		"Health uses sourced energy effects without permanent names, instructions or a numeric HP panel")
	run.collect_hit("presentation:hit", 1, 0, {})
	view.sync(run.snapshot(), {}, 1, false)
	check(float(view.snapshot().health_fraction) < float(view.snapshot().energy_fraction),
		"A real hit drains energy over a visible presentation interval instead of jumping a number")
	run.advance(0.43, [], true)
	view.sync(run.snapshot(), {}, 1, false)
	check(is_equal_approx(float(view.snapshot().health_fraction), float(view.snapshot().energy_fraction)),
		"The visual energy settles to the actual authoritative health ratio")
	run.begin_ending("defeated")
	run.advance(3.5, [], false)
	view.sync(run.snapshot(), {}, 1, false)
	check(view.snapshot().speaker == "Pip" and not view._dialogue.text.is_empty(),
		"The escape exchanges a real reply with Pip instead of leaving a silent retreat")
	check(dock.grow(0.1).encloses(view._character.get_rect()) and not board.intersects(view._character.get_rect()),
		"Even the ending keeps the Boss beside the board instead of opening a giant dialog")
	check(view._dialogue.size.y <= 38.1 and view._dialogue.max_lines_visible == 2,
		"Story reactions are bounded two-line subtitles rather than a board-sized text surface")
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
	var kick_run := Run.new()
	kick_run.configure(Catalog.encounter(18), 71)
	kick_run.advance(2.2, [{"id": 1, "column": 0, "row": 7}], true)
	kick_run.advance(Run.WINDUP_SECONDS, [], true)
	view.layout_battle(dock, board, 1.0, Rect2(280, 40, 340, 54))
	view.sync(kick_run.snapshot(), {}, 3, false)
	var foot: Vector2 = view._character.position + view._character.size * Vector2(0.5, view.Actor.FOOT_Y)
	check(view._preview.grow(8.0).has_point(foot),
		"The giant kick physically reaches the current preview instead of a fixed unrelated screen row")
	view.free()
	sky.free()
	print("Jelly Boss presentation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
