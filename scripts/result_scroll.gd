extends ScrollContainer

const Style = preload("res://scripts/ui_style.gd")
const Momentum = preload("res://scripts/scroll_momentum.gd")
const NO_POINTER := 0
const TOUCH_POINTER := 1
const EMULATED_POINTER := 2
const MOUSE_POINTER := 3

var interaction_allowed: Callable
var horizontal := false
var _motion := Momentum.new()
var _pointer := NO_POINTER
var _touch_id := -1
var _touches: Dictionary = {}
var _multiple_touches := false
var _suppress_emulated_mouse := false
var _native_touch := false
var _origin := Vector2.ZERO
var _scroll_origin := 0
var _travel := 0.0
var _dragging := false
var _braking := false
var _target: Button
var _target_tint := Color.WHITE


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	set_process(false)
	resized.connect(cancel_drag)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			cancel_drag())


func is_pointer_active() -> bool:
	return _pointer != NO_POINTER


func is_scrolling() -> bool:
	return is_pointer_active() or _motion.is_active()


func is_coasting() -> bool:
	return _motion.is_active()


func cancel_drag() -> void:
	_clear_pointer()
	_motion.stop()
	set_process(false)
	_touches.clear()
	_multiple_touches = false


func _clear_pointer() -> void:
	if is_instance_valid(_target):
		_target.self_modulate = _target_tint
	_target = null
	_pointer = NO_POINTER
	_touch_id = -1
	_travel = 0.0
	_dragging = false
	_braking = false


func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0


func _offset() -> int:
	return scroll_horizontal if horizontal else scroll_vertical


func _maximum() -> float:
	var bar: ScrollBar = get_h_scroll_bar() if horizontal else get_v_scroll_bar()
	return maxf(0.0, roundf(bar.max_value - bar.page))


func _set_offset(value: float) -> void:
	var offset := clampi(roundi(value), 0, roundi(_maximum()))
	if horizontal:
		scroll_horizontal = offset
	else:
		scroll_vertical = offset


