extends RefCounted

const INK := Color("#35415e")
const MUTED := Color("#65708a")
const GOOD := Color("#4e966a")
const WRONG := Color("#c46a59")


static func draw_match_badge(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	canvas.draw_circle(center, radius, GOOD)
	canvas.draw_arc(center, radius, 0.0, TAU, 28, GOOD.darkened(0.15), 2.0, true)
	canvas.draw_circle(center + Vector2(-radius * 0.32, -radius * 0.32), radius * 0.18, Color(1, 1, 1, 0.35))
	var check := PackedVector2Array([
		center + Vector2(-radius * 0.48, -radius * 0.02),
		center + Vector2(-radius * 0.16, radius * 0.31),
		center + Vector2(radius * 0.50, -radius * 0.36)
	])
	canvas.draw_polyline(check, Color.WHITE, maxf(2.2, radius * 0.2), true)


static func box(fill: Color, border: Color, radius: int = 16, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


static func button(control: Button, accent: Color, minimum_width: float = 72.0) -> void:
	control.custom_minimum_size = Vector2(minimum_width, 72)
	control.focus_mode = Control.FOCUS_ALL
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.add_theme_font_size_override("font_size", 20)
	control.add_theme_color_override("font_color", INK)
	control.add_theme_color_override("font_focus_color", INK)
	control.add_theme_color_override("font_hover_color", INK)
	control.add_theme_color_override("font_pressed_color", INK)
	control.add_theme_color_override("font_hover_pressed_color", INK)
	control.add_theme_color_override("font_disabled_color", INK)
	control.add_theme_stylebox_override("normal", box(Color.WHITE, accent.lightened(0.6)))
	control.add_theme_stylebox_override("hover", box(accent.lightened(0.92), accent))
	control.add_theme_stylebox_override("pressed", box(accent.lightened(0.8), accent, 16, 3))
	control.add_theme_stylebox_override("disabled", box(Color("#edf0f1"), Color("#d8dde1")))
	control.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, accent, 16, 4))


static func quiet_button(control: Button, accent: Color, minimum_width: float = 72.0) -> void:
	button(control, accent, minimum_width)
	control.add_theme_stylebox_override("normal", box(Color.TRANSPARENT, Color.TRANSPARENT, 16, 0))
	control.add_theme_stylebox_override("hover", box(accent.lightened(0.94), Color.TRANSPARENT, 16, 0))
	control.add_theme_stylebox_override("pressed", box(accent.lightened(0.85), Color.TRANSPARENT, 16, 0))
	control.add_theme_stylebox_override("disabled", box(Color.TRANSPARENT, Color.TRANSPARENT, 16, 0))
	control.add_theme_color_override("font_disabled_color", MUTED)
	control.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, accent, 16, 2))


static func primary_button(control: Button, accent: Color) -> void:
	button(control, accent)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		control.add_theme_color_override("font_" + state + "_color" if state != "normal" else "font_color", Color.WHITE)
	control.add_theme_stylebox_override("normal", box(accent, accent, 16, 0))
	control.add_theme_stylebox_override("hover", box(accent.darkened(0.08), accent, 16, 0))
	control.add_theme_stylebox_override("pressed", box(accent.darkened(0.16), accent, 16, 0))


static func action_button(control: Button, accent: Color, primary: bool = false) -> void:
	button(control, accent, 0)
	var scale: float = ui_scale(control)
	var radius: int = ceili(12 / scale)
	var border: int = maxi(1, roundi(1 / scale))
	var fill: Color = accent.lightened(0.84) if primary else Color.WHITE
	var edge: Color = accent.lightened(0.45 if primary else 0.72)
	control.add_theme_stylebox_override("normal", box(fill, edge, radius, border))
	control.add_theme_stylebox_override("hover", box(accent.lightened(0.9 if not primary else 0.77), accent.lightened(0.35), radius, border))
	control.add_theme_stylebox_override("pressed", box(accent.lightened(0.66 if primary else 0.82), accent, radius, border))
	control.add_theme_stylebox_override("disabled", box(Color("#edf0f1"), Color("#d8dde1"), radius, border))
	control.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, accent, radius, maxi(2, roundi(2 / scale))))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var surface: StyleBox = control.get_theme_stylebox(state)
		surface.content_margin_left = 12 / scale
		surface.content_margin_right = 12 / scale
		surface.content_margin_top = 6 / scale
		surface.content_margin_bottom = 6 / scale
	control.custom_minimum_size = Vector2(0, ceilf(48 / scale))
	control.add_theme_font_size_override("font_size", ceili(14 / scale))
	control.autowrap_mode = TextServer.AUTOWRAP_OFF


static func ui_scale(control: Control) -> float:
	if not control.is_inside_tree():
		return 1.0
	var value: float = float(control.get_window().size.x) / control.get_viewport().get_visible_rect().size.x
	if OS.has_feature("web"):
		value /= float(JavaScriptBridge.get_interface("window").devicePixelRatio)
	return maxf(value, 2.0 / 3.0)


static func square_icon_button(control: Button, accent: Color) -> void:
	var focus: int = control.focus_mode
	quiet_button(control, accent, 0)
	control.focus_mode = focus
	var scale: float = ui_scale(control)
	control.custom_minimum_size = Vector2.ONE * ceilf(44 / scale)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	control.size_flags_horizontal = Control.SIZE_SHRINK_END
	control.add_theme_font_size_override("font_size", ceili(14 / scale))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := control.get_theme_stylebox(state) as StyleBoxFlat
		style.set_corner_radius_all(maxi(1, roundi(4 / scale)))


static func label(text: String, font_size: int = 24) -> Label:
	var control := Label.new()
	control.text = text
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", INK)
	control.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return control
