extends SceneTree

const Jelly = preload("res://scripts/word_jelly.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
const Motion = preload("res://scripts/jelly_motion.gd")
const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")
const COIN_REWARD_SEED: int = 208
const LAYOUT_SIZES: Array[Vector2] = [Vector2(1473, 1175), Vector2(1366, 768), Vector2(1000, 720),
	Vector2(834, 1194), Vector2(768, 1024), Vector2(624, 1119), Vector2(393, 852), Vector2(390, 844),
	Vector2(390, 700), Vector2(844, 390), Vector2(568, 320), Vector2(568, 260), Vector2(320, 480), Vector2(320, 320)]

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
	larger.erase("morphology")
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
	_check_powerup_paused_resize(view)
	_check_concurrent_powerup_resize(view)
	await _check_long_word_label_visibility(view)
	_check_root_tap(view)
	_check_edge_drag(view)
	_check_reposition_release(view)
	_check_reposition_rejection(view)
	_check_reposition_lifecycle(view)
	_check_reposition_completed_word(view)
	_check_merge_handover_stability(view)
	_check_collect_and_fragments(view)
	await _check_fragment_badge_layout(view)
	_check_ordinary_collection(view)
	_check_collection_click_duration(view)
	_check_collect_button_growth(view)
	_check_batch_collection(view)
	_check_coarse_frame_batch_reveals(view)
	_check_batch_chest_queue(view)
	_check_batch_lifecycle(view)
	_check_batch_wallet_failure(view)
	_check_word_reveal(view)
	_check_word_reveal_levels(view)
	_check_word_reveal_control_clearance(view)
	_check_word_reveal_lifecycle(view)
	_check_collection_stack_fall(view)
	_check_dragged_support_fall(view)
	_check_release_after_support_collection(view)
	_check_coarse_frame_collection_landing(view)
	_check_word_pair_colors(view)
	_check_directional_palette_stability(view)
	_check_completion_hints(view)
	_check_ordered_completion_contact(view)
	_check_neutral_contact_targets(view)
	_check_invalid_body_combinations(view)
	_check_rejection_rim_reset(view)
	_check_neutral_contact_lifecycle(view)
	_check_completion_hint_targets(view)
	_check_completion_hint_lifecycle(view)
	_check_completion_hint_reduced_motion(view)
	_check_partial_word_colors(view)
	_check_fusion_palette_handover(view)
	_check_crowded_palette_separation(view)
	_check_repeat_merge_compact_body(view)
	_check_uniform_outline(view)
	_check_cancel_and_pause(view)
	_check_reduced_motion(view)
	_check_wallet_failure(view)
	_check_keyboard(view)
	_check_keyboard_rejection(view)
	_check_arrival_packet(view)
	_check_partial_preview_columns(view)
	_check_partial_preview_press_race(view)
	_check_preview_pull_handoff(view)
	_check_staggered_preview_refill(view)
	_check_immediate_preview_packets(view)
	_check_arrival_land_timing(view)
	_check_danger_ends_when_collecting(view)
	_check_danger_ends_when_merge_frees_space(view)
	view.free()
	await process_frame
	print("Word Jelly view: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _reset(view, reduced: bool = false, age: int = 3) -> void:
	check(view.configure(words, age, Data.theme("spring"), data.chests, reduced, 42), "Word Jelly configures with real art")
	view.set_process(false)
	view.game.spawn_interval = 10000.0
	# The first eligible Lv2 collection wins; Lv1 collections never roll for coins.
	view.game._coin_rng.seed = COIN_REWARD_SEED
	view.credit_collection = func(_id: String, _amount: int) -> Dictionary: return {"ok": true}
	view._layout()
	heard.clear()
	cues.clear()
	payouts.clear()
	attempts.clear()


func _fixture_tile(view, description: String, mass: int = 1, fragments: int = 0) -> Dictionary:
	var parts: PackedStringArray = description.split(":")
	var face: String = parts[0] if parts.size() > 1 else "merged" if mass > 1 else "root"
	var spelling: String = parts[1] if parts.size() > 1 else description
	var word: Dictionary = view.game._word_lookup.get(Model.normalize_word(spelling), {})
	var tile: Dictionary
	if face == "picture" and not word.is_empty():
		tile = view.game._new_picture_tile(word, fragments)
	elif face == "root" and not word.is_empty():
		tile = view.game._new_word_root(word, fragments)
	else:
		tile = view.game._new_tile(spelling, mass, fragments)
		if face == "merged" and not word.is_empty():
			view.game._set_merged_word(tile, word, int(parts[2]) if parts.size() > 2 else 1, true)
	tile.mass = mass
	tile.parts_count = mass
	return tile


func _install(view, pieces: Array[String], fragments: Array[int] = [], masses: Array[int] = []) -> Array[int]:
	view.game.cells.clear()
	var ids: Array[int] = []
	for index in range(pieces.size()):
		var tile: Dictionary = _fixture_tile(view, pieces[index], masses[index] if index < masses.size() else 1,
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
		check(state.columns == 5 and state.rows == 8 and state.tiles.size() == 15, "opening contains three full rows of five settled roots")
		check(state.preview.slots.size() == 5 and state.preview.enabled, "five upcoming roots have a working manual drop")
		check(view._preview_rect.end.y <= view._board.position.y,
			"the whole supply tray sits above the well in portrait and landscape")
		for index in range(1, view._preview_tiles.size()):
			check(is_equal_approx(view._preview_tiles[index].position.y, view._preview_tiles[0].position.y)
				and view._preview_tiles[index].position.x > view._preview_tiles[index - 1].position.x,
				"all five upcoming bodies form one horizontal row above the well")
		check(view._board.position.x >= 0 and view._board.position.y >= 0 and view._board.end.x <= dimensions.x + 0.1
			and view._board.end.y <= dimensions.y + 0.1, "board fits portrait and landscape bounds")
		var s: float = Style.ui_scale(view)
		var bottom: float = maxf(view._board.end.y, view.collect_button.get_rect().end.y)
		for button: Control in view.powerup_buttons.values():
			bottom = maxf(bottom, button.get_rect().end.y)
		check(is_equal_approx(bottom, dimensions.y - 12.0 / s),
			"game group at %s ends above twelve-pixel padding: actual %.3f, expected %.3f" % [dimensions, bottom, dimensions.y - 12.0 / s])
		check(view._preview_rect.position.y >= 0 and view.finish_button.get_rect().end.y <= dimensions.y,
			"bottom alignment preserves room for the complete preview and finish control")
		for tile: Dictionary in state.tiles:
			var cell: Dictionary = view.game.cell(int(tile.id))
			var pictured: bool = str(cell.jelly_kind) == "picture"
			check(tile.settled and tile.visible and bool(tile.picture_visible) == pictured, "opening faces distinguish whole roots from picture clues")
			check(view._tiles[int(tile.id)]._label.text == cell.display_text, "opening faces show the intended spelling or picture-only clue")
			var body: Rect2 = view._tile_rect(tile)
			check(view._board.encloses(body) and is_equal_approx(body.size.x, body.size.y),
				"root rectangle stays square and inside the five-column well")
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
			check(tile.visible and view._preview_rect.encloses(tile.get_rect()) and is_equal_approx(tile.size.x, tile.size.y),
				"preview parts remain square and within their drop control")
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
	var regions: Dictionary = {"well": board, "supply tray": tray, "chest meter": view.chest_meter_rect(),
		"Finish": view.finish_button.get_rect(), "Collect words": view.collect_button.get_rect()}
	for kind: String in view.powerup_buttons:
		regions[kind + " powerup"] = view.powerup_buttons[kind].get_rect()
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
	var collect: Rect2 = view.collect_button.get_rect()
	var auto_merge: Rect2 = view.powerup_buttons.auto_merge.get_rect()
	var divider: Rect2 = view._action_divider.get_rect()
	check(is_equal_approx(collect.position.x, auto_merge.position.x) and is_equal_approx(collect.size.x, auto_merge.size.x)
		and absf(auto_merge.position.y - collect.end.y - 20.0 / s) < 0.01,
		"Collect sits directly above Auto merge with a twenty-pixel separator band" + context)
	check(view._action_divider.visible and bounds.encloses(divider) and divider.size.y * s >= 1.0
		and divider.position.y > collect.end.y and divider.end.y < auto_merge.position.y,
		"a visible divider separates free collection from the paid tools" + context)
	check(view._action_divider.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"the divider is decorative and never intercepts game input" + context)
	check(tray.size.y * s >= 44.0 - 0.01 and view.finish_button.size.y * s >= 44.0 - 0.01,
		"manual drop and Finish retain forty-four-pixel target heights" + context)
	check(view.collect_button.size.y * s >= 44.0 - 0.01 and view.collect_button.size.x * s >= 44.0 - 0.01,
		"batch collection retains a forty-four-pixel target in every layout" + context)
	check(view.chest_meter_rect().size.x * s >= 44.0 - 0.01 and view.chest_meter_rect().size.y * s >= 44.0 - 0.01,
		"the standalone chest retains a forty-four-pixel target without covering the well" + context)
	for button: Control in view.powerup_buttons.values():
		check(button.size.x * s >= 44.0 - 0.01 and button.size.y * s >= 44.0 - 0.01,
			"each paid powerup retains its own forty-four-pixel target" + context)


func _check_preview_label_height(view) -> void:
	var marked: int = 0
	for tile in view._preview_tiles:
		if not tile.visible:
			continue
		var label: Label = tile._label
		var font: Font = label.get_theme_font("font")
		var pixels: int = label.get_theme_font_size("font_size")
		if tile.jelly_kind == "picture":
			check(not label.visible and tile._picture.visible and not tile.requires_read, "picture previews show their clue without spelling or Read")
		else:
			check(not label.text.is_empty() and label.visible, "root previews retain a visible label")
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
		if str(tile.text) == "cat" and str(tile.jelly_kind) == "root":
			source = int(tile.id)
		elif str(tile.text) == "cat" and str(tile.jelly_kind) == "picture":
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


func _check_powerup_paused_resize(view) -> void:
	var purchases: Array[Dictionary] = []
	view.purchase_powerup = func(receipt: String, kind: String, price: int) -> Dictionary:
		purchases.append({"receipt": receipt, "kind": kind, "price": price})
		return {"ok": true}
	for reduced: bool in [false, true]:
		for stage: String in ["drag", "fusion"]:
			view.size = Vector2(1000, 720)
			_reset(view, reduced)
			purchases.clear()
			_install(view, ["root:cat", "picture:cat"])
			view._activate_powerup("auto_merge")
			var fusion_elapsed: float = Model.POWERUP_FUSION_SECONDS * 0.5
			_advance(view, Model.POWERUP_DRAG_SECONDS * 0.5 if stage == "drag" else Model.POWERUP_DRAG_SECONDS + fusion_elapsed)
			check(view.game.powerup_snapshot().stage == stage,
				"responsive powerup coverage reaches the paid " + stage + " stage")
			view.pause(true)
			var frozen: Dictionary = view.game.powerup_snapshot()
			view.size = Vector2(390, 844)
			view._layout()
			var phone: Rect2 = Rect2(Vector2.ZERO, view.size).grow(0.01)
			check(view.game.powerup_snapshot() == frozen,
				"desktop-to-phone layout preserves the paused powerup clock and captured pair")
			if stage == "drag":
				var body = view._tiles[int(frozen.source_id)]
				var before: Vector2 = body.get_rect().get_center()
				check(phone.encloses(body.get_rect()), "paused automatic drag relocates its painted body inside the phone viewport")
				view._process(0.25)
				check(body.get_rect().get_center().is_equal_approx(before) and view.game.powerup_snapshot() == frozen,
					"paused responsive drag neither moves nor advances its paid clock")
				view.pause(false)
				_advance(view, Model.POWERUP_DRAG_SECONDS * 0.25)
				check(body.get_rect().get_center().distance_to(before) > 0.1,
					"resuming a resized automatic drag continues its existing travel")
			else:
				var fusion: Dictionary = view.game.fusions[0]
				var visual: Dictionary = view._fusion_visuals[str(fusion.attempt_id)]
				var contact: Vector2 = view._tile_rect(fusion.b).get_center()
				check(Vector2(visual.origin_a).is_equal_approx(contact) and Vector2(visual.origin_b).is_equal_approx(contact),
					"automatic union resolves both contact origins against the resized destination")
				check(phone.encloses(visual.merged.get_rect()), "the automatic merged-word artwork stays inside the phone viewport")
				if not reduced:
					for key: String in ["body_a", "body_b"]:
						var paint: Vector4 = visual.art._gel.get_shader_parameter(key)
						var center: Vector2 = visual.art.position + Vector2(paint.x, paint.y)
						check(phone.encloses(Rect2(center - Vector2(paint.z, paint.w) * 0.5, Vector2(paint.z, paint.w))),
							"each native gel lobe stays inside the resized phone instead of retaining desktop pixels")
				view._process(0.25)
				check(view.game.powerup_snapshot() == frozen and is_equal_approx(float(view.game.fusions[0].elapsed), fusion_elapsed),
					"paused responsive union preserves its normal fusion timeline")
				view.pause(false)
				_advance(view, Model.POWERUP_FUSION_SECONDS * 0.25)
				check(float(view.game.fusions[0].elapsed) > fusion_elapsed,
					"resuming a resized union advances the same already-paid fusion")
			_advance(view, 2.0)
			check(not view.game.powerup_active() and view.game.cells.size() == 1 and str(view.game.cells[0].text) == "cat"
				and int(view.game.merged_count) == 1 and purchases.size() == 1 and payouts.is_empty(),
				"responsive pause and resume finish one purchased merge without double payment or automatic collection")
	view.purchase_powerup = Callable()
	view.size = Vector2(1000, 720)


func _check_concurrent_powerup_resize(view) -> void:
	var purchases: Array[Dictionary] = []
	view.purchase_powerup = func(receipt: String, kind: String, price: int) -> Dictionary:
		purchases.append({"receipt": receipt, "kind": kind, "price": price})
		return {"ok": true}
	for reduced: bool in [false, true]:
		view.size = Vector2(1000, 720)
		_reset(view, reduced)
		purchases.clear()
		var ids: Array[int] = _completion_board(view, ["root:cat", "picture:cat", "root:caterpillar", "picture:caterpillar"], [1, 2, 3, 4])
		view._activate_powerup("auto_merge")
		_advance(view, 0.225)
		var moving: Dictionary = view.game.powerup_snapshot()
		check(moving.drags.size() == 2 and view.game.fusions.is_empty(), "two independent Auto flights overlap before the first reaches contact")
		var bodies: Array = []
		for drag: Dictionary in moving.drags:
			var body = view._tiles[int(drag.source_id)]
			bodies.append(body)
			var from: Vector2 = view._tile_rect(drag.source).get_center()
			var to: Vector2 = view._tile_rect(drag.target).get_center()
			check(body.get_rect().get_center().x > minf(from.x, to.x) and body.get_rect().get_center().x < maxf(from.x, to.x),
				"each overlapping paid source is visibly in transit")
		view.pause(true)
		var frozen: Dictionary = view.game.powerup_snapshot()
		for dimensions: Vector2 in [Vector2(390, 844), Vector2(568, 320)]:
			view.size = dimensions
			view._layout()
			var bounds := Rect2(Vector2.ZERO, view.size).grow(0.01)
			var centers: Array[Vector2] = []
			for body in bodies:
				check(view.game.powerup_snapshot() == frozen and bounds.encloses(body.get_rect()), "paused resize preserves both paths and moves their artwork inside the viewport")
				centers.append(body.get_rect().get_center())
			view._process(0.5)
			for index in range(bodies.size()):
				check(view.game.powerup_snapshot() == frozen and bodies[index].get_rect().get_center().is_equal_approx(centers[index]), "paused processing advances neither overlapping route nor its artwork")
		view.pause(false)
		_advance(view, 0.05)
		check(view.game.fusions.size() == 1 and view.game.powerup_snapshot().drags.size() == 1,
			"the first flight reaches fusion while the second keeps traveling after resize")
		_advance(view, 5.0)
		var fragments: int = 0
		for tile: Dictionary in view.game.cells:
			fragments += int(tile.fragments)
		check(not view.game.powerup_active() and view.game.collectable_ids().size() == 2 and int(view.game.merged_count) == 2
			and fragments == 10 and purchases.size() == 1 and payouts.is_empty() and attempts.is_empty() and heard.is_empty(),
			"overlapping resized routes finish both distinct words with all rewards carried and only one debit")
	view.purchase_powerup = Callable()
	view.size = Vector2(1000, 720)

func _check_long_word_label_visibility(view) -> void:
	var original_words: Array = words.duplicate(true)
	var quadrilateral: Dictionary = {}
	for word: Dictionary in data.words:
		if str(word.id) == "quadrilateral":
			quadrilateral = word.duplicate(true)
	check(not quadrilateral.is_empty(), "long two-piece label coverage uses the production quadrilateral word")
	if quadrilateral.is_empty():
		return
	words = [quadrilateral]
	for dimensions: Vector2 in [Vector2(1473, 1175), Vector2(1000, 720), Vector2(390, 844), Vector2(320, 568), Vector2(568, 320)]:
		view.size = dimensions
		_reset(view, true, int(quadrilateral.min_age))
		var ids: Array[int] = _install(view, ["root:quadrilateral", "picture:quadrilateral"], [0, 1])
		await process_frame
		for id: int in ids:
			if view.game.cell(id).jelly_kind == "root":
				_assert_compact_label(view._tiles[id], str(view.game.cell(id).text), "long root at %s" % dimensions)
			else:
				check(not view._tiles[id]._label.visible and view._tiles[id]._picture.visible, "a long word's picture remains a picture-only clue")
		var ordinary_size: Vector2 = view._tiles[ids[0]].size
		for fragments: int in [0, 2]:
			ids = _install(view, ["quadrilateral"], [fragments], [2])
			await process_frame
			var body = view._tiles[ids[0]]
			check(view.game.cell(ids[0]).width == 1 and view.game.cell(ids[0]).height == 1
				and body.size.is_equal_approx(ordinary_size) and body.valid_word and body._picture.is_visible_in_tree(),
				"the complete long word keeps its production picture and the same ordinary body as either source")
			_assert_compact_label(body, "quadrilateral", "pictured word at %s with %d fragments" % [dimensions, fragments])
			body.read_requested.emit(ids[0])
			var detail: Dictionary = view.snapshot().read_detail
			check(detail.visible and detail.text == "quadrilateral" and view.game.cells.size() == 1
				and payouts.is_empty() and attempts.is_empty(),
				"the compact long-word caption opens its complete spelling without collecting or assessing it")
			view._close_read()
	words = original_words
	view.size = Vector2(1000, 720)


func _assert_compact_label(body, expected: String, context: String) -> void:
	var label: Label = body._label
	var font: Font = label.get_theme_font("font")
	var pixels: int = label.get_theme_font_size("font_size")
	var lines: int = label.get_line_count()
	var rounded_height: float = 0.0
	for line in range(lines):
		rounded_height += ceilf(label.get_line_height(line))
	check(label.visible and body._spelling == expected and label.text.replace("\n", "") == expected,
		context + ": compact presentation retains every letter of the full spelling")
	check(pixels * Style.ui_scale(body) >= 13.0 - 0.01,
		context + ": the caption keeps at least thirteen physical pixels instead of shrinking with spelling length")
	check(label.autowrap_mode == TextServer.AUTOWRAP_OFF and label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS,
		context + ": overflow can use ellipsis without inventing arbitrary spelling breaks")
	var shaped_lines: PackedStringArray = label.text.split("\n")
	var consumed: int = 0
	var overflows: bool = false
	for index in range(shaped_lines.size()):
		var line: String = shaped_lines[index]
		consumed += line.length()
		overflows = overflows or font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > label.size.x + 0.01
		if index < shaped_lines.size() - 1:
			check(body._break_offsets.has(consumed), context + ": multiline captions use only an approved authored boundary")
	check(bool(body.requires_read) == overflows,
		context + ": the Read hint identifies spelling that cannot fit at the readable caption size")
	check(body.tooltip_text.begins_with(expected) and str(body.get("accessibility_name")).contains(expected),
		context + ": the complete spelling remains available to reading and accessibility")
	check(lines > 0 and label.get_visible_line_count() == lines,
		context + ": every compact caption line remains vertically visible")
	check(rounded_height <= label.size.y + 0.01,
		context + ": rounded native line heights fit the label box (%.2f <= %.2f)" % [rounded_height, label.size.y])
	check(Rect2(Vector2.ZERO, body.size).grow(0.01).encloses(label.get_rect()),
		context + ": the caption stays inside the jelly's painted footprint")


func _check_root_tap(view) -> void:
	_reset(view)
	var ids: Array[int] = _install(view, ["root:cat", "picture:cat"])
	var center: Vector2 = _center(view, ids[0])
	view._press(-1, center)
	view._release(center)
	_advance(view, 0.5)
	check(heard.size() == 1 and heard[0].id == "cat" and payouts.is_empty() and attempts.is_empty(),
		"tapping a complete standalone spelling pronounces it without collecting a reward")
	check(not view.snapshot().word_reveal.visible, "tapping a standalone root never reveals a completed word")
	check(view.game.cells.size() == 2 and view.game.fusions.is_empty(), "root tap does not consume either jelly")


func _check_edge_drag(view) -> void:
	for reduced: bool in [false, true]:
		_reset(view, reduced)
		var ids: Array[int] = _install(view, ["root:cat", "picture:cat"])
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
		check(view._target == ids[1] and cues.count("contact") == 1, "a matching pair offers contact before its painted edges overlap")
		view._move(view.get_global_transform() * touch)
		check(view._target == ids[1] and not target.get_rect().has_point(touch), "slight body overlap selects the target before pointer entry")
		check(view._contact_state().kind == "match" and cues.count("contact") == 1, "an ordered completion shows a match contact response")
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
	var text: String = "root:cat" if mass == 1 else "cat" if mass == 2 else "caterpillar"
	var tile: Dictionary = _fixture_tile(view, text, mass, 2)
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
				for placement: Vector2i in [Vector2i(1, 2), Vector2i(2, 0), Vector2i(2, 2), Vector2i(7, 0)]:
					_reset(view, reduced)
					var mass: int = placement.x
					var tile: Dictionary = _reposition_fixture(view, mass)
					var original: Dictionary = tile.duplicate(true)
					var id: int = int(tile.id)
					var column: int = placement.y
					var motion: Vector2 = _placement_point(view, tile, column, 1)
					var release: Vector2 = _placement_point(view, tile, column, 3)
					_pointer_event(view, pointer, "down", _center(view, id))
					_pointer_event(view, pointer, "move", motion)
					check(view._dragging and view._target == -1, "mouse and touch drag roots, words, and long spellings over an empty destination")
					# Pointer motion presents placement at the next rendered frame.
					view._process(0.0)
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
					check(int(placed.column) == column and int(placed.row) == Model.ROWS - int(placed.height)
						and _has_support(view.game.cells, placed),
						"an unsupported release reserves the first supported destination in the chosen column")
					check(bool(placed.get("falling", false)) and int(placed.get("falling_rows", 0)) == int(placed.row) - 3
						and is_zero_approx(float(placed.age)),
						"gravity starts immediately at the final pointer-up row without a suspended settling delay")
					check(placed.text == original.text and placed.word == original.word and placed.mass == original.mass
						and placed.fragments == original.fragments and placed.width == original.width and placed.height == original.height,
						"repositioning preserves identity, spelling, picture, semantic mass, ordinary footprint, and every fragment")
					check(view.game.fusions.is_empty() and not view._settled(placed), "placing a body starts its short input settling window without merging or collecting it")
					check(not view.snapshot().placement.visible, "a committed placement removes its temporary destination skin")
					check(not view._press(pointer, _center(view, id)), "a newly placed body cannot accept a competing tap during its settle")
					if reduced:
						check(view._tiles[id].get_rect().is_equal_approx(view._tile_rect(placed)) and view._tiles[id].scale == Vector2.ONE,
							"reduced motion places the body at its supported destination without a moving or scaled target")
					else:
						var released_origin: Vector2 = view.get_global_transform().affine_inverse() * release - view._tiles[id].size * 0.5
						check(view._tiles[id].position.is_equal_approx(released_origin) and view._reflow.has(id)
							and bool(view._reflow[id].falling) and not view._snapbacks.has(id),
							"the fall starts at the final pointer location even when its landing slot matches the original slot")
						_advance(view, Model.SETTLE_SECONDS * 0.12)
						var first_position: Vector2 = view._tiles[id].position
						_advance(view, Model.SETTLE_SECONDS * 0.12)
						var second_position: Vector2 = view._tiles[id].position
						check(first_position.y > released_origin.y and second_position.y > first_position.y
							and second_position.y < view._tile_rect(placed).position.y,
							"released bodies visibly fall through intermediate positions instead of teleporting to the floor")
						check(second_position.y - first_position.y > first_position.y - released_origin.y
							and is_equal_approx(second_position.x, released_origin.x),
							"gravity accelerates downward while retaining the chosen horizontal lane")
					_advance(view, Model.SETTLE_SECONDS + 0.01)
					placed = view.game.cell(id)
					check(view._settled(placed) and view._tiles[id].get_rect().is_equal_approx(view._tile_rect(placed)),
						"the settled body and its hit target agree at the supported landing position")
					check(view._tiles[id].visible_fragment_badges() == 2 and view._board.encloses(view._tiles[id].get_rect()),
						"a relocated root or long word retains its chest artwork inside the well")
					view.game._settle_collected_stack()
					_advance(view, 1.0)
					check(_has_support(view.game.cells, placed) and int(placed.column) == column,
						"later gravity keeps the relocated body grounded in the player's chosen column")
					check(payouts.is_empty() and attempts.is_empty() and heard.is_empty()
						and view.game.collected_coins == 0 and view.game.fragment_count == 0,
						"moving even a completed word never pays coins, collects fragments, teaches, or pronounces it")
					check(not view.snapshot().word_reveal.visible and cues.count("pop") == 0 and cues.count("merge") == 0,
						"a positional drop cannot trigger the collection overlay, pop, or merge sound")
	view.size = Vector2(1000, 720)


func _check_reposition_rejection(view) -> void:
	for pointer: int in [-1, 7]:
		for destination: Vector2i in [Vector2i(-1, 2), Vector2i(Model.COLUMNS, 2), Vector2i(0, -1), Vector2i(0, Model.ROWS)]:
			_reset(view)
			var tile: Dictionary = _reposition_fixture(view, 7)
			var original: Rect2 = view._tile_rect(tile)
			var release: Vector2 = _placement_point(view, tile, destination.x, destination.y)
			_pointer_event(view, pointer, "down", _center(view, int(tile.id)))
			_pointer_event(view, pointer, "move", release)
			_pointer_event(view, pointer, "up", release)
			_advance(view, Model.SETTLE_SECONDS + 0.1)
			check(view._tiles[int(tile.id)].get_rect().is_equal_approx(original) and not bool(tile.get("placement_locked", false)),
				"an ordinary long-word body returns home after a drop beyond any well edge")
			check(view.game.fusions.is_empty() and payouts.is_empty(), "an out-of-bounds drop cannot consume or collect a word")
		_reset(view)
		var tile: Dictionary = _reposition_fixture(view, 2)
		var original: Rect2 = view._tile_rect(tile)
		var blocker: Dictionary = _fixture_tile(view, "picture:cat", 1, 0)
		blocker.column = 2
		blocker.row = 2
		blocker.age = 0.0
		blocker.settling = true
		view.game.cells.append(blocker)
		view._sync_tiles()
		var occupied: Vector2 = _placement_point(view, tile, 2, 2)
		_pointer_event(view, pointer, "down", _center(view, int(tile.id)))
		_pointer_event(view, pointer, "move", occupied)
		check(view._target == -1, "a moving occupant cannot become a merge target")
		# Observe the rejected placement after buffered motion is presented.
		view._process(0.0)
		check(view.snapshot().placement.visible and not view.snapshot().placement.valid,
			"a blocked footprint gets visual rejection while leaving the held jelly under pointer control")
		_pointer_event(view, pointer, "up", occupied)
		_advance(view, Model.SETTLE_SECONDS + 0.1)
		check(view._tiles[int(tile.id)].get_rect().is_equal_approx(original) and not bool(tile.get("placement_locked", false)),
			"an occupied destination cell rejects the ordinary body without displacing its occupant")
		check(view.game.cells.size() == 2 and view.game.fusions.is_empty(), "a rejected occupied drop preserves both bodies")
		_reset(view)
		tile = _reposition_fixture(view)
		var a: Dictionary = _fixture_tile(view, "root:cat", 1, 0)
		a.column = 3
		a.row = 2
		var b: Dictionary = _fixture_tile(view, "picture:cat", 1, 0)
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


func _check_reposition_completed_word(view) -> void:
	_reset(view)
	var ids: Array[int] = _install(view, ["root:cat", "picture:cat"], [2, 3])
	_drag(view, ids[0], ids[1])
	var id: int = _merged_id(view)
	_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS * 2.0)
	var tile: Dictionary = view.game.cell(id)
	var release: Vector2 = _placement_point(view, tile, 1, 2)
	_pointer_event(view, 7, "down", _center(view, id))
	_pointer_event(view, 7, "move", release)
	_pointer_event(view, 7, "up", release)
	_advance(view, Model.SETTLE_SECONDS * 2.0)
	tile = view.game.cell(id)
	check(view.game.is_valid_word(tile) and tile.mass == 2 and tile.fragments == 5 and _has_support(view.game.cells, tile),
		"moving a completed word preserves its full body and fragments while landing on support")
	var center: Vector2 = _center(view, id)
	_pointer_event(view, 7, "down", center)
	_pointer_event(view, 7, "up", center)
	check(view.game.fusions.size() == 1 and view.game.fusions[0].operation == "collect",
		"tapping the relocated completed word starts ordinary collection")
	_advance(view, Model.COLLECT_SECONDS)
	check(view.game.cell(id).is_empty() and view.game.fragment_count == 5 and payouts.size() == 1,
		"the moved word collects exactly once with all carried fragments")


func _check_collect_and_fragments(view) -> void:
	_reset(view)
	var ids: Array[int] = _install(view, ["root:cat", "picture:cat"], [1, 1])
	_drag(view, ids[0], ids[1])
	var id: int = _merged_id(view)
	_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS * 2.0)
	var tile = view._tiles[id]
	check(tile.visible_fragment_badges() == 2 and tile._fragment_badges[0].visible and tile._fragment_badges[1].visible, "both source chest markers remain independently visible on the merge")
	check(tile._label.text.to_lower() == "cat" and not tile.requires_read, "the short merged-word caption fits completely at its readable size")
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
	check(payouts[0].amount == 0 and payouts[0].fragments == 2 and payouts[0].origin.distance_to(center) < 0.1,
		"Lv1 collection retains the tapped fragment origin without a coin reward")
	check(cues.count("pop") == 1 and view.game.fragment_count == 2, "collection retains the disappearance cue and all accumulated fragments")


func _check_fragment_badge_layout(view) -> void:
	for dimensions: Vector2 in [Vector2(1473, 1175), Vector2(393, 852), Vector2(320, 568), Vector2(844, 390)]:
		view.size = dimensions
		_reset(view, true)
		var ids: Array[int] = _install(view, ["root:cat"], [1])
		var unit: float = view._tiles[ids[0]].size.x
		for shape: Dictionary in [{"name": "root", "size": Vector2.ONE * unit, "mass": 1, "text": "root:cat"},
			{"name": "square word", "size": Vector2.ONE * unit, "mass": 2, "text": "cat"},
			{"name": "wide word", "size": Vector2(2, 1) * unit, "mass": 2, "text": "cat"},
			{"name": "tall word", "size": Vector2(1, 2) * unit, "mass": 2, "text": "cat"}]:
			ids = _install(view, [str(shape.text)], [1], [int(shape.mass)])
			var body = view._tiles[ids[0]]
			var cell: Dictionary = view.game.cell(ids[0]).duplicate(true)
			for fragments: int in [1, 2, 6, 8, 20, 0, 1]:
				cell.fragments = fragments
				view._configure_tile(body, cell)
				body.size = shape.size
				body._layout()
				await process_frame
				var badge: Dictionary = body.fragment_badge_snapshot()
				var context: String = "%s, %s, %d fragments" % [dimensions, shape.name, fragments]
				check(int(badge.icons) == mini(2, fragments) and body.visible_fragment_badges() == mini(2, fragments),
					context + ": one or two sourced chest icons replace an unbounded row")
				check(str(badge.count_text) == (str(fragments) if fragments > 2 else ""),
					context + ": a larger carried stack displays its full total rather than an overflow remainder")
				check(bool(badge.visible) == (fragments > 0), context + ": clearing fragments removes all badge artwork")
				if fragments == 0:
					continue
				var rect: Rect2 = _snapshot_rect(badge.rect)
				check(rect.size.x > 0.0 and rect.size.y > 0.0 and Rect2(Vector2.ZERO, body.size).grow(0.01).encloses(rect),
					context + ": the complete chest stack and count stay inside the jelly")
				var overlap: Rect2 = rect.intersection(body._label.get_rect())
				check(overlap.size.x < 0.01 or overlap.size.y < 0.01,
					context + ": the compact reward marker never covers the learning label")
				_assert_compact_label(body, str(cell.display_text), context)
				check(body._label.get_theme_font_size("font_size") >= maxi(1, floori(unit * 0.15)),
					context + ": the caption remains readable rather than shrinking to make room for rewards")
				if fragments > 2:
					var count_label: Label = body._fragment_count
					var count_font: Font = count_label.get_theme_font("font")
					var count_pixels: int = count_label.get_theme_font_size("font_size")
					check(count_label.visible and count_label.get_line_count() == 1 and count_label.get_visible_line_count() == 1
						and count_label.get_line_height() <= count_label.size.y + 0.01
						and count_font.get_string_size(count_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, count_pixels).x <= count_label.size.x + 0.01,
						context + ": the entire exact count is visible within its capsule")
				check(str(body.get("accessibility_name")).contains("%d chest fragments." % fragments),
					context + ": accessibility retains the exact carried reward amount")
				body.set_fragment_arrival(0.11, false)
				var peak: Dictionary = body.fragment_badge_snapshot()
				check(float(peak.scale) > float(badge.scale)
					and Rect2(Vector2.ZERO, body.size).grow(0.01).encloses(_snapshot_rect(peak.rect)),
					context + ": the receipt bounce is visible without crossing the jelly boundary")
				body.set_fragment_arrival(0.11, true)
				check(_snapshot_rect(body.fragment_badge_snapshot().rect).is_equal_approx(rect),
					context + ": reduced motion keeps the full amount with a stationary badge")
				body.set_fragment_arrival(-1.0, true)
			body.set_projection(true)
			var projected: Dictionary = body.fragment_badge_snapshot()
			check(not bool(projected.visible) and body.visible_fragment_badges() == 0,
				"placement projection does not duplicate a carried reward marker")
			body.set_projection(false)
	view.size = Vector2(1000, 720)


func _snapshot_rect(value: Array) -> Rect2:
	return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))


