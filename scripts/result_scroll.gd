extends ScrollContainer

const Style = preload("res://scripts/ui_style.gd")
const NO_POINTER := 0
const TOUCH_POINTER := 1
const EMULATED_POINTER := 2

var interaction_allowed: Callable
var _pointer := NO_POINTER
var _touch_id := -1
var _touches: Dictionary = {}
var _multiple_touches := false
var _suppress_emulated_mouse := false
var _origin := Vector2.ZERO
var _scroll_origin := 0
var _travel := 0.0
var _target: Button
var _target_tint := Color.WHITE


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	resized.connect(cancel_drag)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			cancel_drag())


func is_pointer_active() -> bool:
	return _pointer != NO_POINTER


func cancel_drag() -> void:
	_clear_pointer()
	_touches.clear()
	_multiple_touches = false


func _clear_pointer() -> void:
	if is_instance_valid(_target):
		_target.self_modulate = _target_tint
	_target = null
	_pointer = NO_POINTER
	_touch_id = -1
	_travel = 0.0


func _local_point(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point


func _contains(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(_local_point(point))


func _threshold() -> float:
	var canvas_scale: float = get_global_transform_with_canvas().y.length()
	return 8.0 / maxf(0.01, Style.ui_scale(self) * canvas_scale)


func _button_at(parent: Node, point: Vector2) -> Button:
	for child in parent.get_children():
		if not child is Control or not child.is_visible_in_tree():
			continue
		var local: Vector2 = child.get_global_transform_with_canvas().affine_inverse() * point
		var inside: bool = Rect2(Vector2.ZERO, child.size).has_point(local)
		if child.clip_contents and not inside:
			continue
		var nested: Button = _button_at(child, point)
		if nested != null:
			return nested
		if child is Button and inside and not child.disabled:
			return child
	return null


func _begin(point: Vector2, pointer: int, touch_id: int = -1) -> void:
	_pointer = pointer
	_touch_id = touch_id
	_origin = _local_point(point)
	_scroll_origin = scroll_vertical
	_travel = 0.0
	_target = _button_at(self, point)
	if is_instance_valid(_target):
		_target_tint = _target.self_modulate
		_target.self_modulate = _target_tint * Color(0.82, 0.90, 1.0, 1.0)
	_suppress_emulated_mouse = true


func _move(point: Vector2) -> void:
	# Positions are already in viewport coordinates. Convert once to this
	# container's space; never accumulate relative or screen-pixel deltas.
	var delta := _local_point(point) - _origin
	_travel = maxf(_travel, delta.length())
	if _travel < _threshold():
		return
	if is_instance_valid(_target):
		_target.self_modulate = _target_tint
	var bar := get_v_scroll_bar()
	scroll_vertical = clampi(roundi(_scroll_origin - delta.y), 0, maxi(0, roundi(bar.max_value - bar.page)))


func _finish(point: Vector2, canceled: bool = false) -> void:
	if not canceled:
		_move(point)
	var target := _target
	var tapped: bool = not canceled and _travel < _threshold() and _contains(point)
	_clear_pointer()
	# Deferring focus until release prevents focus-reveal scrolling from adding
	# a second movement when a drag starts over Play again or a word card.
	if tapped and is_instance_valid(target) and target == _button_at(self, point):
		target.grab_focus()
		target.pressed.emit()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or (interaction_allowed.is_valid() and not interaction_allowed.call()):
		cancel_drag()
		return
	if event is InputEventScreenTouch:
		var inside: bool = _contains(event.position)
		if event.pressed:
			# A raw-touch-only gesture may have no emulated release to clear the
			# suppression flag. A new contact always rechecks its own location.
			if _touches.is_empty() and _pointer == NO_POINTER:
				_suppress_emulated_mouse = inside
			_touches[event.index] = true
			if _touches.size() > 1:
				_multiple_touches = true
				_clear_pointer()
			elif _pointer == NO_POINTER and not _multiple_touches and inside:
				_begin(event.position, TOUCH_POINTER, event.index)
		else:
			_touches.erase(event.index)
			if event.canceled:
				_clear_pointer()
			elif _pointer == TOUCH_POINTER and event.index == _touch_id:
				_finish(event.position)
			if _touches.is_empty():
				_multiple_touches = false
		if inside or is_pointer_active() or _suppress_emulated_mouse:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		if _pointer == TOUCH_POINTER and event.index == _touch_id:
			_move(event.position)
		if is_pointer_active() or _suppress_emulated_mouse:
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	if event.device != InputEvent.DEVICE_ID_EMULATION:
		if event is InputEventMouseButton and event.pressed and is_pointer_active():
			cancel_drag()
		return
	# Godot emits an emulated mouse event as well as each touch. Whichever
	# press arrives first owns the gesture; consume the other stream so the
	# built-in ScrollContainer cannot start another drag or inertial scroll.
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			if _touches.is_empty():
				_suppress_emulated_mouse = _contains(event.position)
			if _suppress_emulated_mouse and _pointer == NO_POINTER and not _multiple_touches:
				_begin(event.position, EMULATED_POINTER)
		if _suppress_emulated_mouse:
			get_viewport().set_input_as_handled()
		if not event.pressed:
			if _pointer == EMULATED_POINTER:
				_finish(event.position, event.canceled)
			_suppress_emulated_mouse = false
	elif _suppress_emulated_mouse:
		get_viewport().set_input_as_handled()
		if _pointer == EMULATED_POINTER:
			if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
				_clear_pointer()
			else:
				_move(event.position)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		cancel_drag()
