extends Control
## A continuous island journey built from sourced miniature scenery.

signal level_selected(number: int)
signal chapter_changed(index: int)
signal changed

const ART_MANIFEST := "res://assets/talk_quest/map-dimensional/manifest.json"
const LandmarkButton = preload("res://scripts/talk_quest_map_stop.gd")
const MapScroll = preload("res://scripts/review_scroll.gd")
const CHAPTERS: Array = [
	{"title": "COZY BEGINNINGS", "first": 1, "count": 4},
	{"title": "AROUND TOWN", "first": 5, "count": 6},
	{"title": "BEYOND THE GARDEN", "first": 11, "count": 4}
]

var level_buttons: Array[Button] = []
var reduced_motion: bool = false
var interaction_allowed: Callable
var current_chapter: int = 0
var _ui_scale: float = 1.0
var _route_points: Array[Vector2] = []
var _current_stop: int = 0
var _previous: Button
var _next: Button
var _scroll: MapScroll
var _content: Control
var _header_height: float = 52.0
var _compact: bool = false
var _art: Dictionary = {}
var _backgrounds: Array[Texture2D] = []
var _ui: Dictionary = {}
var _decorations: Dictionary = {}
var _heading_panel: StyleBoxTexture
var _layout_pending: bool = false
var _layout_active: bool = false
var _reveal_number: int = 1
var _time: float = 0.0
var _frame_time: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	_load_art()
	_scroll = MapScroll.new()
	_scroll.name = "MapScroll"
	_scroll.interaction_allowed = func() -> bool:
		return not interaction_allowed.is_valid() or interaction_allowed.call()
	add_child(_scroll)
	_scroll.get_h_scroll_bar().value_changed.connect(_scrolled)
	_content = Control.new()
	_content.name = "IslandJourney"
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	_content.draw.connect(_draw_route)
	_heading_panel = StyleBoxTexture.new()
	_heading_panel.texture = _ui.get("panel")
	_heading_panel.modulate_color = Color("#244b5b")
	_heading_panel.set_texture_margin_all(10)
	_previous = _chapter_button("Previous region", -1)
	_next = _chapter_button("Next region", 1)
	resized.connect(_layout)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			cancel_input()
		else:
			_queue_layout())


func _chapter_button(accessible: String, direction: int) -> Button:
	var button := Button.new()
	button.icon = _ui.get("previous" if direction < 0 else "next")
	button.expand_icon = true
	button.accessibility_name = accessible
	button.tooltip_text = accessible
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(func() -> void: set_chapter(current_chapter + direction))
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		var box := StyleBoxTexture.new()
		box.texture = _ui.get("panel")
		box.modulate_color = Color("#7195a0") if state in ["hover", "focus"] else Color("#436879")
		box.set_texture_margin_all(8)
		box.set_content_margin_all(8)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.3))
	add_child(button)
	return button


func configure(levels: Array) -> void:
	cancel_input()
	for button in level_buttons:
		_content.remove_child(button)
		button.queue_free()
	level_buttons.clear()
	_route_points.clear()
	_current_stop = 0
	current_chapter = 0
	_reveal_number = 1
	for definition: Dictionary in levels:
		var button := LandmarkButton.new()
		var number: int = int(definition.number)
		var paths: Array = _art.get("landmarks", [])
		button.art_path = str(paths[number - 1]) if number > 0 and number <= paths.size() else ""
		button.configure(definition, _ui)
		button.reduced_motion = reduced_motion
		button.pressed.connect(func() -> void:
			if not button.disabled and (not interaction_allowed.is_valid() or interaction_allowed.call()):
				level_selected.emit(button.number))
		button.focus_entered.connect(_focus_level.bind(button))
		_content.add_child(button)
		level_buttons.append(button)
	_layout()


func cancel_input() -> void:
	if is_instance_valid(_scroll):
		_scroll.cancel_drag()


func set_chapter(index: int) -> void:
	var next_chapter: int = clampi(index, 0, CHAPTERS.size() - 1)
	show_level(int(CHAPTERS[next_chapter].first))


func show_level(number: int) -> void:
	if number < 1 or number > level_buttons.size():
		return
	cancel_input()
	_reveal_number = number
	_reveal_level()
	_queue_layout()