func _check_collection_click_duration(view) -> void:
	for pointer: int in [-1, 0]:
		for held_ms: int in [100, 500, 850]:
			_reset(view)
			var ids: Array[int] = _install(view, ["merged:cat"], [2])
			var center: Vector2 = _center(view, ids[0])
			_pointer_event(view, pointer, "down", center)
			check(view._pointer == pointer and view.game.fusions.is_empty() and payouts.is_empty(),
				"mouse and touch presses never collect before release")
			# Advance the wall clock independently of frames, including the 500 ms boundary.
			view._tile_press_started_ms = Time.get_ticks_msec() - held_ms
			_pointer_event(view, pointer, "up", center)
			if held_ms >= 500:
				check(view.game.fusions.is_empty() and not view.game.cell(ids[0]).is_empty(),
					"holding a merged word for at least 500 ms never starts collection on release")
				_advance(view, Model.COLLECT_SECONDS + Model.SETTLE_SECONDS)
				check(payouts.is_empty() and attempts.is_empty() and heard.is_empty()
					and cues.count("pop") == 0 and view.game.fragment_count == 0,
					"long holds cannot grant rewards or mastery, pronounce, or play collection effects")
				center = _center(view, ids[0])
				_pointer_event(view, pointer, "down", center)
				_pointer_event(view, pointer, "up", center)
			check(view.game.fusions.size() == 1 and str(view.game.fusions[0].operation) == "collect",
				"a short click collects, including a fresh click after a rejected long hold")
			_advance(view, Model.COLLECT_SECONDS + Model.SETTLE_SECONDS)
			check(payouts.size() == 1 and attempts.size() == 1 and view.game.fragment_count == 2,
				"the accepted click credits its word and carried fragments exactly once")
		_reset(view)
		var ids: Array[int] = _install(view, ["merged:cat", "merged:cat"])
		var destination: Vector2 = _center(view, ids[1])
		_pointer_event(view, pointer, "down", _center(view, ids[0]))
		view._tile_press_started_ms = Time.get_ticks_msec() - 850
		_pointer_event(view, pointer, "move", destination)
		_pointer_event(view, pointer, "up", destination)
		check(view.game.fusions.size() == 1 and str(view.game.fusions[0].operation) == "merge",
			"a long hold still allows dragging matching merged words together")
		var merged: int = _merged_id(view)
		_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS * 2.0)
		check(int(view.game.cell(merged).get("merge_level", 0)) == 2 and payouts.is_empty() and attempts.is_empty(),
			"dragging after a long hold upgrades without collecting or granting mastery")
		_reset(view)
		ids = _install(view, ["merged:cat"])
		var center: Vector2 = _center(view, ids[0])
		_pointer_event(view, pointer, "down", center)
		_pointer_event(view, pointer, "up", center, true)
		_pointer_event(view, pointer, "up", center)
		check(view._tile_press_started_ms == -1 and view.game.fusions.is_empty() and payouts.is_empty(),
			"canceled pointer input clears click timing and ignores a late release")


