extends Control
## A bounded storybook atlas. Landmarks describe the place, never the creature.

signal level_selected(number: int)
signal chapter_changed(index: int)

const INK := Color("#304d53")
const CHAPTERS: Array = [
	{"title": "COZY BEGINNINGS", "first": 1, "count": 4, "color": "#b8d6a0"},
	{"title": "AROUND TOWN", "first": 5, "count": 6, "color": "#accfb5"},
	{"title": "BEYOND THE GARDEN", "first": 11, "count": 4, "color": "#b9cbd2"}
]

var level_buttons: Array[Button] = []
var reduced_motion: bool = false
var current_chapter: int = 0
var _ui_scale: float = 1.0
var _route_points: Array[Vector2] = []
var _cleared: Dictionary = {}
var _unlocked: Dictionary = {}
var _columns: int = 2
var _current_stop: int = 0
var _previous: Button
var _next: Button
var _header_height: float = 48.0
var _compact: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	_previous = _chapter_button("<", "Previous chapter", -1)
	_next = _chapter_button(">", "Next chapter", 1)
	resized.connect(_layout)


func _chapter_button(caption: String, accessible: String, direction: int) -> Button:
	var button := Button.new()
	button.text = caption
	button.accessibility_name = accessible
	button.tooltip_text = accessible
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func() -> void: set_chapter(current_chapter + direction))
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("#fff7df") if state in ["hover", "pressed", "hover_pressed"] else Color("#eef2d5")
		box.border_color = Color("#4a8778") if state == "focus" else Color("#ffffff55")
		box.set_border_width_all(2 if state == "focus" else 1)
		box.set_corner_radius_all(12)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", Color("#879989"))
	add_child(button)
	return button


func configure(levels: Array) -> void:
	for button in level_buttons:
		remove_child(button)
		button.queue_free()
	level_buttons.clear()
	_route_points.clear()
	_unlocked.clear()
	_cleared.clear()
	_current_stop = 0
	current_chapter = 0
	custom_minimum_size = Vector2.ZERO
	for definition: Dictionary in levels:
		var button := LandmarkButton.new()
		button.configure(definition)
		button.reduced_motion = reduced_motion
		button.pressed.connect(func() -> void: level_selected.emit(button.number))
		add_child(button)
		level_buttons.append(button)
	_layout()


func set_chapter(index: int) -> void:
	var next_chapter: int = clampi(index, 0, CHAPTERS.size() - 1)
	if current_chapter == next_chapter:
		return
	current_chapter = next_chapter
	_layout()
	chapter_changed.emit(current_chapter)


func show_level(number: int) -> void:
	for index in range(CHAPTERS.size()):
		var chapter: Dictionary = CHAPTERS[index]
		if number >= int(chapter.first) and number < int(chapter.first) + int(chapter.count):
			set_chapter(index)
			return


func visible_level_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for button in level_buttons:
		if button.visible:
			result.append(button)
	return result


func navigation_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for button in [_previous, _next]:
		if button.visible and not button.disabled:
			result.append(button)
	return result


func set_ui_scale(value: float) -> void:
	var next_scale: float = maxf(0.1, value)
	if is_equal_approx(_ui_scale, next_scale):
		return
	_ui_scale = next_scale
	_layout()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	for button: LandmarkButton in level_buttons:
		button.reduced_motion = value
		button.queue_redraw()


func set_level_state(number: int, unlocked: bool, cleared: bool) -> void:
	if number < 1 or number > level_buttons.size():
		return
	_unlocked[number] = unlocked
	_cleared[number] = cleared
	var button: LandmarkButton = level_buttons[number - 1]
	button.unlocked = unlocked
	button.cleared = cleared
	button.disabled = not unlocked
	button.focus_mode = Control.FOCUS_ALL if unlocked and button.visible else Control.FOCUS_NONE
	button.update_accessibility()
	button.queue_redraw()
	_update_beacon()
	queue_redraw()


func _update_beacon() -> void:
	var found: bool = false
	var next_stop: int = 0
	for button: LandmarkButton in level_buttons:
		button.current_stop = button.unlocked and not button.cleared and not found
		if button.current_stop:
			found = true
			next_stop = button.number
		button.queue_redraw()
	if next_stop != _current_stop:
		_current_stop = next_stop
		if next_stop > 0:
			show_level(next_stop)


