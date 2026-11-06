extends SceneTree
## Toolbar refreshes never simulate merges without explicit preview intent.

const View = preload("res://scripts/word_jelly.gd")
const Model = preload("res://scripts/word_jelly_model.gd")
const Data = preload("res://scripts/game_data.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")

class ObservedModel extends Model:
	var availability_queries := 0
	var planner_queries := 0
	var forecast_queries := 0
	var automatic_queries := 0
	var family_queries: Array = []
	func can_activate_powerup(kind: String) -> bool:
		availability_queries += 1
		return super.can_activate_powerup(kind)
	func authored_completion_plan(captured_only: bool = false, family: String = "",
		input_limit: int = -1, generated: Dictionary = {}) -> Dictionary:
		planner_queries += 1
		return super.authored_completion_plan(captured_only, family, input_limit, generated)
	func _powerup_forecast() -> WordJellyModel:
		forecast_queries += 1
		return super._powerup_forecast()
	func auto_merge_preview() -> Dictionary:
		automatic_queries += 1
		return super.auto_merge_preview()
	func family_merge_quotes(families: Array[String]) -> Dictionary:
		family_queries.append(families.duplicate())
		return super.family_merge_quotes(families)
	func reset_queries() -> void:
		availability_queries = 0
		planner_queries = 0
		forecast_queries = 0
		automatic_queries = 0
		family_queries.clear()

class ObservedView extends View:
	func _init() -> void:
		super()
		var original = game
		game = ObservedModel.new()
		game.finish_feedback_ready = _finish_feedback_ready
		# Keep production callbacks active while counting exact preview demand.
		for descriptor: Dictionary in original.get_signal_list():
			for connection: Dictionary in original.get_signal_connection_list(descriptor.name):
				game.connect(descriptor.name, connection.callable, int(connection.flags))
		_palette.compatibility = game.parts_compatible

var checks := 0
var failures := 0
var words: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func put(model, word: Dictionary) -> Dictionary:
	var tile: Dictionary = model._new_word_root(word)
	model._set_merged_word(tile, word, 1, true)
	var index: int = model.cells.size()
	tile.merge({"column": index % Model.COLUMNS, "row": Model.ROWS - 1 - int(index / Model.COLUMNS),
		"age": 100.0, "arrival": false, "falling": false, "settling": false}, true)
	model.cells.append(tile)
	return tile

func sync(view) -> void:
	view._view_topology_dirty = true
	view._sync_tiles()
	view._layout()
	view._controls_key.clear()
	view._refresh_controls()
	view._refresh_marks()

func fixture() -> View:
	var view := ObservedView.new()
	root.add_child(view)
	view.size = Vector2(1366, 768)
	view.set_process(false)
	view.coin_balance = func() -> int: return 1000
	check(view.configure(words, 3, Data.theme("spring"), {}, false, 31821), "Use real word art and tool controls")
	view.game.cells.clear()
	view.game.fusions.clear()
	view.game.spawn_interval = 10000.0
	view.game.merged_level_limit = 9
	view.game.auto_merge_level = 3
	for index in range(6):
		put(view.game, words[0 if index < 4 else 1])
	var practice: Array = []
	for word: Dictionary in words:
		practice.append({"id": word.id, "word_id": word.id, "text": word.text, "image": word.image,
			"current": 0, "required": 3, "mastered": false})
	view._practice_panel.set_stage({"kind": "main", "number": 1, "practice": practice})
	sync(view)
	view.game.reset_queries()
	return view

func move_mouse(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event)
	await process_frame

func keyboard_input() -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = KEY_SHIFT
	pressed.pressed = true
	root.push_input(pressed)
	var released := InputEventKey.new()
	released.keycode = KEY_SHIFT
	root.push_input(released)
	await process_frame

