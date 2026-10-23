extends "res://tests/godot/word_jelly_view_tests.gd"
## Input ownership across fusion and the distinction between word hints and drops.

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	check(data.load_all(), "Interaction fixtures load production vocabulary")
	for word: Dictionary in data.words:
		if str(word.id) in ["cat", "apple", "carrot", "tooth", "bird", "walk", "hear", "chair"]:
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
			_check_match_edges(view, reduced)
			_check_crowded_match(view, reduced)
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
	var ids: Array[int] = _completion_board(view, ["merged:cat:2", "merged:cat:2", "merged:cat:4", "merged:cat:6", "merged:apple:2"])
	check(view._press(-1, _center(view, ids[0])), "A merged word can be selected")
	_assert_completion_hints(view, [ids[1], ids[2], ids[3]], "same-word levels")
	check(view.game.can_merge(view.game.cell(ids[0]), view.game.cell(ids[2])), "Cross-level Lv2 and Lv4 words can merge into Lv6")
	check(not view.game.can_merge(view.game.cell(ids[0]), view.game.cell(ids[3])), "A family hint cannot authorize an over-cap upgrade")
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
		_place_at_gap(view, ids[1], Vector2.LEFT, 1.0)
		var source_outline: PackedVector2Array = view._tiles[ids[0]].contact_outline(Vector2.ONE if reduced else view.DRAG_STRETCH)
		check(Geometry2D.intersect_polygons(source_outline, view._tiles[ids[1]].contact_outline()).is_empty(), "Early guidance starts before the painted bodies overlap")
		check(view._target == (ids[1] if target == "picture:cat" else -1), "Only a valid match is offered with a one-pixel painted gap")
		view._move(destination)
		check(view._target == ids[1] and view._contact_state().kind == ("match" if target == "picture:cat" else "touch"), "Close contact retains correct and neutral feedback")
		view.cancel_input()

func _check_match_edges(view, reduced: bool) -> void:
	for offset: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP,
		Vector2(0.78, 0.72), Vector2(-0.78, 0.72), Vector2(0.78, -0.72), Vector2(-0.78, -0.72)]:
		_reset(view, reduced, 4)
		var ids: Array[int] = _install(view, ["root:hear", "picture:hear"])
		check(view._press(7, _center(view, ids[0])), "The edge fixture can be picked up")
		_place_at_gap(view, ids[1], offset, 8.0)
		check(view._target == -1, "An eight-pixel painted gap cannot advertise a merge: " + str(offset))
		var approach: Vector2 = _place_at_gap(view, ids[1], offset, 1.0)
		check(view._target == ids[1] and view._contact_state().kind == "match", "A matching edge or corner gets forgiving contact: " + str(offset))
		_advance(view, 0.2)
		check(view._target == ids[1], "Steady contact cannot disconnect itself")
		for id: int in ids:
			var tile = view._tiles[id]
			var direction: Vector2 = tile._gel.get_shader_parameter("contact_direction")
			check(tile._surface.position.dot(direction) >= 0.0, "Matching feedback never pushes either painted body away")
			check(tile._surface.position.length() < tile.size.length() * 0.03, "Matching attraction stays subtle and attached to the pointer")
		view._release(approach)
		_advance(view, 1.0)
		check(view.game.merged_count == 1 and view.game.fusions.is_empty(), "A slight-touch cue releases into exactly one merge")

func _painted_gap(view, target: int) -> float:
	var gap: float = INF
	var other: PackedVector2Array = view._tiles[target].contact_outline()
	for outline: PackedVector2Array in view._feedback_outlines(view._feedback_body()):
		if not Geometry2D.intersect_polygons(outline, other).is_empty():
			return 0.0
		for a: int in range(outline.size()):
			for b: int in range(other.size()):
				gap = minf(gap, outline[a].distance_to(Geometry2D.get_closest_point_to_segment(outline[a], other[b], other[(b + 1) % other.size()])))
				gap = minf(gap, other[b].distance_to(Geometry2D.get_closest_point_to_segment(other[b], outline[a], outline[(a + 1) % outline.size()])))
	return gap * Style.ui_scale(view)

func _place_at_gap(view, target: int, direction: Vector2, pixels: float, grab_offset: Vector2 = Vector2.ZERO) -> Vector2:
	# Measure the acquired paint, independently of the production match margin.
	var destination: Vector2 = _center(view, target) + grab_offset
	var near: float = 0.0
	var far: float = view._pitch * 3.0
	for step: int in range(16):
		var distance: float = (near + far) * 0.5
		view._move(destination + direction.normalized() * distance)
		if _painted_gap(view, target) < pixels:
			near = distance
		else:
			far = distance
	var approach: Vector2 = destination + direction.normalized() * far
	view._move(approach)
	check(absf(_painted_gap(view, target) - pixels) < 0.1, "The fixture uses the requested visible edge gap")
	return approach

func _fusion_grab_point(view, fusion: Dictionary) -> Vector2:
	if view.reduced_motion:
		return view.get_global_transform() * view._tile_rect(fusion.result).get_center()
	var visual: Dictionary = view._fusion_visuals[str(fusion.attempt_id)]
	var body: Vector4 = visual.art._gel.get_shader_parameter("body_b")
	return view.get_global_transform() * (visual.art.position + Vector2(body.x, body.y))

