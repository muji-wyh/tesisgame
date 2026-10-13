extends SceneTree

const Jelly = preload("res://scripts/word_jelly.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const LAYOUT_SIZES: Array[Vector2] = [Vector2(1473, 1175), Vector2(1000, 720), Vector2(768, 1024),
	Vector2(390, 844), Vector2(390, 700), Vector2(568, 320), Vector2(568, 260), Vector2(320, 480), Vector2(320, 320)]

var checks: int = 0
var failures: int = 0
var data = Data.new()
var words: Array = []
var heard: Array[Dictionary] = []
var cues: Array[String] = []
var payouts: Array[Dictionary] = []
var attempts: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1000, 720)
	check(data.load_all(), "view tests use the production vocabulary and chest artwork")
	var cat: Dictionary = {}
	for word: Dictionary in data.words:
		if str(word.id) == "cat":
			cat = word.duplicate(true)
	check(not cat.is_empty(), "cat has production picture and audio")
	var larger: Dictionary = cat.duplicate(true)
	larger.id = "view-fixture-caterpillar"
	larger.text = "caterpillar"
	larger.min_age = 3
	words = [cat, larger]
	var view := Jelly.new()
	root.add_child(view)
	view.set_process(false)
	view.size = Vector2(1000, 720)
	view._layout()
	check(not view.snapshot().visible and view.game.phase == "finished", "unconfigured view can enter and lay out safely")
	view.word_requested.connect(func(word: Dictionary) -> void: heard.append(word))
	view.audio_requested.connect(func(cue: String) -> void: cues.append(cue))
	view.collected.connect(func(id: String, word: Dictionary, amount: int, fragments: int, origin: Vector2) -> void:
		payouts.append({"id": id, "word": word, "amount": amount, "fragments": fragments, "origin": origin}))
	view.word_attempted.connect(func(id: String, ids: Array[String], correct: bool) -> void:
		attempts.append({"id": id, "words": ids, "correct": correct}))
	_check_opening_and_bounds(view)
	_check_paused_resize(view)
	_check_root_tap(view)
	_check_edge_drag(view)
	_check_reposition_release(view)
	_check_reposition_rejection(view)
	_check_reposition_lifecycle(view)
	_check_reposition_ancestry(view)
	_check_merge_handover_stability(view)
	_check_collect_and_fragments(view)
	_check_collect_button_growth(view)
	_check_batch_collection(view)
	_check_batch_chest_queue(view)
	_check_batch_lifecycle(view)
	_check_batch_wallet_failure(view)
	_check_word_reveal(view)
	_check_word_reveal_lifecycle(view)
	_check_collection_stack_fall(view)
	_check_release_after_support_collection(view)
	_check_coarse_frame_collection_landing(view)
	_check_word_pair_colors(view)
	_check_partial_word_colors(view)
	_check_fusion_palette_handover(view)
	_check_crowded_palette_separation(view)
	_check_split_pointer_recovery(view)
	_check_split_cancel_and_pause(view)
	_check_split_keyboard_and_nested_merge(view)
	_check_split_keyboard_source_shortcut(view)
	_check_repeat_merge_and_wrap(view)
	_check_variable_outline(view)
	_check_cancel_and_pause(view)
	_check_reduced_motion(view)
	_check_wallet_failure(view)
	_check_keyboard(view)
	_check_arrival_packet(view)
	_check_staggered_preview_refill(view)
	_check_arrival_land_timing(view)
	_check_danger_ends_when_collecting(view)
	_check_danger_ends_when_merge_frees_space(view)
	view.free()
	await process_frame
	print("Word Jelly view: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _reset(view, reduced: bool = false) -> void:
	check(view.configure(words, 3, Data.theme("spring"), data.chests, reduced, 42), "Word Jelly configures with real art")
	view.set_process(false)
	view.game.spawn_interval = 10000.0
	view.credit_collection = func(_id: String, _amount: int) -> Dictionary: return {"ok": true}
	view._layout()
	heard.clear()
	cues.clear()
	payouts.clear()
	attempts.clear()


func _install(view, pieces: Array[String], fragments: Array[int] = [], masses: Array[int] = []) -> Array[int]:
	view.game.cells.clear()
	var ids: Array[int] = []
	for index in range(pieces.size()):
		var tile: Dictionary = view.game._new_tile(pieces[index], masses[index] if index < masses.size() else 1,
			fragments[index] if index < fragments.size() else 0)
		tile.column = 0 if index == 0 else 4
		tile.row = 6 if index == 0 else 3
		tile.column = mini(int(tile.column), Model.COLUMNS - int(tile.width))
		tile.row = mini(int(tile.row), Model.ROWS - int(tile.height))
		view.game.cells.append(tile)
		ids.append(int(tile.id))
	view._sync_tiles()
	view._layout()
	return ids


func _center(view, id: int) -> Vector2:
	return view._tiles[id].get_global_rect().get_center()


func _advance(view, seconds: float) -> void:
	var remaining: float = seconds
	while remaining > 0.000001:
		var delta: float = minf(0.025, remaining)
		view._process(delta)
		remaining -= delta


func _drag(view, source: int, target: int) -> void:
	var destination: Vector2 = _center(view, target)
	var accepted: bool = view._press(-1, _center(view, source))
	check(accepted, "pointer can pick up an available jelly")
	view._move(destination)
	view._release(destination)


func _merged_id(view) -> int:
	return int(view.game.fusions[0].result.id) if not view.game.fusions.is_empty() else -1


func _check_opening_and_bounds(view) -> void:
	for dimensions: Vector2 in LAYOUT_SIZES:
		view.size = dimensions
		_reset(view)
		var state: Dictionary = view.snapshot()
		check(state.columns == 6 and state.rows == 8 and state.tiles.size() == 18, "opening contains three full rows of six settled roots")
		check(state.preview.slots.size() == 6 and state.preview.enabled, "six upcoming roots have a working manual drop")
		check(view._preview_rect.end.y <= view._board.position.y,
			"the whole supply tray sits above the well in portrait and landscape")
		for index in range(1, view._preview_tiles.size()):
			check(is_equal_approx(view._preview_tiles[index].position.y, view._preview_tiles[0].position.y)
				and view._preview_tiles[index].position.x > view._preview_tiles[index - 1].position.x,
				"all six upcoming bodies form one horizontal row above the well")
		check(view._board.position.x >= 0 and view._board.position.y >= 0 and view._board.end.x <= dimensions.x + 0.1
			and view._board.end.y <= dimensions.y + 0.1, "board fits portrait and landscape bounds")
		var s: float = Style.ui_scale(view)
		var bottom: float = view._board.end.y if view._compact_hud else view.finish_button.get_rect().end.y
		check(is_equal_approx(bottom, dimensions.y - 12.0 / s),
			"game group at %s ends above twelve-pixel padding: actual %.3f, expected %.3f" % [dimensions, bottom, dimensions.y - 12.0 / s])
		check(view._preview_rect.position.y >= 0 and view.finish_button.get_rect().end.y <= dimensions.y,
			"bottom alignment preserves room for the complete preview and finish control")
		for tile: Dictionary in state.tiles:
			check(tile.settled and tile.visible and not tile.picture_visible, "opening root shows text without a word picture")
			check(view._tiles[int(tile.id)]._label.text == tile.text, "root label matches its part")
			check(view._board.encloses(view._tile_rect(tile)), "root rectangle stays inside the well")
			for neighbor: Dictionary in state.tiles:
				if int(neighbor.row) != int(tile.row) or int(neighbor.column) != int(tile.column) + 1:
					continue
				var left: Rect2 = view._tile_rect(tile)
				var right: Rect2 = view._tile_rect(neighbor)
				check(right.position.x - left.end.x >= view._pitch * 0.08,
					"neighboring roots leave a visible gap instead of reading as one connected word")
				var between := Vector2((left.end.x + right.position.x) * 0.5, left.get_center().y)
				check(not view._press(-1, view.get_global_transform() * between),
					"pressing the clear gap cannot accidentally pick up either neighboring root")
		for tile in view._preview_tiles:
			check(tile.visible and view._preview_rect.encloses(tile.get_rect()), "preview parts remain within their drop control")
		_check_supply_layout(view)
		_check_preview_label_height(view)
	view.size = Vector2(1000, 720)


func _check_supply_layout(view) -> void:
	var context: String = " at %s" % view.size
	var board: Rect2 = view._board
	var tray: Rect2 = view._preview_rect
	check(is_equal_approx(tray.position.x, board.position.x) and is_equal_approx(tray.size.x, board.size.x),
		"the supply tray matches the well's horizontal bounds" + context)
	check(view.drop_button.get_rect().is_equal_approx(tray), "the whole aligned tray is the manual drop target" + context)
	for index in range(view._preview_tiles.size()):
		var preview: Rect2 = view._preview_tiles[index].get_rect()
		var column_center: float = board.position.x + (float(index) + 0.5) * board.size.x / Model.COLUMNS
		check(absf(preview.get_center().x - column_center) < 0.01,
			"preview %d is centered above its well column%s" % [index, context])
	var regions: Dictionary = {"well": board, "supply tray": tray, "chest meter": view._loot_meter.get_rect(),
		"Finish": view.finish_button.get_rect(), "Collect words": view.collect_button.get_rect()}
	if view._loot_detail.visible:
		regions["chest detail"] = view._loot_detail.get_rect()
		var detail_font: Font = view._loot_detail.get_theme_font("font")
		var detail_pixels: int = view._loot_detail.get_theme_font_size("font_size")
		check(detail_font.get_string_size(view._loot_detail.text, HORIZONTAL_ALIGNMENT_LEFT, -1, detail_pixels).x <= view._loot_detail.size.x + 0.01
			and detail_font.get_height(detail_pixels) <= view._loot_detail.size.y + 0.01,
			"visible chest detail fits its allotted area" + context)
	var names: Array = regions.keys()
	var bounds := Rect2(Vector2.ZERO, view.size).grow(0.1)
	for index in range(names.size()):
		var region: Rect2 = regions[names[index]]
		check(region.size.x > 0.0 and region.size.y > 0.0 and bounds.encloses(region),
			"%s remains inside the playfield%s" % [names[index], context])
		for other in range(index + 1, names.size()):
			var overlap: Rect2 = region.intersection(regions[names[other]])
			check(overlap.size.x < 0.01 or overlap.size.y < 0.01,
				"%s and %s do not overlap%s" % [names[index], names[other], context])
	var s: float = Style.ui_scale(view)
	check(tray.size.y * s >= 44.0 - 0.01 and view.finish_button.size.y * s >= 44.0 - 0.01,
		"manual drop and Finish retain forty-four-pixel target heights" + context)
	check(view.collect_button.size.y * s >= 44.0 - 0.01 and view.collect_button.size.x * s >= 44.0 - 0.01,
		"batch collection retains a forty-four-pixel target in every layout" + context)


func _check_preview_label_height(view) -> void:
	var marked: int = 0
	for tile in view._preview_tiles:
		if not tile.visible:
			continue
		var label: Label = tile._label
		var font: Font = label.get_theme_font("font")
		var pixels: int = label.get_theme_font_size("font_size")
		check(not label.text.is_empty() and label.visible, "every committed preview retains a visible part label")
		check(font.get_height(pixels) <= label.size.y + 0.01,
			"preview label fits the font's real line height, including marked fragments")
		if tile.fragments > 0:
			marked += 1
	check(marked > 0, "preview readability regression includes a chest-marked part")


func _check_paused_resize(view) -> void:
	_reset(view)
	var source: int = -1
	var target: int = -1
	for tile: Dictionary in view.game.cells:
		if str(tile.text) == "ca":
			source = int(tile.id)
		elif str(tile.text) == "t":
			target = int(tile.id)
	check(source >= 0 and target >= 0, "paused resize fixture has a real starter word to merge")
	_drag(view, source, target)
	var merged: int = _merged_id(view)
	_advance(view, Model.FUSION_SECONDS)
	view.pause(true)
	check(not view.game.is_settled(view.game.cell(merged)), "resize begins before the paused merged body's input settling window ends")
	var spawn_elapsed: float = float(view.game.spawn_elapsed)
	var ages: Dictionary = {}
	for tile: Dictionary in view.game.cells:
		ages[int(tile.id)] = float(tile.age)
	for dimensions: Vector2 in [Vector2(390, 700), Vector2(568, 260), Vector2(320, 480), Vector2(1000, 720)]:
		view.size = dimensions
		view._layout()
		check(view.game.paused and is_equal_approx(view.game.spawn_elapsed, spawn_elapsed), "resizing leaves the paused model clock unchanged")
		check(view._reflow.is_empty() and view._snapbacks.is_empty(), "viewport geometry changes discard obsolete movement coordinates")
		for tile: Dictionary in view.game.cells:
			var body: Control = view._tiles[int(tile.id)]
			check(view._board.encloses(body.get_rect()), "paused populated body moves immediately into the resized board")
			check(body.get_rect().is_equal_approx(view._tile_rect(tile)), "paused body matches its new hit target without waiting for animation time")
			check(is_equal_approx(float(tile.age), float(ages[int(tile.id)])), "resize does not age a paused tile to force it into place")
		_check_supply_layout(view)
		_check_preview_label_height(view)
	view.pause(false)


func _check_root_tap(view) -> void:
	_reset(view)
	var ids: Array[int] = _install(view, ["ca", "t"])
	var center: Vector2 = _center(view, ids[0])
	view._press(-1, center)
	view._release(center)
	_advance(view, 0.5)
	check(heard.is_empty() and payouts.is_empty() and attempts.is_empty(), "tapping a root neither speaks a full word nor collects reward")
	check(not view.snapshot().word_reveal.visible, "tapping a standalone root never reveals a completed word")
	check(view.game.cells.size() == 2 and view.game.fusions.is_empty(), "root tap does not consume either jelly")


func _check_edge_drag(view) -> void:
	for reduced: bool in [false, true]:
		_reset(view, reduced)
		var ids: Array[int] = _install(view, ["ca", "t"])
		var source = view._tiles[ids[0]]
		var target = view._tiles[ids[1]]
		view._press(-1, _center(view, ids[0]))
		if source._lift != null:
			source._lift.kill()
		source._visual.position = Vector2.ZERO
		var edge: float = 295.0 if reduced else 293.0
		var gap: Vector2 = target.get_rect().get_center() + Vector2((edge + 3.0) / 320.0 * source.size.x, 0)
		var touch: Vector2 = target.get_rect().get_center() + Vector2((edge - 1.0) / 320.0 * source.size.x, 0)
		view._move(view.get_global_transform() * gap)
		check(view._target == -1 and cues.count("contact") == 0, "separated silhouettes cannot trigger contact")
		view._move(view.get_global_transform() * touch)
		check(view._target == ids[1] and not target.get_rect().has_point(touch), "slight body overlap selects the target before pointer entry")
		check(view._contact_state().kind == "match" and cues.count("contact") == 1, "any two parts show a merge contact response")
		_advance(view, 0.1)
		check(view.game.fusions.is_empty() and cues.count("contact") == 1, "held touch waits for release without repeating the contact cue")
		view._release(view.get_global_transform() * touch)
		check(view.game.fusions.size() == 1 and cues.count("merge") == 1, "edge release commits one fusion")
		var id: int = _merged_id(view)
		_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS * 2.0)
		check(view.game.cell(id).text == "cat" and view._tiles.has(id), "edge merge becomes one persistent word")
		check(view._tiles[id]._picture.is_visible_in_tree() and view._tiles[id]._picture.texture != null, "a valid merge displays its production word image")
		check(payouts.is_empty() and attempts.is_empty(), "revealing the image grants nothing until the word is collected")