func _check_ordinary_collection(view) -> void:
	for reduced: bool in [false, true]:
		for batch: bool in [false, true]:
			_reset(view, reduced)
			view.game._coin_rng.seed = 0
			var wallet_calls: Array[String] = []
			view.credit_collection = func(id: String, _amount: int) -> Dictionary:
				wallet_calls.append(id)
				return {"ok": false}
			var count: int = 3 if batch else 1
			if batch:
				_install_batch_words(view, count, false, false)
				view._collect_all()
			else:
				var ids: Array[int] = _install(view, ["cat"], [2], [2])
				view._activate(ids[0])
			var elapsed: float = count * Model.BATCH_BEAT_SECONDS if batch else Model.COLLECT_SECONDS
			_advance(view, elapsed)
			check(view.game.cells.is_empty() and payouts.size() == count and attempts.size() == count,
				"ordinary manual and batch pickups still remove every word and record its learning answer")
			check(wallet_calls.is_empty() and view.game.collected_coins == 0 and view.game.error.is_empty()
				and payouts.all(func(reward: Dictionary) -> bool: return reward.amount == 0),
				"a pickup without a rare drop bypasses even an unavailable wallet without an error")
			var reveal_count: int = _batch_reveal_count(count, elapsed, Jelly.WordReveal.BATCH_SECONDS) if batch else count
			check(view.game.fragment_count == (3 if batch else 2) and cues.count("pop") == count
				and int(view.snapshot().word_reveal.active_count) == reveal_count,
				"ordinary pickups retain all fragments, disappearance cues, and word reveals in both motion settings")


func _batch_reveal_count(started: int, elapsed: float, duration: float) -> int:
	var count: int = 0
	for index in range(started):
		if elapsed - index * Model.BATCH_BEAT_SECONDS < duration - 0.000001:
			count += 1
	return count


func _install_batch_words(view, count: int, retain_others: bool = false, eligible_first: bool = true) -> Array[int]:
	view.game.cells.clear()
	var ids: Array[int] = []
	for index in range(count):
		var level_two: bool = eligible_first and index == 0
		var tile: Dictionary = _fixture_tile(view, "merged:cat:2" if level_two else "cat", 4 if level_two else 2, index % 3)
		tile.column = (index % 3) * 2
		tile.row = Model.ROWS - 1 - floori(float(index) / 3.0)
		view.game.cells.append(tile)
		ids.append(int(tile.id))
	if retain_others:
		var invalid: Dictionary = _fixture_tile(view, "tc", 2, 2)
		invalid.column = 0
		invalid.row = Model.ROWS - 2
		var single: Dictionary = _fixture_tile(view, "cat", 1, 1)
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
			check(int(steady.jelly_count) > int(last.jelly_count) and int(steady.sparkle_count) > int(last.sparkle_count)
				and float(steady.glow) > float(last.glow) and float(steady.rays) > float(last.rays),
				"large batches continue gaining word-jelly artwork, glints and stronger light beyond nine words")
			check(is_equal_approx(float(steady.visual_scale), float(last.visual_scale)),
				"high-count intensity grows through richer effects without crowding adjacent controls")
		last = steady


func _check_batch_collection(view) -> void:
	check(is_equal_approx(Model.BATCH_BEAT_SECONDS, 0.20), "Auto Collect starts each collection exactly 200 ms apart")
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
			check(amount == 50, "a rare batch coin drop retains the merged-word reward amount")
			return {"ok": true}
		var pop_times: Array[float] = []
		var on_pop: Callable = func(cue: String) -> void:
			if cue == "pop" or cue == "jelly-collect-lv2":
				pop_times.append(float(view.game.collection_batch_snapshot().elapsed))
		view.audio_requested.connect(on_pop)
		view.collect_button.pressed.emit()
		var started: Dictionary = view.snapshot()
		check(started.collection_batch.active and int(started.collection_batch.total) == 3
			and int(started.collection_batch.started) == 1 and not started.collect_button.enabled,
			"one collect-button activation snapshots three valid merges and starts only the first")
		check(int(started.word_reveal.active_count) == 1 and started.word_reveal.entries.size() == 1,
			"the first collection beat immediately opens its own word reveal")
		check(not started.preview.enabled and not view.navigation_controls().has(view.collect_button)
			and view.navigation_controls().has(view.finish_button),
			"a running batch blocks more supply and collection while leaving Finish accessible")
		view.collect_button.pressed.emit()
		view._activate(ids[1])
		check(not view._press(-1, _center(view, retained[0])),
			"batch playback cannot start a competing drag or merge")
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
			_advance(view, 0.01)
			elapsed += 0.01
			var state: Dictionary = view.snapshot()
			var now_started: int = int(state.collection_batch.started)
			var now_completed: int = int(state.collection_batch.completed)
			check(now_started >= previous_started and now_started <= previous_started + 1
				and now_completed >= previous_completed and now_completed <= previous_completed + 1,
				"batch members start and commit singly in monotonic order")
			check(now_started - now_completed <= 1 and view.game.fusions.size() <= 1,
				"the rhythmic queue never overlaps reward transactions or disappearance poses")
			var visible_reveals: int = _batch_reveal_count(now_started, elapsed, float(started.word_reveal.duration))
			check(int(state.word_reveal.active_count) == visible_reveals and state.word_reveal.entries.size() == visible_reveals,
				"each 200 ms pickup adds its own reveal and expired reading cards leave independently")
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
			and int(final.collection_batch.started) == 3 and is_equal_approx(elapsed, 3.0 * Model.BATCH_BEAT_SECONDS),
			"three words finish in exactly 600 ms through three sequential collection beats")
		check(start_times.size() == 3 and payout_times.size() == 3 and pop_times.size() == 3,
			"each collected word has a separate visible start, payout and disappearance sound")
		for index in range(start_times.size()):
			check(is_equal_approx(start_times[index], index * Model.BATCH_BEAT_SECONDS)
				and is_equal_approx(payout_times[index], (index + 1) * Model.BATCH_BEAT_SECONDS),
				"ordinary and reduced-motion collection both preserve exact 200 ms start and payout spacing")
			check(is_equal_approx(pop_times[index], index * Model.BATCH_BEAT_SECONDS + 0.06),
				"the existing disappearance sound stays at 60 ms within every 200 ms beat")
		check(payouts.size() == 3 and credits.size() == 1 and attempts.size() == 3,
			"batch collection records every word but only persists its one rare coin drop")
		check(payouts[0].amount == 50 and payouts[1].amount == 0 and payouts[2].amount == 0,
			"ordinary batch members collect successfully without creating a coin reward")
		for times: int in credits.values():
			check(times == 1, "each batch event reaches persistent credit only once")
		check(view.game.collected_coins == 50 and view.game.fragment_count == 3
			and cues.count("pop") == 2 and cues.count("jelly-collect-lv2") == 1,
			"the Lv2 bonus and two Lv1 collections retain every fragment and their own level sounds")
		check(heard.is_empty(), "batch collection never pronounces a word, including the final pickup")
		var reveals: Array = final.word_reveal.entries
		var surviving_count: int = _batch_reveal_count(3, elapsed, float(started.word_reveal.duration))
		check(reveals.size() == surviving_count and int(final.word_reveal.active_count) == surviving_count,
			"all three reading cards retain their independent lifetimes after the faster batch completes")
		for index in range(reveals.size()):
			check(str(reveals[index].word_id) == "cat"
				and is_equal_approx(float(reveals[index].elapsed), elapsed - (3 - surviving_count + index) * Model.BATCH_BEAT_SECONDS),
				"repeated spellings retain separate reveal timelines at the 200 ms cadence")
		for id: int in retained:
			check(not view.game.cell(id).is_empty(), "unfinished merges and unmerged roots stay available after collecting")
		check(not final.collect_button.enabled and int(final.collect_button.count) == 0,
			"collecting every completed merge returns the button to its empty state")
		_advance(view, 2.0)
		check(payouts.size() == 3 and view.game.collected_coins == 50,
			"the completed batch cannot replay its rewards on later frames")
		check(view.snapshot().word_reveal.entries.is_empty() and int(view.snapshot().word_reveal.active_count) == 0,
			"all concurrent batch reveals expire without replaying a collection")
		view.audio_requested.disconnect(on_pop)


