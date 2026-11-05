extends "res://tests/godot/word_jelly_view_tests.gd"
## Airborne poses commit once without transient destination layout or transforms.

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	check(catalog is Array and Data.validate_words(catalog).is_empty(),
		"Motion pose fixtures use validated production vocabulary")
	if failures > 0:
		quit(1)
		return
	data.words.assign(catalog)
	for word: Dictionary in data.words:
		if str(word.id) == "cat":
			words.append(word)
	var view := Jelly.new()
	root.add_child(view)
	for dimensions: Vector2 in [Vector2(1366, 768), Vector2(390, 844)]:
		view.size = dimensions
		for reduced: bool in [false, true]:
			_check_arrival_pose_commits(view, reduced)
			_check_reflow_pose_commits(view, reduced)
	view.free()
	print("Word Jelly motion poses: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_arrival_pose_commits(view, reduced: bool) -> void:
	_reset(view, reduced)
	var id: int = _install(view, ["root:cat"])[0]
	var cell: Dictionary = view.game.cells[0]
	cell.arrival = true
	cell.falling_rows = int(cell.row) + 1
	cell.arrival_delay = 0.0
	view._arrival_origins[id] = {"slot": 0, "width": 1, "height": 1,
		"pressure": 0.04, "sway": 0.003, "pull": 0.09}
	var tile = view._tiles[id]
	var changes: Array[int] = [0]
	tile.item_rect_changed.connect(func() -> void: changes[0] += 1)
	var contact: float = Model.arrival_contact_at(cell)
	var previous_foot: float = -INF
	for age: float in [0.02, 0.06, 0.13, contact * 0.65, contact, contact + 0.03]:
		cell.age = age
		view._sync_positions()
		var position: Vector2 = tile.position
		var extent: Vector2 = tile.size
		var stretch: Vector2 = tile._surface.scale
		var pressure: float = float(tile._gel.get_shader_parameter("preview_pressure"))
		var support: float = tile._support_lift
		changes[0] = 0
		view._sync_positions()
		check(changes[0] == 0 and tile.position.is_equal_approx(position) and tile.size.is_equal_approx(extent),
			"Repeating an airborne pose avoids transient rectangle writes (age %.3f, reduced %s, changes %d, position %s -> %s, size %s -> %s)"
			% [age, reduced, changes[0], position, tile.position, extent, tile.size])
		check(tile._surface.scale == stretch and tile._support_lift == support,
			"Repeating a pose retains the same skin stretch and final support shadow")
		var expected_pressure: float = 0.0 if reduced else 0.04 * (1.0 - smoothstep(0.0, 0.12, age))
		check(is_equal_approx(pressure, expected_pressure),
			"The final pose retains the sourced preview-pressure release")
		check(tile._picture.scale == Vector2.ONE and tile._label.scale == Vector2.ONE,
			"Affine skin motion leaves the learning picture and caption undistorted")
		var foot: float = position.y + extent.y * tile.Motion.FOOT_Y \
			* (1.0 + float(tile._gel.get_shader_parameter("preview_pull"))) * stretch.y
		if age < contact:
			check(foot + 0.01 >= previous_foot, "The released skin foot continues downward before impact")
		previous_foot = foot


func _check_reflow_pose_commits(view, reduced: bool) -> void:
	_reset(view, reduced)
	var id: int = _install(view, ["root:cat"])[0]
	var cell: Dictionary = view.game.cells[0]
	cell.arrival = false
	cell.falling = true
	cell.settling = true
	cell.settle_seconds = Model.SETTLE_SECONDS
	var destination: Rect2 = view._tile_rect(cell)
	view._reflow[id] = {"from": destination.position - Vector2(0.0, view._pitch * 3.0),
		"started": 0.0, "falling": true}
	var tile = view._tiles[id]
	var changes: Array[int] = [0]
	tile.item_rect_changed.connect(func() -> void: changes[0] += 1)
	for progress: float in [0.1, 0.5, 0.86, 0.97]:
		cell.age = Model.SETTLE_SECONDS * progress
		view._sync_positions()
		var position: Vector2 = tile.position
		var skin_scale: Vector2 = tile._surface.scale
		changes[0] = 0
		view._sync_positions()
		check(changes[0] == 0 and tile.position == position and tile._surface.scale == skin_scale,
			"Gravity translation and landing squash do not rewind through the destination on repeated poses")
		check(tile._label.scale == Vector2.ONE and tile._picture.scale == Vector2.ONE,
			"Gravity landing squash preserves the separate learning face")
