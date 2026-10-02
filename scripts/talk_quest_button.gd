extends Button
## Tactile quest controls with contained highlights and a short press ripple.

const Style = preload("res://scripts/ui_style.gd")
var reduced_motion: bool = false
var accent := Color("#7665bb")
var primary: bool = false
var _ripple: float = 1.0
var _hover: float = 0.0
var _clock: float = 0.0
var _pulse: float = 0.0


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button_down.connect(func() -> void:
		_ripple = 0.0
		queue_redraw())
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_ripple = 1.0
			_pulse = 0.0)


func configure(color: Color, strong: bool = false, calm: bool = false) -> void:
	accent = color
	primary = strong
	reduced_motion = calm
	Style.action_button(self, accent, primary)
	var s: float = Style.ui_scale(self)
	for key in ["normal", "hover", "pressed"]:
		var box: StyleBoxFlat = get_theme_stylebox(key).duplicate()
		box.bg_color = accent.darkened(0.13 if key == "pressed" else 0.0).lightened(0.06 if key == "hover" else 0.0) if primary else Color("#fffdf8")
		box.border_color = accent.darkened(0.2) if primary else accent.lightened(0.62)
		box.border_width_bottom = ceili((2 if key == "pressed" else 4) / s)
		box.shadow_color = Color("#33395625")
		box.shadow_size = ceili((1 if key == "pressed" else 4) / s)
		box.shadow_offset = Vector2(0, 2 / s)
		add_theme_stylebox_override(key, box)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		add_theme_color_override(key, Color.WHITE if primary else Color("#3e4663"))
	var focus := Style.box(Color.TRANSPARENT, Color("#3e4663"), ceili(14 / s), ceili(2 / s))
	focus.set_expand_margin_all(3 / s)
	add_theme_stylebox_override("focus", focus)
	queue_redraw()


func pulse() -> void:
	_pulse = 1.0
	queue_redraw()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var target: float = 1.0 if (is_hovered() or has_focus()) and not disabled else 0.0
	if _ripple < 1.0 or _pulse > 0.0 or not is_equal_approx(_hover, target):
		_hover = move_toward(_hover, target, delta * 8.0)
		_ripple = minf(1.0, _ripple + delta * 2.5)
		_pulse = maxf(0.0, _pulse - delta * 2.4)
		_clock += delta
		queue_redraw()


func _draw() -> void:
	if size.x < 24 or disabled:
		return
	var s: float = Style.ui_scale(self)
	var edge := Rect2(Vector2(8, 5) / s, size - Vector2(16, 10) / s)
	var color := Color.WHITE if primary else accent
	color.a = 0.16 + _hover * 0.14
	draw_line(edge.position + Vector2(5, 0), Vector2(edge.end.x - 5, edge.position.y), color, 1.0 / s, true)
	if _ripple < 1.0 and not reduced_motion:
		color.a = (1.0 - _ripple) * 0.32
		var center := Vector2(size.x * 0.5, size.y * 0.5)
		var radius: float = minf(size.y * 0.42, 9.0 / s + _ripple * size.y * 0.4)
		draw_arc(center, radius, 0.0, TAU, 32, color, 2.0 / s, true)
	if _pulse > 0.0:
		var glow := Style.box(Color.TRANSPARENT, Color(accent.lightened(0.4), _pulse * 0.8), ceili(12 / s), ceili(2 / s))
		draw_style_box(glow, Rect2(Vector2.ZERO, size).grow(-2 / s))
