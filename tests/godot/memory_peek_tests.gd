extends SceneTree

const Data = preload("res://scripts/game_data.gd")
const Style = preload("res://scripts/ui_style.gd")

var checks := 0
var failures := 0
var words: Array = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 720)
	for word in JSON.parse_string(FileAccess.get_file_as_string("res://words.json")):
		if word.id in ["cat", "dog", "sun", "ball", "car"]:
			words.append(word)
	await _test_face_tween()
	var view = load("res://scripts/memory_garden.gd").new()
	check(view.has_method("begin_peek") and view.has_method("end_peek"), "Native Memory has explicit hold/release entry points")
	if view.has_method("begin_peek") and view.has_method("end_peek"):
		view.pause(true)
		view.end_peek()
		view.stop()
		check(view.memory.phase == "stopped" and not view._paused and view.controls().is_empty(),
			"Lifecycle cancellation is safe before the view enters the scene tree")
		root.add_child(view)
		view.size = Vector2(456, 400)
		await _test_hold_inputs(view)
		await _test_cancel_and_reverse(view)
		await _test_scaled_layout(view)
		view.queue_free()
		await process_frame
	else:
		view.free()
	await _test_external_toolbar()
	print("Memory peek: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_face_tween() -> void:
	var card = load("res://scripts/word_card.gd").new()
	check(card.has_method("set_face_up") and card.has_method("set_back"), "WordCard provides a content-only flip API")
	if not card.has_method("set_face_up") or not card.has_method("set_back"):
		card.free()
		return
	card.setup({"id": words[0].id + ":word", "kind": "word", "word": words[0]})
	root.add_child(card)
	card.position = Vector2(80, 80)
	card.size = Vector2(140, 100)
	var back := Label.new()
	back.text = "Word 1"
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_back(back)
	card.refresh(Data.theme("spring"), false, false, false, false)
	card.set_face_up(false, false)
	await process_frame
	await process_frame
	var bounds: Rect2 = card.get_global_rect()
	var front_bounds: Rect2 = card.word_label.get_rect()
	check(not card.word_label.visible and card.word_label.text.is_empty() and back.visible, "A settled back conceals the original noun")
	card.grab_focus()
	card.set_face_up(true)
	card._flip.pause()
	card._flip.custom_step(0.045)
	var face: Control = card.word_label.get_parent()
	check(face != card and face.scale.x > 0.0 and face.scale.x < 0.98,
		"The real visual face is partway through a native horizontal flip: scale=%s face=%s card=%s tween=%s elapsed=%s" % [
			face.scale, face.size, card.size, card._flip,
			card._flip.get_total_elapsed_time() if card._flip != null else -1.0])
	check(card.get_global_rect() == bounds and card.scale == Vector2.ONE and card.size == bounds.size,
		"The actual Button size, position, scale and hitbox remain unchanged mid-flip")
	check(card.has_focus() and card.get_theme_stylebox("focus").border_width_left > 0, "The stable Button retains its native focus ring")
	card._flip.play()
	await create_timer(0.25).timeout
	check(card.word_label.visible and card.word_label.text == words[0].text and not back.visible and face.scale == Vector2.ONE,
		"The flip restores the exact word at full face width")
	check(card.word_label.get_rect() == front_bounds, "Flipping preserves the original label geometry")
	card.set_face_up(false)
	await create_timer(0.04).timeout
	card.set_face_up(true)
	await create_timer(0.25).timeout
	check(card.face_up and card.word_label.visible and not back.visible and face.scale == Vector2.ONE, "A rapid reversal cannot be overwritten by the old tween")
	card.set_face_up(false)
	await create_timer(0.12).timeout
	card.set_face_up(true)
	card.set_face_up(false)
	await create_timer(0.25).timeout
	check(not card.face_up and not card.word_label.visible and back.visible and face.scale == Vector2.ONE, "Repeated reversals settle the latest requested back")
	card.set_face_up(true)
	card.size = Vector2(180, 120)
	await process_frame
	check(card.face_up and face.scale == Vector2.ONE and face.pivot_offset.is_equal_approx(face.size * 0.5), "Resize settles the requested face and recenters its visual pivot")
	card.set_face_up(false)
	card.set_reduced_motion(true)
	check(face.scale == Vector2.ONE and back.visible and card.word_label.text.is_empty(), "Reduced motion immediately settles and conceals a flipping front")
	card.set_face_up(true)
	check(face.scale == Vector2.ONE and card.word_label.visible, "Reduced-motion reveals are immediate")
	card.set_reduced_motion(false)
	card.set_face_up(false)
	card.hide()
	await create_timer(0.25).timeout
	card.show()
	check(face.scale == Vector2.ONE and back.visible and not card.word_label.visible, "A hidden card cancels its tween without replay on show")
	card.refresh(Data.theme("ocean"), false, true, false, true)
	check(back.visible and card.match_mark.visible and card.disabled, "A hidden matched card retains its independent progress badge")
	card.set_face_up(true)
	card.clear_feedback()
	check(face.scale == Vector2.ONE and card.word_label.visible and card.match_mark.visible, "Explicit cleanup settles the desired face and preserves matched marks")
	card.queue_free()
	await process_frame


func _test_hold_inputs(view) -> void:
	view.set_reduced_motion(true)
	view.start_round(words, Data.theme("spring"), 71)
	await process_frame
	var positions: Array = _rects(view)
	var board: Array = view.memory.cards.duplicate(true)
	view.study_button.button_down.emit()
	view.begin_peek()
	check(view.memory.studying and view.study_button.engaged and view.memory.attempts == 0, "Repeated button-down/hold activation is idempotent")
	view.study_button.pressed.emit()
	check(view.memory.studying, "Pressed does not toggle a held eye")
	view.study_button.button_up.emit()
	view.end_peek()
	check(_all_hidden(view) and not view.study_button.engaged, "Button-up and repeated release hide every front")
	view.study_button.pressed.emit()
	check(not view.memory.studying, "A pressed-only event cannot latch the eye")
	for key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		view.study_button.grab_focus()
		await _key(key, true)
		check(view.memory.studying and view.study_button.engaged, "Native key-down begins a hold: " + str(key))
		await _key(key, true, true)
		check(view.memory.studying, "Key repeat cannot toggle a held eye")
		await _key(key, false)
		check(_all_hidden(view) and not view.study_button.engaged, "Native key-up releases the eye: " + str(key))
	await _mouse(view.study_button.get_global_rect().get_center(), true)
	check(view.memory.studying, "Native mouse-down reveals before release")
	await _mouse(view.study_button.get_global_rect().get_center(), false)
	check(_all_hidden(view), "Native mouse-up reveals nothing persistently")
	await _mouse(view.study_button.get_global_rect().get_center(), true)
	var outside: Vector2 = view.get_global_rect().end + Vector2(30, 30)
	await _motion(outside, MOUSE_BUTTON_MASK_LEFT)
	check(not view.memory.studying, "Dragging a held mouse outside the eye cancels the peek")
	await _mouse(outside, false)
	await _mouse(view.study_button.get_global_rect().get_center(), true)
	await _mouse(outside, false, true)
	check(_all_hidden(view), "A cancelled mouse release outside the button cannot latch it")
	var center: Vector2 = view.study_button.get_global_rect().get_center()
	await _touch(4, center, true)
	check(view.memory.studying, "A native touch holds the eye")
	await _touch(5, center, true)
	await _touch(5, center, false)
	check(view.memory.studying, "Another finger cannot release the active held touch")
	await _touch(4, outside, false, true)
	check(_all_hidden(view), "Cancelling the owning touch hides every face")
	await _touch(6, center, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 6
	drag.position = outside
	root.push_input(drag, true)
	await process_frame
	check(_all_hidden(view), "Dragging the owning touch out cancels its peek")
	await _touch(6, outside, false)
	view.begin_peek()
	view.study_button.release_focus()
	check(_all_hidden(view), "Losing eye focus releases a held reveal")
	check(view.memory.cards == board and _rects(view) == positions and view.memory.attempts == 0 and view.memory.selected_indices.is_empty(),
		"All physical hold/cancel paths preserve identity, score and input geometry")


func _test_cancel_and_reverse(view) -> void:
	view.set_reduced_motion(false)
	view.start_round(words, Data.theme("spring"), 91)
	await process_frame
	await process_frame
	var positions: Array = _rects(view)
	view.begin_peek()
	for card in view.card_buttons:
		card._flip.pause()
		card._flip.custom_step(0.04)
	check(view.card_buttons.all(func(card: Button) -> bool: return card.word_label.get_parent().scale.x < 1.0),
		"All ten actual face containers animate together on hold")
	check(_rects(view) == positions and view.card_buttons.all(func(card: Button) -> bool: return card.scale == Vector2.ONE),
		"All ten Button targets stay fixed during simultaneous flips")
	for card in view.card_buttons:
		card._flip.play()
	view.end_peek()
	view.begin_peek()
	view.end_peek()
	await create_timer(0.3).timeout
	check(_all_hidden(view) and _all_settled(view), "Rapid hold/release/rehold settles all latest backs")
	for cancellation in ["pause", "hide", "focus", "stop", "restart"]:
		view.start_round(words, Data.theme("spring"), 91)
		view.begin_peek()
		await create_timer(0.04).timeout
		match cancellation:
			"pause": view.pause(true)
			"hide": view.hide()
			"focus": view.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			"stop": view.stop()
			"restart": view.start_round(words, Data.theme("spring"), 92)
		check(not view.memory.studying and _all_settled(view), cancellation + " immediately cancels held animations")
		await create_timer(0.3).timeout
		view.pause(false)
		view.show()
		view.end_peek()
		check(_all_hidden(view) and _all_settled(view) and view.memory.attempts == 0, cancellation + " cannot be undone by an old tween or late release")
	view.start_round(words, Data.theme("spring"), 91)
	view.begin_peek()
	view.size = Vector2(600, 360)
	await process_frame
	check(view.memory.studying and _all_settled(view), "Resizing a held board settles all requested fronts")
	view.end_peek()
	view.set_reduced_motion(true)
	check(_all_hidden(view) and _all_settled(view), "Reduced motion during release settles every back immediately")


func _test_scaled_layout(view) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(480, 720)
	root.size = Vector2i(320, 480)
	view.size = Vector2(456, 490)
	view.start_round(words, Data.theme("spring"), 71)
	await process_frame
	await process_frame
	var scale: float = Style.ui_scale(view)
	check(is_equal_approx(scale, 2.0 / 3.0), "The regression exercises the supported 320 CSS pixel startup scale")
	for control in view.card_buttons + [view.study_button]:
		check(control.size.x * scale >= 44 and control.size.y * scale >= 44, "Scaled Memory input targets stay at least 44 CSS pixels")
	check(is_equal_approx(view.study_button.size.x, ceilf(44 / scale)) and is_equal_approx(view.study_button.size.x, view.study_button.size.y),
		"The eye uses the shared CSS-scaled square target")
	check(is_equal_approx(view._board.position.y, ceilf(44 / scale)) and is_equal_approx(view._board.position.y + view._board.size.y, view.size.y),
		"The standalone scaled header contains only the 44 CSS pixel eye row")


func _test_external_toolbar() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(960, 720)
	var script = load("res://scripts/memory_garden.gd")
	var view = script.new()
	root.add_child(view)
	view.position = Vector2(12, 72)
	view.size = Vector2(456, 600)
	view.set_reduced_motion(true)
	view.start_round(words, Data.theme("spring"), 71)
	var toolbar := HBoxContainer.new()
	toolbar.position = Vector2(12, 8)
	toolbar.size = Vector2(740, 52)
	root.add_child(toolbar)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	var eye: Button = view.study_button
	eye.reparent(toolbar)
	Style.square_icon_button(eye, Data.theme("spring").accent)
	eye.custom_minimum_size = Vector2.ONE * 52
	await process_frame
	await process_frame
	var eye_bounds: Rect2 = eye.get_rect()
	var eye_minimum: Vector2 = eye.custom_minimum_size
	check(eye.get_parent() == toolbar and not view.get_global_rect().intersects(eye.get_global_rect()),
		"Root's real HBox owns an eye outside the Memory view")
	check(view._board.position == Vector2.ZERO and view._board.size == view.size,
		"Reparenting the eye immediately releases the entire board rectangle")
	check(not view.status_label.visible and view.find_child("FlowerProgress", true, false) == null and view.find_child("FlowerCount", true, false) == null,
		"External-toolbar Memory has no local heading, progress row or footer")
	for dimensions in [Vector2(456, 600), Vector2(456, 456), Vector2(600, 360), Vector2(456, 480)]:
		view.size = dimensions
		view.set_palette(Data.theme("ocean"))
		view.begin_peek()
		check(eye.get_rect() == eye_bounds and eye.custom_minimum_size == eye_minimum,
			"Memory refresh, palette and resize never write the external eye's assigned geometry")
		view.end_peek()
		await process_frame
		_check_external_grid(view)
	view.size = Vector2(456, 500)
	await _test_hold_inputs(view)
	var center: Vector2 = eye.get_global_rect().get_center()
	await _touch(8, center, true)
	view.set_palette(Data.theme("space"))
	view.size = Vector2(600, 420)
	check(view.memory.studying and view._peek_touch == 8 and eye.get_rect() == eye_bounds,
		"External touch capture survives board resize and palette refresh")
	await _touch(8, center, false)
	check(_all_hidden(view), "The original outside-view touch release still conceals all ten fronts")
	view.begin_peek()
	view.hide()
	check(not eye.visible and not view.memory.studying, "Hiding Memory also hides and releases its externally parented eye")
	view.show()
	check(eye.visible and not eye.disabled and _all_hidden(view), "Showing Memory restores only an unheld external eye")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(480, 720)
	root.size = Vector2i(320, 480)
	toolbar.size = Vector2(456, 66)
	view.size = Vector2(456, 600)
	Style.square_icon_button(eye, Data.theme("spring").accent)
	view._layout()
	await process_frame
	await process_frame
	check(is_equal_approx(Style.ui_scale(view), 2.0 / 3.0) and eye.size.x * Style.ui_scale(view) >= 44
		and eye.size.y * Style.ui_scale(view) >= 44, "The real external toolbar supports a 44 CSS pixel eye at 320 CSS width")
	_check_external_grid(view)
	center = eye.get_global_rect().get_center()
	await _touch(9, center, true)
	check(view.memory.studying and view._peek_touch == 9, "Parent-first teardown begins with a real captured external touch")
	toolbar.queue_free()
	await process_frame
	await process_frame
	check(not is_instance_valid(view.study_button), "The regression frees the external toolbar before Memory")
	view.end_peek()
	view.pause(true)
	view.pause(false)
	view.set_palette(Data.theme("spring"))
	view._layout()
	view.begin_peek()
	view.hide()
	view.show()
	await _mouse(Vector2(900, 690), false, true)
	view.stop()
	check(not view.memory.studying and view.memory.phase == "stopped" and view.controls().is_empty(),
		"Parent-first teardown safely rejects stale native input and lifecycle callbacks")
	view.queue_free()
	await process_frame
	var other = script.new()
	root.add_child(other)
	other.size = Vector2(456, 400)
	other.start_round(words, Data.theme("spring"), 71)
	var other_toolbar := HBoxContainer.new()
	root.add_child(other_toolbar)
	var remaining_eye: Button = other.study_button
	remaining_eye.reparent(other_toolbar)
	other.queue_free()
	await process_frame
	remaining_eye.button_down.emit()
	remaining_eye.button_up.emit()
	check(remaining_eye.get_signal_connection_list("button_down").is_empty(),
		"Memory-first teardown disconnects its externally owned native handlers")
	other_toolbar.queue_free()
	await process_frame


func _check_external_grid(view) -> void:
	var gap: float = ceilf(8 / Style.ui_scale(view))
	var columns: int = 2 if view.size.x < view.size.y else 5
	var rows: int = 10 / columns
	var cell := Vector2((view.size.x - gap * (columns - 1)) / columns, (view.size.y - gap * (rows - 1)) / rows)
	check(view._board.position == Vector2.ZERO and view._board.size == view.size, "External-toolbar cards fill the whole view with no reserved header or footer")
	for index in range(10):
		var expected := Vector2((index % columns) * (cell.x + gap), (index / columns) * (cell.y + gap))
		var card: Button = view.card_buttons[index]
		check(card.position.is_equal_approx(expected) and card.size.is_equal_approx(cell),
			"External-toolbar cards fill every uniform %dx%d cell at %s" % [columns, rows, view.size])
		check(card.size.x * Style.ui_scale(view) >= 44 and card.size.y * Style.ui_scale(view) >= 44,
			"Regular external-toolbar cells preserve 44 CSS pixel targets")


func _all_hidden(view) -> bool:
	for index in range(view.card_buttons.size()):
		var card = view.card_buttons[index]
		if view.memory.is_revealed(index) or card.picture.visible or card.word_label.visible or not card.word_label.text.is_empty():
			return false
	return not view.memory.studying


func _all_settled(view) -> bool:
	return view.card_buttons.all(func(card: Button) -> bool: return card.word_label.get_parent().scale == Vector2.ONE and card.scale == Vector2.ONE)


func _rects(view) -> Array:
	return view.card_buttons.map(func(card: Button) -> Rect2: return card.get_global_rect())


func _key(code: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	root.push_input(event, true)
	await process_frame


func _mouse(point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)
	await process_frame


func _motion(point: Vector2, mask: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = mask
	root.push_input(event, true)
	await process_frame


func _touch(index: int, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)
	await process_frame
