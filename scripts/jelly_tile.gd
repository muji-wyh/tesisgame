extends Button
## Authored gel artwork with a separate, undistorted learning label.

const Style = preload("res://scripts/ui_style.gd")
const Surface = preload("res://scripts/jelly_surface.gdshader")
const Motion = preload("res://scripts/jelly_motion.gd")
const CONTACT_SHADOW = preload("res://assets/images/jelly-match/contact-shadow.png")

var tile_id: int = -1
var word: Dictionary = {}
var kind: String = "word"
var highlighted: bool = false
var selected: bool = false
var combined: bool = false
var _visual: Control
var _shadow: TextureRect
var _surface: TextureRect
var _picture: TextureRect
var _label: Label
var _badge: TextureRect
var _gel: ShaderMaterial
var _accent := Color("#357d70")
var _feedback_enabled: bool = true
var _reduced_motion: bool = false
var _mark: int = 0
var _lift: Tween
var _projection: bool = false
var _contact_kind: String = "none"
var _base_stretch := Vector2.ONE
var _content_offset := Vector2.ZERO

func _init() -> void:
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_shadow = TextureRect.new()
	_shadow.texture = CONTACT_SHADOW
	_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shadow.stretch_mode = TextureRect.STRETCH_SCALE
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow.z_index = -1
	add_child(_shadow)
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
	focus_entered.connect(_refresh_feedback)
	focus_exited.connect(_refresh_feedback)

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
	_badge.visible = bool(cell.get("chest", false)) and not combined and not _projection
	_accent = accent
	_refresh_feedback()
	_label.text = str(word.text)
	set("accessibility_name", "%s %s%s. Press to hear the word. Drag onto its matching partner." % [
		"Picture of" if kind == "picture" else "Word", str(word.text), ". Treasure jelly" if _badge.visible else ""])
	tooltip_text = str(word.text)
	_layout()

func set_marked(value: bool, picked: bool = false, enabled: bool = true, reduced: bool = false) -> void:
	if highlighted == value and selected == picked and _feedback_enabled == enabled and _reduced_motion == reduced:
		return
	highlighted = value
	selected = picked
	_feedback_enabled = enabled
	var motion_changed: bool = _reduced_motion != reduced
	_reduced_motion = reduced
	_refresh_feedback(motion_changed)

