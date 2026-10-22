extends SceneTree
## Real-renderer layout evidence. Vocabulary and cat media are explicit fixtures.
## Requires -- --output <fresh-directory>; never overwrite consumed evidence.

const Jelly = preload("res://scripts/word_jelly.gd")
const Backdrop = preload("res://scripts/jelly_backdrop.gd")
const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
var output_directory: String = ""
const SIZES: Array[Vector2i] = [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 800)]

var view: Control
var backdrop: Control
var captures: Array[Dictionary] = []
var failures: Array[String] = []
var checks: int = 0
var read_id: int = -1
var wide_state: Dictionary


func _initialize() -> void:
	_run.call_deferred()


func _prepare_output() -> bool:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 2 or arguments[0] != "--output" or not arguments[1].is_absolute_path():
		printerr("Usage: --script res://tools/capture-professional-retail04.gd -- --output <new absolute or res:// directory>")
		return false
	output_directory = ProjectSettings.globalize_path(arguments[1]).simplify_path()
	if not DirAccess.dir_exists_absolute(output_directory.get_base_dir()):
		printerr("The output parent must already exist: " + output_directory.get_base_dir())
		return false
	# Non-recursive directory creation fails if this destination already exists.
	# Do not reuse an empty directory: it may belong to another capture attempt.
	if DirAccess.make_dir_absolute(output_directory) != OK:
		printerr("Could not exclusively create a new output directory: " + output_directory)
		return false
	return true


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)


func _part(id: String, spelling: String, type: String = "root") -> Dictionary:
	return {"id": id, "canonical_id": "fixture:" + spelling, "canonical": spelling, "surface": spelling, "type": type}


func _node(id: String, left: String, right: String, spelling: String, breaks: Array = []) -> Dictionary:
	return {"id": id, "left": left, "right": right, "surface": spelling, "rule": "render-fixture", "break_offsets": breaks}


func _word(cat: Dictionary, spelling: String, parts: Array = [], nodes: Array = [], breaks: Array = []) -> Dictionary:
	var word: Dictionary = cat.duplicate(true)
	word.id = "render-fixture:" + spelling
	word.text = spelling
	if parts.is_empty():
		parts = [_part("whole", spelling, "atomic")]
		parts[0].break_offsets = breaks
	word.morphology = {"schema": 1, "id": spelling, "lexeme_id": word.id, "text": spelling,
		"kind": "atomic" if parts.size() == 1 else "morphological",
		"review": {"status": "reviewed", "reviewer": "automated-render-fixture"},
		"parts": parts, "nodes": nodes, "roots": [parts[0].id] if parts.size() == 1 else [nodes.back().id]}
	return word


func _tile(state: Dictionary, fragments: int = 0) -> Dictionary:
	state = state.duplicate(true)
	state.fragments = fragments
	var tile: Dictionary = view.game._new_composition_tile(state)
	var position: Vector2i = view.game._free_position(view.game._occupied(), int(tile.width), int(tile.height))
	_check(position.x >= 0, "Fixture body has room: " + str(tile.text))
	tile.column = position.x
	tile.row = position.y
	view.game.cells.append(tile)
	return tile


func _board_identity() -> Array:
	var positions: Array = []
	for tile: Dictionary in view.game.cells:
		positions.append([tile.id, tile.column, tile.row, tile.width, tile.height])
	return positions


func _preview(states: Array) -> void:
	view.game.upcoming.clear()
	for lane in range(view.game.COLUMNS):
		view.game.upcoming.append({})
	var column: int = 0
	for state: Dictionary in states:
		var tile: Dictionary = view.game._new_composition_tile(state)
		var span: int = int(tile.width)
		_check(column + span <= view.game.COLUMNS, "Fixture preview fits the well's lanes")
		if column + span > view.game.COLUMNS:
			break
		tile.preview_column = column
		tile.preview_span = span
		view.game.upcoming[column] = tile
		for lane in range(column + 1, column + span):
			view.game.upcoming[lane] = {"reservation": tile.id, "anchor": column}
		column += span
	view._sync_preview()


func _resize(dimensions: Vector2i) -> void:
	root.size = dimensions
	for frame in range(3):
		await process_frame
	view.size = Vector2(dimensions)
	backdrop.size = Vector2(dimensions)
	view._layout()
	view._sync_tiles()
	view._sync_preview()
	for frame in range(3):
		await process_frame
	_check(root.size == dimensions, "Window uses the requested physical dimensions %s" % dimensions)


