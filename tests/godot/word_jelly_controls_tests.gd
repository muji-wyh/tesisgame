extends SceneTree

const Fixture = preload("res://tests/godot/player_flow_fixture.gd")
const Data = preload("res://scripts/game_data.gd")
const Catalog = preload("res://scripts/word_jelly_stage_catalog.gd")
const Morphology = preload("res://scripts/growth_morphology.gd")
var checks := 0
var failures := 0
var baseline := false
var output := ""


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)


func settle() -> void:
	for frame in range(6):
		await process_frame


func capture(view, name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture") or DisplayServer.get_name() == "headless":
		return
	await settle()
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image.save_png(output + "/" + name + ".png") == OK, "Save the real " + name)
	var area: Rect2 = view._fill_button.get_global_rect().merge(view.collect_button.get_global_rect())
	for button: Control in view.powerup_buttons.values():
		if button.visible:
			area = area.merge(button.get_global_rect())
	area = area.grow(8.0 / _scale(view))
	var ratio: Vector2 = Vector2(image.get_size()) / root.get_visible_rect().size
	var crop := Rect2i((area.position * ratio).floor(), (area.size * ratio).ceil())
	crop = crop.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	check(image.get_region(crop).save_png(output + "/" + name + "-controls.png") == OK,
		"Save the same-sized action rail, not a reconstruction")


func _scale(view: Control) -> float:
	return preload("res://scripts/ui_style.gd").ui_scale(view)


func put(model, tile: Dictionary) -> void:
	var at: Vector2i = model._free_position(model._occupied(), 1, 1)
	tile.merge({"column": at.x, "row": at.y, "age": 100.0,
		"settling": false, "arrival": false}, true)
	model.cells.append(tile)


func geometry(view) -> void:
	var tools := Rect2()
	for button: Control in view.powerup_buttons.values():
		if button.visible:
			tools = button.get_rect() if not tools.has_area() else tools.merge(button.get_rect())
	if view._compact_hud:
		check(is_equal_approx(view.collect_button.size.x, tools.size.x)
			and is_equal_approx(view._fill_button.size.x, tools.size.x),
			"Fill and primary Collect span the complete paid-tool rail")
	check_collect_typography(view.collect_button, _scale(view))
	for button in view.powerup_buttons.values():
		if not button.visible:
			continue
		var state: Dictionary = button.snapshot()
		for name: String in ["title_rect", "price_rect", "icon_rect", "coin_rect"]:
			var values: Array = state.get(name, [])
			check(values.size() == 4, "Paid control exposes " + name)
			if values.size() == 4:
				check(Rect2(Vector2.ZERO, button.size).encloses(Rect2(values[0], values[1], values[2], values[3])),
					"The sourced icon, title and exact price fit the paid card")