func _placement_point(view, tile: Dictionary, column: int, row: int) -> Vector2:
	var center: Vector2 = view._board.position + Vector2(column, row) * view._pitch \
		+ Vector2(int(tile.width), int(tile.height)) * view._pitch * 0.5
	return view.get_global_transform() * center


func _pointer_event(view, pointer: int, phase: String, position: Vector2, canceled: bool = false) -> void:
	var event: InputEvent
	if pointer >= 0:
		if phase == "move":
			event = InputEventScreenDrag.new()
		else:
			event = InputEventScreenTouch.new()
			event.pressed = phase == "down"
			event.canceled = canceled
		event.index = pointer
	else:
		if phase == "move":
			event = InputEventMouseMotion.new()
			event.button_mask = MOUSE_BUTTON_MASK_LEFT
		else:
			event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = phase == "down"
			event.canceled = canceled
	event.position = position
	view._input(event)


func _reposition_fixture(view, mass: int = 1) -> Dictionary:
	view.game.cells.clear()
	var text: String = "ca" if mass == 1 else "cat" if mass == 2 else "caterpillar"
	var tile: Dictionary = view.game._new_tile(text, mass, 2)
	tile.column = 0
	tile.row = Model.ROWS - int(tile.height)
	view.game.cells.append(tile)
	view._sync_tiles()
	view._layout()
	return tile


func _check_reposition_release(view) -> void:
	for dimensions: Vector2 in [Vector2(1000, 720), Vector2(390, 700)]:
		view.size = dimensions
		for reduced: bool in [false, true]:
			for pointer: int in [-1, 7]:
				for mass: int in [1, 2, 7]:
					_reset(view, reduced)
					var tile: Dictionary = _reposition_fixture(view, mass)
					var original: Dictionary = tile.duplicate(true)
					var id: int = int(tile.id)
					var column: int = 0 if mass == 7 else 2
					var motion: Vector2 = _placement_point(view, tile, column, 1)
					var release: Vector2 = _placement_point(view, tile, column, 3)
					_pointer_event(view, pointer, "down", _center(view, id))
					_pointer_event(view, pointer, "move", motion)
					check(view._dragging and view._target == -1, "mouse and touch drag roots, words, and wrapped bodies over an empty destination")
					var preview: Dictionary = view.snapshot().placement
					check(preview.visible and preview.valid and int(preview.tile_id) == id and int(preview.column) == column and int(preview.row) == 1,
						"the placement skin previews the whole valid snapped destination before release")
					check(int(view.game.cell(id).column) == int(original.column) and int(view.game.cell(id).row) == int(original.row)
						and not bool(view.game.cell(id).get("placement_locked", false)),
						"previewing a destination cannot mutate the live body or claim its new cells before release")
					check(view._placement_tile is Jelly.WordTile and view._placement_tile.mouse_filter == Control.MOUSE_FILTER_IGNORE,
						"placement reuses the painted jelly artwork without intercepting mouse or touch ownership")
					_pointer_event(view, pointer, "up", release)
					var placed: Dictionary = view.game.cell(id)
					check(int(placed.column) == column and int(placed.row) == 3 and bool(placed.get("placement_locked", false)),
						"placement uses the final pointer-up cell, including a newer coordinate than the last motion event")
					check(placed.text == original.text and placed.word == original.word and placed.mass == original.mass
						and placed.fragments == original.fragments and placed.width == original.width and placed.height == original.height,
						"repositioning preserves identity, spelling, picture, mass, full footprint, and every fragment")
					check(view.game.fusions.is_empty() and not view._settled(placed), "placing a body starts its short input settling window without merging or collecting it")
					check(not view.snapshot().placement.visible, "a committed placement removes its temporary destination skin")
					check(not view._press(pointer, _center(view, id)), "a newly placed body cannot accept a competing tap during its settle")
					if reduced:
						check(view._tiles[id].get_rect().is_equal_approx(view._tile_rect(placed)) and view._tiles[id].scale == Vector2.ONE,
							"reduced motion places the body at the exact snapped cell without a moving or scaled target")
					_advance(view, Model.SETTLE_SECONDS + 0.01)
					placed = view.game.cell(id)
					check(view._settled(placed) and view._tiles[id].get_rect().is_equal_approx(view._tile_rect(placed)),
						"the settled body and its hit target agree at the player's chosen position")
					check(view._tiles[id].visible_fragment_badges() == 2 and view._board.encloses(view._tiles[id].get_rect()),
						"a relocated root or wrapped word retains its chest artwork inside the well")
					view.game._settle_collected_stack()
					_advance(view, 1.0)
					check(int(placed.row) == 3 and int(placed.column) == column,
						"later gravity respects an intentional player placement instead of pulling it to the floor")
					check(payouts.is_empty() and attempts.is_empty() and heard.is_empty()
						and view.game.collected_coins == 0 and view.game.fragment_count == 0,
						"moving even a completed word never pays coins, collects fragments, teaches, or pronounces it")
					check(not view.snapshot().word_reveal.visible and cues.count("pop") == 0 and cues.count("merge") == 0,
						"a positional drop cannot trigger the collection overlay, pop, or merge sound")
	view.size = Vector2(1000, 720)


func _check_reposition_rejection(view) -> void:
	for pointer: int in [-1, 7]:
		for destination: Vector2i in [Vector2i(-1, 2), Vector2i(1, 2), Vector2i(0, -1), Vector2i(0, 7)]:
			_reset(view)
			var tile: Dictionary = _reposition_fixture(view, 7)
			var original: Rect2 = view._tile_rect(tile)
			var release: Vector2 = _placement_point(view, tile, destination.x, destination.y)
			_pointer_event(view, pointer, "down", _center(view, int(tile.id)))
			_pointer_event(view, pointer, "move", release)
			_pointer_event(view, pointer, "up", release)
			_advance(view, Model.SETTLE_SECONDS + 0.1)
			check(view._tiles[int(tile.id)].get_rect().is_equal_approx(original) and not bool(tile.get("placement_locked", false)),
				"a wrapped body whose footprint crosses any well edge returns home even when its pointer is inside")
			check(view.game.fusions.is_empty() and payouts.is_empty(), "an out-of-bounds drop cannot consume or collect a word")
		_reset(view)
		var tile: Dictionary = _reposition_fixture(view, 2)
		var original: Rect2 = view._tile_rect(tile)
		var blocker: Dictionary = view.game._new_tile("t", 1, 0)
		blocker.column = 3
		blocker.row = 2
		blocker.age = 0.0
		blocker.settling = true
		view.game.cells.append(blocker)
		view._sync_tiles()
		var occupied: Vector2 = _placement_point(view, tile, 2, 2)
		_pointer_event(view, pointer, "down", _center(view, int(tile.id)))
		_pointer_event(view, pointer, "move", occupied)
		check(view._target == -1, "a moving occupant cannot become a merge target")
		check(view.snapshot().placement.visible and not view.snapshot().placement.valid,
			"a blocked footprint gets visual rejection while leaving the held jelly under pointer control")
		_pointer_event(view, pointer, "up", occupied)
		_advance(view, Model.SETTLE_SECONDS + 0.1)
		check(view._tiles[int(tile.id)].get_rect().is_equal_approx(original) and not bool(tile.get("placement_locked", false)),
			"an occupied tail cell rejects the whole wider footprint instead of checking only its origin")
		check(view.game.cells.size() == 2 and view.game.fusions.is_empty(), "a rejected occupied drop preserves both bodies")
		_reset(view)
		tile = _reposition_fixture(view)
		var a: Dictionary = view.game._new_tile("ca", 1, 0)
		a.column = 3
		a.row = 2
		var b: Dictionary = view.game._new_tile("t", 1, 0)
		b.column = 4
		b.row = 2
		view.game.cells.append(a)
		view.game.cells.append(b)
		view._sync_tiles()
		view._merge(int(a.id), int(b.id), view._tiles[int(a.id)].position)
		check(view.game.fusions.size() == 1, "reservation fixture has an active neighboring merge")
		var reserved: Dictionary = view.game.fusions[0].result
		occupied = _placement_point(view, tile, int(reserved.column), int(reserved.row))
		_pointer_event(view, pointer, "down", _center(view, int(tile.id)))
		_pointer_event(view, pointer, "move", occupied)
		_pointer_event(view, pointer, "up", occupied)
		check(int(tile.column) == 0 and int(tile.row) == Model.ROWS - 1 and not bool(tile.get("placement_locked", false)),
			"dropping into a fusion's future footprint is rejected before its new body appears")
		check(view.game.fusions.size() == 1 and payouts.is_empty(), "reserved-space rejection leaves the original fusion and rewards untouched")


func _check_reposition_lifecycle(view) -> void:
	for pointer: int in [-1, 7]:
		for interruption: String in ["cancel", "pointer_cancel", "pause", "resize", "focus"]:
			_reset(view)
			var tile: Dictionary = _reposition_fixture(view, 2)
			var release: Vector2 = _placement_point(view, tile, 2, 2)
			_pointer_event(view, pointer, "down", _center(view, int(tile.id)))
			_pointer_event(view, pointer, "move", release)
			match interruption:
				"cancel": view.cancel_input()
				"pointer_cancel": _pointer_event(view, pointer, "up", release, true)
				"pause": view.pause(true)
				"resize":
					view.size = Vector2(390, 700)
					view._layout()
					check(view._board.encloses(view._tiles[int(tile.id)].get_rect())
						and view._tiles[int(tile.id)].get_rect().is_equal_approx(view._tile_rect(tile)),
						"resizing a held body immediately fits its artwork and hit target into the new well")
				"focus": view._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
			_pointer_event(view, pointer, "up", release)
			if interruption == "pause":
				view.pause(false)
			_advance(view, Model.SETTLE_SECONDS + 0.1)
			check(int(tile.column) == 0 and int(tile.row) == Model.ROWS - 1 and not bool(tile.get("placement_locked", false)),
				"%s cancels an uncommitted mouse or touch placement" % interruption)
			check(view._tiles[int(tile.id)].get_rect().is_equal_approx(view._tile_rect(tile)) and view.game.fusions.is_empty(),
				"%s restores artwork to its current board rectangle without a stale destination" % interruption)
			check(not view.snapshot().placement.visible, "%s removes the stale placement preview" % interruption)
			check(payouts.is_empty() and heard.is_empty() and attempts.is_empty(), "interrupted placement cannot become an accidental collection tap")
			view.size = Vector2(1000, 720)
		_reset(view)
		var tile: Dictionary = _reposition_fixture(view, 2)
		var origin: Vector2 = _center(view, int(tile.id))
		_pointer_event(view, pointer, "down", origin)
		_pointer_event(view, pointer, "move", _placement_point(view, tile, 2, 2))
		_pointer_event(view, pointer, "up", origin)
		_advance(view, Model.SETTLE_SECONDS)
		check(not bool(tile.get("placement_locked", false)) and view.game.fusions.is_empty() and payouts.is_empty(),
			"returning a dragged word to its own cell is a no-op without pinning or collecting it")


