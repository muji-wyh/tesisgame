extends SceneTree

var checks := 0
var failures := 0
var interactions: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(480, 900)
	var directory := "user://pip-playground-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.medal_progress = load("res://scripts/medal_progress.gd").new(directory + "/medals.cfg", directory + "/legacy.cfg")
	app.playroom_save_path = directory + "/playroom.cfg"
	root.add_child(app)
	await _settle()
	app.audio.set_muted(true)
	app.set_reduced_motion(false)
	app._show_collection()
	await _show_stage(app)
	var room = app._room
	var stage: Control = room._room
	var before_position: Vector2 = room.duck_slot.position
	var floor_point: Vector2 = stage.get_global_rect().end - Vector2(28, 12)
	await _tap(floor_point)
	await create_timer(0.2).timeout
	check(room.duck_slot.position.distance_to(before_position) > 2.0, "A real empty-floor tap actually moves Pip from the resting spot")
	var available: bool = room.get_property_list().any(func(property: Dictionary) -> bool: return property.name == "playground")
	check(available, "Pip's room exposes its direct-interaction playground")
	if not available:
		await _finish(app, directory)
		return
	var playground = room.playground
	check(playground != null and playground.has_signal("interaction"), "The playground reports visible interaction outcomes")
	if playground == null or not playground.has_signal("interaction"):
		await _finish(app, directory)
		return
	playground.interaction.connect(func(kind: String, _message: String) -> void: interactions.append(kind))
	await _advance(playground, 4.0)
	var saved: Dictionary = _saved_files(directory)
	var score: Array = _progress(app)
	await _check_duck_gestures(app, playground)
	await _check_legacy_toy_sequences(app, playground)
	await _check_floor_movement(app, playground)
	await _check_throwing(app, playground)
	await _check_fetch_at_floor_edge(app, playground)
	await _check_locked_toy(app, playground)
	await _check_canceled_touch(app, playground)
	await _check_interruption(app, playground)
	check(_progress(app) == score, "Petting, poking, moving and throwing cannot alter the lesson, medals or saved room choices")
	check(_saved_files(directory) == saved, "Direct Pip interactions never write position, affection or toy motion into any save")
	await _finish(app, directory)


func _check_duck_gestures(app, playground) -> void:
	for method in ["mouse", "touch"]:
		playground.cancel()
		await _show_stage(app)
		var scroll_before: int = app._collection_scroll.scroll_vertical
		var before := interactions.size()
		var point: Vector2 = app.duck.get_global_rect().get_center()
		var hit_context := _hit_context(app, playground, point)
		await _tap(point, method)
		check(playground.interaction_kind == "poke" and interactions.slice(before) == ["poke"], method + " light tap pokes Pip exactly once: kind=%s events=%s; %s" % [playground.interaction_kind, interactions.slice(before), hit_context])
		var poke_caption: String = app._room.caption.text
		before = interactions.size()
		var center: Vector2 = app.duck.get_global_rect().get_center()
		hit_context = _hit_context(app, playground, center - Vector2(22, 0))
		await _drag(center - Vector2(22, 0), center + Vector2(26, 0), method)
		check(playground.interaction_kind == "pet" and interactions.slice(before) == ["pet"], method + " stroke pets Pip once without a release poke or duplicate emulated-mouse action: kind=%s events=%s; %s" % [playground.interaction_kind, interactions.slice(before), hit_context])
		check(app._room.caption.text != poke_caption, method + " stroking and poking give distinguishable visible feedback")
		check(app._collection_scroll.scroll_vertical == scroll_before and not app._collection_dragging, method + " Pip gestures belong to the playground without scrolling the reward list")


