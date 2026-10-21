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
const CHEST = preload("res://assets/chests/royal/closed.png")
const CHEST_BODY = preload("res://assets/chests/rigs/royal/body.png")
const CHEST_INTERIOR = preload("res://assets/chests/rigs/royal/interior.png")
const CHEST_LID = preload("res://assets/chests/rigs/royal/lid_outer.png")
const CHEST_INNER_LID = preload("res://assets/chests/rigs/royal/lid_inner.png")
const CHEST_LATCH = preload("res://assets/chests/rigs/royal/latch.png")
const GLOW = preload("res://assets/chests/particles/portal_glow.png")
const SPARKLE = preload("res://assets/chests/milestone/sparkle.png")
const DESIGN_SIZE := Vector2(220, 112)
const DURATION := 5.8
const PHASE_OFFSETS := {"match": 0.0, "memory": 0.85, "pop": 1.7, "phrase": 2.55, "jelly": 3.4, "word_jelly": 4.25}
const PURPLE := Color("#80719c")

var mode := "match"
var reduced_motion := true
var highlighted := false
var _elapsed := 0.0
var _paused := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	resized.connect(queue_redraw)
	visibility_changed.connect(_visibility_changed)
	set_process(false)


func configure(id: String) -> void:
	mode = id
	name = "Preview_" + mode
	_elapsed = float(PHASE_OFFSETS.get(mode, 0.0))
	_sync_activity()
	queue_redraw()


func _ready() -> void:
	# Entering the tree enables scripted processing after construction. A
	# preview can enter beneath an already-hidden parent with motion disabled.
	_sync_activity()


func set_reduced_motion(value: bool) -> void:
	if reduced_motion == value:
		return
	reduced_motion = value
	_sync_activity()
	queue_redraw()


func set_highlighted(value: bool) -> void:
	if highlighted == value:
		return
	highlighted = value
	queue_redraw()


func _visibility_changed() -> void:
	if is_visible_in_tree():
		_paused = false
	_sync_activity()


func _sync_activity() -> void:
	set_process(is_visible_in_tree() and not _paused and not reduced_motion)
	_update_opacity()


func finish_demo() -> void:
	_paused = true
	set_process(false)
	queue_redraw()


func resume_demo() -> void:
	_paused = false
	_sync_activity()
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed = fposmod(_elapsed + delta, DURATION)
	_update_opacity()
	queue_redraw()


func _update_opacity() -> void:
	# A brief dissolve resets the example after its readable outcome hold.
	self_modulate.a = 1.0 if reduced_motion else smoothstep(0.0, 0.22, _elapsed) * (1.0 - smoothstep(5.35, DURATION, _elapsed))


func _draw() -> void:
	var factor: float = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	if factor <= 0.0:
		return
	draw_set_transform((size - DESIGN_SIZE * factor) * 0.5, 0, Vector2.ONE * factor)
	var moving: bool = not reduced_motion
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


func _hop(start: float, duration: float, height: float) -> float:
	return sin(clampf((_elapsed - start) / duration, 0.0, 1.0) * PI) * height


func _recoil(start: float) -> float:
	var time: float = maxf(0.0, _elapsed - start)
	return sin(time * 18.0) * exp(-time * 5.5)


func _tap(center: Vector2, start: float, color: Color) -> void:
	var time: float = (_elapsed - start) / 0.55
	if time < 0.0 or time > 1.0:
		return
	draw_arc(center, 5.0 + time * 12.0, 0, TAU, 24, Color(color, (1.0 - time) * 0.7), 2.5, true)


