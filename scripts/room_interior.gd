extends RefCounted

const Style = preload("res://scripts/ui_style.gd")
const FLOOR_HEIGHT := 0.57
const SIDE_FLOOR_HEIGHT := 0.70
const EDGE_RADIUS := 24.0


static func floor_y_at(dimensions: Vector2, x: float) -> float:
	var inset := minf(dimensions.x * 0.13, 92.0)
	var distance_to_side := minf(x, dimensions.x - x)
	var depth := clampf(distance_to_side / maxf(1.0, inset), 0.0, 1.0)
	return dimensions.y * lerpf(SIDE_FLOOR_HEIGHT, FLOOR_HEIGHT, depth)


static func draw_room(canvas: Control, palette: Dictionary, theme_id: String) -> void:
	var width := canvas.size.x
	var height := canvas.size.y
	if width < 4.0 or height < 4.0:
		return
	var accent: Color = palette.get("accent", Color("#438363"))
	var tint: Color = palette.get("light", Color("#bfe9c5"))
	var wall := Color("#f7f2e6").lerp(tint, 0.32)
	var wood := Color("#dbc5a3").lerp(tint, 0.13)
	var trim := Color("#fff8e9").lerp(tint, 0.09)
	var shadow := Color("#425044").lerp(accent, 0.20)
	var radius := minf(EDGE_RADIUS, minf(width, height) * 0.2)
	var inset := minf(width * 0.13, 92.0)
	var ceiling_y := maxf(height * 0.095, minf(26.0, height * 0.22))
	var floor_y := height * FLOOR_HEIGHT
	var side_floor_y := height * SIDE_FLOOR_HEIGHT
	var back := Rect2(Vector2(inset, ceiling_y), Vector2(width - inset * 2.0, floor_y - ceiling_y))
	canvas.draw_style_box(Style.box(wall, Color.TRANSPARENT, int(radius), 0), Rect2(Vector2.ZERO, canvas.size))

	var ceiling := PackedVector2Array()
	_append_arc(ceiling, Vector2(radius, radius), radius - 1.0, PI, PI * 1.5)
	_append_arc(ceiling, Vector2(width - radius, radius), radius - 1.0, PI * 1.5, TAU)
	ceiling.append(Vector2(back.end.x, ceiling_y))
	ceiling.append(back.position)
	_vertical_gradient(canvas, ceiling, trim, wall.darkened(0.10), 0.0, ceiling_y)
	_vertical_gradient(canvas, _rectangle(back), wall.lightened(0.05), wall.darkened(0.035), ceiling_y, floor_y)

	var left_wall := PackedVector2Array([
		Vector2(1.0, radius), back.position,
		Vector2(inset, floor_y), Vector2(1.0, side_floor_y)
	])
	var right_wall := PackedVector2Array([
		Vector2(back.end.x, ceiling_y), Vector2(width - 1.0, radius),
		Vector2(width - 1.0, side_floor_y), Vector2(back.end.x, floor_y)
	])
	canvas.draw_polygon(left_wall, PackedColorArray([
		wall.darkened(0.09), wall.darkened(0.035), wall.darkened(0.10), wall.darkened(0.16)
	]))
	canvas.draw_polygon(right_wall, PackedColorArray([
		wall.darkened(0.15), wall.darkened(0.21), wall.darkened(0.26), wall.darkened(0.16)
	]))
	_draw_wall_finish(canvas, back, inset, side_floor_y, width, wall, trim, shadow)

	var floor := PackedVector2Array([
		Vector2(1.0, side_floor_y), Vector2(inset, floor_y),
		Vector2(back.end.x, floor_y), Vector2(width - 1.0, side_floor_y)
	])
	_append_arc(floor, Vector2(width - radius, height - radius), radius - 1.0, 0.0, PI * 0.5)
	_append_arc(floor, Vector2(radius, height - radius), radius - 1.0, PI * 0.5, PI)
	_vertical_gradient(canvas, floor, wood.darkened(0.12), wood.lightened(0.12), floor_y, height)
	_draw_floor_boards(canvas, floor, Vector2(width * 0.48, height * 0.26), wood, canvas.size)
	_draw_skirting(canvas, back, width, side_floor_y, trim, shadow)

	if height >= 105.0 and width >= 160.0:
		var window_height := minf(height * 0.31, 142.0)
		var window_width := minf(back.size.x * 0.32, 172.0)
		var window_top := maxf(ceiling_y + 11.0, minf(43.0, height * 0.18))
		window_height = minf(window_height, floor_y - window_top - 13.0)
		var window := Rect2(Vector2(width * 0.67 - window_width * 0.5, window_top), Vector2(window_width, window_height))
		_draw_daylight(canvas, window, floor, height, theme_id)
		_draw_window(canvas, window, theme_id, trim, wood)
		if height >= 230.0 and width >= 245.0:
			_draw_wall_details(canvas, back, window, tint, accent, wood, theme_id)

	_draw_rug(canvas, Vector2(width * 0.48, height * 0.80), Vector2(width * 0.25, height * 0.093), tint, accent)
	var outline := Style.box(Color.TRANSPARENT, Color("#6e7666").lerp(accent, 0.25).lightened(0.42), int(radius), 1)
	canvas.draw_style_box(outline, Rect2(Vector2.ONE * 0.5, canvas.size - Vector2.ONE))


