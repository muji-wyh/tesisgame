extends SceneTree

const Fixture = preload("res://tests/performance/jelly_drag_fixture.gd")
const Data = preload("res://scripts/game_data.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")

class ObservedJelly extends "res://scripts/word_jelly.gd":
	var position_passes: int = 0
	var publications: int = 0
	var merge_checks: int = 0
	var drop_checks: int = 0
	var outline_bounds_checks: int = 0
	func _sync_positions() -> void:
		position_passes += 1
		super._sync_positions()
	func snapshot() -> Dictionary:
		publications += 1
		return super.snapshot()
	func _can_merge_for_feedback(a: Dictionary, b: Dictionary) -> bool:
		if not _view_update_active or not _view_mergeable.has(Vector2i(int(a.get("id", -1)), int(b.get("id", -1)))):
			merge_checks += 1
		return super._can_merge_for_feedback(a, b)
	func _can_drop_preview() -> bool:
		if not _view_update_active or not _view_drop_known:
			drop_checks += 1
		return super._can_drop_preview()
	func _outline_bounds(outline: PackedVector2Array) -> Rect2:
		outline_bounds_checks += 1
		return super._outline_bounds(outline)

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _check_clock_publication(data) -> void:
	var words: Array = data.words.filter(func(word: Dictionary) -> bool: return Data.word_age(word) == 3) \
		.map(func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	var plan: Dictionary = Catalog.make_plan(1, words, 3, 73021)
	var view := ObservedJelly.new()
	root.add_child(view)
	view.size = Vector2(390, 844)
	check(plan.ok and view.configure(plan.words, 3, Data.theme("spring"), data.chests, false, 73021)
		and view.game.bind_stage(plan),
		"The timer diagnostic uses an actual campaign with reviewed word goals")
	view.set_process(false)
	if view.game.stage_run == null:
		view.free()
		return
	var state: Dictionary = view.game.stage_run.snapshot()
	view.set_stage_progress(state)
	view.publications = 0
	for frame in range(60):
		state = state.duplicate(true)
		state.time_elapsed = float(frame + 1) / 60.0
		state.seconds_remaining = state.seconds_total - state.time_elapsed
		view.set_stage_progress(state)
	check(view.publications == 0 and view._stage_banner._state.seconds_remaining == state.seconds_remaining,
		"Clock-only updates retain native timer feedback without duplicating whole-board host snapshots")
	state.practice[0].current += 1
	state.practice[0].mastered = true
	view.set_stage_progress(state)
	check(view.publications > 0 and view._practice_panel._state.practice[0].mastered,
		"Actual word progress still updates its goal and immediately publishes the meaningful change")
	view.publications = 0
	state.stars_now = 2
	view.set_stage_progress(state)
	check(view.publications > 0, "Crossing a timed star boundary immediately publishes its semantic change")
	view.publications = 0
	view.set_stage_progress(state, true)
	check(view.publications > 0, "An explicit stage celebration is never hidden by the clock-only fast path")
	for frame in range(40):
		view._process(0.05)
	check(view._can_play() and view.powerup_buttons.values().all(
		func(button: Button) -> bool: return not button.snapshot().paused),
		"Ready-to-play resumes tool feedback and hover without needing a manual pause/resume workaround")
	view.pause(true)
	view.publications = 0
	state.seconds_remaining -= 0.1
	view.set_stage_progress(state)
	check(view.publications > 0, "A paused timer update still publishes without relying on the playing-frame clock")
	view.free()

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(390, 844)
	var data := Data.new()
	check(data.load_all(), "Production word and artwork data load")
	_check_clock_publication(data)
	var view := ObservedJelly.new()
	root.add_child(view)
	view.size = Vector2(390, 844)
	for count: int in [Model.INITIAL_SETTLED_TILES, Model.CAPACITY - Model.COLUMNS]:
		var pair: Array[int] = Fixture.install(view, data, count)
		var start: Vector2 = view._tiles[pair[0]].get_global_rect().get_center()
		check(view._press(7, start), "Touch can pick up a settled jelly")
		view.position_passes = 0
		view.publications = 0
		var destination: Vector2 = Fixture.point(view, pair, 0, 0, 1, false)
		for index in range(20):
			Fixture.motion(view, start.lerp(destination, float(index + 1) / 20.0))
		check(view._dragging, "The first threshold crossing lifts the jelly immediately")
		check(view.position_passes == 0 and view.publications == 0, "Touch bursts do not rebuild or serialize the board")
		view.merge_checks = 0
		view.drop_checks = 0
		view.outline_bounds_checks = 0
		view._process(1.0 / 60.0)
		check(view.position_passes == 1, "One presentation pass consumes all pending motion")
		check(view.merge_checks <= count, "Each partner is checked at most once in the presentation pass")
		check(view.drop_checks == 1, "Preview slots share one return-space calculation")
		check(view.outline_bounds_checks <= 8,
			"Empty-space dragging rejects distant bodies before allocating or scanning their authored contours")
		check(view._tiles[pair[0]].position.is_equal_approx(view.get_global_transform().affine_inverse() * destination - view._drag_offset), "The frame uses the latest touch position")
		check(not view._view_update_active, "No cached model decisions survive the frame")
		var target: Vector2 = view._tiles[pair[1]].get_global_rect().get_center()
		Fixture.motion(view, destination + Vector2(4, 4))
		view._release(target)
		check(view.game.fusions.size() == 1 and str(view.game.fusions[0].operation) == "merge", "Release before another frame uses the pointer-up position instead of the buffered position")
		check(view._pointer == view.NO_POINTER and not view._motion_pending, "Release clears pending input ownership")

		pair = Fixture.install(view, data, count)
		start = view._tiles[pair[0]].get_global_rect().get_center()
		view._press(7, start)
		Fixture.motion(view, start + Vector2(30, 0))
		Fixture.motion(view, start)
		check(view._dragging, "Returning within the same frame does not turn a drag into a tap")
		view.cancel_input()
		view._process(1.0 / 60.0)
		check(not view._dragging and not view._motion_pending and view.game.fusions.is_empty(), "Cancellation discards the buffered motion without collecting or merging")

	for cancellation: String in ["touch", "pause", "resize"]:
		view.size = Vector2(390, 844)
		var pair: Array[int] = Fixture.install(view, data, Model.INITIAL_SETTLED_TILES)
		var start: Vector2 = view._tiles[pair[0]].get_global_rect().get_center()
		view._press(7, start)
		Fixture.motion(view, start + Vector2(30, 0))
		Fixture.motion(view, start + Vector2(60, 0))
		check(view._motion_pending, cancellation + ": motion is buffered before cancellation")
		match cancellation:
			"touch":
				var event := InputEventScreenTouch.new()
				event.index = 7
				event.canceled = true
				view._input(event)
			"pause":
				view.pause(true)
				view.pause(false)
			"resize":
				view.size = Vector2(414, 896)
				view._layout()
		view._process(1.0 / 60.0)
		check(view._pointer == view.NO_POINTER and not view._motion_pending and not view._dragging, cancellation + ": pending input cannot replay on the next frame")
		check(view.game.fusions.is_empty() and view.game.cells.size() == Model.INITIAL_SETTLED_TILES and view.game._dragged_tile_id == -1, cancellation + ": cancellation neither merges nor collects and releases the held body")

	var pair: Array[int] = Fixture.install(view, data, Model.INITIAL_SETTLED_TILES)
	view._begin_view_update()
	check(view._can_drop_preview(), "The initial presentation pass has room for a preview")
	check(view._can_merge_for_feedback(view._cell(pair[0]), view._cell(pair[1])), "The initial presentation pass finds the valid word-picture pair")
	view._end_view_update()
	var replacement: Dictionary = view.game.cell(pair[1]).duplicate(true)
	replacement.falling = true
	replacement.image_word.id = "different-word"
	for index in range(view.game.cells.size()):
		if int(view.game.cells[index].id) == pair[1]:
			view.game.cells[index] = replacement
	view.game.paused = true
	view._begin_view_update()
	check(bool(view._cell(pair[1]).falling), "The next pass rebuilds the ID lookup after model replacement")
	check(not view._can_drop_preview(), "The next pass recomputes drop availability after pausing")
	check(not view._can_merge_for_feedback(view._cell(pair[0]), view._cell(pair[1])), "The next pass rejects a partner whose model state changed")
	view._end_view_update()
	view.snapshot()
	check(not view._preview_drop_available, "Publishing before a presentation pass refreshes preview availability")

	view.free()
	await process_frame
	print("Word Jelly drag performance: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
