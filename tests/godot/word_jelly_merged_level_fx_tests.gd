extends SceneTree
## Per-level artwork preserves learning faces and the crowded-board motion budget.

const View = preload("res://scripts/word_jelly.gd")
const Tile = preload("res://scripts/word_jelly_tile.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
const Data = preload("res://scripts/game_data.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")
const Budget = preload("res://scripts/word_jelly_ambient_budget.gd")
const WordArt = preload("res://scripts/word_art.gd")
const Style = preload("res://scripts/ui_style.gd")
const BossCatalog = preload("res://scripts/word_jelly_boss_catalog.gd")
const SKIN = preload("res://assets/images/jelly-match/gel-mint.png")
const PICTURE = preload("res://assets/images/ui/modes/cat.webp")
const SKY = preload("res://assets/images/jelly-match/sky/day.png")
const OUTPUT := "res://build/qa/jelly-level-fx"
const EFFECT_IDS: Array[String] = ["pearl", "ripple", "spiral", "firework", "cascade",
	"bouquet", "aurora", "constellation", "grand_bouquet"]
const ATLAS := "res://assets/images/jelly-level-fx/atlas.png"

var checks := 0
var failures := 0
var words: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func effect(tile) -> Dictionary:
	return tile.presentation_snapshot().get("merged_effect", {})


func merged_cell(model, word: Dictionary, level: int) -> Dictionary:
	var cell: Dictionary = model._new_word_root(word)
	model._set_merged_word(cell, word, level, true)
	return cell


func put(model, cell: Dictionary) -> Dictionary:
	var index: int = model.cells.size()
	cell.merge({"column": index % Model.COLUMNS, "row": Model.ROWS - 1 - int(index / Model.COLUMNS),
		"age": 100.0, "arrival": false, "settling": false, "falling": false}, true)
	model.cells.append(cell)
	return cell


func fixture() -> View:
	var view := View.new()
	root.add_child(view)
	view.size = Vector2(1366, 768)
	view.coin_balance = func() -> int: return 1000
	check(view.configure(words, 3, Data.theme("spring"), {}, false, 47291),
		"Use the real word art and game area without unrelated chest bootstrap")
	view.set_process(false)
	view.game.cells.clear()
	view.game.fusions.clear()
	view.game.spawn_interval = 10000.0
	view.game.merged_level_limit = Model.MAX_MERGE_LEVEL
	view.set_pip_level(Model.AUTO_COLLECT_UNLOCK_LEVEL)
	return view


func sync(view) -> void:
	view._view_topology_dirty = true
	view._sync_tiles()
	view._layout()
	view._refresh_controls()
	view._refresh_marks()


func frames(view, count: int) -> void:
	for frame in range(count):
		WordArt.advance(1.0 / 60.0, view._can_play())
		view._process(1.0 / 60.0)


func geometry(tile) -> Array:
	return [tile.get_rect(), tile.contact_bounds(), tile.contact_outline(), tile._surface.get_rect(),
		tile._label.get_rect(), tile._picture.get_rect(), tile._label.text,
		tile._level_badge.get_rect(), tile.fragment_badge_snapshot().rect]


func child_count(node: Node) -> int:
	var count: int = node.get_child_count()
	for child: Node in node.get_children():
		count += child_count(child)
	return count


func board_frames(view) -> Dictionary:
	var result := {}
	for id: int in view._tiles:
		result[id] = effect(view._tiles[id]).get("frame", -1.0)
	return result


func move_mouse(at: Vector2, mask: int = 0) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	motion.button_mask = mask
	root.push_input(motion)
	await process_frame


func mouse_button(at: Vector2, pressed: bool) -> void:
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	button.position = at
	button.global_position = at
	root.push_input(button)
	await process_frame


func capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	check(DirAccess.make_dir_recursive_absolute(OUTPUT) == OK, "Keep rendered QA in the ignored output directory")
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png") == OK,
		"Capture the actual merged Jelly presentation: " + name)


