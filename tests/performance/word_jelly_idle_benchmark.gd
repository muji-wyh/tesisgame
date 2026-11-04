extends SceneTree
## Paired settled-board CPU diagnostic. Rendering and physical FPS are excluded.

const Fixture = preload("res://tests/performance/jelly_drag_fixture.gd")
const Data = preload("res://scripts/game_data.gd")
const WordArt = preload("res://scripts/word_art.gd")

class ObservedJelly extends "res://scripts/word_jelly.gd":
	var position_passes: int = 0
	var snapshots: int = 0
	func _sync_positions() -> void:
		position_passes += 1
		super._sync_positions()
	func snapshot() -> Dictionary:
		snapshots += 1
		return super.snapshot()

var serialized_characters: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var options: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	var samples: int = int(options.get("samples", 180))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	var data := Data.new()
	assert(data.load_all())
	var cat: Dictionary = data.words.filter(func(word: Dictionary) -> bool: return str(word.id) == "cat")[0]
	var rows: Array[Dictionary] = []
	for count: int in [21, 49]:
		for mix: String in ["ordinary", "merged"]:
			var view := ObservedJelly.new()
			root.add_child(view)
			view.size = Vector2(1366, 768)
			Fixture.install(view, data, count)
			if mix == "merged":
				for cell: Dictionary in view.game.cells:
					view.game._set_merged_word(cell, cat, int(cell.id) % 9 + 1, true)
					cell.fragments = 0
					cell.chest = false
					view._configure_tile(view._tiles[int(cell.id)], cell)
				view._sync_tiles()
			view.changed.connect(_publish)
			for frame in range(60):
				WordArt.advance(1.0 / 60.0)
				view._process(1.0 / 60.0)
			view.position_passes = 0
			view.snapshots = 0
			serialized_characters = 0
			var times: Array[int] = []
			var interaction_trace: Array = []
			for frame in range(samples):
				var started := Time.get_ticks_usec()
				WordArt.advance(1.0 / 60.0)
				view._process(1.0 / 60.0)
				times.append(Time.get_ticks_usec() - started)
				assert(view.game.cells.size() == count and view.game.phase == "playing")
				assert(view.game.merged_count == 0 and view.game.cleared_pairs == 0)
				var cells: Array = []
				for cell: Dictionary in view.game.cells:
					var tile = view._tiles[int(cell.id)]
					cells.append([int(cell.id), int(cell.column), int(cell.row), float(cell.age),
						tile.position.x, tile.position.y, tile.size.x, tile.size.y,
						tile.visible, tile.disabled, tile.modulate.a, view._settled(cell)])
				interaction_trace.append([view.game.phase, view.game.generated_tiles,
					view.game.merged_count, view.game.cleared_pairs, cells])
			var work: Dictionary = view.presentation_work_snapshot() if view.has_method("presentation_work_snapshot") else {}
			rows.append({"scenario": "idle-" + mix, "tiles": count, "mix": mix,
				"samples_us": times, "frames": samples, "warmup": 60,
				"position_passes": view.position_passes, "snapshots": view.snapshots,
				"serialized_characters": serialized_characters,
				"interaction_trace": interaction_trace, "presentation_work": work})
			print("Idle CPU: %d %s bodies" % [count, mix])
			view.free()
			await process_frame
	var report := {"protocol": "word-jelly-idle-cpu-v1", "engine": Engine.get_version_info(),
		"scope": "Headless CPU: deterministic real-art settled boards at 1366x768, 60Hz model/view and shared WordArt clock, plus host snapshot copy/JSON serialization. Excludes GPU cache rendering, browser bridge, audio and physical input/frame pacing.", "rows": rows}
	var file := FileAccess.open(str(options.output), FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report))
	file.close()
	quit()

func _publish(state: Dictionary) -> void:
	serialized_characters += JSON.stringify(state.duplicate(true)).length()
