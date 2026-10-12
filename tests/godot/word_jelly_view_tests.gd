extends SceneTree

const Jelly = preload("res://scripts/word_jelly.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
const Data = preload("res://scripts/game_data.gd")

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
	_check_merge_handover_stability(view)
	_check_collect_and_fragments(view)
	_check_repeat_merge_and_wrap(view)
	_check_variable_outline(view)
	_check_cancel_and_pause(view)
	_check_reduced_motion(view)
	_check_wallet_failure(view)
	_check_keyboard(view)
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
	for dimensions: Vector2 in [Vector2(1000, 720), Vector2(390, 700), Vector2(568, 260)]:
		view.size = dimensions
		_reset(view)
		var state: Dictionary = view.snapshot()
		check(state.columns == 6 and state.rows == 8 and state.tiles.size() == 12, "opening contains twelve settled roots in six columns")
		check(state.preview.slots.size() == 6 and state.preview.enabled, "six upcoming roots have a working manual drop")
		check(view._board.position.x >= 0 and view._board.position.y >= 0 and view._board.end.x <= dimensions.x + 0.1
			and view._board.end.y <= dimensions.y + 0.1, "board fits portrait and landscape bounds")
		for tile: Dictionary in state.tiles:
			check(tile.settled and tile.visible and not tile.picture_visible, "opening root shows text without a word picture")
			check(view._tiles[int(tile.id)]._label.text == tile.text, "root label matches its part")
			check(view._board.encloses(view._tile_rect(tile)), "root rectangle stays inside the well")
		for tile in view._preview_tiles:
			check(tile.visible and view._preview_rect.encloses(tile.get_rect()), "preview parts remain within their drop control")
		_check_preview_label_height(view)
	view.size = Vector2(1000, 720)


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
		_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS)
		check(view.game.cell(id).text == "cat" and view._tiles.has(id), "edge merge becomes one persistent word")
		check(view._tiles[id]._picture.is_visible_in_tree() and view._tiles[id]._picture.texture != null, "a valid merge displays its production word image")
		check(payouts.is_empty() and attempts.is_empty(), "revealing the image grants nothing until the word is collected")


func _check_collect_and_fragments(view) -> void:
	_reset(view)
	var ids: Array[int] = _install(view, ["ca", "t"], [1, 1])
	_drag(view, ids[0], ids[1])
	var id: int = _merged_id(view)
	_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS)
	var tile = view._tiles[id]
	check(tile.visible_fragment_badges() == 2 and tile._fragment_badges[0].visible and tile._fragment_badges[1].visible, "both source chest markers remain independently visible on the merge")
	check(tile._label.text.to_lower() == "cat" and tile._label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, "merged word label remains complete")
	var center: Vector2 = _center(view, id)
	view._press(7, center)
	view._release(center)
	check(view.game.fusions.size() == 1 and view.game.fusions[0].operation == "collect", "touch tap begins a distinct disappearance operation")
	check(heard.size() == 1 and heard[0].id == "cat", "collect tap speaks the completed word once")
	_advance(view, Model.COLLECT_SECONDS)
	check(view.game.cells.is_empty() and payouts.size() == 1 and attempts.size() == 1, "tap collection removes the word and emits one reward and learning attempt")
	check(payouts[0].amount == 100 and payouts[0].fragments == 2 and payouts[0].origin.distance_to(center) < 0.1,
		"coin and fragment flight origin matches the tapped merged jelly")
	check(cues.count("pop") == 1 and view.game.fragment_count == 2, "collection retains the disappearance cue and all accumulated fragments")


