extends SceneTree

const View = preload("res://scripts/word_jelly_boss_view.gd")
const Run = preload("res://scripts/word_jelly_boss_run.gd")
const Catalog = preload("res://scripts/word_jelly_boss_catalog.gd")
const Pirate = preload("res://scripts/pirate_asset_actor.gd")
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
	run.configure(Catalog.encounter(3), 71)
	var board := Rect2(280, 100, 340, 580)
	var dock := Rect2(634, 130, 210, 330)
	view.layout_battle(dock, board, 1.0)
	check(view.sync(run.snapshot(), {}, 1, false), "The real optimized Pirate loads with its authored materials")
	for clip: String in Pirate.CLIPS:
		check(clip in view._actor.animation_names(), "The active Pirate includes the explicit authored %s clip" % clip)
	var faces: Array[Node] = view._actor._model.find_children("*", "MeshInstance3D", true, false)
	var face: MeshInstance3D = null
	for mesh: Node in faces:
		if mesh is MeshInstance3D and (mesh as MeshInstance3D).find_blend_shape_by_name("Eye_Squint") >= 0:
			face = mesh as MeshInstance3D
	check(faces.size() == 2 and face != null and face.mesh.get_blend_shape_count() == 4,
		"The Pirate retains its optimized elastic body, rigid hat and four authored mouth-expression shapes")
	if face != null:
		view._actor.pose("Special_BigBite", 0.60)
		var mouth: int = face.find_blend_shape_by_name("Bite_Open")
		check(mouth >= 0 and face.get_blend_shape_value(mouth) > 0.98,
			"The native Big Bite visibly opens the imported mouth rather than only reporting a clip name")
		view._actor.pose("Taunt_HatTip", 0.65)
		var eye: int = face.find_blend_shape_by_name("Eye_Squint")
		check(eye >= 0 and face.get_blend_shape_value(eye) > 0.1,
			"The native hat-tip taunt deforms the real eye expression")
	var capture: bool = OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless"
	if capture:
		DirAccess.make_dir_recursive_absolute("res://build/qa/jelly-boss")
		view._character.position = Vector2(320, 80)
		view._character.size = Vector2(360, 540)
		for clip: String in Pirate.CLIPS:
			var at: float = view._actor.clip_duration(clip) * 0.4
			view._actor.pose(clip, at)
			for frame in range(3):
				await process_frame
			await RenderingServer.frame_post_draw
			var body: Image = view._actor.get_texture().get_image()
			var occupied: Rect2i = body.get_used_rect()
			check(occupied.position.x > 0 and occupied.position.y > 0
				and occupied.end.x < body.get_width() and occupied.end.y < body.get_height(),
				"The actual %s silhouette retains the elastic body and complete rigid hat inside its transparent camera frame: %s" % [clip, occupied])
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
	check(cues.count("boss-hit") == 0 and not str(view.snapshot().clip).begins_with("Hit_")
		and is_equal_approx(float(view.snapshot().energy_fraction), 1.0),
		"Pirate cannot recoil, lose visible energy or sound hit before the bolt reaches him")
	run.advance(0.02, [], true)
	view.sync(run.snapshot(), {}, 1, true)
	check(cues.count("boss-hit") == 1 and str(view.snapshot().clip).begins_with("Hit_")
		and view.snapshot().gesture == "Hit"
		and view._character.position.x > view._character_rect.position.x,
		"The visual contact owns one synchronized hit cue, authored reaction and planted recoil")
	view.sync(run.snapshot(), {}, 1, true)
	check(cues.count("boss-hit") == 1, "Repeated status/layout refreshes cannot replay a hit cue")
	run.advance(0.08, [], true)
	view.sync(run.snapshot(), {}, 1, true)
	await capture_state("drama-attack-contact")
	run.advance(0.16, [], true)
	view.sync(run.snapshot(), {}, 1, true)
	check(is_equal_approx(float(view.snapshot().health_fraction), float(view.snapshot().energy_fraction)),
		"After contact the visual energy settles promptly to the authoritative committed health")
	check(run.collect_hit("presentation:finishing-word", 9, 0, {}) and run.health == 0 and run.outcome == "defeated",
		"The finishing-word fixture genuinely defeats the real first encounter before asserting its ending")
	view.sync(run.snapshot(), {}, 1, true)
	check(cues.count("boss-win") == 0, "A final award does not announce victory before its visual impact")
	run.advance(View.HIT_FLIGHT_SECONDS + 0.01, [], false)
	view.sync(run.snapshot(), {}, 1, true)
	check(cues.count("boss-win") == 1 and view.snapshot().dialogue == "Pirate beaten!",
		"The decisive impact has an unmistakable victory response rather than another ordinary taunt")
	run.advance(0.14, [], false)
	view.sync(run.snapshot(), {}, 1, true)
	await capture_state("drama-victory-impact")
	run.advance(3.5 - View.HIT_FLIGHT_SECONDS - 0.15, [], false)
	view.sync(run.snapshot(), {}, 1, true)
	check(view.snapshot().speaker == "Pip" and not view._dialogue.text.is_empty(),
		"The escape exchanges a real reply with Pip instead of leaving a silent retreat")
	check(view.snapshot().gesture != "Taunt" and cues.count("boss-win") == 1
		and view.snapshot().compass_visible,
		"A beaten Pirate retreats instead of instantly mocking again; the stolen objective remains visible")
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
	check(finale.collect_hit("presentation:final-clone-one", 1, 0, {})
		and finale.collect_hit("presentation:final-clone-two", 1, 0, {}) and finale.clones == 0,
		"The final-compass fixture genuinely disperses both real opening doubles before targeting the rival")
	check(finale.collect_hit("presentation:final-compass", 1, 0, {}) and finale.health == 0 and finale.outcome == "defeated",
		"The final-compass collected word genuinely starts the definitive ending")
	finale.advance(2.2, [], false)
	view.reduced_motion = false
	view.sync(finale.snapshot(), {}, 5, false)
	check(view.snapshot().clip == "Idle" and view.snapshot().dialogue.contains("You win"),
		"The final rival admits defeat instead of taunting while returning the actual compass")
	await capture_state("drama-compass-recovered")
	var projection_run := Run.new()
	projection_run.configure(Catalog.encounter(18), 71)
	var projection_state: Dictionary = projection_run.snapshot()
	view.sync(projection_state, {}, 6, false)
	var tile = preload("res://scripts/word_jelly_tile.gd").new()
	root.add_child(tile)
	var pitch: float = board.size.x / View.Model.COLUMNS
	for column in range(View.Model.COLUMNS):
		var expected := Rect2(board.position + Vector2(column, 7) * pitch, Vector2.ONE * pitch)
		view._handle_event({"kind": "snatch", "at": 0.0, "target": 991,
			"tile": {"column": column, "row": 7}}, false, {991: tile})
		check(Rect2(view._thrown.back().rect).is_equal_approx(expected),
			"Snatched artwork retains the real square and position in column %d" % (column + 1))
		view._handle_event({"kind": "throw", "status": "snatch", "at": 0.0,
			"column": column, "row": 7}, false, {})
		projection_state.elapsed = Run.WINDUP_SECONDS + Run.FLIGHT_SECONDS
		view.sync(projection_state, {}, 6, false)
		var contact: Vector2 = view._character.position + view._character.size * Vector2(0.5, 0.65)
		check(contact.is_equal_approx(expected.get_center()),
			"The live Boss snatch reaches the real center of column %d without a five-column offset" % (column + 1))
	tile.free()
	for item: Dictionary in [{"level": 1, "clip": "Hit_L"}, {"level": 4, "clip": "Hit_M"}, {"level": 7, "clip": "Hit_P"}]:
		var strength_run := Run.new()
		strength_run.configure(Catalog.encounter(18), 71)
		view.sync(strength_run.snapshot(), {}, 10 + int(item.level), false)
		check(strength_run.collect_hit("presentation:strength:%d" % int(item.level), int(item.level), 0, {})
			and strength_run.snapshot().events.back().kind == "player_hit",
			"The Lv%d strength fixture targets the real rival rather than a shadow double or shield" % int(item.level))
		strength_run.advance(View.HIT_FLIGHT_SECONDS + 0.01, [], false)
		view.sync(strength_run.snapshot(), {}, 10 + int(item.level), false)
		check(view.snapshot().gesture == "Hit" and view.snapshot().clip == item.clip,
			"A collected Lv%d word selects the actual %s impact animation at visual contact: %s" % [
				int(item.level), item.clip, JSON.stringify({"phase": strength_run.phase, "health": strength_run.health,
					"elapsed": strength_run.elapsed, "events": strength_run.snapshot().events,
					"view": view.snapshot()})])
	var taunt_run := Run.new()
	taunt_run.configure(Catalog.encounter(99), 71)
	view.sync(taunt_run.snapshot(), {}, 30, false)
	var seen_taunts: Dictionary = {}
	for index in range(Pirate.TAUNTS.size()):
		view._handle_event({"kind": "taunt", "id": 1000 + index, "at": 0.0}, false, {})
		view._pose()
		var selected: String = str(view.snapshot().clip)
		check(selected in Pirate.TAUNTS and not seen_taunts.has(selected),
			"Repeated real taunt events select all ten distinct authored gestures before repeating")
		seen_taunts[selected] = true
	check(seen_taunts.size() == Pirate.TAUNTS.size(), "Every supplied Pirate taunt is reachable through the active Boss view")
	view.free()
	sky.free()
	print("Jelly Boss presentation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