static func _draw_wall_finish(canvas: Control, back: Rect2, inset: float, side_floor_y: float, width: float, wall: Color, trim: Color, shadow: Color) -> void:
	var panel_top := lerpf(back.position.y, back.end.y, 0.74)
	var panel_tint := wall.darkened(0.035)
	var height := back.end.y - panel_top
	_vertical_gradient(canvas, _rectangle(Rect2(back.position.x, panel_top, back.size.x, height)), panel_tint, wall.darkened(0.085), panel_top, back.end.y)
	var side_panel_y := lerpf(minf(24.0, back.position.y), side_floor_y, 0.74)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(1.0, side_panel_y), Vector2(inset, panel_top),
		Vector2(inset, back.end.y), Vector2(1.0, side_floor_y)
	]), wall.darkened(0.14))
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(back.end.x, panel_top), Vector2(width - 1.0, side_panel_y),
		Vector2(width - 1.0, side_floor_y), Vector2(back.end.x, back.end.y)
	]), wall.darkened(0.23))
	var rail := PackedVector2Array([Vector2(2.0, side_panel_y), Vector2(inset, panel_top), Vector2(back.end.x, panel_top), Vector2(width - 2.0, side_panel_y)])
	canvas.draw_polyline(rail, _alpha(shadow, 0.16), 3.0, true)
	canvas.draw_polyline(_shift(rail, Vector2(0.0, -1.5)), trim.darkened(0.08), 2.0, true)
	if height > 22.0:
		var panels := maxi(3, int(back.size.x / 76.0))
		for index in range(1, panels):
			var x := back.position.x + back.size.x * index / panels
			canvas.draw_line(Vector2(x, panel_top + 5.0), Vector2(x, back.end.y - 3.0), _alpha(shadow, 0.11), 1.0, true)
			canvas.draw_line(Vector2(x + 1.0, panel_top + 5.0), Vector2(x + 1.0, back.end.y - 3.0), _alpha(trim, 0.40), 1.0, true)
	var cornice := PackedVector2Array([Vector2(2.0, minf(24.0, back.position.y)), back.position, Vector2(back.end.x, back.position.y), Vector2(width - 2.0, minf(24.0, back.position.y))])
	canvas.draw_polyline(_shift(cornice, Vector2(0.0, 3.0)), _alpha(shadow, 0.13), 3.0, true)
	canvas.draw_polyline(cornice, trim, 3.0, true)
	canvas.draw_line(back.position + Vector2(1.0, 5.0), Vector2(back.position.x + 1.0, back.end.y), _alpha(shadow, 0.10), 2.0, true)
	canvas.draw_line(Vector2(back.end.x - 1.0, back.position.y + 5.0), back.end - Vector2(1.0, 0.0), _alpha(shadow, 0.17), 3.0, true)


