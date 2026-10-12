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
	app.choose_mode("match")
	app._request_hint()
	app.cards[app.model.hint_ids[0]].pressed.emit()
	var round_id: String = app._round_id
	var cards: Array = app.model.cards.duplicate(true)
	var selected: String = app.model.selected_id
	var hints: int = app.model.hints_remaining
	var growth: Dictionary = app.growth.snapshot().duplicate(true)
	app._show_mode_menu()
	await settle()
	check(app.theme_buttons.size() == 8 and app.theme_buttons.all(func(button: Button) -> bool:
		return app._mode_panel.is_ancestor_of(button)), "All world choices belong to Home")
	var style_id: int = app.theme_buttons[0].get_theme_stylebox("normal").get_instance_id()
	app._refresh()
	check(app.theme_buttons[0].get_theme_stylebox("normal").get_instance_id() == style_id,
		"An unchanged gameplay refresh reuses the Home theme styles")
	for retired in ["WorldChoices", "WorldScroll", "NextWorld"]:
		check(app.find_child(retired, true, false) == null, "The old collection theme control is removed: " + retired)
	for theme_index in [4, 1]:
		var button: Button = app.theme_buttons[theme_index]
		button.grab_focus()
		await settle()
		var scroll: int = app._mode_panel.scroll.scroll_vertical
		button.pressed.emit()
		await settle()
		check(app._mode_menu_open() and not app.collection_page.visible,
			"Choosing a theme keeps Home open")
		check(app._mode_panel.scroll.scroll_vertical == scroll and button.has_focus(),
			"Theme selection preserves Home scroll and control focus")
		check(app.model.theme_id == app.Model.THEMES[theme_index]
			and app._mode_panel.snapshot().theme_id == app.model.theme_id and button.button_pressed,
			"Home identifies and applies the selected theme immediately")
		check(app._round_id == round_id and app.model.cards == cards and app.model.selected_id == selected
			and app.model.hints_remaining == hints and app.growth.snapshot() == growth,
			"A Home theme choice preserves the exact round, selection, hints and growth")
	var save_path: String = app._presentation.path
	app._presentation.path = directory + "/missing/presentation.cfg"
	app.theme_buttons[5].pressed.emit()
	await settle()
	var notice: Label = app._mode_panel._theme_save_notice
	check(app._journey_save_failed and notice.is_visible_in_tree() and app._mode_panel.snapshot().theme_save_failed,
		"A theme save failure remains visibly recoverable on Home")
	app._presentation.path = save_path
	app.theme_buttons[5].pressed.emit()
	await settle()
	check(not app._journey_save_failed and app._mode_menu_open() and not notice.visible,
		"Selecting the same Home theme retries persistence without leaving the page")
	var reloaded = load("res://scripts/presentation_preferences.gd").new()
	reloaded.path = save_path
	reloaded.load_preferences(false)
	check(reloaded.preferred_theme == "space", "A Home theme choice survives preference reload")
	for dimensions in [Vector2i(320, 320), Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(960, 720)]:
		root.size = dimensions
		await settle()
		var scale: float = app.Style.ui_scale(app)
		for button in app.theme_buttons:
			button.grab_focus()
			await settle()
			var surface: StyleBox = button.get_theme_stylebox("normal")
			check(button.size.x * scale >= 44 and button.size.y * scale >= 44,
				"Home theme buttons preserve accessible touch targets")
			check((button.size - surface.get_minimum_size()).x * scale >= 24
				and button.get_theme_constant("icon_max_width") * scale >= 24,
				"Inner padding preserves visible theme artwork")
			check(app._mode_panel.scroll.get_global_rect().grow(1).encloses(button.get_global_rect()),
				"Focus fully reveals each Home theme choice")
	app.choose_mode("match")
	await settle()
	check(app.model.theme_id == "space" and app._round_id == round_id and app.model.cards == cards
		and app.model.selected_id == selected and app.model.hints_remaining == hints and app.growth.snapshot() == growth,
		"Resuming Match applies the Home theme without replacing its partial round")
	await _check_home_only_controls(app)
	await _check_treasure_themes(app)
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Theme and treasure: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _shoulder(right: bool = true) -> void:
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_RIGHT_SHOULDER if right else JOY_BUTTON_LEFT_SHOULDER
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await settle()


func _check_home_only_controls(app) -> void:
	var theme: String = app.model.theme_id
	for context in ["gameplay", "collection"]:
		if context == "collection":
			app._show_collection()
		await settle()
		check(app.theme_buttons.all(func(button: Button) -> bool: return not button.is_visible_in_tree()),
			"Theme choices are hidden during " + context)
		app.theme_buttons[0].pressed.emit()
		await _shoulder()
		check(app.model.theme_id == theme, "Stale theme events and shoulder shortcuts cannot change themes during " + context)
	app._hide_collection()
	app._show_mode_menu()
	await settle()
	await _shoulder()
	var next: String = app.Model.THEMES[posmod(app.Model.THEMES.find(theme) + 1, app.Model.THEMES.size())]
	check(app.model.theme_id == next and app._mode_panel.snapshot().theme_id == next,
		"Controller shoulder switches the theme on Home")
	app.on_page_hidden()
	app.theme_buttons[0].pressed.emit()
	app._cycle_theme(1)
	check(app.model.theme_id == next, "Background Home rejects stale theme controls")
	app.on_page_visible()
	app._mode_panel.collection_requested.emit()
	await settle()
	app.theme_buttons[0].pressed.emit()
	await _shoulder()
	check(app.collection_page.visible and app.model.theme_id == next,
		"A collection opened from Home cannot switch the covered theme")
	app._hide_collection()
	await settle()
	check(app._mode_menu_open(), "Collection Back returns to the Home theme selector")
	app.choose_mode("match")
	await settle()


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
	app.choose_theme("spring")
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
	var chest_theme: String = app.JellyRewardProgress.theme_for_tier(1)
	var counts_before: Dictionary = app.medal_progress.counts.duplicate(true)
	for theme_id in data.THEMES:
		app.choose_theme(theme_id)
		await settle()
		_check_treasure_palette(treasure, data.theme(theme_id), "before opening")
		check(app.model.phase == "won" and app.model.chest_state == "closed" and app.chest.theme_id == chest_theme,
			"The earned tier-one chest is preserved in the selected " + theme_id + " world")
		check(app.medal_progress.counts == counts_before and app.model.reward_theme == chest_theme,
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
	check(app.model.chest_state == "opened" and app.model.reward_theme == chest_theme and earned_id == "spring-1"
		and app.medal_progress.counts == earned_counts,
		"A full hold through the scenery opens the tier-one chest and saves exactly its earned Spring medal piece")
	var saved_bytes := FileAccess.get_file_as_string(app.medal_progress._save_path)
	var pending: Dictionary = app._pending_fragment.duplicate(true)
	for theme_id in data.THEMES:
		app.choose_theme(theme_id)
		await settle()
		_check_treasure_palette(treasure, data.theme(theme_id), "after opening a Spring chest")
		check(app.model.phase == "won" and app.model.chest_state == "opened" and app.chest.mode == "opened"
			and app.chest.theme_id == chest_theme and app.model.reward_theme == chest_theme and app.model.reward_id == earned_id,
			"Changing the scene to " + theme_id + " preserves the already earned chest appearance and Spring reward")
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
