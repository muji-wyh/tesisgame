extends Control

signal interaction(kind: String, message: String)
signal interaction_started
signal toy_tapped

const LoadingMoves = preload("res://scripts/pip_loading_moves.gd")
const Interior = preload("res://scripts/room_interior.gd")

var duck_position := Vector2.ZERO
var target_position := Vector2.ZERO
var motion_kind := ""
var interaction_kind := ""
var flight_active := false
var toy_phase := "idle"
var interaction_allowed: Callable
var pip_audio_busy: Callable
var reduced_motion := false
var toy_word := "ball"
var toy_locked := false
var toy_targets: Dictionary = {}
var active_toy_id := ""
var activate_toy: Callable
var accent := Color("#438363")
var toy_size: float = 64.0
var toy_label_width: float = 96.0

var _slot: Control
var _toy: Button
var _label: Label
var _duck: Button
var _home := Vector2.ZERO
var _toy_home := Vector2.ZERO
var _fixed_toy_home := false
var _crowded := false
var _pointer := -1
var _gesture := ""
var _press := Vector2.ZERO
var _last := Vector2.ZERO
var _last_screen := Vector2.ZERO
var _floor_tap_allowed := true
var _travel := 0.0
var _flight_start := Vector2.ZERO
var _flight_end := Vector2.ZERO
var _elapsed := 0.0
var _duration := 0.7
var _initialized := false
var _paused := false
var _pet_count := 0
var _poke_bag: Array[String] = []
var _previous_poke := ""


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
	var duck_scale: float = minf(1, maxf(0.25, size.y / 160.0))
	_slot.size = Vector2(96, 112) * duck_scale
	_home = _clamp_floor(Vector2(minf(88, size.x * 0.16), size.y - 32))
	_toy.custom_minimum_size = Vector2.ONE * toy_size
	_toy.size = Vector2.ONE * toy_size
	_toy.pivot_offset = _toy.size * 0.5
	if not _fixed_toy_home and (changed or not _initialized):
		_toy_home = Vector2(size.x - 66, size.y - 74)
	elif _fixed_toy_home:
		_toy_home = _clamp_toy(_toy_home)
	_label.size = Vector2(toy_label_width, 26)
	_label.add_theme_font_size_override("font_size", 16 if toy_size < 60 else 21)
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


func set_toy_home(point: Vector2, crowded: bool = false) -> void:
	_fixed_toy_home = true
	_crowded = crowded
	_toy_home = _clamp_toy(point) if _initialized else point
	if _initialized and toy_phase == "idle":
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
	var half_width: float = minf(_slot.size.x * 0.5 + 4, size.x * 0.5)
	var x := clampf(point.x, half_width, maxf(half_width, size.x - half_width))
	var bottom: float = maxf(0, size.y - 12)
	# Pip is drawn in a centered square with its planted toes at 112/120 of the art.
	# Keep both feet below the side-wall junction, including the slot's lower padding.
	var edge := minf(_slot.size.x, _slot.size.y)
	var feet_inset := (_slot.size.y - edge) * 0.5 + edge * (8.0 / 120.0)
	var floor_y := maxf(Interior.floor_y_at(size, x - edge * 0.33), Interior.floor_y_at(size, x + edge * 0.33))
	var top: float = minf(bottom, maxf(_slot.size.y + 4, floor_y + feet_inset + 4))
	return Vector2(x, clampf(point.y, top, bottom))


func _clamp_toy(point: Vector2) -> Vector2:
	var half_size: float = toy_size * 0.5
	var left: float = minf(half_size + 4, size.x * 0.5)
	var label_height: float = maxf(26, _label.get_combined_minimum_size().y) if _label != null else 26
	var bottom: float = maxf(half_size, size.y - half_size - label_height - 2)
	return Vector2(clampf(point.x, left, maxf(left, size.x - left)), clampf(point.y, minf(half_size + 4, bottom), bottom))


func _place_duck() -> void:
	_slot.position = duck_position - Vector2(_slot.size.x * 0.5, _slot.size.y)


