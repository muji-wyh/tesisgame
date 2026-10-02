extends Button
## An accessible destination rendered from the acquired map artwork.

var number: int = 1
var title: String = ""
var art_path: String = ""
var unlocked: bool = false
var cleared: bool = false
var current_stop: bool = false
var reduced_motion: bool = false
var compact: bool = false
var _caption: Label
var _ui_scale: float = 1.0
var _time: float = 0.0
var _lift: float = 0.0
var _frame_time: float = 0.0
var _landmark: Texture2D
var _ui: Dictionary = {}
var _art_rect := Rect2()
var _panel: StyleBoxTexture


func _init() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	resized.connect(_layout_labels)


func configure(definition: Dictionary, artwork: Dictionary) -> void:
	number = int(definition.number)
	title = str(definition.title)
	disabled = true
	_ui = artwork
	if not art_path.is_empty():
		_landmark = load(art_path) as Texture2D
	_panel = StyleBoxTexture.new()
	_panel.texture = _ui.get("panel")
	_panel.set_texture_margin_all(10)
	_caption = Label.new()
	_caption.text = title
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_theme_color_override("font_color", Color("#3b2c23"))
	_caption.add_theme_color_override("font_shadow_color", Color("#fff1cf"))
	_caption.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_caption)
	update_accessibility()
	_layout_labels()


func update_accessibility() -> void:
	var state: String = "Cleared" if cleared else "Ready to explore" if unlocked else "Locked"
	accessibility_name = "Adventure %d: %s. %s." % [number, title, state]
	tooltip_text = "Play " + title if unlocked else "Complete the previous adventure to unlock " + title


func set_ui_scale(value: float) -> void:
	_ui_scale = maxf(0.1, value)
	_layout_labels()


func _layout_labels() -> void:
	if _caption == null:
		return
	var unit: float = 1.0 / _ui_scale
	_caption.add_theme_font_size_override("font_size", ceili(12.0 * unit))
	_caption.clip_text = true
	if compact:
		_caption.position = Vector2(39, 2) * unit
		_caption.size = Vector2(maxf(1, size.x - 44 * unit), maxf(1, size.y - 4 * unit))
		_art_rect = Rect2(Vector2(maxf(0, size.x - 55 * unit), 2 * unit), Vector2(52 * unit, maxf(1, size.y - 4 * unit)))
	else:
		# Two lines need room for the theme's line spacing as well as glyphs.
		var caption_height: float = minf(size.y, 40.0 * unit)
		_caption.position = Vector2(8.0 * unit, size.y - caption_height)
		_caption.size = Vector2(maxf(1, size.x - 16.0 * unit), caption_height)
		_art_rect = Rect2(Vector2(12 * unit, 4 * unit), Vector2(maxf(1, size.x - 24 * unit), maxf(1, _caption.position.y - 15 * unit)))
	queue_redraw()


func route_anchor() -> Vector2:
	if compact:
		return Vector2(20 / _ui_scale, size.y * 0.5)
	return Vector2(size.x * 0.5, maxf(20 / _ui_scale, _caption.position.y - 10 / _ui_scale))


func compact_badge_rect() -> Rect2:
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


func _image(texture: Texture2D, area: Rect2, color: Color = Color.WHITE) -> void:
	if texture == null or area.size.x <= 0 or area.size.y <= 0:
		return
	var ratio: float = minf(area.size.x / texture.get_width(), area.size.y / texture.get_height())
	var dimensions: Vector2 = texture.get_size() * ratio
	draw_texture_rect(texture, Rect2(area.get_center() - dimensions * 0.5, dimensions), false, color)


func _draw() -> void:
	if _caption == null:
		return
	var unit: float = 1.0 / _ui_scale
	var focused: bool = not disabled and (is_hovered() or has_focus())
	var lift: float = (2.0 if is_pressed() else -4.0 * _lift) * unit
	var art_rect: Rect2 = _art_rect
	art_rect.position.y += lift
	var paper_rect := Rect2(Vector2(unit, _caption.position.y), Vector2(maxf(1, size.x - 2 * unit), _caption.size.y))
	if compact:
		paper_rect = Rect2(Vector2.ONE * unit, size - Vector2.ONE * 2 * unit)
	_panel.modulate_color = Color("#fff7d9") if focused or current_stop else Color.WHITE
	draw_style_box(_panel, paper_rect)
	_image(_landmark, art_rect, Color(1, 1, 1, 0.20 if compact else 1.0 if unlocked else 0.76))
	if current_stop and not compact:
		var flag_size: float = minf(36 * unit, _art_rect.size.y * 0.38)
		var bob: float = 0 if reduced_motion else sin(_time * 2.6) * 2 * unit
		var flag_rect := Rect2(Vector2(size.x * 0.67, maxf(0, _art_rect.position.y + bob)), Vector2(flag_size, flag_size))
		_image(_ui.get("current"), flag_rect)
	var center: Vector2 = route_anchor()
	var diameter: float = (28.0 if compact else 42.0) * unit
	var badge_area := Rect2(center - Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter)
	var pulse: float = 1.0 if reduced_motion or not current_stop else 1.0 + sin(_time * 2.4) * 0.045
	if not compact:
		badge_area = Rect2(center - badge_area.size * pulse * 0.5, badge_area.size * pulse)
	_image(_ui.get("badge"), badge_area, Color("#ffe5a2") if current_stop else Color.WHITE)
	var font: Font = get_theme_default_font()
	var font_size: int = ceili((12.0 if compact else 17.0) * unit)
	var number_text: String = str(number)
	var text_width: float = font.get_string_size(number_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center + Vector2(-text_width * 0.5, 5 * unit), number_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#3b2c23"))
	var status_texture: Texture2D = _ui.get("cleared") if cleared else _ui.get("locked") if not unlocked else null
	if status_texture != null:
		var status_size: float = (9.0 if compact else 18.0) * unit
		var offset := Vector2(10, -8) * unit if compact else Vector2(16, -15) * unit
		_image(status_texture, Rect2(center + offset - Vector2.ONE * status_size * 0.5, Vector2.ONE * status_size))
	if focused:
		# The sourced seal makes keyboard focus explicit without altering hit geometry.
		var seal_size: float = (9.0 if compact else 16.0) * unit
		_image(_ui.get("current"), Rect2(Vector2(2 * unit, maxf(0, size.y - seal_size)), Vector2.ONE * seal_size))
