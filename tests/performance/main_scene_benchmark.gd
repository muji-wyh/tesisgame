extends SceneTree
## Rendered native benchmark. Never use the one-second TIME_PROCESS maximum as a frame sample.

const PlayerFixture = preload("res://tests/godot/player_flow_fixture.gd")
const SCENARIOS := ["match", "memory", "voice-pop", "growth", "catalog", "chest"]
const PROTOCOL := "main-scene-rendered-v2"

class FrameStart extends Node:
	var bench
	func _process(delta: float) -> void:
		bench._begin_frame(delta)

class FrameEnd extends Node:
	var bench
	func _process(_delta: float) -> void:
		bench._end_process()

var _app
var _directory: String
var _options: Dictionary = {}
var _scenario: String
var _sampling := false
var _pending_draw := false
var _failed := false
var _begin_usec: int = 0
var _process_usec: int = 0
var _previous_begin_usec: int = 0
var _process_samples: Array[int] = []
var _rendered_samples: Array[int] = []
var _interval_samples: Array[int] = []
var _target_counts: Array[int] = []
var _drawn_target_counts: Array[int] = []
var _target_frame_count: int = 0
var _drawn_target_frame_count: int = 0
var _target_peak: int = 0
var _drawn_target_peak: int = 0
var _actions: Array[Dictionary] = []
var _pairs: Array = []
var _catalog_word_ids: Array[String] = []
var _growth_before: Dictionary = {}
var _catalog_card_peak: int = 0
var _catalog_texture_peak: int = 0
var _chest_cues: Array[String] = []
var _draws: int = 0
var _sample_count: int = 240
var _warmup_count: int = 90
var _seed: int = 73021


func _initialize() -> void:
	_run.call_deferred()


func _require(condition: bool, message: String) -> bool:
	if not condition and not _failed:
		_failed = true
		_sampling = false
		_pending_draw = false
		printerr("BENCHMARK FAILED: " + message)
		_shutdown.call_deferred(1)
	return condition


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		var pair: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			_options[pair[0]] = pair[1]
	_sample_count = int(_options.get("samples", 240))
	_warmup_count = int(_options.get("warmup", 90))
	_seed = int(_options.get("seed", 73021))
	var requested: PackedStringArray = str(_options.get("scenarios", ",".join(SCENARIOS))).split(",")
	if not _require(DisplayServer.get_name() != "headless", "A real native renderer is required"):
		return
	if not _require(_sample_count > 0 and _warmup_count >= 2 and _options.has("output"), "Invalid benchmark options"):
		return
	Engine.max_fps = 60
	Engine.time_scale = 1.0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(int(_options.get("width", 390)), int(_options.get("height", 844)))
	var first := FrameStart.new()
	first.bench = self
	first.process_priority = -1000000
	root.add_child(first)
	var last := FrameEnd.new()
	last.bench = self
	last.process_priority = 1000000
	root.add_child(last)
	RenderingServer.frame_post_draw.connect(_after_draw)
	var scenarios: Array[Dictionary] = []
	for scenario: String in requested:
		if not _require(scenario in SCENARIOS, "Unknown scenario: " + scenario):
			return
		_scenario = scenario
		await _install_scene()
		if _failed:
			return
		_prepare_scenario()
		if _failed:
			return
		for index in range(_warmup_count):
			# Enter measurement one second into the real five-second chest gesture.
			if scenario == "chest" and index == maxi(0, _warmup_count - 60):
				_app.chest_button.button_down.emit()
			await RenderingServer.frame_post_draw
		var before: Dictionary = _state()
		if not _assert_workload(false):
			return
		_process_samples.clear()
		_rendered_samples.clear()
		_interval_samples.clear()
		_target_counts.clear()
		_drawn_target_counts.clear()
		_target_frame_count = 0
		_drawn_target_frame_count = 0
		_target_peak = 0
		_drawn_target_peak = 0
		_actions.clear()
		_previous_begin_usec = 0
		_pending_draw = false
		_sampling = true
		while _sampling:
			await process_frame
		if _failed:
			return
		var after: Dictionary = _state()
		if not _assert_workload(true):
			return
		if not _require(_process_samples.size() == _sample_count and _rendered_samples.size() == _sample_count,
			"Every sampled process span needs one frame_post_draw"):
			return
		var result := {
			"scenario": scenario, "before": before, "after": after, "actions": _actions.duplicate(true),
			"process_us": _process_samples.duplicate(), "rendered_us": _rendered_samples.duplicate(),
			"frame_interval_us": _interval_samples.duplicate(),
			"target_counts": _target_counts.duplicate(), "drawn_target_counts": _drawn_target_counts.duplicate(),
			"target_frame_count": _target_frame_count, "drawn_target_frame_count": _drawn_target_frame_count,
			"target_peak": _target_peak, "drawn_target_peak": _drawn_target_peak,
			"process": _statistics(_process_samples), "rendered": _statistics(_rendered_samples),
			"frame_interval": _statistics(_interval_samples),
			"node_count": get_node_count(), "object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT))
		}
		if scenario == "catalog":
			result["catalog_card_peak"] = _catalog_card_peak
			result["catalog_texture_peak"] = _catalog_texture_peak
		scenarios.append(result)
		print("BENCHMARK %s rendered_mean_us=%.2f process_mean_us=%.2f" % [scenario, result.rendered.mean, result.process.mean])
		_app.free()
		_app = null
		await process_frame
		_clean_save_directory()
		_directory = ""
	var report := {
		"protocol": PROTOCOL, "label": str(_options.get("label", "diagnostic")),
		"source": str(_options.get("source", "unspecified")), "seed": _seed,
		"engine": Engine.get_version_info(), "timestamp_utc": Time.get_datetime_string_from_system(true),
		"configuration": {
			"window_size": [root.size.x, root.size.y], "max_fps": Engine.max_fps,
			"vsync": DisplayServer.window_get_vsync_mode(), "display_server": DisplayServer.get_name(),
			"rendering_method": RenderingServer.get_current_rendering_method(),
			"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
			"adapter": RenderingServer.get_video_adapter_name(), "audio_driver": AudioServer.get_driver_name(),
			"stretch_mode": ProjectSettings.get_setting("display/window/stretch/mode"),
			"stretch_aspect": ProjectSettings.get_setting("display/window/stretch/aspect"),
			"reduced_motion": false, "audio_muted": false, "microphone_network": false,
			"warmup_frames": _warmup_count, "sample_frames": _sample_count,
			"first_process_priority": first.process_priority, "last_process_priority": last.process_priority
		},
		"scenarios": scenarios, "frame_post_draw_count": _draws
	}
	var file := FileAccess.open(str(_options.output), FileAccess.WRITE)
	if not _require(file != null, "Cannot write benchmark JSON"):
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	_shutdown.call_deferred(0)


