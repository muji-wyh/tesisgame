extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	var directory := "user://collection-nav-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/playroom.cfg"
	root.add_child(app)
	await process_frame
	await process_frame
	app.audio.set_muted(true)
	app.medal_progress.counts["winter-6"] = 3
	app._refresh_collection()
	check(app._reward_slots["winter-6"].picture.texture == null, "Hidden medals do not load their artwork during startup refresh")
	app._show_collection()
	check(app._reward_slots["winter-6"].picture.texture == null, "Opening Pip's room keeps medal artwork deferred")
	check(app._room.is_visible_in_tree(), "Rewards starts with Pip's room")
	check(app._collection_rows.all(func(row) -> bool: return not row.is_visible_in_tree()), "Medals do not share the room's long toy list")
	check(app.has_method("_show_reward_section"), "Rewards has a direct route between the room and medals")
	if app.has_method("_show_reward_section"):
		app._show_reward_section("medals")
		await process_frame
		check(app._reward_slots["winter-6"].picture.texture != null, "Opening Medals loads earned medal artwork")
		check(not app._room.is_visible_in_tree(), "Medals hides the room's toy controls")
		check(app._collection_rows.all(func(row) -> bool: return row.is_visible_in_tree()), "The Medals route exposes every theme")
		root.size = Vector2i(480, 600)
		await process_frame
		await process_frame
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		wheel.factor = 3.0
		app._collection_scroll_input(wheel, app._collection_scroll)
		check(app._collection_scroll.scroll_vertical == 144, "A larger wheel movement scrolls proportionally instead of one fixed step")
		var after_scroll: int = app._collection_scroll.scroll_vertical
		wheel.pressed = false
		app._collection_scroll_input(wheel, app._collection_scroll)
		check(app._collection_scroll.scroll_vertical == after_scroll, "Wheel release does not scroll twice")
		check(app._status_announcement.contains("Medals"), "The current reward section is announced")
		app.medal_progress.counts["spring-1"] = 1
		app._refresh_collection()
		app._open_reward_preview("spring-1")
		check(app._preview_page.visible, "An earned piece opens from Medals")
		app._hide_reward_preview()
		check(app._collection_section == "medals" and not app._room.visible, "Closing a medal returns to the same reward section")
		app._show_reward_section("room")
		check(app._room.visible and app._collection_scroll.scroll_vertical == 0, "Returning to the room starts at its scene")
		check(not app._valid_focus(app._reward_slots["spring-1"].button), "Hidden medals cannot take keyboard or controller focus")
		app._hide_collection()
		app._show_collection()
		check(app._room.visible and app._collection_tabs.values().all(func(button) -> bool: return button.visible),
			"More retains its direct reward sections without an adventure picker")
		root.size = Vector2i(960, 480)
		await process_frame
		await process_frame
		var card: Button = app._room.item_buttons["toy-space"]
		card.grab_focus()
		app._collection_scroll.ensure_control_visible(card)
		var position: int = app._collection_scroll.scroll_vertical
		card.pressed.emit()
		await process_frame
		await process_frame
		check(root.gui_get_focus_owner() == card and app._collection_scroll.scroll_vertical == position,
			"A locked preview keeps the current card focus and scroll position")
		app._room.goal_button.grab_focus()
		await process_frame
		await process_frame
		check(app._collection_scroll.get_global_rect().encloses(app._room.goal_button.get_global_rect()), "The gift goal stays visible after previewing a scrolled gift on landscape screens")
		var owned_card: Button = app._room.item_buttons[app.playroom_state.toy_id]
		owned_card.grab_focus()
		await process_frame
		await process_frame
		check(root.gui_get_focus_owner() == owned_card and app._collection_scroll.get_global_rect().encloses(owned_card.get_global_rect()), "An owned toy card stays reachable for leaving a locked preview on landscape screens")
		owned_card.pressed.emit()
		app._show_reward_section("medals")
		app._hide_collection()
		check(app.playroom_state.set_goal("toy-spring", app.medal_progress.counts), "An unfinished gift can be selected before its final piece")
		app.medal_progress.counts["spring-1"] = 3
		app._unlocked_gift = load("res://scripts/playroom_state.gd").item("toy-spring")
		app._try_unlocked_gift()
		for frame in range(5):
			await process_frame
		check(app._room.is_visible_in_tree() and app.playroom_state.toy_id == "toy-spring", "Try it with Pip opens the gift in the room after visiting Medals")
		check(root.gui_get_focus_owner() == app._room.toy_button and app._collection_scroll.get_global_rect().encloses(app._room.toy_button.get_global_rect()),
			"Try gift focuses the visible toy after the completed-goal layout settles: viewport=%s toy=%s scroll=%d/%d" % [
				app._collection_scroll.get_global_rect(), app._room.toy_button.get_global_rect(),
				app._collection_scroll.scroll_vertical, app._collection_max_scroll().y])
	await _check_owned_display_navigation(app)
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Collection navigation: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_owned_display_navigation(app) -> void:
	var original_cards: Dictionary = app._room.item_buttons.duplicate()
	for theme_id in app.Data.THEMES:
		for medal in app.Data.medals(theme_id):
			app.medal_progress.counts[medal.id] = 3
	app._refresh_collection()
	var earned: Dictionary = app.medal_progress.counts.duplicate()
	var stickers: Array = app.playroom_state.collected_word_ids.duplicate()
	for dimensions in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(768, 1024), Vector2i(1366, 768), Vector2i(1920, 1080)]:
		root.size = dimensions
		for frame in range(6):
			await process_frame
		check(app._room.owned_toys.get_child_count() == 9 and not app._room._item_grid.visible
			and app._room.item_buttons.keys().all(func(id: String) -> bool: return app._room.item_buttons[id] == original_cards[id]),
			"The fully earned home retains all nine controls and removes the empty locked catalog at " + str(dimensions))
		for item in app.playroom_state.toys():
			var card: Button = app._room.item_buttons[item.id]
			var active: bool = app._room._toy.id == item.id and not app._room._preview_locked
			var control: Button = app._room.toy_button if active else card
			var label: Label = app._room._toy_label if active else card.title_label
			control.grab_focus()
			for frame in range(5):
				await process_frame
			check(control.has_focus() and app._focus_candidates().has(control)
				and app._collection_scroll.get_global_rect().grow(1).encloses(control.get_global_rect())
				and app._room._room.get_global_rect().grow(1).encloses(control.get_global_rect()),
				"Keyboard focus reaches the playable " + item.id + " on the floor at " + str(dimensions))
			check(label.is_visible_in_tree() and label.text == item.word_id
				and label.get_visible_line_count() == label.get_line_count()
				and app._collection_scroll.get_global_rect().grow(1).encloses(label.get_global_rect()),
				"The playable %s retains its readable noun at %s: visible=%d/%d, size=%s, font_height=%f, scale=%f" % [
					item.id, dimensions, label.get_visible_line_count(), label.get_line_count(),
					label.size, label.get_theme_font("font").get_height(label.get_theme_font_size("font_size")),
					app.Style.ui_scale(app)])
			app._controller_accept()
			check(app.playroom_state.toy_id == item.id and app._room._toy.id == item.id
				and not app._room._preview_locked and app._room._stage == 1,
				"One controller activation equips and starts " + item.id + " directly on the floor")
	check(app.medal_progress.counts == earned and app.playroom_state.collected_word_ids == stickers,
		"Selecting every displayed toy preserves earned pieces and collected words")