static func _draw_floor_boards(canvas: Control, floor: PackedVector2Array, vanishing: Vector2, wood: Color, room_size: Vector2) -> void:
	var board_width := clampf(room_size.x / 9.0, 32.0, 96.0)
	var columns := int(ceil(room_size.x / board_width)) + 6
	for index in range(-3, columns - 3):
		var left := float(index) * board_width
		var right := left + board_width
		var board := PackedVector2Array([vanishing, Vector2(left, room_size.y + 1.0), Vector2(right, room_size.y + 1.0)])
		var tone := Color.WHITE if posmod(index, 3) == 0 else Color("#947254")
		for clipped in Geometry2D.intersect_polygons(board, floor):
			canvas.draw_colored_polygon(clipped, _alpha(tone, 0.045 if posmod(index, 3) == 0 else 0.035))
		var seam := _line_in_polygon(vanishing, Vector2(left, room_size.y + 1.0), floor)
		if seam.size() == 2:
			canvas.draw_line(seam[0], seam[1], _alpha(wood.darkened(0.42), 0.32), 1.0, true)
			canvas.draw_line(seam[0] + Vector2(1.0, 0.0), seam[1] + Vector2(1.0, 0.0), _alpha(Color("#fff5dc"), 0.32), 1.0, true)
		for grain in range(2):
			var endpoint := Vector2(left + board_width * (0.29 + grain * 0.37), room_size.y + 1.0)
			var line := _line_in_polygon(vanishing, endpoint, floor)
			if line.size() == 2:
				var start := line[0].lerp(line[1], 0.22 + posmod(index + grain, 3) * 0.14)
				canvas.draw_line(start, line[0].lerp(line[1], 0.93), _alpha(wood.darkened(0.38), 0.065), 1.0, true)
		for row in range(2):
			var y := room_size.y * (0.70 + row * 0.18 + posmod(index, 3) * 0.045)
			if y >= room_size.y - 4.0:
				continue
			var progress := (y - vanishing.y) / (room_size.y + 1.0 - vanishing.y)
			var start := vanishing.lerp(Vector2(left, room_size.y + 1.0), progress)
			var end := vanishing.lerp(Vector2(right, room_size.y + 1.0), progress)
			if Geometry2D.is_point_in_polygon(start, floor) and Geometry2D.is_point_in_polygon(end, floor):
				canvas.draw_line(start, end, _alpha(wood.darkened(0.40), 0.23), 1.0, true)


static func _draw_skirting(canvas: Control, back: Rect2, width: float, side_floor_y: float, trim: Color, shadow: Color) -> void:
	var depth := clampf(back.size.y * 0.045, 3.0, 8.0)
	var top := PackedVector2Array([Vector2(1.0, side_floor_y - depth), Vector2(back.position.x, back.end.y - depth), Vector2(back.end.x, back.end.y - depth), Vector2(width - 1.0, side_floor_y - depth)])
	var bottom := _shift(top, Vector2(0.0, depth))
	for index in range(3):
		var face := PackedVector2Array([top[index], top[index + 1], bottom[index + 1], bottom[index]])
		canvas.draw_colored_polygon(face, trim.darkened(0.13 if index == 0 else (0.22 if index == 2 else 0.03)))
	canvas.draw_polyline(_shift(bottom, Vector2(0.0, 2.0)), _alpha(shadow, 0.14), 4.0, true)
	canvas.draw_polyline(bottom, _alpha(shadow, 0.25), 1.0, true)
	canvas.draw_polyline(top, trim.lightened(0.1), 1.5, true)


static func _draw_daylight(canvas: Control, window: Rect2, floor: PackedVector2Array, height: float, theme_id: String) -> void:
	var light := Color("#fff7c9") if theme_id != "space" else Color("#e5e8ff")
	var top_left := Vector2(window.position.x - window.size.x * 0.15, height * 0.61)
	var top_right := top_left + Vector2(window.size.x * 0.88, 0.0)
	var offset := Vector2(-window.size.x * 0.92, height * 0.30)
	var patch := PackedVector2Array([top_left, top_right, top_right + offset + Vector2(window.size.x * 0.60, 0.0), top_left + offset])
	for clipped in Geometry2D.intersect_polygons(patch, floor):
		canvas.draw_colored_polygon(clipped, _alpha(light, 0.24))
	var middle := top_left.lerp(top_right, 0.5)
	canvas.draw_line(middle, middle + offset + Vector2(window.size.x * 0.30, 0.0), _alpha(Color("#afa995"), 0.13), 3.0, true)
	canvas.draw_line(top_left.lerp(top_left + offset, 0.54), top_right.lerp(top_right + offset + Vector2(window.size.x * 0.60, 0.0), 0.54), _alpha(Color("#afa995"), 0.10), 2.5, true)


