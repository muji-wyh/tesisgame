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
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 720)
	var directory := "user://layout-finish-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	app.choose_mode("match")
	await settle()
	check(is_equal_approx(app.collection_button.get_global_rect().get_center().y, 40),
		"The header centers its actions in a 56px row")
	check(app._header_duck_slot.is_ancestor_of(app._success) and app._header_duck_slot.is_ancestor_of(app._mistakes),
		"Both counters belong to Pip's status cluster")
	check(app.find_children("*", "Label", true, false).all(func(label: Label) -> bool:
		return not label.is_visible_in_tree() or not label.text in ["Find 3 pairs", "Find a pair.", "Release to hide."]),
		"Unneeded play instructions are not visible")
	var center: float = app.collection_button.get_global_rect().get_center().y
	for button in [app.hint_button, app._voice_button]:
		check(is_equal_approx(button.get_global_rect().get_center().y, center), "Top-right icons share one baseline")
	var game_top: float = app.grid.global_position.y * app.Style.ui_scale(app)
	app._show_collection()
	await settle()
	check(app._collection_title.text == "Pip" and app.theme_buttons.size() == 8
		and app._world_choices.get_parent() == app._collection_header,
		"More keeps a single Pip title plus a persistent World strip")
	check(not app.get_property_list().any(func(property: Dictionary) -> bool: return property.name in ["_world_title", "_world_note"]),
		"The shared strip has no retained World heading or tagline fields")
	var css_scale: float = app.Style.ui_scale(app)
	check(is_equal_approx(app._world_choices.global_position.y * css_scale, 12)
		and is_equal_approx(app._age_choices.global_position.y * css_scale, 72)
		and app._collection_scroll.global_position.y == app._age_choices.get_global_rect().end.y + ceili(8 / css_scale),
		"The World strip shares the header, followed directly by age controls and scrolling content")
	check(app._world_grid.columns == 8 and app._world_grid.get_theme_constant("h_separation") == roundi(6 / css_scale),
		"Eight World icons form one row with six CSS-pixel gaps")
	check(app.find_child("WordStickerBook", true, false) == null, "The Words page is removed")
	check(app._collection_back.text.is_empty() and is_equal_approx(app._collection_back.size.x, app._collection_back.size.y),
		"Rewards has a square Back icon")
	check(app.theme_buttons.all(func(button: Button) -> bool:
		return button.is_visible_in_tree() and button.icon != null and button.tooltip_text == button.name and button.get("accessibility_name") == button.name),
		"World icons have clear native tooltips and accessible names")
	for button in app.theme_buttons:
		check(button.text.is_empty() and button.size.is_equal_approx(Vector2.ONE * ceilf(52 / css_scale))
			and button.get_theme_constant("icon_max_width") == ceili(36 / css_scale),
			"Each named World icon has a 52 CSS-pixel square target and 36 CSS-pixel artwork")
	check(not app.has_method("_show_reward_section") and app.find_child("Rewards_medals", true, false) == null,
		"Obsolete collection routes and Medals navigation are removed")
	check(app._room.is_visible_in_tree() and app._collection_grid.get_children().all(
		func(child: Node) -> bool: return child == app._room or child == app._age_choices),
		"More contains the room and responsive age choices without a medal goal or shelves")
	app._hide_collection()
	check(is_equal_approx(app.grid.global_position.y * app.Style.ui_scale(app), game_top),
		"Adding the More strip does not move the game's header or playfield")
	app.choose_mode("memory")
	await settle()
	check(not app._memory.status_label.is_visible_in_tree(), "Memory's redundant instruction line is hidden")
	var rows: Dictionary = {}
	for card in app._memory.card_buttons:
		var y: float = card.position.y
		rows[y] = int(rows.get(y, 0)) + 1
	check(rows.values().all(func(count: int) -> bool: return count == rows.values()[0])
		and rows.values()[0] in [2, 5], "Every Memory row has the same number of cards")
	app.choose_mode("match")
	root.size = Vector2i(768, 1024)
	await settle()
	check(app._mode_row.get_parent() == app._header and app._match_playfield.global_position.y <= 80,
		"A wide viewport uses one compact header row")
	root.size = Vector2i(390, 844)
	await settle()
	check(app._mode_row.get_parent() == app._main_column,
		"Narrow phones keep a separate mode row instead of crowding the controls")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Final layout: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