func _reveal_level() -> void:
	if _reveal_number < 1 or _reveal_number > level_buttons.size() or _scroll.size.x <= 0:
		return
	var button: Button = level_buttons[_reveal_number - 1]
	var center: float = button.position.x + button.size.x * 0.5
	_scroll.scroll_horizontal = clampi(roundi(center - _scroll.size.x * 0.5), 0, roundi(_scroll._maximum()))
	_scrolled(_scroll.scroll_horizontal)


func _focus_level(button: Button) -> void:
	if _scroll.is_pointer_active():
		return
	cancel_input()
	if not level_in_view(button):
		show_level(button.number)


func level_in_view(button: Control, fully: bool = true) -> bool:
	if not button.is_visible_in_tree():
		return false
	var viewport: Rect2 = _scroll.get_global_rect().grow(1.0)
	return viewport.encloses(button.get_global_rect()) if fully else viewport.intersects(button.get_global_rect())


func visible_level_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for button in level_buttons:
		if level_in_view(button):
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
	queue_redraw()


func set_level_state(number: int, unlocked: bool, cleared: bool) -> void:
	if number < 1 or number > level_buttons.size():
		return
	var button: LandmarkButton = level_buttons[number - 1]
	button.unlocked = unlocked
	button.cleared = cleared
	button.disabled = not unlocked
	button.focus_mode = Control.FOCUS_ALL if unlocked else Control.FOCUS_NONE
	button.update_accessibility()
	button.queue_redraw()
	var next_stop: int = 0
	for item: LandmarkButton in level_buttons:
		item.current_stop = item.unlocked and not item.cleared and next_stop == 0
		if item.current_stop:
			next_stop = item.number
		item.queue_redraw()
	if next_stop != _current_stop:
		_current_stop = next_stop
		if next_stop > 0:
			show_level(next_stop)
	_update_navigation()
	_content.queue_redraw()


func _layout() -> void:
	if _layout_active:
		return
	custom_minimum_size = Vector2.ZERO
	_previous.visible = not level_buttons.is_empty()
	_next.visible = not level_buttons.is_empty()
	if size.x <= 0 or size.y <= 0 or level_buttons.is_empty():
		queue_redraw()
		return
	_layout_active = true
	var unit: float = 1.0 / _ui_scale
	var old_max: float = _scroll._maximum()
	var fraction: float = _scroll.scroll_horizontal / old_max if old_max > 0 else 0.0
	_compact = size.y * _ui_scale < 250.0
	_header_height = (44.0 if _compact else 54.0) * unit
	_scroll.position = Vector2(0, _header_height)
	_scroll.size = Vector2(size.x, maxf(1, size.y - _header_height))
	var width: float = minf((220.0 if _compact else 310.0) * unit, size.x - 24 * unit)
	var height: float = minf((108.0 if _compact else 350.0) * unit, _scroll.size.y - 8 * unit)
	height = maxf(44 * unit, height)
	var spacing: float = width + (20.0 if _compact else 34.0) * unit
	var inset: float = 24 * unit
	var world_width: float = inset * 2 + width + spacing * (level_buttons.size() - 1)
	_content.custom_minimum_size = Vector2(world_width, 0)
	_content.size = Vector2(world_width, _scroll.size.y)
	var room: float = maxf(0, _scroll.size.y - height - 20 * unit)
	_route_points.clear()
	for index in range(level_buttons.size()):
		var button: LandmarkButton = level_buttons[index]
		button.compact = _compact
		button.position = Vector2(inset + index * spacing, 4 * unit + room * [0.40, 0.74, 0.24, 0.57, 0.30, 0.69, 0.43][index % 7])
		button.size = Vector2(width, height)
		button.set_ui_scale(_ui_scale)
		_route_points.append(button.position + button.route_anchor())
	_previous.position = Vector2(8, 0 if _compact else 3) * unit
	_next.position = Vector2(size.x - 52 * unit, (0 if _compact else 3) * unit)
	for button in [_previous, _next]:
		button.size = Vector2.ONE * 44 * unit
		button.add_theme_constant_override("icon_max_width", ceili(18 * unit))
	_update_navigation()
	if _reveal_number == 0:
		_scroll.scroll_horizontal = roundi(fraction * maxf(0, world_width - _scroll.size.x))
	_layout_active = false
	_content.queue_redraw()
	queue_redraw()
	_queue_layout()