func _draw_match(moving: bool) -> void:
	var selected: float = smoothstep(0.55, 0.8, _elapsed) if moving else 1.0
	var linked: float = smoothstep(1.45, 1.75, _elapsed) if moving else 1.0
	var lift: float = _hop(0.55, 0.5, 7.0) if moving else 0.0
	var word_lift: float = _hop(1.4, 0.5, 7.0) if moving else 0.0
	_card(Rect2(14, 18 - lift, 80, 80), Color("#fffdf6"), Color("#bacbbb").lerp(Style.GOOD, selected))
	_art(CAT, Rect2(22, 22 - lift, 64, 64))
	_card(Rect2(126, 18 - word_lift, 80, 80), Color("#fffdf6"), Color("#bacbbb").lerp(Style.GOOD, linked))
	_text("cat", Vector2(166, 59 - word_lift), 32)
	if moving:
		_tap(Vector2(69, 84), 0.55, Style.GOOD)
		_tap(Vector2(186, 84), 1.4, Style.GOOD)
	if linked > 0.0:
		draw_line(Vector2(94, 58), Vector2(94 + 32 * linked, 58), Color(Style.GOOD, linked), 3, true)
	if linked > 0.8:
		var radius: float = 12.0 * (1.0 + (_recoil(1.75) * 0.18 if moving else 0.0))
		Style.draw_match_badge(self, Vector2(110, 58), radius)


func _draw_memory(moving: bool) -> void:
	_card(Rect2(9, 28, 55, 70), Color("#e3ddeb"), PURPLE)
	_text("Aa", Vector2(36.5, 63), 27, PURPLE)
	var first: float = smoothstep(0.65, 1.25, _elapsed) if moving else 1.0
	var second: float = smoothstep(1.6, 2.2, _elapsed) if moving else 1.0
	var lift: float = _hop(2.25, 0.55, 5.0) if moving else 0.0
	var edge: Color = Style.GOOD if second >= 1.0 else PURPLE
	_flip_card(Vector2(106, 60 - lift), first, true, edge)
	_flip_card(Vector2(178, 60 - lift), second, false, edge)
	if moving:
		_tap(Vector2(121, 86), 0.65, PURPLE)
		_tap(Vector2(194, 86), 1.6, PURPLE)
	if second >= 1.0:
		Style.draw_match_badge(self, Vector2(142, 21), 11)


func _flip_card(center: Vector2, progress: float, picture: bool, edge: Color) -> void:
	var width: float = maxf(2, absf(cos(progress * PI)) * 60)
	var face: bool = progress > 0.5
	var rect := Rect2(center - Vector2(width, 74) * 0.5, Vector2(width, 74))
	_card(rect, Color("#fffdf6") if face else Color("#e3ddeb"), edge)
	if face and picture:
		_art(CAT, Rect2(center - Vector2(width * 0.44, 28), Vector2(width * 0.88, 52)))
	elif width > 32:
		_text("cat" if face else "Aa", center, mini(25, int(width * 0.48)), Style.INK if face else PURPLE)


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
			var speaking: float = smoothstep(0.5, 0.8, _elapsed) * (1.0 - smoothstep(1.8, 2.25, _elapsed))
			height *= lerpf(0.4, 0.8 + 0.4 * sin(_elapsed * 12 + index * 1.5), speaking)
		draw_line(Vector2(66 + index * 10, 64 - height * 0.5), Vector2(66 + index * 10, 64 + height * 0.5), Color("#45888d"), 4, true)
	var split: float = smoothstep(1.9, 2.55, _elapsed) if moving else 0.8
	var flight: float = smoothstep(0.2, 0.85, _elapsed) if moving else 1.0
	var depart: float = smoothstep(2.45, 3.25, _elapsed) if moving else 0.0
	var origin := Vector2(160, 55 + (1.0 - flight) * 85 + depart * 38)
	var normal := Vector2(0.25, 1).normalized()
	var art_rect := Rect2(-27, -40, 54, 54)
	var art_points := PackedVector2Array([art_rect.position, Vector2(art_rect.end.x, art_rect.position.y), art_rect.end, Vector2(art_rect.position.x, art_rect.end.y)])
	for side: float in [-1.0, 1.0]:
		var offset: Vector2 = origin + normal * side * split * (6 + depart * 15)
		var opacity: float = 1.0 - depart
		var face: PackedVector2Array = Slice.clip_half(Slice.rounded_rect(Vector2(76, 91), 12), Vector2(0, -4), normal, side)
		draw_colored_polygon(_shift(face, offset + Vector2(0, 3)), Color(0.15, 0.30, 0.32, 0.12 * opacity))
		draw_colored_polygon(_shift(face, offset), Color(Color("#c5ebee"), opacity))
		var art: PackedVector2Array = Slice.clip_half(art_points, Vector2(0, -4), normal, side)
		if art.size() >= 3:
			draw_polygon(_shift(art, offset), PackedColorArray([Color(1, 1, 1, opacity)]), Slice.texture_uv(art, art_rect), APPLE)
		if side > 0:
			_text("apple", offset + Vector2(0, 28), 23, Color(Style.INK, opacity))
	if split > 0.2 and depart < 0.95:
		_arrow(Vector2(114, 63), Vector2(208, 39), Color(Color("#fffdf6"), 1.0 - depart))
	if moving and depart > 0.65:
		Style.draw_match_badge(self, Vector2(160, 55), 22 * smoothstep(0.65, 1.0, depart))