func _install_scene() -> void:
	seed(_seed)
	_directory = "user://performance-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	if not _require(DirAccess.make_dir_recursive_absolute(_directory) == OK, "Cannot create isolated storage"):
		return
	_app = load("res://scenes/main.tscn").instantiate()
	_app.medal_progress = load("res://scripts/medal_progress.gd").new(_directory + "/medals.cfg", _directory + "/legacy.cfg")
	PlayerFixture.install(_app, _directory)
	root.add_child(_app)
	await process_frame
	await process_frame
	_app.set_reduced_motion(false)
	_app.audio.set_muted(false)
	# Pip uses a private RNG, independent of the seeded global gameplay generator.
	_app.duck._idle_rng.seed = _seed
	_app.duck.note_activity()
	_require(_app._host == null and not _app._page_hidden and not _app._mode_menu_open(),
		"Native scene must be active, isolated, and ready for gameplay")


func _prepare_scenario() -> void:
	_pairs.clear()
	_catalog_word_ids.clear()
	_catalog_card_peak = 0
	_catalog_texture_peak = 0
	_chest_cues.clear()
	var mode: String = {"voice-pop": "pop"}.get(_scenario, _scenario)
	if mode not in ["match", "memory", "pop"]:
		mode = "match"
	if not _require(_app.new_round(_seed, false, "", mode), "Deterministic curriculum round must start"):
		return
	_app.choose_theme("spring")
	match _scenario:
		"match", "chest":
			for card: Dictionary in _app.model.cards:
				if card.kind == "word":
					_pairs.append([str(card.id), str(card.word.id) + ":image"])
			if _scenario == "chest":
				for pair: Array in _pairs:
					_app.cards[pair[0]].pressed.emit()
					_app.cards[pair[1]].pressed.emit()
					_app._continue_match()
				PlayerFixture.finish_celebration(_app)
				_app.chest.cue_requested.connect(func(_theme: String, cue: String, _step: int) -> void: _chest_cues.append(cue))
		"memory":
			var board: Array = _app._memory.memory.cards
			for index in range(board.size()):
				if board[index].kind == "word":
					for partner in range(board.size()):
						if board[partner].kind == "image" and board[index].word.id == board[partner].word.id:
							_pairs.append([index, partner])
		"voice-pop":
			PlayerFixture.choose_pop_player(_app)
			_app._on_voice_state([true, true, "Listening. Say an English word."])
		"growth", "catalog":
			_app._show_collection()
			_growth_before = _app.growth.snapshot()
			if _scenario == "catalog":
				_app._age_buttons["7"].pressed.emit()
				# Capture the complete ordered age-seven cohort before timing; rendered cards
				# contain only the current page and cannot select a distant word.
				_catalog_word_ids.assign(_app._age_catalog.snapshot().word_ids)


