extends Button
## A tactile island destination rendered from acquired production models.

const Style = preload("res://scripts/ui_style.gd")
const FLAG = preload("res://assets/talk_quest/map-dimensional/decoration-flag.png")

var number: int = 1
var title: String = ""
var art_path: String = ""
var unlocked: bool = false
var cleared: bool = false
var current_stop: bool = false
var reduced_motion: bool = false
var compact: bool = false
var _caption: Label
var _status: Label
var _ui_scale: float = 1.0
var _time: float = 0.0
var _lift: float = 0.0
var _frame_time: float = 0.0
var _landmark: Texture2D
var _ui: Dictionary = {}
var _art_rect := Rect2()
var _panel: StyleBoxFlat


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
	_caption = Label.new()
	_caption.text = title
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_theme_color_override("font_color", Style.INK)
	_caption.add_theme_font_override("font", Style.HEADING_FONT)
	add_child(_caption)
	_status = Style.label("", 11)
	_status.clip_text = true
	_status.add_theme_color_override("font_color", Style.MUTED)
	add_child(_status)
	update_accessibility()
	_layout_labels()


func update_accessibility() -> void:
	var state: String = "Cleared" if cleared else "Ready to explore" if unlocked else "Locked"
	accessibility_name = "Adventure %d: %s. %s." % [number, title, state]
	if _status != null:
		_status.text = "Explore again" if cleared else "Begin adventure  ›" if current_stop else "Ready to explore" if unlocked else "Complete island %d first" % (number - 1)
		_status.add_theme_color_override("font_color", Style.GOOD if unlocked else Style.MUTED)


func set_ui_scale(value: float) -> void:
	_ui_scale = maxf(0.1, value)
	_layout_labels()


func _layout_labels() -> void:
	if _caption == null:
		return
	var unit: float = 1.0 / _ui_scale
	_caption.add_theme_font_size_override("font_size", ceili((12 if compact else 15) * unit))
	_status.add_theme_font_size_override("font_size", ceili((10 if compact else 11) * unit))
	_caption.clip_text = true
	if compact:
		var art_width: float = minf(size.x * 0.44, size.y)
		_caption.position = Vector2(art_width + 4 * unit, maxf(2 * unit, (size.y - 58 * unit) * 0.5))
		_caption.size = Vector2(maxf(1, size.x - art_width - 12 * unit), minf(44 * unit, size.y - 18 * unit))
		_art_rect = Rect2(Vector2(0, 0), Vector2(art_width, size.y - 4 * unit))
	else:
		_caption.position = Vector2(54 * unit, maxf(0, size.y - 69 * unit))
		_caption.size = Vector2(maxf(1, size.x - 68 * unit), minf(size.y - 18 * unit, 48 * unit))
		_art_rect = Rect2(Vector2(0, 4 * unit), Vector2(size.x, maxf(1, size.y - 83 * unit)))
	_status.position = _caption.position + Vector2(0, _caption.size.y)
	_status.size = Vector2(_caption.size.x, minf(18 * unit, size.y - _status.position.y))
	_panel = Style.box(Color("#fffdf5"), Color("#c9dace"), ceili(16 * unit), maxi(1, ceili(unit)))
	_panel.shadow_color = Color("#29483a20")
	_panel.shadow_size = ceili(5 * unit)
	_panel.shadow_offset = Vector2(0, 3 * unit)
	queue_redraw()


func route_anchor() -> Vector2:
	if compact:
		return Vector2(_art_rect.size.x * 0.5, size.y * 0.76)
	return Vector2(size.x * 0.5, _art_rect.end.y - 18 / _ui_scale)


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
	var lift: float = (2.0 if is_pressed() else -5.0 * _lift) * unit
	var art_rect: Rect2 = _art_rect
	art_rect.position.y += lift
	var paper_rect := Rect2(Vector2(_caption.position.x - 8 * unit, 4 * unit), Vector2(size.x - _caption.position.x + 4 * unit, size.y - 8 * unit)) if compact else Rect2(Vector2(5 * unit, size.y - 74 * unit), Vector2(size.x - 10 * unit, 72 * unit))
	_panel.bg_color = Color("#fff8df") if current_stop else Color("#fffdf5") if unlocked else Color("#f3f6f0e8")
	_panel.border_color = Style.GOOD if focused else Color("#c6a552") if current_stop else Color("#cadbd0")
	draw_style_box(_panel, paper_rect)
	_image(_landmark, art_rect, Color.WHITE if unlocked else Color(0.81, 0.90, 0.88, 0.82))
	if current_stop and not compact:
		var flag_size: float = minf(56 * unit, _art_rect.size.y * 0.30)
		var bob: float = 0 if reduced_motion else sin(_time * 2.6) * 2 * unit
		var flag_rect := Rect2(Vector2(size.x * 0.71, _art_rect.position.y + _art_rect.size.y * 0.24 + bob + lift), Vector2(flag_size, flag_size))
		_image(FLAG, flag_rect)
	var center: Vector2 = route_anchor() if compact else Vector2(29 * unit, size.y - 39 * unit)
	var diameter: float = (28.0 if compact else 36.0) * unit
	var badge_area := Rect2(center - Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter)
	var pulse: float = 1.0 if reduced_motion or not current_stop else 1.0 + sin(_time * 2.4) * 0.045
	if not compact:
		badge_area = Rect2(center - badge_area.size * pulse * 0.5, badge_area.size * pulse)
	_image(_ui.get("badge"), badge_area, Color("#ffcc62") if current_stop else Color("#d6eee9") if cleared else Color.WHITE)
	var font: Font = Style.HEADING_FONT
	var font_size: int = ceili((12.0 if compact else 17.0) * unit)
	var number_text: String = str(number)
	var text_width: float = font.get_string_size(number_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center + Vector2(-text_width * 0.5, 5 * unit), number_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("#3b2c23"))
	var status_texture: Texture2D = _ui.get("cleared") if cleared else _ui.get("locked") if not unlocked else null
	if status_texture != null:
		var status_size: float = (9.0 if compact else 14.0) * unit
		var offset := Vector2(10, -8) * unit if compact else Vector2(12, -14) * unit
		_image(status_texture, Rect2(center + offset - Vector2.ONE * status_size * 0.5, Vector2.ONE * status_size))
	if focused:
		# The sourced seal makes keyboard focus explicit without altering hit geometry.
		var seal_size: float = (9.0 if compact else 16.0) * unit
		_image(_ui.get("current"), Rect2(Vector2(2 * unit, maxf(0, size.y - seal_size)), Vector2.ONE * seal_size))