func _clear_toy_space() -> bool:
	if _crowded:
		return false
	if not Rect2(_slot.position, _slot.size).grow(8).intersects(Rect2(_toy_home - _toy.size * 0.5, _toy.size)):
		return false
	_toy_home.x = size.x - 66 if duck_position.x < size.x * 0.5 else 66
	return true


func _place_toy(center: Vector2) -> void:
	center = _clamp_toy(center)
	_toy.z_index = 90 if toy_phase != "idle" else 0
	_label.z_index = _toy.z_index
	_toy.position = center - _toy.size * 0.5
	var label_height: float = maxf(26, _label.get_combined_minimum_size().y)
	_label.position = Vector2(clampf(center.x - toy_label_width * 0.5, 4, maxf(4, size.x - toy_label_width - 4)), minf(center.y + toy_size * 0.5 + 1, size.y - label_height - 1))


func _react(kind: String) -> void:
	if is_instance_valid(_duck):
		_duck.react_in_room(kind)


func _note_activity() -> void:
	if is_instance_valid(_duck):
		_duck.note_activity()


func _report(kind: String, message: String) -> void:
	interaction_kind = kind
	interaction.emit(kind, message)


func _begin_action() -> void:
	cancel()
	interaction_started.emit()


func _pip_busy() -> bool:
	return _gesture == "duck" \
		or (is_instance_valid(_duck) and _duck.is_manual_action_busy()) \
		or (pip_audio_busy.is_valid() and bool(pip_audio_busy.call()))


func pet() -> void:
	if not _allowed() or _pip_busy(): return
	_perform_pet()


func _perform_pet() -> void:
	_begin_action()
	_pet_count += 1
	_react("pet")
	_report("pet", ["Pip leans into your hand. Lovely!", "Soft strokes. Pip feels loved!", "More cuddles! Pip loves your gentle hand."][(_pet_count - 1) % 3])


func poke() -> void:
	if not _allowed() or _pip_busy(): return
	_perform_poke()


func _perform_poke() -> void:
	_begin_action()
	if _poke_bag.is_empty():
		_poke_bag.assign(LoadingMoves.REACTIONS)
		_poke_bag.shuffle()
		if _poke_bag[0] == _previous_poke:
			var first := _poke_bag[0]
			_poke_bag[0] = _poke_bag[1]
			_poke_bag[1] = first
	_previous_poke = _poke_bag.pop_front()
	_react(_previous_poke)
	_report("poke", LoadingMoves.CAPTIONS[_previous_poke])


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
	set_process(_pointer != -1 or not motion_kind.is_empty() or toy_phase != "idle")
	queue_redraw()


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
	set_process(_pointer != -1 or not motion_kind.is_empty())
	queue_redraw()


func cancel() -> void:
	_pointer = -1
	_gesture = ""
	motion_kind = ""
	interaction_kind = ""
	target_position = duck_position
	_note_activity()
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


func _draw_depth(item: CanvasItem) -> int:
	var depth := 0
	var current: CanvasItem = item
	while current != null:
		depth += current.z_index
		if not current.z_as_relative: break
		current = current.get_parent() as CanvasItem
	return depth


func _draws_above(front: Control, back: Control) -> bool:
	var front_depth := _draw_depth(front)
	var back_depth := _draw_depth(back)
	return front_depth > back_depth or (front_depth == back_depth and front.is_greater_than(back))


