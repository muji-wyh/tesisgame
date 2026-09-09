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
	control.add_theme_color_override("font_hover_color", INK)
	control.add_theme_color_override("font_pressed_color", INK)
	control.add_theme_color_override("font_hover_pressed_color", INK)
	control.add_theme_color_override("font_disabled_color", INK)
	control.add_theme_stylebox_override("normal", box(Color.WHITE, accent.lightened(0.6)))
	control.add_theme_stylebox_override("hover", box(accent.lightened(0.92), accent))
	control.add_theme_stylebox_override("pressed", box(accent.lightened(0.8), accent, 16, 3))
	control.add_theme_stylebox_override("disabled", box(Color("#edf0f1"), Color("#d8dde1")))
	control.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, accent, 16, 4))


static func label(text: String, font_size: int = 24) -> Label:
	var control := Label.new()
	control.text = text
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_theme_font_size_override("font_size", font_size)
	control.add_theme_color_override("font_color", INK)
	control.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return control
