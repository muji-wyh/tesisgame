extends SceneTree
## Feedback keeps exact merge decisions while sharing a conservative space proof.

const Model = preload("res://scripts/word_jelly_model.gd")
const View = preload("res://scripts/word_jelly.gd")

class ObservedModel extends "res://scripts/word_jelly_model.gd":
	var exact_checks: int = 0
	var availability_queries: int = 0
	func can_merge(left: Dictionary, right: Dictionary) -> bool:
		exact_checks += 1
		return super.can_merge(left, right)
	func can_activate_powerup(kind: String) -> bool:
		availability_queries += 1
		return super.can_activate_powerup(kind)

var checks: int = 0
var failures: int = 0
var cat: Dictionary = {"id": "cat", "text": "cat", "min_age": 3,
	"image": "res://assets/images/ui/modes/cat.webp", "audio": "fixture:cat"}
var dog: Dictionary = {"id": "dog", "text": "dog", "min_age": 3,
	"image": "res://assets/images/ui/modes/dog.webp", "audio": "fixture:dog"}

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _board(model: ObservedModel, count: int) -> void:
	model.cells.clear()
	model.fusions.clear()
	model.boss._statuses.clear()
	model._dragged_tile_id = -1
	model._held_tile_id = -1
	for index in range(count):
		var tile: Dictionary = model._new_word_root(cat) if index % 2 == 0 else model._new_picture_tile(cat)
		tile.merge({"column": index % Model.COLUMNS, "row": int(index / Model.COLUMNS), "age": 100.0}, true)
		model.cells.append(tile)

func _oracle(view: View, source: Dictionary, target: Dictionary, message: String) -> void:
	var expected: bool = view.game.can_merge(source, target)
	var before: int = view.game.exact_checks
	var proven: bool = view._feedback_space_guaranteed(int(source.id), int(target.id))
	check(view._can_merge_for_feedback(source, target) == expected, message)
	if proven:
		check(view.game.exact_checks == before, "A proven free cell avoids the exact occupancy search")

func _run() -> void:
	var model := ObservedModel.new()
	check(model.configure([cat, dog], 3, 1721), "Use pictured word identities for feedback decisions")
	var view := View.new()
	root.add_child(view)
	view.set_process(false)
	view.game = model
	_board(model, 49)
	view._begin_view_update()
	check(not view._view_space_known, "A new presentation builds no unused occupancy bound")
	for target: Dictionary in model.cells:
		_oracle(view, model.cells[0], target, "Crowded feedback matches the model's exact merge decision")
	view._end_view_update()
	check(not view._view_space_known and view._view_space_cells.is_empty(),
		"Feedback occupancy data cannot survive its presentation pass")
	model.exact_checks = 0
	view._can_merge_for_feedback(model.cells[0], model.cells[1])
	check(model.exact_checks == 1, "Queries outside a shared presentation still use exact model validation")
	# A fusion's future footprint remains occupied when its ID matches an input.
	_board(model, 2)
	model.fusions.append({"operation": "merge", "a_id": -1000, "b_id": -1001, "result": {"id": model.cells[0].id,
		"column": 0, "row": 0, "width": 7, "height": 8}})
	view._begin_view_update()
	check(not view._feedback_space_guaranteed(int(model.cells[0].id), int(model.cells[1].id)),
		"A full-board result reservation never disappears with an excluded cell")
	_oracle(view, model.cells[0], model.cells[1], "Full-board reservations retain the exact no-room result")
	view._end_view_update()
	# Overlapping reservations deliberately overestimate area, then fall back.
	model.fusions.append(model.fusions[0].duplicate(true))
	view._begin_view_update()
	_oracle(view, model.cells[0], model.cells[1], "Overlapping fusion reservations remain conservative")
	view._end_view_update()
	_board(model, 56)
	view._begin_view_update()
	_oracle(view, model.cells[0], model.cells[1], "Excluding actual inputs frees space on a completely full board")
	view._end_view_update()
	model.cells[0].lifted = true
	model._dragged_tile_id = int(model.cells[0].id)
	view._begin_view_update()
	_oracle(view, model.cells[0], model.cells[1], "The dragged source does not reserve its excluded return footprint")
	view._end_view_update()
	model.boss._statuses[int(model.cells[1].id)] = {"freeze": 3.0}
	view._begin_view_update()
	_oracle(view, model.cells[0], model.cells[1], "A guaranteed destination never bypasses a frozen target")
	view._end_view_update()
	# Mixed dimensions, off-grid geometry, falls, held bodies and reservations
	# exercise the proof against the existing solver without changing live cells.
	var rng := RandomNumberGenerator.new()
	rng.seed = 925137
	for scenario in range(120):
		_board(model, rng.randi_range(3, 24))
		for tile: Dictionary in model.cells:
			tile.column = rng.randi_range(-2, 8)
			tile.row = rng.randi_range(-2, 9)
			tile.width = rng.randi_range(1, 4)
			tile.height = rng.randi_range(1, 3)
			tile.lifted = rng.randf() < 0.12
			tile.falling = rng.randf() < 0.20
			tile.age = 0.1 if tile.falling else 100.0
		for reservation in range(rng.randi_range(0, 3)):
			model.fusions.append({"operation": "merge" if reservation % 2 == 0 else "collect", "a_id": -1000, "b_id": -1001,
				"result": {"id": model.cells[0].id, "column": rng.randi_range(-2, 6),
				"row": rng.randi_range(-2, 7), "width": rng.randi_range(1, 8), "height": rng.randi_range(1, 8)}})
		if scenario % 3 != 0:
			var anchor: Dictionary = model.cells[0 if scenario % 3 == 1 else 2]
			anchor.lifted = true
			if scenario % 4 == 0:
				anchor.composition = {}
			model._dragged_tile_id = int(anchor.id)
		var original: Array = model.cells.duplicate(true)
		view._begin_view_update()
		for target in range(1, mini(model.cells.size(), 7)):
			_oracle(view, model.cells[0], model.cells[target], "Mixed geometry feedback equals the exact solver")
		view._end_view_update()
		check(model.cells == original, "Read-only feedback never changes falling or held bodies")
	_board(model, 2)
	view._configured = true
	model.availability_queries = 0
	view._refresh_controls()
	check(model.availability_queries == 0, "An unrequested control refresh never plans toolbar or goal merges")
	view._refresh_goal_buttons()
	check(model.availability_queries == 0, "A standalone unrequested goal refresh does not search for a merge")
	view.free()
	print("Word Jelly feedback space: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
