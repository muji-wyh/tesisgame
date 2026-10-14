extends "res://scripts/jelly_tile.gd"
## The existing painted skin stretches with mass; letters and artwork do not.

var valid_word: bool = false
var fragments: int = 0
var _fragment_badges: Array[TextureRect] = []
var _fragment_texture: Texture2D
var _fragment_holder: Control
var _fragment_count: Label
var _fragment_arrival_age: float = -1.0
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
		var spread: float = 1.0 if reduced else 1.0 + breath * 0.06
		var reach: float = minf(minf(size.x, size.y), 80.0 / Style.ui_scale(self))
		_completion_glow.size = size + Vector2(0.86, 0.92) * reach * spread
		_completion_glow.position = (size - _completion_glow.size) * 0.5 - Vector2(0.0, size.y * 0.035)
		_completion_glow.modulate = Color(1.0, 0.78, 0.26, 0.86 if reduced else 0.58 + enter * (0.20 + breath * 0.14))
	for index in range(_completion_glints.size()):
		var glint: TextureRect = _completion_glints[index]
		glint.visible = completion_hint
		var twinkle: float = 0.75 if reduced else pow((1.0 + sin(elapsed * TAU / 1.6 - index * PI)) * 0.5, 2.0)
		var edge: float = minf(minf(size.x, size.y) * (0.34 if index == 0 else 0.26), 26.0 / Style.ui_scale(self))
		glint.size = Vector2.ONE * edge
		glint.pivot_offset = glint.size * 0.5
		glint.position = size * (Vector2(0.85, 0.20) if index == 0 else Vector2(0.10, 0.69)) - glint.size * 0.5
		glint.scale = Vector2.ONE * (1.0 if reduced else 0.82 + twinkle * 0.3)
		glint.modulate = Color(1.0, 0.91, 0.58, (1.0 if reduced else enter) * (0.70 + twinkle * 0.30))
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
	if _fragment_holder == null:
		_fragment_holder = Control.new()
		_fragment_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_visual.add_child(_fragment_holder)
		for index in range(2):
			var badge: TextureRect = _texture()
			badge.reparent(_fragment_holder, false)
			_fragment_badges.append(badge)
		_fragment_count = Style.label("", 10)
		_fragment_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_fragment_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_fragment_count.add_theme_font_override("font", Style.HEADING_FONT)
		_fragment_count.add_theme_color_override("font_color", Color("#674a27"))
		_fragment_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fragment_holder.add_child(_fragment_count)
	set("accessibility_name", "%s. %s Drag to a fitting empty space to move it. Shift+Enter selects this jelly to merge with another.%s" % [str(cell.get("text", "")),
		"Word complete. Press to collect, with a 1% chance of bonus coins, or drag to keep building." if valid_word
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
		_gel.set_shader_parameter("rim_color", Color("#ffe9a8"))
		_gel.set_shader_parameter("rim_strength", 1.0)
		_gel.set_shader_parameter("rim_width", 1.9)
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
	_layout_fragment_badge()
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
		if fragments > 0 and size.y < size.x * 1.3:
			# A small square shares its upper row between the picture and spelling.
			_picture.position = size * Vector2(0.10, 0.18)
			_picture.size = size * Vector2(0.30, 0.36)
			_label.position = size * Vector2(0.43, 0.18)
			_label.size = size * Vector2(0.47, 0.42)
	else:
		_label.position = size * Vector2(0.11, 0.22)
		_label.size = size * Vector2(0.78, 0.47 if fragments > 0 else 0.53)
	if fragments > 0 and _fragment_holder != null:
		var footer_top: float = _fragment_holder.position.y + _fragment_holder.size.y * (1.0 - float(_fragment_holder.get_meta("fit", 1.0))) * 0.5
		_label.size.y = minf(_label.size.y, maxf(1.0, footer_top - _unit * 0.035 - _label.position.y))
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var pixels: int = maxi(12, mini(28, roundi(_unit * 0.34)))
	_label.add_theme_font_size_override("font_size", pixels)
	# Fit the shaped lines, including rounded font height. Estimating line
	# height from font size can hide the last line of a two-part long word.
	while pixels > 1 and (_label.get_visible_line_count() < _label.get_line_count() \
		or _label.get_line_count() * _label.get_line_height() > _label.size.y):
		pixels -= 1
		_label.add_theme_font_size_override("font_size", pixels)

func _layout_fragment_badge() -> void:
	if _fragment_holder == null:
		return
	_fragment_holder.visible = fragments > 0 and not _projection
	var ui_scale: float = Style.ui_scale(self)
	var edge: float = minf(_unit * 0.28, 28.0 / ui_scale)
	var stacked: bool = fragments > 1
	var offset := Vector2(edge * 0.25, edge * 0.10) if stacked else Vector2.ZERO
	var extent := Vector2.ONE * edge + offset
	for index in range(_fragment_badges.size()):
		var badge: TextureRect = _fragment_badges[index]
		badge.texture = _fragment_texture
		badge.visible = not _projection and index < mini(fragments, 2)
		badge.size = Vector2.ONE * edge
		badge.position = offset if index == 1 else Vector2.ZERO
		badge.modulate = Color(0.93, 0.96, 0.95, 0.85) if stacked and index == 0 else Color.WHITE
	_fragment_count.visible = fragments > 2 and not _projection
	_fragment_count.text = str(fragments) if fragments > 2 else ""
	if fragments > 2:
		var pixels: int = maxi(8, roundi(minf(_unit * 0.21, 15.0 / ui_scale)))
		_fragment_count.add_theme_font_size_override("font_size", pixels)
		var height: float = maxf(edge * 0.76, Style.HEADING_FONT.get_height(pixels))
		var width: float = maxf(height, Style.HEADING_FONT.get_string_size(_fragment_count.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x + edge * 0.36)
		extent.y = maxf(extent.y, height)
		_fragment_count.position = Vector2(extent.x - edge * 0.13, extent.y - height)
		_fragment_count.size = Vector2(width, height)
		var paper := Style.box(Color("#fff7e4"), Color("#d9bd82"), ceili(height * 0.5), maxi(1, roundi(1.0 / ui_scale)))
		paper.set_content_margin_all(0.0)
		_fragment_count.add_theme_stylebox_override("normal", paper)
		extent.x = _fragment_count.position.x + width
	_fragment_holder.size = extent
	_fragment_holder.pivot_offset = extent * 0.5
	_fragment_holder.position = Vector2(size.x * 0.91 - extent.x, size.y * 0.96 - extent.y)
	# Keep even unusually large totals inside the jelly, including its receive pop.
	var fit: float = minf(1.0, minf(size.x * 0.80 / maxf(1.0, extent.x), size.y * 0.34 / maxf(1.0, extent.y)))
	_fragment_holder.set_meta("fit", fit)
	if fit < 1.0:
		_fragment_holder.position = Vector2(size.x * 0.51, size.y * 0.79) - extent * 0.5
	set_fragment_arrival(_fragment_arrival_age, _reduced_motion)

func set_fragment_arrival(age: float, reduced: bool = false) -> void:
	_fragment_arrival_age = age
	if _fragment_holder == null:
		return
	var pop: float = 0.0
	if age >= 0.0 and age < 0.48 and not reduced:
		pop = sin(minf(age / 0.11, 1.0) * PI * 0.5) * exp(-maxf(0.0, age - 0.11) * 10.0)
	_fragment_holder.scale = Vector2.ONE * float(_fragment_holder.get_meta("fit", 1.0)) * (1.0 + pop * 0.12)

func fragment_badge_snapshot() -> Dictionary:
	if _fragment_holder == null:
		return {"icons": 0, "count_text": "", "rect": [0.0, 0.0, 0.0, 0.0], "visible": false, "scale": 1.0}
	var extent: Vector2 = _fragment_holder.size * _fragment_holder.scale
	var origin: Vector2 = _fragment_holder.position + (_fragment_holder.size - extent) * 0.5
	return {"icons": visible_fragment_badges(), "count_text": _fragment_count.text if _fragment_count.visible else "",
		"rect": [origin.x, origin.y, extent.x, extent.y], "visible": _fragment_holder.visible,
		"scale": _fragment_holder.scale.x}

func visible_fragment_badges() -> int:
	return mini(fragments, 2) if not _projection else 0