func _begin_frame(_delta: float) -> void:
	if not _sampling:
		return
	var now: int = Time.get_ticks_usec()
	if not _require(not _pending_draw, "Renderer did not emit frame_post_draw before the next process frame"):
		_sampling = false
		return
	_begin_usec = now
	if _previous_begin_usec > 0:
		_interval_samples.append(now - _previous_begin_usec)
	_previous_begin_usec = now
	_pending_draw = true
	_scheduled_input(_rendered_samples.size())


func _end_process() -> void:
	if _sampling and _pending_draw:
		_process_usec = Time.get_ticks_usec() - _begin_usec


func _after_draw() -> void:
	var end_usec: int = Time.get_ticks_usec()
	_draws += 1
	if not _sampling or not _pending_draw:
		return
	_process_samples.append(_process_usec)
	_rendered_samples.append(end_usec - _begin_usec)
	# Collect evidence after capturing the endpoint, outside the timed span.
	# A successful last hit may leave an empty screen between natural volleys.
	if _scenario == "voice-pop":
		var target_count: int = _app._pop.game.targets.size()
		var drawn_count: int = _app._pop._draw_targets.size() if _visible_control(_app._pop) else 0
		_target_counts.append(target_count)
		_drawn_target_counts.append(drawn_count)
		_target_frame_count += 1 if target_count > 0 else 0
		_drawn_target_frame_count += 1 if drawn_count > 0 else 0
		_target_peak = maxi(_target_peak, target_count)
		_drawn_target_peak = maxi(_drawn_target_peak, drawn_count)
	elif _scenario == "catalog":
		_catalog_card_peak = maxi(_catalog_card_peak, _app._age_catalog.word_buttons.size())
		_catalog_texture_peak = maxi(_catalog_texture_peak, _app._age_catalog._textures.size())
	_pending_draw = false
	if _rendered_samples.size() >= _sample_count:
		_sampling = false