func test_tiers_and_gallery() -> void:
	var holder := Control.new()
	root.add_child(holder)
	holder.size = Vector2(root.size)
	var sky := TextureRect.new()
	sky.texture = SKY
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky.size = holder.size
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(sky)
	var title := Style.label("Merged Jelly effects", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 18)
	title.size = Vector2(holder.size.x, 42)
	holder.add_child(title)
	var model := Model.new()
	var tiles: Array = []
	var identities: Array[String] = []
	var cells: Array[Dictionary] = []
	var atlas: Texture2D
	for level in range(1, 10):
		var tile := Tile.new()
		holder.add_child(tile)
		tile.size = Vector2(130, 130)
		tile.position = Vector2(holder.size.x * 0.5 - 65.0 + ((level - 1) % 3 - 1) * 280.0,
			100.0 + int((level - 1) / 3) * 215.0)
		var cell: Dictionary = merged_cell(model, words[0], level)
		cell["merged_level_limit"] = 9
		var original: Dictionary = cell.duplicate(true)
		tile.configure(cell, SKIN, PICTURE, null, Color("#357d70"))
		tile.set_ambient_animation(false)
		tile.set_merged_presentation(0.0, false)
		var state: Dictionary = effect(tile)
		var valid: bool = state.has_all(["visible", "id", "level", "animated", "frame", "atlas"])
		check(valid, "A real merged body exposes the per-level effect contract")
		if not valid:
			holder.free()
			return
		check(state.visible and state.id == EFFECT_IDS[level - 1] and state.level == level,
			"Level %d has its own visible effect identity" % level)
		check(state.atlas == ATLAS and tile._merged_effect.texture.resource_path == ATLAS,
			"Each tier uses the shared acquired-art atlas")
		if atlas == null:
			atlas = tile._merged_effect.texture
		else:
			check(tile._merged_effect.texture == atlas,
				"Tier identities do not duplicate the underlying atlas resource")
		check(not state.animated and cell == original and tile._label.visible and tile._picture.visible,
			"A noncohort effect retains its learning content and immutable supplied cell")
		check(tile._merged_effect.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"Special effects remain transparent to game input")
		identities.append(str(state.id))
		cells.append(cell)
		tiles.append(tile)
		var caption := Style.label("Lv%d" % level, 21)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.position = tile.position + Vector2(-45, 144)
		caption.size = Vector2(220, 34)
		holder.add_child(caption)
	check(identities == EFFECT_IDS, "All nine merged tiers retain distinct effects in ascending order")
	await capture("desktop-tier-gallery")
	for index in range(tiles.size()):
		var tile = tiles[index]
		var saved: Array = geometry(tile)
		var descendants: int = child_count(tile)
		var frozen: float = float(effect(tile).frame)
		tile.set_merged_presentation(90.0, false)
		check(float(effect(tile).frame) == frozen,
			"A static tier keeps its exact effect frame despite elapsed wall time")
		tile.set_ambient_animation(true)
		tile.set_merged_presentation(90.01, false)
		var start: float = float(effect(tile).frame)
		for frame in range(30):
			tile.set_merged_presentation(90.02 + float(frame) / 60.0, false)
		check(effect(tile).animated and not is_equal_approx(float(effect(tile).frame), start),
			"An active tier advances its own special effect")
		check(geometry(tile) == saved and child_count(tile) == descendants,
			"Animated tier artwork never moves learning faces, hit contours or allocates more nodes")
		tile.set_ambient_animation(false)
		frozen = float(effect(tile).frame)
		tile.set_merged_presentation(300.0, false)
		check(not effect(tile).animated and float(effect(tile).frame) == frozen,
			"Releasing a tier's animation budget freezes its last coherent pose")
		tile.set_merged_presentation(300.1, true)
		tile.set_merged_presentation(900.0, true)
		check(not effect(tile).animated and is_zero_approx(float(effect(tile).frame)) and geometry(tile) == saved,
			"Reduced motion retains the tier's static identity without changing its learning face")
		tile.set_merged_presentation(900.0, false)
		tile.set_projection(true)
		check(not effect(tile).visible and not effect(tile).animated,
			"A placement projection cannot masquerade as a completed special-effect Jelly")
		tile.set_projection(false)
		check(effect(tile).visible and effect(tile).id == EFFECT_IDS[index],
			"Leaving projection restores the same acquired tier identity")
	var tile = tiles[0]
	var saved: Array = geometry(tile)
	var descendants: int = child_count(tile)
	var upgraded: Dictionary = cells[0].duplicate(true)
	upgraded.merge({"merge_level": 9}, true)
	tile.configure(upgraded, SKIN, PICTURE, null, Color("#357d70"))
	check(effect(tile).id == EFFECT_IDS[8] and effect(tile).level == 9
		and tile._label.text == saved[6] and tile.get_rect() == saved[0]
		and child_count(tile) == descendants,
		"Reusing a body at a higher level changes the effect without duplicating nodes or changing the word and hit target")
	for kind: String in ["root", "picture"]:
		var cell: Dictionary = model._new_word_root(words[0]) if kind == "root" else model._new_picture_tile(words[0])
		tile.configure(cell, SKIN, PICTURE, null, Color("#357d70"))
		check(not effect(tile).visible and not effect(tile).animated and effect(tile).id.is_empty(),
			"A %s clue has no merged-tier effect" % kind)
	tile.configure(cells[0], SKIN, PICTURE, null, Color("#357d70"))
	await capture_gallery_motion(tiles)
	holder.free()
	await process_frame


