extends Control

signal interaction(kind: String, message: String)
signal interaction_started
signal toy_tapped

var duck_position := Vector2.ZERO
var target_position := Vector2.ZERO
var motion_kind := ""
var interaction_kind := ""
var flight_active := false
var toy_phase := "idle"
var interaction_allowed: Callable
var reduced_motion := false
var toy_word := "ball"
var toy_locked := false
var accent := Color("#438363")

var _slot: Control
var _toy: Button
var _label: Label
var _duck: Button
var _home := Vector2.ZERO
var _toy_home := Vector2.ZERO
var _pointer := -1
var _gesture := ""
var _press := Vector2.ZERO
var _last := Vector2.ZERO
var _travel := 0.0
var _flight_start := Vector2.ZERO
var _flight_end := Vector2.ZERO
var _elapsed := 0.0
var _duration := 0.7
var _initialized := false
var _paused := false
var _pet_count := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree(): cancel())


func setup(slot: Control, toy: Button, label: Label) -> void:
	_slot = slot
	_toy = toy
	_label = label


func set_duck(duck: Button) -> void:
	_duck = duck


func layout_room(dimensions: Vector2) -> void:
	if _slot == null:
		return
	var changed := size != dimensions
	size = dimensions
	_slot.size = Vector2(96, 112)
	_home = _clamp_floor(Vector2(88, size.y - 32))
	_toy.size = Vector2(64, 64)
	_toy.pivot_offset = _toy.size * 0.5
	if changed or not _initialized:
		_toy_home = Vector2(size.x - 66, size.y - 74)
	_label.size = Vector2(96, 26)
	if not _initialized:
		duck_position = _home
		target_position = _home
		_initialized = true
	duck_position = _clamp_floor(duck_position)
	target_position = _clamp_floor(target_position)
	if changed:
		cancel()
	_place_duck()
	if toy_phase == "idle":
		_clear_toy_space()
		_place_toy(_toy_home)


func configure(word: String, locked: bool, motion_reduced: bool, color: Color) -> void:
	if word != toy_word or locked != toy_locked or reduced_motion != motion_reduced:
		cancel()
	toy_word = word
	toy_locked = locked
	reduced_motion = motion_reduced
	accent = color
	queue_redraw()


func _allowed() -> bool:
	return _initialized and not _paused and is_visible_in_tree() and (not interaction_allowed.is_valid() or bool(interaction_allowed.call()))


func _clamp_floor(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, 52, maxf(52, size.x - 52)), clampf(point.y, size.y * 0.57 + 38, size.y - 12))


func _clamp_toy(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, 34, maxf(34, size.x - 34)), clampf(point.y, 68, size.y - 36))


func _place_duck() -> void:
	_slot.position = duck_position - Vector2(_slot.size.x * 0.5, _slot.size.y)


func _clear_toy_space() -> bool:
	if not Rect2(_slot.position, _slot.size).grow(8).intersects(Rect2(_toy_home - _toy.size * 0.5, _toy.size)):
		return false
	_toy_home.x = size.x - 66 if duck_position.x < size.x * 0.5 else 66
	return true


func _place_toy(center: Vector2) -> void:
	_toy.z_index = 90 if toy_phase != "idle" else 0
	_label.z_index = _toy.z_index
	_toy.position = center - _toy.size * 0.5
	_label.position = Vector2(clampf(center.x - 48, 4, maxf(4, size.x - 100)), minf(center.y + 33, size.y - 27))


func _react(kind: String) -> void:
	if is_instance_valid(_duck):
		_duck.react_in_room(kind)


func _report(kind: String, message: String) -> void:
	interaction_kind = kind
	interaction.emit(kind, message)


func _begin_action() -> void:
	cancel()
	interaction_started.emit()


func pet() -> void:
	if not _allowed(): return
	_begin_action()
	_pet_count += 1
	_react("pet")
	_report("pet", ["Pip leans into your hand. Lovely!", "Soft strokes. Pip feels loved!", "More cuddles! Pip loves your gentle hand."][(_pet_count - 1) % 3])


func poke() -> void:
	if not _allowed(): return
	_begin_action()
	_react("poke")
	_report("poke", "Quack! You tickled Pip!")