func _check_reposition_ancestry(view) -> void:
	_reset(view)
	var fixture: Dictionary = _invalid_merge(view)
	_advance(view, Model.SETTLE_SECONDS + 0.01)
	var tile: Dictionary = view.game.cell(fixture.id)
	var release: Vector2 = _placement_point(view, tile, 1, 2)
	_pointer_event(view, 7, "down", _center(view, fixture.id))
	_pointer_event(view, 7, "move", release)
	_pointer_event(view, 7, "up", release)
	_advance(view, Model.SETTLE_SECONDS + 0.01)
	tile = view.game.cell(fixture.id)
	check(view.game.can_split(tile) and bool(tile.get("placement_locked", false)), "moving an invalid merged word retains its undo ancestry")
	var center: Vector2 = _center(view, fixture.id)
	_pointer_event(view, 7, "down", center)
	_pointer_event(view, 7, "up", center)
	check(view.game.fusions.size() == 1 and view.game.fusions[0].operation == "split", "a later tap still splits the relocated invalid word")
	_advance(view, Model.SPLIT_SECONDS + Model.SETTLE_SECONDS * 2.0)
	for id: int in fixture.ids:
		var restored: Dictionary = view.game.cell(id)
		check(not restored.is_empty() and not bool(restored.get("placement_locked", false)) and _has_support(view.game.cells, restored),
			"splitting a moved parent restores naturally supported original children without inherited placement locks")
	check(payouts.is_empty() and attempts.is_empty() and heard.is_empty(), "moving and undoing an invalid word preserves rewards and learning state")


func _check_collect_and_fragments(view) -> void:
	_reset(view)
	var ids: Array[int] = _install(view, ["ca", "t"], [1, 1])
	_drag(view, ids[0], ids[1])
	var id: int = _merged_id(view)
	_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS * 2.0)
	var tile = view._tiles[id]
	check(tile.visible_fragment_badges() == 2 and tile._fragment_badges[0].visible and tile._fragment_badges[1].visible, "both source chest markers remain independently visible on the merge")
	check(tile._label.text.to_lower() == "cat" and tile._label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, "merged word label remains complete")
	var center: Vector2 = _center(view, id)
	view._press(7, center)
	view._release(center)
	check(view.game.fusions.size() == 1 and view.game.fusions[0].operation == "collect", "touch tap begins a distinct disappearance operation")
	check(heard.size() == 1 and heard[0].id == "cat", "collect tap speaks the completed word once")
	_advance(view, 0.179)
	check(cues.count("pop") == 0 and payouts.is_empty(), "manual collection retains its full 180 ms anticipation before the pop")
	_advance(view, 0.001)
	check(cues.count("pop") == 1 and payouts.is_empty(), "manual collection plays the existing disappearance sound at 180 ms")
	_advance(view, 0.239)
	check(view.game.cells.size() == 1 and payouts.is_empty(), "manual collection keeps the word reserved before its 420 ms payout")
	_advance(view, 0.001)
	check(view.game.cells.is_empty() and payouts.size() == 1 and attempts.size() == 1, "tap collection removes the word and emits one reward and learning attempt")
	check(payouts[0].amount == 100 and payouts[0].fragments == 2 and payouts[0].origin.distance_to(center) < 0.1,
		"coin and fragment flight origin matches the tapped merged jelly")
	check(cues.count("pop") == 1 and view.game.fragment_count == 2, "collection retains the disappearance cue and all accumulated fragments")


func _snapshot_rect(value: Array) -> Rect2:
	return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))


func _install_batch_words(view, count: int, retain_others: bool = false) -> Array[int]:
	view.game.cells.clear()
	var ids: Array[int] = []
	for index in range(count):
		var tile: Dictionary = view.game._new_tile("cat", 2, index % 3)
		tile.column = (index % 3) * 2
		tile.row = Model.ROWS - 1 - floori(float(index) / 3.0)
		view.game.cells.append(tile)
		ids.append(int(tile.id))
	if retain_others:
		var invalid: Dictionary = view.game._new_tile("tc", 2, 2)
		invalid.column = 0
		invalid.row = Model.ROWS - 2
		var single: Dictionary = view.game._new_tile("cat", 1, 1)
		single.column = 2
		single.row = Model.ROWS - 2
		view.game.cells.append(invalid)
		view.game.cells.append(single)
	view._sync_tiles()
	view._layout()
	return ids


func _check_collect_button_growth(view) -> void:
	for dimensions: Vector2 in LAYOUT_SIZES:
		view.size = dimensions
		_reset(view)
		var empty: Dictionary = view.snapshot().collect_button
		var button_rect: Rect2 = view.collect_button.get_rect()
		check(empty.visible and not empty.enabled and int(empty.count) == 0,
			"the empty collect action remains discoverable but cannot start a batch")
		check(not view.navigation_controls().has(view.collect_button),
			"keyboard navigation skips the unavailable empty collect action")
		var previous_scale: float = float(empty.visual_scale)
		var previous_sparkles: int = int(empty.sparkle_count)
		for count: int in [1, 3, 9]:
			var previous_charge: float = float(view.snapshot().collect_button.charge)
			_install_batch_words(view, count)
			var changed: Dictionary = view.snapshot().collect_button
			check(changed.enabled and int(changed.count) == count and float(changed.target_charge) == count,
				"the action counts completed merged words and targets their accumulated strength")
			check(view.navigation_controls().has(view.collect_button)
				and not str(view.collect_button.get("accessibility_name")).is_empty(),
				"a ready collect action has a keyboard destination and an accessible name")
			check(is_equal_approx(float(changed.charge), previous_charge),
				"a larger batch starts growing from the previous charge instead of snapping")
			_advance(view, 0.12)
			var growing: Dictionary = view.snapshot().collect_button
			check(float(growing.charge) > previous_charge and float(growing.charge) < float(count),
				"the charge visibly passes through intermediate strength after its count rises")
			_advance(view, 2.0)
			var charged: Dictionary = view.snapshot().collect_button
			check(float(charged.visual_scale) > previous_scale and int(charged.sparkle_count) >= previous_sparkles,
				"one, three and nine words produce progressively larger, richer collection artwork")
			check(view.collect_button.get_rect().is_equal_approx(button_rect),
				"growing artwork preserves the button hit target and neighboring layout")
			_check_supply_layout(view)
			previous_scale = float(charged.visual_scale)
			previous_sparkles = int(charged.sparkle_count)
	view.size = Vector2(1000, 720)
	_reset(view, true)
	var last: Dictionary = {}
	var high_count_rect: Rect2 = view.collect_button.get_rect()
	for count: int in [9, 15, 24]:
		_install_batch_words(view, count)
		var steady: Dictionary = view.snapshot().collect_button
		_advance(view, 0.4)
		var later: Dictionary = view.snapshot().collect_button
		check(steady.reduced_motion and is_equal_approx(float(steady.charge), float(count))
			and is_equal_approx(float(steady.visual_scale), float(later.visual_scale))
			and is_equal_approx(float(steady.elapsed), float(later.elapsed)),
			"reduced motion keeps the earned strength readable without pulsing or growth travel")
		check(view.collect_button.get_rect().is_equal_approx(high_count_rect),
			"nine through twenty-four completed words keep the same safe button footprint")
		if not last.is_empty():
			check(int(steady.coin_count) > int(last.coin_count) and int(steady.sparkle_count) > int(last.sparkle_count)
				and float(steady.glow) > float(last.glow) and float(steady.rays) > float(last.rays),
				"large batches continue gaining coin artwork, glints and stronger light beyond nine words")
			check(is_equal_approx(float(steady.visual_scale), float(last.visual_scale)),
				"high-count intensity grows through richer effects without crowding adjacent controls")
		last = steady


func _check_batch_collection(view) -> void:
	for reduced: bool in [false, true]:
		_reset(view, reduced)
		var ids: Array[int] = _install_batch_words(view, 3, true)
		var retained: Array[int] = []
		for tile: Dictionary in view.game.cells:
			if not ids.has(int(tile.id)):
				retained.append(int(tile.id))
		var credits: Dictionary = {}
		view.credit_collection = func(id: String, amount: int) -> Dictionary:
			credits[id] = int(credits.get(id, 0)) + 1
			check(amount == 100, "each batch member uses the ordinary merged-word coin calculation")
			return {"ok": true}
		var pop_times: Array[float] = []
		var on_pop: Callable = func(cue: String) -> void:
			if cue == "pop":
				pop_times.append(float(view.game.collection_batch_snapshot().elapsed))
		view.audio_requested.connect(on_pop)
		view.collect_button.pressed.emit()
		var started: Dictionary = view.snapshot()
		check(started.collection_batch.active and int(started.collection_batch.total) == 3
			and int(started.collection_batch.started) == 1 and not started.collect_button.enabled,
			"one collect-button activation snapshots three valid merges and starts only the first")
		check(not started.preview.enabled and not view.navigation_controls().has(view.collect_button)
			and view.navigation_controls().has(view.finish_button),
			"a running batch blocks more supply and collection while leaving Finish accessible")
		view.collect_button.pressed.emit()
		view._activate(ids[1])
		check(not view._press(-1, _center(view, retained[0])),
			"batch playback cannot start a competing drag or split")
		check(view.game.fusions.size() == 1 and payouts.is_empty(),
			"repeated button and tile activation cannot overlap the first collection")
		var generated: int = int(view.game.generated_tiles)
		view._drop_next(int(view.game.upcoming[0].id))
		check(int(view.game.generated_tiles) == generated, "the manual drop shortcut obeys the running batch input gate")
		var elapsed: float = 0.0
		var previous_started: int = 1
		var previous_completed: int = 0
		var start_times: Array[float] = [0.0]
		var payout_times: Array[float] = []
		while elapsed < 5.0 and bool(view.snapshot().collection_batch.active):
			_advance(view, 0.025)
			elapsed += 0.025
			var state: Dictionary = view.snapshot()
			var now_started: int = int(state.collection_batch.started)
			var now_completed: int = int(state.collection_batch.completed)
			check(now_started >= previous_started and now_started <= previous_started + 1
				and now_completed >= previous_completed and now_completed <= previous_completed + 1,
				"batch members start and commit singly in monotonic order")
			check(now_started - now_completed <= 1 and view.game.fusions.size() <= 1,
				"the rhythmic queue never overlaps reward transactions or disappearance poses")
			if now_started > previous_started:
				start_times.append(float(state.collection_batch.elapsed))
			if now_completed > previous_completed:
				payout_times.append(float(state.collection_batch.elapsed))
				check(now_started == mini(3, now_completed + 1),
					"the next captured word starts on the same beat as the preceding payout")
			previous_started = now_started
			previous_completed = now_completed
		var final: Dictionary = view.snapshot()
		check(not final.collection_batch.active and int(final.collection_batch.completed) == 3
			and int(final.collection_batch.started) == 3 and is_equal_approx(elapsed, 0.30),
			"three words finish in exactly 300 ms through three sequential collection beats")
		check(start_times.size() == 3 and payout_times.size() == 3 and pop_times.size() == 3,
			"each collected word has a separate visible start, payout and disappearance sound")
		for index in range(start_times.size()):
			check(is_equal_approx(start_times[index], index * 0.10)
				and is_equal_approx(payout_times[index], (index + 1) * 0.10),
				"ordinary and reduced-motion collection both preserve exact 100 ms start and payout spacing")
			check(is_equal_approx(pop_times[index], index * 0.10 + 0.06),
				"the existing disappearance sound stays at 60 ms within every 100 ms beat")
		check(payouts.size() == 3 and credits.size() == 3 and attempts.size() == 3,
			"batch collection credits and records each captured word exactly once")
		for times: int in credits.values():
			check(times == 1, "each batch event reaches persistent credit only once")
		check(view.game.collected_coins == 300 and view.game.fragment_count == 3 and cues.count("pop") == 3,
			"all carried fragments, coins and three existing disappearance beats survive batch playback")
		check(heard.size() == 1, "the final batch word speaks once after the short per-word sound rhythm")
		for id: int in retained:
			check(not view.game.cell(id).is_empty(), "unfinished merges and unmerged roots stay available after collecting")
		check(not final.collect_button.enabled and int(final.collect_button.count) == 0,
			"collecting every completed merge returns the button to its empty state")
		_advance(view, 2.0)
		check(payouts.size() == 3 and view.game.collected_coins == 300,
			"the completed batch cannot replay its rewards on later frames")
		view.audio_requested.disconnect(on_pop)


