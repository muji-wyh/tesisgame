extends RefCounted
## Benchmark-only seeded boards. The real view, model, artwork and clocks run normally.

const Data = preload("res://scripts/game_data.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
const GrowthMorphology = preload("res://scripts/growth_morphology.gd")
const COLLECT_WORDS := ["cat", "dog", "sun", "ball", "car", "apple", "fish", "duck", "cow"]

static func install(app, composition: String, seed_value: int) -> Array[int]:
	if composition not in ["ordinary", "merged", "mixed-merged"]:
		push_error("Unknown full-board benchmark composition.")
		return []
	var available: Dictionary = {}
	for candidate: Dictionary in app.data.words:
		available[str(candidate.id)] = candidate
	var cohort: Array[Dictionary] = []
	var requested: Array = COLLECT_WORDS if composition == "mixed-merged" else ["cat"]
	for word_id: String in requested:
		if not available.has(word_id) or int(available[word_id].get("min_age", -1)) != 3:
			push_error("The full-board benchmark requires the production Age 3 word: " + word_id)
			return []
		var selected: Dictionary = GrowthMorphology.decorate(available[word_id])
		if selected.get("morphology_status", "") != "reviewed":
			push_error("The full-board benchmark requires reviewed production morphology: " + word_id)
			return []
		var image_path: String = str(selected.get("image", ""))
		if image_path.is_empty() or not ResourceLoader.exists("res://" + image_path):
			push_error("The full-board benchmark requires a mounted production picture: " + word_id)
			return []
		cohort.append(selected)
	var view = app._word_jelly
	# Release exports remove assert expressions entirely. Required initialization
	# and validation must execute independently of debug assertions.
	if not view.configure(cohort, 3, Data.theme("spring"), app.data.chests, false, seed_value):
		push_error("The full-board benchmark could not configure the production word cohort: " + view.game.error)
		return []
	# The fixture owns an unbound game page; no map or curriculum transition runs.
	app._word_jelly_stages = null
	view.game.cells.clear()
	for index in range(Model.CAPACITY):
		# Word identities and levels are distributed independently, using mounted
		# production pictures. No new art or artificial texture is introduced.
		var selected: Dictionary = cohort[(index * 5 + int(index / Model.MAX_MERGE_LEVEL)) % cohort.size()]
		var tile: Dictionary
		if composition == "ordinary" and index % 2 != 0:
			tile = view.game._new_picture_tile(selected, 1)
		elif composition == "ordinary":
			# Use the same reviewed source-state and tile constructor as the real
			# Growth supply. Cat has one complete atomic spelling source.
			var sources: Array = view.game._morphology.source_tiles(str(view.game._authored_words.get(selected.id, "")))
			if sources.size() != 1:
				push_error("The ordinary full-board benchmark requires one atomic production root.")
				return []
			var state: Dictionary = sources[0].duplicate(true)
			state.fragments = 1
			tile = view.game._new_composition_tile(state)
		else:
			tile = view.game._new_word_root(selected, 1)
		if composition != "ordinary":
			view.game._set_merged_word(tile, selected, index % Model.MAX_MERGE_LEVEL + 1, composition == "mixed-merged")
		tile.column = index % Model.COLUMNS
		tile.row = Model.ROWS - 1 - int(index / Model.COLUMNS)
		tile.age = 2.0
		view.game.cells.append(tile)
	view.game.merged_count = Model.CAPACITY if composition != "ordinary" else 0
	var pair: Array[int] = [int(view.game.cells[Model.CAPACITY - Model.COLUMNS].id),
		int(view.game.cells[Model.CAPACITY - Model.COLUMNS + 1].id)]
	if composition == "ordinary" and not view.game.can_merge(view.game.cell(pair[0]), view.game.cell(pair[1])):
		push_error("The ordinary full-board benchmark pair must be a real legal production merge.")
		return []
	view._sync_tiles()
	app._refresh()
	app._layout()
	view._publish()
	return pair

static func pointer(view, kind: String, point: Vector2) -> void:
	if kind == "move":
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		view._input(motion)
	else:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.position = point
		button.pressed = kind == "press"
		view._input(button)
