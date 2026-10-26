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
	run.configure(Catalog.encounter(45), 71)
	view.layout_battle(Rect2(310, 30, 380, 78), Rect2(310, 160, 380, 570), 1.0)
	check(view.sync(run.snapshot(), {}, 1, false), "The real acquired skinned Boss loads with its source materials")
	for clip: String in ["Idle", "Throw", "Kick", "Snatch", "Hit", "Taunt", "Celebrate", "Escape"]:
		check(clip in view._actor.animation_names(), "The converted source includes the explicit authored %s clip" % clip)
	var capture: bool = OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless"
	if capture:
		DirAccess.make_dir_recursive_absolute("res://build/qa/jelly-boss")
		view._character.position = Vector2(280, 150)
		view._character.size = Vector2(440, 440)
		for clip: String in ["Idle", "Throw", "Kick", "Snatch", "Hit", "Taunt", "Celebrate", "Escape"]:
			view._actor.pose(clip, 0.45)
			for frame in range(3):
				await process_frame
			await RenderingServer.frame_post_draw
			var path: String = "res://build/qa/jelly-boss/%s.png" % clip.to_lower()
			check(root.get_texture().get_image().save_png(path) == OK, "Capture actual rendered %s deformation" % clip)
	view.size = Vector2(393, 700)
	view.layout_battle(Rect2(30, 10, 333, 78), Rect2(30, 140, 333, 530), 1.0)
	check(view._heading.get_rect().end.x <= view._character_rect.position.x + 8.0
		and view._heading.get_rect().end.y <= view._health.position.y,
		"The phone battle caption stays clear of the character and health row")
	run.begin_ending("defeated")
	run.advance(3.5, [], false)
	view.sync(run.snapshot(), {}, 1, false)
	check(view._speaker.text == "Pip" and not view._dialogue.text.is_empty(),
		"The escape exchanges a real reply with Pip instead of leaving a silent retreat")
	view.layout_battle(Rect2(30, 10, 210, 78), Rect2(30, 140, 210, 336), 1.0)
	check(view._board.grow(0.1).encloses(view._dialogue.get_rect()),
		"The entire Boss/Pip exchange stays inside a short phone's well before escape")
	var kick_run := Run.new()
	kick_run.configure(Catalog.encounter(45), 71)
	kick_run.advance(2.2, [{"id": 1, "column": 0, "row": 7}], true)
	kick_run.advance(Run.WINDUP_SECONDS, [], true)
	view.layout_battle(Rect2(30, 10, 210, 78), Rect2(30, 260, 210, 336), 1.0, Rect2(30, 200, 210, 54))
	view.sync(kick_run.snapshot(), {}, 2, false)
	var foot: float = view._character.position.y + view._character.size.y
	check(foot >= view._preview.position.y and foot <= view._preview.end.y + 5.0,
		"The giant kick physically reaches the current preview instead of a fixed unrelated screen row")
	view.free()
	sky.free()
	print("Jelly Boss presentation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
