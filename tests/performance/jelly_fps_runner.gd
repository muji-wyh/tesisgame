extends Node
## Optional benchmark autoload in an isolated export, never in the production project.
## frame_post_draw measures submission completion, not a GPU fence or presentation.

const Fixture = preload("res://tests/performance/jelly_full_board_fixture.gd")
const PROTOCOL := "jelly-full-board-rendered-v2"
const SCENARIOS := ["idle-ordinary", "idle-merged", "drag-ordinary", "drag-merged", "merge", "collect"]

class FrameStart extends Node:
	var bench
	func _process(delta: float) -> void:
		bench._begin_frame(delta)

class FrameEnd extends Node:
	var bench
	func _process(_delta: float) -> void:
		bench._end_process()

var _bridge: JavaScriptObject
var _start_callback: JavaScriptObject
var _app
var _view
var _busy := false
var _sampling := false
var _pending := false
var _request: Dictionary = {}
var _pair: Array[int] = []
var _started_usec: int
var _frame_begin_usec: int
var _process_usec: int
var _previous_begin_usec: int
var _process_samples: Array[int] = []
var _submission_samples: Array[int] = []
var _interval_samples: Array[int] = []
var _tile_counts: Array[int] = []
var _fusion_active: Array[bool] = []
var _sample_elapsed: Array[float] = []
var _fx_counts: Array[int] = []
var _visible_fx_counts: Array[int] = []
var _batch_active: Array[bool] = []
var _batch_total: Array[int] = []
var _batch_cursor: Array[int] = []
var _batch_started: Array[int] = []
var _batch_completed: Array[int] = []
var _batch_skipped: Array[int] = []
var _batch_remaining: Array[int] = []
var _drag_frames := 0
var _fusion_frames := 0
var _collection_frames := 0
var _actions: Array[Dictionary] = []
var _before: Dictionary = {}
var _duration: float
var _warmup: float
var _collect_started := false
var _merge_started := false
var _merge_released := false
var _drag_pressed := false
var _merge_release_at := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var first := FrameStart.new()
	first.bench = self
	first.process_priority = -1000000
	add_child(first)
	var last := FrameEnd.new()
	last.bench = self
	last.process_priority = 1000000
	add_child(last)
	RenderingServer.frame_post_draw.connect(_after_draw)
	if OS.has_feature("web"):
		_bridge = JavaScriptBridge.get_interface("jellyFpsBench")
		if _bridge != null:
			_start_callback = JavaScriptBridge.create_callback(_receive_start)
			_bridge.install(_start_callback)

func _receive_start(arguments: Array) -> void:
	if _busy:
		_fail("A benchmark is already running.")
		return
	if arguments.size() != 1 or not arguments[0] is String:
		_fail("start requires one JSON request.")
		return
	var value: Variant = JSON.parse_string(arguments[0])
	if not value is Dictionary or value.get("scenario", "") not in SCENARIOS:
		_fail("Unknown benchmark scenario.")
		return
	_request = value
	_duration = clampf(float(value.get("seconds", 8.0)), 2.0, 60.0)
	if str(value.scenario) == "collect":
		_duration = maxf(12.0, _duration)
	_warmup = clampf(float(value.get("warmup_seconds", 2.0)), 1.0, 10.0)
	_busy = true
	_run.call_deferred()

