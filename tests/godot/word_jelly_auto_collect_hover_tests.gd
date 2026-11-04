extends SceneTree

const View = preload("res://scripts/word_jelly.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
const Data = preload("res://scripts/game_data.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")
const BossCatalog = preload("res://scripts/word_jelly_boss_catalog.gd")
const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")

var checks: int = 0
var failures: int = 0
var words: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func put(model, tile: Dictionary) -> Dictionary:
	var index: int = model.cells.size()
	tile.merge({"column": index % Model.COLUMNS, "row": Model.ROWS - 1 - int(index / Model.COLUMNS),
		"age": 100.0, "arrival": false, "settling": false, "falling": false}, true)
	model.cells.append(tile)
	return tile


func merged(model, word: Dictionary, level: int = 1) -> Dictionary:
	var tile: Dictionary = model._new_word_root(word)
	model._set_merged_word(tile, word, level, true)
	return put(model, tile)


func sync(view) -> void:
	view._view_topology_dirty = true
	view._sync_tiles()
	view._layout()
	view._refresh_controls()
	view._refresh_marks()


func move_mouse(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion)
	await process_frame


func hover(view) -> void:
	await move_mouse(Vector2(2, 2))
	await move_mouse(view.collect_button.get_global_rect().get_center())
	view._refresh_marks()


func capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute("res://build/qa/auto-collect-hover")
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://build/qa/auto-collect-hover/" + name + ".png") == OK,
		"Capture the real collection-preview presentation: " + name)


func marks(view, ids: Array, reason: String) -> void:
	for id: int in view._tiles:
		var tile = view._tiles[id]
		check(tile.completion_hint == ids.has(id), reason + ": exact target halo " + str(id))
		check(tile.match_dimmed == (not ids.is_empty() and not ids.has(id)),
			reason + ": unrelated Jelly dimming " + str(id))


func fixture() -> View:
	var view := View.new()
	root.add_child(view)
	view.size = Vector2(1366, 768)
	view.coin_balance = func() -> int: return 1000
	check(view.configure(words, 3, Data.theme("spring"), {}, false, 3781),
		"Configure the actual word art and controls without unrelated chest bootstrap")
	view.set_process(false)
	view.game.cells.clear()
	view.game.fusions.clear()
	view.game.spawn_interval = 10000.0
	view.set_pip_level(Model.AUTO_COLLECT_UNLOCK_LEVEL)
	return view


