extends SceneTree
## Preview reuse must agree with fresh model decisions at every state boundary.

const Data = preload("res://scripts/game_data.gd")
const Fixture = preload("res://tests/performance/jelly_authored_drag_fixture.gd")

class CountedModel extends "res://scripts/word_jelly_model.gd":
	var drop_queries: int = 0
	var placement_queries: int = 0
	func can_drop_now() -> bool:
		drop_queries += 1
		return super.can_drop_now()
	func can_reposition(id: int, column: int, row: int) -> bool:
		placement_queries += 1
		return super.can_reposition(id, column, row)
	func fresh_drop() -> bool:
		return super.can_drop_now()
	func fresh_placement(id: int, column: int, row: int) -> bool:
		return super.can_reposition(id, column, row)

class CountedView extends "res://scripts/word_jelly.gd":
	func _init() -> void:
		super()
		var original = game
		game = CountedModel.new()
		game.finish_feedback_ready = _finish_feedback_ready
		# Preserve the real view callbacks while observing only model queries.
		for descriptor: Dictionary in original.get_signal_list():
			for connection: Dictionary in original.get_signal_connection_list(descriptor.name):
				game.connect(descriptor.name, connection.callable, int(connection.flags))
		_palette.compatibility = game.parts_compatible

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _check_preview_boundaries(view, pair: Array[int], label: String) -> void:
	var source: int = pair[0]
	var from: Vector2 = view._board.position + Vector2.ONE * view._gap * 0.5 + Vector2(6, 0) * view._pitch
	var pointer: Vector2 = from + Vector2.ONE * view._pitch * 0.5
	view._placement_cache_key.clear()
	view._drop_cache_key.clear()
	view.game.placement_queries = 0
	view.game.drop_queries = 0
	for frame in range(12):
		view.game.step(1.0 / 60.0)
		view._begin_view_update()
		for request in range(4):
			var placement: Dictionary = view._placement_at(source, from, pointer)
			check(bool(placement.valid) == view.game.fresh_placement(source, 6, 0), label + ": repeated placement matches a fresh decision")
			check(view._can_drop_preview() == view.game.fresh_drop(), label + ": repeated tray availability matches a fresh decision")
		view._end_view_update()
	check(view.game.placement_queries == 1, label + ": stable rounded placement queries occupancy once across steps")
	check(view.game.drop_queries == 1, label + ": settled return geometry queries tray occupancy once across steps")
	check(view._ambient_budget._priority_depth == 0, label + ": every presentation pass closes its scheduler batch")

	var blocker: Dictionary = view.game.cells[0]
	var previous: Vector2i = Vector2i(int(blocker.column), int(blocker.row))
	blocker.column = 6
	blocker.row = 0
	view._begin_view_update()
	check(not bool(view._placement_at(source, from, pointer).valid), label + ": a new occupant invalidates the formerly free destination")
	view._end_view_update()
	blocker.column = previous.x
	blocker.row = previous.y
	view.game.paused = true
	view._begin_view_update()
	check(not bool(view._placement_at(source, from, pointer).valid) and not view._can_drop_preview(), label + ": pause invalidates both preview decisions")
	view._end_view_update()
	view.game.paused = false
	view._begin_view_update()
	check(bool(view._placement_at(source, from, pointer).valid) and view._can_drop_preview(), label + ": unpausing restores fresh preview decisions")
	var before_release: int = view.game.placement_queries
	view._placement_at(source, from, pointer, true)
	check(view.game.placement_queries == before_release + 1, label + ": pointer-up bypasses a valid preview cache")
	view._end_view_update()

	view.game._drag_gravity_delays[int(blocker.id)] = 0.1
	var before_delay: int = view.game.drop_queries
	for pass_index in range(2):
		view._begin_view_update()
		check(view._can_drop_preview() == view.game.fresh_drop(), label + ": a pending fall keeps return-space decisions fresh")
		view._end_view_update()
	check(view.game.drop_queries == before_delay + 2 and view._drop_cache_key.is_empty(), label + ": delayed gravity cannot reuse a prior tray result")
	view.game._drag_gravity_delays.clear()
	blocker.age = 0.0
	blocker.falling = true
	view._begin_view_update()
	check(not view._view_geometry_stable and view._can_drop_preview() == view.game.fresh_drop(), label + ": an airborne body disables cross-step tray reuse")
	view._end_view_update()
	blocker.age = 2.0
	blocker.falling = false

	# Reserve a real authored fusion, then move its future result footprint.
	check(view.game.try_merge(int(view.game.cells[0].id), int(view.game.cells[1].id)) == "merged", label + ": an independent real fusion starts")
	var fusion: Dictionary = view.game.fusions[0]
	fusion.result.column = 6
	fusion.result.row = 0
	var before_fusion: int = view.game.drop_queries
	view._begin_view_update()
	check(not bool(view._placement_at(source, from, pointer).valid), label + ": a future fusion footprint invalidates placement")
	check(not view._view_geometry_stable and view._can_drop_preview() == view.game.fresh_drop(), label + ": fusion keeps tray occupancy fresh")
	view._end_view_update()
	view._begin_view_update()
	view._can_drop_preview()
	view._end_view_update()
	check(view.game.drop_queries == before_fusion + 2, label + ": an active fusion never reuses settled tray availability")
	# This diagnostic does not commit a merge or change its fixture membership.
	view.game.fusions.clear()