func capture_gallery_motion(tiles: Array) -> void:
	if not OS.get_cmdline_user_args().has("--capture-motion") or DisplayServer.get_name() == "headless":
		return
	var directory: String = OUTPUT + "/gallery-motion"
	check(DirAccess.make_dir_recursive_absolute(directory) == OK, "Keep isolated interaction motion previews in QA output")
	for tile in tiles:
		tile.set_ambient_animation(true)
		tile.set_merged_presentation(1000.0, false)
	for frame in range(65):
		for tile in tiles:
			tile.set_merged_presentation(1000.0 + float(frame) / 20.0, false)
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(directory + "/frame-%04d.png" % frame) == OK,
			"Capture isolated active tier effects at 20 fps")
	print("Merged effect gallery: %s (65 frames at 20 fps; complete 3.2-second loop plus wrap sample)" % directory)


func test_full_board_budget() -> void:
	var view := fixture()
	for index in range(Model.CAPACITY):
		put(view.game, merged_cell(view.game, words[index % words.size()], 1 + index % 9))
	sync(view)
	await move_mouse(Vector2(2, 2))
	view._set_ambient_hover(-1)
	frames(view, 60)
	var owners: Array[int] = view._ambient_budget.animated_ids()
	check(view.game.cells.size() == Model.CAPACITY and owners.size() == Budget.IDLE_SLOTS,
		"A full 56-merged-body board retains only three idle animation owners")
	var before: Dictionary = board_frames(view)
	var poses: int = int(view.presentation_work_snapshot().tiles_posed)
	var descendants: int = child_count(view._tiles[view.game.cells[0].id])
	frames(view, 30)
	var after: Dictionary = board_frames(view)
	check(int(view.presentation_work_snapshot().tiles_posed) - poses <= Budget.IDLE_SLOTS * 30 + 6,
		"Steady special effects do not resume full-board geometry writes")
	for id: int in view._tiles:
		var tile = view._tiles[id]
		check(effect(tile).visible and effect(tile).id == EFFECT_IDS[tile.merge_level - 1],
			"Every crowded-board body retains its own visible tier effect")
		check(child_count(tile) == descendants, "Repeated effect samples retain a bounded per-body node count")
		check(effect(tile).animated == owners.has(id), "Only the real ambient cohort owns a moving tier effect")
		if not owners.has(id):
			check(after[id] == before[id], "A settled noncohort body keeps its exact effect frame")
	await capture("desktop-full-board")
	var hovered: int = int(view.game.cells[Model.CAPACITY - 1].id)
	await move_mouse(view._tiles[hovered].get_global_rect().get_center())
	check(view._ambient_budget.animated_ids().has(hovered) and effect(view._tiles[hovered]).animated,
		"Actual pointer hover enables the chosen Jelly immediately")
	var hover_frame: float = float(effect(view._tiles[hovered]).frame)
	frames(view, 12)
	check(not is_equal_approx(float(effect(view._tiles[hovered]).frame), hover_frame),
		"The hovered tier advances while its untouched neighbors remain budgeted")
	await move_mouse(Vector2(2, 2))
	frames(view, 1)
	check(view._ambient_budget.animated_ids().size() == Budget.IDLE_SLOTS,
		"Pointer exit restores the crowded-board idle budget")
	view.pause(true)
	before = board_frames(view)
	frames(view, 30)
	check(board_frames(view) == before, "Pausing holds every tier at its current effect pose")
	view.pause(false)
	view.hide()
	before = board_frames(view)
	frames(view, 30)
	check(board_frames(view) == before
		and view._tiles.values().all(func(body) -> bool: return not effect(body).visible),
		"A hidden game area has no visible or advancing tier effects")
	view.show()
	view.set_reduced_motion(true)
	view._sync_tiles()
	view._layout()
	frames(view, 3)
	check(view._ambient_budget.animated_ids().is_empty(), "Reduced motion releases all ambient effect owners")
	for body in view._tiles.values():
		check(effect(body).visible and not effect(body).animated and is_zero_approx(float(effect(body).frame)),
			"Reduced motion preserves each tier as steady acquired artwork")
	root.size = Vector2i(393, 852)
	view.size = Vector2(393, 852)
	view._layout()
	await process_frame
	await capture("phone-reduced-motion")
	view.set_reduced_motion(false)
	frames(view, 12)
	check(view._ambient_budget.animated_ids().size() == Budget.IDLE_SLOTS,
		"Responsive phone layout restores the same bounded ambient effect budget")
	await capture("phone-full-board")
	view.free()
	root.size = Vector2i(1366, 768)
	await process_frame