func _check_coarse_frame_batch_reveals(view) -> void:
	for reduced: bool in [false, true]:
		_reset(view, reduced)
		_install_batch_words(view, 3)
		view._collect_all()
		view._process(0.30)
		var state: Dictionary = view.snapshot()
		var entries: Array = state.word_reveal.entries
		check(entries.size() == 2 and int(state.word_reveal.active_count) == 2
			and state.collection_batch.active and int(state.collection_batch.completed) == 1,
			"one coarse frame preserves both reveals on either side of the 200 ms collection beat")
		for index in range(entries.size()):
			check(is_equal_approx(float(entries[index].elapsed), 0.30 - index * Model.BATCH_BEAT_SECONDS),
				"coarse frames carry only the remaining frame time into each new collection reveal")
		view._process(0.30)
		entries = view.snapshot().word_reveal.entries
		check(entries.size() == 3, "Three reading cards briefly coexist before their first expiry")
		for index in range(entries.size()):
			check(is_equal_approx(float(entries[index].elapsed), 0.60 - index * Model.BATCH_BEAT_SECONDS),
				"the second coarse frame advances earlier reveals and creates the third at its exact beat")
		view._process(0.40)
		state = view.snapshot()
		check(not state.collection_batch.active and int(state.collection_batch.completed) == 3
			and payouts.size() == 3 and attempts.size() == 3 and view.game.collected_coins == 50
			and view.game.fragment_count == 3 and cues.count("pop") == 2 and cues.count("jelly-collect-lv2") == 1 and heard.is_empty(),
			"coarse reveal catch-up preserves one rare drop and three disappearance sounds without pronunciation")
		view._process(0.10)
		entries = view.snapshot().word_reveal.entries
		check(entries.size() == 1, "Coarse collection frames expire the first two reveals while the newest word remains")
		for index in range(entries.size()):
			check(is_equal_approx(float(entries[index].elapsed), 1.10 - (3 - entries.size() + index) * Model.BATCH_BEAT_SECONDS),
				"after a completed batch each independent reveal advances once per frame")
		var before_pause: Array = entries.duplicate(true)
		view._process(1.25)
		state = view.snapshot()
		check(state.word_reveal.entries == before_pause,
			"an ignored hidden-tab frame preserves all reveal ages and geometry")
		check(payouts.size() == 3 and view.game.collected_coins == 50
			and cues.count("pop") == 2 and cues.count("jelly-collect-lv2") == 1 and heard.is_empty(),
			"an ignored hidden-tab frame cannot replay any batch rewards or sounds")


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
			_advance(view, 0.01)
			elapsed += 0.01
			var presentation: Dictionary = view.snapshot().reward_presentation
			if view.game.chest_tier > 0:
				queued_during_batch = queued_during_batch or bool(presentation.active)
			if view.game.collection_batch_active():
				check(not presentation.visible and confetti.is_empty(),
					"earned chests queue behind batch collection instead of covering its remaining words")
		check(queued_during_batch and not view.game.collection_batch_active()
			and view.game.fragment_count == 9 and view.game.chest_tier == 2,
			"all nine fragments and the second chest tier commit before queued celebration begins")
		check(payouts.size() == 9 and view.game.collected_coins == 50
			and is_equal_approx(elapsed, 9.0 * Model.BATCH_BEAT_SECONDS),
			"waiting chest artwork preserves nine collections and one rare coin reward across nine 200 ms beats")
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
		check(payouts.size() == 9 and view.game.collected_coins == 50 and view.game.fragment_count == 9,
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
	check(payouts.size() == 3 and view.game.collected_coins == 50 and view.game.fragment_count == 3,
		"retry after wallet recovery preserves the rare drop and collects each carried fragment exactly once")


func _check_reveal_content(view, expected: Dictionary) -> void:
	var reveal: Dictionary = view.snapshot().word_reveal
	var card = view._word_reveal._entries.back()
	check(reveal.visible and reveal.word_id == expected.id and reveal.word.id == expected.id,
		"collecting a completed word reveals that word above the board")
	check(reveal.spelling == expected.text and str(reveal.picture).trim_prefix("res://") == expected.image,
		"the reveal uses the collected word's complete spelling and production image")
	check(reveal.content_alpha > 0.95 and card._picture.texture != null,
		"the reveal reaches a readable opaque hold with real picture art")
	var panel: Rect2 = _snapshot_rect(reveal.rect)
	var picture: Rect2 = _snapshot_rect(reveal.picture_rect)
	var spelling: Rect2 = _snapshot_rect(reveal.spelling_rect)
	# Short landscape screens reserve two rows in the upper sixty percent.
	var top_fraction: float = 0.60 if view.size.x > view.size.y * 1.4 and view.size.y * Style.ui_scale(view) < 350.0 else 0.42
	check(view.get_global_rect().grow(0.1).encloses(panel) and panel.end.y <= view.get_global_rect().position.y + view.size.y * top_fraction + 0.1,
		"the reveal remains near the top and inside the available playfield")
	check(panel.grow(0.1).encloses(picture) and panel.grow(0.1).encloses(spelling) and picture.end.x < spelling.position.x,
		"picture and spelling have separate readable space inside the reveal")
	var label: Label = card._spelling
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
			check(is_equal_approx(view.snapshot().word_reveal.elapsed, first.elapsed) and heard.size() == 1
				and int(view.snapshot().word_reveal.active_count) == 1,
				"duplicate activation cannot restart the reveal or repeat pronunciation")
			check(cues.count("pop") == 1, "the reveal peak shares the one existing disappearance sound")
			if reduced:
				check(_snapshot_rect(first.rect).is_equal_approx(_snapshot_rect(first.resting_rect))
					and not view._word_reveal._entries.back()._aura.visible,
					"reduced motion preserves a steady readable picture and spelling")
			_advance(view, Model.COLLECT_SECONDS)
			view._activate(ids[1])
			_advance(view, 0.20)
			_check_reveal_content(view, words[1])
			var concurrent: Dictionary = view.snapshot().word_reveal
			check(int(concurrent.active_count) == 2 and concurrent.entries.size() == 2 and heard.size() == 2,
				"another individual collection immediately coexists with the first word")
			check(str(concurrent.entries[0].word_id) == str(words[0].id)
				and str(concurrent.entries[1].word_id) == str(words[1].id)
				and is_equal_approx(float(concurrent.entries[0].elapsed), float(first.elapsed) + Model.COLLECT_SECONDS + 0.20)
				and is_equal_approx(float(concurrent.entries[1].elapsed), 0.20),
				"both individual reveals retain the correct picture, spelling and independent collection age")
			_advance(view, Model.COLLECT_SECONDS)
			check(payouts.size() == 2 and view.game.collected_coins == 0 and cues.count("pop") == 2,
				"rapid Lv1 reveals produce no coins and retain one disappearance cue per collection")
			_advance(view, float(view.snapshot().word_reveal.duration))
			check(not view.snapshot().word_reveal.visible and view.snapshot().word_reveal.entries.is_empty()
				and int(view.snapshot().word_reveal.active_count) == 0 and heard.size() == 2 and payouts.size() == 2,
				"all reveals clear themselves without replaying a word or collecting another reward")
	view.size = Vector2(1000, 720)


func _check_word_reveal_levels(view) -> void:
	var levels: Array[int] = [1, 4, 9]
	for reduced: bool in [false, true]:
		for batch: bool in [false, true]:
			_reset(view, reduced)
			var ids: Array[int] = _install_batch_words(view, 3)
			for index in range(ids.size()):
				view.game.cells[index].merge_level = levels[index]
			view._sync_tiles()
			var advertised: Array = view.snapshot().tiles
			for index in range(ids.size()):
				var reward: Dictionary = advertised.filter(func(tile: Dictionary) -> bool: return int(tile.id) == ids[index])[0]
				check(is_equal_approx(float(reward.coin_drop_chance), [0.0, 0.06, 0.80][index])
					and int(reward.coins) == [0, 150, 450][index],
					"the view snapshot advertises exact Lv1, Lv4 and Lv9 collection odds and payouts")
			if batch:
				view._collect_all()
				view._process(0.30)
				check(view.snapshot().word_reveal.entries.size() == 2,
					"a late auto-collect frame keeps both mixed-level pop entries alive")
				view._process(0.30)
			else:
				for id: int in ids:
					view._activate(id)
					_advance(view, 0.10)
			var entries: Array = view.snapshot().word_reveal.entries
			check(entries.size() == 3, "rapid individual and automatic pickups retain Lv1, Lv4 and Lv9 pops together")
			var entry_ids: Array[int] = []
			for index in range(entries.size()):
				var entry: Dictionary = entries[index]
				entry_ids.append(int(entry.entry_id))
				check(int(entry.merge_level) == levels[index] and int(entry.effects.level) == levels[index],
					"collection passes the actual merged-Jelly level into its independent reading-pop effects")
				check(bool(entry.effects.reduced_motion) == reduced and bool(entry.effects.input_transparent),
					"collection-pop effects follow the current motion preference and pass pointer input through")
				check(entry.word_id == "cat" and entry.spelling == "cat" and str(entry.picture).ends_with("cat.webp"),
					"all collection levels retain the collected spelling and its production artwork")
				var expected_age: float = 0.60 - index * Model.BATCH_BEAT_SECONDS if batch else (3 - index) * 0.10
				check(is_equal_approx(float(entry.elapsed), expected_age),
					"collection levels share the original clock, including late-frame catch-up")
			check(entry_ids.size() == 3 and entry_ids[0] != entry_ids[1]
				and entry_ids[1] != entry_ids[2] and entry_ids[0] != entry_ids[2],
				"repeated words at different levels have independent presentation identities")
			check(entries[0].effects.pattern != entries[1].effects.pattern
				and entries[1].effects.pattern == "fireworks" and entries[1].effects.pattern != entries[2].effects.pattern,
				"the collection pop distinguishes the ordinary, fireworks and highest-tier treatments")
			_advance(view, 2.0)
			check(payouts.size() == 3 and attempts.size() == 3 and heard.size() == (0 if batch else 3),
				"richer reading-pop effects preserve collection credit and manual-only pronunciation")
			check(cues.count("pop") == 1 and cues.count("jelly-collect-lv4") == 1
				and cues.count("jelly-collect-lv9") == 1,
				"each pickup emits its existing level sound once without extra reading-pop audio")
			check(view.snapshot().word_reveal.entries.is_empty() and view._word_reveal.get_child_count() == 0,
				"every level's collection-pop effect subtree expires with its original reading lifetime")


func _check_word_reveal_control_clearance(view) -> void:
	for dimensions: Vector2 in [Vector2(1000, 720), Vector2(844, 390), Vector2(390, 844)]:
		view.size = dimensions
		_reset(view)
		_install_batch_words(view, 4)
		for index in range(4):
			view.game.cells[index].merge_level = [1, 4, 7, 9][index]
		view._word_reveal._rng.seed = 20261022
		view._collect_all()
		var protected: Array[Rect2] = [view.finish_button.get_global_rect(), view.collect_button.get_global_rect(),
			view.get_global_transform() * view.chest_meter_rect()]
		for tick in range(16):
			view._process(0.05)
			for entry: Dictionary in view.snapshot().word_reveal.entries:
				var panel: Rect2 = _snapshot_rect(entry.rect)
				var effects: Rect2 = _snapshot_rect(entry.effects.rect)
				for control: Rect2 in protected:
					check(not panel.intersects(control) and not effects.intersects(control),
						"collection cards and their high-level halos leave Finish, chest and Collect readable at %s" % dimensions)
		var state: Dictionary = view.snapshot()
		var visible_count: int = _batch_reveal_count(4, 0.80, float(state.word_reveal.duration))
		check(int(state.collection_batch.started) == 4 and int(state.word_reveal.active_count) == visible_count,
			"the 200 ms cadence retains every unexpired collection pop after the fourth start")
		if dimensions == Vector2(1000, 720):
			check(visible_count == 4, "the full reading region supports four concurrent collection pops before their first expiry")
	view.size = Vector2(1000, 720)


func _check_word_reveal_lifecycle(view) -> void:
	for action: String in ["pause", "hide", "finish", "stop", "configure"]:
		_reset(view)
		var ids: Array[int] = _install(view, ["merged:cat:4", "merged:caterpillar:9"], [], [2, 2])
		view._activate(ids[0])
		_advance(view, 0.2)
		view._activate(ids[1])
		_advance(view, 0.2)
		check(view.snapshot().word_reveal.visible and int(view.snapshot().word_reveal.active_count) == 2,
			"lifecycle fixture begins with two simultaneous collected words")
		match action:
			"pause": view.pause(true)
			"hide": view.hide()
			"finish": view._finish_round()
			"stop": view.stop()
			"configure": view.configure(words, 3, Data.theme("spring"), data.chests, false, 42)
		check(not view.snapshot().word_reveal.visible and view.snapshot().word_reveal.entries.is_empty()
			and int(view.snapshot().word_reveal.active_count) == 0, action + " clears every temporary word reveal immediately")
		view.show()
		view.pause(false)
		_advance(view, 0.1)
		check(not view.snapshot().word_reveal.visible and view.snapshot().word_reveal.entries.is_empty(),
			action + " never restores stale collected-word overlays")
	_reset(view)
	var ids: Array[int] = _install(view, ["merged:cat:9"], [], [2])
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
			var support: Dictionary = _fixture_tile(view, "merged:cat:2", 4, 1)
			support.column = 1
			support.row = 7
			var lower: Dictionary = _fixture_tile(view, "root:cat", 1, 1)
			lower.column = 1
			lower.row = 6
			var upper: Dictionary = _fixture_tile(view, "picture:cat", 1, 0)
			upper.column = 1
			upper.row = 5
			var neighbor: Dictionary = _fixture_tile(view, "stay", 1, 0)
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
			check(view.game.cell(int(support.id)).is_empty() and payouts.size() == 1 and payouts[0].amount == 50,
				"a support collection with a rare bonus starts gravity after exactly one coin payment")
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


func _check_dragged_support_fall(view) -> void:
	for reduced: bool in [false, true]:
		for pointer: int in [-1, 7]:
			for interruption: String in ["cancel", "pointer_cancel", "outside", "pause", "focus"]:
				_reset(view, reduced)
				view.game.cells.clear()
				var support: Dictionary = _fixture_tile(view, "hat", 2, 2)
				var lower: Dictionary = _fixture_tile(view, "nose", 2, 1)
				var upper: Dictionary = _fixture_tile(view, "shoe", 2, 0)
				for index in range(3):
					var tile: Dictionary = [support, lower, upper][index]
					tile.column = 1
					tile.row = Model.ROWS - 1 - index
					view.game.cells.append(tile)
				view._sync_tiles()
				view._layout()
				var source: int = int(support.id)
				var origin: Vector2 = _center(view, source)
				var lower_origin: Vector2 = view._tiles[int(lower.id)].position
				var upper_origin: Vector2 = view._tiles[int(upper.id)].position
				var destination: Vector2 = _placement_point(view, support, 4, 3)
				_pointer_event(view, pointer, "down", origin)
				_pointer_event(view, pointer, "move", origin + Vector2(3.0 / Style.ui_scale(view), 0.0))
				_advance(view, 0.1)
				check(not view._dragging and not view.game.is_lifted(source)
					and view._tiles[int(lower.id)].position.is_equal_approx(lower_origin),
					"pressing a support or moving below the drag threshold leaves its stack supported")
				_pointer_event(view, pointer, "move", destination)
				check(view._dragging and view.game.is_lifted(source) and view._source == source,
					"mouse and touch lift the source only when actual dragging begins")
				check(int(lower.row) == Model.ROWS - 1 and int(upper.row) == Model.ROWS - 2
					and bool(lower.get("falling", false)) and bool(upper.get("falling", false)),
					"dragging hat away starts both nose and shoe falling before pointer release")
				var held_position: Vector2 = view._tiles[source].position
				_advance(view, Model.SETTLE_SECONDS * 0.45)
				if reduced:
					check(view._tiles[int(lower.id)].position.is_equal_approx(view._tile_rect(lower).position),
						"reduced motion places the unsupported word at its new supported destination")
				else:
					check(view._tiles[int(lower.id)].position.y > lower_origin.y
						and view._tiles[int(lower.id)].position.y < view._tile_rect(lower).position.y
						and view._tiles[int(upper.id)].position.y > upper_origin.y,
						"the painted stack descends through an intermediate pose while the pointer stays down")
				_advance(view, Model.SETTLE_SECONDS)
				check(view._source == source and view._dragging
					and view._tiles[source].position.is_equal_approx(held_position),
					"falling neighbors cannot move or release the jelly following the pointer")
				check(view._settled(lower) and view._settled(upper)
					and view._tiles[int(lower.id)].get_rect().is_equal_approx(view._tile_rect(lower))
					and view._tiles[int(upper.id)].get_rect().is_equal_approx(view._tile_rect(upper)),
					"both upper words finish their fall while the lower support remains held")
				check(cues.count("land") == 1 and payouts.is_empty() and attempts.is_empty(),
					"support loss produces one landing cue without collection or reward events")
				match interruption:
					"cancel": view.cancel_input()
					"pointer_cancel": _pointer_event(view, pointer, "up", destination, true)
					"outside": _pointer_event(view, pointer, "up", view.get_global_transform() * (view._board.end + Vector2(100.0, 0.0)))
					"pause":
						view.pause(true)
						view.pause(false)
					"focus": view._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
				_advance(view, Model.SETTLE_SECONDS * 3.0)
				check(not view.game.is_lifted(source) and view._source == -1 and not view._dragging,
					"%s clears the lifted source and pointer ownership" % interruption)
				for tile: Dictionary in view.game.cells:
					check(_has_support(view.game.cells, tile) and view._settled(tile)
						and view._tiles[int(tile.id)].get_rect().is_equal_approx(view._tile_rect(tile)),
						"%s restores every body at a supported, interactive visual position" % interruption)
					for other: Dictionary in view.game.cells:
						if int(tile.id) < int(other.id):
							check(not view._tile_rect(tile).intersects(view._tile_rect(other)),
								"returning the dragged support cannot overlap words that fell into its old position")
				check(support.text == "hat" and int(support.mass) == 2 and int(support.fragments) == 2
					and int(lower.fragments) == 1 and view.game.cells.size() == 3
					and view.game.fusions.is_empty() and payouts.is_empty() and attempts.is_empty() and heard.is_empty(),
					"support removal and cancellation retain every word and fragment without merging or collecting")


func _check_release_after_support_collection(view) -> void:
	_reset(view)
	view.game.cells.clear()
	var support: Dictionary = _fixture_tile(view, "cat", 2, 0)
	support.column = 1
	support.row = Model.ROWS - 1
	var upper: Dictionary = _fixture_tile(view, "root:cat", 1, 1)
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
	var support: Dictionary = _fixture_tile(view, "cat", 2, 0)
	support.column = 1
	support.row = Model.ROWS - 1
	var upper: Dictionary = _fixture_tile(view, "root:cat", 1, 0)
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
	_reset(view)
	var ids: Array[int] = _completion_board(view, ["root:cat", "picture:cat", "picture:cat", "root:caterpillar", "picture:caterpillar", "x"])
	var resting: Array = view.snapshot().tiles
	for tile: Dictionary in resting:
		check(int(tile.get("palette_index", -1)) >= 0 and float(tile.get("palette_hue", -1.0)) >= 0.0,
			"hybrid faces expose the palette actually used by their painted gel")
		check(is_equal_approx(float(tile.palette_hue), float(view._tiles[int(tile.id)]._gel.get_shader_parameter("palette_hue"))),
			"color diagnostics match the rendered shader")
		for other: Dictionary in resting:
			if int(tile.id) >= int(other.id) or tile.palette_index != other.palette_index:
				continue
			check(view.game.parts_compatible(view.game.cell(int(tile.id)), view.game.cell(int(other.id)))
				or view.game.parts_compatible(view.game.cell(int(other.id)), view.game.cell(int(tile.id))),
				"a shared resting color represents an exact word-picture or same-level match")
	for keyboard: bool in [false, true]:
		for source_index: int in [0, 1]:
			if keyboard:
				view._activate(ids[source_index])
			else:
				check(view._press(-1, _center(view, ids[source_index])), "either a root or picture can preview exact partners")
			var targets: Array[int] = []
			targets.assign([ids[1], ids[2]] if source_index == 0 else [ids[0]])
			_assert_completion_hints(view, targets, "symmetric picture matching")
			for target: int in targets:
				check(view._tiles[target].palette_index == view._tiles[ids[source_index]].palette_index,
					"all exact partners adopt the selected face's hue")
			view.cancel_input()
			_assert_resting_palette(view, resting, "canceled hybrid match")
	view.apply_theme(Data.theme("autumn"), data.chests)
	_assert_resting_palette(view, resting, "theme update")
	for index in range(view._preview_tiles.size()):
		var slot: Dictionary = view.snapshot().preview.slots[index]
		check(int(slot.get("palette_index", -1)) >= 0 and is_equal_approx(float(slot.palette_hue),
			float(view._preview_tiles[index]._gel.get_shader_parameter("palette_hue"))),
			"previews publish the hue their actual gel renders")

func _assert_resting_palette(view, resting: Array, context: String) -> void:
	for original: Dictionary in resting:
		var id: int = int(original.id)
		var tile: Dictionary = _palette_item(view, id)
		check(tile.get("palette_index", -1) == original.get("palette_index", -2)
			and is_equal_approx(float(tile.get("palette_hue", -1.0)), float(original.get("palette_hue", -2.0))),
			context + ": ineligible bodies retain their resting palette")
		check(is_equal_approx(float(view._tiles[id]._gel.get_shader_parameter("palette_hue")),
			float(original.get("palette_hue", -2.0))), context + ": rendered gel retains its resting hue")


func _check_directional_palette_stability(view) -> void:
	for pointer: int in [-1, 7]:
		view.size = Vector2(1000, 720) if pointer < 0 else Vector2(390, 700)
		for reduced: bool in [false, true]:
			_reset(view, reduced)
			var ids: Array[int] = _completion_board(view, ["root:cat", "picture:cat", "picture:cat", "root:caterpillar", "picture:caterpillar", "x"])
			var resting: Array = view.snapshot().tiles
			for source_index: int in [0, 1]:
				var point: Vector2 = _center(view, ids[source_index])
				_pointer_event(view, pointer, "down", point)
				_pointer_event(view, pointer, "move", point + Vector2(0.0, -18.0))
				_advance(view, 0.24)
				var targets: Array[int] = []
				targets.assign([ids[1], ids[2]] if source_index == 0 else [ids[0]])
				_assert_completion_hints(view, targets, "either drag direction")
				check(view._dragging, "root and picture each enter an actual drag")
				var unaffected: Array = resting.filter(func(tile: Dictionary) -> bool: return not int(tile.id) in targets)
				_assert_resting_palette(view, unaffected, "unrelated words during a hybrid drag")
				view.cancel_input()
				_assert_resting_palette(view, resting, "canceled hybrid drag")
				_assert_completion_hints(view, [], "canceled hybrid drag")
	view.size = Vector2(1000, 720)

func _assert_completion_effect(body, active: bool, context: String) -> void:
	var visible_glints: int = 0
	for glint: TextureRect in body._completion_glints:
		if glint.visible:
			visible_glints += 1
	check(visible_glints == (1 if active else 0), "%s: only eligible targets display the small surface reflection" % context)
	var strength: Variant = body._gel.get_shader_parameter("completion_strength")
	check((strength != null and float(strength) > 0.35) == active,
		"%s: target strength clears while merged words retain their permanent light" % context)


func _assert_completion_hints(view, expected: Array[int], context: String) -> void:
	for tile: Dictionary in view.snapshot().tiles:
		var active: bool = int(tile.id) in expected
		var body = view._tiles[int(tile.id)]
		check(tile.has("completion_hint") and bool(tile.get("completion_hint", false)) == active
			and bool(body.completion_hint) == active, "%s: completion hint follows the live eligible target" % context)
		_assert_completion_effect(body, active, context)
		check(tile.has("completion_scale") and is_equal_approx(float(tile.get("completion_scale", -1.0)), float(body.completion_scale)),
			"%s: diagnostic scale matches the rendered completion feedback" % context)
		if not active:
			check(is_equal_approx(float(body.completion_scale), 1.0), "%s: inactive bodies have no residual completion enlargement" % context)
	for preview in view._preview_tiles:
		check(not preview.completion_hint and is_equal_approx(float(preview.completion_scale), 1.0),
			"%s: upcoming parts never advertise an actionable completion" % context)
		_assert_completion_effect(preview, false, context + " preview")
	check(not view._placement_tile.completion_hint, "%s: placement projection never acts as a second completion target" % context)
	_assert_completion_effect(view._placement_tile, false, context + " placement")


func _completion_board(view, pieces: Array[String], fragments: Array[int] = []) -> Array[int]:
	view.game.cells.clear()
	var ids: Array[int] = []
	for text: String in pieces:
		var tile: Dictionary = _fixture_tile(view, text, 1, fragments[ids.size()] if ids.size() < fragments.size() else 0)
		tile.column = ids.size() % Model.COLUMNS
		tile.row = Model.ROWS - 1 - floori(float(ids.size()) / Model.COLUMNS)
		ids.append(int(tile.id))
		view.game.cells.append(tile)
	view._sync_tiles()
	view._layout()
	return ids


func _check_completion_hints(view) -> void:
	for pointer: int in [-1, 7]:
		view.size = Vector2(1000, 720) if pointer < 0 else Vector2(390, 700)
		_reset(view)
		var ids: Array[int] = _completion_board(view, ["root:cat", "picture:cat", "picture:cat", "picture:cat", "picture:caterpillar", "x"])
		var target = view._tiles[ids[1]]
		var rectangle: Rect2 = target.get_rect()
		var outline: PackedVector2Array = target.contact_outline()
		var center: Vector2 = _center(view, ids[0])
		_assert_completion_hints(view, [], "idle")
		_pointer_event(view, pointer, "down", center)
		_assert_completion_hints(view, [ids[1], ids[2], ids[3]], "press before dragging")
		_pointer_event(view, pointer, "move", center + Vector2(0.0, -4.0))
		check(not view._dragging, "small pointer jitter keeps the source pressed")
		_pointer_event(view, pointer, "move", center + Vector2(0.0, -12.0))
		check(view._dragging, "moving beyond the threshold starts a drag")
		_advance(view, 0.22)
		_assert_completion_hints(view, [ids[1], ids[2], ids[3]], "all matching pictures")
		for id: int in [ids[1], ids[2], ids[3]]:
			check(float(view._tiles[id].completion_scale) > 1.0 and float(view._tiles[id].completion_scale) <= 1.025,
				"each exact target receives a small completion enlargement")
		check(target.get_rect().is_equal_approx(rectangle) and target.contact_outline() == outline,
			"completion animation preserves layout and hit geometry")
		check(cues.count("pick") == 1 and cues.count("contact") <= 1 and cues.count("wrong") == 0 \
			and heard.is_empty() and payouts.is_empty() and attempts.is_empty(),
			"completion guidance does not grant speech, learning credit or rewards")
		view.cancel_input()
		view._activate(ids[1])
		_assert_completion_hints(view, [ids[0]], "picture first")
		view.cancel_input()
		view._activate(ids[0])
		_assert_completion_hints(view, [ids[1], ids[2], ids[3]], "keyboard root selection")
		view._tiles[ids[1]].grab_focus()
		var change_source := InputEventKey.new()
		change_source.keycode = KEY_ENTER
		change_source.pressed = true
		change_source.shift_pressed = true
		view._input(change_source)
		check(view._keyboard_source == ids[1], "keyboard shortcut replaces the active source without merging")
		_assert_completion_hints(view, [ids[0]], "keyboard picture selection")
		view.cancel_input()
	view.size = Vector2(1000, 720)

func _check_ordered_completion_contact(view) -> void:
	for pointer: int in [-1, 7]:
		view.size = Vector2(1000, 720) if pointer < 0 else Vector2(390, 700)
		for reduced: bool in [false, true]:
			for pair: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4)]:
				_reset(view, reduced)
				var fragments: Array[int] = [0, 0, 0, 0, 0]
				fragments[pair.x] = 1
				fragments[pair.y] = 2
				var complete: bool = pair == Vector2i(0, 1) or pair == Vector2i(1, 0)
				# Isolate rejection from the nearby valid-match priority covered by
				# the crowded drag interaction tests.
				var pieces: Array[String] = ["root:cat", "picture:cat" if complete else "picture:caterpillar", "picture:caterpillar", "root:cat", "x"]
				var ids: Array[int] = _completion_board(view, pieces, fragments)
				var originals: Array = view.game.cells.duplicate(true)
				var source: int = ids[pair.x]
				var target: int = ids[pair.y]
				var center: Vector2 = _center(view, source)
				var destination: Vector2 = _center(view, target)
				_pointer_event(view, pointer, "down", center)
				_pointer_event(view, pointer, "move", destination)
				_advance(view, 0.16)
				var kind: String = "match" if complete else "touch"
				check(view._dragging and view._target == target and view._contact_state().kind == kind,
					"word-picture matching is symmetric; wrong pictures and same-kind roots retain neutral contact")
				_assert_contact_surfaces(view, source, target, kind, reduced, "hybrid contact")
				check(cues.count("contact") == 1 and cues.count("wrong") == 0 and heard.is_empty()
					and payouts.is_empty() and attempts.is_empty(), "held contact never grants a reward or negative cue")
				for repeat in range(5):
					_pointer_event(view, pointer, "move", destination)
				_advance(view, 0.3)
				check(cues.count("contact") == 1 and view.game.fusions.is_empty(), "held contact neither repeats its sound nor commits early")
				_pointer_event(view, pointer, "up", destination)
				if complete:
					check(view.game.fusions.size() == 1 and cues.count("merge") == 1 and cues.count("wrong") == 0,
						"either correct direction commits one fusion")
					var merged_id: int = _merged_id(view)
					_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS * 2.0)
					var merged: Dictionary = view.game.cell(merged_id)
					check(merged.text == "cat" and view.game.is_valid_word(merged) and merged.fragments == 3,
						"a correct result retains both inputs' fragments")
				else:
					_assert_rejected_merge(view, originals, source, target, reduced, "hybrid mismatch")
					_pointer_event(view, pointer, "up", destination)
					check(cues.count("wrong") == 1, "a repeated release cannot replay rejection")
				_assert_completion_hints(view, [], "released hybrid contact")
				check(payouts.is_empty() and attempts.is_empty(), "fusion alone never collects or credits mastery")
	view.size = Vector2(1000, 720)