func _check_batch_chest_queue(view) -> void:
	for reduced: bool in [false, true]:
		_reset(view, reduced)
		_install_batch_words(view, 9)
		var confetti: Array[int] = []
		var on_confetti: Callable = func() -> void: confetti.append(1)
		view._reward_presentation.confetti_requested.connect(on_confetti)
		view._collect_all()
		var elapsed: float = 0.0
		var queued_during_batch: bool = false
		while elapsed < 8.0 and view.game.collection_batch_active():
			_advance(view, 0.025)
			elapsed += 0.025
			var presentation: Dictionary = view.snapshot().reward_presentation
			if view.game.chest_tier > 0:
				queued_during_batch = queued_during_batch or bool(presentation.active)
			if view.game.collection_batch_active():
				check(not presentation.visible and confetti.is_empty(),
					"earned chests queue behind batch collection instead of covering its remaining words")
		check(queued_during_batch and not view.game.collection_batch_active()
			and view.game.fragment_count == 9 and view.game.chest_tier == 2,
			"all nine fragments and the second chest tier commit before queued celebration begins")
		check(payouts.size() == 9 and view.game.collected_coins == 900 and is_equal_approx(elapsed, 0.90),
			"waiting chest artwork preserves all nine authoritative coin rewards within 900 ms")
		var kinds: Dictionary = {}
		for tick in range(320):
			_advance(view, 0.025)
			var presentation: Dictionary = view.snapshot().reward_presentation
			if presentation.visible:
				kinds[str(presentation.kind)] = true
		check(kinds.has("synthesis") and kinds.has("upgrade") and not view._reward_presentation.is_active(),
			"the existing synthesis and upgrade performances both play after batch collection")
		check(confetti.size() == (0 if reduced else 2),
			"each queued chest releases one confetti celebration, with reduced motion respected")
		check(payouts.size() == 9 and view.game.collected_coins == 900 and view.game.fragment_count == 9,
			"queued chest flights and confetti remain presentation-only after all batch rewards")
		view._reward_presentation.confetti_requested.disconnect(on_confetti)


func _check_batch_lifecycle(view) -> void:
	_reset(view)
	_install_batch_words(view, 3)
	view._collect_all()
	_advance(view, 0.04)
	view.pause(true)
	var paused: Dictionary = view.snapshot()
	_advance(view, 1.0)
	var waiting: Dictionary = view.snapshot()
	check(paused.collection_batch == waiting.collection_batch
		and is_equal_approx(float(paused.collect_button.elapsed), float(waiting.collect_button.elapsed))
		and is_equal_approx(float(paused.collect_button.charge), float(waiting.collect_button.charge))
		and payouts.is_empty(), "pause freezes both the batch reward clock and the charge animation")
	for dimensions: Vector2 in [Vector2(390, 700), Vector2(568, 320), Vector2(1000, 720)]:
		view.size = dimensions
		view._layout()
		_check_supply_layout(view)
		check(view.snapshot().collection_batch == paused.collection_batch,
			"resizing the paused batch preserves its captured IDs and exact progress")
	view.pause(false)
	_advance(view, 3.0)
	check(payouts.size() == 3 and not view.snapshot().collection_batch.active,
		"resuming completes the original three-member batch once")
	for action: String in ["stop", "finish", "configure"]:
		_reset(view)
		_install_batch_words(view, 3)
		view._collect_all()
		_advance(view, 0.03)
		match action:
			"stop": view.stop()
			"finish": view._finish_round()
			"configure": view.configure(words, 3, Data.theme("spring"), data.chests, false, 42)
		_advance(view, 2.0)
		check(not view.snapshot().collection_batch.active and payouts.is_empty(),
			action + " discards unfinished batch work without a late credit")
		check(not bool(view.snapshot().collect_button.active), action + " clears the running button presentation")
		if action == "stop":
			check(int(view.snapshot().collect_button.count) == 0 and is_zero_approx(float(view.snapshot().collect_button.target_charge)),
				"leaving the mode resets button strength instead of recharging it from the discarded board")


func _check_batch_wallet_failure(view) -> void:
	_reset(view)
	var ids: Array[int] = _install_batch_words(view, 3)
	view.credit_collection = func(_id: String, _amount: int) -> Dictionary: return {"ok": false}
	view._collect_all()
	_advance(view, 3.0)
	check(not view.snapshot().collection_batch.active and payouts.is_empty() and view.game.collected_coins == 0,
		"a rejected wallet write stops the batch without skipping ahead or issuing a reward")
	for id: int in ids:
		check(not view.game.cell(id).is_empty() and view._tiles[id].visible,
			"wallet failure leaves every captured word and its fragments visible for retry")
	check(view.snapshot().collect_button.enabled and int(view.snapshot().collect_button.count) == 3,
		"failed persistence restores the full collectable count and a usable retry action")
	view.credit_collection = func(_id: String, _amount: int) -> Dictionary: return {"ok": true}
	view.collect_button.pressed.emit()
	_advance(view, 3.0)
	check(payouts.size() == 3 and view.game.collected_coins == 300 and view.game.fragment_count == 3,
		"retry after wallet recovery pays each remaining word and carried fragment exactly once")


func _check_reveal_content(view, expected: Dictionary) -> void:
	var reveal: Dictionary = view.snapshot().word_reveal
	check(reveal.visible and reveal.word_id == expected.id and reveal.word.id == expected.id,
		"collecting a completed word reveals that word above the board")
	check(reveal.spelling == expected.text and str(reveal.picture).trim_prefix("res://") == expected.image,
		"the reveal uses the collected word's complete spelling and production image")
	check(reveal.content_alpha > 0.95 and view._word_reveal._picture.texture != null,
		"the reveal reaches a readable opaque hold with real picture art")
	var panel: Rect2 = _snapshot_rect(reveal.rect)
	var picture: Rect2 = _snapshot_rect(reveal.picture_rect)
	var spelling: Rect2 = _snapshot_rect(reveal.spelling_rect)
	check(view.get_global_rect().encloses(panel) and panel.end.y <= view.get_global_rect().position.y + view.size.y * 0.42,
		"the reveal remains near the top and inside the available playfield")
	check(panel.encloses(picture) and panel.encloses(spelling) and picture.end.x < spelling.position.x,
		"picture and spelling have separate readable space inside the reveal")
	var label: Label = view._word_reveal._spelling
	var font: Font = label.get_theme_font("font")
	var pixels: int = label.get_theme_font_size("font_size")
	check(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x <= label.size.x + 0.1,
		"the complete word spelling fits without truncation")
	check(view._word_reveal.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"the brief reading layer leaves gameplay input available")


func _check_word_reveal(view) -> void:
	for reduced: bool in [false, true]:
		for dimensions: Vector2 in [Vector2(1000, 720), Vector2(768, 1024), Vector2(390, 700), Vector2(568, 260)]:
			view.size = dimensions
			_reset(view, reduced)
			var ids: Array[int] = _install(view, ["cat", "caterpillar"], [1, 1], [2, 2])
			for id: int in ids:
				view._cell(id).row = Model.ROWS - 1
			view._rest_rects.clear()
			view._reflow.clear()
			view._sync_positions()
			check(not view.snapshot().word_reveal.visible, "a new round starts without a previous word reveal")
			var point: Vector2 = _center(view, ids[0])
			view._press(7, point)
			view._release(point)
			_advance(view, 0.20)
			_check_reveal_content(view, words[0])
			var first: Dictionary = view.snapshot().word_reveal
			view._activate(ids[0])
			check(is_equal_approx(view.snapshot().word_reveal.elapsed, first.elapsed) and heard.size() == 1,
				"duplicate activation cannot restart the reveal or repeat pronunciation")
			check(cues.count("pop") == 1, "the reveal peak shares the one existing disappearance sound")
			if reduced:
				check(view._word_reveal._visual.scale == Vector2.ONE and not view._word_reveal._aura.visible,
					"reduced motion preserves a steady readable picture and spelling")
			_advance(view, Model.COLLECT_SECONDS)
			view._activate(ids[1])
			_advance(view, 0.20)
			_check_reveal_content(view, words[1])
			check(view.snapshot().word_reveal.elapsed < first.elapsed + 0.01 and heard.size() == 2,
				"another keyboard collection immediately replaces the first word instead of queuing stale overlays")
			_advance(view, Model.COLLECT_SECONDS)
			check(payouts.size() == 2 and view.game.collected_coins == 200 and cues.count("pop") == 2,
				"rapid different-word reveals preserve exactly one reward and one disappearance cue per collection")
			_advance(view, float(view.snapshot().word_reveal.duration))
			check(not view.snapshot().word_reveal.visible and heard.size() == 2 and payouts.size() == 2,
				"the reveal clears itself without replaying a word or collecting another reward")
	view.size = Vector2(1000, 720)


func _check_word_reveal_lifecycle(view) -> void:
	for action: String in ["pause", "hide", "finish", "stop", "configure"]:
		_reset(view)
		var ids: Array[int] = _install(view, ["cat"], [], [2])
		view._activate(ids[0])
		_advance(view, 0.2)
		check(view.snapshot().word_reveal.visible, "lifecycle fixture begins with a visible collected word")
		match action:
			"pause": view.pause(true)
			"hide": view.hide()
			"finish": view._finish_round()
			"stop": view.stop()
			"configure": view.configure(words, 3, Data.theme("spring"), data.chests, false, 42)
		check(not view.snapshot().word_reveal.visible, action + " clears the temporary word reveal immediately")
		view.show()
		view.pause(false)
		_advance(view, 0.1)
		check(not view.snapshot().word_reveal.visible, action + " never restores a stale collected-word overlay")
	_reset(view)
	var ids: Array[int] = _install(view, ["cat"], [], [2])
	view._activate(ids[0])
	_advance(view, 0.2)
	var elapsed: float = float(view.snapshot().word_reveal.elapsed)
	view.interaction_allowed = func() -> bool: return false
	_advance(view, 0.4)
	check(is_equal_approx(float(view.snapshot().word_reveal.elapsed), elapsed),
		"an external interaction gate cannot advance the reading beat")
	view.interaction_allowed = Callable()
	_advance(view, 0.1)
	check(float(view.snapshot().word_reveal.elapsed) > elapsed, "the reading beat resumes only with allowed gameplay")


func _check_collection_stack_fall(view) -> void:
	for reduced: bool in [false, true]:
		for pointer: int in [-1, 7]:
			_reset(view, reduced)
			view.game.cells.clear()
			var support: Dictionary = view.game._new_tile("cat", 2, 1)
			support.column = 1
			support.row = 7
			var lower: Dictionary = view.game._new_tile("ca", 1, 1)
			lower.column = 1
			lower.row = 6
			var upper: Dictionary = view.game._new_tile("t", 1, 0)
			upper.column = 1
			upper.row = 5
			var neighbor: Dictionary = view.game._new_tile("stay", 1, 0)
			neighbor.column = 4
			neighbor.row = 7
			view.game.cells.assign([support, lower, upper, neighbor])
			view._sync_tiles()
			view._layout()
			var origins: Dictionary = {}
			var source_rows: Dictionary = {int(lower.id): int(lower.row), int(upper.id): int(upper.row)}
			for tile: Dictionary in [lower, upper, neighbor]:
				origins[int(tile.id)] = view._tiles[int(tile.id)].get_rect()
			var center: Vector2 = _center(view, int(support.id))
			check(view._press(pointer, center), "mouse and touch can collect the word supporting a stack")
			view._release(center)
			_advance(view, Model.COLLECT_SECONDS - 0.001)
			for tile: Dictionary in [lower, upper]:
				check(view._tiles[int(tile.id)].get_rect().is_equal_approx(origins[int(tile.id)]),
					"a stack stays still until its lower word has actually disappeared")
			_advance(view, 0.002)
			check(view.game.cell(int(support.id)).is_empty() and payouts.size() == 1 and payouts[0].amount == 100,
				"successful support collection starts gravity after exactly one coin payment")
			for tile: Dictionary in [lower, upper]:
				var falling: Dictionary = view.game.cell(int(tile.id))
				check(int(falling.column) == 1 and int(falling.row) == int(source_rows[int(tile.id)]) + 1,
					"the whole stack drops one row in its original column")
				check(bool(falling.get("falling", false)) and int(falling.falling_rows) == 1 and not view._settled(falling),
					"falling stack bodies keep input locked until landing")
				var body: Control = view._tiles[int(tile.id)]
				if reduced:
					check(body.get_rect().is_equal_approx(view._tile_rect(falling)) and body.scale == Vector2.ONE,
						"reduced motion places the supported stack directly at its steady destination")
				else:
					check(body.position.y < view._tile_rect(falling).position.y,
						"normal motion begins the fall above the new resting position")
				check(not view._press(pointer, body.get_global_rect().get_center()),
					"a moving body cannot be picked up at its rendered position")
				view.cancel_input()
			_advance(view, Model.SETTLE_SECONDS * 0.45)
			for tile: Dictionary in [lower, upper]:
				var falling: Dictionary = view.game.cell(int(tile.id))
				var body: Control = view._tiles[int(tile.id)]
				if not reduced:
					check(body.position.y > Rect2(origins[int(tile.id)]).position.y
						and body.position.y < view._tile_rect(falling).position.y,
						"normal gravity renders an intermediate descent instead of teleporting the stack")
			view.pause(true)
			var paused_rect: Rect2 = view._tiles[int(lower.id)].get_rect()
			var paused_age: float = float(view.game.cell(int(lower.id)).age)
			_advance(view, 0.5)
			check(view._tiles[int(lower.id)].get_rect().is_equal_approx(paused_rect)
				and is_equal_approx(float(view.game.cell(int(lower.id)).age), paused_age),
				"pause freezes collection gravity at the visible intermediate pose")
			view.pause(false)
			_advance(view, Model.SETTLE_SECONDS * 0.70 - paused_age - 0.001)
			check(cues.count("land") == 0, "the falling stack stays silent until its shared contact pose")
			_advance(view, 0.002)
			check(cues.count("land") == 1
				and view._tiles[int(lower.id)].get_rect().is_equal_approx(view._tile_rect(view.game.cell(int(lower.id)))),
				"the stack plays one grouped landing cue as its bodies first touch their destinations")
			_advance(view, Model.SETTLE_SECONDS)
			for tile: Dictionary in [lower, upper]:
				var landed: Dictionary = view.game.cell(int(tile.id))
				check(view._settled(landed) and _has_support(view.game.cells, landed),
					"each restored stack body becomes interactive only on a supported landing")
				check(view._tiles[int(tile.id)].get_rect().is_equal_approx(view._tile_rect(landed)),
					"the landed artwork and its hit target share the exact final rectangle")
			check(view._tiles[int(lower.id)].visible_fragment_badges() == 1 and view.game.fragment_count == 1,
				"gravity carries the upper fragment without collecting it with the removed support")
			check(view._tiles[int(neighbor.id)].get_rect().is_equal_approx(origins[int(neighbor.id)]),
				"an already grounded neighbor remains visually stationary")
			check(cues.count("land") == 1, "the end of the squash cannot replay a second gravity impact")
			check(view._press(pointer, _center(view, int(lower.id))), "the landed stack accepts ordinary input again")
			view.cancel_input()


