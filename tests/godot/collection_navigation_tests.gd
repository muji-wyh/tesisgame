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
	app._show_collection()
	check(app._room.is_visible_in_tree(), "Rewards starts with Pip's room")
	check(app._collection_rows.all(func(row) -> bool: return not row.is_visible_in_tree()), "Medals do not share the room's long toy list")
	check(app.has_method("_show_reward_section"), "Rewards has a direct route between the room and medals")
	if app.has_method("_show_reward_section"):
		app._show_reward_section("medals")
		await process_frame
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
		app._show_adventures()
		check(app._collection_title.visible and app._collection_tabs.values().all(func(button) -> bool: return not button.visible), "Adventure navigation has its own title and no reward tabs")
		app._hide_collection()
		app._show_collection()
		check(app._room.visible and not app._adventure_book.visible, "Leaving Adventures restores the reward section correctly")
		root.size = Vector2i(960, 480)
		await process_frame
		await process_frame
		app._room.action_button.grab_focus()
		app._collection_scroll.ensure_control_visible(app._room.item_buttons["toy-space"])
		app._room.item_buttons["toy-space"].pressed.emit()
		await process_frame
		await process_frame
		check(app._collection_scroll.get_global_rect().encloses(app._room.action_button.get_global_rect()), "The locked preview's return button is visible on landscape screens")
		app._room.action_button.pressed.emit()
		app._show_reward_section("medals")
		app._hide_collection()
		app.medal_progress.counts["spring-1"] = 3
		app._unlocked_gift = load("res://scripts/playroom_state.gd").item("toy-spring")
		app._try_unlocked_gift()
		check(app._room.is_visible_in_tree() and app.playroom_state.toy_id == "toy-spring", "Try it with Pip opens the gift in the room after visiting Medals")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Collection navigation: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
