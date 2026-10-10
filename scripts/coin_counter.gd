extends Control
## The durable wallet and this arrival-driven display deliberately differ in flight.

const Style = preload("res://scripts/ui_style.gd")
const COIN = preload("res://assets/coins/gold-coin.png")
var displayed: float = 0.0
var target: int = 0
var reduced_motion: bool = false
var available: bool = true
var _from: float = 0.0
var _elapsed: float = 0.4
var _pulse: float = 0.0


func _init() -> void:
	name = "CoinBalance"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func sync(value: int) -> void:
	target = value
	displayed = float(value)
	_elapsed = 0.4
	_pulse = 0.0
	_update_description()
	queue_redraw()


func arrive(value: int) -> void:
	_from = displayed
	target = value
	_elapsed = 0.0
	_pulse = 1.0 if not reduced_motion else 0.0
	if reduced_motion:
		displayed = float(target)
	_update_description()
	queue_redraw()


func advance(delta: float) -> void:
	_elapsed = minf(0.4, _elapsed + delta)
	_pulse = maxf(0.0, _pulse - delta * 3.8)
	if displayed != float(target):
		var p: float = _elapsed / 0.4
		displayed = lerpf(_from, float(target), 1.0 - pow(1.0 - p, 3.0))
		if _elapsed >= 0.4:
			displayed = float(target)
		queue_redraw()
	elif _pulse > 0.0:
		queue_redraw()


func _update_description() -> void:
	tooltip_text = "%d coins" % target if available else "Coin balance unavailable. Retry saving."
	set("accessibility_name", tooltip_text)


func icon_center() -> Vector2:
	return global_position + Vector2(size.y * 0.52, size.y * 0.5)


func _draw() -> void:
	var s: float = Style.ui_scale(self)
	var background := Style.box(Color("#fff2cd"), Color("#d5b370"), ceili(size.y * 0.5), maxi(1, roundi(1 / s)))
	draw_style_box(background, Rect2(Vector2.ZERO, size))
	var coin_size: float = size.y * (0.92 + 0.08 * _pulse)
	draw_texture_rect(COIN, Rect2(Vector2(size.y * 0.52, size.y * 0.5) - Vector2.ONE * coin_size * 0.5, Vector2.ONE * coin_size), false)
	var font: Font = Style.HEADING_FONT
	var text: String = str(maxi(0, target)) if available else "—"
	var digits: int = text.length()
	var pixels: int = ceili(14 / s)
	var width: float = maxf(1.0, size.x - size.y - 8 / s)
	while pixels > ceili(9 / s) and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > width:
		pixels -= 1
	var cell: float = minf(width / digits, font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x + 1 / s)
	var x: float = size.y + (width - cell * digits) * 0.5
	var baseline: float = (size.y - font.get_height(pixels)) * 0.5 + font.get_ascent(pixels)
	if not available:
		draw_string(font, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, width, pixels, Color("#765025"))
		return
	for index in range(digits):
		var place: float = pow(10.0, digits - index - 1)
		var value: float = displayed / place
		var digit: int = floori(value) % 10
		var offset: float = clampf((fmod(value, 1.0) - (1.0 - 1.0 / place)) * place, 0.0, 1.0)
		if displayed == float(target) or reduced_motion:
			offset = 0.0
		var at := Vector2(x + index * cell, baseline - offset * size.y)
		draw_string(font, at, str(digit), HORIZONTAL_ALIGNMENT_LEFT, cell, pixels, Color("#765025"))
		if offset > 0.0:
			draw_string(font, at + Vector2(0, size.y), str((digit + 1) % 10), HORIZONTAL_ALIGNMENT_LEFT, cell, pixels, Color("#765025"))
