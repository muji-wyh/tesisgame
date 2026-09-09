extends Control

var texture: Texture2D
var pieces: int = 0
var fragment_index: int = -1
var accent: Color = Color("#438363")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func configure(image: Texture2D, count: int, color: Color, fragment: int = -1) -> void:
	texture = image
	pieces = clampi(count, 0, 3)
	accent = color
	fragment_index = clampi(fragment, -1, 2)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.46
	if radius <= 0.0:
		return
	var image_rect := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	if fragment_index < 0:
		draw_circle(center, radius, accent.lightened(0.92))
		draw_arc(center, radius, 0.0, TAU, 64, accent.lightened(0.5), 2.0, true)
	if texture != null and pieces == 3 and fragment_index < 0:
		draw_texture_rect(texture, image_rect, false)
		return
	for index in range(3):
		if fragment_index >= 0 and index != fragment_index:
			continue
		var points := PackedVector2Array([center])
		var uvs := PackedVector2Array([Vector2.ONE * 0.5])
		for step in range(25):
			var angle: float = -PI * 0.5 + TAU * (float(index) + float(step) / 24.0) / 3.0
			var point := center + Vector2(cos(angle), sin(angle)) * radius
			points.append(point)
			uvs.append((point - image_rect.position) / image_rect.size)
		if texture != null and (index < pieces or fragment_index >= 0):
			draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, texture)
		if fragment_index >= 0:
			points.append(center)
			draw_polyline(points, accent, 2.0, true)
		elif pieces < 3:
			draw_line(center, points[1], accent.lightened(0.45), 2.0, true)