func _assert_rejected_merge(view, originals: Array, source_id: int, target_id: int, reduced: bool, context: String) -> void:
	check(view.game.fusions.is_empty() and view._fusion_visuals.is_empty() and cues.count("wrong") == 1
		and cues.count("merge") == 0 and cues.count("pop") == 0,
		context + ": one failed committed merge produces one wrong cue with no fusion or collection effect")
	check(view._contact_state().kind == "mismatch" and int(view._rejection.a) == source_id and int(view._rejection.b) == target_id,
		context + ": rejection marks precisely the attempted source and target")
	check(not view.snapshot().word_reveal.visible and payouts.is_empty() and attempts.is_empty() and heard.is_empty()
		and view.game.collected_coins == 0 and view.game.fragment_count == 0 and view.game.cleared_pairs == 0,
		context + ": rejection cannot pronounce, reveal, teach, collect fragments, or grant coins")
	_advance(view, 0.12)
	for id: int in [source_id, target_id]:
		var body = view._tiles[id]
		var rim: Color = body._gel.get_shader_parameter("rim_color")
		check(body._contact_kind == "mismatch" and rim.is_equal_approx(Color("#b54649")) and not body.highlighted,
			context + ": both failed inputs carry the temporary negative rim")
		if reduced:
			check(body._surface.position.is_zero_approx() and body._surface.scale.is_equal_approx(Vector2.ONE)
				and is_zero_approx(float(body._gel.get_shader_parameter("contact_strength")))
				and body.get_rect().is_equal_approx(view._tile_rect(view.game.cell(id))),
				context + ": reduced-motion rejection stays static at the original body rectangle")
		else:
			check(float(body._gel.get_shader_parameter("contact_strength")) > 0.0,
				context + ": failed inputs show elastic rejection while the source returns")
	_advance(view, 0.3)
	check(view.game.cells.size() == originals.size() and view.game.fusions.is_empty() and view._rejection.is_empty()
		and view._snapbacks.is_empty() and view._contact_state().kind == "none" and cues.count("wrong") == 1,
		context + ": rejection and snapback finish without consuming bodies or replaying audio")
	for original: Dictionary in originals:
		var tile: Dictionary = view.game.cell(int(original.id))
		check(not tile.is_empty(), context + ": every original tile identity survives")
		for field: String in ["text", "mass", "parts_count", "fragments", "chest", "word", "kind", "skin"]:
			check(tile.get(field) == original.get(field), context + ": rejection preserves " + field)
		check(view._tiles[int(tile.id)].visible_fragment_badges() == mini(2, int(tile.fragments)),
			context + ": carried fragments stay on their original artwork")
		check(view._tiles[int(tile.id)].get_rect().is_equal_approx(view._tile_rect(tile)),
			context + ": final painted bodies agree with their retained model rectangles")