func _check_legacy_toy_sequences(app, playground) -> void:
	await _show_stage(app)
	var room = app._room
	var scene: Control = room._room
	var toy: Control = room.toy_button
	await _tap(playground.get_global_transform() * Vector2(12, playground.size.y - 12))
	await _advance(playground, 4.0)
	var old_home: Vector2 = _render_rect(toy, scene).get_center()
	await _tap(playground.get_global_transform() * Vector2(playground.size.x - 12, playground.size.y - 12))
	await _advance(playground, 4.0)
	var home: Vector2 = _render_rect(toy, scene).get_center()
	check(old_home.x > scene.size.x * 0.5 and home.x < scene.size.x * 0.5 and playground.duck_position.x > scene.size.x * 0.5, "Real floor taps move Pip right and relocate the resting ball from the right to the left")
	var previous := 0
	for expected in [1, 2, 3, 0]:
		var center: Vector2 = toy.get_global_transform() * (toy.size * 0.5)
		await _button(center, true)
		check(room._stage == previous, "Toy pointer-down preserves the current sequence stage %d" % previous)
		await _button(center, false)
		check(room._stage == expected, "Real toy clicks advance through 1, 2, 3 and reset to 0: expected %d, got %d" % [expected, room._stage])
		await _advance(room, 1.0)
		previous = expected
	check(_render_rect(toy, scene).get_center().distance_to(home) < 1.0, "The fourth toy click restores the current left home")
	for expected in [1, 2, 3]:
		app._collection_scroll.ensure_control_visible(room.action_button)
		await _settle()
		await _tap(room.action_button.get_global_rect().get_center())
		check(room._stage == expected, "The real action button advances the ball sequence to stage %d" % expected)
		var stayed_on_left := true
		var stayed_inside := true
		for step in range(20):
			await _advance(room, 0.05)
			var visual := _render_rect(toy, scene)
			stayed_on_left = stayed_on_left and visual.get_center().x < scene.size.x * 0.5 and visual.get_center().x >= home.x - 1.0
			stayed_inside = stayed_inside and Rect2(Vector2.ZERO, scene.size).grow(1.0).encloses(visual) and Rect2(Vector2.ZERO, scene.size).grow(1.0).encloses(_render_rect(room._toy_label, scene))
		check(stayed_on_left, "Ball stage %d animates from its current left home without snapping to the old right home or moving away from Pip" % expected)
		check(stayed_inside, "Ball stage %d keeps its actual rotated render rectangle and word label inside the room" % expected)
		var final_center := _render_rect(toy, scene).get_center()
		check(absf(final_center.x - home.x) < 1.0 if expected == 2 else final_center.x > home.x + 10.0, "Ball stage %d visibly returns home or travels toward Pip on the right" % expected)
	await _tap(room.action_button.get_global_rect().get_center())
	await _settle()
	check(room._stage == 0 and _render_rect(toy, scene).get_center().distance_to(home) < 1.0, "Play again resets the legacy action at the current left home")
	await _show_stage(app)


func _render_rect(control: Control, parent: Control) -> Rect2:
	var transform := parent.get_global_transform().affine_inverse() * control.get_global_transform()
	var bounds := Rect2(transform * Vector2.ZERO, Vector2.ZERO)
	for corner in [Vector2(control.size.x, 0), control.size, Vector2(0, control.size.y)]:
		bounds = bounds.expand(transform * corner)
	return bounds


func _check_floor_movement(app, playground) -> void:
	for distance in ["near", "far"]:
		playground.cancel()
		await _show_stage(app)
		var start: Vector2 = playground.duck_position
		var direction := 1.0 if start.x < playground.size.x * 0.5 else -1.0
		var x: float = start.x + direction * (app.duck.size.x * 0.5 + 14.0) if distance == "near" else playground.size.x - 36.0 if direction > 0 else 36.0
		var point := Vector2(x, playground.size.y - 12.0)
		await _tap(playground.get_global_transform() * point)
		var target: Vector2 = playground.target_position
		check(playground.motion_kind == ("walk" if distance == "near" else "run"), "An empty-floor " + distance + " tap chooses an appropriate walk or run")
		await _advance(playground, 0.15)
		check(playground.duck_position.distance_to(start) > 1.0, "Pip visibly travels toward the " + distance + " floor target")
		await _advance(playground, 4.0)
		check(playground.duck_position.distance_to(target) < 1.0 and playground.motion_kind.is_empty(), "Pip reaches the " + distance + " target and stops without drifting")
		_check_room_bounds(app, distance + " movement")
	playground.call_pip()
	check(not playground.motion_kind.is_empty(), "The accessible Call Pip action starts a real movement")
	await _advance(playground, 4.0)
	_check_room_bounds(app, "Call Pip")