func _queue_layout() -> void:
	if _layout_pending or not is_inside_tree():
		return
	_layout_pending = true
	_settle_layout.call_deferred()


func _settle_layout() -> void:
	_layout_pending = false
	if not is_inside_tree():
		return
	if _reveal_number > 0:
		_reveal_level()
		_reveal_number = 0
	changed.emit()


func _update_navigation() -> void:
	var available: Array[Button] = []
	for button in level_buttons:
		if not button.disabled:
			available.append(button)
	for index in range(available.size()):
		var button: Button = available[index]
		var previous: Button = available[maxi(0, index - 1)]
		var next: Button = available[mini(available.size() - 1, index + 1)]
		button.focus_neighbor_left = button.get_path_to(previous)
		button.focus_neighbor_right = button.get_path_to(next)
		button.focus_previous = button.get_path_to(previous if index > 0 else _previous if current_chapter > 0 else _next)
		button.focus_next = button.get_path_to(next if index < available.size() - 1 else _next if current_chapter < 2 else _previous)
	_previous.disabled = current_chapter == 0
	_next.disabled = current_chapter == CHAPTERS.size() - 1
	for button in [_previous, _next]:
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
	if _previous.has_focus() and _previous.disabled:
		_next.grab_focus()
	elif _next.has_focus() and _next.disabled:
		_previous.grab_focus()


func _scrolled(_value: float) -> void:
	if _layout_active or level_buttons.is_empty():
		return
	var center: float = _scroll.scroll_horizontal + _scroll.size.x * 0.5
	var nearest: int = 1
	var distance: float = INF
	for button: LandmarkButton in level_buttons:
		var delta: float = absf(button.position.x + button.size.x * 0.5 - center)
		if delta < distance:
			distance = delta
			nearest = button.number
	var region: int = 0 if nearest < 5 else 1 if nearest < 11 else 2
	if region != current_chapter:
		current_chapter = region
		_update_navigation()
		chapter_changed.emit(region)
	queue_redraw()
	changed.emit()
	_queue_layout()


func _load_art() -> void:
	if not FileAccess.file_exists(ART_MANIFEST):
		push_error("Talk Quest dimensional map manifest is missing.")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ART_MANIFEST))
	if not parsed is Dictionary:
		push_error("Talk Quest dimensional map manifest is invalid.")
		return
	_art = parsed
	for path: String in _art.get("backgrounds", []):
		_backgrounds.append(load(path) as Texture2D)
	for role: String in _art.get("ui", {}):
		_ui[role] = load(str(_art.ui[role])) as Texture2D
	for role: String in _art.get("decorations", {}):
		_decorations[role] = load(str(_art.decorations[role])) as Texture2D


func art_snapshot() -> Dictionary:
	var landmarks: Array[String] = []
	for button in visible_level_buttons():
		landmarks.append(button.art_path)
	var backgrounds: Array = _art.get("backgrounds", [])
	return {"background": str(backgrounds[mini(current_chapter, backgrounds.size() - 1)]) if not backgrounds.is_empty() else "",
		"landmarks": landmarks, "source_manifest": ART_MANIFEST}


func _process(delta: float) -> void:
	if not is_visible_in_tree() or reduced_motion or (interaction_allowed.is_valid() and not interaction_allowed.call()):
		return
	_time += delta
	_frame_time += delta
	if _frame_time >= 1.0 / 20.0:
		_frame_time = 0
		queue_redraw()


func _draw() -> void:
	if size.x <= 0 or level_buttons.is_empty():
		return
	_draw_background()
	var unit: float = 1.0 / _ui_scale
	var heading_width: float = maxf(1, minf(340 * unit, size.x - 116 * unit))
	var left: float = (size.x - heading_width) * 0.5
	draw_style_box(_heading_panel, Rect2(Vector2(left, (0 if _compact else 3) * unit), Vector2(heading_width, 44 * unit)))
	var font: Font = get_theme_default_font()
	var title_size: int = ceili((10.0 if size.x * _ui_scale < 360.0 else 12.0) * unit)
	draw_string(font, Vector2(left + 6 * unit, 21 * unit), str(CHAPTERS[current_chapter].title), HORIZONTAL_ALIGNMENT_CENTER, heading_width - 12 * unit, title_size, Color("#fff7df"))
	draw_string(font, Vector2(left + 6 * unit, 36 * unit), "%02d  /  03" % (current_chapter + 1), HORIZONTAL_ALIGNMENT_CENTER, heading_width - 12 * unit, ceili(9 * unit), Color("#d8c99f"))