func _assert_contact_surfaces(view, source_id: int, target_id: int, kind: String, reduced: bool, context: String) -> void:
	var source = view._tiles[source_id]
	var target = view._tiles[target_id]
	for body in [source, target]:
		check(body._contact_kind == kind and (body._gel.get_shader_parameter("contact_match") == true) == (kind == "match"),
			context + ": both rendered skins separate physical contact from word completion")
		var strength: float = float(body._gel.get_shader_parameter("contact_strength"))
		check(is_zero_approx(strength) if reduced else strength > 0.0,
			context + ": contact pressure is visible on both bodies unless reduced motion is enabled")
		if kind == "touch":
			var rim: Color = body._gel.get_shader_parameter("rim_color")
			check(not rim.is_equal_approx(Color("#b54649")) and not rim.is_equal_approx(Color("#24856a"))
				and not body.highlighted and not body.completion_hint,
				context + ": neutral touching has neither rejection red nor successful completion marking")
		if reduced:
			check(body._surface.position.is_zero_approx() and body._surface.scale.is_equal_approx(Vector2.ONE),
				context + ": reduced-motion contact keeps both skins still")
		else:
			check(not body._surface.scale.is_equal_approx(body._base_stretch),
				context + ": both touching bodies visibly compress or stretch")
	if not reduced:
		check(source._surface.position.dot(target._surface.position) < 0.0,
			context + ": both bodies give reciprocal physical contact feedback")


func _check_neutral_contact_targets(view) -> void:
	for pointer: int in [-1, 7]:
		view.size = Vector2(1000, 720) if pointer < 0 else Vector2(390, 700)
		for reduced: bool in [false, true]:
			for fixture: Dictionary in [{"pieces": ["x", "cat"], "masses": [1, 2]},
				{"pieces": ["cat", "x"], "masses": [2, 1]}, {"pieces": ["x", "caterpillar"], "masses": [1, 7]}]:
				_reset(view, reduced)
				var pieces: Array[String] = []
				pieces.assign(fixture.pieces)
				var masses: Array[int] = []
				masses.assign(fixture.masses)
				var ids: Array[int] = _install(view, pieces, [], masses)
				var target = view._tiles[ids[1]]
				var destination: Vector2 = _center(view, ids[1])
				var target_rect: Rect2 = target.get_rect()
				var target_outline: PackedVector2Array = target.contact_outline()
				var context: String = "%s + %s neutral contact with %s%s" % [pieces[0], pieces[1],
					"mouse" if pointer < 0 else "touch", " and reduced motion" if reduced else ""]
				_pointer_event(view, pointer, "down", _center(view, ids[0]))
				_pointer_event(view, pointer, "move", destination)
				_advance(view, 0.16)
				check(view._target == ids[1] and view._contact_state().kind == "touch",
					context + ": a complete or long word still participates in physical collision")
				_assert_contact_surfaces(view, ids[0], ids[1], "touch", reduced, context)
				check(target.get_rect().is_equal_approx(target_rect) and target.contact_outline() == target_outline,
					context + ": pressure never changes the target's layout or collision outline")
				var empty: Vector2 = view.get_global_transform() * (view._board.position + Vector2(view._pitch * 0.5, view._pitch * 0.5))
				_pointer_event(view, pointer, "move", empty)
				# Separation must be rendered before testing a later recontact.
				view._process(0.0)
				check(view._target == -1 and view._contact_state().kind == "none", context + ": separating ends the collision")
				for id: int in ids:
					check(view._tiles[id]._contact_kind == "none" and view._tiles[id]._surface.position.is_zero_approx(),
						context + ": separating immediately clears pressure from both skins")
				_pointer_event(view, pointer, "move", destination)
				_advance(view, 0.2)
				check(cues.count("contact") == 2, context + ": touching again plays exactly one new contact cue")
				view.cancel_input()
				_advance(view, 0.2)
				check(cues.count("contact") == 2 and view.game.fusions.is_empty() and heard.is_empty()
					and payouts.is_empty() and attempts.is_empty() and cues.count("wrong") == 0
					and cues.count("merge") == 0 and cues.count("pop") == 0,
					context + ": cancelling contact never rejects, merges, collects, pronounces, or rewards the complete word")
	view.size = Vector2(1000, 720)


func _check_invalid_body_combinations(view) -> void:
	for pointer: int in [-1, 7]:
		for reduced: bool in [false, true]:
			for fixture: Dictionary in [{"pieces": ["x", "cat"], "masses": [1, 2]},
				{"pieces": ["cat", "x"], "masses": [2, 1]}, {"pieces": ["x", "caterpillar"], "masses": [1, 7]}]:
				_reset(view, reduced)
				var pieces: Array[String] = []
				pieces.assign(fixture.pieces)
				var masses: Array[int] = []
				masses.assign(fixture.masses)
				var ids: Array[int] = _install(view, pieces, [1, 2], masses)
				var originals: Array = view.game.cells.duplicate(true)
				var destination: Vector2 = _center(view, ids[1])
				_pointer_event(view, pointer, "down", _center(view, ids[0]))
				_pointer_event(view, pointer, "move", destination)
				# Inspect contact after the frame consumes the latest pointer motion.
				view._process(0.0)
				check(view._contact_state().kind == "touch" and cues.count("wrong") == 0,
					"roots, valid words, and long spellings all retain neutral physical contact while held")
				_pointer_event(view, pointer, "up", destination)
				_assert_rejected_merge(view, originals, ids[0], ids[1], reduced,
					"invalid body combination %s + %s" % pieces)


func _check_rejection_rim_reset(view) -> void:
	for reduced: bool in [false, true]:
		for fixture: Dictionary in [{"pieces": ["picture:cat", "picture:cat"], "masses": [1, 1]},
			{"pieces": ["x", "cat"], "masses": [1, 2]}, {"pieces": ["cat", "x"], "masses": [2, 1]}]:
			_reset(view, reduced)
			var pieces: Array[String] = []
			pieces.assign(fixture.pieces)
			var masses: Array[int] = []
			masses.assign(fixture.masses)
			var ids: Array[int] = _install(view, pieces, [], masses)
			var idle: Dictionary = {}
			for id: int in ids:
				var body = view._tiles[id]
				body.release_focus()
				idle[id] = {"color": body._gel.get_shader_parameter("rim_color"),
					"strength": body._gel.get_shader_parameter("rim_strength"), "width": body._gel.get_shader_parameter("rim_width")}
			_drag(view, ids[0], ids[1])
			_advance(view, 0.339)
			check(view._contact_state().kind == "mismatch", "the rejection rim remains active until its feedback window ends")
			_advance(view, 0.002)
			check(view._contact_state().kind == "none" and view._rejection.is_empty(),
				"the rejection contact clears immediately after 340 milliseconds")
			for id: int in ids:
				var body = view._tiles[id]
				var color: Color = body._gel.get_shader_parameter("rim_color")
				check(body._contact_kind == "none" and not body.has_focus() and color.is_equal_approx(idle[id].color)
					and is_equal_approx(float(body._gel.get_shader_parameter("rim_strength")), float(idle[id].strength))
					and is_equal_approx(float(body._gel.get_shader_parameter("rim_width")), float(idle[id].width)),
					"plain roots and valid merged words restore their exact idle rim after rejection")


func _check_neutral_contact_lifecycle(view) -> void:
	for interruption: String in ["cancel", "pointer_cancel", "pause", "hide", "focus", "blocked", "stop", "reconfigure"]:
		_reset(view)
		var ids: Array[int] = _install(view, ["x", "cat"], [], [1, 2])
		var destination: Vector2 = _center(view, ids[1])
		_pointer_event(view, 7, "down", _center(view, ids[0]))
		_pointer_event(view, 7, "move", destination)
		_advance(view, 0.16)
		check(view._contact_state().kind == "touch", interruption + ": the interruption starts from an active neutral collision")
		match interruption:
			"cancel": view.cancel_input()
			"pointer_cancel": _pointer_event(view, 7, "up", destination, true)
			"pause": view.pause(true)
			"hide": view.hide()
			"focus": view._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
			"blocked":
				view.interaction_allowed = func() -> bool: return false
				view._process(0.01)
			"stop": view.stop()
			"reconfigure": _reset(view)
		check(view._contact_state().kind == "none", interruption + ": interruption immediately ends neutral contact ownership")
		for body in view._tiles.values():
			check(body._contact_kind == "none" and body._surface.position.is_zero_approx(),
				interruption + ": no surviving jelly keeps collision pressure or an offset")
		check(view.game.fusions.is_empty() and heard.is_empty() and payouts.is_empty() and attempts.is_empty()
			and cues.count("wrong") == 0 and cues.count("merge") == 0 and cues.count("pop") == 0,
			interruption + ": a cancelled contact never rejects, commits a merge, or collects a word")
		view.interaction_allowed = Callable()
		view.show()
		view.pause(false)