func test_full_board_drag() -> void:
	var view := fixture()
	for index in range(Model.CAPACITY):
		put(view.game, merged_cell(view.game, words[index % words.size()], 1 + index % 9))
	sync(view)
	await move_mouse(Vector2(2, 2))
	frames(view, 60)
	# Lift a top-row body so unrelated supporting stacks do not begin falling.
	var source: int = int(view.game.cells[Model.CAPACITY - 2].id)
	var target: int = int(view.game.cells[Model.CAPACITY - 4].id)
	var capped: int = int(view.game.cells[8].id)
	var identities := {}
	var allocations := {}
	var original_ids: Array[int] = []
	for cell: Dictionary in view.game.cells:
		var id: int = int(cell.id)
		original_ids.append(id)
		identities[id] = view._tiles[id].get_instance_id()
		allocations[id] = child_count(view._tiles[id])
	var expected: Array[int] = []
	for cell: Dictionary in view.game.cells:
		if view.game.can_merge(view.game.cell(source), cell):
			expected.append(int(cell.id))
	check(expected.has(target) and not expected.has(capped) and expected.size() > View.ANIMATED_MATCH_HINT_LIMIT,
		"The full-board drag fixture includes a valid same-word Lv8 partner and an excluded Lv9 partner")
	var start: Vector2 = view._tiles[source].get_global_rect().get_center()
	await mouse_button(start, true)
	check(view._pointer == View.MOUSE_POINTER and view._source == source
		and view.game._held_tile_id == source,
		"A real mouse press owns the selected merged body on a full board")
	if view._source != source:
		await mouse_button(Vector2(2, 2), false)
		view.free()
		await process_frame
		return
	await move_mouse(start + Vector2(-12, -16), MOUSE_BUTTON_MASK_LEFT)
	frames(view, 1)
	var destination: Vector2 = view._tiles[target].get_global_rect().get_center()
	await move_mouse(destination, MOUSE_BUTTON_MASK_LEFT)
	frames(view, 2)
	check(view._dragging and view.game.is_lifted(source) and view._target == target,
		"Real held mouse motion lifts the source and contacts its exact same-word merged partner")
	check(view._hint_matching_ids == expected and view._tiles[target].completion_hint
		and not view._tiles[capped].completion_hint,
		"Dragging preserves every authoritative matching identity while capped merged tiers remain excluded")
	var cohort: Array[int] = view._hint_animated_ids.duplicate()
	check(cohort.size() == View.ANIMATED_MATCH_HINT_LIMIT,
		"Many same-word partners retain only three decorative matching animation owners")
	var max_owners: int = Budget.IDLE_SLOTS + View.ANIMATED_MATCH_HINT_LIMIT + 3
	check(view._ambient_budget.animated_ids().has(source) and effect(view._tiles[source]).animated
		and view._ambient_budget.animated_ids().size() <= max_owners,
		"The held tier gets immediate effect motion within the idle, hint and interaction budget")
	var source_phase: float = float(effect(view._tiles[source]).frame)
	var poses: int = int(view.presentation_work_snapshot().tiles_posed)
	var before: Dictionary = board_frames(view)
	for frame in range(18):
		await move_mouse(destination + Vector2(sin(float(frame) * 0.5) * 3.0,
			cos(float(frame) * 0.5) * 3.0), MOUSE_BUTTON_MASK_LEFT)
		frames(view, 1)
		check(view._source == source and view._dragging and view._target == target
			and view._hint_matching_ids == expected and view._hint_animated_ids == cohort,
			"Continuous real pointer dragging preserves the held identity, contact and fixed matching cohort")
		check(view._ambient_budget.animated_ids().size() <= max_owners
			and view._active_tile_ids.size() <= View.ANIMATED_MATCH_HINT_LIMIT + 3,
			"Continuous pointer motion does not promote the full board into active animation")
	check(not is_equal_approx(float(effect(view._tiles[source]).frame), source_phase),
		"The dragged merged Jelly's special effect advances during the real input stream")
	check(int(view.presentation_work_snapshot().tiles_posed) - poses <= max_owners * 18 + 8,
		"Steady real pointer dragging updates only the bounded active effect cohort")
	var owners: Array[int] = view._ambient_budget.animated_ids()
	for id: int in original_ids:
		check(view._tiles.has(id) and view._tiles[id].get_instance_id() == identities[id]
			and child_count(view._tiles[id]) == allocations[id],
			"Dragging retains each original merged body and its fixed node allocation")
		if id not in owners:
			check(float(effect(view._tiles[id]).frame) == before[id],
				"Untouched merged tiers keep their exact held phase during continuous dragging")
	check(view.game.cells.size() == Model.CAPACITY and view.game.fusions.is_empty(),
		"The full board stays intact until a merge is actually released")
	# Release away from the game area to exercise the actual return animation.
	await move_mouse(Vector2(2, 2), MOUSE_BUTTON_MASK_LEFT)
	frames(view, 1)
	await mouse_button(Vector2(2, 2), false)
	await move_mouse(Vector2(2, 2))
	frames(view, 36)
	check(view._pointer == View.NO_POINTER and view._source == -1 and not view._dragging
		and view.game._held_tile_id == -1 and not view.game.is_lifted(source)
		and not view._snapbacks.has(source),
		"Real pointer release completes normal snapback and clears held gesture ownership")
	check(view._hint_matching_ids.is_empty() and view._ambient_budget.animated_ids().size() == Budget.IDLE_SLOTS,
		"Returning the body and leaving the board restores the three-owner idle effect cohort")
	var returned_ids: Array[int] = []
	for cell: Dictionary in view.game.cells:
		returned_ids.append(int(cell.id))
	check(returned_ids == original_ids and view._tiles.size() == Model.CAPACITY
		and view.game.fusions.is_empty(),
		"Snapback retains all 56 original model and presentation identities")
	for id: int in original_ids:
		check(view._tiles[id].get_instance_id() == identities[id]
			and child_count(view._tiles[id]) == allocations[id]
			and effect(view._tiles[id]).id == EFFECT_IDS[view._tiles[id].merge_level - 1],
			"Released bodies retain their distinct tier artwork without node replacement")
	view.free()
	await process_frame


