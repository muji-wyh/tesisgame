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
	for field: String in ["id", "text", "mass", "width", "height", "word", "fragments", "composition"]:
		check(lower[field] == original_lower[field], "Cancellation preserves authored " + field)
	_board(model, "reviewed lower support")
	_test_fragmented_return(words)
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


func _test_fragmented_return(words: Array) -> void:
	var model := Model.new()
	check(model.configure(words, 3, 42), "The fragmented-space regression uses the reviewed Growth cohort")
	model.spawn_interval = 10000.0
	model.cells.clear()
	var source: Dictionary = _cat(model, 0, 7)
	model.cells.append_array([source, _cat(model, 1, 6)])
	_fill_fixture(model)
	_board(model, "fragmented-space starting board")
	var blocked: Array[String] = []
	model.drag_blocked.connect(func(reason: String) -> void: blocked.append(reason))
	model.set_held_tile(int(source.id))
	var before: Array = model.cells.duplicate(true)
	check(not model.begin_drag(int(source.id)), "A lift is declined when its fixed return footprint would fragment")
	check(model.cells == before and model._dragged_tile_id == -1,
		"Declining the lift does not move, resize, delete, or lift any body")
	check(blocked == ["needs_room"], "A blocked lift explains the lack of room without a wrong-answer cue")
	model.set_held_tile(-1)
	model.step(0.5)
	check(model.cells.size() == before.size(), "Releasing a declined lift retains every body")
	_board(model, "fragmented-space declined lift")


func _test_arrival_preserves_return(words: Array) -> void:
	var model := Model.new()
	check(model.configure(words, 3, 42), "The incoming-body regression uses the reviewed Growth cohort")
	model.spawn_interval = 10000.0
	model.cells.clear()
	var source: Dictionary = _cat(model, 0, 7)
	model.cells.append_array([source, _cat(model, 2, 6)])
	var empty: Array[Vector2i] = []
	for row in range(7):
		empty.append_array([Vector2i(0, row), Vector2i(1, row)])
	_fill_fixture(model, empty)
	_board(model, "incoming-body starting board")
	model.set_held_tile(int(source.id))
	check(model.begin_drag(int(source.id)), "A bridge with separate support leaves a safe full-size return")
	model.step(0.5)
	var incoming: Dictionary = model._new_tile("fixture", 1, 0)
	model.upcoming.assign([incoming, {}, {}, {}, {}, {}])
	var original_preview: Array = model.upcoming.duplicate(true)
	var before: Array = model.cells.duplicate(true)
	check(not model.can_drop_now(), "The preview control does not advertise an unsafe incoming drop")
	check(not model._spawn_tile(true, 0), "An arrival cannot fall through the only fixed-size return footprint")
	check(model.cells == before and model.upcoming == original_preview,
		"A blocked arrival keeps its advertised identity and all existing bodies")
	model.set_held_tile(-1)
	model.step(0.5)
	check(model._dragged_tile_id == -1 and model._held_tile_id == -1, "The reserved full-size body can still be released")
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