func _scheduled_input(frame: int) -> void:
	# Inputs use real scene handlers. No animation or gameplay clock is advanced manually.
	var early: int = int(_sample_count * 0.08)
	var middle: int = int(_sample_count * 0.50)
	match _scenario:
		"match":
			if frame in [early, middle]:
				var pair: Array = _pairs[0 if frame == early else 1]
				_app.cards[pair[0]].pressed.emit()
				_app.cards[pair[1]].pressed.emit()
				_actions.append({"frame": frame, "action": "match_pair", "pair": pair})
		"memory":
			if frame in [early, early + 15, middle, middle + 15]:
				var pair_index: int = 0 if frame < middle else 1
				var side: int = 0 if frame in [early, middle] else 1
				_app._memory.card_buttons[_pairs[pair_index][side]].pressed.emit()
				_actions.append({"frame": frame, "action": "memory_card", "index": _pairs[pair_index][side]})
			if frame == int(_sample_count * 0.75):
				_app._memory.study_button.button_down.emit()
			if frame == int(_sample_count * 0.88):
				_app._memory.study_button.button_up.emit()
		"voice-pop":
			if frame in [early, middle, int(_sample_count * 0.84)] and not _app._pop.game.targets.is_empty():
				var word: String = str(_app._pop.game.targets[0].word.text)
				_app._pop.show_transcript(word, true)
				_app._pop.receive_transcript(word)
				_actions.append({"frame": frame, "action": "pop_word", "word": word})
		"growth":
			if frame in [early, middle]:
				var age: String = "4" if frame == early else "3"
				_app._age_buttons[age].pressed.emit()
				_actions.append({"frame": frame, "action": "browse_age", "age": int(age)})
			if frame == int(_sample_count * 0.84):
				var button: Button = _app._age_catalog.word_buttons[0]
				button.pressed.emit()
				_actions.append({"frame": frame, "action": "growth_word", "word_id": str(button.get_meta("word_id"))})
		"catalog":
			if frame in [early, middle, int(_sample_count * 0.84)]:
				var index: int = 0 if frame == early else _catalog_word_ids.size() / 2 if frame == middle else _catalog_word_ids.size() - 1
				var id: String = _catalog_word_ids[index]
				if not _require(_app._age_catalog.focus_word(id), "Catalogue word must be reachable across pages: " + id):
					return
				var button := _app.get_viewport().gui_get_focus_owner() as Button
				if not _require(button != null and str(button.get_meta("word_id", "")) == id,
					"Catalogue focus must reach the requested word: " + id):
					return
				button.pressed.emit()
				_actions.append({"frame": frame, "action": "catalog_word", "index": index,
					"word_id": id, "page": _app._age_catalog._page_index + 1})


func _state() -> Dictionary:
	match _scenario:
		"match": return {"visible": _visible_control(_app.grid), "phase": _app.model.phase, "cards": _app.cards.size(), "matched_cards": _app.model.matched_ids.size()}
		"memory": return {"visible": _visible_control(_app._memory), "phase": _app._memory.memory.phase, "cards": _app._memory.card_buttons.size(), "matches": _app._memory.memory.matched_word_ids.size()}
		"voice-pop": return {"visible": _visible_control(_app._pop), "hud_visible": _visible_control(_app._pop._hud), "phase": _app._pop.game.phase, "elapsed": _app._pop.game.elapsed, "targets": _app._pop.game.targets.size(), "draw_targets": _app._pop._draw_targets.size(), "hits": _app._pop.game.hits}
		"growth": return {"visible": _visible_control(_app.collection_page), "catalog_visible": _visible_control(_app._age_catalog),
			"age": _app._catalog_age, "level": _app.growth.level, "word_count": _app._age_catalog.word_count(),
			"summary": _app._growth_summary.text, "progress_unchanged": _app.growth.snapshot() == _growth_before}
		"catalog":
			var catalog: Dictionary = _app._age_catalog.snapshot()
			var pictured_paths: Dictionary = {}
			for button: Button in _app._age_catalog.word_buttons:
				var source: String = str(button.get_meta("word").get("image", ""))
				if not source.is_empty():
					pictured_paths[source] = true
			return {"visible": _visible_control(_app._age_catalog), "word_count": catalog.word_count,
				"age": _app._catalog_age, "expected_textures": pictured_paths.size(),
				"page": catalog.page, "page_count": catalog.page_count, "page_size": _app._age_catalog.PAGE_SIZE,
				"cards": _app._age_catalog.word_buttons.size(), "textures": _app._age_catalog._textures.size(),
				"scroll": catalog.scroll_offset, "progress_unchanged": _app.growth.snapshot() == _growth_before}
		"chest": return {"visible": _visible_control(_app.chest), "phase": _app.model.phase, "chest_state": _app.model.chest_state, "cues": _chest_cues.duplicate()}
	return {}


func _visible_control(control: Control) -> bool:
	return control.is_visible_in_tree() and control.size.x > 0 and control.size.y > 0


