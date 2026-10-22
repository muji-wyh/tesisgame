extends RefCounted
## Deterministic real-art boards shared by drag regression and CPU diagnostics.

const Data = preload("res://scripts/game_data.gd")
const Model = preload("res://scripts/word_jelly_model.gd")

static func install(view, data, count: int) -> Array[int]:
	var cat: Dictionary = {}
	for word: Dictionary in data.words:
		if str(word.id) == "cat":
			cat = word
	assert(not cat.is_empty())
	assert(view.configure([cat], 3, Data.theme("spring"), data.chests, false, 73021))
	view.set_process(false)
	view.game.spawn_interval = 10000.0
	view.game.cells.clear()
	for index in range(count):
		var tile: Dictionary = view.game._new_word_root(cat) if index % 2 == 0 else view.game._new_picture_tile(cat)
		tile.column = index % Model.COLUMNS
		tile.row = Model.ROWS - 1 - int(index / Model.COLUMNS)
		tile.age = 2.0
		view.game.cells.append(tile)
	view._sync_tiles()
	view._layout()
	return [int(view.game.cells[count - Model.COLUMNS].id), int(view.game.cells[count - Model.COLUMNS + 1].id)]

static func motion(view, point: Vector2, pointer: int = 7) -> void:
	var event := InputEventScreenDrag.new()
	event.index = pointer
	event.position = point
	view._input(event)

static func point(view, pair: Array[int], frame: int, sample: int, bursts: int, contact: bool) -> Vector2:
	var phase: float = (float(frame) + float(sample) / bursts) * 0.08
	var local: Vector2 = view._board.position + Vector2(view._pitch * (1.4 + sin(phase) * 0.8), view._pitch * 0.45)
	if contact:
		var target: Vector2 = view._tiles[pair[1]].get_rect().get_center()
		local = target + Vector2(view._pitch * 0.85 * sin(phase), -view._pitch * 0.65 * (1.0 + cos(phase)))
	return view.get_global_transform() * local
