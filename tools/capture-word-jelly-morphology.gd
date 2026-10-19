extends SceneTree
## Real-renderer layout evidence. Vocabulary and cat media are explicit fixtures.

const Jelly = preload("res://scripts/word_jelly.gd")
const Backdrop = preload("res://scripts/jelly_backdrop.gd")
const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const OUTPUT: String = "res://build/professional-english"
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
	for lane in range(6):
		view.game.upcoming.append({})
	var column: int = 0
	for state: Dictionary in states:
		var tile: Dictionary = view.game._new_composition_tile(state)
		var span: int = int(tile.width)
		_check(column + span <= 6, "Fixture preview fits its six lanes")
		if column + span > 6:
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
	_check(picture.save_png(OUTPUT + "/" + filename) == OK, "PNG saved: " + filename)
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


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("This harness requires the actual renderer; omit --headless.")
		quit(1)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var data := Data.new()
	_check(data.load_all(), "Production layout assets load")
	var cat: Dictionary = {}
	for word: Dictionary in data.words:
		if word.id == "cat":
			cat = word
	var authored: Dictionary = _word(cat, "unhelpful", [_part("un", "un-", "prefix"), _part("help", "help"), _part("ful", "-ful", "suffix")],
		[_node("helpful", "help", "ful", "helpful", [4]), _node("whole", "un", "helpful", "unhelpful", [2, 6])])
	var wide: Dictionary = _word(cat, "coronary artery bypass graft", [], [], [8, 15, 22])
	var long_word: Dictionary = _word(cat, "fixtureindivisiblespellingthatcannotfitwithoutbeingread")
	var atomic: Dictionary = _word(cat, "MRI")
	backdrop = Backdrop.new()
	root.add_child(backdrop)
	backdrop.set_reduced_motion(true)
	view = Jelly.new()
	root.add_child(view)
	view.set_process(false)
	view.size = Vector2(root.size)
	_check(view.configure([authored, wide, long_word, atomic], 3, Data.theme("spring"), data.chests, true, 42), "Authored renderer fixtures configure")
	view.game.cells.clear()
	view.game.spawn_interval = 10000.0
	var parts: Array = view.game._morphology.source_tiles("unhelpful")
	var partial: Dictionary = view.game._morphology.resolve(parts[1], parts[2]).tile
	var complete: Dictionary = view.game._morphology.resolve(parts[0], partial).tile
	wide_state = view.game._morphology.source_tiles(str(wide.text))[0]
	read_id = int(_tile(view.game._morphology.source_tiles(str(long_word.text))[0], 2).id)
	_tile(wide_state, 1)
	_tile(complete, 3)
	_tile(partial)
	for part: Dictionary in parts:
		_tile(part)
	_tile(view.game._morphology.source_tiles("MRI")[0])
	_preview([partial, parts[0]])
	view._sync_tiles()
	view._refresh_controls()
	var identity: Array = _board_identity()
	for dimensions: Vector2i in SIZES:
		await _resize(dimensions)
		_check(not view._layout_too_small, "Playable reference viewport " + str(dimensions))
		_check(identity == _board_identity(), "Resizing keeps physical identities and footprints")
		await _capture("board", dimensions)
		view._show_read(read_id)
		_check(view.game.paused and view._read_panel.visible, "Read pauses play at " + str(dimensions))
		var elapsed: float = view.game.spawn_elapsed
		view.game.step(20.0)
		_check(view.game.spawn_elapsed == elapsed, "Read freezes the round clock")
		await _capture("read-start", dimensions)
		view._read_panel._scroll.scroll_horizontal = 10000
		await process_frame
		_check(view._read_panel._scroll.scroll_horizontal > 0, "Read reveals the end through real horizontal scrolling")
		await _capture("read-end", dimensions)
		view._close_read()
		_check(not view.game.paused and identity == _board_identity(), "Closing Read restores the same board")
		_preview([wide_state])
		await _capture("wide-preview", dimensions)
		_preview([partial, parts[0]])
	await _resize(Vector2i(180, 220))
	_check(view._layout_too_small and view.game.paused and view._size_cover.visible, "Undersized view pauses with readable explanation")
	var elapsed: float = view.game.spawn_elapsed
	view.game.step(20.0)
	_check(view.game.spawn_elapsed == elapsed and identity == _board_identity(), "Safe pause preserves timer, identities, and footprints")
	await _capture("safe-pause", Vector2i(180, 220))
	var report: Dictionary = {"capture": "word-jelly-authored-morphology", "renderer": RenderingServer.get_video_adapter_name(),
		"fixture_notice": "Automated spelling/layout fixtures use the existing cat image and audio. These captures do not establish Professional curriculum media readiness or editorial approval.",
		"checks": checks, "failures": failures, "captures": captures}
	var file := FileAccess.open(OUTPUT + "/jelly-render-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("Authored Jelly renderer: %d checks, %d failures, %d PNG captures" % [checks, failures.size(), captures.size()])
	view.free()
	backdrop.free()
	quit(1 if not failures.is_empty() else 0)