func _run() -> void:
	_app = get_tree().current_scene
	if _app == null or _app.get("_vocabulary_initialized") != true or get_tree().paused:
		_fail("Enter the game and complete vocabulary boot before starting.")
		return
	if not _app.vocabulary_loader.is_ready(_app.growth.learning_age()):
		_app.vocabulary_loader.request_age(_app.growth.learning_age())
		var deadline: int = Time.get_ticks_msec() + 60000
		while not _app.vocabulary_loader.is_ready(_app.growth.learning_age()):
			await get_tree().process_frame
			if Time.get_ticks_msec() > deadline:
				_fail("Vocabulary was not ready within sixty seconds.")
				return
	_app._has_entered_game = true
	if not _app.new_round(int(_request.get("seed", 73021)), false, "", "word_jelly", "", false):
		_fail("Could not start the real game page.")
		return
	_app.set_reduced_motion(false)
	_app.audio.set_muted(false)
	_view = _app._word_jelly
	if not _app.coin_wallet.ready or not _app.coin_wallet.error.is_empty() or not _app.growth.ready or not _app.growth.error.is_empty():
		_fail("Benchmark storage must be ready: wallet=%s; growth=%s" % [_app.coin_wallet.error, _app.growth.error])
		return
	var composition: String = "merged" if str(_request.scenario) in ["idle-merged", "drag-merged", "collect"] else "ordinary"
	if str(_request.scenario) == "collect":
		composition = "mixed-merged"
	_pair = Fixture.install(_app, composition, int(_request.get("seed", 73021)))
	if _pair.size() != 2:
		_fail("The full-board production fixture failed validation or initialization.")
		return
	if str(_request.scenario) == "collect" and _view.game.pip_level < 3:
		_fail("Seed an earned Pip Lv3 before the Auto Collect benchmark.")
		return
	_collect_started = false
	_merge_started = false
	_merge_released = false
	_drag_pressed = false
	var warmup_end: int = Time.get_ticks_usec() + int(_warmup * 1000000.0)
	while Time.get_ticks_usec() < warmup_end:
		await RenderingServer.frame_post_draw
	if not _valid_workload():
		_fail("Full board was not visible, active and unpaused after warmup.")
		return
	_before = _boundary_state()
	_process_samples.clear()
	_submission_samples.clear()
	_interval_samples.clear()
	_tile_counts.clear()
	_fusion_active.clear()
	_sample_elapsed.clear()
	_fx_counts.clear()
	_visible_fx_counts.clear()
	_batch_active.clear()
	_batch_total.clear()
	_batch_cursor.clear()
	_batch_started.clear()
	_batch_completed.clear()
	_batch_skipped.clear()
	_batch_remaining.clear()
	_actions.clear()
	_drag_frames = 0
	_fusion_frames = 0
	_collection_frames = 0
	_previous_begin_usec = 0
	_pending = false
	_started_usec = Time.get_ticks_usec()
	_sampling = true
	_bridge.begin(JSON.stringify({"scenario": _request.scenario, "seconds": _duration, "before": _before}))

func _begin_frame(_delta: float) -> void:
	# Only the fixture's failure deadline is extended. Every gameplay, animation,
	# publication, audio, spawn and physics clock continues at its normal speed.
	if _busy and is_instance_valid(_view):
		_view.game._full_warning_limit = 3600.0
	if not _sampling:
		return
	var now: int = Time.get_ticks_usec()
	if _pending:
		_fail("A process frame had no corresponding frame_post_draw.")
		return
	_frame_begin_usec = now
	if _previous_begin_usec > 0:
		_interval_samples.append(now - _previous_begin_usec)
	_previous_begin_usec = now
	_pending = true
	_scheduled_input(float(now - _started_usec) / 1000000.0)

func _end_process() -> void:
	if _sampling and _pending:
		_process_usec = Time.get_ticks_usec() - _frame_begin_usec

