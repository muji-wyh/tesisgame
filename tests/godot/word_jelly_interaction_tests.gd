extends "res://tests/godot/word_jelly_view_tests.gd"
## Input ownership across fusion and the distinction between word hints and drops.

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	check(data.load_all(), "Interaction fixtures load production vocabulary")
	for word: Dictionary in data.words:
		if str(word.id) in ["cat", "apple"]:
			words.append(word)
	var view := Jelly.new()
	root.add_child(view)
	view.word_requested.connect(func(word: Dictionary) -> void: heard.append(word))
	for dimensions: Vector2 in [Vector2(1000, 720), Vector2(390, 844)]:
		view.size = dimensions
		for reduced: bool in [false, true]:
			_check_cross_level_hints(view, reduced)
			_check_early_match(view, reduced)
			for release_early: bool in [false, true]:
				_check_fusion_drag(view, reduced, release_early)
			_check_fusion_cancel(view, reduced)
			_check_fusion_chain(view, reduced)
			_check_fusion_interruptions(view, reduced)
	view.free()
	print("Word Jelly interaction: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check_cross_level_hints(view, reduced: bool) -> void:
	_reset(view, reduced)
	var ids: Array[int] = _completion_board(view, ["merged:cat:2", "merged:cat:2", "merged:cat:4", "merged:cat:9", "merged:apple:2"])
	check(view._press(-1, _center(view, ids[0])), "A merged word can be selected")
	_assert_completion_hints(view, [ids[1], ids[2], ids[3]], "same-word levels")
	check(not view.game.can_merge(view.game.cell(ids[0]), view.game.cell(ids[2])), "Cross-level hints do not authorize an upgrade")
	view.cancel_input()
	check(view._press(7, _center(view, ids[3])), "The maximum level remains selectable")
	_assert_completion_hints(view, [ids[0], ids[1], ids[2]], "maximum-level word family")
	view.cancel_input()
	_assert_completion_hints(view, [], "canceled cross-level selection")

func _check_early_match(view, reduced: bool) -> void:
	for target: String in ["picture:cat", "picture:apple"]:
		_reset(view, reduced)
		var ids: Array[int] = _install(view, ["root:cat", target])
		var destination: Vector2 = _center(view, ids[1])
		check(view._press(-1, _center(view, ids[0])), "The approach fixture can be held")
		view._move(destination - Vector2(view._pitch * 0.98, 0))
		var source_outline: PackedVector2Array = view._tiles[ids[0]].contact_outline(Vector2.ONE if reduced else view.DRAG_STRETCH)
		check(Geometry2D.intersect_polygons(source_outline, view._tiles[ids[1]].contact_outline()).is_empty(), "Early guidance starts before the painted bodies overlap")
		check(view._target == (ids[1] if target == "picture:cat" else -1), "Only a valid match is offered at the wider distance")
		view._move(destination)
		check(view._target == ids[1] and view._contact_state().kind == ("match" if target == "picture:cat" else "touch"), "Close contact retains correct and neutral feedback")
		view.cancel_input()

func _start_fusion(view) -> Dictionary:
	var ids: Array[int] = _completion_board(view, ["root:cat", "picture:cat", "merged:cat:1", "picture:apple", "root:apple"])
	_drag(view, ids[0], ids[1])
	check(view.game.fusions.size() == 1, "A real drag starts the merge")
	_advance(view, 0.08)
	return view.game.fusions[0].duplicate(true)

func _check_fusion_drag(view, reduced: bool, release_early: bool) -> void:
	_reset(view, reduced)
	var fusion: Dictionary = _start_fusion(view)
	var visual: Dictionary = view._fusion_visuals[str(fusion.attempt_id)]
	var origin: Vector2 = view.get_global_transform() * view._tile_rect(fusion.result).get_center()
	check(view._press(7, origin), "Either merging body can be picked up before completion")
	var destination: Vector2 = origin - Vector2(0, view._pitch * 2.0)
	view._move(destination)
	check(not view._fusion_drag.is_empty() and view.game.fusions.size() == 1, "Moving preserves the in-progress merge clock")
	check(visual.merged.position.distance_to(view._tile_rect(fusion.result).position + Vector2(0, -view._pitch * 2.0)) < 0.1, "Fusion artwork follows the finger immediately")
	var result_id: int = int(fusion.result.id)
	if release_early:
		view._release(destination)
	else:
		_advance(view, float(fusion.duration))
		check(view._source == result_id and view._dragging and view.game.is_lifted(result_id), "The completed result inherits the same live drag")
		check(view._tiles[result_id].get_global_rect().get_center().distance_to(destination) < 0.1, "Completion does not jump away from the pointer")
		view._move(destination + Vector2(0, -view._pitch * 0.5))
		view._release(destination + Vector2(0, -view._pitch * 0.5))
	_advance(view, 1.0)
	check(view.game.merged_count == 1 and view.game.fusions.is_empty(), "Fusion drag commits its accepted merge exactly once")
	check(not view.game.cell(result_id).is_empty() and view.game.cell(int(fusion.a_id)).is_empty() and view.game.cell(int(fusion.b_id)).is_empty(), "Only one replacement survives the handoff")
	check(view._pointer == view.NO_POINTER and view._source == -1 and not view.game.is_lifted(result_id), "Release relinquishes pointer and model ownership")
	check(view.game.collected_coins == 0 and view.game.cleared_pairs == 0 and heard.is_empty(), "Dragging a fusion never turns into a collection or pronunciation tap")
	var occupied: Dictionary = {}
	for tile: Dictionary in view.game.cells:
		var slot := Vector2i(tile.column, tile.row)
		check(not occupied.has(slot), "Post-drag gravity leaves disjoint board occupancy")
		occupied[slot] = true

func _check_fusion_cancel(view, reduced: bool) -> void:
	_reset(view, reduced)
	var fusion: Dictionary = _start_fusion(view)
	var center: Vector2 = view.get_global_transform() * view._tile_rect(fusion.result).get_center()
	view._press(-1, center)
	view._move(center - Vector2(0, view._pitch))
	view.cancel_input()
	check(view._fusion_drag.is_empty() and not bool(view.game.fusions[0].get("held_for_drag", false)), "Cancellation clears fusion drag ownership")
	_advance(view, 1.0)
	check(view.game.merged_count == 1 and not view.game.is_lifted(int(fusion.result.id)), "Canceled movement lets the accepted merge finish at its reserved slot")
	view.cancel_input()

func _check_fusion_chain(view, reduced: bool) -> void:
	_reset(view, reduced)
	var fusion: Dictionary = _start_fusion(view)
	var partner: int = -1
	for cell: Dictionary in view.game.cells:
		if str(cell.get("jelly_kind", "")) == "merged":
			partner = int(cell.id)
	var center: Vector2 = view.get_global_transform() * view._tile_rect(fusion.result).get_center()
	check(view._press(7, center), "An unfinished pair can start a chained drag")
	view._move(_center(view, partner))
	view._release(_center(view, partner))
	check(view.game.merged_count == 1 and view.game.fusions.size() == 1, "Early drop commits the first pair and starts only one next merge")
	_advance(view, 1.0)
	check(view.game.merged_count == 2 and view.game.fusions.is_empty(), "The chained upgrade completes exactly once")
	var upgraded: int = 0
	for cell: Dictionary in view.game.cells:
		if int(cell.get("merge_level", 0)) == 2:
			upgraded += 1
	check(upgraded == 1 and view.game.collected_coins == 0, "Chaining produces one level-two word and no collection payout")

func _check_fusion_interruptions(view, reduced: bool) -> void:
	for interruption: String in ["pause", "stop", "reconfigure", "tap"]:
		_reset(view, reduced)
		var fusion: Dictionary = _start_fusion(view)
		var center: Vector2 = view.get_global_transform() * view._tile_rect(fusion.result).get_center()
		view._press(-1, center)
		if interruption != "tap":
			view._move(center - Vector2(0, view._pitch))
		match interruption:
			"pause":
				view.pause(true)
				check(view._fusion_drag.is_empty(), "Pausing retires fusion pointer ownership")
				view.pause(false)
			"stop": view.stop()
			"reconfigure": _reset(view, reduced)
			"tap": view._release(center)
		_advance(view, 1.0)
		check(view._fusion_drag.is_empty() and view._pointer == view.NO_POINTER, "Fusion interruption leaves no stranded input: " + interruption)
		check(view.game.collected_coins == 0 and view.game.cleared_pairs == 0, "Fusion interruption never becomes a collection: " + interruption)
