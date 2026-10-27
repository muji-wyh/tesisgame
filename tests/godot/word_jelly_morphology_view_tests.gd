extends SceneTree

const Jelly = preload("res://scripts/word_jelly.gd")
const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _fixture(source: Dictionary, spelling: String) -> Dictionary:
	var word: Dictionary = source.duplicate(true)
	word.id = "view-fixture:" + spelling
	word.text = spelling
	word.morphology = {"schema": 1, "id": word.id + ":analysis", "lexeme_id": word.id, "text": spelling,
		"kind": "atomic", "review": {"status": "reviewed", "reviewer": "automated-test-fixture"},
		"parts": [{"id": "whole", "canonical_id": word.id, "type": "atomic", "canonical": spelling,
			"surface": spelling, "break_offsets": []}], "nodes": [], "roots": ["whole"]}
	return word

func _positions(view: Control) -> Array:
	var values: Array = []
	for cell: Dictionary in view.game.cells:
		values.append([cell.id, cell.column, cell.row, cell.width, cell.height])
	return values

func _check_tile(view: Control, tile: Control, cell: Dictionary, context: String) -> void:
	check(int(cell.width) == 1 and int(cell.height) == 1, context + ": every spelling occupies one normal cell")
	check(is_equal_approx(tile.size.x, view._pitch - view._gap) and is_equal_approx(tile.size.y, tile.size.x),
		context + ": the body keeps the ordinary responsive square size")
	check(not tile._read_button.visible, context + ": no Read button covers the square face")
	check(str(tile.get("accessibility_name")).contains(str(cell.text)), context + ": accessibility retains the complete spelling")
	if str(cell.get("jelly_kind", "root")) == "picture":
		check(not tile._label.visible and tile._picture.visible, context + ": picture pieces show the picture alone")
		check(not tile.requires_read and not tile.tooltip_text.contains(str(cell.text)), context + ": picture pieces do not reveal a spelling clue on hover")
	else:
		check(tile.tooltip_text.contains(str(cell.text)), context + ": the tooltip retains the complete spelling")
	if tile._label.visible:
		check(tile._label.get_theme_font_size("font_size") * Style.ui_scale(tile) >= 13.0,
			context + ": visible spelling stays at least 13 displayed pixels")
		check(Rect2(Vector2.ZERO, tile.size).grow(0.1).encloses(tile._label.get_rect()), context + ": the label stays inside its own square")
		check(tile._label.get_visible_line_count() >= tile._label.get_line_count(), context + ": visible lines fit vertically")
		if tile._picture.visible:
			check(not tile._label.get_rect().intersects(tile._picture.get_rect()), context + ": picture and caption do not overlap")
	if tile.valid_word and not str(cell.get("image_word", {}).get("image", "")).is_empty():
		check(tile._picture.visible, context + ": a completed word retains its picture")
	if tile.valid_word:
		check(tile.presentation_snapshot().merged_light, context + ": a merged word has a permanent readiness glow")