func _check_release_after_support_collection(view) -> void:
	_reset(view)
	view.game.cells.clear()
	var support: Dictionary = view.game._new_tile("cat", 2, 0)
	support.column = 1
	support.row = Model.ROWS - 1
	var upper: Dictionary = view.game._new_tile("ca", 1, 1)
	upper.column = 1
	upper.row = Model.ROWS - 2
	view.game.cells.assign([support, upper])
	view._sync_tiles()
	view._layout()
	view._activate(int(support.id))
	check(view._press(-1, _center(view, int(upper.id))), "an upper root can be held while its lower support is collecting")
	var empty_point: Vector2 = view.get_global_transform() * (view._board.position + Vector2(view._pitch * 7.0, view._pitch * 3.5))
	view._move(empty_point)
	_advance(view, Model.COLLECT_SECONDS + 0.01)
	check(view.game.cell(int(support.id)).is_empty() and int(view.game.cell(int(upper.id)).row) == Model.ROWS - 2,
		"the removed support defers gravity until the player's held upper root is released")
	check(view._target == -1, "the held-root continuity fixture releases outside the well without a new placement")
	view._release(empty_point)
	var target: Vector2 = view._tile_rect(view.game.cell(int(upper.id))).position
	var previous_distance: float = view._tiles[int(upper.id)].position.distance_to(target)
	var backwards: bool = false
	for frame in range(42):
		_advance(view, 0.01)
		var distance: float = view._tiles[int(upper.id)].position.distance_to(target)
		backwards = backwards or distance > previous_distance + 0.01
		previous_distance = distance
	check(not backwards, "releasing into deferred gravity approaches the landing continuously without a snapback-to-fall rewind")
	check(int(view.game.cell(int(upper.id)).row) == Model.ROWS - 1 and previous_distance < 0.01
		and view._settled(view.game.cell(int(upper.id))), "the released upper root finishes at the floor with its hit target and input ready")
	check(view._tiles[int(upper.id)].visible_fragment_badges() == 1 and view.game.fragment_count == 0,
		"releasing a held root after support collection retains its uncollected fragment")


func _check_coarse_frame_collection_landing(view) -> void:
	_reset(view)
	view.game.cells.clear()
	var support: Dictionary = view.game._new_tile("cat", 2, 0)
	support.column = 1
	support.row = Model.ROWS - 1
	var upper: Dictionary = view.game._new_tile("ca", 1, 0)
	upper.column = 1
	upper.row = Model.ROWS - 2
	view.game.cells.assign([support, upper])
	view._sync_tiles()
	view._layout()
	view._activate(int(support.id))
	_advance(view, Model.COLLECT_SECONDS - 0.10)
	check(cues.count("land") == 0, "the coarse-frame fixture has not played an early landing")
	view._process(0.49)
	check(view.game.cell(int(support.id)).is_empty() and view._settled(view.game.cell(int(upper.id)))
		and view._tiles[int(upper.id)].get_rect().is_equal_approx(view._tile_rect(view.game.cell(int(upper.id)))),
		"one delayed frame can complete collection and the full fall without leaving the view behind")
	check(cues.count("land") == 1, "a delayed frame crossing both removal and contact still emits one landing cue")
	_advance(view, 0.4)
	check(cues.count("land") == 1, "later frames cannot replay the coarse-frame landing")


func _palette_item(view, id: int) -> Dictionary:
	for item: Dictionary in view.snapshot().tiles:
		if int(item.id) == id:
			return item
	return {}


func _check_word_pair_colors(view) -> void:
	var original_words: Array = words.duplicate(true)
	for text: String in ["can", "dog"]:
		var word: Dictionary = original_words[0].duplicate(true)
		word.id = "view-fixture-" + text
		word.text = text
		words.append(word)
	_reset(view)
	view.game.cells.clear()
	var ids: Dictionary = {}
	for text: String in ["ca", "t", "n", "c", "at", "d", "og", "x"]:
		var tile: Dictionary = view.game._new_tile(text, 1, 0)
		tile.column = ids.size() % Model.COLUMNS
		tile.row = Model.ROWS - 1 - floori(float(ids.size()) / Model.COLUMNS)
		ids[text] = int(tile.id)
		view.game.cells.append(tile)
	view._sync_tiles()
	view._layout()
	var resting: Dictionary = view.snapshot()
	for tile: Dictionary in resting.tiles:
		check(int(tile.get("palette_index", -1)) >= 0 and float(tile.get("palette_hue", -1.0)) >= 0.0,
			"word roots expose the palette actually used by their painted gel")
		check(is_equal_approx(float(tile.get("palette_hue", -1.0)),
			float(view._tiles[int(tile.id)]._gel.get_shader_parameter("palette_hue"))),
			"color diagnostics match the rendered shader rather than only model metadata")
		for other: Dictionary in resting.tiles:
			if int(tile.id) >= int(other.id) or tile.get("palette_index", -1) != other.get("palette_index", -2):
				continue
			check(view.game._word_lookup.has(str(tile.text) + str(other.text))
				or view.game._word_lookup.has(str(other.text) + str(tile.text)),
				"every shared resting color names an exact current-vocabulary completion")
	check(_palette_item(view, ids.d).get("palette_index", -1) == _palette_item(view, ids.og).get("palette_index", -2),
		"an unambiguous word pair shares a color at rest")
	var isolated_palette: int = int(_palette_item(view, ids.x).get("palette_index", -1))
	for text: String in ["ca", "t", "n", "c", "at", "d", "og"]:
		check(int(_palette_item(view, ids[text]).get("palette_index", -2)) != isolated_palette,
			"an unrelated root cannot reuse a word pair's hint color")
	for keyboard: bool in [false, true]:
		if keyboard:
			view._activate(ids.ca)
		else:
			check(view._press(-1, _center(view, ids.ca)), "pressing a source previews its compatible completion colors")
		var source: Dictionary = _palette_item(view, ids.ca)
		for text: String in ["t", "n"]:
			check(_palette_item(view, ids[text]).get("palette_index", -1) == source.get("palette_index", -2)
				and is_equal_approx(float(_palette_item(view, ids[text]).get("palette_hue", -1.0)), float(source.get("palette_hue", -2.0))),
				"pointer and keyboard selection highlight every exact ordered completion with the source hue")
		for text: String in ["c", "at", "d", "og", "x"]:
			check(_palette_item(view, ids[text]).get("palette_index", -1) != source.get("palette_index", -2),
				"an invalid completion stays visually distinct from the selected source")
		view.cancel_input()
		if keyboard:
			view._activate(ids.t)
		else:
			view._press(-1, _center(view, ids.t))
		check(_palette_item(view, ids.t).get("palette_index", -1) != _palette_item(view, ids.ca).get("palette_index", -1),
			"a reversed-only word partner does not suggest an invalid source-then-target merge")
		view.cancel_input()
	view.apply_theme(Data.theme("autumn"), data.chests)
	for tile: Dictionary in resting.tiles:
		check(_palette_item(view, int(tile.id)).get("palette_index", -1) == tile.get("palette_index", -2),
			"changing the surrounding theme preserves established word-pair hints")
	for index in range(view._preview_tiles.size()):
		var slot: Dictionary = view.snapshot().preview.slots[index]
		check(int(slot.get("palette_index", -1)) >= 0
			and is_equal_approx(float(slot.get("palette_hue", -1.0)), float(view._preview_tiles[index]._gel.get_shader_parameter("palette_hue"))),
			"upcoming parts publish the same hint hue that their actual gel renders")
	words = original_words


func _check_partial_word_colors(view) -> void:
	_reset(view)
	view.game.cells.clear()
	var ids: Array[int] = []
	for text: String in ["cate", "rpil", "lar"]:
		var tile: Dictionary = view.game._new_tile(text, 1, 0)
		tile.column = ids.size() * 2
		tile.row = Model.ROWS - 1
		ids.append(int(tile.id))
		view.game.cells.append(tile)
	view._sync_tiles()
	view._layout()
	for first in range(ids.size()):
		for second in range(first + 1, ids.size()):
			check(_palette_item(view, ids[first]).get("palette_index", -1)
				!= _palette_item(view, ids[second]).get("palette_index", -1),
				"incomplete prefixes of a three-part word do not pretend to be exact word pairs")
	_drag(view, ids[0], ids[1])
	var partial_id: int = _merged_id(view)
	_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS * 2.0)
	check(view.game.cell(partial_id).text == "caterpil" and not view.game.is_valid_word(view.game.cell(partial_id)),
		"the first two chunks form an actual incomplete persistent word")
	check(_palette_item(view, partial_id).get("palette_index", -1) == _palette_item(view, ids[2]).get("palette_index", -2),
		"a merged partial word shares a hint color with the remaining exact completion")
	_drag(view, partial_id, ids[2])
	var completed_id: int = _merged_id(view)
	_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS * 2.0)
	check(view.game.cell(completed_id).text == "caterpillar" and view._tiles[completed_id]._picture.is_visible_in_tree(),
		"following the partial-word color hint produces its pictured vocabulary word")


func _hue_distance(first: float, second: float) -> float:
	return absf(fposmod(first - second + 0.5, 1.0) - 0.5)


func _check_fusion_palette_handover(view) -> void:
	var original_words: Array = words.duplicate(true)
	var bat: Dictionary = original_words[0].duplicate(true)
	bat.id = "view-fixture-bat"
	bat.text = "bat"
	words.append(bat)
	_reset(view)
	view.game.cells.clear()
	var ids: Dictionary = {}
	for text: String in ["a", "t", "c", "b"]:
		var tile: Dictionary = view.game._new_tile(text, 1, 0)
		tile.column = ids.size()
		tile.row = Model.ROWS - 1
		ids[text] = int(tile.id)
		view.game.cells.append(tile)
	view._sync_tiles()
	view._layout()
	_drag(view, ids.a, ids.t)
	var pending: Dictionary = view.game.fusions[0]
	var visual: Dictionary = view._fusion_visuals[str(pending.attempt_id)]
	var input_colors: Array[int] = [visual.palette_a, visual.palette_b]
	for id: int in view._palette_indices:
		check(not int(view._palette_indices[id]) in input_colors,
			"visible liquid input colors stay reserved while other live and upcoming bodies are recolored")
	var alternate: int = ids.b if view._tiles[ids.b].palette_index != visual.merged.palette_index else ids.c
	check(view._press(-1, _center(view, alternate)), "another live prefix can be selected while an unrelated merge animates")
	_advance(view, Model.FUSION_SECONDS * 0.83)
	check(visual.merged.palette_index == view._tiles[alternate].palette_index,
		"the animated future result adopts the selected prefix's newly relevant completion hue")
	check(_hue_distance(float(visual.art._gel.get_shader_parameter("palette_hue_b")),
		float(visual.merged._gel.get_shader_parameter("palette_hue"))) < 0.00001,
		"liquid paint reaches the current result hue before the solid skin handover")
	_advance(view, Model.FUSION_SECONDS * 0.18 + Model.SETTLE_SECONDS)
	var partial_id: int = int(pending.result.id)
	check(view._tiles[partial_id].palette_index == view._tiles[alternate].palette_index,
		"the persistent merged body's color agrees with the active completion hint after handover")
	view.cancel_input()
	words = original_words
	_reset(view)
	var fixture: Dictionary = _invalid_merge(view)
	var prefixes: Array[int] = []
	for column in range(2):
		var prefix: Dictionary = view.game._new_tile("ca", 1, 0)
		prefix.column = column
		prefix.row = Model.ROWS - 1
		prefixes.append(int(prefix.id))
		view.game.cells.append(prefix)
	view._sync_tiles()
	view._activate(fixture.id)
	var split: Dictionary = view.game.fusions[0]
	visual = view._fusion_visuals[str(split.attempt_id)]
	var parent_hue: float = float(visual.merged._gel.get_shader_parameter("palette_hue"))
	for parameter: String in ["palette_hue_a", "palette_hue_b"]:
		check(_hue_distance(float(visual.art._gel.get_shader_parameter(parameter)), parent_hue) < 0.00001,
			"both separating lobes start with the actual unsplit parent's color")
	var suffix_index: int = 0 if str(split.results[0].text) == "t" else 1
	var suffix = visual.parts[suffix_index]
	alternate = prefixes[1] if view._tiles[prefixes[1]].palette_index != suffix.palette_index else prefixes[0]
	check(view._press(-1, _center(view, alternate)), "a live matching prefix can be selected during a split")
	_advance(view, Model.SPLIT_SECONDS * 0.5)
	check(suffix.palette_index == view._tiles[alternate].palette_index,
		"a split child refreshes its material when a live prefix changes its completion hint")
	var target_hue: float = float(suffix._gel.get_shader_parameter("palette_hue"))
	var parameter: String = "palette_hue_a" if suffix_index == 0 else "palette_hue_b"
	var midway: float = float(visual.art._gel.get_shader_parameter(parameter))
	check(_hue_distance(midway, parent_hue) > 0.00001 and _hue_distance(midway, target_hue) > 0.00001,
		"the split color transitions visibly between parent paint and the child's current hint")
	_advance(view, Model.SPLIT_SECONDS * 0.40)
	check(_hue_distance(float(visual.art._gel.get_shader_parameter(parameter)), target_hue) < 0.00001,
		"the separated liquid lobe reaches its child skin's hue before handover")
	_advance(view, Model.SPLIT_SECONDS * 0.11 + Model.SETTLE_SECONDS)
	check(view._tiles[int(split.results[suffix_index].id)].palette_index == view._tiles[alternate].palette_index,
		"the restored child keeps the active completion color when its temporary split skin disappears")
	view.cancel_input()