func _check_completion_hint_targets(view) -> void:
	for mass: int in [2, 7]:
		_reset(view)
		var ids: Array[int] = _install(view, ["root:cat", "picture:cat"], [], [1, mass])
		view._activate(ids[0])
		_assert_completion_hints(view, [ids[1]], "short and long ordinary completion targets")
		check(int(view.game.cell(ids[1]).width) == 1 and int(view.game.cell(ids[1]).height) == 1
			and view._tiles[ids[0]].size.is_equal_approx(view._tiles[ids[1]].size),
			"completion guidance keeps the same ordinary hit area regardless of the target's semantic mass")
		view.cancel_input()
	_reset(view)
	var ids: Array[int] = _completion_board(view, ["root:cat", "picture:cat", "picture:cat", "picture:cat", "root:cat", "picture:cat"])
	var airborne: Dictionary = view._cell(ids[2])
	airborne.age = 0.0
	airborne.arrival = true
	airborne.arrival_delay = 1.0
	view._merge(ids[4], ids[3], view._tiles[ids[4]].position)
	check(view.game.is_fusing(ids[3]) and not view._settled(airborne), "completion fixture has both fusing and airborne partners")
	view._activate(ids[0])
	_assert_completion_hints(view, [ids[1], ids[5]], "only settled actionable partners")
	for visual: Dictionary in view._fusion_visuals.values():
		check(not visual.merged.completion_hint, "temporary fusion artwork is not a selectable completion")
	view.cancel_input()


func _check_completion_hint_lifecycle(view) -> void:
	for interruption: String in ["release", "merge", "cancel", "pointer_cancel", "pause", "hide", "focus", "blocked", "stop", "reconfigure"]:
		_reset(view)
		var ids: Array[int] = _install(view, ["root:cat", "picture:cat"])
		var target = view._tiles[ids[1]]
		var center: Vector2 = _center(view, ids[0])
		_pointer_event(view, 7, "down", center)
		_pointer_event(view, 7, "move", center + Vector2(12.0, 0.0))
		_advance(view, 0.2)
		check(target.completion_hint and float(target.completion_scale) > 1.0, "%s starts from an animated completion target" % interruption)
		match interruption:
			"release": _pointer_event(view, 7, "up", center)
			"merge": _pointer_event(view, 7, "up", _center(view, ids[1]))
			"cancel": view.cancel_input()
			"pointer_cancel": _pointer_event(view, 7, "up", center, true)
			"pause": view.pause(true)
			"hide": view.hide()
			"focus": view._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
			"blocked":
				view.interaction_allowed = func() -> bool: return false
				view._process(0.01)
			"stop": view.stop()
			"reconfigure": _reset(view)
		check(not target.completion_hint and is_equal_approx(float(target.completion_scale), 1.0),
			"%s immediately removes the old target's light and enlargement" % interruption)
		_assert_completion_effect(target, false, interruption + " old target")
		_assert_completion_hints(view, [], interruption)
		view.interaction_allowed = Callable()
		view.show()
		view.pause(false)
		check(heard.is_empty() and payouts.is_empty(), "%s cannot turn completion feedback into an unintended collection" % interruption)


func _check_completion_hint_reduced_motion(view) -> void:
	_reset(view, true)
	var ids: Array[int] = _install(view, ["root:cat", "picture:cat"])
	view._activate(ids[0])
	_assert_completion_hints(view, [ids[1]], "reduced motion retains static completion guidance")
	var target = view._tiles[ids[1]]
	var rim_color: Color = target._gel.get_shader_parameter("rim_color")
	var rim_strength: float = target._gel.get_shader_parameter("rim_strength")
	var glints: Array[Dictionary] = []
	for glint: TextureRect in target._completion_glints:
		glints.append({"transform": glint.get_transform(), "color": glint.modulate})
	_advance(view, 0.3)
	check(is_equal_approx(float(view._tiles[ids[1]].completion_scale), 1.0), "reduced-motion completion guidance never scales the body")
	check(target._gel.get_shader_parameter("rim_color") == rim_color and is_equal_approx(float(target._gel.get_shader_parameter("rim_strength")), rim_strength),
		"reduced-motion completion contour remains steady over time")
	for index in range(glints.size()):
		var glint: TextureRect = target._completion_glints[index]
		check(glint.get_transform().is_equal_approx(glints[index].transform) and glint.modulate.is_equal_approx(glints[index].color),
			"reduced-motion surface reflection stays still and keeps constant brightness")
	view.set_reduced_motion(false)
	_advance(view, 0.2)
	check(view._tiles[ids[1]].completion_hint and float(view._tiles[ids[1]].completion_scale) > 1.0,
		"reenabling motion restores subtle movement for the still-active target")
	view.set_reduced_motion(true)
	_assert_completion_hints(view, [ids[1]], "changing reduced motion keeps completion semantics")
	check(is_equal_approx(float(view._tiles[ids[1]].completion_scale), 1.0), "switching reduced motion on immediately resets target enlargement")
	view.cancel_input()
	_assert_completion_hints(view, [], "reduced-motion cancellation")


func _check_partial_word_colors(view) -> void:
	_reset(view)
	view.game.cells.clear()
	var ids: Array[int] = []
	for text: String in ["cate", "rpil", "lar"]:
		var tile: Dictionary = _fixture_tile(view, text, 1, 0)
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
	check(view.game.fusions.is_empty() and cues.count("wrong") == 1 and cues.count("merge") == 0,
		"new input rejects an incomplete prefix instead of creating a persistent partial word")
	_advance(view, 0.4)

func _hue_distance(first: float, second: float) -> float:
	return absf(fposmod(first - second + 0.5, 1.0) - 0.5)


func _check_fusion_palette_handover(view) -> void:
	_reset(view)
	var ids: Array[int] = _completion_board(view, ["root:cat", "picture:cat", "merged:cat", "x"])
	_drag(view, ids[0], ids[1])
	var pending: Dictionary = view.game.fusions[0]
	var visual: Dictionary = view._fusion_visuals[str(pending.attempt_id)]
	var input_colors: Array[int] = [visual.palette_a, visual.palette_b]
	for id: int in view._palette_indices:
		check(not int(view._palette_indices[id]) in input_colors, "fusion input paint remains reserved during recoloring")
	var alternate: int = ids[2]
	check(view._press(-1, _center(view, alternate)), "a same-level merged word can be selected during an unrelated fusion")
	_advance(view, Model.FUSION_SECONDS * 0.83)
	check(not view._tiles[alternate].requires_read and not view.snapshot().read_detail.visible and not view.game.paused,
		"holding a readable merged word keeps the pending fusion running")
	check(visual.merged.palette_index == view._tiles[alternate].palette_index, "the future result adopts its pending same-level upgrade partner's hue")
	check(_hue_distance(float(visual.art._gel.get_shader_parameter("palette_hue_b")), float(visual.merged._gel.get_shader_parameter("palette_hue"))) < 0.00001,
		"liquid paint reaches the result hue before skin handover")
	_advance(view, Model.FUSION_SECONDS * 0.18 + Model.SETTLE_SECONDS)
	var merged_id: int = int(pending.result.id)
	check(view._tiles[merged_id].palette_index == view._tiles[alternate].palette_index, "persistent paint agrees with the live upgrade hint after handover")
	view.cancel_input()

func _check_crowded_palette_separation(view) -> void:
	_reset(view)
	view.game.cells.clear()
	for index in range(18):
		var tile: Dictionary = _fixture_tile(view, "unpaired%d" % index, 1, 0)
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
		var ids: Array[int] = _install(view, ["root:cat", "picture:cat"])
		var target: Dictionary = view.game.cell(ids[1])
		var target_rect: Rect2 = view._tile_rect(target)
		var neighbor: Dictionary = _fixture_tile(view, "stay", 1, 0)
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


func _check_repeat_merge_compact_body(view) -> void:
	_reset(view)
	var ids: Array[int] = _install(view, ["merged:cat", "merged:cat"], [2, 3], [2, 5])
	var ordinary_size: Vector2 = view._tiles[ids[0]].size
	_drag(view, ids[0], ids[1])
	var id: int = _merged_id(view)
	_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS * 2.0)
	var cell: Dictionary = view.game.cell(id)
	check(cell.text == "cat" and cell.merge_level == 2 and cell.mass == 7 and cell.fragments == 5,
		"identical merged words upgrade once and retain all semantic parts and fragments")
	check(cell.width == 1 and cell.height == 1 and view._tiles[id].size.is_equal_approx(ordinary_size), "level upgrades preserve the ordinary square body")
	check(_has_support(view.game.cells, cell) and not bool(cell.get("placement_locked", false))
		and view._tiles[id].get_rect().is_equal_approx(view._tile_rect(cell)), "upgraded words land with coherent art and hit geometry")
	_assert_compact_label(view._tiles[id], "cat", "level-two word")
	check(view._tiles[id].presentation_snapshot().level_badge == "2" and view._tiles[id].fragment_badge_snapshot().count_text == "5",
		"level and exact fragment count remain independently visible")
	var extra: Dictionary = _fixture_tile(view, "merged:cat", 2, 1)
	extra.column = 0
	extra.row = 0
	view.game.cells.append(extra)
	view._sync_tiles()
	_drag(view, id, int(extra.id))
	check(view.game.fusions.is_empty() and cues.count("wrong") == 1, "different levels reject an upgrade")
	_advance(view, 0.4)
	check(view.game.cell(id).merge_level == 2 and view.game.cell(int(extra.id)).merge_level == 1,
		"a rejected upgrade preserves both levels and their separate identities")
	check(view._tiles[id]._picture.visible and view._tiles[id].fragment_badge_snapshot().count_text == "5"
		and view._tiles[int(extra.id)].visible_fragment_badges() == 1, "upgrade rejection preserves pictures and each carried reward")

func _check_uniform_outline(view) -> void:
	_reset(view, true)
	var ids: Array[int] = _install(view, ["root:cat", "picture:caterpillar"], [], [3, 1])
	var source = view._tiles[ids[0]]
	var target = view._tiles[ids[1]]
	var source_outline: PackedVector2Array = source.contact_outline()
	var min_x: float = INF
	var max_x: float = -INF
	for point: Vector2 in source_outline:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
	var target_min_x: float = INF
	var target_max_x: float = -INF
	for point: Vector2 in target.contact_outline():
		target_min_x = minf(target_min_x, point.x)
		target_max_x = maxf(target_max_x, point.x)
	check(source.size.is_equal_approx(target.size) and is_equal_approx(max_x - min_x, target_max_x - target_min_x),
		"different semantic masses retain the same ordinary painted contact extent")
	view._press(-1, _center(view, ids[0]))
	var destination: Vector2 = target.get_rect().get_center()
	# Search along the horizontal center line from separation toward actual skin
	# overlap; the painted outline is the independent physical contact oracle.
	var first_contact: Vector2 = Vector2.ZERO
	for index in range(100, -1, -1):
		var point: Vector2 = destination + Vector2((source.size.x + target.size.x) * 0.5 * float(index) / 100.0, 0)
		view._move(view.get_global_transform() * point)
		var overlaps: bool = not Geometry2D.intersect_polygons(source.contact_outline(), target.contact_outline()).is_empty()
		check((view._target == ids[1]) == overlaps, "ordinary-body target selection agrees with painted silhouette contact at every sampled edge")
		if overlaps:
			first_contact = point
			break
	check(not first_contact.is_zero_approx() and not target.get_rect().has_point(first_contact),
		"ordinary painted bodies contact before the held center enters the target's rectangle")
	view._release(view.get_global_transform() * first_contact)
	check(view.game.fusions.is_empty() and cues.count("wrong") == 1, "nonmatching edge contact rejects only when released")


func _check_cancel_and_pause(view) -> void:
	_reset(view)
	var ids: Array[int] = _install(view, ["root:cat", "picture:cat"])
	view._press(-1, _center(view, ids[0]))
	view._move(_center(view, ids[1]))
	view.cancel_input()
	view._release(_center(view, ids[1]))
	check(view.game.fusions.is_empty() and payouts.is_empty(), "canceled contact cannot merge or collect")
	_advance(view, Model.SETTLE_SECONDS)
	check(_has_support(view.game.cells, view.game.cell(ids[0])) and _has_support(view.game.cells, view.game.cell(ids[1])),
		"canceling a held unsupported fixture releases both bodies to natural support before the next drag")
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
	var ids: Array[int] = _install(view, ["root:cat", "picture:cat"], [1, 1])
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
	check(view.game.collected_coins == 0 and view.game.fragment_count == 2 and view._loot_flights.is_empty(), "reduced motion preserves Lv1 fragments without inventing a coin reward")


func _check_wallet_failure(view) -> void:
	_reset(view)
	var ids: Array[int] = _install(view, ["merged:cat:2"], [2], [4])
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
	var ids: Array[int] = _install(view, ["root:cat", "picture:cat"])
	view._activate(ids[0])
	check(view._keyboard_source == ids[0] and view.game.fusions.is_empty(), "keyboard activation selects a root")
	view._activate(ids[1])
	check(view.game.fusions.size() == 1 and view._keyboard_source == -1, "keyboard second activation merges in source-target order")
	var id: int = _merged_id(view)
	_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS * 2.0)
	view._activate(id)
	_advance(view, Model.COLLECT_SECONDS)
	check(payouts.size() == 1 and view.game.collected_coins == 0, "keyboard activation collects a Lv1 word without a coin bonus")