func _after_draw() -> void:
	var now: int = Time.get_ticks_usec()
	if not _sampling or not _pending:
		return
	_process_samples.append(_process_usec)
	_submission_samples.append(now - _frame_begin_usec)
	_tile_counts.append(_view.game.cells.size())
	var has_fusion: bool = not _view.game.fusions.is_empty()
	_fusion_active.append(has_fusion)
	_sample_elapsed.append(float(now - _started_usec) / 1000000.0)
	_fx_counts.append(_view._collection_effects._entries.size())
	var visible_fx: int = 0
	for entry: Dictionary in _view._collection_effects._entries:
		visible_fx += 1 if float(entry.elapsed) >= float(entry.delay) else 0
	_visible_fx_counts.append(visible_fx)
	_batch_active.append(_view.game._collection_batch_active)
	_batch_total.append(_view.game._collection_batch_ids.size())
	_batch_cursor.append(_view.game._collection_batch_cursor)
	_batch_started.append(_view.game._collection_batch_started)
	_batch_completed.append(_view.game._collection_batch_completed)
	_batch_skipped.append(_view.game._collection_batch_skipped)
	_batch_remaining.append(_view.game._collection_batch_ids.size() - _view.game._collection_batch_cursor \
		+ (1 if not _view.game._collection_batch_event_id.is_empty() else 0) if _view.game.collection_batch_active() else 0)
	_drag_frames += 1 if _view._dragging else 0
	_fusion_frames += 1 if has_fusion else 0
	_collection_frames += 1 if _view.game.collection_batch_active() or not _view._collection_effects._entries.is_empty() else 0
	_pending = false
	if float(now - _started_usec) / 1000000.0 >= _duration:
		# Extend measurement, never simulation, if an unusually slow renderer has
		# not completed all captured pickups by the requested twelve-second window.
		if str(_request.scenario) == "collect" and _view.game._collection_batch_completed < 56 \
			and float(now - _started_usec) / 1000000.0 < maxf(_duration, 20.0):
			return
		_sampling = false
		_finish.call_deferred()

func _scheduled_input(elapsed: float) -> void:
	var scenario: String = str(_request.scenario)
	if (scenario.begins_with("drag-") or scenario == "merge") and _request.get("input", "scene") == "cdp":
		return
	if scenario.begins_with("drag-"):
		if not _drag_pressed:
			Fixture.pointer(_view, "press", _view._tiles[_pair[0]].get_global_rect().get_center())
			_drag_pressed = true
			_actions.append({"seconds": elapsed, "action": "press_drag", "id": _pair[0]})
		var local: Vector2 = _view._board.position + Vector2(_view._pitch * (3.0 + sin(elapsed * 2.0) * 2.0), _view._pitch * 0.35)
		Fixture.pointer(_view, "move", _view.get_global_transform() * local)
	elif scenario == "merge":
		if not _merge_started and elapsed >= 0.5:
			Fixture.pointer(_view, "press", _view._tiles[_pair[0]].get_global_rect().get_center())
			Fixture.pointer(_view, "move", _view._tiles[_pair[1]].get_global_rect().get_center())
			_merge_started = true
			_merge_release_at = elapsed + 0.15
			_actions.append({"seconds": elapsed, "action": "drag_match", "pair": _pair.duplicate()})
		elif _merge_started and not _merge_released and elapsed >= _merge_release_at:
			Fixture.pointer(_view, "release", _view._tiles[_pair[1]].get_global_rect().get_center())
			_merge_released = true
	elif scenario == "collect" and not _collect_started and elapsed >= 0.5:
		_view.collect_button.pressed.emit()
		_collect_started = true
		_actions.append({"seconds": elapsed, "action": "auto_collect"})

func _valid_workload() -> bool:
	return is_instance_valid(_view) and _view.is_visible_in_tree() and _view.game.cells.size() == 56 \
		and _view.game.phase == "playing" and not _view.game.paused and not get_tree().paused \
		and not _app.reduced_motion and not _app.audio.muted and not _app._mode_menu_open() \
		and not _app._page_hidden and not _app._campaign.is_open() \
		and _app.coin_wallet.ready and _app.coin_wallet.error.is_empty() and _app.growth.ready and _app.growth.error.is_empty()