func _check_throwing(app, playground) -> void:
	playground.cancel()
	await _show_stage(app)
	var before := interactions.size()
	var toy_center: Vector2 = app._room.toy_button.get_global_rect().get_center()
	var duck_center: Vector2 = app.duck.get_global_rect().get_center()
	await _drag(toy_center, toy_center.lerp(duck_center, 0.65))
	check(playground.flight_active and playground.toy_phase == "flying", "Dragging and releasing the ball launches a real flight")
	check(interactions.slice(before).count("throw") == 1, "A real ball drag produces one throw without also activating the old toy button")
	await _advance(playground, 8.0)
	var outcomes: Array = interactions.slice(before)
	check(outcomes.has("catch") or outcomes.has("fetch"), "Pip catches the thrown ball or runs over to retrieve it")
	check(not playground.flight_active and playground.toy_phase == "idle", "A completed throw returns the ball to a reusable resting state")
	check(app._room.caption.text.contains("ball"), "The throw outcome keeps the visible ball-word association")
	_check_room_bounds(app, "mouse throw")
	before = interactions.size()
	playground.toss_to_pip()
	check(playground.flight_active, "The accessible Toss action also launches a real ball")
	await _advance(playground, 8.0)
	check(interactions.slice(before).count("catch") == 1 and app._room.caption.text.contains("Pip caught the ball!"), "An aimed accessible toss reaches Pip and reports one actual catch")
	check(playground.toy_phase == "idle", "Pip returns an aimed toss to the resting toy")
	before = interactions.size()
	toy_center = app._room.toy_button.get_global_rect().get_center()
	var far_side: float = playground.size.x - 20.0 if playground.duck_position.x < playground.size.x * 0.5 else 20.0
	var away: Vector2 = playground.get_global_transform() * Vector2(far_side, playground.size.y - 24.0)
	await _drag(toy_center, away, "touch")
	check(playground.flight_active and interactions.slice(before).count("throw") == 1, "A touch throw launches once despite mouse emulation")
	await _advance(playground, 8.0)
	check(interactions.slice(before).has("fetch") and app._room.caption.text.contains("Pip fetched the ball!"), "A ball thrown away from Pip is chased and fetched")
	check(playground.toy_phase == "idle" and not playground.flight_active, "The fetched ball returns and can be thrown again")
	_check_room_bounds(app, "touch fetch")


func _check_fetch_at_floor_edge(app, playground) -> void:
	playground.cancel()
	await _show_stage(app)
	var upper_corner: Vector2 = playground.get_global_transform() * Vector2(12, 50)
	await _tap(upper_corner)
	await _advance(playground, 4.0)
	var edge_position: Vector2 = playground.duck_position
	var before := interactions.size()
	await _drag(app._room.toy_button.get_global_rect().get_center(), upper_corner)
	check(playground.flight_active, "A real throw toward the upper room edge starts a flight above Pip")
	await _advance(playground, 8.0)
	check(playground.duck_position.distance_to(edge_position) < 0.5 and playground.target_position.distance_to(edge_position) < 0.5, "The upper-edge throw exercises a fetch whose clamped target is already Pip's current position")
	check(interactions.slice(before).count("chase") == 1 and interactions.slice(before).count("fetch") == 1, "An already-reached fetch target still produces one completed retrieval")
	check(playground.toy_phase == "idle" and not playground.flight_active and not playground.is_processing() and app._room.caption.text.contains("Pip fetched the ball!"), "A zero-distance fetch returns the ball instead of leaving it stuck in the chase state")
	_check_room_bounds(app, "upper-edge fetch")


func _check_locked_toy(app, playground) -> void:
	playground.cancel()
	app._room.item_buttons["toy-summer"].pressed.emit()
	await _show_stage(app)
	check(app._room._preview_locked and app._room.toy_button.disabled, "The unearned Summer ball is a locked preview")
	var before := interactions.size()
	playground.toss_to_pip()
	var center: Vector2 = app._room.toy_button.get_global_rect().get_center()
	await _drag(center, center - Vector2(70, 20))
	check(not playground.flight_active and playground.toy_phase == "idle" and interactions.size() == before, "Neither the accessible action nor a real drag can throw a locked toy")
	check(app.playroom_state.toy_id == "toy-ball", "Playing with a locked preview cannot equip it")
	app._room.action_button.pressed.emit()
	await _show_stage(app)
	playground.toss_to_pip()
	check(playground.flight_active, "Returning from a locked preview immediately restores the owned ball")
	playground.cancel()


func _check_canceled_touch(app, playground) -> void:
	for held in ["toy", "duck"]:
		playground.cancel()
		await _show_stage(app)
		var control: Control = app._room.toy_button if held == "toy" else app.duck
		var point: Vector2 = control.get_global_rect().get_center()
		var before := interactions.size()
		await _button(point, true, "touch")
		if held == "toy":
			point += Vector2(-30, -20)
			await _motion(point, Vector2(-30, -20), "touch")
			check(playground.toy_phase == "drag", "A real touch holds the toy before a system cancellation")
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = false
		event.canceled = true
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
		await _button(point, false, "touch")
		check(interactions.size() == before and playground.toy_phase == "idle" and not playground.flight_active and playground.motion_kind.is_empty(), "A canceled " + held + " touch and late release cannot settle as a throw or poke")
	await _tap(app.duck.get_global_rect().get_center(), "touch")
	check(playground.interaction_kind == "poke", "A fresh touch works immediately after a system cancellation")
	playground.cancel()