func _assert_workload(after: bool) -> bool:
	var state: Dictionary = _state()
	if not _require(bool(state.get("visible", false)), "Workload must remain visible with nonzero layout: " + _scenario):
		return false
	if not _require(not _app.reduced_motion and not _app._page_hidden and not _app._mode_menu_open(), "Scene must retain normal motion and active input"):
		return false
	var valid := false
	match _scenario:
		"match": valid = state.cards == 10 and state.phase in ["waiting", "matching", "feedback"] and (not after or state.matched_cards >= 4)
		"memory": valid = state.cards == 10 and state.phase in ["waiting", "matching", "feedback"] and (not after or state.matches >= 2)
		"voice-pop": valid = state.hud_visible and state.phase == "running" and state.elapsed > 0 and ((state.targets > 0 and state.draw_targets > 0) if not after else (state.hits == 3 and _target_workload_recorded()))
		"growth": valid = state.catalog_visible and state.age == 3 and state.level == 0 and state.word_count == 80 \
			and state.summary.begins_with("1 new word to Lv1") and state.progress_unchanged \
			and (not after or (_actions.size() == 3 and _actions[0].action == "browse_age" and _actions[0].age == 4 \
				and _actions[1].action == "browse_age" and _actions[1].age == 3 and _actions[2].action == "growth_word"))
		"catalog":
			var expected_cards: int = mini(state.page_size, state.word_count - (state.page - 1) * state.page_size)
			valid = state.age == 7 and state.word_count == 284 and _catalog_word_ids.size() == state.word_count \
				and state.page_size == 60 and state.page_count == 5 and state.page >= 1 and state.page <= state.page_count \
				and state.cards == expected_cards and state.cards > 0 and state.cards <= state.page_size \
				and state.textures == state.expected_textures and state.progress_unchanged \
				and ((state.page == 1) if not after else (state.page == state.page_count and state.scroll > 0 \
					and _catalog_card_peak > 0 and _catalog_card_peak <= state.page_size \
					and _catalog_texture_peak > 0 and _catalog_texture_peak <= state.page_size and _catalog_inputs_recorded()))
		"chest": valid = state.phase == "won" and ((state.chest_state in ["closed", "opening"] and "release" not in state.cues) if not after else (state.chest_state in ["opening", "opened"] and "release" in state.cues))
	return _require(valid, "Inactive or incorrect workload for %s: %s" % [_scenario, JSON.stringify(state)])


func _catalog_inputs_recorded() -> bool:
	var selected: Array[Dictionary] = _actions.filter(func(action: Dictionary) -> bool: return action.action == "catalog_word")
	var indices: Array[int] = [0, _catalog_word_ids.size() / 2, _catalog_word_ids.size() - 1]
	if selected.size() != indices.size():
		return false
	for index in range(indices.size()):
		var expected_index: int = indices[index]
		var expected_page: int = expected_index / _app._age_catalog.PAGE_SIZE + 1
		if selected[index].index != expected_index or selected[index].word_id != _catalog_word_ids[expected_index] \
			or selected[index].page != expected_page:
			return false
	return true


func _target_workload_recorded() -> bool:
	# At least one quarter of the measured frames must contain real live and
	# prepared, visible target artwork, with one count aligned to every sample.
	var required_frames: int = ceili(_sample_count * 0.25)
	return _target_counts.size() == _sample_count and _drawn_target_counts.size() == _sample_count \
		and _target_frame_count >= required_frames and _drawn_target_frame_count >= required_frames \
		and _target_peak > 0 and _drawn_target_peak > 0


func _statistics(values: Array[int]) -> Dictionary:
	if values.is_empty():
		return {}
	var ordered: Array[int] = values.duplicate()
	ordered.sort()
	var total: float = 0.0
	for value in values:
		total += value
	return {"count": values.size(), "mean": total / values.size(), "p50": ordered[ceili(ordered.size() * 0.50) - 1],
		"p95": ordered[ceili(ordered.size() * 0.95) - 1], "min": ordered[0], "max": ordered[-1]}


func _clean_save_directory() -> void:
	# Only remove the files from this run's flat, isolated directory.
	if _directory.is_empty() or not DirAccess.dir_exists_absolute(_directory):
		return
	for filename: String in DirAccess.get_files_at(_directory):
		DirAccess.remove_absolute(_directory.path_join(filename))
	DirAccess.remove_absolute(_directory)


func _shutdown(exit_code: int) -> void:
	_sampling = false
	_pending_draw = false
	if RenderingServer.frame_post_draw.is_connected(_after_draw):
		RenderingServer.frame_post_draw.disconnect(_after_draw)
	# Deferred shutdown avoids freeing a scene during its process traversal.
	if is_instance_valid(_app):
		_app.free()
	_app = null
	for child: Node in root.get_children():
		if child is FrameStart or child is FrameEnd:
			child.bench = null
			child.free()
	await process_frame
	_clean_save_directory()
	_directory = ""
	quit(exit_code)
