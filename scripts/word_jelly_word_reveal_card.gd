extends Control
## A content-sized picture and spelling with its own elastic release and tail.

const Style = preload("res://scripts/ui_style.gd")
const WordArt = preload("res://scripts/word_art.gd")
const LevelEffects = preload("res://scripts/word_jelly_reveal_fx.gd")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const GLINT = preload("res://assets/chests/milestone/sparkle.png")

var entry_id: int = 0
var elapsed: float = 0.0
var duration: float = 1.95
var variant_scale: float = 1.0
var reduced_motion: bool = false
var rest_position := Vector2.ZERO
var merge_level: int = 1
var _level_effects: LevelEffects
var _word: Dictionary = {}
var _batch: bool = false
var _ui_scale: float = 1.0
var _available := Vector2.ZERO
var _accent: Color = Style.GOOD
var _visual: Control
var _surface: Panel
var _aura: TextureRect
var _picture: TextureRect
var _spelling: Label
var _glints: Array[TextureRect] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_level_effects = LevelEffects.new()
	add_child(_level_effects)
	_visual = Control.new()
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_visual)
	_surface = Panel.new()
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.add_child(_surface)
	_aura = _texture(GLOW)
	_picture = _texture(null)
	_picture.name = "CollectedWordPicture"
	_spelling = Style.label("", 34)
	_spelling.name = "CollectedWordSpelling"
	_spelling.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spelling.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_spelling.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_spelling.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spelling.clip_text = true
	_spelling.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_visual.add_child(_spelling)
	for index in range(3):
		var glint := _texture(GLINT)
		glint.name = "WordGlint%d" % index
		_glints.append(glint)


func _texture(value: Texture2D) -> TextureRect:
	var result := TextureRect.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.texture = value
	_visual.add_child(result)
	return result


func configure(id: int, word: Dictionary, picture: Texture2D, accent: Color,
		batch: bool, variation: float, seconds: float, steady: bool, level: int = 1) -> void:
	entry_id = id
	merge_level = clampi(level, 1, 9)
	_word = word.duplicate(true)
	_picture.texture = picture
	WordArt.bind(picture, _picture)
	_spelling.text = str(word.text)
	_accent = accent
	_batch = batch
	variant_scale = variation
	duration = seconds
	reduced_motion = steady
	set("accessibility_name", str(word.text))


func fit_content(available: Vector2, ui_scale: float) -> void:
	_ui_scale = ui_scale
	_available = available
	var unit: float = variant_scale / ui_scale
	if _batch:
		if available.y * ui_scale < 180.0:
			unit *= 0.70
		elif available.x * ui_scale < 520.0:
			unit *= 0.80
	var max_size: Vector2 = ((available - Vector2.ONE * effect_margin() * 2.0) / 1.22).max(Vector2.ONE)
	var padding: float = 10.0 * unit
	var gap: float = 8.0 * unit if _picture.texture != null else 0.0
	var pixels: int = maxi(1, roundi((26.0 if _batch else 34.0) * unit))
	if _batch:
		pixels = maxi(pixels, roundi(18.0 / ui_scale))
	var picture_height: float = (50.0 if _batch else 80.0) * unit if _picture.texture != null else 0.0
	var aspect: float = clampf(_picture.texture.get_width() / float(maxi(1, _picture.texture.get_height())), 0.5, 1.8) if _picture.texture != null else 1.0
	var text_size: Vector2 = _measure(pixels)
	var desired := Vector2(padding * 2.0 + picture_height * aspect + gap + text_size.x,
		padding * 2.0 + maxf(picture_height, text_size.y))
	# Only long content or a short landscape region reduces the natural size.
	var fit: float = minf(1.0, minf(max_size.x / desired.x, max_size.y / desired.y))
	padding *= fit
	gap *= fit
	picture_height *= fit
	pixels = maxi(1, floori(pixels * fit))
	text_size = _measure(pixels)
	size = Vector2(padding * 2.0 + picture_height * aspect + gap + text_size.x,
		padding * 2.0 + maxf(picture_height, text_size.y))
	_visual.size = size
	_visual.pivot_offset = size * 0.5
	_surface.size = size
	_level_effects.configure(size, ui_scale, merge_level, _accent, _batch, effect_margin())
	var tier: Color = _level_effects.color_at()
	var skin := Style.box(Style.PAPER.lightened(0.46).lerp(tier.lightened(0.84), 0.035 * merge_level),
		_accent.lightened(0.66) if merge_level == 1 else tier.lightened(0.24),
		maxi(1, roundi(size.y * 0.30)), maxi(1, roundi((1.2 + merge_level * 0.20) / ui_scale)))
	skin.shadow_color = Color(tier.darkened(0.28), 0.16 + merge_level * 0.012)
	skin.shadow_size = maxi(1, roundi(5.0 / ui_scale))
	skin.shadow_offset = Vector2(0.0, 2.0 / ui_scale)
	_surface.add_theme_stylebox_override("panel", skin)
	_picture.size = Vector2(picture_height * aspect, picture_height)
	_picture.position = Vector2(padding, (size.y - picture_height) * 0.5)
	_aura.size = _picture.size * 1.25
	_aura.position = _picture.position - _picture.size * 0.125
	_spelling.add_theme_font_size_override("font_size", pixels)
	_spelling.position = Vector2(padding + _picture.size.x + gap, padding)
	_spelling.size = Vector2(text_size.x, size.y - padding * 2.0)
	for index in range(_glints.size()):
		var edge: float = minf(24.0 * unit, size.y * 0.30) * (1.0 if index == 0 else 0.70)
		var point: Vector2 = [Vector2(size.x * 0.94, size.y * 0.20),
			Vector2(size.x * 0.38, size.y * 0.12), Vector2(size.x * 0.08, size.y * 0.84)][index]
		_glints[index].position = point - Vector2.ONE * edge * 0.5
		_glints[index].size = Vector2.ONE * edge
		_glints[index].pivot_offset = Vector2.ONE * edge * 0.5