func _toy_target_at(point: Vector2) -> Dictionary:
	var result: Dictionary = {}
	if _toy.is_visible_in_tree() and (_toy.get_global_rect().has_point(point) or (_label.is_visible_in_tree() and _label.get_global_rect().has_point(point))):
		result = {"id": active_toy_id, "control": _toy}
	for id in toy_targets:
		var control := toy_targets[id] as Control
		if not is_instance_valid(control) or not control.is_visible_in_tree(): continue
		var hit := control.get_global_rect().has_point(point)
		for label_property in ["title_label", "detail_label"]:
			if hit: break
			var label: Control = control.get(label_property) as Control if label_property in control else null
			hit = is_instance_valid(label) and label.is_visible_in_tree() and label.get_global_rect().has_point(point)
		if hit and (result.is_empty() or _draws_above(control, result.control)):
			result = {"id": str(id), "control": control}
	return result


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
					var owned: bool = _gesture != "floor"
					cancel()
					if owned: get_viewport().set_input_as_handled()
				return
			pressed = event.pressed
			released = not pressed
		else:
			moving = true
	else:
		return
	if _pointer != -1 and pointer != _pointer:
		# The held object keeps ownership; a second pointer must not reach a room Button.
		if _point_visible(point): get_viewport().set_input_as_handled()
		return
	var local := get_global_transform().affine_inverse() * point
	if pressed and _pointer == -1 and _point_visible(point):
		var toy_target := _toy_target_at(point)
		var on_toy := not toy_target.is_empty()
		var on_duck := _slot.get_global_rect().has_point(point)
		if on_toy and on_duck and _draws_above(toy_target.control, _duck if is_instance_valid(_duck) else _slot): on_duck = false
		var blocked := false
		if on_duck and _pip_busy():
			# Consume the whole press, even if Pip finishes before its release.
			# Ignored taps must not cancel a gesture, advance its bag or queue work.
			_pointer = pointer
			_gesture = "blocked"
			get_viewport().set_input_as_handled()
			return
		var target_locked := on_toy and str(toy_target.id) == active_toy_id and toy_locked
		if on_toy and not on_duck and not target_locked:
			get_viewport().set_input_as_handled()
			# Saving may synchronously rebuild the room and cancel its previous gesture.
			# Reuse this press after activation instead of requiring a second tap or drag.
			if activate_toy.is_valid():
				blocked = not bool(activate_toy.call(str(toy_target.id))) or toy_locked
			else:
				blocked = str(toy_target.id) != active_toy_id
			local = get_global_transform().affine_inverse() * point
		_floor_tap_allowed = not blocked and not (on_toy and not on_duck and target_locked)
		if not _floor_tap_allowed: on_toy = false
		if on_toy or on_duck: get_viewport().set_input_as_handled()
		if blocked:
			get_viewport().set_input_as_handled()
		elif on_toy and not on_duck:
			# Grabbing even a resting toy takes over any current mascot reaction.
			cancel()
		elif on_duck:
			_begin_action()
		_pointer = pointer
		# Pip draws above the toy; the visible front object owns overlapping hits.
		_gesture = "blocked" if blocked else "duck" if on_duck else "toy" if on_toy else "floor"
		_press = local
		_last = local
		_last_screen = point
		_travel = 0
		_note_activity()
		set_process(true)
	elif pointer == _pointer:
		if _gesture != "floor": get_viewport().set_input_as_handled()
		if _gesture == "blocked":
			if released:
				_pointer = -1
				_gesture = ""
			return
		if moving:
			# Floor scrolling moves this canvas; measure that gesture in viewport coordinates.
			_travel += point.distance_to(_last_screen) if _gesture == "floor" else local.distance_to(_last)
			_last = local
			_last_screen = point
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
				# This gesture was accepted on press. Its pet preview may still be
				# moving; finish the same interaction without treating it as a new tap.
				if _travel > 18: _perform_pet()
				else: _perform_poke()
			elif gesture == "toy":
				if _travel > 8: _launch(_clamp_toy(local), local + (local - _press) * 0.35)
				else: toy_tapped.emit()
			elif gesture == "floor" and _travel < 12 and _floor_tap_allowed:
				_begin_action()
				_move_to(local)
				_report(motion_kind if not motion_kind.is_empty() else "walk", "Pip %s over!" % ("runs" if motion_kind == "run" else "walks"))


func _process(delta: float) -> void:
	if not _allowed():
		cancel()
		return
	if _pointer != -1 or not motion_kind.is_empty() or toy_phase != "idle":
		# A held gesture or flying toy stays active without fresh pointer events.
		_note_activity()
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
	if _pointer == -1 and motion_kind.is_empty() and toy_phase == "idle": set_process(false)
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