func check_collect_typography(button, scale_value: float) -> void:
	var content: Dictionary = button.snapshot().get("content", {})
	check(not content.is_empty(), "Collection typography exposes its actual drawn rectangles")
	if content.is_empty():
		return
	for name: String in ["title", "detail", "count"]:
		var entry: Dictionary = content[name]
		if str(entry.text).is_empty():
			continue
		var values: Array = entry.rect
		var rect := Rect2(values[0], values[1], values[2], values[3])
		var font: Font = preload("res://scripts/ui_style.gd").HEADING_FONT
		var font_size: int = int(entry.font_size)
		check(Rect2(Vector2.ZERO, button.size).encloses(rect)
			and font.get_string_size(str(entry.text), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= rect.size.x + 0.1
			and font.get_height(font_size) <= rect.size.y + 0.1,
			"The full %s text stays inside its allocated area at scale %s" % [name, scale_value])
	var drawn: Dictionary = button._content_layout()
	if not str(drawn.count.text).is_empty():
		check(not Rect2(drawn.title.area).grow(-0.02 / scale_value).intersects(drawn.count.area),
			"Title and count never occupy overlapping rows or columns")
		check(not Rect2(drawn.icon).intersects(drawn.count.area),
			"Animated sourced Jelly artwork has its own area beside the count")


func check_scaled_collect() -> void:
	var button := preload("res://scripts/word_jelly_collect_button.gd").new()
	root.add_child(button)
	button.hide()
	button.set_pip_level(3)
	button.set_reduced_motion(true)
	for scale_value: float in [0.65, 1.0, 1.5, 1175.0 / 480.0, 3.2]:
		button.set_ui_scale(scale_value)
		for width: float in [88.0, 100.0, 136.0, 184.0]:
			for height: float in [44.0, 56.0]:
				button.size = Vector2(width, height) / scale_value
				for count in [0, 8, 40]:
					button.set_state(count, false, 0, 0)
					check_collect_typography(button, scale_value)
	button.queue_free()


func _run() -> void:
	baseline = OS.get_cmdline_user_args().has("--baseline")
	output = "res://build/qa/jelly-controls-" + ("before" if baseline else "after")
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1366, 768)
	var directory := "user://jelly-controls-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	Fixture.install(app, directory)
	app.medal_progress = preload("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	root.add_child(app)
	await settle()
	Fixture.enter_mode(app, "match")
	app.set_process(false)
	app.audio.set_muted(true)
	check(app.coin_wallet.credit_amount("fixture:controls", 5000).ok, "Use only isolated test coins")
	app._coin_flight.sync(app.coin_wallet.balance)
	check(app.new_round(1901, false, "", "word_jelly"), "Open the real Word Jelly application")
	await settle()
	var view = app._word_jelly
	view.set_process(false)
	var words: Array = app._learning_words().filter(func(word: Dictionary) -> bool:
		return not str(word.get("image", "")).is_empty()).slice(0, 8).map(
			func(word: Dictionary) -> Dictionary: return Morphology.decorate(word))
	check(view.configure(words, app.growth.learning_age(), Data.theme(app.model.theme_id),
		app.data.chests, false, 1901), "Use real production words and sourced tile art")
	check(view.game.bind_stage(Catalog.make_plan(2, words, app.growth.learning_age(), 1901)),
		"Main play includes all four paid tools")
	view.game.set_fill_mode(false)
	view.game.cells.clear()
	view.game.spawn_interval = 10000.0
	view.game._powerup_uses.auto_merge = 1
	for index in range(8):
		var word: Dictionary = words[index % words.size()]
		var tile: Dictionary = view.game._new_word_root(word)
		view.game._set_merged_word(tile, word, 1 + index % 3, true)
		put(view.game, tile)
	for index in range(20):
		var word: Dictionary = words[index % words.size()]
		put(view.game, view.game._new_word_root(word) if index % 2 == 0 else view.game._new_picture_tile(word))
	Fixture.unlock_auto_collect(app)
	app._sync_jelly()
	view.set_process(false)
	for dimensions: Vector2i in [Vector2i(1473, 1175), Vector2i(1366, 768),
			Vector2i(393, 852), Vector2i(320, 480), Vector2i(844, 390)]:
		root.size = dimensions
		await settle()
		view.set_process(false)
		view._sync_tiles()
		view._layout()
		view._refresh_controls()
		view.collect_button.set_reduced_motion(true)
		view.collect_button.set_state(8, false, 0, 0)
		await capture(view, "%dx%d-ready8" % [dimensions.x, dimensions.y])
		if not baseline:
			for count in [0, 1, 8, 40]:
				view.collect_button.set_state(count, false, 0, 0)
				geometry(view)
			view.collect_button.set_state(8, true, 2, 8)
			geometry(view)
			view.collect_button.set_pip_level(0)
			geometry(view)
			view.collect_button.set_pip_level(3)
		if dimensions.x == 1366:
			var partner: Dictionary = view.game._new_picture_tile(words[0])
			put(view.game, partner)
			view._sync_tiles()
			view._refresh_controls()
			await capture(view, "ready-tools")
			view._activate_powerup("family_merge")
			check(view._family_selecting and view.powerup_buttons.family_merge.snapshot().targeting,
				"Review the real armed Magnet state without a purchase or a fake disabled selection")
			await capture(view, "magnet-selection")
			view.cancel_input()
			view.game.cells.erase(partner)
			view._sync_tiles()
			view._refresh_controls()
			view.collect_button.set_pip_level(0)
			await capture(view, "collect-locked")
			view.collect_button.set_pip_level(3)
	if not baseline:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_size = Vector2i(480, 480)
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		root.size = Vector2i(1473, 1175)
		await settle()
		view.set_process(false)
		view._layout()
		view._refresh_controls()
		view.collect_button.set_state(8, false, 0, 0)
		geometry(view)
		await capture(view, "1473x1175-scaled-ready8")
		check(view.game.bind_stage(Catalog.make_plan(0, words, app.growth.learning_age(), 1901, true)),
			"Review the actual locked Challenge Fill state")
		view.set_stage_progress(view.game.stage_run.snapshot())
		app._sync_stage_heading()
		view._layout()
		view._refresh_controls()
		await capture(view, "challenge-locked-fill")
		check_scaled_collect()
	app.audio.halt()
	app.queue_free()
	await settle()
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Jelly action controls: %d checks, %d failures%s" % [checks, failures,
		" (baseline capture)" if baseline else ""])
	quit(1 if failures else 0)