func _measure(pixels: int) -> Vector2:
	return Vector2(ceilf(Style.HEADING_FONT.get_string_size(_spelling.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x) + 2.0 / _ui_scale,
		ceilf(Style.HEADING_FONT.get_height(pixels)))


func effect_margin() -> float:
	# Preserve the readable card in short landscape regions as well as portrait.
	return minf(LevelEffects.margin_for(merge_level, _batch, _ui_scale),
		minf(_available.x, _available.y) * 0.20)


func sync() -> void:
	position = rest_position
	_level_effects.sync(elapsed, duration, reduced_motion)
	var fade_start: float = duration - (0.22 if _batch else 0.31)
	var fade: float = smoothstep(fade_start, duration, elapsed)
	_visual.modulate.a = smoothstep(0.0, 0.055, elapsed) * (1.0 - fade)
	_visual.position = Vector2.ZERO
	_visual.scale = Vector2.ONE
	if not reduced_motion:
		# A quick stretched release, a soft compression, then a damped settle.
		var stretch := Vector2.ONE
		if elapsed < 0.10:
			stretch = Vector2(0.46, 0.68).lerp(Vector2(1.17, 1.20),
				1.0 - pow(1.0 - clampf(elapsed / 0.10, 0.0, 1.0), 3.0))
		elif elapsed < 0.21:
			stretch = Vector2(1.17, 1.20).lerp(Vector2(1.05, 0.91), smoothstep(0.10, 0.21, elapsed))
		elif elapsed < 0.33:
			stretch = Vector2(1.05, 0.91).lerp(Vector2(0.98, 1.045), smoothstep(0.21, 0.33, elapsed))
		elif elapsed < 0.47:
			stretch = Vector2(0.98, 1.045).lerp(Vector2.ONE, smoothstep(0.33, 0.47, elapsed))
		_visual.scale = stretch
		_visual.position.y = (4.0 * (1.0 - smoothstep(0.0, 0.16, elapsed)) - fade * 4.0) / _ui_scale
	_aura.visible = not reduced_motion and _picture.texture != null
	_aura.modulate = Color(_accent.lightened(0.50), 0.50 * (1.0 - smoothstep(0.10, 0.48, elapsed)))
	for index in range(_glints.size()):
		var age: float = elapsed - 0.07 - index * 0.075
		var pulse: float = sin(clampf(age / 0.29, 0.0, 1.0) * PI)
		_glints[index].visible = not reduced_motion and pulse > 0.001
		_glints[index].modulate = Color(_accent.lightened(0.60) if merge_level == 1 else _level_effects.color_at(index).lightened(0.35), pulse * 0.95)
		_glints[index].scale = Vector2.ONE * lerpf(0.55, 1.18, pulse)
		_glints[index].rotation = age * 0.40


func snapshot() -> Dictionary:
	return {"entry_id": entry_id, "word_id": str(_word.get("id", "")), "word": _word.duplicate(true),
		"merge_level": merge_level, "effects": _level_effects.snapshot(),
		"picture": WordArt.source_path(_picture.texture), "spelling": _spelling.text, "visible": is_visible_in_tree(),
		"elapsed": elapsed, "duration": duration, "batch": _batch, "variant_scale": variant_scale,
		"animated_scale": [_visual.scale.x, _visual.scale.y], "font_size": _spelling.get_theme_font_size("font_size"),
		"rect": _rect_data(_surface.get_global_rect()), "resting_rect": _rect_data(get_global_rect()),
		"picture_rect": _rect_data(_picture.get_global_rect()), "spelling_rect": _rect_data(_spelling.get_global_rect()),
		"content_alpha": _visual.modulate.a, "reduced_motion": reduced_motion}


func _rect_data(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