func call_pip() -> void:
	if not _allowed(): return
	_begin_action()
	var point := _home if duck_position.distance_to(_home) > 36 else Vector2(size.x - 68, size.y - 24)
	_move_to(point)
	_report("call", "Come here, Pip! Tap the floor to choose where Pip goes.")


func _move_to(point: Vector2) -> void:
	target_position = _clamp_floor(point)
	var distance := duck_position.distance_to(target_position)
	motion_kind = "walk" if distance < 120 else "run"
	if reduced_motion or distance < 1:
		duck_position = target_position
		motion_kind = ""
		_place_duck()
		if toy_phase == "idle" and _clear_toy_space(): _place_toy(_toy_home)
	if is_instance_valid(_duck):
		_duck.set_room_motion(motion_kind, signf(target_position.x - duck_position.x))
	set_process(not motion_kind.is_empty() or toy_phase != "idle")
	queue_redraw()


func toss_to_pip() -> void:
	if not _allowed() or toy_locked: return
	_begin_action()
	_launch(_toy_home, duck_position - Vector2(0, 56))


func _launch(start: Vector2, end: Vector2) -> void:
	_flight_start = _clamp_toy(start)
	_flight_end = _clamp_toy(end)
	_elapsed = 0
	_duration = clampf(start.distance_to(end) / 320.0, 0.55, 0.9)
	toy_phase = "flying"
	flight_active = true
	_report("throw", "Here comes the %s, Pip!" % toy_word)
	if reduced_motion:
		duck_position = _clamp_floor(_flight_end + Vector2(0, 56))
		_place_duck()
		_caught("catch")
		_rest_toy()
	else:
		set_process(true)
	queue_redraw()


func _caught(kind: String) -> void:
	flight_active = false
	motion_kind = ""
	toy_phase = "caught"
	_elapsed = 0
	_react("catch")
	var extra: String = {"ball": "Again? Toss it back!", "flower": "A flower for a friend.", "apple": "Crunch! A tasty apple.", "bell": "Ding! The bell rings.", "shell": "Shh! Listen to the waves.", "rocket": "Whoosh! Ready for another flight."}.get(toy_word, "Let's play again!")
	_report(kind, "Pip %s the %s! %s" % ["caught" if kind == "catch" else "fetched", toy_word, extra])


func _rest_toy() -> void:
	toy_phase = "idle"
	flight_active = false
	_toy.rotation = 0
	_toy.scale = Vector2.ONE
	_clear_toy_space()
	_place_toy(_toy_home)
	set_process(not motion_kind.is_empty())
	queue_redraw()


func cancel() -> void:
	_pointer = -1
	_gesture = ""
	motion_kind = ""
	interaction_kind = ""
	target_position = duck_position
	if _toy != null: _rest_toy()
	if is_instance_valid(_duck): _duck.clear_room_interaction()
	set_process(false)
	queue_redraw()


func pause(value: bool) -> void:
	_paused = value
	if value: cancel()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		pause(true)
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		pause(false)


func _point_visible(point: Vector2) -> bool:
	if not get_global_rect().has_point(point): return false
	var ancestor := get_parent()
	while ancestor is Control:
		if ancestor.clip_contents and not ancestor.get_global_rect().has_point(point): return false
		ancestor = ancestor.get_parent()
	return true