func _capture(stage: String, dimensions: Vector2i) -> void:
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	var filename: String = "jelly-%dx%d-%s.png" % [dimensions.x, dimensions.y, stage]
	_check(picture.get_size() == dimensions, "Rendered image dimensions match " + filename)
	_check(picture.save_png(output_directory + "/" + filename) == OK, "PNG saved: " + filename)
	var tiles: Array[Dictionary] = []
	for data: Dictionary in view.game.cells:
		var tile: Control = view._tiles[int(data.id)]
		var font_pixels: float = tile._label.get_theme_font_size("font_size") * Style.ui_scale(tile)
		tiles.append({"text": data.text, "kind": data.kind, "parts": data.composition.part_count,
			"width": data.width, "height": data.height, "requires_read": data.requires_read,
			"font_pixels": font_pixels, "lines": data.label_lines,
			"tile_rect": [tile.position.x, tile.position.y, tile.size.x, tile.size.y],
			"surface_rect": [tile._surface.position.x, tile._surface.position.y, tile._surface.size.x, tile._surface.size.y],
			"surface_scale": [tile._surface.scale.x, tile._surface.scale.y],
			"label_rect": [tile._label.position.x, tile._label.position.y, tile._label.size.x, tile._label.size.y],
			"visible_lines": tile._label.get_visible_line_count(), "line_count": tile._label.get_line_count()})
		if stage != "safe-pause":
			_check(font_pixels >= 16.0, "Spelling remains at least 16 physical pixels: " + str(data.text))
			_check(tile._label.get_rect().end.y <= tile.size.y + 0.01, "Label stays inside its measured height: " + str(data.text))
			if data.requires_read:
				_check(not tile._label.get_rect().intersects(tile._read_button.get_rect()), "Read never covers its spelling label")
			if not data.requires_read:
				_check(tile._label.get_visible_line_count() == tile._label.get_line_count(), "All authored lines are visible: " + str(data.text))
	var entry: Dictionary = {"file": filename, "stage": stage, "viewport": [dimensions.x, dimensions.y],
		"paused": view.game.paused, "safe_pause": view._layout_too_small, "tiles": tiles}
	if view._read_panel.visible:
		entry.read = view._read_panel.snapshot()
	captures.append(entry)


func _capture_composition(graph: Dictionary, id: String, leaves: Dictionary) -> Dictionary:
	if leaves.has(id):
		return leaves[id]
	var node: Dictionary = graph.nodes.filter(func(item: Dictionary) -> bool: return item.id == id)[0]
	var left := _capture_composition(graph, node.left, leaves)
	var right := _capture_composition(graph, node.right, leaves)
	var result: Dictionary = view.game._morphology.resolve(left, right)
	_check(result.status in ["partial", "complete"], "Real reviewed composition resolves: " + graph.text)
	if result.status not in ["partial", "complete"]:
		return {}
	_tile(result.tile)
	return result.tile

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("This harness requires the actual renderer; omit --headless.")
		quit(1)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(1280, 800)
	if not _prepare_output():
		quit(1)
		return
	var data := Data.new()
	_check(data.load_all(), "Production layout assets load")
	var cat: Dictionary = data.words.filter(func(word: Dictionary) -> bool: return word.id == "cat")[0]
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/professional/lexemes/retail-module04.json"))
	backdrop = Backdrop.new()
	root.add_child(backdrop)
	backdrop.set_reduced_motion(true)
	for text: String in ["ingredient", "lining", "multipack", "net weight", "demonstration model"]:
		var entry: Dictionary = document.lexemes.filter(func(item: Dictionary) -> bool: return item.text == text)[0]
		var graph: Dictionary = entry.morphology
		var fixture: Dictionary = cat.duplicate(true)
		fixture.id = entry.id
		fixture.text = entry.text
		fixture.morphology = graph.duplicate(true)
		view = Jelly.new()
		root.add_child(view)
		view.set_process(false)
		view.size = Vector2(root.size)
		_check(view.configure([fixture], 3, Data.theme("spring"), data.chests, true, 42), "Real graph configures with explicitly substituted layout media: " + text)
		view.game.cells.clear()
		view.game.spawn_interval = 10000.0
		var leaves: Array = view.game._morphology.source_tiles(graph.id)
		var by_id: Dictionary = {}
		for index in range(leaves.size()):
			by_id[graph.parts[index].id] = leaves[index]
		if graph.kind != "atomic":
			_capture_composition(graph, graph.roots[0], by_id)
		for source: Dictionary in leaves:
			_tile(source)
		_preview([leaves[0]])
		view._sync_tiles()
		view._refresh_controls()
		var identity: Array = _board_identity()
		for dimensions: Vector2i in SIZES:
			await _resize(dimensions)
			_check(not view._layout_too_small, "Playable reference viewport for " + text + ": " + str(dimensions))
			_check(identity == _board_identity(), "Resizing preserves tiles for " + text)
			await _capture(text.replace(" ", "-"), dimensions)
		if text == "demonstration model":
			var tiny_dimensions := Vector2i(180, 220)
			await _resize(tiny_dimensions)
			_check(view._layout_too_small and view.game.paused and view._size_cover.visible, "Tiny viewport presents the safe-pause cover")
			var paused_elapsed: float = view.game.spawn_elapsed
			view.game.step(20.0)
			_check(view.game.spawn_elapsed == paused_elapsed, "Safe pause freezes the automatic drop timer")
			_check(identity == _board_identity(), "Safe pause preserves the complete authored board")
			_check(view.can_finish_round(), "Safe pause retains the option to finish the round")
			await _capture("safe-pause", tiny_dimensions)
		view.free()
	var report: Dictionary = {"capture": "retail04-five-reviewed-graphs", "renderer": RenderingServer.get_video_adapter_name(),
		"fixture_notice": "The twenty-one captures show actual reviewed Retail04 morphology graphs, including a 180x220 safe pause, with existing cat image and audio used solely as layout fixtures. They do not approve Professional word media, live timing, physical-device behavior, or release readiness.",
		"checks": checks, "failures": failures, "captures": captures}
	var file := FileAccess.open(output_directory + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	backdrop.free()
	print("Retail04 renderer: %d checks, %d failures, %d PNG captures" % [checks, failures.size(), captures.size()])
	quit(1 if not failures.is_empty() or captures.size() != 21 else 0)
