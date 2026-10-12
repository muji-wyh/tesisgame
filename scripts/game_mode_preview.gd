extends Control
## Decorative demonstrations. Input and gameplay state belong to the parent card.

const Style = preload("res://scripts/ui_style.gd")
const Slice = preload("res://scripts/voice_pop_slice.gd")
const CAT = preload("res://assets/images/ui/modes/cat.webp")
const APPLE = preload("res://assets/images/ui/modes/apple.webp")
const MIC = preload("res://assets/images/ui/modes/microphone.webp")
const MINT = preload("res://assets/images/jelly-match/gel-mint.png")
const LILAC = preload("res://assets/images/jelly-match/gel-lilac.png")
const COIN = preload("res://assets/coins/gold-coin.png")
const DESIGN_SIZE := Vector2(220, 112)
const DURATION := 3.2
const PURPLE := Color("#80719c")

var mode := "match"
var reduced_motion := true
var highlighted := false
var _elapsed := DURATION


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	resized.connect(queue_redraw)
	visibility_changed.connect(_sync_activity)
	set_process(false)


func configure(id: String) -> void:
	mode = id
	name = "Preview_" + mode
	queue_redraw()


func set_reduced_motion(value: bool) -> void:
	if reduced_motion == value:
		return
	reduced_motion = value
	if value:
		_elapsed = DURATION
	_sync_activity()
	queue_redraw()


func set_highlighted(value: bool) -> void:
	if highlighted == value:
		return
	highlighted = value
	_elapsed = 0.0 if value and not reduced_motion else DURATION
	_sync_activity()
	queue_redraw()


func _sync_activity() -> void:
	if not is_visible_in_tree():
		_elapsed = DURATION
	set_process(is_visible_in_tree() and highlighted and not reduced_motion and _elapsed < DURATION)


func finish_demo() -> void:
	_elapsed = DURATION
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed = minf(DURATION, _elapsed + delta)
	queue_redraw()
	if _elapsed >= DURATION:
		set_process(false)


func _draw() -> void:
	var factor: float = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	if factor <= 0.0:
		return
	draw_set_transform((size - DESIGN_SIZE * factor) * 0.5, 0, Vector2.ONE * factor)
	var moving: bool = highlighted and not reduced_motion and _elapsed < DURATION
	match mode:
		"match": _draw_match(moving)
		"memory": _draw_memory(moving)
		"pop": _draw_pop(moving)
		"phrase": _draw_phrase(moving)
		"jelly": _draw_jelly_match(moving)
		"word_jelly": _draw_jelly_words(moving)


func _card(rect: Rect2, fill := Color("#fffdf6"), edge := Color("#bacbbb")) -> void:
	var shadow := Style.box(Color(0.16, 0.24, 0.20, 0.10), Color.TRANSPARENT, 12, 0)
	draw_style_box(shadow, Rect2(rect.position + Vector2(0, 4), rect.size))
	draw_style_box(Style.box(fill, edge, 12, 2), rect)


