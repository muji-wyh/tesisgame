extends SceneTree

const Jelly = preload("res://scripts/word_jelly.gd")
const Data = preload("res://scripts/game_data.gd")
var checks: int = 0
var failures: int = 0
var data := Data.new()
var words: Array = []
var cues: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _prepare(dimensions: Vector2i, steady: bool = false, level: int = 2, dense: bool = false):
	root.size = dimensions
	var view := Jelly.new()
	root.add_child(view)
	view.size = Vector2(dimensions)
	check(view.configure(words, 3, Data.theme("spring"), data.chests, steady, 9317),
		"The blast view uses the production word artwork, backdrop, Jelly skin and particle textures")
	view.set_process(false)
	view.game.spawn_interval = 10000.0
	view.credit_collection = func(_id: String, _coins: int) -> Dictionary: return {"ok": true}
	view.game.cells.clear()
	var cat: Dictionary = words[0]
	var dog: Dictionary = words[1]
	var source: Dictionary = view.game._new_word_root(dog, 2)
	view.game._set_merged_word(source, dog, level, true)
	_put(view, source, 2, 7)
	var marked: Dictionary = _put(view, view.game._new_word_root(cat, 3), 1, 7)
	var partner: Dictionary = _put(view, view.game._new_picture_tile(cat, 4), 4, 7)
	if dense:
		for row in range(7):
			for column in range(5):
				var tile: Dictionary = view.game._new_word_root(cat) if (row + column) % 2 else view.game._new_picture_tile(cat)
				_put(view, tile, column, row)
	view._sync_tiles()
	view._layout()
	view.audio_requested.connect(func(cue: String) -> void: cues.append(cue))
	cues.clear()
	view._collect(int(source.id))
	return {"view": view, "source": source, "marked": marked, "partner": partner}


func _put(view, tile: Dictionary, column: int, row: int) -> Dictionary:
	tile.column = column
	tile.row = row
	tile.age = 100.0
	tile.settling = false
	tile.arrival = false
	tile.falling = false
	view.game.cells.append(tile)
	return tile


func _capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	var directory: String = "res://build/qa/jelly-feedback-2026-10-25"
	DirAccess.make_dir_recursive_absolute(directory)
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory + "/" + name + ".png") == OK,
		"Capture the real native blast presentation")


