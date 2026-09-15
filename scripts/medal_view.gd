extends Control

var texture: Texture2D
var pieces: int = 0
var fragment_index: int = -1
var accent: Color = Color("#438363")
var show_missing: bool = false
var mystery_egg: bool = false
var _wiggle: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func() -> void:
		stop_wiggle()
		queue_redraw())
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			stop_wiggle())


func configure(image: Texture2D, count: int, color: Color, fragment: int = -1) -> void:
	texture = image
	pieces = clampi(count, 0, 3)
	accent = color
	fragment_index = clampi(fragment, -1, 2)
	queue_redraw()


func wiggle(reduced_motion: bool) -> void:
	stop_wiggle()
	if reduced_motion or not is_visible_in_tree():
		return
	pivot_offset = size * 0.5
	_wiggle = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_wiggle.tween_property(self, "rotation", -0.1, 0.08)
	_wiggle.tween_property(self, "rotation", 0.075, 0.1)
	_wiggle.tween_property(self, "rotation", 0.0, 0.12)


func stop_wiggle() -> void:
	if _wiggle == null:
		return
	_wiggle.kill()
	_wiggle = null
	rotation = 0.0
	scale = Vector2.ONE


func _draw_mystery(center: Vector2, radius: float) -> void:
	var shell := PackedVector2Array()
	for index in range(65):
		var angle: float = TAU * index / 64.0
		shell.append(center + Vector2(cos(angle) * radius * (0.76 + sin(angle) * 0.12), sin(angle) * radius))
	draw_colored_polygon(shell, accent.lightened(0.88))
	draw_polyline(shell, accent.lightened(0.4), maxf(1, radius * 0.04), true)
	for side in [-1, 1]:
		var eye: Vector2 = center + Vector2(side * radius * 0.23, -radius * 0.12)
		draw_circle(eye, radius * 0.12, Color.WHITE)
		draw_circle(eye + Vector2(radius * 0.025, radius * 0.015), radius * 0.055, Color("#35415e"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-radius * 0.14, radius * 0.07),
		center + Vector2(0, radius * 0.01),
		center + Vector2(radius * 0.14, radius * 0.07),
		center + Vector2(0, radius * 0.15)
	]), Color("#eda54a"))
	for point in [Vector2(-0.32, 0.5), Vector2(0.3, 0.65), Vector2(0.1, -0.64)]:
		draw_circle(center + point * radius, radius * 0.065, accent.lightened(0.65))


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.46
	if radius <= 0.0:
		return
	if mystery_egg and pieces == 0 and fragment_index < 0:
		_draw_mystery(center, radius)
		return
	var image_rect := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	if fragment_index < 0:
		draw_circle(center, radius, accent.lightened(0.92))
		draw_arc(center, radius, 0.0, TAU, 64, accent.lightened(0.5), 2.0, true)
	if texture != null and pieces == 3 and fragment_index < 0:
		draw_texture_rect(texture, image_rect, false)
		return
	if show_missing and texture != null and fragment_index < 0:
		draw_texture_rect(texture, image_rect, false, Color(1, 1, 1, 0.3))
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
