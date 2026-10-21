extends Button

const Style = preload("res://scripts/ui_style.gd")
enum Symbol { MORE, VOICE, HINT, EYE, BACK, NEXT, HOME, REFRESH }
const ART := {
	Symbol.MORE: preload("res://assets/images/ui/controls/menu.svg"),
	Symbol.VOICE: preload("res://assets/images/ui/controls/microphone.svg"),
	Symbol.HINT: preload("res://assets/images/ui/controls/bulb.svg"),
	Symbol.EYE: preload("res://assets/images/ui/controls/eye-closed.svg"),
	Symbol.BACK: preload("res://assets/images/ui/controls/chevron-left.svg"),
	Symbol.NEXT: preload("res://assets/images/ui/controls/chevron-right.svg"),
	Symbol.HOME: preload("res://assets/images/ui/controls/home.svg"),
	Symbol.REFRESH: preload("res://assets/images/ui/controls/refresh.svg")
}
const ACTIVE_VOICE = preload("res://assets/images/ui/controls/microphone-active.svg")
const OPEN_EYE = preload("res://assets/images/ui/controls/eye.svg")

var symbol: Symbol = Symbol.MORE:
	set(value):
		symbol = value
		queue_redraw()
var engaged: bool = false:
	set(value):
		engaged = value
		queue_redraw()
var count: int = -1:
	set(value):
		count = value
		queue_redraw()
var count_anchor := Vector2(0.78, 0.78)


func _icon_color() -> Color:
	return get_theme_color("font_disabled_color" if disabled else "font_pressed_color" if button_pressed else "font_color")


func _icon_texture() -> Texture2D:
	if engaged and symbol == Symbol.VOICE:
		return ACTIVE_VOICE
	if engaged and symbol == Symbol.EYE:
		return OPEN_EYE
	return ART.get(symbol, ART[Symbol.MORE])


func _draw() -> void:
	var center := size * 0.5
	var side: float = minf(size.x, size.y) * 0.64
	var ink: Color = _icon_color()
	draw_texture_rect(_icon_texture(), Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side), false, ink)
	if count >= 0:
		var badge := size * count_anchor
		draw_circle(badge, minf(size.x, size.y) * 0.17, Color.WHITE)
		var font: Font = get_theme_font("font")
		var font_size: int = maxi(1, roundi(size.y * 0.27))
		var width: float = font.get_string_size(str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, badge + Vector2(-width * 0.5, font_size * 0.35), str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
