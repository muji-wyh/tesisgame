extends Control
## Illustrated word flights. Recognition, expiry, and damage belong to the model.

const Style = preload("res://scripts/ui_style.gd")
const COLORS := [Color("#7fdfde"), Color("#ffcb7b"), Color("#c2a5ef"), Color("#f4adbf")]
var reduced_motion: bool = false
var accent := Color("#ee9b79")
var targets: Array[Dictionary] = []
var _textures: Dictionary = {}
var _geometry: Array[Dictionary] = []
var _geometry_size := Vector2.ZERO
var _geometry_scale: float = -1.0
var _geometry_reduced: bool = false
var _style_scale: float = -1.0
var _shadow: StyleBoxFlat
var _card_styles: Array[StyleBoxFlat] = []
var _text_size := Vector2.ZERO
var _text_font: Font
var _text_layouts: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)


func present(items: Array) -> void:
	targets.assign(items)
	_update_geometry()
	queue_redraw()


func center_for(uid: int) -> Vector2:
	for item in _geometry:
		if item.uid == uid:
			return item.center
	return size * 0.5


func geometry() -> Array[Dictionary]:
	_update_geometry()
	return _geometry.duplicate(true)


func _update_geometry() -> void:
	_geometry.clear()
	_geometry_size = size
	_geometry_scale = Style.ui_scale(self)
	_geometry_reduced = reduced_motion
	if size.x <= 0 or size.y <= 0:
		return
	var s: float = _geometry_scale
	var edge: float = minf(144 / s, minf((size.x - 24 / s) / 3.1, maxf(1, size.y - 24 / s) * 0.75))
	var card_size := Vector2(edge, edge * 1.05)
	for target in targets:
		var progress: float = clampf(float(target.age) / maxf(0.1, float(target.lifetime)), 0, 1)
		var lane: int = int(target.get("lane", int(target.uid) % 3))
		var x: float = size.x * (0.19 + lane * 0.31)
		x += sin(progress * PI) * float(target.get("spin", 0.0)) * edge * 0.25
		var bottom: float = size.y - card_size.y * 0.5 - 6 / s
		var apex: float = card_size.y * 0.5 + 22 / s
		apex += minf(12 / s, maxf(0, bottom - apex) * 0.3) if lane == 1 else 0.0
		apex = minf(apex, bottom)
		var y: float = lerpf(bottom, apex, 4 * progress * (1 - progress))
		if reduced_motion:
			y = size.y * 0.5
		var center := Vector2(clampf(x, edge * 0.55, size.x - edge * 0.55), y)
		_geometry.append({"uid": int(target.uid), "word": target.word, "center": center,
			"size": card_size, "rotation": 0.0 if reduced_motion else float(target.get("spin", 0.0)) * sin(progress * PI) * 0.45,
			"progress": progress, "remaining_ms": maxi(0, int((target.lifetime - target.age) * 1000)),
			"forms": target.get("forms", [])})


func _draw() -> void:
	var s: float = Style.ui_scale(self)
	var night: Color = Color("#203139").lerp(accent.darkened(0.72), 0.18)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
		PackedColorArray([night.lightened(0.04), night.lightened(0.04), night.darkened(0.12), night.darkened(0.12)]))
	draw_line(Vector2.ZERO, Vector2(size.x, 0), Color("#d9bb8260"), maxf(1, 1 / s))
	# present() already prepared this frame's flight positions for projectiles.
	# A resize or motion preference change can still arrive before drawing.
	if _geometry_size != size or _geometry_scale != s or _geometry_reduced != reduced_motion:
		_update_geometry()
	_prepare_styles(s)
	for item in _geometry:
		_draw_card(item, s)


func _prepare_styles(s: float) -> void:
	if _style_scale == s:
		return
	_style_scale = s
	_shadow = Style.box(Color("#30405b20"), Color.TRANSPARENT, ceili(18 / s), 0)
	_card_styles.clear()
	for color: Color in COLORS:
		_card_styles.append(Style.box(color, color.lightened(0.6), ceili(18 / s), maxi(1, ceili(2 / s))))
	_text_layouts.clear()


func _word_layout(text: String, dimensions: Vector2, s: float, compact: bool) -> Vector2:
	var font := ThemeDB.fallback_font
	if _text_size != dimensions or _text_font != font:
		_text_size = dimensions
		_text_font = font
		_text_layouts.clear()
	if not _text_layouts.has(text):
		var font_size: int = ceili(clampf(dimensions.x * s * 0.18, 12 if compact else 15, 24) / s)
		var text_margin: float = minf(12 / s, dimensions.x * 0.14)
		while font_size > ceili((10 if compact else 11) / s) and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > dimensions.x - text_margin:
			font_size -= 1
		_text_layouts[text] = Vector2(font_size, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return _text_layouts[text]


func _draw_card(item: Dictionary, s: float) -> void:
	var rect := Rect2(-item.size * 0.5, item.size)
	var color_index: int = (int(item.uid) - 1) % COLORS.size()
	draw_set_transform(item.center, item.rotation)
	draw_style_box(_shadow, Rect2(rect.position + Vector2(0, 5 / s), rect.size))
	draw_style_box(_card_styles[color_index], rect)
	var compact: bool = item.size.x * s < 80
	var art_edge: float = item.size.x * (0.50 if compact else 0.60)
	var art_center := Vector2(0, -item.size.y * (0.20 if compact else 0.13))
	draw_circle(art_center, art_edge * 0.54, Color("#fffaf0"))
	var path: String = str(item.word.get("image", ""))
	if not path.is_empty() and not path.begins_with("res://"):
		path = "res://" + path
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	var texture: Texture2D = _textures[path]
	if texture != null:
		var art_size: Vector2 = texture.get_size()
		art_size *= art_edge / maxf(1, maxf(art_size.x, art_size.y))
		draw_texture_rect(texture, Rect2(art_center - art_size * 0.5, art_size), false)
	var font := ThemeDB.fallback_font
	var text: String = str(item.word.text)
	var text_layout: Vector2 = _word_layout(text, item.size, s, compact)
	draw_string(font, Vector2(-text_layout.y * 0.5, rect.end.y - (10 if compact else 13) / s), text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(text_layout.x), Color("#293a55"))
	var track_margin: float = minf(13 / s, item.size.x * 0.15)
	var track := Rect2(Vector2(rect.position.x + track_margin, rect.end.y - 5 / s), Vector2(item.size.x - track_margin * 2, 2 / s))
	draw_rect(track, Color("#ffffff70"))
	track.size.x *= 1.0 - float(item.progress)
	draw_rect(track, Color("#34445a70"))
	draw_set_transform(Vector2.ZERO)