func _layout() -> void:
	custom_minimum_size = Vector2.ZERO
	_previous.visible = not level_buttons.is_empty()
	_next.visible = not level_buttons.is_empty()
	if size.x <= 0 or size.y <= 0 or level_buttons.is_empty():
		queue_redraw()
		return
	var unit: float = 1.0 / _ui_scale
	var width: float = size.x
	var chapter: Dictionary = CHAPTERS[current_chapter]
	var count: int = int(chapter.count)
	_compact = size.y * _ui_scale < 220.0 and width * _ui_scale >= 440.0
	_header_height = (44.0 if _compact else 48.0) * unit
	var margin: float = (4.0 if _compact else 8.0) * unit
	var available_height: float = maxf(0.0, size.y - _header_height - margin)
	_columns = 3 if count == 6 and (width * _ui_scale >= 560 or _compact) else 2
	if not _compact and available_height * _ui_scale < 250.0 and width * _ui_scale >= count * 112.0:
		_columns = count
	var rows: int = ceili(float(count) / _columns)
	var column_width: float = (width - margin * 2.0) / _columns
	var tile_width: float = maxf(1.0, minf(208.0 * unit, column_width - 6.0 * unit))
	var row_height: float = available_height / rows
	var tile_height: float = maxf(1.0, minf(184.0 * unit, row_height - (0.0 if _compact else 4.0 * unit)))
	_previous.position = Vector2(8, 0 if _compact else 2) * unit
	_next.position = Vector2(width - 52.0 * unit, (0.0 if _compact else 2.0) * unit)
	for button in [_previous, _next]:
		button.size = Vector2.ONE * ceilf(44.0 * unit)
		button.add_theme_font_size_override("font_size", ceili(20.0 * unit))
	var lost_focus: bool = (_previous.has_focus() and current_chapter == 0) or (_next.has_focus() and current_chapter == CHAPTERS.size() - 1)
	_previous.disabled = current_chapter == 0
	_next.disabled = current_chapter == CHAPTERS.size() - 1
	_previous.focus_mode = Control.FOCUS_NONE if _previous.disabled else Control.FOCUS_ALL
	_next.focus_mode = Control.FOCUS_NONE if _next.disabled else Control.FOCUS_ALL
	_route_points.clear()
	for button: LandmarkButton in level_buttons:
		button.compact = _compact
		var on_page: bool = button.number >= int(chapter.first) and button.number < int(chapter.first) + count
		lost_focus = lost_focus or (button.has_focus() and not on_page)
		button.visible = on_page
		button.focus_mode = Control.FOCUS_ALL if on_page and not button.disabled else Control.FOCUS_NONE
	for offset in range(count):
		var index: int = int(chapter.first) + offset - 1
		if index >= level_buttons.size():
			break
		var row: int = floori(float(offset) / _columns)
		var column: int = offset % _columns
		if row % 2 == 1:
			column = _columns - 1 - column
		var button: LandmarkButton = level_buttons[index]
		button.position = Vector2(margin + column_width * (column + 0.5) - tile_width * 0.5, _header_height + row * row_height + (row_height - tile_height) * 0.5)
		button.size = Vector2(tile_width, tile_height)
		button.set_ui_scale(_ui_scale)
		_route_points.append(button.position + button.route_anchor())
	if lost_focus:
		var choices: Array[Button] = navigation_buttons()
		if not choices.is_empty():
			choices[0].grab_focus()
	queue_redraw()


func _draw() -> void:
	if size.x <= 0 or level_buttons.is_empty():
		return
	var unit: float = 1.0 / _ui_scale
	draw_rect(Rect2(Vector2.ZERO, size), Color("#dce7cb"))
	var area := Rect2(Vector2.ZERO, size)
	_draw_chapter(area, current_chapter, unit)
	if not _compact:
		_draw_route(unit)
	_draw_chapter_caption(area, current_chapter, unit)
	# Hand-drawn paper edging frames the whole atlas.
	draw_line(Vector2(5, 12) * unit, Vector2(5.0 * unit, size.y - 12.0 * unit), Color("#fbf6de99"), 2.0 * unit, true)
	draw_line(Vector2(size.x - 5.0 * unit, 12.0 * unit), Vector2(size.x - 5.0 * unit, size.y - 12.0 * unit), Color("#fbf6de99"), 2.0 * unit, true)