func test_capture_and_lifecycle() -> void:
	var view = fixture()
	var model = view.game
	var ready: Dictionary = merged(model, words[0], 9)
	var landing: Dictionary = merged(model, words[1])
	landing.arrival = true
	landing.settling = true
	landing.age = 0.0
	put(model, model._new_word_root(words[0]))
	put(model, model._new_picture_tile(words[1]))
	var frozen: Dictionary = merged(model, words[0])
	var locked: Dictionary = merged(model, words[1])
	model.boss.configure(BossCatalog.encounter(7), 3781)
	check(model.boss.apply_status("freeze", int(frozen.id)) and model.boss.apply_status("lock", int(locked.id)),
		"The mixed collection fixture uses real Boss exclusions")
	var left: Dictionary = merged(model, words[0])
	var right: Dictionary = merged(model, words[0])
	check(model.try_merge(int(left.id), int(right.id)) == "merged",
		"An ordinary active fusion owns bodies that collection must exclude")
	sync(view)
	var expected: Array[int] = model.collectable_ids()
	check(expected.size() == 2 and expected.has(int(ready.id)) and expected.has(int(landing.id)),
		"Batch capture includes completed landing bodies and excludes roots, pictures, locks and fusions")
	var before: Dictionary = model.snapshot()
	await capture("desktop-before")
	await hover(view)
	var preview: Dictionary = view.snapshot().auto_collect_hover
	check(preview.active and preview.input_ids == expected and preview.result_count == expected.size(),
		"Real Auto Collect hover advertises exactly the capture set, without guessing blast victims")
	check(model.snapshot() == before and not model.collection_batch_active(),
		"Hover leaves the board, RNG, rewards and collection transactions untouched")
	marks(view, expected, "Hovered mixed board")
	await capture("desktop-hover")
	var added: Dictionary = merged(model, words[1])
	sync(view)
	expected = model.collectable_ids()
	check(view.snapshot().auto_collect_hover.input_ids == expected and expected.has(int(added.id)),
		"A new completed Jelly joins the preview while the cursor remains on Auto Collect")
	marks(view, expected, "Live target update")
	await move_mouse(Vector2(2, 2))
	check(not view.snapshot().auto_collect_hover.active, "Leaving Auto Collect clears its preview immediately")
	marks(view, [], "Pointer exit")
	await capture("desktop-exit")
	view.collect_button.grab_focus()
	check(view.snapshot().auto_collect_hover.active, "Keyboard focus offers the same free collection preview")
	view.collect_button.release_focus()
	check(not view.snapshot().auto_collect_hover.active, "Keyboard focus exit releases the target halo")
	await hover(view)
	view.pause(true)
	view._refresh_marks()
	check(not view.snapshot().auto_collect_hover.active, "Pause suppresses the collection promise")
	marks(view, [], "Paused board")
	view.pause(false)
	await hover(view)
	view.hide()
	check(not view.snapshot().auto_collect_hover.active, "Hiding the game removes the collection preview")
	view.show()
	await hover(view)
	view.cancel_input()
	check(not view.snapshot().auto_collect_hover.active, "Input cancellation releases the active preview")
	marks(view, [], "Canceled preview")
	await hover(view)
	view._pointer = 0
	view._source = int(ready.id)
	view._refresh_controls()
	view._refresh_marks()
	check(not view.snapshot().auto_collect_hover.active, "A held pointer gesture takes precedence over toolbar hover")
	view._pointer = view.NO_POINTER
	view._source = -1
	view._refresh_controls()
	await hover(view)
	for blocker: String in ["held", "combo", "model_pause", "stage_end", "powerup"]:
		match blocker:
			"held": model._held_tile_id = int(ready.id)
			"combo": model._combo_pending = "fixture:pending-combo"
			"model_pause": model.paused = true
			"stage_end": model._stage_ending = true
			"powerup": model._powerup_purchasing = true
		view._refresh_marks()
		check(not view.snapshot().auto_collect_hover.active,
			"A blocked batch clears its preview before toolbar state refresh: " + blocker)
		marks(view, [], "Blocked batch " + blocker)
		model._held_tile_id = -1
		model._combo_pending = ""
		model.paused = false
		model._stage_ending = false
		model._powerup_purchasing = false
		view._refresh_marks()
	view.collect_button.disabled = true
	view.collect_button._refresh_preview()
	check(not view.snapshot().auto_collect_hover.active, "A disabled Auto Collect target cannot advertise an action")
	view._refresh_controls()
	view.set_pip_level(Model.AUTO_COLLECT_UNLOCK_LEVEL - 1)
	await hover(view)
	check(not view.snapshot().auto_collect_hover.active, "The locked Pip level has no collection preview")
	view.set_pip_level(Model.AUTO_COLLECT_UNLOCK_LEVEL)
	await hover(view)
	expected = model.collectable_ids()
	view.collect_button.pressed.emit()
	check(model.collection_batch_active() and model._collection_batch_ids == expected,
		"Accepted Auto Collect captures the exact previously highlighted Jelly IDs")
	check(not view.snapshot().auto_collect_hover.active, "Starting collection consumes the free preview")
	marks(view, [], "Accepted batch")
	view.free()
	await process_frame