func _check_crowded_palette_separation(view) -> void:
	_reset(view)
	view.game.cells.clear()
	for index in range(18):
		var tile: Dictionary = view.game._new_tile("unpaired%d" % index, 1, 0)
		tile.column = index % Model.COLUMNS
		tile.row = Model.ROWS - 1 - floori(float(index) / Model.COLUMNS)
		view.game.cells.append(tile)
	view._sync_tiles()
	view._layout()
	var state: Dictionary = view.snapshot()
	var extended: bool = false
	for tile: Dictionary in state.tiles:
		extended = extended or int(tile.palette_index) >= 12
		check(float(tile.palette_hue) >= 0.0 and float(tile.palette_hue) < 1.0,
			"a crowded board keeps every actual shader hue inside its color range")
		for other: Dictionary in state.tiles:
			if int(other.id) <= int(tile.id):
				continue
			check(int(tile.palette_index) != int(other.palette_index)
				and _hue_distance(float(tile.palette_hue), float(other.palette_hue)) >= 0.01,
				"more than twelve unrelated roots retain measurably separated rendered hues")
	check(extended, "the crowded fixture exercises colors beyond the initial twelve-color palette")


func _check_merge_handover_stability(view) -> void:
	for reduced: bool in [false, true]:
		_reset(view, reduced)
		var ids: Array[int] = _install(view, ["ca", "t"])
		var target: Dictionary = view.game.cell(ids[1])
		var target_rect: Rect2 = view._tile_rect(target)
		var neighbor: Dictionary = view.game._new_tile("stay", 1, 0)
		neighbor.column = 1
		neighbor.row = Model.ROWS - 1
		view.game.cells.append(neighbor)
		view._sync_tiles()
		var neighbor_rect: Rect2 = view._tiles[int(neighbor.id)].get_rect()
		_drag(view, ids[0], ids[1])
		var id: int = _merged_id(view)
		_advance(view, Model.FUSION_SECONDS - 0.001)
		var final_fusion_rect: Rect2 = view._fusion_visuals.values()[0].merged.get_rect()
		check(final_fusion_rect.is_equal_approx(view._tile_rect(view.game.fusions[0].result)),
			"the final liquid union converges to its reserved result rectangle")
		_advance(view, 0.002)
		var tile: Dictionary = view.game.cell(id)
		var rest: Rect2 = view._tile_rect(tile)
		var rendered: Rect2 = view._tiles[id].get_rect()
		check(int(tile.row) == int(target.row) and is_equal_approx(rendered.position.y, target_rect.position.y),
			"a sparse upper merge hands its artwork over on the target row before support settlement")
		check(rendered.is_equal_approx(final_fusion_rect) and rendered.is_equal_approx(rest),
			"handover from fusion to the persistent body keeps exactly the same position and size")
		check(not view.game.is_settled(tile) and not view._settled(tile),
			"the stable merged body still waits for its input settling window")
		check(not view._press(-1, view.get_global_transform() * rendered.get_center()),
			"a tap cannot collect the newly handed-over word before input settles")
		view.cancel_input()
		_advance(view, Model.SETTLE_SECONDS * 0.45)
		tile = view.game.cell(id)
		check(not view.game.is_settled(tile) and view._tiles[id].get_rect().is_equal_approx(final_fusion_rect),
			"the first landing wobble retains the merge handover before a separate natural fall")
		_advance(view, Model.SETTLE_SECONDS * 0.75)
		tile = view.game.cell(id)
		check(int(tile.row) == Model.ROWS - int(tile.height) and bool(tile.get("falling", false)) and not view._settled(tile),
			"an unsupported merged body reserves the nearest supported row after its handover settles")
		if reduced:
			check(view._tiles[id].get_rect().is_equal_approx(view._tile_rect(tile)),
				"reduced motion moves the unsupported merge directly to its supported rectangle")
		else:
			check(view._tiles[id].position.y > final_fusion_rect.position.y and view._tiles[id].position.y < view._tile_rect(tile).position.y,
				"normal motion visibly accelerates the unsupported merged body through the empty space")
		_advance(view, Model.SETTLE_SECONDS)
		tile = view.game.cell(id)
		check(view.game.is_settled(tile) and _has_support(view.game.cells, tile)
			and view._tiles[id].get_rect().is_equal_approx(view._tile_rect(tile)),
			"the merged body's final artwork, support, and interactive target agree after landing")
		check(view._press(-1, _center(view, id)), "settled merged body accepts input at its visible position")
		view.cancel_input()
		_advance(view, 0.6)
		check(view._tiles[id].get_rect().is_equal_approx(view._tile_rect(tile)) and _has_support(view.game.cells, tile),
			"a completed automatic merge stays grounded after its landing ends")
		var unchanged: Dictionary = view.game.cell(int(neighbor.id))
		check(int(unchanged.column) == int(neighbor.column) and int(unchanged.row) == int(neighbor.row)
			and view._tiles[int(neighbor.id)].get_rect().is_equal_approx(neighbor_rect),
			"merging leaves unrelated settled jelly positions unchanged")


func _invalid_merge(view) -> Dictionary:
	var ids: Array[int] = _install(view, ["t", "ca"], [1, 2])
	var inputs: Array[Dictionary] = [view.game.cell(ids[0]), view.game.cell(ids[1])]
	_drag(view, ids[0], ids[1])
	var id: int = _merged_id(view)
	_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS * 2.0)
	check(view.game.cell(id).text == "tca" and not view.game.is_valid_word(view.game.cell(id)),
		"split fixture is an actual incorrect merge with two distinct chest-bearing inputs")
	return {"id": id, "ids": ids, "inputs": inputs}


func _check_split_pointer_recovery(view) -> void:
	for reduced: bool in [false, true]:
		for pointer: int in [-1, 7]:
			_reset(view, reduced)
			var fixture: Dictionary = _invalid_merge(view)
			var center: Vector2 = _center(view, fixture.id)
			check(view.game.can_split(view.game.cell(fixture.id)), "an invalid merged word can return to its last two inputs")
			check(view._press(pointer, center), "mouse and touch can press an invalid merged jelly")
			view._release(center)
			check(view.game.fusions.size() == 1 and view.game.fusions[0].operation == "split",
				"tapping an invalid merged jelly starts one distinct split operation")
			var split: Dictionary = view.game.fusions[0]
			check(int(split.a_id) == fixture.id and int(split.b_id) == fixture.id and split.results.size() == 2,
				"the splitting parent reserves both child destinations")
			check(not view._press(pointer, center), "a repeated tap cannot pick up the splitting parent")
			view._release(center)
			view._activate(fixture.id)
			check(view.game.fusions.size() == 1 and view.game.fusions[0].attempt_id == split.attempt_id,
				"repeated pointer and keyboard input cannot duplicate a split")
			_advance(view, Model.SPLIT_SECONDS * 0.5)
			check(view.game.cells.size() == 1 and view.game.cell(fixture.ids[0]).is_empty()
				and view.game.cell(fixture.ids[1]).is_empty(), "children remain reserved until the split animation completes")
			var visual: Dictionary = view._fusion_visuals[str(split.attempt_id)]
			check(visual.parts.size() == 2, "the split has two separate child skins")
			for index in range(2):
				var part = visual.parts[index]
				check(part.is_visible_in_tree(), "both restored child skins are visible during separation")
				if reduced:
					check(part.get_rect().is_equal_approx(view._tile_rect(split.results[index])) and part.scale == Vector2.ONE,
						"reduced motion crossfades children at steady final positions and scale")
				else:
					check(not part.get_rect().is_equal_approx(view._tile_rect(split.results[index])),
						"normal motion visibly separates each child before it reaches the reserved destination")
			check(not visual.art.visible if reduced else visual.art.visible and visual.art.stage == "split",
				"the liquid separation artwork follows the selected motion preference")
			check(heard.is_empty() and payouts.is_empty() and attempts.is_empty() and cues.count("pop") == 0,
				"splitting never speaks a word, records an answer, or plays the collection disappearance")
			check(not view.snapshot().word_reveal.visible, "splitting an invalid word never opens the collected-word reveal")
			_advance(view, Model.SPLIT_SECONDS * 0.5 - 0.001)
			var final_rects: Dictionary = {}
			for index in range(2):
				var final_rect: Rect2 = visual.parts[index].get_rect()
				final_rects[int(split.results[index].id)] = final_rect
				check(final_rect.is_equal_approx(view._tile_rect(split.results[index])), "each split skin reaches its exact reserved rectangle before handover")
			_advance(view, 0.002 + Model.SETTLE_SECONDS)
			check(view.game.cells.size() == 2 and view.game.cell(fixture.id).is_empty(), "one invalid parent returns to exactly two children")
			for original: Dictionary in fixture.inputs:
				var restored: Dictionary = view.game.cell(int(original.id))
				check(not restored.is_empty() and restored.text == original.text and restored.mass == original.mass
					and restored.fragments == original.fragments and int(restored.get("skin", restored.id)) == int(original.get("skin", original.id)),
					"each child retains its original identity, text, mass, skin, and individual fragment count")
				check(view._tiles[int(original.id)].visible_fragment_badges() == int(original.fragments)
					and view._board.encloses(view._tiles[int(original.id)].get_rect()), "restored child artwork and all chest markers fit the board")
				check(view._tiles[int(original.id)].get_rect().is_equal_approx(final_rects[int(original.id)]),
					"the persistent child retains its split animation's final position and size")
				check(_has_support(view.game.cells, restored), "a split child lands on the floor or another body without floating over an empty row")
				check(not view.game.can_split(restored), "a restored single root cannot split further")
			check(view._fusion_visuals.is_empty(), "split completion clears transient child artwork")
			check(not view._tiles[fixture.ids[0]].get_rect().intersects(view._tiles[fixture.ids[1]].get_rect()),
				"restored child hit targets do not overlap")
			check(view.game.collected_coins == 0 and view.game.fragment_count == 0 and view.game.cleared_pairs == 0,
				"split conserves rewards without collecting the carried fragments")
			_drag(view, fixture.ids[1], fixture.ids[0])
			var corrected: int = _merged_id(view)
			_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS * 2.0)
			check(view.game.cell(corrected).text == "cat" and not view.game.can_split(view.game.cell(corrected)),
				"the restored inputs can be corrected into a valid collectible word")
			center = _center(view, corrected)
			view._press(pointer, center)
			view._release(center)
			check(view.game.fusions.size() == 1 and view.game.fusions[0].operation == "collect", "valid-word taps still collect instead of splitting")
			_advance(view, Model.COLLECT_SECONDS)
			check(payouts.size() == 1 and payouts[0].amount == 100 and payouts[0].fragments == 3
				and heard.size() == 1 and attempts.size() == 1, "correcting and collecting pays and teaches exactly once")


func _has_support(cells: Array, child: Dictionary) -> bool:
	var bottom: int = int(child.row) + int(child.height)
	if bottom == Model.ROWS:
		return true
	for other: Dictionary in cells:
		if int(other.id) != int(child.id) and int(other.row) == bottom \
			and int(other.column) < int(child.column) + int(child.width) \
			and int(other.column) + int(other.width) > int(child.column):
			return true
	return false


