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
	view.audio_requested.connect(func(cue: String) -> void: cues.append(cue))
	for dimensions: Vector2 in [Vector2(1000, 720), Vector2(390, 844)]:
		view.size = dimensions
		for reduced: bool in [false, true]:
			_check_cross_level_hints(view, reduced)
			_check_early_match(view, reduced)
			for release_early: bool in [false, true]:
				_check_fusion_drag(view, reduced, release_early)
			_check_fusion_cancel(view, reduced)
			_check_fusion_chain(view, reduced)
			_check_fusion_contact(view, reduced)
			_check_fusion_approach_drop(view, reduced)
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
	check(view._target == partner and view._contact_state().kind == "match", "The unfinished pair previews its chained match before release")
	check(view._tiles[partner]._contact_kind == "match" and view._tiles[partner].highlighted, "The pending result lights and presses its next partner")
	check(view.game.merged_count == 0 and view.game.fusions.size() == 1, "Approaching never commits the pending pair early")
	view._release(_center(view, partner))
	check(view.game.merged_count == 1 and view.game.fusions.size() == 1, "Early drop commits the first pair and starts only one next merge")
	_advance(view, 1.0)
	check(view.game.merged_count == 2 and view.game.fusions.is_empty(), "The chained upgrade completes exactly once")
	var upgraded: int = 0
	for cell: Dictionary in view.game.cells:
		if int(cell.get("merge_level", 0)) == 2:
			upgraded += 1
	check(upgraded == 1 and view.game.collected_coins == 0, "Chaining produces one level-two word and no collection payout")

func _check_fusion_contact(view, reduced: bool) -> void:
	for description: String in ["merged:cat:1", "merged:cat:4", "picture:apple"]:
		_reset(view, reduced)
		var ids: Array[int] = _completion_board(view, ["root:cat", "picture:cat", description])
		_drag(view, ids[0], ids[1])
		_advance(view, 0.08)
		var fusion: Dictionary = view.game.fusions[0].duplicate(true)
		var visual: Dictionary = view._fusion_visuals[str(fusion.attempt_id)]
		var origin: Vector2 = view.get_global_transform() * view._tile_rect(fusion.result).get_center()
		var partner: int = ids[2]
		var destination: Vector2 = _center(view, partner)
		var matching: bool = description == "merged:cat:1"
		check(view._press(7, origin), "An active fusion can be held for contact feedback")
		check(view._tiles[partner].completion_hint == description.begins_with("merged:cat"), "Pending words highlight their same-word family across levels")
		cues.clear()
		var approach: Vector2 = destination - Vector2(0, view._pitch * 0.90)
		view._move(approach)
		var overlaps: bool = false
		for outline: PackedVector2Array in view._feedback_outlines(visual.merged):
			overlaps = overlaps or not Geometry2D.intersect_polygons(outline, view._tiles[partner].contact_outline()).is_empty()
		check(not overlaps, "Fusion approach guidance begins outside the painted bodies")
		check(view._target == (partner if matching else -1), "Only a compatible pending result gets wider merge guidance")
		check(view._contact_state().kind == ("match" if matching else "none"), "Cross-level hints do not advertise an invalid upgrade")
		# Exercise the browser's coalesced pointer path as well as direct moves.
		view._queue_drag_motion(destination - Vector2(0, view._pitch * 0.3))
		_advance(view, 0.025)
		var kind: String = "match" if matching else "touch"
		check(view._target == partner and view._contact_state().kind == kind, "Active fusion contact resolves before pointer-up")
		check(visual.merged._contact_kind == kind and view._tiles[partner]._contact_kind == kind, "Both the pending result and target receive contact feedback")
		check(int(visual.art._gel.get_shader_parameter("contact_kind")) == (2 if matching else 1), "The visible joining lobes receive the same contact cue")
		var pressure: float = float(visual.art._gel.get_shader_parameter("contact_strength"))
		check(is_zero_approx(pressure) if reduced else pressure > 0.0, "Lobe pressure respects reduced motion")
		check(cues.count("contact") == 1 and cues.count("wrong") == 0, "Approach and continued contact share one cue without premature rejection")
		var previous_elapsed: float = float(view.game.fusions[0].elapsed)
		_advance(view, 0.075)
		check(float(view.game.fusions[0].elapsed) > previous_elapsed and view.game.merged_count == 0, "The held merge clock advances without early completion")
		check(view._target == partner and cues.count("contact") == 1, "Pressure cannot flicker its own contact or repeat the cue")
		check(view.game.cell(int(fusion.result.id)).is_empty() and view.game.collected_coins == 0 and heard.is_empty(), "Preview feedback cannot materialize, collect or read the pending result")
		if matching:
			_advance(view, float(fusion.duration))
			check(view._fusion_drag.is_empty() and view._source == int(fusion.result.id), "Natural completion hands contact to the result")
			check(view._target == partner and view._contact_state().kind == "match" and cues.count("contact") == 1, "Natural handoff preserves the target and its single contact cue")
			view._release(destination - Vector2(0, view._pitch * 0.3))
			_advance(view, 1.0)
			check(view.game.merged_count == 2 and view.game.fusions.is_empty(), "A previewed natural handoff chains exactly one upgrade")
		else:
			view._move(origin - Vector2(0, view._pitch * 2.0))
			check(view._contact_state().kind == "none" and visual.merged._contact_kind == "none" and view._tiles[partner]._contact_kind == "none", "Separating clears pressure on both sides")
			view._move(destination - Vector2(0, view._pitch * 0.3))
			check(cues.count("contact") == 2, "Recontact starts one new cue")
			view.pause(true) if description == "picture:apple" else view.cancel_input()
			check(view._contact_state().kind == "none" and view._tiles[partner]._contact_kind == "none", "Pause and cancellation retire active fusion contact")
			check(int(visual.art._gel.get_shader_parameter("contact_kind")) == 0 and not view._tiles[partner].completion_hint, "Interrupted fusion leaves no lobe rim or family highlight")
			view.pause(false)
			_advance(view, 1.0)
			check(view.game.merged_count == 1 and view.game.collected_coins == 0, "Interrupted feedback preserves only the already accepted merge")

func _check_fusion_approach_drop(view, reduced: bool) -> void:
	_reset(view, reduced)
	var ids: Array[int] = _completion_board(view, ["root:cat", "picture:cat", "merged:cat:1"])
	_drag(view, ids[0], ids[1])
	_advance(view, 0.08)
	var fusion: Dictionary = view.game.fusions[0].duplicate(true)
	var origin: Vector2 = view.get_global_transform() * view._tile_rect(fusion.result).get_center()
	view._press(-1, origin)
	var approach: Vector2 = _center(view, ids[2]) - Vector2(0, view._pitch * 0.90)
	view._move(approach)
	check(view._contact_state().kind == "match", "The fusion's wider approach advertises an actionable drop")
	view._release(approach)
	check(view.game.merged_count == 1 and view.game.fusions.size() == 1, "Releasing at the wider approach commits the pair and starts its advertised upgrade")
	_advance(view, 1.0)
	check(view.game.merged_count == 2 and view.game.fusions.is_empty() and view.game.collected_coins == 0, "The early approach drop commits each merge once without collection")

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
