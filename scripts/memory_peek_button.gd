extends "res://scripts/icon_button.gd"
## Keep the reveal gesture and its next price together in one square target.

const COIN = preload("res://assets/coins/gold-coin.png")
const FEEDBACK_SECONDS: float = 0.38

var cost: int = 0:
	set(value):
		cost = maxi(0, value)
		set("accessibility_name", "Hold to reveal all cards. Release to hide unmatched cards. " + ("Next reveal is free." if cost == 0 else "Next reveal costs %d coins." % cost))
		queue_redraw()
var reduced_motion: bool = false
var _feedback_left: float = 0.0
var _accepted: bool = true


func feedback(success: bool) -> void:
	_accepted = success
	_feedback_left = FEEDBACK_SECONDS
	set_process(true)
	queue_redraw()


func reset_feedback() -> void:
	_feedback_left = 0.0
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	_feedback_left = maxf(0.0, _feedback_left - delta)
	set_process(_feedback_left > 0.0)
	queue_redraw()


func price_rect() -> Rect2:
	return Rect2(Vector2(size.x * 0.08, size.y * 0.57), Vector2(size.x * 0.84, size.y * 0.34))


func _draw() -> void:
	var s: float = Style.ui_scale(self)
	var strength: float = _feedback_left / FEEDBACK_SECONDS
	var wave: float = sin((1.0 - strength) * PI)
	var motion: float = 0.0 if reduced_motion else wave
	if strength > 0.0:
		var tint := Color("#59bb92") if _accepted else Color("#d67468")
		draw_style_box(Style.box(Color(tint, strength * 0.2), Color.TRANSPARENT, ceili(12 / s), 0), Rect2(Vector2.ZERO, size))
	# Transform only the artwork, leaving the touch target in place.
	var icon_scale: float = 0.92 + (0.12 * motion if _accepted else 0.0)
	var shake: float = sin((1.0 - strength) * TAU * 3.0) * motion * 2.0 / s if not _accepted else 0.0
	var center := Vector2(size.x * 0.5 + shake, size.y * 0.32)
	draw_set_transform(center - size * 0.5 * icon_scale, 0.0, Vector2.ONE * icon_scale)
	super._draw()
	draw_set_transform(Vector2.ZERO)
	var area := price_rect()
	var font: Font = Style.HEADING_FONT
	var pixels: int = ceili(11 / s)
	var value: String = str(cost)
	var coin_side: float = 12 / s
	var gap: float = 1 / s
	while pixels > ceili(9 / s) and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x + coin_side + gap > area.size.x:
		pixels -= 1
	var text_width: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	var x: float = area.get_center().x - (coin_side + gap + text_width) * 0.5
	var tint := Color(1, 1, 1, 0.45 if disabled else 1.0)
	draw_texture_rect(COIN, Rect2(Vector2(x, area.get_center().y - coin_side * 0.5), Vector2.ONE * coin_side), false, tint)
	var ink: Color = get_theme_color("font_disabled_color" if disabled else "font_color")
	var baseline: float = area.position.y + (area.size.y - font.get_height(pixels)) * 0.5 + font.get_ascent(pixels)
	draw_string(font, Vector2(x + coin_side + gap, baseline), value, HORIZONTAL_ALIGNMENT_LEFT, text_width, pixels, ink)
