extends Button
## The layout target stays still while an acquired gel skin stretches downward.

signal pull_started
signal pull_canceled
signal threshold_reached
signal finish_committed
signal accessibility_requested

const Style = preload("res://scripts/ui_style.gd")
const Surface = preload("res://scripts/jelly_finish_surface.gdshader")
const GEL = preload("res://assets/images/jelly-match/gel-coral.png")
const FLAG = preload("res://assets/images/ui/finish-flag.svg")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const TAP_SLOP_PX: float = 8.0
const TAP_HINT_PULL_PX: float = 32.0
const TAP_HINT_ATTACK_SECONDS: float = 0.20

var _ui_scale: float = 1.0
var _reduced_motion: bool = false
var _accent := Color("#357d70")
var _pulling: bool = false
var _armed: bool = false
var _returning: bool = false
var _tap_hint: bool = false
var _tap_elapsed: float = 0.0
var _tap_start_pull: float = 0.0
var _gesture_travel: float = 0.0
var _pointer_id: int = -2
var _gesture_serial: int = 0
var _suppress_emulated_mouse: bool = false
var _start := Vector2.ZERO
var _pull_distance: float = 0.0
var _visual_pull: float = 0.0
var _sideways: float = 0.0
var _velocity: float = 0.0
var _threshold: float = 88.0
var _max_pull: float = 116.0
var _armed_once: bool = false
var _hint_allowed: bool = true
var _hint_elapsed: float = 0.0
var _next_hint: float = 11.0
var _hint_serial: int = 0
var _idle_cue: float = -1.0
var _clock: float = 0.0
var _was_disabled: bool = false
var _surface := TextureRect.new()
var _label := Label.new()
var _flag := TextureRect.new()
var _glow := TextureRect.new()
var _sparkles: Array[TextureRect] = []
var _gel := ShaderMaterial.new()


func _init() -> void:
	text = "Finish"
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	clip_contents = false
	# Native Button remains the accessible keyboard action. Pointer events are
	# consumed in _input before BaseButton can turn a tap into that action.
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)
	add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	add_theme_constant_override("outline_size", 0)
	add_theme_font_size_override("font_size", 1)
	set("accessibility_name", "Finish game. Pull downward until it lights up, then release. Press Enter for confirmation.")
	for image: TextureRect in [_glow, _surface, _flag]:
		_prepare_texture(image)
		add_child(image)
	_glow.texture = GLOW
	_surface.texture = GEL
	_gel.shader = Surface
	_surface.material = _gel
	_flag.texture = FLAG
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", Style.HEADING_FONT)
	_label.add_theme_color_override("font_color", Color("#643f3d"))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(_label)
	for index: int in range(3):
		var sparkle := TextureRect.new()
		_prepare_texture(sparkle)
		sparkle.texture = SPARKLE
		add_child(sparkle)
		_sparkles.append(sparkle)
	pressed.connect(_request_accessible_finish)
	resized.connect(_on_resized)
	visibility_changed.connect(_on_visibility_changed)
	focus_exited.connect(_on_focus_exited)
	focus_entered.connect(_update_visual)
	configure(_accent, 1.0, false)


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_resized)
	_refresh_distances()
	_update_visual()


func _on_viewport_resized() -> void:
	cancel_pull(true)
	_refresh_distances()
	_update_visual()


func _prepare_texture(image: TextureRect) -> void:
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(accent: Color, ui_scale: float, reduced: bool) -> void:
	var scale_value: float = maxf(0.1, ui_scale)
	if not is_equal_approx(_ui_scale, scale_value) or _reduced_motion != reduced:
		cancel_pull(true)
	_accent = accent
	_ui_scale = scale_value
	_reduced_motion = reduced
	custom_minimum_size = Vector2(84.0, 44.0) / _ui_scale
	_refresh_distances()
	_update_visual()


func _refresh_distances() -> void:
	var short_height: bool = is_inside_tree() and get_viewport_rect().size.y * _ui_scale <= 360.0
	_threshold = (70.0 if short_height else 88.0) / _ui_scale
	_max_pull = (94.0 if short_height else 116.0) / _ui_scale


func is_pulling() -> bool:
	return _pulling