func _crowded_carrot_board(view, fusing: bool = false) -> Array[int]:
	var pieces: Array[String] = ["root:carrot", "root:tooth", "merged:carrot:1" if fusing else "picture:carrot", "root:bird", "root:walk"]
	if fusing:
		pieces.append("picture:carrot")
	var ids: Array[int] = _completion_board(view, pieces)
	for index: int in [3, 4]:
		var cell: Dictionary = view.game.cells[index]
		cell.column = index - 2
		cell.row = Model.ROWS - 2
	if fusing:
		view.game.cells[0].column = 4
		view.game.cells[0].row = Model.ROWS - 2
		var cell: Dictionary = view.game.cells[5]
		cell.column = 4
		cell.row = Model.ROWS - 1
	view._sync_tiles()
	view._layout()
	view._reflow.clear()
	view._sync_positions()
	return ids

func _check_crowded_match(view, reduced: bool) -> void:
	for mode: String in ["ordinary", "fusion-early", "fusion-handoff"]:
		_reset(view, reduced, 4)
		var fusing: bool = mode != "ordinary"
		var ids: Array[int] = _crowded_carrot_board(view, fusing)
		var origin: Vector2 = _center(view, ids[0])
		var grab_offset := Vector2.ZERO
		var fusion: Dictionary = {}
		if fusing:
			_drag(view, ids[0], ids[5])
			check(view.game.fusions.size() == 1, "The crowded fixture starts one accepted carrot merge")
			if view.game.fusions.is_empty():
				continue
			_advance(view, 0.08)
			fusion = view.game.fusions[0].duplicate(true)
			origin = _fusion_grab_point(view, fusion)
			grab_offset = origin - view.get_global_transform() * view._tile_rect(fusion.result).get_center()
		var accepted: bool = view._press(7, origin)
		check(accepted, "The crowded carrot can be picked up: " + mode)
		if not accepted:
			continue
		var approach: Vector2 = _place_at_gap(view, ids[2], Vector2(-0.75, -0.65), 1.0, grab_offset)
		var outlines: Array[PackedVector2Array] = view._feedback_outlines(view._feedback_body())
		var neutral_overlap: bool = false
		for index: int in [1, 3, 4]:
			for outline: PackedVector2Array in outlines:
				neutral_overlap = neutral_overlap or not Geometry2D.intersect_polygons(outline, view._tiles[ids[index]].contact_outline()).is_empty()
		check(neutral_overlap, "The screenshot fixture physically overlaps unrelated neighbors")
		check(view._target == ids[2] and view._contact_state().kind == "match", "A diagonal carrot match takes priority over unrelated overlaps: " + mode)
		check(view._tiles[ids[2]].highlighted and view._tiles[ids[2]]._contact_kind == "match", "The matching carrot visibly responds before release")
		for index: int in [1, 3, 4]:
			check(view._tiles[ids[index]]._contact_kind == "none", "Unrelated neighbors cannot steal matching contact")
		if mode == "fusion-handoff":
			_advance(view, float(fusion.duration))
			check(view._target == ids[2] and view._contact_state().kind == "match", "The crowded diagonal match survives natural fusion completion")
		view._release(approach)
		_advance(view, 1.0)
		check(view.game.merged_count == (2 if fusing else 1) and view.game.fusions.is_empty(), "Releasing on the diagonal cue performs exactly the advertised merge: " + mode)
		check(view.game.cell(ids[2]).is_empty(), "The indicated carrot is consumed by its match")
		for index: int in [1, 3, 4]:
			check(not view.game.cell(ids[index]).is_empty(), "The advertised drop preserves each unrelated neighbor")
		check(view.game.collected_coins == 0 and view.game.cleared_pairs == 0, "Matching priority does not collect or pay out")

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
	for description: String in ["merged:cat:1", "merged:cat:4", "merged:cat:6", "picture:apple"]:
		_reset(view, reduced)
		var ids: Array[int] = _completion_board(view, ["root:cat", "picture:cat", description])
		_drag(view, ids[0], ids[1])
		_advance(view, 0.08)
		var fusion: Dictionary = view.game.fusions[0].duplicate(true)
		var visual: Dictionary = view._fusion_visuals[str(fusion.attempt_id)]
		var origin: Vector2 = view.get_global_transform() * view._tile_rect(fusion.result).get_center()
		var partner: int = ids[2]
		var destination: Vector2 = _center(view, partner)
		var matching: bool = description in ["merged:cat:1", "merged:cat:4"]
		check(view._press(7, origin), "An active fusion can be held for contact feedback")
		check(view._tiles[partner].completion_hint == description.begins_with("merged:cat"), "Pending words highlight their same-word family across levels")
		var separated: Vector2 = _place_at_gap(view, partner, Vector2.UP, 8.0)
		check(view._target == -1, "A pending fusion cannot advertise contact across an eight-pixel gap")
		var approach: Vector2 = _place_at_gap(view, partner, Vector2.UP, 1.0)
		view._move(separated)
		cues.clear()
		view._move(approach)
		var overlaps: bool = false
		for outline: PackedVector2Array in view._feedback_outlines(visual.merged):
			overlaps = overlaps or not Geometry2D.intersect_polygons(outline, view._tiles[partner].contact_outline()).is_empty()
		check(not overlaps, "Fusion approach guidance begins outside the painted bodies")
		check(view._target == (partner if matching else -1), "Only a compatible pending result gets wider merge guidance")
		check(view._contact_state().kind == ("match" if matching else "none"), "Approach feedback only advertises sums within the six-level cap")
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
	var approach: Vector2 = _place_at_gap(view, ids[2], Vector2.UP, 1.0)
	check(view._contact_state().kind == "match", "The fusion's slight-touch cue advertises an actionable drop")
	view._release(approach)
	check(view.game.merged_count == 1 and view.game.fusions.size() == 1, "Releasing at slight touch commits the pair and starts its advertised upgrade")
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