func _check_merge_handover_stability(view) -> void:
	for reduced: bool in [false, true]:
		_reset(view, reduced)
		var ids: Array[int] = _install(view, ["ca", "t"])
		var target: Dictionary = view.game.cell(ids[1])
		var target_rect: Rect2 = view._tile_rect(target)
		var neighbor: Dictionary = view.game._new_tile("stay", 1, 0)
		neighbor.column = 1
		neighbor.row = 1
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
			"a sparse upper target keeps its merged word on the same row instead of sinking into empty rows")
		check(rendered.is_equal_approx(final_fusion_rect) and rendered.is_equal_approx(rest),
			"handover from fusion to the persistent body keeps exactly the same position and size")
		check(not view.game.is_settled(tile) and not view._settled(tile),
			"the stable merged body still waits for its input settling window")
		check(not view._press(-1, view.get_global_transform() * rendered.get_center()),
			"a tap cannot collect the newly handed-over word before input settles")
		view.cancel_input()
		_advance(view, Model.SETTLE_SECONDS)
		tile = view.game.cell(id)
		check(view.game.is_settled(tile) and view._tiles[id].get_rect().is_equal_approx(final_fusion_rect),
			"the input settling window cannot move the body away from its fusion destination")
		check(view._press(-1, _center(view, id)), "settled merged body accepts input at its visible position")
		view.cancel_input()
		_advance(view, 0.6)
		check(view._tiles[id].get_rect().is_equal_approx(final_fusion_rect), "a completed merge remains at its chosen height after settling")
		var unchanged: Dictionary = view.game.cell(int(neighbor.id))
		check(int(unchanged.column) == int(neighbor.column) and int(unchanged.row) == int(neighbor.row)
			and view._tiles[int(neighbor.id)].get_rect().is_equal_approx(neighbor_rect),
			"merging leaves unrelated settled jelly positions unchanged")


func _check_repeat_merge_and_wrap(view) -> void:
	_reset(view)
	var ids: Array[int] = _install(view, ["cat", "erpillar"], [2, 3], [2, 5])
	check(view.game.is_valid_word(view.game.cell(ids[0])), "a prebuilt valid word remains eligible to drag")
	_drag(view, ids[0], ids[1])
	var id: int = _merged_id(view)
	_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS)
	var cell: Dictionary = view.game.cell(id)
	check(cell.text == "caterpillar" and cell.mass == 7 and cell.fragments == 5, "dragging a merged word builds a larger persistent word and retains every fragment")
	check(cell.height == 2 and view._tiles[id].size.x > view._tiles[id].size.y, "large jelly grows across multiple grid rows")
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
	_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS)
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
	_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS)
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
	_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS)
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
	_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS)
	view._activate(id)
	_advance(view, Model.COLLECT_SECONDS)
	check(payouts.size() == 1 and view.game.collected_coins == 100, "keyboard activation can collect a valid merged word")


func _check_arrival_land_timing(view) -> void:
	for reduced: bool in [false, true]:
		for row: int in [0, Model.ROWS - 1]:
			_reset(view, reduced)
			var ids: Array[int] = _install(view, ["ca"])
			var arriving: Dictionary = view.game.cells[0]
			arriving.row = row
			arriving.age = 0.0
			arriving.arrival = true
			arriving.settling = true
			arriving.falling_rows = Model.ROWS - row
			view._rest_rects.clear()
			view._reflow.clear()
			view._sync_positions()
			_advance(view, Model.SETTLE_SECONDS - 0.001)
			check(cues.count("land") == 0 and not view.game.is_settled(view.game.cell(ids[0])),
				"an arriving root stays silent just before its visual settling boundary")
			view.pause(true)
			_advance(view, 0.5)
			check(cues.count("land") == 0 and not view.game.is_settled(view.game.cell(ids[0])),
				"pausing just before contact cannot advance or emit the landing cue")
			view.pause(false)
			_advance(view, 0.002)
			check(cues.count("land") == 1 and view.game.is_settled(view.game.cell(ids[0])),
				"landing sounds at the Word Jelly settling boundary for every arrival row and motion preference")
			check(view._tiles[ids[0]].get_rect().is_equal_approx(view._tile_rect(view.game.cell(ids[0]))),
				"the arrival body is visually at rest when its landing cue plays")
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
	_fill_well(view)
	view._activate(ids[0])
	view._activate(ids[1])
	check(view.game.fusions.size() == 1, "a full well still accepts a persistent large-word merge")
	_advance(view, Model.FUSION_SECONDS - 0.001)
	check(cues.count("danger_end") == 0 and view.game.full_elapsed >= 0.0,
		"the active merge keeps danger until its input footprints are replaced")
	_advance(view, 0.002)
	check(cues.count("danger_end") == 1 and view.game.full_elapsed < 0.0 and view.game._has_free_cell(),
		"a merge that frees board space stops the warning at its completion boundary")
	check(payouts.is_empty(), "merge danger relief never pays coins before collection")
	_advance(view, 0.6)
	check(cues.count("danger") == 1 and cues.count("danger_end") == 1,
		"a space-freeing merge does not leave a warning pulse running")
