extends Panel
## The stage's durable learning evidence, outside the playable well.

const Style = preload("res://scripts/ui_style.gd")
const Scroll = preload("res://scripts/review_scroll.gd")
const WordArt = preload("res://scripts/word_art.gd")
const MEDAL = preload("res://assets/images/ui/mastery-medal.webp")
const STAR = preload("res://assets/chests/milestone/sparkle.png")
var _title: Label
var _subtitle: Label
var _medal := TextureRect.new()
var _scroll := Scroll.new()
var _content := Control.new()
var _rows: Array[Dictionary] = []
var _state: Dictionary = {}
var _compact: bool = false
var _scale: float = 1.0


func _init() -> void:
	name = "StagePracticeWords"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 36
	_title = Style.label("", 16)
	_title.add_theme_font_override("font", Style.HEADING_FONT)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_subtitle = Style.label("", 12)
	_subtitle.add_theme_color_override("font_color", Style.MUTED)
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subtitle)
	_medal.texture = MEDAL
	_medal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_medal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_medal)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	_scroll.add_child(_content)
	hide()


func set_stage(state: Dictionary) -> void:
	if _state == state:
		return
	_state = state.duplicate(true)
	var words: Array = state.get("practice", [])
	while _rows.size() > words.size():
		_rows.pop_back().surface.free()
	while _rows.size() < words.size():
		var surface := Panel.new()
		surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(surface)
		var background := ProgressBar.new()
		background.show_percentage = false
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.add_theme_stylebox_override("background", StyleBoxEmpty.new())
		background.add_theme_stylebox_override("fill",
			Style.box(Color("#c1e1c5"), Color.TRANSPARENT, 10, 0))
		surface.add_child(background)
		var label: Label = Style.label("", 16)
		label.add_theme_font_override("font", Style.HEADING_FONT)
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.add_child(label)
		var fraction: Label = Style.label("", 14)
		fraction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fraction.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fraction.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.add_child(fraction)
		var picture := TextureRect.new()
		picture.name = "PracticeWordPicture"
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.add_child(picture)
		var steps: Array[TextureRect] = []
		for index in range(3):
			var star := TextureRect.new()
			star.texture = STAR
			star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			star.mouse_filter = Control.MOUSE_FILTER_IGNORE
			surface.add_child(star)
			steps.append(star)
		_rows.append({"surface": surface, "background_progress": background, "label": label,
			"fraction": fraction, "picture": picture, "steps": steps})
	for index in range(words.size()):
		var item: Dictionary = words[index]
		var row: Dictionary = _rows[index]
		row.label.text = str(item.text)
		row.fraction.text = "%d/%d" % [int(item.current), int(item.required)]
		row.background_progress.max_value = int(item.required)
		row.background_progress.value = int(item.current)
		row.picture.texture = WordArt.texture(str(item.get("image", "")), row.picture)
		row.picture.visible = row.picture.texture != null
		for index_step in range(3):
			row.steps[index_step].modulate = Color("#e3aa35") if index_step < int(item.current) else Color("#b9c9bf")
		row.label.add_theme_color_override("font_color", Style.GOOD if item.mastered else Style.INK)
		var card: StyleBoxFlat = Style.box(Color("#f5fbef") if item.mastered else Color("#fffdf7"),
			Color("#c5d9b0") if item.mastered else Color("#dce7dd"), ceili(14.0 / _scale), 1)
		card.shadow_color = Color(0.15, 0.28, 0.20, 0.08)
		card.shadow_size = ceili(3.0 / _scale)
		card.shadow_offset = Vector2(0, 2.0 / _scale)
		row.surface.add_theme_stylebox_override("panel", card)
		row.fraction.add_theme_stylebox_override("normal",
			Style.box(Color("#deefd7") if item.mastered else Color("#edf3ee"), Color.TRANSPARENT, ceili(8.0 / _scale), 0))
		row.surface.set("accessibility_name", "%s. %d of %d correct. %s" % [
			item.text, int(item.current), int(item.required), "Mastered." if item.mastered else "Practising."])
	visible = not words.is_empty()
	_layout()


func configure_layout(area: Rect2, ui_scale: float, compact: bool) -> void:
	position = area.position
	size = area.size
	_scale = ui_scale
	_compact = compact
	_layout()