func test_unrequested_work() -> void:
	var view = fixture()
	var model = view.game
	# Incoming ages would otherwise trigger complete family timeline forecasts.
	var arrival: Dictionary = put(model, words[0])
	arrival.arrival = true
	arrival.age = 0.0
	arrival.settling = true
	sync(view)
	model.reset_queries()
	for frame in range(40):
		arrival.age += 0.001
		view._controls_key.clear()
		view._refresh_controls()
		view._refresh_goal_buttons()
		view._refresh_marks()
		view.snapshot()
	check(model.availability_queries == 0 and model.planner_queries == 0 and model.forecast_queries == 0 \
		and model.automatic_queries == 0 and model.family_queries.is_empty(),
		"Unhovered changing arrivals, controls and diagnostic snapshots run no merge planner or forecast")
	check(view.powerup_buttons.auto_merge.snapshot().price == model.powerup_price("auto_merge") \
		and view._practice_panel._rows.all(func(row: Dictionary) -> bool:
			return row.surface.snapshot().price == model.powerup_price("family_merge")),
		"All untouched tools still display their current successful-use prices")
	var family: String = str(words[0].id)
	var goal: Button = view._practice_panel.button_for_goal(family)
	var automatic: Button = view.powerup_buttons.auto_merge
	for kind: String in ["family", "auto_merge"]:
		var button: Button = goal if kind == "family" else automatic
		await move_mouse(button.get_global_rect().get_center())
		model.reset_queries()
		for frame in range(40):
			arrival.age = Model.settle_duration(arrival) * (0.1 + 0.7 * float(frame) / 40.0)
			view._controls_key.clear()
			view._refresh_controls()
			view._refresh_marks()
			check(view._goal_merge_hover_quotes().is_empty() and view._auto_merge_hover_preview().input_ids.is_empty(),
				kind + ": exact quantities remain unknown while an incoming body moves")
			view.snapshot()
		check(model.availability_queries == 0 and model.planner_queries == 0 and model.forecast_queries == 0 \
			and model.automatic_queries == 0 and model.family_queries.is_empty(),
			kind + ": explicit hover coalesces all changing arrival ages without a planner or forecast")
		check(not goal.disabled and not automatic.disabled and automatic.snapshot().price == model.powerup_price("auto_merge") \
			and goal.snapshot().price == model.powerup_price("family_merge"),
			kind + ": incoming supply preserves static prices and actionable merge tools")
		if kind == "family":
			for id: int in view._tiles:
				check(view._tiles[id].completion_hint == (model.family_word_id(id) == family),
					"Moving family preview retains its cheap identity highlight " + str(id))
	arrival.age = Model.settle_duration(arrival) + 0.001
	sync(view)
	var preview: Dictionary = view._auto_merge_hover_preview()
	check(int(preview.result_count) > 0 and not preview.input_ids.is_empty(),
		"The settlement boundary restores the exact Auto Merge input preview")
	for id: int in view._tiles:
		check(view._tiles[id].completion_hint == preview.input_ids.has(id),
			"Settled Auto Merge highlights exactly its planned input " + str(id))
	await move_mouse(goal.get_global_rect().get_center())
	check(int(view._goal_merge_hover_quotes()[family].reduction_count) == 4,
		"The settled family's exact reduction includes the newly landed body")
	var planners: int = model.planner_queries
	var forecasts: int = model.forecast_queries
	for frame in range(12):
		arrival.age += 0.001
		view._refresh_goal_buttons()
		view.snapshot()
	check(model.planner_queries == planners and model.forecast_queries == forecasts,
		"Settled idle ages reuse the existing exact preview cache")
	await move_mouse(Vector2(2, 2))
	model.reset_queries()
	arrival.age += 0.001
	view._refresh_controls()
	view.snapshot()
	check(model.planner_queries == 0 and model.forecast_queries == 0 and model.family_queries.is_empty(),
		"Leaving the settled preview stops all unrequested exact quantity queries")
	view.free()
	await process_frame