func _check_keyboard_rejection(view) -> void:
	for reduced: bool in [false, true]:
		_reset(view, reduced)
		var ids: Array[int] = _completion_board(view, ["picture:cat", "picture:caterpillar", "root:cat"], [1, 2, 2])
		var originals: Array = view.game.cells.duplicate(true)
		view._tiles[ids[0]].pressed.emit()
		check(view._keyboard_source == ids[0] and cues.count("wrong") == 0, "keyboard selection never produces negative feedback")
		check(heard.size() == 1 and heard[0].id == "cat", "Selecting a picture by keyboard pronounces that picture once")
		heard.clear()
		view._tiles[ids[1]].pressed.emit()
		check(view._keyboard_source == -1, "a failed keyboard merge releases the selected source")
		_assert_rejected_merge(view, originals, ids[0], ids[1], reduced, "keyboard picture mismatch")
		view._tiles[ids[2]].pressed.emit()
		check(view._keyboard_source == ids[2] and view._rejection.is_empty(), "keyboard retry immediately selects the correct root")
		view._tiles[ids[0]].pressed.emit()
		check(view.game.fusions.size() == 1 and cues.count("merge") == 1 and cues.count("wrong") == 1, "correct keyboard retry commits once")
		var id: int = _merged_id(view)
		_advance(view, Model.FUSION_SECONDS + Model.SETTLE_SECONDS * 2.0)
		check(view.game.cell(id).text == "cat" and view.game.cell(id).fragments == 3
			and view.game.cell(ids[1]).fragments == 2, "keyboard correction preserves the matched and unmatched rewards")

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
				check(view.game.cells.size() == Model.INITIAL_SETTLED_TILES + Model.DROP_COUNT, "manual and timed release each commit the five preview bodies")
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
						and view._tiles[id]._label.text == packet[index].display_text,
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
				check(coherent_route and view._tiles[first_id]._label.text == packet[0].display_text,
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


func _partial_preview_fixture(view, reduced: bool) -> Array:
	_reset(view, reduced)
	view.game.cells.clear()
	# Three ordinary bodies block three entrances; semantic mass cannot span lanes.
	for column: int in [0, 1, 4]:
		var roof: Dictionary = _fixture_tile(view, "play" if column < 2 else "foot", 2, 1)
		roof.column = column
		roof.row = 0
		view.game.cells.append(roof)
	view.game.upcoming.clear()
	for text: String in ["fat", "hap", "sle", "her", "py"]:
		view.game.upcoming.append(_fixture_tile(view, text, 1, 1 if text in ["fat", "sle"] else 0))
	view._sync_tiles()
	view._layout()
	view._sync_preview()
	return view.game.upcoming.duplicate(true)


func _check_partial_preview_columns(view) -> void:
	for reduced: bool in [false, true]:
		for automatic: bool in [false, true]:
			for dimensions: Vector2 in [Vector2(1366, 768), Vector2(393, 852)]:
				view.size = dimensions
				var packet: Array = _partial_preview_fixture(view, reduced)
				var origins: Array[Rect2] = []
				for preview in view._preview_tiles:
					origins.append(preview.get_rect())
				var generated: int = view.game.generated_tiles
				if automatic:
					view.game.spawn_elapsed = view.game.spawn_interval - 0.001
					_advance(view, 0.001)
				else:
					var point: Vector2 = view.get_global_transform() * view._preview_rect.get_center()
					check(view._press(2, point), "a partially open tray accepts an ordinary pointer press")
					view._release(point)
				check(view.game.generated_tiles == generated + 2 and view.game.cells.size() == 5,
					"only sle and her leave a tray whose three outer entrances have ordinary roof bodies")
				for slot: int in [2, 3]:
					var id: int = int(packet[slot].id)
					var cell: Dictionary = view.game.cell(id)
					check(not cell.is_empty() and cell.column == slot and cell.arrival_index == slot
						and view._arrival_origins[id].slot == slot and view._tiles[id]._label.text == packet[slot].display_text,
						"each middle root owns its original tray slot and the column directly below it")
					var expected: Rect2 = view._tile_rect(cell) if reduced else origins[slot]
					check(view._tiles[id].get_rect().is_equal_approx(expected), "a partial release preserves the original painted origin")
				for sample in range(25):
					for slot: int in [0, 1, 4]:
						var preview = view._preview_tiles[slot]
						check(view.game.upcoming[slot] == packet[slot] and preview.visible
							and preview.tile_id == int(packet[slot].id) and preview._label.text == packet[slot].display_text
							and preview.get_rect().is_equal_approx(origins[slot]) and is_equal_approx(preview.modulate.a, 1.0)
							and not view._tiles.has(int(packet[slot].id)),
							"blocked previews remain visible, unchanged, and in their own slots throughout the middle descent")
					for slot: int in [2, 3]:
						var body = view._tiles[int(packet[slot].id)]
						check(is_equal_approx(body.get_rect().get_center().x, origins[slot].get_center().x),
							"a middle arrival never slides sideways toward another preview or entrance")
					_advance(view, 0.1)
				for slot: int in [2, 3]:
					check(view._preview_tiles[slot].visible and view._preview_tiles[slot].tile_id != int(packet[slot].id)
						and view._preview_tiles[slot].tile_id == int(view.game.upcoming[slot].id),
						"only the two departed slots refill after their own bodies clear the tray")
				check(payouts.is_empty() and attempts.is_empty() and view.game.fragment_count == 0,
					"partial supply preserves reward and learning ledgers")
	view.size = Vector2(1000, 720)


func _check_partial_preview_press_race(view) -> void:
	for reduced: bool in [false, true]:
		var packet: Array = _partial_preview_fixture(view, reduced)
		var point: Vector2 = view.get_global_transform() * view._preview_rect.get_center()
		check(view._press(2, point), "the partial-dispatch race starts with a real held preview")
		view.game.spawn_elapsed = view.game.spawn_interval - 0.001
		_advance(view, 0.001)
		var generated: int = view.game.generated_tiles
		var next: Array = view.game.upcoming.duplicate(true)
		check(view.game.upcoming[0] == packet[0] and view._preview_canceled,
			"automatic partial supply invalidates the held packet even when its first slot stays blocked")
		view._move(point)
		view._release(point)
		check(view.game.generated_tiles == generated and view.game.upcoming == next and cues.count("pick") == 0,
			"releasing a stale partial packet cannot consume replacements or play another pick cue")
		check(view._press(2, point), "a new gesture can immediately use the refilled middle slots")
		view._release(point)
		check(view.game.generated_tiles == generated + 2 and cues.count("pick") == 1,
			"a fresh partial preview gesture releases exactly two more roots once")
		check(view._press(2, point), "partial supply still supports a cancelable tray gesture")
		generated = view.game.generated_tiles
		view.cancel_input()
		view._release(point)
		check(view.game.generated_tiles == generated, "canceling a partial tray gesture does not dispatch supply")


func _preview_skin_pose(tile) -> Dictionary:
	return {"pressure": float(tile._gel.get_shader_parameter("preview_pressure")),
		"sway": float(tile._gel.get_shader_parameter("preview_sway")),
		"pull": float(tile._gel.get_shader_parameter("preview_pull"))}


func _check_skin_pose(actual: Dictionary, expected: Dictionary, reason: String) -> void:
	for field: String in ["pressure", "sway", "pull"]:
		check(actual.has(field) and is_equal_approx(float(actual.get(field, INF)), float(expected[field])),
			"%s preserves the visible %s" % [reason, field])


func _painted_preview_foot(tile) -> float:
	var pull: float = float(tile._gel.get_shader_parameter("preview_pull"))
	return tile.position.y + tile.size.y * Motion.FOOT_Y * (1.0 + pull * tile._surface.scale.y)


func _advance_preview_foot_samples(view, id: int, seconds: float, frame_rate: int) -> void:
	var previous: float = _painted_preview_foot(view._tiles[id])
	var remaining: float = seconds
	while remaining > 0.000001:
		var delta: float = minf(1.0 / float(frame_rate), remaining)
		view._process(delta)
		remaining -= delta
		var current: float = _painted_preview_foot(view._tiles[id])
		check(current >= previous - 0.001,
			"the painted belly keeps falling at %d Hz without an upward release pop: %.4f -> %.4f" % [frame_rate, previous, current])
		previous = current


func _check_preview_pull_handoff(view) -> void:
	for frame_rate: int in [30, 60]:
		_check_preview_pull_handoff_at_rate(view, frame_rate)


func _check_preview_pull_handoff_at_rate(view, frame_rate: int) -> void:
	var neutral := {"pressure": 0.0, "sway": 0.0, "pull": 0.0}
	for reduced: bool in [false, true]:
		for automatic: bool in [false, true]:
			for dimensions: Vector2 in [Vector2(1000, 720), Vector2(390, 844)]:
				view.size = dimensions
				_reset(view, reduced)
				view.game.spawn_interval = Model.INITIAL_SPAWN_INTERVAL
				view.game.spawn_elapsed = view.game.spawn_interval - 0.001 if automatic else view.game.spawn_interval * 0.93
				view._sync_preview()
				var packet: Array = view.game.upcoming.duplicate(true)
				var poses: Dictionary = {}
				var feet: Dictionary = {}
				for preview in view._preview_tiles:
					poses[preview.tile_id] = _preview_skin_pose(preview)
					feet[preview.tile_id] = _painted_preview_foot(preview)
					check(is_zero_approx(float(poses[preview.tile_id].pull)) if reduced else float(poses[preview.tile_id].pull) > 0.20,
						"the handoff starts from a loaded preview skin, or a neutral reduced-motion skin")
				if automatic:
					_advance(view, 0.001)
				else:
					view._drop_next(int(packet[0].id))
				check(is_zero_approx(view.game.spawn_elapsed), "release resets the supply clock before the visual handoff")
				var final_ready: float = 0.0
				for index in range(packet.size()):
					var id: int = int(packet[index].id)
					var origin: Dictionary = view._arrival_origins.get(id, {})
					check(int(origin.get("slot", -1)) == index, "the loaded skin retains its responsive preview slot")
					_check_skin_pose(origin, poses[id], "The captured departure")
					_check_skin_pose(_preview_skin_pose(view._tiles[id]), poses[id], "The first painted arrival frame")
					if not reduced:
						check(is_equal_approx(_painted_preview_foot(view._tiles[id]), float(feet[id])),
							"the first arrival frame starts at the visible loaded foot without a handoff jump")
					final_ready = maxf(final_ready, Model.settle_duration(view.game.cell(id)))
				for preview in view._preview_tiles:
					_check_skin_pose(_preview_skin_pose(preview), neutral, "The replacement preview")
				var first_id: int = int(packet[0].id)
				var last_id: int = int(packet[-1].id)
				_advance_preview_foot_samples(view, first_id, 0.06, frame_rate)
				var departing: Dictionary = _preview_skin_pose(view._tiles[first_id])
				if reduced:
					_check_skin_pose(departing, neutral, "The reduced-motion arrival")
				else:
					check(float(departing.pull) > 0.0 and float(departing.pull) < float(poses[first_id].pull),
						"a departing skin smoothly releases its accumulated downward tension")
					_check_skin_pose(_preview_skin_pose(view._tiles[last_id]), poses[last_id], "The waiting staggered arrival")
				view.pause(true)
				_advance(view, 0.25)
				view.size = Vector2(390, 700) if dimensions.x > dimensions.y else Vector2(1000, 720)
				view._layout()
				_check_skin_pose(_preview_skin_pose(view._tiles[first_id]), departing, "A paused and resized departure")
				view.pause(false)
				_advance_preview_foot_samples(view, first_id, 0.061, frame_rate)
				_check_skin_pose(_preview_skin_pose(view._tiles[first_id]), neutral, "The fully released arrival skin")
				_advance(view, final_ready + 0.001 - float(view.game.cell(first_id).age))
				for item: Dictionary in packet:
					_check_skin_pose(_preview_skin_pose(view._tiles[int(item.id)]), neutral, "The settled board skin")
				check(view.game.generated_tiles == Model.INITIAL_SETTLED_TILES + Model.DROP_COUNT and payouts.is_empty() and heard.is_empty(),
					"preview tension and release cannot create extra bodies, rewards or speech")
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
			check(view.game.can_drop_now() and not view.drop_button.disabled and bool(view.snapshot().preview.enabled),
				"partially refilled supply remains immediately available during descent")
			var old_cells: Array = view.game.cells.duplicate(true)
			var next_packet: Array = view.game.upcoming.duplicate(true)
			view._drop_next(int(next_packet[0].id))
			check(view.game.cells.size() == old_cells.size() + Model.DROP_COUNT
				and view.game.cells.slice(0, old_cells.size()) == old_cells,
				"a second packet starts without moving, restarting, or dropping any earlier arrival")
	view.size = Vector2(1000, 720)


func _check_immediate_preview_packets(view) -> void:
	for reduced: bool in [false, true]:
		_reset(view, reduced)
		var first: Array = view.game.upcoming.duplicate(true)
		view._drop_next(int(first[0].id))
		var previous: Array = view.game.cells.duplicate(true)
		var previous_rects: Dictionary = {}
		for tile: Dictionary in first:
			previous_rects[int(tile.id)] = view._tiles[int(tile.id)].get_rect()
		var second: Array = view.game.upcoming.duplicate(true)
		check(view.game.can_drop_now() and not view.drop_button.disabled,
			"a new packet is available in the same frame as the first departure")
		view._drop_next(int(second[0].id))
		check(view.game.cells.size() == previous.size() + Model.DROP_COUNT
			and view.game.cells.slice(0, previous.size()) == previous,
			"zero-time preview activations preserve the earlier batch and commit each root once")
		for original: Dictionary in first:
			check(view._tiles[int(original.id)].get_rect().is_equal_approx(previous_rects[int(original.id)]),
				"a second packet cannot teleport or restart the first packet's painted bodies")
		for index in range(second.size()):
			var id: int = int(second[index].id)
			var cell: Dictionary = view.game.cell(id)
			var expected: Rect2 = view._tile_rect(cell) if reduced else Rect2(view._preview_origins[index], view._preview_tiles[index].size)
			check(not cell.is_empty() and view._tiles[id].get_rect().is_equal_approx(expected)
				and view._tiles[id]._label.text == str(second[index].display_text),
				"every immediately repeated root starts from its own tray slot with the correct letters")
			if not reduced:
				var visible_waiting: int = 0
				for body: Dictionary in view.game.cells:
					if bool(body.get("arrival", false)) and int(body.arrival_index) == index \
						and float(body.age) <= Model.arrival_delay(body) and view._tiles[int(body.id)].visible:
						visible_waiting += 1
				check(visible_waiting <= 1, "each preview source shows at most one waiting body during rapid releases")
		check(cues.count("pick") == 2 and payouts.is_empty() and attempts.is_empty(),
			"two accepted preview activations emit two pick cues without granting rewards or learning credit")


func _check_arrival_land_timing(view) -> void:
	for reduced: bool in [false, true]:
		for row: int in [0, Model.ROWS - 1]:
			_reset(view, reduced)
			var ids: Array[int] = _install(view, ["root:cat"])
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
			var filler: Dictionary = _fixture_tile(view, "x", 1, 0)
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
	check(payouts.size() == 1 and payouts[0].amount == 0,
		"danger relief completes the Lv1 collection once without inventing a coin bonus")
	_advance(view, 0.6)
	check(cues.count("danger") == 1 and cues.count("danger_end") == 1,
		"a relieved well cannot repeat the old danger pulse or stop event")


func _check_danger_ends_when_merge_frees_space(view) -> void:
	_reset(view)
	var ids: Array[int] = _install(view, ["merged:caterpillar", "merged:caterpillar"], [], [4, 4])
	# The source must reopen the roof; an internal cavity cannot receive a fall.
	view.game.cells[0].row = 0
	_fill_well(view)
	view._tiles[ids[0]].grab_focus()
	var select := InputEventKey.new()
	select.keycode = KEY_ENTER
	select.pressed = true
	select.shift_pressed = true
	view._input(select)
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
