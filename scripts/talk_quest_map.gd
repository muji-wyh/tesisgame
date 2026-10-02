extends Control
## A bounded, sourced parchment atlas. Landmarks show places, never creatures.

signal level_selected(number: int)
signal chapter_changed(index: int)

const INK := Color("#493521")
const ART_MANIFEST := "res://assets/talk_quest/map/manifest.json"
const LandmarkButton = preload("res://scripts/talk_quest_map_stop.gd")
const CHAPTERS: Array = [
	{"title": "COZY BEGINNINGS", "first": 1, "count": 4},
	{"title": "AROUND TOWN", "first": 5, "count": 6},
	{"title": "BEYOND THE GARDEN", "first": 11, "count": 4}
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
var _art: Dictionary = {}
var _backgrounds: Array[Texture2D] = []
var _ui: Dictionary = {}
var _transition: float = 1.0
var _previous_chapter: int = 0
var _frame_time: float = 0.0
var _heading_panel: StyleBoxTexture


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	_load_art()
	_heading_panel = StyleBoxTexture.new()
	_heading_panel.texture = _ui.get("panel")
	_heading_panel.set_texture_margin_all(10)
	_previous = _chapter_button("Previous chapter", -1)
	_next = _chapter_button("Next chapter", 1)
	resized.connect(_layout)


func _chapter_button(accessible: String, direction: int) -> Button:
	var button := Button.new()
	button.text = ""
	button.icon = _ui.get("previous" if direction < 0 else "next")
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 20)
	button.accessibility_name = accessible
	button.tooltip_text = accessible
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func() -> void: set_chapter(current_chapter + direction))
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		var box := StyleBoxTexture.new()
		box.texture = _ui.get("panel")
		box.modulate_color = Color("#fff0cb") if state in ["hover", "pressed", "hover_pressed", "focus"] else Color.WHITE
		box.set_texture_margin_all(8)
		box.set_content_margin_all(8)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.35))
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
		var number: int = int(definition.number)
		var paths: Array = _art.get("landmarks", [])
		button.art_path = str(paths[number - 1]) if number > 0 and number <= paths.size() else ""
		button.configure(definition, _ui)
		button.reduced_motion = reduced_motion
		button.pressed.connect(func() -> void: level_selected.emit(button.number))
		add_child(button)
		level_buttons.append(button)
	_layout()


func set_chapter(index: int) -> void:
	var next_chapter: int = clampi(index, 0, CHAPTERS.size() - 1)
	if current_chapter == next_chapter:
		return
	_previous_chapter = current_chapter
	_transition = 1.0 if reduced_motion else 0.0
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
	if value:
		_transition = 1.0
	queue_redraw()
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
		button.add_theme_constant_override("icon_max_width", ceili(20.0 * unit))
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
		if not _compact:
			# Stagger destinations within their own cells to give the trail a
			# natural course while keeping touch targets separate at every size.
			var horizontal_space: float = maxf(0, column_width - tile_width - 6 * unit)
			var vertical_space: float = maxf(0, row_height - tile_height - 4 * unit)
			var stagger: Vector2 = [Vector2(-0.12, -0.18), Vector2(-0.06, 0.16), Vector2(0.12, -0.10), Vector2(0.08, 0.15), Vector2(-0.10, 0.08), Vector2(0.12, -0.10)][offset]
			button.position += Vector2(horizontal_space, vertical_space) * stagger
		button.size = Vector2(tile_width, tile_height)
		button.set_ui_scale(_ui_scale)
		_route_points.append(button.position + button.route_anchor())
	if lost_focus:
		var choices: Array[Button] = navigation_buttons()
		if not choices.is_empty():
			choices[0].grab_focus()
	queue_redraw()


func _load_art() -> void:
	if not FileAccess.file_exists(ART_MANIFEST):
		push_error("Talk Quest map source manifest is missing.")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ART_MANIFEST))
	if not parsed is Dictionary:
		push_error("Talk Quest map source manifest is invalid.")
		return
	_art = parsed
	for path: String in _art.get("backgrounds", []):
		_backgrounds.append(load(path) as Texture2D)
	for role: String in _art.get("ui", {}):
		_ui[role] = load(str(_art.ui[role])) as Texture2D