func _draw_phrase(moving: bool) -> void:
	_art(CAT, Rect2(15, 2, 49, 49))
	for index in range(5):
		var height: float = [12, 23, 34, 23, 12][index]
		if moving:
			var listening: float = 1.0 - smoothstep(1.1, 1.4, _elapsed)
			height *= lerpf(0.6, 0.7 + 0.3 * sin(_elapsed * 11 + index), listening)
		draw_line(Vector2(77 + index * 9, 28 - height * 0.5), Vector2(77 + index * 9, 28 + height * 0.5), Color("#b3954f"), 4, true)
	_card(Rect2(9, 65, 48, 36), Color("#e1edf9"))
	_card(Rect2(63, 65, 77, 36), Color("#f8e4cc"))
	_text("the", Vector2(33, 83), 23)
	_text("little", Vector2(101.5, 83), 23)
	draw_style_box(Style.box(Color(1, 1, 1, 0.2), Color("#c4b58e"), 10, 2), Rect2(146, 65, 65, 36))
	var progress: float = smoothstep(1.3, 2.35, _elapsed) if moving else 0.2
	var y: float = lerpf(10, 65, progress) - (_recoil(2.35) * 6.0 if moving else 0.0)
	var x: float = 146 - sin(progress * PI) * 10
	_card(Rect2(x, y, 65, 36), Color("#ebe3f7"), Style.GOOD if progress >= 1.0 else PURPLE)
	_text("cat", Vector2(x + 32.5, y + 18), 24)
	if progress < 0.65:
		_arrow(Vector2(178, y + 41), Vector2(178, 80), PURPLE)
	if moving:
		_tap(Vector2(193, 32), 1.2, PURPLE)
		if progress >= 1.0:
			Style.draw_match_badge(self, Vector2(176, 30), 13)


func _gel(rect: Rect2, skin: Texture2D, word: String = "", picture: Texture2D = null, opacity: float = 1.0, content_opacity: float = 1.0) -> void:
	_art(skin, rect, opacity)
	if picture != null:
		var side: float = minf(rect.size.x * 0.54, rect.size.y * (0.40 if not word.is_empty() else 0.60))
		var center: Vector2 = rect.get_center() - Vector2(0, rect.size.y * (0.12 if not word.is_empty() else 0.0))
		_art(picture, Rect2(center - Vector2.ONE * side * 0.5, Vector2.ONE * side), opacity * content_opacity)
	if not word.is_empty():
		_text(word, rect.get_center() + Vector2(0, rect.size.y * (0.20 if picture != null else 0.02)), 23 if picture != null else 29, Color(Style.INK, opacity * content_opacity))


func _draw_jelly_match(moving: bool) -> void:
	if moving:
		_draw_merge_demo()
	else:
		_gel(Rect2(13, 20, 91, 83), MINT, "", CAT)
		_gel(Rect2(116, 20, 91, 83), MINT, "cat")
		_arrow(Vector2(91, 58), Vector2(127, 58))


