extends Button

const Style = preload("res://scripts/ui_style.gd")
const Motion = preload("res://scripts/card_motion.gd")

var picture: TextureRect
var title_label: Label
var detail_label: Label
var badge: Label
var in_room: bool = false
var room_word: String = ""
var item_name: String = ""
var _press_motion := Motion.new()
var _palette: Dictionary = {}
var _using: bool = false
var _showing_error: bool = false
var _goal_label: Label
var _goal_action: Control


func setup(item: Dictionary, texture: Texture2D) -> void:
	room_word = item.word_id
	item_name = item.name
	name = "RoomItem_" + item.id
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	picture = TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	title_label = Style.label(item.name, 14)
	title_label.clip_text = true
	title_label.add_theme_constant_override("line_spacing", 0)
	add_child(title_label)
	detail_label = Style.label("", 12)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_constant_override("line_spacing", 0)
	add_child(detail_label)
	badge = Style.label("", 11)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(badge)
	resized.connect(_layout)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			stop_press())
	_layout()


func present(palette: Dictionary, using: bool, detail: String) -> void:
	stop_press()
	var accent: Color = palette.accent
	var light: Color = palette.get("light", accent.lightened(0.7))
	_palette = {"accent": accent, "light": light, "spark": palette.get("spark", accent.lightened(0.3))}
	_using = using
	_showing_error = false
	detail_label.text = detail
	detail_label.add_theme_color_override("font_color", Style.MUTED)
	var scale: float = Style.ui_scale(self)
	var fill: Color = Color.WHITE.lerp(light, 0.18 if using else 0.04)
	var edge: Color = accent if using else accent.lightened(0.72)
	if in_room:
		fill = Color.TRANSPARENT
		edge = Color.TRANSPARENT
	var normal := Style.box(fill, edge, ceili(16 / scale), maxi(1, roundi((2 if using else 1) / scale)))
	normal.shadow_color = Color.TRANSPARENT if in_room else Color(accent, 0.10)
	normal.shadow_size = ceili(3 / scale)
	normal.shadow_offset = Vector2(0, 2 / scale)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("disabled", normal)
	add_theme_stylebox_override("hover", Style.box(Color.WHITE.lerp(light, 0.24 if using else 0.08), accent.lightened(0.25), ceili(16 / scale), 1))
	add_theme_stylebox_override("pressed", Style.box(Color.WHITE.lerp(light, 0.4), accent, ceili(16 / scale), 2))
	add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, Style.INK, ceili(16 / scale), maxi(2, roundi(2 / scale))))
	if in_room:
		for style_name in ["normal", "disabled", "hover", "pressed"]:
			add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	badge.text = "Using" if using else ""
	badge.add_theme_color_override("font_color", Color.WHITE)
	var pill := Style.box(accent, Color.TRANSPARENT, ceili(8 / scale), 0)
	pill.content_margin_left = 6 / scale
	pill.content_margin_right = 6 / scale
	pill.content_margin_top = 1 / scale
	pill.content_margin_bottom = 1 / scale
	badge.add_theme_stylebox_override("normal", pill)
	_layout()


func clear_goal() -> void:
	_goal_label = null
	_goal_action = null
	title_label.show()
	detail_label.visible = not _using
	_layout()


func show_goal(label: Label, action: Control) -> void:
	_goal_label = label
	_goal_action = action
	for control in [label, action]:
		if control.get_parent() != self:
			control.reparent(self)
	title_label.hide()
	detail_label.hide()
	_layout()


func show_error(summary: String) -> void:
	_showing_error = true
	if _goal_label == null:
		detail_label.text = summary
		detail_label.show()
		detail_label.add_theme_color_override("font_color", Style.WRONG.darkened(0.15))
	_layout()


