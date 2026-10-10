extends Control
## The round earns one evolving chest; score remains a separate achievement.

const Style = preload("res://scripts/ui_style.gd")
const Progress = preload("res://scripts/jelly_reward_progress.gd")
const GOLD := Color("#ffd570")
const WHITE := Color("#faf7ed")
const SOFT := Color("#b7ccc3")

var _score: int = 0
var _fragments: int = 0
var _tier: int = 0
var _compact: bool = false
var _title: Label
var _points: Label
var _detail: Label
var _chest: TextureRect
var _texture: Texture2D
var _panel_style: StyleBoxFlat
var _panel_rect := Rect2()


func _ready() -> void:
	name = "ResultRewards"
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = _label("", GOLD)
	_points = _label("", WHITE)
	_detail = _label("", SOFT)
	_chest = TextureRect.new()
	_chest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_chest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chest)
	resized.connect(_layout)
	_refresh()


func configure(score: int, fragments: int, tier: int, texture: Texture2D) -> void:
	_score = maxi(0, score)
	_fragments = maxi(0, fragments)
	_tier = maxi(0, tier)
	_texture = texture
	if is_instance_valid(_title):
		_refresh()


func set_compact(value: bool) -> void:
	_compact = value
	_layout()


func _refresh() -> void:
	_title.text = Progress.title_for_tier(_tier) if _tier > 0 else "Keep collecting!"
	_points.text = "%d points" % _score
	_detail.text = "1 chest · %d fragments collected" % _fragments if _tier > 0 else "%d / 4 chest fragments" % _fragments
	_chest.texture = _texture
	_chest.modulate.a = 1.0 if _tier > 0 else 0.45
	_layout()


func _label(value: String, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", Style.HEADING_FONT)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(label)
	return label


func _place(label: Label, rect: Rect2, font_size: int) -> void:
	label.add_theme_font_size_override("font_size", ceili(font_size / Style.ui_scale(self)))
	label.position = rect.position
	label.size = rect.size


func _layout() -> void:
	if not is_instance_valid(_title):
		return
	var scale: float = Style.ui_scale(self)
	var height: float = (90.0 if _compact else 108.0) / scale
	custom_minimum_size.y = height
	_panel_rect = Rect2(0, 0, size.x, height)
	_panel_style = Style.box(Color("#193635"), Color("#60796c"), ceili(18.0 / scale), 1)
	var edge: float = (72.0 if _compact else 92.0) / scale
	_chest.position = Vector2(10.0 / scale, (height - edge) * 0.5)
	_chest.size = Vector2.ONE * edge
	var left: float = edge + 22.0 / scale
	var width: float = maxf(1.0, size.x - left - 12.0 / scale)
	var top: float = (7.0 if _compact else 12.0) / scale
	_place(_title, Rect2(left, top, width, 28.0 / scale), 18 if _compact else 22)
	_place(_points, Rect2(left, top + 28.0 / scale, width, 22.0 / scale), 16)
	_place(_detail, Rect2(left, top + 51.0 / scale, width, 22.0 / scale), 10 if size.x * scale < 330 else 12)
	queue_redraw()


func _draw() -> void:
	if _panel_style != null:
		draw_style_box(_panel_style, _panel_rect)


func _global_rect(rect: Rect2) -> Array:
	var global: Rect2 = get_global_transform() * rect
	return [global.position.x, global.position.y, global.size.x, global.size.y]


func snapshot() -> Dictionary:
	return {"visible": is_visible_in_tree(), "score": _score, "earned": 1 if _tier > 0 else 0,
		"fragment_count": _fragments, "chest_tier": _tier,
		"title": _title.text if is_instance_valid(_title) else "",
		"detail": _detail.text if is_instance_valid(_detail) else "",
		"chest_rect": _global_rect(_chest.get_rect()) if is_instance_valid(_chest) else [],
		"rect": _global_rect(Rect2(Vector2.ZERO, size))}