func _draw_chapter(area: Rect2, index: int, unit: float) -> void:
	var chapter: Dictionary = CHAPTERS[index]
	var tint := Color(chapter.color)
	draw_rect(area, tint.lightened(0.24))
	var land := PackedVector2Array()
	var bottom := PackedVector2Array()
	for step in range(33):
		var x: float = float(step) * size.x / 32.0
		var y: float = area.position.y + 45.0 * unit + sin(float(step) * 0.61 + index) * 16.0 * unit
		land.append(Vector2(x, y))
		bottom.append(Vector2(x, area.end.y - 9.0 * unit + sin(float(step) * 0.8) * 13.0 * unit))
	land.append(Vector2(size.x, area.end.y))
	land.append(Vector2(0, area.end.y))
	draw_colored_polygon(land, tint)
	for point in bottom:
		draw_circle(point, 25.0 * unit, tint.darkened(0.035))
	# Quiet topographic contours add depth around the route.
	for contour in range(3):
		var contour_points := PackedVector2Array()
		for step in range(41):
			var x: float = float(step) * size.x / 40.0
			var y: float = area.position.y + (130.0 + contour * 128.0) * unit
			y += sin(float(step) * 0.32 + contour + index) * 24.0 * unit
			contour_points.append(Vector2(x, y))
		draw_polyline(contour_points, Color("#ffffff14"), 2.0 * unit, true)
	# A ribbon of water lives at the edge of each chapter, leaving the path legible.
	var river := PackedVector2Array()
	var river_x: float = size.x * (0.97 if index % 2 == 0 else 0.03)
	for step in range(31):
		var y: float = area.position.y + float(step) * area.size.y / 30.0
		river.append(Vector2(river_x + sin(float(step) * 0.3 + index) * 20.0 * unit, y))
	draw_polyline(river, Color("#87b7b5"), 28.0 * unit, true)
	draw_polyline(river, Color("#a3d4cf"), 20.0 * unit, true)
	for step in range(7):
		var point: Vector2 = river[step * 4 + 1]
		draw_line(point - Vector2(5, 0) * unit, point + Vector2(5, 0) * unit, Color("#e1f2dc99"), 1.4 * unit, true)
	# Groves and tiny garden details stay in the space between the large landmarks.
	for step in range(11):
		var x: float = (0.07 + fmod(float(step) * 0.263 + index * 0.19, 0.86)) * size.x
		var y: float = area.position.y + (54.0 + fmod(float(step) * 97.0, maxf(80.0, area.size.y / unit - 85.0))) * unit
		var point := Vector2(x, y)
		if _near_stop(point, 83.0 * unit):
			continue
		_draw_tree(point, (0.65 + fmod(float(step) * 0.31, 0.5)) * unit, index == 2)
	for step in range(22):
		var x: float = fmod(float(step) * 79.0 + 34.0, size.x / unit) * unit
		var y: float = area.position.y + (75.0 + fmod(float(step) * 43.0, maxf(70.0, area.size.y / unit - 100.0))) * unit
		draw_circle(Vector2(x, y), 1.9 * unit, Color("#f4edb9") if step % 3 else Color("#f7d5b5"))


func _draw_chapter_caption(area: Rect2, index: int, unit: float) -> void:
	var chapter: Dictionary = CHAPTERS[index]
	var font: Font = get_theme_default_font()
	var title_size: int = ceili((11.0 if size.x * _ui_scale < 360.0 else 13.0) * unit)
	draw_string(font, Vector2(60.0 * unit, area.position.y + 23.0 * unit), str(chapter.title), HORIZONTAL_ALIGNMENT_CENTER, size.x - 120.0 * unit, title_size, INK)
	for dot in range(CHAPTERS.size()):
		draw_circle(Vector2(size.x * 0.5 + (dot - 1) * 13.0 * unit, 36.0 * unit), 3.5 * unit, INK if dot == index else Color("#78928266"))


func _near_stop(point: Vector2, distance: float) -> bool:
	for stop in _route_points:
		if point.distance_to(stop - Vector2(0, 25.0 / _ui_scale)) < distance:
			return true
	return false


func _draw_tree(point: Vector2, unit: float, pine: bool) -> void:
	draw_circle(point + Vector2(4, 6) * unit, 12.0 * unit, Color("#50654d22"))
	draw_line(point, point + Vector2(0, -25) * unit, Color("#94784e"), 5.0 * unit, true)
	if pine:
		for tier in range(3):
			var top: Vector2 = point + Vector2(0, -49 + tier * 10) * unit
			var reach: float = (11.0 + tier * 3.0) * unit
			draw_colored_polygon(PackedVector2Array([top, top + Vector2(reach, 22.0 * unit), top + Vector2(-reach, 22.0 * unit)]), Color("#568779").lightened(tier * 0.035))
	else:
		draw_circle(point + Vector2(-7, -24) * unit, 12.0 * unit, Color("#729455"))
		draw_circle(point + Vector2(7, -26) * unit, 13.0 * unit, Color("#83a260"))
		draw_circle(point + Vector2(-2, -36) * unit, 12.0 * unit, Color("#92b270"))
		draw_circle(point + Vector2(-5, -41) * unit, 4.0 * unit, Color("#b3ca8888"))