func _layout() -> void:
	if picture == null:
		return
	stop_press()
	var scale: float = Style.ui_scale(self)
	if in_room:
		_layout_in_room(scale)
		return
	title_label.text = item_name
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var wide: bool = size.x * scale >= 240
	custom_minimum_size = Vector2(44, 128) / scale
	title_label.add_theme_font_size_override("font_size", ceili((12 if _showing_error and not wide else 14) / scale))
	detail_label.add_theme_font_size_override("font_size", ceili(12 / scale))
	badge.add_theme_font_size_override("font_size", ceili(11 / scale))
	badge.visible = _using
	var has_goal: bool = is_instance_valid(_goal_label)
	var art_size: float = (72 if wide else 56) / scale
	var art_width: float = size.x - (72 if has_goal else 24) / scale
	picture.position = Vector2(16 / scale if wide else 12 / scale + (art_width - art_size) * 0.5, (28 if wide else 8) / scale)
	picture.size = Vector2.ONE * art_size
	picture.show()
	var text_left: float = (104 if wide else 8) / scale
	var text_width: float = maxf(0, size.x - text_left - (16 if wide else 8) / scale)
	for label in [title_label, detail_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if wide else HORIZONTAL_ALIGNMENT_CENTER
	var title_height: float = title_label.get_theme_font("font").get_height(title_label.get_theme_font_size("font_size"))
	title_label.position = Vector2(text_left, (42 if wide else 64 if _showing_error else 66) / scale)
	title_label.size = Vector2(text_width, title_height)
	detail_label.position = Vector2(text_left, 72 / scale if wide else title_label.position.y + title_height + 2 / scale)
	detail_label.size = Vector2(text_width, maxf(0, 120 / scale - detail_label.position.y))
	var badge_width: float = maxf(48 / scale, badge.get_theme_font("font").get_string_size("Using", HORIZONTAL_ALIGNMENT_LEFT, -1, badge.get_theme_font_size("font_size")).x + 12 / scale)
	badge.position = Vector2(text_left if wide else (size.x - badge_width) * 0.5, (14 if wide else 104 if has_goal else 96) / scale)
	badge.size = Vector2(badge_width, 20 / scale)
	if _showing_error and _using and not wide:
		var header_end: float = size.x - (60 if has_goal else 8) / scale
		var thumbnail: float = maxf(0, minf(art_size, header_end - 14 / scale - badge_width))
		picture.visible = thumbnail >= 16 / scale
		picture.position = Vector2(8 / scale, 36 / scale - thumbnail * 0.5)
		picture.size = Vector2.ONE * thumbnail
		badge.position = Vector2(header_end - badge_width, 26 / scale)
	if has_goal:
		_goal_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		_goal_label.position = Vector2(text_left, (54 if wide else 66) / scale)
		var short_goal: bool = _using and not _showing_error
		_goal_label.size = Vector2(text_width, ((46 if short_goal else 66) if wide else (36 if short_goal else 54)) / scale)
		_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if wide else HORIZONTAL_ALIGNMENT_CENTER
		_goal_action.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_goal_action.offset_left = -52 / scale
		_goal_action.offset_right = -8 / scale
		_goal_action.offset_top = 8 / scale
		_goal_action.offset_bottom = 52 / scale
	queue_redraw()


func _layout_in_room(scale: float) -> void:
	custom_minimum_size = Vector2(64, 64)
	badge.hide()
	picture.show()
	picture.position = Vector2.ZERO
	picture.size = Vector2(64, 64)
	if _showing_error:
		picture.position = Vector2(12, 0)
		picture.size = Vector2(40, 40)
	title_label.visible = not _showing_error
	title_label.text = room_word
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 21)
	title_label.position = Vector2(-16, 65)
	title_label.size = Vector2(96, 26)
	detail_label.visible = _showing_error
	if _showing_error: detail_label.text = "Not saved\nTap to retry"
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.add_theme_font_size_override("font_size", 14)
	detail_label.position = Vector2(-16, 65)
	detail_label.size = Vector2(96, 40)
	queue_redraw()


func _draw() -> void:
	if picture == null or not picture.visible or _palette.is_empty():
		return
	var center := picture.get_rect().get_center()
	var radius: float = picture.size.x * 0.53
	if in_room:
		return
	draw_circle(center, radius, _palette.light.lightened(0.35))
	var spark: Color = _palette.spark
	draw_circle(center + Vector2(radius * 0.84, -radius * 0.64), radius * 0.13, spark)
	draw_circle(center + Vector2(-radius * 0.87, radius * 0.5), radius * 0.08, Color(spark, 0.7))


func play_press(reduced_motion: bool) -> void:
	_press_motion.play(picture, reduced_motion)


func stop_press() -> void:
	_press_motion.stop()


func _exit_tree() -> void:
	stop_press()
