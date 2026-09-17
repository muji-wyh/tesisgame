extends Button

const Style = preload("res://scripts/ui_style.gd")
enum Symbol { MORE, VOICE, HINT, EYE, BACK, NEXT }

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


func _draw() -> void:
	var center := size * 0.5
	var unit: float = minf(size.x, size.y) * (0.27 if symbol == Symbol.VOICE else 0.24)
	var stroke: float = maxf(1, unit * 0.17)
	var ink: Color = get_theme_color("font_disabled_color" if disabled else "font_pressed_color" if button_pressed else "font_color")
	match symbol:
		Symbol.BACK:
			draw_polyline(PackedVector2Array([
				center + Vector2(unit * 0.4, -unit),
				center + Vector2(-unit * 0.6, 0),
				center + Vector2(unit * 0.4, unit)
			]), ink, stroke, true)
		Symbol.NEXT:
			draw_polyline(PackedVector2Array([
				center + Vector2(-unit * 0.4, -unit),
				center + Vector2(unit * 0.6, 0),
				center + Vector2(-unit * 0.4, unit)
			]), ink, stroke, true)
		Symbol.MORE:
			for row in [-1, 0, 1]:
				draw_line(center + Vector2(-unit, row * unit * 0.7), center + Vector2(unit, row * unit * 0.7), ink, stroke, true)
		Symbol.VOICE:
			draw_arc(center + Vector2(0, -unit * 0.4), unit * 0.35, PI, TAU, 12, ink, stroke, true)
			draw_arc(center + Vector2(0, unit * 0.4), unit * 0.35, 0, PI, 12, ink, stroke, true)
			for side in [-1, 1]:
				draw_line(center + Vector2(side * unit * 0.35, -unit * 0.4), center + Vector2(side * unit * 0.35, unit * 0.4), ink, stroke, true)
			draw_arc(center + Vector2(0, unit * 0.1), unit * 0.7, 0, PI, 16, ink, stroke, true)
			draw_line(center + Vector2(0, unit * 0.8), center + Vector2(0, unit * 1.1), ink, stroke, true)
			draw_line(center + Vector2(-unit * 0.4, unit * 1.1), center + Vector2(unit * 0.4, unit * 1.1), ink, stroke, true)
			if engaged:
				for side in [-1, 1]:
					var angle: float = 0 if side == 1 else PI
					draw_arc(center - Vector2(0, unit * 0.1), unit * 1.1, angle - 0.46, angle + 0.46, 12, ink, stroke, true)
		Symbol.HINT:
			draw_circle(center - Vector2(0, unit * 0.25), unit * 0.65, ink, false, stroke, true)
			for line in [0.5, 0.8]:
				draw_line(center + Vector2(-unit * 0.3, unit * line), center + Vector2(unit * 0.3, unit * line), ink, stroke, true)
			for angle in [-PI * 0.8, -PI * 0.5, -PI * 0.2]:
				var direction := Vector2.from_angle(angle)
				draw_line(center + direction * unit, center + direction * unit * 1.2, ink, stroke, true)
		Symbol.EYE:
			var upper := PackedVector2Array()
			var lower := PackedVector2Array()
			for index in range(21):
				var t: float = index / 20.0
				upper.append(center + Vector2(lerpf(-unit, unit, t), -sin(t * PI) * unit * 0.55))
				lower.append(center + Vector2(lerpf(-unit, unit, t), sin(t * PI) * unit * 0.55))
			draw_polyline(lower, ink, stroke, true)
			if engaged:
				draw_polyline(upper, ink, stroke, true)
				draw_circle(center, unit * 0.24, ink)
			else:
				for side in [-1, 0, 1]:
					var point := center + Vector2(side * unit * 0.65, unit * (0.55 if side == 0 else 0.36))
					draw_line(point, point + Vector2(side * unit * 0.2, unit * 0.35), ink, stroke, true)
	if count >= 0:
		var badge := size * 0.78
		draw_circle(badge, minf(size.x, size.y) * 0.17, Color.WHITE)
		var font: Font = get_theme_font("font")
		var font_size: int = maxi(1, roundi(size.y * 0.27))
		var width: float = font.get_string_size(str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, badge + Vector2(-width * 0.5, font_size * 0.35), str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
