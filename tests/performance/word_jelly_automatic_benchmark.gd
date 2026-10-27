extends SceneTree
## Headless automatic-action CPU diagnostics; not browser, GPU or device FPS.

const Data = preload("res://scripts/game_data.gd")
const Model = preload("res://scripts/word_jelly_model.gd")

class ObservedJelly extends "res://scripts/word_jelly.gd":
	var position_passes: int = 0
	var snapshots: int = 0
	var cpu_us: Dictionary = {}
	func _sync_positions() -> void:
		var started: int = Time.get_ticks_usec()
		position_passes += 1
		super._sync_positions()
		cpu_us["positions"] = int(cpu_us.get("positions", 0)) + Time.get_ticks_usec() - started
	func snapshot() -> Dictionary:
		var started: int = Time.get_ticks_usec()
		snapshots += 1
		var state: Dictionary = super.snapshot()
		cpu_us["snapshot"] = int(cpu_us.get("snapshot", 0)) + Time.get_ticks_usec() - started
		return state
	func _sync_tiles() -> void:
		var started: int = Time.get_ticks_usec()
		super._sync_tiles()
		cpu_us["tiles"] = int(cpu_us.get("tiles", 0)) + Time.get_ticks_usec() - started
	func _refresh_controls() -> void:
		var started: int = Time.get_ticks_usec()
		super._refresh_controls()
		cpu_us["controls"] = int(cpu_us.get("controls", 0)) + Time.get_ticks_usec() - started
	func _refresh_fusion() -> void:
		var started: int = Time.get_ticks_usec()
		super._refresh_fusion()
		cpu_us["fusion"] = int(cpu_us.get("fusion", 0)) + Time.get_ticks_usec() - started
	func _collection_started(fusion: Dictionary) -> void:
		var started: int = Time.get_ticks_usec()
		super._collection_started(fusion)
		cpu_us["collection_start"] = int(cpu_us.get("collection_start", 0)) + Time.get_ticks_usec() - started

var serialized_characters: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var options: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	var samples: int = int(options.get("samples", 600))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(390, 844)
	var data := Data.new()
	assert(data.load_all())
	var cat: Dictionary = data.words.filter(func(word: Dictionary) -> bool: return str(word.id) == "cat")[0]
	var rows: Array[Dictionary] = []
	for mode: String in ["auto-merge", "auto-collect"]:
		var view := ObservedJelly.new()
		root.add_child(view)
		view.size = Vector2(390, 844)
		view.changed.connect(_publish)
		assert(view.configure([cat], 3, Data.theme("spring"), data.chests, false, 73021))
		view.set_process(false)
		view.set_pip_level(99)
		view.coin_balance = func() -> int: return 1000000
		view.purchase_powerup = func(_id: String, _kind: String, _price: int) -> Dictionary: return {"ok": true}
		view.credit_collection = func(_id: String, _amount: int) -> Dictionary: return {"ok": true}
		view.game.credit_combo = func(_id: String, _amount: int) -> Dictionary: return {"ok": true}
		view.game.cells.clear()
		view.game.spawn_interval = 10000.0
		var count: int = Model.CAPACITY - Model.COLUMNS
		for index in range(count):
			var tile: Dictionary = view.game._new_word_root(cat) \
				if mode == "auto-collect" or index % 2 == 0 else view.game._new_picture_tile(cat)
			if mode == "auto-collect":
				view.game._set_merged_word(tile, cat, index % 9 + 1, true)
			tile.fragments = 0
			tile.chest = false
			tile.column = index % Model.COLUMNS
			tile.row = Model.ROWS - 1 - int(index / Model.COLUMNS)
			tile.age = 2.0
			tile.arrival = false
			tile.falling = false
			tile.settling = false
			view.game.cells.append(tile)
		view._sync_tiles()
		view._layout()
		for frame in range(30):
			view._process(1.0 / 60.0)
		view.position_passes = 0
		view.snapshots = 0
		serialized_characters = 0
		view.cpu_us.clear()
		var activation_started: int = Time.get_ticks_usec()
		if mode == "auto-merge":
			assert(view.game.activate_powerup("auto_merge"))
		else:
			assert(not view.collect_button.disabled)
			view.collect_button.pressed.emit()
			assert(view.game.collection_batch_active())
		var activation_us: int = Time.get_ticks_usec() - activation_started
		var activation_cpu: Dictionary = view.cpu_us.duplicate()
		view.cpu_us.clear()
		var times: Array[int] = []
		var trace: Array = []
		for frame in range(samples):
			var started: int = Time.get_ticks_usec()
			view._process(1.0 / 60.0)
			times.append(Time.get_ticks_usec() - started)
			trace.append([view.game.cells.size(), view.game.fusions.size(), view.game.merged_count,
				view.game.cleared_pairs, view.game.collected_coins,
				view.game.powerup_active(), view.game.collection_batch_active()])
		assert(view.game.error.is_empty(), view.game.error)
		assert(not view.game.powerup_active() and not view.game.collection_batch_active())
		assert(view.game.merged_count > 0 and view.game.cells.size() < count if mode == "auto-merge" \
			else view.game.cleared_pairs == count and view.game.cells.is_empty())
		rows.append({"scenario": mode, "tiles": count, "contact": false, "motion_events_per_frame": 0,
			"activation_us": activation_us, "samples_us": times, "frames": samples,
			"activation_cpu_us": activation_cpu, "inclusive_cpu_us": view.cpu_us.duplicate(),
			"position_passes": view.position_passes, "snapshots": view.snapshots,
			"serialized_characters": serialized_characters, "contact_frames": 0,
			"interaction_trace": trace})
		view.free()
		await process_frame
	var report := {"protocol": "word-jelly-auto-cpu-v1", "engine": Engine.get_version_info(),
		"scope": "Headless CPU: dense real-art Word Jelly views, actual Auto Merge planning and Lv1-9 Auto Collect, normal motion, real model clocks and host JSON. Zero carried fragments isolates board work from chest presentation. Excludes GPU, browser bridge, real wallet I/O and device FPS.",
		"rows": rows}
	var file := FileAccess.open(str(options.output), FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report))
	file.close()
	print("Word Jelly automatic CPU diagnostic: %d scenarios" % rows.size())
	quit()


func _publish(state: Dictionary) -> void:
	serialized_characters += JSON.stringify(state.duplicate(true)).length()