static func _draw_window(canvas: Control, opening: Rect2, theme_id: String, trim: Color, wood: Color) -> void:
	var frame := opening.grow(6.0)
	canvas.draw_style_box(Style.box(Color(0.20, 0.24, 0.19, 0.07), Color.TRANSPARENT, 4, 0), Rect2(frame.position + Vector2(3.0, 6.0), frame.size + Vector2(3.0, 1.0)))
	canvas.draw_style_box(Style.box(trim.darkened(0.13), wood.darkened(0.21), 3, 1), frame)
	canvas.draw_style_box(Style.box(trim, Color.TRANSPARENT, 2, 0), Rect2(frame.position, frame.size - Vector2(2.0, 3.0)))
	canvas.draw_rect(opening.grow(1.0), wood.darkened(0.29))
	_draw_outside(canvas, opening, theme_id)
	canvas.draw_line(opening.position, Vector2(opening.position.x, opening.end.y), Color(0.22, 0.30, 0.29, 0.18), 3.0, true)
	canvas.draw_line(opening.position, Vector2(opening.end.x, opening.position.y), Color(0.22, 0.30, 0.29, 0.20), 3.0, true)
	var cross_x := opening.get_center().x
	var cross_y := opening.position.y + opening.size.y * 0.47
	canvas.draw_line(Vector2(cross_x + 1.5, opening.position.y), Vector2(cross_x + 1.5, opening.end.y), trim.darkened(0.28), 5.0, true)
	canvas.draw_line(Vector2(opening.position.x, cross_y + 1.5), Vector2(opening.end.x, cross_y + 1.5), trim.darkened(0.28), 5.0, true)
	canvas.draw_line(Vector2(cross_x, opening.position.y), Vector2(cross_x, opening.end.y), trim, 3.5, true)
	canvas.draw_line(Vector2(opening.position.x, cross_y), Vector2(opening.end.x, cross_y), trim, 3.5, true)
	var sill := PackedVector2Array([
		Vector2(frame.position.x - 3.0, frame.end.y - 1.0), Vector2(frame.end.x + 3.0, frame.end.y - 1.0),
		Vector2(frame.end.x + 7.0, frame.end.y + 4.0), Vector2(frame.position.x - 5.0, frame.end.y + 4.0)
	])
	canvas.draw_colored_polygon(_shift(sill, Vector2(0.0, 4.0)), Color(0.25, 0.29, 0.22, 0.10))
	canvas.draw_colored_polygon(sill, trim.lightened(0.04))
	canvas.draw_line(sill[3], sill[2], trim.darkened(0.22), 3.0, true)
	var reflection := PackedVector2Array([
		opening.position + Vector2(opening.size.x * 0.07, 3.0), opening.position + Vector2(opening.size.x * 0.18, 3.0),
		opening.position + Vector2(opening.size.x * 0.40, opening.size.y * 0.84), opening.position + Vector2(opening.size.x * 0.31, opening.size.y * 0.84)
	])
	canvas.draw_colored_polygon(reflection, Color(1.0, 1.0, 1.0, 0.10))


