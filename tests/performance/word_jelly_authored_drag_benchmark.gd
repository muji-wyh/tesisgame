extends "res://tests/performance/word_jelly_drag_benchmark.gd"
## Desktop CPU coverage for actual authored sources and all matching hint semantics.

const AuthoredFixture = preload("res://tests/performance/jelly_authored_drag_fixture.gd")
const WordArt = preload("res://scripts/word_art.gd")

func _run() -> void:
	var options: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	var samples: int = int(options.get("samples", 120))
	var warmup: int = 30
	var dimensions := Vector2i(int(options.get("width", 1366)), int(options.get("height", 768)))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = dimensions
	var data := Data.new()
	assert(data.load_all())
	var rows: Array[Dictionary] = []
	for scenario: Dictionary in [{"tiles": 49, "source_kind": "root"}, {"tiles": 49, "source_kind": "merged"},
		{"tiles": Model.CAPACITY, "source_kind": "root"}, {"tiles": Model.CAPACITY, "source_kind": "merged"}]:
		var count: int = int(scenario.tiles)
		var source_kind: String = str(scenario.source_kind)
		for contact: bool in [false, true]:
			for bursts: int in [1, 4]:
				var view := ObservedJelly.new()
				root.add_child(view)
				view.size = Vector2(dimensions)
				view.changed.connect(_publish)
				var pair: Array[int] = AuthoredFixture.install(view, data, count, source_kind)
				assert(view._press(7, view._tiles[pair[0]].get_global_rect().get_center()))
				var times: Array[int] = []
				var interaction_trace: Array = []
				var contact_frames: int = 0
				var hint_ids: Array[int] = []
				for frame in range(warmup + samples):
					if frame == warmup:
						view.position_passes = 0
						view.snapshots = 0
						view.cpu_us.clear()
						serialized_characters = 0
						hint_ids.assign(view._hint_matching_ids)
						assert(hint_ids.size() == AuthoredFixture.expected_hint_count(count, source_kind))
					var started: int = Time.get_ticks_usec()
					WordArt.advance(1.0 / 60.0)
					for sample in range(bursts):
						AuthoredFixture.motion(view, AuthoredFixture.point(view, pair, frame, sample, bursts, contact))
					view._process(1.0 / 60.0)
					if frame >= warmup:
						times.append(Time.get_ticks_usec() - started)
						# Trace semantic cues and movement outside the timing window.
						var source_position: Vector2 = view._tiles[pair[0]].position
						var contact_kind: String = str(view._contact_state().kind)
						contact_frames += 1 if view._target >= 0 else 0
						assert(view._hint_matching_ids == hint_ids)
						for id: int in hint_ids:
							assert(view._tiles[id].completion_hint)
						interaction_trace.append([source_position.x, source_position.y, view._target, contact_kind,
							bool(view._placement.get("valid", false)), int(view._placement.get("column", -1)),
							int(view._placement.get("row", -1)), hint_ids.duplicate()])
				assert(view._dragging and view.game.cells.size() == count and view.game.phase == "playing")
				assert(view.game.merged_count == 0 and view.game.cleared_pairs == 0)
				assert(contact_frames > 0 if contact else contact_frames == 0)
				rows.append({"scenario": "authored-drag-" + source_kind, "tiles": count,
					"source_kind": source_kind, "source_has_composition": true,
					"word_id": "cat" if source_kind == "root" else "friendly", "dimensions": [dimensions.x, dimensions.y],
					"contact": contact, "motion_events_per_frame": bursts,
					"samples_us": times, "position_passes": view.position_passes, "snapshots": view.snapshots,
					"serialized_characters": serialized_characters, "frames": samples, "warmup": warmup,
					"inclusive_cpu_us": view.cpu_us.duplicate(), "hint_ids": hint_ids,
					"contact_frames": contact_frames, "interaction_trace": interaction_trace,
					"presentation_work": view.presentation_work_snapshot()})
				print("Authored drag CPU: %s, contact=%s, motion bursts=%d" % [source_kind, contact, bursts])
				view.free()
				await process_frame
	var report := {"protocol": "word-jelly-authored-drag-cpu-v1", "engine": Engine.get_version_info(),
		"scope": "Headless CPU: 49/56-body real-art desktop boards, reviewed Growth cat roots/pictures and friendly authored merged composition, all matching semantic hints, coalesced touch input, 60Hz model/view and shared artwork clock, host snapshot copy/JSON serialization. Excludes renderer, browser bridge, audio playback and physical input latency.",
		"rows": rows}
	var file := FileAccess.open(str(options.get("output", "user://word-jelly-authored-drag-cpu.json")), FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report))
	file.close()
	print("Word Jelly authored drag CPU diagnostic: %d scenarios" % rows.size())
	quit()
