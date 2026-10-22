extends SceneTree
## Headless CPU diagnostic, not rendered FPS, GPU time or physical touch latency.

const Fixture = preload("res://tests/performance/jelly_drag_fixture.gd")
const Data = preload("res://scripts/game_data.gd")

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
		var pair: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			options[pair[0]] = pair[1]
	var samples: int = int(options.get("samples", 120))
	var warmup: int = 30
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(390, 844)
	var data := Data.new()
	assert(data.load_all())
	var rows: Array[Dictionary] = []
	for count: int in [18, 42]:
		for contact: bool in [false, true]:
			for bursts: int in [1, 4]:
				var view := ObservedJelly.new()
				root.add_child(view)
				view.size = Vector2(390, 844)
				view.changed.connect(_publish)
				var pair: Array[int] = Fixture.install(view, data, count)
				assert(view._press(7, view._tiles[pair[0]].get_global_rect().get_center()))
				var times: Array[int] = []
				var interaction_trace: Array = []
				var contact_frames: int = 0
				for frame in range(warmup + samples):
					if frame == warmup:
						view.position_passes = 0
						view.snapshots = 0
						serialized_characters = 0
					var started: int = Time.get_ticks_usec()
					for sample in range(bursts):
						Fixture.motion(view, Fixture.point(view, pair, frame, sample, bursts, contact))
					view._process(1.0 / 60.0)
					if frame >= warmup:
						times.append(Time.get_ticks_usec() - started)
						# Validate equivalent interaction work outside the timing window.
						var source_position: Vector2 = view._tiles[pair[0]].position
						var contact_kind: String = str(view._contact_state().kind)
						contact_frames += 1 if view._target >= 0 else 0
						interaction_trace.append([source_position.x, source_position.y, view._target, contact_kind,
							bool(view._placement.get("valid", false)), int(view._placement.get("column", -1)), int(view._placement.get("row", -1))])
				assert(view._dragging and view.game.cells.size() == count and view.game.phase == "playing")
				assert(contact_frames > 0 if contact else contact_frames == 0)
				rows.append({"tiles": count, "contact": contact, "motion_events_per_frame": bursts,
					"samples_us": times, "position_passes": view.position_passes, "snapshots": view.snapshots,
					"serialized_characters": serialized_characters, "frames": samples,
					"contact_frames": contact_frames, "interaction_trace": interaction_trace})
				view.free()
				await process_frame
	var report := {"protocol": "word-jelly-drag-cpu-v1", "engine": Engine.get_version_info(),
		"scope": "Headless CPU: real Word Jelly view, seeded 390x844 boards, touch events, manual 60Hz simulation, artwork/layout and host serialization. Excludes renderer, browser bridge execution, audio playback and physical input latency.",
		"rows": rows}
	var file := FileAccess.open(str(options.output), FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report))
	file.close()
	print("Word Jelly drag CPU diagnostic: %d scenarios" % rows.size())
	quit()

func _publish(state: Dictionary) -> void:
	# Reproduce the existing host's copy and JSON serialization; browser work is excluded.
	serialized_characters += JSON.stringify(state.duplicate(true)).length()