func _input(event: InputEvent) -> void:
	if not _allowed(): return
	var pointer := -2
	var pressed := false
	var released := false
	var moving := false
	var point := Vector2.ZERO
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		# Touch is handled directly; its synthetic mouse must not also click a Button.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			if _pointer >= 0 or _point_visible(event.position): get_viewport().set_input_as_handled()
			return
		point = event.position
		if event is InputEventMouseButton:
			if event.button_index != MOUSE_BUTTON_LEFT: return
			pressed = event.pressed
			released = not pressed
		else:
			moving = true
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		pointer = event.index
		point = event.position
		if event is InputEventScreenTouch:
			if event.canceled:
				if pointer == _pointer:
					cancel()
					get_viewport().set_input_as_handled()
				return
			pressed = event.pressed
			released = not pressed
		else:
			moving = true
	else:
		return
	var local := get_global_transform().affine_inverse() * point
	if pressed and _pointer == -1 and _point_visible(point):
		var on_toy := _toy.get_global_rect().has_point(point)
		var on_duck := _slot.get_global_rect().has_point(point)
		if on_toy and _toy.z_index > 0: on_duck = false
		get_viewport().set_input_as_handled()
		if on_toy and not on_duck and toy_locked: return
		if on_toy and not on_duck:
			if toy_phase != "idle" or not motion_kind.is_empty(): cancel()
		else:
			_begin_action()
		_pointer = pointer
		# Pip draws above the toy; the visible front object owns overlapping hits.
		_gesture = "duck" if on_duck else "toy" if on_toy else "floor"
		_press = local
		_last = local
		_travel = 0
	elif pointer == _pointer:
		get_viewport().set_input_as_handled()
		if moving:
			_travel += local.distance_to(_last)
			_last = local
			if _gesture == "toy" and _travel > 8:
				if toy_phase != "drag": interaction_started.emit()
				toy_phase = "drag"
				_place_toy(_clamp_toy(local))
				queue_redraw()
			elif _gesture == "duck" and _travel > 18:
				_react("pet")
		elif released:
			var gesture := _gesture
			_pointer = -1
			_gesture = ""
			if not _point_visible(point):
				cancel()
				return
			if gesture == "duck":
				if _travel > 18: pet()
				else: poke()
			elif gesture == "toy":
				if _travel > 8: _launch(_clamp_toy(local), local + (local - _press) * 0.35)
				else: toy_tapped.emit()
			elif _travel < 12:
				_move_to(local)
				_report(motion_kind if not motion_kind.is_empty() else "walk", "Pip %s over!" % ("runs" if motion_kind == "run" else "walks"))


func _process(delta: float) -> void:
	if not _allowed():
		cancel()
		return
	if not motion_kind.is_empty():
		duck_position = duck_position.move_toward(target_position, delta * (230 if motion_kind == "run" else 110))
		_place_duck()
		if duck_position.distance_to(target_position) < 0.5:
			motion_kind = ""
			if is_instance_valid(_duck): _duck.set_room_motion("")
			if toy_phase == "fetch": _caught("fetch")
			elif toy_phase == "idle" and _clear_toy_space():
				toy_phase = "returning"
				_flight_start = _toy.position + _toy.size * 0.5
				_elapsed = 0
	_elapsed += delta
	if toy_phase == "flying":
		var progress := minf(1, _elapsed / _duration)
		_place_toy(_flight_start.lerp(_flight_end, progress) - Vector2(0, sin(progress * PI) * 48))
		_toy.rotation = sin(progress * PI) * (1.8 if toy_word == "ball" else 0.3)
		if progress >= 1:
			flight_active = false
			if (duck_position - Vector2(0, 56)).distance_to(_flight_end) < 78:
				_caught("catch")
			else:
				toy_phase = "fetch"
				_move_to(_flight_end + Vector2(0, 48))
				_report("chase", "Go get the %s, Pip!" % toy_word)
				if motion_kind.is_empty(): _caught("fetch")
	elif toy_phase == "caught":
		_place_toy(duck_position - Vector2(0, 40))
		if _elapsed > 0.5:
			toy_phase = "returning"
			_flight_start = _toy.position + _toy.size * 0.5
			_elapsed = 0
	elif toy_phase == "returning":
		var progress := minf(1, _elapsed / 0.55)
		_place_toy(_flight_start.lerp(_toy_home, progress) - Vector2(0, sin(progress * PI) * 22))
		if progress >= 1: _rest_toy()
	if motion_kind.is_empty() and toy_phase == "idle": set_process(false)
	queue_redraw()


func _draw() -> void:
	if not motion_kind.is_empty():
		draw_arc(target_position - Vector2(0, 3), 13, 0, TAU, 24, accent, 2, true)
		draw_circle(target_position - Vector2(0, 3), 3, accent)
	if toy_phase == "drag":
		var start := _toy.position + _toy.size * 0.5
		var end := _clamp_toy(_last + (_last - _press) * 0.35)
		for index in range(1, 8):
			draw_circle(start.lerp(end, index / 8.0), 2.5, accent)
		draw_arc(end, 10, 0, TAU, 20, accent, 2, true)
	elif toy_phase == "flying":
		var progress := minf(1, _elapsed / _duration)
		var shadow := _flight_start.lerp(_flight_end, progress) + Vector2(0, 34)
		draw_set_transform(shadow, 0, Vector2(1, 0.3))
		draw_circle(Vector2.ZERO, 19, Color(accent, 0.18))
		draw_set_transform(Vector2.ZERO)