func test_preview_demand_and_invalidation() -> void:
	var view = fixture()
	var model = view.game
	var family: String = str(words[0].id)
	var goal: Button = view._practice_panel.button_for_goal(family)
	await move_mouse(goal.get_global_rect().get_center())
	var quote: Dictionary = view._goal_merge_hover_quotes().get(family, {})
	check(not quote.is_empty() and int(quote.reduction_count) == 3 and model.family_queries.all(
		func(query: Array) -> bool: return query == [family]),
		"Family demand computes the exact reduction for only the indicated family")
	var removed: Dictionary = model.cells.pop_front()
	sync(view)
	check(int(view._goal_merge_hover_quotes()[family].reduction_count) == 2,
		"A changed board invalidates the previously hovered family's exact count")
	model.cells.push_front(removed)
	sync(view)
	var other_family: String = str(words[1].id)
	await move_mouse(view._practice_panel.button_for_goal(other_family).get_global_rect().get_center())
	check(int(view._goal_merge_hover_quotes()[other_family].reduction_count) == 1,
		"Moving to another family selects its own exact count")
	goal = view._practice_panel.button_for_goal(other_family)
	goal.grab_focus()
	await move_mouse(Vector2(2, 2))
	check(view._goal_hover_word.is_empty() and view._goal_merge_hover_quotes().is_empty(),
		"Pointer exit clears family demand even when the previous item retains focus")
	await keyboard_input()
	check(view._goal_hover_word == other_family and not view._goal_merge_hover_quotes().is_empty(),
		"Deliberate keyboard focus retains an accessible single-family preview")
	view._practice_panel._scroll.held_button_changed.emit(goal)
	check(view._goal_hover_word.is_empty() and view._goal_merge_hover_quotes().is_empty(),
		"A rail pointer press clears keyboard demand even when the rail consumes the input")
	await move_mouse(Vector2(2, 2))
	var automatic: Button = view.powerup_buttons.auto_merge
	await move_mouse(automatic.get_global_rect().get_center())
	var preview: Dictionary = view._auto_merge_hover_preview()
	check(int(preview.result_count) > 0 and not preview.input_ids.is_empty(),
		"Auto Merge demand retains exact results and captured board inputs")
	for id: int in view._tiles:
		check(view._tiles[id].completion_hint == preview.input_ids.has(id), "Auto Merge highlights exactly its planned input " + str(id))
	automatic.grab_focus()
	await move_mouse(Vector2(2, 2))
	check(not view._auto_merge_hovered and view._auto_merge_hover_preview().input_ids.is_empty(),
		"Pointer exit clears Auto Merge even if the old button remains focused")
	await keyboard_input()
	check(not view._auto_merge_hover_preview().input_ids.is_empty(), "Keyboard focus can deliberately request Auto Merge")
	for kind: String in ["family", "auto_merge"]:
		var button: Button = view._practice_panel.button_for_goal(family) if kind == "family" else automatic
		await move_mouse(button.get_global_rect().get_center())
		for blocker: String in ["held", "collection", "finish", "stage-end"]:
			match blocker:
				"held": model._held_tile_id = int(model.cells[0].id)
				"collection": model._collection_batch_active = true
				"finish": view.finish_button._pulling = true
				"stage-end": model._stage_ending = true
			model.reset_queries()
			view._refresh_marks()
			check(view._auto_merge_hover_preview().input_ids.is_empty() and view._goal_merge_hover_quotes().is_empty() \
				and model.automatic_queries == 0 and model.family_queries.is_empty() \
				and model.planner_queries == 0 and model.forecast_queries == 0,
				kind + ": " + blocker + " clears exact preview without asking the planner")
			model._held_tile_id = -1
			model._collection_batch_active = false
			model._stage_ending = false
			view.finish_button._pulling = false
			view._refresh_marks()
	view.pause(true)
	var queries: int = model.automatic_queries + model.family_queries.size()
	check(view._auto_merge_hover_preview().input_ids.is_empty() and view._goal_merge_hover_quotes().is_empty() \
		and queries == model.automatic_queries + model.family_queries.size(), "Paused previews clear without another forecast")
	view.free()
	await process_frame

func test_click_revalidation() -> void:
	for kind: String in ["auto_merge", "family_merge"]:
		var view = fixture()
		var model = view.game
		var payments: Array = []
		model.purchase_powerup = func(id: String, purchased: String, price: int) -> Dictionary:
			check(model.powerup_quote_is_current(id, purchased, price), "Activation validates the exact current use price")
			payments.append([purchased, price])
			return {"ok": true}
		if kind == "auto_merge":
			view._activate_powerup(kind)
		else:
			view._activate_goal_merge(str(words[0].id), str(words[0].id))
		check(payments.size() == 1 and model.powerup_active(), "An untouched legal " + kind + " remains actionable without preview")
		model.finish_powerup()
		model.cells.clear()
		put(model, words[0])
		sync(view)
		if kind == "auto_merge":
			view._activate_powerup(kind)
		else:
			view._activate_goal_merge(str(words[0].id), str(words[0].id))
		check(payments.size() == 1 and not model.powerup_active(), "No legal merge means no charge despite unknown toolbar availability")
		model.purchase_powerup = Callable()
		view.free()
		await process_frame

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	var source: Array = JSON.parse_string(FileAccess.get_file_as_string("res://words.json"))
	words = source.filter(func(word: Dictionary) -> bool: return str(word.id) in ["cat", "dog"]).map(
		func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	words.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	check(words.size() == 2, "Load reviewed production cat and dog words")
	if failures == 0:
		await move_mouse(Vector2(2, 2))
		await test_unrequested_work()
		await test_preview_demand_and_invalidation()
		await test_click_revalidation()
	print("Word Jelly preview demand: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