func art_snapshot() -> Dictionary:
	var landmarks: Array[String] = []
	for button: LandmarkButton in visible_level_buttons():
		landmarks.append(button.art_path)
	var backgrounds: Array = _art.get("backgrounds", [])
	return {"background": str(backgrounds[current_chapter]) if current_chapter < backgrounds.size() else "",
		"landmarks": landmarks, "source_manifest": ART_MANIFEST}


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _transition >= 1.0:
		return
	_transition = minf(1.0, _transition + delta * 3.8)
	_frame_time += delta
	if _frame_time >= 1.0 / 30.0 or _transition >= 1.0:
		_frame_time = 0.0
		queue_redraw()


func _background(index: int, alpha: float) -> void:
	if index >= _backgrounds.size() or _backgrounds[index] == null:
		return
	var texture: Texture2D = _backgrounds[index]
	var cover: float = maxf(size.x / texture.get_width(), size.y / texture.get_height())
	var region_size: Vector2 = size / cover
	var region := Rect2((texture.get_size() - region_size) * 0.5, region_size)
	draw_texture_rect_region(texture, Rect2(Vector2.ZERO, size), region, Color(1, 1, 1, alpha))


func _draw() -> void:
	if size.x <= 0 or level_buttons.is_empty():
		return
	var unit: float = 1.0 / _ui_scale
	if _transition < 1.0:
		_background(_previous_chapter, 1.0)
	_background(current_chapter, smoothstep(0, 1, _transition))
	if not _compact:
		_draw_route(unit)
	var heading_width: float = maxf(1, minf(360 * unit, size.x - 112 * unit))
	var heading_left: float = (size.x - heading_width) * 0.5
	draw_style_box(_heading_panel, Rect2(Vector2(heading_left, unit), Vector2(heading_width, _header_height - 4 * unit)))
	var font: Font = get_theme_default_font()
	var title_size: int = ceili((10.0 if size.x * _ui_scale < 360.0 else 12.0) * unit)
	draw_string(font, Vector2(heading_left + 5 * unit, 20 * unit), str(CHAPTERS[current_chapter].title), HORIZONTAL_ALIGNMENT_CENTER, heading_width - 10 * unit, title_size, INK)
	var progress: String = "CHAPTER %d / 3" % (current_chapter + 1)
	draw_string(font, Vector2(heading_left + 5 * unit, 34 * unit), progress, HORIZONTAL_ALIGNMENT_CENTER, heading_width - 10 * unit, ceili(9 * unit), Color("#785836"))


func _draw_route(unit: float) -> void:
	var trail: Texture2D = _ui.get("trail")
	if trail == null:
		return
	for index in range(_route_points.size() - 1):
		var start: Vector2 = _route_points[index]
		var finish: Vector2 = _route_points[index + 1]
		var same_row: bool = index % _columns != _columns - 1
		var first_control: Vector2 = start.lerp(finish, 0.33)
		var last_control: Vector2 = start.lerp(finish, 0.66)
		if same_row:
			first_control.y -= 26 * unit
			last_control.y -= 26 * unit
		else:
			var bend: float = -32 * unit if start.x < size.x * 0.5 else 32 * unit
			first_control = start + Vector2(bend, 55 * unit)
			last_control = finish + Vector2(bend, -55 * unit)
		var last_stamp: Vector2 = start
		var reached: bool = bool(_cleared.get(int(CHAPTERS[current_chapter].first) + index, false))
		for step in range(1, 81):
			var point: Vector2 = start.bezier_interpolate(first_control, last_control, finish, float(step) / 80.0)
			if point.distance_to(last_stamp) < 14 * unit or point.distance_to(start) < 28 * unit or point.distance_to(finish) < 28 * unit:
				continue
			var next_point: Vector2 = start.bezier_interpolate(first_control, last_control, finish, minf(1, float(step + 1) / 80.0))
			var dimensions := Vector2(8, 2.2) * unit
			draw_set_transform(point, (next_point - point).angle())
			draw_texture_rect(trail, Rect2(-dimensions * 0.5, dimensions), false, Color(1, 1, 1, 0.88 if reached else 0.46))
			draw_set_transform(Vector2.ZERO)
			last_stamp = point
