extends Control
## A readable clock with an elastic beat and a light travelling with real time.

const Style = preload("res://scripts/ui_style.gd")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")

var remaining: float = 0.0
var duration: float = 0.0
var seconds: int = 0
var reduced_motion: bool = false
var _beat: float = 0.0
var _age: float = 0.0
var _accent := Color("#47bcb1")
var _track_style := Style.box(Color(Style.INK, 0.09), Color.TRANSPARENT, 0, 0)
var _fill_style := Style.box(Color.WHITE, Color.TRANSPARENT, 0, 0)
var _shine_style := Style.box(Color(1, 1, 1, 0.5), Color.TRANSPARENT, 0, 0)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_process(false)
	hide()


func configure(left: float, total: float, palette: Dictionary, reduce: bool) -> void:
	remaining = maxf(0.0, left)
	duration = maxf(0.0, total)
	reduced_motion = reduce
	_accent = Color("#47bcb1").lerp(palette.get("accent", Style.GOOD), 0.22)
	var next_seconds: int = ceili(remaining)
	if next_seconds != seconds:
		seconds = next_seconds
		_beat = 0.42 if seconds > 0 else 0.0
		set("accessibility_name", "Cards hide in %d seconds." % seconds if seconds > 0 else "")
	if remaining <= 0.0:
		_age = 0.0
		_beat = 0.0
	set_process(remaining > 0.0 and not reduced_motion)
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	_beat = maxf(0.0, _beat - delta)
	queue_redraw()


func progress() -> float:
	return clampf(remaining / duration, 0.0, 1.0) if duration > 0.0 else 0.0


func text_rect() -> Rect2:
	var unit: float = 1.0 / Style.ui_scale(self)
	return Rect2(Vector2.ZERO, Vector2(60.0 * unit, size.y))


func bar_rect() -> Rect2:
	var unit: float = 1.0 / Style.ui_scale(self)
	var left: float = 66.0 * unit
	return Rect2(Vector2(left, size.y * 0.5 - 4.5 * unit), Vector2(maxf(0.0, size.x - left - 8.0 * unit), 9.0 * unit))


func snapshot() -> Dictionary:
	var area := Rect2(global_position, size)
	var bar := bar_rect()
	bar.position += global_position
	var number := text_rect()
	number.position += global_position
	return {"visible": is_visible_in_tree(), "seconds": seconds, "progress": progress(),
		"rect": [area.position.x, area.position.y, area.size.x, area.size.y],
		"bar_rect": [bar.position.x, bar.position.y, bar.size.x, bar.size.y],
		"text_rect": [number.position.x, number.position.y, number.size.x, number.size.y]}


func _draw() -> void:
	if remaining <= 0.0 or size.x <= 0.0:
		return
	var unit: float = 1.0 / Style.ui_scale(self)
	var urgency: float = 1.0 - smoothstep(1.0, 4.0, remaining)
	var tint: Color = _accent.lerp(Color("#f2aa52"), urgency)
	var ink: Color = Style.INK.lerp(Color("#9c531f"), urgency * 0.9)
	var beat: float = _beat / 0.42
	var elapsed: float = 0.42 - _beat
	var spring: float = 0.0 if reduced_motion else exp(-elapsed * 9.0) * sin(elapsed * 23.0)
	var number_scale := Vector2(1.0 + spring * 0.14, 1.0 + spring * (0.24 + urgency * 0.10))
	var number_center: Vector2 = text_rect().get_center()
	var glow_side: float = (38.0 + urgency * 8.0) * unit
	draw_texture_rect(GLOW, Rect2(number_center - Vector2.ONE * glow_side * 0.5, Vector2.ONE * glow_side), false,
		Color(tint, 0.17 + (0.0 if reduced_motion else beat * 0.32)))
	draw_set_transform(number_center - (number_center * number_scale), 0.0, number_scale)
	var label: String = "%ds" % seconds
	var pixels: int = maxi(1, roundi(27.0 * unit))
	var width: float = Style.HEADING_FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	var origin := Vector2(number_center.x - width * 0.5,
		number_center.y + Style.HEADING_FONT.get_ascent(pixels) - Style.HEADING_FONT.get_height(pixels) * 0.5)
	draw_string(Style.HEADING_FONT, origin + Vector2(0, unit), label, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, Color.WHITE)
	draw_string(Style.HEADING_FONT, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, ink)
	draw_set_transform(Vector2.ZERO)
	var track: Rect2 = bar_rect()
	if not track.has_area():
		return
	var radius: int = maxi(1, ceili(track.size.y * 0.5))
	_track_style.set_corner_radius_all(radius)
	_fill_style.set_corner_radius_all(radius)
	_fill_style.bg_color = tint
	_shine_style.set_corner_radius_all(maxi(1, ceili(unit)))
	draw_style_box(_track_style, track)
	var length: float = track.size.x * progress()
	if length <= 0.0:
		return
	var fill := Rect2(track.position, Vector2(length, track.size.y))
	var edge := Vector2(fill.end.x, fill.get_center().y)
	var glow_size := Vector2(minf(length + 18.0 * unit, track.size.x), 25.0 * unit)
	draw_texture_rect(GLOW, Rect2(fill.get_center() - glow_size * 0.5, glow_size), false, Color(tint, 0.34))
	draw_style_box(_fill_style, fill)
	var shine := Rect2(fill.position + Vector2(3, 1.0) * unit, Vector2(maxf(0.0, length - 6 * unit), 2 * unit))
	if shine.has_area():
		draw_style_box(_shine_style, shine)
	if not reduced_motion and length > 16.0 * unit:
		var sweep: float = fmod(_age * (0.75 + urgency * 0.5), 1.0)
		var point := Vector2(fill.position.x + length * sweep, fill.get_center().y)
		var side: float = (8.0 + sin(sweep * PI) * 5.0) * unit
		draw_texture_rect(SPARKLE, Rect2(point - Vector2.ONE * side * 0.5, Vector2.ONE * side), false,
			Color(1, 1, 1, sin(sweep * PI) * 0.9))
	var pulse: float = 0.0 if reduced_motion else sin(_age * (7.0 + urgency * 7.0)) * 0.5 + 0.5
	var tip_side: float = (18.0 + pulse * (4.0 + urgency * 3.0)) * unit
	draw_texture_rect(GLOW, Rect2(edge - Vector2.ONE * tip_side * 0.5, Vector2.ONE * tip_side), false, Color(tint.lightened(0.25), 0.75))
	var glint_side: float = (9.0 + pulse * 3.0) * unit
	draw_texture_rect(SPARKLE, Rect2(edge - Vector2.ONE * glint_side * 0.5, Vector2.ONE * glint_side), false, Color("#fff8de"))
