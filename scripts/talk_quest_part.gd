extends Button
## Shape and label both identify a workshop part, independent of its color.

var shape_id: String = "wheel"


func _draw() -> void:
	var side: float = minf(size.x, size.y) * 0.54
	var p := Vector2(size.x * 0.5, size.y * 0.4)
	var ink := Color("#48516c")
	var fill := Color("#b5d7cc")
	var stroke: float = maxf(2, side * 0.04)
	match shape_id:
		"wheel":
			draw_circle(p, side * 0.42, ink)
			draw_circle(p, side * 0.29, fill)
			for index in range(6):
				draw_line(p, p + Vector2.UP.rotated(index * TAU / 6) * side * 0.27, ink, stroke, true)
			draw_circle(p, side * 0.09, ink)
		"wing":
			var points := PackedVector2Array([p + Vector2(-0.48, 0.1) * side, p + Vector2(0.42, -0.36) * side,
				p + Vector2(0.18, 0.36) * side, p + Vector2(-0.18, 0.22) * side])
			draw_colored_polygon(points, Color("#a6bade"))
			points.append(points[0])
			draw_polyline(points, ink, stroke, true)
			draw_line(p + Vector2(-0.25, 0.12) * side, p + Vector2(0.3, -0.22) * side, ink, stroke, true)
		"ribbon":
			for direction in [-1, 1]:
				var points := PackedVector2Array([p, p + Vector2(direction * 0.43, -0.3) * side,
					p + Vector2(direction * 0.4, 0.3) * side])
				draw_colored_polygon(points, Color("#e8a4b5"))
				points.append(p)
				draw_polyline(points, ink, stroke, true)
			draw_circle(p, side * 0.12, ink)
		"screw":
			draw_line(p + Vector2(0, -0.26) * side, p + Vector2(0, 0.42) * side, ink, side * 0.15, true)
			for index in range(4):
				draw_line(p + Vector2(-0.15, -0.12 + index * 0.13) * side, p + Vector2(0.15, -0.2 + index * 0.13) * side, Color("#a1bfd0"), stroke, true)
			draw_circle(p + Vector2(0, -0.26) * side, side * 0.21, Color("#adc5d1"))
			draw_line(p + Vector2(-0.14, -0.26) * side, p + Vector2(0.14, -0.26) * side, ink, stroke, true)
		"key":
			draw_arc(p + Vector2(-0.22, -0.17) * side, side * 0.22, 0, TAU, 24, Color("#d1a24e"), stroke * 2, true)
			draw_line(p, p + Vector2(0.36, 0.28) * side, Color("#d1a24e"), stroke * 2, true)
			for index in range(2):
				var tooth := p + Vector2(0.19 + index * 0.13, 0.12 + index * 0.1) * side
				draw_line(tooth, tooth + Vector2(-0.09, 0.12) * side, Color("#d1a24e"), stroke * 2, true)
