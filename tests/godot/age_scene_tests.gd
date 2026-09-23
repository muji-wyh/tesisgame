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


func _run() -> void:
	var probe = load("res://scripts/game_ui.gd").new()
	var ready: bool = probe.has_method("_choose_age_band")
	check(ready, "More provides an age selection action")
	probe.free()
	if not ready:
		quit(1)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 720)
	var directory := "user://age-scene-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	check(app._mode_id == "match" and app.model.age_band_id == "all", "Startup retains Match and all words by default")
	app._request_hint()
	app.cards[app.model.hint_ids[0]].pressed.emit()
	var cards: Array = app.model.cards.duplicate(true)
	var words: Array = app.model.lesson_words.duplicate(true)
	var progress: Array = [app.model.selected_id, app.model.hints_remaining, app.model.phase,
		app.model.successes, app.model.mistakes, app.model.streak]
	var counts: Dictionary = app.medal_progress.counts.duplicate(true)
	app._show_collection()
	for age_id in ["7-9", "4-6"]:
		await settle()
		app._collection_scroll.scroll_vertical = 60
		var scroll: int = app._collection_scroll.scroll_vertical
		var button: Button = app._age_buttons[age_id]
		button.grab_focus()
		button.pressed.emit()
		await settle()
		check(app.collection_page.visible and app._room.is_visible_in_tree()
			and button.has_focus() and app._collection_scroll.scroll_vertical == scroll,
			"Changing age stays on the same More page without moving scroll or focus")
		check(app.model.cards == cards and app.model.lesson_words == words and app.model.age_band_id == "all"
			and [app.model.selected_id, app.model.hints_remaining, app.model.phase,
				app.model.successes, app.model.mistakes, app.model.streak] == progress,
			"Age selection preserves the exact active round, selection and hints")
		check(app._age_notice.text.is_empty() and not app._age_notice.is_visible_in_tree()
			and app._age_buttons.values().filter(func(choice: Button) -> bool: return choice.button_pressed).size() == 1
			and app.medal_progress.counts == counts,
			"One age is selected without a redundant hint, and rewards are untouched")
	app._collection_dragged = true
	app._age_buttons["10-plus"].pressed.emit()
	check(app.playroom_state.age_band_id == "4-6", "A dragged gesture cannot change age")
	app._collection_dragged = false
	app._hide_collection()
	app._age_buttons["10-plus"].pressed.emit()
	check(app.playroom_state.age_band_id == "4-6", "Hidden age controls cannot change the preference")
	for mode in ["memory", "pop", "match"]:
		app.choose_mode(mode)
		await settle()
		check(app.model.lesson_words == words and app.model.age_band_id == "all",
			"Switching to " + mode + " retains the active vocabulary, not the next-lesson setting")
		if mode == "memory":
			check(app._memory.memory.cards.size() == 10, "Memory retains five pairs at every age")
	check(app.new_round(31, false, "space-trip", "match"), "A new lesson can start at the saved age")
	await settle()
	check(app.model.age_band_id == "4-6" and app.model.lesson_words.all(
		func(word: Dictionary) -> bool: return app.Data.word_level(word) == 1),
		"The next Match lesson uses the saved basic vocabulary")
	app._show_collection()
	await settle()
	var saved_path: String = app.playroom_state._save_path
	var original := FileAccess.get_file_as_string(saved_path)
	app.playroom_state._save_path = directory + "/missing/room.cfg"
	app._age_buttons["10-plus"].grab_focus()
	app._age_buttons["10-plus"].pressed.emit()
	await settle()
	check(app.playroom_state.age_band_id == "4-6" and app._age_buttons["4-6"].button_pressed
		and not app._age_buttons["10-plus"].button_pressed
		and app._age_notice.text.contains("retry") and app._age_notice.is_visible_in_tree()
		and FileAccess.get_file_as_string(saved_path) == original,
		"A failed save restores the confirmed selection and presents a retry, without changing saved bytes")
	app.playroom_state._save_path = saved_path
	app._age_buttons["10-plus"].pressed.emit()
	await settle()
	check(app.playroom_state.age_band_id == "10-plus" and app._age_buttons["10-plus"].button_pressed
		and app._age_notice.text.is_empty() and not app._age_notice.is_visible_in_tree()
		and app.model.age_band_id == "4-6" and app.collection_page.visible,
		"A successful retry removes the error without changing the active lesson")
	var reloaded = app.PlayroomState.new(saved_path)
	check(reloaded.load_state() and reloaded.age_band_id == "10-plus", "The UI choice survives a storage reload")
	for dimensions in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(844, 390), Vector2i(768, 1024), Vector2i(1366, 768)]:
		root.size = dimensions
		await settle()
		var scale: float = app.Style.ui_scale(app)
		check(app._age_buttons.keys() == ["all", "4-6", "7-9", "10-plus"], "All four age choices remain directly available")
		for id in app._age_buttons:
			var button: Button = app._age_buttons[id]
			check(button.is_visible_in_tree() and button.size.x * scale >= 48 and button.size.y * scale >= 48,
				"Age buttons retain 48 CSS-pixel input targets at " + str(dimensions))
			check(app.get_global_rect().encloses(button.get_global_rect())
				and str(button.get("accessibility_name")).contains(app.Data.age_band(id).name),
				"Age choices fit the viewport and retain descriptive accessible names")
		check(app._age_choices.get_global_rect().end.y <= app._collection_scroll.global_position.y
			and app._collection_scroll.size.y * scale >= 160,
			"Compact age controls leave a usable, separate scrolling content area")
		check(not app._age_notice.is_visible_in_tree()
			and is_equal_approx(app._age_choices.size.y, app._age_row.size.y),
			"The hidden notice leaves no reserved height or gap below the age buttons")
		var order: Array = app._focus_candidates()
		check(order.find(app._collection_back) < order.find(app._age_buttons["all"])
			and app._focus_center(app._age_buttons["all"]).y < app._focus_center(app._room.toy_button).y,
			"Age controls follow the header and precede scrolling content in focus order")
		app._age_buttons["all"].grab_focus()
		app._move_focus(Vector2.RIGHT)
		check(app._age_buttons["4-6"].has_focus(), "Controller navigation traverses the age row left to right")
		app._controller_accept()
		check(app.playroom_state.age_band_id == "4-6" and app._age_buttons["4-6"].button_pressed,
			"Controller accept selects and saves an age level")
		app._move_focus(Vector2.UP)
		check(app.theme_buttons.has(root.gui_get_focus_owner())
			or app._collection_back.has_focus(), "Up from the age row reaches the header rather than scrolled content")
	app._hide_collection()
	check(app.new_round(33, false, "music-makers", "match") and app.model.age_band_id == "4-6",
		"A new Match round uses the saved age preference")
	app.choose_mode("memory")
	check(app.model.age_band_id == "4-6" and app._memory.memory.cards.all(
		func(card: Dictionary) -> bool: return app.Data.word_level(card.word) == 1),
		"Memory uses the same age-eligible lesson")
	root.size = Vector2i(320, 320)
	app._show_collection()
	await settle()
	await settle()
	check(app._age_choices.get_parent() == app._collection_grid and app._age_choices.is_visible_in_tree()
		and app._collection_scroll.size.y >= 128,
		"Short screens scroll the age row with content instead of squeezing the room")
	app._age_buttons["7-9"].grab_focus()
	await settle()
	check(app._collection_scroll.get_global_rect().encloses(app._age_buttons["7-9"].get_global_rect()),
		"Keyboard focus can reveal scrolled age choices on short screens")
	app._build_collection()
	await settle()
	check(app._age_buttons.size() == 4 and app._age_buttons["7-9"].is_inside_tree(),
		"Rebuilding rewards preserves the responsive age controls")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Age controls: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
