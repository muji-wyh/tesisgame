extends "res://scripts/jelly_tile.gd"
## The existing painted skin stretches with mass; letters and artwork do not.

var valid_word: bool = false
var fragments: int = 0
var _fragment_badges: Array[TextureRect] = []
var _fragment_texture: Texture2D
var _fragment_overflow: Label
var _unit: float = 60.0
var palette_index: int = -1
const COMPLETION_GLOW = preload("res://assets/chests/particles/portal_glow.png")
const COMPLETION_LIGHT = preload("res://scripts/jelly_completion_glow.gdshader")
const COMPLETION_SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
var completion_hint: bool = false
var completion_scale: float = 1.0
var _completion_glow: TextureRect
var _completion_glints: Array[TextureRect] = []

func set_completion_hint(active: bool, elapsed: float, reduced: bool) -> void:
	var was_active: bool = completion_hint
	completion_hint = active and not _projection
	if not completion_hint and not was_active:
		return
	var previous_scale: float = completion_scale
	var enter: float = smoothstep(0.0, 0.14, elapsed)
	var breath: float = (1.0 - cos(maxf(0.0, elapsed - 0.14) * TAU / 1.45)) * 0.5
	completion_scale = 1.0 + enter * (0.035 + breath * 0.02) if completion_hint and not reduced else 1.0
	# Only the painted skin breathes. Letters, badges, layout and contact stay fixed.
	_base_stretch *= completion_scale / previous_scale
	_surface.scale *= completion_scale / previous_scale
	_gel.set_shader_parameter("completion_strength", (0.9 if reduced else 0.6 + enter * 0.4) if completion_hint else 0.0)
	_gel.set_shader_parameter("completion_glint", -2.0 if reduced else -0.3 + fposmod(elapsed, 1.8) * 1.6)
	if completion_hint and _completion_glow == null:
		_completion_glow = TextureRect.new()
		_completion_glow.texture = COMPLETION_GLOW
		_completion_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_completion_glow.stretch_mode = TextureRect.STRETCH_SCALE
		_completion_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var light := ShaderMaterial.new()
		light.shader = COMPLETION_LIGHT
		_completion_glow.material = light
		# Above the contact shadow, below the gel and its undistorted label.
		_completion_glow.z_index = 0
		add_child(_completion_glow)
		move_child(_completion_glow, _visual.get_index())
		for index in range(2):
			var glint := TextureRect.new()
			glint.texture = COMPLETION_SPARKLE
			glint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			glint.stretch_mode = TextureRect.STRETCH_SCALE
			glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(glint)
			_completion_glints.append(glint)
	if _completion_glow != null:
		_completion_glow.visible = completion_hint
		var spread: float = 1.0 if reduced else 1.0 + breath * 0.035
		var reach: float = minf(minf(size.x, size.y), 80.0 / Style.ui_scale(self))
		_completion_glow.size = size + Vector2(0.50, 0.56) * reach * spread
		_completion_glow.position = (size - _completion_glow.size) * 0.5 - Vector2(0.0, size.y * 0.035)
		_completion_glow.modulate = Color(1.0, 0.83, 0.36, 0.68 if reduced else 0.38 + enter * (0.18 + breath * 0.16))
	for index in range(_completion_glints.size()):
		var glint: TextureRect = _completion_glints[index]
		glint.visible = completion_hint
		var twinkle: float = 0.75 if reduced else pow((1.0 + sin(elapsed * TAU / 1.6 - index * PI)) * 0.5, 2.0)
		var edge: float = minf(minf(size.x, size.y) * (0.28 if index == 0 else 0.21), 20.0 / Style.ui_scale(self))
		glint.size = Vector2.ONE * edge
		glint.pivot_offset = glint.size * 0.5
		glint.position = size * (Vector2(0.85, 0.20) if index == 0 else Vector2(0.10, 0.69)) - glint.size * 0.5
		glint.scale = Vector2.ONE * (1.0 if reduced else 0.82 + twinkle * 0.3)
		glint.modulate = Color(1.0, 0.86, 0.43, (1.0 if reduced else enter) * (0.52 + twinkle * 0.48))
	if completion_hint or was_active:
		_refresh_feedback()

func deform(amount: float, beat: float, stretch: Vector2 = Vector2.ONE) -> void:
	super.deform(amount, beat, stretch * completion_scale)

func set_palette(index: int, hue: float) -> void:
	palette_index = index
	_gel.set_shader_parameter("palette_hue", hue)