func _refresh_feedback(reset_motion: bool = false) -> void:
	# Pointer selection, drop contact and keyboard focus have separate weights.
	var mark: int = (3 if highlighted else 2 if selected else 1 if has_focus() else 0) if _feedback_enabled else 0
	_gel.set_shader_parameter("rim_color", Color("#ae702b") if mark == 3 else _accent)
	_gel.set_shader_parameter("rim_strength", 1.0 if mark >= 2 else 0.85 if mark == 1 else 0.0)
	_gel.set_shader_parameter("rim_width", 1.0 if mark >= 2 else 0.8)
	if mark == _mark and not reset_motion:
		return
	_mark = mark
	if _lift != null:
		_lift.kill()
	_visual.position = Vector2.ZERO
	if mark == 2 and not _reduced_motion and is_inside_tree():
		var rise: float = minf(size.y * 0.035, 3.0 / Style.ui_scale(self))
		_lift = create_tween()
		_lift.tween_property(_visual, "position:y", -rise * 1.2, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_lift.tween_property(_visual, "position:y", -rise, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func set_chest_texture(texture: Texture2D) -> void:
	_badge.texture = texture

func set_projection(value: bool) -> void:
	_projection = value
	_layout()
	if value:
		_badge.hide()
		_gel.set_shader_parameter("rim_color", Color("#507968"))
		_gel.set_shader_parameter("rim_strength", 0.8)
		_gel.set_shader_parameter("rim_width", 1.0)

func deform(amount: float, beat: float, stretch: Vector2 = Vector2.ONE) -> void:
	_gel.set_shader_parameter("bend", amount)
	_gel.set_shader_parameter("beat", beat)
	_surface.pivot_offset = size * Vector2(0.5, Motion.FOOT_Y)
	_base_stretch = stretch * (Vector2(1.025, 0.97) if _mark == 3 and not _reduced_motion else Vector2.ONE)
	_surface.scale = _base_stretch

func set_preview_pressure(pressure: float, sway: float) -> void:
	_gel.set_shader_parameter("preview_pressure", pressure)
	_gel.set_shader_parameter("preview_sway", sway)
	set_support(0.0, clampf(pressure / 0.06, 0.0, 1.0))

func set_contact(kind_value: String, direction: Vector2 = Vector2.ZERO, strength: float = 0.0, reduced: bool = false) -> void:
	if kind_value == "none" and _contact_kind == "none":
		return
	_contact_kind = kind_value
	# Both learning faces stay above the overlapping skins during contact.
	_picture.z_index = 45 if kind_value != "none" else 0
	_label.z_index = 45 if kind_value != "none" else 0
	_picture.position -= _content_offset
	_label.position -= _content_offset
	_content_offset = Vector2.ZERO
	_surface.position = Vector2.ZERO
	_surface.scale = _base_stretch
	_gel.set_shader_parameter("contact_direction", direction)
	_gel.set_shader_parameter("contact_strength", 0.0 if reduced else strength)
	_gel.set_shader_parameter("contact_match", kind_value == "match")
	if kind_value == "none":
		_refresh_feedback()
		return
	_gel.set_shader_parameter("rim_color", Color("#24856a") if kind_value == "match" else Color("#b54649"))
	_gel.set_shader_parameter("rim_strength", 1.0)
	_gel.set_shader_parameter("rim_width", 1.0)
	if reduced:
		_surface.scale = Vector2.ONE
		if _lift != null:
			_lift.kill()
		_visual.position = Vector2.ZERO
		return
	var pull: float = -strength * (0.25 if kind_value == "match" else 0.16)
	_surface.position = direction * size * pull
	_content_offset = _surface.position
	_picture.position += _content_offset
	_label.position += _content_offset
	# Pressure changes the gel skin, never the word, picture or hit rectangle.
	var along := Vector2(absf(direction.x), absf(direction.y))
	_surface.scale = _base_stretch * (Vector2.ONE + (along * 2.0 - Vector2.ONE) * strength * (0.08 if kind_value == "match" else -0.10))


func set_support(lift: float = 0.0, compression: float = 0.0, visible_shadow: bool = true) -> void:
	# The source-painted shadow stays on the support while the body descends.
	var distance: float = clampf(lift / maxf(1.0, size.y * 2.0), 0.0, 1.0)
	_shadow.visible = visible_shadow
	_shadow.size = size * Vector2(lerpf(0.68, 0.94, distance) + compression * 0.07, lerpf(0.095, 0.19, distance))
	_shadow.position = Vector2((size.x - _shadow.size.x) * 0.5, size.y * Motion.FOOT_Y + lift - _shadow.size.y * 0.6)
	_shadow.modulate.a = lerpf(0.6, 0.12, distance)

func _layout() -> void:
	if _visual == null:
		return
	_visual.size = size
	_content_offset = Vector2.ZERO
	_surface.size = size
	# Stay within the artwork's transparent margin, including tiny landscape tiles.
	_gel.set_shader_parameter("rim_uv", clampf(2.8 / maxf(1.0, size.x * Style.ui_scale(self)), 0.014, 0.03))
	_picture.visible = not _projection and (kind == "picture" or combined)
	_label.visible = not _projection and (kind == "word" or combined)
	_picture.position = size * (Vector2(0.26, 0.18) if combined else Vector2(0.18, 0.20))
	_picture.size = size * (Vector2(0.48, 0.42) if combined else Vector2(0.64, 0.58))
	_label.position = size * Vector2(0.13, 0.60 if combined else 0.35)
	_label.size = size * Vector2(0.74, 0.20 if combined else 0.30)
	var font_size: int = maxi(10, int(size.x * (0.15 if combined else 0.21)))
	var available: float = _label.size.x - 2.0
	while font_size > 9 and Style.HEADING_FONT.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
		font_size -= 1
	_label.add_theme_font_size_override("font_size", font_size)
	_badge.position = size * Vector2(0.69, 0.70)
	_badge.size = size * 0.30
	set_support(0.0, 0.0, not _projection)