static func _draw_outside(canvas: Control, area: Rect2, theme_id: String) -> void:
	var sky_top := Color("#afd9d8")
	var sky_bottom := Color("#e9efca")
	var distant := Color("#96b99a")
	var near := Color("#75a685")
	match theme_id:
		"summer":
			sky_top = Color("#8fcddc"); sky_bottom = Color("#ffebbc"); distant = Color("#b6c189"); near = Color("#8eab76")
		"autumn":
			sky_top = Color("#c7d2cf"); sky_bottom = Color("#f6dcac"); distant = Color("#d3af78"); near = Color("#b78b61")
		"winter":
			sky_top = Color("#a5bedc"); sky_bottom = Color("#e8f1f7"); distant = Color("#c0d5de"); near = Color("#edf3ed")
		"ocean":
			sky_top = Color("#a4d8de"); sky_bottom = Color("#e0f3e5"); distant = Color("#69b8c8"); near = Color("#439bad")
		"space":
			sky_top = Color("#344566"); sky_bottom = Color("#8d88b5"); distant = Color("#8885a8"); near = Color("#666587")
		"jungle":
			sky_top = Color("#a1c6b2"); sky_bottom = Color("#d7deb0"); distant = Color("#75a583"); near = Color("#4d826a")
		"candy":
			sky_top = Color("#d2b7d8"); sky_bottom = Color("#f6d9d9"); distant = Color("#b8cbb7"); near = Color("#91bbae")
	_vertical_gradient(canvas, _rectangle(area), sky_top, sky_bottom, area.position.y, area.end.y)
	var orb := area.position + area.size * Vector2(0.76, 0.25)
	var orb_radius := minf(area.size.x, area.size.y) * 0.105
	canvas.draw_circle(orb, orb_radius * 1.40, Color(1.0, 0.98, 0.85, 0.08))
	canvas.draw_circle(orb, orb_radius, Color("#f5eccb") if theme_id == "space" else Color("#fff4d5"))
	if theme_id == "space":
		for index in range(9):
			var point := area.position + area.size * Vector2(0.10 + fmod(index * 0.17, 0.80), 0.09 + fmod(index * 0.13, 0.45))
			canvas.draw_circle(point, 0.75 if index % 2 == 0 else 1.0, Color("#ece4ce"))
	else:
		var cloud_center := area.position + area.size * Vector2(0.27, 0.25)
		_ellipse(canvas, cloud_center, Vector2(area.size.x * 0.12, area.size.y * 0.04), Color(1.0, 1.0, 0.95, 0.46))
		_ellipse(canvas, cloud_center + Vector2(area.size.x * 0.06, -area.size.y * 0.028), Vector2(area.size.x * 0.08, area.size.y * 0.055), Color(1.0, 1.0, 0.95, 0.43))
	var horizon := area.position.y + area.size.y * 0.67
	if theme_id == "ocean":
		canvas.draw_rect(Rect2(area.position.x, horizon, area.size.x, area.end.y - horizon), distant)
		canvas.draw_rect(Rect2(area.position.x, horizon + area.size.y * 0.14, area.size.x, area.size.y * 0.19), near)
		for index in range(4):
			var y := horizon + area.size.y * (0.055 + index * 0.055)
			var x := area.position.x + area.size.x * (0.06 + index % 2 * 0.28)
			canvas.draw_line(Vector2(x, y), Vector2(x + area.size.x * 0.38, y), Color(0.93, 0.98, 0.92, 0.29), 1.0, true)
	else:
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(area.position.x, horizon), area.position + area.size * Vector2(0.24, 0.49),
			area.position + area.size * Vector2(0.58, 0.69), area.position + area.size * Vector2(0.85, 0.52),
			Vector2(area.end.x, horizon), area.end, Vector2(area.position.x, area.end.y)
		]), distant)
		canvas.draw_colored_polygon(PackedVector2Array([
			area.position + area.size * Vector2(0.0, 0.82), area.position + area.size * Vector2(0.32, 0.71),
			area.position + area.size * Vector2(0.73, 0.87), area.position + area.size * Vector2(1.0, 0.72),
			area.end, Vector2(area.position.x, area.end.y)
		]), near)
		if theme_id in ["spring", "autumn", "jungle", "home"]:
			var tree := area.position + area.size * Vector2(0.17, 0.79)
			canvas.draw_line(tree, tree - Vector2(0.0, area.size.y * 0.24), near.darkened(0.24), 2.0, true)
			_ellipse(canvas, tree - Vector2(0.0, area.size.y * 0.23), Vector2(area.size.x * 0.09, area.size.y * 0.16), Color("#bb895d") if theme_id == "autumn" else near.darkened(0.06))