func _layout() -> void:
	if not visible:
		return
	var s: float = _scale
	var padding: float = 6.0 / s
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_title.add_theme_font_size_override("font_size", ceili((12.0 if _compact else 20.0) / s))
	_title.text = "Stage %d" % int(_state.get("number", 1)) if _compact else "Word goals"
	_subtitle.visible = not _compact
	_subtitle.text = "%d of %d mastered" % [int(_state.get("mastered", 0)), _rows.size()]
	_subtitle.add_theme_font_size_override("font_size", ceili(12.0 / s))
	_medal.visible = not _compact
	_medal.position = Vector2(0, 2.0) / s
	_medal.size = Vector2(36, 40) / s
	var stacked: bool = _compact and size.y * s >= 40.0
	var title_height: float = 18.0 / s if stacked else size.y - padding * 2.0
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.position = Vector2(padding if _compact else 46.0 / s, 0.0)
	_title.size = Vector2(size.x - (padding * 2.0 if _compact else 46.0 / s) if stacked or not _compact else 62.0 / s,
		title_height if _compact else 28.0 / s)
	_subtitle.position = Vector2(46, 28) / s
	_subtitle.size = Vector2(maxf(1.0, size.x - 46.0 / s), 20.0 / s)
	_scroll.position = Vector2(padding if stacked or not _compact else 70.0 / s,
		18.0 / s if stacked else 58.0 / s if not _compact else 0.0)
	_scroll.size = (size - _scroll.position - Vector2(padding, 0.0 if _compact else padding)).max(Vector2.ONE)
	_scroll.horizontal = _compact
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if _compact else ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if _compact else ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var cursor: float = 0.0
	for row: Dictionary in _rows:
		var card: StyleBoxFlat = row.surface.get_theme_stylebox("panel")
		card.set_corner_radius_all(ceili((10.0 if _compact else 14.0) / s))
		card.shadow_size = ceili(3.0 / s)
		card.shadow_offset = Vector2(0, 2.0 / s)
		var badge: StyleBoxFlat = row.fraction.get_theme_stylebox("normal")
		badge.set_content_margin_all(1.0 / s)
		badge.content_margin_left = 4.0 / s
		badge.content_margin_right = 4.0 / s
		badge.set_corner_radius_all(ceili(8.0 / s))
		var font_size: int = ceili((13.0 if _compact else 18.0) / s)
		row.label.add_theme_font_size_override("font_size", font_size)
		row.fraction.add_theme_font_size_override("font_size", ceili(12.0 / s))
		var width: float = minf(220.0 / s, maxf(82.0 / s,
			Style.HEADING_FONT.get_string_size(row.label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 44.0 / s)) \
			if _compact else _scroll.size.x
		var height: float = _scroll.size.y if _compact else 52.0 / s
		row.surface.position = Vector2(cursor, 0.0) if _compact else Vector2(0.0, cursor)
		row.surface.size = Vector2(width, height)
		row.background_progress.position = Vector2.ONE / s
		row.background_progress.size = (row.surface.size - Vector2.ONE * 2.0 / s).max(Vector2.ONE)
		row.background_progress.get_theme_stylebox("fill").set_corner_radius_all(
			maxi(0, ceili((10.0 if _compact else 14.0) / s) - 1))
		row.fraction.visible = not _compact
		var picture_edge: float = (20.0 if _compact else 38.0) / s
		row.picture.position = Vector2(6.0 / s, (height - picture_edge) * 0.5)
		row.picture.size = Vector2.ONE * picture_edge
		var left: float = (32.0 if _compact else 58.0) / s if row.picture.visible else 10.0 / s
		row.label.position = Vector2(left, 0.0 if _compact else 4.0 / s)
		row.label.size = Vector2(maxf(1.0, width - left - 10.0 / s),
			height if _compact else 26.0 / s)
		row.fraction.position = Vector2(width - 37.0 / s, (height - 20.0 / s) * 0.5 if _compact else 28.0 / s)
		row.fraction.size = Vector2(30.0, 20.0) / s
		for index in range(3):
			var star: TextureRect = row.steps[index]
			star.visible = not _compact
			star.position = Vector2(left + index * 17.0 / s, 32.0 / s)
			star.size = Vector2.ONE * 13.0 / s
		cursor += width + 8.0 / s if _compact else height + 8.0 / s
	_content.custom_minimum_size = Vector2(maxf(1.0, cursor - 8.0 / s), _scroll.size.y) if _compact \
		else Vector2(_scroll.size.x, maxf(1.0, cursor - 8.0 / s))
	_scroll.focus_mode = Control.FOCUS_ALL if (_content.custom_minimum_size.x > _scroll.size.x + 0.1 \
		or _content.custom_minimum_size.y > _scroll.size.y + 0.1) else Control.FOCUS_NONE
	_scroll.set("accessibility_name", "Current stage practice words and mastery progress")


func snapshot() -> Dictionary:
	var words: Array = _state.get("practice", []).duplicate(true)
	for index in range(words.size()):
		var rect: Rect2 = _rows[index].surface.get_global_rect()
		words[index]["rect"] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	var bounds: Rect2 = get_global_rect()
	return {"visible": is_visible_in_tree(), "compact": _compact, "words": words,
		"rect": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]}
