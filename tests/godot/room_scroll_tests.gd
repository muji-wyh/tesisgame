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
	root.size = Vector2i(390, 650)
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
	app._show_reward_section("room")
	await settle()
	var scene: Control = app._room._room
	for touch in [false, true]:
		for locked in [false, true]:
			if locked:
				app._room._choose_item("toy-spring")
				await settle()
			app._collection_scroll.scroll_vertical = 0
			app._room.playground.cancel()
			await settle()
			var point: Vector2 = app._room.toy_button.get_global_rect().get_center() if locked else scene.global_position + Vector2(scene.size.x * 0.5, 90)
			var caption: String = app._room.caption.text
			check(not app.duck.get_global_rect().has_point(point), "The scroll starts outside Pip")
			if locked:
				await pointer(point, true, touch)
				await pointer(point, false, touch)
				check(app._room.caption.text == caption and app._room.playground.motion_kind.is_empty(),
					"An inactive toy tap stays inactive while its area supports scrolling")
			await pointer(point, true, touch)
			for step in range(1, 5):
				await motion(point - Vector2(0, step * 16), touch)
			await pointer(point - Vector2(0, 64), false, touch)
			check(absi(app._collection_scroll.scroll_vertical - 64) <= 2,
				"Background and locked toys track scrolling: touch=%s locked=%s actual=%d" % [touch, locked, app._collection_scroll.scroll_vertical])
			check(app._room.caption.text == caption and app._room.playground.motion_kind.is_empty(),
				"A scroll does not also call Pip or play the toy")
			if locked:
				app._room._activate_action()
			else:
				app._room.playground.cancel()
			await settle()
	app._collection_scroll.scroll_vertical = 0
	await settle()
	var floor: Vector2 = scene.global_position + Vector2(scene.size.x * 0.5, 90)
	await pointer(floor, true, false)
	await pointer(floor, false, false)
	check(app._room.caption.text.contains("over!") and app._collection_scroll.scroll_vertical == 0,
		"A stationary floor tap still calls Pip without scrolling")
	app._room.playground.cancel()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = floor
	root.push_input(wheel, true)
	await process_frame
	check(app._collection_scroll.scroll_vertical > 0, "Mouse wheel input reaches scrolling through the room canvas")
	check(app.medal_progress.counts.is_empty(), "Room gestures do not award progress")
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Room scrolling: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
