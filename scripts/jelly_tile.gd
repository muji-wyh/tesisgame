extends Button
## Authored gel artwork with a separate, undistorted learning label.

const Style = preload("res://scripts/ui_style.gd")
const Surface = preload("res://scripts/jelly_surface.gdshader")

var tile_id: int = -1
var word: Dictionary = {}
var kind: String = "word"
var highlighted: bool = false
var selected: bool = false
var combined: bool = false
var _visual: Control
var _surface: TextureRect
var _picture: TextureRect
var _label: Label
var _badge: TextureRect
var _gel: ShaderMaterial
var _accent := Color("#357d70")

func _init() -> void:
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_visual = Control.new()
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_visual)
	_surface = _texture()
	_gel = ShaderMaterial.new()
	_gel.shader = Surface
	_surface.material = _gel
	_picture = _texture()
	_label = Style.label("", 20)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.clip_text = true
	_label.add_theme_color_override("font_color", Color("#243f49"))
	_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.65))
	_label.add_theme_constant_override("outline_size", 2)
	_visual.add_child(_label)
	_badge = _texture()
	resized.connect(_layout)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _texture() -> TextureRect:
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.add_child(image)
	return image

func configure(cell: Dictionary, surface: Texture2D, picture: Texture2D, chest: Texture2D, accent: Color, show_both: bool = false) -> void:
	tile_id = int(cell.id)
	word = cell.word
	kind = str(cell.kind)
	combined = show_both
	_surface.texture = surface
	_picture.texture = picture
	_badge.texture = chest
	_badge.visible = bool(cell.get("chest", false)) and not combined
	_accent = accent
	_label.text = str(word.text)
	set("accessibility_name", "%s %s%s. Press to select, then choose its matching partner." % [
		"Picture of" if kind == "picture" else "Word", str(word.text), ". Treasure jelly" if _badge.visible else ""])
	tooltip_text = str(word.text)
	_layout()

func set_marked(value: bool, picked: bool = false) -> void:
	if highlighted == value and selected == picked:
		return
	highlighted = value
	selected = picked
	queue_redraw()

func set_chest_texture(texture: Texture2D) -> void:
	_badge.texture = texture

func deform(amount: float, beat: float, stretch: Vector2 = Vector2.ONE) -> void:
	_gel.set_shader_parameter("bend", amount)
	_gel.set_shader_parameter("beat", beat)
	_surface.pivot_offset = size * Vector2(0.5, 0.78)
	_surface.scale = stretch

func _layout() -> void:
	if _visual == null:
		return
	_visual.size = size
	_surface.size = size
	_picture.visible = kind == "picture" or combined
	_label.visible = kind == "word" or combined
	_picture.position = size * (Vector2(0.31, 0.25) if combined else Vector2(0.25, 0.29))
	_picture.size = size * (Vector2(0.38, 0.34) if combined else Vector2(0.50, 0.46))
	_label.position = size * Vector2(0.13, 0.60 if combined else 0.35)
	_label.size = size * Vector2(0.74, 0.20 if combined else 0.30)
	var font_size: int = maxi(10, int(size.x * (0.15 if combined else 0.21)))
	var available: float = _label.size.x - 2.0
	while font_size > 9 and Style.HEADING_FONT.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
		font_size -= 1
	_label.add_theme_font_size_override("font_size", font_size)
	_badge.position = size * Vector2(0.59, 0.56)
	_badge.size = size * 0.42
	queue_redraw()

func _draw() -> void:
	if not highlighted and not selected and not has_focus():
		return
	var color: Color = _accent.lightened(0.15) if highlighted else _accent
	var border := Style.box(Color.TRANSPARENT, color, maxi(6, int(size.x * 0.2)), 3)
	draw_style_box(border, Rect2(Vector2.ONE * 2, size - Vector2.ONE * 4))