func _advance(view, seconds: float) -> void:
	var remaining: float = seconds
	while remaining > 0.00001:
		var delta: float = minf(0.04, remaining)
		view._process(delta)
		remaining -= delta


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	check(data.load_all(), "Load production assets for the blast rendering route")
	for id: String in ["cat", "dog"]:
		words.append(data.words.filter(func(word: Dictionary) -> bool: return str(word.id) == id)[0])
	for dimensions: Vector2i in [Vector2i(1366, 768), Vector2i(390, 844), Vector2i(844, 390)]:
		for steady: bool in [false, true]:
			var fixture: Dictionary = _prepare(dimensions, steady)
			var view = fixture.view
			view._process(0.42)
			view._process(0.01)
			var source_center: Vector2 = view._tile_rect(fixture.source).get_center()
			var target_center: Vector2 = view._tiles[int(fixture.marked.id)].get_rect().get_center()
			var ambient: float = view._presentation_elapsed
			var board_age: float = float(view.game.cell(int(fixture.marked.id)).age)
			var motion_delta: float = view.game.presentation_delta(0.23)
			_advance(view, 0.23)
			check(view.game.powerup_snapshot().kind == "blast" and view.game.powerup_snapshot().stage == "mark"
				and view.snapshot().get("hit_stop", {}).get("active", false)
				and not view._powerup_effects.stamps.is_empty() and not cues.has("blast_mark"),
				"The source releases a visible marking wave inside real local slow motion, before impact")
			check(is_equal_approx(view._presentation_elapsed - ambient, motion_delta)
				and is_equal_approx(float(view.game.cell(int(fixture.marked.id)).age) - board_age, motion_delta)
				and is_equal_approx(Engine.time_scale, 1.0),
				"Board bodies and ambient Jelly motion slow without changing the engine, UI or audio clock")
			check(view.snapshot().hit_stop.visible == (not steady),
				"A normal-motion board visibly focuses the collected source even when all other Jellies are stationary")
			check(view.find_child("HitStopFocus", true, false) == null,
				"Hit stop keeps its visible sourced wave without a dark overlay covering the well")
			check(view._powerup_effects.stamps.any(func(stamp: Dictionary) -> bool:
				return stamp.texture == view.COLLECTION_GLOW and Vector2(stamp.center).is_equal_approx(source_center)),
				"The collected Jelly's actual board position remains the outgoing energy source")
			check(view._tiles[int(fixture.marked.id)]._base_stretch.is_equal_approx(Vector2.ONE),
				"A target cannot squash before its outward mark has reached it")
			if not steady:
				check(view._powerup_effects.stamps.any(func(stamp: Dictionary) -> bool:
					var point: Vector2 = stamp.center
					return (point.distance_to(source_center) > 0.1 and point.distance_to(target_center) > 0.1
						and point.distance_to(source_center) < source_center.distance_to(target_center))),
					"Acquired marker artwork really travels outward instead of appearing at the target")
			var frozen: Dictionary = view.game.powerup_snapshot()
			view.pause(true)
			view._process(0.20)
			check(view.game.powerup_snapshot() == frozen and not view._powerup_effects.is_visible_in_tree(),
				"Pause freezes the mark and hides its cosmetic layer")
			view.pause(false)
			_advance(view, float(view.game.powerup_snapshot().duration)
				- float(view.game.powerup_snapshot().elapsed) + 0.035)
			check(cues.has("blast_mark") and not view.snapshot().get("hit_stop", {}).get("active", true)
				and view.game.powerup_snapshot().drags.is_empty(),
				"The final impact ends slow motion before the planted body lifts into automatic matching")
			var marked_tile = view._tiles[int(fixture.marked.id)]
			check(marked_tile._base_stretch.is_equal_approx(Vector2.ONE) if steady else
				marked_tile._base_stretch.x > 1.10 and marked_tile._base_stretch.y < 0.82,
				"A sharp, grounded compression gives the hit weight; reduced motion keeps the body still")
			check(marked_tile.position.is_equal_approx(view._tile_rect(view.game.cell(int(fixture.marked.id))).position),
				"Mark impact stays planted on the original support rather than bobbing or floating")
			view._process(0.12)
			var state: Dictionary = view.game.powerup_snapshot()
			check(state.drags.size() == 1 and int(state.drags[0].source_id) == int(fixture.marked.id),
				"The actual marked tile becomes the automatic flight source")
			if not state.drags.is_empty():
				var point: Vector2 = view._tiles[int(fixture.marked.id)].get_rect().get_center()
				var from: Vector2 = view._tile_rect(fixture.marked).get_center()
				var to: Vector2 = view._tile_rect(fixture.partner).get_center()
				check(point.distance_to(from) > 1.0 and point.distance_to(to) > 1.0
					and point.x > minf(from.x, to.x) and point.x < maxf(from.x, to.x),
					"The production jelly moves through an intermediate point instead of teleporting")
			for frame in range(60):
				view._process(0.04)
			check(not view.game.powerup_active() and view.game.cells.size() == 1
				and view.game.cells[0].assisted and view._powerup_effects.stamps.is_empty(),
				"The real view settles one assisted word and cleans up every marking and travel stamp")
			view.free()
	if OS.get_cmdline_user_args().has("--capture"):
		for dimensions: Vector2i in [Vector2i(1366, 768), Vector2i(390, 844)]:
			for level: int in [2, 5, 6, 7, 8, 9]:
				var fixture: Dictionary = _prepare(dimensions, false, level, true)
				var view = fixture.view
				_advance(view, view.game.collection_seconds(level) + 0.22)
				await _capture("blast-%dx%d-lv%d-mark-wave" % [dimensions.x, dimensions.y, level])
				_advance(view, 0.155)
				await _capture("blast-%dx%d-lv%d-first-impact" % [dimensions.x, dimensions.y, level])
				if view.game.gameplay_time_scale() < 1.0:
					_advance(view, float(view.game.powerup_snapshot().duration)
						- float(view.game.powerup_snapshot().elapsed) + 0.035)
				await _capture("blast-%dx%d-lv%d-final-impact" % [dimensions.x, dimensions.y, level])
				_advance(view, 0.12)
				await _capture("blast-%dx%d-lv%d-flight" % [dimensions.x, dimensions.y, level])
				if level >= 4:
					for frame in range(8):
						view._process(0.04)
					await _capture("blast-%dx%d-lv%d-sky-fireworks" % [dimensions.x, dimensions.y, level])
				if level == 9:
					var paper = preload("res://scripts/reward_confetti.gd").new()
					root.add_child(paper)
					paper.burst("visual-stage-complete")
					paper.advance(1.0)
					await _capture("blast-%dx%d-stage-confetti" % [dimensions.x, dimensions.y])
					paper.free()
				view.free()
	await process_frame
	print("Word Jelly blast view: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