func _draw_route(unit: float) -> void:
	for index in range(_route_points.size() - 1):
		var start: Vector2 = _route_points[index]
		var finish: Vector2 = _route_points[index + 1]
		var points := PackedVector2Array()
		var same_row: bool = absf(start.y - finish.y) < 30.0 * unit
		var first_control: Vector2 = start.lerp(finish, 0.33)
		var last_control: Vector2 = start.lerp(finish, 0.66)
		if same_row:
			first_control.y += 34.0 * unit
			last_control.y += 34.0 * unit
		else:
			var bend: float = -48.0 * unit if start.x < size.x * 0.5 else 48.0 * unit
			first_control = start + Vector2(bend, 72.0 * unit)
			last_control = finish + Vector2(bend, -72.0 * unit)
		for step in range(33):
			points.append(start.bezier_interpolate(first_control, last_control, finish, float(step) / 32.0))
		draw_polyline(points, Color("#74805e44"), 19.0 * unit, true)
		draw_polyline(points, Color("#f6e4b5"), 14.0 * unit, true)
		draw_polyline(points, Color("#fff0c7"), 8.0 * unit, true)
		for step in range(2, 31, 5):
			draw_line(points[step], points[step + 1], Color("#c7aa7388"), 2.0 * unit, true)
		if bool(_cleared.get(int(CHAPTERS[current_chapter].first) + index, false)):
			for step in range(3, 30, 6):
				draw_circle(points[step], 2.5 * unit, Color("#7f995a"))