func _local_point(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point


func _contains(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(_local_point(point))


func _unit_scale() -> float:
	var transform := get_global_transform_with_canvas()
	return maxf(0.01, Style.ui_scale(self) * (transform.x.length() if horizontal else transform.y.length()))


func _threshold() -> float:
	return 8.0 / _unit_scale()


func _control_at(parent: Node, point: Vector2, native_only: bool = false) -> Control:
	for child in parent.get_children():
		if not child is Control or not child.is_visible_in_tree():
			continue
		var local: Vector2 = child.get_global_transform_with_canvas().affine_inverse() * point
		var inside: bool = Rect2(Vector2.ZERO, child.size).has_point(local)
		if child.clip_contents and not inside:
			continue
		if inside and native_only and (child is LineEdit or child is TextEdit or child is Range):
			return child
		var nested := _control_at(child, point, native_only)
		if nested != null:
			return nested
		if not native_only and child is Button and inside and not child.disabled:
			return child
	return null


func _button_at(point: Vector2) -> Button:
	return _control_at(self, point) as Button


func _begin(point: Vector2, pointer: int, touch_id: int = -1) -> void:
	var braking := _motion.is_active()
	_motion.begin(_offset(), _now(), _unit_scale())
	set_process(false)
	_pointer = pointer
	_touch_id = touch_id
	_origin = _local_point(point)
	_scroll_origin = _offset()
	_travel = 0.0
	_dragging = false
	_braking = braking
	# The first contact catches a moving list; it must not activate a card.
	_target = null if braking else _button_at(point)
	if is_instance_valid(_target):
		_target_tint = _target.self_modulate
		_target.self_modulate = _target_tint * Color(0.82, 0.90, 1.0, 1.0)
	if pointer != MOUSE_POINTER:
		_suppress_emulated_mouse = true


func _move(point: Vector2) -> void:
	# Convert absolute positions once; emulated mouse and raw touch must never
	# contribute two deltas to the same drag, including on high-DPI canvases.
	var delta := _local_point(point) - _origin
	_travel = maxf(_travel, delta.length())
	var distance: float = delta.x if horizontal else delta.y
	var cross_distance: float = delta.y if horizontal else delta.x
	if not _dragging:
		if absf(distance) < _threshold() or absf(distance) < absf(cross_distance) * 1.2:
			return
		_dragging = true
		if is_instance_valid(_target):
			_target.self_modulate = _target_tint
	_set_offset(_scroll_origin - distance)
	_motion.track(_offset(), _now())


func _finish(point: Vector2, canceled: bool = false) -> void:
	if not canceled:
		_move(point)
	var target := _target
	var tapped: bool = not canceled and not _braking and _travel < _threshold() and _contains(point)
	if not canceled and _dragging:
		_motion.release(_now())
	else:
		_motion.stop()
	_clear_pointer()
	set_process(_motion.is_active())
	# Focus on release, so focus reveal cannot add a jump to the held drag.
	if tapped and is_instance_valid(target) and target == _button_at(point):
		target.grab_focus()
		target.pressed.emit()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or (interaction_allowed.is_valid() and not interaction_allowed.call()):
		cancel_drag()
		return
	if is_pointer_active():
		return
	if not _motion.is_active():
		set_process(false)
		return
	# Explicit focus reveal or a programmatic reset takes priority over inertia.
	if absi(_offset() - roundi(_motion.position)) > 1:
		_motion.stop()
	else:
		_set_offset(_motion.advance(delta, _maximum()))
	set_process(_motion.is_active())


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or (interaction_allowed.is_valid() and not interaction_allowed.call()):
		cancel_drag()
		return
	if (event is InputEventKey or event is InputEventAction or event is InputEventJoypadButton) and event.is_pressed():
		cancel_drag()
		return
	if event is InputEventJoypadMotion and absf(event.axis_value) > 0.3:
		cancel_drag()
		return
	if event is InputEventPanGesture and _contains(event.position):
		cancel_drag()
		# Trackpads supply their own momentum events; do not synthesize a second tail.
		var distance: float = event.delta.y
		if horizontal and absf(event.delta.x) > absf(distance):
			distance = event.delta.x
		_set_offset(_offset() + distance * 24.0 / _unit_scale())
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var inside: bool = _contains(event.position)
		if event.pressed:
			if _touches.is_empty() and _pointer == NO_POINTER:
				_native_touch = inside and _control_at(self, event.position, true) != null
				_suppress_emulated_mouse = inside and not _native_touch
			_touches[event.index] = true
			if _native_touch:
				_motion.stop()
				set_process(false)
				return
			if _touches.size() > 1:
				_multiple_touches = true
				_clear_pointer()
				_motion.stop()
				set_process(false)
			elif _pointer == NO_POINTER and not _multiple_touches and inside:
				_begin(event.position, TOUCH_POINTER, event.index)
		else:
			_touches.erase(event.index)
			if _native_touch:
				return
			if event.canceled:
				_clear_pointer()
				_motion.stop()
				set_process(false)
			elif _pointer == TOUCH_POINTER and event.index == _touch_id:
				_finish(event.position)
			if _touches.is_empty():
				_multiple_touches = false
		if inside or is_pointer_active() or _suppress_emulated_mouse:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag:
		if _native_touch:
			return
		if _pointer == TOUCH_POINTER and event.index == _touch_id:
			_move(event.position)
		if is_pointer_active() or _suppress_emulated_mouse:
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		_handle_emulated_mouse(event)
		return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT] and _contains(event.position):
			if event.pressed:
				_clear_pointer()
				_touches.clear()
				_multiple_touches = false
				var direction: float = -1.0 if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] else 1.0
				_motion.wheel(_offset(), direction * 48.0 * event.factor / _unit_scale(), _maximum(), _unit_scale())
				_set_offset(_motion.position)
				set_process(_motion.is_active())
			get_viewport().set_input_as_handled()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			if not _contains(event.position):
				cancel_drag()
				return
			if _control_at(self, event.position, true) != null:
				cancel_drag()
				return
			if is_pointer_active():
				cancel_drag()
			else:
				_clear_pointer()
			_begin(event.position, MOUSE_POINTER)
			get_viewport().set_input_as_handled()
		elif _pointer == MOUSE_POINTER:
			_finish(event.position, event.canceled)
			get_viewport().set_input_as_handled()
	elif _pointer == MOUSE_POINTER:
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			cancel_drag()
		else:
			_move(event.position)
		get_viewport().set_input_as_handled()


func _handle_emulated_mouse(event: InputEvent) -> void:
	# Whichever stream pressed first owns the gesture. Consume its duplicate
	# so the native ScrollContainer cannot start another drag or inertial scroll.
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			if _touches.is_empty():
				_native_touch = _contains(event.position) and _control_at(self, event.position, true) != null
				_suppress_emulated_mouse = _contains(event.position) and not _native_touch
			if _native_touch:
				_motion.stop()
				set_process(false)
				return
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
				cancel_drag()
			else:
				_move(event.position)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		cancel_drag()
