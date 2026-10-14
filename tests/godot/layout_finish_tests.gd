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
	app._presentation.path = directory + "/presentation.cfg"
	preload("res://tests/godot/player_flow_fixture.gd").install(app, directory)
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	preload("res://tests/godot/player_flow_fixture.gd").enter_mode(app, "match")
	await settle()
	check(is_equal_approx(app.collection_button.get_global_rect().get_center().y - app._content_margins.global_position.y, 40),
		"The bounded game area centers its header actions in a 56px row")
	check(app._header_duck_slot.get_global_rect().encloses(app._growth_button.get_global_rect())
		and app.find_child("MemoryProgress", true, false) == null and app.find_child("MemoryMistakes", true, false) == null,
		"Pip's compact header has no retained Memory counters")
	check(app.find_children("*", "Label", true, false).all(func(label: Label) -> bool:
		return not label.is_visible_in_tree() or not label.text in ["Find 3 pairs", "Find a pair.", "Release to hide."]),
		"Unneeded play instructions are not visible")
	var center: float = app.collection_button.get_global_rect().get_center().y
	for button in [app.hint_button, app._voice_button]:
		check(is_equal_approx(button.get_global_rect().get_center().y, center), "Top-right icons share one baseline")
	var game_top: float = app.grid.global_position.y * app.Style.ui_scale(app)
	app._show_collection()
	await settle()
	check(app._collection_title.text == "Lv0 · Baby Pip"
		and app.theme_buttons.all(func(button: Button) -> bool: return not button.is_visible_in_tree()),
		"Growth keeps its level-and-age title without theme settings")
	check(app.find_child("WorldChoices", true, false) == null and app.find_child("NextWorld", true, false) == null,
		"The collection has no old world strip or compact cycle control")
	check(app._age_choices.get_global_rect().end.y <= app._age_catalog.global_position.y,
		"Age choices precede the word catalog")
	check(app.find_child("WordStickerBook", true, false) == null, "The Words page is removed")
	check(app._collection_back.text.is_empty() and is_equal_approx(app._collection_back.size.x, app._collection_back.size.y),
		"Rewards has a square Back icon")
	check(not app.has_method("_show_reward_section") and app.find_child("Rewards_medals", true, false) == null,
		"Obsolete collection routes and Medals navigation are removed")
	check(app._age_catalog.is_visible_in_tree() and app.find_child("PipRoom", true, false) == null,
		"The central area contains the vocabulary catalog without a playground")
	app._hide_collection()
	await settle()
	check(is_equal_approx(app.grid.global_position.y * app.Style.ui_scale(app), game_top),
		"Visiting the catalog does not move the game's header or playfield")
	preload("res://tests/godot/player_flow_fixture.gd").enter_mode(app, "memory")
	await settle()
	check(not app._memory.status_label.is_visible_in_tree(), "Memory's redundant instruction line is hidden")
	var rows: Dictionary = {}
	for card in app._memory.card_buttons:
		var y: float = card.position.y
		rows[y] = int(rows.get(y, 0)) + 1
	check(rows.values().all(func(count: int) -> bool: return count == rows.values()[0])
		and rows.values()[0] in [2, 5], "Every Memory row has the same number of cards")
	preload("res://tests/godot/player_flow_fixture.gd").enter_mode(app, "match")
	root.size = Vector2i(768, 1024)
	await settle()
	check(not app._mode_panel.grid.is_visible_in_tree() and app._match_playfield.global_position.y - app._content_margins.global_position.y <= 132,
		"A wide viewport uses one compact header row")
	root.size = Vector2i(390, 844)
	await settle()
	check(not app._mode_panel.grid.is_visible_in_tree() and app._match_playfield.global_position.y <= 164
		and app._mode_heading_button.is_visible_in_tree(),
		"Narrow phones separate companion status and game actions while preserving the mode entry")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Final layout: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