func _draw_jelly_words(moving: bool) -> void:
	# A whole-word root first meets its picture; collection follows the merge.
	var arrival: float = smoothstep(0.2, 0.5, _elapsed) if moving else 1.0
	var approach: float = smoothstep(0.8, 1.4, _elapsed) if moving else 1.0
	var fusion: float = smoothstep(1.4, 1.7, _elapsed) if moving else 1.0
	var collect: float = smoothstep(2.55, 2.9, _elapsed) if moving else 0.0
	var opening: float = smoothstep(3.25, 3.85, _elapsed) if moving else 1.0
	var center := Vector2(56, 66 - 12 * (1.0 - arrival))
	if fusion < 1.0:
		var separation: float = lerpf(29.0, 8.0, approach) * (1.0 - fusion)
		var opacity: float = arrival * (1.0 - fusion)
		_gel(Rect2(center - Vector2(separation + 28, 28), Vector2(56, 56)), LILAC, "cat", null, opacity)
		_gel(Rect2(center + Vector2(separation - 28, -28), Vector2(56, 56)), LILAC, "", CAT, opacity)
	if fusion > 0.0:
		var recoil: float = _recoil(1.7) if moving else 0.0
		var press: float = _hop(2.35, 0.35, 0.12) if moving else 0.0
		var dimensions := Vector2(56, 56) * Vector2(1.0 + recoil * 0.12 + press, 1.0 - recoil * 0.10 - press)
		_art(GLOW, Rect2(center - Vector2(43, 43), Vector2(86, 86)), fusion * (1.0 - collect) * 0.55)
		_gel(Rect2(center - dimensions * 0.5 - Vector2(0, collect * 10), dimensions), LILAC, "", null, fusion * (1.0 - collect))
		var content_alpha: float = fusion
		var picture_side: float = lerpf(25, 44, collect)
		var picture_center: Vector2 = center - Vector2(0, 8 + collect * 8)
		_art(CAT, Rect2(picture_center - Vector2.ONE * picture_side * 0.5, Vector2.ONE * picture_side), content_alpha)
		_text("cat", center + Vector2(0, 15), roundi(lerpf(18, 25, collect)), Color(Style.INK, content_alpha))
	if moving:
		_tap(Vector2(80, 85), 2.35, PURPLE)
	# The same acquired Royal layers and hinge as the full-size chest, without
	# creating a reward system or a 3D viewport for a decorative Home card.
	var anticipation: float = _hop(3.0, 0.25, 1.5) if moving else 0.0
	var chest_center := Vector2(164, 103 - anticipation)
	var chest_scale: float = lerpf(0.108, 0.121, opening)
	var mouth := Vector2(164, 60)
	if opening > 0.0:
		var glow_size := Vector2(114, 102)
		draw_texture_rect(GLOW, Rect2(Vector2(162, 56) - glow_size * 0.5, glow_size), false, Color(1.0, 0.78, 0.34, opening * 0.55))
	_draw_preview_chest(chest_center, chest_scale, opening)
	if moving and _elapsed < 3.15:
		var flight: float = smoothstep(2.6, 3.12, _elapsed)
		var origin := Vector2(84, 42)
		var point: Vector2 = origin.lerp(mouth, flight) - Vector2(0, sin(flight * PI) * 29)
		var alpha: float = (1.0 - smoothstep(0.88, 1.0, flight)) * smoothstep(1.4, 1.6, _elapsed)
		var fragment_size := Vector2(21, 16) * (1.0 + sin(flight * PI) * 0.20)
		draw_texture_rect_region(CHEST, Rect2(point - fragment_size * 0.5, fragment_size), Rect2(39, 309, 798, 596), Color(1, 1, 1, alpha))
		if flight > 0.0:
			_art(SPARKLE, Rect2(point - Vector2(16, 5), Vector2(11, 11)), alpha * 0.8)
	if opening > 0.55:
		for index in range(3):
			var flight: float = smoothstep(3.65 + index * 0.12, 4.35 + index * 0.12, _elapsed) if moving else 1.0
			var destination := Vector2(130 + index * 34, 26 - (14 if index == 1 else 0))
			var point: Vector2 = mouth.lerp(destination, flight) - Vector2(0, sin(flight * PI) * 17)
			var coin_size: float = (20 if index != 1 else 24) * smoothstep(0.0, 0.25, flight)
			_art(COIN, Rect2(point - Vector2.ONE * coin_size * 0.5, Vector2.ONE * coin_size))
		for index in range(3):
			var pulse: float = 0.75 + 0.25 * sin(_elapsed * 5 + index * 2) if moving else 1.0
			var point: Vector2 = [Vector2(111, 48), Vector2(210, 56), Vector2(185, 9)][index]
			var side: float = (12 if index == 1 else 9) * pulse
			draw_texture_rect(SPARKLE, Rect2(point - Vector2.ONE * side * 0.5, Vector2.ONE * side), false, Color(1.0, 0.78, 0.25, opening * pulse))


