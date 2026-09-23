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


func tap(point: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = point
	root.push_input(move, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = true
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)
	await process_frame
	event.pressed = false
	event.button_mask = 0
	root.push_input(event, true)
	await settle()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(390, 650)
	var directory := "user://inline-goals-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	app.medal_progress.counts = {"spring-1": 3, "space-1": 2}
	app._show_collection()
	await settle()
	var words: Array = app.model.lesson_words.duplicate(true)
	for id in ["toy-space", "toy-spring"]:
		app._collection_scroll.scroll_vertical = 0
		await settle()
		var card: Button = app._room.item_buttons[id]
		var viewport: Rect2 = app._collection_scroll.get_global_rect()
		app._collection_scroll.scroll_vertical = maxi(0, roundi(card.global_position.y - viewport.end.y + 44))
		await settle()
		var scroll: int = app._collection_scroll.scroll_vertical
		var before: Rect2 = card.get_global_rect()
		var visible: Rect2 = before.intersection(viewport)
		check(visible.size.y > 12, "The card has a real visible pointer target")
		await tap(visible.get_center())
		check(app._collection_scroll.scroll_vertical == scroll, "Pointer card selection keeps the exact scroll offset: " + id)
		check(card.get_global_rect().is_equal_approx(before), "Card selection does not move the grid under the pointer: " + id)
		check(app.collection_page.visible and app.model.lesson_words == words, "Preview/equipment does not start a lesson")
		if id == "toy-space":
			check(app._room.goal_button.get_parent() == card and app._room.goal_label.get_parent() == card,
				"The goal action and status belong to the selected card")
			check(app._room.goal_button.text.is_empty() and app._room.goal_label.text.contains("1 more piece"),
				"The standalone Help button is replaced by an inline status and action")
			check(card.get_global_rect().encloses(app._room.goal_button.get_global_rect())
				and card.get_global_rect().encloses(app._room.goal_label.get_global_rect()),
				"Inline goal controls fit their fixed-size card")
			var tab := InputEventKey.new()
			tab.keycode = KEY_TAB
			tab.pressed = true
			root.push_input(tab, true)
			tab.pressed = false
			root.push_input(tab, true)
			await settle()
			check(app._room.goal_button.has_focus()
				and app._collection_scroll.get_global_rect().grow(1).encloses(card.get_global_rect()),
				"Keyboard focus reveals both the inline action and its card status")
	check(app.find_children("*", "Button", true, false).all(func(button: Button) -> bool:
		return button.text != "Help Pip get this"), "No standalone Help Pip get this control remains")
	var key := InputEventKey.new()
	key.keycode = KEY_TAB
	key.pressed = true
	root.push_input(key, true)
	key.pressed = false
	root.push_input(key, true)
	var rocket: Button = app._room.item_buttons["toy-space"]
	rocket.grab_focus()
	await settle()
	check(app._collection_scroll.get_global_rect().grow(1).encloses(rocket.get_global_rect()),
		"Keyboard focus still scrolls a toy card fully into view")
	rocket.pressed.emit()
	await settle()
	var save_path: String = app.playroom_state._save_path
	app.playroom_state._save_path = directory + "/missing/room.cfg"
	var scroll: int = app._collection_scroll.scroll_vertical
	app._room.goal_button.pressed.emit()
	await settle()
	check(app.collection_page.visible and app._room.goal_label.text.contains("Not saved")
		and app._room.goal_label.get_parent() == rocket,
		"A failed goal save is shown on the same card")
	check(app._collection_scroll.scroll_vertical == scroll and app.model.lesson_words == words,
		"Failed goal saves do not jump the page or replace the lesson")
	app.playroom_state._save_path = save_path
	app._room.goal_button.pressed.emit()
	check(app._mode_id == "match" and app.playroom_state.goal_item_id == "toy-space"
		and app.model.lesson_words.any(func(word: Dictionary) -> bool: return word.id == "rocket"),
		"The inline action starts a Match adventure containing the gift word")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Inline goals: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