func _hold(view: Control, id: int, pointer: int) -> void:
	var point: Vector2 = view._tiles[id].get_global_rect().get_center()
	var before: Array = _positions(view)
	var score: int = view.game.cleared_pairs
	check(view._press(pointer, point), "A stationary Read gesture accepts its board tile")
	view._process(0.20)
	check(not view._read_panel.visible, "A short press does not open Read")
	view._process(0.30)
	check(view._read_panel.visible and view.game.paused, "A 450 ms stationary hold opens paused Read")
	check(view._read_panel.snapshot().text == view.game.cell(id).text, "Holding shows the complete spelling")
	view._release(point)
	check(view.game.cleared_pairs == score and _positions(view) == before and view.game.fusions.is_empty(),
		"Releasing a Read hold cannot collect the word or change the board")
	view._close_read()
	check(not view.game.paused and not view._read_panel.visible, "Closing Read resumes the same round")

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1280, 800)
	var data := Data.new()
	check(data.load_all(), "Production assets load for the rendered-node fixture")
	var cat: Dictionary = {}
	for word: Dictionary in data.words:
		if word.id == "cat":
			cat = word
	var view := Jelly.new()
	root.add_child(view)
	view.set_process(false)
	view.size = Vector2(1280, 800)
	check(view.configure([_fixture(cat, "MRI")], 3, Data.theme("spring"), data.chests, true, 42), "An authored atomic round configures")
	view.game.spawn_interval = 10000.0
	view.game.step(3.0)
	view._sync_tiles()
	view._sync_preview()
	var positions: Array = _positions(view)
	for viewport_size: Vector2i in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 800)]:
		root.size = viewport_size
		view.size = Vector2(viewport_size)
		view._layout()
		await process_frame
		check(not view._layout_too_small, "The reference layout fits %s" % viewport_size)
		check(_positions(view) == positions, "Resize preserves identities, grid positions and footprints at %s" % viewport_size)
		check(view.game.COLUMNS == 5 and view.game.ROWS == 8, "The five-by-eight well retains ordinary square bodies")
		for cell: Dictionary in view.game.cells:
			_check_tile(view, view._tiles[int(cell.id)], cell, str(viewport_size))
		var preview_ids: Array = []
		for index in range(view.game.upcoming.size()):
			var item: Dictionary = view.game.upcoming[index]
			var tile = view._preview_tiles[index]
			if not item.has("id"):
				check(not tile.visible and tile.tile_id == -1, "Covered preview lanes never paint an extra Jelly")
			else:
				check(not preview_ids.has(tile.tile_id), "Each preview has one visible identity")
				preview_ids.append(tile.tile_id)
				_check_tile(view, tile, item, "Preview at " + str(viewport_size))
	var cues: Array[String] = []
	view.audio_requested.connect(func(cue: String) -> void: cues.append(cue))
	view.game.drag_blocked.emit("needs_room")
	check(not view.snapshot().drag.needs_room and cues == ["contact"],
		"A declined lift gives a small material response, not a misleading language error or giant notice")
	for frame in range(5):
		view._process(0.5)
	check(not view.snapshot().drag.needs_room and _positions(view) == positions,
		"A blocked gesture never opens a persistent notice or moves the board")
	view.size = Vector2(180, 220)
	view._layout()
	check(view._layout_too_small and view.game.paused and view._size_cover.visible, "An undersized viewport safely pauses instead of shrinking labels")
	var clock: float = view.game.spawn_elapsed
	view.game.step(2.0)
	check(view.game.spawn_elapsed == clock and _positions(view) == positions, "Layout pause preserves the schedule and board")
	view.pause(true)
	view.size = Vector2(1280, 800)
	view._layout()
	check(not view._layout_too_small and view.game.paused, "Restoring size does not override another pause reason")
	view.pause(false)
	check(not view.game.paused, "Play resumes after all pause reasons clear")
	var long_word: Dictionary = _fixture(cat, "fixtureindivisiblespellingthatcannotfitwithoutbeingread")
	long_word.image = ""
	check(view.configure([long_word], 3, Data.theme("spring"), data.chests, true, 44), "An exceptionally long atomic fixture configures")
	view.game.spawn_interval = 10000.0
	view.game.step(3.0)
	view._sync_tiles()
	view._layout()
	var id: int = int(view.game.cells[0].id)
	check(view._tiles[id].requires_read and not view._tiles[id]._read_button.visible, "Exceptional spelling offers Read without covering the face")
	for item: Dictionary in view.snapshot().tiles:
		check(bool(item.read_available) == bool(view._tiles[int(item.id)].requires_read), "Read availability describes actual layout overflow")
	check(view._tiles[id].valid_word and not view._tiles[id]._picture.visible, "An atomic word without a picture is immediately merged")
	_hold(view, id, -1)
	_hold(view, id, 7)
	view._tiles[id].grab_focus()
	var read_key := InputEventKey.new()
	read_key.keycode = KEY_R
	read_key.pressed = true
	view._input(read_key)
	check(view.game.paused and view._read_panel.visible, "Read pauses play")
	check(view._read_panel.snapshot().text == long_word.text and view._read_panel.snapshot().font_pixels >= 16.0, "Read preserves the full spelling at a readable size")
	clock = view.game.spawn_elapsed
	view.game.step(2.0)
	check(view.game.spawn_elapsed == clock, "Reading does not advance the supply timer")
	view.pause(true)
	view._close_read()
	check(view.game.paused and not view._read_panel.visible, "Closing Read preserves an external pause")
	view.pause(false)
	check(not view.game.paused, "Closing the final pause resumes the same round")
	var point: Vector2 = view._tiles[id].get_global_rect().get_center()
	check(view._press(-1, point), "A potential drag starts on the whole word")
	view._process(0.20)
	view._move(point + Vector2(10.0 / Style.ui_scale(view), 0.0))
	view._process(0.40)
	check(not view._read_panel.visible and not view.game.paused, "Movement beyond seven pixels cancels the Read hold")
	view.cancel_input()
	view.game.step(2.0)
	view._sync_tiles()
	view._sync_preview()
	var preview: Control = view._preview_tiles[0]
	check(preview.requires_read and not preview.disabled and preview.focus_mode == Control.FOCUS_ALL,
		"A newly supplied long preview is keyboard-readable without querying navigation controls")
	preview.grab_focus()
	point = preview.get_global_rect().get_center()
	var generated: int = view.game.generated_tiles
	check(view._press(9, point), "A preview tile accepts a stationary hold")
	view._process(0.50)
	check(view._read_panel.visible and view._read_panel.snapshot().text == long_word.text, "Holding a preview opens its full spelling")
	for tile: Control in view._preview_tiles:
		check(tile.disabled and tile.focus_mode == Control.FOCUS_NONE, "Preview controls cannot receive focus behind Read")
	view._release(point)
	check(view.game.generated_tiles == generated, "Releasing a preview Read hold does not dispatch supply")
	view._close_read()
	check(not preview.disabled and preview.focus_mode == Control.FOCUS_ALL and root.gui_get_focus_owner() == preview,
		"Closing preview Read restores focus to the same readable preview")
	id = int(view.game.cells[0].id)
	point = view._tiles[id].get_global_rect().get_center()
	var cleared: int = view.game.cleared_pairs
	check(view._press(-1, point), "Quick collection still accepts the completed word")
	view._process(0.05)
	view._release(point)
	check(not view._read_panel.visible and not view.game.fusions.is_empty(), "A quick tap collects without opening Read")
	view.game.step(1.0)
	check(view.game.cleared_pairs == cleared + 1 and view.game.cell(id).is_empty(), "Quick collection commits exactly once")
	var compact_word: Dictionary = _fixture(cat, "rainbow")
	compact_word.image = ""
	check(view.configure([compact_word], 3, Data.theme("spring"), data.chests, true, 46),
		"A spelling near the compact reading limit configures")
	view.game.spawn_interval = 10000.0
	view.game.step(3.0)
	view._sync_tiles()
	for viewport_size: Vector2i in [Vector2i(1280, 800), Vector2i(320, 568), Vector2i(1280, 800)]:
		root.size = viewport_size
		view.size = Vector2(viewport_size)
		view._layout()
		await process_frame
		preview = view._preview_tiles[0]
		var overflow: bool = viewport_size.x == 320
		check(preview.requires_read == overflow, "Resizing crosses the preview spelling's reading limit at %s" % viewport_size)
		check(preview.disabled == (not overflow) and preview.focus_mode == (Control.FOCUS_ALL if overflow else Control.FOCUS_NONE),
			"Resize immediately refreshes preview keyboard eligibility without a navigation query")
	var phrase: Dictionary = _fixture(cat, "coronary artery bypass graft")
	phrase.image = ""
	phrase.morphology.parts[0].break_offsets = [8, 15, 22]
	check(view.configure([phrase], 3, Data.theme("spring"), data.chests, true, 45), "A long authored phrase configures")
	view.game.spawn_interval = 10000.0
	view.game.step(3.0)
	view._sync_tiles()
	for viewport_size: Vector2i in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 800)]:
		root.size = viewport_size
		view.size = Vector2(viewport_size)
		view._layout()
		await process_frame
		for cell: Dictionary in view.game.cells:
			var tile: Control = view._tiles[int(cell.id)]
			_check_tile(view, tile, cell, "Long phrase at " + str(viewport_size))
			check(tile.requires_read, "A long phrase remains available in Read without widening its square")
		for index in range(view.game.upcoming.size()):
			if view.game.upcoming[index].has("id"):
				_check_tile(view, view._preview_tiles[index], view.game.upcoming[index], "Long phrase preview")
	view.free()
	print("Word Jelly morphology view: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
