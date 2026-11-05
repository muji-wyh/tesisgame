extends RefCounted
## Actual reviewed Growth states cover authored return projection and crowded hints.

const Data = preload("res://scripts/game_data.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
const Growth = preload("res://scripts/growth_morphology.gd")
const Legacy = preload("res://tests/performance/jelly_drag_fixture.gd")

static func install(view, data, count: int, source_kind: String) -> Array[int]:
	assert(source_kind in ["root", "merged"])
	assert(count >= Model.COLUMNS and count <= Model.CAPACITY)
	var word_id: String = "cat" if source_kind == "root" else "friendly"
	var word: Dictionary = {}
	for candidate: Dictionary in data.words:
		if str(candidate.id) == word_id:
			word = Growth.decorate(candidate)
			break
	assert(word.get("morphology_status") == "reviewed")
	assert(view.configure([word], int(word.min_age), Data.theme("spring"), data.chests, false, 73021))
	view.set_process(false)
	view.game.spawn_interval = 10000.0
	view.game.cells.clear()
	var states: Array = view.game._morphology.source_tiles(str(word.morphology.id))
	assert(states.size() == (1 if source_kind == "root" else 2))
	var merged_state: Dictionary = {}
	if source_kind == "merged":
		# Image-less authored completion naturally retains composition. Picture
		# matches and merged upgrades do not; no synthetic composition is added.
		var resolved: Dictionary = view.game._morphology.resolve(states[0], states[1])
		assert(resolved.status == "complete" and str(resolved.tile.text) == word.text)
		merged_state = resolved.tile
	for index in range(count):
		var tile: Dictionary
		if source_kind == "merged":
			tile = view.game._new_composition_tile(merged_state)
			assert(tile.jelly_kind == "merged" and tile.has("composition"))
		else:
			tile = view.game._new_composition_tile(states[0]) if index % 2 == 0 else view.game._new_picture_tile(word)
		tile.column = index % Model.COLUMNS
		tile.row = Model.ROWS - 1 - int(index / Model.COLUMNS)
		tile.age = 2.0
		view.game.cells.append(tile)
	view._sync_tiles()
	view._layout()
	var source_index: int = count - Model.COLUMNS
	if source_kind == "root" and source_index % 2 != 0:
		source_index += 1
	var pair: Array[int] = [int(view.game.cells[source_index].id), int(view.game.cells[source_index + 1].id)]
	assert(view.game.cell(pair[0]).has("composition"))
	assert(view.game.parts_compatible(view.game.cell(pair[0]), view.game.cell(pair[1])))
	return pair

static func motion(view, point: Vector2, pointer: int = 7) -> void:
	Legacy.motion(view, point, pointer)

static func point(view, pair: Array[int], frame: int, sample: int, bursts: int, contact: bool) -> Vector2:
	return Legacy.point(view, pair, frame, sample, bursts, contact)

static func expected_hint_count(count: int, source_kind: String) -> int:
	return int(count / 2) if source_kind == "root" else count - 1
