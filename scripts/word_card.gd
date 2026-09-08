extends Button

const Style = preload("res://scripts/ui_style.gd")

var card_data: Dictionary = {}
var picture: TextureRect
var word_label: Label
var match_mark: Label
var accent: Color = Style.GOOD


func setup(value: Dictionary) -> void:
	card_data = value
	name = value.id.replace(":", "_")
	tooltip_text = value.word.text if value.kind == "word" else "Picture: " + value.word.text
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(72, 72)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	picture = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.offset_left = 12
	picture.offset_top = 10
	picture.offset_right = -12
	picture.offset_bottom = -10
	picture.visible = value.kind == "image"
	if picture.visible:
		picture.texture = load("res://" + value.word.image)
	word_label = Style.label(value.word.text, 32)
	word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word_label.clip_text = true
	word_label.visible = value.kind == "word"
	add_child(word_label)
	word_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	match_mark = Style.label("\u2713", 28)
	match_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	match_mark.add_theme_color_override("font_color", Style.GOOD)
	add_child(match_mark)
	match_mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	match_mark.offset_right = -8
	match_mark.offset_top = 3
	match_mark.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	match_mark.hide()
	resized.connect(_fit_text)
	_fit_text()


func refresh(palette: Dictionary, selected: bool, matched: bool, wrong: bool, locked: bool) -> void:
	accent = palette.accent
	var fill: Color = Color.WHITE
	var border: Color = accent.lightened(0.68)
	if selected:
		fill = accent.lightened(0.86)
		border = accent
	elif matched:
		fill = Color("#e7f5e9")
		border = Style.GOOD
	elif wrong:
		fill = Color("#ffe8e2")
		border = Style.WRONG
	var normal: StyleBoxFlat = Style.box(fill, border, 20, 3)
	normal.shadow_color = Color(0.15, 0.22, 0.3, 0.1)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 3)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("disabled", normal)
	add_theme_stylebox_override("hover", Style.box(fill, accent, 20, 3))
	add_theme_stylebox_override("pressed", Style.box(accent.lightened(0.8), accent, 20, 3))
	add_theme_stylebox_override("focus", Style.box(Color.TRANSPARENT, accent, 20, 4))
	disabled = matched or locked
	match_mark.visible = matched
	picture.modulate.a = 0.4 if matched else 1.0
	word_label.modulate.a = 0.4 if matched else 1.0


func _fit_text() -> void:
	if word_label == null:
		return
	var font: Font = word_label.get_theme_font("font")
	var font_size: int = clampi(int(minf(size.x * 0.36, size.y * 0.52)), 20, 64)
	while font_size > 16 and font.get_string_size(word_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > size.x - 18:
		font_size -= 1
	word_label.add_theme_font_size_override("font_size", font_size)
