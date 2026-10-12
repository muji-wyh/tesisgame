extends "res://scripts/jelly_tile.gd"
## The existing painted skin stretches with mass; letters and artwork do not.

var valid_word: bool = false
var fragments: int = 0
var _fragment_badges: Array[TextureRect] = []
var _fragment_texture: Texture2D
var _fragment_overflow: Label
var _unit: float = 60.0

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
	set("accessibility_name", "%s. %s%s" % [str(cell.get("text", "")),
		"Word complete. Press to collect %d coins, or drag to keep building." % (int(cell.get("mass", 1)) * 50) if valid_word else "Drag this part before another part to build a word.",
		" %d chest fragments." % fragments if fragments > 0 else ""])
	_layout()
	_refresh_feedback()

func set_chest_texture(texture: Texture2D) -> void:
	super.set_chest_texture(texture)
	_fragment_texture = texture
	_layout()

func _refresh_feedback(reset_motion: bool = false) -> void:
	super._refresh_feedback(reset_motion)
	if valid_word and _mark == 0 and _contact_kind == "none":
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
	while pixels > 10 and Style.HEADING_FONT.get_height(pixels) > _label.size.y:
		pixels -= 1
	# Wrapped content has a real second line; long builds never use ellipses.
	var lines: int = maxi(1, floori(_label.size.y / (pixels * 1.15)))
	while pixels > 10 and Style.HEADING_FONT.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > _label.size.x * lines:
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