func set_hint_allowed(value: bool) -> void:
	_hint_allowed = value
	if not value:
		_hint_elapsed = 0.0
		if _idle_cue >= 0.0:
			_idle_cue = -1.0
			_visual_pull = 0.0
			_update_visual()


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	if disabled != _was_disabled:
		_was_disabled = disabled
		if disabled:
			cancel_pull(true)
	if not is_visible_in_tree() or disabled:
		return
	_clock += delta
	var return_delta: float = delta
	if _tap_hint and not _returning:
		var attack_delta: float = minf(delta, TAP_HINT_ATTACK_SECONDS - _tap_elapsed)
		_tap_elapsed += attack_delta
		return_delta -= attack_delta
		var progress: float = clampf(_tap_elapsed / TAP_HINT_ATTACK_SECONDS, 0.0, 1.0)
		_visual_pull = lerpf(_tap_start_pull, TAP_HINT_PULL_PX / _ui_scale, 1.0 - pow(1.0 - progress, 3.0))
		if _tap_elapsed >= TAP_HINT_ATTACK_SECONDS:
			_returning = true
			_velocity = 0.0
	if _returning:
		if _reduced_motion:
			_visual_pull = 0.0
			_returning = false
			_tap_hint = false
		else:
			var remaining: float = minf(return_delta, 0.5)
			while remaining > 0.0:
				var step: float = minf(remaining, 1.0 / 120.0)
				_velocity += (-_visual_pull * 190.0 - _velocity * 17.5) * step
				_visual_pull = maxf(-6.0 / _ui_scale, _visual_pull + _velocity * step)
				_sideways *= exp(-step * 14.0)
				remaining -= step
			if absf(_visual_pull) * _ui_scale < 0.12 and absf(_velocity) * _ui_scale < 0.8:
				_visual_pull = 0.0
				_velocity = 0.0
				_sideways = 0.0
				_returning = false
				_tap_hint = false
	elif not _pulling and not _tap_hint and _hint_allowed and not _reduced_motion:
		if _idle_cue >= 0.0:
			_idle_cue += delta
			if _idle_cue >= 0.92:
				_idle_cue = -1.0
				_visual_pull = 0.0
			else:
				var t: float = _idle_cue / 0.92
				# Lead with a downward tug; the smaller up/down tail reads as its
				# elastic recovery rather than another equally strong instruction.
				var attack: float = sin(minf(1.0, t * 4.0) * PI * 0.5)
				_visual_pull = sin(t * PI * 2.6) * attack * exp(-t * 3.0) * (1.0 - t) * 15.0 / _ui_scale
		else:
			_hint_elapsed += delta
			if _hint_elapsed >= _next_hint:
				_hint_elapsed = 0.0
				_idle_cue = 0.0
				_hint_serial += 1
				_next_hint = 9.0 + fmod(float(_hint_serial) * 2.7, 5.0)
	_update_visual()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or disabled:
		if _pulling or _tap_hint:
			cancel_pull(true)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Native touch-to-mouse emulation must not start or finish a second pull.
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			if _suppress_emulated_mouse or _pulling or get_global_rect().has_point(event.position):
				get_viewport().set_input_as_handled()
			if not event.pressed:
				_suppress_emulated_mouse = false
			return
		if _pulling and _pointer_id != -1:
			get_viewport().set_input_as_handled()
		elif event.canceled and _pulling:
			cancel_pull()
			get_viewport().set_input_as_handled()
		elif event.pressed and not event.canceled and not _pulling and get_global_rect().has_point(event.position):
			_begin_pull(event.position, -1)
			get_viewport().set_input_as_handled()
		elif not event.pressed and _pulling and _pointer_id == -1:
			_release_pull(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _pulling and _pointer_id == -1:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT == 0:
			cancel_pull()
		else:
			_move_pull(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed and not event.canceled and not _pulling and get_global_rect().has_point(event.position):
			_begin_pull(event.position, event.index)
			get_viewport().set_input_as_handled()
		elif _pulling and event.index == _pointer_id and (not event.pressed or event.canceled):
			if event.canceled:
				cancel_pull()
			else:
				_release_pull(event.position)
			get_viewport().set_input_as_handled()
		elif _pulling:
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _pulling and event.index == _pointer_id:
		_move_pull(event.position)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _pulling:
		cancel_pull()
		get_viewport().set_input_as_handled()


func _begin_pull(point: Vector2, pointer_id: int) -> void:
	if disabled or not is_visible_in_tree() or _pulling:
		return
	_refresh_distances()
	grab_focus()
	_start = point
	_gesture_serial += 1
	_pointer_id = pointer_id
	if pointer_id >= 0:
		_suppress_emulated_mouse = true
	_pulling = true
	_armed = false
	_armed_once = false
	_returning = false
	_tap_hint = false
	_tap_elapsed = 0.0
	_gesture_travel = 0.0
	_pull_distance = 0.0
	_visual_pull = 0.0
	_sideways = 0.0
	_velocity = 0.0
	_idle_cue = -1.0
	_hint_elapsed = 0.0
	_update_visual()
	pull_started.emit()


func _move_pull(point: Vector2) -> void:
	if not _pulling:
		return
	var local_delta: Vector2 = get_global_transform().basis_xform_inv(point - _start)
	_gesture_travel = maxf(_gesture_travel, local_delta.length())
	_pull_distance = maxf(0.0, local_delta.y)
	_sideways = clampf(local_delta.x * 0.12, -10.0 / _ui_scale, 10.0 / _ui_scale)
	# A little extra resistance beyond the threshold protects the header from
	# unbounded stretching while the commitment boundary remains literal.
	_visual_pull = minf(_max_pull, _pull_distance if _pull_distance <= _threshold else _threshold + (_pull_distance - _threshold) * 0.38)
	var was_armed: bool = _armed
	_armed = _pull_distance >= _threshold and absf(local_delta.x) <= maxf(size.x, 84.0 / _ui_scale) * 1.35
	_update_visual()
	if _armed and not was_armed and not _armed_once:
		_armed_once = true
		threshold_reached.emit()


func _release_pull(point: Vector2) -> void:
	if not _pulling:
		return
	_move_pull(point)
	var commit: bool = _armed and not disabled and is_visible_in_tree()
	var tapped: bool = _gesture_travel * _ui_scale <= TAP_SLOP_PX
	_pulling = false
	_gesture_serial += 1
	_pointer_id = -2
	_armed = false
	_pull_distance = 0.0
	_hint_elapsed = 0.0
	if commit:
		cancel_pull(true)
		finish_committed.emit()
	else:
		_returning = not _reduced_motion and absf(_visual_pull) > 0.01
		_velocity = -_visual_pull * 2.5
		if not _returning:
			_visual_pull = 0.0
			_sideways = 0.0
		if tapped and not _reduced_motion:
			# Demonstrate the gesture without owning input or advancing Finish.
			# The same anchored skin and spring as a real pull teach its direction.
			_tap_hint = true
			_tap_elapsed = 0.0
			_tap_start_pull = _visual_pull
			_returning = false
			_velocity = 0.0
			_sideways = 0.0
		_update_visual()
		pull_canceled.emit()


func cancel_pull(immediate: bool = false) -> void:
	var was_pulling: bool = _pulling
	_pulling = false
	_gesture_serial += 1
	_armed = false
	_pointer_id = -2
	_pull_distance = 0.0
	_armed_once = false
	_tap_hint = false
	_tap_elapsed = 0.0
	_gesture_travel = 0.0
	_hint_elapsed = 0.0
	_idle_cue = -1.0
	_returning = not immediate and not _reduced_motion and absf(_visual_pull) > 0.01
	_velocity = -_visual_pull * 2.5 if _returning else 0.0
	if not _returning:
		_visual_pull = 0.0
		_sideways = 0.0
	_update_visual()
	if was_pulling:
		pull_canceled.emit()


func release_pointer(pointer: int) -> void:
	# The Web host can notify pointer-up before Godot dispatches the up event.
	# If that event never arrives, loss of ownership cancels instead of committing.
	_cancel_missing_release.call_deferred(pointer, _gesture_serial)


func _cancel_missing_release(pointer: int, serial: int) -> void:
	if _pulling and pointer == _pointer_id and serial == _gesture_serial:
		cancel_pull()


func _request_accessible_finish() -> void:
	if not disabled and is_visible_in_tree() and not _pulling:
		cancel_pull(true)
		accessibility_requested.emit()


func _on_resized() -> void:
	cancel_pull(true)
	_refresh_distances()
	_update_visual()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		cancel_pull(true)


func _on_focus_exited() -> void:
	if _pulling:
		cancel_pull()
	elif _tap_hint:
		cancel_pull(true)
	_update_visual()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_EXIT_TREE]:
		cancel_pull(true)


func _update_visual() -> void:
	if _surface == null or _gel == null:
		return
	# A stretched header control crosses the preview without going behind its
	# tiles. Confirmation and other modal layers still retain their higher level.
	z_index = 85 if _pulling or _returning or _tap_hint or _idle_cue >= 0.0 else 0
	var unit: float = 1.0 / maxf(0.1, _ui_scale)
	var margin := Vector2(14.0, 12.0) * unit
	_surface.position = -margin
	_surface.size = size + Vector2(margin.x * 2.0, _max_pull + margin.y * 2.0)
	_gel.set_shader_parameter("canvas_size", _surface.size)
	_gel.set_shader_parameter("body_size", size)
	_gel.set_shader_parameter("body_origin", margin)
	_gel.set_shader_parameter("pull", _visual_pull)
	_gel.set_shader_parameter("max_pull", _max_pull)
	_gel.set_shader_parameter("sideways", _sideways)
	_gel.set_shader_parameter("armed", 1.0 if _armed else 0.0)
	_gel.set_shader_parameter("focus_light", 1.0 if has_focus() and not _pulling else 0.0)
	_gel.set_shader_parameter("shimmer", 0.45 if _reduced_motion else fmod(_clock * 1.3, 1.8) - 0.3)
	_gel.set_shader_parameter("light_color", Color("#fff0b8"))
	_surface.modulate = Color(1.0, 1.0, 1.0, 0.48 if disabled else 1.0)
	var text_center := Vector2(size.x * 0.5 + _sideways * 0.74, size.y * 0.5 + _visual_pull * 0.82)
	var instructing: bool = _pulling or _tap_hint or _returning
	_label.text = "Drag to\nfinish" if instructing else text
	_label.add_theme_font_size_override("font_size", maxi(1, roundi(12.0 * unit)))
	var label_width: float = Style.HEADING_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(1, roundi(12.0 * unit))).x + 2.0 * unit
	var flag_edge: float = 15.0 * unit
	var group_width: float = flag_edge + 4.0 * unit + label_width
	_flag.position = text_center + Vector2(-group_width * 0.5, -flag_edge * 0.5)
	_flag.size = Vector2.ONE * flag_edge
	_flag.modulate = Color("#744847") if not _armed else Color("#76532b")
	_label.position = text_center + Vector2(-group_width * 0.5 + flag_edge + 4.0 * unit, -11.0 * unit)
	_label.size = Vector2(label_width, 22.0 * unit)
	_flag.visible = not instructing
	if instructing:
		_label.add_theme_font_size_override("font_size", maxi(1, roundi(11.0 * unit)))
		_label.add_theme_constant_override("line_spacing", -2)
		_label.position = text_center - Vector2(size.x - 12.0 * unit, 34.0 * unit) * 0.5
		_label.size = Vector2(size.x - 12.0 * unit, 34.0 * unit)
	_label.modulate.a = 0.6 if disabled else 1.0
	_flag.modulate.a = 0.6 if disabled else 1.0
	_glow.visible = _armed
	_glow.size = Vector2(size.x * 1.85, maxf(size.y * 2.5, size.y + _visual_pull * 1.15))
	_glow.position = Vector2(size.x * 0.5, (size.y + _visual_pull) * 0.5) - _glow.size * 0.5
	_glow.modulate = Color("#ffe4a1")
	_glow.modulate.a = 0.56 if _reduced_motion else 0.62 + sin(_clock * 7.0) * 0.10
	for index: int in range(_sparkles.size()):
		var sparkle: TextureRect = _sparkles[index]
		sparkle.visible = _armed and not _reduced_motion
		var offsets: Array[Vector2] = [Vector2(-0.45, -0.3), Vector2(0.44, 0.14), Vector2(0.16, 0.56)]
		var edge: float = (12.0 + sin(_clock * 6.0 + index * 1.8) * 3.0) * unit
		var center: Vector2 = text_center + offsets[index] * Vector2(size.x, size.y)
		sparkle.position = center - Vector2.ONE * edge * 0.5
		sparkle.size = Vector2.ONE * edge
		sparkle.modulate = Color(1.0, 0.97, 0.78, 0.75)


func snapshot() -> Dictionary:
	return {
		"pulling": _pulling, "armed": _armed, "returning": _returning,
		"tap_hint": _tap_hint,
		"progress": clampf(_pull_distance / maxf(1.0, _threshold), 0.0, 1.0),
		"pull_distance": _pull_distance, "visual_pull": _visual_pull,
		"threshold": _threshold, "max_pull": _max_pull, "ui_scale": _ui_scale,
		"idle_cue": _idle_cue >= 0.0, "hint_allowed": _hint_allowed,
		"glow": _armed, "label_rect": _label.get_rect(), "label_text": _label.text, "surface_rect": _surface.get_rect()
	}