func _text(value: String, center: Vector2, font_size: int, color := Style.INK) -> void:
	var font: Font = Style.HEADING_FONT
	var width: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center + Vector2(-width * 0.5, (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5),
		value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _art(texture: Texture2D, rect: Rect2, alpha: float = 1.0) -> void:
	draw_texture_rect(texture, rect, false, Color(1, 1, 1, alpha))


func _arrow(from: Vector2, to: Vector2, color := Style.GOOD) -> void:
	draw_line(from, to, color, 3, true)
	var direction: Vector2 = (to - from).normalized()
	var side := Vector2(-direction.y, direction.x)
	draw_polyline(PackedVector2Array([to - direction * 7 + side * 5, to, to - direction * 7 - side * 5]), color, 3, true)


func _draw_match(moving: bool) -> void:
	var linked: float = smoothstep(0.6, 1.1, _elapsed) if moving else 1.0
	var lift: float = sin(clampf(_elapsed / 0.65, 0, 1) * PI) * 6 if moving else 0.0
	var edge: Color = Color("#bacbbb").lerp(Style.GOOD, linked)
	_card(Rect2(14, 18 - lift, 80, 80), Color("#fffdf6"), edge)
	_art(CAT, Rect2(22, 22 - lift, 64, 64))
	_card(Rect2(126, 18, 80, 80), Color("#fffdf6"), edge)
	_text("cat", Vector2(166, 59), 32)
	draw_line(Vector2(94, 58), Vector2(126, 58), Color(Style.GOOD, linked), 3, true)
	if linked > 0.5:
		Style.draw_match_badge(self, Vector2(110, 58), 12)


func _draw_memory(moving: bool) -> void:
	_card(Rect2(9, 28, 55, 70), Color("#e3ddeb"), PURPLE)
	_text("Aa", Vector2(36.5, 63), 27, PURPLE)
	_card(Rect2(76, 24, 60, 74))
	_art(CAT, Rect2(80, 30, 52, 52))
	var progress: float = smoothstep(0.4, 1.1, _elapsed) if moving else 1.0
	var width: float = maxf(2, absf(cos(progress * PI)) * 60)
	var rect := Rect2(178 - width * 0.5, 24, width, 74)
	_card(rect, Color("#fffdf6") if progress > 0.5 else Color("#e3ddeb"), PURPLE)
	if width > 34:
		_text("cat" if progress > 0.5 else "Aa", rect.get_center(), 25, Style.INK if progress > 0.5 else PURPLE)
	draw_arc(Vector2(176, 26), 20, PI * 1.10, PI * 1.94, 18, PURPLE, 3, true)
	_arrow(Vector2(195, 18), Vector2(196, 27), PURPLE)


func _shift(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in points:
		result.append(point + offset)
	return result


func _draw_pop(moving: bool) -> void:
	_art(MIC, Rect2(4, 44, 53, 53))
	_card(Rect2(8, 4, 86, 34), Color("#fffdf6"), Color("#8ab9bd"))
	_text("apple", Vector2(51, 21), 23)
	for index in range(3):
		var height: float = 10 + index * 6
		if moving:
			height *= 0.65 + 0.35 * sin(_elapsed * 9 + index)
		draw_line(Vector2(66 + index * 10, 64 - height * 0.5), Vector2(66 + index * 10, 64 + height * 0.5), Color("#45888d"), 4, true)
	var split: float = smoothstep(0.65, 1.15, _elapsed) if moving else 0.8
	var origin := Vector2(160, 55)
	var normal := Vector2(0.25, 1).normalized()
	var art_rect := Rect2(-27, -40, 54, 54)
	var art_points := PackedVector2Array([art_rect.position, Vector2(art_rect.end.x, art_rect.position.y), art_rect.end, Vector2(art_rect.position.x, art_rect.end.y)])
	for side: float in [-1.0, 1.0]:
		var offset: Vector2 = origin + normal * side * split * 6
		var face: PackedVector2Array = Slice.clip_half(Slice.rounded_rect(Vector2(76, 91), 12), Vector2(0, -4), normal, side)
		draw_colored_polygon(_shift(face, offset + Vector2(0, 3)), Color(0.15, 0.30, 0.32, 0.12))
		draw_colored_polygon(_shift(face, offset), Color("#c5ebee"))
		var art: PackedVector2Array = Slice.clip_half(art_points, Vector2(0, -4), normal, side)
		if art.size() >= 3:
			draw_polygon(_shift(art, offset), PackedColorArray([Color.WHITE]), Slice.texture_uv(art, art_rect), APPLE)
		if side > 0:
			_text("apple", offset + Vector2(0, 28), 23)
	if split > 0.2:
		_arrow(Vector2(114, 63), Vector2(208, 39), Color("#fffdf6"))


func _draw_phrase(moving: bool) -> void:
	_art(CAT, Rect2(15, 2, 49, 49))
	for index in range(5):
		var height: float = [12, 23, 34, 23, 12][index]
		draw_line(Vector2(77 + index * 9, 28 - height * 0.5), Vector2(77 + index * 9, 28 + height * 0.5), Color("#b3954f"), 4, true)
	_card(Rect2(9, 65, 48, 36), Color("#e1edf9"))
	_card(Rect2(63, 65, 77, 36), Color("#f8e4cc"))
	_text("the", Vector2(33, 83), 23)
	_text("little", Vector2(101.5, 83), 23)
	draw_style_box(Style.box(Color(1, 1, 1, 0.2), Color("#c4b58e"), 10, 2), Rect2(146, 65, 65, 36))
	var progress: float = smoothstep(0.4, 1.25, _elapsed) if moving else 0.2
	var y: float = lerpf(10, 65, progress)
	_card(Rect2(146, y, 65, 36), Color("#ebe3f7"), PURPLE)
	_text("cat", Vector2(178.5, y + 18), 24)
	if progress < 0.65:
		_arrow(Vector2(178, y + 41), Vector2(178, 80), PURPLE)


func _gel(rect: Rect2, skin: Texture2D, word: String = "", picture: Texture2D = null) -> void:
	_art(skin, rect)
	if picture != null:
		var side: float = minf(rect.size.x * 0.54, rect.size.y * (0.40 if not word.is_empty() else 0.60))
		var center: Vector2 = rect.get_center() - Vector2(0, rect.size.y * (0.12 if not word.is_empty() else 0.0))
		_art(picture, Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side))
	if not word.is_empty():
		_text(word, rect.get_center() + Vector2(0, rect.size.y * (0.20 if picture != null else 0.02)), 23 if picture != null else 29)


func _draw_jelly_match(moving: bool) -> void:
	var join: float = smoothstep(0.3, 1.0, _elapsed) if moving else 0.0
	if not moving or _elapsed < 1.35:
		_gel(Rect2(13 + join * 26, 20, 91, 83), MINT, "", CAT)
		_gel(Rect2(116 - join * 26, 20, 91, 83), MINT, "cat")
		if join < 0.5:
			_arrow(Vector2(91, 58), Vector2(127, 58))
	elif _elapsed < 2.05:
		var settle: float = 1.0 + sin((_elapsed - 1.35) / 0.7 * PI) * 0.08
		var dimensions := Vector2(129, 84) * settle
		_gel(Rect2(Vector2(110, 62) - dimensions * 0.5, dimensions), MINT, "cat", CAT)
	else:
		Style.draw_match_badge(self, Vector2(110, 62), 24)


func _draw_jelly_words(moving: bool) -> void:
	var join: float = smoothstep(0.3, 1.0, _elapsed) if moving else 0.0
	_gel(Rect2(0 + join * 8, 33, 65, 66), LILAC, "ca")
	_gel(Rect2(54 - join * 4, 33, 55, 66), LILAC, "t")
	_arrow(Vector2(110, 64), Vector2(133, 64), PURPLE)
	var grow: float = 1.0 + (sin(clampf((_elapsed - 0.9) / 0.6, 0, 1) * PI) * 0.10 if moving else 0.0)
	var dimensions := Vector2(87, 99) * grow
	_gel(Rect2(Vector2(174, 59) - dimensions * 0.5, dimensions), LILAC, "cat", CAT)
	_art(COIN, Rect2(185, 0, 27, 27))
