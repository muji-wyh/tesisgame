extends Control
## A manually advanced reading beat for a word the player has already collected.

const Style = preload("res://scripts/ui_style.gd")
const WordArt = preload("res://scripts/word_art.gd")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const GLINT = preload("res://assets/chests/milestone/sparkle.png")
const SECONDS: float = 1.95
const PEAK_SECONDS: float = 0.18

var _word: Dictionary = {}
var _elapsed: float = 0.0
var _reduced_motion: bool = false
var _ui_scale: float = 1.0
var _accent: Color = Style.GOOD
var _rest := Rect2()
var _visual: Control
var _surface: Panel
var _aura: TextureRect
var _picture: TextureRect
var _spelling: Label
var _glints: Array[TextureRect] = []


func _init() -> void:
	name = "WordJellyWordReveal"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 55
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
	_spelling.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_visual.add_child(_spelling)
	for index in range(3):
		var glint := _texture(GLINT)
		glint.name = "WordGlint%d" % index
		_glints.append(glint)
	hide()


func _texture(value: Texture2D) -> TextureRect:
	var result := TextureRect.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.texture = value
	_visual.add_child(result)
	return result


func configure_layout(available: Rect2, ui_scale: float) -> void:
	position = available.position
	size = available.size.max(Vector2.ZERO)
	_ui_scale = maxf(0.5, ui_scale)
	_layout()
	_sync()


func present(word: Dictionary, picture: Texture2D, accent: Color) -> void:
	if str(word.get("text", "")).strip_edges().is_empty() or picture == null:
		reset()
		return
	_word = word.duplicate(true)
	_elapsed = 0.0
	_accent = accent
	_picture.texture = picture
	WordArt.bind(picture, _picture)
	_spelling.text = str(word.text)
	set("accessibility_name", str(word.text))
	_layout()
	show()
	_sync()


func advance(delta: float) -> void:
	if _word.is_empty() or not is_finite(delta) or delta <= 0.0:
		return
	_elapsed = minf(SECONDS, _elapsed + delta)
	if _elapsed >= SECONDS:
		reset()
		return
	_sync()


func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	_sync()


func reset() -> void:
	_word.clear()
	_elapsed = 0.0
	_picture.texture = null
	_spelling.text = ""
	_visual.modulate.a = 0.0
	hide()


func _layout() -> void:
	var padding: float = minf(10.0 / _ui_scale, size.y * 0.10)
	var width: float = maxf(0.0, minf(400.0 / _ui_scale, size.x - padding * 2.0))
	var height: float = maxf(0.0, minf(132.0 / _ui_scale, size.y - padding * 2.0))
	_rest = Rect2(Vector2((size.x - width) * 0.5, padding), Vector2(width, height))
	_visual.size = _rest.size
	_visual.pivot_offset = _rest.size * 0.5
	_surface.position = Vector2.ZERO
	_surface.size = _rest.size
	var skin := Style.box(Style.PAPER.lightened(0.4), _accent.lightened(0.50),
		maxi(1, roundi(minf(24.0 / _ui_scale, height * 0.24))), maxi(1, roundi(2.0 / _ui_scale)))
	skin.shadow_color = Color(_accent.darkened(0.65), 0.18)
	skin.shadow_size = maxi(1, roundi(9.0 / _ui_scale))
	skin.shadow_offset = Vector2(0.0, 4.0 / _ui_scale)
	_surface.add_theme_stylebox_override("panel", skin)
	var inset: float = minf(14.0 / _ui_scale, height * 0.12)
	var picture_edge: float = minf(height - inset * 2.0, width * 0.31)
	_picture.position = Vector2(inset, (height - picture_edge) * 0.5)
	_picture.size = Vector2.ONE * picture_edge
	_aura.position = _picture.position - Vector2.ONE * picture_edge * 0.16
	_aura.size = Vector2.ONE * picture_edge * 1.32
	var spelling_x: float = _picture.position.x + picture_edge + inset
	_spelling.position = Vector2(spelling_x, inset)
	_spelling.size = Vector2(maxf(0.0, width - spelling_x - inset * 1.5), height - inset * 2.0)
	var pixels: int = maxi(1, roundi(minf(34.0 / _ui_scale, height * 0.40)))
	var minimum: int = maxi(1, roundi(14.0 / _ui_scale))
	while pixels > minimum and Style.HEADING_FONT.get_string_size(_spelling.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > _spelling.size.x:
		pixels -= 1
	_spelling.add_theme_font_size_override("font_size", pixels)
	for index in range(_glints.size()):
		var edge: float = minf(27.0 / _ui_scale, height * 0.28) * (1.0 if index == 0 else 0.72)
		var point: Vector2 = [Vector2(width * 0.95, height * 0.15),
			Vector2(width * 0.35, height * 0.16), Vector2(width * 0.07, height * 0.87)][index]
		_glints[index].position = point - Vector2.ONE * edge * 0.5
		_glints[index].size = Vector2.ONE * edge
		_glints[index].pivot_offset = Vector2.ONE * edge * 0.5


func _sync() -> void:
	if _visual == null:
		return
	var alpha: float = smoothstep(0.0, 0.10, _elapsed) * (1.0 - smoothstep(1.64, SECONDS, _elapsed))
	_visual.modulate.a = alpha if not _word.is_empty() else 0.0
	_visual.position = _rest.position
	_visual.scale = Vector2.ONE
	_aura.visible = not _reduced_motion and not _word.is_empty()
	_aura.modulate = Color(_accent.lightened(0.42), 0.32 * (1.0 - smoothstep(0.25, 0.85, _elapsed)))
	if not _reduced_motion:
		var stretch: float = lerpf(0.78, 1.045, 1.0 - pow(1.0 - clampf(_elapsed / PEAK_SECONDS, 0.0, 1.0), 3.0))
		if _elapsed >= PEAK_SECONDS:
			stretch = lerpf(1.045, 1.0, smoothstep(PEAK_SECONDS, 0.34, _elapsed))
		_visual.scale = Vector2.ONE * stretch
		_visual.position.y += 8.0 / _ui_scale * (1.0 - smoothstep(0.0, PEAK_SECONDS, _elapsed))
	for index in range(_glints.size()):
		var age: float = _elapsed - PEAK_SECONDS - index * 0.105
		var pulse: float = sin(clampf(age / 0.36, 0.0, 1.0) * PI)
		_glints[index].visible = not _reduced_motion and not _word.is_empty() and pulse > 0.001
		_glints[index].modulate = Color(_accent.lightened(0.58), pulse * 0.95)
		_glints[index].scale = Vector2.ONE * lerpf(0.58, 1.12, pulse)
		_glints[index].rotation = age * 0.35


func snapshot() -> Dictionary:
	return {"word_id": str(_word.get("id", "")), "word": _word.duplicate(true),
		"picture": WordArt.source_path(_picture.texture), "spelling": _spelling.text,
		"visible": visible and not _word.is_empty(), "elapsed": _elapsed, "duration": SECONDS,
		"rect": _rect_data(_surface.get_global_rect()), "resting_rect": _rect_data(get_global_transform() * _rest),
		"picture_rect": _rect_data(_picture.get_global_rect()), "spelling_rect": _rect_data(_spelling.get_global_rect()),
		"content_alpha": _visual.modulate.a, "reduced_motion": _reduced_motion}


func _rect_data(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