func _boundary_state() -> Dictionary:
	var source: Rect2 = _view._tiles[_pair[0]].get_global_rect() if _view._tiles.has(_pair[0]) else Rect2()
	var target: Rect2 = _view._tiles[_pair[1]].get_global_rect() if _view._tiles.has(_pair[1]) else Rect2()
	var words: Dictionary = {}
	var levels: Dictionary = {}
	for tile: Dictionary in _view.game.cells:
		var word_id: String = str(tile.get("word", {}).get("id", tile.get("word_candidate", {}).get("id", "")))
		if not word_id.is_empty():
			words[word_id] = int(words.get(word_id, 0)) + 1
		var level: String = str(tile.get("merge_level", 0))
		levels[level] = int(levels.get(level, 0)) + 1
	return {"tiles": _view.game.cells.size(), "phase": _view.game.phase, "paused": _view.game.paused,
		"error": _view.game.error,
		"wallet": {"ready": _app.coin_wallet.ready, "error": _app.coin_wallet.error,
			"balance": _app.coin_wallet.balance, "receipts": _app.coin_wallet._receipts.size()},
		"learning": {"ready": _app.growth.ready, "error": _app.growth.error,
			"pending": _app.growth._pending.size(), "save_failed": _app._growth_save_failed,
			"age": _app.growth.learning_age()},
		"cohort_word_ids": _view.game._words_by_id.keys(), "authored_morphology": _view.game.authored_morphology,
		"journal_errors": {"campaign": _app._campaign.error, "campaign_store": _app._campaign.store.error,
			"rewards": _app._jelly_rewards.rewards.error, "reward_settlement": _app._jelly_rewards._settlement_error,
			"medals": _app.medal_progress.error},
		"elapsed": _view.game.full_elapsed, "merged": _view.game.merged_count,
		"cleared_pairs": _view.game.cleared_pairs, "collected_coins": _view.game.collected_coins,
		"window": [get_window().size.x, get_window().size.y],
		"source_rect": [source.position.x, source.position.y, source.size.x, source.size.y],
		"target_rect": [target.position.x, target.position.y, target.size.x, target.size.y],
		"word_counts": words, "level_counts": levels, "collection_batch": _view.game.collection_batch_snapshot(),
		"logical_board": [_view._board.position.x, _view._board.position.y, _view._board.size.x, _view._board.size.y],
		"logical_view_origin": [_view.global_position.x, _view.global_position.y], "pitch": _view._pitch,
		"presentation_work": _view.presentation_work_snapshot()}

func _finish() -> void:
	var report := {"protocol": PROTOCOL, "scenario": _request.scenario,
		"seed": int(_request.get("seed", 73021)), "warmup_seconds": _warmup, "seconds": _duration,
		"engine": Engine.get_version_info(), "before": _before, "after": _boundary_state(),
		"process_us": _process_samples, "submission_us": _submission_samples,
		"frame_interval_us": _interval_samples, "tile_counts": _tile_counts,
		"fusion_active": _fusion_active,
		"sample_elapsed_seconds": _sample_elapsed, "collection_effect_entries": _fx_counts,
		"visible_collection_effect_entries": _visible_fx_counts,
		"batch_progress": {"active": _batch_active, "total": _batch_total, "cursor": _batch_cursor,
			"started": _batch_started, "completed": _batch_completed, "skipped": _batch_skipped,
			"remaining": _batch_remaining},
		"process_frames": _process_samples.size(), "frame_post_draw_frames": _submission_samples.size(),
		"drag_frames": _drag_frames, "fusion_frames": _fusion_frames, "collection_frames": _collection_frames,
		"actions": _actions, "rendering_method": RenderingServer.get_current_rendering_method(),
		"input": str(_request.get("input", "scene")),
		"adapter": RenderingServer.get_video_adapter_name(), "audio_muted": _app.audio.muted,
		"scope": "Real game page and host bridge with normal clocks and audio. Synthetic mouse events enter real scene handlers. frame_post_draw is submission completion, not GPU time or physical input latency. Only the full-board failure deadline is extended in this benchmark fixture."}
	_view.cancel_input()
	_busy = false
	_bridge.finish(JSON.stringify(report))

func _fail(message: String) -> void:
	_sampling = false
	_pending = false
	_busy = false
	printerr("JELLY FPS BENCHMARK FAILED: " + message)
	if _bridge != null:
		_bridge.fail(message)