func _draw_preview_chest(base: Vector2, factor: float, opening: float) -> void:
	# Crop positions are the original 1024px Royal canvas coordinates in rigs.json.
	var origin: Vector2 = base - Vector2(438, 905) * factor
	var lid_height: float = cos(opening * PI)
	if lid_height < 0.0:
		_preview_chest_layer(CHEST_INNER_LID, Vector2(122, 157), origin, factor, -lid_height)
	if opening > 0.0:
		_preview_chest_layer(CHEST_INTERIOR, Vector2(100, 439), origin, factor)
	_preview_chest_layer(CHEST_BODY, Vector2(39, 514), origin, factor)
	if lid_height > 0.0:
		_preview_chest_layer(CHEST_LID, Vector2(46, 309), origin, factor, lid_height)
	_preview_chest_layer(CHEST_LATCH, Vector2(207, 495 + opening * 18), origin, factor)


func _preview_chest_layer(texture: Texture2D, crop: Vector2, origin: Vector2, factor: float, hinge_scale: float = 1.0) -> void:
	var point := Vector2(crop.x, 475 + (crop.y - 475) * hinge_scale)
	var dimensions: Vector2 = texture.get_size() * Vector2(1.0, hinge_scale) * factor
	_art(texture, Rect2(origin + point * factor, dimensions))


func _draw_merge_demo() -> void:
	var approach: float = smoothstep(0.75, 1.7, _elapsed)
	var fusion: float = smoothstep(1.65, 2.3, _elapsed)
	var clear: float = smoothstep(3.65, 4.15, _elapsed)
	var center := Vector2(110, 64)
	if fusion < 1.0:
		var separation: float = lerpf(53, 22, approach) * (1.0 - fusion)
		var stretch := Vector2(1.0 + approach * 0.12, 1.0 - approach * 0.08)
		var dimensions: Vector2 = Vector2(91, 83) * stretch
		var labels: float = 1.0 - smoothstep(0.0, 0.45, fusion)
		_gel(Rect2(center - Vector2(separation, 0) - dimensions * 0.5, dimensions), MINT, "", CAT, 1.0 - fusion, labels)
		_gel(Rect2(center + Vector2(separation, 0) - dimensions * 0.5, dimensions), MINT, "cat", null, 1.0 - fusion, labels)
		if approach < 0.4:
			_arrow(Vector2(96, 61), Vector2(123, 61))
	if fusion > 0.0 and clear < 1.0:
		var recoil: float = _recoil(2.3)
		var press: float = _hop(3.4, 0.25, 0.10)
		var dimensions: Vector2 = Vector2(128, 96) * Vector2(1.0 + recoil * 0.14 + press - clear * 0.5, 1.0 - recoil * 0.10 - press + clear * 0.3)
		var collect_center: Vector2 = center + Vector2(0, -clear * 18)
		_gel(Rect2(collect_center - dimensions * 0.5, dimensions), MINT, "cat", CAT,
			fusion * (1.0 - clear), smoothstep(0.45, 0.85, fusion))
	_tap(center + Vector2(33, 23), 3.4, Style.GOOD)
	if _elapsed >= 3.75:
		var flight: float = smoothstep(3.75, 4.45, _elapsed)
		var coin_center: Vector2 = center.lerp(Vector2(161, 32), flight) - Vector2(0, sin(flight * PI) * 24)
		var coin_side: float = 30 * smoothstep(3.75, 3.95, _elapsed)
		_art(COIN, Rect2(coin_center - Vector2.ONE * coin_side * 0.5, Vector2.ONE * coin_side))
		if flight > 0.8:
			Style.draw_match_badge(self, Vector2(97, 66), 20 * smoothstep(0.8, 1.0, flight))
