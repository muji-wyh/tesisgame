extends SceneTree

const Model = preload("res://scripts/word_jelly_model.gd")
const Growth = preload("res://scripts/growth_morphology.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _board(model: RefCounted, label: String) -> void:
	for tile: Dictionary in model.cells:
		check(not tile.get("lifted", false), label + ": no body remains held after cancellation")
		check(tile.width == 1 and tile.height == 1, label + ": every authored or fixture body retains its ordinary size")
		var footprint := Rect2i(tile.column, tile.row, tile.width, tile.height)
		check(Rect2i(0, 0, Model.COLUMNS, Model.ROWS).encloses(footprint), label + ": body stays inside the board")
		var supported: bool = int(tile.row) + int(tile.height) == Model.ROWS
		for other: Dictionary in model.cells:
			if tile.id == other.id:
				continue
			check(not footprint.intersects(Rect2i(other.column, other.row, other.width, other.height)), label + ": bodies never overlap")
			supported = supported or (int(other.row) == int(tile.row) + int(tile.height)
				and int(other.column) < int(tile.column) + int(tile.width)
				and int(other.column) + int(other.width) > int(tile.column))
		check(supported, label + ": each released body has actual support")


func _run() -> void:
	var vocabulary: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	var words: Array = []
	for word: Dictionary in vocabulary:
		if word.min_age == 3 and not str(word.image).is_empty():
			words.append(Growth.decorate(word))
	var model := Model.new()
	check(model.configure(words, 3, 42), "The real reviewed Growth cohort configures")
	model.spawn_interval = 10000.0
	model.cells.clear()
	var state: Dictionary = model._morphology.source_tiles("growth.cat.analysis.v1")[0]
	var lower: Dictionary = model._new_composition_tile(state)
	var upper: Dictionary = model._new_composition_tile(state)
	lower.column = 0
	lower.row = Model.ROWS - int(lower.height)
	lower.fragments = 2
	upper.column = 0
	upper.row = int(lower.row) - int(upper.height)
	model.cells.append_array([lower, upper])
	var original_upper_row: int = upper.row
	var original_lower: Dictionary = lower.duplicate(true)
	model.set_held_tile(int(lower.id))
	check(model.begin_drag(int(lower.id)), "A reviewed whole-word support can be lifted")
	model.step(2.0)
	check(model.is_lifted(int(lower.id)) and int(upper.row) > original_upper_row and model.is_settled(upper),
		"The upper body falls onto real support while the authored lower body is still held")
	model.set_held_tile(-1)
	model.step(2.0)
	check(model._held_tile_id == -1 and model._dragged_tile_id == -1, "Cancellation releases both held identities")
	for field: String in ["id", "text", "display_text", "jelly_kind", "merge_level", "word_candidate", "image_word",
		"mass", "width", "height", "word", "fragments", "composition"]:
		check(lower[field] == original_lower[field], "Cancellation preserves authored " + field)
	_board(model, "reviewed lower support")
	_test_full_board_return(words)
	_test_arrival_preserves_return(words)
	if not OS.get_cmdline_user_args().has("--quick"):
		_test_crowded_returns(words)
	print("Word Jelly authored drag: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _cat(model: RefCounted, column: int, row: int) -> Dictionary:
	var tile: Dictionary = model._new_composition_tile(model._morphology.source_tiles("growth.cat.analysis.v1")[0])
	tile.column = column
	tile.row = row
	return tile


func _fill_fixture(model: RefCounted, keep_empty: Array[Vector2i] = []) -> void:
	var excluded: Array[int] = []
	var occupied: Dictionary = model._occupied(excluded, false)
	for row in range(Model.ROWS):
		for column in range(Model.COLUMNS):
			if occupied.has(row * Model.COLUMNS + column) or keep_empty.has(Vector2i(column, row)):
				continue
			var tile: Dictionary = model._new_tile("fixture", 1, 0)
			tile.column = column
			tile.row = row
			model.cells.append(tile)


func _test_full_board_return(words: Array) -> void:
	for early_cancel: bool in [true, false]:
		var model := Model.new()
		check(model.configure(words, 3, 42), "The full-board return regression uses the reviewed Growth cohort")
		model.spawn_interval = 10000.0
		model.cells.clear()
		var source: Dictionary = _cat(model, 0, 7)
		source.fragments = 2
		model.cells.append_array([source, _cat(model, 1, 6)])
		_fill_fixture(model)
		_board(model, "full-board starting state")
		var blocked: Array[String] = []
		model.drag_blocked.connect(func(reason: String) -> void: blocked.append(reason))
		model.set_held_tile(int(source.id))
		var before: Array = model.cells.duplicate(true)
		check(before.size() == Model.CAPACITY and model.begin_drag(int(source.id)),
			"A lower ordinary body can be lifted from a full board with a safe one-cell return")
		model.step(Model.DRAG_GRAVITY_DELAY_SECONDS - 0.001 if early_cancel else Model.DRAG_GRAVITY_DELAY_SECONDS + 0.5)
		check(model.is_lifted(int(source.id)) and blocked.is_empty(), "The full-board lift has no artificial room penalty")
		var reserved: Vector2i = model._drag_return_after_motion(source)
		check(reserved == Vector2i(0, 0), "The delayed column reserves its eventual top return cell before cancellation")
		var expected_return := Vector2i(0, 7) if early_cancel else reserved
		if early_cancel:
			for original: Dictionary in before:
				var retained: Dictionary = model.cell(int(original.id))
				check(retained.column == original.column and retained.row == original.row and not bool(retained.falling),
					"At 599 ms every body still retains its original column and row")
		else:
			check(model._occupied().has(0) and not model._occupied([], false).has(0),
				"The falling column leaves one top cell reserved without adding hidden support")
		model.set_held_tile(-1)
		model.step(0.5)
		check(model.cells.size() == before.size() and source.column == expected_return.x and source.row == expected_return.y
			and model._dragged_tile_id == -1 and model._held_tile_id == -1,
			"Early cancellation restores the origin; cancellation after the delay uses the reserved top cell")
		for original: Dictionary in before:
			var retained: Dictionary = model.cell(int(original.id))
			for field: String in ["id", "text", "display_text", "jelly_kind", "merge_level", "word_candidate", "image_word",
				"mass", "width", "height", "word", "fragments", "composition"]:
				check(retained.get(field) == original.get(field), "Full-board return preserves every body's " + field)
		_board(model, "full-board completed return")


func _test_arrival_preserves_return(words: Array) -> void:
	var model := Model.new()
	check(model.configure(words, 3, 42), "The incoming-body regression uses the reviewed Growth cohort")
	model.spawn_interval = 10000.0
	model.cells.clear()
	var source: Dictionary = _cat(model, 0, 7)
	source.fragments = 2
	model.cells.append(source)
	_fill_fixture(model)
	_board(model, "incoming-body starting board")
	model.set_held_tile(int(source.id))
	check(model.begin_drag(int(source.id)), "The full board leaves one safe return cell after its lower support is lifted")
	model.step(Model.DRAG_GRAVITY_DELAY_SECONDS - 0.001)
	check(model._drag_return_after_motion(source) == Vector2i(0, 0),
		"Incoming supply accounts for the return cell needed after the support grace period")
	var incoming: Dictionary = model._new_tile("fixture", 1, 0)
	model.upcoming.assign([incoming, {}, {}, {}, {}, {}])
	var original_preview: Array = model.upcoming.duplicate(true)
	var before: Array = model.cells.duplicate(true)
	check(not model.can_drop_now(), "The preview control does not advertise an unsafe incoming drop")
	check(not model._spawn_tile(true, 0), "An arrival cannot consume the only reserved return cell")
	check(model.cells == before and model.upcoming == original_preview,
		"A blocked arrival keeps its advertised identity and all existing bodies")
	# A separate vacancy remains usable while the held body's own cell is protected.
	var removed: Dictionary = {}
	for tile: Dictionary in model.cells:
		if int(tile.column) == 1 and int(tile.row) == 0:
			removed = tile
			break
	check(not removed.is_empty(), "The neighboring lane has a removable top fixture")
	model.cells.erase(removed)
	model.upcoming.assign([{}, incoming, {}, {}, {}, {}])
	check(model.can_drop_now() and model._spawn_tile(true, 1), "An independent vacant lane still accepts its advertised incoming body")
	check(model.cell(int(incoming.id)).column == 1 and model.cell(int(incoming.id)).row == 0
		and model._occupied().has(0), "The admitted neighbor retains its lane and the held body's return reservation")
	model.step(2.0)
	model.set_held_tile(-1)
	model.step(0.5)
	check(model._dragged_tile_id == -1 and model._held_tile_id == -1 and source.column == 0 and source.row == 0
		and source.fragments == 2 and model.cells.size() == Model.CAPACITY,
		"The reserved ordinary body returns with its fragments after a neighboring arrival")
	_board(model, "incoming-body protected return")


func _test_crowded_returns(words: Array) -> void:
	for seed_value in range(1, 13):
		var initial := Model.new()
		check(initial.configure(words, 3, seed_value), "A crowded reviewed supply configures")
		for packet in range(Model.ROWS):
			if not initial.can_drop_now():
				break
			initial.drop_now()
			initial.spawn_interval = 10000.0
			initial.step(2.0)
		var original: Array = initial.cells.duplicate(true)
		for original_source: Dictionary in original:
			var model := Model.new()
			check(model.configure(words, 3, seed_value), "A cancellation trial restores the same real supply")
			model.cells.assign(original.duplicate(true))
			model.spawn_interval = 10000.0
			model.set_held_tile(int(original_source.id))
			var before_lift: Array = model.cells.duplicate(true)
			if not model.begin_drag(int(original_source.id)):
				check(model.cells == before_lift and model._dragged_tile_id == -1,
					"A crowded lift without a safe fixed return is declined before changing any body")
				model.set_held_tile(-1)
				_board(model, "crowded declined lift")
				continue
			model.step(2.0)
			for packet in range(2):
				if model.can_drop_now():
					model.drop_now()
					model.spawn_interval = 10000.0
					model.step(2.0)
			var before_cancel: Array = model.cells.duplicate(true)
			model.set_held_tile(-1)
			model.step(2.0)
			check(model._held_tile_id == -1 and model._dragged_tile_id == -1,
				"Crowded cancellation clears every drag identity")
			check(model.cells.size() == before_cancel.size(), "Crowded cancellation retains all original and newly supplied bodies")
			for tile: Dictionary in before_cancel:
				var retained: Dictionary = model.cell(int(tile.id))
				for field: String in ["id", "text", "mass", "width", "height", "word", "fragments", "composition"]:
					check(retained.get(field) == tile.get(field), "Crowded cancellation preserves " + field)
			_board(model, "crowded reviewed return")
