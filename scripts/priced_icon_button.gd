extends "res://scripts/icon_button.gd"
## Keep an action, its coin price, and payment feedback in one stable target.

const COIN = preload("res://assets/coins/gold-coin.png")
const FEEDBACK_SECONDS: float = 0.38
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")

var cost: int = 0:
	set(value):
		cost = maxi(0, value)
		set("accessibility_name", _price_description())
		queue_redraw()
var reduced_motion: bool = false
var _feedback_left: float = 0.0
var _accepted: bool = true


func _init() -> void:
	count_anchor = Vector2(0.84, 0.34)


func _price_description() -> String:
	return "Costs %d coins." % cost


func feedback(success: bool) -> void:
	_accepted = success
	_feedback_left = _feedback_duration()
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


func _feedback_duration() -> float:
	return (0.66 if _accepted else 0.48) if symbol == Symbol.HINT else FEEDBACK_SECONDS


func _icon_color() -> Color:
	if symbol == Symbol.HINT and _feedback_left > 0.0:
		return Color("#98611f") if _accepted else Color("#af554e")
	return super._icon_color()


func _draw_hint_feedback(center: Vector2, strength: float, s: float) -> void:
	var t: float = 1.0 - strength
	var light: float = (0.65 if reduced_motion else minf(1.0, t / 0.10) * pow(strength, 0.65))
	var tint := Color("#ffd574") if _accepted else Color("#eea098")
	var side: float = minf(size.x, size.y) * (1.45 if _accepted else 1.05)
	draw_texture_rect(GLOW, Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side), false, Color(tint, light * 0.9))
	if not _accepted:
		return
	for index in range(3):
		var direction := Vector2.from_angle(-PI * (0.86 - index * 0.36))
		var radius: float = (14.0 + (0.0 if reduced_motion else t * 7.0)) / s
		var edge: float = (7.0 if index == 1 else 5.5) / s
		var point: Vector2 = center + direction * radius
		draw_texture_rect(SPARKLE, Rect2(point - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), false, Color("#fff3cb", light))


func _draw() -> void:
	var s: float = Style.ui_scale(self)
	var strength: float = _feedback_left / _feedback_duration()
	var wave: float = sin((1.0 - strength) * PI)
	var motion: float = 0.0 if reduced_motion else wave
	if strength > 0.0:
		var tint := Color("#ffcb68" if symbol == Symbol.HINT else "#59bb92") if _accepted else Color("#d67468")
		draw_style_box(Style.box(Color(tint, strength * 0.2), Color.TRANSPARENT, ceili(12 / s), 0), Rect2(Vector2.ZERO, size))
	# Transform only the artwork, leaving the touch target in place.
	var icon_scale: float = 0.92 + (0.12 * motion if _accepted else 0.0)
	var shake: float = sin((1.0 - strength) * TAU * 3.0) * motion * 2.0 / s if not _accepted else 0.0
	var center := Vector2(size.x * 0.5 + shake, size.y * 0.32)
	var tilt: float = 0.0
	if symbol == Symbol.HINT and strength > 0.0:
		var t: float = 1.0 - strength
		if not reduced_motion:
			if _accepted:
				var spring: float = sin(t * PI * 2.5) * pow(strength, 1.5)
				icon_scale = 0.92 + spring * 0.26
				center.y -= maxf(0.0, spring) * 4.0 / s
				tilt = sin(t * TAU) * strength * 0.09
			else:
				center.x = size.x * 0.5 + sin(t * TAU * 3.0) * pow(strength, 1.3) * 5.5 / s
				tilt = sin(t * TAU * 3.0) * strength * 0.17
				icon_scale = 0.92 - sin(t * PI) * 0.10
		_draw_hint_feedback(center, strength, s)
	draw_set_transform(center - (size * 0.5 * icon_scale).rotated(tilt), tilt, Vector2.ONE * icon_scale)
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
	var celebrating: bool = symbol == Symbol.HINT and strength > 0.0
	var tint := Color(1, 1, 1, 0.45 if disabled and not celebrating else 1.0)
	draw_texture_rect(COIN, Rect2(Vector2(x, area.get_center().y - coin_side * 0.5), Vector2.ONE * coin_side), false, tint)
	var ink: Color = _icon_color() if celebrating else get_theme_color("font_disabled_color" if disabled else "font_color")
	var baseline: float = area.position.y + (area.size.y - font.get_height(pixels)) * 0.5 + font.get_ascent(pixels)
	draw_string(font, Vector2(x + coin_side + gap, baseline), value, HORIZONTAL_ALIGNMENT_LEFT, text_width, pixels, ink)
