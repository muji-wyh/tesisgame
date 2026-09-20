extends SceneTree

var checks := 0
var failures := 0
var taps := 0
var outside_releases := 0
var emulated_presses := 0


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
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	var cards: Array = app.model.cards.duplicate(true)
	app._show_collection()
	for section in ["room", "medals"]:
		app._show_reward_section(section)
		await settle()
		app._collection_scroll.scroll_vertical = 48
		var scroll: int = app._collection_scroll.scroll_vertical
		var button: Button = app.theme_buttons[4 if section == "room" else 1]
		button.grab_focus()
		button.pressed.emit()
		await settle()
		check(app.collection_page.visible and app._collection_section == section,
			"Choosing a theme stays on the current reward page")
		check(app._collection_scroll.scroll_vertical == scroll and button.has_focus(),
			"Theme selection preserves scroll and control focus")
		check(app.model.cards == cards and app.model.hints_remaining == 3,
			"The current game is not reset by a theme choice")
		if not app.collection_page.visible:
			app._show_collection()
	var save_path: String = app.playroom_state._save_path
	app.playroom_state._save_path = directory + "/missing/room.cfg"
	app.theme_buttons[5].pressed.emit()
	await settle()
	var notice: Label = app.get("_world_save_notice")
	check(app._journey_save_failed and notice != null and notice.is_visible_in_tree(),
		"A theme save failure stays visibly recoverable in the open page")
	app.playroom_state._save_path = save_path
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
			var surface: StyleBox = button.get_theme_stylebox("normal")
			check(button.size.x * scale >= 52 and button.size.y * scale >= 52,
				"The theme buttons are visibly larger")
			check((button.size - surface.get_minimum_size()).x * scale >= 36
				and button.get_theme_constant("icon_max_width") * scale >= 36,
				"Inner padding leaves room for the larger theme artwork")
			check(app.get_global_rect().encloses(button.get_global_rect()), "Theme choices fit the viewport")
		if dimensions.x >= 664:
			check(app._world_choices.get_parent() == app._collection_header
				and app.theme_buttons[0].get_global_rect().get_center().y * scale < 44,
				"Wide screens move theme choices up into the top header")
	app._hide_collection()
	await _check_treasure_themes(app)
	root.size = Vector2i(320, 568)
	app.model.phase = "lost"
	app._refresh()
	await settle()
	var treasure: Control = app.get("_treasure_backdrop")
	check(treasure != null and not treasure.visible and not treasure.is_visible_in_tree(),
		"The encouragement result hides the treasure world's scene and theme badge")
	var review: ScrollContainer = app._found_words_scroll
	check(review.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER
		and not review.get_h_scroll_bar().visible, "Review words scroll without a visible scrollbar")
	for button in app._found_words.get_children():
		check(button.tooltip_text.is_empty() and str(button.get("accessibility_name")).begins_with("Hear "),
			"Review guidance stays accessible without a tooltip obscuring held drags")
		button.pressed.connect(func() -> void: taps += 1)
	for touch in [false, true]:
		review.scroll_horizontal = 0
		await settle()
		var point: Vector2 = app._found_words.get_child(1).get_global_rect().get_center()
		var before: int = taps
		await pointer(point, true, touch)
		await motion(point - Vector2(12, 0), touch)
		await motion(point - Vector2(24, 0), touch)
		check(absi(review.scroll_horizontal - 24) <= 1, "Review words follow the held horizontal drag")
		await pointer(point - Vector2(24, 0), false, touch)
		check(taps == before, "Dragging the review strip never pronounces a word")
		point = app._found_words.get_child(1).get_global_rect().get_center()
		await pointer(point, true, touch)
		await pointer(point, false, touch)
		check(taps == before + 1, "A review word still responds to a stationary tap")
	var last: Button = app._found_words.get_children().back()
	last.grab_focus()
	await settle()
	check(review.get_global_rect().grow(1).encloses(last.get_global_rect()),
		"Keyboard and controller focus can still reveal the final word")
	review.scroll_horizontal = 0
	await settle()
	var point: Vector2 = app._found_words.get_child(1).get_global_rect().get_center()
	var before: int = taps
	await pointer(point, true)
	app._show_collection()
	await pointer(point, false)
	app._hide_collection()
	check(taps == before, "Opening More cancels a pending review tap")
	await pointer(point, true, true)
	var second := InputEventScreenTouch.new()
	second.index = 1
	second.position = point + Vector2(20, 0)
	second.pressed = true
	root.push_input(second, true)
	await pointer(point, false, true)
	second.pressed = false
	root.push_input(second, true)
	await process_frame
	check(taps == before, "Multiple touches cannot pronounce a review word")
	var outside: Vector2 = app._new_adventure_button.get_global_rect().get_center()
	check(not review.get_global_rect().has_point(outside), "The external-gesture fixture starts outside the review strip")
	app._new_adventure_button.button_up.connect(func() -> void: outside_releases += 1)
	await pointer(outside, true, true)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.button_mask = MOUSE_BUTTON_MASK_LEFT
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.position = outside
	mouse.pressed = true
	root.push_input(mouse, true)
	await motion(point, true)
	var move := InputEventMouseMotion.new()
	move.device = InputEvent.DEVICE_ID_EMULATION
	move.position = point
	move.relative = point - outside
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(move, true)
	await pointer(point, false, true)
	mouse.button_mask = 0
	mouse.position = point
	mouse.pressed = false
	root.push_input(mouse, true)
	await process_frame
	check(outside_releases == 1 and taps == before and app.model.phase == "lost",
		"A touch begun outside the strip keeps its own emulated mouse release: releases=%d taps=%d/%d phase=%s outside=%s review=%s" % [
			outside_releases, taps, before, app.model.phase, outside, review.get_global_rect()])
	var word_button: Button = app._found_words.get_child(1)
	point = word_button.get_global_rect().get_center()
	word_button.button_down.connect(func() -> void: emulated_presses += 1)
	mouse.position = point
	mouse.pressed = true
	mouse.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(mouse, true)
	await pointer(point, true, true)
	await pointer(point, false, true)
	mouse.pressed = false
	mouse.button_mask = 0
	root.push_input(mouse, true)
	await process_frame
	check(emulated_presses == 0 and taps == before + 1,
		"Mouse-first touch emulation cannot leave a native button press behind")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Theme and review: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_treasure_themes(app) -> void:
	var treasure: Control = app.get("_treasure_backdrop")
	check(treasure != null, "The treasure result has a dedicated world scene")
	if treasure == null:
		return
	var data = load("res://scripts/game_data.gd")
	check(app.new_round(732, false, "", "match"), "The treasure-world fixture starts a real Match round")
	check(not treasure.visible and not treasure.is_visible_in_tree(), "Active play hides the treasure scene")
	app.choose_theme("spring")
	for card in app.model.cards:
		if card.kind == "word" and not app.model.card_by_id(card.word.id + ":image").is_empty():
			app.cards[card.id].pressed.emit()
			app.cards[card.word.id + ":image"].pressed.emit()
			app.feedback_timer.timeout.emit()
	await settle()
	check(app.model.phase == "won" and app.model.chest_state == "closed",
		"Three real matches enter the themed treasure result with an unopened chest")
	check(treasure.mouse_filter == Control.MOUSE_FILTER_IGNORE and treasure.focus_mode == Control.FOCUS_NONE,
		"The world scenery never captures chest pointer input or keyboard focus")
	var counts_before: Dictionary = app.medal_progress.counts.duplicate(true)
	for theme_id in data.THEMES:
		app.choose_theme(theme_id)
		await settle()
		_check_treasure_palette(treasure, data.theme(theme_id), "before opening")
		check(app.model.phase == "won" and app.model.chest_state == "closed" and app.chest.theme_id == theme_id,
			"The unopened chest follows the selected " + theme_id + " world")
		check(app.medal_progress.counts == counts_before and app.model.reward_theme.is_empty(),
			"Viewing the " + theme_id + " treasure world cannot claim a medal piece")
	app.choose_theme("spring")
	await settle()
	var point: Vector2 = app.chest_button.get_global_rect().get_center()
	await pointer(point, true)
	app._process(0.1)
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
	app._process(1.21)
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