func test_tool_precedence() -> void:
	var view = fixture()
	check(view.game.bind_stage(Catalog.make_plan(1, words, 3, 3781)),
		"The toolbar precedence fixture uses actual pending goal identities")
	view.game.merged_level_limit = 9
	put(view.game, view.game._new_word_root(words[0]))
	put(view.game, view.game._new_picture_tile(words[0]))
	merged(view.game, words[1])
	merged(view.game, words[1])
	view.set_stage_progress(view.game.stage_run.snapshot())
	sync(view)
	var automatic = view.powerup_buttons.auto_merge
	await move_mouse(Vector2(2, 2))
	view.collect_button.grab_focus()
	await move_mouse(automatic.get_global_rect().get_center())
	view._refresh_marks()
	var state: Dictionary = view.snapshot()
	check(view.collect_button.has_focus() and state.auto_merge_hover.active and not state.auto_collect_hover.active,
		"Actual Auto Merge hover takes precedence over retained Auto Collect keyboard focus")
	marks(view, state.auto_merge_hover.input_ids, "Auto Merge pointer precedence")
	view.collect_button.release_focus()
	await move_mouse(Vector2(2, 2))
	automatic.grab_focus()
	await hover(view)
	state = view.snapshot()
	check(automatic.has_focus() and state.auto_collect_hover.active and not state.auto_merge_hover.active,
		"Actual Auto Collect hover takes precedence over retained Auto Merge keyboard focus")
	marks(view, view.game.collectable_ids(), "Auto Collect pointer precedence")
	automatic.release_focus()
	await move_mouse(Vector2(2, 2))
	var goal: Button = view._practice_panel.button_for_goal(str(words[0].id))
	check(goal != null and not goal.disabled, "A legal word goal can retain keyboard focus in the precedence case")
	if goal != null and not goal.disabled:
		goal.grab_focus()
		await hover(view)
		check(goal.has_focus() and view.snapshot().auto_collect_hover.active,
			"Auto Collect pointer hover also takes precedence over a focused word goal")
		marks(view, view.game.collectable_ids(), "Goal focus with collection hover")
		goal.release_focus()
	view.free()
	await process_frame


func test_full_board_budget() -> void:
	var view = fixture()
	for index in range(Model.CAPACITY):
		if index % 2 == 0:
			merged(view.game, words[index % words.size()])
		else:
			put(view.game, view.game._new_word_root(words[index % words.size()]))
	sync(view)
	await hover(view)
	var ids: Array[int] = view.game.collectable_ids()
	check(ids.size() == Model.CAPACITY / 2 and view.snapshot().auto_collect_hover.input_ids == ids,
		"A full board highlights every captured word and no uncompleted root")
	marks(view, ids, "Full board")
	var cohort: Array[int] = view._hint_animated_ids.duplicate()
	check(cohort.size() <= view.ANIMATED_MATCH_HINT_LIMIT,
		"A crowded collection preview keeps the established animated target budget")
	var searches: int = int(view.presentation_work_snapshot().hint_searches)
	for frame in range(60):
		view._refresh_completion_hints()
	check(int(view.presentation_work_snapshot().hint_searches) == searches and view._hint_animated_ids == cohort,
		"Unchanged hover frames reuse targets and never rotate the decorative animation cohort")
	view.set_reduced_motion(true)
	view._refresh_marks()
	check(view.snapshot().auto_collect_hover.input_ids == ids, "Reduced motion preserves the complete target set")
	for id: int in ids:
		check(view._tiles[id].completion_hint and is_equal_approx(view._tiles[id].completion_scale, 1.0),
			"Reduced motion retains a still halo without pulsing body scale " + str(id))
	if OS.get_cmdline_user_args().has("--capture"):
		root.size = Vector2i(393, 852)
		view.size = Vector2(393, 852)
		view._layout()
		await process_frame
		await hover(view)
		await capture("phone-hover")
	view.cancel_input()
	view.collect_button.reset()
	check(not view.snapshot().auto_collect_hover.active, "Reset drops the old board preview")
	view.free()
	await process_frame


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	check(source is Array and Data.validate_words(source).is_empty(), "Load the validated production word catalog")
	if failures > 0:
		quit(1)
		return
	words = source.filter(func(word: Dictionary) -> bool: return str(word.id) in ["cat", "dog"]).map(
		func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	check(words.size() == 2, "Use the reviewed cat and dog word identities")
	if failures == 0:
		await test_capture_and_lifecycle()
		await test_tool_precedence()
		await test_full_board_budget()
	print("Auto Collect hover targets: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
