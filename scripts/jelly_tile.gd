extends Button
## Authored gel artwork with a separate, undistorted learning label.

const Style = preload("res://scripts/ui_style.gd")
const WordArt = preload("res://scripts/word_art.gd")
const Surface = preload("res://scripts/jelly_surface.gdshader")
const Motion = preload("res://scripts/jelly_motion.gd")
const CONTACT_SHADOW = preload("res://assets/images/jelly-match/contact-shadow.png")
const SHAPE_SDF = preload("res://assets/images/jelly-match/gel-coral-material.png")

static var _contact_outlines: Dictionary = {}

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
var _contact_outline := PackedVector2Array()
var _surface_parameters: Dictionary = {}

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
	_gel.set_shader_parameter("shape_sdf", SHAPE_SDF)
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
	if not _contact_outlines.has(surface):
		# Trace the acquired skin once, excluding its transparent padding and shadow.
		var mask := BitMap.new()
		mask.create_from_image_alpha(surface.get_image(), 0.5)
		var outlines: Array[PackedVector2Array] = mask.opaque_to_polygons(Rect2i(Vector2i.ZERO, mask.get_size()), 0.5)
		var outline: PackedVector2Array = outlines[0]
		for index in range(outline.size()):
			outline[index] /= Vector2(mask.get_size())
		_contact_outlines[surface] = outline
	_contact_outline = _contact_outlines[surface]
	_picture.texture = picture
	WordArt.bind(picture, _picture)
	_badge.texture = chest
	_badge.visible = bool(cell.get("chest", false)) and not combined and not _projection
	_accent = accent
	_refresh_feedback()
	_label.text = str(word.text)
	set("accessibility_name", "%s %s%s. Press to hear the word. Drag onto its matching partner." % [
		"Picture of" if kind == "picture" else "Word", str(word.text), ". Treasure jelly" if _badge.visible else ""])
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
	_gel.set_shader_parameter("rim_color", Color("#507968") if _projection else Color("#ae702b") if mark == 3 else _accent)
	_gel.set_shader_parameter("rim_strength", 0.8 if _projection else 1.0 if mark >= 2 else 0.85 if mark == 1 else 0.0)
	_gel.set_shader_parameter("rim_width", 1.0 if _projection or mark >= 2 else 0.8)
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

func contact_outline(stretch: Vector2 = Vector2.ONE) -> PackedVector2Array:
	var outline := PackedVector2Array()
	var foot: Vector2 = size * Vector2(0.5, Motion.FOOT_Y)
	for point: Vector2 in _contact_outline:
		outline.append(position + _visual.position + foot + (point * size - foot) * stretch)
	# Contact squash and pull are feedback, so they cannot change their own hit
	# test and repeatedly disconnect/reconnect a pair at the same pointer position.
	return outline

func set_projection(value: bool) -> void:
	if _projection == value:
		return
	_projection = value
	_layout()
	_refresh_feedback()
	if value:
		_badge.hide()

func _set_surface_parameter(parameter: StringName, value: Variant) -> void:
	# Only tile-owned parameters are cached. Placement and contact can override
	# the rim directly, so their feedback parameters stay outside this cache.
	if _surface_parameters.has(parameter) and _surface_parameters[parameter] == value:
		return
	_surface_parameters[parameter] = value
	_gel.set_shader_parameter(parameter, value)

func deform(amount: float, beat: float, stretch: Vector2 = Vector2.ONE) -> void:
	_set_surface_parameter(&"bend", amount)
	_set_surface_parameter(&"beat", beat)
	var pivot: Vector2 = size * Vector2(0.5, Motion.FOOT_Y)
	if _surface.pivot_offset != pivot:
		_surface.pivot_offset = pivot
	_base_stretch = stretch * (Vector2(1.025, 0.97) if _mark == 3 and not _reduced_motion else Vector2.ONE)
	if _surface.scale != _base_stretch:
		_surface.scale = _base_stretch

func set_preview_pressure(pressure: float, sway: float, pull: float = 0.0) -> void:
	_set_surface_parameter(&"preview_pressure", pressure)
	_set_surface_parameter(&"preview_sway", sway)
	_set_surface_parameter(&"preview_pull", pull)
	_update_support(0.0, clampf(pressure / 0.20 + pull, 0.0, 1.0), true, size.y * Motion.FOOT_Y * pull)

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
	var rim: Color = Color("#fff4d4") if kind_value == "touch" else Color("#24856a") if kind_value == "match" else Color("#b54649")
	_gel.set_shader_parameter("rim_color", rim)
	_gel.set_shader_parameter("rim_strength", 0.7 if kind_value == "touch" else 1.0)
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
	_update_support(lift, compression, visible_shadow)

func _update_support(lift: float, compression: float, visible_shadow: bool, drop: float = 0.0) -> void:
	# The source-painted shadow stays on the support while the body descends.
	var distance: float = clampf(lift / maxf(1.0, size.y * 2.0), 0.0, 1.0)
	var extent := size * Vector2(lerpf(0.64, 0.94, distance) + compression * 0.07, lerpf(0.082, 0.19, distance))
	var origin := Vector2((size.x - extent.x) * 0.5, size.y * Motion.FOOT_Y + lift - extent.y * 0.6 + drop)
	var alpha: float = lerpf(1.0, 0.16, distance)
	if _shadow.visible != visible_shadow:
		_shadow.visible = visible_shadow
	if _shadow.size != extent:
		_shadow.size = extent
	if _shadow.position != origin:
		_shadow.position = origin
	if _shadow.modulate.a != alpha:
		_shadow.modulate.a = alpha

func _layout() -> void:
	if _visual == null:
		return
	_visual.size = size
	_content_offset = Vector2.ZERO
	_surface.size = size
	_set_surface_parameter(&"surface_size", size)
	# Stay within the artwork's transparent margin, including tiny landscape tiles.
	_set_surface_parameter(&"rim_uv", clampf(2.8 / maxf(1.0, size.x * Style.ui_scale(self)), 0.014, 0.03))
	_picture.visible = not _projection and (kind == "picture" or combined)
	_label.visible = not _projection and (kind == "word" or combined)
	_picture.position = size * (Vector2(0.26, 0.18) if combined else Vector2(0.18, 0.20))
	_picture.size = size * (Vector2(0.48, 0.42) if combined else Vector2(0.64, 0.58))
	_label.position = size * Vector2(0.13, 0.60 if combined else 0.35)
	_label.size = size * Vector2(0.74, 0.20 if combined else 0.30)
	var scale_factor: float = Style.ui_scale(self)
	var minimum_font_size: int = maxi(1, ceili(9.0 / scale_factor))
	var font_size: int = maxi(ceili(10.0 / scale_factor), int(size.x * (0.15 if combined else 0.21)))
	var available: float = _label.size.x - 2.0
	# The preview is measured in canvas units; its reading floor is in display pixels.
	while font_size > minimum_font_size and Style.HEADING_FONT.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
		font_size -= 1
	_label.add_theme_font_size_override("font_size", font_size)
	_badge.position = size * Vector2(0.69, 0.70)
	_badge.size = size * 0.30
	set_support(0.0, 0.0, not _projection)
