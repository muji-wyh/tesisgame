extends SceneTree

var checks := 0
var failures := 0


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


func pointer(point: Vector2, pressed: bool, touch: bool = false) -> void:
	var event: InputEvent
	if touch:
		event = InputEventScreenTouch.new()
		event.index = 0
	else:
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = point
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame


func motion(point: Vector2, touch: bool) -> void:
	var event: InputEvent = InputEventScreenDrag.new() if touch else InputEventMouseMotion.new()
	event.position = point
	event.relative = Vector2(-12, 0)
	if touch:
		event.index = 0
	else:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)
	await process_frame


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 720)
	var directory := "user://theme-review-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	await _check_loading_theme(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app._presentation.path = directory + "/presentation.cfg"
	preload("res://tests/godot/player_flow_fixture.gd").install(app, directory)
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	var cards: Array = app.model.cards.duplicate(true)
	app._show_collection()
	for theme_index in [4, 1]:
		await settle()
		var button: Button = app.theme_buttons[theme_index]
		button.grab_focus()
		await settle()
		var scroll: int = app._world_scroll.scroll_horizontal
		button.pressed.emit()
		await settle()
		check(app.collection_page.visible and app._age_catalog.is_visible_in_tree(),
			"Choosing a theme keeps the growth catalog open")
		check(app._world_scroll.scroll_horizontal == scroll and button.has_focus(),
			"Theme selection preserves scroll and control focus")
		check(app.model.cards == cards and app.model.hints_remaining == 3,
			"The current game is not reset by a theme choice")
		if not app.collection_page.visible:
			app._show_collection()
	var save_path: String = app._presentation.path
	app._presentation.path = directory + "/missing/presentation.cfg"
	app.theme_buttons[5].pressed.emit()
	await settle()
	var notice: Label = app.get("_world_save_notice")
	check(app._journey_save_failed and notice != null and notice.is_visible_in_tree(),
		"A theme save failure stays visibly recoverable in the open page")
	app._presentation.path = save_path
	app.theme_buttons[5].pressed.emit()
	await settle()
	check(not app._journey_save_failed and app.collection_page.visible
		and (notice == null or not notice.visible),
		"Selecting the same theme retries persistence without leaving the page")
	for dimensions in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(960, 720)]:
		root.size = dimensions
		await settle()
		var scale: float = app.Style.ui_scale(app)
		for button in app.theme_buttons:
			button.grab_focus()
			await settle()
			var surface: StyleBox = button.get_theme_stylebox("normal")
			check(button.size.x * scale >= 44 and button.size.y * scale >= 44,
				"The theme buttons preserve accessible touch targets")
			check((button.size - surface.get_minimum_size()).x * scale >= 24
				and button.get_theme_constant("icon_max_width") * scale >= 30,
				"Inner padding preserves visible theme artwork within its icon cap")
			check(app._world_scroll.get_global_rect().grow(1).encloses(button.get_global_rect()), "Focus reveals theme choices in their horizontal strip")
		check(app._world_scroll.get_global_rect().position.y >= app._age_catalog.get_global_rect().end.y
			and app.collection_page.get_global_rect().grow(1).encloses(app._world_scroll.get_global_rect()),
			"Theme choices stay below the word catalog inside the page at every width")
	app._hide_collection()
	await _check_treasure_themes(app)
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Theme and treasure: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_loading_theme(directory: String) -> void:
	var cases: Array[Array] = [["space"], ["unknown"], [], [42], ["candy"]]
	for index in range(cases.size()):
		var app = load("res://scenes/main.tscn").instantiate()
		var prefix: String = directory + "/loading-%d" % index
		app.medal_progress = load("res://scripts/medal_progress.gd").new(prefix + "-medals.cfg", prefix + "-legacy.cfg")
		preload("res://tests/godot/player_flow_fixture.gd").install(app, directory, "loading-%d-growth.cfg" % index)
		app._presentation.path = prefix + "-presentation.cfg"
		root.add_child(app)
		await settle()
		app._preferred_theme = "autumn"
		app.model.set_theme("autumn")
		app._save_journey()
		var cards: Array = app.model.cards.duplicate(true)
		var mastery: Dictionary = app.growth.snapshot().streaks.duplicate()
		var counts: Dictionary = app.medal_progress.counts.duplicate(true)
		var save_path: String = app._presentation.path
		var save_fails: bool = index == cases.size() - 1
		if save_fails:
			app._presentation.path = directory + "/missing/presentation.cfg"
		paused = true
		app._on_loading_finished(cases[index])
		var expected: String = "space" if index == 0 else ("candy" if save_fails else "autumn")
		check(not paused and app.model.theme_id == expected and app._preferred_theme == expected,
			"Loading entry applies only a valid latest theme before resuming the game")
		check(app.duck.theme_id == expected and app._active_palette.id == expected,
			"Pip and the native scene use the loading theme on the first revealed frame")
		check(app.model.cards == cards and app.model.phase == "waiting" and (app.model.matched_ids.size() / 2) == 0
			and app.model.mistakes == 0 and app.model.hints_remaining == 3
			and app.growth.snapshot().streaks == mastery and app.medal_progress.counts == counts,
			"Loading theme handoff preserves the prepared lesson, mastery and reward progress")
		check(app.audio.active and app.audio.music.playing
			and app.audio.music.stream is AudioStreamWAV
			and app.audio.music.stream.data == load("res://assets/audio/bgm/" + expected + ".wav").data,
			"Loading entry starts the selected world's music without an extra gameplay gesture")
		check(not app.audio.voice.playing,
			"Loading theme handoff does not start narration or another Pip sound")
		if save_fails:
			check(app._journey_save_failed and app._storage_retry_button.visible,
				"A failed loading theme save still enters the chosen world with a visible retry")
			app._presentation.path = save_path
			app._retry_storage()
			check(not app._journey_save_failed, "Loading theme persistence recovers through the normal save retry")
		var reloaded = load("res://scripts/presentation_preferences.gd").new()
		reloaded.path = save_path
		reloaded.load_preferences(false)
		check(reloaded.preferred_theme == expected,
			"The loading theme is remembered independently of retired room data")
		paused = true
		app._on_loading_finished(["winter"])
		check(paused and app.model.theme_id == expected,
			"A duplicate loading callback cannot change the theme or override a later pause")
		paused = false
		app.queue_free()
		await process_frame


