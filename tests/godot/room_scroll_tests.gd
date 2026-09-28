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


func pointer(point: Vector2, down: bool, touch: bool, canceled: bool = false) -> void:
	var event: InputEvent
	if touch:
		event = InputEventScreenTouch.new()
		event.index = 0
		event.canceled = canceled
	else:
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.position = point
	event.pressed = down
	root.push_input(event, true)
	await process_frame


func motion(point: Vector2, touch: bool) -> void:
	var event: InputEvent = InputEventScreenDrag.new() if touch else InputEventMouseMotion.new()
	event.position = point
	if touch:
		event.index = 0
	else:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)
	await process_frame


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(320, 568)
	var directory := "user://room-scroll-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/room.cfg"
	root.add_child(app)
	await settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(true)
	app._show_collection()
	await settle()
	var scene: Control = app._room._room
	await _check_strips(app)
	for touch in [false, true]:
		for locked in [false, true]:
			if locked:
				app._room._choose_item("toy-spring")
				await settle()
			app._collection_scroll.scroll_vertical = 0
			app._room.playground.cancel()
			await settle()
			var point: Vector2 = app._room.toy_button.get_global_rect().get_center() if locked else scene.global_position + Vector2(scene.size.x * 0.5, 90)
			var feedback: String = app._room.feedback_text
			check(not app.duck.get_global_rect().has_point(point), "The scroll starts outside Pip")
			if locked:
				await pointer(point, true, touch)
				await pointer(point, false, touch)
				check(app._room.feedback_text == feedback and app._room.playground.motion_kind.is_empty(),
					"An inactive toy tap stays inactive inside the fixed playground")
			await pointer(point, true, touch)
			for step in range(1, 5):
				await motion(point - Vector2(0, step * 16), touch)
			await pointer(point - Vector2(0, 64), false, touch)
			check(app._collection_scroll.scroll_vertical == 0
				and app._collection_scroll.scroll_horizontal == 0,
				"Background and locked-toy drags cannot move the page: touch=%s locked=%s" % [touch, locked])
			check(app._room.feedback_text == feedback and app._room.playground.motion_kind.is_empty(),
				"A non-tap gesture does not also call Pip or play the toy")
			if locked:
				app._room.item_buttons[app.playroom_state.toy_id].pressed.emit()
			else:
				app._room.playground.cancel()
			await settle()
	app._collection_scroll.scroll_vertical = 0
	await settle()
	var floor: Vector2 = scene.global_position + Vector2(scene.size.x * 0.5, 90)
	await pointer(floor, true, false)
	await pointer(floor, false, false)
	check(app._room.feedback_text.contains("over!") and app._collection_scroll.scroll_vertical == 0,
		"A stationary floor tap still calls Pip without scrolling")
	app._room.playground.cancel()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = floor
	root.push_input(wheel, true)
	await process_frame
	check(app._collection_scroll.scroll_vertical == 0, "Mouse wheel input cannot scroll the playground")
	check(app.medal_progress.counts.is_empty(), "Room gestures do not award progress")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Room scrolling: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_strips(app) -> void:
	var strips: Array = [app._age_scroll, app._world_scroll, app._room.toy_shelf]
	for strip: ScrollContainer in strips:
		check(strip.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER
			and strip.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
			and not strip.get_h_scroll_bar().is_visible_in_tree()
			and not strip.get_v_scroll_bar().is_visible_in_tree(),
			"Each room strip scrolls horizontally without visible scrollbars: " + strip.name)
		check(strip.get_h_scroll_bar().max_value > strip.get_h_scroll_bar().page,
			"The narrow-phone fixture has real overflow to exercise: " + strip.name)
		for touch in [false, true]:
			for other: ScrollContainer in strips:
				other.scroll_horizontal = 0
			await settle()
			var before: Array = [app.playroom_state.age_band_id, app.model.theme_id, app._room._preview_id]
			var stage_bounds: Rect2 = app._room._room.get_global_rect()
			var point: Vector2 = strip.get_global_rect().get_center()
			await pointer(point, true, touch)
			var origin: int = strip.scroll_horizontal
			for step in range(1, 5):
				await motion(point - Vector2(step * 16, 0), touch)
			await pointer(point - Vector2(64, 0), false, touch)
			check(strip.scroll_horizontal > origin,
				"A real horizontal drag advances its strip: %s touch=%s" % [strip.name, touch])
			check(strips.all(func(other: ScrollContainer) -> bool: return other == strip or other.scroll_horizontal == 0),
				"Dragging one strip leaves the other two positions unchanged: " + strip.name)
			check(before == [app.playroom_state.age_band_id, app.model.theme_id, app._room._preview_id],
				"A strip drag does not choose an age, theme, or toy: " + strip.name)
			check(app._room._room.get_global_rect() == stage_bounds
				and app._collection_scroll.scroll_vertical == 0,
				"The playground stays fixed while a strip moves: " + strip.name)
	var targets: Array = [app._age_buttons["10-plus"], app.theme_buttons.back(), app._room.item_buttons["toy-candy"]]
	for index in range(strips.size()):
		var strip: ScrollContainer = strips[index]
		strip.scroll_horizontal = 0
		targets[index].grab_focus()
		await settle()
		check(targets[index].has_focus() and strip.get_global_rect().grow(1).encloses(targets[index].get_global_rect()),
			"Keyboard focus reveals an offscreen choice in its own strip: " + strip.name)
	for dimensions in [Vector2i(320, 320), Vector2i(390, 844), Vector2i(844, 390), Vector2i(768, 1024), Vector2i(1366, 768)]:
		root.size = dimensions
		await settle()
		var bounds: Rect2 = app.get_global_rect().grow(1)
		var stage: Rect2 = app._room._room.get_global_rect()
		check(strips.all(func(strip: ScrollContainer) -> bool: return bounds.encloses(strip.get_global_rect()))
			and bounds.encloses(stage) and app._collection_scroll.scroll_vertical == 0,
			"All controls stay inside the fixed page at " + str(dimensions))
		check(app._age_scroll.get_global_rect().end.y <= stage.position.y
			and stage.end.y <= app._world_scroll.global_position.y
			and app._world_scroll.get_global_rect().end.y <= app._room.toy_shelf.global_position.y,
			"The layout orders age, playground, themes, and toys at " + str(dimensions))
		check(absf(stage.size.y - app._collection_scroll.size.y) <= 2,
			"The playground uses the entire remaining center at " + str(dimensions))
	root.size = Vector2i(320, 568)
	await settle()
