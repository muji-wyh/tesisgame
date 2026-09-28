extends ScrollContainer

const Style = preload("res://scripts/ui_style.gd")

var interaction_allowed: Callable
var _pointer := -1
var _origin := Vector2.ZERO
var _scroll_origin := 0
var _travel := 0.0
var _target: Button
var _touches: Dictionary = {}
var _suppress_emulated_mouse := false


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	resized.connect(cancel_drag)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			cancel_drag())


func _clear_pointer() -> void:
	_pointer = -1
	_target = null
	_travel = 0.0


func cancel_drag() -> void:
	_clear_pointer()
	_touches.clear()


func _button_at(point: Vector2) -> Button:
	if get_child_count() == 0:
		return null
	return _nested_button_at(get_child(0), point)


func _nested_button_at(parent: Node, point: Vector2) -> Button:
	for child in parent.get_children():
		if not child is Control or not child.is_visible_in_tree():
			continue
		var nested: Button = _nested_button_at(child, point)
		if nested != null:
			return nested
		if child is Button and not child.disabled and child.get_global_rect().has_point(point):
			return child
	return null


func _scroll_by(distance: float) -> void:
	var bar := get_h_scroll_bar()
	scroll_horizontal = clampi(roundi(scroll_horizontal + distance), 0, maxi(0, roundi(bar.max_value - bar.page)))


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or (interaction_allowed.is_valid() and not interaction_allowed.call()):
		cancel_drag()
		return
	if event is InputEventPanGesture and get_global_rect().has_point(event.position):
		cancel_drag()
		_scroll_by((event.delta.x if absf(event.delta.x) > absf(event.delta.y) else event.delta.y) * 24 / Style.ui_scale(self))
		get_viewport().set_input_as_handled()
		return
	var pointer := -2
	var pressed := false
	var released := false
	var moving := false
	var point := Vector2.ZERO
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		point = event.position
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			if event is InputEventMouseButton and event.pressed:
				_suppress_emulated_mouse = get_global_rect().has_point(point)
			if _suppress_emulated_mouse:
				get_viewport().set_input_as_handled()
			if event is InputEventMouseButton and not event.pressed:
				_suppress_emulated_mouse = false
			return
		if event is InputEventMouseButton:
			if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT] and get_global_rect().has_point(point):
				if event.pressed:
					cancel_drag()
					var direction: float = -1.0 if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT] else 1.0
					_scroll_by(direction * 48 * event.factor / Style.ui_scale(self))
				get_viewport().set_input_as_handled()
				return
			if event.button_index != MOUSE_BUTTON_LEFT:
				return
			pressed = event.pressed
			released = not pressed
		else:
			if _pointer == -2 and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
				cancel_drag()
				return
			moving = true
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		point = event.position
		pointer = event.index
		if event is InputEventScreenTouch:
			if event.pressed:
				if _touches.is_empty():
					_suppress_emulated_mouse = get_global_rect().has_point(point)
				_touches[pointer] = true
			else:
				_touches.erase(pointer)
			if event.canceled:
				if pointer == _pointer:
					_clear_pointer()
					get_viewport().set_input_as_handled()
				return
			if _touches.size() > 1:
				_clear_pointer()
				if get_global_rect().has_point(point):
					get_viewport().set_input_as_handled()
				return
			pressed = event.pressed
			released = not pressed
		else:
			moving = true
	else:
		return
	if pressed and _pointer == -1 and get_global_rect().has_point(point):
		_pointer = pointer
		_origin = point
		_travel = 0.0
		_target = _button_at(point)
		if _target != null:
			_target.grab_focus()
		_scroll_origin = scroll_horizontal
		get_viewport().set_input_as_handled()
	elif pointer == _pointer:
		var delta: Vector2 = point - _origin
		_travel = maxf(_travel, delta.length())
		var threshold: float = 8 / Style.ui_scale(self)
		if moving and absf(delta.x) >= threshold and absf(delta.x) > absf(delta.y) * 1.2:
			var bar := get_h_scroll_bar()
			scroll_horizontal = clampi(roundi(_scroll_origin - delta.x), 0, maxi(0, roundi(bar.max_value - bar.page)))
		elif released:
			var target := _target
			var tap: bool = _travel < threshold and get_global_rect().has_point(point)
			_clear_pointer()
			if tap and is_instance_valid(target) and target == _button_at(point):
				target.pressed.emit()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		cancel_drag()
