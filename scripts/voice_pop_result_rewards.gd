extends Control
## A read-only score ladder; reward ownership stays with the round model.

const Style = preload("res://scripts/ui_style.gd")
const Model = preload("res://scripts/voice_pop_model.gd")
const CHEST = preload("res://assets/chests/royal/closed.png")
const GOLD := Color("#ffd570")
const WHITE := Color("#faf7ed")
const SOFT := Color("#b7ccc3")

var _score: int = 0
var _earned: int = 0
var _compact: bool = false
var _title: Label
var _points: Label
var _rows: Array[Dictionary] = []
var _panel_rect := Rect2()
var _panel_style: StyleBoxFlat
var _track_style: StyleBoxFlat
var _fill_style: StyleBoxFlat
var _highlight_style: StyleBoxFlat


func _ready() -> void:
	name = "ResultRewards"
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = _label("", GOLD)
	_points = _label("", SOFT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var thumbnail := AtlasTexture.new()
	thumbnail.atlas = CHEST
	thumbnail.region = Rect2(39, 309, 798, 596)
	for threshold in Model.CHEST_SCORE_THRESHOLDS:
		var label := _label("%d points" % threshold, WHITE)
		var status := _label("", SOFT)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var progress := _label("", WHITE)
		progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		progress.add_theme_color_override("font_shadow_color", Color("#102a2a"))
		progress.add_theme_constant_override("shadow_outline_size", 3)
		var chest := TextureRect.new()
		chest.texture = thumbnail
		chest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(chest)
		_rows.append({"threshold": int(threshold), "label": label, "status": status,
			"progress_label": progress, "chest": chest, "rect": Rect2(), "bar": Rect2()})
	resized.connect(_layout)
	_refresh()


func configure(score: int, earned: int) -> void:
	_score = maxi(0, score)
	_earned = clampi(earned, 0, Model.MAX_CHESTS)
	if is_instance_valid(_title):
		_refresh()


func set_compact(value: bool) -> void:
	_compact = value
	_layout()


func _refresh() -> void:
	_title.text = "Your next treasure" if _earned == 0 else "1 chest earned" if _earned == 1 else "All 3 chests earned" if _earned == 3 else "%d chests earned" % _earned
	_points.text = "%d points this round" % _score
	for index in range(_rows.size()):
		var row: Dictionary = _rows[index]
		var threshold: int = row.threshold
		var earned: bool = index < _earned
		row.status.text = "Earned" if earned else "%d to go" % maxi(0, threshold - _score)
		row.status.add_theme_color_override("font_color", GOLD if earned else SOFT)
		row.progress_label.text = "%d / %d" % [mini(_score, threshold), threshold]
		row.chest.modulate = Color.WHITE if earned else Color(0.68, 0.75, 0.73, 0.8)
	_layout()


func _label(value: String, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", Style.HEADING_FONT)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var header: float = (44.0 if _compact else 52.0) / scale
	var row_height: float = (58.0 if _compact else 70.0) / scale
	custom_minimum_size.y = header + row_height * Model.MAX_CHESTS
	_place(_title, Rect2(0, 0, size.x, 26.0 / scale), 18 if _compact else 22)
	_place(_points, Rect2(0, 25.0 / scale, size.x, 17.0 / scale), 12)
	_panel_rect = Rect2(0, header, size.x, row_height * Model.MAX_CHESTS)
	_panel_style = Style.box(Color("#193635"), Color("#45605a"), ceili(14.0 / scale), 1)
	_track_style = Style.box(Color("#3b5551"), Color.TRANSPARENT, ceili(8.0 / scale), 0)
	_fill_style = Style.box(Color("#edbd50"), Color.TRANSPARENT, ceili(8.0 / scale), 0)
	_highlight_style = Style.box(Color("#ffe49a"), Color.TRANSPARENT, ceili(2.0 / scale), 0)
	var inset: float = 14.0 / scale
	var chest_width: float = (54.0 if _compact else 66.0) / scale
	var bar_width: float = maxf(0.0, size.x - inset * 2.0 - chest_width - 10.0 / scale)
	for index in range(_rows.size()):
		var row: Dictionary = _rows[index]
		var top: float = header + index * row_height
		row.rect = Rect2(0, top, size.x, row_height)
		var label_y: float = top + (6.0 if _compact else 10.0) / scale
		_place(row.label, Rect2(inset, label_y, bar_width * 0.58, 20.0 / scale), 13 if _compact else 15)
		_place(row.status, Rect2(inset + bar_width * 0.58, label_y, bar_width * 0.42, 20.0 / scale), 11 if _compact else 12)
		row.bar = Rect2(inset, top + (31.0 if _compact else 38.0) / scale, bar_width, 16.0 / scale)
		_place(row.progress_label, row.bar, 11)
		row.chest.position = Vector2(size.x - inset - chest_width, top + (row_height - chest_width * 0.75) * 0.5)
		row.chest.size = Vector2(chest_width, chest_width * 0.75)
	queue_redraw()


func _draw() -> void:
	if _panel_style == null:
		return
	var scale: float = Style.ui_scale(self)
	draw_style_box(_panel_style, _panel_rect)
	for index in range(_rows.size()):
		var row: Dictionary = _rows[index]
		if index > 0:
			draw_line(Vector2(1.0 / scale, row.rect.position.y), Vector2(size.x - 1.0 / scale, row.rect.position.y), Color("#36514c"), 1.0 / scale)
		draw_style_box(_track_style, row.bar)
		var progress: float = clampf(float(_score) / float(row.threshold), 0.0, 1.0)
		if progress > 0.0:
			var fill: Rect2 = row.bar
			fill.size.x *= progress
			draw_style_box(_fill_style, fill)
			if fill.size.x > 10.0 / scale:
				draw_style_box(_highlight_style, Rect2(fill.position + Vector2(4, 2) / scale, Vector2(fill.size.x - 8.0 / scale, 3.0 / scale)))


func _global_rect(rect: Rect2) -> Array:
	var global: Rect2 = get_global_transform() * rect
	return [global.position.x, global.position.y, global.size.x, global.size.y]


func snapshot() -> Dictionary:
	var rows: Array = []
	for index in range(_rows.size()):
		var row: Dictionary = _rows[index]
		rows.append({"threshold": row.threshold, "value": mini(_score, int(row.threshold)),
			"progress": clampf(float(_score) / float(row.threshold), 0.0, 1.0), "earned": index < _earned,
			"label": row.label.text, "progress_text": row.progress_label.text,
			"rect": _global_rect(row.rect), "bar_rect": _global_rect(row.bar),
			"chest_rect": _global_rect(row.chest.get_rect())})
	return {"visible": is_visible_in_tree(), "score": _score, "earned": _earned,
		"title": _title.text if is_instance_valid(_title) else "", "rows": rows,
		"rect": _global_rect(Rect2(Vector2.ZERO, size))}
