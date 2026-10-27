extends Panel

const Style = preload("res://scripts/ui_style.gd")
const JELLY = preload("res://assets/images/jelly-match/gel-mint.png")
var level: int = 1
var _picture := TextureRect.new()
var _label: Label


func _init() -> void:
	name = "MergedJellyLevel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.texture = JELLY
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_picture)
	_label = Style.label("", 14)
	_label.add_theme_font_override("font", Style.HEADING_FONT)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	set_level(1)


func set_level(value: int) -> void:
	level = clampi(value, 1, 9)
	_label.text = "Jelly Lv%d" % level
	tooltip_text = "Highest unlocked merged Jelly level: %d" % level
	set("accessibility_name", tooltip_text)


func layout_badge(bounds: Rect2, ui_scale: float) -> void:
	position = bounds.position
	size = bounds.size
	var unit: float = 1.0 / maxf(0.1, ui_scale)
	add_theme_stylebox_override("panel", Style.box(Color("#fff7db"), Color("#d9bf76"), ceili(10.0 * unit), 1))
	var edge: float = minf(24.0 * unit, size.y - 4.0 * unit)
	_picture.size = Vector2.ONE * edge
	_picture.position = Vector2(4.0 * unit, (size.y - edge) * 0.5)
	_label.position = Vector2(_picture.get_rect().end.x + 3.0 * unit, 0)
	_label.size = Vector2(maxf(1.0, size.x - _label.position.x - 4.0 * unit), size.y)
	var pixels: int = ceili(14.0 * unit)
	while pixels > 1 and Style.HEADING_FONT.get_string_size(_label.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > _label.size.x:
		pixels -= 1
	_label.add_theme_font_size_override("font_size", pixels)


func snapshot() -> Dictionary:
	var rect: Rect2 = get_global_rect()
	return {"visible": is_visible_in_tree(), "level": level, "text": _label.text,
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]}
