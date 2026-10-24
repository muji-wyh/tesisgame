extends SceneTree
## Native production view with a deterministic board; no audio or device claims.

const Jelly = preload("res://scripts/word_jelly.gd")
const Data = preload("res://scripts/game_data.gd")
var output: String = "res://build/qa/six-level-jelly"
var data := Data.new()
var captures: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _fixture(dimensions: Vector2i, reduced: bool = false, batch: bool = false, level: int = 4):
	root.size = dimensions
	var view := Jelly.new()
	root.add_child(view)
	view.size = Vector2(dimensions)
	var words: Array[Dictionary] = []
	for word: Dictionary in data.words:
		if str(word.id) in ["cat", "apple", "bird", "walk", "peach"]:
			words.append(word)
	view.configure(words, 3, Data.theme("spring"), data.chests, reduced, 42)
	view.set_pip_level(3)
	view.set_process(false)
	view.game.spawn_interval = 10000.0
	view.credit_collection = func(_id: String, _coins: int) -> Dictionary: return {"ok": true}
	view.game.cells.clear()
	var selected: int = -1
	for index in range(23):
		var word: Dictionary = words[index % words.size()]
		var tile: Dictionary = view.game._new_picture_tile(word) if index % 2 else view.game._new_word_root(word)
		if index == 22 or (batch and index >= 20):
			view.game._set_merged_word(tile, word, maxi(4, level - 2) + index % 3 if batch else level, true)
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
	return view

func _capture(view, name: String, elapsed: float) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = output + "/" + name + ".png"
	if root.get_texture().get_image().save_png(path) != OK:
		push_error("Could not capture " + path)
		quit(1)
	var fusion_state: Dictionary = {}
	if not view.game.fusions.is_empty():
		var fusion: Dictionary = view.game.fusions[0]
		var visual: Dictionary = view._fusion_visuals.get(str(fusion.attempt_id), {})
		if not visual.is_empty():
			fusion_state = {"scale": visual.merged.scale.x, "alpha": visual.merged.modulate.a,
				"pop_at": fusion.pop_at, "elapsed": fusion.elapsed}
	captures.append({"file": path, "elapsed": elapsed, "fusion": fusion_state,
		"effects": view._collection_effects.snapshot(), "reveal": view._word_reveal.snapshot()})

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.min_size = Vector2i.ZERO
	if "--high-levels" in OS.get_cmdline_user_args():
		output = "res://build/qa/jelly-lv9-2026-10-25"
	DirAccess.make_dir_recursive_absolute(output + "/animation")
	if not data.load_all():
		quit(1)
		return
	if "--high-levels" in OS.get_cmdline_user_args():
		await _high_levels()
		return
	var phone = _fixture(Vector2i(390, 844))
	for frame in range(121):
		if frame > 0:
			phone._process(1.0 / 30.0)
		await _capture(phone, "animation/frame-%03d" % frame, frame / 30.0)
	phone.free()
	for scenario: String in ["desktop", "reduced", "batch"]:
		var view = _fixture(Vector2i(1000, 720) if scenario == "desktop" else Vector2i(390, 844),
			scenario == "reduced", scenario == "batch")
		var previous: float = 0.0
		for time: float in [0.0, 0.22, 0.55, 0.70, 1.05, 1.50, 2.20, 2.85, 3.50]:
			while previous < time - 0.00001:
				var delta: float = minf(1.0 / 30.0, time - previous)
				view._process(delta)
				previous += delta
			await _capture(view, "%s-%04dms" % [scenario, roundi(time * 1000)], time)
		view.free()
	var report := FileAccess.open(output + "/capture-report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"notice": "Native deterministic production view; silent 30 fps samples, not physical device verification.",
		"renderer": RenderingServer.get_video_adapter_name(), "captures": captures}, "\t") + "\n")
	print("Captured %d integrated firework frames" % captures.size())
	quit()


func _high_levels() -> void:
	for layout: String in ["phone", "desktop"]:
		var dimensions := Vector2i(390, 844) if layout == "phone" else Vector2i(1000, 720)
		for level in [7, 8, 9]:
			var view = _fixture(dimensions, false, false, level)
			var previous: float = 0.0
			var pop: float = view.game.collection_pop_seconds(level)
			for time: float in [0.0, pop * 0.75, pop + 0.12, pop + 0.60, pop + 1.35, pop + 1.90, pop + 3.20]:
				while previous < time - 0.00001:
					var delta: float = minf(1.0 / 30.0, time - previous)
					view._process(delta)
					previous += delta
				await _capture(view, "%s-lv%d-%04dms" % [layout, level, roundi(time * 1000)], time)
			view.free()
		for scenario: String in ["reduced", "batch"]:
			var view = _fixture(dimensions, scenario == "reduced", scenario == "batch", 9)
			var previous: float = 0.0
			for time: float in [0.05, 0.35, 0.85, 1.40, 2.00, 2.50, 3.50, 4.50]:
				while previous < time - 0.00001:
					var delta: float = minf(1.0 / 30.0, time - previous)
					view._process(delta)
					previous += delta
				await _capture(view, "%s-%s-%04dms" % [layout, scenario, roundi(time * 1000)], time)
			view.free()
	var report := FileAccess.open(output + "/capture-report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"notice": "Native deterministic production view; silent sampled phases, not physical-device verification.",
		"renderer": RenderingServer.get_video_adapter_name(), "captures": captures}, "\t") + "\n")
	print("Captured %d integrated Lv7-Lv9 firework phases" % captures.size())
	quit()