func _check_treasure_themes(app) -> void:
	var treasure: Control = app.get("_treasure_backdrop")
	check(treasure != null, "The treasure result has a dedicated world scene")
	if treasure == null:
		return
	var data = load("res://scripts/game_data.gd")
	check(app.new_round(732, false, "", "match"), "The treasure-world fixture starts a real Match round")
	# Use a persisted chest reservation; chance outcomes have separate coverage.
	preload("res://tests/godot/player_flow_fixture.gd").reserve_pair_chest(app)
	check(not treasure.visible and not treasure.is_visible_in_tree(), "Active play hides the treasure scene")
	app.choose_theme("spring")
	for card in app.model.cards:
		if card.kind == "word" and not app.model.card_by_id(card.word.id + ":image").is_empty():
			app.cards[card.id].pressed.emit()
			app.cards[card.word.id + ":image"].pressed.emit()
			app.feedback_timer.timeout.emit()
	preload("res://tests/godot/player_flow_fixture.gd").finish_celebration(app)
	await settle()
	check(app.model.phase == "won" and app.model.chest_state == "closed",
		"Five real matches enter the themed treasure result with an unopened chest")
	check(treasure.mouse_filter == Control.MOUSE_FILTER_IGNORE and treasure.focus_mode == Control.FOCUS_NONE,
		"The world scenery never captures chest pointer input or keyboard focus")
	var counts_before: Dictionary = app.medal_progress.counts.duplicate(true)
	for theme_id in data.THEMES:
		app.choose_theme(theme_id)
		await settle()
		_check_treasure_palette(treasure, data.theme(theme_id), "before opening")
		check(app.model.phase == "won" and app.model.chest_state == "closed" and app.chest.theme_id == "spring",
			"The earned Spring chest is preserved in the selected " + theme_id + " world")
		check(app.medal_progress.counts == counts_before and app.model.reward_theme == "spring",
			"Viewing the " + theme_id + " treasure world cannot claim or replace the frozen reward")
	app.choose_theme("spring")
	await settle()
	var point: Vector2 = app.chest_button.get_global_rect().get_center()
	await pointer(point, true)
	app._advance_ui(0.1)
	await pointer(point, false)
	check(app.model.chest_state == "closed" and app.medal_progress.counts == counts_before,
		"A brief tap through the world scene leaves the chest closed and rewards untouched")
	var original_drag: Vector2 = app.chest.drag_offset
	await pointer(point, true)
	await motion(point - Vector2(12, 0), false)
	check(not app._holding_chest and app.chest.drag_offset != original_drag,
		"Dragging the chest over its world scenery cancels the hold and moves the chest")
	await pointer(point - Vector2(12, 0), false)
	check(app.model.chest_state == "closed" and app.medal_progress.counts == counts_before,
		"Releasing a chest drag cannot open it or award a piece")
	await pointer(point, true)
	app._advance_ui(1.21)
	await pointer(point, false)
	await settle()
	var earned_id: String = app.model.reward_id
	var earned_counts: Dictionary = counts_before.duplicate(true)
	earned_counts["spring-1"] = int(earned_counts.get("spring-1", 0)) + 1
	check(app.model.chest_state == "opened" and app.model.reward_theme == "spring" and earned_id == "spring-1"
		and app.medal_progress.counts == earned_counts,
		"A full hold through the scenery opens the Spring chest and saves exactly its first medal piece")
	var saved_bytes := FileAccess.get_file_as_string(app.medal_progress._save_path)
	var pending: Dictionary = app._pending_fragment.duplicate(true)
	for theme_id in data.THEMES:
		app.choose_theme(theme_id)
		await settle()
		_check_treasure_palette(treasure, data.theme(theme_id), "after opening a Spring chest")
		check(app.model.phase == "won" and app.model.chest_state == "opened" and app.chest.mode == "opened"
			and app.chest.theme_id == "spring" and app.model.reward_theme == "spring" and app.model.reward_id == earned_id,
			"Changing the scene to " + theme_id + " preserves the already earned Spring chest and reward")
		check(app.medal_progress.counts == earned_counts and app._pending_fragment == pending
			and FileAccess.get_file_as_string(app.medal_progress._save_path) == saved_bytes,
			"Changing the opened result to " + theme_id + " cannot rewrite progress or add another piece")
	app._open_chest()
	app._on_chest_opened()
	var reloaded = load("res://scripts/medal_progress.gd").new(app.medal_progress._save_path, app.medal_progress._legacy_path)
	check(reloaded.load_progress() and reloaded.counts == earned_counts and app.medal_progress.counts == earned_counts,
		"Repeated open callbacks after a world change preserve the same single reward through reload")
	check(app.new_round(733, false, "", "match"), "A new adventure still leaves the themed treasure result")
	check(not treasure.visible and not treasure.is_visible_in_tree() and app.medal_progress.counts == earned_counts,
		"The next lesson hides its old treasure scene without claiming the reward again")


func _check_treasure_palette(treasure, palette: Dictionary, context: String) -> void:
	check(treasure.is_visible_in_tree() and treasure.theme_id == palette.id and treasure.palette == palette,
		"The " + palette.name + " treasure scene follows the selected world " + context)