func _check_hint_budget(view, pair: Array[int], source_kind: String) -> void:
	view._sync_positions()
	var expected: int = Fixture.expected_hint_count(49, source_kind)
	check(view._hint_matching_ids.size() == expected, source_kind + ": every correct crowded target retains its semantic cue")
	check(view._hint_animated_ids.size() == 3 and view._hint_live_ids.size() == 3, source_kind + ": decorative matching motion is bounded to three targets")
	var fixed: Array[int] = view._hint_animated_ids.duplicate()
	var remote: int = -1
	for id: int in view._hint_matching_ids:
		var tile = view._tiles[id]
		check(tile.completion_hint and not tile.match_dimmed, source_kind + ": every valid partner remains clearly marked")
		if id not in fixed:
			remote = id
			check(not tile._completion_animated, source_kind + ": distant partners keep a static completion cue")
	check(remote >= 0 and view._active_tile_ids.size() <= 4, source_kind + ": static matching bodies do not enter the active pose set")
	var tile = view._tiles[remote]
	var before_pose: Array = view._hint_pose_key.duplicate(true)
	view._refresh_completion_hints()
	check(view._hint_pose_key == before_pose, source_kind + ": repeated same-clock hint refresh performs no second pose pass")
	view._set_ambient_hover(remote)
	view._refresh_completion_hints()
	check(tile._completion_animated and view._hint_live_ids.size() == 4, source_kind + ": hovering a static target wakes its cue immediately")
	view._set_ambient_hover(-1)
	view._refresh_completion_hints()
	check(not tile._completion_animated and view._hint_live_ids.size() == 3, source_kind + ": hover release returns to the bounded cohort")
	tile.grab_focus()
	view._refresh_completion_hints()
	check(tile._completion_animated, source_kind + ": native keyboard focus wakes a static target immediately")
	tile.release_focus()
	view._refresh_completion_hints()
	check(not tile._completion_animated and view._hint_animated_ids == fixed, source_kind + ": focus and pointer feedback never rotate the gesture cohort")
	var empty: Array[int] = []
	view._set_completion_ids(empty, pair[0], 0.0)
	var before_membership: int = view._ambient_budget._refreshes
	var ids: Array[int] = []
	for id: int in view._tiles:
		if id != pair[0] and view.game.parts_compatible(view.game.cell(pair[0]), view.game.cell(id)):
			ids.append(id)
	view._set_completion_ids(ids, pair[0], 0.0)
	check(view._ambient_budget._refreshes - before_membership <= 2, source_kind + ": a crowded hint transition uses bounded scheduler refreshes")
	var held_ids: Array[int] = view._hint_matching_ids.duplicate()
	view.set_reduced_motion(true)
	check(view._pointer == 7 and view._source == pair[0] and view._hint_matching_ids == held_ids,
		source_kind + ": enabling reduced motion preserves the held source and every matching identity")
	for id: int in held_ids:
		var reduced_tile = view._tiles[id]
		check(reduced_tile.completion_hint and reduced_tile._completion_reduced
			and is_equal_approx(reduced_tile.completion_scale, 1.0)
			and is_equal_approx(float(reduced_tile._gel.get_shader_parameter("completion_strength")), 0.82),
			source_kind + ": reduced motion updates every static and animated completion cue")
	view.set_reduced_motion(false)
	check(view._pointer == 7 and view._source == pair[0] and view._hint_matching_ids == held_ids,
		source_kind + ": restoring motion retains the same held match set")
	for id: int in held_ids:
		var restored_tile = view._tiles[id]
		check(restored_tile.completion_hint and not restored_tile._completion_reduced,
			source_kind + ": restoring motion updates every cue's presentation mode")
		if id not in view._hint_animated_ids:
			check(not restored_tile._completion_animated
				and is_equal_approx(restored_tile.completion_scale, restored_tile.COMPLETION_HELD_SCALE)
				and is_equal_approx(float(restored_tile._gel.get_shader_parameter("completion_strength")), 0.95),
				source_kind + ": restoring motion immediately restores each distant static cue's held size and brightness")

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	var data := Data.new()
	check(data.load_all(), "Production data loads for authored preview regressions")
	for source_kind: String in ["root", "merged"]:
		var view := CountedView.new()
		root.add_child(view)
		view.size = Vector2(1366, 768)
		var pair: Array[int] = Fixture.install(view, data, 49, source_kind)
		check(view._press(7, view._tiles[pair[0]].get_global_rect().get_center()), source_kind + ": an actual authored source is held")
		Fixture.motion(view, Fixture.point(view, pair, 0, 0, 1, false))
		view._process(1.0 / 60.0)
		_check_preview_boundaries(view, pair, source_kind)
		_check_hint_budget(view, pair, source_kind)
		view.free()
		await process_frame
	print("Word Jelly preview caches and hint budget: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