class LandmarkButton extends Button:
	var number: int = 1
	var title: String = ""
	var accent := Color("#dd9f72")
	var unlocked: bool = false
	var cleared: bool = false
	var current_stop: bool = false
	var reduced_motion: bool = false
	var compact: bool = false
	var _caption: Label
	var _ui_scale: float = 1.0
	var _art_unit: float = 1.0
	var _art_top: float = 0.0
	var _time: float = 0.0
	var _lift: float = 0.0
	var _frame_time: float = 0.0

	func _init() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		resized.connect(_layout_labels)

	func configure(definition: Dictionary) -> void:
		number = int(definition.number)
		title = str(definition.title)
		accent = Color(str(definition.get("scene", {}).get("accent", "#dd9f72")))
		disabled = true
		_caption = Label.new()
		_caption.text = title
		_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_caption.add_theme_color_override("font_color", Color("#304d53"))
		add_child(_caption)
		update_accessibility()
		_layout_labels()

	func update_accessibility() -> void:
		var state: String = "Cleared" if cleared else "Ready to explore" if unlocked else "Locked"
		accessibility_name = "Adventure %d: %s. %s." % [number, title, state]
		tooltip_text = "Play " + title if unlocked else "Complete the previous adventure to unlock " + title

	func set_ui_scale(value: float) -> void:
		_ui_scale = value
		_layout_labels()

	func _layout_labels() -> void:
		if _caption == null:
			return
		var unit: float = 1.0 / _ui_scale
		if compact:
			_caption.position = Vector2(38, 2) * unit
			_caption.size = Vector2(maxf(1, size.x - 44 * unit), maxf(1, size.y - 4 * unit))
			_caption.add_theme_font_size_override("font_size", ceili(12 * unit))
			_caption.clip_text = true
			queue_redraw()
			return
		var caption_height: float = minf(size.y, 35.0 * unit)
		_caption.position = Vector2(6.0 * unit, size.y - caption_height)
		_caption.size = Vector2(maxf(1.0, size.x - 12.0 * unit), caption_height)
		_caption.add_theme_font_size_override("font_size", ceili(12.0 * unit))
		_caption.clip_text = true
		_art_unit = maxf(0.0, minf(unit, minf(size.x / 150.0, (_caption.position.y - 4.0 * unit) / 140.0)))
		_art_top = maxf(0.0, (_caption.position.y - _art_unit * 140.0) * 0.5)
		queue_redraw()


	func route_anchor() -> Vector2:
		if compact:
			return Vector2(20 / _ui_scale, size.y * 0.5)
		var badge_radius: float = 24.0 * maxf(_art_unit, 0.72 / _ui_scale)
		return Vector2(size.x * 0.5, maxf(badge_radius, minf(_art_top + 118.0 * _art_unit, _caption.position.y - badge_radius)))


	func compact_badge_rect() -> Rect2:
		# Includes the completed star that extends beyond the number circle.
		var unit: float = 1.0 / _ui_scale
		return Rect2(route_anchor() - Vector2(14, 14) * unit, Vector2(30, 28) * unit)

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		var target: float = 1.0 if not disabled and (is_hovered() or has_focus()) else 0.0
		var previous_lift: float = _lift
		_lift = target if reduced_motion else move_toward(_lift, target, delta * 6.0)
		if not reduced_motion:
			_time += delta
		_frame_time += delta
		if _frame_time >= 1.0 / 20.0 and ((current_stop and not reduced_motion) or not is_equal_approx(_lift, previous_lift)):
			_frame_time = 0.0
			queue_redraw()

	func _draw() -> void:
		if compact:
			_draw_compact()
			return
		var unit: float = 1.0 / _ui_scale
		var center: Vector2 = route_anchor()
		if current_stop:
			var pulse: float = 0.5 if reduced_motion else (sin(_time * 2.0) + 1.0) * 0.5
			draw_circle(center, (30.0 + pulse * 4.0) * _art_unit, Color("#fff8da66"))
			draw_arc(center, (31.0 + pulse * 4.0) * _art_unit, 0, TAU, 48, Color("#fff8e3bb"), 2.0 * _art_unit, true)
		var plaque := Rect2(Vector2(unit, _caption.position.y), Vector2(size.x - 2.0 * unit, _caption.size.y))
		_box(Rect2(plaque.position + Vector2(0, 3.0 * unit), plaque.size), Color("#5b725c22"), Color.TRANSPARENT, 13.0 * unit, 0)
		_box(plaque, Color("#fffaf0") if unlocked else Color("#edf0d9"), Color("#f7e7bf") if unlocked else Color("#a8b997"), 13.0 * unit, unit)
		if has_focus() or (is_hovered() and not disabled):
			_box(Rect2(Vector2.ZERO, size), Color("#ffffff0a"), Color("#4a8778"), 18.0 * unit, 2.5 * unit)
		var pressed_drop: float = 2.0 if is_pressed() else 0.0
		draw_set_transform(Vector2(size.x * 0.5, _art_top + (80.0 - _lift * 4.0 + pressed_drop) * _art_unit), 0.0, Vector2.ONE * _art_unit)
		_ellipse(Vector2(3, 16), Vector2(57, 14), Color("#3a674333"))
		_ellipse(Vector2.ZERO, Vector2(58, 20), Color("#86ad72") if unlocked else Color("#98b58a"))
		_ellipse(Vector2(0, -4), Vector2(58, 19), Color("#d6dbaa") if number >= 11 else Color("#c5d792"))
		_draw_landmark()
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		var badge_unit: float = maxf(_art_unit, unit * 0.72)
		draw_circle(center + Vector2(0, 3.0 * badge_unit), 21.0 * badge_unit, Color("#4b685b33"))
		draw_circle(center, 22.0 * badge_unit, Color("#fff8de"))
		draw_circle(center, 17.5 * badge_unit, Color("#527858") if cleared else accent if unlocked else Color("#8da592"))
		var font: Font = get_theme_default_font()
		var font_size: int = ceili(15.0 * badge_unit)
		var number_text: String = str(number)
		var text_width: float = font.get_string_size(number_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, center + Vector2(-text_width * 0.5, 5.0 * badge_unit), number_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#ffffff") if cleared else Color("#233f49"))
		if cleared:
			_star(center + Vector2(19, -16) * badge_unit, 10.0 * badge_unit, Color("#fff0a0"))
		elif not unlocked:
			var lock_at: Vector2 = center + Vector2(19, -16) * badge_unit
			draw_circle(lock_at, 9.0 * badge_unit, Color("#edf0d9"))
			draw_arc(lock_at + Vector2(0, -2) * badge_unit, 3.0 * badge_unit, PI, TAU, 12, Color("#647d69"), 1.5 * badge_unit, true)
			_box(Rect2(lock_at + Vector2(-4, -1) * badge_unit, Vector2(8, 6) * badge_unit), Color("#647d69"), Color.TRANSPARENT, 1.0 * badge_unit, 0)
		elif number >= 13:
			_star(center + Vector2(20, -15) * badge_unit, 9.0 * badge_unit, Color("#f7d578"))

	func _draw_compact() -> void:
		var unit: float = 1.0 / _ui_scale
		var surface := Rect2(Vector2.ONE * 2 * unit, size - Vector2.ONE * 4 * unit)
		var focused: bool = has_focus() or (is_hovered() and not disabled)
		_box(surface, Color("#fffaf0") if unlocked else Color("#edf0d9"),
			Color("#4a8778") if focused else accent if current_stop else Color("#a8b997"),
			10 * unit, (2.0 if focused or current_stop else 1.0) * unit)
		var center: Vector2 = route_anchor()
		draw_circle(center, 14 * unit, Color("#527858") if cleared else accent if unlocked else Color("#8da592"))
		var font: Font = get_theme_default_font()
		var font_size: int = ceili(12 * unit)
		var value: String = str(number)
		var width: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, center + Vector2(-width * 0.5, 4 * unit), value, HORIZONTAL_ALIGNMENT_LEFT,
			-1, font_size, Color.WHITE if cleared else Color("#233f49"))
		if cleared:
			_star(center + Vector2(11, -9) * unit, 5 * unit, Color("#fff0a0"))


	func _draw_landmark() -> void:
		match number:
			1:
				_house(Color("#efc197"), Color("#ba7967"))
				_box(Rect2(-9, -33, 20, 39), Color("#7aab9d"), Color("#5b8c82"), 4, 2)
				draw_circle(Vector2(5, -14), 2.1, Color("#f7df9a"))
				for x in [-40, 40]:
					_box(Rect2(x - 6, -6, 12, 13), Color("#c78e6b"), Color.TRANSPARENT, 2, 0)
					draw_circle(Vector2(x, -12), 10, Color("#739f6d"))
			2:
				_box(Rect2(-38, -66, 77, 71), Color("#b0d9d1"), Color("#8ebbb7"), 6, 2)
				draw_circle(Vector2(0, -42), 19, Color("#fff5db"))
				draw_circle(Vector2(0, -42), 15, Color("#8dc6ce"))
				draw_line(Vector2(-7, -49), Vector2(8, -38), Color("#cae8df"), 3, true)
				_box(Rect2(-28, -15, 56, 19), Color("#edf3e4"), Color("#96b9b3"), 8, 2)
				draw_arc(Vector2(3, -19), 7, PI, TAU, 16, Color("#5a8d99"), 4, true)
				for p in [Vector2(36, -33), Vector2(-37, -39), Vector2(43, -51)]:
					draw_circle(p, 5, Color("#e4f5efbb"))
					draw_arc(p, 5, 0, TAU, 16, Color("#ffffff"), 1.2, true)
			3:
				_box(Rect2(-42, -48, 83, 45), Color("#e8c996"), Color("#c7ab7a"), 5, 2)
				for x in [-25, 22]:
					_box(Rect2(x - 12, -39, 23, 27), Color("#f5dfb4"), Color("#d0b485"), 3, 1)
					_box(Rect2(x - 3, -27, 6, 2), Color("#af9169"), Color.TRANSPARENT, 1, 0)
				_table(Color("#d3a376"))
				_ellipse(Vector2(-11, -11), Vector2(19, 7), Color("#fff7de"))
				_box(Rect2(-23, -27, 23, 17), Color("#bb8454"), Color.TRANSPARENT, 5, 0)
				_box(Rect2(-20, -25, 17, 13), Color("#f0d39b"), Color.TRANSPARENT, 4, 0)
				_box(Rect2(16, -29, 15, 20), Color("#f3f5e5"), Color("#a9c2b7"), 3, 1)
			4:
				_box(Rect2(-44, -68, 35, 73), Color("#bca0cf"), Color("#947fac"), 4, 2)
				draw_line(Vector2(-27, -62), Vector2(-27, 2), Color("#9a7ca9"), 2, true)
				draw_circle(Vector2(-21, -28), 2, Color("#f3deac"))
				_box(Rect2(-1, -26, 47, 26), Color("#ece0cf"), Color("#a38b7e"), 4, 2)
				_box(Rect2(1, -21, 43, 19), Color("#9bb7d2"), Color.TRANSPARENT, 3, 0)
				_box(Rect2(3, -31, 18, 9), Color("#fff4dc"), Color.TRANSPARENT, 3, 0)
				for x in [0, 44]:
					draw_line(Vector2(x, -6), Vector2(x, 9), Color("#a38b7e"), 4, true)
			5:
				draw_line(Vector2(-36, 6), Vector2(-32, -56), Color("#a88762"), 5, true)
				draw_line(Vector2(-5, 6), Vector2(-9, -56), Color("#a88762"), 5, true)
				draw_line(Vector2(-39, -57), Vector2(-3, -57), Color("#c19768"), 6, true)
				for x in [-27, -15]:
					draw_line(Vector2(x, -54), Vector2(x, -18), Color("#657f78"), 1.5, true)
				draw_line(Vector2(-29, -17), Vector2(-13, -17), Color("#d59475"), 5, true)
				draw_line(Vector2(15, 6), Vector2(15, -40), Color("#9c8567"), 5, true)
				draw_line(Vector2(27, 6), Vector2(27, -41), Color("#9c8567"), 4, true)
				draw_polyline(PackedVector2Array([Vector2(15, -39), Vector2(27, -39), Vector2(48, 1), Vector2(55, 1)]), Color("#e29b79"), 9, true)
				_poly([Vector2(7, -44), Vector2(21, -62), Vector2(34, -44)], Color("#77a6a0"))
			6:
				_box(Rect2(-37, -65, 74, 47), Color("#547f70"), Color("#c29e6f"), 4, 5)
				draw_circle(Vector2(17, -48), 8, Color("#f5dd96"))
				_poly([Vector2(-27, -30), Vector2(-15, -47), Vector2(0, -30)], Color("#c5dfb9"))
				_table(Color("#c59c77"))
				_box(Rect2(-18, -18, 37, 13), Color("#fff7e0"), Color.TRANSPARENT, 1, 0)
				for i in range(3):
					draw_line(Vector2(-29 + i * 8, -26), Vector2(-24 + i * 8, -10), [Color("#d8907d"), Color("#e9c66f"), Color("#7baa9e")][i], 4, true)
			7:
				for x in [-40, 40]:
					draw_line(Vector2(x, 8), Vector2(x, -60), Color("#ad8659"), 4, true)
				_box(Rect2(-45, -28, 90, 28), Color("#c99c68"), Color("#ad8058"), 3, 2)
				_poly([Vector2(-47, -40), Vector2(-36, -64), Vector2(36, -64), Vector2(47, -40)], Color("#fff1cd"))
				for x in [-32, -8, 16]:
					_poly([Vector2(x - 4, -63), Vector2(x + 7, -63), Vector2(x + 10, -40), Vector2(x - 7, -40)], Color("#d79577"))
				for i in range(8):
					draw_circle(Vector2(-31 + i * 9, -29 - (i % 2) * 3), 5, Color("#da8869") if i < 4 else Color("#d9c36a"))
			8:
				_house(Color("#b9c9cf"), Color("#7b94a8"))
				_box(Rect2(-32, -39, 65, 42), Color("#8d7971"), Color("#716766"), 2, 2)
				for shelf in range(2):
					for book in range(7):
						var colors: Array[Color] = [Color("#d6ab7e"), Color("#a1c4b0"), Color("#d69994"), Color("#adb1cc")]
						_box(Rect2(-27 + book * 8, -35 + shelf * 19, 6, 14), colors[(book + shelf) % 4], Color.TRANSPARENT, 1, 0)
					draw_line(Vector2(-32, -18 + shelf * 20), Vector2(33, -18 + shelf * 20), Color("#b29a7d"), 3, true)
			9:
				for x in [-35, 35]:
					_box(Rect2(x - 6, -48, 12, 53), Color("#c4b48a"), Color("#a49771"), 3, 2)
					for leaf in range(4):
						var p := Vector2(x, -53)
						draw_line(p, p + Vector2(20, 0).rotated(float(leaf) * PI / 3.0 + 0.3), Color("#769d69"), 7, true)
				_box(Rect2(-30, -55, 60, 15), Color("#c6a57c"), Color.TRANSPARENT, 3, 0)
				draw_string(get_theme_default_font(), Vector2(-16, -43), "ZOO", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#fff3d5"))
				for x in range(-25, 30, 10):
					draw_line(Vector2(x, -29), Vector2(x, 4), Color("#91a784"), 2, true)
				draw_line(Vector2(-29, -20), Vector2(29, -20), Color("#91a784"), 3, true)
			10:
				_box(Rect2(-48, -8, 96, 17), Color("#aaa993"), Color.TRANSPARENT, 7, 0)
				_box(Rect2(-39, -49, 75, 46), Color("#e3bd67"), Color("#b89d5d"), 8, 2)
				for x in [-29, -9, 11]:
					_box(Rect2(x, -42, 16, 17), Color("#a5cbd0"), Color("#eedd9a"), 2, 2)
				draw_line(Vector2(-36, -19), Vector2(34, -19), Color("#fff0b4"), 3, true)
				for x in [-24, 23]:
					draw_circle(Vector2(x, -5), 9, Color("#586f72"))
					draw_circle(Vector2(x, -5), 4, Color("#d5d9c5"))
			11:
				_ellipse(Vector2(21, 9), Vector2(40, 12), Color("#8fc2bf"))
				_box(Rect2(-32, -36, 42, 40), Color("#e6c993"), Color("#c4ab7e"), 2, 2)
				for x in [-36, -2]:
					_box(Rect2(x, -51, 17, 55), Color("#ead49f"), Color("#c4ab7e"), 2, 2)
					for notch in range(3):
						draw_rect(Rect2(x + notch * 6, -57, 4, 9), Color("#ead49f"))
				_box(Rect2(-21, -13, 18, 18), Color("#b39d76"), Color.TRANSPARENT, 8, 0)
				draw_line(Vector2(31, 2), Vector2(31, -55), Color("#b19a74"), 3, true)
				_poly([Vector2(9, -39), Vector2(31, -61), Vector2(52, -39)], Color("#df9b82"))
				_poly([Vector2(24, -39), Vector2(31, -61), Vector2(39, -39)], Color("#ffe4b9"))
			12:
				_poly([Vector2(-49, 5), Vector2(-13, -55), Vector2(32, 4)], Color("#ce9d75"))
				_poly([Vector2(-13, -55), Vector2(12, -61), Vector2(51, 2), Vector2(32, 4)], Color("#e2b782"))
				_poly([Vector2(-29, 5), Vector2(-12, -30), Vector2(11, 5)], Color("#736f64"))
				for p in [Vector2(-36, -52), Vector2(37, -63), Vector2(50, -32)]:
					_star(p, 5, Color("#fff3bb"))
				draw_line(Vector2(31, 11), Vector2(47, 16), Color("#9a765a"), 5, true)
				draw_line(Vector2(31, 16), Vector2(47, 11), Color("#9a765a"), 5, true)
				_poly([Vector2(31, 10), Vector2(37, -10), Vector2(47, 11)], Color("#e9a069"))
				_poly([Vector2(36, 12), Vector2(39, -1), Vector2(43, 12)], Color("#f8d087"))
			13:
				_box(Rect2(-41, -21, 82, 26), Color("#e9b3ac"), Color("#c88e96"), 7, 2)
				_box(Rect2(-28, -43, 56, 24), Color("#f1d29c"), Color("#cba77f"), 6, 2)
				_box(Rect2(-17, -60, 34, 20), Color("#ead7be"), Color("#caaa9f"), 5, 2)
				for x in [-10, 0, 10]:
					draw_line(Vector2(x, -60), Vector2(x, -72), Color("#bf8daa"), 3, true)
					draw_circle(Vector2(x, -76), 3, Color("#f6db8b"))
				for x in [-48, 48]:
					draw_line(Vector2(x, -17), Vector2(x, -44), Color("#9ba28c"), 1, true)
					_ellipse(Vector2(x, -53), Vector2(9, 12), Color("#9ebcc7") if x < 0 else Color("#daa0af"))
				for x in range(-30, 40, 15):
					draw_circle(Vector2(x, -18), 3, Color("#fff1cd"))
			14:
				_house(Color("#aac7c8"), Color("#829eaf"))
				_box(Rect2(-31, -35, 63, 39), Color("#668994"), Color("#c7d5c5"), 3, 3)
				for x in [-18, 17]:
					draw_circle(Vector2(x, -19), 11, Color("#ddb975"))
					for spoke in range(8):
						var direction := Vector2.UP.rotated(spoke * TAU / 8)
						draw_line(Vector2(x, -19) + direction * 9, Vector2(x, -19) + direction * 14, Color("#ddb975"), 5, true)
					draw_circle(Vector2(x, -19), 5, Color("#668994"))
				_star(Vector2(0, -59), 8, Color("#f4dc97"))

	func _house(wall: Color, roof: Color) -> void:
		_box(Rect2(-38, -49, 76, 55), wall, wall.darkened(0.12), 4, 2)
		_poly([Vector2(-49, -46), Vector2(0, -80), Vector2(49, -46)], roof)
		draw_line(Vector2(-47, -45), Vector2(47, -45), roof.darkened(0.15), 3, true)

	func _table(color: Color) -> void:
		for x in [-33, 33]:
			draw_line(Vector2(x, -4), Vector2(x, 13), color.darkened(0.15), 5, true)
		_box(Rect2(-43, -10, 86, 12), color, color.darkened(0.13), 4, 2)

	func _box(rect: Rect2, color: Color, border: Color, radius: float, width: float) -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = color
		box.border_color = border
		box.set_corner_radius_all(roundi(radius))
		box.set_border_width_all(roundi(width))
		draw_style_box(box, rect)

	func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
		var points := PackedVector2Array()
		for index in range(36):
			points.append(center + Vector2(cos(index * TAU / 36.0), sin(index * TAU / 36.0)) * radii)
		draw_colored_polygon(points, color)

	func _poly(points: Array, color: Color) -> void:
		draw_colored_polygon(PackedVector2Array(points), color)

	func _star(center: Vector2, radius: float, color: Color) -> void:
		var points := PackedVector2Array()
		for index in range(10):
			var reach: float = radius if index % 2 == 0 else radius * 0.46
			points.append(center + Vector2.UP.rotated(index * TAU / 10.0) * reach)
		draw_colored_polygon(points, color)
