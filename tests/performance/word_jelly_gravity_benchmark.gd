extends SceneTree
## Paired gravity-pass CPU timing. Rendering and physical FPS are excluded.

const Model = preload("res://scripts/word_jelly_model.gd")
const Regression = preload("res://tests/godot/word_jelly_gravity_cache_tests.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var options: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	var samples: int = int(options.get("samples", 1000))
	var warmup: int = 30
	assert(samples > 0)
	var words: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	assert(words is Array)
	var cat: Dictionary = words.filter(func(word: Dictionary) -> bool: return str(word.id) == "cat")[0]
	var rows: Array[Dictionary] = []
	for scenario: String in ["lifted-support", "falling", "removed-support"]:
		var reference := Regression.ReferenceModel.new()
		var current := Regression.CountedModel.new()
		for model in [reference, current]:
			assert(model.configure([cat], 3, 73021))
			model.spawn_interval = 10000.0
		var board: Array[Dictionary] = []
		for index in range(Model.CAPACITY):
			var tile: Dictionary = reference._new_word_root(cat) if index % 2 == 0 else reference._new_picture_tile(cat)
			tile.column = index % Model.COLUMNS
			tile.row = Model.ROWS - 1 - int(index / Model.COLUMNS)
			tile.age = 2.0
			board.append(tile)
		var held_id: int = -1
		if scenario == "removed-support":
			board.remove_at(0)
		else:
			board[0].lifted = true
			held_id = int(board[0].id)
		var fixture: Dictionary = {"cells": board, "held_id": held_id}
		if scenario == "falling":
			for model in [reference, current]:
				_reset(model, fixture)
				model._settle_collected_stack()
			assert(_equal_gravity(reference, current))
			fixture.cells = reference.cells.duplicate(true)
		var reference_us: Array[int] = []
		var current_us: Array[int] = []
		for sample in range(warmup + samples):
			if sample == warmup:
				reference.occupancy_queries = 0
				current.occupancy_queries = 0
			# Restore identical real board data outside the measured gravity pass.
			for model in [reference, current]:
				_reset(model, fixture)
			var order: Array = [reference, current] if sample % 2 == 0 else [current, reference]
			for model in order:
				var started: int = Time.get_ticks_usec()
				model._settle_collected_stack()
				var elapsed: int = Time.get_ticks_usec() - started
				if sample >= warmup:
					if model == reference:
						reference_us.append(elapsed)
					else:
						current_us.append(elapsed)
			assert(_equal_gravity(reference, current), "Paired gravity timing must preserve every footprint, clock and pending flag")
		var before: Dictionary = _statistics(reference_us)
		var after: Dictionary = _statistics(current_us)
		rows.append({"scenario": scenario, "source_tiles": Model.CAPACITY, "tiles": fixture.cells.size(),
			"samples": samples, "warmup": warmup, "seed": 73021, "paired_semantics_equal": true,
			"baseline": before, "candidate": after, "baseline_samples_us": reference_us, "candidate_samples_us": current_us,
			"baseline_occupancy_queries": reference.occupancy_queries, "candidate_occupancy_queries": current.occupancy_queries,
			"mean_reduction_percent": (1.0 - float(after.mean_us) / float(before.mean_us)) * 100.0})
		print("Gravity CPU: %s, old %.3f ms, current %.3f ms" % [scenario, float(before.mean_us) / 1000.0, float(after.mean_us) / 1000.0])
	var report: Dictionary = {"protocol": "word-jelly-gravity-cpu-v1", "engine": Engine.get_version_info(),
		"scope": "Headless CPU: paired original per-body occupancy and current gravity passes on production-vocabulary 56-body boards with lifted support, active falls and removed support. Identical fixture resets and semantic comparisons are outside timing; call order alternates. Measures only gravity CPU, excluding model clock advancement, view, rendering, browser, audio and physical FPS.",
		"rows": rows}
	var file := FileAccess.open(str(options.get("output", "user://word-jelly-gravity-cpu.json")), FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report))
	file.close()
	quit()


func _reset(model, fixture: Dictionary) -> void:
	model.cells.assign(fixture.cells.duplicate(true))
	model._held_tile_id = int(fixture.held_id)
	model._dragged_tile_id = -1
	model._drag_gravity_delays.clear()
	model._gravity_pending = true
	model._growth_pending = false


func _equal_gravity(reference, current) -> bool:
	return reference.cells == current.cells and reference._gravity_pending == current._gravity_pending \
		and reference._growth_pending == current._growth_pending \
		and reference._drag_gravity_delays == current._drag_gravity_delays


func _statistics(values: Array[int]) -> Dictionary:
	var sorted: Array[int] = values.duplicate()
	sorted.sort()
	var total: float = 0.0
	for value: int in values:
		total += value
	return {"mean_us": total / values.size(), "p50_us": sorted[ceili(sorted.size() * 0.50) - 1],
		"p95_us": sorted[ceili(sorted.size() * 0.95) - 1], "p99_us": sorted[ceili(sorted.size() * 0.99) - 1]}
