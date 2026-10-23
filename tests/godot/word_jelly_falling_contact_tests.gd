extends "res://tests/godot/word_jelly_interaction_tests.gd"
## Catch a moving painted body without waiting for its reserved cell to settle.

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	check(data.load_all(), "Falling contact uses production vocabulary")
	for word: Dictionary in data.words:
		if str(word.id) in ["cat", "apple", "carrot", "tooth", "bird", "walk", "hear", "chair"]:
			words.append(word)
	var view := Jelly.new()
	root.add_child(view)
	view.audio_requested.connect(func(cue: String) -> void: cues.append(cue))
	for dimensions: Vector2 in [Vector2(1000, 720), Vector2(390, 844)]:
		view.size = dimensions
		for reduced: bool in [false, true]:
			for pointer: int in [-1, 7]:
				_check_falling_catch(view, reduced, pointer)
				_check_falling_mismatch(view, reduced, pointer)
			_check_arrival_catch(view, reduced)
			_check_falling_fusion(view, reduced)
			_check_falling_cancel(view, reduced)
		_check_stationary_catch(view)
	view.free()
	print("Word Jelly falling contact: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _lift_support(view, reduced: bool, pointer: int = 7, target: String = "picture:walk") -> Array[int]:
	_reset(view, reduced, 3)
	var ids: Array[int] = _install(view, ["root:walk", target])
	for index: int in range(2):
		view.game.cells[index].column = 2
		view.game.cells[index].row = Model.ROWS - 1 - index
	view._sync_tiles()
	view._reflow.clear()
	view._sync_positions()
	check(view._press(pointer, _center(view, ids[0])), "The walk support can be picked up")
	view._move(_center(view, ids[0]) - Vector2(view._pitch * 1.6, 0))
	check(view.game.is_lifted(ids[0]) and not bool(view.game.cell(ids[1]).falling),
		"Lifting walk holds its picture in place during the support grace period")
	_advance(view, Model.DRAG_GRAVITY_DELAY_SECONDS)
	check(view.game.is_lifted(ids[0]) and bool(view.game.cell(ids[1]).falling),
		"The picture starts falling after the 600 ms support grace period")
	check(not view.game.is_settled(view.game.cell(ids[1])), "The picture has not landed")
	return ids

func _check_falling_catch(view, reduced: bool, pointer: int) -> void:
	var ids: Array[int] = _lift_support(view, reduced, pointer)
	_advance(view, Model.SETTLE_SECONDS * 0.2)
	check(view.game.try_merge(ids[0], ids[1]) == "ignored", "An unheld command still waits for a settled target")
	_place_at_gap(view, ids[1], Vector2.LEFT, 8.0)
	check(view._target == -1, "Falling matches do not gain a remote contact radius")
	var point: Vector2 = _place_at_gap(view, ids[1], Vector2.LEFT, 1.0)
	check(view._target == ids[1] and view._contact_state().kind == "match", "A slight touch catches the falling match")
	check(view._tiles[ids[1]].completion_hint and view._tiles[ids[1]].highlighted, "The falling match has both selection and close-contact feedback")
	var inverse: Transform2D = view.get_global_transform().affine_inverse()
	var contact: Vector2 = inverse * view._tiles[ids[1]]._surface.get_global_rect().get_center()
	view._release(point)
	check(view.game.fusions.size() == 1, "Release accepts the falling match before settlement")
	if view.game.fusions.is_empty():
		return
	var fusion: Dictionary = view.game.fusions[0]
	check(not view.game.is_settled(fusion.b), "The accepted payload proves the target was still falling")
	check(Vector2(view._fusion_visuals[str(fusion.attempt_id)].origin_b).distance_to(contact) < 0.1, "The union begins at the visible falling skin")
	check(not view._reflow.has(ids[1]) and not view._tiles[ids[1]].visible, "The union exclusively owns the interrupted falling body")
	check(not view.game.is_contactable(view.game.cell(ids[1])), "An accepted endpoint cannot be caught twice")
	cues.clear()
	_advance(view, Model.FUSION_SECONDS * 0.8)
	check(cues.count("land") == 0, "An interrupted fall cannot play a phantom landing during fusion")
	_advance(view, Model.FUSION_SECONDS * 0.2 + Model.SETTLE_SECONDS * 2.0)
	check(view.game.merged_count == 1 and view.game.cells.size() == 1 and view.game.fusions.is_empty(), "The catch produces exactly one completed word")
	check(view.game.cell(ids[0]).is_empty() and view.game.cell(ids[1]).is_empty(), "Neither consumed body returns after landing time")
	check(view._reflow.is_empty() and view._arrival_origins.is_empty(), "Consumed falling animation records are cleaned up")

func _check_stationary_catch(view) -> void:
	var ids: Array[int] = _lift_support(view, false)
	_place_at_gap(view, ids[1], Vector2.DOWN, 8.0)
	cues.clear()
	check(view._target == -1, "A stationary catcher starts outside contact")
	var held: Vector2 = view._tiles[ids[0]].position
	for frame: int in range(14):
		if view._target == ids[1]:
			break
		_advance(view, 0.01)
	check(view._target == ids[1] and view._contact_state().kind == "match", "Descent triggers contact without another pointer move")
	check(view._tiles[ids[0]].position.is_equal_approx(held) and not view.game.is_settled(view.game.cell(ids[1])), "The stationary hand catches the picture in flight")
	check(cues.count("contact") == 1, "Moving contact emits one contact sound")
	view._release(view.get_global_transform() * view._drag_point)
	check(view.game.fusions.size() == 1, "A stationary catch merges on release")

func _check_falling_mismatch(view, reduced: bool, pointer: int) -> void:
	var ids: Array[int] = _lift_support(view, reduced, pointer, "picture:apple")
	_place_at_gap(view, ids[1], Vector2.LEFT, 1.0)
	check(view._target == -1, "A nonmatching fall retains the strict touch distance")
	var point: Vector2 = _center(view, ids[1])
	view._move(point)
	check(view._target == ids[1] and view._contact_state().kind == "touch", "A nonmatching falling body still responds to collision")
	view._release(point)
	_advance(view, Model.SETTLE_SECONDS * 3.0)
	check(view.game.fusions.is_empty() and view.game.merged_count == 0 and view.game.cells.size() == 2, "A nonmatch keeps both bodies and never merges")
	check(cues.count("wrong") == 1, "An invalid falling drop receives ordinary rejection feedback")
	for cell: Dictionary in view.game.cells:
		check(view.game.is_settled(cell) and not view.game.is_lifted(int(cell.id)), "Rejected airborne contact restores normal board ownership")

func _check_arrival_catch(view, reduced: bool) -> void:
	_reset(view, reduced, 3)
	var ids: Array[int] = _install(view, ["root:walk", "picture:walk"])
	var target: Dictionary = view.game.cells[1]
	target.row = Model.ROWS - 1
	target.arrival = true
	target.arrival_delay = 0.3
	target.age = 0.1
	view._sync_positions()
	check(not view.game.is_contactable(target), "A queued arrival is not catchable before departure")
	check(view.game.try_merge(ids[0], ids[1], true) == "ignored", "Held drops cannot consume a queued supply item")
	check(view._press(7, _center(view, ids[0])), "The arrival catcher can be selected")
	view._move(_center(view, ids[0]) + Vector2(view._pitch, 0))
	_advance(view, 0.35)
	check(view.game.is_contactable(target) and not view.game.is_settled(target), "A departed supply picture is catchable during flight")
	if not reduced:
		view._move(view.get_global_transform() * view._tile_rect(target).get_center())
		check(view._target == -1, "The reserved landing cell has no invisible collision body")
	var point: Vector2 = _place_at_gap(view, ids[1], Vector2.LEFT, 1.0)
	check(view._target == ids[1] and view._contact_state().kind == "match", "The incoming picture uses its current rendered outline")
	view._release(point)
	check(view.game.fusions.size() == 1, "A departed supply picture merges before landing")
	_advance(view, 1.2)
	check(view.game.merged_count == 1 and view.game.cells.size() == 1, "Caught arrivals cannot respawn at their old destination")

func _check_falling_fusion(view, reduced: bool) -> void:
	_reset(view, reduced, 3)
	var ids: Array[int] = _completion_board(view, ["root:walk", "picture:walk", "merged:walk:1"])
	_drag(view, ids[0], ids[1])
	_advance(view, 0.08)
	var fusion: Dictionary = view.game.fusions[0]
	var target: Dictionary = view.game.cells[2]
	target.age = 0.0
	target.falling = true
	target.settling = true
	view._reflow[ids[2]] = {"from": view._tiles[ids[2]].position - Vector2(0, view._pitch), "started": 0.0, "falling": true}
	view._sync_positions()
	var origin: Vector2 = _fusion_grab_point(view, fusion)
	var offset: Vector2 = origin - view.get_global_transform() * view._tile_rect(fusion.result).get_center()
	check(view._press(7, origin), "An active union can be grabbed to catch another falling word")
	var point: Vector2 = _place_at_gap(view, ids[2], Vector2.LEFT, 1.0, offset)
	check(view._target == ids[2] and view._contact_state().kind == "match", "An active union advertises its falling upgrade partner")
	view._release(point)
	_advance(view, 1.2)
	check(view.game.merged_count == 2 and view.game.cells.size() == 1 and int(view.game.cells[0].merge_level) == 2, "Release chains the caught fall into exactly one upgrade")

func _check_falling_cancel(view, reduced: bool) -> void:
	var ids: Array[int] = _lift_support(view, reduced)
	_place_at_gap(view, ids[1], Vector2.LEFT, 1.0)
	view.cancel_input()
	_advance(view, 1.2)
	check(view.game.merged_count == 0 and view.game.cells.size() == 2 and view.game.fusions.is_empty(), "Canceling a catch preserves both words")
	for cell: Dictionary in view.game.cells:
		check(_has_support(view.game.cells, cell) and view.game.is_settled(cell) and not view.game.is_lifted(int(cell.id)), "Canceled catches finish with supported independent bodies")