func _check_split_cancel_and_pause(view) -> void:
	_reset(view)
	var fixture: Dictionary = _invalid_merge(view)
	var center: Vector2 = _center(view, fixture.id)
	view._press(-1, center)
	view.cancel_input()
	view._release(center)
	check(view.game.fusions.is_empty() and not view.game.cell(fixture.id).is_empty(), "canceling a press cannot split its invalid word")
	view._press(-1, center)
	view.pause(true)
	view._release(center)
	check(view.game.fusions.is_empty(), "pausing between press and release cancels a possible split")
	view.pause(false)
	view._press(-1, center)
	var empty_point: Vector2 = view.get_global_transform() * (view._board.position + Vector2(view._pitch * 2.5, view._pitch * 0.5))
	view._move(empty_point)
	view._release(empty_point)
	check(view.game.fusions.is_empty() and not view.game.cell(fixture.id).is_empty(), "dragging an invalid word into empty space never acts as a split tap")
	_advance(view, Model.SETTLE_SECONDS + 0.01)
	center = _center(view, fixture.id)
	view._press(7, center)
	view._release(center)
	_advance(view, Model.SPLIT_SECONDS * 0.4)
	var split: Dictionary = view.game.fusions[0]
	var elapsed: float = float(split.elapsed)
	var parts: Array = view._fusion_visuals[str(split.attempt_id)].parts
	var before: Array[Rect2] = [parts[0].get_rect(), parts[1].get_rect()]
	view.pause(true)
	_advance(view, 1.0)
	check(view.game.fusions.size() == 1 and is_equal_approx(float(view.game.fusions[0].elapsed), elapsed), "pause freezes a split before either child is restored")
	check(parts[0].get_rect().is_equal_approx(before[0]) and parts[1].get_rect().is_equal_approx(before[1]), "pause also freezes both visible separation poses")
	var previous_texture: Texture2D = view._chest_texture
	view.apply_theme(Data.theme("winter"), data.chests)
	check(view._chest_texture != previous_texture and is_equal_approx(float(view.game.fusions[0].elapsed), elapsed),
		"changing theme during a paused split updates its artwork without advancing the split")
	var visual: Dictionary = view._fusion_visuals[str(split.attempt_id)]
	for body in [visual.merged, parts[0], parts[1]]:
		check(body._fragment_texture == view._chest_texture and body._fragment_badges[0].texture == view._chest_texture,
			"the paused split parent and both child fragment markers use the new theme")
	var cached_texture: Texture2D = view._chest_for_theme("ocean")
	view._apply_chest_texture(cached_texture)
	for body in [visual.merged, parts[0], parts[1]]:
		check(body._fragment_badges[0].texture == cached_texture, "a refreshed cached chest texture reaches every split ghost")
	check(not view._press(-1, center), "paused splitting rejects new pointer input")
	view.pause(false)
	_advance(view, Model.SPLIT_SECONDS + Model.SETTLE_SECONDS)
	check(view.game.fusions.is_empty() and view.game.cells.size() == 2 and heard.is_empty() and payouts.is_empty(), "resuming a paused split restores its children without rewarding or speaking")


func _check_split_keyboard_and_nested_merge(view) -> void:
	_reset(view)
	var fixture: Dictionary = _invalid_merge(view)
	var extra: Dictionary = view.game._new_tile("x", 1, 1)
	extra.column = 0
	extra.row = 6
	view.game.cells.append(extra)
	view._sync_tiles()
	view._activate(int(extra.id))
	view._activate(fixture.id)
	check(view.game.fusions.size() == 1 and view.game.fusions[0].operation == "merge",
		"an existing keyboard source merges into an invalid word instead of splitting the target")
	var nested: int = _merged_id(view)
	_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS * 2.0)
	view._activate(nested)
	check(view.game.fusions.size() == 1 and view.game.fusions[0].operation == "split", "keyboard activation without a held source splits an invalid word")
	_advance(view, Model.SPLIT_SECONDS + Model.SETTLE_SECONDS)
	check(view.game.cells.size() == 2 and view.game.can_split(view.game.cell(fixture.id)), "one split restores its invalid merged child with its nested ancestry")
	_drag(view, fixture.id, int(extra.id))
	check(view.game.fusions.size() == 1 and view.game.fusions[0].operation == "merge", "dragging a restored invalid merged child continues to merge")
	var remerged: int = _merged_id(view)
	_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS * 2.0)
	view._activate(remerged)
	_advance(view, Model.SPLIT_SECONDS + Model.SETTLE_SECONDS)
	view._activate(fixture.id)
	_advance(view, Model.SPLIT_SECONDS + Model.SETTLE_SECONDS)
	var actual_ids: Array[int] = []
	var mass: int = 0
	var fragments: int = 0
	for tile: Dictionary in view.game.cells:
		actual_ids.append(int(tile.id))
		mass += int(tile.mass)
		fragments += int(tile.fragments)
	var expected_ids: Array[int] = [fixture.ids[0], fixture.ids[1], int(extra.id)]
	actual_ids.sort()
	expected_ids.sort()
	check(actual_ids == expected_ids and mass == 3 and fragments == 4,
		"nested split and remerge restores each original root once and conserves all mass and fragments")
	check(view.game.collected_coins == 0 and view.game.fragment_count == 0 and heard.is_empty()
		and payouts.is_empty() and attempts.is_empty(), "nested recovery never grants coins, chest progress, or learning credit")


func _check_split_keyboard_source_shortcut(view) -> void:
	for keycode: Key in [KEY_ENTER, KEY_SPACE]:
		_reset(view)
		var fixture: Dictionary = _invalid_merge(view)
		var extra: Dictionary = view.game._new_tile("x", 1, 0)
		extra.column = 0
		extra.row = 6
		view.game.cells.append(extra)
		view._sync_tiles()
		view._tiles[fixture.id].grab_focus()
		var event := InputEventKey.new()
		event.keycode = keycode
		event.pressed = true
		event.shift_pressed = true
		view._input(event)
		check(view._keyboard_source == fixture.id and view.game.fusions.is_empty(),
			"Shift+Enter and Shift+Space select an invalid merged jelly as a source without splitting")
		view._activate(int(extra.id))
		check(view.game.fusions.size() == 1 and view.game.fusions[0].operation == "merge"
			and int(view.game.fusions[0].a_id) == fixture.id, "the next keyboard activation merges the selected invalid source")
		var merged: int = _merged_id(view)
		_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS * 2.0)
		view._activate(merged)
		check(view.game.fusions.size() == 1 and view.game.fusions[0].operation == "split", "plain activation still splits after keyboard source selection is consumed")


func _check_repeat_merge_and_wrap(view) -> void:
	_reset(view)
	var ids: Array[int] = _install(view, ["cat", "erpillar"], [2, 3], [2, 5])
	check(view.game.is_valid_word(view.game.cell(ids[0])), "a prebuilt valid word remains eligible to drag")
	_drag(view, ids[0], ids[1])
	var id: int = _merged_id(view)
	_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS * 2.0)
	var cell: Dictionary = view.game.cell(id)
	check(cell.text == "caterpillar" and cell.mass == 7 and cell.fragments == 5, "dragging a merged word builds a larger persistent word and retains every fragment")
	check(cell.height == 2 and view._tiles[id].size.x > view._tiles[id].size.y, "large jelly grows across multiple grid rows")
	check(_has_support(view.game.cells, cell) and not bool(cell.get("placement_locked", false))
		and view._tiles[id].get_rect().is_equal_approx(view._tile_rect(cell)),
		"a wrapped automatic merge lands on support with its full painted footprint and no implicit position lock")
	check(view._tiles[id]._label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART and view._tiles[id]._label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING,
		"large jelly uses wrapping without ellipsis")
	check(view._tiles[id].visible_fragment_badges() == 5 and view._board.encloses(view._tiles[id].get_rect()), "large body and its fragment stack stay in the six-column board")
	var label: Label = view._tiles[id]._label
	check(Rect2(Vector2.ZERO, view._tiles[id].size).encloses(label.get_rect()), "wrapped label stays within the painted body's layout bounds")
	var extra: Dictionary = view.game._new_tile("extra", 1, 1)
	extra.column = 0
	extra.row = 0
	view.game.cells.append(extra)
	view._sync_tiles()
	_drag(view, id, int(extra.id))
	var again: int = _merged_id(view)
	_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS * 2.0)
	check(view.game.cell(again).text == "caterpillarextra" and view.game.cell(again).word.is_empty(), "a large valid jelly can merge onward into an unfinished build")
	check(not view._tiles[again]._picture.visible and view._tiles[again].visible_fragment_badges() == 6, "unfinished larger build hides its old image while preserving six markers")


func _check_variable_outline(view) -> void:
	_reset(view, true)
	var ids: Array[int] = _install(view, ["cat", "t"], [], [3, 1])
	var source = view._tiles[ids[0]]
	var target = view._tiles[ids[1]]
	var source_outline: PackedVector2Array = source.contact_outline()
	var min_x: float = INF
	var max_x: float = -INF
	for point: Vector2 in source_outline:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
	check(max_x - min_x > target.size.x * 2.5, "painted contact outline expands with the merged body's width")
	view._press(-1, _center(view, ids[0]))
	var destination: Vector2 = target.get_rect().get_center()
	# Search along the horizontal center line from separation toward actual skin
	# overlap; the painted outline is the independent physical contact oracle.
	var first_contact: Vector2 = Vector2.ZERO
	for index in range(100, -1, -1):
		var point: Vector2 = destination + Vector2((source.size.x + target.size.x) * 0.5 * float(index) / 100.0, 0)
		view._move(view.get_global_transform() * point)
		var overlaps: bool = not Geometry2D.intersect_polygons(source.contact_outline(), target.contact_outline()).is_empty()
		check((view._target == ids[1]) == overlaps, "variable-size target selection agrees with painted silhouette contact")
		if overlaps:
			first_contact = point
			break
	check(not first_contact.is_zero_approx() and not target.get_rect().has_point(first_contact), "a wide jelly contacts while its held center is outside the target")
	view._release(view.get_global_transform() * first_contact)
	check(view.game.fusions.size() == 1, "wide-body edge contact commits a merge")


func _check_cancel_and_pause(view) -> void:
	_reset(view)
	var ids: Array[int] = _install(view, ["ca", "t"])
	view._press(-1, _center(view, ids[0]))
	view._move(_center(view, ids[1]))
	view.cancel_input()
	view._release(_center(view, ids[1]))
	check(view.game.fusions.is_empty() and payouts.is_empty(), "canceled contact cannot merge or collect")
	_drag(view, ids[0], ids[1])
	var id: int = _merged_id(view)
	_advance(view, 0.2)
	view.pause(true)
	var before: float = float(view.game.fusions[0].elapsed)
	_advance(view, 1.0)
	check(view.game.fusions.size() == 1 and is_equal_approx(float(view.game.fusions[0].elapsed), before), "pause freezes fusion presentation and model time")
	check(not view._press(-1, _center(view, ids[0])), "paused view rejects new pointer input")
	view.pause(false)
	_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS * 2.0)
	check(view.game.cells.size() == 1 and view.game.cell(id).text == "cat", "fusion resumes to its persistent word")
	view._press(-1, _center(view, id))
	view.pause(true)
	view._release(_center(view, id))
	check(view.game.fusions.is_empty() and payouts.is_empty(), "pausing between press and release cancels a collection tap")
	view.pause(false)
	view.stop()
	check(not view._configured and view._tiles.is_empty() and view._fusion_visuals.is_empty(), "leaving the mode clears transient bodies and fusion visuals")


func _check_reduced_motion(view) -> void:
	_reset(view, true)
	var ids: Array[int] = _install(view, ["ca", "t"], [1, 1])
	_drag(view, ids[0], ids[1])
	var id: int = _merged_id(view)
	_advance(view, 0.2)
	check(view._fusion_visuals.size() == 1 and not view._fusion_visuals.values()[0].art.visible, "reduced motion removes the animated liquid union shader")
	check(view._fusion_visuals.values()[0].merged.visible and view._fusion_visuals.values()[0].merged.scale == Vector2.ONE, "reduced motion keeps the prospective word readable at steady scale")
	_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS * 2.0)
	var center: Vector2 = _center(view, id)
	view._press(-1, center)
	view._release(center)
	_advance(view, 0.1)
	check(view._fusion_visuals.values()[0].merged.scale == Vector2.ONE, "reduced-motion collection fades without squeezing")
	_advance(view, Model.COLLECT_SECONDS)
	check(view.game.collected_coins == 100 and view.game.fragment_count == 2 and view._loot_flights.is_empty(), "reduced motion preserves rewards while suppressing fragment travel")