func test_collect_dimming() -> void:
	var view := fixture()
	var ready: Array[int] = []
	for level in [1, 4, 9]:
		ready.append(int(put(view.game, merged_cell(view.game, words[0], level)).id))
	var locked: Dictionary = put(view.game, merged_cell(view.game, words[1], 8))
	view.game.boss.configure(BossCatalog.encounter(7), 47291)
	check(view.game.boss.apply_status("lock", int(locked.id)), "Use a real locked merged body for collection exclusion")
	put(view.game, view.game._new_word_root(words[0]))
	put(view.game, view.game._new_picture_tile(words[1]))
	sync(view)
	await move_mouse(Vector2(2, 2))
	var original: Dictionary = view.game.snapshot()
	await move_mouse(view.collect_button.get_global_rect().get_center())
	view._refresh_marks()
	var targets: Array[int] = view.game.collectable_ids()
	check(targets == ready and view.snapshot().auto_collect_hover.input_ids == targets,
		"Auto Collect retains its exact available-word capture set across different tier effects")
	for id: int in view._tiles:
		var tile = view._tiles[id]
		check(tile.completion_hint == targets.has(id), "Tier effects do not change collection target ownership")
		if tile.valid_word:
			check(tile._merged_effect.self_modulate.a == (1.0 if targets.has(id) else 0.25),
				"Unrelated merged-tier artwork recedes behind the actual collection promise")
	check(view.game.snapshot() == original, "Collection hover changes no board, wallet, RNG or learning receipt")
	await capture("desktop-collect-hover")
	await move_mouse(Vector2(2, 2))
	for body in view._tiles.values():
		if body.valid_word:
			check(not body.match_dimmed and body._merged_effect.self_modulate.a == 1.0,
				"Leaving collection hover restores every tier's ordinary special effect")
	view.free()
	await process_frame


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	WordArt.set_reduced_motion(false)
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	check(source is Array and Data.validate_words(source).is_empty(), "Load the validated production word catalog")
	if failures == 0:
		for word: Dictionary in source:
			if str(word.id) in ["cat", "dog"]:
				words.append(Morphology.decorate(word))
	check(words.size() == 2, "Use reviewed cat and dog identities and their existing artwork")
	if failures == 0:
		await test_tiers_and_gallery()
		if failures == 0:
			await test_full_board_budget()
			await test_full_board_drag()
			await test_collect_dimming()
	print("Merged Jelly level effects: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
