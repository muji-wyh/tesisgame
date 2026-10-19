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
		for tile in view._tiles.values():
			check(tile._label.get_theme_font_size("font_size") * Style.ui_scale(tile) >= 16.0, "Authored spelling remains at least 16 displayed pixels")
			check(tile._label.get_rect().end.y <= tile.size.y + 0.01, "Authored label height does not inherit the base tile's larger font")
		var preview_ids: Array = []
		for index in range(view.game.upcoming.size()):
			var item: Dictionary = view.game.upcoming[index]
			var tile = view._preview_tiles[index]
			if not item.has("id"):
				check(not tile.visible and tile.tile_id == -1, "Covered preview lanes never paint an extra Jelly")
			else:
				check(not preview_ids.has(tile.tile_id), "Each wide preview has one visible identity")
				preview_ids.append(tile.tile_id)
				check(is_equal_approx(tile.size.x, int(item.width) * view._pitch - view._gap), "Preview spans its full advertised lane width")
	var cues: Array[String] = []
	view.audio_requested.connect(func(cue: String) -> void: cues.append(cue))
	view.game.drag_blocked.emit("needs_room")
	check(view._room_notice.visible and view.snapshot().drag.needs_room, "A declined authored lift has visible room feedback")
	check(view._room_notice.text == "Make room before moving this jelly." and cues.is_empty(),
		"Room feedback explains the blocked move without treating it as a language error")
	check(view._board.encloses(view._room_notice.get_rect()), "Room feedback stays inside the board")
	check(view._room_notice.get_theme_font_size("font_size") * Style.ui_scale(view) >= 16.0,
		"Room feedback uses readable text")
	for frame in range(5):
		view._process(0.5)
	check(not view._room_notice.visible and _positions(view) == positions, "Room feedback expires without moving the board")
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
	check(view.configure([long_word], 3, Data.theme("spring"), data.chests, true, 44), "An exceptionally long atomic fixture configures")
	view.game.step(3.0)
	view._sync_tiles()
	view._layout()
	var id: int = int(view.game.cells[0].id)
	check(view._tiles[id].requires_read and view._tiles[id]._read_button.visible, "Exceptional spelling exposes an explicit Read action")
	check(not view._tiles[id]._label.get_rect().intersects(view._tiles[id]._read_button.get_rect()), "Read and its spelling preview have separate rectangles")
	check(view._tiles[id].valid_word and view._tiles[id]._picture.visible, "An atomic whole word is presented as complete")
	view._show_read(id)
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
	var phrase: Dictionary = _fixture(cat, "coronary artery bypass graft")
	phrase.morphology.parts[0].break_offsets = [8, 15, 22]
	check(view.configure([phrase], 3, Data.theme("spring"), data.chests, true, 45), "A two-row authored label fixture configures")
	view.game.step(3.0)
	view._sync_tiles()
	for viewport_size: Vector2i in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 800)]:
		root.size = viewport_size
		view.size = Vector2(viewport_size)
		view._layout()
		await process_frame
		for tile in view._tiles.values():
			check(tile._label.get_line_count() == 2 and tile._label.get_visible_line_count() == 2
				and tile._label.get_rect().end.y <= tile.size.y + 0.01,
				"Both authored lines stay inside the measured footprint at %s" % viewport_size)
		for tile in view._preview_tiles:
			if tile.visible:
				check(tile._label.get_line_count() == 2 and tile._label.get_rect().end.y <= tile.size.y + 0.01,
					"The full-width preview keeps both lines inside its footprint")
	view.free()
	print("Word Jelly morphology view: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