static func _draw_wall_details(canvas: Control, back: Rect2, window: Rect2, tint: Color, accent: Color, wood: Color, theme_id: String) -> void:
	var picture_width := clampf(back.size.x * 0.18, 32.0, 72.0)
	var picture_height := minf(picture_width * 1.14, back.size.y * 0.44)
	var picture := Rect2(Vector2(back.position.x + back.size.x * 0.16, back.position.y + back.size.y * 0.21), Vector2(picture_width, picture_height))
	if picture.end.x + 18.0 > window.position.x:
		return
	canvas.draw_style_box(Style.box(Color(0.23, 0.24, 0.19, 0.08), Color.TRANSPARENT, 2, 0), Rect2(picture.position + Vector2(2.0, 4.0), picture.size))
	canvas.draw_style_box(Style.box(Color("#faf3df"), wood.darkened(0.27), 1, 3), picture)
	var art := picture.grow(-7.0)
	canvas.draw_rect(art, tint.lightened(0.29))
	canvas.draw_circle(art.position + art.size * Vector2(0.70, 0.29), minf(art.size.x, art.size.y) * 0.12, Color("#ecd19a"))
	canvas.draw_colored_polygon(PackedVector2Array([
		art.position + art.size * Vector2(0.0, 0.74), art.position + art.size * Vector2(0.34, 0.40),
		art.position + art.size * Vector2(0.74, 0.84), art.position + art.size * Vector2(1.0, 0.62),
		art.end, Vector2(art.position.x, art.end.y)
	]), accent.lightened(0.50))
	var shelf_y := minf(back.end.y - 20.0, picture.end.y + 32.0)
	var shelf_width := minf(back.size.x * 0.29, 120.0)
	var shelf_x := picture.get_center().x - shelf_width * 0.5
	canvas.draw_style_box(Style.box(Color(0.22, 0.25, 0.18, 0.07), Color.TRANSPARENT, 3, 0), Rect2(shelf_x + 2.0, shelf_y + 6.0, shelf_width + 3.0, 6.0))
	canvas.draw_rect(Rect2(shelf_x, shelf_y, shelf_width, 5.0), wood.darkened(0.16))
	canvas.draw_rect(Rect2(shelf_x - 1.0, shelf_y - 2.0, shelf_width + 2.0, 3.0), wood.lightened(0.09))
	canvas.draw_line(Vector2(shelf_x + 9.0, shelf_y + 5.0), Vector2(shelf_x + 9.0, shelf_y + 11.0), wood.darkened(0.29), 2.0, true)
	canvas.draw_line(Vector2(shelf_x + shelf_width - 9.0, shelf_y + 5.0), Vector2(shelf_x + shelf_width - 9.0, shelf_y + 11.0), wood.darkened(0.29), 2.0, true)
	var pot_base := Vector2(shelf_x + shelf_width * 0.75, shelf_y - 2.0)
	var plant_scale := clampf(shelf_width / 100.0, 0.62, 1.0)
	_draw_plant(canvas, pot_base, plant_scale, accent)
	for index in range(3):
		var book_height := 13.0 + index % 2 * 5.0
		var book_color: Color = [Color("#c49578"), accent.lightened(0.40), Color("#d6bd88")][index]
		canvas.draw_rect(Rect2(shelf_x + 10.0 + index * 6.0, shelf_y - book_height - 2.0, 5.0, book_height), book_color)
		canvas.draw_line(Vector2(shelf_x + 11.0 + index * 6.0, shelf_y - 6.0), Vector2(shelf_x + 14.0 + index * 6.0, shelf_y - 6.0), Color(1.0, 0.95, 0.80, 0.65), 1.0)
	if theme_id == "spring":
		canvas.draw_circle(pot_base + Vector2(0.0, -35.0) * plant_scale, 3.0 * plant_scale, Color("#e5a9b6"))


