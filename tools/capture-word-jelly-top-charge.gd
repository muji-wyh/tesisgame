extends SceneTree
## Silent deterministic production captures; no physical-device or audio claims.

const Jelly = preload("res://scripts/word_jelly.gd")
const Data = preload("res://scripts/game_data.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
const OUTPUT: String = "res://build/qa/top-jelly-charge"
var data := Data.new()
var captures: Array[Dictionary] = []
var output: String = OUTPUT


func _initialize() -> void:
	_run.call_deferred()


func _fixture(dimensions: Vector2i, level: int, reduced: bool = false, batch: bool = false):
	root.size = dimensions
	var view := Jelly.new()
	root.add_child(view)
	view.size = Vector2(dimensions)
	var words: Array[Dictionary] = []
	var table: Dictionary = {}
	for word: Dictionary in data.words:
		if str(word.id) in ["table", "soap", "bowl", "star", "train"]:
			words.append(word)
		if str(word.id) == "table":
			table = word
	assert(not table.is_empty(), "The table fixture requires the production table word.")
	view.configure(words, 4, Data.theme("spring"), data.chests, reduced, 42)
	view.set_pip_level(3)
	assert(view.game.phase == "playing", view.game.error)
	view.set_process(false)
	view.game.spawn_interval = 10000.0
	view.credit_collection = func(_id: String, _coins: int) -> Dictionary: return {"ok": true}
	view.game.cells.clear()
	var selected: int = -1
	for index in range(23):
		var word: Dictionary = table if index == 22 else words[index % words.size()]
		var tile: Dictionary = view.game._new_picture_tile(word) if index % 2 else view.game._new_word_root(word)
		if index == 22 or (batch and index >= 20):
			view.game._set_merged_word(tile, word, level, true)
			selected = int(tile.id)
		tile.column = index % view.game.COLUMNS
		tile.row = view.game.ROWS - 1 - index / view.game.COLUMNS
		tile.age = view.game.SETTLE_SECONDS
		tile.settling = false
		tile.falling = false
		tile.arrival = false
		view.game.cells.append(tile)
	view._sync_tiles()
	view._layout()
	view._reflow.clear()
	view._word_reveal._rng.seed = 20261024
	view._sync_positions()
	if batch:
		view._collect_all()
	else:
		view._collect(selected)
	assert(not view.game.fusions.is_empty(), "The collection fixture must start an accepted pickup.")
	return view


func _capture(view, name: String, elapsed: float, level: int, pop_at: float, scenario: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = output + "/" + name + ".png"
	var frame: Image = root.get_texture().get_image()
	if frame.save_png(path) != OK:
		push_error("Could not capture " + path)
		quit(1)
		return
	var fusion_states: Array[Dictionary] = []
	for fusion: Dictionary in view.game.fusions:
		var visual: Dictionary = view._fusion_visuals.get(str(fusion.attempt_id), {})
		if not visual.is_empty():
			fusion_states.append({"scale": [visual.merged.scale.x, visual.merged.scale.y],
				"alpha": visual.merged.modulate.a, "pop_at": fusion.pop_at,
				"elapsed": fusion.elapsed, "merge_level": fusion.merge_level})
	captures.append({"file": path, "elapsed": elapsed, "level": level, "pop_at": pop_at,
		"scenario": scenario, "dimensions": [frame.get_width(), frame.get_height()],
		"fusions": fusion_states, "effects": view._collection_effects.snapshot(),
		"reveal": view._word_reveal.snapshot()})


func _run() -> void:
	var baseline: bool = "--baseline" in OS.get_cmdline_user_args()
	var frames: bool = "--frames" in OS.get_cmdline_user_args() and not baseline
	output += "/baseline" if baseline else "/after"
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.min_size = Vector2i.ZERO
	DirAccess.make_dir_recursive_absolute(output)
	if not data.load_all():
		quit(1)
		return
	var layouts: Dictionary = {"desktop": Vector2i(1000, 720),
		"portrait": Vector2i(390, 844), "landscape": Vector2i(844, 390)}
	for level: int in [3, 6]:
		for layout: String in layouts:
			for mode: String in ["single", "batch", "reduced"]:
				var scenario: String = "lv%d-%s-%s" % [level, layout, mode]
				var view = _fixture(layouts[layout], level, mode == "reduced", mode == "batch")
				var pop_at: float = Model.collection_pop_seconds(level, mode == "batch")
				var times: Array[float] = [0.0, pop_at * 0.38, maxf(pop_at * 0.50, pop_at - 0.06),
					pop_at + 0.04, pop_at + 0.10, pop_at + 0.24, pop_at + 0.45, pop_at + 0.85]
				var previous: float = 0.0
				for time: float in times:
					while previous < time - 0.00001:
						var delta: float = minf(1.0 / 60.0, time - previous)
						view._process(delta)
						previous += delta
					await _capture(view, "%s-%04dms" % [scenario, roundi(time * 1000)], time,
						level, pop_at, scenario)
				view.free()
		if frames:
			var name: String = "lv%d-portrait-animation" % level
			DirAccess.make_dir_recursive_absolute(output + "/" + name)
			var animated = _fixture(Vector2i(390, 844), level)
			for frame in range(91):
				if frame > 0:
					animated._process(1.0 / 30.0)
				await _capture(animated, name + "/frame-%03d" % frame, frame / 30.0,
					level, Model.collection_pop_seconds(level), name)
			animated.free()
	var report := FileAccess.open(output + "/capture-report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"notice": "Native deterministic production view; silent samples, not physical device verification.",
		"baseline": baseline, "renderer": RenderingServer.get_video_adapter_name(), "captures": captures}, "\t") + "\n")
	print("Captured %d top jelly charge frames in %s" % [captures.size(), output])
	quit()