func _check_interruption(app, playground) -> void:
	await _show_stage(app)
	var center: Vector2 = app._room.toy_button.get_global_rect().get_center()
	await _button(center, true)
	await _motion(center + Vector2(-35, -20), Vector2(-35, -20))
	check(playground.toy_phase == "drag", "A held real pointer picks up the ball before release")
	app._hide_collection()
	await _button(center + Vector2(-35, -20), false)
	check(not playground.flight_active and playground.toy_phase == "idle" and playground.motion_kind.is_empty(), "Leaving Rewards cancels a held toy and ignores its late release")
	var before := interactions.size()
	playground.pet()
	playground.poke()
	playground.call_pip()
	playground.toss_to_pip()
	check(interactions.size() == before and not playground.flight_active and playground.motion_kind.is_empty(), "A hidden playground rejects synthetic interaction actions")
	await _settle()
	check(app.duck.get_parent() == app and root.get_visible_rect().encloses(app.duck.get_global_rect()), "Leaving Rewards restores the shared Pip to the game header")
	app._show_collection()
	await _show_stage(app)
	playground.toss_to_pip()
	app.on_page_hidden()
	check(not playground.flight_active and playground.toy_phase == "idle" and playground.motion_kind.is_empty(), "Backgrounding cancels an active flight without a delayed catch")
	app.on_page_visible()
	await _show_stage(app)
	playground.toss_to_pip()
	root.size = Vector2i(320, 680)
	await _settle()
	await _advance(playground, 8.0)
	_check_room_bounds(app, "resize during a throw")
	check(playground.toy_phase == "idle", "Resizing during a throw leaves a recoverable resting ball")
	app.set_reduced_motion(true)
	playground.toss_to_pip()
	await _advance(playground, 8.0)
	check(not playground.flight_active and playground.toy_phase == "idle" and not playground.is_processing(), "Reduced motion leaves a stable usable result without a running animation loop")
	playground.pet()
	check(playground.interaction_kind == "pet", "Reduced motion still gives direct petting feedback")
	app.set_reduced_motion(false)
	playground.toss_to_pip()
	check(playground.flight_active, "Normal ball play resumes after reduced motion is switched off")
	playground.cancel()


func _check_room_bounds(app, label: String) -> void:
	var bounds: Rect2 = app._room._room.get_global_rect().grow(1.0)
	check(bounds.encloses(app.duck.get_global_rect()), label + " keeps Pip inside the room")
	check(bounds.encloses(app._room.toy_button.get_global_rect()), label + " keeps the resting toy inside the room")


func _hit_context(app, playground, point: Vector2) -> String:
	var duck_rect: Rect2 = app.duck.get_global_rect()
	var toy_rect: Rect2 = app._room.toy_button.get_global_rect()
	return "point=%s duck=%s slot=%s toy=%s on_duck=%s on_toy=%s duck_feet=%s toy_phase=%s" % [point, duck_rect, app._room.duck_slot.get_global_rect(), toy_rect, duck_rect.has_point(point), toy_rect.has_point(point), playground.duck_position, playground.toy_phase]


func _progress(app) -> Array:
	var state = app.playroom_state
	return [app.model.phase, app.model.successes, app.model.mistakes, app.model.lesson_words.duplicate(true), app.medal_progress.counts.duplicate(true), state.toy_id, state.backdrop_id, state.favorite_id, state.goal_item_id, state.recent_topic_ids.duplicate(), state.collected_word_ids.duplicate(), state.displayed_word_id]


func _saved_files(directory: String) -> Dictionary:
	var result: Dictionary = {}
	for filename in DirAccess.get_files_at(directory):
		result[filename] = FileAccess.get_file_as_bytes(directory + "/" + filename)
	return result


func _show_stage(app) -> void:
	app._collection_scroll.scroll_vertical = 0
	await _settle()
	app._update_duck()


func _advance(playground, seconds: float) -> void:
	for step in range(ceili(seconds / 0.05)):
		if playground.is_processing():
			playground._process(0.05)
		await process_frame


func _settle() -> void:
	await process_frame
	await process_frame


func _tap(position: Vector2, method: String = "mouse") -> void:
	await _button(position, true, method)
	await _button(position, false, method)


func _drag(start: Vector2, end: Vector2, method: String = "mouse") -> void:
	await _button(start, true, method)
	var previous := start
	for step in range(1, 5):
		var point: Vector2 = start.lerp(end, float(step) / 4.0)
		await _motion(point, point - previous, method)
		previous = point
	await _button(end, false, method)


func _button(position: Vector2, pressed: bool, method: String = "mouse") -> void:
	if method == "touch":
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = position
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	else:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame


func _motion(position: Vector2, relative: Vector2, method: String = "mouse") -> void:
	if method == "touch":
		var event := InputEventScreenDrag.new()
		event.index = 0
		event.position = position
		event.relative = relative
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	else:
		var event := InputEventMouseMotion.new()
		event.position = position
		event.global_position = position
		event.relative = relative
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(event, true)
	await process_frame


func _finish(app, directory: String) -> void:
	app.audio.halt()
	app.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory + "/" + filename)
	DirAccess.remove_absolute(directory)
	print("Pip playground: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