func configure(cell: Dictionary, surface: Texture2D, picture: Texture2D, chest: Texture2D, accent: Color, show_both: bool = false) -> void:
	valid_word = not cell.get("word", {}).is_empty() and int(cell.get("mass", 1)) > 1
	fragments = int(cell.get("fragments", 0))
	var face: Dictionary = cell.duplicate(true)
	face.word = {"text": str(cell.get("text", ""))} if not valid_word else cell.word
	face.kind = "word"
	super.configure(face, surface, picture, chest, accent, valid_word)
	_fragment_texture = chest
	_surface.stretch_mode = TextureRect.STRETCH_SCALE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _fragment_overflow == null:
		_fragment_overflow = Style.label("", 10)
		_fragment_overflow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_visual.add_child(_fragment_overflow)
	while _fragment_badges.size() < mini(fragments, 6):
		_fragment_badges.append(_texture())
	set("accessibility_name", "%s. %s Drag to a fitting empty space to move it. Shift+Enter selects this jelly to merge with another.%s" % [str(cell.get("text", "")),
		"Word complete. Press to collect %d coins, or drag to keep building." % (int(cell.get("mass", 1)) * 50) if valid_word
		else "Press to split the last merge, or drag to keep building." if int(cell.get("mass", 1)) > 1
		else "Drag this part before another part to build a word.",
		" %d chest fragments." % fragments if fragments > 0 else ""])
	_layout()
	_refresh_feedback()

func set_chest_texture(texture: Texture2D) -> void:
	super.set_chest_texture(texture)
	_fragment_texture = texture
	_layout()

func _refresh_feedback(reset_motion: bool = false) -> void:
	super._refresh_feedback(reset_motion)
	if completion_hint and _mark < 2 and _contact_kind == "none":
		_gel.set_shader_parameter("rim_color", Color("#ffe49a"))
		_gel.set_shader_parameter("rim_strength", 1.0)
		_gel.set_shader_parameter("rim_width", 1.45)
	elif valid_word and _mark == 0 and _contact_kind == "none":
		_gel.set_shader_parameter("rim_color", Color("#de9b29"))
		_gel.set_shader_parameter("rim_strength", 0.85)
		_gel.set_shader_parameter("rim_width", 1.1)

func _layout() -> void:
	if _visual == null:
		return
	super._layout()
	_badge.hide()
	_surface.stretch_mode = TextureRect.STRETCH_SCALE
	_unit = minf(size.y, size.x)
	_picture.visible = valid_word and not _projection
	_label.visible = not _projection
	var side_by_side: bool = valid_word and size.x > size.y * 1.45
	if side_by_side:
		_picture.position = Vector2(size.x * 0.09, size.y * 0.16)
		_picture.size = Vector2(minf(size.y * 0.66, size.x * 0.32), size.y * 0.60)
		_label.position = Vector2(size.x * 0.43, size.y * 0.21)
		_label.size = Vector2(size.x * 0.46, size.y * (0.48 if fragments > 0 else 0.54))
	elif valid_word:
		_picture.position = size * Vector2(0.23, 0.14)
		_picture.size = size * Vector2(0.54, 0.42)
		_label.position = size * Vector2(0.12, 0.53)
		_label.size = size * Vector2(0.76, 0.25)
	else:
		_label.position = size * Vector2(0.11, 0.22)
		_label.size = size * Vector2(0.78, 0.47 if fragments > 0 else 0.53)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var pixels: int = maxi(12, mini(28, roundi(_unit * 0.34)))
	# Logical font pixels also scale with the viewport. Fit the actual line
	# height so small column-aligned previews keep their letters visible.
	while pixels > 1 and Style.HEADING_FONT.get_height(pixels) > _label.size.y:
		pixels -= 1
	# Wrapped content has a real second line; long builds never use ellipses.
	var lines: int = maxi(1, floori(_label.size.y / (pixels * 1.15)))
	while pixels > 1 and Style.HEADING_FONT.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > _label.size.x * lines:
		pixels -= 1
		lines = maxi(1, floori(_label.size.y / (pixels * 1.15)))
	_label.add_theme_font_size_override("font_size", pixels)
	var badge_size: float = minf(_unit * 0.32, 24.0 / maxf(0.5, Style.ui_scale(self)))
	var badge_gap: float = badge_size * 0.74
	var count: int = mini(fragments, 6)
	var start: float = size.x * 0.84 - badge_size - maxf(0, count - 1) * badge_gap
	for index in range(_fragment_badges.size()):
		var badge: TextureRect = _fragment_badges[index]
		badge.texture = _fragment_texture
		badge.visible = not _projection and index < count
		badge.size = Vector2.ONE * badge_size
		badge.position = Vector2(maxf(size.x * 0.09, start) + index * badge_gap, size.y * 0.72)
	if _fragment_overflow != null:
		_fragment_overflow.visible = not _projection and fragments > 6
		_fragment_overflow.text = "+%d" % maxi(0, fragments - 6)
		_fragment_overflow.position = Vector2(size.x * 0.84, size.y * 0.73)
		_fragment_overflow.size = Vector2(size.x * 0.12, badge_size)
		_fragment_overflow.add_theme_font_size_override("font_size", maxi(9, int(badge_size * 0.6)))

func visible_fragment_badges() -> int:
	return mini(fragments, 6) if not _projection else 0