func _check_wallet_failure(view) -> void:
	_reset(view)
	var ids: Array[int] = _install(view, ["cat"], [2], [2])
	view.credit_collection = func(_id: String, _amount: int) -> Dictionary: return {"ok": false}
	var center: Vector2 = _center(view, ids[0])
	view._press(-1, center)
	view._release(center)
	_advance(view, Model.COLLECT_SECONDS)
	check(view.game.cells.size() == 1 and view._tiles[ids[0]].visible and view.game.collected_coins == 0,
		"failed wallet save restores a visible collectible word without losing fragments")
	check(view._notice.visible and payouts.is_empty(), "wallet failure is recoverable and does not emit a successful reward")
	view.credit_collection = func(_id: String, _amount: int) -> Dictionary: return {"ok": true}
	view._press(-1, center)
	view._release(center)
	_advance(view, Model.COLLECT_SECONDS)
	check(view.game.cells.is_empty() and payouts.size() == 1 and view.game.fragment_count == 2, "visible retry collects once after persistence recovers")


func _check_keyboard(view) -> void:
	_reset(view)
	var ids: Array[int] = _install(view, ["ca", "t"])
	view._activate(ids[0])
	check(view._keyboard_source == ids[0] and view.game.fusions.is_empty(), "keyboard activation selects a root")
	view._activate(ids[1])
	check(view.game.fusions.size() == 1 and view._keyboard_source == -1, "keyboard second activation merges in source-target order")
	var id: int = _merged_id(view)
	_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS * 2.0)
	view._activate(id)
	_advance(view, Model.COLLECT_SECONDS)
	check(payouts.size() == 1 and view.game.collected_coins == 100, "keyboard activation can collect a valid merged word")


func _check_arrival_packet(view) -> void:
	for reduced: bool in [false, true]:
		for automatic: bool in [false, true]:
			for dimensions: Vector2 in [Vector2(1473, 1175), Vector2(768, 1024), Vector2(390, 844), Vector2(568, 320), Vector2(1000, 720), Vector2(390, 700)]:
				view.size = dimensions
				_reset(view, reduced)
				var packet: Array = view.game.upcoming.duplicate(true)
				var origins: Dictionary = {}
				var colors: Dictionary = {}
				for preview in view._preview_tiles:
					origins[preview.tile_id] = preview.get_rect()
					colors[preview.tile_id] = preview.palette_index
				if automatic:
					view.game.spawn_elapsed = view.game.spawn_interval - 0.001
					_advance(view, 0.001)
				else:
					view._drop_next(int(packet[0].id))
				check(view.game.cells.size() == Model.INITIAL_SETTLED_TILES + Model.DROP_COUNT, "manual and timed release each commit the six preview bodies")
				var first_id: int = int(packet[0].id)
				var last_id: int = int(packet[-1].id)
				var first_contact: float = Model.arrival_contact_at(view.game.cell(first_id))
				var final_ready: float = 0.0
				for index in range(packet.size()):
					var id: int = int(packet[index].id)
					var cell: Dictionary = view.game.cell(id)
					check(not cell.is_empty() and bool(cell.arrival) and not view.game.is_settled(cell),
						"every preview ID survives release and remains unavailable through its arrival")
					check(int(cell.arrival_index) == index, "the wave preserves the original preview order")
					check(cell.text == packet[index].text and cell.fragments == packet[index].fragments
						and view._tiles[id]._label.text == packet[index].text,
						"falling roots retain their exact letters and carried chest fragments")
					check(view._tiles[id].palette_index == colors[id], "preview partner colors survive handover into the falling bodies")
					var expected: Rect2 = view._tile_rect(cell) if reduced else origins[id]
					check(view._tiles[id].get_rect().is_equal_approx(expected),
						"release starts at the visible preview rectangle, or lands directly with reduced motion")
					view._activate(id)
					check(view._keyboard_source == -1 and view.game.fusions.is_empty(),
						"keyboard activation cannot take an arriving body before its recovery completes")
					final_ready = maxf(final_ready, Model.settle_duration(cell))
				_advance(view, 0.02)
				if not reduced:
					check(view._tiles[first_id].get_rect().get_center().y > Rect2(origins[first_id]).get_center().y,
						"the first preview body immediately begins descending under gravity")
					check(view._tiles[last_id].get_rect().is_equal_approx(origins[last_id]),
						"the final preview body waits its short stagger before entering the well")
				var paused_rect: Rect2 = view._tiles[first_id].get_rect()
				var paused_age: float = float(view.game.cell(first_id).age)
				view.pause(true)
				_advance(view, 0.6)
				check(view._tiles[first_id].get_rect().is_equal_approx(paused_rect)
					and is_equal_approx(float(view.game.cell(first_id).age), paused_age),
					"pausing preserves the airborne body and its authoritative arrival time")
				view.pause(false)
				var previous_y: float = Rect2(origins[first_id]).get_center().y
				var previous_travel: float = 0.0
				for fraction: float in [0.25, 0.5, 0.75]:
					_advance(view, first_contact * fraction - float(view.game.cell(first_id).age))
					var body: Rect2 = view._tiles[first_id].get_rect()
					if not reduced:
						var travel: float = body.get_center().y - previous_y
						check(travel > previous_travel and body.get_center().y < view._tile_rect(view.game.cell(first_id)).get_center().y,
							"equal time slices cover increasing distance while the body is visibly airborne")
						previous_travel = travel
						previous_y = body.get_center().y
					else:
						check(body.is_equal_approx(view._tile_rect(view.game.cell(first_id))),
							"reduced motion leaves the arriving body stationary on its reserved support")
					check(not view.game.is_settled(view.game.cell(first_id)), "an airborne or recovering body is not ready for play")
				var resize_age: float = float(view.game.cell(first_id).age)
				view.size = Vector2(700, 470) if dimensions.x < dimensions.y else Vector2(390, 700)
				view._layout()
				check(is_equal_approx(float(view.game.cell(first_id).age), resize_age), "resize never rewinds the arrival timeline")
				var resized_body: Rect2 = view._tiles[first_id].get_rect()
				var resized_target: Rect2 = view._tile_rect(view.game.cell(first_id))
				var coherent_route: bool = resized_body.is_equal_approx(resized_target) if reduced else resized_body.get_center().y <= resized_target.get_center().y
				check(coherent_route and view._tiles[first_id]._label.text == packet[0].text,
					"resize keeps the same visible letters on a coherent route to the new well: reduced=%s, automatic=%s, dimensions=%s, body_y=%.9f, target_y=%.9f, body=%s, target=%s" %
					[reduced, automatic, dimensions, resized_body.get_center().y, resized_target.get_center().y, resized_body, resized_target])
				_advance(view, final_ready + 0.001 - float(view.game.cell(first_id).age))
				for original: Dictionary in packet:
					var id: int = int(original.id)
					check(view.game.is_settled(view.game.cell(id))
						and view._tiles[id].get_rect().is_equal_approx(view._tile_rect(view.game.cell(id))),
						"every supplied jelly finishes planted exactly on its reserved board cell")
				check(view.game.generated_tiles == Model.INITIAL_SETTLED_TILES + Model.DROP_COUNT and view.game.merged_count == 0 and payouts.is_empty(),
					"arrival, pause and resize preserve the supply and reward ledgers")
	view.size = Vector2(1000, 720)


func _check_staggered_preview_refill(view) -> void:
	for reduced: bool in [false, true]:
		for dimensions: Vector2 in [Vector2(1000, 720), Vector2(390, 844)]:
			view.size = dimensions
			_reset(view, reduced)
			var packet: Array = view.game.upcoming.duplicate(true)
			var origins: Array[Rect2] = []
			for preview in view._preview_tiles:
				origins.append(preview.get_rect())
			view._drop_next(int(packet[0].id))
			_advance(view, 0.40)
			var waiting: int = 0
			var refilled: int = 0
			for index in range(packet.size()):
				var outgoing: Dictionary = view.game.cell(int(packet[index].id))
				var preview = view._preview_tiles[index]
				if reduced:
					check(preview.visible and is_equal_approx(preview.modulate.a, 1.0),
						"reduced motion shows the next preview immediately without a delayed fade")
				elif Model.arrival_delay(outgoing) > float(outgoing.age):
					waiting += 1
					check(not preview.visible and view._tiles[int(outgoing.id)].get_rect().is_equal_approx(origins[index]),
						"a waiting root owns its original tray slot until departure")
				elif float(outgoing.age) - Model.arrival_delay(outgoing) >= 0.36:
					refilled += 1
					check(preview.visible and is_equal_approx(preview.modulate.a, 1.0)
						and preview.tile_id == int(view.game.upcoming[index].id),
						"a cleared slot reveals its next committed root without waiting for the whole wave")
			if not reduced:
				check(waiting >= 2 and refilled >= 1,
					"staggered release visibly combines falling, waiting, and replenished roots")
			check(not view.game.can_drop_now(), "partially refilled supply cannot release a second batch during descent")
	view.size = Vector2(1000, 720)


func _check_arrival_land_timing(view) -> void:
	for reduced: bool in [false, true]:
		for row: int in [0, Model.ROWS - 1]:
			_reset(view, reduced)
			var ids: Array[int] = _install(view, ["ca"])
			var arriving: Dictionary = view.game.cells[0]
			arriving.row = row
			arriving.age = 0.0
			arriving.arrival = true
			arriving.arrival_index = 5 if row == 0 else 0
			arriving.settling = true
			arriving.falling_rows = row + 1
			view._rest_rects.clear()
			view._reflow.clear()
			view._sync_positions()
			var contact: float = Model.arrival_contact_at(arriving)
			var ready: float = Model.settle_duration(arriving)
			_advance(view, contact - 0.001)
			check(cues.count("land") == 0 and not view.game.is_settled(view.game.cell(ids[0])),
				"an arriving root stays silent until its painted body reaches support")
			view.pause(true)
			_advance(view, 0.5)
			check(cues.count("land") == 0 and not view.game.is_settled(view.game.cell(ids[0])),
				"pausing just before contact cannot advance or emit the landing cue")
			view.pause(false)
			_advance(view, 0.002)
			check(cues.count("land") == 1 and not view.game.is_settled(view.game.cell(ids[0])),
				"landing sounds at physical contact before the planted recovery completes")
			check(view._tiles[ids[0]].get_rect().is_equal_approx(view._tile_rect(view.game.cell(ids[0]))),
				"the arrival body reaches its board rectangle when its landing cue plays")
			_advance(view, ready - float(view.game.cell(ids[0]).age) - 0.001)
			view._activate(ids[0])
			check(not view.game.is_settled(view.game.cell(ids[0])) and view._keyboard_source == -1,
				"the planted squash and rebound remain input locked until recovery finishes")
			_advance(view, 0.002)
			check(view.game.is_settled(view.game.cell(ids[0])), "the body becomes playable exactly after its landing recovery")
			_advance(view, 1.5)
			check(cues.count("land") == 1, "the inherited falling-row timeline cannot replay a late impact")


func _fill_well(view) -> void:
	var occupied: Dictionary = view.game._occupied()
	for row in range(Model.ROWS):
		for column in range(Model.COLUMNS):
			if occupied.has(row * Model.COLUMNS + column):
				continue
			var filler: Dictionary = view.game._new_tile("x", 1, 0)
			filler.column = column
			filler.row = row
			view.game.cells.append(filler)
	view._sync_tiles()
	view._layout()
	_advance(view, 0.01)
	check(view.game.full_elapsed >= 0.0 and cues.count("danger") == 1,
		"a settled full well starts the real danger warning before relief")


func _check_danger_ends_when_collecting(view) -> void:
	_reset(view)
	var ids: Array[int] = _install(view, ["cat"], [], [2])
	_fill_well(view)
	var center: Vector2 = _center(view, ids[0])
	view._press(-1, center)
	view._release(center)
	_advance(view, Model.COLLECT_SECONDS - 0.001)
	check(cues.count("danger_end") == 0 and view.game.full_elapsed >= 0.0,
		"danger remains active while the collected word still occupies its cells")
	_advance(view, 0.002)
	check(cues.count("danger_end") == 1 and view.game.full_elapsed < 0.0 and view.game._has_free_cell(),
		"successful collection stops danger in the same frame that its footprint is freed")
	check(payouts.size() == 1 and payouts[0].amount == 100,
		"danger relief does not duplicate or delay the collection reward")
	_advance(view, 0.6)
	check(cues.count("danger") == 1 and cues.count("danger_end") == 1,
		"a relieved well cannot repeat the old danger pulse or stop event")


func _check_danger_ends_when_merge_frees_space(view) -> void:
	_reset(view)
	var ids: Array[int] = _install(view, ["cater", "pillar"], [], [4, 4])
	# The source must reopen the roof; an internal cavity cannot receive a fall.
	view.game.cells[0].row = 0
	_fill_well(view)
	view._activate(ids[0])
	view._activate(ids[1])
	check(view.game.fusions.size() == 1, "a full well still accepts a persistent large-word merge")
	_advance(view, Model.FUSION_SECONDS - 0.001)
	check(cues.count("danger_end") == 0 and view.game.full_elapsed >= 0.0,
		"the active merge keeps danger until its input footprints are replaced")
	_advance(view, 0.002)
	check(cues.count("danger_end") == 1 and view.game.full_elapsed < 0.0 and view.game._has_free_cell(),
		"a merge that reopens the top entrance stops the warning at its completion boundary")
	check(payouts.is_empty(), "merge danger relief never pays coins before collection")
	_advance(view, 0.6)
	check(cues.count("danger") == 1 and cues.count("danger_end") == 1,
		"a space-freeing merge does not leave a warning pulse running")