static func _draw_plant(canvas: Control, base: Vector2, scale: float, accent: Color) -> void:
	var stem := base - Vector2(0.0, 10.0) * scale
	canvas.draw_line(stem, stem - Vector2(1.0, 23.0) * scale, accent.darkened(0.08), 1.5, true)
	for index in range(4):
		var side := -1.0 if index % 2 == 0 else 1.0
		var start := stem - Vector2(0.0, 5.0 + index * 5.0) * scale
		var leaf := PackedVector2Array([
			start, start + Vector2(side * 11.0, -2.0) * scale,
			start + Vector2(side * 14.0, -12.0) * scale,
			start + Vector2(side * 4.0, -9.0) * scale
		])
		canvas.draw_colored_polygon(leaf, accent.lightened(0.22 + index % 2 * 0.12))
	var pot := PackedVector2Array([
		base + Vector2(-8.0, -12.0) * scale, base + Vector2(8.0, -12.0) * scale,
		base + Vector2(6.0, 0.0) * scale, base + Vector2(-6.0, 0.0) * scale
	])
	canvas.draw_polygon(pot, PackedColorArray([Color("#dfb092"), Color("#c28e73"), Color("#b5826b"), Color("#d7a386")]))
	_ellipse(canvas, base - Vector2(0.0, 12.0) * scale, Vector2(8.0, 2.0) * scale, Color("#ae8068"))


static func _draw_rug(canvas: Control, center: Vector2, radius: Vector2, tint: Color, accent: Color) -> void:
	if radius.y < 5.0:
		return
	_ellipse(canvas, center + Vector2(1.0, 3.0), radius + Vector2(3.0, 2.0), Color(0.24, 0.25, 0.18, 0.05))
	_ellipse(canvas, center + Vector2(0.0, 1.5), radius, Color("#9a9980").lerp(accent, 0.12).lightened(0.25))
	var fabric := Color("#e9e4ca").lerp(tint, 0.30)
	_ellipse(canvas, center, radius, fabric)
	canvas.draw_polyline(_ellipse_points(center, radius - Vector2(5.0, 2.5)), _alpha(accent.lightened(0.28), 0.20), 1.5, true)
	canvas.draw_polyline(_ellipse_points(center, radius - Vector2(9.0, 4.0)), _alpha(Color.WHITE, 0.36), 1.0, true)
	for index in range(8):
		var offset_y := (-0.66 + index * 0.19) * radius.y
		var half_width := sqrt(maxf(0.0, 1.0 - pow(offset_y / radius.y, 2.0))) * (radius.x - 13.0)
		canvas.draw_line(center + Vector2(-half_width, offset_y), center + Vector2(half_width, offset_y), Color(1.0, 1.0, 0.92, 0.085), 1.0, true)


static func _vertical_gradient(canvas: Control, polygon: PackedVector2Array, top: Color, bottom: Color, start_y: float, end_y: float) -> void:
	var colors := PackedColorArray()
	for point in polygon:
		colors.append(top.lerp(bottom, clampf((point.y - start_y) / maxf(1.0, end_y - start_y), 0.0, 1.0)))
	canvas.draw_polygon(polygon, colors)


static func _rectangle(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


static func _append_arc(points: PackedVector2Array, center: Vector2, radius: float, start: float, end: float) -> void:
	for index in range(7):
		points.append(center + Vector2.from_angle(lerpf(start, end, index / 6.0)) * radius)


static func _shift(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var shifted := PackedVector2Array()
	for point in points:
		shifted.append(point + offset)
	return shifted


static func _ellipse(canvas: Control, center: Vector2, radius: Vector2, color: Color) -> void:
	canvas.draw_colored_polygon(_ellipse_points(center, radius), color)


static func _ellipse_points(center: Vector2, radius: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(49):
		points.append(center + Vector2.from_angle(index * TAU / 48.0) * radius)
	return points


static func _alpha(color: Color, opacity: float) -> Color:
	return Color(color.r, color.g, color.b, opacity)


static func _line_in_polygon(start: Vector2, end: Vector2, polygon: PackedVector2Array) -> PackedVector2Array:
	var intersections: Array[Vector2] = []
	for index in range(polygon.size()):
		var point: Variant = Geometry2D.segment_intersects_segment(start, end, polygon[index], polygon[(index + 1) % polygon.size()])
		if point != null:
			intersections.append(point)
	if intersections.size() < 2:
		return PackedVector2Array()
	intersections.sort_custom(func(a: Vector2, b: Vector2) -> bool: return start.distance_squared_to(a) < start.distance_squared_to(b))
	return PackedVector2Array([intersections.front(), intersections.back()])