func _draw_background() -> void:
	if _backgrounds.is_empty():
		return
	var offset: float = _scroll.scroll_horizontal * _ui_scale
	var region: float = float(current_chapter)
	if _route_points.size() >= 13:
		var center: float = _scroll.scroll_horizontal + _scroll.size.x * 0.5
		region = clampf((center - _route_points[3].x) / maxf(1, _route_points[6].x - _route_points[3].x), 0, 1)
		region += clampf((center - _route_points[9].x) / maxf(1, _route_points[12].x - _route_points[9].x), 0, 1)
	region = clampf(region, 0, _backgrounds.size() - 1)
	for index in range(_backgrounds.size()):
		var base_region: int = floori(region)
		var opacity: float = 1.0 if index == base_region else region - base_region if index == base_region + 1 else 0.0
		if opacity <= 0:
			continue
		var texture: Texture2D = _backgrounds[index]
		var scale_factor: float = maxf(size.x / texture.get_width(), size.y / texture.get_height())
		var region_size: Vector2 = size / scale_factor
		var spare: Vector2 = texture.get_size() - region_size
		var source_rect := Rect2(Vector2(spare.x * (0.5 + sin(offset * 0.0002) * 0.3), spare.y * 0.5), region_size)
		draw_texture_rect_region(texture, Rect2(Vector2.ZERO, size), source_rect, Color(1, 1, 1, opacity))
	var unit: float = 1.0 / _ui_scale
	var distant_island: Texture2D = _decorations.get("distant_island")
	if distant_island != null and not _compact:
		for index in range(4):
			var width: float = (120 + (index % 3) * 35) * unit
			var x: float = fposmod((index * 430 + 210) * unit - _scroll.scroll_horizontal * 0.28, size.x + 440 * unit) - 220 * unit
			var y: float = size.y * (0.16 if index % 2 == 0 else 0.71)
			draw_texture_rect(distant_island, Rect2(Vector2(x, y), Vector2(width, width * distant_island.get_height() / distant_island.get_width())), false, Color(0.82, 0.90, 0.96, 0.62))
	var cloud: Texture2D = _decorations.get("cloud")
	if cloud != null and not _compact:
		for index in range(3):
			var width: float = (180 + index * 55) * unit
			var x: float = fposmod(index * 380 * unit - _scroll.scroll_horizontal * 0.18 + _time * 2 * unit, size.x + width) - width
			var y: float = size.y * (0.17 if index % 2 == 0 else 0.86)
			draw_texture_rect(cloud, Rect2(Vector2(x, y), Vector2(width, width * cloud.get_height() / cloud.get_width())), false, Color(1, 1, 1, 0.28))


func _draw_route() -> void:
	var trail: Texture2D = _decorations.get("trail", _ui.get("trail"))
	if trail == null:
		return
	var unit: float = 1.0 / _ui_scale
	for index in range(_route_points.size() - 1):
		var start: Vector2 = _route_points[index]
		var finish: Vector2 = _route_points[index + 1]
		var first: Vector2 = start.lerp(finish, 0.35) + Vector2(0, 30 * unit)
		var last: Vector2 = start.lerp(finish, 0.65) + Vector2(0, 30 * unit)
		var previous: Vector2 = start
		for step in range(1, 61):
			var point: Vector2 = start.bezier_interpolate(first, last, finish, float(step) / 60.0)
			if point.distance_to(previous) < (24.0 if _compact else 34.0) * unit:
				continue
			var dimensions := Vector2.ONE * (24.0 if _compact else 38.0) * unit
			_content.draw_texture_rect(trail, Rect2(point - dimensions * 0.5, dimensions), false, Color("#edcf88") if level_buttons[index].cleared else Color(0.87, 0.94, 1.0, 0.88))
			previous = point
